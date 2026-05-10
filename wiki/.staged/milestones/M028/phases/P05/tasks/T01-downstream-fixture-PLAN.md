---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M028"
name: "Permanent downstream-project fixture + shape verifier"
depends_on: []
---

## Prerequisites

Plan-author empirically verified each path on disk at plan-authoring time:

- `scripts/dispatch/adapters/runtime/claude-code.sh` exists (P02/T02 — emits the runtime-stable `~/.claude/orchestrator-hooks/` `--hook-config` shape that this fixture mirrors).
- `tests/fixtures/` exists in-tree (other M028 fixtures — `m028-pre-repair-snapshot.json`, `m028-post-repair-canonical.json`, `m021-prompt-corpus.txt` — are co-located here).
- `scripts/verify/m028/` exists (P02/P03/P04 verifier suite is the sibling directory of this task's deliverable).

Files this task creates from scratch (no prior versions):
- `tests/fixtures/downstream-project/.claude/settings.json`
- `tests/fixtures/downstream-project/README.md`
- `scripts/verify/m028/p05-fixture-permanent.sh`
- `scripts/verify/m028/p05-downstream-fixture-shape.sh`

## Description

Stage the permanent in-tree consumer-project fixture under `tests/fixtures/downstream-project/`. The fixture is intentionally shaped like a *minimal* consumer of the orchestrator skill bundle: it has its own `.claude/settings.json` whose hook entries point at `~/.claude/orchestrator-hooks/<name>.sh` (the runtime-stable install location P02 established) and it has NO internal `scripts/hooks/` directory. T02's replay harness consumes this fixture; T03's regression gate sequences T02's harness as one of four sub-gates.

The fixture is permanent (CON-10 — not generated at test time). It lives in-tree under version control so future authors and CI can re-run M028's close-out without staging-time prep. The accompanying `README.md` documents the fixture's purpose and the noisy-fail discipline (if the runtime adapter's emission shape drifts, this fixture's `.claude/settings.json` falls out of sync and the shape verifier fails loudly).

This task also authors `scripts/verify/m028/p05-downstream-fixture-shape.sh`, the verifier that asserts the fixture's `.claude/settings.json` matches the runtime adapter's current `--hook-config` emission shape (CON-10 byte-shape compatibility — every `command` field starts with `bash ` and ends with `.sh`; every leaf hook object carries `_orchestrator_managed: true`; the count of leaf hooks in the fixture matches the count emitted by `--hook-config`).

T01 also authors a separate cross-cutting plan-level verifier `scripts/verify/m028/p05-fixture-permanent.sh` that asserts the fixture path exists in-tree (existence check on the directory + the two key files) — this is the Truth-Check for the "fixture is permanent in-tree" phase Truth.

## Steps

### Round 1 — Stage the permanent fixture

1. Create the fixture directory tree:
   - `tests/fixtures/downstream-project/`
   - `tests/fixtures/downstream-project/.claude/`

2. Author `tests/fixtures/downstream-project/.claude/settings.json` with the exact content below. The shape mirrors `scripts/dispatch/adapters/runtime/claude-code.sh::--hook-config` emission verbatim, with the `${HOME}` path substituted as the literal placeholder string `~/.claude/orchestrator-hooks` (the verifier T01 also authors strips the `~` and replaces with `${HOME}` at compare time, OR — preferred — the fixture writes the literal `~/.claude/orchestrator-hooks` token and the verifier asserts the substring shape rather than the literal expanded path). Alternative: write `${HOME}/.claude/orchestrator-hooks` literally — the verifier compares the *shape pattern* not the literal expansion.

   **Choice (record in commit message)**: write the literal path `${HOME}/.claude/orchestrator-hooks` (the unexpanded placeholder form) so the fixture is HOME-agnostic and the verifier compares shape:

   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             { "type": "command", "command": "bash ${HOME}/.claude/orchestrator-hooks/after-verify-sync.sh", "_orchestrator_managed": true }
           ]
         }
       ],
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "bash ${HOME}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh", "_orchestrator_managed": true },
             { "type": "command", "command": "bash ${HOME}/.claude/orchestrator-hooks/before-commit.sh", "_orchestrator_managed": true }
           ]
         }
       ]
     }
   }
   ```

   This file is NOT meant to be parsed by Claude Code at runtime — it is a regression fixture asserting shape compatibility. The replay harness in T02 stages a fresh isolated `HOME` and runs the installer to produce the *runtime* `~/.claude/settings.json`; this fixture is the *contract reference* for what the adapter emission shape should look like.

3. Author `tests/fixtures/downstream-project/README.md` (~30 lines). Plain markdown explaining:

   - The fixture's purpose: minimal consumer-project `.claude/settings.json` shape that mirrors the runtime adapter's `--hook-config` emission.
   - The noisy-fail discipline: if `scripts/dispatch/adapters/runtime/claude-code.sh::--hook-config` shape drifts (e.g., a new hook event lands, a `matcher` changes, a leaf is renamed), `scripts/verify/m028/p05-downstream-fixture-shape.sh` fails loudly and this fixture must be updated to match.
   - Permanent fixture status (CON-10) — checked into version control, not generated at test time.
   - Cross-references: `scripts/dispatch/adapters/runtime/claude-code.sh` (canonical adapter), `scripts/verify/m028/p05-downstream-fixture-shape.sh` (shape gate), `tests/run-downstream-fixture.sh` (T02 replay harness).

   Required content (verifier will assert presence of literal substrings — keep them):
   - The basename `downstream-project` (verifier asserts this token is present so a misnamed copy doesn't accidentally pass).
   - The substring `_orchestrator_managed` (so the README documents the [M025](../../../../../milestones/M025/index.md) invariant).
   - The substring `~/.claude/orchestrator-hooks/` (so the README documents the runtime-stable hooks dir convention).

### Round 2 — Author `scripts/verify/m028/p05-fixture-permanent.sh`

4. Create `scripts/verify/m028/p05-fixture-permanent.sh` (~40 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Contract: existence-only check on the fixture directory and its two key files:
   - `tests/fixtures/downstream-project/` (directory exists).
   - `tests/fixtures/downstream-project/.claude/settings.json` (file exists, min 8 lines).
   - `tests/fixtures/downstream-project/README.md` (file exists, min 6 lines, contains `downstream-project` substring).

   Resolve `REPO_ROOT` via `script_dir/../../..` (matches sibling P02/P03/P04 verifier convention).

   Exit 0 on all PASS; exit 1 on any FAIL with `FAIL: <description> (<reason>)` lines on stderr.

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-fixture-permanent.sh -- M028/P05/T01 cross-cutting verifier.
   #
   # Asserts the permanent in-tree downstream-project fixture (CON-10) exists
   # at tests/fixtures/downstream-project/ with its .claude/settings.json and
   # README.md present and minimally populated.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
   FIXTURE_DIR="${REPO_ROOT}/tests/fixtures/downstream-project"

   fail_count=0
   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   if [ -d "$FIXTURE_DIR" ]; then
     pass "fixture dir exists at $FIXTURE_DIR"
   else
     fail "fixture dir exists" "missing $FIXTURE_DIR"
   fi

   settings="${FIXTURE_DIR}/.claude/settings.json"
   if [ -f "$settings" ]; then
     lines=$(wc -l < "$settings")
     if [ "$lines" -ge 8 ]; then
       pass ".claude/settings.json present (>=8 lines)"
     else
       fail ".claude/settings.json line count" "got $lines"
     fi
   else
     fail ".claude/settings.json present" "missing $settings"
   fi

   readme="${FIXTURE_DIR}/README.md"
   if [ -f "$readme" ]; then
     lines=$(wc -l < "$readme")
     if [ "$lines" -ge 6 ]; then
       pass "README.md present (>=6 lines)"
     else
       fail "README.md line count" "got $lines"
     fi
     if grep -q 'downstream-project' "$readme"; then
       pass "README.md mentions downstream-project"
     else
       fail "README.md substring" "missing downstream-project token"
     fi
   else
     fail "README.md present" "missing $readme"
   fi

   if [ "$fail_count" -eq 0 ]; then
     echo "PASS: p05-fixture-permanent.sh"
     exit 0
   fi
   echo "FAIL: p05-fixture-permanent.sh ($fail_count failures)"
   exit 1
   ```

