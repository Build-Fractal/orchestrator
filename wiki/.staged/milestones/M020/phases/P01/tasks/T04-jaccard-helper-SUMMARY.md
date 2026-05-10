---
schema_version: "1.0"
type: task-summary
id: "T04-jaccard-helper"
parent: "P01"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/jaccard.sh exposing pairwise_jaccard subcommand (CON-5 feature vector, similarity=N.NNNN structured output) plus validate subcommand stub (writes report header + iteration loop output to .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md, T05 enriches recommendation); contract verifier scripts/verify/m020-p01-jaccard-pairwise-contract.sh covering 4 cases (identical=1.0000, disjoint<0.3, partial in (0.3,1.0), missing-file rejected)"
requires:
  - "from:M020/P01/T01 what:CON-5 feature-vector definition + MEM031 schema authority cited in report header (informational only, T04 does not consume status: field)"
affects:
  - "P05 clustering integration consumes pairwise_jaccard primitive; T05 enriches the validate report with threshold-recommendation analysis and demo-sentence output"
key_files:
  - "scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-pairwise-contract.sh;.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md"
key_decisions:
  - "none"
patterns_established:
  - "bash 3.2 pure-function pairwise primitive: tokenize -> sort -u -> comm -12 for intersection / cat+sort -u for union / awk for floating-point division (no bc dependency); first-paragraph awk extraction must defer blank-line termination until at least one content line printed (otherwise the conventional blank-line gap between H1 and body is misread as paragraph end); validate-subcommand scaffolding pattern (header + iteration loop ships in T-N, threshold/recommendation analysis lands in T-N+1)"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P01/tasks/T04-jaccard-helper-PLAN.md;/tmp/T04-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-25T05:07:37Z"
---

Shipped scripts/knowledge/lib/jaccard.sh per CON-5 feature vector (title + topic + tags + first-paragraph words capped at 50 tokens via head -50). pairwise_jaccard reads two file paths, extracts tokens (case-folded, punctuation-stripped via tr -c, deduplicated via sort -u), computes intersection (comm -12) and union (cat | sort -u | wc -l), and emits similarity=N.NNNN to stdout (awk for division, MEM003 structured output prefix). validate subcommand walks knowledge_root/*/MEM*.md pairs (i<j double loop, bash 3.2 c-style for) and writes the canonical report at [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) with the configuration header + above-0.5 similarity list + a Threshold Recommendation stub for T05 to fill in. CON-1 read-only honored: pairwise reads only; validate writes only under .orchestrator/milestones/M020/phases/P01/. Contract verifier scripts/verify/m020-p01-jaccard-pairwise-contract.sh PASS 4/4 cases. Deviations from PAYLOAD draft: (1) the awk first-paragraph extractor in the PAYLOAD example exits on the first blank line after the H1, but the conventional blank-line separator between the H1 and the body terminates the paragraph before any body content is read -- fixed by deferring the blank-line exit until at least one content line has printed (probe-confirmed against synthetic fixture before fix), (2) zero-union sentinel returns similarity=0.0000 (4-decimal) instead of 0.0 for stable byte-formatting symmetry with the awk printf, (3) report embedded H2 headings (Configuration, Pairwise Similarities, Threshold Recommendation) demoted to H3 per task constraint about embedded H2 parser collisions, (4) files=( knowledge_root/*/MEM*.md ) glob expansion replaced with explicit for-loop append because empty-glob behavior differs across shells and bash 3.2 nullglob is not on by default. No knowledge MEM mutations from T04.
