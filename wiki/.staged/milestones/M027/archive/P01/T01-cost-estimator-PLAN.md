---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M027"
name: "predictive cost estimator core (scripts/engine/cost-estimate.sh)"
depends_on: []
---

## Prerequisites

- `scripts/lib/pricing.sh` is sourceable per its `_PRICING_SH_SOURCED` re-source guard. It exposes:
  - `pricing_file_path` — prints the resolved `pricing.yml` path (respects `ORCH_PRICING_FILE`).
  - `pricing_file_present` — exit 0 if resolvable + readable, 1 otherwise.
  - `pricing_is_stale` — exit 0 if missing or age > 90 days.
  - `pricing_lookup_rates MODEL` — prints `INPUT_USD_PER_M OUTPUT_USD_PER_M` or empty on miss.
  - `pricing_resolve_alias MODEL` — prints concrete model id (resolves `aliases.* -> models.*`).
  - `pricing_estimate_cost_usd INPUT_TOKENS OUTPUT_TOKENS MODEL` — prints numeric dollar estimate (8-decimal precision) OR prints empty + sets `_PRICING_WARNING_REASON` on miss.
  - `chars_to_tokens_quartile CHARCOUNT` — prints `int(chars/4)`, [M019](../../../../milestones/M019/index.md) AD-1 char-quartile token estimate.
  - `pricing_warning_reason` — prints `missing | stale:<N>d | no-rate:<MODEL>` after a failed estimate.
- `scripts/engine/intensity-recommend.sh` (current shape, pre-T02) emits 8 key=value lines on stdout: `intensity=`, `confidence=`, `reasoning=`, `scope=`, `risk_level=`, `complexity=`, `risk_signals=`, `cap_score=`. Accepts `--description "<text>"` or stdin.
- M019 P01 token-estimate convention: per-recipe input tokens = `chars_to_tokens_quartile(template_char_count)` + recipe overhead; output tokens = recipe-declared output budget.
- M027/P00 has shipped `scripts/diagnostics/metrics-rollup.sh` (sourceable + CLI). T01 does NOT consume it; T01 is the predictive surface and is independent of the rollup engine.

## Description

Create `scripts/engine/cost-estimate.sh` — a sourceable bash library + CLI that, given a task description, produces a per-tier (Quick / Standard / Full) cost+token table in well under 100 ms with zero LLM tokens. The library function `cost_estimate_per_tier "<description>"` is the load-bearing entry point used by both this script's CLI mode and by T02's `intensity-recommend.sh` cost-annotation hook. The estimator pairs cost (USD, input tokens, output tokens) with quality semantics (best-effort / self-review / adversarial gate) on every row — Goodhart pairing extended to the predictive surface (FR-20 / CON-4 / SC-18). When `pricing.yml` is missing or stale, every cost cell renders `(unavailable)`, the recommendation still flows, the override hint still appears (FR-24).

The estimator does not itself classify the task — it asks `intensity-recommend.sh` for the recommended tier and marks that tier in the output. The other two tiers are still emitted with full cost+quality data so the operator can compare and override.

Char-quartile token approximation: input tokens = `chars_to_tokens_quartile(prompt_char_count)`; the prompt-char-count proxy for a task description is `length(description) + per-tier-recipe-overhead-chars`. Per-tier overhead constants are hard-coded in this file (Quick = 800 chars overhead, Standard = 2400 chars, Full = 6800 chars; rationale documented inline). Output tokens are per-tier hard-coded budgets (Quick = 1500 out, Standard = 4000 out, Full = 12000 out). Both sets of constants are tuned-by-eye against M019 baseline and may be revisited once Tier 3 runtime-actuals lands; see D027 +/-20% accuracy disclaimer.

The model used for the estimate is the project's primary dispatch model. Resolve via `pricing_resolve_alias`. If `pricing_resolve_alias` returns empty (no alias defined), fall back to a hard-coded default `claude-opus-4-7` (rationale: matches CLAUDE.md `Opus 4.7` declaration). The model name is configurable via `ORCH_COST_ESTIMATE_MODEL` env var.

