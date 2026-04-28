# M018/P04 — boundary-refusal fixture

## Purpose

Hermetic fixture exercising the **boundary-refusal walker** of Tier 2
head-drop, specifically the MIT-01 4+-backtick nested-fence case:

- The `## Upstream Context` section body exceeds the configured
  `compression.tier2.section_budget_tokens` budget (200 tokens at
  the helper's default).
- The body contains a 4-backtick code fence whose opener sits in the
  head-drop range and whose closer lives in the protected tail.
- Inside the 4-backtick fence is a 3-backtick "nested" fence — under a
  3-backtick-only regex this would falsely close the outer fence; under
  the MIT-01-aware tick-count regex (`^\`{3,}[a-zA-Z0-9_-]*$` with
  matching-count fence pairing) the inner 3-backtick lines are pure
  content of the outer 4-backtick fence and do NOT close it.

## Expected behavior under default `protected_tail_ratio: 0.3`

Naive head-drop boundary lands inside the 4-backtick fence. The
boundary-refusal walker retreats DOWN line-by-line toward line 1 until
it finds a body_unsafe[i] == 0 line (a line not inside any open
multi-line preserved span). The first safe line is the line that OPENS
the fence (the opener line itself is safe — the cut may land at the
opener; cuts BELOW the opener fall inside the span and are unsafe).

Result:
- Either head-drop fires with a smaller `head_dropped` than the naive
  cut would produce (the walker retreated above the fence opener), OR
- The section passes through unmodified plus a
  `tier_preservation_violation` JSONL record (record_type=
  `tier_preservation_violation`, tier=`tier2`, pattern=`code-fence`)
  is appended to the fixture's execution-log.jsonl.

## Verifiers that exercise this fixture

- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` — asserts either
  the retreat path OR the passthrough+violation path; asserts the
  fence opener and closer are both present unaltered in the output.

## Shape

```
title (line 1)
Manifest table
## Knowledge           <- empty stub
## Decisions           <- out-of-scope, verbatim passthrough
## Upstream Context    <- in-scope, ~400 tokens, contains 4-backtick fence
                          (MIT-01 case: nested 3-backtick lines inside)
## Task Plan           <- short, passthrough
```
