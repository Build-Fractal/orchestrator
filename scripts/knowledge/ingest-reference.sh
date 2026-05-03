#!/usr/bin/env bash
# scripts/knowledge/ingest-reference.sh -- M036 P04 driver for
# orchestrator:ingest-reference. Walks knowledge/reference/<category>/
# REF-*.md, validates each chunk via the M036 classifier (FR-1 taxonomy
# + FR-2 required-field presence), gates re-ingest via content_hash
# idempotency, and rebuilds the knowledge index at the end.
#
# Consumes the chunk shape produced by scripts/knowledge/extract-reference.sh
# (M036/P02 + P03). For pre-populated reference roots (operator-authored
# REF chunks without going through extract), the same shape applies.
#
# Usage:
#   scripts/knowledge/ingest-reference.sh [--reference-root <path>]
#                                         [--no-index-rebuild]
#
# Output contract (stdout):
#   CREATED:  <chunk_id> category=<cat> tier=<n>
#   SKIPPED:  <chunk_id> reason=unchanged-content-hash
#   REJECTED: <chunk_id> reason=<missing-required-field|unknown-category>
#   BLOCKED:  <chunk_id> reason=tier-2-fidelity-gate
#   SUMMARY:  ingest-reference.sh created=<n> skipped=<n> rejected=<n> blocked=<n>
# Errors to stderr; non-zero exit on any unrecoverable error (per-chunk
# rejections do NOT abort the pass — partial-success ingest matching the
# spec-chunk classifier's tolerance).
#
# Bash 3.2 / POSIX-sh per CON-2. Idempotent (CON-4).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}"

# shellcheck disable=SC1091
. "$HERE/classify-reference.sh"
# shellcheck disable=SC1091
. "$HERE/lib/ingest-review-advisory.sh"     # M036/P06 T02

REF_ROOT="$ROOT/knowledge/reference"
NO_INDEX_REBUILD=0
DETECT_REMOVALS=0
PRIOR_MANIFEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --reference-root) REF_ROOT="$2"; shift 2 ;;
    --no-index-rebuild) NO_INDEX_REBUILD=1; shift ;;
    --detect-removals) DETECT_REMOVALS=1; shift ;;
    --prior-manifest) PRIOR_MANIFEST="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "ingest-reference.sh: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$REF_ROOT" ]; then
  # Backwards-compatibility green path (Edge Case: reference root does
  # not exist) — exit 0 with informational message. CON-1 preservation.
  echo "SUMMARY: ingest-reference.sh created=0 skipped=0 rejected=0 blocked=0 (no reference corpus configured)"
  exit 0
fi

created=0
skipped=0
rejected=0
blocked=0

# Probe sha256 binary (probe-and-fallback per M036/P02 pattern).
if command -v shasum >/dev/null 2>&1; then
  HASH_BIN="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  HASH_BIN="sha256sum"
else
  echo "ingest-reference.sh: neither shasum nor sha256sum available" >&2
  exit 1
fi

# Compute body sha256 for a chunk file (body = content after the second
# frontmatter `---` line). T02's idempotency path compares this to the
# `content_hash:` frontmatter field.
body_sha256() {
  local f="$1"
  awk '/^---$/{c++; next} c>=2{print}' "$f" | $HASH_BIN | awk '{print $1}'
}

# Read a single-line frontmatter field value (strip leading
# whitespace + surrounding double quotes).
fm_field() {
  local f="$1"
  local k="$2"
  grep -E "^${k}:" "$f" | head -n 1 | sed -E "s/^${k}:[[:space:]]*//" | sed -E 's/^"//; s/"$//'
}

