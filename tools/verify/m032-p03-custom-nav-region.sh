#!/usr/bin/env bash
# tools/verify/m032-p03-custom-nav-region.sh — FR-14 + MIT-005 verifier (T03).
#
# Static text checks against the amended wiki-generate-nav.sh + dynamic checks
# exercising the four FR-14 branches (AS-1 byte-preserve, AS-2 empty-legacy
# migrate, MIT-005 non-empty-legacy migrate with diagnostic, AS-3 self-heal).
#
# Bash 3.2 compatible. Single-script-file shape per AD-19.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GEN="$REPO_ROOT/scripts/wiki/wiki-generate-nav.sh"

pass=0
fail=0

say_pass() {
  pass=$((pass + 1))
  printf 'PASS: %s\n' "$1"
}

say_fail() {
  fail=$((fail + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

# ---- static text checks ----------------------------------------------------
for tok in 'MARKER_AUTO_START' 'MARKER_AUTO_END' 'MARKER_CUSTOM_START' \
           'MARKER_CUSTOM_END' 'LEGACY_MARKER_START' 'LEGACY_MARKER_END' \
           '# >>> auto-nav' '# <<< auto-nav end' '# >>> custom-nav' \
           '# <<< custom-nav end' '# >>> M012-P01 nav' \
           'Migrated %d custom nav entries from legacy markers to custom-nav region' \
           'count_between_markers' 'extract_between_markers' \
           'FR-14' 'MIT-005'; do
  if grep -qF "$tok" "$GEN"; then
    say_pass "wiki-generate-nav.sh contains: $tok"
  else
    say_fail "wiki-generate-nav.sh missing: $tok"
  fi
done

# ---- dynamic branch checks --------------------------------------------------
TMP_F=$(mktemp -d -t m032-p03-nav.XXXXXX)
trap 'rm -rf "$TMP_F"' EXIT INT TERM

mkdir -p "$TMP_F/wiki/docs" "$TMP_F/.orchestrator/memory"
mkdir -p "$TMP_F/scripts/wiki"
# Make the scanner + titles helper available so wiki-generate-nav.sh's
# scanner step does not abort. We point its --root to TMP_F and copy
# wiki-scan-sources.sh + wiki-milestone-titles.sh into the fixture's
# scripts/wiki/ directory.
cp "$REPO_ROOT/scripts/wiki/wiki-scan-sources.sh" "$TMP_F/scripts/wiki/" 2>/dev/null || true
cp "$REPO_ROOT/scripts/wiki/wiki-milestone-titles.sh" "$TMP_F/scripts/wiki/" 2>/dev/null || true

# AS-1: populated custom-nav byte-preserved across regenerate.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
  printf '# >>> auto-nav (auto-generated — do not edit by hand)\nnav:\n  - Home: index.md\n# <<< auto-nav end\n'
  printf '# >>> custom-nav\n  - Domain Decisions: domain-decisions.md\n  - Project Spec: spec.md\n  - Team Notes: notes.md\n# <<< custom-nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"

SHA_BEFORE=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')
bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true
SHA_AFTER=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')

if [ -n "$SHA_BEFORE" ] && [ "$SHA_BEFORE" = "$SHA_AFTER" ]; then
  say_pass "AS-1: custom-nav region byte-preserved across regenerate"
else
  say_fail "AS-1: custom-nav region modified ($SHA_BEFORE -> $SHA_AFTER)"
fi

# AS-2: empty-legacy migration. Rebuild fixture with legacy markers + empty content.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
  printf '# >>> M012-P01 nav (auto-generated — do not edit by hand)\n# <<< M012-P01 nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"

out_empty="$(bash "$GEN" --root "$TMP_F" 2>/dev/null || true)"

if grep -qF '# >>> auto-nav' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! grep -qF '# >>> M012-P01 nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! printf '%s' "$out_empty" | grep -qF 'Migrated'; then
  say_pass "AS-2: empty-legacy migrated to new shape, no diagnostic emitted"
else
  say_fail "AS-2: empty-legacy migration shape unexpected"
fi

# MIT-005: non-empty-legacy migration with diagnostic.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
  printf '# >>> M012-P01 nav (auto-generated — do not edit by hand)\n'
  printf '  - Domain A: a.md\n'
  printf '  - Domain B: b.md\n'
  printf '  - Domain C: c.md\n'
  printf '# <<< M012-P01 nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"

out_nonempty="$(bash "$GEN" --root "$TMP_F" 2>/dev/null || true)"

if printf '%s' "$out_nonempty" | grep -qF 'Migrated 3 custom nav entries from legacy markers to custom-nav region' && \
   grep -qF 'Domain A: a.md' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF 'Domain B: b.md' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF 'Domain C: c.md' "$TMP_F/wiki/mkdocs.yml"; then
  say_pass "MIT-005: non-empty legacy preserved verbatim, diagnostic emitted with count=3"
else
  say_fail "MIT-005: non-empty legacy migration shape unexpected"
fi

# AS-3: self-heal — delete custom-nav markers manually, expect re-creation.
sed -i.bak '/^# >>> custom-nav$/,/^# <<< custom-nav end$/d' "$TMP_F/wiki/mkdocs.yml"
rm -f "$TMP_F/wiki/mkdocs.yml.bak"

bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true

if grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF '# <<< custom-nav end' "$TMP_F/wiki/mkdocs.yml"; then
  say_pass "AS-3: self-heal re-created custom-nav markers"
else
  say_fail "AS-3: self-heal did not re-create custom-nav markers"
fi

printf 'SUMMARY: m032-p03-custom-nav-region pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
