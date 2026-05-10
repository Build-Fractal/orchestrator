---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M008"
name: "Create dispatch-interface.sh -- the uniform entry point"
depends_on: ["T02", "T03", "T04"]
---

## Prerequisites

- T02 complete: `scripts/dispatch/backend-registry.sh` exists and outputs `backends_discovered=`, `backends_available=`, `default_backend=` as key=value lines, and supports `--list` and `--probe <backend>` sub-modes.
- T03 complete: `scripts/dispatch/adapters/backend/local-agent.sh` exists and supports `--probe` plus the normal-mode argument contract (`--task-plan`, `--payload`, `--intensity-metadata`).
- T04 complete: `scripts/dispatch/adapters/backend/local-codex.sh` exists with the same argument contract.
- `templates/dispatch-error.md` exists (from T01).

## Description

Create `scripts/dispatch/dispatch-interface.sh`, the uniform dispatch entry point that satisfies FR-009 ("define a uniform dispatch interface that accepts a task plan and context payload, and returns a structured result"), FR-011 (new backends registerable without core edits), and FR-012 (structured error information on failure).

The interface is intentionally a thin router. It has three responsibilities:

1. **Parse arguments** — `--task-plan`, `--payload`, `--intensity-metadata`, optional `--backend`.
2. **Resolve backend** — if `--backend` is supplied explicitly, use that name; otherwise query `backend-registry.sh` for `default_backend`.
3. **Invoke adapter as a subprocess** — pass through the task-plan, payload, and intensity-metadata arguments. Emit the adapter's stdout unchanged on success. On failure (adapter not found, adapter exited non-zero without emitting a conforming result, malformed adapter output), synthesize a `dispatch-error.md` conforming document on stderr and exit non-zero.

**SC-003 / FR-011 guarantee**: the interface contains NO backend-specific branching. There is no `if [[ backend == "local-agent" ]]` or similar code. Backend selection is purely by filename lookup in `scripts/dispatch/adapters/backend/`. Adding a new backend = dropping a new file in that directory. Verification script `m008-p02-interface-agnostic.sh` enforces this by grepping for forbidden patterns.

## Steps

### Step 1 — Create scripts/dispatch/dispatch-interface.sh

Write the following content verbatim to `scripts/dispatch/dispatch-interface.sh`:

