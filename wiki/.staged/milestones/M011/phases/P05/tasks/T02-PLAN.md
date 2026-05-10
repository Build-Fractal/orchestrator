---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M011"
name: "Add spec-story-graph.sh, register roadmap stage in intensity-gate.sh, and wire commands/roadmap.md to consume ingested story chunks with intensity-aware interaction"
depends_on: []
---

## Prerequisites

P01–P04 are complete. Key interfaces this task depends on:

- `knowledge/spec/story/SPEC-US-<NNN>.md` chunks exist when a spec has been ingested (P02). Frontmatter contains `category: "spec/story"`, `relates_to: [<SPEC-ID>, ...]`, and `superseded_by: "<SPEC-ID>" or ""`.
- `scripts/knowledge/traverse-graph.sh` accepts `--id <id> --hops 1` and emits neighbor IDs on stdout. Established by [M007](../../../../../milestones/M007/index.md); extended by P04 for spec-category respect.
- `scripts/knowledge/lib/graph-db.sh` exposes SQLite helpers with sourcing guarded by `_GRAPH_DB_SOURCED`.
- `scripts/dispatch/scope-filter.sh --category spec/story --graph` emits SPEC-US- IDs from `knowledge.db` (non-superseded only via graph mode; unchanged from P04).
- `scripts/engine/intensity-gate.sh` has a stage registry for commands including `plan-phase`, `discuss`, `dispatch`, `verify`, `knowledge`, `auto`, etc. Each stage has Quick/Standard/Full substep lists hardcoded as a single source of truth. Add a new `roadmap` row.
- `commands/roadmap.md` (~137 lines today) describes the existing raw-spec decomposition flow.
- `commands/discuss.md` implements the Tier C collaborative pattern that roadmap can delegate to at Full intensity.

No spec-chunk-driven decomposition path exists in `commands/roadmap.md` today, and `intensity-gate.sh` has no `roadmap` stage.

## Description

Deliver the roadmap side of P05:

1. **`scripts/knowledge/spec-story-graph.sh`** (new) — emit per-story `<ID>|<comma-sep depends-on IDs>` lines by traversing `relates_to` edges between story chunks via `traverse-graph.sh`. Superseded story tips are skipped.

2. **`scripts/engine/intensity-gate.sh`** (modify) — add a new `roadmap` stage with Quick/Standard/Full substep rows.

3. **`commands/roadmap.md`** (modify) — document the chunks-first phase decomposition path (enumerate `spec/story` chunks via `scope-filter.sh --category spec/story --graph`, read story-to-story dependencies via `spec-story-graph.sh`, fall back to raw-spec parsing when no chunks exist) and the intensity-aware interaction pattern (Quick directive / Standard semi-directive / Full collaborative via `discuss`).

4. **Verify scripts** — four scripts that certify the helper, the intensity-gate stage, the roadmap doc wiring, and the delegation-to-traverse-graph behavior.

The key invariants: (a) when no spec has been ingested, `roadmap` behaves exactly as it does today; (b) when chunks exist, roadmap produces one phase per story or per story cluster, with `depends_on` traced from `relates_to` edges; (c) at Quick intensity the command is strictly single-pass, at Full it delegates to the existing `discuss` collaborative loop.

## Steps

### Step 1: Create `scripts/knowledge/spec-story-graph.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/spec-story-graph.sh — Emit story-to-story depends_on edges.
#
# Usage: spec-story-graph.sh <orch_root>
#   <orch_root> — path to the .orchestrator/ tree (used to locate the
#                 sibling knowledge/ directory).
#
# Output (stdout): one line per non-superseded `spec/story` chunk:
#   <SPEC-STORY-ID>|<comma-sep list of SPEC-STORY-IDs this story depends on>
# The right-hand side is empty ("") for stories with no story-to-story edges.
#
# "Depends on" means: there is a `relates_to` edge from this story to
# another story chunk. The directionality is taken as-is — relates_to
# is treated as a dependency edge for the roadmap's purposes.
#
# Exit 0 on success (including empty output when no stories exist).
# Exit 1 on missing argument.
#
# Bash 3.2 compatible (MEM001). Delegates edge traversal to
# scripts/knowledge/traverse-graph.sh rather than reimplementing SQL.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "spec-story-graph.sh: requires <orch_root>" >&2
  exit 1
