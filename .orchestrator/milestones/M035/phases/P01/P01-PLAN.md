---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M035"
goal: "Dev-ergonomics — `--mode=symlink` install option (FR-1, FR-2) + `orchestrator:status` version-drift datum + line (FR-3, FR-4)"
demo_sentence: "`install-claude-code.sh --mode=symlink` produces a runtime tree whose `<fixture>/scripts` symlink resolves to the orchestrator source repo (SC-1) with reversible uninstall (SC-2); `scripts/state/check-orchestrator-drift.sh` emits `commits_behind=N`/`versions_behind=…` against fixture `install-meta.txt` shapes (SC-3 / SC-3b); the drift line renders inside M029's headline block when drift > 0, suppressed cleanly under `update_source: none` (SC-4)."
risk: "medium"
depends_on: ["P00"]
---

## Plan-Phase-Resolved Open Questions

These four resolve at this plan-phase per AD-7 / spec routing. They land
as design constraints in the task plans below.

- **#Q-7 (symlink-vs-hardlink)**: **symlink only**. Hardlinks survive
  across-machine but break across-filesystem-boundary; symlinks are the
  documented v1 shape. Cross-machine fragility is documented as a known
  caveat in `references/installation.md § Symlink-mode caveats`. T01
  authors this section.

- **#Q-8 (windows-support)**: **defer to M009** (post-launch multi-runtime
  parity audit). P01 codifies `--mode=symlink` as Unix-only at v1; copy
  mode (the default) remains platform-agnostic. The Windows guard is
  already in `install-asset-mode.sh:52-55` (`M032_FORCE_WINDOWS=1` exit 3
  + missing-`ln` exit 3). T01 promotes this guard's stderr message to the
  documented form `"symlink mode unsupported on this filesystem — re-run
  with --mode=copy"` per the discuss-stage `#Q-G4` resolution. No new
  fixture-based "Windows" test surface is added at P01.

- **#Q-9 (install-meta.txt schema extension)**: **two new fields**:
  `commit_sha=<value>` (from `git rev-parse HEAD` inside `REPO_ROOT`,
  empty string when `.git` absent — surfaces the SC-3b
  pre-M035-install fallback path) and `version=<top-line>` (the
  `## [X.Y.Z]` heading from `CHANGELOG.md` — bash 3.2 `head` + `awk`).
  T01 owns the install-time write extension; T03 owns the drift-helper
  read side. The pre-M035 dogfood-project shapes (lakeledger, pbj-central,
  bbt-companion) lack `commit_sha` — T03 detects empty `commit_sha` and
  falls back to version-only diffing, emitting the documented one-time
  stderr advisory.

- **#Q-G8 (FR-12 rollback semantics for symlink-mode)**: **rollback
  unsupported in symlink mode** — symlink-mode consumers are always at
  HEAD. T02 documents this constraint in
  `references/installation.md § Rollback-and-symlink-mode-interaction`
  so P05 plan-phase inherits the contract on disk. No P01 implementation
  work — FR-12 is P05 scope; P01 just records the constraint.

## Must-Haves

### Truths

- The `--mode=symlink|copy` flag is exposed user-facing on all three
  installers and routes to the same internal asset-mode-override
  variable; the M032-era TEST-ONLY `--asset-mode-override` flag remains
  recognised for backward compatibility (FR-1, US-1 acceptance scenario 1).
  - Check: `bash tools/verify/m035-p01-mode-flag.sh`

- After `install-claude-code.sh --mode=symlink` against a fresh fixture,
  `readlink <fixture>/scripts` resolves to the orchestrator source repo
  path (FR-1, US-1 acceptance scenario 1). The symlink target is
  `$REPO_ROOT/<src_rel>`, NOT a managed-runtime-cache subdirectory. This
  is a behaviour change from the M032/P01 implementation of
  `install-asset-mode.sh` symlink mode, motivated by the US-1
  dogfood-velocity contract.
  - Check: `bash tools/verify/m035-p01-symlink-source-target.sh`

- Mode-aware uninstall: against a `--mode=symlink` fixture, uninstall
  removes only the symlinks; the orchestrator source repo's
  `scripts/`, `commands/`, `templates/`, `references/` directories
  remain on disk byte-for-byte. Against a `--mode=copy` fixture,
  uninstall removes the staged copy tree as today (FR-2, US-1
  acceptance scenario 2, CON-1 reversibility-gate).
  - Check: `bash tools/verify/m035-p01-mode-aware-uninstall.sh`

- `scripts/state/check-orchestrator-drift.sh` against a fixture whose
  `install-meta.txt` records a SHA 14 commits behind the configured
  `update_source` git path emits stdout containing exactly one line
  matching `^commits_behind=14$` and one line matching
  `^versions_behind=` plus one line matching `^update_source=`; exit 0
  (FR-3, FR-15, SC-3).
  - Check: `bash tools/verify/m035-p01-drift-detection.sh`

