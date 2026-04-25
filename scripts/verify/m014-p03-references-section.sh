#!/usr/bin/env bash
# scripts/verify/m014-p03-references-section.sh
# Gate: M014/P03/T05 — references/spec-management.md gains the
# Comment Classification & Workflow Routing section AND the existing
# P04-completed sections are byte-preserved (Section Contract,
# Dual-Write Marker Convention, --dry-run Manifest Shape, Failure
# Semantics, Complexity Probe, Conversus Pressure-Test, Decomposition
# Flow, --amend Three-Case Semantics).
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REF="${PROJECT_ROOT}/references/spec-management.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$REF" ] || fail "references/spec-management.md missing"

# T05 new section — heading exists.
grep -qE '^## Comment Classification & Workflow Routing' "$REF" \
  || fail "Comment Classification & Workflow Routing section missing"

# P04-completed section headings still present (byte-preservation
# proxy — exact heading match).
grep -qE '^## Section Contract' "$REF"                          || fail "Section Contract heading missing"
grep -qE '^## Dual-Write Marker Convention' "$REF"              || fail "Dual-Write Marker Convention heading missing"
grep -qE '^## .--dry-run. Manifest Shape \(FR-19\)' "$REF"      || fail "--dry-run Manifest Shape heading missing"
grep -qE '^## Failure Semantics' "$REF"                         || fail "Failure Semantics heading missing"
grep -qE '^## Complexity Probe \(FR-5\)' "$REF"                 || fail "Complexity Probe heading missing"
grep -qE '^## Conversus Pressure-Test' "$REF"                   || fail "Conversus Pressure-Test heading missing"
grep -qE '^## Decomposition Flow \(FR-7\)' "$REF"               || fail "Decomposition Flow heading missing"
grep -qE '^## .--amend. Three-Case Semantics \(FR-14\)' "$REF"  || fail "--amend Three-Case Semantics heading missing"

# P04 invariants and cross-references that must remain byte-preserved.
grep -qF 'hardening_spec_exception' "$REF"                      || fail "hardening_spec_exception cross-reference dropped"
grep -qF 'CALIBRATION-MEMO.md' "$REF"                           || fail "CALIBRATION-MEMO.md cross-reference dropped"
grep -qF 'spec-pressure-test.yml' "$REF"                        || fail "spec-pressure-test.yml cross-reference dropped"
grep -qF 'decomposition-manifest' "$REF"                        || fail "decomposition-manifest cross-reference dropped"
grep -qF 'SC-14' "$REF"                                         || fail "SC-14 cross-reference dropped"

# T05 content — FR-9 v1 ruleset name + D023 + spec-amendment human-gate language.
grep -qF 'regex/heuristic v1' "$REF"                            || fail "regex/heuristic v1 ruleset name missing"
grep -qF 'D023' "$REF"                                          || fail "D023 cross-reference missing"
grep -qF 'CON-5/SC-5' "$REF"                                    || fail "CON-5/SC-5 invariant language missing"
grep -qF 'spec-amendment-human-gate.sh' "$REF"                  || fail "spec-amendment-human-gate.sh cross-reference missing"
grep -qF 'D023 retune trigger' "$REF"                           || fail "D023 retune trigger heading/language missing"

# Auto-apply threshold table rows.
grep -qE '\| .uat-bug. \| 0\.8' "$REF"                          || fail "uat-bug 0.8 row missing"
grep -qE '\| .decision-append. \| 0\.8' "$REF"                  || fail "decision-append 0.8 row missing"
grep -qE '\| .spec-amendment. \| 1\.0' "$REF"                   || fail "spec-amendment 1.0 row missing"
grep -qE '\| .ambiguous. \| 1\.0' "$REF"                        || fail "ambiguous 1.0 row missing"

echo "PASS: $(basename "$0")"
exit 0
