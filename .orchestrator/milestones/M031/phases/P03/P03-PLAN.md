---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M031"
goal: "Ship the universal entry surface `commands/do.md` (FR-10, AD-6 — registered as `orchestrator:do <task>` for the CC launch posture; verbless `orchestrator <task>` reserved for post-M009 runtime parity) backed by `scripts/intake/do-entry.sh` that consumes the existing M024 input-shape classifier (`scripts/intake/shape-detect.sh`) verdict + `shape_classification=high|low` confidence, gates routing on `entry_routing_confidence_floor` (FR-11; numeric-mapped from the M024 high|low enum — high→1.0, low→0.5; A-2 closure), fast-paths high-confidence Tier A degenerate verdicts (`idea`, short `paragraph`) with one Quick-profile dispatch + an `doing: <task> — knowledge: N MEMs / X tokens` stderr summary line read from the AD-11 `--meta-out` sidecar (FR-12), hands `tier_a_plus` verdicts to the P02 router (FR-7 chain) without re-implementing the Tier A+ flow (CON-3 / AD-2), passes Tier B/C verdicts (`fragment`, long `paragraph`, `spec`) through to the existing `orchestrator:specify` / `orchestrator:evaluate` surface unchanged (FR-13), prompts the operator with an explicit Tier A vs Tier B question on low-confidence verdicts and records the chosen shape in the dispatch JSONL `unit_close` record (FR-11 fallback; SC-8); ship the SC-7 trivial-path acceptance test + SC-8 low-confidence prompt test + four shape verifiers + the P03 phase-suite aggregator + the SC-12 scope-guard inheriting the P02 dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) and the MEM `hit_count`-only carve-out verbatim."
demo_sentence: "An operator runs `bash scripts/intake/do-entry.sh --task 'fix typo in foo.md' --dispatch-stub tests/m031-acceptance/fixtures/do-entry-stub.sh` and observes exactly one stderr summary line of shape `doing: fix typo in foo.md — knowledge: N MEMs / X tokens`, exactly one dispatch fired (counted by stub log lines), zero approval prompts, and exit 0; runs `bash scripts/intake/do-entry.sh --task '<62-word feature request>' --dispatch-stub <stub> --yes` against a `tier_a_plus` verdict and observes the run hands off to `route-to-dispatch.sh --verdict tier_a_plus` producing exactly three dispatches (research / plan / build) with one `research: <path>` audit line on stderr; runs `bash scripts/intake/do-entry.sh --task '<82-word fragment>' --dispatch-stub <stub>` and observes the run reports passthrough to `orchestrator:specify` and exits 0 without firing a dispatch from the entry script; runs `bash scripts/intake/do-entry.sh --task '<28-word borderline-low>' --no-prompt-mode A --dispatch-stub <stub>` and observes the explicit Tier A vs Tier B prompt was emitted, the chosen shape recorded in the captured JSONL `unit_close` record, and exit 0; runs `bash tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7) and observes `RESULT: SC-7 pass`; runs `bash tests/m031-acceptance/test-universal-entry-lowconf.sh` (SC-8) and observes `RESULT: SC-8 pass`; runs `bash tools/verify/m031-p03-phase-suite.sh` and observes `SUMMARY: m031-p03-phase-suite.sh pass=N fail=0`; runs `bash tools/verify/m031-p03-scope-guard.sh` and observes `SUMMARY: m031-p03-scope-guard.sh pass=N fail=0 block_list_violations=0`."
risk: "medium"
depends_on: ["P01", "P02"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ per
     M032 Finding A. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task (plan-time discipline
     rule 2). Namespacing: `m031-p03-*` prefix avoids collision with
     M030's `p02-*` and M031's `m031-p01-*` / `m031-p02-*` verifiers in
     the shared tools/verify/ tree. -->

### Truths

- `commands/do.md` exists with YAML frontmatter (`description: "Use when ..."`) and a body documenting the universal entry skill registered as `orchestrator:do <task>` (per AD-6 — verbless `orchestrator <task>` reserved for post-M009 runtime parity; CC at launch ships the `do` form because CC slash-commands are verb-prefixed). The body MUST describe the four routing branches by name (`tier_a_plus` → P02 router; high-confidence Tier A degenerate → Quick-profile single dispatch; Tier B/C → passthrough to `orchestrator:specify` / `orchestrator:evaluate`; low-confidence → explicit Tier A vs Tier B prompt) and reference the backing script `scripts/intake/do-entry.sh` in a Referenced Scripts section per MEM012.
  - Check: `bash tools/verify/m031-p03-do-md-shape.sh`

- `scripts/intake/do-entry.sh` exists, is executable, and implements the FR-10 / FR-11 / FR-12 / FR-13 contract: (a) accepts `--task <description>` (required), `--yes`, `--no-prompt-mode <A|B|C>` (test-only, mirroring the P02 prompt helper bypass), `--dispatch-stub <script>` (test-only seam), `--scratch-root <dir>` (test-only override of `.orchestrator/tier-a-plus/`), `--config <path>` (test-only override of `.orchestrator/config.yml`); (b) invokes `bash scripts/intake/shape-detect.sh --input <task>` and parses `input_shape=<verdict>` + `shape_classification=<high|low>`; (c) maps `high` → `1.0` and `low` → `0.5` and compares against `entry_routing_confidence_floor` from active config (P00 default `0.7`); (d) routes per branch table: `tier_a_plus` → exec `route-to-dispatch.sh --verdict tier_a_plus --task <desc> [--yes] [--dispatch-stub <stub>] [--scratch-root <dir>]`; high-confidence `idea` or `paragraph` → fast-path single dispatch (Quick profile); `fragment` / `spec` / long `paragraph` (Tier B/C) → emit one stderr line `route=tier_bc passthrough=orchestrator:specify` and exit 0 without firing a dispatch from the entry script; low-confidence (numeric < floor) → emit explicit Tier A vs Tier B prompt and record the chosen shape in the captured JSONL `unit_close` record. Bash 3.2 compatible (MEM001).
  - Check: `bash tools/verify/m031-p03-do-entry-shape.sh`

- For the high-confidence Tier A degenerate fast-path branch, `scripts/intake/do-entry.sh` invokes `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <task-plan-path> --out <payload-path> --meta-out <sidecar-path>` (P01 direct-mode driver shape) AND emits exactly one stderr line of shape `doing: <task> — knowledge: <N> MEMs / <X> tokens` where `<N>` is the `mem_count` field from the AD-11 sidecar JSON and `<X>` is the `total_tokens` field (FR-12). Zero approval prompts on the fast-path. The dispatch surface invocation seam is `--dispatch-stub` for testing — when the stub flag is present the entry script invokes the stub script with positional arguments `(branch=tier_a_degenerate, task, payload-path, meta-out-path)` and stops; when the stub flag is absent the production path invokes the agent-runtime handoff (per MEM018 — the agent IS the adapter; the entry script writes the payload + sidecar to disk and emits the summary line, then returns control). The fast-path emits ZERO scaffold-placeholder marker bracket-TODO byte patterns on stdout/stderr (CON-7 / D020).
  - Check: `bash tools/verify/m031-p03-fastpath-shape.sh`

- `scripts/intake/do-entry.sh` does NOT acquire any auto-loop lock, does NOT write any `.orchestrator/milestones/M###/` scaffolding, and does NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` on any branch (CON-4 / DC-4). The Tier B/C passthrough branch reports the passthrough surface name (`orchestrator:specify` for `fragment` / `spec` / long `paragraph`; `orchestrator:evaluate` if the operator selected Tier B in the low-confidence prompt) on stderr and exits 0; it does NOT invoke the downstream command directly (the operator reads the report and runs the named command in their next shell turn — preserves the one-shot-per-command discipline of NG-6).
  - Check: `bash tools/verify/m031-p03-passthrough-shape.sh`

- `tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7) exists, is executable, and exits 0. Asserts: invoking `bash scripts/intake/do-entry.sh --task 'fix typo in foo.md' --dispatch-stub <stub> --scratch-root <tmp>` against the trivial fixture produces (a) exactly one stderr line matching `doing: <task> — knowledge: <N> MEMs / <X> tokens` (literal regex `^doing: .* — knowledge: [0-9]+ MEMs / [0-9]+ tokens$`); (b) exactly one dispatch fired (counted by stub-log line count); (c) the dispatch payload manifest at `<payload-path>` exists and is non-empty (knowledge injection observable); (d) zero approval prompts (no `(y) ... (n) ... (c)` pattern in captured stderr); (e) exit 0. Emits `RESULT: SC-7 pass` on success.
  - Check: `bash tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`

