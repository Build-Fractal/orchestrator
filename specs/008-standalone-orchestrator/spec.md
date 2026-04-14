# Feature Specification: Standalone Orchestrator

**Feature Branch**: `008-standalone-orchestrator`  
**Created**: 2026-04-14  
**Status**: Draft  
**Input**: User description: "Transform the orchestrator from a spec-kit extension into a multi-runtime standalone extension that automatically calibrates its process intensity to the work at hand, packaged as skills that work across Claude Code, Codex CLI, Cursor, and Gemini CLI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adaptive Intensity Auto-Calibration (Priority: P1)

A developer describes a task — anything from a typo fix to a platform build. The orchestrator evaluates the scope, risk, and complexity of the request and automatically recommends an appropriate process intensity level (Quick, Standard, or Full). The developer can accept the recommendation or override it. The entire orchestration pipeline — discussion, planning, verification, knowledge generation, and dispatch — scales to match the selected intensity.

**Why this priority**: This is the core differentiator. Without adaptive intensity, the orchestrator applies the same heavyweight process to every task regardless of size. A typo fix should take seconds with minimal ceremony; a platform build should engage full planning, research agents, and multi-tier verification. Getting this right makes the orchestrator usable for the full spectrum of developer work.

**Independent Test**: Can be fully tested by submitting tasks of varying scope (single-line fix, moderate feature, large project) and verifying that the recommended intensity level matches the scope, that pipeline stages are appropriately included or skipped, and that the developer can override the recommendation.

**Acceptance Scenarios**:

1. **Given** a developer describes a trivial bug fix, **When** the orchestrator evaluates it, **Then** it recommends Quick intensity with minimal process stages and the task completes with no discussion, no research agents, and only static verification.
2. **Given** a developer describes a multi-component feature, **When** the orchestrator evaluates it, **Then** it recommends Standard intensity with task breakdown, optional discussion, on-demand research, and two-tier verification.
3. **Given** a developer describes a platform-level initiative, **When** the orchestrator evaluates it, **Then** it recommends Full intensity with required discussion, pre-planning research, full boundary maps, four-tier verification, and comprehensive knowledge generation.
4. **Given** the orchestrator recommends Standard intensity, **When** the developer overrides to Quick, **Then** the pipeline adjusts immediately and skips stages that Standard would have included.
5. **Given** the orchestrator recommends Quick intensity, **When** the developer overrides to Full, **Then** the pipeline expands to include all Full-mode stages.

---

### User Story 2 - Multi-Runtime Installation and Usage (Priority: P2)

A developer who uses any supported agent runtime (Claude Code on any surface, Codex CLI, or Cursor) installs the orchestrator and immediately starts using it. The orchestrator commands and workflows behave identically regardless of which runtime executes them. Installation is a single command or action per runtime.

**Why this priority**: The orchestrator's value proposition scales with how many developers can access it. Locking it to a single runtime limits adoption. Multi-runtime support is the prerequisite for ecosystem reach and is foundational for packaging (P5) and onboarding (P6).

**Independent Test**: Can be fully tested by installing the orchestrator on at least two different runtimes and running identical workflows on each, verifying that commands produce equivalent results and state files are interchangeable.

**Acceptance Scenarios**:

1. **Given** a developer using Claude Code, **When** they install the orchestrator, **Then** all orchestrator commands are available within their standard workflow.
2. **Given** a developer using Codex CLI, **When** they install the orchestrator, **Then** all orchestrator commands are available within their standard workflow.
3. **Given** a developer using Cursor, **When** they install the orchestrator, **Then** all orchestrator commands are available within their standard workflow.
4. **Given** identical projects on two different runtimes, **When** the same orchestrator workflow is executed on each, **Then** both produce equivalent state files and artifacts.

---

### User Story 3 - Backend-Agnostic Task Dispatch (Priority: P3)

A developer dispatches tasks through the orchestrator without knowing or choosing where execution happens. The orchestrator sends each task through a uniform dispatch interface that accepts a task plan and payload, routes it to an appropriate execution backend (local agent, local SDK, or future cloud backend), and returns a result with artifacts. The dispatch interface is the same regardless of backend, and new backends can be added without changing the orchestrator's core logic.

**Why this priority**: This is the extensibility seam that enables future capabilities (cloud dispatch, parallel execution, specialized workers) without restructuring the core system. It also enables the orchestrator to work across runtimes that have different native dispatch mechanisms.

