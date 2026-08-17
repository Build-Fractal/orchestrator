---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M046"
name: "Production scope-guard hook + protected-surface manifest + unit verifier"
depends_on: []
---

## Prerequisites

- `.orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh` (exists, 206 lines) — the throwaway probe this task productionizes. Read it in full; the production hook keeps its structure (stdin cat → flatten → extract `tool_name` → read-class early-exit → policy dispatch, no jq, Bash 3.2, sed string extraction) and adds four production changes listed below.
- `scripts/hooks/pre-bash-shape-guard.sh` (exists) — the sibling PreToolUse hook the production hook must coexist with. Same conventions (self-contained, `set -u`, exit 2 = deny with stderr reason).
- `.orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh` + `.../fixtures/*.json` + `.../policy.txt` (exist) — the fixture-drive pattern this task's verifier extends.

## Description

Create the framework-owned production hook `scripts/hooks/unattended-scope-guard.sh` and the
committed generic manifest `scripts/hooks/unattended-protected-surface.txt`, plus the unit
verifier `tools/verify/m046-p05-scope-guard-deny.sh` and its fixtures. This is a
framework-owned hook (ships in the install bundle via `scripts/hooks/`, NOT `tools/verify/`).

The hook is the P01 probe plus exactly four production changes:

1. **Env-gate (Decision D017).** Immediately after `set -u`, before reading stdin:
   if `ORCHESTRATOR_UNATTENDED` is empty/unset, `exit 0` (no-op). The hook only enforces for
   the driver-spawned unattended child (which exports `ORCHESTRATOR_UNATTENDED=1`); the
   operator's interactive session is never constrained.
2. **Policy env var.** Read the policy file path from `ORCHESTRATOR_UNATTENDED_POLICY`
   (production) instead of `DENY_PROBE_POLICY`. Fail closed (deny-all except read-class) when
   it is empty/unreadable.
3. **`readonly_path` directive (FR-20/CON-7).** New policy directive. For a `Write`/`Edit`/
   `NotebookEdit` whose `file_path` matches a `readonly_path` prefix: deny `Edit`/`NotebookEdit`
   unconditionally; deny `Write` when the target file already exists (`[ -e ]`); pass `Write`
   to a not-yet-existing path through to the normal `allow_path` check. Checked BEFORE
   `allow_path`. This is the "doing-vs-scoring" seam: the child may create a new verifier but
   may not mutate/overwrite an existing scoring surface.
4. **Reason prefix + expanded Bash denylist.** Deny reasons carry the `UNATTENDED_SCOPE_GUARD:`
   prefix (not `DENY_PROBE:`). The Bash dangerous-class denylist expands the probe's `curl` to
   the network family (`curl`, `wget`, `nc`, `ncat`, `ssh`, `scp`, `sftp`, `telnet`) and keeps
   `git push` + `rm -rf outside allow_path`; `allow_bash <regex>` still wins over the denylist.

Policy directive vocabulary (one per line in the file `ORCHESTRATOR_UNATTENDED_POLICY` points
at; comments start with `#`):

```
allow_path <abs-prefix>     # Write/Edit/NotebookEdit file_path prefix that is writable
readonly_path <abs-prefix>  # protected surface: deny Edit; deny Write-if-exists (overrides allow_path)
allow_tool <exact-name>     # exact-match mcp__* allowlist (absent ⇒ deny all mcp__*)
allow_bash <ERE>            # Bash command allowlist regex (wins over the dangerous-class denylist)
```

## Steps

