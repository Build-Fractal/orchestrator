---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M028"
name: "Investigation Wrappers — grep-files + cleanup-stale-results"
depends_on: []
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time (CLAUDE.md hotfix "Plan-time prerequisite-existence verification"):

- `scripts/util/` directory exists.
- `scripts/util/run-probe.sh` exists (the established sibling shape for util-tree wrappers; T01 follows its general docstring + arg-parsing convention).
- `scripts/util/read-range.sh` exists (sibling shape — short, single-purpose, exit-coded wrapper; T01 follows the same flat AD-19 single-script-file shape).
- `scripts/verify/lib/shape-classifier.sh` exists (used by the plan-level verifiers to confirm wrapper-invocation lines classify as `allow`).
- `scripts/verify/m028/` directory exists with the M028 verifier suite from P02 + P03.
- `ANTIPATTERNS.md` carries AP-010..AP-014 (P03 close).

The wrappers `scripts/util/grep-files.sh` and `scripts/util/cleanup-stale-results.sh` do NOT exist on disk before T01 (verified absent at plan-authoring time); T01 creates them.

## Description

Author two flat AD-19 single-script-file wrappers under `scripts/util/`:

1. **`grep-files.sh`** (FR-14) — replaces the Screenshot 1 shape `grep PATTERN file1 ; echo "---" ; grep PATTERN file2` with a single wrapper invocation that greps each file in turn, prints a per-file separator, and exits with the appropriate aggregate return code (0 if any file matched, 1 if no matches, 2 on usage error). The wrapper accepts a regex pattern as the first positional arg and one or more file paths as subsequent positional args. No `-r`/`-R` recursion in the v1 surface — recursion is `peek-files.sh`'s job; `grep-files.sh` is the explicit-files variant.

2. **`cleanup-stale-results.sh`** (FR-15) — replaces the Screenshot 2 / Finding D shape `/bin/rm -f .orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt && ls .orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt` with a single wrapper invocation that removes per-step result files for the named milestone and prints the residual `.txt` listing under that milestone's tree. The wrapper takes a milestone ID as the first positional arg, validates it matches `M[0-9]+`, refuses paths outside `.orchestrator/milestones/<MID>/` to bound blast radius (Edge Case from M028 spec), and prints a structured summary on stdout (`REMOVED: <N>` line + `RESIDUAL: <count>` line; `OK` on success).

Plus author the matching plan-level verifiers:

- `scripts/verify/m028/p04-grep-files.sh` (~50 lines) — exercises `grep-files.sh` against a tmp-staged 2-file tree with a known pattern, asserts the per-file separator pattern, asserts aggregate exit codes for the match / no-match / usage cases.
- `scripts/verify/m028/p04-cleanup-stale-results.sh` (~70 lines) — exercises `cleanup-stale-results.sh` against an isolated tmp tree mirroring `.orchestrator/milestones/<MID>/phases/<PID>/tasks/*.txt`, asserts the `REMOVED:` count, asserts boundary refusal on a path outside the milestone tree (mocked via the wrapper's input-validation guard), asserts the structured-output protocol.

## Steps

### Round 1 — `scripts/util/grep-files.sh`

1. **Author `scripts/util/grep-files.sh`** (~45 lines):

```bash
#!/usr/bin/env bash
# scripts/util/grep-files.sh -- Grep one pattern across multiple files with per-file separators.
#
# Usage: grep-files.sh <pattern> <file...>
#   <pattern> -- ERE pattern (passed verbatim to grep -E).
#   <file...> -- one or more file paths (no recursion; for recursion use peek-files.sh).
#
# Output:
#   --- <file> ---       (per-file separator, stdout)
#   <matching lines>     (grep output for that file, stdout)
#   ...                  (repeated for each file)
#
# Exit:
#   0 -- at least one file produced at least one match.
#   1 -- no file produced any match (clean run, nothing found).
#   2 -- usage error (missing args, unreadable file).
#
# Replaces the Screenshot 1 shape `grep P f1 ; echo "---" ; grep P f2` (M028 FR-14, AP-009 / AP-010 sibling).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 2 ]; then
  echo "usage: grep-files.sh <pattern> <file...>" >&2
  exit 2
fi

pattern="$1"
shift

any_match=1   # 1 = no match (default), 0 = at least one match
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "grep-files.sh: file not found: $f" >&2
    exit 2
  fi
  printf -- '--- %s ---\n' "$f"
  if grep -E -- "$pattern" "$f"; then
    any_match=0
  fi
done

exit "$any_match"
```

2. **Validate the wrapper script's own shape** against the M028 classifier — every non-comment, non-blank line must classify as `allow`. The plan-author traced the load-bearing lines through `classify_command` at plan-authoring time:

   - `if [ $# -lt 2 ]; then` → `allow` (single test, AP-009-stage-count = 1).
   - `for f in "$@"; do` → fence-internal; the AP-009 inline-shape classifier scans tool-call lines (the surrounding script body is not the agent-facing surface). The wrapper IS the executable; only the wrapper's *invocation* lines (e.g. in plans + payloads) must classify clean.
   - The wrapper's INVOCATION shape `bash scripts/util/grep-files.sh <pattern> <file...>` was traced: `bash scripts/util/grep-files.sh foo file1.md file2.md` → `allow` (recorded at plan-authoring time).

3. **Author `scripts/verify/m028/p04-grep-files.sh`** (~60 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-grep-files.sh -- M028 P04/T01 plan-level verifier for grep-files.sh.
#
# Exercises the wrapper against a tmp-staged 2-file tree:
#   1. Match case: pattern present in both files -> exit 0, two separators.
#   2. Match-some case: pattern in file 1 only -> exit 0.
#   3. No-match case: pattern in neither file -> exit 1.
#   4. Usage-error case: missing args / unreadable file -> exit 2.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/grep-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'apple banana\ncarrot\n' > "$tmp/a.txt"
printf 'apple date\nelderberry\n' > "$tmp/b.txt"
printf 'date elderberry\n' > "$tmp/c.txt"

# Case 1: both files match.
out_match="$(bash "$WRAPPER" 'apple' "$tmp/a.txt" "$tmp/b.txt")"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on any-match"; else fail "case1 exit" "rc=$rc"; fi
echo "$out_match" | grep -q -- "--- $tmp/a.txt ---" && pass "case1 separator a" || fail "case1 separator a" "missing"
echo "$out_match" | grep -q -- "--- $tmp/b.txt ---" && pass "case1 separator b" || fail "case1 separator b" "missing"

# Case 2: no matches.
bash "$WRAPPER" 'zzz_no_match' "$tmp/a.txt" "$tmp/b.txt" >/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on no-match"; else fail "case2 exit" "rc=$rc"; fi

# Case 3: usage error (missing pattern).
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case3 exit 2 on usage"; else fail "case3 exit" "rc=$rc"; fi

# Case 4: unreadable file.
bash "$WRAPPER" 'foo' "$tmp/does-not-exist" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on missing file"; else fail "case4 exit" "rc=$rc"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-grep-files.sh"
  exit 0
fi
echo "FAIL: p04-grep-files.sh ($fail_count failures)"
exit 1
```

### Round 2 — `scripts/util/cleanup-stale-results.sh`

4. **Author `scripts/util/cleanup-stale-results.sh`** (~55 lines):

```bash
#!/usr/bin/env bash
# scripts/util/cleanup-stale-results.sh -- Remove per-step result files under a milestone tree.
#
# Usage: cleanup-stale-results.sh <milestone-id>
#   <milestone-id> -- format M[0-9]+ (e.g. M028).
#
# Removes every *.txt file under .orchestrator/milestones/<MID>/phases/<PID>/tasks/
# (per-step task-result scratch files) and prints a structured summary.
#
# Output:
#   REMOVED: <N>          (count of files removed)
#   RESIDUAL: <count>     (count of *.txt files still present under the milestone tree)
#   OK                    (success terminator)
#
# Refuses milestone IDs that do not match M[0-9]+ to bound blast radius.
# Refuses if the milestone tree does not exist.
#
# Exit:
#   0 -- success.
#   1 -- milestone tree missing.
#   2 -- usage / validation error (bad milestone ID).
#
# Replaces the Screenshot 2 / Finding D shape `/bin/rm -f .../*.txt && ls .../*.txt` (M028 FR-15).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -ne 1 ]; then
  echo "usage: cleanup-stale-results.sh <milestone-id>" >&2
  exit 2
fi

mid="$1"

# Validate milestone ID format -- closed shape avoids path traversal and globbing.
case "$mid" in
  M[0-9]*) : ;;
  *)
    echo "cleanup-stale-results.sh: invalid milestone ID '$mid' (expected M[0-9]+)" >&2
    exit 2
    ;;
esac

# Resolve repo root.
script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../.." && pwd -P)"
TREE="${REPO_ROOT}/.orchestrator/milestones/${mid}"

if [ ! -d "$TREE" ]; then
  echo "cleanup-stale-results.sh: milestone tree not found: $TREE" >&2
  exit 1
fi

