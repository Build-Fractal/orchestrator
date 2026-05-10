---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M014"
name: "One-time migration of repo-root ## Recent Changes into marker region + P01 dogfood cleanup"
depends_on: []
---

## Prerequisites

- P01's T05 live-repo run left a dogfood marker region at the top of `CLAUDE.md` with stale content:
  ```
  # >>> orchestrator:recent-changes >>>
  - 021-test-exporter: foo
  # <<< orchestrator:recent-changes <<<
  ```
- The same T05 run created `AGENTS.md` at repo root with a matching stale entry.
- The pre-existing `## Recent Changes` section at the bottom of `CLAUDE.md` contains six entries (lines 73-80 pre-migration) that were never migrated into the marker region.
- `scripts/util/dual-write-runtime-md.sh` is available for the final write step.

## Description

One-time migration: move the pre-existing `## Recent Changes` entries from the bottom of `CLAUDE.md` into the marker-bounded region at the top, drop the stale `- 021-test-exporter: foo` dogfood entry, regenerate `AGENTS.md` to byte-match `CLAUDE.md`'s marker region. The migration is idempotent — re-running on an already-migrated tree is a no-op with `SUMMARY: already-migrated` on stdout.

After the migration:
- `CLAUDE.md`'s marker region contains the six preserved Recent Changes entries
- `CLAUDE.md`'s `## Recent Changes` section below the frontmatter is removed (content moved to marker region)
- Bytes outside the marker region (and the old `## Recent Changes` section) are byte-preserved
- `AGENTS.md` marker-region bytes are byte-identical to `CLAUDE.md`'s marker region

The migration script ships with `--dry-run` emitting FR-19 JSONL manifest records and `--apply` performing the actual rewrite.

## Steps

### Step 1: Create `scripts/migrate/m014-p02-migrate-recent-changes.sh`

First, ensure the directory exists: `mkdir -p scripts/migrate` (directory did not previously exist).

Verbatim body:

```bash
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
  printf '{"command":"m014-p02-migrate-recent-changes","action_type":"dual-write-region","target_path":"%s","source_ref":"recent-changes","description":"regenerate region byte-identically in both files"}\n' "$PROJECT_ROOT/{CLAUDE.md,AGENTS.md}"
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
```

Make executable: `chmod +x scripts/migrate/m014-p02-migrate-recent-changes.sh`.

### Step 2: Run the migration once against the live repo

Execute in apply mode:

```bash
bash scripts/migrate/m014-p02-migrate-recent-changes.sh --apply
```

Expected output: `SUMMARY: applied legacy_entries=6 stale_dogfood_removed=1`.

Post-conditions on disk:
- `CLAUDE.md` marker region now contains six entries (the preserved legacy entries).
- `CLAUDE.md` no longer has a standalone `## Recent Changes` section at the bottom.
- `AGENTS.md` exists at repo root with marker-region bytes byte-identical to `CLAUDE.md`'s.

### Step 3: Create `scripts/verify/m014-p02-migration-idempotent.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify migration script is idempotent + dry-run emits FR-19 manifest.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MIGRATE="${PROJECT_ROOT}/scripts/migrate/m014-p02-migrate-recent-changes.sh"

if [ ! -x "$MIGRATE" ]; then
  echo "FAIL: migration script missing or not executable" >&2
  exit 1
fi

# Shape checks.
grep -q -- '--dry-run' "$MIGRATE" || { echo "FAIL: --dry-run flag missing" >&2; exit 1; }
grep -q -- '--apply' "$MIGRATE"   || { echo "FAIL: --apply flag missing" >&2; exit 1; }
grep -q 'already-migrated' "$MIGRATE" || { echo "FAIL: already-migrated sentinel missing" >&2; exit 1; }
grep -q 'recent-changes' "$MIGRATE"   || { echo "FAIL: recent-changes region not referenced" >&2; exit 1; }

# Idempotency test on live repo: running the migration now (post-Step 2) should
# print "SUMMARY: already-migrated".
OUT="$(bash "$MIGRATE" 2>&1)"
if ! echo "$OUT" | grep -q 'SUMMARY: already-migrated'; then
  echo "FAIL: migration not idempotent on already-migrated tree" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Re-running twice in a row is still idempotent.
bash "$MIGRATE" >/dev/null 2>&1
OUT2="$(bash "$MIGRATE" 2>&1)"
if ! echo "$OUT2" | grep -q 'SUMMARY: already-migrated'; then
  echo "FAIL: second idempotency invocation did not report already-migrated" >&2
  exit 1
fi

# Verify stale dogfood entry is gone from CLAUDE.md.
if grep -qF '021-test-exporter: foo' "$PROJECT_ROOT/CLAUDE.md"; then
  echo "FAIL: stale 021-test-exporter dogfood entry still in CLAUDE.md" >&2
  exit 1