- `tests/m031-acceptance/test-universal-entry-lowconf.sh` (SC-8) exists, is executable, and exits 0. Asserts: invoking `bash scripts/intake/do-entry.sh --task '<low-confidence-fixture>' --no-prompt-mode A --dispatch-stub <stub> --scratch-root <tmp> --config <test-config>` produces (a) the explicit Tier A vs Tier B prompt rendered on stderr (literal substrings `Tier A` AND `Tier B` AND a question token like `?`); (b) the captured JSONL `unit_close` record (read from `ORCH_DO_ENTRY_LOG` test-only env var pointing at a tmp path) contains the `chosen_shape: A` field reflecting the operator selection; (c) when `--no-prompt-mode B` is exercised in a second sub-case, the captured record contains `chosen_shape: B` and the entry reports passthrough to `orchestrator:specify`; (d) exit 0 in both sub-cases. Emits `RESULT: SC-8 pass` on success.
  - Check: `bash tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh`

- `tools/verify/m031-p03-phase-suite.sh` exists, is executable, invokes every P03 sub-gate in T01 → T02 → T03 dependency order via straight-line `bash <verifier>` invocations (AD-19 — no array loops, no compound chains, no eval), and emits a single final stdout line `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M`. Exits 0 iff every sub-gate exits 0. The aggregator does NOT short-circuit on a sub-gate failure (all gates run regardless so the operator sees the full report). Sub-gate ordering: do-md-shape, do-entry-shape, fastpath-shape, passthrough-shape, test-universal-entry-trivial-shape, test-universal-entry-lowconf-shape, scope-guard (last gate per the P01/P02 convention).
  - Check: `bash tools/verify/m031-p03-phase-suite.sh`

