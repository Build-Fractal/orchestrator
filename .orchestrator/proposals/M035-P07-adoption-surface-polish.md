---
schema_version: "1.0"
type: proposal
status: pending
priority: medium (launch-blocking polish, depends on M035 P02-P06)
captured_at: "2026-05-07"
captured_by: "session exploring readme + getting-started adoption gap"
folds_into: |
  Candidate phase scope for M035 packaging-and-distribution milestone.
  Naturally lands as M035 P07 (after P02-P06 publish the install pipelines
  so demo artifacts can point at the published package, not a clone).
  Alternative: standalone M040 milestone if M035 ships before P07 scope
  is ready.
---

# Proposal: Adoption-Surface Polish (candidate M035 P07)

**Captured**: 2026-05-07. Surfaced when reviewing what milestones cover the
"is the README delightful, on-brand, adoptable for a stranger" pass.
Answer at capture time: nothing in the queue does. M035 P02-P06 ships
mechanical install pipelines and a release page, but those are reference
prose, not adoption polish. M037 P01/P02 polish the wiki for non-author
*existing* users, not for first-impression readers. M033 polished the
*runtime* onboarding (warm front door, four-branch detection) but not the
*doc* surface a stranger lands on before installing.

## What "first sweep" already shipped (commit a6a786ef, 2026-05-07)

`README.md` and `docs/getting-started.md` got targeted updates closing the
most obvious staleness:

- README lede replaced (was: cold dive into M009/M018/P07 milestone
  codenames; now: one-line hook + concrete mental model).
- Version line refreshed to v0.9.3 (was: stuck at 0.9.2/M018).
- "When you'd reach for this" / "When you wouldn't" framing added so
  readers self-select instead of bouncing mid-install.
- Quick Start rewritten to lead with `/orchestrator-start` (M033 warm
  front door) including the four-branch routing table.
- `/orchestrator-do` and `/orchestrator-where` surfaced as recommended
  entry points alongside `/orchestrator-start`.
- Core Capabilities softened from reference-doc wall to concrete
  "what this gives you" prose.
- All Commands table demotes `init` to lower-level primitive, surfaces
  start/do/where as recommended entries.
- `docs/getting-started.md` Overview replaced with "next 30 minutes" arc.
- Step 2 in getting-started now recommends `/orchestrator-start`; init
  documented as the lower-level primitive.
