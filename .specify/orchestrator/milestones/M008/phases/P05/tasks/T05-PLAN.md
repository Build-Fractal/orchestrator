---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M008"
name: "native.sh — orchestrator native task-plan format adapter"
depends_on: []
---

## Prerequisites

None — T05 is independent.

Target script path: `scripts/dispatch/adapters/format/native.sh` (create; directory must be created if absent).

## Description

Create the native format adapter. The native task-plan format is defined by `templates/task-plan.md`: YAML frontmatter with `schema_version`, `type: task-plan`, `task`, `phase`, `milestone`, `name`, `depends_on`, followed by a markdown body.

The adapter supports:
- `--probe` → emits `available=true` / `reason=native-format-always-available` (the native format is always available since it is the orchestrator's own format).
- `--read <path>` → reads a task-plan.md-shaped file and echoes it unchanged (identity function); additionally validates that the frontmatter contains required keys.
- `--write <path>` → accepts task-plan content on stdin and writes it atomically to `<path>`, preserving frontmatter.

Unlike runtime adapters, format adapters are filename-registered under `scripts/dispatch/adapters/format/*.sh` — separate namespace from runtime adapters.

## Steps

1. Create directory `scripts/dispatch/adapters/format/` with `mkdir -p`.
2. Create `scripts/dispatch/adapters/format/native.sh` with `#!/usr/bin/env bash` and `set -u`.
3. Parse `--probe | --read <path> | --write <path>`.
4. --probe mode:
   - Emit `available=true`, `format=native`, `reason=native-format-always-available`.
   - Exit 0.
5. --read mode:
   - Validate input: `[[ -f "$PATH_ARG" ]]`; else emit `FAIL: file not found` on stderr, exit 2.
   - Validate frontmatter: grep for `^schema_version:` AND `^type: "task-plan"` (or `^type: task-plan`). If either missing, emit `FAIL: invalid task-plan frontmatter` on stderr, exit 3.
   - Extract frontmatter fields (task/phase/milestone) via grep + sed (same pattern as P02 local-agent.sh lines 80-82).
   - Emit the file contents on stdout verbatim (use `cat`). The native adapter is an identity function for native-format input.
6. --write mode:
   - Read stdin; write atomically to `<path>` via mktemp + mv.
   - Validate frontmatter after write; if invalid, remove the file and emit `FAIL: write produced invalid task-plan`, exit 3.
   - Emit `written=<path>`, exit 0.
7. `chmod +x scripts/dispatch/adapters/format/native.sh`.

## Must-Haves

- Script exists, executable, Bash 3.2 compatible.
- `--probe` emits `available=true` / `format=native` and exits 0.
- `--read <valid-task-plan.md>` echoes the file unchanged on stdout.
- `--read <nonexistent>` emits `FAIL:` on stderr, exit 2.
- `--read <file-missing-schema-version>` emits `FAIL:` on stderr, exit 3.
- `--write <path>` round-trips: `--read` of the written path emits identical content to the stdin.

## Verification

```
bash scripts/verify/m008-p05-format-adapter-interface.sh
bash scripts/verify/m008-p05-native-round-trip.sh
```

Expected: `PASS: ...` and exit 0.

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `templates/task-plan.md` — defines the native task-plan shape (YAML frontmatter + body).
- `scripts/dispatch/adapters/backend/local-agent.sh` (from P02) — reference for the grep+sed frontmatter extraction pattern (lines 80-82).

## Constraints

- Bash 3.2 compatible.
- No `jq`/`python3` runtime dependencies.
- `--read` is pure: reads input, emits to stdout, no side effects.
- `--write` is atomic: use mktemp + mv pattern so partial writes do not corrupt the target.

## Expected Output

- `scripts/dispatch/adapters/format/native.sh` exists, executable.
- Both T05 verify scripts pass.
