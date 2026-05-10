---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M027"
name: "intensity-recommend.sh cost-annotation hook + --format json cost_estimates per D026"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `scripts/engine/cost-estimate.sh` (sourceable + CLI). After sourcing T01's library, the following functions are defined:
  - `cost_estimate_per_tier "<description>" [--format text|json]` — emits per-tier cost+quality data (text table or single-line JSON). Reads optional module variable `_CE_RECOMMENDED` (one of `quick|standard|full`) to mark the recommended tier; if unset, the function falls back to invoking `cost_estimate_recommend` itself.
  - `cost_estimate_recommend "<description>"` — returns lowercased intensity tier string. Used by CLI mode of T01; T02 does NOT call this (avoids re-entry — see CON below).
  - `cost_estimate_resolve_model` — returns the model id used for cost estimation.
- T01's text output ends with the verbatim D027 trailer `estimates +/-~20%; see commands/cost.md#accuracy`.
- T01's JSON output is shaped `{"recommended":"<tier>","tiers":{"quick":{...},"standard":{...},"full":{...}}}` where each tier's inner shape is `{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"quality":"<str>","pricing_warning":"<str>"}`.
- The current `scripts/engine/intensity-recommend.sh` (pre-T02) emits 8 key=value lines on stdout in fixed order: `intensity=`, `confidence=`, `reasoning=`, `scope=`, `risk_level=`, `complexity=`, `risk_signals=`, `cap_score=`. It does NOT accept `--format` and does NOT emit JSON. CLI flags currently accepted: `--analyze-output`, `--profile-output`, `--description`.
- The current script uses bash 4-style `[[ … ]]` and is bash 3.2 compatible per the project conventions; T02 must not regress this.

## Description

Modify `scripts/engine/intensity-recommend.sh` so it (1) preserves byte-stable text output for the existing 8 key=value lines (CON-3 carry-forward), (2) appends a per-tier cost-annotation block AFTER the existing key=value lines when format is text (default), and (3) accepts a new `--format text|json` flag where `--format json` emits the existing structured fields PLUS a top-level `cost_estimates` object keyed by tier per D026.

The cost-annotation block in text mode is one or more lines below the existing key=value lines, prefixed with a marker (e.g., `# cost estimates (M027/P01)`), so machine consumers grepping for the existing keys (`grep '^intensity='`) continue to work unchanged. The cost annotations themselves are key=value lines for parseability:

```
cost_quick_usd=<num-or-empty>
cost_quick_in_tokens=<int>
cost_quick_out_tokens=<int>
cost_standard_usd=<num-or-empty>
cost_standard_in_tokens=<int>
cost_standard_out_tokens=<int>
cost_full_usd=<num-or-empty>
cost_full_in_tokens=<int>
cost_full_out_tokens=<int>
cost_pricing_warning=<reason-or-empty>
```

The block is suppressed entirely when the operator passes `--no-cost-annotation` (back-compat escape hatch) or when sourcing this script as a library (the existing implementation already runs main only at top level via the script-vs-source idiom; preserve that).

In `--format json` mode, the script emits a single-line JSON object of shape:

```json
{"intensity":"<tier>","confidence":"<level>","reasoning":"<text>","scope":"<scope>","risk_level":"<level>","complexity":"<level>","risk_signals":"<signals>","cap_score":<int>,"cost_estimates":{"quick":{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"pricing_warning":"<str>"},"standard":{...},"full":{...}}}
```

Per D026 the `cost_estimates` object is always present when `--format json` is set, even on pricing degradation (`cost_usd` becomes JSON `null` and `pricing_warning` carries the reason).

## Steps

1. **Open `scripts/engine/intensity-recommend.sh`** and read the full file (already 136 lines; modifications below add ~80 lines).

2. **Argument parsing** — extend the existing `while [[ $# -gt 0 ]]; do case "$1" in ...` loop to accept:
   - `--format text|json` (default `text`); store in `FORMAT` variable; unknown value → exit 2.
   - `--no-cost-annotation` (boolean flag); store in `NO_COST_ANNOTATION` (default 0).
   - Preserve every existing flag and its semantics. Do not change the order of the existing 8 stdout lines.

3. **Source `scripts/engine/cost-estimate.sh`** AFTER all argument parsing and AFTER the existing analyze-output / profile-output / description resolution block, but BEFORE the final `--Output ---` block. The source line: `# shellcheck disable=SC1091` then `. "$REPO_ROOT/scripts/engine/cost-estimate.sh"`. The re-source guard inside cost-estimate.sh prevents repeat loads.

