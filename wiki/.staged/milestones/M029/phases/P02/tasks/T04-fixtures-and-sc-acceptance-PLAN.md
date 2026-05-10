---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M029"
name: "SC-5/SC-6/SC-13/SC-14 fixtures + acceptance scripts + sentinel harness (AD-9, #Q-G6, #Q-G8)"
depends_on: ["T03"]
---

## Prerequisites

- T03 has landed: `scripts/diagnostics/render-position.sh` and `commands/where.md` are on disk and their shape verifiers exit 0; verify `[ -x scripts/diagnostics/render-position.sh ]` and `[ -f commands/where.md ]`.
- T01 + T02 have landed (transitively required by T03; double-check `[ -f references/cross-milestone-feature-shape.md ]` and `[ -x scripts/diagnostics/summarize-milestone.sh ]`).
- `tests/m029-acceptance/` exists (P01 created it); verify `[ -d tests/m029-acceptance ]`.
- `tests/m029-acceptance/fixtures/` exists (P01 created it for status-fixtures).
- No file currently lives at any of: `tests/m029-acceptance/fixtures/where-mixed-state.golden`, `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`, `tests/m029-acceptance/fixtures/where-pre-m019.fixture/`, `tests/m029-acceptance/timestamp-strip.sh`, `tests/m029-acceptance/sentinel-harness.sh`, `tests/m029-acceptance/p02-sc5-where-mixed-state.sh`, `tests/m029-acceptance/p02-sc6-where-pre-m019.sh`, `tests/m029-acceptance/p02-sc13-anti-coupling.sh`, `tests/m029-acceptance/p02-sc14-readonly.sh` (path-collision rule 6 already checked at plan-authoring time — all clean).
- The M029 spec body and context draft restate FR-5/FR-6/FR-11/FR-13/FR-14, SC-5/SC-6/SC-13/SC-14, AD-6/AD-9, #Q-G6 and #Q-G8 inline above; the executor does not need to re-read the spec.

## Description

T04 ships **all four SC fixtures + acceptance scripts that gate P02**:

