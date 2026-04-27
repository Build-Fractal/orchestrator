---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M027"
name: "dispatch-time predictive surface helper + commands/dispatch.md integration (scripts/dispatch/predictive-surface.sh)"
depends_on: []
---

## Prerequisites

- M027/P01 has shipped `scripts/engine/intensity-recommend.sh` (367+ lines, executable, sourceable). Accepts `--description <text>`, `--format text|json`, `--no-cost-annotation`, `--analyze-output <text-or-path>`, `--profile-output <text-or-path>`. Default text mode emits 8 byte-stable key=value lines (intensity / confidence / reasoning / scope / risk_level / complexity / risk_signals / cap_score) followed by a per-tier cost-annotation block (header `# cost estimates (M027/P01)`, 9 numeric lines, 3 quality lines, 1 cost_pricing_warning roll-up line). Module-scope `_CE_RECOMMENDED` slot + `INTENSITY_RECOMMEND_FAST_PATH=1` short-circuit prevent the inner intensity-recommend re-fork when the cost library is sourced from the same script that would otherwise fork it.
- M027/P01 has shipped `scripts/engine/cost-estimate.sh` (466 lines, executable, sourceable). Library functions: `cost_estimate_per_tier`, `cost_estimate_recommend`, `cost_estimate_resolve_model`. Re-source guard `_COST_ESTIMATE_SH_SOURCED`.
- T01 has added `predictive_cost_surface` to the `VALID_KEYS` list in `scripts/state/read-config.sh` (co-edited with `efficiency_footer`).
- Pre-existing `commands/dispatch.md` (161 lines, MEM012-shaped). Sections in current order: frontmatter / Title / Intensity Behavior / Prerequisites / Context Construction / Dispatch Strategy / Execution Recording / Post-Dispatch / Idempotency / Error Handling / Claude Code Appendix / Gotchas / Referenced Scripts / Referenced Templates.
- bash 3.2 / POSIX sh discipline (CON-7, MEM001).
- AD-19 (single-script-file `Check:` shape): this task's `## Verification` block is a SINGLE bash invocation of T03's own deliverable. T03 ships its own scoped precheck.

## Description

Create `scripts/dispatch/predictive-surface.sh` — the helper script that backs the M027/P02 dispatch-time predictive confirmation surface. The helper is sourceable as a library AND runnable as a CLI. It re-uses the P01 cost-annotation hook (`scripts/engine/intensity-recommend.sh --format text` with `_CE_RECOMMENDED` pre-set + `INTENSITY_RECOMMEND_FAST_PATH=1` exported) to render a one-block predictive view (recommended tier highlighted, per-tier cost+quality table, one-line override prompt). The default mode (interactive: not `--yes`, not `ORCHESTRATOR_AUTO=1`, not `--no-predict`, not `config.predictive_cost_surface: false`, intensity in `{standard, full}`) renders the surface. The suppressed mode (any of the suppression conditions met OR intensity = `quick`) emits exactly zero stdout, exit 0 — load-bearing CON-3 / SC-17 byte-identity contract that T04 gates against.

This task ALSO updates `commands/dispatch.md` to document the predictive-surface attach point (after the `## Dispatch Strategy` section, before `## Execution Recording`) and the suppression matrix (`--yes`, `orchestrator:auto` / `ORCHESTRATOR_AUTO=1`, `--no-predict`, `config.predictive_cost_surface: false`, intensity = `quick`).

#Q-16 resolution (closed in P02-PLAN): always-on with `--no-predict` operator-override flag. Rationale documented in P02-PLAN. The helper accepts `--no-predict` as a first-class suppression flag; the verifier `m027-p02-suppression-matrix.sh` exercises it.

The helper preserves operator-override (CON-10) by emitting a one-line override prompt (`override: press 1=quick 2=standard 3=full, or Enter to accept recommended`) on the last line of the surface block. This prompt is informational only — the helper does NOT read stdin; the calling `orchestrator:dispatch` flow handles override capture (the agent runtime interprets the prompt at command-execution time). The helper's contract is "render the surface; let the runtime handle interactivity" — keeps the helper bash-only and read-only.

## Steps

