---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M029"
provides:
  - "AD-6 cross-milestone feature data-model design contract at references/cross-milestone-feature-shape.md (Principle III, upstream of T03 render-position.sh implementation); paired gate verifier at tools/verify/m029-p02-cross-milestone-shape-contract.sh that mechanically asserts every required H1/H2 header, schema token (milestone:/milestones:/M###/feature_ref), canonical glyph (✓ ▶ ◇ ✗ ▽), the #Q-G8 canonical compact savings form (saved Nk), the absence of the forbidden verbose form (via tier1 cache reuse), the AD-6/FR-13/#Q-5/#Q-G8 spec references, the --expand-all flag name, the WARN: advisory token, and the four named consumers (commands/where.md, scripts/diagnostics/render-position.sh, scripts/diagnostics/summarize-milestone.sh, scripts/state/find-active-milestone.sh)"
requires:
  - "from:P01 what:design-contract-pairing-pattern (m029-p01-headline-shape-contract.sh shape precedent for AD-19 straight-line bash + grep -F per-assertion + parallel pass/fail counters)"
affects:
  - "P02-T03,P02-T04,P02-T05"
key_files:
  - "references/cross-milestone-feature-shape.md,tools/verify/m029-p02-cross-milestone-shape-contract.sh"
key_decisions:
  - "AD-6 cross-milestone feature data model (exactly-one-of milestone:/milestones: schema rule + reverse-lookup advisory),#Q-5 inactive-milestone render shape (collapsed by default + --expand-all override + active-milestone always expanded),#Q-G8 FR-8 marker canonical compact form (saved Nk; verbose suffix reserved for future --verbose mode),Principle III (contract upstream of code)"
patterns_established:
  - "Principle-III paired design contract gate verifier shape extended from P01 (m029-p01-headline-shape-contract.sh) to P02; AD-19 straight-line bash with separate grep -F invocation per assertion and parallel pass/fail counters (MEM001/MEM002 bash 3.2 safe); negative assertion pattern for forbidden tokens (via tier1 cache reuse) where the verifier asserts absence in the contract while still containing the literal token in its own assertion code (mirrors P01 verifier discipline -- verifier code is not deliverable text)"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P02/tasks/T01-cross-milestone-data-model-PLAN.md,references/cross-milestone-feature-shape.md,tools/verify/m029-p02-cross-milestone-shape-contract.sh"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-05T23:47:51Z"
---

T01 ships the AD-6 cross-milestone feature data-model design contract for orchestrator:where (FR-13). Per Principle III, the contract is upstream of the T03 render-position.sh implementation: T03 parses feature-spec frontmatter per the schema rule pinned here, T04 builds fixtures using the canonical glyph set pinned here, and T05 chains this verifier as gate 1 of the P02 phase-suite.

Deliverables (both on disk):

- references/cross-milestone-feature-shape.md (240 lines, 7 required H2 sections: Purpose, Frontmatter Schema, Reverse-Lookup Advisory Validation, Inactive Milestone Render Shape, Marker Glyph Set, Cross-References — plus a leading H1). Pins: (a) the AD-6 schema rule (singular milestone: legacy / plural milestones: AD-6 / exactly-one-of / backward-compatibility / no M033 spec migration in M029); (b) the reverse-lookup advisory at render time (enumerate .orchestrator/milestones/M*/M*-EVALUATION.md, group by feature_ref, emit WARN: on mismatch, never hard-error per Principle XI); (c) the #Q-5 inactive-render shape (collapsed by default with progress bar + glyph; --expand-all override expands every milestone full phase tree; active milestone always expanded via scripts/state/find-active-milestone.sh); (d) the canonical glyph alphabet (✓ ▶ ◇ ✗ ▽); (e) the #Q-G8 canonical compact savings form (▽ saved Nk; verbose suffix reserved for future --verbose mode).

- tools/verify/m029-p02-cross-milestone-shape-contract.sh (140 lines, executable, AD-19 straight-line bash, single-script-file shape, no inline compound, no plain subshells, no $() with pipes; pattern after m029-p01-headline-shape-contract.sh). 29 assertions across 10 categories: file existence (1), required headers (7), schema tokens (4), canonical glyphs (5), canonical compact savings form positive assertion (1), forbidden verbose form negative assertion (1), spec references (4), --expand-all flag name (1), WARN: advisory token (1), four named consumer cross-references (4).

Verification (single Must-Have): bash tools/verify/m029-p02-cross-milestone-shape-contract.sh -- 29/29 PASS, exit 0. Final SUMMARY line: 'SUMMARY: m029-p02-cross-milestone-shape-contract.sh pass=29 fail=0'.

CON-7 / AD-8 boundary discipline preserved: T01 introduces NO schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. The two new files (references/*.md + tools/verify/*.sh) are the only artifacts.

Forbidden-token compliance (#Q-G8 + the SC-5 fixtures must-have): the contract document contains neither 'via tier1 cache reuse' nor '4k saved' tokens (rephrased to 'verbose-suffix tokens' and 'magnitude-then-verb' respectively). The verifier contains the literal 'via tier1 cache reuse' string only inside its negative-assertion grep -F call against the contract; this matches the P01 verifier shape precedent (verifier code is not deliverable text — its own code asserts the contract is clean).

Pattern reused / extended for P02: paired Principle-III design contract gate verifier discipline. T01 here mirrors the P01 m029-p01-headline-shape-contract.sh shape exactly (grep -F per assertion, parallel pass/fail counters, single SUMMARY line, exit 0 iff fail=0). Downstream T03/T04/T05 cannot drift from the contract because the verifier asserts every glyph, schema token, header, spec reference, and consumer name.
