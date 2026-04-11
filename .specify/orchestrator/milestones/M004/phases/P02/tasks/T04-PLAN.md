---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M004"
name: "guards.sh — Safety Rails"
depends_on: [T01, T02, T03]
---

## Description

Implement `scripts/lib/guards.sh` — a Bash 3.2 compatible sourced library containing the orchestrator's safety rail functions. Each guard is a pure check with no side effects beyond `emit_event` and `emit_result`. Guards return 0 (pass / allow) or non-zero (block). All guards honor `ORCH_FORCE=1` as an override (emits GUARD_WARNING instead of GUARD_BLOCKED, returns 0).

The 4 guards required by FR-224 / US6:

1. **`guard_payload_sanity <payload_file>`** — Blocks if the payload file is missing, empty, or less than 100 characters. Prevents garbage-in-garbage-out dispatch.

2. **`guard_budget <cumulative_cost> <max_budget> [cumulative_duration_sec] [max_duration_sec]`** — Blocks if cumulative cost exceeds `max_budget` or cumulative duration exceeds `max_duration_sec`. Both numeric comparisons use integer-safe arithmetic (costs passed in cents, durations in whole seconds).

3. **`guard_output_sanity <output_file>`** — Blocks if agent output is missing, empty, or less than 100 characters. Prevents recording a failed dispatch as a success.

4. **`guard_phase_complete <phase_dir>`** — Blocks phase advance if `SUMMARY.md` exists but contains no recognized content sections (e.g., no `## ` headers). Prevents advancing on an empty / placeholder summary.

All guards:
- Source `scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/run-context.sh` at load time
- Emit `EVENT:GUARD_BLOCKED guard=<name> reason="<reason>"` on failure
- Emit `EVENT:GUARD_WARNING guard=<name> reason="<reason>"` when `ORCH_FORCE=1` overrides a failure
- Return 0 on pass or force-override, non-zero on block

This implements:
- FR-224 (safety rail checks: payload sanity, budget, output sanity, phase completeness)
- US6 AS1-6 (all 6 acceptance scenarios)
- Principle II amendment (structured events on rail evaluation)
- NFR-200 (Bash 3.2 compatible)
- NFR-203 (double-sourcing guard)

## Steps

### Step 1: Verify T01-T03 are in place

```bash
for f in errors events run-context; do
  test -f "scripts/lib/${f}.sh" || { echo "ERROR: ${f}.sh missing"; exit 1; }
done
```

### Step 2: Create `scripts/lib/guards.sh`

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# scripts/lib/guards.sh — Safety rail functions for the orchestrator engine.
#
# Source this file to get:
#   - guard_payload_sanity <payload_file>
#   - guard_budget <cumulative_cost_cents> <max_cost_cents> [cum_dur_sec] [max_dur_sec]
#   - guard_output_sanity <output_file>
#   - guard_phase_complete <phase_dir>
#
# Every guard returns 0 on pass (or force-override) and non-zero on block.
# Every guard emits a GUARD_BLOCKED or GUARD_WARNING event on failure. When
# ORCH_FORCE is set (via orch_is_forced), a would-be block becomes a warning.
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
#
# Constitution: Principle II (structured events on rail evaluation),
#               Principle IX (no inline `date` — uses orch_now).

# --- Double-sourcing guard ---
[ -n "${_GUARDS_SOURCED:-}" ] && return 0
_GUARDS_SOURCED=1

# Source required sibling libraries. Resolve relative to this file's location
# so guards.sh works regardless of the caller's cwd.
_guards_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_guards_dir}/errors.sh"
# shellcheck disable=SC1090
. "${_guards_dir}/events.sh"
# shellcheck disable=SC1090
. "${_guards_dir}/run-context.sh"

# --- Configuration ---
# Minimum acceptable payload and output size (chars). Matches spec AS1/AS3.
ORCH_GUARD_MIN_PAYLOAD_CHARS="${ORCH_GUARD_MIN_PAYLOAD_CHARS:-100}"
ORCH_GUARD_MIN_OUTPUT_CHARS="${ORCH_GUARD_MIN_OUTPUT_CHARS:-100}"

