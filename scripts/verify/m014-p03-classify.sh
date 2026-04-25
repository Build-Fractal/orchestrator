#!/usr/bin/env bash
# scripts/verify/m014-p03-classify.sh
# Verifies M014/P03/T02: regex/heuristic v1 classifier produces correct
# class verdicts for the four-class fixture corpus.
#
# Cases:
#   A) uat-bug verdict on acceptance-fails fixture
#   B) decision-append verdict on "decision: ..." fixture
#   C) spec-amendment verdict on "FR-N should ..." fixture
#   D) ambiguous verdict on no-rule-fired fixture
#   E) confidence field present + parseable as 0.0-1.0
#   F) classify.sh references "regex/heuristic" (D023 pin docstring)
#   G) classify-comment preset shipped at templates/conversus-presets/
#   H) dogfood-data file exists + cites D023
#
# AD-19: single-script-file shape; no inline compounds beyond &&/|| of two
# commands. CON-6 / MEM001 Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFY="${REPO_ROOT}/scripts/comments/classify.sh"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Build per-class inbox fixtures (single-line JSON, fetch.sh shape).
cat > "$SCRATCH/uat.json" <<'JSON'
{"url":"https://example/issues/1#issuecomment-1","body":"acceptance criterion 2 fails on macOS 13","source_surface":"github","fetched_at":"2026-04-24T00:00:00Z","body_shasum":"deadbeef","id":"c1"}
JSON
cat > "$SCRATCH/dec.json" <<'JSON'
{"url":"https://example/issues/2#issuecomment-2","body":"decision: pin Bash 3.2 across all scripts","source_surface":"github","fetched_at":"2026-04-24T00:01:00Z","body_shasum":"deadbeef","id":"c2"}
JSON
cat > "$SCRATCH/amend.json" <<'JSON'
{"url":"https://example/discussions/3#discussioncomment-3","body":"FR-5 should also cover token-density measurement","source_surface":"giscus","fetched_at":"2026-04-24T00:02:00Z","body_shasum":"deadbeef","id":"c3"}
JSON
cat > "$SCRATCH/amb.json" <<'JSON'
{"url":"https://example/discussions/4#discussioncomment-4","body":"hmm not sure about this approach","source_surface":"giscus","fetched_at":"2026-04-24T00:03:00Z","body_shasum":"deadbeef","id":"c4"}
JSON

# Case A: uat-bug verdict.
out_a="$(bash "$CLASSIFY" "$SCRATCH/uat.json" 2>/dev/null)"
if printf '%s' "$out_a" | grep -q '^class=uat-bug'; then
  _pass "Case A: uat-bug verdict"
else
  _fail "Case A: got: $out_a"
fi

# Case B: decision-append verdict.
out_b="$(bash "$CLASSIFY" "$SCRATCH/dec.json" 2>/dev/null)"
if printf '%s' "$out_b" | grep -q '^class=decision-append'; then
  _pass "Case B: decision-append verdict"
else
  _fail "Case B: got: $out_b"
fi

# Case C: spec-amendment verdict.
out_c="$(bash "$CLASSIFY" "$SCRATCH/amend.json" 2>/dev/null)"
if printf '%s' "$out_c" | grep -q '^class=spec-amendment'; then
  _pass "Case C: spec-amendment verdict"
else
  _fail "Case C: got: $out_c"
fi

# Case D: ambiguous verdict.
out_d="$(bash "$CLASSIFY" "$SCRATCH/amb.json" 2>/dev/null)"
if printf '%s' "$out_d" | grep -q '^class=ambiguous'; then
  _pass "Case D: ambiguous verdict"
else
  _fail "Case D: got: $out_d"
fi

# Case E: confidence field present + parseable as 0.0-1.0.
if printf '%s' "$out_a" | grep -qE 'confidence=0\.[0-9]'; then
  _pass "Case E: confidence field shape"
else
  _fail "Case E: confidence missing/malformed: $out_a"
fi

# Case F: classify.sh references "regex/heuristic" (D023 pin docstring).
# Verifier self-exempts because this very line contains the literal — match
# against the classify script path only.
if grep -q "regex/heuristic" "$CLASSIFY"; then
  _pass "Case F: D023 pin docstring present"
else
  _fail "Case F: classify.sh missing D023 pin docstring"
fi

# Case G: classify-comment preset shipped.
PRESET="${REPO_ROOT}/templates/conversus-presets/classify-comment.yml"
if [ -f "$PRESET" ]; then
  _pass "Case G: classify-comment preset shipped"
else
  _fail "Case G: preset missing at $PRESET"
fi

# Case H: dogfood-data file exists + cites D023.
DOGFOOD="${REPO_ROOT}/specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md"
if [ -f "$DOGFOOD" ]; then
  if grep -q "D023" "$DOGFOOD"; then
    _pass "Case H: dogfood capture cites D023"
  else
    _fail "Case H: dogfood file missing D023 citation"
  fi
else
  _fail "Case H: dogfood file missing at $DOGFOOD"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
