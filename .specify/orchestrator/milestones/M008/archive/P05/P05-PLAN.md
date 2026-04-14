---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M008"
goal: "The same orchestrator command produces equivalent state files and artifacts whether invoked from Claude Code, Codex CLI, or Cursor, and the runtime is auto-detected without developer configuration."
demo_sentence: "A developer runs the same orchestrator workflow on Claude Code, Codex CLI, and Cursor; each runtime is auto-detected, the appropriate runtime adapter registers skill files into a hermetic HOME fixture, and a format adapter round-trips task payloads through the dispatch interface from P02 and the resolved state root from P04."
risk: "medium"
depends_on: [P02, P04]
---

## Must-Haves

### Truths

<!-- All Truth Check commands use single-script-file shape per AD-19. Each
     m008-p05-*.sh script under scripts/verify/ runs hermetically: it
     builds mktemp fixtures for HOME, never touches the real developer
     home, and exits 0 on pass / 1 on fail with PASS:/FAIL: prefixes per
     MEM001. -->

- detect-runtime.sh emits runtime= and confidence= key=value lines and never exits non-zero on unknown runtime.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-output-shape.sh`
- detect-runtime.sh probes CLAUDECODE env, CURSOR_* env, CODEX_* env, and filesystem markers (.claude/, .cursor/, .codex/, ~/.claude, ~/.cursor, ~/.codex), and reports confidence=high when env and filesystem agree.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-signal-coverage.sh`
- detect-runtime.sh returns runtime=unknown with confidence=low when no signals match, with exit code 0.
  - Check: `bash scripts/verify/m008-p05-detect-runtime-unknown-path.sh`
- Every runtime adapter (claude-code.sh, codex.sh, cursor.sh) supports three modes: --probe, --register [--dry-run], --hook-config, and emits PASS:/FAIL:/registered=true|false key=value lines on stdout.
  - Check: `bash scripts/verify/m008-p05-runtime-adapter-interface.sh`
- Every runtime adapter --register --dry-run emits the list of files it WOULD write to stdout with one `would_write=<path>` line per file and writes nothing to disk.
  - Check: `bash scripts/verify/m008-p05-runtime-adapter-dry-run.sh`
- Runtime adapter --register (non-dry-run) refuses to write if HOME is unset or points to `/` (defensive hardening against accidental root-directory writes).
  - Check: `bash scripts/verify/m008-p05-runtime-adapter-home-guard.sh`
- claude-code.sh --register writes orchestrator-<cmd>.md files into $HOME/.claude/commands/ for each command in the commands/ directory, in a hermetic HOME=$(mktemp -d) fixture.
  - Check: `bash scripts/verify/m008-p05-claude-code-register-hermetic.sh`
- codex.sh --register writes orchestrator-<cmd>.md skill files into $HOME/.codex/skills/ for each command, in a hermetic HOME fixture.
  - Check: `bash scripts/verify/m008-p05-codex-register-hermetic.sh`
- cursor.sh --register writes orchestrator-<cmd>.md rule files into .cursor/rules/ (project-local, not HOME), in a hermetic tmp-project fixture.
  - Check: `bash scripts/verify/m008-p05-cursor-register-hermetic.sh`
- Format adapters (native.sh, speckit.sh) support --probe and --read <path> and emit a native task-plan on stdout with YAML frontmatter fields task/phase/milestone.
  - Check: `bash scripts/verify/m008-p05-format-adapter-interface.sh`
- native.sh --read round-trips a templates/task-plan.md-shaped file: the output's task/phase/milestone frontmatter equals the input's.
  - Check: `bash scripts/verify/m008-p05-native-round-trip.sh`
- speckit.sh --read maps a spec-kit tasks.md + plan.md pair to native task-plan format; output contains task: T## and phase: P## frontmatter derived from the spec-kit source, and no --write subcommand is advertised (one-directional read per plan).
  - Check: `bash scripts/verify/m008-p05-speckit-one-directional.sh`
