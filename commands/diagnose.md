---
description: "Use when chasing a hard bug, flake, or performance regression. Runs a disciplined six-phase loop: feedback loop → reproduce → hypothesize → instrument → fix → regression-test. Aligned with Constitution Principle II (Evidence Before Claims)."
---

# orchestrator:diagnose

Structured debugging loop for bugs, flakes, and performance regressions. Borrowed from `mattpocock/skills::diagnose` (MIT) and adapted to the orchestrator's evidence-first discipline. Use this when the bug is non-trivial — i.e., when "read the code and think harder" has already failed once.

This command is a *coaching* command — it tells the agent how to debug, not what to fix. It does not author plans, dispatch tasks, or modify state. The fix itself, when found, is committed via the agent's normal workflow (or via `orchestrator:dispatch` if scoped as a task).

## Constitutional anchor

Principle II (Evidence Before Claims) — every diagnostic step must produce verifiable evidence before the next step depends on it. The six-phase loop is the operationalization of that principle for debugging.

## The six phases

Run them in order. Do not skip phases. If a phase fails, return to the previous phase rather than guessing.

### Phase 1 — Build a feedback loop

The single highest-leverage action. Spend disproportionate effort here. The goal is **a fast, deterministic, agent-runnable pass/fail signal** for the bug. Until this exists, every subsequent phase is guessing.

In order of preference:

1. Failing test at the appropriate seam (`tests/` or per-module test layout)
2. `curl` / HTTP scripts driving a single endpoint
3. CLI invocation with a fixture file under `tests/fixtures/`
4. Headless browser automation
5. Replayed captured trace
6. Throwaway harness script under `scripts/diagnostics/`
7. Property / fuzz test
8. Bisection harness (`git bisect run`)
9. Differential comparison loop (golden output diff, see `scripts/diagnostics/shadow-compare.sh` for the orchestrator's pattern)
10. HITL bash script — last resort; means humans are in the inner loop

For flaky bugs, the goal becomes *higher reproduction rate*, not perfect determinism. Iterate on the loop itself — speed, signal clarity, determinism — before iterating on the bug.

**Stop condition for Phase 1**: the agent can run one command and get `pass` or `fail` in under 30 seconds.

### Phase 2 — Reproduce

Confirm the loop demonstrates the user's actual failure, not an adjacent bug. Capture the exact symptom (error message, wrong output, missed assertion) for use in regression testing.

If reproduction surfaces a *different* bug than the user reported: stop. Tell the user. Decide whether to pivot or stay on the original report.

### Phase 3 — Hypothesize

Generate **3–5 ranked, falsifiable hypotheses** before testing any. Each must include a specific prediction. Share the list with the user as a checkpoint:

```
Hypotheses (ranked by likelihood):
1. <claim> — predicts <observable> if true; <opposite observable> if false
2. ...
```

If the user is not interactive (autonomous run), record the list in a session note and proceed to Phase 4 against the top hypothesis.

### Phase 4 — Instrument

Map each probe to a Phase 3 prediction. **Change one variable at a time.** Prefer debuggers over logs where the runtime supports it; prefer tagged log lines (`[diagnose:<id>]`) over untagged so cleanup is mechanical.

If a probe disconfirms the top hypothesis, *do not* immediately switch to hypothesis 2 — first record what the disconfirmation taught you, then re-rank. Hypothesis stacks decay quickly under new evidence.

### Phase 5 — Fix + regression test

Write the regression test **at the seam where the real bug pattern occurs at the call site** — not at the level convenient for the unit. A regression test that passes against the buggy code is a fixture, not a regression test.

Order: regression test first (fails) → fix → regression test passes. Do not invert.

### Phase 6 — Cleanup + post-mortem

Remove `[diagnose:<id>]` tagged instrumentation (`grep -rn '\[diagnose:' . | xargs ...`). Verify the original user-reported scenario no longer reproduces.

Then write a post-mortem entry. For an orchestrator-internal bug:

```bash
bash scripts/knowledge/promote-to-knowledge.sh \
    --kind lesson \
    --title "<short title>" \
    --evidence "<paths to fix commit + regression test>"
```

For a project-consumer bug, the post-mortem lives in the project's own knowledge layer.

## When to short-circuit

- **Trivial bug, obvious fix**: skip Phase 1, fix it, regression-test. Diagnose is for hard bugs.
- **Phase 1 stuck > 30 minutes**: the bug may be a design problem, not a defect. Consider `orchestrator:zoom-out` to see if the right fix is at a higher layer.
- **Hypotheses keep all disconfirming**: the mental model of the system is wrong. Stop guessing; read the code.

## Output

This command produces no file artifacts of its own. The artifacts it *causes* to exist are: the feedback-loop script (Phase 1), the regression test (Phase 5), and the post-mortem knowledge entry (Phase 6).

## Idempotency

The command itself is stateless — invoking `orchestrator:diagnose` re-enters Phase 1 every time. The artifacts it produces are committed through the normal git workflow.

## Composition

- Pairs with `orchestrator:zoom-out` when Phase 1 is hard because the right seam isn't obvious.
- Pairs with `orchestrator:doctor` — if `doctor` flags a stale or orphaned artifact, `diagnose` is the loop for chasing the cause.
- Auto-loop (`orchestrator:auto`) does not invoke `diagnose` automatically; verifier-fail escalation goes through M030's adaptive-model path. `diagnose` is operator-driven.

## Reference files

- `references/verification-ladder.md` — the verifier tiers; Phase 1 feedback loops should land at the lowest tier that catches the bug.
- `scripts/diagnostics/shadow-compare.sh` — example of a Phase 1 differential-comparison loop (M030).
- `scripts/knowledge/promote-to-knowledge.sh` — Phase 6 post-mortem promotion.
