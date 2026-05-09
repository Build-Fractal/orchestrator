#!/usr/bin/env bash
# tools/verify/m035-p06-multi-source-dispatch-shape.sh
#
# M035 P06 T02 — Asserts the multi-source dispatch in run-update.sh:
#   1. case "$update_source" in present
#   2. all four channel arms (git/npm/homebrew/none) present
#   3. resolve_update_source helper present
#   4. persist_update_source helper present
#   5. all four would_invoke= strings present
#   6. DECISIONS.md contains D014 anchor
#   7-10. --dry-run against fixtures with explicit update_source: emits the
#         expected would_invoke= substring for each channel
#   11. AD-5 detection resolves runtime=npm-postinstall to npm
#   12. AD-5 detection persists detected source to config.yml
#   13. unknown update_source value exits non-zero with FAIL: unknown update_source
#
# AD-19 single-script-file shape; runs against staged fixtures under
# /tmp/m035-p06-t02-dispatch-fixture-$$/. Bash 3.2 + POSIX-sh-safe.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DRIVER="$REPO/scripts/lifecycle/run-update.sh"
DECISIONS="$REPO/.orchestrator/DECISIONS.md"

# shellcheck disable=SC1091
. "$REPO/scripts/lib/errors.sh"

FIXTURE_ROOT="/tmp/m035-p06-t02-dispatch-fixture-$$"
mkdir -p "$FIXTURE_ROOT"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

pass=0
fail=0

# --- Assertion 1: case "$update_source" in present ---
if grep -qF 'case "$update_source" in' "$DRIVER"; then
  echo 'PASS: run-update.sh contains case "$update_source" in'
  pass=$((pass + 1))
else
  echo 'FAIL: run-update.sh missing case "$update_source" in'
  fail=$((fail + 1))
fi

# --- Assertion 2: all four channel arms present ---
arms_ok=1
if ! grep -qE '^[[:space:]]*git\)' "$DRIVER"; then
  arms_ok=0
fi
if ! grep -qE '^[[:space:]]*npm\)' "$DRIVER"; then
  arms_ok=0
fi
if ! grep -qE '^[[:space:]]*homebrew\)' "$DRIVER"; then
  arms_ok=0
fi
if ! grep -qE '^[[:space:]]*none\)' "$DRIVER"; then
  arms_ok=0
fi
if [ "$arms_ok" -eq 1 ]; then
  echo "PASS: run-update.sh contains all four channel arms (git/npm/homebrew/none)"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing one of git/npm/homebrew/none arms"
  fail=$((fail + 1))
fi

# --- Assertion 3: resolve_update_source helper present ---
if grep -qF 'resolve_update_source' "$DRIVER"; then
  echo "PASS: run-update.sh contains resolve_update_source helper"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing resolve_update_source helper"
  fail=$((fail + 1))
fi

# --- Assertion 4: persist_update_source helper present ---
if grep -qF 'persist_update_source' "$DRIVER"; then
  echo "PASS: run-update.sh contains persist_update_source helper"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing persist_update_source helper"
  fail=$((fail + 1))
fi

# --- Assertion 5: all four would_invoke= strings present ---
wi_ok=1
if ! grep -qF 'would_invoke=bash' "$DRIVER"; then
  wi_ok=0
fi
if ! grep -qF 'would_invoke=npm update -g @build-fractal/orchestrator' "$DRIVER"; then
  wi_ok=0
fi
if ! grep -qF 'would_invoke=brew upgrade orchestrator' "$DRIVER"; then
  wi_ok=0
fi
if ! grep -qF 'would_invoke=<no-op: update_source=none>' "$DRIVER"; then
  wi_ok=0
fi
if [ "$wi_ok" -eq 1 ]; then
  echo "PASS: run-update.sh contains all four would_invoke= strings"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing one of the would_invoke= strings"
  fail=$((fail + 1))
fi

# --- Assertion 6: DECISIONS.md contains D014 anchor ---
d014_anchor=""
d014_anchor="$(grep -nE '^### D014( |$)' "$DECISIONS" | head -1)"
if [ -n "$d014_anchor" ]; then
  echo "PASS: DECISIONS.md contains D014 anchor"
  pass=$((pass + 1))
else
  echo "FAIL: DECISIONS.md missing D014 heading-shape anchor"
  fail=$((fail + 1))
fi

# --- Assertion 7: git fixture --dry-run emits would_invoke=bash ... install-claude-code.sh --force ---
GIT_DIR="$FIXTURE_ROOT/git"
mkdir -p "$GIT_DIR/.orchestrator"
printf 'update_source: git\n' > "$GIT_DIR/.orchestrator/config.yml"
git_out="$FIXTURE_ROOT/git.out"
git_err="$FIXTURE_ROOT/git.err"
ORCHESTRATOR_SOURCE_REPO="$REPO" \
  bash "$DRIVER" --project-dir "$GIT_DIR" --dry-run \
    >"$git_out" 2>"$git_err" || true
