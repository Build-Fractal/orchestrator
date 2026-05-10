---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M014"
milestone: "M014"
provides:
  - "WRITE-SITES.md four-site manifest,m014-p02-write-site-manifest.sh scan verifier with allow-list, scripts/lifecycle/init-project.sh project-identity dual-write; scripts/lifecycle/reinit-handler.sh project-identity dual-write; scripts/verify/m014-p02-init-dual-write.sh gate; scripts/verify/m014-p02-reinit-dual-write.sh gate, scripts/knowledge/consolidate-artifacts.sh recent-changes dual-write + unit_close JSONL emission; scripts/verify/m014-p02-consolidate-dual-write.sh gate verifier, FR-13 runtime-instruction drift detection in check-docs.sh --check drift mode; run-doctor.sh Runtime Instruction Drift advisory section; commands/doctor.md documentation; three gate verifiers (m014-p02-check-docs-drift.sh, m014-p02-run-doctor-drift-section.sh, m014-p02-doctor-md.sh), scripts/migrate/m014-p02-migrate-recent-changes.sh; scripts/verify/m014-p02-migration-idempotent.sh; live-repo migration of 7 legacy Recent Changes entries into marker region; stale 021-test-exporter dogfood entry removed from CLAUDE.md and AGENTS.md, scripts/verify/m014-p02-lint-and-bash32.sh + scripts/verify/m014-p02-phase-suite.sh (nine-gate orchestrator)"
requires:
  - "from:P01 what:dual-write-runtime-md.sh helper + specify.sh P01 write-site; from:disk what:anti-pattern-lint.sh, from:P01/T03 what:scripts/util/dual-write-runtime-md.sh; from:P02/T01 what:.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md, from:P01 what:scripts/util/dual-write-runtime-md.sh; from:P02/T01 what:WRITE-SITES.md manifest, from:P02/T01 what:WRITE-SITES.md marker regions; from:disk what:scripts/diagnostics/check-docs.sh (M006), scripts/diagnostics/run-doctor.sh, commands/doctor.md, from:disk what:CLAUDE.md pre-existing ## Recent Changes section + P01 dogfood marker region + AGENTS.md; from:P01 what:scripts/util/dual-write-runtime-md.sh, from:P02/T01..T05 what:eight prior-task P02 gate scripts; from:disk what:scripts/verify/anti-pattern-lint.sh"
affects:
  - "T02 dual-write add sites (init-project.sh, reinit-handler.sh), T03 dual-write add site (consolidate-artifacts.sh), phase-suite aggregator, P02/T07 phase-suite; M014/P03 drift detection; M014/P04 consolidate dual-write, P02/T07 phase-suite; M019 Tier 1 observability emitter; future consolidate dogfood runs, P02/T07 phase-suite (consumes three new gate verifiers), M014/P03-P04 (dual-write sites surfaced via drift findings), P02/T08 phase-suite (gate included), M014/P02 phase verification; unblocks phase-close for M014/P02"
key_files:
  - ".orchestrator/milestones/M014/phases/P02/WRITE-SITES.md,scripts/verify/m014-p02-write-site-manifest.sh, scripts/lifecycle/init-project.sh,scripts/lifecycle/reinit-handler.sh,scripts/verify/m014-p02-init-dual-write.sh,scripts/verify/m014-p02-reinit-dual-write.sh, scripts/knowledge/consolidate-artifacts.sh,scripts/verify/m014-p02-consolidate-dual-write.sh, scripts/diagnostics/check-docs.sh,scripts/diagnostics/run-doctor.sh,commands/doctor.md,scripts/verify/m014-p02-check-docs-drift.sh,scripts/verify/m014-p02-run-doctor-drift-section.sh,scripts/verify/m014-p02-doctor-md.sh, scripts/migrate/m014-p02-migrate-recent-changes.sh,scripts/verify/m014-p02-migration-idempotent.sh,CLAUDE.md,AGENTS.md, scripts/verify/m014-p02-lint-and-bash32.sh,scripts/verify/m014-p02-phase-suite.sh,scripts/lifecycle/reinit-handler.sh"