- The same helper against a fixture whose `install-meta.txt` lacks
  `commit_sha=` (the pre-M035 dogfood-install shape) emits
  `commits_behind=unknown` plus the semver-delta `versions_behind=…`
  computed against `CHANGELOG.md` top-line, plus exactly one line of
  documented stderr advisory; exit 0 (#Q-G5 / SC-3b).
  - Check: `bash tools/verify/m035-p01-drift-detection-sha-absent.sh`

- `orchestrator:status` rendered against the SC-3 fixture emits a
  fourth headline line of the form
  `STALE: orchestrator runtime is N commits behind upstream — run
  \`orchestrator:update\`` after the embedded efficiency-footer line.
  Both the TUI render path (`commands/status.md`) and the JSON render
  path (`scripts/diagnostics/render-status-json.sh`) carry the
  drift-related field. The line is byte-stable per the addendum
  documented in `references/status-headline-shape.md § Drift Line
  (M035 P01)` (FR-4, SC-4).
  - Check: `bash tools/verify/m035-p01-drift-line-in-status.sh`

- Toggling `update_source: none` in fixture config suppresses the
  drift line entirely; no other field changes (regression check via
  `diff` against a baseline render). Same suppression behaviour when
  `commits_behind=0` and when the drift check itself is unavailable
  (FR-4, FR-16, SC-4).
  - Check: `bash tools/verify/m035-p01-drift-line-suppressed.sh`

### Artifacts

- `scripts/state/check-orchestrator-drift.sh` (min 80 lines, contains "commits_behind")
- `references/installation.md` (min 400 lines, contains "Symlink-mode caveats")
- `references/status-headline-shape.md` (min 175 lines, contains "Drift Line (M035 P01)")
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (min 4 lines, contains "commit_sha=")
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (min 3 lines, contains "source_root=")
- `tools/verify/m035-p01-phase-suite.sh` (min 30 lines, contains "p01-")

### Key Links

- `packaging/install/install-claude-code.sh` → `scripts/lifecycle/install-asset-mode.sh` (mode dispatch)
- `commands/status.md` → `scripts/state/check-orchestrator-drift.sh` (drift datum)
- `scripts/diagnostics/render-status-json.sh` → `scripts/state/check-orchestrator-drift.sh` (drift field in JSON)
- `references/status-headline-shape.md` → `scripts/state/check-orchestrator-drift.sh` (contract)
- `references/installation.md` → `install-asset-mode.sh` (Symlink-mode caveats reference)

## Tasks

### T01: User-facing `--mode=symlink|copy` flag + symlink-to-source semantics + install-meta.txt schema extension

See `tasks/T01-mode-flag-and-symlink-source-PLAN.md`.

### T02: Mode-aware uninstall + reversibility-gate + #Q-G8 rollback constraint documentation

See `tasks/T02-mode-aware-uninstall-PLAN.md`.

### T03: `scripts/state/check-orchestrator-drift.sh` + fixture install-meta.txt shapes

See `tasks/T03-check-orchestrator-drift-PLAN.md`.

### T04: FR-4 drift line in M029 status headline + status-headline-shape.md addendum

See `tasks/T04-drift-line-in-status-PLAN.md`.

## Task Dependencies

```
T01 ──► T02
   │
   └──► T03 ──► T04
```

T01 lands flag + symlink-to-source + install-meta.txt extension.
T02 (mode-aware uninstall) and T03 (drift helper) both depend on T01
but are independent of each other; either ordering is fine.
T04 depends on T03 (consumes its stdout shape).

## Files Likely Touched

- `packaging/install/install-claude-code.sh` (modify) — `--mode` flag, install-meta.txt fields, mode-aware manifest write + uninstall dispatch
- `packaging/install/install-codex.sh` (modify) — same as above
- `packaging/install/install-cursor.sh` (modify) — same as above
- `scripts/lifecycle/install-asset-mode.sh` (modify) — symlink branch retargeted to `$SRC` directly; advisory stderr message updated
- `scripts/state/check-orchestrator-drift.sh` (create)
- `scripts/diagnostics/render-status-json.sh` (modify) — drift field in JSON render path
- `commands/status.md` (modify) — drift line in TUI render path; consumes `check-orchestrator-drift.sh`
- `references/installation.md` (modify) — § Symlink-mode caveats; § Rollback-and-symlink-mode-interaction
- `references/status-headline-shape.md` (modify) — § Drift Line (M035 P01) addendum
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (create)
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (create)
- `tools/verify/m035-p01-mode-flag.sh` (create)
- `tools/verify/m035-p01-symlink-source-target.sh` (create)
- `tools/verify/m035-p01-mode-aware-uninstall.sh` (create)
- `tools/verify/m035-p01-drift-detection.sh` (create)
- `tools/verify/m035-p01-drift-detection-sha-absent.sh` (create)
- `tools/verify/m035-p01-drift-line-in-status.sh` (create)
- `tools/verify/m035-p01-drift-line-suppressed.sh` (create)
- `tools/verify/m035-p01-phase-suite.sh` (create)
