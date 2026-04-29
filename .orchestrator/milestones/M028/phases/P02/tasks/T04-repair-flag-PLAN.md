---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M028"
name: "--repair flag with --dry-run preview (FR-7)"
depends_on: ["T03"]
---

## Prerequisites

- **T03 complete**: `packaging/install/install-claude-code.sh` has the hooks-payload staging step and the extended uninstall block; `scripts/util/settings-merge.sh` has the `(event, matcher, command)` tuple dedup key. T04 extends the same installer file with a NEW `--repair` mode that operates on the same settings.json target and the same `_orchestrator_managed: true` invariant. Confirm T03's `p02-hooks-payload-staged.sh` PASSes before starting T04.
- `tests/fixtures/m028-pre-repair-snapshot.json` exists (P01/T02 deliverable). This is the canonical pre-repair fixture: sanitized snapshot of the operator's M018-close `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` containing 5 unflagged + 1 flagged Stop entries and 7 unflagged + 1 flagged PreToolUse Bash entries. The unflagged entries are the M025 orphans `--repair` removes; the flagged entries are the post-M025 orchestrator-managed entries that survive.
- The known M025 pattern fingerprints are documented per Architectural Decisions in `M028-CONTEXT.md`. Specifically, the orphan tuples are entries whose `command` field literally matches one of:
    - `orchestrator-post-verify` (Stop event, no matcher) — pre-T02 bare-name shape
    - `orchestrator-before-commit` (PreToolUse event, matcher `Bash`) — pre-T02 bare-name shape
- `scripts/util/settings-merge.sh` exposes the python3-baseline merge implementation that T04 reuses for JSON read/write. T04 adds a NEW subcommand `repair` (alongside the existing `merge` and `uninstall`) so the heavy JSON manipulation stays inside `settings-merge.sh` and the installer's `--repair` flag is a thin shim.

## Description

Add `--repair` and `--repair --dry-run` flags to `packaging/install/install-claude-code.sh`. Add a new subcommand `repair` to `scripts/util/settings-merge.sh` that does the JSON manipulation. Land a verifier under `scripts/verify/m028/` that exercises the repair path against the P01/T02 canonical pre-repair fixture and asserts the result matches a canonical post-repair reference fixture.

The repair algorithm:
1. Read target settings.json. If not valid JSON, exit 4 (matches existing `settings-merge.sh` semantics).
2. For each `event` in `target.hooks` (Stop, PreToolUse, ...):
    - For each wrapper in the event's array:
        - Compute `matcher` (default empty string).
        - For each leaf in `wrapper.hooks`:
            - If leaf has `_orchestrator_managed: true`, KEEP.
            - Else if `(event, matcher, leaf.command)` matches a known M025 orphan fingerprint, REMOVE.
            - Else (user-authored), KEEP.
        - Cascade cleanup: if a wrapper's `hooks` array is empty after the pass, drop the wrapper.
        - If an event's array is empty after the wrapper pass, drop the event key.
        - If `target.hooks` is empty, drop the `hooks` key entirely.
3. Write via temp-file-then-rename (matches existing `settings-merge.sh` pattern).
4. Report `repaired=<N>` (count of removed orphans) and `preserved=<M>` (count of preserved user-authored + flagged entries) on stdout.

The `--dry-run` mode does not write; instead it emits per-orphan-line previews:
- `would_remove=<event>:<matcher>:<command>` for each orphan
- `would_preserve=<event>:<matcher>:<command>` for each kept entry
- Final `would_repair=<N> would_preserve=<M> dry_run=1` summary line

Land one new verifier under `scripts/verify/m028/`:
- `p02-repair-fixture.sh` — copies the P01/T02 canonical pre-repair snapshot to a tmp working file, runs `bash packaging/install/install-claude-code.sh --repair` against it (with `HOME` redirected to the tmp dir), computes the SHA-256 of the result, and asserts it matches the SHA-256 of `tests/fixtures/m028-post-repair-canonical.json` (which T04 also creates as a one-time canonical reference fixture).

The known M025 orphan fingerprint table is hard-coded inside `settings-merge.sh repair`:

