---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M029"
provides:
  - "SC-5/SC-6/SC-13/SC-14 acceptance fixtures + scripts + AD-9 sentinel harness; six P02 shape verifiers all PASS; SC-5 byte-stable golden render covering all four glyph states (✓ ▶ ◇ ✗); #Q-G6 timestamp-strip pattern set locked; #Q-G8 canonical compact-form invariant mechanically enforced"
requires:
  - "from:T01 what:references/cross-milestone-feature-shape.md AD-6 schema authority; from:T02 what:scripts/diagnostics/summarize-milestone.sh AD-4 oracle; from:T03 what:scripts/diagnostics/render-position.sh tree renderer + commands/where.md skill"
affects:
  - "P02/T05 phase-suite aggregator (chains all six T04 verifiers as gates 5-10); P03 full SC-1..SC-14 acceptance battery embeds the SC-5/SC-6/SC-13/SC-14 slice; M029 milestone validator embeds the P02 acceptance"
key_files:
  - "tests/m029-acceptance/fixtures/where-mixed-state.fixture/,tests/m029-acceptance/fixtures/where-mixed-state.golden,tests/m029-acceptance/fixtures/where-pre-m019.fixture/,tests/m029-acceptance/timestamp-strip.sh,tests/m029-acceptance/sentinel-harness.sh,tests/m029-acceptance/p02-sc5-where-mixed-state.sh,tests/m029-acceptance/p02-sc6-where-pre-m019.sh,tests/m029-acceptance/p02-sc13-anti-coupling.sh,tests/m029-acceptance/p02-sc14-readonly.sh,tools/verify/m029-p02-sc5-fixtures-shape.sh,tools/verify/m029-p02-sentinel-harness-shape.sh,tools/verify/m029-p02-sc5-shape.sh,tools/verify/m029-p02-sc6-shape.sh,tools/verify/m029-p02-sc13-shape.sh,tools/verify/m029-p02-sc14-shape.sh"
key_decisions:
  - "AD-9 sentinel-file find -newer mechanism for SC-14; #Q-G6 enumerated timestamp-strip pattern set (TS/RECENCY/EPOCH); #Q-G8 canonical compact-form invariant (▽ saved Nk only,no via-tier1 verbose form); fixture orchestrator-root export so transitively-invoked metrics-rollup.sh sees the fixture tree; SC-13 spec-side scan narrowed to normative read-imperative pattern (carve-out for self-referential spec.md mentions of /integrations/github in FR-11/SC-13 definitions and conversus review meta)"
patterns_established:
  - "empty-phase-directory + .gitkeep as ◇ glyph driver; verify_result-record (phase=P##,result=fail) as ✗ glyph driver; ORCHESTRATOR_ROOT env export alongside --root flag for fixtures with transitively-invoked helpers; MEM004 carve-out applies to acceptance script bodies (sed/grep pipes inside scripts permitted,AD-19 single-script-file rule applies only to Check: lines); self-referential spec-paradox carve-out documented in acceptance-script header"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P02/tasks/T04-fixtures-and-sc-acceptance-PAYLOAD.md,tools/verify/m029-p02-sc5-fixtures-shape.sh,tools/verify/m029-p02-sentinel-harness-shape.sh"
duration: "2h"
verification_result: "pass"
completed_at: "2026-05-06T00:46:51Z"
---

# T04 — SC-5/SC-6/SC-13/SC-14 fixtures + acceptance scripts + AD-9 sentinel harness

## What shipped

T04 lands the four SC fixtures + acceptance scripts that gate P02, plus
the AD-9 sentinel harness used by SC-14 to mechanically enforce the
read-only invariant.

### Fixtures

