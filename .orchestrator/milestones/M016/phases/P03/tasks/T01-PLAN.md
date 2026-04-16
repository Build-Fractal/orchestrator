---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M016"
name: "Create anti-pattern-lint.sh linter"
depends_on: []
---

## Prerequisites

P01 delivered `ANTIPATTERNS.md` with AP-004 documenting the three Class A pattern classes (command substitution, brace expansion, compound bash chains). The linter must detect patterns consistent with that catalog.

## Description

Create `scripts/verify/anti-pattern-lint.sh` — a static linter that scans agent-facing markdown files (`commands/*.md`, `templates/*.md`) for Class A anti-patterns that trigger Claude Code safety prompts. The linter must:

1. Detect `$(...)` command substitution in code blocks (not in prose describing forbidden patterns)
2. Detect backtick command substitution in code blocks
3. Detect `{a,b}` brace expansion in code blocks
4. Self-exclude its own source file from scans
5. Exclude `ANTIPATTERNS.md` from scans (it catalogs patterns by definition)
6. Print file:line diagnostics with remediation hints
7. Exit non-zero if any violations found, exit 0 if clean

The linter scans only agent-facing content per AD-4 (context decision). Script internals (`scripts/*.sh`) are exempt.

## Steps

### Step 1: Create the linter script

Create `scripts/verify/anti-pattern-lint.sh` with the following architecture:

```bash
#!/usr/bin/env bash
# scripts/verify/anti-pattern-lint.sh — Detect Class A anti-patterns in agent-facing content
# Scans commands/*.md and templates/*.md for patterns that trigger Claude Code
# safety prompts: $(…), backticks, {a,b} brace expansion.
#
# Usage: anti-pattern-lint.sh [--fixture <file>]
#   Default: scans commands/*.md and templates/*.md
#   --fixture <file>: scan only the specified file (for testing)
#
# Self-excludes its own source. Excludes ANTIPATTERNS.md.
# See AP-004 in ANTIPATTERNS.md for the canonical pattern catalog.
#
# Exit: 0 if clean, 1 if violations found.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse args
FIXTURE_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture) FIXTURE_FILE="$2"; shift 2 ;;
    *) echo "anti-pattern-lint.sh: unknown option $1" >&2; exit 1 ;;
  esac
done

# Build file list
files=""
if [ -n "$FIXTURE_FILE" ]; then
  files="$FIXTURE_FILE"
else
  # Discover agent-facing markdown files
  _tmp_files="$(mktemp)"
  find "$PROJECT_ROOT/commands" -name '*.md' -type f 2>/dev/null > "$_tmp_files"
  find "$PROJECT_ROOT/templates" -name '*.md' -type f 2>/dev/null >> "$_tmp_files"
  files="$(cat "$_tmp_files")"
  rm -f "$_tmp_files"
fi

violation_count=0
violation_output=""

# Self-exclusion: skip this script's own path and ANTIPATTERNS.md
SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ANTIPATTERNS_PATH="$PROJECT_ROOT/ANTIPATTERNS.md"

# Process each file
_file_list="$(mktemp)"
printf '%s\n' "$files" > "$_file_list"
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  # Self-exclusion
  real_file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  if [ "$real_file" = "$SELF_PATH" ]; then
    continue
  fi
  if [ "$real_file" = "$ANTIPATTERNS_PATH" ]; then
    continue
  fi

  # Extract code blocks and scan for anti-patterns
  # We scan inside ```bash ... ``` and ```  ... ``` code blocks only,
  # plus standalone lines that look like bash invocations.
  # We must NOT flag patterns that appear in comment lines describing
  # forbidden patterns (lines starting with # FORBIDDEN or containing
  # "Forbidden" as documentation).
  #
  # Strategy: scan all lines in code blocks for the three pattern classes.
  # A code block starts with ``` and ends with ```.
  in_code_block=0
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track code blocks
    case "$line" in
      '```'*) 
        if [ "$in_code_block" -eq 0 ]; then
          in_code_block=1
          continue
        else
          in_code_block=0
          continue
        fi
        ;;
    esac

    [ "$in_code_block" -eq 0 ] && continue

    # Skip lines that are documenting forbidden patterns (comments)
    case "$line" in
      *'# FORBIDDEN'*) continue ;;
      *'# lint-ignore'*) continue ;;
    esac

    # Check for command substitution $(...) 
    # Use grep with a pattern that matches literal $( 
    if printf '%s' "$line" | grep -qE '\$\(' 2>/dev/null; then
      violation_count=$((violation_count + 1))
      short_file="${file#$PROJECT_ROOT/}"
      violation_output="${violation_output}${short_file}:${line_num}: command substitution \$(...)
  Hint: Use --output-file or omit the dynamic value. See AP-004 in ANTIPATTERNS.md.
"
    fi

    # Check for backtick command substitution
    # Match backticks that contain content (not empty backticks used for inline code in markdown)
    # Only flag backticks at the start of or within a bash command context
    if printf '%s' "$line" | grep -qE '`[^`]+`' 2>/dev/null; then
      # Filter: only flag if the backtick content looks like a command (contains spaces or $)
      backtick_content="$(printf '%s' "$line" | grep -oE '`[^`]+`' | head -1)"
      # Skip single-word backtick references (these are inline code, not command substitution)
      inner="$(printf '%s' "$backtick_content" | sed 's/^`//; s/`$//')"
      if printf '%s' "$inner" | grep -qE ' ' 2>/dev/null; then
        # Multi-word backtick content inside a code block — potential command substitution
        # Only flag if it looks like backtick command substitution (= or flag context)
        if printf '%s' "$line" | grep -qE '=`[^`]+`' 2>/dev/null; then
          violation_count=$((violation_count + 1))
          short_file="${file#$PROJECT_ROOT/}"
          violation_output="${violation_output}${short_file}:${line_num}: backtick command substitution
  Hint: Use a wrapper script or --output-file pattern. See AP-004 in ANTIPATTERNS.md.
