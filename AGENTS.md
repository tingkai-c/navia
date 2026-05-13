# Navia Agent Instructions

This repository is a renamed long-lived fork of upstream Sol. Before syncing, merging, rebasing, or resolving conflicts with upstream Sol, read and follow:

- `docs/upstream-merge-guide.md`

Merge policy:

- Preserve the Navia fork identity unless the user explicitly asks to undo it.
- Treat app/bundle/product-name conflicts as fork-identity conflicts, not simple upstream wins.
- Do not commit generated build artifacts; respect `.gitignore`, especially `macos/build-local/` and `.app` bundles.
- After upstream merges, verify with the checks listed in the merge guide before claiming completion.

## Remote build/signing policy

- The canonical signed and notarized Navia app is built by GitHub Actions workflow `.github/workflows/macos-build.yml`.
- Builds are intended to run on trusted pushes to repo-owned branches in `tingkai-c/navia`; `workflow_dispatch` is allowed for trusted manual retry/diagnostics.
- Do not add signing/notarization paths for pull requests, forks, Dependabot, `pull_request_target`, `workflow_call`, or reusable workflows without an explicit security review and a new plan.
- Do not build, sign, notarize, open, or install Navia app bundles locally for agent completion verification.
- Local app-build/release/open/install commands must fail closed by default unless `NAVIA_ALLOW_LOCAL_APP_BUILD=1` is set for intentional human recovery/development. Agents must not use that override to satisfy completion verification.
- Blocked local paths include `bun macos`, `bun dev`, `bun release`, Fastlane local app/release lanes, and `mise` app/build/install paths such as `mise run app`, `mise run macos`, `mise run local`, `mise run build-release`, `mise run local-release`, `mise run install-local`, `mise run perf`, and default `mise` paths.

## Apple signing secrets policy

- Signing source of truth is the user-wide store under `~/certificates/apple/`, with app notes under `~/certificates/apple/apps/navia/`.
- Never commit Apple signing material, `.p12`, `.p8`, private keys, passwords, decoded certificates, or generated keychains.
- Never print secret values. Refer to GitHub Secrets by name only.
- Required repo secrets are:
  - `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`
  - `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`
  - `MACOS_KEYCHAIN_PASSWORD`
  - `APPLE_TEAM_ID`
  - `APP_STORE_CONNECT_KEY_ID`
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_API_KEY_BASE64`
- When setting secrets with `gh`, pipe from files/stdin and check payload sizes first; base64 is transport encoding, not encryption.

## Agent completion workflow

For task, feature, and bug-fix completion in this repository:

1. Review `git status --short --branch` and `git log --oneline origin/main..HEAD` before pushing.
2. Commit with a concise non-OMX-lore commit message. This is a direct repo policy override requested for Navia agent completion commits.
3. Push to GitHub.
4. Select the GitHub Actions run for the exact pushed commit SHA; do not use “latest” or “first” if multiple runs match.
5. Wait for the workflow to complete successfully.
6. Download the `Navia-macOS-signed-notarized-app` artifact.
7. Verify the artifact contains exactly one `Navia.app` with bundle ID `com.tingkaichiu.navia` before touching `/Applications`.
8. If `/Applications/Navia.app` exists, preserve a timestamped rollback backup before replacing it. If Navia is running, quit it safely or stop before replacement.
9. Install the downloaded app to `/Applications/Navia.app`.
10. Verify the installed app:
    - `codesign -d --entitlements :- /Applications/Navia.app` and confirm `com.apple.security.get-task-allow` is absent.
    - `codesign --verify --strict --deep --verbose=4 /Applications/Navia.app`
    - `spctl --assess --type execute --verbose=4 /Applications/Navia.app`
    - `xcrun stapler validate /Applications/Navia.app`
11. Report commit SHA, run URL, artifact name, install path, rollback backup path, and verification results.

Preferred helper after pushing:

```bash
scripts/install-github-actions-artifact.sh <pushed-commit-sha>
```

Stop immediately if secrets leak, the exact run cannot be selected deterministically, CI signing/notarization/stapling fails, the artifact structure is unexpected, `/Applications` replacement cannot be made rollback-safe, or final codesign/Gatekeeper/stapler/entitlement checks fail.
