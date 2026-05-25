---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M041"
name: "detective-recommend.sh — recommendation helper + doctor hook"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/run-doctor.sh` exists — the existing doctor script
- `scripts/state/resolve-root.sh` exists — resolves orchestrator root

## Description

Create a shared recommendation helper `scripts/diagnostics/detective-recommend.sh` that other commands can source or call to emit `RECOMMEND: orchestrator:detective --symptom "<description>"` lines. Then wire it into `run-doctor.sh` so doctor emits recommendations when it detects orchestrator-side issues.

The helper uses `$ORCHESTRATOR_ROOT` prefix comparison (via `resolve-root.sh`) to determine if an error path is orchestrator-internal. This implements FR-8 with the #Q-6 advisory: only paths starting with the resolved orchestrator root trigger recommendations — user-project paths with `scripts/` or `commands/` subdirectories do not.

## Steps

1. **Create `scripts/diagnostics/detective-recommend.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Shared helper for cross-command detective recommendations (FR-8).
   # Usage: bash scripts/diagnostics/detective-recommend.sh --symptom "<text>" [--path "<error-path>"]
   # Emits RECOMMEND line to stderr if the path is orchestrator-internal.
   # If --path is omitted, always emits (caller has already determined orchestrator-side).
   ```

   - Accept `--symptom <text>` (required) and `--path <error-path>` (optional)
   - If `--path` is provided, resolve `$ORCHESTRATOR_ROOT` via `scripts/state/resolve-root.sh` and check if the error path starts with it. If NOT, exit 0 silently (user-project path, not orchestrator-side).
   - If path check passes (or no `--path`), emit to stderr: `RECOMMEND: orchestrator:detective --symptom "<symptom>"`
   - Exit 0 always (advisory, never blocks the caller)
   - ~25-35 lines, Bash 3.2 compatible

2. **Modify `scripts/diagnostics/run-doctor.sh`** to call the recommendation helper.

   First, read the existing file to understand its structure. Look for where it emits findings/warnings.

   Add a call near the end of the doctor run (after all checks complete) that:
   - Checks if any findings reference orchestrator script/command/template paths
   - For each such finding, calls `detective-recommend.sh --symptom "<finding description>" --path "<finding path>"`
   
   The modification should be minimal — a single block at the end that sources or calls the helper. Do NOT restructure the existing doctor output format.

   If `detective-recommend.sh` doesn't exist (e.g., detective not installed), the call should silently skip (guard with `[ -f ... ]`).

## Must-Haves

- `detective-recommend.sh` exists and emits `RECOMMEND:` line for orchestrator-internal paths
- `detective-recommend.sh` does NOT emit for user-project paths
- `run-doctor.sh` calls the recommendation helper after its checks

## Verification

```bash
bash tools/verify/m041-p03-doctor-recommendation.sh
```

```bash
bash tools/verify/m041-p03-path-disambiguation.sh
```

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — existing doctor script to modify
- `scripts/state/resolve-root.sh` — resolves orchestrator root for path comparison

## Constraints

- Bash 3.2+ compatible (CON-3)
- Recommendation is advisory — never blocks the calling command (FR-8)
- Minimal modification to run-doctor.sh — add hook, don't restructure
- The helper must be callable from any command, not just doctor

## Expected Output

- New file: `scripts/diagnostics/detective-recommend.sh` (~25-35 lines, executable)
- Modified: `scripts/diagnostics/run-doctor.sh` (small addition to call the helper)
