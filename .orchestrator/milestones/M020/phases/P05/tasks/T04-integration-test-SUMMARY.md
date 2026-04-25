---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M020"
provides:
  - "tests/test-jaccard-clustering.sh — SC-4 end-to-end integration test exercising the P05 clustering loop through consolidate-artifacts.sh --cluster across three scenarios: (1) ten-entry fixture (4 near-duplicates + 6 vocabulary-disjoint singletons) at threshold 0.1 yielding 7 cluster IDs covering 10 members exactly once with all IDs matching AD-3 C<8-hex>; (2) conflict-diagnostic surface on mixed decision_history fixtures emitting `conflict: cluster=<id> reason=divergent-decision-history` plus JSONL conflict_flag=1; (3) round-trip cluster ID handoff to graduate.sh --cluster <id> with canonical=>graduated, siblings=>archived back-references, and JSONL knowledge_graduate + N-1 knowledge_archive records. 16 PASS / 0 FAIL. Bash 3.2 + MEM002 pass()/fail() conventions. Tempdir + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation per CON-1 / FR-8 — live knowledge/** and .orchestrator/execution-log.jsonl never touched."
requires:
  - "from:P05/T01,T02,T03 what:cluster.sh+jaccard.sh-v2+consolidate-artifacts.sh--cluster; from:P03/T01,T02 what:decision-history.sh+graduate.sh--cluster"
affects:
  - "P06"
key_files:
  - "tests/test-jaccard-clustering.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "Distinct-vocabulary fixture pattern — when a clustering integration test relies on "should-be-singletons", boilerplate words ("distinct", "fixture", "body", "unique", "for") must be removed from per-entry bodies; otherwise v2 feature-vector token overlap on common scaffolding pushes pairwise similarity above the threshold and the entries co-cluster spuriously. Each singleton entry must use a wholly disjoint word list (zero token intersection with siblings) for the test to satisfy the SC-4 7-cluster contract. Documented for downstream verifier authors. Test-internal heredocs + pipes + process-substitutions remain AD-19 safe because the harness shape-guard inspects directly-invoked Bash tool-call shapes, not script internals (P03/T04 carry-forward)."
drill_down_paths:
  - "tests/test-jaccard-clustering.sh"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-25T15:27:17Z"
---

## Summary

Created `tests/test-jaccard-clustering.sh` — a 16-assertion SC-4 end-to-end integration test exercising the P05 Jaccard-clustering extension of `consolidate-artifacts.sh` across three scenarios.

## Scenarios + assertions

### Scenario 1 (SC-4 ten-entry fixture)
6 PASS — invocation rc=0, 10 member lines, 7 cluster IDs (in-band 6..8), no duplicate members, all IDs match AD-3 `C<8-hex>` shape, JSONL count matches cluster count (7 records).

### Scenario 2 (conflict diagnostic)
3 PASS — invocation rc=0, `conflict: cluster=<id> reason=divergent-decision-history` line emitted, JSONL `conflict_flag=1` recorded.

### Scenario 3 (round-trip cluster ID -> graduate.sh)
7 PASS — consolidate rc=0, cluster_id extracted, 3 members enumerated, `graduate.sh --cluster <cid> --rationale <text> <ids...>` rc=0, canonical -> `graduated`, siblings -> `archived` with `archived_into=<canon>`, JSONL `knowledge_graduate` + N-1 `knowledge_archive` records present.

Total: **16 PASS / 0 FAIL**, summary line `PASS: SC-4 end-to-end clustering + conflict + round-trip handoff to graduate.sh`.

## Deviation from payload

The payload-supplied fixture for the 6 "distinct" singleton entries used shared boilerplate words (`distinct`, `fixture`, `body`, `unique`, `for`, `another`) which under the v2 feature vector (title + topic + tags + relates_to + source_unit + body cap-200 tokens) produces pairwise Jaccard similarity 0.4667 between every pair of "distinct" entries — well above the 0.1 threshold. The result was 2 cluster IDs (one for the 4 near-duplicates, one merging all 6 "distinct" entries), failing the must-have `6..8` band.

Fix: replaced the 6 distinct-entry bodies with wholly disjoint word lists (e.g. `aardvark bumblebee carrot ...`, `igloo jackal kerosene ...`) and stripped the `distinct fixture` + `unique body` scaffolding. Each entry now shares zero body tokens with siblings; pairwise similarity drops below threshold and each becomes a singleton. Test now produces exactly 7 cluster IDs (= SC-4 spec).

The test logic, assertion count, helpers, and fixture-isolation strategy remain byte-identical to the payload spec — only the per-entry body content was tightened to satisfy the v2 vector contract.

## Verification

- `bash tests/test-jaccard-clustering.sh` -> `Test summary: 16 pass / 0 fail`, exit 0.
- `git status .orchestrator/execution-log.jsonl` -> clean (test redirects via `ORCH_ROOT` env override).
- `git status knowledge/` -> pre-existing hit_count churn only (P03 carry-forward lesson 9: hit_count churn is structurally pre-existing from prior index rebuilds; the test itself never touches `knowledge/**` because of the `PROJECT_ROOT` env override on tempdirs).

## Patterns established

- **Distinct-vocabulary fixture pattern** — clustering integration tests relying on "should-be-singletons" must use entries whose body tokens are fully disjoint. v2 vector token overlap on common scaffolding words is sufficient to push pairwise similarity above a 0.1 threshold even when topics, tags, and relates_to are entirely distinct. Future clustering verifiers should use generated nonsense-word lists per entry, not English boilerplate.
- **Test-internal compound shapes are AD-19 safe** — the test file itself uses heredocs, pipes, command substitutions, and process redirections internally. AD-19 / AP-009 govern only directly-invoked Bash tool-call shapes; the shape-guard does not inspect script internals (per P03/T04 carry-forward).
- **Tempdir + PROJECT_ROOT + ORCH_ROOT triple-isolation** — same pattern P03/T04 used for `test-graduate-workflow.sh`, generalised here for both `consolidate-artifacts.sh` and `graduate.sh` invocations sharing one ORCH_ROOT under `mktemp -d`.
- **count_event helper** — wraps `grep -c "\"event\":\"$event\"" file` with `|| true` and empty-to-zero default per P03 carry-forward lesson 8 (the `grep -c` rc-1 + prints-`0` doubling pitfall).

## Files touched

- `tests/test-jaccard-clustering.sh` (created, 295 lines, executable).
- No files under `knowledge/**`, `.orchestrator/memory/**`, or `.orchestrator/DECISIONS.md` modified.
- No files under `scripts/**` modified.

## Done when

`bash tests/test-jaccard-clustering.sh` prints `PASS: SC-4 end-to-end clustering + conflict + round-trip handoff to graduate.sh` and exits 0; `git status knowledge/` shows only pre-existing hit_count churn; `git status .orchestrator/execution-log.jsonl` is clean. **All criteria met.**
