#!/usr/bin/env bash
# scripts/verify/m018-p03-cache-prune.sh — phase-truth verifier:
# "scripts/util/cache-prune.sh --max-age 7d removes cache files older
# than 7d by mtime and leaves newer files alone; safe to invoke
# against an empty or missing cache directory."
#
# Approach:
#   - Stage a hermetic fixture orch_root (so cache-prune.sh's config
#     lookup finds an .orchestrator/config.yml whose tier1.cache_dir
#     points at the staged tmp cache).
#   - Drop two files into the cache: one with mtime backdated to 30
#     days ago (should be pruned), one with current mtime (should
#     survive).
#   - Invoke `cache-prune.sh --max-age 7d`; assert SUMMARY: pruned=1
#     kept=1; assert backdated file gone, fresh file present, exit 0.
#   - Re-invoke; assert idempotency (pruned=0 kept=1 total=1, exit 0).
#   - Tear down cache dir; re-invoke (`cache-prune.sh --max-age 7d`);
#     assert it survives a missing cache dir (exit 0; SUMMARY indicates
#     cache dir absent).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRUNE="$REPO_ROOT/scripts/util/cache-prune.sh"

if [ ! -f "$PRUNE" ]; then
  printf 'FAIL: prerequisite missing: %s\n' "$PRUNE" >&2
  exit 1
fi

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST"' EXIT INT TERM

# Stage a project-root layout cache-prune.sh accepts: walks up from cwd
# looking for .orchestrator/config.yml.
mkdir -p "$DEST/.orchestrator/cache/tool-results"
cat > "$DEST/.orchestrator/config.yml" <<EOF
compression:
  enabled: true
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
    cache_dir: $DEST/.orchestrator/cache/tool-results/
EOF

OLD_FILE="$DEST/.orchestrator/cache/tool-results/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
NEW_FILE="$DEST/.orchestrator/cache/tool-results/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
printf 'old body\n' > "$OLD_FILE"
printf 'new body\n' > "$NEW_FILE"

# Backdate OLD_FILE to 30 days ago. macOS touch -t accepts [[CC]YY]MMDDhhmm[.SS].
BACK_TS="$(date -u -v-30d +%Y%m%d%H%M.%S 2>/dev/null || date -u -d '30 days ago' +%Y%m%d%H%M.%S)"
if ! touch -t "$BACK_TS" "$OLD_FILE"; then
  printf 'FAIL: failed to backdate test cache file\n' >&2
  exit 1
fi

# --- First invocation: prune old, keep new. ---
RUN1_OUT="$DEST/_run1.out"
if ! (cd "$DEST" && bash "$PRUNE" --max-age 7d) > "$RUN1_OUT" 2>"$DEST/_run1.err"; then
  printf 'FAIL: cache-prune.sh first invocation nonzero\n' >&2
  cat "$DEST/_run1.err" >&2
  exit 1
fi

if ! grep -q '^SUMMARY: pruned=1 kept=1 total=2' "$RUN1_OUT"; then
  printf 'FAIL: first invocation did not report pruned=1 kept=1 total=2\n' >&2
  cat "$RUN1_OUT" >&2
  exit 1
fi
if [ -f "$OLD_FILE" ]; then
  printf 'FAIL: backdated cache file still present after prune: %s\n' "$OLD_FILE" >&2
  exit 1
fi
if [ ! -f "$NEW_FILE" ]; then
  printf 'FAIL: fresh cache file removed by prune (expected to survive): %s\n' "$NEW_FILE" >&2
  exit 1
fi

# --- Second invocation: idempotency check. ---
RUN2_OUT="$DEST/_run2.out"
if ! (cd "$DEST" && bash "$PRUNE" --max-age 7d) > "$RUN2_OUT" 2>"$DEST/_run2.err"; then
  printf 'FAIL: cache-prune.sh second invocation nonzero\n' >&2
  cat "$DEST/_run2.err" >&2
  exit 1
fi
if ! grep -q '^SUMMARY: pruned=0 kept=1 total=1' "$RUN2_OUT"; then
  printf 'FAIL: second invocation did not report pruned=0 kept=1 total=1 (idempotency)\n' >&2
  cat "$RUN2_OUT" >&2
  exit 1
fi

# --- Third invocation: missing cache dir. ---
rm -rf "$DEST/.orchestrator/cache"
RUN3_OUT="$DEST/_run3.out"
if ! (cd "$DEST" && bash "$PRUNE" --max-age 7d) > "$RUN3_OUT" 2>"$DEST/_run3.err"; then
  printf 'FAIL: cache-prune.sh third invocation (missing cache dir) nonzero\n' >&2
  cat "$DEST/_run3.err" >&2
  exit 1
fi
if ! grep -q '^SUMMARY: ' "$RUN3_OUT"; then
  printf 'FAIL: cache-prune.sh missing-dir invocation did not emit SUMMARY line\n' >&2
  cat "$RUN3_OUT" >&2
  exit 1
fi

printf 'PASS: m018-p03-cache-prune (--max-age 7d prunes old, keeps new, idempotent, survives missing cache dir)\n'
exit 0
