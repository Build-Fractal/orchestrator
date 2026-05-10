---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M015"
name: "Reference sweep — remove stale references to deleted paths"
depends_on: ["T03"]
---

## Prerequisites

- T01, T02, T03 have completed: `extension.yml`, dogfooded `/speckit.*` commands, `.specify/scripts/bash/`, the spec-kit-style `.specify/templates/` files, and the 3 extension-shape test artifacts are all gone. The preflight call-site bug is fixed.
- Retained code may still reference deleted paths via `grep`, `find`, hardcoded constants, documentation prose, or test allow-lists. This task removes those stale references.
- **Critical exemption**: migration adapters legitimately reference `.specify/` paths as *migration sources*, not as runtime paths. These files MUST be left alone:
  - `scripts/migrate/adapters/speckit.sh`
  - `scripts/state/detect-speckit.sh`
  - `scripts/dispatch/adapters/format/speckit.sh`
  - `commands/migrate.md`
  - `scripts/migrate/lib/detect-source.sh`
  - `scripts/migrate/migrate.sh`
  - `scripts/migrate/transform/report.sh`
  - Any other file under `scripts/migrate/`
  - Any test fixture under `tests/fixtures/` that simulates a spec-kit project for migration testing
- **Historical artifact exemption**: phase summary files, milestone summary files, and `CHANGELOG.md` historical entries reference the spec-kit hosting model in their narrative. These are immutable per the spec's cross-cutting "Historical artifact immutability" concern. Leave them alone:
  - `.specify/orchestrator/milestones/M00*/M00*-SUMMARY.md`
  - `.specify/orchestrator/milestones/M00*/phases/*/P*-SUMMARY.md`
  - `.specify/orchestrator/milestones/M00*/phases/*/tasks/T*-SUMMARY.md`
  - `.specify/orchestrator/handoff-*.md`
  - `.specify/orchestrator/KNOWLEDGE.md` (knowledge entries are append-only history)
  - `.specify/orchestrator/DECISIONS.md` (decision log is append-only history)
  - `CHANGELOG.md` historical entries (M015's new entry is added in P03; existing entries stay)

## Description

Sweep retained, non-exempt files for references to deleted paths. For each match outside the exemption list, remove the reference or restructure the surrounding code so the file no longer requires the deleted path.

The four reference patterns to sweep for:

1. `extension.yml` — anywhere it's named as a runtime input (allow-list patterns, doctor checks, docs that say "edit extension.yml")
2. `.specify/scripts/bash/` and the 5 script names within (`check-prerequisites.sh`, `common.sh`, `create-new-feature.sh`, `setup-plan.sh`, `update-agent-context.sh`)
3. `.specify/templates/commands/` and the 6 root-level template names (`agent-file-template.md`, `checklist-template.md`, `constitution-template.md`, `plan-template.md`, `spec-template.md`, `tasks-template.md`)
4. `.claude/commands/speckit.*.md` paths (the dogfooded slash commands)

Then write a verify script that confirms no non-exempt retained file contains these references.

## Steps

1. Run a discovery sweep across the repo, excluding the exemption directories. Use:

   ```
   grep -rln 'extension\.yml\|\.specify/scripts/bash\|\.specify/templates/commands\|agent-file-template\.md\|checklist-template\.md\|constitution-template\.md\|plan-template\.md\|spec-template\.md\|tasks-template\.md\|\.claude/commands/speckit\.' \
     --exclude-dir=node_modules \
     --exclude-dir=.git \
     --exclude-dir='.specify/orchestrator' \
     --exclude-dir='scripts/migrate' \
     --exclude-dir='tests/fixtures' \
     --exclude='CHANGELOG.md' \
     . 2>/dev/null
   ```

2. For each file in the discovery output, open it and decide:
   - **If the reference is in a doctor check or scope-enforcement allow-list** (e.g., `scripts/diagnostics/*.sh`, `scripts/verify/check-scope.sh`): remove the reference. The deleted files no longer need to be checked.
   - **If the reference is in current-state documentation** (e.g., `references/installation.md`, `docs/getting-started.md`, `README.md`, `CLAUDE.md`): leave the actual rewrite to P03 (Documentation Reframe). T04 only needs to verify the discovery. *However*, if a doc is a build-time artifact that the test suite parses (e.g., command listing files), update it now.
   - **If the reference is in a script that loads or sources a deleted file** (e.g., `source .specify/scripts/bash/common.sh`): remove the source line and any code that depended on it. If removing breaks the script's purpose, the script itself may be dead code — flag it as a deviation rather than guessing.
   - **If the reference is in the orchestrator's own command markdown files** (`commands/*.md`): rewrite the prose to remove instructions to edit `extension.yml` or use spec-kit helper scripts. This is fine to do in T04 since command markdown is operational, not narrative documentation.
   - **If the reference is in a test that asserts on the deleted path's existence**: that test was already addressed in T02 if it's an extension-registration test. Any other test asserting on a deleted path either gets deleted or rewritten depending on what it asserts.

3. Apply the edits decided in step 2.

4. Re-run the discovery grep from step 1. Output should contain only documentation files that are slated for P03's reframe.

5. Create `scripts/verify/m015-p01-no-stale-refs.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu

   # Search non-exempt directories for references to deleted paths.
   # Exemptions:
   #   - .git                       — VCS metadata
   #   - .specify/orchestrator      — historical artifacts (immutable)
   #   - scripts/migrate            — migration adapters (reference .specify as source)
   #   - tests/fixtures             — migration test fixtures (simulate spec-kit)
   #   - CHANGELOG.md               — historical entries
   #   - References handled by P03  — see ALLOW_DOC_REFRAME_FILES
   #
   # Documentation files slated for P03 reframe are tolerated here. T04
   # ensures non-doc references are gone; P03's verify scripts will
   # ensure doc references are gone after the reframe.

   ALLOW_DOC_REFRAME_FILES="README.md|CLAUDE.md|references/installation.md|references/architecture.md|docs/getting-started.md"

   matches=$(grep -rln \
     'extension\.yml\|\.specify/scripts/bash\|\.specify/templates/commands\|agent-file-template\.md\|checklist-template\.md\|constitution-template\.md\|plan-template\.md\|spec-template\.md\|tasks-template\.md\|\.claude/commands/speckit\.' \
     --exclude-dir=node_modules \
     --exclude-dir=.git \
     --exclude-dir='.specify/orchestrator' \
     --exclude-dir='scripts/migrate' \
     --exclude-dir='tests/fixtures' \
     --exclude='CHANGELOG.md' \
     . 2>/dev/null | grep -Ev "^\\./($ALLOW_DOC_REFRAME_FILES)$" || true)

   if [ -n "$matches" ]; then
     echo "FAIL: stale references to deleted paths remain in:"
     echo "$matches"
     exit 1
   fi
   echo "PASS: no stale references to deleted paths in non-doc files"
   ```

6. Make the verify script executable.

## Must-Haves

- After T04, no retained non-exempt, non-doc file in the repo contains a reference to a deleted path.
- The verify script `m015-p01-no-stale-refs.sh` exits 0.
- All migration adapters (per the exemption list) are byte-identical to their pre-T04 state.
- All historical artifacts (per the exemption list) are byte-identical to their pre-T04 state.

## Verification

```
bash scripts/verify/m015-p01-no-stale-refs.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M015/phases/P01
```

The first must print `PASS:` and exit 0. The second runs the full P01 must-haves verification and should also pass — if any earlier task's must-have regressed because T04 over-edited, this is where it surfaces.

## Inputs

### From Previous Tasks

- T01: deletion state — knowing what's gone tells the sweep what to look for
- T02: extension-test deletion state — eliminates one class of false positives
- T03: preflight fix — unrelated, but sequenced before T04 to keep the chain linear

### From Disk (Pre-existing)

- The entire repo, minus the exemption directories listed in Prerequisites
- Migration adapters (read-only — must remain untouched)
- Historical artifacts (read-only — must remain untouched)

## Constraints

- Do not edit any file in the exemption list.
- Do not rewrite documentation prose in the 5 doc files reserved for P03 (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`). T04 verifies that *non-doc* references are gone; P03 handles the doc reframe.
- If the discovery sweep finds dead scripts that reference deleted paths but cannot be salvaged by removing the source line, flag them as deviations rather than deleting them silently. Phase planning should record the disposition rather than T04 making the call alone.
- Do not delete `.specify/templates/orchestrator-config-default.yml` — it is the orchestrator's config template, not a spec-kit template.

## Expected Output

After this task:
- `git status` shows modifications to retained scripts/commands that referenced deleted paths
- `git status` shows a new file `scripts/verify/m015-p01-no-stale-refs.sh`
- The 5 documentation files reserved for P03 may still contain references — that is intentional and tolerated by the verify script's allow-list
- `bash scripts/verify/m015-p01-no-stale-refs.sh` prints `PASS:` and exits 0
- `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M015/phases/P01` prints `PASS:` and exits 0
