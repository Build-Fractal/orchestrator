---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M008"
name: "Create local-codex.sh adapter (Codex CLI SDK)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/dispatch-result.md` exists and defines the success result schema (same fields as T03's prerequisites).
- `scripts/dispatch/adapters/backend/` directory may not yet exist (created here if absent; T03 also creates it — idempotent `mkdir -p`).
- The `codex` CLI binary *may or may not* be installed on the runtime machine; the adapter must handle both cases correctly.

## Description

Create `scripts/dispatch/adapters/backend/local-codex.sh`, the backend adapter for the Codex CLI SDK. This adapter satisfies FR-010 (second local dispatch backend).

The adapter supports two modes:

1. **`--probe`** — emit `available=true|false` based on whether the `codex` binary is on PATH. No further checks — probe is fast and side-effect-free.

2. **Normal mode** — invoke the `codex` CLI as a subprocess with the assembled payload, capture stdout/stderr/exit, and emit a dispatch-result.md conforming document. The exact `codex` CLI invocation is not yet validated against the Codex CLI documentation — the adapter uses a placeholder invocation (`codex run --prompt-file "$PAYLOAD"`) guarded by an explicit `TODO(M008-P02)` comment, so runtime validation can replace the invocation without touching the surrounding result-emission logic. On success, the adapter emits `status: success` and includes the Codex CLI stdout in the Summary section. On failure (non-zero exit from `codex`), the adapter emits `status: failure` with the captured stderr in the Notes section.

Arguments (normal mode, identical to local-agent.sh for parity):

- `--task-plan <path>` — path to the task plan file.
- `--payload <path>` — path to the assembled context payload.
- `--intensity-metadata <path>` — path to the intensity metadata file.

## Steps

### Step 1 — Ensure adapter directory exists (idempotent)

```bash
mkdir -p scripts/dispatch/adapters/backend
```

### Step 2 — Create scripts/dispatch/adapters/backend/local-codex.sh

Write the following content verbatim to `scripts/dispatch/adapters/backend/local-codex.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/local-codex.sh — Codex CLI SDK adapter
#
# Dispatch backend adapter that routes tasks through the `codex` command-
# line tool. Probe mode checks whether the `codex` binary is on PATH.
# Normal mode invokes the CLI as a subprocess with the assembled payload
# and emits a dispatch-result.md conforming document.
#
# Exact Codex CLI invocation is not yet runtime-validated (see the
# TODO(M008-P02) comment below). The placeholder `codex run --prompt-file
# "$PAYLOAD"` preserves the interface contract; swapping it for the
# correct Codex CLI syntax is a follow-up that does not require changes
# to any other orchestrator file.
#
# Usage:
#   local-codex.sh --probe
#     Emits: available=true|false
#
#   local-codex.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#     Emits a dispatch-result.md conforming document on stdout.
#
# Bash 3.2 compatible.

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="codex-not-on-path"
  if command -v codex >/dev/null 2>&1; then
    available="true"
    reason="codex-binary-found"
  fi
  echo "available=${available}"
  echo "backend=local-codex"
  echo "reason=${reason}"
  exit 0
fi

# --- Normal mode ---

# Validate required inputs
if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  echo "ERROR: --task-plan is required and must point to an existing file" >&2
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  echo "ERROR: --payload is required and must point to an existing file" >&2
  exit 2
fi

# Extract task/phase/milestone IDs from task plan YAML frontmatter
task_id="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
phase_id="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
milestone_id="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"

: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_ts="$(date -u +%s)"

# Prepare capture files
tmp_stdout="$(mktemp)"
tmp_stderr="$(mktemp)"
trap 'rm -f "$tmp_stdout" "$tmp_stderr"' EXIT

# Check codex is on PATH; if not, emit a failure result immediately.
if ! command -v codex >/dev/null 2>&1; then
  completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat <<EOF
---
schema_version: "1.0"
type: dispatch-result
status: "failure"
backend: "local-codex"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "0"
---

# Dispatch Result

## Status

failure -- codex CLI is not installed on PATH

## Summary

