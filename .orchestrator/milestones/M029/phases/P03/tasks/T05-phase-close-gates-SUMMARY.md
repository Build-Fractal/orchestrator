---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P03"
milestone: "M029"
provides:
  - "P03 phase-suite aggregator (13 gates: T01:2 + T02:1 + T03:1 + T04:5 + T05:4),P03 acceptance battery chaining SC-7/8/9/10 (BATTERY: p03-acceptance pass=4 fail=0),LIVE-tree readonly-invariant covering --live + at-rest + summarize-milestone surfaces with auto-loop-marker exclusions,P03 scope-guard with P01+P02 upstream-phase carve-out and M029 execution-log.jsonl rescue,AD-4 spec amendment record entry on specs/037-roadmap-visibility-cli-ux/spec.md plus paired shape verifier (8 load-bearing tokens)"
requires:
  - "P02,P03/T01,P03/T02,P03/T03,P03/T04"
affects:
  - "P03/T06"
key_files:
  - "tests/m029-acceptance/p03-acceptance-battery.sh,tools/verify/m029-p03-acceptance-battery-shape.sh,tools/verify/m029-p03-readonly-invariant.sh,tools/verify/m029-p03-scope-guard.sh,tools/verify/m029-p03-spec-amendment-shape.sh,tools/verify/m029-p03-phase-suite.sh,specs/037-roadmap-visibility-cli-ux/spec.md"
key_decisions:
  - "AD-4 SC-8 oracle interface clarification,CON-1/FR-14 read-only with sole allowed write site under /tmp,M029 execution-log.jsonl explicit rescue from the M019-owned global denylist for the T06 milestone-grain unit_close write site,upstream-phase carve-out composes (P03 admits both P01 and P02 untracked deliverables),AD-19 straight-line bash preserved end-to-end (13 literal bash invocations + emit_gate_result),MEM001 Bash 3.2 with printf-pipe-while-read replacement for herestring,WARN-on-unclassified is advisory (32 WARN from knowledge-graph hit_count auto-edits expected per P02 close)"
patterns_established:
  - "phase-suite shape mirroring unbroken from P01/T06 through P03/T05 (linear bash path; rc capture; emit_gate_result; aggregate SUMMARY),AD-4 spec-amendment record-as-permanent-artifact under H2 Spec Amendment Record with paired shape verifier (mirrors M032/M033 in-spec amendment practice),upstream-phase carve-out generalises and composes (P03 unions P01+P02 carve-outs cleanly),M029 execution-log.jsonl dual-mechanism rescue (M029-prefix allowlist plus explicit case-block early return in _deny_reason),BSD-grep verifier-hygiene paper-cut (literal hyphen-leading needle requires -e separator with NO trailing sentinel; load into quoted variable and feed as -e operand),readonly-invariant exclusion-list additive across phases (P02: execution-log+sentinel; P03 adds .complete+.txt for auto-loop/dispatch markers),phase-temporal scope-guard discipline (each scope-guard is snapshot-at-close not steady-state; downstream phase mutations expected to drift upstream phase-suites; canonical signal is always the current phases own phase-suite)"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P03/tasks/T01-render-position-live-and-savings-marker-SUMMARY.md, .orchestrator/milestones/M029/phases/P03/tasks/T02-auto-preflight-summary-SUMMARY.md, .orchestrator/milestones/M029/phases/P03/tasks/T03-auto-chain-flag-SUMMARY.md, .orchestrator/milestones/M029/phases/P03/tasks/T04-fixtures-and-sc-acceptance-SUMMARY.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-06T04:40:47Z"
---

M029/P03/T05 ships the P03 phase-close gate scaffolding plus the AD-4 spec amendment record entry. Six new artifacts on disk; one spec append.

Deliverables shipped:

- tests/m029-acceptance/p03-acceptance-battery.sh -- chains the four P03 SC acceptance scripts (SC-7 live-tail latency + canonical compact savings marker; SC-8 auto preflight predicted_cost byte-identity via AD-4 oracle wrapper; SC-9 Quick intensity suppresses preflight; SC-10 --auto-chain marker writes + resume) and emits the canonical aggregate BATTERY: p03-acceptance pass=4 fail=0 line. Bash 3.2 / MEM001. AD-19 straight-line. Mirrors p02-acceptance-battery.sh end-to-end.

- tools/verify/m029-p03-acceptance-battery-shape.sh -- 12-assertion shape-plus-behavioural verifier. Asserts file existence, executable bit, references to all four SC scripts, BATTERY: token literal, Bash 3.2/MEM001 declaration, AD-19 reference; runs the battery end-to-end and asserts BATTERY: p03-acceptance pass=4 fail=0. SUMMARY: pass=12 fail=0.

- tools/verify/m029-p03-readonly-invariant.sh -- LIVE-tree variant of the read-only contract (project-tree complement to the SC fixture-tree variants). Drops a sentinel under TMPDIR/, sleeps 1s for mtime gap, exercises three P03 surfaces (render-position --live timed-kill at ~1.5s; render-position at-rest; summarize-milestone --milestone --format=keys), then find -newer scans .orchestrator/ for offenders. Excludes execution-log.jsonl (M019 owned), *.sentinel (defensive), *.complete and *.txt (auto-loop / dispatch markers outside P03 surface contract). SUMMARY: pass=6 fail=0.

