---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M018"
goal: "Tier 2 snip — head-drop section body bytes that exceed the configured per-section budget while preserving the configured tail ratio byte-identical, refusing the snip on preserved-pattern boundaries, emitting an in-band `<!-- compressed:tier2 ... -->` marker, and surfacing `tier2_savings_tokens` additively on `payload_breakdown`"
demo_sentence: "After P04, a build-context.sh dispatch whose `## Knowledge`, `## Task Plan`, or `## Upstream Context` section body exceeds `compression.tier2.section_budget_tokens` (default 1500) gets head-dropped — the head bytes above the budget are removed, the configured `protected_tail_ratio` (default 0.3) of the original section bytes survives byte-identical, an in-band `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` marker names the snip; if the head-drop boundary lands inside a preserved-pattern row from the cross-tier vocabulary (frontmatter, 4+-backtick code fence, JSONL record, etc.) the snip retreats to the next safe boundary or passes the section through unmodified; `payload_breakdown` carries an additive integer `tier2_savings_tokens` field; `compression.enabled: false` keeps the existing P02 golden payload byte-identical; `compression.tier2.enabled: false` short-circuits only Tier 2"
risk: "medium"
depends_on: ["P03"]
---

## Must-Haves

### Truths

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p04-*.sh. -->

- Tier 2 head-drop fires on section bodies (`## Knowledge`, `## Task Plan`, `## Upstream Context`) whose body-token count exceeds `compression.tier2.section_budget_tokens` (default 1500), removing head bytes above the budget while leaving the trailing `protected_tail_ratio` (default 0.3) byte-identical to the pre-snip section.
  - Check: `bash scripts/verify/m018-p04-tier2-head-drop.sh`
- Tier 2 emits the in-band marker `<!-- compressed:tier2 head_dropped=<N> protected_tail_ratio=<R> -->` immediately after the section heading line of every section it modifies; the marker's kvpair grammar matches the cross-tier `<!-- compressed:tier[0-9]+ [^>]*-->` vocabulary entry verbatim.
  - Check: `bash scripts/verify/m018-p04-tier2-marker.sh`
- Preserved-pattern boundary refusal: if the computed head-drop boundary lands inside a preserved span from the cross-tier vocabulary (frontmatter delimiter, 4+-backtick code fence, JSONL record, command name, MEM ID, scaffold marker, in-band tier marker, URL, repo-relative or absolute path), the snip retreats to the next safe boundary line; if no safe boundary exists above the protected tail, the section passes through unmodified and a `tier_preservation_violation` JSONL record is appended (record_type=`tier_preservation_violation`, tier=`tier2`).
  - Check: `bash scripts/verify/m018-p04-tier2-boundary-refusal.sh`
- `payload_breakdown` JSONL records carry an additive integer `tier2_savings_tokens` field; pre-T2 records remain valid JSON; missing field defaults to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p04-tier2-emitter-additivity.sh`
- `compression.enabled: false` keeps the P02 golden (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) byte-identical against the post-P04 build-context.sh; `compression.tier2.enabled: false` short-circuits only Tier 2 (filter + Tier 1 still run).
  - Check: `bash scripts/verify/m018-p04-tier2-disable-flag.sh`
- Body-level preservation self-check: after head-drop, `pres_check_section "tier2" <pre> <post> tier2` runs over the section bodies; on failure the section is restored byte-identical from the pre-snip capture and a `tier_preservation_violation` JSONL record is emitted via `pres_emit_violation` (tier=`tier2`).
  - Check: `bash scripts/verify/m018-p04-tier2-preservation-self-check.sh`
- CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P04" or "tier2" — phase-close dual-write via `scripts/util/dual-write-runtime-md.sh`.
  - Check: `bash scripts/verify/m018-p04-dual-write-recent.sh`

### Artifacts

- `scripts/dispatch/build-context.sh` (min 1700 lines, contains "tier2")
- `scripts/lib/knowledge-filter.sh` (min 380 lines, contains "tier2.section_budget_tokens")
- `.orchestrator/config.yml` (min 65 lines, contains "tier2:")
- `templates/orchestrator-config-default.yml` (min 40 lines, contains "tier2:")
- `tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md` (min 30 lines, contains "## Knowledge")
- `tests/fixtures/m018-p04-section-overflow/README.md` (min 10 lines, contains "tier2")
- `tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md` (min 30 lines, contains "```")
- `tests/fixtures/m018-p04-boundary-refusal/README.md` (min 10 lines, contains "boundary")
- `scripts/verify/_helpers/m018-p04-build-fixture.sh` (min 30 lines, contains "P04")
- `scripts/verify/m018-p04-tier2-head-drop.sh` (min 30 lines, contains "head_dropped")
- `scripts/verify/m018-p04-tier2-marker.sh` (min 25 lines, contains "compressed:tier2")
- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` (min 30 lines, contains "boundary")
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` (min 30 lines, contains "tier2_savings_tokens")
- `scripts/verify/m018-p04-tier2-disable-flag.sh` (min 30 lines, contains "compression.enabled")
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` (min 30 lines, contains "tier_preservation_violation")
- `scripts/verify/m018-p04-dual-write-recent.sh` (min 20 lines, contains "recent-changes")
- [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../milestones/M018/phases/P04/P04-SUMMARY.md) (min 40 lines, contains "tier2_savings_tokens")

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/lib/preservation-check.sh` (sources the P02 library to invoke `pres_check_section` after Tier 2 head-drop; uses `PRES_PATTERNS_REGEX` for the boundary-refusal preserved-span detector)
- `scripts/dispatch/build-context.sh` → `scripts/lib/knowledge-filter.sh` (reads `compression.tier2.*` config via new `kf_get_tier2_*` accessors that mirror the existing `kf_get_tier1_*` shape)
- `references/compression-grammar.md` → `scripts/dispatch/build-context.sh` (T2 implementation — applies-to: `payload-section-body` for Knowledge / Task Plan / Upstream Context; preserves cross-tier vocabulary plus the trailing `protected_tail_ratio`; failure semantics emit `tier_preservation_violation` with tier=`tier2`; spec at `## Tier: tier2`, lines 191–211)
- `CLAUDE.md` → `M018/P04` (recent-changes block names the phase)
- `AGENTS.md` → `M018/P04` (recent-changes block names the phase, written via `scripts/util/dual-write-runtime-md.sh`)

