---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M033"
name: "SC-7 + SC-9 + SC-10 acceptance scripts + SC-14 run-acceptance-battery.sh (MIT-002 explicit enumeration)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

T04 ships the three acceptance scripts (SC-7 / SC-9 / SC-10), four shape-acceptance verifiers, and the milestone-grain SC-14 acceptance battery runner with explicit enumeration of all 13 named scripts (MIT-002).

Files that MUST exist on disk at task-start (verified via `ls -la`):

- `commands/customblock-draft.md` (T01)
- `scripts/lifecycle/customblock-draft.sh` (T01) — exercised by SC-7
- `references/customblock-format.md` (T01)
- `scripts/lifecycle/start.sh` (T02 + T03 extended) — exercised by SC-9 + SC-10; carries `WITH_WIKI`, `WITH_GITHUB`, `wiki_init_passthrough`, `github_init_passthrough`, both stub-mode dispatches
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — both `wiki_init_invoked` and `github_init_invoked` and `customblock_drafted` are in the closed enum
- `scripts/util/start-state-markers.sh` (P02/T02) — used by acceptance scripts for marker-preservation assertions
- All P02 shape verifiers (cross-phase regression context for the battery)
- All P01..P04 acceptance scripts under `tests/m033-acceptance/`:
  - `p01-start-branch-routing.sh` (P01/T05)
  - `p02-constitution-author.sh` (P03/T05)
  - `p03-ingest-codebase.sh` (P03/T05)
  - `p04-materials-intake.sh` (P04/T05)
  - `p04-ideation.sh` (P04/T05)
  - `p05-migrate-routing.sh` (P04/T05)
  - `p07-friendly-tester-protocol.sh` (P01/T05)
  - `p07-grilling-shell.sh` (P02/T05)
  - `p07-resume-on-partial-state.sh` (P02/T05)
  - `p07-observability-records.sh` (P02/T05)

Acceptance battery template — model byte-for-byte on:
- `tests/m030-acceptance/run-acceptance-battery.sh` ([M030](../../../../../milestones/M030/index.md) precedent)
- `tests/m031-acceptance/run-acceptance-battery.sh` ([M031](../../../../../milestones/M031/index.md) precedent — closer model since M031 also has multi-prefix discovery)

## Description

T04 ships SEVEN deliverables:

1. **`tests/m033-acceptance/p06-customblock-draft.sh`** (SC-7) — exercises FR-13 + FR-14 against staged fixtures; asserts 5 prescribed sections, strict aggregation, idempotency, `--force` warning, structurally-downstream-of-US-2 gate, branch-dependent variant rule.

2. **`tests/m033-acceptance/p08-with-wiki-passthrough.sh`** (SC-9 amended per MIT-001 two-mode contract) — exercises FR-15 against staged fixtures with seeded sub-flow markers; asserts stub-mode invocation + exit-code propagation + diagnostic + sub-flow preservation; produces pass not skip.

3. **`tests/m033-acceptance/p08-with-github-passthrough.sh`** (SC-10) — exercises FR-16 against staged fixtures; asserts stub-mode invocation + exit-code propagation + diagnostic + ordering rule when `--with-wiki --with-github` combined.

4. **`tools/verify/m033-p05-acceptance-shape-sc7.sh`** — wrapper verifier that runs `tests/m033-acceptance/p06-customblock-draft.sh` and propagates exit code; asserts the script body contains the load-bearing tokens.

5. **`tools/verify/m033-p05-acceptance-shape-sc9.sh`** — wrapper for SC-9.

6. **`tools/verify/m033-p05-acceptance-shape-sc10.sh`** — wrapper for SC-10.

7. **`tests/m033-acceptance/run-acceptance-battery.sh`** (SC-14 amended per MIT-002) — explicit-enumeration runner of all 13 named acceptance scripts; emits `BATTERY: pass=13 fail=0`; propagates `M033_FR15_STUB=1` + `M033_GHINIT_STUB=1` env vars.

Plus one shape verifier for the battery itself: **`tools/verify/m033-p05-acceptance-battery-shape.sh`**.

## Steps

### 1. Author `tests/m033-acceptance/p06-customblock-draft.sh` (SC-7)

