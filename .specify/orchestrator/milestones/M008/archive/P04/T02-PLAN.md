---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M008"
name: "Create scripts/state/detect-speckit.sh -- spec-kit detection and integration toggle"
depends_on: []
---

## Prerequisites

- Bash 3.2+ available.
- `scripts/state/` directory exists in the repo.
- T02 is independent of T01; can run in parallel.

## Description

Create `scripts/state/detect-speckit.sh` — probes the environment for spec-kit presence and emits a canonical two-line key=value answer. Used by runtime adapters (P05) and the init flow (P07) to decide whether to enable spec-kit integration mode (FR-015).

The script checks three signals and OR-combines them:

1. `.specify/` directory exists at the repo root.
2. `.specify/memory/constitution.md` exists (a strong spec-kit signal).
3. `speckit` binary is discoverable on PATH.

If any signal fires, `speckit_installed=true`. Otherwise `false`. `integration_mode` defaults to `enabled` iff `speckit_installed=true`, else `disabled`. A `--force-disabled` flag lets callers force `integration_mode=disabled` even when spec-kit is present (for standalone-mode testing).

## Steps

### Step 1 — Create scripts/state/detect-speckit.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# scripts/state/detect-speckit.sh — Detect spec-kit installation.
#
# Signals (any one triggers speckit_installed=true):
#   - .specify/ directory at repo root
#   - .specify/memory/constitution.md file
#   - speckit binary on PATH
#
# Usage:
#   detect-speckit.sh                  -> emits two key=value lines
#   detect-speckit.sh --force-disabled -> integration_mode=disabled even if installed
#
# Output (stdout):
#   speckit_installed=<true|false>
#   integration_mode=<enabled|disabled>
#
# Exit: 0 always (detection is informational, not failure-mode).
# Bash 3.2 compatible.

set -u

FORCE_DISABLED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-disabled) FORCE_DISABLED=1; shift ;;
    -h|--help)
      sed -n '2,13p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# Locate repo root
repo_root="$PWD"
while [[ "$repo_root" != "/" ]]; do
  if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
    break
  fi
  repo_root="$(dirname "$repo_root")"
done
if [[ "$repo_root" = "/" ]]; then
  repo_root="$PWD"
fi

installed="false"

if [[ -d "$repo_root/.specify" ]]; then
  installed="true"
fi
if [[ "$installed" = "false" ]] && [[ -f "$repo_root/.specify/memory/constitution.md" ]]; then
  installed="true"
fi
if [[ "$installed" = "false" ]] && command -v speckit >/dev/null 2>&1; then
  installed="true"
fi

if [[ "$installed" = "true" ]] && [[ "$FORCE_DISABLED" = "0" ]]; then
  mode="enabled"
else
  mode="disabled"
fi

echo "speckit_installed=$installed"
echo "integration_mode=$mode"
```

### Step 2 — Make the script executable

```bash
chmod +x scripts/state/detect-speckit.sh
```

## Must-Haves

This task addresses:

- `scripts/state/detect-speckit.sh` emits `speckit_installed=<true|false>` and `integration_mode=<enabled|disabled>` as two key=value lines.

## Verification

Run:

- `bash scripts/verify/m008-p04-detect-speckit-shape.sh`

Must exit 0 with a `PASS:` line.

## Inputs

### From Previous Tasks

None. T02 is independent.

### From Disk (Pre-existing)

- `scripts/state/` — existing directory.

## Constraints

- Bash 3.2 compatible.
- Detection must never exit non-zero. Absence of spec-kit is an answer, not an error.
- No modification of any file. Pure read-only probe.
- Output is stable — exactly two lines, fixed keys, values from a closed vocabulary.

## Expected Output

Creating:

- `scripts/state/detect-speckit.sh` — ~45 lines, executable.

Sample run in a project with `.specify/` present:

```
speckit_installed=true
integration_mode=enabled
```

With `--force-disabled`:

```
speckit_installed=true
integration_mode=disabled
```
