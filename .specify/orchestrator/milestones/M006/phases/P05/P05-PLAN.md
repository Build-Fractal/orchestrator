---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M006"
goal: "Create contributor guide (scripts/AGENTS.md) and constitution walkthrough (references/constitution-walkthrough.md) with coding conventions, testing patterns, compliance checklist, and PR review checklist"
demo_sentence: "A developer reading AGENTS.md understands coding conventions (Bash 3.2, double-sourcing guards, error/event emission, atomic writes), testing patterns, constitution v2.0 compliance requirements, and PR review checklist — verified by having the guide review one real M004/M005 phase for compliance."
risk: "low"
depends_on: ["P01"]
---

<!--
  P05 — Contributor Guide and AGENTS.md
  ======================================

  Context: M006 (Documentation & Quality) Phase 05 updates the existing
  scripts/AGENTS.md from a directory-listing format into a full contributor
  guide, and creates a new references/constitution-walkthrough.md that maps
  each of the 13 constitution v2.0 principles to concrete codebase examples.

  The phase then validates the guide by reviewing one real M004/M005 phase
  for compliance against the documented patterns.

  Upstream context:
    P01: references/architecture.md (378 lines) — subsystem map,
         file layout, engine pipeline

  Design constraints from M006-CONTEXT.md:
    DC-1: Progressive disclosure format (## Overview, ##/### headings, ASCII diagrams)
    DC-2: Audience label — contributor docs use "contributors"
    DC-3: Cross-links use relative paths
    DC-4: Verify-as-you-write — follow patterns, confirm against codebase
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for all code fixes
-->

## Must-Haves

### Truths

- `scripts/AGENTS.md` exists with progressive disclosure header and audience label "contributors".
  - Check: `bash scripts/verify/m006-p05-agents-header.sh`
- `scripts/AGENTS.md` documents Bash 3.2 compatibility patterns (no `declare -A`, no process substitution as redirect target, portable `sed_i`).
  - Check: `bash scripts/verify/m006-p05-agents-bash32.sh`
- `scripts/AGENTS.md` documents double-sourcing guards (guard pattern, LIBNAME convention, AP-003 reference).
  - Check: `bash scripts/verify/m006-p05-agents-guards.sh`
- `scripts/AGENTS.md` documents event emission and result protocol (emit_event, emit_result, silent failure definition).
  - Check: `bash scripts/verify/m006-p05-agents-events.sh`
- `scripts/AGENTS.md` documents testing patterns (pass/fail functions, PASS:/FAIL: output, fixture conventions, suite structure).
  - Check: `bash scripts/verify/m006-p05-agents-testing.sh`
- `scripts/AGENTS.md` includes a constitution v2.0 compliance checklist and a PR review checklist.
  - Check: `bash scripts/verify/m006-p05-agents-checklists.sh`
- `references/constitution-walkthrough.md` exists with progressive disclosure header and audience label "contributors".
  - Check: `bash scripts/verify/m006-p05-walkthrough-header.sh`
- `references/constitution-walkthrough.md` covers all 13 constitution principles (I through XIII) with codebase examples.
  - Check: `bash scripts/verify/m006-p05-walkthrough-principles.sh`
- Both docs cross-link to each other and to relevant reference docs using relative paths (DC-3).
  - Check: `bash scripts/verify/m006-p05-crosslinks.sh`

### Artifacts

- `scripts/AGENTS.md` (min 250 lines, contains "## Overview", "Audience: contributors", "Bash 3.2", "double-sourcing guard", "emit_event", "emit_result", "PASS:", "FAIL:", "PR Review")
- `references/constitution-walkthrough.md` (min 300 lines, contains "## Overview", "Audience: contributors", "Context Minimization", "Evidence Before Claims", "No Dead Infrastructure", "Hook Isolation", "Agent Instruction Schema")

### Key Links

- `scripts/AGENTS.md` -> `references/constitution-walkthrough.md` (full principle walkthrough)
- `scripts/AGENTS.md` -> `references/architecture.md` (system architecture overview)
- `scripts/AGENTS.md` -> `ANTIPATTERNS.md` (antipattern register)
- `references/constitution-walkthrough.md` -> `.specify/memory/constitution.md` (authoritative constitution)
- `references/constitution-walkthrough.md` -> `scripts/AGENTS.md` (coding conventions)
- `references/constitution-walkthrough.md` -> `references/architecture.md` (architecture context)
- `references/constitution-walkthrough.md` -> `ANTIPATTERNS.md` (real-world violations)

## Tasks

### T01: Update `scripts/AGENTS.md` — coding conventions, testing patterns, checklists

Rewrites the existing `scripts/AGENTS.md` from a directory listing into a
full contributor guide. Reads the existing file (48 lines, directory-listing
format), the constitution (`13 principles`), `ANTIPATTERNS.md` (3 registered
antipatterns), the test suite AGENTS.md (conventions), and
`references/architecture.md` (subsystem map). Produces a document with
sections covering: project overview and entry points, coding conventions
(Bash 3.2 patterns, library sourcing, error/event emission, atomic writes,
result protocol), testing patterns (suite structure, pass/fail functions,
fixture conventions), constitution v2.0 compliance checklist (all 13
principles as a bulleted checklist), PR review checklist, and anti-patterns
to avoid (referencing ANTIPATTERNS.md).

Full plan: `tasks/T01-PLAN.md`

### T02: Create `references/constitution-walkthrough.md` — 13 principles with codebase examples

Creates a new reference document that walks through each of the 13
constitution v2.0 principles with concrete codebase examples. For each
principle: restates the principle name, provides 1-2 sentences on what it
means, cites 2-3 real file paths from the codebase that exemplify the
principle, identifies common violations (drawing from ANTIPATTERNS.md and
real M001-M005 experience), and describes how to check compliance.

Full plan: `tasks/T02-PLAN.md`

### T03: Verification scripts and cross-link validation for P05

Creates all 9 verification scripts referenced in the Truths section above.
Each script is a standalone single-file invocation (AD-19 compliant) that
checks one specific property. After creating the scripts, reviews one real
M004 or M005 phase against the contributor guide to validate the guide is
actionable, and fixes any convention violations found.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (AGENTS.md) ───────────┐
T02 (constitution-walkthrough.md) ──┼──> T03 (verification + compliance review)
```

T01 and T02 are independent and can execute concurrently. T03 depends on
both because it validates the artifacts they produce and checks cross-links
between them.

## Files Likely Touched

- `scripts/AGENTS.md` (rewrite)
- `references/constitution-walkthrough.md` (create)
- `scripts/verify/m006-p05-agents-header.sh` (create)
- `scripts/verify/m006-p05-agents-bash32.sh` (create)
- `scripts/verify/m006-p05-agents-guards.sh` (create)
- `scripts/verify/m006-p05-agents-events.sh` (create)
- `scripts/verify/m006-p05-agents-testing.sh` (create)
- `scripts/verify/m006-p05-agents-checklists.sh` (create)
- `scripts/verify/m006-p05-walkthrough-header.sh` (create)
- `scripts/verify/m006-p05-walkthrough-principles.sh` (create)
- `scripts/verify/m006-p05-crosslinks.sh` (create)
- Bug fix commits for any convention violations found (files TBD)
