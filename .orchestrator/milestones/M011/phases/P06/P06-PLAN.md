---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M011"
goal: "Ship the user-facing orchestrator:ingest command as a thin wrapper over ingest-spec.sh, and validate the full ingest → evaluate → roadmap pipeline end-to-end at Quick intensity on a real markdown spec in under 60 seconds with zero manual spec formatting."
demo_sentence: "A developer runs `orchestrator:ingest --spec-path specs/016-autonomous-hardening/spec.md --slug 016-autonomous-hardening --milestone M016-DOGFOOD`, then `orchestrator:evaluate` and `orchestrator:roadmap` at Quick intensity, and the pipeline produces a tier classification driven by spec/* chunk counts plus a phase-decomposed roadmap sourced from spec/story chunks — all in under 60 seconds with zero manual spec formatting."
risk: "low"
depends_on: [P03, P05]
---

## Must-Haves

### Truths

<!-- Each truth has a single-script-file Check per AD-19 / AP-004.
     Verify scripts themselves may use any bash internally; the
     restriction applies only to these Check: commands. -->

- `commands/ingest.md` exists and documents the user-facing `orchestrator:ingest` entry point, including `--spec-path`, `--slug`, and `--milestone` flags, the "re-ingest requires confirmation unless `--force`" rule, the spec-slug → milestone mapping written into `<milestone-dir>/M###-EVALUATION.md`, and a Reference Files block pointing at `scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/rebuild-index.sh`, and `scripts/state/spec-metrics.sh`.
  - Check: `bash scripts/verify/m011-p06-ingest-doc-structure.sh`
- `commands/ingest.md` follows the shared command conventions (MEM012): YAML frontmatter with `description`, top-level title, Prerequisites section, a workflow section with numbered steps, an Idempotency section, an Error Handling section, and a Reference Files section.
  - Check: `bash scripts/verify/m011-p06-ingest-doc-conventions.sh`
- `commands/ingest.md` re-ingest semantics match P03 behavior: the document explicitly states that re-running the command on an already-ingested spec emits `SKIPPED:`, `SUPERSEDED:`, and/or `REMOVED:` prefixed lines from `ingest-spec.sh`, and requires `--force` (or interactive confirmation) to proceed without a dry-run preview.
  - Check: `bash scripts/verify/m011-p06-ingest-doc-reingest-contract.sh`
- `commands/evaluate.md` continues to reference the ingest command in its downstream-command guidance so users discover `orchestrator:ingest` before running evaluate when they arrive with an un-chunked spec. The doc mentions `orchestrator:ingest` by name at least once.
  - Check: `bash scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh`
