---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M028"
provides:
  - "Claude Code runtime adapter --hook-config emits absolute bash <abs-path>/<name>.sh commands for every leaf hook object (Stop: after-verify-sync.sh; PreToolUse Bash: pre-bash-shape-guard.sh + before-commit.sh) -- bare-name commands retired"
  - "every leaf hook object carries _orchestrator_managed: true (M025 uninstall-cascade invariant preserved)"
  - "new verifier scripts/verify/m028/p02-adapter-absolute-paths.sh asserting bash-prefix shape, .sh-suffix, _orchestrator_managed-count == command-count, orchestrator-hooks-substring presence"
  - "updated scripts/verify/m025-p01-hook-schema.sh assertions 5+6 to the absolute-path contract (Stop basename == after-verify-sync.sh; PreToolUse Bash basenames include before-commit.sh + pre-bash-shape-guard.sh)"
requires:
  - from: "M025/P01"
    what: "scripts/dispatch/adapters/runtime/claude-code.sh --hook-config baseline interface; HOME guard convention; _orchestrator_managed:true tag semantics"
  - from: "M028/CON-9"
    what: "runtime-stable hooks dir contract: ${HOME}/.claude/orchestrator-hooks/"
affects:
  - "P02/T03 (install-side dedup consumes the new emission shape; settings-merge.sh dedup key (event, matcher, command) is now distinct per absolute-path command string)"
  - "P02/T05 (install-roundtrip pinned-sha gate verifies adapter-emitted fragment merges idempotently into ~/.claude/settings.json)"
  - "P03 (Finding-G self-conformance verifier shares the orchestrator-hooks dir convention)"
  - "M028 phase Truth FR-3 + FR-4 + US-1 + US-3 acceptance scenario 4 (closes Finding F adapter half)"
key_files:
  - "scripts/dispatch/adapters/runtime/claude-code.sh (modified -- --hook-config block heredoc terminator switched <<'EOF' -> <<EOF for HOME_HOOKS expansion; three leaf objects emitted with absolute bash <path>/<name>.sh commands; comment block rewritten to document the new shape)"
  - "scripts/verify/m028/p02-adapter-absolute-paths.sh (created -- 95 lines, AD-19 single-script-file flat shape, bash 3.2 + POSIX-sh-safe, no jq, captures emission via redirect to avoid pipe-in-cmdsub)"
  - "scripts/verify/m025-p01-hook-schema.sh (modified -- assertions 5+6 rewritten to assert absolute-path basenames and bash-prefix/.sh-suffix shape; the bare-name assertions were the Finding F bug contract verbatim)"
key_decisions:
  - "Heredoc-quote discipline: terminator MUST be unquoted (<<EOF) so HOME_HOOKS expands at adapter-emit time. The previous <<'EOF' quoted form blocked expansion. If a future change re-quotes it, the absolute-path contract breaks (literal ${HOME_HOOKS} written to settings.json)."
  - "M025 verifier update is in-scope for T02. The M025 baseline assertions 5+6 (orchestrator-post-verify / orchestrator-before-commit bare names) were the explicit Finding F bug contract; updating them to the absolute-path shape is part of the Finding F fix, not an out-of-scope drift. Alternative -- leaving M025 verifier failing -- would block phase verification."
  - "Three leaves emitted, not two: the M025 baseline emitted two leaves (one Stop, one PreToolUse Bash). T02 adds a third leaf -- the shape-guard hook on PreToolUse Bash -- so the runtime-stable install includes it alongside before-commit. settings-merge.sh dedup key (event, matcher, command) makes the two PreToolUse Bash leaves distinct without collision."
  - "Absolute paths reference ${HOME}/.claude/orchestrator-hooks/ (per CON-9). Symlink resolution at hook-execution time is Claude Code's job; the adapter computes without pwd -P (T01's hook handles symlink resolution at hook-load time via BASH_SOURCE + pwd -P)."
