#!/usr/bin/env bash
# scripts/verify/m028/p02-hooks-payload-staged.sh -- M028/P02/T03 verifier.
#
# Asserts that packaging/install/install-claude-code.sh stages the full hooks
# payload into ${HOME}/.claude/orchestrator-hooks/ on a fresh install. The
# payload contract (per CON-9 + T03 plan):
#
#   pre-bash-shape-guard.sh   -- T01 self-locating shape-guard hook
#   shape-classifier.sh       -- M021 classifier library (sibling of hook)
#   before-commit.sh          -- M025 lifecycle script (PreToolUse Bash)
#   after-verify-sync.sh      -- M025 lifecycle script (Stop)
#   MANIFEST                  -- text file listing staged set (used by --uninstall)
#
# Two-mode design: --dry-run pass first (proves the would_write= list is
# correct; cheap; no real file copy). Then a non-dry-run pass against an
# isolated HOME (proves the bytes actually land on disk and MANIFEST is
# 5 lines).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
# set -u; no set -e (every check runs independently).

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

fail_count=0

# --- Mode 1: dry-run -- prove the would_write= list is correct ---
tmp_home_dry="${TMPDIR:-/tmp}/p02-payload-dry-$$"
mkdir -p "$tmp_home_dry"
dry_log="${tmp_home_dry}/dry.log"

HOME="$tmp_home_dry" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home_dry" --dry-run >"$dry_log" 2>&1
dry_rc=$?

if [ "$dry_rc" -ne 0 ]; then
  echo "FAIL: --dry-run installer exited rc=$dry_rc" >&2
  cat "$dry_log" >&2
  fail_count=$((fail_count + 1))
fi

# Each of the 5 expected basenames must appear in a `would_write=...orchestrator-hooks/<name>` line.
for name in pre-bash-shape-guard.sh shape-classifier.sh before-commit.sh after-verify-sync.sh MANIFEST; do
  if ! grep -q "would_write=${tmp_home_dry}/.claude/orchestrator-hooks/${name}" "$dry_log"; then
    echo "FAIL: dry-run did not emit would_write= for ${name}" >&2
    fail_count=$((fail_count + 1))
  fi
done

rm -rf "$tmp_home_dry"

# --- Mode 2: real install -- prove files land + MANIFEST is 5 lines ---
tmp_home="${TMPDIR:-/tmp}/p02-payload-real-$$"
mkdir -p "$tmp_home"
real_log="${tmp_home}/real.log"

HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" >"$real_log" 2>&1
real_rc=$?

if [ "$real_rc" -ne 0 ]; then
  echo "FAIL: real installer exited rc=$real_rc" >&2
  cat "$real_log" >&2
  fail_count=$((fail_count + 1))
fi

hooks_dir="${tmp_home}/.claude/orchestrator-hooks"

for name in pre-bash-shape-guard.sh shape-classifier.sh before-commit.sh after-verify-sync.sh MANIFEST; do
  if [ ! -f "${hooks_dir}/${name}" ]; then
    echo "FAIL: expected staged file missing: ${hooks_dir}/${name}" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [ -f "${hooks_dir}/MANIFEST" ]; then
  manifest_lines="$(wc -l < "${hooks_dir}/MANIFEST" | tr -d ' ')"
  if [ "$manifest_lines" != "5" ]; then
    echo "FAIL: MANIFEST line count expected 5, got ${manifest_lines}" >&2
    fail_count=$((fail_count + 1))
  fi
fi

rm -rf "$tmp_home"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: ${fail_count} hooks-payload assertion(s) failed" >&2
  exit 1
fi

echo "PASS: hooks payload staged at orchestrator-hooks/ (5 files, MANIFEST present)"
exit 0
