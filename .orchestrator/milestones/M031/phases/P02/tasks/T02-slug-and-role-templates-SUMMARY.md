---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M031"
provides:
  - "scripts/intake/lib/task-slug.sh sourceable derive_task_slug function (AD-10 40-char base slug + 4-char SHA-1 collision suffix + untitled empty-input fallback),templates/dispatch-role-research.md (96 lines prescriptive read-only research-role contract producing research.md with Findings Open Questions Recommended Approach),templates/dispatch-role-plan.md (93 lines prescriptive plan-authoring contract producing PLAN.md with Steps Verification Inputs Files Likely Touched),templates/dispatch-role-build.md (93 lines prescriptive executor contract reading plan.md and running Verification inline with no implicit retry),tools/verify/m031-p02-task-slug-shape.sh (10 checks AD-19 single-script Truth Check),tools/verify/m031-p02-role-templates-shape.sh (21 checks AD-19 single-script Truth Check)"
requires:
  - "P01: scripts/dispatch/build-context.sh --profile=quick --meta-out wired,P02/T01: scripts/intake/shape-detect.sh tier_a_plus verdict + FIXTURE-PROVENANCE.md + tier-a-plus-input.txt on disk,templates/ directory with sibling dispatch-prompt.md / dispatch-result.md,scripts/intake/ directory"
affects:
  - "P02/T03 (prompt helper reads AD-10 path convention from these templates),P02/T04 (router invokes derive_task_slug and copies role templates into per-role dispatch payloads),P02/T05 (phase-suite aggregates these two verifiers)"
key_files:
  - "scripts/intake/lib/task-slug.sh,templates/dispatch-role-research.md,templates/dispatch-role-plan.md,templates/dispatch-role-build.md,tools/verify/m031-p02-task-slug-shape.sh,tools/verify/m031-p02-role-templates-shape.sh"
key_decisions:
  - "AD-10 collision discipline implemented as conservative bare-base-slug-on-no-collision + 4-char SHA-1 suffix only on real collision against an unrelated prior research.md (preserves human-readable slugs for AD-20 prompt UX),empty-input fallback chosen as deterministic literal untitled rather than SHA-1 of empty string (keeps the slug human-readable; collision discipline still applies if untitled/research.md exists),hash availability shasum -a 1 preferred with openssl sha1 fallback (POSIX-portable across macOS and Linux dispatch hosts),sourceability discipline (no top-level side-effects when sourced; private helpers prefixed _task_slug_*),new schema entry type: dispatch-role reserved by M031 P02 (future role-template additions MUST be additive not parallel),role-template body avoids D020 prohibited scaffold-placeholder bracket-TODO byte pattern via paraphrase,AD-19 single-script-file shape preserved across both new verifiers (no inline compound bash no process substitution no plain subshells in verifier bodies)"
patterns_established:
  - "sourceable shell library with private function prefix discipline (_task_slug_* helpers + public derive_task_slug entry),deterministic-by-construction slug derivation (5-step pipeline lower -> ws-hyphen -> strip -> collapse -> truncate) with optional collision-only suffix,role-template trio sibling-symmetric with existing dispatch-prompt.md and dispatch-result.md siblings (same templates/ directory same frontmatter shape),per-role required-literal-substring contract enforced by single-script Truth Check verifier (each role template asserts 4 role-specific literals plus 2 frontmatter literals),collision-check rooted at project-relative .orchestrator/tier-a-plus/<base-slug>/research.md (caller-cwd-independent via BASH_SOURCE-driven project-root resolution)"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-PLAN.md"
duration: "90m"
verification_result: "pass"
completed_at: "2026-05-01T18:57:51Z"
---

T02 ships the AD-10 task-slug derivation library and the FR-8 prescriptive role-template trio that the Tier A+ middle flow consumes. scripts/intake/lib/task-slug.sh exposes a sourceable derive_task_slug function returning a 40-character lowercase hyphenated alphanumeric base slug with an optional 4-character SHA-1 collision suffix per AD-10 (the suffix appears only when an unrelated prior research.md sits at .orchestrator/tier-a-plus/<base-slug>/research.md). Empty input collapses to the deterministic literal untitled fallback. The function is bash 3.2 compatible per MEM001 (no declare -A no process substitution no $() pipes inside conditionals) and uses shasum -a 1 with an openssl sha1 fallback for cross-host portability.

Three role templates land alongside the existing dispatch-prompt.md and dispatch-result.md siblings under templates/. dispatch-role-research.md (96 lines) declares the read-only investigation contract producing a self-contained research.md at .orchestrator/tier-a-plus/<task-slug>/research.md with Findings (>=3 bullets), Open Questions, and Recommended Approach sections. dispatch-role-plan.md (93 lines) declares the plan-authoring contract producing PLAN.md with numbered Steps, AD-19 single-script-file Verification commands, Inputs, and Files Likely Touched. dispatch-role-build.md (93 lines) declares the executor contract reading plan.md and running every Verification command inline with no implicit retry on first failure.

All three templates declare the new schema entry type: dispatch-role and the per-role role: <research|plan|build> frontmatter line. Each template carries the role-specific required literal substrings the verifier asserts (research: findings research.md Quick --meta-out; plan: PLAN.md Steps Verification single-script-file; build: plan.md verifiers inline Quick). The templates avoid the D020 prohibited scaffold-placeholder bracket-TODO byte pattern in source by paraphrasing.

Two AD-19 single-script Truth Check verifiers under tools/verify/m031-p02-*.sh gate the artifacts. tools/verify/m031-p02-task-slug-shape.sh asserts file existence required literal substrings (derive_task_slug sha1 40) clean source (no stderr) and three function-behavior cases (normal-input slug shape and length empty-input fallback long-input truncation determinism on repeated input). tools/verify/m031-p02-role-templates-shape.sh asserts each templates existence (>=25 lines) frontmatter schema and per-role required literal substrings.

Verification: m031-p02-task-slug-shape pass=10 fail=0; m031-p02-role-templates-shape pass=21 fail=0. scripts/intake/route-to-dispatch.sh is byte-identical to its pre-T02 state (T04 owns the router amend). scripts/intake/shape-detect.sh and scripts/intake/paragraph-classify.sh are untouched (T01 owns those edits). templates/orchestrator-config-default.yml is untouched (P00 owns the knobs; P04 owns the FR-16 auto_proceed flip). The SC-12 block-list (knowledge/** scripts/cost/ scripts/dispatch/adapters/router/ scripts/auto/loop/) is fully respected -- no T02 edit touches any block-list path.

T02 leaves the slug helper and the three role templates on disk. T03 builds on this by shipping the prompt helper that reads the AD-10 path convention. T04 builds on T02 plus T03 by amending the router to invoke the slug library role templates and prompt helper in sequence. The new schema entry type: dispatch-role is reserved by M031 P02; future milestones extending dispatch-role surfaces (e.g. M033 onboarding) MAY add fields additively but MUST NOT introduce a parallel role-template schema.

Open questions A2 (router CLI surface) A3 (SC-6 stub vs real dispatch) A4 (session-ID sidecar mechanism) A5 (.orchestrator/tier-a-plus/ allow-list prefix) remain deferred to T03 through T05 per the strict T01 to T05 dependency chain. T02 does NOT touch any of those open-question surfaces.
