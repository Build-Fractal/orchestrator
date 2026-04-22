---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M013"
name: "knowledge/spec/defect/ schema + scripts/integrations/uat-ingest.sh"
depends_on: ["T04"]
---

## Prerequisites

- T04 complete: `scripts/knowledge/rebuild-index.sh` emits the `## Spec Chunks` section in repo-root `KNOWLEDGE-INDEX.md`. `uat-ingest.sh` parses this section to resolve chunk IDs.
- Existing state: `knowledge/spec/story/`, `knowledge/spec/acceptance/`, etc. exist with `SPEC-*.md` files carrying `id:` frontmatter. `knowledge/spec/defect/` does NOT yet exist.
- T03 (UAT template) is independent — this task does NOT parse issues live from GitHub. Ingestion inputs are fixture files on disk matching the post-template Issue shape. Live `gh` API integration is P03.

## Description

Ship two things:

1. **`knowledge/spec/defect/README.md`** — the schema contract for `SPEC-DEFECT-NNN.md` files. Defines required frontmatter fields, the `status` enum, the graph-edge shape, and forward-compatibility with M020 review-state extensions.

2. **`scripts/integrations/uat-ingest.sh`** — a script that reads UAT-bug fixture files from a `--source <dir>` and writes one `knowledge/spec/defect/SPEC-DEFECT-NNN.md` per input. Valid chunk IDs produce `status: open`. Unknown chunk IDs produce `status: chunk-lookup-failed` (never silently dropped — FR-10 and D014 ruling). Re-running with the same fixtures is idempotent via `github_issue_number` match → skip.

Fixture input shape (JSON; one file per UAT bug; field names mirror GitHub Issue form output):

```json
{
  "issue_number": 42,
  "title": "[UAT] Feeding window alert fires at wrong time",
  "spec_chunk_id": "SPEC-US-001",
  "body": "…markdown body of the Issue…",
  "created_at": "2026-04-25T14:22:10Z"
}
```

Output file shape (`knowledge/spec/defect/SPEC-DEFECT-042.md`):

```
---
id: SPEC-DEFECT-042
scope_tags: "[project]"
category: spec/defect
status: open                     # enum: open | chunk-lookup-failed | triaged | closed
chunk: SPEC-US-001               # empty string if chunk-lookup-failed
phase: ""                        # filled later by triage; empty on ingest
tests: []                        # filled later by triage; empty on ingest
github_issue_number: 42
created_at: 2026-04-25T14:22:10Z
ingested_at: 2026-04-25T14:30:00Z
---

# SPEC-DEFECT-042: [UAT] Feeding window alert fires at wrong time

<!-- Original GitHub Issue body -->

…markdown body of the Issue…
```

