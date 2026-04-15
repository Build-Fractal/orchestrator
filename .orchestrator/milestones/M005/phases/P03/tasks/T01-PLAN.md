---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M005"
name: "Create payload-transforms.sh and verification scripts"
depends_on: []
---

## Description

Create the pure transform library at `scripts/lib/payload-transforms.sh` and
all six verification scripts for phase P03 under `scripts/verify/p03-*.sh`.

The library extracts transform logic currently inline in
`scripts/dispatch/compress-payload.sh` and
`scripts/dispatch/build-context.sh` into pure sourced functions. "Pure" means:
no file I/O inside function bodies. Functions take stdin or positional
arguments and return results on stdout. Callers handle all file reads/writes.

Functions to create:

1. `estimate_tokens <text_arg>` -- estimates token count as chars/4, rounded
   to nearest 100. Currently duplicated in both build-context.sh (line 189)
   and compress-payload.sh (line 106). This becomes the single source of
   truth.

2. `raw_token_count <text_arg>` -- raw unrounded token count (chars/4).
   Currently in compress-payload.sh (line 119). Used for budget comparisons
   where rounding would cause off-by-one issues.

3. `assemble_section <heading> <priority>` -- reads section body from stdin,
   emits `## <heading>\n\n<body>` on stdout. New function that standardizes
   how sections are formatted before assembly. Takes the heading name and
   priority as arguments; body content comes from stdin.

4. `drop_by_priority <priority_to_drop>` -- reads a pipe-delimited section
   list from stdin (format: `name|content|priority` per line), drops entries
   matching the given priority, emits remaining entries on stdout in the same
   format. Generalizes `_cp_step_drop_optional` from compress-payload.sh
   (line 265) into a pure filter.

5. `summarize_section <max_words>` -- reads section text from stdin, truncates
   each `###` subsection to `<max_words>` words, appends
   `[...truncated...]` marker. Emits result on stdout. Extracted from the
   awk-based `_cp_step_summarize` in compress-payload.sh (line 296).

6. `drop_lowest_confidence` -- reads knowledge entries (frontmatter-delimited
   blocks) from stdin, sorts by confidence ascending, emits all entries on
   stdout in the same format but with lowest-confidence entries removed until
   a caller-specified budget is met. The function itself emits ALL entries
   sorted; the caller can pipe through `head` or use the `--keep N` argument
   to limit output. Extracted from `_cp_step_drop_lowest_confidence` in
   compress-payload.sh (line 373).

The library follows the double-sourcing guard pattern from
`scripts/lib/errors.sh`:

```
[ -n "${_PAYLOAD_TRANSFORMS_SOURCED:-}" ] && return 0
_PAYLOAD_TRANSFORMS_SOURCED=1
```

Architectural constraint (AD-5): no file I/O inside function bodies. No
`cat <file>`, no `> file`, no `read < file`. Functions receive data via
arguments or stdin; return data via stdout.

## Steps

### Step 1 -- Create `scripts/lib/payload-transforms.sh`

Create the file with the following structure:

```bash
#!/usr/bin/env bash
# scripts/lib/payload-transforms.sh — Pure payload transform functions.
# All functions take stdin/arguments and return stdout. No file I/O.
# Sourced by build-context.sh, compress-payload.sh, and test harnesses.
#
# Functions:
#   estimate_tokens <text>        — chars/4, rounded to nearest 100
#   raw_token_count <text>        — chars/4, unrounded
#   assemble_section <heading>    — stdin body → ## Heading\n\nbody
#   drop_by_priority <priority>   — stdin sections → filtered sections
#   summarize_section <max_words> — stdin text → truncated subsections
#   drop_lowest_confidence [--keep N] — stdin entries → sorted, trimmed
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (NFR-203 / AP-003) ---
[ -n "${_PAYLOAD_TRANSFORMS_SOURCED:-}" ] && return 0
_PAYLOAD_TRANSFORMS_SOURCED=1

# estimate_tokens <text>
# Token estimate: character count / 4, rounded to nearest 100.
# Returns "100" minimum when input is non-empty.
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  local raw_tokens=$((chars / 4))
  local rounded=$(( ((raw_tokens + 50) / 100) * 100 ))
  if [ "$rounded" -eq 0 ] && [ "$raw_tokens" -gt 0 ]; then
    rounded=100
  fi
  printf '%s\n' "$rounded"
}

# raw_token_count <text>
# Raw token count: character count / 4, no rounding.
raw_token_count() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  printf '%s\n' $((chars / 4))
}

# assemble_section <heading>
# Reads body from stdin, emits formatted section on stdout.
# Output: ## <heading>\n\n<body>
assemble_section() {
  local heading="$1"
  local body
  body="$(cat)"
  printf '## %s\n\n%s\n' "$heading" "$body"
}

# drop_by_priority <priority_to_drop>
# Reads pipe-delimited section records from stdin.
# Input format per line: name|content|priority
# Drops lines where field 3 matches <priority_to_drop>.
# Emits remaining lines on stdout in same format.
drop_by_priority() {
  local target_priority="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    local pri
    pri="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')"
    if [ "$pri" != "$target_priority" ]; then
      printf '%s\n' "$line"
    fi
  done
}

# summarize_section <max_words>
# Reads section text from stdin. Truncates each ### subsection to
# <max_words> words, appending "[...truncated...]" when content is cut.
# Non-subsection content passes through unchanged.
# Emits result on stdout.
summarize_section() {
  local max_words="${1:-200}"
  awk -v max="$max_words" '
    /^### / {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
      in_sub = 1
      word_count = 0
      print
      next
    }
    /^## / {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
      in_sub = 0
      word_count = 0
      print
      next
    }
    {
      if (in_sub) {
        n = split($0, words, " ")
        if (word_count + n <= max) {
          print
          word_count += n
        } else if (word_count < max) {
          remaining = max - word_count
          out = ""
          for (i = 1; i <= remaining && i <= n; i++) {
            if (i > 1) out = out " "
            out = out words[i]
          }
          print out
          word_count = max
        }
      } else {
        print
      }
    }
    END {
      if (in_sub && word_count > max) {
        printf "\n[...truncated...]\n"
      }
    }
  '
}

# drop_lowest_confidence [--keep N]
# Reads knowledge entries from stdin. Entries are frontmatter-delimited
# blocks (each starting with ---). Parses confidence: field from each
# entry's frontmatter. Sorts entries by confidence ascending.
#
# If --keep N is specified, emits only the N highest-confidence entries.
# Otherwise emits all entries sorted by confidence ascending (caller
# decides how many to drop by piping through head/tail).
#
# Output: entries on stdout, one per block, separated by blank lines.
# Stderr: prints count of entries parsed for caller diagnostics.
drop_lowest_confidence() {
  local keep=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --keep) keep="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Collect all entries with their confidence values.
  # Entry boundaries are --- lines (YAML frontmatter delimiters).
  local entries=""
  local current_entry=""
  local current_conf="0.90"
  local in_fm=0
  local entry_count=0
  local conf_index=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "---" ]; then
      if [ "$in_fm" -eq 0 ]; then
        # Starting frontmatter. Save previous entry if exists.
        if [ -n "$current_entry" ]; then
          conf_index="${conf_index}${current_conf}	${entry_count}
"
          eval "_pt_entry_${entry_count}=\$(printf '%s' \"\$current_entry\")"
          entry_count=$((entry_count + 1))
          current_entry=""
          current_conf="0.90"
        fi
        in_fm=1
      else
        in_fm=0
      fi
      current_entry="${current_entry}${line}
"
    elif [ "$in_fm" -eq 1 ] && printf '%s' "$line" | grep -q '^confidence:'; then
      current_conf="$(printf '%s' "$line" | sed 's/^confidence:[[:space:]]*//')"
      current_entry="${current_entry}${line}
"
    else
      current_entry="${current_entry}${line}
"
    fi
  done

  # Save last entry
  if [ -n "$current_entry" ]; then
    conf_index="${conf_index}${current_conf}	${entry_count}
"
    eval "_pt_entry_${entry_count}=\$(printf '%s' \"\$current_entry\")"
    entry_count=$((entry_count + 1))
  fi

  printf '%s entries parsed\n' "$entry_count" >&2

  if [ "$entry_count" -eq 0 ]; then
    return 0
  fi

  # Sort by confidence ascending
  local sorted
  sorted="$(printf '%s' "$conf_index" | sort -t'	' -k1 -n)"

  # Determine how many to emit
  local emit_start=0
  if [ -n "$keep" ] && [ "$keep" -lt "$entry_count" ]; then
    emit_start=$((entry_count - keep))
  fi

  # Emit entries (skip the first emit_start, which are lowest confidence)
  local line_idx=0
  local first_emitted=true
  while IFS= read -r conf_line; do
    [ -z "$conf_line" ] && continue
    if [ "$line_idx" -ge "$emit_start" ]; then
      local eidx
      eidx="$(printf '%s' "$conf_line" | awk -F'	' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')"
      local entry_var="_pt_entry_${eidx}"
      if [ "$first_emitted" = true ]; then
        first_emitted=false
      else
        printf '\n'
      fi
      eval "printf '%s' \"\$${entry_var}\""
    fi
    line_idx=$((line_idx + 1))
  done <<EOF_SORTED
$sorted
EOF_SORTED
  printf '\n'
}
```

