---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M015"
name: "Write P03 verify scripts (pre-reframe scaffolding)"
depends_on: []
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- P02 is complete: state lives at `.orchestrator/`, constitution lives at `.orchestrator/memory/constitution.md`, `scripts/state/resolve-root.sh` has no bridge rule, `scripts/verify/m015-p02-no-stale-state-refs.sh` exists and PASSes today with its full `ALLOW_P03_DOCS` list intact.
- The five primary docs (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`) still contain legacy "spec-kit extension" framing and `/speckit.*`/`.specify/orchestrator/` references — that is the expected pre-reframe state. This task does NOT edit them; T02/T03 do.
- CHANGELOG.md has no M015 entry yet. Its current top entry is the `[0.8.0] — 2026-04-14` [M008](../../../../../milestones/M008/index.md) block.

## Description

Create the six P03 verification scripts that T02, T03, and T04 will rely on. Writing them first gives each reframe task an immediate pass/fail signal. Each script follows the single-script-file shape (AD-19 / MEM007): no inline compound bash, no `$(… | …)` command-substitution-with-pipes, no plain subshells, no process substitution. Exit 0 with a `PASS:` line on success, exit 1 with a `FAIL:` line on failure.

All six scripts are designed to FAIL before T02/T03/T04 land and PASS after. That is the expected behavior during T01 — the scripts exist to gate completion of the reframe, not to assert the reframe has already happened.

One additional artifact: capture a pre-reframe snapshot of the historical portion of CHANGELOG.md (everything below the `## [0.8.0]` line) into `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`. T04's `m015-p03-changelog-has-m015.sh` diff-compares the post-reframe historical portion against this snapshot to prove immutability.

## Steps

1. Create directory `scripts/verify/m015-p03-helpers/` if it does not exist.

2. Capture the historical CHANGELOG snapshot. Write `scripts/verify/m015-p03-helpers/capture-changelog-historical.sh` with this content (run it once as part of this task to produce the snapshot file; the script itself is kept in the repo so a later reviewer can reproduce):

   ```bash
   #!/usr/bin/env bash
   set -eu
   # One-shot helper: capture the historical portion of CHANGELOG.md
   # (everything from the FIRST `## [` heading downward) into a snapshot
   # file that T04 diffs against to prove historical entries were not
   # rewritten during P03. Run this once in T01, before any CHANGELOG edit.
   OUT=scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
   SRC=CHANGELOG.md
   test -f "$SRC" || { echo "FAIL: $SRC missing"; exit 1; }
   awk '/^## \[/{found=1} found{print}' "$SRC" > "$OUT"
   test -s "$OUT" || { echo "FAIL: snapshot empty"; exit 1; }
   echo "PASS: snapshot written to $OUT"
   ```

   Make it executable: `chmod +x scripts/verify/m015-p03-helpers/capture-changelog-historical.sh`. Then run it: `bash scripts/verify/m015-p03-helpers/capture-changelog-historical.sh`. Commit both the helper script and the produced snapshot file.

3. Create `scripts/verify/m015-p03-standalone-framing.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: the five primary standalone docs no longer describe the
   # orchestrator as "a spec-kit extension" in current-state framing.
   # Permitted: (a) changelog-style historical prose with explicit history
   # markers, (b) migration-context callouts. Both must include an
   # explicit MIGRATION or HISTORICAL marker nearby — we check for a
   # mention of "migration" or "history" on the same line, or require
   # the phrase to appear only inside known safe contexts.
   #
   # Implementation: disallow the phrase "spec-kit extension" entirely
   # in the five primary docs. T02 must use alternative phrasing
   # ("spec-kit host", "spec-kit extension host (historically)", etc.)
   # in any preserved historical context. Migration contexts live in
   # docs/migrating-from-speckit.md, not in the primary docs.
   PRIMARIES="README.md CLAUDE.md references/architecture.md references/installation.md docs/getting-started.md"
   fail=0
   for f in $PRIMARIES; do
     test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
     if grep -q "spec-kit extension" "$f"; then
       echo "FAIL: '$f' still contains 'spec-kit extension'"
       fail=1
     fi
   done
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: no 'spec-kit extension' framing in primary standalone docs"
   ```

4. Create `scripts/verify/m015-p03-no-legacy-install.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: the five primary standalone docs no longer instruct readers
   # to install extension.yml, reference .specify/orchestrator/ as the
   # canonical state path, or invoke /speckit.* slash commands as this
   # project's SDD entry point.
   PRIMARIES="README.md CLAUDE.md references/architecture.md references/installation.md docs/getting-started.md"
   fail=0
   for f in $PRIMARIES; do
     test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
     if grep -q "extension\.yml" "$f"; then
       echo "FAIL: '$f' still references extension.yml"
       fail=1
     fi
     if grep -q "\.specify/orchestrator" "$f"; then
       echo "FAIL: '$f' still references .specify/orchestrator"
       fail=1
     fi
     if grep -q "\.specify/memory/constitution" "$f"; then
       echo "FAIL: '$f' still references .specify/memory/constitution"
       fail=1
     fi
     if grep -qE "/speckit\.(specify|plan|tasks|clarify|implement|analyze|checklist)" "$f"; then
       echo "FAIL: '$f' still references /speckit.* slash commands as SDD entry points"
       fail=1
     fi
   done
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: no legacy install/runtime references in primary standalone docs"
   ```

5. Create `scripts/verify/m015-p03-changelog-has-m015.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: CHANGELOG.md has an M015 entry at the top (under the top-
   # level title, above the prior top entry [0.8.0]), AND the historical
   # portion below the M015 entry is byte-identical to the pre-P03
   # snapshot captured in T01.
   test -f CHANGELOG.md || { echo "FAIL: CHANGELOG.md missing"; exit 1; }
   SNAP=scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
   test -f "$SNAP" || { echo "FAIL: snapshot $SNAP missing (T01 incomplete)"; exit 1; }
   # Must mention M015 at least once.
   grep -q "M015" CHANGELOG.md || { echo "FAIL: CHANGELOG.md has no M015 entry"; exit 1; }
   # The NEW M015 entry must appear ABOVE the first [0.8.0] entry.
   M015_LINE=$(grep -n "M015" CHANGELOG.md | head -1 | cut -d: -f1)
   FIRST_OLD=$(grep -n "^## \[0\.8\.0\]" CHANGELOG.md | head -1 | cut -d: -f1)
   test -n "$M015_LINE" || { echo "FAIL: no M015 line number resolved"; exit 1; }
   test -n "$FIRST_OLD" || { echo "FAIL: no [0.8.0] header resolved"; exit 1; }
   if [ "$M015_LINE" -ge "$FIRST_OLD" ]; then
     echo "FAIL: M015 entry must appear above [0.8.0] entry (M015 line=$M015_LINE, [0.8.0] line=$FIRST_OLD)"
     exit 1
   fi
   # Historical portion (from first `## [` to EOF) must match snapshot.
   awk '/^## \[/{found=1} found{print}' CHANGELOG.md > /tmp/m015-p03-changelog-current-historical.txt
   if ! diff -q "$SNAP" /tmp/m015-p03-changelog-current-historical.txt >/dev/null 2>&1; then
     echo "FAIL: historical CHANGELOG entries have been modified (compare $SNAP with /tmp/m015-p03-changelog-current-historical.txt)"
     exit 1
   fi
   echo "PASS: CHANGELOG.md has M015 entry at top; historical entries immutable"
   ```

   Note: the awk heuristic treats the NEW M015 entry as part of the "historical" block if it is written as `## [0.9.0]` or similar. To avoid false positives, the snapshot captures EVERYTHING from the first `## [` in the PRE-P03 file — which means the new M015 entry must be inserted ABOVE any `## [` line. T02's changelog steps write the M015 entry using a `## [0.9.0]` or `## M015 — Standalone Cutover` heading *and* the script's historical comparison starts at the FIRST `## [` in the current file. That means T02 must insert the new entry such that it becomes the new first `## [` — and the snapshot is compared starting from the SECOND `## [` onward. Adjust the awk logic accordingly:

   Replace the two `awk` invocations with:

   ```
   # Snapshot (capture-changelog-historical.sh): skip count=0, copy from first `## [`.
   awk '/^## \[/{found=1} found{print}' "$SRC" > "$OUT"
   # Verify (m015-p03-changelog-has-m015.sh): skip the FIRST `## [`, copy from the SECOND onward.
   awk '/^## \[/{count++} count>=2{print}' CHANGELOG.md > /tmp/m015-p03-changelog-current-historical.txt
   ```

   This means the snapshot captures the historical tail starting at `## [0.8.0]`, and post-P03 the historical tail is everything starting at the SECOND `## [` heading (which, after T02 inserts a new M015 entry above `## [0.8.0]`, is still `## [0.8.0]` onward).

   Finalize the verify script with the corrected awk. Full final content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test -f CHANGELOG.md || { echo "FAIL: CHANGELOG.md missing"; exit 1; }
   SNAP=scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
   test -f "$SNAP" || { echo "FAIL: snapshot $SNAP missing (T01 incomplete)"; exit 1; }
   grep -q "M015" CHANGELOG.md || { echo "FAIL: CHANGELOG.md has no M015 entry"; exit 1; }
   M015_LINE=$(grep -n "M015" CHANGELOG.md | head -1 | cut -d: -f1)
   FIRST_OLD=$(grep -n "^## \[0\.8\.0\]" CHANGELOG.md | head -1 | cut -d: -f1)
   test -n "$M015_LINE" || { echo "FAIL: no M015 line number resolved"; exit 1; }
   test -n "$FIRST_OLD" || { echo "FAIL: no [0.8.0] header resolved"; exit 1; }
   if [ "$M015_LINE" -ge "$FIRST_OLD" ]; then
     echo "FAIL: M015 entry must appear above [0.8.0] entry"
     exit 1
   fi
   awk '/^## \[/{count++} count>=2{print}' CHANGELOG.md > /tmp/m015-p03-changelog-current-historical.txt
   if ! diff -q "$SNAP" /tmp/m015-p03-changelog-current-historical.txt >/dev/null 2>&1; then
     echo "FAIL: historical CHANGELOG entries have been modified"
     exit 1
   fi
   echo "PASS: CHANGELOG.md has M015 entry at top; historical entries immutable"
   ```

6. Create `scripts/verify/m015-p03-migration-doc.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: docs/migrating-from-speckit.md exists and frames spec-kit
   # as a migration source (not a runtime dependency).
   DOC=docs/migrating-from-speckit.md
   test -f "$DOC" || { echo "FAIL: $DOC missing"; exit 1; }
   # Must mention "migration" or "migrating".
   grep -qiE "migrat(ion|ing)" "$DOC" || { echo "FAIL: $DOC does not mention migration"; exit 1; }
   # Must reference either commands/migrate.md or scripts/migrate/migrate-state.sh.
   if ! grep -qE "commands/migrate\.md|scripts/migrate/migrate-state\.sh|orchestrator:migrate|orchestrator-migrate" "$DOC"; then
     echo "FAIL: $DOC does not reference the migrate command or migrate script"
     exit 1
   fi
   # Must NOT frame spec-kit as a runtime dependency — the phrase
   # "requires spec-kit" or "depends on spec-kit" at runtime level is
   # disallowed. Spec-kit appears only as a migration SOURCE.
   if grep -qE "requires spec-kit|depends on spec-kit at runtime|spec-kit >= 0\.1\.0.*required" "$DOC"; then
     echo "FAIL: $DOC still frames spec-kit as a runtime dependency"
     exit 1
   fi
   # Minimum length sanity — not a stub.
   lines=$(wc -l < "$DOC")
   if [ "$lines" -lt 40 ]; then
     echo "FAIL: $DOC too short ($lines lines, need >= 40)"
     exit 1
   fi
   echo "PASS: migration guide exists and frames spec-kit as migration source"
   ```

7. Create `scripts/verify/m015-p03-wider-docs-sweep.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: wider P03-reserved docs (all 11 non-primary docs in
   # ALLOW_P03_DOCS from P02's sweep) no longer contain literal
   # .specify/orchestrator/ or .specify/memory/constitution references
   # outside explicit historical/migration callouts.
   #
   # "Explicit historical/migration callout" is defined as: the reference
   # appears within 3 lines of the marker string "HISTORICAL", "MIGRATION",
   # or a section heading containing "Migrat" or "Histor". For simplicity,
   # this check counts occurrences per file and compares against a baseline
   # of zero allowed; any file needing preserved historical references
   # must graduate to the secondary ALLOW list maintained below.
   WIDER_DOCS="references/engine.md references/events.md references/errors.md references/recipes.md references/file-formats.md references/state-machine.md references/tier-definitions.md references/constitution-walkthrough.md references/verification-ladder.md docs/knowledge-management.md docs/recipe-authoring.md docs/hook-development.md scripts/AGENTS.md"
   fail=0
   for f in $WIDER_DOCS; do
     test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
     legacy_count=$(grep -cE "\.specify/orchestrator|\.specify/memory/constitution" "$f" || true)
     if [ "$legacy_count" -gt 0 ]; then
       echo "FAIL: '$f' still has $legacy_count legacy path reference(s)"
       fail=1
     fi
   done
   if [ "$fail" -ne 0 ]; then exit 1; fi
   echo "PASS: wider P03-reserved docs swept clean of legacy path references"
   ```

8. Create `scripts/verify/m015-p03-allow-list-tightened.sh` with this content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   # Verify: ALLOW_P03_DOCS in scripts/verify/m015-p02-no-stale-state-refs.sh
   # has been reduced from its initial 16-entry tolerance set. After P03,
   # the expected state is EMPTY or minimal — no P03-reserved doc should
   # still appear in the allow-list because every reframed doc has been
   # swept clean of legacy references.
   #
   # Baseline: P02 landed with 16 entries in ALLOW_P03_DOCS (README.md,
   # CLAUDE.md, references/architecture.md, references/installation.md,
   # references/constitution-walkthrough.md, references/engine.md,
   # references/events.md, references/errors.md, references/recipes.md,
   # references/file-formats.md, references/state-machine.md,
   # references/tier-definitions.md, docs/getting-started.md,
   # docs/knowledge-management.md, docs/hook-development.md,
   # docs/recipe-authoring.md, scripts/AGENTS.md = 17 pipe-separated tokens).
   # Count the pipe-separated tokens in the ALLOW_P03_DOCS line.
   SCRIPT=scripts/verify/m015-p02-no-stale-state-refs.sh
   test -f "$SCRIPT" || { echo "FAIL: $SCRIPT missing"; exit 1; }
   LINE=$(grep "^ALLOW_P03_DOCS=" "$SCRIPT" || true)
   test -n "$LINE" || { echo "FAIL: ALLOW_P03_DOCS declaration not found in $SCRIPT"; exit 1; }
   # Extract the quoted body after `=`.
   BODY=$(echo "$LINE" | sed -e "s/^ALLOW_P03_DOCS='//" -e "s/'$//")
   # An empty allow list is the ideal post-P03 state. Represent empty
   # as ALLOW_P03_DOCS='(?!x)x' or ALLOW_P03_DOCS='__empty__' or
   # ALLOW_P03_DOCS='' — any of these is acceptable. If non-empty,
   # count pipe-separated tokens.
   if [ -z "$BODY" ] || [ "$BODY" = "__empty__" ] || [ "$BODY" = "(?!x)x" ]; then
     echo "PASS: ALLOW_P03_DOCS is empty — all P03-reserved docs reframed"
     exit 0
   fi
   # Count tokens: count pipes + 1.
   pipe_count=$(echo "$BODY" | tr -cd '|' | wc -c | tr -d ' ')
   token_count=$((pipe_count + 1))
   # Reject growth. Baseline was 17 tokens.
   if [ "$token_count" -ge 17 ]; then
     echo "FAIL: ALLOW_P03_DOCS still has $token_count tokens (baseline=17); P03 must reduce it"
     exit 1
   fi
   echo "PASS: ALLOW_P03_DOCS reduced to $token_count token(s)"
   ```

9. Make every newly created verify script executable:

   ```bash
   chmod +x scripts/verify/m015-p03-standalone-framing.sh
   chmod +x scripts/verify/m015-p03-no-legacy-install.sh
   chmod +x scripts/verify/m015-p03-changelog-has-m015.sh
   chmod +x scripts/verify/m015-p03-migration-doc.sh
   chmod +x scripts/verify/m015-p03-wider-docs-sweep.sh
   chmod +x scripts/verify/m015-p03-allow-list-tightened.sh
   ```

10. Parse-check all six verify scripts with `bash -n`:

    ```bash
    bash -n scripts/verify/m015-p03-standalone-framing.sh
    bash -n scripts/verify/m015-p03-no-legacy-install.sh
    bash -n scripts/verify/m015-p03-changelog-has-m015.sh
    bash -n scripts/verify/m015-p03-migration-doc.sh
    bash -n scripts/verify/m015-p03-wider-docs-sweep.sh
    bash -n scripts/verify/m015-p03-allow-list-tightened.sh
    ```

    All six must exit 0 silently.

11. Run the scripts now — they should FAIL (that is the expected pre-reframe state):
    - `m015-p03-standalone-framing.sh` FAILs because primary docs still say "spec-kit extension"
    - `m015-p03-no-legacy-install.sh` FAILs because primary docs still reference `extension.yml`
    - `m015-p03-changelog-has-m015.sh` FAILs because CHANGELOG.md has no M015 entry
    - `m015-p03-migration-doc.sh` FAILs because `docs/migrating-from-speckit.md` does not exist
    - `m015-p03-wider-docs-sweep.sh` FAILs because wider docs still have `.specify/orchestrator/` refs
    - `m015-p03-allow-list-tightened.sh` FAILs because ALLOW_P03_DOCS still has its full 17-token baseline

    Do NOT fix the failures in T01 — T02, T03, T04 do that. Record these expected failures in the T01 summary as evidence the scripts correctly gate the work.

## Must-Haves

From the phase plan, this task addresses the ARTIFACTS half of the must-haves (all six verify scripts must exist, parse, and be executable).

- scripts/verify/m015-p03-standalone-framing.sh (min 15 lines, contains "spec-kit extension")
- scripts/verify/m015-p03-no-legacy-install.sh (min 10 lines, contains "extension.yml")
- scripts/verify/m015-p03-changelog-has-m015.sh (min 10 lines, contains "M015")
- scripts/verify/m015-p03-migration-doc.sh (min 8 lines, contains "migrating-from-speckit")
- scripts/verify/m015-p03-wider-docs-sweep.sh (min 15 lines, contains ".specify/orchestrator")
- scripts/verify/m015-p03-allow-list-tightened.sh (min 10 lines, contains "ALLOW_P03_DOCS")

## Verification

```
bash -n scripts/verify/m015-p03-standalone-framing.sh
bash -n scripts/verify/m015-p03-no-legacy-install.sh
bash -n scripts/verify/m015-p03-changelog-has-m015.sh
bash -n scripts/verify/m015-p03-migration-doc.sh
bash -n scripts/verify/m015-p03-wider-docs-sweep.sh
bash -n scripts/verify/m015-p03-allow-list-tightened.sh
test -f scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
```

All seven commands must exit 0 silently. `check-must-haves.sh .orchestrator/milestones/M015/phases/P03` is NOT expected to PASS yet — T01 only lands the artifact half (6 of 6 verify scripts) plus the snapshot helper; the six truth-level checks still FAIL until T02/T03/T04.

## Inputs

- The full P02 sweep script at `scripts/verify/m015-p02-no-stale-state-refs.sh` — the `ALLOW_P03_DOCS` regex gives the exact list of 16 files the P03 phase must eventually graduate out.
- `CHANGELOG.md` — read-only in T01 (the capture helper reads it; T02 appends to it).
- `specs/015-standalone-cutover/spec.md` — FR-010, FR-011, FR-012 specify the doc-reframe scope.

## Constraints

- Single-script-file shape (AD-19). No inline compound bash, no `$(…|…)`, no plain subshells, no process substitution, no heredoc-with-pipe. Every verify command is the literal `bash <script-path>` form.
- Bash 3.2 compatible. No `declare -A`, no `${var,,}` lowercasing, no `mapfile`. Use plain arrays or parallel indexed-array pattern.
- Historical artifact immutability (MEM): phase summaries, task summaries, knowledge entries under `.orchestrator/`, DECISIONS.md, and prior CHANGELOG.md entries are IMMUTABLE. The capture helper reads CHANGELOG.md — it must not modify it.
- Path literalism (MEM023): artifact paths in this task plan are parsed literally; do NOT wrap them in markdown backticks when listing them as Must-Haves or Artifacts.
- All new verify scripts live under `scripts/verify/m015-p03-*.sh` — not inside the phase directory. This matches the pattern established by P02 (`scripts/verify/m015-p02-*.sh`).

## Expected Output

After T01 completes:

1. Seven new files exist and are committed:
   - `scripts/verify/m015-p03-helpers/capture-changelog-historical.sh` (executable)
   - `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt` (captured data)
   - `scripts/verify/m015-p03-standalone-framing.sh` (executable)
   - `scripts/verify/m015-p03-no-legacy-install.sh` (executable)
   - `scripts/verify/m015-p03-changelog-has-m015.sh` (executable)
   - `scripts/verify/m015-p03-migration-doc.sh` (executable)
   - `scripts/verify/m015-p03-wider-docs-sweep.sh` (executable)
   - `scripts/verify/m015-p03-allow-list-tightened.sh` (executable)

2. All six verify scripts parse clean (`bash -n` exits 0).
3. All six verify scripts currently FAIL with informative messages (expected pre-reframe state). The T01 summary records these failures as evidence that the gates work.
4. T02 can now reframe primary docs with immediate pass/fail feedback from the first two scripts. T03 can sweep wider docs with feedback from the wider-docs script. T04 can tighten the allow-list with feedback from the allow-list script.
