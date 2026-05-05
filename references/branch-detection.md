# Branch Detection

> Canonical SSOT for the four-branch detection rules consumed by
> `orchestrator:start`. Pattern strings documented here byte-match the
> patterns implemented in `scripts/lifecycle/start.sh`. The parity
> verifier `tools/verify/m033-p01-branch-detection-ssot-parity.sh`
> enforces this contract.

## Purpose

This document is the single-source-of-truth (SSOT) for FR-2's
deterministic branch-detection rules used by `orchestrator:start` (the
warm conversational front door for any new orchestrator-managed
project). Branch-detection logic lives in **exactly two places**:

1. This SSOT — the canonical specification of rules, ordering, and
   pattern strings.
2. `scripts/lifecycle/start.sh` — the implementing script that probes
   the project directory and routes to the appropriate sub-flow.

Consumers:

- **FR-2** (M033 spec, `specs/036-project-onboarding-experience/spec.md`)
  — the functional requirement this SSOT realizes.
- **US-1** (M033 spec) — the user story whose acceptance scenarios
  AS-1..AS-6 cover branch routing and ambiguity handling.
- **`scripts/lifecycle/start.sh`** — the only runtime consumer of these
  rules. Any future codepath that needs to detect onboarding posture
  must invoke `start.sh` rather than re-implementing the rules.
- **P02..P05 sub-flow phases** — when sub-flows extend branch-detection
  (e.g., P03 may add a rule-3 sub-classification by detected language),
  the extension lands here first, then in `start.sh`.

The load-bearing decision authored at P01: every later phase's
branch-detection logic round-trips through this document, preserving
auditability.

## Branch Names

The four branch names are a **closed enum** at v1. Adding a fifth
branch is out of scope for M033 (spec NG list). The four names:

### `greenfield-empty`

The project directory is essentially empty — no source code, no prior
tooling artifacts, no curatorial materials (briefs/plans/decisions).
The user posture is "I want to start something new from scratch." The
sub-flow walks the user through goal articulation, optional stack
recommendation, and constitution authorship.

### `greenfield-with-materials`

The project directory contains curatorial PBJ-shape materials
(briefs / plans / decisions / handoffs / audits) but no source code.
The user posture is "I have a thought-out idea and want to build it."
The sub-flow ingests materials into the knowledge graph, surfaces
inconsistencies (CON-4), and uses the materials to seed the
constitution.

### `existing-codebase`

The project already has source code — a `src/` directory, ten or more
source files at the project root, or a non-trivial git history. The
user posture is "I want to bring orchestration to an existing project."
The sub-flow probes the codebase, seeds the knowledge graph from
detected patterns, and authors a constitution that reflects the
project's current shape.

### `migrating`

The project carries artifacts from a sibling tool — `.gsd/`, `.gsd2/`,
or `.specify/`. The user posture is "I'm switching from another
workflow tool to orchestrator." The sub-flow inventories the prior
tool's artifacts, maps any reusable shape into orchestrator's
conventions, and preserves the prior tool's installed footprint
(merge-not-overwrite per MEM027).

## Detection Rules (Deterministic, Ordered)

The rules fire in the order below. The **first matching rule wins** —
later rules do not run once a match is found. Detection order is
non-negotiable: rule 1 fires before rule 3 even when both would match
(per US-1 AS-4 — `migrating` always wins over `existing-codebase`).

### Rule 1: migrating

**Trigger**: any prior-tooling artifact directory exists at the project
root.

```branch-detection-rule-1
# branch-detection-rule-1: migrating
prior_tooling_globs: .gsd/ .gsd2/ .specify/
```

If `<project-dir>/.gsd/` OR `<project-dir>/.gsd2/` OR
`<project-dir>/.specify/` is present, the branch is `migrating`. This
rule fires first because users mid-migration must not be misclassified
as `existing-codebase` — the sibling-tool artifacts are the load-bearing
signal.

### Rule 2: greenfield-with-materials

**Trigger**: three or more curatorial markdown files at the project
root, AND no `src/` directory.

```branch-detection-rule-2
# branch-detection-rule-2: greenfield-with-materials
pbj_md_glob: *BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md
pbj_md_min_count: 3
pbj_md_no_src_required: true
```

The PBJ-shape glob matches the canonical curatorial-material naming
convention. The "no `src/`" qualifier prevents projects with both code
and materials from being routed through the materials-only sub-flow
(those are `existing-codebase`).