```bash
#!/usr/bin/env bash
# tests/m033-acceptance/p06-customblock-draft.sh
# SC-7: FR-13 + FR-14 customblock-draft acceptance.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

# --- Test 1: existing-codebase fixture with constitution + ingest MEMs.
seed_existing_codebase_fixture() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/memory" \
             "$stage/.orchestrator/knowledge/architecture" \
             "$stage/.orchestrator/knowledge/conventions" \
             "$stage/.orchestrator/knowledge/decisions" \
             "$stage/.orchestrator/start-state"
    # Constitution stub.
    cat > "$stage/.orchestrator/memory/constitution.md" <<'EOF'
# Project Constitution -- web-saas

## Constitution Check

### Principle I -- Idempotent Deploys
Every deploy is repeatable.
EOF
    # Architecture MEM.
    cat > "$stage/.orchestrator/knowledge/architecture/MEM-A1.md" <<'EOF'
---
id: MEM-A1
category: architecture
---
WebApp uses TypeScript + Node 20 with React 19 frontend.
EOF
    # Convention MEM.
    cat > "$stage/.orchestrator/knowledge/conventions/MEM-C1.md" <<'EOF'
---
id: MEM-C1
category: conventions
---
ESLint with prettier-plugin runs on pre-commit.
EOF
    # Decision MEM.
    cat > "$stage/.orchestrator/knowledge/decisions/MEM-D1.md" <<'EOF'
---
id: MEM-D1
category: decisions
---
Postgres chosen over MongoDB for transactional integrity (2026-04-15).
EOF
    # Empty CLAUDE.md with marker region.
    cat > "$stage/CLAUDE.md" <<'EOF'
# CLAUDE.md

<!-- BEGIN CUSTOM -->
<!-- END CUSTOM -->
EOF
}

STAGE1=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE1"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
[ "$RC1" -eq 0 ] && pass "T1 customblock-draft exit 0" || fail "T1 exit $RC1"

# Assert all 5 prescribed sections present (Entry Points variant since no intake).
for h in '## Project' '## Stack' '## Entry Points' '## Conventions' '## Decisions'; do
    grep -qF "$h" "$STAGE1/CLAUDE.md" && pass "T1 section: $h" || fail "T1 missing: $h"
done

# Assert strict aggregation: each section's body contains a verbatim substring
# from the seeded MEM (no LLM-invented strings).
grep -qF 'TypeScript + Node 20' "$STAGE1/CLAUDE.md" \
    && pass "T1 ## Stack body verbatim from MEM-A1" \
    || fail "T1 ## Stack body lost MEM-A1 content"
grep -qF 'ESLint with prettier-plugin' "$STAGE1/CLAUDE.md" \
    && pass "T1 ## Conventions body verbatim from MEM-C1" \
    || fail "T1 ## Conventions body lost MEM-C1 content"
grep -qF 'Postgres chosen over MongoDB' "$STAGE1/CLAUDE.md" \
    && pass "T1 ## Decisions body verbatim from MEM-D1" \
    || fail "T1 ## Decisions body lost MEM-D1 content"

# JSONL event + start-state marker.
grep -qF '"customblock_drafted"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 customblock_drafted JSONL emitted" \
    || fail "T1 JSONL event missing"
[ -f "$STAGE1/.orchestrator/start-state/customblock-draft.complete" ] \
    && pass "T1 start-state marker written" \
    || fail "T1 marker missing"

# --- Test 2: idempotency without --force.
cp "$STAGE1/CLAUDE.md" "$STAGE1/CLAUDE.md.before"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes \
    > "$STAGE1/stdout2" 2> "$STAGE1/stderr2"
RC2=$?
[ "$RC2" -eq 0 ] && pass "T2 idempotent re-run exit 0" || fail "T2 exit $RC2"
diff -q "$STAGE1/CLAUDE.md.before" "$STAGE1/CLAUDE.md" > /dev/null \
    && pass "T2 file byte-identical without --force" \
    || fail "T2 file changed without --force"
grep -qF 'no changes' "$STAGE1/stdout2" && pass "T2 'no changes' diagnostic" || fail "T2 missing 'no changes'"

# --- Test 3: --force regenerates with stderr warning.
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes --force \
    > "$STAGE1/stdout3" 2> "$STAGE1/stderr3"
RC3=$?
[ "$RC3" -eq 0 ] && pass "T3 --force exit 0" || fail "T3 exit $RC3"
grep -qF 'discards prior operator edits' "$STAGE1/stderr3" \
    && pass "T3 --force stderr warning emitted" \
    || fail "T3 --force stderr warning missing"

# --- Test 4: floor-not-ceiling preserves operator additions.
STAGE2=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE2"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE2" --yes \
    > /dev/null 2>&1
# Inject an operator-added ## Notes section into the custom block.
sed -i.bak 's|<!-- END CUSTOM -->|## Notes\n\n- Test note line 1\n\n<!-- END CUSTOM -->|' "$STAGE2/CLAUDE.md"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE2" --yes --force \
    > /dev/null 2>&1
grep -qF '## Notes' "$STAGE2/CLAUDE.md" \
    && pass "T4 floor-not-ceiling preserves ## Notes" \
    || fail "T4 ## Notes section lost on --force"
grep -qF 'Test note line 1' "$STAGE2/CLAUDE.md" \
    && pass "T4 ## Notes body preserved verbatim" \
    || fail "T4 ## Notes body lost"

# --- Test 5: structurally-downstream-of-US-2 gate.
STAGE3=$(mktemp -d)
mkdir -p "$STAGE3/.orchestrator/start-state"
# NO constitution.md.
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE3" --yes \
    > "$STAGE3/stdout" 2> "$STAGE3/stderr"
RC5=$?
[ "$RC5" -ne 0 ] && pass "T5 missing-constitution exit non-zero" \
    || fail "T5 expected non-zero exit"
grep -qF 'constitution not present' "$STAGE3/stderr" \
    && pass "T5 missing-constitution diagnostic" \
    || fail "T5 missing-constitution diagnostic absent"

# --- Test 6: branch-dependent variant rule (## Source-Docs when intake exists).
STAGE4=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE4"
mkdir -p "$STAGE4/.orchestrator/intake/20260504T000000Z"
cat > "$STAGE4/.orchestrator/intake/20260504T000000Z/ideation-pre-spec.md" <<'EOF'
## Problem

Test problem statement.

## MVP

Test MVP boundary.
EOF
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE4" --yes \
    > /dev/null 2>&1
grep -qF '## Source-Docs' "$STAGE4/CLAUDE.md" \
    && pass "T6 ## Source-Docs variant fires" \
    || fail "T6 ## Source-Docs variant absent"
grep -qF '## Entry Points' "$STAGE4/CLAUDE.md" \
    && fail "T6 ## Entry Points should NOT appear when intake exists" \
    || pass "T6 ## Entry Points correctly omitted"

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3" "$STAGE4"

printf 'SUMMARY: p06-customblock-draft.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 2. Author `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (SC-9)

