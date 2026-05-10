---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M011"
name: "End-to-end demo-scenario + Bash 3.2 compat + command-reference-preservation regression for P05"
depends_on: [T01, T02]
---

## Prerequisites

T01 and T02 are complete. The following behaviors are on disk:

- `scripts/state/spec-metrics.sh <orch_root>` emits the seven documented key=value lines (`spec_chunks_present`, `story_count`, `requirement_count`, `acceptance_count`, `constraint_count`, `nfr_count`, `non_goal_count`) and counts only non-superseded tips.
- `scripts/knowledge/spec-story-graph.sh <orch_root>` emits `<SPEC-US-ID>|<comma-sep deps>` lines for each non-superseded story, with edges traced via `traverse-graph.sh` delegation.
- `scripts/engine/intensity-gate.sh --stage roadmap --intensity {Quick|Standard|Full}` emits the documented substep sets.
- `commands/evaluate.md` references `scripts/state/spec-metrics.sh` and documents the Chunks-first / Raw-spec fallback switch plus the `metrics_source` evaluation field.
- `commands/roadmap.md` references `scripts/dispatch/scope-filter.sh`, `scripts/knowledge/spec-story-graph.sh`, `scripts/knowledge/traverse-graph.sh`, `scripts/engine/intensity-gate.sh`, and `scripts/state/spec-metrics.sh`, and documents the chunks-first decomposition + intensity-aware interaction patterns.
- Eight T01+T02 verify scripts are present under `scripts/verify/m011-p05-*.sh` and pass.

No consolidated end-to-end demo exists yet, no Bash 3.2 compat scan covers the new scripts, and no regression script guards the previously-listed Reference File bullets in `evaluate.md` / `roadmap.md`.

## Description

T03 delivers the P05 demo-scenario verification and the regression guards. No new production code lands — only verify scripts.

Three verify scripts:

1. **`m011-p05-demo-scenario.sh`** — builds a rich fixture with 3 stories (one `relates_to` another), 8 requirements, 5 acceptances, 2 constraints, 1 non-goal; rebuilds the knowledge index; asserts `spec-metrics.sh` reports the expected counts AND `spec-story-graph.sh` emits the expected dependency edges. Reproduces the P05 demo sentence literally.

2. **`m011-p05-bash32-compat.sh`** — Bash 3.2 structural scan across every P05 new/modified script. Asserts `bash -n` passes and no forbidden constructs (`declare -A`, `mapfile`, `readarray`, `<(...)`) appear.

3. **`m011-p05-commands-preserve-references.sh`** — asserts every previously-listed Reference File bullet in `commands/evaluate.md` and `commands/roadmap.md` remains present after T01/T02's edits. This catches an accidental deletion during editing.

All three scripts print `PASS:` on success. The full P05 suite should then comprise 11 `m011-p05-*.sh` verify scripts (3 from T01, 5 from T02, 3 from T03) that pass collectively.

## Steps

### Step 1: Write `scripts/verify/m011-p05-demo-scenario.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-demo-scenario.sh
# End-to-end P05 demo scenario: a fixture with 3 stories, 8 requirements,
# 5 acceptances, 2 constraints, 1 non-goal, one story->story relates_to
# edge. Assert spec-metrics.sh counts match and spec-story-graph.sh
# emits the expected depends_on edges.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/story"
mkdir -p "$FIXTURE/knowledge/spec/requirement"
mkdir -p "$FIXTURE/knowledge/spec/acceptance"
mkdir -p "$FIXTURE/knowledge/spec/constraint"
mkdir -p "$FIXTURE/knowledge/spec/non-goal"

write_chunk() {
  # write_chunk <path> <category> <relates> <superseded_by>
  local path="$1" cat="$2" rel="$3" sby="$4"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'id: "%s"\n' "$(basename "$path" .md)"
    printf 'category: "%s"\n' "$cat"
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: %s\n' "$rel"
    printf 'scope_tags: "[project]"\n'
    printf -- '---\n\nbody stub\n'
  } > "$path"
}

# 3 stories; US-003 relates_to US-001
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-001.md" spec/story "[]"           ""
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-002.md" spec/story "[]"           ""
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-003.md" spec/story "[SPEC-US-001]" ""

# 8 requirements (non-superseded tips)
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-003.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-004.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-005.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-006.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-007.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-008.md" spec/requirement "[]" ""

# 5 acceptances
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-001.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-002.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-003.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-004.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-005.md" spec/acceptance "[]" ""

# 2 constraints
write_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-001.md" spec/constraint "[]" ""
write_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-002.md" spec/constraint "[]" ""

# 1 non-goal
write_chunk "$FIXTURE/knowledge/spec/non-goal/SPEC-NG-001.md" spec/non-goal "[]" ""

# Rebuild the knowledge index (populates knowledge.db + KNOWLEDGE-INDEX.md)
PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1 || true

