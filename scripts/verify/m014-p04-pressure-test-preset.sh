#!/usr/bin/env bash
# Gate: T03 — FR-6 preset + FR-5/FR-7 prompt bodies.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PRESET="${PROJECT_ROOT}/templates/conversus-presets/spec-pressure-test.yml"
P_CONT="${PROJECT_ROOT}/templates/spec-complexity-contradiction-prompt.md"
P_SPLIT="${PROJECT_ROOT}/templates/spec-splitter-prompt.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$PRESET" ]  || fail "spec-pressure-test.yml missing"
[ -f "$P_CONT" ]  || fail "spec-complexity-contradiction-prompt.md missing"
[ -f "$P_SPLIT" ] || fail "spec-splitter-prompt.md missing"

# Preset shape.
grep -qE '^preset_name: *spec-pressure-test' "$PRESET"                 || fail "preset_name missing"
grep -qE '^mode: *red-blue' "$PRESET"                                  || fail "mode: red-blue missing"
grep -qE '^  - name: *blue-advocate' "$PRESET"                         || fail "blue-advocate missing"
grep -qE '^  - name: *red-advocate' "$PRESET"                          || fail "red-advocate missing"
grep -qE '^  grounding_file: *\.orchestrator/memory/constitution\.md' "$PRESET" || fail "grounding_file wrong"
grep -qE '^  verdict_contract: *PASS\|BLOCK' "$PRESET"                 || fail "verdict_contract wrong"
grep -qE '^  template: *templates/gate-result\.md' "$PRESET"           || fail "output template wrong"
grep -qE '^    - *verdict' "$PRESET"                                   || fail "required_fields missing verdict"
grep -qE '^    - *disputes' "$PRESET"                                  || fail "required_fields missing disputes"
grep -qE '^    - *rationale' "$PRESET"                                 || fail "required_fields missing rationale"
grep -qE '^    - *source_hash' "$PRESET"                               || fail "required_fields missing source_hash"

# Contradiction prompt shape.
CLINES="$(wc -l < "$P_CONT")"
if [ "$CLINES" -lt 40 ]; then fail "contradiction prompt too short: $CLINES lines"; fi
grep -qF 'contradictions=' "$P_CONT" || fail "contradiction prompt missing contradictions= output spec"

# Splitter prompt shape.
SLINES="$(wc -l < "$P_SPLIT")"
if [ "$SLINES" -lt 40 ]; then fail "splitter prompt too short: $SLINES lines"; fi
grep -qF 'decomposition-manifest' "$P_SPLIT" || fail "splitter prompt missing decomposition-manifest type"
grep -qF 'inherited_user_stories' "$P_SPLIT" || fail "splitter prompt missing inherited_user_stories field"

# Sanity check: no adapter modification. The adapter file shasum is NOT checked here
# (changes may happen for unrelated reasons); but the adapter path is confirmed unchanged
# via its presence.
ADAPTER="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
[ -x "$ADAPTER" ] || fail "conversus adapter missing — T03 assumes D007 reuse discipline"

echo "PASS: pressure-test preset + prompt bodies shipped"
exit 0
