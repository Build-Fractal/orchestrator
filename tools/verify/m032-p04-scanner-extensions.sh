#!/usr/bin/env bash
# tools/verify/m032-p04-scanner-extensions.sh
#
# M032/P04/T01 verifier — asserts FR-17 + FR-18 + FR-19 scanner amendments on
# scripts/wiki/wiki-scan-sources.sh emit the three new category prefixes
# (proposals:*, extra:*, knowledge-flat) against orchestrator + fixture.
#
# Side-effect-free against the orchestrator working tree: no scanner output is
# written under $ROOT (the scanner emits records to stdout). Fixture lives under
# /tmp and is removed via trap.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# Exit 0 on PASS; 1 on FAIL.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"

FIXTURE="/tmp/m032-p04-scanner-ext-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -x "$SCANNER" ]; then
  say_fail "scanner not executable: $SCANNER"
  printf 'SUMMARY: m032-p04-scanner-extensions pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- (a) flag plumbing ----------------------------------------------------

if grep -qF -- '--include-proposals' "$SCANNER"; then
  say_pass "scanner declares --include-proposals flag"
else
  say_fail "scanner missing --include-proposals flag"
fi

if grep -qF -- '--no-include-proposals' "$SCANNER"; then
  say_pass "scanner declares --no-include-proposals flag"
else
  say_fail "scanner missing --no-include-proposals flag"
fi

# ---- (b) FR-17 against orchestrator ROOT ---------------------------------

OUT_ORCH="/tmp/m032-p04-scan-orch-$$.txt"
if bash "$SCANNER" --root "$ROOT" > "$OUT_ORCH" 2>/dev/null; then
  say_pass "scanner exits 0 against orchestrator root (default scope)"
else
  say_fail "scanner non-zero against orchestrator root"
fi

if grep -q '^proposals:' "$OUT_ORCH"; then
  say_pass "FR-17 emits proposals:* records against orchestrator root"
else
  say_fail "FR-17 emitted no proposals:* records against orchestrator root"
fi

# every proposal record carries [stage] badge in title field
if awk -F'|' '
    $1 ~ /^proposals:/ && $3 !~ / \[(stub|brief|specified|active|closed|unknown)\]$/ {
      bad++
    }
    END { exit (bad ? 1 : 0) }
' "$OUT_ORCH"; then
  say_pass "FR-17 every proposals:* record carries enumerated [stage] badge"
else
  say_fail "FR-17 some proposals:* records missing enumerated [stage] badge"
fi

# Existing emissions still present (additivity)
if grep -q '^top:constitution|memory/constitution.md|' "$OUT_ORCH"; then
  say_pass "additivity: top:constitution unchanged"
else
  say_fail "additivity: top:constitution lost"
fi

if grep -q '^top:glossary|wiki/glossary.md|' "$OUT_ORCH"; then
  say_pass "additivity: top:glossary unchanged (FR-15)"
else
  say_fail "additivity: top:glossary lost"
fi

if grep -q '^knowledge:patterns|knowledge/patterns/MEM' "$OUT_ORCH"; then
  say_pass "additivity: knowledge:patterns unchanged"
else
  say_fail "additivity: knowledge:patterns lost"
fi

# Orchestrator has no flat knowledge files — knowledge-flat records should be zero
N_FLAT="$(grep -c '^knowledge-flat' "$OUT_ORCH" || true)"
if [ "$N_FLAT" = "0" ]; then
  say_pass "FR-19 zero knowledge-flat records on orchestrator (no flat *.md files today)"
else
  say_fail "FR-19 expected 0 knowledge-flat records on orchestrator; got $N_FLAT"
fi

rm -f "$OUT_ORCH"

# ---- (c) opt-out via --no-include-proposals -------------------------------

