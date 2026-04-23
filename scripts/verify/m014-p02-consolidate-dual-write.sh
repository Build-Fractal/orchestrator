#!/usr/bin/env bash
# Gate: verify consolidate-artifacts.sh dual-writes recent-changes + emits unit_close.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONSOLIDATE="${PROJECT_ROOT}/scripts/knowledge/consolidate-artifacts.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -f "$CONSOLIDATE" ]; then echo "FAIL: consolidate-artifacts.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

# Shape checks on the script source.
grep -q 'dual-write-runtime-md.sh' "$CONSOLIDATE" || { echo "FAIL: consolidate does not reference helper" >&2; exit 1; }
grep -q 'recent-changes'           "$CONSOLIDATE" || { echo "FAIL: consolidate does not use recent-changes marker" >&2; exit 1; }
grep -q 'orchestrator:consolidate' "$CONSOLIDATE" || { echo "FAIL: consolidate does not emit unit_close record" >&2; exit 1; }

# Hermetic integration: build a scratch milestone that consolidate can process.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Set up a minimal consolidatable milestone fixture.
ORCH="$SCRATCH/.orchestrator"
MDIR="$ORCH/milestones/M999"
mkdir -p "$MDIR/phases/P01/tasks"

cat > "$MDIR/M999-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "M999"
---
## Phases
- P01 complete risk=low depends_on=[]
EOF

cat > "$MDIR/phases/P01/P01-PLAN.md" <<'EOF'
# P01 Plan
Content to archive.
EOF

cat > "$MDIR/phases/P01/P01-SUMMARY.md" <<'EOF'
---
schema_version: "1.0"
type: phase-summary
---
Phase summary preserved.
EOF

# Seed CLAUDE.md with an empty marker region.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# Scratch project
Pre-existing outside content.

# >>> orchestrator:recent-changes >>>
- existing-entry: preserved
# <<< orchestrator:recent-changes <<<

## Recent Changes
Outside-marker section — preserved byte-for-byte.
EOF

# Capture outside-markers shasum.
outside_bytes() {
  awk '/^# >>> orchestrator:/ { in_r=1; next } /^# <<< orchestrator:/ { in_r=0; next } in_r != 1 { print }' "$1"
}
REF_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Run consolidate against the scratch project.
bash "$CONSOLIDATE" "$ORCH" M999 >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: consolidate exited non-zero ($RC)" >&2; exit 1; fi

# Assertions.
if ! grep -qF '# >>> orchestrator:recent-changes >>>' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md missing recent-changes marker" >&2; exit 1
fi
if ! grep -qE '^- M999: milestone consolidated' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md missing new consolidate entry" >&2; exit 1
fi
if ! grep -qE '^- existing-entry: preserved' "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: existing region entry was not preserved on append" >&2; exit 1
fi
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created by consolidate dual-write" >&2; exit 1
fi
if ! grep -qE '^- M999: milestone consolidated' "$SCRATCH/AGENTS.md"; then
  echo "FAIL: AGENTS.md missing new consolidate entry" >&2; exit 1
fi

POST_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_SHA" != "$POST_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged after consolidate dual-write" >&2; exit 1
fi

# Execution-log assertion.
LOG_FILE="$ORCH/execution-log.jsonl"
if [ ! -f "$LOG_FILE" ]; then
  echo "FAIL: execution-log.jsonl not created" >&2; exit 1
fi
if ! grep -q '"command":"orchestrator:consolidate"' "$LOG_FILE"; then
  echo "FAIL: unit_close record not appended" >&2; exit 1
fi
if ! grep -q '"milestone":"M999"' "$LOG_FILE"; then
  echo "FAIL: unit_close record missing milestone field" >&2; exit 1
fi

echo "PASS: consolidate dual-writes recent-changes + emits unit_close record"
exit 0
