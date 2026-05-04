---
schema_version: "1.0"
type: constitution-starter
stack: library
---

# Constitution — {{project_type}}

This constitution governs the architectural decisions for a library
project targeting {{target_user}} under the operating constraint of
{{primary_constraint}}. The 6 baseline principles below mirror the
orchestrator's own canonical baseline; the 2 library-specific
principles (VII, VIII) extend the baseline for this stack.

## Constitution Check

Every plan and every implementation review for this {{project_type}}
MUST include an explicit constitution check section referencing each
applicable principle by Roman numeral. Violations require either a
documented rationale in a Complexity Tracking table or a design change
to achieve compliance.

## Core Principles

### Principle I. Context Minimization

Every architectural decision in this {{project_type}} MUST optimize
for minimizing the context each individual task consumes. A library
ships into other people's projects — {{target_user}}'s context is
already saturated with their own code, so every byte of API surface
the library imposes is a tax.

Distribute knowledge hierarchically — broad context in the README,
narrow context in module-level docstrings. The smaller the public
surface, the lower the cognitive cost.

### Principle II. Evidence Before Claims

No task in this {{project_type}} is marked complete without fresh
verification evidence. "Should work" is not evidence. The verification
sequence is: run the command → read the output → confirm the result
matches expectations → then claim completion.

For a library serving {{target_user}} under {{primary_constraint}},
"complete" means the public API works end-to-end against a downstream
consumer — not just against the library's own tests.

### Principle III. Design Before Code

Every piece of work in this {{project_type}} MUST go through an
explicit design step. The public API is contractual — once a function
signature ships, changing it breaks {{target_user}}'s build.
Brainstorm → plan → execute → review.

The design step MUST surface API-shape alternatives before picking
one. {{primary_constraint}} compliance is impossible if every release
is a breaking change; design choice has multi-version consequences.

### Principle IV. Plans Assume Zero Context

Implementation plans for this {{project_type}} MUST be written as if
the executing agent has zero codebase context. Document exact file
paths, exact function signatures, exact commands with expected output.
A plan that requires the executor to "figure it out" is incomplete.

For a library under {{primary_constraint}}, ambiguity in the plan
becomes ambiguity in the documentation, which becomes a support burden
for {{target_user}}.

### Principle V. State On Disk Is Truth

No in-memory state surviving across consumer invocations of this
{{project_type}}. If the library caches, the cache MUST be either
process-local (cleared on consumer exit) or backed by an explicit
disk artifact the consumer controls.

Globals and ambient process state under {{primary_constraint}} are
sources of non-reproducibility — and for a library, they leak into
{{target_user}}'s test suites as flakiness. Eliminate them at the
boundary.

### Principle VI. Knowledge Compounds

Every phase of work in this {{project_type}} MUST produce structured,
discoverable documentation: what was built, what patterns were used,
what decisions were made, what was learned about {{target_user}}'s
integration patterns.

Knowledge compounds — every well-documented function makes the next
consumer's onboarding cheaper.

## Library Specific Principles

### Principle VII. Stable API Surface

The public API of this {{project_type}} is a contract with
{{target_user}}. Once a name is exported, removing or changing it MUST
follow a documented deprecation cycle: at minimum, one minor version
of warning before any breaking change.

Internal helpers MUST be marked private (underscore prefix, `_internal`
module, or language-level visibility). {{target_user}}'s reliance on
"it happened to work" is the library author's problem to manage, not
to dismiss. {{primary_constraint}} is met by treating the public
surface as the load-bearing contract it is.

### Principle VIII. Semantic Versioning Discipline

This {{project_type}} MUST follow semantic versioning rigorously:
MAJOR for breaking changes, MINOR for backward-compatible additions,
PATCH for backward-compatible fixes. {{target_user}} pins versions in
their dependency manifest; a misclassified release breaks downstream
builds without warning.

Every release MUST ship a CHANGELOG entry mapping the version bump to
the rationale: which symbols were added, deprecated, or removed.
{{primary_constraint}} on stability lives in the discipline of the
version-bump decision, not in the source code itself.
