---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M015"
name: "Execute the four validation streams and capture evidence"
depends_on: [T01]
---

## Prerequisites

- T01 complete: all seven scripts/verify/m015-p04-*.sh exist, tests/fixtures/m015-p04-speckit-migration/build-fixture.sh and README.md exist, and .orchestrator/milestones/M015/phases/P04/evidence/ directory exists (empty at task start).
- Working directory is repo root.
- No uncommitted changes outside T01's deliverables that would affect test suites or doctor output.
- git is available; mktemp is available; run-doctor.sh, migrate.sh, and all tests/test-s*.sh are executable.

## Description

Execute the four validation streams and write an evidence transcript for each under `.orchestrator/milestones/M015/phases/P04/evidence/`. The four streams are:

1. **Test suite sweep** — run every `tests/test-s*.sh` and capture combined output plus per-suite pass/fail status.
2. **Doctor report** — run `bash scripts/diagnostics/run-doctor.sh` and capture the output.
3. **Migration adapter run** — build the spec-kit-shaped fixture into a temp directory, run `bash scripts/migrate/migrate.sh` against it, and capture the transcript plus a directory listing of the produced `.orchestrator/` tree.
4. **Clean-clone shape check** — run `git archive HEAD | tar -x` into a temp directory and capture a file listing of the extracted tree (to confirm no extension-host artifacts are present).

Each stream writes a transcript to a named file under `evidence/` and ends with a specific marker line (`ALL_SUITES_PASS`, `DOCTOR_CLEAN`, `MIGRATION_SUCCESS`, `CLEAN_CLONE_OK`) that the T01 verify scripts key on.

After all four streams run, execute each of the seven T01 gate scripts and confirm they all PASS.

## Steps

1. Run the test suite sweep. Write a wrapper that runs all eight `tests/test-s*.sh` in sequence, captures both stdout and stderr from each, and summarizes pass/fail. Append `ALL_SUITES_PASS` only if every suite exits 0.

   ```bash
   TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt
   : > "$TRANSCRIPT"
   echo "=== Test Suite Sweep — $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$TRANSCRIPT"
   overall=0
   for suite in tests/test-s01-structure.sh tests/test-s02-state-machine.sh tests/test-s03-design-artifacts.sh tests/test-s04-core-commands.sh tests/test-s05-autonomous-mode.sh tests/test-s06-knowledge-lifecycle.sh tests/test-s07-integration.sh tests/test-s08-auto-safety.sh; do
     echo "" >> "$TRANSCRIPT"
     echo "--- $suite ---" >> "$TRANSCRIPT"
     if bash "$suite" >> "$TRANSCRIPT" 2>&1; then
       echo "SUITE_PASS: $suite" >> "$TRANSCRIPT"
     else
       echo "SUITE_FAIL: $suite" >> "$TRANSCRIPT"
       overall=1
     fi
   done
   if [ "$overall" -eq 0 ]; then
     echo "" >> "$TRANSCRIPT"
     echo "ALL_SUITES_PASS" >> "$TRANSCRIPT"
   else
     echo "" >> "$TRANSCRIPT"
     echo "ALL_SUITES_FAIL" >> "$TRANSCRIPT"
   fi
   ```

   If any suite fails, STOP and investigate before continuing. The marker `ALL_SUITES_PASS` must be present for `m015-p04-all-tests-pass.sh` to PASS.

   Note on the spec's "7 test suites" wording: inspection at T01 confirms 8 suites are present. All 8 are executed. If `test-s08-auto-safety.sh` is a post-M001 addition and the spec wording predates it, that is acceptable — run all 8 and let the "7 suites" phrasing remain historical in the FR copy. Record this discrepancy in the T02 summary narrative.

