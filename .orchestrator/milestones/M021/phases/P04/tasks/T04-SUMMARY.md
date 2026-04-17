---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M021"
provides:
  - ".orchestrator/DECISIONS.md D012 row (M021-before-M019 reorder) with substrings D012/sequencing/M019/zero-prompt; ANTIPATTERNS.md Cross-Refs blocks under AP-005..AP-009 each naming scripts/hooks/pre-bash-shape-guard.sh (enforcement), tests/fixtures/m021-prompt-corpus.txt (regression corpus), and scripts/verify/lib/shape-classifier.sh (classifier)"
requires:
  - "from:P01 what:scripts/util/with-env.sh + scripts/util/read-range.sh + scripts/util/run-probe.sh referenced in Remedy text; from:P02 what:AP-005..AP-009 entries previously authored; from:P03 what:scripts/hooks/pre-bash-shape-guard.sh plus scripts/verify/lib/shape-classifier.sh; from:P04/T01 what:tests/fixtures/m021-prompt-corpus.txt path citation; from-disk:.orchestrator/DECISIONS.md (D001..D011) plus ANTIPATTERNS.md (AP-001..AP-009)"
affects:
  - "P04,M021"
key_files:
  - ".orchestrator/DECISIONS.md, ANTIPATTERNS.md"
key_decisions:
  - "D012, AD-11 append-only, constitution XV surgical precision"
patterns_established:
  - "Auto-assigned D-ID via scripts/knowledge/append-decision.sh (highest+1); surgical edit to the just-appended D012 row to normalize Revisable column (removing script-default Yes tail when Revisable content was passed inline via pipe separator in Rationale arg) — pre-existing D001..D011 rows stayed byte-identical; additive Cross-Refs block pattern on AP-005..AP-009 (three-bullet: enforcement layer, regression corpus, classifier implementation) preserving AP-001..AP-004 unchanged; envelope respected (DECISIONS: +1 line, ANTIPATTERNS: +25 lines)"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P04/tasks/T04-PAYLOAD.md, .orchestrator/milestones/M021/phases/P04/tasks/T04-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-17T21:39:17Z"
---

Appended D012 row to .orchestrator/DECISIONS.md via scripts/knowledge/append-decision.sh documenting the M021-before-M019 reorder (sequencing, scope scopes; zero-prompt baseline rationale). The append-decision.sh interface auto-assigned D012 as highest+1 per append-only discipline (AD-11). The Rationale field was passed as a single argument containing the conceptual Rationale+Revisable content separated by a literal pipe (matching the payload's single-physical-line proposed row), and the script's default Revisable Yes tail was removed via surgical Edit to align the table-cell count to 7 columns (9 awk fields with empty leading and trailing). Final D012 row passes all T05 gate substring checks: D012, sequencing, M019, zero-prompt. D001..D011 remain byte-identical. Added Cross-Refs block to each of AP-005, AP-006, AP-007, AP-008, AP-009 in ANTIPATTERNS.md immediately after the existing Remedy block. Each block contains three bullets naming: (1) scripts/hooks/pre-bash-shape-guard.sh as the P03 PreToolUse enforcement layer with the per-AP anchor pointer, (2) tests/fixtures/m021-prompt-corpus.txt as the P04 regression corpus with per-AP EXPECTED_OUTCOME hint, (3) scripts/verify/lib/shape-classifier.sh as the shared classifier library. AP-001..AP-004 not touched (no Cross-Refs lines). File grew from 189 to 214 lines (+25, within 5..40 envelope). No deviations from payload scaffold except the surgical Revisable-cell normalization noted above (constitution XV — surgical precision applied to the freshly-appended row, not to pre-existing content). Anti-pattern linter repo sweep still flags T04-PAYLOAD.md line 899 (the payload's illustrative D012 row containing semicolon chains inside prose) — this clears automatically once T04-SUMMARY.md lands (PAYLOAD active-task exclusion fires on sibling summary per P02 pattern).
