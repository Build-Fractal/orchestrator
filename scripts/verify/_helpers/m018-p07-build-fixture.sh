#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p07-build-fixture.sh
#
# M018/P07/T01 — Stage a hermetic fixture orch_root for the runtime-parity
# diagnostics under tests/compression-runtime-parity/fixtures/<fixture>/.
# Mirrors the M018/P06 helper shape; T01-private so T02/T03 verifiers reuse
# it without coupling to one verifier.
#
# Layout (canonical mode — milestones/<M>/ — so build-context.sh resolves
# the staged orch_root cleanly via positional args):
#
#   <STAGE>/
#     config.yml                                              <- fixture cfg
#     milestones/M-FIXTURE/
#       M-FIXTURE-ROADMAP.md                                  <- minimal
#       execution-log.jsonl                                   <- empty
#       phases/P01/P01-PLAN.md                                <- minimal
#       phases/P01/tasks/T01-PLAN.md                          <- payload body
#     knowledge/                                              <- copied if
#                                                                fixture has
#                                                                a knowledge
#                                                                tree
#
# The fixture's `input/payload-input.txt` is folded into the staged task plan
# body so build-context.sh's payload assembler exposes the bytes to the
# downstream tier helpers (filter / Tier 1 / Tier 2 / Tier 3).
#
# Usage:  m018-p07-build-fixture.sh <runtime> <fixture-name>
#
# Args:
#   <runtime>       — claude-code | codex | cursor (used to namespace the
#                     stage so concurrent invocations of the parity runner
#                     do not collide).
#   <fixture-name>  — directory name under
#                     tests/compression-runtime-parity/fixtures/<name>/.
#
# Stdout: absolute path to the staged orch_root (the directory build-context.sh
#         takes as its first positional arg).
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant. Idempotent — clean-stages on
# every invocation.

set -u

if [ $# -lt 2 ]; then
  printf 'Usage: m018-p07-build-fixture.sh <runtime> <fixture-name>\n' >&2
  exit 1
fi

RUNTIME="$1"
FIXTURE="$2"

case "$RUNTIME" in
  claude-code|codex|cursor) : ;;
  *)
    printf 'm018-p07-build-fixture.sh: unknown runtime: %s (expected claude-code|codex|cursor)\n' "$RUNTIME" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORPUS_DIR="$PROJECT_ROOT/tests/compression-runtime-parity/fixtures/$FIXTURE"

if [ ! -d "$CORPUS_DIR" ]; then
  printf 'm018-p07-build-fixture.sh: fixture not found: %s\n' "$CORPUS_DIR" >&2
  exit 1
fi
if [ ! -f "$CORPUS_DIR/config.yml" ]; then
  printf 'm018-p07-build-fixture.sh: fixture missing config.yml: %s\n' "$CORPUS_DIR/config.yml" >&2
  exit 1
fi
if [ ! -f "$CORPUS_DIR/input/payload-input.txt" ]; then
  printf 'm018-p07-build-fixture.sh: fixture missing input/payload-input.txt: %s\n' "$CORPUS_DIR/input/payload-input.txt" >&2
  exit 1
fi

STAGE_ROOT="${TMPDIR:-/tmp}/_p07_fixture/${RUNTIME}-${FIXTURE}"

# Idempotent: clean prior staging.
rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_ROOT/milestones/M-FIXTURE/phases/P01/tasks"

# Stage config.yml at the orch_root (build-context resolves config via
# kf_resolve_config_path which honors $ORCH_ROOT/config.yml first).
cp "$CORPUS_DIR/config.yml" "$STAGE_ROOT/config.yml"

# Stage knowledge tree if present (informational — build-context's
# hardcoded PROJECT_ROOT means filter resolution still goes through the
# real KNOWLEDGE-INDEX.md; the fixture knowledge/ directory documents
# the contract for future hermetic-mode work).
if [ -d "$CORPUS_DIR/knowledge" ]; then
  cp -R "$CORPUS_DIR/knowledge" "$STAGE_ROOT/knowledge"
fi

# Empty execution log (T02 / T03 verifiers append runtime_parity records
# here when reading the staged root).
: > "$STAGE_ROOT/milestones/M-FIXTURE/execution-log.jsonl"

# Minimal roadmap so read-roadmap.sh resolves cleanly.
cat > "$STAGE_ROOT/milestones/M-FIXTURE/M-FIXTURE-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "M-FIXTURE"
tier: "C"
created_at: "2026-04-28T00:00:00Z"
updated_at: "2026-04-28T00:00:00Z"
---

## Phases

- [ ] **P01**: Fixture phase — "Compression-parity fixture phase."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: nothing
    - Consumes: nothing
EOF

# Minimal phase plan so build-context's task-dispatch branch resolves.
cat > "$STAGE_ROOT/milestones/M-FIXTURE/phases/P01/P01-PLAN.md" <<'EOF'
---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M-FIXTURE"
goal: "Fixture phase goal."
demo_sentence: "Fixture demo sentence."
risk: "low"
depends_on: []
---

## Boundary Map
EOF

# Compose the staged task plan: the fixture's payload-input.txt verbatim.
# build-context.sh's handle_task_plan cats the file body into the
# `## Task Plan` section, so the fixture bytes land inside that section —
# which is in T2's in_scope() set. The fixture author owns the body shape
# (frontmatter optional; tier-2 fixtures avoid `---` and 3+-backtick fences
# so the head-drop's preservation check does not roll the snip back).
TASK_PLAN="$STAGE_ROOT/milestones/M-FIXTURE/phases/P01/tasks/T01-PLAN.md"
cp "$CORPUS_DIR/input/payload-input.txt" "$TASK_PLAN"

# Print the staged orch_root path on stdout — the parity runner feeds this
# to build-context.sh as the first positional arg.
printf '%s\n' "$STAGE_ROOT"
exit 0
