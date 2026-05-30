#!/usr/bin/env bash
# tools/verify/m042-p01-acceptance-battery.sh — M042/P01 acceptance battery.
# Covers SC-1 through SC-6 from the corpus-exhaustion-gate spec.
# Bash 3.2 compatible. Deterministic — fixture corpus + caller-supplied
# timestamps; no network, no LLM.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

SWEEP="scripts/knowledge/corpus-exhaustion-sweep.sh"
ADAPTER="scripts/dispatch/adapters/tool/corpus-gate.sh"
FIX="tests/fixtures/corpus-gate"
GEN_AT="2026-05-30T00:00:00Z"

pass=0
skip=0
fail=0
tmpfiles=""

mktmp_file() {
  local f
  f="$(mktemp)"
  tmpfiles="$tmpfiles $f"
  echo "$f"
}
cleanup() { for f in $tmpfiles; do rm -f "$f" 2>/dev/null; done; }
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
# SC-1: sweep marks the hitting question HITS (with citation) and the absent
# question CLEAN.
# ===========================================================================
sc1_check() {
  local art
  art="$(mktmp_file)"
  bash "$SWEEP" --questions "$FIX/questions-mixed.txt" --checkpoint sc1 \
    --generated-at "$GEN_AT" --manifest "$FIX/manifest-ok.yml" \
    --out "$art" >/dev/null 2>&1 || { echo "  sweep exited nonzero" >&2; return 1; }
  grep -qE '^### Q1 — HITS' "$art" || { echo "  Q1 not HITS" >&2; return 1; }
  grep -qE '^### Q2 — CLEAN' "$art" || { echo "  Q2 not CLEAN" >&2; return 1; }
  grep -q 'decisions :: tests/fixtures/corpus-gate/corpus/decisions.md' "$art" \
    || { echo "  Q1 missing decisions citation" >&2; return 1; }
  return 0
}
check "SC-1" "sweep marks hitting question HITS (cited) + absent question CLEAN" sc1_check

# ===========================================================================
# SC-2: gate adapter exits 2 with an un-dispositioned HITS row; 0 when
# all rows are clean or dispositioned.
# ===========================================================================
sc2_block_check() {
  local art
  art="$(mktmp_file)"
  bash "$ADAPTER" gate --checkpoint sc2 --generated-at "$GEN_AT" \
    --manifest "$FIX/manifest-ok.yml" "$FIX/questions-mixed.txt" "$art" >/dev/null 2>&1
  [ "$?" -eq 2 ] || { echo "  expected exit 2 (BLOCK), got $?" >&2; return 1; }
  return 0
}
sc2_pass_check() {
  local art
  art="$(mktmp_file)"
  bash "$ADAPTER" gate --checkpoint sc2 --generated-at "$GEN_AT" \
    --manifest "$FIX/manifest-ok.yml" "$FIX/questions-kept.txt" "$art" >/dev/null 2>&1
  [ "$?" -eq 0 ] || { echo "  expected exit 0 (PASS), got $?" >&2; return 1; }
  return 0
}
check "SC-2a" "gate exits 2 on un-dispositioned HITS" sc2_block_check
check "SC-2b" "gate exits 0 when all rows clean/dispositioned" sc2_pass_check

