#!/usr/bin/env bash
# tools/verify/m036-p05-scope-filter-baseline.sh — CON-5 regression guard.
#
# Asserts that scripts/dispatch/scope-filter.sh default invocation (no --tag flag)
# is byte-identical to pre-P05 for a fixture KNOWLEDGE-INDEX.md containing only
# pre-P05 tag namespaces ([project], [milestone:M001], [phase:M001/P02]).
#
# Stages the 3-row fixture under mktemp, invokes:
#   scope-filter.sh <fixture> M001/P02 --type knowledge
# and diffs stdout against the baseline file captured BEFORE T03's edits.
#
# Baseline file: tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt
# (captured 2026-05-02 from the unmodified scripts/dispatch/scope-filter.sh).
#
# Any byte-level diff exits 1 with diagnostic output.
#
# T03 of M036/P05: regression guard. Single-script-file invocation per AD-19.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

baseline="$ROOT/tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt"
if [ ! -f "$baseline" ]; then
  echo "FAIL: m036-p05-scope-filter-baseline (baseline file missing at $baseline)" >&2
  exit 1
fi

# Stage a fixture KNOWLEDGE-INDEX.md with three pre-P05 tag namespaces.
# Mirror the corpus used at baseline-capture time so the filter emits
# byte-identical output.
fixture="$tmpdir/KNOWLEDGE-INDEX.md"
cat > "$fixture" <<'EOF_FIXTURE'
# Knowledge Index
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->

MEM001 | [project] | patterns | 0.95 | 2026-01-01 | verified:2026-01-01 | hits:1 | A
MEM002 | [milestone:M001] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:1 | B
MEM003 | [phase:M001/P02] | patterns | 0.95 | 2026-01-01 | verified:2026-01-01 | hits:1 | C
EOF_FIXTURE

# Run scope-filter.sh in default mode (NO --tag flag) — must produce
# byte-identical output to the pre-P05 baseline.
actual="$tmpdir/actual.txt"
bash "$ROOT/scripts/dispatch/scope-filter.sh" \
  "$fixture" M001/P02 --type knowledge \
  > "$actual"

# Byte-level diff against the baseline
if cmp -s "$baseline" "$actual"; then
  echo "PASS: m036-p05-scope-filter-baseline (CON-5 byte-identical)"
  exit 0
fi

# Find diagnostic output for the first differing line
exp_first="$(head -1 "$baseline")"
got_first="$(head -1 "$actual")"
echo "FAIL: CON-5 regression — scope-filter.sh default mode differs from pre-P05 baseline" >&2
echo "  baseline first line: '${exp_first}'" >&2
echo "  actual first line:   '${got_first}'" >&2
echo "full diff:" >&2
diff "$baseline" "$actual" >&2 || true
exit 1
