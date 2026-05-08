---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M035"
name: "User-facing --mode=symlink|copy flag + symlink-to-source semantics + install-meta.txt schema extension"
depends_on: []
---

## Prerequisites

Files that MUST exist on disk at task entry (verified via `[ -f <path> ]`
at plan-authoring time, 2026-05-08):

- `packaging/install/install-claude-code.sh` (the M032/M035-P00 installer; carries the existing TEST-ONLY `--asset-mode-override` flag at lines 53-56, 82-99)
- `packaging/install/install-codex.sh` (sibling installer; same flag surface)
- `packaging/install/install-cursor.sh` (sibling installer; same flag surface)
- `scripts/lifecycle/install-asset-mode.sh` (95 lines; M032/P01 FR-3 per-mode handler — current `symlink` branch resolves to `${HOME}/.claude/orchestrator-runtime/<version>/<src_base>` or `${PROJECT_DIR}/.orchestrator/runtime-cache`)
- `scripts/lifecycle/read-project-assets.sh` (M032/P01 manifest reader; produces `source=<rel>\ttarget=<rel>\tmode=<copy|symlink>` tuples)
- `packaging/bundle/manifest.yml` (declares `project_assets:` — read-only here)
- `CHANGELOG.md` (top-line `## [X.Y.Z]` heading is the SemVer source of truth per CON-4)
- `references/installation.md` (the existing user-facing installation docs)

Pre-existing decisions consumed (from M035 discuss + roadmap):

- AD-7 `#Q-G4` resolution: the unsupported-filesystem advisory uses the
  documented stderr form `"symlink mode unsupported on this filesystem
  — re-run with --mode=copy"` and exits non-zero. No `--mode=auto`.
- `#Q-7` (this plan-phase): symlinks only; hardlinks deferred. Document
  the cross-machine-fragility caveat.
- `#Q-8` (this plan-phase): `--mode=symlink` is Unix-only at v1; copy
  mode (default) is platform-agnostic.
- `#Q-9` (this plan-phase): two new install-meta.txt fields —
  `commit_sha=` (empty when `.git` absent) and `version=` (CHANGELOG
  top-line).

## Description

Promote the existing M032/P01 TEST-ONLY `--asset-mode-override` flag to
the user-facing `--mode=symlink|copy` flag specified by FR-1 across all
three installers, retarget `install-asset-mode.sh`'s symlink branch to
point directly at the orchestrator source repo path (the dogfood-velocity
contract from US-1, replacing the M032-era managed-runtime-root
indirection), and extend `install-meta.txt` with the `commit_sha=` +
`version=` fields the M035 P01 drift helper (T03) consumes. Document
the symlink-mode caveats per `#Q-7` and `#Q-8` resolutions. Backward
compatibility: `--asset-mode-override` is preserved as a recognised
TEST-ONLY alias.

## Steps

1. **Add `--mode` flag in all three installers** (`install-claude-code.sh`,
   `install-codex.sh`, `install-cursor.sh`). Both spellings supported:
   `--mode <copy|symlink>` (space-separated) and `--mode=<copy|symlink>`
   (equals form). Routes into the same internal variable as
   `--asset-mode-override` (rename suggestion: keep the variable name
   `ASSET_MODE_OVERRIDE`; add a comment that `--mode` is the user-facing
   surface and `--asset-mode-override` is preserved as a TEST-ONLY
   alias). Default is the empty string (= manifest's `mode:` field
   wins, i.e. `copy` per CON-7).

   In each installer, parse the flag in the existing `while [ $# -gt 0 ]`
   loop alongside the existing `--asset-mode-override` cases. The
   helper text (`-h|--help` block) must include `--mode <copy|symlink>`.

2. **Update `--help` block** in each installer to document `--mode`.
   Describe symlink-mode as "developer dogfood velocity — links the
   runtime tree directly into the orchestrator source repo so `git pull`
   in the source repo updates every consumer immediately." Reference
   `references/installation.md § Symlink-mode caveats` for the
   constraints (Unix-only, source-path stability, rollback unsupported).

