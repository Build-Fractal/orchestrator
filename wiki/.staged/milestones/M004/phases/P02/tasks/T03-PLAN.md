---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M004"
name: "run-context.sh — Deterministic Run Context"
depends_on: [T01, T02]
---

## Description

Implement `scripts/lib/run-context.sh` — a Bash 3.2 compatible sourced library that initializes and exports the orchestrator's per-session run context: `ORCH_RUN_ID`, `ORCH_STARTED_AT`, `ORCH_FORCE`, and `ORCH_DRY_RUN`. These variables are the glue that correlates JSONL log entries, stamps events with deterministic timestamps, and tells scripts whether to bypass safety rails (`--force`) or execute without actually dispatching (`--dry-run`).

Per Principle IX (Reproducibility Over Convenience), `init_run_context` is **deterministic when seeded**: given the same `ORCH_RUN_SEED` value, it produces the same `ORCH_RUN_ID` and the same `ORCH_STARTED_AT`. Without a seed, it generates a fresh run ID from the current timestamp and a random nonce. Callers that need reproducible output (tests, deterministic replays) pass `ORCH_RUN_SEED=<string>` before calling `init_run_context`.

`ORCH_STARTED_AT` is frozen at init time — every subsequent event and JSONL entry in the session uses this timestamp via `orch_now`. No script should call `date` inline after this library is loaded; they should call `orch_now` instead.

This implements:
- FR-222 (initializes and exports deterministic run context variables)
- US9 (deterministic RunContext, AS1-4)
- Principle IX (reproducibility, no inline `date` calls)
- NFR-200 (Bash 3.2 compatible)
- NFR-203 (double-sourcing guard)

## Steps

### Step 1: Verify T01 and T02 are in place

```bash
test -f scripts/lib/errors.sh || { echo "ERROR: T01 errors.sh must exist"; exit 1; }
test -f scripts/lib/events.sh || { echo "ERROR: T02 events.sh must exist"; exit 1; }
```

### Step 2: Create `scripts/lib/run-context.sh`

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# scripts/lib/run-context.sh — Deterministic per-session run context.
#
# Source this file to get:
#   - init_run_context [milestone] [phase]  — initialize and export run context
#   - orch_now                                — frozen timestamp (Principle IX)
#   - orch_is_forced                          — returns 0 if ORCH_FORCE is set
#   - orch_is_dry_run                         — returns 0 if ORCH_DRY_RUN is set
#
# Exported environment variables (after init_run_context):
#   ORCH_RUN_ID         Unique ID for the current session (deterministic when seeded)
#   ORCH_STARTED_AT     Frozen ISO-8601 UTC timestamp for the session
#   ORCH_FORCE          "1" to bypass safety rails, empty/unset otherwise
#   ORCH_DRY_RUN        "1" to skip real dispatch, empty/unset otherwise
#   ORCH_RUN_MILESTONE  Optional: milestone id for this session
#   ORCH_RUN_PHASE      Optional: phase id for this session
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
#
# Constitution: Principle IX (Reproducibility) — no inline `date` calls after
# this library is loaded. Use orch_now instead.

# --- Double-sourcing guard ---
[ -n "${_RUN_CONTEXT_SOURCED:-}" ] && return 0
_RUN_CONTEXT_SOURCED=1

