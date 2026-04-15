---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M005"
name: "Command wiring — auto pre-flight, evaluate init, known limitations"
depends_on: ["T02", "T03"]
---

## Description

Wire the generator/writer/drift-detector trio into the orchestrator's
user-facing commands:

1. **`commands/auto.md`** — rewrite Section 4 ("Permission Pre-Flight")
   per FR-6 so auto mode calls `generate-permissions.sh` +
   `write-permissions.sh` + `check-permissions.sh` instead of copying
   `templates/claude-settings.json` directly. Also add a new "Known
   Limitations: Harness Safety Heuristics" subsection per AD-19 that
   documents the residual prompt class no allow list can eliminate and
   points at the script-file verification shape as the remedy.

2. **`commands/evaluate.md`** — add a "Permission Generation on Init"
   step after the Tier B/C scaffolding step (FR-7). When
   `autonomy.generate_on_init` is true (default) and the project is Tier
   B or C, run generate → write during evaluate so fresh projects are
   unattended-ready before the first `auto` invocation.

This task is **entirely documentation** — no script changes. But it is
the task that makes the P07 feature *usable*. Without T04, the scripts
from T02/T03 exist but nothing calls them.

Architectural decisions that constrain this task:
- **AD-7**  Never document `bypassPermissions` as a valid mode. The docs
  show only `minimal | standard | full`.
- **AD-13** Document that user-authored files are merged additively and
  never overwritten. The pre-flight's `USER_AUTHORED` branch invokes the
  writer (which detects user-authored files and merges), then warns on
  drift but never blocks.
- **AD-19** The Known Limitations subsection explicitly names the
  harness safety heuristic layer, enumerates the observed trigger classes
  (copy from M005-CONTEXT.md), names the remedy (single-script-file
  shape), and cross-references AD-19 so future planners can judge edge
  cases. It MUST state explicitly that P07's generator does not and
  cannot eliminate this prompt class.

## Steps

### Step 1 — Rewrite `commands/auto.md` Section 4 ("Permission Pre-Flight")

Current Section 4 (lines 48-93 of `commands/auto.md`) is the template-
copy MVP. Replace the entire body between the `### 4. Permission
Pre-Flight` header and the `### 5. Worktree Isolation (FR-075)` header
with the text below. Keep the header itself intact.

**New Section 4 body** (preserves the header `### 4. Permission Pre-Flight`):

```markdown
Check that the project has autonomy permissions wired up. Without them,
autonomous execution will be interrupted by permission prompts for every
tool call.

#### 4a. Read autonomy configuration

```bash
autonomy_generate_on_init=$(bash scripts/state/read-config.sh autonomy.generate_on_init 2>/dev/null || echo true)
autonomy_mode=$(bash scripts/state/read-config.sh autonomy.mode 2>/dev/null || echo null)
```

The four-layer resolution (env > `.local` > project > defaults) comes
from `read-config.sh`. If `autonomy_mode` is `null`, the generator
resolves it from the tier (Tier A=minimal, Tier B=standard, Tier C=full).

#### 4b. Detect settings file state

```bash
if [ ! -f .claude/settings.json ]; then
  state=MISSING
elif grep -q '"_generated_by": "speckit-orchestrator"' .claude/settings.json; then
  state=ORCHESTRATOR
else
  state=USER_AUTHORED
