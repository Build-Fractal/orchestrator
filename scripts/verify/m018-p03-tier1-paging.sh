#!/usr/bin/env bash
# scripts/verify/m018-p03-tier1-paging.sh — phase-truth verifier:
# "Tier 1 paging replaces oversized inline tool-result blocks with a
# `<tool-result file=...>` reference and persists the original to
# .orchestrator/cache/tool-results/<sha256>; the small block is left
# verbatim."
#
# Approach:
#   - Stage a hermetic fixture orch_root via _helpers/m018-p03-build-fixture.sh
#     (M018-fixture milestone, knowledge index empty, config tier1.enabled=true,
#     cache_dir under the staged tmp dir).
#   - Author a thin shim that sources scripts/lib/preservation-check.sh
#     (so pres_check_section is defined) plus the awk-extracted body of
#     _bc_apply_tier1 from build-context.sh, then runs _bc_apply_tier1
#     against the fixture payload and prints the rewritten contents.
#   - Assert: the post-paging payload contains a `<tool-result file="..."`
#     reference (big block was paged); the small "small.txt" line is
#     still present (small block passed through); a SHA-256-named cache
#     file appeared under cache_dir.
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
cat "$PAYLOAD"
SHIM_EOF
chmod +x "$SHIM"

OUT_FILE="$DEST/_paged.out"
if ! bash "$SHIM" "$REPO_ROOT" "$DEST" > "$OUT_FILE" 2>"$DEST/_shim.err"; then
  printf 'FAIL: shim invocation of _bc_apply_tier1 nonzero\n' >&2
  cat "$DEST/_shim.err" >&2
  exit 1
fi

if ! grep -q '<tool-result file="' "$OUT_FILE"; then
  printf 'FAIL: expected <tool-result file="..."> reference in paged payload\n' >&2
  exit 1
fi

if ! grep -q 'small.txt' "$OUT_FILE"; then
  printf 'FAIL: small block was paged (small.txt line missing — small block should pass through verbatim)\n' >&2
  exit 1
fi

# Cache file should be a 64-char SHA-256-named regular file under the cache dir.
CACHE_HIT=""
for f in "$DEST/cache/tool-results/"*; do
  if [ ! -f "$f" ]; then
    continue
  fi
  base="$(basename "$f")"
  case "$base" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
      CACHE_HIT="$f"
      break
      ;;
  esac
done

if [ -z "$CACHE_HIT" ]; then
  printf 'FAIL: expected SHA-256-named cache file under %s\n' "$DEST/cache/tool-results/" >&2
  ls -la "$DEST/cache/tool-results/" >&2 || true
  exit 1
fi

# The cache file body should still contain the marker text.
if ! grep -q 'repeating-content-marker' "$CACHE_HIT"; then
  printf 'FAIL: cache file body missing repeating-content-marker text (paging persistence broken)\n' >&2
  exit 1
fi

printf 'PASS: m018-p03-tier1-paging (big block paged, small block verbatim, cache file under %s)\n' "$DEST/cache/tool-results/"
exit 0
