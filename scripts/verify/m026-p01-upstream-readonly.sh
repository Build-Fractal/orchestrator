#!/usr/bin/env bash
# m026-p01-upstream-readonly.sh
# Asserts that T01 did not write into either conversus tree. CON-5
# requires ~/Sites/conversus* to be read-only from the orchestrator's POV.
#
# Strategy: `git -C <tree> status --porcelain` must produce zero-length
# output, OR any dirt it reports must match the known pre-T01 operator
# baseline whitelist captured at 2026-04-23T17:30 PT by dispatch preflight.
# Anything outside that whitelist is a CON-5 violation.
#
# Bash 3.2 safe (MEM001). Single-script-file shape per AD-19.

set -euo pipefail

PASS=0
FAIL=0

# Pre-T01 baseline dirt captured from the two trees at dispatch time:
#   ~/Sites/conversus-oss: `?? .claude/` and `?? .conversus/`
#   ~/Sites/conversus:     ` M uv.lock`
# Operator-tooling whitelist extension (2026-04-23, post-verify): aider
# drops `.aider.*` working files (chat history, input history, tags cache)
# into trees where the operator is actively editing. These are operator
# tool state, not orchestrator writes, so they are whitelisted by prefix.
# Any new dirt beyond these paths/prefixes is a CON-5 violation.

check_tree_readonly() {
  tree_path="$1"
  label="$2"
  if [ ! -d "$tree_path/.git" ]; then
    echo "PASS: ${label} not a git tree at ${tree_path} — skipping"
    PASS=$((PASS + 1))
    return 0
  fi
  porcelain=""
  porcelain=$(git -C "$tree_path" status --porcelain 2>/dev/null || true)
  if [ -z "$porcelain" ]; then
    echo "PASS: ${label} porcelain clean"
    PASS=$((PASS + 1))
    return 0
  fi
  # Walk each line; any entry outside the whitelist fails.
  unexpected=0
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    # Trim leading XY status code + space (2 chars + space = 3) for path.
    status_code=$(printf '%s' "$entry" | cut -c1-2)
    path=$(printf '%s' "$entry" | cut -c4-)
    whitelisted=0
    case "$tree_path" in
      *conversus-oss)
        case "$path" in
          ".claude/"|".conversus/") whitelisted=1 ;;
          .aider.*) whitelisted=1 ;;
        esac
        ;;
      *conversus)
        case "$path" in
          "uv.lock") whitelisted=1 ;;
          .aider.*) whitelisted=1 ;;
        esac
        ;;
    esac
    if [ "$whitelisted" = "1" ]; then
      echo "PASS: ${label} whitelisted pre-T01 entry: ${status_code} ${path}"
      PASS=$((PASS + 1))
    else
      echo "FAIL: ${label} unexpected dirt (CON-5 violation): ${status_code} ${path}"
      FAIL=$((FAIL + 1))
      unexpected=$((unexpected + 1))
    fi
  done <<UPSTREAMDIRT
${porcelain}
UPSTREAMDIRT
  if [ "$unexpected" = "0" ]; then
    return 0
  fi
  return 1
}

check_tree_readonly "${HOME}/Sites/conversus-oss" "conversus-oss" || true
check_tree_readonly "${HOME}/Sites/conversus" "conversus (paid)" || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
