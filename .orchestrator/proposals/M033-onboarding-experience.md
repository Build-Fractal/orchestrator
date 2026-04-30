# Proposal: M033 — Project Onboarding Experience

**Captured**: 2026-04-28 during pbj-central-mono-repo bootstrap session
**Shape**: Milestone (5 phases, P03 collapsible if launch-timing pressured)
**Predecessors**: M031 (right-sized entry — universal task entry post-bootstrap), M032 (wiki distribution — `--with-<feature>` flag pattern + project-asset surface), M024 (intake & routing — intent classifier reused in greenfield ideation), M020 (knowledge layer — graph schema M033 seeds into), M025 (installer coexistence — user-global skills surface M033 sits atop)
**Source**: 2026-04-28 session — operator started new project `pbj-central-mono-repo`, discovered that `orchestrator:init` is bootstrap-only (config + CLAUDE.md + skills, no constitution, no knowledge seeding, no interactive branching). Asked: *"What would it take for a first-time user with nothing to land in a fully-set-up project after one warm conversational command?"* Same session surfaced that the orchestrator currently leans on `speckit.constitution` for constitution authoring — direct dogfooding contradiction with the standalone posture (CLAUDE.md *Standalone Mode* section + Principle XVI direction).

## Goal

`orchestrator:start` (naming open — see Q1) is the warm conversational front door for any new orchestrator-managed project. One command. Branches based on the user's starting state. Always finishes with: skills installed, config written, **constitution authored (orchestrator-native)**, **CLAUDE.md custom block populated with project context**, **knowledge graph seeded** (from materials, codebase, or both), optional wiki/GH integration deployed via M032/M013 gates, ready for `orchestrator:specify` or `orchestrator <task>` (M031). **Zero spec-kit dependencies.**

## Why M033 (not extending M031 / M032 / `init`)

**M031** scopes *small-task entry* — the universal `orchestrator <task>` invocation that activates *after* a project is set up. M031 assumes knowledge exists; it doesn't put it there.

**M032** scopes *project-local-asset distribution* — the `--with-wiki` flag pattern and bundle/install layer for assets that need to live inside the project. M032 builds the plumbing M033 consumes; it doesn't add interactive UX or content authoring.

**`orchestrator:init`** is correctly bootstrap-only today (~1 second, four phases: detect → probe → generate → verify). Inflating it with conversational branching and content authoring would break its idempotency contract and its `--dry-run` semantics. M033 is a sibling command that *invokes* `init` as one step in a larger flow.

Naming as a new milestone keeps M031's small-task contract clean, lets M032's project-asset surface stay narrow, and gives M033 its own success criteria around first-time-user experience.

## Why this is load-bearing for launch (not polish)

The launch posture is **CC-only, single user, then broaden**. The first 30 minutes of a new user's experience define adoption. Today that experience is:

1. Run install script (manual)
2. Run `/orchestrator:init` (1 second, produces config + empty `CLAUDE.md`)
3. Read 5 reference docs to figure out what to do next
4. Hand-author a constitution (no template, no guidance)
5. Hand-author CLAUDE.md custom block (no scaffold)
6. Decide if you want a wiki / GH integration (no prompts; user has to know to ask)
7. Manually decide between `orchestrator:specify` (have a spec?) vs ideation-from-scratch (no path) vs migrate-from-other-tool (`orchestrator:migrate` exists but no front door routes to it)
8. Begin

Eight steps, several of which require the user to already understand orchestrator's mental model. That's an adoption tax the launch can't pay.

M033 collapses all of this into one conversational command with branching logic that asks the user 5–10 questions and arrives at a fully-set-up project.

## Strict scope

This is **conversational front-door + content authoring layer**, not:
- Knowledge graph schema redesign — M020's territory, closed
- Bundle/install infrastructure — M032's territory
- Spec authoring — `orchestrator:specify` already does this; M033 *invokes* it
- Migration logic — `orchestrator:migrate` already covers GSD2/v1/spec-kit; M033 *routes* to it
- Universal small-task entry — M031's territory
- Adaptive model selection — M030's territory

