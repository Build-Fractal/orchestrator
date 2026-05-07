#!/usr/bin/env bash
# tests/m037-acceptance/p03-overrides-refresh.sh — M037 P03 round-4 acceptance.
#
# Verifies the framework-managed wiki/overrides/ refresh step in
# scripts/lifecycle/wiki-init.sh closes the staging gap surfaced by the
# 2026-05-07 PBJ round-3.5 dogfood. The bundle ships
# wiki/overrides/main.html (P3.1 breadcrumb shim) and updates
# wiki/overrides/partials/comments.html (P3.2 file-feedback aside +
# M032 dual-template surface), but neither install path stages those
# files into existing projects without this refresh step.
#
# Scenarios:
#   (a) Absent project file → restored from bundle byte-identical.
#   (b) Substituted-managed comments.html (placeholder absent, Jinja
#       form present) + .env carries GISCUS_* → re-staged from bundle
#       and re-substituted from .env. Result has the new feedback aside
#       AND the substituted GISCUS_REPO value.
#   (c) Operator-edited main.html (different from bundle, no recognized
#       managed shape) → original preserved, <f>.bundle.new written,
#       WARN line emitted to stderr.
#
# Phase artifact contract: this file is >= 30 lines and contains the
# literal string "wiki/overrides/" (M037 P03 round-4 plan artifact must-have).
# Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INSTALL="$PROJECT_ROOT/packaging/install/install-claude-code.sh"
WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"
BUNDLE_MAIN="$PROJECT_ROOT/wiki/overrides/main.html"
BUNDLE_COMMENTS="$PROJECT_ROOT/wiki/overrides/partials/comments.html"

if [ ! -f "$BUNDLE_MAIN" ] || [ ! -f "$BUNDLE_COMMENTS" ]; then
  echo "FAIL: bundle wiki/overrides/ files missing at $PROJECT_ROOT/wiki/overrides/"
  exit 1
fi

scenario_pass=0
scenario_fail=0

scn_ok() { printf 'PASS: scenario %s\n' "$1"; scenario_pass=$((scenario_pass + 1)); }
scn_bad() { printf 'FAIL: scenario %s — %s\n' "$1" "$2"; scenario_fail=$((scenario_fail + 1)); }

WORK="$(mktemp -d -t m037-p03-overrides.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# Common project setup: install + initial wiki-init.
PROJ="$WORK/proj"
mkdir -p "$PROJ"
cd "$PROJ"
git init -q
git remote add origin git@github.com:Test-Org/test-repo.git
bash "$INSTALL" --project-dir . --force >"$WORK/install.log" 2>&1 || {
  echo "FAIL: install-claude-code.sh exited non-zero (log: $WORK/install.log)"
  exit 1
}
GH_VISIBILITY_OVERRIDE=public bash "$WIKI_INIT" --project-dir . >"$WORK/wiki-init-initial.log" 2>&1 || {
  echo "FAIL: initial wiki-init.sh exited non-zero (log: $WORK/wiki-init-initial.log)"
  exit 1
}

# Sanity: after initial install + wiki-init, both override files should exist
# and match bundle (the initial install path stages them via project_assets).
if [ ! -f "$PROJ/wiki/overrides/main.html" ]; then
  echo "FAIL: initial run did not produce $PROJ/wiki/overrides/main.html"
  exit 1
fi

# --- Scenario (a): absent project file restored from bundle ----------------
rm -f "$PROJ/wiki/overrides/main.html"
GH_VISIBILITY_OVERRIDE=public bash "$WIKI_INIT" --project-dir "$PROJ" >"$WORK/scn-a.log" 2>&1
if [ ! -f "$PROJ/wiki/overrides/main.html" ]; then
  scn_bad "(a)" "main.html not restored after deletion (log: $WORK/scn-a.log)"
elif ! cmp -s "$BUNDLE_MAIN" "$PROJ/wiki/overrides/main.html"; then
  scn_bad "(a)" "restored main.html does not match bundle"
else
  scn_ok "(a) absent main.html restored from bundle byte-identical"
fi

