---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M036"
name: "SC-4 fixture test + phase-suite aggregator"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `tools/verify/m036-p05-edges-schema-accepts-new.sh`, `tools/verify/m036-p05-edges-schema-accepts-old.sh`, and `tools/verify/m036-p05-rebuild-emits-new-edges.sh`. Verified by inspecting `tools/verify/` for the three filenames before starting T04.
- T02 has shipped `tools/verify/m036-p05-traverse-cites.sh` and `tools/verify/m036-p05-traverse-relates-to-baseline.sh`. Verified by inspection.
- T03 has shipped `tools/verify/m036-p05-scope-filter-source-tag.sh` and `tools/verify/m036-p05-scope-filter-baseline.sh`. Verified by inspection.

## Description

Author the SC-4 end-to-end fixture test (`tests/test-reference-graph-edges.sh`), the SC-4 verifier wrapper that calls into it from `tools/verify/`, and the phase-suite aggregator (`tools/verify/m036-p05-phase-suite.sh`) that wires all 8 sub-gates from T01/T02/T03/T04 and emits the canonical `SUMMARY:` line.

The SC-4 test is the user-facing acceptance criterion: it exercises the complete data path end-to-end (frontmatter → rebuild → DB → traverser → graph output) using fixture chunks that match the spec's acceptance scenario verbatim.

The phase-suite aggregator follows the same shape as `tools/verify/m036-p00-phase-suite.sh` (P00 deliverable, recovered after the [M031](../../../../../milestones/M031/index.md)→M036 collision incident). It runs each sub-gate, counts pass/fail, and emits one `SUMMARY:` line.

## Steps

1. **Author `tests/test-reference-graph-edges.sh`** — the SC-4 end-to-end test. Mirrors the existing test conventions in `tests/` (pass/fail counters, prefixed output lines per MEM001/MEM002):
   ```bash
   #!/usr/bin/env bash
   # tests/test-reference-graph-edges.sh — SC-4 acceptance for M036/P05
   # Asserts: a spec chunk declaring cites: [REF-X] traverses at depth 1
   # to REF-X with the 'cites' edge label preserved.
   set -euo pipefail

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

   pass_count=0
   fail_count=0
   pass() { echo "PASS: $*"; pass_count=$((pass_count + 1)); }
   fail() { echo "FAIL: $*" >&2; fail_count=$((fail_count + 1)); }

   tmpdir="$(mktemp -d)"
   trap 'rm -rf "$tmpdir"' EXIT

   # --- Stage fixture knowledge tree ---
   mkdir -p "$tmpdir/knowledge/spec/requirement"
   mkdir -p "$tmpdir/knowledge/reference/cms-rule"

   cat > "$tmpdir/knowledge/spec/requirement/SPEC-requirement-FR-7.md" <<'FIXTURE_SPEC'
   ---
   id: SPEC-requirement-FR-7
   category: spec/requirement
   confidence: 0.95
   created_at: 2026-05-01
   last_verified: 2026-05-01
   hit_count: 0
   cites: [REF-cms-rule-483-20]
   ---
   # SPEC-requirement-FR-7: fixture for SC-4
   FIXTURE_SPEC

   cat > "$tmpdir/knowledge/reference/cms-rule/REF-cms-rule-483-20.md" <<'FIXTURE_REF'
   ---
   id: REF-cms-rule-483-20
   category: reference/cms-rule
   confidence: 0.95
   created_at: 2026-05-01
   last_verified: 2026-05-01
   hit_count: 0
   ---
   # REF-cms-rule-483-20: fixture for SC-4
   FIXTURE_REF

   # --- Rebuild index against staged tree ---
   PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1 || {
     fail "SC-4: rebuild-index failed"
     echo "TEST: pass=$pass_count fail=$fail_count"
     exit 1
   }

   # --- Traverse from spec chunk, asserting cites edge surfaces target ---
   output="$(PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/traverse-graph.sh" --id SPEC-requirement-FR-7 --edge-types cites --max-depth 1 2>&1 || true)"

   if echo "$output" | grep -qF "REF-cms-rule-483-20|cites"; then
     pass "SC-4: cites edge surfaced with label (output: $output)"
   else
     fail "SC-4: expected 'REF-cms-rule-483-20|cites' in output, got: $output"
   fi

   echo "TEST: pass=$pass_count fail=$fail_count"
   [ "$fail_count" -eq 0 ]
   ```

