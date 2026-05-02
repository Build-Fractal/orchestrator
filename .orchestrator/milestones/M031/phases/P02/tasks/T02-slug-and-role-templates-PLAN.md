---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M031"
name: "Task-slug derivation library (AD-10) + research/plan/build role templates (FR-8)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: classifier extension, FIXTURE-PROVENANCE.md, tier-a-plus-input.txt, SC-5 test, and four shape verifiers shipped (verified by `bash tools/verify/m031-p02-classifier-extension-shape.sh`, `bash tools/verify/m031-p02-fixture-provenance-shape.sh`, `bash tools/verify/m031-p02-tier-a-plus-input-shape.sh`, `bash tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh`, and `bash tests/m031-acceptance/test-tier-a-plus-classifier.sh`).
- `templates/` directory exists with sibling role templates from prior milestones (e.g., `dispatch-prompt.md`, `dispatch-result.md`). T02's three new templates are sibling-symmetric.
- `scripts/intake/` directory exists (T01 already verified its presence). T02 creates a new sub-directory `scripts/intake/lib/` for the task-slug helper.

## Description

T02 ships two artifact families:

1. **Task-slug derivation library** — `scripts/intake/lib/task-slug.sh` exposes a sourceable `derive_task_slug` function returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]` per AD-10. The 40-char base is derived from the task description (lowercased, spaces → hyphens, non-alphanumeric-non-hyphen stripped, truncated to 40 characters). The 4-character SHA-1 collision suffix is appended ONLY when an existing `.orchestrator/tier-a-plus/<base-slug>/` directory contains a `research.md` whose first line is NOT a paraphrase of the current task description (collision discipline). On no collision, the bare base slug is returned.
2. **Three role templates** — `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` per FR-8. Each template is prescriptive: it declares the exact output shape the dispatched agent MUST produce, the per-role dispatch-payload requirements (Quick-profile knowledge inject + `--meta-out` sidecar), and the per-role output-path convention `.orchestrator/tier-a-plus/<task-slug>/<role>.md` per AD-10.

T02 ships two shape verifiers under `tools/verify/m031-p02-*.sh`. T02 does NOT amend `scripts/intake/route-to-dispatch.sh` — the router edit is T04's job. T02's outputs are consumed by T03 (prompt helper reads the AD-10 path convention) and T04 (router invokes the slug library + role templates).

## Steps

1. **Create the `scripts/intake/lib/` directory** if it does not already exist (no other intake-lib helpers ship pre-T02; T02 creates the sub-directory).

2. **Author `scripts/intake/lib/task-slug.sh`** (executable, bash 3.2-compatible). Required body shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/intake/lib/task-slug.sh -- M031 P02 T02 deterministic task-slug
   # derivation per AD-10. Sourceable; exposes one function:
   #
   #   derive_task_slug <task-description>  -> echoes <base-slug>[-<sha1-4>]
   #
   # Base slug derivation (deterministic):
   #   1. Lowercase the task description.
   #   2. Replace whitespace runs with single hyphens.
   #   3. Strip every character that is not [a-z0-9-].
   #   4. Collapse consecutive hyphens; strip leading/trailing hyphens.
   #   5. Truncate to 40 characters.
   #
   # Collision discipline (AD-10):
   #   - If `.orchestrator/tier-a-plus/<base-slug>/research.md` does NOT exist
   #     OR its first line matches the current task description's first line,
   #     return the bare <base-slug>.
   #   - Otherwise compute SHA-1 of the full task description (using
   #     `shasum -a 1` or `openssl sha1` per host availability), take the
   #     first 4 hex characters, and return `<base-slug>-<sha1-4>`.
   #
   # Bash 3.2 compatible.
   ```

   The function MUST be sourceable (no top-level side-effects when sourced) and callable as a subshell command:

   ```bash
   slug="$( . scripts/intake/lib/task-slug.sh; derive_task_slug "$task_description" )"
   ```

   Hash availability: prefer `shasum -a 1` (macOS + Linux); fall back to `openssl sha1 | awk '{print $NF}'` if shasum is unavailable. Both are POSIX-portable; pick whichever your dispatch path tests on first.

