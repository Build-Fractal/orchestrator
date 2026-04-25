#!/usr/bin/env bash
# tests/test-preferences-resolution.sh — SC-5 + per-key precedence +
# malformed-fallback integration test through query.sh and
# consolidate-artifacts.sh --cluster.
#
# Bash 3.2 + MEM002 conventions. Tempdir + HOME / PROJECT_ROOT / ORCH_ROOT
# fixture isolation per P03/P05 (no live filesystem access).
#
# Scenarios:
#   A. SC-5 directly: project=0.6, user=0.8 ->
#      consolidate-artifacts.sh --cluster emits effective_threshold=0.6
#      and JSONL threshold_used=0.6. Both preferences files md5 unchanged.
#   B. State-filter precedence via query.sh: project=candidate,
#      user=graduated, no --state flag -> query.sh --topic zeta returns
#      the candidate entry's ID only (graduated entry is filtered out).
#   C. Malformed-value fallback via consolidate-artifacts.sh --cluster:
#      project file similarity_threshold=not-a-number, no user file ->
#      effective_threshold=0.7 on stdout, WARN diagnostic on stderr,
#      project preferences file byte-identical (md5) before/after.
#
# AD-19: invoked externally as a single `bash <script>` call.
# CON-1 / FR-8 (read-only): asserts both preferences files unchanged
# across every invocation that reads from them.
# MEM001 (Bash 3.2): no declare -A; parallel-scalar pass()/fail() pattern.

set -u

# pass/fail parallel-scalar pattern (no declare -A).
pc=0
fc=0
pass() { pc=$((pc + 1)); echo "PASS: $*"; }
fail() { fc=$((fc + 1)); echo "FAIL: $*" >&2; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d -t m020-p06-prefs.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Portable md5 helper. Tries md5 -q (BSD/macOS), then md5sum (GNU/Linux),
# then shasum -a 1 (universal fallback). Pattern from P02/P05 verifiers.
md5_or_sha() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "MISSING"
    return
  fi
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$f" | awk '{print $1}'
  else
    shasum -a 1 "$f" | awk '{print $1}'
  fi
}

# Fixture isolation: HOME, PROJECT_ROOT, ORCH_ROOT all rooted under TMP.
export HOME="$TMP/home"
export PROJECT_ROOT="$TMP/project"
export ORCH_ROOT="$TMP/project/.orchestrator"
KNOWLEDGE_ROOT="$TMP/project/knowledge"

mkdir -p "$HOME/.orchestrator" "$PROJECT_ROOT/.orchestrator" "$KNOWLEDGE_ROOT" "$ORCH_ROOT"

# --- Helper: write a candidate entry with a topic + a single tag ---
write_candidate() {
  local id="$1"
  local topic="$2"
  local tag="$3"
  local file="$KNOWLEDGE_ROOT/${id}.md"
  cat >"$file" <<ENTRY
---
schema_version: "1.0"
id: ${id}
status: candidate
topic: ${topic}
tags: [${tag}]
title: "${id} title"
last_verified: "2026-04-25"
---

# ${id}: ${topic}

${id} body words: ${topic} ${tag} alpha beta gamma delta.
ENTRY
}

write_graduated() {
  local id="$1"
  local topic="$2"
  local file="$KNOWLEDGE_ROOT/${id}.md"
  cat >"$file" <<ENTRY
---
schema_version: "1.0"
id: ${id}
status: graduated
topic: ${topic}
tags: [${topic}]
title: "${id} title"
last_verified: "2026-04-25"
---

# ${id}: ${topic}

${id} body for ${topic}.
ENTRY
}

# Helper: assert the test invokes preferences.sh's contract (key-link).
# This pin keeps Files-To-Touch -> key-link mapping verifiable from the
# test itself.
PREFS_HELPER="$REPO_ROOT/scripts/knowledge/lib/preferences.sh"
if [ -f "$PREFS_HELPER" ]; then
  pass "key-link: preferences.sh helper available at $PREFS_HELPER"
else
  fail "key-link: preferences.sh helper missing at $PREFS_HELPER"
fi

# ============================================================
# Scenario A — SC-5 direct: project=0.6 wins over user=0.8.
# ============================================================

# Three candidate entries with disjoint topics + disjoint tags so the
# clustering proposal will compute (vocabulary-disjoint singletons).
write_candidate MEM501 alpha alpha
write_candidate MEM502 beta beta
write_candidate MEM503 gamma gamma

cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
similarity_threshold: 0.6
EOF
cat >"$HOME/.orchestrator/preferences.yml" <<EOF
similarity_threshold: 0.8
EOF

proj_pre_a="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
user_pre_a="$(md5_or_sha "$HOME/.orchestrator/preferences.yml")"

stdout_a="$TMP/stdout-a.txt"
stderr_a="$TMP/stderr-a.txt"
bash "$REPO_ROOT/scripts/knowledge/consolidate-artifacts.sh" --cluster \
  "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" \
  >"$stdout_a" 2>"$stderr_a" || true

if grep -q '^effective_threshold=0\.6$' "$stdout_a"; then
  pass "scenario A: project=0.6 wins over user=0.8 -> effective_threshold=0.6"
