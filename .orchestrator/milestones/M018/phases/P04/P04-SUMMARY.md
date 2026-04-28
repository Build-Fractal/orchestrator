---
schema_version: "1.0"
type: phase-summary
id: P04
parent: M018
milestone: M018
provides: "Tier 2 snip live in scripts/dispatch/build-context.sh:_bc_apply_tier2 — head-drop of in-scope section bodies (Knowledge, Task Plan, Upstream Context) above compression.tier2.section_budget_tokens (default 1500), preserving compression.tier2.protected_tail_ratio (default 0.3) of pre-snip section bytes byte-identical at the tail; in-band marker `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` named immediately after the section heading; line-aligned cut with boundary-refusal walker that retreats above multi-line preserved spans (frontmatter `^---$` pairs and `^\\`{3,}[a-zA-Z0-9_-]*$` code-fence pairs by tick-count, MIT-01-aware); pass-through on no-safe-boundary plus a `tier_preservation_violation` JSONL record (tier=tier2, pattern=spanning cross-tier label); preservation self-check via pres_check_section ... tier2 (strict multiplicity); additive integer `tier2_savings_tokens` field on payload_breakdown JSONL emit (CON-5); compression.tier2.{enabled, section_budget_tokens, protected_tail_ratio} config keys in .orchestrator/config.yml + templates/orchestrator-config-default.yml; three new kf_get_tier2_* accessors in scripts/lib/knowledge-filter.sh; seven P04-private truth verifiers under scripts/verify/m018-p04-*.sh; two fixture trees under tests/fixtures/m018-p04-{section-overflow, boundary-refusal}/; scripts/verify/_helpers/m018-p04-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh."
requires: "P03 _bc_apply_tier1 wiring shape (build-context.sh call-site adjacency); P02 preservation-check library (pres_check_section + pres_emit_violation + PRES_PATTERNS_REGEX cross-tier vocabulary including the MIT-01 4+-backtick code-fence regex which is load-bearing for boundary detection); P02 byte-identity golden (tests/fixtures/m018-p02-baseline-payload.golden.txt) for the disable-flag regression contract; P01 references/compression-grammar.md `## Tier: tier2` rules."
affects: "P05 (eval harness reads payload_breakdown.tier2_savings_tokens and tier_preservation_violation records with tier=tier2 from execution-log.jsonl per the additive-emitter invariants section of the grammar contract; P05 cohort segmentation reads tier1_savings_tokens + tier2_savings_tokens + filter_dropped_tokens together for cumulative-savings rollups); P06 (T3 auto-compact runs AGAINST the tier2 output — sees head-dropped-plus-protected-tail bytes, not pre-snip bytes; tier3 must NOT mutate the tier2 in-band marker per the grammar contract; tier3 wraps the marker if the section is summarized further); M027/M019 cost surfaces consume tier2_savings_tokens via the existing payload_breakdown read path; doctor anomaly check baselines compression-regression vs historical post-T2 records."
key_files: "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml;tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md;tests/fixtures/m018-p04-section-overflow/README.md;tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md;tests/fixtures/m018-p04-boundary-refusal/README.md;scripts/verify/_helpers/m018-p04-build-fixture.sh;scripts/verify/m018-p04-tier2-head-drop.sh;scripts/verify/m018-p04-tier2-marker.sh;scripts/verify/m018-p04-tier2-boundary-refusal.sh;scripts/verify/m018-p04-tier2-emitter-additivity.sh;scripts/verify/m018-p04-tier2-disable-flag.sh;scripts/verify/m018-p04-tier2-preservation-self-check.sh;scripts/verify/m018-p04-dual-write-recent.sh"
key_decisions: "Boundary-refusal walker retreats DOWN from the naive cut line toward line 1 looking for the first line whose at-line-start unsafe flag is 0 (the line that OPENS a span is itself safe — cutting above the opener is correct because everything from the opener onward falls into the protected tail); 4+-backtick fence tracking by tick-count not by line count (3-backtick lines do not close 4-backtick fences — MIT-01); no-safe-boundary refusal passes the section through verbatim plus a tier_preservation_violation JSONL emit (NOT a tier2_preservation_breach — that record is reserved for the protected-tail breach path which the boundary-refusal detector makes unreachable; the grammar contract separates the two record types intentionally); strict-multiplicity tier2 self-check shape (mirrors the tier1 strict-multiplicity branch in pres_check_section); _bc_apply_tier2 inline in build-context.sh (single call site between _bc_apply_tier1 and the cat/emit cluster, MEM004 carve-out — no extraction to scripts/lib until a second caller emerges); tier2 has NO cache (head-drop is destructive on the in-flight payload; canonical files on disk are untouched per Constitution Principle VI; cache-prune utility is reusable but not wired in this phase); fixture-staging helper mirrors P03 shape one-helper-per-phase under scripts/verify/_helpers/; verifiers stub pres_check_section in shim scope to isolate the awk-pass head-drop coverage from the cross-tier vocabulary self-check (the failure-path coverage lives in m018-p04-tier2-preservation-self-check.sh which inverts the stub to return 1)."
patterns_established: "Awk single-pass section-aware head-drop with at-line-start unsafe-flag recording (T01 — usable shape for P05/P06 if their tiers ever need per-line span awareness); function-stub pattern reused from P03/T03 (override pres_check_section to return 0 for happy-path coverage, return 1 for failure-path coverage — same shape, opposite sentinel); dual-fixture pattern (one fixture exercising the happy-path with no preserved-pattern boundaries, one exercising the boundary-refusal walker via MIT-01 4+-backtick fence — reusable for any tier whose safety boundary is the load-bearing claim); fixture-staging helper accepts a slug argument (section-overflow vs boundary-refusal) so a single helper feeds multiple verifiers."
drill_down_paths: ".orchestrator/milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md;.orchestrator/milestones/M018/phases/P04/tasks/T02-verifiers-and-summary-SUMMARY.md"
duration: "~4h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_breakdown.tier2_savings_tokens additive integer field; tier_preservation_violation record_type (tier=tier2 from this phase; same schema as tier1 from P03 and tier3 from P06); P05 eval harness consumes tier1_savings_tokens + tier2_savings_tokens + filter_dropped_tokens fields together; doctor anomaly-check baselines compression-regression vs historical post-T2 records."
completed_at: "2026-04-28T00:00:00Z"
---

