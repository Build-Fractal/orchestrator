---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M018"
name: "P07 verifiers (3) + RUNTIME-ASSUMPTIONS.md compression block + P07-SUMMARY (via phase-transition.sh --write) + CLAUDE.md / AGENTS.md orchestrator:recent-changes dual-write"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped:
  - `tests/compression-runtime-parity/` corpus tree with four fixtures (filter / tier1 / tier2 / tier3) and a README.
  - `scripts/diagnostics/m018-runtime-parity.sh` zero-LLM tier parity runner.
  - `scripts/verify/_helpers/m018-p07-build-fixture.sh` fixture-staging helper.
- T02 has shipped:
  - `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` deterministic stub.
  - `tests/compression-runtime-parity/_stubs/README.md`.
  - `scripts/diagnostics/m018-runtime-parity-tier3.sh` Tier 3 routing parity runner.
- The P06/T04 implementation is the canonical shape T03 mirrors. Re-read `.orchestrator/milestones/M018/phases/P06/tasks/T04-verifiers-and-summary-PLAN.md` for verifier-shape, `phase-transition.sh --write` invocation, and dual-write conventions before authoring.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper. It writes a `# >>> orchestrator:recent-changes >>>` block to both `CLAUDE.md` and `AGENTS.md`. Invocation pattern:

  ```bash
  bash scripts/util/dual-write-runtime-md.sh '<entry text>'
  ```

  (Confirm the actual flag set at integration time — P06 used `--marker recent-changes --append-entry` per the PAYLOAD note, but the bare-arg form may also work; T03 author reads the helper's `--help` once.)
- `scripts/lifecycle/phase-transition.sh` is the canonical phase-summary writer for P07. **CRITICAL**: T03 invokes `phase-transition.sh --write` (NOT `write-summary.sh phase` directly). P05/T04 wrote the summary directly via `write-summary.sh phase` and triggered a `SYNC:MISMATCH`; P06 / P07 avoid the regression by using the atomic transition helper.
- `references/RUNTIME-ASSUMPTIONS.md` does NOT yet exist (per `ls references/` at planning time; T03 creates it). If a future phase landed it first, T03 appends; the verifier checks for the `# Compression (M018)` block specifically.
- AD-19 single-script-file Check shape: every verifier exposes its truth via a single bash invocation. Verifiers internally use `pass()` / `fail()` per MEM002 and `printf 'PASS:' / 'FAIL:'` line-prefix per MEM001.
- AP-009: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells. Bash 3.2.

## Description

T03 ships:

1. **Three verifier scripts** under `scripts/verify/m018-p07-*.sh` (one per mechanical truth in P07-PLAN.md):
   - `m018-p07-zero-llm-parity.sh` — Truth #1 (filter + T1 + T2 byte-equality across runtimes).
   - `m018-p07-tier3-routing.sh` — Truth #2 (T3 routes through `tier3-llm-call.sh` + dispatch-interface; failure-passthrough on stub-fail).
   - `m018-p07-runtime-assumptions-and-dual-write.sh` — Truth #3 (RUNTIME-ASSUMPTIONS.md compression block + CLAUDE.md / AGENTS.md recent-changes).
2. **`references/RUNTIME-ASSUMPTIONS.md`** — registry document. P07 lands the `# Compression (M018)` block carrying at least one row per documented divergence (or an explicit "no divergences observed" row), each with rationale and an M009 audit-row link field.
3. **`P07-SUMMARY.md`** via `bash scripts/lifecycle/phase-transition.sh --write`.
4. **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write** for M018/P07.

T03 does NOT ship:

- T01's corpus / parity runner / staging helper.
- T02's stub or Tier 3 routing runner.

## Inputs

### From Previous Tasks

- `scripts/diagnostics/m018-runtime-parity.sh` (from T01) — zero-LLM parity runner. T03 verifier #1 invokes it and asserts on its stdout.
  - Key API: `bash scripts/diagnostics/m018-runtime-parity.sh --fixture <name|all> --runtimes <csv>` → prints `runtime-parity` lines, `parity result=match|divergence` lines, and a final `regression_flag: <none|divergence>` line. Always exits 0.
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` (from T02) — Tier 3 routing runner.
  - Key API: `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes <csv> [--fail-stub]` → prints per-runtime routing lines and a final `regression_flag:` line. Always exits 0.
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` (from T01) — fixture-staging helper. T03 verifiers may invoke it via the runners they drive.
- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` (from T02) — referenced by the routing verifier as the LLM provider for hermetic T3 invocations.

### From Disk (Pre-existing)

- `scripts/verify/m018-p06-dual-write-recent.sh` — T03's dual-write verifier mirrors this exactly (substituting `M018/P06` → `M018/P07`).
- `scripts/verify/m018-p06-tier3-helper-shape.sh` etc. — read for the canonical verifier shape (pass()/fail() helpers, hermetic root staging via `ORCHESTRATOR_ROOT`, single-script-file Check shape).
- `scripts/util/dual-write-runtime-md.sh` — read for the recent-changes block shape.
- `scripts/lifecycle/phase-transition.sh` — read for `--write` invocation surface; the canonical body-file pattern is `.orchestrator/milestones/M018/phases/P07/_summary-body.txt`.
- `references/` directory — confirm RUNTIME-ASSUMPTIONS.md does not yet exist.

## Steps

### Step 1 — Author `references/RUNTIME-ASSUMPTIONS.md`

Create the file (or append if a prior phase already created it). Structure:

```markdown
# Runtime Assumptions

This document records cross-runtime divergences and assumptions consumed
by the M009 launch-gate runtime-parity audit. Each block names a
milestone-scoped origin; each row inside a block names one divergence
with rationale and an M009 audit-row link.

## Compression (M018)

P07 (multi-runtime parity audit) exercised the M018 compression
pipeline under three simulated runtime environments — `claude-code`,
`codex`, `cursor` — against the fixture corpus at
`tests/compression-runtime-parity/`.

### Divergences

| ID | Surface | Divergence | Rationale | M009 Audit Row |
|----|---------|------------|-----------|-----------------|
| RA-M018-01 | Tier 3 model name + pricing | Each runtime's native model is invoked by `dispatch-interface.sh` for production T3 calls; pricing fields in `dispatch_usage.estimated_cost_usd` differ accordingly. | Per CON-3 / FR-13: T3 routes through `tier3-llm-call.sh` so each runtime calls its native model; the in-band marker schema is normalized but the model name + cost vary by runtime. | M009-RP-01 (compression-tier-3-pricing) |
| RA-M018-02 | `claude` CLI presence on PATH | `tier3-llm-call.sh`'s second-priority provider path requires the `claude` CLI on PATH when `ORCH_BACKEND=claude-code` and `ORCH_TIER3_LLM_BIN` is unset; absent that, the shim exits 1 and FR-9 failure-passthrough fires. | Operator-environment dependency outside the orchestrator's control; documented so M009 auditors can confirm the failure-passthrough path is operational under each runtime's expected install posture. | M009-RP-02 (claude-cli-path-presence) |

### Bash-only tier parity (filter + T1 + T2)

P07's parity runner asserts SHA-256 byte-equality of post-pipeline
payload bytes across `ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}
for every fixture in the corpus. As of P07 close, no divergence was
observed — the bash-only tiers ignore `ORCH_BACKEND` (consistent with
their bash-only nature). Any future divergence should land here as a
new RA-M018-NN row.
```

If the parity runner found a divergence at T01/T02 close, T03 author adds a row naming the fixture, the divergent runtime, the SHA-256 mismatch, and the rationale.

Min 15 lines; must contain the literal substring `Compression (M018)`.

### Step 2 — Author `scripts/verify/m018-p07-zero-llm-parity.sh` (Truth #1)

Single bash file. AD-19. Asserts:

1. `scripts/diagnostics/m018-runtime-parity.sh` exists and is `bash -n` clean.
2. Running `bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all` exits 0 (advisory pattern always-exit-0).
3. The runner's stdout contains a `runtime-parity fixture=<name> runtime=<runtime> sha256=<hash>` line for every (fixture, runtime) pair in the corpus excluding `tier3-oversized-section`.
4. The runner's stdout contains a `parity fixture=<name> result=match runtimes=3` line for every non-T3 fixture (filter / tier1 / tier2).
5. The final line contains `regression_flag: none` (no divergence observed). If divergence is observed (intentionally documented in RUNTIME-ASSUMPTIONS.md as a known divergence), the verifier accepts `regression_flag: divergence` AND requires the corresponding RA-M018-NN row to exist in `references/RUNTIME-ASSUMPTIONS.md` — this is the "documented divergence" carve-out.

Use `pass()` / `fail()` per MEM002. Capture the runner's stdout to a temp file (`bash scripts/diagnostics/m018-runtime-parity.sh ... > "$TMPOUT" 2>&1` — this is single-redirect, not compound), then grep for the assertions.

Min 30 lines; must contain the literal substring `sha256`.

### Step 3 — Author `scripts/verify/m018-p07-tier3-routing.sh` (Truth #2)

Single bash file. AD-19. Asserts:

1. `scripts/diagnostics/m018-runtime-parity-tier3.sh` exists and is `bash -n` clean.
2. `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` exists and is executable (`-x`).
3. Running `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor` exits 0.
4. The stdout contains `tier3-routing runtime=<r> result=routed stub_invocations=1` for each of the three runtimes.
5. The stdout's final summary contains `tier3-routing-parity result=all-routed` and `regression_flag: none` (or, if divergence is documented, `regression_flag: divergence` AND the corresponding RA-M018-NN row exists).
6. Running `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor --fail-stub` exits 0 (FR-9 failure-passthrough preserved).
7. The fail-stub stdout contains `tier3-routing runtime=<r> stub_fail=1 passthrough=ok` for each runtime.

Min 30 lines; must contain the literal substring `tier3-stub-llm.sh`.

### Step 4 — Author `scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh` (Truth #3)

Single bash file. AD-19. Asserts:

1. `references/RUNTIME-ASSUMPTIONS.md` exists.
2. The file contains the literal substring `# Compression (M018)`.
3. The file contains at least one `RA-M018-` row OR an explicit "no divergences observed" line in the Bash-only tier parity block.
4. `CLAUDE.md` contains a `# >>> orchestrator:recent-changes >>>` block.
5. `AGENTS.md` contains a `# >>> orchestrator:recent-changes >>>` block.
6. Both blocks contain the literal substring `M018/P07`.
7. Both blocks contain the literal substring `runtime-parity`.

Mirrors `m018-p06-dual-write-recent.sh` exactly (substituting `M018/P06` → `M018/P07` and adding the RUNTIME-ASSUMPTIONS.md assertions).

Min 20 lines; must contain the literal substring `M018/P07`.

### Step 5 — Run all three verifiers; iterate until green

```bash
bash scripts/verify/m018-p07-zero-llm-parity.sh
bash scripts/verify/m018-p07-tier3-routing.sh
bash scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh
```

Each verifier must exit 0 and emit `PASS:` lines per assertion. Failures emit `FAIL:` with a message naming the file/line/value mismatch. (The dual-write verifier won't pass until Step 7 lands the dual-write block.)

### Step 6 — Author `_summary-body.txt` for `phase-transition.sh --write`

Write the P07-SUMMARY narrative body to `.orchestrator/milestones/M018/phases/P07/_summary-body.txt`. Mirror the P06-SUMMARY narrative shape (`## Risk-mitigation traceability`, `## Followups for downstream phases`, `## Verification result` sections). Name what P07 ships:

- `tests/compression-runtime-parity/` fixture corpus (filter / tier1 / tier2 / tier3) — byte-equality proof corpus.
- `scripts/diagnostics/m018-runtime-parity.sh` — zero-LLM tier parity runner across CC / Codex CLI / Cursor.
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` — Tier 3 routing parity runner with deterministic stub.
- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` — deterministic four-flag stub for hermetic T3 invocations.
- `references/RUNTIME-ASSUMPTIONS.md` — `# Compression (M018)` block with N divergence rows + M009 audit-row links.
- Three P07-private truth verifiers under `scripts/verify/m018-p07-*.sh`.
- One fixture-staging helper under `scripts/verify/_helpers/m018-p07-build-fixture.sh`.
- CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write.

Document the byte-equality result: `regression_flag: none` (or, if divergence: name the fixture and the corresponding RA-M018-NN row).

Document the M009 launch-gate handoff: `references/RUNTIME-ASSUMPTIONS.md` is the consumption surface; M009's runtime-parity audit reads the rows and confirms each divergence has a rationale + audit-row link.

### Step 7 — Dual-write the `orchestrator:recent-changes` block

```bash
bash scripts/util/dual-write-runtime-md.sh '030-context-compression-layer / M018/P07: multi-runtime parity audit complete; tests/compression-runtime-parity/ corpus + scripts/diagnostics/m018-runtime-parity.sh proves zero-LLM tier byte-equality across CC / Codex CLI / Cursor (filter+T1+T2 SHA-256 identical per fixture); scripts/diagnostics/m018-runtime-parity-tier3.sh + tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh proves T3 routes through tier3-llm-call.sh under every runtime with FR-9 failure-passthrough preserved; references/RUNTIME-ASSUMPTIONS.md compression block carries divergence rows + M009 audit-row links.'
```

(Confirm the helper's actual flag surface at integration time — if it requires `--marker recent-changes --append-entry` per the P06 pattern, adapt accordingly.)

Re-run `bash scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh` and confirm PASS.

### Step 8 — Run `phase-transition.sh --write` to atomically write P07-SUMMARY.md + sync roadmap

```bash
bash scripts/lifecycle/phase-transition.sh \
  .orchestrator/milestones/M018 P07 \
  --write \
  --body-file=.orchestrator/milestones/M018/phases/P07/_summary-body.txt \
  --observability_surfaces='scripts/diagnostics/m018-runtime-parity.sh stdout: per-fixture per-runtime SHA-256 lines + parity match summary + regression_flag advisory; scripts/diagnostics/m018-runtime-parity-tier3.sh stdout: per-runtime routing lines + tier3-routing-parity summary + regression_flag advisory; runtime_parity JSONL record_type appended to fixture-local execution-log.jsonl (additive); references/RUNTIME-ASSUMPTIONS.md: # Compression (M018) block with RA-M018-NN divergence rows.' \
  --verification_result=pass
```

Expected: `phase-transition.sh` reads all three task summaries, derives `provides` / `requires` / `affects` / etc. fields automatically, syncs the roadmap, writes `P07-SUMMARY.md` atomically, and emits a `TRANSITION:READY phase=P07 fields_derived=N` status line. No `SYNC:MISMATCH`.

### Step 9 — Run `check-must-haves.sh` against the phase

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P07/
```

Expected: every truth Check passes; every artifact line-count + substring matches; every key-link resolves.

## Verification

T03's task-local extractable Check is the syntax-only self-check on the closing-task verifier:

- Check: `bash -n scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh`

(One Check per task per the auto-loop verify parser. The three canonical truth verifiers are themselves the phase-level Checks; T03's task-local Check is on the dual-write verifier, which is the truth most tightly tied to T03 itself.)

## Must-Haves (subset addressed by this task)

- **Truth #1** (zero-LLM tier byte-equality): T03 ships the verifier that drives T01's runner end-to-end and asserts on its output. The underlying parity proof ships in T01.
- **Truth #2** (Tier 3 routing parity + failure-passthrough): T03 ships the verifier that drives T02's runner. The underlying routing proof ships in T02.
- **Truth #3** (RUNTIME-ASSUMPTIONS.md compression block + CLAUDE.md / AGENTS.md recent-changes): wholly addressed by Steps 1, 4, 7 of this task.

## Constraints

- **AD-19 / AP-009**: every truth's Check is a single bash file. Verifiers internally use `pass()` / `fail()` per MEM002. No compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution.
- **CON-1 / Constitution Principle VI**: T03 modifies CLAUDE.md (recent-changes block) and AGENTS.md (via dual-write). Any other production code is untouched. Pre-M018 sentinel byte-identity preserved.
- **CON-5 (additive emitters)**: no emitter schema changes in T03. The `runtime_parity` JSONL record_type added in T01/T02 is additive; T03's verifier reads it but does not change it.
- **AGENTS.md dual-write**: the recent-changes block lands in CLAUDE.md AND AGENTS.md via `scripts/util/dual-write-runtime-md.sh` — never edit AGENTS.md directly.
- **Bash 3.2** (MEM001): no `declare -A`. Verifiers use parallel indexed arrays + `pass() / fail()` per MEM002.
- **`phase-transition.sh --write` (NOT `write-summary.sh phase`)**: load-bearing convention. The lifecycle helper handles roadmap sync atomically; direct `write-summary.sh phase` triggers `SYNC:MISMATCH`.

## Notes

- **Three truths, three verifiers**: P07's surface is narrower than P05/P06 because the phase ships only diagnostic surfaces and a registry document — no production code paths change. The three-truth split is:
  1. zero-LLM parity (T01),
  2. T3 routing + failure-passthrough (T02),
  3. RUNTIME-ASSUMPTIONS.md + dual-write (T03).
- **Documented-divergence carve-out**: the verifiers accept `regression_flag: divergence` IF the corresponding `RA-M018-NN` row exists in `references/RUNTIME-ASSUMPTIONS.md`. This honors the spec's framing — divergences are documented, not suppressed; the verifier asserts the documentation discipline.
- **Best-case zero-divergence path**: on a clean checkout, the bash-only tiers ARE byte-identical across runtimes (they're bash code that ignores `ORCH_BACKEND`). The `# Compression (M018)` block still names the divergences that DO exist by design (Tier 3 model name + pricing per runtime; `claude` CLI PATH presence) — these are never resolved away because they're inherent to the multi-runtime model.
- **M009 launch-gate handoff**: `references/RUNTIME-ASSUMPTIONS.md`'s `M009 Audit Row` column is consumed downstream. P07 names placeholders (`M009-RP-01`, `M009-RP-02`); M009 will assign real audit-row IDs at audit time. The verifier asserts the column header exists, not specific row IDs.
- **Hermetic verification**: every verifier uses `ORCHESTRATOR_ROOT=<staged-root>` indirectly via the runners they drive. Verifiers themselves do not write to the canonical `.orchestrator/` tree.
- **No conversus gate at P07**: per CON-6, only P01 grammar contract requires `--strict` conversus. RUNTIME-ASSUMPTIONS.md content is grammatical / structural (one row per divergence) and verified by the lint-shape verifier in Step 4; no subjective-quality review needed.

## Expected Output

After T03 lands:

- `references/RUNTIME-ASSUMPTIONS.md` exists with a `# Compression (M018)` block.
- `scripts/verify/m018-p07-zero-llm-parity.sh`, `m018-p07-tier3-routing.sh`, `m018-p07-runtime-assumptions-and-dual-write.sh` exist; each `bash -n` clean; each exits 0 against the live corpus + runners.
- `CLAUDE.md` and `AGENTS.md` carry an `orchestrator:recent-changes` block naming `M018/P07` and `runtime-parity`.
- `.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md` exists, written atomically by `phase-transition.sh --write`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P07/` exits 0; every truth Check passes; every artifact + key link resolves.
- The phase state advances to a state where `bash scripts/state/derive-phase.sh .orchestrator/milestones/M018` reports the next-phase posture (M018 either complete or advancing per the roadmap; P07 is the last phase per the dependency graph, so M018 transitions to milestone-complete posture pending consolidation).