# ===========================================================================
# SC-3: disabled feature emits SKIPPED + exit 0; --strict + disabled exits 1.
# ===========================================================================
sc3_skip_check() {
  local art out
  art="$(mktmp_file)"; out="$(mktmp_file)"
  SPECKIT_ORCHESTRATOR_CORPUS_EXHAUSTION_ENABLED=false \
    bash "$ADAPTER" gate --checkpoint sc3 --generated-at "$GEN_AT" \
      --manifest "$FIX/manifest-ok.yml" "$FIX/questions-mixed.txt" "$art" >"$out" 2>&1
  [ "$?" -eq 0 ] || { echo "  expected exit 0 when disabled, got $?" >&2; return 1; }
  grep -qF "SKIPPED:" "$out" || { echo "  missing SKIPPED line" >&2; return 1; }
  return 0
}
sc3_strict_check() {
  local art
  art="$(mktmp_file)"
  SPECKIT_ORCHESTRATOR_CORPUS_EXHAUSTION_ENABLED=false \
    bash "$ADAPTER" gate --strict --checkpoint sc3 --generated-at "$GEN_AT" \
      --manifest "$FIX/manifest-ok.yml" "$FIX/questions-mixed.txt" "$art" >/dev/null 2>&1
  [ "$?" -eq 1 ] || { echo "  expected exit 1 (strict+disabled), got $?" >&2; return 1; }
  return 0
}
check "SC-3a" "disabled feature emits SKIPPED + exit 0" sc3_skip_check
check "SC-3b" "strict + disabled exits 1" sc3_strict_check

# ===========================================================================
# SC-4: unreachable required store yields IRREDUCIBLE-WITH-CAVEAT, store named.
# ===========================================================================
sc4_check() {
  local art
  art="$(mktmp_file)"
  bash "$SWEEP" --questions "$FIX/questions-clean.txt" --checkpoint sc4 \
    --generated-at "$GEN_AT" --manifest "$FIX/manifest-caveat.yml" \
    --out "$art" >/dev/null 2>&1 || { echo "  sweep exited nonzero" >&2; return 1; }
  grep -qE '^### Q1 — IRREDUCIBLE-WITH-CAVEAT' "$art" \
    || { echo "  Q1 not IRREDUCIBLE-WITH-CAVEAT" >&2; return 1; }
  grep -q 'unreachable_required_stores: "missing-required"' "$art" \
    || { echo "  missing-required store not named in frontmatter" >&2; return 1; }
  return 0
}
check "SC-4" "unreachable required store -> IRREDUCIBLE-WITH-CAVEAT (named)" sc4_check

# ===========================================================================
# SC-5: parse-verdict emits verdict=PASS|BLOCK from an existing artifact.
# ===========================================================================
sc5_check() {
  local art v
  art="$(mktmp_file)"
  bash "$SWEEP" --questions "$FIX/questions-mixed.txt" --checkpoint sc5 \
    --generated-at "$GEN_AT" --manifest "$FIX/manifest-ok.yml" \
    --out "$art" >/dev/null 2>&1
  v="$(bash "$ADAPTER" parse-verdict "$art" 2>/dev/null)"
  [ "$v" = "verdict=BLOCK" ] || { echo "  parse-verdict got '$v', want verdict=BLOCK" >&2; return 1; }
  return 0
}
check "SC-5" "parse-verdict emits verdict=BLOCK from artifact" sc5_check

# ===========================================================================
# SC-6: P01 scripts are Bash 3.2-safe (syntax-valid; no Bash-4-only constructs).
# ===========================================================================
sc6_check() {
  bash -n "$SWEEP" || { echo "  sweep syntax error" >&2; return 1; }
  bash -n "$ADAPTER" || { echo "  adapter syntax error" >&2; return 1; }
  # Forbidden Bash 4+ constructs (CON-1): associative arrays, mapfile/readarray,
  # ${var,,}/${var^^} case modification. Strip full-line comments first so the
  # CON-1 doc-comments themselves don't trip the scan.
  local scanned
  scanned="$(grep -hvE '^[[:space:]]*#' "$SWEEP" "$ADAPTER" \
    | grep -E 'declare -A|mapfile|readarray|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,\}|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^\}')"
  if [ -n "$scanned" ]; then
    echo "  Bash 4+ construct found: $scanned" >&2
    return 1
  fi
  return 0
}
check "SC-6" "P01 scripts are Bash 3.2-safe (bash -n + no Bash-4 constructs)" sc6_check

# ===========================================================================
# Summary
# ===========================================================================
echo "---"
echo "BATTERY: pass=$pass skip=$skip fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
