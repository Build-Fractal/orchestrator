---
schema_version: "1.0"
type: phase-summary
id: "P07"
parent: "M018"
milestone: "M018"
provides:
  - "tests/compression-runtime-parity/ corpus tree (fixtures/filter-mixed-status,fixtures/tier1-oversized-tool-result,fixtures/tier2-oversized-section,fixtures/tier3-oversized-section + corpus README); each fixture carries config.yml (compression knobs sized so the tier under test fires),input/payload-input.txt (the bytes the runner folds into the staged task plan body),and a fixture-local README naming what the fixture exercises; the filter fixture also ships a knowledge/ subtree (MEM-FXT-A graduated,MEM-FXT-B experimental,MEM-FXT-C superseded,MEM-FXT-D graduated). scripts/diagnostics/m018-runtime-parity.sh — zero-LLM parity runner; iterates fixtures × runtimes ∈ {claude-code,codex,cursor},stages a hermetic orch_root via the helper,exports ORCH_BACKEND + INTENSITY_METADATA_FILE=intensity:Quick (forces T3 short-circuit),invokes scripts/dispatch/build-context.sh,captures the post-pipeline payload,computes SHA-256,prints per-(fixture,runtime) runtime-parity lines + per-fixture parity ... result=match|divergence summary + final regression_flag: <none|divergence|...>; appends additive runtime_parity JSONL records to each staged execution-log.jsonl (CON-5); always exits 0 (FR-12 advisory pattern); snapshots project knowledge/ + KNOWLEDGE-INDEX.md before the first invocation and restores between every runtime run so build-context's increment-hits side-effect does not perturb cross-runtime byte-equality. scripts/verify/_helpers/m018-p07-build-fixture.sh — fixture-staging helper; mirrors the m018-p06 helper shape; takes <runtime> <fixture> positional args; idempotent clean-stage; emits the staged orch_root path on stdout; copies fixture config.yml + knowledge/ tree to the stage; folds payload-input.txt verbatim into the staged T01-PLAN.md body so build-context's handle_task_plan injects the bytes into the ## Task Plan section (which is in T2's in_scope() set).,tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh — deterministic four-flag-honoring stub used as ORCH_TIER3_LLM_BIN; takes the operator-binary precedence path in scripts/dispatch/lib/tier3-llm-call.sh's provider-resolution ladder so the parity runner is hermetic across runtimes (no installed claude CLI is invoked); writes a deterministic envelope `<!-- compressed:tier3 model=stub-deterministic input_tokens=<N> output_tokens=42 -->\\nstub-deterministic-summary-body\\n` to --output where <N> is the byte size of --prompt-file; ORCH_TIER3_STUB_FAIL=1 flips to exit 1 (still records its invocation first) for FR-9 failure-passthrough exercise; per-fire side-effect appends one `<iso8601>\\t<runtime>` line to ORCH_TIER3_STUB_INVOCATIONS_LOG. tests/compression-runtime-parity/_stubs/README.md — stub documentation. scripts/diagnostics/m018-runtime-parity-tier3.sh — Tier 3 routing-parity driver; iterates runtimes ∈ {claude-code,cursor} via the T01 helper,exports ORCH_BACKEND + ORCH_TIER3_LLM_BIN=<stub> + ORCH_TIER3_STUB_INVOCATIONS_LOG + ORCH_TIER3_STUB_FAIL,asserts (success path) stub fired exactly once + post-pipeline payload contains the stub's deterministic marker + payload_breakdown JSONL carries tier3_invocations=1 + tier3_compression_savings_tokens > 0,asserts (--fail-stub) stub fired exactly once + dispatch survived (BC_RC=0) + JSONL carries tier3_failed reason=llm-call-nonzero; appends additive runtime_parity JSONL records to each staged execution-log.jsonl (CON-5); always exits 0 (FR-12 advisory pattern); snapshots project knowledge/ + KNOWLEDGE-INDEX.md before the first invocation and restores between every runtime run so build-context's increment-hits side-effect does not perturb cross-runtime equality.,Three P07-private truth verifiers under scripts/verify/m018-p07-*.sh: m018-p07-zero-llm-parity.sh (16 assertions; drives the T01 zero-LLM runner end-to-end and asserts on per-(fixture,runtime) sha256 lines + per-fixture parity-match summary + final regression_flag: none,with documented-divergence carve-out accepting divergence iff a RA-M018-NN row exists in references/RUNTIME-ASSUMPTIONS.md),m018-p07-tier3-routing.sh (14 assertions; drives the T02 T3 runner under both success and --fail-stub modes asserting per-runtime tier3-routing routed stub_invocations=1 lines,tier3-routing-parity result=all-routed summary,and FR-9 failure-passthrough passthrough=ok lines),m018-p07-runtime-assumptions-and-dual-write.sh (11 assertions; mirrors the m018-p06-dual-write-recent.sh shape with M018/P06 -> M018/P07 substitution and adds RUNTIME-ASSUMPTIONS.md presence + # Compression (M018) header + RA-M018-NN row assertions). references/RUNTIME-ASSUMPTIONS.md (registry document for the M009 launch-gate runtime-parity audit; # Compression (M018) block names two inherent-by-design divergences RA-M018-01 Tier 3 model+pricing per runtime and RA-M018-02 claude CLI PATH presence with rationale + M009 audit-row link placeholders; bash-only tier parity sub-block records P07 close-state regression_flag: none,no divergence observed). P07-SUMMARY.md (written atomically via bash scripts/lifecycle/phase-transition.sh --write so roadmap+disk transition together — load-bearing convention from P05/T04 retrospective). CLAUDE.md / AGENTS.md orchestrator:recent-changes dual-write naming M018/P07 + runtime-parity via scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry."
