---
schema_version: "1.0"
type: operational-runbook
status: pending-execution
priority: high (PBJ this week, gates M037 P02 entry)
captured_at: "2026-05-07"
captured_by: "session drafting PBJ-agent prompt for round-3 dogfood"
gates:
  - "M037 P02 spec authoring depends on the synthesis output from this protocol"
  - "round-3 dogfood signal completion before 2026-05-12 keeps M035 launch on track"
folds_into: |
  Operational artifact, not a milestone. One-shot execution; archive
  to `.orchestrator/runbooks/` (or equivalent) once signal lands and
  M037 P02 enters spec authoring against the captured input.
---

# PBJ Round-3 Wiki Deploy + Feedback Protocol

Operational runbook for the PBJ-central wiki dogfood ship this week. The
operator hands the **PBJ-Agent Prompt** section below to a Claude Code
session inside PBJ-central; the orchestrator session here is the source
of authority for the steps and the feedback synthesis.

## Why this protocol exists

PBJ-central is the **live dogfood signal for the entire orchestrator
process** — the only second-downstream consumer beyond this repo, the
only project currently exercising the full reference-corpus + spec +
decision-log + milestone-history surface. Their feedback during the
next two weeks shapes whether the orchestrator launches with confidence
or with unknowns.

**M037 P01 shipped** (2026-05-06) — homepage card grid, version:→title:
nav projection, DR-### heading-shape pivot, nav.tabs, toc_depth, edit_uri,
install-template config.yml clobber fix. The wiki now renders correctly
and is usable for non-author readers.

**M037 P02 is gated on PBJ feedback** — F1.2 tag-driven nav subgrouping,
F2 GitHub source-link rewrite, F5 knowledge card grid, three plugins
(mkdocs-tags / mkdocs-redirects / git-revision-date-localized). Each
has open design questions that need PBJ's reading-pattern signal to
resolve. P02 cannot enter spec authoring until at least one of:
calendar trigger fires (5 days post-P01-merge), or N concrete pieces
of nav-or-section-shape feedback land. Brief #Q-3 picks the trigger
form when this protocol completes.

**The wiki-deploy .env paper-cut shipped** (2026-05-06, commits 75582a09
+ 0570b5b7) so PBJ can run the deploy on first try without hand-exporting
env vars. Without that paper-cut, gate 1 hard-fails and the friction
contaminates exactly the feedback signal we need.

## Pre-execution checklist (operator confirms before handing prompt)

- [ ] PBJ-central operator has push access to the project's GitHub repo.
- [ ] PBJ-central project has `gh` CLI authed (`gh auth status` exit 0).
- [ ] giscus App is installed on the repo and Discussions are enabled
      (operator UI step, not scriptable; see `wiki/README.md` §
      "First-deploy checklist" step 1).
- [ ] PBJ-central has the orchestrator already installed at some prior
      version (this is a refresh, not a first install). If not,
      `bash <orchestrator-source>/packaging/install/install-claude-code.sh
      --project-dir <pbj-central>` first.
- [ ] PBJ team (Don / Jenn / Polly + occasional contributors) is
      available for a 15-30min reading session within ~5 days of deploy.

If any precondition fails, pause and resolve before handing the prompt
— a half-prepared deploy will burn the round-3 signal.

## PBJ-Agent Prompt

Paste the block below verbatim into a fresh Claude Code session inside
the PBJ-central project directory.

