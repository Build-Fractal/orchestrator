---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01.5"
milestone: "M035"
name: "C9 — git mv specs/001-speckit-orchestrator → specs/001-orchestrator + content reference sweep"
depends_on: ["T01"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- `specs/001-speckit-orchestrator/` directory (current spec dir for
  the original orchestrator feature; verified at plan-authoring time
  via direct ls — contains `spec.md`, `plan.md`, `tasks.md`,
  `data-model.md`, `quickstart.md`, `research.md`, `checklists/`,
  `contracts/`, `conversus-plan/`, `conversus-spec/`).
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` (authored by
  T01) — used by T08 verifiers; not directly consumed by T02 but its
  existence confirms T01 is complete.
- The 27 files referencing `specs/001-speckit-orchestrator/` per
  the 2026-05-08 inventory grep (CLAUDE.md, references/file-formats.md,
  M035-ROADMAP.md, M008/archive payloads/plans, fixtures, RENAME-PLAN.md
  itself, and content inside `specs/001-speckit-orchestrator/` files).

Pre-existing decisions consumed:

- D-RN-1 = `@build-fractal/orchestrator` (T01 D0XX block; informs the
  spec-dir basename — `001-orchestrator` matches the npm package's
  unscoped name).
- RENAME-PLAN.md § 5 Commit 1 (Filename moves) and Commit 6 (spec dir
  content references) — this task executes those two commits as one
  surface (both touch the same path, no benefit from splitting).

## Description

Execute RENAME-PLAN.md § 5 Commit 1 + Commit 6 as one task surface:
`git mv` the spec directory from `specs/001-speckit-orchestrator` to
`specs/001-orchestrator`, then sweep every in-tree content reference
to the old path and rewrite to the new path. Includes references both
inside the renamed directory itself (self-references in spec.md /
plan.md / tasks.md / data-model.md / contracts/state-files.md /
conversus-spec/* / conversus-plan/*) and outside (CLAUDE.md,
references/file-formats.md, M035-ROADMAP.md, M008/archive, test fixtures).

The historical/migration files (RENAME-PLAN.md, archived M008
payloads, etc.) are NOT in the C9 path-rewrite scope — RENAME-PLAN.md's
own self-reference is documentation, and archived-milestone files
preserve audit trail. The verifier in step 6 enforces this distinction.

## Steps

1. **Run `git mv` for the spec directory**:

   ```bash
   git mv specs/001-speckit-orchestrator specs/001-orchestrator
   ```

   Verify with `git status` that the move is staged as a rename
   (single-letter `R` in the porcelain, not `D`/`A` pair). `git log
   --follow specs/001-orchestrator/spec.md` should return the
   pre-rename commit history.

2. **Sweep in-tree content references** to the old path. The C9 surface
   touches these files (per the 2026-05-08 inventory):

   - `CLAUDE.md` — line 88 `specs/001-speckit-orchestrator/spec.md` →
     `specs/001-orchestrator/spec.md`.
   - `references/file-formats.md` — line 55
     `feature_spec: "specs/001-speckit-orchestrator/spec.md"` →
     `feature_spec: "specs/001-orchestrator/spec.md"`.
   - `tests/fixtures/roadmap-sample.md`,
     `tests/fixtures/state-completing/M001-ROADMAP.md`,
     `tests/fixtures/state-replanning/M001-ROADMAP.md`,
     `tests/fixtures/state-verifying/M001-ROADMAP.md`,
     `tests/fixtures/state-summarizing/M001-ROADMAP.md`,
     `tests/fixtures/state-complete/M001-ROADMAP.md`,
     `tests/fixtures/state-executing/M001-ROADMAP.md`,
     `tests/fixtures/state-validating/M001-ROADMAP.md` — each contains
     a content reference to `specs/001-speckit-orchestrator/`. Rewrite
     to `specs/001-orchestrator/`.
   - `.orchestrator/milestones/M035/M035-ROADMAP.md` — line 29
     references the old path inside the demo sentence narrative
     describing what P01.5 produces. The narrative should describe
     "the rename FROM `specs/001-speckit-orchestrator/` TO
     `specs/001-orchestrator/`" — preserve both forms in the prose
     (it documents the rename itself), no edit required.
   - Self-references inside `specs/001-orchestrator/` (formerly
     `…/001-speckit-orchestrator/`) — `plan.md`, `tasks.md`,
     `data-model.md`, `contracts/state-files.md`, `conversus-spec/*.md`,
     `conversus-plan/*.md` — each may carry the old path in
     descriptive prose. Update to `specs/001-orchestrator/`.

3. **PRESERVE references in archived/historical files**. Do NOT edit:

   - `.orchestrator/milestones/M008/archive/P05/T06-PAYLOAD.md`,
     `.orchestrator/milestones/M008/archive/P05/T06-PLAN.md` — archived
     milestone artifacts. The path reference in those files documents
     historical state at the time the milestone was authored. Survives
     under the M0XX-archived-milestone allowlist convention (preserved
     at the M035 closure level via `references/RENAME-PLAN.md` § 6
     allowlist; not in the SC-7 allowlist scope but in the C1 sweep
     allowlist scope at T04).
   - `references/RENAME-PLAN.md` — the runbook itself documents the
     rename and explicitly references the OLD path. Preserved.
   - `.planning/speckit-orchestrator-playbook.md` — operator
     personal-state planning doc; not in C9 scope, will be addressed
     at T03 (path rename) or T04 (basename rename) per its content.

4. **Use single-script-file shape for the sweep**. Author a one-shot
   helper at task execution time (not committed to the repo —
   `mktemp -d` workspace) that:
   - Reads a hardcoded list of the files in step 2.
   - For each file, runs `sed -i '' 's|specs/001-speckit-orchestrator|specs/001-orchestrator|g' <file>`
     (BSD sed; CON-2 bash 3.2 compatibility honored).
   - Verifies with `grep -nE 'specs/001-speckit-orchestrator' <file>`
     returning empty after each edit.

   The helper is one-shot because the file list is finite and known;
   no need for a persistent script. The dispatched agent emits the
   sed commands as separate edits per AD-19 — one Edit tool call per
   file, NOT a compound `git ls-files | xargs sed` chain.

5. **Verify zero residual references in non-allowlisted files**:

   ```bash
   git grep -nE 'specs/001-speckit-orchestrator' \
     | grep -vE '^(references/RENAME-PLAN.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M035/M035-ROADMAP\.md|\.orchestrator/milestones/M035/phases/P01\.5/P01\.5-PLANNING-PAYLOAD\.md|\.planning/speckit-orchestrator-playbook\.md):'
   ```

   Expected output: empty. The exclusion list captures (a) the
   historical/runbook surfaces, (b) M035 P01.5's own planning artifacts
   (which document the rename narratively).

6. **Author `tools/verify/m035-p015-spec-dir-rename.sh`**. Verifier
   asserts:
   - `specs/001-orchestrator/` exists as a directory.
   - `specs/001-speckit-orchestrator/` does NOT exist.
   - `specs/001-orchestrator/spec.md` exists (sentinel file from the
     renamed directory).
   - `git log --follow specs/001-orchestrator/spec.md | head -n 1`
     returns a commit hash (history preservation check).
   - The five non-historical content-reference targets named in step 2
     (CLAUDE.md, references/file-formats.md, the 8 fixture files) all
     contain `specs/001-orchestrator/` and zero matches for
     `specs/001-speckit-orchestrator/`.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-spec-dir-rename.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   fail=0
   if [ ! -d "$REPO_ROOT/specs/001-orchestrator" ]; then
     echo "FAIL: specs/001-orchestrator/ does not exist" >&2
     fail=1
   fi
   if [ -d "$REPO_ROOT/specs/001-speckit-orchestrator" ]; then
     echo "FAIL: specs/001-speckit-orchestrator/ still exists (should be gone)" >&2
     fail=1
   fi
   if [ ! -f "$REPO_ROOT/specs/001-orchestrator/spec.md" ]; then
     echo "FAIL: specs/001-orchestrator/spec.md missing" >&2
     fail=1
   fi
   for f in \
     "CLAUDE.md" \
     "references/file-formats.md" \
     "tests/fixtures/roadmap-sample.md"; do
     full="$REPO_ROOT/$f"
     if grep -qE 'specs/001-speckit-orchestrator' "$full"; then
       echo "FAIL: $f still references specs/001-speckit-orchestrator" >&2
       fail=1
     fi
   done
   if [ "$fail" -eq 0 ]; then
     echo "PASS: m035-p015-spec-dir-rename"
     exit 0
   fi
   exit 1
   ```

## Must-Haves

- `specs/001-orchestrator/` exists; `specs/001-speckit-orchestrator/` gone
  - Check: `bash tools/verify/m035-p015-spec-dir-rename.sh`

## Verification

```bash
bash tools/verify/m035-p015-spec-dir-rename.sh
```

## Inputs

### From Previous Tasks

- T01: D-RN-1..D-RN-7 decision block exists in `.orchestrator/DECISIONS.md`;
  legacy-namespace allowlist file exists; pre-rename tag in local refs.

### From Disk (Pre-existing)

- `specs/001-speckit-orchestrator/` — the directory to rename.
- The 11+ files referencing the old path per the 2026-05-08 inventory.
- `references/RENAME-PLAN.md` § 5 Commit 1 + Commit 6 — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no compound `git ls-files |
  xargs sed` chains. Each file edited as a separate Edit tool call.
- **AD-19 (single-script-file Check shape)**: the verifier is one
  script file; no compound test patterns.
- **Git history preservation**: use `git mv` (not `mv` + `git rm` +
  `git add`) so `git log --follow` traces history through the rename.
- **Reversibility**: `git revert <T02-commit-sha>` reverses both the
  rename and the content sweep in a single commit.

## Notes

- **Why the spec dir basename is `001-orchestrator` not
  `039-packaging-distribution`**: the existing dir name encodes the
  feature index; `001-` is the index for the original orchestrator
  feature (the foundational spec under M001 — see `specs/`). Renaming
  the basename to `001-orchestrator` preserves the index while updating
  the slug. This matches the RENAME-PLAN.md § 3 C9 mapping exactly.
- **Plan-phase verifier-availability cross-check (rule 2)**: T02
  authors `m035-p015-spec-dir-rename.sh` in step 6.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep
  shape; no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.

## Expected Output

After T02 completes:

- `specs/001-orchestrator/` exists with all the files from
  `specs/001-speckit-orchestrator/` (history preserved via `git mv`).
- `specs/001-speckit-orchestrator/` no longer exists on disk.
- 11+ non-historical files have their content references rewritten
  to `specs/001-orchestrator/`.
- One verifier script exists under `tools/verify/`.
