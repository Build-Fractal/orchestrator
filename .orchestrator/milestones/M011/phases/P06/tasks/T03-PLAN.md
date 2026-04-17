---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M011"
name: "Dogfood evidence capture + Bash 3.2 compat + command-reference-preservation regression"
depends_on: [T01, T02]
---

## Prerequisites

T01 and T02 are complete. On disk:

- `commands/ingest.md` exists, documents the three user-facing flags, names `SKIPPED:`/`SUPERSEDED:`/`REMOVED:` + `--force`, and lists `scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/rebuild-index.sh`, `scripts/state/spec-metrics.sh`, and `scripts/dispatch/scope-filter.sh` in its Reference Files block.
- `commands/evaluate.md` references `orchestrator:ingest` at least once.
- `scripts/verify/m011-p06-e2e-pipeline.sh` and `scripts/verify/m011-p06-e2e-pipeline-timing.sh` exist, are executable, and pass.
- The six T01+T02 verify scripts (`ingest-doc-structure`, `ingest-doc-conventions`, `ingest-doc-reingest-contract`, `evaluate-doc-mentions-ingest`, `e2e-pipeline`, `e2e-pipeline-timing`) all print `PASS:` and exit 0.

No dogfood evidence has been captured yet, no Bash 3.2 compat scan covers the new P06 scripts, and no regression guards the previously-listed Reference File bullets in `commands/evaluate.md` and `commands/roadmap.md`.

## Description

T03 delivers the consolidated P06 evidence capture plus two regression guards. No new production code — only evidence artifacts and verify scripts.

Three artifact groups:

1. **Evidence transcripts under `.orchestrator/milestones/M011/phases/P06/evidence/`** — capture the real-spec dogfood run against an in-repo spec (`specs/016-autonomous-hardening/spec.md` recommended; any other `specs/NNN-name/spec.md` that has not yet been ingested into the live `.orchestrator/knowledge/spec/` tree is acceptable). Capture four files:

   - `ingest-transcript.txt` — full stdout from running ingest-spec.sh against the chosen real spec. Must contain at least one `CREATED:` line.
   - `spec-metrics.txt` — stdout from `scripts/state/spec-metrics.sh` after the dogfood run. Must contain `spec_chunks_present=true`.
   - `story-ids.txt` — stdout from `scripts/dispatch/scope-filter.sh --category spec/story --graph`. Must contain at least one `SPEC-US-` line.
   - `timing.txt` — a single line `elapsed_seconds=<N>` recording wall-clock seconds for the ingest → metrics → scope-filter sequence. `N` must be strictly less than 60.

2. **`scripts/verify/m011-p06-evidence-present.sh`** — asserts the four evidence files exist under `.orchestrator/milestones/M011/phases/P06/evidence/` and contain the expected tokens (`CREATED:`, `spec_chunks_present=true`, `SPEC-US-`, `elapsed_seconds=`).

3. **Two regression guards**:

   - `scripts/verify/m011-p06-bash32-compat.sh` — Bash 3.2 structural scan across every P06-new script (`m011-p06-*.sh` verify scripts from T01, T02, and T03). Asserts `bash -n` passes and no forbidden constructs (`declare -A`, `mapfile`, `readarray`, `<(...)`) appear. Consistent with P03/P04/P05 compat-scan pattern.
   - `scripts/verify/m011-p06-commands-preserve-references.sh` — asserts every previously-listed Reference File bullet in `commands/evaluate.md` and `commands/roadmap.md` remains present after T01's evaluate.md edit. This extends the P05/T03 regression guard to include the post-P05 state (which the P05 guard already covers) plus any P06-era additions.

All three scripts print `PASS:` on success. Final P06 suite: 9 `m011-p06-*.sh` verify scripts (4 from T01, 2 from T02, 3 from T03) all green.

## Steps

### Step 1: Run the dogfood pipeline against a real in-repo spec

