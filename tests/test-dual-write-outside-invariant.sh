#!/usr/bin/env bash
# tests/test-dual-write-outside-invariant.sh — SC-6a outside-markers shasum invariant.
# Seeds a temp CLAUDE.md-like file with known outside-markers bytes, invokes
# dual-write-runtime-md.sh several times with distinct content fragments, and
# asserts shasum of outside-markers bytes is byte-identical across writes.
# Also verifies AGENTS.md is created when absent and its outside region is
# preserved on subsequent writes.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$HELPER" ]; then
  echo "FAIL: scripts/util/dual-write-runtime-md.sh missing or not executable" >&2
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Set up scratch project root with config.yml (dual_write_agents: true).
mkdir -p "$SCRATCH/.orchestrator"
cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

# Seed CLAUDE.md with outside-markers content.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md

Outside content paragraph 1.

## Existing Section

Outside content paragraph 2.
EOF

# Helper: extract outside-markers bytes from a file.
outside_bytes() {
  local f="$1"
  awk '
    /^# >>> orchestrator:/ { in_region=1; next }
    /^# <<< orchestrator:/ { in_region=0; next }
    in_region != 1 { print }
  ' "$f"
}

# Compute reference shasum before any writes.
REF_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Fragment 1.
FRAG1="$(mktemp)"
echo "- fragment one: spec-001 scaffolded" > "$FRAG1"

bash "$HELPER" --marker recent-changes --content "$FRAG1" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: first write exited non-zero ($RC)" >&2; exit 1
fi

POST1_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_CLAUDE_SHA" != "$POST1_CLAUDE_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in CLAUDE.md after first write" >&2
  echo "  ref=$REF_CLAUDE_SHA post=$POST1_CLAUDE_SHA" >&2
  exit 1
fi

# AGENTS.md should now exist.
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created on first write" >&2; exit 1
fi
REF_AGENTS_SHA="$(outside_bytes "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

# Fragment 2 — replace the region.
FRAG2="$(mktemp)"
echo "- fragment two: spec-001 amended + spec-002 scaffolded" > "$FRAG2"
bash "$HELPER" --marker recent-changes --content "$FRAG2" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: second write exited non-zero ($RC)" >&2; exit 1
fi

POST2_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
POST2_AGENTS_SHA="$(outside_bytes "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

if [ "$REF_CLAUDE_SHA" != "$POST2_CLAUDE_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in CLAUDE.md after second write" >&2
  exit 1
fi
if [ "$REF_AGENTS_SHA" != "$POST2_AGENTS_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in AGENTS.md after second write" >&2
  exit 1
fi

# Verify region contents actually changed.
if ! grep -qF "fragment two" "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md region content was not replaced" >&2; exit 1
fi
if ! grep -qF "fragment two" "$SCRATCH/AGENTS.md"; then
  echo "FAIL: AGENTS.md region content was not replaced" >&2; exit 1
fi

# Test dual_write_agents=false gate.
cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: false
EOF

FRAG3="$(mktemp)"
echo "- fragment three: should NOT appear in AGENTS.md" > "$FRAG3"

# Capture the pre-state of AGENTS.md.
PRE_GATE_AGENTS_BYTES="$(cat "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

bash "$HELPER" --marker recent-changes --content "$FRAG3" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: third write (gated) exited non-zero ($RC)" >&2; exit 1
fi

POST_GATE_AGENTS_BYTES="$(cat "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"
if [ "$PRE_GATE_AGENTS_BYTES" != "$POST_GATE_AGENTS_BYTES" ]; then
  echo "FAIL: AGENTS.md was modified despite dual_write_agents=false" >&2; exit 1
fi

if ! grep -qF "fragment three" "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md was not updated on gated write" >&2; exit 1
fi

# Test --dry-run.
DRY_OUT="$(bash "$HELPER" --marker recent-changes --content "$FRAG3" --root "$SCRATCH" --dry-run 2>/dev/null)"
if ! echo "$DRY_OUT" | grep -qE '^\{.*"action_type":"dual-write-region"'; then
  echo "FAIL: --dry-run did not emit JSONL manifest record" >&2; exit 1
fi

echo "PASS: tests/test-dual-write-outside-invariant.sh"
exit 0