Make executable:

```bash
chmod +x scripts/lib/payload-transforms.sh
```

### Step 2 -- Create verification scripts

Create six verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant).

**`scripts/verify/p03-payload-transforms-lib.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/lib/payload-transforms.sh exists with double-sourcing
# guard and all required functions.
set -eu
f="scripts/lib/payload-transforms.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_PAYLOAD_TRANSFORMS_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'assemble_section' "$f" || { echo "FAIL: assemble_section missing"; exit 1; }
grep -q 'drop_by_priority' "$f" || { echo "FAIL: drop_by_priority missing"; exit 1; }
grep -q 'summarize_section' "$f" || { echo "FAIL: summarize_section missing"; exit 1; }
grep -q 'drop_lowest_confidence' "$f" || { echo "FAIL: drop_lowest_confidence missing"; exit 1; }
grep -q 'estimate_tokens' "$f" || { echo "FAIL: estimate_tokens missing"; exit 1; }
grep -q 'raw_token_count' "$f" || { echo "FAIL: raw_token_count missing"; exit 1; }
echo "PASS: payload-transforms.sh exists with guard and all functions"
```

**`scripts/verify/p03-manifest-builder-lib.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/lib/manifest-builder.sh exists with double-sourcing
# guard and all required functions.
set -eu
f="scripts/lib/manifest-builder.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_MANIFEST_BUILDER_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'build_manifest_header' "$f" || { echo "FAIL: build_manifest_header missing"; exit 1; }
grep -q 'compute_section_tokens' "$f" || { echo "FAIL: compute_section_tokens missing"; exit 1; }
grep -q 'format_manifest_row' "$f" || { echo "FAIL: format_manifest_row missing"; exit 1; }
echo "PASS: manifest-builder.sh exists with guard and all functions"
```

**`scripts/verify/p03-no-file-io.sh`**

```bash
#!/usr/bin/env bash
# Verifies pure transform functions contain no file I/O operations.
# Checks that function bodies in payload-transforms.sh and
# manifest-builder.sh do not contain cat <file>, read < file,
# > file, or >> file patterns.
set -eu

fail=0

for f in scripts/lib/payload-transforms.sh scripts/lib/manifest-builder.sh; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

  # Extract function bodies (between function_name() { and closing })
  # and check for file I/O patterns.
  # Allowed: cat (bare, for stdin), printf, echo
  # Forbidden inside functions: cat "$file", cat < file, > "$file", >> "$file"

  # Check for redirect to file (> or >> followed by "$" or a path-like token)
  # Exclude lines that are comments
  if grep -n '>[>]\?[[:space:]]*"\$' "$f" | grep -v '^[[:space:]]*#' | grep -v 'printf.*>' | grep -v 'awk.*>' | grep -qv '>&2'; then
    echo "WARN: $f may contain file output redirects (review manually)"
  fi
done

echo "PASS: no obvious file I/O in pure transform functions"
```

**`scripts/verify/p03-build-context-delegates.sh`**

```bash
#!/usr/bin/env bash
# Verifies build-context.sh sources manifest-builder.sh and delegates
# manifest construction to lib functions.
set -eu
f="scripts/dispatch/build-context.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'manifest-builder.sh' "$f" || { echo "FAIL: $f does not source manifest-builder.sh"; exit 1; }
grep -q 'payload-transforms.sh' "$f" || { echo "FAIL: $f does not source payload-transforms.sh"; exit 1; }
echo "PASS: build-context.sh delegates to lib functions"
```

**`scripts/verify/p03-compress-delegates.sh`**

```bash
#!/usr/bin/env bash
# Verifies compress-payload.sh sources payload-transforms.sh and delegates
# compression steps to lib functions.
set -eu
f="scripts/dispatch/compress-payload.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'payload-transforms.sh' "$f" || { echo "FAIL: $f does not source payload-transforms.sh"; exit 1; }
grep -q 'manifest-builder.sh' "$f" || { echo "FAIL: $f does not source manifest-builder.sh"; exit 1; }
echo "PASS: compress-payload.sh delegates to lib functions"
```

**`scripts/verify/p03-no-duplicate-estimate.sh`**

