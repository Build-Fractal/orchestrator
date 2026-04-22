#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-auto-mode.sh — T02 gate: SC-7 under --re-init.
#
# Verifies the SC-7 zero-prompts invariant: when --re-init is invoked WITHOUT
# --i-am-operator and WITHOUT a TTY, the script short-circuits to the
# pending-sentinel path without firing any `gh` subprocess call.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"
INIT="${REPO_ROOT}/scripts/integrations/github-init.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

shim_dir="$(mktemp -d -t m013-p03-auto.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"

cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${SHIM_CALL_LOG:-/tmp/gh-calls.log}"
exit 0
SHIM
chmod +x "${shim_dir}/gh"

export PATH="${shim_dir}:${PATH}"
export SHIM_CALL_LOG="$call_log"

out_file="$(mktemp -t m013-p03-auto-out.XXXXXX)"
bash "$INIT" --root "${FX}/orchestrator-state" \
  --repo-slug test/test --re-init --dry-run </dev/null >"$out_file" 2>&1 || true

if grep -q 'pending-operator-complete' "$out_file"; then
  pass "fell through to pending-sentinel path"
else
  fail "did NOT short-circuit to pending-sentinel under auto-mode"
fi

if [ -s "$call_log" ]; then
  call_count="$(wc -l < "$call_log" | awk '{print $1}')"
  fail "shim logged ${call_count} gh calls (should be zero)"
else
  pass "zero gh calls under auto-mode + --re-init"
fi

rm -f "$out_file"
rm -rf "$shim_dir"

echo "SUMMARY: m013-p03-re-init-auto-mode.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-auto-mode.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-auto-mode.sh" >&2
exit 1
