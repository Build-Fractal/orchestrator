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
# P03 contract: npm-channel + homebrew-channel arms run end-to-end
# and emit NPM_HASH= and HOMEBREW_HASH=. The cross-channel equality
# assertion (CON-5 / Constitution Principle XVI) fires when both
# arms emit hashes. The curl-pipe-bash arm remains a SKIP stub
# (P04 extends). The script's exit code is 0 if every non-skipped
# arm passes its own internal hash-reproducibility check AND the
# cross-channel equality assertion (when fired) passes.
#
# Bash 3.2 compatible. No declare -A.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALLATION_MD="$REPO_ROOT/references/installation.md"

pass=0
fail=0
skip=0

# --- 1. Read per-channel exclusion lists from installation.md ----

if [ ! -f "$INSTALLATION_MD" ]; then
  echo "FAIL: $INSTALLATION_MD missing -- exclusion-list source not found"
  exit 1
fi

export INSTALLATION_MD
CHANNEL=npm
export CHANNEL
EXCLUSION_LIST_NPM="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
CHANNEL=homebrew
export CHANNEL
EXCLUSION_LIST_HOMEBREW="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
unset CHANNEL

if [ -z "$EXCLUSION_LIST_NPM" ] || [ -z "$EXCLUSION_LIST_HOMEBREW" ]; then
  echo "FAIL: per-channel exclusion list empty -- installation.md table unreadable"
  exit 1
fi

npm_excl_lines="$(printf '%s\n' "$EXCLUSION_LIST_NPM" | wc -l | tr -d ' ')"
brew_excl_lines="$(printf '%s\n' "$EXCLUSION_LIST_HOMEBREW" | wc -l | tr -d ' ')"
echo "exclusion_list_npm_lines=$npm_excl_lines"
echo "exclusion_list_homebrew_lines=$brew_excl_lines"

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
      EXCLUSION_LIST="$EXCLUSION_LIST_NPM"
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

# --- 3. homebrew-channel arm (D007 + T03) ------------------------

HOMEBREW_HASH=""
if [ -z "${TARBALL:-}" ] || [ ! -f "$TARBALL" ]; then
  echo "SKIP: homebrew-channel arm requires npm-channel tarball — npm-channel did not produce one"
  skip=$((skip + 1))
else
  BREW_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p03t03brew)"
  trap 'rm -rf "$NPM_FIXTURE" "$BREW_FIXTURE" 2>/dev/null || true' EXIT

  # Extract the npm-channel tarball into a fixture Cellar layout
  # mirroring brew's /opt/homebrew/Cellar/orchestrator/<version>/
  # structure. The npm pack tarball extracts into a top-level
  # "package/" dir per npm convention; Homebrew STRIPS that single
  # leading dir on unpack, so the formula's def install block does
  # `prefix.install Dir["*"]` against the stripped root. This test
  # controls its own extraction (no strip) and therefore flattens
  # package/* by hand to reproduce the same staged Cellar layout —
  # package contents directly under <Cellar>/<version>/.
  # Use POSIX [[:space:]] rather than \s — BSD sed (macOS) doesn't
  # recognize \s and silently no-ops the substitution, leaving
  # PKG_VERSION as the entire matched line. Surfaced after T03 dispatch.
  PKG_VERSION="$(grep -E '^[[:space:]]*"version"[[:space:]]*:' "$REPO_ROOT/package.json" \
    | head -1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  CELLAR="$BREW_FIXTURE/Cellar/orchestrator/$PKG_VERSION"
  mkdir -p "$CELLAR"
  tar -xzf "$TARBALL" -C "$BREW_FIXTURE" >/dev/null 2>&1
  # mv package/* into Cellar/<version>/ (flatten — matches def install)
  if [ -d "$BREW_FIXTURE/package" ]; then
    # Use cp -R + rm rather than mv so it works across exotic FS.
    cp -R "$BREW_FIXTURE/package/." "$CELLAR/"
    rm -rf "$BREW_FIXTURE/package"
    echo "PASS: homebrew-channel staged into $CELLAR"
    pass=$((pass + 1))
  else
    echo "FAIL: tarball did not extract into expected package/ dir"
    fail=$((fail + 1))
  fi

  # Hash the staged tree with homebrew-channel exclusion list.
  STAGED="$CELLAR"
  EXCLUSION_LIST="$EXCLUSION_LIST_HOMEBREW"
  export STAGED EXCLUSION_LIST
  HOMEBREW_HASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
    2>"$BREW_FIXTURE/hash.err")"
  if [ -n "$HOMEBREW_HASH" ]; then
    echo "HOMEBREW_HASH=$HOMEBREW_HASH"
    echo "PASS: homebrew-channel hash emitted"
    pass=$((pass + 1))
  else
    echo "FAIL: homebrew-channel hash not emitted (see $BREW_FIXTURE/hash.err)"
    fail=$((fail + 1))
  fi
fi

# --- 4. curl-pipe-bash-channel arm (D007 + T03 / FR-10) ----------

# Pre-compute curl-pipe-bash exclusion list (re-uses the existing
# _exclusion-list-by-channel.sh helper; CHANNEL=curl-pipe-bash matches
# rows in the references/installation.md table that list "all" or
# "curl-pipe-bash" or comma-separated lists containing curl-pipe-bash).
CHANNEL=curl-pipe-bash
export CHANNEL
EXCLUSION_LIST_CURL_BASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
unset CHANNEL

