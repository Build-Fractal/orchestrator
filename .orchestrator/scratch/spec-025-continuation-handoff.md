---
type: agent-handoff-prompt
target_repo: "/Users/brettkellgren/Sites/orchestrator"
target_agent: "fresh Claude Code session with no prior context on this work"
origin: "2026-04-23 spec-025 / M014/P01 dogfood session"
scope: "continue spec 025 authoring through evaluate + discuss gates"
---

# Handoff: Continue spec 025 (M020) through clarify-weave + evaluate + discuss

You are picking up mid-stream on a multi-step workflow. Don't start over — a lot
is already done. Read this whole brief before touching anything. Read the
referenced files; don't rely on summaries.

## Where you are

**Repo**: `/Users/brettkellgren/Sites/orchestrator`. Branch: `main`.
Working tree is dirty with session output that has NOT been committed yet —
treat those edits as authoritative, not as work-in-progress you might stomp.

**The context you need**, in read order:

1. `.orchestrator/DECISIONS.md` D019 (newest row) — defines the three-pass ×
   intensity `orchestrator:specify` contract this session built. Read this
   first; everything else depends on it.
2. `commands/specify.md` — the three-pass contract as of 2026-04-23. Pass 2
   (author) + Pass 3 (gate) are the contract SSOT; the shell in
   `scripts/specify/specify.sh` does NOT yet implement them (that's part of
   the follow-up you'll file below).
3. `specs/025-knowledge-layer-maturation/spec.md` — the spec you're
   completing. Status is `Draft-Authored`. Pass 1 (scaffold) and Pass 2
   (author) already ran. Pass 3 (conversus gate) is deferred pending two
   upstream conversus PRs (already filed — see findings doc).
4. `specs/025-knowledge-layer-maturation/conversus/PRESSURE-TEST-FINDINGS.md`
   — why pass 3 is deferred; upstream conversus PRs #28 + #29 at
   `Build-Fractal/conversus` are pending merge.
5. `scripts/dispatch/adapters/tool/conversus.sh` — has a new TODO pre-flight
   guard (D019) that refuses TODO-filled artifacts. Regression test:
   `tests/test-conversus-adapter-shim.sh` (section 1b). All 4 tests pass.
6. `scripts/engine/intensity-analyze.sh` — the smell-test the session ran.
   Against spec 025's Input field it returned
   `recommended_intensity=Full` with `risk_signals=auth_detected,migration_detected`.
   That's why this spec was authored at Full intensity.

**What's already done** (don't redo):

- Three-pass × intensity contract: written + recorded (D019).
- TODO pre-flight guard: implemented + tested.
- Spec 025 Pass 1 + Pass 2: scaffold ran, body authored, shape-lint 10/10,
  complexity-probe `above-threshold reason=user_story_count>=5`, TODO count 0.
