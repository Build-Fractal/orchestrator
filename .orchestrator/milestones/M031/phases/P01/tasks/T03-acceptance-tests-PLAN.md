---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M031"
name: "SC-1 / SC-2 / SC-3 / SC-15 acceptance tests + corresponding shape verifiers"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/build-context.sh` accepts `--profile=quick` + `--meta-out <file>`.
- T02 complete: `commands/dispatch.md` no longer contains "Skip payload assembly"; `post-m031-baseline.jsonl` exists with 20 records.
- T01 verifiers green: `bash tools/verify/m031-p01-build-context-profile-shape.sh`, `m031-p01-quick-no-skip-branch.sh`, `m031-p01-config-knobs-stable.sh` all exit 0.
- T02 verifiers green: `bash tools/verify/m031-p01-post-baseline-jsonl-population.sh`, `m031-p01-dispatch-md-reconciliation.sh` all exit 0.
- P00 complete: `tests/m031-acceptance/fixtures/empirical-baseline/` 20-task corpus + `CORPUS-MANIFEST.md` + `pre-m031-baseline.jsonl` (20 records).
- P00 complete: `references/RUNTIME-ASSUMPTIONS.md` documents M018 tier-1 `inline_threshold_tokens=1500`.
- `templates/orchestrator-config-default.yml` declares `quick_knowledge_token_budget: 800` (P00).

## Description

T03 ships the four SC acceptance scripts under `tests/m031-acceptance/` (SC-1, SC-2 per AD-13, SC-3 per AD-17, SC-15 per AD-18) and the four corresponding shape verifiers under `tools/verify/m031-p01-test-*-shape.sh`. Each acceptance script invokes T01's amended `build-context.sh --profile=quick` against fixtures from the P00 corpus and asserts the SC contract verbatim from the spec.

The four SCs and their contracts:

- **SC-1 (Quick injects knowledge)**: a Quick-intensity dispatch payload manifest shows non-zero `knowledge_section_tokens` and either non-zero `tier1_replacements` or an empty-cache-hit record in the JSONL `payload_breakdown`.
- **SC-2 (build-context profile flag, AD-13)**: against a Quick-profile payload constructed to exceed `quick_knowledge_token_budget`, (a) a tier-2 snip JSONL record fires at the budget boundary AND (b) the final Knowledge section in the assembled payload is ≤ `quick_knowledge_token_budget` tokens. NO ±20% tolerance.
- **SC-3 (compression applies to Quick, AD-17)**: the fixture explicitly constructs a Quick-profile payload exceeding the M018 tier-1 `inline_threshold_tokens` value (1500 per P00); tier-1 paging records AND tier-2 snip records appear in the JSONL stream.
- **SC-15 (Quick budget median compliance, AD-18)**: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task P00 corpus is ≤ `quick_knowledge_token_budget` (800), independent of the pre-M031 baseline.

## Steps

1. **Author `tests/m031-acceptance/test-quick-injects-knowledge.sh` (SC-1).** Bash 3.2-compatible, executable. Behavior:
   - Use a single corpus task fixture (`tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` is the canonical pick).
   - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt --out /tmp/m031-p01-t03-sc1-payload.md --meta-out /tmp/m031-p01-t03-sc1-meta.json`.
   - Assert exit 0.
   - Assert `/tmp/m031-p01-t03-sc1-meta.json` is a valid JSON object whose `mem_count` is ≥ 1 AND `total_tokens` is ≥ 100 (sanity floor, not a tight contract — Quick is small but not empty).
   - Assert the JSONL `payload_breakdown` stream emitted during the invocation contains at least one record with `knowledge_section_tokens > 0`. The JSONL emission location is wherever build-context.sh emits today (per existing convention — read the existing emission target from build-context.sh prose; the standard target is `.orchestrator/observability/payload_breakdown.jsonl` or equivalent).
   - File header: contains "SC-1", "knowledge_section_tokens", "payload_breakdown".
   - Output: a single final stdout line `RESULT: SC-1 pass` on success or `RESULT: SC-1 fail <reason>` on failure. Exit 0 on pass.

