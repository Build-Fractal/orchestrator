---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M030"
goal: "Wire operator overrides + kill switch into scripts/dispatch/dispatch-interface.sh so override_source is recorded for every shadow-on dispatch with values drawn from the closed enum {plan_frontmatter, milestone_floor, disabled, shadow_gate_blocked, none} (FR-4 / FR-11 / FR-12 / FR-13 / FR-14). Kill switch supersedes min_tier per CON-4 / D-A5 (SC-7a compound semantics). Override resolution is performed BEFORE the routing-table awk extraction so the recorded model_routed reflects the post-override symbolic tier; classifier still runs unconditionally so model_routed=<tier> remains paired with classifier_confidence=<enum> for stability tracking. SC-11 byte-equality holds when shadow off (override_source absent in shadow-off branch). All routing decisions resolve through templates/model-routing.yml (CON-3 — no new hardcoded model IDs). Append-only discipline preserved (CON-6). The kill-switch + min_tier compound interaction emits a single-line stderr warning naming the bypassed min_tier value when both knobs are active. Plan-time override path (model_override: in PLAN.md frontmatter) is parsed via the same grep+head+sed pattern P02 uses for character/confidence (no jq, no yq, no new dependency). Per-milestone overlay path reads .orchestrator/config.yml model_routing block via grep+sed scoped to the model_routing: section."
demo_sentence: "An operator dispatches three fixture plans: (a) tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md whose frontmatter declares model_override: smart against an unmodified routing table, (b) any mechanical-classified plan against tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml symlinked into ORCH_ROOT, (c) any plan against tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml. Each appended JSONL record carries override_source equal to plan_frontmatter, milestone_floor, and disabled respectively (jq -r .override_source); SC-7a compound case (kill switch + min_tier) records override_source=disabled with stderr containing the line min_tier: smart is inactive; tools/verify/p03-additive-schema.sh re-confirms shadow-off byte-equality against P02's pre-M030 fixture; tools/verify/p03-phase-suite.sh emits SUMMARY: p03-phase-suite.sh pass=N fail=0 with N>=7 and exits 0."
risk: "medium"
depends_on: ["P02"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p03-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2. T01 ships the
     additive-schema gate + override-source enum verifier + fixture
     plans/configs BEFORE T02 amends dispatch-interface.sh; T02 amends
     the override-resolution path; T03 stages the round-trip dispatch
     fixtures + the SC-6/SC-7/SC-7a verifiers; T04 closes with the
     phase-suite aggregator. Strict linear chain. -->

### Truths

- `scripts/dispatch/dispatch-interface.sh` emits an `override_source` field on every shadow-on `dispatch_usage` record drawn from the closed enum {`plan_frontmatter`, `milestone_floor`, `disabled`, `shadow_gate_blocked`, `none`}. Shadow-off records do NOT contain the `override_source` field (additive-only — CON-2/FR-19/SC-11). The verifier exercises four scenarios (plan-frontmatter override, milestone-floor overlay, kill-switch overlay, no-overlay-no-override) under shadow-on and asserts the appended JSONL line contains exactly one `"override_source"` token whose value is one of the five enum strings; under shadow-off it asserts zero `override_source` tokens. (FR-4/FR-11/FR-12/FR-13/FR-14/D-A5.)
  - Check: `bash tools/verify/p03-override-source-enum.sh`

- SC-6 holds: a PLAN.md whose frontmatter declares `model_override: smart` and which the P01 classifier would have classified as `mechanical` dispatches with `model_routed=smart` (post-override) and `override_source=plan_frontmatter`. The verifier stages a fixture plan at `tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md` whose body matches the mechanical-classifier signature (explicit `## Steps` block with file paths + bash verifiers) AND whose frontmatter declares `model_override: smart`, runs an `M030_SHADOW_MODE=1 CLAUDECODE=1` round-trip dispatch through `dispatch-interface.sh`, reads the appended JSONL line, asserts `model_routed=smart` AND `override_source=plan_frontmatter`. Independently re-runs `bash scripts/dispatch/classify-task.sh <plan>` on the same plan and asserts the classifier alone returned `character=mechanical` (i.e., the override actually changed the routed tier). (FR-11/SC-6.)
  - Check: `bash tools/verify/p03-sc6-frontmatter-override.sh`

- SC-7 holds: with `.orchestrator/config.yml` setting `model_routing_enabled: false`, a shadow-on dispatch records `override_source=disabled` AND `model_used` matches the runtime default (the pre-amendment shadow-off `model_used` value, NOT the routing-table-resolved value). The verifier stages a fixture config at `tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml`, points `ORCH_ROOT` at a milestone tree whose `.orchestrator/config.yml` is the fixture, runs a round-trip dispatch, reads the appended JSONL line, asserts `override_source=disabled`, asserts `model_used` matches `${ORCH_MODEL:-}` (the runtime-default channel — not the routing-table `resolution.fast.claude-code` value). (FR-13/SC-7.)
  - Check: `bash tools/verify/p03-sc7-kill-switch.sh`

- SC-7a (compound kill-switch + min_tier) holds: with `.orchestrator/config.yml` declaring BOTH `model_routing_enabled: false` AND `model_routing.min_tier: smart`, a shadow-on dispatch on a `mechanical`-classified plan records `override_source=disabled` (NOT `milestone_floor`), `model_used` matches the runtime default, AND stderr contains a single-line warning whose body matches the regex `min_tier: ?smart is inactive` (substring match — the literal string `model_routing_enabled=false: min_tier: smart is inactive` per CON-4/D-A5 amendment). The verifier captures stderr to a tmp file via `2> /tmp/p03-sc7a-stderr.txt` and greps the file. (CON-4/D-A5/SC-7a.)
  - Check: `bash tools/verify/p03-sc7a-compound.sh`

- The override-resolution path in `dispatch-interface.sh` introduces zero new hardcoded model IDs. The amendment never embeds a literal `claude-haiku-*`, `claude-sonnet-*`, `claude-opus-*`, `gpt-*`, `o1-*`, `o3-*`, or `gemini-*` string. When `model_override:` resolves to a symbolic tier (`fast|balanced|smart`), the resolution to a concrete model ID flows through the same `templates/model-routing.yml resolution.<tier>.claude-code` awk-extraction path P02 uses. When `model_override:` resolves to a concrete model ID (operator-pinned snapshot like `claude-haiku-4-5-20260101`), that string is read FROM the plan-frontmatter file, never embedded in the script. The verifier compares the post-amendment file against `git show HEAD:scripts/dispatch/dispatch-interface.sh` and asserts the per-pattern provider-ID grep count is unchanged. (CON-3.)
  - Check: `bash tools/verify/p03-con3-closure.sh`

- `min_tier` enforcement: when `.orchestrator/config.yml` declares `model_routing.min_tier: smart` AND the kill switch is unset/false AND the plan does NOT declare `model_override:`, a `mechanical`-classified plan dispatches with `model_routed=smart` (raised from the routing-table default `fast`) AND `override_source=milestone_floor`. The verifier stages `tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml`, runs a round-trip dispatch on a mechanical-classified plan, asserts the JSONL line contains `model_routed=smart` AND `override_source=milestone_floor`. Independently re-runs the classifier on the same plan and asserts `character=mechanical`. (FR-12.)
  - Check: `bash tools/verify/p03-min-tier-floor.sh`

- Override-conflict (FR-14) resolution: when a plan declares `model_override: fast` AND milestone config declares `model_routing.min_tier: smart`, the floor wins — `model_routed=smart`, `override_source=milestone_floor` (NOT `plan_frontmatter`), and stderr contains a single-line warning. The verifier stages a plan with `model_override: fast` plus a config with `min_tier: smart`, captures stderr to tmp, asserts the JSONL line carries `override_source=milestone_floor` AND `model_routed=smart` AND the stderr file contains a warning naming both `model_override` and `min_tier`. (FR-14.)
  - Check: `bash tools/verify/p03-override-conflict.sh`

- SC-11 byte-equality re-confirmed against P02's pre-M030 fixture: with shadow mode off (CLAUDECODE unset OR M030_SHADOW_MODE unset), the `dispatch-interface.sh` emit path produces output byte-identical to `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`'s first record under round-trip via the existing P02 stage. The verifier delegates to `tools/verify/p02-additive-schema.sh` (P02 deliverable, still on disk) — re-running it under HEAD must continue to pass after T02's amendment lands. The P03 verifier is a thin wrapper that invokes the P02 gate and asserts exit 0. (CON-2/FR-19/SC-11.)
  - Check: `bash tools/verify/p03-additive-schema.sh`

- `bash tools/verify/p03-phase-suite.sh` invokes all seven P03 sub-gates (override-source-enum, sc6-frontmatter-override, sc7-kill-switch, sc7a-compound, con3-closure, min-tier-floor, override-conflict) plus the additive-schema pass-through verifier (eight total) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p03-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p02-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p03-phase-suite.sh`

### Artifacts

- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md (min 25 lines, contains "model_override", contains "smart", contains "## Steps") — create
- tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md (min 25 lines, contains "## Steps", contains "bash tools/verify") — create
- tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md (min 25 lines, contains "model_override", contains "fast", contains "## Steps") — create
- tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml (min 8 lines, contains "model_routing_enabled", contains "false") — create
- tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml (min 8 lines, contains "model_routing", contains "min_tier", contains "smart") — create
- tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml (min 8 lines, contains "model_routing_enabled", contains "false", contains "min_tier", contains "smart") — create
- tests/fixtures/m030-p03/configs/config-baseline.yml (min 4 lines, contains "schema_version") — create
- tools/verify/p03-override-source-enum.sh (min 80 lines, contains "override_source", contains "plan_frontmatter", contains "milestone_floor", contains "disabled", contains "shadow_gate_blocked", contains "M030_SHADOW_MODE", contains "SUMMARY:") — create
- tools/verify/p03-sc6-frontmatter-override.sh (min 60 lines, contains "model_override", contains "plan_frontmatter", contains "model_routed", contains "smart", contains "classify-task.sh", contains "SUMMARY:") — create
- tools/verify/p03-sc7-kill-switch.sh (min 60 lines, contains "model_routing_enabled", contains "false", contains "override_source", contains "disabled", contains "SUMMARY:") — create
- tools/verify/p03-sc7a-compound.sh (min 70 lines, contains "model_routing_enabled", contains "min_tier", contains "smart", contains "is inactive", contains "stderr", contains "SUMMARY:") — create
- tools/verify/p03-con3-closure.sh (min 50 lines, contains "claude-haiku", contains "claude-sonnet", contains "claude-opus", contains "dispatch-interface.sh", contains "git show HEAD", contains "SUMMARY:") — create
- tools/verify/p03-min-tier-floor.sh (min 60 lines, contains "min_tier", contains "smart", contains "milestone_floor", contains "model_routed", contains "classify-task.sh", contains "SUMMARY:") — create
- tools/verify/p03-override-conflict.sh (min 60 lines, contains "model_override", contains "min_tier", contains "milestone_floor", contains "stderr", contains "SUMMARY:") — create
- tools/verify/p03-additive-schema.sh (min 20 lines, contains "p02-additive-schema.sh", contains "SUMMARY:") — create
- tools/verify/p03-phase-suite.sh (min 60 lines, contains "p03-override-source-enum", contains "p03-sc6-frontmatter-override", contains "p03-sc7-kill-switch", contains "p03-sc7a-compound", contains "p03-con3-closure", contains "p03-min-tier-floor", contains "p03-override-conflict", contains "p03-additive-schema", contains "SUMMARY:") — create
- scripts/dispatch/dispatch-interface.sh (modify — add override-resolution path BEFORE the routing-table awk extraction; emit override_source as additive 5th shadow field on shadow-on records; preserve shadow-off byte-equality) — modify
- references/model-routing.md (modify — add `## Operator Overrides` section documenting the override precedence chain: kill switch supersedes min_tier supersedes plan model_override supersedes routed; cite CON-4/D-A5 + FR-13 + FR-12 + FR-11 + FR-14) — modify

### Key Links

- specs/032-adaptive-model-selection/spec.md → scripts/dispatch/dispatch-interface.sh (FR-4/FR-11/FR-12/FR-13/FR-14 name the override-resolution path; FR-19 names the additive override_source field)
- specs/032-adaptive-model-selection/spec.md → references/model-routing.md (CON-4 + D-A5 name the kill-switch + min_tier compound-precedence rule documented in references)
- .orchestrator/milestones/M030/M030-CONTEXT.md → scripts/dispatch/dispatch-interface.sh (D-A5 amends CON-4 with the kill-switch supersedes min_tier compound case — implementation surface is dispatch-interface)
- scripts/dispatch/dispatch-interface.sh → templates/model-routing.yml (CON-3 closure preserved — symbolic-tier overrides resolve through routing.yml; no new model-ID literals introduced)
- scripts/dispatch/dispatch-interface.sh → .orchestrator/config.yml (FR-4/FR-12/FR-13 name the per-project overlay file; dispatch-interface reads the model_routing block at dispatch time)
- tools/verify/p03-phase-suite.sh → tools/verify/p03-override-source-enum.sh (suite invokes override-source-enum gate)
- tools/verify/p03-phase-suite.sh → tools/verify/p03-sc7a-compound.sh (suite invokes the compound CON-4/D-A5 gate)
- tools/verify/p03-phase-suite.sh → tools/verify/p03-additive-schema.sh (suite invokes the SC-11 byte-equality pass-through gate)

## Tasks

### T01: P03 fixture plans + overlay configs + override-source-enum gate (preflight)

See tasks/T01-fixtures-and-enum-gate-PLAN.md.

T01 ships before any work on `scripts/dispatch/dispatch-interface.sh` so the override_source enum invariant is mechanically enforced at the moment T02 amends the emitter. Mirror of P02/T01's D-A4 timeline-graduation discipline (verifier-before-deliverable). T01 authors: (a) seven fixture files under `tests/fixtures/m030-p03/` — three plan files exercising the override frontmatter shapes, four config files exercising the overlay shapes, plus a baseline; (b) `tools/verify/p03-override-source-enum.sh` (gates the closed enum + shadow-on/off branching); (c) `tools/verify/p03-additive-schema.sh` (thin pass-through wrapper that invokes `tools/verify/p02-additive-schema.sh` and asserts exit 0 — the P02 SC-11 contract continues to hold under HEAD). T01 also stages a P03 round-trip directory under `tests/fixtures/m030-p03/round-trip-stage/` mirroring the P02 stage shape so T02 has deterministic dispatch inputs. T01 ends green: all artifacts on disk, both verifiers pass against the pre-amendment `dispatch-interface.sh` (override-source-enum gate green because shadow-off branch emits zero `override_source` tokens — the enum check is vacuously satisfied; additive-schema gate green because P02's contract is unchanged). T02 inherits a hard gate that fails the moment the override_source emit path drifts from the closed enum.

