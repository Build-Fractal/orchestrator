---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M024"
name: "scripts/intake/qa-loop.sh — bounded loop with `enough` short-circuit + line-mode answers"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/intake-qa-questions.md` exists with five `### Q<N>` heading blocks and the schema fields (`schema_version: "1.0"`, `type: intake-qa-questions`). T01's verify (`m024-p05-qa-questions-template.sh`) passes.
- Bash 3.2+ available; `sed`, `grep`, `awk`, `tr`, `head`, `wc`, `mktemp` POSIX utilities available.

## Description

Author `scripts/intake/qa-loop.sh` — a pure-shell bounded Q&A loop that reads questions from T01's static template and answers from a `--answers-from <file>` argument. The script enforces FR-5's ≤5-turn cap, honors the `enough` short-circuit token, captures a transcript in the embedding-ready shape T03's emitter consumes, and emits two stdout key=value lines (`qa_short_circuited=<true|false>`, `qa_turns=<count>`) for the caller to parse.

**Line-mode only in P05.** The interactive (TTY-prompt) mode is deferred — line-mode (`--answers-from <file>`) is sufficient to earn SC-3 and FR-5 in tests, and a future task can add a TTY surface without breaking the line-mode contract. The decision to defer is recorded in this plan rather than as a Decision row because it is a scope reduction inside a phase, not an architectural commitment.

The script's invocation contract:

```
qa-loop.sh \
  --answers-from <file>    # one answer per line; blank line or `enough` short-circuits
  --transcript-out <path>  # absolute path to write the transcript to
  [--questions <path>]     # optional override; defaults to templates/intake-qa-questions.md
```

The transcript file format mirrors what T03's emitter embeds verbatim under `## Q&A`:

```
### Q1
<answer text for Q1>

### Q2
<answer text for Q2>
...
```

(Heading numbers Q1–Q<N> where N ≤ 5; one blank line between blocks.)

## Steps