git_ok=1
if ! grep -qF 'would_invoke=bash' "$git_out"; then
  git_ok=0
fi
if ! grep -qF 'install-claude-code.sh' "$git_out"; then
  git_ok=0
fi
if ! grep -qF -- '--force' "$git_out"; then
  git_ok=0
fi
if [ "$git_ok" -eq 1 ]; then
  echo "PASS: --dry-run against update_source: git fixture emits would_invoke=bash ... install-claude-code.sh ... --force"
  pass=$((pass + 1))
else
  echo "FAIL: git fixture dry-run did not emit would_invoke=bash ... install-claude-code.sh ... --force"
  sed 's/^/  out: /' "$git_out"
  sed 's/^/  err: /' "$git_err"
  fail=$((fail + 1))
fi

# --- Assertion 8: npm fixture --dry-run emits would_invoke=npm update -g @build-fractal/orchestrator ---
# This assertion only fires when npm is on PATH AND @build-fractal/orchestrator
# is NOT globally installed (the dispatch's pre-flight check fails). To make
# this deterministic across environments, we shim PATH to a directory carrying
# a fake `npm` whose `npm root -g` points at a temp dir we control with the
# expected package present.
NPM_DIR="$FIXTURE_ROOT/npm"
mkdir -p "$NPM_DIR/.orchestrator"
printf 'update_source: npm\n' > "$NPM_DIR/.orchestrator/config.yml"

NPM_SHIM_DIR="$FIXTURE_ROOT/npm-shim-bin"
NPM_FAKE_ROOT="$FIXTURE_ROOT/npm-fake-root"
mkdir -p "$NPM_SHIM_DIR"
mkdir -p "$NPM_FAKE_ROOT/@build-fractal/orchestrator"

NPM_SHIM="$NPM_SHIM_DIR/npm"
{
  printf '#!/usr/bin/env bash\n'
  printf 'if [ "$1" = "root" ] && [ "$2" = "-g" ]; then\n'
  printf '  printf "%%s\\n" "%s"\n' "$NPM_FAKE_ROOT"
  printf '  exit 0\n'
  printf 'fi\n'
  printf 'echo "fake npm: unsupported invocation: $*" >&2\n'
  printf 'exit 1\n'
} > "$NPM_SHIM"
chmod +x "$NPM_SHIM"

npm_out="$FIXTURE_ROOT/npm.out"
npm_err="$FIXTURE_ROOT/npm.err"
PATH="$NPM_SHIM_DIR:$PATH" \
  bash "$DRIVER" --project-dir "$NPM_DIR" --dry-run \
    >"$npm_out" 2>"$npm_err" || true
if grep -qF 'would_invoke=npm update -g @build-fractal/orchestrator' "$npm_out"; then
  echo "PASS: --dry-run against update_source: npm fixture emits would_invoke=npm update -g @build-fractal/orchestrator"
  pass=$((pass + 1))
else
  echo "FAIL: npm fixture dry-run did not emit expected would_invoke= line"
  sed 's/^/  out: /' "$npm_out"
  sed 's/^/  err: /' "$npm_err"
  fail=$((fail + 1))
fi

# --- Assertion 9: homebrew fixture --dry-run emits would_invoke=brew upgrade orchestrator ---
HB_DIR="$FIXTURE_ROOT/homebrew"
mkdir -p "$HB_DIR/.orchestrator"
printf 'update_source: homebrew\n' > "$HB_DIR/.orchestrator/config.yml"

BREW_SHIM_DIR="$FIXTURE_ROOT/brew-shim-bin"
BREW_FAKE_PREFIX="$FIXTURE_ROOT/brew-fake-prefix"
mkdir -p "$BREW_SHIM_DIR"
mkdir -p "$BREW_FAKE_PREFIX/Cellar/orchestrator"

BREW_SHIM="$BREW_SHIM_DIR/brew"
{
  printf '#!/usr/bin/env bash\n'
  printf 'if [ "$1" = "--prefix" ]; then\n'
  printf '  printf "%%s\\n" "%s"\n' "$BREW_FAKE_PREFIX"
  printf '  exit 0\n'
  printf 'fi\n'
  printf 'echo "fake brew: unsupported invocation: $*" >&2\n'
  printf 'exit 1\n'
} > "$BREW_SHIM"
chmod +x "$BREW_SHIM"

hb_out="$FIXTURE_ROOT/hb.out"
hb_err="$FIXTURE_ROOT/hb.err"
PATH="$BREW_SHIM_DIR:$PATH" \
  bash "$DRIVER" --project-dir "$HB_DIR" --dry-run \
    >"$hb_out" 2>"$hb_err" || true
