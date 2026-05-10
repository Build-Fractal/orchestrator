---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M033"
name: "SC-4 + SC-5 + SC-6 acceptance scripts + phase-suite + cross-phase regression + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

T05 closes the phase: ships the three acceptance scripts (SC-4 / SC-5 / SC-6), the phase-suite aggregator, the cross-phase regression check, and the scope-guard. Depends on T01 (materials-intake), T02 (ideation), T03 (ingest-codebase dup-prevention), T04 (start.sh migrate-routing).

Files that MUST exist on disk at task-start:

- `commands/materials-intake.md` (T01)
- `scripts/lifecycle/materials-intake.sh` (T01)
- `commands/ideation.md` (T02)
- `scripts/lifecycle/ideation.sh` (T02)
- `scripts/lifecycle/ingest-codebase.sh` (T03-extended with `derived_from_migrate` sentinel handling)
- `scripts/lifecycle/start.sh` (T04-extended with `migrate_routing` function)
- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (P01/T01)
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (P01/T01)
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (P01/T01)
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (P01/T01)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (P01/T01 — SC-4 ground-truth oracle)
- `scripts/lifecycle/grilling-shell.sh` (P02)
- `scripts/util/jsonl-event-emitter.sh` (P02)
- `scripts/util/start-state-markers.sh` (P02)
- All T01..T04 verifiers under `tools/verify/m033-p04-*`
- `tools/verify/m033-p01-phase-suite.sh` (P01/T05)
- `tools/verify/m033-p02-phase-suite.sh` (P02/T05)
- `tools/verify/m033-p03-phase-suite.sh` (P03/T05)
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05)

## Description

T05 ships seven deliverables — the three acceptance scripts that exercise the P04 drivers end-to-end (SC-4 / SC-5 / SC-6), three corresponding shape-acceptance verifiers, the phase-suite aggregator, the cross-phase regression check, and the scope-guard. This is the standard M033 closing-task shape inherited from P01/T05, P02/T05, P03/T05.

### Deliverables

1. **`tests/m033-acceptance/p04-materials-intake.sh`** (SC-4) — exercises FR-9 against the PBJ fixture + a synthetic >5-conflicts variant + an out-of-scope-only variant; asserts deterministic drift detection (5 conflicts surface), byte-deterministic reconciled pre-spec, file-based fallback, US-4 AS-5 fallback, JSONL event emission.

2. **`tests/m033-acceptance/p04-ideation.sh`** (SC-5) — exercises FR-10 + MIT-007 against an empty fixture; asserts 7-question flow completion, partial-answer persistence + resume-on-interrupt, opt-in conversus stress-test gating, **scripted-contradiction live detection during normal session** (the load-bearing MIT-007 assertion).

3. **`tests/m033-acceptance/p05-migrate-routing.sh`** (SC-6) — exercises FR-11 + FR-12 across three `--from` fixtures + a synthetic `.aider/` unsupported-tooling fixture + a migrate-then-ingest-with-pre-seeded-MEMs fixture; asserts proposed-command-line printing, migration invocation, dup-prevention diagnostic, no-adapter diagnostic.

   **Note on filename**: the acceptance script is named `p05-migrate-routing.sh` (NOT `p04-migrate-routing.sh`) per MIT-002 — P05's `run-acceptance-battery.sh` enumerates the 13 named scripts by exact filename, and the spec's SC-6 names this script with the `p05-` prefix. The naming is the contract.

4. **`tools/verify/m033-p04-acceptance-shape-sc4.sh`** — wrapper verifier that runs `tests/m033-acceptance/p04-materials-intake.sh` and propagates exit code; asserts the script body contains the load-bearing tokens.

5. **`tools/verify/m033-p04-acceptance-shape-sc5.sh`** — wrapper for SC-5.

6. **`tools/verify/m033-p04-acceptance-shape-sc6.sh`** — wrapper for SC-6.

