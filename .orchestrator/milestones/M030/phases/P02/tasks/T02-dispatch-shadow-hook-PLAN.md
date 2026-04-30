---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M030"
name: "dispatch-interface.sh shadow hook + classifier integration + CON-3 closure + append-only"
depends_on: ["T01"]
---

## Prerequisites

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` exists with 5+ canonical pre-M030 records (T01 close).
- `tests/fixtures/m030-p02/round-trip-stage/` exists with `phases/P01/tasks/T01-stage-PLAN.md`, `phases/P01/tasks/T01-stage-PAYLOAD.md`, `intensity-metadata.txt` (T01 close).
- `tools/verify/p02-fixture-shape.sh` exists and exits 0 (T01 close).
- `tools/verify/p02-additive-schema.sh` exists and exits 0 against the pre-amendment `dispatch-interface.sh` (T01 close).
- `scripts/dispatch/classify-task.sh` exists and emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout (P01/T02 close).
- `templates/model-routing.yml` exists with `routing:` (3 characters × 3 runtimes), `resolution:` (3 tiers × 3 runtimes), `cost_rates:` (3 tiers) sections (P01/T03 close).
- `references/model-routing.md` exists with `## Classifier-Confidence Stability Metric` section pinning numerics 0.10 / N=20 / 50 (P01/T03 close).
- `scripts/dispatch/dispatch-interface.sh` exists with `_di_emit_dispatch_usage` body at lines 185-311 (pre-P02 form).

Plan-time prerequisite-existence verification: every path above is asserted by T01's deliverables (T01 closes only when both verifiers exit 0); P01 deliverables are present per `.orchestrator/milestones/M030/phases/P01/P01-SUMMARY.md` `key_files:`. The pre-P02 `dispatch-interface.sh` shape was inspected during plan-authoring (head -311 reads cleanly; lines 283 + 298 contain the canonical `printf` templates).

## Description

T02 is the high-risk core amendment. Three deliverables that ship as a single coherent change:

1. **Amend `scripts/dispatch/dispatch-interface.sh`** — extend `_di_emit_dispatch_usage` so that when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`, the classifier runs and the routing-table choice is recorded as additive fields appended after `timestamp` (the current last field). When either env var is unset/0, the new code path is bypassed and the emitter behaves byte-identically to the pre-P02 form.

2. **`tools/verify/p02-shadow-emit.sh`** — gates the shadow-on path: `model_routed`/`model_used`/`partial_flip_active`/`withheld_classes` appear in the JSONL record when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`; do NOT appear when either env var is off (CC-only short-circuit + shadow-off short-circuit).

3. **`tools/verify/p02-con3-closure.sh`** — gates that no hardcoded model IDs appear in the diff that T02 introduces. Greps the post-amendment file for the closed set of provider model-ID patterns and asserts zero NEW occurrences (relative to the pre-amendment file).

4. **`tools/verify/p02-append-only.sh`** — gates that the shadow write path is append-only. Stages a fixture log file with N pre-existing records, runs an `M030_SHADOW_MODE=1` dispatch, and asserts: (a) the first N lines are byte-identical before and after; (b) exactly one new line was appended; (c) the file's inode is unchanged.

T02 also re-runs T01's `p02-additive-schema.sh` against the amended emitter to confirm that with shadow mode off, the byte-equality contract still holds.

### dispatch-interface.sh amendment shape (load-bearing detail)

The amendment is surgical. Locate `_di_emit_dispatch_usage` (line 185) and the two `printf` templates (lines 283 + 298). The shadow path is a pre-emit branch that computes two new values before the `printf` call:

```bash
# --- M030/P02/T02: shadow-mode classifier + routing-table fields ---
# Gated by BOTH env vars: M030_SHADOW_MODE=1 (operator flag) AND
# CLAUDECODE=1 (CC-only launch posture per CON-3 + spec edge case
# "Runtime that does not support model selection"). Codex CLI / Cursor
# fall through to the pre-P02 emit (no new fields).
shadow_routed=""
shadow_used=""
shadow_partial=""
shadow_withheld=""
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
  # 1. Classify the task plan (P01/T02 deliverable; FR-1 + FR-2).
  classifier_out="$(bash "$_DI_PROJECT_ROOT/scripts/dispatch/classify-task.sh" "$TASK_PLAN" 2>/dev/null)"
  shadow_character="$(printf '%s\n' "$classifier_out" | grep -E '^character=' | head -n 1 | sed 's/^character=//')"
  # 2. Resolve symbolic tier via templates/model-routing.yml routing: block.
  #    Awk section-walker (P01 pattern; no jq dependency).
  shadow_routed="$(awk -v ch="$shadow_character" '
    BEGIN { in_routing = 0; in_class = 0 }
    /^routing:/                       { in_routing = 1; next }
    in_routing && /^[a-z_]+:$/        { in_class = ($1 == ch ":") ? 1 : 0; next }
    in_routing && in_class && /claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
    /^resolution:/                    { exit }
  ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  # 3. Resolve symbolic tier -> runtime model ID via resolution: block.
  #    Same awk pattern, scoped to resolution: section.
  shadow_used="$(awk -v tier="$shadow_routed" '
    BEGIN { in_resolution = 0; in_tier = 0 }
    /^resolution:/                    { in_resolution = 1; next }
    in_resolution && /^[a-z_]+:$/     { in_tier = ($1 == tier ":") ? 1 : 0; next }
    in_resolution && in_tier && /claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
    /^cost_rates:/                    { exit }
  ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
  # 4. P03/P04 placeholders — emitted as no-op-empty in P02.
  shadow_partial="false"
  shadow_withheld=""
fi
```

The `printf` templates at lines 283 + 298 are amended to append four new fields after `timestamp`:

```text
,"model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"
```

