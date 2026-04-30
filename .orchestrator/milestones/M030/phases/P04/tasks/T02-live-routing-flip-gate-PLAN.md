---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M030"
name: "dispatch-interface live-routing branch + programmatic flip-gate + partial-flip + --model passing"
depends_on: ["T01"]
---

## Prerequisites

- All T01 deliverables on disk and green:
  - `bash tools/verify/p04-additive-schema.sh` exits 0 (T01)
  - `bash tools/verify/p04-override-source-enum-extended.sh` exits 0 in pre-amendment-tolerant mode (T01)
- Five fixture plans under `tests/fixtures/m030-p04/plans/`:
  - plan-mechanical-no-override.md (T99)
  - plan-fail-twice-then-pass.md (T97) — used by T03 verifiers, not T02
  - plan-fail-three-times.md (T96) — used by T03 verifiers
  - plan-fail-four-times.md (T96) — used by T03 verifiers
  - plan-novel-class.md (T95) — used by T02 partial-flip verifier
- Three fixture configs under `tests/fixtures/m030-p04/configs/`:
  - config-with-live-true.yml
  - config-with-live-and-killswitch.yml
  - config-with-live-false.yml
- Three shadow corpora at `tests/fixtures/m030-p04/shadow-corpus-{ready,partially-ready,empty}.jsonl`.
- Round-trip stage at `tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt` + `payload.txt`.
- Two stub adapters at `scripts/dispatch/adapters/backend/{stub-fail-n.sh,stub-record-model.sh}` — T02 uses `stub-record-model.sh` for SC-3; `stub-fail-n.sh` is unused in T02 (T03 deliverable).
- scripts/dispatch/dispatch-interface.sh exists in its post-P03 form: `_di_emit_dispatch_usage` body (lines ~190-515); shadow path with override-resolution block (lines ~292-446); happy-path shadow-on printf at ~line 453; degradation shadow-on printf at ~line 486; adapter invocation at ~line 586-589 passing 3 flags.
- scripts/diagnostics/shadow-compare.sh exists with `--corpus <path>` flag and emits `flip_recommendation=` line on stdout.

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. The post-P03 shape of `dispatch-interface.sh` was inspected at planning time; the override-resolution block at lines 292-446 contains the precedence chain that T02's live branch slots into.

## Description

T02 is the high-risk core amendment, part 1 of 2. Five deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — extend `_di_emit_dispatch_usage` with a live-routing branch that reads `model_routing.live: true` from `.orchestrator/config.yml`, programmatically invokes `bash scripts/diagnostics/shadow-compare.sh --corpus <corpus>`, branches on the verdict, and conditionally passes `--model <id>` to the backend adapter via the existing adapter-invocation path. Also amends the kill-switch path to additionally short-circuit live mode.

2. **`tools/verify/p04-sc2a-shadow-gate-block.sh`** — gates SC-2a: with `live: true` AND empty corpus, dispatch-interface refuses to call any adapter, exits nonzero, and writes `override_source=shadow_gate_blocked`.

3. **`tools/verify/p04-sc3-live-mechanical.sh`** — gates SC-3: with `live: true` AND ready corpus, dispatching mechanical plan against `stub-record-model.sh` records `model_used=<resolution.fast.claude-code>` AND the stub's record-file contains the same value (proving `--model <id>` was passed correctly).

4. **`tools/verify/p04-partial-flip-routing.sh`** — gates D-A3: with `live: true` AND partially_ready corpus, dispatching a withheld-class task records `partial_flip_active=true` + `withheld_classes=novel` + `model_used=runtime-default`. Dispatching a flippable-class task records the live-routed `model_used` value.

5. **`tools/verify/p04-con3-live-closure.sh`** — gates CON-3: zero new hardcoded model IDs introduced by the live-routing amendment. HEAD-vs-working-tree per-pattern grep count comparison.

6. **`tools/verify/p04-con4-live-killswitch.sh`** — gates CON-4 / SC-7a-style compound: with `model_routing_enabled: false` AND `model_routing.live: true`, dispatching records `override_source=disabled` (NOT `shadow_gate_blocked`), shadow-compare.sh is NEVER invoked, and stderr contains a one-line bypass warning naming `live: true is inactive`.

T02 also re-runs T01's tolerant gates against the amended emitter to confirm the post-amendment branch fires: `p04-override-source-enum-extended.sh` Scenario F now strict-asserts `shadow_gate_blocked`; `p04-additive-schema.sh` continues to pass (shadow-off byte-equality preserved).

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is THREE-block: (a) read the `live:` knob from config, (b) extend the kill-switch path with a live-mode bypass warning, (c) insert a live-mode branch BEFORE the existing `if [ "$shadow_override_source" = "none" ]` routing-table awk extraction (currently at line ~404). The adapter invocation at line ~586-589 also gains a conditional `--model <id>` flag.

**Block A — read `live:` from config.** Insert into the override-resolution block, alongside the existing `override_min_tier` read (around line ~360). Add a new local `override_live` and read it via a similar awk section-walker scoped to the `model_routing:` block:

```bash
local override_live
override_live=""
if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
  override_live="$(awk '
    BEGIN { in_block = 0 }
    /^model_routing:/                 { in_block = 1; next }
    in_block && /^[a-zA-Z_]/          { exit }
    in_block && /^[[:space:]]+live:/  {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
  ' "$_di_config_yml")"
fi
```

