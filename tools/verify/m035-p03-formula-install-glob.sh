#!/usr/bin/env bash
# tools/verify/m035-p03-formula-install-glob.sh
#
# M035 MOS-3 regression guard — Homebrew formula install-glob correctness.
#
# Catches the class of bug found 2026-06-05 during the first real `brew
# install` smoke test of v0.9.8: the formula's `prefix.install Dir[...]`
# glob did not match Homebrew's ACTUAL on-disk layout, so the Cellar got
# the metafiles (LICENSE/README/CHANGELOG) but no bin/ — `brew install`
# produced a binary-less shell and `brew test` errored ENOENT on
# bin/orchestrator.
#
# Root cause: the npm pack tarball wraps everything under a single
# top-level `package/` dir. Homebrew STRIPS that single leading dir on
# unpack (its standard "tar trim" behavior), so `def install` runs with
# the package CONTENTS already at the staging root. A `Dir["package/*"]`
# glob therefore matches nothing; the correct glob is `Dir["*"]`.
#
# This guard replicates brew's unpack-and-strip against a freshly packed
# tarball, evaluates the template's real install glob from that staged
# root, simulates `prefix.install`, and asserts bin/orchestrator lands
# where `bin.install_symlink prefix/"bin/orchestrator"` expects it.
# It would have failed on the buggy `package/*` glob and passes on `*`.
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

# 1. Extract the formula's install glob argument: prefix.install Dir["<pat>"]
glob_pat="$(grep -E 'prefix\.install[[:space:]]+Dir\[' "$TMPL" \
  | head -1 \
  | sed -E 's/.*Dir\[[[:space:]]*"([^"]*)".*/\1/')"
if [ -z "$glob_pat" ]; then
  fail_msg "could not parse prefix.install Dir[\"...\"] glob from $TMPL"
  echo "BATTERY: pass=$pass fail=$fail"
  exit 1
fi
pass_msg

# 2. Pack the tarball (npm pack on the repo; no network).
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if ! npm pack --pack-destination "$WORK" > "$WORK/pack.log" 2>&1; then
  fail_msg "npm pack failed"
  sed 's/^/    /' "$WORK/pack.log"
  echo "BATTERY: pass=$pass fail=$fail"
  exit 1
fi
TGZ="$(ls "$WORK"/*.tgz 2>/dev/null | head -1)"
if [ -z "$TGZ" ]; then
  fail_msg "npm pack produced no .tgz in $WORK"
  echo "BATTERY: pass=$pass fail=$fail"
  exit 1
fi
pass_msg

# 3. Unpack and replicate brew's leading-dir strip. The npm tarball has a
#    single top-level entry `package/`; brew chdir's into it, so the
#    staging root is <extract>/package.
EXTRACT="$WORK/extract"
mkdir -p "$EXTRACT"
tar xzf "$TGZ" -C "$EXTRACT"
top_count="$(ls "$EXTRACT" | wc -l | tr -d ' ')"
top_entry="$(ls "$EXTRACT" | head -1)"
if [ "$top_count" = "1" ] && [ -d "$EXTRACT/$top_entry" ]; then
  STAGE_ROOT="$EXTRACT/$top_entry"   # brew strips the single leading dir
else
  STAGE_ROOT="$EXTRACT"
fi

# 4. Simulate `prefix.install Dir["<pat>"]` from the staged root.
FAKE_PREFIX="$WORK/prefix"
mkdir -p "$FAKE_PREFIX"
cd "$STAGE_ROOT" || { fail_msg "cannot cd to stage root"; echo "BATTERY: pass=$pass fail=$fail"; exit 1; }
matches=0
for f in $glob_pat; do
  [ -e "$f" ] || continue
  cp -R "$f" "$FAKE_PREFIX/"
  matches=$((matches + 1))
done
cd - >/dev/null 2>&1 || true

if [ "$matches" -eq 0 ]; then
  fail_msg "install glob Dir[\"$glob_pat\"] matched NOTHING under brew's staged root (post-strip). This is the v0.9.8 bug — the npm tarball's package/ dir is already stripped, so the glob must be \"*\" not \"package/*\"."
else
  pass_msg
fi

# 5. The load-bearing assertion: bin/orchestrator must land at
#    prefix/bin/orchestrator (what bin.install_symlink references).
if [ -f "$FAKE_PREFIX/bin/orchestrator" ]; then
  pass_msg
else
  fail_msg "prefix/bin/orchestrator absent after simulated install (glob Dir[\"$glob_pat\"]). bin.install_symlink prefix/\"bin/orchestrator\" would fail and brew install yields a binary-less Cellar."
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
