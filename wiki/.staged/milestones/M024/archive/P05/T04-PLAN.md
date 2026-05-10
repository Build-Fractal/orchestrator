---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M024"
name: "Phase tests + suite + commands/evaluate.md row update"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `templates/intake-qa-questions.md` ships the 5-question schema; T01 verify passes.
- T02 complete: `scripts/intake/qa-loop.sh` is executable; the three T02 verifies (`m024-p05-qa-loop-script.sh`, `m024-p05-qa-loop-cap.sh`, `m024-p05-qa-loop-shortcircuit.sh`) pass.
- T03 complete: `scripts/intake/proposal-emit.sh` accepts `--qa-answers-from` and emits empty_qa proposals; T03 verify (`m024-p05-proposal-emit-empty-qa.sh`) passes.
- P03 + P04 phase suites still pass on HEAD (T03 did not break upstream invariants).

## Description

Author the two phase-level tests, the three remaining per-claim verifies, the write-confinement check, the commands/evaluate.md row update, and the suite runner. The two phase tests are the load-bearing acceptance witnesses for SC-3 (proposal contains `input_shape: empty_qa` and embeds the transcript) and the spec edge case "Q&A short-circuit on question 1" (`low_confidence: true` blocks the P04 fast-path).

## Steps

1. **Author `tests/test-empty-qa-loop.sh`** — phase-level happy-path: 5 answers in, full Q&A proposal out:

   ```bash
   #!/usr/bin/env bash
   # tests/test-empty-qa-loop.sh
   # M024/P05 phase test — empty + 5 answers produces empty_qa proposal with full transcript.

   set -u
   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   cat > "$ans" <<'EOF'
   add a last-seen timestamp to status command output and probably cache it
   single-feature
   code
   no
   Standard
   EOF

   emit_out=$(bash "$EMIT" --qa-answers-from "$ans" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

   [ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

   grep -q '^input_shape: "empty_qa"$'   "$proposal" || { echo "FAIL: input_shape not empty_qa"; exit 1; }
   grep -q '^qa_short_circuited: false$' "$proposal" || { echo "FAIL: qa_short_circuited not false"; exit 1; }
   grep -q '^low_confidence: false$'     "$proposal" || { echo "FAIL: low_confidence should be false on full Q&A"; exit 1; }
   grep -q '^auto_proceeded: false$'     "$proposal" || { echo "FAIL: auto_proceeded should be false (empty_qa is not a fast-path shape)"; exit 1; }
   grep -q '^## Q&A$'                    "$proposal" || { echo "FAIL: proposal missing ## Q&A section"; exit 1; }

   count=$(grep -c '^### Q' "$proposal")
   [ "$count" = "5" ] || { echo "FAIL: ## Q&A section has $count blocks (expected 5)"; exit 1; }

   echo "PASS: test-empty-qa-loop — empty + 5 answers → input_shape: empty_qa, 5 ## Q&A blocks, low_confidence false"
   exit 0
   ```

2. **Author `tests/test-qa-short-circuit.sh`** — phase-level short-circuit: `enough` after turn 2 produces `qa_short_circuited: true` + `low_confidence: true` + auto_proceeded blocked:

   ```bash
   #!/usr/bin/env bash
   # tests/test-qa-short-circuit.sh
   # M024/P05 phase test — `enough` short-circuit forces low_confidence: true,
   # which the P04 fast-path guard refuses to auto-proceed past.

   set -u
   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   cat > "$ans" <<'EOF'
   fix a typo in commands/status.md
   single-task
   enough
   never seen
   never seen
   EOF

   emit_out=$(bash "$EMIT" --qa-answers-from "$ans" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

   [ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

   grep -q '^input_shape: "empty_qa"$'  "$proposal" || { echo "FAIL: input_shape not empty_qa"; exit 1; }
   grep -q '^qa_short_circuited: true$' "$proposal" || { echo "FAIL: qa_short_circuited not true"; exit 1; }
   grep -q '^low_confidence: true$'     "$proposal" || { echo "FAIL: low_confidence should be true on short-circuit"; exit 1; }
   grep -q '^auto_proceeded: false$'    "$proposal" || { echo "FAIL: auto_proceeded must be false when low_confidence is true (P04 guard)"; exit 1; }

   # Transcript should contain Q1+Q2 only.
   grep -q '^### Q1$' "$proposal" || { echo "FAIL: missing ### Q1"; exit 1; }
   grep -q '^### Q2$' "$proposal" || { echo "FAIL: missing ### Q2"; exit 1; }
   grep -q '^### Q3$' "$proposal" && { echo "FAIL: ### Q3 leaked past short-circuit"; exit 1; }
   grep -q 'never seen' "$proposal" && { echo "FAIL: post-enough answer leaked into proposal"; exit 1; }

   echo "PASS: test-qa-short-circuit — enough at turn 3 → qa_short_circuited true, low_confidence true, auto_proceeded false"
   exit 0
   ```

