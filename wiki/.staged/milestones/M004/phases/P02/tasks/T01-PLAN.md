---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M004"
name: "errors.sh — Error Taxonomy and emit_result"
depends_on: []
---

## Description

Implement `scripts/lib/errors.sh` — a Bash 3.2 compatible sourced library that defines the orchestrator's closed error taxonomy and provides `emit_result`, the mandatory final-line emitter for every engine-managed script. This library is the foundation for Principle II's amendment (Evidence Before Claims — structured events and results are mandatory). Every other P02 library sources this one; every P06 script update will source it as well.

The taxonomy has exactly 6 kinds per FR-220:
- `CONFIG` — misconfiguration (missing config file, invalid field value)
- `STATE` — invalid state transition or corrupted state (lock held, summary missing)
- `DISPATCH` — agent dispatch failure (rate limit, timeout, all fallbacks exhausted)
- `VERIFY` — verification failed (must-haves missing, artifacts invalid)
- `BUDGET` — budget exceeded (cost or duration cap hit)
- `IO` — filesystem or subprocess I/O failure (file not found, pipe broken)

`emit_result` outputs exactly one line to stdout in the form:
```
RESULT:{"status":"<ok|error>","error_kind":"<KIND or empty>","detail":"<quoted description>"}
```
This is a grep-parseable single line. No jq. Quoting uses simple double-quote escaping for the detail field.

This implements:
- FR-220 (closed error taxonomy + emit_result)
- Principle II amendment (mandatory emit_result on engine-managed script completion)
- NFR-200 (Bash 3.2 compatible)
- NFR-203 (double-sourcing guard)
- AP-003 remedy (double-sourcing guard on every sourced library)

## Steps

### Step 1: Create `scripts/lib/` directory if needed

```bash
mkdir -p scripts/lib
```

### Step 2: Create `scripts/lib/errors.sh`

Write the following content verbatim to `scripts/lib/errors.sh`:

```bash
#!/usr/bin/env bash
# scripts/lib/errors.sh — Orchestrator error taxonomy and result emitter.
#
# Source this file to get:
#   - Closed error taxonomy: ORCH_ERR_CONFIG, ORCH_ERR_STATE, ORCH_ERR_DISPATCH,
#     ORCH_ERR_VERIFY, ORCH_ERR_BUDGET, ORCH_ERR_IO
#   - emit_result <status> [error_kind] [detail]  — prints a single RESULT: line
#   - orch_is_error_kind <value>                  — validates a value against the taxonomy
#
# Bash 3.2 compatible (NFR-200). No associative arrays, no readarray, no mapfile.
# Double-sourcing guard per NFR-203 / ANTIPATTERNS AP-003.
#
# Constitution: Principle II (Evidence Before Claims) — structured results are
# mandatory. A script that runs without emitting a final RESULT: line is a silent
# failure.

# --- Double-sourcing guard ---
[ -n "${_ERRORS_SOURCED:-}" ] && return 0
_ERRORS_SOURCED=1

# --- Error taxonomy (closed set, FR-220) ---
ORCH_ERR_CONFIG="CONFIG"
ORCH_ERR_STATE="STATE"
ORCH_ERR_DISPATCH="DISPATCH"
ORCH_ERR_VERIFY="VERIFY"
ORCH_ERR_BUDGET="BUDGET"
ORCH_ERR_IO="IO"

# Newline-separated for iteration without associative arrays.
ORCH_ERR_KINDS="CONFIG
STATE
DISPATCH
VERIFY
BUDGET
IO"

export ORCH_ERR_CONFIG ORCH_ERR_STATE ORCH_ERR_DISPATCH ORCH_ERR_VERIFY ORCH_ERR_BUDGET ORCH_ERR_IO ORCH_ERR_KINDS

# orch_is_error_kind <value>
# Returns 0 if <value> is in the closed taxonomy, 1 otherwise.
orch_is_error_kind() {
  local v="$1"
  [ -z "$v" ] && return 1
  case "$v" in
    CONFIG|STATE|DISPATCH|VERIFY|BUDGET|IO) return 0 ;;
    *) return 1 ;;
  esac
}

# _orch_errors_escape <string>
# Minimal JSON string escaping for the detail field: escapes backslash, double
# quote, and control characters (newline, tab, carriage return). Internal.
_orch_errors_escape() {
  local s="$1"
  # Order matters: backslashes first.
  s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  # Convert newlines and tabs to escaped form.
  s="$(printf '%s' "$s" | tr '\n' ' ' | tr '\r' ' ' | tr '\t' ' ')"
  printf '%s' "$s"
}

# emit_result <status> [error_kind] [detail]
# Prints a single-line RESULT: entry to stdout. Called exactly once per script
# at completion. <status> is "ok" or "error". For "error", error_kind MUST be a
# taxonomy value. detail is a free-form human-readable description.
#
# Examples:
#   emit_result ok "" "phase advanced to P03"
#   emit_result error CONFIG "routing.yaml missing required field models.heavy.id"
#   emit_result error DISPATCH "all models in fallback chain exhausted"
emit_result() {
  local status="${1:-error}"
  local kind="${2:-}"
  local detail="${3:-}"

  case "$status" in
    ok|error) ;;
    *)
      status="error"
      kind="${kind:-CONFIG}"
      detail="invalid status passed to emit_result: $detail"
      ;;
  esac

  if [ "$status" = "error" ] && [ -n "$kind" ] && ! orch_is_error_kind "$kind"; then
    detail="unknown error_kind '$kind' (caller: $detail)"
    kind="CONFIG"
  fi

  local escaped_detail
  escaped_detail="$(_orch_errors_escape "$detail")"

  printf 'RESULT:{"status":"%s","error_kind":"%s","detail":"%s"}\n' \
    "$status" "$kind" "$escaped_detail"
}
```