Latency budget: < 100 ms wall-clock on a 2024-era laptop (FR-22 / CON-9 / SC-15). Implementation discipline: source `pricing.sh` once at the top; do not invoke external commands per row beyond what `pricing.sh` already does; no `jq` / `yq` per row; emit the table via a single printf block.

## Steps

1. **Create the file** `scripts/engine/cost-estimate.sh`. Add `#!/usr/bin/env bash` header, `set -u` (no `-e` — we want graceful degradation), and a re-source guard `[ -n "${_COST_ESTIMATE_SH_SOURCED:-}" ] && return 0; _COST_ESTIMATE_SH_SOURCED=1`.

2. **Resolve project root** via `BASH_SOURCE[0]` → `..` → `..` (bash 3.2 safe; mirrors `pricing.sh` `_pricing_project_root`).

3. **Source `scripts/lib/pricing.sh`** at the top of the file (after the re-source guard). Bare `.` builtin with absolute path. No subshell wrapping.

4. **Per-tier constants** — define as plain top-level integer assignments (bash 3.2: no `declare -A`, parallel indexed arrays):
   ```
   _CE_TIERS_NAME_0="quick";   _CE_TIERS_LABEL_0="Quick";    _CE_TIERS_OVERHEAD_0=800;   _CE_TIERS_OUT_0=1500;   _CE_TIERS_QUALITY_0="best-effort"
   _CE_TIERS_NAME_1="standard";_CE_TIERS_LABEL_1="Standard"; _CE_TIERS_OVERHEAD_1=2400;  _CE_TIERS_OUT_1=4000;   _CE_TIERS_QUALITY_1="self-review"
   _CE_TIERS_NAME_2="full";    _CE_TIERS_LABEL_2="Full";     _CE_TIERS_OVERHEAD_2=6800;  _CE_TIERS_OUT_2=12000;  _CE_TIERS_QUALITY_2="adversarial-gate"
   ```

5. **Library function `cost_estimate_resolve_model`** — prints the model id used for estimation:
   - If `ORCH_COST_ESTIMATE_MODEL` is set and non-empty, print it and return.
   - Else, run `pricing_resolve_alias "default"` and print the result if non-empty.
   - Else, print `claude-opus-4-7` (hard-coded fallback).

6. **Library function `cost_estimate_per_tier "<description>" [--format text|json]`** — emits per-tier estimates.
   - Compute `desc_chars = ${#description}` (bash builtin; no fork).
   - For each tier index 0..2:
     - `prompt_chars = desc_chars + overhead_i`
     - `input_tokens = chars_to_tokens_quartile prompt_chars` (sourced from pricing.sh)
     - `output_tokens = _CE_TIERS_OUT_i`
     - If `pricing_file_present` returns 0 AND `pricing_is_stale` returns 1 (i.e. fresh), call `pricing_estimate_cost_usd "$input_tokens" "$output_tokens" "$model"`; capture stdout.
     - If the cost string is empty (estimate failed) or pricing is stale/missing, set `cost_usd=` (empty / null sentinel) and `pricing_warning=$(pricing_warning_reason)` (or set warning to a sentinel like `pricing-stale`/`pricing-missing` based on degradation tier).
     - Else `pricing_warning=""`.
   - Output format:
     - `--format text` (default): emit a 3-row table with header. Columns: `TIER  COST_USD  INPUT_TOK  OUTPUT_TOK  QUALITY  RECOMMENDED`. RECOMMENDED column = `*` for the recommended tier, blank otherwise. Cost cell renders `(unavailable)` when cost_usd is empty. Append a one-line trailer per D027: `estimates +/-~20%; see commands/cost.md#accuracy`.
     - `--format json`: emit a single-line JSON object: `{"recommended":"<tier>","tiers":{"quick":{"cost_usd":<num-or-null>,"input_tokens":<int>,"output_tokens":<int>,"quality":"best-effort","pricing_warning":"<str>"},"standard":{...},"full":{...}}`. Use printf-built JSON (no `jq`); the verifier will parse it.

7. **Library function `cost_estimate_recommend "<description>"`** — calls `bash "$REPO_ROOT/scripts/engine/intensity-recommend.sh" --description "$description" 2>/dev/null`, greps `^intensity=` line, lowercases the value via `tr '[:upper:]' '[:lower:]'` (no `${var,,}` per CON-7), and prints one of `quick|standard|full`. On any failure (script absent, parse fails), print `standard` as a safe default and emit `WARN: cost-estimate fallback recommendation=standard reason=<reason>` to stderr.

