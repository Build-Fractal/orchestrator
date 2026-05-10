---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M030"
name: "dispatch-interface character emit + check-anomalies model_routing_regression check + co-authored verifiers + references doc amendment"
depends_on: ["T01"]
---

## Prerequisites

- T01 deliverables on disk and green:
  - `tests/fixtures/m030-p06/synthesize-corpus.sh` (executable; idempotent).
  - `tests/fixtures/m030-p06/regression-mechanical.jsonl` — 20 records, `character=mechanical`, 12 fail / 8 pass.
  - `tests/fixtures/m030-p06/regression-standard.jsonl` — 20 records, `character=standard`, 12 fail / 8 pass.
  - `tests/fixtures/m030-p06/regression-novel.jsonl` — 20 records, `character=novel`, 12 fail / 8 pass.
  - `tests/fixtures/m030-p06/no-regression.jsonl` — 60 records, per-class 4 fail / 16 pass.
  - `tests/fixtures/m030-p06/below-min-sample.jsonl` — 5 mechanical records, 3 fail / 2 pass.
  - `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` — pre-amendment golden.
  - `tools/verify/p06-sc11-byte-equality.sh` — exits 0 against HEAD.
- `scripts/diagnostics/check-anomalies.sh` is in its post-M027/[M018](../../../../../milestones/M018/index.md) form. Key surface T02 will amend:
  - The CLI dispatch path after argparse (lines ~210-289) — add a new function `_ca_model_routing_regression_check` invoked AFTER the legacy `check_anomalies_render` returns, so the legacy block emits unchanged byte-equality is preserved when no `model_routing_regression` fires.
  - The argparse loop (lines ~211-225) — add `--threshold-pass-rate <float>`, `--min-class-sample <N>`, and `--anomalies-jsonl-path <path>` flags (or only `--threshold-pass-rate` and `--min-class-sample`, with the JSONL emit path resolved exclusively from `M030_ANOMALIES_JSONL_PATH` env + project-default — recommended: env-only so the CLI surface stays narrow).
  - Bash 3.2 compatibility preserved (parallel scalars; no `declare -A`; no `mapfile`).
