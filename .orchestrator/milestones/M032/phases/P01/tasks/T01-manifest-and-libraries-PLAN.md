---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M032"
name: "project_assets: schema in manifest + shared reader helper + per-mode handler library + collision check library (FR-1, FR-3, FR-22, additive surface only)"
depends_on: []
---

## Prerequisites

- `packaging/bundle/manifest.yml` exists with the pre-M032 schema (verified by `[ -f packaging/bundle/manifest.yml ]` and `grep -q '^schema_version:' packaging/bundle/manifest.yml`).
- `packaging/install/install-claude-code.sh` exists and contains the literal `RUNTIME_DIRS="scripts templates references commands"` at approximately line 423 (verified by `grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh`). Same for `install-codex.sh:236` and `install-cursor.sh:245`.
- `scripts/lifecycle/` exists as a directory and is the canonical home for installer-lifecycle helpers (verified by `[ -d scripts/lifecycle ]`).
- `tools/verify/` exists as a directory and is the canonical home for project-owned slug-bearing verifiers per AD-19 path discipline.
- T01 entry: NONE of the three installers may be amended in this task; FR-2 migration is T02 + T03's job. T01 is purely library + manifest-schema work.

## Description

T01 ships the four additive surfaces that T02 and T03 will then dispatch through. None of the three installers is touched in this task — the `RUNTIME_DIRS` block at `install-{claude-code,codex,cursor}.sh` stays live during T01 to preserve the pre-M032 install behavior unchanged. T01's diff is reviewable in isolation: a manifest amendment, three new lifecycle helpers, and five new verifier scripts.

The four deliverables:

1. **`packaging/bundle/manifest.yml` `project_assets:` section (FR-1)** — a top-level YAML list with exactly four entries. Each entry declares `source:` (path under `<REPO_ROOT>/`), `target:` (path under `<PROJECT_DIR>/`), and `mode: copy` (default per FR-1; v1 ships only `copy` in the manifest itself — `symlink` is exercised by the test-only `--asset-mode-override` flag in P01 and becomes a manifest-declarable mode in P02+).

2. **`scripts/lifecycle/read-project-assets.sh` (FR-2 prep)** — the shared reader sourced by all three installers in T02 + T03. Reads the manifest at a caller-supplied bundle path and emits one tab-separated `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` line per entry on stdout. Pure stdout — no environment mutation, no temp files. The reader is the seam that lets T02 + T03 share migration logic without re-implementing manifest parsing.

3. **`scripts/lifecycle/install-asset-mode.sh` (FR-3 + NG-9)** — the per-mode handler invoked once per `read-project-assets.sh` tuple. Dispatches on `mode`: `copy` reproduces today's `cp -R "$src/." "$dst/"` semantics byte-identically; `symlink` resolves the symlink target as `~/.claude/orchestrator-runtime/<version>/<source-basename>` (with fallback to `<PROJECT_DIR>/.orchestrator/runtime-cache/<source-basename>` per Assumption A-1) and creates the symlink with `ln -s`. Windows fail-closed: `M032_FORCE_WINDOWS=1` OR an unavailable `ln -s` exits non-zero with the literal `POSIX-only in v1` diagnostic and writes nothing under `<PROJECT_DIR>/<target>`.

4. **`scripts/lifecycle/install-collision-check.sh` (FR-22 + MIT-006)** — the dual-oracle hierarchy invoked once per tuple BEFORE `install-asset-mode.sh` dispatches. Reads in strict order: tracking-file oracle (primary, `installed-files.txt` left-column lookup); bootstrapping oracle (MIT-006, applies when `installed-files.txt` is absent); operator-owned oracle (tertiary, fails closed naming both manifest entry and operator-owned path).

## Steps

1. **Read the existing `packaging/bundle/manifest.yml`** (37 lines). Confirm the top-level keys and their values.

2. **Amend `packaging/bundle/manifest.yml`** by appending a `project_assets:` section after the existing `runtime_compatibility:` block. The exact YAML to append:

```yaml
# project_assets:
# Project-owned runtime payload staged into <PROJECT_DIR>/<target> by the
# installer's project-asset stage (FR-1 / FR-2). Each entry is processed
# through scripts/lifecycle/install-collision-check.sh (FR-22) and then
# scripts/lifecycle/install-asset-mode.sh (FR-3). v1 ships only mode: copy
# in the manifest; mode: symlink is exercised by the --asset-mode-override
# install flag in P01 and becomes manifest-declarable in P02+ (NG-9 keeps
# Windows fail-closed regardless).
project_assets:
  - source: commands/
    target: commands/
    mode: copy
  - source: scripts/
    target: scripts/
    mode: copy
  - source: references/
    target: references/
    mode: copy
  - source: templates/
    target: templates/
    mode: copy
```

