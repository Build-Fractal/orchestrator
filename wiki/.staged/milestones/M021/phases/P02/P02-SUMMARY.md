---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M021"
milestone: "M021"
provides:
  - "Class B detectors (AP-005..AP-009) in anti-pattern-lint.sh; scope widened to scripts/dispatch/lib and active task-PAYLOADs; marker-gated opt-in for specs/references/docs; 100x perf win via [[ =~ ]] replacing per-line grep forks, ANTIPATTERNS.md AP-005..AP-009 entries with M011/P05-P07 evidence and P01-wrapper remedies, scripts/verify/m021-p02-linter-v2.sh gate + 10 fixture seeds under tests/fixtures/m021-p02/ asserting Class A (AP-004) + Class B (AP-005..AP-009) coverage, suppression preservation, and ANTIPATTERNS.md wrapper-citation structure, scripts/verify/m021-p02-linter-scope.sh gate asserting marker-opt-in scope boundary (specs/references/docs excluded unless <!-- agent-facing --> marker present), tests/fixtures/m021-p02/scope-excluded-spec.md + scope-opted-in-spec.md fixtures, Agent-Facing Marker Convention subsection in references/engine.md"
requires:
  - "from:P01/T01,T02,T03 what:scripts/util/{with-env,read-range,run-probe}.sh referenced in remediation hints, from:P01 what:scripts/util/with-env.sh; from:P01 what:scripts/util/read-range.sh; from:P01 what:scripts/util/run-probe.sh, from:T01 what:scripts/verify/anti-pattern-lint.sh --fixture flag + AP-004..AP-009 tagged output; from:T02 what:ANTIPATTERNS.md AP-005..AP-009 headings each naming scripts/util/*.sh, from:T01 what:anti-pattern-lint.sh with marker-opt-in scope logic; from:T02 what:AP-004..AP-009 anchors in ANTIPATTERNS.md"
affects:
  - "P02, P02,P03,P04, P02,P03,P04, P02"
key_files:
  - "scripts/verify/anti-pattern-lint.sh, ANTIPATTERNS.md, scripts/verify/m021-p02-linter-v2.sh,tests/fixtures/m021-p02/class-a-cmd-sub.md,tests/fixtures/m021-p02/class-a-backtick.md,tests/fixtures/m021-p02/class-a-brace.md,tests/fixtures/m021-p02/class-b-simple-expansion.md,tests/fixtures/m021-p02/class-b-redirect-cmd-sub.md,tests/fixtures/m021-p02/class-b-quoted-brace.md,tests/fixtures/m021-p02/class-b-heredoc-expansion.md,tests/fixtures/m021-p02/class-b-task-plan-compound-PAYLOAD.md,tests/fixtures/m021-p02/suppressed.md,tests/fixtures/m021-p02/clean.md, scripts/verify/m021-p02-linter-scope.sh,tests/fixtures/m021-p02/scope-excluded-spec.md,tests/fixtures/m021-p02/scope-opted-in-spec.md,references/engine.md"
key_decisions:
  - "active-milestone-and-active-task filter for PAYLOAD scope (unclosed milestone + missing TNN-SUMMARY.md); in-place [[ =~ ]] detectors replacing subprocess grep, AD-11,AD-19, AD-19, AD-19"
patterns_established:
  - "Bash 3.2 [[ =~ ]] for per-line regex in hot linter loops avoids fork+exec; variable-assembled ERE for quote-character literals; heredoc-state machine with per-fence reset, Append-only antipattern register grows to 9 entries; each Class B entry names exactly one P01 wrapper in Remedy; M011/P05-P07 screenshot citations grounded in AD-2/AD-9, Fixture seed per detector under tests/fixtures/<milestone>-<phase>/; gate stages task-plan-compound fixture via tempdir with literal tasks/ segment so */tasks/*-PAYLOAD.md scope predicate fires; gate internals use $() and pipes freely (MEM004, AP-004 scope-of-enforcement note) because enforcement applies to inline tool-call sites, not verification-script internals; fixtures live outside linter default scan roots so main-repo sweep remains unaffected, Marker-opt-in scope boundary (<!-- agent-facing --> HTML comment promotes a specs/references/docs file into the linter default sweep); synthetic tempdir tree for scope-gate tests (copy linter + fixtures into mktemp -d with specs/ references/ docs/ subdirs, let linter PROJECT_ROOT resolve to tempdir)"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M021/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M021/phases/P02/tasks/T03-SUMMARY.md, .orchestrator/milestones/M021/phases/P02/tasks/T04-SUMMARY.md"
duration: "105m"
verification_result: "pass"
completed_at: "2026-04-17T19:06:43Z"
observability_surfaces:
  - "none"
---