Place this read after the `override_min_tier` read (currently line ~360-369). The new local should be declared in the locals block at line ~306-307 alongside `shadow_override_source override_kill override_min_tier override_plan`.

**Block B — extend kill-switch path with live-bypass warning.** Currently at line ~372-378 (inside the kill-switch precedence branch):

```bash
if [ "$override_kill" = "false" ]; then
  shadow_override_source="disabled"
  if [ -n "$override_min_tier" ]; then
    printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
  fi
fi
```

T02 amends this branch to additionally emit a `live: true is inactive` warning when both kill-switch AND live are active:

```bash
if [ "$override_kill" = "false" ]; then
  shadow_override_source="disabled"
  if [ -n "$override_min_tier" ]; then
    printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
  fi
  if [ "$override_live" = "true" ]; then
    printf 'model_routing_enabled=false: live: true is inactive\n' >&2
  fi
elif [ -n "$override_plan" ]; then
  ...
```

This preserves CON-4 / D-A5: kill switch wins; the live branch never engages when kill switch is active.

**Block C — insert live-mode branch BEFORE the routing-table awk extraction.** The existing block at line ~404-446 runs the routing-table awk extraction when `shadow_override_source = none`. T02 inserts a live-mode branch INSIDE the `if [ "$shadow_override_source" = "none" ]` block, BEFORE the awk extraction, so the live-mode logic runs only when no override fired AND the live knob is true.

```bash
if [ "$shadow_override_source" = "none" ]; then
  # M030/P04/T02: live-routing branch.
  # Programmatic flip-gate: when live=true, invoke shadow-compare and gate
  # on the verdict before any adapter call (FR-9 / D-A2).
  if [ "$override_live" = "true" ]; then
    # Resolve the corpus path: explicit env-var override (verifier seam) or
    # default to the in-flight log_file. The env var allows fixture-corpus
    # injection without polluting the live log.
    _di_compare_corpus="${M030_SHADOW_COMPARE_CORPUS:-$log_file}"
    _di_compare_tmp="$(mktemp 2>/dev/null || printf '/tmp/p04_compare_%d' "$$")"
    bash "$_DI_PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh" --corpus "$_di_compare_corpus" > "$_di_compare_tmp" 2>/dev/null || true
    _di_verdict="$(grep -E '^flip_recommendation=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^flip_recommendation=([^[:space:]]+).*/\1/')"
    _di_withheld_line="$(grep -E '^withheld_classes=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^withheld_classes=//')"
    rm -f "$_di_compare_tmp" 2>/dev/null

    if [ "$_di_verdict" = "evidence_insufficient" ] || [ "$_di_verdict" = "block" ]; then
      shadow_override_source="shadow_gate_blocked"
      shadow_routed=""
      shadow_used="$model"
      shadow_partial="false"
      shadow_withheld=""
      # Set a sentinel for the top-level block-gate check (see Step 5).
      _DI_LIVE_GATE_BLOCKED=1
    elif [ "$_di_verdict" = "ready" ]; then
      # All classes flippable. Resolve routed tier + model ID via routing.yml.
      shadow_routed="$(awk -v ch="$_di_shadow_character" '
        BEGIN { in_routing = 0; in_class = 0 }
        /^routing:/                       { in_routing = 1; next }
        /^resolution:/                    { exit }
        in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
        in_routing && in_class && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      shadow_used="$(awk -v tier="$shadow_routed" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      shadow_partial="false"
      shadow_withheld=""
      _DI_LIVE_MODEL_FLAG="$shadow_used"
    elif [ "$_di_verdict" = "partially_ready" ]; then
      # Per-class authorization: flip only when the task's class is NOT in
      # withheld_classes. Otherwise: route to runtime default + record
      # partial_flip_active=true + withheld_classes=<list>.
      shadow_partial="true"
      shadow_withheld="$_di_withheld_line"
      # Check whether the task's class is withheld.
      _di_is_withheld=0
      _di_w="$_di_withheld_line"
      while [ -n "$_di_w" ]; do
        _di_w_first="${_di_w%%,*}"
        if [ "$_di_w_first" = "$_di_shadow_character" ]; then
          _di_is_withheld=1
          break
        fi
        case "$_di_w" in
          *,*) _di_w="${_di_w#*,}" ;;
          *) _di_w="" ;;
        esac
      done
      if [ "$_di_is_withheld" -eq 1 ]; then
        # Withheld class: fall back to runtime default; do NOT pass --model.
        shadow_routed=""
        shadow_used="$model"
        # _DI_LIVE_MODEL_FLAG remains unset.
      else
        # Flippable class: resolve and route live.
        shadow_routed="$(awk -v ch="$_di_shadow_character" '
          BEGIN { in_routing = 0; in_class = 0 }
          /^routing:/                       { in_routing = 1; next }
          /^resolution:/                    { exit }
          in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
          in_routing && in_class && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        shadow_used="$(awk -v tier="$shadow_routed" '
          BEGIN { in_resolution = 0; in_tier = 0 }
          /^resolution:/                    { in_resolution = 1; next }
          /^cost_rates:/                    { exit }
          in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
          in_resolution && in_tier && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        _DI_LIVE_MODEL_FLAG="$shadow_used"
      fi
    fi
  fi

  # Existing shadow-mode awk extraction (preserved when live=false / unset).
  if [ -z "$shadow_routed" ] && [ "$shadow_override_source" = "none" ]; then
    # Original P02 path — only fires when live mode did not set shadow_routed.
    shadow_routed="$(awk -v ch="$_di_shadow_character" ' ... ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    shadow_used="$(awk -v tier="$shadow_routed" ' ... ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  fi
fi
```