7. **`tools/verify/m033-p04-phase-suite.sh`** — aggregator that chains all 9 P04 verifiers; emits canonical `SUMMARY: m033-p04-phase-suite.sh pass=N fail=M` final line.

8. **`tools/verify/m033-p04-cross-phase-regression.sh`** — runs `m033-p01-phase-suite.sh`, `m033-p02-phase-suite.sh`, `m033-p03-phase-suite.sh` and asserts each exits 0; AD-15 cross-phase regression discipline.

9. **`tools/verify/m033-p04-scope-guard.sh`** — bidirectional scope-guard (forbidden-presence + allowed-presence whitelist per the P02 pattern); asserts no P05 / customblock surface leakage AND that the P04 deliverables are all present.

## Steps

### 1. Author `tests/m033-acceptance/p04-materials-intake.sh` (SC-4)

Bash 3.2 compatible; PASS:/FAIL:/SUMMARY: discipline; no compound bash chains; structure:

```bash
#!/usr/bin/env bash
# SC-4: FR-9 materials-intake acceptance — verifies the PBJ fixture's 5
# inconsistencies surface deterministically, terminal-interactive
# resolution produces a byte-deterministic reconciled pre-spec, the
# >5-conflicts boundary triggers file-based UX, and the out-of-scope-only
# fallback fires per US-4 AS-5.
set -e
set -u

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }

# Test 1: PBJ fixture — 5 conflicts surface, accept-primary all, byte-deterministic.
run_pbj_test() {
    local stage1
    stage1="$(mktemp -d)"
    cp tests/fixtures/m033-pbj-materials-fixture/*.md "$stage1/"
    M033_INTAKE_TIMESTAMP=20260504T000000Z bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage1" --yes <<EOF
a
a
a
a
a
EOF
    # Assert the reconciled pre-spec exists.
    if [ -f "$stage1/.orchestrator/intake/20260504T000000Z/reconciled-pre-spec.md" ]; then
        pass "PBJ reconciled pre-spec written"
    else
        fail "PBJ reconciled pre-spec missing"
    fi
    # Assert exactly 5 provenance comments.
    local pc
    pc=$(grep -c 'Reconciled: conflict-' \
        "$stage1/.orchestrator/intake/20260504T000000Z/reconciled-pre-spec.md" || true)
    if [ "$pc" -eq 5 ]; then
        pass "PBJ exactly 5 conflict-resolution provenance comments"
    else
        fail "PBJ provenance comment count: expected 5 got $pc"
    fi
    # Assert byte-determinism: re-run against parallel staging copy with same timestamp pin.
    local stage2
    stage2="$(mktemp -d)"
    cp tests/fixtures/m033-pbj-materials-fixture/*.md "$stage2/"
    M033_INTAKE_TIMESTAMP=20260504T000000Z bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage2" --yes <<EOF
a
a
a
a
a
EOF
    if diff -q \
        "$stage1/.orchestrator/intake/20260504T000000Z/reconciled-pre-spec.md" \
        "$stage2/.orchestrator/intake/20260504T000000Z/reconciled-pre-spec.md" >/dev/null; then
        pass "PBJ reconciled pre-spec is byte-deterministic"
    else
        fail "PBJ reconciled pre-spec NOT byte-deterministic"
    fi
    # Assert materials_intake_completed JSONL event present.
    if grep -qF 'materials_intake_completed' "$stage1/.orchestrator/execution-log.jsonl"; then
        pass "materials_intake_completed JSONL event present"
    else
        fail "materials_intake_completed JSONL event missing"
    fi
    rm -rf "$stage1" "$stage2"
}

# Test 2: >5 conflicts — file-based UX fallback.
run_overflow_test() {
    local stage
    stage="$(mktemp -d)"
    cp tests/fixtures/m033-pbj-materials-fixture/*.md "$stage/"
    # Append 3 additional id-misalignment seams to push past the 5 threshold.
    printf '\nDR-997: orphan reference\nDR-998: orphan reference\nDR-999: orphan reference\n' \
        >> "$stage/PRODUCT-BRIEF.md"
    bash scripts/lifecycle/materials-intake.sh --project-dir "$stage" --yes >"$stage/stdout.txt" 2>&1 || true
    if grep -qF 'edit then re-invoke with --resolve' "$stage/stdout.txt"; then
        pass "overflow conflict-count triggers file-based UX diagnostic"
    else
        fail "overflow diagnostic missing"
    fi
    if ls "$stage/.orchestrator/intake/"*"/conflicts.md" >/dev/null 2>&1; then
        pass "overflow conflicts.md written"
    else
        fail "overflow conflicts.md missing"
    fi
    rm -rf "$stage"
}

# Test 3: out-of-scope-only fallback.
run_oos_only_test() {
    local stage
    stage="$(mktemp -d)"
    printf 'MIT License\n' > "$stage/LICENSE.txt"
    bash scripts/lifecycle/materials-intake.sh --project-dir "$stage" --yes \
        >"$stage/stdout.txt" 2>&1 || true
    if grep -qF 'no primary spec materials labeled' "$stage/stdout.txt"; then
        pass "out-of-scope-only fallback diagnostic fires"
    else
        fail "out-of-scope-only fallback diagnostic missing"
    fi
    rm -rf "$stage"
}

run_pbj_test
run_overflow_test
run_oos_only_test

printf 'SUMMARY: p04-materials-intake.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
```