### Round 3 — Author `scripts/verify/m028/p05-downstream-fixture-shape.sh`

5. Create `scripts/verify/m028/p05-downstream-fixture-shape.sh` (~70 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Contract: shape-compatibility check between the fixture's `.claude/settings.json` and the runtime adapter's `--hook-config` emission. The verifier:

   1. Captures the runtime adapter's emission via `HOME=/tmp/m028-p05-shape-$$ bash scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` (or any safe non-`/` non-empty `HOME`). Save to `${tmp}/adapter-emission.json`.
   2. Asserts the fixture file exists.
   3. Asserts every `"command":` line in the fixture matches the shape `"command": "bash <something>.sh"` (regex `"command": "bash [^"]*\.sh"`).
   4. Asserts every `"command":` line in the adapter emission matches the same shape.
   5. Asserts the count of `_orchestrator_managed` flags in the fixture equals the count of `_orchestrator_managed` flags in the adapter emission (currently 3 — Stop=1, PreToolUse=2). Drift in either direction (adapter adds a hook, fixture not updated; fixture adds a hook, adapter not updated) fails the verifier.
   6. Asserts the count of `command` keys in the fixture equals the count of `command` keys in the adapter emission.
   7. Asserts the fixture's `Stop` hook command path basename is `after-verify-sync.sh` AND appears in the adapter emission.
   8. Asserts the fixture's `PreToolUse` Bash hook commands include the basenames `pre-bash-shape-guard.sh` AND `before-commit.sh` AND both basenames appear in the adapter emission.

   Helper-function carve-out: extraction helpers (using `awk`/`grep`/`wc`) live inside bash function bodies for AD-19 helper-function carve-out (function bodies are NOT classifier-scanned per M028/P02/T05).

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-downstream-fixture-shape.sh -- M028/P05/T01 shape gate.
   #
   # CON-10 noisy-fail: if the runtime adapter's --hook-config emission shape
   # drifts (new hook event, renamed leaf, changed matcher), this verifier
   # fails loudly so the fixture must be updated to match.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
   FIXTURE="${REPO_ROOT}/tests/fixtures/downstream-project/.claude/settings.json"
   ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh"

   fail_count=0
   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   # Helper-function carve-out: function bodies are NOT classifier-scanned
   # per M028/P02/T05 codification. Extraction helpers live here.
   count_command_lines() {
     # arg1 = file; emits count of `"command":` substring matches.
     grep -c '"command":' "$1"
   }
   count_managed_flags() {
     grep -c '"_orchestrator_managed": true' "$1"
   }
   all_commands_have_shape() {
     # arg1 = file; returns 0 if every `"command":` line matches
     # `"command": "bash <...>.sh"`.
     local file="$1"
     local total
     local matching
     total=$(grep -c '"command":' "$file")
     matching=$(grep -cE '"command": "bash [^"]*\.sh"' "$file")
     [ "$total" -eq "$matching" ]
   }

   if [ ! -f "$FIXTURE" ]; then
     fail "fixture present" "missing $FIXTURE"
     echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
     exit 1
   fi
   pass "fixture present at $FIXTURE"

   if [ ! -f "$ADAPTER" ]; then
     fail "adapter present" "missing $ADAPTER"
     echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
     exit 1
   fi

   tmp_dir="$(mktemp -d)"
   trap 'rm -rf "$tmp_dir"' EXIT
   adapter_out="${tmp_dir}/adapter-emission.json"
   safe_home="${tmp_dir}/fake-home"
   mkdir -p "$safe_home"
   HOME="$safe_home" bash "$ADAPTER" --hook-config > "$adapter_out" 2>"${tmp_dir}/adapter.err"
   ac=$?
   if [ "$ac" -ne 0 ]; then
     fail "adapter --hook-config exit 0" "rc=$ac"
     cat "${tmp_dir}/adapter.err" >&2
     echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
     exit 1
   fi
   pass "adapter --hook-config exit 0"

   if all_commands_have_shape "$FIXTURE"; then
     pass "fixture commands all match shape: bash <...>.sh"
   else
     fail "fixture command shape" "non-conforming command line"
   fi

   if all_commands_have_shape "$adapter_out"; then
     pass "adapter commands all match shape: bash <...>.sh"
   else
     fail "adapter command shape" "non-conforming command line"
   fi

   fix_managed=$(count_managed_flags "$FIXTURE")
   adp_managed=$(count_managed_flags "$adapter_out")
   if [ "$fix_managed" -eq "$adp_managed" ]; then
     pass "_orchestrator_managed flag count matches (fixture=$fix_managed adapter=$adp_managed)"
   else
     fail "_orchestrator_managed flag count" "fixture=$fix_managed adapter=$adp_managed"
   fi

   fix_cmd=$(count_command_lines "$FIXTURE")
   adp_cmd=$(count_command_lines "$adapter_out")
   if [ "$fix_cmd" -eq "$adp_cmd" ]; then
     pass "command line count matches (fixture=$fix_cmd adapter=$adp_cmd)"
   else
     fail "command line count" "fixture=$fix_cmd adapter=$adp_cmd"
   fi

   for basename in after-verify-sync.sh pre-bash-shape-guard.sh before-commit.sh; do
     if grep -q "$basename" "$FIXTURE" && grep -q "$basename" "$adapter_out"; then
       pass "$basename present in both fixture and adapter emission"
     else
       fail "$basename presence" "missing in one or both"
     fi
   done

   if [ "$fail_count" -eq 0 ]; then
     echo "PASS: p05-downstream-fixture-shape.sh"
     exit 0
   fi
   echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
   exit 1
   ```

### Round 4 — Plan-time empirical pre-validation

6. Plan-author confirms each `## Verification` line below classifies as `allow` under the M028 classifier. Each Verification line is a single-stage `bash <path>.sh` invocation — no nested cmdsub, no compound chain, no quoted-arg-newline-hash, no AP-014 body. Internal verifier-body bodies (function definitions, conditionals) are not classifier-scanned (helper-function + at-rest-script carve-out).

7. Do NOT create a git commit; the orchestrator handles phase-boundary commits at phase close.

## Must-Haves

This task addresses the phase Truths:

- "`tests/fixtures/downstream-project/` exists in-tree" — addressed by Steps 1–3 + verified by `p05-fixture-permanent.sh` (Step 4).
- "The fixture's `.claude/settings.json` is byte-shape-compatible with the runtime adapter's current `--hook-config` emission" — addressed by Step 2 + verified by `p05-downstream-fixture-shape.sh` (Step 5).

## Verification

```bash
bash scripts/verify/m028/p05-fixture-permanent.sh
```

```bash
bash scripts/verify/m028/p05-downstream-fixture-shape.sh
```

## Notes

Expected output of `bash scripts/verify/m028/p05-fixture-permanent.sh`:

- Five `PASS:` lines (fixture dir, settings.json, settings.json line count, README.md, README.md substring).
- Final `PASS: p05-fixture-permanent.sh` line.
- Exit 0.

Expected output of `bash scripts/verify/m028/p05-downstream-fixture-shape.sh`:

- ~9 `PASS:` lines covering: fixture present, adapter exit 0, fixture command shape, adapter command shape, managed-flag count, command-line count, three basename presences (after-verify-sync.sh, pre-bash-shape-guard.sh, before-commit.sh).
- Final `PASS: p05-downstream-fixture-shape.sh` line.
- Exit 0.

If either verifier reports any FAIL line, the task is incomplete: re-read the failing assertion and adjust the fixture or verifier accordingly. The most likely failure modes are: (a) the JSON file has fewer than 8 lines (compact-format JSON — re-format with one key per line); (b) the adapter emits a different hook count than the fixture has (a fourth hook event was added to the adapter; the fixture must be updated to match — this is the CON-10 noisy-fail discipline working as designed).

## Inputs

### From Previous Tasks

None. T01 is the first task in P05 and creates the fixture from scratch.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/runtime/claude-code.sh` — the canonical runtime adapter (P02/T02 deliverable). Its `--hook-config` mode emits the JSON shape this fixture mirrors. The shape verifier captures the adapter's emission live and compares it to the fixture.
- `tests/fixtures/` directory — pre-existing in-tree fixture parent.

## Constraints

- **CON-1 (AD-19)**: Both verifiers are flat single-file shapes under `scripts/verify/m028/`. No nested helpers; helper functions are inline (carve-out documented at top-of-file).
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<` (here-strings), no `declare -A`, no `[[` regex outside guarded contexts. The verifier uses `grep -E` for regex and `case` for pattern matching.
- **CON-6 (no new runtime deps)**: Pure bash + `grep`/`awk`/`wc`/`mktemp`. No jq.
- **CON-10 (downstream-fixture permanence)**: The fixture is in-tree, version-controlled, NOT generated at test time. Drift between adapter emission and fixture fails the shape verifier loudly (noisy-fail).
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly via `bash scripts/verify/m028/<name>.sh`. No `run-probe.sh` wrapping. Both verifiers exist on disk by end of this task (co-authored with the deliverable per CLAUDE.md plan-time verifier-availability discipline).
- **Plan-time classifier-shape pre-validation**: Each `## Verification` line was classified at plan-authoring time — both lines resolve to `allow` (single-stage `bash <path>.sh` invocation, no nested cmdsub, no compound chain).
- **Commit-message form (when applicable)**: `git commit -F <file>`. T01 itself does NOT commit; the orchestrator handles phase-boundary commits.

## Expected Output

After the two `## Verification` lines run cleanly, T01 has shipped:

1. The permanent fixture at `tests/fixtures/downstream-project/` containing `.claude/settings.json` (the contract reference for the adapter emission shape) and `README.md` (the documentation of the noisy-fail discipline).
2. Two new verifiers under `scripts/verify/m028/`: `p05-fixture-permanent.sh` (existence Truth-Check) and `p05-downstream-fixture-shape.sh` (CON-10 noisy-fail Truth-Check).

T02 will consume the fixture as input to the autonomous-loop replay harness; T03 will sequence both verifiers in the regression gate; T04 will roll up the phase Truth-Checks via `check-must-haves.sh`.
