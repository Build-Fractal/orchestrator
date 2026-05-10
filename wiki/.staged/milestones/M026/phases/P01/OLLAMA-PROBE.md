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

## Addendum: 2026-04-23T22:50 PT post-verify install

After P01 verification passed, the operator ran `pipx install conversus`
against the OSS tree. This changed the pipx-venv state captured above.
The T03 probe lines remain as the historical T03-time snapshot for gate
stability; the current state as of this addendum is:

- OSS is now installed at `~/.local/pipx/venvs/conversus/` (same path the
  T03 probe labeled as "paid"). Package `conversus 0.3.0`, editable at
  `~/Sites/conversus-oss`, Home-page `github.com/Build-Fractal/conversus-oss`.
  Binaries: `conversus` + `conversus-lint`.
- Paid is uninstalled (displaced by the OSS install under the same
  package name `conversus`).

### Updated P02 Fallback Posture (supersedes the OQ-5 lookup chain above)

The dual-venv fallback chain (OSS path + paid path) assumed path-based
edition separation. That assumption is wrong: both editions install to
the same path. P02's edition-detection strategy must not rely on venv
path — see `M026-CONVERSUS-PARITY.md` § Addendum "P02 edition-detection
strategy" for the recommended `CONVERSUS_EDITION=oss|paid` env-var primary
+ `pip show` metadata fallback.

FR-8 OSS-branch test still uses `skip-on-429` with `known-upstream-429`
annotation (OQ-3 unchanged — ollama remains absent).
