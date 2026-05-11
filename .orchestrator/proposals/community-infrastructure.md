# Proposal: Community Infrastructure — what happens when a stranger arrives

**Captured**: 2026-05-11
**Shape**: Decision + small artifact bundles. Picks channel, drafts governance, sets triage cadence, surfaces changelog. ~3–5 days of work spread over ~2 weeks once decisions land.
**Predecessors**: M035 (closed — public install paths live so external contributors can install + try the tool), `distribution-surface` (sibling RFC — distribution drives traffic, community holds it), `adoption-measurement` (sibling RFC — issue volume + topic clusters are shared signal layer)
**Source**: 2026-05-11 zoom-out on adoption backlog. Engineering launched 2026-05-09 with no community surface, no CONTRIBUTING.md governance, no declared triage SLA, no changelog distribution beyond `orchestrator:update`.

## Status

**RFC capture only.** Smallest viable cut (~2 days) listed below; bigger items optional fast-follows. Promotion gates on channel-choice decision (Brett owns).

## TL;DR

Strangers can now install. If one of them files a useful issue, what happens? Today: nothing systematic. There's no chat surface for "how do I X?" questions that aren't bug reports, no contributor onboarding for outside PRs, no declared bar for what gets accepted, no triage SLA, no changelog surface that users see after `update`.

This proposal captures the community-infrastructure surface as a **standing workstream parallel to engineering and distribution**. Three-leg stool: distribution drives traffic, community holds the audience, measurement reads the signal.

## Why now (not demand-driven)

The surface needs to exist *before* the first outside contributor arrives, not in response to them arriving. A first-time contributor who files an issue and waits 6 weeks for a response is a contributor who never comes back. The cost of having CONTRIBUTING.md + a declared SLA on launch day is hours; the cost of *not* having them is compound — every unresponded issue degrades reputation.

## Scope

### 1. Channel decision (load-bearing)

Where do users go for "how do I X?" questions that aren't bug reports?

| Channel | Strengths | Weaknesses |
|---|---|---|
| **GitHub Discussions** | Same surface as issues, async-first, searchable, zero new infra, links from search engines | Lower engagement than chat; slow for casual questions |
| **Discord** | Synchronous chat, casual question-friendly, vibrant community feel | Searchability is poor (Discord is a content roach motel), requires moderation, splits attention from GitHub |
| **Slack** | Enterprise-familiar | Invite-only feels exclusive for OSS; same searchability problems as Discord; bad fit |
| **None** | Zero infrastructure | Every casual question becomes a GitHub issue; signal-to-noise degrades |

**Recommendation**: **GitHub Discussions only at launch.** Re-evaluate Discord when active-user count justifies sync surface (~50+ active users). Promotion path is well-defined; demotion is also well-defined (Discord can go inactive without breaking anything).

### 2. CONTRIBUTING.md governance

Declared bar for outside PRs. Today: missing.

