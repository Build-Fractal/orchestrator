---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M021"
name: "Phase integration gate (scripts/verify/m021-p03-hook-integration.sh) — cohesion check across classifier + hook + settings + harness + dispatch"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

All four upstream tasks have completed:

- T01 → `scripts/verify/lib/shape-classifier.sh` with `classify_command` function
- T02 → `scripts/hooks/pre-bash-shape-guard.sh` executable hook
- T03 → `.claude/settings.json` with 9 new allow entries + `hooks.PreToolUse` registration; `scripts/dispatch/lib/section-handlers.sh` extended with `### Allowed invocation shapes`
- T04 → `tests/hook/rewrite-cases.sh` + `tests/hook/reject-cases.sh` both passing

`scripts/verify/run-suite.sh` auto-discovers this gate via filename pattern `m021-p03-*.sh`. The gate name must be `m021-p03-hook-integration.sh` — discovery is case-sensitive and lowercase.

Gate convention from M016/P02: `PASS: <label>` / `FAIL: <label>` per assertion; final line `PASS: <gate-name>` on all-pass (exit 0) or `FAIL: <gate-name> (N failures)` (exit 1).

## Description

Author `scripts/verify/m021-p03-hook-integration.sh` — the phase's single integration gate. It exercises every T01–T04 output in combination to prove the hook is correctly installed, the classifier's matrix is complete, the settings registration is well-formed, the dispatch payload exposes the wrapper catalog, and the test harness results cohere.

The gate is organized in six assertion groups:

1. **Classifier library assertions (T01)** — source `scripts/verify/lib/shape-classifier.sh`, invoke `classify_command` with 20+ synthetic inputs spanning all ten pattern-classes + pass-through cases, assert exact output strings.
2. **Hook protocol assertions (T02)** — drive the hook with a pass-through case (empty stdout + exit 0), a rewrite case (JSON stdout + exit 0), and a reject case (stderr + exit 2). This is a smoke test; the exhaustive per-pattern coverage lives in T04.
3. **Settings registration assertions (T03.a)** — parse `.claude/settings.json`; assert JSON validity, presence of 9 new allow entries, presence of exactly one `PreToolUse` matcher for Bash pointing at `scripts/hooks/pre-bash-shape-guard.sh`, and that the hook file exists + is executable.
4. **Dispatch section assertions (T03.b)** — source `scripts/dispatch/lib/section-handlers.sh`, invoke `handle_template _ _ _ _ constraints` with required env vars, assert output contains `### Allowed invocation shapes` AND all three `scripts/util/*.sh` wrapper paths AND the reference to `scripts/hooks/pre-bash-shape-guard.sh` AND an `ANTIPATTERNS.md AP-005..AP-009` pointer.
5. **Test harness assertions (T04)** — invoke `tests/hook/rewrite-cases.sh` and `tests/hook/reject-cases.sh`, assert each exits 0 and prints the final `PASS: <script-name>` line.
6. **Bash 3.2 compatibility assertions** — `bash -n` on all five new files (classifier, hook, two test scripts, this gate) + grep each for forbidden Bash-4 constructs. Zero hits on any of: `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, `<(`.

## The Classifier Unit Coverage (Group 1)

Seed these assertions directly in the gate (no separate fixture file — the synthetic inputs are small enough to inline):

### Allow cases (≥4)

| Input                                           | Expected |
|-------------------------------------------------|----------|
| `bash scripts/verify/run-suite.sh m021 P03`     | `allow`  |
| `ls scripts/`                                   | `allow`  |
| `cat /tmp/foo.txt`                              | `allow`  |
| `bash a.sh && bash b.sh` (exactly 2 stages)     | `allow`  |

### Rewrite cases (≥6 — one per pattern-class)

| Input                                                   | Expected                                                         |
|---------------------------------------------------------|------------------------------------------------------------------|
| `bash a.sh ; echo "RC=$?"`                              | `rewrite:bash a.sh`                                              |
| `sed -n '10,20p' file.md`                               | `rewrite:bash scripts/util/read-range.sh file.md 10 20`          |
| `cat > /tmp/p.sh <<EOF\necho hi\nEOF\nbash /tmp/p.sh`   | `rewrite:bash scripts/util/run-probe.sh /tmp/p.sh`               |
| `cd .orchestrator && bash scripts/foo.sh a b`           | `rewrite:bash scripts/foo.sh a b`                                |
| `K=v bash scripts/foo.sh --flag`                        | `rewrite:bash scripts/util/with-env.sh K=v -- bash scripts/foo.sh --flag` |
| `bash x.sh > "$(mktemp)"`                               | `rewrite:bash scripts/util/read-range.sh`                        |

### Reject cases (≥4 — one per pattern-class)

| Input                                          | Expected                             |
|------------------------------------------------|--------------------------------------|
| `echo $(date $(hostname))`                     | `reject:nested-cmd-sub`              |
| `bash a.sh \| bash b.sh \| bash c.sh`          | `reject:compound-chain-gt2`          |
| `cat <<EOF\necho $HOME\nEOF`                   | `reject:heredoc-with-expansion`      |
| `awk "BEGIN{print 42}" /dev/null`              | `reject:quoted-brace`                |

## Steps

### Step 1: Author `scripts/verify/m021-p03-hook-integration.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p03-hook-integration.sh — Integration gate for P03.
#
# Assertion groups:
#   1. Classifier library (scripts/verify/lib/shape-classifier.sh)
#   2. Hook protocol (scripts/hooks/pre-bash-shape-guard.sh)
#   3. Settings registration (.claude/settings.json)
#   4. Dispatch section (scripts/dispatch/lib/section-handlers.sh)
#   5. Test harness (tests/hook/{rewrite,reject}-cases.sh)
#   6. Bash 3.2 compatibility (all five P03 new files)
#
# Exit 0 on all-pass; 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
SETTINGS="${REPO_ROOT}/.claude/settings.json"
SECTION_HANDLERS="${REPO_ROOT}/scripts/dispatch/lib/section-handlers.sh"
REWRITE_CASES="${REPO_ROOT}/tests/hook/rewrite-cases.sh"
REJECT_CASES="${REPO_ROOT}/tests/hook/reject-cases.sh"
GATE_SELF="${BASH_SOURCE[0]}"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Group 1: Classifier library ---
if [ -f "$CLASSIFIER" ]; then
  # shellcheck disable=SC1090
  . "$CLASSIFIER"

  assert_classify() {
    local label="$1" input="$2" expected="$3"
    local actual
    actual="$(classify_command "$input" 2>/dev/null)"
    if [ "$actual" = "$expected" ]; then
      pass "classify: $label"
    else
      fail "classify: $label" "got [$actual] expected [$expected]"
    fi
  }

  # Allow cases
  assert_classify "allow: run-suite" 'bash scripts/verify/run-suite.sh m021 P03' 'allow'
  assert_classify "allow: ls" 'ls scripts/' 'allow'
  assert_classify "allow: cat tmp" 'cat /tmp/foo.txt' 'allow'
  assert_classify "allow: 2-stage &&" 'bash a.sh && bash b.sh' 'allow'

  # Rewrite cases
  assert_classify "rewrite: trailing-rc-echo" 'bash a.sh ; echo "RC=$?"' \
    'rewrite:bash a.sh'
  assert_classify "rewrite: sed-n-range" "sed -n '10,20p' file.md" \
    'rewrite:bash scripts/util/read-range.sh file.md 10 20'
  # cat-heredoc-exec with embedded newlines:
  _input_r3="$(printf 'cat > /tmp/p.sh <<EOF\necho hi\nEOF\nbash /tmp/p.sh')"
  assert_classify "rewrite: cat-heredoc-exec" "$_input_r3" \
    'rewrite:bash scripts/util/run-probe.sh /tmp/p.sh'
  assert_classify "rewrite: cd-and-bash" 'cd .orchestrator && bash scripts/foo.sh a b' \
    'rewrite:bash scripts/foo.sh a b'
  assert_classify "rewrite: var-inline-bash" 'K=v bash scripts/foo.sh --flag' \
    'rewrite:bash scripts/util/with-env.sh K=v -- bash scripts/foo.sh --flag'
  assert_classify "rewrite: redirect-cmd-sub" 'bash x.sh > "$(mktemp)"' \
    'rewrite:bash scripts/util/read-range.sh'

  # Reject cases
  assert_classify "reject: nested-cmd-sub" 'echo $(date $(hostname))' \
    'reject:nested-cmd-sub'
  assert_classify "reject: compound-chain-gt2" 'bash a.sh | bash b.sh | bash c.sh' \
    'reject:compound-chain-gt2'
  _input_j3="$(printf 'cat <<EOF\necho $HOME\nEOF')"
  assert_classify "reject: heredoc-with-expansion" "$_input_j3" \
    'reject:heredoc-with-expansion'
  assert_classify "reject: quoted-brace" 'awk "BEGIN{print 42}" /dev/null' \
    'reject:quoted-brace'
else
  fail "classifier library present" "not found at $CLASSIFIER"
fi

# --- Group 2: Hook protocol smoke test ---
if [ -x "$HOOK" ] || [ -f "$HOOK" ]; then
  _out="$(printf '{"tool_name":"Bash","tool_input":{"command":"bash scripts/verify/run-suite.sh m021 P03"}}' \
    | bash "$HOOK" 2>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 0 ] && [ -z "$_out" ]; then
    pass "hook: allow passthrough yields empty stdout + exit 0"
  else
    fail "hook: allow passthrough" "rc=$_rc stdout=[$_out]"
  fi

  _out="$(printf '{"tool_name":"Bash","tool_input":{"command":"sed -n %s10,20p%s file.md"}}' "'" "'" \
    | bash "$HOOK" 2>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -qF 'read-range.sh file.md 10 20'; then
    pass "hook: rewrite emits updatedInput JSON"
  else
    fail "hook: rewrite" "rc=$_rc stdout=[$_out]"
  fi

  _err="$(printf '{"tool_name":"Bash","tool_input":{"command":"echo $(date $(hostname))"}}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 2 ] && printf '%s' "$_err" | grep -qF 'REJECT: nested-cmd-sub'; then
    pass "hook: reject emits stderr diagnostic + exit 2"
  else
    fail "hook: reject" "rc=$_rc stderr=[$_err]"
  fi
else
  fail "hook present" "not found at $HOOK"
fi

# --- Group 3: Settings registration ---
if [ -f "$SETTINGS" ]; then
  # Attempt JSON validation via any available parser.
  _valid=0
  if command -v jq >/dev/null 2>&1; then
    jq . "$SETTINGS" >/dev/null 2>&1 && _valid=1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$SETTINGS" && _valid=1
  else
    # No parser available — fall back to a balanced-brace heuristic.
    _valid=1
  fi
  [ "$_valid" -eq 1 ] && pass "settings: JSON parses" || fail "settings: JSON parses" "parser error"

  # Assert each new allow entry is present.
  for entry in \
    'Read(/var/folders/**)' \
    'Bash(bash /tmp/*.sh)' \
    'Bash(bash /var/folders/**/*.sh)' \
    'Bash(ls tmp/**)' \
    'Bash(cat tmp/**)' \
    'Bash(sed -n *)' \
    'Bash(head *)' \
    'Bash(tail *)' \
    'Bash(stat *)'
  do
    if grep -qF "\"$entry\"" "$SETTINGS"; then
      pass "settings: allow contains $entry"
    else
      fail "settings: allow contains $entry" "missing"
    fi
  done

  # Assert PreToolUse hook registration.
  if grep -qF '"PreToolUse"' "$SETTINGS" && grep -qF 'scripts/hooks/pre-bash-shape-guard.sh' "$SETTINGS"; then
    pass "settings: PreToolUse hook registered"
  else
    fail "settings: PreToolUse hook registered" "missing"
  fi
else
  fail "settings present" "not found at $SETTINGS"
fi

# --- Group 4: Dispatch section ---
if [ -f "$SECTION_HANDLERS" ]; then
  _out="$( . "$SECTION_HANDLERS" && SH_VERIFICATION_CRITERIA=test SH_DURATION_BUDGET=1h SH_DISPATCH_BUDGET=3 SH_BUDGET_ENFORCEMENT=warn handle_template _ _ _ _ constraints )"
  for needle in \
    '### Allowed invocation shapes' \
    'scripts/util/with-env.sh' \
    'scripts/util/read-range.sh' \
    'scripts/util/run-probe.sh' \
    'scripts/hooks/pre-bash-shape-guard.sh' \
    'AP-005..AP-009'
  do
    if printf '%s' "$_out" | grep -qF "$needle"; then
      pass "dispatch: constraints contains $needle"
    else
      fail "dispatch: constraints contains $needle" "missing"
    fi
  done
else
  fail "section-handlers present" "not found at $SECTION_HANDLERS"
fi

# --- Group 5: Test harness ---
for harness in "$REWRITE_CASES" "$REJECT_CASES"; do
  if [ -f "$harness" ]; then
    _out="$(bash "$harness" 2>&1)"
    _rc=$?
    _name="$(basename "$harness")"
    if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -qF "PASS: $_name"; then
      pass "harness: $_name"
    else
      fail "harness: $_name" "rc=$_rc"
    fi
  else
    fail "harness present" "not found at $harness"
  fi
done

# --- Group 6: Bash 3.2 compatibility ---
for f in "$CLASSIFIER" "$HOOK" "$REWRITE_CASES" "$REJECT_CASES" "$GATE_SELF"; do
  if [ ! -f "$f" ]; then
    continue
  fi
  if bash -n "$f" 2>/dev/null; then
    pass "bash32: $(basename "$f") parses clean"
  else
    fail "bash32: $(basename "$f") parses clean" "bash -n failed"
  fi
  for forbidden in 'declare -A' 'mapfile' 'readarray' '${var,,}' '${var^^}' '${!prefix*}' '<('; do
    if grep -qF "$forbidden" "$f"; then
      fail "bash32: $(basename "$f") has forbidden [$forbidden]" "found"
    fi
  done
  pass "bash32: $(basename "$f") no forbidden constructs"
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p03-hook-integration.sh"
  exit 0
fi
echo "FAIL: m021-p03-hook-integration.sh ($fail_count failures)"
exit 1
```

**Author note.** The gate itself uses `$(…)` and `$(printf …)` freely in its internals — per MEM004 and AP-004's "Scope of enforcement" note, verification-script internals are not agent-facing. The gate's single agent-visible invocation shape is `bash scripts/verify/m021-p03-hook-integration.sh` (AD-19).

**Author note.** The `_input_r3` and `_input_j3` lines use `printf 'literal with \n'` to produce strings with embedded newlines. This is Bash 3.2 safe and avoids heredocs in the gate source (which would themselves be at risk of tripping the classifier on any future linter pass).

**Author note.** When `jq` and `python3` are both unavailable, the JSON-validity check falls back to a "valid" assumption. This is acceptable because (a) any later tooling will parse the settings and fail loudly if invalid, and (b) stock macOS ships `python3` via Xcode Command Line Tools in virtually all orchestrator environments.

### Step 2: Make executable

```
chmod +x scripts/verify/m021-p03-hook-integration.sh
```

### Step 3: Run

```
bash scripts/verify/m021-p03-hook-integration.sh
```

Must exit 0 with final line `PASS: m021-p03-hook-integration.sh`.

### Step 4: Run the phase suite

```
bash scripts/verify/run-suite.sh m021 P03
```

Must report PASS: 1 / FAIL: 0 (only this gate is registered under P03).

### Step 5: Run the linter over the repo

```
bash scripts/verify/anti-pattern-lint.sh
```

Must exit 0. No file created by T01–T05 should introduce a Class A or Class B violation.

## Must-Haves

- `scripts/verify/m021-p03-hook-integration.sh` exists, is executable.
- Gate emits `PASS:` / `FAIL:` lines across six assertion groups (classifier, hook, settings, dispatch, harness, bash32).
- Gate exits 0 with final line `PASS: m021-p03-hook-integration.sh` when all upstream outputs are correctly wired.
- Classifier assertion group covers ≥4 allow cases, ≥6 rewrite cases (one per pattern-class), ≥4 reject cases (one per pattern-class) — 14+ `classify_command` invocations total.
- Hook assertion group exercises allow/rewrite/reject branches with driven stdin (three cases).
- Settings assertion group confirms JSON validity (best-effort), all 9 new allow entries, and the PreToolUse hook registration.
- Dispatch assertion group renders `handle_template … constraints` and confirms six needles: `### Allowed invocation shapes`, the three `scripts/util/*.sh` paths, the hook path, and the `AP-005..AP-009` pointer.
- Harness assertion group invokes both T04 scripts and propagates exit codes.
- Bash 3.2 group runs `bash -n` + forbidden-construct grep on all five new P03 files (classifier, hook, rewrite-cases, reject-cases, this gate).
- Gate is Bash 3.2 compatible itself (`bash -n` exits 0; no forbidden constructs).

## Verification

- `bash scripts/verify/m021-p03-hook-integration.sh` exits 0.
- `bash scripts/verify/run-suite.sh m021 P03` reports PASS: 1 / FAIL: 0.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 over the repo (P03 introduces no violations).

## Inputs

### From Previous Tasks

- `scripts/verify/lib/shape-classifier.sh` (from T01) — sourced; `classify_command` invoked 14+ times.
- `scripts/hooks/pre-bash-shape-guard.sh` (from T02) — driven via stdin; stdout/stderr/exit inspected.
- `.claude/settings.json` (from T03) — grepped for allow entries + hook registration.
- `scripts/dispatch/lib/section-handlers.sh` (from T03) — sourced; `handle_template` invoked with constraints.
- `tests/hook/rewrite-cases.sh` and `tests/hook/reject-cases.sh` (from T04) — invoked as subprocesses.

### From Disk (Pre-existing)

- `scripts/verify/run-suite.sh` — discovers this gate by filename pattern after T05 lands.
- `scripts/util/with-env.sh`, `read-range.sh`, `run-probe.sh` — path strings appear in the gate's dispatch-section needle list.

## Constraints

- Bash 3.2 compatibility (constitution IX).
- Single-script-file invocation shape at the phase level (AD-19) — `bash scripts/verify/m021-p03-hook-integration.sh`.
- Gate internals may freely use `$()`, pipes, subshells, heredocs (MEM004 + AP-004 scope-of-enforcement carve-out) — only agent-facing tool-call sites are constrained.
- Gate is hermetic — does not create, modify, or delete any file. All interaction with hook/harness is via subprocess invocation.
- Assertion count: ≥36 `PASS:` lines in the all-pass case (14 classifier + 3 hook + 10 settings + 6 dispatch + 2 harness + 5·2 = 10 bash32 = 45 approximate). Gate must report each assertion individually.

## Expected Output

- `scripts/verify/m021-p03-hook-integration.sh` exists and is executable.
- `bash scripts/verify/m021-p03-hook-integration.sh` exits 0 with ~45 `PASS:` lines and final `PASS: m021-p03-hook-integration.sh`.
- `bash scripts/verify/run-suite.sh m021 P03` reports PASS: 1 / FAIL: 0.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0.
