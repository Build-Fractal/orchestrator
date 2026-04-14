---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M008"
name: "Create local-agent.sh adapter (Claude Code Agent tool)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/dispatch-result.md` exists and defines the success result schema (YAML frontmatter with `status`, `backend`, `task_id`, `dispatched_at`, `completed_at`, `duration_s`; body sections Status, Summary, Artifacts, Notes).
- `scripts/dispatch/adapters/backend/` directory may not yet exist — this task creates it.
- MEM018 applies: the Claude Code Agent tool is an in-process capability of the orchestrating agent runtime; shell scripts cannot invoke it directly. The adapter therefore functions as a COORDINATION BOUNDARY, emitting a dispatch-result whose `notes` section instructs the orchestrating agent to perform the actual Agent invocation.

## Description

Create `scripts/dispatch/adapters/backend/local-agent.sh`, the backend adapter for Claude Code's native Agent tool. This adapter satisfies FR-010 (ship at least two local dispatch backends — this one being the Claude Code backend).

The adapter supports two modes:

1. **`--probe`** — emit `available=true|false` based on whether the environment is Claude Code.
   - Available if `SPECKIT_AGENT_TOOL=1` env var is set, OR
   - Available if a `.claude/` directory exists at the project root (heuristic: running inside Claude Code).
   - Otherwise `available=false`.

2. **Normal mode** — emit a dispatch-result.md conforming document on stdout. Because the Agent tool is in-process (MEM018), the adapter does not perform the actual execution. Instead it emits a result with `status=success` and a `Notes` section explaining that the orchestrating agent layer is responsible for the actual Agent tool invocation using the supplied `--payload`. This preserves the uniform interface contract while acknowledging the architectural reality.

Arguments (normal mode):

- `--task-plan <path>` — path to the task plan file the adapter is dispatching.
- `--payload <path>` — path to the assembled context payload (output of `scripts/dispatch/build-context.sh`).
- `--intensity-metadata <path>` — path to the intensity metadata file (output of P01).

The adapter reads task identification (task_id, phase_id, milestone_id) from the YAML frontmatter of `--task-plan` and embeds these in the result.

## Steps

### Step 1 — Create the adapter directory

```bash
mkdir -p scripts/dispatch/adapters/backend
```

### Step 2 — Create scripts/dispatch/adapters/backend/local-agent.sh

Write the following content verbatim to `scripts/dispatch/adapters/backend/local-agent.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/local-agent.sh — Claude Code Agent tool adapter
#
# Dispatch backend adapter for Claude Code's in-process Agent tool. Per
# MEM018, the Agent tool cannot be invoked directly from a shell script;
# it is an in-process capability of the orchestrating agent runtime. This
# adapter therefore functions as a coordination boundary: its normal-mode
# output is a dispatch-result.md conforming document whose Notes section
# instructs the orchestrating agent layer to perform the actual Agent
# invocation.
#
# The uniform dispatch interface is preserved: callers receive a
# parseable dispatch-result, independent of where/how the Agent tool
# ultimately runs.
#
# Usage:
#   local-agent.sh --probe
#     Emits: available=true|false
#
#   local-agent.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#     Emits a dispatch-result.md conforming document on stdout.
#
# Bash 3.2 compatible. Exits 0 on success, non-zero only if input is
# malformed (missing required flags).

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
  reason="not-claude-code"
  if [[ "${SPECKIT_AGENT_TOOL:-0}" = "1" ]]; then
    available="true"
    reason="SPECKIT_AGENT_TOOL=1"
  elif [[ -d .claude ]]; then
    available="true"
    reason="claude-directory-present"
  fi
  echo "available=${available}"
  echo "backend=local-agent"
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

# Default empty values to the string "unknown" to keep frontmatter valid
: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
completed_at="$dispatched_at"

# Emit a dispatch-result.md conforming document. Per MEM018 the adapter
# does not actually execute the Agent tool -- the orchestrating agent
# layer does. This result encodes the coordination boundary: status is
# 'success' (the adapter successfully produced a dispatch descriptor) and
# the Notes section tells the agent layer what to invoke.

cat <<EOF
---
schema_version: "1.0"
type: dispatch-result
status: "success"
backend: "local-agent"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "0"
---

# Dispatch Result

## Status

success -- dispatch descriptor prepared for orchestrating agent layer

## Summary

The local-agent adapter prepared an Agent-tool dispatch descriptor for
task ${task_id} in phase ${phase_id} of milestone ${milestone_id}. Per
MEM018, the actual Agent tool invocation happens at the orchestrating
agent layer (in-process); this adapter defines the coordination boundary
that preserves uniform dispatch-interface semantics.

## Artifacts

<!-- Artifacts are produced by the Agent tool invocation itself. The
     orchestrating agent records them in the task summary after the
     Agent tool returns. This adapter emits an empty artifacts list by
     design. -->

## Notes

Orchestrating-agent action required: invoke the Claude Code Agent tool
with the following inputs:
  - task-plan: ${TASK_PLAN}
  - payload: ${PAYLOAD}
  - intensity-metadata: ${INTENSITY_METADATA}

Backend: local-agent (Claude Code in-process Agent tool)
Reference: MEM018 (Runtime Adapter Interface)
EOF

exit 0
```

### Step 3 — Make the adapter executable

```bash
chmod +x scripts/dispatch/adapters/backend/local-agent.sh
```

### Step 4 — Create scripts/verify/m008-p02-local-agent-probe.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-agent.sh --probe works and emits available= key.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Check --probe flag handling exists
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not handle --probe"; exit 1; }
grep -q 'backend=local-agent' "$f" || { echo "FAIL: $f missing backend=local-agent identifier"; exit 1; }