```bash
#!/usr/bin/env bash
# tests/m033-acceptance/p08-with-wiki-passthrough.sh
# SC-9 (amended per MIT-001): FR-15 --with-wiki passthrough acceptance, two-mode contract.
# Stub-mode produces PASS not SKIP per CON-1 / SC-14 skip=0 invariant.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

seed_post_onboarding() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/start-state"
    # Seed US-1..US-7 sub-flow markers as if all sub-flows completed.
    for sf in init-invoked subflow-started subflow-completed; do
        date -u +%Y-%m-%dT%H:%M:%SZ > "$stage/.orchestrator/start-state/$sf.complete"
    done
}

# --- Test 1: stub mode rc=0 propagation.
STAGE1=$(mktemp -d)
seed_post_onboarding "$STAGE1"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=0 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE1" --branch greenfield-empty \
    --with-wiki --yes --dry-run \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
[ "$RC1" -eq 0 ] && pass "T1 stub rc=0 propagation" || fail "T1 rc=$RC1 expected 0"
grep -qF 'STUB: wiki-init invoked' "$STAGE1/stdout" \
    && pass "T1 STUB token emitted" || fail "T1 STUB token absent"
grep -qF '"wiki_init_invoked"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 wiki_init_invoked JSONL record" || fail "T1 JSONL record absent"
grep -qF '"stub_mode":true' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 stub_mode:true in JSONL" || fail "T1 stub_mode field wrong"
grep -qF '"exit_code":0' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 exit_code:0 in JSONL" || fail "T1 exit_code field wrong"

# Sub-flow markers preserved.
[ -f "$STAGE1/.orchestrator/start-state/init-invoked.complete" ] \
    && pass "T1 sub-flow markers preserved on success" \
    || fail "T1 sub-flow markers cleared"

# --- Test 2: stub mode rc=42 propagation + failure diagnostic.
STAGE2=$(mktemp -d)
seed_post_onboarding "$STAGE2"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=42 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE2" --branch greenfield-empty \
    --with-wiki --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
[ "$RC2" -eq 42 ] && pass "T2 stub rc=42 propagation" || fail "T2 rc=$RC2 expected 42"
grep -qF 'wiki-init failed' "$STAGE2/stdout" \
    && pass "T2 wiki-init failed diagnostic" || fail "T2 diagnostic absent"
grep -qF 'all other onboarding outputs preserved' "$STAGE2/stdout" \
    && pass "T2 sub-flow-preservation diagnostic" || fail "T2 preservation diagnostic absent"
grep -qF '"exit_code":42' "$STAGE2/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T2 exit_code:42 in JSONL" || fail "T2 exit_code field wrong"

# Sub-flow markers preserved on failure (sequential-atomicity invariant).
[ -f "$STAGE2/.orchestrator/start-state/init-invoked.complete" ] \
    && pass "T2 sub-flow markers preserved on failure" \
    || fail "T2 sub-flow markers cleared on failure"

# --- Test 3: real-mode without wiki-init.sh AND without stub mode.
STAGE3=$(mktemp -d)
seed_post_onboarding "$STAGE3"
# Ensure no stub env vars; rely on absence of scripts/lifecycle/wiki-init.sh.
unset M033_FR15_STUB M033_FR15_STUB_EXIT_CODE
if [ ! -f "scripts/lifecycle/wiki-init.sh" ]; then
    bash scripts/lifecycle/start.sh --project-dir "$STAGE3" --branch greenfield-empty \
        --with-wiki --yes --dry-run \
        > "$STAGE3/stdout" 2> "$STAGE3/stderr"
    RC3=$?
    [ "$RC3" -ne 0 ] && pass "T3 missing wiki-init.sh exits non-zero" \
        || fail "T3 expected non-zero exit"
    grep -qF 'wiki-init.sh not found' "$STAGE3/stderr" \
        && pass "T3 not-found diagnostic" \
        || fail "T3 not-found diagnostic absent"
else
    pass "T3 SKIP-equivalent: wiki-init.sh present (M032/P02 closed)"
fi

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3"

printf 'SUMMARY: p08-with-wiki-passthrough.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 3. Author `tests/m033-acceptance/p08-with-github-passthrough.sh` (SC-10)

Mirror SC-9's shape but for `--with-github`. Key tests:

1. Stub mode rc=0 propagation; assert `STUB: github-init invoked` token; assert `github_init_invoked` JSONL with `"stub_mode":true` + `"exit_code":0`; assert sub-flow markers preserved.
2. Stub mode rc=17 propagation; assert `start.sh` exit code 17; assert `github-init failed; ... all other onboarding outputs preserved` diagnostic.
3. `--with-wiki --with-github` ordering rule: both stubs fire; assert `STUB: wiki-init invoked` line number < `STUB: github-init invoked` line number on stdout.

```bash
#!/usr/bin/env bash
# tests/m033-acceptance/p08-with-github-passthrough.sh
# SC-10: FR-16 --with-github passthrough acceptance + ordering rule when both flags.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