2. **Author `tests/m031-acceptance/test-build-context-profile.sh` (SC-2 per AD-13).** Bash 3.2-compatible, executable. Behavior:
   - Read `quick_knowledge_token_budget` from `templates/orchestrator-config-default.yml` (default 800 per P00).
   - Construct a Quick-profile payload that exceeds the budget. The cleanest path: pass a corpus fixture whose touched-file 1-hop graph traversal yields enough MEMs to exceed 800 tokens. If no corpus fixture naturally exceeds the budget, the test MAY synthesize a wide-touched-files plan in `/tmp/` (a temp task plan that touches enough files to trigger a wide traversal) — but this is the fallback; prefer the natural-corpus path.
   - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <fixture-path> --out /tmp/m031-p01-t03-sc2-payload.md --meta-out /tmp/m031-p01-t03-sc2-meta.json`.
   - Assert exit 0.
   - Assert the JSONL stream contains a tier-2 snip record (look for the M018 tier-2 record name; the existing convention emits a record like `{"event":"tier2_snip", ...}` or `{"compressed":"tier2", ...}` — read the existing emission convention from `scripts/lib/payload-transforms.sh` or build-context.sh prose).
   - Assert the assembled `/tmp/m031-p01-t03-sc2-payload.md` Knowledge section's token count is ≤ `quick_knowledge_token_budget`. Reuse build-context.sh's existing token estimator.
   - File header: contains "SC-2", "AD-13", "tier-2 snip", "quick_knowledge_token_budget".
   - Output: `RESULT: SC-2 pass` or `RESULT: SC-2 fail <reason>`. Exit 0 on pass.

3. **Author `tests/m031-acceptance/test-compression-applies-to-quick.sh` (SC-3 per AD-17).** Bash 3.2-compatible, executable. Behavior:
   - Read M018 tier-1 `inline_threshold_tokens` from `references/RUNTIME-ASSUMPTIONS.md` and from `templates/orchestrator-config-default.yml` (canonical value 1500 per P00). The test MUST construct a payload that exceeds this threshold (AD-17 prescriptive contract — no vacuous sub-threshold pass).
   - The simplest construction: pass a corpus fixture whose Quick-profile assembly yields a tool-result block exceeding 1500 tokens. If no corpus fixture naturally yields one, synthesize a temp fixture in `/tmp/` containing a deliberately oversized inline tool-result block.
   - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <fixture-path> --out /tmp/m031-p01-t03-sc3-payload.md --meta-out /tmp/m031-p01-t03-sc3-meta.json`.
   - Assert exit 0.
   - Assert the JSONL stream contains AT LEAST ONE tier-1 paging record (M018 tier-1 emission convention; look for `{"event":"tier1_replace", ...}` or `{"compressed":"tier1", ...}`).
   - Assert the JSONL stream contains AT LEAST ONE tier-2 snip record.
   - Assert `compression_applied` in the meta sidecar JSON is `true`.
   - File header: contains "SC-3", "AD-17", "inline_threshold_tokens", "1500".
   - Output: `RESULT: SC-3 pass` or `RESULT: SC-3 fail <reason>`. Exit 0 on pass.

