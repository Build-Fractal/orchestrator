#!/usr/bin/env bash
# scripts/migrate/m014-p02-migrate-recent-changes.sh — one-time migration.
# Moves pre-existing ## Recent Changes entries into the orchestrator:recent-changes
# marker region, drops stale dogfood entries, regenerates AGENTS.md to byte-match.
#
# Usage:
#   m014-p02-migrate-recent-changes.sh [--root <project-root>] [--dry-run|--apply] [--force]
#
# Idempotent: re-running exits 0 with "SUMMARY: already-migrated" and no writes.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MODE="dry-run"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)    PROJECT_ROOT="$2"; shift 2 ;;
    --dry-run) MODE="dry-run"; shift ;;
    --apply)   MODE="apply"; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# //'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
AGENTS_MD="$PROJECT_ROOT/AGENTS.md"
HELPER="$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh"

if [ ! -f "$CLAUDE_MD" ]; then
  echo "FAIL: CLAUDE.md missing at $CLAUDE_MD" >&2
  exit 1
fi
if [ ! -x "$HELPER" ]; then
  echo "FAIL: dual-write-runtime-md.sh missing or not executable" >&2
  exit 1
fi

# --- Detect already-migrated state ---
# Signals: marker region exists, contains >1 entry OR no stale dogfood entry,
# AND the legacy `## Recent Changes` section is absent from CLAUDE.md.
has_marker=0
if grep -qF '# >>> orchestrator:recent-changes >>>' "$CLAUDE_MD"; then has_marker=1; fi

has_legacy_section=0
# Look for `## Recent Changes` line AFTER the closing marker.
if awk '
  /^# <<< orchestrator:recent-changes <<</ { past_marker=1; next }
  past_marker==1 && /^## Recent Changes/ { print "found"; exit 0 }
' "$CLAUDE_MD" | grep -q found; then
  has_legacy_section=1
fi

has_stale_dogfood=0
if awk '
  /^# >>> orchestrator:recent-changes >>>/ { in_r=1; next }
  /^# <<< orchestrator:recent-changes <<</ { in_r=0; next }
  in_r==1 && /^- 021-test-exporter: foo/ { print "found"; exit 0 }
' "$CLAUDE_MD" | grep -q found; then
  has_stale_dogfood=1
fi

# Already-migrated = marker present, no stale dogfood, no legacy section below marker.
if [ "$has_marker" -eq 1 ] && [ "$has_stale_dogfood" -eq 0 ] && [ "$has_legacy_section" -eq 0 ] && [ "$FORCE" -eq 0 ]; then
  echo "SUMMARY: already-migrated"
  exit 0
fi

# --- Extract legacy section entries (if any) ---
LEGACY_ENTRIES="$(mktemp)"
trap 'rm -f "$LEGACY_ENTRIES"' EXIT

awk '
  /^# <<< orchestrator:recent-changes <<</ { past_marker=1; next }
  past_marker==1 && /^## Recent Changes/ { in_legacy=1; next }
  in_legacy==1 && /^## / { in_legacy=0 }
  in_legacy==1 && /^- / { print }
' "$CLAUDE_MD" > "$LEGACY_ENTRIES"

LEGACY_COUNT=$(wc -l < "$LEGACY_ENTRIES" | tr -d ' ')

# --- Build the merged fragment (legacy entries preserved, stale dogfood dropped) ---
MERGED_FRAG="$(mktemp)"
trap 'rm -f "$LEGACY_ENTRIES" "$MERGED_FRAG"' EXIT

cat "$LEGACY_ENTRIES" > "$MERGED_FRAG"

# --- Dry-run: emit manifest records, no writes ---
if [ "$MODE" = "dry-run" ]; then
  printf '{"command":"m014-p02-migrate-recent-changes","action_type":"drop-stale-marker-entry","target_path":"%s","source_ref":"recent-changes","description":"remove 021-test-exporter stale dogfood entry"}\n' "$CLAUDE_MD"
  printf '{"command":"m014-p02-migrate-recent-changes","action_type":"migrate-legacy-section","target_path":"%s","source_ref":"## Recent Changes","description":"move %d legacy entries into marker region"}\n' "$CLAUDE_MD" "$LEGACY_COUNT"
  printf '{"command":"m014-p02-migrate-recent-changes","action_type":"dual-write-region","target_path":"%s","source_ref":"recent-changes","description":"regenerate region byte-identically in both files"}\n' "$PROJECT_ROOT/CLAUDE.md-and-AGENTS.md"
  echo "SUMMARY: dry-run legacy_entries=$LEGACY_COUNT has_stale=$has_stale_dogfood has_legacy_section=$has_legacy_section"
  exit 0
fi

# --- Apply mode: rewrite CLAUDE.md ---

# 1. Strip the existing marker region from CLAUDE.md entirely (it will be re-inserted
#    by the dual-write helper).
STRIPPED="$(mktemp)"
awk '
  /^# >>> orchestrator:recent-changes >>>/ { in_r=1; next }
  /^# <<< orchestrator:recent-changes <<</ { in_r=0; next }
  in_r != 1 { print }
' "$CLAUDE_MD" > "$STRIPPED"

# 2. Strip the legacy `## Recent Changes` section and its `- ` entries through the next
#    `## ` header or EOF.
STRIPPED2="$(mktemp)"
awk '
  /^## Recent Changes$/ { in_legacy=1; next }
  in_legacy==1 && /^## / && $0 != "## Recent Changes" { in_legacy=0 }
  in_legacy==1 { next }
  { print }
' "$STRIPPED" > "$STRIPPED2"

mv "$STRIPPED2" "$CLAUDE_MD"
rm -f "$STRIPPED"

# 3. Delete the stale AGENTS.md so the helper recreates it clean with matching region.
rm -f "$AGENTS_MD"

# 4. Use the helper to insert the merged marker region into both files.
if ! bash "$HELPER" \
    --marker recent-changes \
    --content "$MERGED_FRAG" \
    --root "$PROJECT_ROOT" \
    --file CLAUDE.md --file AGENTS.md; then
  echo "FAIL: dual-write helper failed during migration" >&2
  exit 1
fi

echo "SUMMARY: applied legacy_entries=$LEGACY_COUNT stale_dogfood_removed=$has_stale_dogfood"
exit 0