# _guard_block <name> <reason>
# Internal: emit GUARD_BLOCKED (or GUARD_WARNING if forced) and return the
# correct status code. Callers use `_guard_block ... || return $?` is NOT the
# right pattern — callers should `if ! _guard_allow ...; then return 1; fi`.
_guard_block() {
  local name="$1"
  local reason="$2"
  if orch_is_forced; then
    emit_event GUARD_WARNING guard="$name" reason="$reason" forced=1
    return 0
  fi
  emit_event GUARD_BLOCKED guard="$name" reason="$reason"
  return 1
}

# guard_payload_sanity <payload_file>
# Blocks if the payload is missing, empty, or under 100 chars.
guard_payload_sanity() {
  local f="$1"
  if [ -z "$f" ]; then
    _guard_block payload_sanity "no payload path provided"
    return $?
  fi
  if [ ! -f "$f" ]; then
    _guard_block payload_sanity "payload file not found: $f"
    return $?
  fi
  local size
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ]; then
    _guard_block payload_sanity "unable to stat payload: $f"
    return $?
  fi
  if [ "$size" -lt "$ORCH_GUARD_MIN_PAYLOAD_CHARS" ]; then
    _guard_block payload_sanity "payload too small: ${size} < ${ORCH_GUARD_MIN_PAYLOAD_CHARS} chars ($f)"
    return $?
  fi
  return 0
}

# guard_budget <cumulative_cost_cents> <max_cost_cents> [cum_dur_sec] [max_dur_sec]
# Blocks if cumulative cost exceeds max_cost, or cumulative duration exceeds
# max_duration. Passing 0 or empty for a cap disables that check.
guard_budget() {
  local cum_cost="${1:-0}"
  local max_cost="${2:-0}"
  local cum_dur="${3:-0}"
  local max_dur="${4:-0}"

  # Validate numeric inputs (Bash 3.2 safe).
  case "$cum_cost" in ''|*[!0-9]*) cum_cost=0 ;; esac
  case "$max_cost" in ''|*[!0-9]*) max_cost=0 ;; esac
  case "$cum_dur"  in ''|*[!0-9]*) cum_dur=0 ;; esac
  case "$max_dur"  in ''|*[!0-9]*) max_dur=0 ;; esac

  if [ "$max_cost" -gt 0 ] && [ "$cum_cost" -gt "$max_cost" ]; then
    _guard_block budget "cost ${cum_cost} exceeds cap ${max_cost} (cents)"
    return $?
  fi
  if [ "$max_dur" -gt 0 ] && [ "$cum_dur" -gt "$max_dur" ]; then
    _guard_block budget "duration ${cum_dur}s exceeds cap ${max_dur}s"
    return $?
  fi
  return 0
}

# guard_output_sanity <output_file>
# Blocks if agent output is missing, empty, or under 100 chars. Used
# post-dispatch to detect silent failures.
guard_output_sanity() {
  local f="$1"
  if [ -z "$f" ]; then
    _guard_block output_sanity "no output path provided"
    return $?
  fi
  if [ ! -f "$f" ]; then
    _guard_block output_sanity "output file not found: $f"
    return $?
  fi
  local size
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ] || [ "$size" -lt "$ORCH_GUARD_MIN_OUTPUT_CHARS" ]; then
    _guard_block output_sanity "output too small: ${size:-0} < ${ORCH_GUARD_MIN_OUTPUT_CHARS} chars"
    return $?
  fi
  return 0
}

