---
schema_version: "1.0"
type: roadmap
milestone: "M021"
feature_ref: "021-autonomous-hardening-v2"
feature_spec: "specs/021-autonomous-hardening-v2/spec.md"
vision: "Close every residual Claude Code safety-prompt trigger that survived M016 so orchestrator:auto runs ≥4-task phases to completion with zero user approvals under project-default settings."
tier: "C"
created_at: "2026-04-17T00:00:00Z"
updated_at: "2026-04-17T00:00:00Z"
---

## Phases

- [x] **P01**: Wrapper Catalog — "A developer invokes `scripts/util/with-env.sh VAR=val -- bash /tmp/x.sh`, `scripts/util/read-range.sh file.md 10 20`, and `scripts/util/run-probe.sh /tmp/probe.sh`; each wrapper executes successfully and its gate script passes."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`, `scripts/verify/m021-p01-with-env.sh`, `scripts/verify/m021-p01-read-range.sh`, `scripts/verify/m021-p01-run-probe.sh`, `scripts/util/README.md` (catalog index with one-line usage examples)
    - Consumes: none

- [x] **P02**: Linter v2 — Shape Detectors + Scope Widening — "A developer seeds a task-PAYLOAD.md bash fence with `echo \"RC=$?\"`; running `scripts/verify/anti-pattern-lint.sh` exits non-zero, names the file+line, identifies the pattern class (simple-expansion), and points at `scripts/util/with-env.sh`."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: Updated `scripts/verify/anti-pattern-lint.sh` (five new detectors: simple-expansion, redirect-cmd-sub, quoted-brace, heredoc-expansion, task-plan-compound), `ANTIPATTERNS.md` entries AP-005 through AP-009 (each citing specific M011 screenshots), `scripts/verify/m021-p02-linter-v2.sh` (gate that asserts both M016 Class A and M021 Class B coverage + task-PAYLOAD scope), `scripts/verify/m021-p02-linter-scope.sh` (gate that asserts specs/references/docs excluded unless `<!-- agent-facing -->` marker present), convention documented in `references/engine.md` or comparable
    - Consumes: `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` from P01 (remediation hint text names these paths)

- [x] **P03**: Pre-Bash Hook + Permission Widening — "A developer invokes Claude Code with a Bash call containing `sed -n '10,20p' file`; the pre-Bash hook rewrites it to `bash scripts/util/read-range.sh file 10 20` via `hookSpecificOutput.updatedInput.command` and no prompt fires. A Bash call containing nested `$(...)` is hard-rejected with `REJECT: nested-cmd-sub — use scripts/util/run-probe.sh. See ANTIPATTERNS.md#AP-008.` on stderr."
  - Risk: high
  - Depends: P01, P02
  - Boundary Map:
    - Produces: `scripts/hooks/pre-bash-shape-guard.sh` (10-pattern rewrite/reject matrix), `scripts/verify/lib/shape-classifier.sh` (shared shape-detection library used by hook and replay corpus), updated `.claude/settings.json` (PreToolUse hook registration + widened allow-list entries: `Read(/var/folders/**)`, `Bash(bash /tmp/*.sh)`, `Bash(bash /var/folders/**/*.sh)`, `Bash(ls tmp/**)`, `Bash(cat tmp/**)`, `Bash(sed -n *)`, `Bash(head *)`, `Bash(tail *)`, `Bash(stat *)`), `tests/hook/rewrite-cases.sh` (6 cases), `tests/hook/reject-cases.sh` (4 cases), `scripts/verify/m021-p03-hook-integration.sh` (gate), dispatch-payload "Allowed invocation shapes" section via `scripts/dispatch/lib/section-handlers.sh` update
    - Consumes: `scripts/util/*.sh` from P01 (hook rewrite targets), `ANTIPATTERNS.md` AP-005..AP-009 from P02 (reject-diagnostic citation text)