3. **Author `templates/dispatch-role-research.md`** (≥ 25 lines). Required content:

   ```yaml
   ---
   schema_version: "1.0"
   type: dispatch-role
   role: research
   ---
   ```

   Required body sections (prescriptive):
   - `## Goal` — single sentence: "Investigate the user request and produce a `research.md` documenting findings, surface gaps, decisions to make, and a recommended approach. Do NOT modify any source file."
   - `## Output Shape` — exact shape: a single markdown file at `.orchestrator/tier-a-plus/<task-slug>/research.md` with sections `## Findings` (N bullet points, N ≥ 3), `## Open Questions` (zero or more), `## Recommended Approach` (one paragraph). The body MUST be self-contained: no external file references the operator must follow to understand the recommendation.
   - `## Dispatch Payload Requirements` — Quick-profile knowledge inject via `build-context.sh --profile=quick`; `--meta-out <path>` sidecar emitted alongside the payload (P01 contract).
   - `## Constraints` — read-only (no source-file edits); plain prose (no scaffold-placeholder bracket-TODO byte pattern); D020 token hygiene; ≤ 200 lines target output (the prompt summary truncates at `tier_a_plus_prompt_summary_lines` per AD-20).
   - File MUST contain the literal substrings `findings`, `research.md`, `Quick`, `--meta-out`.

4. **Author `templates/dispatch-role-plan.md`** (≥ 25 lines). Required content:

   ```yaml
   ---
   schema_version: "1.0"
   type: dispatch-role
   role: plan
   ---
   ```

   Required body sections (prescriptive):
   - `## Goal` — single sentence: "Read the upstream `research.md` and produce a single `PLAN.md` with explicit Steps, Verification commands, Inputs, and Files Likely Touched. The plan MUST be self-contained — an executor reading only `PLAN.md` plus the codebase MUST be able to ship without re-reading `research.md`."
   - `## Output Shape` — exact shape: a single markdown file at `.orchestrator/tier-a-plus/<task-slug>/plan.md` with sections `## Steps` (numbered, exact file paths), `## Verification` (executable command lines, single-script-file shape per AD-19), `## Inputs` (upstream files this plan reads), `## Files Likely Touched` (every file the build dispatch will create or modify). The PLAN.md MUST cite at least one `## Verification` command — a build dispatch with no verification gate is rejected.
   - `## Dispatch Payload Requirements` — Quick-profile knowledge inject; the upstream `research.md` is included as a `From Previous Tasks` input in the plan dispatch's payload.
   - `## Constraints` — every `## Verification` command MUST be a `bash <path>` invocation, not inline compound bash (AD-19); plain prose (no scaffold-placeholder bracket-TODO byte pattern); plan MUST be reachable in one context window.
   - File MUST contain the literal substrings `PLAN.md`, `Steps`, `Verification`, `single-script-file`.

5. **Author `templates/dispatch-role-build.md`** (≥ 25 lines). Required content:

   ```yaml
   ---
   schema_version: "1.0"
   type: dispatch-role
   role: build
   ---
   ```

   Required body sections (prescriptive):
   - `## Goal` — single sentence: "Read the upstream `plan.md` and execute every `## Steps` item, then run every `## Verification` command inline; exit non-zero if any verifier fails."
   - `## Output Shape` — no per-role markdown file under `.orchestrator/tier-a-plus/<task-slug>/`; the build's deliverables are the source-file edits described by the plan, plus the `## Verification` exit code. The `unit_close` JSONL record carries `tier_a_plus_role: build` and the consolidated verifier-pass result.
   - `## Dispatch Payload Requirements` — Quick-profile knowledge inject; the upstream `plan.md` is included as the primary `Inputs` file.
   - `## Constraints` — inline verifiers MUST run in single-script-file form (AD-19); on first verifier failure the build dispatch exits non-zero with no implicit retry (the operator decides whether to re-dispatch or escalate to Tier B per spec edge case).
   - File MUST contain the literal substrings `plan.md`, `verifiers`, `inline`, `Quick`.

