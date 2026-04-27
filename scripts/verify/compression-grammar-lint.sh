#!/usr/bin/env bash
# scripts/verify/compression-grammar-lint.sh — Public lint gate for the
# M018 Compression Grammar contract (FR-1 / SC-1).
#
# Parses references/compression-grammar.md (or a path supplied as $1) and
# asserts the document carries the load-bearing structure described by
# T01's grammar:
#
#   - Frontmatter (schema_version, type, version, status, last_revised).
#   - `# Compression Grammar` title.
#   - `## Marker Grammar` section that names `compressed:tier`.
#   - `## Preserved-Pattern Vocabulary` section.
#   - Four `## Tier:` sections (filter, tier1, tier2, tier3).
#   - Each tier carries `**applies-to:**` AND `**preserves:**` blocks
#     with at least one bullet each.
#   - `## Aggregate Plausibility (SC-9)` section naming `34.7`.
#   - `## Additive Emitter Invariants (CON-5)` section.
#   - `## Failure Semantics (FR-2)` section naming
#     `tier_preservation_violation`.
#   - Zero `<TODO:` markers.
#
# For each (tier, artifact-class, preserved-pattern) triple actually
# present in the document, emits one PASS line in the shape:
#   PASS: tier <name> applies-to:<class> preserves:<pattern>
# (SC-1 / FR-1 "one row per triple" requirement.)
#
# Exit 0 on clean, 1 on file-not-found / structural failure / contract
# violation. Failures emit FAIL: lines naming the missing block.
#
# AD-19 single-script-file shape: no compound &&-chains > 2; no
# $(... | ...) substitutions; no process substitution. Bash 3.2 compatible.
# AP-009: shape-guard friendly. MEM001: structured PASS/FAIL stdout, exit 0/1.

set -eu

