---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M028"
provides:
  - "P01-VERIFICATION.md collapse-decision evidence document at .orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md (per-screenshot causal trace for SE-01 through SE-09, explicit collapse_decision frontmatter field, corpus staging list consumed by P03); shape verifier scripts/verify/m028/p01-collapse-decision-recorded.sh (AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, asserts frontmatter and section headings and Resolved-by-Finding-A-alone YES/NO discipline)"
requires:
  - "from:P01/T01 what:.orchestrator/milestones/M028/phases/P01/classifier-audit.md (verbatim source events SE-01..SE-09 with classifier verdicts); from:P01/T02 what:tests/fixtures/m028-pre-repair-snapshot.json (path-only reference in Cited Inputs section); from:disk what:specs/031-autonomous-hardening-v3/spec.md and .orchestrator/milestones/M028/M028-CONTEXT.md (Architectural Decisions option-a replanning hook authority for the Replanning trigger note)"
affects:
  - "P02 (collapse decision is full-5-phase so P02 ships hook portability + adapter+installer dedup as roadmapped, no replanning); P03 (consumes the 5-entry corpus staging list verbatim and pads to FR-13 target of 7 with one M021-regression and one AP-014 boundary entry); P04 (Findings D and E remediation lands here per the per-screenshot trace -- cleanup-stale-results.sh and grep-files.sh wrappers); P05 (cross-project verifier suite scope confirmed)"
key_files:
  - ".orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md;scripts/verify/m028/p01-collapse-decision-recorded.sh"
key_decisions:
  - "collapse_decision=full-5-phase based on M=0 of N=7 (threshold 6 not met); SE-01 contributes to A but is NOT resolved-by-A-alone because its in-family commands SE-02..SE-05 all yield existing verdict allow (hook portability alone does not eliminate the in-the-wild failures); SE-09 attributed to G not A despite running on the orchestrator repo itself because the in-tree event proves hook portability is irrelevant to the body-descent bypass surface; corpus staging count is 5 (one per reserved AP-ID) with the FR-13 reconciliation to 7 explicitly delegated to P03 per the rubric in the task plan"
patterns_established:
  - "rubric-driven attribution (verdict + shape + path-prefix triggers map mechanically to Findings A through G; reproducible from classifier-audit.md alone); shape-only verifier discipline (the verifier asserts frontmatter and section headings and per-line YES/NO tokens, never the M/N arithmetic values themselves -- the document body shows the math); corpus-staging delegation pattern (T03 lands the AP-anchored entries derivable from per-screenshot evidence, P03 owns regression and boundary-case padding to the FR-13 target)"
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md;.orchestrator/milestones/M028/phases/P01/classifier-audit.md;scripts/verify/m028/p01-collapse-decision-recorded.sh"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-29T14:15:56Z"
---

Closed P01 by interpreting T01's classifier-replay audit and recording the collapse-decision recommendation. Per-screenshot causal trace covers SE-01 (Finding A family-observation, NO), SE-02..SE-05 (Finding B classifier under-match for AP-010 through AP-013, all NO), SE-06 (Finding E investigation-pattern wrapper -- AP-009 already rejects so this is a wrapper-class need not classifier-class, NO), SE-07 (Finding D destructive-op wrapper, NO), SE-08 (Finding F adapter+installer issue, excluded from Bash-classification denominator), SE-09 (Finding G xargs sh -c body-descent observed in-tree on orchestrator repo, NO). Bash-classification denominator N = 7 (excludes SE-08); resolved-by-Finding-A-alone count M = 0; threshold M >= N-1 = 6 not met. Decision is full-5-phase. P02 ships hook portability + adapter+installer dedup as roadmapped (Findings A + F sibling-folded per CON-1 negotiable in M028-CONTEXT), P03 ships AP-010 through AP-014 classifier extension consuming the 5-entry corpus staging list, P04 ships investigation-pattern + destructive-op wrappers, P05 ships cross-project verifier suite. Replanning trigger does not fire; planner stays in executing on this branch. Verifier asserts shape only -- it does not assert M or N values, leaving the arithmetic to the document body which is the operator-reading surface. Headline reproducibility property: another reader running the rubric in T03-collapse-decision-evidence-PLAN.md step 2 against classifier-audit.md must reach the same M=0 arithmetic and the same full-5-phase recommendation.
