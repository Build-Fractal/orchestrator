---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M018"
provides:
  - "tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh — deterministic four-flag-honoring stub used as ORCH_TIER3_LLM_BIN; takes the operator-binary precedence path in scripts/dispatch/lib/tier3-llm-call.sh's provider-resolution ladder so the parity runner is hermetic across runtimes (no installed claude CLI is invoked); writes a deterministic envelope `<!-- compressed:tier3 model=stub-deterministic input_tokens=<N> output_tokens=42 -->\\nstub-deterministic-summary-body\\n` to --output where <N> is the byte size of --prompt-file; ORCH_TIER3_STUB_FAIL=1 flips to exit 1 (still records its invocation first) for FR-9 failure-passthrough exercise; per-fire side-effect appends one `<iso8601>\\t<runtime>` line to ORCH_TIER3_STUB_INVOCATIONS_LOG. tests/compression-runtime-parity/_stubs/README.md — stub documentation. scripts/diagnostics/m018-runtime-parity-tier3.sh — Tier 3 routing-parity driver; iterates runtimes ∈ {claude-code, codex, cursor} via the T01 helper, exports ORCH_BACKEND + ORCH_TIER3_LLM_BIN=<stub> + ORCH_TIER3_STUB_INVOCATIONS_LOG + ORCH_TIER3_STUB_FAIL, invokes scripts/dispatch/build-context.sh, asserts (success path) stub fired exactly once + post-pipeline payload contains the stub's deterministic marker + payload_breakdown JSONL carries tier3_invocations=1 + tier3_compression_savings_tokens > 0, asserts (--fail-stub) stub fired exactly once + dispatch survived (BC_RC=0) + JSONL carries tier3_failed reason=llm-call-nonzero; appends additive runtime_parity JSONL records to each staged execution-log.jsonl (CON-5); always exits 0 (FR-12 advisory pattern); snapshots project knowledge/ + KNOWLEDGE-INDEX.md before the first invocation and restores between every runtime run so build-context's increment-hits side-effect does not perturb cross-runtime equality."
requires:
  - "from:M018/P06/T01 what:_bc_apply_tier3 + scripts/dispatch/lib/tier3-llm-call.sh provider-resolution ladder honoring ORCH_TIER3_LLM_BIN at highest precedence with the four-flag operator-binary contract --prompt-file/--output/--max-tokens/--timeout; from:M018/P06/T02 what:_bc_emit_payload_breakdown emitter widened with tier3_invocations + tier3_compression_savings_tokens additive integer fields; from:M018/P07/T01 what:tests/compression-runtime-parity/fixtures/tier3-oversized-section/ corpus + scripts/verify/_helpers/m018-p07-build-fixture.sh staging helper"
affects:
  - "P07/T03 (canonical truth verifier scripts/verify/m018-p07-tier3-routing.sh exercises this runner end-to-end on both success and --fail-stub paths; m018-p07-zero-llm-parity.sh + runtime-assumptions-and-dual-write verifiers ship alongside; T03 also drafts the P07-SUMMARY.md and writes the references/RUNTIME-ASSUMPTIONS.md compression block + dual-write recent-changes entries)"
key_files:
  - "tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh;tests/compression-runtime-parity/_stubs/README.md;scripts/diagnostics/m018-runtime-parity-tier3.sh;.orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-SUMMARY.md"
