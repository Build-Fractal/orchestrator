---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M011"
name: "Add spec-metrics.sh helper and wire commands/evaluate.md to consume ingested spec chunks with raw-spec fallback"
depends_on: []
---

## Prerequisites

P01–P04 are complete. Key interfaces this task depends on:

- `knowledge/spec/<cat>/<SPEC-XX-NNN>.md` chunks exist (when ingest has run) with YAML frontmatter containing `category:`, `superseded_by:`, `relates_to:`, and `scope_tags:` fields. Categories are `spec/story`, `spec/requirement`, `spec/acceptance`, `spec/constraint`, `spec/nfr`, `spec/non-goal`. Shape established in P02/P03.
- `scripts/dispatch/scope-filter.sh` supports `--category <cat> --graph` mode that queries `knowledge.db` and emits matching entry IDs. Extended in P04 to handle `spec/*` categories. Superseded-tip filtering is applied in graph mode per P04/T03.
- `scripts/knowledge/rebuild-index.sh` populates `knowledge.db` via a nested scan reaching `knowledge/spec/<cat>/<id>.md` (P01).
- `knowledge.db` lives at `<orch_root>/.knowledge/knowledge.db` or `<project_root>/.knowledge/knowledge.db` depending on resolver configuration.
- `scripts/knowledge/lib/graph-db.sh` exposes sqlite helpers; sourcing is guarded by `_GRAPH_DB_SOURCED`.
- `commands/evaluate.md` (~185 lines today) documents the current scope-analysis flow: it reads the raw spec and counts user stories / AC / FR via regex inspection.

No spec-chunk consumption path exists in the evaluate command or in any central state helper today — evaluate re-parses the raw spec on every run.

## Description

Deliver the evaluate side of P05:

1. **`scripts/state/spec-metrics.sh`** (new) — count ingested spec chunks by category, skipping superseded tips. Emits a stable key=value block to stdout that evaluate (and downstream commands) can parse without reopening `knowledge.db` themselves. When no `spec/*` entries exist, reports `spec_chunks_present=false` with all counts at `0`.

2. **`commands/evaluate.md`** (modify) — document the chunks-first metric path with graceful fallback to the existing raw-spec regex path. Add `scripts/state/spec-metrics.sh` to the "Reference Files" block. Do NOT remove any existing reference or change the Tier A/B/C decision table — the chunks path is a metric-source switch, not a tier-rule change.

3. **Verify scripts** — three scripts that certify the helper's contract and the documentation wiring.

The key invariant: when no spec has been ingested, `evaluate` behaves exactly as it does today. When a spec has been ingested, `evaluate`'s metric section reports counts derived from chunk enumeration instead of regex on the raw file, and the source-of-metrics is recorded in the evaluation output (`metrics_source: spec_chunks` vs `metrics_source: raw_spec`).

## Steps

### Step 1: Create `scripts/state/spec-metrics.sh`

Write a new script with the header and behavior below. Bash 3.2 compatible; no `declare -A`, `mapfile`, `readarray`, `<(...)`.

```bash
#!/usr/bin/env bash
# scripts/state/spec-metrics.sh — Count ingested spec chunks by category.
#
# Usage: spec-metrics.sh <orch_root>
#   <orch_root> — path to the .orchestrator/ tree (or any path whose
#                 project root contains knowledge/spec/).
#
# Output (stdout, key=value lines):
#   spec_chunks_present=true|false
#   story_count=N
#   requirement_count=N
#   acceptance_count=N
#   constraint_count=N
#   nfr_count=N
#   non_goal_count=N
#
# Counts are non-superseded tips only — chunks whose frontmatter
# `superseded_by:` field is non-empty are excluded.
#
# Exit 0 on success (including the "no chunks present" case).
# Exit 1 on missing argument.
#
# Bash 3.2 compatible (MEM001).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "spec-metrics.sh: requires <orch_root>" >&2
  exit 1
fi

ORCH_ROOT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve the knowledge root. Precedence:
# 1. <orch_root>/../knowledge/spec (repo layout where .orchestrator/ is a sibling of knowledge/)
# 2. <project-root>/knowledge/spec (resolved via SCRIPT_DIR parent)
KNOWLEDGE_SPEC=""
if [ -d "${ORCH_ROOT}/../knowledge/spec" ]; then
  KNOWLEDGE_SPEC="$(cd "${ORCH_ROOT}/../knowledge/spec" && pwd)"
elif [ -d "${PROJECT_ROOT}/knowledge/spec" ]; then
  KNOWLEDGE_SPEC="${PROJECT_ROOT}/knowledge/spec"
fi

count_category() {
  # count_category <cat-dir-name> — count *.md files whose frontmatter
  # `superseded_by:` is empty or missing.
  local cat_dir="$1"
  local dir="${KNOWLEDGE_SPEC}/${cat_dir}"
  local n=0
  if [ ! -d "$dir" ]; then
    echo 0
    return 0
  fi
  local f sby
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    # Extract superseded_by value from frontmatter (first match wins)
    sby="$(awk '
      /^---$/ { c++; if (c==2) exit; next }
      c==1 && /^superseded_by:/ {
        sub(/^superseded_by:[[:space:]]*/, "")
        gsub(/"/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        print
        exit
      }
    ' "$f" 2>/dev/null)"
    if [ -z "$sby" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

STORY="$(count_category story)"
REQUIREMENT="$(count_category requirement)"
ACCEPTANCE="$(count_category acceptance)"
CONSTRAINT="$(count_category constraint)"
NFR="$(count_category nfr)"
NONGOAL="$(count_category non-goal)"

TOTAL=$((STORY + REQUIREMENT + ACCEPTANCE + CONSTRAINT + NFR + NONGOAL))
if [ "$TOTAL" -gt 0 ]; then
  echo "spec_chunks_present=true"
else
  echo "spec_chunks_present=false"
fi

echo "story_count=${STORY}"
echo "requirement_count=${REQUIREMENT}"
echo "acceptance_count=${ACCEPTANCE}"
echo "constraint_count=${CONSTRAINT}"
echo "nfr_count=${NFR}"
echo "non_goal_count=${NONGOAL}"
```