- [x] **P04**: Replay Corpus + Dogfood Attestation — "`bash scripts/verify/replay-prompt-corpus.sh` processes all 20 entries in `tests/fixtures/m021-prompt-corpus.txt` and exits 0 with `WOULD_PROMPT=0/20`. The milestone's own auto-run attestation file `.orchestrator/milestones/M021/auto-loop-result.txt` records zero user prompts observed across M021's P01–P04 execution."
  - Risk: medium
  - Depends: P01, P02, P03
  - Boundary Map:
    - Produces: `tests/fixtures/m021-prompt-corpus.txt` (20 verbatim tool-call strings from M011/P05–P07 screenshots, each entry with `INPUT:` and `EXPECTED_OUTCOME:` fields where outcome is `allow`, `rewrite:<result>`, or `reject:<pattern-class>`), `scripts/verify/replay-prompt-corpus.sh` (gate invoking shape-classifier + hook, asserts 0 would-prompt cases), `scripts/verify/m021-p04-dogfood-attestation.sh` (gate asserting M021's own auto-execution observed zero prompts), `M021-SUMMARY.md` with SC-1..SC-7 result table, `.orchestrator/DECISIONS.md` entry D010 documenting the M021-before-M019 reorder, `ANTIPATTERNS.md` cross-references updated
    - Consumes: `scripts/util/*.sh` from P01, `ANTIPATTERNS.md` AP-005..AP-009 from P02, `scripts/hooks/pre-bash-shape-guard.sh` + `scripts/verify/lib/shape-classifier.sh` + `.claude/settings.json` from P03

## Cross-Cutting Concerns

- **Bash 3.2 compatibility** — P01, P02, P03, P04. P01 establishes the wrapper-script pattern under constitution IX. P03 must carry it into the hook (no bash-4 features). Every new `.sh` file gets a line in `scripts/verify/m021-<phase>-bash32-compat.sh` (or equivalent per-phase gate) as part of that phase's verification.

- **ANTIPATTERNS.md citations** — P02 establishes AP-005 through AP-009 with specific M011 screenshot evidence; P03 reject diagnostics reference those AP-IDs by name; P04 dogfood attestation summarizes coverage. The append-only discipline from M016 holds — these entries do not decay or expire (constitution AD-11).

- **Shape-classifier single source of truth** — P03 creates `scripts/verify/lib/shape-classifier.sh`; P04 replay consumes it; P02 linter uses its own file-oriented regex detectors (different domain: file text vs tool-call strings) and does NOT consume the classifier. If a future milestone needs to unify them, that is a separate refactor.

- **Evidence grounding (constitution II)** — All four phases cite M011/P05–P07 screenshots. The 20-screenshot corpus is the authoritative evidence base; no pattern enters the hook matrix, linter detector set, or wrapper catalog without a matching screenshot. This is enforced at review time by boundary-map validation — each phase's verification references specific screenshot timestamps.

- **Dogfood culture continuation** — M016 established the "milestone validates itself via its own auto-execution" pattern. P04 continues it for M021. Future hardening milestones (should any be needed) should continue the convention.

- **Agent-facing marker convention** — P02 establishes `<!-- agent-facing -->` as an HTML-comment marker that opts a markdown file into linter scanning. P03 and P04 adopt the convention. Files under `commands/`, `templates/`, `scripts/dispatch/lib/`, and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` are scanned by default (no marker needed); `specs/`, `references/`, and `docs/` require the marker to opt in.

- **M019 reorder rationale** — All phases. P04 captures decision D010 in `.orchestrator/DECISIONS.md`. Milestone-summary and CLAUDE.md "Forward Roadmap" narrative text updates are out of scope for M021 phase work; they get addressed in a separate doc pass after M021 closes (either standalone or folded into M019 kickoff).

## Dependency Graph

```
P01 ──► P02 ──► P03 ──► P04
```

Serial by construction (AD-7). No phases can execute concurrently. Rationale recorded in AD-7 of `M021-CONTEXT.md`:

- P02 depends on P01 because linter remediation hints name specific wrapper paths.
- P03 depends on both P01 (rewrite targets) and P02 (diagnostic text references AP-005..AP-009 which P02 creates).
- P04 depends on all three (validation layer over the integrated system).

Tighter parallelization was considered (P02 ∥ P03 after P01 completes, since the hook's matrix could reference AP-IDs that P02 creates in a late commit) but rejected to reduce merge risk and preserve linear reasoning about AP-ID authorship.

## Execution Order

1. **P01** — Wrapper Catalog. No dependencies. Low risk. Ships three wrappers + three gate scripts + catalog README.
2. **P02** — Linter v2 + Scope Widening. Depends on P01. Medium risk (regex false-positive rate on task-PAYLOAD bash fences is a new surface). Ships five new detectors, AP-005..AP-009 entries, two gate scripts, agent-facing marker convention.
3. **P03** — Pre-Bash Hook + Permission Widening. Depends on P01 and P02. **High risk (executes first among remaining phases at dependency-satisfied gate per FR-043 — and is naturally also next in serial order).** Ships the PreToolUse hook script, shared shape-classifier lib, updated `.claude/settings.json`, ten test cases (6 rewrite + 4 reject), and dispatch-payload integration.
4. **P04** — Replay Corpus + Dogfood Attestation. Depends on P01, P02, P03. Medium risk. Ships the 20-line fixture, replay gate, dogfood gate, milestone summary, and D010 entry.

No parallel execution. Each phase awaits full completion (summary + verification pass) of the prior phase before dispatch begins.

## Validation

- **No conflicting producers**: PASS. Each file path in a `Produces` list appears in exactly one phase. Cross-phase updates to shared files are scoped: `ANTIPATTERNS.md` is produced (new AP entries) by P02 only, then read (not modified) by P03 and P04. `.claude/settings.json` is modified only by P03. `scripts/verify/anti-pattern-lint.sh` is modified only by P02. No two phases write to the same file.

- **All consumed items have producers**: PASS.
  - P02 consumes P01's wrappers ✓
  - P03 consumes P01's wrappers + P02's AP-005..AP-009 ✓
  - P04 consumes P01's wrappers + P02's AP entries + P03's hook, classifier lib, and settings.json ✓
  - No unresolved dependencies.

- **DAG is acyclic**: PASS. Linear chain P01 → P02 → P03 → P04. No back-edges.

- **Demo sentence coverage**: PASS. Each phase has a concrete, observable demo:
  - P01: wrapper invocations + gate execution (directly runnable).
  - P02: linter fires on a seeded bad file with specific error text (directly runnable).
  - P03: specific rewrite behavior + specific reject diagnostic text (observable via Bash tool call + hook output).
  - P04: specific corpus file processed + specific auto-loop artifact recording zero prompts (observable via gate scripts).

- **Evidence traceability (constitution II bonus check)**: PASS. Every phase boundary map references M011/P05–P07 screenshot-derived artifacts. P01 wrappers absorb the six recurring probe shapes from screenshots. P02 detectors target the five residual file-level patterns. P03 matrix covers all ten observed tool-call shapes. P04 corpus is the 20 screenshots themselves.
