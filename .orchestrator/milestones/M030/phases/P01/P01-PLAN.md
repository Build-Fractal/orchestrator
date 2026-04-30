---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M030"
goal: "Author the M030 classifier + routing-table + cost_rates SSOT — `bash scripts/dispatch/classify-task.sh <plan-path>` emits deterministic `character=` + `confidence=` lines in <100ms with no network calls; `templates/model-routing.yml` declares the symbolic (character × runtime) → tier mapping plus the per-runtime resolution table plus a `cost_rates:` section; `bash scripts/diagnostics/run-doctor.sh --config-check` validates routing-table closure (no undefined symbolic-tier references, every (character, runtime) pair resolves) reporting offending file + line on malformation; the classifier-confidence stability metric (rolling per-class confidence-score variance threshold + minimum class-coverage count) is defined concretely in `references/model-routing.md` so P02's `shadow-compare.sh` consumes a fixed contract; the P00 fixture corpus's first commit timestamp precedes `classify-task.sh`'s first commit timestamp (D-A4/SC-10 mechanical proxy graduates from absence-check to git-log ordering); SC-10's ≥85% agreement holds against the P00 corpus."
demo_sentence: "An operator reads `scripts/dispatch/classify-task.sh`, invokes `bash scripts/dispatch/classify-task.sh tests/fixtures/m030-classifier-corpus/labels.yml`-referenced plan paths and observes deterministic `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` lines under 100ms with no network calls; reads `templates/model-routing.yml` and confirms the `(character × runtime) → symbolic-tier` table, the `(symbolic-tier × runtime) → model-id` resolution table, and the `cost_rates:` SSOT section; reads `references/model-routing.md` and confirms the classifier-confidence stability metric is defined in concrete numeric form (rolling per-class variance threshold + per-class minimum coverage count); runs `bash scripts/diagnostics/run-doctor.sh --config-check` and observes exit 0 on a well-formed table and exit 1 with file+line on a malformed table; runs `bash tools/verify/p01-phase-suite.sh` and observes `SUMMARY: p01-phase-suite.sh pass=N fail=0` exit 0; confirms via `git log` that `tests/fixtures/m030-classifier-corpus/labels.yml`'s first-commit timestamp predates `scripts/dispatch/classify-task.sh`'s first-commit timestamp (SC-10 timeline gate)."
risk: "high"
depends_on: ["P00"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p01-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2 (verifier-availability
     cross-check). No cross-task verifier dependencies. -->

### Truths

- D-A4/SC-10 timeline ordering holds: `tests/fixtures/m030-classifier-corpus/labels.yml`'s first-commit timestamp predates `scripts/dispatch/classify-task.sh`'s first-commit timestamp. (Graduates the P00 absence-check proxy to a git-log ordering check; the verifier accepts pre-graduation absence as a pass during T01 itself, then enforces ordering once classify-task.sh ships in T02.)
  - Check: `bash tools/verify/p01-d-a4-timeline.sh`

- `scripts/dispatch/classify-task.sh` exists and emits deterministic stdout. Two consecutive runs against the same plan path produce byte-identical `character=` + `confidence=` lines (no timestamp, no PID, no random ordering). Output vocabulary is closed: `character` ∈ {mechanical, standard, novel}; `confidence` ∈ {high, medium, low}. (FR-1 + FR-2 + SC-1 determinism gate.)
  - Check: `bash tools/verify/p01-classifier-determinism.sh`

- The classifier runs in well under 100ms per plan and makes no network calls. Performance gate: against any one P00 corpus plan, wall-clock measured by the classifier wrapper script is <100ms. Network-call gate: `classify-task.sh` body contains no `curl`, `wget`, `nc`, `dispatch-interface.sh`, or `bash scripts/dispatch/adapters/backend/` invocation; the script body is grep-asserted clean. (FR-1 hot-path constraint + SC-1 no-network-calls gate.)
  - Check: `bash tools/verify/p01-classifier-perf-and-network.sh`

- Classifier ground-truth agreement holds at ≥85%: `bash scripts/dispatch/classify-task.sh` output for each P00 corpus entry matches the human label (`character` field) for ≥34 of 40 plans. (SC-10 acceptance gate; the P00 fixture corpus has 40 entries — the floor is ≥85% × 40 = 34.)
  - Check: `bash tools/verify/p01-classifier-ground-truth.sh`

- `templates/model-routing.yml` exists with three required top-level sections: (a) `routing:` mapping `(character × runtime) → symbolic-tier` for the three classes (mechanical, standard, novel) and at minimum the `claude-code` runtime; (b) `resolution:` mapping `(symbolic-tier × runtime) → model-id` for the three symbolic tiers (fast, balanced, smart); (c) `cost_rates:` mapping each symbolic tier to per-million-token input + output costs. Symbolic-tier closure: every symbolic-tier reference in `routing:` resolves to an entry in `resolution:`; every reference in `cost_rates:` resolves to a tier in `resolution:`. (FR-3 + D-A6 + CON-3.)
  - Check: `bash tools/verify/p01-routing-table-shape.sh`

- `bash scripts/diagnostics/run-doctor.sh --config-check` exits 0 on the shipped well-formed `templates/model-routing.yml` and exits 1 on a deliberately malformed fixture (introducing an undefined symbolic-tier reference) with stdout naming both the offending file path and the offending line number. (FR-17 + SC-9.)
  - Check: `bash tools/verify/p01-doctor-config-check.sh`

- `references/model-routing.md` exists with at minimum these sections: `## Routing Table` (operator-facing description of the (character × runtime) → tier mapping), `## Per-Runtime Resolution` (how symbolic tiers resolve to runtime-specific model IDs), `## Cost Rates SSOT` (the cost_rates: section's contract + operator update obligation when provider pricing changes), `## Aggressive Overlay` (opt-in operator overlay shape), and `## Classifier-Confidence Stability Metric` (the concrete metric definition that P02's shadow-compare consumes — rolling per-class confidence-score variance threshold expressed as a numeric upper bound, plus minimum class-coverage count expressed as a numeric lower bound). The stability-metric section MUST give numeric values (not "TBD"). (FR-3 + FR-8 + #Q-3 deferred-to-plan-phase resolution.)
  - Check: `bash tools/verify/p01-model-routing-doc-shape.sh`

- `bash tools/verify/p01-phase-suite.sh` invokes all six P01 sub-gates (d-a4-timeline, classifier-determinism, classifier-perf-and-network, classifier-ground-truth, routing-table-shape, doctor-config-check, model-routing-doc-shape) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p01-phase-suite.sh pass=N fail=M` on a single line before exit. (Phase-close aggregator gate — same pattern as P00.)
  - Check: `bash tools/verify/p01-phase-suite.sh`

### Artifacts

- `tools/verify/p01-d-a4-timeline.sh` (min 35 lines, contains "labels.yml", contains "classify-task.sh", contains "git log", contains "SUMMARY:") — create
- `scripts/dispatch/classify-task.sh` (min 120 lines, contains "character=", contains "confidence=", contains "mechanical", contains "standard", contains "novel", contains "high", contains "medium", contains "low") — create
- `tools/verify/p01-classifier-determinism.sh` (min 30 lines, contains "classify-task.sh", contains "diff", contains "SUMMARY:") — create
- `tools/verify/p01-classifier-perf-and-network.sh` (min 40 lines, contains "classify-task.sh", contains "curl", contains "wget", contains "100", contains "SUMMARY:") — create
- `tools/verify/p01-classifier-ground-truth.sh` (min 50 lines, contains "labels.yml", contains "classify-task.sh", contains "85", contains "SUMMARY:") — create
- `templates/model-routing.yml` (min 60 lines, contains "routing:", contains "resolution:", contains "cost_rates:", contains "mechanical", contains "standard", contains "novel", contains "fast", contains "balanced", contains "smart", contains "claude-code") — create
- `tools/verify/p01-routing-table-shape.sh` (min 50 lines, contains "model-routing.yml", contains "routing:", contains "resolution:", contains "cost_rates:", contains "SUMMARY:") — create
- `references/model-routing.md` (min 80 lines, contains "## Routing Table", contains "## Per-Runtime Resolution", contains "## Cost Rates SSOT", contains "## Aggressive Overlay", contains "## Classifier-Confidence Stability Metric", contains "rolling", contains "variance", contains "coverage") — create
- `tools/verify/p01-model-routing-doc-shape.sh` (min 35 lines, contains "model-routing.md", contains "Classifier-Confidence Stability", contains "SUMMARY:") — create
- `tools/verify/p01-doctor-config-check.sh` (min 40 lines, contains "run-doctor.sh", contains "config-check", contains "model-routing.yml", contains "SUMMARY:") — create
- `tools/verify/p01-phase-suite.sh` (min 35 lines, contains "p01-d-a4-timeline", contains "p01-classifier-determinism", contains "p01-classifier-perf-and-network", contains "p01-classifier-ground-truth", contains "p01-routing-table-shape", contains "p01-doctor-config-check", contains "p01-model-routing-doc-shape", contains "SUMMARY:") — create
- `scripts/diagnostics/run-doctor.sh` (modify — extend the existing `--config-check` branch to validate `templates/model-routing.yml` per the routing-table-shape contract; emit file + line on malformation; preserve existing flag semantics for non-routing checks) — modify

### Key Links

- `specs/032-adaptive-model-selection/spec.md` → `scripts/dispatch/classify-task.sh` (FR-1 names the script + interface; FR-2 enumerates the heuristic input set)
- `specs/032-adaptive-model-selection/spec.md` → `templates/model-routing.yml` (FR-3 + D-A6 name the routing table + cost_rates section; CON-3 mandates the symbolic-tier interface)
- `.orchestrator/milestones/M030/M030-CONTEXT.md` → `references/model-routing.md` (D-A1 makes the classifier-confidence stability metric load-bearing for Principle II; D-A6 names the cost_rates: SSOT + operator update obligation)
- `tests/fixtures/m030-classifier-corpus/labels.yml` → `scripts/dispatch/classify-task.sh` (SC-10 ≥85% agreement check ties classifier output to ground-truth labels — D-A4 timeline ordering is the precondition)
- `tools/verify/p01-phase-suite.sh` → `tools/verify/p01-d-a4-timeline.sh` (suite invokes timeline gate)
- `tools/verify/p01-phase-suite.sh` → `tools/verify/p01-classifier-ground-truth.sh` (suite invokes SC-10 agreement gate)
- `tools/verify/p01-phase-suite.sh` → `tools/verify/p01-doctor-config-check.sh` (suite invokes routing-table closure gate)
- `references/model-routing.md` → `templates/model-routing.yml` (operator docs reference the SSOT file)

## Tasks

### T01: D-A4 timeline-graduation verifier + P00 phase-suite re-run

See `tasks/T01-d-a4-timeline-graduation-PLAN.md`.

This task ships **before** any work on `scripts/dispatch/classify-task.sh` so that D-A4 independence-by-construction is preserved across the P00 → P01 boundary. T01 authors `tools/verify/p01-d-a4-timeline.sh` (which graduates the P00 absence-check to a `git log` ordering check that activates once classify-task.sh ships) and confirms via the existing `tools/verify/p00-d-a4-independence.sh` that classify-task.sh STILL does not exist on disk at T01's start. T01 ends with the verifier in place and the absence-by-construction property still holding — the next task (T02) will create classify-task.sh, at which point T01's verifier graduates automatically to the post-classifier git-log mode.

### T02: Classifier script + determinism + perf/network + ground-truth verifiers

See `tasks/T02-classifier-script-PLAN.md`.

T02 authors `scripts/dispatch/classify-task.sh` (FR-1 + FR-2 heuristic table) plus four co-scheduled verifiers: determinism (SC-1 byte-equality across two runs), perf-and-network (<100ms wall-clock + grep-clean of curl/wget/dispatch-adapter invocations), ground-truth (≥85% agreement against the P00 40-entry corpus, SC-10), and an internal sanity script that wraps `classify-task.sh` with a wall-clock timer. T02 is the high-risk core primitive. The first commit of `classify-task.sh` MUST land AFTER `tools/verify/p01-d-a4-timeline.sh` is on disk (T01 produced) so the timeline graduation is mechanically asserted by the verifier on its first git-log evaluation.

### T03: Routing table + cost_rates SSOT + operator docs + classifier-confidence stability metric

See `tasks/T03-routing-table-and-docs-PLAN.md`.

T03 authors `templates/model-routing.yml` (FR-3 + D-A6 + CON-3) with three required sections (`routing:`, `resolution:`, `cost_rates:`) plus the routing-table-shape verifier that checks symbolic-tier closure. T03 also authors `references/model-routing.md` (operator docs) including the section that resolves spec #Q-3 with concrete numeric values: the **classifier-confidence stability metric** P02's `shadow-compare.sh` consumes — rolling per-class confidence-score variance threshold + minimum class-coverage count, both expressed as numbers, not "TBD". T03 ships the model-routing-doc-shape verifier alongside the docs.

### T04: doctor.sh --config-check routing-table validation + P01 phase-suite gate

See `tasks/T04-doctor-config-check-and-suite-PLAN.md`.

T04 extends `scripts/diagnostics/run-doctor.sh`'s existing `--config-check` flag to validate `templates/model-routing.yml` per the routing-table-shape contract — exits 0 on well-formed input, exits 1 on a malformed fixture with stdout naming both the offending file path and the offending line number (SC-9). T04 authors the doctor-config-check verifier that exercises both the well-formed and malformed paths, plus the P01 phase-suite aggregator (`tools/verify/p01-phase-suite.sh`) that invokes all six P01 sub-gates in straight-line bash. T04 closes the phase: when the suite exits 0 with `SUMMARY: p01-phase-suite.sh pass=7 fail=0`, P01 is ready for `orchestrator:verify` and downstream phase P02.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01's verifier (`p01-d-a4-timeline.sh`) MUST land before T02 commits `classify-task.sh` so the timeline-ordering proof exists at the moment classify-task.sh first appears. T03's routing-table consumes nothing from T02's classifier (the classifier emits symbolic `character` only; tier resolution is a separate downstream step in `dispatch-interface.sh`, deferred to P02), but T03 must wait for T02 to close because T03's `references/model-routing.md` cross-references `classify-task.sh` and the classifier-confidence stability metric definition is the contract P02 will consume from a shipped classifier output shape. T04 depends on T03's `templates/model-routing.yml` because the doctor-config-check verifier exercises that file.

Parallelism opportunity: T03 could in principle start as soon as T01 closes (it does not technically read T02's deliverables, only references their interface), but the shared narrative cohesion of the model-routing.md file — which discusses both the classifier and the routing table — argues for sequencing T03 after T02 to avoid a disjointed authoring split. The risk of parallel-T02-and-T03 is low; if `auto` chooses to schedule them in parallel after T01, plan-phase does not forbid it, but this plan documents the linear order as the recommended sequence.

## Files Likely Touched

- `scripts/dispatch/classify-task.sh` (create)
- `templates/model-routing.yml` (create)
- `references/model-routing.md` (create)
- `scripts/diagnostics/run-doctor.sh` (modify)
- `tools/verify/p01-d-a4-timeline.sh` (create)
- `tools/verify/p01-classifier-determinism.sh` (create)
- `tools/verify/p01-classifier-perf-and-network.sh` (create)
- `tools/verify/p01-classifier-ground-truth.sh` (create)
- `tools/verify/p01-routing-table-shape.sh` (create)
- `tools/verify/p01-doctor-config-check.sh` (create)
- `tools/verify/p01-model-routing-doc-shape.sh` (create)
- `tools/verify/p01-phase-suite.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-4]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->
