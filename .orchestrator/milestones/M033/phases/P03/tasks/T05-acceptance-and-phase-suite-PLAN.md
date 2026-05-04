---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M033"
name: "SC-2 + SC-3 acceptance scripts + phase-suite + cross-phase regression + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 closed: `scripts/verify/constitution-shape-lint.sh`, `scripts/verify/standalone-gate.sh`, `templates/constitution-starters/{web-saas,cli-tool,library}.md`, `references/constitution-starter-format.md` all exist.
- T02 closed: `commands/constitution.md`, `scripts/lifecycle/constitution-author.sh` exist.
- T03 closed: `commands/ingest-codebase.md`, `scripts/lifecycle/ingest-codebase.sh` (deterministic core), three stack fixtures exist.
- T04 closed: `references/imported-context-sentinel.md` exists; `ingest-codebase.sh` rich-context branch is filled; downstream traversers carry `_*`-prefix skip annotations.
- M033/P01 phase-suite passes: `bash tools/verify/m033-p01-phase-suite.sh` exits 0.
- M033/P02 phase-suite passes: `bash tools/verify/m033-p02-phase-suite.sh` exits 0.
- `tests/m033-acceptance/p02-constitution-author.sh` does NOT yet exist — verified by `[ ! -f tests/m033-acceptance/p02-constitution-author.sh ]`.
- `tests/m033-acceptance/p03-ingest-codebase.sh` does NOT yet exist.
- `tools/verify/m033-p03-phase-suite.sh` does NOT yet exist.
- Spec context: SC-2 verifies FR-3 + FR-4 + FR-5 + FR-6 across three stacks; SC-3 verifies FR-7 + FR-8 across three stack fixtures plus `build-context.sh --profile=quick` consumability. SC-14 — battery discovers `tests/m033-acceptance/p*.sh` matching `p02-constitution-author.sh` AND `p03-ingest-codebase.sh` (multiple p-prefixes per phase per the SC-14 amendment).

## Description

T05 ships the SC-2 and SC-3 end-to-end acceptance scripts, the `m033-p03-*` phase-suite aggregator, the cross-phase regression verifier, and the bidirectional scope-guard. The acceptance scripts exercise the full T01-T04 surface against staging projects under `mktemp -d`; the phase-suite chains all 13 P03 sub-verifiers; the cross-phase regression re-runs P01 + P02 phase-suites to assert P03 did not regress earlier phases (per AD-15 cross-phase regression precedent established by P02/T02 + P02/T05); the scope-guard is bidirectional (forbidden-presence: P04/P05 surfaces NOT touched; allowed-presence whitelist: P03 deliverables present).

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. Acceptance scripts use parallel indexed arrays for stack iteration.

## Steps

