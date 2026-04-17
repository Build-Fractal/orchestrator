---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M021"
name: "Replay gate — scripts/verify/replay-prompt-corpus.sh (parses 20-entry corpus, invokes classifier + hook end-to-end per entry, asserts WOULD_PROMPT=0/20)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has produced `tests/fixtures/m021-prompt-corpus.txt` with 20 entries in the exact format documented in T01-PLAN.md.
- P03 has produced `scripts/verify/lib/shape-classifier.sh` (sourceable library exporting `classify_command`) and `scripts/hooks/pre-bash-shape-guard.sh` (executable PreToolUse hook consuming stdin JSON).

### Upstream API surface

- **Classifier library** (`scripts/verify/lib/shape-classifier.sh`, source-only):
  - Signature: `classify_command "<cmd-string>"` — writes exactly one line to stdout, exit 0.
  - Output grammar: `allow` | `rewrite:<result-command>` | `reject:<pattern-class>`.
  - Pattern-class labels: six rewrite labels (`trailing-rc-echo`, `sed-n-range`, `cat-heredoc-exec`, `cd-and-bash`, `var-inline-bash`, `redirect-cmd-sub`), four reject labels (`nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`).
  - Side-effect-free; safe to `. "$CLASSIFIER"` inside a gate script.

- **Hook** (`scripts/hooks/pre-bash-shape-guard.sh`, invoke as child process):
  - Reads Claude-Code-format stdin JSON: `{"tool_name":"Bash","tool_input":{"command":"<cmd-string>"}}`.
  - On allow: exit 0, empty stdout.
  - On rewrite: exit 0, stdout JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<rewritten>"}}}`.
  - On reject: exit 2, stderr single line `REJECT: <pattern-class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#AP-00X.` (em dash U+2014).

- **Corpus fixture** (`tests/fixtures/m021-prompt-corpus.txt`):
  - Plain text, 20 `---`-separated entries, 4-line `ID:`/`SCREENSHOT:`/`INPUT:`/`EXPECTED_OUTCOME:` format.
  - Newlines inside INPUT values are encoded as literal `\n` and must be decoded via `printf '%b'` before classification.

## Description

Author `scripts/verify/replay-prompt-corpus.sh` — the authoritative SC-1 regression gate. It parses the 20-entry corpus, runs each INPUT through the classifier library and the hook executable, compares results to EXPECTED_OUTCOME, and reports `WOULD_PROMPT=N/20` where N is zero when the integrated system covers every entry.

The gate operates in two coupled layers:

1. **Classifier layer** — sources `scripts/verify/lib/shape-classifier.sh`, invokes `classify_command` on each decoded INPUT, compares to EXPECTED_OUTCOME.
2. **Hook layer** — pipes synthetic stdin JSON to `scripts/hooks/pre-bash-shape-guard.sh`, captures exit code + stdout + stderr, confirms the hook's decision matches the classifier's. (Allow → exit 0 + empty stdout. Rewrite → exit 0 + `updatedInput.command` present. Reject → exit 2 + `REJECT: <class>` on stderr.)

A fixed N-count tallies the number of entries whose *classifier* output was not one of the three legal grammar forms (`allow`, `rewrite:*`, `reject:*`) — which would indicate a classifier bug (would-prompt leak). Under the hardened system, N must be 0.

## Steps

### Step 1: Author `scripts/verify/replay-prompt-corpus.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# scripts/verify/replay-prompt-corpus.sh — M021 SC-1 regression gate.
#
# Parses tests/fixtures/m021-prompt-corpus.txt (20 entries), invokes the
# shape-classifier library + the pre-bash-shape-guard hook on each INPUT,
# asserts 20/20 decisions match EXPECTED_OUTCOME, and prints the canonical
# final line: WOULD_PROMPT=N/20 where N=0 under the hardened configuration.
#
# Exit: 0 on all-pass (N=0 and 20/20 EXPECTED_OUTCOME matches), 1 otherwise.
#
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

fail_count=0
would_prompt=0
entry_count=0
EXPECTED_TOTAL=20

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Preconditions ---
if [ ! -f "$CORPUS" ]; then
  echo "FAIL: corpus fixture not found at $CORPUS" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier library not found at $CLASSIFIER" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

# --- Parse corpus into parallel indexed arrays (bash 3.2 safe) ---
# Collect: ids[i], inputs[i], expected[i]
# Parser state machine: track the 4 per-entry fields; reset on '---' separator.

