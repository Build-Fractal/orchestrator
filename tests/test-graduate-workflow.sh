#!/usr/bin/env bash
# tests/test-graduate-workflow.sh — SC-2 end-to-end integration test for the
# P03 graduate.sh extension. Exercises the four operational modes that landed
# in T01 (decision-history helper) + T02 (graduate.sh extension):
#
#   1. Three-entry cluster graduate (canonical + 2 siblings)
#   2. Single-entry cluster graduate (canonical only)
#   3. Cluster reject (every member archived)
#   4. Cluster-membership-drift abort (zero file mutations)
#
# MEM002 conventions: pass()/fail() parallel-indexed scalars, tempdir+trap
# fixture isolation, PROJECT_ROOT + ORCH_ROOT env overrides, summary count.
# Bash 3.2 safe. AD-19 single-script-file shape.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

# --- pass()/fail() with parallel-indexed scalars (no declare -A) ---
pass_count=0
fail_count=0
fail_msgs=""

pass() {
  pass_count=$(( pass_count + 1 ))
  printf 'PASS: %s\n' "$1"
}

fail() {
  fail_count=$(( fail_count + 1 ))
  printf 'FAIL: %s\n' "$1"
  fail_msgs="$fail_msgs
$1"
}

# --- portable md5 (macOS + linux) ---
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

# --- jsonl event counter (returns single integer; tolerates rc=1 grep) ---
# Avoids the `grep -c X || echo 0` pattern, which doubles the output line
# when grep itself prints 0 AND the failure branch echoes 0.
count_event() {
  local pattern="$1" file="$2"
  if [ ! -f "$file" ]; then
    printf '0'
    return 0
  fi
  local n
  n="$(grep -c "$pattern" "$file" 2>/dev/null || true)"
  if [ -z "$n" ]; then
    n=0
  fi
  printf '%s' "$n"
}

# --- frontmatter readers (read first --- block) ---
fm_get() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { n++; if (n>=2) exit; next }
    n==1 {
      pat = "^" k ":[[:space:]]"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    }
  ' "$file"
}

fm_has_block_key() {
  local file="$1" key="$2"
  grep -q "^${key}:" "$file"
}

# --- Test fixtures isolation ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

LOG="$ORCH_ROOT/execution-log.jsonl"

# =====================================================================
# Case 1 (SC-2 main): three-entry cluster graduate
# =====================================================================
case1_setup() {
  for id in MEM700 MEM701 MEM702; do
    cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: SC-2 case 1 fixture
EOF
  done
}
case1_setup

if bash "$SCRIPT" --cluster Cint --rationale "merge - same assertion" \
       MEM700 MEM701 MEM702 >/dev/null 2>"$tmpdir/case1.err"; then
  s_canon="$(fm_get "$tmpdir/knowledge/patterns/MEM700.md" status)"
  s_701="$(fm_get "$tmpdir/knowledge/patterns/MEM701.md" status)"
  s_702="$(fm_get "$tmpdir/knowledge/patterns/MEM702.md" status)"
  ai_701="$(fm_get "$tmpdir/knowledge/patterns/MEM701.md" archived_into)"
  ai_702="$(fm_get "$tmpdir/knowledge/patterns/MEM702.md" archived_into)"

  [ "$s_canon" = "graduated" ] && pass "case1: MEM700 graduated" \
    || fail "case1: MEM700 status='$s_canon' (expected graduated)"
  [ "$s_701" = "archived" ] && pass "case1: MEM701 archived" \
    || fail "case1: MEM701 status='$s_701' (expected archived)"
  [ "$s_702" = "archived" ] && pass "case1: MEM702 archived" \
    || fail "case1: MEM702 status='$s_702' (expected archived)"
  [ "$ai_701" = "MEM700" ] && pass "case1: MEM701 archived_into=MEM700" \
    || fail "case1: MEM701 archived_into='$ai_701' (expected MEM700)"
  [ "$ai_702" = "MEM700" ] && pass "case1: MEM702 archived_into=MEM700" \
    || fail "case1: MEM702 archived_into='$ai_702' (expected MEM700)"

  for id in MEM700 MEM701 MEM702; do
    if fm_has_block_key "$tmpdir/knowledge/patterns/${id}.md" decision_history; then
      pass "case1: $id has decision_history block"
    else
      fail "case1: $id missing decision_history block"
    fi
    if grep -q 'merge - same assertion' "$tmpdir/knowledge/patterns/${id}.md"; then
      pass "case1: $id decision_history carries rationale"
    else
      fail "case1: $id decision_history missing rationale"
    fi
  done

  if [ -f "$LOG" ]; then
    g_count="$(count_event '"event":"knowledge_graduate"' "$LOG")"
    a_count="$(count_event '"event":"knowledge_archive"' "$LOG")"
    [ "$g_count" -ge 1 ] && pass "case1: knowledge_graduate JSONL emitted" \
      || fail "case1: knowledge_graduate JSONL missing (count=$g_count)"
    [ "$a_count" -ge 2 ] && pass "case1: 2 knowledge_archive JSONL emitted" \
      || fail "case1: knowledge_archive JSONL count=$a_count (expected >=2)"
  else
    fail "case1: execution-log.jsonl not created at $LOG"
  fi
else
  fail "case1: graduate.sh --cluster exited non-zero. stderr: $(cat "$tmpdir/case1.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 2: single-entry cluster graduate
# =====================================================================
> "$LOG"
cat >"$tmpdir/knowledge/patterns/MEM710.md" <<'EOF'
---
id: MEM710
status: candidate
last_verified: 2026-04-25
---

# MEM710: case 2 fixture
EOF

