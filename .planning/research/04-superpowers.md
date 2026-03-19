# Superpowers Research Report

Research target: `./superpowers/` (git submodule, v5.0.5)
Author: Jesse Vincent (jesse@fsck.com)
Repository: https://github.com/obra/superpowers
License: MIT

---

## 1. Philosophy and Skill System

### 1.1 Core Philosophy -- Mandatory Discipline, Evidence Before Claims, Design Before Code

Superpowers is built on a single thesis: **autonomous AI agents, left to their defaults, will skip every discipline that costs time** -- testing, design, verification, review. The system exists to enforce these disciplines through structured process documentation ("skills") that are injected into every agent session.

Three axioms recur across every skill:

1. **Evidence before claims, always.** (verification-before-completion SKILL.md: "Claiming work is complete without verification is dishonesty, not efficiency.")
2. **Design before code, always.** (brainstorming SKILL.md: `<HARD-GATE>Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.</HARD-GATE>`)
3. **Test before implementation, always.** (test-driven-development SKILL.md: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST")

Each axiom has a matching "iron law" -- a one-line rule stated in uppercase that the skill declares non-negotiable. Iron laws are designed to be un-rationalizable:

> "Violating the letter of this rule is violating the spirit of this rule." (verification-before-completion, test-driven-development, systematic-debugging)

### 1.2 Skill Structure and Mandatory Activation (using-superpowers Meta-Skill)

#### What a Skill Is

A skill is a SKILL.md file with YAML frontmatter (`name` and `description` fields, max 1024 chars total) containing process documentation, decision flowcharts, prompt templates, and anti-rationalization tables. Skills live in `skills/<skill-name>/SKILL.md` in a flat namespace.

Skills are typed:
- **Rigid** (TDD, debugging): "Follow exactly. Don't adapt away discipline."
- **Flexible** (patterns): "Adapt principles to context."

#### How Skills Are Discovered and Activated

The `using-superpowers` skill is the meta-skill. It is force-loaded into every session via a SessionStart hook (see Section 4). Its content instructs the agent on how to discover and activate other skills.

In Claude Code, skills are activated via the `Skill` tool. The agent is instructed:

> "Invoke relevant or requested skills BEFORE any response or action. Even a 1% chance a skill might apply means that you should invoke the skill to check."

The meta-skill contains a graphviz decision flowchart showing the exact flow: `User message received -> Might any skill apply? -> (yes, even 1%) -> Invoke Skill tool -> Announce: 'Using [skill] to [purpose]' -> Has checklist? -> Create TodoWrite todo per item -> Follow skill exactly -> Respond`.

#### Why Mandatory, Not Optional

From using-superpowers SKILL.md:

```
<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>
```

#### Priority System

When multiple skills apply, the ordering is:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) -- highest priority
2. **Superpowers skills** -- override default system behavior where they conflict
3. **Default system prompt** -- lowest priority

Within skills, process skills fire first (brainstorming, debugging), then implementation skills (frontend-design, mcp-builder):
- "Let's build X" -> brainstorming first, then implementation skills
- "Fix this bug" -> debugging first, then domain-specific skills

### 1.3 Anti-Patterns and Rationalization Prevention

Every discipline-enforcing skill contains a **rationalization table** and a **red flags list** -- specific thoughts the agent might have that signal it is about to skip the discipline.

#### using-superpowers Red Flags

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. |

#### test-driven-development Red Flags

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "TDD will slow me down" | TDD faster than debugging. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |

#### verification-before-completion Red Flags

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence != evidence |
| "Just this once" | No exceptions |
| "Agent said success" | Verify independently |
| "Partial check is enough" | Partial proves nothing |

#### systematic-debugging Red Flags

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check. |
| "I see the problem, let me fix it" | Seeing symptoms != understanding root cause. |
| "One more fix attempt" (after 2+) | 3+ failures = architectural problem. |

#### brainstorming Anti-Pattern

