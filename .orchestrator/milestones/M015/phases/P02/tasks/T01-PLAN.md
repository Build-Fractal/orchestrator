---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M015"
name: "Write P02 verify scripts (pre-migration scaffolding)"
depends_on: []
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator`
- P01 is complete: `extension.yml` is gone, dogfooded `/speckit.*` commands are gone, `.specify/scripts/bash/` and `.specify/templates/` spec-kit-style templates are gone.
- The repo's live orchestrator state currently lives at `.specify/orchestrator/` (state not yet moved — this task only writes verification scaffolding; T02 performs the actual move).
- The repo contains `.specify/memory/constitution.md` (not yet moved — T03 handles that).
- `scripts/state/resolve-root.sh` still contains the five-rule resolver with Rule 4 as the `.specify/orchestrator/` bridge (T04 removes it).

## Description

Create the six P02 verification scripts that every downstream task in this phase will run against. Writing them first, before any destructive state move, means T02/T03/T04/T05's success is immediately provable, and the scripts themselves are reviewable before the state actually moves.

Each script follows the single-script-file shape (AD-19 / MEM007): no inline compound bash, no `$(… | …)` command-substitution-with-pipes, no plain subshells, no process substitution. Each script exits 0 with a `PASS:` line on success, exits 1 with a `FAIL:` line on failure, and emits nothing else to stdout on the happy path.

This task also creates `scripts/verify/m015-p02-no-stale-state-refs.sh`, which is the P02 equivalent of P01's stale-reference sweep — it asserts that no retained runtime file references `.specify/orchestrator/` or `.specify/memory/constitution.md`. Its allow-list is authoritative for T05's sweep: any file T05 updates must either stop referencing the old paths or be added to the allow-list for a documented reason (migration adapter, historical artifact, or P03-reserved doc).

All six scripts are written to be safe to run *before* migration too — they will FAIL pre-migration (their exact purpose is to gate migration completion), which is the expected behavior during T01. They begin PASSing once T02–T05 complete.

## Steps

1. Create `scripts/verify/m015-p02-state-tree-migrated.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: .orchestrator/ exists with expected structure AND .specify/orchestrator/ is gone.
   test -d .orchestrator || { echo "FAIL: .orchestrator/ directory missing"; exit 1; }
   test ! -e .specify/orchestrator || { echo "FAIL: .specify/orchestrator/ still exists"; exit 1; }
   test -d .orchestrator/milestones || { echo "FAIL: .orchestrator/milestones missing"; exit 1; }
   test -f .orchestrator/KNOWLEDGE.md || { echo "FAIL: .orchestrator/KNOWLEDGE.md missing"; exit 1; }
   test -f .orchestrator/DECISIONS.md || { echo "FAIL: .orchestrator/DECISIONS.md missing"; exit 1; }
   test -f .orchestrator/execution-log.jsonl || { echo "FAIL: .orchestrator/execution-log.jsonl missing"; exit 1; }
   test -f .orchestrator/config.yml || { echo "FAIL: .orchestrator/config.yml missing"; exit 1; }
   echo "PASS: state tree migrated to .orchestrator/"
   ```

2. Create `scripts/verify/m015-p02-constitution-moved.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: constitution at .orchestrator/memory/constitution.md; legacy .specify/memory/ gone.
   test -f .orchestrator/memory/constitution.md || { echo "FAIL: .orchestrator/memory/constitution.md missing"; exit 1; }
   test ! -e .specify/memory/constitution.md || { echo "FAIL: .specify/memory/constitution.md still exists"; exit 1; }
   test ! -d .specify/memory || { echo "FAIL: .specify/memory/ directory still exists"; exit 1; }
   # Cheap content sanity check: file should mention "Principle" at least once.
   grep -q "Principle" .orchestrator/memory/constitution.md || { echo "FAIL: constitution body looks wrong (no 'Principle' found)"; exit 1; }
   echo "PASS: constitution moved to .orchestrator/memory/constitution.md"
   ```

3. Create `scripts/verify/m015-p02-resolver-no-bridge.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: scripts/state/resolve-root.sh contains no bridge rule.
   RESOLVER=scripts/state/resolve-root.sh
   test -f "$RESOLVER" || { echo "FAIL: $RESOLVER missing"; exit 1; }
   # Must NOT contain the bridge source string.
   if grep -q 'bridge:.specify/orchestrator' "$RESOLVER"; then
     echo "FAIL: bridge source rule still present in $RESOLVER"
     exit 1
   fi
   # Must NOT contain a directory test against .specify/orchestrator.
   if grep -q '\-d "\$repo_root/\.specify/orchestrator"' "$RESOLVER"; then
     echo "FAIL: bridge directory test still present in $RESOLVER"
     exit 1
   fi
   # Must NOT contain the literal assignment to .specify/orchestrator as a resolved path.
   if grep -q 'resolved=".specify/orchestrator"' "$RESOLVER"; then
     echo "FAIL: bridge assignment still present in $RESOLVER"
     exit 1
   fi
   # Must NOT mention the bridge rule in the header comment block.
   if grep -q 'migration bridge' "$RESOLVER"; then
     echo "FAIL: bridge rule header comment still present in $RESOLVER"
     exit 1
   fi
   echo "PASS: resolver has no bridge rule"
   ```

4. Create `scripts/verify/m015-p02-resolver-resolves-new.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: resolver emits root=.orchestrator source=existing:.orchestrator
   # when invoked from repo root with no overrides.
   unset ORCHESTRATOR_ROOT
   out=$(bash scripts/state/resolve-root.sh --verbose)
   echo "$out" | grep -q '^root=\.orchestrator$' || { echo "FAIL: expected root=.orchestrator, got:"; echo "$out"; exit 1; }
   echo "$out" | grep -q '^source=existing:\.orchestrator$' || { echo "FAIL: expected source=existing:.orchestrator, got:"; echo "$out"; exit 1; }
   echo "PASS: resolver resolves to .orchestrator via existing:.orchestrator rule"
   ```

5. Create `scripts/verify/m015-p02-no-stale-state-refs.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Sweep retained runtime files for stale references to .specify/orchestrator
   # or .specify/memory/constitution. Exempts: migration adapters, historical
   # artifacts, and P03-reserved docs.
   #
   # ALLOW_P03_DOCS: reframed by P03 (tolerated here).
   # ALLOW_MIGRATION: migration adapters — target .specify as migration source.
   # ALLOW_SELF_REFERENCE: P02 verify scripts that name old paths in assertions.
   ALLOW_P03_DOCS='README\.md|CLAUDE\.md|references/architecture\.md|references/installation\.md|references/constitution-walkthrough\.md|references/engine\.md|references/events\.md|references/errors\.md|references/recipes\.md|references/file-formats\.md|references/state-machine\.md|references/tier-definitions\.md|docs/getting-started\.md|docs/knowledge-management\.md|docs/hook-development\.md|docs/recipe-authoring\.md|scripts/AGENTS\.md'
   ALLOW_MIGRATION='commands/migrate\.md|scripts/state/detect-speckit\.sh|scripts/dispatch/adapters/format/speckit\.sh|scripts/migrate/.*'
   ALLOW_SELF_REFERENCE='scripts/verify/m015-p02-.*\.sh|scripts/verify/m015-p01-no-stale-refs\.sh|scripts/verify/m003-p07-.*\.sh|scripts/verify/m008-p04-resolve-root-bridge\.sh|scripts/verify/m008-p04-migrate-state-.*\.sh'
   matches=$(grep -rln \
     -e '\.specify/orchestrator' \
     -e '\.specify/memory/constitution' \
     --exclude-dir=node_modules \
     --exclude-dir=.git \
     --exclude-dir='.orchestrator' \
     --exclude-dir='tests/fixtures' \
     --exclude='CHANGELOG.md' \
     . 2>/dev/null \
     | grep -Ev '^\./(\.orchestrator|tests/fixtures|specs|\.planning)/' \
     | grep -Ev "^\./($ALLOW_P03_DOCS)$" \
     | grep -Ev "^\./($ALLOW_MIGRATION)$" \
     | grep -Ev "^\./($ALLOW_SELF_REFERENCE)$" \
     || true)
   if [ -n "$matches" ]; then
     echo "FAIL: stale state-path references remain in:"
     echo "$matches"
     exit 1
   fi
   echo "PASS: no stale state-path references in non-exempt runtime files"
   ```

6. Create `scripts/verify/m015-p02-doctor-clean.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: scripts/diagnostics/run-doctor.sh exits 0 with no FAIL lines.
   test -x scripts/diagnostics/run-doctor.sh || { echo "FAIL: run-doctor.sh missing or not executable"; exit 1; }
   out=$(bash scripts/diagnostics/run-doctor.sh 2>&1 || true)
   rc=$?
   if [ "$rc" != "0" ]; then
     echo "FAIL: run-doctor.sh exited $rc"
     echo "$out"
     exit 1
   fi
   if echo "$out" | grep -q '^FAIL:'; then
     echo "FAIL: run-doctor.sh reported failures:"
     echo "$out" | grep '^FAIL:'
     exit 1
   fi
   echo "PASS: doctor reports clean state"
   ```

7. Make all six scripts executable by running `chmod +x scripts/verify/m015-p02-state-tree-migrated.sh scripts/verify/m015-p02-constitution-moved.sh scripts/verify/m015-p02-resolver-no-bridge.sh scripts/verify/m015-p02-resolver-resolves-new.sh scripts/verify/m015-p02-no-stale-state-refs.sh scripts/verify/m015-p02-doctor-clean.sh`.

8. Do NOT run any of the six scripts at task end — they are designed to FAIL pre-migration (state has not yet moved). The only verification in this task is that all six files exist, are non-empty, are executable, and parse as valid bash (step 9).

9. For each script, verify it parses as valid bash by running `bash -n <script>` and confirming exit 0. Use `scripts/verify/m015-p02-t01-parse-check.sh` created inline: write a helper at `scripts/verify/m015-p02-t01-parse-check.sh` that loops over the six files and runs `bash -n` on each. Script content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   for s in \
     scripts/verify/m015-p02-state-tree-migrated.sh \
     scripts/verify/m015-p02-constitution-moved.sh \
     scripts/verify/m015-p02-resolver-no-bridge.sh \
     scripts/verify/m015-p02-resolver-resolves-new.sh \
     scripts/verify/m015-p02-no-stale-state-refs.sh \
     scripts/verify/m015-p02-doctor-clean.sh; do
     test -x "$s" || { echo "FAIL: $s not executable"; exit 1; }
     bash -n "$s" || { echo "FAIL: $s has syntax errors"; exit 1; }
   done
   echo "PASS: all 6 P02 verify scripts parse and are executable"
   ```

   Make `scripts/verify/m015-p02-t01-parse-check.sh` executable.

