---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M035"
name: "managed-gitignore-block"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed — all three installers are bash 3.2-safe with exit-status-propagating shapes.
- `packaging/install/install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh` exist.
- `scripts/state/resolve-root.sh` exists (used to determine where `.orchestrator/install-meta.txt` actually lives in the consumer project).

## Description

FR-6 / SC-6: every installer must append a managed marker block to `<PROJECT_DIR>/.gitignore` covering installer-managed sidecars (minimum: `.orchestrator/install-meta.txt`). The block is delimited by `# >>> orchestrator-managed: gitignore >>>` / `# <<< orchestrator-managed: gitignore <<<`. Re-runs replace the block contents in place — exactly one block must remain after any number of re-runs (idempotent).

This task adds an `emit_managed_gitignore_block()` helper to each installer (or factors it into a shared helper at `scripts/lifecycle/emit-managed-gitignore.sh` and invokes it from each installer — implementation choice below). It runs during the install pass after `install-meta.txt` is written. It does not run on `--uninstall` or `--repair`.

The block contents at v1:

```
# >>> orchestrator-managed: gitignore >>>
# Managed by packaging/install/install-{claude-code,codex,cursor}.sh.
# Sidecars listed here are installer-owned, regenerated on every install,
# and should not be committed. Edits inside this block are overwritten on
# the next install run; edits outside the block are preserved.
.orchestrator/install-meta.txt
# <<< orchestrator-managed: gitignore <<<
```

