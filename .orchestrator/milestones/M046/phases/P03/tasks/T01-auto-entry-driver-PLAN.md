---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M046"
name: "auto-entry.sh unified classify-first entry driver"
depends_on: []
---

## Prerequisites

- `scripts/intake/do-entry.sh` exists (M031/P03/T01) — the driver being
  generalized. Verified on disk at plan time.
- `scripts/intake/shape-detect.sh` exists — the M024 classifier. Verified.
- `scripts/intake/route-to-dispatch.sh` exists — the Tier A+ router. Verified.
- `scripts/dispatch/build-context.sh` exists — the Quick-profile direct-mode
  driver. Verified.

## Description

Create `scripts/intake/auto-entry.sh` as the single unified classify-first entry
driver behind `orchestrator:auto <arg>`. It absorbs the four-branch one-shot
routing that `do-entry.sh` performs today, adds a Tier-C dir/empty front-route, and
adds an auto-native `AUTO:BLOCK_AMBIGUITY` below-floor default while preserving the
legacy do-compat interactive low-conf prompt behind a mode flag. It reuses the
three downstream scripts by path (byte-unchanged, FR-2 / CON-2) and MUST NOT touch
`auto-loop.sh`.

The cleanest way to guarantee SC-2 byte-parity is to make the high-confidence
one-shot code path in `auto-entry.sh` byte-for-byte the same logic `do-entry.sh`
runs today (moved, not reimplemented). `do-entry.sh` (T02) then becomes a thin
shim that forwards into this driver, so the parity is structural.

## Steps

1. Read `scripts/intake/do-entry.sh` in full (it is ~347 lines). It is the exact
   source of the one-shot routing you are generalizing. Preserve its:
   - CLI surface: `--task`, `--yes`, `--config`, `--dispatch-stub`,
     `--scratch-root`, `--no-prompt-mode` (all six).
   - `ORCH_DO_ENTRY_LOG` env override (keep the same env var name and the same
     default path `.orchestrator/observability/dispatch-log.jsonl` so the JSONL
     `unit_close` record on the low-conf branch is byte-identical under either
     entry).
   - `resolve_floor()` 4-layer precedence.
   - The classifier invocation + `high→1.0 / low→0.5` numeric mapping.
   - The four branch helpers verbatim: `run_tier_a_plus_handoff`,
     `run_tier_a_degenerate`, `run_tier_bc_passthrough`, `run_lowconf_prompt`
     (with `emit_unit_close_lowconf`).
   - The branch table order (tier_a_plus → below-floor → idea/short-paragraph
     degenerate → tier_bc passthrough).

2. Create `scripts/intake/auto-entry.sh`. Header comment must name it the M046/P03
   unified entry driver and cite CON-2 (reuse-not-reimplement; no `auto-loop.sh`
   change). Keep `set -u`. Bash 3.2 compatible (MEM001): no `declare -A`, no
   process substitution, no `$(...)`-containing-pipes inside conditionals.

3. Add ONE new CLI flag beyond the six do flags:
   - `--ambiguity-mode <block|prompt>` — default `block`. Only the below-floor
     branch reads it. `block` (auto-native): emit `AUTO:BLOCK_AMBIGUITY` and exit
     0 without dispatching. `prompt` (do-compat, passed by the shim): run the
     legacy `run_lowconf_prompt` exactly as `do-entry.sh` does today.
   Also accept an optional positional first arg OR `--task` for the description;
   auto is invoked as `orchestrator:auto <arg>` so the driver must accept a bare
   positional target in addition to `--task`. When a bare positional is present
   and `--task` is absent, treat the positional as the arg.

4. Front-route (BEFORE classifier invocation), in order:
   - If the resolved arg is empty (no positional, no `--task`): emit
     `AUTO:ROUTE tier=c mode=loop target=active` and exit 0. (The `commands/auto.md`
     loop flow will call `find-active-milestone.sh`; auto-entry does not run the
     loop.)
   - Else if the resolved arg is an existing directory (`[ -d "$arg" ]`): emit
     `AUTO:ROUTE tier=c mode=loop target=<arg>` and exit 0.
   - Else: the arg is a task description → fall through to the one-shot classify
     path (step 5).

