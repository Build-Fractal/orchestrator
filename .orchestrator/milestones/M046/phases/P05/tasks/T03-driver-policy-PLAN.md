---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M046"
name: "Driver per-run policy composition + env export"
depends_on: [T02]
---

## Prerequisites

- T01 complete: `scripts/hooks/unattended-protected-surface.txt` exists (the committed manifest this task reads at composition time) and the hook's policy-directive vocabulary (`allow_path`/`readonly_path`/`allow_tool`/`allow_bash`) is fixed.
- `scripts/lifecycle/unattended-envelope.sh` (exists, P04 sourceable library) — this task adds one function.
- `scripts/lifecycle/self-continue-drive.sh` (exists, P04 driver) — this task adds a pre-spawn composition call + one env export.

## Description

Give the driver a real, per-run write/tool-scope policy so the T01 hook has something to enforce.
Per Decision D018 the writable allowlist is only knowable at spawn time (it is the active project
root), so the driver composes `<milestone-dir>/.self-continue-scope-policy` before each spawn from
the committed generic manifest + the project root + the milestone-specific SC surfaces, and
exports its path into the child. The composition function lands in the P04 sourceable envelope
library (keeps the driver diff minimal — the P04 seam precedent).

**Critical path facts** (from reading `self-continue-drive.sh`):
- `REPO_ROOT` inside the driver = `$SCRIPT_DIR/..` = `<repo>/scripts` (NOT the repo root).
- Therefore the committed manifest is at `"$REPO_ROOT/hooks/unattended-protected-surface.txt"`
  and the true project root is `PROJECT_ROOT="$(cd "$REPO_ROOT/.." && pwd)"`.
- The driver already exports `ORCHESTRATOR_UNATTENDED=1` and other env into the child in
  `run_child()` (lines 144–150). The new export sits in that same block.
- The pre-spawn envelope block runs under `if [ "$UNATTENDED" = "true" ]` (lines 210–229). The
  policy composition goes there, right after the reserve write, so the file exists before spawn.

## Steps

1. **`scripts/lifecycle/unattended-envelope.sh`** — add a function `envelope_write_scope_policy`:
   ```
   # envelope_write_scope_policy <policy-file> <project-root> <manifest-file> <milestone-dir> <roadmap-file> <phase-plan-file>
   # Composes the per-run default-DENY policy atomically (temp+rename). Emits:
   #   allow_path <project-root>/                 (writable work surface = project root)
   #   readonly_path <project-root>/<glob>        for each non-comment line in the manifest
   #   readonly_path <roadmap-file>               (milestone SC surface, if it exists)
   #   readonly_path <phase-plan-file>            (phase-grain SC, if it exists)
   #   readonly_path <policy-file>                (no self-widening)
   #   # P07 FORWARD-SLOT: readonly_path <milestone-dir>/.self-continue-attempts-ledger
   #                       (emitted as a readonly_path line only once that file exists;
   #                        emit it as a comment placeholder now)
   # No allow_tool line => MCP default-DENY (Decision D019). No allow_bash line => only the
   # hook's dangerous-class Bash denylist applies.
   envelope_write_scope_policy() {
     _pf="$1"; _root="$2"; _manifest="$3"; _mdir="$4"; _road="$5"; _plan="$6"
     _tmp="$_pf.tmp.$$"
     {
       printf 'allow_path %s/\n' "$_root"
       if [ -r "$_manifest" ]; then
         while IFS= read -r _ln; do
           case "$_ln" in ''|'#'*) continue ;; esac
           printf 'readonly_path %s/%s\n' "$_root" "$_ln"
         done < "$_manifest"
       fi
       [ -e "$_road" ] && printf 'readonly_path %s\n' "$_road"
       [ -e "$_plan" ] && printf 'readonly_path %s\n' "$_plan"
       printf 'readonly_path %s\n' "$_pf"
       _ledger="$_mdir/.self-continue-attempts-ledger"
       if [ -e "$_ledger" ]; then
         printf 'readonly_path %s\n' "$_ledger"
       else
         printf '# P07 FORWARD-SLOT readonly_path %s (added when P07 ledger exists)\n' "$_ledger"
       fi
     } > "$_tmp"
     mv -f "$_tmp" "$_pf"
   }
   ```
   (Note: the manifest lines already end in `/` for dir-prefixes like `tools/verify/`; the
   `%s/%s` concatenation yields `<root>/tools/verify/` — correct prefix form.)

