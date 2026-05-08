---
schema_version: "1.0"
type: instruction-schema
description: "Declares required and optional section headings for agent instruction files."
---

# Instruction Schema

This schema defines the required and optional section groups that every agent
instruction file (`commands/*.md`) must contain. Conformance is checked by
`scripts/diagnostics/check-instructions.sh` and surfaced via the `doctor`
command.

Each group lists canonical heading aliases. An instruction file satisfies a
group when it contains at least one `## ` heading whose text matches any alias
in the group (case-sensitive, exact match after `## `).

---

## Required Sections

Every instruction file MUST contain at least one heading from each of the
following five groups.

### 1. Context

Establishes what state the agent needs before acting.

**Aliases**: Context, Prerequisites, State Context, State Derivation, Context Gathering

```markdown
## Context
## Prerequisites
## State Context
## State Derivation
## Context Gathering
```

### 2. Task

Defines the primary action or scope of the command.

**Aliases**: Task, Scope, Phase Planning, What It Checks, Usage, Context Construction, Dispatch Strategy

```markdown
## Task
## Scope
## Phase Planning
## What It Checks
## Usage
## Context Construction
## Dispatch Strategy
```

### 3. Constraints

Declares limits, error handling, and safety invariants.

**Aliases**: Constraints, Error Handling, Gotchas, Idempotency, Concurrent Safety, Budget Gates

```markdown
## Constraints
## Error Handling
## Gotchas
## Idempotency
## Concurrent Safety
## Budget Gates
```

### 4. Verification

Specifies how to confirm the command succeeded.

**Aliases**: Verification, Post-Dispatch, Validation, Must-Haves, Tier 1

```markdown
## Verification
## Post-Dispatch
## Validation
## Must-Haves
## Tier 1
```

### 5. Output Format

Describes the shape and location of produced artifacts.

**Aliases**: Output Format, Expected Output, Output, Referenced Templates, Payload Size Guidance

```markdown
## Output Format
## Expected Output
## Output
## Referenced Templates
## Payload Size Guidance
```

---

## Optional Sections

These groups are recommended but not enforced by default.

### 6. Prior Art

References existing scripts or files that inform the command.

**Aliases**: Prior Art, Referenced Scripts, Reference Files

```markdown
## Prior Art
## Referenced Scripts
## Reference Files
```

### 7. Related Knowledge

Links to upstream context, knowledge entries, or architectural decisions.

**Aliases**: Related Knowledge, Upstream Context, Knowledge, Decisions

```markdown
## Related Knowledge
## Upstream Context
## Knowledge
## Decisions
```

---

## Schema Skeleton

A minimal conforming instruction file looks like:

```markdown
---
description: "One-line summary."
---

# orchestrator:<command>

Brief intro.

## Context

<!-- or any Context alias -->

## Task

<!-- or any Task alias -->

## Constraints

<!-- or any Constraints alias -->

## Verification

<!-- or any Verification alias -->

## Output Format

<!-- or any Output Format alias -->
```

The active heading shape is `# orchestrator:<command>`. Pre-M035 P01.5
instruction files used the legacy `# speckit.orchestrator.<command>`
namespaced-alias shape; that form is preserved in historical and
migration documentation only (see `commands/migrate.md` AD-15) and is
NOT a live registration surface post-M035 P01.5.