- `tools/verify/m031-p03-scope-guard.sh` exists, is executable, and asserts the P03 diff (working tree vs HEAD) does NOT touch any path under the SC-12 block-list (`knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`). The MEM `hit_count`-only carve-out is preserved verbatim from P01/P02 (`^[+-]hit_count: [0-9]+$` line-content check on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths). The dual-prefix permissive carve-out is preserved verbatim from P02 (`.orchestrator/observability/` AND `.orchestrator/tier-a-plus/` are permissive prefixes — diffs under these paths are not block-list violations). Allow-list reflects the P03 "Files Likely Touched" surface plus phase/task plan + summary paths.
  - Check: `bash tools/verify/m031-p03-scope-guard.sh`

### Artifacts

- `commands/do.md` (min 60 lines, contains "orchestrator:do", contains "tier_a_plus", contains "do-entry.sh", contains "Referenced Scripts") — create
- `scripts/intake/do-entry.sh` (min 200 lines, contains "tier_a_plus", contains "shape-detect.sh", contains "route-to-dispatch.sh", contains "build-context.sh", contains "entry_routing_confidence_floor", contains "doing:", contains "MEMs", contains "tokens", contains "chosen_shape") — create
- `tests/m031-acceptance/fixtures/do-entry-stub.sh` (min 15 lines, contains "branch=", contains "task=") — create
- `tests/m031-acceptance/fixtures/do-entry-trivial-input.txt` (min 1 lines, exists with ≤ 10 word body) — create
- `tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt` (min 1 lines, exists with body in word-count band that the M024 classifier emits at `low` confidence) — create
- `tests/m031-acceptance/test-universal-entry-trivial.sh` (min 60 lines, contains "SC-7", contains "doing:", contains "MEMs", contains "tokens", contains "do-entry.sh") — create
- `tests/m031-acceptance/test-universal-entry-lowconf.sh` (min 60 lines, contains "SC-8", contains "Tier A", contains "Tier B", contains "chosen_shape", contains "do-entry.sh") — create
- `tools/verify/m031-p03-do-md-shape.sh` (min 30 lines, contains "commands/do.md", contains "orchestrator:do", contains "tier_a_plus") — create
- `tools/verify/m031-p03-do-entry-shape.sh` (min 50 lines, contains "do-entry.sh", contains "shape-detect.sh", contains "route-to-dispatch.sh", contains "entry_routing_confidence_floor") — create
- `tools/verify/m031-p03-fastpath-shape.sh` (min 35 lines, contains "do-entry.sh", contains "build-context.sh", contains "doing:", contains "mem_count", contains "total_tokens") — create
- `tools/verify/m031-p03-passthrough-shape.sh` (min 30 lines, contains "do-entry.sh", contains "orchestrator:specify", contains "orchestrator:evaluate") — create
- `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh` (min 25 lines, contains "test-universal-entry-trivial.sh", contains "SC-7") — create
- `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` (min 25 lines, contains "test-universal-entry-lowconf.sh", contains "SC-8") — create
- `tools/verify/m031-p03-phase-suite.sh` (min 70 lines, contains "SUMMARY:", contains "m031-p03-do-md-shape", contains "m031-p03-do-entry-shape", contains "m031-p03-fastpath-shape", contains "m031-p03-passthrough-shape", contains "m031-p03-scope-guard", contains "m031-p03-phase-suite") — create
- `tools/verify/m031-p03-scope-guard.sh` (min 100 lines, contains "knowledge/", contains "scripts/cost", contains "scripts/dispatch/adapters/router", contains "scripts/auto/loop", contains "SC-12", contains "mem-hitcount-only", contains "tier-a-plus", contains "observability") — create