1. **Create `scripts/dispatch/predictive-surface.sh`** with the following structure (bash 3.2 compat, ~140 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/predictive-surface.sh — M027/P02/T03 dispatch-time predictive surface helper.
   #
   # Sourceable as a library (function predictive_surface_render) AND runnable as a CLI.
   # Default mode (interactive, intensity in {standard,full}, none of the suppression
   # conditions met) renders a one-block predictive surface — recommended tier
   # highlighted, per-tier cost+quality table, one-line override prompt.
   # Suppressed mode (any of: --yes, ORCHESTRATOR_AUTO=1, --no-predict,
   # config.predictive_cost_surface=false, intensity=quick) emits zero stdout,
   # exit 0 — load-bearing CON-3/SC-17 byte-identity contract.
   #
   # Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
   # Zero-LLM-token (FR-21/CON-6): bash + invocation of intensity-recommend.sh only.
   # Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no herestring redirect.
   # CON-10 (operator-override preserved): one-line override prompt on last line.

   set -u

   if [ -n "${_PREDICTIVE_SURFACE_SH_SOURCED:-}" ]; then
     return 0 2>/dev/null || true
   fi
   _PREDICTIVE_SURFACE_SH_SOURCED=1

   _PS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _PS_PROJECT_ROOT="$(cd "$_PS_SCRIPT_DIR/../.." && pwd)"

   # predictive_surface_render <description> <intensity> <suppress-flag>
   #   When <suppress-flag> = 1, emits zero stdout (and returns 0).
   #   When <intensity> = quick, emits zero stdout (suppression by tier).
   #   Else emits the one-block predictive surface to stdout; returns 0.
   predictive_surface_render() {
     local description="$1"
     local intensity="$2"
     local suppress="$3"
     if [ "$suppress" = "1" ]; then
       return 0
     fi
     case "$intensity" in
       standard|full) ;;
       *) return 0 ;;
     esac
     # Pre-set the recommendation slot + fast-path env so the inner
     # intensity-recommend re-fork is short-circuited.
     export INTENSITY_RECOMMEND_FAST_PATH=1
     _CE_RECOMMENDED="$intensity"
     export _CE_RECOMMENDED
     # Invoke the P01 cost-annotation hook (text mode).
     local hook_out
     hook_out="$(bash "$_PS_PROJECT_ROOT/scripts/engine/intensity-recommend.sh" \
       --description "$description" \
       --format text \
       --analyze-output "intensity=$intensity\nconfidence=high\n" \
       --profile-output "cap_score=80\n" \
       2>/dev/null || true)"
     if [ -z "$hook_out" ]; then
       # Degraded — emit a minimal one-line surface with a pricing-warning hint.
       printf '%s\n' "predictive_cost_surface: estimate unavailable; recommended=$intensity (override: --no-predict to skip)"
       return 0
     fi
     # Render the surface block.
     printf '%s\n' "predictive_cost_surface (M027/P02)"
     printf '%s\n' "  recommended: $intensity"
     # Stream the cost-annotation block (lines starting with cost_) verbatim.
     printf '%s\n' "$hook_out" | grep -E '^cost_|^# cost estimates' || true
     printf '%s\n' "  override: press 1=quick 2=standard 3=full, or Enter to accept recommended (or pass --no-predict to skip)"
     return 0
   }

   # CLI entry point — only when invoked as a script (not sourced).
   if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
     DESCRIPTION=""
     INTENSITY=""
     NO_PREDICT=0
     YES_FLAG=0
     CONFIG_DEFAULTS=""
     while [ $# -gt 0 ]; do
       case "$1" in
         --description) DESCRIPTION="$2"; shift 2 ;;
         --intensity)   INTENSITY="$2"; shift 2 ;;
         --no-predict)  NO_PREDICT=1; shift ;;
         --yes)         YES_FLAG=1; shift ;;
         --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
         --help|-h)
           printf '%s\n' "Usage: predictive-surface.sh --description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]"
           exit 0 ;;
         *) shift ;;
       esac
     done
     if [ -z "$DESCRIPTION" ] || [ -z "$INTENSITY" ]; then
       printf '%s\n' "ERROR: --description and --intensity are required" >&2
       exit 2
     fi

     # Resolve suppression conditions.
     SUPPRESS=0
     if [ "$NO_PREDICT" -eq 1 ]; then SUPPRESS=1; fi
     if [ "$YES_FLAG" -eq 1 ]; then SUPPRESS=1; fi
     if [ -n "${ORCHESTRATOR_AUTO:-}" ] && [ "$ORCHESTRATOR_AUTO" != "0" ]; then
       SUPPRESS=1
     fi

     # Resolve config knob — env var ORCH_PREDICTIVE_COST_SURFACE overrides;
     # then read-config. When config resolves to "false", force suppress.
     if [ "$SUPPRESS" -eq 0 ]; then
       cfg_val="${ORCH_PREDICTIVE_COST_SURFACE:-}"
       if [ -z "$cfg_val" ] && [ -x "$_PS_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
         cfg_val="$(bash "$_PS_PROJECT_ROOT/scripts/state/read-config.sh" predictive_cost_surface 2>/dev/null || true)"
       fi
       case "$cfg_val" in
         false|FALSE|False|0|no|NO) SUPPRESS=1 ;;
       esac
     fi

     predictive_surface_render "$DESCRIPTION" "$INTENSITY" "$SUPPRESS"
     exit 0
   fi
   ```

2. **Make the script executable**: `chmod +x scripts/dispatch/predictive-surface.sh`.

3. **Edit `commands/dispatch.md`** — insert ONE new section between the existing `## Dispatch Strategy` section and the existing `## Execution Recording` section. The new section is titled `## Predictive Surface (M027/P02)` and reads:

   ```markdown
   ## Predictive Surface (M027/P02)

   Before invoking the dispatch (subagent or sequential), surface a one-block predictive view showing the estimated cost at each intensity tier (Quick / Standard / Full), the recommended tier, and a one-keystroke override prompt. The surface is rendered by:

   ```bash
   bash scripts/dispatch/predictive-surface.sh --description "<task-description>" --intensity <recommended-tier>
   ```

   ### Suppression Matrix

   The predictive surface is suppressed (zero stdout, dispatch output remains byte-identical to pre-M027 `orchestrator:dispatch`) when ANY of:

   1. The `--yes` flag is passed to `orchestrator:dispatch`.
   2. `ORCHESTRATOR_AUTO=1` is set in the environment (set by `orchestrator:auto`).
   3. The `--no-predict` flag is passed to `orchestrator:dispatch` (operator-override per #Q-16 resolution).
   4. The config knob `predictive_cost_surface` resolves to `false`. Resolution chain: env `ORCH_PREDICTIVE_COST_SURFACE` → local config → project config → defaults. Default is `true`.
   5. The recommended intensity is `quick` (predictive surface is not surfaced for the cheapest tier — the minimum information-theoretic value of the surface is at Standard or higher).

   Otherwise, render the surface.

   ### Operator Override (CON-10)

   The surface ends with a one-line override prompt: `override: press 1=quick 2=standard 3=full, or Enter to accept recommended (or pass --no-predict to skip)`. The dispatch flow captures the operator's keystroke and adjusts the intensity tier accordingly before constructing the dispatch payload. Override is one keystroke; coercion is never the design goal (per AD-4 strategic positioning).

   ### Read-Only

   The predictive surface helper is a read-only consumer of `scripts/engine/intensity-recommend.sh` and `scripts/lib/pricing.sh` — it never writes to `execution-log.jsonl`, never writes to config, never invokes an LLM (FR-12 / CON-1, FR-21 / CON-6).
   ```