- tools/verify/m029-p03-scope-guard.sh -- enforces P03 allowlist plus P01/P02 upstream-phase carve-out and P03-specific denylist (commands/init.md M033, scripts/lifecycle/auto-loop.sh Principle XV, M027 surfaces under CON-7/AD-8, .orchestrator/integrations/github.json under CON-4/FR-11, M020 KNOWLEDGE.md/DECISIONS.md). Special-case carve-out: M029 execution-log.jsonl is admitted by the M029/* allowlist plus an explicit early-return in _deny_reason (T06 milestone-grain unit_close write site). WARN-on-unclassified is genuinely advisory per P02 precedent. SUMMARY: pass=16 fail=0 warn=32 (the 32 WARN entries are knowledge-graph hit_count auto-edits and KNOWLEDGE-INDEX.md drift -- expected noise per P02 close).

- tools/verify/m029-p03-spec-amendment-shape.sh -- 8-assertion verifier covering each load-bearing token in the AD-4 amendment record entry: Spec Amendment Record header, AD-4 reference, summarize-milestone.sh, predictive-surface.sh, cost_standard_usd, --no-predict suppression-flag clarification, byte-identity invariant phrasing. The --no-predict needle is fed via a quoted variable to avoid the BSD-grep -- sentinel-misparse paper-cut surfaced during T05 authoring. SUMMARY: pass=8 fail=0.

- tools/verify/m029-p03-phase-suite.sh -- canonical P03 close gate. 13 literal bash <verifier> invocations followed by emit_gate_result aggregator (mirrors p02-phase-suite.sh). T01:2 + T02:1 + T03:1 + T04:5 + T05:4 = 13. The T06 milestone-grain validators (validate-milestone-pass, closure-ceremony-shape) are NOT included because they are milestone-grain not phase-grain; they fold into validate-milestone.sh M029 alongside the three phase-suites and the full SC-1..SC-14 acceptance battery. SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0.

Spec append:

- specs/037-roadmap-visibility-cli-ux/spec.md -- new H2 Spec Amendment Record section appended after Downstream Consumers. Documents the AD-4 SC-8 oracle interface clarification: original spec.md drafted bash scripts/dispatch/predictive-surface.sh --milestone <M###> but the shipped surface is --description --intensity. Decision was to amend SC-8 to use the shipped surface via an M029-owned wrapper rather than extend predictive-surface.sh which is closed under M027/CON-7. The amended oracle wrapper feeds summarize-milestone.sh --format=keys output as --description into predictive-surface.sh --intensity standard. The clarification spells out why --no-predict is NOT used (it short-circuits to zero stdout via NO_PREDICT=1 -> SUPPRESS=1, but the byte-identity contract operates on the un-suppressed cost_standard_usd= scalar). Cross-references M029-CONTEXT.md AD-4, commands/auto.md Preflight Summary section, p03-sc8-auto-preflight.sh, and summarize-milestone.sh.

Verification:

- New T05 verifiers all green: spec-amendment-shape pass=8/0, acceptance-battery-shape pass=12/0, readonly-invariant pass=6/0, scope-guard pass=16/0 warn=32.
- Phase-suite green at 13/13: SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0.
- T01..T04 verifiers re-run as non-regression: 9/9 still green (precheck pass=9 fail=0).
- All four SC acceptance scripts green when run inside the battery: BATTERY: p03-acceptance pass=4 fail=0.

Documented in-flight observation (no correctness blocker):

- P01/P02 phase-suites' scope-guards now FAIL on M029/execution-log.jsonl modification when invoked while P03 is in flight. This is the well-understood snapshot-at-close pattern from P02's summary -- each phase scope-guard is phase-temporal, not steady-state. P03's scope-guard explicitly rescues the M029 execution-log via the M029/* allowlist plus a return-1 case in _deny_reason. The canonical P03-is-done signal is the P03 phase-suite, which is green.

Patterns established (load-bearing for T06 + future close gates):

1. Phase-suite shape mirroring across phases -- linear bash <path>; rc=dollar-question; emit_gate_result invocations; aggregate SUMMARY at end. Established P01/T06 -> P02/T05 -> P03/T05 unbroken.
2. AD-4 spec-amendment record-as-permanent-artifact pattern -- amendments appended to specs/<feature>/spec.md under H2 Spec Amendment Record rather than silent rewrite, plus a paired shape verifier. Mirrors M032/M033 in-spec amendment record practice.
3. Upstream-phase carve-out generalised -- P03 scope-guard admits both P01 AND P02 untracked deliverables as upstream allowlist (not denylist). The carve-out cleanly composes; later phases can simply union prior-phase carve-outs.
4. M029 execution-log.jsonl rescue pattern -- M019 owns execution-log.jsonl globally, but the M029-grain unit_close write site (T06 deliverable) requires admission. The dual-mechanism rescue (allowlist by M029/* prefix + explicit case .orchestrator/milestones/M029/execution-log.jsonl) return 1 in _deny_reason lets the rest of the M019 owned denylist for sibling milestones stand untouched.
5. Verifier-hygiene paper-cut on BSD grep -- a literal hyphen-leading needle like --no-predict requires the -e separator without a trailing -- sentinel; BSD grep parses -- as a flag itself. The fix pattern is to load the needle into a quoted variable and feed it as the -e operand: NEEDLE=--no-predict ... grep -F -q -e "$NEEDLE" "$FILE". Worth lifting into ANTIPATTERNS.md as a verifier-author footgun.
6. Readonly-invariant exclusion-list expansion across phases -- P02 excluded execution-log.jsonl + *.sentinel; P03 also excludes *.complete and *.txt to handle auto-loop / dispatch-side markers that surface when --live mode polls execution-log mid-run. The exclusion-list is additive across phases, not regressive.

P03 close gates ship intact. T06 (milestone closure ceremony + validate-milestone.sh M029 + M029-VALIDATED + M029-SUMMARY.md + execution-log unit_close append) is unblocked.