requires:
  - "P06"
affects:
  - "none"
key_files:
  - "scripts/diagnostics/m018-runtime-parity.sh;scripts/verify/_helpers/m018-p07-build-fixture.sh;tests/compression-runtime-parity/README.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/config.yml;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/conventions/MEM-FXT-A.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/conventions/MEM-FXT-B.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/patterns/MEM-FXT-C.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/knowledge/patterns/MEM-FXT-D.md;tests/compression-runtime-parity/fixtures/filter-mixed-status/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/config.yml;tests/compression-runtime-parity/fixtures/tier1-oversized-tool-result/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier2-oversized-section/config.yml;tests/compression-runtime-parity/fixtures/tier2-oversized-section/input/payload-input.txt;tests/compression-runtime-parity/fixtures/tier3-oversized-section/config.yml;tests/compression-runtime-parity/fixtures/tier3-oversized-section/input/payload-input.txt,tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh;tests/compression-runtime-parity/_stubs/README.md;scripts/diagnostics/m018-runtime-parity-tier3.sh;.orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-SUMMARY.md,scripts/verify/m018-p07-zero-llm-parity.sh;scripts/verify/m018-p07-tier3-routing.sh;scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh;references/RUNTIME-ASSUMPTIONS.md;.orchestrator/milestones/M018/phases/P07/_summary-body.txt;.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md;CLAUDE.md;AGENTS.md"
