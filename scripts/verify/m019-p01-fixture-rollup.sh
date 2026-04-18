#!/usr/bin/env bash
# scripts/verify/m019-p01-fixture-rollup.sh — SC-7 greppability demo.
#
# Parses tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl, groups
# unit_close records by granularity, sums estimated_cost_usd (ignoring null),
# prints a three-line ROLLUP: table. Demonstrates that a future rollup
# script (Tier 2) can consume the records without schema changes.
#
# THIS SCRIPT IS VERIFICATION-ONLY. It is NOT orchestrator:cost. It is
# NOT scripts/diagnostics/metrics-rollup.sh. It does not install any
# user-facing surface. Its sole purpose is to demonstrate SC-7 by
# succeeding against the fixture.
#
# On green:
#   ROLLUP: granularity=task      records=N  total_usd=X.XXXXXXXX
#   ROLLUP: granularity=phase     records=N  total_usd=X.XXXXXXXX
#   ROLLUP: granularity=milestone records=N  total_usd=X.XXXXXXXX
#   PASS: m019-p01-fixture-rollup.sh
# Exit 0.
#
# Bash 3.2 compatible. MEM004 carve-out — awk permitted.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$REPO_ROOT/tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl"

if [ ! -f "$FIX" ]; then
  echo "FAIL: fixture not found: $FIX"
  exit 1
fi

# awk: for each unit_close record, extract granularity + estimated_cost_usd,
# accumulate counts + sums by granularity. Null cost is counted but not summed.
awk '
  function extract_field(line, key,    n, parts, i, val) {
    n = split(line, parts, "\"")
    for (i = 1; i <= n; i++) {
      if (parts[i] == key && i + 2 <= n) {
        return parts[i + 2]
      }
    }
    return ""
  }
  /"record_type":"unit_close"/ {
    gran = extract_field($0, "granularity")
    if (gran == "") { next }
    count[gran] = count[gran] + 1
    # estimated_cost_usd is a numeric or null; the "extract between quotes"
    # approach misses it. Use a regex to pick the value.
    if (match($0, /"estimated_cost_usd":[^,}]+/)) {
      raw = substr($0, RSTART, RLENGTH)
      sub(/"estimated_cost_usd":/, "", raw)
      gsub(/[[:space:]]/, "", raw)
      if (raw != "null" && raw != "") {
        sum[gran] = sum[gran] + (raw + 0)
      }
    }
  }
  END {
    order[1] = "task"; order[2] = "phase"; order[3] = "milestone"
    for (i = 1; i <= 3; i++) {
      g = order[i]
      c = count[g] + 0
      s = sum[g] + 0
      printf "ROLLUP: granularity=%-9s records=%d  total_usd=%.8f\n", g, c, s
    }
  }
' "$FIX"

echo "PASS: m019-p01-fixture-rollup.sh"
exit 0
