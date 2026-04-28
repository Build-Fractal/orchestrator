#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p02-build-fixture.sh
#
# Stages a hermetic fixture orch_root for the M018/P02 verifiers under the
# given root path. Layout (fixture mode — `phases/` directly under root):
#
#   <root>/
#     phases/P01/P01-PLAN.md
#     phases/P01/tasks/T01-PLAN.md
#     M999-ROADMAP.md
#     KNOWLEDGE.md  (does NOT exist — we use KNOWLEDGE-INDEX path)
#     KNOWLEDGE-INDEX.md
#     execution-log.jsonl  (empty)
#     config.yml  (compression block)
#     knowledge/
#       patterns/MEM900.md
#       patterns/MEM901.md
#       patterns/MEM902.md
#       lessons/MEM903.md
#       conventions/MEM904.md
#
# Usage: build-fixture.sh <root>
#   <root>: target dir (must already exist; fixture is staged inside)
#
# Env:
#   COMPRESSION_BLOCK_OVERRIDE — optional path; if set, contents of this
#   file replace the default compression: block in config.yml. Use to
#   stage compression.enabled: false fixtures.
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant.

set -eu

if [ $# -lt 1 ]; then
  printf 'Usage: build-fixture.sh <root>\n' >&2
  exit 1
fi

ROOT="$1"
if [ ! -d "$ROOT" ]; then
  printf 'build-fixture.sh: root not found: %s\n' "$ROOT" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC_FIXTURE="$REPO_ROOT/tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md"

if [ ! -f "$SRC_FIXTURE" ]; then
  printf 'build-fixture.sh: source fixture missing: %s\n' "$SRC_FIXTURE" >&2
  exit 1
fi

mkdir -p "$ROOT/phases/P01/tasks"
mkdir -p "$ROOT/knowledge/patterns"
mkdir -p "$ROOT/knowledge/lessons"
mkdir -p "$ROOT/knowledge/conventions"

# ---- Roadmap ----
cat > "$ROOT/M999-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "M999"
feature_ref: "999-m018-p02-fixture"
feature_spec: "specs/999-m018-p02-fixture/spec.md"
vision: "Hermetic M018/P02 fixture milestone."
tier: "C"
created_at: "2026-04-27T00:00:00Z"
updated_at: "2026-04-27T00:00:00Z"
---

## Phases

- [ ] **P01**: Fixture phase — "M018/P02 verifier fixture phase."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: `tasks/T01-PLAN.md`
    - Consumes: nothing

## Dependency Graph

```
P01
```

## Execution Order

1. **P01**

## Validation

- Hermetic.
EOF

# ---- Phase plan ----
cat > "$ROOT/phases/P01/P01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M999"
name: "Fixture phase"
depends_on: []
---

## Goal

M018/P02 fixture phase.

## Demo

N/A.

## Must-Haves

### Truths

- Fixture task exists.
  - Check: `test -f phases/P01/tasks/T01-PLAN.md`

## Files Likely Touched

- `execution-log.jsonl`

## Task Breakdown

- T01
EOF

# ---- Task plan ----
cat > "$ROOT/phases/P01/tasks/T01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M999"
name: "Fixture task"
depends_on: []
---

## Prerequisites

None.

## Description

Fixture task for M018/P02 verifiers.

## Must-Haves

### Truths

- N/A.

## Constraints

- Hermetic.

## Expected Output

- One JSONL record per emitter invocation.
EOF

# ---- KNOWLEDGE-INDEX.md (pipe-delimited per scope-filter contract) ----
# Every fixture entry tagged `[project]` so the planning branch's scope
# filter accepts them regardless of MILESTONE_ID.
cat > "$ROOT/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index

<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->

MEM900 | [project] | patterns | 0.95 | 2026-04-27 | verified:2026-04-27 | hits:1 | Stable Reference Pattern
MEM901 | [project] | patterns | 0.40 | 2026-04-27 | verified:2026-04-27 | hits:1 | Superseded Pattern
MEM902 | [project] | patterns | 0.85 | 2026-04-27 | verified:2026-04-27 | hits:1 | Pre-M020 Entry no status
MEM903 | [project] | lessons | 0.30 | 2026-04-27 | verified:2026-04-27 | hits:1 | Experimental Pattern
MEM904 | [project] | conventions | 0.95 | 2026-04-27 | verified:2026-04-27 | hits:1 | Graduated Pattern
EOF

# ---- Per-MEM detail files (resolve-entries reads these) ----
# Split source fixture into chunks delimited by `^---$` `id: MEM###`.
# Use awk single-pass to write 5 files keyed by id.
awk -v root="$ROOT" '
  BEGIN { id=""; buf=""; in_fm=0; first=1 }
  /^---$/ {
    if (first == 1) {
      first = 0
      buf = "---\n"
      in_fm = 1
      next
    }
    if (in_fm == 1) {
      buf = buf "---\n"
      in_fm = 0
      next
    }
    # Boundary between entries: a `---` after FM closed and body printed.
    # Flush buffer to per-id file.
    if (id != "") {
      cat = "patterns"
      if (id == "MEM903") cat = "lessons"
      if (id == "MEM904") cat = "conventions"
      out = root "/knowledge/" cat "/" id ".md"
      printf "%s", buf > out
      close(out)
    }
    buf = "---\n"
    in_fm = 1
    id = ""
    next
  }
  in_fm == 1 && $0 ~ /^id:[[:space:]]/ {
    id = $0
    sub(/^id:[[:space:]]*/, "", id)
    sub(/[[:space:]]+$/, "", id)
    buf = buf $0 "\n"
    next
  }
  { buf = buf $0 "\n" }
  END {
    if (id != "") {
      cat = "patterns"
      if (id == "MEM903") cat = "lessons"
      if (id == "MEM904") cat = "conventions"
      out = root "/knowledge/" cat "/" id ".md"
      printf "%s", buf > out
      close(out)
    }
  }
' "$SRC_FIXTURE"

# ---- Empty execution log ----
: > "$ROOT/execution-log.jsonl"

# ---- Config ----
if [ -n "${COMPRESSION_BLOCK_OVERRIDE:-}" ] && [ -f "$COMPRESSION_BLOCK_OVERRIDE" ]; then
  cat > "$ROOT/config.yml" <<EOF
context_verbosity: standard
duration_budget: 2h
dispatch_budget: 3
budget_enforcement: warn
EOF
  cat "$COMPRESSION_BLOCK_OVERRIDE" >> "$ROOT/config.yml"
else
  cat > "$ROOT/config.yml" <<'EOF'
context_verbosity: standard
duration_budget: 2h
dispatch_budget: 3
budget_enforcement: warn
compression:
  enabled: true
  knowledge_filter:
    enabled: true
    drop_list: ["superseded", "experimental"]
  underperformance:
    enabled: true
    window_size: 30
    floor_pct: 34.7
    min_sample_size: 10
EOF
fi

printf 'fixture-staged at %s\n' "$ROOT"
exit 0
