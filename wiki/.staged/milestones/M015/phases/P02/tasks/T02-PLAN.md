---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M015"
name: "Execute state tree migration (.specify/orchestrator/ → .orchestrator/)"
depends_on: [T01]
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- T01 is complete: six `scripts/verify/m015-p02-*.sh` verify scripts exist and are executable.
- `.specify/orchestrator/` exists with this project's live state: milestones (M001–M015), `KNOWLEDGE.md`, `DECISIONS.md`, `execution-log.jsonl`, `config.yml`, telemetry, locks, etc.
- `.orchestrator/` does NOT yet exist at the repo root (verified: `test ! -e .orchestrator`).
- `scripts/migrate/migrate-state.sh` exists and is the authoritative migration tool per FR-006. It performs a hard `mv` (atomic on same filesystem) with a `cp -R + rm -rf` fallback across filesystem boundaries. It emits `MIGRATED: <src> -> <dst>` on success.

## Description

Move the live orchestrator state tree from `.specify/orchestrator/` to `.orchestrator/` using the existing `scripts/migrate/migrate-state.sh` tool, then verify the move with `scripts/verify/m015-p02-state-tree-migrated.sh`.

This is the irreversible step. After this task runs, `.specify/orchestrator/` no longer exists on disk and all historical content — milestone summaries, phase summaries, task summaries, knowledge graph files, decisions, telemetry — lives at `.orchestrator/`. Historical content is preserved verbatim; no summary is rewritten (per [M007](../../../../../milestones/M007/index.md) no-graceful-degradation + the spec's "historical artifacts are immutable" constraint).

The migration is a `mv` or `cp -R + rm -rf` — it is purely a path relocation, not a content transformation. File mtimes and contents are preserved. This also means anywhere a summary, knowledge entry, or historical artifact text contains the string `.specify/orchestrator/` inside its markdown body, that string is preserved as-is — those are immutable references describing *where the artifact used to live*, not runtime references. The no-stale-state-refs verify script (T01) excludes `.orchestrator/` from its sweep precisely for this reason.

This task also confirms `.orchestrator/config.yml` has `state_root: ".orchestrator"` after the move (it already had that value before the move; the move just relocates the file so the resolver's config-rule will find it at the new canonical location).

## Steps

1. Pre-check: confirm the source exists and the destination is absent by running:

   ```
   bash scripts/verify/m015-p02-pre-migrate-check.sh
   ```

   First, create that helper at `scripts/verify/m015-p02-pre-migrate-check.sh` with this exact content and make it executable:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test -d .specify/orchestrator || { echo "FAIL: .specify/orchestrator/ missing — nothing to migrate"; exit 1; }
   test ! -e .orchestrator || { echo "FAIL: .orchestrator/ already exists — cannot migrate"; exit 1; }
   test -f .specify/orchestrator/config.yml || { echo "FAIL: source config.yml missing"; exit 1; }
   test -d .specify/orchestrator/milestones || { echo "FAIL: source milestones/ missing"; exit 1; }
   echo "PASS: pre-migration check — ready to migrate"
   ```

2. Perform the migration by running:

   ```
   bash scripts/migrate/migrate-state.sh
   ```

   Expected stdout: a single line `MIGRATED: <abs-path>/.specify/orchestrator -> <abs-path>/.orchestrator`. Exit 0.

   If the tool emits `SKIP:` instead, investigate — it means either the source is absent (step 1 should have caught that) or the destination was already populated (also caught by step 1). Do not proceed if `SKIP:` appears; stop and report.

3. Post-migration verification — run the T01-written state-tree verifier:

   ```
   bash scripts/verify/m015-p02-state-tree-migrated.sh
   ```

   Expected: `PASS: state tree migrated to .orchestrator/`. Exit 0.

4. Verify `.orchestrator/config.yml` still has `state_root: ".orchestrator"`:

   ```
   grep -q 'state_root: *".orchestrator"' .orchestrator/config.yml
   ```

   Expected exit 0. The config file was copied verbatim by the `mv`, so the value is the same as pre-migration (which was already `.orchestrator` — the config pre-declared the canonical location even while state lived under the bridge path).

5. Spot-check one migrated artifact per major category — this is a sanity check, not a verify-script gate. Each of these commands should exit 0:

   ```
   test -f [.orchestrator/KNOWLEDGE.md](../../../../../knowledge.md)
   test -f [.orchestrator/DECISIONS.md](../../../../../decisions.md)
   test -f .orchestrator/execution-log.jsonl
   test -d .orchestrator/milestones/M001
   test -d .orchestrator/milestones/M015
   test -f [.orchestrator/milestones/M015/M015-ROADMAP.md](../../../../../milestones/M015/M015-ROADMAP.md)
   test -f [.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md](../../../../../milestones/M015/phases/P01/P01-SUMMARY.md)
   ```

6. Verify the old path is gone:

   ```
   test ! -e .specify/orchestrator
   ```

   Expected exit 0.

## Must-Haves

- `.orchestrator/` directory exists and is populated with the migrated state.
- `.specify/orchestrator/` directory no longer exists.
- `.orchestrator/config.yml`, [`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md), [`.orchestrator/DECISIONS.md`](../../../../../decisions.md), `.orchestrator/execution-log.jsonl`, and `.orchestrator/milestones/` all present.
- `.orchestrator/config.yml` contains `state_root: ".orchestrator"`.
- `scripts/verify/m015-p02-state-tree-migrated.sh` PASSes.

## Verification

Run:

```
bash scripts/verify/m015-p02-state-tree-migrated.sh
```

Expected stdout: `PASS: state tree migrated to .orchestrator/`. Exit 0.

Also acceptable (additional confidence): `bash scripts/verify/m015-p02-pre-migrate-check.sh` should now FAIL with `FAIL: .specify/orchestrator/ missing — nothing to migrate` — that failure is the *expected post-state* signal (migration has happened). This is not a gate; only the state-tree-migrated script is the gate.

## Inputs

### From Previous Tasks

- `scripts/verify/m015-p02-state-tree-migrated.sh` (from T01)
  - Key API: script takes no arguments, exits 0 on success with `PASS: state tree migrated to .orchestrator/` on stdout, exits 1 with `FAIL: ...` on failure.
  - Behavioral contract: checks `.orchestrator/` presence, `.specify/orchestrator/` absence, and presence of `milestones/`, `KNOWLEDGE.md`, `DECISIONS.md`, `execution-log.jsonl`, `config.yml` under the new root.

### From Disk (Pre-existing)

- `scripts/migrate/migrate-state.sh` — authoritative migration tool. Invoke with no arguments to perform a real (non-dry-run) migration. Emits `MIGRATED: <src> -> <dst>` on success, `SKIP: <reason>` on no-op, `ERROR: <reason>` to stderr on failure.
- `.specify/orchestrator/` — source tree. Entire directory is moved verbatim; no file contents are rewritten.
- `.specify/orchestrator/config.yml` — already has `state_root: ".orchestrator"` (pre-declared by [M008](../../../../../milestones/M008/index.md)). The migration doesn't need to rewrite it.

## Constraints

- Do NOT rewrite any file content inside `.specify/orchestrator/` before or during the move. Historical artifacts (phase summaries, task summaries, knowledge entries, decisions, telemetry) are immutable.
- Do NOT modify `.specify/memory/constitution.md` or `.specify/memory/` in this task. T03 handles the constitution move as a separate step.
- Do NOT modify `scripts/state/resolve-root.sh` in this task. T04 handles the bridge-rule removal after the physical move is complete.
- Do NOT run any of the other five P02 verify scripts (`m015-p02-constitution-moved.sh`, `m015-p02-resolver-no-bridge.sh`, `m015-p02-resolver-resolves-new.sh`, `m015-p02-no-stale-state-refs.sh`, `m015-p02-doctor-clean.sh`) in this task. They are gated on T03/T04/T05 and will FAIL here.
- If `scripts/migrate/migrate-state.sh` fails, stop immediately. Do not attempt manual `mv` or `cp -R`. Report the failure and let recovery be driven by `git status` (since `.specify/orchestrator/` was tracked in git, any partial state can be restored via `git checkout`).
- Do NOT delete `.specify/` as a whole. `.specify/memory/` is handled by T03; other `.specify/` contents (if any remain after P01) are untouched.

## Expected Output

After this task:
- `git status` shows the rename: `.specify/orchestrator/` entries deleted, equivalent entries under `.orchestrator/` added. Depending on git's rename detection, this may appear as renames or as delete+add pairs.
- `bash scripts/verify/m015-p02-state-tree-migrated.sh` prints `PASS: state tree migrated to .orchestrator/` and exits 0.
- `.specify/orchestrator/` is gone.
- `.orchestrator/` is populated.
- `.specify/memory/constitution.md` is still present (T03 moves it).
- `scripts/state/resolve-root.sh` is unchanged (T04 modifies it).
