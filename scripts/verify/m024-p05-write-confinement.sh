#!/usr/bin/env bash
# scripts/verify/m024-p05-write-confinement.sh
# M024/P05 verify — write-confinement (SB-3) — every P05-introduced script
# writes only to .orchestrator/intake/<id>/, templates/, scripts/, tests/,
# or trap-cleaned /tmp scratch (mktemp).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Files introduced by P05 that perform writes.
QA_LOOP="$ROOT/scripts/intake/qa-loop.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$QA_LOOP" ] || { echo "FAIL: qa-loop.sh not executable"; exit 1; }
[ -x "$EMIT" ]    || { echo "FAIL: proposal-emit.sh not executable"; exit 1; }

# qa-loop.sh writes only to TRANSCRIPT_OUT (caller-supplied) and trap-cleaned mktemp.
# Forbidden: any unguarded write outside those two surfaces.
# Filter order: drop comment lines ('^[0-9]+:[[:space:]]*#'), then drop allowed
# write surfaces (mktemp / TRANSCRIPT_OUT / /tmp/), then drop stderr redirects
# (2>/dev/null) since they are not writes.
if grep -nE '>[[:space:]]*/[a-z]' "$QA_LOOP" \
  | grep -vE '^[0-9]+:[[:space:]]*#' \
  | grep -vE 'mktemp|TRANSCRIPT_OUT|/tmp/' \
  | grep -vE '2>/dev/null' \
  | grep -q .; then
  echo "FAIL: qa-loop.sh contains unguarded absolute-path writes"
  exit 1
fi

# proposal-emit.sh write surfaces: $out_path under intake-root, $tmp_render (mktemp),
# $qa_tx_tmp (mktemp), and the trap-cleaned scratch. The structural check is that
# the script does not introduce new absolute-path writes outside those three.
if grep -nE '>[[:space:]]*/[a-z]' "$EMIT" \
  | grep -vE '^[0-9]+:[[:space:]]*#' \
  | grep -vE 'mktemp|out_path|tmp_render|qa_tx_tmp|/tmp/' \
  | grep -vE '2>/dev/null' \
  | grep -q .; then
  echo "FAIL: proposal-emit.sh contains unguarded absolute-path writes"
  exit 1
fi

echo "PASS: P05 write-confinement — qa-loop.sh + proposal-emit.sh respect SB-3"
exit 0
