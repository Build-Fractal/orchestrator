#!/usr/bin/env bash
# tests/m032-acceptance/p0X-code-decorator.sh
# SC-9 — verifies FR-20 code-shorthand decorator (US-8 P3 stub).
#
# Three assertion groups per US-8 acceptance scenarios:
#   AS-1: three known + one unknown   — decorated + byte-identical (Finding G).
#   AS-2: first-titled / subsequent-link-only.
#   AS-3: missing-glossary fallback   — exit 0 + byte-identical copy.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).
# Trap-EXIT cleanup of the throwaway fixture per the M032 P03/T04
# throwaway-fixture-protocol convention.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECORATOR="$PROJECT_ROOT/scripts/wiki/wiki-decorate-codes.sh"

FIXTURE="/tmp/m032-p04-sc9-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM
mkdir -p "$FIXTURE"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Common glossary used by AS-1 + AS-2 (US-6 format invariant: ### TERM
# headings + immediately-following non-blank one-line definitions).
cat > "$FIXTURE/gloss.md" <<'EOF'
### M032

Wiki Distribution and Init Integration

### AP-009

Compound chain

### DR-STACK-001

Stack Decision
EOF

# AS-1: three known + one unknown
cat > "$FIXTURE/page.md" <<'EOF'
See M032 + AP-009 + DR-STACK-001 + XYZ-999 for context.
EOF
bash "$DECORATOR" \
  --in "$FIXTURE/page.md" --glossary "$FIXTURE/gloss.md" --out "$FIXTURE/out1.md"
if grep -q 'M032 (Wiki Distribution and Init Integration)' "$FIXTURE/out1.md" \
   && grep -q 'AP-009 (Compound chain)' "$FIXTURE/out1.md" \
   && grep -q 'DR-STACK-001 (Stack Decision)' "$FIXTURE/out1.md" \
   && grep -qF 'XYZ-999' "$FIXTURE/out1.md" \
   && ! grep -q 'XYZ-999 (' "$FIXTURE/out1.md"; then
  say_pass 'AS-1: three known decorated + one unknown byte-identical'
else
  say_fail 'AS-1: decoration mismatch'
fi

# AS-2: first occurrence titled, subsequent link-only.
cat > "$FIXTURE/page2.md" <<'EOF'
M032 mention M032 again
EOF
bash "$DECORATOR" \
  --in "$FIXTURE/page2.md" --glossary "$FIXTURE/gloss.md" --out "$FIXTURE/out2.md"
# First occurrence has '(Wiki Distribution and Init Integration)'; second does not repeat the title.
# Use grep -c with || true under set -uo pipefail per the P02/T03 patterns-
# established gotcha (silent abort when grep -c returns 0 otherwise).
_occurrences_titled=$(grep -c '(Wiki Distribution and Init Integration)' "$FIXTURE/out2.md" || true)
if [ "$_occurrences_titled" -eq 1 ]; then
  say_pass 'AS-2: first-titled subsequent-link-only'
else
  say_fail "AS-2: expected exactly 1 titled occurrence, got $_occurrences_titled"
fi

# AS-3: missing glossary -> exit 0 + byte-identical copy (Finding G).
set +e
bash "$DECORATOR" \
  --in "$FIXTURE/page.md" --glossary "$FIXTURE/missing.md" --out "$FIXTURE/out3.md" 2>/dev/null
_rc=$?
set -e
if [ "$_rc" -eq 0 ] && diff -q "$FIXTURE/page.md" "$FIXTURE/out3.md" >/dev/null; then
  say_pass 'AS-3: missing glossary -> exit 0 + byte-identical copy'
else
  say_fail "AS-3: rc=$_rc or output not byte-identical"
fi

printf 'RESULT: SC-9 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