patterns_established:
  - "Absolute-path heredoc emission: variable expansion at adapter-emit time via unquoted heredoc terminator <<EOF + HOME_HOOKS=${HOME}/.claude/orchestrator-hooks; resolved absolute path written into JSON fragment, not a placeholder. Robust against PATH-lookup failures in consumer projects (the Finding F root cause)."
  - "Substring-shape verifier discipline: no jq, grep-only structural assertions on JSON-as-text. Asserts on (a) command-prefix '\"bash ', (b) command-suffix '.sh\"', (c) _orchestrator_managed-count == command-count, (d) literal substring 'orchestrator-hooks' present. Robust to whitespace/ordering variation; AD-19 single-file flat shape compliance."
  - "Verifier reads adapter via redirect not pipe (CON-1): emission captured via 'bash $ADAPTER --hook-config > $tmp 2>/dev/null', then grep / while-read against the file. No \$(...) containing pipe; no pipe inside cmdsub. Compatible with the active shape-guard hook's classifier."
  - "Assertion-style shift in step with contract change: when a downstream task explicitly supersedes an upstream verifier's assertion target (here, M025 baseline bare-name assertions superseded by M028 absolute-path contract), the verifier is updated in the same task as the contract change. The verifier is the contract-test, not an immutable artifact."
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P02/tasks/T02-adapter-absolute-paths-PLAN.md"
  - ".orchestrator/milestones/M028/phases/P02/tasks/T02-adapter-absolute-paths-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-29T00:00:00Z"
---

T02 closes the Finding F adapter half: scripts/dispatch/adapters/runtime/claude-code.sh --hook-config now emits absolute bash <abs-path>/<name>.sh commands for every leaf hook object. Three leaves total (Stop + two PreToolUse Bash); each carries _orchestrator_managed: true.

## What Happened

Modified the --hook-config block of `scripts/dispatch/adapters/runtime/claude-code.sh` (around lines 152-192). The HOME guard is preserved. After the guard, a new `HOME_HOOKS="${HOME}/.claude/orchestrator-hooks"` variable is set. The heredoc terminator switched from `<<'EOF'` (which blocked expansion) to `<<EOF` (which expands `${HOME_HOOKS}` at adapter-emit time -- the JSON fragment carries the resolved absolute path, not a `${HOME_HOOKS}` placeholder).

The emission shape changed from M025-baseline two leaves to M028 three leaves:

- **Stop**: one leaf, `command = "bash ${HOME_HOOKS}/after-verify-sync.sh"` (renamed from bare `orchestrator-post-verify` -- the bare name was a misalignment between the emitted hook string and the actual on-disk lifecycle script).
- **PreToolUse Bash**: two leaves in the same wrapper -- (1) `bash ${HOME_HOOKS}/pre-bash-shape-guard.sh` (NEW T02; ensures the runtime-stable install includes the shape-guard); (2) `bash ${HOME_HOOKS}/before-commit.sh` (renamed from bare `orchestrator-before-commit`). settings-merge.sh dedup key `(event, matcher, command)` makes the two leaves distinct dedup-key tuples.

Every leaf carries `"_orchestrator_managed": true` ([M025](../../../../../milestones/M025/index.md) invariant; uninstall-cascade key). The comment block was rewritten to document the new shape, the rename rationale, the heredoc-quote discipline, and the runtime-stable-hooks-dir contract. The four `TODO(M025+)` deferral markers are preserved.

Authored `scripts/verify/m028/p02-adapter-absolute-paths.sh` (95 lines, AD-19 single-script-file flat shape, bash 3.2 + POSIX-sh-safe, no jq):

- `set -u`, no `set -e`. Resolves repo root via `cd $(dirname $0)/../../../ && pwd -P`.
- Captures adapter emission via redirect (no pipe inside cmdsub): `bash "$ADAPTER" --hook-config > "$tmp" 2>/dev/null`.
- Assertion 1: `grep -c '"command":' $tmp` >= 3.
- Assertion 2: every command line contains `"command": "bash ` (literal opener) and `.sh"` (closing quote). Per-line walk via `while IFS= read -r`.
- Assertion 3: `grep -c '_orchestrator_managed' $tmp` == `grep -c '"command":' $tmp`.
- Assertion 4: `grep -q 'orchestrator-hooks' $tmp`.
- On all-pass: `PASS: adapter emits N absolute-path hook commands, each tagged _orchestrator_managed: true` to stdout, exit 0.

Updated `scripts/verify/m025-p01-hook-schema.sh` assertions 5+6: rewritten to assert the absolute-path contract instead of the M025-baseline bare-name shape. Stop leaf basename must equal `after-verify-sync.sh` and the command must start with `bash ` and end with `.sh`. PreToolUse Bash matcher must carry leaf objects whose basenames include both `before-commit.sh` and `pre-bash-shape-guard.sh`. The header comment was updated to document the new contract and reference T02 / Finding F adapter half.