2. **`scripts/lifecycle/self-continue-drive.sh`** — two edits, both under `UNATTENDED=true` only:
   a. Near the other dotfile-path resolutions (after line 176), add:
      ```
      PROJECT_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
      MANIFEST_FILE="$REPO_ROOT/hooks/unattended-protected-surface.txt"
      SCOPE_POLICY="$MILESTONE_DIR/.self-continue-scope-policy"
      ROADMAP_FILE="$MILESTONE_DIR/$(basename "$MILESTONE_DIR")-ROADMAP.md"
      ```
      (The roadmap file for M046 is `.../M046/M046-ROADMAP.md`; `basename "$MILESTONE_DIR"` = the
      milestone id, so this resolves it generically. The active phase plan is not known to the
      driver without deriving it; pass an empty string / the milestone dir's roadmap is the
      primary SC surface. To also protect the active phase plan generically, pass
      `ROADMAP_FILE` for `<roadmap-file>` and an empty arg for `<phase-plan-file>` — the function
      guards each with `[ -e ]` so an empty/absent path is simply skipped.)
   b. In the pre-spawn block, immediately after the `envelope_reserve` call (line ~225), add:
      ```
      envelope_write_scope_policy "$SCOPE_POLICY" "$PROJECT_ROOT" "$MANIFEST_FILE" \
        "$MILESTONE_DIR" "$ROADMAP_FILE" ""
      ```
   c. In `run_child()`'s unattended env block (after `ORCHESTRATOR_UNATTENDED=1 \` at line 145),
      add one line:
      ```
      ORCHESTRATOR_UNATTENDED_POLICY="$SCOPE_POLICY" \
      ```
      The attended branch (`ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@"`, line 157) is UNCHANGED — no
      policy, no export. FR-17 parity preserved.

3. Author `tools/verify/m046-p05-driver-policy.sh` (project-owned). It exercises the composition
   function + the driver wiring without spawning a real child:
   - `set -u`; `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO_ROOT"`.
   - **Function leg**: source `scripts/lifecycle/unattended-envelope.sh`; make a `mktemp -d`
     scratch as a fake milestone dir + a fake project root; call `envelope_write_scope_policy`
     with the real manifest `scripts/hooks/unattended-protected-surface.txt`; assert the emitted
     policy file contains `allow_path <root>/`, a `readonly_path <root>/tools/verify/` line, a
     `readonly_path <root>/scripts/verify/` line, a `readonly_path <root>/specs/` line, a
     `readonly_path <root>/scripts/hooks/` line, a `readonly_path <policy-file>` self-line, the
     `P07 FORWARD-SLOT` comment, and NO `allow_tool` line (MCP deny) and NO `allow_bash` line.
   - **Driver static leg** (grep the driver source, no spawn): assert
     `self-continue-drive.sh` contains `envelope_write_scope_policy`, contains
     `ORCHESTRATOR_UNATTENDED_POLICY`, and that the `ORCHESTRATOR_UNATTENDED_POLICY` line sits
     inside the unattended `run_child` env block (adjacent to `ORCHESTRATOR_UNATTENDED=1`) — a
     simple `grep -A2 'ORCHESTRATOR_UNATTENDED=1' ... | grep -q ORCHESTRATOR_UNATTENDED_POLICY`
     style adjacency check, expressed as separate `grep` commands to stay AD-19-safe inside the
     verifier (verifiers may contain any shape; only Truth `Check:` lines are shape-constrained).
   - **Attended-parity leg**: assert the attended child spawn line
     (`ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" >/dev/null 2>&1`) does NOT carry
     `ORCHESTRATOR_UNATTENDED_POLICY` (grep the attended branch region and assert absence).
   - Final `SUMMARY: pass=<p> fail=<f>`; exit 0 iff `fail==0`.

## Must-Haves

- Truth: driver composes the per-run policy (allow_path project-root + readonly_path manifest + roadmap + policy-file self-line + MCP deny) and exports `ORCHESTRATOR_UNATTENDED_POLICY`; attended path composes/exports none.
- Artifact: `tools/verify/m046-p05-driver-policy.sh` (min 40 lines, contains "ORCHESTRATOR_UNATTENDED_POLICY").
- Key Link: `scripts/lifecycle/unattended-envelope.sh` → `unattended-protected-surface.txt`.

## Verification

```bash
bash tools/verify/m046-p05-driver-policy.sh
```

## Inputs

### From Previous Tasks
- `scripts/hooks/unattended-protected-surface.txt` (from T01) — the manifest read at composition; project-relative dir-prefixes ending in `/`.
- The hook's policy vocabulary (from T01): `allow_path`/`readonly_path`/`allow_tool`(absent⇒MCP-deny)/`allow_bash`.

### From Disk (Pre-existing)
- `scripts/lifecycle/unattended-envelope.sh` — P04 library; add the function beside `envelope_reserve`/`envelope_reconcile`. POSIX-sh function style, no bashisms.
- `scripts/lifecycle/self-continue-drive.sh` — `REPO_ROOT` = `<repo>/scripts`; dotfile-path block at 173–176; pre-spawn block 210–229 (`envelope_reserve` at ~225); `run_child` unattended env block 144–150; attended branch line 157.

## Constraints

- **FR-17 attended parity is load-bearing**: the attended path MUST NOT compose a policy or export
  `ORCHESTRATOR_UNATTENDED_POLICY`. All new logic is guarded by `UNATTENDED=true` / lives in the
  unattended `run_child` branch. The P04 `m046-p04-attended-parity.sh` verifier greps this driver;
  keep the attended-region diff at zero.
- Atomic policy write (temp+rename) per the Edge Cases marker-atomicity discipline.
- CON-2: `auto-loop.sh` untouched.

## Expected Output

`bash tools/verify/m046-p05-driver-policy.sh` prints per-assertion pass lines and
`SUMMARY: pass=N fail=0`, exit 0.
