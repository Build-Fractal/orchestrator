---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M027"
goal: "Ship the two operator-facing M027 dispatch-time surfaces — (a) an efficiency footer attached to `orchestrator:status` (US-3, FR-6/FR-7) backed by a `scripts/diagnostics/efficiency-footer.sh` helper that re-uses the P00 rollup engine; (b) a dispatch-time predictive confirmation surface attached to interactive `orchestrator:dispatch` at intensity Standard or Full (US-5 remainder, FR-23) backed by a `scripts/dispatch/predictive-surface.sh` helper that re-uses the P01 cost-annotation hook (`intensity-recommend.sh --format text` + `_CE_RECOMMENDED` slot + `INTENSITY_RECOMMEND_FAST_PATH=1` short-circuit). Both surfaces are default-on for interactive use and load-bearing-ly suppressed by `--quiet`/`config.efficiency_footer: false` for the footer, and `--yes`/`orchestrator:auto`/`config.predictive_cost_surface: false`/`--no-predict` for the predictive surface. Suppressed-mode output is byte-identical to pre-M027 (CON-3, SC-3, SC-17). Operator-override (CON-10) preserved on the dispatch-time surface. Ship a P02 verifier suite mirroring P01/T04 shape that gates byte-identity, suppression matrix, helper-script latency (CON-9 inherited), Goodhart pairing on the dispatch-time surface (CON-4 carry-forward), zero-LLM-token (FR-21 carry-forward), bash 3.2 (CON-7), and read-only invariant (FR-12)."
demo_sentence: "A developer (1) runs `orchestrator:status` against this repo and the existing state/progress block is byte-identical to pre-M027 output, immediately followed by an `Efficiency (Tier 1 rollup)` footer block (≤ 6 lines) summarizing milestone-to-date cost + paired quality metrics; (2) runs `orchestrator:status --quiet` and the output is byte-identical to pre-M027 — the footer is fully suppressed and `diff` against the captured pre-M027 baseline exits 0; (3) sets `efficiency_footer: false` in `.orchestrator/config.yml` and runs `orchestrator:status` (no flag) — same byte-identity hold; (4) runs `bash scripts/dispatch/predictive-surface.sh --description \"<sample task>\" --intensity standard` (the helper invoked by interactive dispatch) and stdout shows a one-block predictive view (recommended tier highlighted, per-tier cost+quality table, override prompt), completing in < 100 ms; (5) the same helper invoked under `--yes`, under `ORCHESTRATOR_AUTO=1`, with `--no-predict`, or with `config.predictive_cost_surface: false` emits zero output to stdout (suppressed-mode contract), exit 0; (6) interactive `orchestrator:dispatch` at Standard/Full intensity surfaces the predictive view; under `--yes` / `--auto` the dispatch output is byte-identical to pre-M027; (7) `bash scripts/verify/m027-p02-suite.sh` exits 0 (all P02 contract gates green); (8) `git diff --quiet` after every above invocation is exit 0 (FR-12 carry-forward)."
risk: "medium"
depends_on: ["P01"]
---

## Resolved Open Questions (planning-pinned)

- **#Q-16 (repeat-dispatch throttling)** — **closed in this plan; default = always-on with `--no-predict` operator-override flag.** Rationale: the AD-4 strategic positioning ("be very clear to users about our recommendation and the estimated cost, and give them the ability to run cheaper when they see fit") is a visibility-first frame; throttling adds hidden state that disagrees with the user-visible config and undermines the dogfood goal. The `--no-predict` flag (and the existing `--yes` / `orchestrator:auto` / `config.predictive_cost_surface: false` paths) give operators a discoverable opt-out without inventing a session-cache. The verifier `m027-p02-no-predict-flag.sh` enforces the contract — when `--no-predict` is passed, the predictive surface emits zero stdout and the dispatch output is byte-identical to suppressed-mode.

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Per the M027/P00 + M027/P01 parser-shape lesson: every Check command
     references ONLY artifacts T01..T04 of THIS phase produces, never future
     tasks. All P02 verification logic lives in scripts/verify/m027-p02-*.sh
     files shipped in T04. The Truths-list `Check:` commands here are
     phase-boundary checks (run after T04 lands); each task plan defines its
     OWN single-script-file Verification block referencing only that task's
     artifacts. -->