fi

ORCH_ROOT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KNOWLEDGE_SPEC=""
if [ -d "${ORCH_ROOT}/../knowledge/spec" ]; then
  KNOWLEDGE_SPEC="$(cd "${ORCH_ROOT}/../knowledge/spec" && pwd)"
elif [ -d "${REPO_ROOT}/knowledge/spec" ]; then
  KNOWLEDGE_SPEC="${REPO_ROOT}/knowledge/spec"
fi

STORY_DIR="${KNOWLEDGE_SPEC}/story"
if [ ! -d "$STORY_DIR" ]; then
  exit 0
fi

TRAVERSE="${REPO_ROOT}/scripts/knowledge/traverse-graph.sh"

emit_story_deps() {
  # emit_story_deps <story-file>
  local file="$1"
  local id sby
  id="$(basename "$file" .md)"

  # Skip superseded tips
  sby="$(awk '
    /^---$/ { c++; if (c==2) exit; next }
    c==1 && /^superseded_by:/ {
      sub(/^superseded_by:[[:space:]]*/, "")
      gsub(/"/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print; exit
    }
  ' "$file" 2>/dev/null)"
  if [ -n "$sby" ]; then
    return 0
  fi

  # Enumerate 1-hop relates_to neighbors via traverse-graph.sh; filter
  # to story-category neighbors by checking the neighbor file path.
  local neighbors_file
  neighbors_file="$(mktemp)"
  bash "$TRAVERSE" --id "$id" --hops 1 > "$neighbors_file" 2>/dev/null || true

  local deps=""
  local n
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    [ "$n" = "$id" ] && continue
    # Keep only neighbors that exist under knowledge/spec/story/
    if [ -f "${STORY_DIR}/${n}.md" ]; then
      # Skip neighbor if it is itself superseded
      local nsby
      nsby="$(awk '
        /^---$/ { c++; if (c==2) exit; next }
        c==1 && /^superseded_by:/ {
          sub(/^superseded_by:[[:space:]]*/, "")
          gsub(/"/, "")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "")
          print; exit
        }
      ' "${STORY_DIR}/${n}.md" 2>/dev/null)"
      if [ -z "$nsby" ]; then
        if [ -z "$deps" ]; then
          deps="$n"
        else
          deps="${deps},${n}"
        fi
      fi
    fi
  done < "$neighbors_file"
  rm -f "$neighbors_file"

  printf '%s|%s\n' "$id" "$deps"
}

# Iterate story chunks in sorted order for deterministic output
for f in "$STORY_DIR"/SPEC-US-*.md; do
  [ -e "$f" ] || continue
  emit_story_deps "$f"
done
```

`chmod +x`. Notes:

- `while IFS= read -r n; do … done < "$neighbors_file"` — uses a temp file rather than `<(...)` for Bash 3.2 compat.
- Neighbor filtering: only story-category neighbors are treated as story-graph edges. Cross-category neighbors (requirement→story, etc.) are ignored here — those are for dispatch scope filtering (P04), not roadmap phase ordering.
- The traverse-graph invocation returns IDs on stdout one per line; if it fails (e.g., empty DB), we continue with no deps rather than erroring.

### Step 2: Add `roadmap` stage to `scripts/engine/intensity-gate.sh`

Open `scripts/engine/intensity-gate.sh` and locate the stage-matrix block (hardcoded case statements for each stage). Add a new stage case matching the existing pattern. The approximate insertion point is alongside existing stages like `plan-phase`, `discuss`, `dispatch`.

Add a `roadmap` case to both the stage-validation list (if one exists near the top) and the main stage-dispatch matrix:

```bash
    roadmap)
      case "$INTENSITY" in
        Quick)
          echo "execute_substeps=single-pass"
          echo "skip_substeps=rationale,collaborative-loop"
          ;;
        Standard)
          echo "execute_substeps=basic-decomp,rationale"
          echo "skip_substeps=collaborative-loop"
          ;;
        Full)
          echo "execute_substeps=basic-decomp,rationale,collaborative-loop"
          echo "skip_substeps="
          ;;
        *)
          echo "ERROR: unknown intensity '$INTENSITY' for stage roadmap" >&2
          exit 2
          ;;
      esac
      ;;
