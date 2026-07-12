---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M046"
name: "Hook-install portability spike (#Q-1)"
depends_on: []
---

## Prerequisites

All pre-existing (verified on disk at plan-authoring time):

- `scripts/hooks/pre-bash-shape-guard.sh` — the M021 shape-guard PreToolUse hook this probe must coexist with. Contract: reads Claude Code hook JSON from stdin; exit 0 = pass (empty stdout), exit 2 = hard-reject with stderr diagnostic. Registered under `hooks.PreToolUse` with `"matcher": "Bash"`.
- `scripts/util/settings-merge.sh` — M025/M028 merge-not-overwrite helper. CLI: `bash scripts/util/settings-merge.sh merge --target <settings.json> --fragment <json-string> [--dry-run]`. Dedup key is the full (event, matcher, command) tuple within `_orchestrator_managed: true` scope; idempotent on repeat merge.
- `packaging/install/install-claude-code.sh` — consumer installer. Its §2.5 block stages `HOOKS_PAYLOAD` files into `$HOME/.claude/orchestrator-hooks/` via `cp -f` + writes a `MANIFEST`; §3 merges the hooks fragment into `$HOME/.claude/settings.json` via `settings-merge.sh`. Honors `HOME` from the environment.
- `packaging/bundle/build-bundle.sh` — builds the packaged-bundle tree (the byte-identical payload npm/homebrew/curl all deliver, per M035 cross-channel byte-equivalence).

## Description

Answer the two mechanical halves of **#Q-1**: (a) does a **default-DENY** PreToolUse hook — deny unless explicitly allowlisted, covering Write paths, Bash tool surface, and MCP tools — work through the real Claude Code hook contract (stdin JSON → exit 0/2)? (b) does it install via the **M028 consumer path** (staged hooks dir + managed settings-merge fragment) on both real install shapes, coexisting with the already-registered shape-guard?

This is a THROWAWAY probe (M045 P01 pattern): everything lives under the spike dir except nothing — no production surface is touched. The production hook is P05's deliverable; this task only de-risks its premise. All probe runs use an **isolated `HOME`** (a scratch directory) — the real `$HOME/.claude` is never written.

## Steps

1. **Create the spike dir**: `.orchestrator/milestones/M046/phases/P01/spike/hook/`.

2. **Author the probe hook** at `spike/hook/unattended-deny-probe.sh` (bash 3.2, no jq, no process substitution — mirror `pre-bash-shape-guard.sh` conventions). Behavioral contract:
   - Read the full hook JSON from stdin into a variable (single `cat`).
   - Extract `tool_name` and, for Bash, `tool_input.command`; for Write/Edit, `tool_input.file_path` — via `sed`/`awk` string extraction (the shape-guard shows the no-jq pattern).
   - Policy, read from an env-var-pointed config file `DENY_PROBE_POLICY` (one directive per line, `allow_path <prefix>` / `allow_tool <name>` / `allow_bash <regex>`):
     - `tool_name` matching `mcp__*` → DENY unless `allow_tool` matches exactly.
     - `tool_name` = Write/Edit/NotebookEdit → DENY unless `file_path` starts with an `allow_path` prefix.
     - `tool_name` = Bash → DENY if the command matches `git push`, `curl`, `rm -rf` outside an allowed prefix, unless an `allow_bash` regex matches.
     - Everything else (Read, Glob, Grep) → pass.
   - DENY = print one-line reason to stderr (`DENY_PROBE: <tool> <detail> not in allowlist`) + `exit 2`; PASS = empty stdout + `exit 0`. Fail-closed: unreadable/absent policy file → DENY everything except Read-class tools (exit 2 with `policy-missing` reason).

3. **Author the direct-drive harness** at `spike/hook/drive-hook-case.sh` — takes `<case-name> <expected-exit> <json-payload-file>`, pipes the payload into the probe hook, compares actual vs expected exit, appends `case=<name> expected=<e> actual=<a> result=PASS|FAIL` to `spike/hook/deny-drive.log`. Author six payload JSON fixtures (real Claude Code hook shape: `{"tool_name": "...", "tool_input": {...}}`):
   - `case=oos-write` Write to `/etc/passwd` → expect 2
   - `case=oos-bash-gitpush` Bash `git push origin main` → expect 2
   - `case=oos-mcp` `mcp__claude_ai_Slack__slack_send_message` → expect 2
   - `case=allowed-write` Write to an `allow_path` prefix → expect 0
   - `case=allowed-bash` Bash matching an `allow_bash` regex → expect 0
   - `case=policy-missing-failclosed` valid Write payload with `DENY_PROBE_POLICY` pointing at a nonexistent file → expect 2