### Step 3: Make the file executable (optional but matches convention)

```bash
chmod +x scripts/lib/errors.sh
```

Sourced libraries do not strictly need the executable bit, but existing libraries (`scripts/knowledge/lib/staleness.sh`) have it. Match the convention.

### Step 4: Verify

Run these verification commands from the project root:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# File exists with minimum lines
test -f scripts/lib/errors.sh && echo "PASS: file exists" || echo "FAIL"
lines=$(wc -l < scripts/lib/errors.sh | tr -d ' ')
test "$lines" -ge 60 && echo "PASS: $lines lines (min 60)" || echo "FAIL: only $lines lines"

# Double-sourcing guard
head -5 scripts/lib/errors.sh | grep -q '_ERRORS_SOURCED' && echo "PASS: guard" || echo "FAIL: no guard"

# Taxonomy constants
for k in CONFIG STATE DISPATCH VERIFY BUDGET IO; do
  grep -q "ORCH_ERR_${k}" scripts/lib/errors.sh && echo "PASS: $k" || echo "FAIL: $k"
done

# Functions
grep -q '^emit_result()' scripts/lib/errors.sh && echo "PASS: emit_result" || echo "FAIL"
grep -q '^orch_is_error_kind()' scripts/lib/errors.sh && echo "PASS: orch_is_error_kind" || echo "FAIL"

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' scripts/lib/errors.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/errors.sh && echo "PASS: no proc sub" || echo "FAIL"

# Double-sourcing is idempotent
bash -c '. scripts/lib/errors.sh; . scripts/lib/errors.sh; type emit_result >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

# Behavioral: emit_result output format
out="$(bash -c '. scripts/lib/errors.sh; emit_result ok "" "hello world"')"
echo "$out" | grep -q '^RESULT:{"status":"ok"' && echo "PASS: ok format" || echo "FAIL: $out"

out="$(bash -c '. scripts/lib/errors.sh; emit_result error DISPATCH "all fallbacks exhausted"')"
echo "$out" | grep -q '"error_kind":"DISPATCH"' && echo "PASS: error kind" || echo "FAIL: $out"

# Behavioral: unknown kind gets remapped to CONFIG
out="$(bash -c '. scripts/lib/errors.sh; emit_result error WEIRD "bad"')"
echo "$out" | grep -q '"error_kind":"CONFIG"' && echo "PASS: unknown remapped" || echo "FAIL: $out"
```

Every line should print `PASS:`.

## Must-Haves

### Truths

- `scripts/lib/errors.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/errors.sh | grep -q '_ERRORS_SOURCED'`
- All 6 taxonomy kinds are defined as constants
  - Check: `for k in CONFIG STATE DISPATCH VERIFY BUDGET IO; do grep -q "ORCH_ERR_${k}" scripts/lib/errors.sh || exit 1; done && echo PASS`
- `emit_result` function is defined
  - Check: `grep -q '^emit_result()' scripts/lib/errors.sh`
- `orch_is_error_kind` function is defined
  - Check: `grep -q '^orch_is_error_kind()' scripts/lib/errors.sh`
- Bash 3.2 compatible (no associative arrays, readarray, mapfile, process substitution redirect)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/errors.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/errors.sh`
- Library can be sourced twice without re-executing body (idempotent)
  - Check: `bash -c '. scripts/lib/errors.sh; . scripts/lib/errors.sh; type emit_result >/dev/null'`