**The `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` shell variables** are set by the emitter and read by the dispatcher at line ~586-589 (the adapter invocation point) and at the top-level adapter-call gate. They are NOT JSONL fields — they are in-process state passed from the emit-time logic to the dispatch-time logic.

**Block D — extend the adapter invocation with conditional --model flag.** Current code at line ~586-589:

```bash
adapter_output="$(bash "$ADAPTER" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
```

T02 amends to:

```bash
if [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
  adapter_output="$(bash "$ADAPTER" \
    --task-plan "$TASK_PLAN" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_METADATA" \
    --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?
else
  adapter_output="$(bash "$ADAPTER" \
    --task-plan "$TASK_PLAN" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
fi
```

**Block E — top-level shadow-gate-blocked branch.** BEFORE the adapter invocation at line ~586, T02 inserts a check on `_DI_LIVE_GATE_BLOCKED`. If the sentinel is set, the dispatcher MUST refuse to call the adapter, MUST emit the `dispatch_usage` record (which carries `override_source=shadow_gate_blocked`), MUST emit a `dispatch-error.md` document on stderr, and MUST exit nonzero. The challenge: the `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` are set INSIDE `_di_emit_dispatch_usage`, which is called AFTER the adapter at line ~620 (happy-path) or ~596 (adapter-failed). The current ordering does not work: the gate must run BEFORE the adapter.

**Resolution: extract the live-mode resolution into a separate helper called BEFORE the adapter invocation.** Add a new helper `_di_resolve_live_routing` that runs the override-resolution + live-mode + flip-gate logic, sets the shell-scoped sentinels, and returns. This helper is called once before line ~585 (the adapter invocation block); `_di_emit_dispatch_usage` is then called as before, but it consumes pre-resolved values from the shell-scoped variables instead of re-computing them.

The cleanest factoring:

1. Move the override-resolution block + live-mode branch out of `_di_emit_dispatch_usage` and into a new helper `_di_resolve_live_routing` defined alongside it (around line 188).
2. The helper sets shell-scoped variables: `shadow_override_source`, `shadow_routed`, `shadow_used`, `shadow_partial`, `shadow_withheld`, `_DI_LIVE_MODEL_FLAG`, `_DI_LIVE_GATE_BLOCKED`.
3. Call the helper at line ~580 (before adapter resolution but after `BACKEND` is resolved).
4. At line ~585, check `_DI_LIVE_GATE_BLOCKED`; if set, skip adapter invocation, emit error+JSONL, exit nonzero.
5. At line ~586, pass `--model "$_DI_LIVE_MODEL_FLAG"` (when set) to the adapter.
6. `_di_emit_dispatch_usage` reads the shell-scoped variables instead of re-computing them. The override-resolution block inside the function becomes a guard ("if these are already set, skip recomputation").

Alternative (simpler) factoring per MEM004 carve-out: keep the resolution inside `_di_emit_dispatch_usage`, but have the dispatcher call `_di_emit_dispatch_usage --resolve-only` first (a new flag that runs the resolution and sets shell-scoped sentinels but does NOT emit the JSONL record), then check the sentinels, then either skip-adapter-and-emit-record or proceed-and-emit-record-after.

The recommended choice is **option 1 (extract `_di_resolve_live_routing`)** because it cleanly separates resolution from emission and matches MEM004's pure-lib-extraction pattern. The override-resolution + live-mode branch becomes a single helper; the printf branches in `_di_emit_dispatch_usage` continue to read the same shell-scoped variables they already read.

If executor finds extraction too heavy, the alternative (option 2) is acceptable as long as the sentinel-then-gate flow is mechanically observable: `_DI_LIVE_GATE_BLOCKED` is set BEFORE the adapter is invoked, and the adapter is NOT invoked when the sentinel is set.

### Block F — emit JSONL record on shadow-gate-blocked path

When `_DI_LIVE_GATE_BLOCKED=1`, T02 emits the `dispatch_usage` record with `override_source=shadow_gate_blocked` (other shadow fields populated as documented above). The emit happens at the existing `_di_emit_dispatch_usage` call site, but with the resolution already pre-computed. The dispatcher's top-level flow on shadow_gate_blocked:

1. `_di_resolve_live_routing` sets `_DI_LIVE_GATE_BLOCKED=1` + `shadow_override_source=shadow_gate_blocked`.
2. The dispatcher checks the sentinel before adapter invocation.
3. If set: `_di_emit_dispatch_usage ""` (empty warning override; dispatch_usage record carries the shadow_gate_blocked source), then emit a synthesized `dispatch-error.md` on stderr (`error_type=shadow_gate_blocked`, `retry_eligible=true`, `escalation=operator`), then exit 7 (new exit code; or reuse 5 if simpler).
4. If not set: proceed to adapter invocation as before.

### Verifier shapes (load-bearing detail)

