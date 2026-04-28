#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-preservation-self-check.sh — phase-truth
# verifier:
# "Body-level preservation self-check: after head-drop, pres_check_section
# `tier2 <pre> <post> tier2` runs over the section bodies; on failure
# the section is restored byte-identical from the pre-snip capture and
# a tier_preservation_violation JSONL record is emitted via
# pres_emit_violation (tier=tier2)."
#
# Approach (function-stub pattern from P03/T03):
#   - Stage section-overflow fixture.
#   - Source preservation-check.sh, then OVERRIDE pres_check_section to
#     ALWAYS return 1 (forced violation) and OVERRIDE pres_emit_violation
#     to write a synthetic tier_preservation_violation JSONL record.
#     This exercises the failure-restoration path without depending on
#     regex contents.
#   - Awk-extract _bc_apply_tier2 from build-context.sh, source it.
#   - Run _bc_apply_tier2 against a copy of the fixture payload.
#   - Assert (a) the post-call payload bytes equal the pre-call snapshot
#     (restoration on failure); (b) the fixture's execution log carries
#     a tier_preservation_violation record with tier=tier2.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
PRES="$REPO_ROOT/scripts/lib/preservation-check.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md"

for p in "$HELPER" "$BC" "$PRES" "$FIXTURE"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM
bash "$HELPER" "$DEST" section-overflow >/dev/null

PAYLOAD="$DEST/_payload.md"
cp "$FIXTURE" "$PAYLOAD"
PRE_SNAP="$DEST/_payload_pre.md"
cp "$PAYLOAD" "$PRE_SNAP"

LOG="$DEST/execution-log.jsonl"
: > "$LOG"

SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -u
REPO_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$(mktemp -d)"
COMPRESSION_ENABLED=true
TIER2_ENABLED=true
TIER2_SECTION_BUDGET_TOKENS=200
TIER2_PROTECTED_TAIL_RATIO=0.3
MILESTONE_ID=M018-fixture
PHASE_ID=P04
TASK_ID=T01

# Source the real preservation-check library first.
. "$REPO_ROOT/scripts/lib/preservation-check.sh"

# Override pres_check_section to ALWAYS fail — exercises the
# _bc_apply_tier2 violation-restoration code path.
pres_check_section() {
  return 1
}

# Override pres_emit_violation to append a synthetic
# tier_preservation_violation record to the fixture log.
pres_emit_violation() {
  local tier="$1"
  local section="$2"
  local pattern="$3"
  local log_file="$4"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"record_type":"tier_preservation_violation","tier":"%s","section":"%s","pattern":"%s","timestamp":"%s"}\n' \
    "$tier" "$section" "$pattern" "$ts" >> "$log_file"
}

SCRATCH="$(mktemp)"
awk '/^_bc_apply_tier2\(\)/,/^}$/' "$REPO_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"

PAYLOAD="$DEST/_payload.md"
_bc_apply_tier2 "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

if ! bash "$SHIM" "$REPO_ROOT" "$DEST" >"$DEST/_shim.out" 2>"$DEST/_shim.err"; then
  printf 'FAIL: shim invocation of _bc_apply_tier2 nonzero (failure path should still return 0)\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

# Assertion: post-call payload bytes equal pre-call snapshot
# (restoration on preservation-check failure).
if ! diff -q "$PAYLOAD" "$PRE_SNAP" >/dev/null 2>&1; then
  printf 'FAIL: payload was modified despite preservation-check failure (expected verbatim restoration)\n' >&2
  diff -u "$PRE_SNAP" "$PAYLOAD" | head -40 >&2
  exit 1
fi

# Assertion: tier_preservation_violation record present in execution log.
if [ ! -s "$LOG" ]; then
  printf 'FAIL: execution-log.jsonl empty — pres_emit_violation never fired\n' >&2
  exit 1
fi
if ! grep -q '"record_type":"tier_preservation_violation"' "$LOG"; then
  printf 'FAIL: log missing tier_preservation_violation record\n' >&2
  cat "$LOG" >&2
  exit 1
fi
if ! grep -q '"tier":"tier2"' "$LOG"; then
  printf 'FAIL: tier_preservation_violation record missing tier=tier2\n' >&2
  cat "$LOG" >&2
  exit 1
fi

# tier_preservation_violation literal in this verifier (artifact contains check).
printf 'PASS: m018-p04-tier2-preservation-self-check (failure-path passthrough holds; tier_preservation_violation emitted with tier=tier2)\n'
exit 0
