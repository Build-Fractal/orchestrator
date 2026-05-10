---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M031"
name: "commands/do.md skill + scripts/intake/do-entry.sh entry script (FR-10/11/12/13)"
depends_on: []
---

## Prerequisites

- P01 complete: `scripts/dispatch/build-context.sh` accepts `--profile=quick|standard|full` AND `--task-plan <file>` AND `--out <file>` AND `--meta-out <file>`. Direct-mode bypass fires when `--task-plan` is supplied. AD-11 sidecar emits 5 keys `{mem_count, total_tokens, profile, compression_applied, snip_applied}`. Verify by `grep -q -- '--meta-out' scripts/dispatch/build-context.sh` before authoring.
- P01 complete: `templates/orchestrator-config-default.yml` declares `entry_routing_confidence_floor: 0.7` AND `auto_proceed: true` AND `quick_knowledge_token_budget: 800` AND `tier_a_plus_prompt_summary_lines: 8`. Verify by `grep -q '^entry_routing_confidence_floor:' templates/orchestrator-config-default.yml` before authoring.
- P02 complete: `scripts/intake/shape-detect.sh` emits `tier_a_plus` as a sixth verdict value. Verdict surface is `idea | paragraph | tier_a_plus | fragment | spec | empty`. Confidence enum is `high | low`. Verify by `grep -q 'tier_a_plus' scripts/intake/shape-detect.sh`.
- P02 complete: `scripts/intake/route-to-dispatch.sh` accepts `--verdict tier_a_plus --task <description> [--yes] [--session-id <id>] [--scratch-root <dir>] [--dispatch-stub <script>]`. Verify by `grep -q -- '--verdict tier_a_plus' scripts/intake/route-to-dispatch.sh`.
- The existing `commands/dispatch.md` documents the Quick / Standard / Full intensity table. The Quick row carries the post-FR-4 phrasing "Quick profile" (no longer "Skip payload assembly"). Verify by `grep -q 'Quick profile' commands/dispatch.md`.
- The existing `commands/evaluate.md` carries the legacy phrasings "no orchestrator overhead" / "Do NOT create any orchestrator directory" — these are P04's drift-fix targets and are NOT modified by T01. Verify by inspection only; no change in T01.

## Description

T01 ships the universal entry's command surface and backing driver script. The four-branch routing table:

| Classifier output (verdict / confidence)       | Branch                | Action                                                                                    | Approval prompts |
|------------------------------------------------|-----------------------|-------------------------------------------------------------------------------------------|------------------|
| `tier_a_plus` (any confidence)                 | tier-a-plus-handoff   | exec `route-to-dispatch.sh --verdict tier_a_plus --task <desc> [--yes] [--dispatch-stub]` | one (P02 prompt; `--yes` skips) |
| `idea` (high) OR short `paragraph` (high)      | tier-a-degenerate     | invoke `build-context.sh --profile=quick --task-plan <plan> --out <pl> --meta-out <sc>` then emit `doing: <task> — knowledge: <N> MEMs / <X> tokens` to stderr; agent runtime adapter takes over (MEM018) | zero |
| `fragment` / `spec` / long `paragraph` (high)  | tier-bc-passthrough   | emit `route=tier_bc passthrough=orchestrator:specify` to stderr; exit 0 (operator runs the named command in their next turn — NG-6 one-shot discipline) | zero |
| any verdict with confidence below floor        | low-conf-prompt       | render explicit Tier A vs Tier B question to stderr; record `chosen_shape` in JSONL `unit_close` | one |

Key design notes:

1. **Confidence-floor numeric mapping (A-2 closure)**. `shape-detect.sh` emits `shape_classification=high|low` (an enum). The `entry_routing_confidence_floor` knob is numeric (P00 default `0.7`). Map `high → 1.0`, `low → 0.5` and apply the comparison `numeric_confidence >= floor`. `high` (1.0) clears the default floor 0.7; `low` (0.5) does not. This grounds the knob in the active classifier surface without modifying [M024](../../../../../milestones/M024/index.md) to emit a numeric. Future demand can extend M024 to emit a numeric without invalidating this entry. Document the mapping inline in the entry script body as part of the FR-11 contract.

