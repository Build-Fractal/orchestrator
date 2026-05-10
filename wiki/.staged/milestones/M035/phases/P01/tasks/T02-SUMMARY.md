---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M035"
provides:
  - "mode-aware manifest write (symlink emits 1 row per target with mode:symlink, copy emits per-file rows as today) in all 3 installers; mode-aware --uninstall short-circuit (symlink-mode rm -f's the symlink only via -L test, copy-mode rm -f's regular files via -f test) preserving CON-1 source-repo invariant; references/installation.md § Rollback-and-symlink-mode-interaction documenting #Q-G8 (--rollback unsupported in symlink mode); tools/verify/m035-p01-mode-aware-uninstall.sh task-grain verifier exercising both round-trips with snapshot-based source-repo invariant check"
requires:
  - "from:T01 what:--mode flag + symlink-target-equals-SRC behaviour in install-asset-mode.sh + install-meta.txt sha/version fields; from:disk what:install-claude-code.sh + install-codex.sh + install-cursor.sh + references/installation.md § Symlink-mode caveats"
affects:
  - "P01/T03 (drift detection consumes the manifest format unchanged); P01/T04 (status-line drift consumes drift detection); P05 inherits the #Q-G8 documented contract for FR-12 plan-phase"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,references/installation.md,tools/verify/m035-p01-mode-aware-uninstall.sh"
key_decisions:
  - "#Q-G8 resolution recorded in references/installation.md (--rollback unsupported in symlink mode; symlink consumers are always at HEAD by construction; P05 will emit advisory + non-zero exit; P01 ships no --rollback code); manifest-write loop branches on mode_val via case block (NOT inline conditional or compound chain) so AP-009 shape-guard is honoured; codex+cursor uninstall loops upgraded from bare-rel read to tab-split shape that install-claude-code.sh has used since M032 P01"
patterns_established:
  - "single-row-per-symlink-target manifest shape (symlink mode emits one <tgt>\tmode:symlink line; copy mode keeps per-file expansion); -L/-f conditional uninstall (symlink branch tests -L only; copy branch tests -f only) so a copy-mode uninstall never accidentally removes a symlink and vice versa; verifier-snapshot source-repo invariant (ls /<dir> | head -n 1 pre/post-uninstall) — guards CON-1 against future regressions cheaply without sha-summing the entire source tree; symmetric verifier shape across mode branches with skip-when-ln-s-unavailable for symlink branch only (copy branch always runs)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01/tasks/T02-mode-aware-uninstall-PAYLOAD.md,.orchestrator/milestones/M035/phases/P01/tasks/T02-mode-aware-uninstall-PLAN.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-08T13:13:50Z"
---

T02 makes the installer manifest format and the `--uninstall` replay path
mode-aware so symlink-mode installs round-trip byte-cleanly without
`rm -rf`'ing the orchestrator source tree (CON-1 reversibility-gate),
and pre-records the `#Q-G8` rollback-and-symlink-mode-interaction
constraint so M035 P05's FR-12 plan-phase has the contract on disk.

## What changed