- Step 4 now acknowledges that ideation / materials-intake /
  ingest-codebase produce a spec for you (was: "you must hand-author a
  spec at specs/001-your-feature/spec.md").
- Quick-path / one-shot-path callout at top of "Your First Orchestrated
  Project" so readers know the manual breakdown isn't the only way.

This closes the staleness gap and warms the first-impression framing.
It does NOT close the "delight" / "brand consistency" / "first-30-seconds
proof" gap — those need package-manager install paths shipped first and
benefit from a focused pass not a sweep.

## What this proposal covers

Five adoption-surface items the first sweep deliberately deferred:

### 1. Voice/brand consistency across the full doc surface

**Surfaces today**:
- `README.md` (just updated, sets reference voice)
- `docs/getting-started.md` (just updated, sets reference voice)
- `docs/recipe-authoring.md` — reads as cookbook
- `docs/hook-development.md` — reads as developer reference
- `docs/knowledge-management.md` — reads as system documentation
- `docs/ingesting-arbitrary-specs.md` — reads as feature doc
- `docs/migrating-from-speckit.md` — reads as migration guide

**Gap**: each doc was authored for its local audience; cumulative read
across the surface feels like seven different products. Voice consistency
isn't tone uniformity — it's recognizable point of view (precise,
candid, opinionated where it matters, respectful of the reader's time).

**Scope**: editorial pass across the 6 user guides + the 15 reference
docs. Audit checklist:
- Lede: does each doc open with what the reader will be able to do
  after reading, not what the doc *is*?
- Audience: is "who this is for" specific (developer authoring custom
  context recipes) not generic (developers)?
- "Why" before "what": does the doc explain why this surface exists
  before showing how to use it?
- Honest tradeoffs: are the doc's tradeoffs called out (eg. recipes are
  more powerful than hooks but harder to debug) or buried?
- Reference vs narrative: is the doc trying to be both, and failing at
  one? Reference docs should look like reference docs; narrative docs
  should have a beginning-middle-end arc.

**Effort**: ~1 day per doc surface * ~21 surfaces = 3-4 day sustained
pass. Realistically chunked into ~5 PRs.

### 2. `docs/why-this-exists.md` origin story

**Gap**: the M015-standalone-cutover narrative — why the orchestrator
exists as a separate project from spec-kit, what GSD-history informed
the design, what problems forced the multi-runtime story — is invisible
to a stranger. README touches the *what*; nothing touches the *why we
ended up here*.

**Scope**: ~1500-word narrative doc covering: spec-kit origin, GSD-1/2
predecessor lessons, the multi-context-window pain that drove
orchestration, the standalone cutover at v0.9.0, the constitution
codification of lessons. Cross-link from README "How it works" section.

**Why valuable**: adoption isn't just feature-fit; it's also "do I
trust the worldview this product encodes." A clear origin story is
the cheapest way to convey worldview without preaching it.

**Effort**: ~0.5 day. Mostly recall + structuring; the source material
exists in `.orchestrator/proposals/` and milestone summaries.

### 3. First-30-seconds proof artifacts

**Gap**: nothing on the doc surface lets a reader *see* the orchestrator
working in under a minute. A live install + start + do flow takes ~5min
locally and requires the reader to commit to running things. Asciinema
or a screen recording bridges the gap.

**Scope**: 3 artifacts:
- **Install + start asciinema** (~30s): `npx <package>` (or `brew install`)
  → `/orchestrator-start` → branch detection → constitution stack pick
  → first ingestion. Captured to a `.cast` file, embedded in README.
- **One-shot demo asciinema** (~30s): `/orchestrator-do "add an X to Y"`
  in a fresh project, watching the classifier route to Tier A and
  ship the change.
- **Autonomous milestone screen recording** (~2min, optional): a Tier C
  project running `/orchestrator-auto` end-to-end with status-check
  intercuts. Heavier than asciinema but the only way to convey the
  "walk away and come back" value proposition.

**Hard dependency**: this CANNOT ship before M035 P02-P06 — the demo
commands have to point at the actual published install path
(`npx`/`brew`/`curl | bash`), not at "clone this repo and run a bash
script." Asciinema captures with the wrong install command would have
to be re-recorded post-launch. Hence sequencing this AS M035 P07.

**Effort**: ~1 day for the two asciinema artifacts (recording, trimming,
embed). Screen recording adds ~0.5-1 day (more polish overhead). 1.5-2
days total.

### 4. Honest "When NOT to use this" section deepening

**Gap**: the first sweep added a bullet list ("the work fits in one
context window" / "you want a chat companion"). That's directionally
right but not complete. Real anti-patterns the orchestrator doesn't
serve:
- Exploratory research / spike work where you genuinely don't know what
  you're building yet — the orchestrator wants you to author a spec
  first, which is friction in this mode.
- Single-developer projects with no multi-session continuity needs —
  if it all fits in your head, the file-based-state-of-truth discipline
  is overhead.
- Projects with hostile constraints on file emission (sandboxes,
  ephemeral environments) — the orchestrator's State On Disk
  invariant assumes a persistent project tree.
- Pure greenfield ideation where the product shape isn't known —
  ideation grilling-protocol helps but isn't a substitute for actual
  user research.

**Scope**: replace bullet list with a short "When this isn't a fit"
section that names the four anti-patterns above with one-sentence
"reach for X instead" pointers (eg. "for spike work, use your runtime's
native flow until the shape is clear, then come back").

**Why valuable**: "When NOT" sections build trust. Products that don't
self-disqualify feel suspicious.

**Effort**: ~2 hours.

### 5. README hero-section visual polish

**Gap**: README opens with bold prose + a quoted version line. No
visual hierarchy, no proof, no scannable "what does this look like."
Today's competitive bar for an OSS DX tool is at least one of:
- Diagram of the mental model (we have an ASCII workflow diagram, but
  it's halfway down — should be near the top).
- Code-fence demo of the most representative invocation
  (`/orchestrator-start` shape + the prompt that follows).
- Badge row (build status, version, license) for at-a-glance
  legitimacy signaling.

**Scope**: relocate the workflow ASCII diagram to immediately after
"How it works"; add a code-fence showing the
`/orchestrator-start --auto-chain` flow with realistic prompts and
responses; add a minimal badge row (license, version, runtime support).

**Effort**: ~3 hours including testing badge rendering on GitHub.

## Out of scope

- **Changing the doc tooling** (mkdocs, the wiki publishing pipeline) —
  M037 P01/P02 owns wiki polish; M032 owns wiki distribution.
- **Marketing-website-grade polish** (landing page, analytics, hosted
  demo). The goal is GitHub-README-grade adoption polish, not building
  a marketing site.
- **Tutorial / lesson series** — separate post-launch work if demand
  signal arrives. The orchestrator's narrative is "tool for an
  experienced developer", not "learn-this-craft-from-scratch".
- **Internationalization** — English only at launch.

## Dependencies and sequencing

| Item | Depends on |
|---|---|
| Voice consistency pass (1) | None. Could land any time after the first sweep. |
| Origin story doc (2) | None. |
| First-30-seconds asciinema (3) | **HARD DEP**: M035 P02-P06 must publish install paths first. |
| When-NOT deepening (4) | None. Composes with first sweep. |
| Hero-section visual polish (5) | None, but item 3's asciinema embeds here, so 3 should land first or in the same PR. |

Items 1, 2, 4 can ship as a single PR pre-launch (`docs/adoption-surface-pre-launch.md` worth of work). Items 3 and 5 require M035 P02-P06 to land first.

## Why this slots as M035 P07 (not a separate M040)

**Argument for M035 P07**:
- Items 3 and 5 hard-depend on M035 P02-P06's publishing pipelines.
- Adoption polish IS launch readiness. Splitting it from the launch
  milestone risks shipping M035 with a still-stale README.
- Items 1, 2, 4 can land before M035 P02-P06 ships and don't block
  the launch event itself.

**Argument for separate M040**:
- The first sweep already closed the worst staleness, so launch isn't
  blocked on this work the way it would be on the install pipelines.
- Editorial passes have unbounded scope creep risk; isolating them
  from a milestone that has hard ship targets keeps M035 disciplined.

**Recommendation**: fold as M035 P07. Sequence after P02-P06 so item 3's
asciinema points at the published commands. Cap P07 at 5 days
(items 1+2+4+5 ~= 5 days; item 3 ~= 1.5-2 days; reuse the 5-day cap to
force editorial discipline). If P07 overruns, split off into M040 mid-flight
rather than letting it block the launch ship date.

## Cross-references

- First-sweep commit: `a6a786ef` ("docs/readme-getting-started: first-sweep
  adoption-surface polish") — read the commit message for the explicit
  list of what shipped vs what deferred.
- M035 brief: `.orchestrator/proposals/M035-packaging-distribution.md` —
  parent milestone; P07 absorbs into its phase tree.
- M037 brief: `.orchestrator/proposals/M037-wiki-team-feedback-ready.md` —
  related but distinct surface (wiki for existing users, not README for
  first-impression readers).
- M033 summary: `.orchestrator/milestones/M033/M033-SUMMARY.md` —
  M033's `/orchestrator-start` warm front door is the runtime-side
  counterpart to this doc-side polish.
- Constitution amendment brief: `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md` —
  Principle XVI (Distribution Surface Integrity) is the constitutional
  framing for adoption-surface integrity.

## Addendum (2026-05-11) — P07 #3 blocked on first v* tag publication

Surfaced when working the P07 sub-item sweep. `npm view @build-fractal/orchestrator version` returns `E404 Not Found`; the npm, Homebrew, and curl-pipe-bash publish pipelines exist (M035 P02-P06 shipped to disk and `validate-milestone.sh M035` reports 185/185 PASS), but no `v*` tag has been pushed, so MOS-3/MOS-4/MOS-5 have not fired and no installer artifacts are reachable from a public package manager.

Recording asciinemas against the current clone-and-bash install path would lock the demos to a transient install shape that disappears the moment the first `v*` tag publishes. Either the recordings would need to be re-recorded post-publication (the failure mode #3 already names as the hard dep), or the README would briefly carry asciinemas pointing at install commands the launch event itself is supposed to retire.

**Decision**: defer P07 #3 until the first `v*` tag publishes. Revisit when MOS-3/MOS-4/MOS-5 land — at that point `npx @build-fractal/orchestrator init` (or equivalent) becomes the canonical demo invocation, and the asciinemas can be recorded against the launch-event install shape they were designed for.

**Trigger to revisit**: first successful `npm view @build-fractal/orchestrator version` (returns a real version string instead of E404). Until then, P07 #3 stays unscheduled.

P07 sub-items #2 (origin story) and #5 (hero polish) shipped 2026-05-11 in this same sweep — they have no dependency on the publish pipelines and unblock immediately.

## Open questions

1. **Voice consistency pass: who edits?** Editorial work tends to need
   one consistent author for voice consistency. Either the operator
   takes the pass solo, or a single subagent spawns once with the full
   doc surface in context. Pick before P07 enters planning.
2. **Asciinema vs MP4**: asciinema is text-based (terminal recordings
   re-render at any size, embed cleanly in markdown via JS player or
   GIF export). MP4 supports more visual fidelity (browser interactions,
   IDE integration shots) but heavier. Recommendation: asciinema for
   items 3.1 and 3.2; consider MP4 for 3.3 only if M035 P02-P06 lands
   browser-side install affordances worth showing.
3. **License/version badge source**: shields.io is the obvious choice
   but adds an external-image dependency in README. Alternative:
   GitHub's own auto-badges. Decide at P07 planning time.
4. **Should item 1 (voice consistency) extend to references/?** The 15
   reference docs are deeper-disclosure surfaces; non-launch-blocking
   readers might never reach them. Recommendation: yes for the docs/
   user guides (6 surfaces), defer references/ to demand-driven
   post-launch unless patterns emerge that justify the bigger sweep.
