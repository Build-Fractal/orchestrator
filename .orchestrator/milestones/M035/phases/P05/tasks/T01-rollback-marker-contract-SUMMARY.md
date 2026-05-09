---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M035"
provides:
  - "rollback-marker-writer (scripts/lifecycle/write-rollback-marker.sh) + Stage-4.4.6 install-script hooks (install-claude-code.sh, install-codex.sh, install-cursor.sh) + D005 decision (rollback-marker schema) + two task-grain verifiers (m035-p05-rollback-marker-shape.sh BATTERY pass=6, m035-p05-rollback-snapshot-presence.sh BATTERY pass=3)"
requires:
  - "P02:installer-hook-precedent (Stage 4.4.5 emit-managed-gitignore pattern) + M035-P01:installed-files.txt schema (rel-path tab mode:copy|symlink) + M035-P01:install-meta.txt schema (commit_sha= + version= fields)"
affects:
  - "P05/T02 (consumes .previous-version + snapshot for --rollback driver),P05/T05 (consumes snapshot for byte-equivalence acceptance test),T03 (signing pipeline orthogonal to T01 surface)"
key_files:
  - "scripts/lifecycle/write-rollback-marker.sh,packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,.orchestrator/DECISIONS.md,tools/verify/m035-p05-rollback-marker-shape.sh,tools/verify/m035-p05-rollback-snapshot-presence.sh"
key_decisions:
  - "D005 (rollback-marker schema five-field key=value sidecar plus snapshot)"
patterns_established:
  - "rollback-state-capture-at-upgrade-time (decouples rollback from source-repo reachability),Stage-4.4.6-installer-hook-position (between install-meta and managed-gitignore mirroring M035-P00-T02 precedent),mode-detection-via-case-statement-counting (bash 3.2 substring matching no associative arrays),verifier-would_content_line-shape (per-field dry-run echo for shape assertions without writes)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T01-rollback-marker-contract-PAYLOAD.md"
duration: "55m"
verification_result: "pass"
completed_at: "2026-05-09T00:50:59Z"
---

## What was built

T01 — Rollback-marker contract — establishes the FR-12 / D005 / #Q-G8 minimum surface that T02's `--rollback` driver consumes. Three artifacts:

1. **`scripts/lifecycle/write-rollback-marker.sh`** — single-script-file writer (~190 lines, AD-19 / CON-2 bash 3.2 + POSIX-sh, no compound chains, no plain subshells). Behavior:
   - Greenfield (no prior `installed-files.txt`) → emits `SKIP: greenfield install — no prior state to preserve`, exit 0, no marker written.
   - Reads `version=` and `commit_sha=` from `install-meta.txt` (M035 P01 #Q-9 schema). Empty values are explicit (preserved as `commit_sha=`).
   - Inspects `installed-files.txt` to derive `prior_install_mode`: `copy` (all `\tmode:copy`), `symlink` (all `\tmode:symlink`), `mixed` (both present), `unknown` (file present but no mode markers — pre-M035 P01 format).
   - Snapshots the prior `installed-files.txt` byte-for-byte to `.orchestrator/.rollback/manifest-<prior-version>.txt`.
   - Writes the five-field marker (`prior_version=`, `prior_commit_sha=`, `prior_manifest_path=`, `prior_install_mode=`, `rolled_at=`) at `.orchestrator/.previous-version`.
   - `--dry-run` emits `would_write=`, `would_snapshot=`, and per-line `would_content_line=field=value` so verifiers can assert field shape without writes.
   - Idempotent: re-invocation overwrites both marker and snapshot in place.

2. **Three installer hooks** — Stage 4.4.6 inserted between Stage 4.4 (`install-meta.txt` write) and Stage 4.4.5 (managed `.gitignore` block) in:
   - `packaging/install/install-claude-code.sh` (after line 544, before line 546 of pre-edit shape)
   - `packaging/install/install-codex.sh`
   - `packaging/install/install-cursor.sh`
   The hook honors the installer's `--dry-run` flag and exits the installer non-zero on writer failure (`exit "$_wrm_rc"`).

3. **D005 entry in `.orchestrator/DECISIONS.md`** — appended as a 7-column-table row matching P02's D001/D002/D003 sibling shape (the parent installer's existing convention; the new heading-shape migration is a separate paper-cut per P02 caveats).

