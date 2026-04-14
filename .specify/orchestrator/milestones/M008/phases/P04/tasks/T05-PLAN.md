---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M008"
name: "Refactor scripts/state/derive-phase.sh + create scripts/state/namespace-aliases.sh"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete — `scripts/state/resolve-root.sh` exists and emits a path to stdout.
- Bash 3.2+ available.
- The existing `scripts/state/derive-phase.sh` file is present (current implementation hardcodes no root — it takes an explicit `<milestone-dir>` positional argument — but references to `.specify/orchestrator` paths inside comments and fallback logic must be reviewed).

## Description

Two deliverables in one task because they are both surgical and small:

**(A) Refactor `scripts/state/derive-phase.sh`** — the current script already takes an explicit `<milestone-dir>` argument and does not hardcode `.specify/orchestrator/` in its resolution logic. However, comments and any fallback path that assumes `.specify/orchestrator/` layout must be updated to:

1. Reference `resolve-root.sh` as the canonical way callers should construct the milestone directory path (documentation only — the public interface is unchanged).
2. Add a NOTE comment block explaining the root convention.
3. If (and only if) any internal line currently contains a literal `.specify/orchestrator` path as a default or fallback, replace it with a call to `bash "$SCRIPT_DIR/resolve-root.sh"`.

The surgical principle (Constitution XV): the public interface — a single positional argument pointing at a milestone directory — MUST NOT change. All existing callers in `commands/`, `scripts/`, and `tests/` pass that argument explicitly and must continue to work.

**(B) Create `scripts/state/namespace-aliases.sh`** — emits a human-readable mapping table of `speckit.orchestrator.<cmd>` -> `orchestrator:<cmd>` for every command in the `commands/` directory. The output is a reference document, not a runtime router. Runtime adapters (P05) register commands under the new namespace directly; this script generates documentation that users can consult when their muscle memory says `speckit.orchestrator.auto`.

## Steps

### Step 1 — Read the current derive-phase.sh

```bash
cat scripts/state/derive-phase.sh
```

Identify any line containing the literal string `.specify/orchestrator` AND any fallback default that assumes a spec-kit-era layout. Note: in the current implementation (reviewed at planning time), the script takes `$1` as the milestone directory and does not itself contain hardcoded root defaults — the refactor may be purely a documentation addition.

### Step 2 — Refactor scripts/state/derive-phase.sh

Apply ONLY the following two edits:

**Edit A: Add a NOTE comment block** after the existing `# DESIGN NOTE: ...` block and before `set -euo pipefail`. Insert:

```bash
# ROOT RESOLUTION (P04/M008): Callers pass an explicit <milestone-dir>
# positional argument. The conventional way to construct that path is:
#   root="$(bash scripts/state/resolve-root.sh)"
#   milestone_dir="$root/milestones/M###"
# This script does NOT resolve the root itself — it accepts whatever
# directory the caller provides. See scripts/state/resolve-root.sh for
# the authoritative precedence chain (env var, config, existing dir,
# default).
```

**Edit B:** If `grep -n '\.specify/orchestrator' scripts/state/derive-phase.sh` returns any non-comment lines with that literal, replace each with a reference to `resolve-root.sh`. (At planning time, grep returns no such non-comment lines — the current script is root-agnostic at the code level — so this edit is likely a no-op. Do the grep; if empty, skip.)

DO NOT:

- Change the positional-argument interface.
- Add any new required arguments.
- Remove any existing behavior.
- Change the exit codes or stdout shape.

### Step 3 — Create scripts/state/namespace-aliases.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# scripts/state/namespace-aliases.sh — Generate the
# speckit.orchestrator.* -> orchestrator:* mapping table.
#
# Scans the commands/ directory for command files, derives the short
# command name from each filename, and emits both the legacy
# speckit.orchestrator.<name> form and the new orchestrator:<name> form.
#
# This is a documentation tool. Runtime adapters (P05) register commands
# under the new namespace directly; this script does not route at
# runtime.
#
# Usage:
#   namespace-aliases.sh                 -> emit two-column mapping to stdout
#   namespace-aliases.sh --markdown      -> emit a markdown table
#
# Exit: 0 on success, 1 if commands/ is absent.
# Bash 3.2 compatible.

set -u