8. **CLI mode** — when `${BASH_SOURCE[0]}` equals `$0`:
   - Parse `--description "<text>"` (required), `--format text|json` (default text), `--help`/`-h`.
   - Resolve recommended tier via `cost_estimate_recommend`.
   - Call `cost_estimate_per_tier "$description" --format "$format"`, passing the recommended tier through (or letting the function look it up — choose one consistent path; document inline). Concrete shape: `cost_estimate_per_tier` reads `_CE_RECOMMENDED` module variable set by `cost_estimate_recommend`; CLI mode sets it before calling. Library callers (T02) set `_CE_RECOMMENDED` directly to skip the inner `intensity-recommend.sh` call when they already have the recommendation.
   - Exit 0 on success, 2 on usage error, 0 with `(unavailable)` cells on pricing degradation (never abort per CON-5).

9. **Latency discipline (FR-22 / CON-9 / SC-15)** — < 100 ms wall-clock target. Implementation rules:
   - Source `pricing.sh` once at the top of the file. The re-source guard prevents repeat loads.
   - Inside the per-tier loop, call `pricing_estimate_cost_usd` directly (it is a bash function, no fork). Do NOT `bash -c`, do NOT spawn subshells per row.
   - The optional `cost_estimate_recommend` call to `intensity-recommend.sh` is the dominant cost (forks bash + invokes capability profile probe). To bound it, set `INTENSITY_RECOMMEND_FAST_PATH=1` env var if defined (T02 sets this when calling from the recommendation hook — re-entry is idempotent and the cached recommendation is reused). Document the env-var contract in a comment block at the top.
   - For the verifier (T04) to measure the inner library function in isolation, expose `cost_estimate_per_tier` as the perf-bench entry point (the verifier scripts the call with `_CE_RECOMMENDED=standard` pre-set so it does not re-fork `intensity-recommend.sh`).

10. **Zero-LLM-token discipline (FR-21 / CON-6).** The script MUST NOT contain any of: `claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`. The only sourced library is `pricing.sh`. The only forked command is `bash scripts/engine/intensity-recommend.sh` in CLI mode (which itself is bash-only).

11. **bash 3.2 compat (CON-7).** No `declare -A`. No `<<<` herestrings (use `printf '%s\n' "$x" | cmd`). No `mapfile`/`readarray`. No `${var^^}` / `${var,,}` (use `tr`). No `<(...)` process substitution. No `&>` redirection.

12. **`chmod +x scripts/engine/cost-estimate.sh`.**

## Must-Haves

- File `scripts/engine/cost-estimate.sh` exists, is executable, ≥ 200 lines, contains the literal string `char-quartile`.
- Sourcing the file produces no stdout / stderr; all behavior gated behind `${BASH_SOURCE[0]} == ${0}`.
- CLI accepts `--description` (required), `--format text|json`, `--help`.
- Library exports `cost_estimate_per_tier`, `cost_estimate_recommend`, `cost_estimate_resolve_model` after sourcing.
- Live invocation `bash scripts/engine/cost-estimate.sh --description "add a TypeScript rewrite"` exits 0 and prints a 3-row table with header + accuracy trailer.
- Live invocation with the same description and `--format json` exits 0 and prints a single-line JSON object containing `recommended` and `tiers.{quick,standard,full}.{cost_usd,input_tokens,output_tokens,quality,pricing_warning}`.
- Zero-LLM-token: file does not match `(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)`.
- bash 3.2 compat: file does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,})`.

## Verification

```bash
bash scripts/engine/cost-estimate.sh --description "add a TypeScript rewrite of the parser"
```

The above must exit 0 and print one paired cost+quality 3-row table to stdout with the recommended tier marked. Per-contract verifiers (Goodhart pairing, latency, pricing degradation, JSON shape, zero-LLM-token, bash 3.2) live in T04 and are wired into `scripts/verify/m027-p01-suite.sh`. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` runs at the phase boundary, not at T01 task verification.