> "Every project goes through this process. A todo list, a single-function utility, a config change -- all of them. 'Simple' projects are where unexamined assumptions cause the most wasted work."

### 1.4 The Brainstorm -> Plan -> Execute -> Review -> Finish Pipeline

The full pipeline comprises 5 stages, each enforced by a dedicated skill:

#### Stage 1: Brainstorm (brainstorming SKILL.md)

Purpose: Turn an idea into a validated design document.

Checklist:
1. Explore project context -- check files, docs, recent commits
2. Offer visual companion (if topic involves visual questions)
3. Ask clarifying questions -- one at a time, multiple choice preferred
4. Propose 2-3 approaches with trade-offs and recommendation
5. Present design in sections scaled to complexity, get user approval per section
6. Write design doc to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
7. Spec review loop -- dispatch spec-document-reviewer subagent (max 3 iterations)
8. User reviews written spec -- explicit human gate before proceeding
9. Transition to implementation -- invoke writing-plans skill

Key constraint: `<HARD-GATE>` prevents any code before design approval. "The terminal state is invoking writing-plans."

#### Stage 2: Plan (writing-plans SKILL.md)

Purpose: Convert a validated design into zero-context, bite-sized implementation tasks.

Process:
1. Map file structure (what files will be created/modified and why)
2. Define tasks as bite-sized steps (2-5 minutes each)
3. Each step follows TDD: write failing test -> verify fail -> implement minimal code -> verify pass -> commit
4. Plans include exact file paths, complete code, exact commands with expected output
5. Plan review loop via plan-document-reviewer subagent (max 3 iterations)
6. Execution handoff: offer subagent-driven (recommended) or inline execution

#### Stage 3: Execute (subagent-driven-development or executing-plans)

Purpose: Implement the plan task by task with quality gates.

- **Subagent-driven** (recommended): Fresh subagent per task, two-stage review after each
- **Inline execution** (fallback): Batch execution with checkpoints in a single session

#### Stage 4: Review (requesting-code-review, receiving-code-review)

Purpose: Catch issues before they compound.

- After each task in subagent-driven dev: spec compliance review then code quality review
- Before merge: final full-implementation code review
- Technical evaluation, not performative agreement

#### Stage 5: Finish (finishing-a-development-branch)

Purpose: Verify tests pass, present integration options, clean up.

Process: Verify tests -> Present 4 options (merge locally, create PR, keep as-is, discard) -> Execute choice -> Cleanup worktree

### 1.5 How Each Skill Enforces Discipline an Autonomous Agent Would Otherwise Skip

| Skill | Discipline Enforced | What Agent Would Skip |
|-------|--------------------|-----------------------|
| using-superpowers | Check for applicable skills before any action | Jump straight to code |
| brainstorming | Design before code, user approval gate | Code first, design after |
| writing-plans | Zero-context plans, exact paths, TDD steps | Vague plans, skip tests |
| subagent-driven-development | Fresh context per task, two-stage review | Accumulated context, skip review |
| verification-before-completion | Run verification commands before claims | "Should work now" |
| test-driven-development | RED-GREEN-REFACTOR, delete code written before tests | Write code first, tests after |
| systematic-debugging | 4-phase root cause investigation | Random fix attempts |
| requesting-code-review | Dispatch reviewer after each task | Skip review for "simple" changes |
| receiving-code-review | Technical evaluation, push back if wrong | Performative agreement |
| using-git-worktrees | Isolated workspaces, verified baselines | Work on main branch |
| finishing-a-development-branch | Verify tests, present structured options | Merge without verification |
| writing-skills | TDD for process documentation itself | Write skills without testing |
| dispatching-parallel-agents | Domain isolation, focused prompts | One agent investigating everything |
| executing-plans | Follow plan exactly, stop when blocked | Skip steps, guess through blockers |

---

## 2. Subagent Dispatch Patterns

### 2.1 Subagent-Driven Development Model -- Fresh Context Per Task, Zero Session Inheritance

From subagent-driven-development SKILL.md:

> "You delegate tasks to specialized agents with isolated context. By precisely crafting their instructions and context, you ensure they stay focused and succeed at their task. They should never inherit your session's context or history -- you construct exactly what they need. This also preserves your own context for coordination work."

The model: **one orchestrator (the "controller")** reads the plan once, extracts all tasks with full text, creates a TodoWrite checklist, then dispatches a fresh subagent for each task sequentially. After each implementation subagent completes, two reviewer subagents are dispatched in sequence.

Key properties:
- **Fresh subagent per task**: no context pollution between tasks
- **Controller constructs context**: subagents never read plan files -- controller pastes full task text
- **Questions surfaced before work begins**: implementer prompt explicitly invites questions
- **Self-review before handoff**: implementer reviews own work before reporting

### 2.2 Context Isolation -- Orchestrator Constructs EXACTLY What Subagent Needs

The controller's job is to curate context. From subagent-driven-development SKILL.md:

> "Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration"

And:

> "No file reading overhead (controller provides full text)"
> "Controller curates exactly what context is needed"
> "Subagent gets complete information upfront"

Red flags explicitly prevent context leakage:

> "Make subagent read plan file (provide full text instead)" -- listed as a "Never"
> "Skip scene-setting context (subagent needs to understand where task fits)" -- listed as a "Never"

### 2.3 Prompt Construction for Each Role

#### Implementer Prompt Template (from `skills/subagent-driven-development/implementer-prompt.md`)

```
Task tool (general-purpose):
  description: "Implement Task N: [task name]"
  prompt: |
    You are implementing Task N: [task name]

    ## Task Description

    [FULL TEXT of task from plan - paste it here, don't make subagent read file]

    ## Context

    [Scene-setting: where this fits, dependencies, architectural context]

    ## Before You Begin

    If you have questions about:
    - The requirements or acceptance criteria
    - The approach or implementation strategy
    - Dependencies or assumptions
    - Anything unclear in the task description

    **Ask them now.** Raise any concerns before starting work.

    ## Your Job

    Once you're clear on requirements:
    1. Implement exactly what the task specifies
    2. Write tests (following TDD if task says to)
    3. Verify implementation works
    4. Commit your work
    5. Self-review (see below)
    6. Report back

    Work from: [directory]

    **While you work:** If you encounter something unexpected or unclear, **ask questions**.
    It's always OK to pause and clarify. Don't guess or make assumptions.

    ## Code Organization

    You reason best about code you can hold in context at once, and your edits are more
    reliable when files are focused. Keep this in mind:
    - Follow the file structure defined in the plan
    - Each file should have one clear responsibility with a well-defined interface
    - If a file you're creating is growing beyond the plan's intent, stop and report
      it as DONE_WITH_CONCERNS
    - In existing codebases, follow established patterns.

    ## When You're in Over Your Head

    It is always OK to stop and say "this is too hard for me." Bad work is worse than
    no work. You will not be penalized for escalating.

    ## Before Reporting Back: Self-Review

    [Completeness, Quality, Discipline, Testing checklists]

    ## Report Format

    When done, report:
    - **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - What you implemented (or what you attempted, if blocked)
    - What you tested and test results
    - Files changed
    - Self-review findings (if any)
    - Any issues or concerns
```

#### Spec Compliance Reviewer Prompt Template (from `skills/subagent-driven-development/spec-reviewer-prompt.md`)

