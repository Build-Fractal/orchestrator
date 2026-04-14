#!/usr/bin/env bash
# Verifies intensity-override.sh does not modify any file other than
# the metadata file it was given. Uses a sandbox directory with several
# sentinel files and checks their mtimes after the override runs.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
---
EOF

# Sentinel files that represent completed stage outputs.
sentinel_a="$tmp/P01-SUMMARY.md"
sentinel_b="$tmp/T01-SUMMARY.md"
sentinel_c="$tmp/KNOWLEDGE.md"
echo "phase summary" > "$sentinel_a"
echo "task summary" > "$sentinel_b"
echo "knowledge" > "$sentinel_c"

hash_before_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_before_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_before_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

bash "$f" --metadata-file "$meta" --new-intensity Standard >/dev/null 2>&1 \
  || { echo "FAIL: override returned non-zero"; exit 1; }

hash_after_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_after_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_after_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

if [[ "$hash_before_a" != "$hash_after_a" ]]; then echo "FAIL: override modified P01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_b" != "$hash_after_b" ]]; then echo "FAIL: override modified T01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_c" != "$hash_after_c" ]]; then echo "FAIL: override modified KNOWLEDGE.md"; exit 1; fi

# Metadata file ITSELF must have been rewritten
grep -q '^intensity: "Standard"' "$meta" || { echo "FAIL: metadata file not rewritten"; exit 1; }

echo "PASS: intensity-override.sh modifies only the metadata file"
