---
schema_version: "1.0"
type: task-summary
id: "T05-jaccard-validation"
parent: "P01"
milestone: "M020"
provides:
  - "enriched scripts/knowledge/lib/jaccard.sh validate subcommand (computes pair-count distribution buckets, top-10 pairs table, threshold recommendation derived from observed top-similarity, CON-5 feature-vector sanity-check stats; writes the canonical jaccard-validation-report.md with the four T05-required H2 sections); .orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md fully enriched against the live tree (31 entries, 465 pairs, top sim 0.2000); scripts/verify/m020-p01-jaccard-validation-report.sh (validates the report contract: required tokens, required H2 sections, no placeholder strings, numeric threshold recommendation, PASS verdict line); scripts/verify/m020-p01-migration-incremental.sh (asserts P01 did not bulk-migrate -- counts entries with status: field against a 5%-of-total floor-of-2 limit, with a soft milestone-log cross-check capping recognized task closes)"
requires:
  - "from:M020/P01/T03 what:graduate.sh + status: flip semantics; from:M020/P01/T04 what:jaccard.sh pairwise_jaccard primitive + validate-subcommand scaffold; from:M020/P01/T01 what:CON-5 feature-vector definition (cited in report) + MEM031 schema authority context"
affects:
  - "P05 cluster-integration consumes the recommended threshold (0.15 transitional, A-5 0.7 pending vector extension) + the pair-count distribution as baseline; P05 also consumes the feature-vector verdict (extend with relates_to[] / source_unit / full body capped at 200 tokens)"
key_files:
  - "scripts/knowledge/lib/jaccard.sh;scripts/verify/m020-p01-jaccard-validation-report.sh;scripts/verify/m020-p01-migration-incremental.sh;.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md"
key_decisions:
  - "none-new"
patterns_established:
  - "adaptive-threshold-recommendation (validate computes top observed similarity then branches: >=0.7 retain default, 0.3-0.7 lower-moderate at top*0.75, <0.3 lower-aggressive with vector-extension recommendation); status-count-as-bulk-migration-proxy (counting ^status: lines across live entries with a small percentage tolerance is a robust contract proxy that survives unrelated frontmatter churn -- avoids brittle git-diff-against-baseline logic when the baseline state is itself dirty from prior sessions); pre-cache pairwise tokens in tempdir indexed by entry index to avoid O(n^2) re-extraction during validate (was O(n^2) extract+sort calls, now O(n) extract+sort + O(n^2) comm); validate-subcommand owning the persistent enriched report (rather than enrich-once + protect against clobber) means the report is reproducible from source data on every run -- T05 narrative collapses into derived data + observation-conditioned text"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P01/tasks/T05-jaccard-validation-PLAN.md;/tmp/T05-PAYLOAD.md;.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-25T05:19:16Z"
---

T05 closes P01. Three deliverables on disk plus the live-tree validation report.

1. Enriched validate subcommand (scripts/knowledge/lib/jaccard.sh): replaced T04's stub-emitting validate with a full enriched-report generator. The new implementation pre-caches per-entry sorted token sets to a tempdir (keyed by entry index) so the inner pair loop reuses them via comm -12 / cat | sort -u rather than re-extracting tokens O(n^2) times. Computes pair-count distribution buckets (>=0.9, 0.7-0.9, 0.5-0.7, 0.3-0.5, <0.3), captures all pairs sorted for the top-10 table, counts zero-intersection pairs, and tracks min/max/avg dedup tokens per entry. Recommendation logic is data-driven: top observed similarity drives the recommendation strategy (retain at >=0.7, lower-moderate at top*0.75 in 0.3-0.7 range, lower-aggressive at max(0.10, top*0.75) below 0.3 with explicit vector-extension callout). Verdict text branches on the same boundaries.