```
You are the orchestrator agent inside PBJ-central. Goal: deploy the wiki
to the PBJ team (Don / Jenn / Polly + occasional contributors) cleanly
on first try, then capture feedback in a shape that informs M037 P02
planning.

Current state of the orchestrator (the source repo at
/Users/brettkellgren/Sites/spec-kit-orchestrator):
- M037 P01 shipped (homepage card grid + version:→title: nav projection
  + DR-### heading-shape pivot + nav.tabs + toc_depth + edit_uri +
  install-template config.yml clobber fix). PBJ team reads, not operator.
- M032 wiki-deploy .env paper-cut shipped 2026-05-06 (commits 75582a09 +
  0570b5b7). wiki-deploy.sh now sources <root>/.env before gate 1, and
  wiki-init.sh --with-giscus persists the four GISCUS_* exports to
  <project>/.env under a managed marker block. No hand-export step.

Step 1 — pull the orchestrator runtime into PBJ-central:
  /orchestrator-update
  (or directly: bash <orchestrator-source>/packaging/install/install-claude-code.sh
   --project-dir . --force)

Step 2 — wiki-init with giscus, ONE invocation:
  bash scripts/lifecycle/wiki-init.sh \
    --project-dir . --with-giscus \
    --repo <pbj-org>/<pbj-repo> --category "Wiki Comments"

  Pre-req: `gh auth status` must show authed. If not, `gh auth login` first.
  Pre-req: giscus App installed on the repo + Discussions enabled on the
  repo (operator UI step, see wiki/README.md § "First-deploy checklist"
  step 1).

  Expected: <project>/.env grows a `# >>> orchestrator-managed: giscus >>>`
  block with four `export GISCUS_*` lines. Verify with:
    grep -A 5 "orchestrator-managed: giscus" .env

  Verify .env is gitignored:
    git check-ignore .env  # exit 0 means yes
  If exit 1, add `.env` to .gitignore BEFORE next step.

Step 3 — dry-run deploy (no shell exports needed):
  bash scripts/wiki/wiki-deploy.sh --dry-run

  Expected: gate 1 PASSes without any pre-exported env vars in the shell.
  If FAIL, capture the gate output and stop — don't paper over.

Step 4 — real deploy:
  bash scripts/wiki/wiki-deploy.sh

  Confirm the deployed URL renders the M037 P01 surfaces:
  - Homepage shows a card grid (NOT a developer README)
  - Reference nav titles read as human labels (e.g., "QSO-21-06-NH
    (December 4, 2020)"), NOT slug shapes (e.g.,
    "REF-cms-rule-cms-qso-21-06-nh-2020-12")
  - Decisions section shows scannable concept headings, NOT bare DR-###
    codes
  - Top nav uses tabs, not a sidebar-only layout

Step 5 — open to PBJ team and seed the feedback ask. Send Don / Jenn /
Polly the wiki URL with this exact prompt:

  "We're opening the PBJ-central wiki for early feedback. Please spend
  15-30 minutes reading. We're specifically NOT asking 'is the content
  right' yet — we're asking 'is the wiki itself usable enough to give
  content feedback through.' Tell us:

  1. Did the homepage cards point you at the section you cared about,
     or did you bounce?
  2. Reference-corpus nav: are 70+ slug-titled entries scannable or
     overwhelming? If overwhelming, how would you want them grouped
     (alphabetical / topical bucket / date / source-doc-family)?
  3. Knowledge section: which 3-5 areas would you want as homepage
     cards alongside Constitution / Decisions / Reference?
  4. When reading a decision or memory entry, do you want a 'view source
     on GitHub' link, or is it noise?
  5. Is the wiki up-to-date enough that 'last edited 3 days ago' badges
     would build trust, or would they distract from the content?

  Reply in any shape — bullets, voice memo transcript, screenshot
  annotations all fine. Round trip in <5 days helps us not block
  on you."

Step 6 — capture the feedback verbatim into PBJ-central at:
  .orchestrator/feedback/M037-P02-pbj-round-3.5-input.md

  Frontmatter:
    captured_at: <date>
    captured_from: <reader names>
    maps_to: M037 P02 — F1.2 / F2 / F5 / plugins / #Q-3 trigger condition

  Body: each reader's raw response, then a synthesis section pulling
  out the bucket-mapping verdict, which knowledge cards win, F2 noise-
  vs-signal verdict, plugin-by-plugin verdict, and a recommendation
  on M037 brief #Q-3 (calendar trigger vs concrete-feedback trigger).

  Commit:
    feedback: M037 P02 round-3.5 input from PBJ team

  Hand the file path back to the operator. They'll trigger M037 P02
  spec authoring against it.