### Rule 3: existing-codebase

**Trigger**: any of three sub-conditions matches.

```branch-detection-rule-3
# branch-detection-rule-3: existing-codebase
src_dir: src/
source_extensions: .js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h
source_root_min_count: 10
git_min_commits: 1
```

The rule fires if (a) `<project-dir>/src/` exists, OR (b) ten or more
files at the project root carry one of the listed source extensions,
OR (c) `<project-dir>/.git/` exists with at least one commit. The
sub-conditions are OR-ed — any one is sufficient.

### Rule 4: greenfield-empty

**Trigger**: fallback — none of rules 1, 2, 3 fired.

```branch-detection-rule-4
# branch-detection-rule-4: greenfield-empty
trigger: fallback (no rules 1-3 fired)
```

The default posture for a fresh, empty directory.

## Ambiguity Handling

Two ambiguous-signal cases fire the disambiguation question per US-1
AS-5. In both, `start.sh` emits a structured prompt asking the operator
to confirm or override the recommendation.

### Case A: rule 1 + rule 3 both match

**Trigger**: prior-tooling artifact (`.gsd/` etc.) is present AND the
project has source code. The operator may be migrating from a sibling
tool while keeping the working codebase, or may have stale tool
artifacts in an otherwise pure existing project.

**Recommendation**: `migrating` (rule 1 wins by ordering).

**Disambiguation prompt**: "Detected `.gsd/` (or `.gsd2/`/`.specify/`)
alongside source code. Recommend `migrating`. Override with
`existing-codebase` if the sibling-tool artifacts are stale and you
just want to onboard the codebase."

**Example fixture shape**: `<dir>/.gsd/` exists AND `<dir>/src/` exists.

### Case B: thin git history with no other signals

**Trigger** (the MIT-006 / RISK-006 case): rule 3 fires solely because
`.git/` has ≥1 commit, AND the project has ≤9 source files at root, AND
no prior-tooling artifacts. This is typically a fresh `git init` with
a `README.md` commit but no real code yet.

**Recommendation**: `greenfield-empty`.

**Disambiguation prompt**: "Detected a git history but no significant
code. Recommend `greenfield-empty`. Override with `existing-codebase`
if you have code in a non-standard location."

**Example fixture shape**: `<dir>/.git/` with 1 commit, `<dir>/README.md`
present, no `<dir>/src/`, ≤9 source-extension files at root.

## --branch Override

The operator-supplied `--branch <name>` flag skips detection entirely.
Accepted values are exactly the four-branch closed enum:

```
--branch greenfield-empty | greenfield-with-materials | existing-codebase | migrating
```

Override semantics:

- The override is **silent by default** — no warning is emitted when
  detection would have produced the same name.
- If detection would have produced a different name, `start.sh` emits
  a `branch-override:` diagnostic to stderr in the shape
  `branch-override: detected=<X> overridden=<Y>`. This is informational,
  not blocking — the override always wins.
- Unknown values exit non-zero with a usage diagnostic naming the
  unknown value and listing the four valid names.

## Cross-References

**Implementing script**

- `scripts/lifecycle/start.sh` — the only runtime consumer of these
  rules. T03 lands `start.sh` with pattern strings byte-matching this
  document. The parity verifier
  `tools/verify/m033-p01-branch-detection-ssot-parity.sh` enforces the
  match.

**M033 spec entries (source)**

- **FR-2** — functional requirement realized by these rules.
- **MIT-006** — the thin-git-history case (Case B above).
- **RISK-006** — the false-positive `existing-codebase` risk that
  motivates the disambiguation question.
- **AD-4** — the architectural decision that branch-detection ships as
  a deterministic ordered-rule cascade rather than a learned classifier.

**Phase consumers (extension points)**

- **P02..P05 sub-flow phases** — when a sub-flow extends detection
  (e.g., a language-aware sub-classification of `existing-codebase`),
  the extension is authored here first and then implemented in
  `start.sh`. The parity verifier prevents drift.

**Knowledge memos (related conventions)**

- **MEM012** — command file structure (the `commands/start.md`
  consumer of this SSOT follows the canonical command-document shape).
- **MEM027** — merge-not-overwrite user-scope config (the `migrating`
  branch's preservation contract).