| event       | matcher | command                       |
|-------------|---------|-------------------------------|
| Stop        | (empty) | orchestrator-post-verify      |
| PreToolUse  | Bash    | orchestrator-before-commit    |

Future M028 follow-ups MAY extend the table; the contract is exact-tuple match, never structural-shape match. A user-authored hook entry that happens to have one of these tuples but is not the orchestrator's emission survives if it carries a non-empty user-provided key outside the M025-known set (e.g., a custom `description` field) — the repair pass requires a STRICT match: ONLY the exact `{event, matcher, command}` triple AND no extra non-orchestrator-known fields. Implementer note: this strictness is the spec's Edge Cases item "user-authored hook entry that happens to match" — see CON-4 + Edge Cases.

## Steps

1. Read `packaging/install/install-claude-code.sh` end to end (post-T03 state). Identify the argument-parsing block (lines ~46–75) and the `--uninstall` mode block (lines ~91–158). T04 inserts a NEW `--repair` mode after the `--uninstall` block.

2. Add argument-parsing entries for `--repair` and `--repair --dry-run`. The `--dry-run` flag is already parsed (current line ~60); the new `--repair` flag composes with it. Insert after the `--uninstall` case block in the while loop:

    ```bash
    --repair)
      REPAIR=1; shift ;;
    ```

    And initialize `REPAIR=0` in the variable initialization block (current lines ~40–44).

3. Insert the `--repair` mode block after the `--uninstall` block, before the `--probe` invocation. Verbatim shape:

    ```bash
    # --- 2'. --repair: remove flag-less M025 orphans by exact-tuple match (M028/P02/T04, FR-7) ---
    # The repair pass walks ~/.claude/settings.json and removes hook entries
    # whose (event, matcher, command) tuple matches a known M025 pattern but
    # which lack the _orchestrator_managed: true flag — exactly the manual
    # cleanup performed for the operator during M018 close. Strict-tuple
    # match: never structural-shape match; user-authored entries with
    # extra fields are preserved. --dry-run emits the diff without
    # mutating settings.json.
    if [ "${REPAIR:-0}" = "1" ]; then
      hook_target="${HOME}/.claude/settings.json"
      if [ ! -f "$hook_target" ]; then
        echo "SKIP: $hook_target not present, nothing to repair"
        exit 0
      fi

      if [ "$DRY_RUN" = "1" ]; then
        bash "$MERGE_HELPER" repair --target "$hook_target" --dry-run
        rep_rc=$?
      else
        bash "$MERGE_HELPER" repair --target "$hook_target"
        rep_rc=$?
      fi

      if [ "$rep_rc" -ne 0 ]; then
        echo "FAIL: settings-merge.sh repair exited $rep_rc" >&2
        exit 1
      fi

      exit 0
    fi
    ```

    Notes:
    - The `--repair` mode short-circuits the rest of the installer flow (no `--probe`, no payload staging, no runtime staging) — repair is a one-shot cleanup, not a re-install.
    - Each line ≤ 2 connectors per AP-009.
    - Exit 0 on success; exit 1 on `MERGE_HELPER` failure.

4. Add the `repair` subcommand to `scripts/util/settings-merge.sh`. Locate the existing `case "$SUBCMD" in` (or the equivalent dispatch — confirm by reading the file) and add a `repair)` arm. The arm:
    - Validates `$TARGET` is set.
    - Reads the target JSON with the same python3 read pattern the merge / uninstall arms use.
    - Walks `target.hooks` per the algorithm in the Description section.
    - Hard-codes the M025 orphan tuple table (Stop:::orchestrator-post-verify and PreToolUse:Bash:orchestrator-before-commit). Use a python list of tuples; readability matters because future M028 follow-ups may extend.
    - In `--dry-run` mode, emit `would_remove=<event>:<matcher>:<command>` lines and a summary `would_repair=<N> would_preserve=<M> dry_run=1`.
    - In write mode, perform the cascade cleanup, write via temp-then-rename, and emit `repaired=<N> preserved=<M>` summary.
    - Exit 0 on success.

    Implementer note: the existing `settings-merge.sh` has ~333 lines and centralizes its python3 invocation. T04's `repair` arm reuses the same heredoc-into-python3 pattern; expect ~60–80 added lines.

