---
schema_version: "1.0"
type: thinking-document
status: pending
shipped_layers: [1, 2]
priority: high (PBJ this week)
captured_at: "2026-05-06"
captured_by: "M037/P01-close exploration agent"
folds_into: |
  Pre-launch slice → bundle into M037 P02 OR ship as standalone paper-cut to wiki-deploy.sh
  Adaptive-init full design → post-launch milestone (M033 follow-up / new M040)
  Project-shape detection → already captured at papercut-discuss-project-shape.md
---

# Thinking-Document — Operator Secrets Surface + Adaptive-Init UX

## Why this exists

Two questions surfaced together while staging `wiki-deploy.sh --dry-run`
for the PBJ-central wiki ship:

1. **Operator-info hygiene.** Are we shipping any operator-specific
   strings (emails, repo slugs, giscus IDs, SSH paths) embedded in
   orchestrator artifacts that consumer projects will inherit?
2. **First-deploy UX gap.** When an operator opts into wiki, the
   orchestrator hands them no walkthrough of the env vars `wiki-deploy.sh`
   gate 1 will require. They learn it by failing the gate.

Question 2 generalizes: every optional feature with operator-specific
secrets (wiki/giscus, future analytics tokens, future GH-integration
PATs, future reference-corpus API keys) hits the same shape. Question 1
is the audit that scopes how much of this is real.

The operator wants this rolled into a broader **adaptive-init** story:
`orchestrator:start` (or whatever the warm front door is) should detect
project shape and **offer** features rather than silently install all of
them or none. Per-feature the operator opts into, walk them through the
secrets that feature needs.

## 1. Hardcoded operator-info audit

### Method

Scanned shipped surfaces (`templates/`, `packaging/`, `scripts/`,
`commands/`, `references/`, `wiki/`) for known operator strings:

- `brett@`, `bkellgren`, `fivestar` → operator email/identity
- `Build-Fractal` → org slug embedded in URLs
- `GISCUS_*` literals → repo-specific giscus IDs
- `mailto:` / hostname-shaped strings

### Findings

**A. Real hardcodes that consumer projects would inherit (none blocking)**

`wiki/mkdocs.yml` has Build-Fractal-shaped values (site_name, site_url,
repo_url, edit_uri) hardcoded **as the dogfood site's own values**, but:

- `scripts/lifecycle/wiki-init.sh:270-377` (FR-6) sed-rewrites all five
  scalars from the consumer's `git remote get-url origin` at install
  time. The substitution is idempotent against both `{{...}}`
  placeholders AND already-resolved values, so consumers pulling the
  bundle that carries the orchestrator's identity get correctly
  re-templated against their own remote.
- The giscus block (`mkdocs.yml:77-81`) reads `!ENV [GISCUS_*, ""]` —
  empty defaults, never bakes orchestrator's IDs into consumer
  projects.

Verdict: NOT a hardcode-leak. The dogfood-shaped strings in `wiki/`
are this repo's runtime state for its own dogfood wiki. The
install-time templating pipeline correctly transforms them on copy.

**B. Operator-identity strings that exist but stay local to this repo**

- `.orchestrator/milestones/M020/M020-CONTEXT.md:210` →
  `brett@fivestar.studio`
- `.orchestrator/milestones/M033/M033-SUMMARY.md:86` →
  `Brett Kellgren <brett@fivestar.studio>`
- `.orchestrator/milestones/M033/M033-VALIDATED:21,32` →
  `Brett Kellgren <brett@fivestar.studio>`

These are this project's milestone-state records. They render in this
repo's dogfood wiki (because this wiki projects `.orchestrator/`), but
they are NOT shipped to consumer projects — `packaging/bundle/manifest.yml`
does not include `.orchestrator/` in `project_assets:`. Consumer
projects start with an empty `.orchestrator/` and accumulate their own
identity-bearing records.