3. **Retarget `scripts/lifecycle/install-asset-mode.sh` symlink branch**.
   Currently the symlink branch sets `link_target` to
   `${resolved_runtime}/${src_base}` where `resolved_runtime` is either
   `~/.claude/orchestrator-runtime/<version>/` (highest sorted) or
   `${PROJECT_DIR}/.orchestrator/runtime-cache/`. Replace this entire
   resolution block with `link_target="$SRC"` — the absolute source
   path the installer already supplies. The Windows guard (lines 52-55)
   stays. Update the `M032_FORCE_WINDOWS` advisory message to read:
   `"FAIL: symlink mode unsupported on this filesystem — re-run with --mode=copy"`
   (per `#Q-G4` discuss-stage resolution). Keep exit code 3.

   The stdout success line stays in the same shape:
   `staged_mode=symlink src=<src> dst=<dst> link_target=<resolved>` —
   only the value of `link_target` changes (now equals `src`).

4. **Extend `install-meta.txt` write step in all three installers**.
   In each installer, locate the `meta_file="$PROJECT_DIR/.orchestrator/install-meta.txt"`
   block (~line 473 in `install-claude-code.sh`; sibling installers have
   the analog block). Add two new write lines inside the existing
   `printf` group:

   ```bash
   commit_sha_val=""
   if [ -d "$REPO_ROOT/.git" ]; then
     commit_sha_val="$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null)"
   fi
   version_val="$(awk '/^## \[/{print; exit}' "$REPO_ROOT/CHANGELOG.md" 2>/dev/null | sed -E 's/^## \[([^]]+)\].*/\1/')"
   ```

   Then in the existing `{ ... } > "$meta_file"` block (currently emits
   `source_root=`, `runtime=`, `installed_at=`), add two more lines:
   `printf 'commit_sha=%s\n' "$commit_sha_val"` and
   `printf 'version=%s\n' "$version_val"`. Empty values are explicit
   (e.g. `commit_sha=`); do not skip the line when the value is empty.

5. **Author `references/installation.md § Symlink-mode caveats`**.
   New section under the existing user-facing installation docs. Body:
   - Symlink mode is Unix-only at v1 (`#Q-8`). Windows symlink support
     defers to M009 post-launch; copy mode (the default) is
     platform-agnostic.
   - The symlink target is the orchestrator source repo path captured
     at install time. Moving or deleting the source repo breaks the
     consumer install loud (clear stderr message naming the missing
     source path; recovery is `--uninstall` followed by re-install in
     copy mode or restoring the source path).
   - Cross-machine fragility (`#Q-7`): symlinks survive `git pull` in
     the source repo cleanly but break across-machine. A repo cloned
     to a different absolute path on a second machine produces broken
     symlinks until re-installed. Hardlink mode is intentionally not
     offered at v1.
   - Bundle hygiene (per Edge Cases line 188): symlinking `scripts/`
     bypasses pre-publish bundle filters; dogfood-only artifacts visible
     in symlink-mode consumers are excluded from copy-mode adopter
     installs by design.

6. **Author `tests/m035-acceptance/fixtures/install-meta-with-sha.txt`**:

   ```
   source_root=/Users/fixture/Sites/orchestrator
   runtime=claude-code
   installed_at=2026-05-08T12:00:00Z
   commit_sha=0000000000000000000000000000000000000001
   version=0.9.0
   ```

7. **Author `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt`**:

   ```
   source_root=/Users/fixture/Sites/orchestrator
   runtime=claude-code
   installed_at=2026-04-15T12:00:00Z
   ```

   (Three fields only — pre-M035 install shape, lacks `commit_sha=`
   and `version=`; this is the SC-3b fallback fixture.)

