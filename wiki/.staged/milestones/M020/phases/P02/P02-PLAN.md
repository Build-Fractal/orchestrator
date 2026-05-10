---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M020"
goal: "Ship the FR-2 deterministic query surface (`scripts/knowledge/query.sh`) plus its one-line dispatch-interface wrapper, with side-effect-free invariant enforced and US-1 acceptance scenarios green."
demo_sentence: "Running `bash scripts/knowledge/query.sh --topic <X>` against a fixture knowledge tree returns `entry_id=<ID>` lines for graduated entries matching `<X>` (case-insensitive whole-string `topic:` field equality OR case-folded `tags[]` membership), in rank order (topic-field hits first, then tag hits, ties broken by `last_verified` descending), with `--format json` emitting a single `{\"matches\":[...]}` document parseable by `jq`, and zero writes to `knowledge/**` per `git status knowledge/`."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / lessons in continue.md, Truth Check commands MUST
     use single-invocation script-file shape. No inline compound bash, no
     plain subshells, no $() containing pipes, no process substitution. -->

- `scripts/knowledge/query.sh` exists, is executable, and its `--help` enumerates `--topic`, `--state`, `--format` flags.
  - Check: `bash scripts/verify/m020-p02-query-help.sh`
- `query.sh --topic <X>` returns ONLY entries whose `status:` is `graduated` (default state filter) when `--state` is not supplied (FR-2 sub-clause d).
  - Check: `bash scripts/verify/m020-p02-query-default-state-filter.sh`
- `query.sh --topic <X>` matches entries whose frontmatter `topic:` field equals `<X>` case-insensitively OR whose `tags[]` list contains `<X>` case-folded (FR-2 sub-clauses a, b, c).
  - Check: `bash scripts/verify/m020-p02-query-match-rule.sh`
- `query.sh --topic <X>` ranks `topic:`-field exact matches above tag-only matches; ties broken by `last_verified` descending (FR-2 sub-clause e).
  - Check: `bash scripts/verify/m020-p02-query-ranking.sh`
- `query.sh --topic <X> --format ids` emits one `entry_id=<ID>` line per match in rank order; default `--format` is `ids` (FR-2 sub-clause f).
  - Check: `bash scripts/verify/m020-p02-query-format-ids.sh`
- `query.sh --topic <X> --format json` emits a single JSON document with a `matches` array of `{id, title, status, rank}` records, parseable by `jq` (FR-2 sub-clause f).
  - Check: `bash scripts/verify/m020-p02-query-format-json.sh`
- `query.sh` performs zero writes to `knowledge/**` (FR-8, CON-1, SC-7).
  - Check: `bash scripts/verify/m020-p02-query-side-effect-free.sh`
- `query.sh` returns an empty structured result (not an error) when no entries match (US-1 acceptance scenario 3).
  - Check: `bash scripts/verify/m020-p02-query-no-match-empty.sh`
- `scripts/dispatch/dispatch-interface.sh` exposes a `--query` passthrough that delegates to `scripts/knowledge/query.sh` with byte-equivalent stdout (OQ-4).
  - Check: `bash scripts/verify/m020-p02-dispatch-query-wrapper.sh`
- `tests/test-knowledge-query.sh` exists, is executable, and exits 0 — covering SC-1 (graduated-only return + ranking + JSON shape) and SC-7 (clean `git status` post-invocation).
  - Check: `bash tests/test-knowledge-query.sh`

### Artifacts

- `scripts/knowledge/query.sh` (min 120 lines, contains "topic")
- `scripts/dispatch/dispatch-interface.sh` (min 100 lines, contains "query")
- `tests/test-knowledge-query.sh` (min 80 lines, contains "SC-1")
- `scripts/verify/m020-p02-query-help.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m020-p02-query-default-state-filter.sh` (min 30 lines, contains "graduated")
- `scripts/verify/m020-p02-query-match-rule.sh` (min 40 lines, contains "tags")
- `scripts/verify/m020-p02-query-ranking.sh` (min 40 lines, contains "rank")
- `scripts/verify/m020-p02-query-format-ids.sh` (min 30 lines, contains "entry_id=")
- `scripts/verify/m020-p02-query-format-json.sh` (min 30 lines, contains "matches")
- `scripts/verify/m020-p02-query-side-effect-free.sh` (min 30 lines, contains "git status")
- `scripts/verify/m020-p02-query-no-match-empty.sh` (min 25 lines, contains "no-matches")
- `scripts/verify/m020-p02-dispatch-query-wrapper.sh` (min 30 lines, contains "dispatch-interface")