4. **Author `tests/m031-acceptance/test-quick-budget-median.sh` (SC-15 per AD-18).** Bash 3.2-compatible, executable. Behavior:
   - Read `quick_knowledge_token_budget` from `templates/orchestrator-config-default.yml`.
   - For each `task-NN.txt` in `tests/m031-acceptance/fixtures/empirical-baseline/` (sorted, exactly 20 expected): invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <path> --out /tmp/m031-p01-t03-sc15-payload-<id>.md --meta-out /tmp/m031-p01-t03-sc15-meta-<id>.json`. Append the meta sidecar's `total_tokens` value to a tally file `/tmp/m031-p01-t03-sc15-tokens.txt`.
   - Compute the median (lower-middle for even-N to avoid bash 3.2 floating-point math, per the P00 harness convention — sort ascending, take the 10th value of 20).
   - Assert median ≤ `quick_knowledge_token_budget`.
   - File header: contains "SC-15", "AD-18", "median", "quick_knowledge_token_budget".
   - Output: `RESULT: SC-15 pass median=<int> budget=<int>` or `RESULT: SC-15 fail median=<int> budget=<int>`. Exit 0 on pass.
   - **Note**: SC-15 tracks `total_tokens` from the sidecar as the proxy for `knowledge_section_tokens` per the P00 emitter contract (T02's emitter uses the same proxy). If the build-context.sh emits a separate `knowledge_section_tokens` field in the meta sidecar (additive per AD-11), SC-15 SHOULD prefer that field; otherwise it uses `total_tokens` as the conservative proxy.

5. **Author `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `tests/m031-acceptance/test-quick-injects-knowledge.sh` exists and is executable.
   - Assert the file contains the literal substrings "SC-1", "knowledge_section_tokens", "payload_breakdown".
   - Run the script and assert it exits 0.
   - Output: `SUMMARY: m031-p01-test-quick-injects-knowledge-shape.sh pass=N fail=M`. Exit 0 iff fail=0.

6. **Author `tools/verify/m031-p01-test-build-context-profile-shape.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `tests/m031-acceptance/test-build-context-profile.sh` exists and is executable.
   - Assert the file contains the literal substrings "SC-2", "AD-13", "tier-2 snip", "quick_knowledge_token_budget".
   - Run the script and assert it exits 0.
   - Output: `SUMMARY: m031-p01-test-build-context-profile-shape.sh pass=N fail=M`. Exit 0 iff fail=0.

7. **Author `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `tests/m031-acceptance/test-compression-applies-to-quick.sh` exists and is executable.
   - Assert the file contains the literal substrings "SC-3", "AD-17", "inline_threshold_tokens", "1500".
   - Run the script and assert it exits 0.
   - Output: `SUMMARY: m031-p01-test-compression-applies-to-quick-shape.sh pass=N fail=M`. Exit 0 iff fail=0.

8. **Author `tools/verify/m031-p01-test-quick-budget-median-shape.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `tests/m031-acceptance/test-quick-budget-median.sh` exists and is executable.
   - Assert the file contains the literal substrings "SC-15", "AD-18", "median", "quick_knowledge_token_budget".
   - Run the script and assert it exits 0.
   - Output: `SUMMARY: m031-p01-test-quick-budget-median-shape.sh pass=N fail=M`. Exit 0 iff fail=0.

9. **Run all four acceptance scripts and all four shape verifiers locally** to confirm exit 0 on each.

## Must-Haves

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "tests/m031-acceptance/test-quick-injects-knowledge.sh (SC-1) exists, is executable, and exits 0" (Truth #6; Check via `m031-p01-test-quick-injects-knowledge-shape.sh`)
- "tests/m031-acceptance/test-build-context-profile.sh (SC-2 per AD-13)" (Truth #7; Check via `m031-p01-test-build-context-profile-shape.sh`)
- "tests/m031-acceptance/test-compression-applies-to-quick.sh (SC-3 per AD-17)" (Truth #8; Check via `m031-p01-test-compression-applies-to-quick-shape.sh`)
- "tests/m031-acceptance/test-quick-budget-median.sh (SC-15 per AD-18)" (Truth #9; Check via `m031-p01-test-quick-budget-median-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
```

```bash
bash tools/verify/m031-p01-test-build-context-profile-shape.sh
```

```bash
bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
```

```bash
bash tools/verify/m031-p01-test-quick-budget-median-shape.sh
```

## Notes

- Each shape verifier follows the AD-15 corpus-driven verification pattern (the SC tests reference the empirical-baseline corpus at `tests/m031-acceptance/fixtures/empirical-baseline/`).
- The four SC scripts emit `RESULT: SC-N pass` / `RESULT: SC-N fail`, while the verifiers emit `SUMMARY: <verifier> pass=N fail=M`. Two distinct envelope conventions; both are AD-19-compliant single-script invocations.
- M018 tier-1 / tier-2 emission record names: read the canonical names from existing M018 emission code (`scripts/lib/payload-transforms.sh` and the build-context.sh body). The exact record key may be `event:"tier1_replace"` or `compressed:"tier1"` depending on the M018 implementation; tests MUST grep on the actual key, not on a guessed key.
- Median computation in SC-15: lower-middle of even-N (10th element of 20 sorted ascending) avoids bash 3.2 floating-point arithmetic, mirroring the P00 harness pattern (manifest pass-rate uses fixed-point integer comparison for the same reason).
- D020 token hygiene (CON-7): all authored prose MUST avoid the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (from T01) — invoked by all four SC scripts:
  - **Key API**: `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <path> --out <path> --meta-out <path>`
  - **Behavioral contract**: exit 0; emits assembled payload + JSON sidecar + JSONL `payload_breakdown` records.
- `commands/dispatch.md` (from T02) — no longer carries the skip branch; SC-1 implicitly verifies the post-FR-4 dispatch.md state by relying on knowledge-injection actually happening.
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` (from T02) — 20-record post-M031 baseline. SC-15 reads it (or invokes build-context.sh again for fresh emission, equivalent).