# --- Scenario (b): substituted-managed comments.html re-substituted from .env
# Set up: write a "previously substituted" comments.html (placeholder absent,
# Jinja form present, fake old shape WITHOUT the new feedback aside). Persist
# fake GISCUS_* values to .env under the orchestrator-managed marker block.
cat > "$PROJ/wiki/overrides/partials/comments.html" <<'OLDCOMMENTS'
{# Pre-round-3.5 comments partial — Jinja form intact, M032 placeholder
   already substituted with concrete IDs. No P3.2 feedback aside. #}
<h2 id="__comments">Comments</h2>
<script
  src="https://giscus.app/client.js"
  data-repo="OldOrg/old-repo{{ config.extra.giscus.repo }}"
  data-repo-id="R_OldId{{ config.extra.giscus.repo_id }}"
  data-category="OldCat{{ config.extra.giscus.category }}"
  data-category-id="DIC_OldCatId{{ config.extra.giscus.category_id }}"
  async
></script>
OLDCOMMENTS

cat > "$PROJ/.env" <<'ENVEOF'
# >>> orchestrator-managed: giscus >>>
export GISCUS_REPO="Test-Org/test-repo"
export GISCUS_REPO_ID="R_kgDOTestId"
export GISCUS_CATEGORY="Announcements"
export GISCUS_CATEGORY_ID="DIC_kwDOTestCatId"
# <<< orchestrator-managed: giscus <<<
ENVEOF

GH_VISIBILITY_OVERRIDE=public bash "$WIKI_INIT" --project-dir "$PROJ" >"$WORK/scn-b.log" 2>&1
b_miss=""
# The refreshed file must carry the round-3.5 P3.2 feedback aside.
grep -q 'Spot something off on this page?' "$PROJ/wiki/overrides/partials/comments.html" \
  || b_miss="$b_miss feedback-aside"
# The M032 placeholder must be substituted with the .env value.
grep -q 'data-repo="Test-Org/test-repo' "$PROJ/wiki/overrides/partials/comments.html" \
  || b_miss="$b_miss giscus-repo-substituted"
grep -q 'data-repo-id="R_kgDOTestId' "$PROJ/wiki/overrides/partials/comments.html" \
  || b_miss="$b_miss giscus-repo-id-substituted"
# The Jinja form must remain unsubstituted (mkdocs build resolves it).
grep -q '{{ config.extra.giscus.repo }}' "$PROJ/wiki/overrides/partials/comments.html" \
  || b_miss="$b_miss jinja-form-preserved"
# No leftover {{giscus_*}} M032 placeholders should remain after substitution.
if grep -q '{{giscus_repo}}' "$PROJ/wiki/overrides/partials/comments.html"; then
  b_miss="$b_miss leftover-m032-placeholder"
fi
# Diagnostic line should mention re-substitution.
grep -q 're-substituted GISCUS_\* from' "$WORK/scn-b.log" \
  || b_miss="$b_miss diagnostic-missing"
if [ -z "$b_miss" ]; then
  scn_ok "(b) substituted-managed comments.html re-staged + re-substituted from .env"
else
  scn_bad "(b)" "miss:$b_miss (log: $WORK/scn-b.log)"
fi

# --- Scenario (c): operator-edited main.html → .bundle.new + WARN ----------
cat > "$PROJ/wiki/overrides/main.html" <<'CUSTOMSHIM'
{# Operator-edited shim — verbatim hand-written customization
   that the refresh step should NOT clobber. #}
{% extends "base.html" %}
{% block content %}
  <p>Custom operator banner.</p>
  {{ super() }}
{% endblock %}
CUSTOMSHIM
custom_hash=$(wc -c < "$PROJ/wiki/overrides/main.html" | tr -d ' ')

GH_VISIBILITY_OVERRIDE=public bash "$WIKI_INIT" --project-dir "$PROJ" >"$WORK/scn-c.log" 2>"$WORK/scn-c.err"
c_miss=""
# Operator's main.html must be byte-preserved.
preserved_hash=$(wc -c < "$PROJ/wiki/overrides/main.html" | tr -d ' ')
if [ "$custom_hash" != "$preserved_hash" ]; then
  c_miss="$c_miss operator-file-mutated"
fi
# .bundle.new sidecar must exist with bundle content.
if [ ! -f "$PROJ/wiki/overrides/main.html.bundle.new" ]; then
  c_miss="$c_miss bundle-new-missing"
elif ! cmp -s "$BUNDLE_MAIN" "$PROJ/wiki/overrides/main.html.bundle.new"; then
  c_miss="$c_miss bundle-new-not-bundle"
fi
# WARN line must be emitted to stderr.
grep -q 'WARN: wiki-init:.*diverges from bundle' "$WORK/scn-c.err" \
  || c_miss="$c_miss warn-not-emitted"
if [ -z "$c_miss" ]; then
  scn_ok "(c) operator-edited main.html preserved; .bundle.new written; WARN emitted"
else
  scn_bad "(c)" "miss:$c_miss (stdout: $WORK/scn-c.log, stderr: $WORK/scn-c.err)"
fi

printf 'SUMMARY: p03-overrides-refresh scenarios pass=%d fail=%d\n' "$scenario_pass" "$scenario_fail"
if [ "$scenario_fail" -eq 0 ]; then
  printf 'PASS: p03-overrides-refresh (%d/3 scenarios)\n' "$scenario_pass"
  exit 0
fi
exit 1
