#!/usr/bin/env bash
# scripts/verify/m020-p04-status-review-queue-section.sh
#
# M020/P04/T02 truth verifier: scripts/orchestrator/status.sh emits the
# `Review Queue:` section after the existing MILESTONE: / STATE: / PHASE:
# enumeration. Asserts both the empty-queue rendering (single line
# `Review Queue: empty`) and the non-empty rendering (header
# `Review Queue: <N> clusters, <M> entries awaiting review` + per-cluster
# indented summary lines).
#
# AD-19 single-script-file shape; MEM001 PASS/FAIL prefix conventions.
# Bash 3.2 safe (no `declare -A`, no `mapfile`, no `<<<` into `$()`).
# Read-only against live knowledge/** and .orchestrator/execution-log.jsonl —
# all fixture state lives under mktemp -d + trap EXIT rm -rf, and the
# stub helper short-circuits before reading the live tree.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"

if [ ! -f "$STATUS_SH" ]; then
  echo "FAIL: status.sh not found at $STATUS_SH"
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
# Build a synthetic orchestrator root with one fake milestone so status.sh
# emits at least one MILESTONE: / STATE: / PHASE: line, and the Review
# Queue section follows.
# ----------------------------------------------------------------------------
build_fake_root() {
  local rroot="$1"
  mkdir -p "$rroot/milestones/M999/phases/P01"
  : >"$rroot/milestones/M999/M999-ROADMAP.md"
  : >"$rroot/milestones/M999/phases/P01/P01-PLAN.md"
}

# ----------------------------------------------------------------------------
# Build a shadow tree that overrides the status.sh helper resolution.
# We build a fake repo_root by symlinking the real scripts/state and
# scripts/orchestrator dirs, and providing a STUB scripts/knowledge/
# compute-staleness.sh that emits the desired stdout for each scenario.
# ----------------------------------------------------------------------------
build_shadow_repo() {
  local shadow="$1"
  local stub_payload="$2"   # path to the canned stdout to print
  local stub_rc="$3"        # exit code for the stub
  mkdir -p "$shadow/scripts/orchestrator"
  mkdir -p "$shadow/scripts/state"
  mkdir -p "$shadow/scripts/knowledge"

  # Copy status.sh so REPO_ROOT resolves into this shadow tree.
  cp "$ROOT/scripts/orchestrator/status.sh" "$shadow/scripts/orchestrator/status.sh"
  # Copy resolve-root.sh + derive-phase.sh (status.sh shells out to them).
  cp "$ROOT/scripts/state/resolve-root.sh" "$shadow/scripts/state/resolve-root.sh"
  cp "$ROOT/scripts/state/derive-phase.sh" "$shadow/scripts/state/derive-phase.sh"

  # Stub compute-staleness.sh: prints the canned payload, exits with stub_rc.
  cat >"$shadow/scripts/knowledge/compute-staleness.sh" <<EOF
#!/usr/bin/env bash
# stub for m020-p04-status-review-queue-section verifier
cat "$stub_payload"
exit $stub_rc
EOF
  chmod +x "$shadow/scripts/knowledge/compute-staleness.sh"
}

# ----------------------------------------------------------------------------
# Scenario A: empty queue (helper prints `EMPTY`).
# ----------------------------------------------------------------------------
scen_empty="$tmpdir/scen-empty"
mkdir -p "$scen_empty"
empty_payload="$scen_empty/payload.txt"
printf 'EMPTY\n' >"$empty_payload"
build_shadow_repo "$scen_empty" "$empty_payload" 0

empty_root="$scen_empty/.orchestrator"
mkdir -p "$empty_root"
build_fake_root "$empty_root"

empty_out="$(bash "$scen_empty/scripts/orchestrator/status.sh" --root "$empty_root" 2>"$tmpdir/empty.err")"
empty_rc=$?
if [ "$empty_rc" -ne 0 ]; then
  fail "empty-queue scenario: status.sh exited rc=$empty_rc (expected 0); stderr: $(head -1 "$tmpdir/empty.err" 2>/dev/null || true)"
else
  pass "empty-queue scenario: status.sh exits 0"
fi

# Last non-blank line should be exactly `Review Queue: empty`.
last_line="$(printf '%s\n' "$empty_out" | awk 'NF' | tail -1)"
if [ "$last_line" = "Review Queue: empty" ]; then
  pass "empty-queue scenario: last line is exactly 'Review Queue: empty'"
else
  fail "empty-queue scenario: last line was '$last_line' (expected 'Review Queue: empty')"
fi

