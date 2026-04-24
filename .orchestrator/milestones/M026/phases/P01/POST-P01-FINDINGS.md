---
schema_version: "1.0"
type: post-phase-findings
milestone: "M026"
phase: "P01"
created_at: "2026-04-24"
status: open
consumed_by: "M026/P02 plan-phase; adapter + template + references maintainers"
parent_artifacts:
  - .orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md
  - .orchestrator/milestones/M026/phases/P01/P01-SUMMARY.md
targets:
  - scripts/dispatch/adapters/tool/conversus.sh
  - references/provider-convention.md
  - templates/spec-template.md
  - scripts/verify/shape-lint.sh (and/or tests/shape/)
findings:
  - id: F1
    target: scripts/dispatch/adapters/tool/conversus.sh:345
    type: adapter-correctness
  - id: F2
    target: scripts/dispatch/adapters/tool/conversus.sh:285
    type: adapter-coverage
  - id: F3
    target: scripts/dispatch/adapters/tool/conversus.sh (preflight); references/provider-convention.md
    type: operator-ergonomics
  - id: F4
    target: templates/spec-template.md:28; shape-lint em-dash rule
    type: template-lint-conflict
---

# Post-P01 Findings — Hand-off to M026/P02 and adapter maintainers

Four findings surfaced by the P01 dogfood smoke (DOGFOOD-SMOKE-OSS.md) and
subsequent operator review. All four are orthogonal to the FR-1/FR-2 resolver
flip that is P02's committed scope, but F1–F3 are pulled toward P02 because
they materially affect gate-verdict reliability on the `claude-code` provider
path — which DOGFOOD-SMOKE-OSS.md §6 already demonstrates produces a
false-PASS today. F4 is a template-layer conflict that can ship
independently.

## F1 — Adapter rationale text is misleading on parser degradation

**Where**: `scripts/dispatch/adapters/tool/conversus.sh:345`
(`rationale: "${_summary}"` in the gate-result frontmatter heredoc).

