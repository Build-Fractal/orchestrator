---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M030"
name: "dispatch-interface escalation loop + CON-5 hard-cap + escalation_cap_hit record + CON-6 append-only verifier"
depends_on: ["T02"]
---

## Prerequisites

- All T01 + T02 deliverables on disk and green:
  - `bash tools/verify/p04-additive-schema.sh` exits 0 (T01)
  - `bash tools/verify/p04-override-source-enum-extended.sh` exits 0 strict-mode (T02)
  - `bash tools/verify/p04-sc2a-shadow-gate-block.sh` exits 0 (T02)
  - `bash tools/verify/p04-sc3-live-mechanical.sh` exits 0 (T02)
  - `bash tools/verify/p04-partial-flip-routing.sh` exits 0 (T02)
  - `bash tools/verify/p04-con3-live-closure.sh` exits 0 (T02)
  - `bash tools/verify/p04-con4-live-killswitch.sh` exits 0 (T02)
- scripts/dispatch/dispatch-interface.sh exists in its post-T02 form: live-routing branch reads `model_routing.live`; programmatic shadow-compare invocation; conditional `--model "$_DI_LIVE_MODEL_FLAG"` to backend adapter; `_DI_LIVE_GATE_BLOCKED` short-circuits adapter invocation; kill-switch path emits `live: true is inactive` warning when applicable.
- scripts/dispatch/adapters/backend/stub-fail-n.sh exists (T01) with the read-decrement counter contract, the `STUB_FAIL_COUNTER_INVOCATIONS_FILE` side-channel, and the `STUB_INVOCATION_SENTINEL_DIR` sentinel-drop hook.
- tests/fixtures/m030-p04/plans/{plan-fail-twice-then-pass,plan-fail-three-times,plan-fail-four-times}.md exist (T01).
- tests/fixtures/m030-p04/configs/config-with-live-true.yml exists (T01).
- tests/fixtures/m030-p04/shadow-corpus-ready.jsonl exists (T01) — `shadow-compare.sh` returns `flip_recommendation=ready` on it.
- tests/fixtures/m030-p04/round-trip-stage/{intensity-metadata.txt,payload.txt} exist (T01).
- references/model-routing.md exists with the `## Operator Overrides` section authored by P03/T03 (the `## Live Routing` section is T03 deliverable).

Plan-time prerequisite-existence verification: every path above is asserted at T02 close. The post-T02 shape of `dispatch-interface.sh` was inspected at planning time; the live-routing branch + flip-gate + `--model` passing are in place.

## Description

T03 is the high-risk core amendment, part 2 of 2. Six deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — wrap the adapter invocation in an escalation loop that runs ONLY when in live mode AND verdict is `ready` or `partially_ready` AND the current task's class is flippable. The loop iterates up to 3 times (initial + 2 escalations); on rc != 0, recompute the next tier (`fast → balanced → smart`), re-resolve the model ID, emit a NEW dispatch_usage record with incremented `escalation_count` and `escalation_reason=verifier_fail`, and re-invoke the adapter. After the cap is hit (3 attempts all failing), emit ONE `escalation_cap_hit` record and exit nonzero.

2. **Add `_di_tier_at_rank` helper** alongside `_di_tier_rank` (around line 175). Maps numeric rank → symbolic tier (inverse of `_di_tier_rank`).

3. **Add `escalation_count` and `escalation_reason` fields** to BOTH shadow-on printf format strings (happy-path and degradation). Initial dispatch emits `escalation_count=0` + `escalation_reason=""`; escalated dispatches emit the running counter + `verifier_fail`.

4. **Add `escalation_cap_hit` record emission** as a new top-level printf in dispatch-interface.sh (after the escalation loop concludes with cap hit). Single-line JSON record with `record_type=escalation_cap_hit`, `unitId`, `final_count=2`, `timestamp`.

5. **Co-authored verifiers**: `p04-sc4-escalation-sequence.sh`, `p04-sc5-escalation-cap.sh`, `p04-con5-no-fourth-record.sh`, `p04-con6-prior-records-bit-identical.sh`, `p04-escalation-fields-enum.sh`. Each follows the round-trip-stage shape with the `stub-fail-n.sh` adapter.

