---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M030"
name: "Classifier script + determinism + perf/network + ground-truth verifiers"
depends_on: ["T01"]
---

## Prerequisites

- `tools/verify/p01-d-a4-timeline.sh` exists (T01 deliverable). The script is on disk so the moment T02 commits `classify-task.sh`, re-running this verifier triggers Mode B (git-log ordering) and confirms timeline ordering by construction.
- `tests/fixtures/m030-classifier-corpus/labels.yml` exists with 40 entries (P00/T02; 20 mechanical / 15 standard / 5 novel).
- `tests/fixtures/m030-classifier-corpus/README.md` exists with the FR-1 labeling rubric (P00/T03 deliverable; the rubric is the SSOT for the heuristic table T02 implements).
- All `plan_path` values in `labels.yml` resolve to existing files on disk (P00 verifier `p00-plans-exist.sh` already gates this).
- `scripts/dispatch/classify-task.sh` does **NOT** yet exist on disk at the start of T02.

Plan-time prerequisite-existence verification: every path above resolves under `[ -f <path> ]` except `scripts/dispatch/classify-task.sh` which MUST NOT exist (`[ ! -f scripts/dispatch/classify-task.sh ]`).

## Description

T02 is the high-risk core primitive. It authors `scripts/dispatch/classify-task.sh` — the deterministic, sub-100ms, no-network-call task-character classifier that is the load-bearing input to every downstream M030 phase. Concrete deliverables:

1. `scripts/dispatch/classify-task.sh` — the FR-1 / FR-2 classifier.
2. `tools/verify/p01-classifier-determinism.sh` — SC-1 byte-equality gate (two runs same plan, `diff` empty).
3. `tools/verify/p01-classifier-perf-and-network.sh` — performance (<100ms wall-clock) + grep-clean of the script body (no curl/wget/nc/dispatch-adapter invocations).
4. `tools/verify/p01-classifier-ground-truth.sh` — SC-10 ≥85% agreement gate against the P00 corpus.

The classifier emits exactly two lines on stdout per invocation, in this order:

```
character=<mechanical|standard|novel>
confidence=<high|medium|low>
```

