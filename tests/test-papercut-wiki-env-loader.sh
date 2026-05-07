#!/usr/bin/env bash
# tests/test-papercut-wiki-env-loader.sh
#
# Acceptance for the Layer 1 + Layer 2 paper-cut at
# .orchestrator/proposals/papercut-wiki-deploy-env-loader.md.
#
# Exercises the two-path contract:
#   1. wiki-init.sh --with-giscus writes <project>/.env with four
#      `export GISCUS_*` lines under a managed marker block, idempotent
#      across re-runs.
#   2. wiki-deploy.sh --dry-run against the same fixture passes gate 1
#      WITHOUT any GISCUS_* env vars pre-exported in the invoking shell
#      (the script's .env loader populates them from disk).
#
# Uses M032_GISCUS_IDS_FROM_GH_STUB=1 for deterministic IDs and
# M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 to skip the FR-10 cwd-vs-repo_url
# gate (the fixture has a synthetic remote, not a real GH repo).
#
# Bash 3.2 compatible. MIT-001 SKIP_REASON when python3 unavailable.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3 unavailable on this host"
  exit 77
fi

TMP="$(mktemp -d -t papercut-env-loader.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the M032 P01 shared fixture.
cp -R "$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture/." "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/fixture-repo.git ) >/dev/null 2>&1

# wiki-deploy.sh invokes its sibling scripts via project-relative paths
# (`bash scripts/diagnostics/wiki-giscus-config-check.sh`). The fixture
# is the pre-installer baseline and lacks scripts/; symlink the repo's
# scripts/ into the fixture so the dry-run resolves the helpers without
# requiring a full installer staging step. This mirrors what
# install-claude-code.sh / install-codex.sh / install-cursor.sh stage
# at install time (see references/INSTALLATION.md).
ln -s "$REPO_ROOT/scripts" "$TMP/scripts"

ENV_FILE="$TMP/.env"
MARK_START='# >>> orchestrator-managed: giscus >>>'
MARK_END='# <<< orchestrator-managed: giscus <<<'

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Pre-1: default-scope wiki-init to stage wiki/.
if ! bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$TMP" >/dev/null 2>"$TMP/init.err"; then
  say_fail "default-scope wiki-init failed against fixture (precondition)"
  sed -n '1,40p' "$TMP/init.err" >&2 || true
  printf 'SUMMARY: papercut-env-loader pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 1. wiki-init --with-giscus writes <project>/.env with the marker block.
set +e
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>"$TMP/giscus.err"
giscus_rc=$?
set -e

if [ "$giscus_rc" -eq 0 ] && [ -f "$ENV_FILE" ]; then
  say_pass "Layer 2: wiki-init --with-giscus exited 0 and created $ENV_FILE"
else
  say_fail "Layer 2: wiki-init --with-giscus rc=$giscus_rc, $ENV_FILE present=$([ -f "$ENV_FILE" ] && echo yes || echo no)"
  sed -n '1,60p' "$TMP/giscus.err" >&2 || true
fi

if grep -qF "$MARK_START" "$ENV_FILE" \
   && grep -qF "$MARK_END" "$ENV_FILE" \
   && grep -qF 'export GISCUS_REPO="fixture-owner/fixture-repo"' "$ENV_FILE" \
   && grep -qF 'export GISCUS_REPO_ID="R_kgDOFixture"' "$ENV_FILE" \
   && grep -qF 'export GISCUS_CATEGORY="Wiki Comments"' "$ENV_FILE" \
   && grep -qF 'export GISCUS_CATEGORY_ID="DIC_kwDOFixture"' "$ENV_FILE"; then
  say_pass "Layer 2: managed marker block + four export lines present in $ENV_FILE"
else
  say_fail "Layer 2: marker block or one of the four export lines missing in $ENV_FILE"
  sed -n '1,40p' "$ENV_FILE" >&2 || true
fi

# 2. Idempotency — re-run with same flags leaves exactly one marker block.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>&1
START_COUNT=$(grep -cF "$MARK_START" "$ENV_FILE" 2>/dev/null)
END_COUNT=$(grep -cF "$MARK_END" "$ENV_FILE" 2>/dev/null)
if [ "$START_COUNT" = "1" ] && [ "$END_COUNT" = "1" ]; then
  say_pass "Layer 2 idempotency: re-run leaves exactly one marker block (start=$START_COUNT end=$END_COUNT)"
else
  say_fail "Layer 2 idempotency: marker-block duplication after re-run (start=$START_COUNT end=$END_COUNT)"
fi

# 3. Marker-block replacement on flag change — different repo/category replaces in-place.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner-2/fixture-repo-2 --category 'Different Category' \
  --project-dir "$TMP" >/dev/null 2>&1
if grep -qF 'export GISCUS_REPO="fixture-owner-2/fixture-repo-2"' "$ENV_FILE" \
   && grep -qF 'export GISCUS_CATEGORY="Different Category"' "$ENV_FILE" \
   && ! grep -qF 'export GISCUS_REPO="fixture-owner/fixture-repo"' "$ENV_FILE"; then
  say_pass "Layer 2 replacement: new IDs displaced prior IDs in marker block"
else
  say_fail "Layer 2 replacement: prior IDs not displaced or new IDs absent"
fi

# Restore the original fixture-owner IDs for the Layer 1 deploy test below.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$TMP" >/dev/null 2>&1

# 4. Layer 1 contract — wiki-deploy.sh sources .env so gate 1 PASSes
#    without any GISCUS_* env vars pre-exported in the invoking shell.
#    Scoped to gate 1 only: subsequent gates (mkdocs build, link-check,
#    smoke) depend on a fully-built wiki tree and are out of scope for
#    this paper-cut.
unset GISCUS_REPO GISCUS_REPO_ID GISCUS_CATEGORY GISCUS_CATEGORY_ID

set +e
deploy_out="$(M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 \
  bash "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" --root "$TMP" --dry-run 2>&1)"
set -e

if printf '%s' "$deploy_out" | grep -qF 'GATE: giscus-config PASS'; then
  say_pass "Layer 1: wiki-deploy.sh sources .env — gate 1 PASS without pre-exported env vars"
else
  say_fail "Layer 1: gate 1 did not PASS; .env loader did not populate GISCUS_* vars"
  printf '%s\n' "$deploy_out" | sed -n '1,60p' >&2 || true
fi

# 5. Negative — without .env present, gate 1 still fails (proves loader is
#    additive, not a backstop that masks missing config).
rm -f "$ENV_FILE"
unset GISCUS_REPO GISCUS_REPO_ID GISCUS_CATEGORY GISCUS_CATEGORY_ID

set +e
deploy_neg_out="$(M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 \
  bash "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" --root "$TMP" --dry-run 2>&1)"
deploy_neg_rc=$?
set -e

if [ "$deploy_neg_rc" -ne 0 ] \
   && printf '%s' "$deploy_neg_out" | grep -qF 'GATE: giscus-config FAIL' \
   && printf '%s' "$deploy_neg_out" | grep -qF 'wiki-init.sh'; then
  say_pass "Layer 1 negative: missing .env still fails gate 1 with HINT pointing at wiki-init"
else
  say_fail "Layer 1 negative: rc=$deploy_neg_rc; expected gate-1 FAIL with wiki-init HINT"
  printf '%s\n' "$deploy_neg_out" | sed -n '1,60p' >&2 || true
fi

printf 'SUMMARY: papercut-env-loader pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
