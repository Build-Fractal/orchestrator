# Provider Shell Convention

> Reference document for the speckit-orchestrator provider interface.
> Self-contained — read this document to understand how to write a compliant execution provider without cross-referencing the spec or data model.

## Overview

The orchestrator delegates task execution to **providers** — bash scripts that accept standardized arguments, read orchestrator environment variables, perform work, and write a structured result file. Per AD-6, the provider abstraction is a **shell convention**, not a protocol. There is no provider registry, no interface definition, and no runtime type checking. A provider is any bash script that follows the conventions documented here.

Providers are consumed by:
- The dispatch system (`scripts/dispatch/`) which invokes providers for each task
- The hook system (`scripts/lib/hooks.sh`) which captures provider output for gate integration
- The diagnostics system (`scripts/diagnostics/check-providers.sh`) which validates conformance
- Provider authors writing new execution providers

---

## Required Arguments

Every provider **must** accept these CLI arguments:

| Argument | Required | Description |
|----------|----------|-------------|
| `--task` | yes | Task ID (e.g., `T01`, `T02`) |
| `--phase` | yes | Phase ID (e.g., `P01`, `P02`) |
| `--output` | yes | Absolute path where the provider writes its result file |
| `--milestone` | no | Milestone ID (e.g., `M005`). Defaults to `$ORCH_RUN_MILESTONE` if not provided |

Arguments are passed as `--key value` pairs (space-separated, not `=`). Providers must reject unknown arguments with a non-zero exit code.

### Argument Parsing Pattern

```bash
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

[ -z "$TASK" ] && { echo "error: --task required" >&2; exit 1; }
[ -z "$PHASE" ] && { echo "error: --phase required" >&2; exit 1; }
[ -z "$OUTPUT" ] && { echo "error: --output required" >&2; exit 1; }
```

---

## Environment Variables

The orchestrator sets these environment variables before invoking a provider. Providers may read them but must not modify them.

| Variable | Set By | Description |
|----------|--------|-------------|
| `ORCH_RUN_ID` | `run-context.sh` | Unique session ID for the current run (e.g., `run-2026-04-12T00:00:00Z-abc123`) |
| `ORCH_STARTED_AT` | `run-context.sh` | Frozen ISO-8601 timestamp of when the run started |
| `PROJECT_ROOT` | caller | Absolute path to the project root directory |
| `ORCH_FORCE` | caller | Set to `"1"` to bypass safety rails (e.g., skip lock checks) |
| `ORCH_DRY_RUN` | caller | Set to `"1"` to skip real execution (provider should produce a result file but not perform side effects) |
| `ORCH_RUN_MILESTONE` | `run-context.sh` | Current milestone ID (e.g., `M005`) |
| `ORCH_RUN_PHASE` | `run-context.sh` | Current phase ID (e.g., `P05`) |

Providers should use `orch_now` from `run-context.sh` to get timestamps (returns frozen `ORCH_STARTED_AT` for determinism within a run) and `orch_is_forced` to check the force flag.

---

## Output File Format

Providers **must** write a result file to the path specified by `--output`. The file uses YAML frontmatter followed by a markdown body:

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
content_hash: "sha256:abc123def456..."
---

## Result

Provider execution summary and any output artifacts.
```

### Required Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task` | string | yes | The task ID from `--task` |
| `phase` | string | yes | The phase ID from `--phase` |
| `milestone` | string | no | The milestone ID from `--milestone` or `$ORCH_RUN_MILESTONE` |
| `run_id` | string | yes | The run ID from `$ORCH_RUN_ID` |
| `started_at` | ISO-8601 | yes | When the provider began execution |
| `status` | string | yes | `"ok"` on success, `"error"` on failure |

### Optional Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `completed_at` | ISO-8601 | When the provider finished execution |
| `cost` | number | Execution cost in USD (e.g., API call cost) |
| `cost_source` | string | How the cost was determined (see Cost Reporting below) |
| `content_hash` | string | Hash of the output content (see Content Hash Reporting below) |

### Body

The markdown body after the frontmatter delimiter (`---`) contains a human-readable summary of what the provider did. This is freeform but should include enough context for debugging and auditing.

---

## Exit Codes

Providers use standard exit codes to signal success or failure:

| Code | Meaning | Result File | RESULT Line |
|------|---------|-------------|-------------|
| 0 | Success | Written completely, `status: "ok"` in frontmatter | `RESULT:ok` emitted via `emit_result` |
| 1 | Error | May be partial or absent, `status: "error"` if written | `RESULT:error` emitted via `emit_result` |

A provider **must** call `emit_result` exactly once before exiting. The exit code and the `emit_result` status must be consistent: exit 0 with `emit_result ok`, exit 1 with `emit_result error`.

---

## Verdict Integration

Providers may emit VERDICT lines to stdout for gate integration. Verdicts indicate whether a quality gate passed, failed, or needs attention.

### Emitting Verdicts

Use `emit_verdict` from `scripts/lib/verdicts.sh`:

```bash
. "$LIB_DIR/verdicts.sh"

# After running a quality check:
emit_verdict PASS "all tests passed"
emit_verdict BLOCK "3 critical failures found"
emit_verdict WARN "2 non-critical issues"
emit_verdict NEEDS_REVIEW "ambiguous result requires human judgment"
```

### Verdict Constants

| Verdict | Meaning | Hook Behavior |
|---------|---------|---------------|
| `PASS` | Gate passed | `HOOK_COMPLETE` with `verdict: PASS` |
| `BLOCK` | Gate failed, execution must stop | Hook failure (non-zero exit) |
| `WARN` | Non-critical issue, execution continues | `HOOK_WARNING` event emitted |
| `NEEDS_REVIEW` | Ambiguous result, human should review | `HOOK_COMPLETE` with `verdict: NEEDS_REVIEW` |