1. **SC-5 mixed-state fixture tree**
   `tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator/milestones/M998/`
   with four phases that exercise all four canonical glyph states:
   - **P01** (✓): `P01-PLAN.md` + `P01-SUMMARY.md` + `tasks/T01-foo-PLAN+SUMMARY`.
   - **P02** (▶): `P02-PLAN.md`, four tasks (T01-x ✓ via SUMMARY, T02-y/T03-z/T04-w ▶ via PLAN-only).
   - **P03** (✗): `P03-PLAN.md` + `verify_result` record with `result: fail` for `phase: P03`
     in `execution-log.jsonl` (the renderer's `_rp_phase_glyph` derives ✗ from this).
   - **P04** (◇): empty directory with `.gitkeep` (no PLAN, no tasks → ◇).

   Synthetic `dispatch_usage` + `unit_close` records under M019 Tier 1
   schema for each P02 task so `metrics-rollup.sh --granularity task`
   emits a deterministic per-row cost cell. The plan author originally
   asked for three phases (P01/P02/P03) and assumed `T03-z-PLAN.md only`
   would render as `◇`, but the renderer's `_rp_task_glyph` returns ▶ for
   any task with a PLAN. Restructured to four phases so the milestone-
   grain glyph rollup covers all four canonical states (FR-5 / SC-5).

2. **SC-6 pre-M019 fixture tree**
   `tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator/milestones/M997/`
   — single P01-complete phase, NO `execution-log.jsonl`. The renderer's
   `_rp_has_m019_tier1` probe returns 1 (not present) and the cost
   column is silently omitted (FR-6 / CON-3).

3. **Golden render**
   `tests/m029-acceptance/fixtures/where-mixed-state.golden` — captured
   from `bash render-position.sh --milestone M998 --root <fixture>/.orchestrator`
   piped through `timestamp-strip.sh`. Byte-stable across runs.

### Acceptance utilities

4. **`tests/m029-acceptance/timestamp-strip.sh`** — the canonical #Q-G6
   timestamp-strip filter. Single `sed -E` invocation with three `-e`
   clauses enumerating exactly the three #Q-G6 patterns:
   `<TS>` / `<RECENCY>` / `<EPOCH>`. Reads stdin, writes stdout.

5. **`tests/m029-acceptance/sentinel-harness.sh`** — the AD-9 mechanism.
   Writes `.orchestrator/.m029-sc14-sentinel` with the current ISO-8601
   UTC timestamp, runs the wrapped command, then `find -newer` scans
   for any newer-mtime file under `$ORCHESTRATOR_ROOT` excluding the
   sentinel itself and `start-state/*.complete` (the documented FR-10
   exception). PASS iff no offenders.

### Acceptance scripts

6. `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` — renders against
   the SC-5 fixture, normalizes via `timestamp-strip.sh`, and `diff -u`
   asserts byte-identity against the golden. 8 PASS lines.

7. `tests/m029-acceptance/p02-sc6-where-pre-m019.sh` — asserts the
   `$<num>` cost-column delimiter does NOT appear in stdout AND stderr
   is byte-empty against the pre-M019 fixture. 5 PASS lines.

8. `tests/m029-acceptance/p02-sc13-anti-coupling.sh` — anti-coupling
   guard: spec-side scan for any normative `read .* /integrations/github`
   imperative + renderer-side literal `/integrations/github` substring
   scan. Both must return no match. 2 PASS lines.

9. `tests/m029-acceptance/p02-sc14-readonly.sh` — wraps the sentinel
   harness around `bash render-position.sh --milestone M998 --root
   <fixture>/.orchestrator` with `ORCHESTRATOR_ROOT` pointed at the
   fixture tree (so the scan does not surface unrelated developer-side
   writes in the project's live `.orchestrator/`). 5 PASS lines.

### Shape verifiers

10. `tools/verify/m029-p02-sc5-fixtures-shape.sh` — 19 PASS lines.
    Asserts both fixture trees, the golden, the timestamp-strip filter
    (`<TS>` / `<RECENCY>` / `<EPOCH>` placeholders), and the #Q-G8
    invariant (no `via tier1 cache reuse`, no `▽ saved` in fixtures).

11. `tools/verify/m029-p02-sentinel-harness-shape.sh` — 10 PASS lines.
    Asserts AD-9 mechanism declarations + behavioral spot-check (harness
    around `true` under a synthetic temp orchestrator-root exits 0).

12. `tools/verify/m029-p02-sc{5,6,13,14}-shape.sh` — 8/9/8/8 PASS lines
    each. Each asserts file existence + executability + key surface
    references + canonical SUMMARY line shape + behavioral run (the
    full SC acceptance against the fixtures T04 just built).

## Decisions surfaced

### #Q-G6 timestamp-strip pattern set (locked at this task)

`timestamp-strip.sh` enumerates exactly the three patterns documented in
the M029 brief: ISO-8601 UTC timestamps -> `<TS>`, recency phrasing
(`Nm/h/d ago`) -> `<RECENCY>`, and epoch-second tokens (`16xxx...`-`19xxx...`)
-> `<EPOCH>`. Adding patterns silently risks under-stripping in CI;
missing one causes byte-identity failures from natural drift. The set
is locked here for downstream consumers (P03's full acceptance battery).

### #Q-G8 canonical FR-8 marker form

The compact `▽ saved Nk` form is the only canonical form. The verbose
form `▽ saved Nk via tier1 cache reuse` is reserved for a future
`--verbose` mode and MUST NOT appear in v1 deliverables. The fixtures
verifier mechanically enforces this against the golden, the strip
filter, the four acceptance scripts, the sentinel harness, and the
fixture trees themselves.

### SC-13 self-reference resolution

The plan asked for `grep -r '/integrations/github' specs/037-... scripts/diagnostics/render-position.sh`
to return no match. The renderer-side check is straightforward and
load-bearing. The spec-side check has a self-reference paradox: spec.md's
FR-11 (line ~138) and SC-13 (line ~157) both quote the literal
`/integrations/github` string to DEFINE the constraint. The conversus/
subdir contains review meta that also discusses the constraint by name.
Resolved by tightening the spec-side check to match only normative
read-imperatives (`read[s]?\s+\S*/integrations/github`) rather than any
literal mention. The renderer-side literal check remains the load-bearing
assertion. Documented as a carve-out note in the SC-13 acceptance script
header.

### Fixture orchestrator-root scoping

The renderer's `--root` flag overrides `.orchestrator/` discovery for
its own probes, but `metrics-rollup.sh` (invoked transitively by
`_rp_cost_column`) reads `ORCHESTRATOR_ROOT` from the env. The SC-5
acceptance script exports `ORCHESTRATOR_ROOT="$FIXTURE"` before
invoking the renderer so the cost column populates against the fixture
tree, not the project's live `.orchestrator/`. Same applies to SC-14:
the harness scans `$ORCHESTRATOR_ROOT`, and pointing it at the fixture
prevents false-positive newer-mtime hits from concurrent developer
state in the project tree.

## Verification

All six P02 must-have verifiers PASS:

- `tools/verify/m029-p02-sc5-fixtures-shape.sh` — pass=19 fail=0
- `tools/verify/m029-p02-sentinel-harness-shape.sh` — pass=10 fail=0
- `tools/verify/m029-p02-sc5-shape.sh` — pass=8 fail=0
- `tools/verify/m029-p02-sc6-shape.sh` — pass=9 fail=0
- `tools/verify/m029-p02-sc13-shape.sh` — pass=8 fail=0
- `tools/verify/m029-p02-sc14-shape.sh` — pass=8 fail=0

Each shape verifier embeds a behavioral run of its underlying SC
acceptance script, so the SC acceptance itself is exercised end-to-end
through these gates.

## Patterns established for downstream P02 tasks

- **Self-referential spec paradox carve-out** — when a spec defines a
  grep-based anti-coupling check by quoting the literal it looks for,
  the acceptance script narrows the spec-side scan to normative
  imperative shapes rather than literal mentions. Document the carve-out
  in the script header so the relaxation is auditable.
- **Fixture orchestrator-root export + --root flag** — the renderer's
  `--root` flag scopes its own probes; transitively-invoked helpers
  that read `ORCHESTRATOR_ROOT` from the env need the env exported too.
  The SC scripts export `ORCHESTRATOR_ROOT="$FIXTURE"` before invoking
  the renderer.
- **Empty-phase-directory ◇ glyph driver** — to exercise the renderer's
  `◇` (pending) phase glyph in a fixture, ship an empty `phases/P##/`
  directory with a `.gitkeep` file so git tracks the directory but the
  renderer sees no PLAN / SUMMARY / tasks.
- **verify_result-record ✗ glyph driver** — to exercise the renderer's
  `✗` (failed) phase glyph, ship a `verify_result` record in
  `execution-log.jsonl` with `phase: P##` + `result: fail` regardless
  of whether the phase has a PLAN file.
- **MEM004 carve-out applies to acceptance scripts** — pipes inside
  acceptance script bodies (`bash renderer | bash strip > out`) are
  permitted; the AD-19 single-script-file constraint applies only to
  Check: lines invoked from the harness (`bash tools/verify/...`).