The local-codex adapter could not dispatch task ${task_id} because the
\`codex\` binary is not on PATH.

## Artifacts

## Notes

Install the Codex CLI and ensure \`codex\` is on PATH, or dispatch via a
different backend (e.g., --backend local-agent).
EOF
  exit 0
fi

# TODO(M008-P02): Replace the placeholder invocation below with the
# validated Codex CLI syntax. This is a wiring scaffold -- probe +
# result-emission contract is complete; the exact CLI argument shape is
# a runtime-validation follow-up that does not alter this file's
# structure or any other orchestrator file.
#
# Placeholder rationale: `codex run --prompt-file <file>` is a common
# CLI convention; the real CLI may use different flags.

codex_rc=0
codex run --prompt-file "$PAYLOAD" >"$tmp_stdout" 2>"$tmp_stderr" || codex_rc=$?

end_ts="$(date -u +%s)"
completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
duration_s=$((end_ts - start_ts))

if [[ $codex_rc -eq 0 ]]; then
  status="success"
  status_note="task dispatched successfully via codex CLI"
else
  status="failure"
  status_note="codex CLI exited with code ${codex_rc}"
fi

cat <<EOF
---
schema_version: "1.0"
type: dispatch-result
status: "${status}"
backend: "local-codex"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "${duration_s}"
---

# Dispatch Result

## Status

${status} -- ${status_note}

## Summary

Task ${task_id} in phase ${phase_id} of milestone ${milestone_id} was
dispatched via the local-codex backend. The codex CLI stdout follows:

\`\`\`
$(cat "$tmp_stdout")
\`\`\`

## Artifacts

<!-- The codex CLI is responsible for creating artifacts. The adapter
     does not attempt to parse stdout for artifact paths in v1; the
     orchestrator's verification layer inspects the workspace instead. -->

## Notes

Backend: local-codex
codex exit code: ${codex_rc}
codex stderr:
\`\`\`
$(cat "$tmp_stderr")
\`\`\`

Reference: TODO(M008-P02) -- the codex CLI invocation syntax above is a
placeholder pending runtime validation.
EOF

exit 0
```

### Step 3 — Make the adapter executable

```bash
chmod +x scripts/dispatch/adapters/backend/local-codex.sh
```

### Step 4 — Create scripts/verify/m008-p02-local-codex-probe.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-codex.sh --probe works and emits available= key.
set -u

f="scripts/dispatch/adapters/backend/local-codex.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Check --probe flag handling exists
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not handle --probe"; exit 1; }
grep -q 'backend=local-codex' "$f" || { echo "FAIL: $f missing backend=local-codex identifier"; exit 1; }
grep -q 'command -v codex' "$f" || { echo "FAIL: $f does not check for codex binary on PATH"; exit 1; }

# Run probe — must emit available= key with true or false value, and exit 0
output="$(bash "$f" --probe 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: probe exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -qE '^available=(true|false)$' || { echo "FAIL: probe did not emit available=true|false: $output"; exit 1; }
echo "$output" | grep -q '^backend=local-codex' || { echo "FAIL: probe did not emit backend=local-codex"; exit 1; }

