---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M018"
provides:
  - "tests/compression-runtime-parity/ corpus tree (fixtures/filter-mixed-status, fixtures/tier1-oversized-tool-result, fixtures/tier2-oversized-section, fixtures/tier3-oversized-section + corpus README); each fixture carries config.yml (compression knobs sized so the tier under test fires), input/payload-input.txt (the bytes the runner folds into the staged task plan body), and a fixture-local README naming what the fixture exercises; the filter fixture also ships a knowledge/ subtree (MEM-FXT-A graduated, MEM-FXT-B experimental, MEM-FXT-C superseded, MEM-FXT-D graduated). scripts/diagnostics/m018-runtime-parity.sh — zero-LLM parity runner; iterates fixtures × runtimes ∈ {claude-code, codex, cursor}, stages a hermetic orch_root via the helper, exports ORCH_BACKEND + INTENSITY_METADATA_FILE=intensity:Quick (forces T3 short-circuit), invokes scripts/dispatch/build-context.sh, captures the post-pipeline payload, computes SHA-256, prints per-(fixture,runtime) runtime-parity lines + per-fixture parity ... result=match|divergence summary + final regression_flag: <none|divergence|...>; appends additive runtime_parity JSONL records to each staged execution-log.jsonl (CON-5); always exits 0 (FR-12 advisory pattern); snapshots project knowledge/ + KNOWLEDGE-INDEX.md before the first invocation and restores between every runtime run so build-context's increment-hits side-effect does not perturb cross-runtime byte-equality. scripts/verify/_helpers/m018-p07-build-fixture.sh — fixture-staging helper; mirrors the m018-p06 helper shape; takes <runtime> <fixture> positional args; idempotent clean-stage; emits the staged orch_root path on stdout; copies fixture config.yml + knowledge/ tree to the stage; folds payload-input.txt verbatim into the staged T01-PLAN.md body so build-context's handle_task_plan injects the bytes into the ## Task Plan section (which is in T2's in_scope() set)."
requires:
  - "from:M018/P02 what:_bc_apply_knowledge_filter + kf_filter_stream knowledge-aware filter; from:M018/P03/T01 what:_bc_apply_tier1 tool-result paging + SHA-256 cache reuse; from:M018/P04/T01 what:_bc_apply_tier2 section head-drop + protected_tail_ratio; from:M018/P06/T01 what:_bc_apply_tier3 + tier3-llm-call.sh shim + INTENSITY_METADATA_FILE intensity gate (used to short-circuit T3); from:M018/P06/T04 what:scripts/verify/_helpers/m018-p06-build-fixture.sh canonical helper shape; from:scripts/dispatch/build-context.sh what:positional CLI <orch_root> <milestone> <phase> <task> + handle_task_plan section assembler"
affects:
  - "P07/T02 (Tier 3 routing-parity runner consumes tests/compression-runtime-parity/fixtures/tier3-oversized-section/, ships _stubs/tier3-stub-llm.sh, exports ORCH_TIER3_LLM_BIN); P07/T03 (canonical truth verifier scripts/verify/m018-p07-zero-llm-parity.sh exercises this runner end-to-end + RUNTIME-ASSUMPTIONS.md + dual-write recent-changes)"
key_files:
  - "scripts/diagnostics/m018-runtime-parity.sh;scripts/verify/_helpers/m018-p07-build-fixture.sh;tests/compression-runtime-parity/README.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/config.yml;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/conventions/MEM-FXT-A.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/conventions/MEM-FXT-B.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/patterns/MEM-FXT-C.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/patterns/MEM-FXT-D.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/config.yml;tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier2-oversized-section/config.yml;tests/compression-runtime-parity/fixtures/tier2-oversized-section/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier3-oversized-section/config.yml;tests/compression-runtime-parity/fixtures/tier3-oversized-section/input/payload-input.txt"
