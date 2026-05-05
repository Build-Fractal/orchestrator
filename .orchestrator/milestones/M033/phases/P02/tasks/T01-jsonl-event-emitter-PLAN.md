---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M033"
name: "scripts/util/jsonl-event-emitter.sh + schema verifier (FR-22)"
depends_on: []
---

## Prerequisites

- `scripts/util/` exists — verified by `[ -d scripts/util ]`.
- `tools/verify/` exists.
- `scripts/util/jsonl-event-emitter.sh` does NOT yet exist — verified by `[ ! -f scripts/util/jsonl-event-emitter.sh ]`.
- M033/P01 closed: `scripts/lifecycle/start.sh` exists. (Not directly consumed by T01 but documents the prior phase's ship surface — T01 produces the emitter that P03/P04/P05 calling commands invoke.)
- Spec context: FR-22 enumerates 11 event types — `start_branch_detected`, `start_init_invoked`, `constitution_authored`, `ingest_codebase_completed`, `materials_intake_completed`, `ideation_completed`, `migrate_routed`, `customblock_drafted`, `wiki_init_invoked`, `github_init_invoked`, `friendly_tester_report_validated`. Schema version is `1.0`. Append target is `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`.

## Description

T01 ships `scripts/util/jsonl-event-emitter.sh`, the FR-22 observability record emitter library. The script provides a single primary entry point — `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>` — that appends one JSON-line record to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` (created if absent) with the documented schema. The 11 event types form a closed enum; unknown event types exit non-zero with the enum echoed. The schema version literal `1.0` is fixed at this milestone.

The library is a stdlib for FR-22 — every M033 calling command (FR-1 / FR-3 / FR-7 / FR-9 / FR-10 / FR-13 / FR-15 / FR-16 / FR-19) invokes it at load-bearing points to produce the audit trail. M027 / M019 cost-rollup consumers already read the JSONL surface (per Constitution VI State On Disk Is Truth).

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. The JSON formatting uses `printf` with explicit field order (no jq dependency at the emit path — jq is the optional fallback per MEM001's `json_field()` precedent). Append is atomic via single `>>` redirect of a single pre-formatted line.

**Append atomicity:** The script MUST format the entire JSON line in memory (a single `printf` invocation producing one line + newline), then append via `>> <log-path>`. POSIX guarantees atomic append for writes ≤ `PIPE_BUF` bytes (4096 on Linux, 512 on macOS). The emitter MUST refuse payloads that, after formatting, exceed 480 bytes per record (well under macOS PIPE_BUF), exiting non-zero with `payload too large for atomic append` to stderr. This is the load-bearing guarantee for State On Disk Is Truth — Ctrl+C mid-write cannot corrupt the JSONL surface.

## Steps

1. **Author `scripts/util/jsonl-event-emitter.sh`** (≥80 lines, executable, `chmod +x`, bash 3.2 compatible).

   1a. **Header.** Hashbang `#!/usr/bin/env bash`, set `-e -u -o pipefail`, brief comment block naming the script (FR-22), the spec reference (M033 / 036-project-onboarding-experience), the schema version (`1.0`), and the 11 documented event types.

   1b. **Closed enum block.** A fenced `# >>> event-types >>>` ... `# <<< event-types <<<` block (SSOT) listing all 11 event types, one per line, in the order documented in FR-22. The verifier greps this block.

   1c. **Subcommand dispatch.** Argument 1 is the subcommand. Implemented subcommands: `emit <event_type> <payload_json>`. Unknown subcommands exit 2 with usage. Reserved for future: `validate <log-path>` (out of T01 scope; document in comment as a follow-up demand-driven extension).

   1d. **Emit logic.**

   ```bash
   emit() {
     local event_type="$1"
     local payload_json="$2"
     # Validate event_type against closed enum
     case "$event_type" in
       start_branch_detected|start_init_invoked|constitution_authored|\
       ingest_codebase_completed|materials_intake_completed|ideation_completed|\
       migrate_routed|customblock_drafted|wiki_init_invoked|github_init_invoked|\
       friendly_tester_report_validated) ;;
       *) echo "unknown event_type: $event_type" >&2
          echo "valid: start_branch_detected start_init_invoked constitution_authored ingest_codebase_completed materials_intake_completed ideation_completed migrate_routed customblock_drafted wiki_init_invoked github_init_invoked friendly_tester_report_validated" >&2
          return 2 ;;
     esac
     # Validate payload_json is a JSON object (starts with `{`, ends with `}`)
     case "$payload_json" in
       \{*\}) ;;
       *) echo "payload_json must be a JSON object: $payload_json" >&2; return 2 ;;
     esac
     local timestamp
     timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     # Determine project_dir: env override PROJECT_DIR, else pwd
     local project_dir="${PROJECT_DIR:-$PWD}"
     local log_dir="$project_dir/.orchestrator"
     local log_path="$log_dir/execution-log.jsonl"
     mkdir -p "$log_dir"
     # Format the single JSON line
     local line
     line="$(printf '{"schema_version":"1.0","event_type":"%s","timestamp":"%s","payload":%s}' \
       "$event_type" "$timestamp" "$payload_json")"
     # Atomic-append size guard (max 480 bytes per record)
     local linelen=${#line}
     if [ "$linelen" -gt 480 ]; then
       echo "payload too large for atomic append: $linelen > 480 bytes" >&2
       return 2
     fi
     printf '%s\n' "$line" >> "$log_path"
     return 0
   }
   ```

   1e. **Top-level dispatcher.** Read `$1` as subcommand, shift, dispatch:

   ```bash
   case "${1:-}" in
     emit) shift; emit "$@" ;;
     -h|--help|help) echo "usage: jsonl-event-emitter.sh emit <event_type> <payload_json>"; exit 0 ;;
     *) echo "unknown subcommand: ${1:-}" >&2; echo "usage: jsonl-event-emitter.sh emit <event_type> <payload_json>" >&2; exit 2 ;;
   esac
   ```

2. **Author `tools/verify/m033-p02-jsonl-event-schema.sh`** (≥30 lines, executable). Asserts:
   - `scripts/util/jsonl-event-emitter.sh` exists and is executable.
   - The schema version literal `"1.0"` appears (catches accidental schema-version drift).
   - All 11 event-type tokens appear in the file body via `grep -F`: `start_branch_detected`, `start_init_invoked`, `constitution_authored`, `ingest_codebase_completed`, `materials_intake_completed`, `ideation_completed`, `migrate_routed`, `customblock_drafted`, `wiki_init_invoked`, `github_init_invoked`, `friendly_tester_report_validated`.
   - The fenced SSOT block markers `# >>> event-types >>>` and `# <<< event-types <<<` appear.
   - The `execution-log.jsonl` append target string appears.
   - **Functional smoke test:** create a `mktemp -d` staging project; invoke `PROJECT_DIR=<staging> bash scripts/util/jsonl-event-emitter.sh emit ideation_completed '{"test":"smoke"}'`; assert `<staging>/.orchestrator/execution-log.jsonl` exists and contains exactly one line with `"event_type":"ideation_completed"` and `"schema_version":"1.0"` substrings; clean up the staging dir.
   - **Negative smoke test:** invoke `bash scripts/util/jsonl-event-emitter.sh emit unknown_event '{}'` and assert exit code is non-zero AND stderr contains the closed enum.
   - Emits PASS/SUMMARY lines per MEM001.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/util/jsonl-event-emitter.sh` exists with the documented closed-enum event types and schema version `1.0`.
- The library appends atomic JSONL records to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`.

This task creates these P02 phase artifacts:
- Library: `scripts/util/jsonl-event-emitter.sh` (FR-22 emitter with 11 event types, schema 1.0).
- Verifier: `tools/verify/m033-p02-jsonl-event-schema.sh` (shape + functional smoke + negative-path).

## Verification

```bash
bash tools/verify/m033-p02-jsonl-event-schema.sh
```

## Inputs

### From Previous Tasks

None. T01 has no intra-phase prerequisites.

### From Disk (Pre-existing)

- `scripts/util/` directory — established by M001 / earlier milestones; T01 lands a new file inside it.
- `scripts/util/json-field.sh` (MEM008) — NOT required by T01 (T01's emitter is push-side, not parse-side; jq is a fallback at consumer parsing time, not at emit time).

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- The 11 event types are a **closed enum**; unknown event types MUST exit non-zero with the enum echoed (per MEM031 closed-enum discipline precedent).
- Schema version `1.0` is fixed at this milestone. Bumping to `1.1` requires a follow-up M033 D-row (the version-evolution discipline established by M020 D024 reversibility-clause).
- JSON-line records MUST be ≤ 480 bytes for atomic append guarantee (PIPE_BUF macOS 512). Records exceeding this size exit non-zero with `payload too large for atomic append` to stderr.
- ISO 8601 UTC timestamp via `date -u +%Y-%m-%dT%H:%M:%SZ` per MEM008.
- Verifier uses single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.
- T01 MUST NOT modify `scripts/lifecycle/start.sh` (P01-shipped surface; modifications are T02 territory).

## Expected Output

After T01 completes:
- `scripts/util/jsonl-event-emitter.sh` exists, is executable, and emits documented JSONL records.
- `tools/verify/m033-p02-jsonl-event-schema.sh` exists, is executable, and exits 0 with `SUMMARY: m033-p02-jsonl-event-schema.sh pass=N fail=0`.
- A summary file at `.orchestrator/milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-SUMMARY.md` documents the deliverables.

## Notes

The emit function reads `${PROJECT_DIR:-$PWD}` as its base directory. Calling commands SHOULD set `PROJECT_DIR` explicitly (matches the start.sh convention from P01). Unset-and-default-to-`$PWD` is the safety net for ad-hoc invocations.

The `validate` subcommand (read-side / log-shape parser) is deliberately out of scope for T01. It would consume `scripts/util/json-field.sh` for parse-side discipline; demand-driven follow-up if observability consumers need a CLI parser. M027 / M019 already consume the JSONL surface programmatically without a dedicated CLI parser.