6. **Author `tools/verify/m031-p02-task-slug-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/lib/task-slug.sh` exists, is non-empty, contains the literal substrings `derive_task_slug`, `sha1`, and `40`.
   - Assert that sourcing the file does not produce stderr output and that calling `derive_task_slug "Add a flag to script X with three tests"` returns a slug ≤ 40 characters consisting of only `[a-z0-9-]` (regex check on the captured stdout).
   - Assert that calling `derive_task_slug` against an empty input returns a non-empty fallback slug (deterministic; e.g., `untitled` or a SHA-1 of the empty string).
   - Output: a single final stdout line `SUMMARY: m031-p02-task-slug-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m031-p02-role-templates-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` all exist, ≥ 25 lines each.
   - Assert each contains `type: dispatch-role` in its frontmatter and the corresponding `role: <research|plan|build>` line.
   - Assert each contains the role-specific required tokens documented in steps 3–5 (research: `findings`, `research.md`, `Quick`, `--meta-out`; plan: `PLAN.md`, `Steps`, `Verification`, `single-script-file`; build: `plan.md`, `verifiers`, `inline`, `Quick`).
   - Output: a single final stdout line `SUMMARY: m031-p02-role-templates-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Run both new verifiers locally** to confirm exit 0:

   ```bash
   bash tools/verify/m031-p02-task-slug-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p02-role-templates-shape.sh
   ```

9. **Confirm `scripts/intake/route-to-dispatch.sh` UNCHANGED.** Run `git diff --stat scripts/intake/route-to-dispatch.sh` and confirm zero output. T02 has no business amending the router; that is T04's job.

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/lib/task-slug.sh exists and exposes derive_task_slug" (Truth #4; Check via `m031-p02-task-slug-shape.sh`)
- "templates/dispatch-role-{research,plan,build}.md exist with prescriptive bodies" (Truth #5; Check via `m031-p02-role-templates-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p02-task-slug-shape.sh
```

```bash
bash tools/verify/m031-p02-role-templates-shape.sh
```

## Notes

- Each shape verifier MUST emit `SUMMARY: <script-name> pass=N fail=M` as its final stdout line and exit 0 iff `fail=0`.
- AD-10 collision discipline is conservative: the bare base slug is returned in the common case; the SHA-1-4 suffix appears only on a real collision against a different prior task description. This keeps `.orchestrator/tier-a-plus/<slug>/` paths human-readable for the operator's inspection per the AD-20 prompt UX requirement.
- The role templates' YAML frontmatter `type: dispatch-role` is a new schema entry. M031 P02 reserves the type; future milestones extending dispatch-role surfaces (e.g., M033 onboarding) MAY add fields additively but MUST NOT introduce a parallel role-template schema.
- D020 token hygiene (CON-7): comments and prose in the new files MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase or escape.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.

## Inputs

### From Previous Tasks

- `scripts/intake/shape-detect.sh` (modified by T01) — emits `input_shape=tier_a_plus` for the 30–80-word, zero-structural-marker band. T02's role templates reference the verdict in their preamble. Key API: invoked as `bash scripts/intake/shape-detect.sh --input <string>`; emits `input_shape=<value>` + `shape_classification=<high|low>`.
- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (created by T01) — provides the Tier A+ heuristic grounding. T02's role templates may cite the file as an architectural reference.

### From Disk (Pre-existing)

- `templates/` — sibling-symmetric directory. T02 places three new `dispatch-role-*.md` files alongside the existing `dispatch-prompt.md` / `dispatch-result.md` siblings.
- `templates/orchestrator-config-default.yml` — declares `tier_a_plus_prompt_summary_lines: 8`. T02's role templates reference this knob name (research and plan templates note that the AD-20 prompt truncates output at this configured value).
- `scripts/dispatch/build-context.sh` (modified by P01) — accepts `--profile=quick|standard|full` and `--meta-out <file>`. T02's role templates declare that each Tier A+ dispatch invokes the build-context.sh surface with `--profile=quick` and a per-role `--meta-out` path. Key API: `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <fixture> --out <payload> --meta-out <sidecar>`; sidecar is JSON with keys `mem_count`, `total_tokens`, `profile`, `compression_applied`, `snip_applied`.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to the `scripts/intake/` and `templates/` surfaces: no edits to existing files in those directories beyond the T01 deltas already on disk.
- **No edits to `scripts/intake/route-to-dispatch.sh`** in T02 (T04's job).
- **No edits to `scripts/intake/shape-detect.sh` or `paragraph-classify.sh`** in T02 (T01 owns those edits).
- **No edits to `templates/orchestrator-config-default.yml`** in T02 (P00 owns the knobs; M031 P04 owns the FR-16 `auto_proceed` flip).
- **SC-12 scope-guard**: T02 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **No new state machines / lock files** (CON-4 / DC-4): T02 ships templates and a sourceable lib helper only — no state-derivation rule, no lock file, no milestone scaffolding write.
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T02 completes:

1. `scripts/intake/lib/task-slug.sh` exists, sourceable, exposes `derive_task_slug` returning slugs in the AD-10 shape.
2. `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` all exist, ≥ 25 lines each, with prescriptive bodies declaring exact output shapes and dispatch-payload requirements.
3. `tools/verify/m031-p02-task-slug-shape.sh` exists, executable, exits 0.
4. `tools/verify/m031-p02-role-templates-shape.sh` exists, executable, exits 0.
5. `scripts/intake/route-to-dispatch.sh` byte-identical to its pre-T02 state.

T02 leaves the slug helper and role templates on disk. T03 builds on this by shipping the prompt helper that reads the AD-10 path convention. T04 builds on T02 + T03 by amending the router to invoke the slug library, role templates, and prompt helper in sequence.
