---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M028"
name: "Installer payload copy + settings-merge install-side dedup"
depends_on: ["T01", "T02"]
---

## Prerequisites

- **T01 complete**: `scripts/hooks/pre-bash-shape-guard.sh` self-locates via `BASH_SOURCE[0]` and contains zero `CLAUDE_PROJECT_DIR` references in the resolution block. T03's installer copies this hook into `~/.claude/orchestrator-hooks/` where its self-location resolves to that same dir as `HOOK_DIR`. Confirm T01's verifiers PASS before starting T03.
- **T02 complete**: `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` emits absolute `bash ${HOME}/.claude/orchestrator-hooks/<name>.sh` paths with `_orchestrator_managed: true` on every leaf. T03's installer captures this fragment and feeds it to `settings-merge.sh`. Confirm T02's verifier PASSes before starting T03.
- `scripts/util/settings-merge.sh` exists at the M025/P01/T02 baseline shape (333 lines; merge / uninstall subcommands; python3 baseline; cascade-cleanup on uninstall). T03 modifies the merge algorithm to add install-side dedup keyed on `(event, matcher, command) × _orchestrator_managed: true`. The current implementation already has an "idempotency guard" comment for `command-string` matching — T03 promotes it to the full tuple-based key.
- `packaging/install/install-claude-code.sh` exists (334 lines; `--probe` / `--register` / `--hook-config` capture / `settings-merge.sh merge` / runtime staging / SUMMARY line). T03 extends it with a "stage hooks payload" step that runs before the existing settings-merge step.
- `scripts/verify/lib/shape-classifier.sh` exists. T03 stages this into `${HOME}/.claude/orchestrator-hooks/shape-classifier.sh` so the post-T01 self-locating hook finds its sibling at runtime.
- `scripts/lifecycle/before-commit.sh` and `scripts/lifecycle/after-verify-sync.sh` exist. T03 stages both into the runtime-stable hooks dir under their bare names.
- The reject_lookup data lives inside `scripts/hooks/pre-bash-shape-guard.sh` as the `reject_lookup()` function (M021/P05 shape). There is no separate reject_lookup data file at the M021 baseline; T03 does NOT extract it into a separate file. (P03 may add new reject_lookup entries via classifier extension; T03 ships the M021 baseline reject_lookup as part of the hook script itself.)

## Description

Extend `packaging/install/install-claude-code.sh` to copy the full hooks payload into `${HOME}/.claude/orchestrator-hooks/` BEFORE invoking `settings-merge.sh merge`, and extend `settings-merge.sh` itself with an install-side dedup pass keyed on the `(event, matcher, command)` tuple under the `_orchestrator_managed: true` flag.

After T03:
1. Fresh-install path: installer creates `${HOME}/.claude/orchestrator-hooks/`, copies in 5 files (`pre-bash-shape-guard.sh`, `shape-classifier.sh`, `before-commit.sh`, `after-verify-sync.sh`, plus a `MANIFEST` text file listing the staged set), then runs the existing settings-merge step against `${HOME}/.claude/settings.json`.
2. Repeat-install path: every staged file is overwritten (idempotent — `cp -f`). The settings-merge step deduplicates the JSON fragment against the on-disk settings.json so the second run produces a byte-identical settings.json.
3. Uninstall path: existing `settings-merge.sh uninstall` cascade still runs. T03 ALSO removes the staged `${HOME}/.claude/orchestrator-hooks/` dir contents (only files the installer staged — never user-authored siblings) per the manifest.

The dedup key change in `settings-merge.sh`:
- The current "idempotency guard" matches on `command` string only (line ~17 of the algorithm comment).
- T03 changes the match to the full `(event, matcher, command)` tuple, where `event` is the top-level hooks key (`Stop`, `PreToolUse`, etc.), `matcher` is the wrapper-level field (empty string for events without matchers like `Stop`), and `command` is the leaf object's `command` field. Match is exact-string on each component.
- The `_orchestrator_managed: true` flag remains the over-arching scope: only entries carrying the flag participate in dedup. User-authored entries (no flag) are never deduplicated against orchestrator entries.
- This is implemented inside the python3 merge body — the existing python block already iterates fragment leaves; T03 changes the dedup key from `command-only` to `(event, matcher, command)`.

Land one new verifier under `scripts/verify/m028/`:
- `p02-hooks-payload-staged.sh` — runs the installer against an isolated `HOME` fixture and asserts every expected file is present at `${HOME}/.claude/orchestrator-hooks/`. Single-file flat shape, AD-19 + bash 3.2.

The install-roundtrip pinned-sha gate (FR-6, SC-2) is T05's deliverable. T03 stops at the dedup logic + payload copy; T05 wires the round-trip proof.

## Steps

