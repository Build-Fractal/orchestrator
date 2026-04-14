---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M008"
goal: "Deliver the first-run onboarding capstone: one init command detects project context, probes capabilities, generates config + a runtime-discoverable project instruction file, and wires the bundle into the active runtime — all in under two minutes."
demo_sentence: "A developer clones any project, runs `bash scripts/lifecycle/init-project.sh --project-dir <dir>` (or the `orchestrator:init` skill from within Claude Code / Codex / Cursor), and within two minutes sees a valid `config.yml`, a runtime-specific instruction file (CLAUDE.md / AGENTS.md / .cursor/rules/orchestrator.md), the 12 orchestrator skills registered into that runtime, and a printed `SUMMARY:` describing how to run the first orchestrated task."
risk: "medium"
depends_on: ["P01", "P05", "P06"]
---

## Must-Haves

### Truths

<!-- Per AD-19, Check commands use single-script-file shape (no inline
     compound bash, no subshells, no $() with pipes, no process subst). -->

- `commands/init.md` exists, follows MEM012 command structure (frontmatter `description:`, numbered workflow sections, "Referenced Scripts/Templates" tail), references `scripts/lifecycle/init-project.sh` and `templates/project-instruction.md`, and documents the `--dry-run` and `--force` flags.
  - Check: `bash scripts/verify/m008-p07-init-command-doc.sh`

- `scripts/lifecycle/detect-project.sh` emits key=value lines to stdout covering at minimum: `language=`, `framework=`, `ci_system=`, `tools_detected=`, `project_type=`. On a fixture project with no markers, it emits `language=unknown framework=none ci_system=none tools_detected= project_type=generic` and exits 0.
  - Check: `bash scripts/verify/m008-p07-detect-project-contract.sh`

- `scripts/lifecycle/detect-project.sh` correctly identifies a Node project (fixture with `package.json`), a Python project (fixture with `pyproject.toml`), a Rust project (fixture with `Cargo.toml`), and detects GitHub Actions CI when `.github/workflows/` is present.
  - Check: `bash scripts/verify/m008-p07-detect-project-matrix.sh`

- `templates/project-instruction.md` exists with required sections ("Project Overview", "Detected Capabilities", "Detected Runtime", "Orchestrator Conventions", "Custom Instructions") and uses `{{placeholder}}` syntax throughout (MEM013). The "Custom Instructions" section is delimited by HTML comment markers (`<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->`) that the reinit handler preserves.
  - Check: `bash scripts/verify/m008-p07-project-instruction-template.sh`

- `scripts/lifecycle/init-project.sh` supports `--project-dir PATH`, `--dry-run`, `--force`, and `--runtime <claude-code|codex|cursor|auto>`. Default runtime is `auto` (delegates to `detect-runtime.sh`). Exit codes: 0 success, 1 generic failure, 2 unsafe env (empty `$HOME` for claude-code/codex), 3 runtime not available, 4 already initialized (delegates to `reinit-handler.sh`).
  - Check: `bash scripts/verify/m008-p07-init-interface.sh`

- `scripts/lifecycle/init-project.sh --dry-run` against a hermetic `mktemp -d` project emits `would_write=<path>` lines for the config file, the instruction file, and the skill install targets, and a final `SUMMARY:` line with `project_type=`, `runtime=`, `instruction_file=`, `config_file=`, and `next_step=`. No files are written.
  - Check: `bash scripts/verify/m008-p07-init-dry-run-hermetic.sh`

- `scripts/lifecycle/init-project.sh` run without `--dry-run` against a hermetic project + hermetic HOME produces: (a) `<state_root>/config.yml` with `schema_version:`, `state_root:`, `runtime:`, `capabilities:`, and `initialized_at:` fields; (b) a runtime-specific instruction file at the correct path; (c) skills registered under the hermetic HOME via the P06 installer. A final `SUMMARY:` line is printed.
  - Check: `bash scripts/verify/m008-p07-init-e2e-hermetic.sh`

- The generated instruction file path matches the active runtime: Claude Code writes `<project-dir>/CLAUDE.md`, Codex writes `<project-dir>/AGENTS.md`, Cursor writes `<project-dir>/.cursor/rules/orchestrator.md`.
  - Check: `bash scripts/verify/m008-p07-instruction-file-routing.sh`

- `scripts/lifecycle/reinit-handler.sh` supports modes `update` (default), `reset`, and `abort`. Given an existing `<state_root>/config.yml` and an existing instruction file with custom content between `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` markers, `update` mode preserves the custom block verbatim while refreshing auto-filled sections and merges new capability detections into the config (preserving user-edited top-level fields). `reset` overwrites both. `abort` exits 0 with no changes.
  - Check: `bash scripts/verify/m008-p07-reinit-preserves-custom.sh`

- When `scripts/lifecycle/init-project.sh` is invoked against an already-configured project without `--force`, it detects the existing config and delegates to `reinit-handler.sh`, which prints a prompt line (`REINIT:`) and exits 4 in non-interactive mode. With `--force`, it proceeds as a full overwrite.
  - Check: `bash scripts/verify/m008-p07-reinit-delegation.sh`