1. **SC-5 mixed-state fixture + golden render** — `tests/m029-acceptance/fixtures/where-mixed-state.fixture/` is a deterministic project tree containing:
   - `.orchestrator/milestones/M998/M998-ROADMAP.md` (3 phases: P01 done, P02 executing, P03 pending)
   - `.orchestrator/milestones/M998/M998-EVALUATION.md` (intensity=full, feature_ref=037-roadmap-visibility-cli-ux)
   - `.orchestrator/milestones/M998/phases/P01/P01-PLAN.md` + `P01-SUMMARY.md` + one task pair → `✓` glyph
   - `.orchestrator/milestones/M998/phases/P02/P02-PLAN.md` + `tasks/T01-x-PLAN.md` + `T01-x-SUMMARY.md` (✓), `T02-y-PLAN.md` (▶), `T03-z-PLAN.md` (◇), `T04-w-PLAN.md` + a synthetic `last_verify=fail` execution-log entry (✗) — all four glyph states present.
   - `.orchestrator/milestones/M998/phases/P03/P03-PLAN.md` only → `◇` for the entire phase.
   - `.orchestrator/milestones/M998/execution-log.jsonl` with synthetic `dispatch_usage` records under [M019](../../../../../milestones/M019/index.md) Tier 1 schema, sufficient for `metrics-rollup.sh --granularity task` to emit cost values.

   The byte-stable golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden` captures `render-position.sh --milestone M998 --root <fixture-root>/.orchestrator` output AFTER passing through `timestamp-strip.sh` (the #Q-G6 normalizer).

2. **SC-6 pre-M019 fixture** — `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` is a parallel project tree containing a milestone whose `execution-log.jsonl` is **empty** (or absent), simulating a milestone predating M019 Tier 1 emission. The renderer must omit the cost column entirely AND emit nothing on stderr (FR-6 / CON-3).

3. **`tests/m029-acceptance/timestamp-strip.sh`** — the canonical #Q-G6 timestamp-strip filter. Reads stdin, writes to stdout. Strips:
   - ISO-8601 timestamps: `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z`
   - Recency phrasing: `\d+[smhd] ago`
   - Epoch-second tokens that appear in dispatch_id contexts: `\b1[6-9]\d{8}\b`
   Replaces each match with a fixed placeholder (`<TS>` or `<RECENCY>` or `<EPOCH>`). Reproducible across runs.

4. **`tests/m029-acceptance/sentinel-harness.sh`** — the AD-9 mechanism. Wraps an arbitrary command:
   - Writes `.orchestrator/.m029-sc14-sentinel` with the current ISO-8601 UTC timestamp.
   - Records the sentinel's mtime (via `stat`).
   - Runs the wrapped command (forwarded as `"$@"`).
   - After the command completes, scans `.orchestrator/` for any file whose mtime is newer than the sentinel's recorded mtime, EXCLUDING the sentinel itself and EXCLUDING `.orchestrator/start-state/<stage>.complete` markers (the only documented write-site exception per AD-9 / FR-10).
   - On any newer-mtime hit: print `FAIL: read-only invariant violated by <path>` per offender + final `SUMMARY: sentinel-harness.sh fail=N`. Exit 1.
   - On no hits: print `PASS: read-only invariant held`. Exit 0.

5. **SC-5 / SC-6 / SC-13 / SC-14 acceptance scripts** under `tests/m029-acceptance/`:
   - `p02-sc5-where-mixed-state.sh` — invokes the renderer against the mixed-state fixture, normalizes through `timestamp-strip.sh`, diffs against the golden, exits 0 on byte-identity.
   - `p02-sc6-where-pre-m019.sh` — invokes the renderer against the pre-M019 fixture, asserts cost column is absent (no row contains the cost-column delimiter) AND stderr is empty (FR-6 / CON-3).
   - `p02-sc13-anti-coupling.sh` — runs the SC-13 anti-coupling guard: `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match.
   - `p02-sc14-readonly.sh` — wraps `bash sentinel-harness.sh bash render-position.sh --milestone M998 --root <fixture-root>/.orchestrator > /dev/null` and asserts the read-only invariant holds.

## Steps

1. **Create the SC-5 mixed-state fixture tree** at `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`:

   ```
   tests/m029-acceptance/fixtures/where-mixed-state.fixture/
   └── .orchestrator/
       └── milestones/
           └── M998/
               ├── M998-ROADMAP.md       (3 phases listed)
               ├── M998-EVALUATION.md    (intensity=full, feature_ref=037-roadmap-visibility-cli-ux)
               ├── execution-log.jsonl   (synthetic dispatch_usage records for the four task IDs + one unit_close per completed phase)
               └── phases/
                   ├── P01/
                   │   ├── P01-PLAN.md
                   │   ├── P01-SUMMARY.md   (presence → ✓)
                   │   └── tasks/
                   │       ├── T01-foo-PLAN.md
                   │       └── T01-foo-SUMMARY.md
                   ├── P02/
                   │   ├── P02-PLAN.md      (no SUMMARY → ▶)
                   │   └── tasks/
                   │       ├── T01-x-PLAN.md
                   │       ├── T01-x-SUMMARY.md   (✓)
                   │       ├── T02-y-PLAN.md      (▶ — no SUMMARY, latest task in execution-log)
                   │       ├── T03-z-PLAN.md      (◇ — no SUMMARY, no execution record)
                   │       └── T04-w-PLAN.md      (✗ — last verify fail in execution-log)
                   └── P03/
                       └── P03-PLAN.md            (◇ — no tasks dir)
   ```

   Frontmatter for ROADMAP/EVALUATION must use the schemas already established by sibling milestones (e.g. M027/[M028](../../../../../milestones/M028/index.md)) — readable by `scripts/state/read-roadmap.sh` and the parsers in `summarize-milestone.sh`. The execution-log.jsonl records must conform to M019 Tier 1 schema (`record_type=dispatch_usage`, `granularity=task`, `milestone=M998`, `phase=P02`, `task=T##`, plus the documented cost / quality fields). For T04-w (the failed task), include a `record_type=verify_result` with `pass=false` so the renderer can derive the `✗` glyph.

