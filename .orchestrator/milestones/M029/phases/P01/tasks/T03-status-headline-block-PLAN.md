---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M029"
name: "orchestrator:status headline block + SC-2 fixture/script + verifier (FR-2)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has completed: `references/status-headline-shape.md` exists and documents the field set, line packing, regex, and CON-5 suppression-matrix inheritance. Verify with `[ -f references/status-headline-shape.md ]` AND `bash tools/verify/m029-p01-headline-shape-contract.sh` exits 0.
- T02 has completed: `scripts/state/detect-invocation-context.sh` exists and emits the three-field env block. Verify with `[ -f scripts/state/detect-invocation-context.sh ]` AND `bash tools/verify/m029-p01-invocation-context-resolver-shape.sh` exits 0.
- `commands/status.md` exists in its current pre-M029 shape (≥200 lines; verify with `[ -f commands/status.md ]` and `wc -l commands/status.md` returning ≥200). T03 modifies this file additively — it does NOT create it.
- `scripts/diagnostics/efficiency-footer.sh` exists and accepts `--milestone <Mxxx>` (verify with `bash scripts/diagnostics/efficiency-footer.sh --help` exits 0; the helper's surface is documented at the top of the helper).
- `tests/m029-acceptance/` exists from T02.

## Description

T03 implements the **FR-2 status headline block** — a 3-line headline prepended to `orchestrator:status` output, embedding the M027 `efficiency-footer.sh` line verbatim per CON-5 suppression-matrix inheritance. The flat sections beneath the headline remain byte-identical to today's render so existing scrapers do not break (US-2's load-bearing promise).

T03 also ships:
- The fixture milestone tree at `tests/m029-acceptance/fixtures/status-headline-executing.fixture/` providing a milestone in `executing` state with one completed phase + one in-flight phase + a populated `execution-log.jsonl` carrying ≥1 `dispatch_usage` record (so the M027 efficiency-footer has Tier 1 data to roll up).
- The SC-2 acceptance script `tests/m029-acceptance/p01-sc2-headline.sh` that asserts the first three non-blank lines match the regex from `references/status-headline-shape.md` AND that the body below the headline is byte-identical to a "pre-M029" baseline rendering.
- Two shape verifiers (`tools/verify/m029-p01-status-headline-shape.sh` for the commands/status.md modifications; `tools/verify/m029-p01-sc2-shape.sh` for the SC-2 wrapper).

The headline rendering reads the resolver's env block at command entry (AD-1 single-resolve) — T03 does NOT re-implement TTY / CI detection. When `renderer=json` is the resolved value (i.e., `--format=json` is present), T03's headline path is SKIPPED and T04's JSON renderer takes over; the status command's flag dispatch handles the branch.

## Steps

1. **Modify `commands/status.md` additively** to prepend a `## Headline Block` section above the existing `## State Derivation` section (so the headline renders BEFORE state derivation in the status flow). Required additions:

   - A new `## Headline Block` section (immediately after the H1 + the intro paragraph, before `## State Derivation`). Required prose:

     > **FR-2 / SC-2 / Principle XI / AD-1 single-resolve.** The headline block is the first three non-blank lines of stdout. When invoked without `--format=json`, the headline renders before the existing flat sections; when invoked with `--format=json`, this block is skipped and `scripts/diagnostics/render-status-json.sh` takes over (FR-3, T04).
     >
     > **Resolution.** Read the resolver's env block at command entry: `eval "$(bash scripts/state/detect-invocation-context.sh)"`. The resolver returns three fields per AD-1 (`renderer`, `exit_code_scheme`, `default_provider`). When `renderer=json`, branch to the JSON renderer (FR-3) and skip the headline+flat-sections path entirely.
     >
     > **Field set + line packing** are documented in `references/status-headline-shape.md`. The implementation MUST emit lines matching the regex documented there byte-for-byte; SC-2 fails on any drift.
     >
     > **Embedded footer.** Under `efficiency_footer: true` (M027 default), the headline is followed by the `scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>` line verbatim. Under `efficiency_footer: false` or `--quiet`, the footer line disappears with no other side effect (CON-5 suppression-matrix inheritance from M027). M029 introduces NO new suppression knob — M027's resolution chain (env → local config → project config → defaults) governs the footer line.
     >
     > **Flat sections invariant.** Below the headline + blank line + footer line, the existing flat sections (Progress Overview, Blockers, Execution History, Telemetry Metrics, Efficiency Footer, Next Action) render byte-identical to today's pre-M029 output. The headline is additive; existing scrapers do not break.

   - Update the `## Reference Files` section at the bottom of `commands/status.md` to add five new entries:
     - `scripts/state/detect-invocation-context.sh` — AD-1 single-resolve invocation-context resolver (M029/P01)
     - `references/status-headline-shape.md` — FR-2 design contract (M029/P01)
     - `references/status-json-schema.md` — FR-3 design contract (M029/P01; consumed by T04 `--format=json` path)
     - `scripts/diagnostics/render-status-json.sh` — FR-3 JSON renderer (M029/P01; consumed by T04)
     - The existing `scripts/diagnostics/efficiency-footer.sh` entry stays.

   - **Do NOT modify** the existing `## State Derivation`, `## Progress Overview`, `## Blockers`, `## Execution History`, `## Telemetry Metrics`, `## Efficiency Footer`, `## Next Action`, `## Concurrent Safety`, `## Idempotency`, `## Error Handling`, or `## Gotchas` sections except for the additive `## Reference Files` update above. The flat-section invariant requires byte-identical content below the headline.

