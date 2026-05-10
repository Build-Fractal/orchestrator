---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M028"
name: "Install-roundtrip pinned-sha gate + per-finding A/F verifiers (FR-6 + SC-2 + SC-5)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- **T01 complete**: `pre-bash-shape-guard.sh` self-locates via `BASH_SOURCE[0]`; `p02-hook-self-locate.sh` and `p02-hook-self-conformance.sh` PASS.
- **T02 complete**: `claude-code.sh --hook-config` emits absolute-path leaves with `_orchestrator_managed: true` on every entry; `p02-adapter-absolute-paths.sh` PASSes.
- **T03 complete**: installer stages the hooks payload to `${HOME}/.claude/orchestrator-hooks/`; `settings-merge.sh merge` deduplicates on the `(event, matcher, command)` tuple; `p02-hooks-payload-staged.sh` PASSes.
- **T04 complete**: installer has `--repair` and `--repair --dry-run`; `p02-repair-fixture.sh` PASSes.
- All four upstream verifiers under `scripts/verify/m028/` are already installed and exercise the surface T05 builds the close-out gate over.
- `scripts/lifecycle/after-verify-sync.sh` exists and is invocable. T05's Finding F verifier exercises the Stop-event resolution end-to-end.

## Description

Land three verifiers under `scripts/verify/m028/`:
1. `install-roundtrip.sh` — the FR-6 pinned-sha install→install→uninstall byte-equality gate. The closing-the-loop proof for SC-2 ([M025](../../../../../milestones/M025/index.md) reversibility extended).
2. `finding-A-verifier.sh` — the per-finding gate for Finding A. Exercises the self-locating hook in a consumer-project context where `$CLAUDE_PROJECT_DIR` does not point at the orchestrator repo.
3. `finding-F-verifier.sh` — the per-finding gate for Finding F. Exercises the resolved Stop-event lifecycle script with no `command not found` diagnostic.

All three are flat single-file scripts under `scripts/verify/m028/` per AD-19. They reuse the isolated-HOME pattern T03's verifier introduced (tmp dir, `HOME=<tmp> bash <installer>`, post-pass cleanup).

The install-roundtrip gate proof, formally:
- **Snapshot 0**: SHA-256 of `${tmp_home}/.claude/settings.json` BEFORE any install (the file may not exist; treat absence as the canonical "empty" pre-state with a sentinel SHA).
- **Snapshot 1**: SHA-256 after first `bash install-claude-code.sh` run.
- **Snapshot 2**: SHA-256 after second `bash install-claude-code.sh` run.
- **Snapshot 3**: SHA-256 after `bash install-claude-code.sh --uninstall` run.

Assertions:
- `Snapshot 1 == Snapshot 2` (idempotency / install-side dedup proof).
- `Snapshot 0 == Snapshot 3` (M025 reversibility — uninstall returns to pre-install canonical bytes).

The Finding A verifier exercises the hook in a consumer-project context. Pattern:
1. Set up isolated HOME under `${TMPDIR}/p02-finding-A-$$`.
2. Run the installer to stage the hooks payload.
3. Set `CLAUDE_PROJECT_DIR=/some/other/path` (a path that is NOT the orchestrator repo) and invoke `bash ${HOME}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh` with a verbatim Finding A screenshot command piped to stdin (in JSON-shaped Claude Code hook event format).
4. Assert the hook resolves its classifier (not silent passthrough) and emits the expected verdict for the test command. The exact test command is a known-rejected [M021](../../../../../milestones/M021/index.md) corpus entry (e.g., a compound chain > 2 connectors that AP-009 rejects); the verifier confirms the hook's output matches `REJECT:` rather than empty stdout (which would indicate the classifier was not loaded).

The Finding F verifier exercises the lifecycle-script resolution. Pattern:
1. Set up isolated HOME under `${TMPDIR}/p02-finding-F-$$`.
2. Run the installer to stage the hooks payload + register hooks in `${HOME}/.claude/settings.json`.
3. Read the post-install settings.json and extract the Stop-event command string.
4. Confirm the command string starts with `bash ` and ends with `after-verify-sync.sh`.
5. Execute the resolved command with a minimal stub stdin (Claude Code hook event JSON for a Stop event) and assert exit 0 + no `command not found` substring on stderr.

## Steps