```

Follow the exact control-flow idiom of the existing stage cases — do not introduce a new pattern. If the existing stages use `return` instead of `exit`, match that. If an allowlist of known stages exists at the top of the script, add `roadmap` to it.

### Step 3: Update `commands/roadmap.md`

Insert a new subsection inside "Spec Analysis" and extend the Prerequisites block with the intensity call. Keep all existing content intact.

**Edit 1** — in the "Prerequisites" section, add a new step 6 after the existing step 5:

```markdown
6. **Resolve roadmap intensity behavior** by running:

   ```bash
   bash scripts/engine/intensity-gate.sh --stage roadmap --intensity-metadata <path-to-metadata>
   ```

   Parse the `execute_substeps=` output. The values are one of:
   - `single-pass` (Quick) — directive: produce the roadmap in one pass, present it as "Here's your roadmap. Accept, refine, or override."
   - `basic-decomp,rationale` (Standard) — semi-directive: present phase decomposition with rationale per phase, ask the developer to accept or refine specific phases.
   - `basic-decomp,rationale,collaborative-loop` (Full) — collaborative: delegate the walk-through to the `speckit.orchestrator.discuss` Tier C pattern, iterating phase-by-phase with the developer.
```

**Edit 2** — in the "Spec Analysis" section, replace step 1:

```markdown
1. **Read the feature spec** (`specs/{NNN}-{name}/spec.md`) — identify all user stories, acceptance scenarios, functional requirements, and non-functional constraints.
```

With:

```markdown
1. **Read structural elements**. Prefer ingested spec chunks over re-parsing the raw spec:

   **Chunks-first path** (when `bash scripts/state/spec-metrics.sh <orch-root>` reports `spec_chunks_present=true`):

   - Enumerate `spec/story` chunks via `bash scripts/dispatch/scope-filter.sh --category spec/story --graph` — one SPEC-US-NNN ID per line.
   - Read story-to-story dependency edges via `bash scripts/knowledge/spec-story-graph.sh <orch-root>` — one `<SPEC-US-ID>|<comma-sep deps>` line per story. Each dependency pair `US-003|US-001` means "the phase containing US-003 depends on the phase containing US-001".
   - For each story, pull its related `spec/acceptance` and `spec/constraint` chunks via `scope-filter.sh --spec-scope-tags "spec/story/SPEC-US-NNN"` (from P04) to inform phase goals and demo sentences.

   **Raw-spec fallback** (when `spec_chunks_present=false`): parse the raw spec at `specs/{NNN}-{name}/spec.md` for user stories, acceptance scenarios, functional requirements, and non-functional constraints. This is the legacy behavior preserved for un-ingested specs.
```

**Edit 3** — in the "Phase Decomposition" subsection under "Roadmap Generation", add a new bullet at the end describing chunk-driven phase construction:

```markdown
- **When chunks are present**: each phase corresponds to one `spec/story` chunk (or a tightly-linked story cluster when multiple stories share a common thread). The phase `depends_on` field for each phase is populated from the `spec-story-graph.sh` output — if US-003 depends on US-001 via `relates_to`, then the phase containing US-003 has `depends_on` pointing to the phase containing US-001.
```

**Edit 4** — in the "Roadmap Generation" section, prepend a new subsection before "Phase Decomposition":

```markdown
### Intensity-Aware Interaction

The interaction style is gated by the resolved intensity substeps from the Prerequisites step:

- **single-pass (Quick)**: produce the full roadmap in one pass without intermediate confirmation; present the final roadmap with "Accept, refine, or override." No rationale walk-through.
- **basic-decomp,rationale (Standard)**: present phase decomposition with a one-sentence rationale per phase; ask the developer to accept, refine, or request a re-decomposition before writing the roadmap.
- **basic-decomp,rationale,collaborative-loop (Full)**: invoke the `speckit.orchestrator.discuss` Tier C collaborative loop to walk through each candidate phase with the developer. The output of the discussion seeds the roadmap.
```

**Edit 5** — append bullets to the "Reference Files" section:

```markdown
- `scripts/dispatch/scope-filter.sh` — enumerates ingested `spec/story` chunks when chunks are present (via `--category spec/story --graph` mode added in P04)
- `scripts/knowledge/spec-story-graph.sh` — emits story-to-story `depends_on` edges traced from `relates_to` (P05)
- `scripts/knowledge/traverse-graph.sh` — underlying graph traversal used by `spec-story-graph.sh`
- `scripts/engine/intensity-gate.sh` — resolves Quick/Standard/Full substeps for the `roadmap` stage (P05)
- `scripts/state/spec-metrics.sh` — reports `spec_chunks_present` flag driving the chunks-first vs raw-spec-fallback switch (P05, T01)
```

Place these between the existing `scripts/lifecycle/scaffold.sh` bullet and the `references/tier-definitions.md` bullet so script bullets stay grouped.

**Do not remove** any existing bullet or section — the regression verify script (T03) asserts that every previously listed Reference File remains.

### Step 4: Write `scripts/verify/m011-p05-spec-story-graph-emits-deps.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-story-graph-emits-deps.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/story"

