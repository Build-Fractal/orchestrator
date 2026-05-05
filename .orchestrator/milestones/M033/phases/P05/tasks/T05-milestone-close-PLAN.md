---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M033"
name: "M033 milestone close — phase-suite + cross-phase regression + scope-guard + M033-VALIDATED marker + M033-SUMMARY.md + milestone-grain unit_close JSONL (AD-7 three-part close gate)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

T05 closes the milestone. Ships the P05 phase-suite aggregator, cross-phase regression, bidirectional scope-guard, the AD-7 three-part close gate (`M033-VALIDATED` marker + `M033-SUMMARY.md` + milestone-grain `unit_close` JSONL), and three shape verifiers for the close-state artifacts.

Files that MUST exist on disk at task-start (verified via `ls -la` per Plan-Time Discipline rule 1):

- `commands/customblock-draft.md` (T01)
- `scripts/lifecycle/customblock-draft.sh` (T01)
- `references/customblock-format.md` (T01)
- `scripts/lifecycle/start.sh` (T02 + T03 extended)
- `tests/m033-acceptance/p06-customblock-draft.sh` (T04)
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (T04)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (T04)
- `tests/m033-acceptance/run-acceptance-battery.sh` (T04)
- All T01..T04 verifiers under `tools/verify/m033-p05-*` (8 files: 3 from T01, 1 from T02, 1 from T03, 4 from T04)
- All P01..P04 phase-suites: `tools/verify/m033-p01-phase-suite.sh`, `tools/verify/m033-p02-phase-suite.sh`, `tools/verify/m033-p03-phase-suite.sh`, `tools/verify/m033-p04-phase-suite.sh`
- `scripts/verify/standalone-gate.sh` (P03/T01) — invoked by cross-phase regression for CON-3 invariant check
- `scripts/verify/validate-milestone.sh` (framework) — invoked at close to compute NNN
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — emits `unit_close` record (note: `unit_close` is a milestone-grain event type — verify it's in the closed enum or extend additively)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (P01) — SC-15 mechanical gate

Reference templates:
- `templates/milestone-summary.md` — defines the M033-SUMMARY.md frontmatter shape
- `.orchestrator/milestones/M030/M030-SUMMARY.md` and `.orchestrator/milestones/M031/M031-SUMMARY.md` — milestone-summary precedents to model on
- `.orchestrator/milestones/M030/M030-VALIDATED` — VALIDATED marker precedent (if present)

## Description

T05 ships ELEVEN deliverables grouped into three concerns:

**Concern A: Phase-level aggregators (3 files)**

1. **`tools/verify/m033-p05-phase-suite.sh`** — chains all 9 P05 verifiers in dependency order; emits `SUMMARY: m033-p05-phase-suite.sh pass=N fail=M`.

2. **`tools/verify/m033-p05-cross-phase-regression.sh`** — re-runs `m033-p01-phase-suite.sh` + `m033-p02-phase-suite.sh` + `m033-p03-phase-suite.sh` + `m033-p04-phase-suite.sh` + `bash scripts/verify/standalone-gate.sh constitution` and asserts each exits 0; AD-15 cross-phase regression discipline.

3. **`tools/verify/m033-p05-scope-guard.sh`** — bidirectional scope-guard (forbidden-presence + allowed-presence whitelist); asserts no out-of-scope writes (M032 internals, M013 internals, M015 internals, M020 schema) AND every P05 deliverable is on disk.

**Concern B: AD-7 three-part close gate artifacts (3 files)**

4. **`.orchestrator/milestones/M033/M033-VALIDATED`** — milestone-validated marker file; gated on AD-7 (SC-14 `skip=0` AND SC-15 friendly-tester verdict AND SC-16 NNN ≥ 15).

5. **`.orchestrator/milestones/M033/M033-SUMMARY.md`** — milestone summary with canonical M030/M031 shape; references SC-1..SC-16 verdicts.

6. **`.orchestrator/execution-log.jsonl` append** — single milestone-grain `unit_close` JSONL record; modeled on M030/M031 precedents.

**Concern C: Close-state shape verifiers (3 files)**

7. **`tools/verify/m033-p05-validated-marker-shape.sh`** — asserts `M033-VALIDATED` marker exists with non-empty content; documents the AD-7 three-part gate.

8. **`tools/verify/m033-p05-summary-md-shape.sh`** — asserts `M033-SUMMARY.md` shape (frontmatter + SC-1..SC-16 references + standalone-gate verdict).

9. **`tools/verify/m033-p05-unit-close-jsonl-shape.sh`** — asserts a single milestone-grain `unit_close` record was appended.

Plus the close-state authorship logic: T05 manually authors M033-VALIDATED and M033-SUMMARY.md (or extends an existing close-helper script — implementation choice at execution time) and emits the `unit_close` JSONL record via `bash scripts/util/jsonl-event-emitter.sh emit unit_close <payload>`.

## Steps

### 1. Author `tools/verify/m033-p05-phase-suite.sh`

Chain all 9 P05 verifiers in dependency order, emit canonical `SUMMARY:` line:

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-phase-suite.sh
# M033/P05 phase-suite aggregator -- chains 9 P05 verifiers.
set -u
PASS=0; FAIL=0

VERIFIERS="
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
"

OLDIFS="$IFS"
IFS=$'\n'
for v in $VERIFIERS; do
    [ -z "$v" ] && continue
    bash "$v" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS+1))
        printf 'PASS: %s\n' "$v"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: %s (rc=%d)\n' "$v" "$rc"
    fi
