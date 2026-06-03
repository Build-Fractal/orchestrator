#!/usr/bin/env bash
# tools/verify/m035-p02-install-staging-flow.sh
#
# Regression guard for the v0.9.5 package-install fixes:
#   1. Base project-install staging SKIPS the wiki/ project_asset — wiki is
#      opt-in via wiki-init.sh and is intentionally absent from the
#      distributed tarball (m035-p02-npm-pack-contents.sh asserts check_absent
#      "wiki"), so staging it would fail on every package-manager install.
#   2. install-claude-code.sh --skip-project-assets registers skills but
#      stages ZERO project files (runtime_staged=0) — used by the npm
#      postinstall for global installs.
#   3. The npm postinstall short-circuits global installs (npm_config_global)
#      to a register-only delegate instead of staging into the cwd.
#
# All assertions run against --dry-run / DRY_RUN=1 so nothing is written.
# HOME is redirected to a throwaway dir so the dry-run skill-register probe
# never touches the real ~/.claude. Bash 3.2 safe; deterministic; no network.
set -uo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALLER="$REPO/packaging/install/install-claude-code.sh"
POSTINSTALL="$REPO/packaging/npm/postinstall.sh"

pass=0
fail=0

TMPROOT="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02flow)"
trap 'rm -rf "$TMPROOT" 2>/dev/null || true' EXIT
PROJ="$TMPROOT/proj"
FAKEHOME="$TMPROOT/home"
mkdir -p "$PROJ/.orchestrator" "$FAKEHOME/.claude"

# --- 1. Base project-install staging skips wiki content, stages core ----
INIT_LOG="$TMPROOT/init.log"
HOME="$FAKEHOME" bash "$INSTALLER" --dry-run --project-dir "$PROJ" >"$INIT_LOG" 2>&1
wiki_lines="$(grep -c "would_write=$PROJ/wiki/" "$INIT_LOG" 2>/dev/null || true)"
core_lines="$(grep -cE "would_write=$PROJ/(commands|scripts|references|templates)/" "$INIT_LOG" 2>/dev/null || true)"
if [ "${wiki_lines:-0}" = "0" ]; then
  echo "PASS: base install stages no wiki/ content into the project"
  pass=$((pass + 1))
else
  echo "FAIL: base install staged $wiki_lines wiki/ files (expected 0)"
  fail=$((fail + 1))
fi
if [ "${core_lines:-0}" -gt 0 ]; then
  echo "PASS: base install still stages core assets (commands/scripts/...) [$core_lines files]"
  pass=$((pass + 1))
else
  echo "FAIL: base install staged no core assets (expected >0)"
  fail=$((fail + 1))
fi

# --- 2. --skip-project-assets stages nothing -----------------------------
SKIP_LOG="$TMPROOT/skip.log"
HOME="$FAKEHOME" bash "$INSTALLER" --skip-project-assets --dry-run --project-dir "$PROJ" >"$SKIP_LOG" 2>&1
if grep -q 'skipped=project-asset staging' "$SKIP_LOG" \
   && grep -q 'runtime_staged=0' "$SKIP_LOG"; then
  echo "PASS: --skip-project-assets emits skip notice + runtime_staged=0"
  pass=$((pass + 1))
else
  echo "FAIL: --skip-project-assets did not skip staging cleanly"
  fail=$((fail + 1))
fi

# --- 3. npm postinstall short-circuits global installs -------------------
GLOBAL_LOG="$TMPROOT/global.log"
HOME="$FAKEHOME" npm_config_global=true INIT_CWD="$PROJ" DRY_RUN=1 \
  bash "$POSTINSTALL" >"$GLOBAL_LOG" 2>&1
if grep -q 'global_install=true' "$GLOBAL_LOG" \
   && grep -q -- '--skip-project-assets' "$GLOBAL_LOG"; then
  echo "PASS: global npm postinstall routes to --skip-project-assets (no cwd staging)"
  pass=$((pass + 1))
else
  echo "FAIL: global npm postinstall did not short-circuit to register-only"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
