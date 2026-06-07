#!/usr/bin/env bash
# tools/verify/m034-p03-registration.sh — M034 P03 T02 hermetic verifier.
#
# Asserts FR-10 / CON-6 / D-P03-4 for merge-mcp-config.sh and the install
# wiring:
#   1. create     — merge into an absent target creates only our entry.
#   2. preserve    — an operator entry survives the merge byte-intact.
#   3. idempotent  — a second merge leaves exactly one orchestrator entry.
#   4. fail-closed — a malformed target -> exit 2 + file unchanged.
#   5. wiring      — install-cursor.sh references merge-mcp-config.sh and
#                    cursor.sh references mcp-config.
#
# Prints `PASS: m034-p03 registration` / `FAIL: m034-p03 registration — <reason>`.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MERGE="$REPO_ROOT/scripts/lifecycle/merge-mcp-config.sh"
INSTALL="$REPO_ROOT/packaging/install/install-cursor.sh"
CURSOR_ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/cursor.sh"

NAME="orchestrator-review-gate"
ENTRY='{"command":"bash","args":["/x/scripts/lifecycle/review-gate-mcp-server.sh"]}'

fail() {
  echo "FAIL: m034-p03 registration — $1" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  fail "jq not on PATH"
fi
[ -x "$MERGE" ] || fail "merge-mcp-config.sh missing or not executable"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m034-p03-reg.XXXXXX")" || fail "mktemp failed"
trap 'rm -rf "$SCRATCH"' EXIT

# --- 1. create — absent target -> our entry only ---
TARGET1="$SCRATCH/c1/.cursor/mcp.json"
if ! bash "$MERGE" --target "$TARGET1" --name "$NAME" --entry "$ENTRY" >/dev/null 2>&1; then
  fail "create: merge into absent target exited non-zero"
fi
[ -f "$TARGET1" ] || fail "create: target file not created"
if ! jq -e ".mcpServers[\"$NAME\"].command == \"bash\"" "$TARGET1" >/dev/null 2>&1; then
  fail "create: orchestrator entry not present after create"
fi
keys1="$(jq '.mcpServers | keys | length' "$TARGET1")"
[ "$keys1" = "1" ] || fail "create: expected exactly 1 mcpServers key, got $keys1"

# --- 2. preserve — operator entry survives ---
TARGET2="$SCRATCH/c2/.cursor/mcp.json"
mkdir -p "$(dirname "$TARGET2")"
printf '%s\n' '{"mcpServers":{"operator-thing":{"command":"x"}}}' > "$TARGET2"
if ! bash "$MERGE" --target "$TARGET2" --name "$NAME" --entry "$ENTRY" >/dev/null 2>&1; then
  fail "preserve: merge into existing target exited non-zero"
fi
if ! jq -e '.mcpServers["operator-thing"].command == "x"' "$TARGET2" >/dev/null 2>&1; then
  fail "preserve: operator entry not preserved"
fi
if ! jq -e ".mcpServers[\"$NAME\"].command == \"bash\"" "$TARGET2" >/dev/null 2>&1; then
  fail "preserve: orchestrator entry not added"
fi

# --- 3. idempotent — second merge -> exactly one orchestrator entry ---
if ! bash "$MERGE" --target "$TARGET2" --name "$NAME" --entry "$ENTRY" >/dev/null 2>&1; then
  fail "idempotent: second merge exited non-zero"
fi
keys2="$(jq '.mcpServers | keys | length' "$TARGET2")"
[ "$keys2" = "2" ] || fail "idempotent: expected 2 mcpServers keys (operator + ours), got $keys2"
orch_count="$(jq "[.mcpServers | keys[] | select(. == \"$NAME\")] | length" "$TARGET2")"
[ "$orch_count" = "1" ] || fail "idempotent: expected exactly 1 orchestrator entry, got $orch_count"

# --- 4. fail-closed — malformed target -> exit 2, file unchanged ---
TARGET3="$SCRATCH/c3/.cursor/mcp.json"
mkdir -p "$(dirname "$TARGET3")"
printf '%s' '{not json' > "$TARGET3"
before="$(cat "$TARGET3")"
bash "$MERGE" --target "$TARGET3" --name "$NAME" --entry "$ENTRY" >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] || fail "fail-closed: expected exit 2 on malformed target, got $rc"
after="$(cat "$TARGET3")"
[ "$before" = "$after" ] || fail "fail-closed: malformed target was modified"

# --- 5. wiring — install path references the helper + adapter mode ---
grep -q "merge-mcp-config.sh" "$INSTALL" || fail "wiring: install-cursor.sh does not reference merge-mcp-config.sh"
grep -q "mcp-config" "$CURSOR_ADAPTER" || fail "wiring: cursor.sh does not reference mcp-config"

echo "PASS: m034-p03 registration"
exit 0
