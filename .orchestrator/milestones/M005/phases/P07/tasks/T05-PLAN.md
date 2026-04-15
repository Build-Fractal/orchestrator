---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P07"
milestone: "M005"
name: "Harness-heuristic shape guidance + installation docs"
depends_on: []
---

## Description

Lock in the task-plan authoring convention that makes auto mode
**actually unattended**. P07's generator closes the allow-list gap, but
AD-19 identifies a second, independent layer of prompts the generator
cannot touch: the harness safety heuristic, which fires on command
**shape** (obfuscation-looking patterns) rather than command content.

This task updates three authoring documents and one reference:

1. **`commands/plan-phase.md`** — the document that tells future planners
   how to write Truth `Check:` commands. Without guidance here, every
   future phase plan reintroduces the prompt-interrupting shapes.
2. **`templates/phase-plan.md`** — the template future planners copy
   from. Its Truths example must show the script-file shape exclusively.
3. **`templates/task-plan.md`** — same, for individual task plans.
4. **`references/installation.md`** — user-facing documentation of the
   autonomy configuration, drift detection, and harness-heuristic
   limitation.

This task is **entirely documentation** and has **zero runtime
dependency** on T02/T03/T04. It can dispatch in parallel with them. The
only pre-condition is that T01's config shape (`autonomy.mode`,
`autonomy.generate_on_init`, `autonomy.deny_patterns`,
`autonomy.extra_allow`) is settled so the installation docs stay
consistent.

Architectural decisions that constrain this task:
- **AD-19** Full harness trigger enumeration. Do NOT trim the list for
  brevity — future planners need the full shape family to judge edge
  cases. Cross-reference M005-CONTEXT.md by path so the canonical list
  stays honest as the harness evolves.
- **AD-7**  Document only the closed `minimal | standard | full` mode
  enum. Never document `bypassPermissions` as a mode option.

## Steps

### Step 1 — Update `commands/plan-phase.md` Truths section

Find the existing Truths subsection (around lines 52-64 of
`commands/plan-phase.md`). After the existing paragraph that ends with
"...use sparingly and only for behaviors that genuinely cannot be
reduced to a command.", insert a new subsection:

```markdown
#### Truth `Check:` command shape — mandatory script-file shape (AD-19)

Truth `Check:` commands run through the harness bash permission system,
which has two layers:

1. **The allow list** (`.claude/settings.json`) — P07 generates this from
   project introspection to cover every orchestrator script. Patterns
   that match the allow list execute without prompting.

2. **The safety heuristic layer** — built into the host and **cannot be
   disabled from `settings.json`**. It fires on command *shape*, not
   content, to catch obfuscation patterns. Even a command whose
   individual tokens are fully allow-listed will trigger a prompt if its
   shape matches one of the heuristic classes.

**Forbidden shapes** (observed to trigger the harness heuristic — see
AD-19 in `.specify/orchestrator/milestones/M005/M005-CONTEXT.md` for the
authoritative trigger list):

- Inline compound `bash -c '...' && bash -c '...'` chains.
- Plain `( … )` subshells — even without `&&`/`||` — e.g.
  `( . scripts/lib/errors.sh && fn arg )`.
- `source` / `.` builtin with arguments inside a subshell.
- Command substitution `$(…)` containing pipes — e.g.
  `rc=$(bash cmd | grep -c '^RESULT:')`.
- Process substitution `<(…)` or `>(…)` anywhere.
- `cmd <file` input redirection nested inside `$(…)` — e.g.
  `lines=$(wc -l < path)`.
- Compound `;`-separated statements chaining more than two commands.
- Inline `for`/`while`/`if` blocks embedded in a single command.
- Heredocs feeding commands with pipes or further redirects.
- Brace expansion containing quote characters.
- `bash -c '...'` with embedded quoted regex or character classes.

**Required shape**: **single-script-file invocations**. Instead of
writing a compound command inline, extract the logic into a short
helper script under `scripts/verify/` or into the task's own phase
directory, then invoke the helper as the `Check:` command.

```markdown
# ❌ FORBIDDEN — triggers harness heuristic (plain subshell + source)
- My truth statement
  - Check: `( . scripts/lib/errors.sh && emit_result ok "" "test" | grep -q RESULT )`

