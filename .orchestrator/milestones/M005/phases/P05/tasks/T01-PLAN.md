---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M005"
name: "Create verdicts.sh verdict protocol library and verification scripts"
depends_on: []
---

## Description

Create two deliverables:

1. **`scripts/lib/verdicts.sh`** — the verdict protocol library that provides
   structured verdict emission and parsing for hook scripts and gate
   integrations. This library defines the four-value verdict enum
   (PASS, BLOCK, WARN, NEEDS_REVIEW) and provides `emit_verdict` to emit
   structured `VERDICT:` lines to stdout and `parse_verdict` to decompose
   those lines into their components. Follows the same structural patterns
   as `scripts/lib/errors.sh` (double-sourcing guard, exported constants,
   validation function, structured line format).

2. **Five verification scripts** under `scripts/verify/p05-*.sh` for all
   phase P05 must-haves. These are created here so every task in the phase
   can run its relevant verification from the start.

### Verdict Protocol Format

The `VERDICT:` line follows the same design principles as `EVENT:` and
`RESULT:` lines — a single structured line on stdout that downstream
consumers can grep for and parse mechanically.

Format:

```
VERDICT:<verdict> reason="<human-readable reason>"
```

Where `<verdict>` is one of: `PASS`, `BLOCK`, `WARN`, `NEEDS_REVIEW`.

Examples:

```
VERDICT:PASS reason="all verification checks passed"
VERDICT:BLOCK reason="payload exceeds 100k token limit"
VERDICT:WARN reason="3 optional sections missing from instruction file"
VERDICT:NEEDS_REVIEW reason="cost estimate exceeds budget threshold"
```

### Verdict Constants

Following the errors.sh pattern, constants are exported as:

- `ORCH_VERDICT_PASS="PASS"`
- `ORCH_VERDICT_BLOCK="BLOCK"`
- `ORCH_VERDICT_WARN="WARN"`
- `ORCH_VERDICT_NEEDS_REVIEW="NEEDS_REVIEW"`

And a newline-separated list for iteration:

```
ORCH_VERDICT_KINDS="PASS
BLOCK
WARN
NEEDS_REVIEW"
```

### Functions

**`emit_verdict <verdict> <reason>`**

Emits a single `VERDICT:` line to stdout. Validates that `<verdict>` is in
the closed verdict set. If the verdict is invalid, emits a WARN verdict
with the original invalid verdict noted in the reason. The reason string
is quoted if it contains whitespace (following the events.sh quoting
convention).

**`parse_verdict <line>`**

Parses a `VERDICT:` line and outputs three tab-separated fields:
`verdict<TAB>reason`. Returns 0 on success, 1 if the line is not a valid
VERDICT line. This function is used by hooks.sh to extract verdict
information from hook stdout.

**`orch_is_verdict <value>`**

Returns 0 if `<value>` is in the closed verdict set, 1 otherwise. Used
for input validation.

## Steps

### Step 1 — Create `scripts/lib/verdicts.sh`

Create the verdict protocol library. The file structure follows errors.sh:

```bash
#!/usr/bin/env bash
# scripts/lib/verdicts.sh — Gate verdict protocol for hook scripts.
# Provides structured verdict emission and parsing.
#
# Source this file to get:
#   - Closed verdict set: ORCH_VERDICT_PASS, ORCH_VERDICT_BLOCK,
#     ORCH_VERDICT_WARN, ORCH_VERDICT_NEEDS_REVIEW
#   - emit_verdict <verdict> <reason>  — prints a single VERDICT: line
#   - parse_verdict <line>             — extracts verdict and reason
#   - orch_is_verdict <value>          — validates against the verdict set
#
# Verdict line format:
#   VERDICT:<verdict> reason="<reason>"
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
# AD-3: verdict schema is provider-agnostic.

# --- Double-sourcing guard ---
[ -n "${_VERDICTS_SOURCED:-}" ] && return 0
_VERDICTS_SOURCED=1

# --- Verdict constants (closed set, AD-3) ---
ORCH_VERDICT_PASS="PASS"
ORCH_VERDICT_BLOCK="BLOCK"
ORCH_VERDICT_WARN="WARN"
ORCH_VERDICT_NEEDS_REVIEW="NEEDS_REVIEW"

ORCH_VERDICT_KINDS="PASS
BLOCK
WARN
NEEDS_REVIEW"

export ORCH_VERDICT_PASS ORCH_VERDICT_BLOCK ORCH_VERDICT_WARN ORCH_VERDICT_NEEDS_REVIEW ORCH_VERDICT_KINDS

# orch_is_verdict <value>
# Returns 0 if <value> is in the closed verdict set, 1 otherwise.
orch_is_verdict() {
  local v="$1"
  [ -z "$v" ] && return 1
  case "$v" in
    PASS|BLOCK|WARN|NEEDS_REVIEW) return 0 ;;
    *) return 1 ;;
  esac
}

# _verdicts_quote <string>
# Shell-safe quoting for verdict reason values: if the value contains
# whitespace or double quotes, wrap in double quotes and escape internal
# quotes. Follows the events.sh _orch_events_quote pattern.
_verdicts_quote() {
  local s="$1"
  case "$s" in
    *[[:space:]]*|*'"'*)
      s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
      printf '"%s"' "$s"
      ;;
    *)
      printf '%s' "$s"
      ;;
  esac
}

# emit_verdict <verdict> <reason>
# Prints a single VERDICT: line to stdout. Validates that <verdict> is
# in the closed set. If invalid, downgrades to WARN and includes the
# original verdict in the reason.
emit_verdict() {
  local verdict="${1:-}"
  local reason="${2:-}"

  if [ -z "$verdict" ]; then
    verdict="WARN"
    reason="emit_verdict called without verdict: ${reason}"
  elif ! orch_is_verdict "$verdict"; then
    reason="unknown verdict '${verdict}': ${reason}"
    verdict="WARN"
  fi

  local quoted_reason
  quoted_reason="$(_verdicts_quote "$reason")"

  printf 'VERDICT:%s reason=%s\n' "$verdict" "$quoted_reason"
}

# parse_verdict <line>
# Parses a VERDICT: line and outputs tab-separated fields:
#   verdict<TAB>reason
# Returns 0 on successful parse, 1 if the line is not a valid VERDICT line.
#
# Handles both quoted and unquoted reason values:
#   VERDICT:PASS reason="all checks passed"
#   VERDICT:PASS reason=ok
parse_verdict() {
  local line="$1"

  # Must start with VERDICT:
  case "$line" in
    VERDICT:*) ;;
    *) return 1 ;;
  esac

  # Extract verdict (between VERDICT: and first space)
  local after_prefix="${line#VERDICT:}"
  local verdict="${after_prefix%% *}"

  # Validate verdict
  if ! orch_is_verdict "$verdict"; then
    return 1
  fi

  # Extract reason value
  local reason=""
  case "$after_prefix" in
    *reason=\"*)
      # Quoted reason: extract between first =" and last "
      reason="${after_prefix#*reason=\"}"
      reason="${reason%\"}"
      ;;
    *reason=*)
      # Unquoted reason: everything after reason=
      reason="${after_prefix#*reason=}"
      ;;
  esac

  printf '%s\t%s\n' "$verdict" "$reason"
  return 0
}
```

### Step 2 — Create verification scripts

Create five verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant).

**`scripts/verify/p05-verdicts-lib.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/lib/verdicts.sh exists with required exports and functions.
set -eu
f="scripts/lib/verdicts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_VERDICTS_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'emit_verdict' "$f" || { echo "FAIL: emit_verdict function missing"; exit 1; }
grep -q 'parse_verdict' "$f" || { echo "FAIL: parse_verdict function missing"; exit 1; }
grep -q 'orch_is_verdict' "$f" || { echo "FAIL: orch_is_verdict function missing"; exit 1; }
grep -q 'ORCH_VERDICT_PASS' "$f" || { echo "FAIL: ORCH_VERDICT_PASS constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_BLOCK' "$f" || { echo "FAIL: ORCH_VERDICT_BLOCK constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_WARN' "$f" || { echo "FAIL: ORCH_VERDICT_WARN constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_NEEDS_REVIEW' "$f" || { echo "FAIL: ORCH_VERDICT_NEEDS_REVIEW constant missing"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 60 || { echo "FAIL: expected at least 60 lines, found $lines"; exit 1; }
echo "PASS: verdicts.sh exists with all required exports ($lines lines)"
```

**`scripts/verify/p05-hooks-verdict-parsing.sh`**

```bash
#!/usr/bin/env bash
# Verifies hooks.sh has been updated to capture and parse VERDICT lines.
set -eu
f="scripts/lib/hooks.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'VERDICT' "$f" || { echo "FAIL: hooks.sh does not reference VERDICT"; exit 1; }
grep -q 'verdicts.sh' "$f" || { echo "FAIL: hooks.sh does not source verdicts.sh"; exit 1; }
grep -q 'parse_verdict' "$f" || { echo "FAIL: hooks.sh does not call parse_verdict"; exit 1; }
echo "PASS: hooks.sh captures and parses VERDICT lines"
```

**`scripts/verify/p05-provider-convention-doc.sh`**