write_story() {
  # write_story <id> <relates-yaml> <superseded_by>
  local id="$1" rel="$2" sby="$3"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'id: "%s"\n' "$id"
    printf 'category: "spec/story"\n'
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: %s\n' "$rel"
    printf 'scope_tags: "[project]"\n'
    printf -- '---\n\nbody\n'
  } > "$FIXTURE/knowledge/spec/story/${id}.md"
}

write_story SPEC-US-001 "[]"            ""
write_story SPEC-US-002 "[]"            ""
write_story SPEC-US-003 "[SPEC-US-001]" ""

# Rebuild the knowledge DB so traverse-graph.sh can find edges
PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1 || true

OUT="$(bash "$REPO/scripts/knowledge/spec-story-graph.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

# Expected lines (order may vary)
check_line() {
  local expect="$1"
  if ! printf '%s\n' "$OUT" | grep -Fxq "$expect"; then
    printf 'FAIL: missing expected line: %s\n' "$expect"
    printf 'Actual output:\n%s\n' "$OUT"
    exit 1
  fi
}

check_line "SPEC-US-001|"
check_line "SPEC-US-002|"
check_line "SPEC-US-003|SPEC-US-001"

echo "PASS: spec-story-graph emits expected depends_on edges"
```

### Step 5: Write `scripts/verify/m011-p05-spec-story-graph-delegates.sh`

Assert the script calls `traverse-graph.sh` (delegation rather than reimplementation).

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-story-graph-delegates.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/scripts/knowledge/spec-story-graph.sh"

if ! grep -q "traverse-graph.sh" "$SCRIPT"; then
  echo "FAIL: spec-story-graph.sh does not reference traverse-graph.sh"
  exit 1
fi

# Ensure it does NOT contain direct sqlite3 SELECT on the edges table
if grep -q "sqlite3" "$SCRIPT"; then
  echo "FAIL: spec-story-graph.sh invokes sqlite3 directly (should delegate)"
  exit 1
fi

echo "PASS: spec-story-graph.sh delegates edge traversal"
```

### Step 6: Write `scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

check_intensity() {
  local level="$1" expect_exec="$2"
  local out
  out="$(bash "$REPO/scripts/engine/intensity-gate.sh" --stage roadmap --intensity "$level" 2>/dev/null)"
  local got
  got="$(printf '%s\n' "$out" | awk -F= '$1=="execute_substeps"{print $2; exit}')"
  if [ "$got" != "$expect_exec" ]; then
    printf 'FAIL: stage=roadmap intensity=%s expected execute_substeps=%s got=%s\n' \
      "$level" "$expect_exec" "$got"
    exit 1
  fi
}

check_intensity Quick "single-pass"
check_intensity Standard "basic-decomp,rationale"
check_intensity Full "basic-decomp,rationale,collaborative-loop"

echo "PASS: intensity-gate roadmap stage resolves substeps"
```

### Step 7: Write `scripts/verify/m011-p05-roadmap-doc-references-chunks.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-roadmap-doc-references-chunks.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/roadmap.md"

required_patterns="spec/story|spec-story-graph.sh|scope-filter.sh|traverse-graph.sh|Chunks-first path|Raw-spec fallback"

IFS='|'
fail=0
for pat in $required_patterns; do
  if ! grep -Fq "$pat" "$DOC"; then
    printf 'FAIL: roadmap.md missing pattern: %s\n' "$pat"
    fail=1
  fi