- All init and reinit integration tests are hermetic — every test uses `HOME=$(mktemp -d)` and `--project-dir $(mktemp -d)` fixtures. No init script invocation during P07 execution writes to the real developer HOME or the real spec-kit-orchestrator repo.
  - Check: `bash scripts/verify/m008-p07-hermetic-only.sh`

- All P07 shell scripts are Bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no `${var,,}`), excluding comment lines from the scan (MEM001).
  - Check: `bash scripts/verify/m008-p07-bash32-compat.sh`

- End-to-end onboarding: fresh hermetic project with no config → `init-project.sh` → verify config, instruction file, skills present → rerun `init-project.sh` (no flag) → verify reinit preserves custom block → rerun with `--force` → verify reset behavior. Wall-clock duration under 120 seconds on the test harness.
  - Check: `bash scripts/verify/m008-p07-integration-e2e.sh`

### Artifacts

- commands/init.md (min 60 lines, contains "orchestrator:init")
- scripts/lifecycle/detect-project.sh (min 60 lines, contains "language=")
- scripts/lifecycle/init-project.sh (min 80 lines, contains "--dry-run")
- scripts/lifecycle/reinit-handler.sh (min 50 lines, contains "BEGIN CUSTOM")
- templates/project-instruction.md (min 40 lines, contains "{{project_type}}")
- scripts/verify/m008-p07-integration-e2e.sh (min 40 lines, contains "SUMMARY:")

### Key Links

- commands/init.md → scripts/lifecycle/init-project.sh (command doc references the entry-point script in Referenced Scripts section)
- commands/init.md → templates/project-instruction.md (command doc references the instruction file template)
- scripts/lifecycle/init-project.sh → scripts/lifecycle/detect-project.sh (init invokes project detection)
- scripts/lifecycle/init-project.sh → scripts/dispatch/detect-capabilities.sh (init invokes capability probe with --profile)
- scripts/lifecycle/init-project.sh → scripts/dispatch/detect-runtime.sh (init invokes runtime detection when --runtime auto)
- scripts/lifecycle/init-project.sh → scripts/state/resolve-root.sh (init resolves state root before writing config)
- scripts/lifecycle/init-project.sh → scripts/lifecycle/reinit-handler.sh (init delegates to reinit when existing config detected)
- scripts/lifecycle/init-project.sh → packaging/install/install-claude-code.sh (init invokes the matching installer for skill registration)
- scripts/lifecycle/reinit-handler.sh → templates/project-instruction.md (reinit references the template when refreshing auto-filled sections)

## Tasks

### T01: detect-project.sh — language/framework/CI/tools detection

See `tasks/T01-PLAN.md`.

### T02: project-instruction.md template + commands/init.md command doc

See `tasks/T02-PLAN.md`.

### T03: init-project.sh — top-level init entry point

See `tasks/T03-PLAN.md`.

### T04: reinit-handler.sh — update/reset/abort with custom-block preservation

See `tasks/T04-PLAN.md`.

### T05: Bash 3.2 compat + hermetic integration e2e

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ─┐
     ├─► T03 ─► T04 ─► T05
T02 ─┘
```

- T01 produces `scripts/lifecycle/detect-project.sh` (leaf — no prior-task inputs).
- T02 produces `templates/project-instruction.md` and `commands/init.md` (leaf — no prior-task inputs).
- T03 consumes T01 (detect-project) + T02 (instruction template) + P01 capability probe + P05 runtime detection + P06 installers to produce `scripts/lifecycle/init-project.sh`.
- T04 consumes T03's init output surface (config format, instruction file format) to produce `scripts/lifecycle/reinit-handler.sh`.
- T05 is the final gate: Bash 3.2 compat scan across all P07 scripts + hermetic end-to-end integration test (fresh init → rerun preserves context → --force resets).

T01 and T02 can run in parallel; T03 waits for both. T04 depends on T03 (reads the config/instruction shapes T03 emits). T05 depends on everything.

## Files Likely Touched

- commands/init.md (create)
- templates/project-instruction.md (create)
- scripts/lifecycle/detect-project.sh (create)
- scripts/lifecycle/init-project.sh (create)
- scripts/lifecycle/reinit-handler.sh (create)
- scripts/verify/m008-p07-init-command-doc.sh (create)
- scripts/verify/m008-p07-detect-project-contract.sh (create)
- scripts/verify/m008-p07-detect-project-matrix.sh (create)
- scripts/verify/m008-p07-project-instruction-template.sh (create)
- scripts/verify/m008-p07-init-interface.sh (create)
- scripts/verify/m008-p07-init-dry-run-hermetic.sh (create)
- scripts/verify/m008-p07-init-e2e-hermetic.sh (create)
- scripts/verify/m008-p07-instruction-file-routing.sh (create)
- scripts/verify/m008-p07-reinit-preserves-custom.sh (create)
- scripts/verify/m008-p07-reinit-delegation.sh (create)
- scripts/verify/m008-p07-hermetic-only.sh (create)
- scripts/verify/m008-p07-bash32-compat.sh (create)
- scripts/verify/m008-p07-integration-e2e.sh (create)
