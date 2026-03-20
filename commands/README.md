# commands/

Agent instruction documents for spec-kit orchestrator commands. Each file defines one `speckit.orchestrator.*` command.

## Structure
Every command file follows: YAML frontmatter → Title → Prerequisites → Core Workflow → Output → Idempotency → Error Handling → Referenced Scripts/Templates.

## Convention
- Commands tell the agent **what to do**; scripts in `scripts/` do the **how**
- Commands reference scripts by relative path in a "Referenced Scripts" section at the end
- All commands are idempotent — re-running produces no change if output already exists
- Integration tests validate that all cross-references from commands → scripts/templates resolve

## Files
| Command | Registered As | Lines |
|---------|--------------|-------|
| evaluate.md | speckit.orchestrator.evaluate | Scope triage |
| discuss.md | speckit.orchestrator.discuss | Pre-planning capture |
| roadmap.md | speckit.orchestrator.roadmap | Phase decomposition |
| plan-phase.md | speckit.orchestrator.plan-phase | Task breakdown |
| dispatch.md | speckit.orchestrator.dispatch | Fresh context execution |
| auto.md | speckit.orchestrator.auto | Autonomous loop (~359 lines) |
| verify.md | speckit.orchestrator.verify | Must-haves checking |
| status.md | speckit.orchestrator.status | Progress dashboard |
| resume.md | speckit.orchestrator.resume | Crash/pause recovery |
| consolidate.md | speckit.orchestrator.consolidate | Knowledge compression |
