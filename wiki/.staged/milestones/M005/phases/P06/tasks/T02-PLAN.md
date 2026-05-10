---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M005"
name: "check-hashes.sh + check-run-ids.sh"
depends_on: []
---

## Prerequisites

P01 delivered `scripts/lib/hash.sh` with `compute_content_hash` and `compute_file_body_hash`, and updated knowledge scripts to write `content_hash` in YAML frontmatter. Knowledge entries live under `.specify/orchestrator/knowledge/` or `.specify/knowledge/` as `.md` files with YAML frontmatter containing a `content_hash: sha256:{hex}` field.

P02 added `cost_source` to JSONL entries. Execution logs are JSONL files at `.specify/orchestrator/milestones/M*/execution-log.jsonl` and `.specify/orchestrator/execution-log.jsonl`.

## Description

Create two new diagnostic scripts:

1. **`scripts/diagnostics/check-hashes.sh`** — Scans knowledge entry files for valid `content_hash` fields in YAML frontmatter. A valid hash matches the pattern `sha256:[a-f0-9]{64}`. Reports entries with missing or malformed hashes. Emits `DOCTOR:HASHES status=<ok|warn> valid=N missing=N`.

2. **`scripts/diagnostics/check-run-ids.sh`** — Scans recent JSONL log entries for the `run_id` field. Pre-[M004](../../../../../milestones/M004/index.md) entries may lack this field (legacy). The check focuses on entries from the current or most recent milestone. Emits `DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N`.

## Steps

### Step 1: Create `scripts/diagnostics/check-hashes.sh`

Create the file at `scripts/diagnostics/check-hashes.sh`:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-hashes.sh — Knowledge entry content_hash validator.
#
# Scans knowledge entry .md files for valid content_hash fields in YAML frontmatter.
# Valid format: content_hash: "sha256:<64 hex chars>" or content_hash: sha256:<64 hex chars>
#
# Usage: check-hashes.sh [--root <project-root>]
#
# Output: DOCTOR:HASHES status=<ok|warn> valid=N missing=N
#
# Bash 3.2 compatible.
set -eu
```

**Arguments:**
- `--root <project-root>` — defaults to `PROJECT_ROOT` env var or two levels up from script

**Logic:**
1. Find knowledge entry files: look for `.md` files under `<root>/.specify/orchestrator/knowledge/` and `<root>/.specify/knowledge/`. These files should have YAML frontmatter (delimited by `---`).

2. For each `.md` file found:
   - Extract the YAML frontmatter (content between the first `---` and the second `---`)
   - Look for a line matching `content_hash:` in the frontmatter
   - If found, validate that the value matches `sha256:[a-f0-9]{64}` (with optional surrounding quotes)
   - If not found or malformed, count as "missing"

3. Count valid vs missing. If no knowledge entries exist, report `status=ok valid=0 missing=0` (vacuously true).

4. Output: `DOCTOR:HASHES status=<ok|warn> valid=N missing=N`

5. If `status=warn`, list each file with missing/malformed hash prefixed with `  MISSING: `.

6. Exit 0 on ok, exit 1 on warn.

Make executable: `chmod +x scripts/diagnostics/check-hashes.sh`

### Step 2: Create `scripts/diagnostics/check-run-ids.sh`

Create the file at `scripts/diagnostics/check-run-ids.sh`:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-run-ids.sh — JSONL run_id presence checker.
#
# Scans execution-log.jsonl entries for the run_id field.
# Pre-M004 entries may lack run_id (legacy); this check reports coverage.
#
# Usage: check-run-ids.sh [--root <project-root>] [--jsonl <file>]
#
# Output: DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N
#
# Bash 3.2 compatible.
set -eu
```

**Arguments:**
- `--root <project-root>` — defaults to `PROJECT_ROOT` env var or two levels up from script
- `--jsonl <file>` — specific JSONL file to check. If not provided, scans all `execution-log.jsonl` files under `.specify/orchestrator/milestones/`

**Logic:**
1. Collect JSONL files: if `--jsonl` provided, use that file. Otherwise find all `execution-log.jsonl` files under `<root>/.specify/orchestrator/milestones/`.

2. For each JSONL file, read each line (each line is a JSON object).

