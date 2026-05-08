#!/usr/bin/env bash
# tests/m035-acceptance/cross-channel-byte-equivalence.sh
# Constitution Principle XVI compliance test (M035 P02 T03 -- npm-
# channel skeleton; P03 extends homebrew arm; P04 extends curl-
# pipe-bash arm).
#
# Hashes the staged runtime tree post-install for each channel,
# compares across channels for byte equivalence (modulo the
# exclusion list at references/installation.md
# Channel-specific metadata files).
#
# P02 contract: npm-channel arm runs end-to-end and emits NPM_HASH=.
# Other arms emit SKIP: pending P03/P04 and do NOT contribute to the
# final equality assertion. The script's exit code is 0 if every
# non-skipped arm passes its own internal hash-reproducibility
# check.
#
# Bash 3.2 compatible. No declare -A.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALLATION_MD="$REPO_ROOT/references/installation.md"

pass=0
fail=0
skip=0

# --- 1. Read the exclusion list from installation.md --------------

# Extract exclusion paths from the markdown table in
# references/installation.md. Lines look like:
# | `.orchestrator/install-meta.txt` | all | ... |
# We grep table rows and extract the first column's backticked path.
if [ ! -f "$INSTALLATION_MD" ]; then
  echo "FAIL: $INSTALLATION_MD missing -- exclusion-list source not found"
  exit 1
fi

EXCLUSION_LIST="$(awk '
  /^## Channel-specific metadata files/ { flag=1; next }
  flag && /^## / { flag=0 }
  flag
' "$INSTALLATION_MD" | grep -oE '`[^`]+`' | sed -E 's/^`//; s/`$//' \
  | grep -vE '^(all|npm|homebrew|all,)$' || true)"

if [ -z "$EXCLUSION_LIST" ]; then
  echo "FAIL: exclusion list empty -- installation.md Channel-specific metadata files unreadable"
  exit 1
fi

excl_count="$(echo "$EXCLUSION_LIST" | wc -l | tr -d ' ')"
echo "exclusion_list_lines=$excl_count"

# --- 2. npm-channel arm ------------------------------------------

if ! command -v npm >/dev/null 2>&1; then
  echo "FAIL: npm not on PATH -- npm-channel arm cannot run"
  fail=$((fail + 1))
else
  NPM_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t03npm)"
  trap 'rm -rf "$NPM_FIXTURE" 2>/dev/null || true' EXIT

  # 2a. npm pack (offline tarball assembly from package.json)
  pack_ok=1
  ( cd "$REPO_ROOT" && npm pack --pack-destination "$NPM_FIXTURE" \
      >"$NPM_FIXTURE/pack.log" 2>&1 ) || pack_ok=0
  if [ "$pack_ok" -eq 0 ]; then
    echo "FAIL: npm pack failed (see $NPM_FIXTURE/pack.log)"
    fail=$((fail + 1))
  fi

  TARBALL="$(find "$NPM_FIXTURE" -name 'build-fractal-orchestrator-*.tgz' \
    -type f | head -1)"
  if [ -z "$TARBALL" ]; then
    echo "FAIL: npm pack produced no tarball matching build-fractal-orchestrator-*.tgz"
    fail=$((fail + 1))
  else
    echo "PASS: npm pack produced $TARBALL"
    pass=$((pass + 1))

    # 2b. Install into a fixture prefix under DRY_RUN=1 postinstall.
    FIXTURE_PREFIX="$NPM_FIXTURE/.npm-prefix"
    mkdir -p "$FIXTURE_PREFIX"
    export DRY_RUN=1
    export INIT_CWD="$NPM_FIXTURE/project"
    mkdir -p "$INIT_CWD"
    install_ok=1
    ( cd "$NPM_FIXTURE" && npm install -g --prefix "$FIXTURE_PREFIX" \
        "$TARBALL" >"$NPM_FIXTURE/install.log" 2>&1 ) || install_ok=0
    unset DRY_RUN
    unset INIT_CWD

    if [ "$install_ok" -eq 0 ]; then
      echo "FAIL: npm install of tarball failed (see $NPM_FIXTURE/install.log)"
      fail=$((fail + 1))
    fi

    # 2c. Hash the staged tree under FIXTURE_PREFIX, applying
    # exclusion list. The staged tree lives at
    # $FIXTURE_PREFIX/lib/node_modules/@build-fractal/orchestrator/.
    STAGED="$FIXTURE_PREFIX/lib/node_modules/@build-fractal/orchestrator"
    if [ ! -d "$STAGED" ]; then
      echo "FAIL: staged tree not found at $STAGED"
      fail=$((fail + 1))
    else
      # Delegate hashing to a single-script-file helper (AD-19 / AP-009
      # honored: no inline compound chains in this script). The helper
      # is a committed in-repo script, not a staged probe, so it is
      # invoked directly via `bash <single-script>` rather than via
      # scripts/util/run-probe.sh (which is scoped to /tmp/-staged
      # probes only).
      export STAGED EXCLUSION_LIST
      NPM_HASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
        2>"$NPM_FIXTURE/hash.err")"
      if [ -n "$NPM_HASH" ]; then
        echo "NPM_HASH=$NPM_HASH"
        echo "PASS: npm-channel hash emitted"
        pass=$((pass + 1))
      else
        echo "FAIL: npm-channel hash not emitted (see $NPM_FIXTURE/hash.err)"
        fail=$((fail + 1))
      fi
    fi
  fi
fi

# --- 3. homebrew-channel arm (stub, P03 extends) ------------------

echo "SKIP: pending P03 -- homebrew-channel hash assertion"
skip=$((skip + 1))

# --- 4. curl-pipe-bash-channel arm (stub, P04 extends) ------------

echo "SKIP: pending P04 -- curl-pipe-bash-channel hash assertion"
skip=$((skip + 1))

# --- 5. Cross-channel equality assertion (P03+) -------------------

# When 2+ non-skipped channel hashes are emitted, assert they match.
# P02 always has only NPM_HASH; the assertion is a no-op (single-
# channel byte equivalence is reflexive).
echo "BATTERY: pass=$pass fail=$fail skip=$skip"

[ "$fail" -eq 0 ]