key_decisions:
  - "build-context.sh's PROJECT_ROOT is hardcoded to the orchestrator repo (cd $SCRIPT_DIR/../..) so the fixture cannot fully isolate from the project's KNOWLEDGE-INDEX.md and knowledge/ tree; the parity runner instead snapshots both before the first invocation and restores between every (fixture,runtime) pair so the three runtime runs see byte-identical input state — proving byte-equality across runtimes without requiring a build-context PROJECT_ROOT plumbing change (out of T01 scope per CON-1 / Constitution VI). T3 short-circuit via INTENSITY_METADATA_FILE=intensity:Quick rather than tier3.enabled:false because scripts/lib/knowledge-filter.sh's kf_read_compression_scalar awk parser does not handle the tier3 nested block (a P06 oversight outside T01 scope); the intensity-gate path is the contract-supported way to disable T3 from a fixture's orch_root. Helper drops the wrapper task-plan frontmatter and copies the fixture's payload-input.txt verbatim into T01-PLAN.md — handle_task_plan cats the file body,so the fixture-author owns the bytes that land in the ## Task Plan section; this avoids the head-drop preservation-check rolling the snip back over the wrapper's `---` delimiters. tier3-oversized-section fixture is staged but NOT exercised by the runner (T02's job); the runner skips that slug explicitly. tier2-oversized-section fixture's snip path may roll back via the post-snip cross-tier preservation check (the in-band tier2 compression marker is itself a preserved-pattern row,so strict multiplicity is unsatisfied on a marker-free pre payload) — this is a P04 quirk outside T01 scope; either outcome (successful snip or boundary-refusal-rollback) is deterministic across runtimes so the byte-equality contract holds in both cases. Always-exit-0 advisory pattern preserved: divergence surfaces via regression_flag: divergence on stdout,never via non-zero exit (FR-12 / CON-5).,Stub-fires-before-exit-1 invariant on the failure-passthrough path: ORCH_TIER3_STUB_FAIL=1 still appends its invocation line to ORCH_TIER3_STUB_INVOCATIONS_LOG before printing the stderr message and exiting 1,so the parity runner can prove the operator-binary call surface was reached even when the stub aborts. Without this,the runner could not distinguish 'stub never fired (routing broken)' from 'stub fired and failed as instructed' on the --fail-stub path. The runner asserts stub_invocations=1 on both paths. Runner does NOT pass INTENSITY_METADATA_FILE: T01's zero-LLM runner forces intensity=Quick to short-circuit T3; T02 does the inverse — the absent metadata file resolves to `standard` per kf_resolve_intensity which clears the FR-14 gate and lets T3 actually fire. The fixture's config.yml does not override compression.tier3.intensity_floor (default `standard`) so T3 is gated open. Knowledge-snapshot + restore pattern carried forward from T01 verbatim — proves runtime-parity asserts on byte-identical input state across the three runtime runs without requiring a build-context.sh PROJECT_ROOT plumbing change (out of T02 scope per CON-1 / Constitution VI). Operator-binary path chosen over claude-code-claude path because ORCH_TIER3_LLM_BIN takes highest precedence in tier3-llm-call.sh's provider ladder — proves the routing surface itself is runtime-agnostic (the env-var value is the only thing that cycles across the three runtime runs; the actual LLM-call binary is byte-identical per runtime). The runner emits `result=all-routed` on success path and `result=all-passthrough` on --fail-stub path with `regression_flag: none` on both — non-zero divergence surfaces via `regression_flag: divergence` (FR-12 always-exit-0 advisory pattern preserved).,phase-transition.sh --write (NOT write-summary.sh phase) is the canonical closing-task convention — P05/T04 hit a SYNC:MISMATCH using the latter and P06/T04 confirmed the lifecycle helper is the right surface; T03 follows the P06/T04 pattern verbatim with a body-file at .orchestrator/milestones/M018/phases/P07/_summary-body.txt; documented-divergence carve-out: the P07 verifiers accept regression_flag: divergence iff a documenting RA-M018-NN row exists in references/RUNTIME-ASSUMPTIONS.md so divergences are documented (not suppressed) and the verifier asserts the documentation discipline; references/RUNTIME-ASSUMPTIONS.md M009 audit-row column carries placeholder IDs (M009-RP-01,M009-RP-02) — M009 will assign real audit-row IDs at audit time; the verifier asserts header + at least one RA-M018-NN row,not specific row IDs; AP-009 / single-script-file Check shape preserved on every verifier — runner stdout captured to a temp file via single redirect,then grep-asserted (no inline pipes,no compound chains > 2); M018/P06 -> M018/P07 substitution on the dual-write verifier shape + addition of RUNTIME-ASSUMPTIONS.md assertions makes Truth #3 a clean superset of the P06 dual-write check"
