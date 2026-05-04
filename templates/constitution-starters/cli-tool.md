---
schema_version: "1.0"
type: constitution-starter
stack: cli-tool
---

# Constitution — {{project_type}}

This constitution governs the architectural decisions for a cli-tool
project targeting {{target_user}} under the operating constraint of
{{primary_constraint}}. The 6 baseline principles below mirror the
orchestrator's own canonical baseline; the 2 cli-tool-specific
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
for minimizing the context each individual task consumes. CLI tools
ship into hostile environments — slow shells, locked-down CI runners,
constrained terminals — and {{target_user}} pays the latency tax for
every byte of unnecessary work.

Distribute knowledge hierarchically — broad context near the root,
narrow context near the component. Each subcommand should fit in its
own head.

### Principle II. Evidence Before Claims

No task in this {{project_type}} is marked complete without fresh
verification evidence. "Should work" is not evidence. The verification
sequence is: run the command → read the output → confirm the result
matches expectations → then claim completion.

For a cli-tool serving {{target_user}} under {{primary_constraint}},
"complete" means the tool runs end-to-end on a clean shell against a
representative input — not just against a unit test.

### Principle III. Design Before Code

Every piece of work in this {{project_type}} MUST go through an
explicit design step. The CLI surface is contractual — once a flag
ships, removing it breaks {{target_user}} workflows. Brainstorm →
plan → execute → review.

The design step MUST surface uncertainty about {{primary_constraint}}
trade-offs rather than hide them. Enumerate flag-naming alternatives
before picking one; future-proofing is cheaper than deprecation.

### Principle IV. Plans Assume Zero Context

Implementation plans for this {{project_type}} MUST be written as if
the executing agent has zero codebase context. Document exact file
paths, complete code, exact commands with expected output. A plan
that requires the executor to "figure it out" is an incomplete plan.

For a cli-tool under {{primary_constraint}}, ambiguity in the plan
becomes ambiguity in the help text, which becomes friction for
{{target_user}}.

### Principle V. State On Disk Is Truth

No in-memory state across invocations for this {{project_type}}. The
tool MUST be recoverable from files on disk — config, lock files,
state directories. If a CLI invocation crashes mid-run, the next
invocation MUST be able to derive what happened from disk state alone.

Globals and ambient process state under {{primary_constraint}} are
sources of non-reproducibility; eliminate them at the boundary.

### Principle VI. Knowledge Compounds

Every phase of work in this {{project_type}} MUST produce structured,
discoverable documentation: what was built, what patterns were used,
what decisions were made, what was learned about {{target_user}}'s
shell environment and habits.

Knowledge compounds — each task that documents well makes the next
flag, the next subcommand, the next deprecation cheaper.

## CLI-Tool Specific Principles

### Principle VII. Composable Default Exit Codes

This {{project_type}} MUST follow the convention that exit code 0
indicates success and any non-zero code indicates a specific failure
mode. {{target_user}} composes CLI tools in pipelines and `set -e`
scripts; an inconsistent exit-code contract breaks composition.

Document every non-zero exit code in `--help` output. Reserve
specific codes for canonical failure modes (e.g., 2 for usage error,
65 for bad input data per sysexits.h). {{primary_constraint}} demands
predictability: pipelines that depend on exit-code semantics MUST be
able to rely on them.

### Principle VIII. POSIX Convention Adherence

This {{project_type}} MUST adhere to POSIX CLI conventions where they
exist: short flags use `-x`, long flags use `--long`, `--` terminates
flag parsing, `-` reads from stdin / writes to stdout when context
permits. {{target_user}} carries muscle memory across tools; breaking
convention to be clever costs more than it saves.

Where POSIX is silent, follow GNU convention. Where both are silent,
match the closest precedent in {{target_user}}'s existing toolchain.
{{primary_constraint}} is met by leaning on convention, not inventing
new ones.
