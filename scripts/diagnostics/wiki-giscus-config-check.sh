#!/usr/bin/env bash
# scripts/diagnostics/wiki-giscus-config-check.sh — M012/P03 loud-fail gate.
#
# Purpose: verify the four Giscus environment variables are set and
# non-empty before a wiki build runs. Fail loudly (non-zero exit + clear
# diagnostic on stderr) when any is missing so the deploy wrapper in
# M012/P04 can abort before mkdocs emits a silently-broken site.
#
# Contract:
#   - Reads $GISCUS_REPO, $GISCUS_REPO_ID, $GISCUS_CATEGORY,
#     $GISCUS_CATEGORY_ID from the environment.
#   - Exits 0 and emits `PASS: all 4 GISCUS_* env vars set` on success.
#   - Exits 1 and emits `FAIL: GISCUS_<NAME> unset or empty` for each
#     missing var on stderr, then a final `FAIL: <N>/4 required vars
#     missing` summary plus a `HINT:` line pointing at giscus.app.
#   - Supports `--help`/`-h` (usage on stdout, exit 0) and `--quiet`/`-q`
#     (silences PASS line; failure diagnostics still print on stderr).
#
# Upstream context:
#   T01 added an `extra.giscus` block to wiki/mkdocs.yml that reads four
#   env vars via MkDocs' `!ENV NAME,''` syntax, defaulting to the empty
#   string. An empty-string default silently produces a broken build.
#   This gate short-circuits that failure mode before `mkdocs build` runs.
#
# Constraints:
#   - Bash 3.2 compatible. No associative arrays, no mapfile, no
#     process substitution, no `&>`, no `${var^^}`.
#   - Read-only: no repo mutation, no tmp files, no network.
#   - Stdout carries PASS only; FAIL/HINT/ERROR go to stderr (MEM001).
#
# Exit codes: 0 = all set; 1 = any missing/empty; 2 = usage error.

set -u
set -o pipefail

usage() {
  cat <<'USAGE'
Usage: wiki-giscus-config-check.sh [--quiet|-q] [--help|-h]

Verifies the four Giscus env vars are set before a wiki build:
  GISCUS_REPO          e.g. "myorg/myrepo"
  GISCUS_REPO_ID       e.g. "R_kgDO..."  (from https://giscus.app)
  GISCUS_CATEGORY      e.g. "Announcements"
  GISCUS_CATEGORY_ID   e.g. "DIC_kwDO..."

Exits 0 iff all four are set and non-empty.
Exits 1 with a FAIL diagnostic per missing var otherwise.
Exits 2 on unknown argument.
USAGE
}

quiet=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --quiet|-q)
      quiet=1
      shift
      ;;
    *)
      printf 'ERROR: unknown arg: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

required="GISCUS_REPO GISCUS_REPO_ID GISCUS_CATEGORY GISCUS_CATEGORY_ID"
missing=0

for name in $required; do
  # Bash 3.2 indirect expansion: eval is the portable form across 3.2 quirks.
  # `${!name}` is Bash 4-only; avoid for compat (MEM001).
  eval "value=\${$name:-}"
  if [ -z "${value}" ]; then
    printf 'FAIL: %s unset or empty\n' "$name" >&2
    missing=$((missing + 1))
  fi
done

if [ "$missing" -gt 0 ]; then
  printf 'FAIL: %d/4 required Giscus env vars missing -- aborting before build\n' "$missing" >&2
  printf 'HINT: configure these from the https://giscus.app configurator, then export them before running mkdocs build or mkdocs gh-deploy\n' >&2
  exit 1
fi

if [ "$quiet" -eq 0 ]; then
  printf 'PASS: all 4 GISCUS_* env vars set\n'
fi
exit 0