Pick a real spec file (recommended: `specs/016-autonomous-hardening/spec.md`). Then run the pipeline manually — this is a DOGFOOD run that exercises `orchestrator:ingest` as a human would — and capture the four evidence transcripts.

Run from the repo root:

```bash
mkdir -p .orchestrator/milestones/M011/phases/P06/evidence
```

Capture the ingest transcript. Use the LIVE project knowledge tree (no sandbox) so the evidence reflects real-world behavior. If the target spec has already been ingested, re-ingest is safe — the P03 idempotency contract ensures SKIPPED/SUPERSEDED chains, not duplication:

```bash
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/016-autonomous-hardening/spec.md \
  --slug 016-autonomous-hardening \
  > .orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt 2>&1
```

Capture the spec-metrics output:

```bash
bash scripts/state/spec-metrics.sh .orchestrator \
  > .orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt
```

Capture the story-ID list:

```bash
bash scripts/dispatch/scope-filter.sh --category spec/story --graph \
  > .orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt
```

Capture timing. Wrap the sequence in `date +%s` bookends and write a single-line record. Use a short helper script under `/tmp` to avoid compound-bash in the evidence-gathering step (AP-004 applies only to plan `Check:` lines, but keeping the evidence step script-shaped makes it reproducible):

Write `/tmp/p06-capture-timing.sh`:

```bash
#!/usr/bin/env bash
set -u
REPO="$(pwd)"
T_START="$(date +%s)"
bash "$REPO/scripts/knowledge/ingest-spec.sh" \
  --spec-path "$REPO/specs/016-autonomous-hardening/spec.md" \
  --slug 016-autonomous-hardening >/dev/null 2>&1
bash "$REPO/scripts/state/spec-metrics.sh" "$REPO/.orchestrator" >/dev/null 2>&1
bash "$REPO/scripts/dispatch/scope-filter.sh" --category spec/story --graph >/dev/null 2>&1 || true
T_END="$(date +%s)"
printf 'elapsed_seconds=%s\n' "$((T_END - T_START))"
```

Then:

```bash
chmod +x /tmp/p06-capture-timing.sh
bash /tmp/p06-capture-timing.sh > .orchestrator/milestones/M011/phases/P06/evidence/timing.txt
rm -f /tmp/p06-capture-timing.sh
```

Verify each evidence file contains its required token:

```bash
grep -c '^CREATED:' .orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt
grep -Fq 'spec_chunks_present=true' .orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt
grep -c '^SPEC-US-' .orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt
grep -E '^elapsed_seconds=[0-9]+$' .orchestrator/milestones/M011/phases/P06/evidence/timing.txt
```

All four should report non-zero / exit 0. The elapsed seconds value must be strictly less than 60.

### Step 2: Write `scripts/verify/m011-p06-evidence-present.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-evidence-present.sh
# Assert the P06 dogfood evidence transcripts exist and contain the
# expected tokens: CREATED:, spec_chunks_present=true, SPEC-US-,
# elapsed_seconds=<N< 60>.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVID="$REPO/.orchestrator/milestones/M011/phases/P06/evidence"

fail=0

check_exists() {
  local f="$1"
  if [ ! -s "$EVID/$f" ]; then
    printf 'FAIL[evidence-exists]: %s missing or empty\n' "$f"
    fail=1
  fi
}

check_exists ingest-transcript.txt
check_exists spec-metrics.txt
check_exists story-ids.txt
check_exists timing.txt

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Token checks
if ! grep -q '^CREATED:' "$EVID/ingest-transcript.txt"; then
  printf 'FAIL[ingest-transcript]: no CREATED: line found\n'
  fail=1
fi

if ! grep -Fq 'spec_chunks_present=true' "$EVID/spec-metrics.txt"; then
  printf 'FAIL[spec-metrics]: spec_chunks_present=true not found\n'
  fail=1
fi

if ! grep -q '^SPEC-US-' "$EVID/story-ids.txt"; then
  printf 'FAIL[story-ids]: no SPEC-US- line found\n'
  fail=1
fi