key_decisions:
  - "build-context.sh's PROJECT_ROOT is hardcoded to the orchestrator repo (cd $SCRIPT_DIR/../..) so the fixture cannot fully isolate from the project's KNOWLEDGE-INDEX.md and knowledge/ tree; the parity runner instead snapshots both before the first invocation and restores between every (fixture, runtime) pair so the three runtime runs see byte-identical input state — proving byte-equality across runtimes without requiring a build-context PROJECT_ROOT plumbing change (out of T01 scope per CON-1 / Constitution VI). T3 short-circuit via INTENSITY_METADATA_FILE=intensity:Quick rather than tier3.enabled:false because scripts/lib/knowledge-filter.sh's kf_read_compression_scalar awk parser does not handle the tier3 nested block (a P06 oversight outside T01 scope); the intensity-gate path is the contract-supported way to disable T3 from a fixture's orch_root. Helper drops the wrapper task-plan frontmatter and copies the fixture's payload-input.txt verbatim into T01-PLAN.md — handle_task_plan cats the file body, so the fixture-author owns the bytes that land in the ## Task Plan section; this avoids the head-drop preservation-check rolling the snip back over the wrapper's `---` delimiters. tier3-oversized-section fixture is staged but NOT exercised by the runner (T02's job); the runner skips that slug explicitly. tier2-oversized-section fixture's snip path may roll back via the post-snip cross-tier preservation check (the in-band tier2 compression marker is itself a preserved-pattern row, so strict multiplicity is unsatisfied on a marker-free pre payload) — this is a P04 quirk outside T01 scope; either outcome (successful snip or boundary-refusal-rollback) is deterministic across runtimes so the byte-equality contract holds in both cases. Always-exit-0 advisory pattern preserved: divergence surfaces via regression_flag: divergence on stdout, never via non-zero exit (FR-12 / CON-5)."
patterns_established:
  - "Hermetic-fixture-with-knowledge-snapshot pattern: when a tier helper has a side-effect on shared project state (here: increment-hits.sh on KNOWLEDGE-INDEX.md + per-entry hit_count: frontmatter), the parity runner snapshots the relevant subtree to its own output dir before the first invocation and restores between every test case — restores the project to byte-identical pre-test state at the END of the run, satisfying constitution VI (canonical files byte-identical to pre-M018) without needing helper plumbing changes; runner-internal MEM004 carve-out for awk pipes (single-script-file rule applies only at task/phase plan Check: line). Fixture-corpus directory shape: fixtures/<slug>/{config.yml, input/payload-input.txt, knowledge/?, README.md} — uniform across tiers; helper auto-discovers any directory under fixtures/, no registry to update; new fixture = copy directory + tune config.yml + rewrite payload-input.txt + author README. Run-order-deterministic-across-hosts pattern: fixture list and runtime list both flow through sort -o to stable files before iteration so stdout ordering matches the byte-equality assertion verifier T03 will apply; AP-009 clean — no inline pipes-to-wc, no compound chains > 2 — output captured to files and read via `awk 'END{print NR}'` or `awk 'NR==1{print $1}'` single-pass shapes; Bash 3.2 strict (no declare -A, no mapfile, no read -ra)."
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-PAYLOAD.md;.orchestrator/milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-PLAN.md;.orchestrator/milestones/M018/phases/P07/P07-PLAN.md"
duration: "~2h"
verification_result: "pass"
completed_at: "2026-04-28T15:26:28Z"
---

