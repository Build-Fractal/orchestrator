---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M035"
name: "`--rollback` dispatch — `run-update.sh` extension + `commands/update.md` doc + #Q-G8 symlink-mode refusal"
depends_on: ["T01"]
---

## Prerequisites

- **T01 closed** with `scripts/lifecycle/write-rollback-marker.sh` on
  disk and the three installer scripts hooking it. T02 reads the marker
  contract authored by T01.
- **`scripts/lifecycle/run-update.sh`** exists with the pre-M035 interim
  driver shape (git-source-only at lines 1–80+; full file is the
  current upstream-of-T02 surface). T02 extends this driver with a
  `--rollback` flag that branches BEFORE the existing source-resolution
  logic. The existing driver's source-resolution + install-invocation
  flow remains intact for the non-rollback path.
- **`commands/update.md`** exists as the pre-M035 interim skill
  documentation (shipped 2026-05-06 per spec A-5). T02 extends with a
  `## Rollback` section.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the verifier.
- **`.orchestrator/.previous-version` schema** — five fields per T01 D005:
  `prior_version=`, `prior_commit_sha=`, `prior_manifest_path=`,
  `prior_install_mode=`, `rolled_at=`. Read by T02's rollback branch.
- **`.orchestrator/.rollback/manifest-<X>.txt`** schema — verbatim
  snapshot of an `installed-files.txt` (one line per asset, format
  `<relative-path>\tmode:<copy|symlink>`). Read by T02's rollback branch
  to drive the per-asset revert.
- **`scripts/util/settings-merge.sh`** — [M025](../../../../../milestones/M025/index.md)'s manifest replay path.
  T02's rollback REUSES the existing M025 uninstall convention rather
  than reimplementing per-asset cleanup. Specifically, T02 calls
  `settings-merge.sh --uninstall-from-manifest <snapshot-path>` (or the
  equivalent existing entry-point — read the file at execution time to
  confirm the exact subcommand).
- No `--rollback` flag exists in `run-update.sh` at plan-authoring time.

## Description

Extend `commands/update.md` and `scripts/lifecycle/run-update.sh` with
the `--rollback` semantic FR-12 requires. The driver's responsibility:

1. Read `.orchestrator/.previous-version`. If absent, emit
   `no prior version recorded — rollback unavailable` and exit non-zero.