4. **Add `scripts/dispatch/predictive-surface.sh` to the `## Referenced Scripts` section** at the end of `commands/dispatch.md`. Insert as a new bullet after the existing `scripts/lifecycle/record-result.sh` line:

   ```markdown
   - `scripts/dispatch/predictive-surface.sh` — dispatch-time predictive surface helper (M027/P02). Sources or forks `scripts/engine/intensity-recommend.sh` for the per-tier cost-annotation block. Read-only.
   ```

5. **Verify NO existing sections were re-ordered or re-worded.** The exact pre-edit shape (frontmatter / Title / Intensity Behavior / Prerequisites / Context Construction / Dispatch Strategy / Execution Recording / Post-Dispatch / Idempotency / Error Handling / Claude Code Appendix / Gotchas / Referenced Scripts / Referenced Templates) must be preserved with the single insertion of `## Predictive Surface (M027/P02)` between Dispatch Strategy and Execution Recording, plus the one new bullet under Referenced Scripts.

6. **Bash 3.2 / pure-script discipline**:
   - The helper script body uses pipes / `$(...)` / `grep -E` (MEM004 emitter-internal carve-out).
   - No `<<<`, no `<(...)`, no `mapfile`, no `${var^^}`, no `&>`, no `declare -A`.
   - **Comment-hygiene** (carry-forward from M027/P00 + M027/P01 lesson): doc-comments do not list bash-4 forbidden constructs literally; "no <<< herestring redirect" is the safe phrasing — the literal token `<<<` does NOT appear in this file body anywhere.
   - The markdown body of `commands/dispatch.md` likewise contains no forbidden constructs in fenced bash blocks.