```bash
#!/usr/bin/env bash
# scripts/dispatch/dispatch-interface.sh — Uniform dispatch interface
#
# Thin router that accepts a task plan + context payload + intensity
# metadata, resolves a backend adapter (via backend-registry.sh or an
# explicit --backend flag), and invokes the adapter as a subprocess.
#
# On success: emits the adapter's stdout (a dispatch-result.md
# conforming document) unchanged, exit 0.
#
# On failure: synthesizes a dispatch-error.md conforming document on
# stderr and exits non-zero. Failure modes:
#   - missing required inputs (--task-plan, --payload)
#   - explicit --backend that does not exist in adapters/backend/
#   - no backends available (registry reports default_backend empty)
#   - adapter subprocess exits non-zero without emitting a result
#
# Usage:
#   dispatch-interface.sh --task-plan <path> --payload <path> \
#                         --intensity-metadata <path> [--backend <name>]
#
# FR-009: uniform interface, structured result.
# FR-011: no backend-specific branching -- adapters are resolved purely
#         by filename lookup in scripts/dispatch/adapters/backend/.
# FR-012: structured error schema on failure.
# SC-003: new backends = new files; zero edits to this file required.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${SCRIPT_DIR}/backend-registry.sh"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --backend)
      BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Helper: emit a dispatch-error document on stderr ---
emit_error() {
  local error_type="$1"
  local retry_eligible="$2"
  local escalation="$3"
  local backend="$4"
  local error_message="$5"
  local error_context="$6"
  local suggested_action="$7"
  local occurred_at
  occurred_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat >&2 <<EOF
---
schema_version: "1.0"
type: dispatch-error
error_type: "${error_type}"
retry_eligible: "${retry_eligible}"
escalation: "${escalation}"
backend: "${backend}"
occurred_at: "${occurred_at}"
---

# Dispatch Error

## Error Type

${error_type}

## Retry Eligibility

retry_eligible: ${retry_eligible}

## Escalation

escalation: ${escalation}

## Error Message

${error_message}

## Context

${error_context}

## Suggested Action

${suggested_action}
EOF
}

# --- Validate inputs ---

if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--task-plan is required and must point to an existing file" \
    "Received --task-plan='${TASK_PLAN}'" \
    "Provide a valid --task-plan path."
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--payload is required and must point to an existing file" \
    "Received --payload='${PAYLOAD}'" \
    "Provide a valid --payload path."
  exit 2
fi

# --- Resolve backend ---

if [[ -z "$BACKEND" ]]; then
  # Query registry for default
  if [[ ! -x "$REGISTRY" ]]; then
    emit_error "registry_error" "false" "developer" "" \
      "backend-registry.sh is missing or not executable" \
      "Expected at ${REGISTRY}" \
      "Restore the registry script or pass --backend <name> explicitly."
    exit 3
  fi
  registry_output="$(bash "$REGISTRY" 2>/dev/null)"
  BACKEND="$(echo "$registry_output" | grep -E '^default_backend=' | head -n 1 | cut -d= -f2)"
  if [[ -z "$BACKEND" ]]; then
    available="$(echo "$registry_output" | grep -E '^backends_available=' | head -n 1 | cut -d= -f2)"
    emit_error "backend_unavailable" "false" "developer" "" \
      "No dispatch backends reported available" \
      "Registry output: backends_available=${available}" \
      "Install a supported backend (e.g., Claude Code with SPECKIT_AGENT_TOOL=1, or Codex CLI) or register a new adapter in scripts/dispatch/adapters/backend/."
    exit 4
  fi
fi

# --- Resolve adapter path by filename (no backend-specific branching) ---

ADAPTER="${ADAPTERS_DIR}/${BACKEND}.sh"
if [[ ! -f "$ADAPTER" ]]; then
  emit_error "backend_unavailable" "false" "developer" "${BACKEND}" \
    "Requested backend '${BACKEND}' has no adapter script" \
    "Expected adapter at ${ADAPTER}" \
    "Drop an adapter file at the expected path, or pass --backend with a registered name (see 'bash ${REGISTRY} --list')."
  exit 4
fi

# --- Invoke adapter as a subprocess ---

adapter_rc=0
adapter_output="$(bash "$ADAPTER" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?

if [[ $adapter_rc -ne 0 ]]; then
  emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
    "Adapter subprocess exited with code ${adapter_rc}" \
    "Adapter: ${ADAPTER}" \
    "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
  exit 5
fi

# Minimal conformance check: adapter output must contain schema_version
# and type: "dispatch-result" frontmatter.
if ! echo "$adapter_output" | grep -q '^schema_version:'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing schema_version frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi
if ! echo "$adapter_output" | grep -q '^type: "dispatch-result"'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing type: dispatch-result frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi

# --- Emit adapter output unchanged ---
echo "$adapter_output"
exit 0
```

### Step 2 — Make the interface executable

```bash
chmod +x scripts/dispatch/dispatch-interface.sh
```

