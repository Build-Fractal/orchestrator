---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M033"
name: "FR-21 dual-write convention reference + SC-13 acceptance + m033-p02-* phase-suite + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 complete: `scripts/util/jsonl-event-emitter.sh` exists, `tools/verify/m033-p02-jsonl-event-schema.sh` exists.
- T02 complete: `scripts/util/start-state-markers.sh` exists, `scripts/lifecycle/start.sh` is extended (resume-on-partial-state), `tests/m033-acceptance/p07-resume-on-partial-state.sh` exists, T02's three verifiers exist.
- T03 complete: `scripts/lifecycle/grilling-shell.sh` exists with the core `ask_one`, `tools/verify/m033-p02-grilling-shell-shape.sh` exists.
- T04 complete: `scripts/lifecycle/grilling-shell.sh` has populated SSOT blocks + real helper bodies, `tests/m033-acceptance/p07-grilling-shell.sh` exists, T04's three verifiers exist.
- All ten preceding T01–T04 verifiers exit 0 — verified by running them as a chained pre-condition before T05's phase-suite is authored.
- `scripts/util/dual-write-runtime-md.sh` exists (M014 closed deliverable) — verified by `[ -x scripts/util/dual-write-runtime-md.sh ]`.
- Spec context: FR-21 mandates Recent Changes dual-write inheritance from M014/spec 035 — every M033 calling command (FR-3 / FR-7 / FR-9 / FR-10 / FR-13) appends a one-line fragment to the `# >>> orchestrator:recent-changes >>>` regions in both `CLAUDE.md` and `AGENTS.md` (skip `AGENTS.md` if `dual_write_agents: false` in `.orchestrator/config.yml`). FR-22 / SC-13 codifies the observability-record contract; T01 shipped the emitter; T05 ships the SC-13 acceptance script that exercises all 11 event types.

## Description

T05 ships the cross-task wrapping deliverables for P02:

1. **`references/m033-fr21-dual-write-convention.md`** — the SSOT for P03/P04/P05 calling commands documenting the FR-21 dual-write call-site shape. Lists per-command Recent Changes fragment templates, the `dual_write_agents: false` config-respecting precedent, and the canonical token set the verifier greps for.

2. **`tests/m033-acceptance/p07-observability-records.sh`** — SC-13 acceptance script. Exercises all 11 documented event types end-to-end via the T01-shipped emitter; validates schema 1.0, ISO 8601 timestamp, payload pass-through, and the closed-enum negative path.

3. **`tools/verify/m033-p02-fr21-convention-shape.sh`** — verifier asserting the FR-21 convention reference exists with documented tokens.

4. **`tools/verify/m033-p02-acceptance-shape-sc13.sh`** — verifier asserting the SC-13 acceptance script exists with documented tokens.

5. **`tools/verify/m033-p02-phase-suite.sh`** — aggregator chaining all 10 P02 verifiers; emits `SUMMARY: m033-p02-phase-suite.sh pass=N fail=M`.

6. **`tools/verify/m033-p02-scope-guard.sh`** — asserts P02 diff stays within declared boundaries; flags any leakage into P03/P04/P05 surfaces.

T05 is **the last task in P02 by construction**: the phase-suite chains all earlier verifiers, so it must be authored after every verifier exists.

**Bash 3.2 compatibility (MEM001):** No associative arrays, no process substitution.

## Steps

