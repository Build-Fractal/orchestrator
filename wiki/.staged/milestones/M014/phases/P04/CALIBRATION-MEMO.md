---
schema_version: "1.0"
type: design-memo
milestone: "M014"
phase: "P04"
task: "T01"
subject: "FR-5 spec-complexity-probe threshold calibration"
created_at: "2026-04-22"
---

# Calibration Memo: FR-5 Spec-Complexity-Probe Thresholds

## Intent

Per the M014 roadmap P04 boundary-map directive, T01 labels a retrospective corpus of shipped specs as above-threshold or below-threshold, then pins the numeric cutoffs in `.orchestrator/config.yml` that T02's full probe body will consume. The values chosen here are **planning-pinned defaults** — not claimed as empirically optimal. CON-9 (Dogfood is the truth signal) covers re-tuning without a milestone amendment.

## Retrospective Corpus

Six specs shipped under the post-[M011](../../../../milestones/M011/index.md) spec-kit regime. Numeric measurements were re-taken at T01 dispatch time using the heuristic patterns specified in the planner (FR count via `grep -cE '^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+'`, user-story count via `grep -cE '^### User (Story|Scenario)'`, tokens via `wc -w`, TODO count via `grep -cE '<TODO'`).

| Spec | FR | US | Tok | TODO | Label | Reason |
|---|---|---|---|---|---|---|
| M011 (011-spec-management) | 16 | 5 | 2392 | 0 | above | `fr_count>=15` |
| [M013](../../../../milestones/M013/index.md) (023-github-native-integration) | 18 | 6 | 7851 | 0 | above | `user_story_count>=5` |
| [M016](../../../../milestones/M016/index.md) (016-autonomous-hardening) | 0 | 3 | 1218 | 0 | below | hardening-spec exception |
| [M021](../../../../milestones/M021/index.md) (021-autonomous-hardening-v2) | 0 | 5 | 2430 | 0 | below | hardening-spec exception |
| M022 (022-spec-wiki) | 10 | 5 | 3613 | 0 | above | `user_story_count>=5` |
| [M024](../../../../milestones/M024/index.md) (024-spec-management-extended) | 20 | 5 | 11083 | 14 | above | `fr_count>=15` |

### Measurement Deltas From Planner Approximations

The planner supplied approximate token counts (e.g., "~3500", "~9000"). Actual measurements at T01 dispatch:

| Spec | Planner approx | Measured | Delta | Label impact |
|---|---|---|---|---|
| M011 | ~3500 | 2392 | -32% | None — above on `fr_count>=15` |
| M013 | ~9000 | 7851 | -13% | None — above on `user_story_count>=5`; note: measured tokens fall just below the 8000 cutoff, so primary reason is `user_story_count>=5`, not `raw_token_count>=8000` |
| M016 | ~3000 | 1218 | -59% | None — below via hardening exception |
| M021 | ~5000 | 2430 | -51% | None — below via hardening exception |
| M022 | ~4500 | 3613 | -20% | None — above on `user_story_count>=5` |
| M024 | ~14000 | 11083 | -21% | None — above on `fr_count>=15` |

Heuristic counts (FR, US, TODO) match the planner's table exactly except for M024, which showed 14 TODO placeholders (planner said 0 — M024 is a live in-flight spec that has accumulated `<TODO>` placeholders via ongoing authoring; the planner was measured at an earlier snapshot). The TODO delta is informational only; no spec flips above/below on the chosen thresholds, so no threshold re-tuning was warranted. Thresholds are pinned as planned.

## Cutoffs

- `fr_count: 15` — above at `>=15`. Rationale: M011/M013/M024 have >=16 FRs and are all acknowledged as deliberation-worthy; M022 has 10 FRs but passed discuss cleanly (below on this axis). 15 leaves headroom under 16 without catching 10.
- `user_story_count: 5` — above at `>=5`. Rationale: 5+ user stories is where we observe story-overlap disputes (M013 US-3/US-4 overlap flagged in D014 deliberation; M022 US-1/US-2 overlap observed at discuss). M016 at 3 stories had zero overlap churn.
- `raw_token_count: 8000` — above at `>=8000`. Rationale: orders of magnitude; M013 at 7851 and M024 at 11083 are the two token-scale outliers. M022 at 3613 stays below; M016 at 1218 is well below. Cutoff placed between M013 and M022. Note: M013 measured just below this cutoff (7851 vs 8000) — it still fires above-threshold because its fr_count and user_story_count both exceed their cutoffs. Token-count axis alone would not flag M013, but the OR-semantics across axes means it is correctly classified.
- `todo_density: 0.5` — above at `>=0.5` (half of sections still hold TODO placeholders). Rationale: this is a skeleton-vs-authored signal. A freshly-scaffolded spec has density close to 1.0; an authored spec has density close to 0.0. 0.5 flags specs where the author ran `orchestrator:specify` and immediately ran `discuss` without filling sections. `todo_density` is computed as `todo_count / (todo_count + section_count)` where `section_count` is the number of `^## ` headings.
- `contradiction_signal_count: 1` — above at `>=1`. Any LLM-detected contradiction signal trips the probe. Rationale: contradictions are binary — one contradiction is enough to warrant pressure-testing. CC-only per CON-2; non-CC runtimes emit zero signals unconditionally. The top-level `contradiction_signal_criterion: cc-llm-or-zero` key documents this CC-runtime-gated source.

