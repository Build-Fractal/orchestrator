#!/usr/bin/env bash
# tools/verify/m035-p00-wiki-deploy-stage.sh -- M035 P00 T04 shape verifier.
#
# Asserts the wiki-init.sh --deploy step 2 staging-fallback block (M032 SC-5
# fixture-completeness gap closer) is wired and behaves correctly:
#
#   1. Static layer: scripts/lifecycle/wiki-init.sh contains the M035/P00/T04
#      anchor comment AND the staging block precedes the existing
#      bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" invocation.
#
#   2. Behaviour layer: against a tmp $PROJECT_DIR fixture that has NO
#      scripts/wiki/ subdir and a git remote, invoke
#      `wiki-init.sh --deploy --project-dir <fix>` with M032_DEPLOY_GH_API_STUB=1
#      to bypass the gh API. After the run, <fixture>/scripts/wiki/wiki-deploy.sh
#      MUST exist (staged from $REPO_ROOT).
#
# Bash 3.2 compatible.
#
# Exit:
#   0  PASS
#   1  FAIL

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

WIKI_INIT="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"

pass=0
fail=0
failures=""

check_pass() {
    pass=$((pass + 1))
    printf '  ok: %s\n' "$1"
}

check_fail() {
    fail=$((fail + 1))
    failures="${failures}    - ${1}\n"
    printf '  FAIL: %s\n' "$1"
}

WORKDIR="$( mktemp -d -t m035-deploy-stage.XXXXXX )"
trap 'rm -rf "$WORKDIR"' EXIT

printf '=== m035-p00-wiki-deploy-stage (T04 / M032 SC-5 fallback) ===\n'
printf 'bash_version=%s\n' "${BASH_VERSION:-unknown}"
printf 'workdir=%s\n' "$WORKDIR"
printf '\n'

# ---------- Static layer ----------

if [ -f "$WIKI_INIT" ]; then
    check_pass "wiki-init.sh present at $WIKI_INIT"
else
    check_fail "wiki-init.sh missing at $WIKI_INIT"
    printf 'FAIL: m035-p00-wiki-deploy-stage (pass=%d fail=%d)\n' "$pass" "$fail"
    exit 1
fi

# Anchor comment present.
if grep -q 'M035/P00/T04 . closes M032 SC-5' "$WIKI_INIT"; then
    check_pass "wiki-init.sh carries M035/P00/T04 anchor comment"
else
    check_fail "wiki-init.sh missing M035/P00/T04 anchor comment"
fi

# Stage line present (the line that performs the cp).
STAGE_LINE_RE='cp "\$REPO_ROOT/scripts/wiki/wiki-deploy.sh" "\$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"'
if grep -qF 'cp "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"' "$WIKI_INIT"; then
    check_pass "wiki-init.sh stages wiki-deploy.sh from \$REPO_ROOT"
else
    check_fail "wiki-init.sh missing 'cp \$REPO_ROOT/scripts/wiki/wiki-deploy.sh ...' line"
fi

# Stage block precedes the existing wiki-deploy.sh invocation: get line
# numbers and assert ordering.
stage_line="$( grep -nF 'cp "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"' "$WIKI_INIT" | head -1 | cut -d: -f1 )"
deploy_invoke_line="$( grep -nF 'bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"' "$WIKI_INIT" | head -1 | cut -d: -f1 )"
if [ -n "$stage_line" ] && [ -n "$deploy_invoke_line" ] && [ "$stage_line" -lt "$deploy_invoke_line" ]; then
    check_pass "staging block (line $stage_line) precedes wiki-deploy.sh invocation (line $deploy_invoke_line)"
else
    check_fail "ordering check: stage_line=$stage_line deploy_invoke_line=$deploy_invoke_line (expected stage < invoke)"
fi

# ---------- Behaviour layer ----------

# Build a tmp PROJECT_DIR fixture: empty wiki/, git init + origin remote,
# NO scripts/wiki/ subdir.
FIX="$WORKDIR/fixture"
mkdir -p "$FIX"

# git init + origin remote so wiki-init.sh's FR-5 owner/repo parser passes.
( cd "$FIX" && git init --quiet ) >/dev/null 2>&1
git_init_rc=$?
if [ "$git_init_rc" -ne 0 ]; then
    check_fail "fixture git init failed (rc=$git_init_rc)"
fi
( cd "$FIX" && git remote add origin git@github.com:Build-Fractal/m035-p00-fixture.git ) >/dev/null 2>&1
remote_rc=$?
if [ "$remote_rc" -ne 0 ]; then
    check_fail "fixture git remote add failed (rc=$remote_rc)"
fi

# Confirm scripts/wiki/wiki-deploy.sh is ABSENT in the fixture (precondition).
if [ ! -f "$FIX/scripts/wiki/wiki-deploy.sh" ]; then
    check_pass "fixture precondition: scripts/wiki/wiki-deploy.sh absent"
else
    check_fail "fixture precondition violated: scripts/wiki/wiki-deploy.sh already present"
fi

# Confirm $REPO_ROOT/scripts/wiki/wiki-deploy.sh exists (the source for staging).
if [ -f "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" ]; then
    check_pass "source present: \$REPO_ROOT/scripts/wiki/wiki-deploy.sh"
else
    check_fail "source missing: \$REPO_ROOT/scripts/wiki/wiki-deploy.sh — cannot stage"
fi

# Invoke wiki-init.sh --deploy with the gh-api stub.
RUN_LOG="$WORKDIR/wiki-init.log"
set +e
M032_DEPLOY_GH_API_STUB=1 \
    bash "$WIKI_INIT" --project-dir "$FIX" --deploy --force \
    > "$RUN_LOG" 2>&1
run_rc=$?
set -e

# Note: --deploy step 3 (Pages PUT) and beyond may fail under stub mode if
# the fixture's pages-get.json is absent (defaults to "404 / no Pages"
# which then triggers PUT — and step 4 will hit the gh CLI unless
# stubbed). Don't gate on overall rc; the only thing we care about is
# whether the staging block ran *before* step 2's invocation. Assert the
# post-condition (file present) directly.
if [ -f "$FIX/scripts/wiki/wiki-deploy.sh" ]; then
    check_pass "post-run: \$PROJECT_DIR/scripts/wiki/wiki-deploy.sh staged from \$REPO_ROOT"
else
    check_fail "post-run: \$PROJECT_DIR/scripts/wiki/wiki-deploy.sh NOT staged (rc=$run_rc, log=$RUN_LOG)"
fi

# Assert the staging diagnostic line was emitted.
if grep -q 'wiki-init: staged.*scripts/wiki/wiki-deploy.sh from' "$RUN_LOG"; then
    check_pass "staging diagnostic emitted to stderr"
else
    check_fail "staging diagnostic missing from log $RUN_LOG"
fi

# ---------- Verdict ----------

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'PASS: m035-p00-wiki-deploy-stage (M032 SC-5 fallback wired; tmp fixture stages wiki-deploy.sh from $REPO_ROOT) checks=%d\n' "$pass"
    exit 0
else
    printf 'FAIL: m035-p00-wiki-deploy-stage (pass=%d fail=%d)\n' "$pass" "$fail"
    printf '%b' "$failures" >&2
    exit 1
fi