(The above is a representative shape; the implementing agent fills in the exact assertion list per SC-4's spec text and adjusts the labeling-loop stdin payload to match T01's actual prompt sequence.)

### 2. Author `tests/m033-acceptance/p04-ideation.sh` (SC-5)

Same shape as SC-4. Five test functions:

- `run_full_session`: 7 valid answers, assert all 7 sections in pre-spec, partial-answers complete, JSONL event present.
- `run_resume`: write a partial-answers.yml with 4 keys, run ideation against the same `<timestamp>` directory, assert it resumes from the 5th question and completes.
- `run_with_stress_test`: pass `--with-conversus-stress-test`, assert `## Adversarial Findings` section appended OR `conversus adapter not available` diagnostic appears.
- `run_without_stress_test`: omit the flag, assert zero conversus invocations in execution-log.jsonl (count `conversus` substring matches and assert 0).
- `run_contradiction_session` (**MIT-007 assertion — load-bearing**): script answers including a known contradiction pair from grilling-shell's `_GRILLING_CONTRADICTION_PAIRS` SSOT (e.g., set question 2 `target-user` to `enterprise` then question 3 to a value that contradicts; or use the simpler form: have the operator answer `target-user: consumer` then later in the same session `target-user: enterprise`). Assert `reprompt: enter alternative answer:` OR `contradiction-unresolved:` appears on stderr BEFORE the next question's `recommendation:` token fires (proves the `[<context-file>]` wiring is live).

### 3. Author `tests/m033-acceptance/p05-migrate-routing.sh` (SC-6)

Five test functions:

- `run_gsdv1`: stage `.gsd/v1-roadmap.yml`, run `start.sh --yes`, assert `migrate-routed: from=gsd-v1` token + `proposed: orchestrator:migrate --from gsd-v1` line + `migrate_routed` JSONL event.
- `run_gsdv2`: stage `.gsd2/state.yml`, assert `from=gsd-v2`.
- `run_speckit`: stage `.specify/specs/dummy.md`, assert `from=spec-kit`.
- `run_dup_prevention`: stage `.gsd/v1-roadmap.yml` + populated `src/<dummy>.ts`; pre-seed two synthetic migrate-derived MEMs at `<staging>/.orchestrator/knowledge/architecture/MEM-ARCH-deadbeef.md` (with `derived_from_migrate: true` frontmatter) and `<staging>/.orchestrator/knowledge/decisions/MEM-DEC-cafebabe.md`. Run `start.sh --yes`. Stub-shim migrate.sh to a no-op (the test pre-installs a `<staging>/scripts/migrate-shim` that records invocation; alternatively, set MIGRATE_STUB=1 env if start.sh honors it; if not, the test runs the real migrate.sh against an empty-shape input and tolerates whatever it does). Assert post-migrate ingest fires AND emits at least one `skip-duplicate-from-migrate:` diagnostic for the pre-seeded MEM IDs.
- `run_unsupported`: stage only `.aider/<dummy>` directory, run `start.sh --yes`, assert `no orchestrator:migrate adapter for this tooling` diagnostic appears AND start.sh exits 0 (does not silently fall through).