done
unset IFS

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: roadmap.md references spec-chunk enumeration path"
```

### Step 8: Write `scripts/verify/m011-p05-roadmap-doc-references-intensity.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p05-roadmap-doc-references-intensity.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/roadmap.md"

if ! grep -Fq "intensity-gate.sh --stage roadmap" "$DOC"; then
  echo "FAIL: roadmap.md missing intensity-gate.sh --stage roadmap call"
  exit 1
fi

if ! grep -Fq "single-pass" "$DOC"; then
  echo "FAIL: roadmap.md missing 'single-pass' substep description"
  exit 1
fi

if ! grep -Fq "collaborative-loop" "$DOC"; then
  echo "FAIL: roadmap.md missing 'collaborative-loop' substep description"
  exit 1
fi

if ! grep -Fq "speckit.orchestrator.discuss" "$DOC"; then
  echo "FAIL: roadmap.md missing delegation to speckit.orchestrator.discuss"
  exit 1
fi

echo "PASS: roadmap.md documents intensity-aware interaction"
```

## Must-Haves

- `scripts/knowledge/spec-story-graph.sh` exists, is executable, and emits `<id>|<comma-deps>` one line per non-superseded story.
- `spec-story-graph.sh` delegates edge lookup to `traverse-graph.sh` (no `sqlite3` invocation).
- `scripts/engine/intensity-gate.sh` returns deterministic substeps for stage=`roadmap` at Quick, Standard, and Full.
- `commands/roadmap.md` documents:
  - The Chunks-first path enumerating `spec/story` via `scope-filter.sh --category spec/story --graph`.
  - The Raw-spec fallback path (existing behavior preserved).
  - Story-to-story `depends_on` traced from `spec-story-graph.sh`.
  - Intensity-aware interaction with `intensity-gate.sh --stage roadmap` and the three substep patterns.
  - Delegation to `speckit.orchestrator.discuss` at Full intensity.
- `commands/roadmap.md` "Reference Files" block includes `scripts/dispatch/scope-filter.sh`, `scripts/knowledge/spec-story-graph.sh`, `scripts/knowledge/traverse-graph.sh`, `scripts/engine/intensity-gate.sh`, and `scripts/state/spec-metrics.sh`.
- Previously listed roadmap.md references (`templates/roadmap.md`, `scripts/state/derive-phase.sh`, `scripts/state/read-config.sh`, `scripts/lifecycle/scaffold.sh`, `references/tier-definitions.md`, `scripts/verify/check-boundary-map.sh`, `references/state-machine.md`) remain present.
- The four T02 verify scripts print `PASS:` and exit 0.

## Verification

```
bash scripts/verify/m011-p05-spec-story-graph-emits-deps.sh
bash scripts/verify/m011-p05-spec-story-graph-delegates.sh
bash scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh
bash scripts/verify/m011-p05-roadmap-doc-references-chunks.sh
bash scripts/verify/m011-p05-roadmap-doc-references-intensity.sh
```

## Inputs

### From Previous Tasks

- None from within P05 — T02 is independent of T01. (T01's `spec-metrics.sh` is only referenced by roadmap.md documentation; no runtime dependency between T01 and T02 exists.)

### From Disk (Pre-existing)

- `scripts/knowledge/traverse-graph.sh`
  - Key API: `traverse-graph.sh --id <entry-id> --hops <N>` emits neighbor IDs on stdout, one per line. Output includes the starting ID and its 1-hop `relates_to` neighbors. Ignores superseded chains only when invoked in certain graph-db modes — spec-story-graph.sh adds its own per-neighbor superseded-tip filter to be safe.
- `scripts/knowledge/rebuild-index.sh`
  - Key API: `PROJECT_ROOT=<dir> bash rebuild-index.sh` scans `$PROJECT_ROOT/knowledge/**/*.md` and rebuilds `$PROJECT_ROOT/.knowledge/knowledge.db` (or equivalent). Required so traverse-graph.sh can find the edges T02 writes in test fixtures.
- `scripts/dispatch/scope-filter.sh`
  - Key API: `scope-filter.sh --category spec/story --graph` emits `spec/story` entry IDs from knowledge.db, one per line. Respects superseded-tip filtering in graph mode.
- `scripts/engine/intensity-gate.sh`
  - Key API: `intensity-gate.sh --stage <name> --intensity <Quick|Standard|Full>` emits `execute_substeps=<csv>` and `skip_substeps=<csv>`. The `--intensity-metadata <file>` form reads intensity from a metadata file.
  - Existing stages (observed): `plan-phase`, `discuss`, `dispatch`, `verify`, `knowledge`, `auto`. Add `roadmap` following the same idiom.
- `commands/roadmap.md` — 137-line existing doc. Modified in Step 3.
- `commands/discuss.md` — referenced by roadmap.md for Full-intensity delegation; not modified.
- `knowledge/spec/story/*.md` — ingested story chunks (P02/P03). Frontmatter fields `category`, `relates_to`, `superseded_by` are read.

## Constraints

- Bash 3.2 compatible: no `declare -A`, `mapfile`, `readarray`, or `<(...)` in `spec-story-graph.sh`, the `intensity-gate.sh` edits, or the verify scripts.
- AD-19 discipline for the phase-plan `Check:` commands — already satisfied by the single-script-file shape.
- AP-004 compliance in execution-agent bash calls: no `$(...)` with pipes in commands the executor runs directly. Inside verify scripts the `$(bash ... | awk ...)` is fine — that's internal to the script.
- Do NOT change the Tier C discussion-gate rule in `commands/roadmap.md` — that logic stays. The Full-intensity path delegates to `discuss` (same script), not replaces the gate.
- Do NOT delete any existing Reference File bullet from `commands/roadmap.md`.
- Do NOT touch `commands/evaluate.md` (T01 territory) or `commands/discuss.md`.
- Do NOT touch `scripts/knowledge/traverse-graph.sh`, `scripts/dispatch/scope-filter.sh`, or `scripts/knowledge/lib/graph-db.sh`.
- Do NOT introduce a runtime dependency on `jq` or `python3`.
- Scope: no end-to-end demo-scenario script (T03 territory), no Bash 3.2 compat scan (T03 territory), no command-preserve-references regression (T03 territory).
- `spec-story-graph.sh` MUST skip neighbors that are themselves superseded. A story cluster `US-001 → US-001-v2 (superseded_by unused) → US-003` should emit `US-003|US-001-v2`, not `US-003|US-001`.

## Expected Output

- `scripts/knowledge/spec-story-graph.sh` (create, ~90 lines, executable).
- `scripts/engine/intensity-gate.sh` (modify: +16 lines for the new `roadmap` stage case; update any allowlist if one exists at the top of the script).
- `commands/roadmap.md` (modify: ~+45 lines across five targeted insertions; no deletions).
- `scripts/verify/m011-p05-spec-story-graph-emits-deps.sh` (create, ~50 lines, executable).
- `scripts/verify/m011-p05-spec-story-graph-delegates.sh` (create, ~20 lines, executable).
- `scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh` (create, ~30 lines, executable).
- `scripts/verify/m011-p05-roadmap-doc-references-chunks.sh` (create, ~25 lines, executable).
- `scripts/verify/m011-p05-roadmap-doc-references-intensity.sh` (create, ~25 lines, executable).
- All five verify scripts print `PASS:` on stdout and exit 0.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P05 --task T02 \
  --provides "spec-story-graph.sh helper, intensity-gate.sh roadmap stage, roadmap.md chunks-first + intensity-aware wiring" \
  --requires "P02 spec/story chunk shape, P04 scope-filter --category --graph mode, M007 traverse-graph.sh" \
  --affects "T03 demo-scenario + regression, orchestrator:roadmap runtime behavior" \
  --key-files "scripts/knowledge/spec-story-graph.sh, scripts/engine/intensity-gate.sh, commands/roadmap.md" \
  --verification-result pass \
  --body="T02 adds spec-story-graph.sh (emits story-to-story depends_on lines via traverse-graph.sh delegation, skips superseded tips including superseded neighbors), registers a new 'roadmap' stage in intensity-gate.sh with Quick=single-pass / Standard=basic-decomp,rationale / Full=basic-decomp,rationale,collaborative-loop substeps, and wires commands/roadmap.md to prefer ingested spec/story chunks for phase decomposition with graceful fallback to raw-spec parsing. The doc describes intensity-aware interaction and Full-intensity delegation to speckit.orchestrator.discuss. Five verify scripts cover the helper output, delegation discipline, intensity-gate substeps, and doc wiring."
```