## Above/Below Outcomes Per Pinned Thresholds

Applying the pinned thresholds to each corpus row (OR-semantics: above if any axis trips, subject to hardening exception):

- **M011** (16 FR / 5 US / 2392 tok / 0 TODO): fr_count trips (16>=15); user_story_count trips (5>=5). Outcome: **above-threshold**.
- **M013** (18 FR / 6 US / 7851 tok / 0 TODO): fr_count trips (18>=15); user_story_count trips (6>=5); raw_token_count does NOT trip (7851<8000). Outcome: **above-threshold**.
- **M016** (0 FR / 3 US / 1218 tok / 0 TODO): no axis trips. Outcome: **below-threshold** (also covered by hardening exception, redundantly).
- **M021** (0 FR / 5 US / 2430 tok / 0 TODO): user_story_count would trip (5>=5), but `hardening_spec_exception: true` AND `fr_count == 0` overrides to below-threshold. Outcome: **below-threshold**.
- **M022** (10 FR / 5 US / 3613 tok / 0 TODO): user_story_count trips (5>=5). Outcome: **above-threshold**.
- **M024** (20 FR / 5 US / 11083 tok / 14 TODO): fr_count trips (20>=15); user_story_count trips (5>=5); raw_token_count trips (11083>=8000); todo_density is `14/(14+12)` = 0.538 which trips (>=0.5). Outcome: **above-threshold**.

All six labels match the planner's expected labels in `tests/fixtures/m014-p04/corpus-labels.tsv`.

## Hardening-Spec Exception

M016 and M021 are hardening milestones with zero FR-list (behavioral fix milestones, not feature milestones). User-story count alone flags M021 at 5 stories, but M021 was never contentious — the stories are small and well-scoped. We add `hardening_spec_exception: true` with the rule: **if `fr_count == 0`, override above-threshold to below-threshold regardless of user-story count**. This keeps hardening milestones fast-path even as they grow story counts.

The alternative — relax `user_story_count` to `>=6` — was rejected because M011 at 5 user stories *did* need pressure-testing (the US-3/US-5 interaction was nuanced). The hardening-spec exception is more precise: it targets the shape (zero-FR behavioral fix) rather than the size (story count).

### Rationale for the `hardening_spec_exception` Key

1. **Empirical evidence**: M016 and M021 both shipped cleanly without conversus pressure-testing; forcing them above-threshold would have generated false-positive gate prompts and wasted a conversus run on specs with no contradiction surface to find.
2. **Shape signal**: `fr_count == 0` is a strong, specific indicator. Feature-addition specs always declare FRs; behavioral-hardening specs address implicit/already-declared FRs and do not re-declare. The absence of an FR list is itself the signal.
3. **Reversibility**: If a future hardening spec grows enough scope to warrant pressure-testing, the author can manually invoke the pressure-test via the `y` prompt path or add FRs to cross the threshold. The exception is a fast-path default, not a hard block.
4. **Config-surface documentation**: expressing the exception as a top-level boolean key (rather than burying it inside the probe body) makes the behavior discoverable via `grep hardening_spec_exception .orchestrator/config.yml` and adjustable without script edits.

## What We're NOT Claiming

- Threshold values are **planning-pinned defaults**, not empirically-optimal values. CON-9 (Dogfood is the truth signal) covers re-tuning without a milestone amendment.
- The corpus is six specs — too small for statistical confidence. This is a judgment call, documented.
- The LLM contradiction-signal pass is the **only** CC-specific criterion; the other four heuristics are runtime-agnostic. Codex/Cursor users can still get a useful above-threshold verdict from FR/story/token/TODO dimensions alone.

## Re-Tuning Triggers

- If T02 ships and a downstream milestone-author reports "probe fired above-threshold on a spec that was clearly trivial," investigate whether `fr_count` or `user_story_count` should move up.
- If [M019](../../../../milestones/M019/index.md) Tier 2+3 observability ships and we have 10+ more scaffolded specs to analyze, re-run T01-style labeling and consider tightening cutoffs.
- Contradiction-signal LLM false-positive rate should be measured; if it exceeds 20% (LLM flagged contradictions that weren't real), raise the `contradiction_signal_count` threshold to `2`.
- If future hardening specs grow contradictions (counter to the empirical pattern that grounded the exception), re-examine whether `hardening_spec_exception` should gate on an additional signal beyond `fr_count == 0`.

## Cross-References

- `.orchestrator/config.yml` — pinned values under `specify.complexity_thresholds:` + top-level `contradiction_signal_criterion: cc-llm-or-zero` + `hardening_spec_exception: true`
- `tests/fixtures/m014-p04/corpus-labels.tsv` — machine-readable corpus (header + 6 data rows)
- `scripts/knowledge/spec-complexity-probe.sh` (T02 deliverable) — consumer; full body replaces P01 stub and reads these thresholds
- `RUNTIME-ASSUMPTIONS.md` FR-5 — CC-only contradiction-signal pass
- Roadmap M014 P04 boundary map — calibration-corpus directive
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D014 — M013 conversus deliberation precedent (above-threshold firing on high-FR/high-US spec validated the gate intent)
