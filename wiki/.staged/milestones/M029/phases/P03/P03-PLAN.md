---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M029"
goal: "Land the M029 closing slice: the `--live` branch on `render-position.sh` (FR-7, #Q-1 full re-render, #Q-G9 latency methodology) with the `▽ saved Nk` compression-savings marker (FR-8, #Q-G8 canonical compact form) gated by the new `display_thresholds.compression_savings_pct` config knob (AD-5); the `orchestrator:auto` preflight summary block (FR-9) honouring the AD-3 non-interactive policy (`--yes` > `auto_proceed: true` > non-TTY refusal with `M029_PREFLIGHT_NEEDS_CONFIRMATION` > TTY prompt) with cost field byte-identical to the AD-4 oracle wrapper (`predictive-surface.sh` over `summarize-milestone.sh`'s deterministic key=value block); `--auto-chain` on `orchestrator:start` (FR-10) walking `evaluate → discuss → roadmap → plan-phase` with `.orchestrator/start-state/<stage>.complete` markers and #Q-3 leave-marker-absent failure semantics; the SC-7/SC-8/SC-9/SC-10 fixtures + acceptance scripts + `measure-live-tail-latency.sh` harness (#Q-G9 p95 ≤ 1.0s); the AD-4 spec amendment record entry capturing the SC-8 oracle interface change; the milestone-grain `tests/m029-acceptance/run-acceptance-battery.sh` emitting `BATTERY: pass=14 fail=0` over SC-1..SC-14; and the closure ceremony — `validate-milestone.sh M029` 100% PASS, `M029-VALIDATED` marker, `M029-SUMMARY.md`, milestone-grain `unit_close` event."
demo_sentence: "A developer runs `bash scripts/diagnostics/render-position.sh --live --milestone M998` against a fixture, appends a synthetic `dispatch_usage` record with `tier1_savings_tokens + tier2_savings_tokens > 5%` of total dispatch tokens to the fixture's `execution-log.jsonl`, and observes the rendered tree update within 1 second showing the `▽ saved Nk` marker on the corresponding row (SC-7); runs `orchestrator:auto` at Standard intensity against the SC-8 fixture milestone with `--yes` set and observes a preflight block on stderr whose `predicted_cost` field is byte-identical to the `cost_standard_usd=` line emitted by `bash scripts/dispatch/predictive-surface.sh --description \"$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)\" --intensity standard` (SC-8); runs `orchestrator:auto` at Quick intensity and observes no `Preflight Summary` token appears on stderr before `AUTO:READY` (SC-9); runs `orchestrator:start --auto-chain` against the SC-10 greenfield fixture, walks the four entry-chain gates with `--yes`, observes the four marker files written in order under `.orchestrator/start-state/`, then interrupts between `discuss` and `roadmap`, re-invokes, and observes resume at `roadmap` without re-prompting evaluate/discuss (SC-10); runs `bash tests/m029-acceptance/run-acceptance-battery.sh` and observes `BATTERY: pass=14 fail=0`; runs `bash scripts/verify/validate-milestone.sh M029` and observes 100% PASS with the `M029-VALIDATED` marker on disk and `M029-SUMMARY.md` written; observes the milestone-grain `unit_close` event appended to `.orchestrator/milestones/M029/execution-log.jsonl`."
risk: "medium"
depends_on: ["P02"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ with
     the m029-p03-* prefix per the milestone-slug-required convention.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Path-collision rule 6 has been pre-checked at plan-authoring time:
     no P03 deliverable path shadows an existing file (verified
     2026-05-06 via `ls` against every `(create)` entry in `Files
     Likely Touched`). -->

### Truths

- `scripts/diagnostics/render-position.sh` carries an additive `--live` branch that polls `execution-log.jsonl` via POSIX `tail -f`, full-re-renders the tree on every appended `dispatch_usage` record (#Q-1), emits a `▽ saved Nk` marker on rows whose `(tier1_savings_tokens + tier2_savings_tokens) / dispatch_total_tokens` exceeds the `display_thresholds.compression_savings_pct` config knob (default 5.0 per AD-5), uses ONLY the canonical compact form `▽ saved Nk` (#Q-G8 — no `▽ Nk saved` and no `▽ saved Nk via tier1 cache reuse` strings appear anywhere in P03 deliverables), and never invokes `gh` / GitHub APIs (CON-4 / FR-11). Read-only — never writes to `.orchestrator/`.
  - Check: `bash tools/verify/m029-p03-render-position-live-shape.sh`

- `references/file-formats.md` documents the `display_thresholds:` block per AD-5 with the `compression_savings_pct: 5.0` heuristic-default annotation + review trigger ("Tune after first 10 milestones of [M019](../../../../milestones/M019/index.md) Tier 1 + [M018](../../../../milestones/M018/index.md) Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones."). `templates/orchestrator-config-default.yml` carries the new `display_thresholds:` block at top level with a YAML comment naming AD-5 and the FR-8 review trigger. `scripts/state/read-config.sh`'s `VALID_KEYS` list extends to include `display_thresholds.compression_savings_pct`.
  - Check: `bash tools/verify/m029-p03-display-thresholds-config-shape.sh`

- `commands/auto.md` is modified additively to prepend a `## Preflight Summary` section ABOVE the existing `## Core Workflow` (or canonical first H2 — the file's existing first ## section), documenting the FR-9 + AD-3 contract: at Standard or Full intensity, the auto skill emits a preflight block on stderr containing phase count, expected dispatch count, and `predicted_cost: est. ~$X.YY ± $Z.ZZ` (#Q-2 range form derived from `predictive-surface.sh`'s confidence interval); at Quick intensity, the preflight is suppressed entirely (no `Preflight Summary` token appears on stderr — SC-9 invariant). The non-interactive policy follows AD-3 priority order: `--yes` > `auto_proceed: true` > non-TTY refusal with the byte-stable `M029_PREFLIGHT_NEEDS_CONFIRMATION` stderr string > TTY prompt. The block emits the AD-4 oracle wrapper command (`predictive-surface.sh --description "$(summarize-milestone.sh M###)" --intensity standard`) verbatim in the docstring so future readers can reproduce the cost line by hand.
  - Check: `bash tools/verify/m029-p03-auto-preflight-shape.sh`

- `commands/start.md` is modified additively to add `--auto-chain` flag documentation (FR-10): the flag walks `evaluate → discuss → roadmap → plan-phase` one stage at a time, writes `.orchestrator/start-state/<stage>.complete` after each successful stage, leaves the marker absent on failure (#Q-3 — re-runs re-execute the failed stage; surfaced via `orchestrator:status`), resumes from the first incomplete marker on re-invocation, OFF by default. The flag honours `--yes` and `auto_proceed: true` for between-stage gates (mirroring AD-3). `scripts/lifecycle/start.sh` parses `--auto-chain`, USAGE-string-extends to include it, and wires the flag through to a chain-driver block that invokes the four entry-chain skills via the standard skill-invocation surface.
  - Check: `bash tools/verify/m029-p03-auto-chain-shape.sh`

- `tests/m029-acceptance/measure-live-tail-latency.sh` exists, is executable, implements the #Q-G9 methodology: writes a synthetic `dispatch_usage` record with savings ≥5% to a fixture's `execution-log.jsonl`, captures monotonic-clock timestamps before the append and at first re-rendered output, computes append-to-render latency, repeats N times (default 10), reports p50/p95/p99 percentiles. Asserts p95 ≤ 1.0s; emits p99 informationally (no hard fail per AD); no per-measurement retry. If p95 measurements drift beyond 1.5s during P03 execution, the harness emits a RISK-tracked finding callout to stderr (per AD #Q-G9 escalation rule).
  - Check: `bash tools/verify/m029-p03-measure-live-tail-latency-shape.sh`

- The SC-7 acceptance script `tests/m029-acceptance/p03-sc7-live-tail.sh` exists, is executable, and exits 0. The script: (a) sets up a fixture under `mktemp -d` with a fixture milestone and a populated `execution-log.jsonl`; (b) backgrounds `bash scripts/diagnostics/render-position.sh --live --milestone <fixture-id>` capturing stdout to a temp file; (c) appends a synthetic `dispatch_usage` record with `tier1_savings_tokens + tier2_savings_tokens > 5%` of total dispatch tokens; (d) waits up to 1.5s for the temp file to grow with a re-render containing `▽ saved Nk`; (e) asserts the marker appears AND the wall-clock latency from append to render ≤ 1.0s p95 (delegates to `measure-live-tail-latency.sh` for the multi-trial p95 assertion); (f) appends a second record with savings <5% and asserts the row updates without the marker.
  - Check: `bash tools/verify/m029-p03-sc7-shape.sh`

- The SC-8 acceptance script `tests/m029-acceptance/p03-sc8-auto-preflight.sh` exists, is executable, and exits 0. The script: (a) sets up a fixture milestone at `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` in a state where `summarize-milestone.sh --format=keys` emits a deterministic key=value block; (b) computes the oracle's expected `cost_standard_usd=` line by invoking `bash scripts/dispatch/predictive-surface.sh --description "$(bash scripts/diagnostics/summarize-milestone.sh <fixture-id> --format=keys)" --intensity standard` and capturing the `cost_standard_usd=` line via `grep -F`; (c) invokes the auto-preflight surface (the `commands/auto.md`-documented preflight emission path; in M029's read-only-skill-doc model the surface is exercised by running the documented oracle wrapper command directly and asserting the FR-9 contract holds in the docstring) against the fixture with `--yes` set; (d) extracts the preflight block's `predicted_cost` line from stderr; (e) asserts the cost numeric value extracted from the preflight block matches the oracle's `cost_standard_usd=` numeric value byte-for-byte; (f) asserts the preflight block contains the phase count + dispatch count fields per FR-9.
  - Check: `bash tools/verify/m029-p03-sc8-shape.sh`

- The SC-9 acceptance script `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` exists, is executable, and exits 0. The script: (a) sets up a fixture at `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` with intensity=Quick declared in the EVALUATION frontmatter; (b) invokes the auto-preflight surface against the fixture; (c) captures stderr to a temp file; (d) asserts the literal token `Preflight Summary` does NOT appear in stderr before the literal `AUTO:READY` token (the SC-9 byte-stable invariant — Quick intensity suppresses the preflight block entirely per FR-9 + AD-3).
  - Check: `bash tools/verify/m029-p03-sc9-shape.sh`

- The SC-10 acceptance script `tests/m029-acceptance/p03-sc10-auto-chain.sh` exists, is executable, and exits 0. The script: (a) sets up a fresh greenfield fixture at `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` with no `.orchestrator/start-state/` markers; (b) invokes `bash scripts/lifecycle/start.sh --project-dir <fixture> --auto-chain --yes`; (c) asserts the four marker files `.orchestrator/start-state/{evaluate,discuss,roadmap,plan-phase}.complete` exist after the run; (d) deletes `roadmap.complete` and `plan-phase.complete` to simulate mid-chain interruption; (e) re-invokes `start.sh --auto-chain --yes`; (f) asserts the resume run did NOT rewrite `evaluate.complete` or `discuss.complete` mtimes (mtime preservation = idempotent skip); (g) asserts the resume run DID write `roadmap.complete` and `plan-phase.complete` again. The fixture's per-stage skill invocations are stubbed (each stage is a no-op shell that writes its marker) — this acceptance covers the chain-driver semantics, not the deep behavior of each underlying skill (those are tested by their own milestones).
  - Check: `bash tools/verify/m029-p03-sc10-shape.sh`

- The SC-8 oracle interface change is documented in `specs/037-roadmap-visibility-cli-ux/spec.md` as a `## Spec Amendment Record` entry (or appended to an existing such section). The amendment names AD-4, references the discuss-time decision, and re-states SC-8 with the corrected oracle wrapper shape (`predictive-surface.sh --description "$(summarize-milestone.sh M### --format=keys)" --intensity standard` — `--no-predict` is NOT used in the SC-8 byte-identity oracle because `--no-predict` suppresses cost output; the byte-identity contract operates on the `cost_standard_usd=` scalar extracted from the un-suppressed oracle output).
  - Check: `bash tools/verify/m029-p03-spec-amendment-shape.sh`

- `tests/m029-acceptance/run-acceptance-battery.sh` exists, is executable, and chains every SC acceptance script in dependency order (SC-1, SC-2, SC-3, SC-4 from P01; SC-5, SC-6, SC-13, SC-14 from P02; SC-7, SC-8, SC-9, SC-10, plus SC-11 self-reference and SC-12 milestone-validator hook from P03). Emits `BATTERY: pass=14 fail=0` per SC-11 on full pass; exits 0 iff every sub-script exits 0. This is the milestone-grain battery that `validate-milestone.sh M029` (T06) consumes alongside the three phase-suites. SC-13 is the anti-coupling guard (`grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match, P02 deliverable); SC-14 is the read-only sentinel-file harness (P02 deliverable). The battery does NOT re-implement those checks — it invokes the P02 acceptance scripts directly.
  - Check: `bash tools/verify/m029-p03-run-acceptance-battery-shape.sh`

- The P03 acceptance battery `tests/m029-acceptance/p03-acceptance-battery.sh` exists, is executable, and chains the four P03 SC acceptance scripts (SC-7, SC-8, SC-9, SC-10), exits 0 iff every sub-script exits 0, and emits `BATTERY: pass=4 fail=0` on full pass. This is the P03 slice of the SC-11 milestone-grain battery (P01 ships its own slice with SC-1..SC-4, P02 ships its slice with SC-5/SC-6/SC-13/SC-14).
  - Check: `bash tools/verify/m029-p03-acceptance-battery-shape.sh`

- The P03 readonly-invariant verifier `tools/verify/m029-p03-readonly-invariant.sh` exists, is executable, runs `render-position.sh --live` against a fixture for ≥1 second under a sentinel-mtime guard, runs the auto-preflight surface against the SC-8 fixture, runs `start.sh --auto-chain --yes` against the SC-10 fixture, and asserts no `.orchestrator/` file under the live project tree (excluding `.orchestrator/start-state/<stage>.complete` markers when `--auto-chain` is the unit under test, and the sentinel itself) has an mtime newer than the sentinel after the runs. Mirrors P01/P02 readonly-invariant precedent; LIVE-tree variant complements the FIXTURE-tree variants in SC-14.
  - Check: `bash tools/verify/m029-p03-readonly-invariant.sh`

- The P03 scope-guard verifier `tools/verify/m029-p03-scope-guard.sh` exists, is executable, captures `git status --porcelain=v1`, classifies each touched path against the P03 allowlist + denylist, and exits 0 unless any deny hit appears. Allowlist enumerates exactly the `Files Likely Touched` paths declared below; denylist enumerates `commands/init.md` ([M033](../../../../milestones/M033/index.md)), `scripts/lifecycle/auto-loop.sh` (Principle XV), `scripts/diagnostics/metrics-rollup.sh`, `scripts/diagnostics/efficiency-footer.sh` ([M027](../../../../milestones/M027/index.md) read-only consumer per CON-7/AD-8), `.orchestrator/integrations/github.json` (CON-4/FR-11), [`.orchestrator/KNOWLEDGE.md`](../../../../knowledge.md), [`.orchestrator/DECISIONS.md`](../../../../decisions.md) ([M020](../../../../milestones/M020/index.md) schema authority per CON-7). `WARN:` for unclassified, FAIL only on deny hits — P01/P02 precedent.
  - Check: `bash tools/verify/m029-p03-scope-guard.sh`

- The P03 phase-suite aggregator `tools/verify/m029-p03-phase-suite.sh` exists, is executable, chains every P03 verifier in dependency order (T01:2 + T02:1 + T03:1 + T04:5 + T05:5 = 14 gates), emits `OK:` / `FAIL:` per gate + `SUMMARY: m029-p03-phase-suite.sh pass=N fail=M` on exit, exits 0 iff `fail=0`. Mirrors `m029-p01-phase-suite.sh` and `m029-p02-phase-suite.sh` straight-line bash shape.
  - Check: `bash tools/verify/m029-p03-phase-suite.sh`

- `bash scripts/verify/validate-milestone.sh M029` reports 100% PASS chaining `m029-p01-phase-suite.sh` (14 gates) + `m029-p02-phase-suite.sh` (13 gates) + `m029-p03-phase-suite.sh` (14 gates) + `tests/m029-acceptance/run-acceptance-battery.sh` (`BATTERY: pass=14 fail=0`).
  - Check: `bash tools/verify/m029-p03-validate-milestone-pass.sh`

- The closure ceremony fires: `.orchestrator/milestones/M029/M029-VALIDATED` marker exists; [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../milestones/M029/M029-SUMMARY.md) exists with the canonical milestone-summary frontmatter (15 fields per write-summary.sh task-mode usage example expanded shape) + body summarizing what was built, what was deferred, and what the post-close handoff is ([M035](../../../../milestones/M035/index.md) P00+P01 ergonomic prep before launch); the milestone-grain `unit_close` event is appended to `.orchestrator/milestones/M029/execution-log.jsonl` per the M019 emitter convention (consumes existing emitter; produces no new event type per CON-7).
  - Check: `bash tools/verify/m029-p03-closure-ceremony-shape.sh`

### Artifacts

- `scripts/diagnostics/render-position.sh` (modify; post-modification min 250 lines, contains "--live", contains "tail -f", contains "▽ saved", contains "compression_savings_pct", contains "AD-5", contains "FR-7", contains "FR-8", contains "#Q-1", contains "#Q-G8")
- `references/file-formats.md` (modify; post-modification min 1140 lines, contains "display_thresholds:", contains "compression_savings_pct", contains "AD-5", contains "Tune after first 10 milestones")
- `templates/orchestrator-config-default.yml` (modify; post-modification min 130 lines, contains "display_thresholds:", contains "compression_savings_pct: 5.0", contains "FR-8", contains "AD-5")
- `scripts/state/read-config.sh` (modify; VALID_KEYS contains "display_thresholds.compression_savings_pct")
- `commands/auto.md` (modify; post-modification min 80 lines, contains "Preflight Summary", contains "FR-9", contains "AD-3", contains "M029_PREFLIGHT_NEEDS_CONFIRMATION", contains "predictive-surface.sh", contains "summarize-milestone.sh", contains "auto_proceed", contains "--yes", contains "Quick intensity suppresses")
- `commands/start.md` (modify; post-modification min 60 lines, contains "--auto-chain", contains "FR-10", contains "evaluate", contains "discuss", contains "roadmap", contains "plan-phase", contains ".orchestrator/start-state/")
- `scripts/lifecycle/start.sh` (modify; post-modification contains "--auto-chain", contains "evaluate.complete", contains "discuss.complete", contains "roadmap.complete", contains "plan-phase.complete", contains "FR-10")
- `specs/037-roadmap-visibility-cli-ux/spec.md` (modify; post-modification contains "Spec Amendment Record", contains "AD-4", contains "summarize-milestone.sh", contains "predictive-surface.sh", contains "cost_standard_usd")
- `tests/m029-acceptance/measure-live-tail-latency.sh` (create; min 60 lines, contains "p95", contains "p99", contains "1.0", contains "tail -f", contains "#Q-G9")
- `tests/m029-acceptance/p03-sc7-live-tail.sh` (create; min 50 lines, contains "SC-7", contains "FR-7", contains "▽ saved", contains "1 second")
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` (create; min 60 lines, contains "SC-8", contains "FR-9", contains "predicted_cost", contains "cost_standard_usd")
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` (create; min 35 lines, contains "SC-9", contains "Preflight Summary", contains "Quick", contains "AUTO:READY")
- `tests/m029-acceptance/p03-sc10-auto-chain.sh` (create; min 70 lines, contains "SC-10", contains "FR-10", contains "evaluate.complete", contains "discuss.complete", contains "roadmap.complete", contains "plan-phase.complete", contains "resume")
- `tests/m029-acceptance/p03-acceptance-battery.sh` (create; min 25 lines, contains "BATTERY:", contains "p03-sc7-live-tail", contains "p03-sc8-auto-preflight", contains "p03-sc9-auto-quick-no-preflight", contains "p03-sc10-auto-chain")
- `tests/m029-acceptance/run-acceptance-battery.sh` (create; min 50 lines, contains "BATTERY:", contains "pass=14", contains "p01-acceptance-battery", contains "p02-acceptance-battery", contains "p03-acceptance-battery")
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (create — fixture milestone tree at intensity=Standard with EVALUATION frontmatter)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (create — fixture milestone tree at intensity=Quick)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (create — fresh greenfield project tree with stub entry-chain commands)
- `tools/verify/m029-p03-render-position-live-shape.sh` (create; min 40 lines, contains "render-position.sh", contains "--live", contains "▽ saved", contains "tail -f", contains "FR-7", contains "FR-8")
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` (create; min 30 lines, contains "display_thresholds", contains "compression_savings_pct", contains "AD-5", contains "VALID_KEYS")
- `tools/verify/m029-p03-auto-preflight-shape.sh` (create; min 35 lines, contains "commands/auto.md", contains "Preflight Summary", contains "FR-9", contains "AD-3", contains "M029_PREFLIGHT_NEEDS_CONFIRMATION")
- `tools/verify/m029-p03-auto-chain-shape.sh` (create; min 35 lines, contains "commands/start.md", contains "--auto-chain", contains "FR-10", contains "evaluate.complete", contains "scripts/lifecycle/start.sh")
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh` (create; min 25 lines, contains "measure-live-tail-latency.sh", contains "p95", contains "1.0")
- `tools/verify/m029-p03-sc7-shape.sh` (create; min 25 lines, contains "p03-sc7-live-tail.sh", contains "SC-7")
- `tools/verify/m029-p03-sc8-shape.sh` (create; min 25 lines, contains "p03-sc8-auto-preflight.sh", contains "SC-8")
- `tools/verify/m029-p03-sc9-shape.sh` (create; min 25 lines, contains "p03-sc9-auto-quick-no-preflight.sh", contains "SC-9")
- `tools/verify/m029-p03-sc10-shape.sh` (create; min 25 lines, contains "p03-sc10-auto-chain.sh", contains "SC-10")
- `tools/verify/m029-p03-spec-amendment-shape.sh` (create; min 25 lines, contains "Spec Amendment Record", contains "AD-4", contains "specs/037-roadmap-visibility-cli-ux/spec.md")
- `tools/verify/m029-p03-acceptance-battery-shape.sh` (create; min 25 lines, contains "p03-acceptance-battery.sh", contains "BATTERY:")
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh` (create; min 30 lines, contains "run-acceptance-battery.sh", contains "BATTERY:", contains "pass=14")
- `tools/verify/m029-p03-readonly-invariant.sh` (create; min 40 lines, contains "FR-14", contains "CON-1", contains "sentinel", contains "render-position.sh", contains "--live", contains "auto-chain")
- `tools/verify/m029-p03-scope-guard.sh` (create; min 60 lines, contains "render-position.sh", contains "commands/auto.md", contains "commands/start.md", contains "scripts/lifecycle/start.sh", contains "metrics-rollup.sh", contains "efficiency-footer.sh", contains "KNOWLEDGE.md", contains "auto-loop.sh")
- `tools/verify/m029-p03-phase-suite.sh` (create; min 100 lines, contains "SUMMARY:", contains "m029-p03-render-position-live-shape", contains "m029-p03-display-thresholds-config-shape", contains "m029-p03-auto-preflight-shape", contains "m029-p03-auto-chain-shape", contains "m029-p03-measure-live-tail-latency-shape", contains "m029-p03-sc7-shape", contains "m029-p03-sc8-shape", contains "m029-p03-sc9-shape", contains "m029-p03-sc10-shape", contains "m029-p03-spec-amendment-shape", contains "m029-p03-acceptance-battery-shape", contains "m029-p03-readonly-invariant", contains "m029-p03-scope-guard")
- `tools/verify/m029-p03-validate-milestone-pass.sh` (create; min 25 lines, contains "validate-milestone.sh", contains "M029", contains "100%")
- `tools/verify/m029-p03-closure-ceremony-shape.sh` (create; min 35 lines, contains "M029-VALIDATED", contains "M029-SUMMARY.md", contains "unit_close")
- `.orchestrator/milestones/M029/M029-VALIDATED` (create — empty marker file or single-line acknowledgment per `validate-milestone.sh` convention)
- [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../milestones/M029/M029-SUMMARY.md) (create; min 80 lines, contains "milestone: \"M029\"", contains "completed_at:", contains "verification_result: \"pass\"")

### Key Links

- `commands/auto.md` → `scripts/dispatch/predictive-surface.sh` (FR-9 + AD-4 oracle)
- `commands/auto.md` → `scripts/diagnostics/summarize-milestone.sh` (AD-4 oracle wrapper)
- `commands/auto.md` → `scripts/state/detect-invocation-context.sh` (AD-3 non-interactive policy reads resolver per AD-1)
- `commands/start.md` → `scripts/lifecycle/start.sh` (FR-10 — start skill delegates to the driver script)
- `scripts/lifecycle/start.sh` → `commands/start.md` (back-reference for the skill that wraps the script)
- `scripts/diagnostics/render-position.sh` → `scripts/state/read-config.sh` (FR-8 threshold knob read at --live entry)
- `tests/m029-acceptance/p03-sc7-live-tail.sh` → `tests/m029-acceptance/measure-live-tail-latency.sh` (SC-7 delegates p95 to the harness)
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` → `scripts/dispatch/predictive-surface.sh` (SC-8 oracle invocation)
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` → `scripts/diagnostics/summarize-milestone.sh` (SC-8 oracle wrapper)
- `tests/m029-acceptance/p03-sc10-auto-chain.sh` → `scripts/lifecycle/start.sh` (SC-10 invokes the driver)
- `tests/m029-acceptance/run-acceptance-battery.sh` → `tests/m029-acceptance/p01-acceptance-battery.sh` (P01 slice)
- `tests/m029-acceptance/run-acceptance-battery.sh` → `tests/m029-acceptance/p02-acceptance-battery.sh` (P02 slice)
- `tests/m029-acceptance/run-acceptance-battery.sh` → `tests/m029-acceptance/p03-acceptance-battery.sh` (P03 slice)
- `tools/verify/m029-p03-phase-suite.sh` → `tools/verify/m029-p03-render-position-live-shape.sh` (suite chains T01)
- `tools/verify/m029-p03-phase-suite.sh` → `tools/verify/m029-p03-auto-preflight-shape.sh` (suite chains T02)
- `tools/verify/m029-p03-phase-suite.sh` → `tools/verify/m029-p03-auto-chain-shape.sh` (suite chains T03)
- `tools/verify/m029-p03-phase-suite.sh` → `tools/verify/m029-p03-sc7-shape.sh` (suite chains T04)
- `tools/verify/m029-p03-phase-suite.sh` → `tools/verify/m029-p03-readonly-invariant.sh` (suite chains T05)
- `specs/037-roadmap-visibility-cli-ux/spec.md` → `scripts/diagnostics/summarize-milestone.sh` (Spec Amendment Record cross-reference for AD-4)
- `references/file-formats.md` → `templates/orchestrator-config-default.yml` (display_thresholds documentation cross-reference)

## Tasks

### T01: `--live` branch on `render-position.sh` + `▽ saved Nk` marker + `display_thresholds.compression_savings_pct` config knob (FR-7, FR-8, AD-5, #Q-1, #Q-G8)

See `tasks/T01-render-position-live-and-savings-marker-PLAN.md`.

### T02: `orchestrator:auto` preflight summary + AD-3 non-interactive policy + AD-4 oracle integration (FR-9, AD-3, AD-4, #Q-2)

See `tasks/T02-auto-preflight-summary-PLAN.md`.

### T03: `--auto-chain` flag on `orchestrator:start` + marker-file resume (FR-10, #Q-3)

See `tasks/T03-auto-chain-flag-PLAN.md`.

### T04: SC-7/SC-8/SC-9/SC-10 fixtures + acceptance scripts + `measure-live-tail-latency.sh` harness (#Q-G9)

See `tasks/T04-fixtures-and-sc-acceptance-PLAN.md`.

### T05: P03 close gates — phase-suite + p03-acceptance-battery + readonly-invariant + scope-guard + spec amendment record (AD-4)

See `tasks/T05-phase-close-gates-PLAN.md`.

### T06: Milestone closure ceremony — `run-acceptance-battery.sh` + `validate-milestone.sh M029` + `M029-VALIDATED` + `M029-SUMMARY.md` + milestone-grain `unit_close` (SC-11, SC-12)

See `tasks/T06-milestone-closure-PLAN.md`.

## Task Dependencies

```
T01 ──► T04 ──► T05 ──► T06
        ▲       ▲
T02 ────┤       │
        │       │
T03 ────┘       │
                │
(spec amendment lives in T05 alongside close gates)
```

- **T01** (render-position --live + savings marker + config knob) depends on P02's `render-position.sh` (extended in-place) and `summarize-milestone.sh` (consumed by T02 via the AD-4 oracle wrapper, not directly by T01). Lands first because the core surface every SC exercises sits here.
- **T02** (auto preflight) depends on T01 (the FR-8 threshold knob lives in the shared config block; T02's docstring references it for completeness) and on P02's `summarize-milestone.sh` (AD-4 oracle wrapper). Could land in parallel with T01 but the executor is sequential.
- **T03** (--auto-chain) is independent of T01/T02 — touches a different surface (`commands/start.md` + `scripts/lifecycle/start.sh`). Lands after T02 in the serial chain.
- **T04** (fixtures + SC acceptance scripts + latency harness) depends on T01 (SC-7 exercises `--live`), T02 (SC-8 + SC-9 exercise the preflight surface), and T03 (SC-10 exercises `--auto-chain`).
- **T05** (P03 close gates + spec amendment record) depends on T04 (phase-suite chains every prior verifier; readonly-invariant runs against T01/T02/T03 surfaces; the spec amendment record entry per AD-4 lands here so it's grouped with the close-gate ceremony rather than scattered into T01-T04 tasks).
- **T06** (milestone closure ceremony) depends on T05 — `run-acceptance-battery.sh` chains all three phase batteries; `validate-milestone.sh M029` runs after every per-phase suite is green; the closure ceremony writes the `M029-VALIDATED` marker + `M029-SUMMARY.md` + appends the milestone-grain `unit_close` JSONL event.

## Files Likely Touched

- `scripts/diagnostics/render-position.sh` (modify)
- `references/file-formats.md` (modify)
- `templates/orchestrator-config-default.yml` (modify)
- `scripts/state/read-config.sh` (modify — VALID_KEYS extension only)
- `commands/auto.md` (modify)
- `commands/start.md` (modify)
- `scripts/lifecycle/start.sh` (modify)
- `specs/037-roadmap-visibility-cli-ux/spec.md` (modify — Spec Amendment Record entry)
- `tests/m029-acceptance/measure-live-tail-latency.sh` (create)
- `tests/m029-acceptance/p03-sc7-live-tail.sh` (create)
- `tests/m029-acceptance/p03-sc8-auto-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` (create)
- `tests/m029-acceptance/p03-sc10-auto-chain.sh` (create)
- `tests/m029-acceptance/p03-acceptance-battery.sh` (create)
- `tests/m029-acceptance/run-acceptance-battery.sh` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/` (create)
- `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/` (create)
- `tools/verify/m029-p03-render-position-live-shape.sh` (create)
- `tools/verify/m029-p03-display-thresholds-config-shape.sh` (create)
- `tools/verify/m029-p03-auto-preflight-shape.sh` (create)
- `tools/verify/m029-p03-auto-chain-shape.sh` (create)
- `tools/verify/m029-p03-measure-live-tail-latency-shape.sh` (create)
- `tools/verify/m029-p03-sc7-shape.sh` (create)
- `tools/verify/m029-p03-sc8-shape.sh` (create)
- `tools/verify/m029-p03-sc9-shape.sh` (create)
- `tools/verify/m029-p03-sc10-shape.sh` (create)
- `tools/verify/m029-p03-spec-amendment-shape.sh` (create)
- `tools/verify/m029-p03-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p03-readonly-invariant.sh` (create)
- `tools/verify/m029-p03-scope-guard.sh` (create)
- `tools/verify/m029-p03-phase-suite.sh` (create)
- `tools/verify/m029-p03-validate-milestone-pass.sh` (create)
- `tools/verify/m029-p03-closure-ceremony-shape.sh` (create)
- `.orchestrator/milestones/M029/M029-VALIDATED` (create)
- [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../milestones/M029/M029-SUMMARY.md) (create)
- `.orchestrator/milestones/M029/execution-log.jsonl` (append milestone-grain `unit_close` event; existing file)
