---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M031"
name: "Spec-body fold-in (AD-1..AD-20 → spec.md)"
depends_on: []
---

## Prerequisites

- Working tree at `~/Sites/spec-kit-orchestrator/` with `specs/034-right-sized-entry/spec.md` present and unchanged from the post-discuss state (status `Draft`, AD-* amendments present in `.orchestrator/milestones/M031/M031-CONTEXT.md` but NOT yet folded into the spec body — the operator-deferred fold per CONTEXT.md "Resolved meta-decisions: Spec amendment timing").
- `.orchestrator/milestones/M031/M031-CONTEXT.md` present and `status: finalized`. Confirm via `grep -q '^status: finalized' .orchestrator/milestones/M031/M031-CONTEXT.md` returning exit 0.
- `.orchestrator/milestones/M031/M031-ROADMAP.md` present (P00..P04 phase IDs pinned). Confirm via `[ -f .orchestrator/milestones/M031/M031-ROADMAP.md ]`.
- `tools/verify/` directory exists (created by earlier orchestrator phases) or will be created via `mkdir -p tools/verify` if absent.

## Description

Fold the 20 architectural-decision blocks (AD-1 through AD-20) and the cross-cutting meta-decisions from `.orchestrator/milestones/M031/M031-CONTEXT.md` into `specs/034-right-sized-entry/spec.md` so downstream phases reference SC numbers (SC-15, SC-16), AD numbers, and pinned phase IDs (P00..P04 from the roadmap) that exist on disk in the canonical spec.

The fold-in is in-place: spec.md is amended, not replaced. The original Open Questions / Gate Findings sections (lines 209–250 as of P00 plan time) are preserved verbatim as the audit trail; the AD bodies sit in a new top-level section that supersedes the gate-findings deferred items they resolve. The renumber rules:

- **SC-13** is replaced per AD-12 (Option B preferred — `verify-baseline-ordering.sh` git-history check; Option A fallback = reclassify as P00 protocol note when `git log` is unavailable, with N adjustment). The new SC-13 references the verifier T03 ships.
- **SC-15** is added per AD-18 (median absolute budget compliance, independent of pre-M031 baseline). Cross-references SC-2 (per-task ceiling) and SC-11 (relative comparison) for complementary coverage.
- **SC-16** is added per AD-20 (Tier A+ prompt UX integration test). Cross-references AD-7 (one-prompt design) and AD-10 (deterministic paths).
- **SC-14** updates from `N ≥ 13` to `N ≥ 15` reflecting the SC-15 + SC-16 additions (and SC-13 stays in the count under Option B; if T03 selects Option A based on CI environment, the harness adjusts to `N ≥ 14`).
- **SC-2** is rewritten per AD-13: the contradictory "within ±20%" clause is dropped; new gating is (a) tier-2 snip JSONL record at the budget boundary AND (b) final Knowledge section ≤ `quick_knowledge_token_budget`.
- **SC-3** is rewritten per AD-17: descriptive ("when the Quick payload exceeds tier thresholds") becomes prescriptive ("the test fixture MUST construct a payload exceeding M018 tier-1 thresholds"), with the threshold value documented in `references/RUNTIME-ASSUMPTIONS.md` (T02 work).
- **SC-11** is rewritten per AD-14: explicitly references the stored pre-M031 records at `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (T03 work) and the post-M031 records captured during P01 first-task work.

The AD bodies fold in as a new `## Architectural Decisions (folded post-discuss 2026-05-01)` section between `## Constitution Check` and `## Open Questions (defer to planning)`. Each AD-N entry preserves its CONTEXT.md prose verbatim and adds an inline citation `(originated in M031-CONTEXT.md AD-N)` so future readers can trace provenance.

## Steps

1. **Snapshot the pre-fold spec for diff sanity.** Copy `specs/034-right-sized-entry/spec.md` to `/tmp/m031-spec-pre-fold.md` (working artifact; not committed). This is your reference for what the fold-in changes vs. preserves.

2. **Read the source amendments** from `.orchestrator/milestones/M031/M031-CONTEXT.md`:
   - AD-1 through AD-20 (lines 14–67 of CONTEXT.md as of P00 plan time)
   - Cross-cutting meta-decisions from "Resolved meta-decisions" block (CONTEXT.md lines 127–130)
   - SC-15 (AD-18, CONTEXT.md ~line 50) and SC-16 (AD-20, CONTEXT.md ~line 65)

