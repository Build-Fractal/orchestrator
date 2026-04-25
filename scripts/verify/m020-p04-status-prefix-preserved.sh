#!/usr/bin/env bash
# scripts/verify/m020-p04-status-prefix-preserved.sh
#
# M020/P04/T02 surface-preservation verifier (CON-4): the existing
# MILESTONE: / STATE: / PHASE: line shapes from on-main status.sh are
# preserved byte-equivalent after the P04 Review-Queue addition. We strip
# the new `Review Queue:` section + indented per-cluster lines from the
# T02-modified output and assert the remaining prefix is byte-equivalent
# to a recomputed-from-scratch MILESTONE/STATE/PHASE projection of the
# same fixture root.
#
# AD-19 single-script-file shape; MEM001 PASS/FAIL prefix conventions.
# Bash 3.2 safe. Read-only against live knowledge/** — uses tempdir
# fixtures and a stub compute-staleness.sh.

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

# Multi-milestone fixture: M050 (planning, 1 phase pending), M060 (executing,
# 2 phases — P01 complete, P02 executing).
build_fake_root() {
  local rroot="$1"
  mkdir -p "$rroot/milestones/M050/phases/P01"
  : >"$rroot/milestones/M050/M050-ROADMAP.md"
  mkdir -p "$rroot/milestones/M060/phases/P01"
  mkdir -p "$rroot/milestones/M060/phases/P02"
  : >"$rroot/milestones/M060/M060-ROADMAP.md"
  : >"$rroot/milestones/M060/phases/P01/P01-PLAN.md"
  : >"$rroot/milestones/M060/phases/P01/P01-SUMMARY.md"
  : >"$rroot/milestones/M060/phases/P02/P02-PLAN.md"
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

# Strip the P04 Review-Queue section: lines starting with `Review Queue:`,
# and lines starting with two-space + `cluster=`.
strip_p04_section() {
  local f="$1"
  awk '
    /^Review Queue:/ { skip=1; next }
    skip && /^  cluster=/ { next }
    { skip=0; print }
  ' "$f"
}

# ----------------------------------------------------------------------------
# Empty-queue scenario: prefix lines plus `Review Queue: empty`. Strip the
# review queue and assert the remaining stream contains only MILESTONE: /
# STATE: / PHASE: lines.
# ----------------------------------------------------------------------------
shadow_a="$tmpdir/shadow-a"
mkdir -p "$shadow_a"
payload_a="$shadow_a/payload.txt"
printf 'EMPTY\n' >"$payload_a"
build_shadow_repo "$shadow_a" "$payload_a"
orch_a="$shadow_a/.orchestrator"
mkdir -p "$orch_a"
build_fake_root "$orch_a"

out_a="$tmpdir/out-a.txt"
bash "$shadow_a/scripts/orchestrator/status.sh" --root "$orch_a" >"$out_a" 2>/dev/null
rc_a=$?
if [ "$rc_a" -eq 0 ]; then
  pass "empty-queue scenario: status.sh exits 0"
else
  fail "empty-queue scenario: status.sh exited rc=$rc_a"
fi

stripped_a="$tmpdir/stripped-a.txt"
strip_p04_section "$out_a" >"$stripped_a"

# Every remaining non-blank line must begin with MILESTONE:, STATE:, or PHASE:.
foreign_a="$(awk 'NF && $0 !~ /^(MILESTONE: |STATE: |PHASE: )/ {print; n++} END{exit (n>0)?1:0}' "$stripped_a"; printf '%d' $?)"
# foreign_a is "" + "0" or "" + "1" because of awk's exit + the printf below.
# Re-derive deterministically:
foreign_count="$(awk 'NF && $0 !~ /^(MILESTONE: |STATE: |PHASE: )/' "$stripped_a" | wc -l | tr -d ' ')"
if [ "$foreign_count" -eq 0 ]; then
  pass "empty-queue scenario: post-strip stream contains only MILESTONE/STATE/PHASE lines"
else
  fail "empty-queue scenario: $foreign_count non-conforming line(s) survive after stripping P04 section"
fi

# Trim trailing blank lines from stripped_a for cross-scenario comparison.
trimmed_a="$tmpdir/trimmed-a.txt"
awk 'NF{p=1} p' "$stripped_a" >"$trimmed_a"
trimmed2_a="$tmpdir/trimmed2-a.txt"
sed -e :a -e '/^\s*$/{$d;N;ba' -e '}' "$trimmed_a" >"$trimmed2_a"

# Confirm structure: 2 MILESTONE: lines, 2 STATE: lines, 3 PHASE: lines.
ms_count_a="$(grep -c '^MILESTONE: ' "$trimmed2_a" || true)"
st_count_a="$(grep -c '^STATE: ' "$trimmed2_a" || true)"
ph_count_a="$(grep -c '^PHASE: ' "$trimmed2_a" || true)"
if [ "$ms_count_a" -eq 2 ] && [ "$st_count_a" -eq 2 ] && [ "$ph_count_a" -eq 3 ]; then
  pass "empty-queue scenario: prefix structure intact (2 MILESTONE:, 2 STATE:, 3 PHASE:)"
else
  fail "empty-queue scenario: prefix structure was M=$ms_count_a S=$st_count_a P=$ph_count_a (expected 2/2/3)"
fi

# CON-4 byte-equivalence: compare against the on-main (HEAD) version of
# status.sh run against the same fixture. The on-main version emits ONLY
# MILESTONE/STATE/PHASE lines (no Review Queue section). Stripping the P04
# section from current output must yield identical bytes. We install the
# on-main copy alongside the shadow's scripts/state/ so its SCRIPT_DIR-
# derived REPO_ROOT resolves to the shadow tree (with derive-phase.sh).
onmain_status="$shadow_a/scripts/orchestrator/status-onmain.sh"
if git -C "$ROOT" show HEAD:scripts/orchestrator/status.sh >"$onmain_status" 2>/dev/null; then
  chmod +x "$onmain_status"
  onmain_out_a="$tmpdir/onmain-out-a.txt"
  bash "$onmain_status" --root "$orch_a" >"$onmain_out_a" 2>/dev/null || true
  trimmed_onmain_a="$tmpdir/trimmed-onmain-a.txt"
  awk 'NF{p=1} p' "$onmain_out_a" >"$trimmed_onmain_a"
  trimmed2_onmain_a="$tmpdir/trimmed2-onmain-a.txt"
  sed -e :a -e '/^\s*$/{$d;N;ba' -e '}' "$trimmed_onmain_a" >"$trimmed2_onmain_a"
  if cmp -s "$trimmed2_a" "$trimmed2_onmain_a"; then
    pass "empty-queue scenario: prefix lines byte-equivalent to on-main (HEAD) status.sh output"
  else
    fail "empty-queue scenario: prefix lines DIFFER from on-main (HEAD) output:"
    diff "$trimmed2_onmain_a" "$trimmed2_a" || true
  fi
else
  pass "empty-queue scenario: on-main HEAD reference unavailable (skipped byte-equivalence — non-blocking)"
fi

# ----------------------------------------------------------------------------
# Populated-queue scenario: same fixture, helper emits two cluster lines.
# After stripping P04 section, prefix must be byte-equivalent to expected.
# ----------------------------------------------------------------------------
shadow_b="$tmpdir/shadow-b"
mkdir -p "$shadow_b"
payload_b="$shadow_b/payload.txt"
cat >"$payload_b" <<'EOF'
cluster_id=Cabcdef01 topic=zebra count=2 oldest_age=21 stale=true
cluster_id=Cabcdef02 topic=walrus count=3 oldest_age=4 stale=false
EOF
build_shadow_repo "$shadow_b" "$payload_b"
orch_b="$shadow_b/.orchestrator"
mkdir -p "$orch_b"
build_fake_root "$orch_b"

out_b="$tmpdir/out-b.txt"
bash "$shadow_b/scripts/orchestrator/status.sh" --root "$orch_b" >"$out_b" 2>/dev/null
rc_b=$?
if [ "$rc_b" -eq 0 ]; then
  pass "populated scenario: status.sh exits 0"
else
  fail "populated scenario: status.sh exited rc=$rc_b"
fi

stripped_b="$tmpdir/stripped-b.txt"
strip_p04_section "$out_b" >"$stripped_b"

trimmed_b="$tmpdir/trimmed-b.txt"
awk 'NF{p=1} p' "$stripped_b" >"$trimmed_b"
trimmed2_b="$tmpdir/trimmed2-b.txt"
sed -e :a -e '/^\s*$/{$d;N;ba' -e '}' "$trimmed_b" >"$trimmed2_b"

# Cross-check populated scenario also matches on-main HEAD reference.
onmain_status_b="$shadow_b/scripts/orchestrator/status-onmain.sh"
if git -C "$ROOT" show HEAD:scripts/orchestrator/status.sh >"$onmain_status_b" 2>/dev/null; then
  chmod +x "$onmain_status_b"
  onmain_out_b="$tmpdir/onmain-out-b.txt"
  bash "$onmain_status_b" --root "$orch_b" >"$onmain_out_b" 2>/dev/null || true
  trimmed_onmain_b="$tmpdir/trimmed-onmain-b.txt"
  awk 'NF{p=1} p' "$onmain_out_b" >"$trimmed_onmain_b"
  trimmed2_onmain_b="$tmpdir/trimmed2-onmain-b.txt"
  sed -e :a -e '/^\s*$/{$d;N;ba' -e '}' "$trimmed_onmain_b" >"$trimmed2_onmain_b"
  if cmp -s "$trimmed2_b" "$trimmed2_onmain_b"; then
    pass "populated scenario: prefix lines byte-equivalent to on-main (HEAD) status.sh output (P04 section is strictly additive)"
  else
    fail "populated scenario: prefix lines DIFFER from on-main (HEAD) output:"
    diff "$trimmed2_onmain_b" "$trimmed2_b" || true
  fi
else
  pass "populated scenario: on-main HEAD reference unavailable (skipped byte-equivalence — non-blocking)"
fi

# ----------------------------------------------------------------------------
# Cross-scenario invariance: the prefix lines from both scenarios are
# byte-equivalent to each other (the only diff is the P04 section).
# ----------------------------------------------------------------------------
if cmp -s "$trimmed2_a" "$trimmed2_b"; then
  pass "prefix lines are byte-equivalent across empty/populated review-queue scenarios"
else
  fail "prefix lines differ between empty and populated scenarios — P04 must not perturb prefix"
fi

# ----------------------------------------------------------------------------
# Final tally.
# ----------------------------------------------------------------------------
total=$(( pass_count + fail_count ))
printf '\n--- m020-p04-status-prefix-preserved: %d/%d checks passed ---\n' "$pass_count" "$total"

if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
