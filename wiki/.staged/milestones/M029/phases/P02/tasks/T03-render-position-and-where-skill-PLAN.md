---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M029"
name: "render-position.sh + commands/where.md (FR-5, FR-6, CON-3, CON-4)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has landed: `references/cross-milestone-feature-shape.md` is on disk; verify `[ -f references/cross-milestone-feature-shape.md ]`. T03 reads it as the AD-6 schema authority.
- T02 has landed: `scripts/diagnostics/summarize-milestone.sh` is on disk and executable; verify `[ -x scripts/diagnostics/summarize-milestone.sh ]`. T03 invokes it for inactive-milestone summary lines.
- P01 deliverables on disk and verified: `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve resolver — `[ -x scripts/state/detect-invocation-context.sh ]`), `references/status-headline-shape.md`, `references/status-json-schema.md`.
- [M027](../../../../../milestones/M027/index.md) surfaces on disk (closed milestone, read-only consumers): `scripts/diagnostics/metrics-rollup.sh`, `scripts/diagnostics/efficiency-footer.sh`. Verify `[ -x scripts/diagnostics/metrics-rollup.sh ]`.
- [M019](../../../../../milestones/M019/index.md) JSONL schema on disk: `.orchestrator/milestones/M*/execution-log.jsonl` paths exist for closed milestones (read-only consumer).
- `scripts/state/read-roadmap.sh` and `scripts/state/find-active-milestone.sh` exist and are executable.
- No file currently lives at `scripts/diagnostics/render-position.sh` or `commands/where.md` (path-collision rule 6 already checked at plan-authoring time — clean).

## Description

T03 ships **two coupled deliverables** that together satisfy FR-5 (where renderer), FR-6 (cost-column graceful degradation), CON-3 (silent suppression), CON-4 (no GitHub API on render), CON-1/FR-14 (read-only):

1. **`scripts/diagnostics/render-position.sh`** — the at-rest tree renderer. Reads:
   - The AD-1 resolver's env block (`renderer`, `exit_code_scheme`, `default_provider`).
   - The active feature spec frontmatter (`milestone:` singular OR `milestones:` plural per AD-6).
   - Each milestone's `M###-ROADMAP.md` for phase ordering.
   - Each phase's `P##-PLAN.md` / `P##-SUMMARY.md` / `tasks/T##-*-{PLAN,SUMMARY}.md` for state derivation.
   - `metrics-rollup.sh --granularity task` for the per-row cost column on M019-Tier-1-equipped milestones.
   - `summarize-milestone.sh --format=keys` for collapsed inactive-milestone summary lines.
   - `scripts/lifecycle/lock-manager.sh` (read-only probe) for lock state if relevant to the headline.
   - The reverse-lookup advisory (T01 contract): enumerate `.orchestrator/milestones/M*/M*-EVALUATION.md`, group by `feature_ref:`, emit `WARN:` on mismatch, render-from-spec.

   Emits a tree to stdout using the canonical glyph alphabet from `references/cross-milestone-feature-shape.md`:
   - `✓` complete, `▶` executing, `◇` pending, `✗` failed, `▽` saved-Nk (P03 live-only; T03 never emits this glyph itself).

   Renderer flags:
   - `--milestone <M###>` (active-only view; default behavior is the FULL feature view per FR-13).
   - `--expand-all` (#Q-5: expand inactive milestones).
   - `--feature <slug>` (override the active feature; used by SC-5 fixture to point at a known feature).
   - `--no-cost` (operator-side cost-column suppression; FR-6's pre-M019 detection is automatic and silent).
   - `--root <path>` (override `.orchestrator/` root for fixturing; required by SC-5 / SC-6 / SC-14 fixtures).
   - `--help` / `-h`.

2. **`commands/where.md`** — the canonical 8-section command-doc shape mirrored from P01's `commands/context.md`. The command document is an LLM-instruction skill (per T05/P01 pattern); production rendering is performed by an agent reading the skill, but the skill instructs the agent to invoke `render-position.sh` and pass its output through unchanged. The skill must:
   - Reference `scripts/diagnostics/render-position.sh` in the Referenced Scripts section.
   - Reference `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve discipline).
   - Reference `references/cross-milestone-feature-shape.md` (AD-6 contract).
   - Embed the canonical glyph legend.
   - Declare the read-only contract (CON-1 / FR-14): no writes to `.orchestrator/`.
   - Declare CON-4 (no GitHub API): the skill MUST NOT invoke `gh` or any GitHub HTTP API; the [M013](../../../../../milestones/M013/index.md) sidecar at `.orchestrator/integrations/github.json` is NOT read in v1.

## Steps

1. **Create `scripts/diagnostics/render-position.sh`** (≥120 lines, executable, bash 3.2 compatible per MEM001).

   - Header: re-source guard, `_RP_SCRIPT_DIR`, `_RP_PROJECT_ROOT`, the standard read-only declaration, AD-1/AD-6/AD-19/CON-1/CON-3/CON-4 cross-references in the comment block.
   - Argument parser: handles `--milestone`, `--expand-all`, `--feature`, `--no-cost`, `--root`, `-h`/`--help`, default error on unknown flag with exit 2.
   - Resolve invocation context via `bash "$_RP_PROJECT_ROOT/scripts/state/detect-invocation-context.sh" --format=plain` (AD-1 single-resolve; capture stdout into a temp file under `${TMPDIR:-/tmp}/m029-rp.$$/` to avoid `$(…)` pipe). Read the four lines back via `grep -E '^renderer=' "$tmp"`.
   - Resolve the feature: if `--feature` is set, use that slug; otherwise glob `specs/*/spec.md` and pick the spec whose frontmatter `milestone:` or `milestones:` includes the active milestone (from `find-active-milestone.sh`).
   - Parse the spec frontmatter to extract milestone list (singular `milestone:` → `[M###]`; plural `milestones: [M###, M###]` → list).
   - For each milestone in the list:
     - Read `M###-ROADMAP.md` for milestone name + phase IDs.
     - For each phase ID: state-derive via P##-SUMMARY.md exists (✓), tasks dir but no SUMMARY (▶), no plan (◇), last-verify=fail in execution-log.jsonl (✗).
     - For the in-flight phase: enumerate tasks from `tasks/T##-*-PLAN.md` and emit each task's status glyph.
     - Per-row cost column: invoke `metrics-rollup.sh --granularity task --milestone M### --phase P## --task T##` ONLY when the milestone has M019 Tier 1 records (detect via `[ -s execution-log.jsonl ]` + a single `grep -m1 -F '"record_type":"dispatch_usage"'` probe). On detection-miss, OMIT the cost column entirely — no blank column, no stderr warning (FR-6 / CON-3).
   - Active milestone is always expanded; inactive milestones default to collapsed (one summary line via `summarize-milestone.sh`); `--expand-all` expands every milestone.
   - Render the milestone progress bar using `▓░` + percentage (`▓░ 33% (1/3 phases)`).
   - Reverse-lookup advisory: enumerate `.orchestrator/milestones/M*/M*-EVALUATION.md`, group by `feature_ref:` (read frontmatter), compare to spec's declaration, emit `WARN: feature <slug> spec frontmatter declares <set>; reverse-lookup discovered <set>; using spec` to stderr on mismatch. Continue rendering from the spec's declaration.
   - Read-only invariant: NO writes to `.orchestrator/`. The only writes the script may perform are to `${TMPDIR:-/tmp}/m029-rp.$$/` (per `run-probe.sh` scope rule 4 — `/tmp/` is the staged probe domain). Clean up the temp directory on EXIT via `trap`.

   Reference structural shape (NOT a literal full implementation; the executor authors the implementation following this skeleton):

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/render-position.sh -- M029 / FR-5 at-rest tree renderer.
   #
   # Reads (no writes): feature spec frontmatter, M###-ROADMAP.md, P##-PLAN/SUMMARY.md,
   # T##-*-PLAN/SUMMARY.md, execution-log.jsonl (only for FR-6 detection probe),
   # metrics-rollup.sh (--granularity task), summarize-milestone.sh.
   #
   # Glyph alphabet: ✓ (complete) ▶ (executing) ◇ (pending) ✗ (failed); ▽ savings
   # is P03 live-only and NEVER emitted by this at-rest renderer.
   #
   # Read-only (CON-1 / FR-14). Bash 3.2 (MEM001). No GitHub API (CON-4 / FR-11).
   # AD-1 single-resolve via detect-invocation-context.sh. AD-6 cross-milestone
   # data model per references/cross-milestone-feature-shape.md.
   #
   # See M029 spec FR-5/FR-6/FR-13/CON-1/CON-3/CON-4 and M029-CONTEXT AD-1/AD-6.

   set -u
   if [ -n "${_RENDER_POSITION_SH_SOURCED:-}" ]; then return 0 2>/dev/null || exit 0; fi
   _RENDER_POSITION_SH_SOURCED=1

   _RP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _RP_PROJECT_ROOT="$(cd "$_RP_SCRIPT_DIR/../.." && pwd)"

   # ... argument parser, helpers, render loop ...

   exit 0
   ```

2. **`chmod +x scripts/diagnostics/render-position.sh`**.

3. **Create `commands/where.md`** (≥60 lines). Required sections (mirrors `commands/context.md` 8-section shape):

   ```markdown
   ---
   description: "Use when a developer wants to see the full work hierarchy at a glance — feature → milestone → phases → tasks → current dispatch — with per-row cost columns and progress bars. Renders read-only from on-disk state."
   ---

   # orchestrator:where

   Read-only tree renderer for the work hierarchy. Composes existing M013/M018/M019/M027 surfaces into a glanceable view; never mutates state; never invokes GitHub APIs.

   ## Prerequisites / State Check

   - The active milestone resolves via `scripts/state/find-active-milestone.sh` (returns NONE if no milestone is active; the renderer prints a one-line "no active milestone" notice).
   - Invocation context is single-resolved via `scripts/state/detect-invocation-context.sh` (AD-1).

   ## Core Workflow

   1. Resolve invocation context.
   2. Invoke `scripts/diagnostics/render-position.sh` with the operator's flags forwarded unchanged.
   3. Print the renderer's stdout verbatim.
   4. On non-zero exit, surface the renderer's stderr unchanged.

   ## Glyph Legend

   - `✓` — phase or task complete.
   - `▶` — phase or task currently executing.
   - `◇` — phase or task pending (not yet started).
   - `✗` — phase or task failed (last verify result was `fail`).
   - `▽` — savings marker (P03 `--live` mode only; the canonical compact form is `▽ saved Nk`).

   ## Flags

   - `--milestone <M###>`: render only the named milestone (active-only view).
   - `--expand-all`: expand every milestone's full phase tree (default: inactive milestones are collapsed).
   - `--feature <slug>`: override the active feature; used for testing.
   - `--no-cost`: suppress the per-row cost column.
   - `--root <path>`: override the `.orchestrator/` root (fixturing).

   ## Output

   Tree on stdout. Reads-only; never writes to `.orchestrator/`. ANSI color when TTY=true; auto-stripped when piped or under CI per the AD-1 resolver.

   ## Idempotency

   `where` is read-only and produces identical output for identical disk state.

   ## Error Handling

   - No active milestone → one-line notice; exit 0.
   - Spec frontmatter missing both `milestone:` and `milestones:` → "feature <slug> declares no milestone; nothing to render"; exit 0.
   - Reverse-lookup mismatch → `WARN:` on stderr; render proceeds from spec's declaration.

   ## Constraints

   - **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. The only allowed write site is `${TMPDIR:-/tmp}/m029-rp.$$/` for transient resolver capture.
   - **No GitHub API (CON-4 / FR-11)**: the renderer MUST NOT invoke `gh` or any GitHub HTTP API; the M013 sidecar at `.orchestrator/integrations/github.json` is NOT read in v1. Enforced by SC-13's anti-coupling guard.

   ## Referenced Scripts

   - `scripts/diagnostics/render-position.sh` — the renderer engine.
   - `scripts/state/detect-invocation-context.sh` — AD-1 single-resolve resolver.
   - `scripts/state/find-active-milestone.sh` — active-milestone resolver.
   - `scripts/diagnostics/summarize-milestone.sh` — collapsed inactive-milestone summary helper.
   - `scripts/diagnostics/metrics-rollup.sh` — per-row cost column source (M027, read-only).

   ## Reference Files

   - `references/cross-milestone-feature-shape.md` — AD-6 cross-milestone schema contract.
   - `references/status-headline-shape.md` — sibling P01 contract; `where`'s tree reuses the headline field vocabulary in its top-of-tree summary line.
   - [`.orchestrator/milestones/M029/M029-CONTEXT.md`](../../../../../milestones/M029/M029-CONTEXT.md) — AD-1 / AD-6 / AD-9 authorities.
   ```

4. **Author `tools/verify/m029-p02-render-position-shape.sh`** (≥35 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -f scripts/diagnostics/render-position.sh ]` and `[ -x scripts/diagnostics/render-position.sh ]`.
   - Asserts (via `grep -F` per assertion, parallel indexed arrays for pass/fail tracking) the script declares the four glyphs literally: `✓`, `▶`, `◇`, `✗`. Asserts `▽` is referenced (in a comment naming P03's live-mode use).
   - Asserts the AD-19 forbidden shape `via tier1 cache reuse` does NOT appear (no v1 verbose form).
   - Asserts the read-only contract token (`Read-only` or `CON-1` or `FR-14`) appears in the header.
   - Asserts the CON-4 / FR-11 anti-coupling token (`No GitHub API` or `CON-4` or `FR-11`) appears in the header.
   - Asserts the script does NOT contain the literal substring `/integrations/github` (anti-coupling enforcement; complements SC-13).
   - Asserts the script invokes `detect-invocation-context.sh` (AD-1).
   - Asserts the script invokes `metrics-rollup.sh` (M027 cost column source) AND that the FR-6 detection probe pattern is present (grep for `dispatch_usage` literal).
   - Asserts the bash 3.2 compatibility token (`Bash 3.2` or `MEM001`) appears.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-render-position-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p02-where-skill-shape.sh`** (≥30 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -f commands/where.md ]`.
   - Asserts every required H2 section exists (`## Prerequisites`, `## Core Workflow`, `## Glyph Legend`, `## Flags`, `## Output`, `## Idempotency`, `## Error Handling`, `## Constraints`, `## Referenced Scripts`, `## Reference Files`).
   - Asserts the canonical glyphs each appear literally: `✓`, `▶`, `◇`, `✗`, `▽`.
   - Asserts `scripts/diagnostics/render-position.sh` is referenced.
   - Asserts `scripts/state/detect-invocation-context.sh` is referenced (AD-1 single-resolve).
   - Asserts `references/cross-milestone-feature-shape.md` is referenced.
   - Asserts the read-only contract token appears.
   - Asserts the CON-4 token appears.
   - Asserts the literal substring `/integrations/github` does NOT appear in `commands/where.md` (anti-coupling enforcement).
   - Asserts the canonical compact form `▽ saved Nk` appears AND the verbose form `via tier1 cache reuse` does NOT appear (#Q-G8).
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-where-skill-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

6. **`chmod +x` both verifiers**.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 resolver, emits the canonical glyph set, suppresses cost column silently on pre-M019 milestones, and never invokes GitHub APIs.
- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline, references `render-position.sh` + `detect-invocation-context.sh` + `cross-milestone-feature-shape.md`, and embeds the glyph legend.

This task creates these P02 phase artifacts:
- Tree renderer engine at `scripts/diagnostics/render-position.sh` — FR-5 / FR-6 / CON-1 / CON-3 / CON-4 implementation.
- `orchestrator:where` skill doc at `commands/where.md` — LLM-instruction skill that invokes the renderer.
- Renderer shape verifier at `tools/verify/m029-p02-render-position-shape.sh` — mechanical glyph + read-only + anti-coupling enforcement.
- Skill shape verifier at `tools/verify/m029-p02-where-skill-shape.sh` — mechanical 8-section + reference + glyph enforcement.

## Verification

```bash
bash tools/verify/m029-p02-render-position-shape.sh
```

```bash
bash tools/verify/m029-p02-where-skill-shape.sh
```

## Inputs

### From Previous Tasks

- `references/cross-milestone-feature-shape.md` (from T01)
  - Key API: documents the AD-6 schema (`milestone:` singular vs `milestones:` plural), reverse-lookup advisory, inactive-render shape, glyph alphabet.
  - Key types: feature-spec frontmatter shape; T03 parses these per the contract.
- `scripts/diagnostics/summarize-milestone.sh` (from T02)
  - Key API: `bash scripts/diagnostics/summarize-milestone.sh --milestone <M###> --format=keys` emits four lines: `phase_count=`, `phases_complete=`, `tasks_remaining=`, `intensity=`.
  - Key types: fixed-order key=value block on stdout; exit 0 on success, 2 on usage error.

### From Disk (Pre-existing)

- `scripts/state/detect-invocation-context.sh` (P01) — AD-1 single-resolve resolver. T03 invokes via `bash <path>` and reads stdout-captured-to-tempfile (no `$(…)` pipe).
- `scripts/state/find-active-milestone.sh` — active-milestone resolver. T03 invokes for default-milestone resolution.
- `scripts/state/read-roadmap.sh` — roadmap parser. T03 invokes for phase-list extraction.
- `scripts/diagnostics/metrics-rollup.sh` (M027) — per-row cost column source. T03 invokes with `--granularity task --milestone M### --phase P## --task T##`. Read-only.
- `scripts/diagnostics/efficiency-footer.sh` (M027) — comment-header style precedent for read-only diagnostic helpers.
- `references/status-headline-shape.md` (P01) — vocabulary precedent for top-of-tree summary line.
- `commands/context.md` (P01) — 8-section command-doc shape precedent.
- `commands/status.md` (P01) — sibling skill that the operator hits at session resume; `commands/where.md` is the tree-view counterpart.

## Constraints

- **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. Allowed write site: `${TMPDIR:-/tmp}/m029-rp.$$/` for transient capture.
- **No GitHub API (CON-4 / FR-11)**: NO `gh` invocations, NO HTTP calls, NO read of `.orchestrator/integrations/github.json`. SC-13 enforces this with `grep -r '/integrations/github'` against `render-position.sh`.
- **Bash 3.2 (MEM001)**: no `declare -A`, no process substitution, no `<<<`, no `$(cmd | …)` in public surface (awk/sed pipes inside script body are permitted per MEM004 carve-out).
- **AD-19 verifier shape**: gate verifiers MUST be straight-line bash. NO inline compound chains, NO plain subshells, NO `$(cmd | grep …)`, NO process substitution.
- **AD-1 single-resolve discipline (Principle XI)**: T03 MUST NOT re-derive TTY/CI/runtime detection; it reads from `detect-invocation-context.sh` exclusively.
- **CON-7 + AD-8 knowledge-layer boundary**: T03 introduces NO new schema additions to M013 sidecar, M019 JSONL, [M020](../../../../../milestones/M020/index.md) KNOWLEDGE.md, or M027 surfaces. Reads M027 / M019 surfaces only; never modifies.
- **No M027 modification**: `render-position.sh` MUST NOT modify `metrics-rollup.sh`, `efficiency-footer.sh`, or `predictive-surface.sh`. These are read-only consumers.
- **Glyph alphabet (#Q-G8)**: the canonical compact savings form is `▽ saved Nk`; the verbose form `via tier1 cache reuse` MUST NOT appear in T03 deliverables. The `▽` glyph itself is P03 live-only; T03 must reference it (in comments / glyph legend) but MUST NOT emit it from the at-rest renderer.

## Expected Output

After T03 completes:
- `scripts/diagnostics/render-position.sh` exists, is executable, and runs without error against the active M029 milestone (a smoke-test invocation `bash scripts/diagnostics/render-position.sh --milestone M029 > /tmp/where-smoke.$$` should exit 0; full SC-5 acceptance lands in T04 against the dedicated mixed-state fixture).
- `commands/where.md` exists with all 8 required sections.
- `tools/verify/m029-p02-render-position-shape.sh` exists, is executable, exits 0 from project root.
- `tools/verify/m029-p02-where-skill-shape.sh` exists, is executable, exits 0 from project root.
- A summary file at [`.orchestrator/milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md`](../../../../../milestones/M029/phases/P02/tasks/T03-render-position-and-where-skill-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
- `m029-p02-render-position-shape.sh`: `PASS:` per assertion (≈10–14), `SUMMARY: m029-p02-render-position-shape.sh pass=N fail=0`.
- `m029-p02-where-skill-shape.sh`: `PASS:` per assertion (≈12–16), `SUMMARY: m029-p02-where-skill-shape.sh pass=N fail=0`.

The phase-suite aggregator (T05) chains these as gates 3 and 4.

The full SC-5 byte-identical golden-render assertion does NOT land in T03; it lands in T04 alongside the dedicated mixed-state fixture. T03's verifiers are SHAPE checks (does the renderer reference the right surfaces; does the skill have the right sections); T04's verifiers are BEHAVIORAL (does the renderer produce the byte-identical golden output). This is intentional — T03's gates run quickly even before fixtures exist, so the shape problems surface before the more expensive behavioral assertions.

Why `where` is an LLM-instruction skill rather than a thin wrapper script: the SC-5 fixture compares the byte-stream emitted by the renderer engine (`render-position.sh`), not by an agent. The skill exists because the operator invokes `orchestrator:where` (an LLM command) which delegates to the engine; production rendering is performed by the engine, not the agent. This mirrors P01's `commands/context.md` precedent — the agent reads the skill, invokes the script, prints the output.
