---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M028"
name: "Autonomous-loop replay harness + clean verifier"
depends_on: ["T01"]
---

## Prerequisites

Plan-author empirically verified each path on disk at plan-authoring time:

- `packaging/install/install-claude-code.sh` exists (P02/T03 deliverable — the installer that stages the runtime-stable hooks dir).
- `scripts/hooks/pre-bash-shape-guard.sh` exists (P02/T01 deliverable, P03/T03 extended — the self-locating shape-guard hook).
- `scripts/lifecycle/after-verify-sync.sh` exists (the Stop-event lifecycle script the harness invokes to assert no `command not found`).
- `tests/fixtures/m021-prompt-corpus.txt` exists (P03/T04 deliverable — the 27-entry corpus this harness samples for Finding A/B/G replay lines).
- `scripts/verify/m028/finding-A-verifier.sh` exists (P02/T05 deliverable — the canonical pattern this harness mirrors for installer-staged HOME + JSON-on-stdin hook invocation).

Files this task creates from scratch:
- `tests/run-downstream-fixture.sh`
- `scripts/verify/m028/p05-downstream-fixture-clean.sh`

Files this task consumes (T01 deliverables, must exist by T02 dispatch time):
- `tests/fixtures/downstream-project/.claude/settings.json` (T01 — the contract reference, not the runtime settings the harness exercises).
- `tests/fixtures/downstream-project/README.md` (T01 — referenced for cross-link).

## Description

Author the autonomous-loop replay harness `tests/run-downstream-fixture.sh`. The harness exercises the M028 hook + lifecycle infrastructure end-to-end against an isolated `HOME` shaped like a real consumer-project context: it stages the installer's payload (`pre-bash-shape-guard.sh`, `shape-classifier.sh`, reject_lookup, lifecycle scripts) into a tmp `HOME/.claude/orchestrator-hooks/`, then replays a sequence of synthetic Bash hook events plus a Stop event invocation. The harness asserts:

1. The installer succeeds against the isolated HOME.
2. A verbatim Finding A 4-connector compound chain (`echo a && echo b && echo c && echo d`) — guaranteed to reject under both [M021](../../../../../milestones/M021/index.md) and M028 classifiers (AP-009 / compound-chain-gt2) — invoked through the staged hook with `CLAUDE_PROJECT_DIR` set to a non-orchestrator-repo path returns exit 2 with `REJECT:` on stderr.
3. The verbatim M028 corpus IDs 21..25 + 27 commands (the AP-010..AP-014 evidence entries) each invoked through the staged hook return exit 2 with `REJECT:` on stderr.
4. A benign allow-form command (`echo hello`) invoked through the staged hook returns exit 0 with no `REJECT:` substring (negative-control sanity check).
5. The Stop event is exercised by directly invoking `bash <hooks-dir>/after-verify-sync.sh` and asserting exit 0 + no `command not found` text on stderr.

Final harness summary: `WOULD_PROMPT=0/<N>` line where `<N>` is the count of replayed Bash events; the harness exits 0 only when every assertion passes.

T02 also authors `scripts/verify/m028/p05-downstream-fixture-clean.sh`, the cross-cutting Truth-Check verifier that invokes the harness, captures stdout, and asserts: (a) harness exit 0; (b) the canonical `WOULD_PROMPT=0/<N>` summary line is present; (c) zero `command not found` substrings in the harness output; (d) the harness reports `PASS:` lines for every assertion category (Finding A, Finding B/G corpus replay, Stop event). The clean verifier is what `check-must-haves.sh` invokes from the phase-level Truth-Check row.

## Steps

### Round 1 — Read corpus IDs 21..25, 27