# --- Assertion block A: spec-metrics.sh counts ---
OUT_METRICS="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check_metric() {
  local key="$1" expect="$2"
  local got
  got="$(printf '%s\n' "$OUT_METRICS" | awk -F= -v k="$key" '$1==k {print $2; exit}')"
  if [ "$got" != "$expect" ]; then
    printf 'FAIL[metrics]: %s expected=%s got=%s\n' "$key" "$expect" "$got"
    exit 1
  fi
}

check_metric spec_chunks_present true
check_metric story_count 3
check_metric requirement_count 8
check_metric acceptance_count 5
check_metric constraint_count 2
check_metric nfr_count 0
check_metric non_goal_count 1

# --- Assertion block B: spec-story-graph.sh edges ---
OUT_GRAPH="$(bash "$REPO/scripts/knowledge/spec-story-graph.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check_graph_line() {
  local expect="$1"
  if ! printf '%s\n' "$OUT_GRAPH" | grep -Fxq "$expect"; then
    printf 'FAIL[graph]: missing line: %s\n' "$expect"
    printf 'Actual output:\n%s\n' "$OUT_GRAPH"
    exit 1
  fi
}

check_graph_line "SPEC-US-001|"
check_graph_line "SPEC-US-002|"
check_graph_line "SPEC-US-003|SPEC-US-001"

echo "PASS: P05 demo scenario — metrics and story-graph match expectations"
```

`chmod +x`.

### Step 2: Write `scripts/verify/m011-p05-bash32-compat.sh`

Scan every P05-new-or-modified script for Bash 3.2 violations.

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-bash32-compat.sh
# Bash 3.2 compatibility scan for all scripts P05 created or modified.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
scripts/state/spec-metrics.sh
scripts/knowledge/spec-story-graph.sh
scripts/engine/intensity-gate.sh
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
  # Strip comments before scanning so a descriptive comment does not
  # trigger the lint (pattern consistent with P04 bash32-compat scan).
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

  # Process substitution: <(...) or >(...). Match the literal token with fgrep.
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

echo "PASS: P05 scripts are Bash 3.2 compatible"
```

### Step 3: Write `scripts/verify/m011-p05-commands-preserve-references.sh`

Assert every previously-listed Reference File bullet remains in `commands/evaluate.md` and `commands/roadmap.md`.

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-commands-preserve-references.sh
# Regression guard: T01/T02 edits must not delete any previously-listed
# Reference File bullet from evaluate.md or roadmap.md.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

EVAL_DOC="$REPO/commands/evaluate.md"
ROAD_DOC="$REPO/commands/roadmap.md"

EVAL_REQUIRED="
templates/evaluation.md
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
references/tier-definitions.md
references/installation.md
"

ROAD_REQUIRED="
templates/roadmap.md
scripts/state/derive-phase.sh
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
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

### Step 4: Run the full P05 verify suite

After the three scripts are created and executable, run the complete suite to confirm no regression from T01 or T02:

```
bash scripts/verify/m011-p05-spec-metrics-counts.sh
bash scripts/verify/m011-p05-spec-metrics-skips-superseded.sh
bash scripts/verify/m011-p05-evaluate-doc-references-metrics.sh
bash scripts/verify/m011-p05-spec-story-graph-emits-deps.sh
bash scripts/verify/m011-p05-spec-story-graph-delegates.sh
bash scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh
bash scripts/verify/m011-p05-roadmap-doc-references-chunks.sh
bash scripts/verify/m011-p05-roadmap-doc-references-intensity.sh
bash scripts/verify/m011-p05-demo-scenario.sh
bash scripts/verify/m011-p05-bash32-compat.sh
bash scripts/verify/m011-p05-commands-preserve-references.sh
```

All 11 must print `PASS:` and exit 0.

Run a sanity check against the P04 regression suite as well, since T02's edit to `intensity-gate.sh` touches a shared file. The P04 bash32-compat scan already guards its three scripts:

```
bash scripts/verify/m011-p04-demo-scenario.sh
bash scripts/verify/m011-p04-bash32-compat.sh
```

Both must still PASS. If they fail, the T02 intensity-gate edit introduced a regression — fix T02, not T03.

## Must-Haves

- `scripts/verify/m011-p05-demo-scenario.sh` builds the P05 fixture, invokes both `spec-metrics.sh` and `spec-story-graph.sh`, and asserts the documented counts and edges.
- `scripts/verify/m011-p05-bash32-compat.sh` scans `scripts/state/spec-metrics.sh`, `scripts/knowledge/spec-story-graph.sh`, and `scripts/engine/intensity-gate.sh` for syntax and forbidden constructs.
- `scripts/verify/m011-p05-commands-preserve-references.sh` checks every previously-listed Reference File bullet in both `commands/evaluate.md` and `commands/roadmap.md` remains present.
- All 11 `scripts/verify/m011-p05-*.sh` scripts print `PASS:` and exit 0.
- The P04 regression suite (`m011-p04-demo-scenario.sh`, `m011-p04-bash32-compat.sh`) still PASSes.

