---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M018"
goal: "Prove the zero-LLM tiers (filter, T1, T2) produce byte-identical compressed payloads across Claude Code, Codex CLI, and Cursor for a fixture corpus; prove Tier 3 routes through `dispatch-interface.sh` correctly under each runtime via a deterministic stub; record any unavoidable divergences in `references/RUNTIME-ASSUMPTIONS.md`."
demo_sentence: "Run `bash scripts/diagnostics/m018-runtime-parity.sh` against `tests/compression-runtime-parity/`; the report shows zero-LLM tier output SHA-256 byte-identical across CC / Codex CLI / Cursor simulated environments, T3 routes through `dispatch-interface.sh` under each runtime via the deterministic stub, and `references/RUNTIME-ASSUMPTIONS.md` carries a `compression` row per documented divergence."
risk: "low"
depends_on: ["P06"]
---

## Boundary Map

**Produces:**
- `tests/compression-runtime-parity/` fixture corpus tree — small payload-input fixtures covering the filter (US-2 — knowledge entries with mixed `status:` values), T1 (US-3 — oversized tool-result blocks for paging + cache reuse), and T2 (US-4 — oversized section bodies hitting head-drop with protected tail) tiers, plus a T3 fixture (US-5 — oversized post-T2 section that would route through `dispatch-interface.sh`).
- `scripts/diagnostics/m018-runtime-parity.sh` — single-driver parity runner. Invokes the bash pipeline (filter + T1 + T2) against each fixture under three simulated runtime environments (`ORCH_BACKEND=claude-code`, `ORCH_BACKEND=codex`, `ORCH_BACKEND=cursor`), computes SHA-256 over each compressed payload byte-stream, asserts equality across the three runtimes, and emits a `runtime-parity` JSONL row per fixture per runtime. Always exits 0 (FR-12 / CON-5 advisory pattern).
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` — Tier 3 routing parity driver. Wires a deterministic stub (`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`) as `ORCH_TIER3_LLM_BIN` for each runtime, invokes `_bc_apply_tier3` indirectly via `build-context.sh`, asserts the stub fired (single invocation per runtime; identical input prompt bytes; output captured to the prescribed path) under each of the three simulated runtimes.
- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` — deterministic four-flag-honoring binary that writes a fixed string to `--output` and exits 0. Used as `ORCH_TIER3_LLM_BIN` so T3's behavior is byte-deterministic across runtimes.
- `references/RUNTIME-ASSUMPTIONS.md` (create or extend) — registry document. P07 lands the `compression` block carrying a row per documented divergence (e.g., model name + pricing differences feeding Tier 3 cost estimates; `claude` CLI presence on PATH for the no-stub fallback). Rationale + M009 audit-row link per row.
- Three P07-private truth verifiers under `scripts/verify/m018-p07-*.sh`.
- One fixture-staging helper under `scripts/verify/_helpers/m018-p07-build-fixture.sh` (or reuse pattern from P06 helper).
- `P07-SUMMARY.md` (via `bash scripts/lifecycle/phase-transition.sh --write`).
- CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write for M018/P07.

