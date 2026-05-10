---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M035"
goal: "orchestrator:update multi-source dispatch (FR-13, AD-5 detect-by-install-method-first) + update_source: git|npm|homebrew|none config schema (FR-13, #Q-5 resolved at this plan-phase) + update_run JSONL emission honoring CON-7/M027 5-condition suppression matrix (FR-13, FR-16) + extended commands/update.md operator-facing dispatch documentation + tests/m035-acceptance/run-acceptance-battery.sh covering SC-1..SC-15 + SC-15 self-reference + M035-VALIDATED marker + M035-SUMMARY.md on milestone closure (SC-16)."
demo_sentence: "`bash scripts/lifecycle/run-update.sh --dry-run` against three fixture projects with `update_source: git`, `update_source: npm`, and `update_source: homebrew` configured in `.orchestrator/config.yml` each emits the channel-appropriate dispatched command on stdout (`would_invoke=git pull && install-claude-code.sh --force` / `would_invoke=npm update -g @build-fractal/orchestrator` / `would_invoke=brew upgrade orchestrator`); each non-dry-run dispatch appends exactly one `update_run` JSONL event to `.orchestrator/observability/<date>.jsonl` (SC-13); `bash tests/m035-acceptance/run-acceptance-battery.sh` emits `BATTERY: pass=N fail=0` (SC-15); `bash scripts/verify/validate-milestone.sh M035` reports 100% PASS and `M035-VALIDATED` exists on disk (SC-16)."
risk: "medium"
depends_on: ["P02", "P03", "P04"]
---

## Plan-Phase-Resolved Open Questions (AD-7)

These resolve at this plan-phase per AD-7 / spec routing. They land as
design constraints in the task plans below.

