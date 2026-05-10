---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M005"
name: "Create provider-convention.md reference document"
depends_on: []
---

## Description

Create `references/provider-convention.md` — a reference document that
defines the shell convention for execution providers. Per AD-6, the provider
abstraction is a shell convention, not a protocol. Providers are bash
scripts that:

1. Accept documented arguments (`--task`, `--phase`, `--output`, `--milestone`)
2. Read documented environment variables (`ORCH_RUN_ID`, `ORCH_STARTED_AT`,
   `PROJECT_ROOT`, `ORCH_FORCE`, `ORCH_DRY_RUN`)
3. Write a structured result file to the `--output` path
4. Use standard exit codes (0 = success, 1 = error)
5. May emit VERDICT lines to stdout for gate integration
6. Report cost with `cost_source` field (from P02)
7. May report content hashes (from P01's hash.sh)
8. Emit structured events via events.sh
9. Emit a final RESULT line via errors.sh

This document is consumed by:
- Provider authors writing new execution providers
- `scripts/diagnostics/check-providers.sh` (T04) which validates providers
  against this convention
- Future Conversus integration that wraps providers with deliberation gates

### Document Structure

The reference follows the same style as existing documents in `references/`
(state-machine.md, verification-ladder.md, tier-definitions.md):
- YAML frontmatter with schema_version and type
- Top-level heading with document title
- Sections organized by concern
- Code examples showing compliant patterns
- Cross-references to related documents

## Steps

### Step 1 — Create `references/provider-convention.md`

Create the reference document covering all aspects of the provider shell
convention. The document should include these sections:

**Required Arguments** — Documents the CLI arguments every provider must
accept:

| Argument | Required | Description |
|----------|----------|-------------|
| `--task` | yes | Task ID (e.g., T01, T02) |
| `--phase` | yes | Phase ID (e.g., P01, P02) |
| `--output` | yes | Path where the provider writes its result file |
| `--milestone` | no | Milestone ID (e.g., M005). Defaults to `$ORCH_RUN_MILESTONE` |

**Environment Variables** — Documents env vars providers can read:

| Variable | Set By | Description |
|----------|--------|-------------|
| `ORCH_RUN_ID` | run-context.sh | Unique session ID |
| `ORCH_STARTED_AT` | run-context.sh | Frozen ISO-8601 timestamp |
| `PROJECT_ROOT` | caller | Absolute path to project root |
| `ORCH_FORCE` | caller | "1" to bypass safety rails |
| `ORCH_DRY_RUN` | caller | "1" to skip real execution |
| `ORCH_RUN_MILESTONE` | run-context.sh | Current milestone ID |
| `ORCH_RUN_PHASE` | run-context.sh | Current phase ID |

**Output File Format** — Documents the structure of the result file
written to `--output`:

```yaml
---
task: "T01"
phase: "P05"
milestone: "M005"
run_id: "run-2026-04-12T00:00:00Z-abc123"
started_at: "2026-04-12T00:00:00Z"
completed_at: "2026-04-12T00:05:00Z"
status: "ok"
cost: 0.042
cost_source: "reported"
content_hash: "sha256:abc123..."
---

## Result

Provider execution summary and any output artifacts.
```

**Exit Codes** — Documents exit code semantics:

| Code | Meaning |
|------|---------|
| 0 | Success — result file written, RESULT:ok emitted |
| 1 | Error — result file may be partial, RESULT:error emitted |

**Verdict Integration** — Documents how providers emit VERDICT lines:

Providers may emit VERDICT lines to stdout using `emit_verdict` from
`scripts/lib/verdicts.sh`. When a provider is invoked through the hook
system, hooks.sh captures these verdicts and maps them to hook outcomes.
When invoked directly, the caller is responsible for parsing VERDICT lines.

**Cost Reporting** — Documents the `cost_source` field values:

| Value | Meaning |
|-------|---------|
| `estimated` | Cost computed from token count heuristic |
| `reported` | Cost from provider API response |
| `unknown` | Provider did not report cost |

**Content Hash Reporting** — Documents optional content_hash field:

Providers may compute a content hash of their output using
`compute_content_hash` from `scripts/lib/hash.sh`. This hash enables
the stagnation detection from P01 — if the hash matches a prior dispatch,
the result is recorded as `outcome: unchanged`.

**Required Library Sourcing** — Documents which libraries providers must
source:

```bash
. scripts/lib/errors.sh    # emit_result (required)
. scripts/lib/events.sh    # emit_event (required)
. scripts/lib/run-context.sh  # orch_now, orch_is_forced (required)
. scripts/lib/verdicts.sh  # emit_verdict (optional, for gate verdicts)
. scripts/lib/hash.sh      # compute_content_hash (optional)
```

**Minimal Compliant Provider** — A skeleton example showing the minimum
viable provider:

```bash
#!/usr/bin/env bash
# scripts/providers/example-provider.sh — Minimal compliant provider.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source required libraries
. "$LIB_DIR/errors.sh"
. "$LIB_DIR/events.sh"
. "$LIB_DIR/run-context.sh"

# Parse arguments
TASK="" PHASE="" OUTPUT="" MILESTONE="${ORCH_RUN_MILESTONE:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --milestone) MILESTONE="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate required arguments
[ -z "$TASK" ] && { echo "error: --task required" >&2; exit 1; }
[ -z "$PHASE" ] && { echo "error: --phase required" >&2; exit 1; }
[ -z "$OUTPUT" ] && { echo "error: --output required" >&2; exit 1; }

emit_event DISPATCH_START task="$TASK" phase="$PHASE"

# --- Provider logic here ---

# Write result file
cat > "$OUTPUT" <<EOF
---
task: "$TASK"
phase: "$PHASE"
milestone: "$MILESTONE"
run_id: "$ORCH_RUN_ID"
started_at: "$(orch_now)"
status: "ok"
cost_source: "unknown"
---

## Result

Provider completed successfully.
EOF

emit_result ok "" "task $TASK completed"
```

**Conformance Checklist** — A checklist for provider authors:

- [ ] Script has `#!/usr/bin/env bash` shebang
- [ ] Script has `set -eu` (or `set -euo pipefail`)
- [ ] Script accepts `--task`, `--phase`, `--output` arguments
- [ ] Script sources `errors.sh`, `events.sh`, `run-context.sh`
- [ ] Script emits at least one `emit_event` call
- [ ] Script emits exactly one `emit_result` call at completion
- [ ] Script writes a result file to the `--output` path
- [ ] Result file includes YAML frontmatter with `task`, `phase`, `status`
- [ ] Script does not modify files outside `--output` and `$PROJECT_ROOT`
- [ ] Script is Bash 3.2 compatible

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "Provider convention reference document exists at
  `references/provider-convention.md` and declares required arguments,
  env vars, output path, exit codes, and verdict integration."
- **Artifacts**: `references/provider-convention.md` (create, min 80 lines,
  contains "Provider Shell Convention").

## Verification

Run the verification script:

```bash
bash scripts/verify/p05-provider-convention-doc.sh
```

Should print PASS. This script checks that the document exists, has at
least 80 lines, and contains required headings and keywords.

### Files Touched By This Task

- `references/provider-convention.md` (create)

## Inputs

### From Previous Tasks

None -- T03 is independent of T01/T02 and can execute in parallel with T01.

### From Disk (Pre-existing)

- `references/state-machine.md` — reference for the document style and
  structure used in the references/ directory. Key patterns: YAML
  frontmatter with schema_version, structured sections, code examples,
  cross-references.

- `references/verification-ladder.md` — another reference document style
  example. Shows how to document a protocol with tiers and escalation.

- `references/file-formats.md` — documents YAML frontmatter schemas and
  JSONL formats used across the orchestrator. The provider output file
  format should be documented here or cross-referenced.

- `scripts/lib/errors.sh` — defines `emit_result` that providers must
  call. The convention doc references this.

- `scripts/lib/events.sh` — defines `emit_event` that providers must
  call. The convention doc references this.

- `scripts/lib/run-context.sh` — defines env vars (`ORCH_RUN_ID`,
  `ORCH_STARTED_AT`, etc.) that providers read. The convention doc
  documents these.

- `scripts/lib/hash.sh` (from P01) — defines `compute_content_hash`
  that providers may optionally use.

- Cost source enum (from P02) — the three-value enum
  (estimated/reported/unknown) that providers report in their result file.

## Expected Output

After completing this task:

1. `references/provider-convention.md` exists with at least 80 lines.
2. Document covers required arguments (`--task`, `--phase`, `--output`),
   env vars (`ORCH_RUN_ID`, etc.), output file format, exit codes,
   verdict integration, cost reporting, content hash reporting, required
   library sourcing, minimal example, and conformance checklist.
3. `bash scripts/verify/p05-provider-convention-doc.sh` prints PASS.
4. `git status` shows 1 new file. Nothing else touched.