1. **Author `scripts/intake/qa-loop.sh`** with the following structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/intake/qa-loop.sh
   # M024/P05/T02 — Bounded Q&A loop for empty-input intake (FR-5).
   #
   # Inputs:
   #   --answers-from <file>     One answer per line; blank line or `enough` short-circuits.
   #   --transcript-out <path>   Absolute path to write the transcript to.
   #   --questions <path>        Optional. Defaults to templates/intake-qa-questions.md.
   #
   # Output (stdout, two lines):
   #   qa_short_circuited=<true|false>
   #   qa_turns=<count>
   #
   # Exit 0 on success, 2 on usage error, 1 on internal error.

   set -u

   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   QUESTIONS_DEFAULT="$ROOT/templates/intake-qa-questions.md"
   MAX_TURNS=5

   ANSWERS_FROM=""
   TRANSCRIPT_OUT=""
   QUESTIONS="$QUESTIONS_DEFAULT"

   usage() {
     echo "usage: qa-loop.sh --answers-from <file> --transcript-out <path> [--questions <path>]" >&2
     exit 2
   }

   while [ $# -gt 0 ]; do
     case "$1" in
       --answers-from)   ANSWERS_FROM="$2"; shift 2 ;;
       --transcript-out) TRANSCRIPT_OUT="$2"; shift 2 ;;
       --questions)      QUESTIONS="$2"; shift 2 ;;
       -h|--help)        usage ;;
       *)                usage ;;
     esac
   done

   [ -n "$ANSWERS_FROM" ]   || usage
   [ -n "$TRANSCRIPT_OUT" ] || usage
   [ -f "$ANSWERS_FROM" ]   || { echo "qa-loop.sh: answers file not found: $ANSWERS_FROM" >&2; exit 1; }
   [ -f "$QUESTIONS" ]      || { echo "qa-loop.sh: questions file not found: $QUESTIONS" >&2; exit 1; }

   # Validate questions file shape — must contain ### Q1..Q5 headings.
   for n in 1 2 3 4 5; do
     grep -q "^### Q$n " "$QUESTIONS" \
       || { echo "qa-loop.sh: questions file missing ### Q$n heading" >&2; exit 1; }
   done

   # Drain the answers file into a temp working file with at most MAX_TURNS lines
   # (cap-enforcement is structural — extra lines beyond MAX_TURNS are ignored).
   work=$(mktemp)
   trap 'rm -f "$work"' EXIT
   head -n "$MAX_TURNS" "$ANSWERS_FROM" > "$work"

   # Build the transcript by iterating turn-by-turn.
   : > "$TRANSCRIPT_OUT"

   short_circuited="false"
   turns=0
   n=1

   while [ "$n" -le "$MAX_TURNS" ]; do
     # Read the n-th line. sed -n 'Np' is portable.
     line=$(sed -n "${n}p" "$work")

     # Empty line or end-of-file → no answer on this turn → stop.
     if [ -z "$line" ]; then
       break
     fi

     # Trim leading/trailing whitespace for comparison; keep raw value for transcript.
     trimmed=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

     # Short-circuit token (case-insensitive `enough`).
     lc=$(echo "$trimmed" | tr '[:upper:]' '[:lower:]')
     if [ "$lc" = "enough" ]; then
       short_circuited="true"
       break
     fi

     # Append this turn's heading + answer block.
     {
       echo "### Q$n"
       echo "$line"
       echo ""
     } >> "$TRANSCRIPT_OUT"

     turns=$((turns + 1))
     n=$((n + 1))
   done

   echo "qa_short_circuited=$short_circuited"
   echo "qa_turns=$turns"
   exit 0
   ```

2. **Make the script executable**: `chmod +x scripts/intake/qa-loop.sh`.

3. **Author `scripts/verify/m024-p05-qa-loop-script.sh`** — happy-path: 5 answers in, 5 `### Q<N>` blocks out, `qa_short_circuited=false`:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-qa-loop-script.sh
   # M024/P05/T02 verify — qa-loop.sh basic line-mode happy path.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   LOOP="$ROOT/scripts/intake/qa-loop.sh"

   [ -x "$LOOP" ] || { echo "FAIL: $LOOP not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   tx="$tmp/transcript.md"

   cat > "$ans" <<'EOF'
   add a last-seen timestamp to status command output
   single-feature
   code
   no
   Standard
   EOF

   out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
   echo "$out" | grep -q '^qa_short_circuited=false$' || { echo "FAIL: short_circuited not false (got: $out)"; exit 1; }
   echo "$out" | grep -q '^qa_turns=5$'                || { echo "FAIL: qa_turns not 5 (got: $out)";        exit 1; }

   for n in 1 2 3 4 5; do
     grep -q "^### Q$n$" "$tx" || { echo "FAIL: transcript missing ### Q$n"; exit 1; }
   done

   echo "PASS: qa-loop.sh — five answers → five ### Q<N> blocks; qa_short_circuited=false; qa_turns=5"
   exit 0
   ```

4. **Author `scripts/verify/m024-p05-qa-loop-cap.sh`** — cap-enforcement: 7 answers in, 5 `### Q<N>` blocks out, `qa_short_circuited=false`:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-qa-loop-cap.sh
   # M024/P05/T02 verify — qa-loop.sh enforces FR-5 cap (truncate to 5 turns).

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   LOOP="$ROOT/scripts/intake/qa-loop.sh"

   [ -x "$LOOP" ] || { echo "FAIL: $LOOP not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   tx="$tmp/transcript.md"

   cat > "$ans" <<'EOF'
   first answer
   second answer
   third answer
   fourth answer
   fifth answer
   sixth answer
   seventh answer
   EOF

   out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
   echo "$out" | grep -q '^qa_short_circuited=false$' || { echo "FAIL: short_circuited not false (got: $out)"; exit 1; }
   echo "$out" | grep -q '^qa_turns=5$'                || { echo "FAIL: qa_turns not 5 (got: $out)";        exit 1; }

   count=$(grep -c '^### Q' "$tx")
   [ "$count" = "5" ] || { echo "FAIL: transcript has $count ### Q blocks (expected 5)"; exit 1; }

   grep -q 'sixth answer'   "$tx" && { echo "FAIL: 6th answer leaked into transcript"; exit 1; }
   grep -q 'seventh answer' "$tx" && { echo "FAIL: 7th answer leaked into transcript"; exit 1; }

   echo "PASS: qa-loop.sh — 7-line answers truncated to 5 turns; qa_short_circuited=false"
   exit 0
   ```

5. **Author `scripts/verify/m024-p05-qa-loop-shortcircuit.sh`** — `enough` after turn 2 produces `qa_short_circuited=true` + 2-block transcript:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-qa-loop-shortcircuit.sh
   # M024/P05/T02 verify — `enough` token short-circuits the loop.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   LOOP="$ROOT/scripts/intake/qa-loop.sh"

   [ -x "$LOOP" ] || { echo "FAIL: $LOOP not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   tx="$tmp/transcript.md"

   cat > "$ans" <<'EOF'
   first answer
   second answer
   enough
   never seen
   EOF

   out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
   echo "$out" | grep -q '^qa_short_circuited=true$' || { echo "FAIL: short_circuited not true (got: $out)"; exit 1; }
   echo "$out" | grep -q '^qa_turns=2$'              || { echo "FAIL: qa_turns not 2 (got: $out)";        exit 1; }

   grep -q '^### Q1$' "$tx" || { echo "FAIL: transcript missing ### Q1"; exit 1; }
   grep -q '^### Q2$' "$tx" || { echo "FAIL: transcript missing ### Q2"; exit 1; }
   grep -q '^### Q3$' "$tx" && { echo "FAIL: transcript should not contain ### Q3 after enough"; exit 1; }
   grep -q 'never seen' "$tx" && { echo "FAIL: post-enough answer leaked"; exit 1; }

   # Case-insensitivity probe: ENOUGH should also trigger the short-circuit.
   ans2="$tmp/answers2.txt"
   tx2="$tmp/transcript2.md"
   cat > "$ans2" <<'EOF'
   answer one
   ENOUGH
   EOF
   out2=$(bash "$LOOP" --answers-from "$ans2" --transcript-out "$tx2")
   echo "$out2" | grep -q '^qa_short_circuited=true$' || { echo "FAIL: ENOUGH (uppercase) did not short-circuit"; exit 1; }

   echo "PASS: qa-loop.sh — `enough` (case-insensitive) short-circuits at turn 2; qa_short_circuited=true"
   exit 0
   ```

6. **Make the three verifies executable**: `chmod +x scripts/verify/m024-p05-qa-loop-script.sh`, `chmod +x scripts/verify/m024-p05-qa-loop-cap.sh`, `chmod +x scripts/verify/m024-p05-qa-loop-shortcircuit.sh` (three single-script-file commands; do not chain).

## Must-Haves

- `scripts/intake/qa-loop.sh` exists, is executable, and contains the literal token `qa_short_circuited` (used both as the stdout key and in the inline comment block).
- `qa-loop.sh` accepts `--answers-from <file>`, `--transcript-out <path>`, and optional `--questions <path>`; rejects all other invocations with a usage error and exit 2.
- `qa-loop.sh` enforces a 5-turn cap: an answers file with more than 5 lines produces a transcript with exactly 5 `### Q<N>` blocks and `qa_short_circuited=false`.
- `qa-loop.sh` honors the `enough` token (case-insensitive, whitespace-trimmed): the loop terminates after the prior turn; transcript contains only the gathered answers; `qa_short_circuited=true` is emitted.
- `qa-loop.sh` validates the questions file contains `### Q1`–`### Q5` headings before processing; missing headings exit 1 with a stderr message.
- The transcript file format is exactly: `### Q<N>` heading line; one prose answer line; one blank line — repeated per turn.
- All three per-task verifies (`m024-p05-qa-loop-script.sh`, `m024-p05-qa-loop-cap.sh`, `m024-p05-qa-loop-shortcircuit.sh`) exist, are executable, and exit 0 with `PASS: ...` lines.
- AD-19 single-script-file shape: every external command in the verifies is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T02 writes only to `scripts/intake/qa-loop.sh` and the three new verifies under `scripts/verify/`. The script itself writes only to its `--transcript-out` argument and to the trap-cleaned tempfile.

## Verification

```
bash scripts/verify/m024-p05-qa-loop-script.sh
bash scripts/verify/m024-p05-qa-loop-cap.sh
bash scripts/verify/m024-p05-qa-loop-shortcircuit.sh
```

Each exits 0 with a `PASS:` line.

## Inputs

### From Previous Tasks

- `templates/intake-qa-questions.md` (from T01)
  - Key API: a static markdown file with YAML frontmatter (`schema_version: "1.0"`, `type: intake-qa-questions`) and five `### Q<N>` headings (Q1–Q5) in pinned order. T02's loop validates the five headings exist before processing answers.
  - Key types: pure markdown — no placeholder substitution, no interpolation.

### From Disk (Pre-existing)

- `scripts/intake/` directory — pre-existing intake-script home (P01 + P02 + P03 + P04 already populated this directory).
- `scripts/verify/` directory — pre-existing verify-script home for M024 phase verifies.
- `mktemp`, `sed -n 'Np'`, `grep -q`, `head -n`, `tr [:upper:] [:lower:]`, `wc -l`, `cat`, `chmod` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No `[[ ]]` in the script body (the verify bodies may use `[ ]` only). No process substitution `<(...)`. No `$(... | ...)` containing pipes. No heredoc-with-pipes.
- Writes only to `scripts/intake/qa-loop.sh`, the three new verifies under `scripts/verify/`, the script's `--transcript-out` argument, and trap-cleaned `mktemp` outputs (SB-3).
- AD-19 single-script-file shape: every external invocation in the verifies is a top-level command; no inline compound bash, no plain subshells.
- The `enough` token match is case-insensitive AND whitespace-trimmed — both invariants asserted by the short-circuit verify.
- Cap is **structural** — driven by `head -n 5` on the answers file before the loop runs, not by a turn-count check inside the loop. This is the simplest shape that earns the cap invariant; future TTY-mode work can wire an in-loop counter without changing the line-mode contract.

## Expected Output

`scripts/intake/qa-loop.sh` exists and is executable; the three per-task verifies exist and are executable; all three exit 0 with `PASS:` lines.
