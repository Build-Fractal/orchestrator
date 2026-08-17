---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M046"
name: "M028 install-path wiring (HOOKS_PAYLOAD + adapter matcher) + install verifier"
depends_on: [T01]
---

## Prerequisites

- T01 complete: `scripts/hooks/unattended-scope-guard.sh` + `scripts/hooks/unattended-protected-surface.txt` exist on disk (this task stages them via the installer).
- `packaging/install/install-claude-code.sh` (exists) — `HOOKS_PAYLOAD` assembled at lines 403–407; hooks staged into `$HOME/.claude/orchestrator-hooks/` at lines 417–431; settings merged at lines 442–474 via `$ADAPTER --hook-config` + `scripts/util/settings-merge.sh`.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (exists) — `--hook-config` heredoc emits the settings.json fragment at lines 198–219; existing `PreToolUse` wrapper `matcher "Bash"` with the shape-guard + before-commit leaves at 208–216.
- `scripts/util/settings-merge.sh` (exists) — `merge`/`uninstall` subcommands; dedup key is `(event, matcher, command)` within `_orchestrator_managed:true` scope, so a NEW wrapper with a DIFFERENT matcher string coexists with the existing `Bash` wrapper.
- `.orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh` (exists) — the throwaway install-matrix this task's verifier productionizes (shapes A + B, isolated HOME, staged/merged/coexists/idempotent/uninstall-clean).

## Description

Wire the T01 hook + manifest into the M028 consumer install path (staged file + one managed
settings-merge fragment — the exact mechanism P01 proved works on both install shapes with no
installer redesign), then author the install verifier.

## Steps

1. **`packaging/install/install-claude-code.sh`** — extend `HOOKS_PAYLOAD` (after line 407) with
   two appends, mirroring the existing lines exactly:
   ```
   HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/hooks/unattended-scope-guard.sh"
   HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/hooks/unattended-protected-surface.txt"
   ```
   No other installer change is needed: the existing loop stages each payload member into
   `$HOME/.claude/orchestrator-hooks/<basename>` and appends it to the MANIFEST. (The manifest
   `.txt` rides the same `cp -f` staging as the `.sh` files — it is a data file the driver reads
   from the staged hooks dir at runtime.)

2. **`scripts/dispatch/adapters/runtime/claude-code.sh`** — inside the `--hook-config` heredoc
   (lines 198–219), add a SECOND `PreToolUse` wrapper object AFTER the existing `matcher: "Bash"`
   wrapper (keep the existing one byte-identical). The `PreToolUse` array becomes two wrappers:
   ```
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "bash ${HOME_HOOKS}/pre-bash-shape-guard.sh", "_orchestrator_managed": true },
             { "type": "command", "command": "bash ${HOME_HOOKS}/before-commit.sh", "_orchestrator_managed": true }
           ]
         },
         {
           "matcher": "Write|Edit|Bash|mcp__.*",
           "hooks": [
             { "type": "command", "command": "bash ${HOME_HOOKS}/unattended-scope-guard.sh", "_orchestrator_managed": true }
           ]
         }
       ]
   ```
   Also extend the event-mapping comment block above the heredoc to name the new
   `unattended_scope_guard -> PreToolUse (matcher: Write|Edit|Bash|mcp__.*; M046/P05 FR-9/FR-20;
   env-gated to ORCHESTRATOR_UNATTENDED)` mapping, and note the two coexisting `PreToolUse`
   wrappers are distinguished by matcher (distinct dedup-key tuples).

