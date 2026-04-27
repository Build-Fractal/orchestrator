---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M027"
name: "efficiency-footer helper + efficiency_footer config knob (scripts/diagnostics/efficiency-footer.sh)"
depends_on: []
---

## Prerequisites

- M027/P00 has shipped `scripts/diagnostics/metrics-rollup.sh` (sourceable + CLI). CLI accepts `--granularity task|phase|milestone|project`, `--milestone Mxxx`, `--phase Pxx`, `--task <id>`, `--source estimate|runtime|aggregate|all`, `--log <path>`, `--help`. Live invocation against `.orchestrator/milestones/M019/execution-log.jsonl` exits 0 and emits one paired cost+quality milestone row.
- `scripts/state/read-config.sh` exists and resolves config keys from a 4-layer precedence chain (env var → local → project → defaults). Existing valid keys: `default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed`. **This task adds `efficiency_footer` to the valid-key list** so `read-config.sh efficiency_footer` returns a resolved value.
- `scripts/state/find-active-milestone.sh` exists and emits the active milestone's `M###` ID (or empty when no active milestone) — used by the helper to scope the rollup. (If absent in the codebase under that exact name, the helper falls back to scanning `.orchestrator/milestones/M*` for the most-recently-modified milestone with an `execution-log.jsonl`.)
- bash 3.2 / POSIX sh discipline (CON-7, MEM001): no `declare -A`, no `<<<` herestrings, no `mapfile`/`readarray`, no process substitution `<(...)` / `>(...)`, no `${var^^}` / `${var,,}` case folding, no `&>` merged-redir.
- AD-19 (single-script-file `Check:` shape): this task's `## Verification` block is a SINGLE bash invocation of T01's own deliverable. Per the M027/P00 + M027/P01 parser-shape lesson, it must NOT reference future tasks' artifacts (T04's canonical verifier ships later); T01 ships its own scoped precheck.

## Description