- **Spec #Q-5 (config schema for `update_source`)** → **`update_source:
  git|npm|homebrew|none`** as a top-level scalar key in
  `.orchestrator/config.yml`. Default behavior when absent: AD-5
  detect-by-install-method-first (read `.orchestrator/install-meta.txt`
  `runtime=` provenance + presence-of-published-channel signals to
  resolve, then **persist the detected source back to config** for
  future runs — single resolve, then stable). The literal string `none`
  is the operator opt-out: when set, both `orchestrator:update` and the
  drift-render path (FR-4 / FR-16) suppress silently — no dispatch,
  no JSONL emission, no warning. Curl-pipe-bash dispatch is folded
  into the `git`-source path in the same way `homebrew` and `npm`
  read their own dispatch — but the *config* enumeration stays at
  `git|npm|homebrew|none` per spec FR-13's literal three-channel
  contract; `curl-pipe-bash` users whose install resolved through
  `install.sh` are detected as `npm` (because curl-pipe-bash extracts
  the npm tarball — D007/D009 single-source-of-truth) and persist as
  `npm` for future runs. This narrows the schema enumeration without
  losing channel coverage. Recorded as **D012** (`M035/P06 convention`,
  appended at T01). Bound to FR-13 / FR-16 / SC-13 / AD-5.

- **Implicit #Q-P06-1 (5-condition suppression matrix mapping for
  `update_run` JSONL emission)** → honor [M027](../../../../milestones/M027/index.md)'s 5-condition matrix
  verbatim: (a) `--no-emit-jsonl` flag on `run-update.sh` short-circuits
  emission; (b) `ORCHESTRATOR_AUTO=1` env var short-circuits emission
  (auto-loop runs are not metering events that the operator cares to
  see); (c) `update_source: none` short-circuits emission (no dispatch
  → no event); (d) `compression.efficiency_footer.enabled: false` config
  knob does NOT apply (orthogonal surface — that knob gates
  efficiency-footer rendering, not JSONL stream writes); (e) the
  structural carve-out is: when the dispatch itself fails before any
  channel-specific work (e.g. validation failure), no event is emitted —
  emission is bound to a successful dispatch decision-point, not to the
  invocation. Rationale: M035 introduces no new suppression knob per
  FR-16; it inherits M025/M027 conventions, and the (a)/(b)/(c)/(e)
  semantics map cleanly onto the existing matrix shape. (d) is
  explicitly carved out so future authors don't accidentally bind
  unrelated knobs. Recorded as **D013** (`M035/P06 convention`,
  appended at T03). Bound to FR-13 / FR-16 / CON-7.

- **Implicit #Q-P06-2 (AD-5 detection ordering — multiple signals
  could conflict)** → resolution order: (1) `.orchestrator/install-meta.txt`
  `runtime=` field if it carries an install-channel discriminator
  (looks for the literal substrings `npm` / `homebrew` / `curl` / `git`
  in the value, case-insensitive); (2) presence of the npm package's
  symlink at `$(npm root -g)/@build-fractal/orchestrator` if `npm`
  binary is on PATH and exits zero on `npm root -g`; (3) presence of
  the homebrew formula receipt at `$(brew --prefix)/Cellar/orchestrator/`
  if `brew` binary is on PATH and exits zero on `brew --prefix`; (4)
  fallback to `git` (the pre-M035 interim's only-source). First-match
  wins, not majority-vote. The first three checks are read-only and
  bounded — at worst one `command -v` + one `npm/brew` invocation each.
  When detection lands on a non-`git` source, persist by writing
  `update_source: <detected>` as a top-level key into
  `.orchestrator/config.yml` (using `scripts/state/read-config.sh`'s
  existing append discipline if available, or a structural append if
  not). Recorded as **D014** (`M035/P06 convention`, appended at T02).
  Bound to FR-13 / AD-5 / SC-13.

## Must-Haves

### Truths

- `.orchestrator/config.yml` accepts `update_source: git|npm|homebrew|none`
  as a registered top-level key; `scripts/state/read-config.sh` returns
  the configured value (or `null` for unset, per the existing
  null-sentinel pattern); invalid values (e.g. `update_source: ftp`)
  surface a stderr advisory with the canonical four-value enumeration
  and the dispatch falls back to AD-5 detection.
  - Check: `bash tools/verify/m035-p06-config-schema-shape.sh`

- `scripts/lifecycle/run-update.sh` reads `update_source` from
  `.orchestrator/config.yml` (via the new `read-config.sh` registration)
  and dispatches to the channel-appropriate command path (`git pull` +
  `install-claude-code.sh --force` for `git`; `npm update -g
  @build-fractal/orchestrator` for `npm`; `brew upgrade orchestrator`
  for `homebrew`; explicit no-op + `# update_source: none` advisory for
  `none`). When config is absent, AD-5 detection runs in the order
  recorded in D014 and persists the detected source to config.
  - Check: `bash tools/verify/m035-p06-multi-source-dispatch-shape.sh`

- `scripts/lifecycle/run-update.sh` emits exactly one `update_run` JSONL
  event per successful dispatch decision-point (the rollback path's
  emission shipped in P05 T02 stays unchanged). The event lives at
  `.orchestrator/observability/<YYYY-MM-DD>.jsonl` and carries at
  minimum the fields `event=update_run`, `op=update`, `source=<resolved
  channel>`, `target_version=<post-dispatch version or "unknown">`,
  `result=success|failure`, `timestamp=<ISO 8601 UTC>`. Emission honors
  D013's 5-condition suppression matrix.
  - Check: `bash tools/verify/m035-p06-update-run-jsonl-emission-shape.sh`

- `commands/update.md` extends the existing `## Update sources` H2
  (shipped via P03/P04 documentation passes) with: a per-source dispatch
  command table, an explicit AD-5 detection-order paragraph (mirroring
  D014), the `update_source: none` opt-out semantics, and the JSONL
  event shape + suppression-knob enumeration (mirroring D013). Cross-
  references `references/installation.md § Installing via <channel>`
  for each channel. The `## Rollback` section (shipped via P05 T02) is
  preserved unmodified.
  - Check: `bash tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`