# Extract elapsed_seconds integer and gate on < 60.
ELAPSED_LINE="$(grep -E '^elapsed_seconds=[0-9]+$' "$EVID/timing.txt" | head -1)"
if [ -z "$ELAPSED_LINE" ]; then
  printf 'FAIL[timing]: elapsed_seconds=<N> line not found in timing.txt\n'
  fail=1
else
  ELAPSED="${ELAPSED_LINE#elapsed_seconds=}"
  if [ "$ELAPSED" -ge 60 ]; then
    printf 'FAIL[timing]: dogfood pipeline took %s seconds (expected < 60)\n' "$ELAPSED"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: P06 dogfood evidence present and within timing budget"
```

`chmod +x`.

### Step 3: Write `scripts/verify/m011-p06-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-bash32-compat.sh
# Bash 3.2 compatibility scan for every P06 verify script.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
scripts/verify/m011-p06-ingest-doc-structure.sh
scripts/verify/m011-p06-ingest-doc-conventions.sh
scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
scripts/verify/m011-p06-e2e-pipeline.sh
scripts/verify/m011-p06-e2e-pipeline-timing.sh
scripts/verify/m011-p06-evidence-present.sh
scripts/verify/m011-p06-commands-preserve-references.sh
"

fail=0

check_syntax() {
  local f="$1"
  if ! bash -n "$REPO/$f" 2>/dev/null; then
    printf 'FAIL[syntax]: %s\n' "$f"
    fail=1
  fi
}

check_no_forbidden() {
  local f="$1" path="$REPO/$f"
  # Strip comments before scanning so descriptive comments do not trip
  # the lint. Same pattern as P04/P05 compat scans.
  local tmp
  tmp="$(mktemp)"
  sed 's/#.*$//' "$path" > "$tmp"

  local pat
  for pat in 'declare -A' 'mapfile' 'readarray'; do
    if grep -q "$pat" "$tmp"; then
      printf 'FAIL[forbidden-token]: %s contains: %s\n' "$f" "$pat"
      fail=1
    fi
  done

  if grep -Eq '<\(|>\(' "$tmp"; then
    printf 'FAIL[process-substitution]: %s uses <(...) or >(...)\n' "$f"
    fail=1
  fi

  rm -f "$tmp"
}

for f in $FILES; do
  check_syntax "$f"
  check_no_forbidden "$f"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: P06 scripts are Bash 3.2 compatible"
```

`chmod +x`.

### Step 4: Write `scripts/verify/m011-p06-commands-preserve-references.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-commands-preserve-references.sh
# Regression guard: T01's edit to commands/evaluate.md must not delete
# any previously-listed Reference File bullet from evaluate.md or
# roadmap.md. Extends the P05/T03 preserved-references check to cover
# P06-era content.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

EVAL_DOC="$REPO/commands/evaluate.md"
ROAD_DOC="$REPO/commands/roadmap.md"

# These bullets match the post-P05 state of evaluate.md and roadmap.md
# exactly. T01's additive edit to evaluate.md must not drop any of them.
EVAL_REQUIRED="
templates/evaluation.md
scripts/state/read-config.sh
scripts/state/spec-metrics.sh
scripts/lifecycle/scaffold.sh
references/tier-definitions.md
references/installation.md
"

ROAD_REQUIRED="
templates/roadmap.md
scripts/state/derive-phase.sh
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
scripts/dispatch/scope-filter.sh
scripts/knowledge/spec-story-graph.sh
scripts/knowledge/traverse-graph.sh
scripts/engine/intensity-gate.sh
scripts/state/spec-metrics.sh
references/tier-definitions.md
scripts/verify/check-boundary-map.sh
references/state-machine.md
"

fail=0

check_doc() {
  local doc="$1" label="$2" patterns="$3"
  local p
  for p in $patterns; do
    if ! grep -Fq "$p" "$doc"; then
      printf 'FAIL[%s]: missing reference: %s\n' "$label" "$p"
      fail=1
    fi
  done
}

