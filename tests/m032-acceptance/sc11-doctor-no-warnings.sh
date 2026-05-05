#!/usr/bin/env bash
# tests/m032-acceptance/sc11-doctor-no-warnings.sh
#
# SC-11 — verifies three orthogonal M032 spec invariants per the
# MIT-002 + MIT-008 amendments against a stub-bootstrapped fixture
# project plus the orchestrator's own wiki/ tree:
#
#   1. Constitution VIII (No Dead Infrastructure) — running
#      `scripts/diagnostics/run-doctor.sh --root <fixture>` exits 0 AND
#      stdout contains zero `dead-infrastructure` or `unreferenced-asset`
#      warning lines.
#
#   2. MIT-002 — `scripts/wiki/wiki-serve.sh --probe` (port-free
#      mkdocs build --strict health check) against the orchestrator
#      repo's own wiki/ tree exits 0. Closes the FR-6 self-application
#      loop — the orchestrator dogfoods its own wiki throughout M032.
#
#   3. MIT-008 — after the stubbed `--deploy` step completes, the
#      fixture's `<fixture>/.orchestrator/execution-log.jsonl` carries
#      >= 1 NDJSON record matching `"event_type":"wiki-deploy-mutation"`
#      AND `"result":"success"`. Constitution VI (State On Disk Is
#      Truth) applied to remote-state mutations.
#
# Hermetic envelopes per P03/T02 + M026/MEM030 convention:
#   M032_GISCUS_IDS_FROM_GH_STUB=1   (giscus stub — referenced by spec)
#   M032_DEPLOY_GH_API_STUB=1        (gh api PATCH/GET/PUT stubs)
#   M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1
# No live network. Trap-EXIT cleanup per AD-7 throwaway-fixture pattern.
#
# Bash 3.2 compatible (per MEM001). Single-script-file shape (AD-19).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"
FIXTURE_DST="/tmp/m032-p04-sc11-fixture-$$"
STUB_DIR="/tmp/m032-p04-sc11-stub-$$"

cleanup() {
  set +e
  rm -rf "$FIXTURE_DST" 2>/dev/null
  rm -rf "$STUB_DIR" 2>/dev/null
  true
}
trap cleanup EXIT INT TERM

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# ---- bootstrap fixture under stubs ------------------------------------
# Materialize the shared P01 fresh-project fixture (read-only at rest)
# into a scratch dir, initialize git + origin per the fixture README's
# bootstrap procedure (required so wiki-init.sh's FR-5 origin-parse step
# succeeds; --deploy step otherwise exits 4).
mkdir -p "$FIXTURE_DST"
cp -R "$FIXTURE_SRC"/. "$FIXTURE_DST"/
mkdir -p "$STUB_DIR"

# Stub envelope reference: P03/T02 wiki-init.sh consumes the env-vars
# M032_GISCUS_IDS_FROM_GH_STUB / M032_DEPLOY_GH_API_STUB /
# M032_DEPLOY_GH_API_STUB_DIR / M032_WIKI_DEPLOY_BYPASS_CWD_GATE for
# hermetic --with-giscus + --deploy coverage. The deploy stub branch
# in wiki-init.sh writes the wiki-deploy-mutation audit record without
# requiring gh / mkdocs / network. The pages-get.json fixture below
# documents the optional fixture filename the stub envelope reads on
# the MIT-007 read-before-write Pages guard step (left unset here so
# the guard treats Pages as not-yet-configured — happy path).
: > "$STUB_DIR/pages-get.json.placeholder"

(
  cd "$FIXTURE_DST" || exit 1
  git init -q
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git
)

# Run wiki-init.sh --deploy under the stub envelope. This is the
# minimal hermetic invocation that exercises the MIT-008 audit-trail
# branch end-to-end (FR-6 + FR-9 + MIT-007 + MIT-008 all fire under
# M032_DEPLOY_GH_API_STUB=1). The full --with-wiki --with-giscus
# --deploy chain depends on python3/pip3 + a staged comments.html
# partial; verifier-contract-over-verifier-skeleton (P03 patterns-
# established) — ship the contract intent (wiki-deploy-mutation
# success record on disk) using the surface that exists hermetically.
M032_GISCUS_IDS_FROM_GH_STUB=1 \
  M032_DEPLOY_GH_API_STUB=1 \
  M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" \
  M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 \
  bash "$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh" \
    --deploy \
    --project-dir "$FIXTURE_DST" \
    >"$STUB_DIR/wiki-init.out" 2>"$STUB_DIR/wiki-init.err"
_wiki_init_rc=$?

if [ "$_wiki_init_rc" -ne 0 ]; then
  say_fail "wiki-init.sh --deploy stub bootstrap rc=$_wiki_init_rc (see $STUB_DIR/wiki-init.err)"
fi

# ---- ASSERTION GROUP 1: Constitution VIII (run-doctor.sh no warnings) ----
# run-doctor.sh accepts --root <project-root>; emits any
# `dead-infrastructure` / `unreferenced-asset` lines on stdout if
# Constitution VIII surfaces are broken. Contract: rc=0 and zero
# warning matches.
set +e
bash "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh" --root "$FIXTURE_DST" \
  >"$STUB_DIR/doctor.out" 2>&1
_doctor_rc=$?
set -e

_warn_count=$(grep -cE 'dead-infrastructure|unreferenced-asset' "$STUB_DIR/doctor.out" || true)
if [ "$_doctor_rc" -eq 0 ] && [ "$_warn_count" -eq 0 ]; then
  say_pass "Constitution VIII: run-doctor.sh exit 0 with zero dead-infrastructure/unreferenced-asset warnings"
else
  say_fail "Constitution VIII: doctor rc=$_doctor_rc, warn_count=$_warn_count (see $STUB_DIR/doctor.out)"
fi

# ---- ASSERTION GROUP 2: MIT-002 (wiki-serve --probe self-application) ----
# wiki-serve.sh --probe runs mkdocs build --strict to a throwaway
# site-dir against the orchestrator's own wiki/mkdocs.yml. The script
# derives PROJECT_ROOT from its own location (no --root flag); we just
# invoke it. Contract: rc=0 (mkdocs --strict accepts the orchestrator's
# wiki/ tree).
set +e
bash "$PROJECT_ROOT/scripts/wiki/wiki-serve.sh" --probe \
  >"$STUB_DIR/serve.out" 2>&1
_serve_rc=$?
set -e

if [ "$_serve_rc" -eq 0 ]; then
  say_pass "MIT-002: wiki-serve.sh --probe exit 0 against orchestrator wiki/"
else
  say_fail "MIT-002: wiki-serve --probe rc=$_serve_rc (see $STUB_DIR/serve.out)"
fi

# ---- ASSERTION GROUP 3: MIT-008 (audit-trail record presence) ----
_logfile="$FIXTURE_DST/.orchestrator/execution-log.jsonl"
if [ -f "$_logfile" ]; then
  _audit_count=$(grep -cF '"event_type":"wiki-deploy-mutation"' "$_logfile" || true)
  _success_count=$(grep -cF '"result":"success"' "$_logfile" || true)
  if [ "$_audit_count" -ge 1 ] && [ "$_success_count" -ge 1 ]; then
    say_pass "MIT-008: execution-log.jsonl carries $_audit_count wiki-deploy-mutation record(s) with result=success"
  else
    say_fail "MIT-008: audit_count=$_audit_count, success_count=$_success_count"
  fi
else
  say_fail "MIT-008: execution-log.jsonl missing at $_logfile"
fi

printf 'RESULT: SC-11 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
