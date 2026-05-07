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

# -------- gate 0: FR-10 cwd-vs-repo_url sanity gate (Finding J counter-pattern) --------
# Compares repo_url: parsed from <ROOT>/wiki/mkdocs.yml against
# git -C $ROOT remote get-url origin. Normalizes both to canonical
# <owner>/<repo> form (case-lowered owner, case-preserved repo;
# strip .git suffix; strip https://github.com/ or git@github.com:
# prefixes). Exits non-zero with cross-project-hazard diagnostic on
# mismatch — protects against the silent cross-project force-push
# class of bug observed in the 2026-04-28 PBJ pilot session.
#
# Test-only override: M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 skips the gate.
# Used ONLY by tools/verify/m032-p03-* verifiers and by the SC-5/SC-6
# acceptance scripts when their fixture has no real GH remote. The
# operator-facing surface never honors this env-var unset path.
if [ "${M032_WIKI_DEPLOY_BYPASS_CWD_GATE:-0}" != "1" ]; then
  if [ ! -f "$ROOT/wiki/mkdocs.yml" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: %s/wiki/mkdocs.yml missing; cannot run cwd-vs-repo_url sanity gate\n' "$ROOT" >&2
    exit 1
  fi
  REPO_URL_LINE=$(grep -E '^repo_url:' "$ROOT/wiki/mkdocs.yml" | head -n 1)
  REPO_URL_VAL=$(printf '%s' "$REPO_URL_LINE" | sed -E 's/^repo_url:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
  if [ -z "$REPO_URL_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: cannot parse repo_url: from %s/wiki/mkdocs.yml\n' "$ROOT" >&2
    exit 1
  fi
  GIT_REMOTE_VAL=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)
  if [ -z "$GIT_REMOTE_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: no git remote at origin in %s\n' "$ROOT" >&2
    exit 1
  fi
  # Normalize both to <owner>/<repo> form. Strip .git, strip protocol/host prefixes.
  norm_repo() {
    printf '%s' "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##; s#/$##'
  }
  REPO_URL_NORM=$(norm_repo "$REPO_URL_VAL")
  GIT_REMOTE_NORM=$(norm_repo "$GIT_REMOTE_VAL")
  # Owner-lower-case, repo-case-preserved (matches wiki-init.sh's P02 convention).
  REPO_URL_OWNER=$(printf '%s' "$REPO_URL_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  GIT_REMOTE_OWNER=$(printf '%s' "$GIT_REMOTE_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  if [ "$REPO_URL_OWNER" != "$GIT_REMOTE_OWNER" ]; then
    printf 'FAIL: wiki-deploy: cross-project hazard — mkdocs.yml repo_url=%s does not match git remote origin=%s; aborting before gh-deploy. cwd: %s\n' "$REPO_URL_VAL" "$GIT_REMOTE_VAL" "$ROOT" >&2
    exit 1
  fi
  printf 'GATE: cwd-vs-repo_url PASS (%s)\n' "$REPO_URL_OWNER"
fi

# -------- pre-gate: source <root>/.env if present --------
# Layer 1 of the operator-secrets-and-adaptive-init pre-launch slice
# (.orchestrator/proposals/papercut-wiki-deploy-env-loader.md). Closes
# the fetch-vs-deploy persistence gap: wiki-init.sh --with-giscus
# writes the four GISCUS_* values to <root>/.env under a managed
# marker block; this loader makes them visible to gate 1 without
# requiring the operator to source the file in their deploy shell.
# Operators who already export in shell (or CI environments that
# inject vars from the runner) are unaffected — this only ADDS
# values; it does not override anything.
if [ -f "$ROOT/.env" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set -u
fi

# -------- gate 1: giscus config-check --------
if bash scripts/diagnostics/wiki-giscus-config-check.sh --quiet; then
  printf 'GATE: giscus-config PASS\n'
else
  printf 'GATE: giscus-config FAIL\n'
  printf 'FAIL: giscus-config — one or more GISCUS_* env vars unset.\n' >&2
  printf 'HINT: run `bash scripts/lifecycle/wiki-init.sh --project-dir %s --with-giscus --repo <owner>/<repo> --category "Wiki Comments"` to fetch the four IDs and persist them to %s/.env, then re-run deploy.\n' "$ROOT" "$ROOT" >&2
  printf 'HINT: or fetch IDs directly via `bash scripts/diagnostics/giscus-ids-from-gh.sh --repo <owner>/<repo> --category "Wiki Comments"` and paste the four export lines into %s/.env (gitignored).\n' "$ROOT" >&2
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