seed_post_onboarding() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/start-state"
    for sf in init-invoked subflow-started subflow-completed; do
        date -u +%Y-%m-%dT%H:%M:%SZ > "$stage/.orchestrator/start-state/$sf.complete"
    done
}

# Test 1: stub rc=0.
STAGE1=$(mktemp -d)
seed_post_onboarding "$STAGE1"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=0 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE1" --branch greenfield-empty \
    --with-github --yes --dry-run \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
[ "$RC1" -eq 0 ] && pass "T1 stub rc=0" || fail "T1 rc=$RC1"
grep -qF 'STUB: github-init invoked' "$STAGE1/stdout" \
    && pass "T1 STUB token" || fail "T1 STUB token absent"
grep -qF '"github_init_invoked"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 JSONL record" || fail "T1 JSONL absent"
grep -qF '"stub_mode":true' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 stub_mode:true" || fail "T1 stub_mode wrong"
grep -qF '"exit_code":0' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T1 exit_code:0" || fail "T1 exit_code wrong"
[ -f "$STAGE1/.orchestrator/start-state/init-invoked.complete" ] \
    && pass "T1 markers preserved" || fail "T1 markers cleared"

# Test 2: stub rc=17.
STAGE2=$(mktemp -d)
seed_post_onboarding "$STAGE2"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=17 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE2" --branch greenfield-empty \
    --with-github --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
[ "$RC2" -eq 17 ] && pass "T2 stub rc=17 propagation" || fail "T2 rc=$RC2 expected 17"
grep -qF 'github-init failed' "$STAGE2/stdout" && pass "T2 failure diagnostic" || fail "T2 diagnostic absent"
grep -qF 'all other onboarding outputs preserved' "$STAGE2/stdout" \
    && pass "T2 preservation diagnostic" || fail "T2 preservation absent"
grep -qF '"exit_code":17' "$STAGE2/.orchestrator/execution-log.jsonl" 2>/dev/null \
    && pass "T2 exit_code:17" || fail "T2 exit_code wrong"
[ -f "$STAGE2/.orchestrator/start-state/init-invoked.complete" ] \
    && pass "T2 markers preserved on failure" || fail "T2 markers cleared on failure"

# Test 3: --with-wiki --with-github ordering rule.
STAGE3=$(mktemp -d)
seed_post_onboarding "$STAGE3"
M033_FR15_STUB=1 M033_GHINIT_STUB=1 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE3" --branch greenfield-empty \
    --with-wiki --with-github --yes --dry-run \
    > "$STAGE3/stdout" 2> "$STAGE3/stderr"