2. **Author `tools/verify/m036-p05-sc4-test-exists-and-passes.sh`** — wraps the SC-4 test in a single-script-file Truth Check shell. The verifier asserts (a) the test file exists, (b) running it exits 0:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   test_file="$ROOT/tests/test-reference-graph-edges.sh"
   if [ ! -f "$test_file" ]; then
     echo "FAIL: tests/test-reference-graph-edges.sh missing" >&2
     exit 1
   fi
   if bash "$test_file" >/dev/null 2>&1; then
     echo "PASS: m036-p05-sc4-test-exists-and-passes (SC-4)"
     exit 0
   fi
   echo "FAIL: m036-p05-sc4-test-exists-and-passes (test exited non-zero)" >&2
   exit 1
   ```

3. **Author `tools/verify/m036-p05-phase-suite.sh`** — the phase-suite aggregator. Runs the 8 sub-gates serially, counts results, emits one `SUMMARY:` line. Pattern matches the existing `tools/verify/m036-p00-phase-suite.sh` exactly (read it first to mirror format conventions). Skeleton:
   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p05-phase-suite.sh — Phase-suite aggregator for M036/P05.
   # Runs all 8 P05 sub-gates and emits one SUMMARY: line.
   set -euo pipefail

   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0
   fail=0
   run() {
     local script="$1"
     if bash "$ROOT/$script" >/dev/null 2>&1; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "SUB-FAIL: $script" >&2
     fi
   }

   run tools/verify/m036-p05-edges-schema-accepts-new.sh
   run tools/verify/m036-p05-edges-schema-accepts-old.sh
   run tools/verify/m036-p05-rebuild-emits-new-edges.sh
   run tools/verify/m036-p05-traverse-cites.sh
   run tools/verify/m036-p05-traverse-relates-to-baseline.sh
   run tools/verify/m036-p05-scope-filter-source-tag.sh
   run tools/verify/m036-p05-scope-filter-baseline.sh
   run tools/verify/m036-p05-sc4-test-exists-and-passes.sh

   echo "SUMMARY: m036-p05-phase-suite.sh pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

4. **Set executable bits** on all 4 new files (the test script + the wrapper verifier + the aggregator + any not-yet-chmod'd files from T01/T02/T03):
   ```bash
   chmod +x tests/test-reference-graph-edges.sh
   chmod +x tools/verify/m036-p05-sc4-test-exists-and-passes.sh
   chmod +x tools/verify/m036-p05-phase-suite.sh
   ```
   (Existing scripts in `tools/verify/` are already executable per the M036 P00 convention; verify with `ls -l tools/verify/m036-p05-*.sh` after.)

## Must-Haves

Truths from the phase plan addressed by this task:

- "`tests/test-reference-graph-edges.sh` exists, exercises SC-4 end-to-end (fixture spec + reference + traverse + grep), and exits 0" — covered by steps 1+2.
- "Phase-suite aggregator runs all 8 sub-gates with `pass=8 fail=0`" — covered by step 3.

## Verification

```bash
bash tools/verify/m036-p05-sc4-test-exists-and-passes.sh
```

```bash
bash tools/verify/m036-p05-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `tools/verify/m036-p05-edges-schema-accepts-new.sh` (T01)
- `tools/verify/m036-p05-edges-schema-accepts-old.sh` (T01)
- `tools/verify/m036-p05-rebuild-emits-new-edges.sh` (T01)
- `tools/verify/m036-p05-traverse-cites.sh` (T02)
- `tools/verify/m036-p05-traverse-relates-to-baseline.sh` (T02)
- `tools/verify/m036-p05-scope-filter-source-tag.sh` (T03)
- `tools/verify/m036-p05-scope-filter-baseline.sh` (T03)

  Each verifier emits exit 0 + a `PASS:` line on success; exit 1 + a `FAIL:` line on failure. The aggregator suppresses stdout/stderr (`>/dev/null 2>&1`) and only counts exit codes; sub-failures are surfaced via the `SUB-FAIL:` line emitted by the aggregator's `run` function.

- `scripts/knowledge/traverse-graph.sh` (T02-modified) — supports `--edge-types cites --max-depth 1` and emits `<id>|cites` for fixture data.
- `scripts/knowledge/rebuild-index.sh` (T01-modified) — emits `cites` edges into the staged DB.

