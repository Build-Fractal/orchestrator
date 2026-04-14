#!/usr/bin/env bash
# Verify P04 docs cross-link to reference docs and to each other.
set -eu

# --- getting-started.md cross-links ---
f="docs/getting-started.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "installation.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to installation.md"; exit 1; }
grep -q "architecture.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to architecture.md"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to engine.md"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to events.md"; exit 1; }
grep -q "state-machine.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to state-machine.md"; exit 1; }
grep -q "recipe-authoring.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to recipe-authoring.md"; exit 1; }
grep -q "hook-development.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to hook-development.md"; exit 1; }
grep -q "knowledge-management.md" "$f" || { echo "FAIL: getting-started.md missing cross-link to knowledge-management.md"; exit 1; }

# --- recipe-authoring.md cross-links ---
f="docs/recipe-authoring.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "recipes.md" "$f" || { echo "FAIL: recipe-authoring.md missing cross-link to recipes.md"; exit 1; }
grep -q "routing.md" "$f" || { echo "FAIL: recipe-authoring.md missing cross-link to routing.md"; exit 1; }

# --- hook-development.md cross-links ---
f="docs/hook-development.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "hooks.md" "$f" || { echo "FAIL: hook-development.md missing cross-link to hooks.md"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: hook-development.md missing cross-link to events.md"; exit 1; }

# --- knowledge-management.md cross-links ---
f="docs/knowledge-management.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: knowledge-management.md missing cross-link to file-formats.md"; exit 1; }
grep -q "architecture.md" "$f" || { echo "FAIL: knowledge-management.md missing cross-link to architecture.md"; exit 1; }

# --- Ensure links are relative (no absolute paths or http URLs for internal refs) ---
for f in docs/getting-started.md docs/recipe-authoring.md docs/hook-development.md docs/knowledge-management.md; do
  if grep -qE '\]\(/' "$f"; then
    echo "FAIL: $f contains absolute-path links (DC-3 violation)"
    exit 1
  fi
  if grep -qE '\]\(https?://.*\.(architecture|engine|recipes|routing|file-formats|events|errors|hooks|installation|state-machine)\.md\)' "$f"; then
    echo "FAIL: $f contains URL links to internal reference docs (DC-3 violation)"
    exit 1
  fi
done

echo "PASS: P04 cross-links validated (relative paths, all targets present)"
