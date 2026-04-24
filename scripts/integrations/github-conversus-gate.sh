#!/usr/bin/env bash
# scripts/integrations/github-conversus-gate.sh — M013/P04/T05 UAT PR gate.
#
# Invokes the M011/P07 conversus adapter at
# scripts/dispatch/adapters/tool/conversus.sh with --strict, parses the
# verdict, posts it as an Issue/PR comment, appends a
# conversus_gate_invocation JSONL record to .orchestrator/execution-log.jsonl,
# and exits with the adapter's exit code verbatim.
#
# Contracts:
#   FR-13: pre-merge gate for UAT-defect-closing PRs
#   D007:  strict-mode adapter invocation — adapter absence is a hard FAIL
#   XII:   30s default timeout (operator may override up to Constitution XII max)
#   SC-7:  auto-mode short-circuit (no tty + no --i-am-operator → no-op exit 0)
#   FR-17: emits conversus_gate_invocation Tier 1 record (source:"runtime")
#   FR-5:  no GraphQL mutations — gh issue comment is REST
#   FR-12: gate script is runtime-agnostic (Claude-Code-only applies to hook)
#
# Bash 3.2 compatible; jq-optional.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
. "${REPO_ROOT}/scripts/integrations/github-common.sh"

ISSUE_REF=""
ARTIFACT=""
TIMEOUT=30
PRESET="m013-uat-defect-merge"
OPERATOR=0

usage() {
  cat <<'EOF'
Usage: github-conversus-gate.sh --issue-ref <repo>#<num> --artifact <path>
                                [--timeout <sec>] [--preset <name>]
                                [--i-am-operator]
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --issue-ref) ISSUE_REF="${2:-}"; shift 2 ;;
    --artifact)  ARTIFACT="${2:-}"; shift 2 ;;
    --timeout)   TIMEOUT="${2:-30}"; shift 2 ;;
    --preset)    PRESET="${2:-m013-uat-defect-merge}"; shift 2 ;;
    --i-am-operator) OPERATOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) shift ;;
  esac
done

if [ -z "$ISSUE_REF" ] || [ -z "$ARTIFACT" ]; then
  echo "FAIL: --issue-ref and --artifact are required" >&2
  usage >&2
  exit 1
fi

# SC-7 auto-mode short-circuit: no tty on stdin + operator not self-identified.
if [ ! -t 0 ] && [ "$OPERATOR" -eq 0 ]; then
  echo "STATUS: gate-deferred"
  echo "MESSAGE: conversus gate requires --i-am-operator in non-interactive mode"
  exit 0
fi

ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: conversus adapter not found at ${ADAPTER}" >&2
  exit 1
fi

tmp_out="$(mktemp -t m013-p04-gate.XXXXXX)"
tmp_err="$(mktemp -t m013-p04-gate-err.XXXXXX)"

# Millisecond wall clock (jq-optional; python fallback; zero floor).
_now_ms() {
  local _ms
  _ms="$(date +%s%3N 2>/dev/null)"
  case "$_ms" in
    ''|*N*) ;;
    *) echo "$_ms"; return 0 ;;
  esac
  _ms="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null)"
  if [ -n "$_ms" ]; then echo "$_ms"; return 0; fi
  _ms="$(python -c 'import time; print(int(time.time()*1000))' 2>/dev/null)"
  if [ -n "$_ms" ]; then echo "$_ms"; return 0; fi
  echo 0
}

start_ms="$(_now_ms)"

# ----------------------------------------------------------------------------
# Watchdog wrapper (belt-and-suspenders alongside adapter internal timeout).
# kill -TERM after $TIMEOUT seconds; kill -KILL after $TIMEOUT+1 seconds.
# ----------------------------------------------------------------------------
bash "$ADAPTER" gate --strict "$PRESET" "$ARTIFACT" "$tmp_out" >/dev/null 2>"$tmp_err" &
gate_pid=$!

(
  sleep "$TIMEOUT"
  kill -TERM "$gate_pid" 2>/dev/null
  sleep 1
  kill -KILL "$gate_pid" 2>/dev/null
) &
wd_pid=$!

wait "$gate_pid" 2>/dev/null
rc=$?

# Watchdog cleanup: kill the watchdog subshell + its sleeps.
kill "$wd_pid" 2>/dev/null
wait "$wd_pid" 2>/dev/null || true

end_ms="$(_now_ms)"
duration_ms=$((end_ms - start_ms))
[ "$duration_ms" -lt 0 ] && duration_ms=0

# ----------------------------------------------------------------------------
# Parse verdict. Adapter contract: rc=0 PASS, rc=2 BLOCK, rc=1 error/strict-miss.
# ----------------------------------------------------------------------------
verdict="ERROR"
case "$rc" in
  0)
    verdict="$(bash "$ADAPTER" parse-verdict "$tmp_out" 2>/dev/null | awk -F= '/^verdict=/ { print $2; exit }')"
    ;;
  2) verdict="BLOCK" ;;
  *) verdict="ERROR" ;;
esac
[ -z "$verdict" ] && verdict="ERROR"

# ----------------------------------------------------------------------------
# FR-13 verdict-as-comment: post verdict gloss to the Issue/PR in live mode.
# Skip in stub mode (CONVERSUS_STUB=1) or fixture mode (M013_GH_STUB_DIR set).
# ----------------------------------------------------------------------------
if [ -z "${CONVERSUS_STUB:-}" ] && [ -z "${M013_GH_STUB_DIR:-}" ]; then
  repo="${ISSUE_REF%#*}"
  num="${ISSUE_REF#*#}"
  gloss="M013 Conversus Gate: verdict=${verdict} preset=${PRESET} rc=${rc}"
  if command -v gh >/dev/null 2>&1; then
    gh issue comment "$num" -R "$repo" --body "$gloss" >/dev/null 2>&1 || true
  fi
fi

# ----------------------------------------------------------------------------
# FR-17 Tier 1 emission: one conversus_gate_invocation record per invocation.
# M026/P02/T02 (FR-4): resolve the adapter's edition so the JSONL record
# carries it adjacent to adapter_version. Stderr is dropped per DC-5.
# ----------------------------------------------------------------------------
_edition="$(bash "$ADAPTER" check 2>/dev/null | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
: "${_edition:=unknown}"
emit_conversus_gate_record "$ISSUE_REF" "$TIMEOUT" "$verdict" "$rc" "$duration_ms" "$_edition" || true

rm -f "$tmp_out" "$tmp_err"
exit "$rc"