6. **Amend `references/model-routing.md`** to add a `## Live Routing` section documenting the flip-gate + escalation chain end-to-end (operator-facing docs co-locate with the gate-verifier ship date, mirroring P03/T03's `## Operator Overrides` section pattern).

T03 also re-runs T01/T02's gates against the amended emitter to confirm the post-T03 branches don't break upstream invariants.

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is FOUR-block: (a) `_di_tier_at_rank` helper, (b) escalation loop wrapping the adapter invocation, (c) printf format-string extension with `escalation_count` + `escalation_reason`, (d) `escalation_cap_hit` record emission.

**Block A — `_di_tier_at_rank` helper.** Insert immediately after `_di_tier_rank` (current location around line 181-188):

```bash
# --- M030/P04/T03: inverse tier-rank for escalation progression ---
# Maps numeric rank to symbolic tier name (fast=0, balanced=1, smart=2).
# Returns "" for unknown rank. Used by the escalation loop to compute the
# next-higher tier on verifier failure. CON-3-clean (symbolic only).
_di_tier_at_rank() {
  case "$1" in
    0) echo fast ;;
    1) echo balanced ;;
    2) echo smart ;;
    *) echo "" ;;
  esac
}
```

**Block B — escalation loop wrapping the adapter invocation.** The current adapter invocation is at line ~586-595 (post-T02 form, with the conditional `--model` if/else). T03 wraps the entire invocation block in a loop that:

1. Tracks `escalation_count` (starts at 0).
2. Tracks the current symbolic tier (starts at `shadow_routed` from T02's resolution).
3. Invokes the adapter; captures `adapter_rc`.
4. On rc=0: emit happy-path dispatch_usage record (with current `escalation_count` + appropriate `escalation_reason`); break out of loop; continue to "emit adapter output unchanged" line.
5. On rc!=0:
   - If `escalation_count >= 2`: cap is hit. Emit the final dispatch_usage record (with `escalation_count=2`, `escalation_reason=verifier_fail`). Emit ONE `escalation_cap_hit` record. Emit dispatch-error.md on stderr (existing `emit_error "backend_crashed" ...` path). Exit 5.
   - Else: emit current-iteration dispatch_usage record (with current `escalation_count` value, `escalation_reason=verifier_fail`). Increment `escalation_count`. Recompute next tier via `_di_tier_at_rank`. Re-resolve `_DI_LIVE_MODEL_FLAG` for the new tier via the awk section-walker. Loop again.

The loop is gated: it ONLY runs when ALL of `M030_SHADOW_MODE=1` AND `CLAUDECODE=1` AND `_DI_LIVE_MODEL_FLAG` is non-empty (live mode active AND class flippable). Otherwise the original adapter invocation runs as a single-shot (no escalation).

Implementation skeleton (to insert at line ~585 BEFORE the existing adapter invocation block):

```bash
# M030/P04/T03: escalation loop. Active only in live mode.
escalation_count=0
escalation_reason=""
adapter_output=""
adapter_rc=0
escalation_active=0
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ] && [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
  escalation_active=1
fi

if [ "$escalation_active" -eq 1 ]; then
  # Live-mode escalation loop.
  while : ; do
    # Invoke adapter with current --model flag.
    adapter_rc=0
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" \
      --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?

    if [ "$adapter_rc" -eq 0 ]; then
      # Success — emit final dispatch_usage record + break.
      _di_emit_dispatch_usage "" || true
      break
    fi

    # Failure — check cap.
    if [ "$escalation_count" -ge 2 ]; then
      # Cap hit. Emit final failed dispatch_usage record + escalation_cap_hit.
      escalation_reason="verifier_fail"
      _di_emit_dispatch_usage "adapter-failed" || true
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed after escalation cap of 2 escalations" \
        "Adapter: ${ADAPTER}; final tier: $shadow_routed" \
        "Inspect adapter stderr; consider lowering min_tier or disabling routing for this task."
      exit 5
    fi

    # Emit current-iteration failed dispatch_usage record (with current count).
    escalation_reason="verifier_fail"
    _di_emit_dispatch_usage "adapter-failed" || true

    # Escalate: bump count, recompute next tier.
    escalation_count=$((escalation_count + 1))
    _di_curr_rank=$(_di_tier_rank "$shadow_routed")
    _di_next_rank=$((_di_curr_rank + 1))
    shadow_routed="$(_di_tier_at_rank "$_di_next_rank")"
    if [ -z "$shadow_routed" ]; then
      # Should not happen — _di_curr_rank=2 already triggered cap above.
      # Defensive: if we get here, treat as cap hit.
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed; tier progression exhausted" \
        "Adapter: ${ADAPTER}" "Reduce escalation aggressiveness."
      exit 5
    fi
    # Re-resolve shadow_used + _DI_LIVE_MODEL_FLAG for the new tier.
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
  done
else
  # Non-live mode — single-shot dispatch (preserves T02 + pre-T02 behavior).
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
  # Existing post-adapter-invocation flow (conformance checks + happy-path
  # emit at line ~620) runs as before.
fi

# Single-shot non-live path falls through; live-mode happy-path falls through
# to the existing conformance-check + "emit adapter output unchanged" lines.
if [ "$adapter_rc" -ne 0 ] && [ "$escalation_active" -ne 1 ]; then
  # Pre-T03 adapter-failed flow (single-shot non-live).
  emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
    "Adapter subprocess exited with code ${adapter_rc}" \
    "Adapter: ${ADAPTER}" \
    "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
  _di_emit_dispatch_usage "adapter-failed" || true
  exit 5
fi
```

The above replaces the existing adapter invocation + adapter-rc check block (current lines ~586-598). The conformance-check block (line ~600-617) and the happy-path emit (line ~620) continue as before — they fire on the loop's break-on-success path.

**Important — `escalation_count` and `escalation_reason` propagation:** the printf format strings in `_di_emit_dispatch_usage` need to read these locals. Two options:

- (a) Pass them as function arguments: `_di_emit_dispatch_usage "$warning" "$escalation_count" "$escalation_reason"`. Requires changing the signature.
- (b) Make `escalation_count` and `escalation_reason` shell-scoped (declared at top level of the dispatcher block, not local to the loop). The function reads them via the same shell-variable mechanism it uses for `shadow_routed` etc.

Option (b) is cleaner and matches MEM004 carve-out (the function reads shell-scoped state already). Implementation: declare `escalation_count=0` and `escalation_reason=""` at the top of the dispatcher block (before the BACKEND resolution), so they're visible to `_di_emit_dispatch_usage` via the parent-shell scope.

**Block C — printf format-string extension.** Two shadow-ON printfs (happy-path line ~453, degradation line ~486) gain TWO new fields. Insert `,"escalation_count":%d,"escalation_reason":"%s"` after `,"override_source":"%s"`:

```text
,"override_source":"%s","escalation_count":%d,"escalation_reason":"%s"
```

Append `"$escalation_count" "$escalation_reason"` to the args list at the end. The shadow-OFF printfs (lines ~468 + ~501) are UNCHANGED — SC-11 byte-equality preserved.

**Block D — `_di_emit_escalation_cap_hit` helper + emission.** Add a new helper alongside `_di_emit_dispatch_usage`:

```bash
# --- M030/P04/T03: escalation_cap_hit emission helper ---
# Writes a single escalation_cap_hit JSONL record after the cap is hit. Same
# log_dir resolution as _di_emit_dispatch_usage; bail-safe; idempotent
# (caller guarantees one invocation per cap event).
_di_emit_escalation_cap_hit() {
  if [ "${M030_SHADOW_MODE:-0}" != "1" ] || [ "${CLAUDECODE:-0}" != "1" ]; then
    return 0
  fi
  local cap_log_dir cap_log_file cap_ts
  if [ -d "$ORCH_ROOT/phases" ]; then
    cap_log_dir="$ORCH_ROOT"
  elif [ -n "$MILESTONE_ID" ]; then
    cap_log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  else
    return 0
  fi
  cap_log_file="$cap_log_dir/execution-log.jsonl"
  cap_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$cap_log_dir" 2>/dev/null || return 0
  printf '{"record_type":"escalation_cap_hit","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","final_count":2,"timestamp":"%s"}\n' \
    "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$cap_ts" \
    >> "$cap_log_file" 2>/dev/null || true
  return 0
}
```

Called from Block B's cap-hit branch.

### Verifier shapes (load-bearing detail)

**`tools/verify/p04-sc4-escalation-sequence.sh`** — fail-twice-then-pass:

```bash
# Stage tmp_root + counter file at value 2.
COUNTER_FILE="$TMP_ROOT/fail-counter.txt"
printf '2\n' > "$COUNTER_FILE"
INVOCATIONS_FILE="$TMP_ROOT/invocations.txt"
: > "$INVOCATIONS_FILE"

export STUB_FAIL_COUNTER_FILE="$COUNTER_FILE"
export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$INVOCATIONS_FILE"
export M030_SHADOW_COMPARE_CORPUS="$REPO_ROOT/tests/fixtures/m030-p04/shadow-corpus-ready.jsonl"
# Standard live-mode env: ORCHESTRATOR_ROOT, M030_SHADOW_MODE=1, CLAUDECODE=1.
# Plan: plan-fail-twice-then-pass.md (mechanical-classified).
# Backend: stub-fail-n (counter=2 → fail twice then pass).

bash "$DISPATCH" --task-plan "$PLAN_FAIL_TWICE" --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" --backend stub-fail-n \
  > /dev/null 2>&1
DISPATCH_RC=$?

# Assertion 1: dispatch-interface exits 0 (third attempt succeeded).
[ "$DISPATCH_RC" -eq 0 ] && pass=$((pass+1)) || fail=$((fail+1))

# Assertion 2: exactly three dispatch_usage records.
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP"
wc -l < "$LINE_TMP" > "$LC_TMP"
LC="$(tr -d '[:space:]' < "$LC_TMP")"
[ "$LC" -eq 3 ] && pass=$((pass+1)) || fail=$((fail+1))

# Assertion 3: model_used sequence = fast → balanced → smart (resolved at runtime).
EXPECTED_FAST="$(awk ... fast ...)"
EXPECTED_BALANCED="$(awk ... balanced ...)"
EXPECTED_SMART="$(awk ... smart ...)"
LINE1="$(sed -n '1p' "$LINE_TMP")"
LINE2="$(sed -n '2p' "$LINE_TMP")"
LINE3="$(sed -n '3p' "$LINE_TMP")"
# Per-line model_used assertions via grep -F '"model_used":"$EXPECTED_X"'.

# Assertion 4: third record carries escalation_count=2 + escalation_reason=verifier_fail.
# (Wait — third record is the success after 2 failures. escalation_count on the
#  third record is 2 because two escalations preceded it. escalation_reason is
#  "" on the success record? Or is "verifier_fail" on the second-to-last record?)
```

**Subtle semantic decision**: the escalation_count on the SUCCESS record (third record after fail-twice-then-pass) — is it 0, 2, or something else?

Per the demo: "the third carries `escalation_count=2`". So on the success record, `escalation_count=2` (reflecting that two escalations preceded this attempt). And `escalation_reason` on the success record is empty (the success itself was not a verifier_fail).

This means the implementation must:
- Increment `escalation_count` AFTER each failed attempt's record is emitted, not before. The successful attempt's record reads the post-incremented value (which equals the number of preceding failures).
- Reset `escalation_reason` to empty before the successful emit (since rc=0 on the third attempt).

Concretely: each loop iteration emits its dispatch_usage record AFTER computing rc. The values are:

| Iteration | rc | escalation_count emitted | escalation_reason emitted |
|-----------|----|----|----|
| 1 (initial) | 1 (fail) | 0 | verifier_fail |
| 2 (escalated to balanced) | 1 (fail) | 1 | verifier_fail |
| 3 (escalated to smart) | 0 (success) | 2 | "" |

The increment of `escalation_count` happens BETWEEN iterations (after emit, before next attempt). Block B's logic:

```
loop_start:
  invoke adapter; capture rc
  if rc == 0:
    emit record with current escalation_count + escalation_reason="" (success)
    break
  else if escalation_count >= 2:
    emit record with current escalation_count + escalation_reason="verifier_fail" (final failure)
    emit escalation_cap_hit record
    exit 5
  else:
    emit record with current escalation_count + escalation_reason="verifier_fail"
    escalation_count++
    recompute next tier
    goto loop_start
```

This produces the expected sequence:
- (initial, count=0, reason=verifier_fail, fail)
- (escalated, count=1, reason=verifier_fail, fail)
- (escalated, count=2, reason="", success)

For the SC-5 case (fail-three-times):
- (initial, count=0, reason=verifier_fail, fail)
- (escalated, count=1, reason=verifier_fail, fail)
- (escalated, count=2, reason=verifier_fail, fail) ← cap hit
- escalation_cap_hit record emitted; exit 5

Three dispatch_usage records + one escalation_cap_hit record. NO fourth dispatch_usage.

For the CON-5 case (fail-four-times) — same as fail-three-times. The counter has 4 failures pending but the cap stops at 3 invocations. The stub adapter is invoked exactly 3 times; the 4th invocation never happens.

**`tools/verify/p04-sc5-escalation-cap.sh`** — fail-three-times. Same staging as SC-4 but counter starts at 3. Assertions:

1. dispatch-interface exits nonzero (5).
2. Exactly three dispatch_usage records.
3. Exactly one escalation_cap_hit record.
4. The escalation_cap_hit record's `final_count=2` and `unitId` matches the dispatch_usage records' unitId.
5. Each of the three dispatch_usage records has `escalation_reason=verifier_fail`.
6. The third dispatch_usage record has `escalation_count=2`.

**`tools/verify/p04-con5-no-fourth-record.sh`** — fail-four-times. Counter starts at 4. Same assertions as SC-5 plus:

7. The `STUB_FAIL_COUNTER_INVOCATIONS_FILE` contains exactly 3 lines (proving the stub adapter was invoked 3 times, not 4).

**`tools/verify/p04-con6-prior-records-bit-identical.sh`** — append-only check. The challenge: capturing first-two-lines hashes mid-escalation requires inspecting the log file BEFORE the third attempt. Two approaches:

- (a) Use `STUB_INVOCATION_SENTINEL_DIR` from T01's stub-fail-n. Each adapter invocation drops a sentinel file. The verifier waits for the second sentinel, captures `head -n 2 "$LOG_FILE"` hash, lets the third invocation proceed, captures `head -n 2` again at the end, asserts equal. But the dispatch is synchronous — the verifier cannot inject a wait between adapter invocations.
- (b) Run the escalation in two stages: first dispatch the fail-twice-then-pass plan, capture the full log AFTER it completes (3 records); compute hash of `head -n 2`; then cat the same log to a different file and compute hash again; assert equal. This is a degenerate test — it just asserts that the same `head -n 2` is computed twice.

Better approach (c): use `tee` to capture the log file's growth log + a checksum side-channel. Run the dispatch. After completion, compute hashes of `sed -n '1p' "$LOG_FILE"` and `sed -n '2p' "$LOG_FILE"`. Then run the dispatch AGAIN against a fresh tmp_root (same fixture; counter=2 again). After this second completion, the new log's first two lines are the new attempt's records — DIFFERENT from the first run's. The assertion is: WITHIN a single dispatch, the prior records remain stable AS the escalation unfolds. The simplest way to assert this is to compare the bytes of the first two records BEFORE the third attempt's record is appended.

The CLEANEST shape (chosen): **decouple the assertion from the live escalation timing**. The CON-6 verifier asserts:

1. Run the dispatch against fail-twice-then-pass (counter=2). After completion, `head -n 2 "$LOG_FILE"` produces two record lines (the first two attempts).
2. Compute SHA-256 of `head -n 2 "$LOG_FILE"`.
3. Append a synthetic line to the log file AFTER the dispatch completes: `printf 'synthetic\n' >> "$LOG_FILE"`. This simulates a downstream append without re-running dispatch.
4. Compute SHA-256 of `head -n 2 "$LOG_FILE"` AGAIN. Assert equal to step 2's hash.
5. This proves: the escalation's append-only contract holds — appending more records does NOT mutate prior records' bytes.

The above is a degenerate test (essentially asserting `head -n 2` is deterministic), but it's the mechanically-verifiable proxy for CON-6 in the absence of a mid-dispatch inspection seam. The richer test would require a custom adapter that pauses on the third invocation; out of scope for P04.

A STRONGER variant: assert that the inode of the log file does not change between the start and end of the dispatch. Use `stat -f %i "$LOG_FILE"` (macOS) or `stat -c %i` (Linux) to capture the inode before dispatch starts and after dispatch ends. Equal inodes mean no `mv`/`cp`/swap occurred. This is the same shape as `p02-append-only.sh` from P02/T03.

Implementation chosen: **inode-preservation + first-two-lines hash equality after a synthetic append**. Combines both checks for stronger CON-6 assurance.

**`tools/verify/p04-escalation-fields-enum.sh`** — three scenarios:

| Scenario | Counter | Plan | Expected records |
|----------|---------|------|------------------|
| no-failure | 0 | plan-mechanical-no-override | 1 record, count=0, reason="" |
| fail-twice-then-pass | 2 | plan-fail-twice-then-pass | 3 records, sequence (0/vf, 1/vf, 2/"") |
| fail-three-times | 3 | plan-fail-three-times | 3 records, sequence (0/vf, 1/vf, 2/vf) + escalation_cap_hit |

Assert per-record `escalation_count` + `escalation_reason` values match the expected sequences.

### references/model-routing.md ## Live Routing section

Append after the existing `## Operator Overrides` section. Documents:

1. **The flip-gate enforcement chain** — `model_routing.live: true` triggers programmatic shadow-compare invocation; verdicts gate the adapter call.
2. **Verdict-to-action table** —
   - `ready` → all classes flip live; `--model <id>` passed to backend.
   - `partially_ready` → only flippable classes flip; `withheld_classes=<list>` recorded; `partial_flip_active=true`.
   - `evidence_insufficient` / `block` → adapter NOT invoked; `override_source=shadow_gate_blocked`; dispatch-interface exits nonzero.
3. **Escalation chain** — `fast → balanced → smart` on verifier failure. Cap at 2 escalations (CON-5). Three dispatch_usage records max + one `escalation_cap_hit` on cap.
4. **Override precedence (extended from P03)** — kill switch supersedes live; live supersedes routed; routed defers to plan_frontmatter / milestone_floor / none.
5. **Operator workflow** — flip from shadow to live: (a) ensure ≥50 records per class with stable confidence in shadow corpus; (b) run `bash scripts/diagnostics/shadow-compare.sh`; verify verdict is `ready` or acceptable `partially_ready`; (c) set `model_routing.live: true` in `.orchestrator/config.yml`; (d) the next dispatch validates via programmatic shadow-compare and either proceeds or refuses.

## Steps

1. **Confirm T01 + T02 deliverables are on disk and green.** Run all seven existing P04 verifiers:

   ```bash
   bash tools/verify/p04-additive-schema.sh
   bash tools/verify/p04-override-source-enum-extended.sh
   bash tools/verify/p04-sc2a-shadow-gate-block.sh
   bash tools/verify/p04-sc3-live-mechanical.sh
   bash tools/verify/p04-partial-flip-routing.sh
   bash tools/verify/p04-con3-live-closure.sh
   bash tools/verify/p04-con4-live-killswitch.sh
   ```

   Expected: all seven exit 0. If any fail, T01 or T02 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** No explicit snapshot needed — `git show HEAD:scripts/dispatch/dispatch-interface.sh` is the baseline.

3. **Add the `_di_tier_at_rank` helper** (Block A) immediately after `_di_tier_rank` (around line 188).

4. **Add the `_di_emit_escalation_cap_hit` helper** (Block D) alongside `_di_emit_dispatch_usage` (around line 515). Place AFTER the existing function so the existing function is unaffected.

5. **Declare top-level `escalation_count` and `escalation_reason` shell-scoped variables** before the BACKEND resolution block (around line 545). Initialize to `0` and `""` respectively. These are read by `_di_emit_dispatch_usage`'s printf branches.

6. **Extend the printf format strings** in `_di_emit_dispatch_usage` (Block C). The two shadow-on printfs (lines ~453 + ~486) gain `,"escalation_count":%d,"escalation_reason":"%s"` after `,"override_source":"%s"`. Append `"$escalation_count" "$escalation_reason"` to the args list.

   The two shadow-OFF printfs (lines ~468 + ~501) are UNCHANGED — SC-11 byte-equality preserved.

7. **Wrap the adapter invocation in the escalation loop** (Block B). The current adapter invocation block (post-T02) is at line ~580-617. T03 amends it to:

   - Detect live-mode escalation eligibility (`M030_SHADOW_MODE=1` AND `CLAUDECODE=1` AND `_DI_LIVE_MODEL_FLAG` non-empty).
   - When eligible: enter the loop. On rc=0, emit happy-path record + break. On rc!=0 with count<2, emit record with `verifier_fail`, increment, recompute next tier, re-resolve `_DI_LIVE_MODEL_FLAG`, loop. On rc!=0 with count>=2, emit final record with `verifier_fail`, emit `escalation_cap_hit`, emit dispatch-error, exit 5.
   - When not eligible: fall through to the existing single-shot invocation (preserves T02 + pre-T02 behavior).

   Critical: the conformance-check block (line ~600-617) and the happy-path emit (line ~620) must continue to fire correctly on the loop's break-on-success path. Concretely, the loop's success path emits the dispatch_usage record INSIDE the loop body, then breaks; the existing happy-path emit at line ~620 must NOT fire a second time (would produce a duplicate record). The simplest fix: gate the existing happy-path emit at line ~620 on `escalation_active=0` (skip when the loop already emitted).

8. **Author `tools/verify/p04-sc4-escalation-sequence.sh`** per the shape in the Description. Stage tmp_root + counter file (value=2) + invocations file. Standard live-mode env vars + corpus injection. Six assertions:
   - dispatch-interface exits 0.
   - Exactly 3 dispatch_usage records.
   - Record 1 `model_used`=resolution.fast.claude-code (extracted at runtime).
   - Record 2 `model_used`=resolution.balanced.claude-code.
   - Record 3 `model_used`=resolution.smart.claude-code.
   - Record 3 `escalation_count=2`, `escalation_reason=""` (success).

9. **Author `tools/verify/p04-sc5-escalation-cap.sh`** per the shape in the Description. Counter starts at 3. Assertions:
   - dispatch-interface exits nonzero.
   - Exactly 3 dispatch_usage records.
   - Exactly 1 escalation_cap_hit record.
   - escalation_cap_hit record `final_count=2`, `unitId` matches dispatch_usage unitId.
   - Each dispatch_usage record has `escalation_reason=verifier_fail`.
   - Record 3 has `escalation_count=2`.

10. **Author `tools/verify/p04-con5-no-fourth-record.sh`** per the shape in the Description. Counter starts at 4. Same assertions as SC-5 plus:
    - `STUB_FAIL_COUNTER_INVOCATIONS_FILE` contains exactly 3 lines.

11. **Author `tools/verify/p04-con6-prior-records-bit-identical.sh`** per the shape in the Description (inode-preservation + first-two-lines hash equality after synthetic append):

    - Stage tmp_root + counter file (value=2). Capture inode of `$LOG_FILE`'s parent dir's expected log path BEFORE dispatch. (Note: log file doesn't exist before dispatch; capture inode of the parent dir as a stand-in, OR run a no-op append first to create the file with a known inode.)
    - Approach: `touch "$LOG_FILE"; INODE_BEFORE=$(stat ... "$LOG_FILE")`.
    - Run the dispatch (3 records emitted).
    - Capture `INODE_AFTER=$(stat ... "$LOG_FILE")`.
    - Capture `HASH_PRE=$(head -n 2 "$LOG_FILE" | shasum -a 256 | cut -d' ' -f1)`.
    - Append a synthetic line: `printf 'synthetic\n' >> "$LOG_FILE"`.
    - Capture `HASH_POST=$(head -n 2 "$LOG_FILE" | shasum -a 256 | cut -d' ' -f1)`.
    - Assert `INODE_BEFORE == INODE_AFTER` (no `mv`/swap).
    - Assert `HASH_PRE == HASH_POST` (first 2 lines unchanged after append).
    - Assertions count: 2 (inode + hash).

    Note: the `head ... | shasum ... | cut ...` chain is a 3-link pipe. Per AP-009, this is at the boundary of "compound chain >2". Use tmp-file intermediates to keep AD-19-clean:

    ```bash
    head -n 2 "$LOG_FILE" > /tmp/p04-con6-head.txt
    shasum -a 256 /tmp/p04-con6-head.txt > /tmp/p04-con6-shasum.txt
    HASH_PRE="$(cut -d' ' -f1 < /tmp/p04-con6-shasum.txt)"
    rm -f /tmp/p04-con6-head.txt /tmp/p04-con6-shasum.txt
    ```

12. **Author `tools/verify/p04-escalation-fields-enum.sh`** per the shape in the Description. Three scenarios (no-failure, fail-twice-then-pass, fail-three-times). Assert per-record `escalation_count` + `escalation_reason` values match the expected sequences. ~7 assertions total (1 + 3 + 3).

13. **Amend `references/model-routing.md`** to add the `## Live Routing` section per the Description. Insert AFTER the existing `## Operator Overrides` section and BEFORE the `## See Also` section. Update the `## See Also` bullets to include the new `## Live Routing` section.

14. **Re-run all T01 + T02 + T03 verifiers as a self-check:**

    ```bash
    bash tools/verify/p04-additive-schema.sh
    bash tools/verify/p04-override-source-enum-extended.sh
    bash tools/verify/p04-sc2a-shadow-gate-block.sh
    bash tools/verify/p04-sc3-live-mechanical.sh
    bash tools/verify/p04-partial-flip-routing.sh
    bash tools/verify/p04-con3-live-closure.sh
    bash tools/verify/p04-con4-live-killswitch.sh
    bash tools/verify/p04-sc4-escalation-sequence.sh
    bash tools/verify/p04-sc5-escalation-cap.sh
    bash tools/verify/p04-con5-no-fourth-record.sh
    bash tools/verify/p04-con6-prior-records-bit-identical.sh
    bash tools/verify/p04-escalation-fields-enum.sh
    ```

    Expected: all twelve exit 0.

    If `p04-additive-schema.sh` fails: the shadow-off printfs were accidentally modified — revert Step 6 changes to lines ~468 + ~501 (those branches must remain byte-identical to pre-T03).

    If `p04-sc3-live-mechanical.sh` fails post-T03: the happy-path emit at line ~620 may be firing duplicate records. Re-check Step 7's gate on `escalation_active`.

    If `p04-sc4-escalation-sequence.sh` fails on the model_used sequence: the `_di_tier_at_rank` increment logic may be off. Trace through: count=0 → fast (initial); after first fail count=1, tier=balanced; after second fail count=2, tier=smart; success at count=2. The third record's `model_used` is the smart-tier resolution.

    If `p04-con6-prior-records-bit-identical.sh` fails on inode comparison: `mkdir -p` may be creating a new inode each time. Use `:>` instead of `touch` to force file creation.

15. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `references/model-routing.md`, all five new T03 verifier scripts. Write commit message file via Write to `/tmp/p04-t03-commit-msg.txt`; commit with `git commit -F /tmp/p04-t03-commit-msg.txt`. Recommended subject: `M030/P04/T03: dispatch-interface escalation loop + CON-5 cap + escalation_cap_hit + CON-6 verifier`.

## Must-Haves

This task satisfies the phase truths:

- "SC-4 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 2 — fail twice then pass) ..." — gated by `tools/verify/p04-sc4-escalation-sequence.sh`.
- "SC-5 holds: with model_routing.live: true AND a ready-verdict shadow corpus AND the stub-fail-n.sh adapter (counter starts at 3 — fail every attempt) ..." — gated by `tools/verify/p04-sc5-escalation-cap.sh`.
- "CON-5 hard-cap (no-fourth-record) gate ..." — gated by `tools/verify/p04-con5-no-fourth-record.sh`.
- "CON-6 prior-records-bit-identical gate ..." — gated by `tools/verify/p04-con6-prior-records-bit-identical.sh`.
- "New JSONL field escalation_count (integer, 0..2) appears on every shadow-on dispatch_usage record post-T03 ..." — gated by `tools/verify/p04-escalation-fields-enum.sh`.

## Verification

```bash
bash tools/verify/p04-additive-schema.sh
bash tools/verify/p04-override-source-enum-extended.sh
bash tools/verify/p04-sc2a-shadow-gate-block.sh
bash tools/verify/p04-sc3-live-mechanical.sh
bash tools/verify/p04-partial-flip-routing.sh
bash tools/verify/p04-con3-live-closure.sh
bash tools/verify/p04-con4-live-killswitch.sh
bash tools/verify/p04-sc4-escalation-sequence.sh
bash tools/verify/p04-sc5-escalation-cap.sh
bash tools/verify/p04-con5-no-fourth-record.sh
bash tools/verify/p04-con6-prior-records-bit-identical.sh
bash tools/verify/p04-escalation-fields-enum.sh
```

Each verifier uses single-script-file shape per AD-19. All twelve must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- All T01 fixture plans + configs + corpora + stub adapters (T01) — Key API: stub-fail-n.sh consumes `STUB_FAIL_COUNTER_FILE` env var (counter file with single integer; read-decrement on each invocation; rc=1 if remaining>0 else rc=0). Side-channel: `STUB_FAIL_COUNTER_INVOCATIONS_FILE` env var receives one append per invocation; `STUB_INVOCATION_SENTINEL_DIR` env var receives sentinel files.
- scripts/dispatch/dispatch-interface.sh (post-T02) — Key API: live-routing branch reads `model_routing.live`; on `ready` verdict + flippable class, sets `_DI_LIVE_MODEL_FLAG=<resolution.<tier>.claude-code>`; adapter invocation conditionally passes `--model "$_DI_LIVE_MODEL_FLAG"`; `_DI_LIVE_GATE_BLOCKED=1` short-circuits adapter invocation.
- tools/verify/p04-additive-schema.sh, p04-override-source-enum-extended.sh, p04-sc2a-shadow-gate-block.sh, p04-sc3-live-mechanical.sh, p04-partial-flip-routing.sh, p04-con3-live-closure.sh, p04-con4-live-killswitch.sh (T01/T02) — Key API: each `bash <path>` exits 0; `SUMMARY:` line emitted with pass-count.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T03 form (post-T02). T03 amends `_di_emit_dispatch_usage` printfs + dispatcher-level adapter invocation block.
  - Key API: post-T02 the function emits 6 P02/P03 fields under shadow-on (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `override_source`). Post-T03 adds 2 more fields: `escalation_count` (integer 0..2) + `escalation_reason` (string).
- scripts/diagnostics/shadow-compare.sh — P02/T03 deliverable. Used by T02's live-routing branch.
- scripts/dispatch/classify-task.sh — P01/T02 classifier. Used indirectly via shadow-mode dispatch.
- templates/model-routing.yml — P01/T03 SSOT. T03's escalation loop reads `resolution.<tier>.claude-code` to recompute `_DI_LIVE_MODEL_FLAG` after each escalation.
- references/model-routing.md — post-P03/T03 form (with `## Operator Overrides` section). T03 amends to add `## Live Routing` section.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` and the new `_di_emit_escalation_cap_hit` helper inherit the dispatch-internal-emitter carve-out — pipes / awk / `$()` permitted in their bodies. The escalation loop body in the dispatcher is also dispatch-internal and inherits the same carve-out (MEM004 applies to dispatch-internal logic broadly).
- **AP-009 compound-chain-gt2 (verifier shape)**: the five T03 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates throughout. The CON-6 verifier's `head ... | shasum ... | cut ...` chain MUST be unrolled into tmp-file stages.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: the shadow-OFF `printf` format strings MUST be byte-identical to the post-T02 form (which equals the post-P03 form). T03's amendment touches ONLY the shadow-on printfs (lines ~453 + ~486) and the new `_di_emit_escalation_cap_hit` helper — NEVER the shadow-off printfs. Verified by `tools/verify/p04-additive-schema.sh`.
- **CON-3 (symbolic-tier closure)**: the escalation loop's tier progression uses `_di_tier_at_rank` (symbolic only) and re-resolves `_DI_LIVE_MODEL_FLAG` via the awk section-walker against `templates/model-routing.yml resolution.<tier>.claude-code` — no hardcoded provider model IDs introduced. Verified by `tools/verify/p04-con3-live-closure.sh` (still passing post-T03).
- **CON-4 / D-A5 (kill switch supersedes live AND escalation)**: when `model_routing_enabled: false`, the kill-switch path short-circuits BEFORE the live-mode block runs. The escalation loop is gated on `_DI_LIVE_MODEL_FLAG` non-empty — under kill-switch this is unset, so the loop never engages. Verified by `tools/verify/p04-con4-live-killswitch.sh` (still passing post-T03).
- **CON-5 (escalation hard-cap)**: at `escalation_count >= 2` AND rc != 0, the loop MUST emit the final dispatch_usage record + the escalation_cap_hit record + exit 5 WITHOUT a fourth adapter invocation. Verified by `tools/verify/p04-sc5-escalation-cap.sh` and `tools/verify/p04-con5-no-fourth-record.sh`.
- **CON-6 (append-only shadow corpus)**: each loop iteration uses `>> "$log_file"` only via `_di_emit_dispatch_usage`. The `_di_emit_escalation_cap_hit` helper also uses `>>` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `tools/verify/p04-con6-prior-records-bit-identical.sh` (inode preservation + first-two-lines hash equality).
- **D-A2 (programmatic flip-gate enforcement)**: T02 already enforces this; T03 does not weaken the check. The escalation loop runs only AFTER the flip-gate has been cleared (verdict is ready or partially_ready with flippable class).
- **CC-only launch posture**: escalation path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1` AND `_DI_LIVE_MODEL_FLAG` non-empty. Codex CLI / Cursor cannot reach the escalation loop (live mode never engages on those runtimes per the existing T02 gate).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The escalation loop uses `while : ; do ... done` (POSIX-safe).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 introduces no SQL — N/A.

## Expected Output

- scripts/dispatch/dispatch-interface.sh — amended with `_di_tier_at_rank` helper + `_di_emit_escalation_cap_hit` helper + escalation loop wrapping the adapter invocation + extended shadow-on printf format strings (`escalation_count` + `escalation_reason` fields). Shadow-off printfs unchanged.
- references/model-routing.md — amended with new `## Live Routing` section between `## Operator Overrides` and `## See Also`; `## See Also` bullets updated.
- tools/verify/p04-sc4-escalation-sequence.sh — green: 6 assertions (3 model_used per record + dispatch exit 0 + record count + final escalation_count).
- tools/verify/p04-sc5-escalation-cap.sh — green: 6 assertions (dispatch exit nonzero + record count + cap_hit count + cap_hit fields + per-record reason + final count).
- tools/verify/p04-con5-no-fourth-record.sh — green: 7 assertions (SC-5's six + invocation count == 3).
- tools/verify/p04-con6-prior-records-bit-identical.sh — green: 2 assertions (inode preserved + head-2 hash unchanged after synthetic append).
- tools/verify/p04-escalation-fields-enum.sh — green: 7 assertions (1 + 3 + 3 across three scenarios).
- bash tools/verify/p04-sc4-escalation-sequence.sh exits 0 with `SUMMARY: p04-sc4-escalation-sequence.sh pass=6 fail=0`.
- bash tools/verify/p04-sc5-escalation-cap.sh exits 0 with `SUMMARY: p04-sc5-escalation-cap.sh pass=6 fail=0`.
- bash tools/verify/p04-con5-no-fourth-record.sh exits 0 with `SUMMARY: p04-con5-no-fourth-record.sh pass=7 fail=0`.
- bash tools/verify/p04-con6-prior-records-bit-identical.sh exits 0 with `SUMMARY: p04-con6-prior-records-bit-identical.sh pass=2 fail=0`.
- bash tools/verify/p04-escalation-fields-enum.sh exits 0 with `SUMMARY: p04-escalation-fields-enum.sh pass=7 fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-sc4-escalation-sequence.sh` -> 6 assertions pass; `SUMMARY: p04-sc4-escalation-sequence.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-sc5-escalation-cap.sh` -> 6 assertions pass; `SUMMARY: p04-sc5-escalation-cap.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p04-con5-no-fourth-record.sh` -> 7 assertions pass; `SUMMARY: p04-con5-no-fourth-record.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p04-con6-prior-records-bit-identical.sh` -> 2 assertions pass; `SUMMARY: p04-con6-prior-records-bit-identical.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p04-escalation-fields-enum.sh` -> 7 assertions pass; `SUMMARY: p04-escalation-fields-enum.sh pass=7 fail=0`, exit 0.

The escalation-loop emit-vs-increment ordering is subtle. Iteration 1 (initial dispatch): adapter invoked at tier=fast (count=0). On success, emit (count=0, reason=""). On failure, emit (count=0, reason=verifier_fail), THEN increment count to 1, recompute tier=balanced. Iteration 2: adapter invoked at tier=balanced (count=1). On success, emit (count=1, reason=""). On failure, emit (count=1, reason=verifier_fail), THEN increment count to 2, recompute tier=smart. Iteration 3: adapter invoked at tier=smart (count=2). On success, emit (count=2, reason=""). On failure: this is cap-hit. Emit (count=2, reason=verifier_fail), then emit escalation_cap_hit, then exit 5.

The third dispatch_usage record in the SC-4 fail-twice-then-pass scenario has `escalation_count=2` and `escalation_reason=""` — the reason is empty on the success record because the third attempt itself was not a verifier failure. The demo language "the third carries `escalation_count=2`" is precise; it does NOT say `escalation_reason=verifier_fail` on the third record.

For the SC-5 fail-three-times scenario, the third record has `escalation_count=2` and `escalation_reason=verifier_fail` (the third attempt itself failed and triggered the cap). The escalation_cap_hit record's `final_count=2` matches the third record's `escalation_count=2`.

The CON-6 prior-records-bit-identical test is an inode-preservation + head-2-hash check rather than a true mid-escalation inspection because dispatch-interface.sh is synchronous — there's no seam between adapter invocations where the verifier can inject a hash capture without modifying dispatch-interface.sh itself. The synthetic-append + head-2-hash-equality check is the mechanically-verifiable proxy for "appending records does not mutate prior records' bytes" (which is what CON-6 actually asserts at the file-system level). The inode-preservation check additionally rules out the `cp old new; mv new old` swap shape.

If the executor wants a STRONGER CON-6 test, the alternative is to use `STUB_INVOCATION_SENTINEL_DIR`: the stub-fail-n.sh drops a sentinel file on each invocation. The verifier could SPIN on the sentinel file's appearance (busy-wait with sleep 0.05) and capture the log file's first-two-lines hash between the second and third sentinel drops. This requires the verifier to run dispatch-interface.sh in the background and inspect the log file mid-execution — feasible but adds complexity. The simpler synthetic-append test is preferred.

The `## Live Routing` section in `references/model-routing.md` SHOULD include a verbatim reproduction of the verdict-to-action table (per the Description), the escalation chain (`fast → balanced → smart`, cap=2), and the operator workflow for flipping from shadow to live. This is operator-facing documentation; the audience is project maintainers reading the doc to understand the M030 routing layer's behavior.

If `p04-sc4-escalation-sequence.sh` fails on the third record's `model_used`, common causes are: (a) `_di_tier_at_rank` not defined (Step 3 missed), (b) the `_DI_LIVE_MODEL_FLAG` re-resolution awk block has a typo, (c) the loop's increment happens BEFORE the emit instead of AFTER. Trace: after iteration 1's failed emit (count=0, reason=verifier_fail), count must be incremented to 1 BEFORE iteration 2's adapter invocation at tier=balanced.

The amended `dispatch-interface.sh` after T03 will be approximately 100 lines longer than the post-T02 form (escalation loop + 2 helpers + 2 printf extensions). Bulk of the additions are the loop body and the helper functions; the printf extensions are 1-line each. The shadow-off printfs remain UNTOUCHED — the `p04-additive-schema.sh` gate continues to enforce SC-11 byte-equality.
