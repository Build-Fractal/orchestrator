# downstream-project — permanent in-tree consumer fixture

This directory is a **permanent regression fixture** (CON-10, M028) shaped like
a minimal consumer of the orchestrator skill bundle. It is checked into
version control and is **not** generated at test time.

## Purpose

The fixture's `.claude/settings.json` is a contract reference for the runtime
adapter's `--hook-config` emission shape. It mirrors what
`scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` produces:

- A `Stop` hook entry pointing at `after-verify-sync.sh` under
  `~/.claude/orchestrator-hooks/`.
- A `PreToolUse` hook entry (matcher `Bash`) pointing at
  `pre-bash-shape-guard.sh` and `before-commit.sh` under the same runtime-stable
  directory.
- Every leaf hook object carries `_orchestrator_managed: true` (M025 invariant —
  the install/uninstall logic uses this flag to identify managed entries).

The fixture writes the literal `${HOME}` placeholder (rather than an expanded
path) so the bytes are HOME-agnostic and the shape verifier compares the
*pattern* `bash <...>.sh` rather than the literal expansion.

## Noisy-fail discipline (CON-10)

If the runtime adapter's emission shape drifts — e.g., a new hook event lands,
a `matcher` value changes, a hook leaf basename is renamed —
`scripts/verify/m028/p05-downstream-fixture-shape.sh` fails loudly. The fix
is to update this fixture to match the new adapter emission, **not** to
loosen the verifier. The whole point of the permanent fixture is that drift
is caught at CI time rather than discovered downstream.

## Cross-references

- `scripts/dispatch/adapters/runtime/claude-code.sh` — canonical runtime adapter
  whose `--hook-config` mode produces the contract reference shape mirrored here.
- `scripts/verify/m028/p05-downstream-fixture-shape.sh` — shape-compatibility
  gate (asserts every `command` is `bash <...>.sh`, every leaf carries
  `_orchestrator_managed: true`, and the count of `command` keys + managed
  flags matches the adapter's live emission).
- `scripts/verify/m028/p05-fixture-permanent.sh` — existence-only Truth-Check
  for this fixture's presence under version control.
- `tests/run-downstream-fixture.sh` — T02 autonomous-loop replay harness
  consuming this fixture.
