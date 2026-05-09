---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M035"
name: "Rollback-marker contract — schema + writer + install-script integration (FR-12 minimum surface, #Q-G8 binding)"
depends_on: []
---

## Prerequisites

- **`.orchestrator/installed-files.txt`** exists in any consumer fixture
  used to test this task. Schema is `<rel-path>\tmode:<copy|symlink>`
  per FR-1 / FR-2 (M035 P01). T01 reads this file's full contents at
  upgrade time and snapshots it byte-for-byte.
- **`.orchestrator/install-meta.txt`** exists in the same fixture. Schema
  carries `commit_sha=` and `version=` lines (per M035 P01 T01 / #Q-9
  amendment landed at commit 8bcba64). T01 reads these two fields to
  populate `prior_commit_sha=` and `prior_version=` in the marker file.
- **`scripts/lib/errors.sh`** exists and exports `emit_result()` for
  PASS/FAIL line emission. T01 verifier sources this for consistent
  output shape.
- **`packaging/install/install-claude-code.sh`** exists with the M035 P01
  Stage 4.4 install-meta.txt write block at lines 511–544. T01 hooks
  the rollback-marker write IMMEDIATELY AFTER the install-meta write
  block but BEFORE the manifest write (Stage 4.5+). At the moment of
  the hook, the *prior* `installed-files.txt` is still on disk
  unmodified — that is the file T01 snapshots.
- **`packaging/install/install-codex.sh`** and **`install-cursor.sh`**
  exist with parallel structure to install-claude-code.sh. T01 hooks
  the same writer at the parallel position in each.
- **`scripts/lifecycle/run-update.sh`** exists; T01 does not modify it
  (T02 does). Reads at planning time only to confirm the driver invokes
  `install-claude-code.sh --force` to do the upgrade — this is the
  invocation point at which the install-side hook fires.
- No `scripts/lifecycle/write-rollback-marker.sh` exists at plan-authoring
  time (Plan-Time Discipline Rule 6 — path-collision check confirmed
  absent).
- No `.orchestrator/.previous-version` is on disk in any consumer project
  (it is by design a per-install sidecar; first run of a post-T01
  installer creates it).
- No `.orchestrator/.rollback/` dir exists in any consumer project.

## Description

Author the rollback-marker contract that FR-12 requires. The contract has
three surfaces:

1. **Schema** of `.orchestrator/.previous-version` — five fields capturing
   prior version metadata (D005 binding).
2. **Snapshot** of the prior `installed-files.txt` at `.orchestrator/.rollback/manifest-<prior-version>.txt`
   — this is the load-bearing artifact that T02's `--rollback` driver
   replays at restore time. Snapshotting at upgrade-time (rather than
   reconstructing at rollback-time from git history) is constitutionally
   required because the rollback path must succeed even when the source
   repo is unreachable (e.g. `update_source: npm` upgrades against a
   published tarball with no local clone).
3. **Writer** as a single-script-file `scripts/lifecycle/write-rollback-marker.sh`
   invoked from each of the three installers (claude-code / codex /
   cursor) at a deterministic point in the install pipeline.

The writer is **idempotent**: re-invocation overwrites both the marker
and the snapshot in place. First-install (greenfield, no prior install
on disk) is a no-op — the marker is not written because there is no
prior state to preserve. The writer detects greenfield via the absence
of an existing `installed-files.txt` at invocation time.

Symlink-mode handling: when the prior install is symlink-mode (every
line in the prior `installed-files.txt` carries `\tmode:symlink`), the
writer still snapshots the manifest and writes the marker with
`prior_install_mode=symlink`. T02's `--rollback` driver consults this
field to refuse the rollback per #Q-G8 — the marker exists for
diagnostic completeness but is not actionable. Mixed-mode prior installs
(some entries `mode:copy`, some `mode:symlink`) are recorded as
`prior_install_mode=mixed`; T02 also refuses these per the spec
amendment's symlink-mode-anywhere-blocks-rollback semantics (the more
restrictive interpretation; reasoning: any symlink in the runtime tree
makes byte-equivalent revert undefined).

## Steps

