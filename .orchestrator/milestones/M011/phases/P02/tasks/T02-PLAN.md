---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M011"
name: "Section classifiers + chunk creation"
depends_on: [T01]
---

## Prerequisites

T01 is complete:
- `scripts/knowledge/ingest-spec.sh` exists with argument parsing, section splitter, and stub classifier functions
- The section splitter routes `## User Scenarios`, `## Functional Requirements`, `## Constraints`, and `## Non-Goals` sections to the corresponding `classify_*_section()` functions
- Counter variables exist: `US_SEQ`, `FR_SEQ`, `CON_SEQ`, `NG_SEQ`, `AC_SEQ`, `NFR_SEQ`, `CREATED_COUNT`, `SKIPPED_COUNT`
- `SPEC_PATH`, `SLUG`, and `SCOPE_TAGS` are set from arguments

## Description

Replace the stub classifier functions in `scripts/knowledge/ingest-spec.sh` with full implementations that:

1. Parse section content to extract individual items (stories, requirements, constraints, etc.)
2. Generate SPEC-prefixed IDs (SPEC-US-001, SPEC-FR-001, etc.)
3. Call `create-entry.sh` with the correct `--id`, `--category`, `--scope-tags`, `--source-unit`, `--description`, `--body`, and `--relates-to` arguments
4. Track parent story IDs for acceptance scenario `relates_to` edges

Also add a helper function `create_chunk()` that wraps the `create-entry.sh` call and handles counting and output formatting.

## Steps

### Step 1: Add the create_chunk helper function

Replace the classifier stub block with the `create_chunk` helper. Insert this before the classifier functions:

```bash
# --- Source hash library ---
source "$SCRIPT_DIR/../lib/hash.sh"

# --- Helper: create a single spec chunk ---
# Usage: create_chunk <id> <category> <source_section> <description> <body> [relates_to]
create_chunk() {
  local chunk_id="$1"
  local category="$2"
  local source_section="$3"
  local description="$4"
  local body="$5"
  local relates_to="${6:-}"

  # Compute content hash
  local content_hash=""
  content_hash="$(compute_content_hash "$body")" || true

  # Build create-entry.sh arguments
  local args=""
  args="--id $chunk_id"
  args="$args --category $category"
  args="$args --scope-tags $SCOPE_TAGS"
  args="$args --source-unit ${SPEC_PATH}#${source_section}"
  args="$args --source-type spec-ingest"
  args="$args --description $description"

  # Call create-entry.sh
  local output=""
  if [ -n "$relates_to" ]; then
    output="$(bash "$SCRIPT_DIR/create-entry.sh" \
      --id "$chunk_id" \
      --category "$category" \
      --scope-tags "$SCOPE_TAGS" \
      --source-unit "${SPEC_PATH}#${source_section}" \
      --source-type "spec-ingest" \
      --description "$description" \
      --body "$body" \
      --relates-to "$relates_to" 2>&1)" || true
  else
    output="$(bash "$SCRIPT_DIR/create-entry.sh" \
      --id "$chunk_id" \
      --category "$category" \
      --scope-tags "$SCOPE_TAGS" \
      --source-unit "${SPEC_PATH}#${source_section}" \
      --source-type "spec-ingest" \
      --description "$description" \
      --body "$body" 2>&1)" || true
  fi

  # Parse output and update counters
  case "$output" in
    CREATED:*)
      CREATED_COUNT=$((CREATED_COUNT + 1))
      echo "$output"
      ;;
    EXISTS:*)
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      echo "SKIPPED: $chunk_id (unchanged)"
      ;;
    *)
      echo "ERROR: create-entry.sh failed for $chunk_id: $output" >&2
      ;;
  esac
}
```

**Important**: The `source "$SCRIPT_DIR/../lib/hash.sh"` line sources the hash library. The path `$SCRIPT_DIR/../lib/hash.sh` resolves from `scripts/knowledge/` to `scripts/lib/hash.sh`.

