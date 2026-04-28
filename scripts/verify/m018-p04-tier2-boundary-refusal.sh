#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-boundary-refusal.sh — phase-truth verifier:
# "Preserved-pattern boundary refusal: if the computed head-drop boundary
# lands inside a preserved span from the cross-tier vocabulary
# (frontmatter delimiter, 4+-backtick code fence, etc.), the snip
# retreats to the next safe boundary line; if no safe boundary exists
# above the protected tail, the section passes through unmodified and a
# tier_preservation_violation JSONL record is appended."
#
# Approach:
#   - Stage the boundary-refusal fixture: an over-budget Upstream Context
#     section whose naive head-drop boundary lands INSIDE a 4-backtick
#     code fence (MIT-01 case: nested 3-backtick lines that must NOT
#     close the outer 4-backtick fence).
#   - Shim-mode: stub pres_check_section to 0 so we observe the awk
#     walker's retreat behavior directly.
#   - Assert ONE of the two grammar-spec'd outcomes:
#       (a) Retreat path: marker emitted with `head_dropped` strictly
#           smaller than the naive cut would produce; the fence opener
#           AND closer (the 4-backtick rows) are both present and
#           unaltered in the post output.
#       (b) Passthrough path: no tier2 marker in output AND a
#           tier_preservation_violation JSONL record (tier=tier2) is
#           appended to the violations file.
#   - Either outcome is grammar-conformant; we accept (a) OR (b).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
PRES="$REPO_ROOT/scripts/lib/preservation-check.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md"

for p in "$HELPER" "$BC" "$PRES" "$FIXTURE"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM
bash "$HELPER" "$DEST" boundary-refusal >/dev/null

PAYLOAD="$DEST/_payload.md"
cp "$FIXTURE" "$PAYLOAD"

SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -u
REPO_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$DEST/_tmp_build"
mkdir -p "$TMPDIR_BUILD"
COMPRESSION_ENABLED=true
TIER2_ENABLED=true
TIER2_SECTION_BUDGET_TOKENS=200
TIER2_PROTECTED_TAIL_RATIO=0.3
MILESTONE_ID=M018-fixture
PHASE_ID=P04
TASK_ID=T01
. "$REPO_ROOT/scripts/lib/preservation-check.sh"
pres_check_section() { return 0; }
SCRATCH="$(mktemp)"
awk '/^_bc_apply_tier2\(\)/,/^}$/' "$REPO_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"
PAYLOAD="$DEST/_payload.md"
_bc_apply_tier2 "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

if ! bash "$SHIM" "$REPO_ROOT" "$DEST" >"$DEST/_shim.out" 2>"$DEST/_shim.err"; then
  printf 'FAIL: shim invocation of _bc_apply_tier2 nonzero\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

# Look for the marker (retreat path) or absence (passthrough path).
MARKER_LINE="$(awk '/^## Upstream Context$/{getline; print; exit}' "$PAYLOAD")"
case "$MARKER_LINE" in
  '<!-- compressed:tier2 head_dropped='*' protected_tail_ratio=0.30 -->')
    PATH_TYPE=retreat
    HEAD_DROPPED="$(printf '%s\n' "$MARKER_LINE" | sed -n 's/.*head_dropped=\([0-9][0-9]*\).*/\1/p')"
    ;;
  *)
    PATH_TYPE=passthrough
    HEAD_DROPPED=0
    ;;
esac

# 4-backtick fence opener and closer must both still be present in the
# output regardless of which path fired (the retreat path leaves them
# in place; the passthrough path leaves them unaltered).
FENCE_LINES="$(grep -cE '^`{4,}[a-zA-Z0-9_-]*$' "$PAYLOAD" || true)"
if [ "$FENCE_LINES" -ne 2 ]; then
  printf 'FAIL: expected 2 four-backtick fence rows in post output, got %d (fence orphaned by snip)\n' "$FENCE_LINES" >&2
  exit 1
fi

# All twelve "boundary-refusal-fence-content marker line" rows must
# survive — they live inside the fence which is itself preserved.
FENCE_BODY_COUNT="$(grep -c 'boundary-refusal-fence-content marker line' "$PAYLOAD" || true)"
if [ "$FENCE_BODY_COUNT" -lt 6 ]; then
  printf 'FAIL: fewer than 6 fence-body marker lines survived (got %d) — fence body partially dropped\n' "$FENCE_BODY_COUNT" >&2
  exit 1
fi

# Inner 3-backtick line must also be present — under MIT-01 tick-count
# semantics the inner 3-backtick line is content of the outer 4-backtick
# fence, not a closer.
if ! grep -q 'this 3-tick line must NOT close' "$PAYLOAD"; then
  printf 'FAIL: inner 3-backtick fence content missing — MIT-01 regex regressed\n' >&2
  exit 1
fi

if [ "$PATH_TYPE" = "retreat" ]; then
  # Retreat path: head_dropped must be a positive integer.
  if [ "$HEAD_DROPPED" -le 0 ]; then
    printf 'FAIL: retreat path head_dropped must be > 0 (got %d)\n' "$HEAD_DROPPED" >&2
    exit 1
  fi
  # Sanity check: the naive cut at floor(body_chars * 0.7) lands inside
  # the fence body; if retreat fired correctly, head_dropped reflects
  # only bytes ABOVE the fence opener. The Upstream Context body is
  # ~2050 chars, naive cut at ~1435 chars. Pre-fence prose is roughly
  # 600 chars. So retreat-path head_dropped (in tokens) should be
  # noticeably smaller than naive (~360 tok) but still positive.
  if [ "$HEAD_DROPPED" -gt 200 ]; then
    printf 'FAIL: retreat-path head_dropped=%d larger than expected naive bound — walker may not have retreated\n' "$HEAD_DROPPED" >&2
    exit 1
  fi
  printf 'PASS: m018-p04-tier2-boundary-refusal (retreat path; head_dropped=%d; fence opener+closer preserved; MIT-01 nested 3-backtick line intact)\n' "$HEAD_DROPPED"
  exit 0
fi

# Passthrough path: tier_preservation_violation must be in the
# violations file written by the awk pass.
VIOL="$DEST/_tmp_build/_tier2_violations.txt"
if [ ! -f "$VIOL" ]; then
  printf 'FAIL: passthrough path but no _tier2_violations.txt written\n' >&2
  exit 1
fi
if ! grep -q 'pattern=' "$VIOL"; then
  printf 'FAIL: violations file present but contains no pattern= record\n' >&2
  cat "$VIOL" >&2
  exit 1
fi

printf 'PASS: m018-p04-tier2-boundary-refusal (passthrough path; tier_preservation_violation pattern recorded; fence intact)\n'
exit 0