fi

# Verify AGENTS.md region matches CLAUDE.md region byte-for-byte.
extract_region() {
  awk '/^# >>> orchestrator:recent-changes >>>/ { in_r=1; next } /^# <<< orchestrator:recent-changes <<</ { in_r=0; next } in_r==1 { print }' "$1"
}

if [ ! -f "$PROJECT_ROOT/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md missing post-migration" >&2
  exit 1
fi

C_SHA="$(extract_region "$PROJECT_ROOT/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
A_SHA="$(extract_region "$PROJECT_ROOT/AGENTS.md" | shasum -a 256 | awk '{print $1}')"
if [ "$C_SHA" != "$A_SHA" ]; then
  echo "FAIL: recent-changes region bytes differ between CLAUDE.md and AGENTS.md" >&2
  echo "  CLAUDE=$C_SHA  AGENTS=$A_SHA" >&2
  exit 1
fi

# Dry-run invocation with --force emits FR-19 manifest records.
# (--force bypasses already-migrated short-circuit so we can exercise dry-run output.)
OUT="$(bash "$MIGRATE" --dry-run --force 2>/dev/null)"
if ! echo "$OUT" | grep -qE '^\{.*"action_type":"dual-write-region"'; then
  echo "FAIL: --dry-run did not emit FR-19 manifest record" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

echo "PASS: migration idempotent + dry-run emits FR-19 manifest + region byte-identical"
exit 0
```

Make executable.

## Must-Haves

- `scripts/migrate/m014-p02-migrate-recent-changes.sh` exists, is executable, supports `--dry-run` (default) / `--apply` / `--force`
- Dry-run emits FR-19 JSONL manifest records to stdout and makes zero disk writes
- Apply mode: moves legacy `## Recent Changes` entries into marker region, drops stale `- 021-test-exporter: foo` dogfood entry, regenerates `AGENTS.md` byte-identical to `CLAUDE.md`'s marker region
- Idempotent: re-running the script (after Step 2 apply) prints `SUMMARY: already-migrated` and exits 0 with zero writes
- Post-migration repo state: CLAUDE.md's marker region contains the six preserved legacy entries; stale dogfood entry removed; AGENTS.md byte-identical region; outside-markers bytes preserved
- Passes `scripts/verify/anti-pattern-lint.sh`
- Gate verifier exits 0

## Verification

```
bash scripts/verify/m014-p02-migration-idempotent.sh
```

Expected: `PASS: migration idempotent + dry-run emits FR-19 manifest + region byte-identical`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/migrate/m014-p02-migrate-recent-changes.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

None — T05 operates on pre-existing repo state and the P01 dogfood artifacts. T05 is parallel with T01/T02/T03/T04.

### From Disk (Pre-existing)

- `CLAUDE.md` — with P01 dogfood marker region containing `- 021-test-exporter: foo` at top; pre-existing `## Recent Changes` section near the bottom (lines ~73-80).
- `AGENTS.md` — stale dogfood file at repo root from P01/T05 live run.
- `scripts/util/dual-write-runtime-md.sh` — P01 helper used for the final dual-write step.
- `scripts/verify/anti-pattern-lint.sh` — lint surface.

## Constraints

- Bash 3.2 compatible. Uses `awk`, `grep`, `mv`, `rm`, `mktemp`, plain `if` — no process substitution, no compound inline for/if, no `${var,,}`.
- The migration must preserve bytes outside both (a) the target marker region and (b) the legacy `## Recent Changes` section byte-for-byte. Only the marker region and the legacy section are rewritten; all other content (frontmatter, ## What This Is, ## Project Status, ## Forward Roadmap, etc.) is untouched.
- Idempotent: subsequent invocations must be no-ops with `SUMMARY: already-migrated`.
- The `--force` flag bypasses the already-migrated short-circuit (for testing dry-run output against already-migrated trees, and for potential re-runs if the region needs repair).
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files created:

1. `scripts/migrate/` — new directory (parent of migration script)
2. `scripts/migrate/m014-p02-migrate-recent-changes.sh` — migration script (~130 lines, executable)
3. `scripts/verify/m014-p02-migration-idempotent.sh` — gate verifier (~75 lines, executable)

Files modified (one-time migration):

4. `CLAUDE.md` — marker region rewritten with six preserved legacy entries; legacy `## Recent Changes` section removed; stale dogfood entry dropped
5. `AGENTS.md` — regenerated byte-identical to CLAUDE.md's marker region (outside markers: just the region itself — AGENTS.md has no runtime-identification header per P01 D014)

All scripts pass anti-pattern-lint; gate verifier exits 0.
