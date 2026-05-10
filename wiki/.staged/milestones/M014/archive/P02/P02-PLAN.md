---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M014"
goal: "Extend the FR-12 dual-write helper from a single write-site (P01 `orchestrator:specify`) to every enumerated `CLAUDE.md` write-site in the codebase (`orchestrator:init`, `orchestrator:reinit-handler`, `orchestrator:consolidate`); ship the FR-13 drift detector as a new pass inside `scripts/diagnostics/check-docs.sh` with a `DOCTOR:DRIFT` output contract; surface drift findings through `orchestrator:doctor`; migrate the pre-existing repo-root `## Recent Changes` entries into the marker-bounded region; clean up the P01 dogfood residue; and gate the whole surface behind a phase-verification suite."
demo_sentence: "A maintainer on a fresh clone runs `bash scripts/lifecycle/init-project.sh --project-dir <scratch> --runtime claude-code` then `bash scripts/knowledge/consolidate-artifacts.sh <scratch>/.orchestrator M001`; both commands populate byte-identical marker-bounded regions in `<scratch>/CLAUDE.md` and `<scratch>/AGENTS.md` (regions: `project-identity`, `recent-changes`); `bash scripts/diagnostics/check-docs.sh --root <scratch>` prints `DOCTOR:DRIFT status=ok regions=2 divergences=0`; `bash scripts/diagnostics/run-doctor.sh --root <scratch>` includes a `Runtime Instruction Drift` section reporting zero drift; `bash scripts/verify/m014-p02-phase-suite.sh` exits 0 across all six gates."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

<!-- Every Truth `Check:` command is a single-script-file invocation per AD-19. -->

### Truths

- The P02 write-site manifest at [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) enumerates every call site in the repo that writes to `CLAUDE.md` or `AGENTS.md` through the P02 surface. The enumeration names exactly four call sites — `scripts/specify/specify.sh` (P01, unchanged, listed for completeness), `scripts/lifecycle/init-project.sh` (P02/T02, region `project-identity`), `scripts/lifecycle/reinit-handler.sh` (P02/T02, region `project-identity`), `scripts/knowledge/consolidate-artifacts.sh` (P02/T03, region `recent-changes`) — and names the marker region each site writes. No call site writes `CLAUDE.md` or `AGENTS.md` outside the enumerated set.
  - Check: `bash scripts/verify/m014-p02-write-site-manifest.sh`

- `scripts/lifecycle/init-project.sh` invokes `scripts/util/dual-write-runtime-md.sh --marker project-identity --content <tmp-fragment> --root "$PROJECT_DIR"` after writing the runtime-native instruction file (Step 12 in the existing pipeline), passing a fragment capturing `project_name`, `runtime`, `cap_score`, `recommended_intensity`, and `initialized_at` as five one-line key=value entries. The invocation is wrapped in a preflight check that skips cleanly (with a `SKIPPED:` stderr line) when `scripts/util/dual-write-runtime-md.sh` is not present (future-proofing for installs without the helper). The P02 `unit_close` JSONL record emitted at end-of-run carries a `dual_writes` field counting the invocations.
  - Check: `bash scripts/verify/m014-p02-init-dual-write.sh`

- `scripts/lifecycle/reinit-handler.sh` invokes the same helper with the same marker and content shape as `init-project.sh` after the merged instruction file is renamed into place (between lines 249 and 255 of the pre-P02 file — after `mv -f "$merged" "$INSTRUCTION_FILE"`). The invocation is idempotent with respect to the existing `project-identity` region — a reinit rewrites the region with the new values; bytes outside the markers are preserved (`tests/test-dual-write-outside-invariant.sh` invariant still holds on reinit).
  - Check: `bash scripts/verify/m014-p02-reinit-dual-write.sh`