GRAMMAR="${1:-references/compression-grammar.md}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ "${GRAMMAR#/}" = "$GRAMMAR" ]; then
  GRAMMAR="$REPO_ROOT/$GRAMMAR"
fi

if [ ! -f "$GRAMMAR" ]; then
  printf 'FAIL: file not found: %s\n' "$GRAMMAR" >&2
  exit 1
fi

FAIL_COUNT=0

emit_fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

emit_pass() {
  printf 'PASS: %s\n' "$1"
}

# --- Frontmatter checks ---------------------------------------------------

# Pull lines 1..N where N is the second '---' delimiter line number.
# Bash 3.2 safe — single-pipe awk extraction to a temp file.
TMPDIR_L="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_L"' EXIT INT TERM

FM_FILE="$TMPDIR_L/frontmatter"
awk '
  BEGIN { state = 0 }
  /^---$/ {
    state++
    if (state == 1) { next }
    if (state == 2) { exit }
  }
  state == 1 { print }
' "$GRAMMAR" > "$FM_FILE"

fm_missing=""
for key in schema_version type version status last_revised; do
  if ! grep -q "^${key}:" "$FM_FILE"; then
    fm_missing="$fm_missing $key"
  fi
done

if [ -n "$fm_missing" ]; then
  emit_fail "frontmatter missing keys:$fm_missing"
else
  emit_pass "frontmatter present (schema_version, type, version, status, last_revised)"
fi

# Type must be exactly compression-grammar.
if grep -q '^type:[[:space:]]*compression-grammar' "$FM_FILE"; then
  :
else
  emit_fail "frontmatter type field is not 'compression-grammar'"
fi

# --- Title check ----------------------------------------------------------

if grep -q '^# Compression Grammar$' "$GRAMMAR"; then
  emit_pass "title '# Compression Grammar' present"
else
  emit_fail "title '# Compression Grammar' missing"
fi

# --- Marker Grammar section ----------------------------------------------

MG_FILE="$TMPDIR_L/marker-grammar"
awk '
  /^## Marker Grammar/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "$GRAMMAR" > "$MG_FILE"

if [ -s "$MG_FILE" ]; then
  if grep -q 'compressed:tier' "$MG_FILE"; then
    emit_pass "marker grammar section present"
  else
    emit_fail "marker grammar section missing literal 'compressed:tier'"
  fi
else
  emit_fail "marker grammar section absent"
fi

# --- Preserved-Pattern Vocabulary section --------------------------------

if grep -q '^## Preserved-Pattern Vocabulary' "$GRAMMAR"; then
  emit_pass "preserved-pattern vocabulary section present"
else
  emit_fail "preserved-pattern vocabulary section missing"
fi

# --- Tier sections --------------------------------------------------------

# Verify all four tier headings exist.
for tname in filter tier1 tier2 tier3; do
  if ! grep -q "^## Tier: ${tname}$" "$GRAMMAR"; then
    emit_fail "tier section missing: ## Tier: ${tname}"
  fi
done

# For each tier section, slice it into a temp file. Then verify
# **applies-to:** AND **preserves:** blocks each have >=1 bullet.
TIER_NAMES_FILE="$TMPDIR_L/tier-names"
printf 'filter\ntier1\ntier2\ntier3\n' > "$TIER_NAMES_FILE"

while IFS= read -r tname; do
  TIER_FILE="$TMPDIR_L/tier-${tname}"
  # Extract from `## Tier: <tname>` until the next `## ` or `---` divider.
  awk -v target="## Tier: ${tname}" '
    $0 == target { capture = 1; next }
    capture && /^## / { capture = 0 }
    capture && /^---$/ { capture = 0 }
    capture { print }
  ' "$GRAMMAR" > "$TIER_FILE"

  if [ ! -s "$TIER_FILE" ]; then
    # Already reported the missing heading above; skip body checks.
    continue
  fi

  # --- applies-to bullets ---
  AT_FILE="$TMPDIR_L/tier-${tname}-applies"
  awk '
    /^\*\*applies-to:\*\*/ { capture = 1; next }
    capture && /^\*\*/ { capture = 0 }
    capture && /^## / { capture = 0 }
    capture && /^- / { print }
  ' "$TIER_FILE" > "$AT_FILE"

  AT_COUNT=$(wc -l < "$AT_FILE" | tr -d ' ')
  if [ "$AT_COUNT" -lt 1 ]; then
    emit_fail "tier ${tname} missing applies-to bullets"
  fi

  # --- preserves bullets ---
  PR_FILE="$TMPDIR_L/tier-${tname}-preserves"
  awk '
    /^\*\*preserves:\*\*/ { capture = 1; next }
    capture && /^\*\*/ { capture = 0 }
    capture && /^## / { capture = 0 }
    capture && /^- / { print }
  ' "$TIER_FILE" > "$PR_FILE"

  PR_COUNT=$(wc -l < "$PR_FILE" | tr -d ' ')
  if [ "$PR_COUNT" -lt 1 ]; then
    emit_fail "tier ${tname} missing preserves bullets"
  fi

  # Emit one PASS per (tier, applies-to-class, preserves-pattern) triple.
  # Class extraction: take the first inline-code-fenced token in each
  # applies-to bullet (e.g. `knowledge-entry`); fall back to the entire
  # bullet text trimmed.
  # Pattern extraction: take the first inline-code-fenced token in each
  # preserves bullet; fall back to bullet text trimmed.
  AT_CLASSES="$TMPDIR_L/tier-${tname}-classes"
  PR_PATTERNS="$TMPDIR_L/tier-${tname}-patterns"
  awk '
    {
      # Strip leading "- "
      sub(/^- /, "", $0)
      # First backtick-fenced token wins.
      if (match($0, /`[^`]+`/)) {
        cls = substr($0, RSTART + 1, RLENGTH - 2)
      } else {
        cls = $0
      }
      print cls
    }
  ' "$AT_FILE" > "$AT_CLASSES"

  awk '
    {
      sub(/^- /, "", $0)
      if (match($0, /`[^`]+`/)) {
        pat = substr($0, RSTART + 1, RLENGTH - 2)
      } else {
        # Trim to first 60 chars for printable PASS line.
        pat = substr($0, 1, 60)
      }
      print pat
    }
  ' "$PR_FILE" > "$PR_PATTERNS"

  # Cross-product: for each class, for each pattern -> emit triple.
  while IFS= read -r cls; do
    while IFS= read -r pat; do
      emit_pass "tier ${tname} applies-to:${cls} preserves:${pat}"
    done < "$PR_PATTERNS"
  done < "$AT_CLASSES"
done < "$TIER_NAMES_FILE"

# --- Aggregate Plausibility (SC-9) section -------------------------------

SC9_FILE="$TMPDIR_L/sc9"
awk '
  /^## Aggregate Plausibility \(SC-9\)/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "$GRAMMAR" > "$SC9_FILE"

if [ -s "$SC9_FILE" ]; then
  if grep -q '34\.7' "$SC9_FILE"; then
    emit_pass "SC-9 plausibility section names 34.7 floor"
  else
    emit_fail "SC-9 plausibility section missing literal '34.7'"
  fi
else
  emit_fail "SC-9 plausibility section absent"
fi

# --- Additive Emitter Invariants (CON-5) section -------------------------

if grep -q '^## Additive Emitter Invariants (CON-5)' "$GRAMMAR"; then
  emit_pass "additive emitter invariants section present (CON-5)"
else
  emit_fail "additive emitter invariants section missing"
fi

# --- Failure Semantics (FR-2) section ------------------------------------

FS_FILE="$TMPDIR_L/failure-semantics"
awk '
  /^## Failure Semantics \(FR-2\)/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "$GRAMMAR" > "$FS_FILE"

if [ -s "$FS_FILE" ]; then
  if grep -q 'tier_preservation_violation' "$FS_FILE"; then
    emit_pass "failure semantics section names tier_preservation_violation"
  else
    emit_fail "failure semantics section missing 'tier_preservation_violation'"
  fi
else
  emit_fail "failure semantics section absent"
fi

# --- TODO marker check ---------------------------------------------------

TODO_COUNT=$(grep -c '<TODO:' "$GRAMMAR" || true)
TODO_COUNT=${TODO_COUNT:-0}
if [ "$TODO_COUNT" -gt 0 ]; then
  emit_fail "document carries ${TODO_COUNT} <TODO: marker(s)"
else
  emit_pass "document has zero <TODO: markers"
fi

# --- Summary -------------------------------------------------------------

if [ "$FAIL_COUNT" -gt 0 ]; then
  printf 'FAIL: compression-grammar-lint failed (%d issue(s))\n' "$FAIL_COUNT" >&2
  exit 1
fi

exit 0
