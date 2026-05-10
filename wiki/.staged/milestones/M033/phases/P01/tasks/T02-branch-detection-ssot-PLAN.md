---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M033"
name: "references/branch-detection.md SSOT + parity verifier scaffold"
depends_on: []
---

## Prerequisites

- The `references/` directory exists with sibling docs (`installation.md`, `state-machine.md`, etc.) — verified by `[ -d references ]`.
- No file currently lives at `references/branch-detection.md` — verified by `[ ! -f references/branch-detection.md ]`.
- `tools/verify/` exists.
- The FR-2 / MIT-006 / RISK-006 / AD-4 spec entries are documented in the M033 spec body (planning payload). This task plan re-states the load-bearing rules inline so executors do not need to re-read the spec.

## Description

T02 ships `references/branch-detection.md` as the canonical SSOT for FR-2's deterministic branch-detection rules, and the cross-parity verifier `tools/verify/m033-p01-branch-detection-ssot-parity.sh` that asserts the patterns documented in the SSOT byte-match the patterns implemented in `scripts/lifecycle/start.sh` (authored by T03).

**The SSOT is consumed by P02..P05 sub-flow phases when they extend branch-detection** (e.g., P03's codebase-ingestion may add a rule-3 sub-classification by detected language). Establishing the SSOT in P01 — before any sub-flow code references it — is the load-bearing decision: it forces every later phase's branch-detection logic to round-trip through this document, preserving auditability.

**Parity contract.** The verifier extracts the pattern strings from the SSOT (via grep against fenced code blocks named `branch-detection-rule-N`) and asserts those exact strings appear in `scripts/lifecycle/start.sh`. T03's start.sh uses the same patterns verbatim; any future drift between SSOT and implementation fails the verifier. The verifier runs after T03 lands (because it cross-checks against `start.sh`), but its **scaffold + the SSOT itself ship in T02**. T02's verifier wraps the cross-check in a `[ -f scripts/lifecycle/start.sh ] || skip` gate so it can be authored before T03 without false-failing during T02's own dev loop.

## Steps

1. **Create `references/branch-detection.md`** (≥90 lines). The document must contain the following sections (verifier asserts each as a top-level header):

   - `# Branch Detection` (H1)
   - `## Purpose` — explains the SSOT role; names FR-2 / US-1 / `scripts/lifecycle/start.sh` as consumers.
   - `## Branch Names` — the four-name closed enum: `greenfield-empty`, `greenfield-with-materials`, `existing-codebase`, `migrating`. One paragraph per branch describing the user posture.
   - `## Detection Rules (Deterministic, Ordered)` — the load-bearing section. The four rules in priority order. Each rule is presented with: a numbered header (`### Rule 1: migrating`, `### Rule 2: greenfield-with-materials`, `### Rule 3: existing-codebase`, `### Rule 4: greenfield-empty`), a one-line trigger summary, and a fenced code block named `branch-detection-rule-N` containing the literal regex/glob pattern that the implementing script tests.

     Required pattern strings (the executor authors these into the fenced blocks AND into start.sh; the verifier cross-checks they match):

     ```
     # branch-detection-rule-1: migrating
     prior_tooling_globs: .gsd/ .gsd2/ .specify/

     # branch-detection-rule-2: greenfield-with-materials
     pbj_md_glob: *BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md
     pbj_md_min_count: 3
     pbj_md_no_src_required: true

     # branch-detection-rule-3: existing-codebase
     src_dir: src/
     source_extensions: .js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h
     source_root_min_count: 10
     git_min_commits: 1

     # branch-detection-rule-4: greenfield-empty
     trigger: fallback (no rules 1-3 fired)
     ```

   - `## Ambiguity Handling` — documents the two ambiguous-signal cases that fire the disambiguation question per US-1 AS-5: (a) rule-1 + rule-3 both match (`migrating` wins by ordering, but operator confirms); (b) rule-3 fires solely because `.git/` has ≥1 commit AND project has ≤9 source files AND no prior-tooling artifacts (the MIT-006 / RISK-006 case — recommended branch is `greenfield-empty`). Each case is documented with: trigger condition, recommendation, and example fixture shape.
   - `## --branch Override` — documents the operator override contract: `--branch greenfield-empty | greenfield-with-materials | existing-codebase | migrating` skips detection, with a stderr `branch-override:` diagnostic if detection would have produced a different name.
   - `## Cross-References` — names the implementing script (`scripts/lifecycle/start.sh`), the spec entries (FR-2, MIT-006, RISK-006, AD-4), and the consumers (P02..P05 sub-flow phases that may extend detection).

2. **Author `tools/verify/m033-p01-branch-detection-ssot-parity.sh`** (≥30 lines, executable). The verifier:

   - First gates on existence of both files: if `[ ! -f references/branch-detection.md ]`, FAIL with `references/branch-detection.md missing`. If `[ ! -f scripts/lifecycle/start.sh ]`, emit `SKIP: scripts/lifecycle/start.sh not yet authored (T03 deliverable)` and exit 0 — this lets the verifier be co-authored in T02 without false-failing before T03 lands. The skip MUST emit `SKIP:` (NOT `PASS:`) so the phase-suite aggregator can distinguish it.
   - When both files exist, the verifier asserts every pattern string documented in the four `branch-detection-rule-N` fenced blocks of the SSOT also appears literally somewhere in `scripts/lifecycle/start.sh`. Use `grep -F` (fixed-string match) to avoid regex escaping ambiguity. Asserted strings: the prior-tooling globs, the PBJ markdown glob, the source-extension list, the source-root min count, the git min commits.
   - Asserts the four branch names appear literally in both files.
   - Emits `PASS:` per assertion and a final `SUMMARY: m033-p01-branch-detection-ssot-parity.sh pass=N fail=M skip=K` line. Exit 0 iff fail=0.

## Must-Haves

This task addresses these P01 phase truths:
- `references/branch-detection.md` exists as the SSOT.
- The patterns documented in the SSOT byte-match the patterns implemented in `scripts/lifecycle/start.sh` (cross-check enforced by `m033-p01-branch-detection-ssot-parity.sh`).

This task creates these P01 phase artifacts:
- SSOT reference: `references/branch-detection.md` (canonical 4 branch-detection rules + pattern strings).
- Parity verifier: `tools/verify/m033-p01-branch-detection-ssot-parity.sh` (byte-cross-check SSOT ↔ start.sh; emits `SKIP:` until T03 lands).

## Verification

```bash
bash tools/verify/m033-p01-branch-detection-ssot-parity.sh
```

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `references/` — sibling reference docs follow the H1 + `## Purpose` + section convention; T02 mirrors that shape.
- The M033 spec body under FR-2, MIT-006, RISK-006, AD-4 — restated inline in this task plan's Description and Steps.

## Constraints

- The pattern strings authored into the SSOT fenced blocks MUST be the literal strings start.sh greps against. No paraphrasing, no re-formatting. The parity verifier uses `grep -F` to enforce byte-match.
- The four branch names are a closed enum — `greenfield-empty | greenfield-with-materials | existing-codebase | migrating`. Adding a fifth in P01 is out of scope (the spec's NG list defines this enum as v1).
- The SSOT MUST NOT contain executable code, only documentation. Implementation lives in `scripts/lifecycle/start.sh` (T03).
- The parity verifier MUST emit `SKIP:` (not `PASS:`) when `start.sh` does not yet exist. The phase-suite aggregator (T05) treats SKIP as non-fail-non-pass so the verifier can be co-authored before T03 lands.

## Expected Output

After T02 completes:
- `references/branch-detection.md` exists with all required sections and pattern fenced blocks.
- `tools/verify/m033-p01-branch-detection-ssot-parity.sh` exists, is executable, and exits 0 (with one SKIP line until T03 lands `start.sh`, after which all assertions PASS).
- A summary file at [`.orchestrator/milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md`](../../../../../milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output before T03 lands: one `SKIP:` line (`scripts/lifecycle/start.sh not yet authored`) plus PASS lines for the SSOT-internal assertions, ending with `SUMMARY: m033-p01-branch-detection-ssot-parity.sh pass=N fail=0 skip=1`. After T03 lands and `start.sh` exists with the matching pattern strings, the SKIP becomes PASS lines and the SUMMARY shifts to `skip=0`.
