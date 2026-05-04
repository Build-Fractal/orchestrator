---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M032"
name: "Migrate install-claude-code.sh to project_assets schema (FR-2 + FR-4 + FR-22) — primary installer + pre-M032 golden record"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `packaging/bundle/manifest.yml` carries the `project_assets:` section with four `mode: copy` entries (verified by `bash tools/verify/m032-p01-manifest-schema-shape.sh`).
- T01 complete: `scripts/lifecycle/read-project-assets.sh` exists and emits four tab-separated tuples (verified by `bash tools/verify/m032-p01-reader-emits-tuples.sh`).
- T01 complete: `scripts/lifecycle/install-asset-mode.sh` exists with copy + symlink + Windows-fail-closed branches (verified by `bash tools/verify/m032-p01-mode-handler-symlink.sh`).
- T01 complete: `scripts/lifecycle/install-collision-check.sh` exists with the three FR-22 oracle branches (verified by `bash tools/verify/m032-p01-collision-oracle.sh`).
- `packaging/install/install-claude-code.sh` exists and contains the literal `RUNTIME_DIRS="scripts templates references commands"` at approximately line 423 (verified by `grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh`).
- `tools/verify/fixtures/` directory does NOT yet exist; T02 creates it via `mkdir -p` to hold the `m032-pre-m032-golden.txt` reference file. (No conflicting pre-existing path.)

## Description

T02 is the primary FR-2 migration. It replaces the hardcoded `RUNTIME_DIRS` block in `install-claude-code.sh:415-458` with a `read-project-assets.sh`-driven loop, dispatching each tuple through `install-collision-check.sh` (FR-22) and then `install-asset-mode.sh` (FR-3). T02 also amends the `installed-files.txt` writer to include the per-asset `mode:` field per FR-4.

T02 has a load-bearing ordering invariant: **the pre-M032 golden file-tree count MUST be recorded BEFORE the installer migration is applied**. The CON-4 byte-identical contract is checked by SC-1 (T04) by comparing the post-migration `mode: copy` install output against this golden. If the golden is recorded after the migration lands, the comparison is circular (it would compare the new installer against itself). T02 step 1 records the golden by running the pre-T02 (= pre-M032) installer against a temp fixture and capturing the file-tree shape; step 2+ then applies the migration. The golden is committed at `tools/verify/fixtures/m032-pre-m032-golden.txt` so SC-1 can read it on every run.

## Steps

1. **Record the pre-M032 golden file-tree count** BEFORE making any edits to `install-claude-code.sh`. Create a temp fixture and run the current (pre-T02) installer against it:

```bash
tmp_fixture=$(mktemp -d)
bash packaging/install/install-claude-code.sh --dry-run --project-dir "$tmp_fixture" > /tmp/m032-golden-stdout.txt
mkdir -p tools/verify/fixtures
{
  echo "# Pre-M032 golden file-tree shape (recorded T02 step 1, before FR-2 migration)"
  echo "# Source: bash packaging/install/install-claude-code.sh --dry-run"
  echo "# Format: <runtime-dir> file_count=<N>"
  for dir in commands scripts references templates; do
    cnt=$(grep -c "^would_write=${tmp_fixture}/${dir}/" /tmp/m032-golden-stdout.txt || true)
    echo "${dir}/ file_count=${cnt}"
  done
  echo "# Total pre-M032 RUNTIME_DIRS file count:"
  total=$(grep -c "^would_write=${tmp_fixture}/" /tmp/m032-golden-stdout.txt | head -n 1)
  echo "total file_count=${total}"
} > tools/verify/fixtures/m032-pre-m032-golden.txt
rm -rf "$tmp_fixture"
```

   Commit `tools/verify/fixtures/m032-pre-m032-golden.txt` as the immutable CON-4 reference. Subsequent installer changes do NOT regenerate this file.

2. **Read `packaging/install/install-claude-code.sh` lines 415-458** carefully. Identify the exact block to replace: starts at line 415 (the `# --- 4.5 Stage runtime ...` comment header) through line 458 (the `echo "staged=$runtime_staged files manifest=$manifest_file"` close). The replacement preserves the same outer structure (header comment, `manifest_file=` declaration, `runtime_staged=0` initializer, dry-run vs real-run branching, final `staged=` echo) but swaps the `for dir in $RUNTIME_DIRS` loop for a `read-project-assets.sh`-driven loop.