# Walk the four taxonomy categories. Anything NOT in this list (e.g.
# _negative/) is silently skipped per the T01 fixture-corpus convention.
for category in cms-rule training-material glossary regulatory-doc; do
  cat_dir="$REF_ROOT/$category"
  if [ ! -d "$cat_dir" ]; then
    continue
  fi
  # Walk REF-*.md but EXCLUDE *.text.md and *.structured.md (those are
  # extraction-artifact siblings, not graph entries).
  for chunk in "$cat_dir"/REF-*.md; do
    if [ ! -f "$chunk" ]; then
      continue
    fi
    base="$(basename "$chunk")"
    case "$base" in
      *.text.md|*.structured.md)
        continue
        ;;
    esac

    chunk_id="$(fm_field "$chunk" chunk_id)"
    if [ -z "$chunk_id" ]; then
      chunk_id="$(fm_field "$chunk" id)"
    fi
    if [ -z "$chunk_id" ]; then
      chunk_id="$(basename "$chunk" .md)"
    fi

    # FR-1 + FR-2 classifier check. Per-chunk rejection — partial success.
    if ! classify_reference_file "$chunk" 2>/tmp/m036-p04-classify-err.$$.txt; then
      reason="$(grep -E 'required field|taxonomy' /tmp/m036-p04-classify-err.$$.txt | head -n 1 | sed -E 's/^[^:]*: //')"
      [ -z "$reason" ] && reason="unknown-classifier-error"
      echo "REJECTED: $chunk_id reason=$reason"
      rejected=$((rejected + 1))
      rm -f /tmp/m036-p04-classify-err.$$.txt
      continue
    fi
    rm -f /tmp/m036-p04-classify-err.$$.txt

    # Tier 2 BLOCK-verdict gate (T03 fills in the advisory emission;
    # T02 reads the field for the idempotency path).
    tier_2_verdict="$(fm_field "$chunk" tier_2_verdict)"

    # Idempotency gate: if the chunk's frontmatter content_hash matches
    # the body sha256, emit SKIPPED: reason=unchanged-content-hash.
    fm_hash="$(fm_field "$chunk" content_hash)"
    body_hash="$(body_sha256 "$chunk")"
    tier="$(fm_field "$chunk" tier)"
    [ -z "$tier" ] && tier="unknown"

    if [ -n "$fm_hash" ] && [ "$fm_hash" = "$body_hash" ]; then
      echo "SKIPPED: $chunk_id reason=unchanged-content-hash"
      skipped=$((skipped + 1))
      continue
    fi

    # T03 owns the BLOCK-advisory emission. T02's behavior: if the
    # tier_2_verdict field is BLOCK, emit BLOCKED: + still record as a
    # graph entry (the Tier 0 chunk persists per FR-18; only the
    # .structured.md sibling is withheld, and that withholding happens
    # at extract-time in P03, not at ingest-time here). T03 will move
    # this branch to also bump the `blocked` counter and emit the
    # BLOCKED: stdout line; for T02, behavior is "fall through to
    # CREATED:" so the test fixtures continue to flow. T03's verifier
    # m036-p04-tier-2-block-not-promoted.sh will update the expected
    # behavior when T03 lands the BLOCK gating branch.
    if [ "$tier_2_verdict" = "BLOCK" ]; then
      echo "BLOCKED: $chunk_id reason=tier-2-fidelity-gate"
      blocked=$((blocked + 1))
      # CRITICAL: per FR-18 the Tier 0 chunk persists; the .structured.md
      # sibling MUST NOT be auto-promoted. Ingest verifies the absence
      # of the .structured.md file and proceeds without emitting CREATED.
      structured="$cat_dir/$(basename "$chunk" .md).structured.md"
      if [ -f "$structured" ]; then
        echo "ingest-reference.sh: WARNING: BLOCK-verdict chunk has unexpected .structured.md sibling at $structured (FR-18 violation; consult P03 retention contract)" >&2
      fi
      continue
    fi

    echo "CREATED: $chunk_id category=$category tier=$tier"
    created=$((created + 1))
  done
done

# M036/P06 T02: cross-citer REVIEW: advisory pass. Walks the
# reference root for chunks with superseded_by: frontmatter and
# emits a REVIEW: line for each citer. If --detect-removals is
# set and --prior-manifest is supplied, also walks chunks present
# in the prior manifest but absent from the current corpus and
# emits REMOVED: + REVIEW: lines. Advisory only -- never blocks.
review_emit_for_superseded_chunks "$REF_ROOT"
if [ "$DETECT_REMOVALS" -eq 1 ] && [ -n "$PRIOR_MANIFEST" ]; then
  review_emit_for_removed_chunks "$REF_ROOT" "$PRIOR_MANIFEST"
fi

echo "SUMMARY: ingest-reference.sh created=$created skipped=$skipped rejected=$rejected blocked=$blocked"

# Rebuild index (unless --no-index-rebuild). Single-script-file
# invocation — the rebuilder discovers chunks via its own glob (now
# extended to recognize REF-*).
if [ "$NO_INDEX_REBUILD" -eq 0 ]; then
  REBUILDER="$ROOT/scripts/knowledge/rebuild-index.sh"
  if [ -f "$REBUILDER" ]; then
    bash "$REBUILDER" >/dev/null 2>&1 || {
      echo "ingest-reference.sh: rebuild-index.sh failed (non-fatal; chunks are on disk; index may be stale)" >&2
    }
  fi
fi

exit 0
