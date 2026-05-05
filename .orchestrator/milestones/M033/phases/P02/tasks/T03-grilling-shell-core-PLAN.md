---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M033"
name: "scripts/lifecycle/grilling-shell.sh core module — ask_one API + recommendation-not-interrogation (FR-17 / CON-5)"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/` exists.
- `tools/verify/` exists.
- `scripts/lifecycle/grilling-shell.sh` does NOT yet exist — verified by `[ ! -f scripts/lifecycle/grilling-shell.sh ]`.
- Spec context: FR-17 mandates a uniform conversational-shell module with API `ask_one <question> <recommendation> [<context-file>]`; CON-5 mandates sequential-never-batched presentation. The module is sourced by P03/P04/P05 calling commands (FR-3 / FR-9 / FR-10 / FR-13). T03 ships the **core module** — `ask_one` API surface, sequential prompting, recommendation-not-interrogation framing, code-first speculation cap. T04 layers the FR-18 glossary writer + MIT-007 contradiction-detection wiring on top.
- The brief's "Adopted External Pattern: relentless grilling protocol" specifies four rules: (1) sequential never batched (one question at a time, await answer); (2) code-first speculation cap (read project state before asking what reading would resolve); (3) inline doc updates (write into `wiki/glossary.md` as terms resolve — T04 territory); (4) surface contradictions live (T04 territory); plus recommendation-not-interrogation (recommendation named first).

## Description

T03 ships `scripts/lifecycle/grilling-shell.sh`, the FR-17 reusable conversational-shell module. The module exposes a single uniform public function `ask_one <question> <recommendation> [<context-file>]` invokable from sourced bash (calling commands `source` the module, then call `ask_one` directly). The function:

1. Names the recommendation FIRST (recommendation-not-interrogation framing — `recommendation: <value>` printed before the question).
2. Prints the question text on a single line (sequential — one question at a time; never batched).
3. Reads exactly one line of stdin via `read -r` (one keystroke for accept/reject; multi-character explicit answer also supported).
4. Resolves the answer per the documented one-keystroke contract: `Y/y/<enter>` accepts the recommendation; `n/N` requests an alternative (re-prompts for explicit answer); any other input is treated as the explicit operator-supplied answer.
5. Echoes the resolved answer on a single line prefixed `answer: <value>` (the load-bearing token for downstream tests).
6. Returns 0 on success.

T03 ships the **core API + framing**. T04 layers on:
- The FR-18 glossary inline-update writer (private helper invoked from `ask_one` when a domain term resolves).
- The MIT-007 contradiction-detection wiring (active whenever `[<context-file>]` is non-empty).
- The fenced `# >>> contradiction-pairs >>>` and `# >>> glossary-triggers >>>` SSOT blocks.
- The SC-11 acceptance script.