check_doc "$EVAL_DOC" evaluate.md "$EVAL_REQUIRED"
check_doc "$ROAD_DOC" roadmap.md "$ROAD_REQUIRED"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: evaluate.md and roadmap.md preserve all prior Reference File bullets"
```

`chmod +x`.

### Step 5: Run the full P06 verify suite

```
bash scripts/verify/m011-p06-ingest-doc-structure.sh
bash scripts/verify/m011-p06-ingest-doc-conventions.sh
bash scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
bash scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
bash scripts/verify/m011-p06-e2e-pipeline.sh
bash scripts/verify/m011-p06-e2e-pipeline-timing.sh
bash scripts/verify/m011-p06-evidence-present.sh
bash scripts/verify/m011-p06-bash32-compat.sh
bash scripts/verify/m011-p06-commands-preserve-references.sh
```

All 9 must print `PASS:` and exit 0. Then sanity-check the upstream P05 suite is still green (T01's evaluate.md edit touches a shared file):

```
bash scripts/verify/m011-p05-commands-preserve-references.sh
bash scripts/verify/m011-p05-demo-scenario.sh
bash scripts/verify/m011-p05-evaluate-doc-references-metrics.sh
```

All three must still PASS. If any fails, the T01 evaluate.md edit introduced a regression — revert the edit and tune T01's insertion point rather than changing T03's guard thresholds.

## Must-Haves

- `.orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt` exists and contains at least one `CREATED:` line.
- `.orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt` exists and contains `spec_chunks_present=true`.
- `.orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt` exists and contains at least one `SPEC-US-` line.
- `.orchestrator/milestones/M011/phases/P06/evidence/timing.txt` exists, contains a single `elapsed_seconds=<N>` line with `N < 60`.
- `scripts/verify/m011-p06-evidence-present.sh` exists, executable, passes.
- `scripts/verify/m011-p06-bash32-compat.sh` exists, executable, scans all 8 other P06 verify scripts, passes.
- `scripts/verify/m011-p06-commands-preserve-references.sh` exists, executable, asserts preserved bullets in evaluate.md and roadmap.md, passes.
- All 9 `scripts/verify/m011-p06-*.sh` scripts collectively PASS.
- P05 regression suite (`m011-p05-commands-preserve-references.sh`, `m011-p05-demo-scenario.sh`, `m011-p05-evaluate-doc-references-metrics.sh`) still PASS.

## Verification

```
bash scripts/verify/m011-p06-evidence-present.sh
bash scripts/verify/m011-p06-bash32-compat.sh
bash scripts/verify/m011-p06-commands-preserve-references.sh
bash scripts/verify/m011-p05-commands-preserve-references.sh
bash scripts/verify/m011-p05-demo-scenario.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `commands/ingest.md` (from T01) — referenced by verify scripts via its path; no API consumed directly in T03.
- `commands/evaluate.md` (modified by T01) — must contain `orchestrator:ingest` and retain all prior Reference File bullets.
- `scripts/verify/m011-p06-ingest-doc-structure.sh`, `m011-p06-ingest-doc-conventions.sh`, `m011-p06-ingest-doc-reingest-contract.sh`, `m011-p06-evaluate-doc-mentions-ingest.sh` (from T01) — scanned by the Bash 3.2 compat script; must already pass Bash 3.2 compat at the time T03 runs.
- `scripts/verify/m011-p06-e2e-pipeline.sh` (from T02) — Key API: invoked by CI-style runs; scanned by Bash 3.2 compat script.
- `scripts/verify/m011-p06-e2e-pipeline-timing.sh` (from T02) — Key API: prints `elapsed_seconds=<N>` to stdout; scanned by Bash 3.2 compat script.

### From Disk (Pre-existing)