Create `scripts/diagnostics/efficiency-footer.sh` — the helper script that backs the M027/P02/T02 `orchestrator:status` efficiency footer. The helper is sourceable as a library (one entry-point function) AND runnable as a CLI (default behavior when `BASH_SOURCE[0] == $0`). It re-uses the P00 rollup engine to compute milestone-to-date cost + quality aggregates and prints a one-block footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`. Under `--quiet` (or when the config knob `efficiency_footer` resolves to `false`), it emits exactly zero stdout, exit 0 — this is the load-bearing CON-3 / SC-3 contract that the T02 byte-identity baseline + T04 verifier gate against.

This task also adds `efficiency_footer` to the valid-key list in `scripts/state/read-config.sh` so that `read-config.sh efficiency_footer` (or `read-config.sh --key efficiency_footer`) returns a resolved value (default `true` when nothing is configured).

The CLI is a transient surface (operator-facing diagnostic); it is read-only (FR-12 / CON-1 — no writes to `execution-log.jsonl`, no writes to config). Pricing degradation never aborts (CON-5 carry-forward — surfaced via the rollup engine's existing `pricing_warning` propagation).

## Steps

1. **Create `scripts/diagnostics/efficiency-footer.sh`** with the following structure (bash 3.2 compat, ~120 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/efficiency-footer.sh — M027/P02/T01 efficiency footer helper.
   #
   # Sourceable as a library (function efficiency_footer_render) AND runnable as a CLI.
   # CLI emits a one-block efficiency footer (<=6 lines) titled
   # "Efficiency (Tier 1 rollup)" summarizing milestone-to-date cost + quality
   # paired metrics. Under --quiet (or config.efficiency_footer=false), emits
   # exactly zero stdout, exit 0 — load-bearing CON-3/SC-3 byte-identity contract.
   #
   # Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
   # Zero-LLM-token (FR-21/CON-6): bash + invocation of metrics-rollup.sh only.
   # Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no <<<.

   set -u

   if [ -n "${_EFFICIENCY_FOOTER_SH_SOURCED:-}" ]; then
     return 0 2>/dev/null || true
   fi
   _EFFICIENCY_FOOTER_SH_SOURCED=1

   _EFF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _EFF_PROJECT_ROOT="$(cd "$_EFF_SCRIPT_DIR/../.." && pwd)"

   # efficiency_footer_render <milestone-or-empty> <quiet-flag>
   #   When <quiet-flag> = 1, emits zero stdout (and returns 0).
   #   When <milestone-or-empty> = empty, falls back to project-granularity rollup.
   #   Always returns exit 0 (never aborts; degraded inputs surface as text).
   efficiency_footer_render() {
     local milestone="$1"
     local quiet="$2"
     if [ "$quiet" = "1" ]; then
       return 0
     fi
     local rollup_out
     if [ -n "$milestone" ]; then
       rollup_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
         --granularity milestone --milestone "$milestone" 2>/dev/null || true)"
     else
       rollup_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
         --granularity project 2>/dev/null || true)"
     fi
     if [ -z "$rollup_out" ]; then
       printf '%s\n' "Efficiency (Tier 1 rollup)"
       printf '%s\n' "Efficiency: no Tier 1 records yet"
       return 0
     fi
     # Extract a small, fixed set of lines for the footer (<=6 total):
     # title + cost + quality + dispatch-count + scope + pricing-warning (if any).
     # The exact extraction is bash 3.2 safe: grep -E + head -n 1 per field.
     # See US-3 AS-1 — paired cost + quality + count.
     local cost_line qual_line count_line scope_line warn_line
     cost_line="$(printf '%s\n' "$rollup_out" | grep -E '^estimated_cost_usd|^cost_usd' | head -n 1)"
     qual_line="$(printf '%s\n' "$rollup_out" | grep -E '^verification_pass_rate|^pass_rate' | head -n 1)"
     count_line="$(printf '%s\n' "$rollup_out" | grep -E '^dispatch_count|^count' | head -n 1)"
     scope_line="$(printf '%s\n' "$rollup_out" | grep -E '^scope=|^granularity=' | head -n 1)"
     warn_line="$(printf '%s\n' "$rollup_out" | grep -E 'pricing_warning' | head -n 1)"
     printf '%s\n' "Efficiency (Tier 1 rollup)"
     [ -n "$scope_line" ] && printf '  %s\n' "$scope_line"
     [ -n "$cost_line" ] && printf '  %s\n' "$cost_line"
     [ -n "$qual_line" ] && printf '  %s\n' "$qual_line"
     [ -n "$count_line" ] && printf '  %s\n' "$count_line"
     [ -n "$warn_line" ] && printf '  %s\n' "$warn_line"
     return 0
   }

   # CLI entry point — only when invoked as a script (not sourced).
   if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
     MILESTONE=""
     PROJECT_FALLBACK=0
     QUIET=0
     CONFIG_DEFAULTS=""
     while [ $# -gt 0 ]; do
       case "$1" in
         --milestone) MILESTONE="$2"; shift 2 ;;
         --project)   PROJECT_FALLBACK=1; shift ;;
         --quiet)     QUIET=1; shift ;;
         --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
         --help|-h)
           printf '%s\n' "Usage: efficiency-footer.sh [--milestone <Mxxx>] [--project] [--quiet] [--config-defaults <path>]"
           exit 0 ;;
         *) shift ;;
       esac
     done

     # Resolve config knob — env var ORCH_EFFICIENCY_FOOTER overrides; then read-config.
     # When config resolves to "false" (case-insensitive), force quiet.
     if [ "$QUIET" -eq 0 ]; then
       cfg_val="${ORCH_EFFICIENCY_FOOTER:-}"
       if [ -z "$cfg_val" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
         cfg_val="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" efficiency_footer 2>/dev/null || true)"
       fi
       case "$cfg_val" in
         false|FALSE|False|0|no|NO) QUIET=1 ;;
       esac
     fi

     # Resolve active milestone if neither --milestone nor --project given.
     if [ -z "$MILESTONE" ] && [ "$PROJECT_FALLBACK" -eq 0 ]; then
       if [ -x "$_EFF_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
         MILESTONE="$(bash "$_EFF_PROJECT_ROOT/scripts/state/find-active-milestone.sh" 2>/dev/null || true)"
       fi
     fi

     efficiency_footer_render "$MILESTONE" "$QUIET"
     exit 0
   fi
   ```

2. **Add `efficiency_footer` to the valid-key list in `scripts/state/read-config.sh`**. The current list is on line 17 of that file:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed"
   ```

   Modify to:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface"
   ```

   (Note: also adds `predictive_cost_surface` — used by T03; co-locating both M027/P02 keys in a single edit avoids two passes over the same file. T03 may verify but should not re-edit.) The default value when nothing is configured is implementation-defined by `read-config.sh`'s "key not found" behavior (currently exit 1 / empty stdout); the helper handles empty-stdout as "default true" via the case-statement above, so no further changes to `read-config.sh`'s default-resolution path are needed.

3. **Make the script executable**: `chmod +x scripts/diagnostics/efficiency-footer.sh`.