"
        fi
      fi
    fi

    # Check for brace expansion {a,b} 
    # Match {word,word} patterns but not ${var} parameter expansion
    # and not {print $1} awk patterns (those are also flagged but in a different way)
    if printf '%s' "$line" | grep -qE '\{[a-zA-Z0-9_]+,[a-zA-Z0-9_]+' 2>/dev/null; then
      violation_count=$((violation_count + 1))
      short_file="${file#$PROJECT_ROOT/}"
      violation_output="${violation_output}${short_file}:${line_num}: brace expansion {a,b}
  Hint: Use explicit arguments or a wrapper script. See AP-004 in ANTIPATTERNS.md.
"
    fi

  done < "$file"

done < "$_file_list"
rm -f "$_file_list"

# Report results
if [ "$violation_count" -gt 0 ]; then
  printf 'LINT FAIL: %d violation(s) found in agent-facing content\n\n' "$violation_count"
  printf '%s' "$violation_output"
  printf '\nSee AP-004 in ANTIPATTERNS.md for the full Class A pattern catalog.\n'
  exit 1
else
  printf 'LINT PASS: no Class A anti-patterns found in agent-facing content\n'
  exit 0
fi
```

**Key design decisions:**

- **Code-block-only scanning**: The linter only scans inside fenced code blocks (triple backtick regions). Prose descriptions like "Do NOT use `$(date ...)`" are not flagged because they are outside code blocks and serve as documentation.
- **Self-exclusion**: The linter resolves its own absolute path and skips it. `ANTIPATTERNS.md` is also excluded.
- **`# FORBIDDEN` / `# lint-ignore` skip**: Lines inside code blocks that are explicitly documenting forbidden patterns (preceded by `# FORBIDDEN` comment) or marked with `# lint-ignore` are not flagged. This handles examples in `commands/plan-phase.md` that show forbidden patterns for educational purposes.
- **Fixture mode**: `--fixture <file>` allows testing the linter against a single file without scanning the full `commands/` and `templates/` tree.
- **Brace expansion detection**: Matches `{word,word}` but not `${var}` parameter expansion. The regex `\{[a-zA-Z0-9_]+,[a-zA-Z0-9_]+` requires a comma-separated list inside braces.
- **Backtick detection**: Only flags multi-word backtick content in an assignment context (`=` backtick). This avoids false positives on inline-code markdown references.

### Step 2: Verify Bash 3.2 compatibility

Run syntax check:
```
bash -n scripts/verify/anti-pattern-lint.sh
```

Must exit 0 with no output.

### Step 3: Test against a manually created fixture

Create a temporary test fixture containing known violations and run the linter against it with `--fixture`. The fixture should contain:

```markdown
# Test fixture
` `` `bash
state=$(date -u +%Y-%m-%dT%H:%M:%SZ)
` `` `
```

The linter should exit non-zero and report the `$(date ...)` violation with a file:line diagnostic.

## Must-Haves

- `anti-pattern-lint.sh` exits non-zero on a test fixture containing `$(date ...)` with file:line diagnostics
- `anti-pattern-lint.sh` exits non-zero on a test fixture containing backtick command substitution
- `anti-pattern-lint.sh` exits non-zero on a test fixture containing `{a,b}` brace expansion
- `anti-pattern-lint.sh` exits 0 when scanning its own source (self-exclusion works)
- `anti-pattern-lint.sh` is Bash 3.2 compatible

## Verification

```
bash scripts/verify/m016-p03-lint-detects-subst.sh
bash scripts/verify/m016-p03-lint-detects-backtick.sh
bash scripts/verify/m016-p03-lint-detects-brace.sh
bash scripts/verify/m016-p03-lint-self-excludes.sh
bash scripts/verify/m016-p03-lint-bash32.sh
```

Each must print `PASS:` and exit 0. Note: the verify scripts themselves are created in T04.

## Inputs

### From Disk (Pre-existing)
- ANTIPATTERNS.md — AP-004 entry documenting three Class A pattern classes (command substitution, brace expansion, compound bash). The linter's detection rules must align with this catalog. Key patterns: `$(...)`, backtick substitution, `{a,b}` brace expansion. Agent-facing content scope: `commands/*.md`, `templates/*.md`.
- commands/*.md — agent-facing command definitions that the linter will scan
- templates/*.md — agent-facing templates that the linter will scan

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`.
- Must self-exclude its own source file from scans.
- Must exclude `ANTIPATTERNS.md` from scans (it catalogs patterns by definition).
- Scans agent-facing content only: `commands/*.md`, `templates/*.md`. Script internals exempt per AD-4.
- Must not flag documentation of forbidden patterns (lines showing examples of what NOT to do in `# FORBIDDEN` comments).
- Must support `--fixture <file>` mode for testing.

## Expected Output

- scripts/verify/anti-pattern-lint.sh created with detection logic for three Class A pattern classes.
- Linter passes `bash -n` under Bash 3.2.
- Linter exits 0 on clean files, non-zero on files with violations.
- Diagnostics include file path, line number, pattern class, and remediation hint.