# init_run_context [milestone] [phase]
# Initializes the run context. Idempotent in the sense that calling it twice in
# the same shell re-seeds and overwrites the previous values (this is desired
# for tests). Determinism: if ORCH_RUN_SEED is set, both ORCH_RUN_ID and
# ORCH_STARTED_AT are derived from the seed.
init_run_context() {
  local milestone="${1:-${ORCH_RUN_MILESTONE:-}}"
  local phase="${2:-${ORCH_RUN_PHASE:-}}"

  local seed="${ORCH_RUN_SEED:-}"
  local run_id started_at

  if [ -n "$seed" ]; then
    # Deterministic mode: derive run_id and timestamp from the seed.
    # Use a portable hash: sum + cksum of the seed string.
    local hash
    hash="$(printf '%s' "$seed" | cksum | awk '{print $1}')"
    run_id="run-seed-${hash}"
    # Derive a deterministic timestamp from the seed. Anchor to a fixed epoch
    # (2026-01-01T00:00:00Z = 1767225600) and offset by seed hash modulo a year.
    local offset anchor
    anchor=1767225600
    offset=$(( hash % 31536000 ))
    local total=$(( anchor + offset ))
    # Portable epoch → ISO8601 (GNU vs BSD date). Try GNU first.
    if date -u -d "@${total}" +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
      started_at="$(date -u -d "@${total}" +%Y-%m-%dT%H:%M:%SZ)"
    else
      started_at="$(date -u -r "${total}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
    fi
  else
    # Non-deterministic mode: current timestamp + random nonce.
    started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local nonce
    nonce="$(_orch_run_nonce)"
    run_id="run-${started_at}-${nonce}"
  fi

  ORCH_RUN_ID="$run_id"
  ORCH_STARTED_AT="$started_at"
  ORCH_FORCE="${ORCH_FORCE:-}"
  ORCH_DRY_RUN="${ORCH_DRY_RUN:-}"
  ORCH_RUN_MILESTONE="$milestone"
  ORCH_RUN_PHASE="$phase"

  export ORCH_RUN_ID ORCH_STARTED_AT ORCH_FORCE ORCH_DRY_RUN ORCH_RUN_MILESTONE ORCH_RUN_PHASE
}

# _orch_run_nonce
# Generates a short alphanumeric nonce. Prefers /dev/urandom; falls back to $$
# + RANDOM when /dev/urandom is unavailable.
_orch_run_nonce() {
  if [ -r /dev/urandom ]; then
    LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8
  else
    printf '%s%s' "$$" "${RANDOM:-0}" | cksum | awk '{printf "%08x\n", $1}' | head -c 8
  fi
}

