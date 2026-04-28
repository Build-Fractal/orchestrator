---
schema_version: "1.0"
type: phase-summary
id: P03
parent: M018
milestone: M018
provides: "Tier 1 microcompact live in scripts/dispatch/build-context.sh:_bc_apply_tier1 — paging of inline tool-result blocks above compression.tier1.inline_threshold_tokens (default 1500); SHA-256(command + 0x1F + input)-keyed cache at .orchestrator/cache/tool-results/<sha256>; cache-reuse short-circuits writes (mtime preserved); preview-line reference (`<tool-result file=\"...\" preview-lines=\"5\" command=\"...\" original-body-tokens=\"...\">`) replaces oversized bodies; additive `tier1_savings_tokens` and `tier1_invocations` integer fields on payload_breakdown JSONL emit (CON-5 — pre-T01 records remain valid JSON, missing fields default to 0 in rollups); `tier_preservation_violation` JSONL record (record_type=tier_preservation_violation, tier=tier1) on post-paging pres_check_section failure (P02 library shared with P04/P06); scripts/util/cache-prune.sh --max-age <N>{d|h|m} mtime-based eviction utility (default 7d, idempotent, safe against missing cache dir); compression.tier1.{enabled,inline_threshold_tokens,preview_lines,cache_dir} config keys in .orchestrator/config.yml + templates/orchestrator-config-default.yml; seven P03-private truth verifiers under scripts/verify/m018-p03-*.sh; tests/fixtures/m018-p03-tool-result/ fixture (dispatch-payload-fixture.md + README.md); scripts/verify/_helpers/m018-p03-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P02 preservation-check library (scripts/lib/preservation-check.sh — pres_check_section + pres_emit_violation); P02 payload_breakdown schema with filter_dropped_tokens additive field; P02 byte-identity golden (tests/fixtures/m018-p02-baseline-payload.golden.txt) for the disable-flag regression contract; P02 _bc_apply_knowledge_filter establishes the awk-driven single-pass pattern Tier 1 mirrors"
affects: "P04 (T2 head-drop sources scripts/lib/preservation-check.sh established by P02 + reuses cache-prune utility for any spillover artifacts; consumes additive `tier1_savings_tokens` field through the rolling underperformance window; MIT-01 4+-backtick-fence regex remains load-bearing for T2 boundary detection); P05 (eval harness reads payload_breakdown.tier1_savings_tokens / .tier1_invocations + tier_preservation_violation records from execution-log.jsonl per the additive-emitter invariants section of the grammar contract); P06 (T3 auto-compact reuses the cache-prune mtime-only utility for tier-3 originals storage; same record-schema invariants — tier_preservation_violation with tier=tier3); P07+ (cache-prune cron / lifecycle wiring inherits the existing single-utility entry point)"
key_files: "scripts/dispatch/build-context.sh;scripts/util/cache-prune.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml;tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md;tests/fixtures/m018-p03-tool-result/README.md;scripts/verify/_helpers/m018-p03-build-fixture.sh;scripts/verify/m018-p03-tier1-paging.sh;scripts/verify/m018-p03-cache-reuse.sh;scripts/verify/m018-p03-emitter-additivity.sh;scripts/verify/m018-p03-cache-prune.sh;scripts/verify/m018-p03-disable-flag-honored.sh;scripts/verify/m018-p03-preservation-self-check.sh;scripts/verify/m018-p03-dual-write-recent.sh"
key_decisions: "Tier 1 awk-driven single-pass paging (AP-009 compliant; mirrors P02 filter shape; single-pipe printf|grep idiom in verifiers, no $(cmd|cmd)); SHA-256(command + 0x1F + input) cache key — full digest, no truncation (collision domain dominated by hash space, not collision probability — keeps cache key small enough that mtime-based prune is correct without reference counting); cache reuse short-circuits writes (`if (getline _t < path) < 0` — open-for-read probe) so mtime is preserved across replays (FR — cache reuse without re-write); preservation self-check restores pre-paging body on failure (cache files written during the failed pass kept on disk for future reuse — they were physically valid bodies, the failure was a delta on the post-paging payload); cache-prune mtime-only (reference-aware preservation deferred — current cache key small enough that mtime is correct; documented as M018 follow-up in cache-prune.sh header); _bc_apply_tier1 inline in build-context.sh (single call site between _bc_emit_payload_breakdown and _bc_emit_compression_underperformance, MEM004 carve-out — no extraction to scripts/lib until a second caller emerges); shim-style verifier (sed/awk-extract _bc_apply_tier1 + source) avoids the brittleness of a full build-context.sh end-to-end probe for paging unit-coverage tests (the end-to-end path is exercised by m018-p03-emitter-additivity.sh + m018-p03-disable-flag-honored.sh)"
patterns_established: "Single-pass awk pagination with cache-write side-effect (T01); shim-style verifier that source-extracts a single bash function via awk range pattern (T03 — usable as P04/P06 verifier pattern when the function under test is too internal to dispatch end-to-end); function-stub pattern for failure-path test coverage (T03 — override pres_check_section to return 1 to exercise the violation/restoration code without depending on regex contents); fixture-staging helper that mirrors P02 helper shape under scripts/verify/_helpers/ (additive — one helper per phase keeps the helper directory legible)"
drill_down_paths: ".orchestrator/milestones/M018/phases/P03/tasks/T01-tier1-paging-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-SUMMARY.md;.orchestrator/milestones/M018/phases/P03/tasks/T03-verifiers-and-summary-SUMMARY.md"
duration: "~5h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier1_savings_tokens additive integer field; payload_breakdown.tier1_invocations additive integer field; tier_preservation_violation record_type (tier=tier1 from this phase; same schema reused by P04 with tier=tier2 and P06 with tier=tier3); cache-prune.sh stdout SUMMARY: pruned=N kept=M total=T bytes_freed=B"
completed_at: "2026-04-28T00:00:00Z"
---