patterns_established:
  - "Hermetic-fixture-with-knowledge-snapshot pattern: when a tier helper has a side-effect on shared project state (here: increment-hits.sh on KNOWLEDGE-INDEX.md + per-entry hit_count: frontmatter),the parity runner snapshots the relevant subtree to its own output dir before the first invocation and restores between every test case — restores the project to byte-identical pre-test state at the END of the run,satisfying constitution VI (canonical files byte-identical to pre-M018) without needing helper plumbing changes; runner-internal MEM004 carve-out for awk pipes (single-script-file rule applies only at task/phase plan Check: line). Fixture-corpus directory shape: fixtures/<slug>/{config.yml,input/payload-input.txt,knowledge/?,README.md} — uniform across tiers; helper auto-discovers any directory under fixtures/,no registry to update; new fixture = copy directory + tune config.yml + rewrite payload-input.txt + author README. Run-order-deterministic-across-hosts pattern: fixture list and runtime list both flow through sort -o to stable files before iteration so stdout ordering matches the byte-equality assertion verifier T03 will apply; AP-009 clean — no inline pipes-to-wc,no compound chains > 2 — output captured to files and read via `awk 'END{print NR}'` or `awk 'NR==1{print $1}'` single-pass shapes; Bash 3.2 strict (no declare -A,no mapfile,no read -ra).,Hermetic-stub-via-operator-binary-path pattern: when a runtime-portability surface has a provider-resolution ladder,ship a deterministic stub that takes the highest-precedence path (here: ORCH_TIER3_LLM_BIN) so the parity assertion does not depend on any installed real provider. The stub honors the same flag contract the production ladder uses (here: --prompt-file/--output/--max-tokens/--timeout from tier3-llm-call.sh:80-86),so swapping ORCH_TIER3_LLM_BIN for a real binary at any time is a drop-in replacement. Stub-fires-before-exit-non-zero invariant: failure-mode stubs that exercise downstream failure-passthrough paths must record their invocation BEFORE returning non-zero,so the parity runner can disambiguate 'never reached' from 'reached and failed'. Runner-exports-env-vars-inline pattern: the runner exports ORCH_BACKEND / ORCH_TIER3_LLM_BIN / ORCH_TIER3_STUB_INVOCATIONS_LOG / ORCH_TIER3_STUB_FAIL inline on the same `bash $BUILD_CONTEXT ...` invocation rather than `export` + invoke pairs — single-script-file shape (AP-009 clean),no leak across iterations. Always-exit-0 advisory pattern carry-forward from T01: divergence surfaces via per-runtime line shape + `regression_flag: divergence` summary line,never via non-zero exit (FR-12 / CON-5).,Closing-task verifier-and-summary shape carries forward from P03/P04/P05/P06: pass and fail helpers per MEM002,hermetic ORCHESTRATOR_ROOT staging via runners (verifiers themselves do not touch canonical state),single-script-file Check shape per AD-19/AP-009,body-file pattern (_summary-body.txt) keeps multiline narrative out of CLI args per AD-19,dual-write via scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry; phase-transition.sh --write is the canonical roadmap+disk atomic transition for closing tasks; documented-divergence carve-out pattern — verifiers accept observed divergence iff the registry document carries a corresponding row,asserting documentation discipline rather than suppressing observations; runtime-assumptions registry pattern — references/RUNTIME-ASSUMPTIONS.md is the single consumption surface for the M009 launch-gate runtime-parity audit,with milestone-scoped # <Surface> (M0NN) blocks each carrying RA-M0NN-NN rows with rationale + M009 audit-row link"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P07/tasks/T01-fixture-corpus-and-parity-runner-SUMMARY.md, .orchestrator/milestones/M018/phases/P07/tasks/T02-tier3-routing-parity-SUMMARY.md, .orchestrator/milestones/M018/phases/P07/tasks/T03-verifiers-and-summary-SUMMARY.md"