**`tools/verify/p04-sc2a-shadow-gate-block.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/p04-sc2a-shadow-gate-block.sh — M030/P04 SC-2a shadow-gate-blocked.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
EMPTY_CORPUS="$FIXTURES/shadow-corpus-empty.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0; fail=0

# Stage tmp_root.
TMP_ROOT="$(mktemp -d 2>/dev/null)"
[ -n "$TMP_ROOT" ] || { TMP_ROOT="/tmp/p04-sc2a-$$"; mkdir -p "$TMP_ROOT"; }
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml"
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$EMPTY_CORPUS"

DISPATCH_OUT_TMP="/tmp/p04-sc2a-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc2a-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# Assertion 1: dispatch-interface exits nonzero.
if [ "$DISPATCH_RC" -ne 0 ]; then
  pass=$((pass+1))
  printf 'PASS: dispatch-interface exits nonzero (rc=%d)\n' "$DISPATCH_RC"
else
  fail=$((fail+1))
  printf 'FAIL: dispatch-interface exited 0; expected nonzero on shadow-gate-block\n'
fi

# Assertion 2: appended JSONL line carries override_source=shadow_gate_blocked.
LINE_TMP="/tmp/p04-sc2a-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
SGB_TMP="/tmp/p04-sc2a-sgb.txt"
rm -f "$SGB_TMP" 2>/dev/null
grep -F '"override_source":"shadow_gate_blocked"' "$LINE_TMP" > "$SGB_TMP" 2>/dev/null
SGB_LC_TMP="/tmp/p04-sc2a-sgblc.txt"
wc -l < "$SGB_TMP" > "$SGB_LC_TMP" 2>/dev/null
SGB_LC="$(tr -d '[:space:]' < "$SGB_LC_TMP")"
[ -n "$SGB_LC" ] || SGB_LC=0
if [ "$SGB_LC" -ge 1 ]; then
  pass=$((pass+1))
  printf 'PASS: override_source=shadow_gate_blocked recorded\n'
else
  fail=$((fail+1))
  printf 'FAIL: override_source=shadow_gate_blocked token missing\n'
fi

# Assertion 3: dispatch-result NOT emitted on stdout (adapter never invoked).
DRT_TMP="/tmp/p04-sc2a-drt.txt"
grep -F 'type: "dispatch-result"' "$DISPATCH_OUT_TMP" > "$DRT_TMP" 2>/dev/null
DRT_LC_TMP="/tmp/p04-sc2a-drtlc.txt"
wc -l < "$DRT_TMP" > "$DRT_LC_TMP" 2>/dev/null
DRT_LC="$(tr -d '[:space:]' < "$DRT_LC_TMP")"
[ -n "$DRT_LC" ] || DRT_LC=0
if [ "$DRT_LC" -eq 0 ]; then
  pass=$((pass+1))
  printf 'PASS: no dispatch-result emitted (adapter not invoked)\n'
else
  fail=$((fail+1))
  printf 'FAIL: dispatch-result was emitted; adapter was invoked despite gate\n'
fi

# Cleanup.
rm -f "$LINE_TMP" "$SGB_TMP" "$SGB_LC_TMP" "$DRT_TMP" "$DRT_LC_TMP" "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p04-sc2a-shadow-gate-block.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0
exit 1
```

**`tools/verify/p04-sc3-live-mechanical.sh`**: same staging shape but `EMPTY_CORPUS` becomes `READY_CORPUS=tests/fixtures/m030-p04/shadow-corpus-ready.jsonl`, backend becomes `stub-record-model`, and assertions are:

1. `jq -r '.model_used'` from the JSONL record equals the runtime-extracted `resolution.fast.claude-code` value (extracted via the same awk section-walker dispatch-interface uses; CON-3-clean).
2. The contents of `STUB_RECORD_MODEL_FILE` equal that same value (proves `--model <id>` was passed).
3. dispatch-interface exits 0 (live-routed dispatch succeeded).

**`tools/verify/p04-partial-flip-routing.sh`**: stage TWO round-trip dispatches (mechanical-class plan AND novel-class plan) against the partially_ready corpus. Assert:

1. Mechanical-class dispatch: `model_used=<resolution.fast.claude-code>` (live-routed; mechanical is flippable per partially_ready/withheld=novel) AND `partial_flip_active=true` AND `withheld_classes=novel`.
2. Novel-class dispatch: `model_used=<runtime-default>` (NOT routing-table-resolved; novel is withheld) AND `partial_flip_active=true` AND `withheld_classes=novel`.

**`tools/verify/p04-con3-live-closure.sh`**: same shape as `p03-con3-closure.sh`. For each pattern in `{claude-haiku-, claude-sonnet-, claude-opus-, gpt-, o1-, o3-, gemini-}`: count occurrences in `git show HEAD:scripts/dispatch/dispatch-interface.sh` and in working-tree; assert working-tree count <= HEAD count.

**`tools/verify/p04-con4-live-killswitch.sh`**: stage `config-with-live-and-killswitch.yml`. Assert:

1. JSONL record carries `override_source=disabled` (NOT `shadow_gate_blocked`).
2. `model_used` matches runtime default (the `model:` field from `intensity-metadata.txt`).
3. Stderr contains the line `model_routing_enabled=false: live: true is inactive`.
4. Stderr also contains `min_tier:.*is inactive` (since the fixture also sets min_tier).
5. Side-channel: no `MOCK_SHADOW_COMPARE_INVOKED_TOUCH` file is touched (the verifier does NOT need to mock shadow-compare; it relies on the kill-switch path executing BEFORE the live-mode block runs, so shadow-compare is structurally never invoked. The "MOCK_SHADOW_COMPARE_INVOKED_TOUCH" check is strictly a documentation aid in the truth statement; the actual assertion is via the JSONL record value + stderr capture).

