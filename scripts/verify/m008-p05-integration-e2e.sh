#!/usr/bin/env bash
# P05 integration e2e: auto-detect -> register into hermetic HOME ->
# format adapter round-trip -> dispatch through P02 dispatch-interface.
#
# Fixtures use mktemp -d exclusively; the real developer HOME is never
# modified. Per AD-19, only single-script-file invocations and sequential
# statements are used — no process substitution, no $() with pipes.
set -u

fail() { echo "FAIL: $*"; exit 1; }
step() { echo "STEP: $*"; }

# Verify prerequisites exist.
required=(
  "scripts/dispatch/detect-runtime.sh"
  "scripts/dispatch/adapters/runtime/claude-code.sh"
  "scripts/dispatch/adapters/runtime/codex.sh"
  "scripts/dispatch/adapters/runtime/cursor.sh"
  "scripts/dispatch/adapters/format/native.sh"
  "scripts/dispatch/adapters/format/speckit.sh"
  "scripts/dispatch/dispatch-interface.sh"
)
for f in "${required[@]}"; do
  [[ -f "$f" ]] || fail "$f missing"
done

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

home_fix="$tmproot/home"
project_fix="$tmproot/project"
mkdir -p "$home_fix" "$project_fix"

# --- Step 1: detect-runtime --force claude-code ---
step "detect-runtime --force claude-code"
out="$(HOME="$home_fix" bash scripts/dispatch/detect-runtime.sh --force claude-code 2>/dev/null)"
echo "$out" | grep -qE '^runtime=claude-code$' || fail "detect-runtime --force claude-code did not yield runtime=claude-code"

# --- Step 2: claude-code --probe ---
step "claude-code --probe"
out="$(HOME="$home_fix" bash scripts/dispatch/adapters/runtime/claude-code.sh --probe 2>/dev/null)"
echo "$out" | grep -qE '^available=' || fail "claude-code --probe missing available="

# --- Step 3: claude-code --register --dry-run ---
step "claude-code --register --dry-run"
out="$(HOME="$home_fix" bash scripts/dispatch/adapters/runtime/claude-code.sh --register --dry-run 2>/dev/null)"
echo "$out" | grep -qE '^would_write=' || fail "claude-code --dry-run missing would_write="
[[ ! -d "$home_fix/.claude" ]] || fail "claude-code --dry-run wrote to \$HOME/.claude"

# --- Step 4: claude-code --register (hermetic) ---
step "claude-code --register (hermetic HOME)"
HOME="$home_fix" bash scripts/dispatch/adapters/runtime/claude-code.sh --register >/dev/null 2>&1 \
  || fail "claude-code --register failed"
count="$(find "$home_fix/.claude/commands" -type f -name 'orchestrator-*.md' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$count" != "0" ]] || fail "claude-code --register wrote no orchestrator-*.md files"

# --- Step 5: native.sh --read on a task-plan fixture ---
step "native.sh --read round-trip"
fixture="$tmproot/task-plan.md"
cat > "$fixture" <<'EOF'
---
schema_version: "1.0"
type: "task-plan"
task: "T01"
phase: "P05"
milestone: "M008"
name: "integration fixture"
depends_on: []
---

## Description

e2e fixture
EOF
out="$(bash scripts/dispatch/adapters/format/native.sh --read "$fixture" 2>/dev/null)"
echo "$out" | grep -qE '^task: "T01"' || fail "native.sh --read did not preserve task"

# --- Step 6: speckit.sh --read + round-trip through native ---
step "speckit.sh --read -> native validator"
mkdir -p "$tmproot/specs/example"
cat > "$tmproot/specs/example/tasks.md" <<'EOF'
# Tasks

## T01: Integration task

Do the thing.
EOF
speckit_out="$tmproot/speckit-out.md"
bash scripts/dispatch/adapters/format/speckit.sh --read "$tmproot/specs/example/tasks.md" > "$speckit_out" 2>/dev/null \
  || fail "speckit.sh --read failed"
bash scripts/dispatch/adapters/format/native.sh --read "$speckit_out" >/dev/null 2>&1 \
  || fail "speckit.sh output did not validate via native.sh --read"

# --- Step 7: dispatch-interface with local-agent backend ---
step "dispatch-interface.sh via local-agent"
payload="$tmproot/payload.md"
echo "payload stub" > "$payload"
export SPECKIT_AGENT_TOOL=1
dispatch_out="$tmproot/dispatch.out"
HOME="$home_fix" bash scripts/dispatch/dispatch-interface.sh \
  --task-plan "$fixture" \
  --payload "$payload" \
  --intensity-metadata "$payload" \
  --backend local-agent > "$dispatch_out" 2>/dev/null \
  || fail "dispatch-interface.sh --backend local-agent failed"
grep -qE '^type: "dispatch-result"' "$dispatch_out" \
  || fail "dispatch-interface output missing type: dispatch-result"

echo "PASS: P05 integration e2e (auto-detect -> register -> format round-trip -> dispatch)"