key_decisions:
  - "Stub-fires-before-exit-1 invariant on the failure-passthrough path: ORCH_TIER3_STUB_FAIL=1 still appends its invocation line to ORCH_TIER3_STUB_INVOCATIONS_LOG before printing the stderr message and exiting 1, so the parity runner can prove the operator-binary call surface was reached even when the stub aborts. Without this, the runner could not distinguish 'stub never fired (routing broken)' from 'stub fired and failed as instructed' on the --fail-stub path. The runner asserts stub_invocations=1 on both paths. Runner does NOT pass INTENSITY_METADATA_FILE: T01's zero-LLM runner forces intensity=Quick to short-circuit T3; T02 does the inverse — the absent metadata file resolves to `standard` per kf_resolve_intensity which clears the FR-14 gate and lets T3 actually fire. The fixture's config.yml does not override compression.tier3.intensity_floor (default `standard`) so T3 is gated open. Knowledge-snapshot + restore pattern carried forward from T01 verbatim — proves runtime-parity asserts on byte-identical input state across the three runtime runs without requiring a build-context.sh PROJECT_ROOT plumbing change (out of T02 scope per CON-1 / Constitution VI). Operator-binary path chosen over claude-code-claude path because ORCH_TIER3_LLM_BIN takes highest precedence in tier3-llm-call.sh's provider ladder — proves the routing surface itself is runtime-agnostic (the env-var value is the only thing that cycles across the three runtime runs; the actual LLM-call binary is byte-identical per runtime). The runner emits `result=all-routed` on success path and `result=all-passthrough` on --fail-stub path with `regression_flag: none` on both — non-zero divergence surfaces via `regression_flag: divergence` (FR-12 always-exit-0 advisory pattern preserved)."
patterns_established:
  - "Hermetic-stub-via-operator-binary-path pattern: when a runtime-portability surface has a provider-resolution ladder, ship a deterministic stub that takes the highest-precedence path (here: ORCH_TIER3_LLM_BIN) so the parity assertion does not depend on any installed real provider. The stub honors the same flag contract the production ladder uses (here: --prompt-file/--output/--max-tokens/--timeout from tier3-llm-call.sh:80-86), so swapping ORCH_TIER3_LLM_BIN for a real binary at any time is a drop-in replacement. Stub-fires-before-exit-non-zero invariant: failure-mode stubs that exercise downstream failure-passthrough paths must record their invocation BEFORE returning non-zero, so the parity runner can disambiguate 'never reached' from 'reached and failed'. Runner-exports-env-vars-inline pattern: the runner exports ORCH_BACKEND / ORCH_TIER3_LLM_BIN / ORCH_TIER3_STUB_INVOCATIONS_LOG / ORCH_TIER3_STUB_FAIL inline on the same `bash $BUILD_CONTEXT ...` invocation rather than `export` + invoke pairs — single-script-file shape (AP-009 clean), no leak across iterations. Always-exit-0 advisory pattern carry-forward from T01: divergence surfaces via per-runtime line shape + `regression_flag: divergence` summary line, never via non-zero exit (FR-12 / CON-5)."
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-PAYLOAD.md;.orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-PLAN.md;.orchestrator/milestones/M018/phases/P07/P07-PLAN.md"
duration: "~30m"
verification_result: "pass"
completed_at: "2026-04-28T00:00:00Z"
---

T02 ships the **deterministic Tier 3 LLM stub** + the **Tier 3 routing-parity driver** that proves `_bc_apply_tier3` routes its LLM call through `scripts/dispatch/lib/tier3-llm-call.sh` correctly under every simulated runtime (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}). The stub takes the highest-precedence operator-binary path in the shim's provider-resolution ladder so the parity assertion is hermetic — no installed `claude` CLI is invoked. `--fail-stub` exercises the FR-9 failure-passthrough path: the stub records its invocation, exits 1, and the runner asserts the dispatch survived (build-context exit 0) plus the JSONL carries `tier3_failed reason=llm-call-nonzero`.

## Must-Haves