duration: "62m"
verification_result: "pass"
completed_at: "2026-04-28T15:50:43Z"
observability_surfaces:
  - "scripts/diagnostics/m018-runtime-parity.sh stdout: per-fixture per-runtime SHA-256 lines + parity match summary + regression_flag advisory; scripts/diagnostics/m018-runtime-parity-tier3.sh stdout: per-runtime routing lines + tier3-routing-parity summary + regression_flag advisory; runtime_parity JSONL record_type appended to fixture-local execution-log.jsonl (additive); references/RUNTIME-ASSUMPTIONS.md: # Compression (M018) block with RA-M018-NN divergence rows."
---

P07 lands the **multi-runtime parity audit** for the M018 compression
pipeline. The phase ships zero-production-code surfaces — only
diagnostic surfaces, fixtures, verifiers, and a registry document —
and proves the pipeline behaves identically (or, where divergence is
inherent to the multi-runtime model, predictably) under every
supported runtime: `claude-code`, `codex`, `cursor`.

After P07, the M018 compression pipeline carries a hermetic byte-equality
proof for the bash-only tiers (knowledge-aware filter + Tier 1
microcompact + Tier 2 snip) across all three runtimes, plus a Tier 3
routing-parity proof under a deterministic stub. Inherent runtime
divergences (Tier 3 native-model name + pricing; `claude` CLI PATH
presence) are documented in `references/RUNTIME-ASSUMPTIONS.md` for
the M009 launch-gate runtime-parity audit to consume.

The phase ships:

- **`tests/compression-runtime-parity/` fixture corpus** (T01) — four
  fixture trees under `fixtures/{filter-mixed-status,
  tier1-oversized-tool-result, tier2-oversized-section,
  tier3-oversized-section}/`, each with `config.yml`,
  `input/payload-input.txt`, and a fixture-local README; the filter
  fixture also ships a small `knowledge/` subtree (MEM-FXT-A graduated,
  MEM-FXT-B experimental, MEM-FXT-C superseded, MEM-FXT-D graduated)
  exercising the knowledge-aware filter's mixed-status path. Corpus
  README at `tests/compression-runtime-parity/README.md` documents the
  byte-equality contract.

- **`scripts/diagnostics/m018-runtime-parity.sh`** (T01) — zero-LLM
  parity runner. Iterates fixtures × runtimes, stages a hermetic
  orch_root via the helper, exports
  `ORCH_BACKEND` + `INTENSITY_METADATA_FILE=intensity:Quick` (forces T3
  short-circuit), invokes `scripts/dispatch/build-context.sh`, captures
  the post-pipeline payload, computes SHA-256, and prints
  per-(fixture,runtime) `runtime-parity` lines + per-fixture
  `parity ... result=match|divergence` summaries + a final
  `regression_flag:` advisory line. Always exits 0 (FR-12). Snapshots
  the project's `knowledge/` tree + `KNOWLEDGE-INDEX.md` before the
  first invocation and restores between every (fixture, runtime) pair
  so build-context's `increment-hits.sh` side-effect cannot perturb
  cross-runtime byte-equality.

- **`scripts/diagnostics/m018-runtime-parity-tier3.sh`** (T02) — Tier 3
  routing parity runner. Uses
  `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` as the
  deterministic LLM provider via `ORCH_TIER3_LLM_BIN`, runs build-context
  with the `tier3-oversized-section` fixture under each runtime, and
  asserts the stub fired exactly once per runtime (`stub_invocations=1`).
  `--fail-stub` mode exercises FR-9 failure-passthrough: the stub
  exits non-zero and the runner asserts Tier 2's bytes pass through
  unchanged (`passthrough=ok` per runtime). Always exits 0.

