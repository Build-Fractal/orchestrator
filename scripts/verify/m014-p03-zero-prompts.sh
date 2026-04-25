#!/usr/bin/env bash
# scripts/verify/m014-p03-zero-prompts.sh
# Gate: M014/P03/T05 — SC-7 zero-prompts on the comments classify --yes path.
# Asserts that the M021 prompt-corpus regex finds zero approval-prompt-shaped
# strings on the primary comments.sh classify --yes pipeline (hermetic scratch
# root + four-class fixture from T04).
# Self-exempts diagnostic regex-pattern-line content in this file (precedent:
# m014-p04-zero-prompts.sh).
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMENTS="${PROJECT_ROOT}/scripts/comments/comments.sh"
CORPUS="${PROJECT_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
FIXTURE="${PROJECT_ROOT}/tests/fixtures/m014-p03/sample-inbox.jsonl"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$COMMENTS" ] || fail "comments.sh not executable at $COMMENTS"
[ -f "$CORPUS" ]   || fail "m021-prompt-corpus.txt missing at $CORPUS"
[ -f "$FIXTURE" ]  || fail "sample-inbox.jsonl fixture missing at $FIXTURE"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.orchestrator/comments"
printf '# DECISIONS\n\n| ID | Title | Owner | Body | Rationale | Outcome |\n| --- | --- | --- | --- | --- | --- |\n' \
  > "$SCRATCH/.orchestrator/DECISIONS.md"

ABSENT_ADAPTER="$SCRATCH/no-adapter.sh"

# Run classify --yes under the four-class fixture, capture stdout+stderr.
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
  bash "$COMMENTS" classify --yes \
    > "$SCRATCH/run.out" 2> "$SCRATCH/run.err"
rc=$?

if [ "$rc" -ne 0 ]; then
  fail "comments.sh classify --yes exited ${rc} (stdout=$(cat "$SCRATCH/run.out") stderr=$(cat "$SCRATCH/run.err"))"
fi

ALL_OUT="$(cat "$SCRATCH/run.out" "$SCRATCH/run.err")"

# M021 corpus is structured as ID/SCREENSHOT/INPUT/EXPECTED_OUTCOME blocks
# separated by '---'. We grep INPUT lines (the verbatim forbidden prompt
# substrings) against captured output.
INPUTS="$(awk '/^INPUT: /{sub(/^INPUT: */,""); print}' "$CORPUS")"

violations=0
while IFS= read -r line; do
  case "$line" in ""|'#'*) continue ;; esac
  if printf '%s\n' "$ALL_OUT" | grep -qF "$line"; then
    echo "VIOLATION: forbidden M021 prompt pattern detected: $line" >&2
    violations=$((violations + 1))
  fi
done <<EOF
$INPUTS
EOF

if [ "$violations" -gt 0 ]; then
  fail "comments classify --yes leaked ${violations} M021 prompt pattern(s)"
fi

# Belt-and-suspenders: scan output for common interactive-prompt shapes.
# These are diagnostic patterns; the classify --yes path must emit none.
# Self-exemption: this verifier's own regex-pattern lines live inside
# this file but are never read into ALL_OUT (which captures only
# subprocess output), so no exemption logic is needed at runtime.
PROMPT_RE='\(y/n\)|\[y/N\]|\[Y/n\]|Press any key|^Are you sure|^Continue\?|^Proceed\?|read -p '
if printf '%s' "$ALL_OUT" | grep -qE "$PROMPT_RE"; then
  MATCH="$(printf '%s' "$ALL_OUT" | grep -nE "$PROMPT_RE" | head -n 3)"
  fail "comments classify --yes emitted interactive-prompt-shaped output:
$MATCH"
fi

echo "PASS: $(basename "$0") — zero prompts on comments classify --yes (M021 corpus + shape scan)"
exit 0