1. **Author `references/m033-fr21-dual-write-convention.md`** (≥60 lines, markdown).

   1a. **Frontmatter + Title.** Standard markdown; title `# FR-21 Dual-Write Recent Changes Convention (M033)`.

   1b. **Section: Inheritance from M014/spec 035.** Document that the dual-write helper `scripts/util/dual-write-runtime-md.sh` ships as part of M014 (closed) and is invoked by every M033 calling command. The convention is an inheritance, not a new contract.

   1c. **Section: Call-site shape.** Document the canonical invocation:

   ```bash
   bash scripts/util/dual-write-runtime-md.sh append "<one-line-fragment>"
   ```

   The helper writes the fragment to the `# >>> orchestrator:recent-changes >>>` region in `CLAUDE.md` and (if `dual_write_agents` is not `false`) `AGENTS.md`. Documentation MUST include the `dual_write_agents: false` config-respect note.

   1d. **Section: Per-command fragment templates.** Five entries (one per FR-3 / FR-7 / FR-9 / FR-10 / FR-13 command), each with a recommended fragment shape:

   - `orchestrator:constitution` (FR-3) → `- M033/{stack}: constitution authored from {stack} starter`
   - `orchestrator:ingest-codebase` (FR-7) → `- M033/ingest-codebase: seeded {N} MEMs from existing repo`
   - `orchestrator:materials-intake` (FR-9) → `- M033/materials-intake: reconciled {N} conflicts; pre-spec at {path}`
   - `orchestrator:ideation` (FR-10) → `- M033/ideation: 7-question ideation pre-spec at {path}`
   - `orchestrator:customblock-draft` (FR-13) → `- M033/customblock-draft: populated 5-section custom block from upstream sub-flows`

   The `{placeholder}` fields are filled by the calling command at invocation time.

   1e. **Section: Fenced SSOT block.** A `# >>> fr-21-dual-write-callsites >>>` fenced block documenting the 5 call-sites by command name + spec FR ID. The verifier greps this block for the load-bearing tokens.

   ```
   # >>> fr-21-dual-write-callsites >>>
   # FR-3  constitution-authored : commands/constitution.md
   # FR-7  ingest-codebase       : commands/ingest-codebase.md
   # FR-9  materials-intake      : commands/materials-intake.md
   # FR-10 ideation              : commands/ideation.md
   # FR-13 customblock-drafted   : commands/customblock-draft.md
   # <<< fr-21-dual-write-callsites <<<
   ```

   1f. **Section: Cross-references.** Names `scripts/util/dual-write-runtime-md.sh` (M014 closed deliverable), the `dual_write_agents` config flag, and the spec 035 dual-write parent.

2. **Author `tests/m033-acceptance/p07-observability-records.sh`** (≥100 lines, executable, exits 0 → SC-13).

   2a. **Setup.** `mktemp -d` for staging; trap EXIT for cleanup; `staging` is the project dir.

   2b. **Test 1 — emit each of the 11 event types.** For each `event_type` in the documented closed set, invoke:

   ```bash
   PROJECT_DIR=<staging> bash scripts/util/jsonl-event-emitter.sh emit <event_type> '{"test":"sc13","seq":N}'
   ```

   Where `N` is the sequence index (0..10). Use a static enumeration (no loop indirection — the test should hard-code each call so a bug in any one event-type is named in the failure output).

   2c. **Test 2 — assert 11 lines appended.** `wc -l <staging>/.orchestrator/execution-log.jsonl` returns 11.

   2d. **Test 3 — schema-version 1.0 in every line.** `grep -c '"schema_version":"1.0"' <staging>/.orchestrator/execution-log.jsonl` returns 11.

   2e. **Test 4 — every event_type appears exactly once.** For each event_type, `grep -c '"event_type":"<event_type>"'` returns 1.

   2f. **Test 5 — every line has an ISO 8601 timestamp.** `grep -c '"timestamp":"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z"'` returns 11.

   2g. **Test 6 — payload pass-through.** Every line contains `"test":"sc13"` substring (11 matches).

   2h. **Test 7 — unknown event type rejected.** Invoke `bash scripts/util/jsonl-event-emitter.sh emit unknown_event '{}'` capturing exit code; assert non-zero AND stderr contains `valid:` followed by the closed enum tokens.

   2i. **Test 8 — schema version literal in source.** `grep -c '"1.0"' scripts/util/jsonl-event-emitter.sh` ≥1 (catches accidental schema-version drift).

   2j. **Cleanup mandatory.**

3. **Author `tools/verify/m033-p02-fr21-convention-shape.sh`** (≥25 lines, executable). Asserts:
   - `references/m033-fr21-dual-write-convention.md` exists.
   - The `# >>> fr-21-dual-write-callsites >>>` and `# <<< fr-21-dual-write-callsites <<<` markers appear.
   - The five FR-IDs appear: `FR-3`, `FR-7`, `FR-9`, `FR-10`, `FR-13`.
   - The five command names appear: `constitution`, `ingest-codebase`, `materials-intake`, `ideation`, `customblock-draft`.
   - The cross-reference to `scripts/util/dual-write-runtime-md.sh` appears.
   - The `dual_write_agents` config-flag token appears.
   - Emits PASS/SUMMARY lines.

4. **Author `tools/verify/m033-p02-acceptance-shape-sc13.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p07-observability-records.sh` exists, is executable.
   - The literal SC-13 + FR-22 tokens appear.
   - All 11 event-type tokens appear.
   - The `schema_version` and `1.0` tokens appear.
   - The `execution-log.jsonl` cross-reference appears.
   - Emits PASS/SUMMARY lines.

