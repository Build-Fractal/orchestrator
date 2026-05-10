---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M021"
name: "Hook test harness — tests/hook/rewrite-cases.sh (6 cases) + tests/hook/reject-cases.sh (4 cases)"
depends_on: ["T02"]
---

## Prerequisites

T02 has shipped `scripts/hooks/pre-bash-shape-guard.sh` — executable, stdin-driven, emits either empty stdout (allow), one-line JSON (rewrite), or stderr + exit 2 (reject).

The `tests/hook/` directory does not yet exist — T04 creates it. Existing `tests/` subdirectories: `fixtures/`, `integration/`; top-level test files like `test-s0N-*.sh`. The new `tests/hook/` lives alongside these.

The ten-pattern matrix is closed on AD-2 (see [`.orchestrator/milestones/M021/M021-CONTEXT.md`](../../../../../milestones/M021/M021-CONTEXT.md)). Six rewrites, four rejects. This task authors exactly one test case per matrix entry — no speculative additions (constitution XIV).

## Description

Author two Bash 3.2 scripts that drive the hook with synthetic stdin JSON and assert exit code + stdout + stderr shape:

1. **`tests/hook/rewrite-cases.sh`** — six cases. For each, pipe a synthetic `{"tool_name":"Bash","tool_input":{"command":"<INPUT>"}}` into the hook, assert exit 0, and assert stdout matches the expected `{"hookSpecificOutput":{...,"updatedInput":{"command":"<EXPECTED-REWRITE>"}}}` shape (JSON equivalence — key order may vary, values must match).

2. **`tests/hook/reject-cases.sh`** — four cases. For each, pipe a synthetic Bash-tool JSON in, assert exit 2, and assert stderr contains the exact `REJECT: <pattern-class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#<AP-id>.` line.

Both scripts emit `PASS: <case-label>` / `FAIL: <case-label> (reason)` per case and a final `PASS: <script-name>` on all-pass (exit 0) or `FAIL: <script-name> (N failures)` on any-fail (exit 1).

## The Six Rewrite Cases

| # | Pattern-class       | Synthetic `tool_input.command`                                                    | Expected `updatedInput.command`                                |
|---|---------------------|-----------------------------------------------------------------------------------|----------------------------------------------------------------|
| 1 | trailing-rc-echo    | `bash scripts/verify/run-suite.sh m021 P03 ; echo "RC=$?"`                        | `bash scripts/verify/run-suite.sh m021 P03`                    |
| 2 | sed-n-range         | `sed -n '10,20p' file.md`                                                         | `bash scripts/util/read-range.sh file.md 10 20`                |
| 3 | cat-heredoc-exec    | `cat > /tmp/probe.sh <<EOF\necho hello\nEOF\nbash /tmp/probe.sh`                  | `bash scripts/util/run-probe.sh /tmp/probe.sh`                 |
| 4 | cd-and-bash         | `cd .orchestrator && bash scripts/foo.sh arg1 arg2`                               | `bash scripts/foo.sh arg1 arg2`                                |
| 5 | var-inline-bash     | `ORCH_REPO=/tmp/repo LOG=/tmp/x.log bash scripts/foo.sh --flag`                   | `bash scripts/util/with-env.sh ORCH_REPO=/tmp/repo LOG=/tmp/x.log -- bash scripts/foo.sh --flag` |
| 6 | redirect-cmd-sub    | `bash scripts/foo.sh > "$(mktemp)" 2>&1`                                          | `bash scripts/util/read-range.sh` (fixed placeholder per T01 Rewrite #6 note) |

Case 3 contains literal `\n` sequences in the JSON — the hook extracts and unescapes them before classification. The test harness must embed them as JSON-escaped `\\n` in the synthetic stdin payload.

## The Four Reject Cases

| # | Pattern-class             | Synthetic `tool_input.command`                     | Expected stderr line                                                                                                           |
|---|---------------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| 1 | nested-cmd-sub            | `echo $(date $(hostname))`                         | `REJECT: nested-cmd-sub — use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009.`                                  |
| 2 | compound-chain-gt2        | `bash a.sh \| bash b.sh \| bash c.sh \| bash d.sh` | `REJECT: compound-chain-gt2 — use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009.`                              |
| 3 | heredoc-with-expansion    | `cat <<EOF\necho $HOME\nEOF`                       | `REJECT: heredoc-with-expansion — use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-008.`                          |
| 4 | quoted-brace              | `awk "BEGIN{print 42}" /dev/null`                  | `REJECT: quoted-brace — use scripts/util/read-range.sh instead. See ANTIPATTERNS.md#AP-007.`                                   |

Em dash character is U+2014 (bytes `\xe2\x80\x94`). Test harness greps for the exact UTF-8 byte sequence, not `--`.

## Steps

### Step 1: Create `tests/hook/` directory

```
mkdir -p tests/hook
```

### Step 2: Author `tests/hook/rewrite-cases.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# tests/hook/rewrite-cases.sh — Drives scripts/hooks/pre-bash-shape-guard.sh
# with six synthetic stdin-JSON payloads (one per rewrite pattern) and asserts
# the hook's stdout contains the expected `updatedInput.command` string.
#
# Exit 0 on all-pass, 1 on any failure.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

drive_hook() {
  # $1 = input bash command (raw, will be JSON-escaped)
  # stdout = hook stdout; sets global HOOK_EXIT
  local raw="$1"
  local escaped
  # JSON-escape: \ → \\, " → \", newlines → \n, tabs → \t.
  escaped="$(printf '%s' "$raw" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} {if (NR>1) print "\\n"; print}')"
  local out
  out="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$escaped" \
    | bash "$HOOK" 2>/dev/null)"
  HOOK_EXIT=$?
  printf '%s' "$out"
}

