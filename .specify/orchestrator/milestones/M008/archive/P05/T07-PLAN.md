---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P05"
milestone: "M008"
name: "Bash 3.2 compat + integration e2e test"
depends_on: ["T01", "T02", "T03", "T04", "T05", "T06"]
---

## Prerequisites

All of T01–T06 complete:
- `scripts/dispatch/detect-runtime.sh`
- `scripts/dispatch/adapters/runtime/claude-code.sh`
- `scripts/dispatch/adapters/runtime/codex.sh`
- `scripts/dispatch/adapters/runtime/cursor.sh`
- `scripts/dispatch/adapters/format/native.sh`
- `scripts/dispatch/adapters/format/speckit.sh`

Target scripts to create:
- `scripts/verify/m008-p05-bash32-compat.sh`
- `scripts/verify/m008-p05-integration-e2e.sh`
- `scripts/verify/m008-p05-runtime-filename-discovery.sh`
- `scripts/verify/m008-p05-no-real-home-writes.sh`

## Description

Two orthogonal gates:

1. **Bash 3.2 compat scan** — verifies every script created in P05 is Bash 3.2 compatible (no `declare -A`, no `readarray`/`mapfile`, no `|&`). Copy the pattern from `scripts/verify/m008-p02-bash32-compat.sh`.

2. **Integration e2e** — exercises the full P05 pipeline in a hermetic environment:
   - Create `HOME=$(mktemp -d)` and `PROJECT_DIR=$(mktemp -d)` fixtures.
   - Run `detect-runtime.sh --force claude-code` and assert it emits `runtime=claude-code`.
   - Run `claude-code.sh --probe`, `codex.sh --probe`, `cursor.sh --probe` — each exits 0 with valid key=value output.
   - Run `claude-code.sh --register --dry-run` — assert it emits `would_write=` lines without writing.
   - Run `claude-code.sh --register` with hermetic HOME — assert `$HOME/.claude/commands/orchestrator-*.md` files are created.
   - Build a minimal native task-plan fixture; run `native.sh --read` on it — assert exit 0 and output contains `task:`.
   - Build a minimal spec-kit `tasks.md` fixture; run `speckit.sh --read` on it; pipe the output to `native.sh --read` via a tempfile (no process substitution per AD-19) — assert round-trip passes.
   - Finally, build a dispatch-ready payload + task-plan and feed to `scripts/dispatch/dispatch-interface.sh` from P02 (using `--backend local-agent` since that adapter always succeeds per P02 summary) — assert exit 0 and valid dispatch-result frontmatter.
   - Cleanup fixtures with `rm -rf` on the mktemp roots.

Plus two additional gates:

3. **Filename-discovery** — verifies `scripts/dispatch/adapters/runtime/` contains exactly the three expected adapter files, and that there is no central registry file listing them (mirrors P02's filename-discovery pattern).

4. **No-real-HOME-writes** — verifies that grepping P05 scripts does not find any literal `"$HOME/.claude"` or `"$HOME/.codex"` or `"$HOME/.cursor"` write paths OUTSIDE of the adapter scripts themselves (i.e., no P05 orchestrator code writes to the real developer HOME; only the adapters do, and only when `--register` is invoked with a hermetic fixture).

## Steps

1. Create `scripts/verify/m008-p05-bash32-compat.sh`. List the 6 P05 scripts in a bash-array. For each: grep for forbidden patterns (`^[[:space:]]*declare[[:space:]]+-A`, `^[[:space:]]*(readarray|mapfile)[[:space:]]`, `[^|]\|&[^|]`). Exit 1 on any hit. Final: `echo "PASS: all P05 scripts are Bash 3.2 compatible"`.

2. Create `scripts/verify/m008-p05-integration-e2e.sh`. Use `set -eu` + trap-based cleanup:
   ```
   tmpdir=$(mktemp -d)
   trap 'rm -rf "$tmpdir"' EXIT
   export HOME="$tmpdir/home"
   mkdir -p "$HOME"
   ```
   Sequentially invoke each script listed in the Description. Use simple if-statements (not process substitution) to assert expected output. After each assertion, print a `STEP: <n> PASS` line. Final `PASS: integration e2e`.

3. Create `scripts/verify/m008-p05-runtime-filename-discovery.sh`:
   - List `scripts/dispatch/adapters/runtime/*.sh` and assert exactly 3 files: claude-code.sh, codex.sh, cursor.sh.
   - Grep the repo for any literal `runtime-registry.yml` or `runtime-list.json` — must return nothing.

4. Create `scripts/verify/m008-p05-no-real-home-writes.sh`:
   - Grep P05 non-adapter files for `"\$HOME/\.claude"`, `"\$HOME/\.codex"` — must return nothing outside `scripts/dispatch/adapters/runtime/`.

5. `chmod +x` all four verify scripts.

## Must-Haves

- `scripts/verify/m008-p05-bash32-compat.sh` passes.
- `scripts/verify/m008-p05-integration-e2e.sh` passes.
- `scripts/verify/m008-p05-runtime-filename-discovery.sh` passes.
- `scripts/verify/m008-p05-no-real-home-writes.sh` passes.
- No write to the real `$HOME` occurs during any verification run.

## Verification

```
bash scripts/verify/m008-p05-bash32-compat.sh
bash scripts/verify/m008-p05-integration-e2e.sh
bash scripts/verify/m008-p05-runtime-filename-discovery.sh
bash scripts/verify/m008-p05-no-real-home-writes.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P05
```

Expected: `PASS: ...` and exit 0 for each.

## Inputs

### From Previous Tasks

- `scripts/dispatch/detect-runtime.sh` (T01)
  - Key API: emits `runtime=` / `confidence=` on stdout, exits 0.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (T02)
  - Key API: `--probe | --register [--dry-run] | --hook-config`.
- `scripts/dispatch/adapters/runtime/codex.sh` (T03)
  - Key API: `--probe | --register [--dry-run] | --hook-config`.
- `scripts/dispatch/adapters/runtime/cursor.sh` (T04)
  - Key API: `--probe | --register [--dry-run] --project-dir <path> | --hook-config`.
- `scripts/dispatch/adapters/format/native.sh` (T05)
  - Key API: `--probe | --read <path> | --write <path>`; `--read` returns exit 0 with valid native frontmatter.
- `scripts/dispatch/adapters/format/speckit.sh` (T06)
  - Key API: `--probe | --read <path>`; emits native-shape output that round-trips through native.sh --read.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` (P02) — called in integration test with `--backend local-agent`.
- `scripts/verify/m008-p02-bash32-compat.sh` — reference for the compat scan pattern.
- `scripts/verify/check-must-haves.sh` — phase-level verification entry point.

## Constraints

- AD-19 compliance: all `Check:` invocations are single-script-file shape. Do NOT use process substitution `<(...)`, command substitution with pipes `$(cmd | ...)`, or compound `bash -c '...' && bash -c '...'` in verify scripts. Use sequential statements and tempfiles instead.
- All integration fixtures are `mktemp -d`; cleanup via `trap`.
- NEVER invoke adapter `--register` against the real HOME during verification.
- Bash 3.2 compatible.

## Expected Output

- All four new verify scripts exist and are executable.
- Running the full verify sequence for P05 emits `PASS:` lines and exits 0.
- `scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P05` reports all must-haves satisfied.
