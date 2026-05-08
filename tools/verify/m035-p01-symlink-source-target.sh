#!/usr/bin/env bash
# tools/verify/m035-p01-symlink-source-target.sh
# M035 P01 T01 must-have: assert that after install-claude-code.sh
# --mode=symlink against a fresh fixture project, the staged runtime
# subdirs (commands/, scripts/) are symlinks whose targets resolve under
# $REPO_ROOT/. This is the US-1 dogfood-velocity contract — a single
# `git pull` in the orchestrator source repo updates every consumer
# immediately because the consumer's runtime tree links DIRECTLY at the
# source repo path (NOT at a managed-runtime-cache subdirectory, the
# M032/P01 behaviour this task replaced).
#
# Also asserts (c) install-meta.txt carries `commit_sha=` and `version=`
# lines, both non-empty when run inside a git checkout (the dogfooding
# scenario; commit_sha must equal $REPO_ROOT's HEAD SHA).
#
# POSIX SKIP: if `ln -s` is unavailable in the test host, exit 77 with
# `SKIP_REASON: ln -s unavailable` (mirrors M032/P01 SC-2 SKIP).
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

TMP_BASE="$(mktemp -d -t m035-p01-symlink.XXXXXX)"
TMP_FIX="$TMP_BASE/fixture"
TMP_HOME="$TMP_BASE/home"
mkdir -p "$TMP_FIX" "$TMP_HOME/.claude"

cleanup() {
  rm -rf "$TMP_BASE"
}
trap cleanup EXIT

# Probe `ln -s` availability (mirrors M032/P01 p01-symlink-mode.sh MIT-001).
if ! ln -s /dev/null "$TMP_FIX/.lntest" 2>/dev/null; then
  echo "SKIP: ln -s unavailable on this filesystem" >&2
  echo "SKIP_REASON: ln -s unavailable" >&2
  exit 77
fi
rm -f "$TMP_FIX/.lntest"

# Run the installer with --mode=symlink against the fixture, isolating
# all $HOME writes ($HOME/.claude/) into TMP_HOME.
HOME="$TMP_HOME" bash "$INSTALLER" --mode=symlink --project-dir "$TMP_FIX" \
  > "$TMP_BASE/run.log" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: installer exited $rc with --mode=symlink" >&2
  echo "----- installer log -----" >&2
  cat "$TMP_BASE/run.log" >&2
  exit 1
fi

# (b) Each project_assets target should be a symbolic link pointing under
# $REPO_ROOT. Check `scripts` and `commands` (first two manifest entries).
fail=0
for dir in commands scripts; do
  link="$TMP_FIX/$dir"
  if [ ! -L "$link" ]; then
    echo "FAIL: $TMP_FIX/$dir is not a symbolic link (--mode=symlink)" >&2
    ls -la "$TMP_FIX" >&2
    fail=1
    continue
  fi
  # readlink returns the literal symlink target; for our retargeted
  # branch this should be the absolute $REPO_ROOT/<dir>.
  target="$(readlink "$link")"
  case "$target" in
    "$REPO_ROOT"/*)
      : # OK -- target resolves under the orchestrator source repo.
      ;;
    *)
      echo "FAIL: $dir symlink target '$target' does not resolve under \$REPO_ROOT ($REPO_ROOT)" >&2
      fail=1
      ;;
  esac
done

# (c) install-meta.txt carries commit_sha= and version= lines.
meta_file="$TMP_FIX/.orchestrator/install-meta.txt"
if [ ! -f "$meta_file" ]; then
  echo "FAIL: $meta_file missing after install" >&2
  fail=1
else
  if ! grep -q '^commit_sha=' "$meta_file"; then
    echo "FAIL: install-meta.txt missing commit_sha= line" >&2
    fail=1
  fi
  if ! grep -q '^version=' "$meta_file"; then
    echo "FAIL: install-meta.txt missing version= line" >&2
    fail=1
  fi
  # When $REPO_ROOT is itself a git checkout (the dogfood scenario the
  # verifier runs in), commit_sha should be non-empty AND match HEAD.
  if [ -d "$REPO_ROOT/.git" ]; then
    expected_sha="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
    actual_sha="$(awk -F= '/^commit_sha=/{print $2; exit}' "$meta_file")"
    if [ -z "$actual_sha" ]; then
      echo "FAIL: commit_sha= empty when run inside a git checkout" >&2
      fail=1
    elif [ "$actual_sha" != "$expected_sha" ]; then
      echo "FAIL: commit_sha=$actual_sha does not match \$REPO_ROOT HEAD ($expected_sha)" >&2
      fail=1
    fi
    # version should also be non-empty when CHANGELOG.md has a top-line.
    actual_ver="$(awk -F= '/^version=/{print $2; exit}' "$meta_file")"
    if [ -z "$actual_ver" ]; then
      echo "FAIL: version= empty when CHANGELOG.md has top-line ## [...] heading" >&2
      fail=1
    fi
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p01-symlink-source-target"
  exit 0
fi
exit 1
