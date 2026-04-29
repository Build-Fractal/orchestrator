---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M028"
name: "Runtime adapter absolute-path emission + every-entry _orchestrator_managed flag (Finding F adapter half)"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/adapters/runtime/claude-code.sh` exists at the M025 baseline shape. The current `--hook-config` mode (around lines 150–192) emits a JSON fragment with two leaf hook objects — one Stop wrapper containing `orchestrator-post-verify`, one PreToolUse Bash matcher containing `orchestrator-before-commit`. Both are bare command names (the Finding F bug). Confirm with `bash scripts/util/run-probe.sh scripts/dispatch/adapters/runtime/claude-code.sh` (note: probe may not execute the full script — its purpose is shape inspection).

- `scripts/lifecycle/before-commit.sh` and `scripts/lifecycle/after-verify-sync.sh` exist (M025 deliverables). T02 maps the bare-name commands to absolute `bash ${HOOKS_DIR}/<name>.sh` invocations referencing the runtime-stable hooks dir these scripts will live in after T03's installer ships them.

- The runtime-stable hooks dir contract per CON-9 + Architectural Decisions in `M028-CONTEXT.md`: `${HOME}/.claude/orchestrator-hooks/`. Stable contract; future installer versions may add files but must not move the dir.

- `scripts/hooks/pre-bash-shape-guard.sh` (T01 modifies; T02 references the post-T01 hook only by path — the adapter does not currently emit a PreToolUse Bash entry for the shape-guard, but T02 SHOULD add one so the runtime-stable install includes it). See Steps for the emission shape.

## Description

Modify the adapter's `--hook-config` emission so every leaf hook object's `command` field is a literal `bash ${HOOKS_DIR}/<name>.sh` shape — never a bare name — and every leaf object carries `_orchestrator_managed: true`. The adapter must also include the new PreToolUse Bash entry for `pre-bash-shape-guard.sh` (the shape-guard installer-ships into the same dir). After T02:

- Stop event → one wrapper, one leaf object, `command = "bash ${HOOME_HOOKS}/after-verify-sync.sh"` (rename: the operator-reported failure was `orchestrator-post-verify: command not found`; the lifecycle script that satisfies Stop's intent is `after-verify-sync.sh` — the bare name was a misalignment between the emitted hook string and the actual on-disk script).
- PreToolUse event, matcher `Bash` → TWO leaf objects in the SAME wrapper (or two wrappers — adapter author's choice; the `settings-merge.sh` dedup key is `(event, matcher, command)`, not wrapper identity). Leaf 1: shape-guard `command = "bash ${HOME_HOOKS}/pre-bash-shape-guard.sh"`. Leaf 2: before-commit `command = "bash ${HOME_HOOKS}/before-commit.sh"`.
- Every leaf object carries `"_orchestrator_managed": true` adjacent to the `command` field.

The adapter writes the JSON fragment with `${HOME}` expanded inline (since the fragment is consumed by `settings-merge.sh` and ultimately written into the user's settings.json, the path must be the resolved absolute string, not a literal `${HOME}` placeholder).

Land one new verifier under `scripts/verify/m028/`:
- `p02-adapter-absolute-paths.sh` — runs `bash scripts/dispatch/adapters/runtime/claude-code.sh --hook-config`, captures stdout, and asserts:
    - Every `command` field starts with `bash ` (literal four bytes including trailing space).
    - Every `command` field ends with `.sh` (or `.sh"` accounting for the JSON closing quote).
    - The count of `_orchestrator_managed` substrings equals the count of leaf hook objects (heuristic: count `"command":` substrings; they must equal `_orchestrator_managed` substring count).
    - The fragment contains the literal substring `orchestrator-hooks` (proof that the absolute path references the runtime-stable dir).
    - Bash 3.2 + POSIX sh, AD-19 single-file flat shape.

## Steps

1. Read `scripts/dispatch/adapters/runtime/claude-code.sh` end to end. Note the `--hook-config` block (around lines 142–192) and the surrounding `--probe` / `--register` modes. The `set -u`, `HOME` guard, and exit-code conventions are stable; preserve them.

2. Establish the absolute hooks-dir path inside the `--hook-config` block. After the existing `HOME` guard, add:

    ```bash
    HOME_HOOKS="${HOME}/.claude/orchestrator-hooks"
    ```

    The variable is computed at adapter-emit time so the JSON fragment carries the resolved absolute path, not a `${HOME}` placeholder.

