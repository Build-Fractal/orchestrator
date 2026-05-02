---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M031"
name: "Corpus authorship + pre-M031 stub + RUNTIME-ASSUMPTIONS + pinned defaults"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `specs/034-right-sized-entry/spec.md` carries the folded AD-1..AD-20 + renumbered SC vocabulary. Confirm via `bash tools/verify/p00-spec-foldin-shape.sh` exiting 0.
- `tests/m031-acceptance/` directory may not yet exist; create via `mkdir -p tests/m031-acceptance/fixtures/empirical-baseline` if absent.
- `references/RUNTIME-ASSUMPTIONS.md` exists at repo root (seeded by M018 / M030 for cross-runtime parity documentation). Confirm via `[ -f references/RUNTIME-ASSUMPTIONS.md ]`.
- `templates/orchestrator-config-default.yml` exists. Confirm via `[ -f templates/orchestrator-config-default.yml ]`. As of P00 plan time, this file already declares `auto_proceed: true` (line 27); FR-16/AD-8's flip is therefore a documentation-ratification job for P04, not a knob-flip task — T02 only ADDS three new knobs.
- `tools/verify/` exists (created by T01).

## Description

Build the AD-15-stratified 20-task fixture corpus, the AD-14-frozen pre-M031 stub script, the RUNTIME-ASSUMPTIONS update documenting the M018 tier-1 inline_threshold_tokens value (AD-17), and the three new config defaults pinned in `templates/orchestrator-config-default.yml`. Ship the four corresponding verifiers (`p00-corpus-manifest-shape.sh`, `p00-corpus-population.sh`, `p00-pre-stub-shape.sh`, `p00-runtime-assumptions-foldin.sh`, `p00-config-defaults-pinned.sh`).

Critical AD-14 invariant: the pre-M031 stub MUST be authored BEFORE T03 captures the pre-baseline JSONL, AND that capture MUST happen BEFORE any P01 work modifies `commands/dispatch.md:21` or `scripts/dispatch/build-context.sh`. T02 ships the stub; T03 invokes it once to freeze the JSONL. After P01 merges, the stub's emission is the only window into pre-M031 behavior — there is no second capture opportunity.

The 20-task corpus stratification per AD-15:
- **5 historical-JSONL-derived tasks** drawn from `.orchestrator/milestones/M*/execution-log.jsonl` `unit_close` records: 2 high-cost (high token / re-dispatch count), 2 medium-cost, 1 low-cost. The "cost class" annotation is derived from existing JSONL fields (`total_tokens`, `re_dispatch_count` if present). Provenance: `<milestone>/<phase>/<task>` id triple per entry.
- **5 synthetic edge-case tasks**: empty (no touched files), 1-file, 5-file, 10-file, doc-only (markdown-only diff). Each as a standalone fixture file under `fixtures/empirical-baseline/task-NN.txt`.
- **10 spread across ≥3 categories**: bugfix, doc, feature. Mix of historical and synthetic. Each entry tagged with its `category` field.

Total = 20. The manifest declares each entry's `task_id` + `category` + `cost_class` + `provenance` + `rationale`.

## Steps

