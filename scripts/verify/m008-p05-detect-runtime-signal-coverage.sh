#!/usr/bin/env bash
# Verifies detect-runtime.sh probes env vars and filesystem markers for
# claude-code, codex, and cursor, and reports confidence=high when both
# env and filesystem signals match.
set -u

SCRIPT="scripts/dispatch/detect-runtime.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing"
  exit 1
fi

# Source inspection: script mentions the expected env vars and paths.
for token in "CLAUDECODE" "CURSOR" "CODEX" ".claude" ".codex" ".cursor"; do
  if ! grep -qF "$token" "$SCRIPT"; then
    echo "FAIL: $SCRIPT does not reference signal '$token'"
    exit 1
  fi
done

# Behavioral: synthesize a fixture where Claude Code env + fs markers agree.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/.claude"
out="$(HOME="$tmpdir" CLAUDECODE=1 bash "$SCRIPT" 2>/dev/null)"

if ! echo "$out" | grep -qE '^runtime=claude-code$'; then
  echo "FAIL: claude-code env+fs fixture did not yield runtime=claude-code"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

if ! echo "$out" | grep -qE '^confidence=high$'; then
  echo "FAIL: claude-code env+fs fixture did not yield confidence=high"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

echo "PASS: detect-runtime.sh signal coverage includes claude-code/codex/cursor env+fs"
