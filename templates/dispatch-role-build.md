---
schema_version: "1.0"
type: dispatch-role
role: build
---

# Dispatch Role -- Build (Tier A+ middle flow)

This template is consumed by the Tier A+ router (M031 P02 T04). It
declares the prescriptive execution contract for the build-role
dispatch on a Tier A+ input. The build role is the last leg of the
research -> plan -> build chain; its dispatch payload includes the
upstream `plan.md` as the primary `Inputs` file.

## Goal

Read the upstream `plan.md` and execute every `## Steps` item, then
run every `## Verification` command inline; exit non-zero if any
verifier fails.

## Output Shape

The build role does NOT emit a per-role markdown file under
`.orchestrator/tier-a-plus/<task-slug>/`. The build's deliverables are:

- The source-file edits described by the plan's `## Steps` and
  `## Files Likely Touched` sections (real edits to the codebase, not
  scratch artifacts).
- The exit code from the inlined `## Verification` command lines.
- A `unit_close` JSONL record carrying `tier_a_plus_role: build` plus
  the consolidated verifier-pass result. The record lands on the
  appropriate execution-log JSONL stream per the orchestrator's
  unit-close convention.

The build role does NOT write a `build.md` summary -- the source-file
edits plus the verifier exit code are the deliverable. Operator
debriefs (when needed) live in the Tier A+ router's prompt summary,
not in a per-role markdown artifact.

## Dispatch Payload Requirements

- The build dispatch is built via
  `bash scripts/dispatch/build-context.sh --profile=quick` (P01
  contract). Quick-profile knowledge inject fires; the AD-11 sidecar
  is captured at
  `.orchestrator/tier-a-plus/<task-slug>/build.meta.json`.
- The upstream `plan.md` is included as the primary `Inputs` file in
  the build dispatch's payload. The router copies the plan.md body
  verbatim into the dispatch payload between the knowledge section
  and the role-template body so the build dispatch has the plan in
  hand without re-reading it from disk.

## Constraints

- **Inline verifiers in single-script-file form** (AD-19): every
  verifier the build runs MUST be invoked as `bash <path-to-script>`
  inline. Inline compound bash, process substitution, and inline
  `$(...)` are rejected. The plan author owns the AD-19 discipline at
  plan-authoring time; the build dispatch consumes the plan as-is.
- **No implicit retry on failure**: on the first verifier failure, the
  build dispatch exits non-zero immediately. There is no retry loop,
  no fall-through to the next verifier, no auto-escalation. The
  operator decides whether to re-dispatch or escalate to Tier B per
  the Tier A+ spec edge case.
- **Plain prose**: no scaffold-placeholder bracket-TODO byte pattern
  appears in any build-emitted artifact (commit messages, JSONL
  records, etc.). Paraphrase or escape when the pattern must be
  discussed.
- **No new state machines / lock files** (CON-4 / DC-4): the build
  role ships source-file edits and verifier exit codes; it does NOT
  introduce new state-derivation rules, new lock files, or new
  milestone scaffolding writes outside the unit_close JSONL record.

## Inputs

The build dispatch payload includes:

- The user's original task description.
- The Quick-profile knowledge inject.
- The upstream `plan.md` body (verbatim, as the primary `Inputs`
  block).

## Notes

- The build role consumes `plan.md` by literal filename per the AD-10
  path convention. Renaming or relocating the file breaks the
  contract.
- The build role's verifier inline execution is the gate that
  guarantees the source-file edits actually meet the plan's stated
  acceptance criteria. A green verifier suite is the close signal;
  red is an immediate non-zero exit, no exceptions.
- The role template is consumed verbatim by the router; literal
  substring changes are normative dispatch-contract changes.