## Verification

- `bash scripts/verify/m028/p02-adapter-absolute-paths.sh` -> `PASS: adapter emits 3 absolute-path hook commands, each tagged _orchestrator_managed: true` (exit 0).
- `bash scripts/verify/m025-p01-hook-schema.sh` -> `pass=8 fail=0` / `PASS: m025-p01-hook-schema.sh` (exit 0). All eight assertions pass.
- `bash scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` produces the expected JSON: three `_orchestrator_managed: true` flags and three `bash /Users/.../orchestrator-hooks/...sh` command strings.

## Deviations

**M025 verifier update was implied by the task description but not explicitly enumerated in "Files To Touch".** The task plan's Description block specifies the shape change ("bare name -> absolute `bash <path>`") and the M025 verifier asserted the bare-name shape verbatim. Updating the verifier in step with the adapter is part of the Finding F fix surface, not out-of-scope drift. Alternative -- leaving M025 verifier failing -- would have blocked phase verification. The verifier's M025 invariants (every leaf `_orchestrator_managed`-tagged, exactly one Stop leaf, PreToolUse Bash matcher present) are preserved; only the bare-name assertion (assertions 5+6) was replaced with the absolute-path assertion.

**`scripts/verify/m013-p04-post-verify-hook.sh` was already failing pre-T02 and remains failing post-T02.** Two assertions (`hook_count=6` and `event: "post_verify"` JSON shape) reference an adapter emission shape that the M025 baseline never produced -- the M025 schema is `hooks.{Stop,PreToolUse}`-keyed, not flat-`hook_count`/`event`-array shaped. Out of T02 scope; flagged in this summary's Discoveries section for capture in CLAUDE.md's near-term-hotfix list. Not a regression caused by T02.

## Files Created/Modified

- `scripts/dispatch/adapters/runtime/claude-code.sh` (modified) -- --hook-config block: heredoc switched <<'EOF' -> <<EOF; new HOME_HOOKS variable; three leaves emitted with absolute bash <path>/<name>.sh commands; comment block rewritten.
- `scripts/verify/m028/p02-adapter-absolute-paths.sh` (created) -- new T02 verifier asserting absolute-path emission shape.
- `scripts/verify/m025-p01-hook-schema.sh` (modified) -- assertions 5+6 rewritten to absolute-path contract; header comment updated.

## Commit

`5b80573 M028/P02/T02: adapter emits absolute bash <path> hook commands (Finding F adapter half)` on branch `main`.

## Discoveries (capture for CLAUDE.md near-term-hotfix list)

1. **`scripts/verify/m013-p04-post-verify-hook.sh` asserts an adapter emission shape (`hook_count=6`, `event: "post_verify"`) that the M025 baseline emission has never produced.** The verifier currently fails 2/14 assertions against the M025 baseline (and post-T02 against the absolute-path emission). The verifier appears to assert against an older or unrelated hook-config schema. Out of T02 scope but worth either updating to assert the actual M025/M028 schema or removing if obsolete. Suggested home: next M013-touching milestone or paper-cut sweep.

2. **The pre-bash shape-guard hook rejects the `git commit -m "$(cat <<'EOF' ... EOF)"` HEREDOC pattern documented in CLAUDE.md's commit-message guidance.** The hook flagged it as `heredoc-with-expansion` (AP-008) on my first commit attempt. The `-F /tmp/<file>.txt` form works around it. The CLAUDE.md guidance to "ALWAYS pass the commit message via a HEREDOC" + the example showing `git commit -m "$(cat <<'EOF' ... EOF)"` is in tension with the active shape-guard. Suggested fix: update CLAUDE.md commit-message-via-HEREDOC guidance to recommend `git commit -F <file>` as the safe primary form, with the inline-HEREDOC variant noted as guarded against by the shape-guard. Bundles cleanly with the existing CLAUDE.md hotfix list.

3. **Plan-time vs runtime path resolution: the task plan referenced `scripts/util/run-probe.sh scripts/dispatch/adapters/runtime/claude-code.sh --hook-config`** in Steps 5 and 7. `run-probe.sh` rejects paths outside its approved-roots list (same trap T01 surfaced). I invoked the adapter directly. The plan's truth-Check row uses the direct invocation; the Steps section's run-probe wrapping is a planning error in the same shape as T01's discovery #2 -- already on the CLAUDE.md hotfix list. No new entry needed; T02 confirms the existing entry's signal.