**Independent Test**: Can be fully tested by dispatching the same task to at least two different local backends and verifying that the orchestrator receives equivalent results through the same interface, and that adding a new backend requires only implementing the adapter contract without modifying core dispatch logic.

**Acceptance Scenarios**:

1. **Given** a task is dispatched on Claude Code, **When** it routes through the local agent backend, **Then** the orchestrator receives a result containing completion status and generated artifacts through the standard dispatch interface.
2. **Given** a task is dispatched on Codex CLI, **When** it routes through the local SDK backend, **Then** the orchestrator receives a result in the same format as the Claude Code backend.
3. **Given** a new backend is registered, **When** a task is dispatched, **Then** the orchestrator can route to it without any changes to core dispatch logic.
4. **Given** a dispatched task fails in the backend, **When** the result is returned, **Then** it includes structured error information sufficient for the orchestrator to decide whether to retry, skip, or escalate.

---

### User Story 4 - Namespace and State Independence (Priority: P4)

A developer uses the orchestrator as a standalone tool without spec-kit installed. The orchestrator stores its state in its own configurable directory, uses its own command namespace, and does not depend on any spec-kit runtime conventions. Developers who do have spec-kit installed can optionally use spec-kit integration mode, where the orchestrator reads and writes spec-kit artifacts.

**Why this priority**: Standalone operation removes the adoption barrier of requiring spec-kit. The orchestrator's value (scope triage, phase decomposition, autonomous dispatch, verification, knowledge generation) is independent of spec-kit's SDD workflow. Namespace independence also avoids collisions in multi-tool environments.

**Independent Test**: Can be fully tested by running the full orchestrator workflow in a fresh project with no spec-kit present, verifying that all commands work, state is persisted correctly, and no errors reference missing spec-kit dependencies.

**Acceptance Scenarios**:

1. **Given** a project with no spec-kit installed, **When** the developer runs orchestrator commands, **Then** all commands execute successfully using the standalone state directory.
2. **Given** a project with spec-kit installed, **When** the developer enables integration mode, **Then** the orchestrator reads and writes spec-kit artifacts in addition to its own state.
3. **Given** a developer configures a custom state directory, **When** orchestrator commands run, **Then** all state files are read from and written to the custom directory.
4. **Given** the orchestrator is installed alongside other tools that use command namespaces, **When** the developer lists available commands, **Then** orchestrator commands are clearly namespaced and do not collide with other tools.

---

### User Story 5 - First-Run Onboarding (Priority: P5)

A developer installs the orchestrator in a new or existing project for the first time and is guided through initialization. The onboarding flow detects the project's current state (existing files, runtime, installed tools), generates appropriate configuration, and produces a project instruction file so the orchestrator understands the project context on subsequent runs. The experience takes under two minutes and requires no prior orchestrator knowledge.

**Why this priority**: First impressions determine adoption. A developer who installs the orchestrator and can't figure out how to start within two minutes will uninstall it. Onboarding must be fast, opinionated, and produce a working configuration with sensible defaults.

**Independent Test**: Can be fully tested by running the initialization command in an empty project and a populated project, verifying that both produce valid configuration, a project instruction file, and that subsequent orchestrator commands work without additional setup.

**Acceptance Scenarios**:

1. **Given** a developer runs the init command in a new empty project, **When** initialization completes, **Then** a valid configuration file and project instruction file are created with sensible defaults.
2. **Given** a developer runs the init command in an existing project with source files, **When** initialization completes, **Then** the orchestrator detects the project structure and includes relevant context in the project instruction file.
3. **Given** a developer runs the init command, **When** the orchestrator detects installed tools (graph database, MCP servers, CI system), **Then** it includes recommendations for leveraging those tools at appropriate intensity levels.
4. **Given** a developer completes initialization, **When** they immediately run their first orchestrator command, **Then** it works without additional configuration steps.

---

### User Story 6 - Capability Detection and Recommendations (Priority: P6)

The orchestrator probes the developer's environment for installed tools and capabilities (graph database, MCP servers, CI pipelines, specialized analysis tools) and factors them into its intensity recommendations and workflow behavior. When a tool is available that could improve the current workflow step, the orchestrator recommends using it. When a tool is unavailable, the orchestrator proceeds without it — capabilities enhance the workflow but are never required.

