---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01.5"
milestone: "M035"
provides:
  - "D-RN-1..D-RN-7 decision block (anchors dr-code-029..dr-code-035) recording rename decisions for downstream P02/P03/P05; tests/m035-acceptance/legacy-namespace-allowlist.txt enumerating exactly 5 SC-7-allowlisted historical/migration files; pre-rename git tag v0.9.2-final-spec-kit-name at HEAD (local-only, reversible via git tag -d); three task-grain verifiers (m035-p015-allowlist-shape.sh, m035-p015-decisions-block.sh, m035-p015-pre-rename-tag.sh) under tools/verify/"
requires:
  - "from:M035/P00 what:dispatch-budget-shape (none-explicit) ; from:M035/P01 what:tests/m035-acceptance/ directory pre-existing ; from:M037/P01/T04 what:decisions-shape-lint heading-shape contract"
affects:
  - "P01.5/T02..T07 (consume D-RN anchors by reference) ; P01.5/T08 (consumes legacy-namespace-allowlist.txt for SC-7 scan and folds three verifiers into m035-p015 phase-suite aggregator)"
key_files:
  - ".orchestrator/DECISIONS.md,tests/m035-acceptance/legacy-namespace-allowlist.txt,tools/verify/m035-p015-allowlist-shape.sh,tools/verify/m035-p015-decisions-block.sh,tools/verify/m035-p015-pre-rename-tag.sh"
key_decisions:
  - "D-RN-1 (dr-code-029) ; D-RN-2 (dr-code-030) ; D-RN-3 (dr-code-031) ; D-RN-4 (dr-code-032) ; D-RN-5 (dr-code-033) ; D-RN-6 (dr-code-034) ; D-RN-7 (dr-code-035) ; CHANGELOG-top-line-X-resolution X=2 (from , awk skips ## [Unreleased]) ; dispatch-wrapper-vs-task-plan reconciliation: append-decision.sh produces legacy 7-column-table rows that decisions-shape-lint rejects + that m035-p015-decisions-block.sh verifier does not match — followed task plan's heading shape per wrapper's own 'follow the Steps exactly' clause"
patterns_established:
  - "decisions-block-as-D-RN-N-heading-cohort (one ### heading per decision in a contiguous block, anchors run in numeric sequence dr-code-NNN..dr-code-NNN+6, body uses bullet list shape from existing #dr-code-004 example) ; line-equality-allowlist-file (allowlist has exact line count enforced by verifier, plus per-path on-disk existence check, so allowlist cannot drift away from real files it names) ; reversible-local-tag-as-cutover-marker (pre-rename git tag at HEAD, not pushed, reversible via git tag -d, captures patch number from CHANGELOG.md top-line at execution time so plan-author/execution-time drift is absorbed) ; verifier-pattern-pin-by-prefix-not-patch (m035-p015-pre-rename-tag.sh greps v0.9.*-final-spec-kit-name with shell glob — survives patch-number drift between plan author and execution)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T01-decisions-tag-allowlist-PLAN.md, .orchestrator/milestones/M035/phases/P01.5/tasks/T01-decisions-tag-allowlist-PAYLOAD.md, .orchestrator/DECISIONS.md (search '### D-RN-')"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-08T14:16:46Z"
---

T01 lands the foundation reference set for P01.5 (project + namespace
rename). It ships nothing that touches in-tree prose or paths — those
are T02–T07's territory. T01 is the reference set that T08's acceptance
verifiers consume.

Three deliverables:

