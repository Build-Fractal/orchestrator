---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M032"
provides:
  - "install-claude-code.sh project_assets-driven runtime payload stage (FR-2 + FR-3 + FR-4 + FR-22); pre-M032 golden file-tree shape (tools/verify/fixtures/m032-pre-m032-golden.txt); --asset-mode-override flag (TEST-ONLY P01 surface); m032-p01-install-cc-byte-identical.sh verifier"
requires:
  - "from:M032/P01/T01 what:packaging/bundle/manifest.yml(project_assets schema), scripts/lifecycle/read-project-assets.sh, scripts/lifecycle/install-asset-mode.sh, scripts/lifecycle/install-collision-check.sh; from:disk what:packaging/install/install-claude-code.sh(pre-T02 RUNTIME_DIRS block at lines 415-458)"
affects:
  - "P01/T03"
key_files:
  - "packaging/install/install-claude-code.sh,tools/verify/m032-p01-install-cc-byte-identical.sh,tools/verify/fixtures/m032-pre-m032-golden.txt"
key_decisions:
  - "N/A"
patterns_established:
  - "record-golden-before-migrating (load-bearing ordering invariant); two-pass project_assets tuple loop with printf-b joined target list for collision-check argv; column-1 awk extraction for installed-files.txt back-compat read paths"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P01/tasks/T02-install-claude-code-migration-PAYLOAD.md"
duration: "90m"
verification_result: "pass"
completed_at: "2026-05-04T00:19:42Z"
---

T02 migrated `packaging/install/install-claude-code.sh` from the hardcoded
`RUNTIME_DIRS="scripts templates references commands"` bulk-copy block (FR-2)
to a `project_assets:`-driven loop that:

1. Reads tuples from `scripts/lifecycle/read-project-assets.sh`.
2. Dispatches each tuple through `scripts/lifecycle/install-collision-check.sh`
   (FR-22 dual-oracle hierarchy).
3. Dispatches each tuple through `scripts/lifecycle/install-asset-mode.sh`
   (FR-3 per-mode handler; copy or symlink).
4. Writes `installed-files.txt` with a per-line `\tmode:<copy|symlink>` token
   (FR-4).

## What landed

- **Pre-M032 golden recorded BEFORE the migration touched the installer**
  (the load-bearing T02 ordering invariant). `tools/verify/fixtures/m032-pre-m032-golden.txt`
  captures: commands/=27, scripts/=1149, references/=27, templates/=47, total=1250.
  Recorded by running the pre-T02 installer against `/tmp/m032-t02-pre-golden-fixture`
  in `--dry-run` and counting `would_write=` lines per runtime dir.
- **`packaging/install/install-claude-code.sh` migration (lines 415-458 swap)**:
  the `RUNTIME_DIRS=` literal token is fully removed; the new project-asset stage
  reads tuples in two passes (first pass to collect target list for the
  bootstrapping oracle's "in the project_assets target list" check; second pass
  to dispatch each tuple). Dry-run preserves the existing `would_write=` shape;
  real-run dispatches through `install-asset-mode.sh` and emits
  `staged=$runtime_staged files manifest=...` exactly as before.
- **`--asset-mode-override copy|symlink` flag** added to the flag-parsing loop
  (TEST-ONLY P01 surface; manifest-declarable in P02+). Both `--asset-mode-override copy`
  and `--asset-mode-override=copy` forms parse. Bad values are rejected with
  `FAIL: --asset-mode-override requires copy|symlink` (exit 1). Documented in
  the installer's flag-help block as TEST-ONLY.
- **`installed-files.txt` writer rewritten for FR-4**: every line now carries
  `<rel-path>\tmode:<copy|symlink>`. Verified against a real run: 1250 lines,
  1250 carry the `\tmode:` token, byte-identical across two consecutive writer
  invocations (idempotent).