4. **Resolve description for cost estimation** — if `$DESCRIPTION` is empty (the user fed pre-computed `--analyze-output` / `--profile-output`), set `cost_desc=""`. Cost annotation when description is empty is allowed; the char-quartile estimate degrades to overhead-only — emit a stderr WARN line: `WARN: cost-estimate description=empty; estimates use recipe overhead only`.

5. **Compute the per-tier estimate** — set the module variable used by T01's library to skip re-recommending: `_CE_RECOMMENDED="$(printf '%s' "$intensity" | tr '[:upper:]' '[:lower:]')"`. Then call `cost_estimate_per_tier "$cost_desc" --format json` and capture stdout into a variable `cost_json` (single-line JSON). On any failure (empty output, parse fail) set `cost_json='{"recommended":"standard","tiers":{}}'` and emit `WARN: cost-estimate fallback reason=<reason>` to stderr.

6. **Branch on `$FORMAT`**:

   **Text branch** (default):
   - Emit the existing 8 key=value lines via the existing `echo` block — unchanged byte-for-byte.
   - If `NO_COST_ANNOTATION = 1`, stop.
   - Else, emit the per-tier cost-annotation block. Parse `cost_json` for the per-tier values using a single helper function `_cj_field "<json>" "<tier>" "<field>"` that does a regex match against the inline JSON (printf '%s' "$cost_json" | sed -nE 's/.*"<tier>":\{[^{}]*"<field>":(null|[0-9.]+|"[^"]*")[^{}]*\}.*/\1/p'). Strip surrounding quotes for string fields. For null cost_usd, emit empty value. For text values, prefix with `# cost estimates (M027/P01)` comment line, then 9 key=value lines (3 tiers × 3 cost fields) plus the `cost_pricing_warning=<reason>` line.

   **JSON branch**:
   - Build a single-line JSON object via printf-built string composition. The key order: `intensity`, `confidence`, `reasoning`, `scope`, `risk_level`, `complexity`, `risk_signals`, `cap_score`, `cost_estimates`. JSON-escape string values (replace `"` with `\"`, `\` with `\\`, newlines with `\n`) — write a small `_json_escape` helper that uses `sed`. Numeric fields (`cap_score`) emit unquoted; the rest emit quoted.
   - For `cost_estimates`, splice the inner `tiers` object from `cost_json` directly (T01 owns its inner shape; T02 must not re-marshal it). Specifically: extract the substring between the `"tiers":` marker and the closing of its object, OR re-emit it from parsed fields. Reliable approach: T01's `cost_estimate_per_tier --format json` already emits `tiers` as a self-contained object substring; sed-extract it: `tiers_obj=$(printf '%s' "$cost_json" | sed -nE 's/.*"tiers":(\{[^}]*\}\}*)\}*/\1/p')`. If the regex fails (due to nested-object greediness), fall back to reconstructing the object field-by-field from `_cj_field` results. **Implementation discipline**: a single bash 3.2-safe helper function `_cost_tiers_json "$cost_json"` performs this extraction with a documented invariant that T01's output never contains nested objects deeper than 2 levels (recommendations + tiers + per-tier flat). The verifier in T04 covers the JSON parse with both `python3 -c 'import json,sys; json.load(sys.stdin)'` and a printf round-trip.
   - Emit the assembled JSON as one line on stdout. Newline at end. Exit 0.

7. **Latency discipline** — preserve current text-mode latency. The dominant added cost is the source of `cost-estimate.sh` (~20 ms first-load) and the inner per-tier loop (~5 ms). Total text-mode added overhead target: < 50 ms. Verifier asserts.

8. **Zero-LLM-token discipline (FR-21 / CON-6).** The modified script MUST NOT contain any of: `claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`. It only sources `pricing.sh` (transitively via cost-estimate.sh) and forks no LLM call.

9. **bash 3.2 compat (CON-7).** No `declare -A`. No `<<<` herestrings. No `mapfile`/`readarray`. No `${var^^}` / `${var,,}` (use `tr`). No `<(...)`. No `&>`.

10. Preserve the file's executable permission and shebang.

## Must-Haves

- File `scripts/engine/intensity-recommend.sh` exists, ≥ 150 lines, contains the literal string `cost_estimates`.
- The first 8 key=value lines on stdout in text mode (`--format text` or no `--format`) are byte-identical to pre-T02 output for any given input. Verified by T04 against a fixture analyze-output / profile-output pair captured pre-modification.
- `--format json` emits a single-line JSON object that parses with `python3 -c 'import json,sys; json.load(sys.stdin)'` (or a fallback bash regex check) and contains a top-level `cost_estimates` object with keys `quick`, `standard`, `full`; each tier carries `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`.
- `--no-cost-annotation` flag suppresses the trailing cost-annotation block in text mode; the first 8 lines are still emitted.
- Under `ORCH_PRICING_FILE=/tmp/nonexistent.yml`, the script still emits the 8 key=value lines + cost-annotation block (with empty cost_usd values + `cost_pricing_warning=missing`) in text mode and a valid JSON object with `cost_usd:null` per tier in JSON mode.
- Zero-LLM-token: file does not match `(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)`.
- bash 3.2 compat: file does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,})`.

## Verification

```bash
bash scripts/engine/intensity-recommend.sh --description "add a TypeScript rewrite of the parser" --format json
```

The above must exit 0 and print one single-line JSON object containing both the existing structured fields (intensity, confidence, reasoning, scope, risk_level, complexity, risk_signals, cap_score) and a top-level `cost_estimates` object with `quick`, `standard`, `full` keys. Per-contract verifiers (text byte-stability, JSON shape, pricing degradation, zero-LLM-token, bash 3.2) live in T04 and are wired into `scripts/verify/m027-p01-suite.sh`. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` runs at the phase boundary, not at T02 task verification.

## Inputs

### From Previous Tasks

- T01: `scripts/engine/cost-estimate.sh` — sourceable. After source:
  - `cost_estimate_per_tier "<description>" --format json` returns a single-line JSON object `{"recommended":"<tier>","tiers":{"quick":{...},"standard":{...},"full":{...}}}` where each tier's inner shape is `{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"quality":"<str>","pricing_warning":"<str>"}`.
  - Module variable `_CE_RECOMMENDED` may be set before the call to skip the inner intensity-recommend re-fork. T02 sets this from the locally-computed `intensity` to avoid infinite recursion.

### From Disk (Pre-existing)

- `scripts/engine/intensity-recommend.sh` (current shape, pre-T02) — modify in place. Existing flags `--analyze-output`, `--profile-output`, `--description` are preserved. The 8 stdout key=value lines are byte-stable.
- `scripts/lib/pricing.sh` — transitively sourced via `cost-estimate.sh`. T02 does not source it directly.
- `scripts/dispatch/detect-capabilities.sh` — invoked via existing logic; T02 does not modify the call.
- `scripts/engine/intensity-analyze.sh` — invoked via existing logic; T02 does not modify the call.

## Constraints

- **CON-3 (back-compat)**: The first 8 stdout lines in text mode must be byte-identical to pre-T02 output for the same inputs. T04's `m027-p01-intensity-text-back-compat.sh` verifier captures pre-T02 output against fixture inputs and `diff`s.
- **CON-4 / FR-20 (Goodhart)**: The cost-annotation block carries quality semantics (per-tier quality is implicit in T01's output but T02 makes it explicit by emitting `cost_quick_quality=`, `cost_standard_quality=`, `cost_full_quality=` lines after the per-tier numeric lines). This satisfies SC-18 at the predictive intensity-recommend surface. Reconcile with step 6 above: add these 3 lines to the text-mode block; add `quality` to the JSON per-tier object (already present from T01).
- **CON-6 / FR-21 (zero-token)**: bash + sourced `pricing.sh` (transitive) only.
- **CON-7 (bash 3.2)**: T04's bash32-compat verifier will grep this file.
- **CON-9 / FR-22 (latency)**: text-mode end-to-end < 200 ms target (allowing for the existing forks to `intensity-analyze.sh` + `detect-capabilities.sh`); the *cost-annotation overhead* is < 50 ms. T04 measures both.
- **D026 (JSON shape)**: `cost_estimates` keyed by `quick`/`standard`/`full`, each carrying `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`. T04's JSON-shape verifier asserts.
- **No-recursion invariant**: T02 sets `_CE_RECOMMENDED` before calling `cost_estimate_per_tier`, ensuring T01's library does not re-fork `intensity-recommend.sh`.
- **MEM004 carve-out applies here**: pipes / `$()` / `awk` / `sed` are permitted *inside* this script.

## Expected Output

After this task:

1. `scripts/engine/intensity-recommend.sh` exists, ≥ 150 lines, executable.
2. Running `bash scripts/engine/intensity-recommend.sh --description "<task>"` emits the existing 8 key=value lines unchanged, followed by a `# cost estimates (M027/P01)` comment line and 12 cost-annotation key=value lines (9 numeric + 3 quality + 1 pricing warning).
3. Running with `--format json` emits one single-line JSON object with the 8 existing fields + `cost_estimates` object per D026.
4. Running with `--no-cost-annotation` (text mode) suppresses the cost-annotation block; the 8 key=value lines are unchanged.
5. Running under `ORCH_PRICING_FILE=/tmp/nonexistent.yml` still produces the cost-annotation block with empty cost_usd values + `cost_pricing_warning=missing` (text) or null cost_usd values (JSON).
6. `git diff --quiet` after running the script on a sample description returns exit 0.