Make it executable: `chmod +x scripts/state/spec-metrics.sh`.

Design notes:

- The function uses plain `awk` on each file (not a bulk SQL query) because the scale is small (<500 chunks in realistic specs) and to avoid a hard dependency on the `knowledge.db` already being rebuilt — evaluate runs early, possibly before the first rebuild-index call.
- `superseded_by:` with an empty value (either `superseded_by:` alone or `superseded_by: ""`) is treated as "current tip". Any non-empty value means "superseded".
- The `count_category` helper name avoids collision with shell builtins. It prints the count to stdout and is captured with `$(...)` — no pipes inside.
- `for f in "$dir"/*.md` plus `[ -e "$f" ] || continue` safely handles empty directories in Bash 3.2 without nullglob.

### Step 2: Update `commands/evaluate.md`

Insert a new "Spec Chunk Metrics (when present)" subsection inside the existing "Scope Analysis" section (between the current step 2 and step 3), and add one line to "Reference Files". Keep all existing content intact.

Exact edits:

**Edit 1** — in the "Scope Analysis" section, replace the current step 2 bullet block:

```markdown
2. **Count structural elements**:
   - Number of user stories (sections with "As a…" or "US-" prefixed items)
   - Number of acceptance scenarios (AC items, "Given/When/Then" blocks)
   - Number of functional requirements (FR-### items or numbered requirements)
```

With:

```markdown
2. **Count structural elements**. Prefer ingested spec chunks over regex; fall back to regex if no chunks exist:

   **Chunks-first path** (when a spec has been ingested via `orchestrator:ingest`):

   ```bash
   bash scripts/state/spec-metrics.sh <orch-root>
   ```

   Parse the `key=value` lines from stdout. If `spec_chunks_present=true`, use `story_count`, `requirement_count`, and `acceptance_count` directly and record `metrics_source: spec_chunks` in the evaluation output. Non-goals are counted (`non_goal_count`) but do NOT contribute to tier classification.

   **Raw-spec fallback** (when `spec_chunks_present=false`):

   - Number of user stories (sections with "As a…" or "US-" prefixed items)
   - Number of acceptance scenarios (AC items, "Given/When/Then" blocks)
   - Number of functional requirements (FR-### items or numbered requirements)

   Record `metrics_source: raw_spec` in the evaluation output.
```

**Edit 2** — in the evaluation-output template description (step 2 of "Tier B or C Result"), append one bullet to the list of evaluation fields:

```markdown
- `metrics_source`: `spec_chunks` (counts came from ingested chunks) or `raw_spec` (counts came from regex on the raw spec)
```

Insert it immediately after the existing `- Complexity factors: ...` bullet.

**Edit 3** — append one bullet to the "Reference Files" section at the bottom:

```markdown
- `scripts/state/spec-metrics.sh` — counts ingested spec chunks by category; used when a spec has been ingested via `orchestrator:ingest`
```

Place it between the existing `scripts/state/read-config.sh` bullet and the `scripts/lifecycle/scaffold.sh` bullet (so the script bullets stay grouped).

**Do not remove** any existing bullet, heading, or reference — the regression verify script (T03) asserts that every previously listed Reference File remains.