key_decisions:
  - "dual-write is byte-identical (no transform) between CLAUDE.md and AGENTS.md,allow-list documents render_template full-file writes in init/reinit as orthogonal surface, Reinit verifier invokes reinit-handler directly with --mode update (init delegation without --mode exits 4 by design); outside-markers byte-preservation tested via helper re-invocation on reinit-produced file (not init→reinit diff) because reinit legitimately refreshes rendered template, DUAL_WRITE_ROOT-from-ORCH_ROOT-parent; read-concat-write append pattern; best-effort dual-write with WARN fallback, FR-13 v1 advisory stance (exit 0 even on warn); set -eu preserved (no -e drop needed with if-grep idiom); awk variable rename close->close_mk to avoid awk reserved-word collision; extended verifier with unmatched_marker scenario not in verbatim plan, dry-run dual-write-region target_path joined with -and- instead of brace-expansion to stay lint-clean; legacy_entries actual=7 not 6 as payload text stated, Fixed one prior-task false-positive: rephrased a bash4-lowercase-token literal inside a code comment in reinit-handler.sh line 70 to avoid token-scan mismatch without touching behavior"
patterns_established:
  - "write-site-manifest-with-enumeration-invariant,scan-verifier-with-allow-list-grep-v-chain,table-row-count-guard-via-grep-cE, additive dual-write between runtime-native render and config.yml write; fallback to CLAUDE.md-only when AGENTS.md gated by dual_write_agents=false; SUMMARY line carries dual_writes=<N> observability field; helper-re-invocation byte-preservation test isolates SC-6a from legitimate reinit-template refresh, dual-write-root-distinct-from-script-root; read-concat-write-for-wholesale-replace-region-helpers, mode-router-with-preserved-default-branch (default --check docs runs pre-existing M006 body; new --check drift opt-in, byte-identical default path), shasum-normalized-region-byte-compare (extract_region awk helper + shasum -a 256 hash compare handles newline edge cases), advisory-check-with-dotted-exit-zero (drift emits warn but exits 0; run-doctor advisory flag surfaces in advisory_warnings counter not checks_total), one-time migration with --dry-run/--apply/--force; already-migrated short-circuit via combined signals (marker present + no stale dogfood + no legacy section below marker); strip-then-dual-write via helper, lint+bash32 omnibus gate self-exempts like m014-p01-bash32-compat.sh; phase-suite fresh-subshell invocation to isolate gate-local state"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M014/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M014/phases/P02/tasks/T03-SUMMARY.md, .orchestrator/milestones/M014/phases/P02/tasks/T04-SUMMARY.md, .orchestrator/milestones/M014/phases/P02/tasks/T05-SUMMARY.md, .orchestrator/milestones/M014/phases/P02/tasks/T06-SUMMARY.md"
duration: "160m"
verification_result: "pass"
completed_at: "2026-04-23T00:06:52Z"
observability_surfaces:
  - "execution-log.jsonl"
---

## What Was Built

P02 extended the P01 dual-write foundation to every `CLAUDE.md` write-site in the codebase, shipped the FR-13 drift detector, and cleaned up the P01 dogfood artifacts via a one-time migration. Six tasks, 9 phase-suite gates all green.

**Write-site enumeration** (T01 → [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md)):

| # | Script | Region | Shipped |
|---|--------|--------|---------|
| 1 | `scripts/specify/specify.sh` | `recent-changes` | M014/P01/T05 |
| 2 | `scripts/lifecycle/init-project.sh` | `project-identity` | M014/P02/T02 |
| 3 | `scripts/lifecycle/reinit-handler.sh` | `project-identity` | M014/P02/T02 |
| 4 | `scripts/knowledge/consolidate-artifacts.sh` | `recent-changes` | M014/P02/T03 |

Scanner `scripts/verify/m014-p02-write-site-manifest.sh` enforces the enumeration — any new direct `CLAUDE.md`/`AGENTS.md` write outside the dual-write helper fails the gate.

**Regions canonicalized**:
- `project-identity` — five one-line key=value entries (`project_name`, `runtime`, `cap_score`, `recommended_intensity`, `initialized_at`); full-rewrite on every init/reinit via the FR-12 helper.
- `recent-changes` — append-only; existing entries preserved via read-merge-write by the helper on each new append.

