---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M028"
name: "Replay Harness + Per-Finding Verifiers + Self-Conformance"
depends_on: ["T03", "T04"]
---

## Prerequisites

- `ANTIPATTERNS.md` carries AP-010..AP-014 (T01).
- `scripts/verify/lib/shape-classifier.sh` emits the 5 new reject classes with AP-014 ordered before AP-009 (T02).
- `scripts/hooks/pre-bash-shape-guard.sh::reject_lookup` carries the 5 new case arms (T03).
- `tests/fixtures/m021-prompt-corpus.txt` carries 27 entries (T04).
- The existing per-finding verifiers from P02 are present:
  - `scripts/verify/m028/finding-A-verifier.sh` (verified existing).
  - `scripts/verify/m028/finding-F-verifier.sh` (verified existing).
- The existing M021 SC-1 harness `scripts/verify/replay-prompt-corpus.sh` exists with EXPECTED_TOTAL=20.
- The new `tests/run-prompt-corpus-replay.sh` does NOT exist (verified: `find tests -name "*replay*corpus*" -type f` returns only the corpus fixture); T05 creates it.

## Description

Three deliverable rounds:

1. **The 27-entry replay harness** at `tests/run-prompt-corpus-replay.sh` — the spec/roadmap-named gate behind SC-1. Sources the classifier, parses the 27-entry corpus, runs each entry through `classify_command` plus the hook end-to-end (synthetic stdin JSON), asserts actual == expected verdict, prints `WOULD_PROMPT=N/27` (where N must be 0), and exits 0 only on 27/27 match. Plus a one-line patch to the M021 historical harness `scripts/verify/replay-prompt-corpus.sh` updating `EXPECTED_TOTAL=20` → `EXPECTED_TOTAL=27` to preserve harness symmetry on the extended corpus (CON-7 strict-superset is preserved structurally — the 20 M021 entries' verdicts are unchanged and the harness still passes).

2. **Five per-finding verifiers** under `scripts/verify/m028/` — `finding-B-verifier.sh`, `finding-C-verifier.sh`, `finding-G-classifier-verifier.sh`, `finding-G-self-conformance.sh`, plus the `run-all.sh` roll-up. Each verifier is a flat AD-19 single-script-file; helpers may be sourced from existing concern dirs only.

3. **Two plan-level verifiers** under `scripts/verify/m028/` for the P03 truth Checks T05 still owns — `p03-replay-harness-clean.sh` and `p03-finding-verifiers-present.sh`. Each is a flat AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, no jq.

   **Scope reduction (2026-04-29)**: The four per-task verifiers (`p03-antipatterns-entries.sh`, `p03-classifier-new-classes.sh`, `p03-reject-lookup-coverage.sh`, `p03-corpus-shape.sh`) are now co-authored with their respective tasks (T01–T04) per the CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing" — sibling-task verifier dependency made `auto-loop.sh --step=V` unsatisfiable for T01–T04. T01's verifier already exists on disk. T05 retains the cross-cutting verifiers only.

## Steps

### Round 1 — Replay harness

1. **Author `tests/run-prompt-corpus-replay.sh`** (~165 lines). Structurally identical to `scripts/verify/replay-prompt-corpus.sh` but parameterized for the M028-extended corpus:

```bash
#!/usr/bin/env bash
# tests/run-prompt-corpus-replay.sh -- M028 SC-1 + FR-22 regression gate.
#
# Parses tests/fixtures/m021-prompt-corpus.txt (27 entries: 20 M021 + 7 M028),
# invokes the shape-classifier library + the pre-bash-shape-guard hook on each
# INPUT, asserts 27/27 decisions match EXPECTED_OUTCOME, and prints the
# canonical final line: WOULD_PROMPT=N/27 where N=0 under the hardened config.
#
# Exit: 0 on all-pass (N=0 and 27/27 EXPECTED_OUTCOME matches), 1 otherwise.
#
# Bash 3.2 compatible. AD-19 single-script-file flat shape. No jq.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

EXPECTED_TOTAL=27
fail_count=0
would_prompt=0
entry_count=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Preconditions
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

# Parse corpus (same awk as M021 historical harness, preserves grammar).
_tmp="$(mktemp)"
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
' "$CORPUS" > "$_tmp"

# Per-entry assertions (same shape as M021 historical harness).
while IFS=$'\t' read -r eid einput eexpected; do
  entry_count=$((entry_count + 1))
  decoded="$(printf '%b' "$einput")"
  actual="$(classify_command "$decoded" 2>/dev/null)"
  case "$actual" in
    allow|rewrite:*|reject:*) : ;;
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

  # Hook end-to-end (same shape as M021 historical harness).
  _esc="${decoded//\\/\\\\}"
  _esc="${_esc//\"/\\\"}"
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
        _out_contents="$(cat "$_tmp_out")"
        fail "entry $eid hook: allow passthrough" "rc=$_rc stdout=[$_out_contents]"
      fi
      ;;
    rewrite:*)
      _expected_rewrite="${actual#rewrite:}"
      if [ "$_rc" -eq 0 ] && grep -qF "$_expected_rewrite" "$_tmp_out"; then
        pass "entry $eid hook: rewrite emits updatedInput"
      else
        _out_contents="$(cat "$_tmp_out")"
        fail "entry $eid hook: rewrite" "rc=$_rc stdout=[$_out_contents]"
      fi
      ;;
    reject:*)
      _expected_class="${actual#reject:}"
      if [ "$_rc" -eq 2 ] && grep -qF "REJECT: ${_expected_class}" "$_tmp_err"; then
        pass "entry $eid hook: reject emits diagnostic"
      else
        _err_contents="$(cat "$_tmp_err")"
        fail "entry $eid hook: reject" "rc=$_rc stderr=[$_err_contents]"
      fi
      ;;
  esac
  rm -f "$_tmp_out" "$_tmp_err"
done < "$_tmp"

rm -f "$_tmp"

# Entry count.
if [ "$entry_count" -eq "$EXPECTED_TOTAL" ]; then
  pass "corpus entry count: $entry_count"
else
  fail "corpus entry count" "expected $EXPECTED_TOTAL got $entry_count"
fi

# WOULD_PROMPT line.
echo "WOULD_PROMPT=${would_prompt}/${EXPECTED_TOTAL}"
if [ "$would_prompt" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  echo "PASS: tests/run-prompt-corpus-replay.sh"
  exit 0
fi
echo "FAIL: tests/run-prompt-corpus-replay.sh ($fail_count failures)"
exit 1
```

2. **Patch `scripts/verify/replay-prompt-corpus.sh`** — change `EXPECTED_TOTAL=20` to `EXPECTED_TOTAL=27` (line 23). The harness's parser is grammar-stable; the count assertion was the only entry-count tie. After the patch, both harnesses (`scripts/verify/replay-prompt-corpus.sh` and `tests/run-prompt-corpus-replay.sh`) report 27/27. The historical harness preserves its `# M021 SC-1` semantic claim because the 20 M021 entries' verdicts are unchanged (CON-7 strict-superset).

   Alternative: leave the historical harness at `EXPECTED_TOTAL=20` and document the post-T04 expected drift in a comment block. The plan-author recommendation is the patch (one line; preserves CI-runnability of both harnesses); document the path actually taken in the task summary.

### Round 2 — Per-finding verifiers

3. **Author `scripts/verify/m028/finding-B-verifier.sh`** (~120 lines). Exercises the four B-family entries (IDs 21–24) end-to-end through the hook:

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-B-verifier.sh -- M028 Finding B end-to-end gate.
#
# Finding B (in the wild): four shape classes outside M021's matrix that
# agents reach for during normal task execution:
#   B#1 cmd-sub-in-pattern (AP-010)      -- backtick in grep regex
#   B#2 quoted-arg-newline-hash (AP-011) -- newline + # in quoted CLI arg
#   B#3 multiline-quoted-script (AP-012) -- multi-line node -e body
#   B#4 unquoted-brace-glob (AP-013)     -- raw {N,M,...} outside quotes
#
# Each shape exercises the M028-extended classifier + hook end-to-end.
# Asserts hook exit 2 + literal "REJECT:" prefix + the expected AP-ID
# + the expected pattern-class label on stderr.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Helper: invoke hook with synthetic stdin JSON and assert exit 2 + REJECT
# substring + AP-ID substring on stderr.
# (Helper-function carve-out per AD-19: function bodies are NOT scanned by
# the AP-009 inline-command-shape classifier. Documented in M028/P02
# patterns; load-bearing for multi-step verifiers.)
assert_reject() {
  local label="$1" cmd="$2" class="$3" ap_id="$4"
  local _esc="${cmd//\\/\\\\}"
  _esc="${_esc//\"/\\\"}"
  _esc="${_esc//$'\n'/\\n}"
  local _stdin='{"tool_name":"Bash","tool_input":{"command":"'"$_esc"'"}}'
  local _err
  _err="$(mktemp)"
  printf '%s' "$_stdin" | bash "$HOOK" > /dev/null 2> "$_err"
  local _rc=$?
  local _err_text
  _err_text="$(cat "$_err")"
  rm -f "$_err"
  if [ "$_rc" -eq 2 ] && \
     printf '%s' "$_err_text" | grep -qF "REJECT: $class" && \
     printf '%s' "$_err_text" | grep -qF "$ap_id"; then
    pass "$label -> reject:$class (#$ap_id)"
  else
    fail "$label -> reject:$class" "rc=$_rc stderr=[$_err_text]"
  fi
}

# B#1: backtick in grep regex (AP-010)
assert_reject "B#1 cmd-sub-in-pattern" \
  "grep '^- \`bash scripts/util/' commands/dispatch.md" \
  "cmd-sub-in-pattern" "AP-010"

# B#2: newline + # in quoted arg (AP-011)
assert_reject "B#2 quoted-arg-newline-hash" \
  $'bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"' \
  "quoted-arg-newline-hash" "AP-011"

# B#3: multi-line node -e body (AP-012)
assert_reject "B#3 multiline-quoted-script" \
  $'node -e "const x = 1;\nconsole.log(x);\n"' \
  "multiline-quoted-script" "AP-012"

# B#4: unquoted brace glob (AP-013)
assert_reject "B#4 unquoted-brace-glob" \
  "ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md" \
  "unquoted-brace-glob" "AP-013"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-B-verifier.sh"
  exit 0
fi
echo "FAIL: finding-B-verifier.sh ($fail_count failures)"
exit 1
```

4. **Author `scripts/verify/m028/finding-C-verifier.sh`** (~80 lines). Proves the SE-06 investigation-compound shape still rejects under M028 as `compound-chain-gt2` (CON-7 strict-superset; AP-009 untouched):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-C-verifier.sh -- M028 Finding C / E end-to-end gate.
#
# Finding C / E (in the wild): agents construct grep ... ; echo "---" ; grep ...
# compound shells when no canonical investigation example covers the shape.
# AP-009 (compound-chain-gt2) already rejects this shape; this verifier proves
# that the M028-extended classifier preserves the AP-009 reject (CON-7 strict-
# superset).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

# (Same assert_reject helper as finding-B-verifier; helper-function carve-out.)
# ...

# SE-06 verbatim: 3-stage compound chain — must reject as compound-chain-gt2 (AP-009).
assert_reject "SE-06 investigation-compound" \
  'grep -n classify_command scripts/verify/lib/shape-classifier.sh; echo "---"; grep -n reject_lookup scripts/hooks/pre-bash-shape-guard.sh' \
  "compound-chain-gt2" "AP-009"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-C-verifier.sh"
  exit 0
fi
echo "FAIL: finding-C-verifier.sh ($fail_count failures)"
exit 1
```

5. **Author `scripts/verify/m028/finding-G-classifier-verifier.sh`** (~80 lines). Proves the verbatim Finding G command rejects under M028 as `xargs-sh-c-compound-body` (NOT `compound-chain-gt2`); proves AP-014 takes precedence per CON-5:

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-G-classifier-verifier.sh -- M028 Finding G classifier gate.
#
# Finding G (in the wild): find ... | head | xargs -I{} sh -c 'echo; head' shape
# hides a compound chain inside the sh -c body. M021 rejected this as
# compound-chain-gt2 (top-level pipe count = 3). M028 must reject as
# xargs-sh-c-compound-body — the more specific verdict reflecting CON-5
# body-descent and taking the bypass surface (the "don't ask again" allowlist
# rule on the literal sh -c '...' bytes) off the table.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier not found at $CLASSIFIER" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Verbatim Finding G command (SE-09).
SE09_CMD='find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c '"'"'echo "═══ {} ═══"; head -20 "{}"'"'"

actual_se09="$(classify_command "$SE09_CMD" 2>/dev/null)"
if [ "$actual_se09" = "reject:xargs-sh-c-compound-body" ]; then
  pass "SE-09 verdict: $actual_se09 (AP-014 precedence over AP-009; CON-5)"
else
  fail "SE-09 verdict" "expected [reject:xargs-sh-c-compound-body] got [$actual_se09]"
fi

# CON-5 boundary: nested sh -c — inner is opaque.
ID27_CMD="find . | xargs -I{} sh -c 'sh -c \"echo nested\"; head {}'"
actual_id27="$(classify_command "$ID27_CMD" 2>/dev/null)"
if [ "$actual_id27" = "reject:xargs-sh-c-compound-body" ]; then
  pass "ID-27 nested sh -c opaque-treatment: $actual_id27 (CON-5 one-level-deep)"
else
  fail "ID-27 boundary" "expected [reject:xargs-sh-c-compound-body] got [$actual_id27]"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-classifier-verifier.sh"
  exit 0
fi
echo "FAIL: finding-G-classifier-verifier.sh ($fail_count failures)"
exit 1
```

6. **Author `scripts/verify/m028/finding-G-self-conformance.sh`** (~100 lines, FR-21 / SC-9). Reads `scripts/hooks/pre-bash-shape-guard.sh`, sources the M028 classifier, runs `classify_command` on every non-comment, non-blank line in the resolution + dispatch + reject_lookup blocks, asserts every line returns `allow` under the M028-extended classifier:

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-G-self-conformance.sh -- M028 FR-21 / SC-9 hook self-conformance.
#
# Asserts that scripts/hooks/pre-bash-shape-guard.sh itself contains no line
# the M028-extended classifier would reject. The scope is the same scoped
# region the P02/T01 self-conformance verifier used (resolution block) plus
# the M028/P03/T03 reject_lookup case arms — case-arm bodies are
# carve-out-exempt per AD-19 (function/case bodies are NOT inline-shape
# scanned; M028/P02 dogfood codification).
#
# Helper-function carve-out: classify_one() wraps the classify_command call
# in a function body so the call's $(...) does not trigger the AP-009
# classifier on this verifier's own source. M028/P02/T05 pattern.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found" >&2; exit 1
fi
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier not found" >&2; exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Helper-function carve-out (AD-19): function bodies are NOT scanned by
# the AP-009 inline-command-shape classifier. M028/P02 dogfood codification.
classify_one() {
  classify_command "$1" 2>/dev/null
}

# Scope: every non-comment, non-blank line in the resolution block and the
# dispatch block. Use the same scope markers P02/T01 used: between the
# "# Locate classifier" comment and the "# Read stdin" divider.
# For P03 extension, also include lines between "reject_lookup() {" and
# the closing "}" — case-arm bodies are carve-out-exempt at the inline-shape
# layer, but each printf statement IS a single command line and must classify
# as `allow`.

# (Implementation: bash sed -n '<start>,<end>p' to extract the scoped lines,
# walk each via while IFS= read -r line, skip blank/comment lines, run
# classify_one, assert allow.)

# For brevity in this plan, we describe the assertion only:
# - Scope 1 (resolution block, lines 35..64): every non-comment non-blank line classifies as allow.
# - Scope 2 (reject_lookup case arms, lines 25..38 post-T03): every printf line classifies as allow.
# - Scope 3 (dispatch case branches, lines 153..187): every line classifies as allow.

# Aggregate verdict — emitted as a single line per scope.
# (Plan: T05 author writes the actual sed-extract + while-read + classify_one
# loop, asserting per-line allow. The exact line-range numbers are recomputed
# at T05 author time against the post-T03 file shape. The shape rule is
# stable: every line introduced by P02/P03 classifies as allow under the
# M028-extended classifier.)

# ... loop ...

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-self-conformance.sh"
  exit 0
fi
echo "FAIL: finding-G-self-conformance.sh ($fail_count failures)"
exit 1
```

The plan author at T05 time will compute the exact line ranges against the post-T03 hook shape and write the per-line scan. Per the M028/P02/T01 self-conformance scope precedent, the verifier asserts only the resolution + dispatch + new reject_lookup arms — not the entire hook body (the M021 surface outside these regions remains immutable per CON-7).

7. **Author `scripts/verify/m028/run-all.sh`** (~80 lines). Roll-up that invokes all 7 per-finding verifiers (A and F from P02; B, C, G-classifier, G-self-conformance from P03; D and E are P04 deliverables — `run-all.sh` reports `5/7 PASS` in P03 and `7/7 PASS` once P04 lands):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/run-all.sh -- M028 SC-4 per-finding roll-up.
#
# Invokes every per-finding verifier under scripts/verify/m028/ (one per
# Finding A..G), summarizes pass/fail, and prints "M028: <pass>/7 findings
# verified" on the final line. Findings D and E are P04 deliverables; this
# roll-up reports their absence as a SKIP (not a fail) until P04 lands.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"

VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh \
finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh \
finding-G-classifier-verifier.sh"

pass_count=0
fail_count=0
skip_count=0
total=7

for v in $VERIFIERS; do
  if [ ! -f "${script_dir}/${v}" ]; then
    echo "SKIP: ${v} (not yet authored)"
    skip_count=$((skip_count + 1))
    continue
  fi
  if bash "${script_dir}/${v}" >/dev/null 2>&1; then
    echo "PASS: ${v}"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: ${v}"
    fail_count=$((fail_count + 1))
  fi
done

# Note: the G-classifier-verifier counts as the Finding G verifier (the
# self-conformance verifier is a separate axis; it gates SC-9, not SC-4).

echo "M028: ${pass_count}/${total} findings verified (skipped: ${skip_count}, failed: ${fail_count})"

if [ "$fail_count" -eq 0 ]; then
  exit 0
fi
exit 1
```

### Round 3 — Plan-level verifiers

8. **Author the two cross-cutting plan-level verifiers** under `scripts/verify/m028/`. Each is a flat AD-19 single-script-file. Naming: `p03-<truth-name>.sh` mirroring P02's `p02-*.sh` convention. Bash 3.2 + POSIX-sh-safe; no jq.

   The four per-task verifiers (`p03-antipatterns-entries.sh`, `p03-classifier-new-classes.sh`, `p03-reject-lookup-coverage.sh`, `p03-corpus-shape.sh`) ship as part of T01–T04 respectively (per the CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"); T05 does NOT re-author them. T05 owns only the cross-cutting verifiers below:

   - **`p03-replay-harness-clean.sh`** (~40 lines): asserts `tests/run-prompt-corpus-replay.sh` exists and is executable; runs it; asserts exit 0 and output line `WOULD_PROMPT=0/27`.
   - **`p03-finding-verifiers-present.sh`** (~50 lines): asserts each per-finding verifier file exists under `scripts/verify/m028/` (A, B, C, F, G-classifier, G-self-conformance present in P03; D and E SKIP-acknowledged); asserts `run-all.sh` exists and `bash run-all.sh` exits 0 with "M028: 5/7 findings verified" or "M028: 7/7 findings verified" depending on P04 state.

9. **Run the plan-level verifiers locally** before commit; iterate on any individual verifier whose assertion shape needs tightening. The authoring agent should expect to need 1–2 iterations on `p03-classifier-new-classes.sh` and `p03-corpus-shape.sh` (those have the most substantive byte-level assertions).

10. **Run the full P03 verification sweep**:

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03
```

```bash
bash tests/run-prompt-corpus-replay.sh
```

```bash
bash scripts/verify/m028/run-all.sh
```

All three must report PASS / `WOULD_PROMPT=0/27` / `M028: 5/7 findings verified` (the 5/7 acknowledges D + E as P04 deliverables).

11. **Commit** via `git commit -F <message-file>`.

## Must-Haves

This task addresses the phase Truths:
- "The replay harness `tests/run-prompt-corpus-replay.sh` exists, parses the 27 entries, runs each through the classifier + hook end-to-end, asserts every actual verdict equals the expected verdict, and exits 0 only on 27/27 match."
- "The hook body `scripts/hooks/pre-bash-shape-guard.sh` lints clean against the M028 classifier."
- "Per-finding verifiers exist for B (4 sub-shapes), C (investigation-pattern reject), and G (classifier descent + self-conformance); the verifier roll-up `scripts/verify/m028/run-all.sh` exists and invokes A, B, C, F, G."

The plan-level verifiers `p03-replay-harness-clean.sh`, `p03-finding-verifiers-present.sh`, and `finding-G-self-conformance.sh` (T05 deliverables themselves) implement the assertion logic.

## Verification

```bash
bash scripts/verify/m028/p03-replay-harness-clean.sh
```

```bash
bash scripts/verify/m028/p03-finding-verifiers-present.sh
```

```bash
bash scripts/verify/m028/finding-G-self-conformance.sh
```

```bash
bash tests/run-prompt-corpus-replay.sh
```

```bash
bash scripts/verify/m028/run-all.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03
```

## Inputs

### From Previous Tasks

- `ANTIPATTERNS.md` (T01) — the AP-IDs the plan-level verifiers and per-finding verifiers cite.
- `scripts/verify/lib/shape-classifier.sh` (T02) — the classifier the harness sources; the new reject classes are the targets the verifiers assert on.
- `scripts/hooks/pre-bash-shape-guard.sh` (T03) — the hook the harness invokes end-to-end; the new reject_lookup arms are the targets the coverage verifier asserts on.
- `tests/fixtures/m021-prompt-corpus.txt` (T04) — the 27-entry corpus the harness parses.

### From Disk (Pre-existing)

- `scripts/verify/replay-prompt-corpus.sh` — M021 SC-1 historical harness; T05 patches `EXPECTED_TOTAL` and re-runs to confirm post-patch parity.
- `scripts/verify/m028/finding-A-verifier.sh` (P02) — invoked by `run-all.sh`.
- `scripts/verify/m028/finding-F-verifier.sh` (P02) — invoked by `run-all.sh`.
- `scripts/verify/m028/p02-hook-self-locate.sh` (P02) — preserved; T05's `finding-G-self-conformance.sh` is a separate verifier that extends scope to the new code.
- `scripts/verify/m028/p02-hook-self-conformance.sh` (P02) — preserved; T05's verifier supersedes-by-extension on the M028-extended classifier baseline.
- `scripts/verify/check-must-haves.sh` — the standard phase-level Tier 1 verifier the truth Checks roll up into.

### Key API Surface

- `classify_command "<cmd>"` from `scripts/verify/lib/shape-classifier.sh`; T05's harness and four verifiers source this and call it directly. The function emits a single line of `allow` / `rewrite:<r>` / `reject:<c>`.
- `reject_lookup <pattern-class>` from `scripts/hooks/pre-bash-shape-guard.sh`; T05's `p03-reject-lookup-coverage.sh` either sources the hook in a special test-mode (the hook body is structured so sourcing without stdin yields the function definitions) or extracts the case body via grep + per-arm sed for assertion. Plan-author choice; document in the verifier's comment block.

## Constraints

- **CON-1 (AD-19)**: Every script is a flat single-file shape. Helpers may be sourced from existing concern dirs (`scripts/dispatch/`, `scripts/state/`, `scripts/util/`, `scripts/verify/lib/`) only; no new nested helper dirs under `scripts/verify/m028/`.
- **CON-2 (bash 3.2 + POSIX sh)**: All scripts use bash 3.2 grammar; no `mapfile`, no `<<<` here-strings, no process substitution, no `declare -A`. The `printf '%b'` corpus-decode pattern (used in the harness) is bash 3.2 + POSIX-sh-safe.
- **CON-3 (shape-guard self-conformance)**: T05's `finding-G-self-conformance.sh` is the FR-21 / SC-9 gate. Per the M028/P02/T01 scope precedent, the verifier asserts on the resolution + dispatch + reject_lookup arms (not the entire hook body) — the M021 surface outside these regions stays immutable per CON-7.
- **Helper-function carve-out (AD-19)**: T05 verifiers may define `classify_one()`, `assert_reject()`, etc. as bash functions and call them inline. Function bodies are NOT scanned by the AP-009 inline-command-shape classifier; this is the M028/P02 codified convention. T05 verifiers cite this carve-out in a comment block at top-of-script.
- **CON-7 (no-M021-regression)**: All 20 M021 corpus entries replay with verdicts unchanged. The strict-superset invariant is asserted by the new harness (entries 01..20 in the 27-entry replay produce identical verdicts to the M021 SC-1 baseline).
- **Verification-section authoring**: Per the M028/P02 dogfood findings, the `## Verification` sections in this plan invoke project-tree verifiers directly (`bash scripts/verify/m028/<name>.sh`); they do NOT wrap with `run-probe.sh`. Expected output is documented in the `## Expected Output` section, not in the `## Verification` section's fenced blocks.
- **Commit-message form**: Use `git commit -F <message-file>` per CLAUDE.md hotfix list. The heredoc-with-expansion form is rejected by the active AP-008 hook.
- **Plan-time prerequisite-existence verification**: Per CLAUDE.md hotfix list — every prerequisite path was verified at plan-authoring time:
  - `scripts/verify/m028/finding-A-verifier.sh` exists (post-P02 disk).
  - `scripts/verify/m028/finding-F-verifier.sh` exists (post-P02 disk).
  - `scripts/verify/m028/p02-hook-self-locate.sh` exists (post-P02 disk).
  - `scripts/verify/m028/p02-hook-self-conformance.sh` exists (post-P02 disk).
  - `scripts/verify/replay-prompt-corpus.sh` exists with EXPECTED_TOTAL=20 (M021 historical).
  - `tests/run-prompt-corpus-replay.sh` does NOT exist; T05 creates it.
  - `tests/fixtures/m021-prompt-corpus.txt` exists with 20 entries; T04 extends to 27.

## Expected Output

After `bash tests/run-prompt-corpus-replay.sh` (post-T04 corpus + post-T02/T03 classifier+hook):

```
PASS: entry 01 classifier: rewrite:bash scripts/util/run-probe.sh /tmp/m011-p05-probe.sh
PASS: entry 01 hook: rewrite emits updatedInput
... (27 entries)
PASS: entry 25 classifier: reject:xargs-sh-c-compound-body
PASS: entry 25 hook: reject emits diagnostic
... (continues to entry 27)
PASS: corpus entry count: 27
WOULD_PROMPT=0/27
PASS: tests/run-prompt-corpus-replay.sh
```

After `bash scripts/verify/m028/run-all.sh`:

```
PASS: finding-A-verifier.sh
PASS: finding-B-verifier.sh
PASS: finding-C-verifier.sh
SKIP: finding-D-verifier.sh (not yet authored)
SKIP: finding-E-verifier.sh (not yet authored)
PASS: finding-F-verifier.sh
PASS: finding-G-classifier-verifier.sh
M028: 5/7 findings verified (skipped: 2, failed: 0)
```

After `bash scripts/verify/m028/finding-G-self-conformance.sh`:

```
PASS: resolution-block lines (T01 scope) classify as allow under M028
PASS: reject_lookup case arms (T03 scope) classify as allow under M028
PASS: dispatch case branches classify as allow under M028
PASS: finding-G-self-conformance.sh
```

After `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03`:

```
... (all 7 truths PASS, 16 artifact assertions PASS, 13 key-link assertions PASS)
PASS: P03 must-haves: 36/36
```

(Counts above are illustrative; T05 author re-confirms the actual assertion count after `check-must-haves.sh` re-parses the phase plan.)