### Step 3: Write `scripts/verify/m011-p05-spec-metrics-counts.sh`

Build a sandbox fixture and assert `spec-metrics.sh` emits the expected counts.

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-metrics-counts.sh
# Verify spec-metrics.sh counts non-superseded tips by category.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/story"
mkdir -p "$FIXTURE/knowledge/spec/requirement"
mkdir -p "$FIXTURE/knowledge/spec/acceptance"
mkdir -p "$FIXTURE/knowledge/spec/constraint"
mkdir -p "$FIXTURE/knowledge/spec/nfr"
mkdir -p "$FIXTURE/knowledge/spec/non-goal"

make_chunk() {
  # make_chunk <path> <category> <superseded_by>
  local path="$1" cat="$2" sby="$3"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'id: "%s"\n' "$(basename "$path" .md)"
    printf 'category: "%s"\n' "$cat"
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: []\n'
    printf 'scope_tags: "[project]"\n'
    printf -- '---\n\n'
    printf 'body stub\n'
  } > "$path"
}

make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-001.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-002.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-003.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001.md" spec/requirement ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md" spec/requirement ""
make_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-001.md"  spec/acceptance ""
make_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-001.md" spec/constraint ""
make_chunk "$FIXTURE/knowledge/spec/non-goal/SPEC-NG-001.md"    spec/non-goal   ""

OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check() {
  local key="$1" expect="$2"
  local got
  got="$(printf '%s\n' "$OUT" | awk -F= -v k="$key" '$1==k {print $2; exit}')"
  if [ "$got" != "$expect" ]; then
    printf 'FAIL: %s expected=%s got=%s\n' "$key" "$expect" "$got"
    exit 1
  fi
}

check spec_chunks_present true
check story_count 3
check requirement_count 2
check acceptance_count 1
check constraint_count 1
check nfr_count 0
check non_goal_count 1

echo "PASS: spec-metrics counts match fixture"
```

`chmod +x` the script.

### Step 4: Write `scripts/verify/m011-p05-spec-metrics-skips-superseded.sh`

Assert superseded tips are excluded.

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-metrics-skips-superseded.sh

set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/requirement"

make_chunk() {
  local path="$1" sby="$2"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'category: "spec/requirement"\n'
    printf 'superseded_by: "%s"\n' "$sby"
    printf -- '---\n\nbody\n'
  } > "$path"
}

make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001-v1.md" "SPEC-FR-001-v2"
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001-v2.md" ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md"    ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-003.md"    ""

OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"
got="$(printf '%s\n' "$OUT" | awk -F= '$1=="requirement_count"{print $2; exit}')"

if [ "$got" != "3" ]; then
  printf 'FAIL: requirement_count expected=3 got=%s\n' "$got"
  exit 1
fi

# Verify chunks_present also true
present="$(printf '%s\n' "$OUT" | awk -F= '$1=="spec_chunks_present"{print $2; exit}')"
if [ "$present" != "true" ]; then
  printf 'FAIL: spec_chunks_present expected=true got=%s\n' "$present"
  exit 1
fi

echo "PASS: superseded tips excluded"
```

### Step 5: Write `scripts/verify/m011-p05-evaluate-doc-references-metrics.sh`

Assert `commands/evaluate.md` contains the new references.

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-evaluate-doc-references-metrics.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/evaluate.md"

if ! grep -q "scripts/state/spec-metrics.sh" "$DOC"; then
  echo "FAIL: evaluate.md missing reference to scripts/state/spec-metrics.sh"
  exit 1
fi

if ! grep -q "spec_chunks_present" "$DOC"; then
  echo "FAIL: evaluate.md missing spec_chunks_present key description"
  exit 1
fi

if ! grep -q "metrics_source" "$DOC"; then
  echo "FAIL: evaluate.md missing metrics_source evaluation-field description"
  exit 1
fi

if ! grep -q "Chunks-first path" "$DOC"; then
  echo "FAIL: evaluate.md missing Chunks-first path heading"
  exit 1
fi

if ! grep -q "Raw-spec fallback" "$DOC"; then
  echo "FAIL: evaluate.md missing Raw-spec fallback heading"
  exit 1
fi

