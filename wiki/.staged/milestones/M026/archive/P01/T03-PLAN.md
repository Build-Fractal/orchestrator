---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M026"
name: "Ollama + pipx-venv environment probes"
depends_on: []
---

## Prerequisites

- Operator machine has the pipx-installed conversus venvs on disk somewhere under `~/.local/pipx/venvs/`.
- Optional: operator has ollama installed. The probe records presence or absence — absence is not a T03 failure, it feeds the fallback decision into T04's phase-suite outputs and P02 plan-phase scope.

## Description

Probe the operator's local environment for two pre-planning inputs P02 needs:

1. **Ollama availability** (resolves OQ-3 plan-phase follow-up from M026-CONTEXT.md). Per the finalized discuss-draft, P02's FR-8 OSS-branch uses ollama as the integration-test provider. If ollama is absent, the fallback is `skip-on-429` with an explicit `known-upstream-429` annotation. T03 answers which path P02 takes.

2. **Pipx venv path inventory** (resolves OQ-5 plan-phase follow-up). The existing integration test's venv-python lookup at `tests/test-conversus-adapter-shim.sh:119-124` assumes a single path. P02's FR-8 extension needs both editions' venv paths — or a confirmed single-path reality if only one exists on this machine.

Neither probe modifies the operator machine. Both are read-only probes that capture observations to a data-artifact the P02 plan-phase consumes.

## Steps

1. **Probe ollama.** Run the probe helper (create it as part of this task inline, via `Bash` tool invocations — not a new repo-committed script unless useful):

   - Check PATH: `command -v ollama 2>/dev/null` → capture exit + output.
   - If present, check version: `ollama --version 2>&1 | head -n 1`.
   - If present, list local models: `ollama list 2>&1 | head -n 20` (captures the models-present line for the probe report).
   - If `command -v ollama` returns non-zero, the probe records `result=absent`.
   - If the operator explicitly declines to use ollama (e.g., documented preference for skip-on-429), the probe records `result=skipped-operator-choice` — T03 agent decides this only if the operator has surfaced such a preference via conversation or a README; default behavior is to record `available` or `absent` based on `command -v`.

2. **Probe pipx venvs.** Inspect `~/.local/pipx/venvs/` for conversus-related venvs:

   - `ls ~/.local/pipx/venvs/ 2>&1` — list top-level venv directory names.
   - For each venv name matching `conversus*`, check `ls -l <venv>/bin/python` and `ls -l <venv>/bin/conversus` to confirm the venv has the conversus install.
   - Record BOTH edition paths: the OSS venv (expected under `conversus-oss/` if present) and the paid venv (expected under `conversus/` if present). Record `present` or `absent` for each.

3. **Author `OLLAMA-PROBE.md`** at [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md):

   ```markdown
   ---
   schema_version: "1.0"
   type: probe-report
   phase: "P01"
   task: "T03"
   milestone: "M026"
   created_at: "2026-04-23"
   ---

   # Ollama + pipx-venv environment probe

   ## Ollama

   result=<available|absent|skipped-operator-choice>
   ollama_path=<resolved-path-or-N/A>
   ollama_version=<version-or-N/A>
   models_present=<comma-separated-list-or-N/A>

   ## Pipx venvs

   oss_venv_path=<~/.local/pipx/venvs/conversus-oss or N/A>
   oss_venv_python_present=<true|false>
   oss_venv_conversus_binary_present=<true|false>

   paid_venv_path=<~/.local/pipx/venvs/conversus or N/A>
   paid_venv_python_present=<true|false>
   paid_venv_conversus_binary_present=<true|false>

   ## P02 Fallback Posture (OQ-3 + OQ-5 resolution)

   - FR-8 OSS-branch provider: <ollama|skip-on-429>
   - When ollama is absent, FR-8 OSS-branch marks the skip with `known-upstream-429`
     annotation per M026-CONTEXT.md follow-up.
   - FR-8 venv-python lookup extends the fallback chain at
     `tests/test-conversus-adapter-shim.sh:119-124` to probe BOTH paths recorded
     above, in edition-aware order.
   ```

## Must-Haves

This task satisfies the phase truths:
- "OLLAMA-PROBE.md exists with required frontmatter + result= line" (ollama-probe truth).
- "pipx venv path inventory captured for both editions" (pipx-venv-inventory truth — T03 produces the standalone probe report; T01's matrix row for pipx-venv also references this data).

## Verification

```
bash scripts/verify/m026-p01-ollama-probe.sh
bash scripts/verify/m026-p01-pipx-venv-inventory.sh
```

Each verifier uses single-script-file shape per AD-19.

Expected: `SUMMARY: pass=N fail=0` per script, exit 0.

## Inputs

### From Previous Tasks
- None (T03 runs in parallel with T01 + T02).

### From Disk (Pre-existing)
- `~/.local/pipx/venvs/` — pipx venv root (read-only).
- System `PATH` for ollama detection (read via `command -v`).
- [`.orchestrator/milestones/M026/M026-CONTEXT.md`](../../../../milestones/M026/M026-CONTEXT.md) OQ-3 + OQ-5 sections (read for rationale).

## Constraints

- **Read-only probes**: no writes to `~/.local/pipx/venvs/`, no ollama model pulls, no network invocations.
- **Result vocabulary is fixed** for the Ollama result line: `{available, absent, skipped-operator-choice}`. Free-form values fail the ollama-probe gate.
- **Both edition paths must be recorded** even when one is absent. Absent editions record `N/A` on the path line and `false` on the `_present` lines, not empty strings.

## Expected Output

- [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md) — probe report (15+ lines) with ollama block + pipx block + P02 fallback posture section.
- Zero new files elsewhere.
