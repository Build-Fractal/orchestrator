# Quickstart: Speckit-Orchestrator Extension

## Prerequisites

- spec-kit >=0.1.0 installed in project (`.specify/` directory exists)
- Git repository with feature-branch workflow
- An AI agent supported by spec-kit (Claude Code, Copilot, Cursor, Gemini CLI)
- Bash 4+ or POSIX sh

## Install

**Development (current)**:
```bash
specify extension add --dev /path/to/speckit-orchestrator
```

This installs from a local checkout and registers the 10 `speckit.orchestrator.*` commands with your agent.

**Future distribution** (requires publishing):
```bash
# Via spec-kit catalog (after catalog listing)
specify extension add speckit-orchestrator

# Via APM (after apm.yml is published)
apm install speckit-orchestrator
```

## Usage

### 1. Start with scope triage

Describe your project to the orchestrator:

```
/speckit.orchestrator.evaluate

Build a multi-tenant data pipeline with ingestion, transformation, storage, API, and monitoring.
```

The orchestrator classifies your work:
- **Tier A**: Fits one context window → runs standard spec-kit inline, zero overhead
- **Tier B**: Multiple phases, each fits one window → adds roadmap + handoff
- **Tier C**: Full orchestration → state machine, dispatch, crash recovery, knowledge

### 2. For Tier B: Phased execution

```
/speckit.orchestrator.roadmap     # Break spec into phases
/speckit.orchestrator.plan-phase  # Plan next phase
/speckit.orchestrator.dispatch    # Execute tasks in fresh contexts
/speckit.orchestrator.status      # Check progress
```

You drive each phase transition manually.

### 3. For Tier C: Autonomous mode

```
/speckit.orchestrator.discuss     # Capture architectural preferences (required gate)
/speckit.orchestrator.roadmap     # Generate full roadmap with boundary maps
/speckit.orchestrator.auto        # Start autonomous execution — walk away
```

Check progress from a second terminal:
```
/speckit.orchestrator.status      # Progress dashboard
/speckit.orchestrator.discuss     # Inject decisions mid-execution
```

### 4. After completion

```
/speckit.orchestrator.consolidate # Compress knowledge, archive raw artifacts
```

## Configuration

On first run, you'll be prompted for preferences. Or create `orchestrator-config.yml` at project root:

```yaml
default_tier: null
verification_commands:
  - npm test
  - npm run lint
context_verbosity: standard
git_isolation: false
dispatch_budget: null
duration_budget: null
```

Override per-run with env vars: `SPECKIT_ORCHESTRATOR_DEFAULT_TIER=C`

## State Directory

All orchestrator state lives at `.specify/orchestrator/`:

```
.specify/orchestrator/
├── DECISIONS.md          # Architectural decisions (append-only)
├── KNOWLEDGE.md          # Patterns and lessons (append-only)
├── execution-log.jsonl   # Dispatch history
└── milestones/M001/      # Per-milestone state tree
```

This directory is separate from your spec artifacts (`specs/`) and from the extension deployment directory (`.specify/extensions/orchestrator/`).

## Key Principles

1. **Every task fits one context window** — if it can't, it must be decomposed
2. **State on disk is truth** — crash, restart, and resume from file state
3. **Plans assume zero context** — an agent dropped cold into the repo can execute any plan
4. **Knowledge compounds** — every phase produces structured documentation for future phases
5. **Verification is mechanical** — no completion claims without fresh evidence