- Runtime adapter auto-discovery mirrors backend-registry pattern: any file under scripts/dispatch/adapters/runtime/*.sh is a registered runtime with zero central-registry edits.
  - Check: `bash scripts/verify/m008-p05-runtime-filename-discovery.sh`
- P05 adapter scripts do NOT invoke --register against the real HOME during P05 execution or verification — the only write paths are inside mktemp fixtures.
  - Check: `bash scripts/verify/m008-p05-no-real-home-writes.sh`
- All P05 scripts are Bash 3.2 compatible (no declare -A, readarray/mapfile, or `|&`).
  - Check: `bash scripts/verify/m008-p05-bash32-compat.sh`
- Integration test: auto-detect -> select runtime adapter -> register into hermetic HOME -> format adapter reads native + speckit sources -> dispatch-interface.sh from P02 accepts the produced payload, in a single end-to-end run under mktemp fixtures.
  - Check: `bash scripts/verify/m008-p05-integration-e2e.sh`

### Artifacts

- scripts/dispatch/detect-runtime.sh (min 60 lines, contains "runtime=")
- scripts/dispatch/adapters/runtime/claude-code.sh (min 80 lines, contains "--register")
- scripts/dispatch/adapters/runtime/codex.sh (min 80 lines, contains "--register")
- scripts/dispatch/adapters/runtime/cursor.sh (min 60 lines, contains "--register")
- scripts/dispatch/adapters/format/native.sh (min 60 lines, contains "--read")
- scripts/dispatch/adapters/format/speckit.sh (min 60 lines, contains "--read")
- scripts/verify/m008-p05-integration-e2e.sh (min 40 lines, contains "mktemp")

### Key Links

- scripts/dispatch/detect-runtime.sh -> scripts/dispatch/adapters/runtime (detect-runtime references the runtime adapters directory for filename-based discovery)
- scripts/dispatch/adapters/runtime/claude-code.sh -> scripts/state/resolve-root.sh (runtime adapter consults resolve-root.sh from P04 to map to canonical state location)
- scripts/dispatch/adapters/runtime/codex.sh -> scripts/state/resolve-root.sh
- scripts/dispatch/adapters/format/native.sh -> templates/task-plan.md (native format adapter reads/produces the native task-plan template shape)
- scripts/dispatch/adapters/format/speckit.sh -> templates/task-plan.md (speckit reader maps to native shape)
- scripts/verify/m008-p05-integration-e2e.sh -> scripts/dispatch/dispatch-interface.sh (integration test feeds produced payload through the P02 dispatch interface)

## Tasks

### T01: detect-runtime.sh (auto-detection)

See tasks/T01-PLAN.md.

### T02: claude-code.sh runtime adapter

See tasks/T02-PLAN.md.

### T03: codex.sh runtime adapter

See tasks/T03-PLAN.md.

### T04: cursor.sh runtime adapter (best-effort)

See tasks/T04-PLAN.md.

### T05: native.sh format adapter

See tasks/T05-PLAN.md.

### T06: speckit.sh format adapter (one-directional read)

See tasks/T06-PLAN.md.

### T07: Bash 3.2 compat + integration test

See tasks/T07-PLAN.md.

## Task Dependencies

```
T01 (detect-runtime)
 |
 +--> T02 (claude-code adapter) -----+
 |                                   |
 +--> T03 (codex adapter) -----------+
 |                                   |
 +--> T04 (cursor adapter) ----------+
                                     |
T05 (native format) -----------------+
                                     |
T06 (speckit format, depends on T05) +
                                     |
                                     v
                                    T07 (compat + integration e2e)
```

T01 is independent. T02/T03/T04 each depend on T01. T05 is independent. T06 depends on T05 (shares native format shape). T07 depends on everything — it is the integration gate.

## Files Likely Touched

- scripts/dispatch/detect-runtime.sh (create)
- scripts/dispatch/adapters/runtime/claude-code.sh (create)
- scripts/dispatch/adapters/runtime/codex.sh (create)
- scripts/dispatch/adapters/runtime/cursor.sh (create)
- scripts/dispatch/adapters/format/native.sh (create)
- scripts/dispatch/adapters/format/speckit.sh (create)
- scripts/verify/m008-p05-detect-runtime-output-shape.sh (create)
- scripts/verify/m008-p05-detect-runtime-signal-coverage.sh (create)
- scripts/verify/m008-p05-detect-runtime-unknown-path.sh (create)
- scripts/verify/m008-p05-runtime-adapter-interface.sh (create)
- scripts/verify/m008-p05-runtime-adapter-dry-run.sh (create)
- scripts/verify/m008-p05-runtime-adapter-home-guard.sh (create)
- scripts/verify/m008-p05-claude-code-register-hermetic.sh (create)
- scripts/verify/m008-p05-codex-register-hermetic.sh (create)
- scripts/verify/m008-p05-cursor-register-hermetic.sh (create)
- scripts/verify/m008-p05-format-adapter-interface.sh (create)
- scripts/verify/m008-p05-native-round-trip.sh (create)
- scripts/verify/m008-p05-speckit-one-directional.sh (create)
- scripts/verify/m008-p05-runtime-filename-discovery.sh (create)
- scripts/verify/m008-p05-no-real-home-writes.sh (create)
- scripts/verify/m008-p05-bash32-compat.sh (create)
- scripts/verify/m008-p05-integration-e2e.sh (create)
