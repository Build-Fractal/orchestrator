#!/usr/bin/env bash
# tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh — SC-6 acceptance.
#
# Exercises FR-14 + MIT-005 against a tmpdir clone of wiki/mkdocs.yml. Covers
# the four FR-14 branches:
#   AS-1 byte-identical preservation of populated custom-nav across regenerate.
#   AS-2 empty-legacy migration (M012-P01 nav -> auto-nav + empty custom-nav).
#   MIT-005 non-empty-legacy migration with diagnostic emission.
#   AS-3 self-healing of deleted custom-nav markers.
#
# Token contract for the m032-p03-acceptance-shape-sc6 verifier:
# SC-6, FR-14, MIT-005, auto-nav, custom-nav, M012-P01 nav, Migrated, byte-identical.
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

if [ ! -x "$GEN" ]; then
  printf 'ERROR: %s missing or non-executable\n' "$GEN" >&2
  printf 'SUMMARY: m032-acceptance-sc6 pass=0 fail=1\n'
  exit 1
fi

# Build a self-contained fixture root that wiki-generate-nav.sh can scan
# without polluting the real repo.
TMP_F=$(mktemp -d -t m032-acc-sc6.XXXXXX)
trap 'rm -rf "$TMP_F"' EXIT INT TERM

mkdir -p "$TMP_F/wiki/docs" "$TMP_F/.orchestrator/memory"
mkdir -p "$TMP_F/scripts/wiki"
cp "$REPO_ROOT/scripts/wiki/wiki-scan-sources.sh" "$TMP_F/scripts/wiki/" 2>/dev/null || true
cp "$REPO_ROOT/scripts/wiki/wiki-milestone-titles.sh" "$TMP_F/scripts/wiki/" 2>/dev/null || true

# ----------------------------------------------------------------------------
# AS-1 — populated custom-nav region is byte-identical after regenerate.
# ----------------------------------------------------------------------------
{
  printf 'site_name: "sc6-fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
  printf '# >>> auto-nav (auto-generated — do not edit by hand)\nnav:\n  - Home: index.md\n# <<< auto-nav end\n'
  printf '# >>> custom-nav\n  - Domain Decisions: domain-decisions.md\n  - Project Spec: spec.md\n  - Team Notes: notes.md\n# <<< custom-nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"

SHA_BEFORE=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')
bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true
SHA_AFTER=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')

if [ -n "$SHA_BEFORE" ] && [ "$SHA_BEFORE" = "$SHA_AFTER" ]; then
  say_pass "SC-6 AS-1: custom-nav region is byte-identical across regenerate"
else
  say_fail "SC-6 AS-1: custom-nav region NOT byte-identical (before=$SHA_BEFORE after=$SHA_AFTER)"
fi

# ----------------------------------------------------------------------------
# AS-2 — empty M012-P01 nav legacy markers migrate to auto-nav + empty custom-nav,
#         no migration diagnostic on stdout.
# ----------------------------------------------------------------------------
{
  printf 'site_name: "sc6-fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
  printf '# >>> M012-P01 nav (auto-generated — do not edit by hand)\n# <<< M012-P01 nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"

out_empty="$(bash "$GEN" --root "$TMP_F" 2>/dev/null || true)"

if grep -qF '# >>> auto-nav' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! grep -qF '# >>> M012-P01 nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! printf '%s' "$out_empty" | grep -qF 'Migrated'; then
  say_pass "SC-6 AS-2: empty M012-P01 nav legacy migrated cleanly, zero diagnostics"
else
  say_fail "SC-6 AS-2: empty-legacy migration shape unexpected (FR-14 AS-2 contract violated)"
fi

# ----------------------------------------------------------------------------
# MIT-005 — non-empty legacy content moves verbatim into custom-nav region,
#           and a 'Migrated <N>' diagnostic is emitted with the right count.
# ----------------------------------------------------------------------------
{
  printf 'site_name: "sc6-fixture"\nrepo_url: "https://github.com/fixture/repo"\ndocs_dir: "docs"\nsite_dir: "site"\n\n'
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
  say_pass "SC-6 MIT-005: non-empty legacy preserved verbatim, 'Migrated 3' diagnostic emitted"
else
  say_fail "SC-6 MIT-005: non-empty legacy migration shape unexpected (silent migration is the failure mode)"
fi

# ----------------------------------------------------------------------------
# AS-3 — self-heal re-creates deleted custom-nav markers at the standard slot.
# ----------------------------------------------------------------------------
sed -i.bak '/^# >>> custom-nav$/,/^# <<< custom-nav end$/d' "$TMP_F/wiki/mkdocs.yml"
rm -f "$TMP_F/wiki/mkdocs.yml.bak"

bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true

if grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF '# <<< custom-nav end' "$TMP_F/wiki/mkdocs.yml"; then
  say_pass "SC-6 AS-3: deleted custom-nav markers self-healed"
else
  say_fail "SC-6 AS-3: self-heal did not re-create custom-nav markers"
fi

printf 'SUMMARY: m032-acceptance-sc6 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
