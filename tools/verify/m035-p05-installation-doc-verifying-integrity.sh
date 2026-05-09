#!/usr/bin/env bash
# tools/verify/m035-p05-installation-doc-verifying-integrity.sh
#
# M035 P05 T04 — operator-facing integrity-verification doc surface
# verifier (FR-11).
#
# Asserts references/installation.md carries the load-bearing
# `## Verifying integrity` section (subsections + canonical
# tooling tokens + identity-URL pattern + Rekor reference). The
# identity-URL pattern is byte-identical to what T03's
# .github/workflows/release.yml signs against (canonical-repo +
# workflow-file path + per-tag suffix); drift between this doc
# and the workflow makes operator verification fail end-to-end.
#
# AD-19 single-script-file shape. CON-3 / AP-009 compound-chain
# shape-guard honored: each grep is an independent invocation
# against a single file (no pipes, no chains). Bash 3.2 compatible.
# All assertions use grep -F (literal-string matches) so markdown
# punctuation does not regex-confuse the check.
#
# Expected output (matches task plan):
#   PASS: ## Verifying integrity heading present
#   PASS: ### Path 1: Sigstore keyless verification heading present
#   PASS: ### Path 2: SHA-256 checksum verification heading present
#   PASS: ### What to do if verification fails heading present
#   PASS: cosign verify-blob recipe present
#   PASS: shasum -a 256 -c SHA256SUMS recipe present
#   PASS: canonical-repo identity URL present
#   PASS: OIDC issuer URL present
#   PASS: search.sigstore.dev Rekor reference present
#   BATTERY: pass=9 fail=0
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO/references/installation.md"

pass=0
fail=0

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC not found"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

check_fixed() {
  local needle="$1"
  local label="$2"
  if grep -q -F -- "$needle" "$DOC"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (needle: $needle)"
    fail=$((fail + 1))
  fi
}

# 1. Top-level section heading.
check_fixed '## Verifying integrity' \
  '## Verifying integrity heading present'

# 2. Path 1 subsection heading (sigstore keyless).
check_fixed '### Path 1: Sigstore keyless verification' \
  '### Path 1: Sigstore keyless verification heading present'

# 3. Path 2 subsection heading (sha256 fallback).
check_fixed '### Path 2: SHA-256 checksum verification' \
  '### Path 2: SHA-256 checksum verification heading present'

# 4. Failure-recovery subsection heading.
check_fixed '### What to do if verification fails' \
  '### What to do if verification fails heading present'

# 5. cosign verify-blob recipe present.
check_fixed 'cosign verify-blob' \
  'cosign verify-blob recipe present'

# 6. shasum -a 256 -c SHA256SUMS recipe present.
check_fixed 'shasum -a 256 -c SHA256SUMS' \
  'shasum -a 256 -c SHA256SUMS recipe present'

# 7. Canonical-repo identity URL pattern (byte-identical to T03's
#    .github/workflows/release.yml signing path; drift makes operator
#    verification fail end-to-end).
check_fixed 'https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml' \
  'canonical-repo identity URL present'

# 8. GitHub Actions OIDC issuer URL.
check_fixed 'https://token.actions.githubusercontent.com' \
  'OIDC issuer URL present'

# 9. Sigstore Rekor transparency-log reference (failure-recovery path).
check_fixed 'search.sigstore.dev' \
  'search.sigstore.dev Rekor reference present'

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