5. Author `tests/fixtures/m028-post-repair-canonical.json` as the canonical reference for the post-repair state. Take `tests/fixtures/m028-pre-repair-snapshot.json` (P01/T02 deliverable) and manually produce the expected post-repair output:
    - Drop the 5 unflagged Stop entries (matching tuple `Stop:::orchestrator-post-verify`).
    - Drop the 7 unflagged PreToolUse Bash entries (matching tuple `PreToolUse:Bash:orchestrator-before-commit`).
    - Keep the 1 flagged Stop entry and the 1 flagged PreToolUse Bash entry (carry `_orchestrator_managed: true`).
    - Cascade-clean any empty wrappers, empty event arrays, or empty `hooks` keys.
    - The result is the byte-stable canonical reference. Validate it parses as JSON via `python3 -c "import json; json.load(open('tests/fixtures/m028-post-repair-canonical.json'))"`.

6. Author `scripts/verify/m028/p02-repair-fixture.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Creates an isolated `HOME` under `${TMPDIR:-/tmp}/p02-repair-$$`.
    - Copies `tests/fixtures/m028-pre-repair-snapshot.json` to `${tmp_home}/.claude/settings.json` (`mkdir -p` the .claude dir first).
    - Runs the installer in `--repair` mode against the isolated HOME: `HOME="$tmp_home" bash "${REPO_ROOT}/packaging/install/install-claude-code.sh" --repair`.
    - Computes SHA-256 of the post-repair settings.json: `actual_sha="$(shasum -a 256 "${tmp_home}/.claude/settings.json" | cut -d ' ' -f 1)"` — note: `shasum -a 256 <file>` writes `<sha>  <path>` to stdout; `| cut -d ' ' -f 1` extracts the hash. **AD-19 pinch point**: `$(shasum ... | cut ...)` is `$(...)` containing a pipe, which AP-006 forbids. Mitigation: write the shasum output to a tmp file, then read with `cut`: `shasum -a 256 "${tmp_home}/.claude/settings.json" > "${tmp_home}/sha.txt"; actual_sha="$(cut -d ' ' -f 1 < "${tmp_home}/sha.txt")"`. The single redirect form `cut -d ' ' -f 1 < "${tmp_home}/sha.txt"` inside `$(...)` is `cmd <file` nested inside `$(...)` — also forbidden per AD-19's "cmd <file input redirection nested inside $()" entry. Final mitigation: `shasum -a 256 "${tmp_home}/.claude/settings.json" > "${tmp_home}/sha.txt"` then read with awk on a separate line: `actual_sha="$(awk '{print $1}' "${tmp_home}/sha.txt")"` — `$(...)` containing a single command with no pipe and no redirect is permitted.
    - Computes SHA-256 of `tests/fixtures/m028-post-repair-canonical.json` the same way (write to tmp file, awk-extract).
    - Asserts the two hashes are equal: `[ "$actual_sha" = "$expected_sha" ]`.
    - On match, emit `PASS: --repair against pre-repair snapshot produces canonical post-repair bytes (sha=${actual_sha:0:12}...)` to stdout and exit 0.
    - On mismatch, emit `FAIL: post-repair sha=$actual_sha expected=$expected_sha` to stderr, leave the tmp dir for inspection, and exit 1.
    - Cleans up the tmp dir on PASS only.

7. Run the verifier: `bash scripts/util/run-probe.sh scripts/verify/m028/p02-repair-fixture.sh`. Confirm `PASS`. If FAIL, the python repair logic in `settings-merge.sh` is producing a different cascade-cleanup than the manual canonical fixture expects — iterate by inspecting the diff and adjusting EITHER the python logic OR the canonical fixture, depending on which is wrong. The pre-repair fixture (P01/T02) is canonical and immutable; the post-repair canonical is constructed in T04 and adjustable.

8. Smoke-test the `--dry-run` mode manually: against an isolated HOME with the pre-repair fixture, run `bash packaging/install/install-claude-code.sh --repair --dry-run` and confirm 12 `would_remove=` lines + 2 `would_preserve=` lines (matching the 5+7 orphan removal and the 1+1 flagged preservation). Confirm settings.json was NOT modified by the dry-run.

## Must-Haves

This task addresses the phase Truth: "`bash packaging/install/install-claude-code.sh --repair` (and the `--repair --dry-run` preview) removes flag-less orphan entries whose `(event, matcher, command)` tuple matches a known M025 pattern fingerprint (exact-tuple match, never structural-shape match) and preserves user-authored entries verbatim."

It produces the verifier `scripts/verify/m028/p02-repair-fixture.sh` that gates this Truth, plus the canonical reference fixture `tests/fixtures/m028-post-repair-canonical.json`.

## Verification

```bash
bash scripts/verify/m028/p02-repair-fixture.sh
```

## Notes

Expected output is a single line `PASS: --repair against pre-repair snapshot produces canonical post-repair bytes (sha=<first 12 hex chars>...)`.

The strict-tuple match (vs structural-shape match) is the load-bearing safety floor per Edge Cases item "`--repair` false-positive risk". A user-authored hook entry that legitimately predates orchestrator install but happens to share an event/matcher/command tuple is rare; if it ever does happen, the user can re-add their entry post-repair. The alternative — structural-shape match — would risk removing legitimate user entries and is explicitly out of scope.

The `--dry-run` mode is per Architectural Decisions in `M028-CONTEXT.md` ("`--repair` ergonomics extension"): the operator's M018-close manual cleanup wanted a preview before mutation; FR-7's `--dry-run` honors that direct experience.

The known M025 fingerprint table is hard-coded inside `settings-merge.sh repair` rather than externalized to a config file because the table is (a) small (2 entries today, expected to stay small), (b) versioned with the orchestrator code (every M025-shape change ships a new table entry), and (c) trivially auditable. Externalization is a future hardening pass if the table grows beyond ~10 entries.

The pre-repair fixture is sanitized — no user-specific paths, tokens, or emails per P01/T02. The post-repair canonical fixture inherits this sanitization (it is constructed from the pre-repair fixture) and is byte-stable across machines.

## Inputs

### From Previous Tasks

- `packaging/install/install-claude-code.sh` (from T03)
  - Key API: argument parsing, MERGE_HELPER variable already set, REPO_ROOT computed. T04 inserts the `--repair` mode block.
- `scripts/util/settings-merge.sh` (from T03)
  - Key API: `merge` and `uninstall` subcommands; python3 baseline. T04 adds a `repair` subcommand parallel to those.
  - The dedup key change in T03 is independent of T04's repair logic; both consume the same `_orchestrator_managed: true` flag invariant.

### From Disk (Pre-existing)

- `tests/fixtures/m028-pre-repair-snapshot.json` — P01/T02 canonical pre-repair fixture. Sanitized snapshot of operator's M018-close settings.json.bak. Read-only; T04 never writes to this file.
- `scripts/util/run-probe.sh` — shape-safe wrapper for verifier invocation.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: the new verifier `p02-repair-fixture.sh` is flat single-file. The shasum extraction pattern uses tmp-file + awk to avoid `$(... | ...)` and `cmd <file` nested inside `$()`. The installer's `--repair` mode block is straight-line bash with each line ≤ 2 connectors.
- **bash 3.2 + POSIX sh (CON-2)**: every line runs on bash 3.2.
- **No new runtime deps (CON-6)**: T04 uses python3 (already a baseline per M025), `shasum` (POSIX core util), `awk` (POSIX core util), and bash. No new deps.
- **Strict-tuple match (Edge Cases)**: the repair pass matches on EXACT `(event, matcher, command)` tuple, never on structural shape. User-authored entries with extra fields outside the M025-known set are preserved.
- **M025 reversibility (CON-4)**: the repair pass is one-directional — it removes orphans but does not re-add them. (Repair is not symmetric to uninstall; uninstall removes flagged entries, repair removes UNflagged entries that match known M025 fingerprints.) Both operations preserve user-authored entries.
- **Python3 baseline**: matches existing `settings-merge.sh` shape; no `jq` introduction.
- **Cascade cleanup**: after orphan removal, empty wrappers / empty event arrays / empty `hooks` keys are dropped, matching the existing `uninstall` cascade. This is the operator's M018-close cleanup made one-shot.