done
IFS="$OLDIFS"

printf 'SUMMARY: m033-p05-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 2. Author `tools/verify/m033-p05-cross-phase-regression.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-cross-phase-regression.sh
# AD-15 cross-phase regression: re-run P01..P04 phase-suites + standalone-gate.
set -u
PASS=0; FAIL=0

SUITES="
tools/verify/m033-p01-phase-suite.sh
tools/verify/m033-p02-phase-suite.sh
tools/verify/m033-p03-phase-suite.sh
tools/verify/m033-p04-phase-suite.sh
"

OLDIFS="$IFS"
IFS=$'\n'
for s in $SUITES; do
    [ -z "$s" ] && continue
    bash "$s" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS+1))
        printf 'PASS: %s\n' "$s"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: %s (rc=%d)\n' "$s" "$rc"
    fi
done
IFS="$OLDIFS"

# CON-3 / Principle XVI standalone-gate invariant must still hold.
bash scripts/verify/standalone-gate.sh constitution > /dev/null 2>&1
GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
    PASS=$((PASS+1))
    printf 'PASS: standalone-gate constitution (CON-3 / Principle XVI)\n'
else
    FAIL=$((FAIL+1))
    printf 'FAIL: standalone-gate constitution (rc=%d)\n' "$GATE_RC"
fi

printf 'SUMMARY: m033-p05-cross-phase-regression.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 3. Author `tools/verify/m033-p05-scope-guard.sh`

Bidirectional scope-guard per the P02/P03/P04 pattern:

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-scope-guard.sh
# Bidirectional scope-guard: forbidden-presence + allowed-presence.
set -u
PASS=0; FAIL=0

# Forbidden-presence: out-of-scope surfaces MUST NOT be touched by P05.
# (M032 internals, M013 internals, M015 internals, M020 schema.)
FORBIDDEN="
wiki/mkdocs.yml
wiki/overrides
packaging/bundle/manifest.yml.M032-edit
scripts/migrate/migrate.sh.M033-edit
scripts/lifecycle/github-init.sh.M033-edit
knowledge/spec/MEM-NEW-KIND.md
"
OLDIFS="$IFS"
IFS=$'\n'
for f in $FORBIDDEN; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        FAIL=$((FAIL+1))
        printf 'FAIL: forbidden-presence: %s exists (out-of-scope write)\n' "$f"
    else
        PASS=$((PASS+1))
        printf 'PASS: forbidden-presence: %s absent\n' "$f"
    fi
done
IFS="$OLDIFS"