2. **Generate `tests/m029-acceptance/fixtures/where-mixed-state.golden`** by running `bash scripts/diagnostics/render-position.sh --milestone M998 --root tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator | bash tests/m029-acceptance/timestamp-strip.sh > tests/m029-acceptance/fixtures/where-mixed-state.golden`. The golden is then the BYTE-STABLE expected output. Inspect it manually to confirm:
   - All four glyphs (`✓ ▶ ◇ ✗`) appear at least once.
   - The milestone progress bar (`▓░ 33%`) appears.
   - The cost column is present (cost values from M019 Tier 1 records).
   - The headline summary line (mirroring P01 vocabulary) is present.

3. **Create the SC-6 pre-M019 fixture tree** at `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` — mirrors the SC-5 structure but for milestone M997 with NO `execution-log.jsonl` (or an empty one — both are valid pre-M019 markers):

   ```
   tests/m029-acceptance/fixtures/where-pre-m019.fixture/
   └── .orchestrator/
       └── milestones/
           └── M997/
               ├── M997-ROADMAP.md   (1 phase)
               ├── M997-EVALUATION.md
               └── phases/
                   └── P01/
                       ├── P01-PLAN.md
                       └── P01-SUMMARY.md
   ```

4. **Create `tests/m029-acceptance/timestamp-strip.sh`** (≥20 lines, executable, bash 3.2 compatible). Single `sed -E` invocation with three `-e` clauses (one per regex), reading stdin and writing stdout. Per AD-19 / MEM001: NO process substitution, NO `<<<` herestring; the script body MAY use sed pipes (MEM004 carve-out — pipes are permitted INSIDE script bodies, just not on Check: lines).

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/timestamp-strip.sh
   # M029 / #Q-G6 enumerated-pattern timestamp-strip filter for SC-5 golden-render comparison.
   #
   # Reads stdin, writes stdout. Strips:
   #   - ISO-8601 UTC timestamps:  \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z   -> <TS>
   #   - Recency phrasing:         \d+[smhd] ago                          -> <RECENCY>
   #   - Epoch-second tokens:      \b1[6-9]\d{8}\b                        -> <EPOCH>
   #
   # Reproducible across runs. Bash 3.2 / MEM001 compatible.
   set -u
   sed -E \
       -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TS>/g' \
       -e 's/[0-9]+[smhd] ago/<RECENCY>/g' \
       -e 's/(^|[^0-9])1[6-9][0-9]{8}([^0-9]|$)/\1<EPOCH>\2/g'
   ```

   `chmod +x`.

5. **Create `tests/m029-acceptance/sentinel-harness.sh`** (≥30 lines, executable, bash 3.2 compatible, AD-19 single-script-file shape — NO inline compound chains).

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/sentinel-harness.sh
   # M029 / AD-9 sentinel-file harness for SC-14 read-only enforcement.
   #
   # Usage: bash sentinel-harness.sh <command-and-args>...
   #
   # Mechanism (AD-9):
   #   1. Write .orchestrator/.m029-sc14-sentinel with the current ISO-8601 UTC timestamp.
   #   2. Capture the sentinel's mtime via `stat`.
   #   3. Run the wrapped command.
   #   4. Scan .orchestrator/ for any file whose mtime is newer than the sentinel's,
   #      EXCLUDING the sentinel itself AND .orchestrator/start-state/*.complete.
   #   5. PASS iff no offenders; FAIL with one line per offender otherwise.
   #
   # Bash 3.2 / MEM001 compatible. AD-19: straight-line bash. No process substitution.

   set -u

   if [ $# -lt 1 ]; then
       printf 'Usage: sentinel-harness.sh <command> [args...]\n' >&2
       exit 2
   fi

   ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"
   if [ ! -d "$ORCH_ROOT" ]; then
       printf 'sentinel-harness.sh: %s does not exist\n' "$ORCH_ROOT" >&2
       exit 2
   fi

   SENTINEL="$ORCH_ROOT/.m029-sc14-sentinel"
   date -u +%Y-%m-%dT%H:%M:%SZ > "$SENTINEL"

   # Run the wrapped command. Forward exit code on failure but always proceed
   # to the sentinel scan so the operator sees both the command failure AND
   # any read-only violation.
   "$@"
   CMD_RC=$?

   # find -newer is AD-19 safe (single command, no pipe, no $()).
   # Use a tempfile to capture the find output.
   TMP_OUT="${TMPDIR:-/tmp}/m029-sentinel-scan.$$"
   find "$ORCH_ROOT" -type f -newer "$SENTINEL" \
       ! -path "$SENTINEL" \
       ! -path "$ORCH_ROOT/start-state/*.complete" \
       > "$TMP_OUT" 2>/dev/null

   fail=0
   while IFS= read -r line; do
       [ -n "$line" ] || continue
       printf 'FAIL: read-only invariant violated by %s\n' "$line"
       fail=$(( fail + 1 ))
   done < "$TMP_OUT"
   rm -f "$TMP_OUT"

   if [ "$fail" -eq 0 ]; then
       printf 'PASS: read-only invariant held\n'
       printf 'SUMMARY: sentinel-harness.sh pass=1 fail=0\n'
       exit "$CMD_RC"
   fi

   printf 'SUMMARY: sentinel-harness.sh pass=0 fail=%d\n' "$fail"
   exit 1
   ```

   `chmod +x`.

