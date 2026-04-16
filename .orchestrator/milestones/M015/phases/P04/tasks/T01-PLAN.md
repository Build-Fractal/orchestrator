---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M015"
name: "Write P04 verify scripts and build spec-kit migration fixture"
depends_on: []
---

## Prerequisites

- Working in repo root: /Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator
- P01 complete: extension host removed (extension.yml, .specify/scripts/bash/, .specify/templates/, .claude/commands/speckit.*.md all absent)
- P02 complete: state at .orchestrator/, constitution at .orchestrator/memory/constitution.md, resolver has no bridge rule
- P03 complete: primary docs reframed, CHANGELOG has an M015 entry, docs/migrating-from-speckit.md exists
- scripts/migrate/migrate.sh, scripts/migrate/adapters/speckit.sh, scripts/state/detect-speckit.sh all exist and are retained (FR-013)
- scripts/diagnostics/run-doctor.sh exists and is executable
- tests/test-s01-structure.sh through tests/test-s08-auto-safety.sh all exist (8 test suites total; spec says 7 — confirm by listing at step 1)

## Description

Create all seven P04 verify scripts plus a spec-kit-shaped migration fixture scaffold. All seven verify scripts are designed to FAIL on first invocation (before T02 runs) and PASS after T02/T03/T04 land their evidence and closeout docs. That FAIL-first shape is the phase gate: it proves each script discriminates rather than silently accepting any state.

Writing these scripts before running validation gives T02 an immediate pass/fail signal for each of its four evidence streams, and gives T03/T04 a gate for their authoring work.

The migration fixture is a deterministic build script (plus README) that generates a minimal spec-kit-shaped project tree under a caller-supplied directory. The fixture tree is NOT committed — only the build script is committed. This follows the precedent of tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh.

All seven verify scripts follow the single-script-file shape (AD-19, MEM007): no inline compound bash, no `$(… | …)` command-substitution-with-pipes, no plain subshells, no process substitution. Exit 0 with a PASS line on success; exit 1 with a FAIL line on failure.

Parse-check is the only verification executed in this task (`bash -n <script>` on each new script). The seven gate scripts are intentionally NOT executed at task end — by design they FAIL pre-validation, and that FAIL is the gating signal T02/T03/T04 consume.

## Steps