### From Disk (Pre-existing)

- `tools/verify/m036-p00-phase-suite.sh` — read for the canonical aggregator shape (run helper, SUMMARY: emission, exit-1-on-any-fail). Mirror the format exactly.
- `tests/test-fixtures/`, `tests/test-*.sh` — read 1-2 existing test files for the pass/fail counter convention (MEM002 pattern).

## Constraints

- **`tests/test-reference-graph-edges.sh` MUST be standalone** — it stages its own fixture, runs `rebuild-index` against `PROJECT_ROOT=$tmpdir`, traverses against the staged DB, and tears down on EXIT. It does NOT depend on the live `knowledge/` tree.
- **Phase-suite aggregator MUST emit exactly one `SUMMARY:` line** — the format `SUMMARY: m036-p05-phase-suite.sh pass=$pass fail=$fail` is consumed downstream by `scripts/verify/check-must-haves.sh` and the aggregator-of-aggregators pattern. Multiple `SUMMARY:` lines break that consumer.
- **Aggregator exits 1 if ANY sub-gate fails** — even when 7/8 pass. The `[ "$fail" -eq 0 ]` line at the end of the aggregator enforces. The Truth Check inside the phase plan only passes when all 8 sub-gates green.
- **`SUB-FAIL:` to stderr** — debug surface; the aggregator's stdout is reserved for the canonical `SUMMARY:` line.
- **Single-script-file Truth Check shape (AD-19)** — both Verification commands are single `bash <path>` invocations.
- **No hardcoded ROOT path** — `ROOT="$(cd "$(dirname "$0")/../.." && pwd)"` resolves at runtime so the aggregator works regardless of the cwd of the caller.
- **Path-collision discipline** — every artifact T04 creates uses the milestone-prefixed `m036-p05-*.sh` slug. The pre-existing [M030](../../../../../milestones/M030/index.md) `p05-*.sh` set is unaffected. Re-verify at task-execution time with `ls -la tools/verify/m036-p05-*.sh tests/test-reference-graph-edges.sh` — none should exist before T04 starts (they were declared `create` in the phase plan).

## Expected Output

`m036-p05-sc4-test-exists-and-passes.sh` prints `PASS: m036-p05-sc4-test-exists-and-passes (SC-4)`.

`m036-p05-phase-suite.sh` prints `SUMMARY: m036-p05-phase-suite.sh pass=8 fail=0` and exits 0.

After T04 lands, P05 closes: every truth from the phase plan has a green Truth Check command, the SC-4 acceptance is demonstrated end-to-end via fixture, and the phase-suite aggregator gates the M036/P05 SUMMARY for downstream consumption (M036 milestone-suite aggregator, future M036/P06 ingest work, etc.).

## Notes — Real-DB verification posture

This task closes the rule-5 (real-DB SQL verification) chain for the phase. Every sub-gate it runs:
- T01 verifiers: stage real `mktemp` SQLite DBs, call `db_init`, attempt real `INSERT INTO edges` rows, `SELECT COUNT(*)` against the real tables.
- T02 verifiers: rebuild against a real staged DB, traverse via real recursive CTE, grep real stdout.
- T03 verifiers: filter against a real fixture file, optionally a real staged graph DB.
- T04 SC-4 verifier: full real data path — fixture chunks → real rebuild → real DB → real traverse → grep label.

No mocks. The mock-vs-real-schema column-name-drift risk that motivated rule 5 cannot apply because (a) we hold edge-type names in lockstep with the SSOT (`references/reference-edge-types.md`) by grep-checking the SSOT for each name in the schema-accepts verifiers, and (b) the SC-4 test exercises the full path against real SQLite.

## Notes — Verifier-availability cross-check (Plan-Time Discipline rule 2)

Every Verification command in T01–T04's Verification sections invokes a `tools/verify/m036-p05-*.sh` script that is co-authored alongside the deliverable in the same task (T01 authors its three; T02 authors its two; T03 authors its two; T04 authors the SC-4 wrapper plus the aggregator). No cross-task verifier dependencies — T01's verifiers don't reference T02's, T02's don't reference T03's. The phase-suite aggregator (T04 deliverable) is the only file that references all 8 verifiers, and by T04 dispatch time, all 7 prerequisite verifiers exist on disk (verified by the Prerequisites block at the top of this file).