M033 asks: *can a first-time user land in a fully-bootstrapped project after one warm conversation?*

## Adopted external pattern: relentless grilling protocol

The four-branch interactive flow (Findings A, D, E) operationalizes a pattern lifted from `mattpocock/skills::grill-with-docs` (MIT). The protocol — for use anywhere `start` asks the user a structured question — is:

1. **Sequential, never batched** — present one question at a time and await the answer before the next. Batched questions invite skimming and produce shallow inputs.
2. **Code-first speculation cap** — when a question can be answered by reading the project (manifests, directory structure, existing materials), read first, then ask only what reading cannot resolve. The greenfield-with-materials branch (Finding E) and existing-codebase branch (Finding A row 3) are most exposed to this rule.
3. **Inline doc updates** — when an answer resolves a domain term, write it to the project's domain glossary immediately. Do not batch glossary updates to the end; batched updates are the easiest thing to drop and the fact that the user just disambiguated the term is the reason the glossary entry is high-quality. (See M032 *Wiki domain glossary as first-class artifact* for where the glossary lives.)
4. **Surface contradictions live** — if a user answer conflicts with detected codebase state or a prior answer, surface the contradiction in the next turn rather than silently picking one. Constitution Principle II (Evidence Before Claims).
5. **Recommendation, not interrogation** — every question carries a recommended default the user can accept with a single keystroke. The grilling is rigor for the *plan*, not friction for the *user*.

This protocol is the contract for the conversational shell built in P01 and reused by P02 (constitution authoring), P04 (materials intake + ideation), and P05 (custom block authoring). P00 baseline runs validate the protocol against fixtures before P01 codifies it.

## Findings (root-cause analysis)

### Finding A: `orchestrator:init` is binary; no interactive branching

**Evidence**: `commands/init.md` four-phase pipeline (detect → probe → generate → verify) runs the same code path regardless of whether the user has a spec, a codebase, materials, or nothing. `scripts/lifecycle/init-project.sh:1-21` flag-parsing supports `--project-dir`, `--runtime`, `--dry-run`, `--force`, `--verbose` — no `--interactive` and no branch flags.

**Root cause**: scope, correctly. `init`'s job is reproducible bootstrap; conversational branching would break idempotency and `--dry-run`.

**Fix shape**: a sibling command `orchestrator:start` (or `orchestrator:bootstrap` — see Q1) that wraps `init` as one step in a four-branch interactive flow:

| Branch | Trigger | Steps |
|---|---|---|
| **greenfield-empty** | User says "I have an idea, nothing else" | Ideation conversation → MVP scaffold → invoke `specify` → roadmap |
| **greenfield-with-materials** | Materials present in project dir (PBJ case) | Materials intake → drift reconciliation → invoke `specify` consuming materials → roadmap |
| **existing-codebase** | Detected source files + git history, no `.orchestrator/` | Codebase scan → KB seeding → optional spec-kit/GSD migration → ready for surgical work via M031 |
| **migrating** | Detected GSD2/v1/spec-kit artifacts | Invoke `orchestrator:migrate` → reconcile → KB seeding → ready |

Branch detection runs first (filesystem probe + 1-2 questions). User can override.

**Impact**: without this, first-time users have no warm path. The 8-step manual sequence above is the current state.

### Finding B: No orchestrator-native constitution authoring

**Evidence**: `.orchestrator/memory/constitution.md` in this repo was hand-written for the orchestrator project itself. No template, no scaffold command, no recommendation engine. `commands/specify.md:86,99,115` references the constitution for its Constitution Check section — but if the file doesn't exist, the gate degrades silently. The available skill `speckit.constitution` provides interactive authoring but is a **spec-kit dependency** that contradicts CLAUDE.md's *Standalone Mode* commitment.

**Root cause**: M001-M030 were orchestrator self-hosting. The constitution was authored once and never needed a re-author flow.