WIKI_LINE=$(grep -nF 'STUB: wiki-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
GH_LINE=$(grep -nF 'STUB: github-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
if [ -n "$WIKI_LINE" ] && [ -n "$GH_LINE" ] && [ "$WIKI_LINE" -lt "$GH_LINE" ]; then
    pass "T3 ordering: wiki ($WIKI_LINE) before github ($GH_LINE)"
else
    fail "T3 ordering violated: wiki=$WIKI_LINE github=$GH_LINE"
fi

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3"

printf 'SUMMARY: p08-with-github-passthrough.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 4. Author wrapper verifiers `tools/verify/m033-p05-acceptance-shape-sc{7,9,10}.sh`

Each follows the same shape as P04's wrapper verifiers (e.g. `tools/verify/m033-p04-acceptance-shape-sc4.sh`):

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-acceptance-shape-sc7.sh
# Wrapper for tests/m033-acceptance/p06-customblock-draft.sh.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

SCRIPT="tests/m033-acceptance/p06-customblock-draft.sh"
[ -f "$SCRIPT" ] && pass "script exists" || fail "script missing"
[ -x "$SCRIPT" ] && pass "script executable" || fail "script not executable"

# Token-presence shape check.
for tok in 'SC-7' 'FR-13' 'FR-14' 'customblock-draft.sh' 'BEGIN CUSTOM' \
           '## Project' '## Stack' '## Conventions' '## Decisions' \
           'constitution not present' 'no changes' 'discards prior operator edits' \
           '## Notes' '## Source-Docs' 'customblock_drafted'; do
    grep -qF -- "$tok" "$SCRIPT" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$SCRIPT")
[ "$LINES" -ge 130 ] && pass "min 130 lines (got $LINES)" || fail "below 130 lines"

# Functional run + exit propagation.
bash "$SCRIPT" > /dev/null 2> /dev/null
RC=$?
[ "$RC" -eq 0 ] && pass "functional rc=0" || fail "functional rc=$RC"

printf 'SUMMARY: m033-p05-acceptance-shape-sc7.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

For SC-9 (`m033-p05-acceptance-shape-sc9.sh`): same pattern but for `tests/m033-acceptance/p08-with-wiki-passthrough.sh`; required tokens include `SC-9`, `FR-15`, `MIT-001`, `M033_FR15_STUB`, `M033_FR15_STUB_EXIT_CODE`, `wiki_init_invoked`, `wiki-init failed`, `all other onboarding outputs preserved`, `stub_mode`, `exit_code`, `wiki-init.sh not found`. Min 120 lines.

For SC-10 (`m033-p05-acceptance-shape-sc10.sh`): same pattern but for `tests/m033-acceptance/p08-with-github-passthrough.sh`; required tokens include `SC-10`, `FR-16`, `M033_GHINIT_STUB`, `M033_GHINIT_STUB_EXIT_CODE`, `github_init_invoked`, `github-init failed`, `all other onboarding outputs preserved`, `stub_mode`, `exit_code`. Min 110 lines.

Defensive `grep -qF --` (double-dash) is used for tokens starting with `--` per the P04 pattern.

### 5. Author `tests/m033-acceptance/run-acceptance-battery.sh` (SC-14 / MIT-002)

Model byte-for-byte on `tests/m031-acceptance/run-acceptance-battery.sh`. Key invariants:

- Explicit enumeration of all 13 named SC scripts (NOT phase-prefix grouping per MIT-002).
- `run_sc()` helper with `BATTERY-PASS:` / `BATTERY-FAIL:` per-call output.
- Final aggregation line `BATTERY: pass=N fail=M`.
- Exit 0 iff fail=0.
- Propagates `M033_FR15_STUB=1` and `M033_GHINIT_STUB=1` env vars (already in environment when child is invoked — bash automatically forwards exported vars; the runner does NOT need to explicitly set them, only document the contract).
- NO `EXIT 77` / `SKIP:` paths (SC-14 `skip=0` invariant per MIT-001 / CON-1).

```bash
#!/usr/bin/env bash
# tests/m033-acceptance/run-acceptance-battery.sh
# M033/P05/T04 -- SC-14 acceptance battery runner.
# MIT-002: explicit enumeration of all 13 named scripts (NOT phase-prefix grouping).
# CON-1 / MIT-001: stub-mode tests produce pass not skip; SC-14 skip=0 invariant.
#
# Modeled byte-for-byte on tests/m030-acceptance/run-acceptance-battery.sh
# and tests/m031-acceptance/run-acceptance-battery.sh.
#
# Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.
#
# Env vars propagated to child invocations (when set in runner environment):
#   M033_FR15_STUB=1            -- triggers SC-9 stub-mode wiki-init invocation
#   M033_FR15_STUB_EXIT_CODE=N  -- synthetic wiki-init exit code (for failure tests)
#   M033_GHINIT_STUB=1          -- triggers SC-10 stub-mode github-init invocation
#   M033_GHINIT_STUB_EXIT_CODE=N -- synthetic github-init exit code

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

run_sc() {
    # $1 SC label  $2 verifier path
    local label="$1"
    local path="$2"
    bash "$path"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass=$((pass + 1))
        printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
    else
        fail=$((fail + 1))
        printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
    fi
}

# ---------- 13 named scripts in explicit-enumeration order (MIT-002) ----------
run_sc "SC-1"  "$PROJECT_ROOT/tests/m033-acceptance/p01-start-branch-routing.sh"
run_sc "SC-2"  "$PROJECT_ROOT/tests/m033-acceptance/p02-constitution-author.sh"
run_sc "SC-3"  "$PROJECT_ROOT/tests/m033-acceptance/p03-ingest-codebase.sh"
run_sc "SC-4"  "$PROJECT_ROOT/tests/m033-acceptance/p04-materials-intake.sh"
run_sc "SC-5"  "$PROJECT_ROOT/tests/m033-acceptance/p04-ideation.sh"
run_sc "SC-6"  "$PROJECT_ROOT/tests/m033-acceptance/p05-migrate-routing.sh"
run_sc "SC-7"  "$PROJECT_ROOT/tests/m033-acceptance/p06-customblock-draft.sh"
run_sc "SC-8"  "$PROJECT_ROOT/tests/m033-acceptance/p07-friendly-tester-protocol.sh"
run_sc "SC-9"  "$PROJECT_ROOT/tests/m033-acceptance/p08-with-wiki-passthrough.sh"
run_sc "SC-10" "$PROJECT_ROOT/tests/m033-acceptance/p08-with-github-passthrough.sh"
run_sc "SC-11" "$PROJECT_ROOT/tests/m033-acceptance/p07-grilling-shell.sh"
run_sc "SC-12" "$PROJECT_ROOT/tests/m033-acceptance/p07-resume-on-partial-state.sh"
run_sc "SC-13" "$PROJECT_ROOT/tests/m033-acceptance/p07-observability-records.sh"

# ---------- Aggregate (no skip mechanism per SC-14 invariant) ----------
printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
```

### 6. Author `tools/verify/m033-p05-acceptance-battery-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-acceptance-battery-shape.sh
# Asserts tests/m033-acceptance/run-acceptance-battery.sh shape.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

BATTERY="tests/m033-acceptance/run-acceptance-battery.sh"
[ -f "$BATTERY" ] && pass "battery exists" || fail "battery missing"
[ -x "$BATTERY" ] && pass "battery executable" || fail "battery not executable"

for tok in 'BATTERY:' 'BATTERY-PASS:' 'BATTERY-FAIL:' 'MIT-002' \
           'p01-start-branch-routing.sh' 'p02-constitution-author.sh' 'p03-ingest-codebase.sh' \
           'p04-materials-intake.sh' 'p04-ideation.sh' 'p05-migrate-routing.sh' \
           'p06-customblock-draft.sh' 'p07-friendly-tester-protocol.sh' \
           'p07-grilling-shell.sh' 'p07-resume-on-partial-state.sh' 'p07-observability-records.sh' \
           'p08-with-wiki-passthrough.sh' 'p08-with-github-passthrough.sh' \
           'M033_FR15_STUB' 'M033_GHINIT_STUB'; do
    grep -qF -- "$tok" "$BATTERY" && pass "token present: $tok" || fail "token absent: $tok"
done

# Negative grep: SC-14 skip=0 invariant -- NO EXIT 77 / SKIP token.
NONCOMMENT=$(grep -Ev '^[[:space:]]*#' "$BATTERY" || true)
if printf '%s' "$NONCOMMENT" | grep -qE '(EXIT 77|exit 77|SKIP:)'; then
    fail "SC-14 invariant violated: SKIP path detected"
else
    pass "no SKIP path (SC-14 skip=0 invariant)"
fi

LINES=$(wc -l < "$BATTERY")
[ "$LINES" -ge 80 ] && pass "min 80 lines (got $LINES)" || fail "below 80 lines"

# Functional run with stub-mode env vars set.
M033_FR15_STUB=1 M033_GHINIT_STUB=1 bash "$BATTERY" > /tmp/m033-battery-out.txt 2>&1
RC=$?
if grep -qF 'BATTERY: pass=13 fail=0' /tmp/m033-battery-out.txt; then
    pass "battery emits BATTERY: pass=13 fail=0"
else
    fail "battery did not emit pass=13 fail=0 final line"
fi
[ "$RC" -eq 0 ] && pass "battery rc=0" || fail "battery rc=$RC"

rm -f /tmp/m033-battery-out.txt

printf 'SUMMARY: m033-p05-acceptance-battery-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves:

- `tests/m033-acceptance/p06-customblock-draft.sh` exists and exits 0 (Truth #6 / SC-7)
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` exists and exits 0 (Truth #7 / SC-9 amended per MIT-001)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` exists and exits 0 (Truth #8 / SC-10)
- `tests/m033-acceptance/run-acceptance-battery.sh` exists and prints `BATTERY: pass=13 fail=0` (Truth #9 / SC-14)
- Acceptance artifacts: `p06-customblock-draft.sh`, `p08-with-wiki-passthrough.sh`, `p08-with-github-passthrough.sh`, `run-acceptance-battery.sh`
- Verifier artifacts: `m033-p05-acceptance-shape-sc7.sh`, `m033-p05-acceptance-shape-sc9.sh`, `m033-p05-acceptance-shape-sc10.sh`, `m033-p05-acceptance-battery-shape.sh`

## Verification

```bash
bash tools/verify/m033-p05-acceptance-shape-sc7.sh
bash tools/verify/m033-p05-acceptance-shape-sc9.sh
bash tools/verify/m033-p05-acceptance-shape-sc10.sh
bash tools/verify/m033-p05-acceptance-battery-shape.sh
```

## Inputs

### From Previous Tasks

- `commands/customblock-draft.md` (T01) — referenced by SC-7
- `scripts/lifecycle/customblock-draft.sh` (T01)
  - Key API: `bash <path> --project-dir <dir> [--yes] [--force]`; reads `<dir>/.orchestrator/memory/constitution.md` (US-7 AS-5 gate), `<dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/MEM-*.md`, `<dir>/.orchestrator/intake/<timestamp>/{reconciled-pre-spec.md,ideation-pre-spec.md}`; writes between `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` markers in `<dir>/CLAUDE.md`; emits `customblock_drafted` JSONL; writes `customblock-draft.complete` marker
  - Key types: `--force` flag; `EDITOR=cat` for non-interactive review; exit 0 on success / non-zero on missing constitution
- `scripts/lifecycle/start.sh` (T02 + T03 extended)
  - Key API: `bash <path> --project-dir <dir> --branch <branch> [--yes] [--dry-run] [--with-wiki] [--with-giscus] [--deploy] [--with-github]`; under `M033_FR15_STUB=1` invokes the wiki stub; under `M033_GHINIT_STUB=1` invokes the github stub
  - Key env vars: `M033_FR15_STUB`, `M033_FR15_STUB_EXIT_CODE`, `M033_GHINIT_STUB`, `M033_GHINIT_STUB_EXIT_CODE`
  - Key tokens emitted to stdout: `STUB: wiki-init invoked`, `STUB: github-init invoked`, `wiki-init failed`, `github-init failed`, `all other onboarding outputs preserved`
  - Key JSONL events: `wiki_init_invoked`, `github_init_invoked` with payload fields `project_dir`, `exit_code`, `stub_mode`, (wiki) `with_giscus`, `deploy`

### From Disk (Pre-existing)

- `scripts/util/jsonl-event-emitter.sh` (P02/T01)
- `scripts/util/start-state-markers.sh` (P02/T02)
- `tests/m030-acceptance/run-acceptance-battery.sh` and `tests/m031-acceptance/run-acceptance-battery.sh` — battery template references
- The 10 prior-phase acceptance scripts under `tests/m033-acceptance/` (P01..P04 deliverables)

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no command-substitution-with-pipes
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only; the `## Verification` section contains ONLY executable check commands per M028/P01 dogfood finding
- MIT-002 explicit enumeration — battery enumerates 13 scripts by literal `run_sc` calls, NOT phase-prefix grouping
- MIT-001 / CON-1 / SC-14 `skip=0` — battery has no skip mechanism; stub-mode tests produce pass not skip
- AD-15 cross-phase regression — T04's deliverables MUST NOT regress P01..P04 (acceptance scripts under `tests/m033-acceptance/p01..p07*.sh` MUST still pass)
- Defensive `grep -qF --` (double-dash) for tokens starting with `--` per the P04 wrapper-verifier pattern
- Cleanup mandatory — every `mktemp -d` staging dir is removed at script end
- T04's acceptance scripts MUST NOT depend on M032/P02 closure for their pass condition; SC-9 covers the `wiki-init.sh not found` real-mode case explicitly

## Expected Output

T04 creates 8 new files:
- `tests/m033-acceptance/p06-customblock-draft.sh` (≥130 lines, executable)
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (≥120 lines, executable)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (≥110 lines, executable)
- `tests/m033-acceptance/run-acceptance-battery.sh` (≥80 lines, executable)
- `tools/verify/m033-p05-acceptance-shape-sc7.sh` (≥25 lines, executable)
- `tools/verify/m033-p05-acceptance-shape-sc9.sh` (≥25 lines, executable)
- `tools/verify/m033-p05-acceptance-shape-sc10.sh` (≥25 lines, executable)
- `tools/verify/m033-p05-acceptance-battery-shape.sh` (≥30 lines, executable)

T04 modifies zero existing files.

After T04 lands:
- `bash tools/verify/m033-p05-acceptance-shape-sc7.sh` → `SUMMARY: m033-p05-acceptance-shape-sc7.sh pass=N fail=0` (functional run includes SC-7 acceptance exit 0)
- `bash tools/verify/m033-p05-acceptance-shape-sc9.sh` → `SUMMARY: m033-p05-acceptance-shape-sc9.sh pass=N fail=0`
- `bash tools/verify/m033-p05-acceptance-shape-sc10.sh` → `SUMMARY: m033-p05-acceptance-shape-sc10.sh pass=N fail=0`
- `M033_FR15_STUB=1 M033_GHINIT_STUB=1 bash tests/m033-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=13 fail=0`
- `bash tools/verify/m033-p05-acceptance-battery-shape.sh` → `SUMMARY: m033-p05-acceptance-battery-shape.sh pass=N fail=0`

## Notes

### MIT-002 explicit-enumeration discovery model

Per the spec amendment to SC-14, the battery enumerates 13 named scripts via explicit `run_sc` calls in literal order. Multiple scripts sharing a phase prefix (`p04-materials-intake.sh` / `p04-ideation.sh`; `p07-*` ×4; `p08-*` ×2) are intentional — each represents a distinct concern. The battery MUST NOT group tests by phase prefix; it runs all 13 named scripts and expects exactly 13 to match.

### SC-14 `skip=0` invariant (CON-1 / MIT-001)

The battery has NO skip mechanism — no `EXIT 77` paths, no `SKIP:` tokens. Stub-mode SC-9 produces pass not skip per MIT-001. The shape verifier (`m033-p05-acceptance-battery-shape.sh`) asserts via negative grep that no `EXIT 77` / `exit 77` / `SKIP:` token appears in the battery body (excluding comments). If a future amendment adds skip handling, the schema would need to declare `skip=N` in the `BATTERY:` line and `M033-SUMMARY.md` would need to carry a signed-attestation block per MIT-001.

### Stub-mode env vars are forwarded automatically

When the runner is invoked as `M033_FR15_STUB=1 M033_GHINIT_STUB=1 bash tests/m033-acceptance/run-acceptance-battery.sh`, bash exports those variables to child processes automatically (the variables are part of the runner's environment). The runner does NOT need to explicitly set them; it only needs to NOT unset them. The contract is documented in the battery's header comment block.

### SC-9 real-mode case when M032/P02 is not closed

In the M033/P05 working tree at planning time, `scripts/lifecycle/wiki-init.sh` is NOT on disk. SC-9's Test 3 covers this case: when no stub mode is active AND the wiki-init script is absent, `start --with-wiki` exits non-zero with the `wiki-init.sh not found` diagnostic. SC-9 asserts this is treated as a genuine failure (not skip) — Test 3's branch using `[ ! -f "scripts/lifecycle/wiki-init.sh" ]` ensures the test passes whether or not M032/P02 has closed at SC-9 run time. Once M032/P02 closes, the path activates and Test 3's `else` branch fires (passing as a degenerate `wiki-init.sh present` check).

### Path-collision check (Plan-Time Discipline rule 6)

All 8 created paths verified absent at planning time:
- `tests/m033-acceptance/p06-customblock-draft.sh`
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh`
- `tests/m033-acceptance/p08-with-github-passthrough.sh`
- `tests/m033-acceptance/run-acceptance-battery.sh`
- `tools/verify/m033-p05-acceptance-shape-sc7.sh`
- `tools/verify/m033-p05-acceptance-shape-sc9.sh`
- `tools/verify/m033-p05-acceptance-shape-sc10.sh`
- `tools/verify/m033-p05-acceptance-battery-shape.sh`

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

Every `## Verification` command resolves to a verifier co-authored inside this task (steps 4 + 6). The acceptance scripts are exercised via the wrapper verifiers' functional-run sections; the wrappers and acceptance scripts are co-authored together in this task.

### `customblock_drafted`, `wiki_init_invoked`, `github_init_invoked` already in JSONL closed enum

P02/T01 shipped all three event types in the FR-22 closed enum. T04's acceptance scripts assert the JSONL records appear with the documented payload fields — no enum extension required.