1. Read `packaging/install/install-claude-code.sh` end to end. Identify the four existing stages: (1) `--probe` runtime check, (2) `--register` skill registration, (3) hook-config capture + `settings-merge.sh merge`, (4) bundle config staging, (5) runtime staging. T03 inserts a NEW stage 3' between current stages 2 and 3: "Stage hooks payload to runtime-stable hooks dir."

2. Insert the hooks-payload stage after the `--register` block and before the `--hook-config` capture. Verbatim shape:

    ```bash
    # --- 3'. Stage hooks payload into runtime-stable hooks dir (M028/P02/T03) ---
    # The runtime-stable contract per CON-9: ~/.claude/orchestrator-hooks/.
    # The directory holds:
    #   pre-bash-shape-guard.sh   -- T01 self-locating hook
    #   shape-classifier.sh       -- M021 classifier library (sibling of hook)
    #   before-commit.sh          -- M025 lifecycle script
    #   after-verify-sync.sh      -- M025 lifecycle script
    #   MANIFEST                  -- text file listing staged set (used by --uninstall)
    # The hook self-locates the classifier as a sibling under HOOK_DIR (T01); the
    # installer therefore stages classifier alongside hook in this dir, NOT under
    # the in-tree scripts/verify/lib/ path. Repeat-install is idempotent: cp -f
    # overwrites in place.
    HOOKS_DIR="${HOME}/.claude/orchestrator-hooks"
    HOOKS_PAYLOAD=""
    HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
    HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
    HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/lifecycle/before-commit.sh"
    HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/lifecycle/after-verify-sync.sh"

    hooks_staged=0
    if [ "$DRY_RUN" = "1" ]; then
      for src in $HOOKS_PAYLOAD; do
        echo "would_write=${HOOKS_DIR}/$(basename "$src")"
        hooks_staged=$((hooks_staged + 1))
      done
      echo "would_write=${HOOKS_DIR}/MANIFEST"
    else
      mkdir -p "$HOOKS_DIR"
      for src in $HOOKS_PAYLOAD; do
        if [ ! -f "$src" ]; then
          echo "FAIL: hooks payload source missing: $src" >&2
          exit 1
        fi
        cp -f "$src" "${HOOKS_DIR}/$(basename "$src")"
        hooks_staged=$((hooks_staged + 1))
      done
      # Write MANIFEST listing staged basenames (used by --uninstall to remove
      # only files the installer placed; user-authored siblings are preserved).
      : > "${HOOKS_DIR}/MANIFEST"
      for src in $HOOKS_PAYLOAD; do
        echo "$(basename "$src")" >> "${HOOKS_DIR}/MANIFEST"
      done
      echo "MANIFEST" >> "${HOOKS_DIR}/MANIFEST"
      echo "hooks_staged=${hooks_staged} dir=${HOOKS_DIR}"
    fi
    ```

    Notes for the implementer:
    - `HOOKS_PAYLOAD` is a space-delimited string iterated via `for src in $HOOKS_PAYLOAD`. This is bash 3.2 safe — no array required. The strings contain no spaces (paths under `${REPO_ROOT}` which is computed from `cd $(dirname $0)/../..` and `pwd` and is not expected to contain spaces; if the consumer's repo lives at a path with spaces, the installer's existing `$REPO_ROOT` resolution would already break — out of scope for T03).
    - Each line contains ≤ 2 connectors per AD-19 + AP-009. Multi-statement bodies use newlines, not `;`-chaining.
    - The MANIFEST format is one filename per line, plus a final `MANIFEST` line listing itself (so uninstall removes the manifest too). Plain text; no schema.

3. Extend the `--uninstall` block (current lines ~91–158) to remove the staged hooks payload BEFORE invoking `settings-merge.sh uninstall`. Insert verbatim:

    ```bash
    # Remove staged hooks payload (M028/P02/T03 — only files listed in MANIFEST).
    HOOKS_DIR="${HOME}/.claude/orchestrator-hooks"
    hooks_removed_p02=0
    if [ -f "${HOOKS_DIR}/MANIFEST" ]; then
      while IFS= read -r staged_name; do
        target="${HOOKS_DIR}/${staged_name}"
        if [ -f "$target" ]; then
          rm -f "$target"
          hooks_removed_p02=$((hooks_removed_p02 + 1))
        fi
      done < "${HOOKS_DIR}/MANIFEST"
      # Remove the dir if empty (preserves user-authored siblings).
      if [ -d "$HOOKS_DIR" ]; then
        rmdir "$HOOKS_DIR" 2>/dev/null || true
      fi
    fi
    ```

    Notes:
    - `rmdir` (POSIX) fails if the dir is non-empty — exactly the right behavior; on user-authored siblings, the dir survives.
    - The `2>/dev/null || true` swallows the rmdir-failed-because-non-empty diagnostic; the `|| true` is one connector, AP-009-clean.
    - The uninstall path's existing `hooks_removed` count (for settings.json entries) is separate from `hooks_removed_p02` (for staged files); add the latter to the final `UNINSTALLED:` line.