1. **Author `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md`** with this structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: empirical-baseline-corpus
   milestone: "M031"
   phase: "P00"
   created_at: "2026-05-01"
   stratification_constraint: "AD-15"
   ---

   # M031 Empirical Baseline Corpus

   Stratification per AD-15 (CONTEXT.md):
   - 5 historical-JSONL-derived tasks: 2 high-cost, 2 medium-cost, 1 low-cost
   - 5 synthetic edge-case tasks: empty / 1-file / 5-file / 10-file / doc-only
   - 10 spread across ≥3 categories (bugfix / doc / feature)
   - Total: 20 entries

   Each entry's `task_id` corresponds to `task-NN.txt` under this directory.
   `pre-m031-stub.sh` reads each fixture and emits one JSONL record to
   `pre-m031-baseline.jsonl` (frozen at P00 close per AD-14 single-window).

   ## Entries

   | task_id   | category | cost_class | provenance                                 | rationale |
   |-----------|----------|------------|--------------------------------------------|-----------|
   | task-01   | bugfix   | high       | M020/P03/T02 (historical)                  | High re-dispatch count; touched 8 files; representative high-cost rediscovery shape |
   | task-02   | bugfix   | high       | M027/P02/T01 (historical)                  | High token total; multi-subsystem touch; representative |
   | task-03   | feature  | medium     | M025/P01/T03 (historical)                  | Medium cost; 3-file touch |
   | task-04   | doc      | medium     | M020/P05/T01 (historical)                  | Medium cost; doc + script |
   | task-05   | bugfix   | low        | M028/P01/T02 (historical)                  | Low cost; 1-file touch |
   | task-06   | feature  | n/a        | synthetic (empty)                          | Edge: no touched files; degenerate plan |
   | task-07   | bugfix   | n/a        | synthetic (1-file)                         | Edge: smallest non-degenerate |
   | task-08   | feature  | n/a        | synthetic (5-file)                         | Edge: medium fan-out |
   | task-09   | feature  | n/a        | synthetic (10-file)                        | Edge: largest fan-out |
   | task-10   | doc      | n/a        | synthetic (doc-only)                       | Edge: markdown-only diff |
   | task-11   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
   | task-12   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
   | task-13   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
   | task-14   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
   | task-15   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
   | task-16   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
   | task-17   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
   | task-18   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
   | task-19   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
   | task-20   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
   ```

   The historical-task `provenance` strings are placeholders pending the executor's actual JSONL sweep — the executor MUST replace `M020/P03/T02 (historical)` etc. with real `<milestone>/<phase>/<task>` ids drawn from the on-disk `execution-log.jsonl` records, with cost-class derived from observed `total_tokens` / `re_dispatch_count` fields. The five chosen historical entries' rationale strings MUST cite the JSONL field that justified the cost class.

2. **Author the 20 fixture files** at `tests/m031-acceptance/fixtures/empirical-baseline/task-NN.txt` for `NN` ∈ `01..20`. Each file is a minimal task-plan-shaped input the pre-M031 stub can read:

   ```
   # task-NN
   category: <bugfix|doc|feature>
   cost_class: <high|medium|low|n/a>
   touched_files: <comma-separated paths or empty>
   description: <one-line plain-text task description>
   ```

   Historical entries (task-01..task-05) source their fields from the `execution-log.jsonl` record. Synthetic entries (task-06..task-20) have plausible-but-fictional fields scoped to the category.

3. **Author `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh`.** Bash 3.2-compatible, executable (`chmod +x`). Behavior:
   - Argument 1: path to a `task-NN.txt` fixture. Required.
   - Read the fixture; extract `task_id` (basename without `.txt`), `category`, `cost_class`, `touched_files`.
   - Compute `total_task_tokens` per the pre-M031 model: a rough proxy combining `len(touched_files) * 1500` (the per-file rediscovery estimate) + a fixed overhead (`500` for plan delivery). For synthetic empty (`task-06`), return the overhead floor (`500`). The exact constants are documented in the script header so future readers can audit; the values approximate observed pre-M031 Quick costs without requiring a live capture.
   - Emit one JSONL line on stdout:

     ```json
     {"task_id":"task-NN","path":"pre-m031","knowledge_section_tokens":0,"compression_applied":false,"snip_applied":false,"total_task_tokens":<int>,"verifier_pass":true}
     ```

     `verifier_pass` is hard-coded `true` for the stub — the pre-M031 path's pass rate is the baseline against which the post-M031 path is measured for "equal-or-higher" per CON-5/AD-4. P01 first task captures the actual post-M031 pass rate; T03's harness compares them.
   - Exit 0 on success; exit 1 with stderr diagnostic on missing/malformed fixture.
   - File header documents AD-14 single-window discipline and that the stub MUST NOT call `scripts/dispatch/build-context.sh` (the P01 surface).

4. **Update `references/RUNTIME-ASSUMPTIONS.md`** by appending a new section per AD-17:

   ```markdown
   ## M018 Tier-1 inline_threshold_tokens (P00 precondition)

   The M018 compression layer's tier-1 microcompact threshold is sourced from the
   active orchestrator config: `compression.tier1.inline_threshold_tokens`. The
   default value pinned in `templates/orchestrator-config-default.yml:87` is
   `1500` tokens (P00 plan time, 2026-05-01).

   Consuming SC: SC-3 (M031, amended per AD-17) — the test fixture under
   `tests/m031-acceptance/test-compression-applies-to-quick.sh` MUST construct a
   Quick-profile payload exceeding this threshold so tier-1 records reliably emit.
   The constructed payload's body-tokens minimum is `inline_threshold_tokens + 1`;
   the canonical fixture rounds to `1700` for cushion.

   Resolution path at runtime: `compression.tier1.inline_threshold_tokens` in the
   project's active `.orchestrator/config.yml` (or the bundled
   `templates/orchestrator-config-default.yml` if the project hasn't customized).
   M009 (multi-runtime parity, deferred post-launch) is the milestone that
   verifies non-CC runtimes resolve the same value.
   ```

   This section is APPENDED to existing RUNTIME-ASSUMPTIONS.md content; do not delete or reorder existing sections.

5. **Update `templates/orchestrator-config-default.yml`** by appending the three new knobs to an appropriate section (e.g., a new `# M031 — Right-sized entry` block at the file tail, or fold into the existing structure where a sibling section exists). Required additions:

   ```yaml
   # M031 — Right-sized entry (knowledge + compression unconditional, Tier A+ flow,
   # universal entry). Knobs pinned by P00 empirical baseline; AD-5 / OQ-4 / AD-20.
   quick_knowledge_token_budget: 800            # FR-5 / AD-5 — advisory ceiling for Quick-profile knowledge inject; M018 tier-2 snip enforces.
   entry_routing_confidence_floor: 0.7          # FR-11 / OQ-4 — universal-entry classifier confidence below which the operator is prompted Tier A vs Tier B.
   tier_a_plus_prompt_summary_lines: 8          # AD-20 — number of leading lines of research.md rendered inline in the Tier A+ pre-plan approval prompt.
   ```

   Each knob has an inline comment naming the M031 FR or AD that owns it. Indentation: top-level (no nesting), matching the `auto_proceed` declaration at line 27 of the existing template.

