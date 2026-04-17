---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M011"
name: "Dogfood evidence (foreign PRD fixture) + E2E gate + Bash 3.2 compat + regression guards + user guide"
depends_on: ["T03"]
---

## Prerequisites

- T01, T02, T03 are complete. All T01 + T02 per-artifact verify scripts pass. The T03 intensity-gate edit and `commands/ingest.md` re-wire are landed and their two verify scripts pass.
- `scripts/verify/run-suite.sh` exists and can be invoked as `bash scripts/verify/run-suite.sh m011 P07` once all P07 verify scripts are in place.
- The P06 preserved-references regression pattern is established (`scripts/verify/m011-p06-commands-preserve-references.sh`). T04 extends this pattern to P07.

## Description

Capture end-to-end dogfood evidence that the format-agnostic pipeline actually works on a foreign-shaped PRD. Ship a fixture `tests/fixtures/arbitrary-prd.md` (a non-spec-kit-shaped markdown PRD — narrative problem/proposal structure, no FR- / US- / AC- IDs, no Given/When/Then blocks), run the full pipeline against it in both stub mode and (where possible) live mode, and persist the resulting transcripts under `.orchestrator/milestones/M011/phases/P07/evidence/`.

T04 also ships the five remaining verify scripts that weren't owned by T01/T02/T03:

- `m011-p07-e2e-arbitrary-spec.sh` — sandboxed end-to-end pipeline run.
- `m011-p07-gate-pass-block.sh` — asserts BLOCK skips chunker, PASS proceeds, `--force` after BLOCK emits `FORCE:` line.
- `m011-p07-intensity-policy.sh` — asserts the `--review` / `--no-review` overrides documented in `commands/ingest.md` are reachable.
- `m011-p07-bash32-compat.sh` — scans all new P07 scripts for Bash-3.2 incompatibilities.
- `m011-p07-evidence-present.sh` — file-exists + token-contains gate for each evidence artifact.
- `m011-p07-commands-preserve-references.sh` — regression guard for `commands/evaluate.md` + `commands/roadmap.md` Reference File bullets (extends P06's pattern).

And ships the user guide: `docs/ingesting-arbitrary-specs.md`.

## Steps

1. **Create `tests/fixtures/arbitrary-prd.md`** — a deliberately foreign-shaped markdown PRD. Requirements for the fixture:
   - Title line `# Product: Inventory Reconciliation`.
   - At least 30 lines.
   - Uses narrative headings: `## Problem`, `## Proposal`, `## Risks`, `## Out of Scope`.
   - Contains NO `## User Stories`, NO `## Functional Requirements`, NO `FR-NNN` / `US-NNN` / `AC-NNN` IDs, NO Given/When/Then blocks.
   - Contains enough real content that a normalizer could plausibly extract 3–5 user stories and 5–8 requirements. (3 paragraphs under "Problem", 4 bullets under "Proposal", 2 paragraphs under "Risks", 3 bullets under "Out of Scope" is sufficient.)
   - Verify via a quick local run of `bash scripts/knowledge/detect-spec-shape.sh --spec-path tests/fixtures/arbitrary-prd.md` — expect `shape=foreign`.

2. **Create `tests/fixtures/normalized-stub.md`** — the canned normalizer output used by `NORMALIZER_STUB=1`. Requirements:
   - Valid spec-kit-shaped markdown: frontmatter-optional; `# Feature Specification: Inventory Reconciliation`; `## Problem Statement`; `## User Scenarios & Testing` with at least one `### User Story 1` sub-section containing `**As a** ... **I want** ... **So that** ...`; `## Functional Requirements` with at least three `FR-NNN` entries; `## Acceptance Scenarios` with at least one `Given/When/Then` block; `## Constraints`; `## Non-Goals`.
   - At least 40 lines. This fixture is consumed by T01's stub path and by the e2e gate.

3. **Create `tests/fixtures/gate-result-pass.md`** and `tests/fixtures/gate-result-block.md`** — canned conversus verdicts for `CONVERSUS_STUB=1`. (Note: T02 already requires creating these; if they're present from T02, skip. This step is a backstop.) Pass fixture has frontmatter `verdict: "PASS"` plus a 5-line body with a `## Disputes` and `## Rationale` section. Block fixture has `verdict: "BLOCK"` plus at least one entry in `## Disputes`.

4. **Create `scripts/verify/m011-p07-e2e-arbitrary-spec.sh`** (executable). The full sandboxed end-to-end gate:
   - `TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT`.
   - `PROJECT_ROOT=$TMP`; `cd $TMP`.
   - Mirror the minimum project tree into the sandbox: `mkdir -p specs tests/fixtures scripts/knowledge scripts/dispatch/adapters/tool scripts/engine scripts/verify scripts/lifecycle knowledge/spec .orchestrator/memory templates/conversus-presets commands`.
   - Copy the four production scripts that participate in the pipeline: `detect-spec-shape.sh`, `normalize-spec.sh`, `ingest-spec.sh`, `rebuild-index.sh`, `scope-filter.sh`, `dispatch-interface.sh`, `intensity-gate.sh`, the conversus adapter, and `spec-metrics.sh`. Copy the four supporting templates. Copy the two relevant fixtures.
   - Create a minimal stub for `dispatch-interface.sh` in the sandbox that simply echoes the contents of `tests/fixtures/normalized-stub.md` when invoked — this makes the e2e deterministic without a live agent.
   - Set `NORMALIZER_STUB=1` and `CONVERSUS_STUB=1` (verdict=PASS).
   - Copy the foreign PRD fixture to `~/Downloads/arbitrary-prd.md` INSIDE the sandbox (use `$TMP/Downloads/arbitrary-prd.md`).
   - Run the pipeline steps in order, capturing each output:
     1. `bash scripts/knowledge/detect-spec-shape.sh --spec-path $TMP/Downloads/arbitrary-prd.md` → assert `shape=foreign`.
     2. `bash scripts/knowledge/normalize-spec.sh --spec-path $TMP/Downloads/arbitrary-prd.md --slug 019-foo` → assert stdout contains `NORMALIZED:` and the file `specs/019-foo/spec.md` exists.
     3. `bash scripts/dispatch/adapters/tool/conversus.sh gate normalize-fidelity specs/019-foo/spec.md $TMP/gate-result.md` → assert exit 0 and `$TMP/gate-result.md` contains `verdict: "PASS"`.
     4. `bash scripts/knowledge/ingest-spec.sh --spec-path specs/019-foo/spec.md --slug 019-foo --scope-tags "[project]"` → assert stdout contains at least one `CREATED:` line.
     5. `bash scripts/state/spec-metrics.sh` → assert stdout contains `spec_chunks_present=true`.
   - Capture a `date +%s` timestamp before step 1 and after step 5; assert `elapsed_seconds < 120`.
   - Emit `PASS: ...` / `FAIL: ...` per step.

5. **Create `scripts/verify/m011-p07-gate-pass-block.sh`** (executable). Three sub-assertions, each run in a throwaway sandbox:
   - **PASS case**: `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS bash scripts/dispatch/adapters/tool/conversus.sh gate normalize-fidelity <fixture-spec> $TMP/gate-result.md` exits 0; `grep -Fq -- 'verdict: "PASS"' $TMP/gate-result.md`.
   - **BLOCK case**: with `CONVERSUS_STUB_VERDICT=BLOCK`, adapter exits 2; gate-result contains `verdict: "BLOCK"`.
   - **BLOCK + --force case**: simulate the `commands/ingest.md` Step 5 logic by writing a tiny shim wrapper script (inline in the sandbox) that calls the adapter with BLOCK, catches exit 2, then appends a `FORCE: gate BLOCK bypassed by --force at <timestamp>` line to `$TMP/.ingest-log.jsonl`, then exits 0. Run the shim with a `--force` flag and assert the log file contains the `FORCE:` token.
   - Emit `PASS:` / `FAIL:` per sub-assertion.

6. **Create `scripts/verify/m011-p07-intensity-policy.sh`** (executable). Asserts:
   - The three intensity-level matrix rows (already covered by T03's `m011-p07-intensity-ingest-stage.sh` — keep this assertion here as a contract anchor, double-coverage is fine).
   - The `--review` override is documented in `commands/ingest.md`: `grep -B 2 -A 5 -- '--review' commands/ingest.md` must contain a phrase matching `force.*fidelity.*gate` (case-insensitive).
   - The `--no-review` override is documented: `grep -B 2 -A 5 -- '--no-review' commands/ingest.md` must contain `skip` or `force off` (case-insensitive).
   - The `--force` flag's P07 BLOCK-bypass semantics are documented: the doc explicitly states `--force` applies to both re-ingest confirmation AND BLOCK-verdict bypass (search for `BLOCK` within 10 lines of a `--force` occurrence).
   - Emit `PASS:` / `FAIL:` per assertion.

7. **Create `scripts/verify/m011-p07-bash32-compat.sh`** (executable). Scans all new P07 production scripts and verify scripts for Bash-3.2 incompatibilities:
   - List of files to scan: `scripts/knowledge/detect-spec-shape.sh`, `scripts/knowledge/normalize-spec.sh`, `scripts/dispatch/adapters/tool/conversus.sh`, the edited portion of `scripts/engine/intensity-gate.sh` (scan the whole file is fine), plus all twelve `scripts/verify/m011-p07-*.sh`.
   - For each file, run `bash -n <file>` — assert exit 0 (parse-clean).
   - For each file, assert `grep -Eq '\b(declare[[:space:]]+-A|mapfile|readarray)\b' <file>` returns non-zero (none of those tokens present).
   - For each file, assert `grep -Eq '<\(|>\(' <file>` returns non-zero (no process substitution).
   - Emit `PASS:` per file; `FAIL:` on any violation with the specific token named.

8. **Create `scripts/verify/m011-p07-evidence-present.sh`** (executable). File-exists + token-contains gate for each evidence artifact produced in Step 10:
   - `.orchestrator/milestones/M011/phases/P07/evidence/detect-shape.txt` contains `shape=foreign`.
   - `.orchestrator/milestones/M011/phases/P07/evidence/normalize-transcript.txt` contains `NORMALIZED:`.
   - `.orchestrator/milestones/M011/phases/P07/evidence/gate-result.md` contains `verdict:`.
   - `.orchestrator/milestones/M011/phases/P07/evidence/chunker-transcript.txt` contains `CREATED:`.
   - `.orchestrator/milestones/M011/phases/P07/evidence/timing.txt` contains `elapsed_seconds=` and the numeric value parses as an integer `< 120`.
   - Emit `PASS:` / `FAIL:` per artifact.

9. **Create `scripts/verify/m011-p07-commands-preserve-references.sh`** (executable). Regression guard extending P06's pattern to P07. Asserts `commands/evaluate.md` and `commands/roadmap.md` still contain every Reference File bullet that the P06 preserve-references script asserted. The exact token list to check can be harvested from `scripts/verify/m011-p06-commands-preserve-references.sh`. For P07's contribution: the script ALSO verifies that the P06 `commands/ingest.md` bullets (`scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/rebuild-index.sh`, `scripts/state/spec-metrics.sh`, `scripts/dispatch/scope-filter.sh`, `knowledge/spec/`, `templates/evaluation.md`) are still present in `commands/ingest.md` after T03's edits. Use `grep -Fq -- "$tok"` for every token. Emit `PASS:` / `FAIL:` per token.

10. **Dogfood run**: execute the full pipeline on the real fixture and capture evidence:
    - `mkdir -p .orchestrator/milestones/M011/phases/P07/evidence`.
    - Run `bash scripts/knowledge/detect-spec-shape.sh --spec-path tests/fixtures/arbitrary-prd.md > .orchestrator/milestones/M011/phases/P07/evidence/detect-shape.txt`.
    - Run the normalizer (stub or live; stub-mode is acceptable for committed evidence and is documented as such in the user guide). Redirect stdout to `normalize-transcript.txt`. Copy the resulting normalized `specs/019-foo/spec.md` into the evidence directory as `normalized-spec.md` (or reference it from the transcript — either is acceptable; the verify script checks the transcript token).
    - Run the conversus adapter with `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS` and copy the resulting gate-result.md into the evidence directory.
    - Run `ingest-spec.sh` and capture its stdout to `chunker-transcript.txt`.
    - Capture `date +%s` bookends around the four stages; write `elapsed_seconds=<N>` to `timing.txt`.
    - After capture, run `bash scripts/verify/m011-p07-evidence-present.sh` — it must emit `PASS:`.

11. **Create `docs/ingesting-arbitrary-specs.md`** (min 80 lines). Sections:
    - **Overview**: orchestrator ingests any markdown, not just spec-kit-shaped. The pipeline auto-detects shape and normalizes foreign input.
    - **Quickstart**: one-command invocation on a foreign PRD. Show actual stdout.
    - **When the fidelity gate fires**: Quick skips it, Standard/Full run it. `--review` forces on, `--no-review` forces off.
    - **Interpreting BLOCK verdicts**: read the `## Disputes` section of `gate-result.md`; review the normalized `specs/<slug>/spec.md` against the source; fix the normalization by editing the normalized artifact directly (the orchestrator re-uses the edited artifact on the next chunker run since the `source_hash:` marker prevents re-normalization).
    - **`--force` escape hatch**: bypass a BLOCK verdict and run the chunker anyway. Records a `FORCE:` audit-trail line.
    - **Stub modes for CI**: `NORMALIZER_STUB=1` and `CONVERSUS_STUB=1` / `CONVERSUS_STUB_VERDICT=PASS|BLOCK`.
    - **Graceful degradation**: when the conversus binary is missing, the pipeline proceeds without a gate (exit 0 + SKIPPED: line). Document where to install conversus (`~/Sites/conversus` or on PATH).
    - **Extending to new gate points**: M013 / M014 will add their own presets under `templates/conversus-presets/` and invoke the same adapter. Point at `commands/conversus-gate.md` for the reusable protocol.
    - Cross-link to `commands/ingest.md`, `commands/conversus-gate.md`, and `templates/spec-normalizer-prompt.md`.

12. **Set executable bits** on all new verify scripts.

13. **Run the full phase verify suite**: `bash scripts/verify/run-suite.sh m011 P07` — every P07 script must emit `PASS:`. Also run `bash scripts/verify/run-suite.sh m011 P06` to confirm no P06 regressions.

## Must-Haves

From `P07-PLAN.md` Truths, this task is responsible for:

- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` sandboxed end-to-end run on the foreign PRD fixture (Check: `m011-p07-e2e-arbitrary-spec.sh`).
- `scripts/verify/m011-p07-gate-pass-block.sh` PASS/BLOCK/`--force` coverage (Check: `m011-p07-gate-pass-block.sh`).
- `scripts/verify/m011-p07-intensity-policy.sh` documented-override coverage (Check: `m011-p07-intensity-policy.sh`).
- `scripts/verify/m011-p07-bash32-compat.sh` compatibility scan (Check: `m011-p07-bash32-compat.sh`).
- `scripts/verify/m011-p07-evidence-present.sh` dogfood evidence gate (Check: `m011-p07-evidence-present.sh`).
- `scripts/verify/m011-p07-commands-preserve-references.sh` regression guard (Check: `m011-p07-commands-preserve-references.sh`).
- `docs/ingesting-arbitrary-specs.md` user guide (Artifacts).
- Five evidence files under `.orchestrator/milestones/M011/phases/P07/evidence/`.

## Verification

Run (single-script-file shape per AD-19):

```
bash scripts/verify/m011-p07-e2e-arbitrary-spec.sh
bash scripts/verify/m011-p07-gate-pass-block.sh
bash scripts/verify/m011-p07-intensity-policy.sh
bash scripts/verify/m011-p07-bash32-compat.sh
bash scripts/verify/m011-p07-evidence-present.sh
bash scripts/verify/m011-p07-commands-preserve-references.sh
bash scripts/verify/run-suite.sh m011 P07
bash scripts/verify/run-suite.sh m011 P06
```

Every invocation must emit `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- All T01 outputs: `detect-spec-shape.sh`, `normalize-spec.sh`, `spec-normalizer-prompt.md`, four T01 verify scripts.
- All T02 outputs: `scripts/dispatch/adapters/tool/conversus.sh`, `commands/conversus-gate.md`, `templates/conversus-presets/normalize-fidelity.yml`, `templates/gate-result.md`, two T02 fixtures (`gate-result-pass.md`, `gate-result-block.md`), four T02 verify scripts.
- All T03 outputs: `scripts/engine/intensity-gate.sh` with the `ingest` stage registered, `commands/ingest.md` with the re-wired workflow + three new flags + preserved P06 bullets, two T03 verify scripts.

### From Disk (Pre-existing)

- `scripts/knowledge/ingest-spec.sh` (P02/P03), `scripts/knowledge/rebuild-index.sh` (P02), `scripts/state/spec-metrics.sh` (P05), `scripts/dispatch/scope-filter.sh` (P04) — downstream pipeline stages the e2e exercises; do NOT modify.
- `scripts/verify/run-suite.sh` — phase-level verify suite runner.
- `scripts/verify/m011-p06-commands-preserve-references.sh` — pattern reference for T04's preserve-references guard.
- `tests/fixtures/` — existing fixture directory.
- `docs/` — existing user-guide directory with five prior guides (`getting-started.md`, `recipe-authoring.md`, `hook-development.md`, `knowledge-management.md`, `migrating-from-speckit.md`). T04 adds a sixth.

## Constraints

- **Bash 3.2 compatibility** (MEM001) for every new verify script. The bash32-compat scan in Step 7 gates the whole set.
- **Sandbox-with-EXIT-trap cleanup** (MEM008 pattern, extended in P06): every verify script that mutates disk state uses `TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT` and operates strictly under `$TMP`.
- **BSD grep safety** (MEM012): `grep -Fq -- "$tok"` for every token beginning with `-`.
- **Single-script-file Check shape** (AD-19): every verify script is invokable as `bash scripts/verify/<name>.sh` with zero CLI arguments. The e2e gate handles all sandbox wiring internally.
- **Stub-mode determinism**: the e2e gate uses `NORMALIZER_STUB=1` + `CONVERSUS_STUB=1` so it runs deterministically in CI without a live agent or the conversus binary.
- **Timing budget**: the e2e gate asserts `elapsed_seconds < 120` (looser than P06's 60s because P07 adds two stages; the actual dogfood run should be ~15–30s in stub mode).
- **Preserved content regression**: T04's preserve-references guard must not delete or replace any P06 assertions — it ADDS P07's assertions on top.
- **Additive evidence layout**: evidence lives under `.orchestrator/milestones/M011/phases/P07/evidence/` with the exact filenames listed in the Artifacts section of the phase plan.
- **No modifications to T01/T02/T03 outputs**: T04 is pure-additive on top of the prior three tasks. Any bug found in upstream tasks is handled by opening a fix iteration against the owning task, not by patching from T04.

## Expected Output

- One new fixture: `tests/fixtures/arbitrary-prd.md` (≥ 30 lines, foreign-shaped).
- One new fixture: `tests/fixtures/normalized-stub.md` (≥ 40 lines, spec-kit-shaped).
- Two backstop fixtures (idempotent with T02): `tests/fixtures/gate-result-pass.md`, `tests/fixtures/gate-result-block.md`.
- Six new verify scripts: `m011-p07-e2e-arbitrary-spec.sh`, `m011-p07-gate-pass-block.sh`, `m011-p07-intensity-policy.sh`, `m011-p07-bash32-compat.sh`, `m011-p07-evidence-present.sh`, `m011-p07-commands-preserve-references.sh`.
- One new user guide: `docs/ingesting-arbitrary-specs.md` (≥ 80 lines).
- Five evidence artifacts under `.orchestrator/milestones/M011/phases/P07/evidence/`.
- Full P07 verify suite passes; P06 verify suite still passes (no regression).