## Steps

1. **Confirm T01 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p04-additive-schema.sh
   bash tools/verify/p04-override-source-enum-extended.sh
   ```

   Expected: both exit 0 (pre-amendment-tolerant). If either fails, T01 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** No explicit file snapshot needed — `git show HEAD:scripts/dispatch/dispatch-interface.sh` is the baseline (mirrors P02/T02 + P03/T02 pattern).

3. **Amend `_di_emit_dispatch_usage` (or extract `_di_resolve_live_routing`) per the Description.** Concretely:

   a. Add `local override_live` to the locals block at line ~306-307.
   b. After the `override_min_tier` awk extraction (line ~360-369), add the `override_live` awk extraction (Block A in the Description).
   c. Inside the kill-switch precedence branch (line ~372-378), append the `live: true is inactive` warning emission when `override_live=true` (Block B).
   d. Inside the `if [ "$shadow_override_source" = "none" ]` block (line ~404), insert the live-mode branch BEFORE the existing routing-table awk extraction (Block C).
   e. Add top-level shell-scoped sentinels `_DI_LIVE_MODEL_FLAG` and `_DI_LIVE_GATE_BLOCKED` (declared as `local` if inside the function, OR top-level via `: "${_DI_LIVE_MODEL_FLAG:=}"` if extracted to a separate helper).

4. **(Recommended) Extract `_di_resolve_live_routing` as a top-level helper** alongside `_di_tier_rank` (around line 175). The helper takes no arguments; reads/writes shell-scoped variables (`TASK_PLAN`, `ORCH_ROOT`, `_DI_PROJECT_ROOT`, etc.); leaves `shadow_override_source`, `shadow_routed`, `shadow_used`, `shadow_partial`, `shadow_withheld`, `_DI_LIVE_MODEL_FLAG`, `_DI_LIVE_GATE_BLOCKED` set in the caller's scope. Call the helper from BOTH (a) inside `_di_emit_dispatch_usage` (preserves the existing emit-time computation as a fallback when called outside the live flow), AND (b) from the dispatcher at line ~580 BEFORE adapter invocation. Idempotent: a second call on the same dispatch is a no-op.

   Alternative if extraction proves too disruptive: keep all logic inside `_di_emit_dispatch_usage` AND add a dispatcher-side check that re-reads the same `.orchestrator/config.yml` and shadow-compare verdict to derive the `_DI_LIVE_GATE_BLOCKED` sentinel. The duplication is acceptable as long as the dispatcher-side check uses the same code path the emitter uses.

5. **Insert top-level shadow-gate-blocked branch BEFORE adapter invocation.** At line ~585 (just before the adapter invocation), add:

   ```bash
   # M030/P04/T02: shadow-gate-blocked refuses adapter invocation.
   if [ "${_DI_LIVE_GATE_BLOCKED:-0}" = "1" ]; then
     emit_error "shadow_gate_blocked" "true" "operator" "${BACKEND}" \
       "Live routing requested but shadow corpus did not pass flip-readiness check" \
       "Shadow-compare verdict: evidence_insufficient or block" \
       "Either populate the shadow corpus to >=50 records per class with stable confidence, set model_routing.live: false, or set model_routing_enabled: false to bypass routing entirely."
     # Still emit the dispatch_usage record so the gate-block is observable in JSONL.
     _di_emit_dispatch_usage "" || true
     exit 7
   fi
   ```

   Choose exit code 7 (new) to disambiguate from `adapter-failed=5` and `adapter-malformed=6`.

6. **Amend the adapter invocation at line ~586-589** to conditionally append `--model <id>` when `_DI_LIVE_MODEL_FLAG` is set (Block D).

7. **Author `tools/verify/p04-sc2a-shadow-gate-block.sh`** per the shape in the Description. Mark executable.

8. **Author `tools/verify/p04-sc3-live-mechanical.sh`** per the shape in the Description. Key implementation detail: the verifier extracts the expected `resolution.fast.claude-code` literal at runtime via:

   ```bash
   EXPECTED_FAST_TMP="/tmp/p04-sc3-expected.txt"
   awk '
     BEGIN { in_resolution = 0; in_tier = 0 }
     /^resolution:/                    { in_resolution = 1; next }
     /^cost_rates:/                    { exit }
     in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == "fast:") ? 1 : 0; next }
     in_resolution && in_tier && /^    claude-code:/ {
       val = $2; gsub(/[",]/, "", val); print val; exit
     }
   ' "$REPO_ROOT/templates/model-routing.yml" > "$EXPECTED_FAST_TMP"
   EXPECTED_FAST="$(head -n 1 "$EXPECTED_FAST_TMP")"
   rm -f "$EXPECTED_FAST_TMP"
   ```

   Then assert (a) the appended JSONL `model_used` field equals `$EXPECTED_FAST`, (b) the stub-record-model output file equals `$EXPECTED_FAST`. CON-3-clean: no hardcoded `claude-haiku-4-5` in the verifier.

9. **Author `tools/verify/p04-partial-flip-routing.sh`** per the shape in the Description. Stages TWO dispatches (mechanical + novel) against the partially_ready corpus. Two-stage script: each stage is a self-contained tmp_root + dispatch + assertion block.

10. **Author `tools/verify/p04-con3-live-closure.sh`** mirroring `p03-con3-closure.sh`. Seven patterns; per-pattern grep + count + assertion; `SUMMARY:` line at end.

11. **Author `tools/verify/p04-con4-live-killswitch.sh`** per the shape in the Description. Stage `config-with-live-and-killswitch.yml`. Capture stderr to a tmp file. Assert:
    - JSONL `override_source=disabled`.
    - JSONL `model_used` equals runtime default (the `model:` field from `intensity-metadata.txt`).
    - Stderr file contains `live: true is inactive` substring.
    - Stderr file contains `min_tier.*is inactive` substring.

12. **Re-run T01's tolerant verifiers against the amended emitter:**

    ```bash
    bash tools/verify/p04-additive-schema.sh
    bash tools/verify/p04-override-source-enum-extended.sh
    ```

    Expected: both exit 0. `p04-additive-schema.sh` confirms shadow-off byte-equality holds (P02 SC-11 contract preserved). `p04-override-source-enum-extended.sh` Scenario F now strict-asserts `shadow_gate_blocked` (the post-amendment branch fires).

    If `p04-additive-schema.sh` fails, the shadow-off `printf` branch was accidentally modified — revisit Step 3-6 and ensure ONLY the shadow-on branches were touched. The shadow-off lines ~468 + ~501 must be byte-identical to pre-T02.

    If `p04-override-source-enum-extended.sh` fails on Scenario F, the `_DI_LIVE_GATE_BLOCKED` path is not setting `shadow_override_source=shadow_gate_blocked` correctly — recheck the verdict-branching logic.

13. **Run all five new T02 verifiers as a self-check:**

    ```bash
    bash tools/verify/p04-sc2a-shadow-gate-block.sh
    bash tools/verify/p04-sc3-live-mechanical.sh
    bash tools/verify/p04-partial-flip-routing.sh
    bash tools/verify/p04-con3-live-closure.sh
    bash tools/verify/p04-con4-live-killswitch.sh
    ```

    Expected: all five exit 0.

14. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `tools/verify/p04-sc2a-shadow-gate-block.sh`, `tools/verify/p04-sc3-live-mechanical.sh`, `tools/verify/p04-partial-flip-routing.sh`, `tools/verify/p04-con3-live-closure.sh`, `tools/verify/p04-con4-live-killswitch.sh`. Write commit message file via Write to `/tmp/p04-t02-commit-msg.txt`; commit with `git commit -F /tmp/p04-t02-commit-msg.txt`. Recommended subject: `M030/P04/T02: dispatch-interface live-routing branch + flip-gate + partial-flip + --model passing`.

## Must-Haves

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh short-circuits before invoking any backend adapter when ... live: true AND ... evidence_insufficient ..." — gated by `tools/verify/p04-sc2a-shadow-gate-block.sh`.
- "SC-3 holds: with model_routing.live: true AND a shadow corpus passing the flip-readiness check ..." — gated by `tools/verify/p04-sc3-live-mechanical.sh`.
- "Partial-flip routing (D-A3) ..." — gated by `tools/verify/p04-partial-flip-routing.sh`.
- "The live-routing branch in dispatch-interface.sh introduces zero new hardcoded model IDs ..." — gated by `tools/verify/p04-con3-live-closure.sh`.
- "CON-4 / SC-7a-style compound (kill-switch wins in live mode) ..." — gated by `tools/verify/p04-con4-live-killswitch.sh`.
- "The override_source enum gains a sixth value shadow_gate_blocked ..." — gated by `tools/verify/p04-override-source-enum-extended.sh` (post-amendment-strict; T01's tolerant branch retires after T02 lands).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture ..." — gated by `tools/verify/p04-additive-schema.sh` (re-run against amended emitter).

## Verification

```bash
bash tools/verify/p04-additive-schema.sh
bash tools/verify/p04-override-source-enum-extended.sh
bash tools/verify/p04-sc2a-shadow-gate-block.sh
bash tools/verify/p04-sc3-live-mechanical.sh
bash tools/verify/p04-partial-flip-routing.sh
bash tools/verify/p04-con3-live-closure.sh
bash tools/verify/p04-con4-live-killswitch.sh
```

Each verifier uses single-script-file shape per AD-19. All seven must exit 0 before T02 closes.

## Inputs

### From Previous Tasks

- tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md (from T01) — Key API: mechanical-classified plan with no override frontmatter; classifier returns `character=mechanical, confidence=high`.
- tests/fixtures/m030-p04/plans/plan-novel-class.md (from T01) — Key API: novel-classified plan; classifier returns `character=novel, confidence=*`. Used by partial-flip verifier.
- tests/fixtures/m030-p04/configs/{config-with-live-true,config-with-live-and-killswitch,config-with-live-false}.yml (from T01) — Key API: `.orchestrator/config.yml`-shaped overlay configs with `model_routing.live` + optional `model_routing_enabled` / `min_tier` keys.
- tests/fixtures/m030-p04/shadow-corpus-{ready,partially-ready,empty}.jsonl (from T01) — Key API: pre-synthesized JSONL corpora that drive `shadow-compare.sh` to specific verdicts.
- tests/fixtures/m030-p04/round-trip-stage/{intensity-metadata.txt,payload.txt} (from T01) — Standard round-trip dispatch inputs.
- scripts/dispatch/adapters/backend/stub-record-model.sh (from T01) — Key API: accepts `--model <id>` flag, writes value to `STUB_RECORD_MODEL_FILE`. Used by SC-3 verifier.
- scripts/dispatch/adapters/backend/stub-fail-n.sh (from T01) — Not used by T02 verifiers; reserved for T03.
- tools/verify/p04-additive-schema.sh (from T01) — Key API: pass-through wrapper over `tools/verify/p02-additive-schema.sh`. Continues to exit 0 against the post-T02 emitter as long as the shadow-off branches are byte-identical.
- tools/verify/p04-override-source-enum-extended.sh (from T01) — Key API: pre-amendment-tolerant scenario harness with six scenarios A-F. After T02's amendment lands, Scenario F transitions from tolerant ("any P03 enum value PASS") to strict (`shadow_gate_blocked`-only PASS). No verifier-code change needed — the strict branch fires automatically when the token is observed.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form (post-P03). T02 amends `_di_emit_dispatch_usage` body + dispatcher-level adapter invocation.
  - Key API: `_di_emit_dispatch_usage [warning_override]` writes one `dispatch_usage` record to `$log_file` per invocation. Function-internal access to `$TASK_PLAN`, `$PAYLOAD`, `$INTENSITY_METADATA`, `$BACKEND`, `$UNIT_ID`, `$MILESTONE_ID`, `$PHASE_ID`, `$TASK_ID`, `$ORCH_ROOT`, `$_DI_PROJECT_ROOT`. Pre-T02 the function emits 6 P02/P03 fields under shadow-on. Post-T02 the function emits the same 6 fields, but the `override_source` field gains a sixth enum value `shadow_gate_blocked` and the `model_used` field is populated from the routing-table resolution rather than the runtime default when live mode is active.
- scripts/diagnostics/shadow-compare.sh — P02/T03 deliverable.
  - Key API: `bash <path> [--corpus <jsonl-path>]` reads JSONL; emits per-class `count=` + `variance=` + `stable=` lines; emits one `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` line; on `partially_ready` emits an additional `withheld_classes=<comma-list>` line. Bash 3.2 compatible.
- scripts/dispatch/classify-task.sh — P01/T02 classifier. Indirectly exercised via shadow-on dispatch.
- templates/model-routing.yml — P01/T03 SSOT. T02's amendment reads `routing:` and `resolution:` blocks.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip harness invocations. Not affected by T02; shadow-gate-blocked scenarios use stub.sh as the (never-invoked) backend.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` (or the new `_di_resolve_live_routing` helper) inherits the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. T02's amendments stay within this carve-out.
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt; head -1 < /tmp/<g>.txt`.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-P03 form. T02's amendment touches ONLY the resolution logic (which feeds the shadow-on printfs' arguments) and the conditional `--model` flag passing to the adapter — NOT the shadow-off printfs themselves. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: zero new literal provider model IDs in `dispatch-interface.sh`. The live branch's tier resolution flows through `templates/model-routing.yml resolution.<tier>.claude-code` via the same awk section-walker used by the existing P02 path. Verified by `tools/verify/p04-con3-live-closure.sh`.
- **CON-4 / D-A5 (kill switch supersedes live)**: the precedence chain MUST evaluate the kill switch FIRST. When both `model_routing_enabled: false` and `model_routing.live: true` are active, override_source MUST be `disabled` (NOT `shadow_gate_blocked`). The compound case emits a one-line stderr warning naming `live: true is inactive`. Verified by `tools/verify/p04-con4-live-killswitch.sh`.
- **CON-6 (append-only shadow corpus)**: the live-mode emit path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. The P02 `tools/verify/p02-append-only.sh` continues to gate this property under HEAD; T02 does not re-author it.
- **D-A2 (programmatic flip-gate enforcement)**: the live branch MUST invoke `bash scripts/diagnostics/shadow-compare.sh` programmatically before the first live-routed dispatch. The verdict gates the adapter call. Verified by `tools/verify/p04-sc2a-shadow-gate-block.sh` (the gate refuses the adapter call when verdict is evidence_insufficient).
- **D-A3 (per-class partial-flip authorization)**: only classes whose routing-table default is `smart` may be enumerated in `withheld_classes` for the partially_ready verdict. T02 trusts shadow-compare's enumeration (which already enforces D-A3) and does not re-validate. Verified by `tools/verify/p04-partial-flip-routing.sh`.
- **CC-only launch posture**: live path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. The live-routing block is wrapped in the same gate as the existing P02/P03 shadow path — Codex CLI / Cursor short-circuit to the pre-P02 emit (no live mode possible).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.

## Expected Output

- scripts/dispatch/dispatch-interface.sh — amended `_di_emit_dispatch_usage` body (or new `_di_resolve_live_routing` helper) with the live-routing branch reading `model_routing.live:`, programmatically invoking shadow-compare, branching on verdict (`evidence_insufficient|block` → `shadow_gate_blocked`; `ready` → live-route + `--model <id>`; `partially_ready` → per-class authorization). Top-level dispatcher block at line ~585 short-circuits adapter invocation when `_DI_LIVE_GATE_BLOCKED=1`. Adapter invocation at line ~586-589 conditionally appends `--model "$_DI_LIVE_MODEL_FLAG"`. Kill-switch branch additionally emits `live: true is inactive` warning when applicable.
- tools/verify/p04-sc2a-shadow-gate-block.sh — green: dispatch refuses adapter call, exits nonzero, JSONL records shadow_gate_blocked.
- tools/verify/p04-sc3-live-mechanical.sh — green: live-routed mechanical → fast-tier-id passed to stub-record-model, JSONL records resolution.fast.claude-code.
- tools/verify/p04-partial-flip-routing.sh — green: mechanical class flips, novel class withheld, JSONL records partial_flip_active=true + withheld_classes=novel.
- tools/verify/p04-con3-live-closure.sh — green: zero new provider-model-ID literals.
- tools/verify/p04-con4-live-killswitch.sh — green: kill-switch wins; override_source=disabled; stderr names live: true is inactive + min_tier inactive.
- bash tools/verify/p04-additive-schema.sh exits 0 with `SUMMARY: p04-additive-schema.sh pass=1 fail=0`.
- bash tools/verify/p04-override-source-enum-extended.sh exits 0 with `SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0` (Scenario F now strict-asserts shadow_gate_blocked).
- bash tools/verify/p04-sc2a-shadow-gate-block.sh exits 0 with `SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0` (3 assertions: nonzero exit + JSONL token + no dispatch-result).
- bash tools/verify/p04-sc3-live-mechanical.sh exits 0 with `SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0` (3 assertions: JSONL model_used + stub-record-model file + dispatch exit 0).
- bash tools/verify/p04-partial-flip-routing.sh exits 0 with `SUMMARY: p04-partial-flip-routing.sh pass=6 fail=0` (3 assertions × 2 stages).
- bash tools/verify/p04-con3-live-closure.sh exits 0 with `SUMMARY: p04-con3-live-closure.sh pass=7 fail=0` (7 patterns).
- bash tools/verify/p04-con4-live-killswitch.sh exits 0 with `SUMMARY: p04-con4-live-killswitch.sh pass=4 fail=0` (4 assertions: override_source + model_used + stderr line × 2).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-sc2a-shadow-gate-block.sh` -> 3 assertions pass; `SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p04-sc3-live-mechanical.sh` -> 3 assertions pass; `SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p04-partial-flip-routing.sh` -> 6 assertions pass (3 per stage × 2 stages); `SUMMARY: p04-partial-flip-routing.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-con3-live-closure.sh` -> 7 patterns checked; `SUMMARY: p04-con3-live-closure.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p04-con4-live-killswitch.sh` -> 4 assertions pass; `SUMMARY: p04-con4-live-killswitch.sh pass=4 fail=0`, exit 0.

The recommended factoring (extract `_di_resolve_live_routing` as a top-level helper) is preferred because it makes the dispatcher's top-level shadow-gate-blocked check natural — the helper sets the sentinel, the dispatcher reads it. Without the extraction, the dispatcher would either (a) re-execute the resolution inline (duplication), or (b) call `_di_emit_dispatch_usage --resolve-only` (a new flag that runs the resolution but skips emission, then a second call to actually emit). Either alternative works; the extraction is cleanest.

The `M030_SHADOW_COMPARE_CORPUS` env var is the verifier seam — production dispatches DO NOT set it; the live-mode block falls back to `$log_file` (the in-flight log). Verifiers set it to a fixture corpus path so the verdict is deterministic without depending on prior dispatches in the test tmp_root. This pattern matches the `STUB_FAIL_COUNTER_FILE` env-var seam from T01.

The seven-step adapter invocation amendment (Block D) introduces a code duplication: two invocation paths (with/without `--model`) instead of one. This is acceptable per AD-19 — a single-line `[ -n "$_DI_LIVE_MODEL_FLAG" ] && extra_args="--model $_DI_LIVE_MODEL_FLAG"` followed by `bash "$ADAPTER" ... $extra_args` would risk word-splitting on the model ID; the explicit if/else is safer and AD-19-clean.

If the executor finds the verifier-seam env var (`M030_SHADOW_COMPARE_CORPUS`) too coupling, the alternative is a `--shadow-corpus <path>` flag added to dispatch-interface.sh's argument parser. The env var is preferred because (a) it preserves the existing CLI surface, (b) production dispatches never set it so the surface stays clean, and (c) verifiers already use env vars (`M030_SHADOW_MODE`, `CLAUDECODE`, `ORCHESTRATOR_ROOT`) for the same seaming pattern.

If `p04-sc2a-shadow-gate-block.sh` fails on assertion 3 (no dispatch-result emitted), the most likely cause is that the top-level shadow-gate-blocked check fires AFTER the adapter invocation rather than before. Re-check Step 5: the check MUST be inserted at line ~585 (BEFORE the adapter invocation block at line ~586), not at line ~620 (where the happy-path emit currently lives).

If `p04-partial-flip-routing.sh` fails for the novel-class stage with `model_used=<resolution.smart.claude-code>` instead of the runtime default, the partially_ready withheld-class branch is incorrectly resolving the model ID. Re-check Block C's partially_ready branch: when the task's class is in `withheld_classes`, `shadow_used` MUST be set to `$model` (runtime default) and `_DI_LIVE_MODEL_FLAG` MUST remain unset.

Per the operator-doc convention from P03/T03 (operator-facing docs co-locate with gate-verifier ship date), T02 SHOULD amend `references/model-routing.md` to add a `## Live Routing` section documenting the flip-gate behavior. However, given T03 also amends the same file (escalation docs), the recommendation is to defer ALL P04 references docs amendments to T03 and ship them as one section. T02 leaves `references/model-routing.md` untouched.