Hard constraints:
- bash 3.2 portable; no >2-chain bash without scripts/util/run-probe.sh.
- atomic commits.
- if any step fails, capture the failure verbatim and stop — do not
  modify orchestrator-shipped scripts to work around it (those go back
  to the source repo as paper-cuts, not as PBJ-side patches).
- DO NOT push the orchestrator-update commit until the operator OKs it
  (it's just an installer-driven file refresh, but the operator may
  want to review).
```

## Why these 5 questions specifically

Each question maps 1:1 to an open M037 P02 design choice. The synthesis
section in step 6 should produce a verdict for each:

| Q | Maps to M037 P02 surface | What the verdict resolves |
|---|---|---|
| 1 — homepage cards routing | F3 cards (P01 shipped) | Validation that P01's card grid actually serves first-impression routing; informs whether F5 knowledge card grid (P02) deserves equivalent treatment |
| 2 — reference-corpus nav | **F1.2 tag-driven nav subgrouping** | Bucket-mapping shape: alphabetical vs topical vs date vs source-doc-family. P02 plans the nav schema once this is known. |
| 3 — knowledge section cards | **F5 knowledge card grid** | Which knowledge surfaces deserve top-level cards vs nested URLs. P02's template needs this list. |
| 4 — view-source-on-GitHub link | **F2 GitHub source-link rewrite** | Noise-vs-signal verdict. If readers don't want it, P02 narrows to just the necessary subset of pages. |
| 5 — last-edited badges | **mkdocs-git-revision-date-localized plugin** (one of 3 P02 plugins) | Trust-builder vs distraction verdict. If trust-builder, P02 includes it; if distraction, drop the plugin from P02 scope. |

The recommendation on M037 brief #Q-3 (calendar trigger vs concrete-
feedback trigger for P02 planning entry) emerges from the volume and
specificity of feedback received. Concrete feedback on 3+ of the 5
questions = sufficient to enter P02 planning; less than that = wait
for calendar trigger (5 days post-P01 merge).

## Expected outputs back to the orchestrator repo

Once the PBJ-Agent has executed steps 1-6 and the team has filed
responses:

1. **Path to feedback file**: `<pbj-central>/.orchestrator/feedback/M037-P02-pbj-round-3.5-input.md`
   on PBJ-central side. Operator copies the file content (or pulls a
   committed reference) into this repo.
2. **Synthesis section** captures the 5 verdicts + the #Q-3
   trigger-form recommendation.
3. **Operator triggers M037 P02 spec authoring** against the synthesized
   input (`/orchestrator-specify` consumes the M037-wiki-team-feedback-ready.md
   brief plus this feedback file as supplementary input).

If feedback is sparse or ambiguous, operator decides whether to:
- (a) re-prompt the team with sharper questions narrowed to whichever
  surface got vague signal,
- (b) wait for calendar trigger and proceed with operator-best-guess
  on the unanswered design choices, or
- (c) ship a reduced-scope P02 covering only the surfaces that DID
  get clear signal.

## Cross-references

- `.orchestrator/proposals/M037-wiki-team-feedback-ready.md` — parent
  M037 brief; §11 #Q-3 is the trigger condition this protocol
  contributes the verdict to.
- `.orchestrator/proposals/papercut-wiki-deploy-env-loader.md` — the
  shipped paper-cut that closes the .env persistence gap (gate 1
  failure prevention).
- `.orchestrator/proposals/operator-secrets-and-adaptive-init.md` —
  parent thinking-document; §5 SHIPPED callout points back at this
  protocol as the in-flight execution.
- `commands/start.md` + M033-SUMMARY.md — the warm front door pattern
  the PBJ-central onboarding consumed at first install.
- `wiki/README.md` § "First-deploy checklist" — operator-side reference
  for the giscus App + Discussions enable steps that aren't scriptable.
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` — acceptance
  contract the deploy flow validates against.