1. Author `scripts/verify/m028/install-roundtrip.sh`. Single-file flat shape, bash 3.2 safe, ≥ 30 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-roundtrip-$$"` and `mkdir -p "$tmp_home/.claude"`.
    - Defines a helper `compute_sha()` (function definition at top of script — function defs are AD-19 safe; only inline-blocks are restricted) that takes a file path and writes the SHA-256 to a passed-in destination file. The function uses `shasum -a 256 "$1" > "$2.raw"` then `awk '{print $1}' "$2.raw" > "$2"`. Avoids `$(...)` containing pipe.
    - **Snapshot 0** (pre-install): if `${tmp_home}/.claude/settings.json` does not exist, write a sentinel hash to `${tmp_home}/sha0.txt` (e.g., literal string `EMPTY`); else compute SHA-256.
    - Run installer: `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --project-dir "$tmp_home" >/dev/null 2>&1`. Capture exit code; FAIL on non-zero.
    - **Snapshot 1**: compute SHA of `${tmp_home}/.claude/settings.json` to `${tmp_home}/sha1.txt`.
    - Run installer again (second install): `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --project-dir "$tmp_home" >/dev/null 2>&1`.
    - **Snapshot 2**: compute SHA to `${tmp_home}/sha2.txt`.
    - Run uninstall: `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --uninstall >/dev/null 2>&1`.
    - **Snapshot 3**: SHA-256 of `${tmp_home}/.claude/settings.json` (or sentinel if file removed) to `${tmp_home}/sha3.txt`.
    - Read all four hashes via `awk '{print $1}'` redirects (no `$(... | ...)`). Pattern: `sha0="$(awk '{print $1}' "${tmp_home}/sha0.txt")"`.
    - Assertion 1 (idempotency): `[ "$sha1" = "$sha2" ]`. On FAIL, emit `FAIL: install-roundtrip idempotency: sha1=$sha1 sha2=$sha2` to stderr, leave tmp dir, exit 1.
    - Assertion 2 (reversibility): `[ "$sha0" = "$sha3" ]`. On FAIL, emit `FAIL: install-roundtrip reversibility: sha0=$sha0 sha3=$sha3` to stderr, leave tmp dir, exit 1.
    - On all-pass, emit `PASS: install-roundtrip idempotency=$sha1 reversibility=$sha0` to stdout, clean up tmp dir, exit 0.

    **Note on multi-stage shasum extraction within AD-19**: every SHA computation uses the helper function which writes to a tmp file then awk-extracts; no compound `$(... | ...)` anywhere. Function bodies in bash 3.2 are NOT subject to the AP-009 classifier (which scans command-line shape, not function-body shape) — the function may use multi-line clear bash inside `compute_sha() { ... }`.

2. Author `scripts/verify/m028/finding-A-verifier.sh`. Single-file flat shape, ≥ 20 lines, bash 3.2. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-finding-A-$$"`.
    - Runs installer with `HOME="$tmp_home"` to stage the hooks payload.
    - Sets `CLAUDE_PROJECT_DIR="${tmp_home}/fake-project"` (a non-orchestrator path; create the dir empty: `mkdir -p "$CLAUDE_PROJECT_DIR"`).
    - Constructs a minimal Claude Code hook event JSON for a Bash tool call. Example payload (heredoc into a tmp file):
        ```json
        {
          "tool_name": "Bash",
          "tool_input": {
            "command": "bash -c 'a && b && c && d && e'"
          }
        }
        ```
        The command body has 4 `&&` connectors — guaranteed AP-009 reject under M021 classifier. Write the JSON to `${tmp_home}/hook-event.json`.
    - Invoke the staged hook with the JSON on stdin: `HOME="$tmp_home" CLAUDE_PROJECT_DIR="${tmp_home}/fake-project" bash "${tmp_home}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh" < "${tmp_home}/hook-event.json" > "${tmp_home}/hook-stdout.txt" 2> "${tmp_home}/hook-stderr.txt"`. Capture exit code in `hook_rc=$?`.
    - Assertion 1: `hook_rc -eq 2` (the hook's reject exit code per the M021 protocol — Finding A in the wild was the hook returning 0 silently because the classifier didn't load; T05 confirms it now actually rejects).
    - Assertion 2: `grep -q "REJECT" "${tmp_home}/hook-stderr.txt"` succeeds.
    - On all-pass, emit `PASS: finding-A — self-locating hook fires in non-orchestrator-repo CLAUDE_PROJECT_DIR context, classifier loaded, REJECT verdict surfaced` and clean up; exit 0.
    - On FAIL, leave the tmp dir for inspection and exit 1 with a descriptive `FAIL:` to stderr.

    **Important**: if the M021 hook protocol's exit codes are different in the current implementation (e.g., reject is exit 1 not exit 2), the verifier must match the actual protocol. Read `scripts/hooks/pre-bash-shape-guard.sh` to confirm the protocol before authoring the verifier; the file's header comment (lines 1–18 at the M021 baseline) documents it.