- **Manifest-write loop** in all three installers
  (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`)
  now branches on `mode_val` via a `case` block:
  - **symlink branch**: emits exactly one row per project_assets
    target with the literal target path and `\tmode:symlink` (the
    link path itself, not files beneath it). Conditioned on
    `[ -L <dst> ] || [ -e <dst> ]` so a missing target does not
    produce a phantom row.
  - **copy branch (default)**: unchanged — `find <tgt> -type f`
    expands to per-file rows annotated with `mode:copy`.
  Surrounding `mktemp` + `_producer_rc` capture (M035 P00 T01 bash
  3.2 exit-status hardening) is preserved verbatim — no
  reintroduction of process-substitution-fed `while read`.

- **`--uninstall` short-circuit** in all three installers now
  branches on `mode_tok` via a `case` block:
  - `mode:symlink`: removes the symlink itself iff `[ -L "$f" ]`
    holds. The orchestrator source repo is never touched (CON-1).
  - `mode:copy|*` (default fallback): removes the regular file iff
    `[ -f "$f" ]` holds — preserves existing [M025](../../../../../milestones/M025/index.md) behaviour
    byte-identically.
  The empty-dir prune step is preserved unchanged: it is a no-op
  in the symlink-mode case (no staged tree to prune) and runs
  exactly as today in the copy-mode case. The codex and cursor
  installers' pre-T02 uninstall loops parsed each line as a bare
  `rel` (no tab split); they are now upgraded to the
  `IFS= read -r line` + `awk -F'\t'` split shape that
  install-claude-code.sh has used since [M032](../../../../../milestones/M032/index.md) P01 — required for
  the mode_tok dispatch.

- **`references/installation.md`** gains
  `### Rollback-and-symlink-mode-interaction` under the existing
  `## Symlink-mode caveats` section. Documents the `#Q-G8`
  resolution: `--rollback` (FR-12, M035 P05 scope) is unsupported
  in symlink mode because symlink-mode consumers are always at
  HEAD by construction (no "previous version" of a symlink to
  restore). The advisory text P05 will emit is recorded verbatim.
  M035 P01 ships no `--rollback` code; this is a documentation-only
  contract pre-record.

- **`tools/verify/m035-p01-mode-aware-uninstall.sh`** is the new
  task-grain verifier. Single-script-file shape per AD-19, bash 3.2
  compatible. Stages an isolated `HOME` and two fresh fixtures
  (`<tmp>/sym`, `<tmp>/copy`), runs each round-trip, and asserts:
  - install exit code 0 for both modes
  - `<fixture>/scripts` is a symlink (sym mode) / regular dir (copy mode)
  - manifest carries `mode:symlink` rows (sym) / `mode:copy` rows
    AND `^scripts/.*mode:copy` per-file rows (copy)
  - uninstall exit code 0 for both modes
  - `<fixture>/scripts` is removed
  - `$REPO_ROOT/scripts` and `$REPO_ROOT/commands` are byte-identical
    pre/post (snapshot via `ls | head -n 1`) — the CON-1 source-repo
    invariant
  POSIX-skip for the symlink branch when `ln -s` is unavailable
  (mirrors the M032 P01 `p01-symlink-mode.sh` SKIP shape); copy
  branch always runs.

## Step 5 spot-check (idempotent symlink-mode re-install)

Per task plan step 5, ran `--mode=symlink` twice in a row against
the same fixture out-of-band: first run rc=0, second run rc=0,
`<fixture>/scripts` remains a symlink. Existing
`--on-operator-owned=skip` flag at install-claude-code.sh:611 covers
the FR-22 collision-check interaction; no additional code needed.
Spot-check script lived at `/tmp/m035-t02-collision-spotcheck.sh`
(not committed; out-of-band evidence).

## Verification result

- `bash tools/verify/m035-p01-mode-aware-uninstall.sh`
  --> `PASS: m035-p01-mode-aware-uninstall`
- Regression-clean against T01 verifiers:
  - `bash tools/verify/m035-p01-mode-flag.sh`
    --> `PASS: m035-p01-mode-flag`
  - `bash tools/verify/m035-p01-symlink-source-target.sh`
    --> `PASS: m035-p01-symlink-source-target`

## Pre-existing baseline issue noted (out of T02 scope)

`tests/m032-acceptance/p01-managed-bundle-shape.sh` reports
`FR-2:per-dir-count-drift:scripts actual=1175 expected=1173` — a
hard-coded per-dir count expectation that has drifted as scripts
were added across M033/[M037](../../../../../milestones/M037/index.md). Confirmed pre-existing on `main` via
`git stash` baseline test (fails with the same message before any
T02 edit). Not introduced by T02; flagging here so the orchestrator
can route the count-update fix into a paper-cut sweep or the M032
acceptance maintainer's queue.

## Forward-looking

T03 picks up `scripts/state/check-orchestrator-drift.sh` and
the install-meta.txt drift detection flow; T04 wires the drift
line into `commands/status.md` headline. T02 does NOT touch any
drift-detection code or status-line UX (those are T03 and T04
scope).
