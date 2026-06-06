#!/usr/bin/env bash
# tools/verify/m034-p01-producer.sh — M034 P01 verifier for
# decisions-from-conversus.sh (the optional conversus producer).
#
# Tests:
#   (a) CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK -> the --out packet
#       contains two CONV- entries (the two disputes in gate-result-block.md),
#       each severity: block, picked_value mentioning BLOCK;
#   (b) CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS -> packet produced (PASS
#       path) with at least one CONV- entry;
#   (c) DECISIONS_CONV_STUB_MISSING=1 -> producer exits non-zero AND stderr
#       contains `pipx install conversus-oss` AND the --out packet was NOT
#       created/modified (strict block, no silent SKIP).
#
# Throwaway packets under $TMPDIR (or repo tmp/). Prints `PASS: m034-p01
# producer` on success, `FAIL: ...` + exit 1 otherwise.
#
# Bash 3.2 / POSIX-sh. Run via plain `bash tools/verify/m034-p01-producer.sh`.

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PRODUCER="$REPO_ROOT/scripts/knowledge/decisions-from-conversus.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$PRODUCER" ] || fail "producer not found: $PRODUCER"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/m034-p01-producer.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# The stub adapter requires a readable artifact path (it checks `-r`) and the
# named preset under templates/conversus-presets/. normalize-fidelity is the
# preset stamped into the stub fixtures' frontmatter, but the stub path skips
# requires_source; CONVERSUS_GATE_SKIP_TODO_CHECK guards against the TODO
# pre-flight on a synthetic artifact body.
ARTIFACT="$WORK/artifact.md"
printf '# Synthetic artifact\n\nBody for producer verification.\n' > "$ARTIFACT"
PRESET="normalize-fidelity"
[ -f "$REPO_ROOT/templates/conversus-presets/${PRESET}.yml" ] \
  || fail "expected preset template not found: templates/conversus-presets/${PRESET}.yml"

# Helper: extract a block for a given `## <id>` heading from a packet.
block_of() {
  awk -v want="## $2" '
    $0 == want { grab=1; print; next }
    /^## / && grab { exit }
    grab { print }
  ' "$1"
}

# ---------------------------------------------------------------------------
# (a) BLOCK verdict -> two CONV- entries, severity block, picked_value BLOCK.
PACKET_A="$WORK/block-DECISIONS.md"
set +e
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
  bash "$PRODUCER" \
    --preset="$PRESET" \
    --artifact="$ARTIFACT" \
    --milestone=M034 \
    --out="$PACKET_A" >/dev/null 2>"$WORK/a-err.txt"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(a) producer exited non-zero on BLOCK stub: $(cat "$WORK/a-err.txt")"
[ -f "$PACKET_A" ] || fail "(a) BLOCK packet not created"

conv_count=$(grep -c '^## CONV-' "$PACKET_A" || true)
[ "$conv_count" -eq 2 ] || fail "(a) expected 2 CONV- entries, got $conv_count"

for id in CONV-1 CONV-2; do
  block=$(block_of "$PACKET_A" "$id")
  [ -n "$block" ] || fail "(a) block $id missing"
  printf '%s\n' "$block" | grep -q "^- \*\*severity\*\*: block$" \
    || fail "(a) $id not severity: block"
  printf '%s\n' "$block" | grep -q "^- \*\*picked_value\*\*: conversus verdict: BLOCK$" \
    || fail "(a) $id picked_value does not mention BLOCK"
done

# ---------------------------------------------------------------------------
# (b) PASS verdict -> packet produced with at least one CONV- entry.
PACKET_B="$WORK/pass-DECISIONS.md"
set +e
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
  bash "$PRODUCER" \
    --preset="$PRESET" \
    --artifact="$ARTIFACT" \
    --milestone=M034 \
    --out="$PACKET_B" >/dev/null 2>"$WORK/b-err.txt"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(b) producer exited non-zero on PASS stub: $(cat "$WORK/b-err.txt")"
[ -f "$PACKET_B" ] || fail "(b) PASS packet not created"

conv_count_b=$(grep -c '^## CONV-' "$PACKET_B" || true)
[ "$conv_count_b" -ge 1 ] || fail "(b) expected >=1 CONV- entry, got $conv_count_b"
# The PASS fixture has zero dispute lines -> the single CONV-1 summary entry,
# severity warn, picked_value PASS.
grep -q "^- \*\*picked_value\*\*: conversus verdict: PASS$" "$PACKET_B" \
  || fail "(b) PASS packet does not carry 'conversus verdict: PASS'"

# ---------------------------------------------------------------------------
# (c) Missing-binary seam -> non-zero exit, install pointer, packet untouched.
PACKET_C="$WORK/missing-DECISIONS.md"
# Assert the packet does NOT exist before AND after (never created).
[ ! -e "$PACKET_C" ] || fail "(c) precondition: packet path already exists"
set +e
DECISIONS_CONV_STUB_MISSING=1 \
  bash "$PRODUCER" \
    --preset="$PRESET" \
    --artifact="$ARTIFACT" \
    --milestone=M034 \
    --out="$PACKET_C" >/dev/null 2>"$WORK/c-err.txt"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "(c) producer did NOT exit non-zero under missing-binary seam"
grep -q "pipx install conversus-oss" "$WORK/c-err.txt" \
  || fail "(c) stderr lacks 'pipx install conversus-oss' install pointer"
[ ! -e "$PACKET_C" ] || fail "(c) packet was created/modified on the block path (must be untouched)"

echo "PASS: m034-p01 producer"
