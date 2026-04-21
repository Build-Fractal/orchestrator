#!/usr/bin/env bash
# scripts/wiki/wiki-deploy.sh — M012/P04/T03 chained deploy wrapper.
#
# Runs the four pre-deploy gates in order:
#   1. scripts/diagnostics/wiki-giscus-config-check.sh   (env-var loud-fail)
#   2. mkdocs build -f wiki/mkdocs.yml                   (render to wiki/site/)
#   3. scripts/diagnostics/wiki-link-check.sh --site     (built-HTML walker)
#   4. scripts/diagnostics/wiki-giscus-smoke.sh --site   (Giscus presence)
# Then, on live path: mkdocs gh-deploy --force -f wiki/mkdocs.yml
# (pushes wiki/site/ to the gh-pages branch).
#
# Any non-zero exit from any gate aborts before gh-deploy runs.
# See wiki/README.md "Running the deploy wrapper" for the full
# contract + failure-triage table.
#
# Flags:
#   --dry-run       run gates, skip gh-deploy, exit 0 on all PASS
#   --help          print usage and exit 0
#   --root <dir>    override project root (default: invocation cwd)
#   --skip-smoke    skip gate (4) only (not recommended)
#
# Exit codes:
#   0 — all gates PASS and (live path) gh-deploy exit 0
#   1 — any gate FAIL, build fail, or gh-deploy fail
#   2 — usage error
#
# Bash 3.2 compliant. No declare -A. No process substitution.

set -u

# -------- usage / help --------
usage() {
  cat <<'USAGE'
Usage: bash scripts/wiki/wiki-deploy.sh [--dry-run] [--help] [--root DIR] [--skip-smoke]

Chains the four pre-deploy gates in order:
  1. scripts/diagnostics/wiki-giscus-config-check.sh
  2. mkdocs build -f wiki/mkdocs.yml
  3. scripts/diagnostics/wiki-link-check.sh --site wiki/site
  4. scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site

Then (live path only): mkdocs gh-deploy --force -f wiki/mkdocs.yml

Flags:
  --dry-run      Run gates, skip gh-deploy, exit 0 on all PASS.
  --help         Print this usage and exit 0.
  --root DIR     Override project root (default: invocation cwd).
  --skip-smoke   Skip gate (4) only. Not recommended for production.

See wiki/README.md "First-deploy checklist" and "Running the deploy
wrapper" sections for the full operator contract.
USAGE
}

# -------- flag parsing (Bash 3.2 safe; no while case across shifts > 1) --------
DRY_RUN=0
SKIP_SMOKE=0
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --skip-smoke)  SKIP_SMOKE=1 ;;
    --help|-h)     usage; exit 0 ;;
    --root)
      if [ $# -lt 2 ]; then
        printf 'ERROR: --root requires a directory argument\n' >&2
        exit 2
      fi
      ROOT="$2"
      shift
      ;;
    *)
      printf 'ERROR: unknown flag: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# -------- resolve root --------
if [ -z "$ROOT" ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
fi
if [ ! -d "$ROOT" ]; then
  printf 'ERROR: --root %s is not a directory\n' "$ROOT" >&2
  exit 2
fi

cd "$ROOT"

# -------- gate 1: giscus config-check --------
if bash scripts/diagnostics/wiki-giscus-config-check.sh --quiet; then
  printf 'GATE: giscus-config PASS\n'
else
  printf 'GATE: giscus-config FAIL\n'
  printf 'FAIL: giscus-config — one or more GISCUS_* env vars unset. See wiki/README.md "First-deploy checklist".\n' >&2
  exit 1
fi

# -------- gate 2: mkdocs build --------
if command -v mkdocs >/dev/null 2>&1; then
  if mkdocs build -f wiki/mkdocs.yml >/dev/null; then
    printf 'BUILD: ok\n'
  else
    printf 'BUILD: fail\n'
    printf 'FAIL: mkdocs build — see mkdocs output above.\n' >&2
    exit 1
  fi
else
  printf 'BUILD: skip (mkdocs not installed)\n'
  if [ "$DRY_RUN" -eq 0 ]; then
    printf 'FAIL: mkdocs not installed; cannot deploy.\n' >&2
    exit 1
  fi
fi

# -------- gate 3: link-check --------
if [ -d wiki/site ]; then
  if bash scripts/diagnostics/wiki-link-check.sh --site wiki/site; then
    printf 'GATE: link-check PASS\n'
  else
    printf 'GATE: link-check FAIL\n'
    printf 'FAIL: link-check — see BROKEN: lines above.\n' >&2
    exit 1
  fi
else
  printf 'GATE: link-check SKIP (no wiki/site/)\n'
fi

# -------- gate 4: giscus smoke --------
if [ "$SKIP_SMOKE" -eq 1 ]; then
  printf 'GATE: giscus-smoke SKIP (--skip-smoke)\n'
elif [ -d wiki/site ]; then
  if bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site; then
    printf 'GATE: giscus-smoke PASS\n'
  else
    printf 'GATE: giscus-smoke FAIL\n'
    printf 'FAIL: giscus-smoke — one or more pages missing the Giscus loader.\n' >&2
    exit 1
  fi
else
  printf 'GATE: giscus-smoke SKIP (no wiki/site/)\n'
fi

# -------- deploy (live path only) --------
if [ "$DRY_RUN" -eq 1 ]; then
  printf 'DRY-RUN: would deploy\n'
  exit 0
fi

printf 'DEPLOY: pushing to gh-pages\n'
if mkdocs gh-deploy --force -f wiki/mkdocs.yml; then
  printf 'OK: deployed to gh-pages\n'
  exit 0
else
  printf 'FAIL: mkdocs gh-deploy exited non-zero.\n' >&2
  exit 1
fi