4. **Author the install-matrix probe** at `spike/hook/run-install-matrix.sh`:
   - **Shape A (symlink/source)**: `HOME=<scratch-A>` → run `packaging/install/install-claude-code.sh` from the repo tree, then (i) manually `cp` the probe hook into `$HOME/.claude/orchestrator-hooks/` and (ii) merge its PreToolUse fragment via `settings-merge.sh merge` (fragment: matcher `Write|Edit|Bash|mcp__.*`, command `bash $HOME/.claude/orchestrator-hooks/unattended-deny-probe.sh`, `_orchestrator_managed: true`). This mirrors exactly what P05 will add to `HOOKS_PAYLOAD` + the installer fragment — the probe proves the two mechanisms accept a NEW hook without installer changes.
   - **Shape B (packaged-bundle)**: build the bundle via `packaging/bundle/build-bundle.sh` into a scratch stage dir, run the STAGED installer with `HOME=<scratch-B>`, repeat (i)+(ii).
   - For each shape assert: hook file staged + executable; settings.json contains BOTH the shape-guard entry AND the probe entry (grep both command strings); re-running the merge is a no-op (idempotency — assert leaf count unchanged); `settings-merge.sh uninstall` removes managed entries cleanly. Append `shape=<A|B> staged=<0|1> merged=<0|1> coexists=<0|1> idempotent=<0|1> uninstall_clean=<0|1>` per shape to `spike/hook/install-matrix.log`.

5. **Run** both harnesses; confirm `deny-drive.log` shows 6/6 PASS and `install-matrix.log` shows both shapes all-1s. If any leg fails, record the failure honestly — a NEGATIVE #Q-1 verdict routes FR-9 to an alternate enforcement mechanism via an explicit Decision row (T03's job), it does not block this task's completion.

6. **Optional live leg (attended judgment)**: if the `claude` CLI is available and the operator context permits a ~$0.25 spend, run one `claude -p` invocation with `HOME=<scratch-A>` prompting a single out-of-scope write, and record whether the deny fires end-to-end (append `case=live-e2e` to `deny-drive.log`). If skipped, note `live-e2e=deferred-to-SC-5` in the log — SC-5 (P05, milestone-blocking, non-stubbed) is the committed end-to-end proof either way.

## Must-Haves

- The hook probe demonstrates live default-DENY semantics (deny ×3 vectors, pass ×2, fail-closed ×1) through the real stdin/exit-code contract.
- The install-shape matrix shows staging + managed merge + shape-guard coexistence + idempotency on both shapes.

## Verification

```bash
bash .orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh --all
bash .orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh
grep -c "result=PASS" .orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log
grep -c "shape=" .orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log
```

## Notes

Expected: `drive-hook-case.sh --all` re-runs all six cases and exits 0 only if every case PASSes; the first `grep -c` prints ≥ 6; the second prints 2 (one line per shape). The `## Verification` fences contain only executable commands per M028/P01 finding; this Notes section carries the expected-output prose. T03 authors the durable `tools/verify/m046-p01-*.sh` wrappers over these logs — per plan-time discipline rule 2, this task's inline checks depend only on artifacts this task itself creates.

## Inputs

### From Previous Tasks

None (first task, parallel with T02).

### From Disk (Pre-existing)

- `scripts/hooks/pre-bash-shape-guard.sh` — stdin/exit-code contract to mirror; the settings.json entry to coexist with.
- `scripts/util/settings-merge.sh` — `merge`/`uninstall` subcommands as documented in Prerequisites.
- `packaging/install/install-claude-code.sh` — run with overridden `HOME`; emits `hooks_staged=<n> dir=<path>` on success.
- `packaging/bundle/build-bundle.sh` — bundle builder for Shape B.

## Constraints

- **Isolated HOME only** — no write to the real `$HOME/.claude` (the operator's live settings are in use by this very session).
- **Throwaway discipline** — nothing lands in `scripts/` or `packaging/`; the production hook is P05's deliverable.
- **Bash 3.2 / no jq / no process substitution** in the probe hook (MEM001; consumer machines).
- **Shape-guard discipline for harness scripts** — single-invocation shapes; no inline compound chains >2, no `$(...)` with pipes (AD-19). Classifier verdict for the plan's check shape recorded at plan time: `AUTO_SAFE`.
- Live leg spend cap: ≤ $0.50; skipping it is an accepted PARTIAL (SC-5 is the committed proof).

## Expected Output

`spike/hook/` containing the probe hook, drive harness, six payload fixtures, install-matrix script, and two populated logs: `deny-drive.log` (≥6 `result=PASS` lines) and `install-matrix.log` (2 `shape=` lines, all fields 1). These are T03's #Q-1 verdict inputs.