3. **Author `scripts/verify/m024-p05-empty-qa-full.sh`** — wraps the phase test as a verify so the suite picks it up:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-empty-qa-full.sh
   # Suite-runnable wrapper for tests/test-empty-qa-loop.sh.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   T="$ROOT/tests/test-empty-qa-loop.sh"
   [ -x "$T" ] || { echo "FAIL: $T not executable"; exit 1; }
   bash "$T"
   ```

4. **Author `scripts/verify/m024-p05-empty-qa-shortcircuit.sh`** — wraps the short-circuit phase test:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-empty-qa-shortcircuit.sh
   # Suite-runnable wrapper for tests/test-qa-short-circuit.sh.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   T="$ROOT/tests/test-qa-short-circuit.sh"
   [ -x "$T" ] || { echo "FAIL: $T not executable"; exit 1; }
   bash "$T"
   ```

5. **Author `scripts/verify/m024-p05-write-confinement.sh`** — asserts every P05-introduced script writes only to `.orchestrator/intake/<id>/`, `templates/`, `scripts/`, `tests/`, or trap-cleaned `/tmp` scratch (SB-3). The check greps the new scripts for any `>` redirects or `cat >` invocations and asserts the targets fall in the allow-list:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-write-confinement.sh
   # M024/P05 verify — write-confinement (SB-3) — every P05-introduced script
   # writes only to .orchestrator/intake/<id>/, templates/, scripts/, tests/,
   # or trap-cleaned /tmp scratch (mktemp).

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   # Files introduced by P05 that perform writes.
   QA_LOOP="$ROOT/scripts/intake/qa-loop.sh"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$QA_LOOP" ] || { echo "FAIL: qa-loop.sh not executable"; exit 1; }
   [ -x "$EMIT" ]    || { echo "FAIL: proposal-emit.sh not executable"; exit 1; }

   # qa-loop.sh writes only to TRANSCRIPT_OUT (caller-supplied) and trap-cleaned mktemp.
   # Forbidden: any unguarded write outside those two surfaces.
   if grep -nE '>[[:space:]]*/[a-z]' "$QA_LOOP" | grep -vE 'mktemp|TRANSCRIPT_OUT|/tmp/' | grep -v '^#' | grep -q .; then
     echo "FAIL: qa-loop.sh contains unguarded absolute-path writes"
     exit 1
   fi

   # proposal-emit.sh write surfaces: $out_path under intake-root, $tmp_render (mktemp),
   # $qa_tx_tmp (mktemp), and the trap-cleaned scratch. The structural check is that
   # the script does not introduce new absolute-path writes outside those three.
   if grep -nE '>[[:space:]]*/[a-z]' "$EMIT" | grep -vE 'mktemp|out_path|tmp_render|qa_tx_tmp|/tmp/' | grep -v '^#' | grep -q .; then
     echo "FAIL: proposal-emit.sh contains unguarded absolute-path writes"
     exit 1
   fi

   echo "PASS: P05 write-confinement — qa-loop.sh + proposal-emit.sh respect SB-3"
   exit 0
   ```

6. **Author `scripts/verify/m024-p05-evaluate-md.sh`** — asserts the `commands/evaluate.md` empty-shape row is updated:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-evaluate-md.sh
   # M024/P05 verify — commands/evaluate.md empty-shape row mentions qa-loop and empty_qa.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   F="$ROOT/commands/evaluate.md"

   [ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

   grep -q 'empty_qa'  "$F" || { echo "FAIL: commands/evaluate.md missing 'empty_qa'"; exit 1; }
   grep -q 'qa-loop'   "$F" || { echo "FAIL: commands/evaluate.md missing reference to qa-loop"; exit 1; }
   # Old placeholder text must be gone.
   grep -q 'P05+ wires Q&A' "$F" && { echo "FAIL: stale 'P05+ wires Q&A' placeholder still present"; exit 1; }

   echo "PASS: commands/evaluate.md — empty-shape row updated to name empty_qa + qa-loop"
   exit 0
   ```

