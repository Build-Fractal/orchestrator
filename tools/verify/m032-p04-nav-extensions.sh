#!/usr/bin/env bash
# tools/verify/m032-p04-nav-extensions.sh
#
# M032/P04/T01 verifier — asserts the nav-generator (FR-17/18/19) renders the
# Proposals + per-extra_dirs + Knowledge — Flat sections inside the
# `# >>> auto-nav` region while byte-preserving the `# >>> custom-nav` region.
#
# Side-effect-free: backs up wiki/mkdocs.yml before regeneration and restores
# from backup on every exit path (EXIT/INT/TERM).
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# Exit 0 on PASS; 1 on FAIL.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"
NAVGEN="$ROOT/scripts/wiki/wiki-generate-nav.sh"
CONFIG="$ROOT/wiki/mkdocs.yml"
STUBGEN="$ROOT/scripts/wiki/wiki-generate-stubs.sh"

TMP="/tmp/m032-p04-nav-ext-$$"
mkdir -p "$TMP"
BACKUP="$TMP/mkdocs.yml.bak"
FIXTURE="$TMP/fixture"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

cleanup() {
  if [ -f "$BACKUP" ]; then
    cp "$BACKUP" "$CONFIG" 2>/dev/null || :
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

[ -x "$NAVGEN" ] || { say_fail "navgen not executable: $NAVGEN"; printf 'SUMMARY: m032-p04-nav-extensions pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }
[ -x "$STUBGEN" ] || { say_fail "stubgen not executable: $STUBGEN"; printf 'SUMMARY: m032-p04-nav-extensions pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }
[ -f "$CONFIG" ] || { say_fail "mkdocs.yml missing: $CONFIG"; printf 'SUMMARY: m032-p04-nav-extensions pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

# ---- (a) Orchestrator regeneration: Proposals section + custom-nav preservation

cp "$CONFIG" "$BACKUP"

if ! bash "$NAVGEN" --root "$ROOT" >/dev/null 2>&1; then
  say_fail "navgen returned non-zero against orchestrator root"
  printf 'SUMMARY: m032-p04-nav-extensions pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Confirm both region markers exist post-regenerate (FR-14 invariant)
if grep -qF '# >>> auto-nav' "$CONFIG"; then
  say_pass "auto-nav region marker present after regenerate"
else
  say_fail "auto-nav region marker absent after regenerate"
fi
if grep -qF '# >>> custom-nav' "$CONFIG"; then
  say_pass "custom-nav region marker present after regenerate (FR-14)"
else
  say_fail "custom-nav region marker absent after regenerate (FR-14 violation)"
fi

# Extract auto-nav region into a temp file
AUTO_BLOCK="$TMP/auto-block.txt"
awk '
  $0 ~ /^# >>> auto-nav/ { state=1; print; next }
  $0 ~ /^# <<< auto-nav end/ { print; state=0; next }
  state == 1 { print }
' "$CONFIG" > "$AUTO_BLOCK"

if grep -qE '^  - Proposals:' "$AUTO_BLOCK"; then
  say_pass "FR-17 Proposals: section emitted inside auto-nav region"
else
  say_fail "FR-17 Proposals: section missing from auto-nav region"
fi

# Sanity: at least one proposals/<basename>.md leaf entry under Proposals
if grep -qE 'proposals/.+\.md' "$AUTO_BLOCK"; then
  say_pass "FR-17 Proposals section contains at least one proposals/*.md leaf"
else
  say_fail "FR-17 Proposals section has zero proposals/*.md leafs"
fi

# Knowledge — Flat section is suppressed when zero records (orchestrator case)
if grep -qE '^  - Knowledge — Flat:' "$AUTO_BLOCK"; then
  say_fail "FR-19 Knowledge — Flat section emitted with zero records (suppression contract violated)"
else
  say_pass "FR-19 Knowledge — Flat section suppressed when zero flat records"
fi

# Restore orchestrator mkdocs.yml before fixture phase
cp "$BACKUP" "$CONFIG"

# ---- (b) Fixture regeneration: extra-dirs + Knowledge — Flat sections ------

mkdir -p "$FIXTURE/.orchestrator/proposals"
mkdir -p "$FIXTURE/.orchestrator/knowledge"
mkdir -p "$FIXTURE/specs"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/scripts/wiki"
# Stage the orchestrator's wiki tooling into the fixture (bundle-equivalent
# project-asset copy). nav-generator expects $ROOT/scripts/wiki/wiki-scan-sources.sh.
cp "$ROOT/scripts/wiki/wiki-scan-sources.sh" "$FIXTURE/scripts/wiki/"
cp "$ROOT/scripts/wiki/wiki-generate-nav.sh" "$FIXTURE/scripts/wiki/"
cp "$ROOT/scripts/wiki/wiki-generate-stubs.sh" "$FIXTURE/scripts/wiki/"
chmod +x "$FIXTURE/scripts/wiki/wiki-scan-sources.sh"
chmod +x "$FIXTURE/scripts/wiki/wiki-generate-nav.sh"
chmod +x "$FIXTURE/scripts/wiki/wiki-generate-stubs.sh"
# wiki-milestone-titles.sh is optional but referenced.
if [ -f "$ROOT/scripts/wiki/wiki-milestone-titles.sh" ]; then
  cp "$ROOT/scripts/wiki/wiki-milestone-titles.sh" "$FIXTURE/scripts/wiki/"
  chmod +x "$FIXTURE/scripts/wiki/wiki-milestone-titles.sh"
fi

cat > "$FIXTURE/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
type: orchestrator-config
wiki:
  extra_dirs:
    - specs/
EOF

cat > "$FIXTURE/specs/spec1.md" <<'EOF'
# Spec One
EOF

cat > "$FIXTURE/.orchestrator/knowledge/flat1.md" <<'EOF'
# Flat One
EOF

cat > "$FIXTURE/.orchestrator/proposals/p1.md" <<'EOF'
---
stage: brief
---
# Sample Proposal P1
EOF

# minimal mkdocs.yml — empty file (navgen will inject region pair)
: > "$FIXTURE/wiki/mkdocs.yml"

if bash "$NAVGEN" --root "$FIXTURE" >/dev/null 2>&1; then
  say_pass "navgen exits 0 against fixture (extra_dirs declared)"
else
  say_fail "navgen non-zero against fixture"
fi

FIX_AUTO="$TMP/fixture-auto-block.txt"
awk '
  $0 ~ /^# >>> auto-nav/ { state=1; print; next }
  $0 ~ /^# <<< auto-nav end/ { print; state=0; next }
  state == 1 { print }
' "$FIXTURE/wiki/mkdocs.yml" > "$FIX_AUTO"

if grep -qE '^  - Specs:' "$FIX_AUTO"; then
  say_pass "FR-18 Specs section (Title-Case extra:specs) emitted under auto-nav"
else
  say_fail "FR-18 Specs section missing from fixture auto-nav"
fi

if grep -qE '^  - Knowledge — Flat:' "$FIX_AUTO"; then
  say_pass "FR-19 Knowledge — Flat section emitted under fixture auto-nav"
else
  say_fail "FR-19 Knowledge — Flat section missing from fixture auto-nav"
fi

if grep -qE '^  - Proposals:' "$FIX_AUTO"; then
  say_pass "FR-17 Proposals section emitted under fixture auto-nav"
else
  say_fail "FR-17 Proposals section missing from fixture auto-nav"
fi

# ---- (c) custom-nav preservation invariant (FR-14) ------------------------

# Inject sentinel into custom-nav region of fixture mkdocs.yml, regenerate,
# assert sentinel survives byte-identical.
SENTINEL="# m032-p04-t01-nav-ext-sentinel-$$"
# Place inside custom-nav region
awk -v s="$SENTINEL" '
  { print }
  /^# >>> custom-nav/ { print s }
' "$FIXTURE/wiki/mkdocs.yml" > "$TMP/fix-with-sentinel.yml"
cp "$TMP/fix-with-sentinel.yml" "$FIXTURE/wiki/mkdocs.yml"

if ! bash "$NAVGEN" --root "$FIXTURE" >/dev/null 2>&1; then
  say_fail "navgen failed on second-regenerate fixture"
fi

if grep -qF "$SENTINEL" "$FIXTURE/wiki/mkdocs.yml"; then
  say_pass "FR-14 custom-nav region byte-preserves sentinel across regenerate"
else
  say_fail "FR-14 custom-nav region lost sentinel across regenerate"
fi

# ---- (d) stub-generator routes new categories ----------------------------

if grep -qE 'proposals:\*' "$STUBGEN"; then
  say_pass "stub generator declares proposals:* case-arm"
else
  say_fail "stub generator missing proposals:* case-arm"
fi

if grep -qE 'knowledge-flat\)' "$STUBGEN"; then
  say_pass "stub generator declares knowledge-flat case-arm"
else
  say_fail "stub generator missing knowledge-flat case-arm"
fi

if grep -qE 'extra:\*\)' "$STUBGEN"; then
  say_pass "stub generator declares extra:* case-arm"
else
  say_fail "stub generator missing extra:* case-arm"
fi

printf 'SUMMARY: m032-p04-nav-extensions pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