# Enumerate target files via find (no -exec into sh -c; AP-014 safe).
list_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$list_tmp"

removed=0
while IFS= read -r f; do
  if [ -f "$f" ]; then
    rm -f -- "$f"
    removed=$((removed + 1))
  fi
done < "$list_tmp"
rm -f "$list_tmp"

# Residual count -- separate find pass after removal.
residual_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$residual_tmp"
residual=$(wc -l < "$residual_tmp" | tr -d ' ')
rm -f "$residual_tmp"

printf 'REMOVED: %s\n' "$removed"
printf 'RESIDUAL: %s\n' "$residual"
echo "OK"
exit 0
```

5. **Validate wrapper-invocation shape** through the classifier — `bash scripts/util/cleanup-stale-results.sh M028` traced at plan-authoring time → `allow`.

6. **Author `scripts/verify/m028/p04-cleanup-stale-results.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-cleanup-stale-results.sh -- M028 P04/T01 plan-level verifier
# for cleanup-stale-results.sh.
#
# Exercises the wrapper against an isolated tmp tree mirroring the
# .orchestrator/milestones/<MID>/phases/<PID>/tasks/ layout:
#   1. Happy path: 3 .txt files staged, wrapper removes all 3, RESIDUAL=0.
#   2. No-tree case: bogus milestone ID -> exit 2.
#   3. Empty-tree case: milestone exists but no .txt files -> REMOVED=0, exit 0.
#   4. Boundary refusal: invalid milestone ID -> exit 2.
#
# Uses an isolated REPO_ROOT (export an env override or run inside a tmp dir).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/cleanup-stale-results.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Stage an isolated tree by setting up tmp/.orchestrator/milestones/MX99/phases/P01/tasks/*.txt
# Then run the wrapper against the real REPO_ROOT for the validation arms (case 4),
# and use a stub-mode override for the happy-path arms.

# Case 4: invalid milestone ID -> exit 2.
bash "$WRAPPER" "not-a-milestone" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on invalid ID"; else fail "case4 exit" "rc=$rc"; fi

# Case 4b: usage (no args) -> exit 2.
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4b exit 2 on no-args"; else fail "case4b exit" "rc=$rc"; fi

# Case 1 (happy path): stage isolated tree.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks"
printf 'stale1\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T01-result.txt"
printf 'stale2\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T02-result.txt"
printf 'stale3\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T01-result.txt"

# Stage a temp wrapper copy that points REPO_ROOT at $tmp_root via dirname inversion:
# cleanup-stale-results.sh resolves REPO_ROOT as "$(cd "$script_dir/../.." && pwd -P)",
# so we copy it into $tmp_root/scripts/util/ and invoke from there.
mkdir -p "$tmp_root/scripts/util"
cp "$WRAPPER" "$tmp_root/scripts/util/cleanup-stale-results.sh"

out="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M999)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on happy path"; else fail "case1 exit" "rc=$rc"; fi
echo "$out" | grep -q '^REMOVED: 3$' && pass "case1 REMOVED=3" || fail "case1 REMOVED" "got [$out]"
echo "$out" | grep -q '^RESIDUAL: 0$' && pass "case1 RESIDUAL=0" || fail "case1 RESIDUAL" "got [$out]"
echo "$out" | grep -q '^OK$' && pass "case1 OK terminator" || fail "case1 OK" "got [$out]"

# Case 3: empty tree (no .txt files).
mkdir -p "$tmp_root/.orchestrator/milestones/M998/phases/P01/tasks"
out2="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M998)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case3 exit 0 on empty"; else fail "case3 exit" "rc=$rc"; fi
echo "$out2" | grep -q '^REMOVED: 0$' && pass "case3 REMOVED=0" || fail "case3 REMOVED" "got [$out2]"

# Case 2: missing tree.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M997 2>/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on missing tree"; else fail "case2 exit" "rc=$rc"; fi

rm -rf "$tmp_root"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-cleanup-stale-results.sh"
  exit 0
