#!/usr/bin/env bash
# tools/verify/m035-p05-release-workflow-signing-shape.sh
#
# M035 P05 T03 — sigstore signing shape verifier.
#
# Asserts .github/workflows/release.yml carries the load-bearing M035
# P05 T03 contract surfaces (D004: sigstore keyless primary +
# SHA-256 fallback). All assertions are static grep checks against
# the workflow YAML; runtime semantics (real OIDC issuance, real
# Rekor entry) are exercised in T05's signature-verification battery
# under default-OFF live mode (M030 P03 live-LLM precedent).
#
# AD-19 single-script-file shape. CON-3 / AP-009 compound-chain
# shape-guard honored: each grep is an independent invocation.
# Bash 3.2 compatible. No jq, no yq, no python (the YAML lint probe
# in /tmp/m035-p05-t03-yaml-validate.sh handles structural shape;
# this verifier exercises the textual contract).
#
# Expected output (matches task plan):
#   PASS: npm-publish job declares permissions.id-token: write
#   PASS: npm-publish job declares permissions.contents: write
#   PASS: workflow uses sigstore/cosign-installer
#   PASS: cosign release version is pinned
#   PASS: Stage release artifacts step exists
#   PASS: Generate SHA256SUMS step exists
#   PASS: cosign sign-blob invocation present
#   PASS: cosign sign-blob uses --output-signature and --output-certificate
#   PASS: gh release create invocation present
#   PASS: SHA256SUMS itself is signed
#   BATTERY: pass=10 fail=0
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WF="$REPO/.github/workflows/release.yml"

pass=0
fail=0

if [ ! -f "$WF" ]; then
  echo "FAIL: $WF not found"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

check_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$WF"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (pattern: $pattern)"
    fail=$((fail + 1))
  fi
}

# 1. Job-level permissions block under npm-publish includes id-token: write.
#    The workflow-level `permissions: contents: read` (top of file) is
#    overridden at the job level for the OIDC scope cosign keyless needs.
check_grep '^[[:space:]]+id-token:[[:space:]]+write' \
  "npm-publish job declares permissions.id-token: write"

# 2. Job-level permissions block also opens contents: write for
#    `gh release create` (default workflow-level read is insufficient).
check_grep '^[[:space:]]+contents:[[:space:]]+write' \
  "npm-publish job declares permissions.contents: write"

# 3. Setup cosign step uses the pinned sigstore/cosign-installer action.
check_grep 'sigstore/cosign-installer' \
  "workflow uses sigstore/cosign-installer"

# 4. Cosign release version is pinned (string `cosign-release:` present).
check_grep 'cosign-release:' \
  "cosign release version is pinned"

# 5. Stage release artifacts step exists (anchor: release-artifacts dir).
check_grep 'Stage release artifacts' \
  "Stage release artifacts step exists"

# 6. Generate SHA256SUMS step exists (anchor: SHA256SUMS).
check_grep 'Generate SHA256SUMS' \
  "Generate SHA256SUMS step exists"

# 7. Sign release artifacts step invokes `cosign sign-blob` (keyless).
check_grep 'cosign sign-blob' \
  "cosign sign-blob invocation present"

# 8. cosign sign-blob uses --output-signature AND --output-certificate.
#    Single PASS line covers both flags per the plan's named assertion.
if grep -qE '\-\-output-signature' "$WF" && \
   grep -qE '\-\-output-certificate' "$WF"; then
  echo "PASS: cosign sign-blob uses --output-signature and --output-certificate"
  pass=$((pass + 1))
else
  echo "FAIL: cosign sign-blob missing --output-signature and/or --output-certificate"
  fail=$((fail + 1))
fi

# 9. Create GitHub release step invokes gh release create.
check_grep 'gh release create' \
  "gh release create invocation present"

# 10. SHA256SUMS itself is signed — anchor: SHA256SUMS.sig appears in
#     the workflow (cosign sign-blob is invoked against SHA256SUMS,
#     emitting SHA256SUMS.sig).
check_grep 'SHA256SUMS\.sig' \
  "SHA256SUMS itself is signed"

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