1. **Author `tests/m033-acceptance/p02-constitution-author.sh`** (≥100 lines, executable, `chmod +x`). The script (SC-2):

   1a. **Header.** `#!/usr/bin/env bash`, `set -e -u -o pipefail`, comment block naming SC-2, FR-3, FR-4, FR-5, FR-6, US-2 acceptance scenarios.

   1b. **Pass/fail counter setup.** `pass=0`, `fail=0` integers. `pass()` and `fail()` helpers per MEM002 — emit `PASS: <message>` / `FAIL: <message>` and increment. `cleanup()` trap on EXIT removes all `mktemp -d` staging dirs.

   1c. **Three-stack iteration.** For each stack in `web-saas cli-tool library`:
   - `staging="$(mktemp -d)"` — create staging project.
   - `mkdir -p "$staging/.orchestrator"` — minimum init.
   - Run `EDITOR=cat bash scripts/lifecycle/constitution-author.sh --stack <stack> --project-dir "$staging" --yes` against simulated stdin (`printf 'y\ny\ny\ny\ny\ny\ny\ny\n'` — 8 `y` lines for the 5–8 question flow).
   - Assert `[ -f "$staging/.orchestrator/memory/constitution.md" ]`.
   - Assert the file contains the stack-specific tokens via `grep -F`:
     - web-saas: `Idempotent Deploys` AND `User Data Privacy`.
     - cli-tool: `Composable Default Exit Codes` AND `POSIX Convention Adherence`.
     - library: `Stable API Surface` AND `Semantic Versioning Discipline`.
   - Assert zero literal `{{` placeholder strings remain (`grep -cF '{{' "$staging/.orchestrator/memory/constitution.md"` returns 0).
   - Assert `bash scripts/verify/constitution-shape-lint.sh "$staging/.orchestrator/memory/constitution.md"` exits 0.
   - Assert `[ -f "$staging/.orchestrator/start-state/constitution-authored.complete" ]` (FR-20 marker).
   - Assert `[ -f "$staging/.orchestrator/execution-log.jsonl" ]` AND `grep -F 'constitution_authored' "$staging/.orchestrator/execution-log.jsonl"` returns ≥1 match (FR-22 event).

   1d. **Idempotency assertion (US-2 AS-2).** For the `web-saas` staging dir, capture file mtime via `ls -la` (or `stat -f %m` on darwin, `stat -c %Y` on linux — detect via `command -v`); re-run the command without `--force`; assert `no changes` appears on stdout AND the file's mtime is preserved (byte-identical preservation).

   1e. **`--force` regeneration assertion (US-2 AS-3).** Re-run with `--force`; assert the file is regenerated AND a stderr line containing `WARN` AND `--force` appears (warning naming discarded edits).

   1f. **Unknown stack assertion (US-2 AS-4).** Run `bash scripts/lifecycle/constitution-author.sh --stack quantum-mainframe --project-dir "$staging" --yes` (note: this should NOT produce a constitution); assert non-zero exit; assert stderr contains `web-saas`, `cli-tool`, `library` (the v1 list) AND `#Q-2`.

   1g. **Standalone-gate assertion (FR-6 / CON-3 / Principle XVI).** Run `bash scripts/verify/standalone-gate.sh constitution`; assert exit 0; assert stdout contains `PASS:` (zero `speckit.*` references in M033 surface).

   1h. **Final summary.** Emit `SUMMARY: p02-constitution-author.sh pass=$pass fail=$fail`. Exit 0 iff `fail=0`.

