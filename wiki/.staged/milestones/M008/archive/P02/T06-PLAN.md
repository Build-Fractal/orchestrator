---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P02"
milestone: "M008"
name: "Integration test + Bash 3.2 compatibility check"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- All prior P02 tasks complete:
  - T01: `templates/dispatch-result.md`, `templates/dispatch-error.md`
  - T02: `scripts/dispatch/backend-registry.sh`
  - T03: `scripts/dispatch/adapters/backend/local-agent.sh`
  - T04: `scripts/dispatch/adapters/backend/local-codex.sh`
  - T05: `scripts/dispatch/dispatch-interface.sh`

## Description

Create two final verification scripts:

1. **`scripts/verify/m008-p02-bash32-compat.sh`** — scans all P02 shell scripts for Bash-4-only constructs (associative arrays `declare -A`, `readarray`/`mapfile`, `|&`, `&>>` append-redirect) and fails if any are found. Mirrors `m002-p02-bash32-compat.sh` and `m008-p01-bash32-compat.sh`.

2. **`scripts/verify/m008-p02-integration-e2e.sh`** — end-to-end integration smoke test. Constructs a fixture task plan, payload, and intensity-metadata file in a scratch directory, then invokes `dispatch-interface.sh` routed to `local-agent` (forced available via `SPECKIT_AGENT_TOOL=1`). Asserts that the emitted stdout is a parseable dispatch-result with the correct backend and propagated task_id.

This task adds no new source scripts or templates — only the two verification scripts. It is the phase "glue" check confirming all five prior tasks integrate correctly.

## Steps

### Step 1 — Create scripts/verify/m008-p02-bash32-compat.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies all P02 shell scripts are Bash 3.2 compatible.
# macOS ships Bash 3.2; the orchestrator targets this baseline.
set -u

FILES=(
  "scripts/dispatch/backend-registry.sh"
  "scripts/dispatch/dispatch-interface.sh"
  "scripts/dispatch/adapters/backend/local-agent.sh"
  "scripts/dispatch/adapters/backend/local-codex.sh"
)

for f in "${FILES[@]}"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

  # Forbidden: declare -A (associative arrays, Bash 4+)
  if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
    echo "FAIL: $f uses 'declare -A' (associative arrays, Bash 4+)"
    exit 1
  fi

  # Forbidden: readarray / mapfile (Bash 4+)
  if grep -qE '^[[:space:]]*(readarray|mapfile)[[:space:]]' "$f"; then
    echo "FAIL: $f uses readarray/mapfile (Bash 4+)"
    exit 1
  fi

  # Forbidden: |& (Bash 4+ shorthand for 2>&1 |)
  if grep -qE '[^|]\|&[^|]' "$f"; then
    echo "FAIL: $f uses '|&' (Bash 4+ shorthand)"
    exit 1
  fi
done

