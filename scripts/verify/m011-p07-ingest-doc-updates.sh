#!/usr/bin/env bash
# scripts/verify/m011-p07-ingest-doc-updates.sh
#
# Asserts that commands/ingest.md carries the P07 updates:
#   - new flags --review / --no-review / --force
#   - workflow references detect-spec-shape.sh, normalize-spec.sh,
#     adapters/tool/conversus.sh, intensity-gate.sh --stage ingest
#   - FORCE: audit-trail marker documented
#   - "normalized artifact written BEFORE the fidelity gate" assurance
#   - all P06 Reference File bullets preserved
#
# Bash 3.2 compatible (MEM001). BSD-grep safe: every token beginning
# with `-` is matched via `grep -Fq -- "$tok"` (MEM012). Single-script-
# file invokable (AD-19).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/commands/ingest.md"

pass_count=0
fail_count=0

emit_pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

emit_fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

# 1. File exists.
if [ -f "$DOC" ]; then
  emit_pass "commands/ingest.md exists"
else
  emit_fail "commands/ingest.md missing at $DOC"
  echo "SUMMARY: pass=$pass_count fail=$fail_count"
  exit 1
fi

# 2. Line count >= 140.
LC=$(wc -l <"$DOC" | tr -d '[:space:]')
if [ "$LC" -ge 140 ]; then
  emit_pass "commands/ingest.md has $LC lines (>= 140)"
else
  emit_fail "commands/ingest.md too short: $LC lines (expected >= 140)"
fi

# 3-5. New flag tokens present.
assert_token() {
  tok="$1"
  label="$2"
  if grep -Fq -- "$tok" "$DOC"; then
    emit_pass "$label: '$tok' present"
  else
    emit_fail "$label: '$tok' missing"
  fi
}

assert_token "--review"    "review flag"
assert_token "--no-review" "no-review flag"
assert_token "--force"     "force flag (preserved from P06)"

# 6-7. Script references for the new pipeline steps.
assert_token "detect-spec-shape.sh"      "shape probe reference"
assert_token "normalize-spec.sh"         "normalizer wrapper reference"
assert_token "adapters/tool/conversus.sh" "conversus tool-adapter reference"

# 8. Intensity-gate invocation literal.
assert_token "intensity-gate.sh --stage ingest" "intensity-gate ingest-stage invocation literal"

# 9. FORCE: audit-trail marker.
assert_token "FORCE:" "FORCE: audit-trail marker"

# 10. "normalized artifact" + "BEFORE" + "fidelity gate" appear within 3
#     consecutive lines of each other (via grep -B2 -A2 on 'normalized
#     artifact' and then checking for the other two tokens in the window).
WINDOW=$(grep -n -B 2 -A 2 -- 'normalized artifact' "$DOC" 2>/dev/null || true)
if [ -n "$WINDOW" ]; then
  if echo "$WINDOW" | grep -Fq -- 'BEFORE'; then
    if echo "$WINDOW" | grep -Fq -- 'fidelity gate'; then
      emit_pass "normalization-before-gate assurance phrase present"
    else
      emit_fail "normalization-before-gate: 'fidelity gate' not found near 'normalized artifact'"
    fi
  else
    emit_fail "normalization-before-gate: 'BEFORE' not found near 'normalized artifact'"
  fi
else
  emit_fail "normalization-before-gate: 'normalized artifact' phrase missing entirely"
fi

# 11. Preserved P06 Reference File bullets.
assert_token "scripts/knowledge/ingest-spec.sh"  "P06 ref: ingest-spec.sh"
assert_token "scripts/knowledge/rebuild-index.sh" "P06 ref: rebuild-index.sh"
assert_token "scripts/state/spec-metrics.sh"     "P06 ref: spec-metrics.sh"
assert_token "scripts/dispatch/scope-filter.sh"  "P06 ref: scope-filter.sh"
assert_token "knowledge/spec/"                   "P06 ref: knowledge/spec/ tree"
assert_token "templates/evaluation.md"           "P06 ref: evaluation template"

echo "SUMMARY: pass=$pass_count fail=$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
