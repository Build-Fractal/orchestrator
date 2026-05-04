#!/usr/bin/env bash
# tools/verify/m032-p03-with-giscus-scope.sh — M032/P03/T01 FR-8 verifier.
#
# Asserts the wiki-init.sh --with-giscus workflow code path is present
# (text-grep checks against the script body) and exercises stub-mode
# happy-path and failure-injection branches against a tmpdir fixture.
# The shared P01 fixture is exercised by the SC-4 acceptance script;
# this verifier stays hermetic.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -x "$WI" ]; then
  say_fail "$WI absent or non-executable"
  printf 'SUMMARY: m032-p03-with-giscus-scope pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Static text checks on wiki-init.sh source.
for tok in '--with-giscus' '--repo' '--category' 'M032_GISCUS_IDS_FROM_GH_STUB' \
           'wiki-giscus-config-check.sh' 'integration-giscus-config-failed' \
           'integration-giscus-config-check-failed' 'GISCUS_REPO_VAL' \
           'GISCUS_REPO_ID_VAL' 'GISCUS_CATEGORY_VAL' 'GISCUS_CATEGORY_ID_VAL'; do
  if grep -qF -e "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode happy path against a tmpdir fixture.
TMPDIR_F="$(mktemp -d -t m032-p03-with-giscus.XXXXXX)"
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/wiki/overrides/partials"
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
# Also stage a minimal mkdocs.yml so wiki-init.sh's PRE_STAGE_NO_OP path fires
# (otherwise the bundle-staging step will trip the FR-22 collision-check on
# our hermetic tmpdir which has no installed-files.txt).
cp "$REPO_ROOT/wiki/mkdocs.yml" "$TMPDIR_F/wiki/mkdocs.yml"
# Set up a minimal git remote so wiki-init's FR-5 path doesn't bail.
( cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-tmp.git ) >/dev/null 2>&1

set +e
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ] && grep -qF 'fixture-owner/m032-p03-tmp' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode happy path substitutes IDs in tmpdir fixture (rc=0)"
else
  say_fail "stub-mode happy path: rc=$rc; substitution did not fire"
fi

# Hermetic failure injection — re-stage the partial first to reset placeholder state.
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
set +e
M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ] && grep -qF '{{giscus_repo}}' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode fail injection: rc=$rc, partial preserved in placeholder state"
else
  say_fail "stub-mode fail injection: rc=$rc; partial not preserved"
fi

printf 'SUMMARY: m032-p03-with-giscus-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
