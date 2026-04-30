# commands/

Agent instruction documents for spec-kit orchestrator commands. Each file defines one `orchestrator:*` command (invoked at runtime as `/orchestrator-<name>`).

## Structure
Every command file follows: YAML frontmatter → Title → Prerequisites → Core Workflow → Output → Idempotency → Error Handling → Referenced Scripts/Templates.

## Convention
- Commands tell the agent **what to do**; scripts in `scripts/` do the **how**
- Commands reference scripts by relative path in a "Referenced Scripts" section at the end
- All commands are idempotent — re-running produces no change if output already exists
- Integration tests validate that all cross-references from commands → scripts/templates resolve

## Files
| Command | Invoked As | Lines |
|---------|-----------|-------|
| evaluate.md | /orchestrator-evaluate | Scope triage |
| discuss.md | /orchestrator-discuss | Pre-planning capture |
| roadmap.md | /orchestrator-roadmap | Phase decomposition |
| plan-phase.md | /orchestrator-plan-phase | Task breakdown |
| dispatch.md | /orchestrator-dispatch | Fresh context execution |
| auto.md | /orchestrator-auto | Autonomous loop (~359 lines) |
| verify.md | /orchestrator-verify | Must-haves checking |
| status.md | /orchestrator-status | Progress dashboard |
| resume.md | /orchestrator-resume | Crash/pause recovery |
| consolidate.md | /orchestrator-consolidate | Knowledge compression |
| zoom-out.md | /orchestrator-zoom-out | One-layer-up code map (read-only utility, mattpocock/skills-derived, MIT) |
| diagnose.md | /orchestrator-diagnose | Six-phase debug loop: feedback → reproduce → hypothesize → instrument → fix → regression-test (mattpocock/skills-derived, MIT) |