7. **Update `commands/evaluate.md`** — replace the existing empty-shape row in the Input Shapes table. The current row (line 21 at HEAD) reads:

   ```
   | `empty`     | No `--input` and no `--spec-path`                                                     | Bounded Q&A loop (P05+ wires Q&A); then proposal as if paragraph | Operator-approve                       |
   ```

   Replace with:

   ```
   | `empty_qa`  | No `--input` and no `--spec-path`; operator answers up to 5 Q&A turns                 | `scripts/intake/qa-loop.sh` then proposal with `## Q&A` transcript embedded | Operator-approve (short-circuit forces `low_confidence: true` so fast-path is blocked) |
   ```

   The single-row update preserves FR-6 byte-compat for the legacy spec-on-disk row (which is unchanged) and does not require any other section edit.

8. **Author `scripts/verify/m024-p05-suite.sh`** — suite runner that executes every P05 verify with MEM002 parallel-array tracking + `PASS:` / `FAIL:` summary:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-suite.sh
   # M024/P05 suite runner — invokes every per-claim verify and the two phase tests.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   VDIR="$ROOT/scripts/verify"

   verifies="
     m024-p05-qa-questions-template.sh
     m024-p05-qa-loop-script.sh
     m024-p05-qa-loop-cap.sh
     m024-p05-qa-loop-shortcircuit.sh
     m024-p05-proposal-emit-empty-qa.sh
     m024-p05-empty-qa-full.sh
     m024-p05-empty-qa-shortcircuit.sh
     m024-p05-write-confinement.sh
     m024-p05-evaluate-md.sh
   "

   pass_count=0
   fail_count=0
   failures=""

   for v in $verifies; do
     vp="$VDIR/$v"
     if [ ! -x "$vp" ]; then
       echo "FAIL: $v not executable"
       fail_count=$((fail_count + 1))
       failures="$failures $v"
       continue
     fi
     if bash "$vp" >/dev/null 2>&1; then
       pass_count=$((pass_count + 1))
       echo "  ok: $v"
     else
       fail_count=$((fail_count + 1))
       failures="$failures $v"
       echo "  FAIL: $v"
     fi
   done

   echo ""
   echo "M024/P05 suite — pass=$pass_count fail=$fail_count"
   if [ "$fail_count" -gt 0 ]; then
     echo "FAIL: M024/P05 suite — failures:$failures"
     exit 1
   fi
   echo "PASS: M024/P05 suite — all $pass_count verifies green"
   exit 0
   ```

9. **Make the new scripts executable**: `chmod +x tests/test-empty-qa-loop.sh`, `chmod +x tests/test-qa-short-circuit.sh`, `chmod +x scripts/verify/m024-p05-empty-qa-full.sh`, `chmod +x scripts/verify/m024-p05-empty-qa-shortcircuit.sh`, `chmod +x scripts/verify/m024-p05-write-confinement.sh`, `chmod +x scripts/verify/m024-p05-evaluate-md.sh`, `chmod +x scripts/verify/m024-p05-suite.sh` (seven single-script-file commands; do not chain).

## Must-Haves

- `tests/test-empty-qa-loop.sh` exists, is executable, exits 0 with `PASS: ...` on a clean checkout, and asserts: `input_shape: "empty_qa"`, `qa_short_circuited: false`, `low_confidence: false`, `auto_proceeded: false`, and exactly 5 `### Q<N>` blocks under `## Q&A`.
- `tests/test-qa-short-circuit.sh` exists, is executable, exits 0 with `PASS: ...`, and asserts: `input_shape: "empty_qa"`, `qa_short_circuited: true`, `low_confidence: true`, `auto_proceeded: false` (P04 guard fires), and that no answers past the `enough` token leak into the proposal body.
- `scripts/verify/m024-p05-empty-qa-full.sh` and `scripts/verify/m024-p05-empty-qa-shortcircuit.sh` exist, are executable, and wrap the two phase tests.
- `scripts/verify/m024-p05-write-confinement.sh` exists, is executable, exits 0 with `PASS: ...`, and asserts that `qa-loop.sh` and `proposal-emit.sh` perform no unguarded absolute-path writes outside the allowed surfaces (intake-root, template substitutions, mktemp scratch).
- `scripts/verify/m024-p05-evaluate-md.sh` exists, is executable, exits 0 with `PASS: ...`, and asserts `commands/evaluate.md` references `empty_qa` and `qa-loop` and no longer contains the stale `P05+ wires Q&A` placeholder text.
- `commands/evaluate.md` empty-shape row in the Input Shapes table is updated to name `empty_qa` and `scripts/intake/qa-loop.sh`. No other rows are touched (FR-6).
- `scripts/verify/m024-p05-suite.sh` exists, is executable, runs every P05 verify (nine total), and reports `pass_count`/`fail_count` with structured `PASS:`/`FAIL:` summary lines.
- `bash scripts/verify/m024-p05-suite.sh` exits 0 on a clean checkout.
- AD-19 single-script-file shape preserved across every new file. No inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T04 writes only to the seven new files plus the one-row edit in `commands/evaluate.md`.

