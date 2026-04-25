#!/usr/bin/env bash
# scripts/verify/m020-p04-status-review-queue-readonly.sh
#
# M020/P04/T02 read-only invariant verifier (CON-1 / FR-8): scripts/
# orchestrator/status.sh writes nothing to knowledge/** and appends nothing
# to .orchestrator/execution-log.jsonl when emitting the Review-Queue
# section. Tempdir-isolated; the live tree is never touched. Also exercises
# the failure-tolerant fallback path (`Review Queue: unavailable`) without
# leaking writes.
#
# AD-19 single-script-file shape; MEM001 PASS/FAIL prefix conventions.
# Bash 3.2 safe.

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

# Build a shadow repo with a tracked knowledge/ tree and a tracked
# execution-log.jsonl. We snapshot the byte-equivalence of these surfaces
# before and after running status.sh.
build_shadow_repo() {
  local shadow="$1" stub_payload="$2" stub_rc="$3"
  mkdir -p "$shadow/scripts/orchestrator" "$shadow/scripts/state" "$shadow/scripts/knowledge"
  cp "$ROOT/scripts/orchestrator/status.sh" "$shadow/scripts/orchestrator/status.sh"
  cp "$ROOT/scripts/state/resolve-root.sh" "$shadow/scripts/state/resolve-root.sh"
  cp "$ROOT/scripts/state/derive-phase.sh" "$shadow/scripts/state/derive-phase.sh"

  if [ -n "$stub_payload" ]; then
    cat >"$shadow/scripts/knowledge/compute-staleness.sh" <<EOF
#!/usr/bin/env bash
cat "$stub_payload"
exit $stub_rc
EOF
    chmod +x "$shadow/scripts/knowledge/compute-staleness.sh"
  fi
  # Seed knowledge/ tree with a couple of files so we can checksum.
  mkdir -p "$shadow/knowledge/patterns"
  printf 'seed-1\n' >"$shadow/knowledge/patterns/MEM700.md"
  printf 'seed-2\n' >"$shadow/knowledge/patterns/MEM701.md"
}

# Portable directory checksum (find + cksum sum). Captures both content and
# the file-list shape so a write/append/delete trips it.
dir_fingerprint() {
  local d="$1"
  if [ ! -d "$d" ]; then
    printf 'MISSING\n'
    return 0
  fi
  ( cd "$d" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 cksum 2>/dev/null )
}

file_fingerprint() {
  local f="$1"
  if [ ! -e "$f" ]; then
    printf 'MISSING\n'
    return 0
  fi
  cksum "$f" 2>/dev/null
}

# ----------------------------------------------------------------------------
# Scenario A: empty queue (helper exits 0 with EMPTY).
# ----------------------------------------------------------------------------
shadow_a="$tmpdir/shadow-a"
mkdir -p "$shadow_a"
payload_a="$shadow_a/payload.txt"
printf 'EMPTY\n' >"$payload_a"
build_shadow_repo "$shadow_a" "$payload_a" 0

orch_a="$shadow_a/.orchestrator"
mkdir -p "$orch_a"
build_fake_root "$orch_a"
# Seed an execution log to detect appends.
exec_log_a="$orch_a/execution-log.jsonl"
printf '{"event":"seed"}\n' >"$exec_log_a"

knowledge_before_a="$(dir_fingerprint "$shadow_a/knowledge")"
log_before_a="$(file_fingerprint "$exec_log_a")"

bash "$shadow_a/scripts/orchestrator/status.sh" --root "$orch_a" >/dev/null 2>&1
rc_a=$?

knowledge_after_a="$(dir_fingerprint "$shadow_a/knowledge")"
log_after_a="$(file_fingerprint "$exec_log_a")"

if [ "$rc_a" -eq 0 ]; then
  pass "scenario A (empty queue): status.sh exits 0"
else
  fail "scenario A (empty queue): status.sh exited rc=$rc_a"
fi

if [ "$knowledge_before_a" = "$knowledge_after_a" ]; then
  pass "scenario A (empty queue): knowledge/ tree byte-equivalent before/after"
else
  fail "scenario A (empty queue): knowledge/ tree changed during status.sh invocation"
fi

if [ "$log_before_a" = "$log_after_a" ]; then
  pass "scenario A (empty queue): execution-log.jsonl byte-equivalent before/after"
else
  fail "scenario A (empty queue): execution-log.jsonl was modified during status.sh invocation"
fi