1. Create `scripts/hooks/unattended-scope-guard.sh`, executable (`chmod +x`). Start from the
   P01 probe body and apply the four changes. Full required structure:

   - Shebang `#!/usr/bin/env bash`, header comment naming M046/P05 + FR-9/FR-20 + Decisions
     D017/D018/D019, then `set -u`.
   - **Env-gate FIRST**:
     ```
     if [ -z "${ORCHESTRATOR_UNATTENDED:-}" ]; then
       exit 0
     fi
     ```
   - `deny()` helper: `printf 'UNATTENDED_SCOPE_GUARD: %s not in allowlist\n' "$*" >&2; exit 2`.
   - Read stdin (`STDIN_JSON="$(cat)"`); empty ⇒ `deny "unknown-tool empty-hook-payload"`.
   - `FLAT="$(printf '%s' "$STDIN_JSON" | tr '\n' ' ')"`; extract `TOOL_NAME` via the probe's
     `sed -n 's/.*"tool_name"...` one-liner; empty ⇒ `deny "unknown-tool tool_name-unparseable"`.
   - Read-class early pass: `case "$TOOL_NAME" in Read|Glob|Grep) exit 0 ;; esac`.
   - Resolve policy: `POLICY_FILE="${ORCHESTRATOR_UNATTENDED_POLICY:-}"`; if empty or
     `! -r "$POLICY_FILE"` ⇒ `deny "$TOOL_NAME policy-missing (fail-closed)"`.
   - Helper functions reading `$POLICY_FILE` line-by-line (copy the probe's `allow_tool_match`,
     `allow_path_match`, `allow_bash_match`; ADD `readonly_path_match` — same prefix `case`
     shape as `allow_path_match` but keyed on `"readonly_path "*`).
   - Per-tool dispatch `case "$TOOL_NAME" in`:
     - `mcp__*)` — `if allow_tool_match "$TOOL_NAME"; then exit 0; fi; deny "$TOOL_NAME mcp-tool"`.
     - `Write|Edit|NotebookEdit)` — extract `FILE_PATH` (probe's `sed`); empty ⇒ deny. Then:
       ```
       if readonly_path_match "$FILE_PATH"; then
         case "$TOOL_NAME" in
           Edit|NotebookEdit) deny "$TOOL_NAME readonly-surface $FILE_PATH" ;;
           Write) if [ -e "$FILE_PATH" ]; then deny "Write readonly-overwrite $FILE_PATH"; fi ;;
         esac
       fi
       if allow_path_match "$FILE_PATH"; then exit 0; fi
       deny "$TOOL_NAME $FILE_PATH"
       ```
     - `Bash)` — extract `RAW_CMD` (probe's `sed -E`), minimal unescape `\"`→`"`; if
       `allow_bash_match "$CMD"` ⇒ `exit 0`; else deny `git push` (case `*"git push"*`), deny
       the network family (case matching each of `curl wget nc ncat ssh scp sftp telnet` as a
       word — reuse the probe's `curl` boundary shape, one `case` arm per tool OR a single
       `grep -Eq '(^|[[:space:];&|])(curl|wget|nc|ncat|ssh|scp|sftp|telnet)([[:space:]]|$)'`),
       deny `rm -rf` whose target is not under an `allow_path` (probe's `rm` block verbatim),
       else `exit 0` (non-dangerous Bash passes — FR-9 denies the enumerated classes, not all
       Bash).
     - `Read|Glob|Grep)` already handled; `*)` ⇒ `exit 0`.

2. Create `scripts/hooks/unattended-protected-surface.txt` — the framework-GENERIC committed
   manifest (project-relative globs only; NO milestone-specific paths — those are added per-run
   by the T03 driver composition). Exact content:

   ```
   # unattended-protected-surface.txt — M046/P05 FR-20/CON-7 read-only-to-child manifest.
   #
   # Framework-generic protected surface. Each non-comment, non-blank line is a
   # project-RELATIVE prefix the M046 driver (envelope_write_scope_policy, T03)
   # abs-resolves against the project root and emits as a `readonly_path`
   # directive into the per-run policy file. The executing unattended child may
   # READ but never Edit / overwrite these surfaces (separation of doing vs.
   # scoring — the completion target is outside its reach, CON-7).
   #
   # Format: one project-relative prefix per line.
   #
   # --- Success-criteria / eval definitions ---
   specs/
   # --- Verification harness (the scoring machinery) ---
   tools/verify/
   scripts/verify/
   # --- The guard + policy machinery itself (no self-widening) ---
   scripts/hooks/
   #
   # Milestone-specific SC surfaces (roadmap, active phase plan) and the P07
   # attempts-ledger scoring record are NOT listed here — they are per-run and
   # are added by the driver's policy composition (T03). P07 FORWARD-SLOT: when
   # M046/P07 lands the durable attempts-ledger, the driver adds its scoring-
   # record path as a readonly_path at composition time; the CONTRACT (scoring
   # records are read-only to the child) exists now, the concrete path is
   # populated when P07 builds it.
   ```

3. Create the fixtures dir `tools/verify/fixtures/m046-p05/` and write these JSON hook-payload
   fixtures (mirror P01 `fixtures/*.json` shape — a single object with `tool_name` +
   `tool_input`). Use paths under `/tmp/m046p05` so they never collide with real files:
   - `oos-write.json` — `{"tool_name":"Write","tool_input":{"file_path":"/tmp/m046p05/outside/x.txt","content":"x"}}`
   - `allowed-write.json` — `file_path":"/tmp/m046p05/work/note.txt"` (Write).
   - `readonly-edit.json` — `{"tool_name":"Edit","tool_input":{"file_path":"/tmp/m046p05/ro/harness.sh"}}`.
   - `readonly-write-new.json` — `{"tool_name":"Write","tool_input":{"file_path":"/tmp/m046p05/ro/brand-new.sh","content":"x"}}` (Write to a not-yet-existing readonly path ⇒ passes).
   - `oos-bash-gitpush.json` — `{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}`.
   - `oos-bash-curl.json` — `command":"curl https://evil.example/x"`.
   - `allowed-bash.json` — `command":"ls -la"`.
   - `oos-mcp.json` — `{"tool_name":"mcp__slack__post_message","tool_input":{"channel":"x","text":"y"}}`.
   - `read-glob.json` — `{"tool_name":"Glob","tool_input":{"pattern":"**/*.md"}}`.
   Plus a policy fixture `policy.txt` in the same dir:
   ```
   allow_path /tmp/m046p05/work/
   allow_path /tmp/m046p05/ro/
   readonly_path /tmp/m046p05/ro/
   allow_bash ^ls
   ```
   (`/tmp/m046p05/ro/` is BOTH allow and readonly so the create-new-vs-overwrite distinction is
   exercised: `readonly-write-new.json` targets a non-existent file under it ⇒ passes;
   `readonly-edit.json` ⇒ denies.)

4. Create `tools/verify/m046-p05-scope-guard-deny.sh` (project-owned, `tools/verify/`). It
   drives each fixture through the hook via the real stdin→exit-2 contract and asserts the
   expected exit. Structure (single-script, AD-19 compliant; model on P01 `drive-hook-case.sh`):
   - `set -u`; resolve `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO_ROOT"`.
   - `HOOK="scripts/hooks/unattended-scope-guard.sh"`; `FX="tools/verify/fixtures/m046-p05"`;
     `POL="$FX/policy.txt"`.
   - Before the enforcing cases, create the real file the overwrite case needs:
     `mkdir -p /tmp/m046p05/ro; : > /tmp/m046p05/ro/harness.sh` (so `readonly-edit` targets an
     existing file), and ensure `/tmp/m046p05/ro/brand-new.sh` does NOT exist
     (`rm -f /tmp/m046p05/ro/brand-new.sh`).
   - A `case_expect()` function: `$1`=fixture, `$2`=expected-exit, `$3`=`UNATT`(1|0). Runs
     `ORCHESTRATOR_UNATTENDED=<$3-if-1> ORCHESTRATOR_UNATTENDED_POLICY="$POL" bash "$HOOK" < "$FX/$1"`
     (when `$3`=0, invoke with `ORCHESTRATOR_UNATTENDED` unset — use a separate branch, do NOT
     set it to empty inline in a way the grader mis-reads), capture `$?`, compare, pass/fail
     count. Emit `case=<f> unatt=<3> expected=<2> actual=<a> result=PASS|FAIL`.
   - Enforcing leg (`UNATT=1`): oos-write→2, allowed-write→0, readonly-edit→2,
     readonly-write-new→0, oos-bash-gitpush→2, oos-bash-curl→2, allowed-bash→0, oos-mcp→2,
     read-glob→0.
   - Env-gate leg (`UNATT=0`): oos-write→0, oos-bash-gitpush→0, oos-mcp→0 (hook no-ops entirely).
   - Fail-closed leg: `ORCHESTRATOR_UNATTENDED=1` with `ORCHESTRATOR_UNATTENDED_POLICY` pointing
     at a nonexistent file, oos-write→2 (policy-missing), read-glob→0 (read-class still passes).
   - Final `SUMMARY: pass=<p> fail=<f>`; `exit 0` iff `fail==0`.

## Must-Haves

- Truth: env-gate no-op when `ORCHESTRATOR_UNATTENDED` unset.
- Truth: enforcing deny/pass matrix (write/Bash/MCP/read-class).
- Truth: readonly deny-edit + deny-overwrite + pass-create-new.
- Artifact: `scripts/hooks/unattended-scope-guard.sh` (min 130 lines, contains "ORCHESTRATOR_UNATTENDED").
- Artifact: `scripts/hooks/unattended-protected-surface.txt` (min 12 lines, contains "readonly_path").
- Artifact: `tools/verify/m046-p05-scope-guard-deny.sh` (min 60 lines, contains "ORCHESTRATOR_UNATTENDED").

## Verification

```bash
bash tools/verify/m046-p05-scope-guard-deny.sh
```

## Inputs

### From Disk (Pre-existing)
- `.orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh` — copy its stdin/extract/policy-helper/dispatch scaffolding; apply the four production changes. Key contract: reads stdin JSON, exit 0 = pass, exit 2 = deny with a one-line stderr reason, Bash 3.2, no jq.
- `.orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh` — the fixture-drive harness shape (`ENV=... bash "$HOOK" < payload; actual=$?; compare`).
- `.orchestrator/milestones/M046/phases/P01/spike/hook/fixtures/*.json` + `policy.txt` — fixture JSON shape + allow_path/allow_tool/allow_bash directive syntax.

## Constraints

- Bash 3.2 compatible: no `declare -A`, no process substitution, no `$(...)`-containing-pipes in
  the hook body. sed/grep/case only. The hook is a single self-contained file (no sourcing).
- Framework-owned path discipline: hook + manifest live under `scripts/hooks/` (bundled), NOT
  `tools/verify/`. Only the verifier + fixtures live under `tools/verify/`.
- The env-gate MUST be the first executable statement after `set -u` (before any stdin read) so
  an attended invocation is a pure fast no-op.

## Expected Output

`bash tools/verify/m046-p05-scope-guard-deny.sh` prints a `case=... result=PASS` line per case
and a final `SUMMARY: pass=N fail=0`, exit 0.
