#!/usr/bin/env bash
# Verifies intensity-override.sh rejects invalid intensities and no-op
# (same-level) overrides with non-zero exit.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Standard"
---
EOF

# Invalid intensity
err="$(bash "$f" --metadata-file "$meta" --new-intensity Medium 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: invalid intensity did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'invalid intensity' || { echo "FAIL: invalid intensity diagnostic missing"; exit 1; }

# No-op (same level)
err2="$(bash "$f" --metadata-file "$meta" --new-intensity Standard 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: same-level override did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'no-op' || { echo "FAIL: same-level override diagnostic missing"; exit 1; }

# Missing file
err3="$(bash "$f" --metadata-file "$tmp/does-not-exist" --new-intensity Full 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing file did not exit non-zero"; exit 1; fi

echo "PASS: intensity-override.sh rejects invalid intensities, no-ops, and missing files"
