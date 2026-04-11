---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T01 (Phase P01, Milestone M004)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge | 19-21 | ~100 | filtered |
| Decisions | 23-25 | ~100 | filtered |
| Scope | 27-55 | ~300 | required |
| Upstream Context | 57-59 | ~100 | required |
| Task Plan | 61-288 | ~2700 | required |
| State Context | 290-296 | ~100 | required |
| Constraints | 298-303 | ~100 | required |
| **Total** | | **~3500** | |

## Knowledge

No knowledge entries in scope.

## Decisions

No decision entries in scope.

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

### Truths

- The constitution contains exactly 13 numbered principles (I through XIII)
  - Check: `test "$(grep -c '^### [IVXLC]*\.' .specify/memory/constitution.md)" -ge 13`
- Principle II text includes requirement for structured event emission from engine-managed scripts
  - Check: `grep -q 'structured event' .specify/memory/constitution.md`
- Constitution version string is 2.0.0
  - Check: `grep -q 'Version.*2\.0\.0' .specify/memory/constitution.md`
- Sync Impact Report exists as an HTML comment in the constitution file
  - Check: `grep -q 'Sync Impact Report' .specify/memory/constitution.md`
- ANTIPATTERNS.md has at least 2 antipattern entries with real incident references
  - Check: `test "$(grep -c '^## AP-' ANTIPATTERNS.md)" -ge 2`
- Antipattern entries reference specific milestones (M001, M002, or M003) as evidence
  - Check: `grep -q 'M00[123]' ANTIPATTERNS.md`

### Artifacts

- `.specify/memory/constitution.md` (min 280 lines, contains "2.0.0")

## Upstream Context

No upstream summaries available.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M004"
name: "Constitution v2.0.0"
depends_on: []
---

## Description

Update the orchestrator constitution from v1.0.0 to v2.0.0. This is a MAJOR version bump because it adds 6 new principles (VIII-XIII), amends 1 existing principle (II), and codifies patterns learned from Conversus and index-pipeline analysis. The new principles establish governance for the engine architecture being built in M004.

## Steps

### Step 1: Read the current constitution

Read `.specify/memory/constitution.md`. The current file has:
- 7 principles (I through VII) under `## Core Principles`
- Sections: Constraints, Quality Gates, Governance
- An HTML comment block at the top containing the Sync Impact Report
- Version line at the bottom: `**Version**: 1.0.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-03-18`

### Step 2: Amend Principle II (Evidence Before Claims)

Add a new bullet point to Principle II after the existing bullets. The amendment requires structured event emission:

```markdown
- Engine-managed scripts MUST emit structured events (`emit_event`)
  and a final result (`emit_result`). A script that runs to
  completion without emitting a RESULT line is treated as a silent
  failure. Events are the observable evidence trail for engine
  coordination — they are NOT optional instrumentation.
```

### Step 3: Add 6 new principles after Principle VII