P02 ships **Linter v2** — a strict superset of the [M016](../../../../milestones/M016/index.md) Class A anti-pattern detector extended with five Class B shape heuristics matching the residual M011/P05–P07 prompt triggers, widened scope to agent-facing task-PAYLOADs and the dispatch lib, and an `<!-- agent-facing -->` marker opt-in convention for specs/references/docs.

## What Was Built

- `scripts/verify/anti-pattern-lint.sh` v2 — five Class B detectors (simple-expansion `[AP-005]`, redirect-cmd-sub `[AP-006]`, quoted-brace `[AP-007]`, heredoc-expansion `[AP-008]`, task-plan-compound `[AP-009]`) layered on top of M016's Class A detection with no byte-level regression on unchanged inputs. Scope widened to `scripts/dispatch/lib/**/*.sh` and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` (active-milestone + active-task filtered). Marker-gated opt-in for `specs/`, `references/`, `docs/`.
- `ANTIPATTERNS.md` AP-005..AP-009 — five new entries with M011/P05–P07 screenshot evidence citations and remediation text naming a specific P01 wrapper (`with-env.sh` / `read-range.sh` / `run-probe.sh`).
- `scripts/verify/m021-p02-linter-v2.sh` + 10 fixtures under `tests/fixtures/m021-p02/` — gate asserts Class A + Class B detector coverage, suppression preservation, and ANTIPATTERNS.md wrapper-citation structure. 22 PASS assertions.
- `scripts/verify/m021-p02-linter-scope.sh` + 2 scope fixtures — gate asserts specs/references/docs exclusion with/without the marker. 10 PASS assertions.
- `references/engine.md` — "Agent-Facing Marker Convention" subsection documenting placement, scoped directories, and the always-scanned defaults.

## Key Decisions

- **100× perf fix (T01)** — initial implementation forked `printf | grep -qE` per line per detector, producing ~14k subprocesses per large PAYLOAD file and hanging the full-repo sweep for minutes. Rewrote every hot-path detector to Bash 3.2 built-in `[[ =~ ]]` / `case` glob matching. Per-file latency 19s → 0.17s; full repo 5.7s → 0.45s.
- **Active-milestone + active-task filter** — PAYLOAD scope skips closed milestones (milestone summary present) and completed tasks (sibling `TNN-SUMMARY.md` present). Prevents re-litigating 7527 historical findings while enforcing the live dispatch surface. Post-summary, the task's own PAYLOAD is also excluded — this is why each task's final full-repo lint assertion runs *after* the summary write.
- **Variable-assembled ERE for heredoc opener** — BSD/portable regex can't reliably match a literal single quote inline; the heredoc-expansion detector assembles the ERE via variable concatenation.
- **Fixture isolation** — all fixtures live under `tests/fixtures/m021-p02/` (outside linter default scan roots) so the main repo sweep exit 0 is preserved regardless of fixture content.
- **Gate internals use `$()` + pipes freely** — AP-004's "Scope of enforcement" note already carves this out. Enforcement applies to inline tool-call sites; verification-script internals are not agent-facing.
- **Four-backtick outer fence in `references/engine.md`** — the marker-convention example contains a ```` ```bash ```` fence; wrapping it in a four-backtick outer fence prevents any future marker opt-in from making the docs example trip the linter.

## Patterns Established

- **Built-in regex in hot linter loops** — `[[ =~ ]]` / `case` glob over `printf | grep` saves an order of magnitude on large scan surfaces.
- **Append-only antipattern register with wrapper-citation discipline** — every Class B entry names exactly one P01 wrapper in its Remedy. Citations grounded in [M011](../../../../milestones/M011/index.md) screenshots per AD-2/AD-9.
- **Marker-opt-in scope boundary** — `<!-- agent-facing -->` HTML-comment promotes a specs/references/docs file into the linter default sweep. Scope gate uses a synthetic mktemp tree with `specs/ references/ docs/` subdirs so PROJECT_ROOT resolves to the tempdir.
- **Per-class fixture seed + gate** — one fixture per detector under `tests/fixtures/<milestone>-<phase>/`; gate stages task-plan-compound via a tempdir with a literal `tasks/` segment so the `*/tasks/*-PAYLOAD.md` scope predicate fires.

## Verification Results

Phase suite `bash scripts/verify/run-suite.sh m021 P02` reports PASS: 2 / FAIL: 0 across both P02 gates. Full-repo `bash scripts/verify/anti-pattern-lint.sh` exits 0 in ~0.45s. External-modification check: no external modifications. All four task summaries present.

## Downstream Impact

P03 (Pre-Bash Hook) consumes AP-005..AP-009 IDs by name in its reject diagnostics and rewrites the shapes the linter detects at edit-time into wrapper invocations at tool-call time. P04 (Replay Corpus) validates that the hook + linter together eliminate the would-prompt count across the 20 M011 screenshots.