# guard_phase_complete <phase_dir>
# Blocks phase advance when SUMMARY.md exists but has no content sections
# (no `## ` headers). Missing SUMMARY.md is ALSO a block.
guard_phase_complete() {
  local phase_dir="$1"
  if [ -z "$phase_dir" ] || [ ! -d "$phase_dir" ]; then
    _guard_block phase_complete "phase dir not found: ${phase_dir:-<empty>}"
    return $?
  fi
  # Prefer P##-SUMMARY.md, fall back to SUMMARY.md.
  local summary
  summary="$(ls "$phase_dir"/P*-SUMMARY.md 2>/dev/null | head -1)"
  if [ -z "$summary" ] && [ -f "${phase_dir}/SUMMARY.md" ]; then
    summary="${phase_dir}/SUMMARY.md"
  fi
  if [ -z "$summary" ]; then
    _guard_block phase_complete "no SUMMARY.md in ${phase_dir}"
    return $?
  fi
  if ! grep -q '^## ' "$summary"; then
    _guard_block phase_complete "SUMMARY.md has no content sections: $summary"
    return $?
  fi
  return 0
}
```

### Step 3: Make executable

```bash
chmod +x scripts/lib/guards.sh
```

### Step 4: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

test -f scripts/lib/guards.sh && echo "PASS: file" || echo "FAIL"
lines=$(wc -l < scripts/lib/guards.sh | tr -d ' ')
test "$lines" -ge 120 && echo "PASS: $lines lines" || echo "FAIL"
head -5 scripts/lib/guards.sh | grep -q '_GUARDS_SOURCED' && echo "PASS: guard" || echo "FAIL"

for fn in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do
  grep -q "^${fn}()" scripts/lib/guards.sh && echo "PASS: $fn" || echo "FAIL: $fn"
done

grep -q 'ORCH_FORCE' scripts/lib/guards.sh && echo "PASS: ORCH_FORCE referenced" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/guards.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/guards.sh && echo "PASS: no proc sub" || echo "FAIL"
! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/guards.sh && echo "PASS: no sed -i" || echo "FAIL"

# Behavioral: payload guard blocks on small file
tmp=$(mktemp)
printf short > "$tmp"
if bash -c ". scripts/lib/guards.sh; guard_payload_sanity $tmp" 2>&1 | grep -q GUARD_BLOCKED; then
  echo "PASS: small payload blocked"
else
  echo "FAIL: small payload not blocked"
fi
rm -f "$tmp"

# Behavioral: payload guard passes on large file
tmp=$(mktemp)
printf '%0.s=' {1..200} > "$tmp"
bash -c ". scripts/lib/guards.sh; guard_payload_sanity $tmp" > /dev/null && echo "PASS: large payload allowed" || echo "FAIL"
rm -f "$tmp"

# Behavioral: force override
tmp=$(mktemp); printf x > "$tmp"
out="$(bash -c "ORCH_FORCE=1 . scripts/lib/guards.sh; guard_payload_sanity $tmp" 2>&1)"
echo "$out" | grep -q GUARD_WARNING && echo "PASS: force→warning" || echo "FAIL: $out"
bash -c "ORCH_FORCE=1 . scripts/lib/guards.sh; guard_payload_sanity $tmp" > /dev/null && echo "PASS: force allows" || echo "FAIL"
rm -f "$tmp"

# Behavioral: budget guard blocks over cap
bash -c '. scripts/lib/guards.sh; guard_budget 150 100' 2>&1 | grep -q GUARD_BLOCKED && echo "PASS: budget block" || echo "FAIL"
bash -c '. scripts/lib/guards.sh; guard_budget 50 100' > /dev/null && echo "PASS: budget allow" || echo "FAIL"

# Behavioral: phase_complete blocks on empty summary
tmp=$(mktemp -d)
printf '# Empty\n' > "$tmp/P99-SUMMARY.md"
bash -c ". scripts/lib/guards.sh; guard_phase_complete $tmp" 2>&1 | grep -q GUARD_BLOCKED && echo "PASS: empty summary blocked" || echo "FAIL"
printf '## Results\nstuff\n' >> "$tmp/P99-SUMMARY.md"
bash -c ". scripts/lib/guards.sh; guard_phase_complete $tmp" > /dev/null && echo "PASS: full summary allowed" || echo "FAIL"
rm -rf "$tmp"

# Double-sourcing idempotent
bash -c '. scripts/lib/guards.sh; . scripts/lib/guards.sh; type guard_payload_sanity >/dev/null' && echo "PASS: idempotent" || echo "FAIL"
```

Every line should print `PASS:`.

## Must-Haves

### Truths

- `scripts/lib/guards.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/guards.sh | grep -q '_GUARDS_SOURCED'`
- All 4 required guard functions are defined
  - Check: `for fn in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do grep -q "^${fn}()" scripts/lib/guards.sh || exit 1; done && echo PASS`