2. **Author `tests/m033-acceptance/p03-ingest-codebase.sh`** (≥100 lines, executable, `chmod +x`). The script (SC-3):

   2a. **Header.** `#!/usr/bin/env bash`, `set -e -u -o pipefail`, comment block naming SC-3, FR-7, FR-8, US-3 acceptance scenarios.

   2b. **Pass/fail + cleanup.** Same shape as SC-2.

   2c. **Three-stack-fixture iteration.** For each fixture in `m033-stack-fixture-ts-saas m033-stack-fixture-py-cli m033-stack-fixture-rust-library`:
   - `staging="$(mktemp -d)"`.
   - `cp -R "tests/fixtures/$fixture/" "$staging/"` — copy fixture content into the staging dir (NOT into `$staging/$fixture/`; use trailing slash to copy contents).
   - Run `bash scripts/lifecycle/ingest-codebase.sh --project-dir "$staging" --yes`.
   - Count MEM files emitted: `mem_count=$(find "$staging/.orchestrator/knowledge/" -name 'MEM-*.md' -type f | wc -l)` (a single pipe `find ... | wc -l` is acceptable per MEM001's "no `$(...)` containing pipes" — the prohibition is on command-substitution-containing-pipes, not on simple `wc -l` of a `find` result; if the bash-shape-guard objects, fall back to `find ... > tmp && wc -l < tmp`).
   - Assert `[ "$mem_count" -ge 5 ] && [ "$mem_count" -le 15 ]` (FR-7 5–15 range).
   - Assert at least one MEM in each category:
     - `find "$staging/.orchestrator/knowledge/architecture/" -name 'MEM-*.md' -type f` returns ≥1.
     - `find "$staging/.orchestrator/knowledge/conventions/" -name 'MEM-*.md' -type f` returns ≥1.
     - `find "$staging/.orchestrator/knowledge/decisions/" -name 'MEM-*.md' -type f` returns ≥1.

   2d. **Idempotency assertion (FR-7 / US-3 AS-2).** Re-run the same command against the same staging dir; assert zero new MEMs (count unchanged); assert `re-ingest` appears on stdout.

   2e. **FR-8 / MIT-005 rich-context assertion.** For the `m033-stack-fixture-ts-saas` staging dir (which carries `.orchestrator/DECISIONS.md` with `DR-DEMO-001` and `DR-DEMO-002`):
   - Assert `[ -f "$staging/.orchestrator/milestones/_imported-context/_imported-context.md" ]` (sentinel path because no active milestone is configured per #Q-11).
   - Assert the file contains `context_source: imported-from-existing` via `grep -F`.
   - Assert `[ -f "$staging/.orchestrator/knowledge/decisions/MEM-DR-DEMO-001.md" ]`.
   - Assert `[ -f "$staging/.orchestrator/knowledge/decisions/MEM-DR-DEMO-002.md" ]`.
   - Assert `grep -F 'imported_context_loaded' "$staging/.orchestrator/execution-log.jsonl"` returns ≥1 match.

   2f. **`build-context.sh --profile=quick` consumability assertion (SC-3 / M031 boundary).** Run `bash scripts/dispatch/build-context.sh --profile=quick --task 'fix flaky test' --project-dir "$staging"` against the post-ingest TS SaaS staging dir; capture stdout/stderr to a temp file; assert ≥3 of the seeded MEM filenames (or MEM IDs) appear in the captured payload. The exact assertion shape: enumerate `find "$staging/.orchestrator/knowledge/" -name 'MEM-*.md'` to a temp file; for each MEM filename, check via `grep -F` whether the basename appears in the captured payload; count matches; assert count ≥ 3.

     Note: this assertion verifies that the seeded MEMs are discoverable by M031's universal-entry profile traversal — proves the SC-3 "consumable by M031's universal-entry path" contract.

   2g. **Minimum-viable-seed assertion (US-3 AS-5).** Create a degenerate fixture under `mktemp -d` containing ONLY a `src/` directory with a trivial file (no `README.md`, no manifest, no `tests/`). Run `bash scripts/lifecycle/ingest-codebase.sh --project-dir "$degenerate" --yes`. Assert exit 0. Assert `mem_count ≥ 1` (at least one MEM derived from directory structure alone). Assert stdout contains a diagnostic listing what was missing (e.g., `missing: README.md, ARCHITECTURE.md, package.json, ...`).

   2h. **Final summary.** Emit `SUMMARY: p03-ingest-codebase.sh pass=$pass fail=$fail`. Exit 0 iff `fail=0`.

3. **Author `tools/verify/m033-p03-acceptance-shape-sc2.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p02-constitution-author.sh` exists, is executable.
   - Body contains `SC-2`, `FR-3`, `FR-4`, `FR-5`, `FR-6`, `web-saas`, `cli-tool`, `library`, `Idempotent Deploys`, `Composable Default Exit Codes`, `Stable API Surface`, `speckit`, `no changes`, `constitution-shape-lint.sh`, `standalone-gate.sh` via `grep -F`.
   - **Functional smoke test:** invoke `bash tests/m033-acceptance/p02-constitution-author.sh`; assert exit 0; assert `SUMMARY:` final line contains `pass=` and `fail=0`.
   - Emits `PASS:` / `SUMMARY:` lines.

4. **Author `tools/verify/m033-p03-acceptance-shape-sc3.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p03-ingest-codebase.sh` exists, is executable.
   - Body contains `SC-3`, `FR-7`, `FR-8`, `ingest-codebase.sh`, `knowledge/architecture`, `knowledge/conventions`, `knowledge/decisions`, `re-ingest`, `context_source: imported-from-existing`, `_imported-context`, `MEM-DR-DEMO-001`, `build-context.sh`, `--profile=quick` via `grep -F`.
   - **Functional smoke test:** invoke `bash tests/m033-acceptance/p03-ingest-codebase.sh`; assert exit 0; assert `SUMMARY:` final line contains `pass=` and `fail=0`.
   - Emits `PASS:` / `SUMMARY:` lines.

5. **Author `tools/verify/m033-p03-cross-phase-regression.sh`** (≥25 lines, executable). Asserts the AD-15 cross-phase regression precedent for P03:
   - `bash tools/verify/m033-p01-phase-suite.sh` exits 0 (P01 surface preserved).
   - `bash tools/verify/m033-p02-phase-suite.sh` exits 0 (P02 surface preserved).
   - The verifier captures each sub-suite's exit code and propagates failure (fails on either regression). Body contains the load-bearing tokens `m033-p01-phase-suite.sh`, `m033-p02-phase-suite.sh`, `AD-15`.
   - Emits `PASS:` / `SUMMARY:` lines.

6. **Author `tools/verify/m033-p03-scope-guard.sh`** (≥50 lines, executable). Bidirectional scope-guard (P02/T05 pattern):
   - **Forbidden-presence (P04/P05 surfaces NOT touched):** assert the following files do NOT exist (P04/P05 deliverables):
     - `scripts/lifecycle/materials-intake.sh`
     - `scripts/lifecycle/ideation.sh`
     - `scripts/lifecycle/customblock-draft.sh`
     - `commands/materials-intake.md`
     - `commands/ideation.md`
     - `commands/customblock-draft.md`
   - **Allowed-presence (P03 deliverables ARE present):** assert the following files DO exist:
     - `commands/constitution.md`, `commands/ingest-codebase.md`
     - `scripts/lifecycle/constitution-author.sh`, `scripts/lifecycle/ingest-codebase.sh`
     - `scripts/verify/constitution-shape-lint.sh`, `scripts/verify/standalone-gate.sh`
     - `templates/constitution-starters/web-saas.md`, `templates/constitution-starters/cli-tool.md`, `templates/constitution-starters/library.md`
     - `references/constitution-starter-format.md`, `references/imported-context-sentinel.md`
     - `tests/fixtures/m033-stack-fixture-ts-saas/README.md`, `tests/fixtures/m033-stack-fixture-py-cli/README.md`, `tests/fixtures/m033-stack-fixture-rust-library/README.md`
     - `tests/m033-acceptance/p02-constitution-author.sh`, `tests/m033-acceptance/p03-ingest-codebase.sh`
   - **P02 boundary:** assert the P02 surfaces (`scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `scripts/lifecycle/grilling-shell.sh`, `references/m033-fr21-dual-write-convention.md`) still exist (P03 did not delete them).
   - **`wiki/` boundary (M033-tagged narrowing per P01 D-T05-02):** scan `wiki/` for filenames matching `M033*` or `m033*` — assert none exist (P03 should not write to wiki/; that's M032 territory). Note: the orchestrator's pre-existing `wiki/` content is unrelated and is NOT scanned.
   - Body contains `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/ideation.sh`, `scripts/lifecycle/customblock-draft.sh`, `commands/materials-intake.md`, `commands/ideation.md`, `commands/customblock-draft.md`, `constitution-author.sh`, `ingest-codebase.sh`, `SC-13` via `grep -F`.
   - Emits `PASS:` / `SUMMARY:` lines.

7. **Author `tools/verify/m033-p03-phase-suite.sh`** (≥60 lines, executable). The aggregator chains all 13 P03 sub-verifiers in dependency order:

   ```
   m033-p03-constitution-md-shape.sh         (T02)
   m033-p03-constitution-author-sh-shape.sh  (T02)
   m033-p03-constitution-starter-templates-shape.sh  (T01)
   m033-p03-constitution-starter-format-ref-shape.sh (T01)
   m033-p03-constitution-shape-lint-shape.sh (T01)
   m033-p03-standalone-gate-sh-shape.sh      (T01)
   m033-p03-ingest-codebase-md-shape.sh      (T03)
   m033-p03-ingest-codebase-sh-shape.sh      (T03)
   m033-p03-rich-context-import-shape.sh     (T04)
   m033-p03-imported-context-sentinel-shape.sh (T04)
   m033-p03-stack-fixtures-shape.sh          (T03)
   m033-p03-acceptance-shape-sc2.sh          (T05)
   m033-p03-acceptance-shape-sc3.sh          (T05)
   ```

   The aggregator iterates the verifier list under `IFS=$'\n'` for-loop swap (P02/T05 pattern), captures each sub-verifier's exit code, propagates failure, and emits a final `SUMMARY: m033-p03-phase-suite.sh pass=N fail=M` line.

   Body contains the load-bearing tokens `SUMMARY:`, `m033-p03-constitution-md-shape`, `m033-p03-constitution-author-sh-shape`, `m033-p03-standalone-gate-sh-shape`, `m033-p03-ingest-codebase-sh-shape`, `m033-p03-rich-context-import-shape`, `m033-p03-acceptance-shape-sc2`, `m033-p03-acceptance-shape-sc3`, `m033-p03-phase-suite` via `grep -F`.

## Must-Haves

This task addresses these P03 phase truths:
- `tests/m033-acceptance/p02-constitution-author.sh` exists and exits 0 (SC-2).
- `tests/m033-acceptance/p03-ingest-codebase.sh` exists and exits 0 (SC-3).
- `tools/verify/m033-p03-phase-suite.sh` exists and chains all 13 sub-verifiers.
- The P02 cross-phase regression boundary holds (AD-15).
- The SC-13 / scope-guard invariant holds for the P03 diff.

This task creates these P03 phase artifacts:
- Acceptance: `tests/m033-acceptance/{p02-constitution-author,p03-ingest-codebase}.sh`.
- Verifiers: `tools/verify/m033-p03-{acceptance-shape-sc2,acceptance-shape-sc3,cross-phase-regression,scope-guard,phase-suite}.sh`.

## Verification

```bash
bash tools/verify/m033-p03-acceptance-shape-sc2.sh
bash tools/verify/m033-p03-acceptance-shape-sc3.sh
bash tools/verify/m033-p03-cross-phase-regression.sh
bash tools/verify/m033-p03-scope-guard.sh
bash tools/verify/m033-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- T01 — `scripts/verify/standalone-gate.sh`, `scripts/verify/constitution-shape-lint.sh`, `templates/constitution-starters/`, `references/constitution-starter-format.md`. SC-2 invokes the gate; SC-2 invokes the lint via the constitution-author driver.
- T02 — `commands/constitution.md`, `scripts/lifecycle/constitution-author.sh`. SC-2's primary subject under test.
- T03 — `commands/ingest-codebase.md`, `scripts/lifecycle/ingest-codebase.sh` deterministic core, three stack fixtures. SC-3's primary subject under test.
- T04 — `references/imported-context-sentinel.md`, `ingest-codebase.sh` rich-context branch (in-place), downstream-traverser annotations. SC-3's FR-8 / MIT-005 assertion exercises this path.

### From P01 + P02 (Pre-existing)

- `tools/verify/m033-p01-phase-suite.sh` — cross-phase regression input.
- `tools/verify/m033-p02-phase-suite.sh` — cross-phase regression input.
- `scripts/dispatch/build-context.sh` — invoked by SC-3 step 2f to verify M031 universal-entry consumability.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- The acceptance scripts MUST clean up all `mktemp -d` staging directories on exit (trap on EXIT).
- The phase-suite is the LAST sub-verifier authored — it depends on every earlier verifier's existence.
- The cross-phase regression verifier MUST pass — if either P01 or P02 phase-suite regresses, T05 fails and the phase cannot close. This is the AD-15 enforcement; T04's annotations to downstream traversers must NOT regress P01/P02 surfaces.
- The scope-guard's `wiki/` rule is narrowed to `M033*`/`m033*` filename match per P01 D-T05-02 (the orchestrator's pre-existing `wiki/` content is unrelated and is NOT scanned).
- The acceptance scripts are bash-shape-guard-aware: simple `find ... | wc -l` pipes are acceptable; `$(find ... | wc -l)` is NOT (command substitution containing pipe). When the count is needed in a variable, prefer `find ... > tmp.txt; count=$(wc -l < tmp.txt)` (POSIX-safe) or `set -- $(find ...); count=$#`.
- T05 MUST NOT modify any P01, P02, T01, T02, T03, or T04 surface (T05 is purely additive — acceptance scripts + verifiers).
- The scope-guard's allowed-presence whitelist documents the exact P03 deliverable file set; drift detection is bidirectional.

## Expected Output

After T05 completes:
- `tests/m033-acceptance/p02-constitution-author.sh` exists, is executable, exits 0 with `SUMMARY: pass=N fail=0`.
- `tests/m033-acceptance/p03-ingest-codebase.sh` exists, is executable, exits 0 with `SUMMARY: pass=N fail=0`.
- All 5 T05 verifiers exit 0 with `SUMMARY:` lines.
- `tools/verify/m033-p03-phase-suite.sh` exits 0 with `SUMMARY: m033-p03-phase-suite.sh pass=13 fail=0`.
- `tools/verify/m033-p03-cross-phase-regression.sh` exits 0 (P01 + P02 phase-suites still pass).
- A summary file at `.orchestrator/milestones/M033/phases/P03/tasks/T05-acceptance-and-phase-suite-SUMMARY.md` documents the deliverables.

## Notes

The `find ... | wc -l` pattern is the canonical shape for counting matching files. Under bash 3.2 + the active shape-guard (per CLAUDE.md guidance), simple pipes are allowed; the prohibitions are on `$(...)` containing pipes, process substitution `<(...)`, and inline compound chains. If a specific shape-guard rejection surfaces during T05 execution, fall back to the `find ... > tmp.txt; count=$(wc -l < tmp.txt)` shape (single-redirect, no pipe inside command-substitution).

The 8-`y` stdin shape in SC-2 step 1c (`printf 'y\ny\ny\ny\ny\ny\ny\ny\n'`) is intentional: the FR-3 grilling flow is 5–8 questions, and 8 `y` lines covers the worst case. The recommendation-not-interrogation framing in P02's `ask_one` accepts `y` as the recommendation-accept; extra lines past the question count are absorbed by the surrounding shell without error.

The SC-3 `build-context.sh --profile=quick` assertion is the load-bearing M031 boundary check — proves the seeded MEMs are discoverable by the universal-entry traversal. If this assertion fails, the FR-7 contract is broken at the integration boundary. Note: `build-context.sh` may emit additional stderr output that the assertion must tolerate; the verifier captures both stdout and stderr to the same temp file via `>tmp.txt 2>&1` (single redirect, no pipe).

The cross-phase regression verifier is intentionally minimal: it only asserts P01 and P02 phase-suite exit codes. Deeper regression coverage is M033's friendly-tester pass (US-8 / SC-15) territory — the mechanical verifier catches the gross-failure cases, the friendly-tester catches the UX cases.

The bidirectional scope-guard's allowed-presence whitelist is the load-bearing P03 deliverable inventory. If a future task adds a new P03 deliverable, the whitelist MUST be updated — otherwise the guard fires a false-fail (`expected presence` violated). This is deliberate: it forces explicit acknowledgment of every new deliverable, catching silent additions.