- `scripts/knowledge/consolidate-artifacts.sh` invokes `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content <tmp-fragment> --root "$PROJECT_ROOT"` after the knowledge-lifecycle advisory checks (between lines 181 and 184) with a one-line fragment `- <milestone-id>: milestone consolidated (<reduction>% reduction, <archived-count> phases archived)`. The append preserves existing marker-region entries (appends above the closing marker, not replacement). The command emits an `unit_close` JSONL record with `{command: "orchestrator:consolidate", milestone_id, dual_writes, reduction_pct, archived_count, elapsed_ms, source: "runtime"}` shape consistent with [M019](../../../../milestones/M019/index.md) Tier 1 and FR-16.
  - Check: `bash scripts/verify/m014-p02-consolidate-dual-write.sh`

- `scripts/diagnostics/check-docs.sh --check drift [--root <project-root>]` executes the new `runtime_instruction_drift` detection pass (additive — the default no-flag invocation still runs the [M006](../../../../milestones/M006/index.md) docs-completeness pass). The drift pass compares marker-bounded regions between `CLAUDE.md` and `AGENTS.md`: detects (a) marker present in one file but absent in the other (`missing_region`), (b) both markers present but region bytes differ (`byte_divergence`), (c) opening marker without closing marker (`unmatched_marker`). For each finding, emits one line of shape `DRIFT: <kind> region=<name> file=<file-path>` on stderr. Summary line on stdout: `DOCTOR:DRIFT status=<ok|warn> regions=<N> divergences=<M>`. Exit 0 on ok, exit 0 on warn (advisory per FR-13 v1 stance; escalation to failure is future-milestone work). Missing `CLAUDE.md` or `AGENTS.md` → `DOCTOR:DRIFT status=skip reason=<absent-file>` and exit 0.
  - Check: `bash scripts/verify/m014-p02-check-docs-drift.sh`

- `scripts/diagnostics/run-doctor.sh` includes a new `Runtime Instruction Drift` section that invokes `bash scripts/diagnostics/check-docs.sh --check drift --root $PROJECT_ROOT` (advisory flag set to `1` — warn status does not fail the overall diagnostic). The section is inserted between `Documentation Completeness` and the `Graph Health` block. The DOCTOR:DRIFT output line is displayed verbatim; individual `DRIFT:` findings appear on subsequent lines.
  - Check: `bash scripts/verify/m014-p02-run-doctor-drift-section.sh`

- `commands/doctor.md` documents the new `runtime_instruction_drift` check under `## What It Checks` as a fifth bullet: `5. **Runtime Instruction Drift**: `CLAUDE.md` and `AGENTS.md` marker-bounded region comparison (FR-13 advisory in v1).` The command file passes `scripts/verify/anti-pattern-lint.sh` without flags.
  - Check: `bash scripts/verify/m014-p02-doctor-md.sh`

- Pre-existing `## Recent Changes` entries in the repo-root `CLAUDE.md` have been migrated into the `# >>> orchestrator:recent-changes >>>` marker region; the stale `- 021-test-exporter: foo` dogfood entry has been removed; the corresponding dogfood `AGENTS.md` has been regenerated to byte-match `CLAUDE.md`'s marker region. The migration is a one-time script — `scripts/migrate/m014-p02-migrate-recent-changes.sh` — with an `--dry-run` flag that emits the planned edits as FR-19 JSONL manifest records without disk writes. The script is idempotent: re-running it on an already-migrated tree is a no-op and exits 0 with `SUMMARY: already-migrated`.
  - Check: `bash scripts/verify/m014-p02-migration-idempotent.sh`

- Every P02-created or P02-modified shell script passes `scripts/verify/anti-pattern-lint.sh` (Class A + Class B clean). Every P02 shell script is Bash 3.2 compatible (no `declare -A`, `mapfile`, `${var,,}`, `<(...)`, `&>`). Every command introduced or patched by P02 (`orchestrator:init`, `orchestrator:consolidate`, `orchestrator:doctor`) emits its `unit_close` JSONL record in the M019 Tier 1 shape per FR-16.
  - Check: `bash scripts/verify/m014-p02-lint-and-bash32.sh`