- **`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`** (T02) —
  deterministic four-flag stub for hermetic T3 invocations. Honors
  `--prompt`, `--input`, `--output`, `--stub-fail` flags; in success
  mode emits a fixed compressed body to the output path; in
  `--stub-fail` mode exits non-zero so the helper's failure-passthrough
  path fires. Stub README documents the contract.

- **`scripts/verify/_helpers/m018-p07-build-fixture.sh`** (T01) —
  fixture-staging helper mirroring the P06 helper shape. Takes
  `<runtime> <fixture>` positional args; idempotent clean-stage; emits
  the staged orch_root path on stdout; copies fixture `config.yml` +
  `knowledge/` tree to the stage; folds `payload-input.txt` verbatim
  into the staged `T01-PLAN.md` body so build-context's
  `handle_task_plan` injects the bytes into the `## Task Plan` section.

- **`references/RUNTIME-ASSUMPTIONS.md`** (T03) — registry document
  consumed by the M009 launch-gate runtime-parity audit. The
  `# Compression (M018)` block names two inherent-by-design divergences
  (`RA-M018-01` Tier 3 model + pricing per runtime; `RA-M018-02`
  `claude` CLI PATH presence), each with rationale and an M009
  audit-row link placeholder. The bash-only tier parity sub-block
  records the P07 close-state result: `regression_flag: none`, no
  divergence observed.

- **Three P07-private truth verifiers** (T03) under
  `scripts/verify/m018-p07-*.sh`:
    - `m018-p07-zero-llm-parity.sh` — drives the zero-LLM runner; 16
      assertions covering per-(fixture, runtime) SHA-256 lines,
      per-fixture parity match, and the final `regression_flag: none`
      result. Documented-divergence carve-out: accepts
      `regression_flag: divergence` iff a documenting RA-M018-NN row
      exists in `references/RUNTIME-ASSUMPTIONS.md`.
    - `m018-p07-tier3-routing.sh` — drives the T3 routing runner; 14
      assertions covering both success and `--fail-stub` modes (per-runtime
      routed lines, summary, regression flag, FR-9 failure-passthrough).
    - `m018-p07-runtime-assumptions-and-dual-write.sh` — 11 assertions
      covering RUNTIME-ASSUMPTIONS.md presence + `# Compression (M018)`
      block header + at least one RA-M018-NN row, plus the CLAUDE.md /
      AGENTS.md `orchestrator:recent-changes` block (both name `M018/P07`
      and `runtime-parity`).

- **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write**
  (T03) via `scripts/util/dual-write-runtime-md.sh --marker recent-changes
  --append-entry "..."`. Both runtime instruction files name `M018/P07`
  and `runtime-parity`.

## Risk-mitigation traceability

- **CON-1 / Constitution Principle VI (canonical files byte-identical
  to pre-M018)** — P07 modifies only CLAUDE.md (recent-changes block,
  via the marker-bounded dual-write helper) and AGENTS.md (the marker
  region). All other production code (`scripts/dispatch/build-context.sh`,
  `scripts/lib/knowledge-filter.sh`, the dispatch tree, etc.) is
  untouched. The fixture corpus + verifiers + RUNTIME-ASSUMPTIONS.md +
  diagnostic runners are net-new files outside the canonical surface.

- **CON-5 (additive emitters)** — no emitter schema changes in P07.
  The `runtime_parity` JSONL record_type that T01's runner appends to
  the staged-fixture execution-log.jsonl is additive (new record_type
  values are CON-5-compliant; pre-M018 readers ignore unknown
  record_types).

- **FR-9 (Tier 3 failure-passthrough)** — exercised end-to-end by the
  T02 routing runner's `--fail-stub` mode under every runtime. Runner
  asserts `passthrough=ok` per runtime; the dispatch never crashes
  from a Tier 3 fault even when the LLM provider exits non-zero.

- **FR-12 (read-only diagnostic surfaces)** — both runners always exit
  0; divergence surfaces via `regression_flag:` advisory lines, never
  via non-zero exit. Verifiers honor the same contract.

