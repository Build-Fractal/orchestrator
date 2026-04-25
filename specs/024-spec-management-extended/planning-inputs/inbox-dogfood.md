# Inbox Dogfood Data Capture (M014/P03 SC-16, RELAXED per D023)

## Status: best-available signal at plan time (2026-04-24)

The original SC-16 contract called for ≥1 week of M012/M013 inbox volume
captured before plan-phase pins the FR-9 classifier shape. **D023
(2026-04-24) relaxed this preflight** — the wiki was deployed 2026-04-23
(one day before plan-phase); waiting six more calendar days delays M014
close past usable cadence.

This file documents the snapshot state, the regex/heuristic v1 baseline
pin chosen by D023, and the explicit retune-trigger conditions that move
the classifier off this baseline.

## Snapshot

| Surface       | Threads observed | Comments observed | Notes |
|---------------|------------------|-------------------|-------|
| Wiki Giscus   | 0                | 0                 | Wiki deployed 2026-04-23; no organic stakeholder comments yet. |
| GitHub Issues | 0                | 0                 | Existing M013/M014 dogfood Issues; mostly orchestrator-id-marker self-comments — none classified by humans. |
| GitHub PRs    | 0                | 0                 | None of the M026 PRs received external review comments. |

## Per-class counts (seeded fixture)

The `tests/fixtures/m014-p03/sample-inbox.jsonl` fixture seeds 4 synthetic
comments — 1 per class — exercising the regex/heuristic v1 ruleset. Real-
inbox calibration accumulates as comments are actioned (see `actioned.jsonl`).

| Class            | Seeded fixture count | Real-inbox count (snapshot) |
|------------------|----------------------|-----------------------------|
| uat-bug          | 1                    | 0                           |
| decision-append  | 1                    | 0                           |
| spec-amendment   | 1                    | 0                           |
| ambiguous        | 1                    | 0                           |

## FR-9 shape pinned: regex/heuristic v1 (D023)

Rule set captured in `scripts/comments/classify.sh:R1-R10`. Confidence
assignments are coarse-grained (0.7–0.95 in 0.05–0.10 increments), pinned
on intuition + the four-class precedent from prior milestones, NOT on
measured precision/recall.

Rule summary:

| Rule | Class           | Confidence | Match shape |
|------|-----------------|------------|-------------|
| R1   | uat-bug         | 0.9        | YAML frontmatter `kind: uat-bug` (M013 template) |
| R2   | uat-bug         | 0.7        | "acceptance (criterion\|scenario\|criteria) ... fail" |
| R3   | uat-bug         | 0.7        | "(bug\|broken\|failing\|crashes\|errors out) ... on" |
| R4   | decision-append | 0.95       | `^/append-decision` (explicit trigger) |
| R5   | decision-append | 0.85       | `^decision: ` (prefix) |
| R6   | decision-append | 0.75       | "we (decided\|agreed\|chose)" (narrative) |
| R7   | spec-amendment  | 0.85       | "FR-N (should\|needs to\|must\|also cover)" |
| R8   | spec-amendment  | 0.85       | "(AS\|US\|SC\|CON)-N (is wrong\|contradicts\|missing)" |
| R9   | spec-amendment  | 0.95       | `^(amend\|propose amendment)` |
| R10  | ambiguous       | 0.0        | fallthrough — route to conversus (CON-4) |

## Retune trigger (D023)

When **EITHER** condition holds, open a follow-up D-row that re-pins FR-9 shape:

1. **Volume trigger**: `.orchestrator/comments/actioned.jsonl` shows ≥30
   fetched comments across the four classes.
2. **Calibration trigger**: classifier confidence calibration on observed
   comments diverges from regex/heuristic predictions in ≥20% of samples
   (sample = comment whose conversus-triage verdict OR human-triage
   outcome disagrees with the regex/heuristic verdict).

Either trigger justifies escalating FR-9 to one of the alternative shapes
from spec OQ #C-1 (embedding-distance, LLM-call-per-comment, two-pass
hybrid). The escalation lands inside M014 extended scope OR as a dedicated
M011/M014 follow-up (operator decides at trigger time).

## Cross-references

- `.orchestrator/DECISIONS.md` D023 — original relaxation rationale.
- `commands/comments.md` — user-facing surface citing this file (T03).
- `references/spec-management.md` — "Comment Classification & Workflow Routing"
  section (added by M014/P03/T05).
- `scripts/comments/classify.sh` — regex/heuristic v1 implementation (R1–R10).
- `templates/conversus-presets/classify-comment.yml` — ambiguous-routing
  preset for the conversus adapter (D007 reuse).
