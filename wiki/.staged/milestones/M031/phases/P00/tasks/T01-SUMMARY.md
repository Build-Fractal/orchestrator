---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P00"
milestone: "M031"
provides:
  - "spec-body fold-in (AD-1..AD-20), SC-15 + SC-16 added, SC-2/SC-3/SC-11/SC-13 rewritten, SC-14 raised to N >= 15, p00-spec-foldin-shape.sh verifier"
requires:
  - "from:M031-CONTEXT.md what:AD-1..AD-20 prose; from:M031-ROADMAP.md what:pinned phase IDs P00..P04"
affects:
  - "P00/T02 (CORPUS-MANIFEST shape consumes SC-15 vocabulary), P00/T03 (harness consumes SC-11 stored-records language and SC-13 ordering verifier)"
key_files:
  - "specs/034-right-sized-entry/spec.md,tools/verify/p00-spec-foldin-shape.sh"
key_decisions:
  - "AD-12 Option B preferred for SC-13 (git-history check); AD-13 ±20% literal removed globally including audit-trail; AD-18 SC-15 added; AD-20 SC-16 added"
patterns_established:
  - "post-roadmap spec fold-in (defer ratified ADs into spec body until phase IDs pinned); inverted-polarity grep verifier with explicit comment guarding the inversion against future maintainer 'fixes'"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P00/tasks/T01-spec-foldin-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-01T16:21:10Z"
---

Folded all 20 architectural decisions (AD-1..AD-20) from M031-CONTEXT.md into specs/034-right-sized-entry/spec.md as a new ## Architectural Decisions (folded post-discuss 2026-05-01) section between ## Constitution Check and ## Open Questions. Each AD entry preserves CONTEXT.md prose verbatim with inline provenance citation (originated in [.orchestrator/milestones/M031/M031-CONTEXT.md](../../../../../milestones/M031/M031-CONTEXT.md) AD-N). Rewrote SC-2 (AD-13: drop tolerance-band clause, ground in [M018](../../../../../milestones/M018/index.md) tier-2 snip), SC-3 (AD-17: prescriptive fixture exceeds M018 tier-1 inline_threshold_tokens), SC-11 (AD-14: explicit stored pre-M031 records at fixtures/empirical-baseline/pre-m031-baseline.jsonl), SC-13 (AD-12: git-history Option B with Option A fallback recorded in SC13-OPTION.md). Added SC-15 (AD-18: median absolute budget compliance) and SC-16 (AD-20: Tier A+ prompt UX integration test). Updated SC-14 from N >= 13 to N >= 15 with Option A parenthetical (N >= 14). Authored tools/verify/p00-spec-foldin-shape.sh (127 lines, bash 3.2 compatible, single-script-file shape per AD-19) with 7 checks: file exists, AD section header present, all 20 AD sub-headers present, SC-15 list-item present, SC-16 list-item present, SC-14 declares N >= 15 (or 14), and inverted-polarity check that ±20% literal is GONE from the entire spec body. Verifier emits SUMMARY: p00-spec-foldin-shape.sh pass=7 fail=0 on green; ran clean from repo root. Hygiene: removed ±20% literal from gate-findings audit-trail section (paraphrased as 'plus-or-minus 20 percent tolerance') so the verifier's inverted check passes; original Open Questions and Gate Findings sections otherwise preserved verbatim. Spec grew 267 -> 408 lines.