3. **Author the replacement block**. The replacement reads:

```bash
# --- 4.5 Stage runtime payload via project_assets: manifest schema (FR-2 + FR-3 + FR-4 + FR-22) ---
# The pre-M032 RUNTIME_DIRS hardcoded loop is fully replaced by the
# project_assets: schema in packaging/bundle/manifest.yml. Each tuple
# from read-project-assets.sh is dispatched through:
#   1. install-collision-check.sh (FR-22 dual-oracle hierarchy)
#   2. install-asset-mode.sh      (FR-3 per-mode handler)
# At mode: copy the per-target file-tree is byte-identical to the pre-M032
# behavior (CON-4 reference: tools/verify/fixtures/m032-pre-m032-golden.txt).
# --asset-mode-override flag (TEST-ONLY) lets P01 acceptance scripts
# exercise mode: symlink without re-authoring the manifest.
manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
runtime_staged=0
project_assets_targets=""

# First pass: collect the project-assets target list (needed by collision check
# for the bootstrapping oracle's "in the project_assets target list" check).
while IFS= read -r tuple; do
  tgt=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  project_assets_targets="${project_assets_targets}${tgt}\n"
done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")

# Second pass: dispatch each tuple through collision check + mode handler.
while IFS= read -r tuple; do
  src_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^source=/){sub(/^source=/, "", $i); print $i}}}')
  tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')

  # --asset-mode-override (TEST-ONLY) takes precedence over manifest mode.
  [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"

  src_abs="$REPO_ROOT/${src_rel%/}"
  dst_abs="$PROJECT_DIR/${tgt_rel%/}"

  if [ ! -d "$src_abs" ]; then
    echo "FAIL: project_assets source missing: $src_abs" >&2
    exit 1
  fi

  # FR-22 collision check (skips on collision-clean cases).
  if ! bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" \
    "$dst_abs" "$PROJECT_DIR" "$(printf '%b' "$project_assets_targets")"; then
    rc=$?
    if [ "$rc" = "4" ]; then
      echo "FAIL: staged-dirs-collision: project_assets entry $src_rel collides with operator-owned $tgt_rel" >&2
    fi
    exit "$rc"
  fi

  # FR-3 mode dispatch (copy or symlink).
  if [ "$DRY_RUN" = "1" ]; then
    find "$src_abs" -type f | while IFS= read -r f; do
      rel="${f#$src_abs/}"
      echo "would_write=$dst_abs/$rel"
    done
    cnt=$(find "$src_abs" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + cnt))
  else
    bash "$REPO_ROOT/scripts/lifecycle/install-asset-mode.sh" \
      "$src_abs" "$dst_abs" "$mode_val" "$PROJECT_DIR"
    cnt=$(find "$src_abs" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + cnt))
  fi
done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")

# FR-4: write installed-files.txt with per-asset mode: field.
if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$(dirname "$manifest_file")"
  : > "$manifest_file"
  while IFS= read -r tuple; do
    tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
    mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')
    [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"
    if [ -d "$PROJECT_DIR/${tgt_rel%/}" ]; then
      ( cd "$PROJECT_DIR" && find "${tgt_rel%/}" -type f ) | \
        awk -v m="$mode_val" '{printf "%s\tmode:%s\n", $0, m}' >> "$manifest_file"
    fi
  done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")
  echo "staged=$runtime_staged files manifest=$manifest_file"
fi
```

4. **Add `--asset-mode-override` flag parsing** to the existing flag-parsing loop near the top of `install-claude-code.sh`. The flag takes one value (`copy` or `symlink`); reject any other value with `FAIL: --asset-mode-override requires copy|symlink`. Default is empty (manifest mode wins).

5. **Verify the migration is byte-identical at `mode: copy`** by running `bash packaging/install/install-claude-code.sh --dry-run --project-dir /tmp/m032-postmig-golden-check` and comparing the `would_write=` lines against the golden recorded in step 1. The two outputs MUST be the same set of paths (unordered comparison via `sort | uniq`).

6. **Author `tools/verify/m032-p01-install-cc-byte-identical.sh`**. The verifier:
   - Asserts `! grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh` (FR-2 — old block fully removed).
   - Asserts `grep -q 'read-project-assets.sh' packaging/install/install-claude-code.sh` (new dispatch present).
   - Reads `tools/verify/fixtures/m032-pre-m032-golden.txt` and asserts the file is non-empty and references all four runtime dirs.
   - Runs `bash packaging/install/install-claude-code.sh --dry-run --project-dir /tmp/m032-bi-check-$$` against a fresh temp dir; counts `would_write=` lines per runtime dir; compares against the per-dir counts in the golden. Asserts equality.