3. For each line, check if it contains the string `"run_id"` (simple string match — sufficient for JSONL where keys are always quoted). If present, count as `with_id`. If absent, count as `without_id`.

4. If no JSONL entries exist, report `status=ok with_id=0 without_id=0`.

5. Output: `DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N`

6. The status is `ok` if `without_id=0`, `warn` otherwise. Note: legacy entries without `run_id` are expected in older milestones, so this is advisory.

7. If `status=warn`, report the count and which JSONL files contributed entries without run_id.

8. Exit 0 on ok, exit 1 on warn.

Make executable: `chmod +x scripts/diagnostics/check-run-ids.sh`

### Step 3: Create verification scripts

Create `scripts/verify/p06-check-hashes.sh`:

```bash
#!/usr/bin/env bash
# Verify check-hashes.sh exists, is executable, contains DOCTOR:HASHES,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-hashes.sh"

[ -f "$script" ] || { echo "FAIL: check-hashes.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-hashes.sh not executable"; exit 1; }
grep -q 'DOCTOR:HASHES' "$script" || { echo "FAIL: missing DOCTOR:HASHES output"; exit 1; }

output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:HASHES' || { echo "FAIL: no DOCTOR:HASHES in output"; exit 1; }

echo "PASS: check-hashes.sh verified"
```

Create `scripts/verify/p06-check-run-ids.sh`:

```bash
#!/usr/bin/env bash
# Verify check-run-ids.sh exists, is executable, contains DOCTOR:RUNIDS,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-run-ids.sh"

[ -f "$script" ] || { echo "FAIL: check-run-ids.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-run-ids.sh not executable"; exit 1; }
grep -q 'DOCTOR:RUNIDS' "$script" || { echo "FAIL: missing DOCTOR:RUNIDS output"; exit 1; }

output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:RUNIDS' || { echo "FAIL: no DOCTOR:RUNIDS in output"; exit 1; }

echo "PASS: check-run-ids.sh verified"
```

Make both verification scripts executable.

## Must-Haves

- check-hashes.sh scans knowledge entries for valid `content_hash` fields and emits `DOCTOR:HASHES status=<ok|warn> valid=N missing=N`
- check-run-ids.sh scans recent JSONL entries for `run_id` field presence and emits `DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N`

### Artifacts

- scripts/diagnostics/check-hashes.sh (min 30 lines, contains "DOCTOR:HASHES")
- scripts/diagnostics/check-run-ids.sh (min 30 lines, contains "DOCTOR:RUNIDS")

## Verification

```
bash scripts/verify/p06-check-hashes.sh
bash scripts/verify/p06-check-run-ids.sh
```

Expected: both output `PASS: ...`

## Inputs

### From Previous Tasks
None — this is independent of T01.

### From Disk (Pre-existing)
- `scripts/lib/hash.sh` (from P01) — defines `compute_content_hash` function and the `sha256:{hex}` format convention that check-hashes.sh validates against
- `.specify/orchestrator/milestones/M*/execution-log.jsonl` — JSONL log files that check-run-ids.sh scans for `run_id` field
- `.specify/orchestrator/knowledge/` or `.specify/knowledge/` — knowledge entry `.md` files with YAML frontmatter containing `content_hash`
- Existing doctor checks — follow the `DOCTOR:*` structured output pattern

## Constraints

- Bash 3.2 compatible
- Follow the `DOCTOR:*` structured output protocol
- Exit 0 on ok, exit 1 on warn
- Advisory checks — report state, do not fix it
- Do not source `errors.sh` or `events.sh` — diagnostic scripts are read-only
- check-hashes.sh validates the `sha256:[a-f0-9]{64}` format from P01, not the actual hash correctness (hash recomputation is expensive and out of scope for a diagnostic)
- check-run-ids.sh uses simple string matching (`"run_id"`) — no jq dependency

## Expected Output

Two new files:
- `scripts/diagnostics/check-hashes.sh` — ~50-60 lines
- `scripts/diagnostics/check-run-ids.sh` — ~50-60 lines
- `scripts/verify/p06-check-hashes.sh` — ~20 lines
- `scripts/verify/p06-check-run-ids.sh` — ~20 lines

All executable. Both diagnostic scripts emit `DOCTOR:*` structured output.