Verdict: NOT a problem. Expected dogfood content in this repo's state.

**C. Documentation example URLs (acceptable)**

- `commands/github-status.md:34` → `REPO_SLUG: Build-Fractal/orchestrator`
- `references/RENAME-PLAN.md` → multiple `Build-Fractal/...` references
- `scripts/lifecycle/wiki-init.sh:147-148` → comment showing example
  URL shapes
- `scripts/verify/m014-p03-fetch.sh:73`,
  `scripts/verify/m028/p01-fixture-sanitize{,d}.sh` → fixture/test
  references that explicitly sanitize the operator email out

These read as documentation examples, not as hardcoded references
consumers will inherit. The fixture-sanitize verifier at
`scripts/verify/m028/p01-fixture-sanitize.sh` is itself the proof that
the orchestrator's posture is "operator email is never load-bearing in
shipped fixtures."

Verdict: cosmetic. Worth a one-pass cleanup to `<owner>/<repo>` in the
documentation examples (commands/github-status.md is the most
consumer-facing) but NOT pre-launch blocking.

### Net audit

The orchestrator-shipped surface is **already clean** of operator-info
hardcodes that would leak into consumer projects. Every place where
operator-specific data appears, it's either:

- in `.orchestrator/` (this project's state, not bundled), OR
- runtime-templated on install (`wiki-init.sh` rewrites all five
  identity scalars), OR
- environment-driven with empty defaults (`!ENV [GISCUS_*, ""]`), OR
- a documentation example.

The papercut at
`.orchestrator/proposals/install-template-preserve-operator-keys.md`
flags the inverse pattern (operator-authored config getting clobbered
by template re-install) and is already queued for M035 install
territory. The constitution's Principle XVI (Distribution Surface
Integrity, captured in `constitution-amendment-inclusion-criteria.md`)
covers this whole class.

**One concrete cleanup recommendation if it ever fits a sweep:**

`commands/github-status.md:34` shows `REPO_SLUG: Build-Fractal/orchestrator`
in an example output block. Generic-ize to `<owner>/<repo>` so
consumers who paste a snippet from the docs don't accidentally
Build-Fractal themselves. Five-minute fix.

## 2. The actual gap: secrets walkthrough

