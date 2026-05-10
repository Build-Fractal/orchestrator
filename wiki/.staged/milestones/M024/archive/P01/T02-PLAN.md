---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M024"
name: "Author the intake-id allocator"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/intake-proposal.md` exists. T02 does not read the template — the dependency is logical (T02 produces an `intake_id` value the template's `{{intake_id}}` placeholder consumes via T04 substitution).
- `.orchestrator/intake/` directory may or may not exist on disk; the allocator must handle both cases.
- `specs/` directory exists with `NNN-<slug>/spec.md` entries (e.g., `specs/028-universal-intake-routing/spec.md`).

## Description

Author `scripts/intake/intake-id-allocate.sh` — a portable shell script that emits the `intake_id` value for a single `evaluate` invocation.

Two allocation modes per FR-11 + AD-2:

- **Spec-path mode**: When invoked with `--spec-path <path>`, the allocator extracts the spec slug from the path (`specs/028-universal-intake-routing/spec.md` → `028-universal-intake-routing`) and emits that as the intake-id. The proposal will be written to `.orchestrator/intake/<spec-slug>/proposal.md`. This keeps the proposal inside the spec ecosystem and makes [M013](../../../../milestones/M013/index.md) / [M014](../../../../milestones/M014/index.md) round-trip trivial.
- **Counter mode**: When invoked with `--input <string>` (no spec path), the allocator scans `.orchestrator/intake/` for existing entries, picks `max(NNN) + 1` (zero-padded to 3 digits), and combines with a short slug derived from the first 1–4 words of the input (lowercased, hyphenated, ≤24 chars). Output: `<NNN>-<short-slug>` (e.g., `001-status-cache`).

The allocator writes nothing to disk — it only emits `intake_id=<value>` to stdout. The directory creation is T04's responsibility (the emitter creates `.orchestrator/intake/<intake_id>/` as part of the write).

## Steps

1. **Create the directory** if it does not exist: `mkdir -p scripts/intake`. Confirm with `ls scripts/intake/` (should be empty before this task).

2. **Write the script** at `scripts/intake/intake-id-allocate.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/intake-id-allocate.sh
# M024/P01/T02 — Allocate the intake_id for an `evaluate` invocation.
#
# Two modes:
#   --spec-path <path>  Reuse the spec slug as the intake_id (FR-11).
#   --input <string>    Counter-allocate <NNN>-<short-slug> (AD-2).
#
# Emits one line `intake_id=<value>` to stdout. Exit 0 on success, 2 on usage
# error. Writes nothing — directory creation is the caller's responsibility.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INTAKE_DIR="$ROOT/.orchestrator/intake"

usage() {
  echo "usage: intake-id-allocate.sh --spec-path <path> | --input <string>" >&2
  exit 2
}

MODE=""
SPEC_PATH=""
INPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) MODE="spec"; SPEC_PATH="$2"; shift 2 ;;
    --input)     MODE="input"; INPUT="$2"; shift 2 ;;
    --intake-dir) INTAKE_DIR="$2"; shift 2 ;;  # test-only override
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

if [ -z "$MODE" ]; then
  usage
fi

# Mode 1: spec-path → reuse spec slug.
if [ "$MODE" = "spec" ]; then
  if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
    echo "intake-id-allocate.sh: spec path '$SPEC_PATH' not found" >&2
    exit 2
  fi
  # specs/028-universal-intake-routing/spec.md → 028-universal-intake-routing
  slug="$(basename "$(dirname "$SPEC_PATH")")"
  if [ -z "$slug" ] || [ "$slug" = "." ] || [ "$slug" = "/" ]; then
    echo "intake-id-allocate.sh: cannot extract slug from '$SPEC_PATH'" >&2
    exit 2
  fi
  echo "intake_id=$slug"
  exit 0
fi

# Mode 2: input → counter + short-slug.
# (a) Counter: max(existing NNN) + 1, zero-padded to 3 digits.
next=1
if [ -d "$INTAKE_DIR" ]; then
  for entry in "$INTAKE_DIR"/*; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    # Match leading 3 digits.
    case "$name" in
      [0-9][0-9][0-9]-*)
        n=$(echo "$name" | cut -c1-3)
        # Strip leading zeros for arithmetic without octal interpretation.
        n=$(echo "$n" | sed 's/^0*//')
        [ -z "$n" ] && n=0
        if [ "$n" -ge "$next" ]; then
          next=$((n + 1))
        fi
        ;;
    esac
  done
fi
nnn=$(printf '%03d' "$next")

# (b) Short-slug from first 1–4 words: lowercase, alnum + hyphens, ≤24 chars.
short="$(echo "$INPUT" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c 'a-z0-9 \n' ' ' \
  | tr -s ' ' \
  | cut -d ' ' -f 1-4 \
  | tr ' ' '-' \
  | sed 's/^-//; s/-$//')"

