#!/usr/bin/env bash
# Verify P03 docs cross-link to each other and to existing reference docs.
set -eu

# --- recipes.md cross-links ---
f="references/recipes.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "routing.md" "$f" || { echo "FAIL: recipes.md missing cross-link to routing.md"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: recipes.md missing cross-link to file-formats.md"; exit 1; }
grep -q "architecture.md" "$f" || { echo "FAIL: recipes.md missing cross-link to architecture.md"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: recipes.md missing cross-link to engine.md"; exit 1; }

# --- routing.md cross-links ---
f="references/routing.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "recipes.md" "$f" || { echo "FAIL: routing.md missing cross-link to recipes.md"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: routing.md missing cross-link to file-formats.md"; exit 1; }
grep -q "architecture.md" "$f" || { echo "FAIL: routing.md missing cross-link to architecture.md"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: routing.md missing cross-link to engine.md"; exit 1; }

# --- Ensure links are relative (no absolute paths or http URLs for internal refs) ---
for f in references/recipes.md references/routing.md; do
  if grep -qE '\]\(/' "$f"; then
    echo "FAIL: $f contains absolute-path links (DC-3 violation)"
    exit 1
  fi
  if grep -qE '\]\(https?://.*\.(architecture|engine|recipes|routing|file-formats|events|errors|hooks)\.md\)' "$f"; then
    echo "FAIL: $f contains URL links to internal reference docs (DC-3 violation)"
    exit 1
  fi
done

echo "PASS: P03 cross-links validated (relative paths, all targets present)"
