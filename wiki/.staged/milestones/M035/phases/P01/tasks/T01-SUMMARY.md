---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M035"
provides:
  - "user-facing --mode=copy|symlink flag on all 3 installers; --asset-mode-override preserved as TEST-ONLY backward-compat alias; install-asset-mode.sh symlink branch retargeted to direct REPO_ROOT/<src> path (US-1 dogfood-velocity contract); install-meta.txt extended with commit_sha= + version= fields (Q-9 5-line shape); references/installation.md Symlink-mode caveats section documents Q-7 + Q-8 + bundle-hygiene; m035-acceptance fixture pair (with-sha + pre-m035) for downstream T03; two task-grain verifiers (m035-p01-mode-flag.sh + m035-p01-symlink-source-target.sh)"
requires:
  - "from:P00 what:installer hardening; from:disk what:install-claude-code.sh + install-codex.sh + install-cursor.sh + install-asset-mode.sh + CHANGELOG.md + references/installation.md"
affects:
  - "P01/T02,P01/T03,P01/T04 (drift-detection, status-line, mode-aware uninstall consume install-meta.txt new fields)"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,scripts/lifecycle/install-asset-mode.sh,references/installation.md,tests/m035-acceptance/fixtures/install-meta-with-sha.txt,tests/m035-acceptance/fixtures/install-meta-pre-m035.txt,tools/verify/m035-p01-mode-flag.sh,tools/verify/m035-p01-symlink-source-target.sh,tests/m032-acceptance/p01-symlink-mode.sh"
key_decisions:
  - "Q-G4 advisory-message wording (symlink mode unsupported on this filesystem -- re-run with --mode=copy, exit 3 unchanged); Q-7 symlinks-only at v1, hardlinks deferred (cross-machine fragility caveat documented); Q-8 --mode=symlink is Unix-only at v1, copy-mode is platform-agnostic; Q-9 install-meta.txt gains commit_sha= + version= as always-present lines, empty values explicit not skipped"
patterns_established:
  - "user-facing-flag-promoted-from-test-only-alias-without-deprecating-alias (--mode supersedes --asset-mode-override at the surface; alias preserved byte-identically for M032 acceptance scripts); symlink-target-equals-src-abs (link_target=SRC retires the runtime-cache indirection; one-line replacement for the M032/P01 11-line resolution block); install-meta.txt always-present-lines-with-explicit-empty-values (downstream drift helper distinguishes field-absent-pre-M035 from field-present-but-empty)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01/tasks/T01-mode-flag-and-symlink-source-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-08T12:55:49Z"
---

T01 promotes the M032/P01 TEST-ONLY `--asset-mode-override` flag to the
user-facing `--mode=copy|symlink` surface across all three installers
(install-claude-code.sh, install-codex.sh, install-cursor.sh), retargets
the symlink branch in `scripts/lifecycle/install-asset-mode.sh` to point
directly at the orchestrator source repo path (US-1 dogfood-velocity
contract), and extends `install-meta.txt` with two new fields
(`commit_sha=`, `version=`) the M035 P01 drift helper consumes.

## What changed

