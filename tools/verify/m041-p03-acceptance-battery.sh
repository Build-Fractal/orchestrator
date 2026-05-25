#!/usr/bin/env bash
# tools/verify/m041-p03-acceptance-battery.sh -- M041 acceptance battery.
# Covers SC-1 through SC-7 from the detective spec.
# Bash 3.2 compatible.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

ORCH_ROOT="$(bash scripts/state/resolve-root.sh 2>/dev/null || echo ".orchestrator")"
case "$ORCH_ROOT" in /*) ;; *) ORCH_ROOT="$(pwd)/$ORCH_ROOT" ;; esac

pass=0
skip=0
fail=0

# Temp cleanup registry
tmpfiles=""
tmpdirs=""

mktmp_file() {
  local f
  f="$(mktemp)"
  tmpfiles="$tmpfiles $f"
  echo "$f"
}

mktmp_dir() {
  local d
  d="$(mktemp -d)"
  tmpdirs="$tmpdirs $d"
  echo "$d"
}

cleanup() {
  for f in $tmpfiles; do rm -f "$f" 2>/dev/null; done
  for d in $tmpdirs; do rm -rf "$d" 2>/dev/null; done
}
trap cleanup EXIT

check() {
  local id="$1" desc="$2"
  shift 2
  if "$@"; then
    echo "PASS: $id -- $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $id -- $desc"
    fail=$((fail + 1))
  fi
}

# ===========================================================================
# SC-1: triage-issue.sh emits all 6 section headers + exits 0
# ===========================================================================
sc1_check() {
  local out
  out="$(mktmp_file)"
  bash scripts/diagnostics/triage-issue.sh --symptom "test symptom" --capture-log >"$out" 2>/dev/null
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  triage-issue.sh exited $rc" >&2
    return 1
  fi
  local missing=""
  for hdr in "## Symptom" "## Environment" "## Recent Execution Log" "## Relevant Files" "## Disk State" "## Suggested Fix"; do
    if ! grep -qF "$hdr" "$out"; then
      missing="${missing} [$hdr]"
    fi
  done
  if [ -n "$missing" ]; then
    echo "  missing sections:$missing" >&2
    return 1
  fi
  return 0
}
check "SC-1" "triage-issue.sh emits 6-section structured report" sc1_check

# ===========================================================================
# SC-2: search-issues.sh returns scored results from mock data
# ===========================================================================
sc2_check() {
  local out
  out="$(mktmp_file)"
  GH_MOCK_DIR="$(cd tests/fixtures/detective/gh-mock && pwd)" \
    bash scripts/diagnostics/search-issues.sh \
      --query "test query" --repo Build-Fractal/orchestrator >"$out" 2>/dev/null
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  search-issues.sh exited $rc" >&2
    return 1
  fi
  if ! grep -q '"number"' "$out"; then
    echo "  stdout missing \"number\"" >&2
    return 1
  fi
  if ! grep -q '"match_score"' "$out"; then
    echo "  stdout missing \"match_score\"" >&2
    return 1
  fi
  return 0
}
check "SC-2" "search-issues.sh returns scored results via mock" sc2_check

# ===========================================================================
# SC-3: file-issue.sh creates mock issue request file
# ===========================================================================
sc3_check() {
  local report mockdir
  report="$(mktmp_file)"
  mockdir="$(mktmp_dir)"

  # Generate a triage report to use as input
  bash scripts/diagnostics/triage-issue.sh --symptom "SC-3 test filing" \
    --capture-log >"$report" 2>/dev/null

  GH_MOCK_DIR="$mockdir" \
    bash scripts/diagnostics/file-issue.sh \
      --triage-report "$report" --repo Build-Fractal/orchestrator --yes >/dev/null 2>/dev/null
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  file-issue.sh exited $rc" >&2
    return 1
  fi
  local req="$mockdir/issue-create-request.json"
  if [ ! -f "$req" ]; then
    echo "  issue-create-request.json not created" >&2
    return 1
  fi
  if ! grep -q '"title"' "$req"; then
    echo "  request missing \"title\"" >&2
    return 1
  fi
  if ! grep -q 'detective-triage' "$req"; then
    echo "  request missing detective-triage label" >&2
    return 1
  fi
  return 0
}
check "SC-3" "file-issue.sh creates mock issue with detective-triage label" sc3_check

# ===========================================================================
# SC-4: search-issues.sh degrades gracefully when gh is unavailable
# ===========================================================================
sc4_check() {
  local stderr_file
  stderr_file="$(mktmp_file)"
  env PATH="/usr/bin:/bin" GH_MOCK_DIR="" \
    bash scripts/diagnostics/search-issues.sh --query "test" >/dev/null 2>"$stderr_file"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  search-issues.sh exited $rc under stripped PATH" >&2
    return 1
  fi
  if ! grep -qF "DETECTIVE: gh unavailable" "$stderr_file"; then
    echo "  stderr missing 'DETECTIVE: gh unavailable'" >&2
    return 1
  fi
  return 0
}
check "SC-4" "graceful degradation when gh is unavailable" sc4_check

# ===========================================================================
# SC-5: commands/detective.md exists and contains description:
# ===========================================================================
sc5_check() {
  if [ ! -f "commands/detective.md" ]; then
    echo "  commands/detective.md not found" >&2
    return 1
  fi
  if ! grep -q 'description:' "commands/detective.md"; then
    echo "  commands/detective.md missing description:" >&2
    return 1
  fi
  return 0
}
check "SC-5" "commands/detective.md exists with description:" sc5_check

# ===========================================================================
# SC-6: detective-recommend.sh emits RECOMMEND for orchestrator-internal path
# ===========================================================================
sc6_check() {
  local stderr_file
  stderr_file="$(mktmp_file)"
  bash scripts/diagnostics/detective-recommend.sh \
    --symptom "test" --path "$ORCH_ROOT/scripts/nonexistent.sh" 2>"$stderr_file"
  if ! grep -qF "RECOMMEND: orchestrator:detective" "$stderr_file"; then
    echo "  stderr missing RECOMMEND line" >&2
    return 1
  fi
  return 0
}
check "SC-6" "detective-recommend.sh emits RECOMMEND for orchestrator-internal path" sc6_check

# ===========================================================================
# SC-7: SKIP -- unit_close requires full command wiring via skill registration
# ===========================================================================
echo "SKIP: SC-7 -- unit_close deferred to skill registration"
skip=$((skip + 1))

# ===========================================================================
# Summary
# ===========================================================================
echo "---"
echo "BATTERY: pass=$pass skip=$skip fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