T03 establishes the function shape, the recommendation-not-interrogation framing, the sequential constraint, and the empty-`[<context-file>]` short-circuit.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution, no `$(...)` containing pipes. The module is sourceable (no top-level `set -e -u -o pipefail` that would corrupt the caller's settings — only set them inside functions or trap them).

**Sourcing semantics:** The module MUST work when `source`-ed — it MUST NOT call `exit` from `ask_one` (would kill the caller). All non-success paths use `return <code>`. Top-level code (outside function definitions) is limited to function definitions and the fenced SSOT blocks.

**Code-first speculation cap (brief Adopted External Pattern rule 2):** T03 documents the convention via a comment block at the top of the file: calling commands MUST read project state (manifests, directory structure, prior answers) before invoking `ask_one`. The `ask_one` function itself does not enforce this (it is a library function with no opinion on caller state); the convention is documented for P03/P04/P05 dispatched agents, and the verifier asserts the convention block exists.

## Steps

1. **Author `scripts/lifecycle/grilling-shell.sh`** (≥200 lines after T04 layers on; T03 ships ≥120 lines of core API + framing + comments).

   1a. **Header comment block.** Hashbang `#!/usr/bin/env bash` (informational — module is sourced, not executed); brief block naming the script (FR-17 / CON-5), the spec reference (M033 / 036-project-onboarding-experience), and the four-rule grilling protocol from the brief's Adopted External Pattern.

   1b. **`# >>> grilling-protocol-rules >>>` SSOT block** (fenced, comment-only). Documents the four rules verbatim:

   ```bash
   # >>> grilling-protocol-rules >>>
   # 1. Sequential never batched (CON-5 hard architectural invariant).
   # 2. Code-first speculation cap — calling commands MUST read project
   #    state (manifests, directory structure, prior answers) before
   #    invoking ask_one. ask_one is a library function; calling
   #    commands enforce this convention.
   # 3. Inline doc updates — when ask_one resolves a domain term, the
   #    glossary writer fires immediately (T04 deliverable).
   # 4. Surface contradictions live — when ask_one is invoked with a
   #    [<context-file>] the contradiction detector fires before
   #    returning success (T04 deliverable per MIT-007).
   # Plus: recommendation-not-interrogation — recommendation named
   # first, then the question asks for confirm-or-correct.
   # <<< grilling-protocol-rules <<<
   ```

   1c. **Reserved fenced blocks for T04.** Insert empty fenced blocks that T04 will populate:

   ```bash
   # >>> contradiction-pairs >>>
   # T04: populates with closed contradiction-table entries.
   # <<< contradiction-pairs <<<

   # >>> glossary-triggers >>>
   # T04: populates with closed glossary-trigger key set.
   # <<< glossary-triggers <<<
   ```

   The presence of these markers in T03 is documented as a stub — T03's verifier checks they exist (so T04's verifier can layer assertions on top without restructuring).

   1d. **`ask_one` function.** ≥40 lines.

   ```bash
   ask_one() {
     local question="${1:-}"
     local recommendation="${2:-}"
     local context_file="${3:-}"

     if [ -z "$question" ] || [ -z "$recommendation" ]; then
       echo "ask_one: question and recommendation are required" >&2
       echo "usage: ask_one <question> <recommendation> [<context-file>]" >&2
       return 2
     fi

     # Recommendation-not-interrogation framing — recommendation FIRST
     printf 'recommendation: %s\n' "$recommendation"
     printf '%s [Y/n/<answer>]: ' "$question"

     local input=""
     # Sequential read of one line (CON-5)
     IFS= read -r input || input=""

     local resolved=""
     case "$input" in
       ""|Y|y) resolved="$recommendation" ;;
       N|n)
         printf 'enter explicit answer: ' >&2
         IFS= read -r resolved || resolved=""
         if [ -z "$resolved" ]; then
           echo "no explicit answer provided" >&2
           return 2
         fi
         ;;
       *) resolved="$input" ;;
     esac

     # T04: contradiction-detection wiring fires here when context_file
     #      is non-empty. T03 emits a placeholder no-op:
     if [ -n "$context_file" ]; then
       _grilling_check_contradiction "$resolved" "$context_file" || return $?
     fi

     # T04: glossary-trigger writer fires here on matching question text.
     # T03 emits a placeholder no-op (T04 layers _grilling_glossary_update).
     _grilling_glossary_update "$question" "$resolved"

     printf 'answer: %s\n' "$resolved"
     return 0
   }
   ```

   1e. **Stub helper functions.** T03 ships no-op stubs that T04 replaces:

   ```bash
   _grilling_check_contradiction() {
     # T04 deliverable — MIT-007 wiring. T03: no-op return 0.
     local _resolved="$1"
     local _context_file="$2"
     return 0
   }

   _grilling_glossary_update() {
     # T04 deliverable — FR-18 inline-update writer. T03: no-op.
     local _question="$1"
     local _resolved="$2"
     return 0
   }
   ```

   These stubs ensure `ask_one` works end-to-end at T03 (testable) without yet implementing T04's logic. T04 replaces the stub bodies with real logic.

   1f. **Sourceability guard.** End of file:

   ```bash
   # Module-level guard: this file is meant to be sourced, not executed.
   # If executed directly, print the API surface and exit informationally.
   if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
     echo "scripts/lifecycle/grilling-shell.sh — FR-17 conversational-shell module"
     echo "API: ask_one <question> <recommendation> [<context-file>]"
     echo "usage: source this file from a calling command, then invoke ask_one."
   fi
   ```

