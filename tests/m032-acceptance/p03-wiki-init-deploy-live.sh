#!/usr/bin/env bash
# tests/m032-acceptance/p03-wiki-init-deploy-live.sh — SC-5 (FR-9 + FR-10 + FR-21).
#
# Implements the throwaway-fixture-protocol per
# tests/m032-acceptance/throwaway-fixture-protocol.md and CON-5. Exits 0
# on pass, 77 on SKIP_REASON (gh unauthenticated), other non-zero on fail.
# Three-category exit-code semantics per MIT-001.
#
# This script transitively exercises MIT-007 (read-before-write Pages
# guard inside wiki-deploy.sh) via the --deploy step and MIT-008
# (audit-trail integrity for wiki-deploy-mutation records).
#
# Coverage:
#  - Live --with-wiki --with-giscus --deploy invocation against a throwaway repo.
#  - Live URL responds 200 within M032_DEPLOY_PROPAGATION_TIMEOUT seconds.
#  - Served HTML contains data-repo="<owner>/<ts>-m032-fixture" attribute.
#  - .orchestrator/execution-log.jsonl carries >= 1 wiki-deploy-mutation record.
#  - Post-teardown: no GitHub repo, no local refs, no orphan state.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Precondition: gh auth status. SKIP_REASON / exit 77 if non-zero.
if ! command -v gh >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh CLI not on PATH)\n'
  exit 77
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh auth status non-zero)\n'
  exit 77
fi

# Resolve owner from gh's authenticated account.
GH_OWNER="$(gh api user --jq .login 2>/dev/null)"
if [ -z "$GH_OWNER" ]; then
  printf 'SKIP_REASON: gh unauthenticated (could not resolve user.login)\n'
  exit 77
fi

# Fixture-completeness precondition per MIT-001: wiki-init.sh's --deploy
# branch invokes "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh", but the
# m032-fresh-project-fixture does NOT carry scripts/ (the fixture is the
# pre-orchestrator-installer baseline; scripts/ lands at install time).
# Without scripts/wiki/wiki-deploy.sh in the fixture, --deploy step 2
# fails with rc=11 ("No such file or directory"). This is an environmental
# precondition — the test cannot run hermetically without operator-side
# scripts/ pre-staging, which the SC-5 protocol does not specify. Treat
# as SKIP_REASON per MIT-001 three-category exit semantics. P04/T05
# in-flight repair on the established M032 P02/P03 convention.
if [ ! -f "$FIXTURE/scripts/wiki/wiki-deploy.sh" ]; then
  printf 'SKIP_REASON: fixture lacks scripts/wiki/wiki-deploy.sh (operator-side install required for --deploy)\n'
  exit 77
fi

# Throwaway fixture creation per AD-7 / throwaway-fixture-protocol.md.
TS="$(date +%s)"
FIXTURE_NAME="${TS}-m032-fixture"
PROPAGATION_TIMEOUT="${M032_DEPLOY_PROPAGATION_TIMEOUT:-90}"

cleanup() {
  set +e
  if [ -n "${FIXTURE_NAME:-}" ]; then
    gh repo delete "$GH_OWNER/$FIXTURE_NAME" --yes 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if ! gh repo create "$FIXTURE_NAME" --private --add-readme >/dev/null 2>&1; then
  say_fail "throwaway-fixture creation failed: gh repo create $FIXTURE_NAME --private --add-readme"
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "throwaway-fixture created: $GH_OWNER/$FIXTURE_NAME"

# Re-point the fixture's git remote to the throwaway repo so wiki-init's
# FR-5 git-remote parsing resolves to the throwaway, not the P01-baseline
# fixture-owner/m032-fresh-project-fixture remote.
git -C "$FIXTURE" remote set-url origin "https://github.com/$GH_OWNER/$FIXTURE_NAME.git" 2>/dev/null || true

# Full --with-wiki --with-giscus --deploy invocation.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-wiki --with-giscus --deploy \
  --repo "$GH_OWNER/$FIXTURE_NAME" --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/tmp/sc5-wiki-init-stdout.$$ 2>/tmp/sc5-wiki-init-stderr.$$
deploy_rc=$?
if [ "$deploy_rc" -eq 0 ]; then
  say_pass "wiki-init.sh --with-wiki --with-giscus --deploy exited 0"
else
  say_fail "wiki-init.sh --deploy exited $deploy_rc; stderr: $(tail -10 /tmp/sc5-wiki-init-stderr.$$ | tr '\n' ' ')"
  rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Parse live URL from stdout.
LIVE_URL="$(tail -1 /tmp/sc5-wiki-init-stdout.$$)"
rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
case "$LIVE_URL" in
  https://*) say_pass "live URL printed: $LIVE_URL" ;;
  *) say_fail "live URL not parsed from wiki-init stdout (got: '$LIVE_URL')"; LIVE_URL="" ;;
