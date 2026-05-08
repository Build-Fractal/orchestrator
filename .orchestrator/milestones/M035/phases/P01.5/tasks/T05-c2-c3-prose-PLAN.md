---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01.5"
milestone: "M035"
name: "C2 + C3 — Title-case + lowercase prose sweep across *.md"
depends_on: ["T04"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- T04 output: zero residual `spec-kit-orchestrator` matches in non-historical
  files (the lowercase-hyphenated sweep is complete).
- The pre-T05 inventory is captured at task execution time:
  ```bash
  git grep -niE 'Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' '*.md' \
    > /tmp/m035-p015-c2-c3-inventory.txt
  ```
  Expected hit zone: README.md (title-case heading + body), CLAUDE.md
  (project description prose), various `commands/*.md` introductory
  paragraphs that name the project, doc cross-references in `docs/`.

Pre-existing decisions consumed:

- D-RN-1 = `@build-fractal/orchestrator` (T01 D0XX block) — informs
  the `Orchestrator` (title-case) form.
- RENAME-PLAN.md § 3 mapping table (C2: `Spec-Kit Orchestrator` →
  `Orchestrator`; C3: `spec-kit orchestrator` / `spec kit orchestrator`
  → `orchestrator`) and § 5 Commit 4 — runbook source.

## Description

Sweep title-case (`Spec-Kit Orchestrator`) and lowercase-spaced
(`spec-kit orchestrator` / `spec kit orchestrator`) prose references
in `*.md` files outside the C2/C3 historical allowlist (same set as
T04 plus any `*.md` artifact pre-rename audit-trail dependent on the
old prose form). Rewrite to `Orchestrator` (title) or `orchestrator`
(lowercase).

This is the "eyeball-not-sed" zone for context-sensitivity — sentence
flow matters, and there are legitimate references to the upstream
spec-kit framework (handled in T07 C4 pass) which look superficially
similar to C3 prose patterns. T05's allowlist EXCLUDES the upstream
references (those stay) and the T07 review log will catch any T05
miss.

## Steps

1. **Inventory the C2 + C3 surface**:

   ```bash
   git grep -niE 'Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' '*.md' \
     > /tmp/m035-p015-c2-c3-inventory.txt
   ```

2. **Classify each match**:
   - `[C2-rewrite]` — title-case prose; rewrite to `Orchestrator`.
   - `[C3-rewrite]` — lowercase-spaced prose; rewrite to `orchestrator`.
   - `[HIST]` — historical/archived file (same allowlist as T04
     extended).
   - `[UPSTREAM]` — refers to the upstream spec-kit framework
     ("originally migrated FROM spec-kit", "spec-kit's design pattern",
     etc.). PRESERVE. T07's C4 pass cross-validates these.
   - `[REVIEW]` — context unclear; HALT for operator review at end if
     non-empty.

3. **Per-match Edit calls**. Per AD-19 / CON-3, no compound `xargs sed`.
   For each `[C2-rewrite]` and `[C3-rewrite]` match, run a per-file
   Edit. Sentence-flow preservation: many prose references read like
   "The Spec-Kit Orchestrator is a multi-phase autonomous orchestrator"
   which after C2 becomes "The Orchestrator is a multi-phase autonomous
   orchestrator" (which is fine). But "the spec-kit orchestrator
   approach" might benefit from rephrasing rather than mechanical
   replacement; if so, the Edit call rewrites the surrounding clause.

4. **Verify zero residual non-allowlisted, non-upstream matches**:

   ```bash
   git grep -niE 'Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' '*.md' \
     | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-):'
   ```

   Expected: empty, OR only `[UPSTREAM]` matches that survived
   classification (these are flagged in step 2's classification log
   for T07 cross-validation, not edited).

5. **Author `tools/verify/m035-p015-c2-c3-prose.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-c2-c3-prose.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   residue=$(git grep -niE 'Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' '*.md' 2>/dev/null \
     | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-):' || true)
   if [ -n "$residue" ]; then
     echo "FAIL: residual C2/C3 prose matches in non-historical *.md files:" >&2
     echo "$residue" >&2
     exit 1
   fi
   echo "PASS: m035-p015-c2-c3-prose"
   exit 0
   ```

## Must-Haves

- Zero residual `Spec-Kit Orchestrator` / `spec-kit orchestrator` /
  `spec kit orchestrator` matches in `*.md` files outside the C2/C3
  historical allowlist
  - Check: `bash tools/verify/m035-p015-c2-c3-prose.sh`

## Verification

```bash
bash tools/verify/m035-p015-c2-c3-prose.sh
```

## Inputs

### From Previous Tasks

- T04: lowercase-hyphenated path/repo basename sweep complete.

### From Disk (Pre-existing)

- All `*.md` files (T05 scope).
- `references/RENAME-PLAN.md` § 5 Commit 4 — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no compound chains.
- **AD-19 (single-script-file Check shape)**: one verifier script.
- **Upstream-spec-kit reference preservation**: any prose mentioning
  the upstream `spec-kit` framework (the Anthropic project the
  orchestrator originally migrated from) MUST survive C2/C3 sweep.
  These are tagged `[UPSTREAM]` in step 2's classification and cross-
  validated in T07.
- **Sentence-flow preservation**: rewrite, don't just sed. If the
  result is awkward, hand-rewrite the clause.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T05
  authors `m035-p015-c2-c3-prose.sh` in step 5.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep;
  no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **CHANGELOG.md top-line section**: the current top-line section
  (e.g. "Spec-Kit Orchestrator" project header) gets the new name
  per T05; archived version-history sub-sections preserve old prose.
  This requires a careful surgical edit on `CHANGELOG.md` rather than
  including it in the broad allowlist exclusion.

## Expected Output

After T05 completes:

- Zero residual `Spec-Kit Orchestrator` / `spec-kit orchestrator` /
  `spec kit orchestrator` matches in non-historical, non-upstream
  `*.md` files.
- One verifier script exists under `tools/verify/`.
- README.md and other doc-surface `*.md` files use `Orchestrator`
  (title) or `orchestrator` (lowercase) prose throughout.