3. Author `scripts/verify/m028/finding-F-verifier.sh`. Single-file flat shape, ≥ 20 lines, bash 3.2. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root.
    - Sets `tmp_home="${TMPDIR:-/tmp}/m028-finding-F-$$"`.
    - Runs installer with `HOME="$tmp_home"` to stage payload + register hooks.
    - Reads `${tmp_home}/.claude/settings.json`, extracts the Stop-event command string. Pattern: write the file to a temp work file and use `grep` + `sed` to extract the `"command":` value under the Stop array. Plain pattern: `python3 -c "import json,sys; s=json.load(open('${tmp_home}/.claude/settings.json')); print(s['hooks']['Stop'][0]['hooks'][0]['command'])" > "${tmp_home}/stop-cmd.txt"`. (python3 is the baseline per M025/P01/T02; OK to use here.)
    - Reads the command: `stop_cmd="$(awk '{print $0}' "${tmp_home}/stop-cmd.txt")"` — wait, this captures the full line; for a single-line file, plain `read`: `read -r stop_cmd < "${tmp_home}/stop-cmd.txt"`.
    - Assertion 1: `stop_cmd` starts with `bash ` (literal). Pattern: `case "$stop_cmd" in 'bash '*) ;; *) echo "FAIL: stop_cmd does not start with 'bash ': $stop_cmd" >&2; exit 1 ;; esac`.
    - Assertion 2: `stop_cmd` ends with `.sh`. Pattern: `case "$stop_cmd" in *'.sh') ;; *) echo "FAIL: stop_cmd does not end with .sh: $stop_cmd" >&2; exit 1 ;; esac`.
    - Assertion 3: the resolved command file exists. Extract the path from `stop_cmd` (strip the leading `bash `): `cmd_path="${stop_cmd#bash }"`. Then `[ -f "$cmd_path" ]` else FAIL.
    - Assertion 4: invoke the resolved command with a minimal Stop-event stdin and assert no `command not found` on stderr. Pattern: emit a tiny JSON Stop event to stdin via heredoc-redirect, capture stderr, grep for `command not found`. The script `after-verify-sync.sh` may exit non-zero in an isolated test context (it depends on M025 lifecycle state); the gate is "no `command not found`", not "exit 0". Pattern: `bash "$cmd_path" < /dev/null > "${tmp_home}/stop-stdout.txt" 2> "${tmp_home}/stop-stderr.txt"; sync_rc=$?` — then `if grep -q 'command not found' "${tmp_home}/stop-stderr.txt"; then echo "FAIL: command not found on Stop event"; exit 1; fi`.
    - On all-pass, emit `PASS: finding-F — Stop event resolves $cmd_path, no command-not-found diagnostic` to stdout, clean up tmp dir, exit 0.

4. Run all three verifiers via `scripts/util/run-probe.sh`:

    ```bash
    bash scripts/util/run-probe.sh scripts/verify/m028/install-roundtrip.sh
    bash scripts/util/run-probe.sh scripts/verify/m028/finding-A-verifier.sh
    bash scripts/util/run-probe.sh scripts/verify/m028/finding-F-verifier.sh
    ```

    Confirm all three PASS. If any FAIL, root-cause via the FAIL diagnostic — the tmp dir is left in place on FAIL for inspection.

5. Document a known-pinned post-install SHA in `.orchestrator/milestones/M028/phases/P02/P02-VERIFICATION.md` (or in the verifier comment block) for the install-roundtrip output. Pattern: capture `sha1` from a known-good run and pin it as a comment in `install-roundtrip.sh`. Future drift is then detectable by simple inspection — if `sha1` changes without an explanatory M028 change, something silently broke. (This is informational pinning, not a hard gate; the hard gate is the idempotency + reversibility assertions.)

## Must-Haves