# orch_now
# Returns the frozen ORCH_STARTED_AT timestamp. Scripts that need a timestamp
# MUST call this function instead of `date` inline (Principle IX).
orch_now() {
  if [ -n "${ORCH_STARTED_AT:-}" ]; then
    printf '%s\n' "$ORCH_STARTED_AT"
  else
    # Graceful fallback for scripts sourcing this lib without init_run_context.
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# orch_is_forced
# Returns 0 if ORCH_FORCE is set to a truthy value, 1 otherwise.
orch_is_forced() {
  case "${ORCH_FORCE:-}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# orch_is_dry_run
# Returns 0 if ORCH_DRY_RUN is set to a truthy value, 1 otherwise.
orch_is_dry_run() {
  case "${ORCH_DRY_RUN:-}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
```

### Step 3: Make executable

```bash
chmod +x scripts/lib/run-context.sh
```

### Step 4: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Static
test -f scripts/lib/run-context.sh && echo "PASS: file exists" || echo "FAIL"
lines=$(wc -l < scripts/lib/run-context.sh | tr -d ' ')
test "$lines" -ge 70 && echo "PASS: $lines lines" || echo "FAIL: $lines"
head -5 scripts/lib/run-context.sh | grep -q '_RUN_CONTEXT_SOURCED' && echo "PASS: guard" || echo "FAIL"

# Function definitions
for fn in init_run_context orch_now orch_is_forced orch_is_dry_run; do
  grep -q "^${fn}()" scripts/lib/run-context.sh && echo "PASS: $fn" || echo "FAIL: $fn"
done

# Exports
for v in ORCH_RUN_ID ORCH_STARTED_AT ORCH_FORCE ORCH_DRY_RUN; do
  grep -q "export.*$v" scripts/lib/run-context.sh && echo "PASS: export $v" || echo "FAIL: $v"
done

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' scripts/lib/run-context.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/run-context.sh && echo "PASS: no proc sub" || echo "FAIL"

# Behavioral: init without seed sets all 4 exports
bash -c '. scripts/lib/run-context.sh; init_run_context M004 P02; test -n "$ORCH_RUN_ID" && test -n "$ORCH_STARTED_AT"' && echo "PASS: init sets vars" || echo "FAIL"

# Behavioral: determinism — same seed → same run_id and started_at
a="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=myseed init_run_context; printf "%s:%s\n" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"
b="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=myseed init_run_context; printf "%s:%s\n" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"
test "$a" = "$b" && echo "PASS: deterministic seed" || echo "FAIL: $a vs $b"

# Behavioral: different seeds → different run IDs
c="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=other init_run_context; printf "%s" "$ORCH_RUN_ID"')"
d="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=myseed init_run_context; printf "%s" "$ORCH_RUN_ID"')"
test "$c" != "$d" && echo "PASS: seeds differ" || echo "FAIL"

# Behavioral: orch_now returns frozen ORCH_STARTED_AT
bash -c 'ORCH_STARTED_AT=2026-04-10T12:00:00Z . scripts/lib/run-context.sh; ts="$(orch_now)"; test "$ts" = "2026-04-10T12:00:00Z"' && echo "PASS: orch_now frozen" || echo "FAIL"

# Behavioral: orch_is_forced / orch_is_dry_run
bash -c 'ORCH_FORCE=1 . scripts/lib/run-context.sh; orch_is_forced' && echo "PASS: force detected" || echo "FAIL"
bash -c 'ORCH_DRY_RUN=1 . scripts/lib/run-context.sh; orch_is_dry_run' && echo "PASS: dry-run detected" || echo "FAIL"
bash -c '. scripts/lib/run-context.sh; ! orch_is_forced' && echo "PASS: force unset default" || echo "FAIL"

# Double-sourcing idempotent
bash -c '. scripts/lib/run-context.sh; . scripts/lib/run-context.sh; type init_run_context >/dev/null' && echo "PASS: idempotent" || echo "FAIL"
```

Every line should print `PASS:`.

## Must-Haves

### Truths

- `scripts/lib/run-context.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/run-context.sh | grep -q '_RUN_CONTEXT_SOURCED'`
- `init_run_context` function is defined and exports all 4 required variables
  - Check: `grep -q '^init_run_context()' scripts/lib/run-context.sh && grep -q 'export.*ORCH_RUN_ID' scripts/lib/run-context.sh && grep -q 'export.*ORCH_STARTED_AT' scripts/lib/run-context.sh && grep -q 'export.*ORCH_FORCE' scripts/lib/run-context.sh && grep -q 'export.*ORCH_DRY_RUN' scripts/lib/run-context.sh`
- `orch_now` function is defined and returns `$ORCH_STARTED_AT` when set
  - Check: `grep -q '^orch_now()' scripts/lib/run-context.sh && bash -c 'ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/run-context.sh; test "$(orch_now)" = "2026-04-10T00:00:00Z"'`
- `orch_is_forced` and `orch_is_dry_run` helpers are defined
  - Check: `grep -q '^orch_is_forced()' scripts/lib/run-context.sh && grep -q '^orch_is_dry_run()' scripts/lib/run-context.sh`
- Deterministic seeding: same `ORCH_RUN_SEED` produces same run_id and started_at (US9 AS4)
  - Check: `a="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=s1 init_run_context; printf "%s:%s" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"; b="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=s1 init_run_context; printf "%s:%s" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"; test "$a" = "$b"`
- Bash 3.2 compatible
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/run-context.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/run-context.sh`
- Library is idempotent under double-sourcing
  - Check: `bash -c '. scripts/lib/run-context.sh; . scripts/lib/run-context.sh; type init_run_context >/dev/null'`

### Artifacts

- `scripts/lib/run-context.sh` (min 70 lines, contains "_RUN_CONTEXT_SOURCED")

### Key Links

- `scripts/lib/run-context.sh` → `.specify/memory/constitution.md` (implements Principle IX Reproducibility Over Convenience)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T03 Verification ==="

test -f scripts/lib/run-context.sh && echo "PASS: file exists" || { echo "FAIL"; exit 1; }
lines=$(wc -l < scripts/lib/run-context.sh | tr -d ' ')
test "$lines" -ge 70 && echo "PASS: $lines lines" || echo "FAIL: $lines"

head -5 scripts/lib/run-context.sh | grep -q '_RUN_CONTEXT_SOURCED' && echo "PASS: guard" || echo "FAIL"

for fn in init_run_context orch_now orch_is_forced orch_is_dry_run; do
  grep -q "^${fn}()" scripts/lib/run-context.sh && echo "PASS: $fn" || echo "FAIL: $fn"
done

for v in ORCH_RUN_ID ORCH_STARTED_AT ORCH_FORCE ORCH_DRY_RUN; do
  grep -q "export.*$v" scripts/lib/run-context.sh && echo "PASS: export $v" || echo "FAIL: $v"
done

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/run-context.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/run-context.sh && echo "PASS: no proc sub" || echo "FAIL"

bash -c '. scripts/lib/run-context.sh; init_run_context M004 P02; test -n "$ORCH_RUN_ID" -a -n "$ORCH_STARTED_AT"' && echo "PASS: init exports" || echo "FAIL"

a="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=det init_run_context; printf "%s:%s" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"
b="$(bash -c '. scripts/lib/run-context.sh; ORCH_RUN_SEED=det init_run_context; printf "%s:%s" "$ORCH_RUN_ID" "$ORCH_STARTED_AT"')"
test "$a" = "$b" && echo "PASS: deterministic seed" || echo "FAIL: $a vs $b"

bash -c 'ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/run-context.sh; test "$(orch_now)" = "2026-04-10T00:00:00Z"' && echo "PASS: orch_now frozen" || echo "FAIL"

bash -c 'ORCH_FORCE=1 . scripts/lib/run-context.sh; orch_is_forced' && echo "PASS: force detected" || echo "FAIL"
bash -c 'ORCH_DRY_RUN=1 . scripts/lib/run-context.sh; orch_is_dry_run' && echo "PASS: dry-run detected" || echo "FAIL"

bash -c '. scripts/lib/run-context.sh; . scripts/lib/run-context.sh; type init_run_context >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

echo "=== T03 complete ==="
```

## Inputs

### From Previous Tasks

- `scripts/lib/errors.sh` (from T01)
  - Key API: `emit_result <status> [error_kind] [detail]`
  - Key types: `ORCH_ERR_CONFIG`, `ORCH_ERR_STATE`, etc.
  - Behavioral contract: run-context.sh does NOT source errors.sh at runtime. Cross-reference is via documentation only.

- `scripts/lib/events.sh` (from T02)
  - Key API: `emit_event <TYPE> [key=value ...]`
  - Behavioral contract: events.sh consumes `$ORCH_STARTED_AT` and `$ORCH_RUN_ID` when set. run-context.sh is the producer of those variables. Loading order should be: run-context → events (so events get the frozen timestamp). run-context.sh does NOT source events.sh at runtime — they are sibling libraries.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — Principle IX (Reproducibility Over Convenience): "No inline `date` calls — use `$ORCH_STARTED_AT` or run-context timestamps. No random identifiers without seed control — `ORCH_RUN_ID` is deterministic when seeded."
- `ANTIPATTERNS.md` — AP-001, AP-003.
- `specs/004-engine-architecture/spec.md` — FR-222 (init_run_context exports ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN). US9 AS1-4 describe RunContext behavior, including the deterministic seeding requirement (AS4).
- `scripts/knowledge/lib/staleness.sh` — Reference double-sourcing guard.

## Expected Output

The file `scripts/lib/run-context.sh` containing:
- Shebang and descriptive header comment referencing Principle IX
- Double-sourcing guard (`_RUN_CONTEXT_SOURCED`)
- `init_run_context [milestone] [phase]` public function that:
  - Reads `ORCH_RUN_SEED` if set and derives a deterministic run_id and started_at via `cksum`-based hashing (portable, Bash 3.2 compatible)
  - Otherwise generates a timestamp via `date -u` (the **only** sanctioned `date` call in the orchestrator after this library loads) and a nonce from `/dev/urandom`
  - Exports `ORCH_RUN_ID`, `ORCH_STARTED_AT`, `ORCH_FORCE`, `ORCH_DRY_RUN`, `ORCH_RUN_MILESTONE`, `ORCH_RUN_PHASE`
- `_orch_run_nonce` internal helper
- `orch_now` public function returning frozen `$ORCH_STARTED_AT`
- `orch_is_forced` and `orch_is_dry_run` truthy-value helpers (accepting `1|true|TRUE|yes|YES`)
- File ≥ 70 lines, Bash 3.2 compatible