```
Task tool (general-purpose):
  description: "Review spec compliance for Task N"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## What Was Requested

    [FULL TEXT of task requirements]

    ## What Implementer Claims They Built

    [From implementer's report]

    ## CRITICAL: Do Not Trust the Report

    The implementer finished suspiciously quickly. Their report may be incomplete,
    inaccurate, or optimistic. You MUST verify everything independently.

    **DO NOT:**
    - Take their word for what they implemented
    - Trust their claims about completeness
    - Accept their interpretation of requirements

    **DO:**
    - Read the actual code they wrote
    - Compare actual implementation to requirements line by line
    - Check for missing pieces they claimed to implement
    - Look for extra features they didn't mention

    ## Your Job

    Read the implementation code and verify:

    **Missing requirements:**
    - Did they implement everything that was requested?
    - Are there requirements they skipped or missed?

    **Extra/unneeded work:**
    - Did they build things that weren't requested?
    - Did they over-engineer or add unnecessary features?

    **Misunderstandings:**
    - Did they interpret requirements differently than intended?

    Report:
    - Spec compliant (if everything matches after code inspection)
    - Issues found: [list specifically what's missing or extra, with file:line references]
```

#### Code Quality Reviewer Prompt Template (from `skills/subagent-driven-development/code-quality-reviewer-prompt.md`)

```
Task tool (superpowers:code-reviewer):
  Use template at requesting-code-review/code-reviewer.md

  WHAT_WAS_IMPLEMENTED: [from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

Additional checks beyond standard code quality:
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this implementation create new files that are already large, or significantly grow existing files?

#### Spec Document Reviewer Prompt Template (from `skills/brainstorming/spec-document-reviewer-prompt.md`)

Used during the brainstorming spec review loop:

```
Task tool (general-purpose):
  description: "Review spec document"
  prompt: |
    You are a spec document reviewer. Verify this spec is complete and ready for planning.

    **Spec to review:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, "TBD", incomplete sections |
    | Consistency | Internal contradictions, conflicting requirements |
    | Clarity | Requirements ambiguous enough to cause wrong implementation |
    | Scope | Focused enough for a single plan |
    | YAGNI | Unrequested features, over-engineering |

    ## Calibration

    Only flag issues that would cause real problems during implementation planning.
    Approve unless there are serious gaps that would lead to a flawed plan.

    ## Output Format

    **Status:** Approved | Issues Found
    **Issues (if any):** [Section X]: [specific issue] - [why it matters]
    **Recommendations (advisory, do not block approval):** [suggestions]
```

#### Plan Document Reviewer Prompt Template (from `skills/writing-plans/plan-document-reviewer-prompt.md`)

Used during the plan review loop:

```
Task tool (general-purpose):
  description: "Review plan document"
  prompt: |
    You are a plan document reviewer. Verify this plan is complete and ready for implementation.

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Plan covers spec requirements, no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, steps are actionable |
    | Buildability | Could an engineer follow this plan without getting stuck? |

    ## Calibration

    Only flag issues that would cause real problems during implementation.
    Approve unless there are serious gaps.

    ## Output Format

    **Status:** Approved | Issues Found
    **Issues (if any):** [Task X, Step Y]: [specific issue]
    **Recommendations (advisory):** [suggestions]
