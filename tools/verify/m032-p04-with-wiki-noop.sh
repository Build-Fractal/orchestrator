#!/usr/bin/env bash
# tools/verify/m032-p04-with-wiki-noop.sh
# M032/P04/T02 — --with-wiki no-op in-flight repair verifier.
#
# Asserts:
#   1. scripts/lifecycle/wiki-init.sh contains the `--with-wiki) shift`
#      no-op case arm (with the FR-11 passthrough symmetry comment block).
#   2. Running wiki-init.sh with --with-wiki does NOT exit 2 with
#      "unknown argument" diagnostic. Uses M032_WIKI_INIT_FORCE_EXIT=99
#      to short-circuit AFTER argument-parse but BEFORE any heavy
#      python3 / git-remote / mkdocs work — exercising only the argument-
#      parse path.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$WI" ]; then
  say_fail "$WI absent"
  printf 'SUMMARY: m032-p04-with-wiki-noop.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Static-text checks for the new case arm + comment block.
if grep -qF -- '--with-wiki) shift' "$WI"; then
  say_pass "wiki-init.sh contains --with-wiki) shift no-op case arm"
else
  say_fail "wiki-init.sh missing --with-wiki) shift case arm"
fi

for tok in 'M032/P04/T02' 'FR-11 passthrough' 'P03/T04 SC-5'; do
  if grep -qF -- "$tok" "$WI"; then
    say_pass "wiki-init.sh comment block cites: $tok"
  else
    say_fail "wiki-init.sh comment block missing: $tok"
  fi
done

# Behavioral check: --with-wiki passes argument-parse step without
# triggering the "unknown argument" diagnostic.
# M032_WIKI_INIT_FORCE_EXIT=99 short-circuits after parse + after the
# python3/pip3 probe (line 91-94 forces exit before FR-5 git-remote work).
TMPDIR_F=$(mktemp -d -t m032-p04-with-wiki-noop.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT INT TERM
mkdir -p "$TMPDIR_F"
# Initialize git remote so FR-5 wouldn't immediately bail (defensive — the
# FORCE_EXIT path triggers before FR-5 anyway).
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p04-noop.git) >/dev/null 2>&1

set +e
STDERR_FILE="$TMPDIR_F/stderr.txt"
M032_WIKI_INIT_FORCE_EXIT=99 bash "$WI" --with-wiki --project-dir "$TMPDIR_F" >/dev/null 2>"$STDERR_FILE"
rc=$?
set -e

# Expected: rc=99 (FORCE_EXIT path); stderr does NOT contain
# "unknown argument '--with-wiki'".
if [ "$rc" -eq 99 ]; then
  say_pass "wiki-init.sh --with-wiki: parse path reached (rc=99 from FORCE_EXIT)"
else
  say_fail "wiki-init.sh --with-wiki: expected rc=99 from FORCE_EXIT, got rc=$rc"
fi

if grep -qF "unknown argument '--with-wiki'" "$STDERR_FILE"; then
  say_fail "wiki-init.sh --with-wiki: rejected as unknown argument (regression)"
else
  say_pass "wiki-init.sh --with-wiki: not rejected as unknown argument"
fi

# Bonus: confirm the no-op preserves all other case arms (composability check).
# Run --with-wiki + --with-giscus together; both should be consumed.
set +e
STDERR2="$TMPDIR_F/stderr2.txt"
M032_WIKI_INIT_FORCE_EXIT=99 bash "$WI" --with-wiki --with-giscus --project-dir "$TMPDIR_F" >/dev/null 2>"$STDERR2"
rc2=$?
set -e
if [ "$rc2" -eq 99 ] && ! grep -qF "unknown argument" "$STDERR2"; then
  say_pass "wiki-init.sh composability: --with-wiki + --with-giscus both consumed"
else
  say_fail "wiki-init.sh composability: rc=$rc2 or 'unknown argument' present"
fi

# Decision-id token surface.
for tok in 'FR-11' 'M032/P04/T02'; do
  if grep -qF -- "$tok" "$WI"; then
    say_pass "wiki-init.sh references decision id: $tok"
  else
    say_fail "wiki-init.sh missing decision id: $tok"
  fi
done

printf 'SUMMARY: m032-p04-with-wiki-noop.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
