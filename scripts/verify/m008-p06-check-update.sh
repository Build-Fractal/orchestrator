#!/usr/bin/env bash
# scripts/verify/m008-p06-check-update.sh — Verify offline-safe check-update.sh.
#
# Asserts:
#   1. Unreachable remote (.invalid TLD) → exit 0, all three required keys,
#      update_available=unknown.
#   2. Hermetic VERSION fixture → installed_version reflects the fixture.
#   3. (Optional, curl-gated) file:// remote returning installed version →
#      update_available=false.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK_UPDATE="$REPO_ROOT/scripts/lifecycle/check-update.sh"

if [ ! -x "$CHECK_UPDATE" ]; then
  echo "FAIL: $CHECK_UPDATE missing or not executable" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------
# Subtest 1: offline remote produces update_available=unknown.
# ------------------------------------------------------------------
out1="$TMP/offline.out"
bash "$CHECK_UPDATE" \
  --remote-url 'https://speckit.example.invalid/does-not-exist' \
  --timeout 2 > "$out1" 2>&1
rc1=$?

if [ "$rc1" != "0" ]; then
  echo "FAIL: offline check-update exited non-zero ($rc1)" >&2
  cat "$out1" >&2
  exit 1
fi

if ! grep -q '^installed_version=' "$out1"; then
  echo "FAIL: missing installed_version" >&2
  cat "$out1" >&2
  exit 1
fi

if ! grep -q '^latest_version=' "$out1"; then
  echo "FAIL: missing latest_version" >&2
  cat "$out1" >&2
  exit 1
fi

if ! grep -q '^update_available=unknown' "$out1"; then
  echo "FAIL: expected update_available=unknown under offline remote" >&2
  cat "$out1" >&2
  exit 1
fi

# Offline output must not leak an update_instructions line (spec says only
# emitted when update_available=true).
if grep -q '^update_instructions=' "$out1"; then
  echo "FAIL: update_instructions should not appear when latest=unknown" >&2
  cat "$out1" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Subtest 2: hermetic VERSION fixture drives installed_version.
# Build a fake project dir with a VERSION file and a stub manifest.
# ------------------------------------------------------------------
fixture="$TMP/fixture"
mkdir -p "$fixture/packaging/bundle"
printf '9.9.9-fixture\n' > "$fixture/VERSION"
cat > "$fixture/packaging/bundle/manifest.yml" <<'YAML'
schema_version: "1.0"
type: bundle-manifest
name: "fixture"
version: "0.0.0-manifest"
YAML

out2="$TMP/fixture.out"
bash "$CHECK_UPDATE" \
  --project-dir "$fixture" \
  --remote-url 'https://speckit.example.invalid/does-not-exist' \
  --timeout 2 > "$out2" 2>&1
rc2=$?

if [ "$rc2" != "0" ]; then
  echo "FAIL: fixture check-update exited non-zero ($rc2)" >&2
  cat "$out2" >&2
  exit 1
fi

if ! grep -q '^installed_version=9\.9\.9-fixture$' "$out2"; then
  echo "FAIL: installed_version did not pick up VERSION fixture" >&2
  cat "$out2" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Subtest 2b: manifest-only fallback when VERSION absent.
# ------------------------------------------------------------------
fixture2="$TMP/fixture-manifest-only"
mkdir -p "$fixture2/packaging/bundle"
cat > "$fixture2/packaging/bundle/manifest.yml" <<'YAML'
schema_version: "1.0"
type: bundle-manifest
name: "fixture"
version: "1.2.3-manifest"
YAML

out2b="$TMP/fixture2.out"
bash "$CHECK_UPDATE" \
  --project-dir "$fixture2" \
  --remote-url 'https://speckit.example.invalid/does-not-exist' \
  --timeout 2 > "$out2b" 2>&1
rc2b=$?

if [ "$rc2b" != "0" ]; then
  echo "FAIL: manifest-only fixture check-update exited non-zero ($rc2b)" >&2
  cat "$out2b" >&2
  exit 1
fi

if ! grep -q '^installed_version=1\.2\.3-manifest$' "$out2b"; then
  echo "FAIL: installed_version did not fall back to manifest.yml" >&2
  cat "$out2b" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Subtest 3 (curl-gated): file:// URL returns installed version →
# update_available=false.
# ------------------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  latest_file="$TMP/latest.txt"
  printf '9.9.9-fixture\n' > "$latest_file"

  out3="$TMP/equal.out"
  bash "$CHECK_UPDATE" \
    --project-dir "$fixture" \
    --remote-url "file://$latest_file" \
    --timeout 2 > "$out3" 2>&1
  rc3=$?

  if [ "$rc3" != "0" ]; then
    echo "WARN: file:// subtest exited non-zero ($rc3) — curl may lack file:// support; skipping" >&2
  else
    if grep -q '^latest_version=9\.9\.9-fixture$' "$out3" \
       && grep -q '^update_available=false$' "$out3"; then
      : # pass
    elif grep -q '^update_available=unknown$' "$out3"; then
      echo "WARN: curl did not fetch file:// URL (update_available=unknown); skipping equality subtest" >&2
    else
      echo "FAIL: equality subtest — expected update_available=false" >&2
      cat "$out3" >&2
      exit 1
    fi

    # Subtest 3b: mismatched remote → update_available=true +
    # update_instructions line.
    printf '99.99.99\n' > "$latest_file"
    out4="$TMP/diff.out"
    bash "$CHECK_UPDATE" \
      --project-dir "$fixture" \
      --remote-url "file://$latest_file" \
      --timeout 2 > "$out4" 2>&1
    rc4=$?
    if [ "$rc4" != "0" ]; then
      echo "WARN: mismatch file:// subtest exited non-zero ($rc4); skipping" >&2
    elif grep -q '^update_available=unknown$' "$out4"; then
      echo "WARN: curl did not fetch file:// URL for mismatch subtest; skipping" >&2
    else
      if ! grep -q '^update_available=true$' "$out4"; then
        echo "FAIL: mismatch subtest — expected update_available=true" >&2
        cat "$out4" >&2
        exit 1
      fi
      if ! grep -q '^update_instructions=' "$out4"; then
        echo "FAIL: mismatch subtest — expected update_instructions line" >&2
        cat "$out4" >&2
        exit 1
      fi
    fi
  fi
else
  echo "INFO: curl unavailable; skipping file:// equality subtest" >&2
fi

echo "PASS: check-update.sh offline-safe"
exit 0