```

### 2.4 Two-Stage Review -- Spec Compliance FIRST, THEN Code Quality

The two-stage review is the core quality mechanism. From subagent-driven-development SKILL.md:

**Stage 1: Spec Compliance Review** catches over-building and under-building:
- Missing requirements (under-building)
- Extra/unneeded work (over-building, YAGNI violations)
- Misunderstandings (building the wrong thing)

**Stage 2: Code Quality Review** catches implementation issues:
- Architecture violations
- Poor test coverage
- Naming, maintainability
- Security, performance

The ordering is explicit and enforced:

> "**Start code quality review before spec compliance is approved** (wrong order)" -- listed in Red Flags as a "Never"

Rationale: There is no point reviewing code quality if the code does the wrong thing. Spec compliance review is a gate that must pass before code quality review begins.

If either reviewer finds issues:
1. The same implementer subagent fixes them (preserves context)
2. The reviewer re-reviews
3. Repeat until approved
4. "Don't skip the re-review"

### 2.5 Implementer Status Handling

Four status codes, each with a defined orchestrator response:

**DONE:** Proceed to spec compliance review. Normal happy path.

**DONE_WITH_CONCERNS:** Implementer completed the work but flagged doubts.
- If concerns are about correctness or scope: address before review
- If observations (e.g., "this file is getting large"): note and proceed to review

**NEEDS_CONTEXT:** Implementer needs information not provided.
- Provide the missing context and re-dispatch

**BLOCKED:** Implementer cannot complete the task. Escalation ladder:
1. If context problem: provide more context, re-dispatch with same model
2. If task requires more reasoning: re-dispatch with more capable model
3. If task is too large: break into smaller pieces
4. If plan itself is wrong: escalate to human

Critical rule: "Never ignore an escalation or force the same model to retry without changes. If the implementer said it's stuck, something needs to change."

### 2.6 Model Selection by Task Complexity

From subagent-driven-development SKILL.md:

> "Use the least powerful model that can handle each role to conserve cost and increase speed."

| Task Type | Model Tier | Signals |
|-----------|-----------|---------|
| Mechanical implementation | Fast/cheap | Isolated functions, clear specs, 1-2 files |
| Integration and judgment | Standard | Multi-file coordination, pattern matching, debugging |
| Architecture, design, review | Most capable | Design judgment, broad codebase understanding |

Complexity signals:
- Touches 1-2 files with complete spec -> cheap model
- Touches multiple files with integration concerns -> standard model
- Requires design judgment or broad codebase understanding -> most capable model

### 2.7 Parallel vs. Sequential Dispatch (from dispatching-parallel-agents)

#### When to Parallelize

Use parallel dispatch when:
- 3+ independent failures (different test files, different subsystems)
- Each problem can be understood without context from others
- No shared state between investigations

Do NOT use when:
- Failures are related (fix one might fix others)
- Need full system state understanding
- Agents would interfere (editing same files)

#### Implementation Dispatch is Always Sequential

From subagent-driven-development Red Flags:
> "Dispatch multiple implementation subagents in parallel (conflicts)" -- listed as a "Never"

Implementation tasks run sequentially because they modify shared code. Parallel dispatch is reserved for independent investigation/debugging tasks.

#### Parallel Prompt Structure

Each parallel agent gets:
1. **Specific scope:** One test file or subsystem
2. **Clear goal:** Make these tests pass
3. **Constraints:** Don't change other code
4. **Expected output:** Summary of what you found and fixed

After agents return:
1. Review each summary
2. Verify fixes don't conflict
3. Run full test suite
4. Integrate all changes

---

## 3. Plan Structure

### 3.1 Plan Format from Concrete Examples

#### Plan Header (required)

Every plan MUST start with this header (from writing-plans SKILL.md):

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

#### Task Structure (from writing-plans SKILL.md)

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

#### Concrete Example: Svelte Todo Plan (from `tests/subagent-driven-dev/svelte-todo/plan.md`)

The plan contains 12 tasks. Each follows the pattern:

```markdown
### Task 2: Todo Store

Create the Svelte store for todo state management.

**Do:**
- Create `src/lib/store.ts`
- Define `Todo` interface with id, text, completed
- Create writable store with initial empty array
- Export functions: `addTodo(text)`, `toggleTodo(id)`, `deleteTodo(id)`, `clearCompleted()`
- Create `src/lib/store.test.ts` with tests for each function

**Verify:**
- Tests pass: `npm run test` (install vitest if needed)
```

#### Concrete Example: Go Fractals Plan (from `tests/subagent-driven-dev/go-fractals/plan.md`)

10 tasks, structured similarly:

```markdown
### Task 3: Sierpinski Algorithm

Implement the Sierpinski triangle generation algorithm.

**Do:**
- Create `internal/sierpinski/sierpinski.go`
- Implement `Generate(size, depth int, char rune) []string` that returns lines of the triangle
- Use recursive midpoint subdivision algorithm
- Create `internal/sierpinski/sierpinski_test.go` with tests:
  - Small triangle (size=4, depth=2) matches expected output
  - Size=1 returns single character
  - Depth=0 returns filled triangle

