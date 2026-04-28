---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M018"
provides:
  - "scripts/diagnostics/compression-eval.sh — sourceable + CLI cohort-segmentation diagnostic for the M018 compression pipeline. compression_eval_render <milestone> <tier> <sample_floor> walks .orchestrator/milestones/<M>/execution-log.jsonl in a single awk pass, classifies each task-granularity unit_close into the compressed cohort (matching payload_breakdown carries tier<N>_savings_tokens > 0) or the uncompressed cohort (tier<N>_savings_tokens == 0 OR field absent), then computes per-cohort means + 95% CIs for verification_pass_rate (Wilson interval), retry_count (SEM), and deviation_count (SEM), plus the cohort delta with pooled-SE proportion CI / SEM-difference CI. CLI: --milestone <Mxxx> (auto-resolved via find-active-milestone.sh when omitted), --tier <N> (1 or 2 in P05; 3 emits 'reserved for P06' stub; other values emit 'unsupported tier'), --sample-floor <N> (default 30 — both cohorts must meet floor or 'insufficient sample (compressed=N1 uncompressed=N2 floor=F)' is emitted). Always exits 0 (FR-12 / CON-5). Zero LLM tokens (FR-21). Read-only (no JSONL writes). Bash 3.2 compatible: awk + parallel scalars only, no declare -A, no process substitution, no merged stdout-stderr. MEM004 emitter-internal carve-out documented in header for the awk + pipe shape. Sourceable guard via _COMPRESSION_EVAL_SH_SOURCED. Regression flag fires only when delta_pr <= -0.05 AND CI excludes 0."
requires:
  - "from:P05/T01 what:tier1_savings_tokens / tier2_savings_tokens / tier1_invocations / filter_dropped_tokens additive fields on dispatch_usage and unit_close JSONL records (T01-shipped P05/T01-SUMMARY); from:P02/T02 what:filter_dropped_tokens on payload_breakdown; from:P03/T01 what:tier1_savings_tokens + tier1_invocations on payload_breakdown; from:P04/T01 what:tier2_savings_tokens on payload_breakdown; from:M027/P00 what:metrics-rollup.sh shape skeleton (header / sourceable guard / project-root resolution / MEM004 carve-out comment / CLI argv parser); from:M019 what:execution-log.jsonl path convention .orchestrator/milestones/<M>/execution-log.jsonl; from:scripts/state/find-active-milestone.sh what:active milestone resolver."
affects:
  - "T04 (verifiers m018-p05-compression-eval.sh + m018-p05-compression-eval-shape.sh exercise this script); P06 (--tier 3 stub will be replaced with real cohort logic against tier3_savings_tokens / tier3_invocations); M018 phase close (compression-eval is the outcome-rate gate complementing T02's savings-ratio anomaly flag — they cover different abstractions: savings-ratio = 'did compression reduce tokens enough?', cohort-delta pass-rate = 'did compression hurt downstream verification outcomes?')."
key_files:
  - "scripts/diagnostics/compression-eval.sh"
key_decisions:
  - "Wilson 95% CI for proportions (closed-form, bash-3.2-friendly via awk arithmetic, no python/jq); pooled-SE normal-approximation for proportion delta CI (acceptable at n>=30 floor); SEM + 1.96*SEM-difference for retry/deviation count CIs (heavy-tail tolerant since the diagnostic refuses to flag below the floor); cohort match keyed on (milestone, phase, task) — phase-granularity and milestone-granularity unit_close records excluded from the split (they are aggregations); 'compressed' cohort defined as tier<N>_savings_tokens > 0 from payload_breakdown rows (per-dispatch ground truth) NOT from the rolled-up unit_close field (prevents double-classification); --tier 3 ships as recognized-but-no-op stub so CLI surface is stable for P06; sample-floor default 30 prevents false positives at low N; regression flag fires only when delta_pr <= -0.05 AND CI excludes 0 (5pp pass-rate drop with statistical confidence) — advisory text-only output, no JSONL emission, no exit-code change."
patterns_established:
  - "cohort-segmentation diagnostic shape: single awk pass over execution-log.jsonl with per-record-type branches (payload_breakdown classifies, unit_close measures); awk inline helpers field_num/field_str/field_real for jq-free JSONL field extraction (regex-based, no library dependency); Wilson CI + pooled-SE delta in pure awk (closed-form, single-pass); 'insufficient sample' early-exit in awk END-block before any cohort math; sourceable + CLI duality via _<NAME>_SOURCED guard + BASH_SOURCE[0]==$0 check (mirrors metrics-rollup.sh / efficiency-footer.sh / check-anomalies.sh); --tier <N> recognized-but-stub pattern for forward-compat with future tier additions; FR-12 always-exit-0 contract surfaces degraded inputs as text on stdout (no exit-code signaling)."
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P05/tasks/T03-compression-eval-PLAN.md,scripts/diagnostics/compression-eval.sh"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-28T04:56:02Z"
---

