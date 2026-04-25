#!/usr/bin/env bash
# m020-p01-jaccard-pairwise-contract.sh -- exercise pairwise_jaccard
# semantics on synthetic fixtures. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/lib/jaccard.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: jaccard.sh missing or not executable at $SCRIPT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_fixture() {
  local id="$1"
  local title="$2"
  local body="$3"
  cat > "$tmpdir/${id}.md" <<EOF
---
id: ${id}
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
title: "${title}"
topic: "${title}"
tags: ${title}
---

# ${id}: ${title}

${body}
EOF
}

# Identical entries -> similarity 1.0
write_fixture MEMA "alpha beta gamma" "shared body content here"
write_fixture MEMB "alpha beta gamma" "shared body content here"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEMA.md" "$tmpdir/MEMB.md")"
case "$sim_line" in
  similarity=1.0000) ;;
  *)
    echo "FAIL: identical entries produced '$sim_line', expected similarity=1.0000"
    exit 1
    ;;
esac

# Disjoint entries -> similarity 0.0
write_fixture MEMC "foo bar" "completely different words"
write_fixture MEMD "qux quux" "nothing in common at all whatsoever"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEMC.md" "$tmpdir/MEMD.md")"
sim_val="${sim_line#similarity=}"
# Allow some incidental overlap from common stop-tokens; assert < 0.3.
keep="$(awk -v s="$sim_val" 'BEGIN{print (s<0.3)?"y":"n"}')"
if [ "$keep" != "y" ]; then
  echo "FAIL: disjoint entries produced '$sim_line', expected < 0.3"
  exit 1
fi

# Partial overlap entries -> similarity in (0, 1)
write_fixture MEME "shared overlap" "alpha beta gamma extra unique words here"
write_fixture MEMF "shared overlap" "alpha beta gamma different unique terms there"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEME.md" "$tmpdir/MEMF.md")"
sim_val="${sim_line#similarity=}"
keep="$(awk -v s="$sim_val" 'BEGIN{print (s>0.3 && s<1.0)?"y":"n"}')"
if [ "$keep" != "y" ]; then
  echo "FAIL: partial-overlap entries produced '$sim_line', expected (0.3, 1.0)"
  exit 1
fi

# Missing-file rejection
if bash "$SCRIPT" pairwise_jaccard "$tmpdir/MISSING.md" "$tmpdir/MEMA.md" 2>/dev/null; then
  echo "FAIL: pairwise_jaccard accepted nonexistent file"
  exit 1
fi

echo "PASS: pairwise_jaccard contract honored (4/4 cases)"
exit 0