2. **Author `tools/verify/m033-p02-grilling-shell-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/grilling-shell.sh` exists.
   - The file is sourceable: a smoke-source (`source scripts/lifecycle/grilling-shell.sh` in a sandboxed bash) does not exit non-zero.
   - The `ask_one` function is defined: `declare -F ask_one` after sourcing reports the function exists.
   - Required tokens appear via `grep -F`: `ask_one`, `recommendation:`, `answer:`, `CON-5`, `MIT-007` (in the comment block), `FR-17`, `grilling-protocol-rules`, `contradiction-pairs`, `glossary-triggers`.
   - **Functional smoke test:** create a sandboxed bash subshell that sources the module and invokes `ask_one 'What is your stack?' 'web-saas'` against simulated stdin (`printf 'y\n'`); assert stdout contains `recommendation: web-saas` AND `answer: web-saas` AND that `recommendation:` appears before `answer:` (recommendation-not-interrogation ordering).
   - **Sequential-not-batched gate:** assert no `for ` loop or `while ` loop appears that wraps multiple `ask_one` invocations without intervening `read` (lint-style check via grep — at most a heuristic, but adequate for the SSOT-shape assertion). Implementation: assert `ask_one` is defined as a single function (not a loop wrapper); the per-invocation sequential semantics are validated by the SC-11 acceptance script in T04.
   - Emits PASS/SUMMARY lines per MEM001.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/lifecycle/grilling-shell.sh` exists, is sourceable, defines `ask_one` with the documented signature and recommendation-not-interrogation framing.

This task creates these P02 phase artifacts:
- Module: `scripts/lifecycle/grilling-shell.sh` (FR-17 core API + framing + reserved T04 SSOT block markers + stub helper functions).
- Verifier: `tools/verify/m033-p02-grilling-shell-shape.sh` (shape + sourceability + functional smoke).

## Verification

```bash
bash tools/verify/m033-p02-grilling-shell-shape.sh
```

## Inputs

### From Previous Tasks

None. T03 has no intra-phase prerequisites; runs in parallel with T01 and T02.

### From Disk (Pre-existing)

- `scripts/lifecycle/` directory.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- **Sourceability:** the module is sourced, not executed. NO top-level `set -e -u -o pipefail` (would corrupt caller settings). NO top-level `exit` calls. All non-success paths use `return`.
- **CON-5 sequential-never-batched** is a hard architectural invariant. `ask_one` reads exactly one line per invocation; multi-question batching is forbidden. Calling commands invoking `ask_one` in a loop without awaiting answers is a CON-5 violation (cannot be enforced from the library; documented in `# >>> grilling-protocol-rules >>>` block).
- The `recommendation:` and `answer:` line prefixes are load-bearing. Use `printf` (not `echo -e`).
- The fenced SSOT blocks (`grilling-protocol-rules`, `contradiction-pairs`, `glossary-triggers`) MUST exist in T03 (T04 populates `contradiction-pairs` and `glossary-triggers` content; T03 ships empty stubs with the comment markers in place).
- T03 ships **no-op stubs** for `_grilling_check_contradiction` and `_grilling_glossary_update`; T04 replaces the stub bodies with real logic. T03's verifier MUST NOT assert the stub bodies are non-trivial (it asserts the names exist; T04's verifier asserts the bodies).
- T03 MUST NOT touch `scripts/util/jsonl-event-emitter.sh` (T01 deliverable), `scripts/util/start-state-markers.sh` (T02 deliverable), `scripts/lifecycle/start.sh` (T02 deliverable territory for resume-extension), or any P03/P04/P05 surface.
- Verifier scripts use single-script-file shape per AD-19.

## Expected Output

After T03 completes:
- `scripts/lifecycle/grilling-shell.sh` exists, is sourceable, defines `ask_one`.
- `tools/verify/m033-p02-grilling-shell-shape.sh` exists, is executable, exits 0 with `SUMMARY: m033-p02-grilling-shell-shape.sh pass=N fail=0`.
- A summary file at `.orchestrator/milestones/M033/phases/P02/tasks/T03-grilling-shell-core-SUMMARY.md` documents the deliverables.

## Notes

T03 ships the **core API**. T04 ships the **load-bearing logic** (MIT-007 contradiction-detection + FR-18 glossary writer). The split is deliberate: T03 establishes a stable, sourceable module + verifier shape that T04 layers on without restructuring. This pattern follows the M030/P00 staged-delivery precedent and lets T04 focus on the high-risk wiring (MIT-007 + FR-18) without re-deriving the function contract.

The stub helper functions (`_grilling_check_contradiction`, `_grilling_glossary_update`) are deliberate scaffolding. After T04, the stubs are replaced with real logic, but the shape verifier T03 ships continues to pass (T03's verifier asserts only the function-name-and-signature shape, not the body content).

The `code-first speculation cap` rule (brief Adopted External Pattern rule 2) is a calling-command discipline — `ask_one` itself is a library function with no opinion on caller state. T03 documents the rule in the SSOT comment block; P03/P04/P05 dispatched agents enforce the rule in their own task plans by reading project state before invoking `ask_one`. The grilling-shell verifier does NOT assert this enforcement (it would be cross-cutting — out of scope for a shape verifier).
