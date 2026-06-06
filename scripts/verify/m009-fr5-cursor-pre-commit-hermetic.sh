#!/usr/bin/env bash
# scripts/verify/m009-fr5-cursor-pre-commit-hermetic.sh
#
# Hermetic verifier for M009 FR-5 — the git pre-commit wiring of the
# orchestrator before-commit lifecycle gate under the Cursor install path.
# Exercises scripts/lifecycle/install-git-pre-commit.sh directly (the unit)
# plus the install-cursor.sh integration. All writes go to mktemp fixtures;
# real HOME / git config are never touched.
#
# Contract under test:
#   1. Non-git project        → benign skip, exit 0, no hook, reason=not-a-git-repo.
#   2. Git repo, no pre-commit → managed hook written, executable, carries marker.
#   3. Re-run (idempotent)     → still exactly one managed hook.
#   4. Operator-owned hook     → preserved byte-identical (clobber-guard), wired=0.
#   5. --dry-run               → no write, would_write= emitted.
#   6. --uninstall             → removes OUR hook; preserves operator hook.
#   7. Generated hook fails OPEN (missing gate → exit 0) and is a no-op today.
#   8. core.hooksPath honored.
#   9. install-cursor.sh integration emits pre_commit_wired= in SUMMARY.
#
# This suite shells out to `git` and writes temp trees → run in a
# sandbox-disabled shell.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WIRE="$REPO_ROOT/scripts/lifecycle/install-git-pre-commit.sh"
INSTALLER="$REPO_ROOT/packaging/install/install-cursor.sh"
MARKER='ORCHESTRATOR_MANAGED_PRE_COMMIT'

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*" >&2; }

if [ ! -f "$WIRE" ]; then
  echo "FAIL: wiring script not found at $WIRE" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Hermetic git identity so `git init`/commit never reads the developer's config.
export GIT_CONFIG_GLOBAL="$WORK/gitconfig-global"
export GIT_CONFIG_SYSTEM="$WORK/gitconfig-system"
: > "$GIT_CONFIG_GLOBAL"
: > "$GIT_CONFIG_SYSTEM"
export GIT_AUTHOR_NAME="t"
export GIT_AUTHOR_EMAIL="t@t"
export GIT_COMMITTER_NAME="t"
export GIT_COMMITTER_EMAIL="t@t"

# A stub before-commit.sh under each project's staged scripts/ tree. We stage a
# no-op (mirrors the real one) so the generated hook's gate path resolves.
stage_gate() {
  _proj="$1"
  mkdir -p "$_proj/scripts/lifecycle"
  printf '%s\n%s\n' '#!/usr/bin/env bash' 'exit 0' > "$_proj/scripts/lifecycle/before-commit.sh"
  chmod +x "$_proj/scripts/lifecycle/before-commit.sh"
}

# ---------------------------------------------------------------------------
# 1. Non-git project → benign skip.
# ---------------------------------------------------------------------------
P1="$WORK/nongit"
mkdir -p "$P1"
out="$(bash "$WIRE" --project-dir "$P1" 2>&1)"
rc=$?
if [ $rc -eq 0 ] && printf '%s\n' "$out" | grep -q 'reason=not-a-git-repo'; then
  pass "non-git project skips with exit 0 + reason=not-a-git-repo"
else
  fail "non-git project: expected exit 0 + not-a-git-repo (rc=$rc out=$out)"
fi

# ---------------------------------------------------------------------------
# 2. Git repo, no existing pre-commit → managed hook written + executable.
# ---------------------------------------------------------------------------
P2="$WORK/clean"
mkdir -p "$P2"
( cd "$P2" && git init -q )
stage_gate "$P2"
out="$(bash "$WIRE" --project-dir "$P2" 2>&1)"
rc=$?
hook="$P2/.git/hooks/pre-commit"
if [ $rc -eq 0 ] && [ -f "$hook" ] && printf '%s\n' "$out" | grep -q 'pre_commit_wired=1'; then
  pass "clean git repo: managed pre-commit written + pre_commit_wired=1"
else
  fail "clean git repo: expected hook + pre_commit_wired=1 (rc=$rc out=$out)"
fi
if [ -x "$hook" ]; then
  pass "generated pre-commit hook is executable"
else
  fail "generated pre-commit hook is not executable"
fi
if grep -q "$MARKER" "$hook" 2>/dev/null; then
  pass "generated hook carries the $MARKER marker"
else
  fail "generated hook missing the $MARKER marker"
fi

# ---------------------------------------------------------------------------
# 3. Idempotent re-run → still exactly one managed hook.
# ---------------------------------------------------------------------------
bash "$WIRE" --project-dir "$P2" >/dev/null 2>&1
rc=$?
marker_count="$(grep -c "$MARKER" "$hook" 2>/dev/null | tr -d ' ')"
if [ $rc -eq 0 ] && [ "$marker_count" = "1" ]; then
  pass "re-run is idempotent (single marker, exit 0)"
else
  fail "re-run not idempotent (rc=$rc marker_count=$marker_count)"
fi

# ---------------------------------------------------------------------------
# 4. Operator-owned pre-commit → preserved byte-identical (clobber-guard).
# ---------------------------------------------------------------------------
P4="$WORK/operator"
mkdir -p "$P4"
( cd "$P4" && git init -q )
stage_gate "$P4"
op_hook="$P4/.git/hooks/pre-commit"
printf '%s\n%s\n' '#!/bin/sh' 'echo operator hook; exit 0' > "$op_hook"
chmod +x "$op_hook"
op_before="$(cat "$op_hook")"
out="$(bash "$WIRE" --project-dir "$P4" 2>&1)"
rc=$?
op_after="$(cat "$op_hook")"
if [ $rc -eq 0 ] && [ "$op_before" = "$op_after" ] && printf '%s\n' "$out" | grep -q 'reason=operator-owned'; then
  pass "operator-owned hook preserved byte-identical (clobber-guard, wired=0)"