**Consumes:**
- `scripts/dispatch/build-context.sh` (P02/P03/P04/P06) — the parity runner invokes this end-to-end. The bash-only tier helpers (`_bc_apply_filter` from P02, `_bc_apply_tier1` from P03, `_bc_apply_tier2` from P04) are the byte-equality surface.
- `scripts/dispatch/dispatch-interface.sh` (DEP-7) — Tier 3 parity runner asserts the helper routes summarization through this entry point under every runtime.
- `scripts/dispatch/lib/tier3-llm-call.sh` (P06/T01) — the operator-binary path (`ORCH_TIER3_LLM_BIN`) is the runtime-portable LLM invocation surface. P07 exercises it with a deterministic stub.
- `scripts/lib/knowledge-filter.sh` `kf_get_*` (P02/P03/P04/P06) — config accessors the parity runner overrides via `ORCHESTRATOR_ROOT` + a fixture `config.yml`.
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` (P06/T04) — fixture-staging helper shape T03's helper mirrors.
- `scripts/util/dual-write-runtime-md.sh` (existing) — for the `orchestrator:recent-changes` dual-write at phase close.
- `scripts/lifecycle/phase-transition.sh` (existing) — for atomic P07-SUMMARY + roadmap sync.

## Must-Haves

<!-- Every truth's Check is a single-script-file invocation per AD-19. The
     three canonical verifiers ship in T03; T01-T02 each carry a `bash -n`
     self-check as their task-local extractable Check (the auto-loop verify
     parser refuses zero-Check plans). -->

### Truths

- The bash-only tiers (filter + T1 + T2) produce byte-identical compressed payloads across the three simulated runtime environments (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}) for every fixture in `tests/compression-runtime-parity/`. SHA-256 over the post-T2 payload bytes is identical across runtimes per fixture.
  - Check: `bash scripts/verify/m018-p07-zero-llm-parity.sh`
- Tier 3 routes its LLM call through `scripts/dispatch/lib/tier3-llm-call.sh` (which fronts the runtime's resolution surface) under every simulated runtime; with `ORCH_TIER3_LLM_BIN` pointing at the deterministic stub, the helper invokes the stub once per fixture per runtime, the stub receives the rendered prompt-file bytes verbatim, and the captured output replaces the section in the payload. The dispatch pipeline never crashes when the stub exits 0; on stub-exit-1 the failure-passthrough emits `tier3_failed`.
  - Check: `bash scripts/verify/m018-p07-tier3-routing.sh`
- `references/RUNTIME-ASSUMPTIONS.md` exists and carries a `# Compression (M018)` block listing at least one documented divergence (model-pricing differences feeding `dispatch_usage.estimated_cost_usd`, OR `claude` CLI PATH presence for the no-stub fallback path) with rationale and an M009 audit-row reference. CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P07" and "runtime-parity".
  - Check: `bash scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh`

### Artifacts