echo "PASS: local-codex.sh --probe emits available= and backend=local-codex"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-codex-probe.sh
```

### Step 5 — Create scripts/verify/m008-p02-local-codex-result.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-codex.sh normal mode emits a dispatch-result conforming
# document. The test does NOT require the codex CLI to be installed --
# when it is absent, the adapter must emit a failure-status result with
# backend=local-codex (the uniform contract must hold in both cases).
set -u

f="scripts/dispatch/adapters/backend/local-codex.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Ensure the script contains the TODO marker documenting the placeholder
# invocation (contract: runtime validation follow-up).
grep -q 'TODO(M008-P02)' "$f" || { echo "FAIL: $f missing TODO(M008-P02) marker for placeholder codex invocation"; exit 1; }

# Fixture files
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "Fixture"
depends_on: []
---

## Description

Fixture.
EOF

echo "Fixture payload" > "$tmp/payload.md"
echo "Fixture metadata" > "$tmp/metadata.md"

output="$(bash "$f" --task-plan "$tmp/task-plan.md" --payload "$tmp/payload.md" --intensity-metadata "$tmp/metadata.md" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: adapter exited $rc (expected 0)"; exit 1
fi

# Frontmatter must include identifying fields regardless of codex presence
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output missing type: dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-codex"' || { echo "FAIL: output missing backend: local-codex"; exit 1; }
echo "$output" | grep -q '^task_id: "T99"' || { echo "FAIL: output did not propagate task_id"; exit 1; }
echo "$output" | grep -q '^phase_id: "P99"' || { echo "FAIL: output did not propagate phase_id"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M999"' || { echo "FAIL: output did not propagate milestone_id"; exit 1; }
echo "$output" | grep -qE '^status: "(success|failure)"' || { echo "FAIL: output missing status: success or failure"; exit 1; }

# Body sections
echo "$output" | grep -q '^# Dispatch Result' || { echo "FAIL: output missing '# Dispatch Result' heading"; exit 1; }
echo "$output" | grep -q '^## Status' || { echo "FAIL: output missing '## Status' section"; exit 1; }
echo "$output" | grep -q '^## Summary' || { echo "FAIL: output missing '## Summary' section"; exit 1; }
echo "$output" | grep -q '^## Artifacts' || { echo "FAIL: output missing '## Artifacts' section"; exit 1; }
echo "$output" | grep -q '^## Notes' || { echo "FAIL: output missing '## Notes' section"; exit 1; }

echo "PASS: local-codex.sh emits a dispatch-result conforming document"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-codex-result.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/adapters/backend/local-codex.sh supports --probe and checks whether the `codex` binary is on PATH." and "scripts/dispatch/adapters/backend/local-codex.sh in normal mode wires a subprocess invocation of the `codex` CLI and emits a dispatch-result.md conforming document with backend=local-codex."
- **Artifacts**: `scripts/dispatch/adapters/backend/local-codex.sh`, `scripts/verify/m008-p02-local-codex-probe.sh`, `scripts/verify/m008-p02-local-codex-result.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-local-codex-probe.sh
bash scripts/verify/m008-p02-local-codex-result.sh
```

Both should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/dispatch/adapters/backend/local-codex.sh` (create)
- `scripts/verify/m008-p02-local-codex-probe.sh` (create)
- `scripts/verify/m008-p02-local-codex-result.sh` (create)

## Inputs

### From Previous Tasks

- `templates/dispatch-result.md` (from T01)
  - Same schema as used by T03 (`local-agent.sh`). The adapter emits text matching this schema via a heredoc.
  - Critical behavioral contract: even when the task execution fails (codex unavailable, codex exits non-zero), the adapter still emits a conforming dispatch-result — with `status: failure` — so the uniform interface is preserved.

### From Disk (Pre-existing)

- None required beyond standard system utilities (`command`, `date`, `mktemp`, `grep`, `sed`, `cat`).

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`.
- Probe mode must never fail (exits 0 even when codex absent — emits `available=false`).
- Normal mode must emit a dispatch-result conforming document even when codex is absent or fails — the uniform interface contract (FR-009) requires this.
- Normal mode exits 0 on both success and task-execution failure (the orchestrator parses `status:` from the emitted document to distinguish). Only malformed inputs (missing `--task-plan`/`--payload`) cause non-zero exit.
- The placeholder `codex run --prompt-file "$PAYLOAD"` invocation MUST be accompanied by a `TODO(M008-P02)` comment so the follow-up runtime-validation task is discoverable via grep.
- ISO 8601 UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`) per MEM008.

## Expected Output

After completing this task:

1. `scripts/dispatch/adapters/backend/local-codex.sh` exists (~140 lines), is executable.
2. `bash scripts/dispatch/adapters/backend/local-codex.sh --probe` emits `available=true|false` and `backend=local-codex`. Exit 0.
3. Normal mode with fixture inputs emits a dispatch-result with `backend: "local-codex"`, propagated task/phase/milestone IDs, and a `status:` of either `success` or `failure` depending on whether `codex` is on PATH. Exit 0.
4. The file contains the `TODO(M008-P02)` marker.
5. `bash scripts/verify/m008-p02-local-codex-probe.sh` prints `PASS`.
6. `bash scripts/verify/m008-p02-local-codex-result.sh` prints `PASS`.
7. `git status` shows 3 new files.
