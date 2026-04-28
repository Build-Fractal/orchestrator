#!/usr/bin/env bash
# scripts/verify/m018-p06-tier3-prompt-template.sh — phase-truth verifier:
# "templates/compression-tier3-prompt.md exists with versioned frontmatter
# and a body that names input contract (section header + body bytes) and
# output contract (in-band marker + summary body)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TPL="$REPO_ROOT/templates/compression-tier3-prompt.md"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: template file exists.
if [ -f "$TPL" ]; then
  pass "compression-tier3-prompt.md exists"
else
  fail "compression-tier3-prompt.md missing at $TPL"
  exit 1
fi

# --- Assertion 2: frontmatter declares tier: 3.
if grep -qE '^tier:[[:space:]]*3' "$TPL"; then
  pass "frontmatter declares tier: 3"
else
  fail "frontmatter missing 'tier: 3'"
fi

# --- Assertion 3: applies_to contains dispatch-payload-section.
if grep -q 'dispatch-payload-section' "$TPL"; then
  pass "frontmatter applies_to names dispatch-payload-section"
else
  fail "frontmatter applies_to missing dispatch-payload-section"
fi

# --- Assertion 4: schema_version present.
if grep -qE '^schema_version:' "$TPL"; then
  pass "frontmatter declares schema_version"
else
  fail "frontmatter missing schema_version"
fi

# --- Assertion 5: preserves: array contains every preserved-pattern token
# named in references/compression-grammar.md Tier 3 section. Markers:
# frontmatter, code fences, JSONL, MEM identifiers, paths,
# scaffold-placeholder markers, URLs, command names, in-band markers.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

# Extract preserves block (between first 'preserves:' and the next ']' line).
PRES="$TMPDIR_E/preserves.txt"
awk '
  /^preserves:/ { in_p=1 }
  in_p { print }
  in_p && /^\]/ { exit }
' "$TPL" > "$PRES"

if [ ! -s "$PRES" ]; then
  fail "preserves: array missing or empty in template frontmatter"
else
  pass "preserves: array extracted"
fi

# Required tokens (substrings within the preserves array).
REQUIRED_TOKENS="frontmatter|code fences|JSONL|MEM|paths|scaffold-placeholder|URL|command|in-band"
i=0
for tok in frontmatter "code fences" JSONL MEM paths scaffold-placeholder URL command "in-band"; do
  i=$((i + 1))
  if grep -qi "$tok" "$PRES"; then
    pass "preserves: token #$i ('$tok') present"
  else
    fail "preserves: token #$i ('$tok') missing"
  fi
done

# --- Assertion 6: body contains the in-band marker template literal.
if grep -q 'compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M>' "$TPL"; then
  pass "body contains in-band marker template literal"
else
  fail "body missing 'compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M>' literal"
fi

# --- Assertion 7: body contains the '## Section to compress' header (where
# the helper appends the section bytes).
if grep -q '^## Section to compress' "$TPL"; then
  pass "body contains '## Section to compress' header"
else
  fail "body missing '## Section to compress' header"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p06-tier3-prompt-template (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p06-tier3-prompt-template (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