CURL_HASH=""
if [ -z "${TARBALL:-}" ] || [ ! -f "$TARBALL" ]; then
  echo "SKIP: curl-pipe-bash-channel arm requires npm-channel tarball — npm-channel did not produce one"
  skip=$((skip + 1))
elif [ ! -x "$REPO_ROOT/packaging/install/install.sh" ]; then
  echo "SKIP: curl-pipe-bash-channel arm requires packaging/install/install.sh — not on disk or not executable"
  skip=$((skip + 1))
else
  CURL_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p04t03curl)"
  trap 'rm -rf "$NPM_FIXTURE" "$BREW_FIXTURE" "$CURL_FIXTURE" 2>/dev/null || true' EXIT

  # Invoke install.sh in test-mode: LOCAL_TARBALL short-circuits
  # the download + SHA-verify steps; STAGE_ONLY=1 extracts and
  # exits without dispatching install-claude-code.sh; STAGE_DIR
  # lets us control where the staged tree lands.
  CURL_STAGE="$CURL_FIXTURE/staged"
  mkdir -p "$CURL_STAGE"
  M035_P04_LOCAL_TARBALL="$TARBALL" \
  M035_P04_STAGE_ONLY=1 \
  M035_P04_STAGE_DIR="$CURL_STAGE" \
    bash "$REPO_ROOT/packaging/install/install.sh" \
    >"$CURL_FIXTURE/install.log" 2>&1 \
    || { echo "FAIL: install.sh STAGE_ONLY mode failed (see $CURL_FIXTURE/install.log)"; fail=$((fail + 1)); }

  if [ -d "$CURL_STAGE" ] && [ -f "$CURL_STAGE/package.json" ]; then
    echo "PASS: curl-pipe-bash-channel staged into $CURL_STAGE"
    pass=$((pass + 1))

    # Hash the staged tree with curl-pipe-bash exclusion list.
    STAGED="$CURL_STAGE"
    EXCLUSION_LIST="$EXCLUSION_LIST_CURL_BASH"
    export STAGED EXCLUSION_LIST
    CURL_HASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
      2>"$CURL_FIXTURE/hash.err")"
    if [ -n "$CURL_HASH" ]; then
      echo "CURL_HASH=$CURL_HASH"
      echo "PASS: curl-pipe-bash-channel hash emitted"
      pass=$((pass + 1))
    else
      echo "FAIL: curl-pipe-bash-channel hash not emitted (see $CURL_FIXTURE/hash.err)"
      fail=$((fail + 1))
    fi
  else
    echo "FAIL: curl-pipe-bash-channel staged tree missing or empty"
    fail=$((fail + 1))
  fi
fi

# --- 5. Cross-channel equality assertion (CON-5 / Principle XVI) -

# 3-way assertion: fires when ALL THREE arms emit hashes.
# 2-way fallback: fires when only npm + homebrew emit hashes (curl
# arm SKIPped). 1-way fallback: SKIP entirely when fewer than two
# arms emit hashes.

if [ -n "${NPM_HASH:-}" ] && [ -n "${HOMEBREW_HASH:-}" ] && [ -n "$CURL_HASH" ]; then
  # 3-way path — load-bearing CON-5 / Constitution Principle XVI test.
  if [ "$NPM_HASH" = "$HOMEBREW_HASH" ] && [ "$HOMEBREW_HASH" = "$CURL_HASH" ]; then
    echo "PASS: cross-channel byte-equivalence (3-way) — NPM_HASH = HOMEBREW_HASH = CURL_HASH"
    pass=$((pass + 1))
  else
    echo "FAIL: cross-channel byte-equivalence violated (3-way)"
    echo "  NPM_HASH=$NPM_HASH"
    echo "  HOMEBREW_HASH=$HOMEBREW_HASH"
    echo "  CURL_HASH=$CURL_HASH"
    echo "  See references/installation.md § Channel-specific metadata files"
    echo "  for the per-channel exclusion list. If the divergence is a"
    echo "  legitimate channel-specific metadata file, add it to that"
    echo "  table and re-run."
    fail=$((fail + 1))
  fi
elif [ -n "${NPM_HASH:-}" ] && [ -n "${HOMEBREW_HASH:-}" ]; then
  # 2-way fallback: curl arm unavailable.
  if [ "$NPM_HASH" = "$HOMEBREW_HASH" ]; then
    echo "PASS: cross-channel byte-equivalence (2-way) — NPM_HASH = HOMEBREW_HASH (CURL_HASH unavailable)"
    pass=$((pass + 1))
  else
    echo "FAIL: cross-channel byte-equivalence violated (2-way, curl arm SKIPped)"
    echo "  NPM_HASH=$NPM_HASH"
    echo "  HOMEBREW_HASH=$HOMEBREW_HASH"
    fail=$((fail + 1))
  fi
else
  echo "SKIP: cross-channel equality assertion requires at least NPM_HASH and HOMEBREW_HASH"
  skip=$((skip + 1))
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
[ "$fail" -eq 0 ]
