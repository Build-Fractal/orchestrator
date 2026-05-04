#!/usr/bin/env bash
# tools/verify/m032-p02-wiki-init-default-scope.sh
#
# M032/P02/T01 verifier (Truth 2): exercises scripts/lifecycle/wiki-init.sh
# default-scope invocation against the P01 fresh-project fixture
# (tests/fixtures/m032-fresh-project-fixture/).
#
# Asserts:
#   1. wiki-init.sh exists, is executable.
#   2. Default invocation against a staged fixture (with a fake git
#      remote) produces <fixture>/wiki/mkdocs.yml with resolved
#      site_name=m032-fresh-project-fixture and
#      repo_url=https://github.com/fixture-owner/m032-fresh-project-fixture
#      and contains NO {{...}} placeholders.
#   3. Default invocation does NOT stage commands/, scripts/,
#      references/, or templates/ at the fixture root (those are P01's
#      installer-staging responsibility — wiki-init.sh filters to
#      wiki/ source only).
#   4. wiki-init.sh authors a wiki/glossary.md stub.
#   5. FR-12 toolchain probe: PATH=/dev/null invocation exits 3 with
#      diagnostic substring on stderr.
#   6. FR-5 P03-flag rejection: --with-giscus exits 5 with diagnostic.
#   7. FR-5 P03-flag rejection: --deploy exits 5 with diagnostic.
#   8. Idempotency (US-2 Acceptance Scenario 5): a second invocation
#      against an already-templated fixture exits 0 with "no changes".
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No process substitution. Pipes restricted to one-stage where used.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WITH_ENV="$PROJECT_ROOT/scripts/util/with-env.sh"

WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"

pass=0
fail=0

check_pass() {
  pass=$((pass + 1))
  echo "PASS: $1"
}

check_fail() {
  fail=$((fail + 1))
  echo "FAIL: $1"
}

# Check 1: wiki-init.sh exists and is executable.
if [ -x "$WIKI_INIT" ]; then
  check_pass "$WIKI_INIT exists and is executable"
else
  check_fail "$WIKI_INIT missing or not executable"
  echo "SUMMARY: m032-p02-wiki-init-default-scope.sh pass=$pass fail=$fail"
  exit 1
fi

# Stage a temp copy of the fresh-project fixture and init a fake git remote.
TMP="$(mktemp -d -t m032-p02-wiki-init.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

cp -R "$FIXTURE_SRC/." "$TMP/"
git -C "$TMP" init -q
git -C "$TMP" remote add origin "https://github.com/fixture-owner/m032-fresh-project-fixture.git"

# Run wiki-init.sh default scope.
out_log="$(mktemp -t m032-p02-out.XXXXXX)"
err_log="$(mktemp -t m032-p02-err.XXXXXX)"
set +e
bash "$WIKI_INIT" --project-dir "$TMP" >"$out_log" 2>"$err_log"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  check_pass "wiki-init.sh default invocation exits 0 against fixture"
else
  check_fail "wiki-init.sh default invocation exit $rc against fixture"
  echo "--- stderr: ---" >&2
  cat "$err_log" >&2
fi

MKDOCS="$TMP/wiki/mkdocs.yml"

# Check 2: mkdocs.yml exists at fixture root.
if [ -f "$MKDOCS" ]; then
  check_pass "$MKDOCS exists"
else
  check_fail "$MKDOCS missing after wiki-init.sh"
fi

# Check 3: site_name resolved to the fixture repo basename.
if grep -q 'site_name: "m032-fresh-project-fixture"' "$MKDOCS"; then
  check_pass "mkdocs.yml site_name resolved to m032-fresh-project-fixture"
else
  check_fail "mkdocs.yml site_name NOT resolved (expected m032-fresh-project-fixture)"
fi

# Check 4: repo_url resolved to fixture-owner/m032-fresh-project-fixture.
if grep -q 'repo_url: "https://github.com/fixture-owner/m032-fresh-project-fixture"' "$MKDOCS"; then
  check_pass "mkdocs.yml repo_url resolved to fixture-owner/m032-fresh-project-fixture"
else
  check_fail "mkdocs.yml repo_url NOT resolved correctly"
fi

# Check 5: site_url resolved (lowercase owner per GitHub Pages convention).
if grep -q 'site_url: "https://fixture-owner.github.io/m032-fresh-project-fixture/"' "$MKDOCS"; then
  check_pass "mkdocs.yml site_url resolved to fixture-owner.github.io/m032-fresh-project-fixture/"
else
  check_fail "mkdocs.yml site_url NOT resolved correctly"
fi

# Check 6: NO {{...}} placeholders remain.
if grep -qE '\{\{(site_name|site_description|site_url|repo_url)\}\}' "$MKDOCS"; then
  check_fail "mkdocs.yml still contains unresolved {{...}} placeholders"
else
  check_pass "mkdocs.yml has no unresolved {{site_*}} / {{repo_url}} placeholders"
fi

# Check 7: glossary stub authored.
if [ -f "$TMP/wiki/glossary.md" ]; then
  check_pass "wiki/glossary.md stub authored"
else
  check_fail "wiki/glossary.md stub NOT authored"
fi