# Allowed-presence: every P05 deliverable MUST be on disk.
ALLOWED="
commands/customblock-draft.md
scripts/lifecycle/customblock-draft.sh
references/customblock-format.md
scripts/lifecycle/start.sh
tests/m033-acceptance/p06-customblock-draft.sh
tests/m033-acceptance/p08-with-wiki-passthrough.sh
tests/m033-acceptance/p08-with-github-passthrough.sh
tests/m033-acceptance/run-acceptance-battery.sh
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
tools/verify/m033-p05-phase-suite.sh
tools/verify/m033-p05-cross-phase-regression.sh
tools/verify/m033-p05-scope-guard.sh
tools/verify/m033-p05-validated-marker-shape.sh
tools/verify/m033-p05-summary-md-shape.sh
tools/verify/m033-p05-unit-close-jsonl-shape.sh
"
IFS=$'\n'
for f in $ALLOWED; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        PASS=$((PASS+1))
        printf 'PASS: allowed-presence: %s exists\n' "$f"
    else
        FAIL=$((FAIL+1))
        printf 'FAIL: allowed-presence: %s missing (P05 deliverable)\n' "$f"
    fi
done
IFS="$OLDIFS"

# Customblock-draft must additively-extend, not over-author M020 schema.
# Negative grep on customblock-draft.sh for any M020 schema-extension token.
NONCOMMENT=$(grep -Ev '^[[:space:]]*#' scripts/lifecycle/customblock-draft.sh 2>/dev/null || true)
for forbidden_kind in 'mkdir.*knowledge/[a-z]*kind' 'kind:.*new'; do
    if printf '%s' "$NONCOMMENT" | grep -qE -- "$forbidden_kind"; then
        FAIL=$((FAIL+1))
        printf 'FAIL: M020 schema overreach: %s\n' "$forbidden_kind"
    else
        PASS=$((PASS+1))
        printf 'PASS: no M020 schema overreach: %s\n' "$forbidden_kind"
    fi
done

printf 'SUMMARY: m033-p05-scope-guard.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 4. Run the AD-7 three-part close gate and author `M033-VALIDATED`

This step is procedural at execution time, not a script. The executor:

1. Runs `bash tests/m033-acceptance/run-acceptance-battery.sh` (with `M033_FR15_STUB=1 M033_GHINIT_STUB=1` if M032/P02 has not closed). Asserts `BATTERY: pass=13 fail=0` (SC-14 / first AD-7 gate). If `pass<13` OR `skip>0`, STOP and surface — do NOT write the marker. The `skip=0` invariant is non-negotiable per CON-1 / MIT-001.

