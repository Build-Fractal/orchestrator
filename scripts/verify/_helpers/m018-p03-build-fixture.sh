#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p03-build-fixture.sh
#
# Stages a hermetic fixture orch_root for the M018/P03 verifiers under
# the given root path. Layout (fixture mode — `phases/` directly under
# root; build-context.sh's elif branch picks up "fixture mode" from the
# presence of a phases/ dir).
#
#   <root>/
#     phases/P03/P03-PLAN.md
#     phases/P03/tasks/T01-PLAN.md
#     M018-fixture-ROADMAP.md
#     KNOWLEDGE-INDEX.md
#     execution-log.jsonl  (empty)
#     config.yml           (compression block — tier1 enabled by default)
#     cache/tool-results/  (target cache dir)
#     _fixture-payloads/payload.md  (copy of dispatch-payload-fixture.md)
#
# Usage: m018-p03-build-fixture.sh <root>
#
# Env (optional):
#   COMPRESSION_BLOCK_OVERRIDE — path to a file whose contents replace the
#                                default compression: block in config.yml.
#                                Use to stage compression.enabled: false
#                                or compression.tier1.enabled: false
#                                fixtures.
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant.

set -eu

if [ $# -lt 1 ]; then
  printf 'Usage: m018-p03-build-fixture.sh <root>\n' >&2
  exit 1
fi

ROOT="$1"
if [ ! -d "$ROOT" ]; then
  printf 'm018-p03-build-fixture.sh: root not found: %s\n' "$ROOT" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC_PAYLOAD="$REPO_ROOT/tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md"

if [ ! -f "$SRC_PAYLOAD" ]; then
  printf 'm018-p03-build-fixture.sh: source fixture missing: %s\n' "$SRC_PAYLOAD" >&2
  exit 1
fi

mkdir -p "$ROOT/phases/P03/tasks"
mkdir -p "$ROOT/cache/tool-results"
mkdir -p "$ROOT/_fixture-payloads"

# ---- Roadmap ----
cat > "$ROOT/M018-fixture-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "M018-fixture"
feature_ref: "030-context-compression-layer"
feature_spec: "specs/030-context-compression-layer/spec.md"
vision: "Hermetic M018/P03 fixture milestone."
tier: "C"
created_at: "2026-04-27T00:00:00Z"
updated_at: "2026-04-27T00:00:00Z"
---

## Phases

- [ ] **P03**: Tier 1 microcompact fixture phase — "M018/P03 verifier fixture phase."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: `tasks/T01-PLAN.md`
    - Consumes: nothing

## Dependency Graph

```
P03
```

## Execution Order

1. **P03**

## Validation

- Hermetic.
EOF

# ---- Phase plan ----
cat > "$ROOT/phases/P03/P03-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M018-fixture"
name: "Fixture phase"
depends_on: []
---

## Goal

M018/P03 fixture phase.

## Demo

N/A.

## Must-Haves

### Truths

- Fixture task exists.
  - Check: `test -f phases/P03/tasks/T01-PLAN.md`

## Files Likely Touched

- `execution-log.jsonl`

## Task Breakdown

- T01
EOF

# ---- Task plan ----
cat > "$ROOT/phases/P03/tasks/T01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M018-fixture"
name: "Fixture task"
depends_on: []
---

## Prerequisites

None.

## Description

Fixture task for M018/P03 verifiers.

## Must-Haves

### Truths

- N/A.

## Constraints

- Hermetic.

## Expected Output

- One JSONL record per emitter invocation.
EOF

# ---- KNOWLEDGE-INDEX.md (empty — no knowledge entries needed for tier1) ----
cat > "$ROOT/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index

<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
EOF

# ---- Empty execution log ----
: > "$ROOT/execution-log.jsonl"

# ---- Copy fixture payload ----
cp "$SRC_PAYLOAD" "$ROOT/_fixture-payloads/payload.md"

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
  cat > "$ROOT/config.yml" <<EOF
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
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
    cache_dir: $ROOT/cache/tool-results/
EOF
fi

printf 'fixture-staged at %s\n' "$ROOT"
exit 0
