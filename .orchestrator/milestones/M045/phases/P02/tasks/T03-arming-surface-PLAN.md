---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M045"
name: "Document the --self-continue arming surface in commands/auto.md"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `scripts/lifecycle/self-continue-branch.sh` exists.

## Description

Document the self-continue arming surface (spec FR-1 + CON-4) in `commands/auto.md`: an explicit, per-run `--self-continue` opt-in that defaults OFF, plus how the (P03) rotation branch will consult armed state + the `headless_reentry` capability via `self-continue-branch.sh`. P02 is DOCUMENTATION ONLY — it must NOT change the live rotation-exit behavior (that wiring is P03). This preserves legacy parity (FR-8) until P03.

## Steps

1. Add a new section to `commands/auto.md` (place it near the top-of-file invocation/flags area, or immediately before the `## Completion` section — wherever flags are described). Content:
   ```markdown
   ## Self-Continue (M045 — process-fresh re-entry)

   `orchestrator:auto` accepts an explicit, per-run opt-in `--self-continue`
   (default: OFF — spec CON-4; no config key may make it the silent default).
   When ARMED and the runtime reports the `headless_reentry` capability
   (`detect-capabilities.sh`), the loop, instead of exiting for a human at a
   context-rotation boundary, hands off to a **process-fresh `claude -p`
   re-entry** that resumes the next phase from disk and keeps advancing until a
   terminal state (milestone complete / blocker / budget / stuck / pause).

   The self-continue-vs-legacy-exit decision is deterministic and lives in
   `scripts/lifecycle/self-continue-branch.sh` (the agent only acts on its
   directive):

   - `AUTO:SELF_CONTINUE` — rotation AND armed AND headless-capable → spawn a
     fresh `claude -p` re-entry (wired in P03).
   - `AUTO:ROTATE_EXIT reason=not-armed|headless-unavailable` — fall back to the
     legacy human-handoff (write `continue.md`, report, exit).
   - `AUTO:NO_ROTATION` — no rotation; advance normally.

   Substrate note (decision D015): the re-entry is process-fresh (a new
   `claude -p`), NOT in-session — the M045 P01 spike proved in-session re-entry
   does not relieve context per-rotation. See
   `.orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md`.

   **Status**: arming surface + decision core land in P02; the live rotation
   branch is rewired to consume `AUTO:SELF_CONTINUE` in P03. Until P03, the
   rotation-exit path behaves exactly as documented in "Context Rotation Check".
   ```
2. Author `tools/verify/m045-p02-arming-surface.sh`:
   ```sh
   #!/usr/bin/env sh
   # Checks commands/auto.md documents the --self-continue arming surface.
   set -eu
   F="commands/auto.md"
   grep -q -- "--self-continue" "$F" || { echo "FAIL: --self-continue not documented"; exit 1; }
   grep -q "self-continue-branch.sh" "$F" || { echo "FAIL: branch script not referenced"; exit 1; }
   grep -qi "default: OFF\|default OFF\|defaults OFF\|default: off" "$F" || { echo "FAIL: default-off opt-in not stated"; exit 1; }
   echo "PASS: arming surface documented"
   ```
3. `chmod +x tools/verify/m045-p02-arming-surface.sh` and run it.

## Must-Haves

- `commands/auto.md` documents `--self-continue` (default OFF, explicit opt-in), references `self-continue-branch.sh`, and states the process-fresh substrate.
- The live rotation-exit behavior in `auto.md` is UNCHANGED (P02 is doc-only).

## Verification

`bash tools/verify/m045-p02-arming-surface.sh`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-branch.sh` (from T02) — emits `AUTO:SELF_CONTINUE` / `AUTO:ROTATE_EXIT reason=...` / `AUTO:NO_ROTATION`.

### From Disk (Pre-existing)
- `commands/auto.md` — has a `## Context Rotation Check` block (~"Context Rotation Check (FR-CONTEXT)") describing today's exit-for-human behavior, and a `## Completion` section.

## Constraints

- Documentation only — do NOT edit the `## Context Rotation Check` exit logic or any other live behavior in P02.
- Keep the addition consistent with auto.md's existing heading style + tone.

## Expected Output

`commands/auto.md` gains a Self-Continue section; the arming-surface verifier prints `PASS:`.
