---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M028"
name: "Investigation Wrappers — node-eval + peek-files"
depends_on: []
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time (CLAUDE.md hotfix "Plan-time prerequisite-existence verification"):

- `scripts/util/` directory exists.
- `scripts/util/run-probe.sh`, `scripts/util/read-range.sh` exist (sibling shapes).
- `scripts/verify/lib/shape-classifier.sh` exists.
- `scripts/verify/m028/` directory exists.
- `ANTIPATTERNS.md` carries AP-012 (multiline-quoted-script) and AP-014 (xargs-sh-c-compound-body) post-P03.

The wrappers `scripts/util/node-eval.sh` and `scripts/util/peek-files.sh` do NOT exist on disk before T02 (verified absent at plan-authoring time); T02 creates them.

T02 is parallelizable with T01 — neither task reads the other's outputs. Both consume only pre-existing siblings.

## Description

Author two flat AD-19 single-script-file wrappers under `scripts/util/`:

1. **`node-eval.sh`** (FR-16) — replaces the AP-012 multiline `node -e "<body>"` shape with a wrapper that takes a script PATH (not an inline body) and runs `node <script-path> [args...]`. The wrapper does NOT accept `-e`. If the operator's intent is a one-liner, they author a `.js` file under `tmp/` (or a stable allow-listed location) and pass its path. The wrapper exists to give agents a canonical alternative when they would otherwise reach for `node -e "<multiline body>"`.

2. **`peek-files.sh`** (FR-17) — replaces the Finding G `find … | head … | xargs -I{} sh -c '…echo;head…'` (AP-014) shape with a wrapper that enumerates files matching a glob pattern, prints a per-file separator, and head-N's each match. Internal implementation uses `find` + `while-read` (no `-exec sh -c`, no `xargs sh -c`). The wrapper accepts an `--lines N` flag (default 20), an optional `--exclude PATH` flag, and an optional `--max N` cap on the number of files to peek (default 20).

Plus author the matching plan-level verifiers:

- `scripts/verify/m028/p04-node-eval.sh` (~50 lines) — exercises `node-eval.sh` against a tmp-staged `.js` file emitting a known stdout marker; asserts the wrapper rejects a multi-line `-e`-style body if accidentally invoked with `-e` (defensive); asserts usage-error exit codes.
- `scripts/verify/m028/p04-peek-files.sh` (~70 lines) — exercises `peek-files.sh` against a tmp-staged file tree; asserts per-file separators; asserts `--lines` boundary; asserts `--exclude` filter; asserts the wrapper produces deterministic output without ever invoking `sh -c`.

## Steps

### Round 1 — `scripts/util/node-eval.sh`

1. **Author `scripts/util/node-eval.sh`** (~45 lines):

```bash
#!/usr/bin/env bash
# scripts/util/node-eval.sh -- Run a Node.js script file (not an inline -e body).
#
# Usage: node-eval.sh <script-path> [args...]
#   <script-path> -- path to a .js / .mjs / .cjs file (positional, REQUIRED).
#   [args...]     -- forwarded as positional argv to node.
#
# Output:
#   Whatever the script writes to stdout / stderr.
#
# Exit:
#   0 -- node returned 0.
#   N -- node's exit code (forwarded).
#   2 -- usage / validation error (missing path, file unreadable, -e attempted).
#   127 -- node not on PATH.
#
# Replaces the AP-012 multi-line `node -e "<body>"` shape (M028 FR-16).
# Refuses any `-e` argument to prevent rebuilding the AP-012 shape.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 1 ]; then
  echo "usage: node-eval.sh <script-path> [args...]" >&2
  exit 2
fi

# Defensive guard: reject -e / --eval to keep callers from rebuilding the AP-012 shape.
case "$1" in
  -e|--eval|-p|--print)
    echo "node-eval.sh: -e/-p/--eval/--print are not supported (use a script file)" >&2
    exit 2
    ;;
esac

script_path="$1"
shift

if [ ! -f "$script_path" ]; then
  echo "node-eval.sh: script not found: $script_path" >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node-eval.sh: node not on PATH" >&2
  exit 127
fi

exec node "$script_path" "$@"
```

