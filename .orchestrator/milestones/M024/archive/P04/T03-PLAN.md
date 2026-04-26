---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M024"
name: "Wire fast-path into scripts/intake/proposal-emit.sh"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `scripts/state/read-config.sh` accepts `auto_proceed` as a valid key; `templates/orchestrator-config-default.yml` ships `auto_proceed: true`.
- T02 complete: `scripts/intake/approval-gate.sh` accepts `--mode check-fast-path --proposal <path>` and emits the two-line verdict (`fast_path_eligible=...` + `reason=...`) without mutating the proposal.
- P01 complete: the proposal frontmatter ships `auto_proceeded: <bool>` (default `false`) and `proceeded_at: <iso8601-or-null>`. The P01/P03 paragraph-axes / spec-axes wiring already establishes the `*_AXES_DONE` flag pattern in `proposal-emit.sh`.
- P03 complete: `scripts/intake/route-to-dispatch.sh` already honors `auto_proceeded: true` by mutating `proceeded_at: <ISO8601>` and emitting `auto_proceed=1` to stdout — P04 only needs to flip the upstream flag.

## Description

Wire the fast-path verdict into `scripts/intake/proposal-emit.sh`. After axis resolution (paragraph + spec deep classifiers, intensity recommendation) but **before** the final `swap` loop renders the proposal to its final path, the emitter:

1. Resolves `auto_proceed` from config (`scripts/state/read-config.sh`) — treats `null` as `true` per FR-3 default-on.
2. Renders an **interim** copy of the proposal frontmatter to a tmp path (the existing `tmp_render` already lives in mktemp).
3. Invokes `bash scripts/intake/approval-gate.sh --mode check-fast-path --proposal <interim>` against that interim file.
4. If the verdict is `fast_path_eligible=true` AND config `auto_proceed != "false"`, sets the local shell var `auto_proceeded="true"` before the final `swap auto_proceeded "$auto_proceeded"` call runs.
5. Records a `FAST_PATH_AXES_DONE=1` flag (mirroring `PARA_AXES_DONE` and `SPEC_AXES_DONE`) so future-phase rationale loops know the fast-path branch fired.

The wiring is **invoke-time** per the validated convention — no plan-phase-time probe; the check re-runs every emit. SB-3 write-confinement preserved: the check is read-only, the only writes the emitter performs target `.orchestrator/intake/<id>/` exactly as today.

### Subtle interim-render note (load-bearing)

The current `proposal-emit.sh` flow is:

1. Compute axes (shape, id, intensity, paragraph/spec overrides).
2. `cp "$TEMPLATE" "$tmp_render"`.
3. Run a long sequence of `swap <key> <val>` calls against `$tmp_render` (each is a `sed -i.bak` line replace).
4. Run rationale-loop `swap`s for any axis the deep classifiers did not handle.
5. `mv "$tmp_render" "$out_path"`.

To run check-fast-path mid-flow, the emitter must call the gate after step 3 has populated the five axis lines (`scope_tier`, `intensity`, `conversus_gate`, `design_gate`, `low_confidence`) but before the `auto_proceeded` swap. Concretely: the fast-path block goes **immediately after** the existing `swap intensity "$intensity"` call but **before** `swap auto_proceeded "$auto_proceeded"` so the gate sees the true axis values rather than the `{{placeholder}}` literals. The `low_confidence` swap must also have already run by that point — currently `low_confidence` is swapped before `auto_proceeded` in the existing source, so the natural insertion point sits between those two swaps.

If the swap order changes in a future patch, the verify script (`m024-p04-proposal-emit-fast-path.sh`) catches the regression by inspecting the rendered proposal end-to-end.

## Steps

1. **Edit `scripts/intake/proposal-emit.sh`.** After the existing `swap intensity "$intensity"` line and immediately **before** `swap auto_proceeded "$auto_proceeded"` (so `auto_proceeded` is still the local-var value when it gets swapped in), insert the fast-path block:

   ```bash
   # (8a) Fast-path check (M024/P04 — FR-3 four-condition gate).
   #
   # The check requires the five axis frontmatter lines to be already swapped
   # in. The block sits between the `swap intensity` and the `swap auto_proceeded`
   # calls so the verdict reflects real values, not template placeholders.
   GATE="$ROOT/scripts/intake/approval-gate.sh"
   READ_CONFIG="$ROOT/scripts/state/read-config.sh"
   DEFAULTS_FILE="$ROOT/templates/orchestrator-config-default.yml"
   PROJECT_FILE="$ROOT/orchestrator-config.yml"
   LOCAL_FILE="$ROOT/orchestrator-config.local.yml"

   # Resolve config — treat null as the default (true) per FR-3.
   ap_config="true"
   if [ -x "$READ_CONFIG" ]; then
     ap_resolved=$(bash "$READ_CONFIG" auto_proceed --defaults "$DEFAULTS_FILE" --project "$PROJECT_FILE" --local "$LOCAL_FILE" 2>/dev/null || echo "null")
     case "$ap_resolved" in
       false) ap_config="false" ;;
       true|null|"") ap_config="true" ;;
       *) ap_config="true" ;;
     esac
   fi

   # Interim render: the existing $tmp_render already has the five axis lines
   # swapped at this point. We pass it directly to check-fast-path.
   if [ "$ap_config" = "true" ] && [ -x "$GATE" ]; then
     fp_out=$(bash "$GATE" --proposal "$tmp_render" --mode check-fast-path 2>/dev/null || true)
     fp_eligible=$(echo "$fp_out" | sed -n 's/^fast_path_eligible=//p' | head -1)
     if [ "$fp_eligible" = "true" ]; then
       auto_proceeded="true"
       FAST_PATH_AXES_DONE=1
     fi
   fi
   ```

