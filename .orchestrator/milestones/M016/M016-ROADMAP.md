---
schema_version: "1.0"
type: roadmap
milestone: "M016"
feature_ref: "016-autonomous-hardening"
feature_spec: "specs/016-autonomous-hardening/spec.md"
vision: "orchestrator:auto runs end-to-end with zero Claude Code approval prompts under project-default settings"
tier: "C"
created_at: "2026-04-16T01:52:30Z"
updated_at: "2026-04-16T01:52:30Z"
---

## Phases

- [x] **P01**: Timestamp & Command-Substitution Elimination — "A dispatched subagent writes a task summary via `write-summary.sh` with no `$(…)` in the Bash call — `--completed_at` is omitted and the script defaults to now."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/write-summary.sh` (updated: `--completed_at` optional, `now` sentinel, internal `date -u` computation)
      - `scripts/lifecycle/mark-complete.sh` (updated: no longer requires caller-supplied timestamp if it delegates to `write-summary.sh`)
      - `ANTIPATTERNS.md` (created or updated: Class A pattern catalog with prohibited patterns and wrapper alternatives)
    - Consumes: nothing (foundation phase)

- [x] **P02**: Verify-Suite Wrapper — "A developer runs `bash scripts/verify/run-suite.sh m016 P01` and sees per-script PASS/FAIL status plus aggregate counts — no chained `&&` or inline `awk` needed."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/verify/run-suite.sh` (new: auto-discovers `scripts/verify/<m>-<p>-*.sh`, executes each, prints per-script status + `PASS: N / FAIL: M` summary, exits 0 on all-pass / non-zero on any-fail)
    - Consumes: nothing (independent of P01; uses existing verify script naming convention)

- [x] **P03**: Anti-Pattern Guardrails & Template Updates — "The dispatch payload includes a 'Prohibited inline bash patterns' section, plan templates reference `run-suite.sh` instead of chained commands, and `anti-pattern-lint.sh` exits non-zero on a test fixture containing `$(date …)`."
  - Risk: high
  - Depends: P01, P02
  - Boundary Map:
    - Produces:
      - `scripts/verify/anti-pattern-lint.sh` (new: scans `commands/*.md`, `templates/*.md` for `$(…)`, backticks, `{a,b}` brace expansion; exits non-zero with file:line diagnostics and remediation hints; self-excludes its own regex source)
      - `commands/auto.md` (updated: prohibited-patterns section revised, example invocations cleaned of Class A patterns)
      - `commands/consolidate.md` (updated: `state=$(bash …)` example replaced with wrapper or variable-assignment pattern)
      - `commands/plan-phase.md` (updated: subshell/command-substitution examples replaced)
      - `templates/task-plan.md` (updated: chained verify example replaced with `run-suite.sh`; `$(…)` examples removed)
      - `templates/claude-code-appendix.md` (updated: `output=$(bash …)` example replaced)
      - `scripts/dispatch/build-context.sh` (updated: payload template includes prohibited-patterns section referencing ANTIPATTERNS.md)
    - Consumes:
      - `ANTIPATTERNS.md` from P01 (Class A pattern catalog — linter rules align with catalog)
      - `scripts/verify/run-suite.sh` from P02 (wrapper referenced in updated templates)
      - `scripts/knowledge/write-summary.sh` from P01 (new API documented in examples)

- [x] **P04**: Allow-List Promotion & Dogfood Validation — "A fresh `orchestrator:auto` run on a prior completed phase (M015 P02 or similar) using only project-default `settings.json` produces zero approval prompts."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces:
      - `.claude/settings.json` (updated: safe tool wildcards promoted from `settings.local.json` — `sed *`, `awk *`, `/usr/bin/sed *`; stale one-off entries in local removed)
      - `.orchestrator/milestones/M016/phases/P04/evidence/` (dogfood evidence: prompt count = 0, subagent transcript excerpts)
      - `scripts/verify/m016-p04-zero-prompts.sh` (gate script for SC-1 validation)
    - Consumes:
      - `scripts/verify/anti-pattern-lint.sh` from P03 (run as pre-validation before dogfood)
      - `scripts/verify/run-suite.sh` from P02 (used during dogfood run itself)
      - All P01–P03 deliverables (the dogfood run exercises the full updated surface)

## Cross-Cutting Concerns

- **Bash 3.2 compatibility** — P01, P02, P03. All new scripts must pass `bash -n` under Bash 3.2. No `declare -A`, `mapfile`, `${var,,}`. P01 establishes the pattern (write-summary.sh already Bash 3.2); P02 and P03 must conform.
- **Anti-pattern consistency** — P01, P03, P04. The ANTIPATTERNS.md catalog (P01) is the single source of truth for what constitutes a Class A pattern. The linter (P03) must enforce exactly those patterns. The dogfood run (P04) validates the linter catches everything. If the catalog, linter, and dogfood disagree, the dogfood result wins and the others are updated.
- **Self-referential safety** — P03. The linter scans `commands/*.md` and `templates/*.md`, which may contain examples of prohibited patterns for documentation. Use a `<!-- lint-ignore -->` marker or exclude the linter's own test fixtures. The ANTIPATTERNS.md file itself is excluded from scans (it catalogs patterns by definition).

## Dependency Graph

```
P01 ──→ P03 ──→ P04
         ↑
P02 ────┘
```

P01 and P02 have no dependencies and can execute concurrently.
P03 depends on both P01 and P02 (consumes their deliverables).
P04 depends on P03 (dogfood validates the complete surface).

## Execution Order

1. **P01, P02** — can execute concurrently. P01 is the highest-impact change (eliminates the #1 prompt source); P02 is independent (new wrapper script). Both unblock P03.
2. **P03** — depends on P01 + P02. Largest phase: updates 6+ agent-facing files, creates linter, updates dispatch payload template. High risk due to broad surface area.
3. **P04** — depends on P03. Validation-only: promotes allow-list entries, runs dogfood, captures evidence. Lower risk — if prompts still appear, the fix is iterating P01–P03, not P04.

## Validation

- **No conflicting producers**: PASS — each artifact is produced by exactly one phase. `ANTIPATTERNS.md` is produced by P01; `settings.json` is produced by P04; no overlap.
- **All consumed items have producers**: PASS — P03 consumes `ANTIPATTERNS.md` (P01), `run-suite.sh` (P02), `write-summary.sh` (P01). P04 consumes `anti-pattern-lint.sh` (P03), `run-suite.sh` (P02). All traced.
- **DAG is acyclic**: PASS — P01→P03→P04 and P02→P03→P04. No back-edges.
- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo sentence describing a specific developer action and its expected result.
