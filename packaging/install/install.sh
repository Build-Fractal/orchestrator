#!/usr/bin/env bash
# packaging/install/install.sh
#
# M035 P04 — curl-pipe-bash one-liner installer for orchestrator.
#
# Usage (consumer-facing):
#   curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
#
# Or pinned to a version:
#   ORCHESTRATOR_VERSION=v1.0.0 \
#     curl -sSL https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/install.sh | bash
#
# D009 (M035 P04 T01): hosted at GitHub release asset URL —
#   latest:   https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh
#   pinned:   https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh
# Rationale: zero new infrastructure, symmetric with the npm + homebrew
# release-asset distribution model, versioned + unversioned URLs both
# ship for free, reversible to a polished short URL post-launch.
#
# Test-mode env vars (default OFF, no production behavior change):
#   M035_P04_LOCAL_TARBALL=<path>  short-circuits download/SHA-verify
#                                  steps; uses the named tarball as
#                                  if it had been downloaded from
#                                  the release.
#   M035_P04_STAGE_ONLY=1          extracts the tarball into the
#                                  staging dir and exits 0 with
#                                  `STAGED_DIR=<path>` on stdout —
#                                  does NOT invoke install-claude-code.sh
#                                  or remove the staged dir.
#   M035_P04_STAGE_DIR=<path>      overrides the default mktemp -d
#                                  staging dir (used by the byte-
#                                  equivalence test to control hash
#                                  scope).
#
# Bash 3.2 + POSIX-sh-safe (no associative arrays, no mapfile, no
# process substitution, no jq, no python). Long-running probes use
# if/then blocks rather than &&-chains beyond two clauses.
#
# Exit codes:
#   0  success (install dispatched OR STAGE_ONLY mode complete)
#   1  generic failure (FAIL: line on stderr)
#   2  unsupported runtime (no Claude Code detected, no fallback)
#   3  download or SHA-verify failed

set -eu

REPO="${ORCHESTRATOR_REPO:-Build-Fractal/orchestrator}"
VERSION="${ORCHESTRATOR_VERSION:-latest}"
LOCAL_TARBALL="${M035_P04_LOCAL_TARBALL:-}"
STAGE_ONLY="${M035_P04_STAGE_ONLY:-0}"
STAGE_DIR_OVERRIDE="${M035_P04_STAGE_DIR:-}"

ORIG_PWD="$(pwd)"

# --- Banner / --help / --version ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<EOF
orchestrator — curl-pipe-bash installer (M035 P04)

Usage:
  curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash

Pinned version:
  ORCHESTRATOR_VERSION=v1.0.0 bash install.sh