- `tests/m035-acceptance/run-acceptance-battery.sh` exists, executable,
  chains every per-phase aggregator (`tools/verify/m035-p00-phase-suite.sh`
  through `tools/verify/m035-p05-phase-suite.sh` and the new
  `tools/verify/m035-p06-phase-suite.sh`), reports per-phase PASS/FAIL,
  and emits a single `BATTERY: pass=N fail=0 skip=M` rollup line on
  stdout. SC-15 is the self-reference: this script's own BATTERY line is
  one of the SCs it's reporting against. Mirrors the M029/M030/M031/M032/[M037](../../../../milestones/M037/index.md)
  acceptance-battery convention.
  - Check: `bash tools/verify/m035-p06-acceptance-battery-shape.sh`

- `tests/m035-acceptance/run-acceptance-battery.sh` end-to-end run
  emits `BATTERY: pass=15 fail=0 skip=M` (or higher pass count if
  per-SC-fanout is wider than 1:1) covering SC-1..SC-15. SC-16 is
  satisfied separately via `validate-milestone.sh M035 = PASS` + the
  `M035-VALIDATED` marker on disk; the battery does not self-assert
  SC-16 because that creates a chicken-and-egg loop (the marker is
  written by milestone close, which the battery itself gates).
  - Check: `bash tests/m035-acceptance/run-acceptance-battery.sh`

- `tools/verify/m035-p06-phase-suite.sh` exists, chains every per-truth
  verifier scheduled in this phase (T01–T05), parses each verifier's
  BATTERY line, sums pass/fail/skip, emits per-verifier PASS/FAIL plus a
  consolidated `BATTERY: pass=N fail=0 skip=M` rollup, and exits 0 iff
  total_fail=0. Mirrors the P05 T06 + P04 T04 phase-suite shape.
  - Check: `bash tools/verify/m035-p06-phase-suite.sh`

- `bash scripts/verify/validate-milestone.sh M035` reports 100% PASS
  with `M035-VALIDATED` marker on disk and `M035-SUMMARY.md` populated
  per the milestone-summary template. (SC-16; verified at the very end
  of T06 after the milestone-grain `unit_close` JSONL entry lands.)
  - Check: `bash tools/verify/m035-p06-milestone-close-shape.sh`

### Artifacts

- `scripts/state/read-config.sh` (modified — `VALID_KEYS` includes
  `update_source` and the four-value enumeration is documented inline)
- `scripts/lifecycle/run-update.sh` (modified — multi-source dispatch
  block added before the existing git-source-only fast path; AD-5
  detection helper invoked when config absent; persistence write on
  detected non-`git` resolution)
- `commands/update.md` (modified — extended `## Update sources` H2 +
  per-channel dispatch table + AD-5 detection paragraph + suppression
  knob enumeration; `## Rollback` section preserved verbatim from P05)
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (modified — appends D012 update_source
  schema, D013 suppression matrix mapping, D014 AD-5 detection order)