2. Run the doctor report. Capture stdout + stderr into `evidence/doctor-report.txt` and append the `DOCTOR_CLEAN` marker only if the doctor exits 0 and produces no FAIL: lines.

   ```bash
   REPORT=.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt
   : > "$REPORT"
   echo "=== Doctor Report — $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$REPORT"
   if bash scripts/diagnostics/run-doctor.sh >> "$REPORT" 2>&1; then
     if grep -q "^FAIL:" "$REPORT"; then
       echo "" >> "$REPORT"
       echo "DOCTOR_DIRTY" >> "$REPORT"
     else
       echo "" >> "$REPORT"
       echo "DOCTOR_CLEAN" >> "$REPORT"
     fi
   else
     echo "" >> "$REPORT"
     echo "DOCTOR_EXIT_NONZERO" >> "$REPORT"
   fi
   ```

   If doctor is not clean, investigate and fix any flagged issues before proceeding. The verifier requires `DOCTOR_CLEAN` present and zero `^FAIL:` lines.

3. Run the migration adapter against the spec-kit-shaped fixture.

   ```bash
   TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt
   : > "$TRANSCRIPT"
   echo "=== Migration Adapter Run — $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$TRANSCRIPT"

   SRC=$(mktemp -d -t m015p04-src.XXXXXX)
   DST=$(mktemp -d -t m015p04-dst.XXXXXX)
   echo "SRC=$SRC" >> "$TRANSCRIPT"
   echo "DST=$DST" >> "$TRANSCRIPT"

   # Build the spec-kit-shaped fixture into SRC
   bash tests/fixtures/m015-p04-speckit-migration/build-fixture.sh "$SRC" >> "$TRANSCRIPT" 2>&1

   # Run the migration (flags per scripts/migrate/migrate.sh --help; adjust
   # if the CLI shape has changed — the transcript must show a successful
   # adapter load, detect, extract, transform, import sequence).
   echo "" >> "$TRANSCRIPT"
   echo "--- migrate.sh run ---" >> "$TRANSCRIPT"
   if bash scripts/migrate/migrate.sh --source "$SRC" --target "$DST" >> "$TRANSCRIPT" 2>&1; then
     migrate_rc=0
   else
     migrate_rc=$?
   fi
   echo "migrate.sh exit code: $migrate_rc" >> "$TRANSCRIPT"

   # Record the produced .orchestrator/ tree (if any)
   echo "" >> "$TRANSCRIPT"
   echo "--- produced tree ---" >> "$TRANSCRIPT"
   if [ -d "$DST/.orchestrator" ]; then
     find "$DST/.orchestrator" -maxdepth 4 -type f >> "$TRANSCRIPT" 2>&1 || true
     if [ -f "$DST/.orchestrator/memory/constitution.md" ]; then
       echo "VERIFIED: $DST/.orchestrator/memory/constitution.md exists" >> "$TRANSCRIPT"
     fi
   else
     echo "MISSING: $DST/.orchestrator directory was not produced" >> "$TRANSCRIPT"
   fi

   # Success marker — only if migrate exited 0 AND constitution was migrated
   echo "" >> "$TRANSCRIPT"
   if [ "$migrate_rc" -eq 0 ] && [ -f "$DST/.orchestrator/memory/constitution.md" ]; then
     echo "MIGRATION_SUCCESS" >> "$TRANSCRIPT"
   else
     echo "MIGRATION_FAIL rc=$migrate_rc" >> "$TRANSCRIPT"
   fi

   # Cleanup temp dirs (optional — evidence transcript has everything we need)
   rm -rf "$SRC" "$DST"
   ```

   If `MIGRATION_SUCCESS` does not appear, inspect `scripts/migrate/migrate.sh --help` and adjust the invocation shape above (the flags `--source`/`--target` are the planned API; if the actual CLI uses positional arguments or different flag names, use what the script exposes and document the adjustment in the transcript). Record any adjustment in the T02 summary.

