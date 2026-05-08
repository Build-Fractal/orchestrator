---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01.5"
milestone: "M035"
provides:
  - "C1 lowercase-hyphenated spec-kit-orchestrator -> orchestrator sweep across 158 *.md/*.yml/*.yaml files (~308 occurrences) outside the C1 historical allowlist; tools/verify/m035-p015-c1-sweep.sh task-grain verifier (single-script AD-19 shape, exit-zero PASS contract, internal allowlist regex extended for self-referential rename-description files)"
requires:
  - "from:M035/P01.5/T03 what:operator-environment paths swept (~/Sites/spec-kit-orchestrator subset removed) so T04 can sweep the broader C1 surface without colliding"
affects:
  - "P01.5/T05 (C2+C3 prose sweep -- inherits self-referential rename-description allowlist pattern; M035-ROADMAP/CONTEXT and specs/039-packaging-distribution/spec.md must remain intact); P01.5/T08 (acceptance battery -- m035-p015-c1-sweep.sh folds into phase-suite aggregator)"
key_files:
  - "tools/verify/m035-p015-c1-sweep.sh,README.md,CLAUDE.md,packaging/bundle/manifest.yml,wiki/mkdocs.yml,references/installation.md,references/architecture.md,packaging/bundle/README.md,specs/035-wiki-distribution-init-integration/spec.md,specs/003-migration-tool/spec.md,specs/023-github-native-integration/conversus.yml,specs/001-orchestrator/contracts/extension-manifest.md"
key_decisions:
  - "D-RN-1 drives C1 rewrite target; allowlist-extension-for-self-referential-rename-descriptions (M035-ROADMAP.md + M035-CONTEXT.md + specs/039-packaging-distribution/spec.md must retain spec-kit-orchestrator references because they describe the rename plan itself; mechanical collapse to orchestrator -> orchestrator is nonsensical); .planning/speckit-*-playbook.md is out-of-scope-for-C1 (basename uses speckit-orchestrator without spec-kit hyphen -- T06 cohort territory)"
patterns_established:
  - "staged-probe-with-run-probe-wrapper-for-bulk-sed (Write tool stages /tmp/m035-p015-c1-sweep.sh probe; scripts/util/run-probe.sh invokes via approved-root contract; CON-3/AP-009 honored without per-file Edit tool calls); self-referential-rename-description-allowlist-extension (rename-plan documents must retain pre-rename name to remain coherent; allowlist regex extension is the right fix not eyeball rewrite); post-sweep-sentence-flow-audit (git grep for orchestrator-orchestrator/orchestrator project is now patterns surfaces awkward sed artifacts before verifier finalization)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T04-c1-lowercase-hyphenated-PAYLOAD.md,.orchestrator/milestones/M035/phases/P01.5/tasks/T04-c1-lowercase-hyphenated-PLAN.md,references/RENAME-PLAN.md,tools/verify/m035-p015-c1-sweep.sh"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-08T15:03:27Z"
---

T04 executes the C1 lowercase-hyphenated `spec-kit-orchestrator` ->
`orchestrator` sweep across `*.md` / `*.yml` / `*.yaml` files outside
the C1 historical allowlist. The pre-rename sentence-flow safety net
(plan Constraint, RENAME-PLAN "eyeball-not-sed" guidance) drove three
allowlist extensions on top of the payload step-4 narrow regex --
self-referential rename-description files were reverted to the
original `spec-kit-orchestrator -> orchestrator` shape so the
descriptions remain semantically coherent post-sweep.

**Step 1 inventory (`/tmp/m035-p015-c1-inventory.txt` at task entry):**
430 hits across 159 files. After applying the payload step-4 narrow
exclusion regex (RENAME-PLAN, migrating-from-speckit, papercut-sweep,
M008/archive, M0XX-SUMMARY/BODY, CHANGELOG, DECISIONS, P01.5
planning, KNOWLEDGE, conversus-deliberation), 308 non-allowlisted
hits across 158 files remained. Note `.planning/speckit-*-playbook.md`
basenames carry `speckit-orchestrator` (no spec-kit hyphen) and
therefore fall outside C1 scope (cohort sweep, T06 territory).

**Step 3 sweep:** mechanical `sed -i ''
's/spec-kit-orchestrator/orchestrator/g'` over every non-allowlisted
file via a staged probe (`/tmp/m035-p015-c1-sweep.sh`) invoked through
`scripts/util/run-probe.sh` per CON-3 / AP-009. 158 files swept.

**Step 4 sentence-flow audit:** post-sweep `git grep` for
`orchestrator project is now`, `orchestrator-orchestrator`, and
`orchestrator orchestrator` surfaced 5 hits, all inside three
self-referential rename-description files:
`.orchestrator/milestones/M035/M035-ROADMAP.md`,
`.orchestrator/milestones/M035/M035-CONTEXT.md`, and
`specs/039-packaging-distribution/spec.md`. These files literally
describe the rename plan ("`spec-kit-orchestrator` ->
`orchestrator`"); the mechanical sweep collapsed them to the
nonsensical "`orchestrator` -> `orchestrator`" shape. Reverted via
`git checkout --` on the three files and extended the C1 verifier
allowlist regex to permanently exclude them. Justification:
allowlist-extension-for-self-referential-rename-descriptions
mirrors the T03 pragmatic-extension pattern.

**Step 5 verifier `tools/verify/m035-p015-c1-sweep.sh`:** asserts a
single property -- every `spec-kit-orchestrator` match in
`*.md` / `*.yml` / `*.yaml` files outside the documented C1
historical allowlist is gone. The allowlist now spans the payload
step-4 narrow set plus the three self-referential rename-description
files (`M035-ROADMAP.md`, `M035-CONTEXT.md`,
`specs/039-packaging-distribution/spec.md`). Single-script AD-19
shape; no compound chains (CON-3 / AP-009).

**Pattern handoff to T05 (C2 + C3 prose sweep):** the same
self-referential rename-description allowlist will likely apply to
T05 since the M035 spec/roadmap/context describe both the
hyphenated and the title-case prose renames. T05 should pre-flight
its inventory against `M035-ROADMAP.md`, `M035-CONTEXT.md`, and
`specs/039-packaging-distribution/spec.md` before starting and
extend its own allowlist regex accordingly.

**Verification (verbatim PASS line):**

```
PASS: m035-p015-c1-sweep
```
