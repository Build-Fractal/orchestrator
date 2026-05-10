---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M015"
name: "Move constitution and remove .specify/memory/"
depends_on: [T02]
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- T02 is complete: `.orchestrator/` exists with the migrated state tree, `.specify/orchestrator/` is gone.
- `.specify/memory/constitution.md` still exists and has not been touched.
- `.orchestrator/memory/` does NOT yet exist.
- The constitution file contains the v2.1.0 project constitution with principles I–XV (the spec-kit-neutral governance document).

## Description

Move the constitution from `.specify/memory/constitution.md` to `.orchestrator/memory/constitution.md`, then delete the now-empty `.specify/memory/` directory. This is the second half of the state migration — done as a separate task from T02 because `scripts/migrate/migrate-state.sh` only targets `.specify/orchestrator/`, not `.specify/memory/`. Splitting the moves lets T02 use the existing migration tool unchanged.

The constitution is referenced by multiple runtime files — `scripts/diagnostics/check-constitution.sh`, `scripts/AGENTS.md`, `references/constitution-walkthrough.md`, `docs/knowledge-management.md`, `CLAUDE.md`, `references/architecture.md`, and others. This task only *moves the file*; T05 updates every runtime reference to the new path.

Like T02, this is a verbatim file move — no content rewriting. The constitution file's text is preserved as-is.

## Steps

1. Create the destination directory:

   ```
   mkdir -p .orchestrator/memory
   ```

2. Move the constitution file:

   ```
   mv .specify/memory/constitution.md .orchestrator/memory/constitution.md
   ```

3. Remove the now-empty `.specify/memory/` directory. It should contain no other files at this point ([M008](../../../../../milestones/M008/index.md) moved the constitution as the only file under `.specify/memory/`; no subdirectories or other files exist):

   ```
   rmdir .specify/memory
   ```

   If `rmdir` fails with "Directory not empty," list the remaining contents and stop — the task's assumption that only `constitution.md` lived there is wrong and requires human review. Do not `rm -rf`.

4. Confirm the move with the T01-written verifier:

   ```
   bash scripts/verify/m015-p02-constitution-moved.sh
   ```

   Expected: `PASS: constitution moved to .orchestrator/memory/constitution.md`. Exit 0.

5. Spot-check the constitution content survived verbatim. Run:

   ```
   grep -q "Principle I" .orchestrator/memory/constitution.md
   ```

   Expected exit 0. (The constitution uses `Principle I`, `Principle II`, etc., as section headings — this is one sentinel to confirm the body arrived intact.)

## Must-Haves

- `.orchestrator/memory/constitution.md` exists with the unmodified constitution content.
- `.specify/memory/constitution.md` no longer exists.
- `.specify/memory/` directory no longer exists.
- `scripts/verify/m015-p02-constitution-moved.sh` PASSes.

## Verification

Run:

```
bash scripts/verify/m015-p02-constitution-moved.sh
```

Expected stdout: `PASS: constitution moved to .orchestrator/memory/constitution.md`. Exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m015-p02-constitution-moved.sh` (from T01)
  - Key API: script takes no arguments, exits 0 on success with `PASS: constitution moved to .orchestrator/memory/constitution.md`, exits 1 with `FAIL: ...` on failure.
  - Behavioral contract: checks `.orchestrator/memory/constitution.md` exists, `.specify/memory/constitution.md` is absent, `.specify/memory/` directory is absent, and constitution body contains the word "Principle."

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — source file. Moved verbatim; content is not rewritten.

## Constraints

- Do NOT rewrite the constitution content. This is a verbatim path move.
- Do NOT create any other files under `.orchestrator/memory/`. Only `constitution.md` is moved.
- If `rmdir .specify/memory` fails, STOP. Do not use `rm -rf`. The failure means the directory contained more than just the constitution, which contradicts this task's precondition.
- Do NOT update any runtime references to `.specify/memory/constitution.md` in this task. T05 handles the reference sweep.
- Do NOT modify `scripts/state/resolve-root.sh`. T04 handles the resolver.

## Expected Output

After this task:
- `git status` shows: `.specify/memory/constitution.md` deleted, `.orchestrator/memory/constitution.md` added (or a rename if git detects it).
- `bash scripts/verify/m015-p02-constitution-moved.sh` prints `PASS: constitution moved to .orchestrator/memory/constitution.md` and exits 0.
- `.specify/memory/` directory does not exist.
- Runtime references to `.specify/memory/constitution.md` still exist in source files (T05 cleans them up).
