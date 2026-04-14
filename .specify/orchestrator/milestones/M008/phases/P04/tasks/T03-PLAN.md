---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M008"
name: "Create scripts/state/config-system.sh -- unified config get/set/list"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete — `scripts/state/resolve-root.sh` exists and emits a path to stdout.
- Bash 3.2+ available.
- `scripts/state/` directory exists.

## Description

Create `scripts/state/config-system.sh` — the single entry point for reading and writing orchestrator configuration. All commands that need to persist user preferences (default intensity, preferred backend, custom state-root overrides) go through this script.

The config file lives at `<root>/config.yml` where `<root>` is whatever `resolve-root.sh` returns. The file format is a small YAML subset: flat `key: value` lines plus nested keys represented as dot-joined paths on a single line (`intensity.default: Full`). No multi-line values, no lists, no anchors. The script manipulates the file with `grep`/`sed`/`awk` — no Python or jq.

Subcommands:

- `get <key>` — print the value for `<key>` to stdout, or exit 1 if the key is absent.
- `set <key> <value>` — upsert the key; creates the file if missing.
- `list` — print all key=value pairs, one per line, sorted.

## Steps

### Step 1 — Create scripts/state/config-system.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# scripts/state/config-system.sh — Unified config get/set/list for the orchestrator.
#
# Stores configuration at <root>/config.yml where <root> is resolved via
# scripts/state/resolve-root.sh. File format is a flat YAML subset:
#   key: value
#   nested.key: value     (dot notation on a single line)
#
# Usage:
#   config-system.sh get <key>
#   config-system.sh set <key> <value>
#   config-system.sh list
#
# Exit: 0 success, 1 missing key on `get`, 2 bad arguments.
# Bash 3.2 compatible (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE_ROOT="$SCRIPT_DIR/resolve-root.sh"

if [[ ! -x "$RESOLVE_ROOT" ]]; then
  echo "ERROR: resolve-root.sh not found or not executable at $RESOLVE_ROOT" >&2
  exit 2
fi

SUBCOMMAND="${1:-}"
if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: config-system.sh {get|set|list} [args]" >&2
  exit 2
fi
shift

# Resolve config file location once, up front.
root_path="$(bash "$RESOLVE_ROOT" --absolute)"
config_file="$root_path/config.yml"

ensure_config_dir() {
  if [[ ! -d "$root_path" ]]; then
    mkdir -p "$root_path"
  fi
  if [[ ! -f "$config_file" ]]; then
    touch "$config_file"
  fi
}

case "$SUBCOMMAND" in
  get)
    key="${1:-}"
    if [[ -z "$key" ]]; then
      echo "Usage: config-system.sh get <key>" >&2
      exit 2
    fi
    if [[ ! -f "$config_file" ]]; then
      exit 1
    fi
    value="$(grep -E "^${key}:" "$config_file" 2>/dev/null | head -n 1 | sed -E "s/^${key}:[[:space:]]*(.*)[[:space:]]*$/\1/")"
    if [[ -z "$value" ]]; then
      exit 1
    fi
    echo "$value"
    ;;

  set)
    key="${1:-}"
    value="${2:-}"
    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
      echo "Usage: config-system.sh set <key> <value>" >&2
      exit 2
    fi
    ensure_config_dir
    # Upsert: remove any existing line for the key, then append.
    tmp_file="$config_file.tmp.$$"
    if grep -qE "^${key}:" "$config_file" 2>/dev/null; then
      grep -vE "^${key}:" "$config_file" > "$tmp_file" || true
      mv "$tmp_file" "$config_file"
    fi
    echo "${key}: ${value}" >> "$config_file"
    ;;

  list)
    if [[ ! -f "$config_file" ]]; then
      exit 0
    fi
    # Strip blank lines and comments, sort, print as key=value.
    grep -vE '^[[:space:]]*(#|$)' "$config_file" \
      | sed -E 's/^([^:]+):[[:space:]]*(.*)$/\1=\2/' \
      | sort
    ;;

  *)
    echo "ERROR: unknown subcommand '$SUBCOMMAND' (expected get|set|list)" >&2
    exit 2
    ;;
esac
```

### Step 2 — Make the script executable

```bash
chmod +x scripts/state/config-system.sh
```

### Step 3 — Verify nested-key handling

Dot notation works transparently because keys are treated as opaque strings; `intensity.default` is a valid key identical to `foo` from the script's perspective. No special parsing needed.

## Must-Haves

This task addresses:

- `scripts/state/config-system.sh` supports `get`, `set`, and `list` subcommands operating on `<root>/config.yml`.
- `scripts/state/config-system.sh set` handles dot-notation nested keys.

## Verification

Run:

- `bash scripts/verify/m008-p04-config-system-subcommands.sh`
- `bash scripts/verify/m008-p04-config-system-nested.sh`

Each must exit 0 with a `PASS:` line.

## Inputs

### From Previous Tasks

- `scripts/state/resolve-root.sh` (from T01)
  - Key API: `bash resolve-root.sh [--absolute]` — emits the resolved state root to stdout; `--absolute` returns a full path rather than a repo-relative path.
  - Key behavior: resolve-root never creates directories; callers must handle directory creation themselves.

### From Disk (Pre-existing)

- `scripts/state/` — existing directory where the new script lives.

## Constraints

- Bash 3.2 compatible. No associative arrays.
- No `jq`, no `python3`. Use `grep`/`sed`/`awk` only.
- `set` must be idempotent: setting the same key twice with the same value produces identical file contents (one line for that key, no duplicates).
- Keys containing characters that break `grep -E` patterns (regex metacharacters) are out of scope for P04 — we document only alphanumeric + dots + underscores + hyphens.
- The script MUST create the root directory if it does not exist on `set` (this is the first place in the codebase that writes to the resolved root).

## Expected Output

Creating:

- `scripts/state/config-system.sh` — ~100 lines, executable.

Sample session in a temp directory:

```
$ bash scripts/state/config-system.sh set intensity.default Full
$ bash scripts/state/config-system.sh get intensity.default
Full
$ bash scripts/state/config-system.sh set intensity.default Quick
$ bash scripts/state/config-system.sh list
intensity.default=Quick
```
