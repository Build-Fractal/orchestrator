#!/usr/bin/env bash
# Verifies intensity-override.sh rewrites the metadata frontmatter:
# intensity becomes the new value, original_intensity records the old
# value, overridden_by=developer. Body is untouched.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
scope: "trivial"
risk_level: "low"
complexity: "simple"
confidence: "high"
reasoning: "trivial task, low risk"
overridden_by: ""
original_intensity: ""
capabilities_used:
  - "none"
evaluated_at: "2026-04-14T15:00:00Z"
---

## Intensity Metadata

Body content stays untouched by override.
EOF

body_before="$(sed -n '/^---$/,/^---$/!p' "$meta")"

bash "$f" --metadata-file "$meta" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: override Quick -> Full returned non-zero"; exit 1; }

grep -q '^intensity: "Full"' "$meta" || { echo "FAIL: intensity: not rewritten to Full"; exit 1; }
grep -q '^original_intensity: "Quick"' "$meta" || { echo "FAIL: original_intensity: not set to Quick"; exit 1; }
grep -q '^overridden_by: "developer"' "$meta" || { echo "FAIL: overridden_by: not set to developer"; exit 1; }

body_after="$(sed -n '/^---$/,/^---$/!p' "$meta")"
if [[ "$body_before" != "$body_after" ]]; then
  echo "FAIL: body content changed by override"
  exit 1
fi

echo "PASS: intensity-override.sh rewrites frontmatter correctly and leaves body unchanged"