4. Modify `scripts/util/settings-merge.sh`'s python3 merge body to use the `(event, matcher, command)` tuple as the dedup key. The current python block (around line 100+) iterates fragment leaves; locate the `command-string` match and replace it with tuple match. Verbatim shape (sketch — implementer adapts to existing python style):

    ```python
    # Dedup key: (event, matcher, command). _orchestrator_managed scope only.
    def existing_keys(target_hooks):
        keys = set()
        for event, wrappers in (target_hooks or {}).items():
            for wrapper in (wrappers or []):
                matcher = wrapper.get("matcher", "") or ""
                for leaf in wrapper.get("hooks", []):
                    if leaf.get("_orchestrator_managed") is True:
                        cmd = leaf.get("command", "")
                        keys.add((event, matcher, cmd))
        return keys

    target_keys = existing_keys(target.get("hooks", {}))
    for event, wrappers in (fragment.get("hooks", {}) or {}).items():
        for wrapper in (wrappers or []):
            matcher = wrapper.get("matcher", "") or ""
            new_leaves = []
            for leaf in wrapper.get("hooks", []):
                cmd = leaf.get("command", "")
                if leaf.get("_orchestrator_managed") is True:
                    if (event, matcher, cmd) in target_keys:
                        continue  # dup — skip
                    target_keys.add((event, matcher, cmd))
                new_leaves.append(leaf)
            if not new_leaves:
                continue
            # ... existing wrapper-merge logic appends new_leaves ...
    ```

    Implementer notes:
    - The existing python block already implements per-event-array deep-merge. T03's change is narrow: replace the `command-string` dedup with the tuple-based dedup. Preserve all other behavior (cascade cleanup on uninstall, byte-identical write of unchanged keys, `--force` bypass, exit codes).
    - The `--force` flag still bypasses the dedup (so manual edits stripping the managed tag can be recovered). Preserve that branch.
    - User-authored entries (no `_orchestrator_managed: true`) are NEVER deduplicated against orchestrator entries — they pass through untouched.
    - Update the algorithm comment at the top of `settings-merge.sh` (around line 14–22) to document the new tuple key.

5. Author `scripts/verify/m028/p02-hooks-payload-staged.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Creates an isolated HOME under `${TMPDIR:-/tmp}/p02-payload-test-$$` and runs the installer with `HOME=<isolated>` set inline. Pattern: `tmp_home="${TMPDIR:-/tmp}/p02-payload-$$"; mkdir -p "$tmp_home"; HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --project-dir "$tmp_home" >/dev/null 2>&1` (the `--project-dir` arg keeps the runtime staging out of the real project tree).
    - **Note**: invoking the full installer in a verifier is heavy. If the installer's runtime-staging step (stage 4.5 — copies `scripts/`, `templates/`, `references/`, `commands/` into the project) creates a ~100MB artifact, the verifier becomes slow. Mitigation: invoke the installer with `--dry-run` and assert on `would_write=` lines for the hooks-dir payload; AND run a separate non-`--dry-run` invocation in a deeper isolated tmp dir for the actual payload-copy proof. Two-mode verifier: `--dry-run` proves the would-write list is correct; non-`--dry-run` proves the files actually land. Implementer chooses cleanest layout; both modes are within ≤ 10 lines of straight-line bash if reused via a per-mode function.
    - Asserts the expected files exist post-install: `pre-bash-shape-guard.sh`, `shape-classifier.sh`, `before-commit.sh`, `after-verify-sync.sh`, `MANIFEST` — five `[ -f "${tmp_home}/.claude/orchestrator-hooks/<name>" ]` checks.
    - Asserts the MANIFEST contains exactly five lines (four payload + MANIFEST itself): `manifest_lines="$(wc -l < "${tmp_home}/.claude/orchestrator-hooks/MANIFEST" | tr -d ' ')"; [ "$manifest_lines" = "5" ]`.
    - Cleans up the isolated tmp dir (`rm -rf "$tmp_home"`).
    - On all-pass, emit `PASS: hooks payload staged at orchestrator-hooks/ (5 files, MANIFEST present)` to stdout and exit 0.

6. Run `bash scripts/util/run-probe.sh scripts/verify/m028/p02-hooks-payload-staged.sh`. Confirm `PASS`. If FAIL, iterate on the installer's hooks-payload stage — do not weaken the verifier.

7. Smoke-test the dedup change manually: against an isolated HOME, run the installer twice and compare `${HOME}/.claude/settings.json` SHA-256 across the two runs. If the file differs, the python dedup logic is incorrect — iterate. (T05's `install-roundtrip.sh` formalizes this; T03's smoke-test is a sanity check before handing off.)

## Must-Haves

This task addresses three phase Truths:
- "The installer copies the full hooks payload [...] into `~/.claude/orchestrator-hooks/` on a fresh install."
- "`settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file." (T03 lands the dedup; T05 runs the byte-equality gate.)
- "`bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes." (T03 lands the staged-payload removal; T05 runs the byte-equality gate.)

