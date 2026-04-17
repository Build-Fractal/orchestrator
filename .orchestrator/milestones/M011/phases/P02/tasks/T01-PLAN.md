---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M011"
name: "Core ingest script skeleton + section splitter"
depends_on: []
---

## Prerequisites

P01 is complete:
- `scripts/knowledge/create-entry.sh` accepts `--id SPEC-*` with `--category spec/*` and creates entries at nested paths like `knowledge/spec/requirement/SPEC-FR-001.md`
- `scripts/knowledge/rebuild-index.sh` scans nested `knowledge/spec/*/` directories
- `.orchestrator/knowledge/spec/` directory tree exists with 6 subdirectories: `story/`, `requirement/`, `constraint/`, `nfr/`, `acceptance/`, `non-goal/`

## Description

Create `scripts/knowledge/ingest-spec.sh` with argument parsing, the heading-level section splitter that reads a markdown spec file and splits it into semantic sections, and a classification router that dispatches each section to the appropriate classifier function. The classifier functions themselves are stubs in this task -- they print the section type and content but do not create entries yet. That wiring happens in T02.

The section splitter is the hardest part of the ingest pipeline because real-world specs have varied structure. The splitter must correctly identify these top-level sections by `## ` (h2) headings:

- `## User Scenarios & Testing` (or similar) -- contains `### User Story N` subsections
- `## Functional Requirements` -- contains `- **FR-NNN**:` list items  
- `## Constraints` -- contains `- ` list items (bold-prefixed or plain)
- `## Non-Goals` -- contains `- ` list items
- `## Success Criteria` -- skipped (not a chunk type for P02)
- `## Problem Statement` -- skipped
- `## Dependencies` -- skipped

Within the User Stories section, acceptance scenarios appear as numbered `Given/When/Then` blocks under `**Acceptance Scenarios**:` within each story.

## Steps

### Step 1: Create the ingest-spec.sh script with argument parsing

Create `scripts/knowledge/ingest-spec.sh` with this structure:

```bash
#!/usr/bin/env bash
# scripts/knowledge/ingest-spec.sh -- Ingest a markdown spec into the knowledge system
# Usage: ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]
#
# Parses a markdown spec file, classifies sections into chunk types
# (story, requirement, constraint, nfr, acceptance, non-goal), and
# creates knowledge entries via create-entry.sh. Calls rebuild-index.sh
# once at the end.
#
# Output: CREATED:, SKIPPED:, SUPERSEDED:, REMOVED: prefixed lines to stdout.
# Errors to stderr. Exit 0 on success, 1 on failure.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Argument parsing ---
SPEC_PATH=""
SLUG=""
SCOPE_TAGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --scope-tags) SCOPE_TAGS="$2"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# --- Validate required arguments ---
if [ -z "$SPEC_PATH" ]; then
  echo "ERROR: --spec-path is required" >&2
  exit 1
fi
if [ -z "$SLUG" ]; then
  echo "ERROR: --slug is required" >&2
  exit 1
fi
if [ ! -f "$SPEC_PATH" ]; then
  echo "ERROR: spec file not found: $SPEC_PATH" >&2
  exit 1
fi

# Default scope-tags to spec slug
if [ -z "$SCOPE_TAGS" ]; then
  SCOPE_TAGS="[spec:$SLUG]"
fi

# --- Counters ---
CREATED_COUNT=0
SKIPPED_COUNT=0
US_SEQ=0
FR_SEQ=0
CON_SEQ=0
NG_SEQ=0
AC_SEQ=0
NFR_SEQ=0
```

**Arguments**:
- `--spec-path` (required): Path to the markdown spec file
- `--slug` (required): Spec slug for scope tags (e.g., `016-autonomous-hardening`)
- `--scope-tags` (optional): Override scope tags; defaults to `[spec:<slug>]`

### Step 2: Implement the top-level section splitter

The splitter reads the file line by line, accumulates content into section buffers, and dispatches to classifier functions when a new `## ` heading is encountered. The key logic:

1. Track the current h2 section name and accumulate body lines
2. When a new `## ` heading is encountered, dispatch the completed section
3. After EOF, dispatch the final section

Add the following after the argument parsing block:

```bash
# --- Section splitter ---
# Reads the spec line by line, splits on ## headings, routes each section
# to the appropriate classifier.

current_h2=""
current_h2_body=""
current_story_heading=""
current_story_body=""
in_story=0

dispatch_section() {
  local section_name="$1"
  local section_body="$2"
  
  # Skip empty sections
  if [ -z "$section_body" ]; then
    return 0
  fi

  case "$section_name" in
    "User Scenarios"*|"User Stories"*)
      classify_stories_section "$section_body"
      ;;
    "Functional Requirements"*)
      classify_requirements_section "$section_body"
      ;;
    "Constraints"*)
      classify_constraints_section "$section_body"
      ;;
    "Non-Goals"*|"Non Goals"*)
      classify_nongoals_section "$section_body"
      ;;
    *)
      # Sections we don't classify: Problem Statement, Success Criteria,
      # Dependencies, etc. Skip silently.
      ;;
  esac
}

# Main read loop
while IFS= read -r line || [ -n "$line" ]; do
  # Detect ## heading (h2)
  case "$line" in
    '## '*)
      # Dispatch previous section
      if [ -n "$current_h2" ]; then
        dispatch_section "$current_h2" "$current_h2_body"
      fi
      # Start new section -- strip "## " prefix and any trailing markup
      current_h2="${line#\#\# }"
      # Remove trailing markup like " *(mandatory)*"
      current_h2="$(printf '%s' "$current_h2" | sed 's/ \*.*$//')"
      current_h2_body=""
      ;;
    *)
      # Accumulate body
      if [ -n "$current_h2" ]; then
        if [ -z "$current_h2_body" ]; then
          current_h2_body="$line"
        else
          current_h2_body="$current_h2_body
$line"
        fi
      fi
      ;;
  esac
done < "$SPEC_PATH"

# Dispatch final section
if [ -n "$current_h2" ]; then
  dispatch_section "$current_h2" "$current_h2_body"
fi
```