Sections:
- **What we accept** — bug fixes, doc improvements, paper-cuts. What we don't — feature additions without an issue, refactors, style changes
- **Constitution principles compliance** — linked from CONTRIBUTING with explicit "what does this mean for a PR?" framing
- **Test coverage expectations** — verifier scripts in `tools/verify/` for any new shape; existing tests must pass
- **Commit message format** — existing convention (`paper-cut(probe): ...`, `feat(M###): ...`, `fix(M###): ...`); document it
- **PR review SLA** — what timeline can a contributor expect? (See #2 below for SLA decisions)
- **Code of Conduct** — Contributor Covenant 2.1 (standard, fast to adopt)

### 3. Triage cadence + SLA

Declared expectations:
- **New issues**: triaged (label + acknowledgment comment) within 7 days
- **Bug reports**: acknowledged within 3 days
- **First-time contributor PRs**: first response within 7 days
- **All other PRs**: first response within 14 days

Triage labels:
- `bug` / `feature-request` / `docs` / `question` / `discussion` / `confusion`
- `accepted` / `wontfix` / `duplicate` / `needs-info`
- `good-first-issue` / `help-wanted`
- Cluster labels for measurement: `confusion:install`, `confusion:command`, `friction:review-gate`, `friction:wiki-nav` (aligns with `adoption-measurement` topic-cluster needs)

Stale-issue policy: 90 days of inactivity → auto-comment asking for status; 30 more days → close as `stale`. Automated via GitHub Actions.

### 4. Showcase / "who's using this" surface

Wall of projects + one-line use case. Submission flow:
- PR to add an entry to `showcase.md` (or `docs/showcase.md`)
- Required fields: project name, link, one-line use case, contact for review
- Maintainer review = "is this real" check, not curation

Submission flow handoff from `distribution-surface` proposal (which captured the *need*) to this proposal (which owns the *mechanism*).

### 5. Changelog distribution

`orchestrator:update` exists. Missing: a "what's new" surface users see *after* update.

Three-tier surface:
- **Tier 1 (must)**: render `CHANGELOG.md` excerpt for the version delta in the post-update terminal output. ~30-line snippet of headlines.
- **Tier 2 (should)**: changelog wiki page generated from `CHANGELOG.md` (M037 wiki primitive composes naturally)
- **Tier 3 (nice)**: RSS feed for power users who want changelog notifications without polling. Optional.

### 6. Contributor recognition

Costs nothing; compounds. Two surfaces:
- README section: "Contributors" with link to GitHub contributors graph + explicit names for noteworthy contributions
- CHANGELOG.md: per-release "Thanks to @username for X" mentions in each release block

## Smallest viable cut (~2 days)

Ship in one bundle:

1. Enable GitHub Discussions in repo settings (5 min)
2. Add `CONTRIBUTING.md` (~half-day editorial)
3. Add `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1 — copy-paste with maintainer email; 10 min)
4. Declare triage SLA in README "Community" section (~1 hour)
5. Add label scheme to repo (~30 min via `gh api`)
6. Tier 1 changelog excerpt in `commands/update.md` output (~half-day; reuses CHANGELOG.md format)

This bundle is launch-completion work — should ship before the first external-traffic event (Show HN, etc.) per `distribution-surface` sequencing.

## Larger follow-ups (~3 more days, fast-follow)

- Stale-issue automation (GitHub Action, ~half-day)
- Showcase submission flow + initial 3 entries (PBJ, LakeLedger, bbt-crm — half-day each with consent review)
- Contributor recognition README section + per-release CHANGELOG patterns (~1 day editorial)
- Tier 2 changelog wiki page (~1 day; needs M037 wiki integration confirmed)

## Out of scope

- Hosted forum software (Discourse, Vanilla) — overkill at current scale
- GitHub Sponsors setup — separate decision; revisit at 100+ active users
- Bug bounty program — premature
- Co-maintainer governance — premature (current maintainer count = 1)
- Translation / i18n governance — premature
- Commercial / sponsored support tiers — out of scope; tracks with the M026 OSS-posture conversation

## Open questions

- **#Q-1 channel** — Discussions only, or Discussions + Discord from day 1? Recommendation: Discussions only; Discord when active-user count justifies sync surface
- **#Q-2 triage SLA aspirational vs strict** — 7-day issue triage feels right but creates an expectations contract. Recommendation: declared as "target" not "guarantee" with a footnote about maintainer bandwidth. Honest framing.
- **#Q-3 stale-issue auto-close** — 90+30 days feels conservative. Alternative: 60+15 days, more aggressive cleanup. Recommendation: 90+30 to start; tighten if stale-issue volume becomes a triage burden.
- **#Q-4 CODE_OF_CONDUCT maintainer contact** — needs an email or anon-reporting surface. Recommendation: `conduct@<domain>` once a domain is set; until then, Brett's email with a note about future migration.
- **#Q-5 changelog excerpt format** — full CHANGELOG.md delta, headlines only, or "summary + link"? Recommendation: headlines + link, render ~30 lines max.

## Trigger condition

Community-infrastructure fires **now**, not demand-driven. The smallest-viable-cut bundle (above) should ship before the first external-traffic event from `distribution-surface`. Larger follow-ups can drip over the following 2–4 weeks.

## Blast radius

- New top-level files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`
- GitHub repo settings change: enable Discussions, add labels (manual one-time op)
- Optional GitHub Actions workflow: `.github/workflows/stale-issues.yml`
- Modification to `commands/update.md` + `scripts/lifecycle/update.sh` for changelog surfacing
- Modification to `README.md` for triage SLA + contributor recognition
- No changes to dispatch / verify / orchestration

## Relationship to adjacent proposals

- **distribution-surface** (sibling RFC): distribution drives traffic; community holds the audience. Three-leg stool with measurement. Showcase mechanism handoffs from distribution to here.
- **adoption-measurement** (sibling RFC): triage labels align with topic-cluster signal needs. Issue volume + cluster trends are read by the measurement dashboard.
- **M035 P07** (existing): P07 polishes the README. This proposal adds CONTRIBUTING/CODE_OF_CONDUCT *alongside* README + adds a "Community" section *to* README. Sequenced after P07's README polish to avoid merge conflicts.
- **M037** (closed): wiki integration is foundational for Tier 2 changelog wiki page.
- **M040** (existing): contradiction-gate routes through `commands/comments.md` human-gated apply queue. Community contribution review uses the same review-queue convention. Compose.

## Promotion path

Smallest-viable-cut ships as a single bundled PR within 2 weeks of M035 close. Larger follow-ups land as independent PRs over the following month. If community volume grows beyond manual-triage capacity, revisit (e.g., co-maintainer recruitment, automated triage bot, Discord with moderation rotation).