# ❌ FORBIDDEN — triggers harness heuristic ($(...) containing pipe)
- My truth statement
  - Check: `test $(grep -c "pattern" file.txt) -gt 0`

# ✅ REQUIRED — single-script-file shape
- My truth statement
  - Check: `bash scripts/verify/p07-my-check.sh`
```

**Why this matters**: the orchestrator's `speckit.orchestrator.auto`
command runs unattended. Every harness prompt interrupts that
unattended run — even for commands the developer has allow-listed.
Writing `Check:` commands in the script-file shape keeps auto mode
genuinely unattended. This is preventive; P06's
`scripts/diagnostics/check-plans.sh` is the detective counterpart, an
advisory lint that scans task plans and flags violations before they
reach auto mode.

Rationale: the rule exists because the harness heuristic layer is
*above* the allow list, cannot be configured away, and fires on shape
family rather than specific patterns. Future planners encountering an
edge case should read AD-19 in full rather than mechanically following
the bulleted list — the list is indicative, not exhaustive, and will
grow as new triggers are observed.
```

### Step 2 — Update `templates/phase-plan.md`

The current template's Truths example uses the placeholder shape
`{{truth}}` with no sub-items. Expand it to show the script-file shape
explicitly so future planners copy the correct pattern. Replace the
existing Truths block:

```markdown
### Truths

- {{truth}}
```

with:

```markdown
### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19, Truth Check commands MUST use single-invocation script-
     file shape — no inline compound bash, no plain subshells, no
     command-substitution-with-pipes. See commands/plan-phase.md for
     the full forbidden-shape enumeration.

     Forbidden:
       - Check: `( . scripts/lib/errors.sh && fn | grep -q X )`
       - Check: `test $(grep -c foo file) -gt 0`

     Required:
       - Check: `bash scripts/verify/<phase>-<task>-<name>.sh`
-->
- {{truth statement}}
  - Check: `bash scripts/verify/{{check-script}}.sh`
```

### Step 3 — Update `templates/task-plan.md`

Similar update. The current task template's Verification placeholder is
`{{verification_criteria}}` — too vague to enforce shape. Replace:

```markdown
## Verification

{{verification_criteria}}
```

with:

```markdown
## Verification

<!-- Verification commands MUST use single-script-file shape per AD-19.
     The harness safety heuristic layer sits above the allow list and
     cannot be configured away. Inline compound bash, plain subshells,
     $() containing pipes, and process substitution all trigger the
     heuristic and interrupt unattended auto mode execution.

     See commands/plan-phase.md "Truth Check: command shape" for the
     full forbidden-shape enumeration and rationale (AD-19).

     Required form:
       bash scripts/verify/<phase>-<task>-<name>.sh
       bash scripts/verify/check-must-haves.sh <phase-dir>

     Forbidden forms:
       ( . scripts/lib/errors.sh && fn arg )
       result=$(bash cmd | grep -c 'RESULT')
       diff <(cmd1) <(cmd2)
-->
{{verification_criteria}}
```

### Step 4 — Update `references/installation.md`

Find the `## Updating` section (around line 140) and insert a new
section before it: `## Autonomy Configuration`.

