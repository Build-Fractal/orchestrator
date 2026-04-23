#!/usr/bin/env bash
# scripts/diagnostics/wiki-giscus-smoke.sh — M012/P03 SC-2 smoke test.
#
# Walks every *.html under --site <dir> (default wiki/site) and asserts
# each page contains `src="https://giscus.app/client.js"`. Emits one
# FAIL: <path> line per offending page plus a PASS/FAIL summary. Bash 3.2.
#
# Contract:
#   --site <dir>      path to the built site (default wiki/site)
#   --root <dir>      project root (default invocation cwd)
#   --verbose         emit one OK: <path> per passing page
#   --help            print usage; exit 0
#
# Exit codes:
#   0  every page carries the Giscus loader tag
#   1  one or more pages missing the tag
#   2  usage error / empty site / site directory missing
#
# Companion: scripts/diagnostics/wiki-giscus-config-check.sh (pre-build).
#   — the config-check gates env-var presence BEFORE the build; this
#     script gates the rendered output AFTER the build. P04 chains both
#     around `mkdocs gh-deploy`.
#
# AD-3 SSOT: reads only rendered HTML under the built-site directory.
# Never reads .orchestrator/**.md (those are scanner inputs, not outputs).

set -u
set -o pipefail

PROJECT_ROOT="${PWD}"
SITE_DIR=""
verbose=0

usage() {
  cat <<'USAGE'
Usage: wiki-giscus-smoke.sh [--site <dir>] [--root <dir>] [--verbose] [--help]

Walks every *.html under <site> (default wiki/site) and confirms each
page carries the Giscus loader tag. Intended to run AFTER mkdocs build.

Exit codes:
  0  every page carries the Giscus loader tag
  1  one or more pages missing the tag
  2  usage error / empty site / site directory missing
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --site)
      if [ $# -lt 2 ]; then
        printf 'ERROR: --site requires a value\n' >&2
        exit 2
      fi
      SITE_DIR="$2"
      shift 2
      ;;
    --root)
      if [ $# -lt 2 ]; then
        printf 'ERROR: --root requires a value\n' >&2
        exit 2
      fi
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --verbose)
      verbose=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown arg: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$SITE_DIR" ]; then
  SITE_DIR="$PROJECT_ROOT/wiki/site"
fi

if [ ! -d "$SITE_DIR" ]; then
  printf 'ERROR: site directory not found: %s\n' "$SITE_DIR" >&2
  printf 'HINT: run (cd wiki && mkdocs build) first, or pass --site <dir>\n' >&2
  exit 2
fi

# Collect pages into a /tmp list file — avoids $() with pipe and
# avoids |-while (subshell counter loss on some bashes). Bash 3.2 safe.
list_file="$(mktemp -t wiki-giscus-smoke.XXXXXX)"
# shellcheck disable=SC2064
trap "rm -f '$list_file'" EXIT

# Exclude mkdocs auto-generated 404.html (no comments surface expected on
# an error page — the Material theme's 404 template does not include the
# comments partial by design).
find "$SITE_DIR" -type f -name '*.html' ! -name '404.html' -print > "$list_file"

total=0
missing=0
needle='src="https://giscus.app/client.js"'

while IFS= read -r page; do
  total=$((total + 1))
  if grep -qF "$needle" "$page"; then
    if [ "$verbose" -eq 1 ]; then
      printf 'OK: %s\n' "$page"
    fi
  else
    printf 'FAIL: %s\n' "$page" >&2
    missing=$((missing + 1))
  fi
done < "$list_file"

if [ "$total" -eq 0 ]; then
  printf 'ERROR: no .html files under %s\n' "$SITE_DIR" >&2
  printf 'HINT: run (cd wiki && mkdocs build) to populate the site directory\n' >&2
  exit 2
fi

if [ "$missing" -gt 0 ]; then
  printf 'SUMMARY: %d/%d pages missing Giscus loader\n' "$missing" "$total" >&2
  printf 'FAIL: Giscus smoke — %d missing of %d pages (site=%s)\n' "$missing" "$total" "$SITE_DIR" >&2
  exit 1
fi

printf 'PASS: %d pages have Giscus (site=%s)\n' "$total" "$SITE_DIR"
exit 0
