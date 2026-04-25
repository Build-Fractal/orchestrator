#!/usr/bin/env bash
# m020-p06-consolidate-cli-precedence.sh — assert CLI > preferences precedence
# for consolidate-artifacts.sh --cluster, plus CON-1/FR-8 read-only invariant
# on the preferences files. Built-in default fallback also asserted.
# Bash 3.2 safe. AD-19 single-script-file shape. MEM002 conventions.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

pass_count=0
fail_count=0
pass() {
  pass_count=$(( pass_count + 1 ))
  echo "PASS: $1"
}
fail() {
  fail_count=$(( fail_count + 1 ))
  echo "FAIL: $1"
}

mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"
mkdir -p "$tmpdir/project/.orchestrator"
mkdir -p "$tmpdir/userhome/.orchestrator"

cat >"$tmpdir/knowledge/patterns/MEM910.md" <<'EOF'
---
id: MEM910
status: candidate
topic: shared
tags: [shared]
relates_to: [MEM911]
source_unit: M999/P01
---

# MEM910
alpha beta gamma delta common shared body words
EOF

cat >"$tmpdir/knowledge/patterns/MEM911.md" <<'EOF'
---
id: MEM911
status: candidate
topic: shared
tags: [shared]
relates_to: [MEM910]
source_unit: M999/P01
---

# MEM911
alpha beta gamma delta common shared body words
EOF

cat >"$tmpdir/knowledge/patterns/MEM912.md" <<'EOF'
---
id: MEM912
status: candidate
topic: distinct
tags: [unique]
relates_to: []
source_unit: M999/P02
---

# MEM912
epsilon zeta eta theta unique body
EOF

KNOWLEDGE_ROOT="$tmpdir/knowledge"
ORCH_ROOT="$tmpdir/orch-state"

# Compute md5 portably (mac+linux).
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

# --- Case 1: CLI=0.9 with project=0.3 user=0.4 -> CLI wins ---
cat >"$tmpdir/project/.orchestrator/preferences.yml" <<'EOF'
similarity_threshold: 0.3
EOF
cat >"$tmpdir/userhome/.orchestrator/preferences.yml" <<'EOF'
similarity_threshold: 0.4
EOF

proj_md5_pre="$(md5_of "$tmpdir/project/.orchestrator/preferences.yml")"
user_md5_pre="$(md5_of "$tmpdir/userhome/.orchestrator/preferences.yml")"

case1_out_file="$tmpdir/case1.out"
PROJECT_ROOT="$tmpdir/project" HOME="$tmpdir/userhome" \
  bash "$SCRIPT" --cluster "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" 0.9 \
  >"$case1_out_file" 2>&1
case1_rc=$?

if [ "$case1_rc" -ne 0 ]; then
  fail "case1: consolidate-artifacts.sh --cluster exited $case1_rc"
  cat "$case1_out_file"
fi

if grep -q '^effective_threshold=0\.9$' "$case1_out_file"; then
  pass "CLI=0.9 with project=0.3 user=0.4 -> effective_threshold=0.9"
else
  fail "case1: expected effective_threshold=0.9, got:"
  cat "$case1_out_file"
fi

# --- Case 1 JSONL: threshold_used=0.9 ---
jsonl="$ORCH_ROOT/execution-log.jsonl"
if [ -f "$jsonl" ] && grep -q '"threshold_used":"0.9"' "$jsonl"; then
  pass "JSONL threshold_used=0.9 matches CLI value"
elif [ -f "$jsonl" ] && grep -q 'threshold_used=0.9' "$jsonl"; then
  pass "JSONL threshold_used=0.9 matches CLI value"
else
  fail "JSONL did not record threshold_used=0.9. Contents:"
  if [ -f "$jsonl" ]; then
    cat "$jsonl"
  else
    echo "(JSONL file not found at $jsonl)"
  fi
fi

# --- Case 1 read-only invariant (CON-1 / FR-8): preferences files unchanged ---
proj_md5_post="$(md5_of "$tmpdir/project/.orchestrator/preferences.yml")"
user_md5_post="$(md5_of "$tmpdir/userhome/.orchestrator/preferences.yml")"

if [ "$proj_md5_pre" = "$proj_md5_post" ]; then
  pass "project preferences file md5 unchanged"
else
  fail "project preferences file mutated: $proj_md5_pre -> $proj_md5_post"
fi

if [ "$user_md5_pre" = "$user_md5_post" ]; then
  pass "user preferences file md5 unchanged"
else
  fail "user preferences file mutated: $user_md5_pre -> $user_md5_post"
fi

# --- Case 2 sanity: no preferences files, no positional threshold -> built-in 0.7 ---
rm -f "$tmpdir/project/.orchestrator/preferences.yml"
rm -f "$tmpdir/userhome/.orchestrator/preferences.yml"
rm -f "$jsonl"

case2_out_file="$tmpdir/case2.out"
PROJECT_ROOT="$tmpdir/project" HOME="$tmpdir/userhome" \
  bash "$SCRIPT" --cluster "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" \
  >"$case2_out_file" 2>&1

if grep -q '^effective_threshold=0\.7$' "$case2_out_file"; then
  pass "no-pref no-CLI -> effective_threshold=0.7"
else
  fail "case2: expected effective_threshold=0.7, got:"
  cat "$case2_out_file"
fi

total=$(( pass_count + fail_count ))
echo "RESULT: $pass_count/$total PASS"
if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
