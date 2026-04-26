#!/usr/bin/env bash
# scripts/verify/m024-p03-evaluate-md.sh
# Verifies commands/evaluate.md ships the "Input Shapes" section per P03.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/commands/evaluate.md"

[ -f "$DOC" ] || { echo "FAIL: $DOC missing"; exit 1; }

grep -q '^## Input Shapes' "$DOC" || { echo "FAIL: $DOC missing '## Input Shapes' section"; exit 1; }

# All five shapes named in the section.
# NOTE: M024/P05 supersedes the P03 stub `empty` shape with `empty_qa` once
# the bounded Q&A loop is wired (commands/evaluate.md row 21). Either form
# satisfies the "empty" assertion — they refer to the same input shape
# (no --input + no --spec-path), but `empty_qa` is the post-P05 canonical
# name carrying the embedded ## Q&A transcript contract.
for shape in spec paragraph fragment idea empty; do
  if [ "$shape" = "empty" ]; then
    if grep -q "\`empty\`" "$DOC" || grep -q "\`empty_qa\`" "$DOC"; then
      continue
    fi
    echo "FAIL: $DOC does not name shape 'empty' or 'empty_qa' (M024/P05 alias) in backticks"
    exit 1
  fi
  if ! grep -q "\`$shape\`" "$DOC"; then
    echo "FAIL: $DOC does not name shape '$shape' in backticks"
    exit 1
  fi
done

# Back-references to P01 + P03 scripts.
for script in shape-detect.sh paragraph-classify.sh approval-gate.sh route-to-specify.sh route-to-dispatch.sh; do
  if ! grep -q "$script" "$DOC"; then
    echo "FAIL: $DOC does not back-reference $script"
    exit 1
  fi
done

# Legacy spec discovery section preserved (FR-6 byte-compat marker).
grep -q '^## Spec Discovery' "$DOC" || grep -q '^### 2. Spec Discovery' "$DOC" || {
  echo "FAIL: $DOC removed legacy Spec Discovery section (FR-6 violation)"
  exit 1
}

echo "PASS: evaluate.md — Input Shapes section + all five shapes + back-references + legacy preserved"
exit 0
