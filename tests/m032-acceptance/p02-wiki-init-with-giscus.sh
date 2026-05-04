#!/usr/bin/env bash
# tests/m032-acceptance/p02-wiki-init-with-giscus.sh — M032/P03/T01 SC-4 (FR-7 + FR-8).
#
# Verifies: wiki/overrides/partials/comments.html bundle-staged copy carries
# the four {{giscus_*}} placeholder tokens; wiki-init.sh --with-giscus
# substitutes them with deterministic fixture IDs under
# M032_GISCUS_IDS_FROM_GH_STUB=1; the post-step wiki-giscus-config-check.sh
# verifier exits 0; failure injection (M032_GISCUS_IDS_FROM_GH_STUB=fail)
# leaves the partial in placeholder state with `integration-giscus-config-failed`
# diagnostic; re-run with same flags is idempotent; re-run with different
# flags overwrites with new IDs (US-3 AS-3).
#
# MIT-001 SKIP semantics: exit 77 with `SKIP_REASON: ...` on stdout when
# python3 is unavailable. Acceptance battery distinguishes 77 from pass / fail.
#
# The committed P01 fixture is read-only at test time (per its README
# invariants); this script stages it into a mktemp -d copy and tears the
# copy down on every exit path — same convention as SC-3
# (p02-wiki-init-default-scope.sh).
#
# Bash 3.2 compatible (MEM001). Single-script-file shape per AD-19.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# MIT-001 SKIP_REASON if python3 unavailable.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3 unavailable on this host"
  exit 77
fi

TMP="$(mktemp -d -t m032-sc4.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the P01 shared fixture (read-only baseline).
cp -R "$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture/." "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/fixture-repo.git ) >/dev/null 2>&1

PARTIAL="$TMP/wiki/overrides/partials/comments.html"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Pre-1: wiki-init default scope to stage the partial in the staged fixture.
if ! bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$TMP" >/dev/null 2>"$TMP/init.err"; then
  say_fail "default-scope wiki-init failed against fixture (SC-4 precondition)"
  sed -n '1,40p' "$TMP/init.err" >&2
  printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 1. Bundle-staged partial carries the four placeholder tokens (FR-7).
if grep -qF '{{giscus_repo}}' "$PARTIAL" && \
   grep -qF '{{giscus_repo_id}}' "$PARTIAL" && \
   grep -qF '{{giscus_category}}' "$PARTIAL" && \
   grep -qF '{{giscus_category_id}}' "$PARTIAL"; then
  say_pass "FR-7: four {{giscus_*}} placeholder tokens present in staged partial"
else
  say_fail "FR-7: one or more {{giscus_*}} placeholder tokens missing from $PARTIAL"
fi

# 2. Happy path with stub mode 1 (FR-8).
set +e
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>"$TMP/giscus.err"
giscus_rc=$?
set -e
if [ "$giscus_rc" -eq 0 ] && \
   grep -qF 'fixture-owner/fixture-repo' "$PARTIAL" && \
   grep -qF 'R_kgDOFixture' "$PARTIAL" && \
   grep -qF 'Wiki Comments' "$PARTIAL" && \
   grep -qF 'DIC_kwDOFixture' "$PARTIAL" && \
   ! grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 happy path: four IDs substituted, no {{giscus_repo}} placeholder remains"
else
  say_fail "FR-8 happy path: rc=$giscus_rc; partial does not carry expected fixture IDs (or placeholder remains)"
  sed -n '1,40p' "$TMP/giscus.err" >&2 || true
fi

# 3. Post-step verifier exits 0 (wiki-giscus-config-check.sh requires the
#    GISCUS_* env vars to be set; supply them from the same fixture values
#    that --with-giscus just substituted).
set +e
GISCUS_REPO=fixture-owner/fixture-repo \
GISCUS_REPO_ID=R_kgDOFixture \
GISCUS_CATEGORY='Wiki Comments' \
GISCUS_CATEGORY_ID=DIC_kwDOFixture \
  bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --quiet
check_rc=$?
set -e
if [ "$check_rc" -eq 0 ]; then
  say_pass "FR-8 post-step: wiki-giscus-config-check.sh exits 0 after substitution"
else
  say_fail "FR-8 post-step: wiki-giscus-config-check.sh rc=$check_rc"
fi

# 4. Failure injection branch — re-stage the partial to reset placeholder state.
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$PARTIAL"
set +e
err_out="$(M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" 2>&1)"
inject_rc=$?
set -e
if [ "$inject_rc" -ne 0 ] && \
   printf '%s' "$err_out" | grep -qF 'integration-giscus-config-failed' && \
   grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 failure injection: rc=$inject_rc, integration-giscus-config-failed diagnostic, partial in placeholder state"
else
  say_fail "FR-8 failure injection: rc=$inject_rc; expected non-zero with diagnostic and placeholders preserved"
fi

# 5. Re-run idempotency (same flags twice).
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$PARTIAL"
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>&1
SHA_FIRST=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>&1
SHA_SECOND=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
if [ "$SHA_FIRST" = "$SHA_SECOND" ]; then
  say_pass "FR-8 re-run idempotency: partial sha-256 stable across two same-flag invocations"
else
  say_fail "FR-8 re-run idempotency: partial sha-256 changed: $SHA_FIRST -> $SHA_SECOND"
fi

# 6. Overwrite branch (US-3 AS-3) — re-stage placeholder state, then
#    invoke with different --repo / --category.
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$PARTIAL"
set +e
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner-2/fixture-repo-2 --category 'Different Category' \
  --project-dir "$TMP" >/dev/null 2>&1
overwrite_rc=$?
set -e
if [ "$overwrite_rc" -eq 0 ] && \
   grep -qF 'fixture-owner-2/fixture-repo-2' "$PARTIAL" && \
   grep -qF 'Different Category' "$PARTIAL" && \
   ! grep -qF 'fixture-owner/fixture-repo' "$PARTIAL"; then
  say_pass "FR-8 overwrite branch (US-3 AS-3): new IDs replace prior IDs"
else
  say_fail "FR-8 overwrite branch: rc=$overwrite_rc; new IDs absent or prior IDs not displaced"
fi

printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