- `scripts/knowledge/ingest-spec.sh` — invoked during the dogfood run to produce `ingest-transcript.txt`.
- `scripts/state/spec-metrics.sh` — invoked during the dogfood run to produce `spec-metrics.txt`.
- `scripts/dispatch/scope-filter.sh` — invoked during the dogfood run to produce `story-ids.txt`.
- `specs/016-autonomous-hardening/spec.md` (or equivalent in-repo spec) — input to the dogfood run.
- `scripts/verify/m011-p05-commands-preserve-references.sh`, `m011-p05-demo-scenario.sh`, `m011-p05-evaluate-doc-references-metrics.sh` — P05 regression scripts; invoked but not modified.

## Constraints

- Bash 3.2 compatible for all three new verify scripts (no `declare -A`, `<(...)`, `mapfile`, `readarray`).
- AD-19 / AP-004 discipline for plan `Check:` lines — single-script-file shape only (already satisfied).
- No new production code in T03. If the dogfood evidence capture fails (e.g., `ingest-transcript.txt` has zero `CREATED:` lines), fix T01/T02 or the upstream P03/P05 scripts — do not adjust T03's thresholds.
- Do NOT modify `commands/ingest.md`, `commands/evaluate.md`, `commands/roadmap.md`, `scripts/knowledge/ingest-spec.sh`, `scripts/state/spec-metrics.sh`, `scripts/dispatch/scope-filter.sh`, or any T01/T02 verify script in this task.
- Do NOT touch P03, P04, or P05 verify scripts — those are frozen.
- The evidence-capture step (Step 1) writes into the LIVE `.orchestrator/` tree — this is intentional, to dogfood the real system. If the target spec produces no chunks (e.g., spec is structurally empty), pick a different in-repo spec that does produce chunks; do not fake evidence.
- Do NOT introduce a runtime dependency on `jq` or `python3`.
- The timing threshold is `< 60` (strict less-than). Do NOT change this — it is the P06 demo-sentence success criterion.

## Expected Output

- `.orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt` (create).
- `.orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt` (create).
- `.orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt` (create).
- `.orchestrator/milestones/M011/phases/P06/evidence/timing.txt` (create, single line `elapsed_seconds=<N>` with N < 60).
- `scripts/verify/m011-p06-evidence-present.sh` (create, ~60 lines, executable).
- `scripts/verify/m011-p06-bash32-compat.sh` (create, ~55 lines, executable).
- `scripts/verify/m011-p06-commands-preserve-references.sh` (create, ~60 lines, executable).
- All 9 P06 verify scripts collectively PASS.
- P05 regression suite still PASS.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P06 --task T03 \
  --provides "P06 dogfood evidence transcripts (ingest-transcript.txt, spec-metrics.txt, story-ids.txt, timing.txt), m011-p06-evidence-present.sh token gate, m011-p06-bash32-compat.sh scan across all 8 other P06 verify scripts, m011-p06-commands-preserve-references.sh regression guarding prior Reference File bullets" \
  --requires "T01 commands/ingest.md + commands/evaluate.md edit, T02 m011-p06-e2e-pipeline.sh + m011-p06-e2e-pipeline-timing.sh, P03 ingest-spec.sh, P05 spec-metrics.sh, P04 scope-filter.sh, an in-repo real spec for the dogfood run" \
  --affects "P06 phase verification closes with all 9 m011-p06-*.sh PASS plus P05 regression still PASS; M011 ready to close at milestone level" \
  --key-files ".orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt, .orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt, .orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt, .orchestrator/milestones/M011/phases/P06/evidence/timing.txt, scripts/verify/m011-p06-evidence-present.sh, scripts/verify/m011-p06-bash32-compat.sh, scripts/verify/m011-p06-commands-preserve-references.sh" \
  --verification-result pass \
  --body="T03 dogfoods the full orchestrator:ingest → orchestrator:evaluate → orchestrator:roadmap pipeline against a real in-repo spec, captures four evidence transcripts (ingest output, spec-metrics output, story IDs, timing), and lands three regression guards: evidence-present token gate, Bash 3.2 compat scan across all 8 other P06 verify scripts, and command-reference-preservation for evaluate.md + roadmap.md. All 9 P06 verify scripts pass collectively; P05 regression suite still PASS. No production code changes."
```