3. **Author `scripts/lifecycle/read-project-assets.sh`**. The reader takes one positional arg (bundle dir, default `packaging/bundle/`), reads `<bundle-dir>/manifest.yml`, and emits one line per `project_assets:` entry as `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` on stdout. Use `awk` (POSIX) or a manual line-walking shell loop to parse the section between `^project_assets:$` and the next top-level key (or EOF). Reject manifests where any entry is missing `source`, `target`, or `mode` (exit 2 with `FAIL: project_assets entry N missing required key <key>`). Reject manifests where `mode` is anything other than `copy` or `symlink` (exit 2 with `FAIL: project_assets entry N mode='<x>' invalid (must be copy|symlink)`). On success, exit 0; on no `project_assets:` section, exit 0 with no stdout (downstream callers treat zero-tuple emission as a no-op).

4. **Author `scripts/lifecycle/install-asset-mode.sh`**. The handler takes four args: `<src-abs-path> <dst-abs-path> <mode> <project-dir-abs>` (project-dir is needed for the runtime-cache fallback). Dispatch:
   - `mode=copy`: run `mkdir -p "$dst"` then `cp -R "$src/." "$dst/"` and emit `staged_mode=copy src=<src> dst=<dst>` on stdout. Exit 0 on success.
   - `mode=symlink`: detect Windows or absent `ln` — `if [ "${M032_FORCE_WINDOWS:-0}" = "1" ] || ! command -v ln >/dev/null 2>&1; then echo "FAIL: mode: symlink is POSIX-only in v1 (NG-9)" >&2; exit 3; fi`. Resolve the symlink target: `runtime_root="${HOME}/.claude/orchestrator-runtime"` and pick the highest-versioned subdir if present, else fall back to `<PROJECT_DIR>/.orchestrator/runtime-cache/`. Run `mkdir -p "$(dirname "$dst")"`, `rm -rf "$dst"` (idempotency — second invocation overwrites the symlink), then `ln -s "$resolved_runtime/<basename>" "$dst"` and emit `staged_mode=symlink src=<src> dst=<dst> link_target=<resolved>` on stdout.
   - Any other `mode`: exit 2 with `FAIL: install-asset-mode.sh: unknown mode '<x>'` on stderr.