3. Replace the existing `cat <<'EOF' ... EOF` heredoc that emits the JSON fragment with one that uses an unquoted heredoc terminator (`<<EOF`, no quotes) so `${HOME_HOOKS}` expands. Verbatim shape (preserve indentation; this is the JSON the merge helper will consume):

    ```bash
    cat <<EOF
    {
      "hooks": {
        "Stop": [
          {
            "hooks": [
              { "type": "command", "command": "bash ${HOME_HOOKS}/after-verify-sync.sh", "_orchestrator_managed": true }
            ]
          }
        ],
        "PreToolUse": [
          {
            "matcher": "Bash",
            "hooks": [
              { "type": "command", "command": "bash ${HOME_HOOKS}/pre-bash-shape-guard.sh", "_orchestrator_managed": true },
              { "type": "command", "command": "bash ${HOME_HOOKS}/before-commit.sh", "_orchestrator_managed": true }
            ]
          }
        ]
      }
    }
    EOF
    ```

    Notes for the implementer:
    - The heredoc terminator is `EOF` (unquoted) — required so `${HOME_HOOKS}` expands at adapter-emit time. The previous `'EOF'` quoted form blocked expansion.
    - Three leaf hook objects total. Each carries exactly one `_orchestrator_managed: true` flag.
    - The Stop wrapper's command is `after-verify-sync.sh` — this is the rename per the operator-reported failure (`orchestrator-post-verify: command not found` → the actual lifecycle script is `after-verify-sync.sh`).
    - The PreToolUse Bash matcher carries TWO leaf objects: the shape-guard hook (NEW in T02) and the before-commit hook (renamed from bare `orchestrator-before-commit` to absolute `bash ${HOME_HOOKS}/before-commit.sh`).

4. Update the surrounding comment block (lines 152–168 in the current file) to reflect the new emission shape:
    - Note that every command is an absolute `bash <path>` invocation referencing `${HOME}/.claude/orchestrator-hooks/`.
    - Note that the shape-guard hook is now emitted on PreToolUse Bash (alongside before-commit).
    - Preserve the existing `_orchestrator_managed: true` rationale paragraph (M025 invariant; uninstall-cascade key).
    - Preserve the existing TODO list for deferred orchestrator events (`before_tasks`, `after_tasks`, etc.).

5. Run `bash scripts/util/run-probe.sh scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` to confirm the modified emission. The output should be valid JSON containing three `_orchestrator_managed: true` flags and three `bash <absolute-path>/...sh` command strings. (If `run-probe.sh` does not pass through the `--hook-config` arg cleanly, invoke the adapter directly via `bash scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` — `run-probe.sh` is a shape-safe wrapper, not strictly required for adapter invocation.)

6. Author `scripts/verify/m028/p02-adapter-absolute-paths.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Captures the adapter's emission to a temp file (avoids `$(...)` containing pipe). Use a redirect, not a pipe: `bash "${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh" --hook-config > "${tmp}" 2>/dev/null`. Set `tmp="${TMPDIR:-/tmp}/p02-adapter-$$.json"`. Add a trap or simply leave the tmp file (auto-cleaned on next reboot — sufficient for verifier).
    - Assertion 1: `grep -c '"command":' "${tmp}"` returns the per-leaf count via a plain assignment (no pipe inside `$(...)`). Use `cmd_count="$(grep -c '"command":' "${tmp}")"`. Then assert `[ "$cmd_count" -ge 3 ]` and on FAIL emit `FAIL: expected ≥ 3 command fields, got $cmd_count` to stderr and exit 1.
    - Assertion 2: every command starts with `bash ` and ends with `.sh`. Use a per-line walk: extract command lines via `grep '"command":' "${tmp}" > "${tmp}.cmds"`, then `while IFS= read -r line; do ... done < "${tmp}.cmds"`. For each line, assert it contains the substring `"bash ` (literal `"bash` followed by space — note the leading double-quote is the JSON value opener) and contains `.sh"` (literal `.sh` followed by closing JSON quote). Two `grep -q` calls per line; on either failing, FAIL with the offending line.
    - Assertion 3: `_orchestrator_managed` substring count equals `"command":` substring count. `flag_count="$(grep -c '_orchestrator_managed' "${tmp}")"`. Assert `[ "$flag_count" = "$cmd_count" ]`.
    - Assertion 4: the fragment contains the literal substring `orchestrator-hooks`. `grep -q 'orchestrator-hooks' "${tmp}"` else FAIL.
    - On all-pass, emit `PASS: adapter emits $cmd_count absolute-path hook commands, each tagged _orchestrator_managed: true` to stdout and exit 0.