1. **D-RN-1..D-RN-7 in `.orchestrator/DECISIONS.md`**. Seven new
   `### D-RN-N — <title> { #dr-code-NNN }` headings (anchors
   `#dr-code-029` through `#dr-code-035`) recording the rename decisions:
   D-RN-1 npm package name `@build-fractal/orchestrator`; D-RN-2 GitHub
   repo basename `Build-Fractal/orchestrator`; D-RN-3 command-cohort
   prefix `orchestrator:<cmd>`; D-RN-4 homebrew tap
   `build-fractal/orchestrator` (single-formula); D-RN-5 local clone
   path `~/Sites/orchestrator`; D-RN-6 migrate Claude memory dir
   alongside path rename; D-RN-7 pre-rename version tag
   `v0.9.X-final-spec-kit-name`. Heading shape follows the M037/P01/T04
   decisions-shape-lint contract; the framework
   `decisions-shape-lint.sh` reports `35 entries, all anchors unique`.

2. **`tests/m035-acceptance/legacy-namespace-allowlist.txt`**. Enumerates
   exactly the five historical/migration files the M035 roadmap
   Boundary Map allowlists from SC-7's legacy-namespace scan
   (`commands/migrate.md`, `docs/migrating-from-speckit.md`,
   `references/RENAME-PLAN.md`,
   `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`,
   `scripts/state/namespace-aliases.sh`). Line-equality is enforced by
   the verifier — drift (a sixth allowlisted file or a removed entry)
   must be a conscious decision.

3. **Pre-rename git tag `v0.9.2-final-spec-kit-name`**. Authored at HEAD
   on `main`. Patch number `2` resolved from `CHANGELOG.md` top-line
   `## [0.9.2]` per the task plan's awk pattern (`^## \[[0-9]` skips
   past `## [Unreleased]`). The tag is local-only; it is not pushed.
   **Reversibility**: `git tag -d v0.9.2-final-spec-kit-name` removes
   it locally; `git push --delete origin v0.9.2-final-spec-kit-name`
   removes from remote (only relevant if pushed, which T01 did not do).

Three task-grain verifiers shipped under `tools/verify/`:

- `m035-p015-allowlist-shape.sh` — asserts the allowlist file exists,
  has exactly 5 lines, contains the 5 expected paths verbatim, and
  every allowlisted path resolves to a file or directory on disk.
- `m035-p015-decisions-block.sh` — asserts the seven `### D-RN-N — `
  headings are present and each carries a `{ #dr-code-NNN }` anchor.
- `m035-p015-pre-rename-tag.sh` — asserts at least one
  `v0.9.*-final-spec-kit-name` tag exists in local refs and resolves
  to a real commit (does NOT pin the patch number, which can drift).

All three single-script-file shape per AD-19; no compound chains
(CON-3 / AP-009).

Verification (verbatim PASS lines):

```
PASS: m035-p015-allowlist-shape
PASS: m035-p015-decisions-block
PASS: m035-p015-pre-rename-tag found=v0.9.2-final-spec-kit-name
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (35 entries, all anchors unique)
```

The decisions-shape-lint follow-up (per the task plan's "Notes" section)
ran clean — no shape regression.

**Dispatch-wrapper-vs-task-plan reconciliation note**: the dispatch
wrapper instructed using `bash scripts/knowledge/append-decision.sh`
for the D-RN-* rows, but that script appends 7-column-table rows
(`| D### | When | Scope | ... |`) which the M037/P01/T04
decisions-shape-lint contract explicitly rejects as a `legacy
7-column-table row`, and which the task plan's verifier
`m035-p015-decisions-block.sh` does not match (the verifier greps for
`^### D-RN-N — `). Followed the task plan's heading shape (which the
verifier and lint both consume successfully); see the dispatch wrapper's
own guidance: "follow the task plan's `## Steps` exactly".

Downstream consumers: T02 onward reference D-RN-1 (npm scope) and
D-RN-3 (cohort prefix) by anchor; T08's `m035-p015-sc7.sh` consumes the
allowlist file via `grep -v -F -f`.

P01.5 T02 (spec-dir rename) inherits a clean DECISIONS.md, an
authoritative SC-7 allowlist, three task-grain verifiers ready to be
folded into the P01.5 phase-suite aggregator at T08, and a reversible
pre-rename tag pinning HEAD before the rename branch lands.
