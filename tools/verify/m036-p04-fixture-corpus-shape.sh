#!/usr/bin/env bash
# tools/verify/m036-p04-fixture-corpus-shape.sh -- M036 P04 T01.
# Asserts the P04 reference-corpus fixture is on disk: 6 valid REF
# chunks across the 4 taxonomy categories + 3 negative-path chunks
# under _negative/<reason>/.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
# Valid fixtures (one per file across the 4 taxonomy categories).
checkfile "$FX/cms-rule/REF-cms-rule-fixture-01.md"
checkfile "$FX/cms-rule/REF-cms-rule-fixture-02.md"
checkfile "$FX/training-material/REF-training-material-fixture-01.md"
checkfile "$FX/training-material/REF-training-material-fixture-02.md"
checkfile "$FX/glossary/REF-glossary-fixture-01.md"
checkfile "$FX/regulatory-doc/REF-regulatory-doc-fixture-01.md"
# Negative fixtures (under _negative/ — driver does NOT auto-walk).
checkfile "$FX/_negative/unknown-category/REF-blog-post-fixture.md"
checkfile "$FX/_negative/missing-source/REF-cms-rule-no-source.md"
checkfile "$FX/_negative/tier-2-block/REF-cms-rule-blocked.md"
# Frontmatter-shape spot-checks on a representative valid fixture.
SAMPLE="$FX/cms-rule/REF-cms-rule-fixture-01.md"
if [ -f "$SAMPLE" ]; then
  for pat in "category: \"cms-rule\"" "cite_id: \"fixture-01\"" "tier: 2" "topic_tags:" "applies_to_field:"; do
    if grep -qF -e "$pat" "$SAMPLE"; then
      echo "PASS: '$pat' in $(basename "$SAMPLE")"
    else
      echo "FAIL: '$pat' missing in $(basename "$SAMPLE")"
      fail=$((fail + 1))
    fi
  done
fi
# Tier-2-block fixture must declare the BLOCK verdict.
BLOCKED="$FX/_negative/tier-2-block/REF-cms-rule-blocked.md"
if [ -f "$BLOCKED" ]; then
  if grep -qF -e 'tier_2_verdict: "BLOCK"' "$BLOCKED"; then
    echo "PASS: BLOCK fixture declares tier_2_verdict"
  else
    echo "FAIL: BLOCK fixture missing tier_2_verdict"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p04-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
