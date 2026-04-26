#!/usr/bin/env bash
# scripts/verify/m024-p05-proposal-emit-empty-qa.sh
# M024/P05/T03 verify — empty + qa-answers-from emits empty_qa proposal.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ans="$tmp/answers.txt"
cat > "$ans" <<'EOF'
add a last-seen timestamp to status command output
single-feature
code
no
Standard
EOF

emit_out=$(bash "$EMIT" --qa-answers-from "$ans" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

[ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

grep -q '^input_shape: "empty_qa"$'        "$proposal" || { echo "FAIL: input_shape not empty_qa"; exit 1; }
grep -q '^qa_short_circuited: false$'      "$proposal" || { echo "FAIL: qa_short_circuited not false"; exit 1; }
grep -q '^low_confidence: false$'          "$proposal" || { echo "FAIL: low_confidence should be false on full Q&A run"; exit 1; }
grep -q '^## Q&A$'                         "$proposal" || { echo "FAIL: proposal missing ## Q&A section"; exit 1; }

count=$(grep -c '^### Q' "$proposal")
[ "$count" = "5" ] || { echo "FAIL: proposal Q&A section has $count blocks (expected 5)"; exit 1; }

echo "PASS: proposal-emit.sh — empty + 5 answers → input_shape: empty_qa; ## Q&A with 5 blocks; low_confidence false"
exit 0
