---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M035"
name: "bash-3.2-installer-exit-status"
depends_on: []
---

## Prerequisites

- `packaging/install/install-claude-code.sh` exists at the repo root.
- `packaging/install/install-codex.sh` exists at the repo root.
- `packaging/install/install-cursor.sh` exists at the repo root.
- `scripts/lifecycle/read-project-assets.sh` exists (the pre-existing producer that feeds the process-substitution-fed `while` loops being hardened).

## Description

Each of the three installers contains the pattern:

```bash
while IFS= read -r tuple; do
  ...
done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")
```

at three locations per installer (the `project_assets` install pass, the `--uninstall` pass, and the `--repair` pass). On macOS bash 3.2, when the producing `bash read-project-assets.sh` command fails (or any inner copy/symlink step inside the loop fails on a name-collision), the process-substitution form does not propagate the inner exit status to the outer installer — the loop simply terminates and the installer continues as if nothing went wrong. SC-5 calls this out as a "collision masking" failure and demands a regression fixture that goes red on the pre-fix shape and green on the post-fix shape across both bash 3.2 and bash 4+.

This task replaces the masking pattern with an exit-status-capturing form (write the producer's stdout to a temp file, iterate the temp file with a normal `while read`, capture both the producer's exit status and any inner-loop exit status into outer variables, exit non-zero if either failed) across all three installers, and authors the regression fixture.

The shape change is a refactor of existing logic into a safer form — it does NOT introduce new compound-shell shapes that would trigger the AP-009 shape-guard. The fix uses the temp-file-iteration pattern that other framework-owned scripts already use; classifier-shape pre-validation is satisfied trivially by the chosen shape (single `bash <script>` invocations + plain `while read` over a file).

## Steps

1. **Inventory the masking pattern** in each of the three installers. Run `grep -nE 'done < <\(bash' packaging/install/install-claude-code.sh packaging/install/install-codex.sh packaging/install/install-cursor.sh` and record the line ranges. Expected: three `done < <(bash …)` sites per installer (install pass, uninstall pass, repair pass).

2. **Replace each site with the temp-file-iteration form**. The replacement shape is:

   ```bash
   # Before:
   while IFS= read -r tuple; do
     <inner work>
   done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")

   # After:
   _tuples_tmp="$(mktemp -t orch-install-tuples.XXXXXX)"
   bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" > "$_tuples_tmp"
   _producer_rc=$?
   if [ "$_producer_rc" -ne 0 ]; then
     rm -f "$_tuples_tmp"
     echo "FAIL: read-project-assets.sh exited $_producer_rc" >&2
     exit 1
   fi
   _inner_rc=0
   while IFS= read -r tuple; do
     <inner work>
     _inner_step_rc=$?
     if [ "$_inner_step_rc" -ne 0 ]; then _inner_rc=$_inner_step_rc; fi
   done < "$_tuples_tmp"
   rm -f "$_tuples_tmp"
   if [ "$_inner_rc" -ne 0 ]; then
     echo "FAIL: install pass had inner failure rc=$_inner_rc" >&2
     exit "$_inner_rc"
   fi
   ```

   Use the variable name `_tuples_tmp` (or `_inner_step_rc`) prefixed with underscore to avoid clashing with installer-scope variables. Inside `<inner work>`, identify any existing `cp` / `ln` / `rm` calls that should propagate failure: capture their exit status into `_inner_step_rc` immediately after the call.

3. **Adapt the same pattern to the two non-`read-project-assets` `done < <(…)` sites per installer** (the `--uninstall` and `--repair` passes). Same replacement shape. Use distinct temp-file names (`_uninstall_tmp`, `_repair_tmp`) to avoid cross-pass clobber if any pass calls another in the same run.