ids=""
_idx=0
_cur_id=""
_cur_input=""
_cur_expected=""

# Use a single-pass read of the corpus into a tempfile so arrays work in
# the parent shell (Bash 3.2 safe).

_tmp="$(mktemp)"
# Emit three parallel records per entry: IDX<TAB>id<TAB>input<TAB>expected
# by scanning the corpus line-by-line.
awk '
  /^#/ { next }
  /^---$/ {
    if (id != "" && input != "" && expected != "") {
      gsub(/\t/, " ", input)
      gsub(/\t/, " ", expected)
      printf "%s\t%s\t%s\n", id, input, expected
    }
    id=""; input=""; expected=""; next
  }
  /^ID: / { id = substr($0, 5); next }
  /^INPUT: / { input = substr($0, 8); next }
  /^EXPECTED_OUTCOME: / { expected = substr($0, 19); next }
  # SCREENSHOT line ignored for gate purposes.
' "$CORPUS" > "$_tmp"

# --- Per-entry assertions ---
while IFS=$'\t' read -r eid einput eexpected; do
  entry_count=$((entry_count + 1))

  # Decode literal \n sequences into real newlines for classification.
  decoded="$(printf '%b' "$einput")"

  # --- Layer 1: Classifier decision ---
  actual="$(classify_command "$decoded" 2>/dev/null)"

  case "$actual" in
    allow|rewrite:*|reject:*)
      : # legal grammar
      ;;
    *)
      would_prompt=$((would_prompt + 1))
      fail "entry $eid classifier grammar" "unexpected output [$actual]"
      continue
      ;;
  esac

  if [ "$actual" = "$eexpected" ]; then
    pass "entry $eid classifier: $actual"
  else
    fail "entry $eid classifier" "expected [$eexpected] got [$actual]"
  fi

  # --- Layer 2: Hook end-to-end ---
  # Build synthetic stdin JSON. Escape backslashes and quotes in decoded.
  _esc="${decoded//\\/\\\\}"
  _esc="${_esc//\"/\\\"}"
  # Encode newlines as JSON \n.
  _esc="${_esc//$'\n'/\\n}"

  _stdin_json='{"tool_name":"Bash","tool_input":{"command":"'"$_esc"'"}}'

  _tmp_out="$(mktemp)"
  _tmp_err="$(mktemp)"
  printf '%s' "$_stdin_json" | bash "$HOOK" > "$_tmp_out" 2> "$_tmp_err"
  _rc=$?

  case "$actual" in
    allow)
      if [ "$_rc" -eq 0 ] && [ ! -s "$_tmp_out" ]; then
        pass "entry $eid hook: allow passthrough"
      else
        fail "entry $eid hook: allow passthrough" "rc=$_rc stdout=[$(cat "$_tmp_out")]"
      fi
      ;;
    rewrite:*)
      _expected_rewrite="${actual#rewrite:}"
      if [ "$_rc" -eq 0 ] && grep -qF "$_expected_rewrite" "$_tmp_out"; then
        pass "entry $eid hook: rewrite emits updatedInput"
      else
        fail "entry $eid hook: rewrite" "rc=$_rc stdout=[$(cat "$_tmp_out")]"
      fi
      ;;
    reject:*)
      _expected_class="${actual#reject:}"
      if [ "$_rc" -eq 2 ] && grep -qF "REJECT: ${_expected_class}" "$_tmp_err"; then
        pass "entry $eid hook: reject emits diagnostic"
      else
        fail "entry $eid hook: reject" "rc=$_rc stderr=[$(cat "$_tmp_err")]"
      fi
      ;;
  esac

  rm -f "$_tmp_out" "$_tmp_err"
done < "$_tmp"

rm -f "$_tmp"

# --- Entry count assertion ---
if [ "$entry_count" -eq "$EXPECTED_TOTAL" ]; then
  pass "corpus entry count: $entry_count"
else
  fail "corpus entry count" "expected $EXPECTED_TOTAL got $entry_count"
fi

# --- Final WOULD_PROMPT line (the SC-1 headline metric) ---
echo "WOULD_PROMPT=${would_prompt}/${EXPECTED_TOTAL}"

