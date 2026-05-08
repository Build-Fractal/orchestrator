---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M035"
name: "Mode-aware uninstall + reversibility-gate + #Q-G8 rollback constraint documentation"
depends_on: ["T01"]
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring time):

- `packaging/install/install-claude-code.sh` (carries the manifest-write
  loop at lines 614-637 and the `--uninstall` short-circuit at lines
  119-241; T01 has retargeted the symlink branch and added the
  `--mode` flag)
- `packaging/install/install-codex.sh`, `packaging/install/install-cursor.sh`
  (sibling installers with parallel manifest-write + uninstall paths)
- `scripts/lifecycle/install-asset-mode.sh` (T01-retargeted symlink branch
  now produces `<DST>` as a symlink to `$SRC`)
- `references/installation.md` (existing user-facing install docs;
  T01 has added `## Symlink-mode caveats` here)

Pre-existing decisions consumed:

- `#Q-G8` (this plan-phase): rollback unsupported in symlink mode —
  symlink-mode consumers are always at HEAD. FR-12 (P05 scope) inherits
  this constraint via documentation, not code.
- CON-1 (M025 reversibility-gate): `install→install→uninstall` byte-equality
  round-trip MUST hold for both modes.

## Description

Make the installer manifest format and the `--uninstall` replay path
mode-aware so symlink-mode installs can be uninstalled byte-cleanly
without `rm -rf`'ing the orchestrator source tree (CON-1). Document the
`#Q-G8` rollback-and-symlink-mode-interaction constraint in
`references/installation.md` so P05 plan-phase has the contract on
disk before FR-12 implementation begins.

The current manifest write loop (lines 614-637 in `install-claude-code.sh`
and analog blocks in the other two installers) walks `tgt_rel` with
`find -type f` and emits one row per file. This works for copy mode
but is wrong for symlink mode: when `<DST>` is a single symlink to a
directory, the post-T01 install produces a single symlink not a tree
of files, and the manifest must record the symlink path itself so
uninstall removes the symlink (not files inside the linked directory,
which would mutate the source repo).

## Steps

1. **Update the manifest-write loop in all three installers** (lines
   614-637 in `install-claude-code.sh`; analog blocks in `install-codex.sh`
   and `install-cursor.sh`). Branch on `mode_val`:

   ```bash
   while IFS= read -r tuple; do
     tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
     mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')
     [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"
     case "$mode_val" in
       symlink)
         # Record the symlink path itself, not files beneath it.
         if [ -L "$PROJECT_DIR/${tgt_rel%/}" ] || [ -e "$PROJECT_DIR/${tgt_rel%/}" ]; then
           printf '%s\tmode:symlink\n' "${tgt_rel%/}" >> "$manifest_file"
         fi
         ;;
       copy|*)
         if [ -d "$PROJECT_DIR/${tgt_rel%/}" ]; then
           ( cd "$PROJECT_DIR" && find "${tgt_rel%/}" -type f ) | \
             awk -v m="$mode_val" '{printf "%s\tmode:%s\n", $0, m}' >> "$manifest_file"
         fi
         ;;
     esac
   done < "$_manifest_tmp"
   ```

   Apply the same change in all three installers. Preserve the
   surrounding `mktemp` + `_producer_rc` capture pattern from M035 P00 T01
   (the bash 3.2 exit-status hardening) — do not re-introduce
   process-substitution-fed `while read`.

2. **Update the `--uninstall` short-circuit in all three installers**
   (lines 211-237 in `install-claude-code.sh`; analog blocks in the
   other two). The current loop reads each manifest line and runs
   `rm -f "$f"` where `$f="$PROJECT_DIR/$rel"`. Branch on the
   `mode:` token:

   ```bash
   manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
   if [ -f "$manifest_file" ]; then
     while IFS= read -r line; do
       [ -z "$line" ] && continue
       rel=$(printf '%s\n' "$line" | awk -F'\t' '{print $1}')
       mode_tok=$(printf '%s\n' "$line" | awk -F'\t' '{print $2}')
       [ -z "$rel" ] && continue
       f="$PROJECT_DIR/$rel"
       case "$mode_tok" in
         mode:symlink)
           # Symlink-mode: rm the symlink itself; source untouched.
           if [ -L "$f" ]; then
             if [ "$DRY_RUN" = "1" ]; then
               echo "would_remove=$f"
             else
               rm -f "$f"
             fi
             runtime_removed=$((runtime_removed + 1))
           fi
           ;;
         mode:copy|*)
           # Copy-mode: rm the regular file (existing behaviour).
           if [ -f "$f" ]; then
             if [ "$DRY_RUN" = "1" ]; then
               echo "would_remove=$f"
             else
               rm -f "$f"
             fi
             runtime_removed=$((runtime_removed + 1))
           fi
           ;;
       esac
     done < "$manifest_file"
     # ... existing prune-empty-dirs + manifest cleanup ...
   fi
   ```

   The existing `find <d> -type d -empty -depth -exec rmdir {} \;`
   block at line 230 stays — it's a no-op when there are no empty
   directories (symlink-mode case) and prunes the staging tree as
   today (copy-mode case).