The implementation choice is: **factor the helper into `scripts/lifecycle/emit-managed-gitignore.sh`** and have each installer invoke it. This avoids triplicating the replace-in-place logic, keeps the helper unit-testable, and makes future block-content additions (P05's `.previous-version` rollback marker would extend this list) a one-file edit.

## Steps

1. **Author the shared helper** at `scripts/lifecycle/emit-managed-gitignore.sh`. Contract:
   - Usage: `bash scripts/lifecycle/emit-managed-gitignore.sh --project-dir <path> [--dry-run] [--block-content <file>]`.
   - Reads `<path>/.gitignore` if present; else creates it.
   - Looks for an existing `# >>> orchestrator-managed: gitignore >>>` opener and matching `# <<< orchestrator-managed: gitignore <<<` closer.
   - **No block found**: appends the canonical block (separated from prior content by a single blank line if the file is non-empty and doesn't already end in a blank line).
   - **Block found**: replaces the line range in place (everything from the opener line through the closer line) with the canonical block contents. Lines outside the block are preserved verbatim.
   - **Multiple blocks found** (defensive): collapses to one — keeps the first opener, deletes the second-and-later block ranges.
   - `--dry-run` writes nothing; emits `would_write=<path>/.gitignore` to stdout.
   - Bash 3.2 compatible. No `mapfile`, no `<(...)`, no associative arrays. Use `awk` or a temp-file rewrite.
   - Exit 0 on success; non-zero on I/O error with `FAIL:` prefix on stderr.

2. **Wire the helper into each installer**. After the existing `install-meta.txt` write step (search each installer for `install-meta.txt` to locate the insertion point; the line that writes the file is the right anchor — call the helper immediately after), add:

   ```bash
   # FR-6 / SC-6: managed .gitignore block for installer-owned sidecars.
   if [ "$DRY_RUN" -eq 0 ]; then
     bash "$REPO_ROOT/scripts/lifecycle/emit-managed-gitignore.sh" --project-dir "$PROJECT_DIR"
     _emit_rc=$?
     if [ "$_emit_rc" -ne 0 ]; then
       echo "FAIL: emit-managed-gitignore.sh exited $_emit_rc" >&2
       exit "$_emit_rc"
     fi
   else
     bash "$REPO_ROOT/scripts/lifecycle/emit-managed-gitignore.sh" --project-dir "$PROJECT_DIR" --dry-run
   fi
   ```

   Apply identically across all three installers. The helper invocation is a single `bash <script>` call — AP-009 compliant.

3. **Skip the helper on `--uninstall` and `--repair`**. The block stays in `.gitignore` after uninstall (consumer can remove manually if desired); `--repair` is for orchestrator-state repair, not for `.gitignore` re-emission. The wiring in step 2 sits inside the install path only.

4. **Author the project-owned shape verifier** at `tools/verify/m035-p00-managed-gitignore.sh`. The verifier:
   - Stages a fresh project fixture under `$(mktemp -d)` (no pre-existing `.gitignore`). Invokes `bash packaging/install/install-claude-code.sh --project-dir <fixture> --dry-run`. Asserts the dry-run emits `would_write=<fixture>/.gitignore` line. Expected: dry-run path matches.
   - Stages a second fixture (no pre-existing `.gitignore`). Invokes `bash packaging/install/install-claude-code.sh --project-dir <fixture>` (real run). Asserts `<fixture>/.gitignore` exists, contains exactly one `>>> orchestrator-managed: gitignore >>>` opener, contains `.orchestrator/install-meta.txt` inside the block.
   - Stages a third fixture with a *pre-existing* `.gitignore` containing user content like `node_modules/`. Runs the installer; asserts the user content is preserved AND the managed block is appended.
   - Stages a fourth fixture, runs the installer twice. Asserts exactly one managed block remains (idempotency, SC-6's load-bearing assertion).
   - Repeats stages 2–4 with `install-codex.sh` and `install-cursor.sh` to confirm parity.
   - Prints `PASS: m035-p00-managed-gitignore (4-fixture battery × 3 installers green; idempotent)` or `FAIL: …`.
   - Bash 3.2 compatible.

5. **Run the verifier locally** to confirm green.

## Must-Haves

This task addresses the phase must-have:

- "Each of the three installers emits a `# >>> orchestrator-managed: gitignore >>>` … marker block … and re-runs replace the block contents in place leaving exactly one block (idempotent)."

## Verification

```bash
bash tools/verify/m035-p00-managed-gitignore.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install-claude-code.sh` (from T01)
  - Key API: `--project-dir <path>`, `--dry-run`, `--force`, `--uninstall`, `--repair` flags. T02 inserts the helper invocation after the `install-meta.txt` write step.
  - Key types: shell variables `$DRY_RUN` (0|1), `$PROJECT_DIR` (absolute path), `$REPO_ROOT` (absolute path).
- `packaging/install/install-codex.sh` (from T01) — same API surface as install-claude-code.sh.
- `packaging/install/install-cursor.sh` (from T01) — same API surface as install-claude-code.sh.

### From Disk (Pre-existing)

- `scripts/state/resolve-root.sh` — used internally by installers to resolve `.orchestrator/` location; T02 does not call it directly but its result is the target of the gitignore entry.

## Constraints

- Bash 3.2 + POSIX-sh compatibility for the helper and installer wiring.
- AP-009 shape-guard discipline: helper invocation is a single `bash <script>` call; the helper itself uses awk or temp-file rewrite, not `<(...)` or compound chains.
- Idempotency is the load-bearing acceptance — SC-6 specifically asserts "Re-running the installer leaves the block count at exactly 1."
- The block must be readable enough that an operator who opens `.gitignore` understands what the markers mean — the canonical block content above includes a 3-line explanatory comment.
- Do not touch the `.gitignore` outside the marker block. User content above and below must be preserved verbatim.

## Expected Output

`bash tools/verify/m035-p00-managed-gitignore.sh` exits 0 with stdout: `PASS: m035-p00-managed-gitignore (4-fixture battery × 3 installers green; idempotent)`.

## Notes

- **Future-proofing for P05**: P05's rollback marker (`.orchestrator/.previous-version`, FR-12) will extend the block contents. The helper's `--block-content <file>` option is a forward hook — at v1 the canonical block is hard-coded; P05 plan-phase decides whether to factor the content into a sibling file or extend the helper's hard-coded list. Either way, T02's helper is the modification site.
- **Expected verifier output** (informational, not in `## Verification`): `PASS: m035-p00-managed-gitignore (4-fixture battery × 3 installers green; idempotent)`.
