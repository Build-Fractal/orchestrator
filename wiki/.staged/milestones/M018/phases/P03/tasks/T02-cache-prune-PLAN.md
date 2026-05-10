---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M018"
name: "scripts/util/cache-prune.sh utility (--max-age <duration>) for tool-result cache eviction"
depends_on: []
---

## Prerequisites

- Spec FR-16 (`cache-prune`): `scripts/util/cache-prune.sh --max-age <duration>` prunes cache entries older than the named age. Spec acceptance scenario 5 (US-3): `bash scripts/util/cache-prune.sh --max-age 30d` removes entries older than 30 days; entries referenced by any open milestone's `execution-log.jsonl` in the last 30 days are preserved.
  - **Scope simplification for M018/P03**: per the roadmap phase scope ("`cache-prune.sh --max-age 7d` evicts entries past retention"), T02 ships the **mtime-based prune surface only**. Reference-aware preservation (the second clause of acceptance scenario 5 — preserving entries that are still referenced in execution-log.jsonl) is a follow-up; T02 does NOT implement it. The current cache-key collision surface is so small (full SHA-256 + dispatch-time-only writes) that mtime-only prune is correct for M018.
- Cache root path: `compression.tier1.cache_dir` from `.orchestrator/config.yml` (default `.orchestrator/cache/tool-results/`). T02 reads this config key so prune respects operator overrides.
- AP-009 (Bash shape guard): no compound chains > 2; no plain subshells; no `$(...|...)`. Bash 3.2.
- T02 has no upstream task dependency inside P03. It can run in parallel with T01.

## Description

Land a small, single-script-file utility under `scripts/util/` that prunes the Tier 1 tool-result cache by file mtime. The utility:

1. Accepts `--max-age <duration>` where `<duration>` is one of `<N>d` (days), `<N>h` (hours), or `<N>m` (minutes). The default if `--max-age` is absent is `7d` (matches the roadmap demo sentence).
2. Resolves the cache root from `.orchestrator/config.yml` `compression.tier1.cache_dir` (default `.orchestrator/cache/tool-results/`). Resolves the path relative to the project root if not absolute.
3. If the cache root does not exist, exits 0 with a one-line stdout message — pruning a missing cache is a successful no-op.
4. Walks the cache root one level deep, removes regular files whose mtime is older than `now - max_age`, and prints one `PRUNED: <path>` line per removal. Sub-directories (none expected in M018, but possible in future) are NOT recursed into — explicit shape decision so a future tier-3-originals/ co-tenant under the same cache root cannot be accidentally clobbered.
5. Final summary line on stdout: `SUMMARY: pruned=<N> kept=<M> total=<T>`.
6. Accepts a `--dry-run` flag that prints what WOULD be pruned without actually removing files. Useful for operator inspection; spec doesn't strictly require this but it's table stakes for a destructive utility.
7. Exits 0 on success even when zero files were pruned. Exits 1 only on argument parsing failure (unrecognized flag, malformed `--max-age` value).

## Steps

### Step 1 — Author `scripts/util/cache-prune.sh`

