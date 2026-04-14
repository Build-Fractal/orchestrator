---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P05"
milestone: "M008"
name: "speckit.sh — spec-kit format adapter (one-directional read)"
depends_on: ["T05"]
---

## Prerequisites

- T05 complete: `scripts/dispatch/adapters/format/native.sh` exists and defines the native task-plan shape that speckit.sh maps to.

Target script path: `scripts/dispatch/adapters/format/speckit.sh` (create).

## Description

Create the spec-kit format adapter. Spec-kit's task format is defined by `specs/<feature>/tasks.md` and `specs/<feature>/plan.md`. Both use different shapes from the orchestrator's native task-plan.

This adapter is ONE-DIRECTIONAL READ — it maps spec-kit format INTO the native task-plan format. No `--write` subcommand is implemented. Writing back to spec-kit format is out of scope for M008 per the planning payload.

Interface:
- `--probe` → emits `available=true` if a `specs/` directory exists in the project root, else `available=false` / `reason=no-speckit-specs-directory`.
- `--read <path>` → takes a path to a spec-kit `tasks.md` file and emits a native task-plan on stdout for the first task found. Companion `plan.md` (sibling file) is read for phase/milestone inference.

## Steps

1. Create `scripts/dispatch/adapters/format/speckit.sh` with `#!/usr/bin/env bash` and `set -u`.
2. Parse `--probe | --read <path>`. Reject `--write` explicitly: if `--write` appears in args, emit `FAIL: speckit adapter is one-directional read only` on stderr, exit 4.
3. --probe mode:
   - Check `-d "specs"` (spec-kit convention) or `-d "${PROJECT_ROOT:-.}/specs"`.
   - Emit `available=true|false`, `format=speckit`, `reason=<signal>`. Exit 0.
4. --read mode:
   - Validate `[[ -f "$PATH_ARG" ]]`; else `FAIL: file not found`, exit 2.
   - Parse the first task entry from `tasks.md`. Spec-kit convention: tasks are numbered T## in headings like `## T01: Name` or list items like `- [ ] T01 Name`. Use grep to extract the first match of `T[0-9]+`.
   - Derive `phase` and `milestone` from sibling `plan.md` if present (`dirname "$PATH_ARG"/plan.md`). Fallback: `phase="P01"`, `milestone="M000"` when absent.
   - Emit a native task-plan.md-shaped output on stdout:
     ```
     ---
     schema_version: "1.0"
     type: "task-plan"
     task: "<T##>"
     phase: "<P##>"
     milestone: "<M###>"
     name: "<task name extracted from tasks.md>"
     depends_on: []
     source_format: "speckit"
     source_path: "<absolute path to tasks.md>"
     ---

     ## Description

     <text extracted from the first task's body in tasks.md>
     ```
5. `chmod +x scripts/dispatch/adapters/format/speckit.sh`.

## Must-Haves

- Script exists, executable, Bash 3.2 compatible.
- `--probe` emits `available=`, `format=speckit`, `reason=` key=value and exits 0.
- `--write` rejected with `FAIL:` on stderr, exit 4.
- `--read <tasks.md>` emits a native-shape task-plan with `task:`, `phase:`, `milestone:`, `type: "task-plan"` frontmatter plus `source_format: "speckit"`.
- Output frontmatter is consumable by `scripts/dispatch/adapters/format/native.sh --read` (round-trip through native validator passes).

## Verification

```
bash scripts/verify/m008-p05-format-adapter-interface.sh
bash scripts/verify/m008-p05-speckit-one-directional.sh
```

Expected: `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/format/native.sh` (from T05)
  - Key API: `bash native.sh --read <path>` returns exit 0 when input has `schema_version:` + `type: "task-plan"` frontmatter.
  - Behavioral contract: speckit.sh output MUST pass through native.sh --read without error — this is how we validate the mapping.

### From Disk (Pre-existing)

- `templates/task-plan.md` — target shape.
- `specs/001-speckit-orchestrator/tasks.md` (if present) — reference real-world spec-kit tasks.md structure. Do NOT read or depend on this file in the adapter's normal-mode execution; it may be absent on standalone installs. The adapter works purely from the `--read <path>` argument.

## Constraints

- ONE-DIRECTIONAL READ ONLY: no `--write` handler.
- Bash 3.2 compatible.
- No `jq`/`python3` runtime dependencies.
- Tolerant of missing `plan.md` sibling (fallback values).
- Output MUST validate against native.sh --read so downstream consumers can use either format interchangeably.

## Expected Output

- `scripts/dispatch/adapters/format/speckit.sh` exists, executable.
- `bash speckit.sh --read <tasks.md>` emits a native-shape task-plan document on stdout.
- Both T06 verify scripts pass.