4. Run the clean-clone shape check. `git archive HEAD` is byte-equivalent to the post-checkout tree for this commit without needing network access or a second clone. The transcript writes a full path listing of the extracted tree plus the required `CLEAN_CLONE_OK` marker.

   ```bash
   SHAPE=.orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt
   : > "$SHAPE"
   echo "=== Clean Clone Shape — $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$SHAPE"

   TMP=$(mktemp -d -t m015p04-clone.XXXXXX)
   echo "EXTRACT_DIR=$TMP" >> "$SHAPE"

   # Extract the committed tree (no .git — exactly what a fresh clone checkout looks like)
   git archive --format=tar HEAD | tar -xf - -C "$TMP"

   echo "" >> "$SHAPE"
   echo "--- full file listing ---" >> "$SHAPE"
   ( cd "$TMP" && find . -type f ) >> "$SHAPE" 2>&1 || true

   echo "" >> "$SHAPE"
   echo "--- extension-host artifact probe ---" >> "$SHAPE"
   fail=0
   if [ -f "$TMP/extension.yml" ]; then echo "FOUND: extension.yml" >> "$SHAPE"; fail=1; fi
   if [ -d "$TMP/.specify/scripts/bash" ]; then echo "FOUND: .specify/scripts/bash/" >> "$SHAPE"; fail=1; fi
   if [ -d "$TMP/.specify/templates/commands" ]; then echo "FOUND: .specify/templates/commands/" >> "$SHAPE"; fail=1; fi
   if [ -d "$TMP/.specify/orchestrator" ]; then echo "FOUND: .specify/orchestrator/" >> "$SHAPE"; fail=1; fi
   if ls "$TMP/.claude/commands/"speckit.*.md >/dev/null 2>&1; then echo "FOUND: .claude/commands/speckit.*.md" >> "$SHAPE"; fail=1; fi

   echo "" >> "$SHAPE"
   if [ "$fail" -eq 0 ]; then
     echo "CLEAN_CLONE_OK" >> "$SHAPE"
   else
     echo "CLEAN_CLONE_DIRTY" >> "$SHAPE"
   fi

   rm -rf "$TMP"
   ```

   Note: the path listing produced by `find . -type f` uses relative paths (e.g. `./README.md`, `./scripts/...`). The `m015-p04-clean-clone-shape.sh` verifier greps for path substrings, so relative-with-leading-`./` is fine. The negative-probe block above also runs in-shell and appends explicit `FOUND:` lines — those are there as a secondary signal for post-hoc debugging but are redundant with the verifier's grep over the listing.

