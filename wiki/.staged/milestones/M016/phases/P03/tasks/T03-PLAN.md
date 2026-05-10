---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M016"
name: "Add prohibited-patterns section to dispatch payload via build-context.sh"
depends_on: []
---

## Prerequisites

P01 delivered `ANTIPATTERNS.md` with AP-004. P02 delivered `scripts/verify/run-suite.sh`. The dispatch payload is assembled by `scripts/dispatch/build-context.sh`, which delegates section rendering to `scripts/dispatch/lib/section-handlers.sh`. The constraints section is rendered by `handle_template()` in section-handlers.sh.

## Description

Add a "Prohibited inline bash patterns" subsection to the dispatch payload's Constraints section. This section appears in every task dispatch payload, reminding subagents not to use Class A anti-patterns. The content references `ANTIPATTERNS.md` AP-004 and provides the three pattern classes with their wrapper alternatives.

The change is localized to `scripts/dispatch/lib/section-handlers.sh` in the `handle_template()` function's `constraints` case. The constraints section currently emits four bullet points (verification criteria, duration budget, dispatch budget, budget enforcement). We add a fifth section block after these bullets.

## Steps

### Step 1: Modify the handle_template constraints case in section-handlers.sh

Open `scripts/dispatch/lib/section-handlers.sh` and find the `handle_template()` function (starts at line 178). The `constraints` case currently looks like:

```bash
    constraints|Constraints|CONSTRAINTS)
      printf '## Constraints\n\n'
      printf -- '- **Verification Criteria**: %s\n' "${SH_VERIFICATION_CRITERIA:-See phase plan must-haves}"
      printf -- '- **Duration Budget**: %s\n' "${SH_DURATION_BUDGET:-2h}"
      printf -- '- **Dispatch Budget**: %s\n' "${SH_DISPATCH_BUDGET:-3}"
      printf -- '- **Budget Enforcement**: %s\n' "${SH_BUDGET_ENFORCEMENT:-warn}"
      ;;
```

Add the prohibited-patterns block after the budget enforcement line:

```bash
    constraints|Constraints|CONSTRAINTS)
      printf '## Constraints\n\n'
      printf -- '- **Verification Criteria**: %s\n' "${SH_VERIFICATION_CRITERIA:-See phase plan must-haves}"
      printf -- '- **Duration Budget**: %s\n' "${SH_DURATION_BUDGET:-2h}"
      printf -- '- **Dispatch Budget**: %s\n' "${SH_DISPATCH_BUDGET:-3}"
      printf -- '- **Budget Enforcement**: %s\n' "${SH_BUDGET_ENFORCEMENT:-warn}"
      printf '\n### Prohibited inline bash patterns\n\n'
      printf 'The following patterns trigger Claude Code safety prompts and MUST NOT\n'
      printf 'appear in Bash tool calls. See AP-004 in ANTIPATTERNS.md for details.\n\n'
      printf -- '- **Command substitution**: Do not use $(cmd) or backtick substitution.\n'
      printf -- '  Use --output-file flags or omit dynamic values (e.g., omit --completed_at).\n'
      printf -- '- **Brace expansion**: Do not use {a,b} patterns.\n'
      printf -- '  Pass explicit arguments instead.\n'
      printf -- '- **Compound chains**: Do not chain commands with && || ; or pipes.\n'
      printf -- '  Use wrapper scripts (e.g., bash scripts/verify/run-suite.sh).\n'
      ;;
```

This adds 8 `printf` lines. The content is static (no dynamic values) so there is no Bash 3.2 concern.

### Step 2: Verify the change does not break payload assembly

Run `build-context.sh` in a test mode to confirm it still assembles payloads correctly. Since we cannot easily run it against live milestone data in the task context, the verification scripts (T04) will test for the prohibited-patterns content in a generated payload.

### Step 3: Verify Bash 3.2 compatibility

Run syntax check on the modified file:
```
bash -n scripts/dispatch/lib/section-handlers.sh
```

Must exit 0 with no output.

## Must-Haves

- Dispatch payload includes a "Prohibited inline bash patterns" section referencing ANTIPATTERNS.md
- The prohibited-patterns section lists all three Class A pattern classes with remediation hints
- `section-handlers.sh` passes `bash -n` after modification

## Verification

```
bash scripts/verify/m016-p03-payload-prohibited.sh
```

Must print `PASS:` and exit 0. Note: the verify script is created in T04.

## Inputs

### From Disk (Pre-existing)
- scripts/dispatch/lib/section-handlers.sh — contains `handle_template()` function at line 178. The `constraints` case (lines 181-187) emits a `## Constraints` header followed by four bullet points. The function is called by `dispatch_section_handler()` (line 438) when the recipe source is `template`. Key API: `handle_template(orch_root, milestone, phase, task, section_name)`. Reads env vars `SH_VERIFICATION_CRITERIA`, `SH_DURATION_BUDGET`, `SH_DISPATCH_BUDGET`, `SH_BUDGET_ENFORCEMENT`.
- scripts/dispatch/build-context.sh — calls `dispatch_section_handler` which routes `template` sources to `handle_template()`. The constraints section is defined in `templates/context-recipe.yaml` as `constraints: { source: template, priority: optional, order: 30 }`.
- ANTIPATTERNS.md — AP-004 documents the three Class A pattern classes. The prohibited-patterns section references this entry by ID.

## Constraints

- Only modify the `handle_template()` function in section-handlers.sh. Do NOT modify `build-context.sh` directly.
- The added content must be static printf statements — no dynamic values, no command substitution.
- Bash 3.2 compatible.
- The section must reference AP-004 in ANTIPATTERNS.md by name so subagents can look it up if needed.

## Expected Output

- scripts/dispatch/lib/section-handlers.sh modified: `handle_template()` constraints case expanded with prohibited-patterns subsection.
- Every dispatch payload now includes the prohibited-patterns section in its Constraints block.
- No other files modified.