if grep -qF 'would_invoke=brew upgrade orchestrator' "$hb_out"; then
  echo "PASS: --dry-run against update_source: homebrew fixture emits would_invoke=brew upgrade orchestrator"
  pass=$((pass + 1))
else
  echo "FAIL: homebrew fixture dry-run did not emit expected would_invoke= line"
  sed 's/^/  out: /' "$hb_out"
  sed 's/^/  err: /' "$hb_err"
  fail=$((fail + 1))
fi

# --- Assertion 10: none fixture --dry-run emits would_invoke=<no-op: update_source=none> ---
NONE_DIR="$FIXTURE_ROOT/none"
mkdir -p "$NONE_DIR/.orchestrator"
printf 'update_source: none\n' > "$NONE_DIR/.orchestrator/config.yml"
none_out="$FIXTURE_ROOT/none.out"
none_err="$FIXTURE_ROOT/none.err"
bash "$DRIVER" --project-dir "$NONE_DIR" --dry-run \
  >"$none_out" 2>"$none_err" || true
if grep -qF 'would_invoke=<no-op: update_source=none>' "$none_out"; then
  echo "PASS: --dry-run against update_source: none fixture emits would_invoke=<no-op: update_source=none>"
  pass=$((pass + 1))
else
  echo "FAIL: none fixture dry-run did not emit expected would_invoke= line"
  sed 's/^/  out: /' "$none_out"
  sed 's/^/  err: /' "$none_err"
  fail=$((fail + 1))
fi

# --- Assertion 11: AD-5 detection resolves runtime=npm-postinstall to npm ---
DETECT_DIR="$FIXTURE_ROOT/detect-npm"
mkdir -p "$DETECT_DIR/.orchestrator"
# No update_source: in config — install-meta.txt drives detection.
printf 'schema_version: "1.0"\ntype: orchestrator-config\n' > "$DETECT_DIR/.orchestrator/config.yml"
{
  printf 'source_root=/some/path\n'
  printf 'runtime=npm-postinstall\n'
  printf 'installed_at=2026-05-09T00:00:00Z\n'
  printf 'commit_sha=abc1234\n'
  printf 'version=0.9.3\n'
} > "$DETECT_DIR/.orchestrator/install-meta.txt"
detect_out="$FIXTURE_ROOT/detect.out"
detect_err="$FIXTURE_ROOT/detect.err"
PATH="$NPM_SHIM_DIR:$PATH" \
  bash "$DRIVER" --project-dir "$DETECT_DIR" --dry-run \
    >"$detect_out" 2>"$detect_err" || true
if grep -qF 'would_invoke=npm update -g' "$detect_out"; then
  echo "PASS: AD-5 detection resolves to npm via install-meta.txt runtime=npm-postinstall"
  pass=$((pass + 1))
else
  echo "FAIL: AD-5 detection did not resolve runtime=npm-postinstall to npm"
  sed 's/^/  out: /' "$detect_out"
  sed 's/^/  err: /' "$detect_err"
  fail=$((fail + 1))
fi

# --- Assertion 12: AD-5 detection persists detected source to config.yml ---
if grep -qE '^update_source:[[:space:]]*npm$' "$DETECT_DIR/.orchestrator/config.yml"; then
  echo "PASS: AD-5 detection persists detected source to config.yml"
  pass=$((pass + 1))
else
  echo "FAIL: detection did not persist update_source: npm to config.yml"
  sed 's/^/  cfg: /' "$DETECT_DIR/.orchestrator/config.yml"
  fail=$((fail + 1))
fi

# --- Assertion 13: invalid_value exits non-zero with FAIL: unknown update_source ---
BAD_DIR="$FIXTURE_ROOT/bad"
mkdir -p "$BAD_DIR/.orchestrator"
printf 'update_source: invalid_value\n' > "$BAD_DIR/.orchestrator/config.yml"
bad_out="$FIXTURE_ROOT/bad.out"
bad_err="$FIXTURE_ROOT/bad.err"
bad_rc=0
bash "$DRIVER" --project-dir "$BAD_DIR" --dry-run \
  >"$bad_out" 2>"$bad_err" || bad_rc=$?
bad_ok=1
if [ "$bad_rc" -eq 0 ]; then
  bad_ok=0
fi
if ! grep -qF 'FAIL: unknown update_source' "$bad_err"; then
  bad_ok=0
fi
if [ "$bad_ok" -eq 1 ]; then
  echo "PASS: --dry-run against update_source: invalid_value exits non-zero with FAIL: unknown update_source"
  pass=$((pass + 1))
else
  echo "FAIL: invalid_value fixture did not exit non-zero with FAIL: unknown update_source (rc=$bad_rc)"
  sed 's/^/  out: /' "$bad_out"
  sed 's/^/  err: /' "$bad_err"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