3. **Author the new `## Architectural Decisions (folded post-discuss 2026-05-01)` section** in `specs/034-right-sized-entry/spec.md`. Insert position: between the existing `## Constitution Check` section (currently ending around line 207) and the existing `## Open Questions (defer to planning)` section (currently starting around line 209). Section header text:

   ```markdown
   ## Architectural Decisions (folded post-discuss 2026-05-01)

   The 20 architectural decisions below were ratified during `orchestrator:discuss`
   (operator review 2026-05-01). They are folded into the spec body post-roadmap so
   they can reference pinned phase IDs (P00..P04 from `.orchestrator/milestones/M031/M031-ROADMAP.md`)
   and the renumbered SC vocabulary (SC-15 added per AD-18; SC-16 added per AD-20;
   SC-13 / SC-2 / SC-3 / SC-11 rewritten per AD-12/13/17/14). Original `## Open Questions`
   and `## Gate Findings` sections below are preserved verbatim as the audit trail
   for future readers.
   ```

   Then enumerate AD-1 through AD-20, each as a `### AD-N. <title>` subsection. For each AD, copy the CONTEXT.md prose verbatim and append an inline citation line: `*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-N)*`.

4. **Renumber and rewrite the affected SCs** in the existing `## Success Criteria` block (currently lines 127–142):
   - **SC-2** — replace its body with the AD-13 wording: "Run `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <fixture> --out /tmp/payload.md`. Exit 0. Resulting `/tmp/payload.md` Knowledge section is ≤ `quick_knowledge_token_budget` tokens AND a tier-2 snip JSONL record is emitted at the budget boundary when the source payload exceeds the budget. (No ±20% clause; AD-13 grounds enforcement in M018 tier-2 snip per FR-5's 'advisory ceiling' framing.)"
   - **SC-3** — replace its body with the AD-17 wording: "Run `bash tests/m031-acceptance/test-compression-applies-to-quick.sh`. Exit 0. The test fixture MUST construct a Quick-profile payload exceeding the M018 tier-1 `inline_threshold_tokens` value (documented in `references/RUNTIME-ASSUMPTIONS.md`). Asserts: tier-1 and tier-2 records appear in JSONL when the constructed payload meets the threshold."
   - **SC-11** — replace its body with the AD-14 wording: "Run `bash tests/m031-acceptance/empirical-baseline.sh --compare`. Exit 0. Reads stored pre-M031 records from `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (captured at P00 close per AD-14 single-window discipline) and post-M031 records emitted during P01 first-task work; asserts median post-M031 total task tokens < median pre-M031 AND verifier pass rate ≥. If the assertion fails, P01 redesigns before merge per CON-5."
   - **SC-13** — replace its body with the AD-12 wording: "Run `bash tests/m031-acceptance/verify-baseline-ordering.sh`. Exit 0 under Option B (the verifier asserts via `git log --diff-filter=A --follow` that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/` predates the first commit touching `scripts/dispatch/build-context.sh` and `commands/dispatch.md`). If `git log` is unavailable (shallow clone), Option A activates: SC-13 reclassifies as a P00 protocol note, drops from SC-14's count, and N reduces by 1. The active option is recorded in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`."
   - **SC-14** — replace `N ≥ 13` with `N ≥ 15` (SC-15 + SC-16 added; SC-13 stays under Option B; Option A fallback adjusts to `N ≥ 14`). Add a parenthetical: "(N ≥ 14 if SC13-OPTION.md records Option A.)"
   - **SC-15** (NEW per AD-18) — append to the SC list: "Run `bash tests/m031-acceptance/test-quick-budget-median.sh`. Exit 0. Asserts: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task corpus is ≤ `quick_knowledge_token_budget`, independent of the pre-M031 baseline. Complements SC-2 (per-task ceiling) and SC-11 (relative comparison)."
   - **SC-16** (NEW per AD-20) — append to the SC list: "Run `bash tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh`. Exit 0. Asserts: captured stdout/stderr from a Tier A+ flow includes (a) plain-language framing strings (no `null`, no JSON braces, no scaffold-placeholder bracket-TODO patterns), (b) the first `tier_a_plus_prompt_summary_lines` lines of the fixture `research.md` rendered inline, (c) all three named options visible (`y`/`n`/`c`), (d) the `(N more lines at <path>)` ellipsis when research exceeds budget, AND (e) when `--yes` is passed, the `research: <path>` audit-line appears on stderr."

