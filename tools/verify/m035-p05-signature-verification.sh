#!/usr/bin/env bash
# tools/verify/m035-p05-signature-verification.sh
#
# M035 P05 T05 — SC-11 signature-verification verifier (FR-11 + D004).
#
# Two execution modes mirroring the M030 P03 live-LLM gating
# discipline:
#
#   Shape mode (default) — runs against the fixture release dir
#     tests/m035-acceptance/fixtures/m035-p05-release-fixture/
#     and asserts the artifact quartet is present, non-empty, and
#     internally consistent (SHA256SUMS hash matches install.sh).
#     Always-on; no external tooling beyond shasum required.
#
#   Live mode — opt-in via:
#     COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR=<path> env vars.
#     Runs `cosign verify-blob` against a real release directory
#     identified by the env var. Optional identity override via
#     M035_P05_LIVE_IDENTITY (defaults to the canonical T03/T04
#     identity URL pattern). Default behavior in CI is SKIP.
#
# Constitution / contracts:
#   - AD-19 single-script-file shape; no compound chains, no
#     process substitution, no $(... | ...).
#   - CON-3 / AP-009 honored: each external invocation is its own
#     command, independent grep/shasum calls.
#   - Mirrors M030 P03 live-LLM gating: live verification path is
#     opt-in; CI default is SKIP rather than mock — no silently-
#     mocked surface.
#   - Plan-Time Discipline Rule 5 (real-app smoke): the always-on
#     `shasum -a 256 -c SHA256SUMS` runs against real fixture data,
#     not a mock.
#
# Expected output (shape mode default):
#   PASS: install.sh exists in fixture
#   PASS: install.sh.sig exists in fixture
#   PASS: install.sh.pem exists in fixture
#   PASS: SHA256SUMS exists in fixture
#   PASS: shasum -a 256 -c SHA256SUMS validates install.sh
#   PASS: install.sh.sig non-empty
#   PASS: install.sh.pem non-empty
#   SKIP: cosign verify-blob (gated by COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR)
#   BATTERY: pass=7 fail=0 skip=1

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
FIXTURE_DIR="${M035_P05_LIVE_RELEASE_DIR:-$REPO/tests/m035-acceptance/fixtures/m035-p05-release-fixture}"

pass_count=0
fail_count=0
skip_count=0

check_exists() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    echo "PASS: $label exists in fixture"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $label absent from fixture (expected $path)"
    fail_count=$((fail_count + 1))
  fi
}

# --- Shape mode -----------------------------------------------------

check_exists "$FIXTURE_DIR/install.sh"     "install.sh"
check_exists "$FIXTURE_DIR/install.sh.sig" "install.sh.sig"
check_exists "$FIXTURE_DIR/install.sh.pem" "install.sh.pem"
check_exists "$FIXTURE_DIR/SHA256SUMS"     "SHA256SUMS"

# SHA256SUMS verification (no cosign dependency). cd into fixture
# so the relative `install.sh` reference inside SHA256SUMS resolves.
sha_log="$(mktemp -t m035-p05-sigverif.XXXXXX)"
(
  cd "$FIXTURE_DIR" && shasum -a 256 -c SHA256SUMS --ignore-missing
) >"$sha_log" 2>&1
sha_rc=$?
if [ "$sha_rc" -eq 0 ]; then
  echo "PASS: shasum -a 256 -c SHA256SUMS validates install.sh"
  pass_count=$((pass_count + 1))
else
  echo "FAIL: shasum -c SHA256SUMS failed against fixture (see $sha_log)"
  fail_count=$((fail_count + 1))
fi
rm -f "$sha_log"

# Sig + cert non-empty content checks. Placeholder comment headers
# satisfy `-s` (file size > 0) without requiring real cosign output.
if [ -s "$FIXTURE_DIR/install.sh.sig" ]; then
  echo "PASS: install.sh.sig non-empty"
  pass_count=$((pass_count + 1))
else
  echo "FAIL: install.sh.sig empty"
  fail_count=$((fail_count + 1))
fi

if [ -s "$FIXTURE_DIR/install.sh.pem" ]; then
  echo "PASS: install.sh.pem non-empty"
  pass_count=$((pass_count + 1))
else
  echo "FAIL: install.sh.pem empty"
  fail_count=$((fail_count + 1))
fi

# --- Live mode (gated) ---------------------------------------------
#
# Both COSIGN_AVAILABLE=1 AND M035_P05_LIVE_RELEASE_DIR=<path> must
# be set to enable the real cosign verification path. Default in CI
# (and on dispatcher dispatches) is SKIP.
COSIGN_LIVE="${COSIGN_AVAILABLE:-0}"
LIVE_DIR="${M035_P05_LIVE_RELEASE_DIR:-}"

if [ "$COSIGN_LIVE" = "1" ] && [ -n "$LIVE_DIR" ]; then
  IDENTITY="${M035_P05_LIVE_IDENTITY:-https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v0.0.0-test}"
  ISSUER="https://token.actions.githubusercontent.com"

  cosign_log="$(mktemp -t m035-p05-cosign.XXXXXX)"
  cosign verify-blob \
    --certificate-identity "$IDENTITY" \
    --certificate-oidc-issuer "$ISSUER" \
    --signature "$LIVE_DIR/install.sh.sig" \
    --certificate "$LIVE_DIR/install.sh.pem" \
    "$LIVE_DIR/install.sh" >"$cosign_log" 2>&1
  cosign_rc=$?
  if [ "$cosign_rc" -eq 0 ]; then
    echo "PASS: cosign verify-blob succeeds against live release"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: cosign verify-blob failed against live release (see $cosign_log)"
    fail_count=$((fail_count + 1))
  fi
  rm -f "$cosign_log"
else
  echo "SKIP: cosign verify-blob (gated by COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR)"
  skip_count=$((skip_count + 1))
fi

echo "BATTERY: pass=$pass_count fail=$fail_count skip=$skip_count"
[ "$fail_count" -eq 0 ] || exit 1
exit 0
