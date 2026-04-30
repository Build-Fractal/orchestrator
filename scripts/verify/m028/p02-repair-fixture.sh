#!/usr/bin/env bash
# scripts/verify/m028/p02-repair-fixture.sh -- M028/P02/T04 verifier (FR-7).
#
# Asserts that running `bash packaging/install/install-claude-code.sh --repair`
# against the canonical pre-repair fixture produces a result byte-identical to
# the canonical post-repair reference fixture.
#
# Mechanics:
#   1. Stage tests/fixtures/m028-pre-repair-snapshot.json into an isolated
#      $HOME under ${TMPDIR:-/tmp}/p02-repair-$$/.claude/settings.json.
#   2. Run the installer in --repair mode against that isolated HOME.
#   3. Compute SHA-256 of the post-repair settings.json (via shasum + awk to
#      stay AD-19 compliant -- no $(... | ...) compound).
#   4. Compute SHA-256 of tests/fixtures/m028-post-repair-canonical.json the
#      same way.
#   5. Assert the hashes are equal. Emit PASS / FAIL accordingly.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
# set -u; no set -e.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"
PRE_FIXTURE="${REPO_ROOT}/tests/fixtures/m028-pre-repair-snapshot.json"
POST_FIXTURE="${REPO_ROOT}/tests/fixtures/m028-post-repair-canonical.json"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi
if [ ! -f "$PRE_FIXTURE" ]; then
  echo "FAIL: pre-repair fixture missing at $PRE_FIXTURE" >&2
  exit 1
fi
if [ ! -f "$POST_FIXTURE" ]; then
  echo "FAIL: post-repair canonical fixture missing at $POST_FIXTURE" >&2
  exit 1
fi

tmp_home="${TMPDIR:-/tmp}/p02-repair-$$"
mkdir -p "${tmp_home}/.claude"
cp "$PRE_FIXTURE" "${tmp_home}/.claude/settings.json"

run_log="${tmp_home}/repair.log"
HOME="$tmp_home" bash "$INSTALLER" --repair >"$run_log" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: installer --repair exited rc=$rc" >&2
  cat "$run_log" >&2
  exit 1
fi

# Compute SHA-256 of post-repair settings.json -- avoid $(... | ...) compound
# (AD-19 / AP-006). Two-step: shasum to tmp file, awk to extract.
actual_sha_file="${tmp_home}/actual.sha"
expected_sha_file="${tmp_home}/expected.sha"

shasum -a 256 "${tmp_home}/.claude/settings.json" > "$actual_sha_file"
shasum -a 256 "$POST_FIXTURE" > "$expected_sha_file"

actual_sha="$(awk '{print $1}' "$actual_sha_file")"
expected_sha="$(awk '{print $1}' "$expected_sha_file")"

if [ -z "$actual_sha" ] || [ -z "$expected_sha" ]; then
  echo "FAIL: could not compute SHA-256 (actual='$actual_sha' expected='$expected_sha')" >&2
  exit 1
fi

if [ "$actual_sha" != "$expected_sha" ]; then
  echo "FAIL: post-repair sha=$actual_sha expected=$expected_sha" >&2
  echo "DIFF: actual settings.json kept at ${tmp_home}/.claude/settings.json for inspection" >&2
  echo "DIFF: expected canonical at $POST_FIXTURE" >&2
  exit 1
fi

# Idempotency check: a second --repair run should leave the file byte-identical.
HOME="$tmp_home" bash "$INSTALLER" --repair >"${tmp_home}/repair2.log" 2>&1
rc2=$?
if [ "$rc2" -ne 0 ]; then
  echo "FAIL: second --repair run exited rc=$rc2 (idempotency violation)" >&2
  cat "${tmp_home}/repair2.log" >&2
  exit 1
fi
shasum -a 256 "${tmp_home}/.claude/settings.json" > "${tmp_home}/idem.sha"
idem_sha="$(awk '{print $1}' "${tmp_home}/idem.sha")"
if [ "$idem_sha" != "$expected_sha" ]; then
  echo "FAIL: --repair is not idempotent: second-run sha=$idem_sha expected=$expected_sha" >&2
  exit 1
fi

# Cleanup on PASS only -- on FAIL the tmp dir is left for inspection.
rm -rf "$tmp_home"

sha_short="${actual_sha%${actual_sha#????????????}}"
echo "PASS: --repair against pre-repair snapshot produces canonical post-repair bytes (sha=${sha_short}...)"
exit 0
