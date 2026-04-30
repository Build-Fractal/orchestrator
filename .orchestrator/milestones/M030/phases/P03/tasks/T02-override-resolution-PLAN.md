---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M030"
name: "dispatch-interface.sh override-resolution path + override_source emit + CON-4/D-A5 compound"
depends_on: ["T01"]
---

## Prerequisites

- All T01 deliverables on disk and green (per `bash tools/verify/p03-additive-schema.sh && bash tools/verify/p03-override-source-enum.sh` — both exit 0 in pre-amendment-tolerant mode).
- Seven fixture files under `tests/fixtures/m030-p03/`:
  - plans/plan-with-frontmatter-override.md
  - plans/plan-mechanical-no-override.md
  - plans/plan-frontmatter-fast-vs-floor.md
  - configs/config-baseline.yml
  - configs/config-with-routing-disabled.yml
  - configs/config-with-min-tier-smart.yml
  - configs/config-with-killswitch-and-floor.yml
- tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt + payload.txt exist (T01).
- scripts/dispatch/dispatch-interface.sh exists in its post-P02 form: `_di_emit_dispatch_usage` body at lines ~185-392; shadow path at lines ~279-324; happy-path printf at line ~332; degradation printf at line ~364.
- scripts/dispatch/classify-task.sh exists (P01/T02).
- templates/model-routing.yml exists (P01/T03).

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. The post-P02 shape of `dispatch-interface.sh` was inspected at planning time (head -400 reads cleanly).

## Description

T02 is the high-risk core amendment. Four deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — extend `_di_emit_dispatch_usage` so that BEFORE the existing routing-table awk extraction (lines ~301-323), the override-resolution path runs and produces a single `(override_tier, override_source, override_used_default)` triple. The triple drives the new `override_source` field plus a conditional re-write of `shadow_routed` / `shadow_used`.

2. **`tools/verify/p03-sc7-kill-switch.sh`** — gates SC-7: kill-switch shadow-on dispatch records `override_source=disabled` AND `model_used` matches the runtime default channel (`${ORCH_MODEL:-}` or the `model:` field from `intensity-metadata.txt`).

3. **`tools/verify/p03-sc7a-compound.sh`** — gates SC-7a: compound kill-switch + min_tier shadow-on dispatch records `override_source=disabled` (NOT `milestone_floor`), `model_used` matches runtime default, AND stderr contains the line naming `min_tier: smart is inactive`.

4. **`tools/verify/p03-min-tier-floor.sh`** — gates the FR-12 floor path: with `min_tier: smart` AND no kill switch AND no plan override, mechanical-classified plan dispatches with `model_routed=smart` AND `override_source=milestone_floor`.

