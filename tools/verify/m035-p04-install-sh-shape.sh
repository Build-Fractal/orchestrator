#!/usr/bin/env bash
# tools/verify/m035-p04-install-sh-shape.sh
#
# M035 P04 T01 task-grain verifier. Asserts packaging/install/install.sh
# shape:
#   * file exists, executable
#   * shebang is bash
#   * declares M035_P04_LOCAL_TARBALL test-mode hook
#   * declares M035_P04_STAGE_ONLY test-mode hook
#   * declares M035_P04_STAGE_DIR test-mode hook
#   * references Build-Fractal/orchestrator (D009)
#   * references the canonical latest/download URL (D009)
#   * uses tar -xzf for extraction
#   * dispatches into install-claude-code.sh
#   * checks for ~/.claude (CC-only runtime detection)
#   * uses shasum -a 256 -c for SHA verification
#   * has --version / --help banner emitting D-RN-3 cohort prefix string
# Plus the D009 row in .orchestrator/DECISIONS.md is grep-asserted.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALL_SH="$REPO_ROOT/packaging/install/install.sh"
DECISIONS="$REPO_ROOT/.orchestrator/DECISIONS.md"

pass=0
fail=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    fail=$((fail + 1))
  fi
}

# 1. File exists and is executable.
if [ -x "$INSTALL_SH" ]; then check "install.sh exists + executable" 0; else check "install.sh exists + executable" 1; fi

# 2. Shebang is bash.
if [ -f "$INSTALL_SH" ] && head -1 "$INSTALL_SH" | grep -q 'bash'; then check "shebang is bash" 0; else check "shebang is bash" 1; fi

# 3. Declares M035_P04_LOCAL_TARBALL hook.
if grep -q 'M035_P04_LOCAL_TARBALL' "$INSTALL_SH"; then check "M035_P04_LOCAL_TARBALL hook" 0; else check "M035_P04_LOCAL_TARBALL hook" 1; fi

# 4. Declares M035_P04_STAGE_ONLY hook.
if grep -q 'M035_P04_STAGE_ONLY' "$INSTALL_SH"; then check "M035_P04_STAGE_ONLY hook" 0; else check "M035_P04_STAGE_ONLY hook" 1; fi

# 5. Declares M035_P04_STAGE_DIR hook.
if grep -q 'M035_P04_STAGE_DIR' "$INSTALL_SH"; then check "M035_P04_STAGE_DIR hook" 0; else check "M035_P04_STAGE_DIR hook" 1; fi

# 6. References Build-Fractal/orchestrator (D009).
if grep -q 'Build-Fractal/orchestrator' "$INSTALL_SH"; then check "Build-Fractal/orchestrator reference" 0; else check "Build-Fractal/orchestrator reference" 1; fi

# 7. References the canonical latest/download URL (D009).
if grep -F 'releases/latest/download/install.sh' "$INSTALL_SH" >/dev/null; then check "latest/download URL" 0; else check "latest/download URL" 1; fi

# 8. Uses tar -xzf for extraction.
if grep -qE 'tar[[:space:]]+-xzf' "$INSTALL_SH"; then check "tar -xzf extraction" 0; else check "tar -xzf extraction" 1; fi

# 9. Dispatches into install-claude-code.sh.
if grep -q 'install-claude-code.sh' "$INSTALL_SH"; then check "install-claude-code.sh dispatch" 0; else check "install-claude-code.sh dispatch" 1; fi

# 10. Checks for ~/.claude (CC-only runtime detection).
if grep -qE '\$HOME/\.claude|~/\.claude' "$INSTALL_SH"; then check "~/.claude runtime detection" 0; else check "~/.claude runtime detection" 1; fi

# 11. Uses shasum -a 256 -c for SHA verification.
if grep -F 'shasum -a 256 -c' "$INSTALL_SH" >/dev/null; then check "shasum -a 256 -c verification" 0; else check "shasum -a 256 -c verification" 1; fi

# 12. --version / --help banner emits orchestrator:<cmd> cohort prefix string (D-RN-3).
if grep -F 'orchestrator:' "$INSTALL_SH" >/dev/null; then check "orchestrator:<cmd> cohort prefix in banner" 0; else check "orchestrator:<cmd> cohort prefix in banner" 1; fi

# 13. D009 row recorded in .orchestrator/DECISIONS.md.
if grep -qE '^### D009 ' "$DECISIONS"; then check "D009 row in DECISIONS.md" 0; else check "D009 row in DECISIONS.md" 1; fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