### T02: dispatch-interface override-resolution path + override_source emit + CON-4/D-A5 compound

See tasks/T02-override-resolution-PLAN.md.

T02 is the high-risk core amendment. Reads P01's classifier and routing table; reads the in-flight task plan's frontmatter for `model_override:`; reads `.orchestrator/config.yml` for the `model_routing:` block (`enabled`, `min_tier`); amends `_di_emit_dispatch_usage` so that BEFORE the routing-table awk extraction (existing P02 block at lines ~301-324), the override-resolution path runs and produces a single `(routed_tier, override_source)` pair. Precedence chain (CON-4 / D-A5):

1. Kill switch first: if `model_routing_enabled: false`, set `routed_tier=""` (signals "no routing — runtime default"), `override_source=disabled`. If `min_tier:` is also set, emit a one-line stderr warning. Skip the routing-table awk; `model_used` defaults to `${ORCH_MODEL:-}` (runtime default channel — same as the existing pre-amendment `model` field on line 213).
2. Plan frontmatter `model_override:` second: parse via `grep -E '^model_override:' "$TASK_PLAN" | head -n 1 | sed -E 's/^model_override:[[:space:]]*"?([^"]*)"?.*/\1/'`. If non-empty, set `routed_tier=<value>`, `override_source=plan_frontmatter`.
3. Milestone floor `model_routing.min_tier:` third: parse via `grep -E '^[[:space:]]+min_tier:' "$ORCH_ROOT/../config.yml" | head -n 1 | sed -E ...` (scoped under `model_routing:`). If a numeric tier-rank comparison shows the routed tier is below the floor, raise to floor; `override_source=milestone_floor`.
4. Plain routed (existing P02 path) fourth: if no override, no floor, no kill switch — fall through to the P02 awk extraction; `override_source=none`.

