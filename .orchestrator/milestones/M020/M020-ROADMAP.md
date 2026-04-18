---
schema_version: "1.0"
type: roadmap
milestone: "M020"
feature_ref: "020-cutover-content-sweep"
feature_spec: "specs/020-cutover-content-sweep/spec.md"
vision: "a fresh clone of spec-kit-orc resolves orchestrator:init, runs orchestrator:auto end-to-end, recovers crashes using the current identifier, and contains zero Skill(speckit.orchestrator.*) entries in templates or project settings — with six mechanical gates preventing the drift from recurring"
tier: "C"
created_at: "2026-04-16T18:00:00Z"
updated_at: "2026-04-16T18:00:00Z"
---

## Phases

- [ ] **P01**: Gate Scaffolding — "A developer runs `bash scripts/verify/run-suite.sh m020 P01` against HEAD and sees PASS for all six gate scripts' existence checks, plus expected content-failures in `no-legacy-content.sh`, `no-legacy-resolver-docs.sh`, and `packaging-skills-match-commands.sh` — each failure names a file:line and a remediation hint. The failures are the baseline."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/verify/no-legacy-content.sh` (new: scans `templates/*.{md,yaml,json}`, `.claude/settings.json`, `commands/*.md` for `Skill(speckit.orchestrator.*)`, `speckit.orchestrator.<identifier>`, and similar tokens defined in the shared fixture; exits non-zero with file:line diagnostics and a remediation hint naming the current identifier)
      - `scripts/verify/no-legacy-resolver-docs.sh` (new: scans `docs/`, `commands/`, `references/` for "5-rule", "5 rule", "five-rule", "bridge" in resolver-description context; exits non-zero with file:line + suggested 4-rule phrasing)
      - `scripts/verify/packaging-skills-match-commands.sh` (new: enumerates `commands/*.md` and `packaging/skills/*.md`; for each command file, requires a corresponding skill file; exits non-zero with the list of commands missing skills)
      - `scripts/verify/principle-count-sync.sh` (new: extracts principle count from `CLAUDE.md` and `.orchestrator/memory/constitution.md`; exits zero iff they match; exits non-zero with both counts and the delta)
      - `scripts/verify/test-suite-count-sync.sh` (new: counts `tests/test-s*.sh` files vs. the claimed-count number in `CLAUDE.md`, `milestone-summary.md`, and docs; exits non-zero with the delta)
      - `scripts/verify/config-schema-matches-live.sh` (new: validates `tests/test-s01-structure.sh` keyset against the live `.orchestrator/config.yml` schema; exits non-zero if the test validates absent keys or misses present ones)
      - `scripts/verify/fixtures/legacy-tokens.txt` (new: catalog of banned tokens for `no-legacy-content.sh` — excluded from its own scan via self-exclude)
      - `scripts/verify/m020-p01-gates-exist.sh` (new: gate-script existence check for P01 acceptance)
      - `.orchestrator/milestones/M020/phases/P01/evidence/arbiter-rulings.md` (copy the blind-arbiter binding decisions from `conversus-oss/deliberations/spec-kit-orc-audit/arbitration/resolution.md` into a local evidence file; establishes the authority trail independent of the sibling-repo state)
    - Consumes: nothing (foundation phase)

- [ ] **P02**: Runtime-Path Restoration — "A fresh clone of spec-kit-orc invokes `orchestrator:init` and the harness resolves it to `packaging/skills/orchestrator-init.md` with zero approval prompts. A developer reads `commands/auto.md` crash-recovery instructions and sees `orchestrator:resume` (not `speckit.orchestrator.resume`). The `packaging-skills-match-commands.sh` gate transitions FAIL → PASS. The `no-legacy-content.sh` gate's `commands/auto.md` diagnostic transitions from 3 hits (lines 68, 296, 518) to zero."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `packaging/skills/orchestrator-init.md` (new: skill file for `orchestrator:init`, following the structural shape of the twelve existing `packaging/skills/orchestrator-*.md` files — YAML frontmatter with `name: "orchestrator:init"`, body matching the `commands/init.md` entry-point contract, either full inline logic or thin delegation to `scripts/lifecycle/init-project.sh` per the shape of the other twelve)
      - `packaging/bundle/manifest.yml` (updated: add `orchestrator-init.md` to the bundle entry; no version bump — version governance is out of scope per Q2)
      - `commands/auto.md` (updated: lines 68, 296, 518 — replace `speckit.orchestrator.resume` with the current `orchestrator:resume` identifier; grep-safe post-edit)
      - `scripts/verify/m020-p02-init-resolves.sh` (new: gate validating `orchestrator:init` resolves from a fresh clone posture; invoked as part of P04 dogfood and as a standalone CI check)
      - `.orchestrator/milestones/M020/phases/P02/evidence/init-resolution.md` (evidence of the fresh-clone resolution pass; prompt count; transcript excerpt)
    - Consumes:
      - `scripts/verify/packaging-skills-match-commands.sh` from P01 (must transition from FAIL to PASS as P02's acceptance signal)
      - `scripts/verify/no-legacy-content.sh` from P01 (must show zero `commands/auto.md` diagnostics after P02 lands)

- [ ] **P03**: Content Sweep + Governance — "The repo contains zero `Skill(speckit.orchestrator.*)` entries in `.claude/settings.json`, `templates/autonomy-defaults.yaml`, `templates/claude-settings.json`, `templates/instruction-schema.md`, `templates/claude-code-appendix.md`. `commands/migrate.md` describes only the 4-rule resolver. `.orchestrator/DECISIONS.md` contains a new D007 (FR-013 hash-preservation retirement) and a new D008 (content-layer governance rule). The `no-legacy-content.sh` and `no-legacy-resolver-docs.sh` gates transition FAIL → PASS across all targeted files."
  - Risk: high
  - Depends: P02
  - Boundary Map:
    - Produces:
      - `templates/autonomy-defaults.yaml` (updated: lines 90-91 `Skill(speckit.orchestrator.*)` entries removed)
      - `templates/claude-settings.json` (updated: `Skill(speckit.orchestrator.*)` entries removed)
      - `templates/instruction-schema.md` (updated if it carries the same tokens; zero-diff if it does not)
      - `templates/claude-code-appendix.md` (updated if it carries the same tokens; zero-diff if it does not)
      - `.claude/settings.json` (updated: lines 55-56 `Skill(speckit.orchestrator.*)` entries removed; `Bash(bash .specify/*)` entries retained per Q4 resolution with an inline comment citing `M015-SUMMARY.md:32`)
      - `commands/migrate.md` (updated: lines 47 and 83 — rewrite the 5-rule resolver description as the current 4-rule resolver; remove references to the bridge)
      - `.orchestrator/DECISIONS.md` (updated: append D007 retiring the FR-013 hash-preservation clause with evidence pointer to this roadmap and the arbiter rulings; append D008 establishing the content-layer governance rule — any change leaving content-layer surfaces inconsistent with specs requires either a DECISIONS entry or a mechanical grep-gate enforcing consistency)
      - `scripts/verify/m020-p03-content-clean.sh` (new: aggregate gate invoking `no-legacy-content.sh` and `no-legacy-resolver-docs.sh` in a single wrapper; exits zero iff both pass)
      - `.orchestrator/milestones/M020/phases/P03/evidence/gate-transitions.md` (evidence recording the FAIL → PASS transitions for each touched gate)
    - Consumes:
      - `scripts/verify/no-legacy-content.sh` from P01 (must transition FAIL → PASS across all edited files)
      - `scripts/verify/no-legacy-resolver-docs.sh` from P01 (must transition FAIL → PASS for `commands/migrate.md`)
      - `commands/auto.md` from P02 (the prior fix must be in the tree — confirms AD-2 ordering)

- [ ] **P04**: Summary Reconciliation + Locked-Down Dogfood — "A fresh clone of spec-kit-orc with `.claude/settings.json` stripped to a minimal posture runs `orchestrator:init → orchestrator:auto` on a completed phase from a prior milestone and produces zero approval prompts across the full loop. `CLAUDE.md` enumerates all 15 constitution principles. Four documents referencing the test-suite count all read `8`. `M016-SUMMARY.md:8` zero-prompt phrasing is qualified by its scope (`orchestrator:auto`, Class A harness prompts, measured posture). The `principle-count-sync.sh`, `test-suite-count-sync.sh`, and `m020-p04-zero-prompts-locked.sh` gates all exit zero."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces:
      - `CLAUDE.md` (updated: line 37 principle-count "7" → "15"; lines 48-54 enumerate principles VIII through XV with a one-sentence gloss each; reference pointer to `.orchestrator/memory/constitution.md` retained for full definitions per Q3 resolution)
      - `milestone-summary.md` (updated: any claim of "7 test suites" → "8 test suites"; verified against `tests/test-s*.sh` file count)
      - Up to 3 additional docs flagged by `test-suite-count-sync.sh` (updated: same sync)
      - `M016-SUMMARY.md` (updated: line 8 zero-prompt phrasing qualified with `orchestrator:auto` scope and the measured posture)
      - `scripts/verify/m020-p04-zero-prompts-locked.sh` (new: gate for the locked-down re-run; records prompt count; exits zero iff count is zero; requires pointing at evidence file)
      - `.orchestrator/milestones/M020/phases/P04/evidence/zero-prompts-locked.md` (evidence document: fresh-clone hash, stripped-settings posture, target phase, transcript excerpts, prompt-count tally, comparison to M016 baseline)
      - `.orchestrator/milestones/M020/M020-SUMMARY.md` (new — written at milestone close per template convention)
      - `.orchestrator/milestones/M020/M020-VALIDATED` (new: validation sentinel at milestone close)
    - Consumes:
      - All P01 gates (exit-zero required as gate-to-merge)
      - `packaging/skills/orchestrator-init.md` from P02 (required for the `init → auto` chain in the dogfood)
      - All P03 content edits (required to reach zero-prompt posture on the measured posture)

## Cross-Cutting Concerns

- **Bash 3.2 compatibility** — P01, P02, P03, P04. All six new verify scripts plus the P02/P03/P04 gate wrappers must pass `bash -n` under Bash 3.2 and must not use `declare -A`, `mapfile`, `${var,,}`. P01 establishes the pattern; P02 through P04 conform.
- **Gate self-exclusion** — P01, P03. The banned-token fixture at `scripts/verify/fixtures/legacy-tokens.txt` is a catalog of tokens that `no-legacy-content.sh` must flag elsewhere but must not flag in the fixture. Either a `# lint-ignore` marker, a path exclude-list, or a stable marker-comment convention must be used. The deliberation transcripts in `conversus-oss/deliberations/spec-kit-orc-audit/` are outside this repo's tree and do not need exclusion. If any portion is copied inline (P01 `phases/P01/evidence/arbiter-rulings.md`), gate scans must exclude `.orchestrator/milestones/M020/phases/**/evidence/**`.
- **AD-2 ordering** — P02 → P03. P02 must land on the target branch (or be staged in an earlier commit within the same PR) before P03's `.claude/settings.json` deletion merges. A PR that merges P03's settings deletion while `commands/auto.md` still references `speckit.orchestrator.resume` breaks crash-recovery UX in the intermediate window. Phase acceptance for P03 includes verification that P02's gate (`no-legacy-content.sh` for `commands/auto.md`) is already PASS.
- **Governance rule enforcement** — P03 lands D008; enduring enforcement is cultural and is recorded as a known limitation (see M020-EVALUATION Complexity Factors). The gates from P01 discharge the current drift mechanically; D008 is the floor, not the ceiling.
- **Evidence independence** — P01 copies the arbiter's bindings into a local evidence file so the milestone's rationale does not depend on the sibling-repo state. The sibling repo is explicitly allowed to drift (per project-memory "2026-04-17: focus shifted to conversus; spec-kit-orc allowed to drift").

## Dependency Graph

```
P01 ──→ P02 ──→ P03 ──→ P04
```

Strictly sequential. P01's gate scaffolding must exist before any fix can prove
itself via gate transition. P02's runtime-path fixes must land before P03's
allow-list deletion (AD-2 ordering constraint). P03's content sweep must land
before P04's locked-down dogfood (the dogfood runs against the post-sweep
state, not the pre-sweep state).

## Execution Order

1. **P01** — foundation. No dependencies. Authors six verify gates, a shared
   banned-token fixture, and a local copy of the arbiter rulings. Expected
   outcome: three of the six gates fail against HEAD with file:line diagnostics
   (this is the baseline; not a regression).
2. **P02** — depends on P01. Lands `orchestrator:init` skill file, bundle
   manifest entry, and `commands/auto.md` identifier fix. Acceptance includes
   the `packaging-skills-match-commands.sh` gate transitioning FAIL → PASS
   and the `commands/auto.md` portion of `no-legacy-content.sh` going to zero
   hits.
3. **P03** — depends on P02. Content sweep (templates, settings), migrate.md
   rewrite, DECISIONS.md D007 + D008. Acceptance includes the remaining
   `no-legacy-content.sh` diagnostics going to zero and
   `no-legacy-resolver-docs.sh` going to zero.
4. **P04** — depends on P03. Summary reconciliation + locked-down dogfood.
   Largest evidence capture. Close-out includes writing `M020-SUMMARY.md` and
   the `M020-VALIDATED` sentinel.

## Validation

- **No conflicting producers**: PASS — each artifact is produced by exactly one phase. Verify scripts and their aggregators live at distinct paths; `DECISIONS.md` D007 and D008 are appended by P03 only; `M016-SUMMARY.md` is touched by P04 only (a targeted line-8 edit; no other surface is amended).
- **All consumed items have producers**: PASS — P02 consumes P01 gates; P03 consumes P01 gates and P02's `auto.md` fix; P04 consumes all P01 gates, P02's init skill, and all P03 content edits. All traced.
- **DAG is acyclic**: PASS — P01 → P02 → P03 → P04. No back-edges.
- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo sentence describing a specific developer action (running the suite, grepping a file, invoking `orchestrator:init` from a fresh clone, completing a locked-down dogfood) and a specific expected result (gate transitions, token counts, prompt-count zero).