### Truths

- `scripts/diagnostics/efficiency-footer.sh` exists, is executable, sourceable, and accepts `--milestone <Mxxx>`, `--project`, `--quiet`, `--config-defaults <path>`, `--help` flags. CLI mode (no `--quiet`) emits a one-block efficiency footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`; under `--quiet`, emits exactly zero stdout, exit 0. The block contains paired cost (USD) + quality (verification_pass_rate, dispatch count) tokens on adjacent lines. Reads via `scripts/diagnostics/metrics-rollup.sh` (sourced or forked); never writes to `execution-log.jsonl` (FR-12 carry-forward). Empty-log path emits `Efficiency: no Tier 1 records yet` per US-3 AS-3 (FR-6, FR-7, US-3 AS-1, AS-3, CON-5 carry-forward).
  - Check: `bash scripts/verify/m027-p02-efficiency-footer-shape.sh`

- `commands/status.md` is updated to invoke the efficiency footer below the existing telemetry block (after the `## Telemetry Metrics` section and before `## Next Action`); the footer is governed by `--quiet` and by `config.efficiency_footer` (default `true`). Pre-footer output remains structurally unchanged from the pre-M027 command document — no re-ordering of existing sections, no rewording of existing prose. Documents `--quiet` suppression and the config knob explicitly. References `scripts/diagnostics/efficiency-footer.sh` in the `## Reference Files` section (FR-6, FR-7, US-3 AS-1, AS-2, MEM012).
  - Check: `bash scripts/verify/m027-p02-status-md-shape.sh`

- Status byte-identity (suppressed mode) — `orchestrator:status --quiet` emits a tail (`tail -n +1` after the existing telemetry block, identified by the `## Next Action` heading boundary) that is byte-identical to the captured pre-M027 baseline. The fixture baseline lives at `tests/fixtures/m027-p02/status-quiet-baseline.txt`. The verifier diffs the tail of a deterministic invocation against the fixture; failure if `diff` exits non-zero. Two suppression paths are exercised: (a) `--quiet` flag on the simulated status invocation; (b) `efficiency_footer: false` in a `mktemp`-isolated `.orchestrator/config.yml`. Both paths produce the byte-identical tail (FR-6, FR-7, CON-3, SC-3).
  - Check: `bash scripts/verify/m027-p02-status-quiet-byte-identity.sh`

- `scripts/dispatch/predictive-surface.sh` exists, is executable, sourceable, and accepts `--description <text>` (required), `--intensity quick|standard|full` (required), `--no-predict`, `--yes`, `--config-defaults <path>`, `--help` flags. Default mode (interactive: not `--yes`, not `ORCHESTRATOR_AUTO=1`, not `--no-predict`, not `config.predictive_cost_surface: false`, intensity in `{standard, full}`) emits a one-block predictive surface (recommended tier highlighted, per-tier cost+quality table, one-line override prompt). Suppressed mode (any of the suppression conditions met, or intensity = quick) emits exactly zero stdout, exit 0. Reads via `scripts/engine/intensity-recommend.sh --format text` (with `_CE_RECOMMENDED` pre-set + `INTENSITY_RECOMMEND_FAST_PATH=1` exported per the P01/T02 hook contract); never writes to `execution-log.jsonl` (FR-12 carry-forward). (FR-23, US-5 AS-3, AS-4, CON-10).
  - Check: `bash scripts/verify/m027-p02-predictive-surface-shape.sh`