- `emit_result ok` produces a RESULT: line with status=ok
  - Check: `bash -c '. scripts/lib/errors.sh; emit_result ok "" "t"' | grep -q '^RESULT:{"status":"ok"'`
- `emit_result error <kind>` records the error kind
  - Check: `bash -c '. scripts/lib/errors.sh; emit_result error DISPATCH "x"' | grep -q '"error_kind":"DISPATCH"'`

### Artifacts

- `scripts/lib/errors.sh` (min 60 lines, contains "_ERRORS_SOURCED")

### Key Links

- `scripts/lib/errors.sh` → `.specify/memory/constitution.md` (implements Principle II amendment)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T01 Verification ==="

test -f scripts/lib/errors.sh && echo "PASS: file exists" || { echo "FAIL: file missing"; exit 1; }
lines=$(wc -l < scripts/lib/errors.sh | tr -d ' ')
test "$lines" -ge 60 && echo "PASS: $lines lines" || echo "FAIL: only $lines lines"

head -5 scripts/lib/errors.sh | grep -q '_ERRORS_SOURCED' && echo "PASS: guard" || echo "FAIL: no guard"

for k in CONFIG STATE DISPATCH VERIFY BUDGET IO; do
  grep -q "ORCH_ERR_${k}" scripts/lib/errors.sh && echo "PASS: $k" || echo "FAIL: $k"
done

grep -q '^emit_result()' scripts/lib/errors.sh && echo "PASS: emit_result defined" || echo "FAIL"
grep -q '^orch_is_error_kind()' scripts/lib/errors.sh && echo "PASS: orch_is_error_kind defined" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/errors.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/errors.sh && echo "PASS: no proc sub" || echo "FAIL"

bash -c '. scripts/lib/errors.sh; . scripts/lib/errors.sh; type emit_result >/dev/null' && echo "PASS: double-source idempotent" || echo "FAIL"

bash -c '. scripts/lib/errors.sh; emit_result ok "" "hello"' | grep -q '^RESULT:{"status":"ok"' && echo "PASS: ok format" || echo "FAIL"
bash -c '. scripts/lib/errors.sh; emit_result error DISPATCH "boom"' | grep -q '"error_kind":"DISPATCH"' && echo "PASS: error kind" || echo "FAIL"
bash -c '. scripts/lib/errors.sh; emit_result error BOGUS "bad"' | grep -q '"error_kind":"CONFIG"' && echo "PASS: unknown remapped" || echo "FAIL"

echo "=== T01 complete ==="
```

## Inputs

### From Previous Tasks

None — T01 is the first task of P02 and has no upstream task dependencies.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — Principle II (Evidence Before Claims) amendment requires structured event emission and emit_result from engine-managed scripts. Principle IX (Reproducibility) forbids inline non-deterministic values — this library has none (taxonomy is static).
- `ANTIPATTERNS.md` — AP-003 documents the double-sourcing guard pattern that every new library MUST include. Uses `_LIBNAME_SOURCED` convention.
- `scripts/knowledge/lib/staleness.sh` (lines 1-3) — Reference for the exact double-sourcing guard pattern:
  ```bash
  #!/usr/bin/env bash
  [ -n "${_STALENESS_SOURCED:-}" ] && return 0
  _STALENESS_SOURCED=1
  ```
  This task uses `_ERRORS_SOURCED` as the unique identifier.
- `specs/004-engine-architecture/spec.md` — FR-220 defines the closed error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO). US8 describes the error taxonomy user story.

## Expected Output

The file `scripts/lib/errors.sh` containing:
- Shebang (`#!/usr/bin/env bash`)
- Block comment describing purpose, functions, and constitution reference
- Double-sourcing guard as the first executable lines (`_ERRORS_SOURCED`)
- 6 exported constants: `ORCH_ERR_CONFIG` through `ORCH_ERR_IO`, plus `ORCH_ERR_KINDS` newline-separated list
- `orch_is_error_kind <value>` validator function using a `case` statement
- `_orch_errors_escape <string>` internal helper for JSON string escaping
- `emit_result <status> [error_kind] [detail]` function producing exactly one `RESULT:{...}` line to stdout
- File ≥ 60 lines, Bash 3.2 compatible, no inline `date`, no `sed -i`, no process substitution as redirect target