- **`--uninstall` path updated to read column 1 of installed-files.txt**: the
  previous form `IFS= read -r rel; f="$PROJECT_DIR/$rel"` would now read
  `<rel>\tmode:copy` and fail to resolve. Updated to extract column 1 via
  `awk -F'\t' '{print $1}'`. Honors the install-collision-check.sh FILE
  FORMAT INVARIANT (column 1 is canonical path-of-record).
- **Help-block sed range bumped from `2,32p` to `2,35p`** to include the
  new `--asset-mode-override` doc lines.

## Verifier authored

`tools/verify/m032-p01-install-cc-byte-identical.sh` (9 checks):
1. Installer file exists.
2. `RUNTIME_DIRS=` literal removed (FR-2).
3. `read-project-assets.sh` dispatch present.
4. `install-collision-check.sh` dispatch present (FR-22).
5. `install-asset-mode.sh` dispatch present (FR-3).
6. Golden file exists and is non-empty.
7. Golden references all four runtime dirs.
8. Post-migration `--dry-run` succeeds against a fresh `/tmp/m032-bi-check-$$` fixture.
9. Post-migration per-dir `would_write=` counts equal golden per-dir counts
   (CON-4 byte-identical at mode: copy).

## Verification result

Both verifiers from the T02 plan's Verification block exit 0:
- `bash tools/verify/m032-p01-install-cc-byte-identical.sh` -> pass=9 fail=0.
- `bash tools/verify/m032-p01-installed-files-format.sh`     -> pass=6 fail=0.

Upstream T01 verifiers re-run as a regression check, all still pass:
- `m032-p01-manifest-schema-shape.sh`  -> pass=19 fail=0
- `m032-p01-reader-emits-tuples.sh`    -> pass=11 fail=0
- `m032-p01-mode-handler-symlink.sh`   -> pass=12 fail=0
- `m032-p01-collision-oracle.sh`       -> pass=13 fail=0

Out-of-band sanity checks:
- FR-4: 1250/1250 lines in `installed-files.txt` carry tab-separated
  `mode:<copy|symlink>` after a real-run; second run is byte-identical to
  the first (idempotent writer).
- Flag shape: `--asset-mode-override BOGUS` rejected (rc=1); `--asset-mode-override`
  with no value rejected (rc=1); `=copy` and `--asset-mode-override copy`
  forms both parse (rc=0).
- `--help` output renders cleanly through the bumped sed range and includes
  the new `--asset-mode-override` doc block.

## Constraints honored

- `install-codex.sh` and `install-cursor.sh` were NOT touched (T03's job).
- The dry-run `would_write=` set is unordered-equal pre- and post-T02 per
  dimension (CON-4): commands/=27 == 27, scripts/=1149 == 1149,
  references/=27 == 27, templates/=47 == 47.
- `tools/verify/fixtures/m032-pre-m032-golden.txt` was committed before the
  installer body was touched and will not be regenerated.
- Existing dry-run branching, `staged=` summary line, and exit-code conventions
  are preserved.
- The `--asset-mode-override` flag is documented in the installer header
  (lines 16-25) as TEST-ONLY M032 P01.

## Notes for downstream

- T03 (codex + cursor symmetry) inherits the project-asset stage shape from
  T02. The two-pass tuple loop, the `printf '%b' "$project_assets_targets"`
  trick for the collision-check argv, and the FR-4 manifest writer are
  reusable as-is — T03's job is to swap the same RUNTIME_DIRS block in the
  other two installers and run the parity verifier.
- T04 (M032 P01 acceptance battery) will read
  `tools/verify/fixtures/m032-pre-m032-golden.txt` for SC-1's CON-4
  byte-identical contract verification. The file is committed.
- The `--uninstall` path now correctly handles both pre-T02 (single-column)
  and post-T02 (two-column tab-separated) installed-files.txt formats —
  the column-1 extraction via `awk -F'\t' '{print $1}'` is a no-op when the
  line has no tabs.