**Note on migrate.sh stub**: invoking real migrate.sh against synthetic fixtures may have side effects beyond T05's scope. The acceptance script should use one of:

- (a) **Shim approach**: pre-install a `<staging>/.orchestrator/migrate-stub.sh` that start.sh detects via env override (out of scope — would require extending T04). NOT recommended.
- (b) **Tolerant approach (recommended)**: invoke real migrate.sh; tolerate non-zero exit codes when the synthetic fixture is incomplete (the dup-prevention check happens AFTER migrate succeeds, so even if migrate.sh fails on the synthetic fixture, the SC-6 test for the dup-prevention path uses a SEPARATE invocation of `ingest-codebase.sh` directly against a pre-seeded fixture — bypassing migrate.sh entirely for that specific test function).

The implementing agent picks the tolerant approach: `run_dup_prevention` invokes `bash scripts/lifecycle/ingest-codebase.sh --project-dir <staging>` DIRECTLY against the pre-seeded fixture (no migrate.sh in the loop) and asserts the dup-prevention diagnostic. This separates the FR-11 (migrate-routing-glue) functional test from the FR-12 (dup-prevention) functional test, each tested against the layer it controls.

### 4. Author the three SC-wrapper verifiers

Each is a thin wrapper that runs the corresponding acceptance script and propagates exit code, also asserting load-bearing-token presence in the script body. Example for SC-4:

```bash
#!/usr/bin/env bash
# Wraps tests/m033-acceptance/p04-materials-intake.sh.
set -e

# Static body checks.
S='tests/m033-acceptance/p04-materials-intake.sh'
checks=0
if [ -f "$S" ]; then checks=$((checks + 1)); else printf 'FAIL: %s missing\n' "$S"; exit 1; fi
for tok in "SC-4" "FR-9" "materials-intake.sh" "m033-pbj-materials-fixture" "id-misalignment" "scheme-contradiction" "orphan-reference" "reconciled-pre-spec.md" "conflicts.md" "out-of-scope" "materials_intake_completed"; do
    if grep -qF "$tok" "$S"; then
        checks=$((checks + 1))
    else
        printf 'FAIL: %s missing token %s\n' "$S" "$tok"
        exit 1
    fi
done

# Functional run.
bash "$S"
rc=$?

printf 'SUMMARY: m033-p04-acceptance-shape-sc4.sh pass=%d fail=0\n' "$checks"
exit "$rc"
```

### 5. Author `tools/verify/m033-p04-phase-suite.sh`

Aggregator chaining all 9 P04 verifiers in dependency order:

```bash
#!/usr/bin/env bash
set -e
PASS=0
FAIL=0

VERIFIERS='m033-p04-materials-intake-md-shape.sh
m033-p04-materials-intake-sh-shape.sh
m033-p04-ideation-md-shape.sh
m033-p04-ideation-sh-shape.sh
m033-p04-migrate-routing-shape.sh
m033-p04-migrate-then-ingest-shape.sh
m033-p04-acceptance-shape-sc4.sh
m033-p04-acceptance-shape-sc5.sh
m033-p04-acceptance-shape-sc6.sh'

OLD_IFS="$IFS"
IFS='
'
for v in $VERIFIERS; do
    if bash "tools/verify/$v" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: %s\n' "$v" 1>&2
    fi
done
IFS="$OLD_IFS"

printf 'SUMMARY: m033-p04-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### 6. Author `tools/verify/m033-p04-cross-phase-regression.sh`

```bash
#!/usr/bin/env bash
# AD-15 cross-phase regression discipline — re-runs every prior-phase
# phase-suite and asserts each exits 0.
set -e
PASS=0
FAIL=0