# Check 8: wiki-init.sh did NOT stage commands/, scripts/, references/, templates/.
# (Those are P01 installer responsibility; wiki-init filters source==wiki/ only.)
for d in commands scripts references templates; do
  if [ -d "$TMP/$d" ]; then
    check_fail "wiki-init.sh leaked staging into $d/ (should be P01 installer scope only)"
  else
    check_pass "wiki-init.sh did not stage $d/ (filter source==wiki/ holds)"
  fi
done

# Check 9: FR-12 toolchain probe — synthesize a PATH that excludes python3 and pip3.
TMP2="$(mktemp -d -t m032-p02-toolchain.XXXXXX)"
cp -R "$FIXTURE_SRC/." "$TMP2/"
git -C "$TMP2" init -q
git -C "$TMP2" remote add origin "https://github.com/fixture-owner/probe.git"

# Build a minimal PATH dir containing the standard utilities wiki-init.sh
# needs (dirname, mktemp, mkdir, cp, rm, mv, cat, awk, sed, grep, git,
# uname, command via bash builtin) but NOT python3/pip3. We symlink the
# whitelist; python3/pip3 are deliberately omitted.
PROBE_BIN="$(mktemp -d -t m032-p02-probe-bin.XXXXXX)"
for tool in bash sh dirname mktemp mkdir cp rm mv cat awk sed grep git uname tr printf chmod; do
  tool_path=""
  if [ -x "/bin/$tool" ]; then
    tool_path="/bin/$tool"
  elif [ -x "/usr/bin/$tool" ]; then
    tool_path="/usr/bin/$tool"
  elif [ -x "/usr/local/bin/$tool" ]; then
    tool_path="/usr/local/bin/$tool"
  fi
  if [ -n "$tool_path" ]; then
    ln -s "$tool_path" "$PROBE_BIN/$tool"
  fi
done

err_tc="$(mktemp -t m032-p02-tc-err.XXXXXX)"
set +e
bash "$WITH_ENV" "PATH=$PROBE_BIN" -- bash "$WIKI_INIT" --project-dir "$TMP2" 2>"$err_tc"
rc_tc=$?
set -e

rm -rf "$PROBE_BIN"

if [ "$rc_tc" -eq 3 ]; then
  check_pass "wiki-init.sh exits 3 when python3/pip3 missing (PATH=/dev/null)"
else
  check_fail "wiki-init.sh exit $rc_tc with PATH=/dev/null (expected 3)"
fi

if grep -q 'python3/pip3 missing' "$err_tc"; then
  check_pass "wiki-init.sh stderr names 'python3/pip3 missing' on toolchain probe failure"
else
  check_fail "wiki-init.sh stderr missing 'python3/pip3 missing' diagnostic"
fi

rm -rf "$TMP2"

# Check 10: --with-giscus arg-validation (P03/T01 in-flight repair).
# Pre-P03: --with-giscus exited 5 with 'reserved for P03'. P03/T01 lands the
# real implementation; calling --with-giscus WITHOUT --repo / --category now
# exits 2 with a 'requires both --repo' diagnostic. Mirrors the P01 in-flight
# repair at commit 4dedb92a where P01 verifiers were relaxed once P02 added
# the wiki/ project_assets entry.
err_giscus="$(mktemp -t m032-p02-giscus-err.XXXXXX)"
set +e
bash "$WIKI_INIT" --project-dir "$TMP" --with-giscus 2>"$err_giscus"
rc_giscus=$?
set -e

if [ "$rc_giscus" -eq 2 ]; then
  check_pass "wiki-init.sh exits 2 on bare --with-giscus (P03/T01: missing --repo / --category)"
else
  check_fail "wiki-init.sh exit $rc_giscus on bare --with-giscus (expected 2 post-P03/T01)"
fi

if grep -q 'requires both --repo' "$err_giscus"; then
  check_pass "wiki-init.sh stderr names missing --repo / --category on bare --with-giscus"
else
  check_fail "wiki-init.sh stderr missing 'requires both --repo' diagnostic on bare --with-giscus"
fi

# Check 11: --deploy rejection.
err_deploy="$(mktemp -t m032-p02-deploy-err.XXXXXX)"
set +e
bash "$WIKI_INIT" --project-dir "$TMP" --deploy 2>"$err_deploy"
rc_deploy=$?
set -e

if [ "$rc_deploy" -eq 5 ]; then
  check_pass "wiki-init.sh exits 5 on --deploy (P03 deliverable)"
else
  check_fail "wiki-init.sh exit $rc_deploy on --deploy (expected 5)"
fi

# Check 12: idempotency — second invocation says "no changes".
out_idem="$(mktemp -t m032-p02-idem-out.XXXXXX)"
set +e
bash "$WIKI_INIT" --project-dir "$TMP" >"$out_idem" 2>&1
rc_idem=$?
set -e

if [ "$rc_idem" -eq 0 ]; then
  check_pass "wiki-init.sh idempotent re-run exits 0"
else
  check_fail "wiki-init.sh idempotent re-run exit $rc_idem (expected 0)"
fi

if grep -q 'no changes' "$out_idem"; then
  check_pass "wiki-init.sh idempotent re-run emits 'no changes'"
else
  check_fail "wiki-init.sh idempotent re-run missing 'no changes' diagnostic"
fi

rm -f "$out_log" "$err_log" "$err_tc" "$err_giscus" "$err_deploy" "$out_idem"

echo "SUMMARY: m032-p02-wiki-init-default-scope.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
