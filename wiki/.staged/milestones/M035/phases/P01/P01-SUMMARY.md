---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M035"
milestone: "M035"
provides:
  - "user-facing --mode=copy|symlink flag on all 3 installers; --asset-mode-override preserved as TEST-ONLY backward-compat alias; install-asset-mode.sh symlink branch retargeted to direct REPO_ROOT/<src> path (US-1 dogfood-velocity contract); install-meta.txt extended with commit_sha= + version= fields (Q-9 5-line shape); references/installation.md Symlink-mode caveats section documents Q-7 + Q-8 + bundle-hygiene; m035-acceptance fixture pair (with-sha + pre-m035) for downstream T03; two task-grain verifiers (m035-p01-mode-flag.sh + m035-p01-symlink-source-target.sh),mode-aware manifest write (symlink emits 1 row per target with mode:symlink,copy emits per-file rows as today) in all 3 installers; mode-aware --uninstall short-circuit (symlink-mode rm -f's the symlink only via -L test,copy-mode rm -f's regular files via -f test) preserving CON-1 source-repo invariant; references/installation.md § Rollback-and-symlink-mode-interaction documenting #Q-G8 (--rollback unsupported in symlink mode); tools/verify/m035-p01-mode-aware-uninstall.sh task-grain verifier exercising both round-trips with snapshot-based source-repo invariant check,scripts/state/check-orchestrator-drift.sh (read-only drift helper,FR-3 / FR-15); SHA-absent fallback per #Q-G5; tools/verify/m035-p01-drift-detection.sh (SC-3 SHA-bearing path); tools/verify/m035-p01-drift-detection-sha-absent.sh (SC-3b pre-M035 fallback path),drift-line render path wired into both TUI (commands/status.md doc-step) and JSON (render-status-json.sh top-level `drift` object); FR-4/FR-16 suppression matrix implementation; § Drift Line (M035 P01) addendum on status-headline-shape.md + § drift (M035 P01) addendum on status-json-schema.md; m035-p01-drift-line-in-status.sh (SC-4 primary) + m035-p01-drift-line-suppressed.sh (3 sub-cases) + m035-p01-phase-suite.sh AD-19-prefixed P01 aggregator"
requires:
  - "P00"
affects:
  - "P01.5"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,scripts/lifecycle/install-asset-mode.sh,references/installation.md,tests/m035-acceptance/fixtures/install-meta-with-sha.txt,tests/m035-acceptance/fixtures/install-meta-pre-m035.txt,tools/verify/m035-p01-mode-flag.sh,tools/verify/m035-p01-symlink-source-target.sh,tests/m032-acceptance/p01-symlink-mode.sh,tools/verify/m035-p01-mode-aware-uninstall.sh,scripts/state/check-orchestrator-drift.sh,tools/verify/m035-p01-drift-detection.sh,tools/verify/m035-p01-drift-detection-sha-absent.sh,scripts/diagnostics/render-status-json.sh,commands/status.md,references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m035-p01-drift-line-in-status.sh,tools/verify/m035-p01-drift-line-suppressed.sh,tools/verify/m035-p01-phase-suite.sh"
key_decisions:
  - "Q-G4 advisory-message wording (symlink mode unsupported on this filesystem -- re-run with --mode=copy,exit 3 unchanged); Q-7 symlinks-only at v1,hardlinks deferred (cross-machine fragility caveat documented); Q-8 --mode=symlink is Unix-only at v1,copy-mode is platform-agnostic; Q-9 install-meta.txt gains commit_sha= + version= as always-present lines,empty values explicit not skipped,#Q-G8 resolution recorded in references/installation.md (--rollback unsupported in symlink mode; symlink consumers are always at HEAD by construction; P05 will emit advisory + non-zero exit; P01 ships no --rollback code); manifest-write loop branches on mode_val via case block (NOT inline conditional or compound chain) so AP-009 shape-guard is honoured; codex+cursor uninstall loops upgraded from bare-rel read to tab-split shape that install-claude-code.sh has used since M032 P01,inline awk semver-delta (no separate lib/semver-delta.sh — patch-diff when major+minor match,else 1); CHANGELOG awk pattern restricted to ^## \[[0-9] to skip past ## [Unreleased]; verifier owns fixture upstream creation under mktemp -d with git config commit.gpgsign false guard against operator gpg configs,additive `drift` top-level object does NOT bump _M029_SCHEMA_VERSION (AD-7 stability policy honored — inline comment in renderer captures intent; M029 SC-3 acceptance re-run 26/26 green); commits_behind encoded as JSON string (accommodates both numeric and unknown-fallback shapes without parser brittleness); drift object key set is STABLE across availability states (deviation from sections-side suppression-by-omission convention — downstream consumers need stable shape regardless of helper availability); _rsj_collect_drift_block strips trailing /.orchestrator from _RSJ_ORCH_ROOT to compute consumer project root for the helper invocation; verifier sub-case (c) tests render-side suppression matrix with update_source=none rather than helper-unavailable path (the latter is owned by T03 graceful-degrade tests)"