## Verification

```
bash scripts/verify/m024-p05-suite.sh
bash scripts/verify/m024-p04-suite.sh
bash scripts/verify/m024-p03-suite.sh
```

The first exits 0 with `PASS: M024/P05 suite — all 9 verifies green` (or similar with the actual count). The two upstream suites continue to pass — T04 only adds new files and edits one row of `commands/evaluate.md` whose location is in the empty-shape row, not in any P03/P04-asserted region.

## Inputs

### From Previous Tasks

- `templates/intake-qa-questions.md` (from T01) — exists; not directly read by T04 but verified-by-reference via the suite.
- `scripts/intake/qa-loop.sh` (from T02)
  - Key API: `qa-loop.sh --answers-from <file> --transcript-out <path>` returns `qa_short_circuited=<bool>` + `qa_turns=<count>` and writes a transcript with `### Q<N>` blocks. Used indirectly via the emitter.
- `scripts/intake/proposal-emit.sh` (modified by T03)
  - Key API: `proposal-emit.sh --qa-answers-from <file> [--intake-root <path>]` returns `proposal_path=<absolute>` and emits a proposal with `input_shape: "empty_qa"`, `qa_short_circuited`, `low_confidence`, and a `## Q&A` body section.
  - Behavioral contract: short-circuit forces `low_confidence: true` which the P04 fast-path guard refuses to auto-proceed past — so `auto_proceeded: false` on every short-circuited proposal.

### From Disk (Pre-existing)

- `commands/evaluate.md` — pre-existing P03-rewritten command file with the Input Shapes table on line 9. The empty-shape row sits at line 21 at HEAD. T04 modifies only that one row.
- `tests/` directory — pre-existing test home. P03 + P04 already populated this directory (`tests/test-paragraph-intake.sh`, `tests/test-fast-path-auto-proceed.sh`, etc.).
- `scripts/verify/` directory — pre-existing verify-script home for M024 phase verifies.
- `scripts/verify/m024-p03-suite.sh`, `scripts/verify/m024-p04-suite.sh` — pre-existing upstream suite runners. T04's verification step re-runs them to prove no regressions.
- `mktemp`, `cat`, `grep`, `sed`, `chmod`, `bash` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No process substitution `<(...)`. No `$(... | ...)` containing pipes.
- Writes only to: `tests/test-empty-qa-loop.sh`, `tests/test-qa-short-circuit.sh`, `scripts/verify/m024-p05-empty-qa-full.sh`, `scripts/verify/m024-p05-empty-qa-shortcircuit.sh`, `scripts/verify/m024-p05-write-confinement.sh`, `scripts/verify/m024-p05-evaluate-md.sh`, `scripts/verify/m024-p05-suite.sh`, and the single-row edit in `commands/evaluate.md` (SB-3).
- AD-19 single-script-file shape: every external invocation in every new verify and test is a top-level command; no inline compound bash, no plain subshells.
- The MEM002 suite-runner pattern (parallel arrays for pass/fail tracking, structured `PASS:`/`FAIL:` summary) is preserved verbatim from P03/P04 — this milestone is consistent in its suite-runner shape.
- The condition-violation regression fence is the load-bearing P05 invariant: short-circuit MUST set `low_confidence: true` MUST block the P04 fast-path. The two-test pair witnesses this end-to-end.

## Expected Output

`tests/test-empty-qa-loop.sh` and `tests/test-qa-short-circuit.sh` exist and pass; the five new verifies (`m024-p05-empty-qa-full.sh`, `m024-p05-empty-qa-shortcircuit.sh`, `m024-p05-write-confinement.sh`, `m024-p05-evaluate-md.sh`, `m024-p05-suite.sh`) exist and pass; `commands/evaluate.md` row 21 (empty-shape row) is updated to name `empty_qa` and `qa-loop`; `bash scripts/verify/m024-p05-suite.sh` exits 0 with `PASS: M024/P05 suite — all 9 verifies green`. The P03 and P04 suites still pass on a clean checkout.
