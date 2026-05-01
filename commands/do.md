---
description: "Use when invoking a one-shot task — runs the M024 classifier, dispatches a Tier A degenerate task with Quick-profile knowledge inject, hands Tier A+ tasks to the P02 research → plan → build chain, or routes Tier B/C tasks to orchestrator:specify."
---

# orchestrator:do <task>

The universal entry point for one-shot work. Lowers adoption friction for
small tasks: the operator types `orchestrator:do "fix the typo in foo"`
and the orchestrator decides whether the input is small enough to
fast-path (Quick-profile knowledge inject), middle-sized enough for the
Tier A+ research → plan → build chain, or large enough that it deserves
the full SDD flow (`orchestrator:specify` / `orchestrator:evaluate`).

This command is a thin authoring surface over the backing driver script
`scripts/intake/do-entry.sh`. The driver is a one-shot — it runs the
M024 classifier, picks one of four routing branches, optionally invokes
one downstream script, and exits. There is no auto-loop, no state
machine, no resume.

The command is registered as `orchestrator:do <task>` because Claude
Code slash-commands are verb-prefixed at launch (per AD-6). The
verbless `orchestrator <task>` form is reserved for the post-M009
multi-runtime parity audit when CC, Codex CLI, and Cursor all support
the same invocation shape.

## Prerequisites / State Check

The orchestrator must already be initialized in the project. Verify:

```bash
test -d .orchestrator
```

If non-zero, run `orchestrator:init` first. The driver script also
inspects `.orchestrator/config.yml` (when present) and falls back to
`templates/orchestrator-config-default.yml` for the
`entry_routing_confidence_floor` knob; the bundled default 0.7 ships
with the orchestrator skill, so even a freshly-initialized project
without a project-local override resolves the floor.

## Core Workflow

The driver implements a four-branch routing table. The branches are
applied in order, first-match wins.

| Classifier output (verdict / confidence)       | Branch                | Action                                                                                    | Approval prompts |
|------------------------------------------------|-----------------------|-------------------------------------------------------------------------------------------|------------------|
| `tier_a_plus` (any confidence)                 | tier-a-plus-handoff   | exec `route-to-dispatch.sh --verdict tier_a_plus --task <desc> [--yes] [--dispatch-stub]` | one (P02 prompt; `--yes` skips) |
| `idea` (high) OR short `paragraph` (high)      | tier-a-degenerate     | invoke `build-context.sh --profile=quick --task-plan <plan> --out <pl> --meta-out <sc>` then emit `doing: <task> — knowledge: <N> MEMs / <X> tokens` to stderr; agent runtime adapter takes over (MEM018) | zero |
| `fragment` / `spec` / long `paragraph` (high)  | tier-bc-passthrough   | emit `route=tier_bc passthrough=orchestrator:specify` to stderr; exit 0 (operator runs the named command in their next turn — NG-6 one-shot discipline) | zero |
| any verdict with confidence below floor        | low-conf-prompt       | render explicit Tier A vs Tier B question to stderr; record `chosen_shape` in JSONL `unit_close` | one |

### Confidence-floor numeric mapping (A-2 closure)

The classifier `shape-detect.sh` emits `shape_classification=high|low`
(an enum). The `entry_routing_confidence_floor` knob is numeric (P00
default `0.7`). The driver maps the enum to a numeric:

- `high` → `1.0`
- `low` → `0.5`

…and applies the comparison `numeric_confidence >= floor`. `high` (1.0)
clears the default floor 0.7; `low` (0.5) does not. This grounds the
knob in the active classifier surface without modifying M024 to emit a
numeric. Future demand can extend M024 to emit a numeric without
invalidating this entry — the mapping is a forward-compatible adapter.

### Word-band split for Tier A degenerate vs Tier B/C

After the `tier_a_plus` verdict has been peeled off (the Tier A+ branch
handles the 30–80 word band with zero structural markers), the
remaining verdicts split by word count:

- `idea` (≤10 words) → Tier A degenerate fast-path.
- `paragraph` (11–29 words) → Tier A degenerate fast-path.
- `paragraph` (>30 words) → Tier B/C passthrough (the operator likely
  intended a more complex task; route to `orchestrator:specify`).
- `fragment` (structural markers OR ≥81 words) / `spec` (full spec
  shape) / `empty` → Tier B/C passthrough.

## Output

### Tier A degenerate fast-path

One stderr line of the form:

```
doing: <task> — knowledge: <N> MEMs / <X> tokens
```

…where `<N>` is the AD-11 sidecar `mem_count` field and `<X>` is the
AD-11 sidecar `total_tokens` field. The dispatch payload + sidecar are
written to disk; the agent runtime takes over (MEM018) — production
execution requires the agent runtime to read the payload + execute.

### Tier A+ handoff

The driver execs `route-to-dispatch.sh --verdict tier_a_plus`. The
P02 router emits its own audit lines and chains research → approval →
plan → build dispatches. See `commands/dispatch.md` and the P02 router
internals for the chain output.

### Tier B/C passthrough

Two stderr lines:

```
route=tier_bc passthrough=<surface>
do-entry: this task is too large for a single dispatch — invoke <surface> in your next turn.
```

…where `<surface>` is `orchestrator:specify` (default) or
`orchestrator:evaluate` (empty input). Exit 0 — the operator runs the
named command in their next turn (NG-6 one-shot discipline).

### Low-confidence prompt

A multi-line prompt to stderr describing the Tier A vs Tier B choice,
plus a JSONL `unit_close` record appended to
`.orchestrator/observability/dispatch-log.jsonl` (or the
`ORCH_DO_ENTRY_LOG` override path) with the operator's `chosen_shape`.

## Idempotency

The entry is one-shot (NG-6). There is no state machine, no lock file,
no `.orchestrator/milestones/M###/` scaffolding write. Re-running
`orchestrator:do "<task>"` with the same input simply re-runs the
classifier and re-dispatches — there is nothing to resume.

## Error Handling

Non-zero exit reasons:

- `64` — usage error (missing `--task`, unknown flag).
- non-zero from `build-context.sh` on the Tier A degenerate fast-path
  (the driver prints `do-entry: build-context.sh exited <rc> on
  tier_a_degenerate fast-path` and returns the same `<rc>`).
- non-zero from `route-to-dispatch.sh` on the Tier A+ handoff (the
  driver returns the router's exit code unchanged).
- `2` — operator cancel at the low-confidence prompt (response `C` or
  timeout).

The driver does not retry on its own. The agent runtime (or the
operator) is responsible for re-invoking after fixing the underlying
issue.

## Referenced Scripts/Templates

- `scripts/intake/do-entry.sh` — backing driver. Implements the
  four-branch routing table and the FR-12 stderr summary line.
- `scripts/intake/shape-detect.sh` — M024 classifier (verdict +
  confidence enum).
- `scripts/intake/route-to-dispatch.sh` — P02 Tier A+ middle-flow
  router (research → approval → plan → build chain).
- `scripts/dispatch/build-context.sh` — P01 direct-mode driver
  (Quick-profile knowledge inject + AD-11 sidecar).
- `templates/orchestrator-config-default.yml` — P00 pinned defaults
  (`entry_routing_confidence_floor: 0.7`,
  `quick_knowledge_token_budget: 800`,
  `tier_a_plus_prompt_summary_lines: 8`, `auto_proceed: true`).