3. Author `tools/verify/m046-p05-install-wiring.sh` (project-owned). Productionize
   `run-install-matrix.sh` into a durable verifier that targets the REAL production hook (not the
   probe) and the REAL adapter fragment (not a hand-built fragment). Structure:
   - `set -u`; `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`.
   - `SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046-p05-install.XXXXXX")"`; `trap 'rm -rf "$SCRATCH"' EXIT`.
   - A `run_shape()` function `$1`=label(A|B) `$2`=src-tree-root, mirroring the spike:
     - isolated `HOME="$SCRATCH/home-$1"` (pre-`mkdir -p "$HOME/.claude"`), scratch project dir.
     - Run `HOME="$_home" bash "$_src/packaging/install/install-claude-code.sh" --project-dir "$_proj"`.
     - Assert: `$_home/.claude/orchestrator-hooks/unattended-scope-guard.sh` exists + executable;
       `unattended-protected-surface.txt` exists.
     - Assert the merged `settings.json` contains the guard command
       (`grep -F "bash $_hooks_dir/unattended-scope-guard.sh" "$_settings"`) AND the shape-guard
       command (coexistence) AND the literal matcher string `Write|Edit|Bash|mcp__.*`.
     - Idempotency: re-run the installer; `grep -c '"command"'` leaf count unchanged.
     - Uninstall: `bash "$_src/packaging/install/install-claude-code.sh" --uninstall` (or the
       settings-merge uninstall path the installer uses); assert `grep -c '_orchestrator_managed'
       "$_settings"` == 0 and no guard command remains.
     - Emit `shape=<A|B> staged=<0|1> merged=<0|1> coexists=<0|1> matcher=<0|1> idempotent=<0|1> uninstall_clean=<0|1>`.
   - Shape A: `run_shape A "$REPO_ROOT"`. Shape B: stage `commands scripts references templates
     packaging` + CHANGELOG/VERSION into `$SCRATCH/stage-B`, run
     `$SCRATCH/stage-B/packaging/bundle/build-bundle.sh`, then `run_shape B "$SCRATCH/stage-B"`
     (verbatim from the spike; the production hook rides `cp -R scripts` into the stage tree, so
     no `build-bundle.sh` change is required — P01 shape B proved this).
   - Final `SUMMARY: pass=<p> fail=<f>`; `exit 0` iff both shapes are all-1s.
   - **Self-check (safety)**: assert `HOME` was overridden to the scratch dir before any installer
     run (e.g. verify `$SCRATCH` is a prefix of the `$HOME` used); the real `~/.claude` is never
     touched.

## Must-Haves

- Truth: hook + manifest ride the M028 path; install clean on both shapes; coexist with shape-guard; idempotent; uninstall-clean.
- Artifact: `tools/verify/m046-p05-install-wiring.sh` (min 60 lines, contains "mcp__").
- Key Link: `packaging/install/install-claude-code.sh` → `unattended-scope-guard.sh`.
- Key Link: `scripts/dispatch/adapters/runtime/claude-code.sh` → `unattended-scope-guard.sh`.

## Verification

```bash
bash tools/verify/m046-p05-install-wiring.sh
```

## Inputs

### From Previous Tasks
- `scripts/hooks/unattended-scope-guard.sh` (from T01) — staged by the installer; basename must appear in `HOOKS_PAYLOAD` and the adapter fragment.
- `scripts/hooks/unattended-protected-surface.txt` (from T01) — staged alongside the hook.

### From Disk (Pre-existing)
- `packaging/install/install-claude-code.sh` — `HOOKS_PAYLOAD` (lines 403–407), staging loop, settings-merge invocation, `--uninstall` path (lines 167–216).
- `scripts/dispatch/adapters/runtime/claude-code.sh` — `--hook-config` heredoc (lines 198–219). `HOME_HOOKS="${HOME}/.claude/orchestrator-hooks"`; the fragment carries resolved absolute paths (unquoted heredoc).
- `scripts/util/settings-merge.sh` — `merge`/`uninstall`; `(event, matcher, command)` dedup within managed scope; temp-file-then-rename write.
- `packaging/bundle/build-bundle.sh` — shape-B bundle build (unchanged by this task; hook flows via `cp -R scripts`).
- `.orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh` — the matrix-drive template.

## Constraints

- **Isolated scratch HOME, always** — every installer run in the verifier MUST set
  `HOME="$SCRATCH/..."`; the operator's real `~/.claude` MUST NEVER be touched. Include the
  self-check above.
- Keep the existing `matcher: "Bash"` wrapper byte-identical; ADD the new wrapper, do not merge
  the shape-guard into the new matcher (the shape-guard must keep firing on attended Bash calls).
- Bash 3.2 compatible; no `run-probe.sh` (repo-resident verifier invoked directly).

## Expected Output

`bash tools/verify/m046-p05-install-wiring.sh` prints `shape=A ... all 1s`, `shape=B ... all 1s`,
and `SUMMARY: pass=N fail=0`, exit 0.
