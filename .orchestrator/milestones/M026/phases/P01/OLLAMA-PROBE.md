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

result=absent
ollama_path=N/A
ollama_version=N/A
models_present=N/A

## Pipx venvs

oss_venv_path=N/A
oss_venv_python_present=false
oss_venv_conversus_binary_present=false

paid_venv_path=/Users/brettkellgren/.local/pipx/venvs/conversus
paid_venv_python_present=true
paid_venv_conversus_binary_present=true

## P02 Fallback Posture (OQ-3 + OQ-5 resolution)

- FR-8 OSS-branch provider: skip-on-429
- When ollama is absent, FR-8 OSS-branch marks the skip with `known-upstream-429`
  annotation per M026-CONTEXT.md follow-up.
- FR-8 venv-python lookup extends the fallback chain at
  `tests/test-conversus-adapter-shim.sh:119-124` to probe BOTH paths recorded
  above, in edition-aware order. On this operator machine only the paid venv
  exists; the OSS venv is absent and FR-8 must handle the N/A case without
  erroring (treat as "OSS venv not installed — skip OSS-branch invocation
  with skip-on-429 + known-upstream-429 annotation").

## Probe Notes

- `command -v ollama` returned non-zero (ollama not on PATH); this is the
  canonical "absent" signal per the task plan Steps.1 fallback rule.
- `ls ~/.local/pipx/venvs/` returned a single entry: `conversus`. No
  `conversus-oss` sibling exists at this time.
- Paid venv binaries confirmed via direct `ls -l`:
  - `~/.local/pipx/venvs/conversus/bin/python` -> symlink to `python3.14` (present).
  - `~/.local/pipx/venvs/conversus/bin/conversus` -> 198-byte executable (present).
- No writes to `~/.local/pipx/venvs/` or `~/Sites/conversus*` trees; no
  network invocations; no ollama model pulls.