1. Read `tests/fixtures/m021-prompt-corpus.txt` and extract the seven verbatim INPUT bytes for IDs 21, 22, 23, 24, 25, 27. The corpus grammar is: each entry is 4 lines (`# ID: NN ...`, blank, `INPUT: <verbatim bytes>`, `EXPECTED_OUTCOME: <verdict>`, `--- ` separator) — the existing replay harness `tests/run-prompt-corpus-replay.sh` parses this format and is the canonical reference. The plan-author has confirmed this format empirically by reading the corpus.

   The harness re-uses these INPUT bytes verbatim; do NOT paraphrase or re-author them. Either:
   - **Option A (preferred)**: source the existing parser logic via a small embedded awk block that extracts INPUTs for given IDs from the corpus file; the harness reads the corpus at runtime.
   - **Option B**: hard-code the seven INPUT strings as bash variables in the harness header. Higher byte-fidelity risk; reject unless Option A is impractical.

   Use Option A. The harness reads the corpus file via an awk filter at runtime; if the corpus IDs drift (a future M### renumbers), the harness fails noisily — symmetrical to the CON-10 noisy-fail discipline T01 established.

### Round 2 — Author `tests/run-downstream-fixture.sh`

2. Create `tests/run-downstream-fixture.sh` (~140 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Structural outline (the implementing agent fills helper-function bodies; the API-surface contract below is the binding shape):

   ```bash
   #!/usr/bin/env bash
   # tests/run-downstream-fixture.sh -- M028/P05/T02 autonomous-loop replay harness.
   #
   # Stages the installer payload into an isolated HOME, replays a sequence of
   # synthetic Bash hook events (Finding A + corpus IDs 21..25, 27 + a benign
   # allow-form negative control) plus a Stop event, and emits a final
   # WOULD_PROMPT=0/<N> summary line. Exits 0 only when every assertion
   # passes.
   #
   # The harness is consumed by:
   #   - scripts/verify/m028/p05-downstream-fixture-clean.sh (Truth-Check)
   #   - scripts/verify/m028/p05-regression-gate.sh (close-out gate sub-leaf)
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/.." && pwd -P)"
   INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"
   CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
   FIXTURE_DIR="${REPO_ROOT}/tests/fixtures/downstream-project"

   if [ ! -f "$INSTALLER" ]; then
     echo "FAIL: installer not found at $INSTALLER" >&2
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi
   if [ ! -f "$CORPUS" ]; then
     echo "FAIL: corpus not found at $CORPUS" >&2
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi
   if [ ! -d "$FIXTURE_DIR" ]; then
     echo "FAIL: downstream fixture not found at $FIXTURE_DIR" >&2
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi

   # --- Helper-function carve-out (per M028/P02/T05 codification): function
   #     bodies are NOT scanned by the AP-009 inline-shape classifier; the
   #     extraction + invocation helpers below contain $(...) substitutions
   #     and grep/awk pipelines that classify cleanly only because they live
   #     inside function bodies. ---

   tmp_home="${TMPDIR:-/tmp}/m028-p05-replay-$$"
   mkdir -p "$tmp_home"
   trap 'rm -rf "$tmp_home"' EXIT

   total=0
   would_prompt=0
   fail_count=0

   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   # Stage installer.
   HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
     --project-dir "$tmp_home" > "${tmp_home}/install.log" 2>&1
   ic=$?
   if [ "$ic" -ne 0 ]; then
     echo "FAIL: installer exited rc=$ic" >&2
     cat "${tmp_home}/install.log" >&2
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi
   pass "installer staged hooks payload at ${tmp_home}/.claude/orchestrator-hooks/"

   hook="${tmp_home}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh"
   if [ ! -f "$hook" ]; then
     fail "hook staged" "missing $hook"
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi

   stop_script="${tmp_home}/.claude/orchestrator-hooks/after-verify-sync.sh"
   if [ ! -f "$stop_script" ]; then
     fail "stop script staged" "missing $stop_script"
     echo "WOULD_PROMPT=N/A"
     exit 1
   fi

   fake_project="${tmp_home}/fake-project"
   mkdir -p "$fake_project"

   # invoke_hook: route a single command string through the staged hook and
   # assert the expected outcome. arg1=label, arg2=command, arg3=expected
   # ('reject' or 'allow').
   invoke_hook() {
     local label="$1"
     local cmd="$2"
     local expected="$3"
     total=$((total + 1))
     local event="${tmp_home}/event-${total}.json"
     # Write JSON via printf to avoid heredoc-with-expansion (AP-008).
     # We need to escape backslashes and double-quotes inside cmd for valid
     # JSON. Use bash parameter expansion (function-body carve-out applies).
     local safe="$cmd"
     safe="${safe//\\/\\\\}"
     safe="${safe//\"/\\\"}"
     printf '{ "tool_name": "Bash", "tool_input": { "command": "%s" } }\n' "$safe" > "$event"

     local out_tmp="${tmp_home}/hook-stdout-${total}.txt"
     local err_tmp="${tmp_home}/hook-stderr-${total}.txt"
     HOME="$tmp_home" CLAUDE_PROJECT_DIR="$fake_project" \
       bash "$hook" < "$event" > "$out_tmp" 2> "$err_tmp"
     local rc=$?

     if [ "$expected" = "reject" ]; then
       if [ "$rc" -eq 2 ] && grep -q 'REJECT' "$err_tmp"; then
         pass "${label} -> REJECT (rc=2 + REJECT on stderr)"
       else
         fail "${label}" "expected REJECT (rc=2 + REJECT) got rc=$rc"
         would_prompt=$((would_prompt + 1))
       fi
     else
       if [ "$rc" -eq 0 ] && ! grep -q 'REJECT' "$err_tmp"; then
         pass "${label} -> ALLOW (rc=0 no REJECT)"
       else
         fail "${label}" "expected ALLOW (rc=0 no REJECT) got rc=$rc"
         would_prompt=$((would_prompt + 1))
       fi
     fi
   }

   # extract_corpus_input: extract the INPUT bytes for a given corpus ID.
   # The corpus grammar is the M028/P03/T04 4-line entry:
   #   # ID: NN ...
   #   INPUT: <verbatim>
   #   EXPECTED_OUTCOME: <verdict>
   #   ---
   # The replay harness uses awk with the same id-anchored extraction shape
   # tests/run-prompt-corpus-replay.sh established (printf %b for the
   # literal-backslash-n decoding when present).
   extract_corpus_input() {
     awk -v id="$1" '
       /^# ID:/ {
         current = $3
       }
       current == id && /^INPUT:/ {
         sub(/^INPUT: /, "")
         print
         exit
       }
     ' "$CORPUS"
   }

   # Finding A: bare 4-connector AP-009 compound chain (matches the
   # finding-A-verifier.sh canonical assertion).
   invoke_hook "Finding-A AP-009 4-connector compound" \
     "echo a && echo b && echo c && echo d" \
     "reject"

   # Corpus IDs 21..25, 27 (AP-010..AP-014 evidence entries + AP-014 boundary).
   for cid in 21 22 23 24 25 27; do
     raw="$(extract_corpus_input "$cid")"
     if [ -z "$raw" ]; then
       fail "corpus ID $cid extraction" "empty INPUT"
       continue
     fi
     # Decode literal backslash-n -> real LF (M028/P03/T04 + M021 corpus
     # convention preserves newlines as the two-byte escape \n).
     decoded="$(printf '%b' "$raw")"
     invoke_hook "Corpus ID-${cid}" "$decoded" "reject"
   done

   # Negative control: a benign single-stage allow-form command.
   invoke_hook "Negative-control echo hello" "echo hello" "allow"

   # Stop event: directly invoke after-verify-sync.sh and assert exit 0
   # + no `command not found`.
   total_stop=1
   stop_out="${tmp_home}/stop-stdout.txt"
   stop_err="${tmp_home}/stop-stderr.txt"
   HOME="$tmp_home" bash "$stop_script" > "$stop_out" 2> "$stop_err"
   sc=$?
   if [ "$sc" -eq 0 ] && ! grep -q 'command not found' "$stop_err"; then
     pass "Stop event after-verify-sync.sh -> exit 0 (no 'command not found')"
   else
     fail "Stop event" "rc=$sc"
     would_prompt=$((would_prompt + 1))
   fi

   # Aggregate.
   echo "WOULD_PROMPT=${would_prompt}/${total}"
   if [ "$fail_count" -eq 0 ] && [ "$would_prompt" -eq 0 ]; then
     echo "PASS: tests/run-downstream-fixture.sh"
     exit 0
   fi
   echo "FAIL: tests/run-downstream-fixture.sh ($fail_count failures)"
   exit 1
   ```

3. Make the harness executable: `chmod +x tests/run-downstream-fixture.sh`. (The orchestrator's installer-staged scripts use `bash <path>` invocation so chmod is a courtesy, not a contract; matches sibling `tests/run-prompt-corpus-replay.sh` shape.)

### Round 3 — Author `scripts/verify/m028/p05-downstream-fixture-clean.sh`

4. Create `scripts/verify/m028/p05-downstream-fixture-clean.sh` (~50 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Contract: invoke the T02 harness, capture stdout+stderr, assert:
   1. Harness exit 0.
   2. The summary line `WOULD_PROMPT=0/<N>` is present (where `<N>` is any non-zero integer — Bash 3.2 does NOT support regex anchored to digit-class, so use `grep -E '^WOULD_PROMPT=0/[0-9]+$'`).
   3. No `command not found` substring anywhere in the captured output.
   4. At least one `PASS:` line is present (sanity-check the harness ran assertions, didn't short-circuit silently).

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-downstream-fixture-clean.sh -- M028/P05/T02
   # cross-cutting Truth-Check.
   #
   # Invokes tests/run-downstream-fixture.sh, captures output, and asserts
   # the canonical clean-pass shape: exit 0 + WOULD_PROMPT=0/<N> + no
   # 'command not found' + at least one PASS line.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
   HARNESS="${REPO_ROOT}/tests/run-downstream-fixture.sh"

   if [ ! -f "$HARNESS" ]; then
     echo "FAIL: harness not found at $HARNESS" >&2
     exit 1
   fi

   fail_count=0
   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   tmp_out="$(mktemp)"
   trap 'rm -f "$tmp_out"' EXIT
   bash "$HARNESS" > "$tmp_out" 2>&1
   rc=$?

   if [ "$rc" -eq 0 ]; then pass "harness exit 0"; else fail "harness exit" "rc=$rc"; fi

   if grep -qE '^WOULD_PROMPT=0/[0-9]+$' "$tmp_out"; then
     pass "harness summary WOULD_PROMPT=0/<N>"
   else
     fail "harness summary" "missing canonical WOULD_PROMPT=0/<N> line"
   fi

   if grep -q 'command not found' "$tmp_out"; then
     fail "no 'command not found'" "command-not-found substring present"
   else
     pass "no 'command not found' substring"
   fi

   if grep -q '^PASS:' "$tmp_out"; then
     pass "harness emitted PASS lines"
   else
     fail "harness PASS lines" "no PASS lines in output"
   fi

   if [ "$fail_count" -eq 0 ]; then
     echo "PASS: p05-downstream-fixture-clean.sh"
     exit 0
   fi
   echo "FAIL: p05-downstream-fixture-clean.sh ($fail_count failures)"
   exit 1
   ```

### Round 4 — Plan-time pre-validation + close

5. Plan-author confirms each `## Verification` line classifies as `allow` under the M028 classifier. Both lines are single-stage `bash <path>.sh` invocations.

6. Do NOT create a git commit; the orchestrator handles phase-boundary commits.

## Must-Haves

This task addresses the phase Truth:

- "The autonomous-loop replay harness `tests/run-downstream-fixture.sh` exists, is executable, and exits 0 against the permanent fixture" — addressed by Steps 1–3 + verified by `p05-downstream-fixture-clean.sh` (Step 4).

## Verification

```bash
bash scripts/verify/m028/p05-downstream-fixture-clean.sh
```

```bash
bash tests/run-downstream-fixture.sh
```

## Notes

Expected output of `bash scripts/verify/m028/p05-downstream-fixture-clean.sh`:

- Four `PASS:` lines (harness exit 0; canonical summary; no `command not found`; PASS lines emitted).
- Final `PASS: p05-downstream-fixture-clean.sh` line.
- Exit 0.

Expected output of `bash tests/run-downstream-fixture.sh`:

- 1 installer-staging PASS line.
- 1 Finding A PASS line.
- 6 corpus-ID PASS lines (IDs 21, 22, 23, 24, 25, 27).
- 1 negative-control PASS line.
- 1 Stop event PASS line.
- Final `WOULD_PROMPT=0/9` line (9 = 1 Finding A + 6 corpus + 1 negative-control + 1 Stop).
- Final `PASS: tests/run-downstream-fixture.sh` line.
- Exit 0.

If the harness reports a non-zero `WOULD_PROMPT` count, inspect `${TMPDIR:-/tmp}/m028-p05-replay-$$/hook-stderr-<N>.txt` to see which command failed to reject and why. The harness's tmp-home is rm'd on EXIT; comment out the trap line during debugging if needed.

Failure modes to expect during development:
- (a) Installer fails to stage hooks → P02 regression, escalate to P02/T03.
- (b) Hook fires but classifier rejects with the wrong AP-ID → harness still PASSes (it asserts REJECT, not which AP-ID); cross-check via `bash scripts/verify/m028/run-all.sh` if the suspicion is classifier drift.
- (c) Stop event fails with `command not found` → P02 regression on FR-3 / FR-4 (adapter absolute-path emission); escalate to P02/T02.
- (d) Negative-control `echo hello` rejects → classifier over-broad regression; cross-check via `bash tests/run-prompt-corpus-replay.sh` against IDs 01..20.

## Inputs

### From Previous Tasks

- `tests/fixtures/downstream-project/.claude/settings.json` (T01) — referenced in the harness's pre-flight existence check; not parsed at runtime (the harness uses an isolated `HOME` and runs the installer to produce the runtime settings).
  - Key API: file existence is checked before the harness proceeds; absent → exit 1 with `WOULD_PROMPT=N/A`.
- `tests/fixtures/downstream-project/README.md` (T01) — referenced in cross-link only; harness does not read its contents.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` (P02/T03) — invoked with `--project-dir <tmp_home>` against an isolated `HOME` to stage the runtime hooks dir. Exit 0 → continue; non-zero → harness exits with `WOULD_PROMPT=N/A`.
  - Key API: `HOME=<tmp> CLAUDECODE=1 bash install-claude-code.sh --project-dir <tmp>` produces `<tmp>/.claude/orchestrator-hooks/{pre-bash-shape-guard.sh, shape-classifier.sh, after-verify-sync.sh, before-commit.sh, ...}`.
- `scripts/hooks/pre-bash-shape-guard.sh` (P02/T01) — the staged hook the harness routes commands through.
  - Key API: reads JSON `{ "tool_name": "Bash", "tool_input": { "command": "..." } }` on stdin; exits 0 (allow/passthrough) or 2 (REJECT with `REJECT:` diagnostic on stderr).
- `scripts/lifecycle/after-verify-sync.sh` — the staged Stop-event lifecycle script.
  - Key API: invoked as `bash <path>` with no stdin; exits 0 on success.
- `tests/fixtures/m021-prompt-corpus.txt` (P03/T04) — the 27-entry corpus with the 4-line entry grammar; the harness extracts INPUT bytes for IDs 21..25, 27 via awk.
  - Key API: 4-line entry (`# ID: NN`, `INPUT:`, `EXPECTED_OUTCOME:`, `---`); the harness's `extract_corpus_input <id>` helper returns the verbatim `INPUT:` line bytes, with `printf %b` decoding for literal `\n` escape sequences.
- `scripts/verify/m028/finding-A-verifier.sh` (P02/T05) — pattern reference for the installer-staged HOME + JSON-on-stdin invocation shape. T02 harness mirrors the same shape for cross-finding consistency.

## Constraints

- **CON-1 (AD-19)**: Harness and verifier are flat single-file shapes. Helper-function carve-out documented at top-of-file; helpers (`invoke_hook`, `extract_corpus_input`, `pass`, `fail`) live as bash functions whose bodies are NOT classifier-scanned per M028/P02/T05 codification.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<` here-strings, no `declare -A`, no `[[` regex. Use `grep -E` for regex, `case` for pattern matching, parallel indexed arrays for any keyed data.
- **CON-6 (no new runtime deps)**: Pure bash + `grep`/`awk`/`printf`/`mktemp`. No jq.
- **CON-7 (no M021 regression)**: The harness's negative-control assertion (`echo hello` allows) catches M021 regression by construction — if the classifier becomes over-broad and rejects benign commands, the negative-control assertion fails.
- **CON-10 (downstream-fixture permanence)**: The harness reads `tests/fixtures/downstream-project/` existence at startup as a guard; the fixture is the noisy-fail anchor.
- **Verification-section authoring**: `## Verification` invokes project-tree scripts directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: Both `## Verification` lines resolve to scripts T02 itself authors (the harness + the clean verifier). Co-authored with the deliverable per CLAUDE.md plan-time verifier-availability discipline.
- **Plan-time classifier-shape pre-validation**: Each `## Verification` line is a single-stage `bash <path>.sh` invocation — classifies as `allow` under the M028 classifier.
- **Heredoc-in-function-body carve-out**: The harness uses `printf` rather than heredocs to author the JSON event payload because the orchestrator's commit-time AP-008 hook rejects heredoc-with-expansion shapes; `printf '{ ... "command": "%s" ... }\n' "$safe"` is the equivalent shape that classifies cleanly.
- **Commit-message form (when applicable)**: `git commit -F <file>`. T02 itself does NOT commit.

## Expected Output

After both `## Verification` lines run cleanly, T02 has shipped:

1. `tests/run-downstream-fixture.sh` — the autonomous-loop replay harness with 9 hook-event replay assertions + 1 Stop-event assertion + a canonical `WOULD_PROMPT=0/9` summary line.
2. `scripts/verify/m028/p05-downstream-fixture-clean.sh` — the cross-cutting Truth-Check verifier that wraps the harness with grep-based output-shape assertions.

T03 will sequence the harness as one of four sub-gates in the close-out regression gate; T04 will roll up `p05-downstream-fixture-clean.sh` via `check-must-haves.sh` against the phase plan.
