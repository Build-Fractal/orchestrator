---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M026"
goal: "Author the authoritative parity matrix M026-CONVERSUS-PARITY.md with the Verified: column fully populated from fs-inspection of both ~/Sites/conversus-oss and ~/Sites/conversus trees (FR-9 / SC-9); run the DC-6 synthesis-crux spike to determine whether OSS's red-blue synthesis phase produces (or can be made to produce) content parseable into the four adapter-expected linter.output_contract fields (verdict, disputes, rationale, source_hash); probe ollama availability on the operator machine (OQ-3 plan-phase validation); and emit a single GO/NO-GO spike-gate note that either unblocks P02 or halts M026 at the spike-gate per DC-6."
demo_sentence: "Operator reads .orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md (canonical copy at .orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md) and observes every row's Verified: column non-empty with one of {verified-identical, verified-drifted, verified-absent}; reads .orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md and observes a single Verdict: GO|NO-GO line plus a committed rationale; bash scripts/verify/m026-p01-phase-suite.sh exits 0 with SUMMARY: pass=N fail=0."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- Every Check uses single-script-file shape per AD-19.
     All verification logic lives in scripts/verify/m026-p01-*.sh.
     P01 is gate-only: it produces read-only artifacts (parity matrix, spike note,
     ollama-probe note) and a single GO/NO-GO verdict that gates P02. No adapter
     code changes land in P01 — CON-5 read-only-on-conversus-trees applies. -->

### Truths

- [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) exists with YAML frontmatter (`schema_version`, `type: parity-matrix`, `milestone: M026`, `phase: P01`, `created_at`, `status: final`) and four required markdown table columns (`Surface`, `OSS`, `Paid`, `Verified`). Every data row has a non-empty `Verified:` cell drawn from the fixed vocabulary `{verified-identical, verified-drifted, verified-absent, verified-moot}`. No row contains the literal string `VERIFY` (the scratch-matrix placeholder) in any cell.
  - Check: `bash scripts/verify/m026-p01-parity-matrix-shape.sh`

