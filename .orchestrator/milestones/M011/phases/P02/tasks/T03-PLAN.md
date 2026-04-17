---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M011"
name: "Content hash + idempotency + end-to-end verification"
depends_on: [T02]
---

## Prerequisites

T02 is complete:
- `scripts/knowledge/ingest-spec.sh` has full classifier implementations for stories, requirements, constraints, non-goals, acceptance scenarios, and NFRs
- The `create_chunk` helper calls `create-entry.sh` for each classified chunk and emits `CREATED:` / `SKIPPED:` lines
- Content hash computation via `compute_content_hash()` is already called in `create_chunk` but the hash value is not yet passed to `create-entry.sh` (the `content_hash` field in frontmatter is empty)
- All T02 verification scripts pass

## Description

Wire content hash computation into the chunk creation flow so each entry has a non-empty `content_hash` field in its frontmatter. Verify first-ingest idempotency (running twice on the same unchanged spec produces no new `CREATED:` lines -- this is already guaranteed by `create-entry.sh`'s EXISTS check, but this task adds explicit verification). Create comprehensive end-to-end verification scripts including one that runs against the real `specs/016-autonomous-hardening/spec.md`.

The content hash is critical infrastructure for P03 (Idempotent Re-Ingest & Versioning), which will compare hashes to detect changed chunks. Without hashes populated in P02, P03 has nothing to compare against.

## Steps

### Step 1: Wire content hash into create-entry.sh calls

The `create-entry.sh` script already emits a `content_hash: ""` field in frontmatter (added in P01/T02). However, it does not accept a `--content-hash` argument. There are two approaches:

**Approach A (preferred)**: After `create-entry.sh` creates the file, update the `content_hash` field in place using `sed`. This avoids modifying `create-entry.sh`'s API surface.

**Approach B**: Add `--content-hash` to `create-entry.sh`. This is cleaner long-term but modifies a shared API.

Use Approach A. In the `create_chunk` helper function in `ingest-spec.sh`, after the `create-entry.sh` call succeeds (CREATED:), compute the hash and patch the file:

Modify the `create_chunk` function. After the line that checks `CREATED:*` in the case block, add hash patching logic. The updated `CREATED:*)` branch should look like:

```bash
    CREATED:*)
      CREATED_COUNT=$((CREATED_COUNT + 1))
      # Patch content_hash into the newly created file
      if [ -n "$content_hash" ]; then
        local root
        root="$(cd "$SCRIPT_DIR" && source lib/index-utils.sh && get_project_root)"
        local detail_file="$root/knowledge/$category/$chunk_id.md"
        if [ -f "$detail_file" ]; then
          # Use portable sed -i
          if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "s|^content_hash: .*|content_hash: \"$content_hash\"|" "$detail_file"
          else
            sed -i '' "s|^content_hash: .*|content_hash: \"$content_hash\"|" "$detail_file"
          fi
        fi
      fi
      echo "$output"
      ;;
```

However, this approach is fragile because it re-sources `index-utils.sh` inside the helper. A cleaner approach: resolve the project root once at the top of the script and store it. Add this near the top of `ingest-spec.sh` (after sourcing the hash library):

```bash
# --- Resolve project root once ---
source "$SCRIPT_DIR/lib/index-utils.sh"
INGEST_PROJECT_ROOT="$(get_project_root)"
```

Then in the `create_chunk` function, use `$INGEST_PROJECT_ROOT` directly:

```bash
    CREATED:*)
      CREATED_COUNT=$((CREATED_COUNT + 1))
      # Patch content_hash into the newly created file
      if [ -n "$content_hash" ]; then
        local detail_file="$INGEST_PROJECT_ROOT/knowledge/$category/$chunk_id.md"
        if [ -f "$detail_file" ]; then
          if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "s|^content_hash: .*|content_hash: \"$content_hash\"|" "$detail_file"
          else
            sed -i '' "s|^content_hash: .*|content_hash: \"$content_hash\"|" "$detail_file"
          fi
        fi
      fi
      echo "$output"
      ;;
```

### Step 2: Normalize chunk body before hashing

To ensure stable hashes across re-ingests, the body text should be normalized before hashing. Add a helper function:

```bash
# --- Normalize text for hashing ---
# Strips leading/trailing whitespace and normalizes line endings
normalize_for_hash() {
  local text="$1"
  # Strip leading and trailing blank lines, normalize trailing whitespace per line
  printf '%s' "$text" | sed 's/[[:space:]]*$//' | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}
```

Then in `create_chunk`, compute the hash on normalized body:

```bash
  # Compute content hash on normalized body
  local normalized_body=""
  normalized_body="$(normalize_for_hash "$body")"
  local content_hash=""
  content_hash="$(compute_content_hash "$normalized_body")" || true
```

### Step 3: Create the content hash verification script

**`scripts/verify/m011-p02-content-hash.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Constraints

- Must be fast.
SPEC

PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-hash 2>/dev/null || true

con_file="$TMP_ROOT/knowledge/spec/constraint/SPEC-CON-001.md"
if [ ! -f "$con_file" ]; then
  echo "FAIL: Constraint file not created"
  exit 1
fi

# Extract content_hash from frontmatter
hash_value="$(sed -n '/^---$/,/^---$/p' "$con_file" | grep "^content_hash:" | head -1 | sed 's/^content_hash:[[:space:]]*//' | sed 's/^"//;s/"$//')"

if [ -z "$hash_value" ]; then
  echo "FAIL: content_hash is empty in SPEC-CON-001.md"
  exit 1
fi

# Check format: sha256:{64-hex}
case "$hash_value" in
  sha256:*)
    hex_part="${hash_value#sha256:}"
    hex_len="${#hex_part}"
    if [ "$hex_len" -eq 64 ]; then
      echo "PASS: content_hash is sha256:{64-hex} format: $hash_value"
    else
      echo "FAIL: hex portion is $hex_len chars, expected 64"
      exit 1
    fi
    ;;
  *)
    echo "FAIL: content_hash does not start with sha256: -- got: $hash_value"
    exit 1
    ;;
esac
```

### Step 4: Create the idempotency verification script

**`scripts/verify/m011-p02-idempotent.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Idempotency Test

## User Scenarios & Testing

### User Story 1 - Test (Priority: P1)

Test story.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Test requirement.

## Constraints

- Test constraint.

## Non-Goals

- Test non-goal.
SPEC

# First ingest
output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-idempotent 2>&1)" || true

created_count1="$(echo "$output1" | grep -c "^CREATED:" || true)"
if [ "$created_count1" -lt 5 ]; then
  echo "FAIL: First ingest should create >= 5 chunks, got $created_count1"
  echo "Output: $output1"
  exit 1
fi

# Second ingest -- same spec, should produce no CREATED lines
output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-idempotent 2>&1)" || true

created_count2="$(echo "$output2" | grep -c "^CREATED:" || true)"
skipped_count2="$(echo "$output2" | grep -c "^SKIPPED:" || true)"

if [ "$created_count2" -eq 0 ]; then
  echo "PASS: Second ingest created 0 new chunks (idempotent). Skipped $skipped_count2."
else
  echo "FAIL: Second ingest created $created_count2 chunks (expected 0)"
  echo "Output: $output2"
  exit 1
fi
```

### Step 5: Create the rebuild-index verification script

**`scripts/verify/m011-p02-rebuild-index.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Functional Requirements

- **FR-001**: Requirement one.
- **FR-002**: Requirement two.

## Constraints

- Constraint one.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-rebuild 2>&1)" || true

# Check that rebuild was called (look for REBUILT: line)
if echo "$output" | grep -q "^REBUILT:"; then
  echo "PASS: rebuild-index.sh called at end of ingest"
else
  echo "FAIL: No REBUILT: line in output -- rebuild-index.sh may not have been called"
  echo "Output: $output"
  exit 1
fi

# Check KNOWLEDGE-INDEX.md exists and contains spec entries
index_file="$TMP_ROOT/.orchestrator/KNOWLEDGE-INDEX.md"
if [ -f "$index_file" ]; then
  spec_count="$(grep -c "SPEC-" "$index_file" || true)"
  if [ "$spec_count" -ge 3 ]; then
    echo "PASS: KNOWLEDGE-INDEX.md contains $spec_count SPEC- entries"
  else
    echo "FAIL: KNOWLEDGE-INDEX.md has only $spec_count SPEC- entries, expected >= 3"
    exit 1
  fi
else
  echo "FAIL: KNOWLEDGE-INDEX.md not found after ingest"
  exit 1
fi
```

### Step 6: Update the Bash 3.2 compatibility script

The `m011-p02-bash32-compat.sh` from T01 only checks `ingest-spec.sh`. Update it to also check any new verify scripts. However, since T01 already created this script checking `ingest-spec.sh`, and the verify scripts use standard bash, the existing check is sufficient. No modification needed.

### Step 7: Run all verification scripts

```
bash scripts/verify/m011-p02-content-hash.sh
bash scripts/verify/m011-p02-idempotent.sh
bash scripts/verify/m011-p02-rebuild-index.sh
bash scripts/verify/m011-p02-ingest-creates-chunks.sh
bash scripts/verify/m011-p02-classify-stories.sh
bash scripts/verify/m011-p02-classify-requirements.sh
bash scripts/verify/m011-p02-classify-constraints.sh
bash scripts/verify/m011-p02-classify-nongoals.sh
bash scripts/verify/m011-p02-classify-acceptance.sh
bash scripts/verify/m011-p02-source-unit.sh
bash scripts/verify/m011-p02-bash32-compat.sh
```

All must print `PASS:` and exit 0.

### Step 8 (optional but recommended): Manual end-to-end test against real spec

Run ingest against the real 016 spec to verify classification against real-world content:

```
bash scripts/knowledge/ingest-spec.sh \
  --spec-path specs/016-autonomous-hardening/spec.md \
  --slug 016-autonomous-hardening
```

Expected output for 016-autonomous-hardening spec:
- 3 stories: SPEC-US-001, SPEC-US-002, SPEC-US-003
- ~10 acceptance scenarios: SPEC-AC-001 through SPEC-AC-010 (4 + 3 + 3)
- 0 functional requirements (no `## Functional Requirements` section in 016)
- 4 constraints: SPEC-CON-001 through SPEC-CON-004
- 3 non-goals: SPEC-NG-001 through SPEC-NG-003
- 0 NFRs

Total: ~20 chunks. All acceptance scenarios should have `relates_to` edges to their parent stories.

**Important**: Running this against the real repo's knowledge tree will create actual files. Use `PROJECT_ROOT` override to a temp directory for testing, or run in the actual repo if you intend to keep the results.

## Must-Haves

- Each chunk has a non-empty `content_hash` field in frontmatter set to `sha256:{64-hex}` format
- Running ingest twice on the same unchanged spec produces no new `CREATED:` lines (first-ingest idempotency)
- `rebuild-index.sh` is called once at the end and the resulting KNOWLEDGE-INDEX.md contains all spec entries
- All verification scripts pass

## Verification

```
bash scripts/verify/m011-p02-content-hash.sh
bash scripts/verify/m011-p02-idempotent.sh
bash scripts/verify/m011-p02-rebuild-index.sh
bash scripts/verify/m011-p02-bash32-compat.sh
```

All must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `scripts/knowledge/ingest-spec.sh` (from T01 + T02)
  - Key API: `ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]`
  - Has `create_chunk()` helper that calls `create-entry.sh` and emits CREATED:/SKIPPED: output
  - Already sources `scripts/lib/hash.sh` and calls `compute_content_hash()` in `create_chunk`, but does not yet write the hash into the created files
  - Variables: `SCRIPT_DIR`, `SPEC_PATH`, `SLUG`, `SCOPE_TAGS`, `INGEST_PROJECT_ROOT` (may or may not exist -- add if not present), counters
  - Classifier functions: `classify_stories_section`, `classify_requirements_section`, `classify_constraints_section`, `classify_nongoals_section`, `classify_nfr_section` -- all fully implemented
  - Helper functions: `_emit_story`, `_parse_acceptance_scenarios`, `_emit_requirement`, `_emit_constraint`, `_emit_nongoal`, `_emit_nfr`
- `scripts/verify/m011-p02-bash32-compat.sh` (from T01) -- checks bash -n on ingest-spec.sh
- `scripts/verify/m011-p02-classify-*.sh` (from T02) -- classification tests, all passing

### From Disk (Pre-existing)
- `scripts/knowledge/create-entry.sh` -- creates entries with `content_hash: ""` in frontmatter. The empty string needs to be patched after creation.
- `scripts/lib/hash.sh` -- `compute_content_hash(<string>)` returns `sha256:{64-hex}`. Uses `shasum -a 256`.
- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()` which resolves the repo root. Respects `PROJECT_ROOT` env var.
- `scripts/knowledge/rebuild-index.sh` -- regenerates KNOWLEDGE-INDEX.md and knowledge.db. Called once at end of ingest. Reads `content_hash` from frontmatter of each detail file and inserts it into the knowledge.db entries table.
- `specs/016-autonomous-hardening/spec.md` -- real-world test spec for optional manual validation.

## Constraints

- Bash 3.2 compatible. The `sed -i` portability pattern (check for GNU vs BSD sed) must be used for in-place edits.
- The content hash must be computed on normalized body text (leading/trailing whitespace stripped, trailing whitespace per line stripped) so that incidental formatting changes don't alter the hash.
- The hash patching must happen atomically after `create-entry.sh` succeeds -- if `create-entry.sh` returns EXISTS, no patching occurs (the existing file already has its hash from the first ingest).
- Do not modify `create-entry.sh` itself -- the hash patching is ingest-specific behavior, not a general knowledge infrastructure concern. P03 may add `--content-hash` to `create-entry.sh` if needed for the re-ingest flow.

## Expected Output

- `scripts/knowledge/ingest-spec.sh` modified: content hash wiring added, normalize_for_hash helper added, INGEST_PROJECT_ROOT resolved at top
- 3 new verification scripts: `m011-p02-content-hash.sh`, `m011-p02-idempotent.sh`, `m011-p02-rebuild-index.sh`
- All 11 verification scripts pass (3 new + 8 from T01/T02)