**Verify:**
- `go test ./internal/sierpinski/...` passes
```

### 3.2 Plans Assume Zero Context

From writing-plans SKILL.md:

> "Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it."

Key requirements:
- **Exact file paths always** -- never "the config file" but `exact/path/to/config.json`
- **Complete code in plan** -- not "add validation" but the actual validation code
- **Exact commands with expected output** -- not "run tests" but `pytest tests/path/test.py::test_name -v` with `Expected: FAIL with "function not defined"`
- **DRY, YAGNI, TDD, frequent commits**

The reasoning: "Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well."

### 3.3 Task Granularity -- Bite-Sized (2-5 Min Each), TDD Red-Green Steps

From writing-plans SKILL.md:

> "Each step is one action (2-5 minutes):"
> - "Write the failing test" - step
> - "Run it to make sure it fails" - step
> - "Implement the minimal code to make the test pass" - step
> - "Run the tests and make sure they pass" - step
> - "Commit" - step

The granularity serves two purposes:
1. Subagents work best with focused, bounded tasks
2. Each commit creates a verifiable checkpoint

File structure is mapped before tasks are defined: "Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in."

### 3.4 Plan Review Loop

After writing the complete plan:

1. Dispatch a single **plan-document-reviewer** subagent with:
   - Path to the plan document
   - Path to the spec document
   - "Precisely crafted review context -- never your session history"

2. The reviewer checks:
   - **Completeness**: TODOs, placeholders, incomplete tasks, missing steps
   - **Spec Alignment**: Plan covers spec requirements, no major scope creep
   - **Task Decomposition**: Tasks have clear boundaries, steps are actionable
   - **Buildability**: "Could an engineer follow this plan without getting stuck?"

3. Returns: `Approved` or `Issues Found`

4. If Issues Found: fix issues, re-dispatch reviewer
5. If loop exceeds 3 iterations: surface to human
6. Reviewers are advisory: "explain disagreements if you believe feedback is incorrect"

### 3.5 Design Document -> Plan -> Execution Handoff Flow

The complete handoff:

1. **Brainstorming** produces a design doc at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
2. Design doc passes spec review loop (spec-document-reviewer, max 3 iterations)
3. User reviews and approves the written spec (explicit human gate)
4. Brainstorming invokes **writing-plans** skill
5. **writing-plans** produces a plan at `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
6. Plan passes plan review loop (plan-document-reviewer, max 3 iterations)
7. Plan offers execution choice:
   - **Subagent-driven** (recommended): invoke subagent-driven-development skill
   - **Inline execution**: invoke executing-plans skill
8. Execution proceeds task by task with review gates
9. After all tasks: **finishing-a-development-branch** skill handles integration

---

## 4. Session Lifecycle and Hooks

### 4.1 Session-Start Hook -- How using-superpowers Content Is Injected

The `hooks/session-start` shell script runs on every session start. It:

1. Reads the full content of `skills/using-superpowers/SKILL.md`
2. JSON-escapes the content
3. Wraps it in an `<EXTREMELY_IMPORTANT>` XML tag with the preamble: "You have superpowers."
4. Outputs it as structured JSON for context injection

The exact injection format (from `hooks/session-start`):

```
<EXTREMELY_IMPORTANT>
You have superpowers.

**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**

[full SKILL.md content]
</EXTREMELY_IMPORTANT>
```

The script handles platform detection:
- **Cursor**: checks for `CURSOR_PLUGIN_ROOT` env var, outputs `additional_context` field
- **Claude Code**: checks for `CLAUDE_PLUGIN_ROOT` env var, outputs `hookSpecificOutput.additionalContext` field
- **Other platforms**: falls back to `additional_context`

### 4.2 Plugin Distribution Model

Superpowers is distributed as a plugin for multiple platforms:

**Claude Code** (`.claude-plugin/plugin.json`):
```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "version": "5.0.5",
  "skills": not present in this manifest (uses skills directory convention)
}
```