- `scripts/verify/m011-p06-e2e-pipeline.sh` runs the full pipeline against a sandbox fixture spec: builds a throwaway `PROJECT_ROOT` under `mktemp -d`, copies a representative multi-story markdown spec into `specs/<slug>/spec.md`, invokes `ingest-spec.sh` with `--spec-path` + `--slug`, rebuilds the index, asserts the spec/* chunk counts are non-zero, invokes `scripts/dispatch/scope-filter.sh --category spec/story --graph` and asserts at least one story ID is returned, runs `scripts/state/spec-metrics.sh` and asserts `spec_chunks_present=true`, and exits 0 on success.
  - Check: `bash scripts/verify/m011-p06-e2e-pipeline.sh`
- The end-to-end pipeline completes in under 60 seconds on a representative 40-page markdown spec fixture. `scripts/verify/m011-p06-e2e-pipeline-timing.sh` captures the elapsed seconds for the ingest → rebuild-index → spec-metrics → scope-filter sequence (time_end - time_start in seconds, integer floor) and asserts the result is strictly less than 60.
  - Check: `bash scripts/verify/m011-p06-e2e-pipeline-timing.sh`
- `.orchestrator/milestones/M011/phases/P06/evidence/` contains the dogfood transcript from running the pipeline on a real in-repo spec (`specs/016-autonomous-hardening/spec.md` or equivalent), including: the ingest-spec.sh stdout capture (`ingest-transcript.txt` with at least one `CREATED:` line), the spec-metrics.sh output (`spec-metrics.txt` with `spec_chunks_present=true`), the scope-filter.sh story-ID list (`story-ids.txt` with at least one `SPEC-US-` line), and a timing record (`timing.txt` with a single integer `elapsed_seconds=<N>` line where N < 60).
  - Check: `bash scripts/verify/m011-p06-evidence-present.sh`
- All new P06 scripts pass `bash -n` under Bash 3.2 and do not use `declare -A`, `mapfile`, `readarray`, or `<(...)` process substitution.
  - Check: `bash scripts/verify/m011-p06-bash32-compat.sh`
- `commands/evaluate.md` and `commands/roadmap.md` preserve every previously-listed Reference File bullet — the P06 edits to `commands/evaluate.md` (adding the ingest-command mention) must not delete any prior bullet.
  - Check: `bash scripts/verify/m011-p06-commands-preserve-references.sh`

### Artifacts

- `commands/ingest.md` (min 120 lines, contains "orchestrator:ingest")
- `commands/evaluate.md` (min 190 lines, contains "orchestrator:ingest")
- `.orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt` (min 1 line, contains "CREATED:")
- `.orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt` (min 1 line, contains "spec_chunks_present=true")
- `.orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt` (min 1 line, contains "SPEC-US-")
- `.orchestrator/milestones/M011/phases/P06/evidence/timing.txt` (min 1 line, contains "elapsed_seconds=")
- `scripts/verify/m011-p06-ingest-doc-structure.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p06-ingest-doc-conventions.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p06-ingest-doc-reingest-contract.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p06-e2e-pipeline.sh` (min 60 lines, contains "PASS")
- `scripts/verify/m011-p06-e2e-pipeline-timing.sh` (min 30 lines, contains "PASS")
- `scripts/verify/m011-p06-evidence-present.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p06-bash32-compat.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p06-commands-preserve-references.sh` (min 20 lines, contains "PASS")

### Key Links

- `commands/ingest.md` → `scripts/knowledge/ingest-spec.sh` (ingest.md wraps ingest-spec.sh as its execution primitive)
- `commands/ingest.md` → `scripts/knowledge/rebuild-index.sh` (ingest.md documents the post-ingest index rebuild step)
- `commands/ingest.md` → `scripts/state/spec-metrics.sh` (ingest.md points users at spec-metrics for post-ingest verification)
- `commands/evaluate.md` → `commands/ingest.md` (evaluate.md references the ingest command by name as the upstream step for chunk-driven evaluation)
- `scripts/verify/m011-p06-e2e-pipeline.sh` → `scripts/knowledge/ingest-spec.sh` (the e2e gate exercises ingest-spec.sh end-to-end)
- `scripts/verify/m011-p06-e2e-pipeline.sh` → `scripts/state/spec-metrics.sh` (the e2e gate asserts spec-metrics reports spec_chunks_present=true)
- `scripts/verify/m011-p06-e2e-pipeline.sh` → `scripts/dispatch/scope-filter.sh` (the e2e gate exercises scope-filter's --category spec/story --graph path from P04)

## Tasks

### T01: `commands/ingest.md` + evaluate.md cross-link + doc-structure verify scripts

See `tasks/T01-PLAN.md`.

### T02: End-to-end pipeline gate script + timing harness

See `tasks/T02-PLAN.md`.

### T03: Dogfood evidence capture + Bash 3.2 compat + command-reference-preservation regression

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 (no new deps beyond P03/P05)
T02 (no new deps beyond P03/P05; independent from T01)
T03 depends on T01 + T02
```

T01 produces the user-facing `orchestrator:ingest` command document and the minimal cross-link from `commands/evaluate.md` so users discover ingest before running evaluate on an un-chunked spec. T01 also delivers four doc-shape verify scripts (structure, conventions, re-ingest contract, evaluate-doc-mentions-ingest). T02 produces the end-to-end pipeline gate script and the timing harness — a sandboxed run of `ingest-spec.sh` → `rebuild-index.sh` → `spec-metrics.sh` → `scope-filter.sh --category spec/story --graph` exercising the P05 chunks-first branch. T03 delivers the consolidated dogfood evidence (real in-repo spec run, transcript, metrics, story IDs, timing) plus regression guards: Bash 3.2 compat across new scripts, and the preserved-references regression for `commands/evaluate.md` + `commands/roadmap.md`.

T01 and T02 are independent and can run in parallel; T03 waits for both because it runs the evidence-capture pipeline (which depends on T02's scripts for timing measurement) and the preserved-references regression (which depends on T01's evaluate.md edit).

## Files Likely Touched

- `commands/ingest.md` (create)
- `commands/evaluate.md` (modify)
- `.orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt` (create)
- `.orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt` (create)
- `.orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt` (create)
- `.orchestrator/milestones/M011/phases/P06/evidence/timing.txt` (create)
- `scripts/verify/m011-p06-ingest-doc-structure.sh` (create)
- `scripts/verify/m011-p06-ingest-doc-conventions.sh` (create)
- `scripts/verify/m011-p06-ingest-doc-reingest-contract.sh` (create)
- `scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh` (create)
- `scripts/verify/m011-p06-e2e-pipeline.sh` (create)
- `scripts/verify/m011-p06-e2e-pipeline-timing.sh` (create)
- `scripts/verify/m011-p06-evidence-present.sh` (create)
- `scripts/verify/m011-p06-bash32-compat.sh` (create)
- `scripts/verify/m011-p06-commands-preserve-references.sh` (create)