### Step 2: Implement classify_stories_section

This is the most complex classifier. It must:
1. Split the stories section on `### User Story` headings
2. For each story, extract the story name and body
3. Within each story, find acceptance scenarios (numbered `Given/When/Then` blocks)
4. Create the story chunk first, then create acceptance chunks with `relates_to` pointing to the story

Replace the `classify_stories_section` stub:

```bash
classify_stories_section() {
  local body="$1"
  local current_story_name=""
  local current_story_num=""
  local current_story_body=""
  local in_acceptance=0
  local current_ac_body=""
  local current_ac_num=""
  local story_id=""

  # Process line by line
  while IFS= read -r line || [ -n "$line" ]; do
    # Detect ### User Story heading
    case "$line" in
      '### User Story '*)
        # Dispatch previous story if any
        if [ -n "$current_story_name" ]; then
          _emit_story "$current_story_num" "$current_story_name" "$current_story_body" "$story_id"
        fi
        # Extract story number and name
        # Format: ### User Story N - Name (Priority: PN)
        current_story_num="$(printf '%s' "$line" | sed 's/^### User Story \([0-9]*\).*/\1/')"
        current_story_name="$(printf '%s' "$line" | sed 's/^### User Story [0-9]* *- *//;s/ *(Priority:.*//')"
        current_story_body=""
        in_acceptance=0
        current_ac_body=""
        current_ac_num=""
        US_SEQ=$((US_SEQ + 1))
        story_id="$(printf 'SPEC-US-%03d' "$US_SEQ")"
        ;;
      *)
        # Accumulate story body
        if [ -n "$current_story_name" ]; then
          if [ -z "$current_story_body" ]; then
            current_story_body="$line"
          else
            current_story_body="$current_story_body
$line"
          fi
        fi
        ;;
    esac
  done <<EOF_STORIES
$body
EOF_STORIES

  # Dispatch final story
  if [ -n "$current_story_name" ]; then
    _emit_story "$current_story_num" "$current_story_name" "$current_story_body" "$story_id"
  fi
}

# Helper: emit a story chunk and its acceptance scenarios
_emit_story() {
  local story_num="$1"
  local story_name="$2"
  local story_body="$3"
  local story_id="$4"

  # Create the story chunk (body is everything up to Acceptance Scenarios)
  local story_text=""
  local ac_section=""
  local in_ac_section=0

  # Split story body into narrative (before Acceptance Scenarios) and AC section
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *"Acceptance Scenarios"*)
        in_ac_section=1
        ;;
      *)
        if [ "$in_ac_section" -eq 0 ]; then
          if [ -z "$story_text" ]; then
            story_text="$line"
          else
            story_text="$story_text
$line"
          fi
        else
          if [ -z "$ac_section" ]; then
            ac_section="$line"
          else
            ac_section="$ac_section
$line"
          fi
        fi
        ;;
    esac
  done <<EOF_STORY_BODY
$story_body
EOF_STORY_BODY

  # Create the story entry
  create_chunk "$story_id" "spec/story" "US-${story_num}" "$story_name" "$story_text"

  # Parse and create acceptance scenarios from the AC section
  if [ -n "$ac_section" ]; then
    _parse_acceptance_scenarios "$ac_section" "$story_id"
  fi
}

# Helper: parse numbered Given/When/Then blocks into acceptance chunks
_parse_acceptance_scenarios() {
  local ac_body="$1"
  local parent_story_id="$2"
  local current_ac_text=""
  local current_ac_start=""

  while IFS= read -r line || [ -n "$line" ]; do
    # Detect numbered AC items: "N. **Given**" or "N. Given"
    case "$line" in
      [0-9]*'. '**|[0-9]*'. **Given'*|[0-9]*'. Given'*)
        # Emit previous AC if any
        if [ -n "$current_ac_text" ]; then
          AC_SEQ=$((AC_SEQ + 1))
          local ac_id
          ac_id="$(printf 'SPEC-AC-%03d' "$AC_SEQ")"
          # Extract first sentence as description (up to first comma or period)
          local ac_desc
          ac_desc="$(printf '%s' "$current_ac_text" | head -1 | sed 's/^[0-9]*\. *//' | sed 's/\*\*//g' | cut -c1-80)"
          create_chunk "$ac_id" "spec/acceptance" "AC-${AC_SEQ}" "$ac_desc" "$current_ac_text" "$parent_story_id"
        fi
        current_ac_text="$line"
        ;;
      *)
        # Continuation of current AC
        if [ -n "$current_ac_text" ]; then
          current_ac_text="$current_ac_text
$line"
        fi
        ;;
    esac
  done <<EOF_AC
$ac_body
EOF_AC

  # Emit final AC
  if [ -n "$current_ac_text" ]; then
    AC_SEQ=$((AC_SEQ + 1))
    local ac_id
    ac_id="$(printf 'SPEC-AC-%03d' "$AC_SEQ")"
    local ac_desc
    ac_desc="$(printf '%s' "$current_ac_text" | head -1 | sed 's/^[0-9]*\. *//' | sed 's/\*\*//g' | cut -c1-80)"
    create_chunk "$ac_id" "spec/acceptance" "AC-${AC_SEQ}" "$ac_desc" "$current_ac_text" "$parent_story_id"
  fi
}
```