2. Read `prior_install_mode`. If `symlink` or `mixed`, emit the spec-
   amendment-mandated advisory text and exit non-zero (#Q-G8). The
   advisory is verbatim from the spec amendment:
   ```
   rollback not available for symlink-mode installs — symlink-mode
   consumers are always at HEAD; to revert, run `git checkout
   <prior-sha>` in the orchestrator source repo.
   ```
   Substitute `<prior-sha>` with the value of `prior_commit_sha` from
   the marker (or literal `<prior-sha>` if the field is empty).
3. Validate the snapshot file at `prior_manifest_path` exists and is
   readable. If absent, emit `prior manifest snapshot missing at <path>
   — rollback unavailable` and exit non-zero (this is the corrupted-state
   branch).
4. Replay the snapshot: for each line in the snapshot, the asset path
   is the file portion before the `\t`, and `mode:copy` is the only
   mode that can be replayed (per step 2's symlink-mode refusal). For
   each line:
   - Compute the destination path relative to PROJECT_DIR.
   - Source path: a freshly-resolved orchestrator source repo's copy of
     the same relative path AT THE PRIOR VERSION's commit SHA.
   - Source-of-truth resolution: `update_source` from
     `.orchestrator/config.yml` (per FR-13's multi-source dispatch). For
     `update_source: git`, run `git -C <source-repo> checkout
     <prior_commit_sha>`, then `cp` each asset, then restore source-repo
     HEAD. For `update_source: npm`, fetch `npm pack
     @build-fractal/orchestrator@<prior_version>` to a tmpdir and copy
     from the unpacked tarball. (Homebrew + curl-pipe-bash sources land
     in P03/P04 and extend this dispatch identically — for now stub
     them with `SKIP: rollback not yet implemented for source=<value>`.)
5. After all assets replayed, swap `installed-files.txt` for the
   snapshot byte-for-byte. Update `.orchestrator/.previous-version`'s
   `rolled_at=` field to the current ISO 8601 timestamp.
6. Emit one `update_run` JSONL event per FR-13 / FR-15 with
   `op=rollback`, `target_version=<prior_version>`, `result=success`.
7. Exit 0.

The byte-for-byte equivalence (SC-12) hinges on: (a) the snapshot
faithfully captures every asset's relative path; (b) the source repo
checked out at `prior_commit_sha` produces byte-identical asset content
to the original install; (c) any per-install metadata files (per CON-5
exclusion list) are excluded from the byte-equivalence comparison. The
acceptance test (T05) runs the full N → N+1 → rollback cycle against a
copy-mode fixture and asserts byte-equality of the staged tree.

**Out of scope for T02**: the actual implementation of every update_source
branch (only `git` ships in T02; `npm` ships when P06 lands; `homebrew`
similarly). T02 SHIPS the driver with a `case "$update_source" in`
dispatch where `git` is functional and other sources emit
`SKIP: rollback not yet implemented for source=<value>` with a non-zero
exit. This mirrors the byte-equivalence test's "skeleton with
extension-points" pattern from P02 T03.

## Steps

1. **Read `commands/update.md`** in full to understand the current
   skill structure. Identify the section ordering (likely
   `## Description`, `## Usage`, `## Output`, `## Source Resolution`).
   Plan to insert a new `## Rollback` section before the `## Output`
   section.

2. **Read `scripts/lifecycle/run-update.sh`** in full to understand
   the current arg-parse loop and the install-invocation block. The
   rollback branch must hook BEFORE the source-resolution logic
   (lines 44–80+ in the current file).

3. **Extend the arg-parse loop** in `run-update.sh` to recognize
   `--rollback` (no-arg flag). Set `ROLLBACK=1` when present. Add the
   `--rollback` documentation to the existing `usage()` function.

4. **Author the rollback branch** in `run-update.sh`. Insert AFTER arg
   parsing completes and BEFORE the source-resolution section. Shape:

   ```bash
   if [ "$ROLLBACK" = "1" ]; then
     marker="$PROJECT_DIR/.orchestrator/.previous-version"
     if [ ! -f "$marker" ]; then
       echo "FAIL: no prior version recorded — rollback unavailable" >&2
       exit 1
     fi
     # Read fields from marker (one var per field; bash 3.2 safe)
     prior_version=""
     prior_commit_sha=""
     prior_manifest_path=""
     prior_install_mode=""
     while IFS= read -r line; do
       case "$line" in
         prior_version=*)        prior_version="${line#prior_version=}" ;;
         prior_commit_sha=*)     prior_commit_sha="${line#prior_commit_sha=}" ;;
         prior_manifest_path=*)  prior_manifest_path="${line#prior_manifest_path=}" ;;
         prior_install_mode=*)   prior_install_mode="${line#prior_install_mode=}" ;;
       esac
     done < "$marker"

     # #Q-G8 — symlink-mode refusal
     case "$prior_install_mode" in
       symlink|mixed)
         sha_display="${prior_commit_sha:-<prior-sha>}"
         echo "rollback not available for symlink-mode installs — \
   symlink-mode consumers are always at HEAD; to revert, run \
   \`git checkout $sha_display\` in the orchestrator source repo." >&2
         exit 1
         ;;
     esac

     # Snapshot validation
     snapshot_full="$PROJECT_DIR/$prior_manifest_path"
     if [ ! -f "$snapshot_full" ]; then
       echo "FAIL: prior manifest snapshot missing at $snapshot_full \
   — rollback unavailable" >&2
       exit 1
     fi

     # Source dispatch
     update_source="$(grep -E '^update_source:' \
       "$PROJECT_DIR/.orchestrator/config.yml" 2>/dev/null \
       | sed -E 's/^update_source:\s*//' || echo "")"
     if [ -z "$update_source" ]; then
       update_source="git"  # default per FR-13 / #Q-6 detect-by-install
     fi

     case "$update_source" in
       git)
         # ... see step 5 ...
         ;;
       npm|homebrew|curl)
         echo "SKIP: rollback not yet implemented for source=$update_source" >&2
         exit 1
         ;;
       *)
         echo "FAIL: unknown update_source=$update_source" >&2
         exit 1
         ;;
     esac

     # Common post-replay path
     # ... see step 6 ...
   fi
   ```

   **Note on the `case` value join across the heredoc-like quoted block**:
   the `echo "rollback not available..."` line uses bash's literal
   newline-continuation via `\` at end-of-line. Bash 3.2 honors this in
   double-quoted strings. Single-script-file shape is preserved (no
   compound chain, no subshell).

5. **Author the `git`-source rollback body** for the dispatch's `git)` arm:

   ```bash
   git)
     # Resolve source repo (reuse the existing resolution at lines 80+).
     # SOURCE_REPO is already set from the env-var / default cascade
     # above. Confirm it is a git repo with the prior_commit_sha
     # reachable.
     if [ ! -d "$SOURCE_REPO/.git" ]; then
       echo "FAIL: source repo at $SOURCE_REPO is not a git repository" >&2
       exit 1
     fi
     # Validate prior_commit_sha is reachable
     if ! git -C "$SOURCE_REPO" cat-file -e "$prior_commit_sha^{commit}" 2>/dev/null; then
       echo "FAIL: prior commit $prior_commit_sha not reachable in $SOURCE_REPO" >&2
       exit 1
     fi
     # Save current HEAD to restore later
     orig_head="$(git -C "$SOURCE_REPO" rev-parse HEAD)"
     # Checkout prior version (detached HEAD; non-destructive)
     git -C "$SOURCE_REPO" checkout --quiet "$prior_commit_sha"
     # Replay each asset from snapshot
     while IFS= read -r asset_line; do
       # Format: <rel-path>\tmode:<copy|symlink>
       rel="${asset_line%%	*}"  # everything before tab
       # mode is implicitly `copy` since symlink-mode was refused at step 4
       src="$SOURCE_REPO/$rel"
       dst="$PROJECT_DIR/$rel"
       if [ -f "$src" ]; then
         mkdir -p "$(dirname "$dst")"
         cp "$src" "$dst"
       elif [ -d "$src" ]; then
         mkdir -p "$dst"
         cp -R "$src/." "$dst/"
       fi
     done < "$snapshot_full"
     # Restore source-repo HEAD
     git -C "$SOURCE_REPO" checkout --quiet "$orig_head"
     ;;
   ```

6. **Author the post-replay common path**:

   ```bash
   # Swap installed-files.txt for snapshot byte-for-byte
   cp "$snapshot_full" "$PROJECT_DIR/.orchestrator/installed-files.txt"

   # Update marker rolled_at field (replace empty with timestamp)
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   tmp_marker="$marker.tmp"
   sed -E "s/^rolled_at=.*/rolled_at=$ts/" "$marker" > "$tmp_marker"
   mv "$tmp_marker" "$marker"

   # Emit JSONL event (FR-13)
   obs_dir="$PROJECT_DIR/.orchestrator/observability"
   mkdir -p "$obs_dir"
   today="$(date -u +%Y-%m-%d)"
   jsonl="$obs_dir/$today.jsonl"
   printf '{"event":"update_run","op":"rollback","target_version":"%s","source":"%s","result":"success","timestamp":"%s"}\n' \
     "$prior_version" "$update_source" "$ts" >> "$jsonl"

   echo "orchestrator:update --rollback OK -- runtime in $PROJECT_DIR reverted to $prior_version"
   exit 0
   ```

7. **Extend `commands/update.md`** with a new `## Rollback` section.
   Verbatim copy:

   ```markdown
   ## Rollback

   `orchestrator:update --rollback` reverts the orchestrator runtime to
   the prior installed version, restoring the manifest byte-for-byte
   (copy-mode installs only).

   ### Behavior

   1. Reads `.orchestrator/.previous-version` for the prior version's
      metadata.
   2. Reads the snapshotted manifest at
      `.orchestrator/.rollback/manifest-<prior-version>.txt`.
   3. Replays each asset from the source-repo at the prior commit SHA
      (for `update_source: git`).
   4. Updates `installed-files.txt` to the snapshotted version.
   5. Emits one `update_run` JSONL event with `op: rollback`.

   ### Symlink-mode refusal

   Symlink-mode installs (per `--mode=symlink`) cannot be rolled back
   via this skill: the runtime files ARE the source repo at HEAD, so
   "rollback" is a `git checkout <prior-sha>` operation in the
   orchestrator source repo, not a copy-revert in the consumer project.
   `--rollback` against a symlink-mode install exits non-zero with the
   exact advisory:

   ```
   rollback not available for symlink-mode installs — symlink-mode
   consumers are always at HEAD; to revert, run `git checkout
   <prior-sha>` in the orchestrator source repo.
   ```

   ### Missing-marker behavior

   `--rollback` against a project with no `.orchestrator/.previous-version`
   marker (i.e. no prior install on record) exits non-zero with `no
   prior version recorded — rollback unavailable`. This includes greenfield
   first installs.

   ### Unsupported source dispatches

   `update_source: npm` and `update_source: homebrew` rollback dispatches
   are stubbed in M035 P05 with `SKIP: rollback not yet implemented for
   source=<value>` and exit non-zero. Full implementation lands when
   the corresponding distribution channels close (P03 / P04 / P06).
   ```

8. **Author the verifier** `tools/verify/m035-p05-rollback-driver-shape.sh`.
   ~80 lines. Stages a tmp fixture, sets up four scenarios, and asserts
   each:

   - **Scenario A — missing marker**: tmp fixture with no
     `.previous-version`. Run `bash run-update.sh --rollback --project-dir
     <fixture>`. Assert exit 1, stderr contains
     `no prior version recorded`.
   - **Scenario B — symlink-mode refusal**: stage `.previous-version`
     with `prior_install_mode=symlink`, `prior_commit_sha=abcd1234`.
     Run `--rollback`. Assert exit 1, stderr contains
     `rollback not available for symlink-mode installs` AND
     `git checkout abcd1234`.
   - **Scenario C — mixed-mode refusal**: same with
     `prior_install_mode=mixed`. Assert same advisory shape.
   - **Scenario D — missing snapshot**: stage `.previous-version` with
     `prior_install_mode=copy` and `prior_manifest_path=.orchestrator/.rollback/manifest-bogus.txt`,
     but DON'T create the snapshot file. Run `--rollback`. Assert exit 1,
     stderr contains `prior manifest snapshot missing`.

   T02 verifier does NOT exercise the actual git-checkout / cp loop —
   that is T05's acceptance test (`m035-p05-rollback-byte-equivalence.sh`),
   which sets up a real source repo and a real install. T02 verifier
   covers only the four refusal/error branches that have no source-repo
   dependency.

   Emit `BATTERY: pass=4 fail=0` summary.

9. **Author the verifier** `tools/verify/m035-p05-update-skill-doc-shape.sh`.
   ~30 lines. Asserts `commands/update.md` contains:
   - The literal `## Rollback` heading.
   - The verbatim symlink-mode advisory text (full pattern match,
     newline-flexible).
   - `.orchestrator/.previous-version` reference.
   - `.orchestrator/.rollback/` reference.
   - `update_source: npm` and `update_source: homebrew` SKIP statement.

   Emit `BATTERY: pass=N fail=0` summary.

## Must-Haves

- `scripts/lifecycle/run-update.sh` modified — contains `--rollback`,
  `prior_install_mode`, `symlink-mode`, `git checkout`, `prior_manifest_path`.
- `commands/update.md` modified — contains `## Rollback`,
  `.previous-version`, the verbatim symlink advisory.
- `tools/verify/m035-p05-rollback-driver-shape.sh` exists, emits
  `BATTERY: pass=N fail=0`.
- `tools/verify/m035-p05-update-skill-doc-shape.sh` exists, emits
  `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p05-rollback-driver-shape.sh
```

```bash
bash tools/verify/m035-p05-update-skill-doc-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/write-rollback-marker.sh` (from T01)
  - Key API: invoked at install-time by all three installers; writes
    `.previous-version` and snapshots `installed-files.txt`. T02 does
    NOT invoke this script directly — T02 reads the artifacts the
    writer produces.
  - Key types: marker file with five fields, snapshot file as a
    verbatim copy of `installed-files.txt`.
- `.orchestrator/.previous-version` (T01 D005 schema)
  - Key fields read by T02: `prior_version`, `prior_commit_sha`,
    `prior_manifest_path`, `prior_install_mode`.
- `.orchestrator/.rollback/manifest-<X>.txt` (T01 snapshot)
  - Key shape: one line per asset, `<relative-path>\tmode:<copy|symlink>`.

### From Disk (Pre-existing)

- `scripts/lifecycle/run-update.sh` — pre-M035 interim driver (lines 1–80+
  are the `--rollback` insertion zone in the arg-parse loop and the
  branch insertion zone immediately after).
- `commands/update.md` — pre-M035 interim skill doc; T02 inserts a new
  `## Rollback` section.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`,
  `RESULT_OK`, `RESULT_FAIL`. Used by both verifiers.
- `.orchestrator/observability/<date>.jsonl` — [M027](../../../../../milestones/M027/index.md) surface; T02 appends
  one `update_run` event per rollback invocation. Pre-existing M027
  consumer convention; T02 does not introduce new schema (per FR-15
  / FR-16).

## Constraints

- **AD-19 single-script-file shape** — verifiers and the rollback
  branch use single-script invocations. The `case` arms inside the
  rollback branch in `run-update.sh` use intermediate variables
  rather than `$(... | ...)` compound chains.
- **Bash 3.2 + POSIX-sh** — CON-2. The `while IFS= read -r line; do
  ...; done < "$file"` pattern is bash 3.2 safe. The `case
  "${line#prefix=}"` pattern is POSIX-sh.
- **#Q-G8 binding** — symlink-mode and mixed-mode refusal exits
  non-zero with the verbatim advisory. The wording matches the spec
  amendment exactly; T05 acceptance test pattern-matches the same
  verbatim string.
- **CON-7 (M025 reversibility-gate)** — T02's rollback DOES modify
  `installed-files.txt` (replaces with snapshot). This is the
  intended behavior of rollback — restoring the prior install's
  manifest. M025's uninstall path can subsequently process the
  restored manifest correctly because the snapshot carries the
  same `mode:` schema M025 already understands.
- **FR-13 / FR-16 (M027 suppression honored)** — JSONL emission goes
  to `.orchestrator/observability/<date>.jsonl` per M027 convention.
  No new suppression knob.
- **No background auto-update (CON-4)** — `--rollback` is invoked
  explicitly by the operator; never automatically.
- **Plan-Time Discipline Rule 1 (Prerequisite-existence)** — `[ -f
  scripts/lifecycle/run-update.sh ]` and `[ -f commands/update.md ]`
  pass at plan-authoring time.

## Expected Output

Stdout from `bash tools/verify/m035-p05-rollback-driver-shape.sh`:

```
PASS: missing-marker emits documented error and exits non-zero
PASS: symlink-mode refusal emits verbatim advisory
PASS: mixed-mode refusal emits verbatim advisory
PASS: missing-snapshot emits documented error and exits non-zero
BATTERY: pass=4 fail=0
```

Stdout from `bash tools/verify/m035-p05-update-skill-doc-shape.sh`:

```
PASS: ## Rollback heading present
PASS: verbatim symlink-mode advisory present
PASS: .orchestrator/.previous-version reference present
PASS: .orchestrator/.rollback/ reference present
PASS: SKIP statement for npm/homebrew rollback present
BATTERY: pass=5 fail=0
```

Stdout from a successful copy-mode rollback in T05 (informational, not
verified at T02 time):

```
orchestrator:update --rollback OK -- runtime in /path/to/project reverted to 0.9.2
```