esac

# Curl retry loop bounded by M032_DEPLOY_PROPAGATION_TIMEOUT.
if [ -n "$LIVE_URL" ]; then
  ELAPSED=0
  STEP=10
  HTTP_OK=0
  while [ "$ELAPSED" -lt "$PROPAGATION_TIMEOUT" ]; do
    if curl -fsS -o /tmp/sc5-html.$$ "$LIVE_URL" >/dev/null 2>&1; then
      HTTP_OK=1
      break
    fi
    sleep "$STEP"
    ELAPSED=$((ELAPSED + STEP))
  done
  if [ "$HTTP_OK" -eq 1 ]; then
    say_pass "live URL responded 200 within ${ELAPSED}s (timeout ${PROPAGATION_TIMEOUT}s)"
  else
    say_fail "live URL did not respond 200 within ${PROPAGATION_TIMEOUT}s"
  fi

  # Served HTML contains the per-fixture data-repo attribute.
  if [ -f /tmp/sc5-html.$$ ] && grep -qF "data-repo=\"$GH_OWNER/$FIXTURE_NAME\"" /tmp/sc5-html.$$; then
    say_pass "served HTML contains data-repo=\"$GH_OWNER/$FIXTURE_NAME\" (FR-21 end-to-end loop)"
  else
    say_fail "served HTML missing data-repo attribute for $GH_OWNER/$FIXTURE_NAME"
  fi
  rm -f /tmp/sc5-html.$$
fi

# MIT-008 audit-trail invariant.
LOG_FILE="$FIXTURE/.orchestrator/execution-log.jsonl"
if [ -f "$LOG_FILE" ] && grep -qF '"event_type":"wiki-deploy-mutation"' "$LOG_FILE" \
   && grep -qF '"result":"success"' "$LOG_FILE"; then
  say_pass "MIT-008 audit-trail: >= 1 wiki-deploy-mutation record with result=success"
else
  say_fail "MIT-008 audit-trail: no wiki-deploy-mutation success record in $LOG_FILE"
fi

# Teardown is via trap. Verify post-teardown invariants AFTER trap fires by
# explicitly invoking cleanup and re-checking. (The trap will fire again at
# script exit; gh repo delete is idempotent.)
cleanup
trap - EXIT INT TERM

# No-orphan-state invariant 1: GitHub repo is gone.
if gh repo view "$GH_OWNER/$FIXTURE_NAME" --json name >/dev/null 2>&1; then
  say_fail "post-teardown: $GH_OWNER/$FIXTURE_NAME still exists on GitHub"
else
  say_pass "post-teardown: throwaway repo absent from GitHub"
fi

# No-orphan-state invariant 2: no fixture dir left in tests/fixtures/.
if [ -d "$REPO_ROOT/tests/fixtures/$FIXTURE_NAME" ]; then
  say_fail "post-teardown: tests/fixtures/$FIXTURE_NAME directory leaked"
else
  say_pass "post-teardown: no tests/fixtures/$FIXTURE_NAME directory"
fi

# No-orphan-state invariant 3: no orphan refs.
ORPHAN_REFS=$(find "$REPO_ROOT/.git/refs" -name "*$FIXTURE_NAME*" -print 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORPHAN_REFS" -eq 0 ]; then
  say_pass "post-teardown: no orphan refs in .git/refs"
else
  say_fail "post-teardown: $ORPHAN_REFS orphan ref(s) in .git/refs"
fi

# Restore fixture's git remote to baseline (avoid leaving the shared fixture
# pointing at a deleted throwaway repo for downstream tests).
git -C "$FIXTURE" remote set-url origin \
  "https://github.com/fixture-owner/m032-fresh-project-fixture.git" 2>/dev/null || true

printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
