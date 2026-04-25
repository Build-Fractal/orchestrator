#!/usr/bin/env bash
# scripts/verify/m020-p06-preferences-doc-content.sh
#
# Verifies references/preferences.md documents the load-bearing facts:
#   - file exists
#   - names all five keys verbatim
#   - documents project>user>default precedence
#   - documents per-key independent resolution (THREAT-007 disposition)
#   - contains the worked malformed example (not-a-number + WARN: pref_resolve)
#   - mentions the closed-enum vocabulary (the literal word "closed")
#   - names both file paths verbatim (~/.orchestrator/preferences.yml and
#     .orchestrator/preferences.yml)
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape. MEM002 pass()/fail().
# Read-only — reads the static doc only, no fixtures, no tempdir.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/references/preferences.md"

# pass/fail parallel-scalar pattern (no declare -A).
pc=0
fc=0
pass() { pc=$((pc + 1)); echo "PASS: $*"; }
fail() { fc=$((fc + 1)); echo "FAIL: $*" >&2; }

# 1. File exists.
if [ -f "$DOC" ]; then
  pass "references/preferences.md exists"
else
  fail "references/preferences.md not found at $DOC"
  echo "RESULT: ${pc}/$((pc + fc)) PASS"
  exit 1
fi

# 2. All five keys named verbatim.
for key in default_state_filter similarity_threshold staleness_threshold preferred_cluster_size operator_identifier; do
  if grep -q -F "$key" "$DOC"; then
    pass "doc names $key"
  else
    fail "doc missing key: $key"
  fi
done

# 3. Precedence rule (project ... user ... default in order).
# Use awk to confirm the three tokens appear in that order somewhere in the doc.
order_ok="$(awk '
  BEGIN { stage = 0 }
  stage == 0 && tolower($0) ~ /project/ { stage = 1; next }
  stage == 1 && tolower($0) ~ /user/    { stage = 2; next }
  stage == 2 && tolower($0) ~ /default/ { stage = 3; exit }
  END { print stage }
' "$DOC")"
if [ "$order_ok" = "3" ]; then
  pass "doc names project>user>default precedence"
else
  fail "doc does not present project/user/default in expected order (stage=$order_ok)"
fi

# 4. Per-key independent resolution (THREAT-007). Grep for "INDEPENDENTLY"
#    (the doc's literal capitalized form) or "independent" as a fallback.
if grep -q -E 'INDEPENDENTLY|independent' "$DOC"; then
  pass "doc mentions per-key independent resolution"
else
  fail "doc does not document per-key independent resolution (THREAT-007)"
fi

# 5. Worked malformed example: both 'not-a-number' and 'WARN: pref_resolve' present.
malformed_ok=1
if grep -q -F 'not-a-number' "$DOC"; then
  :
else
  malformed_ok=0
fi
if grep -q -F 'WARN: pref_resolve' "$DOC"; then
  :
else
  malformed_ok=0
fi
if [ "$malformed_ok" = "1" ]; then
  pass "doc contains worked malformed example"
else
  fail "doc missing worked malformed example (need both 'not-a-number' and 'WARN: pref_resolve')"
fi

# 6. Closed-enum vocabulary phrase.
if grep -q -i 'closed' "$DOC"; then
  pass "doc mentions closed enum vocabulary"
else
  fail "doc missing closed-enum vocabulary phrase"
fi

# 7. Both file paths verbatim.
paths_ok=1
if grep -q -F '~/.orchestrator/preferences.yml' "$DOC"; then
  :
else
  paths_ok=0
fi
if grep -q -F '.orchestrator/preferences.yml' "$DOC"; then
  :
else
  paths_ok=0
fi
if [ "$paths_ok" = "1" ]; then
  pass "doc names both file paths"
else
  fail "doc missing one or both preferences file paths"
fi

echo "RESULT: ${pc}/$((pc + fc)) PASS"
[ "$fc" -eq 0 ] || exit 1
exit 0
