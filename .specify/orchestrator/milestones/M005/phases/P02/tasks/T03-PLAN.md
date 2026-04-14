---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M005"
name: "Document telemetry entry schema in references/file-formats.md"
depends_on: ["T01"]
---

## Description

Update `references/file-formats.md` to add a Telemetry Entry section
documenting the `record-telemetry.sh` JSONL format, including the new
`cost_source` enum and the null-vs-zero cost distinction.

Currently, `references/file-formats.md` documents the dispatch result
entry format (via `record-result.sh`) under "Execution Log" but does
not document the telemetry entry format (via `record-telemetry.sh`).
Both entry types are appended to the same `execution-log.jsonl` file and
are distinguished by their `type` field (`"telemetry"` vs no type field
for dispatch results).

This task adds a "Telemetry Entry Format" subsection after the existing
"Verification Entry" subsection (around line 538), documenting:

1. The entry structure (all fields from record-telemetry.sh)
2. The `cost_source` enum with semantic definitions (AD-2)
3. The null-vs-zero distinction for `cost_estimated`
4. An example JSONL entry

## Steps

### Step 1 -- Add Telemetry Entry Format subsection

In `references/file-formats.md`, after the "Verification Entry" subsection
(which ends around line 538 with `---`), insert a new subsection before
the `---` separator:

```markdown
### Telemetry Entry Format (via `record-telemetry.sh`)

Appended to the same execution log as dispatch results. Distinguished by
`"type": "telemetry"`.

```json
{
  "timestamp": "2026-03-19T10:15:00Z",
  "type": "telemetry",
  "unitId": "M001/P01/T01",
  "model_used": "claude-sonnet-4-20250514",
  "tokens_input": 5000,
  "tokens_output": 1200,
  "tokens_cache_read": 3000,
  "cost_estimated": 0.12,
  "cost_source": "estimated",
  "cache_hit_rate": 0.6,
  "payload_bytes": 4096
}
```

Use `scripts/telemetry/record-telemetry.sh` to append entries.

#### Required Fields

`timestamp` (auto-generated), `type` (always `"telemetry"`), `unitId`

#### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `model_used` | string | Model identifier used for the dispatch |
| `tokens_input` | number | Input token count |
| `tokens_output` | number | Output token count |
| `tokens_cache_read` | number | Cache-read token count |
| `cost_estimated` | number | Cost in dollars. `null`/absent = unknown, `0` = actually free |
| `cost_source` | string | Cost provenance: `estimated`, `reported`, or `unknown` |
| `cache_hit_rate` | number | Cache hit rate (0.0-1.0) |
| `payload_bytes` | number | Payload size in bytes |

#### Cost Source Enum (AD-2)

| Value | Meaning |
|-------|---------|
| `estimated` | Cost computed from chars/4 heuristic |
| `reported` | Cost returned by provider API response |
| `unknown` | No cost data available |

**Null vs Zero Distinction**: A missing `cost_estimated` field means the
cost is unknown. A `cost_estimated` of `0` means the operation was
actually free (zero cost). These are semantically different: `null` =
"we don't know" vs `0` = "we know it was free." The `cost_source` field
provides additional provenance for downstream consumers (e.g., Conversus
gate cost decisions).
```

### Step 2 -- Verify the documentation is findable

Confirm the new section is reachable:

```bash
grep -q 'cost_source' references/file-formats.md && echo "OK: cost_source documented"
grep -q 'Telemetry Entry' references/file-formats.md && echo "OK: section heading present"
grep -q 'estimated.*reported.*unknown\|estimated\|reported\|unknown' references/file-formats.md && echo "OK: enum values present"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "references/file-formats.md documents the telemetry entry
  schema including cost_source enum and the null-vs-zero distinction".
- **Artifacts**: `references/file-formats.md` (modify, contains
  "cost_source").

## Verification

Run the verification script:

```bash
bash scripts/verify/p02-schema-docs.sh
```

Should print PASS.

### Files Touched By This Task

- `references/file-formats.md` (modify)

## Inputs

### From Previous Tasks

- T01: field names must be finalized (`cost_source`, enum values
  `estimated|reported|unknown`). The record-telemetry.sh changes in T01
  define the canonical field names that this documentation must match.

### From Disk (Pre-existing)

- `references/file-formats.md` -- the existing file formats reference
  document. The relevant section is "Execution Log" starting at line 479.
  Current subsections:
  - "Entry Format (via record-result.sh)" -- lines 485-502
  - "Required Fields" -- line 506-508
  - "Optional Fields" -- line 510-512
  - "Outcome Values" -- line 514-516
  - "Verification Entry" -- lines 518-538
  
  The new "Telemetry Entry Format" subsection should be inserted after
  the "Verification Entry" subsection, before the `---` separator that
  begins the "Decisions Register" section at line 542.

- `scripts/telemetry/record-telemetry.sh` (after T01 modifications) --
  the canonical source of field names. The documentation must match
  the script's actual field output exactly.

## Expected Output

After completing this task:

1. `references/file-formats.md` contains a "Telemetry Entry Format"
   subsection under the "Execution Log" section.
2. The subsection documents all fields from record-telemetry.sh:
   `timestamp`, `type`, `unitId`, `model_used`, `tokens_input`,
   `tokens_output`, `tokens_cache_read`, `cost_estimated`,
   `cost_source`, `cache_hit_rate`, `payload_bytes`.
3. The `cost_source` enum is documented with all three values and
   their semantic meanings.
4. The null-vs-zero distinction is explicitly documented.
5. A JSON example entry is included.
6. `bash scripts/verify/p02-schema-docs.sh` prints PASS.
7. `git status` shows 1 modified file. Nothing else touched.