| # | Truth (from T02 plan + P07 plan slice) | Status | Evidence |
|---|----------------------------------------|--------|----------|
| 1 | `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` exists, executable, `bash -n` clean, ≥15 lines, contains `--output`. | PASS | 113 lines; executable; `bash -n` exit 0; `grep -c -- "--output"` = 3. |
| 2 | `tests/compression-runtime-parity/_stubs/README.md` exists. | PASS | Documents purpose, four-flag contract, ORCH_TIER3_STUB_FAIL=1 failure mode, invocation-counter side-effect, why operator-binary path. |
| 3 | `scripts/diagnostics/m018-runtime-parity-tier3.sh` exists, executable, `bash -n` clean, ≥50 lines, contains `ORCH_TIER3_LLM_BIN`. | PASS | 325 lines; executable; `bash -n` exit 0; `grep -c "ORCH_TIER3_LLM_BIN"` = 2. |
| 4 | Runner success path runs end-to-end: per-runtime `tier3-routing ... result=routed stub_invocations=1` lines + `tier3-routing-parity result=all-routed` + `regression_flag: none`; exits 0. | PASS | See "Verification output" — 3 runtimes × `result=routed`; final `regression_flag: none`. |
| 5 | Runner `--fail-stub` path exercises FR-9: per-runtime `stub_fail=1 stub_invocations=1 passthrough=ok bc_rc=0` + `tier3-routing-parity result=all-passthrough` + `regression_flag: none`; exits 0. | PASS | See "Verification output" — `tier3_failed reason=llm-call-nonzero` records present in each staged execution-log.jsonl; build-context survived on every runtime. |
| 6 | T02 task-local Check passes: `bash -n scripts/diagnostics/m018-runtime-parity-tier3.sh`. | PASS | exit 0. |

## Verification output

Success path — `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor`:

```
tier3-routing runtime=claude-code result=routed stub_invocations=1
tier3-routing runtime=codex result=routed stub_invocations=1
tier3-routing runtime=cursor result=routed stub_invocations=1
tier3-routing-parity result=all-routed
regression_flag: none
```

(exit 0)

Failure-passthrough path — `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor --fail-stub`:

```
tier3-routing runtime=claude-code stub_fail=1 stub_invocations=1 passthrough=ok bc_rc=0
tier3-routing runtime=codex stub_fail=1 stub_invocations=1 passthrough=ok bc_rc=0
tier3-routing runtime=cursor stub_fail=1 stub_invocations=1 passthrough=ok bc_rc=0
tier3-routing-parity result=all-passthrough
regression_flag: none
```

(exit 0)

T02 task-local Check — `bash -n scripts/diagnostics/m018-runtime-parity-tier3.sh` → exit 0.
Companion check — `bash -n tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` → exit 0.

## Files Created

- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` — deterministic stub honoring the four-flag operator-binary contract `--prompt-file / --output / --max-tokens / --timeout` from `scripts/dispatch/lib/tier3-llm-call.sh:80-86`. Writes a fixed `compressed:tier3 model=stub-deterministic` envelope; `ORCH_TIER3_STUB_FAIL=1` flips to exit 1 after recording the invocation. Bash 3.2; AP-009 / AD-19 clean.
- `tests/compression-runtime-parity/_stubs/README.md` — stub documentation.
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` — Tier 3 routing-parity driver. 325 lines; Bash 3.2; AP-009 / AD-19 clean. Always exits 0 (FR-12). Emits per-runtime `tier3-routing` lines, final `tier3-routing-parity result=...` line, and `regression_flag: <none|divergence>` for T03's verifier.
- `.orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-SUMMARY.md` (this file).

## Files Modified

None. T02 is purely additive — no production-code changes (CON-1 / Constitution VI). Pre-M018 sentinel byte-identity preserved. No CLAUDE.md / AGENTS.md edits in T02 scope (T03 ships the dual-write recent-changes entries).

## Deviations

None. The plan's pseudo-shape used flag names `--prompt-file/--output/--max-tokens/--timeout` for the stub which exactly match `tier3-llm-call.sh:80-86`'s operator-binary call surface — the stub is a direct contract match. The plan's `--max-output-tokens` / `--timeout-seconds` reference (in the prerequisites paragraph) describes the SHIM's caller-facing contract, not the operator-binary forwarded shape; the stub correctly implements the latter.

## Notes for T03

- `m018-p07-tier3-routing.sh` (T03's canonical truth verifier) should run BOTH the success path and the `--fail-stub` path of this runner and assert on the per-runtime line shape, the final `tier3-routing-parity result=` line, and the `regression_flag: none` line. The runner's stdout shape is stable across hosts because the runtime list flows through a temp file with deterministic ordering.
- The `runtime_parity` JSONL record_type is reused from T01's runner and remains additive (CON-5).
- No knowledge-state mutation persists past `restore_knowledge` between runtimes; the `git status --short knowledge/ KNOWLEDGE-INDEX.md` should be clean after the runner exits.
