# Glossary

Project glossary for orchestrator — alphabetized term entries with
one-line definitions and at most a two-line elaboration. M033's grilling
protocol writes inline into this file as terms resolve.

Format invariant (per US-6 / M032/P02/T03):

- Heading style: `### TERM` (level-3 heading, term name capitalized).
- One-line definition immediately under the heading.
- At most a two-line elaboration paragraph below the definition.
- Entries alphabetized at file scope.

---

### Constitution

The seven governing principles authored at `.orchestrator/memory/constitution.md` that gate every orchestrator decision.

The constitution is amended via the formal amendment process documented in `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`; principles are added only when they fail the inclusion-criteria gate.

### Knowledge Graph

The on-disk record of patterns, conventions, lessons, and decisions accumulated across milestones, projected into the wiki via `scripts/wiki/wiki-scan-sources.sh`.

The graph is the orchestrator's product core; wiki / Jira / Notion projections are views (per `project_knowledge_graph_vision.md`). Cross-company comment / scan / AI-Q&A is the engagement loop.

### Milestone

A multi-phase delivery unit closed by a `M###-VALIDATED` marker file plus a `M###-SUMMARY.md` plus an `unit_close` JSONL record per the M030/M031 close discipline.

Milestones decompose into phases (typically P00–P0N); phases decompose into tasks (T01–T0N). Each task is one fresh-context dispatch.