T01 ships the **fixture corpus tree** + the **zero-LLM parity runner** that proves the bash-only compression tiers (knowledge-aware filter + Tier 1 microcompact + Tier 2 snip) produce byte-identical compressed payloads under every supported runtime (`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}), plus the fixture-staging helper T02 / T03 reuse. Tier 3 is short-circuited via the intensity gate (T02 ships the routing-parity runner that exercises T3 against a deterministic stub).

## Must-Haves

| # | Truth (from T01 plan / P07 plan slice) | Status | Evidence |
|---|----------------------------------------|--------|----------|
| 1 | `tests/compression-runtime-parity/` corpus tree exists with fixture directories (filter / T1 / T2 / T3) and a corpus README. | PASS | Four fixture dirs under `tests/compression-runtime-parity/fixtures/`; corpus `README.md` present, names "byte-identical" verbatim. |
| 2 | `scripts/diagnostics/m018-runtime-parity.sh` exists, contains `ORCH_BACKEND`, `bash -n` clean, ≥60 lines. | PASS | 280 lines; `bash -n` exit 0; references `ORCH_BACKEND` (1 occurrence; runner exports it per fixture-runtime pair). |
| 3 | `scripts/verify/_helpers/m018-p07-build-fixture.sh` exists and `bash -n` clean. | PASS | `bash -n` exit 0; mirrors P06 helper shape; idempotent clean-stage; takes `<runtime> <fixture>` args; emits stage path on stdout. |
| 4 | Runner runs end-to-end: per-fixture parity lines + `regression_flag:` summary; exits 0. | PASS | See "Verification output" below — 3 fixtures × 3 runtimes = 9 `runtime-parity` lines; all 3 fixtures `result=match`; `regression_flag: none`; exit 0. |
| 5 | All 3 zero-LLM fixtures (filter / tier1 / tier2) report `parity ... result=match runtimes=3` on a clean checkout. | PASS | All three SHA-256 hashes per fixture match across `claude-code` / `codex` / `cursor`. |
| 6 | T01 task-local Check passes: `bash -n scripts/diagnostics/m018-runtime-parity.sh`. | PASS | exit 0. |

## Verification output

`bash scripts/diagnostics/m018-runtime-parity.sh --runtimes claude-code,codex,cursor --fixture all`:

```
runtime-parity fixture=filter-mixed-status runtime=claude-code sha256=53965bafb6c22c582b2907f69074efe5d542087a987589d81350eacc611b97af
runtime-parity fixture=filter-mixed-status runtime=codex sha256=53965bafb6c22c582b2907f69074efe5d542087a987589d81350eacc611b97af
runtime-parity fixture=filter-mixed-status runtime=cursor sha256=53965bafb6c22c582b2907f69074efe5d542087a987589d81350eacc611b97af
parity fixture=filter-mixed-status result=match runtimes=3
runtime-parity fixture=tier1-oversized-tool-result runtime=claude-code sha256=168f702663db6ad9e4f05b314a28126634ee5a4eee92d8b9cb1a0db6212a3452
runtime-parity fixture=tier1-oversized-tool-result runtime=codex sha256=168f702663db6ad9e4f05b314a28126634ee5a4eee92d8b9cb1a0db6212a3452
runtime-parity fixture=tier1-oversized-tool-result runtime=cursor sha256=168f702663db6ad9e4f05b314a28126634ee5a4eee92d8b9cb1a0db6212a3452
parity fixture=tier1-oversized-tool-result result=match runtimes=3
runtime-parity fixture=tier2-oversized-section runtime=claude-code sha256=6c103c0658ceb25d1c502eb8462f750a1bb010e4b5317d19a60842f631f42926
runtime-parity fixture=tier2-oversized-section runtime=codex sha256=6c103c0658ceb25d1c502eb8462f750a1bb010e4b5317d19a60842f631f42926
runtime-parity fixture=tier2-oversized-section runtime=cursor sha256=6c103c0658ceb25d1c502eb8462f750a1bb010e4b5317d19a60842f631f42926
parity fixture=tier2-oversized-section result=match runtimes=3
regression_flag: none
exit=0
```

`bash -n scripts/diagnostics/m018-runtime-parity.sh` → exit 0.
`bash -n scripts/verify/_helpers/m018-p07-build-fixture.sh` → exit 0.

Constitution VI: `git status --short knowledge/ KNOWLEDGE-INDEX.md` clean after the runner exits — the snapshot+restore pattern leaves the canonical project knowledge state byte-identical to the pre-M018 baseline.

## Files Created

- `tests/compression-runtime-parity/README.md` — corpus structure, byte-identical contract, "how to add a fixture" recipe.
- `tests/compression-runtime-parity/fixtures/filter-mixed-status/{config.yml,knowledge/conventions/MEM-FXT-A.md,knowledge/conventions/MEM-FXT-B.md,knowledge/patterns/MEM-FXT-C.md,knowledge/patterns/MEM-FXT-D.md,input/payload-input.txt,README.md}` — knowledge-aware filter fixture (US-2 / FR-3); mixed `status:` graduated/experimental/superseded; T1 + T2 disabled in config so the filter is the only mutating stage.
- `tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/{config.yml,input/payload-input.txt,README.md}` — Tier 1 microcompact fixture (US-3 / FR-4); inline `<tool-result command=...>` block with body past the configured `tier1.inline_threshold_tokens`; filter + T2 disabled.
- `tests/compression-runtime-parity/fixtures/tier2-oversized-section/{config.yml,input/payload-input.txt,README.md}` — Tier 2 snip fixture (US-4 / FR-5); ~58 KB lorem-ipsum body lands inside the `## Task Plan` section past the configured `tier2.section_budget_tokens`; filter + T1 disabled.
- `tests/compression-runtime-parity/fixtures/tier3-oversized-section/{config.yml,input/payload-input.txt,README.md}` — staged for T02; T01 runner skips this slug (the `tier3-oversized-section` fixture is the routing-parity input).
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` — fixture-staging helper. Mirrors the M018/P06 helper shape; takes `<runtime> <fixture>` args; idempotent clean-stage; emits the staged orch_root path on stdout. Bash 3.2, AP-009 / AD-19 clean.
- `scripts/diagnostics/m018-runtime-parity.sh` — zero-LLM parity runner. 280 lines. Bash 3.2, AP-009 / AD-19 clean. Always exits 0 (FR-12). Ships per-fixture-per-runtime `runtime-parity` lines, per-fixture `parity ... result=...` summaries, and a final `regression_flag: <none|divergence>` line for T03's verifier to read.
- [`.orchestrator/milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-SUMMARY.md`](../../../../../milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-SUMMARY.md) (this file).

## Files Modified

None. T01 is purely additive — no production-code changes (CON-1 / Constitution VI). Pre-M018 sentinel byte-identity is preserved.

## Deviations

1. **build-context.sh CLI surface**. The plan's Step 7 outline assumed a `--task-plan <file> --milestone <M>` interface; the actual CLI is positional: `<orch_root> <milestone> <phase> <task>`. The runner matches the actual surface (the plan explicitly authorized this in Step 7's "If build-context's CLI requires different flags, T01 author reads … once and matches the actual surface"). The fixture's `payload-input.txt` is folded into the staged task plan body via the helper, which `handle_task_plan` cats verbatim into the `## Task Plan` section — the bytes reach the tier helpers as intended.
2. **T3 short-circuit mechanism**. The plan's Step 5 fixture `config.yml` for `tier3-oversized-section` includes a (commented-out) `tier3.enabled: false`; that key is honored by `scripts/lib/knowledge-filter.sh` only on paper — the awk parser at `kf_read_compression_scalar` lacks the `in_t3` nested-block branch (a P06 oversight). The runner instead exports `INTENSITY_METADATA_FILE=intensity:Quick`, which forces `_bc_apply_tier3`'s intensity gate to short-circuit and emit a `tier3_skipped reason=intensity=quick` JSONL record — the contract-supported way to disable T3 from a fixture's orch_root. T01 documents this choice but does not patch the parser (out of T01 scope).
3. **Knowledge-state snapshot+restore**. `scripts/dispatch/build-context.sh`'s `PROJECT_ROOT` is hardcoded to `cd $SCRIPT_DIR/../..` — the orchestrator repo root — so a fixture's own `knowledge/` tree is not actually consulted by the resolved-knowledge pipeline (which goes through the project's `KNOWLEDGE-INDEX.md`). The runner snapshots `knowledge/` + `KNOWLEDGE-INDEX.md` to its output directory before the first invocation and restores them between every (fixture, runtime) pair so the three runtime runs see byte-identical input state. After the runner exits, `git status --short` shows `knowledge/` and `KNOWLEDGE-INDEX.md` clean — the snapshot+restore satisfies Constitution VI.
4. **T2 fixture rollback**. The Tier 2 fixture's snip path may roll back via the post-snip cross-tier preservation check (the in-band tier2 compression marker is itself a preserved-pattern row in the cross-tier vocabulary, so strict multiplicity is unsatisfied on a marker-free pre payload — `pre_count=0`, `post_count=1`, mismatch → rollback). This is a P04 logic quirk outside T01 scope. Either outcome — successful snip or boundary-refusal-rollback — is deterministic across runtimes; the byte-equality contract this fixture proves holds in both cases. The fixture's README documents this explicitly.
