---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M041"
name: "triage-issue.sh — core triage report engine"
depends_on: []
---

## Prerequisites

- `.orchestrator/execution-log.jsonl` format is documented in `references/file-formats.md`
- `scripts/state/resolve-root.sh` exists and resolves the orchestrator root directory
- Project uses Bash 3.2+ compatible shell scripts (CON-3)

## Description

Create `scripts/diagnostics/triage-issue.sh` — the core diagnostic script that captures structured triage context from orchestrator-internal symptoms and emits a structured Markdown report. This script is the foundation for the entire detective command: all downstream scripts (search-issues.sh, file-issue.sh) and the command definition consume its output.

The script accepts a symptom description (via `--symptom` flag or piped stdin), captures environment and disk state, reads recent execution-log entries, identifies relevant files, and emits a structured triage report with YAML frontmatter and six Markdown body sections.

## Steps

1. **Create `scripts/diagnostics/triage-issue.sh`** with the following structure:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ```

   **Argument parsing** (Bash 3.2 compatible — no associative arrays):
   - `--symptom <text>` — the symptom description (required unless stdin is piped)
   - `--capture-log` — include execution-log tail in the report (default: on)
   - `--errors-only` — filter log entries to FAIL/ERROR results only
   - `--suggest-fix` — run the heuristic fix-suggestion engine
   - `--log-tail <N>` — number of log entries to include (default: 20)

   **Stdin detection (FR-10)**:
   ```bash
   if [ ! -t 0 ] && [ -z "${symptom:-}" ]; then
       symptom="$(cat)"
   fi
   ```

   If `--symptom` is omitted and stdin is not a pipe (TTY), print usage and exit 1.

2. **Implement orchestrator root resolution**:
   ```bash
   ORCH_ROOT="$(bash scripts/state/resolve-root.sh 2>/dev/null || echo ".orchestrator")"
   ```

3. **Implement version detection**:
   ```bash
   if [ -f CHANGELOG.md ]; then
       orch_version="$(grep -m1 '^## \[' CHANGELOG.md | sed 's/## \[//;s/\].*//')"
   else
       orch_version="unknown"
   fi
   ```

4. **Implement execution-log reading (FR-6)**:
   - Read the last N lines from `$ORCH_ROOT/execution-log.jsonl`
   - If `--errors-only`, filter to lines containing `"result":"FAIL"` or `"result":"ERROR"`
   - If the file doesn't exist, set `log_entries` to empty and note "execution-log.jsonl not found"
   - Use `tail -n "$log_tail"` (Bash 3.2 safe)

5. **Implement relevant-file detection**:
   - Extract file-path-like tokens from the symptom (patterns matching `[a-zA-Z_/.-]+\.(sh|md|yml|yaml|json|jsonl)`)
   - For each token, check if the file exists on disk
   - Also grep for the symptom's key words across `scripts/`, `commands/`, `templates/` under `$ORCH_ROOT` (limit to 10 matches)

6. **Implement disk-state snapshot**:
   - Report `$ORCH_ROOT` path
   - List lock files if present (`$ORCH_ROOT/orchestrator.lock`)
   - Report active milestone (via `scripts/state/find-active-milestone.sh` if available, else "none")
   - Report config hash (`md5 -q` on macOS / `md5sum` on Linux for `$ORCH_ROOT/config.yml`)

7. **Implement suggest-fix heuristic (FR-7)**:
   - If `--suggest-fix` is passed:
     - Check if symptom references a file path that doesn't exist → report the missing path and what references it
     - Check for known patterns: "template not found", "script not found", broken symlink patterns
     - If no simple fix identified: output "No simple fix identified — manual investigation required."
   - If `--suggest-fix` is NOT passed:
     - Output "No simple fix identified — run with --suggest-fix for heuristic analysis."
   - The `## Suggested Fix` section is ALWAYS present (FR-1 versioned contract)

8. **Emit the triage report** to stdout in this exact format:

   ```
   ---
   symptom: "<escaped symptom text>"
   captured_at: "<ISO-8601 timestamp>"
   orchestrator_version: "<version>"
   config_hash: "<hash or 'unavailable'>"
   log_tail_count: <N>
   ---

   ## Symptom

   <symptom text, unescaped>

   ## Environment

   - Orchestrator version: <version>
   - Orchestrator root: <path>
   - Active milestone: <milestone or "none">
   - Lock state: <"locked (PID: ...)" or "unlocked">
   - Platform: <uname -s output>
   - Shell: <SHELL env var>

   ## Recent Execution Log

   <last N entries from execution-log.jsonl, or "No execution log found.">

   ## Relevant Files

   <list of files matching symptom keywords, or "No relevant files identified.">

   ## Disk State

   <snapshot of orchestrator state directory>

   ## Suggested Fix

   <fix suggestion or default text>
   ```

9. **Exit code**: always 0 on successful report generation. Exit 1 only on usage error (no symptom provided in non-pipe context).

## Must-Haves

- `triage-issue.sh` exits 0 and produces all six body sections
- `## Suggested Fix` is always present regardless of `--suggest-fix` flag
- When `--suggest-fix` is passed with a missing-file symptom, the section is populated with the path
- Piped stdin is read as the symptom when no `--symptom` flag is provided
- YAML frontmatter includes `symptom`, `captured_at`, `orchestrator_version`

## Verification

```bash
bash tools/verify/m041-p01-triage-report-sections.sh
```

```bash
bash tools/verify/m041-p01-suggest-fix-unconditional.sh
```

```bash
bash tools/verify/m041-p01-pipe-input.sh
```

```bash
bash tools/verify/m041-p01-report-frontmatter.sh
```

## Notes

Expected output from `m041-p01-triage-report-sections.sh`: `PASS: all 6 sections present in triage report output`

Expected output from `m041-p01-pipe-input.sh`: `PASS: piped stdin read as symptom`

## Inputs

### From Disk (Pre-existing)

- `scripts/state/resolve-root.sh` — resolves the orchestrator root directory; this task calls it to determine where `.orchestrator/` lives
- `references/file-formats.md` — documents the execution-log JSONL schema (fields: `type`, `command`, `result`, `timestamp`, etc.)
- `scripts/state/find-active-milestone.sh` — returns the active milestone ID or "NONE"; called for the disk-state snapshot section
- `CHANGELOG.md` — read for version string (first `## [X.Y.Z]` heading)

## Constraints

- Bash 3.2+ compatible (CON-3): no associative arrays, no `${var,,}`, no `|&`
- No writes to `.orchestrator/milestones/` or `.orchestrator/DECISIONS.md` (CON-2)
- Exit 0 on successful report; exit 1 only on usage error
- The `## Suggested Fix` section is a versioned contract — always present, never conditional on flags

## Expected Output

A new file at `scripts/diagnostics/triage-issue.sh` (executable, ~120-180 lines) that:
- Accepts `--symptom`, `--capture-log`, `--errors-only`, `--suggest-fix`, `--log-tail` flags
- Reads piped stdin as symptom when no `--symptom` and stdin is not a TTY
- Emits a structured Markdown triage report to stdout with YAML frontmatter + 6 body sections
- Exits 0 on success, 1 on usage error
