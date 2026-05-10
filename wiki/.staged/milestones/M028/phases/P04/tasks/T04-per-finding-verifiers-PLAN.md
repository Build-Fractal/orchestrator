---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M028"
name: "Per-Finding Verifiers — D, E, G-wrapper"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time:

- `scripts/verify/m028/` directory exists with the M028 verifier suite from P02 + P03.
- `scripts/verify/m028/finding-A-verifier.sh` (P02) exists.
- `scripts/verify/m028/finding-B-verifier.sh` (P03) exists.
- `scripts/verify/m028/finding-C-verifier.sh` (P03) exists.
- `scripts/verify/m028/finding-F-verifier.sh` (P02) exists.
- `scripts/verify/m028/finding-G-classifier-verifier.sh` (P03) exists.
- `scripts/verify/m028/finding-G-self-conformance.sh` (P03) exists.

Files T04 expects to exist (T01 + T02 deliverables) after upstream tasks complete:
- `scripts/util/grep-files.sh` (T01)
- `scripts/util/cleanup-stale-results.sh` (T01)
- `scripts/util/node-eval.sh` (T02)
- `scripts/util/peek-files.sh` (T02)
- (T03 documentation deliverables — referenced for cross-link prose only, not for verifier assertion logic.)

The per-finding verifiers `finding-D-verifier.sh`, `finding-E-verifier.sh`, `finding-G-wrapper-verifier.sh` do NOT exist on disk before T04 (verified absent at plan-authoring time); T04 creates them.

## Description

Author three per-finding end-to-end verifiers under `scripts/verify/m028/`. Each is a flat AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, no jq.

1. **`finding-D-verifier.sh`** — exercises `cleanup-stale-results.sh` end-to-end against an isolated tmp tree mirroring the `.orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt` shape; asserts the wrapper produces the expected `REMOVED:`/`RESIDUAL:`/`OK` output and refuses paths outside the milestone tree (the boundary refusal is the load-bearing Finding D contract — without it, the wrapper would reproduce the unbounded `/bin/rm -f` Screenshot 2 hazard).

2. **`finding-E-verifier.sh`** — exercises `grep-files.sh` and `node-eval.sh` happy paths to confirm both investigation-pattern wrappers are reachable from a non-orchestrator-repo working dir context. Finding E in the spec is "agents invent compound shells when no canonical investigation example covers them"; the verifier proves the canonical examples are wired and produce the operator's intended output. The verifier does NOT assert anything about *how* an agent picks the wrapper — that's the documentation's job (T03); the verifier asserts the wrappers run successfully when called.

3. **`finding-G-wrapper-verifier.sh`** — the wrapper-side complement of `finding-G-classifier-verifier.sh` (P03). The P03 verifier proves the classifier rejects the verbatim Finding G shape; the P04 verifier proves `peek-files.sh` produces the operator's intended output (per-file separators + head-N each match) for the same use case (`T*-SUMMARY.md` recursive head-20) without invoking the AP-014 `xargs sh -c '<body>'` shape. Together the two G verifiers close the loop: classifier rejects bad shape, wrapper produces good output.

## Steps

### Round 1 — `finding-D-verifier.sh`