### From Disk (Pre-existing)

- `tests/m031-acceptance/fixtures/empirical-baseline/task-NN.txt` (P00) — 20 corpus task fixtures.
- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` (P00) — corpus stratification metadata.
- `templates/orchestrator-config-default.yml` (P00) — declares `quick_knowledge_token_budget: 800`, `compression.tier1.inline_threshold_tokens: 1500`, `compression.tier1.enabled: true`, `compression.tier2.enabled: true`.
- `references/RUNTIME-ASSUMPTIONS.md` (P00) — documents M018 tier-1 `inline_threshold_tokens=1500` (AD-17 P00 precondition).
- `scripts/lib/payload-transforms.sh` — pure-function lib for compression-tier emission. Read to confirm the canonical M018 emission record key names.

## Constraints

- **Bash 3.2 compatibility** (MEM001).
- **No edits to T01 or T02 deliverables** (build-context.sh, commands/dispatch.md, the post-m031 emitter, post-m031-baseline.jsonl). T03 is purely additive (new SC scripts + new shape verifiers).
- **No edits to `templates/orchestrator-config-default.yml`** (P00 owns the M031 knobs).
- **No edits to `references/RUNTIME-ASSUMPTIONS.md`** (P00 owns the M018 tier-1 threshold doc).
- **SC-12 scope-guard**: T03 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
- **Verifier path discipline**: all new verifiers under `tools/verify/m031-p01-*.sh`; SC scripts under `tests/m031-acceptance/`.
- **Prescriptive fixture (AD-17)**: SC-3's fixture MUST construct a payload exceeding the M018 tier-1 threshold. A vacuous sub-threshold pass is a known false-pass shape and must be guarded against.

## Expected Output

After T03 completes:

1. Four SC acceptance scripts under `tests/m031-acceptance/`:
   - `test-quick-injects-knowledge.sh` (SC-1)
   - `test-build-context-profile.sh` (SC-2 / AD-13)
   - `test-compression-applies-to-quick.sh` (SC-3 / AD-17)
   - `test-quick-budget-median.sh` (SC-15 / AD-18)
2. Four shape verifiers under `tools/verify/`:
   - `m031-p01-test-quick-injects-knowledge-shape.sh`
   - `m031-p01-test-build-context-profile-shape.sh`
   - `m031-p01-test-compression-applies-to-quick-shape.sh`
   - `m031-p01-test-quick-budget-median-shape.sh`
3. All four shape verifiers exit 0 (which transitively confirms all four SC scripts exit 0).

T03 leaves the system with all four P01-owned SC contracts mechanically gated. T04 chains them into a phase-suite aggregator + adds the SC-12 scope-guard.