## Must-Haves

- The literal token `RUNTIME_DIRS=` no longer appears anywhere in `packaging/install/install-claude-code.sh` (FR-2 — full removal, no commented-out fallback).
- The new project-asset stage in `install-claude-code.sh` invokes `scripts/lifecycle/read-project-assets.sh`, `scripts/lifecycle/install-collision-check.sh`, and `scripts/lifecycle/install-asset-mode.sh` (FR-2 + FR-3 + FR-22 fully wired).
- `installed-files.txt` written by `install-claude-code.sh` contains a tab-separated `mode:` field on every line (FR-4).
- `tools/verify/fixtures/m032-pre-m032-golden.txt` exists with per-runtime-dir file counts captured BEFORE the migration was applied (CON-4 reference).
- A second invocation of `install-claude-code.sh` against the same `--project-dir` produces a byte-identical `installed-files.txt` (idempotency check).
- A `--asset-mode-override symlink` invocation against a POSIX host with `~/.claude/orchestrator-runtime/<version>/` populated produces symlinks at the target paths (FR-3 forward-looking exercise).
- `bash tools/verify/m032-p01-install-cc-byte-identical.sh` exits 0.

## Verification

```bash
bash tools/verify/m032-p01-install-cc-byte-identical.sh
bash tools/verify/m032-p01-installed-files-format.sh
```

## Inputs

### From Previous Tasks

- `packaging/bundle/manifest.yml` (from T01)
  - Key API: `project_assets:` top-level YAML list with four entries, each with `source:` / `target:` / `mode: copy`.
- `scripts/lifecycle/read-project-assets.sh` (from T01)
  - Key API: positional arg `<bundle-dir>` (default `packaging/bundle/`); emits one `source=...\ttarget=...\tmode=copy|symlink` line per entry on stdout; exit 0 on success; exit 2 on malformed manifest.
- `scripts/lifecycle/install-asset-mode.sh` (from T01)
  - Key API: positional args `<src-abs> <dst-abs> <mode> <project-dir-abs>`; dispatches `mode` to `copy` (`cp -R`) or `symlink` (`ln -s` with POSIX fail-closed); exit 0 on success; exit 3 on Windows fail-closed.
- `scripts/lifecycle/install-collision-check.sh` (from T01)
  - Key API: positional args `<target-abs> <project-dir-abs> <project-assets-target-list-newline-sep>`; runs the FR-22 dual-oracle hierarchy; exit 0 on clean / framework-installed; exit 4 on operator-owned collision.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — pre-T02 form has the `RUNTIME_DIRS` block at lines 415-458 and the flag-parsing loop near the top.
- `$REPO_ROOT` (resolved by the installer near line 30 from the script's own location) — used as the source root for `find ... -type f` enumeration.

## Constraints

- T02 MUST NOT touch `install-codex.sh` or `install-cursor.sh`. Symmetry pass is T03's job.
- T02 MUST NOT introduce a behavior regression: the dry-run `would_write=` set against any consumer fixture is unordered-equal pre- and post-T02 (CON-4).
- T02 MUST NOT delete or rename `tools/verify/fixtures/m032-pre-m032-golden.txt` once committed; it is the immutable CON-4 reference T04's SC-1 acceptance script reads.
- T02 MUST preserve the installer's existing dry-run branching, summary line, and exit-code conventions byte-identically — the project-asset stage is the only block that changes.
- The `--asset-mode-override` flag is documented in the installer's flag-help block as TEST-ONLY (P01 surface; will be replaced by manifest-declarable symlink mode in P02).

## Expected Output

After T02 closes: the installer body no longer contains `RUNTIME_DIRS=` (verified by `! grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh`); the new project-asset stage dispatches through the three T01-authored libraries; `installed-files.txt` carries `mode:` field on every line; `tools/verify/fixtures/m032-pre-m032-golden.txt` is committed; `bash tools/verify/m032-p01-install-cc-byte-identical.sh` exits 0; running the installer twice against the same fixture produces a byte-identical `installed-files.txt`. The codex and cursor installers are unchanged from pre-T02 state — they still contain `RUNTIME_DIRS=` and will be migrated by T03.