# Helper: extract updatedInput.command from hook stdout.
extract_updated_command() {
  # $1 = hook stdout; echo the command field (unescaped) or empty if missing.
  printf '%s' "$1" \
    | sed -n 's/.*"updatedInput"[[:space:]]*:[[:space:]]*{[[:space:]]*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
    | head -1 \
    | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g' -e 's/\\n/\n/g' -e 's/\\t/\t/g'
}

assert_rewrite() {
  local label="$1" input="$2" expected="$3"
  local out actual
  out="$(drive_hook "$input")"
  if [ "$HOOK_EXIT" -ne 0 ]; then
    fail "$label" "hook exited $HOOK_EXIT (expected 0)"
    return
  fi
  actual="$(extract_updated_command "$out")"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label" "got [$actual] expected [$expected]"
  fi
}

# --- Six rewrite cases ---

assert_rewrite "R1 trailing-rc-echo" \
  'bash scripts/verify/run-suite.sh m021 P03 ; echo "RC=$?"' \
  'bash scripts/verify/run-suite.sh m021 P03'

assert_rewrite "R2 sed-n-range" \
  "sed -n '10,20p' file.md" \
  'bash scripts/util/read-range.sh file.md 10 20'

assert_rewrite "R3 cat-heredoc-exec" \
  'cat > /tmp/probe.sh <<EOF
echo hello
EOF
bash /tmp/probe.sh' \
  'bash scripts/util/run-probe.sh /tmp/probe.sh'

assert_rewrite "R4 cd-and-bash" \
  'cd .orchestrator && bash scripts/foo.sh arg1 arg2' \
  'bash scripts/foo.sh arg1 arg2'

assert_rewrite "R5 var-inline-bash" \
  'ORCH_REPO=/tmp/repo LOG=/tmp/x.log bash scripts/foo.sh --flag' \
  'bash scripts/util/with-env.sh ORCH_REPO=/tmp/repo LOG=/tmp/x.log -- bash scripts/foo.sh --flag'

assert_rewrite "R6 redirect-cmd-sub" \
  'bash scripts/foo.sh > "$(mktemp)" 2>&1' \
  'bash scripts/util/read-range.sh'

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: rewrite-cases.sh"
  exit 0
fi
echo "FAIL: rewrite-cases.sh ($fail_count failures)"
exit 1
```

**Author note.** The multi-line R3 case relies on the `drive_hook` helper's JSON-escape step converting literal newlines to `\n`. Confirm the escape step produces exactly one JSON string.

### Step 3: Author `tests/hook/reject-cases.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# tests/hook/reject-cases.sh — Drives scripts/hooks/pre-bash-shape-guard.sh
# with four synthetic stdin-JSON payloads (one per reject pattern) and asserts
# exit 2 with the exact REJECT diagnostic on stderr.
#
# Exit 0 on all-pass, 1 on any failure.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

# U+2014 em dash as literal UTF-8 bytes.
EMDASH=$'\xe2\x80\x94'

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

drive_hook_stderr() {
  local raw="$1"
  local escaped
  escaped="$(printf '%s' "$raw" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} {if (NR>1) print "\\n"; print}')"
  local err
  err="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$escaped" \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  HOOK_EXIT=$?
  printf '%s' "$err"
}

assert_reject() {
  local label="$1" input="$2" expected_line="$3"
  local err
  err="$(drive_hook_stderr "$input")"
  if [ "$HOOK_EXIT" -ne 2 ]; then
    fail "$label" "hook exited $HOOK_EXIT (expected 2)"
    return
  fi
  if printf '%s' "$err" | grep -qF "$expected_line"; then
    pass "$label"
  else
    fail "$label" "stderr missing expected line; got [$err]"
  fi
}