**Key design decisions in this classifier**:
- Story numbering uses the sequential `US_SEQ` counter, not the story number from the heading (which may not be sequential or may be missing)
- Acceptance scenarios are numbered globally (AC_SEQ) not per-story, matching the SPEC-AC-NNN convention
- The `relates_to` edge from AC to parent story is set via the `create_chunk` helper's 6th argument
- The story body is split at `**Acceptance Scenarios**:` -- everything before is the story text, everything after is parsed for ACs
- The AC detection pattern matches numbered items starting with a digit followed by period (e.g., `1. **Given**`)

### Step 3: Implement classify_requirements_section

This handles the `## Functional Requirements` section. Requirements are `- **FR-NNN**:` prefixed list items.

```bash
classify_requirements_section() {
  local body="$1"
  local current_fr_id=""
  local current_fr_body=""

  while IFS= read -r line || [ -n "$line" ]; do
    # Detect FR-NNN items: "- **FR-NNN**: description"
    case "$line" in
      *'**FR-'[0-9]*)
        # Emit previous FR if any
        if [ -n "$current_fr_id" ]; then
          _emit_requirement "$current_fr_id" "$current_fr_body"
        fi
        # Extract FR ID number
        current_fr_id="$(printf '%s' "$line" | sed 's/.*\*\*FR-\([0-9]*\)\*\*.*/\1/')"
        current_fr_body="$line"
        ;;
      '  '*)
        # Continuation line (indented under the FR item)
        if [ -n "$current_fr_id" ]; then
          current_fr_body="$current_fr_body
$line"
        fi
        ;;
      '')
        # Blank line -- part of current FR if we have one
        if [ -n "$current_fr_id" ]; then
          current_fr_body="$current_fr_body
$line"
        fi
        ;;
      *)
        # Non-FR content -- emit previous and reset
        if [ -n "$current_fr_id" ]; then
          _emit_requirement "$current_fr_id" "$current_fr_body"
          current_fr_id=""
          current_fr_body=""
        fi
        ;;
    esac
  done <<EOF_FR
$body
EOF_FR

  # Emit final FR
  if [ -n "$current_fr_id" ]; then
    _emit_requirement "$current_fr_id" "$current_fr_body"
  fi
}

_emit_requirement() {
  local fr_num="$1"
  local fr_body="$2"

  FR_SEQ=$((FR_SEQ + 1))
  local fr_id
  fr_id="$(printf 'SPEC-FR-%03d' "$FR_SEQ")"
  # Extract description: strip the "- **FR-NNN**: " prefix from first line
  local description
  description="$(printf '%s' "$fr_body" | head -1 | sed 's/^- \*\*FR-[0-9]*\*\*:[[:space:]]*//')"
  create_chunk "$fr_id" "spec/requirement" "FR-$(printf '%03d' "$fr_num")" "$description" "$fr_body"
}
```