# Empty rendering must be exactly one line (no per-cluster lines emitted).
empty_rq_lines="$(printf '%s\n' "$empty_out" | grep -c '^Review Queue:' || true)"
if [ "$empty_rq_lines" -eq 1 ]; then
  pass "empty-queue scenario: exactly one 'Review Queue:' line"
else
  fail "empty-queue scenario: $empty_rq_lines 'Review Queue:' lines (expected 1)"
fi

empty_cluster_lines="$(printf '%s\n' "$empty_out" | grep -c '^  cluster=' || true)"
if [ "$empty_cluster_lines" -eq 0 ]; then
  pass "empty-queue scenario: no indented per-cluster lines emitted"
else
  fail "empty-queue scenario: $empty_cluster_lines indented cluster lines emitted (expected 0)"
fi

# ----------------------------------------------------------------------------
# Scenario B: non-empty queue (two clusters, totals 5 entries).
# Helper prints two well-formed cluster lines.
# ----------------------------------------------------------------------------
scen_full="$tmpdir/scen-full"
mkdir -p "$scen_full"
full_payload="$scen_full/payload.txt"
cat >"$full_payload" <<'EOF'
cluster_id=Cabcdef01 topic=zebra count=2 oldest_age=21 stale=true
cluster_id=Cabcdef02 topic=walrus count=3 oldest_age=4 stale=false
EOF
build_shadow_repo "$scen_full" "$full_payload" 0

full_root="$scen_full/.orchestrator"
mkdir -p "$full_root"
build_fake_root "$full_root"

full_out="$(bash "$scen_full/scripts/orchestrator/status.sh" --root "$full_root" 2>"$tmpdir/full.err")"
full_rc=$?
if [ "$full_rc" -ne 0 ]; then
  fail "non-empty scenario: status.sh exited rc=$full_rc (expected 0)"
else
  pass "non-empty scenario: status.sh exits 0"
fi

# Header line: `Review Queue: 2 clusters, 5 entries awaiting review`
header_line="$(printf '%s\n' "$full_out" | grep '^Review Queue:' | head -1)"
if printf '%s' "$header_line" | grep -E -q '^Review Queue: 2 clusters, 5 entries awaiting review$'; then
  pass "non-empty scenario: header line matches '^Review Queue: <N> clusters, <M> entries awaiting review$' (N=2, M=5)"
else
  fail "non-empty scenario: header line was '$header_line' (expected 'Review Queue: 2 clusters, 5 entries awaiting review')"
fi

# Two indented cluster summary lines, two-space-prefix.
cluster_count="$(printf '%s\n' "$full_out" | grep -c '^  cluster=' || true)"
if [ "$cluster_count" -eq 2 ]; then
  pass "non-empty scenario: 2 indented cluster summary lines"
else
  fail "non-empty scenario: $cluster_count indented cluster lines (expected 2)"
fi

# Each cluster line shape: `  cluster=<C8hex> topic=<t> count=<N> oldest_age=<d>d[ (stale)]`
cline_shape='^  cluster=[A-Za-z0-9]+ topic=[^ ]+ count=[0-9]+ oldest_age=[0-9]+d( \(stale\))?$'
cline_violations=0
i=1
for n in 1 2; do
  cl="$(printf '%s\n' "$full_out" | grep '^  cluster=' | sed -n "${n}p")"
  [ -z "$cl" ] && continue
  if ! printf '%s' "$cl" | grep -E -q "$cline_shape"; then
    cline_violations=$(( cline_violations + 1 ))
  fi
  i=$(( i + 1 ))
done
if [ "$cline_violations" -eq 0 ]; then
  pass "non-empty scenario: every cluster line matches indented summary shape"
else
  fail "non-empty scenario: $cline_violations cluster line(s) violate indented summary shape"
fi

# Existing MILESTONE / STATE / PHASE lines must precede the Review Queue header.
ms_line_no="$(printf '%s\n' "$full_out" | grep -n '^MILESTONE: M999$' | head -1 | cut -d: -f1)"
rq_line_no="$(printf '%s\n' "$full_out" | grep -n '^Review Queue:' | head -1 | cut -d: -f1)"
if [ -n "$ms_line_no" ] && [ -n "$rq_line_no" ] && [ "$ms_line_no" -lt "$rq_line_no" ]; then
  pass "non-empty scenario: MILESTONE: line precedes Review Queue: section"
else
  fail "non-empty scenario: MILESTONE: line ($ms_line_no) does not precede Review Queue: ($rq_line_no)"
fi

# ----------------------------------------------------------------------------
# Final tally.
# ----------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-status-review-queue-section: %d/%d checks passed ---\n' "$pass_count" "$total"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
