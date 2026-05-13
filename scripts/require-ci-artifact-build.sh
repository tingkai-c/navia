#!/usr/bin/env bash
set -euo pipefail

command_name="${*:-local app build}"

if [ "${NAVIA_ALLOW_LOCAL_APP_BUILD:-}" = "1" ]; then
  exit 0
fi

cat >&2 <<MSG
Navia local app build/release/open/install command blocked: ${command_name}

Signed/testable Navia.app artifacts must come from GitHub Actions, not local app builds.
Use the GitHub Actions artifact instead.
Commit and push the change, wait for .github/workflows/macos-build.yml, then download
and install the Navia-macOS-signed-notarized-app artifact.

Set NAVIA_ALLOW_LOCAL_APP_BUILD=1 only for intentional human recovery/development;
agents must not use that override for completion verification.
MSG
exit 1
