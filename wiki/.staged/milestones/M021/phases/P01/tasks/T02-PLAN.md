---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M021"
name: "Create scripts/util/read-range.sh + gate"
depends_on: []
---

## Prerequisites

No upstream task dependencies. `scripts/util/` exists. The `scripts/verify/m021-p01-*.sh` naming convention is established by T01.

## Description

Create `scripts/util/read-range.sh` — a canonical wrapper that prints lines M through N (inclusive, 1-indexed) of a target file on stdout. This replaces the recurring shape `sed -n '686,1050p' file.md` that Claude Code's safety layer misclassifies as a write (because the `p` flag appears inside single quotes) and flags as quoted-brace obfuscation (M011/P05–P07 screenshots; AD-3).

Then create `scripts/verify/m021-p01-read-range.sh` — a self-contained gate that exercises happy-path range reads and three error modes (missing file, inverted range, out-of-file range).

## Steps

### Step 1: Create scripts/util/read-range.sh

Write the script at `scripts/util/read-range.sh`:

```bash
#!/usr/bin/env bash
# scripts/util/read-range.sh — Emit lines M..N of a file (inclusive, 1-indexed).
#
# Usage: read-range.sh <file> <M> <N>
#   e.g.: read-range.sh file.md 686 1050
#
# Replaces the inline `sed -n 'M,Np' file` shape that Claude Code
# flags as quoted-brace / sed-write obfuscation. The wrapper is
# allow-listed (bash scripts/util/*) and its arguments are plain
# integers, so no shape heuristic fires.
#
# Exit: 0 on success, 1 when the file is missing or unreadable,
# 2 when the range is invalid (non-integer, M<1, N<M, or N exceeds
# the file's line count).
#
# Bash 3.2 compatible.

set -u

if [ $# -ne 3 ]; then
  echo "usage: read-range.sh <file> <M> <N>" >&2
  exit 2
fi

file="$1"
m="$2"
n="$3"

# Validate file.
if [ ! -f "$file" ]; then
  echo "read-range.sh: file not found: $file" >&2
  exit 1
fi
if [ ! -r "$file" ]; then
  echo "read-range.sh: file not readable: $file" >&2
  exit 1
fi

# Validate integer shape (digits only, at least one digit).
case "$m" in
  ''|*[!0-9]*)
    echo "read-range.sh: M must be a positive integer: $m" >&2
    exit 2
    ;;
esac
case "$n" in
  ''|*[!0-9]*)
    echo "read-range.sh: N must be a positive integer: $n" >&2
    exit 2
    ;;
esac

if [ "$m" -lt 1 ]; then
  echo "read-range.sh: M must be >= 1 (got $m)" >&2
  exit 2
fi
if [ "$n" -lt "$m" ]; then
  echo "read-range.sh: N must be >= M (got M=$m N=$n)" >&2
  exit 2
fi

# Verify N does not exceed file line count.
total=$(wc -l "$file" | awk '{print $1}')
if [ "$n" -gt "$total" ]; then
  echo "read-range.sh: N=$n exceeds file line count ($total)" >&2
  exit 2
fi

# Emit the range. awk is allow-listed and the pattern is numeric
# only — no brace-in-quote ambiguity.
awk -v m="$m" -v n="$n" 'NR>=m && NR<=n { print } NR>n { exit }' "$file"
```

### Step 2: Create scripts/verify/m021-p01-read-range.sh

Write the gate at `scripts/verify/m021-p01-read-range.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p01-read-range.sh — Gate for scripts/util/read-range.sh
# Exits 0 when all assertions hold, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="${REPO_ROOT}/scripts/util/read-range.sh"

fail_count=0

assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fail_count=$((fail_count + 1))
  fi
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Build a 10-line fixture.
i=1
while [ "$i" -le 10 ]; do
  printf "line-%s\n" "$i" >> "$tmp"
  i=$((i + 1))
done

# 1. Happy path: lines 3..5.
got=$(bash "$WRAPPER" "$tmp" 3 5)
want=$(printf "line-3\nline-4\nline-5")
assert_eq "reads lines 3..5" "$want" "$got"

# 2. Single-line range: line 1.
got=$(bash "$WRAPPER" "$tmp" 1 1)
assert_eq "reads single line 1..1" "line-1" "$got"

# 3. Missing file: exit 1.
bash "$WRAPPER" /no/such/file 1 5 >/dev/null 2>&1
rc=$?
assert_eq "missing file exits 1" "1" "$rc"

# 4. Inverted range: exit 2.
bash "$WRAPPER" "$tmp" 5 3 >/dev/null 2>&1
rc=$?
assert_eq "inverted range exits 2" "2" "$rc"

# 5. Out-of-file range: exit 2.
bash "$WRAPPER" "$tmp" 5 9999 >/dev/null 2>&1
rc=$?
assert_eq "out-of-file range exits 2" "2" "$rc"

# 6. Non-integer arg: exit 2.
bash "$WRAPPER" "$tmp" abc 5 >/dev/null 2>&1
rc=$?
assert_eq "non-integer M exits 2" "2" "$rc"

# 7. Missing args: exit 2.
bash "$WRAPPER" "$tmp" 3 >/dev/null 2>&1
rc=$?
assert_eq "missing N arg exits 2" "2" "$rc"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-read-range.sh"
  exit 0
fi
echo "FAIL: m021-p01-read-range.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `scripts/util/read-range.sh` emits the inclusive, 1-indexed line range on stdout.
- Exits 0 on success, 1 on missing/unreadable file, 2 on invalid range or non-integer bounds.
- Gate exercises happy path + single-line range + all documented error modes.
- Both files are Bash 3.2 compatible.

## Verification

- `bash scripts/verify/m021-p01-read-range.sh` exits 0 with final line `PASS: m021-p01-read-range.sh`.

## Inputs

### From Disk (Pre-existing)

- `scripts/util/` — existing util directory.
- `scripts/verify/` — where the gate script lands; discovered by `scripts/verify/run-suite.sh`.

## Constraints

- Bash 3.2 compatible.
- No dependency on jq/node/python. `awk` and `wc` are POSIX-standard and already used elsewhere in the orchestrator.
- Range semantics are inclusive at both ends and 1-indexed — this matches the `sed -n 'M,Np'` semantics the wrapper replaces, so callers can mechanically translate from existing task plans.
- On a valid range the wrapper emits nothing to stderr; error messages go to stderr only on non-zero exit.
- Gate script uses only single-script-file-shape commands (AD-19). No `diff <(...) <(...)`.

## Expected Output

- `scripts/util/read-range.sh` created.
- `scripts/verify/m021-p01-read-range.sh` created.
- `bash scripts/verify/m021-p01-read-range.sh` → final line `PASS: m021-p01-read-range.sh`, exit 0.