5. **Author `scripts/lifecycle/install-collision-check.sh`**. The check takes three args: `<target-abs-path> <project-dir-abs> <project-assets-target-list-newline-sep>` and dispatches the FR-22 oracle hierarchy:
   - **Tracking-file oracle (primary)**: `manifest="$project_dir/.orchestrator/installed-files.txt"`. If `[ -f "$manifest" ]` AND `awk -F'\t' '{print $1}' "$manifest" | grep -Fxq "$rel_target"` (rel_target is the relative form of `<target-abs-path>` from `<project-dir-abs>`), emit `oracle=tracking-file result=framework-installed target=<rel>` and exit 0.
   - **Bootstrapping oracle (MIT-006)**: if `[ ! -f "$manifest" ]` AND the relative target appears in the project-assets target list (passed in arg 3), emit `oracle=bootstrapping result=framework-installed target=<rel> mit=MIT-006` and exit 0. The caller is responsible for writing `installed-files.txt` reflecting the bootstrapped state at the END of the install run.
   - **Operator-owned oracle (tertiary)**: if the target path pre-exists (`[ -e "$abs_target" ]`) AND it is not in the tracking file AND `git -C "$project_dir" check-ignore -- "$rel_target" >/dev/null 2>&1` exits non-zero (i.e., the path is NOT ignored — it's tracked or untracked-but-not-ignored, so plausibly operator-owned), emit `oracle=operator-owned result=collision target=<rel> manifest_entry=<rel>` on stderr and exit 4 (collision exit code reserved for FR-22). The caller's diagnostic format is the literal string `staged-dirs-collision: project_assets entry <entry> collides with operator-owned <path>`.
   - Otherwise (target does not pre-exist OR is gitignored), emit `oracle=clean result=ok target=<rel>` and exit 0.

6. **Author the five T01 verifiers** under `tools/verify/`:
   - `m032-p01-manifest-schema-shape.sh` — `grep -q '^project_assets:$' packaging/bundle/manifest.yml`; assert exactly four `^  - source: ` lines under the `project_assets:` block; assert each entry has matching `target:` and `mode: copy` lines.
   - `m032-p01-reader-emits-tuples.sh` — invoke `bash scripts/lifecycle/read-project-assets.sh packaging/bundle/`; assert stdout has exactly four lines each matching `^source=[^\t]+\ttarget=[^\t]+\tmode=copy$`.
   - `m032-p01-mode-handler-symlink.sh` — exercise both branches against a `mktemp -d`-staged fixture: copy mode produces a regular file tree; symlink mode under `M032_FORCE_WINDOWS=1` exits 3 with `POSIX-only in v1` on stderr; symlink mode without the env var produces a symlink (test by `[ -L <dst> ]`).
   - `m032-p01-installed-files-format.sh` — currently asserts only that the file format invariant is documented inline in `install-collision-check.sh` and that the install-asset-mode emit lines do NOT use spaces between path and `mode:` token (T02 ships the actual writer; T01's verifier asserts the contract documentation).
   - `m032-p01-collision-oracle.sh` — exercise all three oracle branches against `mktemp -d` fixtures: tracking-file branch (writes `installed-files.txt` then probes), bootstrapping branch (no tracking file, target in list), operator-owned branch (pre-existing target, not in tracking, not gitignored — assert exit 4 + `oracle=operator-owned` + `result=collision` on stderr).

7. **Run the five new verifiers locally** to confirm exit 0 from each.

## Must-Haves

- The `project_assets:` schema is present in `packaging/bundle/manifest.yml` per the exact YAML in step 2 (FR-1).
- `scripts/lifecycle/read-project-assets.sh` exists, is executable, and emits four `source=...\ttarget=...\tmode=copy` lines for the manifest landed in step 2.
- `scripts/lifecycle/install-asset-mode.sh` exists and supports both `copy` (byte-identical to today's `cp -R "$src/." "$dst/"`) and `symlink` (POSIX `ln -s`) with Windows fail-closed via `M032_FORCE_WINDOWS=1` (FR-3 / NG-9).
- `scripts/lifecycle/install-collision-check.sh` exists and implements all three FR-22 oracle branches with the documented exit-code contract and MIT-006 bootstrapping branch.
- All five T01 verifiers under `tools/verify/m032-p01-*.sh` exist, are executable, and exit 0 against the T01-landed surface.

## Verification

```bash
bash tools/verify/m032-p01-manifest-schema-shape.sh
bash tools/verify/m032-p01-reader-emits-tuples.sh
bash tools/verify/m032-p01-mode-handler-symlink.sh
bash tools/verify/m032-p01-installed-files-format.sh
bash tools/verify/m032-p01-collision-oracle.sh
```

## Inputs

### From Previous Tasks

None. T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `packaging/bundle/manifest.yml` — pre-M032 manifest schema with `schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility` top-level keys. T01 amends it by appending `project_assets:` only; pre-existing keys are preserved byte-identically.
- `packaging/install/install-claude-code.sh` (read-only in T01) — lines 415-458 contain the live `RUNTIME_DIRS` loop. T01 does NOT touch this file.
- `scripts/lifecycle/` directory — canonical home for installer-lifecycle helpers (existing helpers: `init-project.sh`, `before-commit.sh`, `after-verify-sync.sh`).
- `tools/verify/` directory — canonical home for project-owned slug-bearing verifiers (per AD-19 path discipline; existing verifiers under `m030-p0*-*.sh` and `m031-p0*-*.sh` namespaces).

## Constraints

- T01 MUST NOT amend any of the three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`). Migration is T02 + T03. The pre-M032 install behavior MUST be unchanged at T01 close.
- The manifest amendment MUST preserve every pre-existing top-level key (CON-4 byte-identical at the manifest layer).
- The reader, mode handler, and collision check libraries MUST use single-script-file shapes only — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes (AD-19). All five verifiers ship in script-file form per the `tools/verify/m032-p01-*.sh` pattern.
- Exit-code discipline: 0 = success; 2 = invalid input (malformed manifest, unknown mode); 3 = POSIX-only fail-closed (Windows symlink); 4 = FR-22 collision detected. These codes are part of the library contract T02 + T03 + T04 read against.

## Expected Output

After T01 closes, `bash tools/verify/m032-p01-manifest-schema-shape.sh && bash tools/verify/m032-p01-reader-emits-tuples.sh && bash tools/verify/m032-p01-mode-handler-symlink.sh && bash tools/verify/m032-p01-installed-files-format.sh && bash tools/verify/m032-p01-collision-oracle.sh` exits 0 and the disk state is: amended `manifest.yml` with `project_assets:` section + four runtime-dir entries; three new lifecycle helpers under `scripts/lifecycle/`; five new verifiers under `tools/verify/m032-p01-*.sh`. The three installers and the existing install behavior are byte-identical to pre-T01 — verified by running `bash packaging/install/install-claude-code.sh --dry-run --project-dir <some-fixture>` and observing the same `would_write=` lines as before T01.