with the trailing `\n` preserved at end. The `partial_flip_active` value is a JSON boolean literal (`false` / `true`, no surrounding quotes — that's why the format specifier is `%s` not `"%s"`). When shadow mode is off, the four shell variables are empty strings; the format string emits `,"model_routed":"","model_used":"","partial_flip_active":,"withheld_classes":""` which is INVALID JSON.

To preserve the additive-only-when-shadow-on invariant, the printf format string is itself selected at emit time:

```bash
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
  # Shadow-on emit: pre-M030 fields + 4 P02 additive fields.
  printf '{"record_type":"dispatch_usage",...,"timestamp":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"}\n' \
    ...existing_args... "$ts" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
    >> "$log_file" 2>/dev/null || ...
else
  # Shadow-off emit: byte-identical to pre-P02 (preserves SC-11).
  printf '{"record_type":"dispatch_usage",...,"timestamp":"%s"}\n' \
    ...existing_args... "$ts" \
    >> "$log_file" 2>/dev/null || ...
fi
```

Two parallel branches per emit-side (happy-path AND degradation path → 4 total `printf` invocations after the amendment). This is verbose but preserves SC-11 byte-equality for the shadow-off path mechanically: when neither env var is set, the original `printf` template runs unchanged.

### CC-only conditional discipline

The shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. Why both:

- `CLAUDECODE=1` is the runtime-detection signal Claude Code sets in dispatch contexts. Codex CLI does not set it; Cursor does not set it. This is the load-bearing CON-3 + edge-case "Runtime that does not support model selection" gate — only on Claude Code do we record the shadow fields.
- `M030_SHADOW_MODE=1` is the operator-controlled flag. It can be set on a per-session basis to opt into shadow recording without modifying any config file.

When `CLAUDECODE` is unset (Codex CLI, Cursor, non-orchestrator-direct invocations), the shadow branch is bypassed. The record is byte-identical to the pre-P02 shape. SC-11 byte-equality holds for these runtimes regardless of `M030_SHADOW_MODE`.

### CON-3 closure: zero hardcoded model IDs

The amendment's awk extraction reads `templates/model-routing.yml` at every dispatch (acceptable per FR-1 latency budget — awk on a ~100-line YAML is sub-millisecond). The result: dispatch-interface.sh contains no literal `claude-haiku-*`, `claude-sonnet-*`, `claude-opus-*`, `gpt-*`, `o1-*`, `o3-*`, or `gemini-*` strings. `p02-con3-closure.sh` greps for these patterns in the diff and asserts zero new occurrences.

The reference comment in the amendment block names `templates/model-routing.yml` so future readers see the indirection target without needing to chase the awk template.

### Append-only discipline (CON-6)

The new code path uses the same `>> "$log_file"` redirection as the existing emitter (line 290, 305). No `mv`, no `cp`, no temp-file-and-swap. The verifier (`p02-append-only.sh`) confirms via `stat` inode comparison that the file is unchanged in identity across the dispatch invocation; only its byte length grows.

This locks in the discipline P04 will inherit: escalation will produce NEW records with new timestamps, never rewrite prior records. P04 cannot break this without a new `mv`/`cp`/`>` (truncating) usage that would be caught by the same verifier.

## Steps

1. **Confirm T01 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-fixture-shape.sh
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: both exit 0. If either fails, T01 must be re-opened.

2. **Snapshot the pre-amendment `dispatch-interface.sh` for the CON-3 diff baseline.** The CON-3 verifier compares the post-amendment file against `git show HEAD:scripts/dispatch/dispatch-interface.sh`; the snapshot is whatever HEAD points at when T02 begins. No explicit snapshot file is needed — the verifier reads HEAD via `git show`.

3. **Amend `scripts/dispatch/dispatch-interface.sh`** per the shape described in the Description. Concretely:

   - Insert the shadow-mode classifier-and-resolution block after the existing `mkdir -p "$log_dir"` call (around line 273) and before the `if [ -n "$cost_usd" ] && [ -z "$warning" ]; then` happy-path branch (line 279). The new block is the four-step bash + awk routine described above.
   - Replace the single happy-path `printf` (line 283) with an `if/else` that selects the shadow-on vs shadow-off format string. The shadow-on format string adds four trailing fields (`,"model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s"`) before the closing `}`; the shadow-off format string is byte-identical to the pre-amendment form.
   - Same treatment for the degradation `printf` (line 298).
   - Both branches preserve the existing `>> "$log_file" 2>/dev/null || { ...; return 0; }` failure-handling shape.

4. **Re-run T01's `p02-additive-schema.sh` against the amended emitter.** The verifier runs with shadow off (`unset CLAUDECODE`, `unset M030_SHADOW_MODE`); the round-trip diff must come back empty.

   ```bash
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: exits 0, `SUMMARY: p02-additive-schema.sh pass=N fail=0`. If it fails, the shadow-off `printf` branch's format string differs from the pre-P02 form — re-author the format string verbatim from `git show HEAD:scripts/dispatch/dispatch-interface.sh:283` (or :298 for the degradation path). The format string is the byte-equality SSOT; even a re-ordering of escape sequences breaks SC-11.

5. **Author `tools/verify/p02-shadow-emit.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Exercises three scenarios:

   - **Scenario A — shadow on, CC on**: `export M030_SHADOW_MODE=1; export CLAUDECODE=1`. Stage a fixture log file (rm + touch). Invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan <stage>/T01-stage-PLAN.md --payload <stage>/T01-stage-PAYLOAD.md --intensity-metadata <stage>/intensity-metadata.txt --backend stub`. Read the appended JSONL line. Assert `grep -q '"model_routed"' <line>` AND `grep -q '"model_used"' <line>` AND `grep -q '"partial_flip_active"' <line>` AND `grep -q '"withheld_classes"' <line>`. Also assert the line is well-formed JSON (`grep -q '^{.*}$' <line>`).
   - **Scenario B — shadow off, CC on**: `unset M030_SHADOW_MODE; export CLAUDECODE=1`. Same staging + invocation. Assert NONE of the four shadow tokens appear in the appended line.
   - **Scenario C — shadow on, CC off (Codex CLI / Cursor simulation)**: `export M030_SHADOW_MODE=1; unset CLAUDECODE`. Same staging + invocation. Assert NONE of the four shadow tokens appear in the appended line (CC-only short-circuit).

   Each scenario uses a fresh log file at `<round-trip-stage>/execution-log.jsonl` (rm + touch before, rm after). Per-scenario pass/fail accumulators; final `SUMMARY: p02-shadow-emit.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

6. **Author `tools/verify/p02-con3-closure.sh`.** Bash 3.2-compatible. Greps both the pre-amendment HEAD version and the working-tree version of `scripts/dispatch/dispatch-interface.sh` for the closed set of provider model-ID patterns:

   - `claude-haiku-`
   - `claude-sonnet-`
   - `claude-opus-`
   - `gpt-`
   - `o1-`
   - `o3-`
   - `gemini-`

   For each pattern, count occurrences in HEAD version: `git show HEAD:scripts/dispatch/dispatch-interface.sh | grep -c -E '<pattern>' > /tmp/p02-con3-head-<n>.txt`. Count in working tree: `grep -c -E '<pattern>' scripts/dispatch/dispatch-interface.sh > /tmp/p02-con3-wt-<n>.txt`. Read both counts; assert working-tree count is <= HEAD count (i.e., T02's amendment did not INTRODUCE any provider model-ID literal). Cleanup: `rm -f /tmp/p02-con3-*.txt`.

   Per-pattern pass/fail; final `SUMMARY: p02-con3-closure.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

7. **Author `tools/verify/p02-append-only.sh`.** Bash 3.2-compatible. Stages a fixture log file with 5 pre-existing records (cat the T01 fixture into a fresh log), captures the file's inode via `stat -f '%i' <log> > /tmp/p02-inode-pre.txt` (macOS) or `stat -c '%i' <log> > /tmp/p02-inode-pre.txt` (GNU — use `uname -s` to dispatch), captures the first-N-lines content via `head -5 <log> > /tmp/p02-pre-content.txt`, captures line count via `wc -l < <log> > /tmp/p02-pre-lines.txt`. Then `export M030_SHADOW_MODE=1; export CLAUDECODE=1` and invokes `dispatch-interface.sh`. Re-captures inode + first-5-lines + line-count. Assertions:

   - Inode pre == post (file identity preserved — `diff /tmp/p02-inode-pre.txt /tmp/p02-inode-post.txt` exits 0).
   - First-5-lines pre == post (existing records bit-identical — `diff /tmp/p02-pre-content.txt /tmp/p02-post-content.txt` exits 0).
   - Post-line-count == pre-line-count + 1 (exactly one new record appended).

   Cleanup: `rm -f /tmp/p02-{inode,pre-content,post-content,pre-lines,post-lines}-*.txt`. Final `SUMMARY: p02-append-only.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

8. **Run all four T02 verifiers as a self-check:**

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   ```

   Expected: all four exit 0. If `p02-additive-schema.sh` fails, the shadow-off `printf` branch's format string differs from pre-amendment — fix Step 3. If `p02-shadow-emit.sh` Scenario A fails (shadow tokens missing under shadow-on), the format-string selection logic in Step 3 mis-branched — fix the env-var check. If Scenario B/C fails (shadow tokens leaking under shadow-off / CC-off), the gate is wrong — both env vars must be set for the shadow branch. If `p02-con3-closure.sh` fails, a literal model ID slipped into the amendment — replace with the awk-resolution pattern. If `p02-append-only.sh` fails on inode check, a `mv`/`cp` snuck in; on first-5-lines check, the emitter is rewriting prior records (CON-6 violation).

9. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh`, `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh`. Author commit message file via Write to `/tmp/p02-t02-commit-msg.txt`; commit with `git commit -F /tmp/p02-t02-commit-msg.txt`. Recommended message subject: `M030/P02/T02: dispatch-interface shadow hook + classifier + CON-3 closure + append-only`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/dispatch/dispatch-interface.sh` invokes the P01 classifier on every dispatch when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`..." — gated by `tools/verify/p02-shadow-emit.sh`.
- "The shadow-mode amendment to `dispatch-interface.sh` contains zero hardcoded model IDs..." — gated by `tools/verify/p02-con3-closure.sh`.
- "The shadow JSONL write path is append-only..." — gated by `tools/verify/p02-append-only.sh`.
- "SC-11 byte-equality holds..." — re-asserted by `tools/verify/p02-additive-schema.sh` against the amended emitter.

## Verification

```bash
bash tools/verify/p02-additive-schema.sh
bash tools/verify/p02-shadow-emit.sh
bash tools/verify/p02-con3-closure.sh
bash tools/verify/p02-append-only.sh
```

Each verifier uses single-script-file shape per AD-19. All four must exit 0 before T02 closes.

## Inputs

### From Previous Tasks

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (from T01)
  - Key API: 5+ canonical pre-M030 `dispatch_usage` JSONL records — the byte-equality golden file.
- `tests/fixtures/m030-p02/round-trip-stage/` (from T01)
  - Key API: `phases/P01/tasks/T01-stage-PLAN.md` + `phases/P01/tasks/T01-stage-PAYLOAD.md` + `intensity-metadata.txt` — fixture inputs for round-trip dispatch invocations.
- `tools/verify/p02-additive-schema.sh` (from T01)
  - Key API: `bash <path>` exits 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0` when shadow off + CC unset, byte-equality holds against the golden fixture.
- `tools/verify/p02-fixture-shape.sh` (from T01)
  - Key API: `bash <path>` exits 0 confirming fixture well-formedness.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — pre-P02 emitter at lines 185-311. T02 amends `_di_emit_dispatch_usage` body.
  - Key API: `_di_emit_dispatch_usage [warning_override]` writes one `dispatch_usage` record to `$log_file` per invocation. Function-internal access to `$TASK_PLAN`, `$PAYLOAD`, `$INTENSITY_METADATA`, `$BACKEND`, `$UNIT_ID`, `$MILESTONE_ID`, `$PHASE_ID`, `$TASK_ID`, `$ORCH_ROOT`, `$_DI_PROJECT_ROOT` (set in the parent script body before the function is invoked).
- `scripts/dispatch/classify-task.sh` — P01 classifier.
  - Key API: `bash scripts/dispatch/classify-task.sh <plan-path>` writes two stdout lines: `character=<mechanical|standard|novel>` and `confidence=<high|medium|low>`. Bash 3.2-safe, no network, <100ms wall-clock. Exit 0 on success; exit 1 on missing plan-path.
- `templates/model-routing.yml` — P01 routing-table SSOT.
  - Key API: YAML file with three top-level sections. Closure invariant: every symbolic-tier reference in `routing:` resolves to an entry in `resolution:`. Per-runtime: `claude-code` always resolves to a concrete model ID; `codex-cli` and `cursor` resolve to literal `inherit`.
- `references/model-routing.md` — operator docs (T03 will consume the stability-metric section, not T02).
- `scripts/dispatch/adapters/backend/stub.sh` — minimal adapter for round-trip harness invocations.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The amendment to `dispatch-interface.sh` is internal code; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: `_di_emit_dispatch_usage` already declares (line 184) that pipes / `awk` / `$()` are permitted in its body as a dispatch-internal carve-out. T02's amendment extends that carve-out — the new awk extraction blocks are body-internal and are NOT subject to AD-19's outer-invocation shape rules.
- **AP-009 compound-chain-gt2 (verifier shape)**: the four T02 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>; grep ... < /tmp/<f> > /tmp/<g>; head -1 < /tmp/<g>`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **CON-2/FR-19/SC-11 (additive-only schema)**: the shadow-off `printf` format strings MUST be byte-identical to the pre-amendment form. T01's golden fixture is the SSOT; if Step 4's re-run of `p02-additive-schema.sh` fails, the format string is wrong.
- **CON-3 (symbolic-tier closure)**: zero literal provider model IDs in `dispatch-interface.sh`. The awk extraction reads `templates/model-routing.yml` at every dispatch. Verified by `p02-con3-closure.sh` (HEAD-vs-working-tree count comparison per pattern).
- **CON-6 (append-only shadow corpus)**: the new code path uses `>> "$log_file"` only. No `mv`, no `cp`, no truncating `>`, no temp-file-and-swap. Verified by `p02-append-only.sh` (inode + first-N-lines + line-count comparison).
- **CC-only launch posture**: shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. Codex CLI / Cursor short-circuit to the pre-P02 emit. Verified by `p02-shadow-emit.sh` Scenario C.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The awk blocks are POSIX awk, not gawk-extended.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 does NOT introduce SQL — N/A.

## Expected Output

- `scripts/dispatch/dispatch-interface.sh` — amended `_di_emit_dispatch_usage` body with shadow-mode classifier hook + four additive fields, gated by `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`. Shadow-off `printf` branch byte-identical to pre-amendment.
- `tools/verify/p02-shadow-emit.sh` — green: shadow tokens present under shadow-on + CC-on, absent under shadow-off OR CC-off.
- `tools/verify/p02-con3-closure.sh` — green: zero provider-model-ID literals introduced by the amendment.
- `tools/verify/p02-append-only.sh` — green: log file inode + prior records preserved across shadow-on dispatch.
- `bash tools/verify/p02-additive-schema.sh` exits 0 (re-confirmed against amended emitter).
- `bash tools/verify/p02-shadow-emit.sh` exits 0 with `SUMMARY: p02-shadow-emit.sh pass=N fail=0`.
- `bash tools/verify/p02-con3-closure.sh` exits 0 with `SUMMARY: p02-con3-closure.sh pass=N fail=0`.
- `bash tools/verify/p02-append-only.sh` exits 0 with `SUMMARY: p02-append-only.sh pass=N fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p02-shadow-emit.sh` → 3 scenarios pass (12 token-presence/absence checks total); `SUMMARY: p02-shadow-emit.sh pass=12 fail=0`, exit 0.
- `bash tools/verify/p02-con3-closure.sh` → 7 patterns checked, all `working-tree count <= HEAD count`; `SUMMARY: p02-con3-closure.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p02-append-only.sh` → 3 invariants pass (inode unchanged, first-5-lines unchanged, line-count delta = +1); `SUMMARY: p02-append-only.sh pass=3 fail=0`, exit 0.

The amendment's `awk` extraction blocks are the load-bearing CON-3 mechanism. They are intentionally inline in `dispatch-interface.sh` rather than factored out to a helper because the function is already past the line count where pure-lib extraction (MEM004 pattern) pays off. If T03/T04 grows further dispatch-side routing logic, P03 should consider extracting `_di_resolve_routing()` into `scripts/dispatch/lib/routing-resolve.sh` and sourcing it. P02 keeps the logic inline to minimize the amendment surface.

P03 will consume the four shadow fields T02 emits: `model_routed` for override-source comparison, `model_used` for live-routing baseline, `partial_flip_active` + `withheld_classes` for the per-class flip-activation path. T02's emit-as-no-op-empty for the latter two is the schema reservation P03 builds on.

If the awk YAML extraction proves brittle (e.g., the `templates/model-routing.yml` syntax shifts in a future edit), the fallback shape is: source `scripts/util/json-field.sh` and adopt a YAML-to-JSON converter. P02 explicitly does NOT introduce that dependency — the awk approach is sufficient for the current YAML structure (P01's `awk` section-walker pattern is the precedent per P01-SUMMARY.md `patterns_established:` "Awk section-walker for YAML closure-check").
