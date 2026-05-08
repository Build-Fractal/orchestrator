---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01.5"
milestone: "M035"
name: "C6 — Operator-environment paths (~/Sites/spec-kit-orchestrator → ~/Sites/orchestrator)"
depends_on: ["T02"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- `references/installation.md` — operator-facing install docs;
  contains `~/Sites/spec-kit-orchestrator` references in shell-function
  recipes (per `references/RENAME-PLAN.md` § 5 Commit 2 inventory).
- Operator scripts that hard-code `~/Sites/spec-kit-orchestrator` —
  enumerated at task execution time via
  `git grep -nE '~/Sites/spec-kit-orchestrator|/Sites/spec-kit-orchestrator'`.
- T02 output on disk: `specs/001-orchestrator/` exists; old
  `specs/001-speckit-orchestrator/` is gone. (T03 sequences after T02
  for blast-radius predictability — the spec-dir rename happens before
  the broad path sweep so any path interaction surfaces in isolation.)

Pre-existing decisions consumed:

- D-RN-5 (T01 D0XX block): local clone path is `~/Sites/orchestrator`.
- RENAME-PLAN.md § 5 Commit 2 — the canonical sed pattern for this
  surface: `s|~/Sites/spec-kit-orchestrator|~/Sites/orchestrator|g`
  and `s|/Sites/spec-kit-orchestrator|/Sites/orchestrator|g`.

## Description

Sweep operator-environment path references — every match for
`~/Sites/spec-kit-orchestrator` or `/Sites/spec-kit-orchestrator` in
in-tree files (operator scripts, `references/installation.md` recipes,
shell-function examples) — to the new `~/Sites/orchestrator` /
`/Sites/orchestrator` form. The sweep is autonomous-executable on
the in-tree surface only; the operator's actual filesystem rename
(`mv ~/Sites/spec-kit-orchestrator ~/Sites/orchestrator`) is off-tree
and surfaced in T08's runbook.

Allowlisted historical files (RENAME-PLAN.md, archived M008 payloads,
`.orchestrator/proposals/papercut-sweep-pre-M030.md`,
`docs/migrating-from-speckit.md`) are NOT in T03's path-rewrite scope —
their references document the rename narrative or pre-rename history.
The verifier in step 4 enforces this.

## Steps

1. **Inventory the C6 surface at task execution time**:

   ```bash
   git grep -nE '~?/Sites/spec-kit-orchestrator' \
     > /tmp/m035-p015-c6-inventory.txt
   ```

   Read every line. Classify each into:
   - `[C6-rewrite]` — operator-facing path; rewrite to
     `~/Sites/orchestrator`. (Most matches.)
   - `[HIST]` — preserved historical reference (RENAME-PLAN.md, archived
     milestone summaries, papercut-sweep proposal). Do NOT edit.
   - `[REVIEW]` — context unclear. Operator review required at task
     end (HALT signal if non-empty).

   Expected `[HIST]` set (allowlist for this task):
   - `references/RENAME-PLAN.md` (entire file documents the rename)
   - `.orchestrator/milestones/M008/archive/**` (archived milestones)
   - `.orchestrator/proposals/papercut-sweep-pre-M030.md` (pre-rename
     session log)
   - `.orchestrator/milestones/M035/phases/P01.5/P01.5-PLANNING-PAYLOAD.md`
     (this phase's planning payload — documents both old and new names)
   - `.orchestrator/milestones/M035/phases/P01.5/P01.5-PLAN.md` (this
     phase plan — same)
   - `.orchestrator/milestones/M035/phases/P01.5/tasks/T0*-PLAN.md`
     (all task plans in this phase — same)
   - `CHANGELOG.md` entries that document pre-rename releases (top-line
     section may need rewrite per T05; archived entries preserved).

2. **Rewrite each `[C6-rewrite]` match via individual Edit calls**.
   Per AD-19 / CON-3, do NOT chain `git ls-files | xargs sed`. Per
   surface-by-surface basis:
   - `references/installation.md` — every operator-recipe block
     containing `~/Sites/spec-kit-orchestrator` rewrites in place.
     Spot-check: the `orchestrator-update()` shell function example
     (per RENAME-PLAN.md § 9.3) is the load-bearing case; rewrite to
     `~/Sites/orchestrator`.
   - Any operator script under `scripts/` that references the path
     (likely few or none — operator-personal scripts live outside the
     repo by convention; the sweep should find few matches).
   - Any documentation under `docs/` that demonstrates an install
     recipe with the old path.

3. **Verify zero residual non-allowlisted matches**:

   ```bash
   git grep -nE '~?/Sites/spec-kit-orchestrator' \
     | grep -vE '^(references/RENAME-PLAN\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M035/phases/P01\.5/|CHANGELOG\.md):'
   ```

   Expected output: empty.

4. **Author `tools/verify/m035-p015-operator-paths.sh`**. Verifier
   asserts the post-sweep state:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-operator-paths.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   # The exclusion regex enumerates the historical/in-flight allowlist.
   residue=$(git grep -nE '~?/Sites/spec-kit-orchestrator' 2>/dev/null \
     | grep -vE '^(references/RENAME-PLAN\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M035/phases/P01\.5/|CHANGELOG\.md):' || true)
   if [ -n "$residue" ]; then
     echo "FAIL: residual ~/Sites/spec-kit-orchestrator matches in non-historical files:" >&2
     echo "$residue" >&2
     exit 1
   fi
   echo "PASS: m035-p015-operator-paths"
   exit 0
   ```

## Must-Haves

- Zero residual `~/Sites/spec-kit-orchestrator` or
  `/Sites/spec-kit-orchestrator` matches outside the historical
  allowlist
  - Check: `bash tools/verify/m035-p015-operator-paths.sh`

## Verification

```bash
bash tools/verify/m035-p015-operator-paths.sh
```

## Inputs

### From Previous Tasks

- T02: `specs/001-orchestrator/` exists; old spec dir gone.

### From Disk (Pre-existing)

- `references/installation.md` — operator-recipe block; the load-bearing
  rewrite target.
- `references/RENAME-PLAN.md` § 5 Commit 2 — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no `git ls-files | xargs sed`
  chains. Per-file Edit calls.
- **AD-19 (single-script-file Check shape)**: verifier is one script.
- **Off-tree filesystem rename is NOT this task's responsibility** —
  the operator's `mv ~/Sites/spec-kit-orchestrator ~/Sites/orchestrator`
  is documented in T08's runbook. T03 only rewrites in-tree references
  to the new path.
- **CHANGELOG.md preservation**: entries documenting pre-rename
  releases (e.g. v0.9.X release notes referencing the old path) are
  in the historical allowlist; the top-line section gets the new path
  via T05's prose sweep.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T03
  authors `m035-p015-operator-paths.sh` in step 4.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep;
  no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **HALT-signal protocol**: if step 1's classification log surfaces
  any `[REVIEW]` entries, the dispatched agent emits
  `HALT: T03/C6 review needed — see /tmp/m035-p015-c6-inventory.txt`
  and pauses for operator decision before proceeding to step 2.

## Expected Output

After T03 completes:

- Every operator-environment path reference in non-historical files is
  rewritten from `~/Sites/spec-kit-orchestrator` (or
  `/Sites/spec-kit-orchestrator`) to `~/Sites/orchestrator` (or
  `/Sites/orchestrator`).
- One verifier script exists under `tools/verify/`.
- The off-tree filesystem rename remains operator's responsibility
  (surfaced in T08 runbook).
