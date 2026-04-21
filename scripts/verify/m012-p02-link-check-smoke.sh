#!/usr/bin/env bash
# scripts/verify/m012-p02-link-check-smoke.sh — M012/P02 gate 7.
#
# End-to-end smoke against a real mkdocs build. When mkdocs is available:
#   - builds the wiki into a throwaway site directory
#   - runs wiki-link-check.sh --site <probe>
#   - asserts exit 0 and a "PASS: 0 broken" summary line
#
# When mkdocs is absent, emits SKIP: and exits 0 (Tier 1 acceptable;
# Tier 4 UAT covers the live build).
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"

if ! command -v mkdocs >/dev/null 2>&1; then
  printf 'SKIP: mkdocs not installed — link-check smoke deferred to Tier 4 UAT\n'
  exit 0
fi

probe="/tmp/m012-p02-linksmoke.$$"
mkdir -p "$probe"
trap 'rm -rf "$probe"' EXIT INT TERM

build_log="/tmp/m012-p02-linksmoke-build.$$"
(cd "$ROOT/wiki" && mkdocs build --site-dir "$probe" --quiet) > "$build_log" 2>&1
build_rc=$?

if [ "$build_rc" != "0" ]; then
  printf 'FAIL: mkdocs build failed (rc=%s)\n' "$build_rc"
  sed 's/^/  /' "$build_log"
  rm -f "$build_log"
  exit 1
fi
rm -f "$build_log"

out=$(bash "$ROOT/scripts/diagnostics/wiki-link-check.sh" --site "$probe" 2>&1)
rc=$?

if [ "$rc" != "0" ]; then
  printf 'FAIL: link-check against real build exit %s\n%s\n' "$rc" "$out"
  exit 1
fi

if ! echo "$out" | grep -qE '^PASS: 0 broken'; then
  printf 'FAIL: link-check stdout missing "PASS: 0 broken" summary\n%s\n' "$out"
  exit 1
fi

printf 'PASS: real-build link-check clean\n'
exit 0