### Key Links

- `scripts/knowledge/query.sh` → `scripts/knowledge/lib/frontmatter.sh` (query.sh sources fm helper for `fm_read_status`; comment in header names the file)
- `scripts/dispatch/dispatch-interface.sh` → `scripts/knowledge/query.sh` (wrapper delegates to query.sh; comment in dispatch-interface.sh names the script)
- `tests/test-knowledge-query.sh` → `scripts/knowledge/query.sh` (test invokes the script under test; references the path verbatim)

## Tasks

### T01: Query surface core (`query.sh` matching + ranking + `--format ids`)

See `tasks/T01-query-core-PLAN.md`.

### T02: Query surface JSON output + no-match diagnostic + side-effect-free invariant

See `tasks/T02-query-json-side-effect-PLAN.md`.

### T03: Dispatch-interface query wrapper passthrough (OQ-4)

See `tasks/T03-dispatch-wrapper-PLAN.md`.

### T04: Integration test suite (`tests/test-knowledge-query.sh` covering SC-1 + SC-7)

See `tasks/T04-integration-test-PLAN.md`.

## Task Dependencies

```
T01 ──→ T02 ──→ T03 ──→ T04
```

- **T01** ships the core `query.sh` with `--topic`, `--state`, default-state-filter, match rule, ranking, and `--format ids`.
- **T02** extends `query.sh` in place with `--format json`, the no-match empty result diagnostic, and the side-effect-free invariant verifier.
- **T03** wires the `--query` passthrough into `scripts/dispatch/dispatch-interface.sh` once the query surface is contract-stable.
- **T04** lands the cross-cutting integration test (`tests/test-knowledge-query.sh`) covering SC-1 + SC-7 end-to-end through the dispatch wrapper.

Linear chain — each task strictly depends on the previous one's stdout contract being stable. Parallelism not exploited because every task touches `query.sh` or its consumers.

## Verification Commands

<!-- Cross-task invariants and phase-level rollups. Per-task verifiers
     live under each task's own ## Verification block; the commands here
     are the phase-completion gate that runs after T04 ships. Per the
     P01 retrospective lesson: NEVER reference verifier scripts created
     by future tasks from inside a task's own verification block. -->

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P02
bash scripts/verify/m020-p02-query-help.sh
bash scripts/verify/m020-p02-query-default-state-filter.sh
bash scripts/verify/m020-p02-query-match-rule.sh
bash scripts/verify/m020-p02-query-ranking.sh
bash scripts/verify/m020-p02-query-format-ids.sh
bash scripts/verify/m020-p02-query-format-json.sh
bash scripts/verify/m020-p02-query-side-effect-free.sh
bash scripts/verify/m020-p02-query-no-match-empty.sh
bash scripts/verify/m020-p02-dispatch-query-wrapper.sh
bash tests/test-knowledge-query.sh
```

All eleven commands must exit 0. The first is the rollup; the next nine are per-truth Tier-1 verifiers; the last is the integration test (SC-1 + SC-7).

## Files Likely Touched

- `scripts/knowledge/query.sh` (create)
- `scripts/dispatch/dispatch-interface.sh` (modify — add `--query` passthrough; preserve all other adapter semantics byte-equivalent per CON-4)
- `tests/test-knowledge-query.sh` (create)
- `scripts/verify/m020-p02-query-help.sh` (create)
- `scripts/verify/m020-p02-query-default-state-filter.sh` (create)
- `scripts/verify/m020-p02-query-match-rule.sh` (create)
- `scripts/verify/m020-p02-query-ranking.sh` (create)
- `scripts/verify/m020-p02-query-format-ids.sh` (create)
- `scripts/verify/m020-p02-query-format-json.sh` (create)
- `scripts/verify/m020-p02-query-side-effect-free.sh` (create)
- `scripts/verify/m020-p02-query-no-match-empty.sh` (create)
- `scripts/verify/m020-p02-dispatch-query-wrapper.sh` (create)

No files under `knowledge/**` are touched; no files under `.orchestrator/memory/` or [`.orchestrator/DECISIONS.md`](../../../../decisions.md) are touched (no schema evolution in P02 — schema authority work landed in P01 per D024). FR-8 + CON-1 + SC-7 demand `git status knowledge/` clean post-invocation; verifier `m020-p02-query-side-effect-free.sh` enforces this directly.