After install, run \`/orchestrator-init\` inside any project to
register the orchestrator:<cmd> skill cohort.

See https://github.com/Build-Fractal/orchestrator for source
and references/installation.md for the full installation matrix.
EOF
  exit 0
fi

if [ "${1:-}" = "--version" ]; then
  echo "orchestrator-install.sh (M035 P04 — see ${REPO})"
  exit 0
fi

# --- Resolve staging directory ---
if [ -n "$STAGE_DIR_OVERRIDE" ]; then
  STAGED_DIR="$STAGE_DIR_OVERRIDE"
  mkdir -p "$STAGED_DIR"
else
  STAGED_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t orchestrator-install)"
fi

# Cleanup trap unless STAGE_ONLY (test-mode preserves the tree).
if [ "$STAGE_ONLY" != "1" ]; then
  trap 'rm -rf "$STAGED_DIR" 2>/dev/null || true' EXIT
fi

# --- Resolve tarball: download from GH release, OR use local override ---
if [ -n "$LOCAL_TARBALL" ]; then
  # Test-mode: skip download + SHA-verify, use the named tarball.
  if [ ! -f "$LOCAL_TARBALL" ]; then
    echo "FAIL: M035_P04_LOCAL_TARBALL=$LOCAL_TARBALL — file not found" >&2
    exit 1
  fi
  TARBALL_PATH="$LOCAL_TARBALL"
  echo "M035_P04_LOCAL_TARBALL test-mode active — skipping download/SHA-verify"
else
  # Production path: query GitHub for the release tag, derive
  # tarball URL, download via curl, verify SHA-256.
  if ! command -v curl >/dev/null 2>&1; then
    echo "FAIL: curl not on PATH — install.sh requires curl" >&2
    exit 1
  fi
  if ! command -v shasum >/dev/null 2>&1; then
    echo "FAIL: shasum not on PATH — install.sh requires shasum (or sha256sum)" >&2
    exit 1
  fi

  # Resolve TAG. If VERSION=latest, query GitHub for the latest
  # release tag (jq-free grep+sed parse of the JSON response).
  if [ "$VERSION" = "latest" ]; then
    LATEST_JSON="$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest")"
    TAG="$(printf '%s\n' "$LATEST_JSON" \
      | grep -E '"tag_name"[[:space:]]*:' \
      | head -1 \
      | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  else
    TAG="$VERSION"
  fi

  if [ -z "$TAG" ]; then
    echo "FAIL: could not resolve release tag for VERSION=$VERSION" >&2
    exit 3
  fi

  # Strip leading v from TAG to derive the tarball asset name.
  # Asset name pattern: build-fractal-orchestrator-<version>.tgz
  # (npm scope @build-fractal/orchestrator -> file basename
  # build-fractal-orchestrator).
  TAG_NO_V="${TAG#v}"
  ASSET="build-fractal-orchestrator-${TAG_NO_V}.tgz"
  URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
  SHA_URL="https://github.com/${REPO}/releases/download/${TAG}/SHA256SUMS"

  echo "Downloading $ASSET from $URL ..."
  TARBALL_PATH="$STAGED_DIR/$ASSET"
  if ! curl -sSL -o "$TARBALL_PATH" "$URL"; then
    echo "FAIL: download failed: $URL" >&2
    exit 3
  fi

  # Download SHA256SUMS and verify.
  SHA_PATH="$STAGED_DIR/SHA256SUMS"
  if ! curl -sSL -o "$SHA_PATH" "$SHA_URL"; then
    echo "FAIL: SHA256SUMS download failed: $SHA_URL" >&2
    exit 3
  fi
  ( cd "$STAGED_DIR" && shasum -a 256 -c SHA256SUMS --ignore-missing ) \
    || { echo "FAIL: SHA-256 verification failed for $ASSET" >&2; exit 3; }
  echo "PASS: SHA-256 verification — $ASSET"
fi

# --- Extract tarball ---
# The npm pack tarball wraps content in a top-level package/ dir.
# Flatten: extract package/* directly into $STAGED_DIR. This installer
# controls its own extraction, so it flattens package/ explicitly; the
# homebrew formula relies on brew stripping the leading package/ dir and
# then does `prefix.install Dir["*"]`. Both yield the same post-extract
# tree shape as the npm-channel `lib/node_modules/<scope>/<name>/` —
# cross-channel byte-equivalence requires identical post-extract trees.
tar -xzf "$TARBALL_PATH" -C "$STAGED_DIR" >/dev/null 2>&1 \
  || { echo "FAIL: tar extract failed for $TARBALL_PATH" >&2; exit 1; }
if [ -d "$STAGED_DIR/package" ]; then
  # cp -R + rm rather than mv for exotic-FS robustness.
  cp -R "$STAGED_DIR/package/." "$STAGED_DIR/"
  rm -rf "$STAGED_DIR/package"
fi

# --- STAGE_ONLY test-mode exit ---
if [ "$STAGE_ONLY" = "1" ]; then
  echo "STAGED_DIR=$STAGED_DIR"
  echo "PASS: M035_P04_STAGE_ONLY=1 — staging complete, dispatch skipped"
  exit 0
fi

# --- Runtime detection (CC-only at v1) ---
if [ ! -d "$HOME/.claude" ]; then
  echo "FAIL: ~/.claude not found — Claude Code is the only supported runtime at v1." >&2
  echo "  Codex CLI / Cursor support is post-launch (M009 fast-follow);" >&2
  echo "  see references/installation.md for current runtime support." >&2
  exit 2
fi

# --- Dispatch ---
INSTALLER="$STAGED_DIR/packaging/install/install-claude-code.sh"
if [ ! -x "$INSTALLER" ]; then
  echo "FAIL: $INSTALLER not found or not executable in extracted tarball" >&2
  exit 1
fi
echo "Dispatching $INSTALLER --project-dir $ORIG_PWD ..."
bash "$INSTALLER" --project-dir "$ORIG_PWD"
echo "PASS: install.sh — orchestrator runtime staged into $ORIG_PWD"
