---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M032"
name: "Apply identical FR-2 migration to install-codex.sh + install-cursor.sh — symmetry pass across all three installers"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `packaging/install/install-claude-code.sh` no longer contains `RUNTIME_DIRS=` and dispatches the project-asset stage through the three T01-authored libraries (verified by `bash tools/verify/m032-p01-install-cc-byte-identical.sh`).
- T01 complete (transitively via T02): the three lifecycle helpers (`read-project-assets.sh`, `install-asset-mode.sh`, `install-collision-check.sh`) exist and are exercised by T02 (verified by the T01/T02 verifiers).
- `packaging/install/install-codex.sh` exists and contains `RUNTIME_DIRS="scripts templates references commands"` at approximately line 236 (verified by `grep -q 'RUNTIME_DIRS=' packaging/install/install-codex.sh`).
- `packaging/install/install-cursor.sh` exists and contains the same `RUNTIME_DIRS=` block at approximately line 245 (verified by `grep -q 'RUNTIME_DIRS=' packaging/install/install-cursor.sh`).
- `tools/verify/fixtures/m032-pre-m032-golden.txt` exists from T02 (used by the parity verifier to confirm codex/cursor produce the same per-dir file counts as claude-code).

## Description

T03 is the symmetry pass that closes FR-2 across all three installers. The codex and cursor installers carry the same `RUNTIME_DIRS` block as claude-code (verified at T01 entry: lines 236-271 in codex, 245-280 in cursor). T03 replaces those blocks with the same `read-project-assets.sh`-driven dispatch landed in T02, reusing the libraries from T01 — no new library code in T03.

The codex and cursor installer bodies are otherwise functionally distinct from claude-code (each has its own skill-registration, hook-payload, settings-merge behavior). The project-asset staging block is the ONLY block that becomes line-for-line identical across all three installers after T03.

The `m032-p01-installers-parity.sh` verifier T03 ships asserts the parity invariant: it extracts the project-asset staging block from each installer (delimited by the `# --- 4.5 Stage runtime payload via project_assets:` comment header and the closing `staged=$runtime_staged files manifest=$manifest_file` echo) and runs `diff` between the three extracts, asserting they are byte-identical.

## Steps