2. **Create the SC-2 fixture milestone tree** at `tests/m029-acceptance/fixtures/status-headline-executing.fixture/`:

   - `M999-ROADMAP.md` — a minimal roadmap with two phases: `P01` (completed) and `P02` (in-flight). Frontmatter: `milestone: "M999"`, `feature_ref: "999-m029-p01-status-fixture"`, `tier: "C"`. Body: a `## Phases` section listing `P01` (with `[x]` checkmark since it has a summary) and `P02` (with `[ ]`). Minimum 30 lines.
   - `phases/P01/P01-SUMMARY.md` — minimal summary marking P01 complete. Frontmatter: `phase: "P01"`, `milestone: "M999"`, `status: complete`. Body: 1–2 lines. Minimum 10 lines (including frontmatter).
   - `execution-log.jsonl` — at least 3 records: one `dispatch_open` for P01/T01, one `dispatch_close` for P01/T01 (with `outcome: success`, `duration_seconds: 42`), and one `dispatch_usage` carrying valid M019 Tier 1 fields (`milestone_id: "M999"`, `phase_id: "P01"`, `task_id: "T01"`, `model: "claude-opus-4-7"`, `input_tokens: 1000`, `output_tokens: 500`, `cache_read_tokens: 200`, `cache_creation_tokens: 0`, `cost_usd: 0.018`, `timestamp: "2026-05-05T20:00:00Z"`). The schema must match the existing M019 emitter's output shape — read `scripts/diagnostics/efficiency-footer.sh` and the M019 emitter helpers (`scripts/dispatch/emit-dispatch-usage.sh` or equivalent — find via `grep -rl 'dispatch_usage' scripts/`) to get the exact field set and copy it verbatim.
   - The roadmap file is at the fixture root (NOT at `<fixture-root>/.orchestrator/milestones/M999/`) because the SC-2 script invokes status with `--orchestrator-root <fixture-root>` style flags — the fixture mimics the orchestrator state shape needed by `derive-phase.sh`. Confirm by reading `scripts/state/derive-phase.sh` and `scripts/state/read-roadmap.sh` to determine the exact directory layout the existing scripts probe; mirror that layout.

3. **Author `tests/m029-acceptance/p01-sc2-headline.sh`** (≥70 lines, executable). The script:

   - Sets `set -u` and traps cleanup on exit.
   - Creates a working temp directory via `mktemp -d`. Copies the SC-2 fixture into the temp dir using `cp -r tests/m029-acceptance/fixtures/status-headline-executing.fixture <tmpdir>/orch-root` so writes during status invocation (if any sneak in) don't pollute the source fixture.
   - Captures a "pre-M029 baseline" rendering by invoking the existing status flow path WITHOUT the headline block (use a feature flag env var the implementation reads — `M029_DISABLE_HEADLINE=1` — that the executor wires into the headline-render guard). Captures stdout to `<tmpdir>/baseline.out`.
   - Runs `orchestrator:status` against the fixture (with the feature flag absent so the headline renders) and captures stdout to `<tmpdir>/with-headline.out`.
   - Asserts the first three non-blank lines of `with-headline.out` match the regex documented in `references/status-headline-shape.md` (Line 1: `^M[0-9]{3} .+$`; Line 2: `^phase [0-9]+/[0-9]+ \(P[0-9]{2}, [0-9]+%\)  \|  lock: (free|held by PID [0-9]+ since .+)$`; Line 3: `^last_dispatch: ([0-9]+[smhd] ago|none)  \|  last_verify: (pass|fail|none)$`).
   - Asserts the line immediately following the three-line headline (after one blank line) starts with `Efficiency (Tier 1 rollup)` (the M027 footer prefix).
   - Diffs `with-headline.out` (skipping the first 5 lines: 3 headline + 1 blank + 1 efficiency footer line — actually the efficiency footer is multi-line, so skip until the first `## ` markdown header) against `baseline.out`. The diff MUST be empty (byte-identical flat-section invariant). Implementation hint: use `tail -n +<N>` where N is the line count of (headline + blank + efficiency-footer-block + blank).
   - Re-runs the status flow with `efficiency_footer: false` set in the fixture's config (write a temporary `.orchestrator/config.yml` carrying `efficiency_footer: false` in the temp orch-root). Asserts the headline block is still present (3 non-blank lines matching the regex) but the `Efficiency (Tier 1 rollup)` line is absent.
   - Cleanup: `rm -rf <tmpdir>` on exit.
   - Tracks pass/fail counters; emits `PASS:` / `FAIL:` lines + final `SC-2: pass=N fail=M`. Exits 0 iff `fail=0`.

