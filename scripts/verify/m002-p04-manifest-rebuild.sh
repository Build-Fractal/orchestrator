#!/usr/bin/env bash
# Verifies compress-payload.sh rebuilds the manifest header after compression
# to reflect updated line ranges and token estimates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Build a test payload that exceeds a small budget ---
setup_payload() {
  local root="$TMPDIR_TEST"

  # Copy scripts so compress-payload.sh can find its libs
  mkdir -p "$root/scripts/dispatch/lib"
  mkdir -p "$root/scripts/knowledge/lib"
  mkdir -p "$root/scripts/lib"
  mkdir -p "$root/scripts/state"
  mkdir -p "$root/scripts/telemetry"
  mkdir -p "$root/templates"

  cp -R "$PROJECT_ROOT/scripts/dispatch/"* "$root/scripts/dispatch/"
  cp -R "$PROJECT_ROOT/scripts/knowledge/"* "$root/scripts/knowledge/"
  cp -R "$PROJECT_ROOT/scripts/lib/"* "$root/scripts/lib/"
  cp -R "$PROJECT_ROOT/scripts/state/"* "$root/scripts/state/"
  cp -R "$PROJECT_ROOT/scripts/telemetry/"* "$root/scripts/telemetry/"
  cp "$PROJECT_ROOT/templates/context-recipe.yaml" "$root/templates/" 2>/dev/null || true
  mkdir -p "$root/.orchestrator"

  # Generate filler text
  local filler_block="Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."

  local k_filler=""
  local i=0
  while [ "$i" -lt 30 ]; do
    k_filler="${k_filler} ${filler_block}"
    i=$((i + 1))
  done

  local u_filler=""
  i=0
  while [ "$i" -lt 20 ]; do
    u_filler="${u_filler} ${filler_block}"
    i=$((i + 1))
  done

  # Write payload to file directly (avoids broken-pipe with large echo|awk)
  {
    printf '%s\n' '---'
    printf 'schema_version: "1.0"\n'
    printf 'type: dispatch-prompt\n'
    printf '%s\n' '---'
    printf '\n'
    printf '# Dispatch Context -- T01 (Phase P01, Milestone M001)\n'
    printf '## Manifest\n'
    printf '| Section | Lines | Est. Tokens | Priority |\n'
    printf '|---------|-------|-------------|----------|\n'
    printf '| Knowledge | 19-100 | ~5000 | filtered |\n'
    printf '| Upstream Context | 101-200 | ~4000 | required |\n'
    printf '| Task Plan | 201-230 | ~200 | required |\n'
    printf '| Constraints | 231-240 | ~100 | optional |\n'
    printf '| **Total** | | **~9300** | |\n'
    printf '\n'
    printf '## Knowledge\n'
    printf '\n'
    printf 'Knowledge entry body text.%s\n' "$k_filler"
    printf '\n'
    printf '## Upstream Context\n'
    printf '\n'
    printf '### P01 Summary\n'
    printf '%s\n' "$u_filler"
    printf '\n'
    printf '### P02 Summary\n'
    printf '%s\n' "$u_filler"
    printf '\n'
    printf '## Task Plan\n'
    printf '\n'
    printf 'This is the task plan content.\n'
    printf '\n'
    printf '## Constraints\n'
    printf '\n'
    printf -- '- Verification: See phase plan must-haves\n'
    printf -- '- Duration Budget: 2h\n'
  } > "$TMPDIR_TEST/test-payload.md"
}

# --- Setup ---
setup_payload

# Capture original manifest total tokens
original_total="$(grep '\*\*Total\*\*' "$TMPDIR_TEST/test-payload.md" | grep -oE '[0-9]+' | head -1)"

# --- Run compress-payload.sh with a small budget ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/compress-payload.sh" \
  --budget 2000 --input "$TMPDIR_TEST/test-payload.md" 2>/dev/null)" || true

# --- Assertions ---

# 1. Output should still contain ## Manifest
if ! echo "$output" | grep -q "^## Manifest"; then
  echo "FAIL: compressed output missing ## Manifest heading"
  exit 1
fi

# 2. Output should still contain the column headers
if ! echo "$output" | grep -q "| Section | Lines | Est. Tokens | Priority |"; then
  echo "FAIL: compressed output missing manifest column headers"
  exit 1
fi

# 3. Output should contain a Total row
if ! echo "$output" | grep -q '\*\*Total\*\*'; then
  echo "FAIL: compressed output missing manifest Total row"
  exit 1
fi

# 4. The Total token count should be smaller than the original
new_total="$(echo "$output" | grep '\*\*Total\*\*' | grep -oE '[0-9]+' | head -1)"
if [ -z "$new_total" ]; then
  echo "FAIL: could not extract new Total tokens from compressed manifest"
  exit 1
fi

if [ -n "$original_total" ] && [ "$new_total" -ge "$original_total" ]; then
  echo "FAIL: compressed manifest Total ($new_total) is not smaller than original ($original_total)"
  exit 1
fi

# 5. Line ranges should contain valid numbers (N-N format)
data_rows="$(echo "$output" | grep -E '^\| .+ \| [0-9]+-[0-9]+ \|')"
if [ -z "$data_rows" ]; then
  echo "FAIL: compressed manifest has no data rows with line ranges"
  exit 1
fi

echo "PASS: compress-payload.sh rebuilds manifest after compression with updated line ranges and token estimates (${original_total} -> ${new_total})"