2. **Author `scripts/verify/m028/p04-node-eval.sh`** (~55 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-node-eval.sh -- M028 P04/T02 plan-level verifier for node-eval.sh.
#
# Cases:
#   1. Happy path: stage tmp .js file printing 'NODE_EVAL_OK', run wrapper, assert stdout.
#   2. Usage (no args) -> exit 2.
#   3. Refuse -e -> exit 2.
#   4. Missing file -> exit 2.
#   5. Forwarded args: stage tmp .js that prints process.argv.slice(2), assert pass-through.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/node-eval.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: p04-node-eval.sh (node not on PATH)"
  exit 0
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case 1: happy path.
printf 'console.log("NODE_EVAL_OK");\n' > "$tmp/ok.js"
out="$(bash "$WRAPPER" "$tmp/ok.js")"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "NODE_EVAL_OK" ]; then
  pass "case1 happy path"
else
  fail "case1 happy path" "rc=$rc out=[$out]"
fi

# Case 2: usage.
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case2 exit 2 on usage"; else fail "case2 exit" "rc=$rc"; fi

# Case 3: refuse -e.
bash "$WRAPPER" -e 'console.log(1)' 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case3 exit 2 on -e"; else fail "case3 exit" "rc=$rc"; fi

# Case 4: missing file.
bash "$WRAPPER" "$tmp/does-not-exist.js" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on missing"; else fail "case4 exit" "rc=$rc"; fi

# Case 5: forwarded args.
printf 'console.log(process.argv.slice(2).join(","));\n' > "$tmp/argv.js"
out5="$(bash "$WRAPPER" "$tmp/argv.js" alpha beta gamma)"
if [ "$out5" = "alpha,beta,gamma" ]; then pass "case5 forwarded args"; else fail "case5 forwarded args" "got [$out5]"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-node-eval.sh"
  exit 0
fi
echo "FAIL: p04-node-eval.sh ($fail_count failures)"
exit 1
```

### Round 2 — `scripts/util/peek-files.sh`

3. **Author `scripts/util/peek-files.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/util/peek-files.sh -- Enumerate files matching a glob and head-N each match.
#
# Usage: peek-files.sh <glob-pattern> [--lines N] [--exclude PATH] [--max N]
#   <glob-pattern> -- path glob suitable for find -name (e.g. "T*-SUMMARY.md").
#   --lines N      -- lines per file (default 20).
#   --exclude PATH -- exclude any path containing this substring (find -not -path "*PATH*").
#   --max N        -- cap on the number of files to peek (default 20).
#
# Output:
#   --- <file> ---       (per-file separator, stdout)
#   <first N lines>      (stdout)
#   ...
#
# Exit:
#   0 -- at least one file peeked.
#   1 -- no files matched.
#   2 -- usage / validation error.
#
# Replaces the Finding G shape `find ... | head ... | xargs -I{} sh -c 'echo "---"; head -N "{}"'`
# (M028 FR-17 / AP-014). Internal impl uses find + while-read; never invokes sh -c.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 1 ]; then
  echo "usage: peek-files.sh <glob-pattern> [--lines N] [--exclude PATH] [--max N]" >&2
  exit 2
fi

pattern="$1"
shift

lines=20
exclude=""
max=20

while [ $# -gt 0 ]; do
  case "$1" in
    --lines)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --lines requires a value" >&2; exit 2; fi
      lines="$2"; shift 2
      ;;
    --exclude)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --exclude requires a value" >&2; exit 2; fi
      exclude="$2"; shift 2
      ;;
    --max)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --max requires a value" >&2; exit 2; fi
      max="$2"; shift 2
      ;;
    *)
      echo "peek-files.sh: unknown option $1" >&2
      exit 2
      ;;
  esac
done

# Validate integers.
case "$lines" in ''|*[!0-9]*) echo "peek-files.sh: --lines must be a positive integer" >&2; exit 2 ;; esac
case "$max"   in ''|*[!0-9]*) echo "peek-files.sh: --max must be a positive integer" >&2; exit 2 ;; esac

# Enumerate matches via find. Search root is CWD.
list_tmp="$(mktemp)"
trap 'rm -f "$list_tmp"' EXIT

if [ -n "$exclude" ]; then
  find . -type f -name "$pattern" -not -path "*${exclude}*" -print > "$list_tmp"
else
  find . -type f -name "$pattern" -print > "$list_tmp"
fi