**Fix shape**: new orchestrator-native command `orchestrator:constitution` + tech-stack-aware starter templates. Templates live at `templates/constitution-starters/<stack>.md` with placeholders (`{{project_type}}`, `{{primary_constraint}}`, etc.). Stacks for v1: `web-saas`, `cli-tool`, `library`, `ml-pipeline`, `mobile-app`, `monorepo`, `data-pipeline`, `internal-tool`. Each starter ships 6–8 baseline principles plus 2–3 stack-specific ones (e.g., web-saas adds *Idempotent Deploys*, ml-pipeline adds *Reproducible Training Runs*). Interactive flow: 5–8 questions → draft → user edits in their editor → write to `.orchestrator/memory/constitution.md`.

**Impact**: without an orchestrator-native path, every first-time user either skips constitution authoring (specify gate degrades) or leans on spec-kit (violates standalone posture). This is also Principle XVI's first compliance test on the *content-authoring* surface (M032 covers the *asset-distribution* surface).

### Finding C: No codebase-knowledge ingestion

**Evidence**: `commands/ingest.md` ingests *spec markdown* into the knowledge graph (chunks into spec/story, spec/requirement, etc.). It does not ingest a codebase. There is no command that says *"scan this existing repo and seed knowledge graph entries from README + ARCHITECTURE.md + package manifests + directory structure + test suites + recent commits."*

**Root cause**: M020 closed the knowledge layer with the assumption that knowledge enters via `specify` → `ingest` (spec-driven flow). Existing-codebase users have no entry path.

**Fix shape**: new command `orchestrator:ingest-codebase` (or `--source codebase` flag on existing `ingest`). Scans:
- Top-level docs (`README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`, `docs/`)
- Package manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.) — extract dependencies, scripts, project-type signals
- Directory structure — top 2 levels of `src/` or equivalent, infer module boundaries
- Test directory shape — infer testing conventions
- Recent git log — infer active areas, contributor patterns
- Existing `.cursor/`, `.aider/`, `.claude/`, `.specify/`, `.gsd/` — detect prior tooling

Produces 5–15 initial MEM entries (knowledge/architecture/, knowledge/conventions/, knowledge/decisions/) — *seeds*, not exhaustive understanding. The graph compounds from there. **Explicitly not** deep semantic understanding; this is structural extraction.

**Impact**: without this, M031's universal small-task entry runs against an empty knowledge graph for any existing-codebase project. The orchestrator's "every dispatch is knowledge-rich" promise (M031 Goal) is unfulfillable on existing codebases until M033 P03.

### Finding D: No greenfield ideation path

**Evidence**: `commands/specify.md` requires a feature description to scaffold from. Users with "I have an idea" cannot enter the orchestrator workflow without first writing prose somewhere.

**Root cause**: scope. `specify` is correctly an authoring step, not an ideation step.

**Fix shape**: greenfield-empty branch in `start` runs an ideation sub-conversation **before** invoking `specify`. Walks through: problem statement → target user → MVP boundary → top-3 user stories → primary success metric → top-3 risks → top-3 non-goals. Output is a structured pre-spec markdown doc that `specify` consumes as if it were user-authored materials. Composes with conversus for adversarial idea-stress-testing if user opts in (`--with-conversus-stress-test`).

**Impact**: without this, "I have an idea" users either bounce off the orchestrator or write their pre-spec elsewhere. The latter is a leak point — pre-spec writing is exactly where the orchestrator's adversarial-review and Constitution-Check value compounds most.

### Finding E: No materials intake / drift reconciliation

**Evidence**: PBJ case — operator arrived with Product Brief, Decision Register, MVP Plan, Handoff JSON, plus a milestone audit identifying 5 inconsistencies between source docs. No orchestrator command exists to *intake heterogeneous materials, reconcile drift, and produce a unified spec input*. Operator did this by hand across multiple sessions.

**Root cause**: M011-M014 spec management focused on the *single spec* lifecycle (author → ingest → comment → amend). Heterogeneous-source intake was never scoped.

