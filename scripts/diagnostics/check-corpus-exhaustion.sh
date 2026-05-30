#!/usr/bin/env bash
# scripts/diagnostics/check-corpus-exhaustion.sh — M042/P02 corpus-gate lint.
#
# Surfaces corpus-exhaustion gate artifacts (M042) that carry an unresolved
# BLOCK verdict — i.e. a gate ran, found un-dispositioned corpus hits, and the
# question packet / plan was left in that state instead of being resolved
# (read the cited hits → drop the answered questions / keep the open ones →
# re-run to PASS). This is the bypass signal: a BLOCK that never became a PASS.
#
# `warn`, not `fail` (advisory) — sparse cases are legitimate (work in
# progress, an intentionally-parked packet). The operator decides. Zero-noise
# on projects with no corpus-exhaustion artifacts (status=ok artifacts=0).
#
# Emits: DOCTOR:CORPUS_EXHAUSTION status=ok|warn artifacts=<N> unresolved_block=<N>
#
# Bash 3.2 compatible. Read-only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --quiet) shift ;;            # accepted for run_check arg-shape parity
    *) shift ;;
  esac
done

# Real artifacts live under .orchestrator/. A test root may place them directly;
# fall back to ROOT when there is no .orchestrator/ subtree.
scan="$ROOT/.orchestrator"
if [ ! -d "$scan" ]; then
  scan="$ROOT"
fi

matches="$(find "$scan" -type f -name 'corpus-exhaustion-*.md' 2>/dev/null | grep -v '/templates/' || true)"

total=0
block=0
if [ -n "$matches" ]; then
  _old_ifs="$IFS"
  IFS='
'
  for f in $matches; do
    [ -n "$f" ] || continue
    # Content gate: a real artifact carries `type: corpus-exhaustion` in its
    # frontmatter. This excludes same-prefixed non-artifacts (e.g. the
    # proposal doc corpus-exhaustion-gate.md) that share the filename glob.
    grep -qE '^type:[[:space:]]*corpus-exhaustion' "$f" 2>/dev/null || continue
    total=$((total + 1))
    v="$(grep -E '^verdict:' "$f" 2>/dev/null | head -1 | sed -E 's/^verdict:[[:space:]]*"?([^"]*)"?.*/\1/')"
    if [ "$v" = "BLOCK" ]; then
      block=$((block + 1))
      echo "BLOCK (unresolved): ${f#$ROOT/}"
    fi
  done
  IFS="$_old_ifs"
fi

if [ "$block" -gt 0 ]; then
  echo "Resolve each BLOCK: read the cited hits, annotate questions @disposition=dropped|kept, and re-run the gate to PASS."
  echo "DOCTOR:CORPUS_EXHAUSTION status=warn artifacts=$total unresolved_block=$block"
else
  echo "PASS: no unresolved corpus-exhaustion BLOCK artifacts ($total scanned)."
  echo "DOCTOR:CORPUS_EXHAUSTION status=ok artifacts=$total unresolved_block=0"
fi
exit 0