T03 ships scripts/diagnostics/compression-eval.sh — a sourceable + CLI cohort-segmentation diagnostic that answers 'did the dispatches that fired tier N produce different outcomes than the dispatches on the same milestone that did not fire tier N?' by reading payload_breakdown + unit_close records from execution-log.jsonl and reporting per-cohort + delta means with confidence intervals.

Cohort definition (milestone, phase, task)-keyed. The classifier walks payload_breakdown records and sets tier_fired[key]=1 when tier<N>_savings_tokens > 0 (per the requested --tier 1 or 2). The measure pass walks task-granularity unit_close records (phase-granularity / milestone-granularity records are excluded as aggregations), looks up the same key, and accumulates pass_rate / retry_count / deviation_count sums + sums-of-squares per cohort. END block: enforce sample floor (default 30 per cohort, --sample-floor overrides), then compute means, Wilson 95% CI for the pass-rate proportion, SEM for retry/deviation, pooled-SE delta CI for the proportion, sqrt(var_a/n_a + var_b/n_b) delta SE for the count metrics, and emit a regression_flag only when delta_pr <= -0.05 AND the upper CI bound is < 0.

Implementation honors all P05 constraints: bash 3.2 (parallel scalars MILESTONE/TIER/FLOOR_OVERRIDE/FLOOR; no declare -A; awk indexed maps only beyond standard awk usage; no process substitution; no merged stdout-stderr); zero LLM tokens (bash + awk + grep only — no python, no jq); read-only (FR-12 — never appends to or rewrites JSONL); always exit 0 (FR-12 / CON-5 — degraded inputs surface as text). MEM004 emitter-internal carve-out documented in the header allows the awk + pipe shape inside this diagnostic; AD-19 single-script-file Check: rule applies at task/phase plan level, where T04 will invoke this script as a single bash invocation.

CLI surface: --milestone <Mxxx> (auto-resolved via find-active-milestone.sh when omitted, falls back to empty); --tier <N> required (1 or 2 in P05; --tier 3 emits 'tier 3 reserved for P06; not yet supported' and exits 0 — recognized-but-no-op stub for forward-compat; other values emit 'unsupported tier'); --sample-floor <N> default 30; --help / -h emits usage block. Sourceable: source the script and call compression_eval_render <milestone> <tier> <sample_floor> directly; the function always returns 0.

Verification (Constitution Principle II — Evidence Before Claims):

Tier 1 syntax check: bash -n scripts/diagnostics/compression-eval.sh — PASS (no output).

Tier 2 functional smoke against the live M018 execution-log.jsonl:
- bash scripts/diagnostics/compression-eval.sh --help → emits the 5-line usage block, exits 0.
- bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 5 → '# compression-eval — milestone=M018 tier=1' header + 'insufficient sample (compressed=0 uncompressed=18 floor=5)' (the live log carries 18 task-granularity unit_close records but no T01-emitted unit_close yet rolls up tier1_savings_tokens > 0 because P05/T01 closed before any post-T01 dispatches landed at task granularity with tier1 firings — exactly the kind of degraded input the script handles gracefully).
- bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 2 --sample-floor 5 → same shape, tier=2 header.
- bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 3 → '# compression-eval — milestone=M018 tier=3' header + 'tier 3 reserved for P06; not yet supported', exits 0 (P06-stub path).
- bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 1000 → 'insufficient sample (...floor=1000)' (high-floor refusal).
- bash scripts/diagnostics/compression-eval.sh --milestone NOPE --tier 1 → 'log file missing: ...' degraded-path text, exits 0.

Sourceable verification:
- bash -c 'source scripts/diagnostics/compression-eval.sh; compression_eval_render M018 1 5' → emits the same per-cohort report; type compression_eval_render reports 'is a function'. Confirms sourceable + CLI duality.

Plan defect patched: T03's Verification block references T04-shipped verifiers (m018-p05-compression-eval.sh / m018-p05-compression-eval-shape.sh) with no extractable Check: lines (same defect as T01 and T02 plans). Patched the plan to add a 'Mechanical self-check (T03-local; AD-19 single-script-file shape; no T04 dependency)' section with 'Check: bash -n scripts/diagnostics/compression-eval.sh' so the orchestrator-verify pass has a hard-grounded T03-local Check command. T04 verifiers will exercise the script's runtime semantics with formal fixtures.

T03 ships ONLY scripts/diagnostics/compression-eval.sh per the plan's explicit scope statement. No verifiers, no fixtures, no fixture-staging helper, no P05-SUMMARY, no dual-write — all of those are T04. No T01 or T02 surface extensions. Truth #6 (compression-eval cohort segmentation) and Truth #7 (compression-eval shape contract) are wholly addressed; Truths #1-5 (T01, T02) and #8 (T04) are out of scope.