2. Runs `bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh tests/m033-acceptance/friendly-tester-pass/report-<latest>.md` (where `<latest>` is the lexicographically latest filed report). Asserts exit 0 with `friction_blockers: 0` AND `eligible_testers >= 1` (SC-15 / second AD-7 gate). FALLBACK: if no report has been filed AND `M033_SKIP_FRIENDLY_TESTER_PASS=1` is declared in the close-state environment, the gate is satisfied via signed attestation (per US-8 AS-5 / launch sequencing amendment #Q-1). The signed-attestation block MUST be inserted into `M033-SUMMARY.md` (step 5).

3. Runs `bash scripts/verify/validate-milestone.sh M033`. Asserts `M033: NNN/NNN PASS` with NNN ≥ 15 (SC-16 / third AD-7 gate, non-escalable per MIT-004). If NNN < 15, STOP and surface.

If all three gates pass, the executor authors `.orchestrator/milestones/M033/M033-VALIDATED`:

```
M033 VALIDATED -- 2026-05-DD

AD-7 three-part close gate satisfied:
- SC-14: bash tests/m033-acceptance/run-acceptance-battery.sh exit 0 with BATTERY: pass=13 fail=0 skip=0
- SC-15: bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh exit 0 (friction_blockers: 0, eligible_testers: 1)
        OR M033_SKIP_FRIENDLY_TESTER_PASS=1 signed attestation per US-8 AS-5 / launch sequencing amendment #Q-1
- SC-16: bash scripts/verify/validate-milestone.sh M033 reports M033: NNN/NNN PASS with NNN ≥ 15

Validated by: <maintainer-id>
Validated at: <ISO 8601 UTC>
```

### 5. Author `M033-SUMMARY.md`

Modeled on `.orchestrator/milestones/M031/M031-SUMMARY.md` shape. YAML frontmatter:

```yaml
---
schema_version: "1.0"
type: milestone-summary
id: "M033"
parent: "milestone"
milestone: "M033"
provides:
  - "orchestrator:start warm conversational front door (FR-1/FR-2/FR-20/FR-21/FR-22); orchestrator-native constitution authoring (FR-3/FR-4/FR-5/FR-6/CON-3); deterministic codebase ingestion (FR-7/FR-8/MIT-005); materials intake with deterministic CON-4 drift detection (FR-9); ideation with MIT-007 live contradiction detection (FR-10/FR-17); migrate-routing glue (FR-11/FR-12); customblock drafter with strict aggregation (FR-13/FR-14); --with-wiki paired-launch passthrough (FR-15/CON-1/MIT-001); --with-github passthrough (FR-16); grilling-shell + glossary inline-update writer (FR-17/FR-18); friendly-tester pass artifact + validator (FR-19/SC-15)"
requires:
  - "M001 (init), M013 (github-init), M014 (dual-write), M015 (migrate), M020 (knowledge-graph kinds), M027 (observability), M030 (model routing), M031 (build-context profile), M032 (paired wiki-init)"
affects:
  - "Launch first-impression UX; M029 (where) consumes branch-detection signals; M035 (packaging) consumes friendly-tester recruiting protocol; M036b (post-launch wiki UX) consumes grilling-shell"
key_files:
  - "<full file inventory mirroring P01..P05 phase-summaries>"
key_decisions:
  - "<aggregated decision rows from P01..P05>"
patterns_established:
  - "<aggregated patterns from P01..P05 phase-summaries>"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/P01-SUMMARY.md, .orchestrator/milestones/M033/phases/P02/P02-SUMMARY.md, .orchestrator/milestones/M033/phases/P03/P03-SUMMARY.md, .orchestrator/milestones/M033/phases/P04/P04-SUMMARY.md, .orchestrator/milestones/M033/phases/P05/P05-SUMMARY.md"
duration: "<sum of P01..P05 durations>"
verification_result: "pass"
completed_at: "<ISO 8601 UTC>"
observability_surfaces:
  - "jsonl-event-emitter.sh@.orchestrator/execution-log.jsonl (12 closed-enum event types); customblock-draft.complete + ideation.complete + materials-intake.complete + constitution-authored.complete + ingest-codebase.complete + start-state markers; M033-VALIDATED marker file"
---
```

Body (≥100 lines total) sections:

```markdown
# M033 Milestone Summary

## Vision realized

<one-paragraph synthesis>

## Phase rollup

- P01 closed YYYY-MM-DD: <one-line shipped surface>
- P02 closed YYYY-MM-DD: <one-line>
- P03 closed YYYY-MM-DD: <one-line>
- P04 closed YYYY-MM-DD: <one-line>
- P05 closed YYYY-MM-DD: <one-line>

## SC verdict roll

| SC | Verifier | Verdict |
|----|----------|---------|
| SC-1 | tests/m033-acceptance/p01-start-branch-routing.sh | PASS |
| SC-2 | tests/m033-acceptance/p02-constitution-author.sh | PASS |
| SC-3 | tests/m033-acceptance/p03-ingest-codebase.sh | PASS |
| SC-4 | tests/m033-acceptance/p04-materials-intake.sh | PASS |
| SC-5 | tests/m033-acceptance/p04-ideation.sh | PASS |
| SC-6 | tests/m033-acceptance/p05-migrate-routing.sh | PASS |
| SC-7 | tests/m033-acceptance/p06-customblock-draft.sh | PASS |
| SC-8 | tests/m033-acceptance/p07-friendly-tester-protocol.sh | PASS |
| SC-9 | tests/m033-acceptance/p08-with-wiki-passthrough.sh | PASS (M033_FR15_STUB=1) |
| SC-10 | tests/m033-acceptance/p08-with-github-passthrough.sh | PASS (M033_GHINIT_STUB=1) |
| SC-11 | tests/m033-acceptance/p07-grilling-shell.sh | PASS |
| SC-12 | tests/m033-acceptance/p07-resume-on-partial-state.sh | PASS |
| SC-13 | tests/m033-acceptance/p07-observability-records.sh | PASS |
| SC-14 | tests/m033-acceptance/run-acceptance-battery.sh | PASS (BATTERY: pass=13 fail=0 skip=0) |
| SC-15 | tests/m033-acceptance/friendly-tester-pass/validate-report.sh | PASS (friction_blockers: 0, eligible_testers: 1) OR SIGNED-ATTESTATION (M033_SKIP_FRIENDLY_TESTER_PASS=1) |
| SC-16 | scripts/verify/validate-milestone.sh M033 | PASS (M033: NNN/NNN PASS with NNN ≥ 15) |

## CON-3 standalone-gate verdict

bash scripts/verify/standalone-gate.sh constitution: PASS (pass=N skip=0 fail=0) — Principle XVI's first content-authoring compliance test satisfied.

## AD-15 cross-phase regression verdict

P01 + P02 + P03 + P04 phase-suites all PASS against the post-P05 working tree.

## [Optional] Signed attestation block

If M033_SKIP_FRIENDLY_TESTER_PASS=1 was set per US-8 AS-5:

> Signed attestation: M033 closes without an outsider friendly-tester pass per the launch sequencing amendment #Q-1 fallback path. Cold-start UX risk acknowledged. Recruiting outreach attempted by 2026-05-DD; no eligible tester confirmed by 2026-05-12 fallback deadline. Maintainer signature: <name>, <date>.

## Patterns established

<aggregated from P01..P05>

## Open follow-ups (deferred)

- M032/P02 closure for SC-9 real-mode (paired-launch contract per CON-1)
- M033.5 LLM-augmentation for codebase ingestion per #Q-3 (demand-driven post-launch)
- Constitution starter library expansion per #Q-2 (demand-driven post-launch, ≥2 external requests trigger expansion)
- M034 interactive review gates (deferred post-launch, demand-driven)
```

### 6. Emit milestone-grain `unit_close` JSONL record

Run:

```bash
PAYLOAD='{"unit_grain":"milestone","unit_id":"M033","verification_result":"pass","completed_at":"<ISO 8601 UTC>","gates_passed":["SC-14","SC-15","SC-16"]}'
bash scripts/util/jsonl-event-emitter.sh emit unit_close "$PAYLOAD"
```

NOTE: `unit_close` may not be in the P02-shipped 12-event closed enum (which covers M033 sub-flow events). If absent, T05 includes a 1-line additive enum extension to `scripts/util/jsonl-event-emitter.sh` matching the P03/T04 precedent, OR reuses an existing milestone-close emitter helper if one exists. Verify at task-start by `grep -F 'unit_close' scripts/util/jsonl-event-emitter.sh`. Alternative: emit directly via `printf '%s\n' "..." >> .orchestrator/execution-log.jsonl` if the closed-enum extension is out of M033 scope (and document the deviation in M033-SUMMARY.md). Recommended: extend the enum additively, matching M030/M031's milestone-close precedent.

### 7. Author `tools/verify/m033-p05-validated-marker-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-validated-marker-shape.sh
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

MARKER=".orchestrator/milestones/M033/M033-VALIDATED"
[ -f "$MARKER" ] && pass "marker exists" || fail "marker missing: $MARKER"

for tok in 'M033' 'VALIDATED' 'AD-7' 'SC-14' 'SC-15' 'SC-16'; do
    grep -qF -- "$tok" "$MARKER" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$MARKER")
[ "$LINES" -ge 5 ] && pass "min 5 lines (got $LINES)" || fail "below 5 lines"

printf 'SUMMARY: m033-p05-validated-marker-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 8. Author `tools/verify/m033-p05-summary-md-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-summary-md-shape.sh
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

SUM=".orchestrator/milestones/M033/M033-SUMMARY.md"
[ -f "$SUM" ] && pass "summary exists" || fail "summary missing: $SUM"

for tok in 'schema_version' 'type: milestone-summary' 'M033' \
           'SC-1' 'SC-2' 'SC-3' 'SC-4' 'SC-5' 'SC-6' 'SC-7' 'SC-8' 'SC-9' \
           'SC-10' 'SC-11' 'SC-12' 'SC-13' 'SC-14' 'SC-15' 'SC-16' \
           'P01' 'P02' 'P03' 'P04' 'P05' 'standalone-gate' 'verification_result'; do
    grep -qF -- "$tok" "$SUM" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$SUM")
[ "$LINES" -ge 100 ] && pass "min 100 lines (got $LINES)" || fail "below 100 lines"

printf 'SUMMARY: m033-p05-summary-md-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 9. Author `tools/verify/m033-p05-unit-close-jsonl-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-unit-close-jsonl-shape.sh
# Asserts a single milestone-grain unit_close record was appended for M033.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

LOG=".orchestrator/execution-log.jsonl"
[ -f "$LOG" ] && pass "execution-log.jsonl exists" || fail "execution-log.jsonl missing"

# Find unit_close records mentioning M033 at milestone grain.
COUNT=$(grep -c '"event_type":"unit_close".*"unit_id":"M033".*"unit_grain":"milestone"' "$LOG" 2>/dev/null || true)
[ "${COUNT:-0}" -ge 1 ] && pass "milestone unit_close record present (count=$COUNT)" \
    || fail "no milestone unit_close record for M033"

# At least one record carries gates_passed.
if grep -q '"gates_passed".*"SC-14".*"SC-16"' "$LOG"; then
    pass "gates_passed includes SC-14 + SC-16"
else
    fail "gates_passed field missing required SC labels"
fi

printf 'SUMMARY: m033-p05-unit-close-jsonl-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves:

- `tools/verify/m033-p05-phase-suite.sh` exists and emits `SUMMARY: ... pass=N fail=0` (Truth #10)
- The P01..P04 cross-phase regression boundary holds (Truth #11)
- The bidirectional scope-guard invariant holds (Truth #12)
- `M033-VALIDATED` marker exists, AD-7-gated (Truth #13)
- `M033-SUMMARY.md` exists with canonical milestone-summary shape (Truth #14)
- Single milestone-grain `unit_close` JSONL record appended (Truth #15)
- Verifier artifacts: `m033-p05-phase-suite.sh`, `m033-p05-cross-phase-regression.sh`, `m033-p05-scope-guard.sh`, `m033-p05-validated-marker-shape.sh`, `m033-p05-summary-md-shape.sh`, `m033-p05-unit-close-jsonl-shape.sh`
- Marker artifact: `.orchestrator/milestones/M033/M033-VALIDATED`
- Summary artifact: `.orchestrator/milestones/M033/M033-SUMMARY.md`

## Verification

```bash
bash tools/verify/m033-p05-phase-suite.sh
bash tools/verify/m033-p05-cross-phase-regression.sh
bash tools/verify/m033-p05-scope-guard.sh
bash tools/verify/m033-p05-validated-marker-shape.sh
bash tools/verify/m033-p05-summary-md-shape.sh
bash tools/verify/m033-p05-unit-close-jsonl-shape.sh
bash scripts/verify/validate-milestone.sh M033
```

## Inputs

### From Previous Tasks

- `commands/customblock-draft.md` (T01) — referenced by scope-guard allowed-presence list
- `scripts/lifecycle/customblock-draft.sh` (T01) — referenced by scope-guard
- `references/customblock-format.md` (T01) — referenced by scope-guard
- `scripts/lifecycle/start.sh` (T02 + T03) — referenced by scope-guard; modified additively in P05
- `tests/m033-acceptance/p06-customblock-draft.sh` (T04) — referenced by phase-suite + scope-guard
- `tests/m033-acceptance/p08-with-wiki-passthrough.sh` (T04)
- `tests/m033-acceptance/p08-with-github-passthrough.sh` (T04)
- `tests/m033-acceptance/run-acceptance-battery.sh` (T04)
  - Key API: `bash <path>` runs the 13-script battery; final line `BATTERY: pass=N fail=M`; exit 0 iff fail=0
  - Key env vars: `M033_FR15_STUB`, `M033_GHINIT_STUB` (forwarded from runner environment to child invocations)
- All T01..T04 verifiers under `tools/verify/m033-p05-*` — referenced by phase-suite

### From Disk (Pre-existing)

- `tools/verify/m033-p01-phase-suite.sh` (P01/T05)
- `tools/verify/m033-p02-phase-suite.sh` (P02/T05)
- `tools/verify/m033-p03-phase-suite.sh` (P03/T05)
- `tools/verify/m033-p04-phase-suite.sh` (P04/T05)
- `scripts/verify/standalone-gate.sh` (P03/T01) — `bash <path> constitution` exits 0 with `pass=N skip=0` when CON-3 invariant holds
- `scripts/verify/validate-milestone.sh` (framework) — `bash <path> M033` reports `M033: NNN/NNN PASS`
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — emits `unit_close` (or extend additively if absent from closed enum)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (P01) — SC-15 mechanical gate
- `templates/milestone-summary.md` (M001) — frontmatter shape reference
- `.orchestrator/milestones/M030/M030-SUMMARY.md` and `.orchestrator/milestones/M031/M031-SUMMARY.md` — milestone-summary precedents

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- AD-7 three-part close gate — `M033-VALIDATED` MUST NOT be authored if any of the three gates fail. The marker authorship is procedural (step 4) and conditioned on the three gates' verdicts; SC-15's gate has a signed-attestation escalation per US-8 AS-5
- AD-15 cross-phase regression — every P01..P04 phase-suite MUST exit 0 against the post-P05 tree (verified by `m033-p05-cross-phase-regression.sh`)
- CON-3 / Principle XVI — `bash scripts/verify/standalone-gate.sh constitution` MUST exit 0 with `pass=N skip=0` (no `speckit.*` references in M033's content-authoring surfaces)
- Bidirectional scope-guard — both forbidden-presence (out-of-scope absence) AND allowed-presence (P05 deliverable presence) verified
- Closed-enum extension discipline — if `unit_close` is not in the P02-shipped enum, T05's extension is additive, matches the P03/T04 precedent, and preserves the existing 12 event-type tokens
- T05 MUST NOT modify P01..P04 acceptance scripts or P01..P04 phase-suites

## Expected Output

T05 creates 9 new files (3 aggregators + 3 close-state shape verifiers + 2 close-state artifacts + 1 JSONL-record append):

- `tools/verify/m033-p05-phase-suite.sh` (≥60 lines, executable)
- `tools/verify/m033-p05-cross-phase-regression.sh` (≥30 lines, executable)
- `tools/verify/m033-p05-scope-guard.sh` (≥60 lines, executable)
- `tools/verify/m033-p05-validated-marker-shape.sh` (≥25 lines, executable)
- `tools/verify/m033-p05-summary-md-shape.sh` (≥30 lines, executable)
- `tools/verify/m033-p05-unit-close-jsonl-shape.sh` (≥25 lines, executable)
- `.orchestrator/milestones/M033/M033-VALIDATED` (≥5 lines)
- `.orchestrator/milestones/M033/M033-SUMMARY.md` (≥100 lines)

T05 modifies one file:
- `.orchestrator/execution-log.jsonl` (append a single milestone-grain `unit_close` record)

T05 may additively extend `scripts/util/jsonl-event-emitter.sh` if `unit_close` is not in the closed enum (1-line addition matching the P03/T04 precedent).

After T05 lands:
- `bash tools/verify/m033-p05-phase-suite.sh` → `SUMMARY: m033-p05-phase-suite.sh pass=9 fail=0`
- `bash tools/verify/m033-p05-cross-phase-regression.sh` → `SUMMARY: m033-p05-cross-phase-regression.sh pass=5 fail=0` (4 phase-suites + 1 standalone-gate)
- `bash tools/verify/m033-p05-scope-guard.sh` → `SUMMARY: m033-p05-scope-guard.sh pass=N fail=0`
- `bash tools/verify/m033-p05-validated-marker-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash tools/verify/m033-p05-summary-md-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash tools/verify/m033-p05-unit-close-jsonl-shape.sh` → `SUMMARY: ... pass=N fail=0`
- `bash scripts/verify/validate-milestone.sh M033` → `M033: NNN/NNN PASS` with NNN ≥ 15

## Notes

### AD-7 three-part close gate enforcement

Step 4 explicitly STOPs and surfaces if any gate fails. The gate logic is procedural — the executor runs each gate command, captures the verdict, and only authors `M033-VALIDATED` when all three pass. There is NO automated "gate-checker" script; the discipline is enforced by the executor following the step-4 procedure literally.

### `M033_SKIP_FRIENDLY_TESTER_PASS=1` fallback path (US-8 AS-5)

When the env var is declared in the close-state environment AND the friendly-tester report is absent OR shows `eligible_testers: 0`, the SC-15 gate is satisfied via signed attestation. The attestation block (step 5 / "Optional signed attestation block") MUST be inserted into `M033-SUMMARY.md` with: maintainer name, date, recruiting-outreach evidence (date the outreach was attempted), and the cold-start-risk acknowledgment text. The `M033-VALIDATED` marker text references this fallback explicitly. The summary's SC-15 row says `SIGNED-ATTESTATION` instead of `PASS`.

### `unit_close` enum extension precedent

P03/T04 already extended the JSONL emitter closed enum 11→12 (added `imported_context_loaded`). The pattern is documented and verified by `tools/verify/m033-p02-jsonl-event-schema.sh`. T05 MAY follow the same pattern to add `unit_close` 12→13 if absent. Alternatively, T05 may emit the JSONL record via `printf` direct-append (bypassing the emitter library) since this is a one-time milestone-close event, not a recurring sub-flow event. Implementation choice at execution time; the shape verifier (`m033-p05-unit-close-jsonl-shape.sh`) only checks the record's presence and field shape, not the path that wrote it.

### Path-collision check (Plan-Time Discipline rule 6)

All 8 created paths verified absent at planning time:
- `tools/verify/m033-p05-phase-suite.sh`
- `tools/verify/m033-p05-cross-phase-regression.sh`
- `tools/verify/m033-p05-scope-guard.sh`
- `tools/verify/m033-p05-validated-marker-shape.sh`
- `tools/verify/m033-p05-summary-md-shape.sh`
- `tools/verify/m033-p05-unit-close-jsonl-shape.sh`
- `.orchestrator/milestones/M033/M033-VALIDATED`
- `.orchestrator/milestones/M033/M033-SUMMARY.md`

`.orchestrator/execution-log.jsonl` is present (M001 + many milestones append to it); declared as `modify`, NOT `create`.

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

Every `## Verification` command resolves to a verifier co-authored inside this task (steps 1, 2, 3, 7, 8, 9) OR an existing framework verifier (`bash scripts/verify/validate-milestone.sh M033`). No cross-task dependency on yet-unwritten verifiers.

### Friendly-tester report path

The friendly-tester report path is `tests/m033-acceptance/friendly-tester-pass/report-<latest>.md` where `<latest>` is the lexicographically-latest filed report (e.g., `report-2026-05-08.md`). T05's step 4.2 invokes `validate-report.sh` against this path. If multiple reports are filed, the lexicographically latest wins per the protocol convention (P01/FR-19).

### Standalone-gate invariant (CON-3 / Principle XVI)

The cross-phase regression verifier (step 2) explicitly invokes `bash scripts/verify/standalone-gate.sh constitution` and asserts exit 0 — the customblock-draft surface (T01) MUST NOT introduce any `speckit.*` references. The shape verifier `m033-p05-customblock-draft-sh-shape.sh` (T01's deliverable) already asserts negative-grep for `conversus|model_routing|dispatch|claude-code.*--task` in the customblock-draft.sh body; the standalone-gate provides the cross-cutting CON-3 check across the full M033 surface.
