---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M029"
name: "--live branch on render-position.sh + ▽ saved Nk savings marker + display_thresholds.compression_savings_pct config knob"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/render-position.sh` is on disk from P02/T03 (the at-rest renderer this task extends in-place per Boundary Map "produced once in P02 and *extended in place* in P03"). `[ -f scripts/diagnostics/render-position.sh ]` PASS at plan-authoring time.
- `references/file-formats.md` is on disk (`## Configuration (orchestrator-config.yml)` section at line 666). `[ -f references/file-formats.md ]` PASS.
- `templates/orchestrator-config-default.yml` is on disk. `[ -f templates/orchestrator-config-default.yml ]` PASS.
- `scripts/state/read-config.sh` is on disk with `VALID_KEYS` at line 17. `[ -f scripts/state/read-config.sh ]` PASS.
- M019 `dispatch_usage` JSONL schema is closed and exposes `tier1_savings_tokens`, `tier2_savings_tokens`, and a total-tokens field on every `dispatch_usage` record. M018 `payload_breakdown.tier1_savings_tokens` and `tier2_savings_tokens` fields are stable per `references/RUNTIME-ASSUMPTIONS.md`.
- No path-collision: this task creates one new file (`tools/verify/m029-p03-render-position-live-shape.sh`); `[ ! -f tools/verify/m029-p03-render-position-live-shape.sh ]` PASS at plan-authoring time. All other paths are modifications of existing files.

## Description

T01 ships the foundational live-tail surface and the FR-8 marker:

1. **`scripts/diagnostics/render-position.sh` `--live` branch** (additive, in-place modification): a new branch that polls `execution-log.jsonl` via POSIX `tail -f`, full-re-renders the tree on every appended `dispatch_usage` record (#Q-1 — full re-render, no incremental row update; tree fits in <50 rows so the cost is negligible), exits cleanly on SIGTERM/SIGINT.

2. **`▽ saved Nk` marker rendering** (FR-8, AD-5, #Q-G8): when a `dispatch_usage` record's savings ratio `(tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` exceeds the `display_thresholds.compression_savings_pct` knob (default 5.0), the row renders the canonical compact-form marker `▽ saved Nk` where `N = ceil((tier1_savings_tokens + tier2_savings_tokens) / 1000)`. The compact form is the ONLY form emitted in P03 deliverables — no `▽ Nk saved`, no `▽ saved Nk via tier1 cache reuse`, no other variants. Per #Q-G8 the verbose form `via tier1 cache reuse` is reserved for a future `--verbose` mode and is NOT shipped in M029.

3. **`display_thresholds.compression_savings_pct` config knob** (AD-5):
   - `templates/orchestrator-config-default.yml` carries a new top-level `display_thresholds:` block with `compression_savings_pct: 5.0` and a YAML comment annotating the heuristic-default rationale + review trigger.
   - `references/file-formats.md` documents the new block under the existing `## Configuration (orchestrator-config.yml)` section.
   - `scripts/state/read-config.sh` extends its `VALID_KEYS` allowlist to include `display_thresholds.compression_savings_pct` so the dotted form resolves through the standard 4-layer fallback.
   - `render-position.sh` reads the knob via `bash scripts/state/read-config.sh display_thresholds.compression_savings_pct` at `--live` entry; on any read failure (key absent / config corrupt / read-config exit non-zero), the renderer falls back to the hard-coded default `5.0` and emits an advisory `WARN: display_thresholds.compression_savings_pct fallback to default` line on stderr (NOT a hard fail — Principle XI fail-open).

4. **Shape verifier** `tools/verify/m029-p03-render-position-live-shape.sh`: mechanical assertions that the `--live` branch exists in the file body, that the canonical compact-form `▽ saved Nk` literal is present, that the forbidden verbose form `via tier1 cache reuse` is absent (negative-assertion verifier discipline — the verifier code itself names the forbidden token in an assertion string but the deliverable body must not contain it), and that the renderer reads the threshold knob via `read-config.sh`.

5. **Config-shape verifier** `tools/verify/m029-p03-display-thresholds-config-shape.sh`: asserts the new block lands at top level in the default-config template, the `compression_savings_pct: 5.0` line is byte-stable, the docstring annotation appears in `references/file-formats.md`, and `VALID_KEYS` in `read-config.sh` includes the dotted form.

## Steps

1. **Modify `scripts/diagnostics/render-position.sh`** — add the `--live` branch:

   - Extend the existing CLI flag parser to accept `--live` (boolean, no argument).
   - When `--live` is set:
     - Resolve the active milestone's `execution-log.jsonl` path via `find-active-milestone.sh` + `<root>/.orchestrator/milestones/<MID>/execution-log.jsonl` (or honour `--milestone <MID>`).
     - If the path does not exist, wait up to 5 seconds for it to appear (poll loop with 0.5s sleeps); if still absent, emit `ERROR: no execution log under <path>` to stderr and exit 1 (per spec Edge Cases entry "Live-tail target file missing").
     - Read the threshold knob via `bash scripts/state/read-config.sh display_thresholds.compression_savings_pct`; capture stdout to a scalar; on non-zero rc OR empty stdout, fall back to `5.0` and emit `WARN: ...` on stderr.
     - Run an initial full re-render (the existing at-rest tree code path).
     - Enter the tail loop: `tail -f -n 0 "$LOG_PATH"` piped to a `while read -r line` loop; on every line containing `"event":"dispatch_usage"` (substring match — keep parsing simple per AD-19), trigger a full re-render. Trap SIGTERM and SIGINT to break out cleanly.

   - For the marker rendering during the tree walk:
     - For each in-flight task row, scan the most-recent `dispatch_usage` record for that `task_id` from the JSONL stream (single-pass, O(n) over recent lines is acceptable; can be a separate helper function `_rp_latest_dispatch_usage_for_task`).
     - Compute `savings_pct = 100.0 * (tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` using `awk` or bash arithmetic + `printf '%.1f'` (bash 3.2-safe — no associative arrays, no `<<<` herestring; use `printf | awk` for the float division).
     - When `savings_pct >= threshold_pct`, append the marker `printf ' ▽ saved %dk' "$N"` to the row, where `N = ceil((tier1_savings_tokens + tier2_savings_tokens) / 1000)` (use `awk 'BEGIN{ printf("%d", int((s+999)/1000)) }'` or equivalent integer-ceil).

   - **AD-19 discipline inside the renderer body**: complex line-by-line parsing of JSONL is allowed via `awk`/`grep`/`sed` pipes inside function bodies (MEM004 carve-out — AD-19 single-script-file shape applies only to `Check:` command level, not to internal renderer logic). Keep the OUTER CLI flag-handling and tail-loop free of compound chains > 2 stages.

2. **Modify `templates/orchestrator-config-default.yml`** — append a new top-level `display_thresholds:` block (after the `quick_knowledge_token_budget:` / `entry_routing_confidence_floor:` block at the file tail; before EOF):

   ```yaml
   # M029 — display_thresholds (AD-5).
   # FR-8 / AD-5 — minimum compression savings ratio (as a percentage of total
   # dispatch tokens) below which the live-tail render suppresses the
   # `▽ saved Nk` marker on a `dispatch_usage` row. Heuristic default; tune
   # after first 10 milestones of M019 Tier 1 + M018 Tier 2 telemetry.
   # Review trigger: re-evaluate threshold once
   # `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across
   # closed milestones.
   display_thresholds:
     compression_savings_pct: 5.0
   ```

   Bash 3.2 quoting; YAML 1.2 compatible.

3. **Modify `references/file-formats.md`** — under `## Configuration (orchestrator-config.yml)` (line 666), extend the documented key set or add a new sub-section `### Display Thresholds (M029)` documenting:
   - The block name `display_thresholds:`.
   - The single key `compression_savings_pct: 5.0`.
   - The AD-5 rationale text verbatim ("Heuristic default. Tune after first 10 milestones of M019 Tier 1 + M018 Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones.").
   - The cross-reference to FR-8 + AD-5 + the `▽ saved Nk` marker semantics.

4. **Modify `scripts/state/read-config.sh`** — extend the `VALID_KEYS` string at line 17 by appending `display_thresholds.compression_savings_pct` (single space separator). DO NOT change any other line. The dotted-form key resolves through the standard YAML walker that `read-config.sh` already implements for `compression.efficiency_footer.enabled` and `compression.regression_floor`.

5. **Author `tools/verify/m029-p03-render-position-live-shape.sh`** (≥40 lines, executable, AD-19 single-script-file shape, bash 3.2):
   - Asserts `[ -f scripts/diagnostics/render-position.sh ]` and `[ -x scripts/diagnostics/render-position.sh ]`.
   - Asserts the file body contains `--live` (the new flag is wired).
   - Asserts the file body contains `tail -f` (the POSIX-portable polling primitive per CON-2).
   - Asserts the file body contains the literal `▽ saved` and the literal `display_thresholds.compression_savings_pct` and the literal `read-config.sh`.
   - Asserts the file body does NOT contain the forbidden verbose suffix `via tier1 cache reuse` (negative-assertion discipline: this verifier's assertion string DOES contain that literal token but the deliverable body MUST not).
   - Asserts the file body contains the references `FR-7`, `FR-8`, `#Q-1`, `#Q-G8`, `AD-5`.
   - Emits `PASS:` per assertion, `FAIL:` on any miss, and `SUMMARY: m029-p03-render-position-live-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.
   - `chmod +x`.

6. **Author `tools/verify/m029-p03-display-thresholds-config-shape.sh`** (≥30 lines, executable, AD-19, bash 3.2):
   - Asserts `templates/orchestrator-config-default.yml` contains `display_thresholds:` at line start (`grep -n '^display_thresholds:' ...`), and `compression_savings_pct: 5.0` indented under it.
   - Asserts `references/file-formats.md` contains `display_thresholds:`, `compression_savings_pct`, `AD-5`, and the literal phrase `Tune after first 10 milestones`.
   - Asserts `scripts/state/read-config.sh`'s `VALID_KEYS` line contains `display_thresholds.compression_savings_pct`.
   - Emits per-assertion `PASS:`/`FAIL:` + `SUMMARY:` line. Exit 0 iff `fail=0`.

7. **`chmod +x` every new `.sh` file**.

8. **Smoke-run** the renderer's at-rest path against an existing fixture (`tests/m029-acceptance/fixtures/where-mixed-state.fixture/`) to confirm the additive `--live` flag does not regress the at-rest rendering. The output should match the existing `where-mixed-state.golden` byte-stable contract from P02/SC-5.

9. **Smoke-run** the renderer's `--live` path against the same fixture for ~2 seconds (background the process, append a synthetic `dispatch_usage` line to the fixture's `execution-log.jsonl`, kill the renderer, inspect captured stdout for the `▽ saved Nk` marker). This is a hand-verification step — the SC-7 acceptance script in T04 will codify it.

## Must-Haves

This task addresses these P03 phase truths:
- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch with the canonical compact-form `▽ saved Nk` marker (FR-7, FR-8, #Q-1, #Q-G8) gated by the AD-5 threshold knob.
- `references/file-formats.md` + `templates/orchestrator-config-default.yml` + `scripts/state/read-config.sh` document and surface the `display_thresholds.compression_savings_pct` knob (AD-5).

This task creates these P03 phase artifacts:
- `tools/verify/m029-p03-render-position-live-shape.sh`
- `tools/verify/m029-p03-display-thresholds-config-shape.sh`

## Verification

```bash
bash tools/verify/m029-p03-render-position-live-shape.sh
bash tools/verify/m029-p03-display-thresholds-config-shape.sh
```

## Inputs

### From Previous Tasks (P02)

- `scripts/diagnostics/render-position.sh` (the at-rest renderer, T01 extends in-place).
  - Key API: `bash scripts/diagnostics/render-position.sh [--milestone M###] [--expand-all] [--feature <slug>] [--no-cost] [--root <path>]` emits the at-rest tree to stdout. T01 adds `--live`.
  - Internal helpers used: `_rp_yaml_scalar` (frontmatter scalar), `_rp_yaml_inline_list` (inline list parser), `_rp_resolver_capture` (AD-1 single-resolve), the M027 cost-column probe (`grep -m1 -F dispatch_usage`).
- `scripts/diagnostics/summarize-milestone.sh` (P02/T02) — NOT consumed by T01 directly; consumed by T02's preflight surface and T04's SC-8 oracle wrapper.

### From Disk (Pre-existing — closed milestones)

- `scripts/state/read-config.sh` (4-layer config resolver; dotted-form key support already shipped per `compression.efficiency_footer.enabled` precedent).
- M018 `payload_breakdown.tier1_savings_tokens` / `tier2_savings_tokens` field set (closed; no schema change).
- M019 `dispatch_usage` event schema (closed; no schema change).
- POSIX `tail -f` (CON-2 portability assumption A-3).

### From Disk (Pre-existing — modify-in-place)

- `templates/orchestrator-config-default.yml` — top-level YAML config template; T01 appends a new `display_thresholds:` block at the file tail.
- `references/file-formats.md` — file-formats reference doc; T01 extends `## Configuration (orchestrator-config.yml)` with the new block documentation.
- `scripts/state/read-config.sh` — config resolver script; T01 appends one token to the `VALID_KEYS` string at line 17.

## Constraints

- **AD-19 straight-line bash for `Check:` commands**: every verifier MUST be straight-line (NO inline compound chains, NO plain subshells, NO `$(cmd | …)`, NO process substitution). Internal renderer body MAY use `awk`/`grep`/`sed` pipes inside function bodies (MEM004 carve-out — AD-19 applies at `Check:` command level, not inside renderer logic).
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO `<<<` herestring, parallel indexed arrays for any per-item tracking. Use `printf | awk` for float arithmetic; use `awk 'BEGIN{...}'` for integer ceiling.
- **CON-1 / FR-14 read-only**: the `--live` branch never writes to `.orchestrator/`. The fall-back-to-default branch on threshold-read failure emits ONLY to stderr.
- **CON-2 bash + ANSI only**: live-tail uses POSIX `tail -f` exclusively. NO `inotify`, NO `fswatch`, NO Python, NO Rich/TUI. ANSI escapes only.
- **CON-3 cost-column-graceful-degradation**: pre-M019 milestones (no `dispatch_usage` records) render WITHOUT the `▽` marker AND without stderr noise. The savings probe must mirror P02's silent-suppression contract.
- **CON-4 no-github-api-on-render**: NO `gh` invocations, NO HTTP. The `--live` branch is the same in this regard as the at-rest branch from P02.
- **CON-7 / AD-8 knowledge-layer-boundary**: T01 introduces NO new JSONL event types, NO M020 schema changes, NO M027 surface changes. The new `display_thresholds:` config block is M029-owned per AD-8 write-claim.
- **#Q-G8 canonical-form invariant**: ONLY `▽ saved Nk`. NO `▽ Nk saved`. NO `▽ saved Nk via tier1 cache reuse`. The verifier asserts both presence of the canonical form AND absence of the forbidden suffix.
- **#Q-1 full-re-render**: live-tail performs a full tree re-render on every appended `dispatch_usage` record. NO incremental row-update / row-tracking state. Tree size is bounded (<50 rows) so the cost is negligible per the spec's #Q-1 recommendation.
- **Path-collision rule 6**: `tools/verify/m029-p03-render-position-live-shape.sh` and `tools/verify/m029-p03-display-thresholds-config-shape.sh` do not exist on disk at plan-authoring time (verified 2026-05-06).

## Expected Output

After T01 completes:
- `scripts/diagnostics/render-position.sh` — the `--live` branch is wired; at-rest behaviour unchanged; manual smoke run shows the marker on a synthetic ≥5% savings record.
- `templates/orchestrator-config-default.yml` — `display_thresholds:` block appended.
- `references/file-formats.md` — `display_thresholds:` documented.
- `scripts/state/read-config.sh` — `VALID_KEYS` extended.
- `tools/verify/m029-p03-render-position-live-shape.sh` — exists, executable, exits 0.
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` — exists, executable, exits 0.
- A summary file at `.orchestrator/milestones/M029/phases/P03/tasks/T01-render-position-live-and-savings-marker-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output:
```
PASS: render-position.sh exists and is executable
PASS: --live flag wired
PASS: tail -f primitive present
PASS: ▽ saved canonical form present
PASS: forbidden verbose form `via tier1 cache reuse` absent
PASS: read-config.sh threshold-knob read present
PASS: display_thresholds.compression_savings_pct token present
PASS: FR-7 / FR-8 / #Q-1 / #Q-G8 / AD-5 references present
SUMMARY: m029-p03-render-position-live-shape.sh pass=N fail=0
```

The forbidden-token negative-assertion pattern carries forward from P02/T03's render-position-shape verifier — that verifier's assertion code names `▽ saved Nk via tier1 cache reuse` as the forbidden literal while the renderer body itself never emits it. P03/T01 mirrors this discipline.

`read-config.sh`'s dotted-form key resolution treats `display_thresholds.compression_savings_pct` exactly the way it already treats `compression.efficiency_footer.enabled` — no resolver change is needed beyond extending the `VALID_KEYS` allowlist string. The 4-layer precedence (env > local > project > defaults) applies automatically.

The fall-back-to-default discipline matters because consumer projects that have not yet upgraded their `orchestrator-config.yml` (or are using a legacy default-config template) must continue to render `▽ saved Nk` markers without breaking. The fail-open default is `5.0`; the stderr `WARN:` line is advisory and does not break SC-6's "stderr is empty" invariant against pre-M019 milestones (because pre-M019 milestones have no `dispatch_usage` records to evaluate the threshold against — the marker code path never fires for them).