5. **Author `tools/verify/m033-p02-phase-suite.sh`** (≥50 lines, executable). Implementation:

   ```bash
   #!/usr/bin/env bash
   set -e -u -o pipefail
   PASS=0
   FAIL=0
   verifiers="
   tools/verify/m033-p02-grilling-shell-shape.sh
   tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
   tools/verify/m033-p02-glossary-writer-shape.sh
   tools/verify/m033-p02-jsonl-event-schema.sh
   tools/verify/m033-p02-start-state-markers-shape.sh
   tools/verify/m033-p02-start-sh-resume-extension.sh
   tools/verify/m033-p02-fr21-convention-shape.sh
   tools/verify/m033-p02-acceptance-shape-sc11.sh
   tools/verify/m033-p02-acceptance-shape-sc12.sh
   tools/verify/m033-p02-acceptance-shape-sc13.sh
   "
   IFSO="$IFS"
   IFS=$'\n'
   for v in $verifiers; do
     v="$(echo "$v" | tr -d '[:space:]')"
     [ -z "$v" ] && continue
     if bash "$v" > /dev/null 2>&1; then
       PASS=$((PASS + 1))
       echo "PASS: $v"
     else
       FAIL=$((FAIL + 1))
       echo "FAIL: $v"
     fi
   done
   IFS="$IFSO"
   printf 'SUMMARY: m033-p02-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
   if [ "$FAIL" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   The 10 sub-gates plus the `SUMMARY:` line equal 11 line outputs on success. The `SUMMARY:` token + the per-verifier names are load-bearing for milestone-level aggregation.

6. **Author `tools/verify/m033-p02-scope-guard.sh`** (≥35 lines, executable). Asserts the P02 diff (against the M033/P01 close commit) stays within declared P02 boundaries:
   - **Forbidden creations:** `scripts/lifecycle/constitution-author.sh`, `scripts/lifecycle/ingest-codebase.sh`, `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/ideation.sh`, `scripts/lifecycle/customblock-draft.sh`. Verifier asserts these files do NOT exist (P02 must not leak P03/P04/P05 surfaces).
   - **Forbidden creations:** `templates/constitution-starters/web-saas.md`, `templates/constitution-starters/cli-tool.md`, `templates/constitution-starters/library.md`. Verifier asserts they do NOT exist (P03 territory).
   - **Forbidden creations:** `commands/constitution.md`, `commands/ingest-codebase.md`, `commands/materials-intake.md`, `commands/ideation.md`, `commands/customblock-draft.md`. Verifier asserts they do NOT exist (P03/P04/P05 territory).
   - **Forbidden creations:** `references/constitution-starter-format.md`, `references/customblock-format.md`. Verifier asserts they do NOT exist.
   - **Wiki write boundary:** any creation under `wiki/` outside fixture-local staging directories under `mktemp -d` is forbidden. The repo's `wiki/` was a P01 / pre-P02 surface; P02 must not modify it. Verifier: `git diff --name-only HEAD~N -- wiki/` should produce no output for the P02 commit range. (Heuristic: if the verifier cannot determine the diff range, it falls back to checking that no `wiki/` files are newly added relative to the M033/P01 close marker.)
   - **Allowed P02 creations** (whitelist, asserted to exist as a positive gate): the 20 deliverables enumerated in the P02-PLAN.md "Files Likely Touched" section. The verifier reads each path, confirms it exists, and emits a PASS line. (This both detects scope underflow and overflow.)
   - Emits PASS/SUMMARY lines per the SC-13 / scope-guard precedent.

## Must-Haves

This task addresses these P02 phase truths:
- The FR-21 dual-write convention is documented at `references/m033-fr21-dual-write-convention.md` for P03/P04/P05 consumption.
- SC-13 (`tests/m033-acceptance/p07-observability-records.sh`) exits 0 and validates all 11 event types + schema 1.0 + ISO 8601 timestamps.
- The P02 phase-suite aggregator chains all 10 P02 verifiers and emits the canonical `SUMMARY: m033-p02-phase-suite.sh pass=N fail=M` line.
- The SC-13 / scope-guard invariant holds for the P02 diff.

This task creates these P02 phase artifacts:
- Reference: `references/m033-fr21-dual-write-convention.md` (FR-21 SSOT for P03/P04/P05).
- Acceptance script: `tests/m033-acceptance/p07-observability-records.sh` (SC-13).
- Verifiers: `tools/verify/m033-p02-fr21-convention-shape.sh`, `tools/verify/m033-p02-acceptance-shape-sc13.sh`, `tools/verify/m033-p02-phase-suite.sh`, `tools/verify/m033-p02-scope-guard.sh`.

## Verification

```bash
bash tools/verify/m033-p02-fr21-convention-shape.sh
```

```bash
bash tools/verify/m033-p02-acceptance-shape-sc13.sh
```

```bash
bash tools/verify/m033-p02-phase-suite.sh
```

```bash
bash tools/verify/m033-p02-scope-guard.sh
```

```bash
bash tests/m033-acceptance/p07-observability-records.sh
```

## Inputs

### From Previous Tasks

- T01: `scripts/util/jsonl-event-emitter.sh` and `tools/verify/m033-p02-jsonl-event-schema.sh`. SC-13 invokes the emitter directly; phase-suite chains the schema verifier.
- T02: `scripts/util/start-state-markers.sh`, `scripts/lifecycle/start.sh` resume-extension, three T02 verifiers (`start-state-markers-shape`, `start-sh-resume-extension`, `acceptance-shape-sc12`). Phase-suite chains them.
- T03: `scripts/lifecycle/grilling-shell.sh` core, `tools/verify/m033-p02-grilling-shell-shape.sh`. Phase-suite chains it.
- T04: T03 module's populated SSOT blocks + real helper bodies, `tests/m033-acceptance/p07-grilling-shell.sh`, three T04 verifiers (`grilling-shell-contradiction-detection`, `glossary-writer-shape`, `acceptance-shape-sc11`). Phase-suite chains them.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — M014 closed deliverable. T05 documents the call-site convention; does not modify the helper.
- M033/P01 close commit (the diff baseline for the scope-guard).

## Constraints

- Bash 3.2 compatibility (MEM001).
- The phase-suite emits exactly one `SUMMARY:` line on the final line of stdout. The format `SUMMARY: m033-p02-phase-suite.sh pass=N fail=M` is the load-bearing token for milestone-level aggregation.
- The scope-guard MUST be discriminating — it checks both forbidden-presence (P03/P04/P05 surface absence) AND allowed-presence (the 20 P02 whitelist deliverables exist). Both halves are required to catch overflow and underflow respectively.
- T05 MUST NOT modify any T01–T04 deliverable. T05 is purely additive (5 new files).
- Verifier scripts use single-script-file shape per AD-19.
- The P02 phase-suite chains exactly 10 verifiers (the 10 enumerated in P02-PLAN.md "Truths" / Check lines). Adding or removing a sub-gate is a contract change requiring a P02-PLAN.md amendment.

## Expected Output

After T05 completes:
- `references/m033-fr21-dual-write-convention.md` exists with documented tokens.
- `tests/m033-acceptance/p07-observability-records.sh` exists, is executable, exits 0.
- All four new T05 verifiers exist, are executable.
- `tools/verify/m033-p02-phase-suite.sh` exits 0 with `SUMMARY: m033-p02-phase-suite.sh pass=10 fail=0`.
- `tools/verify/m033-p02-scope-guard.sh` exits 0 (no P03/P04/P05 leakage; all 20 P02 whitelist files present).
- A summary file at `.orchestrator/milestones/M033/phases/P02/tasks/T05-fr21-convention-and-phase-suite-SUMMARY.md` documents the deliverables.

## Notes

The phase-suite ships LAST in P02 by construction. If T01/T02/T03/T04 verifiers fail at T05's authoring time, T05 cannot complete — the auto-loop should escalate to the orchestrator for re-dispatch of the failing earlier task rather than degrading the phase-suite contract.

The scope-guard's whitelist check (allowed-presence) detects underflow — if a P02 task silently skipped a deliverable, the whitelist gate fails. Combined with the blacklist check (forbidden-presence), the guard provides bidirectional scope discipline matching M033/P01's `m033-p01-scope-guard.sh` pattern.

The FR-21 convention reference is **read-only documentation** for P03/P04/P05. T05 does NOT invoke `dual-write-runtime-md.sh` itself — that invocation happens in P03/P04/P05 calling commands. T05's contribution to FR-21 is the documentation surface that those calling commands consume; the actual dual-write firing is exercised end-to-end in P03/P04/P05 acceptance tests (SC-2 / SC-3 / SC-4 / SC-5 / SC-7 will inherit the dual-write assertion).