- `bash scripts/verify/m014-p02-phase-suite.sh` orchestrates all P02 gates (write-site-manifest, init-dual-write, reinit-dual-write, consolidate-dual-write, check-docs-drift, run-doctor-drift-section, doctor-md, migration-idempotent, lint-and-bash32) and exits 0 on green; non-zero with a per-gate breakdown otherwise.
  - Check: `bash scripts/verify/m014-p02-phase-suite.sh`

### Artifacts

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) (min 30 lines, contains "project-identity") — the enumerated call-site manifest
- `scripts/lifecycle/init-project.sh` (modify — dual-write invocation added after instruction-file render; passes anti-pattern-lint)
- `scripts/lifecycle/reinit-handler.sh` (modify — dual-write invocation added after merged-instruction rename; passes anti-pattern-lint)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — dual-write + unit_close JSONL emission added before the final `CONSOLIDATE: ...` stdout line; passes anti-pattern-lint)
- `scripts/diagnostics/check-docs.sh` (modify — additive `--check drift` mode; default no-flag invocation preserves M006 behavior byte-for-byte; passes anti-pattern-lint)
- `scripts/diagnostics/run-doctor.sh` (modify — new `Runtime Instruction Drift` run_check line; advisory flag = 1; passes anti-pattern-lint)
- `commands/doctor.md` (modify — new bullet under What It Checks; passes anti-pattern-lint)
- `scripts/migrate/m014-p02-migrate-recent-changes.sh` (create; min 100 lines, contains "recent-changes") — one-time migration
- `scripts/verify/m014-p02-write-site-manifest.sh` (create; min 30 lines, contains "project-identity")
- `scripts/verify/m014-p02-init-dual-write.sh` (create; min 40 lines, contains "dual-write-runtime-md")
- `scripts/verify/m014-p02-reinit-dual-write.sh` (create; min 40 lines, contains "dual-write-runtime-md")
- `scripts/verify/m014-p02-consolidate-dual-write.sh` (create; min 40 lines, contains "recent-changes")
- `scripts/verify/m014-p02-check-docs-drift.sh` (create; min 40 lines, contains "DOCTOR:DRIFT")
- `scripts/verify/m014-p02-run-doctor-drift-section.sh` (create; min 30 lines, contains "Runtime Instruction Drift")
- `scripts/verify/m014-p02-doctor-md.sh` (create; min 25 lines, contains "runtime_instruction_drift")
- `scripts/verify/m014-p02-migration-idempotent.sh` (create; min 40 lines, contains "already-migrated")
- `scripts/verify/m014-p02-lint-and-bash32.sh` (create; min 30 lines, contains "anti-pattern-lint")
- `scripts/verify/m014-p02-phase-suite.sh` (create; min 40 lines, contains "m014-p02")

### Key Links