# Phase Summary: M018/P03 — Tier 1 Microcompact

## Closure summary

P03 lands the **second tier** of the M018 compression pipeline: Tier 1
microcompact paging of oversized inline tool-result blocks. After P03
closes, every M018 dispatch (and every other orchestrator dispatch in
this repo) runs through the knowledge-aware filter (P02) **and** the
Tier 1 pager — the orchestrator dogfoods its own caveman compression
pipeline starting now.

P03 also ships the first cache-bearing tier — `.orchestrator/cache/tool-results/`
keyed by the full SHA-256 of `command + 0x1F + input`. Cache reuse
short-circuits writes (mtime preserved across replays); cache eviction
is mtime-only via `scripts/util/cache-prune.sh --max-age <duration>`.
P04/T2 head-drop has no cache. P06/T3 auto-compact reuses this same
cache-prune utility for tier-3 originals storage.

The phase ships:

- **Tier 1 paging** (`_bc_apply_tier1` in `scripts/dispatch/build-context.sh`)
  — single awk pass: scan the captured payload, accumulate
  `<tool-result command="...">…</tool-result>` blocks, hash + write
  the cache, replace oversized bodies (> 1500 tokens by default) with
  `<tool-result file="<path>" preview-lines="5" command="..." original-body-tokens="...">`
  + a 5-line preview. Bodies under threshold pass through verbatim.
  Hooked at `build-context.sh` line ~1723 between
  `_bc_emit_payload_breakdown` and `_bc_emit_compression_underperformance`.
- **SHA-256 cache key** — `command + 0x1F + input`. Full 64-hex digest.
  Cache files re-used across dispatches: an open-for-read probe
  (`(getline _t < path) < 0`) tests presence; on hit, the cache write
  is skipped (mtime preserved).
- **Additive emitter fields** (CON-5) — `tier1_savings_tokens` and
  `tier1_invocations` on `_bc_emit_payload_breakdown`'s printf line.
  Stats are captured to `$TMPDIR_BUILD/_tier1_stats.txt` by the awk
  pass and read back by the emitter; missing stats file defaults
  to 0/0 (passthrough case where no paging fired).
- **Preservation self-check integration** — when Tier 1 modifies the
  capture, `pres_check_section "tier1" <pre> <post> tier1` runs over
  the post-paging body. On failure, the pre-paging file is restored
  to `$capture_file` byte-for-byte and `pres_emit_violation` writes a
  `tier_preservation_violation` JSONL record (record_type=`tier_preservation_violation`,
  tier=`tier1`). Cache files written during the failed pass remain on
  disk — they were physically valid bodies; the failure was a delta on
  the post-paging payload bytes, not on the cache contents.