### Step 3 — Create scripts/verify/m008-p02-interface-arguments.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh accepts required arguments and rejects
# missing inputs with a structured error.
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script declares the expected flags
grep -q '\-\-task-plan' "$f" || { echo "FAIL: $f missing --task-plan"; exit 1; }
grep -q '\-\-payload' "$f" || { echo "FAIL: $f missing --payload"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q '\-\-backend' "$f" || { echo "FAIL: $f missing --backend"; exit 1; }
grep -q 'backend-registry.sh' "$f" || { echo "FAIL: $f does not reference backend-registry.sh"; exit 1; }

# Missing --task-plan: must exit non-zero and emit a dispatch-error on stderr
err="$(bash "$f" --payload /dev/null 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --task-plan did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'input_invalid' || { echo "FAIL: missing --task-plan did not emit error_type=input_invalid"; exit 1; }

# Missing --payload: must exit non-zero and emit a dispatch-error
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo '---' > "$tmp/tp.md"
err2="$(bash "$f" --task-plan "$tmp/tp.md" 2>&1 >/dev/null || true)"
echo "$err2" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --payload did not emit dispatch-error"; exit 1; }

echo "PASS: dispatch-interface.sh accepts required arguments and rejects missing inputs with structured errors"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-arguments.sh
```

### Step 4 — Create scripts/verify/m008-p02-interface-routing.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh routes to the correct adapter and
# emits either the adapter's result (success) or a dispatch-error
# (failure).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T77"
phase: "P02"
milestone: "M008"
name: "Routing fixture"
depends_on: []
---

## Description

Fixture.
EOF

echo "payload" > "$tmp/payload.md"
echo "metadata" > "$tmp/metadata.md"

# Route explicitly to local-agent (always exists after T03)
output="$(SPECKIT_AGENT_TOOL=1 bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: --backend local-agent exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: routing to local-agent did not emit dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: routing to local-agent did not emit backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T77"' || { echo "FAIL: routing did not propagate task_id"; exit 1; }

# Request a non-existent backend -> dispatch-error on stderr
err="$(bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend does-not-exist 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'backend_unavailable' || { echo "FAIL: nonexistent backend did not emit error_type=backend_unavailable"; exit 1; }

echo "PASS: dispatch-interface.sh routes correctly and emits structured errors on failure"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-routing.sh
```

### Step 5 — Create scripts/verify/m008-p02-interface-agnostic.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies dispatch-interface.sh contains NO backend-specific branching,
# satisfying FR-011 and SC-003 (new backends can be added by dropping
# an adapter file; zero edits to this interface file required).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Forbidden patterns: any conditional that names a specific backend
# indicates the interface is no longer backend-agnostic. Allowed
# references: the placeholder "${BACKEND}" or "$BACKEND" variable.
#
# Check for literal backend names appearing in conditional expressions.
# Matches on '= "local-agent"' or '= "local-codex"' or similar patterns
# that would tie the router to a specific backend.

if grep -E '\[\[[[:space:]]+["$]?BACKEND["$]?[[:space:]]*[=!]=?[[:space:]]*["]?(local-agent|local-codex)["]?' "$f" >/dev/null; then
  echo "FAIL: $f contains backend-specific branching (compares \$BACKEND to a literal adapter name)"
  exit 1
fi

# Also check for `case "$BACKEND" in local-agent)` style branches
if grep -E 'case[[:space:]]+["$]?BACKEND["$]?' "$f" >/dev/null; then
  echo "FAIL: $f switches on \$BACKEND (backend-specific branching)"
  exit 1
fi

# The file must use filename-based resolution (ADAPTERS_DIR + BACKEND + .sh)
grep -q 'ADAPTERS_DIR' "$f" || { echo "FAIL: $f does not use ADAPTERS_DIR for filename-based resolution"; exit 1; }
grep -qE '\$\{?ADAPTERS_DIR\}?/\$\{?BACKEND\}?\.sh' "$f" || { echo "FAIL: $f does not resolve adapter via \${ADAPTERS_DIR}/\${BACKEND}.sh"; exit 1; }

echo "PASS: dispatch-interface.sh is backend-agnostic (filename-based resolution only)"
```

Make executable:

```bash
chmod +x scripts/verify/m008-p02-interface-agnostic.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "scripts/dispatch/dispatch-interface.sh accepts --task-plan, --payload, --intensity-metadata, and optional --backend arguments...", "scripts/dispatch/dispatch-interface.sh invokes the selected adapter as a subprocess...", and "scripts/dispatch/dispatch-interface.sh contains no backend-specific branching...".
- **Artifacts**: `scripts/dispatch/dispatch-interface.sh`, `scripts/verify/m008-p02-interface-arguments.sh`, `scripts/verify/m008-p02-interface-routing.sh`, `scripts/verify/m008-p02-interface-agnostic.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-interface-arguments.sh
bash scripts/verify/m008-p02-interface-routing.sh
bash scripts/verify/m008-p02-interface-agnostic.sh
```

All three should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/dispatch/dispatch-interface.sh` (create)
- `scripts/verify/m008-p02-interface-arguments.sh` (create)
- `scripts/verify/m008-p02-interface-routing.sh` (create)
- `scripts/verify/m008-p02-interface-agnostic.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/dispatch/backend-registry.sh` (from T02)
  - Key API: invoked as `bash scripts/dispatch/backend-registry.sh` (no args). Outputs three key=value lines including `default_backend=<name>` (empty if none available). Also supports `--list` and `--probe <name>`.
  - Behavioral contract: always exits 0; failure modes are reflected in output fields.

- `scripts/dispatch/adapters/backend/local-agent.sh` (from T03)
  - Key API: invoked as `bash ... --task-plan <p> --payload <p> --intensity-metadata <p>`. Emits a dispatch-result.md conforming document on stdout. Exit 0 on success, 2 on malformed inputs.

- `scripts/dispatch/adapters/backend/local-codex.sh` (from T04)
  - Key API: identical to local-agent.sh.

- `templates/dispatch-error.md` (from T01)
  - Schema: `type: dispatch-error`, frontmatter includes `error_type`, `retry_eligible`, `escalation`, `backend`, `occurred_at`. Body: Error Type, Retry Eligibility, Escalation, Error Message, Context, Suggested Action.
  - The interface emits text matching this schema via a heredoc on stderr when dispatch fails.

### From Disk (Pre-existing)

- None required beyond standard utilities (`bash`, `date`, `grep`, `cut`, `echo`, `cat`).

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`.
- MUST NOT contain backend-specific branching. Adapter resolution is purely by filename (`${ADAPTERS_DIR}/${BACKEND}.sh`). No `case "$BACKEND" in local-agent) ... esac` or equivalent. Verified by `m008-p02-interface-agnostic.sh`.
- MUST invoke adapters as subprocesses (`bash "$adapter" ...`), never via `source`. Isolation is a hard requirement.
- MUST emit adapter stdout unchanged on success — no reformatting, no truncation.
- On failure MUST emit a dispatch-error.md conforming document on stderr (not stdout) and exit non-zero.
- Exit codes are informational (callers primarily inspect the emitted document), but use distinct codes: 2 (input_invalid), 3 (registry_error), 4 (backend_unavailable), 5 (backend_crashed), 6 (backend_malformed).
- ISO 8601 UTC timestamps (`date -u +%Y-%m-%dT%H:%M:%SZ`) per MEM008.

## Expected Output

After completing this task:

1. `scripts/dispatch/dispatch-interface.sh` exists (~160 lines), is executable.
2. With missing `--task-plan` or `--payload`, the script emits a `dispatch-error` on stderr with `error_type: input_invalid` and exits non-zero.
3. With valid inputs and `--backend local-agent`, the script invokes the adapter and emits the adapter's `dispatch-result` on stdout unchanged. Exit 0.
4. With `--backend does-not-exist`, the script emits a `dispatch-error` with `error_type: backend_unavailable`. Exit non-zero.
5. Without `--backend`, the script queries the registry for `default_backend` and routes accordingly.
6. The script contains no backend-specific branching.
7. `bash scripts/verify/m008-p02-interface-arguments.sh` prints `PASS`.
8. `bash scripts/verify/m008-p02-interface-routing.sh` prints `PASS`.
9. `bash scripts/verify/m008-p02-interface-agnostic.sh` prints `PASS`.
10. `git status` shows 4 new files.
