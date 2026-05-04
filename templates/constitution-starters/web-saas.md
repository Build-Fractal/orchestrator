---
schema_version: "1.0"
type: constitution-starter
stack: web-saas
---

# Constitution — {{project_type}}

This constitution governs the architectural decisions for a web-saas
project targeting {{target_user}} under the operating constraint of
{{primary_constraint}}. The 6 baseline principles below mirror the
orchestrator's own canonical baseline; the 2 web-saas-specific
principles (VII, VIII) extend the baseline for this stack.

## Constitution Check

Every plan and every implementation review for this {{project_type}}
MUST include an explicit constitution check section referencing each
applicable principle by Roman numeral. Violations require either a
documented rationale in a Complexity Tracking table or a design change
to achieve compliance.

## Core Principles

### Principle I. Context Minimization

Every architectural decision in this {{project_type}} MUST optimize for
minimizing the context each individual task consumes. Context is the
finite resource that {{target_user}} pays for indirectly via latency
and directly via cost; protecting it protects {{primary_constraint}}.

Distribute knowledge hierarchically — broad context near the root,
narrow context near the component. When a task needs context from a
prior task, deliver the prior task's structured summary, not its raw
session.

### Principle II. Evidence Before Claims

No task in this {{project_type}} is marked complete without fresh
verification evidence. "Should work" is not evidence. "Tests passed
last time" is not evidence. The verification sequence is: run the
command → read the output → confirm the result matches expectations
→ then claim completion.

For a web-saas serving {{target_user}} under {{primary_constraint}},
"complete" means the user-visible flow works end-to-end against a real
backing service — not against a mock.

### Principle III. Design Before Code

Every piece of work in this {{project_type}} MUST go through an
explicit design step, no matter how simple it seems. Simple features
are where unexamined assumptions about {{target_user}} cause the most
wasted work. Brainstorm → plan → execute → review.

The design step MUST surface uncertainty about {{primary_constraint}}
trade-offs rather than hide them. When a requirement has multiple
valid interpretations, enumerate them and state which was chosen.

### Principle IV. Plans Assume Zero Context

Implementation plans for this {{project_type}} MUST be written as if
the executing agent has zero codebase context. Document everything:
exact file paths, complete code, exact commands with expected output,
verification steps with expected results.

A plan that requires the executor to "figure it out" or "use
judgment" is an incomplete plan; for a web-saas serving {{target_user}}
under {{primary_constraint}}, that ambiguity is where regressions live.

### Principle V. State On Disk Is Truth

No in-memory state across sessions for this {{project_type}}. All
state MUST be recoverable from files on disk (or from the canonical
backing store — database rows, blob keys, queue records). Crash
recovery derives entirely from durable state; in-memory caches are
optimizations, not sources of truth.

If the operation under {{primary_constraint}} is not durable, it did
not happen.

### Principle VI. Knowledge Compounds

Every phase of work in this {{project_type}} MUST produce structured,
discoverable documentation: what was built, what patterns were used,
what decisions were made, what was learned about {{target_user}}.

Knowledge compounds — each task that documents well makes every
future task targeting {{target_user}} cheaper to execute. Knowledge
artifacts are mandatory outputs at every level.

## Web-SaaS Specific Principles

### Principle VII. Idempotent Deploys

Every deploy of this {{project_type}} MUST be idempotent. Re-running
the same deploy against the same target MUST produce the same final
state — no duplicate resources, no orphaned migrations, no surprise
charges that violate {{primary_constraint}}.

Database migrations MUST be reversible (or carry a documented forward-
only justification). Feature flags gate user-visible cutovers so
{{target_user}} sees a single coherent state at any moment.

### Principle VIII. User Data Privacy

User data belonging to {{target_user}} is the highest-priority asset
of this {{project_type}}. Every read, write, and export path MUST be
auditable; every retention boundary MUST be declared in code, not in
runbook prose.

PII fields MUST be tagged at the schema level. Logs MUST NOT carry
raw PII; structured fields with PII MUST be redacted at the log-
emission boundary. {{primary_constraint}} compliance starts with
making the privacy posture of every code path visible.
