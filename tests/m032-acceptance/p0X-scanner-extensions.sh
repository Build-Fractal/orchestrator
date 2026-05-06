#!/usr/bin/env bash
# tests/m032-acceptance/p0X-scanner-extensions.sh — SC-8 acceptance.
#
# Verifies FR-17 + FR-18 + FR-19 scanner extensions on
# scripts/wiki/wiki-scan-sources.sh end-to-end. The `p0X-` prefix follows the
# spec's portable shape (not a specific phase placement).
#
# Bash 3.2 compatible (MEM001). Single-script-file shape per AD-19.
# Trap-EXIT cleanup pattern per M032/P03/T04 throwaway-fixture protocol.
#
# Four assertion groups:
#   (1) FR-17 against $PROJECT_ROOT  — proposals records emit with [stage] badge
#   (2) FR-18-present against fixture — extra:* records emit when config declared
#   (3) FR-18-absent against fixture  — extra:* records do NOT emit when absent
#   (4) FR-19 against fixture         — knowledge-flat records emit for *.md flat

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

FIXTURE="/tmp/m032-p04-sc8-fixture-$$"
FIXTURE_NOEXTRA="/tmp/m032-p04-sc8-fixture-noextra-$$"
trap 'rm -rf "$FIXTURE" "$FIXTURE_NOEXTRA"' EXIT INT TERM

SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"
[ -x "$SCANNER" ] || { echo "FAIL: SC-8 scanner not executable: $SCANNER"; exit 1; }

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# ---- (1) FR-17 — proposals enumeration against $PROJECT_ROOT --------------

OUT_PROP="/tmp/m032-p04-sc8-proposals-$$.txt"
bash "$SCANNER" --root "$PROJECT_ROOT" > "$OUT_PROP" 2>/dev/null || {
  say_fail "FR-17 scanner returned non-zero against PROJECT_ROOT"
}
N_PROP="$(grep -c '^proposals:' "$OUT_PROP" || true)"
if [ "$N_PROP" -ge 1 ]; then
  say_pass "FR-17 emits >= 1 proposals:* record (got $N_PROP)"
else
  say_fail "FR-17 expected >= 1 proposals:* record; got $N_PROP"
fi

if grep -q '^proposals:M032-wiki-distribution-and-init-integration|proposals/M032-wiki-distribution-and-init-integration.md|' "$OUT_PROP"; then
  say_pass "FR-17 emits canonical proposals:M032-* record"
else
  say_fail "FR-17 missing canonical proposals:M032-wiki-distribution-and-init-integration record"
fi

# Title carries [stage] badge (per FR-17 contract). Without stage frontmatter
# the badge renders as [unknown].
if grep -qE '^proposals:[^|]+\|[^|]+\|.* \[(stub|brief|specified|active|closed|unknown)\]$' "$OUT_PROP"; then
  say_pass "FR-17 proposals records carry [stage] badge in title"
else
  say_fail "FR-17 proposals records missing [stage] badge surface"
fi

# Opt-out flag works.
OUT_NOPROP="/tmp/m032-p04-sc8-noproposals-$$.txt"
bash "$SCANNER" --root "$PROJECT_ROOT" --no-include-proposals > "$OUT_NOPROP" 2>/dev/null || true
if grep -q '^proposals:' "$OUT_NOPROP"; then
  say_fail "FR-17 --no-include-proposals still emitted proposals:* records"
else
  say_pass "FR-17 --no-include-proposals suppresses proposals:* records"
fi
rm -f "$OUT_NOPROP"

rm -f "$OUT_PROP"

# ---- fixture setup --------------------------------------------------------

mkdir -p "$FIXTURE/.orchestrator/proposals"
mkdir -p "$FIXTURE/.orchestrator/knowledge"
mkdir -p "$FIXTURE/specs"
mkdir -p "$FIXTURE/domain-decisions"

# .orchestrator/config.yml — block form.
# `domain-decisions/` rather than `decisions/`: PBJ-dogfood B3 sweep added
# top:/extra: collision detection in wiki-scan-sources.sh that fails-loud
# on reserved dirname-records (constitution|decisions|knowledge|...).
# `domain-decisions` is non-colliding and exercises the same FR-18 path.
cat > "$FIXTURE/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
type: orchestrator-config
wiki:
  extra_dirs:
    - specs/
    - domain-decisions/
EOF

cat > "$FIXTURE/specs/foo.md" <<'EOF'
# Foo Spec

Body of foo spec.
EOF

cat > "$FIXTURE/domain-decisions/bar.md" <<'EOF'
# Bar Decision

Body of bar decision.
EOF

cat > "$FIXTURE/.orchestrator/knowledge/baz.md" <<'EOF'
# Baz Flat Knowledge

Body of baz flat knowledge.
EOF

cat > "$FIXTURE/.orchestrator/proposals/sample.md" <<'EOF'
---
stage: brief
---

# Sample Proposal

Body of sample proposal.
EOF

# ---- (2) FR-18-present against fixture ------------------------------------

OUT_FIX="/tmp/m032-p04-sc8-fixture-$$.txt"
bash "$SCANNER" --root "$FIXTURE" > "$OUT_FIX" 2>/dev/null || {
  say_fail "FR-18-present scanner returned non-zero against fixture"
}

if grep -q '^extra:specs|specs/foo.md|' "$OUT_FIX"; then
  say_pass "FR-18 emits extra:specs|specs/foo.md record"
else
  say_fail "FR-18 missing extra:specs|specs/foo.md record"
fi

if grep -q '^extra:domain-decisions|domain-decisions/bar.md|' "$OUT_FIX"; then
  say_pass "FR-18 emits extra:domain-decisions|domain-decisions/bar.md record"
else
  say_fail "FR-18 missing extra:domain-decisions|domain-decisions/bar.md record"
fi

# ---- (4) FR-19 against fixture (combined with fixture run above) ----------

if grep -q '^knowledge-flat|knowledge/baz.md|' "$OUT_FIX"; then
  say_pass "FR-19 emits knowledge-flat|knowledge/baz.md record"
else
  say_fail "FR-19 missing knowledge-flat|knowledge/baz.md record"
fi

# proposals:sample with stage=brief should surface as [brief]
if grep -q '^proposals:sample|proposals/sample.md|.* \[brief\]$' "$OUT_FIX"; then
  say_pass "FR-17 fixture proposals:sample renders [brief] badge"
else
  say_fail "FR-17 fixture proposals:sample missing [brief] badge"
fi

rm -f "$OUT_FIX"

# ---- (3) FR-18-absent against fixture (no config.yml) ---------------------

mkdir -p "$FIXTURE_NOEXTRA/.orchestrator/proposals"
mkdir -p "$FIXTURE_NOEXTRA/specs"
cat > "$FIXTURE_NOEXTRA/specs/should-not-emit.md" <<'EOF'
# Should Not Emit

This file lives under specs/ but no config.yml declares wiki.extra_dirs:.
EOF

OUT_NOEX="/tmp/m032-p04-sc8-noex-$$.txt"
bash "$SCANNER" --root "$FIXTURE_NOEXTRA" > "$OUT_NOEX" 2>/dev/null || {
  say_fail "FR-18-absent scanner returned non-zero against fixture_noextra"
}

if grep -q '^extra:' "$OUT_NOEX"; then
  say_fail "FR-18-absent: scanner emitted extra:* records without config.yml declaration"
else
  say_pass "FR-18-absent: scanner emits zero extra:* records (no false-positive)"
fi
rm -f "$OUT_NOEX"

# ---- summary --------------------------------------------------------------

printf 'RESULT: SC-8 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