**Why this priority**: This transforms the orchestrator from a static workflow runner into an environment-aware system that gets better as the developer's tooling matures. It also provides a natural upsell path: developers see what capabilities they're missing and can choose to install them.

**Independent Test**: Can be fully tested by running the orchestrator in environments with varying tool installations and verifying that detected tools are reflected in intensity recommendations, that available tools are used when the intensity level supports them, and that missing tools cause graceful omission rather than errors.

**Acceptance Scenarios**:

1. **Given** a developer's environment includes a graph database, **When** the orchestrator runs at Standard or Full intensity, **Then** knowledge operations leverage the graph database for richer knowledge retrieval and storage.
2. **Given** a developer's environment has no optional tools installed, **When** the orchestrator runs at any intensity, **Then** all workflows complete successfully using only built-in capabilities.
3. **Given** a tool becomes available after initial setup, **When** the orchestrator runs its next workflow, **Then** it detects the new tool and adjusts its recommendations accordingly.

---

### Edge Cases

- What happens when the developer's runtime is not in the supported list? The orchestrator reports an unsupported runtime error with guidance on which runtimes are supported and how to request support for new ones.
- What happens when the orchestrator detects conflicting signals for intensity (e.g., small diff but high-risk file paths)? The orchestrator recommends the higher intensity and explains the conflicting signals so the developer can make an informed override decision.
- What happens when state files from one runtime are opened by a different runtime? State files are runtime-agnostic and interchangeable; the orchestrator reads them correctly regardless of which runtime created them.
- What happens when the developer downgrades intensity mid-workflow after some stages have already completed at the original intensity? Completed stages are preserved as-is; only remaining stages adjust to the new intensity level.
- What happens when a dispatch backend becomes unavailable mid-task? The dispatch interface returns a structured error; the orchestrator logs the failure and presents the developer with options (retry, switch backend, or abort).
- What happens when initialization is run in a project that already has orchestrator configuration? The orchestrator detects existing configuration and offers to update or reset it, preserving existing project context by default.

## Requirements *(mandatory)*

### Functional Requirements

#### Adaptive Intensity

- **FR-001**: System MUST evaluate task scope, risk, and complexity from a natural-language task description and produce an intensity recommendation (Quick, Standard, or Full).
- **FR-002**: System MUST allow the developer to accept or override the recommended intensity level before the workflow begins.
- **FR-003**: System MUST scale each pipeline stage (discussion, research, planning, verification, knowledge generation, dispatch) according to the active intensity level.
- **FR-004**: System MUST support intensity override mid-workflow, adjusting remaining stages while preserving completed stages.
- **FR-005**: System MUST detect risk signals (file-path sensitivity, dependency changes, scope markers) that may warrant higher intensity than scope alone would suggest.

#### Multi-Runtime Support

- **FR-006**: System MUST operate on Claude Code (CLI, desktop, web, IDE extensions), Codex CLI, and Cursor.
- **FR-007**: System MUST produce identical state files and artifacts regardless of which runtime executes the workflow.
- **FR-008**: System MUST auto-detect the current runtime and load the appropriate runtime adapter without developer configuration.

#### Backend-Agnostic Dispatch

- **FR-009**: System MUST define a uniform dispatch interface that accepts a task plan and context payload, and returns a structured result with completion status and generated artifacts.
- **FR-010**: System MUST ship with at least two local dispatch backends (one for Claude Code's native agent dispatch, one for Codex CLI's native dispatch).
- **FR-011**: System MUST allow new dispatch backends to be registered without modifying core dispatch logic.
- **FR-012**: System MUST return structured error information from failed dispatches sufficient to determine retry, skip, or escalate actions.

#### Namespace and State Independence

- **FR-013**: System MUST function without spec-kit installed, using its own state directory and command namespace.
- **FR-014**: System MUST support a configurable state directory root, defaulting to a standalone location when spec-kit is not present.
- **FR-015**: System MUST provide an optional spec-kit integration mode that reads and writes spec-kit artifacts alongside orchestrator state.
- **FR-016**: System MUST use a distinct command namespace that does not collide with spec-kit or other installed tools.

#### Packaging and Distribution

- **FR-017**: System MUST be distributable as skill files conforming to an open standard format that supported runtimes can discover and load.
- **FR-018**: System MUST support installation as a single command or action on each supported runtime.
- **FR-019**: System MUST include a self-update mechanism that preserves local configuration.

