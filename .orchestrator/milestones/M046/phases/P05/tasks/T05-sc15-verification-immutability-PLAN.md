---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M046"
name: "SC-15 live non-stubbed verification-integrity harness (milestone-blocking)"
depends_on: [T03]
---

## Prerequisites

- T02 complete: production hook installs via the M028 path.
- T03 complete: `envelope_write_scope_policy` composes a policy whose `readonly_path` lines cover the SC/harness/scoring surface (`specs/`, `tools/verify/`, `scripts/verify/`, `scripts/hooks/`, the roadmap, the policy file, and the P07 ledger forward-slot).
- T01 complete: the hook's `readonly_path` semantics — deny Edit/NotebookEdit unconditionally; deny Write when the target already exists; pass Write to a not-yet-existing path.

## Description

Author the SC-15 milestone-blocking, NON-STUBBED harness
`tools/verify/m046-p05-sc15-verification-immutability.sh`. It proves the CON-7 separation-of-
doing-and-scoring invariant: a real unattended child, driven through the LIVE installed hook,
CANNOT modify (a) a success-criterion definition, (b) the verification harness, or (c) its own
scoring record — while it CAN still write a legitimate work-dir artifact (the protected surface is
scoped, not a blanket milestone-dir deny). Same honest-realism model as T04 (real install wiring +
real per-run policy + real hook contract; no stub in the enforcement path).

## Steps

1. Create `tools/verify/m046-p05-sc15-verification-immutability.sh` (project-owned). Structure:
   - `set -u`; `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`.
   - `SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046-p05-sc15.XXXXXX")"`; `trap 'rm -rf "$SCRATCH"' EXIT`.
   - `HOME_ISO="$SCRATCH/home"; mkdir -p "$HOME_ISO/.claude"`; `PROJ="$SCRATCH/project"; mkdir -p "$PROJ"`.
   - **Safety self-check** (same as T04): assert `$HOME_ISO` is under `$SCRATCH` or fail-fast.
   - Install via `HOME="$HOME_ISO" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" --project-dir "$PROJ"`; resolve `GUARD="$HOME_ISO/.claude/orchestrator-hooks/unattended-scope-guard.sh"`; assert `-x`.
   - **Build a representative protected surface under `$PROJ`** so the readonly_path prefixes have
     real files to protect (the composition's readonly_path lines are `<project-root>/<glob>`):
     - `mkdir -p "$PROJ/specs/047-x"; printf 'Success Criteria\n' > "$PROJ/specs/047-x/spec.md"` (an SC definition).
     - `mkdir -p "$PROJ/tools/verify"; printf '#!/bin/sh\nexit 0\n' > "$PROJ/tools/verify/m046-p05-phase-suite.sh"` (an existing verification harness file).
     - The scoring record: `mkdir -p "$PROJ/.orchestrator/milestones/M046/phases/P05"`; create the
       P07 ledger forward-slot file so it is protected in this test:
       `printf 'ledger\n' > "$PROJ/.orchestrator/milestones/M046/phases/P05/.self-continue-attempts-ledger"`
       (and note: T03's composition emits the ledger `readonly_path` line only when the file
       exists — this harness creates it, so the readonly line is emitted).
     - A legitimate work-dir target dir: `mkdir -p "$PROJ/.orchestrator/milestones/M046/phases/P05"` (already created; the summary write below targets a NEW file there).
   - **Compose the real policy** via T03's function, rooted at `$PROJ`:
     `envelope_write_scope_policy "$SCRATCH/policy" "$PROJ" "$REPO_ROOT/scripts/hooks/unattended-protected-surface.txt" "$PROJ/.orchestrator/milestones/M046/phases/P05" "$SCRATCH/NO-ROADMAP.md" ""`.
     Then APPEND the ledger readonly line explicitly if the composition placed it as a
     forward-slot comment (the ledger lives under the milestone dir passed as `<milestone-dir>`,
     so `envelope_write_scope_policy` emits its real `readonly_path` line because the file exists).
   - Write the four PreToolUse payloads into `$SCRATCH` (substitute real `$PROJ`):
     - `edit-sc.json` — `{"tool_name":"Edit","tool_input":{"file_path":"$PROJ/specs/047-x/spec.md"}}`.
     - `edit-harness.json` — `{"tool_name":"Edit","tool_input":{"file_path":"$PROJ/tools/verify/m046-p05-phase-suite.sh"}}`.
     - `write-scoring.json` — `{"tool_name":"Write","tool_input":{"file_path":"$PROJ/.orchestrator/milestones/M046/phases/P05/.self-continue-attempts-ledger","content":"cheat"}}` (Write over an EXISTING scoring record ⇒ deny).
     - `write-summary.json` — `{"tool_name":"Write","tool_input":{"file_path":"$PROJ/.orchestrator/milestones/M046/phases/P05/P05-SUMMARY.md","content":"ok"}}` (legitimate NEW work-dir artifact ⇒ pass).
   - **Milestone-blocking DENY leg** (`ORCHESTRATOR_UNATTENDED=1`, real policy, LIVE hook):
     - `edit-sc`       → exit 2  (SC definition)
     - `edit-harness`  → exit 2  (verification harness)
     - `write-scoring` → exit 2  (own scoring record, overwrite of existing)
     - `write-summary` → exit 0  (legitimate work-dir write — protected surface is scoped)
     Emit `case=<name> surface=<sc|harness|scoring|control> expected=<e> actual=<a> result=PASS|FAIL`.
   - Final `SUMMARY: pass=<p> fail=<f>`; `exit 0` iff `fail==0` AND all three DENY cases denied.

## Must-Haves

- Truth: SC-15 — a real unattended child editing an SC definition, the verification harness, or its own scoring record is BLOCKED; a legitimate work-dir Write passes.
- Artifact: `tools/verify/m046-p05-sc15-verification-immutability.sh` (min 60 lines, contains "readonly_path").

## Verification

```bash
bash tools/verify/m046-p05-sc15-verification-immutability.sh
```

## Inputs

### From Previous Tasks
- `scripts/lifecycle/unattended-envelope.sh::envelope_write_scope_policy` (T03) — emits the `readonly_path` lines (incl. the ledger when it exists); signature `(<policy> <project-root> <manifest> <milestone-dir> <roadmap> <phase-plan>)`.
- `scripts/hooks/unattended-scope-guard.sh` (T01) — `readonly_path` semantics: deny Edit; deny Write-if-exists; pass Write-to-new; `allow_path` covers `<project-root>/` so the summary write passes.
- `scripts/hooks/unattended-protected-surface.txt` (T01) — the generic globs (`specs/`, `tools/verify/`, `scripts/verify/`, `scripts/hooks/`).
- T02 install wiring — the real installer/adapter.

### From Disk (Pre-existing)
- `.orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh` — drive shape.

## Constraints

- **Isolated scratch HOME, always** — mandatory self-check; real `~/.claude` never touched.
- NON-STUBBED: real installer + real composed policy + real hook; no seeded exit codes.
- The `write-summary` control is REQUIRED — it proves the readonly surface is scoped (the child
  keeps writing legitimate artifacts); a harness that only proves denials could mask a
  blanket-deny regression that would break real unattended execution.
- Bash 3.2 compatible; invoked directly (no `run-probe.sh`).

## Expected Output

`bash tools/verify/m046-p05-sc15-verification-immutability.sh` prints a `case=...` line per
surface, the three protected surfaces DENY (`result=PASS`), the control passes, and
`SUMMARY: pass=N fail=0`, exit 0.