1. **Author `scripts/lifecycle/write-rollback-marker.sh`** — single-script-file
   shape, bash 3.2 + POSIX-sh, ~80–120 lines. The driver contract:

   **Invocation**:
   ```
   bash scripts/lifecycle/write-rollback-marker.sh \
     --project-dir <PATH> \
     [--source-version <X.Y.Z>] \
     [--source-commit-sha <SHA>] \
     [--dry-run]
   ```

   **Behavior** (in order):
   1. Resolve `PROJECT_DIR` (required), abort with FAIL on missing.
   2. Greenfield check: if `<PROJECT_DIR>/.orchestrator/installed-files.txt`
      does NOT exist, emit `SKIP: greenfield install — no prior state to
      preserve` to stdout, exit 0. (This is the no-op branch.)
   3. Read prior version from `<PROJECT_DIR>/.orchestrator/install-meta.txt`
      `version=` line. If absent or empty, set to `unknown`.
   4. Read prior commit SHA from the same file's `commit_sha=` line. If
      absent or empty, set to empty (explicit empty).
   5. Read prior install mode by inspecting `installed-files.txt`:
      - All lines `\tmode:copy` → `copy`.
      - All lines `\tmode:symlink` → `symlink`.
      - Mixed → `mixed`.
      - File present but malformed (no mode markers, e.g. pre-M035 P01
        format) → `unknown`.
   6. Derive `prior_manifest_path=.orchestrator/.rollback/manifest-<prior_version>.txt`
      using the version from step 3. (When step 3 returned `unknown`,
      use literal string `unknown` in the path.)
   7. Snapshot: copy `installed-files.txt` byte-for-byte to the path
      derived in step 6. Create the `.orchestrator/.rollback/` directory
      if absent.
   8. Write the marker file at `<PROJECT_DIR>/.orchestrator/.previous-version`
      with the verbatim shape:
      ```
      prior_version=<from step 3>
      prior_commit_sha=<from step 4>
      prior_manifest_path=<from step 6>
      prior_install_mode=<from step 5>
      rolled_at=
      ```
      (`rolled_at=` is empty until T02's rollback runs.)
   9. Emit `wrote=<PROJECT_DIR>/.orchestrator/.previous-version` to stdout.
   10. Emit `snapshotted=<PROJECT_DIR>/<prior_manifest_path>` to stdout.
   11. Exit 0.

   **Dry-run** (`--dry-run`): emit `would_write=` and `would_snapshot=`
   lines instead of writing. Useful for the install-script integration
   (the install-script's `DRY_RUN=1` path) and for T05 acceptance tests.

   **Exit codes**:
   - `0` success or skip-greenfield
   - `1` PROJECT_DIR validation failed; or installed-files.txt unreadable
   - `2` invalid arguments

   The script MUST honor the AD-19 single-script-file shape — no
   `$(... | ...)`, no plain subshells, no compound chains. Use
   intermediate variables and `if` blocks for any compound logic.
   Reading lines from `installed-files.txt` uses a `while IFS= read -r
   line; do ...; done < "$file"` form (single-input redirect, no
   process substitution).

2. **Hook into `packaging/install/install-claude-code.sh`** — add the
   following block IMMEDIATELY AFTER the existing Stage 4.4 (install-meta.txt
   write, currently at lines 511–544) and IMMEDIATELY BEFORE Stage 4.4.5
   (managed .gitignore, currently lines 546–562):

   ```bash
   # --- 4.4.6 Rollback marker (M035 P05 T01, FR-12 / D005) ---
   # Snapshots the prior install's manifest and writes the
   # .orchestrator/.previous-version marker BEFORE the new manifest is
   # staged at Stage 4.5. Greenfield installs (no prior installed-files.txt)
   # are a no-op via the writer's internal greenfield check.
   #
   # The writer is idempotent: re-installs at the same version overwrite
   # both the marker and the snapshot in place.
   if [ "$DRY_RUN" = "1" ]; then
     bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
       --project-dir "$PROJECT_DIR" --dry-run
     _wrm_rc=$?
   else
     bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
       --project-dir "$PROJECT_DIR"
     _wrm_rc=$?
   fi
   if [ "$_wrm_rc" -ne 0 ]; then
     echo "FAIL: write-rollback-marker.sh exited $_wrm_rc" >&2
     exit "$_wrm_rc"
   fi
   ```

   The `--uninstall` and `--repair` paths short-circuit before this stage
   per the existing convention (M035 P00 T02 emit-managed-gitignore
   precedent at lines 552–557). No additional gating needed.

3. **Hook into `packaging/install/install-codex.sh`** — locate the
   parallel position (immediately after install-meta.txt write,
   immediately before managed-gitignore call). Insert the same block
   verbatim from step 2.

4. **Hook into `packaging/install/install-cursor.sh`** — same as step 3.

5. **Append D005 to `.orchestrator/DECISIONS.md`** — author the row using
   the existing 7-column-table convention (NOT the new heading-shape;
   T01 follows the parent installer's existing convention. The heading-shape
   migration is a separate paper-cut per P02 caveats). Append:

   ```
   | D005 | M035/P05 | rollback-marker schema | `.orchestrator/.previous-version` is a structured `key=value` sidecar with five fields (`prior_version`, `prior_commit_sha`, `prior_manifest_path`, `prior_install_mode`, `rolled_at`); the prior `installed-files.txt` is snapshotted to `.orchestrator/.rollback/manifest-<prior-version>.txt` for replay. | snapshot-at-upgrade-time decouples rollback from source-repo reachability (works under `update_source: npm` with no local clone). | bound by FR-12 / SC-12 / #Q-G8 | 2026-05-08 |
   ```

   (Adjust the column shape to match the existing DECISIONS.md table
   header at append time — read the file first to confirm column count.)

6. **Author the verifier** `tools/verify/m035-p05-rollback-marker-shape.sh`.
   Single-script-file shape, AD-19, ~50 lines. Sources `scripts/lib/errors.sh`
   for `emit_result`. Stages a temp fixture under `/tmp/m035-p05-t01-marker-fixture-$$/`
   (mktemp), runs `write-rollback-marker.sh --dry-run` against three
   scenarios:

   1. **Greenfield**: empty `<fixture>/.orchestrator/`. Assert stdout
      contains `SKIP: greenfield`, exit 0, no `.previous-version` written.
   2. **Copy-mode prior**: `<fixture>/.orchestrator/installed-files.txt`
      with two `\tmode:copy` lines + `<fixture>/.orchestrator/install-meta.txt`
      with `version=0.9.2` and `commit_sha=abc123`. Assert stdout contains
      `would_write=`, the would-be marker content (in --dry-run echo the
      content as `would_content_line=...` lines for verifiability) shows
      `prior_install_mode=copy`, `prior_version=0.9.2`,
      `prior_commit_sha=abc123`, `prior_manifest_path=.orchestrator/.rollback/manifest-0.9.2.txt`.
   3. **Symlink-mode prior**: same fixture but with `\tmode:symlink` lines.
      Assert `prior_install_mode=symlink`.

   Then run the writer in non-dry-run mode against scenario 2's fixture
   and assert:
   - `<fixture>/.orchestrator/.previous-version` exists with all five
     fields.
   - `<fixture>/.orchestrator/.rollback/manifest-0.9.2.txt` exists and
     is byte-identical to the prior `installed-files.txt`.

   Emit `BATTERY: pass=N fail=0` summary. Cleanup fixture on exit.

7. **Author the verifier** `tools/verify/m035-p05-rollback-snapshot-presence.sh`.
   Lighter-weight verifier (~30 lines): runs the writer against a
   minimal copy-mode fixture and asserts the snapshot file exists with
   non-zero size and matches a SHA-256 hash of the prior
   `installed-files.txt`. Three assertions; emit `BATTERY: pass=3 fail=0`.

## Must-Haves

- `scripts/lifecycle/write-rollback-marker.sh` exists, executable,
  ~80+ lines, contains `prior_version=`, `prior_install_mode=`,
  `prior_manifest_path=`, `--dry-run`, greenfield check.
- `packaging/install/install-claude-code.sh` modified — contains the
  literal token `write-rollback-marker.sh` invocation block.
- `packaging/install/install-codex.sh` modified — same.
- `packaging/install/install-cursor.sh` modified — same.
- `.orchestrator/DECISIONS.md` modified — contains `D005` row referencing
  M035/P05 + `.previous-version`.
- `tools/verify/m035-p05-rollback-marker-shape.sh` exists, runs against a
  staged fixture, emits `BATTERY: pass=N fail=0`.
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` exists, emits
  `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p05-rollback-marker-shape.sh
```

```bash
bash tools/verify/m035-p05-rollback-snapshot-presence.sh
```

```bash
bash tests/installer-acceptance/m035-collision-exit-status.sh
```

```bash
bash tools/verify/m029-p01-status-headline-shape.sh
```

```bash
bash tools/verify/m029-p01-headline-shape-contract.sh
```

## Inputs

### From Previous Tasks

None — T01 is a leaf task within P05 with no upstream P05 dependencies.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` (lines 511–562 are the
  insertion zone) — Stage 4.4 install-meta.txt write at lines 511–544;
  Stage 4.4.5 managed-gitignore at lines 546–562. T01 inserts a new
  Stage 4.4.6 between them.
- `packaging/install/install-codex.sh` — parallel structure; locate the
  install-meta.txt write block via `grep -n install-meta.txt` and the
  managed-gitignore block via `grep -n emit-managed-gitignore`.
- `packaging/install/install-cursor.sh` — same.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`,
  `RESULT_OK`, `RESULT_FAIL`. Used by every verifier.
- `scripts/util/run-probe.sh` — staged-throwaway-probe wrapper. T01
  verifier does NOT use this (verifiers are repo-resident; AD-19 says
  invoke `bash <path>` directly).
- `.orchestrator/installed-files.txt` schema (M035 P01 / FR-1) — flat
  list, one entry per line, format `<relative-path>\tmode:<copy|symlink>`.
  Read by step 1.5 of the writer to determine `prior_install_mode`.
- `.orchestrator/install-meta.txt` schema — five fields: `source_root=`,
  `runtime=`, `installed_at=`, `commit_sha=`, `version=`. Read by step 3
  + step 4 of the writer.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p05-*.sh` or `bash scripts/lifecycle/write-rollback-marker.sh`.
  No inline compound chains; no `$(... | ...)`; no plain subshells.
- **Bash 3.2 + POSIX-sh in the writer and the install-script hooks** —
  CON-2. The writer must run on macOS bash 3.2 unmodified.
- **CON-7 (M025 reversibility-gate preserved)** — T01 reads
  `installed-files.txt` but does NOT modify it. The writer's
  responsibility is purely additive: snapshot + marker. The new
  install's manifest write at Stage 4.5 (existing M025 behavior)
  proceeds unchanged.
- **#Q-G8 binding** — `prior_install_mode=symlink` and `mixed` are
  written but T01 does NOT enforce the rollback refusal. Refusal is
  T02's job. T01's contract: capture enough state for T02 to make the
  decision.
- **Idempotency** — re-invocation overwrites the marker and the
  snapshot in place. Re-running the writer at the same version is
  a no-op functionally (snapshot stays byte-identical).
- **Greenfield no-op** — first install on a project with no prior
  `installed-files.txt` MUST NOT write the marker; the writer's
  greenfield-check branch handles this.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la` performed
  against every `create` path. All absent at plan-authoring time. New
  files all carry `m035-p05-` slug per the milestone-prefix
  convention.

## Expected Output

Stdout from `bash tools/verify/m035-p05-rollback-marker-shape.sh`:

```
PASS: greenfield no-op
PASS: copy-mode prior writes correct marker
PASS: symlink-mode prior writes correct marker (mode=symlink)
PASS: snapshot is byte-identical to source manifest
PASS: marker file contains all five required fields
PASS: --dry-run emits would_write= and would_snapshot=
BATTERY: pass=6 fail=0
```

Stdout from `bash tools/verify/m035-p05-rollback-snapshot-presence.sh`:

```
PASS: snapshot file written
PASS: snapshot file is non-empty
PASS: snapshot SHA-256 matches source installed-files.txt SHA-256
BATTERY: pass=3 fail=0
```

Stdout from a successful `bash scripts/lifecycle/write-rollback-marker.sh
--project-dir <fixture>` against a copy-mode fixture:

```
wrote=<fixture>/.orchestrator/.previous-version
snapshotted=<fixture>/.orchestrator/.rollback/manifest-0.9.2.txt
```
