#!/usr/bin/env bash
set -eu
# Verify: docs/migrating-from-speckit.md exists and frames spec-kit
# as a migration source (not a runtime dependency).
DOC=docs/migrating-from-speckit.md
test -f "$DOC" || { echo "FAIL: $DOC missing"; exit 1; }
# Must mention "migration" or "migrating".
grep -qiE "migrat(ion|ing)" "$DOC" || { echo "FAIL: $DOC does not mention migration"; exit 1; }
# Must reference either commands/migrate.md or scripts/migrate/migrate-state.sh.
if ! grep -qE "commands/migrate\.md|scripts/migrate/migrate-state\.sh|orchestrator:migrate|orchestrator-migrate" "$DOC"; then
  echo "FAIL: $DOC does not reference the migrate command or migrate script"
  exit 1
fi
# Must NOT frame spec-kit as a runtime dependency — the phrase
# "requires spec-kit" or "depends on spec-kit" at runtime level is
# disallowed. Spec-kit appears only as a migration SOURCE.
if grep -qE "requires spec-kit|depends on spec-kit at runtime|spec-kit >= 0\.1\.0.*required" "$DOC"; then
  echo "FAIL: $DOC still frames spec-kit as a runtime dependency"
  exit 1
fi
# Minimum length sanity — not a stub.
lines=$(wc -l < "$DOC")
if [ "$lines" -lt 40 ]; then
  echo "FAIL: $DOC too short ($lines lines, need >= 40)"
  exit 1
fi
echo "PASS: migration guide exists and frames spec-kit as migration source"
