# M018/P04 — section-overflow fixture

## Purpose

Hermetic fixture exercising the **happy-path** of Tier 2 head-drop:

- The `## Knowledge` section body exceeds the configured
  `compression.tier2.section_budget_tokens` budget (200 tokens at
  the helper's default — see `scripts/verify/_helpers/m018-p04-build-fixture.sh`).
- The body contains zero multi-line preserved spans (no frontmatter
  delimiter pairs, no 4+-backtick code fences, no JSONL records, no
  cross-tier in-band markers).
- Every body line carries the body_unsafe[i]=0 flag — the
  boundary-refusal walker therefore retreats only as far as the line
  boundary nearest the naive cut byte, never as a result of preserved
  spans.

## Verifiers that exercise this fixture

- `scripts/verify/m018-p04-tier2-head-drop.sh` — asserts head-drop
  fires; protected tail bytes byte-identical at end of section.
- `scripts/verify/m018-p04-tier2-marker.sh` — asserts the in-band
  `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=0.30 -->`
  marker appears immediately after the `## Knowledge` heading.
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` — asserts the
  live `payload_breakdown` JSONL record carries an integer
  `tier2_savings_tokens` field > 0 alongside the prior tier1 fields.
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` — uses
  this fixture as input to the function-stub failure-path test.

## Shape

```
title (line 1)
Manifest table
## Knowledge          <- in-scope section, ~400 tokens of plain prose
## Decisions          <- out-of-scope (passes through verbatim)
## Task Plan          <- in-scope but small enough to pass through
```

The `## Task Plan` body is small; only `## Knowledge` triggers head-drop
under the default budget.