**What**: The adapter embeds `linter.output_contract`'s `summary` field
verbatim as `rationale:`. When the parser's structural extraction
degrades (e.g., the §6 claude-code false-PASS where red-blue markers
weren't found and every quality-indicator field defaulted to 0), the
`summary` formula reads `"0 agents in <mode> mode completed 0 phases.
0 convergence points, 0 surviving disputes."` — technically correct
output from the parser, but actively misleading as a gate rationale
for a human reviewer who trusts the frontmatter.

**Proposed fix**: Prefer the arbiter's verdict text. Extract the first
paragraph of the `### Verdict` section from the synthesis file (or from
`arbiter/resolution.md` if present — see F2) and use that as
`rationale:`. Fall back to the `summary` formula only when neither is
extractable. The extracted rationale should be newline-collapsed to a
single frontmatter-safe line, matching the current `_summary`
post-processing at line 306.

**Why this matters**: a rationale derived from the verdict text will
always reflect what the deliberation actually concluded, even when
structural parsing has degraded. It also gives reviewers a
human-readable anchor that matches what they would see if they opened
the synthesis file by eye.

## F2 — Adapter reads only `summary/final.md`; arbiter output is authoritative when present

**Where**: `scripts/dispatch/adapters/tool/conversus.sh:285`
(`_synthesis="${_run_output_dir}/summary/final.md"`).

**What**: The new arbitration phase writes `arbiter/resolution.md` with
the authoritative ruling when arbitration ran. The adapter currently
ignores this file and reads only `summary/final.md`. When both exist,
the arbiter file is the more definitive verdict source.

**Proposed fix**: If `${_run_output_dir}/arbiter/resolution.md` exists,
prefer it as the verdict source (for the rationale extraction in F1 and
for any future verdict-derivation path that moves beyond the
`linter.output_contract` JSON). Keep `summary/final.md` as the fallback
and as the source for structural fields the arbiter file doesn't
emit (headline, disputes count via the existing
`linter.output_contract` invocation). Schema rule: **prefer arbiter
verdict, supplement with synthesis structural fields.**

**Why this matters**: the arbiter phase was added specifically because
synthesis alone can under-determine the PASS/BLOCK decision in
adversarial modes. Ignoring its output defeats the purpose.

## F3 — `CONVERSUS_PROVIDER=claude-code` is tribal knowledge; make it a documented preflight

**Where**: adapter preflight in `scripts/dispatch/adapters/tool/conversus.sh`
(new block before line 272 where `_provider="${CONVERSUS_PROVIDER:-anthropic}"`
is resolved); canonical doc in `references/provider-convention.md`.

**What**: Subscription-OAuth operators must set `CONVERSUS_PROVIDER=claude-code`
because the default `--provider anthropic` path is a policy gate — not a
transient rate limit — and will 429 deterministically on OAuth
credentials (captured as `feedback_conversus_provider_claude_code` in
user memory). This rule currently exists only as tribal knowledge and
cost ~90 minutes of debugging this session.

**Proposed fix** (two layers):

1. **Adapter preflight**: before resolving `_provider` at line 272, add
   a check: if `CONVERSUS_PROVIDER` is unset AND `~/.conversus/auth.json`
   shows a subscription-OAuth record (not an API-key record), emit a
   single-line warning to stderr and set `CONVERSUS_PROVIDER=claude-code`
   automatically for the run. Keep the operator's explicit setting if
   provided. Detection: parse `auth.json` for the provider entry that
   indicates OAuth vs API-key — consult `conversus status` output shape
   and/or `~/.conversus/auth.json` schema before finalizing the probe;
   this may require a short read of the OSS auth module.

2. **Canonical doc**: add a `## Provider selection on subscription OAuth`
   section to `references/provider-convention.md` stating the rule, the
   reason (policy gate vs. rate limit), the symptom (immediate 429 on
   first contact), and the auto-preflight behavior. Also add a header
   comment block at the top of `conversus.sh` pointing to that
   reference section.

**Why this matters**: F3 is the difference between gates that run and
gates that 429 on first contact. DOGFOOD-SMOKE-OSS.md §6 is the first
real-signal confirmation that `claude-code` path runs cleanly
end-to-end on OSS. Pairing it with automatic detection closes the
common operator-onboarding trap.

**Interaction with F1/F2**: on the `claude-code` path today, the gate
produces a false-PASS (§6). F3 makes the path easier to reach; F1 and
F2 make its verdicts trustworthy. All three travel together.

## F4 — `templates/spec-template.md` em-dash in User Story headers conflicts with shape-lint and brand-voice-forbidden projects

**Where**: `templates/spec-template.md:28`
(`### User Story 1 — <TODO: short-title> (Priority: P1)`); any subsequent
User Story header lines in the same template; the em-dash normalization
rule baked into the repo's shape-lint.

**What**: The User Story header uses an em-dash (`—`) as the separator
between the label and the title slot. Projects whose brand voice
forbids em-dashes have to fight the template on every spec authored.
The repo's own shape-lint bakes em-dash normalization in as a policy —
turning this into a consistent friction point rather than a one-off.

**Proposed fix**: Switch the separator from ` — ` to `: `. So:

```
### User Story 1: <TODO: short-title> (Priority: P1)
```

Update every `### User Story N` header line in `templates/spec-template.md`
and audit `commands/`, `references/`, and `docs/` for any hardcoded
User Story header strings that expect the em-dash form. Update the
shape-lint rule (or its test fixtures under `tests/shape/`) to expect
the colon form. Migration surface for existing specs: an opportunistic
pass — spec files already ingested do not re-read the template, so
existing content is undisturbed; new specs pick up the colon form on
next author.

**Why this matters**: the template is the first thing every new spec
inherits. Sticky punctuation in a template propagates to every
downstream artifact. Colon is neutral, matches common markdown
conventions for label: value headers, and does not conflict with any
brand voice guideline this repo has encountered.

## Scope suggestion for P02

- F1, F2, F3 are adapter-layer and ship well as one P02 task (they
  share the `conversus.sh` file and together restore gate-verdict
  reliability on the `claude-code` path). Recommend bundling.
- F4 is template-layer and independent. Can ship as a standalone
  docs/templates task in or out of M026 — no dependency on the
  resolver flip.
- None of F1–F4 change the P01 GO verdict or the FR-1/FR-2 resolver
  flip scope. They extend P02, they don't revise it.
