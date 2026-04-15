---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M008"
name: "detect-runtime.sh — auto-detect current runtime from environment signals"
depends_on: []
---

## Prerequisites

None. This task is independent and runs first in P05.

Target script path: `scripts/dispatch/detect-runtime.sh` (create).

## Description

Create a pure, read-only detector that identifies which agent runtime (Claude Code, Codex CLI, Cursor, or unknown) is currently executing the orchestrator. It MUST:

- Probe environment variables exported by each runtime.
- Probe filesystem markers (project-local `.claude/`, `.cursor/`, `.codex/` directories and user-level `~/.claude/`, `~/.cursor/`, `~/.codex/`).
- Emit `runtime=` and `confidence=` key=value lines to stdout per MEM001.
- Exit 0 always — never fail; unknown is a legitimate outcome (`runtime=unknown`, `confidence=low`).
- Be Bash 3.2 compatible: no `declare -A`, no `readarray`, no `|&`.

Confidence rules (applied in order):
- `high` — at least one runtime-specific env var AND at least one matching filesystem marker found.
- `medium` — exactly one of env-var OR filesystem marker found.
- `low` — no signals, or only ambiguous signals that match multiple runtimes.

Runtime detection precedence (first match wins when signals conflict):
1. Claude Code — env vars: `CLAUDECODE`, `CLAUDE_CODE_SSE_PORT`, `CLAUDE_CODE_ENTRYPOINT`. Markers: `$PWD/.claude/` or `$HOME/.claude/`.
2. Codex CLI — env vars: `CODEX_HOME`, `CODEX_SANDBOX`, `CODEX_CLI_VERSION`. Markers: `$PWD/.codex/` or `$HOME/.codex/`.
3. Cursor — env vars: `CURSOR_TRACE_ID`, `CURSOR_SESSION_ID`, `CURSOR_USER`. Markers: `$PWD/.cursor/`.

An optional `--verbose` flag emits probe lines (`probed_env=<var>=<value>`, `probed_path=<path>=<exists|missing>`) BEFORE the `runtime=` / `confidence=` lines so tests can audit the signal set.

An optional `--force <runtime>` flag overrides detection (emits `runtime=<forced>`, `confidence=forced`, `source=force-flag`). Accepted values: `claude-code`, `codex`, `cursor`, `unknown`.

## Steps

1. Create `scripts/dispatch/detect-runtime.sh` with a `#!/usr/bin/env bash` shebang and `set -u`.
2. Parse arguments: `--verbose`, `--force <value>`.
3. If `--force` is provided, validate it against the allowed list, emit forced output, exit 0.
4. Build parallel indexed arrays for each runtime's env-var names and filesystem markers (bash 3.2 safe per MEM001):
   - `claude_envs=(CLAUDECODE CLAUDE_CODE_SSE_PORT CLAUDE_CODE_ENTRYPOINT)`
   - `claude_paths=("$PWD/.claude" "$HOME/.claude")`
   - repeat for codex, cursor.
5. For each runtime, count env hits and path hits. Emit `probed_*=` verbose lines if `--verbose`.
6. Select the first runtime with any hit, per precedence order. Compute confidence from the hit pattern:
   - env_hits > 0 AND path_hits > 0 → high
   - env_hits > 0 XOR path_hits > 0 → medium
   - neither → continue to next runtime
7. If no runtime had any hit, emit `runtime=unknown` / `confidence=low`.
8. Emit `runtime=<name>` and `confidence=<level>` exactly once each.
9. `chmod +x scripts/dispatch/detect-runtime.sh`.

## Must-Haves

- Script exists at `scripts/dispatch/detect-runtime.sh`, executable, Bash 3.2 compatible.
- `--force claude-code` emits `runtime=claude-code` and `confidence=forced`.
- With no env signals and empty `HOME=$(mktemp -d)`, emits `runtime=unknown` and `confidence=low`.
- With `CLAUDECODE=1` and `.claude/` present, emits `runtime=claude-code` and `confidence=high`.
- Exit code is always 0 for valid inputs.

## Verification

Run in order:

```
bash scripts/verify/m008-p05-detect-runtime-output-shape.sh
bash scripts/verify/m008-p05-detect-runtime-signal-coverage.sh
bash scripts/verify/m008-p05-detect-runtime-unknown-path.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P05
```

Expected output for each: `PASS: ...` line and exit code 0.

## Inputs

### From Previous Tasks

None — T01 has no upstream dependencies inside P05.

### From Disk (Pre-existing)

- `scripts/dispatch/backend-registry.sh` (from P02) — reference for the filename-based auto-discovery pattern and key=value stdout conventions. detect-runtime.sh does NOT source it but mirrors its output shape.
- `scripts/state/resolve-root.sh` (from P04) — reference for the pure-resolver pattern (no side effects, emits result on stdout).

## Constraints

- READ-ONLY: must never create, modify, or delete any file. No `mkdir`, no `touch`, no redirection to files.
- Must not invoke other scripts that perform side effects.
- Must not rely on optional tooling (no `jq`, no `python3`). grep/sed/awk/test only per MEM001.
- Exit code is 0 in all non-exceptional paths. Exit 2 only for malformed `--force <bad-value>` flag.

## Expected Output

After T01 completes:
- `scripts/dispatch/detect-runtime.sh` exists and is executable.
- Running `bash scripts/dispatch/detect-runtime.sh` prints two lines on stdout: `runtime=<name>` and `confidence=<level>`.
- Running `bash scripts/dispatch/detect-runtime.sh --verbose` prints additional `probed_env=` / `probed_path=` diagnostic lines.
- Running `bash scripts/dispatch/detect-runtime.sh --force codex` prints `runtime=codex` / `confidence=forced`.
- All three T01 verify scripts pass.