4. **Author `tools/verify/m029-p01-status-headline-shape.sh`** (≥30 lines, executable). The verifier:

   - Gates on file existence: `[ -f commands/status.md ]`. FAIL if missing.
   - Asserts `commands/status.md` contains the literal string `## Headline Block`.
   - Asserts `commands/status.md` contains `FR-2`.
   - Asserts `commands/status.md` contains `scripts/state/detect-invocation-context.sh` (the resolver reference in the headline block).
   - Asserts `commands/status.md` contains `scripts/diagnostics/efficiency-footer.sh` (the embedded footer reference).
   - Asserts `commands/status.md` contains `references/status-headline-shape.md` (the design contract reference).
   - Asserts `commands/status.md` contains `CON-5` (suppression-matrix inheritance reference).
   - Asserts the `## Reference Files` section names all five required entries (resolver, headline shape, JSON schema, JSON renderer, efficiency footer).
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-status-headline-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p01-sc2-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on file existence: `[ -f tests/m029-acceptance/p01-sc2-headline.sh ]` AND `[ -d tests/m029-acceptance/fixtures/status-headline-executing.fixture ]`.
   - Asserts the SC-2 script is executable.
   - Asserts the SC-2 script's header references SC-2 AND FR-2.
   - Asserts the fixture milestone has `M999-ROADMAP.md`, `phases/P01/P01-SUMMARY.md`, and `execution-log.jsonl`.
   - Asserts the fixture's `execution-log.jsonl` contains at least one `dispatch_usage` record (greps for `"dispatch_usage"`).
   - Runs `bash tests/m029-acceptance/p01-sc2-headline.sh` and asserts exit 0.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-sc2-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

6. **Run all verifiers + the SC-2 script** to confirm green: `bash tools/verify/m029-p01-status-headline-shape.sh`, `bash tests/m029-acceptance/p01-sc2-headline.sh`, `bash tools/verify/m029-p01-sc2-shape.sh`.

## Must-Haves

This task addresses these P01 phase truths:
- `commands/status.md` carries the headline block (FR-2) prepended above the flat sections.
- The flat sections below the headline are byte-identical to the pre-M029 rendering.
- The CON-5 suppression-matrix inheritance from M027 is honored — `efficiency_footer: false` makes the footer line disappear without affecting the headline.
- The SC-2 acceptance script exits 0.

