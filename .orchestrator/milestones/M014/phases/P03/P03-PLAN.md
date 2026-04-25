---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M014"
goal: "Comment→workflow classifier (regex/heuristic v1 per D023) + spec-amendment human-gated apply path; consumes M012 wiki + M013 GitHub comment surfaces."
demo_sentence: "A maintainer runs `orchestrator:comments classify` on a seeded inbox; each unactioned Giscus + GitHub Issue/PR comment is fetched, classified into one of {uat-bug, decision-append, spec-amendment, ambiguous}, with uat-bug + decision-append above threshold auto-applied (UAT ingestion / DECISIONS append), spec-amendment queued for human sign-off (never auto-applied per CON-5), and ambiguous comments routed through the M011/P07 conversus adapter; `orchestrator:comments apply <queue-id>` on an approved item edits the target spec atomically."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- AD-19: every Check is a single-script-file invocation. No inline compound bash, subshells, or $(...|pipe). -->

### Truths

- `scripts/comments/fetch.sh` enumerates unactioned comments from Giscus + GitHub Issue/PR surfaces, caches each to `.orchestrator/comments/inbox/<comment-id>.json`, and skips entries whose URL is already in `.orchestrator/comments/actioned.jsonl`. Dry-run path emits FR-19 JSONL action records without disk mutation.
  - Check: `bash scripts/verify/m014-p03-fetch.sh`

- `scripts/comments/classify.sh <inbox-file>` reads one cached inbox comment and emits a single-line `class=<class> confidence=<score>` verdict on stdout for one of the four FR-9 classes (`uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`). Per D023, classifier shape is regex/heuristic v1 — no LLM round-trip on the primary classification path. Ambiguous routes to `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment` per CON-4 (`--strict`).
  - Check: `bash scripts/verify/m014-p03-classify.sh`

- `commands/comments.md` documents the user-facing surface with subcommands `classify`, `status`, `apply`, `reject`, `triage`, `reclassify`; references the regex/heuristic v1 baseline per D023 with explicit retune-trigger language; documents the FR-19 dry-run manifest shape.
  - Check: `bash scripts/verify/m014-p03-commands-md.sh`

- `scripts/comments/apply.sh <queue-id>` applies an operator-approved spec-amendment queue item atomically: edits the target spec at the M011 chunk source line range, runs `scripts/knowledge/rebuild-index.sh`, marks the comment actioned in `actioned.jsonl`. Refuses on stale diffs (US-5 AS-2). Refuses when the target spec has an in-flight conversus deliberation (US-5 AS-4).
  - Check: `bash scripts/verify/m014-p03-apply.sh`

- `scripts/comments/reject.sh <queue-id> --reason <prose>` marks a queue item actioned with `applied: false` and records the rejection reason; `scripts/comments/triage.sh` lists comments routed to the human-triage bucket with their conversus-adapter verdict (when present).
  - Check: `bash scripts/verify/m014-p03-reject-triage.sh`

- Spec-amendment-class comments are NEVER auto-applied regardless of confidence (CON-5/SC-5). Verifier seeds an `actioned.jsonl` fixture covering high-confidence `spec-amendment` rows and asserts every one has `applied: false` until an explicit `apply <queue-id>` invocation lands.
  - Check: `bash scripts/verify/m014-p03-spec-amendment-human-gate.sh`

- `scripts/comments/comments.sh` is the master pipeline: subcommands `classify` (fetch → classify-each → route to {auto-apply | queue | triage}), `status` (read review-queue + print one entry per queued item with approve/reject hint), `reclassify <comment-url>` (re-run classify on a specific URL skipping idempotency check). Above-threshold `uat-bug` auto-applies via M013/FR-10's UAT ingestion path; above-threshold `decision-append` appends a templated block to `.orchestrator/DECISIONS.md`; spec-amendment queues; ambiguous routes through conversus.
  - Check: `bash scripts/verify/m014-p03-pipeline.sh`

- Auto-apply path emits `comment_actioned` JSONL records to `.orchestrator/execution-log.jsonl` with `{comment_url, class, confidence, action_taken, source_surface}` per FR-10/FR-16. `unit_close` records carry `{comments_classified, comments_auto_applied, comments_queued, conversus_invocations, elapsed_ms, source: "runtime"}`.
  - Check: `bash scripts/verify/m014-p03-observability.sh`