4. **Author the regression fixture** at `tests/installer-acceptance/m035-collision-exit-status.sh`. The fixture:
   - Stages a fresh project fixture under `$(mktemp -d)` and pre-populates one staged-runtime path with a *colliding* file (e.g. `<fixture>/scripts/state/resolve-root.sh` already exists with content `pre-existing collision marker`).
   - Invokes `bash packaging/install/install-claude-code.sh --project-dir <fixture>` with `BASH_VERSINFO[0]` recorded in the run header (the fixture executes under whatever bash is on PATH; the M035 SC-5 spec requires running under both bash 3.2 and bash 4+ — see `## Notes` for the matrix wiring).
   - Asserts the installer exits non-zero on the collision.
   - Repeats with `install-codex.sh` and `install-cursor.sh` against fresh fixtures.
   - Prints `PASS: m035-p00-collision-exit-status (N/3 installers exit non-zero on collision; bash <version>)` on success or `FAIL: …` with the collision-masked installer name on failure.
   - Bash 3.2 compatible.

5. **Author the project-owned shape verifier** at `tools/verify/m035-p00-bash32-collision.sh`. The verifier:
   - Greps each installer for the *forbidden* pattern `done < <(bash` and asserts it returns zero matches. (After the replacement, the only remaining `<(...)` patterns should be in non-installer files.)
   - Greps each installer for the *required* shape — at least one occurrence per installer of `mktemp` paired with a subsequent `rc=` capture (loose check; the precise variable names don't matter).
   - Greps each installer for the regression fixture's existence (`tests/installer-acceptance/m035-collision-exit-status.sh`).
   - Prints `PASS: m035-p00-bash32-collision (3 installers cleared of process-substitution masking; fixture authored)` or `FAIL: …`.
   - Bash 3.2 compatible.

6. **Run the verifier locally** to confirm green. If red, iterate steps 2–4 until the verifier passes.

## Must-Haves

This task addresses the phase must-have:

- "Each of the three installers replaces every process-substitution-fed `while read` loop that drives a write/copy step with an exit-status-capturing form…"

## Verification

```bash
bash tools/verify/m035-p00-bash32-collision.sh
bash tests/installer-acceptance/m035-collision-exit-status.sh
```

## Inputs

### From Previous Tasks

(none — this task has no upstream task in P00.)

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — installer to harden. Contains three `done < <(bash …)` sites at lines 504, 554, 568 (per current state; verify line numbers before editing).
- `packaging/install/install-codex.sh` — installer to harden. Three sites at lines 306, 356, 379 (per current state).
- `packaging/install/install-cursor.sh` — installer to harden. Three sites at lines 315, 365, 379 (per current state).
- `scripts/lifecycle/read-project-assets.sh` — pre-existing producer; emits one `tuple` per project asset on stdout. Contract: exits 0 on success, non-zero on bundle-malformed. Read-only consumed.

## Constraints

- Bash 3.2 + POSIX-sh compatibility for all installer paths (CON-3 in M035 spec).
- AP-009 shape-guard discipline: no new compound-chain shapes. The temp-file-iteration form chosen above is composed of plain `bash …`, `while … done < <file>`, and individual `if [ … ]` statements — none trigger the heuristic.
- M025 reversibility-gate (CON-1) preserved: the install→install→uninstall byte-equality round-trip must continue to hold. The shape change is internal to the loop body; outputs are unchanged.
- No changes to any file outside `packaging/install/` and the two new files (regression fixture + verifier).

## Expected Output

`bash tools/verify/m035-p00-bash32-collision.sh` exits 0 with stdout: `PASS: m035-p00-bash32-collision (3 installers cleared of process-substitution masking; fixture authored)`.

## Notes

- **bash 3.2 vs bash 4+ matrix wiring**: SC-5 demands the regression fixture run under both bash 3.2 (macOS stock) and bash 4+ (Linux / homebrew bash). The matrix wiring lands at P05/P02 plan-phase under `#Q-7` (CI runner choice). For T01, the fixture executes under whatever bash is on PATH and records the version in its header; the cross-version matrix is wired downstream when the publishing CI workflow exists. Acceptance for T01 is "fixture exists, exits non-zero on collision under at least one bash version, records the version in its run header." This is an accepted Tier 3 behavioral check for the cross-version assertion until the matrix runner exists.
- **Expected verifier output** (informational, not part of `## Verification`): `PASS: m035-p00-bash32-collision (3 installers cleared of process-substitution masking; fixture authored)`.