8. **Author `tools/verify/m035-p01-mode-flag.sh`**. Verifier asserts
   that all three installers have `--mode` in their argument-parsing
   `case` blocks (greps for `--mode)` literal). Also asserts
   `--asset-mode-override` is preserved (greps for the literal).
   Helper script shape (single-script-file per AD-19):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p01-mode-flag.sh — assert --mode flag present in 3 installers.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   fail=0
   for inst in install-claude-code.sh install-codex.sh install-cursor.sh; do
     if ! grep -q -- '--mode)' "$REPO_ROOT/packaging/install/$inst"; then
       echo "FAIL: $inst missing --mode flag handler" >&2
       fail=1
     fi
     if ! grep -q -- '--asset-mode-override)' "$REPO_ROOT/packaging/install/$inst"; then
       echo "FAIL: $inst missing --asset-mode-override backward-compat handler" >&2
       fail=1
     fi
   done
   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p01-mode-flag"; exit 0; fi
   exit 1
   ```

9. **Author `tools/verify/m035-p01-symlink-source-target.sh`**. Verifier
   stages a `mktemp -d` fixture project, runs `install-claude-code.sh
   --project-dir <fixture> --mode=symlink`, then asserts (a) the
   exit code is 0, (b) `readlink <fixture>/scripts` (or whichever
   symlink target lands first per the manifest) resolves to a path
   under `$REPO_ROOT/`, and (c) `install-meta.txt` contains the
   `commit_sha=` and `version=` lines (non-empty when run inside a
   git checkout). Cleanup the fixture on exit. Single-script-file
   shape per AD-19.

## Must-Haves

The truths and `Check:` commands satisfied by this task are:

- `--mode=symlink|copy` flag exposed user-facing on all three installers
  - Check: `bash tools/verify/m035-p01-mode-flag.sh`
- After `--mode=symlink`, `readlink <fixture>/scripts` resolves under `$REPO_ROOT`
  - Check: `bash tools/verify/m035-p01-symlink-source-target.sh`

## Verification

```bash
bash tools/verify/m035-p01-mode-flag.sh
bash tools/verify/m035-p01-symlink-source-target.sh
```

## Inputs

### From Previous Tasks

(none — this is the foundation task in P01)

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — user-facing installer; lines 53-99 carry the existing `--asset-mode-override` flag this task promotes to `--mode`. Lines 462-483 carry the `install-meta.txt` write step this task extends with `commit_sha=` + `version=`.
- `packaging/install/install-codex.sh`, `packaging/install/install-cursor.sh` — sibling installers with parallel argument-parsing structure.
- `scripts/lifecycle/install-asset-mode.sh` — 95-line per-mode handler; lines 50-89 are the symlink branch this task retargets to `link_target="$SRC"`. Windows guard (lines 52-55) stays; advisory message updates.
- `CHANGELOG.md` — SemVer top-line source (CON-4); `awk '/^## \[/{print; exit}'` extracts the latest version block.
- `references/installation.md` — user-facing install docs; the new `## Symlink-mode caveats` section appends to the existing structure.

## Constraints

- **CON-2 (bash-3.2-and-POSIX-only-in-installers)**: every installer
  edit stays bash 3.2 + POSIX-sh-compatible. The new `git rev-parse`
  + `awk` + `sed` calls all work on bash 3.2.
- **CON-3 (AP-009-shape-guard-honored)**: no new compound-chain shapes
  in installer paths. The `[ -d "$REPO_ROOT/.git" ] && ...` predicate
  uses an `if` block, not an inline `&&` chain.
- **CON-7 (--mode default is copy)**: empty `ASSET_MODE_OVERRIDE`
  means manifest's `mode:` field wins (which is `copy` per
  `packaging/bundle/manifest.yml`). Do NOT change the default.
- **Backward compat (TEST-ONLY alias)**: M032 P01 acceptance scripts
  invoke `--asset-mode-override`. That flag MUST keep working
  byte-identically. The new `--mode` flag is a documented public
  surface; the old flag is undocumented but recognised.
- **No M025 or M027 schema changes**: install-meta.txt is M035-owned
  per the spec's Knowledge-Layer Boundary (line 252-265). Adding
  `commit_sha=` and `version=` is in scope; reformatting the file is
  not.

## Notes

- Expected verifier output: `PASS: m035-p01-mode-flag` and a similar
  PASS line from the symlink-source verifier.
- **Plan-phase verifier-availability cross-check (rule 2)**: this task
  authors both `m035-p01-mode-flag.sh` and `m035-p01-symlink-source-target.sh`
  in step 8 + 9; their availability at verification time is
  satisfied by their authorship inside this same task.
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  proposed `Check:` command is a single-script-file invocation —
  `bash tools/verify/m035-p01-*.sh` — which is the AD-19-required
  shape. No compound-chain shapes are introduced.
- **Plan-phase real-DB rule (rule 5)**: not applicable — no SQL or
  schema-bound integration code.

## Expected Output

After T01 completes:

- All three installers accept `--mode=symlink|copy` with `--mode <X>`
  and `--mode=<X>` syntaxes; `--asset-mode-override` still works.
- `install-asset-mode.sh` symlink branch points `link_target` at the
  source repo path supplied by the installer.
- `install-meta.txt` carries five lines (`source_root=`, `runtime=`,
  `installed_at=`, `commit_sha=`, `version=`) on every install,
  including with empty values when absent.
- `references/installation.md § Symlink-mode caveats` documents
  `#Q-7` (symlink-only, cross-machine fragility) and `#Q-8`
  (Unix-only at v1).
- Two fixture install-meta.txt shapes are on disk for T03 to consume.
- Two verifiers are on disk and PASS against the new state.
