# Constitution Starter Format

This reference documents the file format for constitution-starter
templates under `templates/constitution-starters/`. Each starter is the
seed for `commands/constitution.md` (M033/P03/T02) — a stack-aware
front door that produces the destination project's
`.orchestrator/memory/constitution.md` after a grilling-shell pass.

The format below is the v1 closed contract. The associated lint
verifier `scripts/verify/constitution-shape-lint.sh` (FR-5) enforces
the structural invariants at write time; the standalone gate
`scripts/verify/standalone-gate.sh` (FR-6) enforces the
distribution-surface invariant (Principle XVI).

## File Format

### YAML Frontmatter

Every starter MUST begin with YAML frontmatter delimited by `---`:

```yaml
---
schema_version: "1.0"
type: constitution-starter
stack: <stack-name>
---
```

- `schema_version` — closed at "1.0" until a breaking change forces a
  bump (per MEM013 template-convention precedent).
- `type` — closed at `constitution-starter`. The discriminator
  downstream tooling matches on.
- `stack` — one of the v1 closed enum: `web-saas`, `cli-tool`,
  `library`. Adding a stack requires editing the closed enum below
  AND adding the corresponding starter file in the same change.

### Title

The first body line MUST be a level-1 heading containing the
`{{project_type}}` placeholder:

```markdown
# Constitution — {{project_type}}
```

### Constitution Check Section

Every starter MUST include a `## Constitution Check` section header.
This anchor is load-bearing: `commands/specify.md` cross-references the
section by literal token grep at lines 86, 99, 115, and downstream
plan-time and review-time gates assert the presence of the section as
the structural anchor for the constitution check.

### Principle Sub-Headers

Principles MUST use Roman-numeral level-3 sub-headers:

```markdown
### Principle I. <Name>

<2–4 lines of body prose>
```

- The `### Principle <Roman-numeral>` shape is the canonical principle
  anchor. The lint counts headers matching `^### Principle [IVX]+`.
- Each starter MUST ship at least 6 baseline principles (Roman numerals
  I through VI). The orchestrator's own baseline (Context Minimization
  / Evidence Before Claims / Design Before Code / Plans Assume Zero
  Context / State On Disk Is Truth / Knowledge Compounds) is the
  canonical seed. Project-specific framing of the same baseline is
  encouraged; the principle *names* should remain stable.
- Each starter MUST ship 2–3 stack-specific principles (Roman numerals
  VII, VIII, optionally IX). These are the stack's identity.
- Each principle body MUST be non-empty (the lint asserts at least one
  non-blank, non-header line between principle headers).

### Placeholder Vocabulary

The v1 closed placeholder vocabulary consumed by T02's
`scripts/lifecycle/constitution-author.sh`:

- `{{project_type}}` — the project's identity (e.g., "B2B
  scheduling SaaS", "developer-facing CLI", "Python data-pipeline
  helper library").
- `{{primary_constraint}}` — the dominant operating constraint
  (e.g., "SOC 2 Type II compliance", "single-binary distribution",
  "API stability across major versions").
- `{{target_user}}` — the user the project serves (e.g., "small-team
  ops engineers", "shell power-users", "downstream Python data
  teams").

All `{{...}}` placeholders MUST be resolved before the file is
written. The FR-5 lint asserts zero literal `{{` strings remain;
unresolved placeholders are a grilling-shell failure that MUST block
write.

## Closed v1 Stack List

- `web-saas` — multi-tenant web applications, hosted operations,
  user-data-bearing surfaces.
- `cli-tool` — single-binary or interpreted command-line tools
  composed in shell pipelines.
- `library` — reusable code distributed via package managers and
  consumed by other developers' projects.

## Demand-Driven Expansion (per #Q-2)

The v1 list is closed deliberately. Per #Q-2 in the M033 spec:

> **≥2 distinct external requests for a stack post-launch trigger
> expansion of that stack; no speculative pre-build.**

Until a stack accumulates two distinct external requests, the closed
list does not expand. This avoids the
"speculative-stack-templates-nobody-uses" failure mode and keeps the
maintenance surface small.

## Community Contributions

A future M033.5 may extend the v1 stack list per #Q-2 demand signal.
Until then, projects whose stack is not represented should:

1. Pick the closest v1 starter (`web-saas` for hosted services,
   `cli-tool` for command-line tools, `library` for distributed
   reusable code).
2. Fork it locally as `templates/constitution-starters/<custom>.md`
   in the destination project.
3. Open a follow-up D-row in `.orchestrator/DECISIONS.md` documenting
   the gap and the workaround.

The follow-up D-row is the demand signal that aggregates toward the
#Q-2 threshold; without it, the gap is invisible to the maintainers.

## Verifier Coverage

- `scripts/verify/constitution-shape-lint.sh <path>` — FR-5 shape
  lint. Asserts the four structural invariants (Constitution Check
  header, ≥6 Roman-numeral principle headers, non-empty bodies,
  zero placeholder leakage).
- `scripts/verify/standalone-gate.sh constitution` — FR-6 / Principle
  XVI standalone gate. Scans the closed surface (this reference, the
  three starters, the lint, T02's `commands/constitution.md` and
  `scripts/lifecycle/constitution-author.sh`) for any case-insensitive
  reference to the upstream-framework shorthand (the literal substring
  the gate scans for is intentionally elided here so the reference does
  not trip its own scan); zero matches required.
- `tools/verify/m033-p03-constitution-starter-templates-shape.sh` —
  per-starter shape (frontmatter + section + principle count + stack-
  specific tokens + placeholder presence).
- `tools/verify/m033-p03-constitution-starter-format-ref-shape.sh` —
  this reference's own shape verifier.
