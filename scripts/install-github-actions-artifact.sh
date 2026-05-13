#!/usr/bin/env bash
set -euo pipefail

repo="${NAVIA_GITHUB_REPO:-tingkai-c/navia}"
workflow_name="${NAVIA_WORKFLOW_NAME:-Build macOS App}"
event_name="${NAVIA_WORKFLOW_EVENT:-push}"
artifact_name="${NAVIA_ARTIFACT_NAME:-Navia-macOS-signed-notarized-app}"
sha="${1:-}"

if [ -z "$sha" ]; then
  sha="$(git rev-parse HEAD)"
fi

if [ -z "$sha" ]; then
  echo "Usage: $0 <pushed-commit-sha>" >&2
  exit 2
fi

workdir="${NAVIA_ARTIFACT_WORKDIR:-/tmp/navia-artifact-$sha}"
rm -rf "$workdir"
mkdir -p "$workdir"

runs_json="$workdir/runs.json"
run_info="$workdir/run-info.json"
run_timeout_seconds="${NAVIA_RUN_DISCOVERY_TIMEOUT_SECONDS:-180}"
run_started_at="$(date +%s)"

while :; do
  gh run list \
    --repo "$repo" \
    --workflow "$workflow_name" \
    --commit "$sha" \
    --event "$event_name" \
    --limit 100 \
    --json databaseId,headSha,event,workflowName,url,status,conclusion,headBranch \
    > "$runs_json"

  match_status="$(python3 - "$runs_json" "$sha" "$event_name" "$workflow_name" "$run_info" <<'PY'
import json
import sys

runs_path, sha, event_name, workflow_name, out_path = sys.argv[1:]
runs = json.load(open(runs_path))
matches = [
    run for run in runs
    if run.get("headSha") == sha
    and run.get("event") == event_name
    and run.get("workflowName") == workflow_name
]

if len(matches) == 1:
    open(out_path, "w").write(json.dumps(matches[0]))
    print("one")
elif len(matches) == 0:
    print("zero")
else:
    print(
        f"Expected exactly one {workflow_name!r} run for sha={sha} event={event_name}; found {len(matches)}.",
        file=sys.stderr,
    )
    for run in matches:
        print(
            f"candidate id={run.get('databaseId')} status={run.get('status')} "
            f"conclusion={run.get('conclusion')} url={run.get('url')}",
            file=sys.stderr,
        )
    sys.exit(2)
PY
)"

  if [ "$match_status" = "one" ]; then
    break
  fi

  now="$(date +%s)"
  if [ $((now - run_started_at)) -ge "$run_timeout_seconds" ]; then
    echo "Timed out waiting for a unique $workflow_name run for sha=$sha event=$event_name." >&2
    exit 1
  fi

  sleep 5
done

run_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["databaseId"])' "$run_info")"
run_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["url"])' "$run_info")"

gh run watch --repo "$repo" "$run_id" --exit-status

gh run download \
  --repo "$repo" \
  "$run_id" \
  --name "$artifact_name" \
  --dir "$workdir/download"

zip_path="$workdir/download/Navia.app.zip"
if [ ! -f "$zip_path" ]; then
  echo "Expected artifact zip missing: $zip_path" >&2
  exit 1
fi

unzip_dir="$workdir/unzipped"
mkdir -p "$unzip_dir"
ditto -x -k "$zip_path" "$unzip_dir"

apps_list="$workdir/apps.txt"
find "$unzip_dir" -maxdepth 3 -name '*.app' -type d > "$apps_list"
app_count="$(wc -l < "$apps_list" | tr -d ' ')"
if [ "$app_count" -ne 1 ]; then
  echo "Expected exactly one .app bundle in artifact; found $app_count." >&2
  cat "$apps_list" >&2
  exit 1
fi

app_path="$(cat "$apps_list")"
if [ "$(basename "$app_path")" != "Navia.app" ]; then
  echo "Expected artifact app bundle to be Navia.app, found: $(basename "$app_path")" >&2
  exit 1
fi
plist="$app_path/Contents/Info.plist"
if [ ! -f "$plist" ]; then
  echo "Artifact Navia.app is missing Contents/Info.plist." >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$plist" 2>/dev/null || true)"
if [ "$bundle_id" != "com.tingkaichiu.navia" ]; then
  echo "Unexpected bundle id in artifact: $bundle_id" >&2
  exit 1
fi
if [ -n "$display_name" ] && [ "$display_name" != "Navia" ]; then
  echo "Unexpected display name in artifact: $display_name" >&2
  exit 1
fi

if pgrep -x "Navia" >/dev/null 2>&1; then
  echo "Navia is running; asking it to quit before replacement." >&2
  osascript -e 'tell application "Navia" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do
    if ! pgrep -x "Navia" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if pgrep -x "Navia" >/dev/null 2>&1; then
    echo "Navia is still running; stop before replacing /Applications/Navia.app." >&2
    exit 1
  fi
fi

dest="/Applications/Navia.app"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$workdir/rollback"
backup_app="$backup_dir/Navia-$timestamp.app"
mkdir -p "$backup_dir"

if [ -d "$dest" ]; then
  ditto "$dest" "$backup_app"
fi

restore_backup() {
  if [ -d "$backup_app" ]; then
    rm -rf "$dest"
    ditto "$backup_app" "$dest"
    echo "Restored previous app from rollback backup: $backup_app" >&2
  fi
}
trap restore_backup ERR

rm -rf "$dest"
ditto "$app_path" "$dest"

entitlements="$workdir/installed-entitlements.plist"
codesign -d --entitlements :- "$dest" > "$entitlements" 2>/dev/null
if grep -q "com.apple.security.get-task-allow" "$entitlements"; then
  echo "Installed app contains disallowed get-task-allow entitlement." >&2
  exit 1
fi

codesign --verify --strict --deep --verbose=4 "$dest"
spctl --assess --type execute --verbose=4 "$dest"
xcrun stapler validate "$dest"

trap - ERR

cat <<REPORT
Installed Navia artifact successfully.
Run URL: $run_url
Run ID: $run_id
Artifact: $artifact_name
Download directory: $workdir
Install path: $dest
Rollback backup: ${backup_app:-none}
REPORT
