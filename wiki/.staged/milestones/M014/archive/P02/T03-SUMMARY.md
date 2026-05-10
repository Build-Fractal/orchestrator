---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M014"
provides:
  - "scripts/knowledge/consolidate-artifacts.sh recent-changes dual-write + unit_close JSONL emission; scripts/verify/m014-p02-consolidate-dual-write.sh gate verifier"
requires:
  - "from:P01 what:scripts/util/dual-write-runtime-md.sh; from:P02/T01 what:WRITE-SITES.md manifest"
affects:
  - "P02/T07 phase-suite; M019 Tier 1 observability emitter; future consolidate dogfood runs"
key_files:
  - "scripts/knowledge/consolidate-artifacts.sh,scripts/verify/m014-p02-consolidate-dual-write.sh"
key_decisions:
  - "DUAL_WRITE_ROOT-from-ORCH_ROOT-parent; read-concat-write append pattern; best-effort dual-write with WARN fallback"
patterns_established:
  - "dual-write-root-distinct-from-script-root; read-concat-write-for-wholesale-replace-region-helpers"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P02/tasks/T03-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-22T23:47:45Z"
---

## What Was Built

Patched `scripts/knowledge/consolidate-artifacts.sh` to dual-write a milestone-consolidation entry to the `recent-changes` marker-bounded region of CLAUDE.md and AGENTS.md via the P01 FR-12 helper, and to append a single `unit_close` JSONL record to `.orchestrator/execution-log.jsonl` carrying the [M019](../../../../milestones/M019/index.md) Tier 1 shape.

## Key Decisions

- **DUAL_WRITE_ROOT derived from `$ORCH_ROOT` parent**, not from the script-local `$PROJECT_ROOT` (which locates the helper). This decouples the dual-write target from the script location and makes the script hermetically testable against a scratch state directory. Plan-flagged risk resolved: for live dogfood runs `dirname(.orchestrator)` equals the repo root, so live behavior is unchanged.
- **Existing region entries preserved on append** by reading the current `recent-changes` region content from `$DUAL_WRITE_ROOT/CLAUDE.md` into a temp file, concatenating the new one-line entry below it, and passing the combined fragment to the helper (which does wholesale-region-replace). This satisfies the "append above closing marker, not replacement" contract in WRITE-SITES.md.
- **Dual-write best-effort**: primary attempt writes both `CLAUDE.md` + `AGENTS.md`; on failure, falls back to `CLAUDE.md`-only; on further failure, emits `WARN:` and continues (consolidation itself remains non-blocking). `DUAL_WRITES` tracks the count (0/1/2) for the JSONL record.
- **`START_EPOCH_MS` capture moved adjacent to `ORCH_ROOT` parsing** (line 47) rather than immediately after — keeps the sequencing of argument handling intact; the intervening `DUAL_WRITE_ROOT` resolve line is cheap and deterministic.
- **`unit_close` JSONL append is defensive**: `mkdir -p "$ORCH_ROOT"` + redirect to `>> $LOG_FILE 2>/dev/null`; failure emits `WARN:` and the script still exits 0 per FR-16.

## Cross-Cutting Patterns Established

- **Dual-write-root distinct from script-root**: `$DUAL_WRITE_ROOT = dirname($ORCH_ROOT)` pattern establishes that consolidator-style scripts can target arbitrary state trees (including scratch fixtures) without a `--project-root` override flag. Reusable for future call sites where the dual-write target and script-discovery root diverge.
- **Read-concat-write append pattern for wholesale-replace region helpers**: when a helper replaces a marker-bounded region wholesale, preserving existing region entries requires reading the existing region, concatenating the new line, and passing the combined content. The pattern is encapsulated in a short awk block that matches the open/close markers byte-exactly.

## Verification Results

- `bash scripts/verify/m014-p02-consolidate-dual-write.sh` — PASS (hermetic scratch milestone asserts: marker present, new entry in both CLAUDE.md and AGENTS.md, existing entry preserved, outside-markers shasum unchanged, unit_close JSONL with `"command":"orchestrator:consolidate"` + `"milestone":"M999"` appended).
- `bash tests/test-dual-write-outside-invariant.sh` — PASS (SC-6a byte-preservation regression check).
- `bash scripts/verify/m014-p02-reinit-dual-write.sh` — PASS (T02 gate still green, no cross-task regression).
- `bash scripts/verify/anti-pattern-lint.sh --fixture scripts/knowledge/consolidate-artifacts.sh` — LINT PASS.
- `bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p02-consolidate-dual-write.sh` — LINT PASS.
- Bash 3.2 compatible: no `declare -A`, no process substitution, no `mapfile`, no `&>`; uses `printf`/`awk`/`cat`/`mktemp`/`rm -f` only.

## Deviations From Verbatim Plan

- **`DUAL_WRITE_ROOT` introduced** — plan's verbatim patch used `--root "$PROJECT_ROOT"` (the repo root), which would route hermetic-test writes to the live repo and fail the scratch-fixture verifier. `DUAL_WRITE_ROOT = $(cd "$(dirname "$ORCH_ROOT")" && pwd)` preserves production behavior (live `.orchestrator/`'s parent is the repo root) while enabling scratch-directory testing. Documented in-code comment.
- **`START_EPOCH_MS` moved**: plan said "after line 45"; I placed it adjacent to the `DUAL_WRITE_ROOT` resolve for readability. No semantic change.
- **Grep shape check narrowed**: verifier's unit_close grep uses `'orchestrator:consolidate'` substring match instead of plan's `'unit_close\|"command":"orchestrator:consolidate"'` alternation — the emitted JSONL does not contain the literal string `unit_close` (that's the record type name, not a field value), so only the substring branch can match. The plan's alternation was logically OR-ed with an always-false branch; narrowing matches actual output shape.

No deviation crosses task contracts or downstream phase surfaces.

## Live-Repo Mutations

None from this task. Pre-existing diff on `CLAUDE.md` (marker region with stale `- 021-test-exporter: foo` entry) and untracked `AGENTS.md` are P01/T05 dogfood artifacts, documented in the P01 phase summary; P02's migration task is scoped to clean these up.

## Files Changed

- Modified: `scripts/knowledge/consolidate-artifacts.sh` (+55 lines: `START_EPOCH_MS` + `DUAL_WRITE_ROOT` + dual-write block + unit_close emission)
- Created: `scripts/verify/m014-p02-consolidate-dual-write.sh` (executable, ~100 lines, hermetic scratch milestone fixture)

## Ready For Downstream

T04+ tasks in P02 (check-docs drift detector, run-doctor hookup, migration script, phase suite) can treat this task's outputs as stable. The `unit_close` JSONL shape matches FR-16 / M019 Tier 1 verbatim; drift detector will find well-formed `recent-changes` regions in both CLAUDE.md and AGENTS.md after a consolidate pass.
