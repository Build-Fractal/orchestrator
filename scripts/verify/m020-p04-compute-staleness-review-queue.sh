#!/usr/bin/env bash
# scripts/verify/m020-p04-compute-staleness-review-queue.sh
#
# M020/P04/T01 truth verifier: scripts/knowledge/compute-staleness.sh
# accepts --review-queue [--knowledge-root <path>] and emits the documented
# cluster_id=<C8hex> topic=<t> count=<N> oldest_age=<d> stale=<true|false>
# stdout shape per FR-4. Empty candidate set emits exactly the literal EMPTY
# (one line, no trailing fields). Legacy invocation (no flag) preserves the
# STALENESS REPORT header byte-equivalent per CON-4.
#
# AD-19 single-script-file shape; MEM001 PASS/FAIL prefix conventions.
# Bash 3.2 safe (no `declare -A`, no `mapfile`, no `<<<` into `$()`).
# Read-only against knowledge/** and .orchestrator/execution-log.jsonl —
# all fixture state lives under mktemp -d + trap EXIT rm -rf.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/compute-staleness.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: compute-staleness.sh not found at $SCRIPT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

pass_count=0
fail_count=0

pass() {
  pass_count=$(( pass_count + 1 ))
  printf 'PASS: %s\n' "$1"
}

fail() {
  fail_count=$(( fail_count + 1 ))
  printf 'FAIL: %s\n' "$1"
}

# ----------------------------------------------------------------------------
# Check 1: legacy invocation (no flag) preserves STALENESS REPORT header.
# ----------------------------------------------------------------------------
legacy_first_line="$(bash "$SCRIPT" 2>/dev/null | head -1 || true)"
case "$legacy_first_line" in
  "STALENESS REPORT (as of "*)
    pass "legacy invocation first line begins with 'STALENESS REPORT (as of '"
    ;;
  *)
    fail "legacy first line was: $legacy_first_line (expected STALENESS REPORT prefix)"
    ;;
esac

# ----------------------------------------------------------------------------
# Check 2: --review-queue against an empty fixture -> stdout exactly EMPTY,
#          exit 0.
# ----------------------------------------------------------------------------
empty_fixture="$tmpdir/empty"
mkdir -p "$empty_fixture/patterns"
empty_out="$(bash "$SCRIPT" --review-queue --knowledge-root "$empty_fixture" 2>/dev/null)"
empty_rc=$?
if [ "$empty_rc" -ne 0 ]; then
  fail "empty fixture exit was $empty_rc (expected 0)"
elif [ "$empty_out" = "EMPTY" ]; then
  pass "empty fixture stdout is exactly 'EMPTY' and exit 0"
else
  fail "empty fixture stdout was: $(printf '%s' "$empty_out" | head -3) (expected EMPTY)"
fi

# ----------------------------------------------------------------------------
# Check 3: --review-queue against a single-candidate fixture emits exactly one
#          well-formed cluster_id line of the documented shape, exit 0.
# ----------------------------------------------------------------------------
single_fixture="$tmpdir/single"
mkdir -p "$single_fixture/patterns"
cat >"$single_fixture/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
topic: shell utilities
tags: [shell, utilities]
relates_to: []
source_unit: M999/P01
created_at: 2026-01-01
---

# MEM900: candidate fixture
single candidate body for review-queue verifier
EOF

single_out="$(bash "$SCRIPT" --review-queue --knowledge-root "$single_fixture" 2>/dev/null)"
single_rc=$?
if [ "$single_rc" -ne 0 ]; then
  fail "single-candidate exit was $single_rc (expected 0)"
fi

single_line_count="$(printf '%s\n' "$single_out" | grep -c '^cluster_id=' || true)"
if [ "$single_line_count" -ne 1 ]; then
  fail "single-candidate emitted $single_line_count cluster_id lines (expected 1). Output: $single_out"
else
  pass "single-candidate emitted exactly one cluster_id line"
fi

# Documented shape: cluster_id=<C8hex> topic=<t> count=<N> oldest_age=<d> stale=<true|false>
shape_re='^cluster_id=C[0-9a-f]{8} topic=[^ ]* count=[0-9]+ oldest_age=[0-9]+ stale=(true|false)$'
single_first_line="$(printf '%s\n' "$single_out" | grep '^cluster_id=' | head -1)"
if printf '%s' "$single_first_line" | grep -E -q "$shape_re"; then
  pass "single-candidate line matches documented cluster_id=<C8hex> topic=<t> count=<N> oldest_age=<d> stale=<true|false> shape"
