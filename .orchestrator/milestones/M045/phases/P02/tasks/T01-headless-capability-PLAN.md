---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M045"
name: "Add headless_reentry capability to detect-capabilities.sh"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/detect-capabilities.sh` exists (extend it).

## Description

Add a `headless_reentry` capability: true when the runtime can spawn a fresh `claude -p` process (the process-fresh re-entry substrate chosen in D015). This is the capability the P02 branch and the P03 wiring gate on for graceful degradation (spec FR-7): where a fresh headless process cannot be spawned (e.g. no `claude` CLI on PATH — Codex/Cursor, or a locked-down CI), self-continue falls back to legacy exit.

## Steps

1. In `scripts/dispatch/detect-capabilities.sh`, in the detection section (near the other `command -v` probes, after the `subagent_dispatch` block), add:
   ```bash
   # headless_reentry: can we spawn a fresh `claude -p` process for a process-fresh
   # self-continue re-entry (M045 / D015)? Requires the claude CLI on PATH.
   headless_reentry=false
   if command -v claude >/dev/null 2>&1; then
     headless_reentry=true
   fi
   ```
2. In the **text** output block (the `echo "key=value"` list, after `echo "ci_pipeline=$ci_pipeline"`), add:
   ```bash
   echo "headless_reentry=$headless_reentry"
   ```
3. In the **json** output block (the `cat <<EOF … EOF` heredoc), add a line inside the JSON object (after `"ci_pipeline": $ci_pipeline` — mind the trailing comma; place `headless_reentry` before the last field or add a comma to the prior line):
   ```
   "headless_reentry": $headless_reentry,
   ```
   Ensure the JSON stays valid (no trailing comma on the final field).
4. Author `tools/verify/m045-p02-headless-capability.sh`:
   ```sh
   #!/usr/bin/env sh
   # Checks detect-capabilities.sh emits a headless_reentry key in both formats.
   set -eu
   OUT=$(bash scripts/dispatch/detect-capabilities.sh 2>/dev/null)
   echo "$OUT" | grep -q '^headless_reentry=' || { echo "FAIL: no headless_reentry in text output"; exit 1; }
   JSON=$(bash scripts/dispatch/detect-capabilities.sh --format json 2>/dev/null)
   echo "$JSON" | grep -q '"headless_reentry"' || { echo "FAIL: no headless_reentry in json output"; exit 1; }
   echo "PASS: headless_reentry present in text + json"
   ```
5. `chmod +x tools/verify/m045-p02-headless-capability.sh` and run it.

## Must-Haves

- `detect-capabilities.sh` emits `headless_reentry=` in text and `"headless_reentry"` in JSON.
- JSON output remains valid.

## Verification

`bash tools/verify/m045-p02-headless-capability.sh`
`bash scripts/dispatch/detect-capabilities.sh --format json`

## Inputs

### From Disk (Pre-existing)
- `scripts/dispatch/detect-capabilities.sh` — text output is `key=value` lines (~line 179+); JSON output is a `cat <<EOF` heredoc (~line 160+). Detection vars are plain bash booleans (`true`/`false` strings).

## Constraints

- Do not disturb existing capability fields or the `--profile` output.
- Bash 3.2 compatible.

## Expected Output

`detect-capabilities.sh` reports `headless_reentry` in both formats; verifier prints `PASS:`.