echo "PASS: evaluate.md references spec-metrics.sh path and keys"
```

## Must-Haves

- `scripts/state/spec-metrics.sh` exists and emits the seven documented `key=value` lines on stdout.
- `spec-metrics.sh` counts only non-superseded tips per category.
- `commands/evaluate.md` describes the chunks-first path with `spec-metrics.sh`, the `Raw-spec fallback` behavior, and the `metrics_source` evaluation field.
- `commands/evaluate.md` "Reference Files" block includes `scripts/state/spec-metrics.sh`.
- Previously listed evaluate.md references (`templates/evaluation.md`, `scripts/state/read-config.sh`, `scripts/lifecycle/scaffold.sh`, `references/tier-definitions.md`, `references/installation.md`) remain present.
- The three T01 verify scripts print `PASS:` and exit 0.

## Verification

```
bash scripts/verify/m011-p05-spec-metrics-counts.sh
bash scripts/verify/m011-p05-spec-metrics-skips-superseded.sh
bash scripts/verify/m011-p05-evaluate-doc-references-metrics.sh
```

## Inputs

### From Previous Tasks

- None (T01 has no upstream P05 tasks).

### From Disk (Pre-existing)

- `scripts/dispatch/scope-filter.sh` — reference for the `--category <cat> --graph` contract that spec-metrics.sh could alternatively delegate to. T01 uses awk-on-files instead to avoid a hard `knowledge.db` dependency; if a future refactor wants to switch to SQL, the `scope-filter.sh --category spec/<cat> --graph` command emits entry IDs on stdout. Not invoked by this task.
- `scripts/knowledge/rebuild-index.sh` — existing script; not invoked here.
- `scripts/knowledge/lib/graph-db.sh` — existing library; not sourced here.
- `commands/evaluate.md` — 185-line existing doc. Modified in Step 2.
- `knowledge/spec/<cat>/*.md` — ingested chunks (P02/P03 output). Only frontmatter `superseded_by:` is read.
- Frontmatter contract from P02:
  - `category: "spec/<type>"` (one of story|requirement|acceptance|constraint|nfr|non-goal)
  - `superseded_by: ""` on current tips, populated SPEC-* ID on superseded revisions
  - `relates_to: [...]` (YAML list; not used in T01)

## Constraints

- Bash 3.2 compatible: no `declare -A`, `mapfile`, `readarray`, or `<(...)` in `spec-metrics.sh` or the verify scripts.
- AD-19 discipline for the phase-plan `Check:` commands — already satisfied by the single-script-file shape used in all truths.
- AP-004 compliance in execution-agent bash calls: no `$(...)` with pipes inside commands the executor will run directly. (The `OUT=$(bash ...)` pattern inside verify scripts is fine — that is internal to the script, not a Bash-tool compound command.)
- Do NOT change the Tier A/B/C classification rules. The chunks path is a metric-source switch only.
- Do NOT delete any existing Reference File bullet from `commands/evaluate.md`.
- Do NOT touch `commands/roadmap.md` in this task — that is T02 territory.
- Do NOT touch `scripts/dispatch/scope-filter.sh`, `scripts/knowledge/rebuild-index.sh`, or `scripts/knowledge/lib/graph-db.sh`.
- Do NOT introduce a runtime dependency on `jq` or `python3` — awk/sed/grep only (MEM001).
- Scope: no end-to-end demo scenario script (T03 territory), no Bash 3.2 compat scan (T03 territory), no command-preserve-references regression (T03 territory).

## Expected Output

- `scripts/state/spec-metrics.sh` (create, ~80 lines, executable)
- `commands/evaluate.md` (modify: ~+25 lines across three targeted insertions; no deletions)
- `scripts/verify/m011-p05-spec-metrics-counts.sh` (create, ~55 lines, executable)
- `scripts/verify/m011-p05-spec-metrics-skips-superseded.sh` (create, ~40 lines, executable)
- `scripts/verify/m011-p05-evaluate-doc-references-metrics.sh` (create, ~30 lines, executable)
- All three verify scripts print `PASS:` on stdout and exit 0.
- `bash scripts/state/spec-metrics.sh /tmp` (non-existent knowledge tree) emits `spec_chunks_present=false` plus zero counts, exit 0.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P05 --task T01 \
  --provides "spec-metrics.sh helper, evaluate.md chunks-first wiring, metrics_source evaluation field" \
  --requires "P02 spec chunks shape, P04 superseded-tip filtering convention" \
  --affects "T02 roadmap command (parallel sibling), T03 demo-scenario (consumes spec-metrics)" \
  --key-files "scripts/state/spec-metrics.sh, commands/evaluate.md" \
  --verification-result pass \
  --body="T01 adds scripts/state/spec-metrics.sh and wires commands/evaluate.md to prefer ingested chunk counts over raw-spec regex. spec-metrics.sh emits seven key=value lines (spec_chunks_present, story_count, requirement_count, acceptance_count, constraint_count, nfr_count, non_goal_count), counting non-superseded tips only. evaluate.md documents the chunks-first / raw-spec-fallback switch and adds a metrics_source evaluation field. Three verify scripts cover the counter, superseded-tip skipping, and documentation wiring. No changes to tier classification rules or to roadmap.md."
```