# ----------------------------------------------------------------------------
# Scenario B: populated queue (helper exits 0 with two cluster lines).
# ----------------------------------------------------------------------------
shadow_b="$tmpdir/shadow-b"
mkdir -p "$shadow_b"
payload_b="$shadow_b/payload.txt"
cat >"$payload_b" <<'EOF'
cluster_id=Cabcdef01 topic=zebra count=2 oldest_age=21 stale=true
cluster_id=Cabcdef02 topic=walrus count=3 oldest_age=4 stale=false
EOF
build_shadow_repo "$shadow_b" "$payload_b" 0

orch_b="$shadow_b/.orchestrator"
mkdir -p "$orch_b"
build_fake_root "$orch_b"
exec_log_b="$orch_b/execution-log.jsonl"
printf '{"event":"seed"}\n' >"$exec_log_b"

knowledge_before_b="$(dir_fingerprint "$shadow_b/knowledge")"
log_before_b="$(file_fingerprint "$exec_log_b")"

bash "$shadow_b/scripts/orchestrator/status.sh" --root "$orch_b" >/dev/null 2>&1
rc_b=$?

knowledge_after_b="$(dir_fingerprint "$shadow_b/knowledge")"
log_after_b="$(file_fingerprint "$exec_log_b")"

if [ "$rc_b" -eq 0 ]; then
  pass "scenario B (populated queue): status.sh exits 0"
else
  fail "scenario B (populated queue): status.sh exited rc=$rc_b"
fi

if [ "$knowledge_before_b" = "$knowledge_after_b" ]; then
  pass "scenario B (populated queue): knowledge/ tree byte-equivalent before/after"
else
  fail "scenario B (populated queue): knowledge/ tree changed during status.sh invocation"
fi

if [ "$log_before_b" = "$log_after_b" ]; then
  pass "scenario B (populated queue): execution-log.jsonl byte-equivalent before/after"
else
  fail "scenario B (populated queue): execution-log.jsonl was modified during status.sh invocation"
fi

# ----------------------------------------------------------------------------
# Scenario C: helper failure path (stub exits non-zero).
# Confirm: status.sh emits 'Review Queue: unavailable', exits 0, and writes
# nothing to knowledge/** or execution-log.jsonl.
# ----------------------------------------------------------------------------
shadow_c="$tmpdir/shadow-c"
mkdir -p "$shadow_c"
payload_c="$shadow_c/payload.txt"
printf 'BOGUS\n' >"$payload_c"
build_shadow_repo "$shadow_c" "$payload_c" 7

orch_c="$shadow_c/.orchestrator"
mkdir -p "$orch_c"
build_fake_root "$orch_c"
exec_log_c="$orch_c/execution-log.jsonl"
printf '{"event":"seed"}\n' >"$exec_log_c"

knowledge_before_c="$(dir_fingerprint "$shadow_c/knowledge")"
log_before_c="$(file_fingerprint "$exec_log_c")"

out_c="$(bash "$shadow_c/scripts/orchestrator/status.sh" --root "$orch_c" 2>"$tmpdir/c.err")"
rc_c=$?

knowledge_after_c="$(dir_fingerprint "$shadow_c/knowledge")"
log_after_c="$(file_fingerprint "$exec_log_c")"

if [ "$rc_c" -eq 0 ]; then
  pass "scenario C (helper failure): status.sh still exits 0 (failure-tolerant)"
else
  fail "scenario C (helper failure): status.sh exited rc=$rc_c (expected 0)"
fi

last_line_c="$(printf '%s\n' "$out_c" | awk 'NF' | tail -1)"
if [ "$last_line_c" = "Review Queue: unavailable" ]; then
  pass "scenario C (helper failure): renders 'Review Queue: unavailable'"
else
  fail "scenario C (helper failure): last line was '$last_line_c' (expected 'Review Queue: unavailable')"
fi

if [ -s "$tmpdir/c.err" ]; then
  pass "scenario C (helper failure): stderr diagnostic emitted"
else
  fail "scenario C (helper failure): stderr is empty (expected one-line diagnostic)"
fi

if [ "$knowledge_before_c" = "$knowledge_after_c" ]; then
  pass "scenario C (helper failure): knowledge/ tree byte-equivalent before/after"
else
  fail "scenario C (helper failure): knowledge/ tree changed during failure path"
fi

if [ "$log_before_c" = "$log_after_c" ]; then
  pass "scenario C (helper failure): execution-log.jsonl byte-equivalent before/after"
else
  fail "scenario C (helper failure): execution-log.jsonl was modified during failure path"
fi

# ----------------------------------------------------------------------------
# Final tally.
# ----------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-status-review-queue-readonly: %d/%d checks passed ---\n' "$pass_count" "$total"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