5. **`tools/verify/p03-con3-closure.sh`** — gates CON-3: zero new hardcoded model IDs introduced by the amendment. HEAD-vs-working-tree per-pattern grep count comparison (mirrors P02/T02's `p02-con3-closure.sh` shape).

T02 also re-runs T01's `p03-override-source-enum.sh` against the amended emitter to confirm the post-amendment branch fires correctly: Scenarios A-D produce exactly one `override_source` field with an enum-valid value; Scenario E remains zero-tokens.

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is two-block: an override-resolution block placed BEFORE the P02 routing-table awk extraction, and a printf-format-string extension that adds `,"override_source":"%s"` after `withheld_classes`.

**Block 1 — override-resolution (insert after line 291 `shadow_confidence=""`, before line 292 `if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then`):**

```bash
local shadow_override_source override_kill override_min_tier override_plan
shadow_override_source=""
override_kill=""
override_min_tier=""
override_plan=""
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
  # Override-resolution precedence chain (CON-4 / D-A5 / FR-11/12/13/14):
  #   1. Kill switch (model_routing_enabled: false at config root) supersedes
  #      everything. Records override_source=disabled. If min_tier is also set,
  #      emit a one-line stderr warning naming the bypassed value.
  #   2. Plan frontmatter `model_override:` second.
  #   3. Milestone floor `model_routing.min_tier:` third (only when not yet
  #      overridden by the plan; if both are present, floor wins per FR-14).
  #   4. Plain routed (the P02 awk extraction below) fourth — override_source=none.

  # Resolve the per-project config path. Standard pattern:
  #   ORCHESTRATOR_ROOT may itself be a milestone dir (round-trip fixtures),
  #   in which case the parent's parent contains .orchestrator/config.yml.
  #   Otherwise ORCH_ROOT/../config.yml is the canonical path.
  _di_config_yml=""
  if [ -f "$ORCH_ROOT/config.yml" ]; then
    _di_config_yml="$ORCH_ROOT/config.yml"
  elif [ -f "$ORCH_ROOT/../config.yml" ]; then
    _di_config_yml="$ORCH_ROOT/../config.yml"
  fi
  # Kill switch (top-level model_routing_enabled).
  if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
    override_kill="$(grep -E '^model_routing_enabled:' "$_di_config_yml" 2>/dev/null | head -n 1 | sed -E 's/^model_routing_enabled:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
  fi
  # Plan-frontmatter override (model_override at top level of plan frontmatter).
  if [ -n "${TASK_PLAN:-}" ] && [ -f "$TASK_PLAN" ]; then
    override_plan="$(grep -E '^model_override:' "$TASK_PLAN" 2>/dev/null | head -n 1 | sed -E 's/^model_override:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
  fi
  # Milestone floor (nested under model_routing: in config.yml).
  # Awk section-walker scoped to the model_routing: block; same pattern as P02.
  if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
    override_min_tier="$(awk '
      BEGIN { in_block = 0 }
      /^model_routing:/                 { in_block = 1; next }
      in_block && /^[a-z_]/             { exit }
      in_block && /^[[:space:]]+min_tier:/ {
        val = $2; gsub(/[",]/, "", val); print val; exit
      }
    ' "$_di_config_yml")"
  fi

  # Apply precedence. Kill switch first.
  if [ "$override_kill" = "false" ]; then
    shadow_override_source="disabled"
    # Compound case (CON-4 / D-A5): emit one-line stderr warning when min_tier
    # is also active. The warning names the bypassed value verbatim.
    if [ -n "$override_min_tier" ]; then
      printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
    fi
  elif [ -n "$override_plan" ]; then
    shadow_override_source="plan_frontmatter"
    shadow_routed="$override_plan"
    # Floor still wins if it raises above the plan override.
    if [ -n "$override_min_tier" ] && _di_tier_rank "$override_min_tier" -gt "$(_di_tier_rank "$override_plan")" ]; then
      shadow_override_source="milestone_floor"
      shadow_routed="$override_min_tier"
      printf 'model_override=%s overridden by min_tier=%s (floor wins)\n' "$override_plan" "$override_min_tier" >&2
    fi
  elif [ -n "$override_min_tier" ]; then
    shadow_override_source="milestone_floor"
    shadow_routed="$override_min_tier"
  else
    shadow_override_source="none"
  fi
fi
```

The above contains a syntax issue in the `_di_tier_rank` test — bash does not chain `_di_tier_rank "$x" -gt $(...)` directly. The actual implementation uses a numeric tier-rank helper:

```bash
# Helper: map symbolic tier to numeric rank (fast=0, balanced=1, smart=2).
# Higher rank = stricter floor. Returns rank on stdout; unknown tier returns -1.
_di_tier_rank() {
  case "$1" in
    fast) echo 0 ;;
    balanced) echo 1 ;;
    smart) echo 2 ;;
    *) echo -1 ;;
  esac
}
```

Defined as a top-level helper alongside `_di_rollup_savings_fields` (around line 142). The override-resolution block uses it via:

```bash
_plan_rank=$(_di_tier_rank "$override_plan")
_floor_rank=$(_di_tier_rank "$override_min_tier")
if [ "$_plan_rank" -ge 0 ] && [ "$_floor_rank" -ge 0 ] && [ "$_floor_rank" -gt "$_plan_rank" ]; then
  shadow_override_source="milestone_floor"
  shadow_routed="$override_min_tier"
  printf 'model_override=%s overridden by min_tier=%s (floor wins)\n' "$override_plan" "$override_min_tier" >&2
fi
```

**Block 2 — printf format-string extension.** The shadow-on happy-path printf at line ~332 adds one trailing field after `withheld_classes`:

```text
,"withheld_classes":"%s","override_source":"%s"
```

with the matching `"$shadow_override_source"` argument appended at the end of the args list. Same treatment for the shadow-on degradation printf at line ~364. The shadow-OFF printfs (lines ~346 and ~378) are UNCHANGED — they remain byte-identical to the pre-P03 form. SC-11 byte-equality is preserved because the shadow-off branches never see the new field.

**Important — `shadow_used` semantics under kill switch:** when `shadow_override_source=disabled`, the routing-table awk extraction is SKIPPED. `shadow_routed` becomes `""` (empty); `shadow_used` becomes `""` (empty). The pre-amendment shadow-on emit branches use `"$shadow_used"` for the JSON `model_used` field — under kill switch this is the empty string, which is the documented "runtime default" channel (the existing `"$model"` field at JSON key `model` carries the actual runtime-default ID). For SC-7 verification, the verifier asserts `jq -r '.model'` equals the `intensity-metadata.txt` model literal AND `jq -r '.model_used'` equals the empty string — together these prove the kill-switch was respected.

**Alternative (simpler) shape under kill switch:** instead of leaving `shadow_used` empty, populate it with the `${model}` runtime-default value so the JSONL record's `model_used` field is operator-friendly. This is an implementation choice the executor MAY take if it simplifies SC-7's verifier shape. The verifier assertion is: under kill switch, `model_used` MUST match the runtime default — whether by being empty (pointing back at `model`) or by being explicitly populated with the runtime default ID. Both shapes pass SC-7 as long as the verifier's assertion is matched to the chosen shape.

The recommended choice is **populate explicitly**: under kill switch, set `shadow_used="$model"` (the runtime-default channel value). This makes `jq -r '.model_used'` directly comparable to the runtime default and avoids the "empty string is documentation" subtlety.

### Override precedence chain (canonical reference)

```
1. KILL SWITCH (model_routing_enabled: false)
   -> override_source=disabled
   -> shadow_routed="" (or runtime-default tier name)
   -> shadow_used="$model" (runtime default)
   -> if min_tier also active: stderr warning "min_tier: <X> is inactive"

2. PLAN FRONTMATTER (model_override: <tier>)
   -> override_source=plan_frontmatter
   -> shadow_routed=<plan-override-value>
   -> shadow_used=<routing-table resolution.<tier>.claude-code>
   -> if min_tier raises above plan tier: bump to floor (case 3)

3. MILESTONE FLOOR (model_routing.min_tier: <tier>)
   -> override_source=milestone_floor
   -> shadow_routed=<floor-tier>
   -> shadow_used=<routing-table resolution.<tier>.claude-code>
   -> if reached via case 2 conflict: stderr warning naming both knobs

4. PLAIN ROUTED (default)
   -> override_source=none
   -> shadow_routed=<routing-table routing.<character>.claude-code>
   -> shadow_used=<routing-table resolution.<tier>.claude-code>
```

### CON-3 closure preservation

The override-resolution block introduces zero new provider model-ID literals. `override_plan` and `override_min_tier` are READ from external files (plan frontmatter and `.orchestrator/config.yml`). When a plan frontmatter declares `model_override: claude-haiku-4-5-20260101` (an operator-pinned snapshot), that string is read from the plan file — never embedded in `dispatch-interface.sh`. `p03-con3-closure.sh` confirms this via HEAD-vs-working-tree per-pattern grep count comparison.

### Append-only discipline preservation

The amendment uses the same `>> "$log_file"` redirection as the pre-P03 emitter. No `mv`, no `cp`, no temp-file-and-swap. The append-only invariant remains intact and is gated by the existing P02 `tools/verify/p02-append-only.sh`. T02 does NOT re-author the append-only verifier; it relies on the P02 deliverable continuing to pass under HEAD.

## Steps

1. **Confirm T01 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p03-additive-schema.sh
   bash tools/verify/p03-override-source-enum.sh
   ```

   Expected: both exit 0 (pre-amendment-tolerant). If either fails, T01 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** Same pattern as P02/T02 — `git show HEAD:scripts/dispatch/dispatch-interface.sh` is the baseline; no explicit file snapshot needed.

3. **Add the `_di_tier_rank` helper.** Insert after `_di_rollup_savings_fields` (around line 175):

   ```bash
   # M030/P03/T02: numeric tier-rank for floor comparison (fast<balanced<smart).
   _di_tier_rank() {
     case "$1" in
       fast) echo 0 ;;
       balanced) echo 1 ;;
       smart) echo 2 ;;
       *) echo -1 ;;
     esac
   }
   ```

4. **Insert the override-resolution block.** After the existing `shadow_confidence=""` declaration block (around line 291) and BEFORE the existing `if [ "${M030_SHADOW_MODE:-0}" = "1" ]` shadow-on branch (line 292), insert the full override-resolution block per the Description. Concretely:

   - Declare locals: `shadow_override_source override_kill override_min_tier override_plan _di_config_yml _plan_rank _floor_rank`.
   - Initialize all to empty.
   - Wrap the resolution logic in the same `if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then` gate so the path is shadow-on-only.
   - Resolve `_di_config_yml` (try `$ORCH_ROOT/config.yml`, fall back to `$ORCH_ROOT/../config.yml`).
   - Read `override_kill` via `grep -E '^model_routing_enabled:'` + sed.
   - Read `override_plan` via `grep -E '^model_override:'` + sed against `$TASK_PLAN`.
   - Read `override_min_tier` via the awk section-walker scoped to `model_routing:` block.
   - Apply precedence: kill switch first, plan-frontmatter second (with floor-wins-conflict check), milestone floor third, none fourth.
   - On kill-switch + min_tier compound: emit one-line stderr warning `model_routing_enabled=false: min_tier: <X> is inactive`.
   - On plan-vs-floor conflict: emit one-line stderr warning `model_override=<X> overridden by min_tier=<Y> (floor wins)`.

5. **Adjust the existing routing-table awk extraction.** The pre-amendment block (lines 301-324) computes `shadow_routed` from `templates/model-routing.yml routing.<character>.claude-code`. After T02, this block runs ONLY when `shadow_override_source` is `none` OR empty (i.e., no override fired). When override_source is `disabled`, the routing block is skipped entirely. When override_source is `plan_frontmatter` or `milestone_floor`, `shadow_routed` is already set by the override-resolution block; the routing block is skipped. When override_source is `none`, the routing block runs as in P02.

   Wrap the existing block in a guard:

   ```bash
   if [ -z "$shadow_override_source" ] || [ "$shadow_override_source" = "none" ]; then
     # Existing P02 routing-table awk extraction — unchanged.
     shadow_routed="$(awk -v ch="$_di_shadow_character" ' ... ')"
     shadow_used="$(awk -v tier="$shadow_routed" ' ... ')"
   fi
   ```

   For `plan_frontmatter` and `milestone_floor`, the override-resolution block sets `shadow_routed` directly. After the routing-block guard, run a SECOND awk extraction to populate `shadow_used` from the resolved tier, but ONLY when `shadow_override_source` is in {`plan_frontmatter`, `milestone_floor`}:

   ```bash
   if [ "$shadow_override_source" = "plan_frontmatter" ] || [ "$shadow_override_source" = "milestone_floor" ]; then
     shadow_used="$(awk -v tier="$shadow_routed" '
       BEGIN { in_resolution = 0; in_tier = 0 }
       /^resolution:/                    { in_resolution = 1; next }
       /^cost_rates:/                    { exit }
       in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
       in_resolution && in_tier && /^    claude-code:/ {
         val = $2; gsub(/[",]/, "", val); print val; exit
       }
     ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
   fi
   if [ "$shadow_override_source" = "disabled" ]; then
     shadow_routed=""
     shadow_used="$model"
   fi
   ```

6. **Extend the printf format strings.** Two shadow-ON printf invocations need the new field:

   - Line ~332 (happy-path shadow-on): append `,"override_source":"%s"` after `,"withheld_classes":"%s"` and append `"$shadow_override_source"` to the args list (after `"$shadow_withheld"`).
   - Line ~364 (degradation shadow-on): same treatment.

   The shadow-OFF printfs (lines ~346 and ~378) are UNCHANGED.

7. **Author `tools/verify/p03-sc7-kill-switch.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Round-trip dispatch shape (mirrors P02/T02 verifier shape):

   - Stage a tmp `ORCH_ROOT` whose `.orchestrator/config.yml` is `tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml`.
   - Stage a fresh log file under `$ORCH_ROOT/milestones/M999/execution-log.jsonl` (matches the fixture plan's `M999/P99/T99` UNIT_ID).
   - `export M030_SHADOW_MODE=1; export CLAUDECODE=1; export ORCHESTRATOR_ROOT="$ORCH_ROOT"`.
   - Invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md --payload tests/fixtures/m030-p03/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt --backend stub`.
   - Read the appended JSONL line via `tail -n 1 "$log_file" > /tmp/p03-sc7-line.txt`.
   - Assert `grep -q '"override_source":"disabled"' /tmp/p03-sc7-line.txt`.
   - Assert `model_used` field is empty OR matches the runtime default (read from `intensity-metadata.txt`'s `model:` field). Use grep+sed to extract the value; compare to the expected.
   - Cleanup: `rm -rf "$ORCH_ROOT" /tmp/p03-sc7-*.txt`.
   - Final `SUMMARY: p03-sc7-kill-switch.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

8. **Author `tools/verify/p03-sc7a-compound.sh`.** Bash 3.2-compatible. Same round-trip shape as Step 7, but config = `config-with-killswitch-and-floor.yml` AND stderr capture enabled:

   - Run the dispatch invocation with `2> /tmp/p03-sc7a-stderr.txt` to capture stderr.
   - Read the appended JSONL line.
   - Assert `grep -q '"override_source":"disabled"' /tmp/p03-sc7a-line.txt` (NOT `milestone_floor` — kill switch wins).
   - Assert `grep -q 'min_tier:.*smart.*is inactive' /tmp/p03-sc7a-stderr.txt` (the one-line warning).
   - Cleanup.
   - Final `SUMMARY: p03-sc7a-compound.sh pass=N fail=M`.

9. **Author `tools/verify/p03-min-tier-floor.sh`.** Bash 3.2-compatible. Same shape, config = `config-with-min-tier-smart.yml`, plan = `plan-mechanical-no-override.md`:

   - Independently re-run the classifier on the plan and assert `character=mechanical` (sanity check — the routing-table default for mechanical is `fast`, so the floor ACTUALLY raises the tier).
   - Run the dispatch invocation.
   - Read the appended JSONL line.
   - Assert `grep -q '"override_source":"milestone_floor"' /tmp/p03-min-tier-line.txt`.
   - Assert `grep -q '"model_routed":"smart"' /tmp/p03-min-tier-line.txt` (raised from `fast` to `smart` by the floor).
   - Final `SUMMARY: p03-min-tier-floor.sh pass=N fail=M`.

10. **Author `tools/verify/p03-con3-closure.sh`.** Bash 3.2-compatible. Mirrors P02/T02's `p02-con3-closure.sh` shape. For each pattern in {`claude-haiku-`, `claude-sonnet-`, `claude-opus-`, `gpt-`, `o1-`, `o3-`, `gemini-`}:

    - Count occurrences in HEAD: `git show HEAD:scripts/dispatch/dispatch-interface.sh > /tmp/p03-con3-head.txt; grep -c -E "<pattern>" /tmp/p03-con3-head.txt > /tmp/p03-con3-head-count-<n>.txt` (use a per-pattern numeric suffix to avoid filename collision).
    - Count in working tree: `grep -c -E "<pattern>" scripts/dispatch/dispatch-interface.sh > /tmp/p03-con3-wt-count-<n>.txt`.
    - Read both counts; assert working-tree count <= HEAD count.
    - Cleanup: `rm -f /tmp/p03-con3-*.txt`.
    - Final `SUMMARY: p03-con3-closure.sh pass=N fail=M`.

11. **Re-run T01's verifiers against the amended emitter.** Step 4-6 amendments are now on disk. Run:

    ```bash
    bash tools/verify/p03-additive-schema.sh
    bash tools/verify/p03-override-source-enum.sh
    ```

    Expected: both exit 0. `p03-additive-schema.sh` confirms shadow-off byte-equality holds (P02 SC-11 contract preserved). `p03-override-source-enum.sh` now fires the post-amendment branch for Scenarios A-D: A returns `none`, B returns `disabled`, C returns `plan_frontmatter`, D returns `milestone_floor`. Scenario E remains zero-tokens (shadow-off).

    If `p03-additive-schema.sh` fails, the shadow-off `printf` branch was accidentally modified — Step 6 must touch only the shadow-on branches.

    If `p03-override-source-enum.sh` fails on Scenario A, the `none` value is missing — the `else` branch in Step 4's precedence chain must explicitly set `shadow_override_source="none"`.

    If Scenario B fails, `override_kill` is not being read — check the `_di_config_yml` resolution (Step 4 first sub-step).

    If Scenario C fails, `override_plan` is not being read — check the grep against `$TASK_PLAN` (Step 4 third sub-step).

    If Scenario D fails, `override_min_tier` is not being read — check the awk section-walker (Step 4 fourth sub-step).

12. **Run all four T02 verifiers as a self-check:**

    ```bash
    bash tools/verify/p03-additive-schema.sh
    bash tools/verify/p03-override-source-enum.sh
    bash tools/verify/p03-sc7-kill-switch.sh
    bash tools/verify/p03-sc7a-compound.sh
    bash tools/verify/p03-min-tier-floor.sh
    bash tools/verify/p03-con3-closure.sh
    ```

    Expected: all six exit 0.

13. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `tools/verify/p03-sc7-kill-switch.sh`, `tools/verify/p03-sc7a-compound.sh`, `tools/verify/p03-min-tier-floor.sh`, `tools/verify/p03-con3-closure.sh`. Author commit message file via Write to /tmp/p03-t02-commit-msg.txt; commit with `git commit -F /tmp/p03-t02-commit-msg.txt`. Recommended subject: `M030/P03/T02: dispatch-interface override-resolution + kill-switch + min_tier floor + CON-4 compound`.

## Must-Haves

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh emits an override_source field on every shadow-on dispatch_usage record drawn from the closed enum..." — gated by `tools/verify/p03-override-source-enum.sh` (now firing the post-amendment branch).
- "SC-7 holds: with model_routing_enabled: false, a shadow-on dispatch records override_source=disabled..." — gated by `tools/verify/p03-sc7-kill-switch.sh`.
- "SC-7a (compound kill-switch + min_tier) holds..." — gated by `tools/verify/p03-sc7a-compound.sh`.
- "min_tier enforcement: when model_routing.min_tier: smart..." — gated by `tools/verify/p03-min-tier-floor.sh`.
- "The override-resolution path in dispatch-interface.sh introduces zero new hardcoded model IDs..." — gated by `tools/verify/p03-con3-closure.sh`.
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture..." — gated by `tools/verify/p03-additive-schema.sh` (re-run against amended emitter).

## Verification

```bash
bash tools/verify/p03-additive-schema.sh
bash tools/verify/p03-override-source-enum.sh
bash tools/verify/p03-sc7-kill-switch.sh
bash tools/verify/p03-sc7a-compound.sh
bash tools/verify/p03-min-tier-floor.sh
bash tools/verify/p03-con3-closure.sh
```

Each verifier uses single-script-file shape per AD-19. All six must exit 0 before T02 closes.

## Inputs

### From Previous Tasks

- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md (from T01) — Key API: plan with `model_override: smart` frontmatter + mechanical body. T02 verifiers do not use this plan directly (T03 does); T02 uses `plan-mechanical-no-override.md`.
- tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md (from T01) — Key API: plan with no override frontmatter + mechanical body signature. Classifier returns `character=mechanical, confidence=high`. Routing-table default for mechanical/claude-code is `fast`. The mechanical-no-override input is the load-bearing fixture for SC-7, SC-7a, and the min_tier floor test.
- tests/fixtures/m030-p03/configs/{config-baseline,config-with-routing-disabled,config-with-min-tier-smart,config-with-killswitch-and-floor}.yml (from T01) — Key API: `.orchestrator/config.yml`-shaped overlay configs. Each has at most two relevant keys: `model_routing_enabled:` (top-level boolean) and `model_routing.min_tier:` (nested string).
- tests/fixtures/m030-p03/round-trip-stage/{intensity-metadata.txt,payload.txt} (from T01) — Key API: standard intensity-metadata + payload pair for round-trip dispatch invocations.
- tools/verify/p03-additive-schema.sh (from T01) — Key API: pass-through wrapper over `tools/verify/p02-additive-schema.sh`. Continues to exit 0 against the post-T02 emitter as long as the shadow-off branch is byte-identical.
- tools/verify/p03-override-source-enum.sh (from T01) — Key API: pre-amendment-tolerant scenario harness. After T02's amendment lands, the verifier transitions from the "zero tokens vacuously PASS" branch to the "exactly one token, value enum-checked" branch automatically — no verifier code change needed.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form. T02 amends `_di_emit_dispatch_usage` body.
  - Key API: `_di_emit_dispatch_usage [warning_override]` writes one `dispatch_usage` record to `$log_file` per invocation. Function-internal access to `$TASK_PLAN`, `$PAYLOAD`, `$INTENSITY_METADATA`, `$BACKEND`, `$UNIT_ID`, `$MILESTONE_ID`, `$PHASE_ID`, `$TASK_ID`, `$ORCH_ROOT`, `$_DI_PROJECT_ROOT`. Pre-T02 the function emits 5 P02 fields under shadow-on (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`). Post-T02 it emits 6 fields (above + `override_source`).
- scripts/dispatch/classify-task.sh — P01 classifier. T02 verifiers indirectly exercise it via shadow-on dispatch.
  - Key API: `bash scripts/dispatch/classify-task.sh <plan-path>` writes `character=<m|s|n>` + `confidence=<h|m|l>` to stdout.
- templates/model-routing.yml — P01 routing-table SSOT.
  - Key API: YAML file with `routing:` (3 chars x 3 runtimes) + `resolution:` (3 tiers x 3 runtimes) + `cost_rates:` (3 tiers). T02's amendment reads `resolution:` for tier-to-model resolution under plan_frontmatter and milestone_floor cases.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip harness invocations.
- tools/verify/p02-additive-schema.sh — P02 SC-11 gate. T02 indirectly exercises it via the T01 `p03-additive-schema.sh` wrapper.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` already declares (line 184) that pipes / `awk` / `$()` are permitted in its body as a dispatch-internal carve-out. T02's amendment extends that carve-out — the new awk extraction blocks and grep+sed parsing are body-internal and are NOT subject to AD-19's outer-invocation shape rules.
- **AP-009 compound-chain-gt2 (verifier shape)**: the four T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt; head -1 < /tmp/<g>.txt`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **CON-2/FR-19/SC-11 (additive-only schema)**: the shadow-off `printf` format strings MUST be byte-identical to the pre-P03 form (which equals the pre-P02 form per the P02 invariant). T02's amendment touches ONLY the shadow-on branches (lines ~332 and ~364). Verified by `tools/verify/p03-additive-schema.sh` (delegating to P02).
- **CON-3 (symbolic-tier closure)**: zero new literal provider model IDs in `dispatch-interface.sh`. Plan-frontmatter `model_override:` values are READ from the plan file; milestone_floor values are READ from `.orchestrator/config.yml`. The awk extraction reads `templates/model-routing.yml` for tier-to-model resolution. Verified by `tools/verify/p03-con3-closure.sh`.
- **CON-4 / D-A5 (kill switch supersedes min_tier)**: the precedence chain MUST evaluate the kill switch FIRST. When both `model_routing_enabled: false` and `model_routing.min_tier:` are active, override_source MUST be `disabled` (NOT `milestone_floor`). The compound case emits a one-line stderr warning naming the bypassed `min_tier` value. Verified by `tools/verify/p03-sc7a-compound.sh`.
- **CON-6 (append-only shadow corpus)**: the new code path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. The P02 `tools/verify/p02-append-only.sh` continues to gate this property under HEAD; T02 does not re-author it.
- **CC-only launch posture**: shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. The override-resolution block is wrapped in the same gate as the existing P02 routing-block — Codex CLI / Cursor short-circuit to the pre-P03 emit (which is the pre-P02 emit, via P02's CC-only gate).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended. The `_di_tier_rank` helper uses `case` (POSIX-safe).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.

## Expected Output

- scripts/dispatch/dispatch-interface.sh — amended `_di_emit_dispatch_usage` body with `_di_tier_rank` helper + override-resolution block (kill switch → plan-frontmatter → milestone-floor → none precedence chain) + extended shadow-on printf format strings (one new field `,"override_source":"%s"` after `withheld_classes`). Shadow-off printf branches unchanged.
- tools/verify/p03-sc7-kill-switch.sh — green: kill-switch shadow-on dispatch records override_source=disabled + model_used=runtime-default.
- tools/verify/p03-sc7a-compound.sh — green: compound case records override_source=disabled (NOT milestone_floor) + stderr contains `min_tier:.*smart.*is inactive`.
- tools/verify/p03-min-tier-floor.sh — green: floor raises mechanical/fast → smart, override_source=milestone_floor.
- tools/verify/p03-con3-closure.sh — green: zero new provider-model-ID literals.
- bash tools/verify/p03-additive-schema.sh exits 0 with `SUMMARY: p03-additive-schema.sh pass=1 fail=0`.
- bash tools/verify/p03-override-source-enum.sh exits 0 with `SUMMARY: p03-override-source-enum.sh pass=5 fail=0` (post-amendment branch fires for Scenarios A-D).
- bash tools/verify/p03-sc7-kill-switch.sh exits 0 with `SUMMARY: p03-sc7-kill-switch.sh pass=2 fail=0` (override_source value + model_used value).
- bash tools/verify/p03-sc7a-compound.sh exits 0 with `SUMMARY: p03-sc7a-compound.sh pass=3 fail=0` (override_source + model_used + stderr warning).
- bash tools/verify/p03-min-tier-floor.sh exits 0 with `SUMMARY: p03-min-tier-floor.sh pass=3 fail=0` (override_source + model_routed + classifier sanity).
- bash tools/verify/p03-con3-closure.sh exits 0 with `SUMMARY: p03-con3-closure.sh pass=7 fail=0` (7 patterns, all working-tree count <= HEAD count).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p03-sc7-kill-switch.sh` -> 2 assertions pass; `SUMMARY: p03-sc7-kill-switch.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p03-sc7a-compound.sh` -> 3 assertions pass; `SUMMARY: p03-sc7a-compound.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p03-min-tier-floor.sh` -> 3 assertions pass; `SUMMARY: p03-min-tier-floor.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p03-con3-closure.sh` -> 7 patterns checked; `SUMMARY: p03-con3-closure.sh pass=7 fail=0`, exit 0.

The override-resolution block is intentionally inline in `dispatch-interface.sh` rather than factored out to a helper because the function is already past the line count where pure-lib extraction (MEM004 pattern) pays off, and the precedence chain is shallow enough (4 cases) that an inline block remains auditable. If T03 grows the chain (e.g., adds a `resolution_override:` config-side knob per the references doc), P05 should consider extracting `_di_resolve_overrides()` into `scripts/dispatch/lib/override-resolve.sh` and sourcing it. T02 keeps the logic inline to minimize the amendment surface.

The kill-switch + min_tier compound case (CON-4 / D-A5) is the only branch that emits a stderr warning. The plan-frontmatter + min_tier conflict case (FR-14) ALSO emits a stderr warning naming both knobs — operators who hit either case see the conflict mid-run rather than discovering it post-hoc by reading JSONL.

When T03's `p03-override-conflict.sh` runs after T02 ships, it will exercise the FR-14 conflict path and assert the stderr warning fires correctly. T02 ships the warning-emit code; T03 verifies it.

The `shadow_used` semantics under kill switch are documented above. The recommended shape is `shadow_used="$model"` (explicit population with the runtime-default channel value). If the executor chooses the alternative (leave `shadow_used` empty), the SC-7 verifier (Step 7) must be matched accordingly — assert `model_used` is empty rather than equal to the runtime default ID.

If the awk YAML extraction or the grep+sed config parsing proves brittle (e.g., the `.orchestrator/config.yml` syntax shifts in a future edit), the fallback shape is: source `scripts/util/json-field.sh` and adopt a YAML-to-JSON converter. T02 explicitly does NOT introduce that dependency — the awk + grep+sed approach is sufficient for the current YAML structure.
