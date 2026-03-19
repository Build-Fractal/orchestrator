# Contract: Extension Manifest (`extension.yml`)

**Version**: 1.0 | **Date**: 2026-03-19

## Schema

The orchestrator's `extension.yml` is the primary interface between the orchestrator and spec-kit's extension system. It declares commands, hooks, config schema, and required dependencies.

```yaml
schema_version: "1.0"

extension:
  id: speckit-orchestrator
  name: Speckit Orchestrator
  version: 0.1.0
  description: >-
    Autonomous multi-phase orchestration for spec-kit's spec-driven development
    workflow. Adds milestone/phase/task hierarchy, state machine dispatch, crash
    recovery, and knowledge generation.
  author: clariti-care
  repository: https://github.com/clariti-care/spec-kit-orchestrator
  license: MIT

requires:
  speckit_version: ">=0.1.0"
  commands:
    - speckit.plan
    - speckit.tasks
    - speckit.implement
    - speckit.clarify
    - speckit.specify
    - speckit.analyze

provides:
  commands:
    - name: speckit.orchestrator.evaluate
      file: commands/evaluate.md
      description: "Use when starting a new project to classify scope as Tier A, B, or C."

    - name: speckit.orchestrator.discuss
      file: commands/discuss.md
      description: "Use when capturing architectural decisions and constraints before roadmap generation."

    - name: speckit.orchestrator.roadmap
      file: commands/roadmap.md
      description: "Use when breaking a spec into phases with dependency graph and boundary maps."

    - name: speckit.orchestrator.plan-phase
      file: commands/plan-phase.md
      description: "Use when planning one phase — creates task decomposition with must-haves."

    - name: speckit.orchestrator.dispatch
      file: commands/dispatch.md
      description: "Use when executing one task in a fresh context with constructed payload."

    - name: speckit.orchestrator.auto
      file: commands/auto.md
      description: "Use when starting autonomous execution — dispatches tasks until milestone completes."

    - name: speckit.orchestrator.verify
      file: commands/verify.md
      description: "Use when checking must-haves verification for a completed phase."

    - name: speckit.orchestrator.status
      file: commands/status.md
      description: "Use when checking progress — milestone/phase/task completion, blockers, next action."

    - name: speckit.orchestrator.resume
      file: commands/resume.md
      description: "Use when resuming from a crash or intentional pause using disk state."

    - name: speckit.orchestrator.consolidate
      file: commands/consolidate.md
      description: "Use when compressing knowledge and archiving verbose artifacts after milestone completion."

  config:
    - file: orchestrator-config.yml
      template: templates/orchestrator-config-default.yml
      required: false

  scripts:
    - file: scripts/state/derive-phase.sh
      executable: true
    - file: scripts/state/read-roadmap.sh
      executable: true
    - file: scripts/state/read-config.sh
      executable: true
    - file: scripts/state/check-lock.sh
      executable: true
    - file: scripts/dispatch/build-context.sh
      executable: true
    - file: scripts/dispatch/scope-filter.sh
      executable: true
    - file: scripts/dispatch/detect-capabilities.sh
      executable: true
    - file: scripts/verify/check-must-haves.sh
      executable: true
    - file: scripts/verify/check-boundary-map.sh
      executable: true
    - file: scripts/verify/run-commands.sh
      executable: true
    - file: scripts/knowledge/write-summary.sh
      executable: true
    - file: scripts/knowledge/append-decision.sh
      executable: true
    - file: scripts/knowledge/append-knowledge.sh
      executable: true
    - file: scripts/knowledge/consolidate-artifacts.sh
      executable: true
    - file: scripts/lifecycle/scaffold.sh
      executable: true
    - file: scripts/lifecycle/advance-state.sh
      executable: true
    - file: scripts/lifecycle/write-lock.sh
      executable: true
    - file: scripts/lifecycle/write-continue.sh
      executable: true

defaults:
  default_tier: null
  verification_commands: []
  context_verbosity: standard
  git_isolation: false
  dispatch_budget: null
  duration_budget: null

config_schema:
  type: object
  properties:
    default_tier:
      type: [string, "null"]
      enum: [A, B, C, null]
    verification_commands:
      type: array
      items:
        type: string
    context_verbosity:
      type: string
      enum: [minimal, standard, full]
    git_isolation:
      type: boolean
    dispatch_budget:
      type: [integer, "null"]
      minimum: 1
    duration_budget:
      type: [string, "null"]

hooks:
  before_tasks:
    command: speckit.orchestrator.evaluate
    optional: true
    prompt: "Orchestration active — evaluate project scope and classify execution tier?"
    description: "Injects phase-level context if orchestrator is active."

  after_tasks:
    command: speckit.orchestrator.roadmap
    optional: true
    prompt: "Generate orchestration roadmap from task phases?"
    description: "Triggers roadmap generation from tasks.md phases."

  before_implement:
    command: speckit.orchestrator.dispatch
    optional: true
    prompt: "Dispatch this implementation phase via orchestrator?"
    description: "Injects phase scope enforcement for current phase."

  after_implement:
    command: speckit.orchestrator.verify
    optional: true
    prompt: "Run orchestrator verification on completed phase?"
    description: "Triggers phase summary generation and state advancement."

  before_commit:
    command: speckit.orchestrator.verify
    optional: true
    prompt: "Run tier-1 static verification before commit?"
    description: "Runs deterministic verification scripts to block commits when must-haves are unmet."

tags:
  - orchestration
  - automation
  - multi-phase
  - autonomous
```

## Command Naming Convention

All commands follow `speckit.orchestrator.<verb>` pattern:
- Matches spec-kit's extension command regex: `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$`
- Verb describes the action: evaluate, discuss, roadmap, plan-phase, dispatch, auto, verify, status, resume, consolidate

## Command Descriptions

All descriptions use trigger phrasing ("Use when...") per FR-029. This enables accurate skill discovery by agents scanning description fields.

## Command Frontmatter Requirements

All orchestrator commands MUST include these frontmatter fields:

- **`$ARGUMENTS`**: A `## User Input` section that processes `$ARGUMENTS` per spec-kit convention. Commands accepting inline arguments (evaluate, discuss, dispatch, auto) document expected argument formats.
- **`scripts`**: Commands invoking helper scripts declare them for spec-kit's path rewriting:
  ```yaml
  scripts:
    sh: ../../scripts/state/derive-phase.sh
  ```
- **`handoffs`**: Declare command transitions for local agent navigation. The CI adapter extracts target command names and ignores prompt/send context.

## Hook Behavior

All hooks use `optional: true` — they prompt the user and no-op when orchestration is not active. This ensures zero overhead for non-orchestrated projects (SC-008).

## Hook Count

The extension registers 5 hooks (expanded from the original 4):
- `before_tasks`, `after_tasks`, `before_implement`, `after_implement` — original 4 hook points
- `before_commit` — added per plan-level conversus convergence for tier-1 static verification

Note: `before_commit` and `after_commit` are documented in spec-kit but not fully wired in all command templates. The orchestrator registers `before_commit` as `optional: true` to degrade gracefully.