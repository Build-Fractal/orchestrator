#!/usr/bin/env bash
# scripts/verify/m020-p04-status-stale-marker.sh
#
# M020/P04/T02 truth verifier: scripts/orchestrator/status.sh Review-Queue
# rendering surfaces the literal `(stale)` marker on per-cluster summary
# lines whose underlying compute-staleness output carries `stale=true`;
# non-stale cluster lines do NOT carry the marker.
#
# AD-19 single-script-file shape; MEM001 PASS/FAIL prefix conventions.
# Bash 3.2 safe. Read-only against live knowledge/** — uses a stub
# compute-staleness.sh under a shadow repo root.

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

build_fake_root() {
  local rroot="$1"
  mkdir -p "$rroot/milestones/M999/phases/P01"
  : >"$rroot/milestones/M999/M999-ROADMAP.md"
  : >"$rroot/milestones/M999/phases/P01/P01-PLAN.md"
}

build_shadow_repo() {
  local shadow="$1" stub_payload="$2"
  mkdir -p "$shadow/scripts/orchestrator" "$shadow/scripts/state" "$shadow/scripts/knowledge"
  cp "$ROOT/scripts/orchestrator/status.sh" "$shadow/scripts/orchestrator/status.sh"
  cp "$ROOT/scripts/state/resolve-root.sh" "$shadow/scripts/state/resolve-root.sh"
  cp "$ROOT/scripts/state/derive-phase.sh" "$shadow/scripts/state/derive-phase.sh"
  cat >"$shadow/scripts/knowledge/compute-staleness.sh" <<EOF
#!/usr/bin/env bash
cat "$stub_payload"
exit 0
EOF
  chmod +x "$shadow/scripts/knowledge/compute-staleness.sh"
}

# ----------------------------------------------------------------------------
# Mixed payload: one stale=true cluster, one stale=false cluster.
# ----------------------------------------------------------------------------
shadow="$tmpdir/shadow"
mkdir -p "$shadow"
payload="$shadow/payload.txt"
cat >"$payload" <<'EOF'
cluster_id=Cabcdef01 topic=zebra count=2 oldest_age=21 stale=true
cluster_id=Cabcdef02 topic=walrus count=3 oldest_age=4 stale=false
EOF
build_shadow_repo "$shadow" "$payload"

orch_root="$shadow/.orchestrator"
mkdir -p "$orch_root"
build_fake_root "$orch_root"

out="$(bash "$shadow/scripts/orchestrator/status.sh" --root "$orch_root" 2>"$tmpdir/err")"
rc=$?
if [ "$rc" -ne 0 ]; then
  fail "status.sh exited rc=$rc (expected 0)"
else
  pass "status.sh exits 0 with mixed stale payload"
fi

# Find the cluster lines.
zebra_line="$(printf '%s\n' "$out" | grep '^  cluster=' | grep 'topic=zebra' || true)"
walrus_line="$(printf '%s\n' "$out" | grep '^  cluster=' | grep 'topic=walrus' || true)"

if [ -z "$zebra_line" ]; then
  fail "did not find indented cluster line for topic=zebra"
elif printf '%s' "$zebra_line" | grep -E -q ' \(stale\)$'; then
  pass "stale=true cluster (zebra) carries trailing ' (stale)' marker"
else
  fail "stale=true cluster (zebra) missing ' (stale)' marker. Line: $zebra_line"
fi

if [ -z "$walrus_line" ]; then
  fail "did not find indented cluster line for topic=walrus"
elif printf '%s' "$walrus_line" | grep -q '(stale)'; then
  fail "stale=false cluster (walrus) carries '(stale)' marker. Line: $walrus_line"
else
  pass "stale=false cluster (walrus) does NOT carry '(stale)' marker"
fi

# Marker text is the literal `(stale)` (parenthesised, lowercase).
if [ -n "$zebra_line" ]; then
  marker="$(printf '%s' "$zebra_line" | grep -oE '\([A-Za-z]+\)$' || true)"
  if [ "$marker" = "(stale)" ]; then
    pass "marker text is the literal '(stale)' (parenthesised, lowercase)"
  else
    fail "marker text was '$marker' (expected '(stale)')"
  fi
fi

# Marker is single-space-separated and at end-of-line.
if [ -n "$zebra_line" ]; then
  if printf '%s' "$zebra_line" | grep -E -q '[^ ] \(stale\)$'; then
    pass "marker is single-space-separated and at end-of-line"
  else
    fail "marker spacing/position incorrect on stale line: $zebra_line"
  fi
fi

# ----------------------------------------------------------------------------
# All-stale payload: every line carries ' (stale)'.
# ----------------------------------------------------------------------------
shadow2="$tmpdir/shadow2"
mkdir -p "$shadow2"
payload2="$shadow2/payload.txt"
cat >"$payload2" <<'EOF'
cluster_id=Caaaaaaa1 topic=alpha count=1 oldest_age=30 stale=true
cluster_id=Caaaaaaa2 topic=beta count=2 oldest_age=40 stale=true
EOF
build_shadow_repo "$shadow2" "$payload2"
orch_root2="$shadow2/.orchestrator"
mkdir -p "$orch_root2"
build_fake_root "$orch_root2"

out2="$(bash "$shadow2/scripts/orchestrator/status.sh" --root "$orch_root2" 2>/dev/null)"
all_lines="$(printf '%s\n' "$out2" | grep -c '^  cluster=' || true)"
stale_lines="$(printf '%s\n' "$out2" | grep '^  cluster=' | grep -c '(stale)$' || true)"
if [ "$all_lines" -eq 2 ] && [ "$stale_lines" -eq 2 ]; then
  pass "all-stale payload: both cluster lines carry '(stale)' marker"
else
  fail "all-stale payload: $stale_lines/$all_lines cluster lines carry '(stale)' marker (expected 2/2)"
fi

# ----------------------------------------------------------------------------
# Final tally.
# ----------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-status-stale-marker: %d/%d checks passed ---\n' "$pass_count" "$total"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