# Phase Summary: M018/P04 — Tier 2 Snip

## Closure summary

P04 lands the **third tier** of the M018 compression pipeline: Tier 2
section head-drop with protected tail. After P04 closes, every M018
dispatch (and every other orchestrator dispatch in this repo) runs
through the knowledge-aware filter (P02), the Tier 1 pager (P03), AND
the Tier 2 snip — the orchestrator dogfoods the full caveman
compression pipeline starting now.

P04 is the **first tier with destructive in-payload mutation** (head-drop
removes head bytes from the in-flight payload). Per Constitution VI,
the canonical files on disk are untouched: only the assembled dispatch
payload is mutated. T2 has no cache (head-drop is in-flight; cache-prune
utility is reusable but not wired here).

The phase ships:

- **Tier 2 head-drop** (`_bc_apply_tier2` in `scripts/dispatch/build-context.sh`)
  — single awk pass: stream the captured payload, buffer each in-scope
  section's body (`## Knowledge`, `## Task Plan`, `## Upstream Context`),
  track multi-line preserved spans line-by-line so each buffered line
  carries an at-line-start `body_unsafe[i]` flag. At section close, if
  body-tokens > `compression.tier2.section_budget_tokens` (default
  1500), compute naive cut at `floor(body_chars * (1 - protected_tail_ratio))`,
  retreat DOWN from the naive cut line toward line 1 until the walker
  finds a line with `body_unsafe[i] = 0` (the opener of a span is
  itself safe — cuts BELOW the opener fall inside the span and are
  unsafe), then emit `## <Section>\n<!-- compressed:tier2 ... -->\n<tail>`.
  Hooked at `build-context.sh` line ~2023 between `_bc_apply_tier1` and
  the cat/emit cluster.
- **MIT-01 nested-fence regex** — the awk pass tracks fences by
  TICK COUNT, not by line. A 4-backtick fence opens at tick-count 4;
  3-backtick lines inside it do NOT close it. Only a matching-tick-count
  closer ends the fence. This is the load-bearing MIT-01 fix, exercised
  live by the `m018-p04-tier2-boundary-refusal.sh` verifier against the
  `tests/fixtures/m018-p04-boundary-refusal/` fixture.
- **In-band tier2 marker** — `<!-- compressed:tier2 head_dropped=<N>
  protected_tail_ratio=<R> -->` emitted on its own line directly after
  the `## <Section>` heading. Marker matches the cross-tier
  `<!-- compressed:tier[0-9]+ [^>]*-->` vocabulary entry verbatim;
  downstream Tier 3 (P06) wraps but MUST NOT mutate the kvpairs.
- **Boundary-refusal passthrough** — when no safe boundary exists at
  or above the naive cut byte (the section is dominated by an
  unsplittable preserved span), the section passes through unmodified
  AND the awk pass appends a record to `$TMPDIR_BUILD/_tier2_violations.txt`
  which the bash caller reads and dispatches via `pres_emit_violation`
  with `tier=tier2`, `pattern=<spanning vocabulary label>`. Distinct
  from `tier2_preservation_breach`, which the grammar reserves for the
  protected-tail breach path that the boundary-refusal walker makes
  unreachable.
- **Preservation self-check** — `pres_check_section "tier2" $pre_file
  $out_file tier2` runs over the rewritten payload after head-drop
  succeeds. On failure, the pre-snip payload is restored byte-identical
  via `cp "$pre_file" "$capture_file"` and `pres_emit_violation` writes
  `tier_preservation_violation` (tier=`tier2`). The verifier
  `m018-p04-tier2-preservation-self-check.sh` exercises this path via
  the function-stub pattern (override `pres_check_section` to return 1).
- **Additive emitter field** (CON-5) — `tier2_savings_tokens` on
  `_bc_emit_payload_breakdown`'s printf line. Stats captured to
  `$TMPDIR_BUILD/_tier2_stats.txt` by the awk pass and read back by
  the emitter; missing stats file defaults to 0 (passthrough case where
  no head-drop fired, including all sections under budget).