else
  fail "operator-owned hook clobber-guard failed (rc=$rc out=$out)"
fi

# ---------------------------------------------------------------------------
# 5. --dry-run → no write, would_write= emitted.
# ---------------------------------------------------------------------------
P5="$WORK/dryrun"
mkdir -p "$P5"
( cd "$P5" && git init -q )
stage_gate "$P5"
out="$(bash "$WIRE" --project-dir "$P5" --dry-run 2>&1)"
rc=$?
if [ $rc -eq 0 ] && printf '%s\n' "$out" | grep -q '^would_write=' && [ ! -f "$P5/.git/hooks/pre-commit" ]; then
  pass "--dry-run emits would_write= and writes nothing"
else
  fail "--dry-run misbehaved (rc=$rc out=$out, hook-exists=$([ -f "$P5/.git/hooks/pre-commit" ] && echo yes || echo no))"
fi

# ---------------------------------------------------------------------------
# 6. --uninstall → removes OUR hook; preserves an operator hook.
# ---------------------------------------------------------------------------
# 6a: remove our managed hook (reuse P2 which has one).
out="$(bash "$WIRE" --project-dir "$P2" --uninstall 2>&1)"
rc=$?
if [ $rc -eq 0 ] && [ ! -f "$hook" ] && printf '%s\n' "$out" | grep -q '^removed='; then
  pass "--uninstall removes the managed hook"
else
  fail "--uninstall did not remove managed hook (rc=$rc out=$out)"
fi
# 6b: uninstall must NOT remove an operator-owned hook (reuse P4).
out="$(bash "$WIRE" --project-dir "$P4" --uninstall 2>&1)"
rc=$?
if [ $rc -eq 0 ] && [ -f "$op_hook" ] && printf '%s\n' "$out" | grep -q 'reason=operator-owned'; then
  pass "--uninstall preserves an operator-owned hook"
else
  fail "--uninstall clobbered an operator-owned hook (rc=$rc out=$out)"
fi

# ---------------------------------------------------------------------------
# 7. Generated hook fails OPEN (missing gate → exit 0) AND is a no-op today.
# ---------------------------------------------------------------------------
P7="$WORK/failopen"
mkdir -p "$P7"
( cd "$P7" && git init -q )
stage_gate "$P7"
bash "$WIRE" --project-dir "$P7" >/dev/null 2>&1
h7="$P7/.git/hooks/pre-commit"
# 7a: with the gate present (no-op exit 0), the hook exits 0.
bash "$h7" </dev/null >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "generated hook is a no-op (exit 0) with the stub gate present"
else
  fail "generated hook returned non-zero with a no-op gate"
fi
# 7b: remove the gate → hook must still exit 0 (fail OPEN).
rm -f "$P7/scripts/lifecycle/before-commit.sh"
bash "$h7" </dev/null >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "generated hook fails OPEN (exit 0) when the gate is missing"
else
  fail "generated hook did NOT fail open when the gate was missing"
fi
# 7c: a real `git commit` through the hook succeeds (end-to-end, gate restored).
stage_gate "$P7"
( cd "$P7" && git add -A && git commit -q -m "test" ) >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "real git commit succeeds through the managed pre-commit hook"
else
  fail "real git commit was blocked by the managed pre-commit hook"
fi

# ---------------------------------------------------------------------------
# 8. core.hooksPath is honored.
# ---------------------------------------------------------------------------
P8="$WORK/hookspath"
mkdir -p "$P8"
( cd "$P8" && git init -q && git config core.hooksPath custom-hooks )
stage_gate "$P8"
bash "$WIRE" --project-dir "$P8" >/dev/null 2>&1
if [ -f "$P8/custom-hooks/pre-commit" ]; then
  pass "core.hooksPath honored (hook landed in custom-hooks/)"
else
  fail "core.hooksPath ignored (hook not in custom-hooks/)"
fi

# ---------------------------------------------------------------------------
# 9. install-cursor.sh integration emits pre_commit_wired= in SUMMARY.
# ---------------------------------------------------------------------------
if [ -f "$INSTALLER" ]; then
  P9="$WORK/integration"
  mkdir -p "$P9/.cursor"
  ( cd "$P9" && git init -q )
  FH="$WORK/inthome"
  mkdir -p "$FH"
  out="$(HOME="$FH" bash "$INSTALLER" --project-dir "$P9" 2>&1)"
  rc=$?
  if [ $rc -eq 0 ] && printf '%s\n' "$out" | grep -q 'SUMMARY:.*pre_commit_wired=1'; then
    pass "install-cursor.sh wires pre-commit + reports pre_commit_wired=1 in SUMMARY"
  else
    fail "install-cursor.sh integration failed (rc=$rc); SUMMARY=$(printf '%s\n' "$out" | grep '^SUMMARY:')"
  fi
  if [ -f "$P9/.git/hooks/pre-commit" ] && grep -q "$MARKER" "$P9/.git/hooks/pre-commit" 2>/dev/null; then
    pass "install-cursor.sh actually wrote the managed pre-commit hook"
  else
    fail "install-cursor.sh did not write the managed pre-commit hook"
  fi
else
  echo "note: install-cursor.sh not found; skipping integration assertions" >&2
fi

echo "BATTERY: pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