Both T01-staged enum and T02-amended emit branches MUST round-trip the four fixture configs cleanly. Co-authored verifiers: `p03-sc7-kill-switch.sh`, `p03-sc7a-compound.sh`, `p03-min-tier-floor.sh`, `p03-con3-closure.sh`. T02 also re-runs T01's `p03-additive-schema.sh` and `p03-override-source-enum.sh` to confirm shadow-off byte-equality + shadow-on enum closure both hold under the amended emitter.

### T03: SC-6 frontmatter override + override-conflict (FR-14) + references docs

See tasks/T03-sc6-and-conflict-PLAN.md.

T03 closes the remaining override semantics: SC-6 (plain plan-frontmatter override raises the tier above the classifier's choice) and FR-14 (when plan-frontmatter override AND milestone min_tier disagree, floor wins; stderr names both knobs). T03 authors `tools/verify/p03-sc6-frontmatter-override.sh` and `tools/verify/p03-override-conflict.sh`, both using the same round-trip-stage harness P02 established. T03 also amends `references/model-routing.md` to add the `## Operator Overrides` section documenting the precedence chain (kill switch supersedes min_tier supersedes plan model_override supersedes routed) — operator-facing docs that will surface in `orchestrator:doctor --config-check` output (M030/P05 deliverable, but the docs land here in P03 so the chain is documented at the moment the code ships).

### T04: P03 phase-suite + recent-changes dual-write + commit

See tasks/T04-phase-suite-and-close-PLAN.md.

T04 authors `tools/verify/p03-phase-suite.sh` — the straight-line aggregator over all eight P03 sub-gates (mirrors `p02-phase-suite.sh` shape). Each sub-gate is invoked as a literal `bash <path>` statement; `pass`/`fail` accumulators update via `pass=$((pass+1))`/`fail=$((fail+1))` per `$?`. Final line: `SUMMARY: p03-phase-suite.sh pass=N fail=M`. T04 also runs the dual-write recent-changes update against `CLAUDE.md` (and `AGENTS.md` if present) via `scripts/util/dual-write-runtime-md.sh` and stages + commits all P03 deliverables with `git commit -F <message-file>` (multi-line message; AP-008 heredoc-with-expansion forbids the inline-HEREDOC form per CLAUDE.md commit-authoring guidance).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01 ships the override-source enum gate + fixtures BEFORE T02 amends `dispatch-interface.sh`, so the enum-closure invariant has a mechanical gate at the moment the diff lands (mirrors P02/T01's graduation pattern). T02 ships the override-resolution amendment + co-authored verifiers (`p03-sc7-kill-switch.sh`, `p03-sc7a-compound.sh`, `p03-min-tier-floor.sh`, `p03-con3-closure.sh`); T03 consumes T02's amended emit path for SC-6 + FR-14 verifiers and the references-doc edit. T04 closes the phase with the suite + commit.

T01 and T02 cannot be parallelized: T01 IS the enum gate that T02 must pass. T02 and T03 cannot be parallelized: T03's verifiers exercise the override-resolution path that only exists after T02. T03 and T04 cannot be parallelized: T04's phase-suite invokes T03's verifiers.

## Files Likely Touched

- scripts/dispatch/dispatch-interface.sh (modify)
- references/model-routing.md (modify)
- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md (create)
- tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md (create)
- tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md (create)
- tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml (create)
- tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml (create)
- tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml (create)
- tests/fixtures/m030-p03/configs/config-baseline.yml (create)
- tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt (create)
- tests/fixtures/m030-p03/round-trip-stage/payload.txt (create)
- tools/verify/p03-override-source-enum.sh (create)
- tools/verify/p03-sc6-frontmatter-override.sh (create)
- tools/verify/p03-sc7-kill-switch.sh (create)
- tools/verify/p03-sc7a-compound.sh (create)
- tools/verify/p03-con3-closure.sh (create)
- tools/verify/p03-min-tier-floor.sh (create)
- tools/verify/p03-override-conflict.sh (create)
- tools/verify/p03-additive-schema.sh (create)
- tools/verify/p03-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->