7. Run `bash scripts/util/run-probe.sh scripts/verify/m028/p02-adapter-absolute-paths.sh`. Confirm `PASS`. If FAIL, iterate on the adapter emission — do not weaken the verifier.

## Must-Haves

This task addresses the phase Truth: "The Claude Code runtime adapter emits, for every hook entry, a `command` field of the literal shape `bash <hooks-dir>/<name>.sh` (never a bare command name) and every emitted leaf object carries `_orchestrator_managed: true`."

It produces the verifier `scripts/verify/m028/p02-adapter-absolute-paths.sh` that gates this Truth.

## Verification

```bash
bash scripts/verify/m028/p02-adapter-absolute-paths.sh
```

## Notes

Expected output is a single line `PASS: adapter emits 3 absolute-path hook commands, each tagged _orchestrator_managed: true` (the count may grow as future M028 phases add additional lifecycle hooks; the verifier asserts ≥ 3, not exactly 3).

The previous bare-name emission (`"orchestrator-post-verify"`, `"orchestrator-before-commit"`) was the Finding F adapter-half root cause: Claude Code's hook runner looked these up on PATH, found nothing, and emitted `command not found` on every Stop event. Absolute `bash <path>` invocations resolve unconditionally regardless of the consumer project's PATH.

The unquoted heredoc terminator (`<<EOF` not `<<'EOF'`) is the load-bearing change for `${HOME_HOOKS}` expansion. If the adapter is ever re-quoted, the JSON fragment will carry literal `${HOME_HOOKS}` in the `command` field and `settings-merge.sh` will write that to disk verbatim — defeating the absolute-path contract.

The settings-merge dedup key (T03 deliverable) is `(event, matcher, command)`. Adding the shape-guard PreToolUse Bash leaf does not collide with the existing before-commit leaf because the two have different `command` strings — they are distinct dedup-key tuples. Both will land on rerun without duplication.

## Inputs

### From Previous Tasks

None within P02. T02 is independent of T01 — different files, different concerns.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/runtime/claude-code.sh` — M025 runtime adapter. T02 modifies the `--hook-config` mode block (around lines 142–192). All other modes (`--probe`, `--register`, `--register --dry-run`) are untouched.
- `scripts/lifecycle/before-commit.sh` — M025 lifecycle script. T02 references it by absolute name in the JSON fragment. Key behavior: invoked by Claude Code on PreToolUse Bash before a `git commit` runs; performs sentinel/audit-log work; exits 0 on allow.
- `scripts/lifecycle/after-verify-sync.sh` — M025 lifecycle script. T02 references it by absolute name in the JSON fragment. Key behavior: invoked by Claude Code on Stop event after a tool batch completes; performs post-verify roadmap sync; exits 0 on success.
- `scripts/hooks/pre-bash-shape-guard.sh` — referenced by name in the JSON fragment. T02 does not modify the hook (T01 owns that). The fragment will resolve to the post-T01 self-locating hook because the installer (T03) copies whichever version is in tree.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: the new verifier `p02-adapter-absolute-paths.sh` is a flat single-file script under `scripts/verify/m028/`. No nested helper dirs. No inline compound bash, no plain `( ... )` subshells, no `$(...)` containing a pipe, no process substitution.
- **bash 3.2 + POSIX sh (CON-2)**: the verifier and the adapter modifications run on bash 3.2. No associative arrays. No `mapfile` / `readarray`. No unguarded `<<<` here-strings.
- **No new runtime deps (CON-6)**: the verifier uses `grep`, `[ ... ]`, plain string substitution. No `jq` (though the adapter's emission is JSON, the verifier asserts on substring shape, not parsed structure).
- **Non-Goal: no M025 contract revision**: T02 extends the adapter's emission set (one new leaf for the shape-guard) and changes the `command` field shape (bare name → absolute `bash <path>`), but does not alter the `_orchestrator_managed: true` tag semantics, the wrapper-grouping convention, or the `--hook-config` invocation contract. M025 owns those; M028 consumes them.
- **Heredoc-quote discipline**: the heredoc terminator MUST be unquoted (`<<EOF`) so `${HOME_HOOKS}` expands. If a future change re-quotes it (`<<'EOF'`), the absolute-path contract is broken.
- **Symlink edge case**: the adapter computes `${HOME}/.claude/orchestrator-hooks` without a `pwd -P` — Claude Code's hook runner resolves symlinks at execution time. The hook's own self-location (T01) handles symlink resolution at hook-load time.