```markdown
## Autonomy Configuration

Spec-kit-orchestrator's Tier C autonomous mode (`speckit.orchestrator.auto`)
runs unattended — it dispatches tasks, verifies results, and advances
phase boundaries without developer interaction. For this to work
reliably, the agent host (Claude Code, Cursor, etc.) must have a
sufficient allow list so tool calls execute without permission prompts.

**How it works**: the orchestrator ships a generator at
`scripts/lifecycle/generate-permissions.sh` that introspects the
current project and emits a canonical JSON permissions object that
covers every orchestrator script (from `extension.yml`), every
`package.json` script key, every Makefile target, and the standard
toolchain commands for the languages in use. The writer at
`scripts/lifecycle/write-permissions.sh` translates the canonical
object to your agent host's specific settings file (today:
`.claude/settings.json`). A drift detector at
`scripts/diagnostics/check-permissions.sh` reports when the current
settings file has fallen behind the generated output.

### Autonomy Modes

Three modes ship in `templates/autonomy-defaults.yaml`:

| Mode | Tier default | Use case |
|------|--------------|----------|
| `minimal` | Tier A | Reads/edits only. No unattended bash. |
| `standard` | Tier B | Common toolchains + scripts/. Guided dispatch. |
| `full` | Tier C | Comprehensive allow list for unattended auto mode. |

The mode is tier-derived by default but can be overridden in
`orchestrator-config.yml`:

```yaml
autonomy:
  mode: full                # null (tier default) | minimal | standard | full
  generate_on_init: true    # Run generator during speckit.orchestrator.evaluate
  deny_patterns: []         # Extra deny patterns appended to baseline_deny
  extra_allow: []           # Extra allow patterns appended to baseline_allow
```

**Note**: `bypassPermissions` is **not** a supported mode. Per AD-7 in
`.specify/orchestrator/milestones/M005/M005-CONTEXT.md`, safety comes
from explicit allow-list enumeration, never from disabling checks.

### Running the Generator

```bash
# Emit canonical JSON to stdout (preview)
bash scripts/lifecycle/generate-permissions.sh --tier C

# Generate + write in one step
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/canon.json

# Check for drift
bash scripts/diagnostics/check-permissions.sh
# → DOCTOR:PERMISSIONS status=ok gaps=0 stale=0
```

### Drift Detection

`scripts/diagnostics/check-permissions.sh` compares the current
`.claude/settings.json` against what the generator would produce. It
emits a structured line consumable by diagnostics and returns:

- `status=ok` — zero gaps, zero stale patterns, baseline deny intact.
- `status=drift` — one or more missing patterns (regeneration needed).
- `status=missing` — `.claude/settings.json` does not exist at all.

`speckit.orchestrator.auto` runs this check as part of its pre-flight.
User-authored settings files trigger an informational warning but do
not block execution — AD-13 says user autonomy wins over orchestrator
opinion.

### Known Limitation: Harness Safety Heuristics

Generating a comprehensive allow list covers the allow-list layer of
the host's bash permission system, but there is a **second, independent
layer** — the safety heuristic check — that fires on command **shape**
(not content) to catch obfuscation patterns. This layer sits above the
allow list and cannot be disabled from `settings.json`. Even a command
whose individual tokens are fully allow-listed will trigger a prompt if
its shape matches one of the heuristic classes (plain subshells,
command substitution containing pipes, process substitution, inline
compound bash, etc.).

The orchestrator's remedy is **preventive**: task plan Truth `Check:`
commands and verification scripts must use the **single-script-file
shape** — extract multi-step logic into a helper script under
`scripts/verify/` and invoke the helper as a plain `bash scripts/...`
command. The authoritative list of forbidden shapes lives in AD-19 at
`.specify/orchestrator/milestones/M005/M005-CONTEXT.md` and in the
authoring guidance at `commands/plan-phase.md`.

If you are writing a new extension command or phase plan, follow the
shape guidance in `commands/plan-phase.md`. The advisory lint at
`scripts/diagnostics/check-plans.sh` (M005 P06) scans task plans and
flags violations so you can fix them before running auto mode.
```

### Step 5 — Smoke test

