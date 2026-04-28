#!/usr/bin/env bash
# M018/P03/T02: cache-prune.sh — Tier 1 tool-result cache eviction by mtime.
#
# Usage:
#   bash scripts/util/cache-prune.sh --max-age 7d
#   bash scripts/util/cache-prune.sh --max-age 24h --dry-run
#   bash scripts/util/cache-prune.sh --max-age 60m
#
# Reads compression.tier1.cache_dir from .orchestrator/config.yml; falls
# back to .orchestrator/cache/tool-results/ relative to the project root.
# Removes regular files older than the configured age; never recurses
# into sub-directories (so future tier-3-originals/ co-tenants are
# untouched). Idempotent — running twice in succession is a no-op on
# the second call.
#
# Reference-aware preservation (acceptance scenario 5 second clause —
# preserving entries still referenced in execution-log.jsonl) is an
# explicit M018 follow-up. The current cache key surface (full SHA-256
# hex over command + 0x1F + input, dispatch-time-only writes) makes
# mtime-only prune correct for M018.
#
# Bash 3.2 + AP-009 compliant: no compound chains > 2, no plain
# subshells in inline shape, no $(... | ...).

set -eu

MAX_AGE=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --max-age)
      shift
      MAX_AGE="${1:-}"
      ;;
    --max-age=*)
      MAX_AGE="${1#--max-age=}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: cache-prune.sh [--max-age <duration>] [--dry-run]

  --max-age <N>d|<N>h|<N>m  Prune files older than this age. Default: 7d.
  --dry-run                  Print what would be pruned; do not remove.

Reads compression.tier1.cache_dir from .orchestrator/config.yml.
USAGE
      exit 0
      ;;
    *)
      printf 'cache-prune.sh: unrecognized argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ -z "$MAX_AGE" ]; then
  MAX_AGE="7d"
fi

# Parse <N>d / <N>h / <N>m into seconds. The unit is the trailing single
# character; the numeric prefix is everything before it.
_unit="${MAX_AGE#"${MAX_AGE%?}"}"
_num="${MAX_AGE%?}"
case "$_num" in
  ''|*[!0-9]*)
    printf 'cache-prune.sh: malformed --max-age value: %s\n' "$MAX_AGE" >&2
    exit 1
    ;;
esac
case "$_unit" in
  d) MAX_AGE_SECONDS=$(( _num * 86400 )) ;;
  h) MAX_AGE_SECONDS=$(( _num * 3600  )) ;;
  m) MAX_AGE_SECONDS=$(( _num * 60    )) ;;
  *)
    printf 'cache-prune.sh: unrecognized --max-age unit (need d|h|m): %s\n' "$MAX_AGE" >&2
    exit 1
    ;;
esac

# Resolve project root: walk up from cwd first (so a verifier or operator
# invoking from a fixture/tmp tree can override). If no config.yml is found
# above cwd, fall back to walking up from $0's directory (handles the
# "operator runs `bash /abs/path/cache-prune.sh` from /" case).
PROJECT_ROOT=""
_cwd="$(pwd)"
_probe="$_cwd"
while [ "$_probe" != "/" ]; do
  if [ -f "$_probe/.orchestrator/config.yml" ]; then
    PROJECT_ROOT="$_probe"
    break
  fi
  _probe="$(dirname "$_probe")"
done

if [ -z "$PROJECT_ROOT" ]; then
  SCRIPT_DIR_PARENT="$(dirname "$0")"
  cd "$SCRIPT_DIR_PARENT"
  SCRIPT_DIR="$(pwd)"
  cd "$_cwd"
  PROJECT_ROOT="$SCRIPT_DIR"
  while [ "$PROJECT_ROOT" != "/" ]; do
    if [ -f "$PROJECT_ROOT/.orchestrator/config.yml" ]; then
      break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
  done
fi

CACHE_DIR=""
if [ -f "$PROJECT_ROOT/.orchestrator/config.yml" ]; then
  # Read compression.tier1.cache_dir via single awk pass. Tracks indent
  # entry into the tier1 block; resets when a non-indented top-level key
  # appears.
  CACHE_DIR="$(awk '
    BEGIN { in_t1=0 }
    /^[[:space:]]*tier1:[[:space:]]*$/ { in_t1=1; next }
    in_t1==1 && /^[[:space:]]*cache_dir:[[:space:]]/ {
      sub(/^[[:space:]]*cache_dir:[[:space:]]*/, "")
      gsub(/^["\047]|["\047]$/, "")
      print
      exit
    }
    in_t1==1 && /^[^[:space:]]/ { in_t1=0 }
  ' "$PROJECT_ROOT/.orchestrator/config.yml")"
fi

if [ -z "$CACHE_DIR" ]; then
  CACHE_DIR=".orchestrator/cache/tool-results/"
fi

# Resolve relative cache paths against project root.
case "$CACHE_DIR" in
  /*) : ;;
  *)  CACHE_DIR="$PROJECT_ROOT/$CACHE_DIR" ;;
esac

if [ ! -d "$CACHE_DIR" ]; then
  printf 'SUMMARY: pruned=0 kept=0 total=0 bytes_freed=0 (cache dir absent: %s)\n' "$CACHE_DIR"
  exit 0
fi

NOW="$(date -u +%s)"
CUTOFF=$(( NOW - MAX_AGE_SECONDS ))

PRUNED=0
KEPT=0
TOTAL=0
BYTES_FREED=0

# Detect stat flavor once: macOS uses `stat -f`, Linux uses `stat -c`.
STAT_FLAVOR="bsd"
if ! stat -f %m "$0" >/dev/null 2>&1; then
  STAT_FLAVOR="gnu"
fi

# Single-level walk only. The `for f in "$CACHE_DIR"/*` glob is bash 3.2
# safe; cache filenames are SHA-256 hex digests (no spaces). Skip
# sub-directories so future tier-3-originals/ co-tenants stay untouched.
shopt -s nullglob 2>/dev/null || true
for f in "$CACHE_DIR"/*; do
  if [ ! -f "$f" ]; then
    continue
  fi
  TOTAL=$(( TOTAL + 1 ))
  if [ "$STAT_FLAVOR" = "bsd" ]; then
    mtime="$(stat -f %m "$f")"
    fsize="$(stat -f %z "$f")"
  else
    mtime="$(stat -c %Y "$f")"
    fsize="$(stat -c %s "$f")"
  fi
  if [ "$mtime" -lt "$CUTOFF" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      printf 'WOULD-PRUNE: %s (mtime=%s size=%s)\n' "$f" "$mtime" "$fsize"
    else
      rm -f "$f"
      printf 'PRUNED: %s\n' "$f"
    fi
    PRUNED=$(( PRUNED + 1 ))
    BYTES_FREED=$(( BYTES_FREED + fsize ))
  else
    KEPT=$(( KEPT + 1 ))
  fi
done

printf 'SUMMARY: pruned=%d kept=%d total=%d bytes_freed=%d\n' "$PRUNED" "$KEPT" "$TOTAL" "$BYTES_FREED"
exit 0
