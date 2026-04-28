#!/usr/bin/env bash
# scripts/verify/m018-p03-cache-reuse.sh — phase-truth verifier:
# "A second dispatch with an identical tool-call (matched on SHA-256 of
# command+input) reuses the same cache entry without rewriting the
# file (mtime preserved)."
#
# Approach:
#   - Stage a fixture orch_root via the helper.
#   - Run _bc_apply_tier1 once; capture the cache file's mtime.
#   - Restore the pre-paging payload, sleep 1s for mtime resolution,
#     run _bc_apply_tier1 a second time; assert the cache file's mtime
#     is unchanged across the two passes.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p03-build-fixture.sh"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
PRES="$REPO_ROOT/scripts/lib/preservation-check.sh"

for p in "$HELPER" "$BC" "$PRES"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM
bash "$HELPER" "$DEST" >/dev/null

PAYLOAD="$DEST/_fixture-payloads/payload.md"
PAYLOAD_BACKUP="$DEST/_fixture-payloads/payload-backup.md"
cp "$PAYLOAD" "$PAYLOAD_BACKUP"

SHIM="$DEST/_shim.sh"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -u
REPO_ROOT="$1"
DEST="$2"
ORCH_ROOT="$DEST"
TMPDIR_BUILD="$(mktemp -d)"
COMPRESSION_ENABLED=true
TIER1_ENABLED=true
TIER1_INLINE_THRESHOLD_TOKENS=1500
TIER1_PREVIEW_LINES=5
TIER1_CACHE_DIR="$DEST/cache/tool-results/"
MILESTONE_ID=M018-fixture
PHASE_ID=P03
TASK_ID=T01
. "$REPO_ROOT/scripts/lib/preservation-check.sh"
SCRATCH="$(mktemp)"
awk '/^_bc_apply_tier1\(\)/,/^}$/' "$REPO_ROOT/scripts/dispatch/build-context.sh" > "$SCRATCH"
. "$SCRATCH"
PAYLOAD="$DEST/_fixture-payloads/payload.md"
_bc_apply_tier1 "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

# First paging pass.
if ! bash "$SHIM" "$REPO_ROOT" "$DEST" >/dev/null 2>"$DEST/_shim.err"; then
  printf 'FAIL: first shim invocation nonzero\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

CACHE_FILE=""
for f in "$DEST/cache/tool-results/"*; do
  if [ -f "$f" ]; then
    CACHE_FILE="$f"
    break
  fi
done

if [ -z "$CACHE_FILE" ]; then
  printf 'FAIL: cache file missing after first pass\n' >&2
  exit 1
fi

if stat -f %m "$CACHE_FILE" >/dev/null 2>&1; then
  STAT_FLAVOR="bsd"
else
  STAT_FLAVOR="gnu"
fi

if [ "$STAT_FLAVOR" = "bsd" ]; then
  MTIME1="$(stat -f %m "$CACHE_FILE")"
else
  MTIME1="$(stat -c %Y "$CACHE_FILE")"
fi

# Restore original payload + sleep so mtime resolution can register a delta if it fires.
cp "$PAYLOAD_BACKUP" "$PAYLOAD"
sleep 1

if ! bash "$SHIM" "$REPO_ROOT" "$DEST" >/dev/null 2>"$DEST/_shim.err"; then
  printf 'FAIL: second shim invocation nonzero\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

if [ ! -f "$CACHE_FILE" ]; then
  printf 'FAIL: cache file disappeared after second pass\n' >&2
  exit 1
fi

if [ "$STAT_FLAVOR" = "bsd" ]; then
  MTIME2="$(stat -f %m "$CACHE_FILE")"
else
  MTIME2="$(stat -c %Y "$CACHE_FILE")"
fi

if [ "$MTIME1" != "$MTIME2" ]; then
  printf 'FAIL: cache-reuse expected mtime preserved (%s != %s)\n' "$MTIME1" "$MTIME2" >&2
  exit 1
fi

printf 'PASS: m018-p03-cache-reuse (mtime preserved across two paging passes: %s)\n' "$MTIME1"
exit 0
