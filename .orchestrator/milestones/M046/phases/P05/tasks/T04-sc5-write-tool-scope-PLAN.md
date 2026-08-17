---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M046"
name: "SC-5 live non-stubbed write/Bash/MCP scope harness (milestone-blocking)"
depends_on: [T03]
---

## Prerequisites

- T02 complete: the production hook installs via the M028 path (`HOOKS_PAYLOAD` + adapter matcher `Write|Edit|Bash|mcp__.*`).
- T03 complete: `envelope_write_scope_policy` composes a per-run policy; the driver exports `ORCHESTRATOR_UNATTENDED_POLICY`.
- T01 complete: `scripts/hooks/unattended-scope-guard.sh` enforces the deny matrix under `ORCHESTRATOR_UNATTENDED=1`.

## Description

Author the SC-5 milestone-blocking, NON-STUBBED harness
`tools/verify/m046-p05-sc5-write-tool-scope.sh`. It proves that a real unattended child, driven
through the LIVE production hook installed via the real M028 path, is BLOCKED on all three
out-of-scope vectors — a write, a Bash `git push`, AND an MCP tool call — with the MCP vector
inside the milestone-blocking gate (Problem Statement Gap 2).

**Honest-realism design (record this framing in a header comment).** A full `claude -p` agent
making a live remote MCP call is deliberately NOT attempted: it needs real credentials + network
+ a connected MCP server — exactly the surface this hook forbids — and reaching the server would
prove the hook FAILED (a PreToolUse deny fires BEFORE tool dispatch; that IS the containment).
Instead the enforcement path is exercised end-to-end with no stub in it:
1. **Real install wiring.** Run the REAL `install-claude-code.sh` into an isolated scratch HOME so
   the production hook is genuinely staged into `$HOME/.claude/orchestrator-hooks/` and its
   `Write|Edit|Bash|mcp__.*` matcher is genuinely merged into that HOME's `settings.json`.
2. **Real matcher routing.** Parse the installed `settings.json` and assert the `PreToolUse`
   wrapper whose matcher contains `mcp__.*` points at our `unattended-scope-guard.sh` command —
   proving a real child's `mcp__*` tool_use WOULD route to this hook (the wiring is live, not
   assumed).
3. **Real per-run policy.** Compose the policy via the T03 `envelope_write_scope_policy` function
   (the same code the driver runs), not a hand-built fixture policy.
4. **Real hook contract.** Drive the genuinely-installed hook (resolved from `settings.json`) via
   the authentic Claude Code PreToolUse stdin→exit-2 contract with `ORCHESTRATOR_UNATTENDED=1`,
   using the authentic PreToolUse JSON envelope for each tool_use. The only non-live element is
   that no remote MCP server is contacted — which is definitionally correct.

## Steps

