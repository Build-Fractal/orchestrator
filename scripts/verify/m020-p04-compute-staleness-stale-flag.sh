#!/usr/bin/env bash
# scripts/verify/m020-p04-compute-staleness-stale-flag.sh
#
# M020/P04/T03 truth verifier: scripts/knowledge/compute-staleness.sh
# --review-queue resolves the per-cluster `stale=true|false` flag correctly
# against the configured staleness_threshold (default 14 days per OQ-1).
#
# Two scenarios:
#   1. A candidate created clearly outside the threshold window
#      (created_at: 2024-01-01) -> stale=true
#   2. A candidate created today
#      (created_at: $TODAY)     -> stale=false
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

mkdir -p "$tmpdir/k/patterns"

# ---------------------------------------------------------------------------
# Case 1: clearly-stale candidate (created Jan 2024, well > 14 days old).
# Two entries with overlapping vocabulary so cluster.sh produces one cluster
# (the stale flag is computed off the cluster's oldest member).
# ---------------------------------------------------------------------------
cat >"$tmpdir/k/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
created_at: 2024-01-01
last_verified: 2024-01-01
topic: zebra_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

zebra zebra zebra ancient candidate body tokens
EOF

cat >"$tmpdir/k/patterns/MEM901.md" <<'EOF'
---
id: MEM901
status: candidate
created_at: 2024-01-02
last_verified: 2024-01-02
topic: zebra_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

zebra zebra zebra ancient candidate body tokens
EOF

stale_out="$(bash "$SCRIPT" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/stale.err" || true)"
stale_rc=$?

if [ "$stale_rc" -ne 0 ]; then
  fail "stale fixture exit rc=$stale_rc; stderr: $(cat "$tmpdir/stale.err" 2>/dev/null)"
else
  pass "stale fixture: --review-queue exits 0"
fi

if printf '%s\n' "$stale_out" | grep -qE '^cluster_id=C[0-9a-f]{8} .* stale=true( |$)'; then
  pass "stale fixture: cluster line carries stale=true"
else
  fail "stale fixture: no cluster line with stale=true; got: $stale_out"
fi

case "$stale_out" in
  *stale=false*)
    fail "stale fixture: cluster line incorrectly carries stale=false: $stale_out"
    ;;
  *)
    pass "stale fixture: stdout contains no stale=false token"
    ;;
esac

# ---------------------------------------------------------------------------
# Case 2: fresh candidates (created today, age=0 < threshold=14).
# Replace the stale fixture with two same-day entries.
# ---------------------------------------------------------------------------
TODAY="$(date -u +%Y-%m-%d)"

cat >"$tmpdir/k/patterns/MEM900.md" <<EOF
---
id: MEM900
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: walrus_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

walrus walrus walrus fresh candidate body tokens
EOF

cat >"$tmpdir/k/patterns/MEM901.md" <<EOF
---
id: MEM901
status: candidate
created_at: $TODAY
last_verified: $TODAY
topic: walrus_topic
tags: [test]
confidence: 0.5
hit_count: 0
---

walrus walrus walrus fresh candidate body tokens
EOF

fresh_out="$(bash "$SCRIPT" --review-queue --knowledge-root "$tmpdir/k" 2>"$tmpdir/fresh.err" || true)"
fresh_rc=$?

if [ "$fresh_rc" -ne 0 ]; then
  fail "fresh fixture exit rc=$fresh_rc; stderr: $(cat "$tmpdir/fresh.err" 2>/dev/null)"
else
  pass "fresh fixture: --review-queue exits 0"
fi

if printf '%s\n' "$fresh_out" | grep -qE '^cluster_id=C[0-9a-f]{8} .* stale=false( |$)'; then
  pass "fresh fixture: cluster line carries stale=false"
else
  fail "fresh fixture: no cluster line with stale=false; got: $fresh_out"
fi

case "$fresh_out" in
  *stale=true*)
    fail "fresh fixture: cluster line incorrectly carries stale=true: $fresh_out"
    ;;
  *)
    pass "fresh fixture: stdout contains no stale=true token"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-compute-staleness-stale-flag: %s/%s checks passed ---\n' \
  "$pass_count" "$total"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