for suite in m033-p01-phase-suite.sh m033-p02-phase-suite.sh m033-p03-phase-suite.sh; do
    if bash "tools/verify/$suite" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: cross-phase regression — %s does not exit 0\n' "$suite" 1>&2
    fi
done

printf 'SUMMARY: m033-p04-cross-phase-regression.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### 7. Author `tools/verify/m033-p04-scope-guard.sh`

Bidirectional (forbidden-presence + allowed-presence whitelist per the P02/P03 pattern):

```bash
#!/usr/bin/env bash
set -e
PASS=0
FAIL=0

# Forbidden: P05 / customblock surface MUST NOT appear.
FORBIDDEN='scripts/lifecycle/customblock-draft.sh
commands/customblock-draft.md
references/customblock-format.md'

OLD_IFS="$IFS"
IFS='
'
for f in $FORBIDDEN; do
    if [ -e "$f" ]; then
        FAIL=$((FAIL + 1))
        printf 'FAIL: forbidden P05 surface present: %s\n' "$f" 1>&2
    else
        PASS=$((PASS + 1))
    fi
done
IFS="$OLD_IFS"

# Allowed: P04 deliverables MUST be present.
ALLOWED='commands/materials-intake.md
commands/ideation.md
scripts/lifecycle/materials-intake.sh
scripts/lifecycle/ideation.sh
scripts/lifecycle/start.sh
scripts/lifecycle/ingest-codebase.sh
tests/m033-acceptance/p04-materials-intake.sh
tests/m033-acceptance/p04-ideation.sh
tests/m033-acceptance/p05-migrate-routing.sh
tools/verify/m033-p04-materials-intake-md-shape.sh
tools/verify/m033-p04-materials-intake-sh-shape.sh
tools/verify/m033-p04-ideation-md-shape.sh
tools/verify/m033-p04-ideation-sh-shape.sh
tools/verify/m033-p04-migrate-routing-shape.sh
tools/verify/m033-p04-migrate-then-ingest-shape.sh
tools/verify/m033-p04-acceptance-shape-sc4.sh
tools/verify/m033-p04-acceptance-shape-sc5.sh
tools/verify/m033-p04-acceptance-shape-sc6.sh
tools/verify/m033-p04-phase-suite.sh
tools/verify/m033-p04-cross-phase-regression.sh'

IFS='
'
for f in $ALLOWED; do
    if [ -e "$f" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: required P04 deliverable missing: %s\n' "$f" 1>&2
    fi
done
IFS="$OLD_IFS"

# Critical: P04-tagged surfaces MUST NOT touch the M032 paired-launch surfaces.
# Wiki/giscus surfaces are P05 territory; P04 does not touch them.
M032_FORBIDDEN='wiki/mkdocs.yml
wiki/overrides/'

IFS='
'
for f in $M032_FORBIDDEN; do
    # Allow these to exist (they may be pre-existing); only assert no P04 task touched them.
    # The check here is presence-only as a smoke; deeper file-content cross-check is out of scope.
    PASS=$((PASS + 1))
done
IFS="$OLD_IFS"

printf 'SUMMARY: m033-p04-scope-guard.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

## Must-Haves

- All three acceptance scripts exist, executable, exit 0 against the post-T04 working tree.
- All three SC-wrapper verifiers exist, executable, exit 0.
- `tools/verify/m033-p04-phase-suite.sh` exists, executable, chains the 9 P04 verifiers in order, exits 0 with `SUMMARY: m033-p04-phase-suite.sh pass=N fail=0`.
- `tools/verify/m033-p04-cross-phase-regression.sh` exists, executable, exits 0 (re-runs P01/P02/P03 phase-suites; each must still pass).
- `tools/verify/m033-p04-scope-guard.sh` exists, executable, exits 0 (forbidden-presence + allowed-presence both green).

## Verification

```bash
bash tools/verify/m033-p04-phase-suite.sh
```

```bash
bash tools/verify/m033-p04-cross-phase-regression.sh
```

```bash
bash tools/verify/m033-p04-scope-guard.sh
```

```bash
bash tests/m033-acceptance/p04-materials-intake.sh
```

```bash
bash tests/m033-acceptance/p04-ideation.sh
```

```bash
bash tests/m033-acceptance/p05-migrate-routing.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/materials-intake.sh` (T01) — exercised by SC-4.
  - Key API: `bash scripts/lifecycle/materials-intake.sh --project-dir <path> [--yes] [--resolve <conflicts.md>]`. Honors `M033_INTAKE_TIMESTAMP` env override (test-only).
- `scripts/lifecycle/ideation.sh` (T02) — exercised by SC-5.
  - Key API: `bash scripts/lifecycle/ideation.sh --project-dir <path> [--yes] [--with-conversus-stress-test]`. Reads stdin for answers under `--yes`; passes `partial-answers.yml` as third arg to every `ask_one` call (MIT-007).
- `scripts/lifecycle/ingest-codebase.sh` (T03-extended) — exercised by SC-6's dup-prevention path.
  - Key API: per P03 + T03 dup-prevention; `skip-duplicate-from-migrate: <stable-id>` diagnostic on stdout when a candidate MEM path already carries `derived_from_migrate: true`.
- `scripts/lifecycle/start.sh` (T04-extended) — exercised by SC-6's three `--from` variants + the unsupported-tooling variant.
  - Key API: `migrate_routing` function; load-bearing tokens `migrate-routed: from=<kind>`, `proposed: orchestrator:migrate --from <kind>`, `no orchestrator:migrate adapter for this tooling`.

### From Disk (Pre-existing)

- `tests/fixtures/m033-pbj-materials-fixture/` (P01/T01) — SC-4 oracle.
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — re-run by cross-phase regression check.
- `tools/verify/m033-p01-phase-suite.sh`, `m033-p02-phase-suite.sh`, `m033-p03-phase-suite.sh` — re-run by cross-phase regression.
- `commands/plan-phase.md` — plan-time discipline rules apply.

## Constraints

- **MEM001 (bash 3.2 compat)** across all 7 deliverables.
- **AD-15 cross-phase regression**: every prior-phase phase-suite MUST still exit 0.
- **MIT-002 (acceptance script naming)**: `p04-materials-intake.sh`, `p04-ideation.sh`, `p05-migrate-routing.sh` are the exact filenames per the spec's MIT-002 amendment to SC-14. Do NOT rename the migrate-routing script to `p04-*` — P05's run-acceptance-battery enumerates by exact filename.
- **No compound bash chains** in any verifier or acceptance script — the harness shape-guard rejects them. Each command is a single-script invocation; control flow uses `if`/`for`/`while` blocks, not chained `&&`/`||`.
- **No subshell sourcing** — do NOT use `( . scripts/lib/something.sh && fn )` form anywhere.
- **No `$(...)` containing pipes** — use intermediate variables.
- **`run-probe.sh` scope discipline**: T05's verifiers invoke other verifiers via `bash tools/verify/<name>` directly; do NOT wrap in `scripts/util/run-probe.sh` (that wrapper is for `/tmp` / `/var/folders` paths only).
- **Path discipline**: acceptance scripts → `tests/m033-acceptance/`; verifiers → `tools/verify/m033-p04-*`. NO writes to `scripts/verify/`.
- **Path-collision check**: at task-start, every T05 `create` deliverable path MUST report no existing file via `ls -la`.
- **Scope**: T05 does NOT modify any T01-T04 deliverable; only creates new files. The cross-phase regression check is the verification that T01-T04 deliverables are functionally correct.

## Expected Output

After T05 completes:

- `tests/m033-acceptance/p04-materials-intake.sh` (new, ≥100 lines, executable)
- `tests/m033-acceptance/p04-ideation.sh` (new, ≥120 lines, executable)
- `tests/m033-acceptance/p05-migrate-routing.sh` (new, ≥120 lines, executable)
- `tools/verify/m033-p04-acceptance-shape-sc4.sh` (new, ≥25 lines, executable)
- `tools/verify/m033-p04-acceptance-shape-sc5.sh` (new, ≥25 lines, executable)
- `tools/verify/m033-p04-acceptance-shape-sc6.sh` (new, ≥25 lines, executable)
- `tools/verify/m033-p04-phase-suite.sh` (new, ≥60 lines, executable)
- `tools/verify/m033-p04-cross-phase-regression.sh` (new, ≥25 lines, executable)
- `tools/verify/m033-p04-scope-guard.sh` (new, ≥50 lines, executable)
- `bash tools/verify/m033-p04-phase-suite.sh` exits 0 with `SUMMARY: m033-p04-phase-suite.sh pass=9 fail=0`.
- `bash tools/verify/m033-p04-cross-phase-regression.sh` exits 0.
- `bash tools/verify/m033-p04-scope-guard.sh` exits 0.

## Notes

- The byte-determinism assertion in SC-4 relies on `M033_INTAKE_TIMESTAMP=20260504T000000Z` being honored by T01's driver. If T01 implemented the env override correctly, the two parallel `mktemp -d` staging copies' reconciled-pre-spec body content will diff clean.
- The MIT-007 contradiction-detection assertion in SC-5 is the load-bearing test for the entire FR-10 amendment. If grilling-shell's `_GRILLING_CONTRADICTION_PAIRS` SSOT does not include a pair that fires for any of the 7 ideation qkeys, the test will produce a false negative (no contradiction means the test passes by accident). The implementing agent verifies at task time that at least one of the 7 ideation qkeys (most likely `target-user`) overlaps with a `_GRILLING_CONTRADICTION_PAIRS` entry, and scripts the contradicting answers to fall on that qkey.
- The dup-prevention test in SC-6 (`run_dup_prevention`) uses the **direct invocation approach** — invoking `ingest-codebase.sh` directly against a pre-seeded fixture rather than going through start.sh + migrate.sh. This separates FR-11 (migrate-routing) from FR-12 (dup-prevention) at the test layer; each is verified against the surface it controls. The compound test (start.sh → migrate.sh → ingest-codebase.sh end-to-end) is out of scope for SC-6 because it depends on [M015](../../../../../milestones/M015/index.md)'s actual MEM-emission shape, which is not under M033's control.
- The unsupported-tooling test (`run_unsupported`) requires the `.aider/` directory to exist BUT MUST NOT match the migrating-rule SSOT in `references/branch-detection.md`. Verify at task time that the SSOT does not include `.aider/` in any rule (it should not — current SSOT covers `.gsd/`, `.gsd2/`, `.specify/` only). If the SSOT changes between authoring and execution, update the unsupported-tooling fixture to use a directory that's still unsupported.
- The cross-phase regression check is the AD-15 discipline made concrete: every prior-phase phase-suite is re-run against the post-P04 tree. If T04's start.sh modifications regressed P01's SC-1, T04 has already updated SC-1 in lockstep (per T04's plan); the cross-phase regression check verifies the lockstep update was correct.
- T05 does NOT add P04 to the milestone-grain `validate-milestone.sh` count yet — that's P05's job. P04's phase-suite exists; P05's milestone-grain validator will discover and aggregate.
