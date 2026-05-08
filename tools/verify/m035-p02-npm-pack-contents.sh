#!/usr/bin/env bash
# tools/verify/m035-p02-npm-pack-contents.sh
# Runs `npm pack` and asserts the staged tarball contents conform to
# the M035 P02 T05 bundle-hygiene contract:
#   - INCLUDE: bin/orchestrator, package.json,
#     packaging/install/install-claude-code.sh,
#     packaging/npm/postinstall.sh, commands/, scripts/, templates/,
#     references/.
#   - EXCLUDE: .orchestrator/, specs/, tests/, tools/, docs/, wiki/,
#     .git/, .github/, .planning/, node_modules/.
#   - EXCLUDE: m[0-9]*-p[0-9]*-* dogfood verifiers under scripts/verify/.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

if ! command -v npm >/dev/null 2>&1; then
    echo "SKIP: npm not on PATH — npm-pack-contents check deferred to CI"
    echo "BATTERY: pass=0 fail=0 skip=1"
    exit 0
fi

FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t05)"
trap 'rm -rf "$FIXTURE" 2>/dev/null || true' EXIT

# npm pack is invoked via a single command (no compound chain). cd is a
# subshell to keep CWD stable for the caller.
( cd "$REPO" && npm pack --pack-destination "$FIXTURE" \
    >"$FIXTURE/pack.log" 2>&1 ) || {
    echo "FAIL: npm pack failed (see $FIXTURE/pack.log)"
    exit 1
}

# The tarball name follows npm's scoped-package convention:
#   @build-fractal/orchestrator -> build-fractal-orchestrator-<v>.tgz
TARBALL="$(find "$FIXTURE" -maxdepth 1 -name 'build-fractal-orchestrator-*.tgz' \
    -type f | head -1)"
if [ -z "$TARBALL" ]; then
    echo "FAIL: npm pack produced no matching tarball"
    exit 1
fi

PROBE="$FIXTURE/extracted"
mkdir -p "$PROBE"
tar -xzf "$TARBALL" -C "$PROBE"
PKG_ROOT="$PROBE/package"
if [ ! -d "$PKG_ROOT" ]; then
    echo "FAIL: tarball lacks expected package/ root"
    exit 1
fi

pass=0
fail=0

check_present() {
    local rel="$1"
    if [ -e "$PKG_ROOT/$rel" ]; then
        echo "PASS: tarball INCLUDES $rel"
        pass=$((pass + 1))
    else
        echo "FAIL: tarball MISSING $rel"
        fail=$((fail + 1))
    fi
}

check_absent() {
    local rel="$1"
    if [ ! -e "$PKG_ROOT/$rel" ]; then
        echo "PASS: tarball EXCLUDES $rel"
        pass=$((pass + 1))
    else
        echo "FAIL: tarball UNEXPECTEDLY INCLUDES $rel"
        fail=$((fail + 1))
    fi
}

# Required-present surfaces:
check_present "package.json"
check_present "bin/orchestrator"
check_present "packaging/install/install-claude-code.sh"
check_present "packaging/npm/postinstall.sh"
check_present "commands"
check_present "scripts"
check_present "templates"
check_present "references"

# Required-absent surfaces (whole-dir exclusion via files: whitelist):
check_absent ".orchestrator"
check_absent "specs"
check_absent "tests"
check_absent "tools"
check_absent "docs"
check_absent "wiki"
check_absent ".git"
check_absent ".github"
check_absent ".planning"
check_absent "node_modules"

# Bundle-hygiene rule 1: no m[0-9]*-p[0-9]*-* files under scripts/verify/
# inside the tarball (tools/verify/ is whole-dir excluded above).
if [ -d "$PKG_ROOT/scripts/verify" ]; then
    COUNT=$(find "$PKG_ROOT/scripts/verify" -type f -name 'm[0-9]*-p[0-9]*-*' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" = "0" ]; then
        echo "PASS: tarball scripts/verify/ has no m[0-9]*-p[0-9]*-* dogfood verifiers"
        pass=$((pass + 1))
    else
        echo "FAIL: tarball scripts/verify/ contains $COUNT dogfood verifiers"
        fail=$((fail + 1))
    fi
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