**Note**: The FR_SEQ counter increments sequentially. The `fr_num` from the spec text (the NNN in FR-NNN) is used in the `source_unit` field, not in the SPEC-FR-NNN ID. The SPEC-FR-NNN ID uses the sequential counter to handle specs where FR numbering may have gaps. However, for consistency with human expectations, the SPEC-FR ID number matches the source FR number when possible. The implementation uses `FR_SEQ` but sets it from the parsed FR number so SPEC-FR-001 maps to FR-001:

Actually, to keep IDs stable and predictable, use the source FR number directly in the SPEC ID:

```bash
_emit_requirement() {
  local fr_num="$1"
  local fr_body="$2"

  local fr_padded
  fr_padded="$(printf '%03d' "$fr_num")"
  local fr_id="SPEC-FR-${fr_padded}"
  FR_SEQ=$((FR_SEQ + 1))
  # Extract description
  local description
  description="$(printf '%s' "$fr_body" | head -1 | sed 's/^- \*\*FR-[0-9]*\*\*:[[:space:]]*//')"
  create_chunk "$fr_id" "spec/requirement" "FR-${fr_padded}" "$description" "$fr_body"
}
```

### Step 4: Implement classify_constraints_section

Constraints are list items under `## Constraints`. They may be bold-prefixed (`- **Must...**`) or plain (`- Must...`).

```bash
classify_constraints_section() {
  local body="$1"
  local current_con_body=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '- '*)
        # New constraint item
        if [ -n "$current_con_body" ]; then
          _emit_constraint "$current_con_body"
        fi
        current_con_body="$line"
        ;;
      '  '*)
        # Continuation of current constraint
        if [ -n "$current_con_body" ]; then
          current_con_body="$current_con_body
$line"
        fi
        ;;
      '')
        # Blank lines within constraint
        if [ -n "$current_con_body" ]; then
          current_con_body="$current_con_body
$line"
        fi
        ;;
      *)
        # Non-list content, emit and reset
        if [ -n "$current_con_body" ]; then
          _emit_constraint "$current_con_body"
          current_con_body=""
        fi
        ;;
    esac
  done <<EOF_CON
$body
EOF_CON

  # Emit final constraint
  if [ -n "$current_con_body" ]; then
    _emit_constraint "$current_con_body"
  fi
}

_emit_constraint() {
  local con_body="$1"
  CON_SEQ=$((CON_SEQ + 1))
  local con_id
  con_id="$(printf 'SPEC-CON-%03d' "$CON_SEQ")"
  # Extract description: strip "- " prefix and any bold markers from first line
  local description
  description="$(printf '%s' "$con_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | cut -c1-80)"
  create_chunk "$con_id" "spec/constraint" "CON-${CON_SEQ}" "$description" "$con_body"
}
```

### Step 5: Implement classify_nongoals_section

Non-goals follow the same pattern as constraints: list items under `## Non-Goals`.

