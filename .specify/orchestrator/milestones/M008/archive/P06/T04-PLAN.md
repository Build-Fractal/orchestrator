---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M008"
name: "check-update.sh — offline-safe version checker"
depends_on: ["T02"]
---

## Prerequisites

- T02 produced `packaging/bundle/manifest.yml` with a `version:` field (default `0.3.0-dev`).
- No `VERSION` file is required at repo root; check-update falls back to the manifest.
- FR-019 requires self-update infrastructure that preserves local configuration. This task ships the read-only version checker half of that story; actual upgrade execution is infrastructure reserved for M010.

## Description

Create `scripts/lifecycle/check-update.sh`, a read-only command that compares the installed bundle version against a remote "latest" version and reports structured `key=value` lines. The remote URL is a placeholder for M010 — when the remote is unavailable (no network, 404, or missing curl/wget), the script degrades gracefully: it still emits the installed version and sets `update_available=unknown` rather than crashing.

## Steps

1. Create `scripts/lifecycle/check-update.sh` (Bash 3.2). Interface:

```
Usage:
  scripts/lifecycle/check-update.sh [--project-dir PATH] [--timeout SECONDS] [--remote-url URL]

Outputs (stdout, key=value lines):
  installed_version=<version-string>
  latest_version=<version-string or "unknown">
  update_available=true|false|unknown
  update_instructions=<single line>   # only when update_available=true

Exit codes:
  0  always, unless invoked with invalid arguments.
```

2. Resolve the installed version in this order:
   - `$REPO_ROOT/VERSION` file (if present and non-empty).
   - `packaging/bundle/manifest.yml` — grep `^version:` and strip quotes.
   - Fall back to `0.3.0-dev`.

3. Resolve the remote latest version:
   - Default `--remote-url` to a placeholder (e.g., `https://speckit.example.invalid/orchestrator/latest.txt`). `.invalid` TLD guarantees it won't accidentally resolve in production.
   - If `curl` is available: `curl -fsS --max-time "$TIMEOUT" "$REMOTE_URL"` with stderr suppressed; trim whitespace.
   - Else if `wget` is available: `wget -qO- --timeout="$TIMEOUT" "$REMOTE_URL"`.
   - Else: print `latest_version=unknown` and `update_available=unknown`, then exit 0. Do NOT call `curl`/`wget` in a subshell with `$()` containing pipes (AD-19 / MEM001).
   - If the remote call returns non-zero: `latest_version=unknown`, `update_available=unknown`.

4. Comparison:
   - If `latest_version` is `unknown`, emit `update_available=unknown` and exit 0 without `update_instructions`.
   - If `latest_version` equals `installed_version`, emit `update_available=false`.
   - Else emit `update_available=true` and `update_instructions=<text>` where `<text>` is a single-line hint like:
     `update_instructions=run: bash packaging/install/install-claude-code.sh --force (or the codex/cursor variant)`

5. Offline-safety tests. Create `scripts/verify/m008-p06-check-update.sh` that:
   - Runs `check-update.sh` with `--remote-url https://speckit.example.invalid/does-not-exist --timeout 2` and asserts exit 0 plus all three required keys present.
   - Asserts that `update_available=unknown` when the remote is unreachable.
   - Temporarily overrides `VERSION` file in a hermetic fixture to assert the installed version is sourced correctly.
   - Asserts that when the remote returns the same version as installed, `update_available=false` (tested via a `file://` URL pointing at a mktemp'd file — use curl's `file://` support; skip this subtest if curl is unavailable).

Sample verification script skeleton:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

out="$TMP/out.txt"
bash "$REPO_ROOT/scripts/lifecycle/check-update.sh" \
  --remote-url 'https://speckit.example.invalid/does-not-exist' \
  --timeout 2 > "$out" 2>&1

grep -q '^installed_version=' "$out" || {
  echo "FAIL: missing installed_version" >&2
  cat "$out" >&2
  exit 1
}

grep -q '^latest_version=' "$out" || {
  echo "FAIL: missing latest_version" >&2
  exit 1
}

grep -q '^update_available=unknown' "$out" || {
  echo "FAIL: expected update_available=unknown under offline remote" >&2
  cat "$out" >&2
  exit 1
}

echo "PASS: check-update.sh offline-safe"
```

## Must-Haves

Addresses:

- `scripts/lifecycle/check-update.sh` exists, emits the three required keys, and works offline.
- Key link: `scripts/lifecycle/check-update.sh → packaging/bundle/manifest.yml` (reads bundled version).

## Verification

```
bash scripts/verify/m008-p06-check-update.sh
```

Expected output:

```
PASS: check-update.sh offline-safe
```

## Inputs

### From Previous Tasks

- `packaging/bundle/manifest.yml` (from T02) — source of installed version when no `VERSION` file is present.
  - Key API: YAML with a top-level `version: "<semver-or-dev>"` field. Read via `grep '^version:' manifest.yml | sed`.

### From Disk (Pre-existing)

- `VERSION` (optional) at repo root — if present, takes precedence over manifest.
- `scripts/util/json-field.sh` (MEM008) — not used here (we don't parse JSON), listed for awareness.

## Constraints

- Offline-safe: script MUST exit 0 when the remote is unreachable.
- No python, no jq — pure bash/grep/sed/curl|wget.
- AD-19 / MEM001 shape: do not embed `$(cmd | pipe)`; capture remote output via `curl -fsS ... > "$tmpfile"` then `read` from the file. Similarly, version-file reads use `read -r line < "$file"` patterns, not `$(cat)`.
- Bash 3.2 compat.
- The placeholder `--remote-url` default MUST use a TLD like `.invalid` or `.example` that cannot resolve in real networks.
- Timeout default: 5 seconds. User-overridable via `--timeout`.

## Expected Output

- `scripts/lifecycle/check-update.sh` — 30+ line script (mode 0755).
- `scripts/verify/m008-p06-check-update.sh` — verification script (mode 0755).
