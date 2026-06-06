#!/usr/bin/env bash
# tools/verify/m034-p01-writer.sh — M034 P01 verifier for write-decisions.sh.
#
# Tests:
#   (a) baseline round-trip — 8 baseline entries -> packet whose ## D-N blocks
#       each carry all eight required fields + a content_hash;
#   (b) idempotent no-op — same input against same --out file -> no new blocks;
#   (c) changed rationale -> a -v2 block appears carrying supersedes: and the
#       prior block gains superseded_by:;
#   (d) jq-required error path — guard message exists + error path exercised.
#
# Throwaway packets under $TMPDIR (or repo tmp/). Prints `PASS: m034-p01 writer`
# on success, `FAIL: ...` + exit 1 otherwise.
#
# Bash 3.2 / POSIX-sh. Run via plain `bash tools/verify/m034-p01-writer.sh`.

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WRITER="$REPO_ROOT/scripts/knowledge/write-decisions.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/m034-p01-writer.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Build the 8-entry {"decisions":[...]} doc from the baseline fixture.
# The fixture is hand-authored markdown blocks; reshape into the stdin JSON.
FIXTURE="$REPO_ROOT/.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md"
[ -f "$FIXTURE" ] || fail "baseline fixture not found: $FIXTURE"

# Parse the fixture's ## D-N bold-key bullet blocks into a decisions array.
# awk emits one compact-ish JSON object per entry; jq -s wraps into {"decisions":[...]}.
ENTRIES_JSON="$WORK/entries.json"
awk '
  function jesc(s,   r) {
    r = s
    gsub(/\\/, "\\\\", r)
    gsub(/"/, "\\\"", r)
    return r
  }
  function field(line, key,   v) {
    v = line
    sub("^- \\*\\*" key "\\*\\*: ", "", v)
    return v
  }
  function flush() {
    if (id != "") {
      printf "{"
      printf "\"id\":\"%s\",", jesc(id)
      printf "\"summary\":\"%s\",", jesc(summary)
      printf "\"picked_value\":\"%s\",", jesc(picked)
      printf "\"rationale\":\"%s\",", jesc(rationale)
      printf "\"alternatives_considered\":\"%s\",", jesc(alts)
      printf "\"concrete_impact\":\"%s\",", jesc(impact)
      printf "\"severity\":\"%s\",", jesc(severity)
      printf "\"type\":\"%s\"", jesc(typ)
      printf "}\n"
    }
    id=""; summary=""; picked=""; rationale=""; alts=""; impact=""; severity=""; typ=""
  }
  /^## D-/ { flush(); next }
  /^- \*\*id\*\*: /                      { id = field($0, "id"); next }
  /^- \*\*summary\*\*: /                 { summary = field($0, "summary"); next }
  /^- \*\*picked_value\*\*: /            { picked = field($0, "picked_value"); next }
  /^- \*\*rationale\*\*: /               { rationale = field($0, "rationale"); next }
  /^- \*\*alternatives_considered\*\*: / { alts = field($0, "alternatives_considered"); next }
  /^- \*\*concrete_impact\*\*: /         { impact = field($0, "concrete_impact"); next }
  /^- \*\*severity\*\*: /                { severity = field($0, "severity"); next }
  /^- \*\*type\*\*: /                    { typ = field($0, "type"); next }
  END { flush() }
' "$FIXTURE" | jq -s '{decisions: .}' > "$ENTRIES_JSON"

NUM=$(jq '.decisions | length' "$ENTRIES_JSON")
[ "$NUM" -eq 8 ] || fail "expected 8 parsed baseline entries, got $NUM"

# ---------------------------------------------------------------------------
# (a) Baseline round-trip.
PACKET="$WORK/packet-DECISIONS.md"
jq -c '.' "$ENTRIES_JSON" | bash "$WRITER" \
  --milestone=M034 \
  --artifact=catalog/lake-attributes-catalog.md \
  --out="$PACKET" >/dev/null 2>&1 \
  || fail "(a) writer exited non-zero on baseline round-trip"

[ -f "$PACKET" ] || fail "(a) packet not created"