else
  fail "scenario A: stdout missing effective_threshold=0.6 (head: $(head -3 "$stdout_a" | tr '\n' '|'))"
fi

# JSONL check: dh_emit_jsonl writes "threshold_used":"0.6" inside the
# consolidate_cluster record (one record per cluster).
if grep -q '"threshold_used":"0\.6"' "$ORCH_ROOT/execution-log.jsonl" 2>/dev/null; then
  pass "scenario A: JSONL threshold_used=0.6"
else
  fail "scenario A: JSONL missing threshold_used=0.6 in $ORCH_ROOT/execution-log.jsonl"
fi

proj_post_a="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
user_post_a="$(md5_or_sha "$HOME/.orchestrator/preferences.yml")"

if [ "$proj_pre_a" = "$proj_post_a" ]; then
  pass "scenario A: project preferences file md5 unchanged"
else
  fail "scenario A: project preferences file mutated ($proj_pre_a -> $proj_post_a)"
fi

if [ "$user_pre_a" = "$user_post_a" ]; then
  pass "scenario A: user preferences file md5 unchanged"
else
  fail "scenario A: user preferences file mutated ($user_pre_a -> $user_post_a)"
fi

# ============================================================
# Scenario B — state-filter precedence via query.sh.
# project=candidate, user=graduated, no --state -> candidate wins.
# query --topic zeta returns MEM511 (candidate) and not MEM510 (graduated).
# ============================================================

# Reset JSONL so scenario C's downstream check is unambiguous.
rm -f "$ORCH_ROOT/execution-log.jsonl"

write_graduated MEM510 zeta
write_candidate MEM511 zeta zeta

cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
default_state_filter: candidate
EOF
cat >"$HOME/.orchestrator/preferences.yml" <<EOF
default_state_filter: graduated
EOF

proj_pre_b="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
user_pre_b="$(md5_or_sha "$HOME/.orchestrator/preferences.yml")"

stdout_b="$TMP/stdout-b.txt"
stderr_b="$TMP/stderr-b.txt"
bash "$REPO_ROOT/scripts/knowledge/query.sh" --topic zeta --format ids \
  >"$stdout_b" 2>"$stderr_b" || true

if grep -q '^entry_id=MEM511$' "$stdout_b"; then
  has_511=1
else
  has_511=0
fi
if grep -q '^entry_id=MEM510$' "$stdout_b"; then
  has_510=1
else
  has_510=0
fi

if [ "$has_511" = "1" ] && [ "$has_510" = "0" ]; then
  pass "scenario B: project=candidate wins over user=graduated -> MEM511 returned, MEM510 not"
else
  fail "scenario B: query.sh stdout did not honor project default_state_filter=candidate (MEM511=$has_511, MEM510=$has_510, head: $(head -5 "$stdout_b" | tr '\n' '|'))"
fi

proj_post_b="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
user_post_b="$(md5_or_sha "$HOME/.orchestrator/preferences.yml")"

if [ "$proj_pre_b" = "$proj_post_b" ] && [ "$user_pre_b" = "$user_post_b" ]; then
  pass "scenario B: both preferences files md5 unchanged"
else
  fail "scenario B: preferences file mutated by query.sh"
fi

# ============================================================
# Scenario C — malformed-value fallback via consolidate-artifacts.sh.
# project=not-a-number, no user file -> effective_threshold=0.7 (default)
# + WARN stderr + project file unchanged (md5).
# ============================================================

# Reset state.
rm -f "$ORCH_ROOT/execution-log.jsonl"
rm -f "$HOME/.orchestrator/preferences.yml"

cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
similarity_threshold: not-a-number
EOF

proj_pre_c="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"

stdout_c="$TMP/stdout-c.txt"
stderr_c="$TMP/stderr-c.txt"
bash "$REPO_ROOT/scripts/knowledge/consolidate-artifacts.sh" --cluster \
  "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" \
  >"$stdout_c" 2>"$stderr_c" || true

if grep -q '^effective_threshold=0\.7$' "$stdout_c"; then
  pass "scenario C: malformed project value -> effective_threshold=0.7 (built-in default)"
else
  fail "scenario C: stdout missing effective_threshold=0.7 (head: $(head -3 "$stdout_c" | tr '\n' '|'))"
fi

if grep -q "WARN: pref_resolve: malformed value for 'similarity_threshold'" "$stderr_c"; then
  pass "scenario C: stderr WARN diagnostic emitted"
else
  fail "scenario C: stderr missing WARN diagnostic (stderr head: $(head -5 "$stderr_c" | tr '\n' '|'))"
fi

proj_post_c="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
if [ "$proj_pre_c" = "$proj_post_c" ]; then
  pass "scenario C: project preferences file md5 unchanged (operator file untouched)"
else
  fail "scenario C: project preferences file mutated ($proj_pre_c -> $proj_post_c)"
fi

# ============================================================
# Final summary line in the MEM002 RESULT shape.
# ============================================================

echo "RESULT: ${pc}/$((pc + fc)) PASS"
[ "$fc" -eq 0 ] || exit 1
exit 0