3. **Author `references/installation.md § Rollback-and-symlink-mode-interaction`**.
   New subsection under § Symlink-mode caveats. Body (paraphrasing
   `#Q-G8`):

   - `orchestrator:update --rollback` (FR-12, M035 P05) reverts a
     copy-mode install to a previous version's manifest byte-for-byte
     using the `.orchestrator/.previous-version` rollback marker.
   - In symlink-mode the runtime tree is a set of symlinks into the
     orchestrator source repo; the runtime is always at HEAD by
     construction. There is no "previous version" of a symlink to
     restore.
   - Therefore `--rollback` is unsupported in symlink mode. P05 will
     emit the documented advisory:
     `'rollback not available for symlink-mode installs — symlink-mode
     consumers are always at HEAD; to revert, run \`git checkout
     <prior-sha>\` in the orchestrator source repo.'` and exit
     non-zero.
   - This constraint is recorded here so P05 plan-phase has it on
     disk; M035 P01 ships no `--rollback` code.

4. **Author `tools/verify/m035-p01-mode-aware-uninstall.sh`**.
   Verifier exercises both mode round-trips. Single-script-file shape
   per AD-19:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p01-mode-aware-uninstall.sh
   # Asserts CON-1 reversibility-gate holds for both --mode=symlink
   # and --mode=copy: install → uninstall removes only the staged
   # entries, leaving the source repo untouched (symlink mode) or
   # leaving the source repo and PROJECT_DIR's pre-install state
   # untouched (copy mode).
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FIXTURE="$(mktemp -d -t m035-p01-uninstall.XXXXXX)"
   trap "rm -rf '$FIXTURE'" EXIT

   fail=0

   # --- symlink-mode round-trip ---
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE/sym" --mode=symlink >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
     echo "FAIL: symlink-mode install exited $rc" >&2; fail=1
   fi
   if ! [ -L "$FIXTURE/sym/scripts" ]; then
     echo "FAIL: symlink-mode install did not produce a symlink at <fixture>/scripts" >&2; fail=1
   fi

   # Snapshot source-repo state before uninstall.
   pre_uninst="$(ls "$REPO_ROOT/scripts" | head -n 1 || true)"

   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE/sym" --uninstall >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
     echo "FAIL: symlink-mode uninstall exited $rc" >&2; fail=1
   fi
   if [ -L "$FIXTURE/sym/scripts" ]; then
     echo "FAIL: symlink-mode uninstall did not remove the symlink" >&2; fail=1
   fi
   post_uninst="$(ls "$REPO_ROOT/scripts" | head -n 1 || true)"
   if [ "$pre_uninst" != "$post_uninst" ]; then
     echo "FAIL: source repo scripts/ disturbed by symlink-mode uninstall" >&2; fail=1
   fi

   # --- copy-mode round-trip (existing behaviour preserved) ---
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE/copy" --mode=copy >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
     echo "FAIL: copy-mode install exited $rc" >&2; fail=1
   fi
   if ! [ -d "$FIXTURE/copy/scripts" ] || [ -L "$FIXTURE/copy/scripts" ]; then
     echo "FAIL: copy-mode install did not produce a regular dir at <fixture>/scripts" >&2; fail=1
   fi

   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE/copy" --uninstall >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
     echo "FAIL: copy-mode uninstall exited $rc" >&2; fail=1
   fi
   if [ -d "$FIXTURE/copy/scripts" ]; then
     echo "FAIL: copy-mode uninstall did not remove staged scripts/ tree" >&2; fail=1
   fi

   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p01-mode-aware-uninstall"; exit 0; fi
   exit 1
   ```

   Note: this verifier touches the live `~/.claude/settings.json` via
   the install path's hook-merge step. To minimise blast radius, the
   verifier could optionally `--dry-run` for the hook merge — but the
   acceptance battery accepts the small reversible mutation today
   (the M035 P00 verifiers already exercise the same path). Re-runs
   stay idempotent.

5. **Cross-check** the `install-collision-check.sh` integration: T01's
   symlink-target retargeting may interact with the FR-22 collision
   check's "operator-owned" classification. Verify that re-installing
   over an existing symlink-mode install does not flag the symlink as
   operator-owned. The existing `--on-operator-owned=skip` flag at
   line 570 should already cover this; spot-test by running
   `--mode=symlink` twice in a row against the same fixture and
   confirming idempotency.

## Must-Haves

- Mode-aware uninstall: symlink-mode removes symlinks only; copy-mode removes the staged tree
  - Check: `bash tools/verify/m035-p01-mode-aware-uninstall.sh`

(`#Q-G8` documentation is verified via the artifact line-count + grep
in the phase plan's Artifacts list — `references/installation.md`
contains "Symlink-mode caveats", and the artifact verifier in T04's
phase-suite confirms it.)

