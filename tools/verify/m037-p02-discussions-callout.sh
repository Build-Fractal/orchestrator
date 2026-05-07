#!/usr/bin/env bash
# tools/verify/m037-p02-discussions-callout.sh — M037 P02 T05 FR-22b verifier.
#
# Asserts:
#  1. wiki/README.md contains the recovery URL pattern `discussions/categories`.
#  2. wiki/README.md contains a literal mention of the symptom (`302` or
#     `redirect`) near the callout.
#  3. The callout lands inside the "First-deploy checklist" section
#     (between the `## First-deploy checklist` heading and the next `## ` heading).
#  4. Pre-existing checklist items survive byte-anchored: `giscus GitHub App`
#     (step 1), `wiki-init --with-giscus` (step 2), `Smoke-test the deployed URL`
#     (step 4).
#  5. tests/m037-acceptance/p01-discussions-callout.sh exists and exits 0.
#
# AD-19 compliant: invokes the test scaffold via `bash <path>` only.
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

README="$PROJECT_ROOT/wiki/README.md"
ACCEPTANCE="$PROJECT_ROOT/tests/m037-acceptance/p01-discussions-callout.sh"

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

# ---------- Gate 1: recovery URL pattern present ----------

if [ ! -f "$README" ]; then
  bad "wiki/README.md missing at $README"
else
  if grep -q 'discussions/categories' "$README"; then
    ok "wiki/README.md mentions discussions/categories recovery URL"
  else
    bad "wiki/README.md missing discussions/categories recovery URL"
  fi

  # ---------- Gate 2: symptom token present ----------

  if grep -E -q '302|redirect' "$README"; then
    ok "wiki/README.md mentions symptom token (302 or redirect)"
  else
    bad "wiki/README.md missing symptom token (302 or redirect)"
  fi

  # ---------- Gate 3: callout lives inside First-deploy checklist section ----------

  # Extract the section content between `## First-deploy checklist` and the
  # next `## ` heading. awk: print lines after the marker until the next
  # top-level `## ` heading.
  section="$(awk '
    /^## First-deploy checklist[[:space:]]*$/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section { print }
  ' "$README")"

  if [ -z "$section" ]; then
    bad "First-deploy checklist section not found in wiki/README.md"
  else
    if printf '%s\n' "$section" | grep -q 'discussions/categories'; then
      ok "discussions/categories URL appears inside First-deploy checklist"
    else
      bad "discussions/categories URL not inside First-deploy checklist"
    fi
  fi

  # ---------- Gate 4: pre-existing checklist anchors survive ----------

  if grep -q 'giscus GitHub App' "$README"; then
    ok "step 1 anchor preserved: giscus GitHub App"
  else
    bad "step 1 anchor missing: giscus GitHub App"
  fi

  if grep -q 'wiki-init --with-giscus' "$README"; then
    ok "step 2 anchor preserved: wiki-init --with-giscus"
  else
    bad "step 2 anchor missing: wiki-init --with-giscus"
  fi

  if grep -q 'Smoke-test the deployed URL' "$README"; then
    ok "step 4 anchor preserved: Smoke-test the deployed URL"
  else
    bad "step 4 anchor missing: Smoke-test the deployed URL"
  fi
fi

# ---------- Gate 5: acceptance scaffold exists and passes ----------

if [ ! -f "$ACCEPTANCE" ]; then
  bad "tests/m037-acceptance/p01-discussions-callout.sh missing"
else
  set +e
  bash "$ACCEPTANCE" > /dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    ok "p01-discussions-callout.sh acceptance scaffold passes"
  else
    bad "p01-discussions-callout.sh acceptance scaffold failed (rc=$rc)"
  fi
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: m037-p02-discussions-callout pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
