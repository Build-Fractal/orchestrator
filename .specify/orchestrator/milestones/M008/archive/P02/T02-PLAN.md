---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M008"
name: "Create backend-registry.sh -- adapter auto-discovery and probing"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/` directory exists (contains `build-context.sh`, `detect-capabilities.sh`, etc.).
- The directory `scripts/dispatch/adapters/backend/` may not yet exist — this task will create it if absent so registry invocations remain safe when called in isolation.

## Description

Create `scripts/dispatch/backend-registry.sh`, which enumerates available dispatch backend adapters by scanning `scripts/dispatch/adapters/backend/*.sh` and probing each one. The registry is the mechanism that satisfies FR-011 — "new dispatch backends can be registered without modifying core dispatch logic." There is no central registration file; dropping a new adapter script into `scripts/dispatch/adapters/backend/` is sufficient.

The registry contract:

- Adapters are shell scripts matching `scripts/dispatch/adapters/backend/*.sh`.
- Each adapter MUST support a `--probe` sub-command that outputs key=value lines including at minimum `available=true|false`.
- The registry aggregates probe results and outputs the set of available backends and the default backend (first available in sorted-by-filename order).

Output format (key=value lines on stdout, one per line):

```
backends_discovered=local-agent,local-codex
backends_available=local-agent
default_backend=local-agent
```

- `backends_discovered` — comma-separated list of all adapter names (with the `.sh` suffix stripped), sorted alphabetically.
- `backends_available` — comma-separated subset that probed `available=true`.
- `default_backend` — the first entry in `backends_available`; empty string if none available.

If no adapters are discovered, output:

```
backends_discovered=
backends_available=
default_backend=
```

Exit code: always 0. Registry failures (missing adapters, probe timeouts) are reflected in the output, not the exit code.

## Steps

### Step 1 — Ensure the adapters directory exists

The registry must not fail when no adapters are present yet (during bootstrap or in tests). The script will test for the directory and gracefully output empty fields.

### Step 2 — Create scripts/dispatch/backend-registry.sh

Write the following content verbatim to `scripts/dispatch/backend-registry.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/backend-registry.sh — Dispatch backend discovery and probing
#
# Scans scripts/dispatch/adapters/backend/*.sh and probes each adapter via
# --probe to determine which backends are available in the current
# environment. Outputs discovery and availability as key=value lines.
#
# Usage: backend-registry.sh [--list | --probe <backend>]
#   (no args)       — discover + probe all adapters; output key=value summary
#   --list          — list all discovered adapters (one per line), no probing
#   --probe <name>  — probe a single named adapter; print its raw probe output
#
# Output (default mode):
#   backends_discovered=<comma-list>
#   backends_available=<comma-list>
#   default_backend=<name or empty>
#
# FR-011: new backends are registered by dropping a *.sh file into the
# adapters/backend/ directory. No core edits required.
#
# Bash 3.2 compatible. Always exits 0.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

MODE="summary"
TARGET_BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      MODE="list"; shift ;;
    --probe)
      MODE="probe"; TARGET_BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Discovery ---

discovered_names=""
if [[ -d "$ADAPTERS_DIR" ]]; then
  for adapter in "$ADAPTERS_DIR"/*.sh; do
    [[ -f "$adapter" ]] || continue
    base="$(basename "$adapter" .sh)"
    if [[ -z "$discovered_names" ]]; then
      discovered_names="$base"
    else
      discovered_names="${discovered_names},${base}"
    fi
  done
fi

# --- Mode: list ---

if [[ "$MODE" = "list" ]]; then
  if [[ -n "$discovered_names" ]]; then
    # Print one adapter name per line
    old_ifs="$IFS"
    IFS=','
    for name in $discovered_names; do
      echo "$name"
    done
    IFS="$old_ifs"
  fi
  exit 0
fi

# --- Mode: probe a single named adapter ---

if [[ "$MODE" = "probe" ]]; then
  if [[ -z "$TARGET_BACKEND" ]]; then
    echo "FAIL: --probe requires a backend name" >&2
    exit 0
  fi
  adapter="${ADAPTERS_DIR}/${TARGET_BACKEND}.sh"
  if [[ ! -f "$adapter" ]]; then
    echo "available=false"
    echo "reason=adapter-not-found"
    exit 0
  fi
  bash "$adapter" --probe 2>/dev/null || echo "available=false"
  exit 0
fi

# --- Mode: summary (default) ---

available_names=""
if [[ -n "$discovered_names" ]]; then
  old_ifs="$IFS"
  IFS=','
  for name in $discovered_names; do
    adapter="${ADAPTERS_DIR}/${name}.sh"
    probe_output="$(bash "$adapter" --probe 2>/dev/null || echo "available=false")"
    # Extract the available= value
    is_available="$(echo "$probe_output" | grep -E '^available=' | head -n 1 | cut -d= -f2)"
    if [[ "$is_available" = "true" ]]; then
      if [[ -z "$available_names" ]]; then
        available_names="$name"
      else
        available_names="${available_names},${name}"
      fi
    fi
  done
  IFS="$old_ifs"
fi

default_backend=""
if [[ -n "$available_names" ]]; then
  default_backend="${available_names%%,*}"
fi

echo "backends_discovered=${discovered_names}"
echo "backends_available=${available_names}"
echo "default_backend=${default_backend}"
exit 0
```

### Step 3 — Make the script executable

```bash
chmod +x scripts/dispatch/backend-registry.sh
```

### Step 4 — Create scripts/verify/m008-p02-registry-discovery.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies backend-registry.sh discovers and probes adapters correctly.
set -u

f="scripts/dispatch/backend-registry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script documents its contract
grep -q 'backends_discovered' "$f" || { echo "FAIL: $f missing backends_discovered key"; exit 1; }
grep -q 'backends_available' "$f" || { echo "FAIL: $f missing backends_available key"; exit 1; }
grep -q 'default_backend' "$f" || { echo "FAIL: $f missing default_backend key"; exit 1; }
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not probe adapters"; exit 1; }
grep -q 'adapters/backend' "$f" || { echo "FAIL: $f does not reference adapters directory"; exit 1; }

# Script must be bash 3.2 compatible (no declare -A)
if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
  echo "FAIL: $f uses declare -A (not Bash 3.2 compatible)"; exit 1
fi

# Run the script in summary mode — must emit all three required keys and exit 0
output="$(bash "$f" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: $f exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -qE '^backends_discovered=' || { echo "FAIL: output missing backends_discovered"; exit 1; }
echo "$output" | grep -qE '^backends_available=' || { echo "FAIL: output missing backends_available"; exit 1; }
echo "$output" | grep -qE '^default_backend=' || { echo "FAIL: output missing default_backend"; exit 1; }

# --list mode must work without adapters present (may print nothing or list names)
bash "$f" --list >/dev/null 2>&1 || { echo "FAIL: --list mode failed"; exit 1; }

echo "PASS: backend-registry.sh discovers and probes adapters"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-registry-discovery.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/backend-registry.sh discovers adapters in scripts/dispatch/adapters/backend/*.sh and probes each to determine availability..."
- **Artifacts**: `scripts/dispatch/backend-registry.sh`, `scripts/verify/m008-p02-registry-discovery.sh`.

## Verification

Run the verification script standalone:

```bash
bash scripts/verify/m008-p02-registry-discovery.sh
```

Should print `PASS:` and exit 0. Note: T02's verification runs successfully even when no adapters exist yet (the `backends_discovered` field is empty but present). Full multi-adapter verification occurs in T06 after T03 and T04 create the adapters.

### Files Touched By This Task

- `scripts/dispatch/backend-registry.sh` (create)
- `scripts/verify/m008-p02-registry-discovery.sh` (create)

## Inputs

### From Previous Tasks

None — T02 is independent of T01.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` — existing peer script demonstrating the `--format` / flag-style argument parsing pattern and key=value output convention.

## Constraints

- Bash 3.2 compatible — no `declare -A`, no `readarray`, no `|&`.
- Always exits 0 (registry failures are reflected in output fields, never via exit codes).
- Must function even when `scripts/dispatch/adapters/backend/` directory does not exist (empty output, no error).
- Must not `source` adapter scripts — always invoke them as subprocesses (`bash "$adapter" --probe`). Adapters are isolated.
- Adapter probe output is parsed by grepping `^available=` — adapters that emit malformed probe output are treated as unavailable.

## Expected Output

After completing this task:

1. `scripts/dispatch/backend-registry.sh` exists (~110 lines), is executable, and supports three modes: default (summary), `--list`, and `--probe <name>`.
2. `bash scripts/dispatch/backend-registry.sh` with no adapters present outputs three lines: `backends_discovered=`, `backends_available=`, `default_backend=` (all empty). Exit 0.
3. `bash scripts/dispatch/backend-registry.sh --list` prints adapter names one per line (or nothing if none exist). Exit 0.
4. `bash scripts/verify/m008-p02-registry-discovery.sh` prints `PASS`.
5. `git status` shows 2 new files.