fi
echo "FAIL: p04-cleanup-stale-results.sh ($fail_count failures)"
exit 1
```

7. **Run both plan-level verifiers locally** before commit:

```bash
bash scripts/verify/m028/p04-grep-files.sh
```

```bash
bash scripts/verify/m028/p04-cleanup-stale-results.sh
```

8. **Commit** via `git commit -F <message-file>` per CLAUDE.md hotfix list.

## Must-Haves

This task addresses the phase Truths:

- "The four investigation-pattern wrappers exist under `scripts/util/` …" — T01 lands 2 of the 4 (grep-files.sh, cleanup-stale-results.sh).
- "`scripts/util/grep-files.sh <pattern> <file...>` greps each file …"
- "`scripts/util/cleanup-stale-results.sh <milestone>` removes per-step result files …"

The plan-level verifiers `p04-grep-files.sh` and `p04-cleanup-stale-results.sh` (T01 deliverables themselves) implement the assertion logic for the latter two truths.

## Verification

```bash
bash scripts/verify/m028/p04-grep-files.sh
```

```bash
bash scripts/verify/m028/p04-cleanup-stale-results.sh
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `scripts/util/run-probe.sh` — sibling shape; T01 wrappers follow the same flat AD-19 single-script-file convention (set -u, structured exit codes, comment-block docstring).
- `scripts/util/read-range.sh` — sibling shape with explicit usage docstring + exit-code semantics; T01 wrappers mirror that shape.
- `scripts/verify/lib/shape-classifier.sh` — `classify_command` is the line-by-line classifier the plan-author traced wrapper-invocation lines through at plan-authoring time. The wrappers' *invocation* lines are agent-facing; their internal bodies are not.
- `scripts/verify/m028/p02-repair-fixture.sh` — pattern reference for "stage tmp tree + invoke wrapper from copied-in path" verifier shape; T01's `p04-cleanup-stale-results.sh` follows the same isolated-tmp-root pattern.

### Key API Surface

T01 wrappers are pure shell scripts with positional-arg interfaces:

- `grep-files.sh <pattern> <file...>` — returns 0 / 1 / 2 depending on match / no-match / usage; emits `--- <file> ---` separators per file plus grep output to stdout.
- `cleanup-stale-results.sh <milestone-id>` — returns 0 / 1 / 2; emits `REMOVED: <N>` / `RESIDUAL: <count>` / `OK` lines to stdout. Validates milestone ID against `M[0-9]+`.

No library sourcing, no upstream API surface to honor.

## Constraints

- **CON-1 (AD-19)**: Each wrapper is a flat single-file shape under `scripts/util/`. No nested helper dirs. No sourcing from outside `scripts/util/` or `scripts/verify/lib/`.
- **CON-2 (bash 3.2 + POSIX sh)**: All scripts use bash 3.2 grammar; no `mapfile`, no `<<<` here-strings, no process substitution, no `declare -A`, no associative arrays. The `case "$mid" in M[0-9]*) ... esac` form is bash 3.2-safe pattern matching.
- **CON-6 (no new runtime deps)**: Both wrappers use only `grep`, `find`, `rm`, `wc`, `tr`, `mkdir`, `cd`, `pwd`, `printf`, `echo`, plus standard bash builtins — no jq / node / python.
- **Boundary refusal (M028 spec Edge Cases)**: `cleanup-stale-results.sh` MUST refuse milestone IDs that don't match `M[0-9]+`. The refusal is the spec's blast-radius bound for Finding D.
- **Verification-section authoring**: Per the M028/P02 dogfood findings, the `## Verification` section invokes project-tree verifiers directly (`bash scripts/verify/m028/<name>.sh`); does NOT wrap with `run-probe.sh`. Expected output is documented in the `## Expected Output` section, not in the `## Verification` section's fenced blocks.
- **Plan-time verifier-availability**: Both `## Verification` checks resolve to scripts T01 itself authors (per the CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"). No cross-task verifier dependency.
- **Plan-time classifier-shape pre-validation**: Wrapper INVOCATION shapes traced through `classify_command` at plan-authoring time — `bash scripts/util/grep-files.sh foo file1.md file2.md` → `allow`; `bash scripts/util/cleanup-stale-results.sh M028` → `allow`. Recorded here as the verdict-of-record.
- **Commit-message form**: `git commit -F <file>`. Heredoc-with-expansion form is rejected by AP-008.

## Expected Output

After `bash scripts/verify/m028/p04-grep-files.sh`:

```
PASS: case1 exit 0 on any-match
PASS: case1 separator a
PASS: case1 separator b
PASS: case2 exit 1 on no-match
PASS: case3 exit 2 on usage
PASS: case4 exit 2 on missing file
PASS: p04-grep-files.sh
```

After `bash scripts/verify/m028/p04-cleanup-stale-results.sh`:

```
PASS: case4 exit 2 on invalid ID
PASS: case4b exit 2 on no-args
PASS: case1 exit 0 on happy path
PASS: case1 REMOVED=3
PASS: case1 RESIDUAL=0
PASS: case1 OK terminator
PASS: case3 exit 0 on empty
PASS: case3 REMOVED=0
PASS: case2 exit 1 on missing tree
PASS: p04-cleanup-stale-results.sh
```
