---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M030"
provides:
  - "dispatch-interface.sh override-resolution path (kill-switch->plan-frontmatter->milestone-floor->none precedence chain),_di_tier_rank helper,2 shadow-on printf format-string extensions adding override_source field,4 new T02 verifiers (p03-sc7-kill-switch.sh p03-sc7a-compound.sh p03-min-tier-floor.sh p03-con3-closure.sh)"
requires:
  - "from:T01 what:fixture plans+overlay configs+round-trip stage+pre-amendment-tolerant override-source-enum gate"
affects:
  - "P03,P04,P05"
key_files:
  - "scripts/dispatch/dispatch-interface.sh,tools/verify/p03-sc7-kill-switch.sh,tools/verify/p03-sc7a-compound.sh,tools/verify/p03-min-tier-floor.sh,tools/verify/p03-con3-closure.sh"
key_decisions:
  - "config-resolution-three-candidate-paths-ORCH_ROOT-config-yml-then-ORCH_ROOT-dot-orchestrator-config-yml-then-ORCH_ROOT-parent-config-yml,shadow_used-equals-model-runtime-default-channel-under-disabled-recommended-populate-explicitly-shape,floor-wins-conflict-uses-numeric-tier-rank-comparison-with-minus-one-unknown-guard,override-resolution-block-runs-before-routing-extraction-three-mutually-exclusive-post-block-awk-paths"
patterns_established:
  - "override-resolution-before-routing-extraction-shape,stderr-warning-emission-inside-emitter-body-with-two-distinct-warning-shapes,per-pattern-HEAD-vs-WT-grep-count-comparison-mirrors-P02-CON3-closure-shape,round-trip-verifier-shape-reused-from-T01-tmp_root-with-dot-orchestrator-config-yml-and-phases-subdir"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P03/tasks/T02-override-resolution-PLAN.md,scripts/dispatch/dispatch-interface.sh"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-30T15:08:30Z"
---

## What was built

T02 is the high-risk core amendment for P03. Five deliverables shipped as one coherent change:

1. **`scripts/dispatch/dispatch-interface.sh` — override-resolution path.** Added `_di_tier_rank` helper (fast=0/balanced=1/smart=2; -1 for unknown) at the top-level alongside `_di_rollup_savings_fields`. Inserted an override-resolution block inside `_di_emit_dispatch_usage` that runs BEFORE the existing P02 routing-table awk extraction. The block resolves `_di_config_yml` (tries `$ORCH_ROOT/config.yml`, then `$ORCH_ROOT/.orchestrator/config.yml`, then `$ORCH_ROOT/../config.yml`), reads `model_routing_enabled` (kill switch) via grep+sed, reads `model_override` from `$TASK_PLAN` frontmatter, and reads `model_routing.min_tier` via an awk section-walker. Applies precedence chain: kill-switch → plan-frontmatter → milestone-floor → none. Emits stderr warnings on (a) kill-switch + min_tier compound, and (b) plan-vs-floor floor-wins conflict. Wraps the existing P02 routing-table awk in a guard so it only runs under `none`. Adds a second resolution-only awk for `plan_frontmatter` / `milestone_floor` to populate `shadow_used`. Under `disabled`, sets `shadow_routed=""` and `shadow_used="$model"` (runtime-default channel).

2. **Two shadow-on `printf` format strings extended** with `,"override_source":"%s"` after `withheld_classes`, with `"$shadow_override_source"` appended to args. Shadow-OFF printf branches (lines ~346 and ~378) UNCHANGED — SC-11 byte-equality preserved (verified by `p03-additive-schema.sh` delegating to P02).

3. **`tools/verify/p03-sc7-kill-switch.sh`** — round-trip dispatch with `config-with-routing-disabled.yml`; asserts `override_source=disabled` AND `model_used=claude-opus-4-7` (runtime default from intensity-metadata).

4. **`tools/verify/p03-sc7a-compound.sh`** — round-trip with `config-with-killswitch-and-floor.yml` + stderr capture; asserts `override_source=disabled` AND NOT `milestone_floor` AND `model_used` matches runtime default AND stderr contains `min_tier: smart is inactive` warning.

5. **`tools/verify/p03-min-tier-floor.sh`** — round-trip with `config-with-min-tier-smart.yml`; asserts classifier independently returns `character=mechanical` AND `override_source=milestone_floor` AND `model_routed=smart` (raised from fast).