- **`scripts/util/cache-prune.sh --max-age <N>{d|h|m}`** — single-script
  utility, default 7d. Reads `compression.tier1.cache_dir` from
  `.orchestrator/config.yml`; falls back to `.orchestrator/cache/tool-results/`.
  Single-level glob (sub-directories skipped per Constitution VI —
  future tier-3-originals/ co-tenants stay untouched). BSD-vs-GNU stat
  detection. `--dry-run` prints `WOULD-PRUNE:` lines without removal.
  `SUMMARY: pruned=N kept=M total=T bytes_freed=B` line on stdout.
  Idempotent. Malformed `--max-age` exits 1.
- **Config surface** — `compression.tier1.{enabled, inline_threshold_tokens,
  preview_lines, cache_dir}` keys; defaults true / 1500 / 5 /
  `.orchestrator/cache/tool-results/`. Live in `.orchestrator/config.yml`
  + `templates/orchestrator-config-default.yml`.
- **Disable contracts** —
  `compression.enabled: false` (master toggle, FR-15) short-circuits
  the entire pipeline (filter + Tier 1 — byte-identical to pre-M018
  capture against the P02 golden).
  `compression.tier1.enabled: false` short-circuits only Tier 1; the
  knowledge-aware filter still runs.
  `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env wins over the config
  (test seam, FR-15 SC-8).

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate, P01 conversus deliberation)** — LLM
  preservation trust boundary lives in P06; P03 contributes the
  preservation-check failure-path wiring pattern that P06 will mirror
  with the LLM density-pre-check.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** —
  preservation-contract self-check algorithmic specification is now
  exercised live: `pres_check_section` runs over every Tier 1 paging
  pass, and the failure-path emits `tier_preservation_violation`
  per the grammar contract.
- **CON-5 (additive emitters)** — `tier1_savings_tokens` /
  `tier1_invocations` are additions to the existing payload_breakdown
  schema; pre-T01 records remain valid JSON; rollups treat absent
  fields as 0. Verified by the historical-log diff in
  `m018-p03-emitter-additivity.sh`.

## Followups for downstream phases

- **P04 (tier2 head-drop)** — sources `scripts/lib/preservation-check.sh`
  (same library; tier=`tier2`); the MIT-01 nested-fence regex
  (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop
  boundary detection. T2 has no cache — paging is destructive.
  Reuses `scripts/util/cache-prune.sh` only if any spillover artifacts
  are introduced.
- **P05 (eval harness)** — reads
  `payload_breakdown.tier1_savings_tokens` / `.tier1_invocations`
  from `execution-log.jsonl` for cumulative-savings rollups. Reads
  `tier_preservation_violation` records (tier=`tier1`/`tier2`/`tier3`)
  for trust-boundary diagnostics.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before
  the LLM call per MIT-08; tier-3-savings field additive on
  `payload_breakdown`; tier-3 originals stored under
  `.orchestrator/cache/tier3-originals/` (sibling, not nested).
  `cache-prune.sh` already-skips sub-directories so tier-3 storage
  needs its own prune pass — recommend `--cache-dir` flag rather than
  hard-coding tier1 vs tier3 in the utility.
- **P07+** — cache-prune cron / lifecycle wiring inherits the existing
  single-utility entry point; recipe-level integration with
  `orchestrator:doctor` is the natural follow-up.

## Verification result

All P03 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P03/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all seven private verifiers green:

- `m018-p03-tier1-paging.sh` — PASS (big block paged, small block
  verbatim, SHA-256 cache file written under fixture cache dir).
- `m018-p03-cache-reuse.sh` — PASS (mtime preserved across two paging
  passes against the same fixture payload).
- `m018-p03-emitter-additivity.sh` — PASS (emitter source carries
  additive fields; live emission carries integer-valued tier1_*
  fields; pre-T01 + post-T01 historical records both valid JSON).
- `m018-p03-cache-prune.sh` — PASS (`--max-age 7d` prunes 30d-old
  file, keeps fresh file, idempotent on second invocation, survives
  missing cache dir).
- `m018-p03-disable-flag-honored.sh` — PASS (P02 golden byte-identical
  to fixture; both `compression.enabled=false` and
  `compression.tier1.enabled=false` short-circuit Tier 1 — empty cache
  dir, tier1_invocations=0).
- `m018-p03-preservation-self-check.sh` — PASS (failure-path
  passthrough holds; `tier_preservation_violation` record emitted with
  tier=`tier1`).
- `m018-p03-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P03).

P03 closed. M018 advances to P04 (head-drop tier).
