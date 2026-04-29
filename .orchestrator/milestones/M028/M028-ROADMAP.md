---
schema_version: "1.0"
type: roadmap
milestone: "M028"
feature_ref: "031-autonomous-hardening-v3"
feature_spec: "specs/031-autonomous-hardening-v3/spec.md"
vision: "Close the gap between M021's shape-guard infrastructure and the actual autonomous-run experience — hook portability, installer+adapter dedup, five new shape classes, and investigation-pattern wrappers — so every downstream consumer running orchestrator:auto sees the same zero-prompt loop the orchestrator's own repo does."
tier: "C"
created_at: "2026-04-29T00:00:00Z"
updated_at: "2026-04-29T00:00:00Z"
---

## Phases

- [x] **P01**: Empirical Baseline + Collapse-Decision Evidence — "A developer runs the M028 baseline harness against the 7 verbatim screenshot commands plus the operator-reported Stop-hook failure; the run records, per-screenshot, whether the failure traces to Finding A (hook portability), Finding B/G (classifier shape), Finding D/E (missing wrapper), or Finding F (adapter+installer); the collapse-decision evidence file lands at `phases/P01/P01-VERIFICATION.md`."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` (per-screenshot causal trace + collapse-decision recommendation: full-5-phase-shape vs collapse-to-2-PRs); a staging note that lists the 8 candidate corpus entries with their root-cause attribution (consumed by P03 when authoring the corpus extension)
    - Consumes: nothing on-disk; reads `tests/fixtures/m021-prompt-corpus.txt` (existing M021 corpus), `scripts/verify/lib/shape-classifier.sh` (existing M021 classifier), and the seven source screenshots referenced in `specs/031-autonomous-hardening-v3/spec.md`

- [x] **P02**: Hook Portability + Adapter+Installer Dedup (Findings A + F folded) — "A developer in any consumer project runs `orchestrator:auto`; the PreToolUse shape-guard hook fires from `~/.claude/orchestrator-hooks/pre-bash-shape-guard.sh` (self-locating via `BASH_SOURCE[0]`), Stop events resolve `bash ~/.claude/orchestrator-hooks/after-verify-sync.sh` and emit zero `command not found`, and `bash packaging/install/install-claude-code.sh` is byte-idempotent across reruns plus reversible via `--uninstall`."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `~/.claude/orchestrator-hooks/` runtime-stable install location (CON-9); `scripts/hooks/pre-bash-shape-guard.sh` (self-locating, AP-009 self-conforming); `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` (absolute-path emission + `_orchestrator_managed: true` on every entry, FR-3); `scripts/util/settings-merge.sh` (install-side dedup keyed on `(event, matcher, command) × _orchestrator_managed: true`, FR-5); `packaging/install/install-claude-code.sh` (extended payload copy: shape-guard + classifier + reject_lookup + `before-commit.sh` + `after-verify-sync.sh`; new `--repair` flag with `--dry-run` mode, FR-7 + ratified extension); `scripts/verify/m028/install-roundtrip.sh` (FR-6 pinned-sha install→install→uninstall byte-equality gate); `scripts/verify/m028/finding-A-verifier.sh` and `scripts/verify/m028/finding-F-verifier.sh` (per-finding gates, AD-19 single-file shape)
    - Consumes: P01 evidence record (gates whether the collapse-decision triggers a `replanning` pass into PR-1+PR-2 shape before the rest of M028 executes — see Architectural Decisions in `M028-CONTEXT.md`)

- [x] **P03**: Classifier Extension (AP-010 through AP-014) — "A developer runs `bash tests/run-prompt-corpus-replay.sh` against the 28-entry combined corpus (21 M021 + 7 M028); the M028 classifier produces the expected verdict on every line — including AP-014's `sh -c '<body>'` body-descent on the verbatim Finding G screenshot — and the M021 21-entry strict-superset gate (FR-22) reports zero regressions."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: `ANTIPATTERNS.md` entries AP-010 (`cmd-sub-in-pattern`), AP-011 (`quoted-arg-newline-hash`), AP-012 (`multiline-quoted-script`), AP-013 (`unquoted-brace-glob`), AP-014 (`xargs-sh-c-compound-body`), each cross-referenced to hook + classifier + corpus + wrapper (P04 deliverable); `scripts/verify/lib/shape-classifier.sh::classify_command` new pattern branches including AP-014's one-level-deep `sh -c '<body>'` connector descent (CON-5); `scripts/hooks/pre-bash-shape-guard.sh::reject_lookup` new entries mapping AP-010..AP-014 to the matching P04 wrapper paths or remediation hints; `tests/fixtures/m021-prompt-corpus.txt` 7 appended verbatim entries with expected-verdict comment annotations (CON-8: file remains M021-named, regression-data shape); `scripts/verify/m028/finding-B-verifier.sh`, `finding-C-verifier.sh`, `finding-G-classifier-verifier.sh`, `finding-G-self-conformance.sh` (FR-21 hook lints clean against AP-009)
    - Consumes: P01 staging note (root-cause attribution + 8-candidate corpus list); P02 (installed hook surface + adapter emission shape — P03's reject_lookup paths must match the runtime-stable layout P02 ships)

- [x] **P04**: Investigation-Pattern Wrappers + Dispatch Documentation — "A subagent dispatched to a task that needs to grep across files, clean stale per-step results, eval a Node expression, or peek the first N lines of a glob calls one of four wrappers under `scripts/util/` instead of constructing a compound shell; `commands/dispatch.md`'s 'Investigation Patterns' section names every wrapper with a one-line example and AP-ID cross-reference, and `bash scripts/verify/anti-pattern-lint.sh` over the updated dispatch payload + task-PAYLOAD template exits 0."
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces: `scripts/util/grep-files.sh` (FR-14, replaces `grep …; echo "---"; grep …` Screenshot 1 shape); `scripts/util/cleanup-stale-results.sh` (FR-15, replaces `/bin/rm -f .../*.txt && ls .../*.txt` Screenshot 2 / Finding D shape); `scripts/util/node-eval.sh` (FR-16, replaces multiline `node -e "…"` AP-012 shape); `scripts/util/peek-files.sh` (FR-17, replaces Finding G `find | head | xargs sh -c '…'` AP-014 shape, all four scripts AD-19 flat single-file); `commands/dispatch.md` "Investigation patterns" section + task-PAYLOAD template "Investigation patterns" section (FR-18); `ANTIPATTERNS.md` "Investigation patterns" subsection (cross-references each wrapper to its AP-ID); `scripts/verify/m028/finding-D-verifier.sh` and `scripts/verify/m028/finding-E-verifier.sh`; `scripts/verify/m028/finding-G-wrapper-verifier.sh` (peek-files.sh exercises Finding G's body-descent shape end-to-end)
    - Consumes: P02 (installer + allowlist surface; wrappers must be reachable from the installed hooks-dir context for happy-path verification); P03 (AP-IDs the wrapper docs cross-reference; reject_lookup wrapper paths the docs must match)

- [x] **P05**: Cross-Project Verifier Suite + Downstream Fixture Replay — "A developer runs `bash scripts/verify/m028/run-all.sh` and `bash tests/run-downstream-fixture.sh`; both exit 0; the run-all summary line reads 'M028: 7/7 findings verified'; the fixture autonomous-loop completes uninterrupted with zero `would_prompt: true` events and zero `command not found` diagnostics in the final `unit_close` JSONL."
  - Risk: medium
  - Depends: P03, P04
  - Boundary Map:
    - Produces: `tests/fixtures/downstream-project/` (permanent in-tree fixture per CON-10: own `.claude/settings.json` pointing at `~/.claude/orchestrator-hooks/`, no internal `scripts/hooks/`, harness asserts settings.json schema matches current adapter emission shape and fails noisily on drift); `tests/run-downstream-fixture.sh` (autonomous-loop replay harness — replays 7 Finding A/B/G screenshot commands plus a Stop event); `scripts/verify/m028/run-all.sh` (per-finding aggregator A,B,C,D,E,F,G with summary line); regression gate that combines all P02–P04 verifiers + corpus-replay (FR-22 strict-superset gate) into a single CI-runnable artifact
    - Consumes: P02 (installed hooks dir + adapter emission + install-roundtrip gate); P03 (M028 classifier + appended corpus + per-finding-B/C/G classifier verifiers); P04 (wrappers + dispatch docs + per-finding-D/E/G-wrapper verifiers)

## Cross-Cutting Concerns

- **bash 3.2 + POSIX sh (CON-2)** — affects P02, P03, P04, P05. P02 establishes the per-task acceptance-criterion carry pattern (every task that authors or modifies a `.sh` file under `scripts/`, `packaging/`, or `tests/` declares the constraint in its acceptance criteria so subagent dispatch payloads inherit it). P03, P04, P05 conform. No bash 4+ associative arrays, no `mapfile`/`readarray`, no unguarded `<<<` here-strings.

- **AD-19 single-script-file shape (CON-1)** — affects P02, P03, P04, P05. Every M028 verifier (`scripts/verify/m028/*.sh`), every wrapper (`scripts/util/*.sh`), every lifecycle script is a flat single-file shape. No nested helper directories under `scripts/verify/m028/` or `scripts/util/`. Helpers source from existing concern dirs only (`scripts/dispatch/`, `scripts/state/`, `scripts/util/`).

- **Self-conformance hard-gate (CON-3 + FR-21 + SC-9)** — affects P02 (authors the hook) and P03 (the verifier `finding-G-self-conformance.sh` lints the hook against the M028 classifier's own AP-009 rule). Hard gate from day one per `M028-CONTEXT.md` Architectural Decisions; no soft-warning grace period.

- **M025 reversibility extension (CON-4)** — P02 establishes via `install-roundtrip.sh` (install→install→uninstall pinned-sha byte-equality, SC-2); P05's `run-all.sh` invokes the gate as part of the final close-out. M025's `_orchestrator_managed: true` tag semantics are stable and load-bearing for both the install-side dedup (M028-new) and the uninstall cascade (M025-existing).

- **Strict-superset classifier guarantee (CON-7 + FR-22 + SC-8)** — P03 produces the M028 classifier; P05 verifies via 21-entry M021 corpus replay. Every classifier change in P03 must preserve prior verdicts; the per-line expected-verdict comparison in the replay harness gates this.

- **Knowledge-layer boundary M025↔M028** — affects P02 (the only phase that touches `settings-merge.sh` and `install-claude-code.sh`). M028 owns: AP-010..AP-014, new classifier branches, new wrappers, `scripts/verify/m028/*`, `tests/fixtures/downstream-project/`, "Investigation patterns" docs, the runtime-stable hooks dir contents, and the `--repair` flag. M028 consumes (does not modify): `_orchestrator_managed: true` tag semantics, the `settings-merge.sh` uninstall cascade convention, and the `install-claude-code.sh` install-vs-uninstall contract. The boundary is explicit in `specs/031-autonomous-hardening-v3/spec.md` § "Knowledge-Layer Boundary (M028 vs. M025)".

- **Permanent fixture noisy-fail (CON-10)** — P05 establishes. `tests/fixtures/downstream-project/.claude/settings.json` is asserted byte-shape-compatible with the runtime adapter's current emission before any replay runs; if the adapter's emission shape drifts (e.g., a future P02 follow-up changes an entry's `matcher` field), the harness fails noisily rather than silently passing on a stale fixture.

- **Collapse-decision replanning hook (Architectural Decision option-a)** — P01 produces the evidence record; P02's planning entry is the consumer. If P01 evidence shows Finding A alone resolves 6 of 7 screenshots, the orchestrator enters `replanning` state, marks P02–P05 stale, and rewrites them into PR-1 (hook portability) + PR-2 (the one outlier as corpus + classifier rule). If P01 does not support collapse, P02–P05 stay as-roadmapped. This is a planning-time consumption of empirical evidence, not a runtime branch.

## Dependency Graph

```
P01 ─→ P02 ─┬─→ P03 ─┬─→ P05
            │        │
            └─→ P04 ─┘
```

P03 and P04 share a parent (P02) and a child (P05); they have no edge between them. P03's reject_lookup references wrapper paths that P04 ships, and P04's docs cross-reference AP-IDs that P03 ships, but the coupling is name-level (deliverable cross-reference), not execution-time — both phases can author against the agreed paths/IDs in parallel without on-disk dependency.

## Execution Order

1. **P01** — foundation phase, no dependencies. Read-only baseline replay + evidence collection. Risk: low. Runs first because every other phase consumes its evidence (directly via P02's planning consumption, indirectly via P03's corpus annotation source).

2. **P02** — depends on P01. Risk: high (load-bearing surface; three distinct bugs in Finding F alone; M025 reversibility extension; sibling-fold A+F integration constraint). Per FR-043, the highest-risk phase among satisfied dependencies executes first — P02 is the only phase satisfied after P01, so order is forced.

3. **P03 and P04 — concurrent** — both depend only on P02; can execute in parallel once P02 ships. P03 is medium-risk (AP-014 body-descent classifier logic is the subtle one); P04 is low-risk (four small wrappers + docs). Concurrent execution is a net win for wall-clock time; the dispatch system schedules both as soon as P02's verification completes.

4. **P05** — depends on both P03 and P04. Risk: medium (permanent fixture + cross-project verifier suite + run-all aggregator). Final closeout phase; produces the suite that becomes the M028 close-out evidence.

**Collapse branch**: if P01's evidence record recommends collapse, the planner enters `replanning` after P01, rewrites P02–P05 into PR-1 + PR-2, and the execution order above is replaced. If P01 does not recommend collapse, the order above stands.

## Validation

- **No conflicting producers**: PASS. Every artifact appears in exactly one phase's `Produces` list. `ANTIPATTERNS.md` is touched by both P03 (entries AP-010..AP-014) and P04 ("Investigation patterns" subsection), but the file regions are disjoint — P03 owns the AP-### entries; P04 owns the new subsection — and the planner will sequence the edits to avoid merge conflict (P03 edits the per-pattern sections, P04 appends the subsection at file bottom). No same-region producer conflict.

- **All consumed items have producers**: PASS.
  - P02 consumes `P01 evidence record` → produced by P01.
  - P03 consumes `P01 staging note` → produced by P01; `P02 (installed hook surface + adapter emission shape)` → produced by P02.
  - P04 consumes `P02 (installer + allowlist surface)` → produced by P02; `P03 (AP-IDs + reject_lookup wrapper paths)` → produced by P03 (resolved via name-level coupling, not on-disk handoff — see Dependency Graph note).
  - P05 consumes `P02 (installed hooks dir + adapter + install-roundtrip gate)` → produced by P02; `P03 (M028 classifier + appended corpus + per-finding verifiers)` → produced by P03; `P04 (wrappers + dispatch docs + per-finding verifiers)` → produced by P04.

- **DAG is acyclic**: PASS. Edges: P01→P02, P02→P03, P02→P04, P03→P05, P04→P05. Topological order: P01, P02, {P03, P04}, P05. No back-edges; P03↔P04 name-level coupling is not a graph edge (no on-disk handoff).

- **Demo sentence coverage**: PASS. Each phase's demo sentence describes a concrete, observable end-state — what command runs, what output is produced, what file lands where, what verifier exits 0. Not a paraphrase of acceptance scenarios (those land at the task level during plan-phase per the roadmap-vs-task separation).