# Every entry block must carry all eight required fields + content_hash.
n=1
while [ "$n" -le 8 ]; do
  id="D-$n"
  # Slice the block for this id: from `## D-n` to the next `## ` or EOF.
  block=$(awk -v want="## $id" '
    $0 == want { grab=1; print; next }
    /^## / && grab { exit }
    grab { print }
  ' "$PACKET")
  [ -n "$block" ] || fail "(a) block $id missing from packet"
  for key in id summary picked_value rationale alternatives_considered concrete_impact severity type content_hash; do
    printf '%s\n' "$block" | grep -q "^- \*\*$key\*\*: " \
      || fail "(a) block $id missing field '$key'"
  done
  n=$((n + 1))
done

# Sanity: the warn-severity entry (D-5) and boundary_translation entry (D-7)
# survived the round-trip with their non-default values.
grep -q "^- \*\*severity\*\*: warn$" "$PACKET" || fail "(a) warn severity not preserved"
grep -q "^- \*\*type\*\*: boundary_translation$" "$PACKET" || fail "(a) boundary_translation type not preserved"

# ---------------------------------------------------------------------------
# (b) Idempotent no-op: same input, same --out -> no new blocks.
BLOCKS_BEFORE=$(grep -c '^## ' "$PACKET")
jq -c '.' "$ENTRIES_JSON" | bash "$WRITER" \
  --milestone=M034 \
  --artifact=catalog/lake-attributes-catalog.md \
  --out="$PACKET" >/dev/null 2>&1 \
  || fail "(b) writer exited non-zero on idempotent re-emit"
BLOCKS_AFTER=$(grep -c '^## ' "$PACKET")
[ "$BLOCKS_BEFORE" -eq "$BLOCKS_AFTER" ] \
  || fail "(b) block count changed on idempotent re-emit ($BLOCKS_BEFORE -> $BLOCKS_AFTER)"

# ---------------------------------------------------------------------------
# (c) Changed rationale on D-1 -> D-1-v2 supersede block + prior superseded_by.
CHANGED_JSON="$WORK/entries-changed.json"
jq '(.decisions[] | select(.id == "D-1") | .rationale) |= . + " [revised: new tiebreak constraint added]"' \
  "$ENTRIES_JSON" > "$CHANGED_JSON"

jq -c '.' "$CHANGED_JSON" | bash "$WRITER" \
  --milestone=M034 \
  --artifact=catalog/lake-attributes-catalog.md \
  --out="$PACKET" >/dev/null 2>&1 \
  || fail "(c) writer exited non-zero on changed re-emit"

grep -q "^## D-1-v2$" "$PACKET" || fail "(c) expected ## D-1-v2 supersede block not found"

# The new -v2 block must carry supersedes: D-1.
v2block=$(awk '
  $0 == "## D-1-v2" { grab=1; print; next }
  /^## / && grab { exit }
  grab { print }
' "$PACKET")
printf '%s\n' "$v2block" | grep -q "^- \*\*supersedes\*\*: D-1$" \
  || fail "(c) D-1-v2 missing 'supersedes: D-1'"

# The prior D-1 block must now carry superseded_by: D-1-v2.
v1block=$(awk '
  $0 == "## D-1" { grab=1; print; next }
  /^## / && grab { exit }
  grab { print }
' "$PACKET")
printf '%s\n' "$v1block" | grep -q "^- \*\*superseded_by\*\*: D-1-v2$" \
  || fail "(c) prior D-1 missing 'superseded_by: D-1-v2'"

# A second change-re-run with the SAME changed input must be a no-op now
# (tip is D-1-v2; its hash matches) — no D-1-v3.
jq -c '.' "$CHANGED_JSON" | bash "$WRITER" \
  --milestone=M034 \
  --artifact=catalog/lake-attributes-catalog.md \
  --out="$PACKET" >/dev/null 2>&1 \
  || fail "(c) writer exited non-zero on changed re-emit (2nd run)"
if grep -q "^## D-1-v3$" "$PACKET"; then
  fail "(c) unexpected D-1-v3 — supersede chain not idempotent at the tip"
fi

# ---------------------------------------------------------------------------
# (d) jq-required error path.
# Source-grep: the guard must reference `command -v jq`.
grep -q "command -v jq" "$WRITER" || fail "(d) writer lacks 'command -v jq' guard"

# Exercise the guard by running with a PATH that omits jq. Build a fake bin
# that symlinks the externals the writer touches BEFORE the guard (dirname),
# but deliberately contains no jq, so `command -v jq` fails.
FAKEBIN="$WORK/fakebin"
mkdir -p "$FAKEBIN"
ln -s "$(command -v dirname)" "$FAKEBIN/dirname"
# (cd/pwd are shell builtins; the sourced SSOT lib uses no externals.)
# Invoke bash by ABSOLUTE path so `env` can exec it even though the child's
# PATH (fakebin) omits jq — that omission is what trips `command -v jq`.
BASH_ABS=$(command -v bash)
ERR_OUT="$WORK/jq-err.txt"
set +e
echo '{"decisions":[]}' | env PATH="$FAKEBIN" "$BASH_ABS" "$WRITER" \
  --milestone=M034 --artifact=x --out=- >/dev/null 2>"$ERR_OUT"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "(d) writer did not exit non-zero when jq absent"
grep -q "requires jq" "$ERR_OUT" || fail "(d) writer did not print the requires-jq error"

echo "PASS: m034-p01 writer"