The `NNN` serial is `issue_number` from the fixture, zero-padded to three digits (so #42 → `SPEC-DEFECT-042`, #1234 → `SPEC-DEFECT-1234`). This ties the knowledge entry deterministically to the Issue number for idempotency without requiring a separate map.

## Steps

### Step 1: Create `knowledge/spec/defect/` directory + `README.md`

```markdown
# knowledge/spec/defect/ — UAT Defect Knowledge Entries

This directory holds `SPEC-DEFECT-NNN.md` files — structured records of UAT-filed defects linked back to the spec chunk whose acceptance criterion failed. Entries are produced by `scripts/integrations/uat-ingest.sh` (M013/P01) from UAT-bug Issue fixtures or (later, M013/P03) live GitHub Issues.

## Schema Contract

Every `SPEC-DEFECT-NNN.md` file MUST carry the following YAML frontmatter fields:

| Field | Type | Required | Semantics |
|-------|------|----------|-----------|
| `id` | string | yes | `SPEC-DEFECT-NNN` — pinned to the GitHub Issue number, zero-padded to 3 digits minimum. |
| `scope_tags` | string | yes | Standard orchestrator scope-tag list, e.g. `"[project]"` or `"[project], [milestone:M013]"`. |
| `category` | string | yes | Always the literal `spec/defect`. |
| `status` | enum | yes | One of: `open` (freshly ingested, valid chunk), `chunk-lookup-failed` (ingested but chunk ID did not match any `SPEC-*` in `KNOWLEDGE-INDEX.md`), `triaged` (human has assigned a triage bucket), `closed` (defect resolved). |
| `chunk` | string | yes | The `SPEC-*` chunk ID the defect is linked to. Empty string `""` when `status: chunk-lookup-failed`. |
| `phase` | string | yes | The orchestrator `M###-P##` id where the failing acceptance criterion lives. Filled during triage; empty on ingest. |
| `tests` | YAML list | yes | List of test file paths (or identifiers) that covered the failing acceptance criterion. Filled during triage; empty `[]` on ingest. |
| `github_issue_number` | integer \| null | yes | The originating GitHub Issue number. `null` if the defect is hand-authored. |
| `created_at` | ISO-8601 string | yes | When the original Issue was opened. |
| `ingested_at` | ISO-8601 string | yes | When this knowledge entry was written. |

## `status` Enum Transitions

```
            ┌─────────────────────┐
            │  chunk-lookup-failed│ (terminal unless chunk is manually resolved)
            └─────────────────────┘
                     │
                     ▼ (manual reconciliation)
  ingest ──► open ──► triaged ──► closed
```

- `open` → `triaged`: a maintainer assigns the defect to an orchestrator triage bucket (execution-error / spec-gap / spec-error) and records it in the body.
- `triaged` → `closed`: the bucket action completes (re-dispatch, clarification phase merged, spec chunk superseded).
- `chunk-lookup-failed` → `open`: a maintainer manually supplies the correct chunk ID in the `chunk:` field.

## M020 Forward-Compatibility

M013 deliberately ships the schema above without review-state lifecycle, query-surface affordances, or clustering metadata — all of which are M020 territory per `.orchestrator/DECISIONS.md` D013. M020 MAY add new optional frontmatter fields (e.g. `review_state:`, `cluster_id:`, `similarity_hash:`) in a forward-compatible additive manner. M013-era entries will continue to validate against M020's extended schema.

## Relationship to `KNOWLEDGE-INDEX.md`

Entries are scanned and indexed by `scripts/knowledge/rebuild-index.sh` the same way other knowledge entries are. They appear in the existing pipe-table section with `category: spec/defect`. They do NOT appear in the `## Spec Chunks` section — that section is scoped to `SPEC-US-*`, `SPEC-AC-*`, `SPEC-NG-*`, `SPEC-CON-*` (the canonical spec-chunk categories).

## Ingestion

See `scripts/integrations/uat-ingest.sh`. Fixture input format and CLI are documented in `references/github-integration.md` (T06).
```

### Step 2: Create `scripts/integrations/uat-ingest.sh`

```bash
#!/usr/bin/env bash
# scripts/integrations/uat-ingest.sh — Ingest UAT-bug fixture files into
# knowledge/spec/defect/SPEC-DEFECT-NNN.md entries.
#
# Usage:
#   uat-ingest.sh --source <dir> [--root <project-root>] [--dry-run]
#
# Inputs: one JSON file per UAT bug under <source>, each carrying:
#   issue_number, title, spec_chunk_id, body, created_at
#
# Output (stdout):
#   INGEST: SPEC-DEFECT-NNN status=<open|chunk-lookup-failed> issue=<N>
#   SKIP: SPEC-DEFECT-NNN issue=<N> (already ingested)
#   SUMMARY: created=<N> skipped=<N> errors=<N>
#
# Exit 0 on success (including chunk-lookup-failed entries — those are
# created, not silently dropped — FR-10). Exit 1 on malformed fixtures
# or write errors. Exit 2 on invalid CLI args.
#
# Bash 3.2 compatible; no jq hard dep; no gh subprocess calls.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "uat-ingest.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE_DIR" ]; then
  echo "uat-ingest.sh: --source <dir> is required" >&2
  exit 2
fi
if [ ! -d "$SOURCE_DIR" ]; then
  echo "uat-ingest.sh: source directory does not exist: $SOURCE_DIR" >&2
  exit 1
fi

DEFECT_DIR="${PROJECT_ROOT}/knowledge/spec/defect"
INDEX="${PROJECT_ROOT}/KNOWLEDGE-INDEX.md"

# Build set of known chunk IDs from KNOWLEDGE-INDEX.md Spec Chunks section.
# Bash 3.2 — use a newline-delimited string, not an assoc array.
known_chunks=""
if [ -f "$INDEX" ]; then
  known_chunks=$(awk '
    /^## Spec Chunks/ { in_sec=1; next }
    /^## / && in_sec { exit }
    in_sec && /^SPEC-[A-Z]+-[0-9]+ \|/ {
      n = index($0, " |")
      if (n > 0) print substr($0, 1, n-1)
    }
  ' "$INDEX")
fi

chunk_known() {
  # $1 = candidate id
  local id="$1"
  printf '%s\n' "$known_chunks" | grep -qxF "$id"
}

# Minimal JSON field reader — handles flat single-level string/integer fields
# with double-quoted keys. Not a general JSON parser; acceptable for fixture
# files we author. Prefers python3 when available for robustness.
json_field_str() {
  # $1 = file path; $2 = field name; stdout = value (unquoted)
  local file="$1"; local field="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
v=d.get(sys.argv[2])
if v is None:
    sys.exit(0)
sys.stdout.write(str(v))
" "$file" "$field"
    return
  fi
  # Fallback: grep + sed
  grep -E "\"${field}\"[[:space:]]*:" "$file" | head -1 | \
    sed -E "s/.*\"${field}\"[[:space:]]*:[[:space:]]*//" | \
    sed -E 's/^"//' | sed -E 's/"[[:space:]]*,?[[:space:]]*$//' | \
    sed -E 's/,[[:space:]]*$//'
}

created=0
skipped=0
errors=0

mkdir -p "$DEFECT_DIR"

for f in "$SOURCE_DIR"/*.json; do
  [ -f "$f" ] || continue
  issue_number=$(json_field_str "$f" "issue_number")
  title=$(json_field_str "$f" "title")
  chunk=$(json_field_str "$f" "spec_chunk_id")
  body=$(json_field_str "$f" "body")
  created_at=$(json_field_str "$f" "created_at")

  if [ -z "$issue_number" ]; then
    echo "ERROR: $f missing issue_number" >&2
    errors=$((errors + 1))
    continue
  fi

  # Zero-pad issue_number to 3 digits for IDs 1-999; otherwise use as-is.
  if [ "$issue_number" -lt 1000 ] 2>/dev/null; then
    padded=$(printf '%03d' "$issue_number")
  else
    padded="$issue_number"
  fi
  defect_id="SPEC-DEFECT-${padded}"
  out="${DEFECT_DIR}/${defect_id}.md"

  # Idempotency: skip if already exists with matching issue_number.
  if [ -f "$out" ]; then
    existing=$(grep -E '^github_issue_number:' "$out" | head -1 | sed 's/^github_issue_number:[[:space:]]*//')
    if [ "$existing" = "$issue_number" ]; then
      echo "SKIP: ${defect_id} issue=${issue_number} (already ingested)"
      skipped=$((skipped + 1))
      continue
    fi
    # File exists with different issue — collision; error.
    echo "ERROR: ${out} exists with different issue_number: ${existing} vs ${issue_number}" >&2
    errors=$((errors + 1))
    continue
  fi

  # Resolve status by chunk lookup.
  if [ -n "$chunk" ] && chunk_known "$chunk"; then
    status="open"
    chunk_field="$chunk"
  else
    status="chunk-lookup-failed"
    chunk_field=""
  fi

  ingested_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: would write ${out} status=${status}"
    continue
  fi

  {
    printf -- '---\n'
    printf 'id: %s\n' "$defect_id"
    printf 'scope_tags: "[project]"\n'
    printf 'category: spec/defect\n'
    printf 'status: %s\n' "$status"
    printf 'chunk: "%s"\n' "$chunk_field"
    printf 'phase: ""\n'
    printf 'tests: []\n'
    printf 'github_issue_number: %s\n' "$issue_number"
    printf 'created_at: "%s"\n' "$created_at"
    printf 'ingested_at: "%s"\n' "$ingested_at"
    printf -- '---\n\n'
    printf '# %s: %s\n\n' "$defect_id" "$title"
    printf '<!-- Original GitHub Issue body -->\n\n'
    printf '%s\n' "$body"
  } > "$out"

  echo "INGEST: ${defect_id} status=${status} issue=${issue_number}"
  created=$((created + 1))
done

printf 'SUMMARY: created=%d skipped=%d errors=%d\n' "$created" "$skipped" "$errors"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3: Create fixtures

`tests/fixtures/m013-p01/uat-bug-issues/valid-chunk.json`:

```json
{
  "issue_number": 101,
  "title": "[UAT] Autonomous mode surfaces approval prompt",
  "spec_chunk_id": "SPEC-US-001",
  "body": "Running `orchestrator:auto` on a phase with git operations surfaces a Claude Code approval prompt.\n\nSteps: ...\nExpected: zero prompts.\nObserved: one prompt on git stage.",
  "created_at": "2026-04-25T14:22:10Z"
}
```

`tests/fixtures/m013-p01/uat-bug-issues/unknown-chunk.json`:

```json
{
  "issue_number": 102,
  "title": "[UAT] Invented chunk reference",
  "spec_chunk_id": "SPEC-NOEXIST-999",
  "body": "This fixture references a chunk that does not exist; the ingester should flag it rather than drop it.",
  "created_at": "2026-04-25T14:23:00Z"
}
```

### Step 4: Create `scripts/verify/m013-p01-defect-schema.sh`

Gate asserts:

1. `knowledge/spec/defect/` exists as a directory.
2. `knowledge/spec/defect/README.md` exists and documents required frontmatter fields (`id`, `status`, `chunk`, `phase`, `tests`, `github_issue_number`, `created_at`).
3. `status` enum documented in README includes all four values: `open`, `chunk-lookup-failed`, `triaged`, `closed`.
4. README mentions forward-compatibility with M020 (Knowledge-Layer Boundary reference).

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-defect-schema.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${REPO_ROOT}/knowledge/spec/defect"
README="${DIR}/README.md"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

[ -d "$DIR" ]; assert_ok $? "knowledge/spec/defect/ directory exists"
[ -f "$README" ]; assert_ok $? "README.md exists"

for field in id status chunk phase tests github_issue_number created_at ingested_at; do
  grep -q "\`${field}\`" "$README"
  assert_ok $? "README documents field: ${field}"
done

for val in open chunk-lookup-failed triaged closed; do
  grep -q "$val" "$README"; assert_ok $? "README documents status: ${val}"
done

grep -q "M020" "$README"; assert_ok $? "README references M020 forward-compatibility"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-defect-schema.sh"
  exit 0
fi
echo "FAIL: m013-p01-defect-schema.sh ($fail_count failures)"
exit 1
```

### Step 5: Create `scripts/verify/m013-p01-uat-ingest.sh`

Gate asserts:

1. Running `uat-ingest.sh --source <fixtures>` on a tempdir (with the fixture files copied in) produces two `SPEC-DEFECT-*.md` files.
2. The valid-chunk fixture → `status: open`, `chunk: SPEC-US-001`.
3. The unknown-chunk fixture → `status: chunk-lookup-failed`, `chunk: ""` (never silently dropped).
4. Both files carry `tests: []` and `phase: ""` on ingest.
5. Re-running is idempotent: second run reports `SUMMARY: created=0 skipped=2 errors=0`.
6. A malformed fixture (missing `issue_number`) is reported as `ERROR:` and counted in `errors=`; exit code 1.

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-uat-ingest.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INGEST="${REPO_ROOT}/scripts/integrations/uat-ingest.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/m013-p01/uat-bug-issues"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }
assert_eq() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected=$2 actual=$3)"; fail_count=$((fail_count + 1)); fi; }

[ -f "$INGEST" ]; assert_ok $? "uat-ingest.sh present"
[ -d "$FIXTURES" ]; assert_ok $? "fixtures directory present"

# Build a tempdir with the same structure as repo, pre-seed KNOWLEDGE-INDEX.md
# with a Spec Chunks section naming SPEC-US-001.
TMP="$(mktemp -d)"
mkdir -p "${TMP}/knowledge/spec/defect" "${TMP}/scripts/integrations" "${TMP}/tests/fixtures/m013-p01/uat-bug-issues"
cp "$INGEST" "${TMP}/scripts/integrations/"
cp "${FIXTURES}"/*.json "${TMP}/tests/fixtures/m013-p01/uat-bug-issues/"

cat > "${TMP}/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index

## Spec Chunks
SPEC-US-001 | Full Phase Runs To Completion Without Prompts |
EOF

# First run
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run1.out" 2>&1
rc=$?
assert_eq "first run exit 0" "0" "$rc"

# Two defect files created
count=$(ls "${TMP}/knowledge/spec/defect/"SPEC-DEFECT-*.md 2>/dev/null | wc -l | tr -d ' ')
assert_eq "two defect files written" "2" "$count"

# Valid-chunk: status=open, chunk=SPEC-US-001
valid_file="${TMP}/knowledge/spec/defect/SPEC-DEFECT-101.md"
[ -f "$valid_file" ]; assert_ok $? "SPEC-DEFECT-101.md written"
grep -q '^status: open' "$valid_file"; assert_ok $? "valid-chunk has status: open"
grep -q '^chunk: "SPEC-US-001"' "$valid_file"; assert_ok $? "valid-chunk has chunk: SPEC-US-001"

# Unknown-chunk: status=chunk-lookup-failed, chunk=""
unknown_file="${TMP}/knowledge/spec/defect/SPEC-DEFECT-102.md"
[ -f "$unknown_file" ]; assert_ok $? "SPEC-DEFECT-102.md written"
grep -q '^status: chunk-lookup-failed' "$unknown_file"; assert_ok $? "unknown-chunk flagged"
grep -q '^chunk: ""' "$unknown_file"; assert_ok $? "unknown-chunk has empty chunk field"

# Both files: phase empty, tests empty
grep -q '^phase: ""' "$valid_file"; assert_ok $? "valid-chunk phase is empty on ingest"
grep -q '^tests: \[\]' "$valid_file"; assert_ok $? "valid-chunk tests is empty list on ingest"

# Idempotency: second run
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run2.out" 2>&1
grep -q "SUMMARY: created=0 skipped=2 errors=0" "${TMP}/run2.out"
assert_ok $? "second run idempotent"

# Malformed fixture
echo '{"title": "no issue number"}' > "${TMP}/tests/fixtures/m013-p01/uat-bug-issues/bad.json"
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run3.out" 2>&1
rc=$?
assert_eq "malformed fixture exits 1" "1" "$rc"

rm -rf "$TMP"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-uat-ingest.sh"
  exit 0
fi
echo "FAIL: m013-p01-uat-ingest.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `knowledge/spec/defect/README.md` documents every required frontmatter field and the full `status` enum.
- `scripts/integrations/uat-ingest.sh` writes `SPEC-DEFECT-NNN.md` files from fixture JSON; unknown chunks are flagged, never silently dropped.
- Re-running ingestion is idempotent via `github_issue_number` match.
- Both verify gates (`m013-p01-defect-schema.sh`, `m013-p01-uat-ingest.sh`) pass.

## Verification

- `bash scripts/verify/m013-p01-defect-schema.sh`
- `bash scripts/verify/m013-p01-uat-ingest.sh`

## Inputs

### From Previous Tasks

- `scripts/knowledge/rebuild-index.sh` (from T04): emits the `## Spec Chunks` section in repo-root `KNOWLEDGE-INDEX.md`. The ingester parses that section to resolve `spec_chunk_id` lookups.
  - Key API: awk scan of `KNOWLEDGE-INDEX.md` between `^## Spec Chunks` and the next `^## ` heading. Each line matches `^SPEC-[A-Z]+-[0-9]+ \| <title> \| <phase_id>`.

### From Disk (Pre-existing)

- `knowledge/spec/story/SPEC-US-001.md` and siblings — chunk files whose `id:` frontmatter values appear in the Spec Chunks section.
- `scripts/util/json-field.sh` — optional helper; this task uses its own minimal reader (python3 preferred, grep fallback) to avoid tight coupling.

## Constraints

- **FR-10 never silently drops**: unknown chunk IDs produce a `chunk-lookup-failed` entry, not a silent skip. This is a D014 ruling — non-negotiable.
- **Bash 3.2 compatible** (Constitution IX).
- **No `gh` subprocess calls** — P01 is scaffold only. Live GitHub API reads are P03.
- **No jq hard dependency** — prefer `python3` for JSON; fall back to grep/sed; the script must run on a bare macOS install.
- **Idempotent** — re-running with the same fixtures produces `created=0 skipped=N` output and no duplicate files.
- **Single-script-file shape (AD-19)** for all `Check:` commands and verify gates.
- **Knowledge-Layer Boundary (D014)**: `SPEC-DEFECT-NNN` IDs are a NEW category the `spec/defect` subdir owns (not a widening of `SPEC-*` chunk IDs). The `chunk:` field references existing chunk IDs verbatim. No composite addressing.
- **Do not run `scripts/knowledge/rebuild-index.sh`** from inside `uat-ingest.sh` — the new defect entries will be indexed on the next rebuild. Separation of concerns (MEM004 pure lib extraction).

## Expected Output

- `knowledge/spec/defect/` directory created.
- `knowledge/spec/defect/README.md` created.
- `scripts/integrations/uat-ingest.sh` created.
- `tests/fixtures/m013-p01/uat-bug-issues/valid-chunk.json` + `unknown-chunk.json` created.
- `scripts/verify/m013-p01-defect-schema.sh` created.
- `scripts/verify/m013-p01-uat-ingest.sh` created.
- `bash scripts/verify/m013-p01-defect-schema.sh` → `PASS: m013-p01-defect-schema.sh`, exit 0.
- `bash scripts/verify/m013-p01-uat-ingest.sh` → `PASS: m013-p01-uat-ingest.sh`, exit 0.
