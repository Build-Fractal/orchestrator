---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M030"
goal: "Wire live-routing + flip-gate enforcement + verifier-fail escalation into scripts/dispatch/dispatch-interface.sh on top of the P02 shadow path and P03 override-resolution path. Live mode (model_routing.live: true in .orchestrator/config.yml) causes dispatch-interface.sh to (a) programmatically invoke bash scripts/diagnostics/shadow-compare.sh per D-A2, (b) refuse to call any backend adapter when the verdict is evidence_insufficient or block, recording override_source=shadow_gate_blocked in JSONL (SC-2a), (c) when verdict is ready, pass --model <resolved-id> through to the adapter so model_used is the routing-table-resolved tier-id (SC-3), (d) when verdict is partially_ready, route live only for classes whose default tier is smart (D-A3) and emit partial_flip_active=true + withheld_classes=<list> on records for under-threshold classes. Verifier-fail escalation (FR-10) re-dispatches at the next-higher symbolic tier (fast→balanced→smart) on adapter-rc nonzero, capped at 2 escalations per CON-5 — three records max per task, then one escalation_cap_hit record and the task surfaces as a normal verifier failure. Each escalation produces a NEW JSONL record with new timestamp; prior records are bit-identical (CON-6). The kill switch (CON-4 / D-A5) supersedes live routing — model_routing_enabled: false short-circuits the live branch and the flip-gate before any adapter call (SC-7a-style compound). All routed model IDs flow through templates/model-routing.yml (CON-3). All new JSONL fields (escalation_count, escalation_reason, plus the new escalation_cap_hit record_type) are additive — pre-M030 fixtures continue to round-trip byte-identically through shadow-off (SC-11)."
demo_sentence: "An operator dispatches four fixture plans. (a) With model_routing.live: true and a shadow corpus passing the flip-readiness check (tests/fixtures/m030-p04/shadow-corpus-ready.jsonl), dispatching plan-mechanical-no-override.md results in jq -r '.model_used' returning the routing-table resolution.fast.claude-code value. (b) With model_routing.live: true and shadow corpus = 0 records, dispatch-interface.sh refuses to call the backend adapter, exits nonzero, and the appended JSONL line carries jq -r '.override_source' = shadow_gate_blocked. (c) Dispatching plan-fail-twice-then-pass.md against the fail-counter stub adapter (counter starts at 2) produces three dispatch_usage records with jq -r '.model_used' values forming the routing-table sequence (fast → balanced → smart); the third record carries jq -r '.escalation_count' = 2. (d) Dispatching plan-fail-three-times.md against the same stub adapter (counter starts at 3) produces exactly three dispatch_usage records (jq -s 'length' returns 3, no fourth) plus one escalation_cap_hit record with jq -r '.final_count' = 2. Compound CON-4 case: with model_routing.live: true AND model_routing_enabled: false, dispatch records jq -r '.override_source' = disabled and never invokes the flip-gate. tools/verify/p04-phase-suite.sh emits SUMMARY: p04-phase-suite.sh pass=N fail=0 with N>=10 and exits 0."
risk: "high"
depends_on: ["P02", "P03"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p04-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2. T01 ships fixtures
     + the stub-fail-n adapter + tolerant pre-amendment gates BEFORE T02
     amends dispatch-interface.sh. T02 ships the live-routing branch +
     flip-gate enforcement + partial-flip routing + co-authored
     verifiers (SC-2a, SC-3, partial-flip, CON-3 live-closure, CON-4
     live-killswitch, SC-11 pass-through). T03 ships the escalation
     loop + CON-5 hard-cap + CON-6 prior-records-bit-identical
     verifier. T04 closes with the phase-suite aggregator. Strict
     linear chain T01→T02→T03→T04. -->

### Truths

- `scripts/dispatch/dispatch-interface.sh` short-circuits before invoking any backend adapter when `.orchestrator/config.yml` declares `model_routing:` with `live: true` AND `bash scripts/diagnostics/shadow-compare.sh --corpus <empty>` returns `flip_recommendation=evidence_insufficient`. The dispatch-interface invocation exits nonzero and the appended JSONL line records `override_source=shadow_gate_blocked`. The verifier stages a config with `live: true`, an empty execution log (zero shadow records), and asserts (i) dispatch-interface exit code is nonzero, (ii) the appended JSONL `override_source` field equals `shadow_gate_blocked`, (iii) NO record_type=dispatch_result line was written by the stub adapter (the adapter was never invoked). (FR-9 / SC-2a / D-A2.)
  - Check: `bash tools/verify/p04-sc2a-shadow-gate-block.sh`

- SC-3 holds: with `model_routing.live: true` AND a shadow corpus passing the flip-readiness check (`bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-ready.jsonl` → `flip_recommendation=ready`), dispatching `plan-mechanical-no-override.md` against `stub-record-model.sh` produces a JSONL `dispatch_usage` record where `jq -r '.model_used'` equals the value of `templates/model-routing.yml resolution.fast.claude-code` (extracted at verifier runtime via the same awk section-walker dispatch-interface uses — no hardcoded model-ID literal). The stub-record-model adapter echoes the `--model <id>` flag the dispatch-interface passes; the verifier asserts the adapter received and recorded the flag value. (FR-9 / SC-3 / CON-3.)
  - Check: `bash tools/verify/p04-sc3-live-mechanical.sh`

- SC-4 holds: with `model_routing.live: true` AND a `ready`-verdict shadow corpus AND the `stub-fail-n.sh` adapter (counter starts at 2 — fail twice then pass), dispatching `plan-fail-twice-then-pass.md` (mechanical-classified) produces exactly three `dispatch_usage` records in the appended JSONL trail. The `model_used` field of the three records forms the routing-table sequence `<resolution.fast.claude-code> <resolution.balanced.claude-code> <resolution.smart.claude-code>` (verified via per-record `jq -r '.model_used'` against runtime-extracted tier values). The third record carries `escalation_count=2` and `escalation_reason=verifier_fail`. The dispatch-interface invocation exits 0 (third attempt passes). (FR-10 / SC-4.)
  - Check: `bash tools/verify/p04-sc4-escalation-sequence.sh`

- SC-5 holds: with `model_routing.live: true` AND a `ready`-verdict shadow corpus AND the `stub-fail-n.sh` adapter (counter starts at 3 — fail every attempt), dispatching `plan-fail-three-times.md` (mechanical-classified) produces exactly three `dispatch_usage` records (NOT four) plus exactly one `escalation_cap_hit` record. The `escalation_cap_hit` record has `record_type=escalation_cap_hit`, `final_count=2`, and the same `unitId` as the dispatch_usage trail. The dispatch-interface invocation exits nonzero (final attempt failed). The verifier independently asserts `jq -s '[.[] | select(.record_type=="dispatch_usage")] | length'` returns 3, NOT 4. (FR-10 / SC-5 / CON-5.)
  - Check: `bash tools/verify/p04-sc5-escalation-cap.sh`

- CON-5 hard-cap (no-fourth-record) gate: the verifier engineers an explicit fail-four-times scenario (`stub-fail-n.sh` counter = 4) and asserts that the JSONL trail still contains exactly three `dispatch_usage` records and one `escalation_cap_hit`. The fourth adapter invocation MUST never happen — verified by counting how many times `stub-fail-n.sh` was invoked via a side-channel counter file written by the stub. The counter file's final value is asserted to be 3. (CON-5.)
  - Check: `bash tools/verify/p04-con5-no-fourth-record.sh`

- CON-6 prior-records-bit-identical gate: the verifier captures SHA-256 hashes of the first two `dispatch_usage` records BEFORE escalation runs the third attempt (using a multi-stage round-trip where the verifier inspects the log mid-escalation via a sentinel file the stub-fail-n drops on each invocation), then re-hashes the same lines AFTER all three records are written, and asserts the hashes are unchanged. Equivalent simpler shape: capture the file's first-two-lines bytes via `head -n 2`, hash, then capture the file's first-two-lines bytes after the full sequence completes, hash, assert equal. The escalation logic MUST append new records with new timestamps; rewriting any prior record is forbidden. (CON-6.)
  - Check: `bash tools/verify/p04-con6-prior-records-bit-identical.sh`

- The live-routing branch in `dispatch-interface.sh` introduces zero new hardcoded model IDs. The amendment never embeds a literal `claude-haiku-*`, `claude-sonnet-*`, `claude-opus-*`, `gpt-*`, `o1-*`, `o3-*`, or `gemini-*` string. Every model ID passed via `--model <id>` to the backend adapter flows through the `templates/model-routing.yml resolution.<tier>.claude-code` awk-extraction path. The escalation logic recomputes the next tier symbolically (`fast` → `balanced` → `smart`) and re-extracts the resolution. The verifier compares the post-amendment `dispatch-interface.sh` against `git show HEAD:scripts/dispatch/dispatch-interface.sh` and asserts the per-pattern provider-ID grep count is unchanged. Same shape as `p03-con3-closure.sh`. (CON-3 / D-A2.)
  - Check: `bash tools/verify/p04-con3-live-closure.sh`

- CON-4 / SC-7a-style compound (kill-switch wins in live mode): with `.orchestrator/config.yml` declaring BOTH `model_routing_enabled: false` AND `model_routing.live: true`, dispatching ANY plan results in `jq -r '.override_source'` = `disabled` (NOT `shadow_gate_blocked`, NOT `none`, NOT a tier-routed value) AND the `model_used` field matches the runtime default channel (the `model:` field from `intensity-metadata.txt`) AND `bash scripts/diagnostics/shadow-compare.sh` is NEVER invoked (verified via a `MOCK_SHADOW_COMPARE_INVOKED_TOUCH=` file the verifier stages — if shadow-compare ran, the file would be touched; it remains absent). The kill switch short-circuits BEFORE the live branch's flip-gate logic. Stderr contains the one-line bypass warning naming `live: true is inactive` (in addition to or in place of the `min_tier:` warning when both are set). (CON-4 / D-A5 / SC-7a.)
  - Check: `bash tools/verify/p04-con4-live-killswitch.sh`

- Partial-flip routing (D-A3): with `model_routing.live: true` AND a `partially_ready`-verdict shadow corpus (`tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl` whose verdict enumerates a withheld class), dispatching a task in the WITHHELD class produces a JSONL record with `model_used` matching the runtime default channel (NOT the routing-table-resolved tier ID), `partial_flip_active=true`, and `withheld_classes` containing the class name. Dispatching a task in a FLIPPED class produces a record with `model_used` matching the routing-table-resolved tier ID (live-routed), `partial_flip_active=true`, and `withheld_classes` listing the under-threshold class. (D-A3 / FR-9.)
  - Check: `bash tools/verify/p04-partial-flip-routing.sh`

- The `override_source` enum gains a sixth value `shadow_gate_blocked` (which P03 reserved per the closed-enum spec). All shadow-on `dispatch_usage` records emit exactly one `override_source` field whose value is one of `{plan_frontmatter, milestone_floor, disabled, shadow_gate_blocked, none}`. P03 already documented the value in `references/model-routing.md ## Operator Overrides`; T02 ships the emission path. The verifier extends the P03 enum gate with a new scenario F (live-mode + 0-record corpus → `shadow_gate_blocked`). (FR-9 / FR-19.)
  - Check: `bash tools/verify/p04-override-source-enum-extended.sh`

- New JSONL field `escalation_count` (integer, 0..2) appears on every shadow-on `dispatch_usage` record post-T03. New JSONL field `escalation_reason` (string, empty on initial dispatch, `verifier_fail` on escalated dispatches) appears alongside `escalation_count`. New record type `escalation_cap_hit` is emitted exactly once per task that exhausts the escalation cap, with fields `record_type=escalation_cap_hit`, `unitId=<id>`, `final_count=2`, `timestamp=<iso8601>`. The verifier exercises three scenarios (no-failure, fail-twice-then-pass, fail-three-times) and asserts each record's `escalation_count`/`escalation_reason` values match the expected sequence. (FR-10 / FR-19 / CON-5.)
  - Check: `bash tools/verify/p04-escalation-fields-enum.sh`

- SC-11 byte-equality re-confirmed against P02's pre-M030 fixture: with shadow mode off (`CLAUDECODE` unset OR `M030_SHADOW_MODE` unset), the `dispatch-interface.sh` emit path produces output byte-identical to `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`'s first record under round-trip via the existing P02 stage. The verifier delegates to `tools/verify/p02-additive-schema.sh` (P02 deliverable, still on disk) — re-running it under HEAD must continue to pass after T02 + T03's amendments land. The P04 verifier is a thin wrapper that invokes the P02 gate and asserts exit 0. Live-mode amendments touch ONLY shadow-on branches; shadow-off byte-equality is preserved. (CON-2 / FR-19 / SC-11.)
  - Check: `bash tools/verify/p04-additive-schema.sh`

- `bash tools/verify/p04-phase-suite.sh` invokes all eleven P04 sub-gates (additive-schema, override-source-enum-extended, sc2a-shadow-gate-block, sc3-live-mechanical, sc4-escalation-sequence, sc5-escalation-cap, con5-no-fourth-record, con6-prior-records-bit-identical, con3-live-closure, con4-live-killswitch, partial-flip-routing) plus the escalation-fields-enum gate (twelve total) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p04-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p02-phase-suite.sh` and `p03-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p04-phase-suite.sh`

### Artifacts

- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (min 25 lines, contains "## Steps", contains "T99") — create
- tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md (min 25 lines, contains "## Steps", contains "T97") — create
- tests/fixtures/m030-p04/plans/plan-fail-three-times.md (min 25 lines, contains "## Steps", contains "T96") — create
- tests/fixtures/m030-p04/plans/plan-fail-four-times.md (min 25 lines, contains "## Steps", contains "T96") — create
- tests/fixtures/m030-p04/plans/plan-novel-class.md (min 25 lines, contains "## Steps", contains "explore", contains "T95") — create
- tests/fixtures/m030-p04/configs/config-with-live-true.yml (min 8 lines, contains "model_routing", contains "live", contains "true") — create
- tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml (min 10 lines, contains "model_routing_enabled", contains "false", contains "live", contains "true") — create
- tests/fixtures/m030-p04/configs/config-with-live-false.yml (min 6 lines, contains "model_routing", contains "live", contains "false") — create
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl (min 150 lines, contains "model_routed", contains "classifier_confidence", contains "high") — create
- tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl (min 100 lines, contains "model_routed", contains "smart") — create
- tests/fixtures/m030-p04/shadow-corpus-empty.jsonl (min 0 lines, max 1 lines) — create
- tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt (min 2 lines, contains "model:", contains "claude-opus") — create
- tests/fixtures/m030-p04/round-trip-stage/payload.txt (min 1 lines) — create
- scripts/dispatch/adapters/backend/stub-fail-n.sh (min 60 lines, contains "STUB_FAIL_COUNTER_FILE", contains "exit 1", contains "dispatch-result") — create
- scripts/dispatch/adapters/backend/stub-record-model.sh (min 50 lines, contains "STUB_RECORD_MODEL_FILE", contains "--model", contains "dispatch-result") — create
- tools/verify/p04-additive-schema.sh (min 20 lines, contains "p02-additive-schema.sh", contains "SUMMARY:") — create
- tools/verify/p04-override-source-enum-extended.sh (min 90 lines, contains "shadow_gate_blocked", contains "plan_frontmatter", contains "milestone_floor", contains "disabled", contains "none", contains "M030_SHADOW_MODE", contains "SUMMARY:") — create
- tools/verify/p04-sc2a-shadow-gate-block.sh (min 80 lines, contains "shadow_gate_blocked", contains "shadow-corpus-empty.jsonl", contains "live", contains "SUMMARY:") — create
- tools/verify/p04-sc3-live-mechanical.sh (min 80 lines, contains "model_used", contains "fast", contains "shadow-corpus-ready.jsonl", contains "stub-record-model", contains "SUMMARY:") — create
- tools/verify/p04-sc4-escalation-sequence.sh (min 100 lines, contains "fail-twice-then-pass", contains "escalation_count", contains "escalation_reason", contains "stub-fail-n", contains "SUMMARY:") — create
- tools/verify/p04-sc5-escalation-cap.sh (min 100 lines, contains "fail-three-times", contains "escalation_cap_hit", contains "final_count", contains "stub-fail-n", contains "SUMMARY:") — create
- tools/verify/p04-con5-no-fourth-record.sh (min 80 lines, contains "fail-four-times", contains "escalation_cap_hit", contains "STUB_FAIL_COUNTER_INVOCATIONS", contains "SUMMARY:") — create
- tools/verify/p04-con6-prior-records-bit-identical.sh (min 80 lines, contains "head -n 2", contains "shasum", contains "escalation", contains "SUMMARY:") — create
- tools/verify/p04-con3-live-closure.sh (min 50 lines, contains "claude-haiku", contains "claude-sonnet", contains "claude-opus", contains "git show HEAD", contains "SUMMARY:") — create
- tools/verify/p04-con4-live-killswitch.sh (min 80 lines, contains "model_routing_enabled", contains "live", contains "disabled", contains "is inactive", contains "SUMMARY:") — create
- tools/verify/p04-partial-flip-routing.sh (min 90 lines, contains "shadow-corpus-partially-ready.jsonl", contains "partial_flip_active", contains "withheld_classes", contains "SUMMARY:") — create
- tools/verify/p04-escalation-fields-enum.sh (min 80 lines, contains "escalation_count", contains "escalation_reason", contains "verifier_fail", contains "SUMMARY:") — create
- tools/verify/p04-phase-suite.sh (min 80 lines, contains "p04-additive-schema", contains "p04-override-source-enum-extended", contains "p04-sc2a-shadow-gate-block", contains "p04-sc3-live-mechanical", contains "p04-sc4-escalation-sequence", contains "p04-sc5-escalation-cap", contains "p04-con5-no-fourth-record", contains "p04-con6-prior-records-bit-identical", contains "p04-con3-live-closure", contains "p04-con4-live-killswitch", contains "p04-partial-flip-routing", contains "p04-escalation-fields-enum", contains "SUMMARY:") — create
- scripts/dispatch/dispatch-interface.sh (modify — add live-routing branch reading model_routing.live, programmatic shadow-compare invocation, --model flag passing to adapter, escalation loop with fast→balanced→smart progression, escalation_cap_hit record emission, kill-switch short-circuit BEFORE live branch; preserve shadow-off byte-equality) — modify
- references/model-routing.md (modify — add `## Live Routing` section documenting the flip-gate enforcement chain + escalation behavior + cap semantics; cite FR-9 / FR-10 / D-A2 / D-A3 / CON-5) — modify
- CLAUDE.md (modify — recent-changes region) — modify
- AGENTS.md (modify if present — recent-changes region dual-write) — modify

### Key Links

- specs/032-adaptive-model-selection/spec.md → scripts/dispatch/dispatch-interface.sh (FR-9 names the live-routing programmatic flip-gate path; FR-10 names the escalation logic; FR-19 names the additive escalation_count / escalation_reason fields and the escalation_cap_hit record_type)
- specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/shadow-compare.sh (FR-9 / D-A2 — dispatch-interface MUST invoke shadow-compare programmatically before any live-routed dispatch)
- specs/032-adaptive-model-selection/spec.md → references/model-routing.md (FR-9 / FR-10 / CON-5 — operator-facing live-routing + escalation documentation)
- [.orchestrator/milestones/M030/M030-CONTEXT.md](../../../../milestones/M030/M030-CONTEXT.md) → scripts/dispatch/dispatch-interface.sh (D-A2 names dispatch-interface as the programmatic enforcement point; D-A3 names per-class partial-flip authorization)
- scripts/dispatch/dispatch-interface.sh → templates/model-routing.yml (CON-3 closure preserved — escalation tier progression resolves through routing.yml; no new model-ID literals introduced)
- scripts/dispatch/dispatch-interface.sh → scripts/diagnostics/shadow-compare.sh (live-routing branch invokes shadow-compare; verdict gates the adapter call)
- scripts/dispatch/dispatch-interface.sh → .orchestrator/config.yml (FR-9 names the per-project overlay file; dispatch-interface reads model_routing.live: at dispatch time)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-sc2a-shadow-gate-block.sh (suite invokes the SC-2a gate)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-sc4-escalation-sequence.sh (suite invokes the SC-4 escalation gate)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-sc5-escalation-cap.sh (suite invokes the SC-5 cap gate)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-con6-prior-records-bit-identical.sh (suite invokes the CON-6 append-only gate)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-con4-live-killswitch.sh (suite invokes the CON-4 kill-switch-wins-in-live gate)
- tools/verify/p04-phase-suite.sh → tools/verify/p04-additive-schema.sh (suite invokes the SC-11 byte-equality pass-through gate)

## Tasks

### T01: P04 fixture plans + overlay configs + shadow corpora + stub adapters + tolerant pre-amendment gates (preflight)

See tasks/T01-fixtures-and-stubs-PLAN.md.

T01 ships before any work on `scripts/dispatch/dispatch-interface.sh` so the new field invariants are mechanically enforced at the moment T02/T03 amend the emitter. Mirrors the P02/T01 + P03/T01 graduation pattern (verifier-before-deliverable). T01 authors:

(a) Five fixture plans under `tests/fixtures/m030-p04/plans/` — `plan-mechanical-no-override.md` (load-bearing for SC-3 + partial-flip), `plan-fail-twice-then-pass.md` (T97 unitId; load-bearing for SC-4), `plan-fail-three-times.md` (T96 unitId; load-bearing for SC-5), `plan-fail-four-times.md` (T96 unitId; load-bearing for CON-5 no-fourth-record), `plan-novel-class.md` (load-bearing for partial-flip + class-routing tests).

(b) Three fixture configs under `tests/fixtures/m030-p04/configs/` — `config-with-live-true.yml` (live: true + nothing else), `config-with-live-and-killswitch.yml` (live: true + model_routing_enabled: false; CON-4/SC-7a compound), `config-with-live-false.yml` (live: false explicit; pass-through baseline).

(c) Three shadow-corpus JSONL fixtures under `tests/fixtures/m030-p04/` — `shadow-corpus-ready.jsonl` (50+ records per class with stable classifier_confidence; `shadow-compare.sh` returns `flip_recommendation=ready`), `shadow-corpus-partially-ready.jsonl` (≥50 records for two classes; under-threshold class is novel which routes to smart by default → D-A3 partial-flip safe), `shadow-corpus-empty.jsonl` (zero bytes; verdict = `evidence_insufficient`).

(d) Round-trip stage at `tests/fixtures/m030-p04/round-trip-stage/` — `intensity-metadata.txt` + `payload.txt`, mirroring P02/P03.

(e) Two new stub adapters under `scripts/dispatch/adapters/backend/`:
  - `stub-fail-n.sh` — programmable fail-counter adapter. Reads `STUB_FAIL_COUNTER_FILE` env var (path to a counter file containing a single integer); on each invocation, decrements the counter; if remaining > 0, exits 1 (failure); if remaining == 0, emits a conforming dispatch-result.md and exits 0. Also writes one line per invocation to `STUB_FAIL_COUNTER_INVOCATIONS_FILE` (env var) for side-channel invocation-count assertions (CON-5 verifier).
  - `stub-record-model.sh` — model-flag-recorder adapter. Reads the `--model <id>` flag passed by dispatch-interface (parsed via the same `case` block as other adapters), writes the value to `STUB_RECORD_MODEL_FILE` env var (path), and emits a conforming dispatch-result. Used by SC-3 verifier to assert the `--model` flag was passed with the runtime-default-resolved tier ID.

(f) Two pre-amendment-tolerant gates under `tools/verify/`:
  - `p04-additive-schema.sh` — thin pass-through wrapper that invokes `tools/verify/p02-additive-schema.sh` and asserts exit 0 (continues to enforce SC-11 byte-equality under HEAD post-T02/T03).
  - `p04-override-source-enum-extended.sh` — extends the P03 5-value enum check with a new Scenario F (live-mode + empty corpus → `shadow_gate_blocked`). Pre-amendment-tolerant: zero `override_source` tokens PASS pre-T02 (Scenario F's verdict path doesn't yet exist); exactly one with the `shadow_gate_blocked` value PASSES post-T02. The other five enum scenarios from P03 are inherited verbatim.

T01 ends green: all artifacts on disk, both tolerant verifiers pass against the pre-amendment `dispatch-interface.sh` (override-source-enum-extended green because Scenario F's `shadow_gate_blocked` token is not yet emitted; additive-schema green because P02's contract is unchanged).

T01 also stages a compound-config helper that T02's verifiers will use: when both `live: true` and `model_routing_enabled: false` are present, the kill-switch path supersedes the live path (CON-4 / D-A5). The fixture file `config-with-live-and-killswitch.yml` makes this scenario load-bearing for `p04-con4-live-killswitch.sh` in T02.

### T02: dispatch-interface live-routing branch + flip-gate enforcement + partial-flip + --model passing

See tasks/T02-live-routing-flip-gate-PLAN.md.

T02 is the high-risk core amendment, part 1 of 2. Reads the post-P03 `dispatch-interface.sh` (`_di_emit_dispatch_usage` body + the override-resolution block + the routing-table awk extraction) and amends it to:

1. **Read the `live:` knob** from `.orchestrator/config.yml model_routing:` block via the same awk section-walker pattern used for `min_tier:`. Store in a new local `override_live`.

2. **Insert a live-mode short-circuit** AFTER the existing kill-switch check but BEFORE the plan-frontmatter / milestone-floor branches. When `override_kill = false` (kill-switch active), emit an additional one-line stderr warning `model_routing_enabled=false: live: true is inactive` if `override_live = true`; the kill-switch path otherwise proceeds unchanged (CON-4 / D-A5 — kill switch wins).

3. **When `override_live = true` AND kill-switch is NOT active**, programmatically invoke `bash scripts/diagnostics/shadow-compare.sh --corpus <log_file>` (the same `$log_file` the emitter is writing to, OR a fixture corpus path from a new env var `M030_SHADOW_COMPARE_CORPUS` for verifier-time injection — preferred shape per FR-9 for verifier engineerability). Capture the verdict (`flip_recommendation=<value>`) via grep+sed. Branch on verdict:
   - `evidence_insufficient` OR `block` → set `shadow_override_source=shadow_gate_blocked`; SKIP the routing-table awk extraction; SKIP the adapter invocation; emit the JSONL record; exit nonzero with a synthesized dispatch-error document on stderr.
   - `ready` → resolve the routed tier via the existing P02 awk section-walker; resolve `shadow_used` to the runtime model ID via the resolution: block; pass `--model "$shadow_used"` as an additional flag to the backend adapter invocation at line ~589.
   - `partially_ready` → parse `withheld_classes=<list>` from shadow-compare stdout; if the current task's classifier-character maps (via routing:) to a tier in the withheld set, fall back to runtime-default channel (do NOT pass `--model` flag), set `shadow_partial=true`, set `shadow_withheld="<list>"`. Otherwise, route live (same as `ready` path).

4. **Pass `--model <id>` flag to backend adapter** when in live mode AND a tier is resolved. The adapter invocation at line ~586-589 currently passes `--task-plan`, `--payload`, `--intensity-metadata`. T02 conditionally appends `--model "$shadow_used"` when `shadow_override_source = none` AND `override_live = true` AND verdict is `ready` or `partially_ready` (with the task's class flippable). The `stub-record-model.sh` and `stub-fail-n.sh` adapters from T01 accept and process this flag.

5. **Emit `partial_flip_active` and `withheld_classes`** as already-reserved JSONL fields (P02/T03 reserved them as empty placeholders). T02 populates them when verdict = `partially_ready`.

6. **Co-authored verifiers**: `p04-sc2a-shadow-gate-block.sh`, `p04-sc3-live-mechanical.sh`, `p04-partial-flip-routing.sh`, `p04-con3-live-closure.sh`, `p04-con4-live-killswitch.sh`. Each follows the round-trip-stage shape from P03 verifiers (tmp_root with `.orchestrator/config.yml` + `phases/` carve-out; `M030_SHADOW_MODE=1 CLAUDECODE=1 ORCHESTRATOR_ROOT=tmp_root` env). The SC-2a verifier asserts dispatch-interface exits nonzero AND the JSONL record records `shadow_gate_blocked` AND no dispatch-result was emitted (the adapter was never invoked). The SC-3 verifier asserts the stub-record-model file contains the resolution.fast.claude-code value (extracted at runtime via awk — CON-3-clean). The partial-flip verifier exercises both a flippable-class task and a withheld-class task against the same `partially_ready` corpus.

T02 also re-runs T01's tolerant gates against the amended emitter to confirm the post-amendment branch fires correctly: `p04-override-source-enum-extended.sh` Scenario F now produces exactly one `shadow_gate_blocked` token; `p04-additive-schema.sh` continues to pass (shadow-off byte-equality preserved).

### T03: dispatch-interface escalation loop + CON-5 cap + escalation_cap_hit record + CON-6 append-only

See tasks/T03-escalation-loop-PLAN.md.

T03 is the high-risk core amendment, part 2 of 2. Reads T02's amended `dispatch-interface.sh` (live-routing branch, flip-gate, --model passing) and amends it to:

1. **Wrap the adapter invocation in an escalation loop** that runs ONLY when in live mode AND verdict is `ready` or `partially_ready` AND the current task's class is flippable. The loop:
   - Iteration 0: invoke adapter at the routed tier (e.g., `fast` for mechanical). Capture rc.
   - On rc != 0: increment `escalation_count` (in-memory local; starts at 0). If `escalation_count <= 2`, recompute the next tier (`fast → balanced → smart` via `_di_tier_rank` reverse lookup — add a `_di_tier_at_rank` helper next to `_di_tier_rank`). Re-resolve `shadow_used` for the new tier. Emit a NEW dispatch_usage record with the new `model_used`, `escalation_count`, and `escalation_reason=verifier_fail`. Re-invoke adapter.
   - At `escalation_count = 2`: this is the third attempt total. If rc != 0 after this, the cap is hit — emit ONE `escalation_cap_hit` record with `record_type=escalation_cap_hit`, `final_count=2`, `unitId=<id>`, `timestamp=<iso8601>`. Do NOT re-invoke adapter for a fourth attempt. Exit nonzero with the standard adapter-failed dispatch-error.

2. **Each iteration emits a separate dispatch_usage record** via a per-iteration call to `_di_emit_dispatch_usage` (or an inlined emit block). Records share `unitId` but have distinct `timestamp` values; the `escalation_count` and `escalation_reason` fields differentiate them. Prior records are NEVER rewritten — the only file mutation is `>> "$log_file"` (append-only per CON-6).

3. **Add the `_di_tier_at_rank` helper** alongside `_di_tier_rank`:
   ```bash
   _di_tier_at_rank() {
     case "$1" in
       0) echo fast ;;
       1) echo balanced ;;
       2) echo smart ;;
       *) echo "" ;;
     esac
   }
   ```

4. **Add new JSONL fields** `escalation_count` (integer) + `escalation_reason` (string) to BOTH shadow-on printf format strings (happy-path line ~453 and degradation line ~486). On initial dispatch (no escalation), emit `escalation_count=0` and `escalation_reason=""`. On escalated dispatches, emit the running counter and `verifier_fail`. SC-11 byte-equality is preserved — the shadow-off branches remain untouched.

5. **Add `escalation_cap_hit` record emission** as a new printf at the top level of `dispatch-interface.sh` (after the escalation loop concludes with cap hit). Single-line JSON record:
   ```text
   {"record_type":"escalation_cap_hit","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","final_count":2,"timestamp":"%s"}
   ```

6. **Co-authored verifiers**: `p04-sc4-escalation-sequence.sh`, `p04-sc5-escalation-cap.sh`, `p04-con5-no-fourth-record.sh`, `p04-con6-prior-records-bit-identical.sh`, `p04-escalation-fields-enum.sh`. Each follows the round-trip-stage shape with the `stub-fail-n.sh` adapter and the counter-file env vars from T01. The SC-4 verifier engineers a 2-fail-then-pass scenario and asserts the model_used sequence + escalation_count=2 on the third record. The SC-5 verifier engineers a 3-fail-everywhere scenario and asserts exactly 3 dispatch_usage records + 1 escalation_cap_hit. The CON-5 verifier engineers a 4-fail scenario and asserts the stub adapter was invoked exactly 3 times (no fourth attempt). The CON-6 verifier captures `head -n 2` of the log mid-escalation (via a sentinel file the stub-fail-n drops on each invocation; the verifier uses `tee` + a tmp-staged log to inspect intermediate state) and re-captures after the full sequence; SHA-256 of the first-two-lines bytes must match.

T03 also re-runs T01/T02's gates against the amended emitter to confirm:
- `p04-additive-schema.sh` continues to pass (shadow-off byte-equality preserved post-T03 — only shadow-on printfs gained `escalation_count` + `escalation_reason`).
- `p04-override-source-enum-extended.sh` continues to pass (override_source enum unchanged).
- `p04-sc2a-shadow-gate-block.sh` (T02 deliverable) continues to pass (the shadow_gate_blocked path emits zero escalations because the adapter is never invoked).
- `p04-sc3-live-mechanical.sh` (T02 deliverable) continues to pass (no failure → `escalation_count=0` on the single dispatch record).
- `p04-con4-live-killswitch.sh` (T02 deliverable) continues to pass (kill switch short-circuits before escalation logic ever fires).

T03 amends `references/model-routing.md` to add the `## Live Routing` section documenting the flip-gate + escalation chain end-to-end (operator-facing docs co-locate with the gate-verifier ship date, mirroring P03/T03's `## Operator Overrides` section pattern).

### T04: P04 phase-suite aggregator + recent-changes dual-write + commit

See tasks/T04-phase-suite-and-close-PLAN.md.

T04 closes P04 with three deliverables:

1. **`tools/verify/p04-phase-suite.sh`** — straight-line aggregator over all twelve P04 sub-gates (additive-schema + override-source-enum-extended + sc2a-shadow-gate-block + sc3-live-mechanical + sc4-escalation-sequence + sc5-escalation-cap + con5-no-fourth-record + con6-prior-records-bit-identical + con3-live-closure + con4-live-killswitch + partial-flip-routing + escalation-fields-enum). Same straight-line shape as `p02-phase-suite.sh` and `p03-phase-suite.sh` (literal `bash <path>` invocations + per-gate rc capture + pass/fail accumulators + SUMMARY line).

2. **CLAUDE.md + AGENTS.md recent-changes dual-write** via `scripts/util/dual-write-runtime-md.sh --append-entry` with the standard single-line P04-close entry summarizing live-routing + escalation + flip-gate enforcement deliverables.

3. **Stage + commit P04 close** as a single coherent commit covering the phase-suite verifier, the CLAUDE.md+AGENTS.md edits, and any plan-side amendments needed to satisfy `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04`. Plan-amendments-not-task-reopen pattern (per P02/T04 + P03/T04 precedent) when the must-haves grep fails on artifact-grep or key-link-direction. Use `git commit -F /tmp/p04-t04-commit-msg.txt` (multi-line message; AP-008 heredoc-with-expansion forbids the inline-HEREDOC form).

After T04 commits, P04 is closed and the orchestrator state machine transitions to `summarized` for P04 (phase-summary still authored by `orchestrator:verify` + `orchestrator:consolidate` downstream).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01 ships the fixture plans + configs + shadow corpora + stub adapters + tolerant pre-amendment gates BEFORE T02 amends `dispatch-interface.sh`, so the enum invariants and the SC-11 byte-equality contract have mechanical gates at the moment the diff lands (mirrors P02/T01 + P03/T01 graduation patterns). T02 ships the live-routing branch (flip-gate + --model passing + partial-flip routing) + co-authored verifiers (SC-2a, SC-3, partial-flip, CON-3 live-closure, CON-4 live-killswitch). T03 layers the escalation loop on top of T02's live-routing branch + co-authors the escalation/cap/append-only verifiers. T04 closes the phase with the suite + commit.

T01 and T02 cannot be parallelized: T01 IS the enum gate and the SC-11 gate that T02 must continue to pass. T02 and T03 cannot be parallelized: T03's escalation loop wraps T02's adapter invocation; the `--model` passing and the live-mode gating belong to T02's locus. T03 and T04 cannot be parallelized: T04's phase-suite invokes T03's verifiers.

## Files Likely Touched

- scripts/dispatch/dispatch-interface.sh (modify)
- scripts/dispatch/adapters/backend/stub-fail-n.sh (create)
- scripts/dispatch/adapters/backend/stub-record-model.sh (create)
- references/model-routing.md (modify)
- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-three-times.md (create)
- tests/fixtures/m030-p04/plans/plan-fail-four-times.md (create)
- tests/fixtures/m030-p04/plans/plan-novel-class.md (create)
- tests/fixtures/m030-p04/configs/config-with-live-true.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml (create)
- tests/fixtures/m030-p04/configs/config-with-live-false.yml (create)
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl (create)
- tests/fixtures/m030-p04/shadow-corpus-empty.jsonl (create)
- tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt (create)
- tests/fixtures/m030-p04/round-trip-stage/payload.txt (create)
- tools/verify/p04-additive-schema.sh (create)
- tools/verify/p04-override-source-enum-extended.sh (create)
- tools/verify/p04-sc2a-shadow-gate-block.sh (create)
- tools/verify/p04-sc3-live-mechanical.sh (create)
- tools/verify/p04-sc4-escalation-sequence.sh (create)
- tools/verify/p04-sc5-escalation-cap.sh (create)
- tools/verify/p04-con5-no-fourth-record.sh (create)
- tools/verify/p04-con6-prior-records-bit-identical.sh (create)
- tools/verify/p04-con3-live-closure.sh (create)
- tools/verify/p04-con4-live-killswitch.sh (create)
- tools/verify/p04-partial-flip-routing.sh (create)
- tools/verify/p04-escalation-fields-enum.sh (create)
- tools/verify/p04-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->