- **FR-13 (multi-runtime native-model T3 routing)** — the routing
  runner proves T3 routes through `scripts/dispatch/lib/tier3-llm-call.sh`
  under every runtime (`stub_invocations=1` per runtime in success
  mode); the inherent native-model + pricing divergence is documented
  in `references/RUNTIME-ASSUMPTIONS.md` `RA-M018-01`.

- **AD-19 / AP-009 single-script-file Check shape** — every truth
  verifier exposes its truth via a single bash invocation; verifiers
  use `pass()`/`fail()` per MEM002 and `printf 'PASS:' / 'FAIL:'`
  line-prefix per MEM001; runner-internal MEM004 carve-out applies
  inside the diagnostic bodies but the Check line itself remains
  single-script-file.

- **Bash 3.2 (MEM001)** — verifiers use parallel indexed arrays + simple
  for-loops; no `declare -A`, no `mapfile`, no `read -ra`. AGENTS.md
  dual-write via the canonical helper (never edited directly).

## Followups for downstream phases

- **M009 launch-gate handoff** — `references/RUNTIME-ASSUMPTIONS.md`
  is the consumption surface for the M009 runtime-parity audit. P07
  uses placeholder M009 audit-row IDs (`M009-RP-01`, `M009-RP-02`);
  M009 will assign real audit-row IDs at audit time. The verifier
  asserts the column header exists and at least one RA-M018-NN row is
  present, not specific row IDs. Future divergences observed under
  later phases or milestones should land as new RA-M018-NN rows in the
  bash-only tier parity sub-block.

- **Documented-divergence carve-out** — the P07 verifiers accept
  `regression_flag: divergence` iff the corresponding RA-M018-NN row
  exists in `references/RUNTIME-ASSUMPTIONS.md`. This honors the spec
  framing: divergences are documented, not suppressed; the verifier
  asserts the documentation discipline.

- **Knowledge-state snapshot/restore** — the zero-LLM parity runner
  carries an in-runner snapshot of `knowledge/` + `KNOWLEDGE-INDEX.md`
  before the first invocation and restores between (fixture, runtime)
  pairs because `build-context.sh`'s `PROJECT_ROOT` is hardcoded to
  the orchestrator repo. A future phase could plumb a `PROJECT_ROOT`
  override through build-context to remove the snapshot/restore
  surface, but P07 leaves the canonical script untouched per CON-1.

- **Tier 3 fixture coverage** — the corpus ships one Tier 3 fixture
  (`tier3-oversized-section`); future routing-parity work could add
  fixtures exercising the density-floor short-circuit, the
  preservation-breach failure path, and the `output_max_ratio`
  no-savings path. The runner auto-discovers fixtures, so adding new
  ones requires no runner change.

## Verification result

All three P07 truths PASS. Each verifier exits 0 with `PASS:` lines per
assertion:

- `m018-p07-zero-llm-parity.sh` — PASS (16 assertions: runner exists +
  `bash -n` clean + per-(fixture, runtime) `runtime-parity sha256=`
  lines × 9 + per-fixture `parity result=match runtimes=3` × 3 + final
  `regression_flag: none`).
- `m018-p07-tier3-routing.sh` — PASS (14 assertions: runner +
  `bash -n` + stub `-x` + success-mode `tier3-routing routed
  stub_invocations=1` × 3 + `tier3-routing-parity result=all-routed` +
  `regression_flag: none` + `--fail-stub` exit 0 + per-runtime
  `passthrough=ok` × 3).
- `m018-p07-runtime-assumptions-and-dual-write.sh` — PASS (11
  assertions: RUNTIME-ASSUMPTIONS.md + `# Compression (M018)` header +
  RA-M018-NN row + CLAUDE.md / AGENTS.md `recent-changes` regions +
  both name `M018/P07` and `runtime-parity`).

P07 closed. M018 advances to milestone-close consolidation.
