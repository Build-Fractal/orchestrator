---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M008"
goal: "Define a uniform dispatch interface and ship two local backend adapters (Claude Code Agent tool, Codex CLI SDK) with auto-discovery registration"
demo_sentence: "A task dispatched through the orchestrator returns a structured result with completion status and artifacts, regardless of whether it executed via Claude Code's Agent tool or Codex CLI's SDK."
risk: "high"
depends_on: []
---

<!--
  P02 -- Dispatch Interface & Backend Adapters
  =============================================

  Context: the existing dispatch flow uses build-context.sh to assemble a
  payload and the orchestrating agent invokes the Agent tool directly. That
  couples the orchestrator core to a specific runtime. P02 establishes a
  uniform dispatch interface so the orchestrator becomes backend-agnostic,
  enabling: (a) parity across Claude Code and Codex CLI (FR-010, SC-002),
  (b) zero-core-edit registration of new backends (FR-011, SC-003), and
  (c) a stable seam for future cloud backends (Managed Agents, M010).

  Architectural decisions:
    - Adapters are self-describing via a --probe sub-command that answers
      "am I available in this environment?" with available=true|false. This
      avoids a central registry file and satisfies FR-011 (auto-discovery).
    - The dispatch interface is a thin router: resolve backend (via
      registry or explicit --backend), invoke adapter as a subprocess,
      emit the adapter's output unchanged on success, emit a structured
      dispatch-error on failure.
    - The local-agent adapter honors MEM018: the real Agent tool runs
      inside the orchestrating agent's runtime (in-process, not invokable
      from shell). The adapter is therefore a COORDINATION BOUNDARY -- its
      normal-mode output is a dispatch-result that the orchestrating agent
      interprets as "invoke the Agent tool now with this payload." The
      interface parity is preserved; the invocation happens at the agent
      layer, consistent with how v0.1.0's dispatch-prompt.md works.
    - The local-codex adapter invokes the `codex` CLI as a subprocess when
      available. Exact CLI flags TBD -- a placeholder invocation is wired
      with a clear TODO for runtime validation. Probe mode checks PATH.
    - Schema parity: both adapters emit results conforming to
      dispatch-result.md; both emit errors conforming to dispatch-error.md.
      Core orchestrator code consumes only these two schemas, never
      backend-specific formats (FR-009, FR-012).

  Key design choices:
    - Subprocess invocation boundary (not source/dot-include) -- each
      adapter is a standalone script with its own process. This isolates
      backend failures and prevents scope leakage.
    - Structured key=value probe output (same convention as
      detect-capabilities.sh --profile from P01).
    - dispatch-result.md and dispatch-error.md are separate schemas --
      success and failure have different shapes and different consumers.
    - No central registry file; the registry script scans
      scripts/dispatch/adapters/backend/*.sh and probes each. Adding a new
      backend = dropping a new file. Zero core edits (SC-003).

  Cross-phase dependencies:
    - P03 (namespace independence): dispatch interface must work under any
      state directory root. No hardcoded .specify/ paths in the interface
      or adapters.
    - P05/M010 (cloud dispatch): the interface seam is frozen here. The
      Managed Agents adapter will be dropped in as a new file in
      adapters/backend/ without touching dispatch-interface.sh.
    - Wave 1 independent -- no upstream phase dependencies.
-->

## Must-Haves

### Truths

- templates/dispatch-result.md defines the success result schema with YAML frontmatter (schema_version, type, status, backend, dispatched_at, completed_at, duration_s) and body sections for summary and artifacts.
  - Check: `bash scripts/verify/m008-p02-result-template.sh`
- templates/dispatch-error.md defines the failure error schema with YAML frontmatter (schema_version, type, error_type, retry_eligible, escalation, occurred_at, backend) and body sections for error message, context, and suggested action.
  - Check: `bash scripts/verify/m008-p02-error-template.sh`
- scripts/dispatch/backend-registry.sh discovers adapters in scripts/dispatch/adapters/backend/*.sh and probes each to determine availability, outputting key=value pairs (backends_available, default_backend).
  - Check: `bash scripts/verify/m008-p02-registry-discovery.sh`
- scripts/dispatch/adapters/backend/local-agent.sh supports --probe and emits available=true|false key=value output.
  - Check: `bash scripts/verify/m008-p02-local-agent-probe.sh`
- scripts/dispatch/adapters/backend/local-agent.sh in normal mode emits a dispatch-result.md conforming document with backend=local-agent.
  - Check: `bash scripts/verify/m008-p02-local-agent-result.sh`
- scripts/dispatch/adapters/backend/local-codex.sh supports --probe and checks whether the `codex` binary is on PATH.
  - Check: `bash scripts/verify/m008-p02-local-codex-probe.sh`
- scripts/dispatch/adapters/backend/local-codex.sh in normal mode wires a subprocess invocation of the `codex` CLI and emits a dispatch-result.md conforming document with backend=local-codex.
  - Check: `bash scripts/verify/m008-p02-local-codex-result.sh`
- scripts/dispatch/dispatch-interface.sh accepts --task-plan, --payload, --intensity-metadata, and optional --backend arguments and resolves the backend through backend-registry.sh when --backend is not supplied.
  - Check: `bash scripts/verify/m008-p02-interface-arguments.sh`
- scripts/dispatch/dispatch-interface.sh invokes the selected adapter as a subprocess and emits the adapter's structured result on stdout on success, or a structured dispatch-error on stderr with non-zero exit on failure.
  - Check: `bash scripts/verify/m008-p02-interface-routing.sh`
- scripts/dispatch/dispatch-interface.sh contains no backend-specific branching (no `if backend = local-agent` or `if backend = local-codex`) other than delegating by adapter filename -- satisfies SC-003 zero-core-edit contract.
  - Check: `bash scripts/verify/m008-p02-interface-agnostic.sh`
- All new scripts are Bash 3.2 compatible (no associative arrays, no readarray, no |&).
  - Check: `bash scripts/verify/m008-p02-bash32-compat.sh`
- End-to-end integration: dispatch-interface.sh, invoked with a fixture task plan and payload and explicit --backend local-agent, produces a parseable dispatch-result on stdout.
  - Check: `bash scripts/verify/m008-p02-integration-e2e.sh`

### Artifacts

- templates/dispatch-result.md (min 25 lines, contains "schema_version" and "status" and "artifacts" and "backend")
- templates/dispatch-error.md (min 25 lines, contains "schema_version" and "error_type" and "retry_eligible" and "escalation")
- scripts/dispatch/backend-registry.sh (min 60 lines, contains "backends_available=" and "default_backend=" and "--probe")
- scripts/dispatch/adapters/backend/local-agent.sh (min 80 lines, contains "backend=local-agent" and "--probe" and "available=")
- scripts/dispatch/adapters/backend/local-codex.sh (min 80 lines, contains "backend=local-codex" and "--probe" and "available=" and "codex")
- scripts/dispatch/dispatch-interface.sh (min 100 lines, contains "--task-plan" and "--payload" and "--backend" and "backend-registry.sh")
- scripts/verify/m008-p02-result-template.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-error-template.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-registry-discovery.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-local-agent-probe.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-local-agent-result.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-local-codex-probe.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-local-codex-result.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-interface-arguments.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-interface-routing.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-interface-agnostic.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-bash32-compat.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p02-integration-e2e.sh (min 10 lines, contains "PASS")

### Key Links

- scripts/dispatch/dispatch-interface.sh -> scripts/dispatch/backend-registry.sh (interface uses registry for backend resolution when --backend is not supplied)
- scripts/dispatch/dispatch-interface.sh -> scripts/dispatch/adapters/backend/local-agent.sh (interface invokes adapter as subprocess)
- scripts/dispatch/dispatch-interface.sh -> scripts/dispatch/adapters/backend/local-codex.sh (interface invokes adapter as subprocess)
- scripts/dispatch/adapters/backend/local-agent.sh -> templates/dispatch-result.md (adapter emits result conforming to the schema)
- scripts/dispatch/adapters/backend/local-codex.sh -> templates/dispatch-result.md (adapter emits result conforming to the schema)
- scripts/dispatch/dispatch-interface.sh -> templates/dispatch-error.md (interface emits errors conforming to the error schema)
- scripts/dispatch/backend-registry.sh -> scripts/dispatch/adapters/backend/local-agent.sh (registry invokes adapter with --probe for availability detection)

## Tasks

### T01: Create dispatch-result.md and dispatch-error.md templates

Creates the two canonical schemas that all backend adapters emit. `templates/dispatch-result.md` defines the success result envelope; `templates/dispatch-error.md` defines the structured-error envelope. Both use YAML frontmatter + markdown body per MEM013 and the v0.1.0 template convention. Creates two verification scripts that assert each template's structural fields exist.

Full plan: `tasks/T01-PLAN.md`

### T02: Create backend-registry.sh -- adapter auto-discovery and probing

Creates `scripts/dispatch/backend-registry.sh` that scans `scripts/dispatch/adapters/backend/*.sh`, probes each adapter via `--probe`, and outputs the set of available backends and the default backend as key=value pairs. Satisfies FR-011 (new backends registerable without modifying core dispatch logic) via pure file-system discovery. Creates one verification script.

Full plan: `tasks/T02-PLAN.md`

### T03: Create local-agent.sh adapter (Claude Code Agent tool)

Creates `scripts/dispatch/adapters/backend/local-agent.sh`, the backend adapter for Claude Code's native Agent tool. Implements `--probe` (checks SPECKIT_AGENT_TOOL=1 env var OR detects Claude Code runtime) and normal mode (emits a dispatch-result.md conforming document noting that the orchestrating agent layer performs the actual Agent invocation, consistent with MEM018). Creates two verification scripts.

Full plan: `tasks/T03-PLAN.md`

### T04: Create local-codex.sh adapter (Codex CLI SDK)

Creates `scripts/dispatch/adapters/backend/local-codex.sh`, the backend adapter for the Codex CLI. Implements `--probe` (checks PATH for `codex` binary) and normal mode (invokes `codex` CLI with the assembled payload, captures stdout/stderr/exit, emits a dispatch-result.md conforming document). Exact `codex` CLI invocation uses a placeholder with TODO marker for runtime validation. Creates two verification scripts.

Full plan: `tasks/T04-PLAN.md`

### T05: Create dispatch-interface.sh -- the uniform entry point

Creates `scripts/dispatch/dispatch-interface.sh`, the uniform dispatch entry point. Parses `--task-plan`, `--payload`, `--intensity-metadata`, and optional `--backend` arguments. Resolves the backend via `backend-registry.sh` when `--backend` is not supplied. Invokes the resolved adapter as a subprocess. On success, emits the adapter's structured result on stdout. On failure, synthesizes a dispatch-error on stderr and exits non-zero. Contains no backend-specific branching (FR-011, SC-003). Creates three verification scripts.

Full plan: `tasks/T05-PLAN.md`

### T06: Integration test + Bash 3.2 compatibility check

Creates the Bash 3.2 compatibility verification script that checks all new scripts for prohibited constructs. Creates an end-to-end integration test: fixture task plan + fixture payload -> dispatch-interface.sh with --backend local-agent -> assert parseable dispatch-result on stdout. Verifies all components work together as a pipeline.

Full plan: `tasks/T06-PLAN.md`

## Task Dependencies

```
T01 (templates)
  |
  +--------------------------------+
                                   |
T02 (backend-registry.sh) --------->+ (registry is used by T05)
                                   |
T03 (local-agent.sh) -- needs T01 templates to emit conforming results
  |                                |
  +-------------------------------->+ (adapters are invoked by T05)
                                   |
T04 (local-codex.sh) -- needs T01 templates to emit conforming results
  |                                |
  +-------------------------------->+
                                   |
                                   v
                            T05 (dispatch-interface.sh)
                                   |
                                   v
                            T06 (integration + bash32)
```

- T01 is independent and comes first (both adapters emit conforming results).
- T02 is independent of T01 (scans file system, no template dependency).
- T03 depends on T01 (emits dispatch-result format).
- T04 depends on T01 (emits dispatch-result format).
- T02, T03, T04 can execute concurrently after T01.
- T05 depends on T02, T03, T04 (routes via registry into an adapter).
- T06 depends on all prior tasks.

## Files Likely Touched

- templates/dispatch-result.md (create)
- templates/dispatch-error.md (create)
- scripts/dispatch/backend-registry.sh (create)
- scripts/dispatch/adapters/backend/local-agent.sh (create)
- scripts/dispatch/adapters/backend/local-codex.sh (create)
- scripts/dispatch/dispatch-interface.sh (create)
- scripts/verify/m008-p02-result-template.sh (create)
- scripts/verify/m008-p02-error-template.sh (create)
- scripts/verify/m008-p02-registry-discovery.sh (create)
- scripts/verify/m008-p02-local-agent-probe.sh (create)
- scripts/verify/m008-p02-local-agent-result.sh (create)
- scripts/verify/m008-p02-local-codex-probe.sh (create)
- scripts/verify/m008-p02-local-codex-result.sh (create)
- scripts/verify/m008-p02-interface-arguments.sh (create)
- scripts/verify/m008-p02-interface-routing.sh (create)
- scripts/verify/m008-p02-interface-agnostic.sh (create)
- scripts/verify/m008-p02-bash32-compat.sh (create)
- scripts/verify/m008-p02-integration-e2e.sh (create)