This task addresses three phase Truths:
- "`settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal)." (T05's `install-roundtrip.sh` is the canonical-bytes proof.)
- "`bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes." (Same gate, reversibility leg.)
- "The Finding A end-to-end verifier passes" / "The Finding F end-to-end verifier passes."

It produces three verifiers: `install-roundtrip.sh`, `finding-A-verifier.sh`, `finding-F-verifier.sh`.

## Verification

```bash
bash scripts/verify/m028/install-roundtrip.sh
```

```bash
bash scripts/verify/m028/finding-A-verifier.sh
```

```bash
bash scripts/verify/m028/finding-F-verifier.sh
```

## Notes

Expected output for `install-roundtrip.sh`: `PASS: install-roundtrip idempotency=<sha1-hex> reversibility=<sha0-hex>` (sha0 may be the literal string `EMPTY` if pre-install settings.json did not exist).

Expected output for `finding-A-verifier.sh`: `PASS: finding-A — self-locating hook fires in non-orchestrator-repo CLAUDE_PROJECT_DIR context, classifier loaded, REJECT verdict surfaced`.

Expected output for `finding-F-verifier.sh`: `PASS: finding-F — Stop event resolves <absolute-path>/after-verify-sync.sh, no command-not-found diagnostic`.

The install-roundtrip gate is the canonical-bytes proof for SC-2. The pinned-SHA comment in the verifier (Step 5) is the audit trail; future M028 changes that affect the JSON shape will alter the SHA and the comment must be updated in the same PR — that drift IS the audit signal.

The Finding A verifier's choice of `bash -c 'a && b && c && d && e'` as the test command is deliberate: 4 `&&` connectors guaranteed reject AP-009 under both M021 and M028 classifiers (no risk of P03's classifier extension changing the verdict). The verifier is stable across M028's classifier evolution.

The Finding F verifier's `command not found` grep is a substring check — the actual CC error format may be `bash: <cmd>: command not found` or similar; the substring `command not found` is robust to both forms.

These three verifiers, together with the four T01–T04 verifiers, constitute P02's verification surface (8 verifiers total). P05's `run-all.sh` (Phase 5 deliverable) will aggregate these plus P03/P04 verifiers into a single CI gate.

## Inputs

### From Previous Tasks

- `scripts/hooks/pre-bash-shape-guard.sh` (from T01) — self-locating hook. Finding-A verifier exercises end-to-end.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (from T02) — emits absolute-path leaves. Indirectly exercised via install-roundtrip + finding-F (which reads the post-install settings.json).
- `packaging/install/install-claude-code.sh` (from T03 + T04) — installer with payload-staging, settings-merge dedup, `--repair`, and `--uninstall`. T05's roundtrip exercises install + install + uninstall.
- `scripts/util/settings-merge.sh` (from T03) — `(event, matcher, command)` tuple dedup. Indirectly exercised by install-roundtrip's idempotency leg.

### From Disk (Pre-existing)

- `scripts/lifecycle/after-verify-sync.sh` — M025 lifecycle script. Finding-F verifier invokes it with stub stdin.
- `scripts/util/run-probe.sh` — shape-safe wrapper for verifier invocation.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: all three verifiers are flat single-file scripts. SHA computation uses helper functions (function bodies are not classifier-scanned) + tmp-file + awk pattern; no `$(... | ...)` and no `cmd <file` nested inside `$()`. The Stop-command extraction uses python3 + write-to-tmp-file + read. The hook-output extraction uses redirect, not pipe.
- **bash 3.2 + POSIX sh (CON-2)**: every line runs on bash 3.2.
- **No new runtime deps (CON-6)**: T05 uses python3 (M025 baseline), `shasum`, `awk`, `grep`, `case`-pattern matching. No new deps.
- **M025 reversibility (CON-4)**: install-roundtrip.sh is the canonical-bytes proof. The `Snapshot 0 == Snapshot 3` assertion is the contract.
- **Non-Goal: classifier extension**: T05's Finding A verifier uses an AP-009-rejected test command (compound chain > 2). It does NOT exercise AP-010..AP-014 (P03's classifier extension) — those are tested by P03's per-finding-B/G verifiers. T05's scope is hook portability + adapter emission + installer idempotency.
- **Tmp-dir hygiene**: every verifier cleans up its tmp dir on PASS. On FAIL, the tmp dir is preserved for post-mortem inspection (per the existing M021/M025 verifier convention).
- **Hook protocol stability**: T05's Finding A verifier asserts on the hook's exit code (likely 2 for reject) and stderr substring (`REJECT`). If the hook protocol changes in a future M028 phase, the verifier must be re-aligned. T05 reads the current protocol from the hook's header comment before authoring.