### Hook Integration

When a provider is invoked through the hook system (`scripts/lib/hooks.sh`), VERDICT lines in stdout are captured automatically. The hook system:

1. Captures all `VERDICT:` prefixed lines from provider stdout
2. Maps `BLOCK` verdicts to hook failure (non-zero exit)
3. Maps `WARN` verdicts to `HOOK_WARNING` events
4. Maps `PASS` and `NEEDS_REVIEW` to `HOOK_COMPLETE` with verdict metadata

When a provider is invoked directly (not through hooks), the caller is responsible for parsing VERDICT lines from stdout.

---

## Cost Reporting

Providers report execution cost via the `cost` and `cost_source` fields in the result file frontmatter. The `cost_source` field uses a closed enum defined in AD-2:

| Value | Meaning | When to Use |
|-------|---------|-------------|
| `estimated` | Cost computed from a token count heuristic | Provider calculates cost from input/output token counts using known pricing |
| `reported` | Cost taken directly from the provider API response | The upstream API returns cost information in its response |
| `unknown` | Provider did not or could not report cost | No cost information is available |

### Guidelines

- If a provider does not interact with a paid API, omit the `cost` field and set `cost_source: "unknown"`.
- If a provider receives cost data from an API, use `cost_source: "reported"` and set `cost` to the reported value.
- If a provider estimates cost from token counts, use `cost_source: "estimated"` and document the estimation method in the result body.
- The `cost` field is a number in USD. Use `0` for free operations, not `null`.
- Legacy entries without `cost_source` are classified by the aggregation layer based on the presence or absence of the `cost` field.

---

## Content Hash Reporting

Providers may optionally compute a content hash of their output to enable stagnation detection. When the orchestrator sees the same content hash across consecutive dispatches for the same task, it records the result as `outcome: unchanged`, signaling that the provider is not making progress.

### Computing Content Hashes

Use `compute_content_hash` from `scripts/lib/hash.sh`:

```bash
. "$LIB_DIR/hash.sh"

# Hash a string (e.g., the result body)
result_body="Provider completed successfully."
hash="$(compute_content_hash "$result_body")"
# Returns: sha256:a1b2c3d4e5f6...
```

### Hash Format

Content hashes use the format `sha256:{hex}` — the literal prefix `sha256:` followed by the hex-encoded SHA-256 digest. This format is consistent across all orchestrator components (knowledge entries, telemetry, provider results).

### Stagnation Detection

The orchestrator compares the `content_hash` in the current result file against the previous dispatch's `content_hash` for the same task. If they match, the result is recorded with `outcome: unchanged` via `record-result.sh`. This enables automated detection of stuck tasks that produce identical output across retries.

---

## Required Library Sourcing

Providers must source orchestrator libraries to access shared functions. Libraries use a double-sourcing guard pattern — sourcing the same library twice is safe and has no side effects.

### Required Libraries

```bash
. "$LIB_DIR/errors.sh"       # emit_result (required — must be called exactly once)
. "$LIB_DIR/events.sh"       # emit_event (required — at least one event per provider)
. "$LIB_DIR/run-context.sh"  # orch_now, orch_is_forced (required — timestamp and flag access)
```

### Optional Libraries

```bash
. "$LIB_DIR/verdicts.sh"     # emit_verdict (for providers that participate in quality gates)
. "$LIB_DIR/hash.sh"         # compute_content_hash (for stagnation detection)
```

### Library Path Resolution

Providers should resolve `LIB_DIR` relative to their own location:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
```

This ensures providers work regardless of the caller's working directory.

---

## Minimal Compliant Provider

The following is a complete, minimal provider that satisfies all required conventions:

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

---

## Conformance Checklist

Use this checklist when authoring or reviewing a provider script:

- [ ] Script has `#!/usr/bin/env bash` shebang
- [ ] Script has `set -eu` (or `set -euo pipefail`)
- [ ] Script accepts `--task`, `--phase`, `--output` arguments
- [ ] Script rejects unknown arguments with non-zero exit
- [ ] Script sources `errors.sh`, `events.sh`, `run-context.sh`
- [ ] Script emits at least one `emit_event` call
- [ ] Script emits exactly one `emit_result` call at completion
- [ ] Script writes a result file to the `--output` path
- [ ] Result file includes YAML frontmatter with `task`, `phase`, `status`
- [ ] Result file includes `run_id` from `$ORCH_RUN_ID`
- [ ] Exit code is consistent with `emit_result` status (0 = ok, 1 = error)
- [ ] Script does not modify files outside `--output` and `$PROJECT_ROOT`
- [ ] Script is Bash 3.2 compatible (no associative arrays, no `declare -A`)
- [ ] Script respects `$ORCH_DRY_RUN` if set (skips real side effects)

---

## Cross-References

- **State Machine**: `references/state-machine.md` — lifecycle states that providers operate within
- **Verification Ladder**: `references/verification-ladder.md` — verification tiers that consume provider results
- **File Formats**: `references/file-formats.md` — YAML frontmatter and JSONL schemas for telemetry entries
- **Tier Definitions**: `references/tier-definitions.md` — scope tiers that determine provider invocation patterns
- **AD-6**: Provider abstraction is a shell convention, not a protocol
- **AD-2**: Cost source enum (estimated/reported/unknown)
- **AD-1**: Content hash format (`sha256:{hex}`)