The audit above is reassuring. The question that triggered this
investigation is *not* "are we leaking operator info" (we aren't); it's
**"how does an operator learn what secrets they need to provide for
each feature they opt into?"**

Today, that learning path is:

1. Operator runs `orchestrator:init --with-wiki [--with-giscus ...]`.
2. Wiki tooling stages cleanly. Operator confirms with `mkdocs serve`.
3. Operator runs `bash scripts/wiki/wiki-deploy.sh --dry-run`.
4. **Gate 1 hard-fails: "FAIL: GISCUS_REPO unset or empty."**
5. Operator reads `wiki/README.md` § "First-deploy checklist", finds
   the 8-step recovery, runs `bash scripts/diagnostics/giscus-ids-from-gh.sh`,
   exports the four vars into their shell, re-runs deploy.

The wiki/README first-deploy checklist exists and is good
documentation. But:

- It's docs-not-flow. The operator only finds it after failing.
- It assumes the operator wants giscus configured (no path for "yes
  wiki, no comments").
- It doesn't address the `.env` / shell-export persistence question —
  the env vars survive only until the operator's next shell.
- `wiki-init.sh --with-giscus` already does the right thing (fetches
  IDs via `gh` and bakes them into the comments.html partial), but
  it's invoked manually after the operator has read the docs deeply
  enough to know it exists.
- **`wiki-deploy.sh` gate 1 has no `.env` loader.** No script in
  `scripts/` sources `.env`. Even if the operator persists their IDs
  in a project-local `.env`, the deploy gate doesn't see them unless
  the operator manually sources the file in the same shell.

This is the real problem: the orchestrator owns the gate, owns the
fetcher, and owns the mkdocs.yml templating, but it doesn't own the
**persistence layer between fetch and deploy**.

### Generalize the shape

Every optional feature has a similar pattern:

| Feature        | Secret(s)                              | Today                             |
|----------------|----------------------------------------|-----------------------------------|
| wiki + giscus  | 4 GISCUS_* vars                        | shell export + partial substitute |
| GH integration | `gh` auth (already-installed PAT)      | inherited from `gh auth login`    |
| Reference corpus (M036a) | API keys for Tier 2 LLM extraction | M030 routing handles in-process |
| Wiki analytics (P02)     | Plausible/GA token                | not yet specified                 |
| Edit-link auth (P02)     | n/a (read-only GH URL rewrite)    | n/a                               |

Today only **wiki+giscus** and (transitively) **M036a Tier 2 extract**
need operator-managed secrets. Everything else either piggybacks on
`gh auth login` or has no secret. So the immediate scope is small.

The architectural question is: when **future** features (analytics,
Notion-sync adapter, etc.) want operator-managed secrets, do we want a
**single secrets-walkthrough primitive** they all plug into, or
per-feature flows? Constitution Principles I (Context Minimization)
and X (Templating Over Inference) both push toward a single primitive
declared in a recipe.

## 3. Proposed shape: layered pre-deploy secrets pattern

Three layers, each independently valuable:

### Layer 1 (smallest, ships immediately): `.env` loader in deploy gates

`scripts/wiki/wiki-deploy.sh` sources `<root>/.env` if present BEFORE
gate 1. No flag, no behavior change for operators who already export in
shell or for CI environments where vars come from the runner. Three
lines of bash. Better gate-1 failure message:

```
FAIL: gate 1 — GISCUS_REPO unset.
HINT: run `bash scripts/diagnostics/giscus-ids-from-gh.sh \
        --repo <owner>/<repo> --category "Wiki Comments"` and paste
      the four export lines into <root>/.env (gitignored), then
      re-run deploy.
```

Where `.env` lives is operator territory. Already gitignored in most
projects.

### Layer 2 (one-step bigger): `wiki-init.sh --with-giscus` writes `.env` too

Today, `wiki-init.sh --with-giscus` fetches IDs via `gh`, parses
them, sed-substitutes into `wiki/overrides/partials/comments.html`,
and runs the verifier with the values exported only into the
verifier's process. It does NOT persist the values anywhere the
operator's deploy shell can see.

Add: after the partial substitute, append the four `export GISCUS_*`
lines to `<project>/.env` (idempotent — replace existing block under a
marker like `# >>> orchestrator-managed: giscus >>>`).

Now the flow is symmetric: operator runs `orchestrator:wiki-init
--with-giscus`, orchestrator persists the secrets to `.env`, deploy
gate reads them back. No manual export step.

### Layer 3 (post-launch): generalized `secrets-recipe` primitive

When a second feature wants operator-managed secrets (analytics token
in P02 is a candidate), don't repeat the layer-2 pattern per-script.
Lift it to a recipe:

```yaml
# packaging/bundle/secrets/wiki-giscus.yml
feature: wiki-giscus
required_vars:
  - name: GISCUS_REPO
    fetcher: scripts/diagnostics/giscus-ids-from-gh.sh
    fetcher_args: ["--repo", "{{repo}}", "--category", "{{category}}"]
  # ...
persistence: project-env  # or operator-shell, ci-secret, etc.
```

A new `scripts/util/secrets-walkthrough.sh` consumes the recipe,
fetches via the declared fetcher, persists per the declared
persistence target, runs the declared verifier. Per Principle X
(Templating Over Inference). Defer until a second consumer arrives;
single-feature primitive is premature.

## 4. Adaptive-init UX

The operator's broader framing: when the operator inits a project,
ask which features they want and walk them through what each needs.
Today's shape is `--with-wiki --with-giscus --with-github` flag
passthrough on the install scripts and on `commands/start.md`, which
is correct plumbing but not adaptive UX.

### Detection signals (cheap, local)

`scripts/lifecycle/start.sh` already has the four-branch detector
(greenfield-empty / greenfield-with-materials / existing-codebase /
migrating). Project-shape detection on top of that lives in
`.orchestrator/proposals/papercut-discuss-project-shape.md` —
deferred but designed. The shape verdict (`simple | complex`) is the
right gate for "should we even surface a feature menu?"

Layer the signals:

- **Branch** (already detected): existing-codebase + git-history-rich
  → "this project is mature; consider wiki for the team."
- **Shape** (deferred): simple → skip menu, run lean. complex → offer
  menu.
- **Operator override**: `--menu` to force, `--no-menu` to skip.

### Feature menu (v1, what's actually shippable)

| Feature         | Status today                                       | Menu prompt                                       |
|-----------------|----------------------------------------------------|---------------------------------------------------|
| wiki            | M032 closed; `--with-wiki` ships                   | "Stand up an mkdocs wiki for team feedback?"      |
| wiki + giscus   | M032 closed; `--with-giscus` ships                 | (chained) "Add GitHub-Discussions comments?"      |
| GH integration  | M013 closed; `--with-github` ships                 | "Project state to GitHub Issues/Projects?"        |
| Constitution    | M033 P02 closed                                    | "Author a project constitution?"                  |
| Reference corpus | M036a closed; `commands/extract.md` invoked manually | "Have a doc corpus to ingest? (PDF/DOCX/MD)"   |
| Conversus       | M026 closed; `commands/conversus-gate.md` exists   | "Adversarial multi-agent review on key artifacts?" |

Everything else (design layer, multi-runtime parity, living
documents) is post-launch demand-driven and shouldn't appear in the
menu until shipped.

### Per-feature secrets walkthrough

For each feature the operator opts into:

- **wiki + giscus**: invoke `wiki-init.sh --with-giscus` (chained),
  which (Layer 2 above) writes `.env`. If `gh` isn't authed, walk
  through `gh auth login` first.
- **GH integration**: `gh auth status` check; if unauthed, walk
  through `gh auth login`.
- **Reference corpus**: ask for source dir; invoke
  `commands/extract.md` flow per `orchestrator:extract`. Tier 2
  routing's API keys handled by M030's existing config (already
  operator-owned).
- **Constitution**: invoke `commands/constitution.md` (M033 P02 already
  authored this surface; stack starter selection is already
  interactive).
- **Conversus**: `conversus:status` check, route to `conversus:login`
  if needed.

### Right-sized escape hatch

Tie to the M031 Quick/Standard/Full tier model. `start --yes`
(auto-accept defaults) bypasses the menu entirely; defaults to
no-extras for `simple` shape, "wiki + constitution" defaults for
`complex` shape, operator can flip later via `wiki-init` /
`constitution` invocations directly. The menu is rigor for the *plan*,
not friction for the *user* (M033's grilling-protocol § Recommendation,
not interrogation).

### Claude Code interaction shape

Today's CC affordances for this shape are:

1. **Slash command** invokes the orchestrator skill, which renders
   inline assistant prose with a numbered question + recommended
   default. Operator answers in chat. Skill consumes answer, renders
   next question. This is what `commands/start.md` already implements
   for branch disambiguation (US-1 AS-5).
2. **`AskUserQuestion` tool** — structured prompt with single-keystroke
   answers. Sharper UX but requires the skill's running context to
   call the tool; today's `start.md` flows are bash-script-driven
   (`scripts/lifecycle/start.sh`), so the bash side can't call CC
   tools. The skill *wrapping* the bash script could.
3. **Hand off to a spawned subagent** for the menu walk, then resume.
   Heavier; loses operator-in-the-driver's-seat feel.

**Pick #1**: extend the existing grilling-protocol pattern from
`start.md`'s branch disambiguation. The skill prose asks the question,
operator answers in chat, skill writes the answer to a marker file
that `scripts/lifecycle/start.sh` reads on resume. Same pattern as
the M033 P01 disambiguation already ships. Doesn't require CC tool
features that aren't already proven in the orchestrator.

#2 (`AskUserQuestion`) is the upgrade path if/when the orchestrator
moves to a slash-command-as-skill pattern that runs in-context rather
than dispatching to a bash driver. Worth tracking but not v1.

## 5. Pre-launch slice (PBJ this week) vs post-launch

> **SHIPPED 2026-05-06 — Layers 1+2** in commit `75582a09`
> (`papercut-wiki-deploy-env-loader.md`). `wiki-deploy.sh` now sources
> `<root>/.env` before gate 1; `wiki-init.sh --with-giscus` writes the
> four `GISCUS_*` exports to `<project>/.env` under a managed marker
> block; `wiki/.gitignore` template + first-deploy-checklist collapse
> rode in the same paper-cut. Layer 3 (generalized secrets-recipe
> primitive) remains legitimately deferred to post-launch demand-driven,
> gated by a second consumer arriving with operator-managed secrets.
> Frontmatter `status: pending` reflects Layer 3 still being open;
> `shipped_layers: [1, 2]` records what's already done. Design rationale
> below preserved verbatim for Layer 3 work.

### What PBJ-central needs THIS week

- **Configure giscus for THEIR repo** (not Build-Fractal's).
  Mechanism: `bash scripts/lifecycle/wiki-init.sh --with-giscus
  --project-dir /path/to/pbj-central --repo <pbj-org>/<pbj-repo>
  --category "Wiki Comments"`. **This already works today.**
- **Persist the IDs so deploy doesn't re-fail.** Not solved today.
- **No other deploy-time secrets needed** (analytics et al. not yet
  specified anywhere).
- **Operator-info hardcodes**: audit found nothing blocking. The one
  cosmetic cleanup (commands/github-status.md `REPO_SLUG` example) is
  not blocking PBJ ship.

### Smallest pre-launch slice (cheap; ~1–2 hours total)

1. **`scripts/wiki/wiki-deploy.sh`**: source `<root>/.env` if present,
   before gate 1. Three lines of bash, one acceptance fixture. Better
   gate-1 failure message naming `.env` and the fetcher script. (Layer
   1 above.)
2. **`scripts/lifecycle/wiki-init.sh --with-giscus`**: append four
   `export GISCUS_*` lines to `<project>/.env` under a managed marker
   block. Idempotent (replace block on re-run). One acceptance fixture.
   (Layer 2 above.)
3. **`wiki/.gitignore` template**: add `.env` if not already present.
   (Or check at install time and warn if `.env` isn't ignored — paranoid
   but cheap.)
4. **`wiki/README.md` first-deploy checklist update**: collapse the
   8-step recovery to "run `wiki-init --with-giscus`, then deploy."
   The old long-form stays as fallback for operators who want to
   understand what's happening.

This slice ships PBJ-central with a clean first-deploy: they run
`orchestrator:init --with-wiki --with-giscus --repo X/Y --category Z`
and deploy works on first try.

### What defers to post-launch

- **Adaptive feature menu in `start.md`** — the bigger UX. Lands as
  M033 fast-follow or as new M040. After PBJ team's first feedback
  signal, when we know which features they actually wanted to be
  asked about.
- **Project-shape classifier integration** — already deferred via
  `papercut-discuss-project-shape.md`. Composes with adaptive menu;
  ships separately.
- **Generalized secrets-recipe primitive (Layer 3)** — premature
  abstraction until a second feature wants operator-managed secrets.
  Defer until the second consumer arrives.
- **`AskUserQuestion`-based UX** — requires skill-as-runtime shift.
  Not a launch dependency.
- **Cosmetic doc cleanup** (`commands/github-status.md` REPO_SLUG
  example) — bundle into next paper-cut sweep. Five minutes.

### Where the pre-launch slice lands

Two reasonable homes:

- **Bundle into M037 P02** when it enters planning. P02 is
  "round-3.5 polish after PBJ feedback signal" — but the signal will
  surface AFTER PBJ has tried to deploy. If gate 1 fails on PBJ's
  first attempt, the signal is contaminated by exactly the friction
  this slice removes. Pulling these three changes INTO P02's scope
  before PBJ enters the wiki is too late. Pulling them out of P02's
  scope and shipping NOW means P02 stays narrow.
- **Standalone paper-cut to `wiki-deploy.sh` + `wiki-init.sh`**, ships
  before PBJ deploys. Single small PR. Doesn't touch any milestone.
  Cleanest.

Recommendation: **standalone paper-cut**, captured as a proposal
parallel to this one (`papercut-wiki-deploy-env-loader.md` or
similar), shipped same day. M037 P02 stays narrow.

## 6. Recommended next-step shape

If I were the operator and I wanted the wiki up for PBJ this week with
the cleanest path forward, I would:

**Now** (1–2 hours, before PBJ deploys):

1. Author `papercut-wiki-deploy-env-loader.md` capturing Layers 1+2
   above as a single small PR.
2. Ship it: `wiki-deploy.sh` sources `.env`, `wiki-init.sh
   --with-giscus` writes `.env`, `wiki/.gitignore` includes `.env`,
   first-deploy checklist updated to the new shape.
3. Hand PBJ-central operator the one-line invocation:
   `bash scripts/lifecycle/wiki-init.sh --project-dir <path>
   --with-giscus --repo <pbj>/<repo> --category "Wiki Comments"`
   (or if init hasn't run yet, the `init --with-wiki --with-giscus`
   compound). Deploy works on first try.

**Defer to post-launch** (after PBJ feedback signal informs scope):

4. `start.md` adaptive feature menu — author as proposal then size.
   Not blocking launch; M037 P02 / fast-follow milestone.
5. Project-shape classifier (already deferred at
   `papercut-discuss-project-shape.md`).
6. Generalized secrets-recipe primitive (Layer 3) — wait for second
   consumer.
7. Cosmetic operator-info doc cleanup — next paper-cut sweep.

The audit confirms there's no operator-info hygiene problem in
shipped surfaces today. The friction PBJ would hit is the
fetch-vs-deploy persistence gap, which Layers 1+2 close cheaply.
Everything else is genuine UX work that benefits from PBJ's first
feedback signal informing the design.

## Cross-references

- `.orchestrator/proposals/install-template-preserve-operator-keys.md` —
  inverse of this audit (operator-authored config getting clobbered);
  M035 install territory.
- `.orchestrator/proposals/papercut-discuss-project-shape.md` —
  project-shape classifier; composes with adaptive-init menu.
- `.orchestrator/proposals/M033-onboarding-experience.md` § Findings
  D + E + F — materials intake / ideation / custom-block authoring;
  feature-menu candidates.
- `.orchestrator/proposals/M037-wiki-team-feedback-ready.md` § P02 —
  natural home for adaptive-init slice if it grows beyond the
  paper-cut.
- `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`
  Principle XVI (Distribution Surface Integrity) — the constitutional
  framing for this whole question.
- `wiki/README.md` § "First-deploy checklist" — current
  documentation surface that the Layer 1+2 ship simplifies.
- `scripts/lifecycle/wiki-init.sh` — `--with-giscus` flow (already
  fetches IDs); needs `.env` write in Layer 2.
- `scripts/wiki/wiki-deploy.sh` — gate 1 hard-fail surface; needs
  `.env` source + better failure message in Layer 1.
- `scripts/diagnostics/wiki-giscus-config-check.sh` — gate 1
  implementation; consumes env vars set before invocation.