This task creates these P01 phase artifacts:
- `commands/status.md` — modified with the FR-2 headline block + Reference Files updates.
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/` — fixture milestone tree.
- `tests/m029-acceptance/p01-sc2-headline.sh` — SC-2 acceptance script.
- `tools/verify/m029-p01-status-headline-shape.sh` — commands/status.md shape verifier.
- `tools/verify/m029-p01-sc2-shape.sh` — SC-2 wrapper verifier.

## Verification

```bash
bash tools/verify/m029-p01-status-headline-shape.sh
```

```bash
bash tools/verify/m029-p01-sc2-shape.sh
```

## Inputs

### From Previous Tasks

- `references/status-headline-shape.md` (from T01) — the FR-2 design contract. T03 reads this for: field set, line packing, regex, embedded-footer rule, CON-5 suppression-matrix inheritance. The headline implementation in `commands/status.md` MUST emit lines matching the regex byte-for-byte.
  - Key API: documented field order (5 fields packed into 3 lines), regex (POSIX extended; matches first 3 non-blank lines), CON-5 suppression rule (efficiency_footer knob gates the footer line, no other field).
- `references/status-json-schema.md` (from T01) — informational; T03 names this as a Reference File so the round-trip cross-reference is auditable.
- `scripts/state/detect-invocation-context.sh` (from T02) — the AD-1 single-resolve resolver. T03's headline path reads the resolver's env block at command entry and branches on `renderer=json` (skip headline path; let T04's JSON renderer take over).
  - Key API: `bash scripts/state/detect-invocation-context.sh` emits three lines `renderer=<value>`, `exit_code_scheme=<value>`, `default_provider=<value>` to stdout; exit 0. Eval'able as `eval "$(bash scripts/state/detect-invocation-context.sh)"`.
  - Key types: `renderer ∈ {tui, json, plain}`; `exit_code_scheme ∈ {interactive, governance}`; `default_provider` is a free-form string.

### From Disk (Pre-existing)

- `commands/status.md` (current pre-M029 shape, ≥200 lines) — T03 modifies additively. The existing `## Reference Files` section at the bottom is updated; the existing flat sections are NOT modified.
- `scripts/diagnostics/efficiency-footer.sh` — the M027 helper the headline embeds. Read its `--help` output for the surface contract. Headline rendering invokes `bash scripts/diagnostics/efficiency-footer.sh --milestone <id>` verbatim under `efficiency_footer: true`.
- `scripts/state/find-active-milestone.sh` — used by the headline rendering to identify the active milestone for the M027 footer call. Existing surface; bash-callable.
- `scripts/state/derive-phase.sh` — used by the headline rendering to compute phase index + percent complete. Existing surface.
- `scripts/state/read-roadmap.sh` — used by the headline rendering to count phases.
- The lock-manager state at `.orchestrator/global/lock.json` (existing read; provides the `lock:` field for line 2 of the headline). NOTE: the lock-manager state file path may differ — check `commands/status.md`'s current `### Stale Lock File` section for the canonical lock-file lookup pattern and reuse it.
- The most recent `P##-VERIFICATION.md` in the active phase (existing read; provides the `last_verify:` field for line 3). The existing `### Failed Verification` section in `commands/status.md` documents the lookup; reuse it.

## Constraints

- The flat-section invariant is load-bearing: every byte below the headline + footer + blank line MUST be byte-identical to pre-M029 output. Existing CI scrapers test against the flat sections; any drift breaks the SC-2 baseline-diff assertion AND breaks downstream consumers.
- AD-1 single-resolve: T03's headline implementation MUST consume `scripts/state/detect-invocation-context.sh`'s emitted env block. T03 MUST NOT re-implement TTY / CI / `--format=json` detection.
- CON-5 suppression-matrix inheritance: M029 introduces NO new suppression knobs in P01. The headline embeds M027's footer line, which honors M027's `efficiency_footer` knob (resolution chain: env `ORCH_EFFICIENCY_FOOTER` → local config → project config → defaults; default `true`). Disabling the footer disappears the footer line ONLY; the headline's three lines remain.
- The `M029_DISABLE_HEADLINE=1` env var is a TEST-ONLY hook used by the SC-2 baseline capture path. It must be documented as a test-only seam in the headline rendering's source comment, NOT advertised to end users. Production callers do not set this var.
- Read-only (CON-1 / FR-14): the headline rendering is read-only. No writes to `.orchestrator/`, no log emission. The SC-14 sentinel-file mechanism (P02 deliverable) will eventually verify this; T06 ships the P01 precursor `m029-p01-readonly-invariant.sh`.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T03 modifies only `commands/status.md` (additive headline block + reference files); creates only fixture + acceptance + verifier files. NO modification to M013 sidecar, M019 JSONL emitter, M020 KNOWLEDGE.md, or M027 surfaces.

## Expected Output

After T03 completes:
- `commands/status.md` carries the new `## Headline Block` section + updated `## Reference Files`.
- The SC-2 fixture milestone tree exists with valid roadmap, phase summary, and execution log.
- `tests/m029-acceptance/p01-sc2-headline.sh` exists, is executable, and exits 0 with `SC-2: pass=N fail=0`.
- Both shape verifiers (`m029-p01-status-headline-shape.sh`, `m029-p01-sc2-shape.sh`) exist, are executable, and exit 0.
- A summary file at `.orchestrator/milestones/M029/phases/P01/tasks/T03-status-headline-block-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output for the headline shape verifier: `PASS:` lines for each of ~8 assertions, ending with `SUMMARY: m029-p01-status-headline-shape.sh pass=8 fail=0`. Expected SC-2 acceptance output: per-assertion `PASS:` lines for the regex matches + flat-section diff + suppression test, ending with `SC-2: pass=N fail=0`.

The flat-section byte-identity diff is the load-bearing assertion. If the headline implementation accidentally emits an extra blank line, alters the existing `## Progress Overview` rendering, or shifts ANSI behavior on the footer-suppressed path, the diff fails. Treat the diff as the canonical regression test for the "existing scrapers do not break" promise from US-2.