#### Onboarding and Initialization

- **FR-020**: System MUST provide an init command that creates configuration and a project instruction file from detected project context.
- **FR-021**: System MUST detect installed tools and capabilities during initialization and include them in configuration.
- **FR-022**: System MUST generate a project instruction file that the runtime can discover and use for project context on subsequent runs.
- **FR-023**: System MUST detect and handle re-initialization of already-configured projects, preserving existing context by default.

#### Capability Detection

- **FR-024**: System MUST probe the environment for optional tools (graph database, MCP servers, CI pipelines) at startup and cache the results.
- **FR-025**: System MUST factor detected capabilities into intensity recommendations and pipeline behavior.
- **FR-026**: System MUST proceed without error when optional capabilities are absent, using only built-in functionality.

### Key Entities

- **Intensity Level**: A named process calibration (Quick, Standard, Full) that controls which pipeline stages execute and at what depth. Combines scope classification with risk assessment.
- **Runtime Adapter**: A component that bridges the orchestrator's commands and state conventions to a specific agent runtime's native patterns (instruction files, command discovery, hook mechanisms).
- **Dispatch Backend**: A component that accepts a task plan and payload through the uniform dispatch interface and executes it via a specific mechanism (local agent tool, local SDK, future cloud API). Returns structured results.
- **Dispatch Interface**: The contract between the orchestrator core and dispatch backends — task plan + payload in, result + artifacts out. Backend-agnostic by design.
- **Capability Profile**: The set of detected tools and features available in the developer's environment, used to inform intensity recommendations and pipeline behavior.
- **Project Instruction File**: A runtime-discoverable file generated during initialization that provides the orchestrator with persistent project context (structure, conventions, detected capabilities).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can describe a task and receive an appropriate intensity recommendation within 5 seconds, without manual scope classification.
- **SC-002**: The same orchestrator workflow produces equivalent results across at least 3 different supported runtimes.
- **SC-003**: A new dispatch backend can be added by implementing the adapter contract alone, with zero changes to core orchestrator files.
- **SC-004**: The orchestrator completes a full workflow in a project with no spec-kit present, producing valid state and artifacts.
- **SC-005**: A developer can install the orchestrator and complete their first orchestrated task within 5 minutes on any supported runtime, with no prior orchestrator experience.
- **SC-006**: Quick-intensity workflows complete in under 30 seconds for single-file changes, while Full-intensity workflows engage all pipeline stages for platform-level work.
- **SC-007**: All state files produced by the orchestrator are readable and usable across any supported runtime without conversion.
- **SC-008**: The orchestrator functions correctly with zero optional tools installed, and automatically leverages detected tools when available at appropriate intensity levels.

## Assumptions

- Supported runtimes (Claude Code, Codex CLI, Cursor) all support some form of discoverable skill/command files and project instruction files. Specific formats vary by runtime but the concept is universal.
- The existing orchestrator command and script architecture (markdown commands + shell scripts) is portable to non-spec-kit contexts with adapter-layer changes rather than rewrites.
- Developers are comfortable with a single init step per project. Re-initialization is rare and handled as an update rather than a fresh start.
- Risk signal detection for intensity recommendation can be meaningfully derived from file paths, dependency manifests, and natural-language scope descriptions without requiring deep code analysis.
- The dispatch interface contract (task plan + payload in, result + artifacts out) is sufficient for both local and future cloud backends without breaking changes.

## Constraints

- Must not introduce runtime dependencies on spec-kit. Spec-kit integration is optional, never required.
- Must not break existing orchestrator state files or workflows for current users. Migration from spec-kit extension mode to standalone mode must be supported.
- The dispatch adapter interface must be designed to accommodate future cloud backends (Managed Agents) without interface changes — this is the explicit seam for M010.
- Installation must work without elevated system permissions on all supported platforms.
- All state and configuration must be file-based and version-controllable. No daemon processes, no databases, no network services required for core operation.

## Dependencies

- Existing orchestrator v0.2.0 codebase (commands, scripts, templates, state machine) as the foundation to refactor.
- M007 (Graph-Enhanced Knowledge) complete — knowledge operations referenced by adaptive intensity depend on graph pipeline.
- Runtime documentation for each target runtime's skill/command discovery and project instruction mechanisms.