It produces the verifier `scripts/verify/m028/p02-hooks-payload-staged.sh` that gates the staged-payload Truth.

## Verification

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/p02-hooks-payload-staged.sh
```

## Notes

Expected output is a single line `PASS: hooks payload staged at orchestrator-hooks/ (5 files, MANIFEST present)`.

The dedup key change (`command` only → `(event, matcher, command)`) is the load-bearing fix for the operator's M018-close 5-Stop-dupes / 7-PreToolUse-dupes regression. Under the old key, repeat-install produced apparent dedup but the wrapper grouping mismatched, leaving stale wrappers around. Under the tuple key, every (event, matcher, command) triple is unique within the orchestrator-managed scope.

The MANIFEST file is the install-side counterpart to M025's `_orchestrator_managed: true` tag in settings.json — it makes `--uninstall` deterministic for the staged-files branch (vs. the settings.json branch which uses the JSON tag).

The dedup change is API-compatible with M025's existing uninstall cascade. The cascade still operates on `_orchestrator_managed: true` flags within the JSON; T03 only changes which fragment-leaves get appended on merge. Byte-equality on round-trip (T05) is the proof.

## Inputs

### From Previous Tasks

- `scripts/hooks/pre-bash-shape-guard.sh` (from T01)
  - Key API: hook stdin protocol (Claude Code JSON in, exit 0/0+stdout/2 out). T03 stages this file but does not call into it.
  - Self-location contract: hook locates classifier as `${HOOK_DIR}/shape-classifier.sh` first. T03 stages classifier alongside hook in `${HOOKS_DIR}` so this resolution succeeds at runtime.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (from T02)
  - Key API: `--hook-config` mode emits JSON fragment to stdout. T03's installer captures this stdout and feeds it to `settings-merge.sh merge`.
  - Emission shape: every leaf carries absolute `bash ${HOME}/.claude/orchestrator-hooks/<name>.sh` and `_orchestrator_managed: true`. T03's merge dedup operates on this shape.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — M025 installer. T03 inserts new stage 3' after the existing `--register` block; extends the `--uninstall` block.
- `scripts/util/settings-merge.sh` — M025 merge helper. T03 modifies the python3 merge body's dedup key.
- `scripts/verify/lib/shape-classifier.sh` — M021 classifier library. T03 stages this into `${HOOKS_DIR}/shape-classifier.sh` so the post-T01 self-locating hook finds its sibling at runtime.
- `scripts/lifecycle/before-commit.sh` — M025 lifecycle script. Staged unmodified.
- `scripts/lifecycle/after-verify-sync.sh` — M025 lifecycle script. Staged unmodified.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: the new verifier `p02-hooks-payload-staged.sh` is flat single-file. The installer's hooks-payload stage uses a `for src in $HOOKS_PAYLOAD` loop, not an array; the inline body is multi-line, not `;`-chained. No plain `( ... )` subshells, no `$(...)` containing pipes, no process substitution.
- **bash 3.2 + POSIX sh (CON-2)**: every line runs on bash 3.2. No associative arrays. No `mapfile`/`readarray`. The `HOOKS_PAYLOAD` "list" is space-delimited string iteration (bash 3.2 safe).
- **No new runtime deps (CON-6)**: the installer adds no new dependency. The settings-merge dedup uses python3 (already a baseline per M025/P01/T02). No `jq`.
- **M025 reversibility (CON-4)**: install → install → uninstall byte-equality is the SC-2 contract. T03 lands the install-side dedup; T05 lands the byte-equality gate. T03's smoke-test (Step 7) is a sanity check, not the formal proof.
- **Knowledge-layer boundary (M025 vs M028)**: T03 EXTENDS `settings-merge.sh` with install-side dedup. It does NOT redefine the `_orchestrator_managed: true` tag, the wrapper-grouping convention, or the cascade-cleanup semantics on uninstall. M025 owns those; M028 keys on them.
- **Manifest-driven uninstall**: the staged-files removal walks `MANIFEST` only — never `find ... -delete` against the dir. User-authored siblings (if any) are preserved.
- **Idempotent install (FR-5)**: repeat install is byte-identical. Verified by T05's pinned-sha gate. T03's payload-copy uses `cp -f` (always overwrites) so file-bytes are stable across reruns; the settings-merge dedup ensures settings.json is stable.
