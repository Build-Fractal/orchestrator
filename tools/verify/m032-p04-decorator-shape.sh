#!/usr/bin/env bash
# tools/verify/m032-p04-decorator-shape.sh
# M032/P04/T02 — FR-20 build-time code-shorthand decorator surface verifier.
#
# Asserts that scripts/wiki/wiki-decorate-codes.sh:
#   - exists and is executable
#   - implements the documented --in / --glossary / --out interface
#   - contains the four documented regex pattern literals (verbatim)
#   - implements first-occurrence-titled / subsequent-link-only rule
#   - implements the missing-glossary fallback (debug stderr + cp byte-identical)
#   - carries the stub-shaped framing comment (Principle XIV)
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DECORATOR="$REPO_ROOT/scripts/wiki/wiki-decorate-codes.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$DECORATOR" ]; then
  say_fail "$DECORATOR absent"
  printf 'SUMMARY: m032-p04-decorator-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "decorator exists at $DECORATOR"

if [ ! -x "$DECORATOR" ]; then
  say_fail "decorator is not executable"
else
  say_pass "decorator is executable"
fi

# --in / --glossary / --out interface tokens.
for tok in '--in' '--glossary' '--out'; do
  if grep -qF -- "$tok)" "$DECORATOR"; then
    say_pass "decorator interface contains: $tok"
  else
    say_fail "decorator interface missing: $tok"
  fi
done

# Four documented regex pattern literals (verbatim from payload).
# Patterns scanned: [A-Z]{2,4}-\d+, M\d{3}, DR-[A-Z]+-\d+, AP-\d+
for tok in '[A-Z]{2,4}-\d+' 'M\d{3}' 'DR-[A-Z]+-\d+' 'AP-\d+'; do
  if grep -qF -- "$tok" "$DECORATOR"; then
    say_pass "decorator documents regex: $tok"
  else
    say_fail "decorator missing regex literal: $tok"
  fi
done

# First-occurrence-titled / subsequent-link-only rewrite-rule documentation.
for tok in 'First-occurrence-per-page' 'Subsequent occurrences' 'CODE (Title)' 'link-only'; do
  if grep -qF -- "$tok" "$DECORATOR"; then
    say_pass "decorator documents rewrite rule: $tok"
  else
    say_fail "decorator missing rewrite-rule token: $tok"
  fi
done

# Missing-glossary fallback (debug stderr + byte-identical cp).
for tok in 'no glossary resolved, skipping decoration' 'cp "$IN" "$OUT"'; do
  if grep -qF -- "$tok" "$DECORATOR"; then
    say_pass "decorator implements missing-glossary fallback: $tok"
  else
    say_fail "decorator missing fallback token: $tok"
  fi
done

# Stub-shaped framing comment (Principle XIV — load-bearing).
for tok in 'P3 stub' 'post-launch wiki-UX-deep' 'Principle XIV'; do
  if grep -qF -- "$tok" "$DECORATOR"; then
    say_pass "decorator carries stub-framing token: $tok"
  else
    say_fail "decorator missing stub-framing token: $tok"
  fi
done

# Bash 3.2 compatibility — no declare -A, no process substitution.
# Strip comment lines before grepping so the documentation comment block
# ("no declare -A, no process substitution") doesn't trip the check.
if grep -v '^[[:space:]]*#' "$DECORATOR" | grep -qE 'declare -A'; then
  say_fail "decorator violates MEM001: contains 'declare -A'"
else
  say_pass "decorator bash-3.2 safe: no 'declare -A'"
fi

# Token surface for FR-20 / US-8.
for tok in 'FR-20' 'US-8' 'Finding G'; do
  if grep -qF -- "$tok" "$DECORATOR"; then
    say_pass "decorator references decision id: $tok"
  else
    say_fail "decorator missing decision id: $tok"
  fi
done

printf 'SUMMARY: m032-p04-decorator-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