- The parity matrix body covers at minimum the 12 consumption-surface rows enumerated in `.orchestrator/scratch/conversus-oss-migration-parity.md` Section 2 (CLI shape, exit codes, `linter.output_contract` module importability + JSON schema, config schema, deliberation modes, OAuth login path, pipx venv path, upstream PR #28 status in OSS, upstream PR #29 status in OSS, prebuilt role presets, token/cost accounting, MCP adapter interface) plus the four dogfood-smoke drift rows folded in per M026-CONTEXT.md update-from-smoke-test section (top-level YAML contract, `agents[].role:` requirement in red-blue, `prompt:` vs `system_prompt:` field, top-level `output:` object-vs-string semantic collision). Each drift row carries `confirmed 2026-04-23` in its Notes cell rather than a re-run invocation.
  - Check: `bash scripts/verify/m026-p01-parity-matrix-coverage.sh`

- [`.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`](../../../../milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md) exists with YAML frontmatter (`type: spike-report`, `phase: P01`, `task: T02`, `status: final`) and body structure: (a) `## Method` naming the exact OSS commands invoked + files inspected under `~/Sites/conversus-oss/linter/output_contract.py` and `~/Sites/conversus-oss/engine/pipeline.py`; (b) `## Findings` enumerating whether `linter/output_contract.py` ships in the OSS tree, whether it exposes the JSON-key set `{quality_indicators.genuine_disagreements_surviving, headline, summary}` the adapter consumes at `scripts/dispatch/adapters/tool/conversus.sh:298`, and whether OSS red-blue's terminal phase output is parseable by that module; (c) `## Verdict` line matching exactly one of `Verdict: GO` or `Verdict: NO-GO` on a single line; (d) `## Rationale` containing at minimum one paragraph grounding the verdict in the findings.
  - Check: `bash scripts/verify/m026-p01-spike-note-shape.sh`

- If the spike verdict is `GO`, [`.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md`](../../../../milestones/M026/phases/P01/P01-SPIKE-GATE.md) contains a single `gate=GO` line (stdout-grep anchor for P02 plan-phase). If the verdict is `NO-GO`, the same file contains `gate=NO-GO` and an operator-visible `## Halt` section naming the scope-narrowing option (OQ-2 pointer) and the upstream-handoff option (spec 025 CONVERSUS-PR-HANDOFF.md pattern). The file is always present after T02; the verifier distinguishes shape from value, not the verdict itself.
  - Check: `bash scripts/verify/m026-p01-spike-gate-file.sh`

- [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md) exists with YAML frontmatter (`type: probe-report`, `phase: P01`, `task: T03`) and a body whose first non-heading line matches exactly one of `result=available`, `result=absent`, or `result=skipped-operator-choice`. When `result=available`, the file additionally records the resolved path (e.g., `ollama_path=/usr/local/bin/ollama`) and a `models_present=<comma-separated>` line. When `result=absent`, the file names `fallback=skip-on-429` as the FR-8 OSS-branch posture and records the explicit `known-upstream-429` annotation convention P02's FR-8 will use. This artifact is the operator-visible resolution of M026-CONTEXT.md OQ-3 follow-up for plan-phase.
  - Check: `bash scripts/verify/m026-p01-ollama-probe.sh`

- The pipx venv path for both editions has been inspected on the operator's machine and the parity matrix row for "pipx venv path assumption" names the exact OSS path (e.g., `~/.local/pipx/venvs/conversus-oss/bin/python` or whichever path exists) and the paid path (e.g., `~/.local/pipx/venvs/conversus/bin/python`). The matrix records which of the two is present today and which is absent; rows include both observations so P02's FR-8 edition-aware venv-python lookup extension has concrete data. This is the OQ-5 plan-phase resolution input.
  - Check: `bash scripts/verify/m026-p01-pipx-venv-inventory.sh`

- [`.orchestrator/milestones/M026/phases/P01/P01-SUMMARY.md`](../../../../milestones/M026/phases/P01/P01-SUMMARY.md) does NOT exist at end-of-T01-through-T04 (summary is written by `orchestrator:verify` at phase-close, not by plan-phase tasks). Conversely, once the summary lands, it MUST contain the spike verdict verbatim (`Verdict: GO` or `Verdict: NO-GO`) and a pointer to `M026-CONVERSUS-PARITY.md`. This truth is checked at phase-verify time, not at T04 close; P01-PLAN declares the shape so `orchestrator:verify` has a mechanical target.
  - Check: `bash scripts/verify/m026-p01-summary-shape-when-present.sh`

- No modifications were made to `~/Sites/conversus`, `~/Sites/conversus-oss`, or any file outside this repo during P01 execution. P01 is strictly read-only on the upstream conversus trees per CON-5. Concretely: no git commits under `~/Sites/conversus*`, no file writes under those trees, no `rm`/`mv` touching them.
  - Check: `bash scripts/verify/m026-p01-upstream-readonly.sh`

- Every new `.sh` file created in P01 passes Bash 3.2 compatibility (no `declare -A`, no `mapfile`/`readarray`, no process substitution `<(...)`/`>(...)`, no `&>`, no `${var^^}`/`${var,,}`) per CON-2. The gate self-excludes its own violation-pattern list via case-branch discipline (reuse M025/P01/T06 pattern).
  - Check: `bash scripts/verify/m026-p01-bash32-compat.sh`

- `CLAUDE.md` and `AGENTS.md` both have their `# >>> orchestrator:recent-changes >>>` region updated with a one-line M026/P01 close fragment via `scripts/util/dual-write-runtime-md.sh` (OQ-10 / CON-6 dual-write invariant). The fragment names the parity matrix completion and the spike verdict (not the spike mechanism).
  - Check: `bash scripts/verify/m026-p01-recent-changes.sh`

- `bash scripts/verify/m026-p01-phase-suite.sh` invokes all nine P01 gates in dependency order (parity-matrix-shape, parity-matrix-coverage, spike-note-shape, spike-gate-file, ollama-probe, pipx-venv-inventory, upstream-readonly, bash32-compat, recent-changes) and exits 0 iff every sub-gate passes. Emits `SUMMARY: m026-p01-phase-suite.sh pass=N fail=M` on a single line before exit.
  - Check: `bash scripts/verify/m026-p01-phase-suite.sh`

### Artifacts

- [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) (min 80 lines, contains "Verified:", contains "verified-identical", contains "schema_version") — create
- [`.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md`](../../../../milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md) (min 1 line, contains "M026-CONVERSUS-PARITY.md") — create (pointer file; the authoritative body lives at the milestone-level path)
- [`.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`](../../../../milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md) (min 50 lines, contains "Verdict:", contains "## Method", contains "## Findings", contains "## Rationale") — create
- [`.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md`](../../../../milestones/M026/phases/P01/P01-SPIKE-GATE.md) (min 1 line, contains "gate=") — create
- [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md) (min 10 lines, contains "result=", contains "type: probe-report") — create
- `scripts/verify/m026-p01-parity-matrix-shape.sh` (min 40 lines, contains "Verified", contains "verified-identical") — create
- `scripts/verify/m026-p01-parity-matrix-coverage.sh` (min 40 lines, contains "confirmed 2026-04-23", contains "agents") — create
- `scripts/verify/m026-p01-spike-note-shape.sh` (min 30 lines, contains "Verdict:", contains "## Method") — create
- `scripts/verify/m026-p01-spike-gate-file.sh` (min 20 lines, contains "gate=") — create
- `scripts/verify/m026-p01-ollama-probe.sh` (min 25 lines, contains "result=", contains "probe-report") — create
- `scripts/verify/m026-p01-pipx-venv-inventory.sh` (min 25 lines, contains "pipx/venvs") — create
- `scripts/verify/m026-p01-upstream-readonly.sh` (min 30 lines, contains "Sites/conversus") — create
- `scripts/verify/m026-p01-bash32-compat.sh` (min 40 lines, contains "declare -A") — create
- `scripts/verify/m026-p01-summary-shape-when-present.sh` (min 25 lines, contains "Verdict:") — create
- `scripts/verify/m026-p01-recent-changes.sh` (min 20 lines, contains "dual-write") — create
- `scripts/verify/m026-p01-phase-suite.sh` (min 40 lines, contains "SUMMARY:") — create
- `CLAUDE.md` (Recent Changes region) — modify-in-place via dual-write helper
- `AGENTS.md` (Recent Changes region) — modify-in-place via dual-write helper

### Key Links

- `specs/027-conversus-oss-migration/spec.md` → `.orchestrator/milestones/M026/phases/P01/P01-PLAN.md` (spec authoritatively drives this phase's scope)
- [`.orchestrator/milestones/M026/M026-CONTEXT.md`](../../../../milestones/M026/M026-CONTEXT.md) → [`.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`](../../../../milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md) (DC-6 synthesis-crux constraint originates the spike)
- `.orchestrator/scratch/conversus-oss-migration-parity.md` → [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) (seed matrix graduates to authoritative artifact)
- `specs/027-conversus-oss-migration/conversus/oss-early-review.md` → [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) (smoke-test confirmed drift rows fold in)
- `scripts/util/dual-write-runtime-md.sh` → `scripts/verify/m026-p01-recent-changes.sh` (verifier asserts dual-write outcome)

## Tasks

### T01: Parity matrix fs-inspection + authoritative artifact

See `tasks/T01-PLAN.md`.

### T02: Synthesis-crux spike + GO/NO-GO gate file

See `tasks/T02-PLAN.md`.

### T03: Ollama + pipx-venv environment probes

See `tasks/T03-PLAN.md`.

### T04: Phase-close gate suite + dual-write Recent Changes

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T04
T02 ──▶ T04
T03 ──▶ T04
```

T01, T02, T03 are independent of each other (T01 inspects the two trees' CLI + config
surfaces; T02 inspects the OSS synthesis + linter.output_contract surface; T03 probes
the operator's local machine for ollama + pipx). They can run in parallel. T04 closes
the phase by authoring the gate-suite scripts (which grep the outputs of T01/T02/T03),
running the dual-write Recent Changes fragment, and exiting on a green phase-suite.

Operator-visible halt: if T02's spike verdict is `NO-GO`, T04 still runs (it authors
the suite that proves the NO-GO state was captured authentically). P02 does not begin
— the spike-gate file's `gate=NO-GO` value blocks `orchestrator:plan-phase M026 P02`
via the P02-PLAN's explicit check for this file.

## Files Likely Touched

- [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) (create)
- [`.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md`](../../../../milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md) (create)
- [`.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`](../../../../milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md) (create)
- [`.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md`](../../../../milestones/M026/phases/P01/P01-SPIKE-GATE.md) (create)
- [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md) (create)
- `scripts/verify/m026-p01-parity-matrix-shape.sh` (create)
- `scripts/verify/m026-p01-parity-matrix-coverage.sh` (create)
- `scripts/verify/m026-p01-spike-note-shape.sh` (create)
- `scripts/verify/m026-p01-spike-gate-file.sh` (create)
- `scripts/verify/m026-p01-ollama-probe.sh` (create)
- `scripts/verify/m026-p01-pipx-venv-inventory.sh` (create)
- `scripts/verify/m026-p01-upstream-readonly.sh` (create)
- `scripts/verify/m026-p01-bash32-compat.sh` (create)
- `scripts/verify/m026-p01-summary-shape-when-present.sh` (create)
- `scripts/verify/m026-p01-recent-changes.sh` (create)
- `scripts/verify/m026-p01-phase-suite.sh` (create)
- `CLAUDE.md` (modify — Recent Changes region only)
- `AGENTS.md` (modify — Recent Changes region only)
