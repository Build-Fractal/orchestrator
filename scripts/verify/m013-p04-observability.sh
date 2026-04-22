#!/usr/bin/env bash
# scripts/verify/m013-p04-observability.sh — T03 gate: FR-17 observability emitters.
#
# Covers:
#   1. emit_tier1_record defined in github-common.sh
#   2. emit_conversus_gate_record defined in github-common.sh
#   3. github-sync.sh invokes emit_tier1_record with the unit_close event
#   4. --dry-run path writes zero JSONL records
#   5. live path writes at least one JSONL record
#   6. every JSONL line conforms to the M019 Tier 1 shape
#   7. at least one unit_close record present
#   8. FR-5 lint still green
#
# AD-19: single-script-invocation. Bash 3.2.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# 1. emit_tier1_record defined.
if grep -qE '^emit_tier1_record\(\)' "$COMMON"; then
  pass "emit_tier1_record defined"
else
  fail "emit_tier1_record missing"
fi

# 2. emit_conversus_gate_record defined.
if grep -qE '^emit_conversus_gate_record\(\)' "$COMMON"; then
  pass "emit_conversus_gate_record defined"
else
  fail "emit_conversus_gate_record missing"
fi

# 3. unit_close emitter wired in github-sync.sh.
if grep -qE 'emit_tier1_record unit_close' "$SYNC"; then
  pass "unit_close emitter wired"
else
  fail "unit_close emitter missing in github-sync.sh"
fi

# Shim gh so no real network is hit.
shim_dir="$(mktemp -d -t m013-p04-obs-shim.XXXXXX)"
cat > "${shim_dir}/gh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "${shim_dir}/gh"

# 4. --dry-run emits zero JSONL.
# github-sync.sh reassigns ORCHESTRATOR_ROOT from --root ("$root/.orchestrator"),
# so the JSONL (if any were emitted) would land in the fixture-copy root. We
# copy the fixture to a tmp so a dry-run pollution attempt never touches the
# repo fixture tree.
dry_work="$(mktemp -d -t m013-p04-obs-dry.XXXXXX)"
cp -R "${FX}/orchestrator-state/." "${dry_work}/"
: > "${dry_work}/.orchestrator/execution-log.jsonl"

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${FX}/gh-stub-responses" \
  bash "$SYNC" --root "${dry_work}" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run \
  </dev/null >/dev/null 2>&1 || true

if [ ! -s "${dry_work}/.orchestrator/execution-log.jsonl" ]; then
  pass "dry-run wrote zero JSONL records"
else
  fail "dry-run emitted JSONL (should not)"
fi

# 5. live mode writes JSONL records. We copy the fixture orchestrator-state
# so the live pass can mutate the sidecar without polluting the repo fixture.
# github-sync.sh derives ORCHESTRATOR_ROOT from --root ("$root/.orchestrator"),
# so the execution-log.jsonl lands at "${live_work}/.orchestrator/".
live_work="$(mktemp -d -t m013-p04-obs-live.XXXXXX)"
cp -R "${FX}/orchestrator-state/." "${live_work}/"
: > "${live_work}/.orchestrator/execution-log.jsonl"

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${FX}/gh-stub-responses" \
  bash "$SYNC" --root "${live_work}" --i-am-operator \
  --repo-slug test/sync-fixture \
  </dev/null >/dev/null 2>&1 || true

jsonl="${live_work}/.orchestrator/execution-log.jsonl"
if [ -s "$jsonl" ]; then
  pass "live mode wrote JSONL"
else
  fail "live mode wrote no JSONL"
fi

# 6. every JSONL line conforms to the M019 Tier 1 shape.
bad=0
while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  case "$line" in
    '{"ts":"'*'","event":"unit_close","source":"runtime"'*'}') : ;;
    '{"ts":"'*'","event":"conversus_gate_invocation","source":"runtime"'*'}') : ;;
    *) bad=$((bad + 1)) ;;
  esac
done < "$jsonl"
if [ "$bad" -eq 0 ]; then
  pass "every JSONL line M019 Tier 1 shape"
else
  fail "${bad} JSONL lines off-shape"
fi

# 7. at least one unit_close record present.
if grep -qE '"event":"unit_close"' "$jsonl"; then
  pass "at least one unit_close record"
else
  fail "no unit_close records"
fi

# 8. FR-5 lint still green.
if bash "${REPO_ROOT}/scripts/verify/graphql-call-shape.sh" >/dev/null 2>&1; then
  pass "FR-5 lint still green"
else
  fail "FR-5 lint REGRESSION"
fi

rm -rf "$shim_dir" "$dry_work" "$live_work"

echo "SUMMARY: m013-p04-observability.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-observability.sh"
  exit 0
fi
echo "FAIL: m013-p04-observability.sh" >&2
exit 1