## Must-Haves

- Six P02 verify scripts exist at the paths enumerated in Steps 1–6, each executable, each parseable by `bash -n`.
- One parse-check helper exists at `scripts/verify/m015-p02-t01-parse-check.sh`, executable, parseable.
- No other files are created or modified by this task. No state is moved. No runtime references are rewritten.

## Verification

Run:

```
bash scripts/verify/m015-p02-t01-parse-check.sh
```

Expected stdout: `PASS: all 6 P02 verify scripts parse and are executable`. Exit 0.

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies within P02.

### From Disk (Pre-existing)

- `scripts/verify/m015-p01-no-stale-refs.sh` — read as a structural model for the stale-reference sweep pattern. Copy the `grep -rln + --exclude-dir + post-filter with grep -Ev` shape; adjust the patterns and allow-list for P02's scope (state paths, not deleted-host paths).
- `scripts/state/resolve-root.sh` — read to confirm the exact string that the `--verbose` flag emits (expected: `root=<path>` on one line, `source=<rule>` on a second line). The resolver-resolves-new script relies on these exact strings.
- `scripts/diagnostics/run-doctor.sh` — read to confirm it is executable and emits `FAIL:` prefixed lines on failure. The doctor-clean script relies on this convention.

## Constraints

- All six scripts MUST use single-script-file shape (AD-19 / MEM007). No `$(cmd | …)`, no process substitution `<(…)`, no plain subshells `( cmd1 && cmd2 )`, no compound `;`-chained statements beyond two commands, no inline `for`/`if`/`while` embedded in a single shell invocation, no heredocs piping into further commands.
- Scripts MUST exit 0 on success with a single `PASS:` line and exit 1 on failure with a single `FAIL:` line followed by diagnostic output. No other stdout on happy path.
- Bash 3.2 compatible — no `declare -A`, no `${var,,}` lowercase expansion, no `mapfile`.
- Do NOT run the six verify scripts (except via the parse-check helper with `bash -n`). They are designed to FAIL pre-migration; running them would emit misleading output.
- Do NOT touch `.specify/orchestrator/` or `.specify/memory/`. This task is pre-move scaffolding only.
- Do NOT create any verify script outside `scripts/verify/m015-p02-*.sh` naming.

## Expected Output

After this task:
- `git status` shows 7 new files under `scripts/verify/` matching `m015-p02-*.sh`.
- `bash scripts/verify/m015-p02-t01-parse-check.sh` prints `PASS: all 6 P02 verify scripts parse and are executable` and exits 0.
- `.specify/orchestrator/` still exists (will be moved in T02).
- `.specify/memory/constitution.md` still exists (will be moved in T03).
- `scripts/state/resolve-root.sh` is unchanged (will be modified in T04).