6. **Create `tests/m029-acceptance/p02-sc5-where-mixed-state.sh`** (≥25 lines, executable, AD-19 single-script-file shape):
   - Asserts the fixture tree exists.
   - Asserts the golden file exists.
   - Captures `bash scripts/diagnostics/render-position.sh --milestone M998 --root tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator` stdout to `${TMPDIR:-/tmp}/m029-sc5-actual.$$.raw`.
   - Pipes through `bash tests/m029-acceptance/timestamp-strip.sh` to produce `${TMPDIR:-/tmp}/m029-sc5-actual.$$.normalized` (script body pipe is permitted per MEM004 carve-out; the assertion line that runs the diff is straight-line bash).
   - Diffs the normalized file against `tests/m029-acceptance/fixtures/where-mixed-state.golden` via `diff -u`.
   - On byte-identity: `PASS: SC-5 byte-identity` + final `SUMMARY: p02-sc5-where-mixed-state.sh pass=N fail=0`. Exit 0.
   - On diff: emit the diff verbatim (helpful for debugging) + `FAIL: SC-5 byte-identity` + final SUMMARY. Exit 1.
   - Cleans up tempfiles on EXIT via `trap`.

7. **Create `tests/m029-acceptance/p02-sc6-where-pre-m019.sh`** (≥20 lines, executable, AD-19 single-script-file shape):
   - Asserts the pre-M019 fixture tree exists.
   - Captures `bash scripts/diagnostics/render-position.sh --milestone M997 --root tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator` stdout to a tempfile and stderr to a separate tempfile (uses standard `> stdout 2> stderr` redirection — straight-line, AD-19 safe).
   - Asserts the cost column delimiter (e.g. literal `cost=` or the column header `cost`) does NOT appear in stdout.
   - Asserts stderr is byte-empty (`[ ! -s "$stderr_file" ]`).
   - On both: `PASS: SC-6 cost column suppressed` + `PASS: SC-6 stderr empty` + `SUMMARY: p02-sc6-where-pre-m019.sh pass=N fail=0`. Exit 0.
   - Cleans up tempfiles on EXIT.

8. **Create `tests/m029-acceptance/p02-sc13-anti-coupling.sh`** (≥15 lines, executable, AD-19 single-script-file shape):
   - Runs `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/` capturing exit code; **expects** exit 1 (no match).
   - Runs `grep -F '/integrations/github' scripts/diagnostics/render-position.sh` capturing exit code; **expects** exit 1 (no match).
   - On both no-match: `PASS: SC-13 spec anti-coupling` + `PASS: SC-13 renderer anti-coupling` + `SUMMARY: p02-sc13-anti-coupling.sh pass=N fail=0`. Exit 0.
   - Per AD-19: avoid `if grep | grep`; capture exit codes via straight `grep ...; rc=$?`.

