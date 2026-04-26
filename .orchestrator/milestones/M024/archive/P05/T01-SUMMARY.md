---
schema_version: "1.0"
type: task-summary
id: T01
parent: M024/P05
task: T01
phase: P05
milestone: M024
outcome: success
verification_result: pass
provides:
  - "templates/intake-qa-questions.md (5 Q<N> blocks: Goal/Scope/Surface/Adversarial/Time, MEM013 frontmatter); scripts/verify/m024-p05-qa-questions-template.sh"
requires:
  - "MEM013 template frontmatter conventions; D019 reuse-over-rebuild posture"
affects:
  - "P05/T02 (qa-loop.sh consumes the template)"
key_files:
  - "templates/intake-qa-questions.md,scripts/verify/m024-p05-qa-questions-template.sh"
key_decisions:
  - "Static-template-first cut resolves planning #Q-3; conversus-loop generation deferred unless dogfood demands"
patterns_established:
  - "MEM013 frontmatter on intake templates; AD-19 single-script-file Check shape"
---

# T01 Summary — Static qa-questions template

## What Was Built

Authored the static 5-question Q&A template for M024/P05 — the pinned data source consumed by `scripts/intake/qa-loop.sh` (T02) when an operator invokes `orchestrator:evaluate` with neither `--input` nor `--spec-path`. The template resolves planning open-question #Q-3 with the static-template-first cut per D019 reuse-over-rebuild posture.

The template defines:

- YAML frontmatter with `schema_version: "1.0"` and `type: intake-qa-questions` (MEM013 conventions).
- Five `### Q<N>` heading blocks in pinned order Q1–Q5 (the read-by-number convention T02's loop relies on).
- Each block carries a one-line **Prompt** + one-line **Guidance** hint covering one load-bearing routing axis:
  - Q1 — Goal (input_shape rationale + scope_tier evidence)
  - Q2 — Scope (decomposition axis)
  - Q3 — Visible surface (design_gate signal)
  - Q4 — Adversarial review (conversus_gate signal)
  - Q5 — Time-boxing (intensity axis)
- Inline preface documenting the `enough` short-circuit token + FR-5 cap of 5 turns.
- No `{{placeholder}}` substitutions — the template is static and pinned (T02's loop reads literal heading text).

Also authored the verify script that asserts the template ships with the pinned schema fields, the five `### Q<N>` headings, and the five grep-stable topic words.

## Files Created

- `templates/intake-qa-questions.md` — static 5-question template (M024/P05 #Q-3 resolution).
- `scripts/verify/m024-p05-qa-questions-template.sh` — verify script (executable, single-script-file shape per AD-19).

## Files NOT Touched (out of scope for T01)

The payload's First-Turn Completeness "Files To Touch" enumerates the full phase P05 file set (T02–T05 + suite). Those were intentionally left for their owning tasks. T01 writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh` per SB-3.

## Verification

```
$ bash scripts/verify/m024-p05-qa-questions-template.sh
PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present
```

Exit 0.