No other stdout output. Stderr may carry diagnostic lines (e.g., `RESULT:` lines if the project's `scripts/lib/errors.sh` is sourced). The output vocabulary is a closed enum identical to the P00 fixture corpus vocabulary.

### Heuristic table (FR-2 SSOT)

The classifier reads PLAN.md frontmatter and body and applies a literal rule table. No machine learning, no LLM, no network. The full input set per FR-2 is: (a) explicit `## Steps` block presence + structure, (b) file-touch breadth declared in plan, (c) verification-block specificity, (d) frontmatter `type:` field if present, (e) phase position within milestone, and (f) recent-retry signal from [M027](../../../../../milestones/M027/index.md) anomaly JSONL. For T02's initial implementation, inputs (a)-(d) are the load-bearing signals; (e) and (f) are stubbed to pass-through values that don't affect classification (left as TODO comments in the script for follow-up). This is acceptable because the SC-10 ≥85% agreement gate is what mechanically validates the heuristic — if the simplified heuristic table hits ≥85% on the 40-entry corpus, it ships; if not, T02 iterates the table until it does, OR the inputs (e)/(f) are wired up.

Concrete heuristic rules (apply in priority order; the first match wins):

1. **Frontmatter override** — if PLAN.md frontmatter contains `complexity: <tier>` or an explicit character hint, use it. Confidence: high.
2. **Novel signals (high-precedence)** — if the plan's Goal / Description section contains any of the literal words `explore`, `design alternatives`, `evaluate alternatives`, `spike`, `research`, `investigate options`, `prototype`, AND no `## Steps` block lists explicit file paths, classify as `novel`. Confidence: high.
3. **Mechanical signals** — if a `## Steps` block exists AND the union of file paths declared in Steps + Files-Likely-Touched ≤ 3 distinct files AND the `## Verification` section contains at least one explicit `bash <path>.sh` invocation, classify as `mechanical`. Confidence: high.
4. **Standard fallback** — anything else is `standard`. Confidence is `high` if both a Steps block and a Verification block are present, `medium` if one is present, `low` if neither (rare — typically novel framing without explicit "explore"-class words).

The exact regex patterns + bash extraction shapes are documented in the script body's commented heuristic table; T02's executor authors them with judgment, then iterates until SC-10's ≥85% agreement gate (`tools/verify/p01-classifier-ground-truth.sh`) passes.

### Output stability — D-A9

Per D-A9, classifier output for the same PLAN.md is consistent within a single `orchestrator:auto` run because the anomaly JSONL state is snapshotted at session start. T02's initial implementation does NOT read anomaly JSONL (input (f) is stubbed), so cross-run consistency is trivially preserved. When input (f) is wired in a future iteration, the script MUST snapshot the JSONL once at the start of the run (or read it once at session startup) so two invocations within the same run produce identical output. The SC-1 determinism verifier in T02 catches violations.

## Steps

1. **Confirm `tools/verify/p01-d-a4-timeline.sh` is on disk and `scripts/dispatch/classify-task.sh` is absent.** Run:

   ```bash
   ls tools/verify/p01-d-a4-timeline.sh
   ```

   Expected: prints the path. Then:

   ```bash
   ls scripts/dispatch/classify-task.sh
   ```

   Expected: `No such file or directory` (stderr) + non-zero exit.

2. **Author `scripts/dispatch/classify-task.sh`.** Bash 3.2-compatible. No `declare -A`. No jq required (jq optional fallback acceptable per MEM001). Single-script-file invocation pattern (`bash classify-task.sh <plan-path>`). Output contract:

   - stdout line 1: `character=<mechanical|standard|novel>`
   - stdout line 2: `confidence=<high|medium|low>`
   - exit 0 on success, exit 1 on usage error (missing arg, plan path doesn't exist).

   Skeleton (executor fills the heuristic table per the FR-2 input set + the priority rules above):

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/classify-task.sh — M030 task-character classifier (FR-1, FR-2).
   #
   # Reads a PLAN.md and emits two stdout lines:
   #   character=<mechanical|standard|novel>
   #   confidence=<high|medium|low>
   #
   # Pure bash + grep/sed/awk. NO LLM call. NO network. NO jq dependency
   # on the hot path. Bash 3.2 compatible. Runs in well under 100ms.
   #
   # Usage: classify-task.sh <plan-path>
   #
   # AD-19 single-script-file invocation. CON-1 (no-LLM-on-hot-path).
   # CON-3 (symbolic-tier closure — classifier emits character only;
   # tier resolution lives in templates/model-routing.yml).
   #
   # FR-2 input set (inputs e/f stubbed in v1; see ## Notes for the
   # SC-10 agreement-validated rationale):
   #   (a) ## Steps block presence + structure   — IMPLEMENTED
   #   (b) file-touch breadth in plan            — IMPLEMENTED
   #   (c) ## Verification specificity           — IMPLEMENTED
   #   (d) frontmatter type: field               — IMPLEMENTED
   #   (e) phase position                        — STUBBED (no-op)
   #   (f) recent-retry anomaly JSONL signal     — STUBBED (no-op)

   set -uo pipefail

   PLAN_PATH="${1:-}"
   if [ -z "$PLAN_PATH" ]; then
     echo "usage: classify-task.sh <plan-path>" >&2
     exit 1
   fi
   if [ ! -f "$PLAN_PATH" ]; then
     echo "classify-task.sh: plan not found: $PLAN_PATH" >&2
     exit 1
   fi

   # ---- Heuristic table (priority order, first match wins) ----
   #
   # Rule 1: frontmatter explicit override.
   # Rule 2: novel signals + no concrete file targets.
   # Rule 3: mechanical signals (Steps + ≤3 files + bash verifiers).
   # Rule 4: standard fallback (confidence depends on Steps/Verification presence).

   character=""
   confidence=""

   # Rule 1: explicit override in frontmatter.
   if awk '/^---$/{c++; next} c==1 && /^character: */{print $2; found=1; exit} END{exit !found}' "$PLAN_PATH" > /tmp/p01-classify-fm-char.tmp 2>/dev/null; then
     fm_char="$(cat /tmp/p01-classify-fm-char.tmp)"
     case "$fm_char" in
       mechanical|standard|novel)
         character="$fm_char"
         confidence="high"
         ;;
     esac
     rm -f /tmp/p01-classify-fm-char.tmp
   fi

   # Rule 2: novel signals.
   if [ -z "$character" ]; then
     # Detect "explore"-class language outside code fences.
     if grep -E -i -q '\b(explore|design alternatives|evaluate alternatives|spike|research|investigate options|prototype)\b' "$PLAN_PATH"; then
       # Only classify novel if there are NOT explicit file paths in Steps.
       if ! grep -E -q '^\s*[0-9]+\.\s+\*\*Author\b|^\s*-\s+`[a-zA-Z0-9_/.-]+\.(sh|md|yml|yaml|py|ts|tsx|js)`' "$PLAN_PATH"; then
         character="novel"
         confidence="high"
       fi
     fi
   fi

   # Rule 3: mechanical.
   if [ -z "$character" ]; then
     has_steps=0
     has_verif_bash=0
     file_count=0
     if grep -E -q '^## Steps' "$PLAN_PATH"; then has_steps=1; fi
     if grep -E -q '^bash [a-zA-Z0-9_/.-]+\.sh|^\s*bash [a-zA-Z0-9_/.-]+\.sh' "$PLAN_PATH"; then has_verif_bash=1; fi
     # File-touch count: extract from "Files Likely Touched" section + Steps file paths.
     file_count="$(grep -E -o '`[a-zA-Z0-9_/.-]+\.(sh|md|yml|yaml|py|ts|tsx|js)`' "$PLAN_PATH" | sort -u | wc -l | tr -d ' ')"
     if [ "$has_steps" -eq 1 ] && [ "$has_verif_bash" -eq 1 ] && [ "$file_count" -le 3 ]; then
       character="mechanical"
       confidence="high"
     fi
   fi

   # Rule 4: standard fallback.
   if [ -z "$character" ]; then
     character="standard"
     has_steps=0
     has_verif=0
     if grep -E -q '^## Steps' "$PLAN_PATH"; then has_steps=1; fi
     if grep -E -q '^## Verification' "$PLAN_PATH"; then has_verif=1; fi
     if [ "$has_steps" -eq 1 ] && [ "$has_verif" -eq 1 ]; then
       confidence="high"
     elif [ "$has_steps" -eq 1 ] || [ "$has_verif" -eq 1 ]; then
       confidence="medium"
     else
       confidence="low"
     fi
   fi

   printf 'character=%s\n' "$character"
   printf 'confidence=%s\n' "$confidence"
   exit 0
   ```

   The skeleton is a starting point; the executor MUST iterate the regex patterns + thresholds until `tools/verify/p01-classifier-ground-truth.sh` reports ≥85% agreement against the 40-entry corpus. The classifier MUST NOT call out to any other dispatch script and MUST NOT touch the network.

   `chmod +x scripts/dispatch/classify-task.sh` after writing.

3. **Author `tools/verify/p01-classifier-determinism.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Behavior:

   - Path argument default: a sample plan from `tests/fixtures/m030-classifier-corpus/labels.yml` (e.g., the first `plan_path:` value). Override via `$1`.
   - Run `bash scripts/dispatch/classify-task.sh "$plan" > /tmp/p01-determinism-a.out 2>/dev/null` then `bash scripts/dispatch/classify-task.sh "$plan" > /tmp/p01-determinism-b.out 2>/dev/null` (separate statements; no compound chain).
   - `diff /tmp/p01-determinism-a.out /tmp/p01-determinism-b.out > /tmp/p01-determinism-diff.out 2>&1` — exit code 0 means byte-identical.
   - Confirm both stdout files contain exactly two lines, the first matching `^character=(mechanical|standard|novel)$` and the second matching `^confidence=(high|medium|low)$`.
   - On all checks pass, emit `SUMMARY: p01-classifier-determinism.sh pass=N fail=0` and exit 0; on any fail, exit 1 with the diagnostic + summary.
   - Cleanup: `rm -f /tmp/p01-determinism-*.out`.

4. **Author `tools/verify/p01-classifier-perf-and-network.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Two gates in one script:

   - **Performance gate**: pick the first `plan_path` from `labels.yml`. Capture wall-clock around `bash scripts/dispatch/classify-task.sh "$plan"` using bash `SECONDS` (precision ~1s — too coarse for sub-100ms) OR `date +%s%N` capturing nanoseconds before/after. Compute elapsed in milliseconds (integer arithmetic via `$((end-start))/1000000`). Assert `elapsed_ms < 100`. (To absorb wall-clock noise, the script does the run 5 times and takes the minimum elapsed value — runtime variance from cold cache / disk read should fall out of the minimum.)
   - **Network-call gate**: grep `scripts/dispatch/classify-task.sh` body for any of the literals `curl`, `wget`, `nc -`, `bash scripts/dispatch/dispatch-interface.sh`, `bash scripts/dispatch/adapters/backend/`, `dispatch-task`, `await-completion`, `LLM`, `claude `, `anthropic`, `openai`, `gpt-`. ALL grep invocations MUST exit 1 (no match). Any match is a fail.
   - On all checks pass, emit `SUMMARY: p01-classifier-perf-and-network.sh pass=N fail=0` and exit 0; on any fail, exit 1.

   Note on `date +%s%N`: macOS `date` does not natively support `%N` — the script MUST detect and fall back. Use `python3 -c 'import time; print(int(time.monotonic_ns()))'` as a portable fallback (python3 is on every supported runtime per existing repo conventions; the optional-jq guard pattern from MEM001 applies — fall back to `date +%s` * 1000 if python3 absent, accepting ±1s precision and looping the run 100 times to amortize). The executor picks the precision strategy that fits the runtime; the gate's contract is "elapsed < 100ms" not "use this specific timer".

5. **Author `tools/verify/p01-classifier-ground-truth.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Behavior:

   - Read `tests/fixtures/m030-classifier-corpus/labels.yml`.
   - For each `entries:` block, extract `plan_path` and the human-applied `character` value.
   - For each entry, run `bash scripts/dispatch/classify-task.sh "$plan_path" > /tmp/p01-gt-out.tmp 2>/dev/null`.
   - Parse the classifier's `character=...` line. Compare to the human label.
   - Track `agree` / `disagree` counts. Track per-class disagreements (helpful diagnostic when the gate fails).
   - Compute agreement: `agree * 100 / total`. Assert `agree >= ceil(0.85 * total)` (for total=40, threshold is 34).
   - On pass, emit a per-class breakdown summary (`mechanical: 18/20 agree`, `standard: 12/15 agree`, `novel: 4/5 agree`, total `34/40 = 85.0%`) plus `SUMMARY: p01-classifier-ground-truth.sh pass=1 fail=0` and exit 0.
   - On fail, emit the per-class breakdown + the list of disagreeing plans (`<plan_path> expected=<human_label> got=<classifier_label>`) + `SUMMARY: p01-classifier-ground-truth.sh pass=0 fail=1` and exit 1.

   YAML parsing: use `awk` to walk the `entries:` list. Each entry starts with a line matching `^  - plan_path:`; the `character:` line follows on the next non-comment line. No jq dependency. Bash 3.2 compatible.

6. **Iterate the classifier heuristics until ground-truth gate passes.** Run the four T02 verifiers in this order:

   ```bash
   bash tools/verify/p01-classifier-determinism.sh
   bash tools/verify/p01-classifier-perf-and-network.sh
   bash tools/verify/p01-classifier-ground-truth.sh
   ```

   If the ground-truth gate fails, the executor inspects the per-class disagreements, refines the heuristic table in `classify-task.sh`, and re-runs. The first-fail-retry / second-fail-pause discipline applies — but heuristic iteration is the expected loop here, not an exceptional state.

7. **Re-run T01's timeline verifier** to confirm Mode-B graduation. After committing `classify-task.sh`:

   ```bash
   bash tools/verify/p01-d-a4-timeline.sh
   ```

   Expected: `OK: labels.yml committed at <ts1> precedes classify-task.sh at <ts2>`, `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`, exit 0. If this fails, the timeline ordering has been violated — STOP and escalate.

8. **Stage and commit.** Add `scripts/dispatch/classify-task.sh` + the four `tools/verify/p01-classifier-*.sh` verifiers and commit with `git commit -F <message-file>`. Recommended message: `M030/P01/T02: classifier script + determinism + perf/network + ground-truth verifiers`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/dispatch/classify-task.sh` exists and emits deterministic stdout" — gated by `tools/verify/p01-classifier-determinism.sh`.
- "The classifier runs in well under 100ms per plan and makes no network calls" — gated by `tools/verify/p01-classifier-perf-and-network.sh`.
- "Classifier ground-truth agreement holds at ≥85%" — gated by `tools/verify/p01-classifier-ground-truth.sh`.

This task also confirms the timeline truth from T01 graduates correctly:

- "D-A4/SC-10 timeline ordering holds" — `tools/verify/p01-d-a4-timeline.sh` re-runs in Mode B post-commit.

## Verification

```bash
bash tools/verify/p01-classifier-determinism.sh
bash tools/verify/p01-classifier-perf-and-network.sh
bash tools/verify/p01-classifier-ground-truth.sh
bash tools/verify/p01-d-a4-timeline.sh
```

Each verifier uses single-script-file shape per AD-19. The four are the SC-1 / FR-1-perf / SC-10 / D-A4 mechanical gates respectively.

## Inputs

### From Previous Tasks

- `tools/verify/p01-d-a4-timeline.sh` (from T01)
  - Key API: invoke as `bash tools/verify/p01-d-a4-timeline.sh`. Pre-T02-commit: Mode A passes by absence. Post-T02-commit: Mode B passes via git-log ordering. T02 re-runs this in Step 7 to confirm Mode B fires correctly.

### From Disk (Pre-existing)

- `tests/fixtures/m030-classifier-corpus/labels.yml` — 40 hand-labeled entries; the SC-10 ground-truth source.
- `tests/fixtures/m030-classifier-corpus/README.md` — FR-1 labeling rubric (the SSOT for the heuristic table T02 implements).
- `specs/032-adaptive-model-selection/spec.md` FR-1 (lines 627), FR-2 (line 628), SC-1 (line 649), SC-10 (line 661), CON-1 (line 677), CON-3 (line 679).
- [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) D-A9 (lines 71-72; output-stability convention).
- `scripts/dispatch/classify-complexity.sh` (existing pattern for a similar script — useful reference for the awk-based YAML walk + the `errors.sh` / `events.sh` library sourcing convention; T02's classify-task.sh does NOT need to source those libs unless the executor decides the structured-output discipline benefits from it; the SC-1 determinism gate forbids any timestamp / PID in stdout).
- `scripts/dispatch/select-model.sh` (existing routing pattern; reference for tier resolution shape — T02 does NOT modify or call this; it's documentation context for understanding where `classify-task.sh`'s output flows in P02).

## Constraints

- **CON-1 (no-LLM-on-hot-path)**: classifier MUST NOT invoke any LLM. The perf-and-network gate enforces this by grep.
- **CON-3 (symbolic-tier closure)**: classifier emits `character` (mechanical|standard|novel), NOT tier (`fast|balanced|smart`). Tier resolution lives in `templates/model-routing.yml` (T03's deliverable). Hardcoding tier names in `classify-task.sh` is forbidden.
- **D-A9 (output-stability)**: within a single run, output for the same PLAN.md is consistent. T02's v1 trivially satisfies this because input (f) is stubbed (no anomaly JSONL read). Future iterations that wire input (f) MUST snapshot at session start.
- **SC-1 determinism**: two runs against the same plan produce byte-identical stdout. No timestamps, no PIDs, no random ordering, no `find` ordering reliance.
- **SC-10 ≥85% agreement**: classifier's output `character` matches the human label for ≥34 of the 40 corpus entries. T02 iterates until this holds.
- **D-A4 timeline ordering**: the first commit of `scripts/dispatch/classify-task.sh` lands AFTER the existing `tests/fixtures/m030-classifier-corpus/labels.yml` first-commit (`9f99df2`). The timeline verifier from T01 mechanically asserts this.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. YAML parsing via `grep`/`sed`/`awk` only.
- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. No compound chains in plan / verifier prose.

## Expected Output

- `scripts/dispatch/classify-task.sh` — heuristic classifier on disk, executable.
- `tools/verify/p01-classifier-determinism.sh` — SC-1 gate.
- `tools/verify/p01-classifier-perf-and-network.sh` — FR-1-perf + CON-1 gate.
- `tools/verify/p01-classifier-ground-truth.sh` — SC-10 ≥85% gate.
- All four T02 verifiers exit 0 on a clean run.
- T01's `p01-d-a4-timeline.sh` exits 0 in Mode B post-commit.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p01-classifier-determinism.sh` → `OK: classifier output byte-identical across two runs`, `SUMMARY: p01-classifier-determinism.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-classifier-perf-and-network.sh` → `OK: min elapsed <NN>ms < 100ms`, `OK: no network-call literals in classify-task.sh body`, `SUMMARY: p01-classifier-perf-and-network.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-classifier-ground-truth.sh` → per-class breakdown (`mechanical: 18/20`, `standard: 12/15`, `novel: 4/5`, total `34/40 = 85.0%`), `SUMMARY: p01-classifier-ground-truth.sh pass=1 fail=0`, exit 0.

The 40-entry corpus has class distribution 20 mechanical / 15 standard / 5 novel. The SC-10 ≥85% threshold is 34 agreements; the per-class shape that hits 34 is roughly 18+/12+/4+ given the corpus's class-confidence distribution (26 high / 14 medium / 0 low). The novel class is structurally rare (5 entries) — agreement of 4/5 is a 1-miss tolerance; 5/5 is achievable if the classifier's "explore"-language regex is precise. The executor SHOULD aim for full agreement on novel before relaxing thresholds elsewhere, because shadow-mode P02 verdicts will lean on the novel class as the load-bearing safety class.

If after multiple heuristic iterations the ≥85% gate cannot be reached, the executor escalates to plan-phase rather than fudging the corpus or weakening the threshold — SC-10 is a spec constraint per D-A4 (arbiter-ruled), not a plan-phase question.

The wall-clock perf gate using `date +%s%N` will fail on macOS by default (BSD `date` doesn't honor `%N`). The executor's fallback strategy is documented in Step 4 — python3 monotonic_ns or a 100-iteration loop with second-precision `date +%s`. Either is acceptable; the gate's contract is "single classification < 100ms wall-clock", not the timer mechanism.