patterns_established:
  - "user-facing-flag-promoted-from-test-only-alias-without-deprecating-alias (--mode supersedes --asset-mode-override at the surface; alias preserved byte-identically for M032 acceptance scripts); symlink-target-equals-src-abs (link_target=SRC retires the runtime-cache indirection; one-line replacement for the M032/P01 11-line resolution block); install-meta.txt always-present-lines-with-explicit-empty-values (downstream drift helper distinguishes field-absent-pre-M035 from field-present-but-empty),single-row-per-symlink-target manifest shape (symlink mode emits one <tgt>\tmode:symlink line; copy mode keeps per-file expansion); -L/-f conditional uninstall (symlink branch tests -L only; copy branch tests -f only) so a copy-mode uninstall never accidentally removes a symlink and vice versa; verifier-snapshot source-repo invariant (ls /<dir> | head -n 1 pre/post-uninstall) — guards CON-1 against future regressions cheaply without sha-summing the entire source tree; symmetric verifier shape across mode branches with skip-when-ln-s-unavailable for symlink branch only (copy branch always runs),read-only drift helper exits 0 always (FR-15 — consumers branch on data not exit code); SHA-absent fallback emits commits_behind=unknown + one-time stderr advisory; verifier owns its fixture upstream-repo (mktemp -d + git init + N seeded commits + rewrite consumer commit_sha to fixture INITIAL_SHA) for deterministic commits_behind=N assertions,render-side reuse of T03 helper four-line key=value stdout block via grep+sed parse (no jq dependency on helper invocation; jq used only for envelope assembly); JSON envelope key-set stability under suppression — empty string for rendered_line + zero/none defaults for the rest,NOT key omission (downstream-consumer ergonomics); AD-19 phase-suite aggregator filename mirrors P00 shape (m035-p<NN>-phase-suite.sh) for cross-phase grep discovery; verifier scaffold for render-side drift fixtures = T03 upstream-fixture pattern (mktemp -d + git init + N seeded commits + INITIAL_SHA rewrite of consumer install-meta) + M029 milestone-fixture overlay (cp -R from tests/m029-acceptance/fixtures/status-json-executing.fixture/milestones)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M035/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M035/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M035/phases/P01/tasks/T04-SUMMARY.md"
duration: "185m"
verification_result: "pass"
completed_at: "2026-05-08T13:50:21Z"
observability_surfaces:
  - "none"
---

P01 closes the M035 pre-launch dev-ergonomics layer for orchestrator-source
visibility and `--mode=symlink` velocity. With P00's installer hardening as
foundation, P01 promotes the M032/P01 TEST-ONLY `--asset-mode-override`
flag to the user-facing `--mode=copy|symlink` surface across all three
installers, retargets the symlink branch directly at the source repo
(US-1 dogfood-velocity contract), wires drift detection from
`install-meta.txt` into `orchestrator:status`, and ships a 7-verifier
phase-suite that the M035 publishing pipelines (P02–P06) inherit as
preconditions.

Four tasks landed:

- **T01** (mode flag + symlink-to-source + meta extension). Promoted
  `--asset-mode-override` to `--mode=copy|symlink` across the three
  installers; preserved the old flag byte-identically as a TEST-ONLY
  alias so [M032](../../../../milestones/M032/index.md) acceptance scripts keep working. Retargeted
  `scripts/lifecycle/install-asset-mode.sh`'s symlink branch to set
  `link_target="$SRC"` directly — replacing the M032-era 11-line
  runtime-cache resolution block with a one-line assignment that
  delivers the US-1 contract: `git pull` in `$REPO_ROOT` updates every
  consumer immediately. Extended `install-meta.txt` with two new
  always-present fields (`commit_sha=` from `git rev-parse HEAD`,
  `version=` from `CHANGELOG.md` top-line per #Q-9) so T03's drift
  helper has the data shape it consumes. Authored
  `references/installation.md § Symlink-mode caveats` covering #Q-7
  (cross-machine fragility), #Q-8 (Unix-only at v1), and bundle hygiene.
  Updated the Windows fail-closed advisory wording per #Q-G4
  (`"FAIL: symlink mode unsupported on this filesystem -- re-run with
  --mode=copy"`) and synced the M032 acceptance grep accordingly.

- **T02** (mode-aware uninstall). Branched the manifest-write loop in
  all three installers on `mode_val` via `case`: symlink mode emits one
  `<tgt>\tmode:symlink` row per target; copy mode emits per-file rows
  as today. `--uninstall` short-circuit branches symmetrically on
  `mode_tok` — symlink-mode tests `[ -L "$f" ]` then `rm -f`, copy-mode
  tests `[ -f "$f" ]` then `rm -f`, so a copy-mode uninstall never
  accidentally removes a symlink and vice versa. The CON-1 source-repo
  invariant is enforced in the verifier via `ls /<dir> | head -n 1`
  pre/post-uninstall snapshots — cheap, reusable, and catches any
  future regression that would `rm` through the symlink. Added
  `### Rollback-and-symlink-mode-interaction` section recording #Q-G8
  (--rollback unsupported in symlink mode) for P05 plan-phase.

- **T03** (orchestrator-source drift detection). Authored
  `scripts/state/check-orchestrator-drift.sh` — a read-only helper that
  reads `.orchestrator/install-meta.txt` + `.orchestrator/config.yml`
  and emits a four-line `key=value` block (`commits_behind`,
  `update_source`, `upstream_path`, `versions_behind`) on stdout,
  exiting 0 always (FR-15 — consumers branch on data, not exit code).
  SHA-absent fallback per #Q-G5 emits `commits_behind=unknown` plus a
  one-time stderr advisory. Two task-grain verifiers: SC-3 SHA-bearing
  path (fixture upstream owns 14 seeded commits past INITIAL_SHA;
  asserts `commits_behind=14`) and SC-3b pre-M035 fallback path
  (asserts `commits_behind=unknown` + one stderr advisory).
  Verifier-owned fixture upstream pattern (mktemp -d + git init +
  N seeded commits + rewrite consumer commit_sha to INITIAL_SHA) makes
  the assertion deterministic without depending on the live repo HEAD.
  CHANGELOG awk pattern restricted to `^## \[[0-9]` to skip past
  `## [Unreleased]` heading; inline awk semver-delta avoids authoring
  a separate `lib/semver-delta.sh` per the payload's budget-saving
  endorsement.

- **T04** (drift line in status). Wired the drift surface into both
  status render paths: TUI side documented as a render rule in
  `commands/status.md`; JSON side emits a top-level `drift` object
  via two new helpers in `scripts/diagnostics/render-status-json.sh`
  (`_rsj_collect_drift_block` parses the helper's four-line stdout via
  grep+sed; `_rsj_drift_rendered_line` formats the human line). The
  drift `_M029_SCHEMA_VERSION` stays at `"1.0"` per AD-7 stability
  policy — the inline comment in the renderer captures intent — and
  [M029](../../../../milestones/M029/index.md) SC-3 acceptance battery re-runs 26/26 green to confirm. The
  drift object key set is STABLE across availability states (deviation
  from the M029 sections-side suppression-by-omission convention,
  reasoned: downstream consumers need stable shape regardless of
  helper availability). Authored `tools/verify/m035-p01-drift-line-in-status.sh`
  (SC-4 primary path), `tools/verify/m035-p01-drift-line-suppressed.sh`
  (SC-4 three suppression sub-cases), and the AD-19-prefixed P01
  phase-suite aggregator `tools/verify/m035-p01-phase-suite.sh`.

Verification: phase-suite battery `pass=7 fail=0` on all 7 task-grain
verifiers. Lock held throughout; no blockers, budget under at 4 tasks /
~185m duration. The 28 "external modification" warnings reported by
`phase-transition.sh` are the genuine T01–T04 implementation diffs
(installer modifications, references doc additions, new verifiers, new
helpers, T01–T04 SUMMARY.md and PLAN.md files) — not actual external
edits. Roadmap sync: SYNC:OK.

P02 (M035 launch event — npm + homebrew + curl-pipe-bash publishing
pipelines) inherits: an installer trio that takes `--mode=copy|symlink`,
emits 5-line `install-meta.txt` (with `commit_sha=` + `version=`), and
uninstalls correctly under both modes; a read-only drift helper that
already does the work the publish-pipeline first-user UX needs; and a
status-line drift surface that surfaces `Orchestrator drift: N commits /
M versions behind via <source>` to operators the moment a consumer
falls behind a published release.
