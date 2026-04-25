---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M014"
provides:
  - "scripts/comments/fetch.sh (FR-8 fetcher: Giscus + GitHub Issue/PR via gh stubs, JSONL line-by-line parser, --dry-run FR-19 manifest, --yes inheritance, unit_close JSONL emission); tests/fixtures/m014-p03/sample-inbox.jsonl (4 mixed-surface comments — one per FR-9 class — reusable by T02+); scripts/verify/m014-p03-fetch.sh (8-check verifier covering hermetic stub fetch, idempotency skip, dry-run no-write); CON-8 idempotency contract via grep -F on actioned.jsonl URLs; ORCHESTRATOR_PROJECT_ROOT + GH_API_STUB + GH_GRAPHQL_STUB env-var hermetic-test convention"
requires:
  - "from:disk what:scripts/integrations/github-common.sh (M013 marker convention reference, not modified); from:disk what:scripts/wiki/wiki-giscus-remap.sh (M012 mapping reference, not modified); from:plan what:T01 step 1-7 verbatim skeleton + verifier shape"
affects:
  - "T02 (consumes sample-inbox.jsonl as classifier corpus + inbox/<comment-id>.json record shape); T03 (apply.sh + reject.sh append to actioned.jsonl using the schema seeded by Case B); T04 (pipeline-suite consumer); T05 (phase-suite incorporates m014-p03-fetch.sh)"
key_files:
  - "scripts/comments/fetch.sh,scripts/verify/m014-p03-fetch.sh,tests/fixtures/m014-p03/sample-inbox.jsonl"
key_decisions:
  - "JSONL stub fixtures filtered per-surface inside _process_record so a single shared fixture pointed at by both GH_API_STUB and GH_GRAPHQL_STUB yields each record exactly once (plan implicit); plan step 7 expected pass=8 but plan step 6 enumerates only 7 checks — closed the gap by adding inbox-record-shape check (body_shasum field presence) which also locks down the FR-8 record contract for T02; sed-based json field extractor (no jq dependency) per MEM001; surface filter is only applied when source_surface is present so production gh JSON without that field still flows through"
patterns_established:
  - "hermetic-test stub via env-var pointing at JSONL fixture (GH_API_STUB / GH_GRAPHQL_STUB) — operator gh path untouched, verifier never invokes real gh; per-surface source_surface filter on shared stub fixture preventing double-count when one fixture feeds both surfaces; FR-19 dry-run JSONL action records as the no-disk-write counterpart to actual cache writes, same iteration loop, single conditional branch — pattern reusable by T03 apply/reject; grep -F literal-string match on URL inside actioned.jsonl for safe dedup against URLs containing regex metacharacters"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T01-fetch-PAYLOAD.md,scripts/comments/fetch.sh,scripts/verify/m014-p03-fetch.sh,tests/fixtures/m014-p03/sample-inbox.jsonl"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-25T01:00:50Z"
---

T01 ships the comment fetcher (FR-8) — the cache primer that every later P03 task consumes. Behavior:

1. **Surface enumeration**: `_fetch_github` and `_fetch_giscus` each read JSONL records from either a stub file (GH_API_STUB / GH_GRAPHQL_STUB env var, hermetic) or a live `gh api` invocation. Stubs share a single fixture and filter by source_surface so each record lands on exactly one surface.
2. **Idempotency key**: URL is canonical, body shasum is fallback. Skip check via `grep -F` literal-match against `.orchestrator/comments/actioned.jsonl`.
3. **Cache write**: each new comment becomes `<inbox>/<comment-id>.json` with fields url, body, source_surface, fetched_at, body_shasum — flat single-line JSON written via printf with minimal escaping (no jq dependency).
4. **Dry-run**: identical iteration, but emits FR-19 `cache-comment` action records to stdout instead of writing to disk.
5. **Telemetry**: `unit_close` JSONL appended to `.orchestrator/execution-log.jsonl` on real (non-dry) runs with comments_fetched, comments_skipped, source_surfaces, elapsed_ms, source=runtime.

**Verifier** (`scripts/verify/m014-p03-fetch.sh`) — 8 checks across 3 cases:
- Case A: stub fetch yields fetched=4, 4 inbox files, unit_close emitted, inbox records carry body_shasum.
- Case B: pre-seeded actioned.jsonl row -> fetched=3 skipped=1.
- Case C: --dry-run emits FR-19 manifest, zero inbox writes.

**Bash 3.2 compliance**: no declare -A, no mapfile, no lowercase-expansion, no ampersand-redirect, no process substitution. Anti-pattern lint (Class A + B) clean on both fetch.sh and verifier.

**D007 reuse honored**: scripts/dispatch/adapters/tool/conversus.sh untouched. Conversus integration belongs to T02 (ambiguous classification routing).

**Upstream contracts T02 will need**:
- inbox JSON shape: url, body, source_surface, fetched_at, body_shasum (read by classifier).
- Fixture: `tests/fixtures/m014-p03/sample-inbox.jsonl` is the canonical 4-class corpus (uat-bug, decision-append, spec-amendment, ambiguous).
- Idempotency: classifier should NOT pre-write to actioned.jsonl; that is apply.sh / reject.sh's responsibility (T03).
- Hermetic env vars (GH_API_STUB, GH_GRAPHQL_STUB) usable by T02 verifier if it needs to exercise the fetch->classify pipeline.
