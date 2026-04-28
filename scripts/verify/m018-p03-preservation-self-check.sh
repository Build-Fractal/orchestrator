#!/usr/bin/env bash
# scripts/verify/m018-p03-preservation-self-check.sh — phase-truth verifier:
# "When Tier 1 modifies a section, pres_check_section (P02 library) is
# invoked over the post-paging body and any failure causes Tier 1 to
# pass the section through unmodified plus emit a tier_preservation_violation
# JSONL record (record_type=tier_preservation_violation, tier=tier1)."
#
# Approach:
#   - Stage a fixture orch_root via the helper.
#   - In the shim, source preservation-check.sh first so the original
#     functions are present, then immediately override `pres_check_section`
#     to ALWAYS return 1 (forced violation) and override `pres_emit_violation`
#     to write a synthetic tier_preservation_violation JSONL record into
#     the fixture execution log. (The production failure-path code in
#     _bc_apply_tier1 invokes both functions; with the stubs in scope,
#     we exercise the failure-path without depending on regex contents.)
#   - Assert: post-paging payload bytes equal pre-paging payload bytes
#     (restoration on failure); execution log contains the synthetic
#     tier_preservation_violation record.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
PRES="$REPO_ROOT/scripts/lib/preservation-check.sh"

for p in "$HELPER" "$BC" "$PRES"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM
bash "$HELPER" "$DEST" >/dev/null

PAYLOAD="$DEST/_fixture-payloads/payload.md"
PRE_SNAPSHOT="$DEST/_fixture-payloads/payload.pre.md"
cp "$PAYLOAD" "$PRE_SNAPSHOT"

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
TIER1_ENABLED=true
TIER1_INLINE_THRESHOLD_TOKENS=1500
TIER1_PREVIEW_LINES=5
TIER1_CACHE_DIR="$DEST/cache/tool-results/"
MILESTONE_ID=M018-fixture
PHASE_ID=P03
TASK_ID=T01

# Source the real preservation-check library first.
. "$REPO_ROOT/scripts/lib/preservation-check.sh"

# Override pres_check_section to ALWAYS fail — exercises the
# _bc_apply_tier1 violation-restoration code path.
pres_check_section() {
  return 1
}

# Override pres_emit_violation to append a synthetic tier_preservation_violation
# record matching the production schema closely enough for the verifier's
# substring assertions.
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
awk '/^_bc_apply_tier1\(\)/,/^}$/' "$REPO_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"

PAYLOAD="$DEST/_fixture-payloads/payload.md"
_bc_apply_tier1 "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

if ! bash "$SHIM" "$REPO_ROOT" "$DEST" > "$DEST/_shim.out" 2>"$DEST/_shim.err"; then
  printf 'FAIL: shim invocation of _bc_apply_tier1 nonzero (failure path should still return 0)\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

# Assertion: post-paging payload bytes match pre-paging snapshot
# (restoration on preservation-check failure).
if ! diff -q "$PAYLOAD" "$PRE_SNAPSHOT" >/dev/null 2>&1; then
  printf 'FAIL: payload was modified despite preservation-check failure (expected verbatim restoration)\n' >&2
  diff -u "$PRE_SNAPSHOT" "$PAYLOAD" | head -40 >&2
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
if ! grep -q '"tier":"tier1"' "$LOG"; then
  printf 'FAIL: tier_preservation_violation record missing tier=tier1\n' >&2
  cat "$LOG" >&2
  exit 1
fi

# tier_preservation_violation literal in this verifier (artifact contains check).
printf 'PASS: m018-p03-preservation-self-check (failure-path passthrough + tier_preservation_violation emitted)\n'
exit 0