count=0
while IFS= read -r f; do
  if [ "$count" -ge "$max" ]; then break; fi
  printf -- '--- %s ---\n' "$f"
  head -n "$lines" -- "$f"
  count=$((count + 1))
done < "$list_tmp"

if [ "$count" -eq 0 ]; then
  exit 1
fi
exit 0
```

4. **Author `scripts/verify/m028/p04-peek-files.sh`** (~75 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-peek-files.sh -- M028 P04/T02 plan-level verifier for peek-files.sh.
#
# Cases:
#   1. Happy path: stage 3 matching files in tmp tree, run wrapper, assert 3 separators + content.
#   2. --lines N: assert head-N respected.
#   3. --exclude: assert excluded path absent from output.
#   4. --max N: assert cap enforced.
#   5. No matches -> exit 1.
#   6. Usage error: bad --lines value -> exit 2.
#
# Verifier runs from a tmp dir to isolate find . from the repo tree.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/peek-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stage tree.
mkdir -p "$tmp/a/sub" "$tmp/b" "$tmp/excluded"
printf 'line1\nline2\nline3\nline4\n' > "$tmp/a/T01-SUMMARY.md"
printf 'lineA\nlineB\nlineC\n' > "$tmp/a/sub/T02-SUMMARY.md"
printf 'lineX\nlineY\n' > "$tmp/b/T03-SUMMARY.md"
printf 'should not appear\n' > "$tmp/excluded/T04-SUMMARY.md"

# Use a subshell-style approach: cd via a wrapper that runs the gate inside $tmp.
# (No process substitution; plain cd is safe.)
prev_dir="$(pwd -P)"
cd "$tmp"

# Case 1: happy path -- 4 matches, default --lines 20 (all content shown).
out="$(bash "$WRAPPER" 'T*-SUMMARY.md')"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0"; else fail "case1 exit" "rc=$rc"; fi
sep_count="$(printf '%s\n' "$out" | grep -c '^--- ')"
if [ "$sep_count" -eq 4 ]; then pass "case1 4 separators"; else fail "case1 separators" "got $sep_count"; fi

# Case 2: --lines 2.
out2="$(bash "$WRAPPER" 'T01-SUMMARY.md' --lines 2)"
content_lines="$(printf '%s\n' "$out2" | grep -cE '^line[1-4]$')"
if [ "$content_lines" -eq 2 ]; then pass "case2 --lines 2 respected"; else fail "case2 --lines" "got $content_lines"; fi

# Case 3: --exclude.
out3="$(bash "$WRAPPER" 'T*-SUMMARY.md' --exclude excluded)"
if printf '%s\n' "$out3" | grep -q 'should not appear'; then
  fail "case3 --exclude" "excluded content present"
else
  pass "case3 --exclude filters"
fi

# Case 4: --max 1.
out4="$(bash "$WRAPPER" 'T*-SUMMARY.md' --max 1)"
sep4="$(printf '%s\n' "$out4" | grep -c '^--- ')"
if [ "$sep4" -eq 1 ]; then pass "case4 --max 1 enforced"; else fail "case4 --max" "got $sep4"; fi

# Case 5: no matches.
bash "$WRAPPER" 'NO_SUCH_FILE_*.md' >/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case5 exit 1 on no-match"; else fail "case5 exit" "rc=$rc"; fi

# Case 6: bad --lines.
bash "$WRAPPER" 'T*-SUMMARY.md' --lines abc 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case6 exit 2 on bad --lines"; else fail "case6 exit" "rc=$rc"; fi

cd "$prev_dir"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-peek-files.sh"
  exit 0
fi
echo "FAIL: p04-peek-files.sh ($fail_count failures)"
exit 1
```

5. **Validate wrapper-invocation shapes** through the classifier — traced at plan-authoring time:

   - `bash scripts/util/node-eval.sh tmp/foo.js` → `allow`.
   - `bash scripts/util/peek-files.sh "T*-SUMMARY.md" --lines 20` → `allow`.

6. **Run both plan-level verifiers locally** before commit:

```bash
bash scripts/verify/m028/p04-node-eval.sh
```

```bash
bash scripts/verify/m028/p04-peek-files.sh
```

7. **Commit** via `git commit -F <message-file>`.

## Must-Haves

This task addresses the phase Truths:

- "The four investigation-pattern wrappers exist under `scripts/util/` …" — T02 lands the remaining 2 of 4 (node-eval.sh, peek-files.sh).
- "`scripts/util/node-eval.sh <script-path> [args...]` runs `node` against a script file …"
- "`scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` enumerates files matching the glob …"

The plan-level verifiers `p04-node-eval.sh` and `p04-peek-files.sh` (T02 deliverables themselves) implement the assertion logic.

## Verification

```bash
bash scripts/verify/m028/p04-node-eval.sh
```

```bash
bash scripts/verify/m028/p04-peek-files.sh
```

## Inputs

### From Previous Tasks

None — T02 is parallelizable with T01 and reads no T01 outputs.

### From Disk (Pre-existing)

- `scripts/util/run-probe.sh`, `scripts/util/read-range.sh` — sibling shapes for the wrapper convention.
- `scripts/verify/lib/shape-classifier.sh` — line-by-line classifier used at plan-authoring time to verify wrapper-invocation shapes.
- `ANTIPATTERNS.md` — AP-012 (multiline-quoted-script) is the antipattern node-eval.sh remediates; AP-014 (xargs-sh-c-compound-body) is the antipattern peek-files.sh remediates. Both entries cite the wrapper paths in their Remedy section.

### Key API Surface

T02 wrappers are pure shell scripts with positional + flag interfaces:

- `node-eval.sh <script-path> [args...]` — exec's `node <script-path> [args...]`. Refuses `-e/-p/--eval/--print`. Returns node's exit code; 2 on usage error; 127 if node missing.
- `peek-files.sh <glob-pattern> [--lines N] [--exclude PATH] [--max N]` — enumerates via `find . -name "$pattern"` (no -exec, no xargs); per-file `--- <path> ---` separator + `head -n N` content. Returns 0 on at-least-one-match, 1 on no-match, 2 on usage error.

## Constraints

- **CON-1 (AD-19)**: Each wrapper is a flat single-file shape. No nested helpers. No sourcing.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<`, no process substitution, no `declare -A`. The `case "$lines" in ''|*[!0-9]*) ... esac` integer-validation form is bash 3.2-safe.
- **CON-5 (AP-014 self-conformance)**: `peek-files.sh` MUST NOT call `xargs -I{} sh -c '...'` or `find -exec sh -c '...'` internally. The wrapper exists precisely to retire that shape; reproducing it inside the wrapper would defeat the point. Implementation uses `find` + `while-read` only.
- **CON-6 (no new runtime deps)**: peek-files.sh uses only `find`, `head`, `mktemp`, `mkdir`, `rm`, `printf`, `grep`, `cd`, `pwd`. node-eval.sh uses `node` (only when invoked with a valid script) plus `command -v` for the path probe.
- **AP-012 self-conformance**: node-eval.sh MUST refuse `-e/-p` arguments. The defensive guard is a load-bearing part of the wrapper's contract — without it, callers would rebuild the AP-012 shape inside the wrapper invocation.
- **Verification-section authoring**: Per the M028/P02 dogfood findings, the `## Verification` section invokes project-tree verifiers directly. No `run-probe.sh` wrapping. Expected output goes in `## Expected Output`.
- **Plan-time verifier-availability**: Both `## Verification` checks resolve to scripts T02 itself authors.
- **Plan-time classifier-shape pre-validation**: Wrapper INVOCATION shapes traced through `classify_command` at plan-authoring time (recorded above); both produced `allow`.
- **Commit-message form**: `git commit -F <file>`.

## Expected Output

After `bash scripts/verify/m028/p04-node-eval.sh`:

```
PASS: case1 happy path
PASS: case2 exit 2 on usage
PASS: case3 exit 2 on -e
PASS: case4 exit 2 on missing
PASS: case5 forwarded args
PASS: p04-node-eval.sh
```

(If `node` is not on PATH, the verifier prints `SKIP: p04-node-eval.sh (node not on PATH)` and exits 0 — same skip-discipline as conditional CI gates elsewhere in the suite.)

After `bash scripts/verify/m028/p04-peek-files.sh`:

```
PASS: case1 exit 0
PASS: case1 4 separators
PASS: case2 --lines 2 respected
PASS: case3 --exclude filters
PASS: case4 --max 1 enforced
PASS: case5 exit 1 on no-match
PASS: case6 exit 2 on bad --lines
PASS: p04-peek-files.sh
```