- `ORCH_FORCE` is referenced for override behavior (US6 AS6)
  - Check: `grep -q 'ORCH_FORCE\|orch_is_forced' scripts/lib/guards.sh`
- guards.sh sources errors.sh, events.sh, and run-context.sh
  - Check: `grep -q 'errors\.sh' scripts/lib/guards.sh && grep -q 'events\.sh' scripts/lib/guards.sh && grep -q 'run-context\.sh' scripts/lib/guards.sh`
- `guard_payload_sanity` blocks on a sub-100-char payload
  - Check: `tmp=$(mktemp); printf short > "$tmp"; bash -c ". scripts/lib/guards.sh; guard_payload_sanity $tmp" 2>&1 | grep -q GUARD_BLOCKED; rc=$?; rm -f "$tmp"; test $rc -eq 0`
- `guard_budget` blocks when cumulative cost exceeds cap
  - Check: `bash -c '. scripts/lib/guards.sh; guard_budget 150 100' 2>&1 | grep -q GUARD_BLOCKED`
- Bash 3.2 compatible, no process substitution, no `sed -i`
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/guards.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/guards.sh && ! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/guards.sh`
- Library is idempotent under double-sourcing
  - Check: `bash -c '. scripts/lib/guards.sh; . scripts/lib/guards.sh; type guard_payload_sanity >/dev/null'`

### Artifacts

- `scripts/lib/guards.sh` (min 120 lines, contains "_GUARDS_SOURCED")

### Key Links

- `scripts/lib/guards.sh` → `scripts/lib/errors.sh` (sources error taxonomy)
- `scripts/lib/guards.sh` → `scripts/lib/events.sh` (emits GUARD_BLOCKED / GUARD_WARNING)
- `scripts/lib/guards.sh` → `scripts/lib/run-context.sh` (reads ORCH_FORCE via orch_is_forced)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T04 Verification ==="

test -f scripts/lib/guards.sh && echo "PASS: file" || { echo "FAIL"; exit 1; }
lines=$(wc -l < scripts/lib/guards.sh | tr -d ' ')
test "$lines" -ge 120 && echo "PASS: $lines lines" || echo "FAIL: $lines"
head -5 scripts/lib/guards.sh | grep -q '_GUARDS_SOURCED' && echo "PASS: guard" || echo "FAIL"

for fn in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do
  grep -q "^${fn}()" scripts/lib/guards.sh && echo "PASS: $fn" || echo "FAIL: $fn"
done

grep -q 'orch_is_forced\|ORCH_FORCE' scripts/lib/guards.sh && echo "PASS: force override" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/guards.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/guards.sh && echo "PASS: no proc sub" || echo "FAIL"
! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/guards.sh && echo "PASS: no sed -i" || echo "FAIL"

# Behavioral
tmp=$(mktemp); printf short > "$tmp"
bash -c ". scripts/lib/guards.sh; guard_payload_sanity $tmp" 2>&1 | grep -q GUARD_BLOCKED && echo "PASS: small payload blocked" || echo "FAIL"
rm -f "$tmp"

tmp=$(mktemp)
python3 -c 'import sys; sys.stdout.write("="*200)' > "$tmp" 2>/dev/null || printf '%200s' '' > "$tmp"
bash -c ". scripts/lib/guards.sh; guard_payload_sanity $tmp" > /dev/null && echo "PASS: large payload allowed" || echo "FAIL"
rm -f "$tmp"

bash -c '. scripts/lib/guards.sh; guard_budget 150 100' 2>&1 | grep -q GUARD_BLOCKED && echo "PASS: budget blocks" || echo "FAIL"
bash -c '. scripts/lib/guards.sh; guard_budget 50 100' > /dev/null && echo "PASS: budget allows" || echo "FAIL"

tmp=$(mktemp -d)
printf '# Empty\n' > "$tmp/P99-SUMMARY.md"
bash -c ". scripts/lib/guards.sh; guard_phase_complete $tmp" 2>&1 | grep -q GUARD_BLOCKED && echo "PASS: empty summary blocked" || echo "FAIL"
printf '## Results\nbody\n' >> "$tmp/P99-SUMMARY.md"
bash -c ". scripts/lib/guards.sh; guard_phase_complete $tmp" > /dev/null && echo "PASS: non-empty summary allowed" || echo "FAIL"
rm -rf "$tmp"

tmp=$(mktemp); printf x > "$tmp"
bash -c "ORCH_FORCE=1 . scripts/lib/guards.sh; guard_payload_sanity $tmp" 2>&1 | grep -q GUARD_WARNING && echo "PASS: force→warning" || echo "FAIL"
bash -c "ORCH_FORCE=1 . scripts/lib/guards.sh; guard_payload_sanity $tmp" > /dev/null && echo "PASS: force allows" || echo "FAIL"
rm -f "$tmp"

bash -c '. scripts/lib/guards.sh; . scripts/lib/guards.sh; type guard_payload_sanity >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

echo "=== T04 complete ==="
```