```bash
# All four docs contain the required markers
grep -q "AD-19" commands/plan-phase.md
grep -q "script-file shape" commands/plan-phase.md
grep -q "bash scripts/" templates/phase-plan.md
grep -q "AD-19" templates/task-plan.md
grep -qE "minimal.*standard.*full|full.*standard.*minimal" references/installation.md

# Phase must-haves
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

## Must-Haves

This task addresses:

- **Truths**: "commands/plan-phase.md Truths guidance cross-references
  AD-19", "commands/plan-phase.md enumerates the harness-heuristic
  trigger classes and points at the script-file shape remedy",
  "templates/phase-plan.md example Truth `Check:` uses single-invocation
  script-file shape", "templates/task-plan.md verification example
  calls out AD-19 as the source of the shape constraint",
  "references/installation.md documents the three autonomy modes".
- **Artifacts**: modified `commands/plan-phase.md`, modified
  `templates/phase-plan.md`, modified `templates/task-plan.md`,
  modified `references/installation.md`.
- **Key Links**: `commands/plan-phase.md → templates/phase-plan.md`.

## Verification

```bash
test -f commands/plan-phase.md
test -f templates/phase-plan.md
test -f templates/task-plan.md
test -f references/installation.md

grep -q "AD-19" commands/plan-phase.md
grep -q "script-file shape" commands/plan-phase.md
grep -q "bash scripts/" templates/phase-plan.md
grep -q "AD-19" templates/task-plan.md
grep -q "autonomy" references/installation.md

# Phase must-haves — after T05, everything should PASS (assuming T01-T04 ran)
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

### Files Touched By This Task

- `commands/plan-phase.md` (modify — insert script-file-shape subsection
  after Truths paragraph)
- `templates/phase-plan.md` (modify — replace Truths example with
  script-file shape)
- `templates/task-plan.md` (modify — replace Verification placeholder
  comment with AD-19 shape guidance)
- `references/installation.md` (modify — insert Autonomy Configuration
  section before Updating)

## Inputs

### From Previous Tasks

- **T01 autonomy config shape** — the installation docs reference the
  four config keys (`mode`, `generate_on_init`, `deny_patterns`,
  `extra_allow`). These key names must match `templates/autonomy-defaults.yaml`
  and `templates/orchestrator-config-default.yml` exactly. Coordinate
  with T01's output to keep them consistent. The expected canonical
  names are documented in T01's Step 2.

### From Disk (Pre-existing)

- `commands/plan-phase.md` — current Truths subsection starts at line
  52 (the `#### Truths` header) and extends to line 64 (end of the
  "use sparingly" paragraph). The new subsection from Step 1 inserts
  immediately after line 64, before the `#### Artifacts` header.
- `templates/phase-plan.md` — 50 lines total. Truths example is at
  lines 14-16 (`### Truths` header + `- {{truth}}` placeholder).
- `templates/task-plan.md` — 45 lines total. Verification placeholder
  is at lines 23-25 (`## Verification` header + `{{verification_criteria}}`).
- `references/installation.md` — 158 lines total. `## Updating` section
  starts at line 139. Insert the new `## Autonomy Configuration`
  section immediately before it.
- `.specify/orchestrator/milestones/M005/M005-CONTEXT.md` — AD-19 full
  text. All four doc updates cross-reference this file for the
  authoritative trigger list.

## Expected Output

After completing this task:

1. `commands/plan-phase.md` contains a new "Truth Check: command
   shape" subsection that enumerates forbidden shapes, shows correct
   script-file form, explains *why*, and cross-references AD-19 in
   M005-CONTEXT.md.
2. `templates/phase-plan.md` Truths example shows the script-file
   shape with a `bash scripts/verify/...sh` Check command and a
   comment naming AD-19.
3. `templates/task-plan.md` Verification section has an AD-19 comment
   block and lists the required/forbidden forms.
4. `references/installation.md` contains an `## Autonomy Configuration`
   section documenting the three modes, four config keys, drift
   detection, and the harness-heuristic limitation.
5. All T05 Truth `Check:` commands pass:
   - `grep -q "AD-19" commands/plan-phase.md`
   - `grep -q "script-file shape" commands/plan-phase.md`
   - `grep -q "bash scripts/" templates/phase-plan.md`
   - `grep -q "AD-19" templates/task-plan.md`
   - `grep -qE "minimal.*standard.*full" references/installation.md`
6. Running
   `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07`
   after all five tasks are complete shows every Must-Have item PASS.