- Upstream conversus PRs: filed by the operator (#28 claude-code false-fail,
  #29 anthropic concurrency + retry). Not yours to touch.

## Your work (four tasks, in order)

### Task A — Weave clarify-loop answers into spec 025

The spec's `## Open Questions (defer to planning)` section currently has
five load-bearing ambiguities Q-1..Q-5. Full-intensity pass 2 ran a clarify
loop; the operator accepted all five recommended defaults. Your job is to
fold those answers into the spec body so the Open Questions section
reflects only genuinely-unresolved items (not "we picked a default and
left the question standing").

**Answers and exactly where to fold each**:

**Q-1 (query-surface-shape)** → **answer: exact-match + topic-keyword-index
for M020/P01; semantic/hybrid deferred unless M024 routing demonstrates
real need.**

- Remove Q-1 from `## Open Questions`.
- Update `FR-2 (query-surface)` prose to pin the shape: "resolves
  `topic=<X> [state=<S>]` via exact-match + topic-keyword-index into a
  structured result..."
- `CON-3` already carries the "no semantic/hybrid without evidence"
  rationale — leave it untouched.

**Q-2 (jaccard-threshold)** → **answer: default 0.7; validated against live
`knowledge/**/MEM*.md` at M020/P01 kickoff; operator-tunable via FR-6.**

- Remove Q-2 from `## Open Questions`.
- Add a new row to `## Assumptions` as `A-5 (jaccard-threshold-default)`:
  "Default Jaccard similarity threshold is 0.7. Validation against the
  live `knowledge/**/MEM*.md` tree occurs at M020/P01 kickoff; threshold
  is operator-tunable via FR-6 preferences."

**Q-3 (jaccard-feature-vector)** → **answer: `title` + `topic` + `tags[]`
frontmatter keys + first-paragraph content-words with a 50-token cap.**

- Remove Q-3 from `## Open Questions`.
- Update `CON-5 (jaccard-feature-vector-bounded)` to specify the vector:
  "The Jaccard clustering feature vector IS: frontmatter `title` +
  `topic` + `tags[]` keys plus first-paragraph content-words capped at
  50 tokens. Full-body tokenization remains out of scope in M020
  (revisit in M018 once context-compression lands)."

**Q-4 (preferences-precedence-direction)** → **answer: project wins over
user** (already the authored default; this answer just closes the question).

- Remove Q-4 from `## Open Questions` — the answer is already pinned in
  US-5 Acceptance Scenario 2 + FR-6 prose. No spec body changes needed.

**Q-5 (decision-history-retention)** → **answer: append-only in M020;
compaction deferred to a follow-up D-row if real growth curves warrant it.**

- Remove Q-5 from `## Open Questions` — the answer is already pinned in
  NG-6 + FR-7. No spec body changes needed.

**After weaving**: the `## Open Questions (defer to planning)` section
should contain ONLY the pre-discuss pressure-test gate deferral note
(the existing block about conversus upstream PRs). All five Q-* entries
removed. The frontmatter + body otherwise unchanged.

**Verify your weave**:

```bash
bash scripts/verify/spec-shape-lint.sh specs/025-knowledge-layer-maturation/spec.md
grep -c '<TODO:' specs/025-knowledge-layer-maturation/spec.md
bash scripts/knowledge/spec-complexity-probe.sh specs/025-knowledge-layer-maturation/spec.md
```

All three should behave as they did pre-weave: shape-lint 10/10, TODO
count 0, probe above-threshold. If any regress, you introduced a defect
— fix before proceeding.

**Promote status** after weave:

- Change frontmatter `status: "Draft-Authored"` → `status: "Ready-for-discuss-gate-deferred"`.
  (Per D019, Full+PASS would normally promote to `Ready-for-discuss`;
  we're one step short because Pass 3 is upstream-blocked. The
  "-gate-deferred" suffix signals that a re-gate run is expected when
  PR #28 + #29 land.)
- Add a line `**Last Revised**: 2026-04-23` already present — update it
  if you run on a later date.

### Task B — File the specify.sh implementation follow-up

D019 commits to a contract that `scripts/specify/specify.sh` does NOT yet
implement. This session deferred the implementation so the command
contract could land first. Your job is to file the follow-up so the work
isn't lost.

**Create a new spec** via the normal path — run
`bash scripts/specify/specify.sh` to scaffold, then author the body
manually (since the new author-pass isn't wired yet).

- **Description** (pass via `--description`): "Implement the three-pass
  (scaffold / author / gate) × intensity flow for `orchestrator:specify`
  per D019 contract in `commands/specify.md`. Wire Pass 2 (author) to
  draft spec body from Input + DECISIONS.md + constitution via
  `scripts/dispatch/dispatch-interface.sh`; at Full intensity, invoke
  `speckit.clarify` after the draft lands. Wire Pass 3 (gate) to
  intensity-scaled conversus gate invocation (Quick=skip, Standard=advisory,
  Full=strict). Intensity resolution: project default → smell-test
  escalation via `intensity-analyze.sh` → CLI `--intensity` override.
  Emit `specify_intensity_resolution` JSONL record. Preserve all current
  Pass 1 behavior byte-equivalently."
- **Milestone**: `M014` (this is M014 extended scope per D016).
- **Slug**: let specify.sh derive, or pass `--slug specify-three-pass-impl`.

After scaffold, author the body manually. The body should reference D019
as the driving decision and `commands/specify.md` as the contract SSOT.
FRs should cover: scaffold parity preservation, author-pass dispatch
wiring, Full-intensity clarify integration, Pass 3 intensity-scaled
invocation, intensity resolution chain, TODO pre-flight interaction (the
gate adapter already refuses TODOs — pass 2 must complete before pass 3
fires), the new JSONL record types, and byte-equivalent Pass 1 regression
tests.

**Do NOT implement the shell here** — that's the spec this creates, not
work you do in this session. Stop after authoring the spec body + running
the same verify triple (`spec-shape-lint`, `grep TODO`, `complexity-probe`).

### Task C — Run `orchestrator:evaluate` on spec 025

Spec 025 is authored. Run `orchestrator:evaluate` to classify tier and
create the M020 milestone directory + `M020-EVALUATION.md`.

Read `commands/evaluate.md` first. The command has intensity-aware
behavior; spec 025 should come out Tier C (knowledge-layer schema
authority + multiple user stories + downstream consumers). If evaluate
classifies it as Tier A or B, stop and surface — something's off, and
that's worth human review.

Expected outputs after `evaluate`:

- `.orchestrator/milestones/M020/` directory exists.
- `.orchestrator/milestones/M020/M020-EVALUATION.md` with `tier: C` in
  frontmatter.
- `.orchestrator/execution-log.jsonl` gains an `evaluate_classified` or
  similar record.

### Task D — Run `orchestrator:discuss` on spec 025

Tier C requires discuss before roadmap. Read `commands/discuss.md`.

Discuss generates spec-driven questions, creates `M020-CONTEXT.md` with
`status: draft`, and waits for operator input. Since you don't have an
operator in-session, do this:

1. Run the question-generation phase and present the questions.
2. Draft default answers for each question grounded in spec 025's body +
   D019 + D011/D013/D016 (all already referenced in the spec). Mark each
   answer as `[agent-default — operator review required]`.
3. Populate `M020-CONTEXT.md` with your drafted answers.
4. Leave `status: draft` (do NOT finalize). The operator will review +
   refine + finalize in a subsequent session.

Discuss output: `.orchestrator/milestones/M020/M020-CONTEXT.md` with
`status: draft` and populated body sections.

### Guardrails

- **Do not touch the upstream conversus repo** at `/Users/brettkellgren/Sites/conversus`. PRs #28 + #29 are the operator's to merge.
- **Do not commit** — leave the working tree dirty. The operator decides
  commit strategy.
- **Do not run `orchestrator:roadmap`** — discuss is not finalized,
  so roadmap's state-machine precondition isn't met. Stop at discuss/draft.
- **Do not attempt to re-run conversus gate** against spec 025. The
  upstream PRs haven't merged. Even with the TODO guard passing, both
  provider paths (claude-code / anthropic-OAuth) are still broken.
- **Do not implement the three-pass shell** in `scripts/specify/specify.sh`.
  That's the spec you create in Task B, not work this session delivers.
- **Preserve existing session work**. Files touched by the prior session
  (per `git status`): `AGENTS.md`, `CLAUDE.md`, `commands/specify.md`,
  `.orchestrator/DECISIONS.md`, `scripts/dispatch/adapters/tool/conversus.sh`,
  plus untracked files in `scripts/dispatch/adapters/tool/conversus-synth.py`,
  `specs/025-knowledge-layer-maturation/`, `tests/test-conversus-adapter-shim.sh`.
  Your Tasks A–D add to this set; they do not replace any of it.

### Verification before you call it done

Run this triple; all should pass:

```bash
bash tests/test-conversus-adapter-shim.sh
bash scripts/verify/spec-shape-lint.sh specs/025-knowledge-layer-maturation/spec.md
bash scripts/knowledge/spec-complexity-probe.sh specs/025-knowledge-layer-maturation/spec.md
```

And confirm the new artifacts exist:

```bash
ls .orchestrator/milestones/M020/
test -f specs/<NNN>-specify-three-pass-impl/spec.md  # or whatever slug you chose
```

### What to report back

When you're done, produce a short handoff summary (5–8 bullets) naming:

1. Clarify-weave outcome (which Open Questions removed; where the
   answers landed; final Open Questions content).
2. Spec 025 status promotion (`Draft-Authored` →
   `Ready-for-discuss-gate-deferred`).
3. Task B artifact — the spec number + slug you created for the
   three-pass shell implementation follow-up.
4. Task C artifact — `M020-EVALUATION.md` path + tier classification.
5. Task D artifact — `M020-CONTEXT.md` path + how many agent-default
   answers were drafted for operator review.
6. Any deviation from this brief + why (e.g., if evaluate returned
   unexpected tier; if discuss's question-generation surfaced something
   the spec body missed).
7. Anything the operator needs to act on next (e.g., "review +
   finalize M020-CONTEXT.md before running orchestrator:roadmap";
   "re-run pass 3 after conversus PR #28 + #29 merge").

### Out of scope

- Running `orchestrator:roadmap`, `plan-phase`, or any dispatch against
  M020. Discuss must finalize first.
- Re-running pass 3 (conversus gate) against spec 025.
- Implementing the three-pass shell (that's the spec Task B creates).
- Touching conversus upstream.
- Committing or pushing.
- Adding new D-rows (your work is execution against existing decisions,
  not new decisions).