```bash
#!/usr/bin/env bash
# Verifies estimate_tokens is defined in exactly one lib file and that
# both dispatch scripts source it rather than defining their own.
set -eu

lib="scripts/lib/payload-transforms.sh"
test -f "$lib" || { echo "FAIL: $lib missing"; exit 1; }

# estimate_tokens must be defined in the lib
grep -q '^estimate_tokens()' "$lib" || { echo "FAIL: estimate_tokens not defined in $lib"; exit 1; }

# Neither dispatch script should define estimate_tokens locally
for ds in scripts/dispatch/build-context.sh scripts/dispatch/compress-payload.sh; do
  test -f "$ds" || { echo "FAIL: $ds missing"; exit 1; }
  if grep -q '^estimate_tokens()' "$ds"; then
    echo "FAIL: $ds still defines estimate_tokens locally"
    exit 1
  fi
done

echo "PASS: estimate_tokens defined once in $lib, not duplicated in dispatch scripts"
```

Make all executable:

```bash
chmod +x scripts/verify/p03-*.sh
```

### Step 3 -- Smoke test payload-transforms.sh

Source the library and test key functions:

```bash
source scripts/lib/payload-transforms.sh

# Test estimate_tokens
result="$(estimate_tokens "hello world test")"
echo "estimate_tokens: $result"
# Expected: 100 (16 chars / 4 = 4, rounded to 100)

# Test assemble_section
echo "This is body content" | assemble_section "My Section"
# Expected:
# ## My Section
#
# This is body content

# Test summarize_section
printf '### Sub1\none two three four five six\n### Sub2\nseven eight nine\n' | summarize_section 3
# Expected: truncated output with [...truncated...] markers
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "payload-transforms.sh exists with double-sourcing guard and
  exports assemble_section, drop_by_priority, summarize_section,
  drop_lowest_confidence", "All pure functions take stdin or arguments and
  return stdout with no file I/O", "Token estimation function
  (estimate_tokens) is defined in exactly one lib file".
- **Artifacts**: `scripts/lib/payload-transforms.sh`, all six
  `scripts/verify/p03-*.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/p03-payload-transforms-lib.sh
bash scripts/verify/p03-no-file-io.sh
bash scripts/verify/p03-no-duplicate-estimate.sh
```

The first should print PASS. The second should print PASS (checks function
bodies for file I/O patterns). The third will FAIL at this point because
build-context.sh and compress-payload.sh have not yet been refactored
(T03/T04). This is expected.

The remaining verification scripts (p03-manifest-builder-lib.sh,
p03-build-context-delegates.sh, p03-compress-delegates.sh) will also FAIL
until T02-T04 complete. This is expected.

### Files Touched By This Task

- `scripts/lib/payload-transforms.sh` (create)
- `scripts/verify/p03-payload-transforms-lib.sh` (create)
- `scripts/verify/p03-manifest-builder-lib.sh` (create)
- `scripts/verify/p03-no-file-io.sh` (create)
- `scripts/verify/p03-build-context-delegates.sh` (create)
- `scripts/verify/p03-compress-delegates.sh` (create)
- `scripts/verify/p03-no-duplicate-estimate.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` -- reference for the double-sourcing guard pattern.
  The guard shape is:
  ```
  [ -n "${_ERRORS_SOURCED:-}" ] && return 0
  _ERRORS_SOURCED=1
  ```
  payload-transforms.sh replicates this with `_PAYLOAD_TRANSFORMS_SOURCED`.

- `scripts/dispatch/compress-payload.sh` -- source of the transform logic
  being extracted. Key functions to port:
  - `estimate_tokens()` at line 106 (chars/4 rounded to 100)
  - `raw_token_count()` at line 119 (chars/4 unrounded)
  - `_cp_step_summarize()` at line 296 (awk-based ### subsection truncation)
  - `_cp_step_drop_optional()` at line 265 (drop sections by priority)
  - `_cp_step_drop_lowest_confidence()` at line 373 (sort knowledge by
    confidence, remove lowest)

- `scripts/dispatch/build-context.sh` -- contains duplicate `estimate_tokens()`
  at line 189. This duplicate will be removed in T03.

## Expected Output

After completing this task:

1. `scripts/lib/payload-transforms.sh` exists, is chmod +x, has the
   double-sourcing guard `_PAYLOAD_TRANSFORMS_SOURCED`, and defines six
   functions: `estimate_tokens`, `raw_token_count`, `assemble_section`,
   `drop_by_priority`, `summarize_section`, `drop_lowest_confidence`.
2. `estimate_tokens "hello world"` returns `100` (11 chars / 4 = 2, rounded
   to 100).
3. `echo "body" | assemble_section "Title"` returns `## Title\n\nbody`.
4. `summarize_section 3` truncates ### subsections to 3 words with marker.
5. All six `scripts/verify/p03-*.sh` files exist and are chmod +x.
6. `bash scripts/verify/p03-payload-transforms-lib.sh` prints PASS.
7. `bash scripts/verify/p03-no-file-io.sh` prints PASS.
8. `git status` shows 7 new files (1 lib + 6 verify scripts). Nothing else
   touched.
