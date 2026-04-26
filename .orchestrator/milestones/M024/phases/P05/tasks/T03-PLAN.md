---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M024"
name: "Wire qa-loop into proposal-emit.sh — empty-input branch + Q&A section + low_confidence on short-circuit"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `templates/intake-qa-questions.md` ships with the 5-question schema; T01's verify (`m024-p05-qa-questions-template.sh`) passes.
- T02 complete: `scripts/intake/qa-loop.sh` is executable and accepts `--answers-from <file>` / `--transcript-out <path>`. T02's three verifies (`m024-p05-qa-loop-script.sh`, `m024-p05-qa-loop-cap.sh`, `m024-p05-qa-loop-shortcircuit.sh`) pass.
- P01 + P04 already shipped: `scripts/intake/proposal-emit.sh` exists at HEAD with the rendering pipeline (shape-detect → intake-id-allocate → intensity-recommend → axis swaps → fast-path check → final write). The proposal frontmatter carries `qa_short_circuited` and `low_confidence` keys (default `false`). The body template `templates/intake-proposal.md` does **not** today contain a `## Q&A` heading or `{{qa_section}}` placeholder; T03 introduces the embedding shape.

## Description

Extend `scripts/intake/proposal-emit.sh` so that when invoked with **neither** `--input` **nor** `--spec-path` **and** with a new `--qa-answers-from <file>` flag, the emitter:

1. Treats the invocation as an empty-input branch.
2. Allocates a transcript scratch path under `/tmp` via `mktemp`.
3. Invokes `bash scripts/intake/qa-loop.sh --answers-from <file> --transcript-out <tmp>` and parses two stdout lines (`qa_short_circuited=<bool>`, `qa_turns=<count>`).
4. Reads the transcript file content into a shell variable.
5. Sets `input_shape="empty_qa"` (overriding shape-detect's `empty` value).
6. Sets `qa_short_circuited` from the loop's stdout.
7. When `qa_short_circuited="true"`, additionally sets `low_confidence="true"` so the P04 fast-path guard fires (and the proposal cannot auto-bypass the operator approval gate per the spec edge case "Q&A short-circuit on question 1").
8. Embeds the transcript verbatim under a `## Q&A` heading appended to the proposal body — sitting after the existing `## Approval` section (the `## Approval` section comes from `templates/intake-proposal.md` and is the last body section today).
9. Sets a `QA_AXES_DONE=1` flag (mirroring P04's `FAST_PATH_AXES_DONE`, P03's `PARA_AXES_DONE`, and P02's `SPEC_AXES_DONE`) so later axis-rationale loops do not clobber the empty-qa rationale slots with the P01 stub string.
10. Routes the `low_confidence` swap to occur **before** the P04 fast-path check block (lines 218–246 in the HEAD-version of `proposal-emit.sh`) so the gate sees the true value, not the template literal `{{low_confidence}}`.

The wiring must preserve byte-compat for every other input mode (paragraph, idea, fragment, spec) — T03 only adds new behavior on the empty-input branch and updates the `low_confidence` swap-ordering invariant the P04 block already relies on (the existing P04 block already swaps `low_confidence` ahead of the gate; T03 just makes that swap unconditionally derive from the qa-loop result on the empty-qa branch).

## Steps

1. **Add the `--qa-answers-from <file>` flag to `scripts/intake/proposal-emit.sh`** — extend the argument-parsing while-loop:

   ```bash
   while [ $# -gt 0 ]; do
     case "$1" in
       --input)              INPUT="$2"; shift 2 ;;
       --spec-path)          SPEC_PATH="$2"; shift 2 ;;
       --intake-root)        INTAKE_ROOT="$2"; shift 2 ;;
       --qa-answers-from)    QA_ANSWERS_FROM="$2"; shift 2 ;;
       -h|--help)
         echo "usage: proposal-emit.sh [--input <string>] [--spec-path <path>] [--qa-answers-from <file>]" >&2
         exit 2 ;;
       *)
         echo "proposal-emit.sh: unknown arg '$1'" >&2; exit 2 ;;
     esac
   done

   QA_ANSWERS_FROM="${QA_ANSWERS_FROM:-}"
   ```

2. **Insert the empty-qa branch after the (1) Shape block but before (2) Intake-id**, so the intake-id allocator sees the "empty input" mode (counter-allocate `<NNN>-empty-qa-...`) rather than treating the qa-loop answers as the input:

   ```bash
   # (1a) Empty + Q&A branch (M024/P05 — FR-5).
   #
   # Triggered when neither --input nor --spec-path is supplied AND
   # --qa-answers-from is. The loop reads questions from the static
   # template and answers from the line-mode file, captures a transcript,
   # and propagates qa_short_circuited / low_confidence into the
   # downstream rendering.
   QA_LOOP="$ROOT/scripts/intake/qa-loop.sh"
   qa_transcript=""
   qa_short_circuited="false"
   if [ -z "$INPUT" ] && [ -z "$SPEC_PATH" ] && [ -n "$QA_ANSWERS_FROM" ]; then
     [ -x "$QA_LOOP" ] || { echo "proposal-emit.sh: qa-loop.sh not executable" >&2; exit 1; }
     [ -f "$QA_ANSWERS_FROM" ] || { echo "proposal-emit.sh: qa answers file not found: $QA_ANSWERS_FROM" >&2; exit 1; }
     qa_tx_tmp=$(mktemp)
     qa_out=$(bash "$QA_LOOP" --answers-from "$QA_ANSWERS_FROM" --transcript-out "$qa_tx_tmp")
     qa_short_circuited=$(echo "$qa_out" | sed -n 's/^qa_short_circuited=//p' | head -1)
     [ -n "$qa_short_circuited" ] || qa_short_circuited="false"
     qa_transcript=$(cat "$qa_tx_tmp")
     rm -f "$qa_tx_tmp"

     # Override the shape-detect output: empty + qa-loop ran → empty_qa.
     input_shape="empty_qa"
     # input_hash will be computed from the transcript contents (deterministic).
     INPUT="$qa_transcript"   # synthesize INPUT for downstream id-allocate + hash
   fi
   ```

   The `INPUT="$qa_transcript"` synthesis lets the existing intake-id-allocate counter+slug logic produce a useful slug from the transcript (e.g., `001-add-a-last-seen` from "add a last-seen timestamp to status command output"), rather than introducing a new id-allocate code path.

3. **Update the `low_confidence` derivation block** (currently after the existing `low_confidence="false"` initialization). Replace:

   ```bash
   low_confidence="false"
   [ "$shape_classification" = "low" ] && low_confidence="true"
   ```

   with:

   ```bash
   low_confidence="false"
   [ "$shape_classification" = "low" ] && low_confidence="true"
   # Q&A short-circuit forces low_confidence so the P04 fast-path guard fires.
   [ "$qa_short_circuited" = "true" ] && low_confidence="true"
   ```

4. **Update `qa_short_circuited`'s default value** — replace the existing `qa_short_circuited="false"` initialization line with a derive-from-loop assignment that defers to the empty-qa branch when set:

   ```bash
   # qa_short_circuited is set above by the (1a) empty-qa branch when applicable;
   # otherwise default to "false" for all other input modes.
   qa_short_circuited="${qa_short_circuited:-false}"
   ```

5. **Mark the `QA_AXES_DONE` flag** before the per-axis rationale-stub loop. Add immediately after the existing `SPEC_AXES_DONE=1` block (around line 286 of the HEAD-version `proposal-emit.sh`):

   ```bash
   # M024/P05 — empty-qa branch overrides P01 stubs for input_shape and decomposition rationale slots.
   if [ "$input_shape" = "empty_qa" ]; then
     swap rationale_input_shape "Operator-supplied via bounded Q&A loop (5 turns max, `enough` short-circuit). Transcript embedded under ## Q&A."
     swap evidence_input_shape  "scripts/intake/qa-loop.sh transcript at this proposal's ## Q&A section"
     swap rationale_scope_tier "Derived from Q2 (scope) answer in the embedded Q&A transcript."
     swap evidence_scope_tier  "Operator answer to Q2 in ## Q&A"
     swap rationale_decomposition "Derived from Q2 (scope) answer in the embedded Q&A transcript."
     swap evidence_decomposition  "Operator answer to Q2 in ## Q&A"
     QA_AXES_DONE=1
   fi
   ```

6. **Extend the existing per-axis stub-swap loop** to honor `QA_AXES_DONE`:

   ```bash
   for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
     if [ "${PARA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
       continue
     fi
     if [ "${SPEC_AXES_DONE:-0}" = "1" ] && [ "$axis" = "input_shape" -o "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
       continue
     fi
     if [ "${QA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "input_shape" -o "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
       continue
     fi
     swap "rationale_${axis}" "$stub_rationale"
     swap "evidence_${axis}" "$stub_evidence"
   done
   ```

7. **Append the `## Q&A` section to the rendered proposal**, after all swaps and after the final `mv "$tmp_render" "$out_path"` line:

   ```bash
   # Append the Q&A transcript (M024/P05 — FR-5).
   if [ -n "$qa_transcript" ]; then
     {
       echo ""
       echo "## Q&A"
       echo ""
       echo "$qa_transcript"
     } >> "$out_path"
   fi
   ```

8. **Author `scripts/verify/m024-p05-proposal-emit-empty-qa.sh`** — exercises the emitter end-to-end on a 5-answer line-mode invocation:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-proposal-emit-empty-qa.sh
   # M024/P05/T03 verify — empty + qa-answers-from emits empty_qa proposal.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

   tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
   ans="$tmp/answers.txt"
   cat > "$ans" <<'EOF'
   add a last-seen timestamp to status command output
   single-feature
   code
   no
   Standard
   EOF

   emit_out=$(bash "$EMIT" --qa-answers-from "$ans" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

   [ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

   grep -q '^input_shape: "empty_qa"$'        "$proposal" || { echo "FAIL: input_shape not empty_qa"; exit 1; }
   grep -q '^qa_short_circuited: false$'      "$proposal" || { echo "FAIL: qa_short_circuited not false"; exit 1; }
   grep -q '^low_confidence: false$'          "$proposal" || { echo "FAIL: low_confidence should be false on full Q&A run"; exit 1; }
   grep -q '^## Q&A$'                         "$proposal" || { echo "FAIL: proposal missing ## Q&A section"; exit 1; }

   count=$(grep -c '^### Q' "$proposal")
   [ "$count" = "5" ] || { echo "FAIL: proposal Q&A section has $count blocks (expected 5)"; exit 1; }

   echo "PASS: proposal-emit.sh — empty + 5 answers → input_shape: empty_qa; ## Q&A with 5 blocks; low_confidence false"
   exit 0
   ```

9. **Make the verify executable**: `chmod +x scripts/verify/m024-p05-proposal-emit-empty-qa.sh`.

## Must-Haves

- `scripts/intake/proposal-emit.sh` accepts a new `--qa-answers-from <file>` flag without breaking the existing `--input` / `--spec-path` / `--intake-root` invocations.
- An invocation with neither `--input` nor `--spec-path` AND `--qa-answers-from <file>` produces a proposal with frontmatter `input_shape: "empty_qa"`.
- The proposal body contains a `## Q&A` heading followed by the transcript content T02's qa-loop produced (one `### Q<N>` block per answered turn).
- On a 5-line answers invocation, the proposal contains exactly 5 `### Q<N>` blocks under `## Q&A`, frontmatter `qa_short_circuited: false`, and frontmatter `low_confidence: false`.
- On an `enough`-bearing answers invocation (short-circuit), the proposal frontmatter contains `qa_short_circuited: true` AND `low_confidence: true`. (T04 phase test exercises this case.)
- The `QA_AXES_DONE=1` flag prevents the per-axis stub-rationale loop from clobbering the empty-qa rationale slots (`rationale_input_shape`, `rationale_scope_tier`, `rationale_decomposition`).
- Backward-compat: a paragraph, idea, fragment, or spec invocation produces the same proposal it produces today (no byte-changes to those branches' rendered output beyond what's already in HEAD). T04's phase suite + the existing M024/P03/P04 phase suites prove this.
- AD-19 single-script-file shape preserved in `proposal-emit.sh` and the new verify; no inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T03 writes only to `scripts/intake/proposal-emit.sh` and `scripts/verify/m024-p05-proposal-emit-empty-qa.sh`. The script writes to `.orchestrator/intake/<id>/` (or `--intake-root` override) and trap-cleaned `/tmp` scratch.

## Verification

```
bash scripts/verify/m024-p05-proposal-emit-empty-qa.sh
bash scripts/verify/m024-p04-suite.sh
bash scripts/verify/m024-p03-suite.sh
```

The first exits 0 with the `PASS:` line. The two upstream suites (P03 + P04) MUST continue to pass — T03 alters the empty branch only; the paragraph + spec + fast-path paths are unchanged.

## Inputs

### From Previous Tasks

- `templates/intake-qa-questions.md` (from T01)
  - Key API: static markdown, five `### Q<N>` headings, schema fields. Read directly by T02's qa-loop, not by T03.
- `scripts/intake/qa-loop.sh` (from T02)
  - Key API: `qa-loop.sh --answers-from <file> --transcript-out <path>` returns two stdout lines (`qa_short_circuited=<bool>`, `qa_turns=<count>`) and writes a transcript file with `### Q<N>` blocks.
  - Behavioral contract: enforces the FR-5 cap (≤5 turns), case-insensitive `enough` short-circuit, blank-line short-circuit. Validates the questions file before processing.
  - Exit codes: 0 on success, 2 on usage error, 1 on internal error.

### From Disk (Pre-existing)

- `scripts/intake/proposal-emit.sh` — pre-existing P01-built emitter at HEAD (304 lines per HEAD inspection). Pipeline: argument-parse → shape-detect → intake-id-allocate → intensity-recommend → paragraph/spec deep-classifier → axis stubs/overrides → frontmatter dynamic values → render-via-sed-swap → P04 fast-path check → body slot fills → write to `.orchestrator/intake/<id>/proposal.md` → emit `proposal_path=<absolute>` to stdout.
- `templates/intake-proposal.md` — pre-existing P01 template with the 25-key frontmatter and the `## Approval` body section. T03 does not modify this template — the `## Q&A` section is appended to the rendered output by `proposal-emit.sh`, not authored as a template placeholder, so the template stays minimal.
- `scripts/intake/intake-id-allocate.sh` — pre-existing counter+slug allocator. T03 synthesizes `INPUT="$qa_transcript"` so the existing slug-from-input logic produces a useful intake-id without code changes.
- `scripts/state/read-config.sh`, `scripts/intake/approval-gate.sh` — pre-existing P04 fast-path infrastructure. T03 does not touch them; the existing block in `proposal-emit.sh` (lines ~218–246 at HEAD) automatically picks up the new `low_confidence="true"` value on short-circuit and refuses to flip `auto_proceeded`.
- `mktemp`, `cat`, `head -1`, `sed -n 's/^X=//p'`, `chmod` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No `[[ ]]` in any new code (the pre-existing `proposal-emit.sh` uses some `[[ ]]` constructs already — leave those untouched). No process substitution `<(...)`. No `$(... | ...)` containing pipes.
- Writes only to `scripts/intake/proposal-emit.sh` and `scripts/verify/m024-p05-proposal-emit-empty-qa.sh` (SB-3). The script writes only to `.orchestrator/intake/<id>/` (or `--intake-root` override) and trap-cleaned `mktemp` scratch.
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells.
- Backward-compat: `proposal-emit.sh --input <string>`, `proposal-emit.sh --spec-path <path>`, and `proposal-emit.sh --input <string> --intake-root <path>` MUST continue to behave identically to HEAD (the P03 + P04 phase suites prove this).
- The `## Q&A` heading is appended to the proposal body **after** the final swap pass and after the file is moved to `$out_path`. This keeps the section literally markdown-pasted (no `{{placeholder}}` substitution) — simplest shape; future TTY mode does not change the embedding contract.
- The empty-qa branch synthesizes `INPUT="$qa_transcript"` solely to feed the existing intake-id-allocate slug logic. The `input_hash` is computed from the transcript content (deterministic across runs with the same answers file).

## Expected Output

`scripts/intake/proposal-emit.sh` is modified to accept `--qa-answers-from`, runs the qa-loop on the empty branch, sets `input_shape: "empty_qa"`, propagates `qa_short_circuited` to frontmatter, escalates `low_confidence` on short-circuit, embeds the transcript under `## Q&A`, and gates the per-axis stub loop with `QA_AXES_DONE`. `scripts/verify/m024-p05-proposal-emit-empty-qa.sh` exists, is executable, and exits 0 with `PASS: proposal-emit.sh — empty + 5 answers → input_shape: empty_qa; ## Q&A with 5 blocks; low_confidence false`. The P03 and P04 phase suites still pass on a clean checkout.
