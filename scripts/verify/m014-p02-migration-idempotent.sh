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