Write the file with `Write`. Make it executable (`chmod +x` is enforced by tooling on commit; T02's authoring agent should run `chmod +x scripts/util/cache-prune.sh` after Write so the verifier finds it executable).

```bash
#!/usr/bin/env bash
# M018/P03/T02: cache-prune.sh — Tier 1 tool-result cache eviction by mtime.
#
# Usage:
#   bash scripts/util/cache-prune.sh --max-age 7d
#   bash scripts/util/cache-prune.sh --max-age 24h --dry-run
#
# Reads compression.tier1.cache_dir from .orchestrator/config.yml; falls
# back to .orchestrator/cache/tool-results/ relative to the project root.
# Removes regular files older than the configured age; never recurses
# into sub-directories (so future tier-3-originals/ co-tenants are
# untouched). Idempotent — running twice in succession is a no-op on
# the second call.
#
# Bash 3.2 + AP-009 compliant: no compound chains > 2, no plain
# subshells, no $(... | ...).

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

# Parse <N>d / <N>h / <N>m into seconds.
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

# Resolve project root and config path. Walks up from $0 until it finds
# .orchestrator/config.yml or hits filesystem root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
while [ "$PROJECT_ROOT" != "/" ]; do
  if [ -f "$PROJECT_ROOT/.orchestrator/config.yml" ]; then
    break
  fi
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

CACHE_DIR=""
if [ -f "$PROJECT_ROOT/.orchestrator/config.yml" ]; then
  # Read compression.tier1.cache_dir via awk single-pass.
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

case "$CACHE_DIR" in
  /*) : ;;
  *)  CACHE_DIR="$PROJECT_ROOT/$CACHE_DIR" ;;
esac

if [ ! -d "$CACHE_DIR" ]; then
  printf 'SUMMARY: pruned=0 kept=0 total=0 (cache dir absent: %s)\n' "$CACHE_DIR"
  exit 0
fi

NOW="$(date -u +%s)"
CUTOFF=$(( NOW - MAX_AGE_SECONDS ))

PRUNED=0
KEPT=0
TOTAL=0

# Single-level walk. find with -maxdepth 1 -type f keeps us out of any
# future subdirectories. Use -newer-style mtime comparison via stat
# rather than find -mtime so we get explicit second-resolution control.
for f in "$CACHE_DIR"/*; do
  [ -f "$f" ] || continue
  TOTAL=$(( TOTAL + 1 ))
  # macOS stat -f %m; Linux stat -c %Y. Probe once.
  if stat -f %m "$f" >/dev/null 2>&1; then
    mtime="$(stat -f %m "$f")"
  else
    mtime="$(stat -c %Y "$f")"
  fi
  if [ "$mtime" -lt "$CUTOFF" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      printf 'WOULD-PRUNE: %s (mtime=%s)\n' "$f" "$mtime"
    else
      rm -f "$f"
      printf 'PRUNED: %s\n' "$f"
    fi
    PRUNED=$(( PRUNED + 1 ))
  else
    KEPT=$(( KEPT + 1 ))
  fi
done

printf 'SUMMARY: pruned=%d kept=%d total=%d\n' "$PRUNED" "$KEPT" "$TOTAL"
exit 0
```

Notes:
- `stat` is invoked twice on cache hits. Acceptable: cache directories are small (one file per unique tool-call-hash; expected dozens to low hundreds). If profiling later flags this as hot, a single `find -printf` (Linux) / `find -exec stat` (macOS) pass replaces the loop.
- Bash 3.2: no `mapfile`, no `readarray`. The `for f in "$CACHE_DIR"/*` glob is fine because the cache directory has no spaces in filenames (SHA-256 hex digests only).
- `set -eu`: aborts on undefined variables and on unhandled command failures. We deliberately do NOT enable `pipefail` because we never use pipes in this script.

### Step 2 — Run a quick self-test

Stage two fake cache files under a tmp directory:

```
mkdir -p /tmp/cache-prune-selftest/.orchestrator/cache/tool-results
printf 'old\n' > /tmp/cache-prune-selftest/.orchestrator/cache/tool-results/oldfile
printf 'new\n' > /tmp/cache-prune-selftest/.orchestrator/cache/tool-results/newfile
touch -t 202001010000 /tmp/cache-prune-selftest/.orchestrator/cache/tool-results/oldfile
# (touch -t backdates oldfile to 2020-01-01.)
cd /tmp/cache-prune-selftest
bash <project-root>/scripts/util/cache-prune.sh --max-age 7d
```

Expected stdout:

```
PRUNED: /tmp/cache-prune-selftest/.orchestrator/cache/tool-results/oldfile
SUMMARY: pruned=1 kept=1 total=2
```

Run again — second call summary: `SUMMARY: pruned=0 kept=1 total=1` (idempotent on a stable cache).

### Step 3 — Permissions

```
chmod +x scripts/util/cache-prune.sh
```

## Must-Haves

- `scripts/util/cache-prune.sh` exists, is executable, has a `--max-age <duration>` flag, and prunes mtime-aged files from the configured cache directory (T03 verifier `m018-p03-cache-prune.sh`).
- Idempotent: running twice in succession does not error and the second call's pruned count is 0 (covered by T03 verifier).

## Verification

- `bash scripts/verify/m018-p03-cache-prune.sh` — PASS (T03 ships this verifier; it stages a fake cache, runs prune, asserts old files are gone and new ones remain, and re-runs to assert idempotency).
- `bash -n scripts/util/cache-prune.sh` — syntactically valid.

## Inputs

### From Previous Tasks

(None — T02 has no upstream P03 dependency.)

### From Disk (Pre-existing)

- `.orchestrator/config.yml` `compression.tier1.cache_dir` — set by T01. T02 reads it; if T02 runs ahead of T01, the awk fallback returns empty and T02 uses its hardcoded default `.orchestrator/cache/tool-results/`. Either order works.
- `scripts/hooks/pre-bash-shape-guard.sh` — must not flag any line in T02's script. The `case` blocks, the `for f in glob` loop, and the integer arithmetic are all AP-009-clean.

## Constraints

- **Single-script-file shape (AD-19)**: T02 is one self-contained script. No sourced helpers, no spawned utility scripts.
- **No find with `-exec`-piped-to-shell**: AP-009 banned shapes are absent. The `for f in "$CACHE_DIR"/*` loop iterates the glob in pure bash.
- **Idempotency**: re-running on a steady-state cache is a no-op (zero rm calls, zero stderr noise).
- **Constitution Principle VI**: T02 deletes only files under the configured cache root. Never touches knowledge files, never touches spec/plan/roadmap files. The `find -maxdepth 1 -type f` invariant (here implemented via the single-level glob) prevents accidental recursion into a sibling sub-directory.

## Expected Output

- `scripts/util/cache-prune.sh` exists, is executable, ≥ 60 lines, contains the literal string `--max-age`.
- A self-test against a tmp directory produces `PRUNED:` + `SUMMARY:` lines and removes the backdated test file.