```bash
classify_nongoals_section() {
  local body="$1"
  local current_ng_body=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '- '*)
        if [ -n "$current_ng_body" ]; then
          _emit_nongoal "$current_ng_body"
        fi
        current_ng_body="$line"
        ;;
      '  '*)
        if [ -n "$current_ng_body" ]; then
          current_ng_body="$current_ng_body
$line"
        fi
        ;;
      '')
        if [ -n "$current_ng_body" ]; then
          current_ng_body="$current_ng_body
$line"
        fi
        ;;
      *)
        if [ -n "$current_ng_body" ]; then
          _emit_nongoal "$current_ng_body"
          current_ng_body=""
        fi
        ;;
    esac
  done <<EOF_NG
$body
EOF_NG

  if [ -n "$current_ng_body" ]; then
    _emit_nongoal "$current_ng_body"
  fi
}

_emit_nongoal() {
  local ng_body="$1"
  NG_SEQ=$((NG_SEQ + 1))
  local ng_id
  ng_id="$(printf 'SPEC-NG-%03d' "$NG_SEQ")"
  local description
  description="$(printf '%s' "$ng_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | sed 's/\*\*.*\*\* *//' | cut -c1-80)"
  create_chunk "$ng_id" "spec/non-goal" "NG-${NG_SEQ}" "$description" "$ng_body"
}
```

### Step 6: Add NFR classification support to the dispatch_section router

If a spec has a `## Non-Functional Requirements` section, route it to a classifier. NFRs can also appear as items with "NFR-" prefix under other headings. For now, add a simple NFR section classifier:

Add to the `dispatch_section` case block:

```bash
    "Non-Functional Requirements"*|"NFRs"*)
      classify_nfr_section "$section_body"
      ;;
```

And implement the NFR classifier (same pattern as constraints):

```bash
classify_nfr_section() {
  local body="$1"
  local current_nfr_body=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '- '*)
        if [ -n "$current_nfr_body" ]; then
          _emit_nfr "$current_nfr_body"
        fi
        current_nfr_body="$line"
        ;;
      '  '*)
        if [ -n "$current_nfr_body" ]; then
          current_nfr_body="$current_nfr_body
$line"
        fi
        ;;
      '')
        if [ -n "$current_nfr_body" ]; then
          current_nfr_body="$current_nfr_body
$line"
        fi
        ;;
      *)
        if [ -n "$current_nfr_body" ]; then
          _emit_nfr "$current_nfr_body"
          current_nfr_body=""
        fi
        ;;
    esac
  done <<EOF_NFR
$body
EOF_NFR

  if [ -n "$current_nfr_body" ]; then
    _emit_nfr "$current_nfr_body"
  fi
}

_emit_nfr() {
  local nfr_body="$1"
  NFR_SEQ=$((NFR_SEQ + 1))
  local nfr_id
  nfr_id="$(printf 'SPEC-NFR-%03d' "$NFR_SEQ")"
  local description
  description="$(printf '%s' "$nfr_body" | head -1 | sed 's/^- //' | sed 's/\*\*//g' | cut -c1-80)"
  create_chunk "$nfr_id" "spec/nfr" "NFR-${NFR_SEQ}" "$description" "$nfr_body"
}
```

### Step 7: Create classification verification scripts

Create the following verification scripts under `scripts/verify/`. Each script creates a temp project root, writes a minimal synthetic spec, runs `ingest-spec.sh`, and checks that the correct entries were created.

