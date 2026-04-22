#!/usr/bin/env bash
# scripts/verify/m013-p02-auto-mode-pending.sh
#
# Invokes scripts/integrations/github-init.sh with stdin redirected to
# /dev/null (no TTY) and NO --i-am-operator, then asserts the SC-7 contract:
#
#   1. STATUS: pending-operator-complete appears on stdout.
#   2. The sidecar .orchestrator/integrations/github.json lands in the
#      pending-sentinel shape (repo_slug: "pending").
#   3. ZERO `gh` subprocess invocations — enforced by injecting a fake `gh`
#      shim at the front of PATH that logs every call it receives; the log
#      must be empty after the init run.
#
# Bash 3.2 compatible. Exits 0 on PASS, 1 on FAIL.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT_SH="${REPO_ROOT}/scripts/integrations/github-init.sh"

fail_count=0
pass_count=0
_pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
_fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }

if [ ! -f "$INIT_SH" ]; then
  _fail "github-init.sh missing"
  echo "FAIL: m013-p02-auto-mode-pending.sh" >&2
  exit 1
fi

# Sandbox: a fresh project root with no sidecar. Copy the template only.
SANDBOX="$(mktemp -d -t m013-p02-auto.XXXXXX)"
mkdir -p "${SANDBOX}/templates"
cp "${REPO_ROOT}/templates/github-integration-sidecar.json" \
   "${SANDBOX}/templates/github-integration-sidecar.json"

# Clone the two helper scripts into the sandbox so --root <SANDBOX> does not
# reach out to the real repo for the init-pending path.
mkdir -p "${SANDBOX}/scripts/integrations"
cp "${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh" \
   "${SANDBOX}/scripts/integrations/sidecar-init-pending.sh"
cp "${REPO_ROOT}/scripts/integrations/github-common.sh" \
   "${SANDBOX}/scripts/integrations/github-common.sh"

# Install a fake `gh` at the front of PATH. Every invocation appends a line
# to GH_CALL_LOG. The script itself always exits 1 to simulate a would-be
# error — the auto-mode path must never reach this.
FAKE_BIN="${SANDBOX}/fakebin"
mkdir -p "$FAKE_BIN"
GH_CALL_LOG="${SANDBOX}/gh-calls.log"
: > "$GH_CALL_LOG"
cat > "${FAKE_BIN}/gh" <<GH_SHIM_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GH_CALL_LOG}"
exit 1
GH_SHIM_EOF
chmod +x "${FAKE_BIN}/gh"

ORIG_PATH="$PATH"
PATH="${FAKE_BIN}:${PATH}"
export PATH

# Invoke init with stdin redirected (no TTY) and no --i-am-operator.
STDOUT_FILE="${SANDBOX}/stdout.txt"
STDERR_FILE="${SANDBOX}/stderr.txt"
bash "$INIT_SH" --root "$SANDBOX" < /dev/null \
  > "$STDOUT_FILE" 2> "$STDERR_FILE"
rc=$?

PATH="$ORIG_PATH"
export PATH

# --- 1. Exit code 0 -----------------------------------------------------------
if [ "$rc" -eq 0 ]; then
  _pass "auto-mode github-init.sh exits 0"
else
  _fail "auto-mode github-init.sh exited ${rc} (expected 0); stderr: $(cat "$STDERR_FILE")"
fi

# --- 2. STATUS: pending-operator-complete on stdout --------------------------
if grep -q "^STATUS: pending-operator-complete$" "$STDOUT_FILE"; then
  _pass "auto-mode emits 'STATUS: pending-operator-complete' on stdout"
else
  _fail "auto-mode did not emit STATUS: pending-operator-complete; stdout: $(cat "$STDOUT_FILE")"
fi

# --- 3. Sidecar lands in pending-sentinel shape -------------------------------
SIDECAR="${SANDBOX}/.orchestrator/integrations/github.json"
if [ -f "$SIDECAR" ]; then
  if grep -q '"repo_slug"[[:space:]]*:[[:space:]]*"pending"' "$SIDECAR"; then
    _pass "sidecar ends up at pending-sentinel state (repo_slug=pending)"
  else
    _fail "sidecar exists but repo_slug is not 'pending'"
  fi
else
  _fail "sidecar file not written at ${SIDECAR}"
fi

# --- 4. Zero `gh` subprocess invocations --------------------------------------
gh_call_count="$(wc -l < "$GH_CALL_LOG" | awk '{print $1}')"
if [ "$gh_call_count" = "0" ]; then
  _pass "auto-mode invoked gh zero times (SC-7 strict contract)"
else
  _fail "auto-mode invoked gh ${gh_call_count} times (SC-7 violation)"
  echo "--- gh call log ---" >&2
  cat "$GH_CALL_LOG" >&2
  echo "--- end gh call log ---" >&2
fi

rm -rf "$SANDBOX"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: auto-mode (no TTY) writes pending-sentinel sidecar and exits 0 with STATUS: pending-operator-complete, zero gh subprocess calls (${pass_count}/${pass_count})"
  exit 0
fi
echo "FAIL: m013-p02-auto-mode-pending.sh (${fail_count} failures, ${pass_count} passes)" >&2
exit 1
