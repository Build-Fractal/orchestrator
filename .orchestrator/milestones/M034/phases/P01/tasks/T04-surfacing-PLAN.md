---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M034"
name: "status/doctor unreviewed-decision surfacing"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `scripts/knowledge/lib/decisions-constants.sh` exists (T01 — provides `DECISIONS_WARN_FINDING_THRESHOLD`).
- `scripts/knowledge/write-decisions.sh` exists (T02 — emits the `*-DECISIONS.md` packets this task reads).
- `scripts/diagnostics/render-status-json.sh` exists (the FR-4 status integration point — modify). Sectioned JSON renderer; read-only; bash 3.2.
- `scripts/diagnostics/run-doctor.sh` exists (the FR-4 doctor integration point — modify). Registers checks via `run_check "<name>" "<script>" "<args>" "<advisory 0|1>"`; new-style checks emit a `DOCTOR: status=ok|warn|skip ...` line parsed by `run_check`.
- Other `scripts/diagnostics/check-*.sh` exist as the pattern to mirror (e.g. `check-stale.sh`).

## Description

FR-4 + SC-2. Surface unreviewed load-bearing decisions in `status` and `doctor`:
1. Author `scripts/knowledge/read-decisions.sh` — the read engine: counts active (non-superseded) and unreviewed decision entries in a packet or a directory of packets.
2. Add a per-phase `unreviewed_decisions` integer to `render-status-json.sh` output (SC-2).
3. Author `scripts/diagnostics/check-decisions.sh` — an advisory doctor check that flags when active unreviewed `warn`-severity entries cross `DECISIONS_WARN_FINDING_THRESHOLD`.
4. Wire that check into `run-doctor.sh`.