- `.orchestrator/config.yml` gains a `comments:` section with `auto_apply_threshold:` (per-class scalars), `reply_on_apply:` (boolean, default false v1), `fetch_schedule:` (string enum: `manual`/`post-verify`/`cron`, default `manual` per OQ #C-2 v1 conservative pin). All keys are additive; existing config is byte-preserved outside the new section.
  - Check: `bash scripts/verify/m014-p03-config-keys.sh`

- `references/spec-management.md` gains a `## Comment Classification & Workflow Routing` section documenting the FR-9 regex/heuristic v1 shape, per-class confidence-score derivation, auto-apply thresholds, the spec-amendment human-gate invariant, and the D023 retune-trigger contract. Existing P04-completed sections (pressure-test, decomposition, dual-write marker convention) are byte-preserved.
  - Check: `bash scripts/verify/m014-p03-references-section.sh`

- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` lands as a best-available capture per D023 — wiki was deployed 2026-04-23, full ≥1-week SC-16 corpus is not yet available; the file documents the snapshot state, names the regex/heuristic v1 baseline as the conservative pin, and enumerates the retune-trigger conditions (≥30 actioned comments OR ≥20% calibration divergence) so future operators have the audit trail.
  - Check: `bash scripts/verify/m014-p03-dogfood-capture.sh`

- Every new shell script passes `scripts/verify/anti-pattern-lint.sh` and runs under Bash 3.2 (CON-6, MEM001). Every new command honors CON-3 zero-prompts in auto mode (`--yes` resolves all interactive prompts to documented defaults).
  - Check: `bash scripts/verify/m014-p03-bash32-and-lint.sh`

- M021 prompt-corpus cross-check: `scripts/comments/{fetch,classify,apply,reject,triage,comments}.sh` paths invoked under `--yes` produce zero approval-prompt-shaped strings on the primary path.
  - Check: `bash scripts/verify/m014-p03-zero-prompts.sh`

- Phase verification suite chains every P03 verifier into a single orchestrator and emits `SUMMARY: m014-p03-phase-suite.sh pass=N fail=0`.
  - Check: `bash scripts/verify/m014-p03-phase-suite.sh`

### Artifacts

- `scripts/comments/fetch.sh` (min 80 lines, contains "actioned.jsonl")
- `scripts/comments/classify.sh` (min 80 lines, contains "regex/heuristic")
- `scripts/comments/apply.sh` (min 60 lines, contains "queue-id")
- `scripts/comments/reject.sh` (min 30 lines, contains "applied: false")
- `scripts/comments/triage.sh` (min 30 lines, contains "triage")
- `scripts/comments/comments.sh` (min 120 lines, contains "comment_actioned")
- `commands/comments.md` (min 60 lines, contains "regex/heuristic")
- `scripts/verify/m014-p03-fetch.sh` (min 50 lines, contains "fetch")
- `scripts/verify/m014-p03-classify.sh` (min 50 lines, contains "class=")
- `scripts/verify/m014-p03-commands-md.sh` (min 25 lines, contains "comments.md")
- `scripts/verify/m014-p03-apply.sh` (min 40 lines, contains "queue-id")
- `scripts/verify/m014-p03-reject-triage.sh` (min 30 lines, contains "applied: false")
- `scripts/verify/m014-p03-spec-amendment-human-gate.sh` (min 30 lines, contains "spec-amendment")
- `scripts/verify/m014-p03-pipeline.sh` (min 50 lines, contains "classify")
- `scripts/verify/m014-p03-observability.sh` (min 30 lines, contains "comment_actioned")
- `scripts/verify/m014-p03-config-keys.sh` (min 25 lines, contains "comments")
- `scripts/verify/m014-p03-references-section.sh` (min 25 lines, contains "spec-management")
- `scripts/verify/m014-p03-dogfood-capture.sh` (min 20 lines, contains "inbox-dogfood")
- `scripts/verify/m014-p03-bash32-and-lint.sh` (min 30 lines, contains "anti-pattern-lint")
- `scripts/verify/m014-p03-zero-prompts.sh` (min 30 lines, contains "m021-prompt-corpus")
- `scripts/verify/m014-p03-phase-suite.sh` (min 40 lines, contains "SUMMARY:")
- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` (min 30 lines, contains "D023")
- `references/spec-management.md` (min 100 lines, contains "Comment Classification")
- `.orchestrator/config.yml` (min 30 lines, contains "comments:")
- `tests/fixtures/m014-p03/sample-inbox.jsonl` (min 4 lines, contains "uat-bug")
- `tests/fixtures/m014-p03/queued-amendment.md` (min 5 lines, contains "comment_url")
- `CLAUDE.md` (min 5 lines, contains "M014/P03")
- `AGENTS.md` (min 5 lines, contains "M014/P03")

### Key Links

- `commands/comments.md` → `scripts/comments/comments.sh`
- `commands/comments.md` → `.orchestrator/DECISIONS.md` (cites D023)
- `scripts/comments/comments.sh` → `scripts/comments/fetch.sh`
- `scripts/comments/comments.sh` → `scripts/comments/classify.sh`
- `scripts/comments/comments.sh` → `scripts/comments/apply.sh`
- `scripts/comments/comments.sh` → `scripts/dispatch/adapters/tool/conversus.sh`
- `scripts/comments/apply.sh` → `scripts/knowledge/rebuild-index.sh`
- `references/spec-management.md` → `scripts/comments/classify.sh`
- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` → `.orchestrator/DECISIONS.md`

## Tasks

### T01: Comment fetcher + idempotency log (FR-8, CON-8)

See `tasks/T01-fetch-PLAN.md`.

### T02: Regex/heuristic v1 classifier + dogfood capture (FR-9, D023)

See `tasks/T02-classify-PLAN.md`.

### T03: Command surface + review queue + apply/reject/triage action surfaces (FR-1, FR-11, US-5, CON-5)

See `tasks/T03-action-surfaces-PLAN.md`.

### T04: Master pipeline + auto-apply for trivial classes + observability (FR-10, FR-16, CON-4)

See `tasks/T04-pipeline-PLAN.md`.

### T05: Phase close — config + references + lint + zero-prompts + phase suite + Recent Changes (FR-17, SC-9, SC-11, CON-3, CON-6)

See `tasks/T05-phase-close-PLAN.md`.

## Task Dependencies

```
T01 → T04
T02 → T04
T03 → T04
T04 → T05
```

T01–T03 are independent of each other (different scripts, no shared state). The orchestrator's auto-loop dispatches them sequentially; T04 wires the master pipeline once T01–T03's primitives ship; T05 closes the phase by adding config keys, references, omnibus lint/zero-prompts/phase-suite gates, and the Recent Changes dual-write.

## Files Likely Touched

- scripts/comments/fetch.sh (create)
- scripts/comments/classify.sh (create)
- scripts/comments/apply.sh (create)
- scripts/comments/reject.sh (create)
- scripts/comments/triage.sh (create)
- scripts/comments/comments.sh (create)
- commands/comments.md (create)
- scripts/verify/m014-p03-fetch.sh (create)
- scripts/verify/m014-p03-classify.sh (create)
- scripts/verify/m014-p03-commands-md.sh (create)
- scripts/verify/m014-p03-apply.sh (create)
- scripts/verify/m014-p03-reject-triage.sh (create)
- scripts/verify/m014-p03-spec-amendment-human-gate.sh (create)
- scripts/verify/m014-p03-pipeline.sh (create)
- scripts/verify/m014-p03-observability.sh (create)
- scripts/verify/m014-p03-config-keys.sh (create)
- scripts/verify/m014-p03-references-section.sh (create)
- scripts/verify/m014-p03-dogfood-capture.sh (create)
- scripts/verify/m014-p03-bash32-and-lint.sh (create)
- scripts/verify/m014-p03-zero-prompts.sh (create)
- scripts/verify/m014-p03-phase-suite.sh (create)
- specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md (create)
- references/spec-management.md (modify — append "Comment Classification" section)
- .orchestrator/config.yml (modify — add comments: section)
- tests/fixtures/m014-p03/sample-inbox.jsonl (create)
- tests/fixtures/m014-p03/queued-amendment.md (create)
- CLAUDE.md (modify — RC region only via dual-write)
- AGENTS.md (modify — RC region only via dual-write)
- .orchestrator/milestones/M014/phases/P03/P03-SUMMARY.md (create at phase close)

## Notes

- **D023 binding**: P03 plans against the regex/heuristic v1 baseline pinned by D023 (2026-04-24). The retune trigger (≥30 actioned comments OR ≥20% calibration divergence) is documented in `commands/comments.md`, in `references/spec-management.md`'s new section, and in the `inbox-dogfood.md` capture. None of these encode an automatic re-pin — they are operator-actioned via a future D-row.
- **Hermetic testing**: every verifier copies its own fixtures into `mktemp -d` scratch dirs, sets `ORCHESTRATOR_PROJECT_ROOT` to the scratch dir for mutation paths (per the M014/P04/T07 pattern), and uses `gh` API stubs (PATH-prefixed shim under scratch) so `gh` is never invoked against the live repo. This mirrors the conversus stub pattern from M026/P02 (`CONVERSUS_STUB=1` + `CONVERSUS_STUB_VERDICT=...`).
- **Scope discipline**: P03 does NOT modify `scripts/dispatch/adapters/tool/conversus.sh` (D007 reuse discipline). The ambiguous-comment triage path consumes the adapter via the existing `gate <preset> <input> <output>` interface; if a `classify-comment` preset is needed, it ships under `templates/conversus-presets/` as a new file (M026/P03/T03 precedent).
