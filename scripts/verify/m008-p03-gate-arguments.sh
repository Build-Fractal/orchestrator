#!/usr/bin/env bash
# Verifies intensity-gate.sh accepts --stage plus either --intensity or
# --intensity-metadata, and emits execute_substeps= / skip_substeps= lines.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

grep -q '\-\-stage' "$f" || { echo "FAIL: $f missing --stage"; exit 1; }
grep -q '\-\-intensity' "$f" || { echo "FAIL: $f missing --intensity"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q 'execute_substeps=' "$f" || { echo "FAIL: $f does not emit execute_substeps="; exit 1; }
grep -q 'skip_substeps=' "$f" || { echo "FAIL: $f does not emit skip_substeps="; exit 1; }

# Direct invocation emits both lines
out="$(bash "$f" --stage verify --intensity Standard 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: direct invocation did not emit execute_substeps="; exit 1; }
echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: direct invocation did not emit skip_substeps="; exit 1; }

# Metadata-file invocation also works
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' '---' 'intensity: "Full"' '---' > "$tmp/meta.md"
out2="$(bash "$f" --stage verify --intensity-metadata "$tmp/meta.md" 2>/dev/null)"
echo "$out2" | grep -q '^execute_substeps=' || { echo "FAIL: metadata-file invocation did not emit execute_substeps="; exit 1; }

echo "PASS: intensity-gate.sh accepts documented arguments and emits key=value output"