5. After all four evidence transcripts are written, run the seven T01 gate scripts and confirm all PASS:

   ```bash
   bash scripts/verify/m015-p04-all-tests-pass.sh
   bash scripts/verify/m015-p04-doctor-clean.sh
   bash scripts/verify/m015-p04-speckit-migration-works.sh
   bash scripts/verify/m015-p04-clean-clone-shape.sh
   bash scripts/verify/m015-p04-evidence-captured.sh
   ```

   All five must exit 0 with a PASS line. (The other two — `verification-complete` and `milestone-summary-present` — are T03/T04's responsibility and will still FAIL here; that is expected.)

6. Commit only what T02 produced: the four evidence transcripts under `.orchestrator/milestones/M015/phases/P04/evidence/`. No runtime files changed.

## Must-Haves

This task addresses these phase must-haves:

- Truth: all 7 test suites pass (evidence via test-suite-transcript.txt + ALL_SUITES_PASS marker)
- Truth: orchestrator-doctor clean (evidence via doctor-report.txt + DOCTOR_CLEAN marker)
- Truth: spec-kit migration adapter produces valid .orchestrator/ (evidence via migration-adapter-transcript.txt + MIGRATION_SUCCESS marker)
- Truth: clean-clone shape has no extension-host artifacts (evidence via clean-clone-shape.txt + CLEAN_CLONE_OK marker)
- Truth: validation evidence captured (all four transcripts non-empty)
- Artifacts: four evidence transcript files under .orchestrator/milestones/M015/phases/P04/evidence/

This task does NOT address the verification doc (T03) nor the milestone summary (T04).

## Verification

- Confirm all four evidence transcripts exist, are non-empty, and contain the required markers:

  ```
  bash scripts/verify/m015-p04-all-tests-pass.sh
  bash scripts/verify/m015-p04-doctor-clean.sh
  bash scripts/verify/m015-p04-speckit-migration-works.sh
  bash scripts/verify/m015-p04-clean-clone-shape.sh
  bash scripts/verify/m015-p04-evidence-captured.sh
  ```

  All five must exit 0 with `PASS:` lines.

- Confirm phase must-haves are partially passing (11 of 15 artifacts present; 4 still missing: verification doc + summary doc + the T03/T04 artifact lines):

  ```
  bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04
  ```

  Expected: five Truths in the "evidence-backed" group PASS; seven artifact-bundle entries for the evidence transcripts + test-suite/doctor/migration/clean-clone verifiers PASS; M015-VERIFICATION.md and M015-SUMMARY.md artifact entries still FAIL (expected — T03/T04 produce them).

## Inputs

### From Previous Tasks

- `scripts/verify/m015-p04-all-tests-pass.sh` (from T01)
  - Key API: executes as a shell script; reads `.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt`.
  - Required marker: `ALL_SUITES_PASS` at the end of transcript.
- `scripts/verify/m015-p04-doctor-clean.sh` (from T01)
  - Required marker: `DOCTOR_CLEAN` in `evidence/doctor-report.txt`; zero `^FAIL:` lines.
- `scripts/verify/m015-p04-speckit-migration-works.sh` (from T01)
  - Required markers: `MIGRATION_SUCCESS` and literal substring `.orchestrator/memory/constitution.md` in `evidence/migration-adapter-transcript.txt`; fixture build script present.
- `scripts/verify/m015-p04-clean-clone-shape.sh` (from T01)
  - Required marker: `CLEAN_CLONE_OK` in `evidence/clean-clone-shape.txt`; zero matches for extension-host artifact patterns.
- `scripts/verify/m015-p04-evidence-captured.sh` (from T01)
  - Asserts all four transcripts exist and are non-empty.
- `tests/fixtures/m015-p04-speckit-migration/build-fixture.sh` (from T01)
  - Key API: `build-fixture.sh <target-dir>` → populates `<target-dir>/.specify/memory/constitution.md`, `<target-dir>/specs/001-example/spec.md`, and `<target-dir>/README.md`; prints `FIXTURE_BUILT target=<target-dir>` on success.

### From Disk (Pre-existing)

- `tests/test-s01-structure.sh` through `tests/test-s08-auto-safety.sh` — eight test suites; must all exit 0.
- `scripts/diagnostics/run-doctor.sh` — executed to produce the doctor report.
- `scripts/migrate/migrate.sh` — executed against the fixture to produce the migration transcript.
- `git` — used for `git archive HEAD` to produce the clean-clone extraction.
- `mktemp -d` — used for throwaway work directories.

## Constraints

- **Four evidence streams only** — do NOT attempt to run orchestrator-auto inside the clean-clone extraction. M003 P07/P08 already validated auto in Claude Code native mode (per the spec's stated assumption). Clean-clone here is a shape assertion, not a behavioral run.
- **Temp directories must be cleaned up** — every `mktemp -d` result must be removed at the end of its stream (or in a `trap` if you want belt-and-suspenders).
- **Evidence transcripts go only under `.orchestrator/milestones/M015/phases/P04/evidence/`** — do not sprinkle transcripts elsewhere.
- **Do not modify any runtime file** — T02 is execution + evidence capture. If a test or doctor failure surfaces a real bug, stop and escalate; do not silently patch.
- **Do not commit the fixture tree** — only the evidence transcripts. The fixture is regenerated per run in a temp dir.
- **Markers must match T01 verifier expectations byte-for-byte**: `ALL_SUITES_PASS`, `DOCTOR_CLEAN`, `MIGRATION_SUCCESS`, `CLEAN_CLONE_OK`.
- **Bash 3.2 compatibility** (MEM001): no associative arrays, no `mapfile`.

## Expected Output

At task end:

- Four evidence transcripts exist under `.orchestrator/milestones/M015/phases/P04/evidence/`, each non-empty, each terminating in its required marker line.
- Five T01 gate verifiers (`all-tests-pass`, `doctor-clean`, `speckit-migration-works`, `clean-clone-shape`, `evidence-captured`) all exit 0 with `PASS:` lines.
- Two T01 gate verifiers (`verification-complete`, `milestone-summary-present`) still exit 1 — correct, since T03/T04 haven't run yet.
- No runtime files modified; no uncommitted changes outside the four evidence transcripts.
- T02 summary narrative records: the "7 vs 8 suites" discrepancy resolution, any migrate.sh CLI shape adjustment, and the total runtime for each stream.