2. **Word-band split for Tier A degenerate vs Tier B/C**. After the `tier_a_plus` verdict has been peeled off (Tier A+ branch handles 30–80 word + zero structural markers), the remaining verdicts are: `idea` (≤10 words) and `paragraph` (11–29 words and 80+ word with no structural marker fallback) → Tier A degenerate fast-path; `fragment` (structural markers OR ≥81 words) and `spec` (full spec shape) → Tier B/C passthrough. `paragraph` is the ambiguous case; the resolution is to inspect the word count: if `paragraph` AND word count ≤ 30 → Tier A degenerate; if `paragraph` AND word count > 30 → Tier B/C passthrough (the operator likely intended a more complex task; route to `orchestrator:specify`). Document this branching inline in the entry script body.

3. **Test-only seams**. The script exposes `--dispatch-stub <script>`, `--scratch-root <dir>`, `--config <path>`, `--no-prompt-mode <A|B|C>`, plus the `ORCH_DO_ENTRY_LOG` env-var override (mirrors P02's `ORCH_TIER_A_PLUS_LOG` pattern) for the JSONL `unit_close` record path. Production paths default to `.orchestrator/observability/dispatch-log.jsonl` (or its existing [M027](../../../../../milestones/M027/index.md) equivalent). The test seams DO NOT change the production CLI surface — every production-relevant CLI flag (`--task`, `--yes`) is documented in `commands/do.md`'s Output section.

4. **No new state machine / lock file** (CON-4). The entry script is a one-shot driver: it inspects the classifier output, picks one of four branches, optionally invokes one downstream script (build-context.sh / route-to-dispatch.sh), emits one JSONL `unit_close` record on the low-confidence-prompt branch, and exits. No lock file, no `.orchestrator/milestones/M###/` scaffolding write.

5. **CON-7 / D020 hygiene**. The entry script, the command document, and all four shape verifiers MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern in any prose, backticked code, comment, or output. Paraphrase as "scaffold-placeholder marker" wherever it must be referenced.

6. **MEM018 adapter discipline**. On the Tier A degenerate fast-path, the entry script's responsibility is bounded: write the dispatch payload + sidecar to disk, emit the `doing:` summary line, and return control. The agent runtime IS the adapter (MEM018) — production execution requires the agent to read the payload + execute. The `--dispatch-stub` test seam stands in for the agent runtime in test environments.

## Steps

1. **Inspect the existing classifier surface.** Read `scripts/intake/shape-detect.sh` (115+ lines after P02/T01) to confirm the verdict enum and confidence enum:

   ```bash
   bash scripts/intake/shape-detect.sh --input "fix typo"
   bash scripts/intake/shape-detect.sh --input "$(cat tests/m031-acceptance/fixtures/tier-a-plus-input.txt)"
   ```

   Expect two stdout lines per invocation: `input_shape=<verdict>` and `shape_classification=<high|low>`.

2. **Inspect the P02 router CLI surface.** Read `scripts/intake/route-to-dispatch.sh` (~390 lines after P02/T04). Confirm the `--verdict tier_a_plus --task <desc>` mode is present and that `--dispatch-stub <script>` is honored. The entry script will exec this surface verbatim for the Tier A+ branch.

3. **Inspect the P01 build-context.sh direct-mode driver.** Read the AD-11 sidecar shape:

   ```bash
   bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/p01-fixture-task-plan.md --out /tmp/test-payload.md --meta-out /tmp/test-sidecar.json
   ```

   The sidecar is a JSON object containing `{mem_count, total_tokens, profile, compression_applied, snip_applied}`. The entry script reads `mem_count` and `total_tokens` for the FR-12 stderr line.

4. **Author `scripts/intake/do-entry.sh`** (executable, bash 3.2). The script body in order:

   - **Header comment block** (≥40 lines) documenting:
     - The four-branch routing table (verbatim from the Description above).
     - The confidence-floor numeric mapping (`high → 1.0`, `low → 0.5`; A-2 closure).
     - The CLI surface — required `--task <description>`; optional `--yes`, `--config <path>`, `--dispatch-stub <script>`, `--scratch-root <dir>`, `--no-prompt-mode <A|B|C>`; plus the `ORCH_DO_ENTRY_LOG` env-var override.
     - A `# Key links (M031/P03):` comment block listing literal basenames `shape-detect.sh`, `route-to-dispatch.sh`, `build-context.sh`, `orchestrator-config-default.yml` so phase-level key-link must-haves resolve via grep on basename.
     - Bash 3.2 + CON-7 + AD-19 invariants.

   - **Argument parser**. Loop over `$@` matching the long flags above. Reject unknown flags via `usage` + `exit 64`. Require `--task` (or `usage`).

   - **Active config resolution** (4-layer precedence — mirrors P02's `tier_a_plus_prompt.sh` knob resolution):
     - if `--config <path>` supplied AND file exists → grep `^entry_routing_confidence_floor:` from that path.
     - else if `.orchestrator/config.yml` exists → grep from there.
     - else if `templates/orchestrator-config-default.yml` exists → grep from there.
     - else hardcoded fallback `0.7`.

     ```bash
     resolve_floor() {
       local _f
       if [ -n "${OPT_CONFIG:-}" ] && [ -f "$OPT_CONFIG" ]; then
         _f=$(grep -E '^entry_routing_confidence_floor:' "$OPT_CONFIG" | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
       fi
       if [ -z "${_f:-}" ] && [ -f .orchestrator/config.yml ]; then
         _f=$(grep -E '^entry_routing_confidence_floor:' .orchestrator/config.yml | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
       fi
       if [ -z "${_f:-}" ] && [ -f templates/orchestrator-config-default.yml ]; then
         _f=$(grep -E '^entry_routing_confidence_floor:' templates/orchestrator-config-default.yml | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
       fi
       printf '%s' "${_f:-0.7}"
     }
     ```

   - **Classifier invocation**. `bash scripts/intake/shape-detect.sh --input "$TASK" > "$tmp_classifier"`. Parse two key=value lines: `verdict=$(grep -E '^input_shape=' "$tmp_classifier" | head -1 | sed 's/^input_shape=//')` and `conf=$(grep -E '^shape_classification=' "$tmp_classifier" | head -1 | sed 's/^shape_classification=//')`.

   - **Confidence numeric mapping**. Map enum to numeric:

     ```bash
     case "$conf" in
       high) conf_num="1.0" ;;
       low)  conf_num="0.5" ;;
       *)    conf_num="0.0" ;;  # malformed → forces the low-confidence branch
     esac
     ```

   - **Floor comparison** (bash 3.2 — no floating-point arithmetic in `[ ... ]`; use awk):

     ```bash
     # passes_floor: 1 iff conf_num >= floor
     passes_floor=$(awk -v c="$conf_num" -v f="$FLOOR" 'BEGIN { print (c+0 >= f+0) ? 1 : 0 }')
     ```

   - **Branch table** (in order, first-match wins):

     ```bash
     # Branch 1: tier_a_plus verdict (regardless of confidence — P02 router has its own prompt)
     if [ "$verdict" = "tier_a_plus" ]; then
       run_tier_a_plus_handoff
       exit $?
     fi

     # Branch 2: low-confidence on a non-tier_a_plus verdict
     if [ "$passes_floor" -eq 0 ]; then
       run_lowconf_prompt
       exit $?
     fi

     # Branch 3: high-confidence Tier A degenerate (idea, or paragraph with word count <= 30)
     if [ "$verdict" = "idea" ]; then
       run_tier_a_degenerate
       exit $?
     fi
     if [ "$verdict" = "paragraph" ]; then
       _wc=$(printf '%s' "$TASK" | wc -w | tr -d ' ')
       if [ "${_wc:-0}" -le 30 ]; then
         run_tier_a_degenerate
         exit $?
       fi
       # long paragraph → falls through to Tier B/C
     fi

     # Branch 4: Tier B/C passthrough (fragment, spec, long paragraph, empty)
     run_tier_bc_passthrough
     exit $?
     ```

   - **`run_tier_a_plus_handoff` function**. Build argv for the P02 router and exec it:

     ```bash
     run_tier_a_plus_handoff() {
       local _argv
       _argv="--verdict tier_a_plus --task \"$TASK\""
       if [ "${OPT_YES:-0}" -eq 1 ]; then _argv="$_argv --yes"; fi
       if [ -n "${OPT_DISPATCH_STUB:-}" ]; then _argv="$_argv --dispatch-stub \"$OPT_DISPATCH_STUB\""; fi
       if [ -n "${OPT_SCRATCH_ROOT:-}" ]; then _argv="$_argv --scratch-root \"$OPT_SCRATCH_ROOT\""; fi
       eval "bash scripts/intake/route-to-dispatch.sh $_argv"
       return $?
     }
     ```

     (`eval` is acceptable inside a controlled-argument helper here; the alternative — manually building a positional argv array — is more bash 3.2-error-prone. Verifier MUST NOT trip on `eval` because the verifier-shape requirement is on the Truth Check command, not on internal helpers.)

   - **`run_tier_a_degenerate` function**. Generate a minimal task-plan fixture inline (a tmpfile holding the task description so build-context.sh's direct-mode has something to walk), invoke build-context.sh with Quick profile, read the sidecar, emit the FR-12 line, optionally invoke the dispatch stub:

     ```bash
     run_tier_a_degenerate() {
       local _tmp_plan _tmp_payload _tmp_sidecar
       _tmp_plan=$(mktemp -t do-entry-plan.XXXXXX)
       _tmp_payload=$(mktemp -t do-entry-payload.XXXXXX)
       _tmp_sidecar=$(mktemp -t do-entry-sidecar.XXXXXX)
       printf -- '---\ntype: task-plan\nname: "%s"\n---\n\n%s\n' "$TASK" "$TASK" > "$_tmp_plan"

       bash scripts/dispatch/build-context.sh --profile=quick --task-plan "$_tmp_plan" --out "$_tmp_payload" --meta-out "$_tmp_sidecar"
       local rc=$?
       if [ "$rc" -ne 0 ]; then
         printf 'do-entry: build-context.sh exited %d on tier_a_degenerate fast-path\n' "$rc" >&2
         rm -f "$_tmp_plan" "$_tmp_payload" "$_tmp_sidecar"
         return "$rc"
       fi

       # Parse mem_count + total_tokens from sidecar JSON via grep+sed (no jq dependency).
       local _N _X
       _N=$(grep -oE '"mem_count":[ ]*[0-9]+' "$_tmp_sidecar" | head -1 | sed -E 's/.*: *([0-9]+).*/\1/')
       _X=$(grep -oE '"total_tokens":[ ]*[0-9]+' "$_tmp_sidecar" | head -1 | sed -E 's/.*: *([0-9]+).*/\1/')
       _N="${_N:-0}"
       _X="${_X:-0}"

       printf 'doing: %s — knowledge: %s MEMs / %s tokens\n' "$TASK" "$_N" "$_X" >&2

       # Optional test-stub invocation. Production: agent runtime takes over (MEM018).
       if [ -n "${OPT_DISPATCH_STUB:-}" ]; then
         bash "$OPT_DISPATCH_STUB" "tier_a_degenerate" "$TASK" "$_tmp_payload" "$_tmp_sidecar"
         local _rc2=$?
         rm -f "$_tmp_plan" "$_tmp_payload" "$_tmp_sidecar"
         return "$_rc2"
       fi

       # In production we leave the payload + sidecar on disk for the agent
       # runtime to consume. Cleanup is the runtime's job.
       return 0
     }
     ```

   - **`run_tier_bc_passthrough` function**. Pick the downstream surface name based on the verdict + length and emit one stderr line; exit 0:

     ```bash
     run_tier_bc_passthrough() {
       local _surface="orchestrator:specify"
       case "$verdict" in
         spec|fragment) _surface="orchestrator:specify" ;;
         paragraph)     _surface="orchestrator:specify" ;;  # long paragraph
         empty)         _surface="orchestrator:evaluate" ;;
         *)             _surface="orchestrator:specify" ;;
       esac
       printf 'route=tier_bc passthrough=%s\n' "$_surface" >&2
       printf 'do-entry: this task is too large for a single dispatch — invoke %s in your next turn.\n' "$_surface" >&2
       return 0
     }
     ```

   - **`run_lowconf_prompt` function**. Render the Tier A vs Tier B question and accept a response (interactive `read` OR test-only `--no-prompt-mode <A|B|C>` bypass). Emit a JSONL `unit_close` record with `chosen_shape: <A|B|C>` to `ORCH_DO_ENTRY_LOG` (default `.orchestrator/observability/dispatch-log.jsonl`). Then dispatch to the chosen branch:

     ```bash
     run_lowconf_prompt() {
       printf '\n' >&2
       printf 'Classifier confidence is below the entry_routing_confidence_floor (%s).\n' "$FLOOR" >&2
       printf '\n' >&2
       printf 'Is this a small task (Tier A — single dispatch with knowledge inject) or a larger task (Tier B — full SDD flow)?\n' >&2
       printf '  (A) Tier A — proceed to fast-path dispatch (Quick profile)\n' >&2
       printf '  (B) Tier B — pass through to orchestrator:specify\n' >&2
       printf '  (C) Cancel — abort this entry\n' >&2
       printf '\n' >&2

       local _resp
       if [ -n "${OPT_NO_PROMPT_MODE:-}" ]; then
         _resp="$OPT_NO_PROMPT_MODE"
       else
         # Interactive: 60s timeout; empty/EOF/timeout → C cancel default (mirrors AD-20).
         _resp=$(read -r -n 1 -t 60 _r && printf '%s' "$_r" || printf 'C')
       fi
       _resp=$(printf '%s' "$_resp" | tr 'a-z' 'A-Z')
       case "$_resp" in
         A|B|C) : ;;
         *)     _resp="C" ;;
       esac

       emit_unit_close_lowconf "$_resp"

       case "$_resp" in
         A) run_tier_a_degenerate ;;
         B) run_tier_bc_passthrough ;;
         C) printf 'do-entry: aborted by operator\n' >&2; return 2 ;;
       esac
     }

     emit_unit_close_lowconf() {
       local _shape="$1"
       local _log="${ORCH_DO_ENTRY_LOG:-.orchestrator/observability/dispatch-log.jsonl}"
       local _ts
       _ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
       mkdir -p "$(dirname "$_log")" 2>/dev/null || true
       printf '{"record_type":"unit_close","granularity":"task","unitId":"do-entry/lowconf","milestone":"do-entry","phase":"lowconf","task":"%s","outcome":"prompted","completed_at":"%s","verdict":"%s","conf":"%s","chosen_shape":"%s","source":"do-entry","timestamp":"%s"}\n' "$TASK" "$_ts" "$verdict" "$conf" "$_shape" "$_ts" >> "$_log"
     }
     ```

   - **`set -u`** at the top; explicit `set -e` is intentionally NOT used (each branch has its own rc handling and we want to control non-zero propagation).

5. **Author `commands/do.md`** (≥60 lines). Required sections (per MEM012):
   - YAML frontmatter with `description: "Use when invoking a one-shot task — runs the M024 classifier, dispatches a Tier A degenerate task with Quick-profile knowledge inject, hands Tier A+ tasks to the P02 research → plan → build chain, or routes Tier B/C tasks to orchestrator:specify."`.
   - `# orchestrator:do <task>` title.
   - `## Prerequisites / State Check` — `.orchestrator/` exists; otherwise advise running `orchestrator:init`.
   - `## Core Workflow` — describe the four branches (verbatim from the Description routing table) plus the confidence-floor mapping.
   - `## Output` — describe the FR-12 stderr summary line shape `doing: <task> — knowledge: <N> MEMs / <X> tokens`.
   - `## Idempotency` — describe that the entry is one-shot (no state machine, no resume).
   - `## Error Handling` — non-zero exit reasons (build-context.sh failure, P02 router failure, operator cancel at low-confidence prompt).
   - `## Referenced Scripts/Templates` — list `scripts/intake/do-entry.sh`, `scripts/intake/shape-detect.sh`, `scripts/intake/route-to-dispatch.sh`, `scripts/dispatch/build-context.sh`, `templates/orchestrator-config-default.yml`.
   - The body MUST contain the literal tokens `orchestrator:do`, `tier_a_plus`, `do-entry.sh`, `Referenced Scripts`.

6. **Author `tools/verify/m031-p03-do-md-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `commands/do.md` exists and is ≥ 60 lines.
   - Assert the file contains the literal substrings `orchestrator:do`, `tier_a_plus`, `do-entry.sh`, `Referenced Scripts`.
   - Assert YAML frontmatter starts at line 1 (`head -1 commands/do.md` matches `^---$`).
   - Output: a single final stdout line `SUMMARY: m031-p03-do-md-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m031-p03-do-entry-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/do-entry.sh` exists, is executable, ≥ 200 lines.
   - Assert the file contains literal substrings: `tier_a_plus`, `shape-detect.sh`, `route-to-dispatch.sh`, `build-context.sh`, `entry_routing_confidence_floor`, `--task`, `--yes`, `--no-prompt-mode`, `--dispatch-stub`, `--scratch-root`, `--config`, `chosen_shape`, `MEMs`, `tokens`.
   - Assert the script does NOT contain `declare -A` (MEM001) and does NOT contain `<(` (process substitution forbidden by MEM001).
   - Assert the script does NOT contain `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` (CON-4).
   - Output: a single final stdout line `SUMMARY: m031-p03-do-entry-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Author `tools/verify/m031-p03-fastpath-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/do-entry.sh` contains the literal substring `build-context.sh --profile=quick` (the FR-12 fast-path invocation).
   - Assert the file contains the literal substring `doing:` followed somewhere later by `MEMs` and `tokens` (FR-12 stderr summary line shape).
   - Assert the file contains the literal substring `mem_count` AND `total_tokens` (sidecar field reads).
   - Assert the file contains a function definition matching `run_tier_a_degenerate` (grep `^run_tier_a_degenerate()` or `^run_tier_a_degenerate ()`).
   - Output: a single final stdout line `SUMMARY: m031-p03-fastpath-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

9. **Author `tools/verify/m031-p03-passthrough-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/do-entry.sh` contains the literal substrings `orchestrator:specify` AND `orchestrator:evaluate` (FR-13 passthrough surface names).
   - Assert the file contains the literal substring `route=tier_bc` (the passthrough stderr line key).
   - Assert the file contains a function definition matching `run_tier_bc_passthrough` (grep `^run_tier_bc_passthrough()` or `^run_tier_bc_passthrough ()`).
   - Output: a single final stdout line `SUMMARY: m031-p03-passthrough-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

10. **Run the four shape verifiers locally to confirm exit 0**:

    ```bash
    bash tools/verify/m031-p03-do-md-shape.sh
    bash tools/verify/m031-p03-do-entry-shape.sh
    bash tools/verify/m031-p03-fastpath-shape.sh
    bash tools/verify/m031-p03-passthrough-shape.sh
    ```

11. **Sanity-smoke the entry script** against three short test inputs (NOT acceptance tests — those land in T02; this is just driver-level sanity):

    ```bash
    bash scripts/intake/do-entry.sh --task "fix typo"             # expect: tier_a_degenerate fast-path; doing: ... line on stderr
    bash scripts/intake/do-entry.sh --task "$(cat tests/m031-acceptance/fixtures/tier-a-plus-input.txt)" --yes  # expect: tier_a_plus handoff to route-to-dispatch.sh
    bash scripts/intake/do-entry.sh --task "$(printf 'A %.0s' {1..200})"  # expect: tier_bc passthrough; route=tier_bc line
    ```

    These are sanity smokes only — the entry script may exit non-zero in step 11.1 if `build-context.sh --profile=quick --task-plan <plan>` requires more than the inline-generated minimal plan provides (e.g., a milestone tree). If so, simply note the dependency for the T02 fixture stub and do NOT block T01 on it — T01's deliverable contract is the script body + the four shape verifiers, NOT runtime exit 0 against a synthetic plan.

## Must-Haves

This task addresses the following Must-Haves from `P03-PLAN.md`:
- "`commands/do.md` exists with YAML frontmatter ... documenting the universal entry skill" (Truth #1; Check via `m031-p03-do-md-shape.sh`)
- "`scripts/intake/do-entry.sh` exists, is executable, and implements the FR-10 / FR-11 / FR-12 / FR-13 contract" (Truth #2; Check via `m031-p03-do-entry-shape.sh`)
- "the high-confidence Tier A degenerate fast-path branch invokes `bash scripts/dispatch/build-context.sh --profile=quick ...` AND emits exactly one stderr line of shape `doing: <task> — knowledge: <N> MEMs / <X> tokens`" (Truth #3; Check via `m031-p03-fastpath-shape.sh`)
- "`scripts/intake/do-entry.sh` does NOT acquire any auto-loop lock, does NOT write any `.orchestrator/milestones/M###/` scaffolding, and does NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`" (Truth #4; Check via `m031-p03-passthrough-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p03-do-md-shape.sh
```

```bash
bash tools/verify/m031-p03-do-entry-shape.sh
```

```bash
bash tools/verify/m031-p03-fastpath-shape.sh
```

```bash
bash tools/verify/m031-p03-passthrough-shape.sh
```

## Notes

- Each shape verifier MUST emit `SUMMARY: <script-name> pass=N fail=M` as its final stdout line and exit 0 iff `fail=0` — the M031 P01/P02 convention reused.
- D020 / CON-7 token hygiene: comments and prose in the new files MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase as "scaffold-placeholder marker" or escape.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution `<(...)`, no `$()` containing pipes inside conditionals.
- `eval` is acceptable inside the `run_tier_a_plus_handoff` helper because the input is fully controlled by the script's own argument parser (no operator-supplied unquoted strings reach it). The verifier does NOT scan for `eval`; the AD-19 single-script-file shape applies to the Truth `Check:` command, not to the implementation internals.
- The entry script writes the JSONL `unit_close` record with `mkdir -p "$(dirname "$_log")"` to handle the case where `.orchestrator/observability/` does not yet exist on a fresh project — this is the only allowed write outside the test-controlled tmp roots, and it lands under the `.orchestrator/observability/` permissive prefix from P01/P02 scope-guard carve-outs.
- The script's confidence-floor numeric mapping (`high → 1.0` / `low → 0.5`) closes A-2 from the spec (M024 today emits enum confidence; future demand can extend M024 to emit a numeric without breaking this entry — the mapping is a forward-compatible adapter).
- **Real-app smoke test pending** (plan-time discipline rule 5): T01's verifiers gate the script-body shape, not its runtime behavior against the production `build-context.sh`. T02 ships SC-7 / SC-8 acceptance tests that exercise runtime behavior end-to-end via the dispatch stub seam. Production-runtime confirmation (entry script invoked from a CC slash-command surface in a live consumer project) is the [M033](../../../../../milestones/M033/index.md) onboarding-experience milestone's job; T01 + T02 together verify the script's contract against the test seam.

## Inputs

### From Previous Tasks

(No upstream tasks within P03; T01 is the entry point.)

### From Previous Phases

- **P01: `scripts/dispatch/build-context.sh` direct-mode driver.** Invoked as `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <plan> --out <payload> --meta-out <sidecar>`. Emits AD-11 5-key sidecar JSON to `<sidecar>`: `{"mem_count":N,"total_tokens":X,"profile":"quick","compression_applied":<bool>,"snip_applied":<bool>}`. Direct-mode bypasses milestone/phase/task derivation when `--task-plan` is supplied (the file may be any task-plan-shaped markdown — the driver does not require milestone scaffolding to exist).
- **P01: `templates/orchestrator-config-default.yml`.** Declares `entry_routing_confidence_floor: 0.7` (P00 pinned default). Read via direct YAML grep; the canonical `read-config.sh` `VALID_KEYS` list does not yet whitelist this knob (forwarded from P02 to P04 / [M032](../../../../../milestones/M032/index.md) per the P02 forward-looking notes).
- **P02: `scripts/intake/shape-detect.sh`.** Emits `input_shape=<verdict>` + `shape_classification=<high|low>` to stdout. Verdict enum is `idea | paragraph | tier_a_plus | fragment | spec | empty`. T01 invokes this to obtain the routing verdict.
- **P02: `scripts/intake/route-to-dispatch.sh`.** Accepts `--verdict tier_a_plus --task <description> [--yes] [--session-id <id>] [--scratch-root <dir>] [--dispatch-stub <script>]`. Chains research → operator-prompt → plan → build dispatches. T01 execs this surface verbatim for the `tier_a_plus` branch.

### From Disk (Pre-existing)

- `commands/dispatch.md` — read for the post-FR-4 Quick row phrasing; not modified.
- `commands/evaluate.md` — read for the existing tier-routing section; not modified (P04's drift-fix scope, not T01's).
- `references/tier-definitions.md` — read for the existing Tier A description; not modified.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **CON-3 / AD-2** (M024 is the single routing source): T01 MUST NOT introduce a parallel routing implementation. The entry script invokes `shape-detect.sh` and consumes its existing two-line output contract.
- **CON-4 / DC-4** (no new state machines): the entry script makes additive driver invocations only — no state-derivation rule, no lock file, no milestone scaffolding write. The only persistent write is the JSONL `unit_close` record on the low-confidence-prompt branch, which lands under `.orchestrator/observability/` (permissive carve-out from P01/P02 scope-guard).
- **CON-7 / D020 hygiene**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file (script body, command document, verifiers).
- **NG-6** (one-shot per command): the entry is a single-shot driver — no REPL, no daemon, no resume.
- **SC-12 scope-guard**: T01 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. The M031-namespaced prefix `m031-p03-` avoids collision with [M030](../../../../../milestones/M030/index.md)'s `p02-*` and M031's `m031-p01-*` / `m031-p02-*` verifiers in the shared tree.
- **No edits to `scripts/intake/shape-detect.sh`** in T01 (P02 owned).
- **No edits to `scripts/intake/route-to-dispatch.sh`** in T01 (P02 owned).
- **No edits to `scripts/intake/paragraph-classify.sh`** in T01 (P02 owned).
- **No edits to `scripts/dispatch/build-context.sh`** in T01 (P01 owned).
- **No edits to `templates/orchestrator-config-default.yml`** in T01 (P01 owned).
- **No edits to `commands/dispatch.md` / `commands/evaluate.md` / `references/tier-definitions.md`** in T01 (P01 / P04 owned).

## Expected Output

After T01 completes:

1. `commands/do.md` exists, ≥ 60 lines, contains the literal `orchestrator:do` AND `tier_a_plus` AND `do-entry.sh` AND `Referenced Scripts` tokens. YAML frontmatter at top.
2. `scripts/intake/do-entry.sh` exists, executable, ≥ 200 lines, implements the four-branch routing table with the documented CLI surface (`--task`, `--yes`, `--config`, `--dispatch-stub`, `--scratch-root`, `--no-prompt-mode`, `ORCH_DO_ENTRY_LOG` env override).
3. Four shape verifiers exist under `tools/verify/m031-p03-*.sh` (do-md-shape, do-entry-shape, fastpath-shape, passthrough-shape), executable, exit 0 each.
4. No edits to any P01- or P02-owned file (`build-context.sh`, `shape-detect.sh`, `route-to-dispatch.sh`, etc.).
5. No new files under `tests/m031-acceptance/` (T02's job).
6. No new files under `tools/verify/` matching `m031-p03-test-*` or `m031-p03-phase-suite` or `m031-p03-scope-guard` (T02 / T03's jobs).

T01 leaves the universal entry's authoring surface + driver script on disk. T02 builds on this by shipping the SC-7 + SC-8 acceptance tests that exercise the entry script end-to-end via the `--dispatch-stub` seam.