MARKDOWN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown) MARKDOWN=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# Locate repo root
repo_root="$PWD"
while [[ "$repo_root" != "/" ]]; do
  if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
    break
  fi
  repo_root="$(dirname "$repo_root")"
done

cmd_dir="$repo_root/commands"
if [[ ! -d "$cmd_dir" ]]; then
  echo "ERROR: commands directory not found at $cmd_dir" >&2
  exit 1
fi

if [[ "$MARKDOWN" = "1" ]]; then
  echo "| Legacy namespace | New namespace |"
  echo "| --- | --- |"
fi

for cmd_file in "$cmd_dir"/*.md; do
  [[ -f "$cmd_file" ]] || continue
  base="$(basename "$cmd_file" .md)"
  # Skip README-style files
  case "$base" in
    README|AGENTS) continue ;;
  esac
  if [[ "$MARKDOWN" = "1" ]]; then
    echo "| \`speckit.orchestrator.$base\` | \`orchestrator:$base\` |"
  else
    echo "speckit.orchestrator.$base -> orchestrator:$base"
  fi
done
```

### Step 4 — Make the script executable

```bash
chmod +x scripts/state/namespace-aliases.sh
```

### Step 5 — Smoke test

```bash
bash scripts/state/namespace-aliases.sh | head -5
```

Expected output: lines like `speckit.orchestrator.auto -> orchestrator:auto`, one per command file.

## Must-Haves

This task addresses:

- `scripts/state/derive-phase.sh` no longer contains a hardcoded reference to `.specify/orchestrator` as its internal default, and uses `resolve-root.sh` for root resolution (documented via comment).
- `scripts/state/derive-phase.sh` still accepts an explicit milestone-dir positional argument unchanged.
- `scripts/state/namespace-aliases.sh` emits a complete `speckit.orchestrator.* -> orchestrator:*` mapping covering every command.

## Verification

Run:

- `bash scripts/verify/m008-p04-derive-phase-no-hardcode.sh`
- `bash scripts/verify/m008-p04-derive-phase-interface.sh`
- `bash scripts/verify/m008-p04-namespace-aliases-complete.sh`

Each must exit 0 with a `PASS:` line.

## Inputs

### From Previous Tasks

- `scripts/state/resolve-root.sh` (from T01)
  - Key API: `bash resolve-root.sh [--absolute]` — emits resolved root to stdout.
  - Used here: only in the NOTE comment block of derive-phase.sh as documentation. No functional call.

### From Disk (Pre-existing)

- `scripts/state/derive-phase.sh` — the existing file. Surgical refactor target.
- `commands/` — directory containing all command .md files. namespace-aliases.sh scans it.

## Constraints

- Bash 3.2 compatible.
- derive-phase.sh MUST retain its current public interface: one positional argument = milestone directory. Every existing caller in `commands/` and `scripts/` continues to work.
- derive-phase.sh MUST retain its current state-derivation semantics (the 9 state rules). No behavioral change.
- namespace-aliases.sh MUST skip README.md and AGENTS.md in the commands/ directory (per MEM008 — these are doc files, not commands).
- namespace-aliases.sh outputs deterministic order (filesystem glob order is acceptable — commands are named uniquely).

## Expected Output

Modifying:

- `scripts/state/derive-phase.sh` — add a NOTE comment block (~9 lines). No interface change. Line count goes from ~204 to ~213.

Creating:

- `scripts/state/namespace-aliases.sh` — ~50 lines, executable.

Sample run of `bash scripts/state/namespace-aliases.sh`:

```
speckit.orchestrator.auto -> orchestrator:auto
speckit.orchestrator.consolidate -> orchestrator:consolidate
speckit.orchestrator.discuss -> orchestrator:discuss
speckit.orchestrator.dispatch -> orchestrator:dispatch
speckit.orchestrator.evaluate -> orchestrator:evaluate
speckit.orchestrator.plan-phase -> orchestrator:plan-phase
speckit.orchestrator.resume -> orchestrator:resume
speckit.orchestrator.roadmap -> orchestrator:roadmap
speckit.orchestrator.status -> orchestrator:status
speckit.orchestrator.verify -> orchestrator:verify
```

Running `bash scripts/state/derive-phase.sh .specify/orchestrator/milestones/M008` after the refactor still emits a single state word (e.g. `executing`), identical to pre-refactor behavior.