echo "PASS: all P02 scripts are Bash 3.2 compatible"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-bash32-compat.sh
```

### Step 2 — Create scripts/verify/m008-p02-integration-e2e.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# End-to-end integration smoke test for P02.
#
# Constructs a fixture task plan, payload, and intensity-metadata file,
# then invokes dispatch-interface.sh with --backend local-agent (forced
# available via SPECKIT_AGENT_TOOL=1). Asserts that the emitted stdout
# is a parseable dispatch-result with backend=local-agent and the
# propagated task_id.
set -u

INTERFACE="scripts/dispatch/dispatch-interface.sh"
REGISTRY="scripts/dispatch/backend-registry.sh"
LOCAL_AGENT="scripts/dispatch/adapters/backend/local-agent.sh"
LOCAL_CODEX="scripts/dispatch/adapters/backend/local-codex.sh"
RESULT_TEMPLATE="templates/dispatch-result.md"
ERROR_TEMPLATE="templates/dispatch-error.md"

# All P02 artifacts must exist
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX" "$RESULT_TEMPLATE" "$ERROR_TEMPLATE"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX"; do
  test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
done

# Registry must list both adapters
discovered="$(bash "$REGISTRY" --list 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
echo ",${discovered}," | grep -q ',local-agent,' || { echo "FAIL: registry did not discover local-agent (got: $discovered)"; exit 1; }
echo ",${discovered}," | grep -q ',local-codex,' || { echo "FAIL: registry did not discover local-codex (got: $discovered)"; exit 1; }

# Registry summary must succeed
summary="$(bash "$REGISTRY" 2>/dev/null)"
echo "$summary" | grep -q '^backends_discovered=' || { echo "FAIL: registry summary missing backends_discovered"; exit 1; }
echo "$summary" | grep -q '^backends_available=' || { echo "FAIL: registry summary missing backends_available"; exit 1; }
echo "$summary" | grep -q '^default_backend=' || { echo "FAIL: registry summary missing default_backend"; exit 1; }

# Fixture inputs
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T42"
phase: "P02"
milestone: "M008"
name: "E2E fixture"
depends_on: []
---

## Description

Fixture task plan for P02 integration test.
EOF

echo "Integration payload fixture" > "$tmp/payload.md"
echo "Integration metadata fixture" > "$tmp/metadata.md"

# Invoke dispatch-interface.sh routed explicitly to local-agent.
# SPECKIT_AGENT_TOOL=1 forces local-agent probe to report available=true.
output="$(SPECKIT_AGENT_TOOL=1 bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: dispatch-interface.sh --backend local-agent exited $rc (expected 0)"
  exit 1
fi

# Assert parseable dispatch-result
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version frontmatter"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output not a dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output backend is not local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T42"' || { echo "FAIL: output did not propagate task_id from fixture"; exit 1; }
echo "$output" | grep -q '^phase_id: "P02"' || { echo "FAIL: output did not propagate phase_id from fixture"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M008"' || { echo "FAIL: output did not propagate milestone_id from fixture"; exit 1; }
echo "$output" | grep -qE '^status: "(success|failure|retry|timeout)"' || { echo "FAIL: output status not in expected set"; exit 1; }

# Also verify a failure path: non-existent backend -> structured error on stderr
err="$(bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend nonexistent-backend 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }

echo "PASS: P02 integration -- registry discovers adapters, interface routes to local-agent, result schema conforms"
```

Make it executable:

```bash
chmod +x scripts/verify/m008-p02-integration-e2e.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "All new scripts are Bash 3.2 compatible..." and "End-to-end integration: dispatch-interface.sh, invoked with a fixture task plan and payload and explicit --backend local-agent, produces a parseable dispatch-result on stdout."
- **Artifacts**: `scripts/verify/m008-p02-bash32-compat.sh`, `scripts/verify/m008-p02-integration-e2e.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-bash32-compat.sh
bash scripts/verify/m008-p02-integration-e2e.sh
```

Both should print `PASS:` and exit 0.

Also run the full phase verification to confirm all must-haves are satisfied:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P02
```

### Files Touched By This Task

- `scripts/verify/m008-p02-bash32-compat.sh` (create)
- `scripts/verify/m008-p02-integration-e2e.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/dispatch/dispatch-interface.sh` (from T05)
  - Key API: `bash ... --task-plan <p> --payload <p> --intensity-metadata <p> [--backend <name>]`. Emits adapter's dispatch-result on stdout (exit 0) or dispatch-error on stderr (exit non-zero).
- `scripts/dispatch/backend-registry.sh` (from T02)
  - Key API: `bash ...` -> `backends_discovered=`, `backends_available=`, `default_backend=` lines. `--list` prints adapter names.
- `scripts/dispatch/adapters/backend/local-agent.sh` (from T03)
  - Behavior: probe honors `SPECKIT_AGENT_TOOL=1`; normal mode emits dispatch-result with backend=local-agent.
- `scripts/dispatch/adapters/backend/local-codex.sh` (from T04)
  - Behavior: probe checks PATH for `codex`.
- `templates/dispatch-result.md`, `templates/dispatch-error.md` (from T01)
  - Schemas emitted by adapters (result) and interface (error).

### From Disk (Pre-existing)

- Standard utilities (`bash`, `grep`, `mktemp`, `cat`, `echo`, `tr`, `sed`).

## Constraints

- No new source scripts or templates are created in this task — only verification scripts.
- The Bash 3.2 check targets only the P02 source scripts (not the verify scripts themselves, which may use slightly richer constructs within reason).
- The integration test must be hermetic: all fixture files are created in `mktemp -d` and cleaned via `trap`.
- `SPECKIT_AGENT_TOOL=1` is used to force local-agent availability so the test is deterministic regardless of the developer's current runtime (avoids false failures on CI where `.claude/` may not exist).

## Expected Output

After completing this task:

1. `scripts/verify/m008-p02-bash32-compat.sh` exists, is executable, and prints `PASS` when run.
2. `scripts/verify/m008-p02-integration-e2e.sh` exists, is executable, and prints `PASS` when run.
3. `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P02` reports all phase truths pass.
4. `git status` shows 2 new files.