**Cursor** (`.cursor-plugin/plugin.json`):
```json
{
  "name": "superpowers",
  "displayName": "Superpowers",
  "version": "5.0.2",
  "skills": "./skills/",
  "agents": "./agents/",
  "commands": "./commands/",
  "hooks": "./hooks/hooks-cursor.json"
}
```

Both platforms use the same skills directory but different hook wiring:
- Claude Code: `hooks/hooks.json` with `SessionStart` event
- Cursor: `hooks/hooks-cursor.json` with `sessionStart` event

### 4.3 How This Ensures Every Session Starts with the Right Discipline

The hook system guarantees that:

1. **Every session** (new, clear, compact) receives the using-superpowers content
2. The agent sees `<EXTREMELY_IMPORTANT>` framing before processing any user message
3. The 1% rule is loaded into context before the agent can rationalize skipping it
4. The skill priority system and red flags table are immediately available

This is the enforcement mechanism: you cannot opt out of discipline because the discipline instructions arrive before your first thought.

### 4.4 hooks.json Format

**Claude Code** (`hooks/hooks.json`):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

The `matcher` field triggers on session startup, clear, and compact events. `async: false` ensures the hook completes before the session begins, guaranteeing the context is injected before any user interaction.

**Cursor** (`hooks/hooks-cursor.json`):
```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "command": "./hooks/session-start"
      }
    ]
  }
}
```

Simpler format for Cursor, same effect.

---

## 5. Principles to Port to Orchestrator

### 5.1 Mandatory Skill Activation Prevents Corner-Cutting

The orchestrator must ensure that discipline is not optional. The Superpowers approach: inject discipline instructions before the agent's first response, use `<EXTREMELY_IMPORTANT>` framing, and provide a red flags table so agents can self-check rationalization.

**Key mechanism:** The 1% rule. "If you think there is even a 1% chance a skill might apply... you ABSOLUTELY MUST invoke the skill." This prevents all forms of "this is too simple for process."

**Porting implication:** The speckit-orchestrator's command system should enforce pipeline stages (design, plan, execute, review) the way Superpowers enforces skill activation -- as non-negotiable prerequisites, not optional add-ons.

### 5.2 HARD-GATE on Design Before Code

The `<HARD-GATE>` in brainstorming prevents implementation before design approval. This is not a suggestion -- it is an XML-tagged structural constraint.

**Key mechanism:** "Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity."

**Porting implication:** The orchestrator should have explicit gates between pipeline stages. A plan cannot be created without an approved spec. Code cannot be written without an approved plan. These gates should be structural (enforced by the system), not behavioral (enforced by instructions).

### 5.3 Zero-Context Plans for Dispatch

Plans are written assuming the implementer has zero context. This is the key to making subagent dispatch work: the plan IS the context.

**Key requirements from writing-plans:**
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills
- DRY, YAGNI, TDD, frequent commits

**Porting implication:** The orchestrator's plan format should be a contract -- a self-contained document that a fresh subagent can execute without reading any other files. The orchestrator constructs the prompt by pasting the task text, not by telling the subagent to read a file.

### 5.4 Fresh Subagent Per Task with Constructed Context

Each task gets a fresh subagent. The controller never shares its session history. Instead, it constructs exactly what the subagent needs.

**Key principle from subagent-driven-development:** "They should never inherit your session's context or history -- you construct exactly what they need."

**Porting implication:** The orchestrator is the context curator. For each task dispatch, it assembles:
- Full task text (pasted, not file-referenced)
- Scene-setting context (where this fits in the plan)
- Relevant constraints and patterns
- Explicit invitation to ask questions before starting

### 5.5 Two-Stage Review (Spec Compliance + Code Quality)

Two separate reviews, in mandatory order:

1. **Spec compliance** (did they build the right thing?): catches over-building (YAGNI violations) and under-building (missing requirements)
2. **Code quality** (did they build it right?): catches implementation issues

The spec reviewer is explicitly told: "CRITICAL: Do Not Trust the Report. The implementer finished suspiciously quickly."

