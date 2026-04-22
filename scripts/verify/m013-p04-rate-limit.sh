#!/usr/bin/env bash
# scripts/verify/m013-p04-rate-limit.sh — T03 gate: FR-16 rate-limit + auth-expiry.
#
# Covers:
#   Assertion 1: classify_gh_rc helper defined in github-common.sh
#   Assertion 2: github-sync.sh contains rate-limit rc=3 path
#   Assertion 3: github-sync.sh contains auth-expired rc=4 path
#   Assertion 4: rate-limit pre-flight → rc=3 + RATE-LIMIT retry-after diagnostic
#   Assertion 5: auth-expired pre-flight → rc=4 + AUTH-EXPIRED diagnostic
#
# AD-19: single-script-invocation. Bash 3.2. No $() in compound chains.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: classify_gh_rc defined.
if grep -qE '^classify_gh_rc\(\)' "$COMMON"; then
  pass "classify_gh_rc defined"
else
  fail "classify_gh_rc missing"
fi

# Assertion 2: rate-limit rc=3 wired in github-sync.sh.
if grep -qE 'exit 3' "$SYNC"; then
  if grep -qE 'RATE-LIMIT:' "$SYNC"; then
    pass "rate-limit rc=3 path wired"
  else
    fail "RATE-LIMIT diagnostic missing in github-sync.sh"
  fi
else
  fail "rate-limit rc=3 exit missing"
fi

# Assertion 3: auth-expired rc=4 wired in github-sync.sh.
if grep -qE 'exit 4' "$SYNC"; then
  if grep -qE 'AUTH-EXPIRED:' "$SYNC"; then
    pass "auth-expired rc=4 path wired"
  else
    fail "AUTH-EXPIRED diagnostic missing in github-sync.sh"
  fi
else
  fail "auth-expired rc=4 exit missing"
fi

# Build a 60-phase fixture that exceeds the 50-mutation threshold and will
# trigger the pre-flight probe. All phases have state:done + SUMMARY with
# verification_result: pass, so desired=done. Cached status_field_synced=false
# ⇒ projected_mutations = 60 > 50.
rl_fx="$(mktemp -d -t m013-p04-rl-fx.XXXXXX)"
mkdir -p "${rl_fx}/.orchestrator/integrations"
mkdir -p "${rl_fx}/.orchestrator/milestones/M013-RL/phases"
cat > "${rl_fx}/.orchestrator/milestones/M013-RL/M013-RL-ROADMAP.md" <<'RM'
---
schema_version: "1.0"
type: roadmap
milestone: "M013-RL"
---
## Phases
RM

sidecar="${rl_fx}/.orchestrator/integrations/github.json"
{
  echo '{'
  echo '  "schema_version":"1.0",'
  echo '  "repo_slug":"t/r",'
  echo '  "project_v2_id":"P1",'
  echo '  "sync_mode":"manual",'
  echo '  "sub_issue_mode":"native",'
  echo '  "items":{'
  sep=""
  n=1
  while [ "$n" -le 60 ]; do
    pid="P$(printf '%02d' "$n")-RL"
    mkdir -p "${rl_fx}/.orchestrator/milestones/M013-RL/phases/${pid}"
    cat > "${rl_fx}/.orchestrator/milestones/M013-RL/phases/${pid}/${pid}-PLAN.md" <<PLN
---
type: phase-plan
phase: "${pid}"
milestone: "M013-RL"
state: "done"
---
PLN
    cat > "${rl_fx}/.orchestrator/milestones/M013-RL/phases/${pid}/${pid}-SUMMARY.md" <<SUM
---
type: phase-summary
id: "${pid}"
verification_result: "pass"
---
SUM
    issue=$((n + 100))
    printf '    %s"M013-RL-%s": { "issue_number": %d, "project_v2_attached": true, "status_field_synced": false, "last_attempt_at": "2026-04-22T00:00:00Z", "last_error": null }\n' \
      "${sep}" "${pid}" "${issue}"
    sep=","
    n=$((n + 1))
  done
  echo '  }'
  echo '}'
} > "$sidecar"

# Shim gh so no real network is ever hit in this gate.
shim_dir="$(mktemp -d -t m013-p04-rl-shim.XXXXXX)"
cat > "${shim_dir}/gh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "${shim_dir}/gh"

# Assertion 4: rate-limit pre-flight → rc=3.
rl_stub_dir="$(mktemp -d -t m013-p04-rl-stub.XXXXXX)"
cat > "${rl_stub_dir}/http-probe-rate_limit.txt" <<'RL'
HTTP/2 403
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 2026-04-22T23:00:00Z

{"message":"API rate limit exceeded"}
RL

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${rl_stub_dir}" \
  bash "$SYNC" --root "$rl_fx" --i-am-operator --repo-slug t/r \
  </dev/null >/tmp/t03-rl.out 2>/tmp/t03-rl.err
rc=$?
if [ "$rc" -eq 3 ]; then
  pass "rc=3 on rate-limit pre-flight"
else
  fail "expected rc=3 on rate-limit pre-flight, got rc=${rc}"
fi
if grep -q 'RATE-LIMIT: retry-after=' /tmp/t03-rl.err; then
  pass "RATE-LIMIT retry-after diagnostic emitted"
else
  fail "RATE-LIMIT retry-after diagnostic missing"
fi

# Assertion 5: auth-expired pre-flight → rc=4.
ae_stub_dir="$(mktemp -d -t m013-p04-ae-stub.XXXXXX)"
cat > "${ae_stub_dir}/http-probe-rate_limit.txt" <<'AE'
HTTP/2 401
X-RateLimit-Remaining: 4500
X-RateLimit-Reset: 0

{"message":"Bad credentials"}
AE

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${ae_stub_dir}" \
  bash "$SYNC" --root "$rl_fx" --i-am-operator --repo-slug t/r \
  </dev/null >/tmp/t03-ae.out 2>/tmp/t03-ae.err
rc=$?
if [ "$rc" -eq 4 ]; then
  pass "rc=4 on auth-expired pre-flight"
else
  fail "expected rc=4 on auth-expired pre-flight, got rc=${rc}"
fi
if grep -q 'AUTH-EXPIRED: run gh auth refresh' /tmp/t03-ae.err; then
  pass "AUTH-EXPIRED diagnostic emitted"
else
  fail "AUTH-EXPIRED diagnostic missing"
fi

rm -rf "$rl_fx" "$shim_dir" "$rl_stub_dir" "$ae_stub_dir"
rm -f /tmp/t03-rl.out /tmp/t03-rl.err /tmp/t03-ae.out /tmp/t03-ae.err

echo "SUMMARY: m013-p04-rate-limit.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-rate-limit.sh"
  exit 0
fi
echo "FAIL: m013-p04-rate-limit.sh" >&2
exit 1
