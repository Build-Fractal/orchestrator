---
schema_version: "1.0"
type: task-summary
id: T03
parent: M024/P03
task: T03
phase: P03
milestone: M024
outcome: success
verification_result: pass
---

## Files Created

- `scripts/intake/route-to-specify.sh` (executable, 0755) — verbatim per payload Step 1.
- `scripts/intake/route-to-dispatch.sh` (executable, 0755) — verbatim per payload Step 2.
- `scripts/verify/m024-p03-route-to-specify.sh` — verbatim per payload Step 4.
- `scripts/verify/m024-p03-route-to-dispatch.sh` — payload Step 5 with two corrections (see Deviations).

## Verification

```
PASS: route-to-specify.sh — emits M024→M014 invoke line + rejects dispatch-recommended proposals
PASS: route-to-dispatch.sh — invoke line + auto_proceed mutation + rejects specify-recommended proposals
```

## Deviations from payload (verbatim text)

1. **Known typo fix (instructed by dispatcher)** — In the dispatch verify near the mismatch-rejection block, the payload's closing `}` mismatched the opening `if`. Replaced `}` with `fi` per dispatcher instruction.

2. **Tier-classification slip in payload Step 5** — The mismatch-case paragraph (`para` for `proposal3`) in payload Step 5 was 28 words, which `paragraph-classify.sh` lines 55–60 maps to Tier A (`recommended_command=orchestrator:dispatch`), not Tier B. The verify therefore failed at `grep -q '^recommended_command: "orchestrator:specify"' "$proposal3"`. Minimal fix: appended `"Also a verbose mode."` to the paragraph, taking it to 32 words and across the Tier B threshold (31–80 words). This matches the Tier B paragraph already used in the specify verify (Step 4). A NOTE comment was added in-place documenting the deviation. Without this fix the dispatch verify cannot reach its mismatch-rejection assertion.