1. Create `tools/verify/m046-p05-sc5-write-tool-scope.sh` (project-owned). Structure:
   - `set -u`; `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`.
   - `SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046-p05-sc5.XXXXXX")"`; `trap 'rm -rf "$SCRATCH"' EXIT`.
   - `HOME_ISO="$SCRATCH/home"`; `mkdir -p "$HOME_ISO/.claude"`; `PROJ="$SCRATCH/project"; mkdir -p "$PROJ"`.
   - **Safety self-check**: assert `case "$HOME_ISO" in "$SCRATCH"/*) : ;; *) echo FAIL not-isolated; exit 1 ;; esac` — the harness refuses to run if HOME is not under the scratch dir.
   - **Install**: `HOME="$HOME_ISO" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" --project-dir "$PROJ" >"$SCRATCH/install.out" 2>&1` — assert rc 0.
   - `HOOKS_DIR="$HOME_ISO/.claude/orchestrator-hooks"`; `SETTINGS="$HOME_ISO/.claude/settings.json"`;
     `GUARD="$HOOKS_DIR/unattended-scope-guard.sh"`. Assert `-x "$GUARD"`.
   - **Matcher-routing assertion**: `grep -F "mcp__.*" "$SETTINGS"` succeeds AND
     `grep -F "bash $GUARD" "$SETTINGS"` succeeds (the mcp-covering wrapper points at our hook).
   - **Compose the real policy** via the T03 function: source
     `"$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"`; `POLICY="$SCRATCH/policy"`;
     call `envelope_write_scope_policy "$POLICY" "$PROJ" "$REPO_ROOT/scripts/hooks/unattended-protected-surface.txt" "$SCRATCH/mdir" "$SCRATCH/mdir/NO-ROADMAP.md" ""`.
     (allow_path = `$PROJ/`, so any write outside `$PROJ` is out-of-scope.)
   - Write the three PreToolUse payload fixtures into `$SCRATCH` (heredocs are fine inside a
     verifier; only Truth `Check:` lines are AD-19-constrained):
     - `oos-write.json` — `{"tool_name":"Write","tool_input":{"file_path":"/etc/evil.txt","content":"x"}}` (outside `$PROJ`).
     - `oos-bash-gitpush.json` — `{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}`.
     - `oos-mcp.json` — `{"tool_name":"mcp__slack__post_message","tool_input":{"channel":"x","text":"y"}}`.
     - `inscope-write.json` — `{"tool_name":"Write","tool_input":{"file_path":"$PROJ/note.txt","content":"x"}}` (positive control; substitute the real `$PROJ`).
   - **Milestone-blocking DENY leg** (`ORCHESTRATOR_UNATTENDED=1`, real policy, LIVE installed
     hook resolved from settings): a `drive()` helper runs
     `ORCHESTRATOR_UNATTENDED=1 ORCHESTRATOR_UNATTENDED_POLICY="$POLICY" bash "$GUARD" < "$payload"`,
     captures `$?`. Assert:
       - `oos-write`      → exit 2
       - `oos-bash-gitpush` → exit 2
       - `oos-mcp`        → exit 2   (the MCP vector — milestone-blocking, non-stubbed)
       - `inscope-write`  → exit 0   (positive control)
     Emit `case=<name> vector=<write|bash|mcp|control> expected=<e> actual=<a> result=PASS|FAIL`.
   - **Env-gate leg** (`ORCHESTRATOR_UNATTENDED` UNSET, same live hook): all three oos payloads
     → exit 0 (proves the live installed hook no-ops in the operator's session; safety-critical).
   - Final `SUMMARY: pass=<p> fail=<f>`; `exit 0` iff `fail==0` AND every DENY-leg case passed
     (a single missed deny fails the milestone-blocking gate).

## Must-Haves

- Truth: SC-5 — a real unattended child through the LIVE installed hook is BLOCKED on out-of-scope write, `git push`, AND `mcp__*`; env-gate leg passes all three; positive control passes.
- Artifact: `tools/verify/m046-p05-sc5-write-tool-scope.sh` (min 70 lines, contains "oos-mcp").

## Verification

```bash
bash tools/verify/m046-p05-sc5-write-tool-scope.sh
```

## Inputs

### From Previous Tasks
- `packaging/install/install-claude-code.sh` + `scripts/dispatch/adapters/runtime/claude-code.sh` (T02 wiring) — the real installer stages the hook + merges the `mcp__.*` matcher.
- `scripts/lifecycle/unattended-envelope.sh::envelope_write_scope_policy` (T03) — compose the real per-run policy; signature `(<policy> <project-root> <manifest> <milestone-dir> <roadmap> <phase-plan>)`.
- `scripts/hooks/unattended-scope-guard.sh` (T01) — enforces under `ORCHESTRATOR_UNATTENDED=1`; MCP default-deny; exit 2 = deny.

### From Disk (Pre-existing)
- `.orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh` — the `ENV=... bash "$HOOK" < payload; actual=$?` drive shape.
- `.orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh` — isolated-HOME install pattern.

## Constraints

- **Isolated scratch HOME, always** — the installer wires a deny-hook into `settings.json`; that
  MUST be an isolated scratch HOME under `$SCRATCH`. The operator's real `~/.claude` MUST NEVER be
  touched. The self-check above is mandatory; a harness that skips it is a defect.
- NON-STUBBED gate: the enforcement path (installer → settings matcher → hook → exit 2) contains
  no stub. Do not replace the installed hook with a stand-in, and do not seed a canned exit code.
- The MCP vector is a first-class DENY assertion inside the milestone-blocking summary, not a
  non-blocking example.

## Expected Output

`bash tools/verify/m046-p05-sc5-write-tool-scope.sh` prints a `case=...` line per vector, the
DENY leg all PASS (incl. `vector=mcp`), the env-gate leg all PASS, and `SUMMARY: pass=N fail=0`,
exit 0.

## Notes

Expected DENY-leg output (prose, not an executable line): each of `oos-write`, `oos-bash-gitpush`,
`oos-mcp` reports `expected=2 actual=2 result=PASS`; `inscope-write` reports `expected=0 actual=0
result=PASS`. A future optional live leg (default-closed, isolated-HOME, gated behind an env flag
à la M036/P03's `ORCHESTRATOR_TIER2_LIVE`) could spawn a real `claude -p` child against a local
stdio MCP stub server and assert the same denial end-to-end; it is a forward note, not a
deliverable of this task, and is NOT the milestone-blocking assertion.
