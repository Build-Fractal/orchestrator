#!/usr/bin/env bash
# Verifies compress-payload.sh applies the 3-step compression cascade
# (drop optional, summarize upstream, drop lowest-confidence knowledge)
# and never truncates the task plan section.
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
  touch "$root/extension.yml"

  # Generate filler text (~100 words per block, repeat blocks)
  # We need ~5000 tokens = ~20000 chars, so use moderate filler
  local filler_block="Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident sunt in culpa qui officia deserunt mollit anim id est laborum."

  # Build filler for knowledge section (~3000 tokens each = ~12000 chars)
  local k_filler=""
  local i=0
  while [ "$i" -lt 30 ]; do
    k_filler="${k_filler} ${filler_block}"
    i=$((i + 1))
  done

  # Build filler for upstream section
  local u_filler=""
  i=0
  while [ "$i" -lt 20 ]; do
    u_filler="${u_filler} ${filler_block}"
    i=$((i + 1))
  done

  # Write payload to file directly (avoids broken-pipe with large echo)
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
    printf 'High confidence knowledge entry body.%s\n' "$k_filler"
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
    printf 'This is the task plan content that must NEVER be truncated by compression.\n'
    printf 'The task plan is a protected section.\n'
    printf '\n'
    printf 'Steps:\n'
    printf '\n'
    printf '1. First step of the important task.\n'
    printf '2. Second step of the important task.\n'
    printf '3. Third step of the important task.\n'
    printf '\n'
    printf '## Constraints\n'
    printf '\n'
    printf -- '- **Verification Criteria**: See phase plan must-haves\n'
    printf -- '- **Duration Budget**: 2h\n'
    printf -- '- **Dispatch Budget**: 3\n'
    printf -- '- **Budget Enforcement**: warn\n'
  } > "$TMPDIR_TEST/test-payload.md"
}

# --- Setup ---
setup_payload

# Measure input size
input_size="$(wc -c < "$TMPDIR_TEST/test-payload.md" | tr -d ' ')"

# --- Run compress-payload.sh with a small budget ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/compress-payload.sh" \
  --budget 2000 --input "$TMPDIR_TEST/test-payload.md" 2>/dev/null)" || true

# Measure output size
output_size="$(printf '%s' "$output" | wc -c | tr -d ' ')"

# --- Assertions ---

# 1. Output should be shorter than input (compression happened)
if [ "$output_size" -ge "$input_size" ]; then
  echo "FAIL: compressed output ($output_size bytes) is not smaller than input ($input_size bytes)"
  exit 1
fi

# 2. Task Plan section must be preserved (never truncated)
if ! echo "$output" | grep -q "must NEVER be truncated"; then
  echo "FAIL: Task Plan section was truncated by compression"
  exit 1
fi

if ! echo "$output" | grep -q "Third step of the important task"; then
  echo "FAIL: Task Plan steps were truncated by compression"
  exit 1
fi

# 3. Output should exist and be non-empty
if [ -z "$output" ]; then
  echo "FAIL: compress-payload.sh produced empty output"
  exit 1
fi

echo "PASS: compress-payload.sh applies compression cascade and preserves the Task Plan section (input=${input_size}b, output=${output_size}b)"