**`scripts/verify/m011-p02-classify-stories.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up minimal structure
mkdir -p "$TMP_ROOT/knowledge/spec/story"
mkdir -p "$TMP_ROOT/knowledge/spec/acceptance"
mkdir -p "$TMP_ROOT/.orchestrator"

# Create synthetic spec with one story + acceptance scenarios
cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## User Scenarios & Testing

### User Story 1 - Login Flow (Priority: P1)

A user wants to log in.

**Acceptance Scenarios**:

1. **Given** a valid user, **When** they log in, **Then** they see a dashboard.
2. **Given** an invalid user, **When** they log in, **Then** they see an error.

---
SPEC

# Run ingest
output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

# Check story was created
if echo "$output" | grep -q "CREATED: SPEC-US-001"; then
  echo "PASS: User story classified as spec/story with SPEC-US-001 ID"
else
  echo "FAIL: Expected CREATED: SPEC-US-001 in output"
  echo "Output: $output"
  exit 1
fi

# Check ACs were created with relates_to
if echo "$output" | grep -q "CREATED: SPEC-AC-001"; then
  echo "PASS: Acceptance scenario 1 classified as spec/acceptance"
else
  echo "FAIL: Expected CREATED: SPEC-AC-001 in output"
  echo "Output: $output"
  exit 1
fi

if echo "$output" | grep -q "CREATED: SPEC-AC-002"; then
  echo "PASS: Acceptance scenario 2 classified as spec/acceptance"
else
  echo "FAIL: Expected CREATED: SPEC-AC-002 in output"
  echo "Output: $output"
  exit 1
fi

# Check relates_to edge in AC file
ac_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-001.md"
if [ -f "$ac_file" ]; then
  if grep -q "relates_to:.*SPEC-US-001" "$ac_file"; then
    echo "PASS: AC-001 has relates_to edge to SPEC-US-001"
  else
    echo "FAIL: AC-001 missing relates_to edge to SPEC-US-001"
    cat "$ac_file"
    exit 1
  fi
else
  echo "FAIL: AC file not created at $ac_file"
  exit 1
fi
```

**`scripts/verify/m011-p02-classify-requirements.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/requirement"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Functional Requirements

- **FR-001**: The system shall accept user input.
- **FR-002**: The system shall validate input before processing.
- **FR-003**: The system shall log all errors to stderr.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

pass=0
for id in SPEC-FR-001 SPEC-FR-002 SPEC-FR-003; do
  if echo "$output" | grep -q "CREATED: $id"; then
    pass=$((pass + 1))
  else
    echo "FAIL: Expected CREATED: $id in output"
    echo "Output: $output"
    exit 1
  fi
done

# Check category in frontmatter
fr_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md"
if [ -f "$fr_file" ] && grep -q "category: spec/requirement" "$fr_file"; then
  echo "PASS: $pass/3 requirements classified as spec/requirement with correct IDs"
else
  echo "FAIL: FR-001 file missing or wrong category"
  exit 1
fi
```

**`scripts/verify/m011-p02-classify-constraints.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/constraint"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Constraints

- Must ship before M009.
- Must remain Bash 3.2 compatible.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

if echo "$output" | grep -q "CREATED: SPEC-CON-001" && echo "$output" | grep -q "CREATED: SPEC-CON-002"; then
  echo "PASS: 2 constraints classified as spec/constraint with SPEC-CON-NNN IDs"
else
  echo "FAIL: Expected CREATED: SPEC-CON-001 and SPEC-CON-002"
  echo "Output: $output"
  exit 1
fi
```

**`scripts/verify/m011-p02-classify-nongoals.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/non-goal"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Non-Goals

- Expanding autonomy to credential prompts.
- Hardening interactive commands.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

if echo "$output" | grep -q "CREATED: SPEC-NG-001" && echo "$output" | grep -q "CREATED: SPEC-NG-002"; then
  echo "PASS: 2 non-goals classified as spec/non-goal with SPEC-NG-NNN IDs"
else
  echo "FAIL: Expected CREATED: SPEC-NG-001 and SPEC-NG-002"
  echo "Output: $output"
  exit 1
fi
```