2. **Confirm the existing `swap auto_proceeded "$auto_proceeded"` call sits immediately after** the new block. The fast-path block does not itself call `swap` for `auto_proceeded` — it mutates the local shell var `auto_proceeded`, and the existing swap line picks up the new value.

3. **Author the per-task verify** at `scripts/verify/m024-p04-proposal-emit-fast-path.sh`. The verify exercises the full emit-to-disk path (no hand-crafted frontmatter) so it catches both wiring regressions and any swap-order changes:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-proposal-emit-fast-path.sh
   # Verifies proposal-emit.sh sets auto_proceeded: true on a Tier-A-eligible input.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"
   GATE="$ROOT/scripts/intake/approval-gate.sh"
   READ_CONFIG="$ROOT/scripts/state/read-config.sh"

   [ -x "$EMIT" ]        || { echo "FAIL: $EMIT not executable"; exit 1; }
   [ -x "$GATE" ]        || { echo "FAIL: $GATE not executable"; exit 1; }
   [ -x "$READ_CONFIG" ] || { echo "FAIL: $READ_CONFIG not executable"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   # Tier A trivial input — paragraph classifier yields A + single-task + dispatch;
   # design_gate / conversus_gate are P01 stubs at "none"; intensity falls back to
   # Standard unless --description is exactly the right shape. The fast-path needs
   # intensity=Quick, so we manually exercise the emitter on a string short enough
   # for intensity-recommend to land Quick (single-line typo fix).
   trivial="fix typo in commands/status.md line 12 sope to scope"
   emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
   [ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

   # Sanity — the four conditions must hold in the rendered proposal frontmatter.
   grep -q '^scope_tier: "A"$'      "$proposal" || { echo "FAIL: scope_tier not A"; exit 1; }
   grep -q '^conversus_gate: "none"$' "$proposal" || { echo "FAIL: conversus_gate not none"; exit 1; }
   grep -q '^design_gate: "none"$'  "$proposal" || { echo "FAIL: design_gate not none"; exit 1; }
   intensity_line=$(grep '^intensity: ' "$proposal" | head -1)
   case "$intensity_line" in
     'intensity: "Quick"') ;;
     *) echo "FAIL: intensity not Quick (got: $intensity_line) — fast-path cannot fire on this fixture; revisit intensity-recommend.sh thresholds"; exit 1 ;;
   esac

   # The load-bearing assertion — auto_proceeded must be true on a four-condition input.
   grep -q '^auto_proceeded: true$' "$proposal" \
     || { echo "FAIL: auto_proceeded not flipped to true on Tier-A fast-path input"; exit 1; }

   # The pending_approval invariant: when auto_proceeded=true, pending_approval is still
   # the P01 default true at emit time — the route-to-dispatch script is what eventually
   # supersedes the operator gate. (P04 only flips auto_proceeded; P03's gate behavior
   # for non-fast-path proposals is unchanged.)
   grep -q '^pending_approval: true$' "$proposal" \
     || { echo "FAIL: pending_approval should remain true at emit time (route-to-dispatch finalizes)"; exit 1; }

   echo "PASS: proposal-emit.sh — Tier-A fast-path input flips auto_proceeded to true"
   exit 0
   ```

4. **Make the verify executable**: `chmod +x scripts/verify/m024-p04-proposal-emit-fast-path.sh`.

## Must-Haves

- `scripts/intake/proposal-emit.sh` resolves `auto_proceed` via `scripts/state/read-config.sh` before the final render, treating `null` as `true` per FR-3.
- After axis swaps but before `swap auto_proceeded`, the emitter invokes `approval-gate.sh --mode check-fast-path` against the interim render and reads the `fast_path_eligible=` line.
- When the verdict is `true` AND config `auto_proceed != "false"`, the local `auto_proceeded` shell var is flipped to `"true"` so the rendered proposal carries `auto_proceeded: true`.
- `FAST_PATH_AXES_DONE=1` is set when the fast-path branch fires (mirrors `PARA_AXES_DONE` / `SPEC_AXES_DONE` for forward compatibility with future rationale-loop short-circuiting).
- Non-eligible proposals (any condition violated, or config explicitly `false`) keep `auto_proceeded` at the P01 default `false`. `pending_approval` is unaffected at emit time — the existing P03 approval-gate path is the operator's only finalization route for non-fast-path proposals.
- The check is read-only — no `.bak` file remains after the gate invocation; the only writes the emitter performs target `.orchestrator/intake/<id>/` (the same surface as before T03).
- AD-19 single-script-file shape: every external invocation is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.

## Verification

```
bash scripts/verify/m024-p04-proposal-emit-fast-path.sh
```

Exits 0 with `PASS: proposal-emit.sh — Tier-A fast-path input flips auto_proceeded to true`.

## Inputs

### From Previous Tasks

- `scripts/intake/approval-gate.sh` (from M024/P04/T02) — invoked at emit time. Key API: `bash approval-gate.sh --proposal <path> --mode check-fast-path` emits two stdout lines `fast_path_eligible=true|false` and `reason=<token>`. Read-only — does not mutate the proposal. Exit 0 on verdict (eligible or not), 1 on I/O error, 2 on usage error.
- `scripts/state/read-config.sh` (from M024/P04/T01 — `auto_proceed` added to `VALID_KEYS`) — invoked at emit time. Key API: `bash read-config.sh auto_proceed --defaults <f> --project <f> --local <f>` returns `true | false | null`. The new key resolves through the existing four-layer precedence with no resolver code changes.
- `scripts/intake/paragraph-classify.sh` + `scripts/intake/spec-shape-classify.sh` (from P02/P03) — already wired into the emitter; provide the `scope_tier` / `decomposition` / `recommended_command` axis values the fast-path check reads.
- `scripts/engine/intensity-recommend.sh` (FR-9 reuse) — already wired; provides the `intensity` value (`Quick | Standard | Full`).

### From Disk (Pre-existing)

- `templates/intake-proposal.md` (from M024/P01/T01) — the frontmatter schema. Keys read by the fast-path check: `scope_tier`, `intensity`, `conversus_gate`, `design_gate`, `low_confidence`. The `auto_proceeded` key is the one this task flips.
- `templates/orchestrator-config-default.yml` (from M024/P04/T01) — defaults file consumed by `read-config.sh` layer 4. Ships `auto_proceed: true`.
- `sed -n`, `grep`, `head`, `mktemp`, `printf`, `case` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- The fast-path check must run **after** the five axis swaps (`swap scope_tier`, `swap intensity`, `swap conversus_gate`, `swap design_gate`, `swap low_confidence`) and **before** `swap auto_proceeded`. Re-ordering swaps without re-positioning the fast-path block will silently break the verdict.
- The check is read-only against `$tmp_render` — the gate's `--mode check-fast-path` does not call `swap_line`, but the emit-side wiring must also not write anything new to the proposal beyond the existing render flow.
- AD-19 single-script-file shape: the gate invocation is a single `bash "$GATE" --proposal "$tmp_render" --mode check-fast-path` call; no `$(... | ...)` shape, no nested subshells.
- Stdout-discipline: the gate's two-line stdout is parsed with `sed -n` line-by-line, never with a pipe-into-grep-into-cut compound (the existing `paragraph-classify` / `spec-classify` plumbing in proposal-emit.sh uses the same shape).
- FR-3 default-on: an unresolvable config (`null` from read-config, or read-config not executable) MUST be treated as `auto_proceed=true`. The default is the operator-friendly path; opt-out is explicit.
- NG-6: there is no other auto-proceed path. The only condition that flips `auto_proceeded` to `true` is the four-condition gate verdict; nothing else.
- SB-3 write-confinement: the only file mutations are the existing `swap` calls against `$tmp_render` and the final `mv` to `.orchestrator/intake/<id>/proposal.md`. The fast-path check itself writes nothing.
- Backwards compatibility: a checkout where `approval-gate.sh` is missing the `--mode check-fast-path` capability (e.g. a re-rolled tree without P04/T02) MUST degrade gracefully — the `bash "$GATE" ... 2>/dev/null || true` and the `case "$ap_resolved"` defaults ensure the local `auto_proceeded` stays `false` and the operator path is unchanged.

## Expected Output

`scripts/intake/proposal-emit.sh` is modified to wire the fast-path check between the axis-swap and `auto_proceeded`-swap phases; `scripts/verify/m024-p04-proposal-emit-fast-path.sh` exists, is executable, and exits 0 with a `PASS:` line.
