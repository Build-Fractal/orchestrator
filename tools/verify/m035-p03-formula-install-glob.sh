#!/usr/bin/env bash
# tools/verify/m035-p03-formula-install-glob.sh
#
# M035 MOS-3 regression guard — Homebrew formula install correctness.
#
# Catches the two-part bug found 2026-06-05 during the first real
# `brew install` smoke test of v0.9.8, where `brew install` produced a
# binary-less Cellar and `brew test` errored ENOENT on bin/orchestrator:
#
#   1. Wrong glob. The npm pack tarball wraps everything under a single
#      top-level "package/" dir, which Homebrew STRIPS on unpack (tar-
#      trim). So `def install` runs with the contents at the staging
#      root and a `Dir["package/*"]` glob matches nothing. Correct: `*`.
#   2. Self-referential bin symlink. `prefix.install Dir["*"]` puts the
#      real binary at prefix/bin/orchestrator; then
#      `bin.install_symlink prefix/"bin/orchestrator"` symlinks
#      prefix/bin/orchestrator onto ITSELF (bin == prefix/bin), emptying
#      it. Correct: stage into libexec, symlink libexec/"bin/orchestrator".
#
# This guard replicates brew's unpack-and-strip against a freshly packed
# tarball, parses BOTH formula steps (the install dir + glob, and the
# symlink target), simulates them, and asserts the on-PATH entry point
# resolves to an executable file — i.e. `orchestrator --version` would
# work. Fails on either the package/* glob or the prefix-self-symlink.
#
# Bash 3.2; offline (npm pack only, no network). No jq/python.
set -u

pass=0
fail=0
TMPL="packaging/homebrew/orchestrator.rb.tmpl"

fail_msg() { echo "FAIL: $1"; fail=$((fail + 1)); }
pass_msg() { pass=$((pass + 1)); }

if [ ! -f "$TMPL" ]; then
  echo "FAIL: template not found: $TMPL"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

# 1. Parse the install line: "<dir>.install Dir[\"<glob>\"]".
install_line="$(grep -E '(libexec|prefix|pkgshare)\.install[[:space:]]+Dir\[' "$TMPL" | head -1)"
install_dir="$(printf '%s' "$install_line" | sed -E 's/^[[:space:]]*([a-z]+)\.install.*/\1/')"
glob_pat="$(printf '%s' "$install_line" | sed -E 's/.*Dir\[[[:space:]]*"([^"]*)".*/\1/')"
# 2. Parse the symlink line: "bin.install_symlink <dir>/\"<subpath>\"".
symlink_line="$(grep -E 'bin\.install_symlink' "$TMPL" | head -1)"
symlink_dir="$(printf '%s' "$symlink_line" | sed -E 's/.*install_symlink[[:space:]]+([a-z]+)\/.*/\1/')"
symlink_sub="$(printf '%s' "$symlink_line" | sed -E 's/.*install_symlink[[:space:]]+[a-z]+\/"([^"]*)".*/\1/')"

if [ -z "$install_dir" ] || [ -z "$glob_pat" ]; then
  fail_msg "could not parse the <dir>.install Dir[\"...\"] line from $TMPL"
  echo "BATTERY: pass=$pass fail=$fail"
  exit 1
fi
if [ -z "$symlink_dir" ] || [ -z "$symlink_sub" ]; then
  fail_msg "could not parse the bin.install_symlink <dir>/\"...\" line from $TMPL"
  echo "BATTERY: pass=$pass fail=$fail"
  exit 1
fi
pass_msg

# 3. Pack + unpack + replicate brew's leading-dir strip.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if ! npm pack --pack-destination "$WORK" > "$WORK/pack.log" 2>&1; then
  fail_msg "npm pack failed"; sed 's/^/    /' "$WORK/pack.log"
  echo "BATTERY: pass=$pass fail=$fail"; exit 1
fi
TGZ="$(ls "$WORK"/*.tgz 2>/dev/null | head -1)"
[ -n "$TGZ" ] || { fail_msg "npm pack produced no .tgz"; echo "BATTERY: pass=$pass fail=$fail"; exit 1; }
EXTRACT="$WORK/extract"; mkdir -p "$EXTRACT"
tar xzf "$TGZ" -C "$EXTRACT"
top_count="$(ls "$EXTRACT" | wc -l | tr -d ' ')"
top_entry="$(ls "$EXTRACT" | head -1)"
if [ "$top_count" = "1" ] && [ -d "$EXTRACT/$top_entry" ]; then
  STAGE_ROOT="$EXTRACT/$top_entry"   # brew strips the single leading dir
else
  STAGE_ROOT="$EXTRACT"
fi
pass_msg

# 4. Simulate "<install_dir>.install Dir[\"<glob>\"]".
FAKE="$WORK/cellar"
case "$install_dir" in
  libexec) DEST="$FAKE/libexec" ;;
  *)       DEST="$FAKE" ;;   # prefix
esac
mkdir -p "$DEST"
cd "$STAGE_ROOT" || { fail_msg "cannot cd to stage root"; echo "BATTERY: pass=$pass fail=$fail"; exit 1; }
matches=0
for f in $glob_pat; do
  [ -e "$f" ] || continue
  cp -R "$f" "$DEST/"
  matches=$((matches + 1))
done
cd - >/dev/null 2>&1 || true
if [ "$matches" -eq 0 ]; then
  fail_msg "install glob Dir[\"$glob_pat\"] matched NOTHING under brew's post-strip staging root — must be \"*\", not \"package/*\"."
else
  pass_msg
fi

# 5. Simulate "bin.install_symlink <symlink_dir>/\"<symlink_sub>\"" and assert
#    the on-PATH entry point resolves to an executable file.
case "$symlink_dir" in
  libexec) TARGET="$FAKE/libexec/$symlink_sub" ;;
  *)       TARGET="$FAKE/$symlink_sub" ;;   # prefix
esac
LINK="$FAKE/bin/$(basename "$symlink_sub")"
mkdir -p "$FAKE/bin"
# Homebrew's install_symlink force-overwrites (ln_sf): a prefix-self-symlink
# replaces the real file with a dangling self-loop. Model with -f so this
# guard catches that regression, not just the empty-glob one.
ln -sf "$TARGET" "$LINK" 2>/dev/null || true
# `-f`/`-x` follow the symlink; a self-referential or dangling link fails both.
if [ -f "$LINK" ] && [ -x "$LINK" ]; then
  pass_msg
else
  fail_msg "on-PATH entry $LINK does not resolve to an executable (target=$TARGET). A package/* glob (target absent) or a prefix-self-symlink (link==target) both produce this. Use libexec.install + bin.install_symlink libexec/\"bin/orchestrator\"."
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