```bash
#!/usr/bin/env bash
# Verifies references/provider-convention.md exists with required sections.
set -eu
f="references/provider-convention.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'Provider Shell Convention' "$f" || grep -q 'Provider Convention' "$f" || { echo "FAIL: title heading missing"; exit 1; }
grep -q '\-\-task' "$f" || { echo "FAIL: --task argument not documented"; exit 1; }
grep -q '\-\-output' "$f" || { echo "FAIL: --output argument not documented"; exit 1; }
grep -q 'ORCH_RUN_ID' "$f" || { echo "FAIL: ORCH_RUN_ID env var not documented"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: cost_source not documented"; exit 1; }
grep -q 'VERDICT' "$f" || { echo "FAIL: verdict integration not documented"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 80 || { echo "FAIL: expected at least 80 lines, found $lines"; exit 1; }
echo "PASS: provider-convention.md exists with required sections ($lines lines)"
```

**`scripts/verify/p05-check-providers.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/diagnostics/check-providers.sh exists with expected structure.
set -eu
f="scripts/diagnostics/check-providers.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
grep -q 'DOCTOR:PROVIDERS' "$f" || { echo "FAIL: DOCTOR:PROVIDERS output missing"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 40 || { echo "FAIL: expected at least 40 lines, found $lines"; exit 1; }
echo "PASS: check-providers.sh exists with DOCTOR:PROVIDERS output ($lines lines)"
```

**`scripts/verify/p05-doctor-integration.sh`**

```bash
#!/usr/bin/env bash
# Verifies run-doctor.sh includes a call to check-providers.sh.
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-providers.sh' "$f" || { echo "FAIL: run-doctor.sh does not reference check-providers.sh"; exit 1; }
echo "PASS: run-doctor.sh includes provider conformance check"
```

Make all scripts executable:

```bash
chmod +x scripts/verify/p05-*.sh
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "verdicts.sh exists at `scripts/lib/verdicts.sh` with
  double-sourcing guard and exports `emit_verdict`, `parse_verdict`, and
  verdict constants (PASS, BLOCK, WARN, NEEDS_REVIEW)."
- **Artifacts**: `scripts/lib/verdicts.sh`, all five `scripts/verify/p05-*.sh`
  scripts.

## Verification

Run the verification script:

```bash
bash scripts/verify/p05-verdicts-lib.sh
```

Should print PASS.

The remaining verification scripts (`p05-hooks-verdict-parsing.sh`,
`p05-provider-convention-doc.sh`, `p05-check-providers.sh`,
`p05-doctor-integration.sh`) will FAIL until T02, T03, and T04 complete.
This is expected.

Smoke test emit_verdict and parse_verdict:

```bash
(
  . scripts/lib/verdicts.sh
  emit_verdict PASS "all checks green"
  emit_verdict BLOCK "budget exceeded"
  emit_verdict INVALID "testing bad input"
)
```

Expected output:

```
VERDICT:PASS reason="all checks green"
VERDICT:BLOCK reason="budget exceeded"
VERDICT:WARN reason="unknown verdict 'INVALID': testing bad input"
```

Smoke test parse_verdict:

```bash
(
  . scripts/lib/verdicts.sh
  echo "VERDICT:PASS reason=\"all good\"" | while IFS= read -r line; do
    parse_verdict "$line"
  done
)
```

Expected output: `PASS	all good`

### Files Touched By This Task

- `scripts/lib/verdicts.sh` (create)
- `scripts/verify/p05-verdicts-lib.sh` (create)
- `scripts/verify/p05-hooks-verdict-parsing.sh` (create)
- `scripts/verify/p05-provider-convention-doc.sh` (create)
- `scripts/verify/p05-check-providers.sh` (create)
- `scripts/verify/p05-doctor-integration.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — reference implementation for the library pattern.
  Key structural elements to replicate:
  - Double-sourcing guard: `[ -n "${_ERRORS_SOURCED:-}" ] && return 0`
  - Constant exports: `ORCH_ERR_CONFIG="CONFIG"` etc.
  - Validation function: `orch_is_error_kind()` using case statement
  - Structured line format: `RESULT:{"status":"...","error_kind":"...","detail":"..."}`
  - Escaping helper: `_orch_errors_escape()`

- `scripts/lib/events.sh` — reference for the quoting convention used in
  structured output lines. Key pattern: `_orch_events_quote()` wraps values
  containing whitespace in double quotes.

- `scripts/lib/hash.sh` — reference for the double-sourcing guard pattern
  and the minimal-dependency (no jq) approach.

## Expected Output

After completing this task:

1. `scripts/lib/verdicts.sh` exists with at least 60 lines, double-sourcing
   guard, four verdict constants exported, `emit_verdict`, `parse_verdict`,
   and `orch_is_verdict` functions defined.
2. All five `scripts/verify/p05-*.sh` files exist and are chmod +x.
3. `bash scripts/verify/p05-verdicts-lib.sh` prints PASS.
4. Sourcing verdicts.sh and calling `emit_verdict PASS "test"` outputs
   `VERDICT:PASS reason="test"`.
5. `parse_verdict` correctly decomposes a VERDICT line into verdict and
   reason fields.
6. `git status` shows 6 new files (1 lib + 5 verify scripts). Nothing
   else touched.