- `tools/verify/m035-p06-config-schema-shape.sh` (create, min 40 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (create, min 60
  lines, contains `BATTERY:` AND `update_source`)
- `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (create,
  min 60 lines, contains `BATTERY:` AND `update_run`)
- `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`
  (create, min 30 lines, contains `BATTERY:`)
- `tools/verify/m035-p06-acceptance-battery-shape.sh` (create, min 40
  lines, contains `BATTERY:`)
- `tools/verify/m035-p06-milestone-close-shape.sh` (create, min 30
  lines, contains `BATTERY:` AND `M035-VALIDATED`)
- `tools/verify/m035-p06-phase-suite.sh` (create, min 60 lines, contains
  `BATTERY:`)
- `tests/m035-acceptance/run-acceptance-battery.sh` (create, min 80
  lines, contains `BATTERY:` AND `m035-p05-phase-suite.sh` AND
  `m035-p06-phase-suite.sh`)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-git/.orchestrator/config.yml`
  (create, contains `update_source: git`)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-npm/.orchestrator/config.yml`
  (create, contains `update_source: npm`)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-homebrew/.orchestrator/config.yml`
  (create, contains `update_source: homebrew`)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-none/.orchestrator/config.yml`
  (create, contains `update_source: none`)
- `.orchestrator/milestones/M035/M035-VALIDATED` (create, marker file
  with timestamp)
- [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../milestones/M035/M035-SUMMARY.md) (create, populated per
  the milestone-summary template)

### Key Links

- `commands/update.md` → `scripts/lifecycle/run-update.sh` (skill →
  driver dispatch, extended with multi-source)
- `scripts/lifecycle/run-update.sh` → `scripts/state/read-config.sh`
  (driver reads `update_source` via the registered key)
- `scripts/lifecycle/run-update.sh` → `.orchestrator/observability/<date>.jsonl`
  (driver appends `update_run` event per successful dispatch)
- `tests/m035-acceptance/run-acceptance-battery.sh` →
  `tools/verify/m035-p06-phase-suite.sh` (battery chains the P06 suite)
- `tests/m035-acceptance/run-acceptance-battery.sh` →
  `tools/verify/m035-p05-phase-suite.sh` (battery chains every prior
  phase suite — full milestone rollup)
- `tools/verify/m035-p06-phase-suite.sh` →
  `tools/verify/m035-p06-config-schema-shape.sh` (aggregator → unit)
- [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../milestones/M035/M035-SUMMARY.md) →
  `tests/m035-acceptance/run-acceptance-battery.sh` (summary cites the
  battery as the SC-15 evidence surface)

## Tasks

### T01: `update_source` config schema — `read-config.sh` VALID_KEYS + D012

See `tasks/T01-config-schema-update-source-PLAN.md`.

### T02: Multi-source dispatch in `run-update.sh` + AD-5 detection + D014

See `tasks/T02-multi-source-dispatch-PLAN.md`.

### T03: `update_run` JSONL emission for non-rollback path + 5-condition suppression matrix + D013

See `tasks/T03-update-run-jsonl-emission-PLAN.md`.

### T04: `commands/update.md` extended dispatch documentation

See `tasks/T04-update-skill-doc-multi-source-PLAN.md`.

### T05: SC-1..SC-15 acceptance battery + per-truth verifiers + fixtures

See `tasks/T05-acceptance-battery-and-fixtures-PLAN.md`.

### T06: Phase-suite aggregator + milestone close (M035-VALIDATED + M035-SUMMARY.md)

See `tasks/T06-phase-suite-and-milestone-close-PLAN.md`.

## Task Dependencies

```
T01 (config schema) ─────────┐
T01 (config schema) ────► T02 (multi-source dispatch) ─┐
T02 (multi-source dispatch) ────► T03 (JSONL emission) ┤
T01 + T02 + T03 ─────────────────► T04 (skill doc) ────┤
T01 + T02 + T03 + T04 ───────────► T05 (acceptance battery + verifiers) ──► T06 (phase-suite + milestone close)
```

T01 lands first (others read it). T02 reads T01's config-schema. T03
reads T02's dispatch surface (the JSONL emission point lives inside T02's
multi-source dispatch block). T04 reads T01/T02/T03 to document the
contract end-to-end. T05 chains every per-truth verifier scheduled
across T01–T04 plus the milestone-grain rollup. T06 ships the phase-suite
aggregator + the milestone-close artifacts after all preceding tasks
have closed.

## Files Likely Touched

- `scripts/state/read-config.sh` (modify)
- `scripts/lifecycle/run-update.sh` (modify)
- `commands/update.md` (modify)
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (modify — D012 / D013 / D014)
- `tools/verify/m035-p06-config-schema-shape.sh` (create)
- `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (create)
- `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (create)
- `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` (create)
- `tools/verify/m035-p06-acceptance-battery-shape.sh` (create)
- `tools/verify/m035-p06-milestone-close-shape.sh` (create)
- `tools/verify/m035-p06-phase-suite.sh` (create)
- `tests/m035-acceptance/run-acceptance-battery.sh` (create)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-git/.orchestrator/config.yml` (create)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-npm/.orchestrator/config.yml` (create)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-homebrew/.orchestrator/config.yml` (create)
- `tests/m035-acceptance/fixtures/m035-p06-config-update-source-none/.orchestrator/config.yml` (create)
- `.orchestrator/milestones/M035/M035-VALIDATED` (create)
- [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../milestones/M035/M035-SUMMARY.md) (create)

## Notes

**Plan-Time Discipline checks performed:**

- **Rule 1 (Prerequisite-existence)**: `scripts/state/read-config.sh`,
  `scripts/lifecycle/run-update.sh`, `commands/update.md`,
  `.orchestrator/config.yml`, [`.orchestrator/DECISIONS.md`](../../../../decisions.md),
  `tests/m035-acceptance/cross-channel-byte-equivalence.sh`,
  `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`,
  `tools/verify/m035-p02-phase-suite.sh`,
  `tools/verify/m035-p03-phase-suite.sh`,
  `tools/verify/m035-p04-phase-suite.sh`,
  `tools/verify/m035-p05-phase-suite.sh`,
  `scripts/verify/validate-milestone.sh` all confirmed present on disk
  at plan-authoring time.

- **Rule 2 (Verifier-availability)**: every `Check:` command in this
  plan references either a `tools/verify/m035-p06-*.sh` script that is
  scheduled as a deliverable inside this phase's task plans (T01–T06)
  or `tests/m035-acceptance/run-acceptance-battery.sh` which is itself
  scheduled in T05. No cross-task verifier dependency that would
  deadlock auto-loop. The acceptance battery's chained sub-aggregators
  (`m035-p00-phase-suite.sh` ... `m035-p05-phase-suite.sh`) all exist
  on disk today (P00 through P05 are closed). The new
  `m035-p06-phase-suite.sh` is scheduled in T06 — the battery's invocation
  of it lands at the same task close.

- **Rule 3 (Classifier-shape)**: all proposed `Check:` commands use the
  single-script-file shape per AD-19 (`bash tools/verify/<...>` /
  `bash tests/m035-acceptance/<...>`). No compound chains, no
  `$(...)` containing pipes, no plain subshells. The
  `run-update.sh` AD-5 detection logic uses `command -v` + intermediate
  variable assignment to keep each shell statement to a single command
  with no inline pipes or subshells; `npm root -g` and `brew --prefix`
  invocations capture stdout via `$(...)` (no pipe inside) which is
  AP-009-permitted because the substitution body is a single command.
  Drift-detection helper is read-only and bounded (D014 enumerates the
  exact ordering and exit conditions).

- **Rule 4 (run-probe.sh scope)**: every verifier scheduled here is a
  repo-resident `tools/verify/m035-p06-*.sh` invoked directly via
  `bash tools/verify/<path>`. `run-probe.sh` is reserved for any
  `/tmp/`-staged fixture-construction probes referenced inside T05
  (the dispatch test-mode invocations stage projects under
  `mktemp -d` / `/tmp/m035-p06-*-fixture-$$/` and use run-probe.sh
  if any compound logic is needed there).

- **Rule 5 (real-DB / real-app smoke)**: N/A — P06 introduces no SQL
  surface. The acceptance battery DOES exercise real-application smoke
  paths (real `run-update.sh --dry-run` against fixture projects with
  real `.orchestrator/config.yml` files; real JSONL emission against
  mktemp project trees) so Plan-Time Discipline Rule 5's "real-app
  smoke" intent is satisfied via the acceptance test surface even
  though no SQL is involved.

- **Rule 6 (Path-collision)**: `ls -la` performed against every
  `create` path enumerated in `## Files Likely Touched`:
  - `tools/verify/m035-p06-config-schema-shape.sh` — ABSENT
  - `tools/verify/m035-p06-multi-source-dispatch-shape.sh` — ABSENT
  - `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` — ABSENT
  - `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` — ABSENT
  - `tools/verify/m035-p06-acceptance-battery-shape.sh` — ABSENT
  - `tools/verify/m035-p06-milestone-close-shape.sh` — ABSENT
  - `tools/verify/m035-p06-phase-suite.sh` — ABSENT
  - `tests/m035-acceptance/run-acceptance-battery.sh` — ABSENT
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-git/.orchestrator/config.yml` — ABSENT (parent dir absent)
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-npm/.orchestrator/config.yml` — ABSENT (parent dir absent)
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-homebrew/.orchestrator/config.yml` — ABSENT (parent dir absent)
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-none/.orchestrator/config.yml` — ABSENT (parent dir absent)
  - `.orchestrator/milestones/M035/M035-VALIDATED` — ABSENT
  - [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../milestones/M035/M035-SUMMARY.md) — ABSENT
  No collisions; every new verifier and fixture path carries the
  `m035-p06-` slug per the milestone-prefix convention.

**[M033](../../../../milestones/M033/index.md) friendly-tester gate disposition:** the M033 friendly-tester
gate is cleared via signed-attestation per the maintainer-advisory
report at `tests/m033-acceptance/friendly-tester-pass/reports/2026-05-09-maintainer-advisory.md`
(commit `1fc95833`). P06 entry is unblocked. The roadmap's `Blocked by:`
external prerequisite on this phase is satisfied via the same
attestation path that cleared P04. No documentation contingency
deltas surfaced for `commands/update.md`.

**Expected verifier output shape:**

Every per-truth verifier emits `BATTERY: pass=N fail=N` (and `skip=M`
where applicable per the acceptance-battery convention). Phase-suite
aggregator (T06) chains every per-truth verifier and emits
`BATTERY: pass=<sum> fail=0 skip=<sum>` summing across the seven
per-truth verifiers (six T01–T05 verifiers + the acceptance battery
self-reference). The milestone-grain acceptance battery chains every
phase suite (P00–P06, seven aggregators) and emits a single
`BATTERY: pass=N fail=0 skip=M` rollup.

**Risk areas worth flagging at execution time:**

1. **AD-5 detection's `npm root -g` invocation** — on a CI runner
   without a global npm install, `npm root -g` exits 0 with a path
   that may not exist; the detector must `[ -d "$path/@build-fractal/orchestrator" ]`
   rather than trusting the exit code. Same for `brew --prefix`.
2. **Persistence write to `.orchestrator/config.yml`** — D014's
   "persist detected source" semantics require an in-place edit of
   the YAML file. T02 must use a single-line append (since
   `update_source` is a top-level scalar key) and check if the key
   already exists before appending — duplicate top-level keys would
   surface as a `read-config.sh` warning. The simplest shape: grep
   for an existing line, sed-replace if present, append if absent.
3. **`update_run` JSONL emission directory creation** — the rollback
   path in `run-update.sh` already has `mkdir -p "$obs_dir"`; T03 must
   ensure the non-rollback dispatch path uses the same idiom (don't
   assume the directory exists, especially on first-run consumers).
4. **Acceptance battery's chained sub-aggregator invocation order** —
   the M029/M030/M031/M032/M037 batteries chain in phase order
   (P01 → P02 → P03 → ...). The M035 battery chains P00 → P01 → P01.5
   → P02 → P03 → P04 → P05 → P06. The decimal `P01.5` slug requires
   a slug-aware iteration (don't use a `for p in P0{0..6}` brace
   expansion which silently skips P01.5).
5. **`M035-VALIDATED` marker timing** — the marker is written by T06
   at the very end, AFTER `validate-milestone.sh M035` reports PASS.
   T06's `m035-p06-milestone-close-shape.sh` verifier must NOT
   require the marker as a prerequisite (chicken-and-egg) — instead
   it asserts the marker's *contents shape* (timestamp present) when
   present, and is invoked from the phase-suite aggregator AFTER the
   marker is written.
6. **Operator-only smokes deferred from P02/P03/P04** (MOS-3 brew tap
   smoke, MOS-4 first-release curl-pipe-bash smoke, MOS-5 synthetic-
   tag-push smoke) are NOT P06 deliverables — they fire at first-
   release time. The M035 acceptance battery treats them as
   `SKIP: deferred to first-release`. The M035-SUMMARY.md must
   surface this carve-out so launch-readiness reviewers don't expect
   live-channel evidence at milestone close.