## Tasks

### T01: Tier 2 head-drop function + boundary-refusal logic in build-context.sh + config keys + additive emitter field

(Plan in `tasks/T01-tier2-head-drop-PLAN.md`.)

### T02: Verifiers, fixtures, fixture-staging helper, P04-SUMMARY + dual-write

(Plan in `tasks/T02-verifiers-and-summary-PLAN.md`.)

## Task Dependencies

```
T01 → T02   (T02 verifiers exercise T01's production code; T01 must land first)
```

(Two-task decomposition: T2 is a single feature in a single function; the head-drop logic and the boundary-refusal detector live together because the detector is the inner loop of the head-drop. Splitting them produces a stub interface with no second consumer — MEM004 carve-out applies. Cache-prune integration is NOT wired here per phase scope; T2 has no cache.)

## Files Likely Touched

- `scripts/dispatch/build-context.sh` (modify) — add `compression.tier2.*` config reads, the `_bc_apply_tier2` head-drop function (placed adjacent to `_bc_apply_tier1` per the existing dispatch-internal helper convention), the call-site wiring (between `_bc_apply_tier1` and `_bc_emit_payload_breakdown`), and the additive `tier2_savings_tokens` field on `_bc_emit_payload_breakdown`'s printf line.
- `scripts/lib/knowledge-filter.sh` (modify) — add `kf_get_tier2_enabled`, `kf_get_tier2_section_budget_tokens`, `kf_get_tier2_protected_tail_ratio` accessors mirroring the existing `kf_get_tier1_*` shape; reuse `kf_read_compression_scalar`.
- `.orchestrator/config.yml` (modify) — append `compression.tier2.{enabled,section_budget_tokens,protected_tail_ratio}` block under the existing `compression:` map.
- `templates/orchestrator-config-default.yml` (modify) — same `compression.tier2.*` block so freshly-installed projects inherit the defaults.
- `tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md` (create) — fixture payload with a Knowledge section large enough to exceed the default budget but with no preserved-pattern boundary inside the head-drop range.
- `tests/fixtures/m018-p04-section-overflow/README.md` (create) — fixture description.
- `tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md` (create) — fixture payload with an over-budget Upstream Context section whose head-drop boundary lands inside a 4+-backtick code fence (MIT-01 case) plus a frontmatter delimiter case.
- `tests/fixtures/m018-p04-boundary-refusal/README.md` (create) — fixture description.
- `scripts/verify/_helpers/m018-p04-build-fixture.sh` (create) — fixture-staging helper mirroring `scripts/verify/_helpers/m018-p03-build-fixture.sh`.
- `scripts/verify/m018-p04-tier2-head-drop.sh` (create)
- `scripts/verify/m018-p04-tier2-marker.sh` (create)
- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` (create)
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` (create)
- `scripts/verify/m018-p04-tier2-disable-flag.sh` (create)
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` (create)
- `scripts/verify/m018-p04-dual-write-recent.sh` (create)
- [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../milestones/M018/phases/P04/P04-SUMMARY.md) (create)
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P04.
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`).