fi
```

#### 4c. Branch on state

**state=MISSING** — generate from introspection and write a fresh
`.claude/settings.json`:

```bash
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-canon.json
```

Report: "Generated `.claude/settings.json` from project introspection
(autonomy mode: {autonomy_mode}). Review if desired."

**state=ORCHESTRATOR** — regenerate. Catches toolchain drift since the
last generation (new script registered in `extension.yml`, new
`package.json` key, etc). The writer overwrites orchestrator-generated
files in place.

```bash
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-canon.json
```

Then run the drift detector to confirm status is clean:

```bash
bash scripts/diagnostics/check-permissions.sh
```

The drift detector emits `DOCTOR:PERMISSIONS status=ok gaps=0 stale=0`
on success. If it reports drift, the writer failed silently — escalate
to the developer and exit before acquiring the lock.

**state=USER_AUTHORED** — DO NOT overwrite. Per AD-13, the writer merges
additively into user-authored files and never removes user entries.
Invoke the writer so missing baseline patterns are added:

```bash
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-canon.json
```

Then run the drift detector for informational warnings — user-authored
files can legitimately deviate from the orchestrator baseline. The
doctor reports the gaps but auto mode proceeds (AD-13: user autonomy
wins over orchestrator opinion).

```bash
bash scripts/diagnostics/check-permissions.sh || echo "User-authored settings drift — proceeding anyway per AD-13"
```

Warn the developer if any of the following critical patterns are
missing after the merge:
- `"defaultMode":` (missing = zero unattended execution)
- `Bash(output=*)` (missing = `output=$(bash scripts/...)` idiom blocked)
- `Bash(bash scripts/*)` (missing = orchestrator script invocation blocked)

#### 4d. Verify readiness

```bash
bash scripts/diagnostics/check-permissions.sh > /tmp/p07-preflight.out
grep -q 'status=ok' /tmp/p07-preflight.out || grep -q 'status=drift' /tmp/p07-preflight.out
```

If `status=missing` appears, the writer failed. Escalate and exit before
acquiring the lock.

### Known Limitations: Harness Safety Heuristics

Claude Code's bash permission system has two independent layers:

1. **The permission layer** — `.claude/settings.json` `defaultMode` plus
   allow/deny pattern matching. This is what `generate-permissions.sh`
   targets. Generating a comprehensive allow list from introspection
   eliminates the vast majority of unattended-mode prompts.

2. **The safety heuristic layer** — built-in checks in the harness that
   detect obfuscation-shaped commands and force a user prompt
   **regardless** of the allow list. This layer cannot be disabled from
   `settings.json`, is invisible to the orchestrator, and fires on
   command shape rather than command content. P07's generator does not
   and cannot eliminate this prompt class.

**Observed trigger classes** (from M004/P02 and M004/P05 task
verification; list grows as the harness evolves — treat as indicative,
not exhaustive):

- Brace expansion containing quote characters
- Complex `$variable` expansion inside compound blocks
- `bash -c '...'` with embedded quoted regex or character classes
- Plain `( ... )` subshell groups — **even without `&&`/`||`**
- `source` / `.` builtin with arguments inside a subshell
- Process substitution `<(...)` / `>(...)`
- `cmd <file` input redirection nested inside `$(...)` — e.g.
  `lines=$(wc -l < path/to/file)`
- `&&`/`||` outside a trivial two-token pair
- Command substitution `$(...)` containing pipes
- Compound `;`-separated statements chaining more than two commands
- Inline `for`/`while`/`if` blocks in a single command
- Heredocs feeding commands with further pipes/redirects

**Remedy**: write task plan Truth `Check:` commands and inline
verification blocks as **single-script-file invocations**. Instead of:

```bash
# FAILS harness heuristic (plain subshell + source + compound)
( . scripts/lib/errors.sh && emit_result ok "" "test" | grep -q RESULT: )
```

Write:

```bash
# PASSES harness heuristic (single-file invocation)
bash scripts/verify/my-check.sh
```

The rationale is documented in AD-19 (see
`.specify/orchestrator/milestones/M005/M005-CONTEXT.md`). Task plans
authored per `commands/plan-phase.md` follow this convention by default.
P06's `scripts/diagnostics/check-plans.sh` (advisory lint) flags task
plans that drift from the convention.
```

### Step 2 — Update `commands/evaluate.md`

Find the section `### Tier B or C Result` (around line 99). After the
existing step `1. Scaffold the orchestrator directory structure` and
step `2. Write the evaluation file`, add a new step `3. Generate
autonomy permissions`:

```markdown
3. **Generate autonomy permissions** (FR-7):

Check the `autonomy.generate_on_init` config value:

```bash
gen_on_init=$(bash scripts/state/read-config.sh autonomy.generate_on_init 2>/dev/null || echo true)
```

If `gen_on_init` is `true` (default) and the tier is B or C, run the
generator → writer pipeline so the fresh project is unattended-ready
before the first `auto` invocation:

```bash
if [ "$gen_on_init" = "true" ]; then
  mkdir -p /tmp
  bash scripts/lifecycle/generate-permissions.sh --tier $TIER > /tmp/p07-evaluate-canon.json
  bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-evaluate-canon.json
  rm -f /tmp/p07-evaluate-canon.json
fi
```

This step is idempotent: running `evaluate` again with an existing
`.claude/settings.json` that has the `_generated_by` marker overwrites
it with a fresh generation (reflecting any `extension.yml` or toolchain
changes since the last run). User-authored `.claude/settings.json`
files are merged additively (AD-13) — never overwritten.

Report: "Wrote `.claude/settings.json` with introspection-based
permissions (autonomy mode: full, tier: C)."
```

Renumber the existing step 3 ("Report to the user") → step 4.

Also, update the `### Override Support` block to note that tier
overrides re-trigger the permission generator when
`autonomy.generate_on_init` is true — a tier change should refresh the
autonomy mode (e.g., B→C should upgrade `minimal` → `full`). This is a
one-sentence note, not a new step.

### Step 3 — Smoke test

```bash
# Run doctor against the current repo with the new pre-flight flow
bash scripts/diagnostics/check-permissions.sh

# Run phase must-haves
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

The new pre-flight flow documentation is Tier 1 verified via the phase
plan's Truth `Check:` commands: `grep -q "generate-permissions" commands/auto.md`,
`grep -q "check-permissions" commands/auto.md`, `grep -q "Known Limitations" commands/auto.md`,
`grep -q "AD-19" commands/auto.md`, `grep -q "generate_on_init" commands/evaluate.md`.
All five must pass after this task.

## Must-Haves

This task addresses:

- **Truths**: "commands/auto.md Permission Pre-Flight references the
  generator", "commands/auto.md Permission Pre-Flight references the
  drift detector", "commands/auto.md documents the harness-safety-
  heuristic limitation (AD-19)", "commands/auto.md Known Limitations
  section names AD-19 explicitly", "commands/evaluate.md triggers
  permission generation on init (FR-7)".
- **Artifacts**: modified `commands/auto.md`, modified
  `commands/evaluate.md`.
- **Key Links**:
  - `commands/auto.md → scripts/lifecycle/generate-permissions.sh`
  - `commands/auto.md → scripts/lifecycle/write-permissions.sh`
  - `commands/auto.md → scripts/diagnostics/check-permissions.sh`
  - `commands/evaluate.md → scripts/lifecycle/generate-permissions.sh`

## Verification

```bash
# auto.md references all three P07 scripts
grep -q "generate-permissions" commands/auto.md
grep -q "write-permissions" commands/auto.md
grep -q "check-permissions" commands/auto.md

# Known Limitations subsection exists and names AD-19
grep -q "Known Limitations" commands/auto.md
grep -q "AD-19" commands/auto.md

# evaluate.md triggers generation on init
grep -q "generate_on_init" commands/evaluate.md

# Phase must-haves
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

### Files Touched By This Task

- `commands/auto.md` (modify — replace Section 4 body, add Known
  Limitations subsection between Section 4 and Section 5)
- `commands/evaluate.md` (modify — insert step 3 under Tier B/C Result,
  renumber existing step 3 → 4)

## Inputs

### From Previous Tasks

- **T02 generator** (`scripts/lifecycle/generate-permissions.sh`):
  - CLI: `bash scripts/lifecycle/generate-permissions.sh [--tier A|B|C] [--project-root <path>]`
  - Stdout: AD-16 canonical JSON envelope.
  - Stderr: EVENT + RESULT lines.
  - Exit 0 on success; non-zero on configuration error.
- **T03 writer** (`scripts/lifecycle/write-permissions.sh`):
  - CLI: `bash scripts/lifecycle/write-permissions.sh [--input <file>] [--host claude_code|cursor|copilot]`
  - Reads canonical envelope from stdin or `--input <file>`, writes the
    host-specific settings file.
  - Detects user-authored targets via the `_generated_by` marker and
    merges additively (AD-13).
  - Only `claude_code` is implemented in v0.1; other hosts return exit 1
    with `emit_result error DISPATCH "host 'X' is a pluggable stub"`.
- **T03 drift detector** (`scripts/diagnostics/check-permissions.sh`):
  - CLI: `bash scripts/diagnostics/check-permissions.sh [--target <path>]`
  - Stdout: single `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N`
    line followed by zero or more human-readable detail lines.
  - Exit 0 if `status=ok`, 1 if `status=drift`, 2 if `status=missing`.

### From Disk (Pre-existing)

- `commands/auto.md` — current Section 4 is the template-copy MVP
  (lines 48-93). Section 5 "Worktree Isolation (FR-075)" starts at line
  95. The replacement body from Step 1 goes between them. The rest of
  auto.md (lock acquisition, loop iteration pattern, phase transition,
  completion) is unchanged.
- `commands/evaluate.md` — `### Tier B or C Result` section starts at
  line 99. Insert the new step after the evaluation-file-write step.
- `scripts/state/read-config.sh` — supports dotted-path queries
  (e.g., `read-config.sh autonomy.mode`). Returns the resolved value or
  exits non-zero if the key is unset. The new pre-flight uses
  `2>/dev/null || echo <default>` to get a fall-through default.
- `.specify/orchestrator/milestones/M005/M005-CONTEXT.md` — AD-19 full
  text. The Known Limitations subsection in auto.md cross-references
  this file (by path) so future planners can find the authoritative
  trigger list.

## Expected Output

After completing this task:

1. `commands/auto.md` contains the new Permission Pre-Flight body with
   explicit references to `generate-permissions.sh`,
   `write-permissions.sh`, and `check-permissions.sh`.
2. `commands/auto.md` contains a `### Known Limitations: Harness Safety
   Heuristics` subsection that names AD-19, enumerates the trigger
   classes, and points at the script-file-shape remedy.
3. `commands/evaluate.md` contains a new "Generate autonomy permissions"
   step in the Tier B/C Result flow that runs when
   `autonomy.generate_on_init` is true.
4. All T04 Truth `Check:` commands pass:
   - `grep -q "generate-permissions" commands/auto.md` → exit 0
   - `grep -q "check-permissions" commands/auto.md` → exit 0
   - `grep -q "Known Limitations" commands/auto.md` → exit 0
   - `grep -q "AD-19" commands/auto.md` → exit 0
   - `grep -q "generate_on_init" commands/evaluate.md` → exit 0
5. Phase Tier 1 verification:
   `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07`
   — all T01+T02+T03+T04 items PASS; only T05 items remain FAIL.