**Drift detector (FR-13)**:
- `scripts/diagnostics/check-docs.sh` gained a `--check drift` mode (default `--check docs` preserves [M006](../../../../milestones/M006/index.md) behavior).
- Three drift kinds detected: `missing_region` (region in one file, absent from the other), `byte_divergence` (region present in both, bytes differ), `unmatched_marker` (opening marker without close).
- Output shape: `DOCTOR:DRIFT status=<ok|warn|skip> regions=<N> divergences=<M>`.
- Severity model (v1): **advisory**. `check-docs.sh --check drift` exits 0 even on warn. `scripts/diagnostics/run-doctor.sh` wires a new `Runtime Instruction Drift` section with the advisory flag (increments advisory counter, does not fail overall health). Escalation to failure is explicit future-milestone work.
- Double-reporting caveat documented: malformed opening-marker-only case may be reported as both `unmatched_marker` and `missing_region`; acceptable for v1.

**Migration (T05)**:
- `scripts/migrate/m014-p02-migrate-recent-changes.sh` with `--dry-run` / `--apply` / `--force` flags.
- Applied against live repo: 7 legacy Recent Changes entries (not 6 as plan text said — count computed dynamically) migrated INTO the marker region. Stale `- 021-test-exporter: foo` dogfood entry dropped. `## Recent Changes` heading-based section removed from CLAUDE.md. AGENTS.md region byte-identical to CLAUDE.md's.
- Idempotent: re-run prints `SUMMARY: already-migrated` and exits 0.
- SC-6a outside-markers byte-preservation verified.

**Observability**:
- `consolidate-artifacts.sh` emits `unit_close` JSONL to `.orchestrator/execution-log.jsonl` with `{dual_writes, elapsed_ms}`.
- `init-project.sh` / `reinit-handler.sh` dry-run + final SUMMARY lines include `dual_writes=<N>`.

## Key Decisions

- **Byte-identical dual-write retained** (not transform-based) — consistent with P01. AGENTS.md has no runtime-identification header. Transform-based remains open for later phases if FR-13 findings demonstrate need.
- **`DUAL_WRITE_ROOT` derivation in `consolidate-artifacts.sh`** (T03 deviation): `dirname($ORCH_ROOT)` instead of `--root "$PROJECT_ROOT"`. For live dogfood these coincide (repo root). For hermetic scratch testing the verifier sets `ORCH=$SCRATCH/.orchestrator` and `DUAL_WRITE_ROOT=$SCRATCH`. Unlocks hermetic testability.
- **Drift detector v1 is advisory** — warnings count; exit codes stay zero. Forces "do we escalate?" to be explicit future work.
- **Awk reserved-word collision fixed** (T04 correctness fix): plan's `-v close=` shadowed the `close()` builtin on macOS awk, causing spurious byte_divergence findings on every match. Renamed `open`/`close` → `open_mk`/`close_mk`.
- **Reinit gate invocation path** (T02 deviation): verifier calls `reinit-handler.sh --mode update` directly rather than via init's delegation. The init→reinit delegation without explicit `--mode` exits 4 by design (operator prompt), orthogonal to P02 scope.
- **SC-6a assertion reshape in reinit gate** (T02 deviation): reinit legitimately refreshes the rendered template (timestamp, re-detected project_type, `initialized_at` placeholder) — outside-markers bytes between init→reinit runs are expected to differ. The SC-6a assertion instead exercises the dual-write helper twice on the reinit-produced CLAUDE.md with identical fragments and asserts byte-identity across those helper invocations. Isolates the invariant to the mechanism it actually concerns.

## Cross-Cutting Patterns Established