## Verification

```
bash scripts/verify/m011-p05-demo-scenario.sh
bash scripts/verify/m011-p05-bash32-compat.sh
bash scripts/verify/m011-p05-commands-preserve-references.sh
bash scripts/verify/m011-p04-demo-scenario.sh
bash scripts/verify/m011-p04-bash32-compat.sh
```

## Inputs

### From Previous Tasks

- `scripts/state/spec-metrics.sh` (from T01)
  - Key API: `spec-metrics.sh <orch_root>` emits 7 key=value lines including `spec_chunks_present`, `story_count`, `requirement_count`, `acceptance_count`, `constraint_count`, `nfr_count`, `non_goal_count`.
  - Counts non-superseded tips only.
- `scripts/knowledge/spec-story-graph.sh` (from T02)
  - Key API: `spec-story-graph.sh <orch_root>` emits `<SPEC-US-ID>|<comma-sep deps>` one per non-superseded story. Empty RHS for stories with no story→story edges.
  - Delegates edge lookup to `traverse-graph.sh`.
- `scripts/engine/intensity-gate.sh` (modified by T02)
  - Key API: `intensity-gate.sh --stage roadmap --intensity {Quick|Standard|Full}` emits substeps. Existing stages unchanged.
- `commands/evaluate.md` (modified by T01)
  - Must contain: `scripts/state/spec-metrics.sh` reference, `spec_chunks_present` keyword, `metrics_source` field, `Chunks-first path` and `Raw-spec fallback` headings.
- `commands/roadmap.md` (modified by T02)
  - Must contain: `spec/story`, `spec-story-graph.sh`, `scope-filter.sh`, `traverse-graph.sh`, `Chunks-first path`, `Raw-spec fallback`, `intensity-gate.sh --stage roadmap`, `single-pass`, `collaborative-loop`, `speckit.orchestrator.discuss` references.

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` — invoked to populate `knowledge.db` in the demo-scenario fixture so that `spec-story-graph.sh` can find edges via `traverse-graph.sh`.
- `scripts/knowledge/traverse-graph.sh` — indirect dependency via `spec-story-graph.sh`.
- `scripts/verify/m011-p04-demo-scenario.sh` and `scripts/verify/m011-p04-bash32-compat.sh` — P04 regression scripts; invoked but not modified.

## Constraints

- Bash 3.2 compatible for all three new verify scripts themselves.
- AD-19 discipline for the phase-plan `Check:` commands — single-script-file shape only (already satisfied).
- AP-004 compliance in executor's Bash tool calls — the `Verification` block lists commands one per line, each a single `bash scripts/verify/*.sh` invocation.
- No new production code lands in T03. If the demo-scenario test fails, fix T01 or T02, not T03 — T03 codifies behavior, it does not implement it.
- Do NOT modify `commands/evaluate.md`, `commands/roadmap.md`, `scripts/state/spec-metrics.sh`, `scripts/knowledge/spec-story-graph.sh`, or `scripts/engine/intensity-gate.sh` in this task.
- Do NOT touch any P04 verify scripts — those are frozen.
- The demo-scenario script MUST clean up its sandbox via `trap 'rm -rf "$FIXTURE"' EXIT` so repeated runs do not leak `/tmp` state.
- Do NOT introduce a runtime dependency on `jq` or `python3`.

## Expected Output

- `scripts/verify/m011-p05-demo-scenario.sh` (create, ~100 lines, executable).
- `scripts/verify/m011-p05-bash32-compat.sh` (create, ~60 lines, executable).
- `scripts/verify/m011-p05-commands-preserve-references.sh` (create, ~55 lines, executable).
- All 11 P05 verify scripts collectively print `PASS:` and exit 0.
- P04 regression scripts (`m011-p04-demo-scenario.sh`, `m011-p04-bash32-compat.sh`) still PASS.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P05 --task T03 \
  --provides "m011-p05-demo-scenario.sh end-to-end, m011-p05-bash32-compat.sh scan, m011-p05-commands-preserve-references.sh regression" \
  --requires "T01 spec-metrics.sh, T02 spec-story-graph.sh + intensity-gate roadmap stage, P04 regression suite stability" \
  --affects "P05 phase verification closes, M011 continues to P06" \
  --key-files "scripts/verify/m011-p05-demo-scenario.sh, scripts/verify/m011-p05-bash32-compat.sh, scripts/verify/m011-p05-commands-preserve-references.sh" \
  --verification-result pass \
  --body="T03 delivers the P05 demo-scenario end-to-end (3 stories, 8 requirements, 5 acceptances, 2 constraints, 1 non-goal; US-003 relates_to US-001), a Bash 3.2 compat scan over the three new/modified P05 scripts, and a command-reference-preservation regression guarding the existing Reference File bullets in evaluate.md and roadmap.md. All 11 P05 verify scripts pass collectively; P04 regression still PASS. No production code changes in T03."
```
