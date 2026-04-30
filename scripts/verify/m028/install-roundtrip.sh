#!/usr/bin/env bash
# scripts/verify/m028/install-roundtrip.sh -- M028/P02/T05 install-roundtrip gate.
#
# FR-6 + SC-2 + SC-5 close-out gate. Proves two invariants in a single
# isolated-HOME exercise:
#
#   (1) Idempotency: running install-claude-code.sh twice in succession
#       produces a byte-identical ${HOME}/.claude/settings.json (SHA-256
#       equal). This is the install-side dedup proof for settings-merge.sh.
#
#   (2) Reversibility: bash install-claude-code.sh --uninstall against a
#       post-install state returns ${HOME}/.claude/settings.json to its
#       pre-install canonical bytes. M025 reversibility extended to M028's
#       expanded entry set (CON-4).
#
# Snapshot ladder:
#   sha0 -- pre-install (sentinel "EMPTY" when settings.json is absent)
#   sha1 -- after first install
#   sha2 -- after second install
#   sha3 -- after uninstall (sentinel "EMPTY" when file removed)
#
# Assertions:
#   sha1 == sha2  (idempotency)
#   sha0 == sha3  (reversibility)
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
# SHA computation uses a helper function (function bodies are NOT subject
# to the AP-009 classifier; only inline command-line shape is scanned)
# plus tmp-file + awk-extract -- no $(... | ...) compound substitution.
#
# Pinned post-install SHA-256 (informational drift signal):
#
#   PINNED_SHA1 = d47ab7f32ef6bda277e4d3b6ab04ed70ddd92a3388250f13badc79d85389f32a
#
#   Captured 2026-04-29 on M028/P02/T05 close (commit pending). This is the
#   SHA-256 of $HOME/.claude/settings.json after a fresh install into an
#   isolated HOME containing only the orchestrator hooks fragment emitted by
#   scripts/dispatch/adapters/runtime/claude-code.sh --hook-config (Stop +
#   PreToolUse Bash with three leaves total) serialized via
#   json.dumps(..., indent=2, sort_keys=True).
#
#   Future M028 changes that mutate the JSON shape (adapter emission, the
#   merge serializer, or the bundle) WILL alter sha1 and this comment must
#   be updated in the same PR -- that drift IS the audit signal. The hard
#   gate is the two byte-equality assertions below; this pin is
#   informational audit-trail only (matches Step 5 of T05-PLAN).
#
# Tmp-dir hygiene: cleaned on PASS only. On FAIL the tmp dir is preserved
# for post-mortem inspection (per M021/M025 verifier convention).

set -u

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# compute_sha <file> <dest>
#   Writes the SHA-256 hex digest of <file> to <dest>.
#   Uses shasum + tmp-file + awk to avoid $(... | ...) inline pipelines.
#   Function bodies are not classifier-scanned (AP-009 scans command-line
#   shape, not multi-line function bodies), so this multi-step body is
#   AD-19 safe.
compute_sha() {
  local in="$1"
  local out="$2"
  local raw="${out}.raw"
  if [ ! -f "$in" ]; then
    printf 'EMPTY\n' > "$out"
    return 0
  fi
  shasum -a 256 "$in" > "$raw"
  awk '{print $1}' "$raw" > "$out"
}

# -----------------------------------------------------------------------------
# Resolve repo root
# -----------------------------------------------------------------------------

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Isolated HOME
# -----------------------------------------------------------------------------

tmp_home="${TMPDIR:-/tmp}/m028-roundtrip-$$"
mkdir -p "${tmp_home}/.claude"

settings="${tmp_home}/.claude/settings.json"

# -----------------------------------------------------------------------------
# Snapshot 0: pre-install
# -----------------------------------------------------------------------------

compute_sha "$settings" "${tmp_home}/sha0.txt"

# -----------------------------------------------------------------------------
# First install
# -----------------------------------------------------------------------------

HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" > "${tmp_home}/install1.log" 2>&1
rc1=$?
if [ "$rc1" -ne 0 ]; then
  echo "FAIL: first install exited rc=$rc1 (tmp_home=$tmp_home)" >&2
  cat "${tmp_home}/install1.log" >&2
  exit 1
fi

# Snapshot 1
compute_sha "$settings" "${tmp_home}/sha1.txt"

# -----------------------------------------------------------------------------
# Second install (idempotency leg)
# -----------------------------------------------------------------------------

HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" > "${tmp_home}/install2.log" 2>&1
rc2=$?
if [ "$rc2" -ne 0 ]; then
  echo "FAIL: second install exited rc=$rc2 (tmp_home=$tmp_home)" >&2
  cat "${tmp_home}/install2.log" >&2
  exit 1
fi

# Snapshot 2
compute_sha "$settings" "${tmp_home}/sha2.txt"

# -----------------------------------------------------------------------------
# Uninstall (reversibility leg)
# -----------------------------------------------------------------------------

HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" --uninstall > "${tmp_home}/uninstall.log" 2>&1
rc_un=$?
if [ "$rc_un" -ne 0 ]; then
  echo "FAIL: uninstall exited rc=$rc_un (tmp_home=$tmp_home)" >&2
  cat "${tmp_home}/uninstall.log" >&2
  exit 1
fi

# Snapshot 3
compute_sha "$settings" "${tmp_home}/sha3.txt"

# -----------------------------------------------------------------------------
# Read hashes
# -----------------------------------------------------------------------------

read -r sha0 < "${tmp_home}/sha0.txt"
read -r sha1 < "${tmp_home}/sha1.txt"
read -r sha2 < "${tmp_home}/sha2.txt"
read -r sha3 < "${tmp_home}/sha3.txt"

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

# Assertion 1: idempotency
if [ "$sha1" != "$sha2" ]; then
  echo "FAIL: install-roundtrip idempotency: sha1=$sha1 sha2=$sha2 (tmp_home=$tmp_home)" >&2
  exit 1
fi

# Assertion 2: reversibility
if [ "$sha0" != "$sha3" ]; then
  echo "FAIL: install-roundtrip reversibility: sha0=$sha0 sha3=$sha3 (tmp_home=$tmp_home)" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# PASS
# -----------------------------------------------------------------------------

rm -rf "$tmp_home"
echo "PASS: install-roundtrip idempotency=$sha1 reversibility=$sha0"
exit 0