- `WRITE-SITES.md` → `scripts/util/dual-write-runtime-md.sh` (names the P01 helper as the single write surface)
- `WRITE-SITES.md` → `scripts/specify/specify.sh` (P01 call site — documented for completeness)
- `WRITE-SITES.md` → `scripts/lifecycle/init-project.sh` (P02 call site)
- `WRITE-SITES.md` → `scripts/lifecycle/reinit-handler.sh` (P02 call site)
- `WRITE-SITES.md` → `scripts/knowledge/consolidate-artifacts.sh` (P02 call site)
- `scripts/lifecycle/init-project.sh` → `scripts/util/dual-write-runtime-md.sh` (invokes with `--marker project-identity`)
- `scripts/lifecycle/reinit-handler.sh` → `scripts/util/dual-write-runtime-md.sh` (invokes with `--marker project-identity`)
- `scripts/knowledge/consolidate-artifacts.sh` → `scripts/util/dual-write-runtime-md.sh` (invokes with `--marker recent-changes`)
- `scripts/diagnostics/check-docs.sh` → `scripts/util/dual-write-runtime-md.sh` (reads marker convention strings from helper for drift pass)
- `scripts/diagnostics/run-doctor.sh` → `scripts/diagnostics/check-docs.sh` (new `Runtime Instruction Drift` run_check invocation)
- `commands/doctor.md` → `scripts/diagnostics/check-docs.sh` (documents `--check drift` surface)
- `commands/doctor.md` → `scripts/diagnostics/run-doctor.sh` (Usage section unchanged — run-doctor still orchestrates)
- `scripts/migrate/m014-p02-migrate-recent-changes.sh` → `scripts/util/dual-write-runtime-md.sh` (final migration step dual-writes normalized region)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-write-site-manifest.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-init-dual-write.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-reinit-dual-write.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-consolidate-dual-write.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-check-docs-drift.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-run-doctor-drift-section.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-doctor-md.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-migration-idempotent.sh` (orchestrated gate)
- `scripts/verify/m014-p02-phase-suite.sh` → `scripts/verify/m014-p02-lint-and-bash32.sh` (orchestrated gate)

## Tasks

### T01: Write-site manifest + scan verifier

See `tasks/T01-PLAN.md`.

### T02: Patch `init-project.sh` + `reinit-handler.sh` with `project-identity` dual-write

See `tasks/T02-PLAN.md`.

### T03: Patch `consolidate-artifacts.sh` with `recent-changes` dual-write + `unit_close` emission

See `tasks/T03-PLAN.md`.

### T04: Extend `check-docs.sh` with drift pass + wire into `run-doctor.sh` + update `commands/doctor.md`

See `tasks/T04-PLAN.md`.

### T05: One-time migration of repo-root `## Recent Changes` into marker region + P01 dogfood cleanup

See `tasks/T05-PLAN.md`.

### T06: P02 phase verification suite — nine gates + suite orchestrator

See `tasks/T06-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──┐
       │      │
       ├──► T03 ──┐
       │      │  │
       └──► T04 ─┤
              │  ├──► T06
              └──┤
                 │
              T05 ┘
```

T01 produces the write-site manifest that scopes T02/T03/T04 — the three call-site patch tasks read it as their source of truth. T02 and T03 are mechanically independent (different files) but share the same dual-write invocation shape; dispatch may parallelize. T04 is independent of T02/T03 because the drift detector reads the two files on disk — it only needs the P01 helper and the marker convention. T05 is independent (operates on the live repo state). T06 blocks on all five predecessors and orchestrates the gates.

## Files Likely Touched

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) (create)
- `scripts/lifecycle/init-project.sh` (modify — dual-write invocation block added)
- `scripts/lifecycle/reinit-handler.sh` (modify — dual-write invocation block added)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — dual-write + unit_close emission)
- `scripts/diagnostics/check-docs.sh` (modify — additive `--check drift` mode)
- `scripts/diagnostics/run-doctor.sh` (modify — new `Runtime Instruction Drift` run_check)
- `commands/doctor.md` (modify — new bullet + reference)
- `scripts/migrate/m014-p02-migrate-recent-changes.sh` (create)
- `CLAUDE.md` (modify — one-time migration moves pre-existing Recent Changes into marker region, stale `- 021-test-exporter: foo` entry removed; bytes outside the marker region preserved byte-identically per SC-6a)
- `AGENTS.md` (modify — regenerated to byte-match CLAUDE.md's marker region content)
- `scripts/verify/m014-p02-write-site-manifest.sh` (create)
- `scripts/verify/m014-p02-init-dual-write.sh` (create)
- `scripts/verify/m014-p02-reinit-dual-write.sh` (create)
- `scripts/verify/m014-p02-consolidate-dual-write.sh` (create)
- `scripts/verify/m014-p02-check-docs-drift.sh` (create)
- `scripts/verify/m014-p02-run-doctor-drift-section.sh` (create)
- `scripts/verify/m014-p02-doctor-md.sh` (create)
- `scripts/verify/m014-p02-migration-idempotent.sh` (create)
- `scripts/verify/m014-p02-lint-and-bash32.sh` (create)
- `scripts/verify/m014-p02-phase-suite.sh` (create)