7. **Read-only discipline**: The helper invokes `intensity-recommend.sh` (which is read-only per FR-12 / CON-1) and `read-config.sh` (which only reads). No writes to disk. No JSONL appends. The override prompt is informational; the helper does NOT read stdin.

## Must-Haves

- File `scripts/dispatch/predictive-surface.sh` exists, ≥ 80 lines, executable.
- File contains the literal string `predictive_cost_surface` (config knob reference + surface block title).
- File contains a function definition `predictive_surface_render`.
- File contains a CLI entry-point guard (`BASH_SOURCE` / `$0` comparison) so the script is sourceable AND runnable.
- File reads / honors the `--no-predict` flag.
- File reads / honors the `--yes` flag.
- File reads / honors the `ORCHESTRATOR_AUTO` env var (suppression).
- File reads / honors the `predictive_cost_surface` config knob (via env var `ORCH_PREDICTIVE_COST_SURFACE` or `read-config.sh predictive_cost_surface`).
- File invokes `scripts/engine/intensity-recommend.sh` (delegation to the P01 hook).
- File pre-sets `INTENSITY_RECOMMEND_FAST_PATH=1` and `_CE_RECOMMENDED` before invoking the hook (no-recursion invariant per P01/T02 contract).
- File contains the one-line override prompt (`override: press 1=quick 2=standard 3=full`).
- File `commands/dispatch.md` contains a `## Predictive Surface` heading.
- File `commands/dispatch.md` references `scripts/dispatch/predictive-surface.sh` in the `## Referenced Scripts` section.
- File `commands/dispatch.md` documents the 5-condition suppression matrix (`--yes`, `ORCHESTRATOR_AUTO`, `--no-predict`, `predictive_cost_surface: false`, intensity = `quick`).
- File `commands/dispatch.md` retains its pre-edit canonical sections in the pre-edit order.
- Running `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes` emits zero stdout, exit 0.
- Running `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity quick` emits zero stdout, exit 0 (intensity-based suppression).

## Verification

```bash
bash scripts/verify/m027-p02-t03-shape-precheck.sh
```

This T03-scoped precheck verifier (ships with T03) asserts T03's must-haves: `predictive-surface.sh` exists ≥ 80 lines and is executable, contains `predictive_cost_surface`, contains the `predictive_surface_render` function, contains a `BASH_SOURCE`/`$0` guard, contains the `--no-predict`, `--yes`, `ORCHESTRATOR_AUTO`, and `predictive_cost_surface` references, invokes `scripts/engine/intensity-recommend.sh`, pre-sets `INTENSITY_RECOMMEND_FAST_PATH=1` and `_CE_RECOMMENDED`, contains the override prompt, `commands/dispatch.md` has the `## Predictive Surface` heading + the 5-condition suppression-matrix documentation + the new bullet under Referenced Scripts, and that `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes` and `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity quick` both emit zero stdout / exit 0.