6. **Author `tools/verify/p00-corpus-manifest-shape.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md`.
   - Check 1: file exists.
   - Check 2: frontmatter contains `schema_version: "1.0"`, `type: empirical-baseline-corpus`, `milestone: "M031"`, `phase: "P00"`, `created_at`, `stratification_constraint: "AD-15"`.
   - Check 3: body declares the AD-15 stratification: `grep -q '5 historical' "$file"`, `grep -q '5 synthetic' "$file"`, `grep -q '10 spread' "$file"`.
   - Check 4: count of pipe-separated table rows under `## Entries` is ≥20 (one per task). Use `grep -c '^| task-' "$file"`.
   - On pass, emit `SUMMARY: p00-corpus-manifest-shape.sh pass=4 fail=0`, exit 0.

7. **Author `tools/verify/p00-corpus-population.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/fixtures/empirical-baseline/`.
   - Check 1: directory exists.
   - Check 2: count of `task-*.txt` files is exactly 20. Use `find "$dir" -maxdepth 1 -name 'task-*.txt' -type f`. Pipe to `wc -l`. (Direct find-to-wc; no `$()` containing pipe — use a tmp file.)
   - On pass, emit `SUMMARY: p00-corpus-population.sh pass=2 fail=0`, exit 0.

8. **Author `tools/verify/p00-pre-stub-shape.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh`.
   - Check 1: file exists.
   - Check 2: file is executable (`[ -x "$file" ]`).
   - Check 3: file body asserts AD-14 discipline by NOT calling `scripts/dispatch/build-context.sh` (`grep -q 'build-context.sh' "$file"` returns NON-zero — invert as in T01's verifier check 7).
   - Check 4: file contains the pre-M031 JSONL emission keys (`grep -q '"path":"pre-m031"' "$file"`, `grep -q 'knowledge_section_tokens' "$file"`).
   - Check 5: stub is invokable — runs cleanly against the first fixture file and emits valid JSONL on stdout. Use a single-script-file invocation: `bash "$file" tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` and check stdout matches the expected shape via `grep -q '"task_id":"task-01"'`.
   - On pass, emit `SUMMARY: p00-pre-stub-shape.sh pass=5 fail=0`, exit 0.

9. **Author `tools/verify/p00-runtime-assumptions-foldin.sh`.** Bash 3.2. Behavior:
   - Path default: `references/RUNTIME-ASSUMPTIONS.md`.
   - Check 1: file exists.
   - Check 2: contains `## M018 Tier-1 inline_threshold_tokens` header.
   - Check 3: contains the threshold value `1500`.
   - Check 4: cites `templates/orchestrator-config-default.yml` as the source.
   - Check 5: cites `SC-3` and `AD-17`.
   - On pass, emit `SUMMARY: p00-runtime-assumptions-foldin.sh pass=5 fail=0`, exit 0.

10. **Author `tools/verify/p00-config-defaults-pinned.sh`.** Bash 3.2. Behavior:
    - Path default: `templates/orchestrator-config-default.yml`.
    - Check 1: file exists.
    - Check 2: declares `quick_knowledge_token_budget: 800` (`grep -qE '^quick_knowledge_token_budget:\s*800' "$file"`).
    - Check 3: declares `entry_routing_confidence_floor: 0.7` (`grep -qE '^entry_routing_confidence_floor:\s*0\.7' "$file"`).
    - Check 4: declares `tier_a_plus_prompt_summary_lines: 8` (`grep -qE '^tier_a_plus_prompt_summary_lines:\s*8' "$file"`).
    - Check 5: each knob's line has an FR or AD reference comment.
    - On pass, emit `SUMMARY: p00-config-defaults-pinned.sh pass=5 fail=0`, exit 0.

11. **Run all five verifiers as a self-check.** From repo root, in sequence:

    ```bash
    bash tools/verify/p00-corpus-manifest-shape.sh
    bash tools/verify/p00-corpus-population.sh
    bash tools/verify/p00-pre-stub-shape.sh
    bash tools/verify/p00-runtime-assumptions-foldin.sh
    bash tools/verify/p00-config-defaults-pinned.sh
    ```

    All five must exit 0. Fix any failure before handing off to T03.

## Must-Haves

This task satisfies the phase truths:
- "CORPUS-MANIFEST.md exists [...] declaring 20 entries stratified per AD-15".
- "corpus directory contains exactly 20 task-fixture inputs".
- "pre-m031-stub.sh exists, is executable, and freezes the pre-M031 dispatch path semantics".
- "RUNTIME-ASSUMPTIONS.md documents the M018 tier-1 inline_threshold_tokens default".
- "templates/orchestrator-config-default.yml declares the three M031 knobs with pinned defaults".

## Verification

```bash
bash tools/verify/p00-corpus-manifest-shape.sh
bash tools/verify/p00-corpus-population.sh
bash tools/verify/p00-pre-stub-shape.sh
bash tools/verify/p00-runtime-assumptions-foldin.sh
bash tools/verify/p00-config-defaults-pinned.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` and exits 0 on green.

## Inputs

### From Previous Tasks

- `specs/034-right-sized-entry/spec.md` (from T01)
  - Key API: pinned SC vocabulary — `SC-2` / `SC-3` / `SC-11` / `SC-13` / `SC-14` / `SC-15` / `SC-16` referenced by name in CORPUS-MANIFEST.md and RUNTIME-ASSUMPTIONS.md
  - Key types: AD-14 (single-window discipline), AD-15 (corpus stratification), AD-17 (M018 tier-1 threshold documentation)
- `tools/verify/p00-spec-foldin-shape.sh` (from T01) — referenced as a sibling verifier in T03's phase suite.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M*/execution-log.jsonl` — source of historical task records. T02 sweeps these to derive task-01..task-05 cost-class annotations and the milestone/phase/task provenance triples.
- `references/RUNTIME-ASSUMPTIONS.md` — existing file with prior runtime-parity content; T02 appends without modifying existing sections.
- `templates/orchestrator-config-default.yml` — existing template (already declares `auto_proceed: true` at line 27, `compression.tier1.inline_threshold_tokens: 1500` at line 87). T02 appends three new top-level knobs.
- `commands/dispatch.md` — T02 reads line 21 (the pre-M031 Quick-skip language) to confirm the stub correctly freezes the pre-M031 semantics by exclusion.

## Constraints

- **AD-14 single-window discipline**: the stub MUST NOT call `scripts/dispatch/build-context.sh`. The pre-M031 path is defined as the path that skips it; the stub freezes that semantic. The `p00-pre-stub-shape.sh` check 3 enforces this with an inverted grep.
- **20-task floor**: the corpus has exactly 20 entries (not 19, not 21). AD-15's stratification arithmetic (5 + 5 + 10) sums to 20.
- **Synthetic-vs-historical labeling**: each manifest entry's `provenance` field unambiguously distinguishes historical from synthetic. Historical entries cite a real `<milestone>/<phase>/<task>` triple; synthetic entries say `synthetic (<edge-case>)`.
- **Bash 3.2 compatibility for verifiers**: no `mapfile`, no `declare -A`, no process substitution.
- **Single-script-file Truth Check shape (AD-19)**: every verifier is a standalone script.
- **Idempotent re-runs**: every verifier MUST exit 0 on subsequent runs against the same green disk state. No verifier writes to disk.
- **D020 token hygiene (CON-7)**: in CORPUS-MANIFEST.md and RUNTIME-ASSUMPTIONS.md prose, paraphrase as "scaffold-placeholder marker" rather than embedding the literal open-bracket-TODO byte pattern in backticked inline code.
- **No P01 surface modifications**: T02 MUST NOT touch `scripts/dispatch/build-context.sh` or `commands/dispatch.md`. Those are P01 deliverables; touching them at P00 violates AD-14's single-window capture (the pre-M031 records must be captured BEFORE those files change).

## Expected Output

- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` — manifest with 20 stratified entries.
- `tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` through `task-20.txt` — 20 fixture inputs.
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` — executable, ≥30 lines.
- `references/RUNTIME-ASSUMPTIONS.md` — appended `## M018 Tier-1 inline_threshold_tokens` section.
- `templates/orchestrator-config-default.yml` — three new knobs at top level with FR/AD comments.
- `tools/verify/p00-corpus-manifest-shape.sh` — ≥40 lines.
- `tools/verify/p00-corpus-population.sh` — ≥25 lines.
- `tools/verify/p00-pre-stub-shape.sh` — ≥25 lines.
- `tools/verify/p00-runtime-assumptions-foldin.sh` — ≥25 lines.
- `tools/verify/p00-config-defaults-pinned.sh` — ≥30 lines.
- All five verifiers exit 0 against the T02-close disk state.

## Notes

Expected verifier output examples (for human readers):
- `bash tools/verify/p00-corpus-manifest-shape.sh` → `SUMMARY: p00-corpus-manifest-shape.sh pass=4 fail=0`, exit 0.
- `bash tools/verify/p00-corpus-population.sh` → `SUMMARY: p00-corpus-population.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p00-pre-stub-shape.sh` → `SUMMARY: p00-pre-stub-shape.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p00-runtime-assumptions-foldin.sh` → `SUMMARY: p00-runtime-assumptions-foldin.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p00-config-defaults-pinned.sh` → `SUMMARY: p00-config-defaults-pinned.sh pass=5 fail=0`, exit 0.

The five `provenance` strings in CORPUS-MANIFEST.md (M020/P03/T02 etc.) shipped in this plan are PLACEHOLDERS. The executor MUST replace them with real `<milestone>/<phase>/<task>` ids drawn from on-disk `execution-log.jsonl` records. The plan does not pin specific historical tasks because the executor's sweep against current execution logs will produce a cleaner result than P00 plan-time guesses — and the cost-class annotations must come from observed JSONL fields (`total_tokens`, `re_dispatch_count` if present) rather than planner guesses.

`auto_proceed: true` already lives at line 27 of `templates/orchestrator-config-default.yml` (verified at P00 plan time). FR-16 / AD-8's "flip from `false` to `true`" is therefore a *documentation-ratification* job for P04 (CHANGELOG entry naming the compound change) rather than a knob-flip task. T02 does not touch `auto_proceed` — only adds the three new knobs.