## Patterns established

- **Rollback-state-capture-at-upgrade-time** — snapshot is written BEFORE the new manifest is staged, while the prior `installed-files.txt` is still on disk. Decouples the rollback path from source-repo reachability (works under `update_source: npm` against a published tarball with no local clone).
- **Stage 4.4.6 hook position** — between `install-meta.txt` write and managed `.gitignore` block. Mirror of M035 P00 T02's emit-managed-gitignore precedent: a thin-script invocation surrounded by DRY_RUN gating + non-zero-exit-on-failure pattern.
- **Mode-detection via case-statement counting** — `\tmode:copy` / `\tmode:symlink` substring matching inside a `while IFS= read -r line; do ...; done < file` loop with parallel counters. Bash 3.2 safe; no associative arrays; no compound chains.
- **Verifier `would_content_line=` shape** — for dry-run dispatch where the writer must echo the would-be marker contents so a verifier can assert per-field correctness without writing files.

## Verification

- `tools/verify/m035-p05-rollback-marker-shape.sh` → `BATTERY: pass=6 fail=0`
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` → `BATTERY: pass=3 fail=0`
- `tests/installer-acceptance/m035-collision-exit-status.sh` → `PASS: m035-p00-collision-exit-status (3/3 installers exit non-zero on collision)`
- `tools/verify/m029-p01-status-headline-shape.sh` → `pass=8 fail=0`
- `tools/verify/m029-p01-headline-shape-contract.sh` → `pass=20 fail=0`
- End-to-end installer smoke via `install-claude-code.sh --dry-run`:
  - Greenfield run: `SKIP: greenfield install — no prior state to preserve`
  - Prior-install run (copy-mode fixture): `would_write=...previous-version`, `would_snapshot=...rollback/manifest-0.9.2.txt`, `would_content_line=prior_install_mode=copy`

## Caveats

- The task plan referenced `tools/verify/m029-p01-headline-shape.sh` in the verification list; the actual paths in repo are `m029-p01-status-headline-shape.sh` + `m029-p01-headline-shape-contract.sh`. Both resolved to PASS.
- The "Files To Touch" section in the plan listed many files belonging to T02–T06 (rollback driver, signing artifacts, release-workflow signing, update-skill doc, phase-suite, fixtures). T01 strictly executed against the must-haves enumerated under `## Must-Haves` — the broader list is reserved for sibling tasks.
- D005 was authored as a 7-column-table row (matching P02's D001/D002/D003 shape). The new heading-shape `### Title { #dr-code-NNN }` migration noted in P02 caveats is still pending and out-of-scope for T01.
- The installer hook honors the installer's existing `--dry-run` CLI flag (DRY_RUN variable assigned by argparser at line 81 of install-claude-code.sh), not an env-var-prefix shape — first smoke probe used `DRY_RUN=1 bash installer` which silently drops to non-dry-run; corrected to `--dry-run` flag.

## Out-of-scope-found

- **T02 territory (`scripts/lifecycle/rollback-driver.sh`)** — T01 records `prior_install_mode=symlink|mixed` but does NOT enforce refusal. The #Q-G8 refusal logic is T02's responsibility; T01's contract is purely state-capture.
- **T05 acceptance test (`tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`)** — depends on T02's rollback driver and the snapshot-replay mechanism; T01 ships the snapshot artifact but not the replay.
- **D004 (sigstore-keyless decision)** — listed in the plan's "Files To Touch" but is T03/T05's territory (signature verification + signing pipeline). T01 only authors D005.