**`scripts/verify/m011-p02-classify-acceptance.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/story"
mkdir -p "$TMP_ROOT/knowledge/spec/acceptance"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## User Scenarios & Testing

### User Story 1 - Login (Priority: P1)

Story text here.

**Acceptance Scenarios**:

1. **Given** valid creds, **When** login, **Then** success.
2. **Given** expired token, **When** refresh, **Then** new token.
3. **Given** locked account, **When** login, **Then** lockout message.

---

### User Story 2 - Logout (Priority: P2)

Story text here.

**Acceptance Scenarios**:

1. **Given** active session, **When** logout, **Then** session destroyed.

---
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

# Should have 2 stories and 4 acceptance scenarios
for id in SPEC-US-001 SPEC-US-002 SPEC-AC-001 SPEC-AC-002 SPEC-AC-003 SPEC-AC-004; do
  if ! echo "$output" | grep -q "CREATED: $id"; then
    echo "FAIL: Expected CREATED: $id in output"
    echo "Output: $output"
    exit 1
  fi
done

# Verify AC-001 through AC-003 relate to US-001
for num in 001 002 003; do
  ac_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-${num}.md"
  if ! grep -q "SPEC-US-001" "$ac_file" 2>/dev/null; then
    echo "FAIL: SPEC-AC-${num} should relate_to SPEC-US-001"
    exit 1
  fi
done

# Verify AC-004 relates to US-002
ac4_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-004.md"
if ! grep -q "SPEC-US-002" "$ac4_file" 2>/dev/null; then
  echo "FAIL: SPEC-AC-004 should relate_to SPEC-US-002"
  exit 1
fi

echo "PASS: 4 acceptance scenarios correctly linked to their parent stories"
```

**`scripts/verify/m011-p02-source-unit.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/constraint"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Constraints

- Must be fast.
SPEC

PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-source 2>/dev/null || true

con_file="$TMP_ROOT/knowledge/spec/constraint/SPEC-CON-001.md"
if [ -f "$con_file" ]; then
  source_unit="$(sed -n '/^---$/,/^---$/p' "$con_file" | grep "^source_unit:" | head -1)"
  if echo "$source_unit" | grep -q "test-spec.md"; then
    echo "PASS: source_unit contains spec path reference"
  else
    echo "FAIL: source_unit does not reference spec path: $source_unit"
    exit 1
  fi
else
  echo "FAIL: Constraint file not created"
  exit 1
fi
```

### Step 8: Create the ingest-creates-chunks verification script

This is the main end-to-end test for T02. It runs ingest against the synthetic spec and verifies overall chunk creation:

**`scripts/verify/m011-p02-ingest-creates-chunks.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up full spec directory structure
for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

# Create a comprehensive test spec
cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Feature Spec

## Problem Statement

This is a test.

## User Scenarios & Testing

### User Story 1 - Create Widget (Priority: P1)

A user creates a widget.

**Acceptance Scenarios**:

1. **Given** valid input, **When** submitted, **Then** widget created.

---

## Functional Requirements

- **FR-001**: Accept widget input.
- **FR-002**: Validate widget data.

## Constraints

- Must be Bash 3.2 compatible.

## Non-Goals

- No GUI support.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-feature 2>&1)" || true

# Count CREATED lines
created_count="$(echo "$output" | grep -c "^CREATED:" || true)"

if [ "$created_count" -ge 6 ]; then
  echo "PASS: ingest-spec.sh created $created_count chunks from test spec (expected >= 6: 1 story, 1 AC, 2 FRs, 1 constraint, 1 non-goal)"
else
  echo "FAIL: Expected >= 6 CREATED lines, got $created_count"
  echo "Output: $output"
  exit 1
fi
```

### Step 9: Run all verification scripts

```
bash scripts/verify/m011-p02-classify-stories.sh
bash scripts/verify/m011-p02-classify-requirements.sh
bash scripts/verify/m011-p02-classify-constraints.sh
bash scripts/verify/m011-p02-classify-nongoals.sh
bash scripts/verify/m011-p02-classify-acceptance.sh
bash scripts/verify/m011-p02-source-unit.sh
bash scripts/verify/m011-p02-ingest-creates-chunks.sh
bash scripts/verify/m011-p02-bash32-compat.sh
```

All must print `PASS:` and exit 0.

## Must-Haves

- `classify_stories_section` correctly splits `### User Story N` headings and extracts story text and acceptance scenarios
- `classify_requirements_section` correctly parses `- **FR-NNN**:` items from the Functional Requirements section
- `classify_constraints_section` correctly parses list items from the Constraints section
- `classify_nongoals_section` correctly parses list items from the Non-Goals section
- Acceptance scenarios have `relates_to` edges pointing to their parent story
- Each chunk has `source_unit` containing the spec path
- All chunks are created via `create-entry.sh` with correct `--id`, `--category`, `--body`, and `--relates-to` arguments