## Inputs

### From Previous Tasks

None — T01 is the dependency root for P01.

### From Disk (Pre-existing)

- `scripts/lib/pricing.sh` — sourceable; exposes `pricing_file_path`, `pricing_file_present`, `pricing_is_stale`, `pricing_lookup_rates`, `pricing_resolve_alias`, `pricing_estimate_cost_usd`, `chars_to_tokens_quartile`, `pricing_warning_reason`. Re-source guard `_PRICING_SH_SOURCED`. No new functions are added by this task; this task is a consumer.
- `scripts/engine/intensity-recommend.sh` — outputs 8 key=value lines (`intensity=`, `confidence=`, `reasoning=`, `scope=`, `risk_level=`, `complexity=`, `risk_signals=`, `cap_score=`). T01 forks it via `bash` to obtain the `intensity=` line. T02 will modify this script; T01 does NOT modify it.
- `.orchestrator/config/pricing.yml` — read by `pricing.sh`. May be missing / stale; estimator must degrade gracefully.

## Constraints

- **CON-1 / FR-12 (read-only)**: This task MUST NOT write to or rewrite any `execution-log.jsonl` or any project-tree file beyond the script itself. Estimator output goes to stdout. T04's read-only verifier will run `git diff --quiet` after invocation.
- **CON-6 / FR-21 (zero-token)**: bash + sourced `pricing.sh` only. No LLM invocation. T04's zero-LLM-token verifier will grep this file.
- **CON-7 (bash 3.2)**: T04's bash32-compat verifier will grep this file.
- **CON-9 / FR-22 / SC-15 (latency)**: < 100 ms wall-clock target. Sourcing `pricing.sh` once + 3-tier iteration + 1 fork to `intensity-recommend.sh` + 1 printf block is the budget. If T04's perf verifier shows > 100 ms with `_CE_RECOMMENDED=standard` pre-set (so the inner intensity-recommend fork is bypassed), T01 must be revisited — the likely culprit will be per-row pricing.sh function call overhead under the bash interpreter; the fix is to inline the rate-multiply arithmetic into a single `awk` pass.
- **CON-4 / FR-20 (Goodhart pairing)**: Every output row carries cost AND quality. The text-format renderer MUST refuse to drop the QUALITY column. If pricing data is unavailable, cost cells render `(unavailable)`; the QUALITY column still renders.
- **D026 (JSON shape)**: `--format json` emits the contract pinned in D026 — top-level `cost_estimates` (or `tiers`; use exactly one). Reconciliation: in this T01 file the JSON top-level shape is `{"recommended":"<tier>","tiers":{...}}` because the estimator owns its own JSON contract; T02 attaches the `cost_estimates` object as a sibling of the existing `intensity-recommend.sh` JSON output (different surface, same per-tier inner shape). The per-tier inner shape (`cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning` plus `quality`) is identical across both surfaces.
- **D027 (accuracy disclaimer)**: Text output appends the verbatim trailer `estimates +/-~20%; see commands/cost.md#accuracy` as the last line.
- **MEM004 carve-out applies here**: this is emitter-internal code, so pipes / `$()` / `awk` are permitted *inside* the script. The AD-19 single-script-file shape rule applies only to `Check:` commands at task and phase plan level.

## Expected Output

After this task:

1. `scripts/engine/cost-estimate.sh` exists, ≥ 200 lines, executable, sourceable.
2. Running `bash scripts/engine/cost-estimate.sh --description "<task>"` against this repo prints a 3-row table with header + recommended-tier marker + accuracy trailer, exit 0.
3. Running with `--format json` prints a single-line JSON object with `recommended` + `tiers.{quick,standard,full}` shape.
4. Running under `ORCH_PRICING_FILE=/tmp/nonexistent.yml` prints `(unavailable)` cost cells but still emits the 3-row table + recommendation + override hint, exit 0.
5. Sourcing the file (e.g., `. scripts/engine/cost-estimate.sh`) produces no stdout / stderr; functions `cost_estimate_per_tier`, `cost_estimate_recommend`, `cost_estimate_resolve_model` are defined.
6. `git diff --quiet` after running the CLI on a sample description returns exit 0.