**Porting implication:** The orchestrator should implement both review stages. Spec compliance review is the gate -- code quality review only fires after spec compliance passes. The spec reviewer should be adversarial by design.

### 5.6 Verification as Iron Law

From verification-before-completion: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"

The gate function:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
5. ONLY THEN: Make the claim

**Porting implication:** The orchestrator should never accept "DONE" from a subagent without independent verification. After each task, the orchestrator should run the verification command itself and compare output to expectations. Agent self-reports are inputs to investigation, not evidence of completion.

### 5.7 Status Codes for Task Completion (DONE / CONCERNS / NEEDS_CONTEXT / BLOCKED)

Four defined statuses with specific orchestrator responses:

| Status | Meaning | Orchestrator Response |
|--------|---------|----------------------|
| DONE | Task complete | Proceed to spec review |
| DONE_WITH_CONCERNS | Complete but doubts | Assess concerns before review |
| NEEDS_CONTEXT | Missing information | Provide context, re-dispatch |
| BLOCKED | Cannot complete | Escalation ladder: more context -> more capable model -> break task smaller -> escalate to human |

**Porting implication:** The orchestrator must handle all four statuses. It must never ignore BLOCKED or force retry without changes. The escalation ladder (context -> model upgrade -> task decomposition -> human) is a critical pattern for autonomous operation.

---

## Appendix: File Inventory

### Skill Files Read
- `skills/using-superpowers/SKILL.md` -- Meta-skill, mandatory activation
- `skills/brainstorming/SKILL.md` -- Design-before-code pipeline
- `skills/brainstorming/spec-document-reviewer-prompt.md` -- Spec review prompt template
- `skills/writing-plans/SKILL.md` -- Zero-context plan authoring
- `skills/writing-plans/plan-document-reviewer-prompt.md` -- Plan review prompt template
- `skills/subagent-driven-development/SKILL.md` -- Fresh subagent per task orchestration
- `skills/subagent-driven-development/implementer-prompt.md` -- Implementer dispatch template
- `skills/subagent-driven-development/spec-reviewer-prompt.md` -- Spec compliance review template
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md` -- Code quality review template
- `skills/verification-before-completion/SKILL.md` -- Evidence-before-claims enforcement
- `skills/executing-plans/SKILL.md` -- Fallback inline execution
- `skills/dispatching-parallel-agents/SKILL.md` -- Independent task parallelization
- `skills/test-driven-development/SKILL.md` -- RED-GREEN-REFACTOR enforcement
- `skills/systematic-debugging/SKILL.md` -- 4-phase root cause process
- `skills/requesting-code-review/SKILL.md` -- Pre-review dispatch protocol
- `skills/receiving-code-review/SKILL.md` -- Review reception protocol
- `skills/using-git-worktrees/SKILL.md` -- Workspace isolation
- `skills/finishing-a-development-branch/SKILL.md` -- Branch completion workflow
- `skills/writing-skills/SKILL.md` -- Meta-skill for creating skills (TDD applied to documentation)

### Supporting Files Read
- `tests/subagent-driven-dev/svelte-todo/plan.md` -- Concrete plan example (12 tasks)
- `tests/subagent-driven-dev/svelte-todo/design.md` -- Concrete design example
- `tests/subagent-driven-dev/go-fractals/plan.md` -- Concrete plan example (10 tasks)
- `tests/subagent-driven-dev/go-fractals/design.md` -- Concrete design example
- `agents/code-reviewer.md` -- Code reviewer agent definition
- `hooks/hooks.json` -- Claude Code hook registration
- `hooks/hooks-cursor.json` -- Cursor hook registration
- `hooks/session-start` -- Session start hook script
- `hooks/run-hook.cmd` -- Cross-platform hook runner
- `.claude-plugin/plugin.json` -- Claude Code plugin manifest
- `.cursor-plugin/plugin.json` -- Cursor plugin manifest
- `package.json` -- npm package metadata (v5.0.5)