## Verification

```
bash scripts/verify/m011-p02-classify-stories.sh
bash scripts/verify/m011-p02-classify-requirements.sh
bash scripts/verify/m011-p02-classify-constraints.sh
bash scripts/verify/m011-p02-classify-nongoals.sh
bash scripts/verify/m011-p02-classify-acceptance.sh
bash scripts/verify/m011-p02-source-unit.sh
bash scripts/verify/m011-p02-ingest-creates-chunks.sh
bash scripts/verify/m011-p02-bash32-compat.sh
```

All must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `scripts/knowledge/ingest-spec.sh` (from T01)
  - Key API: script accepts `--spec-path <path>`, `--slug <slug>`, `--scope-tags <tags>`. Has `dispatch_section()` routing function and stub classifiers. Variables available: `SPEC_PATH`, `SLUG`, `SCOPE_TAGS`, `SCRIPT_DIR`, counters `US_SEQ`, `FR_SEQ`, `CON_SEQ`, `NG_SEQ`, `AC_SEQ`, `NFR_SEQ`, `CREATED_COUNT`, `SKIPPED_COUNT`.
  - The section splitter reads the spec file, accumulates body text per h2 section, and calls `dispatch_section "$current_h2" "$current_h2_body"` for each section.
  - `dispatch_section` routes to `classify_stories_section`, `classify_requirements_section`, `classify_constraints_section`, `classify_nongoals_section` based on section name matching.

### From Disk (Pre-existing)
- `scripts/knowledge/create-entry.sh` -- creates knowledge entries. API: `create-entry.sh --id <SPEC-ID> --category <spec/type> --scope-tags <tags> --source-unit <path#section> --source-type <type> --description <text> --body <text> [--relates-to <id>]`. Outputs `CREATED: <id> at knowledge/<category>/<id>.md` for new entries, `EXISTS: <id> already exists` for duplicate calls. Exit 0 on success or exists.
- `scripts/lib/hash.sh` -- content hash utility. Source it to get `compute_content_hash()`. API: `compute_content_hash <string>` returns `sha256:{64-hex}`. Returns empty and exit 1 if input is empty.
- `scripts/knowledge/rebuild-index.sh` -- called at end of ingest. Scans `knowledge/*/*.md` and `knowledge/*/*/*.md`, rebuilds KNOWLEDGE-INDEX.md and knowledge.db.
- `specs/016-autonomous-hardening/spec.md` -- real-world test input. Has 3 user stories (each with numbered Given/When/Then acceptance scenarios under `**Acceptance Scenarios**:`), `## Success Criteria` (6 SC items -- not a chunk type), `## Non-Goals` (3 items), `## Constraints` (4 items). No `## Functional Requirements` section.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`.
- Use `while IFS= read -r line` with heredoc EOF for line-by-line processing within functions (safe in Bash 3.2).
- The `create_chunk` helper must handle both with and without `--relates-to` argument -- use separate `bash` invocations (not conditional flag building with arrays, which needs `declare -a` append syntax).
- Content hash will be wired in T03 -- for this task, the `create_chunk` helper should call `compute_content_hash` but the actual hash is not verified until T03.
- The AC detection pattern must match both `N. **Given**` and `N. Given` formats (some specs use bold, some don't).
- FR IDs use the source FR number (FR-001 becomes SPEC-FR-001) rather than a sequential counter, for human predictability.

## Expected Output

- `scripts/knowledge/ingest-spec.sh` modified: stub classifiers replaced with full implementations (~250-350 total lines)
- 7 verification scripts created under `scripts/verify/m011-p02-*.sh`
- Running against test specs produces correct CREATED: output with proper IDs and categories