5. **Author `tools/verify/p00-spec-foldin-shape.sh`.** Bash 3.2-compatible. Behavior:
   - Path argument default: `specs/034-right-sized-entry/spec.md`. Override via `$1`.
   - Check 1: file exists; print `FAIL: spec.md missing` and exit 1 if not.
   - Check 2: section header `## Architectural Decisions (folded post-discuss 2026-05-01)` is present. Use `grep -q '^## Architectural Decisions (folded post-discuss 2026-05-01)$' "$file"`.
   - Check 3: AD-1 through AD-20 headers (`### AD-1.` through `### AD-20.`) all present. Loop over numbers 1..20 and run `grep -q "^### AD-$i\\." "$file"` for each; tally pass/fail.
   - Check 4: SC-15 body present. Use `grep -q '^- \*\*SC-15' "$file"` (matches the `- **SC-15` list-item prefix used by the other SCs).
   - Check 5: SC-16 body present. Use `grep -q '^- \*\*SC-16' "$file"`.
   - Check 6: SC-14 declares `N ≥ 15` (or `N ≥ 14` under Option A). Use `grep -qE 'N ≥ 1[45]' "$file"`.
   - Check 7: AD-13 / SC-2 amendment landed: `grep -q '±20%' "$file"` returns NON-zero exit (i.e., the contradictory ±20% clause is GONE). Reject if present.
   - On success, emit `SUMMARY: p00-spec-foldin-shape.sh pass=7 fail=0` and exit 0.
   - On any failure, emit `SUMMARY: p00-spec-foldin-shape.sh pass=N fail=M` plus per-failure diagnostics, exit 1.
   - File must be ≥40 lines (phase plan artifact requirement).

6. **Run the verifier as a self-check.** From repo root:

   ```bash
   bash tools/verify/p00-spec-foldin-shape.sh
   ```

   Exit 0 expected. If any check fails, fix the spec (typos in AD headers, wrong SC numbering, etc.) and re-run.

## Must-Haves

This task satisfies the phase truth:
- "specs/034-right-sized-entry/spec.md contains AD-1..AD-20 folded in [...] adds SC-15 + SC-16 and updates SC-14 to N ≥ 15".

It also lays the SC-vocabulary foundation that T02's CORPUS-MANIFEST.md and T03's harness reference by name (SC-11 stored-records language; SC-15 median compliance; SC-16 prompt UX).

## Verification

```bash
bash tools/verify/p00-spec-foldin-shape.sh
```

Single-script-file shape per AD-19. Emits `SUMMARY: p00-spec-foldin-shape.sh pass=7 fail=0` and exits 0 on green.

## Inputs

### From Previous Tasks

- None (T01 is the head of P00).

### From Disk (Pre-existing)

- `specs/034-right-sized-entry/spec.md` — current spec body (Open Questions / Gate Findings sections lines 209–250 are preserved verbatim; this task amends the SC list and inserts the new AD section).
- `.orchestrator/milestones/M031/M031-CONTEXT.md` — authoritative source of AD-1..AD-20 prose. Each AD body in CONTEXT.md is folded verbatim into spec.md with provenance citation.
- `.orchestrator/milestones/M031/M031-ROADMAP.md` — authoritative source of pinned phase IDs (P00..P04). AD references to "P00" / "P01 first task" / "P02 exit criteria" / etc. are now grounded in disk-resident phase IDs.

## Constraints

- **In-place amendment, not replacement**: the original Open Questions / Gate Findings sections (currently lines 209–250) MUST be preserved verbatim. The AD section is inserted, not substituted.
- **Verbatim AD prose**: each AD-N body is copied from CONTEXT.md without paraphrasing. The provenance citation `*(originated in M031-CONTEXT.md AD-N)*` is appended below the AD body.
- **D020 todo-token hygiene (CON-7 / DC-8)**: when folding AD-20's prompt UX requirements, do NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code. Use "scaffold-placeholder marker" or paraphrase. (The conversus.sh gate adapter pre-flight refuses artifacts containing the pattern.)
- **Bash 3.2 compatibility for the verifier**: `tools/verify/p00-spec-foldin-shape.sh` MUST NOT use `mapfile`/`readarray`, `declare -A`, process substitution `<(...)`, `&>`, or `${var^^}`.
- **Single-script-file Truth Check shape (AD-19)**: the verifier is a standalone script invoked as `bash tools/verify/p00-spec-foldin-shape.sh`. No inline compound bash, no plain subshells, no `$(...)` containing a pipe.

## Expected Output

- `specs/034-right-sized-entry/spec.md` — amended in place: new `## Architectural Decisions (folded post-discuss 2026-05-01)` section with AD-1 through AD-20; SC-2 / SC-3 / SC-11 / SC-13 rewritten; SC-14 updated to `N ≥ 15`; SC-15 + SC-16 appended; original Open Questions / Gate Findings preserved.
- `tools/verify/p00-spec-foldin-shape.sh` — created, ≥40 lines, exits 0 on green spec.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-spec-foldin-shape.sh` → stdout ends with `SUMMARY: p00-spec-foldin-shape.sh pass=7 fail=0`, exit 0.

Per planner-template Section-Discipline rule, expected output stays under `## Notes` because everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.

The `±20%` removal in step 4 is NEGATIVE — the verifier asserts the substring is GONE. Step 5 check 7 inverts the usual `grep -q` pass/fail polarity; document this carefully in the verifier so a future maintainer reading it doesn't "fix" the inversion as a typo.