if [ "$would_prompt" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  echo "PASS: replay-prompt-corpus.sh"
  exit 0
fi
echo "FAIL: replay-prompt-corpus.sh ($fail_count failures)"
exit 1
```

### Step 2: Make the gate executable

```
chmod +x scripts/verify/replay-prompt-corpus.sh
```

### Step 3: Run the gate

```
bash scripts/verify/replay-prompt-corpus.sh
```

Expected final two lines (exactly):

```
WOULD_PROMPT=0/20
PASS: replay-prompt-corpus.sh
```

Exit code must be 0.

### Step 4: Confirm run-suite.sh picks it up via M021/P04

The gate's filename is `scripts/verify/replay-prompt-corpus.sh` — it does **not** match `m021-p04-*.sh`. Two equally-acceptable options:

- Option A (preferred): leave the filename as-is (its name is the canonical product name from the roadmap's `Produces` list and the spec's User Story 1). The phase suite script authored in T05 (`scripts/verify/m021-p04-phase-suite.sh`) invokes it explicitly alongside the `m021-p04-*.sh` glob discovery. This keeps the gate's identity tied to the spec language.
- Option B (rejected): rename to `scripts/verify/m021-p04-replay-prompt-corpus.sh`. Rejected because the roadmap and feature spec both name the file `replay-prompt-corpus.sh` verbatim; renaming breaks spec traceability.

T05 authors `scripts/verify/m021-p04-phase-suite.sh` which wraps both `run-suite.sh m021 P04` and an explicit invocation of `replay-prompt-corpus.sh`.

## Must-Haves

- `scripts/verify/replay-prompt-corpus.sh` exists, is executable.
- Gate parses 20 entries from `tests/fixtures/m021-prompt-corpus.txt`.
- For each entry: asserts classifier output equals `EXPECTED_OUTCOME` (Layer 1) AND hook end-to-end behavior matches the classifier's decision (Layer 2).
- Gate emits exactly one final `WOULD_PROMPT=N/20` line and one final `PASS:` or `FAIL:` line.
- Gate exits 0 iff `WOULD_PROMPT=0/20` AND all per-entry assertions pass.
- Bash 3.2 compatible — no `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, process substitution `<(`.

## Verification

- `bash scripts/verify/replay-prompt-corpus.sh` exits 0 with final `WOULD_PROMPT=0/20` and `PASS: replay-prompt-corpus.sh`.
- `bash scripts/verify/m021-p04-bash32-compat.sh` (T05) reports PASS on `replay-prompt-corpus.sh`.

## Inputs

### From Previous Tasks

- `tests/fixtures/m021-prompt-corpus.txt` (from T01) — parsed for 20 entries. Read: INPUT, EXPECTED_OUTCOME fields. SCREENSHOT ignored at gate level (audit metadata only).

### From Disk (Pre-existing)

- `scripts/verify/lib/shape-classifier.sh` (from P03/T01) — sourced; `classify_command` invoked per entry.
- `scripts/hooks/pre-bash-shape-guard.sh` (from P03/T02) — invoked as child process with piped stdin JSON per entry.
- `scripts/verify/run-suite.sh` — pre-existing discovery wrapper. Not consumed directly; T05's phase-suite invokes this gate explicitly.

## Constraints

- **Bash 3.2 compatibility** (constitution IX). The `${var//old/new}` form used for JSON escaping IS bash 3.2 safe — only the case-conversion forms (`${var,,}` / `${var^^}`) are bash-4+.
- **Single-script-file invocation** (AD-19). The gate is invoked from other scripts or developers as `bash scripts/verify/replay-prompt-corpus.sh` — no wrapping in compound chains.
- **Gate internals use `$()`, pipes, `awk`, heredocs freely** (MEM004 + AP-004 scope-of-enforcement carve-out). Verification-script internals are not agent-facing tool-call sites.
- **No mutation of classifier / hook / corpus**. The gate reads only.
- **Hermetic**: the gate creates tempfiles under `mktemp` and removes them. No writes under the repo tree.
- **Performance envelope**: 20 entries × (1 classifier call + 1 hook subprocess) ≈ 40 subprocesses. Expected runtime <3s on a modern laptop.

## Expected Output

- `scripts/verify/replay-prompt-corpus.sh` exists and is executable.
- `bash scripts/verify/replay-prompt-corpus.sh` exits 0.
- Output contains exactly 20 `PASS: entry NN classifier:` lines, 20 `PASS: entry NN hook:` lines (40 per-entry assertions total), 1 `PASS: corpus entry count: 20` line, and final two lines `WOULD_PROMPT=0/20` + `PASS: replay-prompt-corpus.sh`.
- `bash scripts/verify/m021-p04-bash32-compat.sh` (T05) includes `PASS: replay-prompt-corpus.sh parses clean`.