- `scripts/diagnostics/m018-runtime-parity.sh` (min 60 lines, contains "ORCH_BACKEND")
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` (min 50 lines, contains "ORCH_TIER3_LLM_BIN")
- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` (min 15 lines, contains "--output")
- `tests/compression-runtime-parity/README.md` (min 20 lines, contains "byte-identical")
- `references/RUNTIME-ASSUMPTIONS.md` (min 15 lines, contains "Compression (M018)")
- `scripts/verify/m018-p07-zero-llm-parity.sh` (min 30 lines, contains "sha256")
- `scripts/verify/m018-p07-tier3-routing.sh` (min 30 lines, contains "tier3-stub-llm.sh")
- `scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh` (min 20 lines, contains "M018/P07")
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` (min 25 lines, contains "ORCHESTRATOR_ROOT")
- [`.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md`](../../../../milestones/M018/phases/P07/P07-SUMMARY.md) (min 50 lines, contains "runtime-parity")

### Key Links

- `scripts/diagnostics/m018-runtime-parity.sh` → `scripts/dispatch/build-context.sh` (parity runner invokes the canonical bash pipeline)
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` → `scripts/dispatch/lib/tier3-llm-call.sh` (Tier 3 parity runner overrides the LLM provider via the shim's operator-binary surface)
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` → `scripts/dispatch/dispatch-interface.sh` (Tier 3 parity runner asserts routing through the dispatch interface)
- `scripts/verify/m018-p07-zero-llm-parity.sh` → `scripts/diagnostics/m018-runtime-parity.sh` (verifier drives the runner)
- `scripts/verify/m018-p07-tier3-routing.sh` → `scripts/diagnostics/m018-runtime-parity-tier3.sh` (verifier drives the T3 runner)
- `references/RUNTIME-ASSUMPTIONS.md` → `scripts/dispatch/lib/tier3-llm-call.sh` (compression block names the LLM-call shim as the runtime-portable surface)
- `CLAUDE.md` → `m018-runtime-parity` (recent-changes dual-write names the new diagnostic)
- `AGENTS.md` → `m018-runtime-parity` (recent-changes dual-write names the new diagnostic)

## Tasks

### T01: Fixture corpus + zero-LLM parity runner (filter + T1 + T2 byte-equality across runtimes)

See [`.orchestrator/milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-PLAN.md`](../../../../milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-PLAN.md).

### T02: Tier 3 routing parity runner + deterministic LLM stub (T3 routes through dispatch-interface.sh under every runtime)

See [`.orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-PLAN.md`](../../../../milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-PLAN.md).

### T03: Verifiers + RUNTIME-ASSUMPTIONS.md compression block + P07-SUMMARY (via phase-transition.sh --write) + dual-write

See [`.orchestrator/milestones/M018/phases/P07/tasks/T03-verifiers-and-summary-PLAN.md`](../../../../milestones/M018/phases/P07/tasks/T03-verifiers-and-summary-PLAN.md).

## Task Dependencies

```
T01 ──┐
      ├─→ T03
T02 ──┘
```

- T01 (fixture corpus + zero-LLM parity runner) and T02 (Tier 3 routing parity + stub) are mechanically independent surfaces — T01 exercises bash-only tiers; T02 exercises the LLM-call shim. Either ordering works; the canonical execution order in this plan is T01 → T02 → T03 to mirror the P05/P06 ordering and to give T02 the fixture-staging helper shape T01 establishes.
- T03 (verifiers + RUNTIME-ASSUMPTIONS.md + summary + dual-write) depends on T01 + T02; the three-truth verifier fan-out exercises both prior tasks' surfaces.

## Files Likely Touched

- scripts/diagnostics/m018-runtime-parity.sh (create) — zero-LLM tier parity driver.
- scripts/diagnostics/m018-runtime-parity-tier3.sh (create) — T3 routing parity driver.
- tests/compression-runtime-parity/README.md (create) — corpus documentation.
- tests/compression-runtime-parity/fixtures/filter-mixed-status/ (create tree) — knowledge-entry fixtures with mixed `status:` values for filter parity.
- tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/ (create tree) — oversized tool-result inputs for T1 paging parity.
- tests/compression-runtime-parity/fixtures/tier2-oversized-section/ (create tree) — oversized section inputs for T2 head-drop parity.
- tests/compression-runtime-parity/fixtures/tier3-oversized-section/ (create tree) — oversized post-T2 section inputs for T3 routing parity.
- tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh (create) — deterministic stub honoring the four-flag tier3-llm-call.sh contract.
- tests/compression-runtime-parity/_stubs/README.md (create) — stub documentation.
- references/RUNTIME-ASSUMPTIONS.md (create or extend) — compression block.
- scripts/verify/m018-p07-zero-llm-parity.sh (create).
- scripts/verify/m018-p07-tier3-routing.sh (create).
- scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh (create).
- scripts/verify/_helpers/m018-p07-build-fixture.sh (create).
- .orchestrator/milestones/M018/phases/P07/_summary-body.txt (create) — narrative body for phase-transition.sh --write.
- [.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md](../../../../milestones/M018/phases/P07/P07-SUMMARY.md) (create) — written atomically by phase-transition.sh --write.
- CLAUDE.md (modify) — `orchestrator:recent-changes` block append.
- AGENTS.md (modify) — `orchestrator:recent-changes` block (dual-write mirror).

## Notes

- **AD-19 / AP-009 single-script-file Check shape**: every truth's Check is a single bash invocation. Verifier scripts use `pass()` / `fail()` per MEM002 and `printf 'PASS:' / 'FAIL:'` line-prefix convention per MEM001. The three canonical verifiers ship in T03; T01-T02 each carry a `bash -n` self-check as their task-local extractable Check (the auto-loop verify parser refuses zero-Check plans). No compound chains > 2 anywhere; no inline `$(...)` containing pipes; no plain subshells. Where the parity runner needs to compute SHA-256 over a generated payload, it writes the payload to a temp file first, then invokes `shasum -a 256 <file>` as a single command, then awk-reads the hash — no `$(... | ...)`.
- **Simulated-runtime model**: the three "runtimes" exercised here are simulated environments under a single bash process — distinct `ORCH_BACKEND` values plus per-runtime env-var overrides (model name, pricing knob). The bash-only tiers do not actually invoke the runtime — they are bash code. The byte-equality assertion is that the tier helpers ignore `ORCH_BACKEND` for filter / T1 / T2 outputs (consistent with their bash-only nature) and any divergence MUST be rooted out as a bug or documented in `references/RUNTIME-ASSUMPTIONS.md`. Per A-6 in the spec, multi-runtime work is the close-out audit, not an in-loop dispatch surface.
- **Tier 3 deterministic stub**: `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` honors the four-flag contract from `tier3-llm-call.sh` (`--prompt-file` / `--output` / `--max-tokens` / `--timeout`). It writes a fixed `<!-- compressed:tier3 model=stub-deterministic input_tokens=<N> output_tokens=<M> -->\n<deterministic summary body>` envelope to `--output` and exits 0. With `ORCH_TIER3_LLM_BIN=$PROJECT_ROOT/tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`, the operator-binary path in the shim takes precedence, every runtime's T3 invocation is byte-deterministic, and parity is provable. Stub exits 0 by default; an `ORCH_TIER3_STUB_FAIL=1` env-var flips it to exit 1 to exercise the FR-9 failure-passthrough branch.
- **CON-5 (additive emitters)**: T01 / T02 emit a new `runtime_parity` JSONL record_type to fixture-local execution-log.jsonl files for diagnostic readability. The record is additive — pre-M018 readers ignore unknown record_type values. No changes to existing record schemas (payload_breakdown / dispatch_usage / unit_close).
- **Constitution Principle VI byte-identity**: P07 does NOT modify any tier helper, emitter, or dispatch-interface code path. The phase is purely diagnostic — adds new files under `scripts/diagnostics/`, `scripts/verify/`, `tests/compression-runtime-parity/`, and `references/`. The pre-M018 sentinel (SC-8) byte-identity contract is preserved automatically because no code under test is touched.
- **AGENTS.md dual-write**: any CLAUDE.md edit MUST be followed by `bash scripts/util/dual-write-runtime-md.sh ...` so AGENTS.md mirrors the recent-changes block. T03 runs the dual-write helper as Step 11 (mirrors P06/T04 step 11). Never edit AGENTS.md directly.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand. Parallel scalars / indexed arrays only.
- **Hermetic fixtures**: every parity invocation uses `ORCHESTRATOR_ROOT=<staged-fixture-root>` to point production scripts at the fixture tree. The fixture-staging helper is the canonical entry point. Production scripts never write to the canonical `.orchestrator/` tree during P07 verification.
- **`phase-transition.sh --write` (NOT `write-summary.sh phase`)**: T03's closing step invokes `bash scripts/lifecycle/phase-transition.sh <milestone-dir> P07 --write --body-file=<path> --observability_surfaces=<text>` mirroring P06/T04. P05/T04 wrote the summary directly via `write-summary.sh phase` and triggered a `SYNC:MISMATCH`; P07 avoids the regression.
- **No conversus gate at P07** (per CON-6, only P01 grammar contract requires `--strict` conversus). RUNTIME-ASSUMPTIONS.md content is grammatical / structural (one row per divergence) and verified by the lint-shape verifier in T03; no subjective-quality review needed.
- **M009 launch-gate continuity**: `references/RUNTIME-ASSUMPTIONS.md` is consumed by M009's runtime-parity audit. P07 is M018's contribution — the compression block carries a row per divergence with a `m009_audit_row:` field that the M009 auditor reads. If P07 finds zero divergences (best case — bash-only tiers are perfectly portable), the block still exists and names the assertion that "no compression-tier divergences observed under the P07 corpus" so the auditor can confirm without re-running the analysis.
- **Risk classification — low**: P07 ships diagnostics only; no production code paths change. The downside if a verifier finds a divergence is documenting a row in RUNTIME-ASSUMPTIONS.md, not blocking the milestone. The phase closes cleanly even if every fixture's T3 stub exits 1 (failure-passthrough is the documented contract; the verifier asserts the dispatch survives).