6. **`tools/verify/p03-con3-closure.sh`** — mirrors P02/T02's `p02-con3-closure.sh` shape; HEAD-vs-working-tree per-pattern grep count comparison over 7 provider-model-ID prefixes.

## Verification

- `tools/verify/p03-additive-schema.sh` → pass=1 fail=0 (delegates to P02 SC-11 byte-equality, still green)
- `tools/verify/p03-override-source-enum.sh` → pass=6 fail=0 (5 scenarios + prerequisites; post-amendment branch fires for A=none, B=disabled, C=plan_frontmatter, D=milestone_floor; E=zero tokens)
- `tools/verify/p03-sc7-kill-switch.sh` → pass=2 fail=0
- `tools/verify/p03-sc7a-compound.sh` → pass=3 fail=0
- `tools/verify/p03-min-tier-floor.sh` → pass=3 fail=0
- `tools/verify/p03-con3-closure.sh` → pass=7 fail=0
- `tools/verify/p02-phase-suite.sh` → pass=9 fail=0 (no P02 regression — shadow-emit, additive-schema, con3-closure, append-only, etc. all still green under the amended emitter)

## Key decisions

- **Config-resolution paths extended to three candidates.** Plan specified `$ORCH_ROOT/config.yml` then `$ORCH_ROOT/../config.yml`. The T01 fixture stages config at `$ORCH_ROOT/.orchestrator/config.yml` (where `ORCH_ROOT` is the tmp_root), so I added that as the second candidate. This matches both fixture-mode (ORCH_ROOT is project-root-with-.orchestrator-subdir) and canonical mode (ORCH_ROOT is .orchestrator/ itself).
- **`shadow_used="$model"` under kill switch (recommended populate-explicitly shape).** Picked the operator-friendly variant per the payload's recommended choice. Verifier asserts `model_used` matches runtime-default model literal directly.
- **Awk section-walker for min_tier nested under `model_routing:`.** Same pattern as P02's routing-table walker; `BEGIN { in_block = 0 }` + `/^model_routing:/ { in_block = 1; next }` + exit on next top-level key. Anchored exit on `^[a-zA-Z_]` to handle CamelCase / underscore top-level keys.
- **Floor-wins-conflict path uses `_di_tier_rank` numeric comparison.** Bash `[ "$a" -gt "$b" ]` requires both sides numeric; the helper maps symbolic tiers to ranks and returns -1 for unknown. Guard against -1 via `>=0` check before comparison.

## Patterns established

- **Override-resolution-before-routing-extraction shape.** The override block runs first, sets `shadow_override_source` + (conditionally) `shadow_routed`. Three post-block awk-extraction branches, mutually exclusive: `none` runs the full P02 routing+resolution awks; `plan_frontmatter`/`milestone_floor` runs only the resolution awk (since shadow_routed is already set); `disabled` skips both and uses `$model` for `shadow_used`.
- **Stderr-warning emission inside emitter body.** `printf '...' >&2` in the resolution block. Two distinct warning shapes: `model_routing_enabled=false: min_tier: <X> is inactive` (compound case) and `model_override=<X> overridden by min_tier=<Y> (floor wins)` (FR-14 conflict).
- **Per-pattern HEAD-vs-WT grep count comparison reuses P02 shape.** `p03-con3-closure.sh` is byte-similar to `p02-con3-closure.sh` — same 7 provider-prefix patterns, same tmp-file intermediaries, same SUMMARY: format.
- **Round-trip verifier shape: stage tmp_root/.orchestrator/config.yml + tmp_root/phases/, ORCHESTRATOR_ROOT=tmp_root, M030_SHADOW_MODE=1 + CLAUDECODE=1.** Inherited from T01's `p03-override-source-enum.sh`; reused verbatim across all three new T02 round-trip verifiers.

## Files

Modified:
- `scripts/dispatch/dispatch-interface.sh` — `_di_tier_rank` helper + override-resolution block + 2 shadow-on printf extensions

Created:
- `tools/verify/p03-sc7-kill-switch.sh`
- `tools/verify/p03-sc7a-compound.sh`
- `tools/verify/p03-min-tier-floor.sh`
- `tools/verify/p03-con3-closure.sh`