OUT_NOPROP="/tmp/m032-p04-scan-noprop-$$.txt"
bash "$SCANNER" --root "$ROOT" --no-include-proposals > "$OUT_NOPROP" 2>/dev/null || true
if grep -q '^proposals:' "$OUT_NOPROP"; then
  say_fail "--no-include-proposals still emitted proposals:* records"
else
  say_pass "--no-include-proposals suppresses proposals:* records"
fi
rm -f "$OUT_NOPROP"

# ---- (d) FR-18 + FR-19 against fixture -----------------------------------

mkdir -p "$FIXTURE/.orchestrator/proposals"
mkdir -p "$FIXTURE/.orchestrator/knowledge"
mkdir -p "$FIXTURE/specs/v1"
mkdir -p "$FIXTURE/decisions"

cat > "$FIXTURE/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
type: orchestrator-config
wiki:
  extra_dirs:
    - specs/v1/
    - decisions/
EOF

cat > "$FIXTURE/specs/v1/spec1.md" <<'EOF'
# Spec One
Body.
EOF

cat > "$FIXTURE/decisions/dec1.md" <<'EOF'
# Decision One
Body.
EOF

cat > "$FIXTURE/.orchestrator/knowledge/flatfile.md" <<'EOF'
# Flat File Knowledge
Body.
EOF

cat > "$FIXTURE/.orchestrator/proposals/active-prop.md" <<'EOF'
---
stage: active
---
# Active Proposal
Body.
EOF

OUT_FIX="/tmp/m032-p04-scan-fix-$$.txt"
if bash "$SCANNER" --root "$FIXTURE" > "$OUT_FIX" 2>/dev/null; then
  say_pass "scanner exits 0 against fixture"
else
  say_fail "scanner non-zero against fixture"
fi

# FR-18: extra:specs-v1 (path separator / -> -)
if grep -q '^extra:specs-v1|specs/v1/spec1.md|' "$OUT_FIX"; then
  say_pass "FR-18 emits extra:specs-v1|specs/v1/spec1.md (path separator -> '-')"
else
  say_fail "FR-18 missing extra:specs-v1|specs/v1/spec1.md"
fi

if grep -q '^extra:decisions|decisions/dec1.md|' "$OUT_FIX"; then
  say_pass "FR-18 emits extra:decisions|decisions/dec1.md"
else
  say_fail "FR-18 missing extra:decisions|decisions/dec1.md"
fi

# FR-19
if grep -q '^knowledge-flat|knowledge/flatfile.md|' "$OUT_FIX"; then
  say_pass "FR-19 emits knowledge-flat|knowledge/flatfile.md"
else
  say_fail "FR-19 missing knowledge-flat|knowledge/flatfile.md"
fi

# FR-17: stage=active surfaces in badge
if grep -q '^proposals:active-prop|proposals/active-prop.md|.* \[active\]$' "$OUT_FIX"; then
  say_pass "FR-17 fixture proposals:active-prop renders [active] badge"
else
  say_fail "FR-17 fixture proposals:active-prop missing [active] badge"
fi

rm -f "$OUT_FIX"

# ---- (e) FR-18-absent — fixture without config.yml ------------------------

FIX2="/tmp/m032-p04-scan-fix2-$$"
mkdir -p "$FIX2/.orchestrator/proposals"
mkdir -p "$FIX2/specs"
cat > "$FIX2/specs/should-not-emit.md" <<'EOF'
# Phantom
EOF

OUT_FIX2="/tmp/m032-p04-scan-fix2-$$.txt"
bash "$SCANNER" --root "$FIX2" > "$OUT_FIX2" 2>/dev/null || true
if grep -q '^extra:' "$OUT_FIX2"; then
  say_fail "FR-18-absent: scanner emitted extra:* without config.yml declaration"
else
  say_pass "FR-18-absent: zero extra:* records (no false-positive section)"
fi
rm -rf "$FIX2"
rm -f "$OUT_FIX2"

printf 'SUMMARY: m032-p04-scanner-extensions pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