- **Flag promotion**: each installer's argument-parsing while-case block
  now recognises `--mode <copy|symlink>` and `--mode=<copy|symlink>`
  alongside the preserved `--asset-mode-override` TEST-ONLY alias. Both
  flags route into the same internal `ASSET_MODE_OVERRIDE` variable; the
  default is empty (manifest's `mode:` field wins, i.e. copy per CON-7).
  The header comments and `-h|--help` `sed` ranges were updated so the
  new flag appears in `--help`. The `--asset-mode-override` alias is
  recognised but undocumented in `--help`, preserving [M032](../../../../../milestones/M032/index.md) P01
  acceptance-script byte-identity.

- **Symlink retargeting** (`scripts/lifecycle/install-asset-mode.sh`):
  the symlink branch's resolution block is replaced with
  `link_target="$SRC"`. Previously the link target was
  `${HOME}/.claude/orchestrator-runtime/<version>/<src_base>` or
  `${PROJECT_DIR}/.orchestrator/runtime-cache/<src_base>`; now it is the
  installer-supplied absolute path under `$REPO_ROOT/`. The Windows
  fail-closed guard stays at exit code 3, with the advisory message
  updated per #Q-G4 to:
  `FAIL: symlink mode unsupported on this filesystem -- re-run with --mode=copy`.

- **install-meta.txt extension** (#Q-9): each installer now computes
  `commit_sha_val` (via `git -C "$REPO_ROOT" rev-parse HEAD` when
  `$REPO_ROOT/.git` exists; empty otherwise) and `version_val` (top-line
  `## [X.Y.Z]` heading from `CHANGELOG.md` per CON-4), then emits two
  additional `printf` lines (`commit_sha=`, `version=`) in the existing
  `{ ... } > "$meta_file"` block. Empty values are explicit lines, not
  skipped — the M035 P01 drift helper distinguishes "field absent
  (pre-M035 install)" from "field present but empty".

- **Documentation**: new `## Symlink-mode caveats` section in
  `references/installation.md` (placed before `## Uninstall`),
  documenting Unix-only-at-v1 (#Q-8), source-path stability,
  cross-machine fragility (#Q-7), and bundle-hygiene divergence between
  symlink and copy modes.

- **Fixtures**: `tests/m035-acceptance/fixtures/install-meta-with-sha.txt`
  (5-field shape) and `install-meta-pre-m035.txt` (3-field shape, SC-3b
  fallback) for downstream tasks (T03 drift helper) to consume.

- **Verifiers**: two new task-grain verifiers under `tools/verify/`:
  - `m035-p01-mode-flag.sh` greps each installer for the four expected
    case-block patterns (`--mode)`, `--mode=*)`, `--asset-mode-override)`,
    `--asset-mode-override=*)`).
  - `m035-p01-symlink-source-target.sh` stages a `mktemp -d` fixture,
    runs `install-claude-code.sh --mode=symlink --project-dir <fixture>`
    with `HOME` isolated to a tmp dir, then asserts (a) exit 0, (b) both
    `<fixture>/commands` and `<fixture>/scripts` are symbolic links
    whose targets resolve under `$REPO_ROOT/`, and (c) `install-meta.txt`
    contains non-empty `commit_sha=` matching `git rev-parse HEAD` and
    non-empty `version=`. POSIX-skip (rc=77) when `ln -s` is unavailable.

- **M032 acceptance test follow-through**: `tests/m032-acceptance/p01-symlink-mode.sh`
  grep updated from `'POSIX-only in v1'` to
  `'symlink mode unsupported on this filesystem'` (matching the new
  #Q-G4 advisory). Exit-code contract (rc=3) and `[ -L ... ]` symlink
  assertions unchanged. Test still passes.

## Behaviour change summary

After T01, an operator running
`bash packaging/install/install-claude-code.sh --mode=symlink --project-dir <consumer>`
sees `<consumer>/commands` (and `scripts/`, `references/`, `templates/`,
`wiki/`) as symlinks pointing AT the orchestrator source repo path.
A subsequent `git pull` in `$REPO_ROOT` updates every consumer
immediately — no per-consumer re-install required. This is the M035 P01
US-1 contract that retires the M032/P01-era runtime-cache indirection.

## Verification result

- `bash tools/verify/m035-p01-mode-flag.sh` → `PASS: m035-p01-mode-flag`
- `bash tools/verify/m035-p01-symlink-source-target.sh` → `PASS: m035-p01-symlink-source-target`
- `bash tests/m032-acceptance/p01-symlink-mode.sh` → `RESULT: ok p01-symlink-mode.sh`
  (regression-clean against the advisory-message change).

## Forward-looking

T02 picks up the orchestrator-source drift detection
(`scripts/state/check-orchestrator-drift.sh`); T03 the
`commands/status.md` headline-block drift line; subsequent T04+ the
mode-aware uninstall and phase-suite aggregator. All consume
`install-meta.txt`'s new `commit_sha=` and `version=` fields.