1. **Author `scripts/verify/m028/finding-D-verifier.sh`** (~80 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-D-verifier.sh -- M028 Finding D end-to-end gate.
#
# Finding D (in the wild): destructive `/bin/rm -f .../*.txt && ls .../*.txt`
# always prompts under Claude Code's destructive-op policy. The remediation is
# the wrapper `scripts/util/cleanup-stale-results.sh <milestone-id>` that
# performs the rm + listing internally, refuses paths outside the milestone
# tree, and emits a structured summary.
#
# This verifier proves the wrapper's contract end-to-end:
#   1. Happy path: 4 stale .txt files staged, wrapper removes all 4, REMOVED=4 RESIDUAL=0.
#   2. Boundary refusal: invalid milestone ID -> exit 2.
#   3. Missing tree: valid ID but no tree -> exit 1.
#   4. Multi-phase: stale files under multiple phases all removed.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/cleanup-stale-results.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found (Finding D wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Stage isolated tmp tree.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/scripts/util"
cp "$WRAPPER" "$tmp_root/scripts/util/cleanup-stale-results.sh"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks"
printf 'a\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T01-r.txt"
printf 'b\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T02-r.txt"
printf 'c\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T01-r.txt"
printf 'd\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T02-r.txt"

# Case 1 + 4: happy path multi-phase.
out="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M999)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0"; else fail "case1 exit" "rc=$rc"; fi
echo "$out" | grep -q '^REMOVED: 4$' && pass "case1 REMOVED=4 (multi-phase)" || fail "case1 REMOVED=4" "got [$out]"
echo "$out" | grep -q '^RESIDUAL: 0$' && pass "case1 RESIDUAL=0" || fail "case1 RESIDUAL=0" "got [$out]"
echo "$out" | grep -q '^OK$' && pass "case1 OK terminator" || fail "case1 OK" "got [$out]"

# Case 2: boundary refusal -- invalid milestone ID.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" "../escape" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case2 boundary refusal on path-escape ID"; else fail "case2 refusal" "rc=$rc"; fi

bash "$tmp_root/scripts/util/cleanup-stale-results.sh" "/etc" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case2b boundary refusal on absolute path"; else fail "case2b refusal" "rc=$rc"; fi

# Case 3: missing tree.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M998 2>/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case3 exit 1 on missing tree"; else fail "case3 exit" "rc=$rc"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-D-verifier.sh"
  exit 0
fi
echo "FAIL: finding-D-verifier.sh ($fail_count failures)"
exit 1
```

### Round 2 — `finding-E-verifier.sh`

2. **Author `scripts/verify/m028/finding-E-verifier.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-E-verifier.sh -- M028 Finding E end-to-end gate.
#
# Finding E (in the wild): agents invent compound shells when no canonical
# investigation example covers them (M028 spec Findings C, D, E group). The
# documentation surfaces (dispatch.md, dispatch-prompt.md, ANTIPATTERNS.md
# Investigation patterns subsection) cover the discoverability axis (T03);
# the wrapper-existence axis is asserted by p04-wrappers-present.sh (T05).
#
# This verifier asserts the operational axis: when an agent calls one of the
# canonical wrappers, it produces the expected output. We exercise grep-files.sh
# and node-eval.sh end-to-end to prove they are operationally reachable from
# a non-orchestrator-repo working dir context.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
GREP_FILES="${REPO_ROOT}/scripts/util/grep-files.sh"
NODE_EVAL="${REPO_ROOT}/scripts/util/node-eval.sh"

if [ ! -f "$GREP_FILES" ]; then
  echo "FAIL: $GREP_FILES not found (Finding E wrapper missing)" >&2
  exit 1
fi
if [ ! -f "$NODE_EVAL" ]; then
  echo "FAIL: $NODE_EVAL not found (Finding E wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# grep-files.sh end-to-end: stage 2 files, grep an investigation-pattern.
printf 'classify_command "foo"\nset -u\n' > "$tmp/a.sh"
printf 'classify_command "$cmd"\necho done\n' > "$tmp/b.sh"

out_grep="$(bash "$GREP_FILES" 'classify_command' "$tmp/a.sh" "$tmp/b.sh")"
rc=$?
if [ "$rc" -eq 0 ]; then pass "grep-files.sh end-to-end exit 0"; else fail "grep-files.sh exit" "rc=$rc"; fi
sep_count="$(printf '%s\n' "$out_grep" | grep -c '^--- ')"
if [ "$sep_count" -eq 2 ]; then pass "grep-files.sh emits 2 separators"; else fail "grep-files.sh separators" "got $sep_count"; fi
match_count="$(printf '%s\n' "$out_grep" | grep -c 'classify_command')"
if [ "$match_count" -ge 2 ]; then pass "grep-files.sh emits matches"; else fail "grep-files.sh matches" "got $match_count"; fi

# node-eval.sh end-to-end: stage a .js, run wrapper, assert stdout.
if command -v node >/dev/null 2>&1; then
  printf 'console.log("FINDING_E_NODE_OK");\n' > "$tmp/probe.js"
  out_node="$(bash "$NODE_EVAL" "$tmp/probe.js")"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$out_node" = "FINDING_E_NODE_OK" ]; then
    pass "node-eval.sh end-to-end emits expected stdout"
  else
    fail "node-eval.sh end-to-end" "rc=$rc out=[$out_node]"
  fi
else
  echo "SKIP: node-eval.sh end-to-end (node not on PATH)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-E-verifier.sh"
  exit 0
fi
echo "FAIL: finding-E-verifier.sh ($fail_count failures)"
exit 1
```

### Round 3 — `finding-G-wrapper-verifier.sh`

3. **Author `scripts/verify/m028/finding-G-wrapper-verifier.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/finding-G-wrapper-verifier.sh -- M028 Finding G wrapper-path gate.
#
# Finding G (in the wild): the verbatim shape
#   find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null \
#     | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'
# trips AP-014 under the M028 classifier (verified by finding-G-classifier-
# verifier.sh in P03). The wrapper-side complement: peek-files.sh produces
# the operator's intended output for the same use case without invoking the
# AP-014 shape internally.
#
# Cases:
#   1. Happy path: stage 4 T*-SUMMARY.md files, run peek-files.sh with
#      --max 3 --lines 20, assert 3 separators + content from each.
#   2. --exclude path: stage 1 file under "excluded/" subdir, --exclude
#      excluded; assert excluded content absent from output.
#   3. No internal sh -c: assert peek-files.sh source contains no
#      `sh -c '` literal (the wrapper's self-conformance to the AP-014
#      remediation contract).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/peek-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found (Finding G wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stage tree mirroring the Finding G use case.
mkdir -p "$tmp/M001/phases/P01/tasks" "$tmp/M002/phases/P01/tasks" "$tmp/M066/phases/P01/tasks"
printf 'M001-T01-line1\nM001-T01-line2\n' > "$tmp/M001/phases/P01/tasks/T01-SUMMARY.md"
printf 'M001-T02-line1\nM001-T02-line2\n' > "$tmp/M001/phases/P01/tasks/T02-SUMMARY.md"
printf 'M002-T01-line1\nM002-T01-line2\n' > "$tmp/M002/phases/P01/tasks/T01-SUMMARY.md"
printf 'M066-T01-EXCLUDED\n' > "$tmp/M066/phases/P01/tasks/T01-SUMMARY.md"

prev_dir="$(pwd -P)"
cd "$tmp"

# Case 1: happy path -- 4 matches without --exclude, --max 3 -> 3 separators.
out="$(bash "$WRAPPER" 'T*-SUMMARY.md' --max 3 --lines 20)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0"; else fail "case1 exit" "rc=$rc"; fi
sep="$(printf '%s\n' "$out" | grep -c '^--- ')"
if [ "$sep" -eq 3 ]; then pass "case1 --max 3 enforced"; else fail "case1 --max" "got $sep"; fi

# Case 2: --exclude M066.
out2="$(bash "$WRAPPER" 'T*-SUMMARY.md' --exclude M066)"
if printf '%s\n' "$out2" | grep -q 'EXCLUDED'; then
  fail "case2 --exclude M066" "excluded content present"
else
  pass "case2 --exclude M066 filters"
fi

cd "$prev_dir"

# Case 3: wrapper-source self-conformance -- peek-files.sh contains no `sh -c '` literal.
if grep -q "sh -c '" "$WRAPPER"; then
  fail "case3 self-conformance" "peek-files.sh source contains sh -c literal"
else
  pass "case3 peek-files.sh self-conformance (no sh -c internal)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-wrapper-verifier.sh"
  exit 0
fi
echo "FAIL: finding-G-wrapper-verifier.sh ($fail_count failures)"
exit 1
```

4. **Run all three new verifiers locally** before commit:

```bash
bash scripts/verify/m028/finding-D-verifier.sh
```

```bash
bash scripts/verify/m028/finding-E-verifier.sh
```

```bash
bash scripts/verify/m028/finding-G-wrapper-verifier.sh
```

5. **Commit** via `git commit -F <message-file>`.

## Must-Haves

This task addresses the phase Truth:

- "Per-finding end-to-end verifiers exist for Findings D, E, and the G wrapper path …"

The verifiers themselves (the three scripts T04 authors) are the deliverables. T05's `p04-finding-verifiers-present.sh` then asserts they exist and run; T05 also updates `run-all.sh` so the suite reaches 7/7.

## Verification

```bash
bash scripts/verify/m028/finding-D-verifier.sh
```

```bash
bash scripts/verify/m028/finding-E-verifier.sh
```

```bash
bash scripts/verify/m028/finding-G-wrapper-verifier.sh
```

## Inputs

### From Previous Tasks

- `scripts/util/grep-files.sh` (T01) — invoked end-to-end by `finding-E-verifier.sh`.
- `scripts/util/cleanup-stale-results.sh` (T01) — invoked end-to-end by `finding-D-verifier.sh`.
- `scripts/util/node-eval.sh` (T02) — invoked end-to-end by `finding-E-verifier.sh`.
- `scripts/util/peek-files.sh` (T02) — invoked end-to-end by `finding-G-wrapper-verifier.sh`.
- (T03 deliverables — not directly consumed by T04 verifiers; only by T05's `p04-investigation-section.sh` and `p04-anti-pattern-lint-clean.sh` already authored under T03.)

### Wrapper API Surface (used by T04 verifiers)

- `cleanup-stale-results.sh <milestone-id>` — returns 0 / 1 / 2; emits `REMOVED: <N>` / `RESIDUAL: <count>` / `OK`. Refuses non-`M[0-9]+` IDs, refuses paths outside `.orchestrator/milestones/<MID>/`.
- `grep-files.sh <pattern> <file...>` — returns 0 / 1 / 2; emits `--- <file> ---` separators + grep matches.
- `node-eval.sh <script-path> [args...]` — exec's `node`; returns node's exit code; refuses `-e/-p`.
- `peek-files.sh <glob> [--lines N] [--exclude PATH] [--max N]` — returns 0 / 1 / 2; emits `--- <file> ---` separators + head-N each match. Internal impl uses `find` + `while-read`; never invokes `sh -c`.

### From Disk (Pre-existing)

- `scripts/verify/m028/finding-A-verifier.sh` (P02), `finding-B-verifier.sh`, `finding-C-verifier.sh` (P03), `finding-F-verifier.sh` (P02), `finding-G-classifier-verifier.sh`, `finding-G-self-conformance.sh` (P03) — sibling per-finding verifiers; T04's three new verifiers follow the same shape (mktemp + happy path + boundary cases + `pass` / `fail` aggregator + structured exit).

## Constraints

- **CON-1 (AD-19)**: Each verifier is a flat single-file shape. No nested helpers; no sourcing from outside `scripts/verify/lib/`.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<`, no process substitution, no `declare -A`.
- **CON-7 (no-M021-regression)**: T04's verifiers are additive; they do not modify any existing verifier or AP-001..AP-014 entry. The strict-superset invariant is preserved structurally.
- **End-to-end discipline**: Each verifier MUST exercise its target wrapper end-to-end (stage tmp tree → run wrapper → assert output). Source-only assertions (e.g. "wrapper file contains substring X") are not sufficient — the per-finding contract requires runtime behavior verification.
- **Self-conformance check**: `finding-G-wrapper-verifier.sh` MUST assert that `peek-files.sh`'s source does not contain a `sh -c '` literal (case 3). The wrapper exists to retire AP-014; reproducing the shape inside the wrapper would defeat the point. This source-level assertion complements the end-to-end behavioral assertion.
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: All three `## Verification` checks resolve to scripts T04 itself authors.
- **Plan-time classifier-shape pre-validation**: The verifier-invocation lines `bash scripts/verify/m028/finding-D-verifier.sh` (etc.) traced through `classify_command` → `allow`. Internal verifier-body lines (function definitions, conditionals, loops) are not classifier-scanned (helper-function carve-out from M028/P02 — function bodies are NOT inline-shape scanned).
- **Commit-message form**: `git commit -F <file>`.

## Expected Output

After `bash scripts/verify/m028/finding-D-verifier.sh`:

```
PASS: case1 exit 0
PASS: case1 REMOVED=4 (multi-phase)
PASS: case1 RESIDUAL=0
PASS: case1 OK terminator
PASS: case2 boundary refusal on path-escape ID
PASS: case2b boundary refusal on absolute path
PASS: case3 exit 1 on missing tree
PASS: finding-D-verifier.sh
```

After `bash scripts/verify/m028/finding-E-verifier.sh`:

```
PASS: grep-files.sh end-to-end exit 0
PASS: grep-files.sh emits 2 separators
PASS: grep-files.sh emits matches
PASS: node-eval.sh end-to-end emits expected stdout
PASS: finding-E-verifier.sh
```

(If `node` is not on PATH, the `node-eval.sh` block prints `SKIP:` and the verifier still passes.)

After `bash scripts/verify/m028/finding-G-wrapper-verifier.sh`:

```
PASS: case1 exit 0
PASS: case1 --max 3 enforced
PASS: case2 --exclude M066 filters
PASS: case3 peek-files.sh self-conformance (no sh -c internal)
PASS: finding-G-wrapper-verifier.sh
```
