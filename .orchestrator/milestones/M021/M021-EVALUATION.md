---
schema_version: "1.0"
type: evaluation
milestone: "M021"
feature_ref: "021-autonomous-hardening-v2"
feature_spec: "specs/021-autonomous-hardening-v2/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-17T00:00:00Z"
---

# M021 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `speckit.orchestrator.discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 20 |
| Functional requirements | — (expressed as success criteria + user stories; see below) |
| Estimated SDD flows | 4 |

Success criteria as implicit functional requirements: 7 (SC-1 through SC-7).

## Reasoning

Tier C is unambiguous. The spec covers five distinct user stories, each demanding its own SDD cycle:

1. **US-1 (Replay corpus)** — build a fixture + classifier harness to prove zero prompts against the 20-screenshot regression corpus. This is a verification infrastructure flow and must run last so it consumes US-2/3/4/5 artifacts.
2. **US-2 (Linter v2)** — extend `anti-pattern-lint.sh` with five new pattern classes, widen scope to task-PAYLOAD bodies and dispatch-payload builders, preserve M016 suppression semantics, and wire into the verify ladder. This is a pure-script flow.
3. **US-3 (Wrapper catalog)** — ship three wrappers under `scripts/util/`, each with gate scripts and dispatch-payload integration. Separate SDD cycle from US-2 because the wrappers are the remediation targets the linter points at, so US-3 must land before (or at least alongside) US-2 for the diagnostic hints to be meaningful.
4. **US-4 (Pre-Bash hook)** — design a ten-pattern rewrite/reject matrix, implement via pure bash hook wired through `.claude/settings.json`, test against `tests/hook/rewrite-cases.sh` and `tests/hook/reject-cases.sh`. This is the single riskiest flow — it intercepts every Bash tool call and must have zero false-negatives on the 95% allowed path.
5. **US-5 (Permission widening)** — audit the allow-list, add entries for `/var/folders/**` reads, `bash /tmp/*.sh`, project-relative `tmp/**`, and read-only `sed -n`/`head`/`tail`/`stat`. Light-weight but deserves its own flow because changes to `settings.json` ship to every contributor.

Four SDD flows (US-2, US-3, US-4 combined with US-5 since US-5 dovetails into the hook's allow-list, and US-1 as validation) maps cleanly to a four-phase roadmap plus the self-dogfood milestone closeout (pattern established in M016).

Cross-phase coordination is required: the linter (P01) must name wrappers that only exist after P02 ships; the hook (P03) depends on both the wrappers and the linter's rewriter routines; the corpus replay (P04) closes out by validating the integrated system. Autonomous dispatch with per-phase verification gates is the right shape.

Constitution principles this milestone exercises most heavily:

- **VII (Knowledge Compounds)** — this *is* the knowledge-compound loop: M016 recorded AP-004, M011 auto runs exposed AP-004's gaps, M021 catalogs Class B triggers as new AP entries (AP-005 through AP-009 likely) with the linter and hook as their enforcement.
- **XIV (No Speculative Complexity)** — the 10-pattern matrix is grounded in 20 observed screenshots, not hypothesized shapes.
- **XV (Surgical Precision)** — wrapper catalog is intentionally capped at three; pattern matrix at ten; no speculative helpers for shapes that have not yet been observed to prompt.

## Complexity Factors

- **Cross-phase dependency graph**: P02 (wrappers) must land before P01 (linter) can point at remediations, but both must land before P03 (hook) can reference either. P04 depends on all three. Linear roadmap with no parallel phases — consistent with Tier C but on the simpler end of that tier.
- **Two-artifact surface area**: both `scripts/util/` wrappers and `.claude/settings.json` hook config must ship together to be meaningful; neither is individually useful until US-4 lands.
- **Regression-corpus authoring**: the 20-line prompt corpus is derived from visual screenshots of a live auto run. Extracting the verbatim tool-call strings from those screenshots is a manual OCR step that must be done carefully — miss a `$VAR` and the corpus is wrong. This work is enumerated as a P04 T01 task.
- **Claude Code harness opacity**: neither the safety layer's regex set nor the "Unhandled node type: string" parser path is documented publicly. The hook's correctness rests on empirical shape matching derived from observed prompt text. This is inherently brittle — future Claude Code versions may change the heuristics. Mitigation: the replay corpus is a permanent CI gate, so regressions surface immediately.
- **Dogfood validation (SC-7)**: M021 itself runs in auto mode as the closing validation. Same convention M016 established — the milestone closeout report includes the prompt count observed during its own execution.
- **No net-new runtime dependencies**: wrappers and hook are pure bash. No new installer step, no packaging churn — the hook is just another entry in the project `.claude/settings.json` that already ships via `packaging/install/install-claude-code.sh`.
- **Runs before M019 (metrics)**: M021 must close before M019 P01 kickoff so the Tier 1 metrics emitter observes zero-prompt auto runs. This is a schedule constraint, not a technical dependency. D010 (new decision entry) captures the reorder.