- `scripts/dispatch/dispatch-interface.sh` is in its post-P04 form with the shadow-on emit branch carrying the 9-field schema. Key surface T02 will amend:
  - The shadow-on emit printf format string (P04/T03's `_di_emit_dispatch_usage` body) — append `,"character":"%s"` to the format and append the `character_value` arg to the printf args list. The character is already in scope at emit-time as a local variable from the classifier invocation in `_di_resolve_live_routing` (or `_di_resolve_shadow_routing`); T02 plumbs it through to the emit.
  - The shadow-OFF emit branch is byte-untouched. The new field appears ONLY when `M030_SHADOW_MODE=1 && CLAUDECODE=1` is satisfied.
- `templates/model-routing.yml` carries the shipped `routing:` block (3 chars × 3 runtimes; default `mechanical→fast / standard→balanced / novel→smart` for claude-code). T02 reads the block at check-anomalies runtime to validate that the active routing config has not removed a class from the per-class iteration set.
- `references/model-routing.md` exists with the existing P01–P05 sections (`## Operator Overrides`, `## Live Routing`, `## Cost Rollup Surfaces`). T02 appends a `## Anomaly Records` section after `## Cost Rollup Surfaces`.

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. T02 entry runs `bash tools/verify/p06-sc11-byte-equality.sh && echo $?` (logical equivalent — actually run as a single script `bash <path>` and check `$?`) to confirm T01 is green before any amendment.

## Description

T02 lands the FR-18 anomaly-driven regression detection — extends `check-anomalies.sh` with a per-class verifier-fail-rate check that emits a `model_routing_regression` record (text + JSONL) when a class crosses the configured threshold, and amends `dispatch-interface.sh` shadow-on emit additively to include the `character` field that the new check groups by. Six deliverable groups:

1. **`dispatch-interface.sh` shadow-on `character` emit** — additive single-field amendment.
2. **`check-anomalies.sh` model_routing_regression check** — new function + integration into CLI dispatch.
3. **Co-authored scenario-specific verifiers** (6 new gates).
4. **`references/model-routing.md` amendment** — `## Anomaly Records` section.
5. **Re-run T01's SC-11 gate** against the post-amendment surface to confirm byte-equality holds.
6. **Co-author `p06-shadow-off-byte-equality.sh`** — wraps P02's `p02-additive-schema.sh` to confirm dispatch-interface shadow-OFF byte-equality.

### `dispatch-interface.sh` shadow-on `character` emit

The amendment is a one-field additive extension to the shadow-on emit branch only. P04/T02 introduced the helper `_di_resolve_live_routing` that already invokes `classify-task.sh` and captures the `character=<C>` line. T02 plumbs the captured character through to the emit:

```bash
# In _di_resolve_live_routing or wherever the classifier output is captured:
classifier_out="$(bash "$_DI_PROJECT_ROOT/scripts/dispatch/classify-task.sh" "$plan_path" 2>/dev/null || true)"
# Existing: extract character + confidence
character_value="$(printf '%s\n' "$classifier_out" | sed -n 's/^character=\(.*\)$/\1/p' | head -n 1)"
classifier_confidence_value="$(printf '%s\n' "$classifier_out" | sed -n 's/^confidence=\(.*\)$/\1/p' | head -n 1)"
# Existing: route to tier via templates/model-routing.yml
# ...

# Existing top-level export (parent-shell scope so _di_emit_dispatch_usage reads it):
_DI_SHADOW_CHARACTER="$character_value"
```

Then in `_di_emit_dispatch_usage`'s shadow-on printf (the dual-branch P04/T03 established):

```bash
# BEFORE (P04/T03 shipped):
printf '{...,"escalation_count":%s,"escalation_reason":"%s"}\n' "$esc_count" "$esc_reason" >> "$log"

# AFTER (T02 amendment — additive trailing field):
printf '{...,"escalation_count":%s,"escalation_reason":"%s","character":"%s"}\n' "$esc_count" "$esc_reason" "${_DI_SHADOW_CHARACTER:-unknown}" >> "$log"
```

The `${_DI_SHADOW_CHARACTER:-unknown}` default guards against any code path that emits a shadow-on record without setting the character (defense-in-depth; should not fire in practice). The `unknown` value is documented in references/model-routing.md as a valid-but-warning state — the per-class anomaly check skips records with `character=unknown` (treats them as no-class signal).

The shadow-OFF printf branch is byte-untouched. The new field appears ONLY when `M030_SHADOW_MODE=1 && CLAUDECODE=1` is satisfied. P02's `p02-additive-schema.sh` (round-trips a record through dispatch-interface under shadow-off and asserts byte-identity against a pre-amendment fixture) is the contract — T02 re-runs it post-amendment to confirm shadow-off byte-equality holds.

### `check-anomalies.sh` model_routing_regression check

The amendment introduces:

- A new function `_ca_model_routing_regression_check` near the bottom of `check-anomalies.sh` (after `check_anomalies_render`).
- New flags in the CLI argparse loop:
  - `--threshold-pass-rate <float>` (default 0.5; pass-rate floor below which a class triggers regression)
  - `--min-class-sample <N>` (default 10; minimum per-class sample size to trigger regression)
  - (`--anomalies-jsonl-path` is NOT exposed as a CLI flag; resolved exclusively from `M030_ANOMALIES_JSONL_PATH` env + project default `.orchestrator/anomalies.jsonl`. Narrows the CLI surface; mirrors the existing convention of env-var seams for fixture redirection.)
- Config-knob resolution via `read-config.sh` (mirrors existing pattern):
  - `model_routing_regression.pass_rate_threshold` (default 0.5)
  - `model_routing_regression.min_class_sample` (default 10)
- A new branch in the CLI entry point (after `check_anomalies_render` returns) that invokes `_ca_model_routing_regression_check` against the active milestone's execution-log.

#### `_ca_model_routing_regression_check` function shape

```bash
# _ca_model_routing_regression_check <milestone-or-empty> <pass-rate-thresh> <min-class-sample> <jsonl-emit-path>
#
# Reads execution-log.jsonl for shadow-on dispatch_usage records carrying
# the `character` field (additively introduced by M030/P06/T02). Groups by
# character class. Computes per-class pass-rate as:
#   pass_rate = pass_count / sample_count
#     where pass_count = records with escalation_count=0 AND escalation_reason=""
#     where sample_count = records with character=<C>
# When sample_count >= min_class_sample AND pass_rate < pass_rate_thresh,
# emits a `FLAGGED model_routing_regression class=<C> ...` line to stdout
# AND appends a JSONL anomaly record to the configured emit path.
#
# Invariants:
# - Idempotent stdout: same input → same stdout (modulo timestamp on JSONL
#   record, which is appended-not-rewritten so stdout is unaffected).
# - Read-only on execution-log.jsonl. Append-only on anomalies.jsonl.
# - Exit 0 always (CON-5 never-abort, mirrors check_anomalies_render).
# - Bash 3.2 compatible: parallel scalars, awk for parsing, no `declare -A`.
_ca_model_routing_regression_check() {
  local milestone="$1"
  local pass_rate_thresh="$2"
  local min_class_sample="$3"
  local jsonl_path="$4"
  local log_path

  # Resolve the execution-log path. ORCHESTRATOR_ROOT + milestone for
  # fixture-routing; falls back to project default.
  local orch_root="${ORCHESTRATOR_ROOT:-$_CA_PROJECT_ROOT/.orchestrator}"
  if [ -n "$milestone" ]; then
    log_path="$orch_root/milestones/$milestone/execution-log.jsonl"
  else
    log_path="$orch_root/execution-log.jsonl"
  fi

  if [ ! -f "$log_path" ]; then
    return 0
  fi

  # Per-class counters (parallel scalars, Bash 3.2 compatible).
  local mech_total=0; local mech_pass=0
  local std_total=0; local std_pass=0
  local nov_total=0; local nov_pass=0

  # Single-pass awk: parse each line, look for character=<C> and
  # escalation_count=0 + escalation_reason="" simultaneously.
  # The JSONL fields are unordered so we can't rely on column position.
  # Use grep + awk with field anchors. Robust shape:
  #   read each line; if it contains "record_type":"dispatch_usage" AND
  #   "character":"<C>" AND <pass-pattern OR fail-pattern>, increment
  #   counters via awk's printf to a parsed-out scalar string we reassemble
  #   in Bash. Simplest: invoke awk once per class with a regex matcher.
  local awk_out
  awk_out="$(awk '
    BEGIN { mt=0; mp=0; st=0; sp=0; nt=0; np=0; }
    /"record_type":"dispatch_usage"/ {
      ch = "";
      if (match($0, /"character":"mechanical"/)) ch = "mechanical";
      else if (match($0, /"character":"standard"/)) ch = "standard";
      else if (match($0, /"character":"novel"/)) ch = "novel";
      else next;
      pass = 0;
      if (match($0, /"escalation_count":0/) && match($0, /"escalation_reason":""/)) pass = 1;
      if (ch == "mechanical") { mt++; if (pass) mp++; }
      if (ch == "standard")   { st++; if (pass) sp++; }
      if (ch == "novel")      { nt++; if (pass) np++; }
    }
    END { printf "%d %d %d %d %d %d", mt, mp, st, sp, nt, np; }
  ' "$log_path")"

  set -- $awk_out
  mech_total="$1"; mech_pass="$2"
  std_total="$3"; std_pass="$4"
  nov_total="$5"; nov_pass="$6"

  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  _ca_emit_class_regression() {
    local class="$1"
    local total="$2"
    local pass_count="$3"
    if [ "$total" -lt "$min_class_sample" ]; then
      return 0
    fi
    # Compute pass-rate as a 2-decimal float via awk (printf in Bash on a
    # division would need bc).
    local pass_rate
    pass_rate="$(awk -v p="$pass_count" -v t="$total" 'BEGIN { if (t == 0) { printf "0.00" } else { printf "%.2f", p / t } }')"
    # Threshold comparison via awk (Bash arithmetic doesn't do floats).
    local below
    below="$(awk -v r="$pass_rate" -v th="$pass_rate_thresh" 'BEGIN { if (r + 0 < th + 0) print "1"; else print "0" }')"
    if [ "$below" != "1" ]; then
      return 0
    fi
    # Emit the FLAGGED text line.
    local thresh_fmt
    thresh_fmt="$(awk -v th="$pass_rate_thresh" 'BEGIN { printf "%.2f", th + 0 }')"
    printf 'FLAGGED model_routing_regression class=%s class_pass_rate=%s sample=%d threshold=%s\n' \
      "$class" "$pass_rate" "$total" "$thresh_fmt"
    # Append the JSONL record.
    if [ -n "$jsonl_path" ]; then
      mkdir -p "$(dirname "$jsonl_path")"
      printf '{"record_type":"anomaly","kind":"model_routing_regression","class":"%s","class_pass_rate":%s,"class_sample":%d,"threshold":%s,"milestone":"%s","timestamp":"%s"}\n' \
        "$class" "$pass_rate" "$total" "$thresh_fmt" "${milestone:-}" "$now" \
        >> "$jsonl_path"
    fi
  }

  _ca_emit_class_regression "mechanical" "$mech_total" "$mech_pass"
  _ca_emit_class_regression "standard"   "$std_total"  "$std_pass"
  _ca_emit_class_regression "novel"      "$nov_total"  "$nov_pass"

  return 0
}
```

#### CLI integration

After `check_anomalies_render "$MILESTONE" ... "$COMPRESSION_FLOOR"` returns, add:

```bash
# M030/P06/T02 — model_routing_regression check (FR-18). Additive: emits
# zero stdout AND zero JSONL when no class crosses the threshold; the
# legacy anomaly block above is unaffected. Threshold defaults: pass-rate
# 0.50 floor + 10 min class sample.
PASS_RATE_THRESH=""
if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
  PASS_RATE_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" model_routing_regression.pass_rate_threshold 2>/dev/null || true)"
fi
if [ -z "$PASS_RATE_THRESH" ] || [ "$PASS_RATE_THRESH" = "null" ]; then PASS_RATE_THRESH="0.5"; fi

MIN_CLASS_SAMPLE=""
if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
  MIN_CLASS_SAMPLE="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" model_routing_regression.min_class_sample 2>/dev/null || true)"
fi
if [ -z "$MIN_CLASS_SAMPLE" ] || [ "$MIN_CLASS_SAMPLE" = "null" ]; then MIN_CLASS_SAMPLE="10"; fi

ANOMALIES_JSONL_PATH="${M030_ANOMALIES_JSONL_PATH:-${ORCHESTRATOR_ROOT:-$_CA_PROJECT_ROOT/.orchestrator}/anomalies.jsonl}"

_ca_model_routing_regression_check "$MILESTONE" "$PASS_RATE_THRESH" "$MIN_CLASS_SAMPLE" "$ANOMALIES_JSONL_PATH"
```

The CLI flow is now:

1. Resolve suppression matrix (existing).
2. Resolve thresholds (existing).
3. Resolve milestone (existing).
4. `check_anomalies_render` — emits the legacy "Anomaly Detection (Tier 1 baseline)" block (UNCHANGED).
5. **NEW**: `_ca_model_routing_regression_check` — emits zero or more `FLAGGED model_routing_regression ...` lines AND appends zero or more JSONL records to the anomalies path.

The new block is gated by NONE of the suppression matrix conditions (intentional — model_routing_regression should fire even when ORCHESTRATOR_AUTO=1 because it's a quality regression signal, NOT a noisy notification). However, when `--no-anomaly` is set, the entire script returns early at the `SUPPRESS=1` short-circuit (still upstream of step 4-5) — so `--no-anomaly` does suppress both legacy and new. This matches the spirit of `--no-anomaly`: blanket disable.

**Critical SC-11 invariant**: when the input JSONL has zero shadow-on `dispatch_usage` records carrying `character=`, the new block emits ZERO stdout (every `_ca_emit_class_regression` call hits the `total < min_class_sample` short-circuit and returns 0). The legacy block at step 4 is byte-identical to pre-amendment. Therefore the pre-M030 fixture's stdout is byte-identical to the pre-amendment golden. T01's `p06-sc11-byte-equality.sh` is the mechanical contract.

### Co-authored verifiers

Six new verifiers under `tools/verify/`:

#### 1. `p06-mechanical-regression.sh`

Invokes `check-anomalies.sh` against `regression-mechanical.jsonl` and asserts:
- The `FLAGGED model_routing_regression class=mechanical class_pass_rate=0.40 sample=20 threshold=0.50` line is present in stdout.
- A JSONL record with `"kind":"model_routing_regression"` AND `"class":"mechanical"` is present in the env-redirected anomalies.jsonl.
- Exit 0.

```bash
#!/usr/bin/env bash
# tools/verify/p06-mechanical-regression.sh — mechanical-class regression detection gate.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/regression-mechanical.jsonl"

pass=0
fail=0

# Stage the carve-out: copy the regression fixture as the M999 execution log.
tmp_root="$(mktemp -d -t p06-mech.XXXXXX)"
mkdir -p "$tmp_root/milestones/M999"
cp "$FIXTURE" "$tmp_root/milestones/M999/execution-log.jsonl"
# Minimal milestone marker so find-active-milestone.sh resolves M999.
printf '%s\n' '---' 'type: milestone-context' 'milestone: "M999"' 'status: open' '---' \
  > "$tmp_root/milestones/M999/M999-CONTEXT.md"

ANOMALIES_JSONL="$tmp_root/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-mech-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" PROJECT_ROOT="$PROJECT_ROOT" \
  M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" --milestone M999 \
  > "$ACTUAL" 2>/dev/null

# Assert text-line presence.
if grep -qE '^FLAGGED model_routing_regression class=mechanical class_pass_rate=0\.40 sample=20 threshold=0\.50' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: FLAGGED model_routing_regression class=mechanical line present"
else
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression class=mechanical line missing"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Assert JSONL record presence.
if [ -f "$ANOMALIES_JSONL" ] && grep -qE '"kind":"model_routing_regression".*"class":"mechanical"' "$ANOMALIES_JSONL"; then
  pass=$((pass + 1))
  echo "OK: anomalies.jsonl record class=mechanical present"
else
  fail=$((fail + 1))
  echo "FAIL: anomalies.jsonl record class=mechanical missing"
  if [ -f "$ANOMALIES_JSONL" ]; then
    echo "anomalies.jsonl content:"
    cat "$ANOMALIES_JSONL"
  else
    echo "anomalies.jsonl does not exist at $ANOMALIES_JSONL"
  fi
fi

echo "SUMMARY: p06-mechanical-regression.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

#### 2. `p06-standard-regression.sh`

Same shape as `p06-mechanical-regression.sh` but against `regression-standard.jsonl`; asserts `class=standard` in both text line and JSONL.

#### 3. `p06-novel-regression.sh`

Same shape; against `regression-novel.jsonl`; asserts `class=novel`.

#### 4. `p06-no-regression.sh`

Invokes `check-anomalies.sh` against `no-regression.jsonl` and asserts:
- NO `FLAGGED model_routing_regression` line in stdout.
- NO record matching `"kind":"model_routing_regression"` in the env-redirected anomalies.jsonl (the file may not even exist if no record is emitted — both states are valid PASS).
- The legacy "Anomaly Detection (Tier 1 baseline)" block IS present (sanity check that the legacy path still emits).
- Exit 0.

```bash
# (header + setup mirrors p06-mechanical-regression.sh)

# Assert NO FLAGGED model_routing_regression line.
if grep -qE 'FLAGGED model_routing_regression' "$ACTUAL"; then
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression line UNEXPECTEDLY present"
  cat "$ACTUAL"
else
  pass=$((pass + 1))
  echo "OK: no FLAGGED model_routing_regression line"
fi

# Assert NO JSONL record.
if [ -f "$ANOMALIES_JSONL" ] && grep -qE '"kind":"model_routing_regression"' "$ANOMALIES_JSONL"; then
  fail=$((fail + 1))
  echo "FAIL: anomalies.jsonl UNEXPECTEDLY contains model_routing_regression record"
  cat "$ANOMALIES_JSONL"
else
  pass=$((pass + 1))
  echo "OK: no model_routing_regression record in anomalies.jsonl"
fi

# Assert legacy block IS present.
if grep -qE '^Anomaly Detection \(Tier 1 baseline\)' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: legacy Anomaly Detection block present"
else
  fail=$((fail + 1))
  echo "FAIL: legacy Anomaly Detection block missing"
fi
```

#### 5. `p06-below-min-sample.sh`

Invokes `check-anomalies.sh` against `below-min-sample.jsonl` (5 mechanical records, pass-rate 0.40 — would trigger if sample met floor). Asserts:
- NO `FLAGGED model_routing_regression class=mechanical` line (sample 5 < min_class_sample 10).
- NO JSONL record.
- Exit 0.

#### 6. `p06-doctor-surfaces-anomaly.sh`

Stages an `ORCHESTRATOR_ROOT` carve-out (M999 execution log = regression-mechanical.jsonl), invokes `run-doctor.sh --root $tmp_root`, and asserts:
- The "Anomaly Detection" section in stdout contains `FLAGGED model_routing_regression class=mechanical`.
- Exit code follows existing doctor semantics (advisory; does NOT block).

```bash
#!/usr/bin/env bash
# tools/verify/p06-doctor-surfaces-anomaly.sh — doctor-end-to-end gate.
# Confirms the new check-anomalies output flows through run-doctor.sh
# without any run-doctor.sh amendment (acceptance: "the anomaly surfaces
# through orchestrator:doctor per existing M027 conventions").
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/regression-mechanical.jsonl"

pass=0
fail=0

tmp_root="$(mktemp -d -t p06-doctor.XXXXXX)"
mkdir -p "$tmp_root/.orchestrator/milestones/M999"
cp "$FIXTURE" "$tmp_root/.orchestrator/milestones/M999/execution-log.jsonl"
printf '%s\n' '---' 'type: milestone-context' 'milestone: "M999"' 'status: open' '---' \
  > "$tmp_root/.orchestrator/milestones/M999/M999-CONTEXT.md"

ANOMALIES_JSONL="$tmp_root/.orchestrator/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-doctor-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

# run-doctor.sh resolves PROJECT_ROOT from --root or env. Use --root.
M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh" --root "$tmp_root" \
  > "$ACTUAL" 2>&1

# Assert "Anomaly Detection" header is present (existing doctor section).
if grep -qE '^--- Anomaly Detection ---' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: Anomaly Detection section header present"
else
  fail=$((fail + 1))
  echo "FAIL: Anomaly Detection section header missing"
fi

# Assert the model_routing_regression line is present in the rendered block.
if grep -qE 'FLAGGED model_routing_regression class=mechanical' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: FLAGGED model_routing_regression class=mechanical surfaced through doctor"
else
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression class=mechanical NOT surfaced through doctor"
  echo "Actual doctor output (last 50 lines):"
  tail -n 50 "$ACTUAL"
fi

echo "SUMMARY: p06-doctor-surfaces-anomaly.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

#### 7. `p06-shadow-off-byte-equality.sh`

Wraps P02's `p02-additive-schema.sh` to confirm dispatch-interface shadow-off byte-equality holds post-amendment:

```bash
#!/usr/bin/env bash
# tools/verify/p06-shadow-off-byte-equality.sh — wraps p02-additive-schema.sh
# to confirm dispatch-interface shadow-OFF emit is byte-identical to
# pre-amendment HEAD after T02's character-field amendment lands. Mirrors
# P05/T01's doctor-config-check delegate-and-pass-through pattern.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$PROJECT_ROOT/tools/verify/p02-additive-schema.sh"
rc=$?

pass=0
fail=0
if [ "$rc" -eq 0 ]; then
  pass=1
  echo "OK: p02-additive-schema.sh exited 0 (shadow-off byte-equality preserved)"
else
  fail=1
  echo "FAIL: p02-additive-schema.sh exited $rc — T02 amendment broke shadow-off byte-equality"
fi

echo "SUMMARY: p06-shadow-off-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

This delegate-and-pass-through pattern matches P05/T01's `p05-doctor-config-check.sh` shape — P02 already ships the byte-strict additive-schema gate; P06 just re-confirms it post-T02 amendment.

### `references/model-routing.md` amendment

Append a new `## Anomaly Records` section after the existing `## Cost Rollup Surfaces` section. Section content:

```markdown
## Anomaly Records

`scripts/diagnostics/check-anomalies.sh` emits a `model_routing_regression`
anomaly when a class's verifier-fail rate over the rolling window crosses
the configured threshold. The anomaly surfaces in two places:

1. **Stdout text line** (consumed by `orchestrator:doctor`):

   ```
   FLAGGED model_routing_regression class=<C> class_pass_rate=<R> sample=<N> threshold=<T>
   ```

2. **JSONL record** appended to `.orchestrator/anomalies.jsonl` (or the
   path passed via the `M030_ANOMALIES_JSONL_PATH` env):

   ```json
   {"record_type":"anomaly","kind":"model_routing_regression","class":"<C>","class_pass_rate":<R>,"class_sample":<N>,"threshold":<T>,"milestone":"<M###>","timestamp":"<ISO8601>"}
   ```

### Threshold defaults (#Q-4 plan-phase decision)

- `pass_rate_threshold` = `0.50` — class triggers regression when its
  rolling-window verifier-pass rate falls below 0.50.
- `min_class_sample` = `10` — the per-class sample size floor; classes
  with fewer records are silently skipped.

Both defaults are overridable via `.orchestrator/config.yml`:

```yaml
model_routing_regression:
  pass_rate_threshold: 0.50
  min_class_sample: 10
```

Operators tuning these values after a milestone or two of live-routed
data should consider raising `pass_rate_threshold` toward the empirically
observed pass-rate floor for the runtime-default model — the defaults
ship conservative.

### Doctor surfacing

The anomaly surfaces through `bash scripts/diagnostics/run-doctor.sh` via
the existing "Anomaly Detection" advisory check (line 156-159 of
`run-doctor.sh`). The section header reads `--- Anomaly Detection ---`
followed by the legacy "Anomaly Detection (Tier 1 baseline)" block,
followed by zero or more `FLAGGED model_routing_regression class=<C>` lines.

The check is **advisory** — `run-doctor.sh` does NOT block on it (the
`run_check` invocation passes `advisory=1`). This matches the existing
M027 anomaly-check semantics.

### Append-only invariant

`.orchestrator/anomalies.jsonl` is append-only. `check-anomalies.sh`
NEVER rewrites prior records. Operators acknowledging or dismissing an
anomaly do so out-of-band (no UI primitive — the operator-noticed-fact
convention from references/observability.md mirrors this).

### Class derivation

The per-class grouping reads the `character` field on shadow-on
`dispatch_usage` records (additively introduced in M030/P06). Records
without the `character` field (pre-P06 records, or records emitted in
shadow-off mode) are silently skipped — they don't contribute to any
class's sample count.

### CON-2 / FR-19 / SC-11 contract

When no class crosses the threshold (or when the input contains zero
shadow-on records carrying `character=`), `check-anomalies.sh` emits
ZERO additional stdout and appends ZERO JSONL records — preserving
byte-equality with pre-M030 output. The mechanical gate is
`tools/verify/p06-sc11-byte-equality.sh`.
```

### SC-11 re-confirmation

Post-amendment, T02 re-runs T01's SC-11 gate AND P02's shadow-off byte-equality gate:

```bash
bash tools/verify/p06-sc11-byte-equality.sh
bash tools/verify/p02-additive-schema.sh
```

Both must continue to exit 0. Common breakage modes:

- The check-anomalies amendment accidentally emits a stdout line on the unflagged code-path (e.g., a debug `printf` left in `_ca_model_routing_regression_check`'s top-level). Fix: gate every emission on `total >= min_class_sample` AND `pass_rate < threshold`.
- The dispatch-interface character-field amendment accidentally fires on the shadow-OFF emit branch (e.g., the printf format change wasn't gated by the existing shadow-on if-branch). Fix: re-read the printf branch in dispatch-interface.sh and confirm only the `M030_SHADOW_MODE=1 && CLAUDECODE=1` branch's printf was extended.

## Steps

1. **Confirm T01 deliverables are green**:

   ```bash
   bash tools/verify/p06-sc11-byte-equality.sh
   ```

   Expected: exit 0. If fail, halt T02 and re-open T01.

2. **Read `scripts/diagnostics/check-anomalies.sh`** in full to confirm the line numbers + suppression matrix shape match the prerequisite description. Identify the argparse loop (lines ~211-225) and the CLI entry point's bottom-of-file check_anomalies_render invocation (line ~287).

3. **Read `scripts/dispatch/dispatch-interface.sh`** in full (or at least the `_di_emit_dispatch_usage` body and `_di_resolve_live_routing` / `_di_resolve_shadow_routing` bodies). Confirm the shadow-on emit printf branch and identify where the character variable is in scope.

4. **Amend `scripts/dispatch/dispatch-interface.sh`** per the Description:

   - Plumb the captured character through to `_DI_SHADOW_CHARACTER` at the top-level shell scope (parent-shell so `_di_emit_dispatch_usage` reads it).
   - Append `,"character":"%s"` to the shadow-on printf format string and append `${_DI_SHADOW_CHARACTER:-unknown}` to the printf arg list.
   - The shadow-OFF printf branch is byte-untouched.
   - Bash 3.2 compatible. MEM004 emitter-internal carve-out applies — the dispatch-interface internals.

5. **Run P02's `p02-additive-schema.sh` immediately after the dispatch-interface amendment** to confirm shadow-off byte-equality holds:

   ```bash
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: exit 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0`. If fail, the dispatch-interface amendment has broken byte-equality on the shadow-off branch — re-read step 4 and confirm only the shadow-on branch's printf was modified.

6. **Author `tools/verify/p06-shadow-off-byte-equality.sh`** per the shape in the Description (delegate-and-pass-through wrapper). Make executable.

7. **Run `p06-shadow-off-byte-equality.sh`** to confirm:

   ```bash
   bash tools/verify/p06-shadow-off-byte-equality.sh
   ```

   Expected: exit 0.

8. **Amend `scripts/diagnostics/check-anomalies.sh`** per the Description:

   - Add the `_ca_model_routing_regression_check` function near the bottom (after `check_anomalies_render`).
   - Add the threshold-resolution + invocation block in the CLI entry point after `check_anomalies_render` returns.
   - Add `--threshold-pass-rate` and `--min-class-sample` flags to the argparse loop (optional CLI overrides).
   - Bash 3.2 compatible.

9. **Run T01's SC-11 gate immediately after the check-anomalies amendment** to confirm byte-equality holds on the pre-M030 fixture path:

   ```bash
   bash tools/verify/p06-sc11-byte-equality.sh
   ```

   Expected: exit 0. If fail, the check-anomalies amendment has broken byte-equality on the no-class-regression path — investigate `_ca_model_routing_regression_check`'s short-circuit conditions.

10. **Author `tools/verify/p06-mechanical-regression.sh`** per the shape in the Description. Make executable.

11. **Author `tools/verify/p06-standard-regression.sh`** by copy + class-substitution from `p06-mechanical-regression.sh`. Make executable.

12. **Author `tools/verify/p06-novel-regression.sh`** by copy + class-substitution. Make executable.

13. **Author `tools/verify/p06-no-regression.sh`** per the shape in the Description (asserts NO regression line + NO JSONL record + legacy block present). Make executable.

14. **Author `tools/verify/p06-below-min-sample.sh`** per the shape in the Description (asserts NO regression line + NO JSONL record despite pass-rate below threshold, because sample size below min_class_sample floor). Make executable.

15. **Author `tools/verify/p06-doctor-surfaces-anomaly.sh`** per the shape in the Description (stages ORCHESTRATOR_ROOT carve-out + invokes run-doctor.sh + greps for the anomaly line in the doctor output). Make executable.

16. **Run all six new verifiers**:

    ```bash
    bash tools/verify/p06-mechanical-regression.sh
    bash tools/verify/p06-standard-regression.sh
    bash tools/verify/p06-novel-regression.sh
    bash tools/verify/p06-no-regression.sh
    bash tools/verify/p06-below-min-sample.sh
    bash tools/verify/p06-doctor-surfaces-anomaly.sh
    ```

    Expected: all six exit 0 with `SUMMARY: <verifier-name> pass=N fail=0`.

17. **Re-run T01's SC-11 gate AND P02's shadow-off byte-equality gate** to confirm byte-equality is preserved end-to-end:

    ```bash
    bash tools/verify/p06-sc11-byte-equality.sh
    bash tools/verify/p06-shadow-off-byte-equality.sh
    ```

    Expected: both exit 0.

18. **Amend `references/model-routing.md`** by appending the `## Anomaly Records` section per the Description. Place the section after the existing `## Cost Rollup Surfaces` section.

19. **Run the full T01+T02 verifier set** as a self-check:

    ```bash
    bash tools/verify/p06-sc11-byte-equality.sh
    bash tools/verify/p06-shadow-off-byte-equality.sh
    bash tools/verify/p06-mechanical-regression.sh
    bash tools/verify/p06-standard-regression.sh
    bash tools/verify/p06-novel-regression.sh
    bash tools/verify/p06-no-regression.sh
    bash tools/verify/p06-below-min-sample.sh
    bash tools/verify/p06-doctor-surfaces-anomaly.sh
    ```

    Expected: all eight exit 0.

## Must-Haves

T02 satisfies the following phase truths:

- "mechanical-class regression detected" — gated by `bash tools/verify/p06-mechanical-regression.sh`.
- "standard-class regression detected" — gated by `bash tools/verify/p06-standard-regression.sh`.
- "novel-class regression detected" — gated by `bash tools/verify/p06-novel-regression.sh`.
- "no-regression corpus emits no model_routing_regression record" — gated by `bash tools/verify/p06-no-regression.sh`.
- "below-min-sample corpus emits no model_routing_regression record" — gated by `bash tools/verify/p06-below-min-sample.sh`.
- "anomaly surfaces through orchestrator:doctor per existing [M027](../../../../../milestones/M027/index.md) conventions" — gated by `bash tools/verify/p06-doctor-surfaces-anomaly.sh`.
- "SC-11 byte-equality on dispatch-interface shadow-off path" — gated by `bash tools/verify/p06-shadow-off-byte-equality.sh`.
- SC-11 gate from T01 continues to pass post-amendment — gated by `bash tools/verify/p06-sc11-byte-equality.sh`.

## Verification

```bash
bash tools/verify/p06-sc11-byte-equality.sh
bash tools/verify/p06-shadow-off-byte-equality.sh
bash tools/verify/p06-mechanical-regression.sh
bash tools/verify/p06-standard-regression.sh
bash tools/verify/p06-novel-regression.sh
bash tools/verify/p06-no-regression.sh
bash tools/verify/p06-below-min-sample.sh
bash tools/verify/p06-doctor-surfaces-anomaly.sh
```

Each command uses single-script-file shape per AD-19. All eight must exit 0 before T02 closes. Each emits `SUMMARY: <verifier-name> pass=N fail=0` on success.

## Inputs

### From Previous Tasks (T01)

- `tests/fixtures/m030-p06/regression-mechanical.jsonl` — Key API: 20-record JSONL fixture; `character=mechanical`; 12 fail (`escalation_count=1`, `escalation_reason="verifier_fail"`) / 8 pass (`escalation_count=0`, `escalation_reason=""`); class_pass_rate = 0.40; sample = 20.
- `tests/fixtures/m030-p06/regression-standard.jsonl` — same shape, `character=standard`.
- `tests/fixtures/m030-p06/regression-novel.jsonl` — same shape, `character=novel`.
- `tests/fixtures/m030-p06/no-regression.jsonl` — Key API: 60-record fixture (20 per class); per-class 4 fail / 16 pass; class_pass_rate = 0.80.
- `tests/fixtures/m030-p06/below-min-sample.jsonl` — Key API: 5 mechanical records; 3 fail / 2 pass; class_pass_rate = 0.40 but sample < min_class_sample floor of 10.
- `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` — Key API: golden stdout snapshot of pre-amendment check-anomalies against the P02 pre-M030 fixture. Consumed by `p06-sc11-byte-equality.sh`.
- `tools/verify/p06-sc11-byte-equality.sh` — Key API: `bash <path>` exits 0 on byte-equality; emits `SUMMARY:` line.

### From Disk (Pre-existing)

- `scripts/diagnostics/check-anomalies.sh` — Key API: sourceable + CLI; `bash <path> [--milestone <M>] [--project] [--no-anomaly] [--yes] [--threshold <mult>] [--sample-floor <N>] [--config-defaults <path>]`. Emits "Anomaly Detection (Tier 1 baseline)" text block to stdout. Exit 0 always (CON-5). T02 extends with `--threshold-pass-rate <float>` and `--min-class-sample <N>` flags + `_ca_model_routing_regression_check` function + JSONL emit.
- `scripts/dispatch/dispatch-interface.sh` — Key API: emits `dispatch_usage` JSONL records via `_di_emit_dispatch_usage`. Shadow-on emit branch (gated by `M030_SHADOW_MODE=1 && CLAUDECODE=1`) carries 9 additive fields beyond [M019](../../../../../milestones/M019/index.md) baseline. T02 appends `character` as a 10th additive field.
- `scripts/diagnostics/run-doctor.sh` — Key API: `bash <path> [--root <P>] [--format text|json] [--config-check] [--routing-table <T>] [--no-anomaly]`. Invokes `check-anomalies.sh` at lines 154-159 as advisory. Renders its stdout in the "Anomaly Detection" section. T02 does NOT amend run-doctor.sh — the new check-anomalies output flows through unchanged.
- `tools/verify/p02-additive-schema.sh` — Key API: P02's SC-11 byte-equality gate; round-trips a record through dispatch-interface under shadow-off and asserts byte-identity. Consumed by `p06-shadow-off-byte-equality.sh`.
- `templates/model-routing.yml` — Key API: shipped routing-table; default mapping `mechanical→fast / standard→balanced / novel→smart` for claude-code. Read at runtime by check-anomalies (informationally; T02's check uses the `character` field directly, not via inverse routing).
- `scripts/state/read-config.sh` — Key API: `bash <path> <key>` reads `<key>` from `.orchestrator/config.yml` overlay layers. Used by check-anomalies' threshold-resolution.
- `references/model-routing.md` — operator-facing routing-table documentation. T02 appends `## Anomaly Records` section after `## Cost Rollup Surfaces`.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p06-*` is invoked as a single `bash <path>`. The amendments themselves are emitter-internal (MEM004 carve-out applies — pipes / `$(...)` / awk allowed inside `check-anomalies.sh` and `dispatch-interface.sh` bodies).
- **AP-008 heredoc-with-expansion**: not introduced — T02 ships only code amendments + verifiers + docs. T03 handles the commit.
- **AP-009 compound-chain-gt2**: verifier scripts use straight-line shape (per-command `bash <path>` then `$?` capture); no `cmd1 && cmd2 && cmd3` chains.
- **Bash 3.2 compatibility**: amendments use parallel scalars, plain `case`, `while [ ... ]; do` loops. No `declare -A`, no `mapfile`, no process substitution, no `[[ ... =~ ... ]]`.
- **CON-2 / FR-19 / SC-11 (additive schema)**: every amendment is strictly additive. Default check-anomalies output (no class crosses threshold) is byte-identical to pre-T02. Dispatch-interface shadow-off output is byte-identical to pre-T02 (the new `character` field is gated to shadow-on only). The SC-11 gates from T01 + P02 are the mechanical contract.
- **CON-3 closure preserved**: T02 introduces zero new hardcoded model IDs. The new check-anomalies block reads model class names ONLY from the `character` field on dispatch_usage records (which themselves resolve through templates/model-routing.yml at emit-time). Verified by visual inspection of the diff.
- **CON-5 never-abort preserved**: `_ca_model_routing_regression_check` always returns 0; degraded inputs (missing log file, malformed JSONL, missing character field) surface as zero-emission paths rather than nonzero exit.
- **CON-6 append-only preserved**: `.orchestrator/anomalies.jsonl` is append-only. `_ca_model_routing_regression_check` NEVER rewrites prior records — only appends new lines via `>> "$jsonl_path"`.
- **MEM004 emitter-internal carve-out**: applies to the bodies of `_ca_model_routing_regression_check` (in check-anomalies.sh) and `_di_emit_dispatch_usage` (in dispatch-interface.sh) — pipes, `$(...)`, and awk are permitted inside these function bodies.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T02 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline ([M032](../../../../../milestones/M032/index.md) Finding A)**: every new verifier lives under `tools/verify/p06-*`; none under `scripts/verify/`.
- **D-A9 anomaly JSONL snapshot convention**: this is the M030/P06 doc requirement (FR-2 prose amendment). T02 satisfies it implicitly via the append-only invariant + the `## Anomaly Records` doc — operators reading the doc understand the cross-run consistency contract.

## Expected Output

- `scripts/diagnostics/check-anomalies.sh` — amended with `_ca_model_routing_regression_check` function + CLI integration + threshold-resolution. Default behavior (no class crosses threshold) byte-identical to pre-T02.
- `scripts/dispatch/dispatch-interface.sh` — amended with `character` field on shadow-on emit only. Shadow-off behavior byte-identical to pre-T02.
- `references/model-routing.md` — extended with `## Anomaly Records` section.
- `tools/verify/p06-mechanical-regression.sh` + `p06-standard-regression.sh` + `p06-novel-regression.sh` + `p06-no-regression.sh` + `p06-below-min-sample.sh` + `p06-doctor-surfaces-anomaly.sh` + `p06-shadow-off-byte-equality.sh` — seven new verifiers; each exits 0 against post-T02 surfaces.
- T01 SC-11 gate continues to exit 0.
- P02 `p02-additive-schema.sh` continues to exit 0 (re-confirmed via `p06-shadow-off-byte-equality.sh`).

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p06-mechanical-regression.sh` → `SUMMARY: p06-mechanical-regression.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p06-standard-regression.sh` → `SUMMARY: p06-standard-regression.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p06-novel-regression.sh` → `SUMMARY: p06-novel-regression.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p06-no-regression.sh` → `SUMMARY: p06-no-regression.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p06-below-min-sample.sh` → `SUMMARY: p06-below-min-sample.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p06-doctor-surfaces-anomaly.sh` → `SUMMARY: p06-doctor-surfaces-anomaly.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p06-shadow-off-byte-equality.sh` → `SUMMARY: p06-shadow-off-byte-equality.sh pass=1 fail=0`, exit 0.
- `bash scripts/diagnostics/check-anomalies.sh --milestone M999` (against staged regression-mechanical.jsonl carve-out) →
  ```
  Anomaly Detection (Tier 1 baseline)
  ANOMALY: <legacy block content depending on rollup median>
  FLAGGED model_routing_regression class=mechanical class_pass_rate=0.40 sample=20 threshold=0.50
  ```
  (The legacy block precedes the new line; the new line is the additive contribution.)

The label tokens `FLAGGED model_routing_regression class=`, `class_pass_rate=`, `sample=`, `threshold=` are stable contract — the verifiers lock them. If T02 chooses different label tokens, the label change must be reflected in BOTH the check-anomalies amendment AND the verifier scripts authored in T02 — the labels are a coupled commit. Recommended: use the labels documented above for consistency with the demo sentence in P06-PLAN.md.

The `M030_ANOMALIES_JSONL_PATH` env-var seam is the verifier-injection mechanism (mirrors P02's `M030_SHADOW_MODE` env, P04's `M030_SHADOW_COMPARE_CORPUS` env, and P05's `M030_ROUTING_TABLE_PATH` env). The default fallback is `${ORCHESTRATOR_ROOT:-$_CA_PROJECT_ROOT/.orchestrator}/anomalies.jsonl`. Verifiers MUST always pass `M030_ANOMALIES_JSONL_PATH` explicitly to keep the carve-out predictable.

If `dispatch-interface.sh`'s emit path doesn't currently keep the character variable in scope where `_di_emit_dispatch_usage` is invoked, T02 must export it via a top-level scalar (`_DI_SHADOW_CHARACTER`) at the same point where `_DI_SHADOW_ROUTED` and `_DI_LIVE_MODEL_FLAG` are exported (this top-level pattern was established by P04/T02). The amendment is mechanically symmetrical to those.

If running the full verifier suite at step 19 reveals that one of the three regression verifiers (`p06-mechanical-regression.sh` / `p06-standard-regression.sh` / `p06-novel-regression.sh`) fails because the awk pattern in `_ca_model_routing_regression_check` matched the wrong character (e.g., regex partial-match treating "standard" record as "mechanical" because of substring), the awk patterns must use field anchors that include surrounding quotes — `"character":"mechanical"` not `mechanical`. The matching is intentionally substring-greedy on the full quoted token to avoid this kind of cross-class leakage.

If the regression verifiers report passing class pass-rate of 0.40 but the threshold-resolution branch reads the threshold as a string "0.5" rather than a number, the awk `r + 0 < th + 0` comparison handles the coercion correctly — but make sure the threshold value isn't accidentally double-quoted into the printf arg list ("0.50" vs 0.50 in the JSONL record). Recommended: format the threshold via `awk -v th="$pass_rate_thresh" 'BEGIN { printf "%.2f", th + 0 }'` (used in the function body's `thresh_fmt` derivation) so the JSONL record carries the numeric form 0.50.

If T02's amendment to dispatch-interface.sh introduces the character field but P02's `p02-additive-schema.sh` still passes (because the shadow-off branch is byte-untouched), and P02's `p02-shadow-emit.sh` (the shadow-ON byte-equality gate) FAILS because the shadow-on emit format changed — that is EXPECTED: the shadow-on emit IS supposed to change additively. Read p02-shadow-emit.sh's contract: it likely asserts the 9-field shape of the shadow-on emit; T02's amendment makes it 10-field. p02-shadow-emit.sh must be updated to assert the 10-field shape post-T02 — file an amendment as a coupled commit with the dispatch-interface change. Alternatively, p02-shadow-emit.sh may already use a "fields-MUST-be-present" predicate (rather than "fields-MUST-equal-N") which would be additive-tolerant; check the verifier body before authoring an amendment. The expected outcome: p02-shadow-emit.sh either continues green (if its predicate is presence-based) or needs a 1-line amendment to the field-count assertion (if it locks the count).