**"Unreviewed" definition (v1).** An active entry is *reviewed* iff a sibling `*-REVIEW.md` (co-located, same basename stem) records its id as adjudicated. In P01 there is no walkthrough and no `*-REVIEW.md`, so every active entry is unreviewed — the count equals the active-entry count. The reader is written to honor a present `*-REVIEW.md` (so P02's gate drives the count to zero), but P01 verifies only the non-zero half of SC-2; the zero-after-SIGNOFF half is forward-verified at P02 (recorded in `M034-P01-ADDENDUM.md`).

## Steps

1. Author `scripts/knowledge/read-decisions.sh` sourcing the SSOT. Subcommands:
   - `active-count <packet-file>` → integer count of `## <id>` blocks that do NOT contain a `- **superseded_by**:` line. (Active view, #Q-1.)
   - `unreviewed-count <packet-file>` → active entries whose id is NOT marked reviewed in a sibling `*-REVIEW.md`. Resolve the sibling by replacing the `-DECISIONS.md` suffix with `-REVIEW.md`; if absent, every active entry is unreviewed. A REVIEW entry counts an id as reviewed if the REVIEW file contains a line matching `reviewed: <id>` or `- **id**: <id>` under a reviewed block (forward-compatible with P02's REVIEW.md shape — keep the match liberal).
   - `unreviewed-warn-count <packet-file>` → like `unreviewed-count` but only entries whose active block has `- **severity**: warn`.
   - `dir-unreviewed-count <dir>` → sum of `unreviewed-count` over every `*-DECISIONS.md` found at depth ≤ 3 under `<dir>` (0 when none).
   Each subcommand prints a single integer to stdout. Bash 3.2; loops/`grep`/`awk` inside the body are fine.

2. **Modify `render-status-json.sh`** to add an `unreviewed_decisions` integer to each per-phase object. Read the renderer to locate where phase objects are assembled; for each phase with an on-disk phase directory, compute the value via `read-decisions.sh dir-unreviewed-count <phase-dir>` (default `0` on any error or when the phase dir / packet is absent). Preserve `schema_version` and the AD-2 unconditional ANSI-strip discipline; do not break the existing JSON shape — this is an ADDITIVE field. If the renderer's structure makes a clean per-phase hook impractical, instead add a single top-level `unreviewed_decisions` total for the active milestone and document the per-phase deferral in `## Notes` — but prefer per-phase.

3. Author `scripts/diagnostics/check-decisions.sh` (mirror an existing `check-*.sh`): accept `--root <path>` (default the resolved orchestrator root). Source the SSOT. Walk `<root>/milestones/*/` (and phase dirs) for `*-DECISIONS.md`; sum active unreviewed `warn`-severity entries via `read-decisions.sh unreviewed-warn-count`. Emit exactly one `DOCTOR:` line:
   - if the sum `>= DECISIONS_WARN_FINDING_THRESHOLD`: `DOCTOR: status=warn check=decisions unreviewed_warn=<N> threshold=<T> — recurring unreviewed warn-severity decisions`
   - else: `DOCTOR: status=ok check=decisions unreviewed_warn=<N> threshold=<T>`
   Exit 0 in both cases (advisory; `run_check` reads the status from the `DOCTOR:` line, not the exit code). If no packets exist anywhere, emit `DOCTOR: status=skip check=decisions — no decision packets found` and exit 0.

4. **Wire into `run-doctor.sh`**: add, alongside the other advisory `run_check` lines (near `check-corpus-exhaustion.sh` at ~`:225`), the line:
   `run_check "Unreviewed Decisions" "$SCRIPT_DIR/check-decisions.sh" "--root $PROJECT_ROOT" "1"`
   (advisory `1` — an unreviewed-decision backlog is a health signal, not a hard failure).

5. Co-author `tools/verify/m034-p01-surfacing.sh`:
   - Build a throwaway packet under `$TMPDIR` via the T02 writer (or copy the P00 baseline fixture) containing ≥3 active warn-severity entries.
   - Assert `read-decisions.sh active-count` and `unreviewed-count` return the expected non-zero integers, and that adding a sibling `*-REVIEW.md` marking one id reviewed drops `unreviewed-count` by 1.
   - Assert `check-decisions.sh --root <tmp-root>` emits `DOCTOR: status=warn` when ≥`DECISIONS_WARN_FINDING_THRESHOLD` unreviewed warn entries exist, and `status=ok`/`status=skip` otherwise.
   - Assert `render-status-json.sh` output contains the `unreviewed_decisions` key (grep the rendered JSON for a fixture milestone).
   - Assert `run-doctor.sh` source contains the `Unreviewed Decisions` `run_check` wiring.
   - Print `PASS: m034-p01 surfacing` / `FAIL: ...`.

## Must-Haves

- `read-decisions.sh` counts active (non-superseded) and unreviewed entries, honoring a sibling `*-REVIEW.md` (FR-4 engine).
- `status` (via `render-status-json.sh`) reports an `unreviewed_decisions` count (SC-2).
- `doctor` carries an advisory check flagging when unreviewed warn-severity entries cross the SSOT threshold (FR-4).

## Verification

`bash tools/verify/m034-p01-surfacing.sh`
`grep -q "DOCTOR:" scripts/diagnostics/check-decisions.sh`
`grep -q "unreviewed_decisions" scripts/diagnostics/render-status-json.sh`
`grep -q "Unreviewed Decisions" scripts/diagnostics/run-doctor.sh`

## Notes

Expected: `bash tools/verify/m034-p01-surfacing.sh` prints `PASS: m034-p01 surfacing` and exits 0; the three `grep` commands exit 0. The threshold and the `warn` value come from the SSOT (`DECISIONS_WARN_FINDING_THRESHOLD`, `DECISIONS_SEVERITY_VALUES`) — do not hard-code them in `check-decisions.sh`.

SC-2's "zero after the gate populates SIGNOFF.md" half is a P02 concern (no gate exists in P01). The reader's `*-REVIEW.md` awareness is built now so P02 inherits a working zero-path; the P01 verifier exercises the review-drops-the-count behavior with a synthetic `*-REVIEW.md`, which is the same mechanism P02's gate will drive.

**Real-app smoke test pending — confirm before phase close** (plan-time discipline rule 5, non-DB variant): after T04 lands, run `bash scripts/diagnostics/render-status-json.sh --milestone M034` against the live repo and confirm it still emits valid JSON with the new field and no regression in the existing sections. The verifier asserts the field's presence on a fixture; the live smoke confirms no breakage of the real status path.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/lib/decisions-constants.sh` (T01) — `DECISIONS_WARN_FINDING_THRESHOLD="3"`, `DECISIONS_SEVERITY_VALUES="warn block"`.
- `scripts/knowledge/write-decisions.sh` (T02) — emits packets whose active entries lack `superseded_by` and superseded entries carry it; `severity` is a `- **severity**: <value>` bullet line.
- `scripts/diagnostics/render-status-json.sh` — sectioned JSON renderer; AD-2 ANSI-strip; `_M029_SCHEMA_VERSION` constant; read-only. Locate the per-phase object assembly to add the additive field.
- `scripts/diagnostics/run-doctor.sh` — `run_check "<name>" "<script>" "<args>" "<advisory>"`; advisory checks pass `1`; new-style checks emit `DOCTOR: status=...`. Advisory `run_check` lines cluster around `:222-226`.
- `scripts/diagnostics/check-stale.sh` (or any `check-*.sh`) — the `--root` flag + `DOCTOR:` emission pattern to mirror.

## Constraints

- Bash 3.2 / POSIX-sh single file for the new scripts (CON-1 / AD-19). `render-status-json.sh`/`run-doctor.sh` edits stay within their existing bash-3.2 style.
- CON-4: read the threshold + severity values from the SSOT; never hard-code.
- `render-status-json.sh` stays read-only (FR-14 carry-forward): the new field is computed, never written to disk.
- Additive only: do not change existing JSON keys or the doctor pass/fail semantics (the new check is advisory).
- Do NOT author the writer (T02), producer (T03), or the addendum/aggregator (T05).

## Expected Output

`scripts/knowledge/read-decisions.sh` + `scripts/diagnostics/check-decisions.sh` + `tools/verify/m034-p01-surfacing.sh` created; `render-status-json.sh` + `run-doctor.sh` modified. `status` reports `unreviewed_decisions`; `doctor` carries the advisory Unreviewed Decisions check.
