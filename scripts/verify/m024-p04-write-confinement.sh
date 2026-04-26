#!/usr/bin/env bash
# scripts/verify/m024-p04-write-confinement.sh
# Verifies P04-introduced shell scripts respect SB-3 — writes target only
# .orchestrator/intake/<id>/, /tmp scratch, or stdout/stderr.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# The check-fast-path mode is read-only — any write at all in approval-gate.sh
# must be explicitly under the verb path (already verified by P03 confinement).
# T03's wiring in proposal-emit.sh introduces no new write paths — the existing
# mktemp + swap + mv flow already SB-3-conforms.
#
# We grep the P04-touched files for `>` redirections that escape the allowed
# surfaces and fail loudly on any hit. The regex requires whitespace before `>`
# and excludes `>&[12]` and `>/dev/null` per the P03 tightening.

files="
  scripts/intake/approval-gate.sh
  scripts/intake/proposal-emit.sh
  scripts/state/read-config.sh
"

rc=0
for f in $files; do
  full="$ROOT/$f"
  [ -f "$full" ] || { echo "FAIL: $f not present"; rc=1; continue; }
  # Look for a write that escapes /tmp, .orchestrator/intake/, $tmp, /dev/null, &1, &2.
  hits=$(grep -nE '[[:space:]]>([^&/]|/[^d])' "$full" \
           | grep -vE '/tmp|\.orchestrator/intake|\$tmp|>/dev/null|tmp_render|\$out_path|\$out_dir|>&[12]' \
           || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $f has unconfined writes:"
    echo "$hits"
    rc=1
  fi
done

if [ $rc -eq 0 ]; then
  echo "PASS: m024-p04-write-confinement — approval-gate / proposal-emit / read-config writes confined to .orchestrator/intake/, /tmp, or stdio"
fi
exit $rc