### Key Links

<!-- Each declared key-link points to a file that EXISTS POST-PHASE under
     the artifact list above (P02/T05 lesson: links pointing at literal
     filenames must be discoverable in the producing file via grep on
     basename — co-author a `# Key links (M031/P03):` comment block in
     scripts that need to surface their cross-references for must-have
     verification, mirroring the P01 build-context.sh and P02
     route-to-dispatch.sh remediation pattern at commit 7624397). -->

- `commands/do.md` → `scripts/intake/do-entry.sh` (the skill's body references the backing script in a Referenced Scripts section per MEM012)
- `commands/do.md` → `scripts/intake/shape-detect.sh` (the skill's body explains that classifier verdicts drive routing)
- `commands/do.md` → `scripts/intake/route-to-dispatch.sh` (the skill's body explains the `tier_a_plus` handoff to the P02 router)
- `scripts/intake/do-entry.sh` → `scripts/intake/shape-detect.sh` (entry invokes shape-detect to obtain the verdict)
- `scripts/intake/do-entry.sh` → `scripts/intake/route-to-dispatch.sh` (entry hands off `tier_a_plus` verdicts to the P02 router)
- `scripts/intake/do-entry.sh` → `scripts/dispatch/build-context.sh` (entry invokes Quick-profile build-context for the Tier A degenerate fast-path)
- `scripts/intake/do-entry.sh` → `templates/orchestrator-config-default.yml` (entry reads `entry_routing_confidence_floor` knob via direct YAML grep — same precedent as the P02 prompt helper for `tier_a_plus_prompt_summary_lines`)
- `tests/m031-acceptance/test-universal-entry-trivial.sh` → `scripts/intake/do-entry.sh` (SC-7 invokes the entry script and asserts the FR-12 stderr summary shape)
- `tests/m031-acceptance/test-universal-entry-lowconf.sh` → `scripts/intake/do-entry.sh` (SC-8 invokes the entry script with `--no-prompt-mode` and asserts the FR-11 fallback prompt + chosen_shape recording)
- `tools/verify/m031-p03-phase-suite.sh` → `tools/verify/m031-p03-do-md-shape.sh` (suite invokes do-md shape gate)
- `tools/verify/m031-p03-phase-suite.sh` → `tools/verify/m031-p03-do-entry-shape.sh` (suite invokes do-entry shape gate)
- `tools/verify/m031-p03-phase-suite.sh` → `tools/verify/m031-p03-fastpath-shape.sh` (suite invokes fastpath shape gate)
- `tools/verify/m031-p03-phase-suite.sh` → `tools/verify/m031-p03-passthrough-shape.sh` (suite invokes passthrough shape gate)
- `tools/verify/m031-p03-phase-suite.sh` → `tools/verify/m031-p03-scope-guard.sh` (suite invokes the scope-guard as the last gate)

## Tasks

### T01: `commands/do.md` skill + `scripts/intake/do-entry.sh` entry script (FR-10, FR-11, FR-12, FR-13)

See `tasks/T01-do-md-and-entry-script-PLAN.md`.

T01 ships the universal entry's authoring surface and the backing entry script. `commands/do.md` is the new top-level command document registered as `orchestrator:do <task>` per AD-6 (verbless `orchestrator <task>` deferred to M009). `scripts/intake/do-entry.sh` is the bash 3.2 driver that invokes `shape-detect.sh`, parses the verdict + confidence, maps `high|low` to numeric (1.0 / 0.5) for comparison against the `entry_routing_confidence_floor` knob (P00 default 0.7), and routes per the four-branch table. The fast-path branch invokes `build-context.sh --profile=quick --task-plan <task-plan> --out <payload> --meta-out <sidecar>` (P01 direct-mode driver), reads the AD-11 sidecar's `mem_count` + `total_tokens` fields, and emits the FR-12 stderr summary line. The Tier A+ branch execs the P02 `route-to-dispatch.sh --verdict tier_a_plus`. The Tier B/C branch reports passthrough on stderr and exits 0 without firing a dispatch. The low-confidence branch prompts the operator and records the chosen shape in the JSONL `unit_close` record (`ORCH_DO_ENTRY_LOG` test-only override). T01 ships four shape verifiers under `tools/verify/m031-p03-*.sh`: do-md-shape, do-entry-shape, fastpath-shape, passthrough-shape.

### T02: SC-7 trivial-path acceptance test + SC-8 low-confidence prompt acceptance test + fixtures

See `tasks/T02-acceptance-tests-PLAN.md`.

T02 ships `tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7) asserting the FR-12 fast-path emits exactly one `doing: <task> — knowledge: <N> MEMs / <X> tokens` stderr line, exactly one dispatch fired, payload manifest non-empty, zero approval prompts. T02 ships `tests/m031-acceptance/test-universal-entry-lowconf.sh` (SC-8) asserting the FR-11 fallback prompt fires when classifier confidence is below the floor, with both `--no-prompt-mode A` and `--no-prompt-mode B` sub-cases verifying the `chosen_shape` field lands in the captured JSONL `unit_close` record. T02 ships fixtures `tests/m031-acceptance/fixtures/do-entry-stub.sh` (canned dispatch stub mirroring the P02 SC-6 stub shape), `do-entry-trivial-input.txt` (a ≤10-word `idea`-shape input the M024 classifier emits as `idea` + `high`), and `do-entry-lowconf-input.txt` (an input the M024 classifier emits at `low` confidence — empirically the boundary bands `8-10` words for `idea` or `32` / `78`-word edge of `tier_a_plus`). T02 ships two shape verifiers: m031-p03-test-universal-entry-trivial-shape.sh and m031-p03-test-universal-entry-lowconf-shape.sh.

### T03: P03 phase-suite aggregator + SC-12 scope-guard for P03

See `tasks/T03-phase-suite-and-scope-guard-PLAN.md`.

T03 ships `tools/verify/m031-p03-phase-suite.sh` chaining every P03 sub-gate (in T01 → T02 dependency order) via straight-line `bash <verifier>` invocations (AD-19 compliant — no array loops, no compound chains). The suite emits a single final `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M` line and exits 0 iff every sub-gate exits 0; gates do NOT short-circuit on failure. T03 ships `tools/verify/m031-p03-scope-guard.sh` enforcing the SC-12 block-list (`knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`). The MEM `hit_count`-only carve-out from the P01/P02 scope-guard is preserved verbatim. The dual-prefix permissive carve-out from P02 (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) is preserved verbatim. The allow-list reflects the P03 "Files Likely Touched" surface plus phase/task plan + summary paths. The scope-guard is the last gate in the phase-suite (so a clean diff is required for green).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03
```

Strict linear chain. T01 ships `commands/do.md` + `scripts/intake/do-entry.sh` + four shape verifiers (do-md-shape / do-entry-shape / fastpath-shape / passthrough-shape). T02 depends on T01 because the SC-7 + SC-8 tests invoke the T01 entry script; T02 ships the two SC scripts + their fixtures + the two test-shape verifiers. T03 depends on T02 because the phase-suite aggregator invokes every shape verifier shipped alongside the deliverables in T01–T02, and the scope-guard's allow-list reflects the post-T02 file inventory.

## Files Likely Touched

- `commands/do.md` (create)
- `scripts/intake/do-entry.sh` (create)
- `tests/m031-acceptance/fixtures/do-entry-stub.sh` (create)
- `tests/m031-acceptance/fixtures/do-entry-trivial-input.txt` (create)
- `tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt` (create)
- `tests/m031-acceptance/test-universal-entry-trivial.sh` (create)
- `tests/m031-acceptance/test-universal-entry-lowconf.sh` (create)
- `tools/verify/m031-p03-do-md-shape.sh` (create)
- `tools/verify/m031-p03-do-entry-shape.sh` (create)
- `tools/verify/m031-p03-fastpath-shape.sh` (create)
- `tools/verify/m031-p03-passthrough-shape.sh` (create)
- `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh` (create)
- `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` (create)
- `tools/verify/m031-p03-phase-suite.sh` (create)
- `tools/verify/m031-p03-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run scratch files
     written under .orchestrator/tier-a-plus/<task-slug>/ during
     integration smoke runs land under the .orchestrator/tier-a-plus/
     permissive prefix (carve-out inherited from P02 scope-guard).
     Test-run JSONL records written via ORCH_DO_ENTRY_LOG land at
     paths the test controls (typically /tmp); they are out of the
     scope-guard's purview because /tmp is outside the repo tree. -->