else
  fail "single-candidate line did not match documented shape: $single_first_line"
fi

# ----------------------------------------------------------------------------
# Check 4: cluster_id token matches AD-3 ^C[0-9a-f]{8}$ exactly.
# ----------------------------------------------------------------------------
cid_token="$(printf '%s' "$single_first_line" | awk '{print $1}' | sed 's/^cluster_id=//')"
if printf '%s' "$cid_token" | grep -E -q '^C[0-9a-f]{8}$'; then
  pass "cluster_id token '$cid_token' matches AD-3 regex ^C[0-9a-f]{8}$"
else
  fail "cluster_id token '$cid_token' does not match AD-3 regex ^C[0-9a-f]{8}$"
fi

# ----------------------------------------------------------------------------
# Check 5: --review-queue against a multi-entry fixture (two unrelated
#          candidates plus one graduated entry) emits two cluster lines and
#          excludes the graduated entry. Output sorted by cluster_id ascending.
# ----------------------------------------------------------------------------
multi_fixture="$tmpdir/multi"
mkdir -p "$multi_fixture/patterns"
cat >"$multi_fixture/patterns/MEM910.md" <<'EOF'
---
id: MEM910
status: candidate
topic: zebra
tags: [zebra]
relates_to: []
source_unit: M999/P01
created_at: 2026-04-22
---

# MEM910: zebra
zebra zoological zenith zephyr zone
EOF

cat >"$multi_fixture/patterns/MEM911.md" <<'EOF'
---
id: MEM911
status: candidate
topic: walrus
tags: [walrus]
relates_to: []
source_unit: M999/P01
created_at: 2026-04-15
---

# MEM911: walrus
walrus waltz waxen wedge winch
EOF

cat >"$multi_fixture/patterns/MEM920.md" <<'EOF'
---
id: MEM920
status: graduated
topic: ferret
tags: [ferret]
relates_to: []
source_unit: M999/P01
created_at: 2025-12-01
---

# MEM920: graduated entry — must be excluded by candidate filter.
ferret figment frost fjord furrow
EOF

multi_out="$(bash "$SCRIPT" --review-queue --knowledge-root "$multi_fixture" 2>/dev/null)"
multi_rc=$?
if [ "$multi_rc" -ne 0 ]; then
  fail "multi-fixture exit was $multi_rc (expected 0)"
fi

multi_line_count="$(printf '%s\n' "$multi_out" | grep -c '^cluster_id=' || true)"
if [ "$multi_line_count" -eq 2 ]; then
  pass "multi-fixture emitted exactly 2 cluster lines (graduated entry excluded)"
else
  fail "multi-fixture emitted $multi_line_count cluster lines (expected 2). Output: $multi_out"
fi

# Confirm graduated entry topic 'ferret' is absent from the output.
if printf '%s\n' "$multi_out" | grep -q 'topic=ferret'; then
  fail "multi-fixture output contains topic=ferret (graduated entry leaked into review queue)"
else
  pass "multi-fixture output excludes graduated entry (topic=ferret absent)"
fi

# Confirm output is sorted ascending by cluster_id.
multi_cids="$(printf '%s\n' "$multi_out" | grep '^cluster_id=' | awk '{print $1}' | sed 's/^cluster_id=//')"
multi_cids_sorted="$(printf '%s\n' "$multi_cids" | LC_ALL=C sort)"
if [ "$multi_cids" = "$multi_cids_sorted" ]; then
  pass "multi-fixture cluster_id lines are sorted ascending"
else
  fail "multi-fixture cluster_id lines not sorted ascending. Got:\n$multi_cids\nExpected:\n$multi_cids_sorted"
fi

# Each emitted line must conform to the documented shape regex.
shape_violations=0
for cid_line_idx in 1 2; do
  line="$(printf '%s\n' "$multi_out" | grep '^cluster_id=' | sed -n "${cid_line_idx}p")"
  [ -z "$line" ] && continue
  if ! printf '%s' "$line" | grep -E -q "$shape_re"; then
    shape_violations=$(( shape_violations + 1 ))
  fi
done
if [ "$shape_violations" -eq 0 ]; then
  pass "multi-fixture every cluster line matches documented shape"
else
  fail "multi-fixture $shape_violations cluster line(s) violate documented shape"
fi

# ----------------------------------------------------------------------------
# Final tally.
# ----------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-compute-staleness-review-queue: %d/%d checks passed ---\n' "$pass_count" "$total"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
