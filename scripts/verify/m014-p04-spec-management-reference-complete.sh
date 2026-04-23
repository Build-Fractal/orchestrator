#!/usr/bin/env bash
# Gate: T06 — references/spec-management.md completion (SC-11).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REF="${PROJECT_ROOT}/references/spec-management.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$REF" ] || fail "references/spec-management.md missing"

# Sentinel removed.
grep -qF 'partial: P04 completes' "$REF" \
  && fail "P04 partial sentinel still present — SC-11 not closed"

# Four new top-level sections present.
grep -qE '^## Complexity Probe \(FR-5\)' "$REF"            || fail "Complexity Probe section missing"
grep -qE '^## Conversus Pressure-Test' "$REF"              || fail "Conversus Pressure-Test section missing"
grep -qE '^## Decomposition Flow \(FR-7\)' "$REF"          || fail "Decomposition Flow section missing"
grep -qE '^## `--amend` Three-Case Semantics' "$REF"       || fail "--amend Three-Case Semantics section missing"

# Action_type table extended with three P04 rows.
grep -qF 'invoke-conversus-gate' "$REF"    || fail "action_type table missing invoke-conversus-gate row"
grep -qF 'propose-decomposition' "$REF"    || fail "action_type table missing propose-decomposition row"
grep -qF 'amend-section' "$REF"            || fail "action_type table missing amend-section row"

# Key cross-references present.
grep -qF 'hardening_spec_exception' "$REF"        || fail "hardening_spec_exception documented"
grep -qF 'CALIBRATION-MEMO.md' "$REF"             || fail "CALIBRATION-MEMO.md cross-reference missing"
grep -qF 'spec-pressure-test.yml' "$REF"          || fail "preset file cross-reference missing"
grep -qF 'decomposition-manifest' "$REF"          || fail "decomposition-manifest shape documented"
grep -qF 'SC-14' "$REF"                           || fail "SC-14 invariant documented"

echo "PASS: references/spec-management.md completion verified"
exit 0