# --- Four reject cases ---

assert_reject "J1 nested-cmd-sub" \
  'echo $(date $(hostname))' \
  "REJECT: nested-cmd-sub ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009."

assert_reject "J2 compound-chain-gt2" \
  'bash a.sh | bash b.sh | bash c.sh | bash d.sh' \
  "REJECT: compound-chain-gt2 ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009."

assert_reject "J3 heredoc-with-expansion" \
  'cat <<EOF
echo $HOME
EOF' \
  "REJECT: heredoc-with-expansion ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-008."

assert_reject "J4 quoted-brace" \
  'awk "BEGIN{print 42}" /dev/null' \
  "REJECT: quoted-brace ${EMDASH} use scripts/util/read-range.sh instead. See ANTIPATTERNS.md#AP-007."

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: reject-cases.sh"
  exit 0
fi
echo "FAIL: reject-cases.sh ($fail_count failures)"
exit 1
```

### Step 4: Make both executable

```
chmod +x tests/hook/rewrite-cases.sh tests/hook/reject-cases.sh
```

### Step 5: Run both

```
bash tests/hook/rewrite-cases.sh
bash tests/hook/reject-cases.sh
```

Both must exit 0 with final `PASS: …` lines.

### Step 6: Verify Bash 3.2 compatibility

```
bash -n tests/hook/rewrite-cases.sh
bash -n tests/hook/reject-cases.sh
```

Exit 0 required for each. Grep both for forbidden bash-4 constructs (same set as T01).

## Must-Haves

- `tests/hook/rewrite-cases.sh` exists, is executable, and invokes the hook with six synthetic stdin payloads (one per rewrite pattern-class). Each case asserts exit 0 AND the extracted `updatedInput.command` equals the expected rewritten string.
- `tests/hook/reject-cases.sh` exists, is executable, and invokes the hook with four synthetic stdin payloads (one per reject pattern-class). Each case asserts exit 2 AND stderr contains the exact diagnostic line (including the U+2014 em dash, the `scripts/util/<wrapper>` path, and the `ANTIPATTERNS.md#AP-00X` anchor).
- Both scripts emit `PASS:` / `FAIL:` per case and a final `PASS: <script-name>` / `FAIL: <script-name> (N failures)` line.
- Both scripts exit 0 when all cases pass; exit 1 otherwise.
- Both scripts are Bash 3.2 compatible (`bash -n` exits 0; no `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, or `<(`).
- Exactly 6 + 4 = 10 cases total, matching AD-2's ten-entry matrix (no speculative additions).

## Verification

- `bash tests/hook/rewrite-cases.sh` exits 0 with final line `PASS: rewrite-cases.sh` and 6 `PASS:` case lines.
- `bash tests/hook/reject-cases.sh` exits 0 with final line `PASS: reject-cases.sh` and 4 `PASS:` case lines.
- `bash scripts/verify/m021-p03-hook-integration.sh` (T05) includes invocations of both scripts and asserts their exit codes + summary lines.

## Inputs

### From Previous Tasks

- `scripts/hooks/pre-bash-shape-guard.sh` (from T02)
  - Key contract: reads Claude Code stdin JSON, classifies, emits `updatedInput` JSON on rewrite or stderr diagnostic on reject.
- `scripts/verify/lib/shape-classifier.sh` (from T01 — indirect via T02)
  - Classifier emits the ten pattern-class labels that drive hook behavior.

### From Disk (Pre-existing)

None (the hook binary and classifier are the only dependencies; wrappers are referenced by name in expected-output strings only, not invoked).

## Constraints

- Bash 3.2 compatibility (constitution IX).
- Em dash is U+2014 (three UTF-8 bytes). Do not substitute `--`. Do not substitute a different Unicode dash.
- Exactly 10 cases across both scripts — one per matrix entry. No test for pass-through (`allow`) cases in T04; T05 covers pass-through.
- Test scripts drive the hook via pipe-to-`bash <hook>` — do not source the hook, do not mock stdin via redirection from a temp file (simpler and preserves real TTY semantics).
- JSON escape / unescape in the harness must match the hook's own encoding: `\\`, `\"`, `\n`, `\t` handled; no other escapes assumed.
- Tests are hermetic — they must not read or write any file other than their own stdin pipe.

## Expected Output

- `tests/hook/rewrite-cases.sh` and `tests/hook/reject-cases.sh` exist, executable, pass.
- Step-5 probe commands produce PASS lines.
- T05 gate invokes both and propagates their exit codes.