- **Write-site enumeration discipline**: `WRITE-SITES.md` manifest + scanner gate prevents phantom write-sites from accumulating. Any new script wanting to write `CLAUDE.md` gets routed through the helper or added to the allow-list explicitly.
- **Allow-list pattern for orthogonal writes**: `render_template > "$INSTRUCTION_FILE"` in init/reinit is the runtime-native full-file render — orthogonal to dual-write marker mechanism. Scanner allow-lists the literal redirect pattern in these specific files; any new caller gets flagged.
- **Hermetic-root via `dirname($ORCH_ROOT)`**: decouples consolidate's dual-write target from the repo root, enabling `mktemp -d` scratch testing without touching the live tree.
- **Advisory-first drift severity model**: new diagnostic extensions ship as advisory warnings, not hard-fail. Forces explicit escalation decisions. Precedent from M006 `DOCTOR:` protocol (advisory counter separate from fail status).
- **One-time migration script pattern**: `--dry-run` → `--apply` flow with FR-19 JSONL manifest for preview, temp-file-then-rename for atomicity, idempotent `SUMMARY: already-migrated` on repeat runs.
- **Bash 3.2 scanner self-exemption for comment-embedded tokens** (T06 fix): broad-regex bash32 compat scans match literal parameter-expansion tokens inside code comments. The fix is to rephrase the comment (describe intent without the literal token) rather than complicate the scanner — inherited from P01/T07's `m014-p01-bash32-compat.sh` self-exempt precedent.

## Verification Results

**P02 phase suite**: 9/9 gates PASS, exit 0.
- `m014-p02-write-site-manifest.sh` (T01)
- `m014-p02-init-dual-write.sh` (T02)
- `m014-p02-reinit-dual-write.sh` (T02)
- `m014-p02-consolidate-dual-write.sh` (T03)
- `m014-p02-check-docs-drift.sh` (T04)
- `m014-p02-run-doctor-drift-section.sh` (T04)
- `m014-p02-doctor-md.sh` (T04)
- `m014-p02-migration-idempotent.sh` (T05)
- `m014-p02-lint-and-bash32.sh` (T06 — rollup gate for P02)

**Cross-cutting invariants**:
- SC-6a (outside-markers byte-preservation): `tests/test-dual-write-outside-invariant.sh` passes against every write-site.
- CON-6 (anti-pattern lint): every new + modified shell script passes `scripts/verify/anti-pattern-lint.sh`.
- MEM001 (Bash 3.2 compat): every new script passes the `m014-p02-lint-and-bash32.sh` rollup gate.
- Live-repo drift check against migrated state: `DOCTOR:DRIFT status=ok regions=1 divergences=0` — AGENTS.md and CLAUDE.md marker regions are byte-identical.

## Deviations Worth Surfacing

Seven task-level deviations from verbatim plan bodies, all correctness fixes or hermetic-testability enablers with documented rationale:

1. **T02**: reinit gate invocation path (init→reinit exits 4 without `--mode`; verifier calls reinit directly).
2. **T02**: SC-6a assertion reshape (isolate invariant to helper splice, not end-to-end rerender).
3. **T03**: `DUAL_WRITE_ROOT` derivation via `dirname($ORCH_ROOT)` for hermetic testability.
4. **T03**: verifier grep narrowed (alternation branch was unreachable).
5. **T04**: awk reserved-word collision fix (`close` → `close_mk`) — caught at dispatch time; plan was broken as written on macOS awk.
6. **T04**: additive scenario 4b + subsection in doctor.md documenting double-reporting.
7. **T05**: legacy-count text said 6 entries, live repo had 7 (dynamic count handled correctly by script); brace-expansion in dry-run JSON replaced with hyphen-joined path (anti-pattern-lint compliance).

All documented in their respective task summaries. No deviations affected cross-task contracts or downstream phase scope.

## State After P02

- Every `CLAUDE.md` write-site in the codebase routes through `scripts/util/dual-write-runtime-md.sh` — no direct redirects remain outside the allow-list.
- `AGENTS.md` exists in the repo root with marker-bounded regions byte-identical to `CLAUDE.md`.
- `CLAUDE.md` Recent Changes now lives in the `recent-changes` marker region; the old heading-based section is gone. Stale dogfood entry removed.
- `orchestrator:doctor` now includes a Runtime Instruction Drift advisory section.
- `check-docs.sh` has both M006 docs completeness and FR-13 drift detection modes.
- P03 stays deferred (blocked on [M012](../../../../milestones/M012/index.md) DEPLOY-RECORD resolution + ≥1 week inbox dogfood data per D018). P04 is next.