## Inputs

### From Previous Tasks

- `scripts/lib/errors.sh` (from T01)
  - Key API: `emit_result <status> [error_kind] [detail]`
  - Key types: `ORCH_ERR_CONFIG`, `ORCH_ERR_STATE`, `ORCH_ERR_DISPATCH`, `ORCH_ERR_VERIFY`, `ORCH_ERR_BUDGET`, `ORCH_ERR_IO`
  - Usage: guards.sh sources errors.sh so callers of guards.sh get the taxonomy for free. Guards themselves typically don't emit a RESULT line (they are called inline, not as script main functions), but callers may use `emit_result error VERIFY "guard failed"` after a blocked guard.

- `scripts/lib/events.sh` (from T02)
  - Key API: `emit_event <TYPE> [key=value ...]`
  - Key types: `GUARD_BLOCKED`, `GUARD_WARNING`, `SAFETY_WARNING` are in the canonical event registry
  - Behavioral contract: `emit_event` produces a single `EVENT:<TYPE>` line to stdout, threaded with `$ORCH_RUN_ID` and `$ORCH_STARTED_AT`. Values with whitespace are automatically quoted.
  - Usage: guards.sh calls `emit_event GUARD_BLOCKED guard=<name> reason="<why>"` on failure.

- `scripts/lib/run-context.sh` (from T03)
  - Key API: `init_run_context [milestone] [phase]`, `orch_now`, `orch_is_forced`, `orch_is_dry_run`
  - Exported vars: `ORCH_RUN_ID`, `ORCH_STARTED_AT`, `ORCH_FORCE`, `ORCH_DRY_RUN`
  - Behavioral contract: `orch_is_forced` returns 0 if `ORCH_FORCE` is set to `1|true|TRUE|yes|YES`. guards.sh uses this helper to implement the FORCE override per US6 AS6.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — Principle II amendment requires structured events from rail evaluation. Principle IX requires `orch_now` instead of inline `date`.
- `ANTIPATTERNS.md` — AP-001, AP-002, AP-003.
- `specs/004-engine-architecture/spec.md` — FR-224 (safety rail list). US6 AS1-6 acceptance scenarios define the exact block semantics: payload < 100 chars, budget exceeded, output < 100 chars, phase advance with empty summary, all overridable with `--force`.

## Expected Output

The file `scripts/lib/guards.sh` containing:
- Shebang and descriptive header referencing Principles II and IX, guard contract
- Double-sourcing guard (`_GUARDS_SOURCED`)
- Relative-path sourcing of errors.sh, events.sh, run-context.sh via `$(dirname "${BASH_SOURCE[0]}")`
- Configurable thresholds: `ORCH_GUARD_MIN_PAYLOAD_CHARS`, `ORCH_GUARD_MIN_OUTPUT_CHARS`
- `_guard_block <name> <reason>` internal helper: emits GUARD_BLOCKED on block, GUARD_WARNING when forced, returns appropriate status
- `guard_payload_sanity <payload_file>` function
- `guard_budget <cum_cost> <max_cost> [cum_dur] [max_dur]` function with Bash-3.2-safe numeric parsing
- `guard_output_sanity <output_file>` function
- `guard_phase_complete <phase_dir>` function that checks for `P*-SUMMARY.md` (or fallback `SUMMARY.md`) containing at least one `## ` section header
- File ≥ 120 lines, Bash 3.2 compatible, no process substitution as redirection, no `sed -i`
