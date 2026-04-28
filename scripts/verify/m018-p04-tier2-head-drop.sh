#!/usr/bin/env bash
# scripts/verify/m018-p04-tier2-head-drop.sh — phase-truth verifier:
# "Tier 2 head-drop fires on section bodies (Knowledge, Task Plan,
# Upstream Context) whose body-token count exceeds
# compression.tier2.section_budget_tokens, removing head bytes above the
# budget while leaving the trailing protected_tail_ratio of pre-snip
# section bytes byte-identical at the tail of the post-snip section;
# the heading line is preserved."
#
# Approach (mirrors P03 shim pattern):
#   - Stage a hermetic fixture orch_root via _helpers/m018-p04-build-fixture.sh
#     (slug=section-overflow). The helper writes config.yml with
#     compression.tier2.section_budget_tokens=200 so ~400-token Knowledge
#     body comfortably exceeds budget.
#   - Author a thin shim that sources scripts/lib/preservation-check.sh
#     (so the cross-tier vocab + violation emitter are defined), STUBS
#     pres_check_section to always return 0 (the self-check failure path
#     is exercised by m018-p04-tier2-preservation-self-check.sh — this
#     verifier targets the head-drop happy-path), then awk-extracts and
#     sources _bc_apply_tier2 from build-context.sh.
#   - Run _bc_apply_tier2 against a copy of the fixture payload; assert
#     the heading line is intact, the in-band tier2 marker appears, the
#     post-snip body is shorter than the pre-snip body, and a known
#     protected-tail substring appears verbatim in the post output.
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

. "$REPO_ROOT/scripts/lib/preservation-check.sh"

# Stub the cross-tier preservation self-check so we observe the awk
# pass's head-drop output. Failure-path coverage lives in
# m018-p04-tier2-preservation-self-check.sh.
pres_check_section() {
  return 0
}
pres_emit_violation() {
  return 0
}

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

# 1. The Knowledge heading line is preserved.
if ! grep -q '^## Knowledge$' "$PAYLOAD"; then
  printf 'FAIL: Knowledge heading line removed by head-drop\n' >&2
  exit 1
fi

# 2. The in-band tier2 marker appears immediately after the heading.
HEAD_DROP_LINE="$(awk '/^## Knowledge$/{getline; print; exit}' "$PAYLOAD")"
case "$HEAD_DROP_LINE" in
  '<!-- compressed:tier2 head_dropped='*' protected_tail_ratio=0.30 -->')
    : ;;
  *)
    printf 'FAIL: tier2 marker line not the line immediately after ## Knowledge\n' >&2
    printf '       got: %s\n' "$HEAD_DROP_LINE" >&2
    exit 1
    ;;
esac

# 3. The post-snip payload is strictly shorter than the pre-snip payload.
PRE_BYTES="$(wc -c < "$PRE_SNAP" | tr -d ' ')"
POST_BYTES="$(wc -c < "$PAYLOAD" | tr -d ' ')"
if [ "$POST_BYTES" -ge "$PRE_BYTES" ]; then
  printf 'FAIL: post-snip payload not smaller than pre-snip (pre=%d post=%d)\n' "$PRE_BYTES" "$POST_BYTES" >&2
  exit 1
fi

# 4. The protected-tail-marker-line literal from the fixture's tail
#    paragraph appears verbatim in the post-snip output.
if ! grep -q 'protected-tail-marker-line' "$PAYLOAD"; then
  printf 'FAIL: protected-tail-marker-line missing from post-snip output (protected tail not preserved)\n' >&2
  exit 1
fi

# 5. The seventh-paragraph trailing prose appears in the post output
#    (the tail prose). The seventh paragraph is at the end of the
#    Knowledge body and must be preserved.
if ! grep -q 'seventh paragraph closes' "$PAYLOAD"; then
  printf 'FAIL: tail-paragraph prose missing — protected tail not preserved verbatim\n' >&2
  exit 1
fi

# 6. The first-paragraph head prose is GONE from the post output.
#    (The first paragraph body is in the head-drop range.)
if grep -q 'highest byte offset of the section body' "$PAYLOAD"; then
  printf 'FAIL: head prose still present — head-drop did not fire\n' >&2
  exit 1
fi

# 7. The marker's head_dropped value is a positive integer.
HD="$(printf '%s' "$HEAD_DROP_LINE" | sed -n 's/.*head_dropped=\([0-9][0-9]*\).*/\1/p')"
if [ -z "$HD" ] || [ "$HD" -le 0 ]; then
  printf 'FAIL: head_dropped value not a positive integer (got "%s")\n' "$HD" >&2
  exit 1
fi

# tier2 head_dropped literal in this verifier.
printf 'PASS: m018-p04-tier2-head-drop (heading preserved; tier2 marker emitted with head_dropped=%s; protected tail bytes intact)\n' "$HD"
exit 0