### Step 3: Add stub classifier functions

Add classifier function stubs before the main read loop. These stubs will be replaced with full implementations in T02. For now, they just count sections:

```bash
# --- Classifier stubs (implemented in T02) ---

classify_stories_section() {
  local body="$1"
  echo "DEBUG: classify_stories_section called with ${#body} chars" >&2
}

classify_requirements_section() {
  local body="$1"
  echo "DEBUG: classify_requirements_section called with ${#body} chars" >&2
}

classify_constraints_section() {
  local body="$1"
  echo "DEBUG: classify_constraints_section called with ${#body} chars" >&2
}

classify_nongoals_section() {
  local body="$1"
  echo "DEBUG: classify_nongoals_section called with ${#body} chars" >&2
}
```

### Step 4: Add the rebuild-index.sh call and summary output at the end

After the main read loop and final dispatch, add:

```bash
# --- Rebuild index ---
bash "$SCRIPT_DIR/rebuild-index.sh"

# --- Summary ---
echo "INGEST: $SLUG complete. created=$CREATED_COUNT skipped=$SKIPPED_COUNT"
```

### Step 5: Make the script executable

```
chmod +x scripts/knowledge/ingest-spec.sh
```

### Step 6: Create the Bash 3.2 compatibility verification script

Create `scripts/verify/m011-p02-bash32-compat.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail_count=0

for script in "$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"; do
  if ! /bin/bash -n "$script" 2>/dev/null; then
    echo "FAIL: $script does not pass bash -n syntax check"
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: ingest-spec.sh passes Bash 3.2 syntax check"
else
  echo "FAIL: $fail_count script(s) failed syntax check"
  exit 1
fi
```

### Step 7: Verify the skeleton works

Run the script against the 016 spec to confirm the section splitter routes correctly:

```
bash scripts/knowledge/ingest-spec.sh --spec-path specs/016-autonomous-hardening/spec.md --slug 016-autonomous-hardening
```

Expected stderr output should show `classify_stories_section called`, `classify_requirements_section called` (if FRs section exists -- note 016 spec does NOT have a `## Functional Requirements` section, only `## Constraints` and `## Non-Goals`), `classify_constraints_section called`, and `classify_nongoals_section called`. This confirms the splitter is routing correctly.

Also run `bash scripts/verify/m011-p02-bash32-compat.sh` -- it should print `PASS:`.

## Must-Haves

- `ingest-spec.sh` exists at `scripts/knowledge/ingest-spec.sh`, is executable, and accepts `--spec-path` and `--slug` arguments
- The section splitter correctly identifies and routes `## User Scenarios`, `## Constraints`, `## Non-Goals`, and `## Functional Requirements` sections
- The script passes `bash -n` syntax check under `/bin/bash`
- The script calls `rebuild-index.sh` at the end

## Verification

```
bash scripts/verify/m011-p02-bash32-compat.sh
```

Must print `PASS:` and exit 0.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/create-entry.sh` -- the entry creation script that T02 will call. API: `create-entry.sh --id <SPEC-ID> --category <spec/type> --scope-tags <tags> --source-unit <path#section> --description <text> --body <text> [--relates-to <id>]`. Outputs `CREATED: <id>` or `EXISTS: <id>`. Exit 0 on success/exists, 1 on error.
- `scripts/knowledge/rebuild-index.sh` -- regenerates KNOWLEDGE-INDEX.md and knowledge.db from all detail files. API: `rebuild-index.sh [--root <project-root>]`. Outputs `REBUILT: KNOWLEDGE-INDEX.md with N entries`.
- `scripts/lib/hash.sh` -- provides `compute_content_hash()` function. API: `compute_content_hash <string>` returns `sha256:{64-hex}`. Returns empty string and exit 1 if input is empty.
- `specs/016-autonomous-hardening/spec.md` -- real-world test input. Structure: h2 sections for Problem Statement, User Scenarios & Testing (with h3 User Story subsections containing numbered Given/When/Then acceptance scenarios), Success Criteria, Non-Goals, Constraints. Note: this spec has NO `## Functional Requirements` section (requirements are not separately listed). It has 3 user stories, numbered acceptance scenarios within each story, 6 success criteria, 3 non-goals, and 4 constraints.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`, `[[ =~ ]]`.
- Use `case` for string matching, `grep`/`sed` for pattern extraction.
- The section splitter must handle specs that do NOT have all section types (e.g., 016 spec has no `## Functional Requirements` heading).
- The splitter must strip trailing markdown decorators from h2 headings (e.g., `## User Scenarios & Testing *(mandatory)*` becomes `User Scenarios & Testing`).
- No NFR classifier stub is needed yet -- NFRs will be extracted from within the Functional Requirements section or as a standalone `## Non-Functional Requirements` section. The router can be extended in T02.

## Expected Output

- `scripts/knowledge/ingest-spec.sh` created (~100-120 lines): argument parsing, section splitter, stub classifiers, rebuild-index call, summary output
- `scripts/verify/m011-p02-bash32-compat.sh` created (~15 lines)
- Running against a real spec produces debug output showing correct section routing