9. **Create `tests/m029-acceptance/p02-sc14-readonly.sh`** (≥20 lines, executable, AD-19 single-script-file shape):
   - Asserts `[ -x tests/m029-acceptance/sentinel-harness.sh ]`.
   - Sets `ORCHESTRATOR_ROOT="$PWD/tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator"` so the harness scans the FIXTURE tree, not the project tree (the renderer is read-only against `.orchestrator/`; SC-14 must enforce this against the fixture's tree to avoid false-positive collisions with developer state in the live `.orchestrator/`).
   - Invokes `bash tests/m029-acceptance/sentinel-harness.sh bash scripts/diagnostics/render-position.sh --milestone M998 --root "$ORCHESTRATOR_ROOT" > /dev/null`.
   - Captures the harness exit code.
   - On exit 0 (harness asserts read-only invariant held): `PASS: SC-14 read-only invariant` + `SUMMARY: p02-sc14-readonly.sh pass=N fail=0`. Exit 0.
   - On non-zero: `FAIL:` + propagate harness output + `SUMMARY: ... fail=1`. Exit 1.

10. **Author `tools/verify/m029-p02-sc5-fixtures-shape.sh`** (≥30 lines, executable, AD-19):
    - Asserts the fixture trees exist (`[ -d tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator/milestones/M998 ]`, `[ -d tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator/milestones/M997 ]`).
    - Asserts the golden file exists and contains all four glyphs literally (`✓ ▶ ◇ ✗`).
    - Asserts `timestamp-strip.sh` exists, is executable, and references the three #Q-G6 patterns (`<TS>`, `<RECENCY>`, `<EPOCH>` placeholders).
    - Asserts the canonical `▽ saved Nk` form does NOT appear in any P02 fixture file (the at-rest renderer never emits the savings glyph; T04 fixtures must not contain it). Asserts the verbose form `via tier1 cache reuse` does NOT appear anywhere in the fixture tree (#Q-G8).
    - Emits SUMMARY.

11. **Author `tools/verify/m029-p02-sentinel-harness-shape.sh`** (≥25 lines, executable, AD-19):
    - Asserts `[ -x tests/m029-acceptance/sentinel-harness.sh ]`.
    - Asserts the script declares the AD-9 sentinel file path literal (`.m029-sc14-sentinel`).
    - Asserts the script excludes `start-state/*.complete` (AD-9 documented exception).
    - Asserts the script invokes `find ... -newer` (the AD-9 mechanism).
    - Asserts the read-only contract token (`AD-9` or `read-only`) appears in the header.
    - Behavioral spot-check: invoke the harness against a no-op (`bash sentinel-harness.sh true`) under a temp `ORCHESTRATOR_ROOT` and assert it exits 0 with `PASS: read-only invariant held`. Use a `${TMPDIR:-/tmp}/m029-sentinel-test.$$/` temp tree containing an empty `.orchestrator/` directory.
    - Emits SUMMARY.

12. **Author `tools/verify/m029-p02-sc5-shape.sh`**, **`m029-p02-sc6-shape.sh`**, **`m029-p02-sc13-shape.sh`**, **`m029-p02-sc14-shape.sh`** (each ≥20 lines, executable, AD-19) — one shape verifier per acceptance script. Each:
    - Asserts the corresponding `tests/m029-acceptance/p02-sc##-*.sh` exists, is executable.
    - Asserts the script references the correct surfaces (e.g. SC-5 references `where-mixed-state.golden` AND `timestamp-strip.sh`; SC-13 references `/integrations/github`; SC-14 references `sentinel-harness.sh`).
    - Asserts the script emits the standard `SUMMARY: p02-sc##-*.sh pass=N fail=M` line shape.
    - **Behavioral run**: invokes the acceptance script and asserts exit 0 (full SC pass against the fixtures T04 just built). This is the load-bearing assertion that proves the fixtures actually work end-to-end.
    - Emits SUMMARY.

13. **`chmod +x` every new `.sh` file**.

## Must-Haves

This task addresses these P02 phase truths:
- The SC-5 mixed-state golden fixture covers all four glyph states and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set.
- `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns (#Q-G6 resolution).
- The FR-8 marker canonical form `▽ saved Nk` is the only form that appears in fixtures (no `via tier1 cache reuse` anywhere) (#Q-G8 resolution).
- The SC-14 sentinel-file harness implements the AD-9 mechanism (write sentinel before read; assert no `.orchestrator/` mtime newer than the sentinel after).
- The SC-5 acceptance script renders against the mixed-state fixture, normalizes via `timestamp-strip.sh`, and diffs against the golden with exit 0.
- The SC-6 acceptance script asserts cost column omitted AND stderr empty on the pre-M019 fixture.
- The SC-13 anti-coupling guard asserts no `/integrations/github` match in spec or render path.
- The SC-14 acceptance script wraps the sentinel harness around `where` and asserts read-only invariant held.

This task creates these P02 phase artifacts:
- Mixed-state fixture tree under `tests/m029-acceptance/fixtures/where-mixed-state.fixture/`.
- Golden render at `tests/m029-acceptance/fixtures/where-mixed-state.golden`.
- Pre-M019 fixture tree under `tests/m029-acceptance/fixtures/where-pre-m019.fixture/`.
- Timestamp-strip filter at `tests/m029-acceptance/timestamp-strip.sh`.
- AD-9 sentinel harness at `tests/m029-acceptance/sentinel-harness.sh`.
- Four SC acceptance scripts at `tests/m029-acceptance/p02-sc{5,6,13,14}-*.sh`.
- Six shape verifiers at `tools/verify/m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh`, `m029-p02-sc{5,6,13,14}-shape.sh`.

## Verification

```bash
bash tools/verify/m029-p02-sc5-fixtures-shape.sh
```

```bash
bash tools/verify/m029-p02-sentinel-harness-shape.sh
```

```bash
bash tools/verify/m029-p02-sc5-shape.sh
```

```bash
bash tools/verify/m029-p02-sc6-shape.sh
```

```bash
bash tools/verify/m029-p02-sc13-shape.sh
```

```bash
bash tools/verify/m029-p02-sc14-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/diagnostics/render-position.sh` (from T03)
  - Key API: `bash render-position.sh --milestone <M###> --root <fixture-orch-root>` emits the tree to stdout; `--no-cost` suppresses the cost column; `--expand-all` expands inactive milestones.
  - Key behavior: read-only against `.orchestrator/`, never invokes GitHub APIs, suppresses cost column silently on pre-M019 milestones.
- `commands/where.md` (from T03) — the orchestrator-level skill; not directly invoked by acceptance scripts (which test the engine), but referenced by SC-13's anti-coupling grep when extended.
- `scripts/diagnostics/summarize-milestone.sh` (from T02) — used transitively by T03's renderer.
- `references/cross-milestone-feature-shape.md` (from T01) — the AD-6 schema authority for fixture frontmatter shape.

### From Disk (Pre-existing)

- `tests/m029-acceptance/fixtures/` directory — created by P01 (status fixtures).
- `tests/m029-acceptance/p01-sc{1,2,3,4}-*.sh` — sibling acceptance-script shape precedents.
- `scripts/state/find-active-milestone.sh` — invoked by T03's renderer.
- M019 Tier 1 JSONL schema documentation: `record_type=dispatch_usage`, `granularity=task`, `milestone=...`, `phase=...`, `task=...`, plus the cost / quality fields enumerated in `scripts/diagnostics/metrics-rollup.sh` header (≈ lines 22–34).
- `tools/verify/m029-p01-headline-shape-contract.sh` — verifier shape precedent.

## Constraints

- **Read-only renderer (CON-1 / FR-14)**: `render-position.sh` MUST NOT mutate `.orchestrator/`. SC-14 enforces this.
- **No GitHub API (CON-4 / FR-11)**: SC-13 enforces this; T04's fixtures contain no GitHub sidecars.
- **#Q-G6 enumerated patterns**: `timestamp-strip.sh` MUST enumerate exactly the three documented regex patterns. Adding patterns silently risks under-stripping in CI; missing one causes byte-identity failures from natural drift.
- **#Q-G8 canonical marker form**: NO occurrences of `▽ saved Nk via tier1 cache reuse` ANYWHERE in T04 deliverables (fixtures, golden, scripts). The verbose form is reserved for a future `--verbose` mode.
- **AD-19 verifier shape**: every shape verifier and acceptance script MUST be straight-line bash on Check: lines. Pipes are permitted INSIDE script bodies (MEM004 carve-out — sed/awk/grep pipes are legitimate transformation tools). The constraint is that the `Check:` line invoked from the harness is a single `bash <path>` invocation.
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO process substitution, NO `<<<` herestring.
- **`run-probe.sh` scope discipline (rule 4)**: tempfiles MUST live under `${TMPDIR:-/tmp}` (the staged-probe domain). NO writes outside `/tmp`, `/var/folders`, or `<repo>/tmp/`.
- **CON-7 + AD-8**: T04 introduces NO new schemas. Fixtures consume existing M019 Tier 1 / [M020](../../../../../milestones/M020/index.md) / [M027](../../../../../milestones/M027/index.md) schemas; T04's only schema-relevant artifact is fixture data conforming to those schemas.
- **Path-collision rule 6**: every fixture path was checked at plan-authoring time — all clean.

## Expected Output

After T04 completes:
- All fixture trees, the golden, the strip filter, the sentinel harness, and the four SC acceptance scripts are on disk and executable.
- The six shape verifiers in `tools/verify/m029-p02-sc{5,6,13,14}-shape.sh`, `m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh` exit 0 from project root.
- Each acceptance script (`p02-sc5-where-mixed-state.sh`, `p02-sc6-where-pre-m019.sh`, `p02-sc13-anti-coupling.sh`, `p02-sc14-readonly.sh`) exits 0 when invoked directly.
- A summary file at [`.orchestrator/milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md`](../../../../../milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
- `m029-p02-sc5-fixtures-shape.sh`: ≈8–10 PASS lines + SUMMARY.
- `m029-p02-sentinel-harness-shape.sh`: ≈6–8 PASS lines + behavioral spot-check PASS + SUMMARY.
- `m029-p02-sc5-shape.sh`: shape PASSes + behavioral SC-5 PASS (the full byte-identical golden diff) + SUMMARY.
- `m029-p02-sc6-shape.sh`: shape PASSes + behavioral SC-6 PASS (cost column omitted + stderr empty) + SUMMARY.
- `m029-p02-sc13-shape.sh`: shape PASSes + behavioral SC-13 PASS (no `/integrations/github` matches) + SUMMARY.
- `m029-p02-sc14-shape.sh`: shape PASSes + behavioral SC-14 PASS (sentinel harness reports read-only invariant held) + SUMMARY.

The phase-suite aggregator (T05) chains all six T04 verifiers as gates 5–10.

Why the mixed-state fixture uses M998/M997 (not M029): keeping fixture milestones in the M9xx range avoids any collision with real milestones, mirrors the P01 SC-2 fixture-milestone convention (M999), and keeps the fixture tree fully self-contained under `tests/m029-acceptance/fixtures/`. The renderer's `--root` flag points it at the fixture's `.orchestrator/` so production state is never read.

Why `find -newer` rather than `stat | sort` (AD-9 mechanism choice): `find -newer <sentinel>` is a single-command AD-19-safe invocation that returns one path per line — straight to the loop. `stat | sort | diff` would chain three commands with pipes (compound-chain-gt2), tripping the harness shape-guard. The AD-9 mechanism was specifically designed around this constraint.

Why the SC-13 verifier uses TWO greps rather than one wildcard: `grep -r 'pattern' specs/ scripts/` would mix the spec directory and a single file in one invocation, but `render-position.sh` is a single file (not a tree), and combining can mask which surface had the leak. Two separate greps produce diagnostic clarity at the cost of one extra line.
