---
description: Comment to workflow classifier with human-gated spec-amendment apply.
---

# orchestrator:comments

Comment-to-workflow classifier and human-gated spec-amendment apply path.
Consumes M012 wiki Giscus + M013 GitHub Issue/PR comments per FR-8/FR-9
(M014 spec). Spec-amendment-class comments are NEVER auto-applied
(CON-5 / SC-5 — Constitution III + XIV); the `apply <queue-id>` subcommand
is the single path for spec mutation from comments.

## Subcommands

### classify

`orchestrator:comments classify [--dry-run] [--yes]`

Fetches unactioned comments from Giscus + GitHub surfaces, classifies each
into one of `{uat-bug, decision-append, spec-amendment, ambiguous}` per the
regex/heuristic v1 baseline (D023 pin), routes:

- **uat-bug** above threshold → auto-apply via M013/FR-10 UAT ingestion path.
- **decision-append** above threshold → append templated block to `.orchestrator/DECISIONS.md`.
- **spec-amendment** any confidence → queue for human sign-off at `.orchestrator/comments/review-queue/<queue-id>.md`. (Never auto-applied — CON-5/SC-5.)
- **ambiguous** → invoke `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment` (M011/P07 adapter, `--strict`); on low-confidence verdict, route to human triage bucket.

`--dry-run` prints FR-19 JSONL action records to stdout without disk mutation.
`--yes` resolves all interactive prompts to documented defaults (CON-3 zero-prompt baseline).

### status

`orchestrator:comments status`

Lists every queued review-queue item with `queue_id`, `class`, `confidence`,
`comment_url`, and the approve/reject hint. Read-only.

### apply

`orchestrator:comments apply <queue-id>`

Applies an operator-approved spec-amendment queue item atomically:
reads the queued diff, verifies it still applies (rejects on stale diff
per US-5 AS-2), edits the target spec, runs `scripts/knowledge/rebuild-index.sh`,
commits the change with a message citing the queue-id and source comment URL,
and marks the comment actioned with `applied: true`.

Refuses when an in-flight conversus deliberation exists at the target spec's
`conversus/` directory (US-5 AS-4 — no interleaving authorship + amendment).

This is the ONLY path for spec mutation from a comment-class verdict of
`spec-amendment`. The classifier never auto-applies — every spec-amendment
queues for human sign-off regardless of confidence (CON-5 / SC-5 invariant —
mechanically asserted by `scripts/verify/m014-p03-spec-amendment-human-gate.sh`).

### reject

`orchestrator:comments reject <queue-id> --reason "<prose>"`

Marks a queue item actioned with `applied: false`, records the rejection reason,
and (if `comments.reply_on_apply: true` in config) replies to the source comment
thread with the rejection reason.

### triage

`orchestrator:comments triage`

Lists comments routed to the human-triage bucket (ambiguous comments whose
conversus verdict was low-confidence per spec AS-5/AS-8). Each entry shows
source URL, conversus verdict, and remediation hint.

**Corpus-exhaustion gate (M042).** When triage would draft a clarifying
question back to the operator/SME (rather than route the comment to a workflow
action), pass that question through `orchestrator:corpus-gate` first — the
project's own corpus often already answers it. See `commands/corpus-gate.md`
(`gate --checkpoint comments …`). The gate respects `corpus_exhaustion.enabled`.

### reclassify

`orchestrator:comments reclassify <comment-url>`

Re-runs classification on a specific URL skipping the `actioned.jsonl`
idempotency check. Useful when the regex/heuristic ruleset has been retuned
(per the D023 retune trigger) and historical comments need reprocessing.

## D023 retune trigger

The regex/heuristic v1 baseline is provisional. When EITHER of these conditions
holds, open a follow-up D-row that re-pins FR-9 shape:

1. `actioned.jsonl` shows >= 30 fetched comments across the four classes.
2. Classifier confidence calibration on observed comments diverges from
   regex/heuristic predictions in >= 20% of samples.

See `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md`
(SSOT for retune-trigger conditions, per T02 handoff) and
`.orchestrator/DECISIONS.md` D023 for the full retune contract.

## FR-19 dry-run manifest

Every M014 command's `--dry-run` emits JSONL action records to stdout:

```
{"command":"comments classify","action_type":"<action>","target_path":"<path>","source_ref":"<url>","description":"<text>"}
```

`action_type` values include `cache-comment`, `classify-comment`, `auto-apply-uat-bug`,
`auto-apply-decision-append`, `queue-spec-amendment`, `route-ambiguous-to-conversus`,
`apply-amendment`, `reject-queue-item`.

## Reference files

- `scripts/comments/comments.sh` — master pipeline implementation (M014/P03/T04).
- `scripts/comments/fetch.sh` — FR-8 comment fetcher (M014/P03/T01).
- `scripts/comments/classify.sh` — FR-9 regex/heuristic classifier (M014/P03/T02).
- `scripts/comments/apply.sh` — human-gated spec-amendment apply (M014/P03/T03).
- `scripts/comments/reject.sh` — queue rejection recorder (M014/P03/T03).
- `scripts/comments/triage.sh` — human-triage bucket lister (M014/P03/T03).
- `references/spec-management.md#comment-classification--workflow-routing` — full algorithmic reference.
- `.orchestrator/DECISIONS.md` D023 — regex/heuristic v1 pin + retune trigger.
