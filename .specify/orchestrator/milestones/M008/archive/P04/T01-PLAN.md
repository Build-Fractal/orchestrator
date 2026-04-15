---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M008"
name: "Create scripts/state/resolve-root.sh -- the canonical root resolver"
depends_on: []
---

## Prerequisites

- Bash 3.2+ available (macOS default). No Bash 4 features (no `declare -A`, no `mapfile`, no `readarray`).
- Repository root contains `scripts/state/` directory (already present in this codebase).
- No other P04 task has run yet. T01 is the dependency root for T03, T04, T05.

## Description

Create `scripts/state/resolve-root.sh` — the single authoritative resolver for the orchestrator state root. Every downstream script that needs to read or write orchestrator state will call this script instead of hardcoding `.specify/orchestrator/` or `.orchestrator/`.

The resolver encodes a deterministic precedence chain:

1. **`ORCHESTRATOR_ROOT` env var** — explicit user override. If set and non-empty, use it verbatim.
2. **Config file** — `.orchestrator/config.yml` OR `.specify/orchestrator/config.yml` containing `state_root: <path>`. First one found wins.
3. **`.orchestrator/` exists** — use it. This is the standalone-mode canonical root.
4. **`.specify/orchestrator/` exists** — use it. This is the one-way migration bridge for existing users.
5. **Neither exists** — default to `.orchestrator/` (new standalone projects).

The resolver never creates directories. It only reports where the root should be. Callers that need to write to the root are responsible for creating it.

Output: a single line to stdout containing a repo-relative path (no trailing slash). No other output unless `--verbose` is passed.

## Steps

### Step 1 — Create scripts/state/resolve-root.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# scripts/state/resolve-root.sh — Resolve the orchestrator state root.
#
# Resolution precedence (highest first):
#   1. ORCHESTRATOR_ROOT env var (explicit override)
#   2. state_root field in .orchestrator/config.yml or .specify/orchestrator/config.yml
#   3. .orchestrator/ directory (standalone canonical)
#   4. .specify/orchestrator/ directory (migration bridge)
#   5. Default: .orchestrator/ (new projects)
#
# Usage:
#   resolve-root.sh                  -> emits repo-relative root to stdout
#   resolve-root.sh --verbose        -> emits "root=<path>" plus "source=<precedence-rule>"
#   resolve-root.sh --absolute       -> emits absolute path to stdout
#
# Exit: 0 on success. 1 on malformed argument.
# Bash 3.2 compatible (MEM001).

set -u

VERBOSE=0
ABSOLUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    --absolute) ABSOLUTE=1; shift ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0 ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

# Determine repo root. Walk up from $PWD looking for .git.
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

resolved=""
source_rule=""

# Rule 1: env var
if [[ -n "${ORCHESTRATOR_ROOT:-}" ]]; then
  resolved="$ORCHESTRATOR_ROOT"
  source_rule="env:ORCHESTRATOR_ROOT"
fi

# Rule 2: config file state_root field
if [[ -z "$resolved" ]]; then
  for cfg in "$repo_root/.orchestrator/config.yml" "$repo_root/.specify/orchestrator/config.yml"; do
    if [[ -f "$cfg" ]]; then
      candidate="$(grep -E '^state_root:' "$cfg" 2>/dev/null | head -n 1 | sed -E 's/^state_root:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
      if [[ -n "$candidate" ]]; then
        resolved="$candidate"
        source_rule="config:$cfg"
        break
      fi
    fi
  done
fi

# Rule 3: .orchestrator/ exists
if [[ -z "$resolved" ]] && [[ -d "$repo_root/.orchestrator" ]]; then
  resolved=".orchestrator"
  source_rule="existing:.orchestrator"
fi

# Rule 4: .specify/orchestrator/ exists (bridge)
if [[ -z "$resolved" ]] && [[ -d "$repo_root/.specify/orchestrator" ]]; then
  resolved=".specify/orchestrator"
  source_rule="bridge:.specify/orchestrator"
fi

# Rule 5: default
if [[ -z "$resolved" ]]; then
  resolved=".orchestrator"
  source_rule="default"
fi

# Strip trailing slash if any
resolved="${resolved%/}"

if [[ "$ABSOLUTE" = "1" ]]; then
  case "$resolved" in
    /*) : ;;
    *)  resolved="$repo_root/$resolved" ;;
  esac
fi

if [[ "$VERBOSE" = "1" ]]; then
  echo "root=$resolved"
  echo "source=$source_rule"
else
  echo "$resolved"
fi
```

### Step 2 — Make the script executable

```bash
chmod +x scripts/state/resolve-root.sh
```

### Step 3 — Smoke test manually (optional, for reviewer confidence)

```bash
bash scripts/state/resolve-root.sh --verbose
```

Expected: two lines, `root=.specify/orchestrator` (because this project currently has `.specify/orchestrator/`) and `source=bridge:.specify/orchestrator` OR `root=.orchestrator` and `source=existing:.orchestrator` depending on which dir is present. Either is acceptable — the verification scripts use fresh temp dirs, not the live repo state.

## Must-Haves

This task addresses the following phase must-haves:

- `scripts/state/resolve-root.sh` exists and is executable.
- `scripts/state/resolve-root.sh` honors the `ORCHESTRATOR_ROOT` env var as the highest-priority override.
- `scripts/state/resolve-root.sh` defaults to `.orchestrator/` for a brand-new project with neither `.orchestrator/` nor `.specify/orchestrator/` present.
- `scripts/state/resolve-root.sh` resolves to `.specify/orchestrator/` when only that directory exists.
- `scripts/state/resolve-root.sh` prefers `.orchestrator/` when BOTH roots exist.
- Bash 3.2 compatibility (verified holistically by T06).

## Verification

Run each of the following; each must exit 0 and print a `PASS:` line:

- `bash scripts/verify/m008-p04-resolve-root-exists.sh`
- `bash scripts/verify/m008-p04-resolve-root-env-override.sh`
- `bash scripts/verify/m008-p04-resolve-root-default.sh`
- `bash scripts/verify/m008-p04-resolve-root-bridge.sh`
- `bash scripts/verify/m008-p04-resolve-root-prefers-new.sh`

## Inputs

### From Previous Tasks

None. T01 is the root task.

### From Disk (Pre-existing)

- `scripts/state/` — existing directory in the repo; new resolve-root.sh joins it.

## Constraints

- Bash 3.2 compatible. No `declare -A`, no `mapfile`, no `readarray`, no `[[ -v ]]`.
- No external dependencies beyond `grep`, `sed`, `dirname`, `basename`. No `jq`, no `python3`.
- Must not create any directory. Pure read-only resolver.
- Must not write to stdout anything except the resolved path (and the verbose key=value lines when `--verbose` is passed). Errors go to stderr.
- Output path has no trailing slash.

## Expected Output

Creating:

- `scripts/state/resolve-root.sh` — ~80 lines, executable.

Running `bash scripts/state/resolve-root.sh` in a directory with neither `.orchestrator/` nor `.specify/orchestrator/` present prints exactly:

```
.orchestrator
```

Running `ORCHESTRATOR_ROOT=custom/path bash scripts/state/resolve-root.sh --verbose` prints:

```
root=custom/path
source=env:ORCHESTRATOR_ROOT
```
