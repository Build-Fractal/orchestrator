---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M024"
goal: "Spec-path backward compat + M014→M024 manifest read direction"
demo_sentence: "Running `evaluate <existing-spec-path>` produces both the legacy evaluation output (byte-compatible vs a captured pre-M024 baseline) AND a `proposal.md` with `input_shape: spec` and deep (non-stub) axes derived from the spec; an M014 interim manifest is read live (not via the fixture) by `scripts/intake/m014-manifest-read.sh` and yields the same proposal frontmatter superset."
risk: "medium"
depends_on: ["P01"]
---

## M014/extended Shipping Probe (Cross-Cutting #DQ-2)

Plan-phase-time probe (informational — the live invoke-time probe lives inside `scripts/intake/m014-manifest-read.sh` per the P03 precedent for AD-19 / #DQ-2 invoke-time gating):

```
test -f scripts/specify/specify.sh
test -f templates/spec-template.md
```

Both succeed at plan-phase time (specify.sh present; spec-template.md ships the M014 interim-manifest frontmatter contract: `schema_version`, `type`, `feature_slug`, `created_at`, `status`, `milestone`). **Disposition**: M014/extended **has shipped** — P02 wires the live read direction (AD-4 direction `a`) against the M014 interim manifest produced by `scripts/specify/specify.sh` scaffold pass + `templates/spec-template.md`. The P01 fixture (`tests/fixtures/m014-interim-manifest-keys.txt`) stays in place as the contracted source of truth and is asserted to be a **strict subset** of the keys the live reader emits — when the live reader returns a richer key-set, the fixture is updated by the same task that observes the drift.

If the probe ever fails on a future re-plan (worktree without M014 staged), the live-read task MUST emit a clearly-marked stub message naming `templates/spec-template.md` as the unshipped target and exit non-zero — same shape as P03's #DQ-2 invoke-time stub (see `scripts/intake/route-to-specify.sh`).

## Must-Haves

### Truths

- The spec-shape classifier, given a spec path with a valid `type: feature-spec` frontmatter, populates the four classifiable axes with non-stub values derived from the spec body (scope_tier from existing tier-classification logic — chunks-first via `scripts/state/spec-metrics.sh` when chunks exist, raw-spec FR/AC/story counts otherwise; decomposition mapped from tier; recommended_command=`orchestrator:roadmap` per FR-6 legacy contract; design_gate / conversus_gate remain at P01 stubs in P02 scope — P04/P07 wire them). The P01-stub rationale string `P01 stub — deep classifier ships in a later phase.` no longer appears in `scope_tier` / `decomposition` / `recommended_command` rationale slots when input_shape=spec.
  - Check: `bash scripts/verify/m024-p02-spec-shape-classify.sh`
- The M014 manifest reader, given any path to a file or directory under `specs/<NNN>-<slug>/` whose `spec.md` carries the M014 interim-manifest frontmatter (`schema_version`, `type: feature-spec`, `feature_slug`, `created_at`, `status`, `milestone`), emits the six manifest key=value lines on stdout in the same order the fixture pins. The reader runs an invoke-time probe (`test -f templates/spec-template.md`) and exits non-zero with a stub message if the probe fails (#DQ-2 option `b`).
  - Check: `bash scripts/verify/m024-p02-m014-manifest-read.sh`
- The proposal frontmatter emitted from a spec-path input is a strict superset of the M014 manifest keys read live by `scripts/intake/m014-manifest-read.sh` (not via the fixture). The fixture stays in place but is asserted to equal the live reader's stdout key-list — when they drift, the fixture is updated by the same task that observes the drift.
  - Check: `bash scripts/verify/m024-p02-fixture-vs-live.sh`
- The pre-M024 evaluation output shape (the today-shape `metrics_source`, `story_count`, `requirement_count`, `acceptance_count` lines emitted by `commands/evaluate.md` consumers reading a spec) is byte-compatible vs the captured baseline fixture at `tests/fixtures/evaluate-pre-m024-baseline.txt`. The baseline is captured against an existing in-repo spec (e.g. `specs/023-github-native-integration/spec.md`) at P02 plan-phase time; P02's regression test re-runs the same metric-extraction path and `diff`s vs the baseline.
  - Check: `bash scripts/verify/m024-p02-evaluate-spec-backcompat.sh`
- The proposal emitter, given `--spec-path <p>` and no `--input`, populates the proposal body's `## Input Shape` section with a `spec` rationale citing the spec's slug + `metrics_source` + structural counts (instead of the P01 stub rationale).
  - Check: `bash scripts/verify/m024-p02-spec-rationale.sh`
- The two phase-level tests (`tests/test-evaluate-spec-backcompat.sh` and `tests/test-m014-manifest-read.sh`) plus the P02 suite all exit 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p02-suite.sh`
- All P02-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter on emit) and `/tmp` (test scratch).
  - Check: `bash scripts/verify/m024-p02-write-confinement.sh`

### Artifacts

- scripts/intake/spec-shape-classify.sh (min 80 lines, contains "feature-spec")
- scripts/intake/m014-manifest-read.sh (min 60 lines, contains "spec-template.md")
- tests/test-evaluate-spec-backcompat.sh (min 50 lines, contains "baseline")
- tests/test-m014-manifest-read.sh (min 50 lines, contains "manifest")
- tests/fixtures/evaluate-pre-m024-baseline.txt (min 4 lines, contains "metrics_source")
- scripts/verify/m024-p02-spec-shape-classify.sh (min 25 lines, contains "feature-spec")
- scripts/verify/m024-p02-m014-manifest-read.sh (min 25 lines, contains "manifest")
- scripts/verify/m024-p02-fixture-vs-live.sh (min 25 lines, contains "fixture")
- scripts/verify/m024-p02-evaluate-spec-backcompat.sh (min 25 lines, contains "baseline")
- scripts/verify/m024-p02-spec-rationale.sh (min 20 lines, contains "spec")
- scripts/verify/m024-p02-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p02-suite.sh (min 15 lines, contains "test-evaluate-spec-backcompat")

### Key Links

- scripts/intake/spec-shape-classify.sh → scripts/intake/proposal-emit.sh (classifier consumed by emitter when input_shape=spec)
- scripts/intake/spec-shape-classify.sh → scripts/state/spec-metrics.sh (chunks-first metric path, FR-6 legacy contract)
- scripts/intake/m014-manifest-read.sh → templates/spec-template.md (M014 interim-manifest schema source — read-only per AD-4 direction `a`)
- tests/test-m014-manifest-read.sh → scripts/intake/m014-manifest-read.sh (test exercises the live reader)
- tests/test-evaluate-spec-backcompat.sh → tests/fixtures/evaluate-pre-m024-baseline.txt (test diffs vs the pinned baseline)
- tests/test-evaluate-spec-backcompat.sh → scripts/intake/proposal-emit.sh (test invokes emitter with --spec-path)

## Tasks

### T01: Spec-shape classifier — replace P01 stubs for spec branch

See `tasks/T01-PLAN.md`. Authors `scripts/intake/spec-shape-classify.sh` — a pure classifier that, given `--spec-path <p>`, emits four `key=value` stdout lines (`scope_tier`, `decomposition`, `recommended_command`, `rationale_spec`) plus a body rationale. Tier derivation reuses the legacy `commands/evaluate.md` chunks-first / raw-spec metric path (calls `scripts/state/spec-metrics.sh` when chunks present; falls back to grep-based FR/AC/story counts when not). Tier→decomposition mapping: A→single-task, B→single-phase, C→milestone-with-phases. Recommended command per FR-6 is always `orchestrator:roadmap` for spec-path inputs (the legacy entry-point per byte-compat invariant). Wires into `scripts/intake/proposal-emit.sh` so spec-shape inputs no longer carry the P01-stub rationale on the three classifiable axes. Pure shell, AD-19 single-script-file shape.

### T02: M014 manifest live reader (M014→M024 handshake direction `a`)

See `tasks/T02-PLAN.md`. Authors `scripts/intake/m014-manifest-read.sh` — given `--spec-path <p>` (or `--specs-dir <d>` to pick the most-recently-mtime'd spec), runs an invoke-time probe (`test -f templates/spec-template.md`) and either reads the spec frontmatter and emits six key=value lines (`schema_version=…`, `type=…`, `feature_slug=…`, `created_at=…`, `status=…`, `milestone=…`) on stdout, or emits a clearly-marked stub message naming `templates/spec-template.md` as the unshipped target and exits non-zero. The reader is the live AD-4 direction `a` source-of-truth; the P01 fixture (`tests/fixtures/m014-interim-manifest-keys.txt`) becomes a fallback contracted snapshot, asserted equal to the live reader's keys by T04's `m024-p02-fixture-vs-live.sh` verify. Pure shell; no disk writes; pure stdout.

### T03: Backcompat baseline capture + spec-path emitter rationale wiring

See `tasks/T03-PLAN.md`. Two deliverables: (a) capture `tests/fixtures/evaluate-pre-m024-baseline.txt` — the today-shape evaluation metric output for an existing in-repo spec (`specs/023-github-native-integration/spec.md`), produced by re-running the same chunks-first / raw-spec metric path that `commands/evaluate.md` documents (`scripts/state/spec-metrics.sh` when chunks exist; raw FR/AC/story grep counts otherwise). The fixture format is one `key=value` line per metric (`metrics_source`, `story_count`, `requirement_count`, `acceptance_count`). (b) Wire the proposal emitter's spec-shape body rationale: when `input_shape=spec` AND T01's classifier produced a spec rationale, swap that rationale into `rationale_input_shape` / `evidence_input_shape` (the P01 stub sits at the input_shape rationale slot for spec inputs today; T01 only touched scope_tier/decomposition/recommended_command). The wiring snippet mirrors P03/T01's PARA_AXES_DONE sentinel pattern with a SPEC_AXES_DONE flag. Pure shell; SB-3 write-confined to `.orchestrator/intake/<id>/`.

### T04: Two phase tests + per-task verify scripts + suite + write-confinement

See `tasks/T04-PLAN.md`. Authors `tests/test-evaluate-spec-backcompat.sh` (re-runs the metric extraction path against the same in-repo spec used to capture the baseline; `diff`s against `tests/fixtures/evaluate-pre-m024-baseline.txt`; asserts byte-identical match) and `tests/test-m014-manifest-read.sh` (invokes the live reader against an in-repo spec, asserts the six manifest keys are present in stdout in the pinned order). Authors all P02 verify scripts (`m024-p02-spec-shape-classify.sh`, `m024-p02-m014-manifest-read.sh`, `m024-p02-fixture-vs-live.sh`, `m024-p02-evaluate-spec-backcompat.sh`, `m024-p02-spec-rationale.sh`, `m024-p02-write-confinement.sh`, `m024-p02-suite.sh`). MEM002 conventions throughout: parallel arrays, structured `PASS:`/`FAIL:` summary. AD-19 single-script-file shape on every external invocation.

## Task Dependencies

```
T01 → T03    (T03 wires the emitter rationale slot that T01 leaves at P01-stub)
T02 → T04    (T04's fixture-vs-live verify exercises T02's live reader)
T01 + T02 + T03 → T04
```

T01 (spec-shape classifier) replaces P01 stubs for the spec branch. T02 (live M014 reader) wires AD-4 direction `a` and is file-disjoint from T01 — they can run in parallel. T03 (baseline capture + rationale slot wiring) consumes T01's output to finish the spec-shape proposal body. T04 (tests + suite + verifies) exercises everything end-to-end.

## Files Likely Touched

- scripts/intake/spec-shape-classify.sh (create)
- scripts/intake/m014-manifest-read.sh (create)
- scripts/intake/proposal-emit.sh (modify — wire classifier on spec branch + spec rationale slot)
- tests/test-evaluate-spec-backcompat.sh (create)
- tests/test-m014-manifest-read.sh (create)
- tests/fixtures/evaluate-pre-m024-baseline.txt (create)
- scripts/verify/m024-p02-spec-shape-classify.sh (create)
- scripts/verify/m024-p02-m014-manifest-read.sh (create)
- scripts/verify/m024-p02-fixture-vs-live.sh (create)
- scripts/verify/m024-p02-evaluate-spec-backcompat.sh (create)
- scripts/verify/m024-p02-spec-rationale.sh (create)
- scripts/verify/m024-p02-write-confinement.sh (create)
- scripts/verify/m024-p02-suite.sh (create)