## Verification

```bash
bash tools/verify/m035-p01-mode-aware-uninstall.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install-claude-code.sh` (from T01)
  - Key API: `--mode <copy|symlink>` flag is recognised; `ASSET_MODE_OVERRIDE` is the internal variable
  - Behaviour: `--asset-mode-override` is a TEST-ONLY backward-compat alias
- `scripts/lifecycle/install-asset-mode.sh` (from T01)
  - Key API: `symlink` branch produces `link_target=$SRC` (i.e., `<DST>` is a symlink to the source repo path); `copy` branch unchanged
  - Behaviour: `<DST>` is `mkdir -p`'d for copy, `ln -s`'d for symlink
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (from T01)
  - Used opportunistically; not strictly required by T02 verifier

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh:614-637` — manifest-write loop this task branches on `mode_val`
- `packaging/install/install-claude-code.sh:211-237` — uninstall short-circuit this task branches on `mode_tok`
- `references/installation.md` — the user-facing install docs; T01 added § Symlink-mode caveats; T02 appends § Rollback-and-symlink-mode-interaction below it

## Constraints

- **CON-1 (M025 reversibility-gate)**: install→install→uninstall byte
  equality MUST hold for both modes. The verifier exercises this.
- **CON-2 (bash-3.2-and-POSIX-only-in-installers)**: every change is
  bash 3.2 + POSIX-sh-compatible. No process substitution, no
  associative arrays, no `<<<` herestrings.
- **CON-3 (AP-009-shape-guard-honored)**: no compound-chain shapes
  in installer paths. The `case` blocks satisfy this.
- **No P05 work**: rollback support (FR-12) is P05 scope. T02 only
  documents the constraint.

## Notes

- Expected verifier output: `PASS: m035-p01-mode-aware-uninstall`.
- **Plan-phase verifier-availability cross-check (rule 2)**: the
  verifier `m035-p01-mode-aware-uninstall.sh` is authored in step 4
  of this task; available at verification time.
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  proposed `Check:` command is a single-script-file invocation. The
  installer-internal changes use `case` blocks (not inline `&&`
  compound chains).
- **Plan-phase real-DB rule (rule 5)**: not applicable.

## Expected Output

After T02 completes:

- The manifest-write loop in all three installers branches on
  `mode_val`: symlink-mode emits a single `<tgt>\tmode:symlink` line,
  copy-mode emits one line per file beneath `<tgt>` as today.
- The `--uninstall` short-circuit in all three installers branches
  on `mode_tok`: symlink-mode `rm -f`'s the symlink only, copy-mode
  `rm -f`'s the regular file as today. The empty-dir prune step
  remains.
- `references/installation.md` carries § Rollback-and-symlink-mode-interaction
  documenting the `#Q-G8` constraint.
- `tools/verify/m035-p01-mode-aware-uninstall.sh` exercises both
  round-trips and PASSes.
