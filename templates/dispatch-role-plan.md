---
schema_version: "1.0"
type: dispatch-role
role: plan
---

# Dispatch Role -- Plan (Tier A+ middle flow)

This template is consumed by the Tier A+ router (M031 P02 T04). It
declares the prescriptive output shape, the dispatch-payload requirements,
and the constraints that govern the plan-role dispatch. The plan role
fires after the research role completes; its dispatch payload includes
the upstream `research.md` as a `From Previous Tasks` input.

## Goal

Read the upstream `research.md` and produce a single `PLAN.md` with
explicit Steps, Verification commands, Inputs, and Files Likely Touched.
The plan MUST be self-contained -- an executor reading only `PLAN.md`
plus the codebase MUST be able to ship without re-reading `research.md`.

## Output Shape

The plan dispatch produces a single markdown file at
`.orchestrator/tier-a-plus/<task-slug>/plan.md`. The file MUST contain
the following sections, in order, each populated:

- `## Steps` -- numbered steps. Each step names exact file paths
  (`scripts/foo/bar.sh`, `templates/baz.md`, etc.) and the action
  verb (Create, Edit, Delete, Run). Steps are ordered such that an
  executor working top-to-bottom never reads from a file before the
  step that creates it.
- `## Verification` -- one or more executable command lines. Every
  command line MUST be a single-script-file invocation per AD-19
  (`bash <path-to-script>` or `bash <path-to-script> <args>`); inline
  compound bash (`for`, `if`, `&&`, `||`, `$(...)`, plain subshells) is
  rejected. A plan with zero verification commands is invalid -- the
  build dispatch refuses to run against an unverifiable plan.
- `## Inputs` -- bullet points naming every upstream file the plan
  reads (the upstream `research.md`, any fixtures, any reference docs).
- `## Files Likely Touched` -- bullet points naming every file the
  build dispatch will create or modify. The list is exhaustive: any
  file edited at build time but not listed here invalidates the plan.

## Dispatch Payload Requirements

- The plan dispatch is built via
  `bash scripts/dispatch/build-context.sh --profile=quick` (P01
  contract). Quick-profile knowledge inject fires; the AD-11 sidecar
  is captured at
  `.orchestrator/tier-a-plus/<task-slug>/plan.meta.json`.
- The upstream `research.md` is included as a `From Previous Tasks`
  input in the plan dispatch's payload. The router copies the
  research.md body verbatim into the dispatch payload between the
  knowledge section and the role-template body so the plan dispatch
  has the research findings in-context.

## Constraints

- **Single-script-file verifiers** (AD-19): every command line under
  `## Verification` MUST be a `bash <path>` invocation. Inline `for`
  loops, `if` expressions, `$(...)` substitutions, and `&&`/`||` chains
  are rejected -- helper scripts go under `tools/verify/` or
  `scripts/util/` instead.
- **Plain prose**: no scaffold-placeholder bracket-TODO byte pattern
  appears in the plan body. Paraphrase or escape when the pattern
  must be discussed.
- **One context window**: the plan MUST be reachable in one context
  window. If the plan body grows past the target length, the plan
  dispatch escalates to Tier B (full milestone scaffolding) rather
  than emitting a plan that the build cannot fit in one shot.
- **Self-containment**: the build dispatch reads only the plan body
  plus the codebase. It does NOT re-read the research.md (the plan
  has already distilled the relevant findings).

## Inputs

The plan dispatch payload includes:

- The user's original task description.
- The Quick-profile knowledge inject.
- The upstream `research.md` body (verbatim, as a `From Previous
  Tasks` block).

## Notes

- The output filename `plan.md` is fixed by the AD-10 path convention.
  Downstream `build` dispatches read the file by literal name.
- A plan without any `## Verification` command line is rejected at
  build time -- the build dispatch exits non-zero with a diagnostic
  pointing back to this template's Output Shape requirement.
- The role template is consumed verbatim by the router; literal
  substring changes are normative dispatch-contract changes.