# Run probe with SPECKIT_AGENT_TOOL=1 — must emit available=true
probe_on="$(SPECKIT_AGENT_TOOL=1 bash "$f" --probe 2>/dev/null)"
echo "$probe_on" | grep -q '^available=true' || { echo "FAIL: probe with SPECKIT_AGENT_TOOL=1 did not emit available=true: $probe_on"; exit 1; }

# Run probe with explicit env disabled and no .claude directory in a scratch dir
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
probe_off="$(cd "$tmp" && SPECKIT_AGENT_TOOL=0 bash "${OLDPWD}/$f" --probe 2>/dev/null || true)"
echo "$probe_off" | grep -q '^available=' || { echo "FAIL: probe in empty dir did not emit available= key"; exit 1; }

echo "PASS: local-agent.sh --probe emits available= and backend=local-agent"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-agent-probe.sh
```

### Step 5 — Create scripts/verify/m008-p02-local-agent-result.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies local-agent.sh normal mode emits a dispatch-result conforming document.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Create a minimal task plan fixture
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "Fixture task for adapter verification"
depends_on: []
---

## Description

Fixture.
EOF

echo "Fixture payload" > "$tmp/payload.md"
echo "Fixture metadata" > "$tmp/metadata.md"

# Invoke the adapter
output="$(bash "$f" --task-plan "$tmp/task-plan.md" --payload "$tmp/payload.md" --intensity-metadata "$tmp/metadata.md" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: adapter exited $rc (expected 0)"; exit 1
fi

# Check frontmatter fields
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output missing type: dispatch-result"; exit 1; }
echo "$output" | grep -q '^status: "success"' || { echo "FAIL: output missing status: success"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output missing backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T99"' || { echo "FAIL: output did not propagate task_id from task plan"; exit 1; }
echo "$output" | grep -q '^phase_id: "P99"' || { echo "FAIL: output did not propagate phase_id from task plan"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M999"' || { echo "FAIL: output did not propagate milestone_id from task plan"; exit 1; }
echo "$output" | grep -qE '^dispatched_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' || { echo "FAIL: output missing ISO 8601 dispatched_at"; exit 1; }

# Check body sections
echo "$output" | grep -q '^# Dispatch Result' || { echo "FAIL: output missing '# Dispatch Result' heading"; exit 1; }
echo "$output" | grep -q '^## Status' || { echo "FAIL: output missing '## Status' section"; exit 1; }
echo "$output" | grep -q '^## Summary' || { echo "FAIL: output missing '## Summary' section"; exit 1; }
echo "$output" | grep -q '^## Artifacts' || { echo "FAIL: output missing '## Artifacts' section"; exit 1; }
echo "$output" | grep -q '^## Notes' || { echo "FAIL: output missing '## Notes' section"; exit 1; }

echo "PASS: local-agent.sh emits a dispatch-result conforming document"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-local-agent-result.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/adapters/backend/local-agent.sh supports --probe and emits available=true|false key=value output." and "scripts/dispatch/adapters/backend/local-agent.sh in normal mode emits a dispatch-result.md conforming document with backend=local-agent."
- **Artifacts**: `scripts/dispatch/adapters/backend/local-agent.sh`, `scripts/verify/m008-p02-local-agent-probe.sh`, `scripts/verify/m008-p02-local-agent-result.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-local-agent-probe.sh
bash scripts/verify/m008-p02-local-agent-result.sh
```

Both should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/dispatch/adapters/backend/local-agent.sh` (create)
- `scripts/verify/m008-p02-local-agent-probe.sh` (create)
- `scripts/verify/m008-p02-local-agent-result.sh` (create)

## Inputs

### From Previous Tasks

- `templates/dispatch-result.md` (from T01)
  - Key schema fields (frontmatter): `schema_version`, `type` (must equal `dispatch-result`), `status` (success|failure|retry|timeout), `backend`, `task_id`, `phase_id`, `milestone_id`, `dispatched_at`, `completed_at`, `duration_s`.
  - Key body sections: `# Dispatch Result`, `## Status`, `## Summary`, `## Artifacts`, `## Notes`.
  - The adapter emits text matching this schema via a heredoc; no file I/O with the template itself.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` — reference for key=value probe-style output convention.
- MEM018 documentation context (Runtime Adapter Interface) — describes why this adapter does not actually invoke the Agent tool.

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`.
- Probe mode must never fail (exits 0 even when unavailable — emits `available=false`).
- Normal mode must fail with non-zero exit only on malformed inputs (missing `--task-plan` or `--payload`); emits an error message to stderr and exits 2.
- Heredoc output must be verbatim — no command substitution inside the heredoc body except for documented placeholders (task_id, phase_id, milestone_id, timestamps, input paths).
- ISO 8601 UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`) per MEM008.
- Must not require any network, daemon, or elevated permissions.

## Expected Output

After completing this task:

1. `scripts/dispatch/adapters/backend/local-agent.sh` exists (~110 lines), is executable.
2. `bash scripts/dispatch/adapters/backend/local-agent.sh --probe` emits key=value lines including `available=true|false` and `backend=local-agent`. Exit 0.
3. With `SPECKIT_AGENT_TOOL=1`, probe emits `available=true`. In a scratch directory without `.claude/`, probe emits `available=false`.
4. `bash scripts/dispatch/adapters/backend/local-agent.sh --task-plan <p> --payload <p> --intensity-metadata <p>` emits a dispatch-result.md conforming document on stdout with `backend: "local-agent"` and the task/phase/milestone IDs extracted from the task plan's frontmatter.
5. `bash scripts/verify/m008-p02-local-agent-probe.sh` prints `PASS`.
6. `bash scripts/verify/m008-p02-local-agent-result.sh` prints `PASS`.
7. `git status` shows 3 new files (plus one new directory `scripts/dispatch/adapters/backend/`).