Add these principles in order, continuing the existing formatting style (### heading with roman numeral, description paragraph, then bullet points):

**VIII. No Dead Infrastructure**

Every file, script, template, and configuration entry MUST be reachable from a live code path. Infrastructure that exists "for future use" or "just in case" violates Context Minimization (Principle I) by consuming context budget without delivering value.

- New files MUST be referenced by at least one command, script, or template before the phase is marked complete.
- Audit tooling (`run-doctor.sh`) MUST detect unreachable files and report them as warnings.
- Removing dead infrastructure is always cheaper than maintaining it. When in doubt, delete.

**IX. Reproducibility Over Convenience**

Given identical inputs (disk state, configuration, environment), any orchestrator operation MUST produce identical outputs. Non-determinism is a bug, not a feature.

- No inline `date` calls — use `$ORCH_STARTED_AT` or run-context timestamps.
- No random identifiers without seed control — `ORCH_RUN_ID` is deterministic when seeded.
- Recipe-driven assembly produces the same payload given the same recipe and source files.
- If a script's output varies between runs with identical inputs, it is broken.

**X. Templating Over Inference**

Configuration and policy MUST be declared in templates (YAML recipes, routing config, hooks config), not inferred by scripts at runtime. Scripts implement mechanics; templates declare policy.

- Context assembly sections, order, and priority: declared in `context-recipe.yaml`.
- Compression strategy and thresholds: declared in the recipe's `compression:` block.
- Model selection and fallback chains: declared in `routing.yaml`.
- Hook lifecycle points and behavior: declared in `hooks.yaml`.
- When a behavior is controlled by a template, changing it requires editing the template — not the script. This is the design goal.

**XI. Single Source of Truth**

Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen.

- State: derived from disk by `derive-phase.sh` — no cached state variables.
- Configuration: `orchestrator-config.yml` with specificity resolution (task > phase > milestone > default).
- Knowledge: three-temperature storage (hot index, warm detail files, cold archive) with one entry per concept.
- Roadmap phase status: the roadmap file is the single source; phase directories are artifacts, not status indicators.

**XII. Hook Isolation**

Hook scripts operate in a sandbox: they receive a read-only state snapshot and produce stdout/stderr output. They MUST NOT modify engine state, write to orchestrator directories, or have side effects on the dispatch pipeline.

- State snapshots are `chmod 444` temp files deleted after hook execution.
- Hooks that violate isolation (force-write to snapshot, write to orchestrator paths) trigger a `HOOK_VIOLATION` event.
- Hook timeout is enforced (default 30s). Hooks that exceed timeout are killed and recorded as failures.
- This principle exists because hooks are the integration seam for external tools (Conversus, monitoring). An untrusted hook MUST NOT be able to corrupt orchestrator state.

**XIII. Agent Instruction Schema**

Dispatch instructions (the payload assembled for executing agents) MUST follow a declared, inspectable schema. Ad-hoc instruction assembly produces inconsistent agent behavior and prevents variance analysis.

- The instruction schema declares required sections, optional sections, and section ordering.
- Context recipes (`context-recipe.yaml`) are the mechanism for schema declaration.
- New instruction formats require a recipe change — not a script change.
- This principle enables systematic analysis of what context agents receive and how it correlates with task outcomes. Progressive migration: new instructions conform immediately, existing instructions migrate as they are touched.

### Step 4: Update the Sync Impact Report

Replace the existing HTML comment block at the top of the file with an updated Sync Impact Report:

```html
<!--
  Sync Impact Report
  ==================
  Version change: 1.0.0 → 2.0.0 (MAJOR — new principles change compliance requirements)

  Added principles:
    - VIII. No Dead Infrastructure
    - IX. Reproducibility Over Convenience
    - X. Templating Over Inference
    - XI. Single Source of Truth
    - XII. Hook Isolation
    - XIII. Agent Instruction Schema

  Amended principles:
    - II. Evidence Before Claims — added structured event emission requirement
      for engine-managed scripts (emit_event / emit_result)

  Unchanged principles:
    - I. Context Minimization
    - III. Design Before Code
    - IV. Plans Assume Zero Context
    - V. Fresh Context Per Unit
    - VI. State On Disk Is Truth
    - VII. Knowledge Compounds

  Unchanged sections:
    - Constraints (no changes)
    - Quality Gates (no changes)
    - Governance (no changes)

  Templates requiring updates:
    ⚠️ templates/phase-plan.md — Constitution Check should reference
       principles VIII-XIII where applicable. Low urgency: templates
       dynamically load constitution; no hardcoded principle references.
    ✅ All other templates — no constitution-specific references to update.

  Follow-up TODOs:
    - Phase plans from M004 P02+ should reference new principles in
      their must-haves where applicable.
    - run-doctor.sh conformance check (P07) will verify principle
      references in phase plans.
-->
```

### Step 5: Update the version line

Replace the version line at the bottom of the file:

```markdown
**Version**: 2.0.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-04-10
```

### Step 6: Verify

Run these verification commands:

```bash
# Count principles — expect >= 13
grep -c '^### [IVXLC]*\.' .specify/memory/constitution.md

# Check Principle II amendment
grep -q 'structured event' .specify/memory/constitution.md && echo "PASS: Principle II amended" || echo "FAIL"

# Check version
grep -q 'Version.*2\.0\.0' .specify/memory/constitution.md && echo "PASS: Version 2.0.0" || echo "FAIL"

# Check Sync Impact Report
grep -q 'Sync Impact Report' .specify/memory/constitution.md && echo "PASS: Sync Impact Report" || echo "FAIL"

# Check new principles exist
for p in "No Dead Infrastructure" "Reproducibility" "Single Source of Truth" "Templating Over Inference" "Hook Isolation" "Agent Instruction Schema"; do
  grep -q "$p" .specify/memory/constitution.md && echo "PASS: $p" || echo "FAIL: $p"
done
```

## Must-Haves

### Truths

- The constitution contains exactly 13 numbered principles (I through XIII)
  - Check: `test "$(grep -c '^### [IVXLC]*\.' .specify/memory/constitution.md)" -ge 13`
- Principle II text includes requirement for structured event emission from engine-managed scripts
  - Check: `grep -q 'structured event' .specify/memory/constitution.md`
- Constitution version string is 2.0.0
  - Check: `grep -q 'Version.*2\.0\.0' .specify/memory/constitution.md`
- Sync Impact Report exists as an HTML comment in the constitution file
  - Check: `grep -q 'Sync Impact Report' .specify/memory/constitution.md`

### Artifacts

- `.specify/memory/constitution.md` (min 280 lines, contains "2.0.0")

## Verification

```bash
# All checks in one pass
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T01 Verification ==="
count=$(grep -c '^### [IVXLC]*\.' .specify/memory/constitution.md)
test "$count" -ge 13 && echo "PASS: $count principles found" || echo "FAIL: only $count principles"
grep -q 'structured event' .specify/memory/constitution.md && echo "PASS: Principle II amended" || echo "FAIL: Principle II not amended"
grep -q 'Version.*2\.0\.0' .specify/memory/constitution.md && echo "PASS: Version 2.0.0" || echo "FAIL: Version not 2.0.0"
grep -q 'Sync Impact Report' .specify/memory/constitution.md && echo "PASS: Sync Impact Report present" || echo "FAIL: Sync Impact Report missing"
lines=$(wc -l < .specify/memory/constitution.md | tr -d ' ')
test "$lines" -ge 280 && echo "PASS: $lines lines (min 280)" || echo "FAIL: only $lines lines"
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — The current v1.0.0 constitution with 7 principles (I-VII), Constraints, Quality Gates, and Governance sections. This task modifies this file in place.
- `specs/004-engine-architecture/spec.md` — FR-230 through FR-233, US7 acceptance scenarios define the requirements for the constitution update.
- `.specify/orchestrator/milestones/M004/M004-CONTEXT.md` — AD-10 (MAJOR version bump), AD-11 (antipatterns are permanent). Architectural decisions that constrain this task.

## Expected Output

The file `.specify/memory/constitution.md` updated to v2.0.0 with:
- 13 principles (I-XIII) under `## Core Principles`
- Principle II amended with structured event emission requirement
- Updated Sync Impact Report HTML comment at top
- Version line showing `2.0.0` with amended date `2026-04-10`
- All existing sections (Constraints, Quality Gates, Governance) unchanged

## State Context

- **Current State**: executing
- **Milestone**: M004
- **Phase**: P01
- **Task**: T01
- **Tier**: C

## Constraints

- **Verification Criteria**: See phase plan must-haves
- **Duration Budget**: 2h
- **Dispatch Budget**: 3
- **Budget Enforcement**: warn