# Truncate to 24 chars, trim trailing hyphen.
short=$(echo "$short" | cut -c1-24 | sed 's/-$//')
if [ -z "$short" ]; then
  short="intake"
fi

echo "intake_id=${nnn}-${short}"
exit 0
```

3. **Make it executable**: `chmod +x scripts/intake/intake-id-allocate.sh`.

4. **Write the verify script** at `scripts/verify/m024-p01-intake-id-allocate.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-intake-id-allocate.sh
# Exercises the allocator against four cases: spec-path, empty intake dir,
# populated intake dir, missing input.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ALLOC="$ROOT/scripts/intake/intake-id-allocate.sh"

if [ ! -x "$ALLOC" ]; then
  echo "FAIL: $ALLOC not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case A — spec-path mode.
mkdir -p "$tmp/specs/099-foo-bar"
touch "$tmp/specs/099-foo-bar/spec.md"
out_a=$(bash "$ALLOC" --spec-path "$tmp/specs/099-foo-bar/spec.md" || echo "ERR")
case "$out_a" in
  intake_id=099-foo-bar) ;;
  *) echo "FAIL: spec-path mode emitted '$out_a' (expected intake_id=099-foo-bar)"; exit 1 ;;
esac

# Case B — counter mode against empty intake dir.
mkdir -p "$tmp/empty"
out_b=$(bash "$ALLOC" --input "Add a status cache for the dispatcher" --intake-dir "$tmp/empty" || echo "ERR")
case "$out_b" in
  intake_id=001-add-a-status-cache) ;;
  *) echo "FAIL: empty-dir counter emitted '$out_b' (expected intake_id=001-add-a-status-cache)"; exit 1 ;;
esac

# Case C — counter mode against intake dir with 003 + 005.
mkdir -p "$tmp/populated/003-old" "$tmp/populated/005-newer" "$tmp/populated/not-a-counter"
out_c=$(bash "$ALLOC" --input "Fix race condition" --intake-dir "$tmp/populated" || echo "ERR")
case "$out_c" in
  intake_id=006-fix-race-condition) ;;
  *) echo "FAIL: populated-dir counter emitted '$out_c' (expected intake_id=006-fix-race-condition)"; exit 1 ;;
esac

# Case D — usage error.
if bash "$ALLOC" 2>/dev/null; then
  echo "FAIL: no-arg invocation should exit non-zero"
  exit 1
fi

echo "PASS: intake-id-allocate.sh — spec-path, empty-counter, populated-counter, usage-error"
exit 0
```

## Must-Haves

- `scripts/intake/intake-id-allocate.sh` exists and is executable (`chmod +x`).
- Spec-path mode emits `intake_id=<spec-slug>` extracted from the path.
- Counter mode emits `intake_id=<NNN>-<short-slug>` with `<NNN> = max(existing) + 1` zero-padded.
- Counter starts at `001` when intake dir is empty.
- Short-slug is derived from first 1–4 words of input, lowercased, hyphenated, ≤24 chars.
- Empty input falls back to slug `intake` (so the script never emits a bare `<NNN>-`).
- Usage error (no args) exits 2 with a message on stderr.

## Verification

```
bash scripts/verify/m024-p01-intake-id-allocate.sh
```

Expected output (exit 0): `PASS: intake-id-allocate.sh — spec-path, empty-counter, populated-counter, usage-error`

## Inputs

### From Previous Tasks

- `templates/intake-proposal.md` (from T01) — not read directly; consumed via T04 substitution. T02 only emits `intake_id=<value>` to stdout. The template's `{{intake_id}}` placeholder reads this value.

### From Disk (Pre-existing)

- `.orchestrator/intake/` (may or may not exist) — counter mode scans for existing `<NNN>-*` directories.
- `specs/<NNN>-<slug>/spec.md` (one or more) — spec-path mode extracts the slug from the directory name.

## Constraints

- POSIX sh + bash 3.2 portable. No bash 4+ features (no associative arrays, no `${var,,}`).
- Writes nothing to disk. Caller (T04 emitter) is responsible for `mkdir -p .orchestrator/intake/<id>/`.
- No conversus invocations, no knowledge writes (SB-3).
- No `<TODO:` markers (DC-3).
- `--intake-dir <path>` is a test-only override; production calls always use the project root's `.orchestrator/intake/`.
- Octal trap: when stripping leading zeros from `NNN`, use `sed 's/^0*//'` not `$((10#$n))` — the latter is bashism.

## Expected Output

`scripts/intake/intake-id-allocate.sh` exists, is executable, and `bash scripts/verify/m024-p01-intake-id-allocate.sh` exits 0 with the `PASS:` line.
