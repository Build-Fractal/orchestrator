#!/usr/bin/env bash
# scripts/lifecycle/after-verify-sync.sh — M013/P04 post-verify hook wrapper.
#
# Invoked by the Claude Code post_verify lifecycle event. Reads the
# GitHub integration sidecar; when sync_mode=on-transition AND the
# sidecar is populated (not pending-operator-complete), invokes
# scripts/integrations/github-sync.sh. Fail-as-warning: rc != 0 from
# sync does not block the orchestrator advance (US-5 AS-5). Returns 0
# always; emits WARN: diagnostics on stderr for the operator.
#
# Respects SC-7 (zero approval prompts): under auto-mode (no TTY +
# no --i-am-operator semantics honored), github-sync.sh short-circuits
# to pending-operator-complete without a live gh call. This wrapper
# issues no interactive prompts itself.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins, no jq.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Resolve sidecar path. ORCHESTRATOR_ROOT may be set to a test fixture
# directory (e.g. /tmp/fixture/.orchestrator); default is the repo's
# own .orchestrator/ directory.
state_root="${ORCHESTRATOR_ROOT:-${REPO_ROOT}/.orchestrator}"
sidecar="${state_root}/integrations/github.json"

# FR-11 reversibility: absent sidecar => no-op.
if [ ! -f "$sidecar" ]; then
  exit 0
fi

# Pending-operator-complete sidecars no-op (operator has not finished
# wiring the GitHub integration yet).
if grep -q '"pending-operator-complete"' "$sidecar"; then
  exit 0
fi
if grep -q '"pending"' "$sidecar"; then
  exit 0
fi

# Extract sync_mode via awk (jq-optional). Matches shape:
#   "sync_mode": "on-transition"
mode="$(awk -F'"' '/"sync_mode"[[:space:]]*:/ { for (i=1;i<=NF;i++) if ($i=="sync_mode") { print $(i+2); exit } }' "$sidecar")"
if [ "${mode:-manual}" != "on-transition" ]; then
  exit 0
fi

# Invoke sync (fail-as-warning). --i-am-operator is the operator-attested
# flag; github-sync.sh itself decides whether the current shell actually
# has a TTY / operator present and short-circuits accordingly under
# auto-mode (SC-7 guard inherited from T02).
sync_log="/tmp/m013-p04-after-verify.out"
bash "${REPO_ROOT}/scripts/integrations/github-sync.sh" --i-am-operator >"$sync_log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "WARN: github-sync exited rc=${rc} (fail-as-warning; see ${sync_log})" >&2
fi
exit 0