if bash "$SCRIPT" --cluster Csingle --rationale "lone candidate" \
       MEM710 >/dev/null 2>"$tmpdir/case2.err"; then
  s="$(fm_get "$tmpdir/knowledge/patterns/MEM710.md" status)"
  ai="$(fm_get "$tmpdir/knowledge/patterns/MEM710.md" archived_into)"
  [ "$s" = "graduated" ] && pass "case2: MEM710 graduated (single-entry cluster)" \
    || fail "case2: MEM710 status='$s' (expected graduated)"
  [ -z "$ai" ] && pass "case2: MEM710 has no archived_into (canonical)" \
    || fail "case2: MEM710 archived_into='$ai' (expected empty)"
  if fm_has_block_key "$tmpdir/knowledge/patterns/MEM710.md" decision_history; then
    pass "case2: MEM710 has decision_history block"
  else
    fail "case2: MEM710 missing decision_history block"
  fi

  g_count="$(count_event '"event":"knowledge_graduate"' "$LOG")"
  a_count="$(count_event '"event":"knowledge_archive"' "$LOG")"
  [ "$g_count" -eq 1 ] && pass "case2: 1 knowledge_graduate JSONL" \
    || fail "case2: knowledge_graduate count=$g_count (expected 1)"
  [ "$a_count" -eq 0 ] && pass "case2: 0 knowledge_archive JSONL" \
    || fail "case2: knowledge_archive count=$a_count (expected 0)"
else
  fail "case2: graduate.sh --cluster Csingle exited non-zero. stderr: $(cat "$tmpdir/case2.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 3: cluster reject
# =====================================================================
> "$LOG"
for id in MEM720 MEM721; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: case 3 reject fixture
EOF
done

if bash "$SCRIPT" --reject --cluster Crej --rationale "superseded by M021" \
       MEM720 MEM721 >/dev/null 2>"$tmpdir/case3.err"; then
  for id in MEM720 MEM721; do
    s="$(fm_get "$tmpdir/knowledge/patterns/${id}.md" status)"
    [ "$s" = "archived" ] && pass "case3: $id archived (reject)" \
      || fail "case3: $id status='$s' (expected archived)"
    if grep -q '^archived_into:' "$tmpdir/knowledge/patterns/${id}.md"; then
      fail "case3: $id has archived_into (rejection should not write it)"
    else
      pass "case3: $id has no archived_into (rejection)"
    fi
    if grep -q 'superseded by M021' "$tmpdir/knowledge/patterns/${id}.md"; then
      pass "case3: $id decision_history carries rejection rationale"
    else
      fail "case3: $id decision_history missing rationale"
    fi
  done

  g_count="$(count_event '"event":"knowledge_graduate"' "$LOG")"
  a_count="$(count_event '"event":"knowledge_archive"' "$LOG")"
  [ "$g_count" -eq 0 ] && pass "case3: 0 knowledge_graduate (reject)" \
    || fail "case3: knowledge_graduate count=$g_count (expected 0 on reject)"
  [ "$a_count" -eq 2 ] && pass "case3: 2 knowledge_archive (reject)" \
    || fail "case3: knowledge_archive count=$a_count (expected 2 on reject)"
else
  fail "case3: graduate.sh --reject exited non-zero. stderr: $(cat "$tmpdir/case3.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 4: cluster-membership-drift abort (zero file mutations)
# =====================================================================
> "$LOG"
cat >"$tmpdir/knowledge/patterns/MEM730.md" <<'EOF'
---
id: MEM730
status: candidate
last_verified: 2026-04-25
---

# MEM730: drift fixture (candidate)
EOF

cat >"$tmpdir/knowledge/patterns/MEM731.md" <<'EOF'
---
id: MEM731
status: graduated
last_verified: 2026-04-25
---

# MEM731: drift fixture (already graduated -> drift)
EOF

md5_pre_730="$(md5_of "$tmpdir/knowledge/patterns/MEM730.md")"
md5_pre_731="$(md5_of "$tmpdir/knowledge/patterns/MEM731.md")"

set +e
out4="$(bash "$SCRIPT" --cluster Cdrift --rationale "test" MEM730 MEM731 2>&1)"
rc4=$?
set -e

[ "$rc4" -ne 0 ] && pass "case4: drift abort returned non-zero" \
  || fail "case4: drift abort returned 0 (expected non-zero). out=$out4"

case "$out4" in
  *"cluster-membership-drift"*) pass "case4: 'cluster-membership-drift' diagnostic emitted" ;;
  *) fail "case4: missing 'cluster-membership-drift' diagnostic. Got: $out4" ;;
esac

md5_post_730="$(md5_of "$tmpdir/knowledge/patterns/MEM730.md")"
md5_post_731="$(md5_of "$tmpdir/knowledge/patterns/MEM731.md")"

[ "$md5_pre_730" = "$md5_post_730" ] && pass "case4: MEM730 byte-identical (atomic abort)" \
  || fail "case4: MEM730 mutated despite drift abort"
[ "$md5_pre_731" = "$md5_post_731" ] && pass "case4: MEM731 byte-identical (atomic abort)" \
  || fail "case4: MEM731 mutated despite drift abort"

if [ ! -s "$LOG" ]; then
  pass "case4: no JSONL records emitted on drift abort"
else
  drift_records="$(count_event 'Cdrift' "$LOG")"
  [ "$drift_records" -eq 0 ] && pass "case4: zero Cdrift JSONL records" \
    || fail "case4: $drift_records JSONL records emitted on drift (expected 0)"
fi

# =====================================================================
# Summary
# =====================================================================
total=$(( pass_count + fail_count ))
printf '\n--- Summary: %d/%d cases PASS ---\n' "$pass_count" "$total"

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d test cases failed\n' "$fail_count" >&2
  exit 1
fi

printf 'SC-2 + drift abort: all %d cases PASS\n' "$total"
exit 0
