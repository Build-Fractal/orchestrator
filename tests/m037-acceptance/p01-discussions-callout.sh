#!/usr/bin/env bash
# tests/m037-acceptance/p01-discussions-callout.sh — M037 P02 SC-17 acceptance.
#
# Exercises the FR-22b org-level-discussions-redirect callout in
# wiki/README.md. PBJ-central operator hit this dead-end on 2026-05-07
# (papercut-sweep-wiki-deploy-2026-05-07.md finding #7); the callout names
# both the symptom (302 redirect to org-level page) and the recovery path
# (`<Org>/<Repo>/discussions/categories` direct URL).
#
# Asserts:
#   1. wiki/README.md contains `discussions/categories` (recovery URL pattern).
#   2. The recovery URL lives inside the "First-deploy checklist" section
#      (between `## First-deploy checklist` and the next `## ` heading).
#   3. Pre-existing checklist anchors survive: `giscus GitHub App`,
#      `wiki-init --with-giscus`, `Smoke-test the deployed URL`.
#
# Phase artifact contract: this file contains the literal string
# "discussions/categories" (M037 P02 plan must-have).
# Bash 3.2 + POSIX sh compatible. Single-script-file (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

README="$PROJECT_ROOT/wiki/README.md"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# ---------- Case 1: recovery URL pattern present ----------

if [ ! -f "$README" ]; then
  bad "wiki/README.md missing at $README"
  printf 'SUMMARY: p01-discussions-callout pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -q 'discussions/categories' "$README"; then
  ok "Case 1: discussions/categories recovery URL present"
else
  bad "Case 1: discussions/categories recovery URL missing"
fi

# ---------- Case 2: callout inside First-deploy checklist section ----------

section="$(awk '
  /^## First-deploy checklist[[:space:]]*$/ { in_section = 1; next }
  in_section && /^## / { in_section = 0 }
  in_section { print }
' "$README")"

if [ -z "$section" ]; then
  bad "Case 2: First-deploy checklist section not found"
else
  if printf '%s\n' "$section" | grep -q 'discussions/categories'; then
    ok "Case 2: discussions/categories URL inside First-deploy checklist"
  else
    bad "Case 2: discussions/categories URL not inside First-deploy checklist"
  fi
fi

# ---------- Case 3: pre-existing checklist anchors preserved ----------

if grep -q 'giscus GitHub App' "$README"; then
  ok "Case 3a: pre-existing anchor preserved: giscus GitHub App"
else
  bad "Case 3a: pre-existing anchor lost: giscus GitHub App"
fi

if grep -q 'wiki-init --with-giscus' "$README"; then
  ok "Case 3b: pre-existing anchor preserved: wiki-init --with-giscus"
else
  bad "Case 3b: pre-existing anchor lost: wiki-init --with-giscus"
fi

if grep -q 'Smoke-test the deployed URL' "$README"; then
  ok "Case 3c: pre-existing anchor preserved: Smoke-test the deployed URL"
else
  bad "Case 3c: pre-existing anchor lost: Smoke-test the deployed URL"
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p01-discussions-callout pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p02-discussions-callout\n'
  exit 0
fi
exit 1
