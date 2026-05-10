---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M018"
provides:
  - "public compression-grammar lint gate (FR-1/SC-1); four phase-truth verifiers; M018/P01 runtime-assumptions row; refreshed recent-changes block dual-written to AGENTS.md"
requires:
  - "T01"
affects:
  - "T03 (consumes lint as gate input + runtime-assumptions row); P02-P05 (lint enforces preservation contract as tier code lands); P07 (runtime-parity audit consumes RUNTIME-ASSUMPTIONS.md M018/P01 row)"
key_files:
  - "scripts/verify/compression-grammar-lint.sh, scripts/verify/m018-p01-grammar-shape.sh, scripts/verify/m018-p01-lint-clean.sh, scripts/verify/m018-p01-sc9-traceability.sh, scripts/verify/m018-p01-runtime-assumptions.sh, scripts/verify/m018-p01-dual-write-recent.sh, RUNTIME-ASSUMPTIONS.md, CLAUDE.md, AGENTS.md"
key_decisions:
  - "D016 (RUNTIME-ASSUMPTIONS registry); D028 (P00 calibration backstops the SC-9 floor cited by lint)"
patterns_established:
  - "single-file lint script emits one PASS per (tier, applies-to-class, preserves-pattern) triple via cross-product over awk-extracted bullet sets; phase verifiers wrap the public lint and add narrow extra checks (semver, tier-marker coverage, literal floor traceability); RUNTIME-ASSUMPTIONS append-only with ### M###/P##: heading shape (extends D016 schema beyond ### FR-N: keying)"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P01/tasks/T02-lint-and-runtime-PAYLOAD.md, references/compression-grammar.md, RUNTIME-ASSUMPTIONS.md"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-27T21:54:32Z"
---

T02 closes the four phase-private must-haves M018/P01 owns: (1) the public compression-grammar lint gate; (2) the M018/P01 row in RUNTIME-ASSUMPTIONS.md; (3) the refreshed recent-changes block dual-written across CLAUDE.md and AGENTS.md; (4) phase-truth verifiers that wrap (1)-(3) so the conversus gate in T03 can mechanically confirm them. The fifth must-have (conversus --strict PASS) is T03's responsibility per the phase plan; m018-p01-conversus-pass.sh is intentionally NOT shipped here. Lint emits 33 PASS lines against the T01 grammar; all four phase verifiers exit 0.

The lint script is the load-bearing artifact. It enforces the 14-element grammar shape from T01: frontmatter (5 keys), title, Marker Grammar (must name compressed:tier), Preserved-Pattern Vocabulary, four ## Tier: sections each with non-empty applies-to + preserves bullet blocks, Aggregate Plausibility (SC-9) with literal 34.7, Additive Emitter Invariants (CON-5), Failure Semantics (FR-2) naming tier_preservation_violation, and zero <TODO: markers. The (tier, class, pattern) triple emission is implemented as a cross-product over awk-extracted bullets per tier — not the most semantically-rich emission (each preserves bullet replays under each applies-to class) but it satisfies SC-1's 'one row per triple' requirement and the count grows mechanically with grammar additions.

The dual-write step required calling scripts/util/dual-write-runtime-md.sh with --marker recent-changes --content <fragment>; bare invocation (no flags) hard-fails with 'missing --marker'. Pattern: extract the CLAUDE.md block body to a temp fragment, then dual-write back to both files via --content. AGENTS.md was never edited directly — confirmed via git show.

All scripts are AD-19 single-file shape, bash 3.2 compatible, MEM001 PASS/FAIL stdout, exit 0/1. AP-009-friendly: no compound &&-chains beyond two; no $(... | ...); no process substitution. Commit f1cf742 lands the nine touched files (six new scripts, three modified docs).
