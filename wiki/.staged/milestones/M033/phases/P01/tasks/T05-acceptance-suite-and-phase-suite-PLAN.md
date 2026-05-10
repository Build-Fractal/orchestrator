---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M033"
name: "SC-1 + SC-8 acceptance scripts + m033-p01-* phase-suite + scope-guard verifiers"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 complete: `tests/fixtures/m033-pbj-materials-fixture/` exists with the four PBJ-shape `.md` files (used as the rule-2 fixture in SC-1's six-fixture sweep).
- T02 complete: `references/branch-detection.md` exists (the SSOT cross-referenced by start.sh).
- T03 complete: `commands/start.md` and `scripts/lifecycle/start.sh` exist; start.sh implements FR-2 detection, idempotent init invocation, sub-flow stubs, and the disambiguation question.
- T04 complete: `tests/m033-acceptance/friendly-tester-pass/protocol.md`, `report-template.md`, `validate-report.sh`, and the two report fixtures exist.
- `tests/m033-acceptance/` directory exists (created by T04).
- `tools/verify/` exists with all P01 verifier scripts authored by T01–T04 (eleven verifiers prior to T05; T05 adds three more — sc1, sc8, phase-suite, scope-guard).

## Description

T05 closes P01 by shipping (a) the `tests/m033-acceptance/p01-start-branch-routing.sh` acceptance script (SC-1), (b) the `tests/m033-acceptance/p07-friendly-tester-protocol.sh` acceptance script (SC-8), (c) the `tools/verify/m033-p01-phase-suite.sh` aggregator chaining all 14 P01 verifiers, and (d) the `tools/verify/m033-p01-scope-guard.sh` invariant verifier (SC-13 derivation contribution).

**Why two acceptance script names?** SC-1 verifies the branch-routing surface (US-1 / FR-1 / FR-2). SC-8 verifies the friendly-tester artifact shape (US-8 / FR-19). Both ship in P01 even though SC-8's filename uses a `p07-` prefix — per the spec's SC-14 amendment, the battery runs all `p*.sh` scripts under `tests/m033-acceptance/`, and the `p07-` prefix anchors the friendly-tester concern to the same development phase grouping as the other US-7-domain test scripts (grilling shell, resume-on-partial-state, observability) that ship in P02–P04. Shipping the `p07-friendly-tester-protocol.sh` script in P01 (alongside its FR-19 deliverables) is the load-bearing decision — it lets recruiting + scheduling start in parallel with P02–P05.

**Scope-guard rationale.** The scope-guard verifier asserts that P01's diff did not touch any P02–P05 files. The check is forward-looking: even though P02–P05's files do not yet exist (the scope-guard greps for their nonexistence as a paths-not-touched assertion), the verifier exists at P01 close to record the invariant for the milestone-close audit.

## Steps

1. **Author `tests/m033-acceptance/p01-start-branch-routing.sh`** (≥120 lines, executable, `chmod +x`, bash 3.2 compatible). Header naming SC-1 / FR-1 / FR-2 / US-1.

   The script structure:

   ```bash
   #!/usr/bin/env bash
   set -e -u -o pipefail

   # SC-1: M033 P01 branch-routing acceptance test.
   # Asserts FR-1 (start-command-skeleton) + FR-2 (branch-detection-rules)
   # against six fixture shapes.

   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   STAGING_BASE="$(mktemp -d)/m033-p01-sc1-$$"
   mkdir -p "$STAGING_BASE"

   cleanup() { rm -rf "$STAGING_BASE"; }
   trap cleanup EXIT

   pass=0
   fail=0

   pass() { pass=$((pass+1)); echo "PASS: $1"; }
   fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

   # Helper: stage fixture-N at a temp dir, populate it per the requested shape.
   make_fixture_1_greenfield_empty() {
     local d="$STAGING_BASE/fix1"; mkdir -p "$d"; echo "$d"
   }
   make_fixture_2_greenfield_with_materials() {
     local d="$STAGING_BASE/fix2"; mkdir -p "$d"
     printf 'placeholder\n' > "$d/PRODUCT-BRIEF.md"
     printf 'placeholder\n' > "$d/MVP-PLAN.md"
     printf 'placeholder\n' > "$d/DECISIONS.md"
     echo "$d"
   }
   make_fixture_3_existing_codebase() {
     local d="$STAGING_BASE/fix3"; mkdir -p "$d/src"
     printf '{}\n' > "$d/package.json"
     printf 'export const x = 1;\n' > "$d/src/index.ts"
     git -C "$d" init -q
     git -C "$d" add -A
     git -C "$d" -c user.email=fixture@example.com -c user.name=fixture commit -q -m initial
     echo "$d"
   }
   make_fixture_4_migrating() {
     local d="$STAGING_BASE/fix4"; mkdir -p "$d/.gsd"
     printf 'version: 1\n' > "$d/.gsd/v1-roadmap.yml"
     echo "$d"
   }
   make_fixture_5_ambiguous() {
     local d="$STAGING_BASE/fix5"; mkdir -p "$d/src" "$d/.gsd"
     printf '{}\n' > "$d/package.json"
     printf 'version: 1\n' > "$d/.gsd/v1-roadmap.yml"
     echo "$d"
   }
   make_fixture_6_mit006() {
     local d="$STAGING_BASE/fix6"; mkdir -p "$d"
     printf 'export const x = 1;\n' > "$d/index.ts"
     git -C "$d" init -q
     git -C "$d" add -A
     git -C "$d" -c user.email=fixture@example.com -c user.name=fixture commit -q -m initial
     echo "$d"
   }

   # Test 1: greenfield-empty
   f1=$(make_fixture_1_greenfield_empty)
   out1=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f1" --yes --dry-run 2>&1) || fail "fixture-1 start failed"
   echo "$out1" | grep -q '^branch: greenfield-empty' && pass "fixture-1 detects greenfield-empty" || fail "fixture-1 wrong branch"
   echo "$out1" | grep -q 'would-execute: ideation-stub' && pass "fixture-1 dispatches ideation-stub" || fail "fixture-1 wrong stub"

   # Test 2: greenfield-with-materials
   f2=$(make_fixture_2_greenfield_with_materials)
   out2=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f2" --yes --dry-run 2>&1) || fail "fixture-2 start failed"
   echo "$out2" | grep -q '^branch: greenfield-with-materials' && pass "fixture-2 detects greenfield-with-materials" || fail "fixture-2 wrong branch"
   echo "$out2" | grep -q 'would-execute: materials-intake-stub' && pass "fixture-2 dispatches materials-intake-stub" || fail "fixture-2 wrong stub"

   # Test 3: existing-codebase
   f3=$(make_fixture_3_existing_codebase)
   out3=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f3" --yes --dry-run 2>&1) || fail "fixture-3 start failed"
   echo "$out3" | grep -q '^branch: existing-codebase' && pass "fixture-3 detects existing-codebase" || fail "fixture-3 wrong branch"
   echo "$out3" | grep -q 'would-execute: ingest-codebase-stub' && pass "fixture-3 dispatches ingest-codebase-stub" || fail "fixture-3 wrong stub"

   # Test 4: migrating
   f4=$(make_fixture_4_migrating)
   out4=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f4" --yes --dry-run 2>&1) || fail "fixture-4 start failed"
   echo "$out4" | grep -q '^branch: migrating' && pass "fixture-4 detects migrating" || fail "fixture-4 wrong branch"
   echo "$out4" | grep -q 'would-execute: migrate-routing-stub' && pass "fixture-4 dispatches migrate-routing-stub" || fail "fixture-4 wrong stub"
   echo "$out4" | grep -q -- '--from gsd-v1' && pass "fixture-4 pre-fills --from gsd-v1" || fail "fixture-4 wrong --from"

   # Test 5: ambiguous (rule-1 + rule-3) — disambiguation question fires without --yes
   f5=$(make_fixture_5_ambiguous)
   out5=$(cd "$PROJECT_ROOT" && printf 'y\n' | bash scripts/lifecycle/start.sh --project-dir "$f5" --dry-run 2>&1) || true
   echo "$out5" | grep -q 'disambiguation:' && pass "fixture-5 fires disambiguation question" || fail "fixture-5 missing disambiguation"
   echo "$out5" | grep -q 'recommended:' && pass "fixture-5 recommendation present" || fail "fixture-5 missing recommendation"

   # Test 6: MIT-006 / RISK-006 (git-init-only, ≤9 source files)
   f6=$(make_fixture_6_mit006)
   out6=$(cd "$PROJECT_ROOT" && printf 'y\n' | bash scripts/lifecycle/start.sh --project-dir "$f6" --dry-run 2>&1) || true
   echo "$out6" | grep -q 'MIT-006' && pass "fixture-6 fires MIT-006 disambiguation" || fail "fixture-6 missing MIT-006"
   echo "$out6" | grep -q 'recommended: greenfield-empty' && pass "fixture-6 recommends greenfield-empty" || fail "fixture-6 wrong MIT-006 recommendation"

   # Idempotency: re-run against fixture-1, assert "init already complete"
   out1b=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f1" --yes --dry-run 2>&1) || fail "fixture-1 re-run failed"
   echo "$out1b" | grep -q 'init already complete' && pass "fixture-1 second run idempotent" || fail "fixture-1 second run not idempotent"

   echo "SUMMARY: p01-start-branch-routing.sh pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Required content tokens (for the verifier wrapper): `SC-1`, `FR-1`, `FR-2`, `greenfield-empty`, `greenfield-with-materials`, `existing-codebase`, `migrating`, `MIT-006`, `init already complete`.

2. **Author `tests/m033-acceptance/p07-friendly-tester-protocol.sh`** (≥60 lines, executable, `chmod +x`, bash 3.2 compatible). Header naming SC-8 / FR-19. The script:

   ```bash
   #!/usr/bin/env bash
   set -e -u -o pipefail

   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FT_DIR="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass"

   pass=0; fail=0
   pass() { pass=$((pass+1)); echo "PASS: $1"; }
   fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

   [ -f "$FT_DIR/protocol.md" ] && pass "protocol.md exists" || fail "protocol.md missing"
   [ -f "$FT_DIR/report-template.md" ] && pass "report-template.md exists" || fail "report-template.md missing"
   [ -x "$FT_DIR/validate-report.sh" ] && pass "validate-report.sh executable" || fail "validate-report.sh not executable"
   [ -f "$FT_DIR/fixtures/report-pass.md" ] && pass "report-pass.md exists" || fail "report-pass.md missing"
   [ -f "$FT_DIR/fixtures/report-fail.md" ] && pass "report-fail.md exists" || fail "report-fail.md missing"

   grep -q 'tester-eligibility' "$FT_DIR/protocol.md" && pass "protocol.md has tester-eligibility section" || fail "protocol.md missing tester-eligibility"
   grep -q 'friction_blockers:' "$FT_DIR/report-template.md" && pass "report-template has friction_blockers field" || fail "report-template missing friction_blockers"

   # Validator pass case
   if bash "$FT_DIR/validate-report.sh" "$FT_DIR/fixtures/report-pass.md" >/dev/null 2>&1; then
     pass "validate-report.sh exits 0 on report-pass.md"
   else
     fail "validate-report.sh did not exit 0 on report-pass.md"
   fi

   # Validator fail case — capture stderr, assert non-zero exit + blocker token
   set +e
   stderr=$(bash "$FT_DIR/validate-report.sh" "$FT_DIR/fixtures/report-fail.md" 2>&1 1>/dev/null)
   rc=$?
   set -e
   if [ "$rc" -ne 0 ]; then
     pass "validate-report.sh exits non-zero on report-fail.md"
   else
     fail "validate-report.sh did not fail on report-fail.md"
   fi
   echo "$stderr" | grep -q 'friction_blockers' && pass "validate-report.sh stderr names friction_blockers" || fail "validate-report.sh stderr missing friction_blockers"

   echo "SUMMARY: p07-friendly-tester-protocol.sh pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Required content tokens: `SC-8`, `FR-19`, `validate-report.sh`, `report-pass.md`, `report-fail.md`.

3. **Author `tools/verify/m033-p01-acceptance-shape-sc1.sh`** (≥25 lines, executable). Asserts `tests/m033-acceptance/p01-start-branch-routing.sh` exists, is executable, and contains the required content tokens (`SC-1`, `FR-1`, `FR-2`, the four branch names, `MIT-006`, `init already complete`). Optionally executes the script and propagates its exit code (the wrapper invocation gates SC-1's actual mechanical assertion). Emits PASS/SUMMARY.

4. **Author `tools/verify/m033-p01-acceptance-shape-sc8.sh`** (≥25 lines, executable). Asserts `tests/m033-acceptance/p07-friendly-tester-protocol.sh` exists, is executable, and contains the required content tokens (`SC-8`, `FR-19`, `validate-report.sh`, `report-pass.md`, `report-fail.md`). Optionally executes the script and propagates its exit code. Emits PASS/SUMMARY.

5. **Author `tools/verify/m033-p01-phase-suite.sh`** (≥60 lines, executable). The aggregator. Chains the 14 P01 verifiers in this exact order:

   1. `m033-p01-pbj-fixture-shape.sh`
   2. `m033-p01-pbj-fixture-readme-oracle.sh`
   3. `m033-p01-branch-detection-ssot-parity.sh`
   4. `m033-p01-start-md-shape.sh`
   5. `m033-p01-start-sh-flags-and-init-invocation.sh`
   6. `m033-p01-branch-detection-rules.sh`
   7. `m033-p01-subflow-stubs-shape.sh`
   8. `m033-p01-disambiguation-question-shape.sh`
   9. `m033-p01-friendly-tester-protocol-shape.sh`
   10. `m033-p01-report-template-shape.sh`
   11. `m033-p01-validate-report-sh-contract.sh`
   12. `m033-p01-validate-report-fixtures-shape.sh`
   13. `m033-p01-acceptance-shape-sc1.sh`
   14. `m033-p01-acceptance-shape-sc8.sh`

   The aggregator runs each verifier sequentially, increments pass/fail counters, and emits the final line `SUMMARY: m033-p01-phase-suite.sh pass=N fail=M`. Exits 0 iff fail=0.

   ```bash
   #!/usr/bin/env bash
   set -u -o pipefail

   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   VERIFIER_DIR="$PROJECT_ROOT/tools/verify"

   pass=0; fail=0

   verifiers=(
     m033-p01-pbj-fixture-shape.sh
     m033-p01-pbj-fixture-readme-oracle.sh
     m033-p01-branch-detection-ssot-parity.sh
     m033-p01-start-md-shape.sh
     m033-p01-start-sh-flags-and-init-invocation.sh
     m033-p01-branch-detection-rules.sh
     m033-p01-subflow-stubs-shape.sh
     m033-p01-disambiguation-question-shape.sh
     m033-p01-friendly-tester-protocol-shape.sh
     m033-p01-report-template-shape.sh
     m033-p01-validate-report-sh-contract.sh
     m033-p01-validate-report-fixtures-shape.sh
     m033-p01-acceptance-shape-sc1.sh
     m033-p01-acceptance-shape-sc8.sh
   )

   for v in "${verifiers[@]}"; do
     if bash "$VERIFIER_DIR/$v" >/dev/null 2>&1; then
       pass=$((pass+1))
       echo "PASS: $v"
     else
       fail=$((fail+1))
       echo "FAIL: $v"
     fi
   done

   echo "SUMMARY: m033-p01-phase-suite.sh pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

6. **Author `tools/verify/m033-p01-scope-guard.sh`** (≥35 lines, executable). Asserts P01 did not author files belonging to P02–P05:

   ```bash
   #!/usr/bin/env bash
   set -u -o pipefail

   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0

   forbidden=(
     scripts/lifecycle/grilling-shell.sh
     scripts/lifecycle/constitution-author.sh
     scripts/lifecycle/ingest-codebase.sh
     scripts/lifecycle/materials-intake.sh
     scripts/lifecycle/ideation.sh
     scripts/lifecycle/customblock-draft.sh
     scripts/verify/constitution-shape-lint.sh
     templates/constitution-starters/web-saas.md
     templates/constitution-starters/cli-tool.md
     templates/constitution-starters/library.md
     references/constitution-starter-format.md
     references/customblock-format.md
   )

   for f in "${forbidden[@]}"; do
     if [ -e "$PROJECT_ROOT/$f" ]; then
       fail=$((fail+1))
       echo "FAIL: P01 scope-guard violated — $f exists (belongs to P02-P05)"
     else
       pass=$((pass+1))
       echo "PASS: $f not present (P02-P05 deliverable)"
     fi
   done

   # No wiki/ writes from P01
   if [ -d "$PROJECT_ROOT/wiki" ]; then
     fail=$((fail+1))
     echo "FAIL: wiki/ directory exists — P01 must not write under wiki/ (P02 deliverable)"
   else
     pass=$((pass+1))
     echo "PASS: wiki/ not touched (SC-13)"
   fi

   echo "SUMMARY: m033-p01-scope-guard.sh pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Note: this scope-guard is a "should not exist on disk" check. If a future P02 author lands `grilling-shell.sh` and re-runs P01's phase-suite, the scope-guard correctly fails — that is by design. The scope-guard is meant for the P01 close audit; once P02 lands, this check is excluded from the M033-wide validate-milestone aggregator (handled by `validate-milestone.sh`'s phase-aware skipping).

   Required content tokens (per artifacts list): `scripts/lifecycle/grilling-shell.sh`, `scripts/lifecycle/constitution-author.sh`, `templates/constitution-starters`, `wiki/`, `tests/paired-m032-m033`, `SC-13`. Add `tests/paired-m032-m033` as a forbidden-path entry as well.

## Must-Haves

This task addresses these P01 phase truths:
- `tests/m033-acceptance/p01-start-branch-routing.sh` exists, is executable, exits 0 (SC-1).
- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` exists, is executable, exits 0 (SC-8).
- `tools/verify/m033-p01-phase-suite.sh` exists, chains all 14 P01 verifiers, emits the SUMMARY line, exits 0 iff every sub-gate passes.
- The SC-13 / scope-guard invariant holds for the P01 diff.

This task creates these P01 phase artifacts:
- Acceptance scripts: `tests/m033-acceptance/p01-start-branch-routing.sh` (SC-1), `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (SC-8).
- Acceptance shape verifiers: `tools/verify/m033-p01-acceptance-shape-sc1.sh`, `tools/verify/m033-p01-acceptance-shape-sc8.sh`.
- Phase suite & scope guard: `tools/verify/m033-p01-phase-suite.sh` (14-verifier aggregator), `tools/verify/m033-p01-scope-guard.sh` (P02–P05 file-scope check).

## Verification

```bash
bash tools/verify/m033-p01-acceptance-shape-sc1.sh
```

```bash
bash tools/verify/m033-p01-acceptance-shape-sc8.sh
```

```bash
bash tools/verify/m033-p01-scope-guard.sh
```

```bash
bash tools/verify/m033-p01-phase-suite.sh
```

```bash
bash tests/m033-acceptance/p01-start-branch-routing.sh
```

```bash
bash tests/m033-acceptance/p07-friendly-tester-protocol.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m033-pbj-materials-fixture/` (T01) — used as a reference shape; SC-1 stages its own minimal fixtures inline rather than copying T01's full corpus, but the T01 fixture is the materials-intake fixture for downstream P04 consumption.
- `references/branch-detection.md` (T02) — the SSOT; SC-1's pattern assertions implicitly verify start.sh's patterns matched the SSOT (already cross-checked by `m033-p01-branch-detection-ssot-parity.sh`).
- `commands/start.md` + `scripts/lifecycle/start.sh` (T03) — SC-1 invokes start.sh against six staged fixtures; T03's flag set + branch detection + sub-flow stubs + disambiguation behavior are the SC-1 surface.
  - Key API: `start.sh --project-dir <path> [--yes] [--branch <name>] [--stack <name>] [--dry-run]`. Stdout shape: `branch: <name>` line + `would-execute: <stub-name> --project-dir <path>` line + (for `migrating`) `--from <kind>`. Re-invocation against an init-completed dir emits `init already complete`. Disambiguation question contains `disambiguation:` + `recommended:` substrings; MIT-006 case adds `MIT-006`.
- `tests/m033-acceptance/friendly-tester-pass/{protocol.md,report-template.md,validate-report.sh,fixtures/report-pass.md,fixtures/report-fail.md}` (T04) — SC-8 reads/executes these. Validator API: `validate-report.sh <report.md>`; exit 0 iff `friction_blockers: 0` AND `eligible_testers >= 1`.

### From Disk (Pre-existing)

- `tools/verify/` — T05 adds four new verifiers (sc1, sc8, phase-suite, scope-guard) here.
- `tests/m033-acceptance/` — T05 adds two new acceptance scripts here.
- `git` on PATH — used by SC-1's fixture-3 and fixture-6 to seed `.git/` with one commit.

## Constraints

- Bash 3.2 compatibility (MEM001).
- The phase-suite aggregator's verifier list MUST be authored as an indexed bash array, NOT as `declare -A`. The list order is the dependency order — fixture verifiers first (no dependencies), then SSOT parity, then start.sh shape, then start.sh behavior, then friendly-tester shape, then acceptance wrappers.
- The phase-suite emits `SUMMARY: m033-p01-phase-suite.sh pass=N fail=M` as its single SUMMARY line. The validate-milestone.sh aggregator parses this format.
- The scope-guard's forbidden-path list is the authoritative P02–P05 boundary. If a future phase plan adds a deliverable, this list MUST be extended; otherwise scope-guard would silently allow drift.
- SC-1's six-fixture staging happens under `mktemp -d`; `trap cleanup EXIT` MUST clean up dangling staging dirs. Ungated dangling dirs in `/tmp/` are a CI-cleanliness regression.
- Verifier scripts use single-script-file shape per AD-19.
- The phase-suite script invokes 14 sub-verifiers via a `for` loop INSIDE the script body — this is allowed (the AD-19 prohibition is on inline `for` blocks at the COMMAND-LINE shape, e.g. inside a Truth Check). Multi-line `for` loops in script files are standard bash and do NOT trigger the harness shape-guard.

## Expected Output

After T05 completes:
- `tests/m033-acceptance/p01-start-branch-routing.sh` and `tests/m033-acceptance/p07-friendly-tester-protocol.sh` exist, executable, exit 0.
- `tools/verify/m033-p01-{acceptance-shape-sc1,acceptance-shape-sc8,phase-suite,scope-guard}.sh` exist, executable.
- Running `bash tools/verify/m033-p01-phase-suite.sh` emits 14 PASS lines + the SUMMARY line + exits 0.
- Running `bash tools/verify/m033-p01-scope-guard.sh` emits PASS lines for each forbidden path's nonexistence + exits 0.
- A summary file at [`.orchestrator/milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md`](../../../../../milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-SUMMARY.md) documents the 14-verifier chain and the SC-1 / SC-8 mechanical assertions.

## Notes

Expected output for `m033-p01-phase-suite.sh`: 14 `PASS:` lines (one per verifier) followed by `SUMMARY: m033-p01-phase-suite.sh pass=14 fail=0` + exit 0. If any sub-verifier fails, that line is `FAIL:` and the SUMMARY pass count drops accordingly.

Expected output for SC-1 (`p01-start-branch-routing.sh`): roughly 13 PASS lines (one per fixture-shape assertion plus idempotency assertion) + `SUMMARY: p01-start-branch-routing.sh pass=13 fail=0`.

Expected output for SC-8 (`p07-friendly-tester-protocol.sh`): roughly 9 PASS lines + `SUMMARY: p07-friendly-tester-protocol.sh pass=9 fail=0`.
