#!/usr/bin/env bash
# m020-p06-consolidate-effective-threshold.sh — assert consolidate-artifacts.sh
# --cluster resolves similarity_threshold from preferences (project>user>built-in)
# and emits a single `effective_threshold=<N>` line BEFORE per-cluster blocks.
# Covers SC-5 + line-ordering invariant.
# Bash 3.2 safe. AD-19 single-script-file shape. MEM002 conventions.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Parallel-scalar pass/fail tracking (MEM002, no declare -A).
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

# Fixtures.
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"
mkdir -p "$tmpdir/project/.orchestrator"
mkdir -p "$tmpdir/userhome/.orchestrator"

# Three candidate entries (cluster_compute requires status: candidate).
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
topic: alpha-cluster
tags: [alpha, common]
relates_to: [MEM901]
source_unit: M999/P01
---

# MEM900: entry one
alpha beta gamma delta common shared body words
EOF

cat >"$tmpdir/knowledge/patterns/MEM901.md" <<'EOF'
---
id: MEM901
status: candidate
topic: alpha-cluster
tags: [alpha, common]
relates_to: [MEM900]
source_unit: M999/P01
---

# MEM901: entry two
alpha beta gamma delta common shared body words
EOF

cat >"$tmpdir/knowledge/patterns/MEM902.md" <<'EOF'
---
id: MEM902
status: candidate
topic: distinct
tags: [unique]
relates_to: []
source_unit: M999/P02
---

# MEM902: distinct entry
epsilon zeta eta theta unique body
EOF

KNOWLEDGE_ROOT="$tmpdir/knowledge"
ORCH_ROOT="$tmpdir/orch-state"

run_cluster() {
  # Args: [<cli-threshold>]
  out_file="$tmpdir/out.$$"
  if [ "$#" -ge 1 ] && [ -n "$1" ]; then
    PROJECT_ROOT="$tmpdir/project" HOME="$tmpdir/userhome" \
      bash "$SCRIPT" --cluster "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" "$1" \
      >"$out_file" 2>&1
  else
    PROJECT_ROOT="$tmpdir/project" HOME="$tmpdir/userhome" \
      bash "$SCRIPT" --cluster "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" \
      >"$out_file" 2>&1
  fi
  cat "$out_file"
}

# --- Case A: project=0.6 user=0.8 -> expect effective_threshold=0.6 ---
cat >"$tmpdir/project/.orchestrator/preferences.yml" <<'EOF'
similarity_threshold: 0.6
EOF
cat >"$tmpdir/userhome/.orchestrator/preferences.yml" <<'EOF'
similarity_threshold: 0.8
EOF

caseA_out="$(run_cluster)"
if printf '%s\n' "$caseA_out" | grep -q '^effective_threshold=0\.6$'; then
  pass "case A project=0.6 user=0.8 -> effective_threshold=0.6"
else
  fail "case A: expected effective_threshold=0.6, got:"
  printf '%s\n' "$caseA_out"
fi

# --- Case A2 (line-ordering invariant): effective_threshold= line precedes first cluster_id= line ---
ordering_check="$(printf '%s\n' "$caseA_out" | awk '
  /^effective_threshold=/ { if (!eff_seen) { eff_line=NR; eff_seen=1 } }
  /^cluster_id=/ { if (!cid_seen) { cid_line=NR; cid_seen=1 } }
  END {
    if (!eff_seen) { print "no_eff"; exit }
    if (!cid_seen) { print "no_cid"; exit }
    if (eff_line < cid_line) print "ok"; else print "out_of_order"
  }
')"
if [ "$ordering_check" = "ok" ]; then
  pass "case A effective_threshold= line precedes first cluster_id= line"
else
  fail "case A line-ordering invariant violated: $ordering_check"
  printf '%s\n' "$caseA_out"
fi

# --- Case B: remove project file -> expect effective_threshold=0.8 (user wins) ---
rm -f "$tmpdir/project/.orchestrator/preferences.yml"

caseB_out="$(run_cluster)"
if printf '%s\n' "$caseB_out" | grep -q '^effective_threshold=0\.8$'; then
  pass "case B user-only=0.8 -> effective_threshold=0.8"
else
  fail "case B: expected effective_threshold=0.8, got:"
  printf '%s\n' "$caseB_out"
fi

# --- Case C: remove user file -> expect effective_threshold=0.7 (built-in default) ---
rm -f "$tmpdir/userhome/.orchestrator/preferences.yml"

caseC_out="$(run_cluster)"
if printf '%s\n' "$caseC_out" | grep -q '^effective_threshold=0\.7$'; then
  pass "case C no-pref -> effective_threshold=0.7"
else
  fail "case C: expected effective_threshold=0.7, got:"
  printf '%s\n' "$caseC_out"
fi

# --- Case D: positional CLI threshold 0.5 (no preferences files) -> expect 0.5 ---
caseD_out="$(run_cluster 0.5)"
if printf '%s\n' "$caseD_out" | grep -q '^effective_threshold=0\.5$'; then
  pass "case D CLI=0.5 (no pref) -> effective_threshold=0.5"
else
  fail "case D: expected effective_threshold=0.5, got:"
  printf '%s\n' "$caseD_out"
fi

total=$(( pass_count + fail_count ))
echo "RESULT: $pass_count/$total PASS"
if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