2. Live-tree report (.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md): regenerated fully enriched against 31 entries / 465 pairs. All 465 pairs fall below 0.5 against the live tree -- top observed similarity is 0.2000 (MEM029 vs MEM030, both M026/conversus-OSS, a real cluster). 166/465 (35.7%) of pairs have zero token-set intersection, indicating the CON-5 vector is too narrow for the current tree size. Recommendation: lower-aggressive to 0.15 as a transitional value, AND extend the vector in M020/P05 to include relates_to[] edges, source_unit, and full body capped at 200 tokens. The roadmap's "may adjust 0.7 default" clause is exercised here.

3. scripts/verify/m020-p01-jaccard-validation-report.sh: validates the report exists at the canonical path and contains: load-bearing tokens (0.7, CON-5, "feature vector", "Demo-sentence verification"); required H2 section headers (## Pair-count distribution, ## Threshold Recommendation, ## Feature-Vector Sanity Check, ## Demo-sentence verification); no remaining placeholder strings (TBD, <X>, <N>); a numeric threshold value in the recommendation line; the "Demo sentence: PASS." verdict line.

4. scripts/verify/m020-p01-migration-incremental.sh: enforces FR-10 + NG-3 (no bulk migration of pre-M020 entries). Mechanism: counts ^status: lines across live knowledge/*/MEM*.md (archive excluded). Limit is 5% of total entries, floor-of-2, so the demo flips P01 testing might leak into the live tree (CON-1 says they should not) stay tolerated while a real bulk migration -- which would write status: to all 31 entries -- fails loudly. Includes a soft milestone-log cross-check capping recognized P01 task closes at 7. Tolerates the existing 30 pre-T05 hit_count auto-update modifications because those do not introduce status: fields.

Verification (all PASS, exit 0):
- bash scripts/verify/m020-p01-jaccard-validation-report.sh -> PASS: jaccard validation report contract honored
- bash scripts/verify/m020-p01-migration-incremental.sh -> PASS: migration is incremental -- 0 of 31 entries bear status: (within 2 limit)
- bash scripts/verify/m020-p01-graduate-single-entry.sh -> PASS: graduate.sh single-entry flip honors contract (4/4 cases)
- bash scripts/verify/m020-p01-jaccard-pairwise-contract.sh (regression) -> PASS: pairwise_jaccard contract honored (4/4 cases)
- bash scripts/verify/m020-p01-frontmatter-helper-contract.sh (regression) -> PASS: frontmatter helper contract honored (7/7 cases)
- bash scripts/verify/m020-p01-graduate-side-effect-scope.sh (regression) -> PASS: graduate.sh side-effect scope bounded to target entry

CON-1 honored: T05 wrote only under .orchestrator/milestones/M020/phases/P01/ and scripts/. Zero knowledge/ mutations from T05 (verified: 0/31 live entries bear status:; the 30 pre-existing M files in git status knowledge/ are unrelated hit_count auto-updates from prior sessions). Demo path runs end-to-end against the live tree.

Deviations from PAYLOAD draft: (1) the payload showed a one-shot enrichment workflow (validate writes stub, T05 hand-edits the report); I instead promoted the enrichment into the validate subcommand itself so the demo path is reproducible on every run without clobber risk. (2) the migration-incremental verifier in the payload sketched a grep -l listfiles approach without explicitly excluding the archive subdirectory; I tightened both the count and the find total to exclude */archive/* so archived entries (which can legitimately bear status: archived) do not skew either side of the comparison. (3) added a floor-of-2 to the 5% limit so the small-tree case (where 5% rounds to 1) tolerates a single demo flip without false-positive. (4) added a soft milestone-log cross-check capping recognized task closes at 7 -- defensive, not load-bearing.

Demo sentence verification (per wakeup instructions): graduate.sh + jaccard.sh validate path exercised end-to-end by m020-p01-graduate-single-entry.sh (uses tempdir fixture, never touches knowledge/) and the validate-subcommand re-run during T05 development. Both PASS. The phase-defending sentence holds.