5. One-shot classify path (description arg): run `shape-detect.sh --input "$arg"`,
   parse `input_shape` + `shape_classification`, apply the floor mapping, then
   execute the four-branch table. Emit exactly one `AUTO:ROUTE tier=<t> mode=one-shot`
   line to stderr BEFORE the chosen branch action, where `<t>` is:
   - `a_plus` for the `tier_a_plus` verdict branch,
   - `a` for the tier_a_degenerate branch (idea / short paragraph),
   - `b` for the tier_bc_passthrough branch.
   The below-floor branch does NOT emit `AUTO:ROUTE`; it emits either
   `AUTO:BLOCK_AMBIGUITY verdict=<v> conf=<c>` (mode=block) or runs
   `run_lowconf_prompt` (mode=prompt).

6. Preserve every branch helper's disk side effects EXACTLY (payload + AD-11
   sidecar via `build-context.sh` on the degenerate path; `route-to-dispatch.sh`
   exec on the Tier A+ path; JSONL `unit_close` on the low-conf prompt path). Do
   NOT change any downstream invocation path or argument shape — this is what
   guarantees FR-2 byte-unchanged reuse and SC-2 byte-parity.

7. `chmod +x scripts/intake/auto-entry.sh`.

## Must-Haves

- `scripts/intake/auto-entry.sh` exists, is executable, and passes `bash -n`.
- Contains the literal token `AUTO:BLOCK_AMBIGUITY` and the `AUTO:ROUTE` routing
  lines.
- Invokes `shape-detect.sh`, `route-to-dispatch.sh`, and `build-context.sh` by
  their canonical paths (`scripts/intake/shape-detect.sh`,
  `scripts/intake/route-to-dispatch.sh`, `scripts/dispatch/build-context.sh`).
- Accepts the six do flags plus `--ambiguity-mode`.
- Makes NO reference to editing or re-implementing `auto-loop.sh`.

## Verification

`test -f scripts/intake/auto-entry.sh`
`bash -n scripts/intake/auto-entry.sh`
`grep -q "AUTO:BLOCK_AMBIGUITY" scripts/intake/auto-entry.sh`
`grep -q "AUTO:ROUTE" scripts/intake/auto-entry.sh`
`grep -q "shape-detect.sh" scripts/intake/auto-entry.sh`
`grep -q "route-to-dispatch.sh" scripts/intake/auto-entry.sh`
`grep -q "build-context.sh" scripts/intake/auto-entry.sh`
`grep -q "ambiguity-mode" scripts/intake/auto-entry.sh`

## Inputs

### From Disk (Pre-existing)

- `scripts/intake/do-entry.sh` — the exact one-shot routing source. Its four
  branch helpers, `resolve_floor()`, the classifier invocation + `high→1.0/low→0.5`
  mapping, and the branch-table order are moved verbatim into auto-entry.sh.
  Six flags: `--task`, `--yes`, `--config`, `--dispatch-stub`, `--scratch-root`,
  `--no-prompt-mode`. Env: `ORCH_DO_ENTRY_LOG` (default
  `.orchestrator/observability/dispatch-log.jsonl`).
- `scripts/intake/shape-detect.sh` — call as
  `bash scripts/intake/shape-detect.sh --input "<desc>"`. Two-line stdout:
  `input_shape=<idea|paragraph|tier_a_plus|fragment|spec|empty>` +
  `shape_classification=<high|low>`. Byte-unchanged.
- `scripts/intake/route-to-dispatch.sh` — Tier A+ handoff. Invoked as
  `bash scripts/intake/route-to-dispatch.sh --verdict tier_a_plus --task "<desc>"
  [--yes] [--dispatch-stub <s>] [--scratch-root <d>]`. Byte-unchanged.
- `scripts/dispatch/build-context.sh` — degenerate fast-path. Invoked as
  `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <plan>
  --out <payload> --meta-out <sidecar>`. Byte-unchanged.

## Constraints

- FR-2 / CON-2: the three consumed scripts and `auto-loop.sh` are byte-unchanged.
  Do not edit them; invoke by path.
- MEM001: Bash 3.2. No `declare -A`, no process substitution, no
  `$(...)`-containing-pipes in conditionals.
- The high-confidence one-shot logic must be byte-equivalent to `do-entry.sh`'s so
  SC-2 parity is structural. `--ambiguity-mode` is the ONLY behavioral fork, and
  it only affects the below-floor branch (never reached by the Tier-A SC-2
  fixture).

## Expected Output

`scripts/intake/auto-entry.sh` on disk, executable, `bash -n` clean, emitting
`AUTO:ROUTE tier=c mode=loop ...` for dir/empty args, `AUTO:ROUTE tier=<a|a_plus|b>
mode=one-shot` + the corresponding do-branch action for descriptions, and
`AUTO:BLOCK_AMBIGUITY` for below-floor args under the default block mode.