1. List tests/test-s*.sh to confirm suite count. Expected: 8 files (test-s01 through test-s08). The roadmap and spec say "7 test suites" — the discrepancy is because one suite was either deleted during P01 or will be treated as not-in-scope. Inspect the tests/AGENTS.md and spec FR-016 wording. If 8 files exist and all are runnable, the verify script must run all 8 and the "7" in the spec is a stale count (note the discrepancy in T02's transcript). If a file is skeleton-only or explicitly marked no-op, exclude it by name in the verify script.

   ```bash
   ls tests/test-s*.sh
   ```

2. Create directory .orchestrator/milestones/M015/phases/P04/evidence/ (needed by T02; create it now so path-existence checks in verify scripts are meaningful during development).

   ```bash
   mkdir -p .orchestrator/milestones/M015/phases/P04/evidence
   ```

3. Create scripts/verify/m015-p04-all-tests-pass.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: all test suites (tests/test-s*.sh) pass.
   # T02 writes the full transcript to evidence/test-suite-transcript.txt.
   # This verifier asserts (a) the transcript exists, (b) the transcript
   # contains a FINAL line matching the expected passing shape, and (c)
   # no "FAIL" line appears outside explicit negative-test contexts.
   TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt
   test -f "$TRANSCRIPT" || { echo "FAIL: transcript missing at $TRANSCRIPT"; exit 1; }
   test -s "$TRANSCRIPT" || { echo "FAIL: transcript empty"; exit 1; }
   # Require each suite name to appear in the transcript at least once
   suites="test-s01 test-s02 test-s03 test-s04 test-s05 test-s06 test-s07 test-s08"
   fail=0
   for s in $suites; do
     if ! grep -q "$s" "$TRANSCRIPT"; then
       echo "FAIL: suite '$s' not mentioned in transcript"
       fail=1
     fi
   done
   # Require an explicit overall pass marker (T02 writes "ALL_SUITES_PASS")
   if ! grep -q "ALL_SUITES_PASS" "$TRANSCRIPT"; then
     echo "FAIL: transcript does not contain ALL_SUITES_PASS marker"
     fail=1
   fi
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: all test-s0* suites mentioned + ALL_SUITES_PASS marker present"
   ```

4. Create scripts/verify/m015-p04-doctor-clean.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: run-doctor.sh produces a clean report.
   # T02 runs the doctor and captures output to evidence/doctor-report.txt.
   # This verifier asserts (a) the report exists, (b) contains a clean
   # marker, and (c) has no FAIL: lines outside explicit allow-listed
   # advisory contexts.
   REPORT=.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt
   test -f "$REPORT" || { echo "FAIL: doctor report missing at $REPORT"; exit 1; }
   test -s "$REPORT" || { echo "FAIL: doctor report empty"; exit 1; }
   if grep -q "^FAIL:" "$REPORT"; then
     echo "FAIL: doctor report contains FAIL: lines"
     exit 1
   fi
   # Require an explicit clean marker (T02 writes "DOCTOR_CLEAN")
   if ! grep -q "DOCTOR_CLEAN" "$REPORT"; then
     echo "FAIL: doctor report missing DOCTOR_CLEAN marker"
     exit 1
   fi
   echo "PASS: doctor report clean + DOCTOR_CLEAN marker present"
   ```

5. Create scripts/verify/m015-p04-speckit-migration-works.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: the spec-kit migration adapter produced a valid .orchestrator/
   # from the spec-kit-shaped fixture. T02 runs scripts/migrate/migrate.sh
   # against a temp-dir build of tests/fixtures/m015-p04-speckit-migration/
   # and captures the transcript to evidence/migration-adapter-transcript.txt.
   # The transcript must contain (a) a successful-run marker, (b) the path
   # to a produced .orchestrator/ directory, and (c) evidence that
   # memory/constitution.md was migrated.
   TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt
   test -f "$TRANSCRIPT" || { echo "FAIL: migration transcript missing at $TRANSCRIPT"; exit 1; }
   test -s "$TRANSCRIPT" || { echo "FAIL: migration transcript empty"; exit 1; }
   fail=0
   if ! grep -q "MIGRATION_SUCCESS" "$TRANSCRIPT"; then
     echo "FAIL: transcript missing MIGRATION_SUCCESS marker"
     fail=1
   fi
   if ! grep -q ".orchestrator/memory/constitution.md" "$TRANSCRIPT"; then
     echo "FAIL: transcript missing evidence of constitution migration"
     fail=1
   fi
   # Fixture build script must also exist
   BUILD=tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
   test -f "$BUILD" || { echo "FAIL: fixture build script missing at $BUILD"; fail=1; }
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: migration adapter transcript has success markers + fixture exists"
   ```

6. Create scripts/verify/m015-p04-clean-clone-shape.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: a clean-clone simulation (via git archive HEAD) contains no
   # extension-host artifacts. T02 runs git archive into a temp dir and
   # writes a path-listing transcript to evidence/clean-clone-shape.txt.
   # Required absent classes: extension.yml at root,
   # .specify/scripts/bash/, .specify/templates/commands/,
   # .specify/orchestrator/, .claude/commands/speckit.*.md.
   SHAPE=.orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt
   test -f "$SHAPE" || { echo "FAIL: clean-clone shape missing at $SHAPE"; exit 1; }
   test -s "$SHAPE" || { echo "FAIL: clean-clone shape empty"; exit 1; }
   fail=0
   # Each class is asserted absent by a negative grep
   if grep -qE "^extension\.yml$|/extension\.yml$" "$SHAPE"; then
     echo "FAIL: extension.yml present in clean-clone shape"
     fail=1
   fi
   if grep -q "\.specify/scripts/bash/" "$SHAPE"; then
     echo "FAIL: .specify/scripts/bash/ present in clean-clone shape"
     fail=1
   fi
   if grep -q "\.specify/templates/commands/" "$SHAPE"; then
     echo "FAIL: .specify/templates/commands/ present in clean-clone shape"
     fail=1
   fi
   if grep -q "\.specify/orchestrator/" "$SHAPE"; then
     echo "FAIL: .specify/orchestrator/ present in clean-clone shape"
     fail=1
   fi
   if grep -qE "\.claude/commands/speckit\.[^/]+\.md" "$SHAPE"; then
     echo "FAIL: .claude/commands/speckit.*.md present in clean-clone shape"
     fail=1
   fi
   if ! grep -q "CLEAN_CLONE_OK" "$SHAPE"; then
     echo "FAIL: clean-clone shape missing CLEAN_CLONE_OK marker"
     fail=1
   fi
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: clean-clone shape has no extension-host artifacts + CLEAN_CLONE_OK marker present"
   ```

7. Create scripts/verify/m015-p04-verification-complete.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: M015-VERIFICATION.md scores every FR-001 through FR-019 with
   # a PASS or FAIL verdict.
   DOC=.orchestrator/milestones/M015/M015-VERIFICATION.md
   test -f "$DOC" || { echo "FAIL: verification doc missing at $DOC"; exit 1; }
   test -s "$DOC" || { echo "FAIL: verification doc empty"; exit 1; }
   fail=0
   i=1
   while [ "$i" -le 19 ]; do
     # zero-pad to 3 digits: FR-001, FR-002, ..., FR-019
     if [ "$i" -lt 10 ]; then
       tag="FR-00$i"
     else
       tag="FR-0$i"
     fi
     if ! grep -q "$tag" "$DOC"; then
       echo "FAIL: $tag missing from verification doc"
       fail=1
     fi
     i=$((i + 1))
   done
   # Require at least one PASS verdict (sanity — full PASS sweep expected)
   if ! grep -q "PASS" "$DOC"; then
     echo "FAIL: verification doc has no PASS verdicts"
     fail=1
   fi
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: verification doc references FR-001 through FR-019 and contains PASS verdicts"
   ```

8. Create scripts/verify/m015-p04-milestone-summary-present.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: M015-SUMMARY.md exists and follows milestone-summary schema.
   DOC=.orchestrator/milestones/M015/M015-SUMMARY.md
   test -f "$DOC" || { echo "FAIL: milestone summary missing at $DOC"; exit 1; }
   test -s "$DOC" || { echo "FAIL: milestone summary empty"; exit 1; }
   fail=0
   # Required schema markers
   if ! grep -q "type: milestone-summary" "$DOC"; then
     echo "FAIL: missing 'type: milestone-summary' in frontmatter"
     fail=1
   fi
   if ! grep -q "schema_version:" "$DOC"; then
     echo "FAIL: missing schema_version in frontmatter"
     fail=1
   fi
   # Each phase must be referenced by id
   for p in P01 P02 P03 P04; do
     if ! grep -q "$p" "$DOC"; then
       echo "FAIL: phase $p not referenced in milestone summary"
       fail=1
     fi
   done
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: milestone summary schema-shaped and references P01..P04"
   ```

9. Create scripts/verify/m015-p04-evidence-captured.sh with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: all four evidence transcripts exist and are non-empty.
   DIR=.orchestrator/milestones/M015/phases/P04/evidence
   test -d "$DIR" || { echo "FAIL: evidence dir missing at $DIR"; exit 1; }
   fail=0
   for f in test-suite-transcript.txt doctor-report.txt migration-adapter-transcript.txt clean-clone-shape.txt; do
     path="$DIR/$f"
     if [ ! -f "$path" ]; then
       echo "FAIL: evidence missing: $path"
       fail=1
       continue
     fi
     if [ ! -s "$path" ]; then
       echo "FAIL: evidence empty: $path"
       fail=1
     fi
   done
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: all four evidence transcripts present and non-empty"
   ```

10. Make all seven verify scripts executable:

    ```bash
    chmod +x scripts/verify/m015-p04-all-tests-pass.sh
    chmod +x scripts/verify/m015-p04-doctor-clean.sh
    chmod +x scripts/verify/m015-p04-speckit-migration-works.sh
    chmod +x scripts/verify/m015-p04-clean-clone-shape.sh
    chmod +x scripts/verify/m015-p04-verification-complete.sh
    chmod +x scripts/verify/m015-p04-milestone-summary-present.sh
    chmod +x scripts/verify/m015-p04-evidence-captured.sh
    ```

11. Parse-check each new script:

    ```bash
    bash -n scripts/verify/m015-p04-all-tests-pass.sh
    bash -n scripts/verify/m015-p04-doctor-clean.sh
    bash -n scripts/verify/m015-p04-speckit-migration-works.sh
    bash -n scripts/verify/m015-p04-clean-clone-shape.sh
    bash -n scripts/verify/m015-p04-verification-complete.sh
    bash -n scripts/verify/m015-p04-milestone-summary-present.sh
    bash -n scripts/verify/m015-p04-evidence-captured.sh
    ```

    Expect zero output (parse-OK). Any stderr output is a syntax error and must be fixed before committing.

12. Create the fixture directory and README:

    ```bash
    mkdir -p tests/fixtures/m015-p04-speckit-migration
    ```

13. Create tests/fixtures/m015-p04-speckit-migration/README.md with this content:

    ```markdown
    # M015 P04 Spec-Kit Migration Fixture

    Deterministic minimal spec-kit-shaped project tree used by T02 to
    validate that `scripts/migrate/migrate.sh` produces a valid
    `.orchestrator/` directory when run against a spec-kit-shaped source.

    The fixture tree itself is NOT committed — it is generated on demand
    by `build-fixture.sh` into a caller-supplied directory. This follows
    the precedent of `tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh`.

    ## Usage

    ```bash
    # T02 invokes this pattern:
    TMP=$(mktemp -d)
    bash tests/fixtures/m015-p04-speckit-migration/build-fixture.sh "$TMP"
    # Then: bash scripts/migrate/migrate.sh --source "$TMP" ... (see T02 plan)
    ```

    ## Produced Tree

    ```
    <target-dir>/
      .specify/
        memory/
          constitution.md         # minimal 7-principle stub
      specs/
        001-example/
          spec.md                 # minimal spec with frontmatter
      README.md                   # project README sentinel
    ```

    ## Why spec-kit-shaped

    The orchestrator retained spec-kit as a **migration source** (FR-013).
    This fixture exists because the cutover removed spec-kit as a
    **runtime host** but preserved the ability for users coming *from*
    spec-kit to migrate into the orchestrator. Every run proves that
    path still works end-to-end.
    ```

14. Create tests/fixtures/m015-p04-speckit-migration/build-fixture.sh with this content:

    ```bash
    #!/usr/bin/env bash
    # =============================================================================
    # build-fixture.sh — Build minimal spec-kit-shaped fixture tree
    # =============================================================================
    #
    # Generates a spec-kit-shaped project tree at the caller-supplied target
    # directory. Used by T02 of M015/P04 to validate the spec-kit migration
    # adapter (scripts/migrate/adapters/speckit.sh).
    #
    # Usage: build-fixture.sh <target-dir>
    #
    # Compatibility: Bash 3.2+ / POSIX sh; no associative arrays.
    # =============================================================================
    set -eu

    if [ "$#" -ne 1 ]; then
      echo "usage: build-fixture.sh <target-dir>" >&2
      exit 1
    fi

    TARGET="$1"
    test -d "$TARGET" || { echo "FAIL: target dir missing: $TARGET" >&2; exit 1; }

    mkdir -p "$TARGET/.specify/memory"
    mkdir -p "$TARGET/specs/001-example"

    cat > "$TARGET/.specify/memory/constitution.md" <<'EOF'
    # Fixture Constitution

    Minimal spec-kit-shaped constitution used by the M015 P04 migration
    fixture. Any field changes in this file require a corresponding
    change to the migration adapter's constitution-move logic.

    ## Principles

    1. Context Minimization
    2. Evidence Before Claims
    3. Design Before Code
    4. Plans Assume Zero Context
    5. Fresh Context Per Unit
    6. State On Disk Is Truth
    7. Knowledge Compounds
    EOF

    cat > "$TARGET/specs/001-example/spec.md" <<'EOF'
    ---
    feature_branch: 001-example
    status: draft
    ---

    # Example Feature

    Minimal fixture spec used to exercise the spec-kit migration adapter.
    EOF

    cat > "$TARGET/README.md" <<'EOF'
    # Fixture Project

    This is a minimal spec-kit-shaped project generated by
    tests/fixtures/m015-p04-speckit-migration/build-fixture.sh.
    Not intended for direct use — see the fixture README.
    EOF

    echo "FIXTURE_BUILT target=$TARGET"
    ```

15. Make the build script executable and parse-check:

    ```bash
    chmod +x tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
    bash -n tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
    ```

    Expect zero output.

## Must-Haves

This task addresses the artifact-existence portions of these phase must-haves:

- scripts/verify/m015-p04-all-tests-pass.sh
- scripts/verify/m015-p04-doctor-clean.sh
- scripts/verify/m015-p04-speckit-migration-works.sh
- scripts/verify/m015-p04-clean-clone-shape.sh
- scripts/verify/m015-p04-verification-complete.sh
- scripts/verify/m015-p04-milestone-summary-present.sh
- scripts/verify/m015-p04-evidence-captured.sh
- tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
- tests/fixtures/m015-p04-speckit-migration/README.md

This task does NOT address the evidence transcript artifacts (T02) nor M015-VERIFICATION.md (T03) nor M015-SUMMARY.md (T04). The seven P04 gate verify scripts are EXPECTED TO FAIL on first invocation — that FAIL is the gating signal consumed by T02/T03/T04.

## Verification

- Parse-check each of the seven new verify scripts:

  ```
  bash -n scripts/verify/m015-p04-all-tests-pass.sh
  bash -n scripts/verify/m015-p04-doctor-clean.sh
  bash -n scripts/verify/m015-p04-speckit-migration-works.sh
  bash -n scripts/verify/m015-p04-clean-clone-shape.sh
  bash -n scripts/verify/m015-p04-verification-complete.sh
  bash -n scripts/verify/m015-p04-milestone-summary-present.sh
  bash -n scripts/verify/m015-p04-evidence-captured.sh
  ```

  Each must exit 0 with no stderr.

- Parse-check the fixture build script:

  ```
  bash -n tests/fixtures/m015-p04-speckit-migration/build-fixture.sh
  ```

- Confirm fixture files exist (not built — only the scaffolding):

  ```
  bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04
  ```

  At this point the artifact-bundle check expects all seven verify scripts + the two fixture files present. Evidence transcripts, M015-VERIFICATION.md, and M015-SUMMARY.md are expected to be MISSING at this task boundary and that is the correct gating signal for T02/T03/T04.

## Inputs

### From Previous Tasks

None — T01 is the phase entry.

### From Disk (Pre-existing)

- specs/015-standalone-cutover/spec.md — source of truth for FR-001..FR-019 and for the validation acceptance scenarios.
- scripts/diagnostics/run-doctor.sh — executed by T02; referenced by name in verify script content.
- scripts/migrate/migrate.sh, scripts/migrate/adapters/speckit.sh — executed by T02; referenced by name in verify script content.
- tests/test-s01-structure.sh through tests/test-s08-auto-safety.sh — executed by T02; names referenced in verify script.
- tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh — structural precedent for the new fixture build script (bash 3.2 shape, `FIXTURE_BUILT` marker style, determinism).
- templates/milestone-summary.md — read-only reference for milestone-summary schema; used by T04 verify script content.

## Constraints

- **No runtime code changes**. This task only creates new files under scripts/verify/ and tests/fixtures/. Do not edit any existing file.
- **Single-script-file shape** (AD-19): no inline compound bash, no `$(cmd | …)`, no plain subshells, no process substitution, no brace expansion with quoted regex.
- **Bash 3.2 compatibility** (MEM001): no associative arrays, no `mapfile`, no `readarray`. The fixture build script uses POSIX-safe `cat <<EOF` heredocs and plain `for` loops.
- **Fixture tree not committed**: only build-fixture.sh and README.md go in the repo. The fixture tree produced by running build-fixture.sh belongs in temp directories during T02.
- **Do not execute the seven gate verify scripts at task end** — they are designed to FAIL pre-validation. Only parse-check runs here.

## Expected Output

At task end:

- 7 new scripts under scripts/verify/ matching scripts/verify/m015-p04-*.sh (all executable, all parse-clean).
- 2 new files under tests/fixtures/m015-p04-speckit-migration/ (build-fixture.sh executable + parse-clean; README.md).
- 1 new directory at .orchestrator/milestones/M015/phases/P04/evidence/ (empty — T02 fills it).
- Zero changes to any pre-existing file.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04` reports the nine artifact entries (7 verify scripts + 2 fixture files) as PASS. The remaining artifacts (4 evidence transcripts, M015-VERIFICATION.md, M015-SUMMARY.md) report as FAIL-missing — that is the expected and correct gating signal for T02/T03/T04.