1. **Read `packaging/install/install-codex.sh:230-271`** carefully. Confirm the block matches the structure replaced in T02 (different surrounding context — codex has no hook-payload section, only skill-registration — but the project-asset block itself is structurally identical to claude-code's).

2. **Apply the same replacement to `install-codex.sh`** that T02 applied to `install-claude-code.sh`. The replacement block is line-for-line the same as T02's step 3 replacement. Only the surrounding context (the lines before `# --- 4.5 Stage runtime payload via project_assets:` and after the closing `staged=` echo) differs between the three installers.

3. **Read `packaging/install/install-cursor.sh:240-281`** carefully. Confirm the block matches.

4. **Apply the same replacement to `install-cursor.sh`**. Cursor's installer has one extra constraint: `--project-dir` is REQUIRED (not optional like claude-code/codex). The project-asset stage block does not interact with that constraint — the constraint is enforced upstream of the project-asset stage in cursor's existing flag-parsing loop.

5. **Add `--asset-mode-override` flag parsing** to both `install-codex.sh` and `install-cursor.sh` flag-parsing loops. The flag semantics are identical to T02's claude-code addition.

6. **Verify byte-identical project-asset staging blocks across all three installers**:

```bash
# Extract the project-asset staging block from each installer (between the
# canonical comment header and the closing `staged=` echo). Compare via diff.
for installer in install-claude-code.sh install-codex.sh install-cursor.sh; do
  awk '/^# --- 4.5 Stage runtime payload via project_assets:/{p=1} p; /^echo "staged=\$runtime_staged files manifest=\$manifest_file"$/{p=0}' \
    "packaging/install/$installer" > "/tmp/m032-block-$installer.txt"
done
diff -u /tmp/m032-block-install-claude-code.sh.txt /tmp/m032-block-install-codex.sh.txt
diff -u /tmp/m032-block-install-claude-code.sh.txt /tmp/m032-block-install-cursor.sh.txt
```

   Both `diff` invocations MUST produce no output (zero diff). If they don't, fix the codex/cursor block to match claude-code exactly.

7. **Run dry-run installs against a temp fixture for both codex and cursor**, verify per-runtime-dir file counts match the golden in `tools/verify/fixtures/m032-pre-m032-golden.txt` (CON-4 byte-identical contract holds across all three installers, not just claude-code).

8. **Author `tools/verify/m032-p01-installers-parity.sh`**. The verifier:
   - Asserts `! grep -q 'RUNTIME_DIRS=' packaging/install/install-claude-code.sh`.
   - Asserts `! grep -q 'RUNTIME_DIRS=' packaging/install/install-codex.sh`.
   - Asserts `! grep -q 'RUNTIME_DIRS=' packaging/install/install-cursor.sh`.
   - Asserts `grep -q 'read-project-assets.sh' packaging/install/install-claude-code.sh` (and same for codex + cursor).
   - Extracts the project-asset staging block from all three installers via `awk` (same delimiters as step 6) and runs `diff -q` between them; asserts zero diff.
   - Runs dry-run installs for codex and cursor against `mktemp -d` fixtures and confirms per-runtime-dir `would_write=` line counts match the golden.

## Must-Haves

- The literal token `RUNTIME_DIRS=` no longer appears in `install-codex.sh` (FR-2 across codex).
- The literal token `RUNTIME_DIRS=` no longer appears in `install-cursor.sh` (FR-2 across cursor).
- The project-asset staging block in all three installers is line-for-line identical (extractable by the `awk` delimiters in step 6, byte-equal under `diff`).
- All three installers source `scripts/lifecycle/read-project-assets.sh` and dispatch through `install-collision-check.sh` + `install-asset-mode.sh`.
- All three installers honor the `--asset-mode-override <copy|symlink>` flag identically.
- `bash tools/verify/m032-p01-installers-parity.sh` exits 0.
- Dry-run installs of codex and cursor produce per-runtime-dir file counts that match `tools/verify/fixtures/m032-pre-m032-golden.txt` (CON-4 byte-identical at `mode: copy`).

## Verification

```bash
bash tools/verify/m032-p01-installers-parity.sh
bash tools/verify/m032-p01-install-cc-byte-identical.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install-claude-code.sh` (post-T02 form)
  - Key API: the project-asset staging block landed in T02 step 3 — the exact lines T03 mirrors into codex and cursor.
- `tools/verify/fixtures/m032-pre-m032-golden.txt` (from T02)
  - Key API: per-runtime-dir file counts (`commands/ file_count=N`, etc.) that codex and cursor's dry-run output is asserted to match.
- T01 lifecycle helpers (`read-project-assets.sh`, `install-asset-mode.sh`, `install-collision-check.sh`) — invoked unchanged from T03.

### From Disk (Pre-existing)

- `packaging/install/install-codex.sh` (pre-T03 form: `RUNTIME_DIRS` block at 236-271).
- `packaging/install/install-cursor.sh` (pre-T03 form: `RUNTIME_DIRS` block at 245-280; `--project-dir` is REQUIRED in cursor).

## Constraints

- T03 MUST NOT modify any of the three lifecycle helpers from T01 (they are reused as-is).
- T03 MUST NOT modify `install-claude-code.sh` (T02 already landed the canonical migration there).
- The project-asset staging block in codex MUST be byte-identical to the staging block in claude-code AND cursor — not just functionally equivalent. This is the parity invariant the `m032-p01-installers-parity.sh` verifier asserts.
- The cursor installer's pre-existing `--project-dir is REQUIRED` enforcement MUST keep working byte-identically; the project-asset stage block does not interact with it.
- The codex and cursor installers' summary lines, exit-code conventions, and dry-run branching outside the project-asset stage MUST be unchanged from pre-T03 state.

## Expected Output

After T03 closes: none of the three installers contains `RUNTIME_DIRS=`; all three source the same lifecycle helpers and dispatch through the same project-asset staging block; `bash tools/verify/m032-p01-installers-parity.sh` exits 0 with `diff -q` reporting zero differences across the three extracted blocks; dry-run installs for codex and cursor produce file counts matching the pre-M032 golden. T04 then ships the SC-1 / SC-2 / SC-10 acceptance scripts that exercise the migration end-to-end against the shared `tests/fixtures/m032-fresh-project-fixture/`.
