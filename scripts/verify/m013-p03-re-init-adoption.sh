#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-adoption.sh — T02 gate: re-init adoption branch.
#
# Invokes github-init.sh --re-init --dry-run against the T01 fixture with
# M013_GH_STUB_DIR set; asserts:
#   - manifest contains at least one adopt row
#   - footer has adopted=<N> field
#   - ZERO `gh create` calls (PATH-shim a fake gh that blocks creates)
#   - >=3 adopt rows
#   - --re-init documented in --help
#   - P02 fixture byte-identity still holds (regression guard)

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"
INIT="${REPO_ROOT}/scripts/integrations/github-init.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# PATH-shim a fake gh that logs calls and blocks any `create` invocation.
shim_dir="$(mktemp -d -t m013-p03-gh-shim.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"

cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
log="${SHIM_CALL_LOG:-/tmp/m013-p03-gh-calls.log}"
printf 'gh %s\n' "$*" >> "$log"
for arg in "$@"; do
  case "$arg" in
    create) echo "FAKE-GH: create invocation BLOCKED" >&2; exit 99 ;;
  esac
done
# Pass through other read calls with empty/zero output; the re-init path
# reads stub files directly via M013_GH_STUB_DIR, so these are typically
# not invoked in the dry-run gate path.
exit 0
SHIM
chmod +x "${shim_dir}/gh"

export PATH="${shim_dir}:${PATH}"
export SHIM_CALL_LOG="$call_log"
export M013_GH_STUB_DIR="${FX}/gh-stub-responses"

out_file="$(mktemp -t m013-p03-readopt.XXXXXX)"
bash "$INIT" --root "${FX}/orchestrator-state" \
  --repo-slug test/test --i-am-operator --re-init --dry-run \
  >"$out_file" 2>/dev/null || true

# Assertion 1: manifest contains at least one adopt row.
if grep -qE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ adopt$' "$out_file"; then
  pass "manifest contains adopt rows"
else
  fail "no adopt rows in manifest"
fi

# Assertion 2: footer has adopted=<N> field.
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+ adopted=[0-9]+$' "$out_file"; then
  pass "footer has adopted= field"
else
  fail "footer missing adopted= field"
fi

# Assertion 3: zero `create` calls logged by the shim.
if grep -q ' create' "$call_log"; then
  fail "shim logged 'create' calls (should be zero in adopt path)"
else
  pass "zero create calls issued"
fi

# Assertion 4: >=3 adopt rows.
adopt_count="$(grep -cE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ adopt$' "$out_file" 2>/dev/null || echo 0)"
if [ "${adopt_count:-0}" -ge 3 ]; then
  pass ">=3 adopt rows (got ${adopt_count})"
else
  fail "expected >=3 adopt rows, got ${adopt_count:-0}"
fi

# Assertion 5: --re-init is documented in the help output.
help_out="$(bash "$INIT" --help 2>/dev/null || true)"
if printf '%s\n' "$help_out" | grep -q -- '--re-init'; then
  pass "--re-init in help"
else
  fail "--re-init missing from help"
fi

# Assertion 6: P02 fixture byte-identity preserved (regression guard).
if bash "${REPO_ROOT}/scripts/verify/m013-p02-github-init-fixture.sh" >/dev/null 2>&1; then
  pass "P02 fixture byte-identity preserved"
else
  fail "P02 fixture byte-identity REGRESSION"
fi

rm -f "$out_file"
rm -rf "$shim_dir"

echo "SUMMARY: m013-p03-re-init-adoption.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-adoption.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-adoption.sh" >&2
exit 1