4. **Bash 3.2 / pure-script discipline**:
   - The script body uses pipes / `$(...)` / `grep -E` (MEM004 emitter-internal carve-out — AD-19's single-script-file rule binds only `Check:` commands at task/phase plan level, not script internals).
   - No `<<<`, no `<(...)`, no `mapfile`, no `${var^^}`, no `&>`, no `declare -A`.
   - **Comment-hygiene** (carry-forward from M027/P00 + M027/P01 lesson): when CON-7 doc-comments would naturally list bash-4 forbidden constructs literally, reword the prose to describe them by category so the T04 `m027-p02-bash32-compat.sh` verifier grep regex stays clean against this file body. This script's banner says `no <<<` but uses plain ASCII without triggering the regex (the comment refers to "no <<<" in the PROSE, but the literal grep regex matches `<<<` anywhere — so use the safer phrasing "no herestring redirection" in the comment body if it would otherwise false-match).

5. **Read-only discipline**: The script invokes `metrics-rollup.sh` (which is read-only per FR-12 / CON-1) and `read-config.sh` (which only reads). No writes to disk. No JSONL appends.

## Must-Haves

- File `scripts/diagnostics/efficiency-footer.sh` exists, ≥ 80 lines, executable.
- File contains the literal string `Efficiency (Tier 1 rollup)` (footer title).
- File contains a function definition `efficiency_footer_render`.
- File contains a CLI entry-point guard (`BASH_SOURCE` / `$0` comparison) so the script is sourceable AND runnable.
- File reads / honors the `--quiet` flag (case for `--quiet)` in the arg-parse loop).
- File reads / honors the `efficiency_footer` config knob (via env var `ORCH_EFFICIENCY_FOOTER` or `read-config.sh efficiency_footer`).
- File invokes `scripts/diagnostics/metrics-rollup.sh` (delegation to the P00 engine).
- `scripts/state/read-config.sh` `VALID_KEYS` includes `efficiency_footer` and `predictive_cost_surface`.
- Running `bash scripts/diagnostics/efficiency-footer.sh --quiet` emits zero stdout, exit 0.

## Verification

```bash
bash scripts/verify/m027-p02-t01-shape-precheck.sh
```

This T01-scoped precheck verifier (ships with T01) asserts T01's nine must-haves: `efficiency-footer.sh` exists ≥ 80 lines and is executable, contains the `Efficiency (Tier 1 rollup)` title, contains the `efficiency_footer_render` function, contains a `BASH_SOURCE`/`$0` source-vs-CLI guard, contains the `--quiet` arg-parse case, contains a reference to `efficiency_footer` (config knob), invokes `scripts/diagnostics/metrics-rollup.sh`, `read-config.sh` `VALID_KEYS` contains both `efficiency_footer` and `predictive_cost_surface`, and `bash scripts/diagnostics/efficiency-footer.sh --quiet` emits zero stdout / exit 0.

T04 ships the canonical phase-level verifier `m027-p02-efficiency-footer-shape.sh` which subsumes this precheck. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` runs at the phase boundary, not at T01 task verification (per the M027/P00 + M027/P01 parser-shape lesson — task-level Verification must reference only what the task itself produces).

The precheck script is created as part of T01 (its body is a small shell script that performs the nine assertions). T04 may delete this precheck once the canonical verifier ships, mirroring the M027/P01/T03 + T04 pattern (phase summary `cross-phase handoff` paragraph). The precheck lives at `scripts/verify/m027-p02-t01-shape-precheck.sh` and follows the standard verifier skeleton (PROJECT_ROOT via `BASH_SOURCE`; `PASS:` / `FAIL:` to stdout / stderr; exit 0/1).

## Inputs

### From Previous Tasks

- (none — T01 is the entry point of P02; consumes only P00's `metrics-rollup.sh` and `scripts/state/read-config.sh`.)

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (P00) — invoked from `efficiency_footer_render`. Accepts `--granularity milestone --milestone <Mxxx>` and `--granularity project`. Output is a paired cost+quality block. Read-only (FR-12 carry-forward).
- `scripts/state/read-config.sh` — modified in step 2 to include `efficiency_footer` + `predictive_cost_surface` in `VALID_KEYS`. Resolves config values from env / local / project / defaults precedence chain.
- `scripts/state/find-active-milestone.sh` — invoked to detect the active milestone for default-scope resolution. (If absent or non-executable, the helper falls back to the project-granularity rollup; the `|| true` guard makes the call safe.)

## Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. Verifier scans this file in T04.
- **CON-3 / SC-3 (back-compat byte-identity)**: Under `--quiet` or `efficiency_footer=false`, emits zero stdout. The T02 baseline fixture + T04 verifier gate this.
- **CON-5 (never-abort)**: Pricing-warning propagation is the rollup engine's responsibility; this helper just prints the warning line if present. No aborts on missing pricing, missing milestone, or empty log.
- **FR-12 / CON-1 (read-only)**: No writes to disk. Verified by T04's read-only verifier (and by T03's read-only tests, which exercise this helper transitively via the live status invocation).
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` in the file body. Verified by T04's `m027-p02-zero-llm-token.sh`.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T01-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM004 (emitter-internal carve-out)**: The helper script body MAY use pipes / `$()` / `grep -E` / `printf` — these are emitter internals, not `Check:` shape concerns.

## Expected Output

After this task:

1. `scripts/diagnostics/efficiency-footer.sh` exists, ≥ 80 lines, executable, satisfies the nine must-haves.
2. `scripts/state/read-config.sh` `VALID_KEYS` includes `efficiency_footer` and `predictive_cost_surface`.
3. `scripts/verify/m027-p02-t01-shape-precheck.sh` exists, executable, exits 0 against the post-T01 codebase.
4. Running `bash scripts/diagnostics/efficiency-footer.sh --quiet` emits zero stdout, exit 0.
5. Running `bash scripts/diagnostics/efficiency-footer.sh` (no flags, against this repo) emits a short footer block (1–6 lines) prefixed `Efficiency (Tier 1 rollup)`, exit 0.
6. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