**Fix shape**: greenfield-with-materials branch in `start` runs a materials intake sub-conversation. Steps:
1. List detected materials in project directory (markdown, PDF-via-textutil, JSON, plain text)
2. Ask user to label each: *primary spec*, *supplementary*, *decision history*, *out-of-scope reference*
3. Run cross-document drift detection (deterministic — check for ID misalignment, scheme contradictions, orphan references)
4. Surface drift findings as a checklist; user reconciles each (accept primary, accept supplementary, manual edit, defer)
5. Produce reconciled spec input; invoke `specify` consuming it

This is a **deterministic reconciliation pass plus interactive resolution** — no LLM-magic merge. The operator stays in control of every conflict.

**Impact**: without this, PBJ-shaped users (which is most real-world greenfield with-materials cases) either reconcile by hand (the current pain) or accept silent drift in their spec.

### Finding F: No project-context CLAUDE.md custom block authoring

**Evidence**: `templates/project-instruction.md` produces a CLAUDE.md with empty `<!-- BEGIN CUSTOM --> <!-- END CUSTOM -->` block. The block is preserved across re-inits (good) but never *authored* by any orchestrator command. Users either know to fill it (mostly don't) or leave it empty (and every fresh agent in the project loads with zero project context).

**Root cause**: M001 templates assumed the operator authors custom block manually. No interactive scaffold.

**Fix shape**: in the final P05 phase of `start`, draft the custom block from intake conversation outputs:
- Project type + tech stack (from F3 codebase scan or F4 ideation answers)
- Source-doc map (from F5 materials intake) or codebase entry-point map (from F3 scan)
- Naming conventions (from F3 detection)
- Top constitution principles (cross-reference to `.orchestrator/memory/constitution.md`)
- Initial decision register if F5 produced one

User reviews/edits in their editor. Write to CLAUDE.md.

**Impact**: every fresh agent in a project loads CLAUDE.md automatically. Custom block is the highest-leverage 50–200 lines of context the orchestrator can ship per dispatch. Empty custom block = every dispatch starts cold. Authored custom block = every dispatch starts with project-specific anchoring.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| **P00** (recommended) | Empirical baseline | Manual run of all 4 branches against fixture projects (greenfield-empty, greenfield-with-materials [PBJ], existing-codebase, migrating). Friction inventory per branch. Decision: which findings load-bearing? | Inventory matches Findings A–F; if a finding is fictional in practice, drop from scope. PBJ bootstrap is the with-materials baseline. |
| **P01** | `orchestrator:start` skeleton + branching front door | `commands/start.md` + `scripts/lifecycle/start.sh`. Branch detection (filesystem probe + 1–2 questions). Routes to `init` + branch-specific sub-flow stubs. Conversational shell (read user input, dispatch sub-flows). | Fresh fixture project (each branch shape) → `start` correctly identifies branch + invokes `init` + reaches sub-flow stub. No content authoring yet. |
| **P02** | Constitution authoring (orchestrator-native) | `commands/constitution.md` + `scripts/lifecycle/constitution-author.sh`. `templates/constitution-starters/<stack>.md` for 8 stacks. Interactive 5–8 question flow → draft → user edit → write. | Fresh fixture (each stack) → `constitution` produces stack-appropriate `.orchestrator/memory/constitution.md`. Re-running is idempotent (preserves edits). Composes correctly with `specify`'s Constitution Check. **Standalone gate**: zero `speckit.constitution` references in any output. |
| **P03** | Codebase ingestion | `commands/ingest-codebase.md` + `scripts/lifecycle/ingest-codebase.sh`. Scanners for top-level docs, manifests, structure, tests, git log, prior-tooling detection. Produces 5–15 MEM entries seeding the knowledge graph. | Fresh fixture (existing-codebase shape, ~3 stack variants) → `ingest-codebase` produces non-empty knowledge graph. M031's universal entry on the same fixture loads ≥3 relevant MEMs into payload. |
| **P04** | Materials intake + greenfield ideation | `scripts/lifecycle/materials-intake.sh` (deterministic drift detection + interactive reconciliation). `scripts/lifecycle/ideation.sh` (greenfield-empty conversation → pre-spec markdown). Both feed into `orchestrator:specify`. | PBJ fixture → materials intake surfaces the 5 known inconsistencies as a reconciliation checklist; user resolves; resulting spec input is drift-free. Greenfield-empty fixture → ideation produces structured pre-spec; `specify` consumes it. |
| **P05** | Custom block authoring + integration gates | Custom-block drafter using P01-P04 outputs. `start` integrates `--with-wiki` (M032), `--with-github` (M013) flag pass-through. End-to-end fixture: each branch runs `start` to completion with all gates exercised. CLAUDE.md custom block populated. | Fixture per branch → end-to-end `start` run completes with: skills installed, config written, constitution authored, knowledge seeded, custom block populated, optional wiki + GH integration deployed. Zero `speckit.*` invocations across any path. |

## Empirical baseline (P00)

Before flipping anything, run all four branches manually against fixture projects. **PBJ bootstrap counts as the greenfield-with-materials baseline** — capture friction notes as you go. The other three need synthetic fixtures (a one-line idea fixture, a 5k-line existing TypeScript project fixture, a 200-line GSD-v1 migrating fixture). Decision points the baseline produces:

- Are F4 (ideation) and F5 (materials) really separate findings, or do they collapse into one "pre-spec authoring" path with two sub-flows? Baseline tells.
- Is F3 (codebase ingestion) genuinely deterministic (manifests + structure + git log) or does it want LLM augmentation? Baseline tells. Recommendation: ship deterministic v1, LLM augmentation as M033.5 fast-follow.
- Is the constitution starter library 8 stacks or 3? Baseline tells. Recommendation: ship 3 (`web-saas`, `cli-tool`, `library`) covering 80% of v1 users; expand demand-driven.

If P00 reveals a finding is fictional or the scope collapses, M033 reshapes. The 5-phase scope is the maximal version.

## Sequencing

**Slot recommendation**: pre-launch, after M032, before M029. Revised launch sequence:

```
M028 → M030 → M031 → M032 → M033 → M029 → launch
```

Reasoning:
- **After M032**: M033 P05 invokes `--with-wiki`. M032 must ship first.
- **After M031**: M033 P03 codebase ingestion is what makes M031's universal entry actually knowledge-rich on existing-codebase projects. They reinforce each other; ordering chosen so M031 ships first and gets immediate validation when M033 lands.
- **Before M029**: M029 is launch polish (`orchestrator:where`, headline status). M033 changes the *first* thing a user runs; M029 changes how they navigate after. M033's UX shifts inform M029's design (e.g., should `where` show branch context if user is mid-onboarding?).

**Cost**: ~2 weeks added to launch (P03 codebase ingestion is largest, ~1 week alone; rest ~1 week combined). **P03 collapse condition**: if P00 baseline shows existing-codebase users tolerate manual KB seeding as part of M031's universal entry (i.e., they let knowledge accumulate organically through use), P03 collapses to a stub command that drafts 1–2 placeholder MEMs from README only. M033 then ships in ~5 days.

**Alternative slot**: post-launch fast-follow alongside M009/M023/M010. Costs: launch first-impression remains the 8-step manual flow; first 50 real users hit it. Wins: empirical signal informs which findings are load-bearing. Recommendation: pre-launch unless launch timing slips below 6 weeks.

## How M033 plays with adjacent milestones

- **M031 (right-sized entry)**: M031's universal `orchestrator <task>` activates *after* M033 finishes. M033's codebase ingestion (P03) is what makes M031 knowledge-rich on existing projects.
- **M032 (wiki distribution)**: M033 P05 invokes M032's `--with-wiki` gate as one optional step. M033 doesn't redo wiki plumbing.
- **M030 (adaptive model selection)**: M033's interactive flows (constitution authoring, ideation, materials intake) are surgical-character tasks. They route to Sonnet/Haiku via M030. M033 + M030 = cheap, fast onboarding.
- **M013 (GH integration)**: M033 P05 invokes M013's init flow as one optional gate. M033 doesn't redo GH plumbing.
- **M024 (intake & routing)**: M033's branch detection reuses M024's intent classifier on the user's first answer ("what are you trying to build?").
- **Constitution Amendment (Principle XVI)**: M033 P02 + P05 are XVI's first content-authoring compliance test (M032 was the asset-distribution test). Both ship under XVI.
- **M020 (knowledge layer)**: M033 P03 writes into M020's existing graph schema. No schema changes.

## Out of scope

- **AI-magic full constitution generation without user input**: every constitution is user-edited before write. Templates seed; users decide.
- **Deep semantic codebase understanding**: P03 is structural extraction (manifests, directory structure, git log, README). Semantic understanding is M020.5 / future.
- **Wiki/GH integration redesign**: delegated to M032 / M013. M033 only invokes their gates.
- **Multi-language / i18n**: English UX only in v1.
- **Persistent interactive shell**: `start` is one command, runs to completion, exits. No long-running session.
- **Profile-driven onboarding** (e.g., "I'm a senior dev, skip the explanations"): single onboarding flow in v1; verbosity-tuning is post-launch demand-driven.
- **Migration from non-spec-kit/GSD tools** (Aider, Cursor, generic scaffolds): v1 covers GSD2/v1/spec-kit (existing `migrate` scope). Other tools are demand-driven.
- **Re-onboarding flow** (e.g., reset and re-run): `--force` on `init` exists; M033 re-runs are idempotent like `init`. No dedicated reset command.
- **Cloud/team onboarding** (multi-user simultaneous setup): single-operator flow only.

## Open questions for `orchestrator:specify`

1. **Naming**: `orchestrator:start` vs `orchestrator:bootstrap` vs `orchestrator:onboard` vs renaming `orchestrator:init` to `orchestrator:start` and demoting current init to internal `init-bootstrap`? Recommendation: `orchestrator:start` as a sibling to `init`. Keeps `init`'s idempotency contract clean. Marketing-friendly verb. Shipped command count goes from 13 to 14 (acceptable).

2. **Constitution starter library v1 scope**: 3 stacks (web-saas, cli-tool, library) covering 80%, or 8 stacks (full sketch above)? Recommendation: ship 3, design template format to allow community-contributed additions. P00 baseline informs.

3. **Codebase ingestion depth (P03)**: deterministic-only (manifests + structure + git log) or include LLM-augmented summaries of top files? Recommendation: deterministic v1, LLM augmentation as M033.5 fast-follow if real-user signal demands. Token cost is real on large codebases.

4. **Materials intake auto-pip-style question**: when materials are detected, ask "should I ingest these?" vs auto-ingest with diff preview? Recommendation: ask. Materials are user IP; explicit consent is hygienic. Same shape as M032 Q2.

5. **Branch detection failure mode**: if filesystem signals are ambiguous (e.g., a repo with both `package.json` and partial `.orchestrator/`), do we ask the user, pick a default, or fail? Recommendation: ask. Branch detection is high-leverage; getting it wrong costs the whole flow.

6. **Reconciliation checklist UX (P04)**: terminal interactive (one question at a time) vs single markdown file the user edits then re-invokes? Recommendation: terminal interactive for ≤5 conflicts, hand off to markdown for >5. PBJ has 5; on the boundary.

7. **`--with-conversus-stress-test`** in greenfield ideation: opt-in flag (default off) or auto-trigger when ideation surfaces low-confidence answers? Recommendation: opt-in. Conversus has a token cost; ideation should be cheap by default.

8. **CLAUDE.md custom block format**: prescriptive section structure (Project / Stack / Source-Docs / Conventions / Decisions) or freeform user-edited prose? Recommendation: prescriptive sections with placeholder text, user fills in. Composes better with future tooling that may parse the custom block.

9. **Where does P00 friction inventory live?** `tests/fixtures/m033-onboarding-baseline/` permanent fixture set or session-only notes? Recommendation: permanent fixture set, mirrors M032 P03's approach.

10. **Existing-codebase + spec-kit/GSD migration ordering**: if a project has *both* an existing codebase *and* GSD artifacts, do we migrate first then ingest codebase, or ingest codebase first then layer migrated artifacts? Recommendation: migrate first (artifacts have explicit provenance), then ingest-codebase fills gaps the artifacts don't cover. Verifier: no duplicate MEMs across the two paths.

## Source evidence (file paths)

- `commands/init.md:38-103` — current four-phase init pipeline (M033 wraps, doesn't replace).
- `scripts/lifecycle/init-project.sh` — flag-parsing pattern + sed-substitution pattern; M033 follows.
- `commands/specify.md:86,99,115` — Constitution Check references (M033 P02 makes load-bearing).
- `commands/ingest.md` — current spec-only ingestion (M033 P03 adds codebase variant).
- `commands/migrate.md` (GSD2/v1/spec-kit migration) — M033 P01 routes to it from `migrating` branch.
- `commands/evaluate.md` — M024 input classifier (M033 P01 reuses for branch detection).
- `templates/project-instruction.md` — CLAUDE.md template with empty custom block (M033 P05 fills).
- `.orchestrator/memory/constitution.md` (this repo) — pattern source for orchestrator-native constitution shape.
- `.orchestrator/proposals/M031-right-sized-entry.md` — pair milestone (M031 small-task entry, M033 onboarding entry).
- `.orchestrator/proposals/M032-wiki-distribution-and-init-integration.md` — `--with-<feature>` flag pattern + project-asset surface M033 consumes.
- `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md` § Change 3 — Principle XVI; M033 P02 + P05 are content-authoring compliance test.
- 2026-04-28 session transcript — pbj-central-mono-repo bootstrap context, Findings A–F evidence, eight-step current-state inventory.
- 2026-04-29 pbj-central-mono-repo Tier C dogfood — friction signal for the **existing-codebase** branch (Finding A's table row): rich architectural context already on disk at `.orchestrator/DECISIONS.md` (DR-MILESTONE-001, DR-RECONCILE-001..005, DR-PROCESS-001..004) is *substance-equivalent* to a finalized `M###-CONTEXT.md`, but `orchestrator:roadmap`'s Tier C gate is filename-shaped, not substance-shaped, so the planner blocks with "Tier C requires a finalized context draft. Run speckit.orchestrator.discuss first." DR-MILESTONE-001 even self-declares as the roadmap input shape. Workaround landed manually in `.orchestrator/milestones/M001/M001-CONTEXT.md` (status: finalized, context_source: imported-from-existing). Implication for M033 design: the existing-codebase P03 (codebase ingestion / KB seeding) should also detect rich-context source files (`DECISIONS.md` with DR- entries, `MILESTONE-AUDIT.md`, `CLAUDE.md` custom blocks) and offer a non-interactive **import-from-existing** path that emits a thin `M###-CONTEXT.md` with `context_source: imported-from-existing` pointing at those sources — preserves the file-shape contract for downstream tools (no roadmap gate change needed) without forcing re-litigation of context the project has already finalized. Cheap-now alternative (substance-equivalent satisfier in `M###-EVALUATION.md` frontmatter) was considered and explicitly deferred to keep M033's existing-codebase branch design clean; revisit only if a second consumer (lakeledger or future) trips on this gate before M033 lands.

## Why this is the right scope

M033 is **integration + UX + 3 net-new pieces** (constitution authoring, codebase ingestion, ideation/materials-intake). Most of the heavy lifting (init, migrate, ingest, specify, conversus, M032 wiki, M013 GH, M031 entry) already exists. M033's job is to *connect the existing pieces* through a warm conversational front door, plus author the 3 missing pieces (constitution, codebase-knowledge, pre-spec).

If the heavy lifting weren't already in place, M033 would be a 10-phase mega-milestone. Because M001-M032 did the work, M033 is 5 phases (collapsible to 4 if P03 collapses). That's the load-bearing observation: **the orchestrator has every internal piece needed; what's missing is the front door that makes them adoptable**.