T04 ships the canonical phase-level verifiers `m027-p02-predictive-surface-shape.sh`, `m027-p02-suppression-matrix.sh`, `m027-p02-dispatch-md-shape.sh`, `m027-p02-predictive-surface-latency.sh`, and `m027-p02-predictive-goodhart-pairing.sh` — each subsumes a slice of this precheck. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` runs at the phase boundary, not at T03 task verification.

The precheck script is created as part of T03. T04 may delete this precheck once the canonical verifiers ship, mirroring the M027/P01/T03 + T04 pattern. The precheck lives at `scripts/verify/m027-p02-t03-shape-precheck.sh` and follows the standard verifier skeleton.

## Inputs

### From Previous Tasks

- T01: `scripts/state/read-config.sh` `VALID_KEYS` — modified by T01 to include `predictive_cost_surface`. This task's helper invokes `bash scripts/state/read-config.sh predictive_cost_surface`; the call returns a resolved value (`true`/`false`/empty) that the helper interprets via the case-statement above.

### From Disk (Pre-existing)

- `scripts/engine/intensity-recommend.sh` (P01) — invoked from `predictive_surface_render`. Accepts `--description <text>`, `--format text|json`, `--analyze-output <text>`, `--profile-output <text>`. Default text mode emits 8 byte-stable key=value lines + per-tier cost-annotation block. The helper passes `--analyze-output` and `--profile-output` inline strings to bypass the inner `intensity-analyze.sh` + `detect-capabilities.sh` forks (latency optimization; mirrors the P01/T04 verifier pattern).
- `scripts/engine/cost-estimate.sh` (P01) — transitively sourced by `intensity-recommend.sh` (no direct invocation from this helper). Library functions: `cost_estimate_per_tier`, `cost_estimate_recommend`. The `_CE_RECOMMENDED` slot pre-set by the helper short-circuits the inner intensity-recommend re-fork (no-recursion invariant).
- `scripts/state/read-config.sh` — invoked to resolve `predictive_cost_surface` config value.
- `commands/dispatch.md` (161 lines) — modified in place. Pre-edit canonical sections must be preserved in pre-edit order.
- `commands/init.md`, `commands/cost.md`, `commands/status.md` — reference shapes for MEM012 canonical commands convention.

## Constraints

- **CON-3 / SC-17 (back-compat byte-identity)**: Suppressed-mode emits zero stdout. The T04 verifier `m027-p02-suppression-matrix.sh` exercises all 5 suppression paths.
- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. Verifier scans this file in T04.
- **CON-9 / FR-22 / SC-15 (latency carry-forward)**: Inner library measurement (with `INTENSITY_RECOMMEND_FAST_PATH=1` + `_CE_RECOMMENDED` pre-set) under 100 ms. Outer wall-clock includes ~200 ms of bash startup + fork overhead on macOS. T04's latency verifier hard-fails on inner measurement; outer measurement carries `RELAX-CANDIDATE` annotation.
- **CON-10 (operator-override preserved)**: One-line override prompt on the last line of the surface block.
- **CON-4 / SC-18 (Goodhart pairing carry-forward)**: The cost-annotation block emitted via `intensity-recommend.sh --format text` already carries paired cost+quality per the P01 contract. T04's `m027-p02-predictive-goodhart-pairing.sh` re-asserts at this attach point.
- **FR-12 / CON-1 (read-only)**: No writes to disk. No JSONL appends. The override prompt is informational; helper does NOT read stdin.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` in the file body.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T03-scoped precheck).
- **MEM012 (command structure)**: New section in `commands/dispatch.md` follows the canonical shape; new bullet under Referenced Scripts follows the existing bullet style.
- **MEM004 (emitter-internal carve-out)**: The helper script body MAY use pipes / `$()` / `grep -E` / `printf`.
- **#Q-16 resolution**: Always-on by default with `--no-predict` operator-override flag (no session-cache, no hidden state). Documented in P02-PLAN.

## Expected Output

After this task:

1. `scripts/dispatch/predictive-surface.sh` exists, ≥ 80 lines, executable, satisfies the must-haves.
2. `commands/dispatch.md` exists, ≥ 200 lines (post-edit), contains the new `## Predictive Surface (M027/P02)` section between Dispatch Strategy and Execution Recording, contains the 5-condition suppression matrix, contains the new `predictive-surface.sh` bullet under Referenced Scripts.
3. `scripts/verify/m027-p02-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.
4. Running `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes` emits zero stdout, exit 0.
5. Running `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity quick` emits zero stdout, exit 0.
6. Running `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard` (interactive default) emits a multi-line block titled `predictive_cost_surface (M027/P02)` with paired cost+quality lines and the override prompt as the last line, exit 0.
7. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