- **Config surface** — `compression.tier2.{enabled,
  section_budget_tokens, protected_tail_ratio}` keys; defaults true /
  1500 / 0.3. Live in `.orchestrator/config.yml` +
  `templates/orchestrator-config-default.yml`. Three new
  `kf_get_tier2_*` accessors in `scripts/lib/knowledge-filter.sh`
  mirror the `kf_get_tier1_*` shape and reuse `kf_read_compression_scalar`.
- **Disable contracts** —
  `compression.enabled: false` (master toggle, FR-15) short-circuits
  the entire pipeline (filter + Tier 1 + Tier 2 — byte-identical to
  pre-M018 capture against the P02 golden).
  `compression.tier2.enabled: false` short-circuits only Tier 2; the
  knowledge-aware filter and Tier 1 pager still run.
  `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env wins over the config.

## Risk-mitigation traceability

- **MIT-01 (P01 conversus deliberation, 4+-backtick fence regex)** —
  the boundary-refusal walker tracks fences by tick count, not by
  line count. A 3-backtick line nested inside a 4-backtick fence is
  fence content, not a closer. The `m018-p04-tier2-boundary-refusal.sh`
  verifier exercises this live — its fixture wraps a 3-backtick
  "nested" fence inside a 4-backtick outer fence and asserts the
  inner 3-backtick line survives unaltered through the snip.
- **MIT-08 (P02 entry gate, P01 conversus deliberation)** — LLM
  preservation trust boundary lives in P06; P04 contributes the
  body-level head-drop pattern that P06 will mirror with the LLM
  density pre-check + summary call.
- **MIT-10 (P02, THREAT-09)** — preservation-contract self-check
  algorithmic specification continues to be exercised live through
  Tier 2: `pres_check_section "tier2"` runs after every successful
  head-drop, and the failure-path emits `tier_preservation_violation`
  per the grammar contract.
- **CON-5 (additive emitters)** — `tier2_savings_tokens` is an
  addition to the existing payload_breakdown schema. Pre-T2 records
  remain valid JSON; rollups treat absent fields as 0. Verified by
  the historical-log diff in `m018-p04-tier2-emitter-additivity.sh`.

## Followups for downstream phases

- **P05 (eval harness)** — reads `payload_breakdown.tier2_savings_tokens`
  alongside `tier1_savings_tokens` + `filter_dropped_tokens` from
  `execution-log.jsonl` for cumulative-savings cohort segmentation.
  Reads `tier_preservation_violation` records (tier=`tier1`/`tier2`/
  `tier3`) for trust-boundary diagnostics. P05 cohort segmentation
  is now able to see the third tier's contribution and report
  outcome-rate deltas at the per-tier level.
- **P06 (tier3 auto-compact)** — sees post-tier-2 bytes (head-dropped
  + protected tail), not pre-snip bytes. Tier3 wraps but does NOT
  mutate the in-band tier2 marker per grammar. `pres_density_pre_check`
  runs in front of the LLM call per MIT-08; `tier3_savings_tokens`
  field is additive on `payload_breakdown`; tier-3 originals stored
  under `.orchestrator/cache/tier3-originals/` (sibling to
  `.orchestrator/cache/tool-results/`, not nested).
- **P07+** — doctor anomaly check baselines compression-regression
  vs historical post-T2 records; cost surfaces (M027/M019) consume
  `tier2_savings_tokens` via the existing payload_breakdown read
  path with no surface changes required.

## Verification result

All P04 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all seven private verifiers green:

- `m018-p04-tier2-head-drop.sh` — PASS (heading preserved; tier2
  marker emitted with positive head_dropped; protected tail bytes
  intact at end of section).
- `m018-p04-tier2-marker.sh` — PASS (single tier2 marker line;
  immediately after `## Knowledge` heading; matches cross-tier
  compression-marker regex; carries integer head_dropped + literal
  protected_tail_ratio=0.30).
- `m018-p04-tier2-boundary-refusal.sh` — PASS (retreat path; walker
  retreated above 4-backtick fence opener; head_dropped reflects
  only pre-fence prose; fence opener+closer preserved; MIT-01 nested
  3-backtick line intact through the snip).
- `m018-p04-tier2-emitter-additivity.sh` — PASS (emitter source
  carries additive `tier2_savings_tokens` field; live emission
  carries integer-valued field; pre-T2 + post-T2 historical records
  both valid JSON; pre-existing tier1 + filter fields still present).
- `m018-p04-tier2-disable-flag.sh` — PASS (P02 golden byte-identical
  to fixture; `tier2.enabled=false` leaves no tier2 marker and
  reports `tier2_savings_tokens=0`; `compression.enabled=false`
  short-circuits the entire pipeline — no compression markers of
  any tier in output).
- `m018-p04-tier2-preservation-self-check.sh` — PASS (failure-path
  passthrough holds; `tier_preservation_violation` record emitted
  with tier=`tier2`).
- `m018-p04-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P04).

P04 closed. M018 advances to P05 (eval harness).