- Suppression matrix is exhaustively enforced — the predictive surface emits exactly zero stdout under each of: `--yes`, `ORCHESTRATOR_AUTO=1`, `--no-predict`, `config.predictive_cost_surface: false`, intensity `quick`. The verifier exercises all five suppression paths against a deterministic invocation and asserts byte-identical empty stdout per path; exit 0 in all five. The interactive (default) path emits the surface block (asserted by the shape verifier above). (FR-23, CON-3, CON-10, SC-17, #Q-16 resolution.)
  - Check: `bash scripts/verify/m027-p02-suppression-matrix.sh`

- Dispatch byte-identity (suppressed mode) — `commands/dispatch.md` is updated to invoke the predictive surface helper at the documented attach point (after the `## Dispatch Strategy` section, before `## Execution Recording`); the invocation is gated by the suppression matrix above. The verifier asserts the documented attach-point exists and is wrapped with the gating condition (markdown-source structural check, since `commands/dispatch.md` is a markdown command document, not a shell entry point) AND that `bash scripts/dispatch/predictive-surface.sh --description "<sample>" --intensity standard --yes` emits empty stdout. (FR-23, CON-3, SC-17, MEM012.)
  - Check: `bash scripts/verify/m027-p02-dispatch-md-shape.sh`

- Predictive surface latency — `time bash scripts/dispatch/predictive-surface.sh --description "<sample>" --intensity standard` reports wall-clock under the latency budget on a 2024-era laptop; verifier applies the **inner** measurement (with `INTENSITY_RECOMMEND_FAST_PATH=1` + `_CE_RECOMMENDED=standard` pre-set, bypassing the inner intensity-recommend re-fork) at a 100 ms hard threshold + the **outer** measurement (full fork chain) reported as informational with `RELAX-CANDIDATE` annotation if it exceeds 250 ms — outer wall-clock includes ~200 ms of bash startup + fork overhead on macOS that the helper author cannot optimize. Per the P01 lesson: hard-fail only on the inner library budget; outer measurement carries `RELAX-CANDIDATE` annotation forwarded by the suite orchestrator (FR-22 carry-forward, CON-9 carry-forward, SC-15 carry-forward).
  - Check: `bash scripts/verify/m027-p02-predictive-surface-latency.sh`

- Predictive Goodhart pairing on the dispatch-time surface — every line of the predictive-surface helper output that contains a cost token also contains a quality token on the same row (mirrors P01's predictive-goodhart verifier; the dispatch-time surface re-uses the same per-tier table renderer via `intensity-recommend.sh --format text`'s cost-annotation block, so the pairing is inherited but is verified explicitly at the dispatch-time surface to close CON-4 at this attach-point). (CON-4 carry-forward, SC-18 carry-forward, FR-23.)
  - Check: `bash scripts/verify/m027-p02-predictive-goodhart-pairing.sh`

- Zero-LLM-token contract — grepping the M027/P02 script set (`scripts/diagnostics/efficiency-footer.sh`, `scripts/dispatch/predictive-surface.sh`, every `scripts/verify/m027-p02-*.sh`) for forbidden LLM-invocation patterns (`claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`) returns no matches. Carries forward the FR-21 / CON-6 / SC-16 contract from P01 to P02's new helpers (FR-21 carry-forward, CON-6 carry-forward, SC-16 carry-forward).
  - Check: `bash scripts/verify/m027-p02-zero-llm-token.sh`

- Read-only invariant carry-forward — `git diff --quiet` against the project tree after running `efficiency-footer.sh`, `predictive-surface.sh` (default mode), and `predictive-surface.sh --yes` (suppressed mode) against the live repo is exit 0; no JSONL records are emitted by P02 code paths; no config files are modified. The verifier captures a pre-run `git diff --quiet` exit; if dirty, it skips with `WARN: working-tree-dirty pre-run; skipping read-only assertion` (mirrors P01/T04 pattern). (FR-12, CON-1, SC-9 carry-forward.)
  - Check: `bash scripts/verify/m027-p02-read-only.sh`

- bash 3.2 compat — every M027/P02 shell script (`scripts/diagnostics/efficiency-footer.sh`, `scripts/dispatch/predictive-surface.sh`, every `scripts/verify/m027-p02-*.sh`) does not match the forbidden-construct regex `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^})` (CON-7, SC-11 carry-forward). Verifier excludes itself from the scan via explicit file list (mirrors P01 carve-out).
  - Check: `bash scripts/verify/m027-p02-bash32-compat.sh`

- `bash scripts/verify/m027-p02-suite.sh` orchestrates the full P02 verifier set (the named per-contract checks above), runs them in stable order (cheapest static checks first, latency / live-invocation last), aggregates PASS/FAIL counts to stdout, forwards `RELAX-CANDIDATE` annotations from the latency gate to stdout, and exits 0 on green / 1 on red (FR-15 carry-forward to P02 surface, mirrors P00's `m027-rollup-schema.sh` and P01's `m027-p01-suite.sh` shape).
  - Check: `bash scripts/verify/m027-p02-suite.sh`

### Artifacts

- `scripts/diagnostics/efficiency-footer.sh` (min 80 lines, contains "Efficiency (Tier 1 rollup)")
- `scripts/dispatch/predictive-surface.sh` (min 80 lines, contains "predictive_cost_surface")
- `commands/status.md` (min 170 lines, contains "efficiency-footer")
- `commands/dispatch.md` (min 160 lines, contains "predictive-surface")
- `tests/fixtures/m027-p02/status-quiet-baseline.txt` (min 1 lines, contains "Next Action")
- `scripts/verify/m027-p02-suite.sh` (min 30 lines, contains "m027-p02")
- `scripts/verify/m027-p02-efficiency-footer-shape.sh` (min 30 lines, contains "Efficiency (Tier 1 rollup)")
- `scripts/verify/m027-p02-status-md-shape.sh` (min 30 lines, contains "efficiency-footer")
- `scripts/verify/m027-p02-status-quiet-byte-identity.sh` (min 30 lines, contains "diff")
- `scripts/verify/m027-p02-predictive-surface-shape.sh` (min 30 lines, contains "predictive-surface")
- `scripts/verify/m027-p02-suppression-matrix.sh` (min 30 lines, contains "no-predict")
- `scripts/verify/m027-p02-dispatch-md-shape.sh` (min 30 lines, contains "predictive-surface")
- `scripts/verify/m027-p02-predictive-surface-latency.sh` (min 30 lines, contains "100")
- `scripts/verify/m027-p02-predictive-goodhart-pairing.sh` (min 30 lines, contains "Goodhart")
- `scripts/verify/m027-p02-zero-llm-token.sh` (min 30 lines, contains "anthropic")
- `scripts/verify/m027-p02-read-only.sh` (min 30 lines, contains "git diff --quiet")
- `scripts/verify/m027-p02-bash32-compat.sh` (min 30 lines, contains "declare -A")

### Key Links

- `commands/status.md` → `scripts/diagnostics/efficiency-footer.sh` (footer surface delegates to the new helper)
- `commands/status.md` → `scripts/diagnostics/metrics-rollup.sh` (transitive — efficiency footer wraps the P00 rollup engine)
- `commands/dispatch.md` → `scripts/dispatch/predictive-surface.sh` (dispatch-time predictive surface delegates to the new helper)
- `scripts/diagnostics/efficiency-footer.sh` → `scripts/diagnostics/metrics-rollup.sh` (sources or forks the P00 engine for milestone-to-date aggregates)
- `scripts/diagnostics/efficiency-footer.sh` → `scripts/state/read-config.sh` (reads `efficiency_footer` config knob)
- `scripts/dispatch/predictive-surface.sh` → `scripts/engine/intensity-recommend.sh` (sources the P01 cost-annotation hook with `INTENSITY_RECOMMEND_FAST_PATH=1` short-circuit)
- `scripts/dispatch/predictive-surface.sh` → `scripts/engine/cost-estimate.sh` (transitively sourced via the P01 hook for the per-tier renderer)
- `scripts/dispatch/predictive-surface.sh` → `scripts/state/read-config.sh` (reads `predictive_cost_surface` config knob)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-efficiency-footer-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-status-md-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-status-quiet-byte-identity.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-predictive-surface-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-suppression-matrix.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-dispatch-md-shape.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-predictive-surface-latency.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-predictive-goodhart-pairing.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-zero-llm-token.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-read-only.sh` (orchestrated gate)
- `scripts/verify/m027-p02-suite.sh` → `scripts/verify/m027-p02-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: efficiency-footer helper + `efficiency_footer` config knob (`scripts/diagnostics/efficiency-footer.sh`)

See `.orchestrator/milestones/M027/phases/P02/tasks/T01-efficiency-footer-PLAN.md`.

### T02: `commands/status.md` integration + `tests/fixtures/m027-p02/status-quiet-baseline.txt`

See `.orchestrator/milestones/M027/phases/P02/tasks/T02-status-md-integration-PLAN.md`.

### T03: dispatch-time predictive surface helper + `commands/dispatch.md` integration (`scripts/dispatch/predictive-surface.sh`)

See `.orchestrator/milestones/M027/phases/P02/tasks/T03-predictive-surface-PLAN.md`.

### T04: P02 verifier suite (`m027-p02-suite.sh` + per-contract `m027-p02-*.sh`)

See `.orchestrator/milestones/M027/phases/P02/tasks/T04-verifier-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T04
            │
T03 ────────┴──► T04
```

T01 ships the efficiency-footer helper (no upstream P02 tasks; consumes only P00's `metrics-rollup.sh`). T02 wires `commands/status.md` to invoke T01's helper and ships the byte-identity baseline fixture (depends on T01 to produce a stable invocation surface). T03 ships the predictive-surface helper + edits to `commands/dispatch.md` (no upstream P02 tasks; consumes only P01's cost-annotation hook via `intensity-recommend.sh --format text`). T04 verifies all three together and asserts the byte-identity / suppression / latency / Goodhart-pairing / read-only / bash-3.2 / zero-LLM-token contracts.

T01 and T03 can run in parallel (independent surfaces, independent helpers, no shared edits). T02 depends on T01 (the baseline fixture is captured against the post-T01 helper invocation). T04 depends on T01 + T02 + T03 (its verifiers gate against the post-T03 codebase).

## Files Likely Touched

- scripts/diagnostics/efficiency-footer.sh (create)
- scripts/dispatch/predictive-surface.sh (create)
- commands/status.md (modify)
- commands/dispatch.md (modify)
- tests/fixtures/m027-p02/status-quiet-baseline.txt (create)
- tests/fixtures/m027-p02/README.md (create)
- scripts/verify/m027-p02-suite.sh (create)
- scripts/verify/m027-p02-efficiency-footer-shape.sh (create)
- scripts/verify/m027-p02-status-md-shape.sh (create)
- scripts/verify/m027-p02-status-quiet-byte-identity.sh (create)
- scripts/verify/m027-p02-predictive-surface-shape.sh (create)
- scripts/verify/m027-p02-suppression-matrix.sh (create)
- scripts/verify/m027-p02-dispatch-md-shape.sh (create)
- scripts/verify/m027-p02-predictive-surface-latency.sh (create)
- scripts/verify/m027-p02-predictive-goodhart-pairing.sh (create)
- scripts/verify/m027-p02-zero-llm-token.sh (create)
- scripts/verify/m027-p02-read-only.sh (create)
- scripts/verify/m027-p02-bash32-compat.sh (create)
