---
type: migration-scratch
captured_at: "2026-04-23"
scope: "conversus-paid → conversus-oss migration parity audit (orchestrator-consumption surface)"
status: draft
---

# Conversus-OSS Migration — Parity Matrix (scratch)

**Reading posture**: this matrix enumerates the orchestrator's *consumption* surface of
conversus — every CLI flag, env var, file-shape assumption, and exit-code contract the
adapter and its callers depend on. Filesystem inspection of `~/Sites/conversus-oss`
and `~/Sites/conversus` was **not available in this session** (sandboxed off), so
cells marked `VERIFY` are open questions for discuss-finalize. Everything else is
derived from this repo's own code + docs.

## 1. Consumption Surface (what the orchestrator actually uses)

Sources: `scripts/dispatch/adapters/tool/conversus.sh`, `scripts/dispatch/adapters/tool/conversus-synth.py`,
`tests/test-conversus-adapter-shim.sh`, `templates/conversus-presets/*.yml`,
`commands/specify.md`, `commands/ingest.md`, `commands/github-sync.md`,
`references/github-integration.md`.

### 1.1 CLI surface the adapter invokes on `conversus`

| Touch point                                              | Adapter call                                                                 | Source location                                           |
|----------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------|
| Binary resolution (4-step order)                         | `command -v conversus` → `$CONVERSUS_HOME/bin/conversus` → `~/Sites/conversus/bin/conversus` | `conversus.sh:52–82`                                      |
| Binary launcher shebang (venv python extraction)         | `head -n 1 $_bin_path` to extract `#!<venv-python>`                          | `conversus.sh:236`                                        |
| Primary invocation                                       | `conversus run <config.yml> --provider <provider>`                           | `conversus.sh:273`                                        |
| Provider selection                                       | `CONVERSUS_PROVIDER=anthropic` (default) or `claude-code` / `mock`           | `conversus.sh:272`; `tests/...shim.sh:167`                |
| Output-contract linter (via venv python)                 | `python -m linter.output_contract <synthesis> --mode <mode>` → JSON with `quality_indicators.genuine_disagreements_surviving`, `headline`, `summary` | `conversus.sh:298`                                        |
| PyYAML (synth helper dep, satisfied via conversus venv)  | `import yaml` inside `conversus-synth.py`                                    | `conversus-synth.py:34–38`; `tests/...shim.sh:117–125`    |
| pipx venv path assumption (integration test)             | `~/.local/pipx/venvs/conversus/bin/python`                                   | `tests/...shim.sh:119–120`                                |
| OAuth login path (documented, not adapter-invoked)       | `conversus login anthropic`                                                  | `specs/025-.../conversus/PRESSURE-TEST-FINDINGS.md:83`    |

### 1.2 Config shape (`conversus.yml`) synthesized by the orchestrator

Written by `conversus-synth.py` → consumed by `conversus run`:

- `mode: cooperative | red-blue | winner-take-all | prisoners-dilemma` (value comes from preset; red-blue is the canonical pressure-test mode)
- `target: <absolute path to artifact>`
- `output: <absolute path to output dir>`
- `iterations: 1`
- `agents: [ { name, prompt, role? (red|blue, red-blue mode only) } ]`
- `arbiter: { name, prompt, docs: [<grounding>], grounding: <path>, trigger: disputes_remain }`

### 1.3 Output-tree shape the adapter reads back

- `<output>/summary/final.md` — synthesis artifact (required; adapter bails if missing; `conversus.sh:285–289`)
- `<output>/<agent-name>/review.md`, `.../cross-review.md`, etc. — observed in partial runs; referenced in PRESSURE-TEST-FINDINGS but not asserted by adapter
- JSON schema of `summary/final.md` consumed via `linter.output_contract` module — keys: `quality_indicators.genuine_disagreements_surviving`, `headline`, `summary`

### 1.4 Environment variables the orchestrator sets or relies on

| Env var                             | Set by                                  | Consumed by                       | Purpose                                                               |
|-------------------------------------|-----------------------------------------|-----------------------------------|-----------------------------------------------------------------------|
| `CONVERSUS_STUB`                    | tests, operator debug                   | `conversus.sh:56`                 | Bypass binary; use canned fixtures                                    |
| `CONVERSUS_STUB_VERDICT`            | tests                                   | `conversus.sh:173`                | PASS / BLOCK for stub mode                                            |
| `CONVERSUS_STRICT`                  | M013 pre-merge gate, `specify` Full     | `conversus.sh:127`                | Treat missing binary as FAIL (rc=1) not SKIPPED                       |
| `CONVERSUS_HOME`                    | operator                                | `conversus.sh:69`                 | Explicit binary location                                              |
| `CONVERSUS_PROVIDER`                | `specify.sh`, tests, operator           | `conversus.sh:272`                | `anthropic` (default) / `claude-code` / `mock`                        |
| `CONVERSUS_RUN_OUTPUT_DIR`          | operator; integration test              | `conversus.sh:246`                | Override run output tree (default = `dirname <output>`)              |
| `CONVERSUS_GATE_TODO_THRESHOLD`     | operator                                | `conversus.sh:161`                | D019 TODO pre-flight threshold                                        |
| `CONVERSUS_GATE_SKIP_TODO_CHECK`    | tests, preset-authoring                 | `conversus.sh:160`                | D019 TODO pre-flight bypass                                           |
| `CONVERSUS_INTEGRATION`             | integration test                        | `tests/...shim.sh:155`            | Gate real-binary test                                                 |
| `ANTHROPIC_API_KEY`                 | operator                                | upstream provider                 | PAYG bypass for Bug 2 (OAuth parallel-429)                            |

### 1.5 Exit-code contract (adapter ↔ caller)

- `0` — PASS **or** SKIPPED (binary missing in non-strict)
- `1` — adapter error (missing preset, missing artifact, malformed output, TODO pre-flight refusal, missing binary in strict mode)
- `2` — BLOCK verdict

## 2. OSS-vs-Paid Parity — Open Questions (VERIFY at discuss-finalize)

Every row marked VERIFY needs operator or agent-with-fs-access check of
`~/Sites/conversus-oss` vs `~/Sites/conversus`:

| Feature surface the orchestrator consumes                                          | OSS coverage | Paid-only? | Notes |
|------------------------------------------------------------------------------------|-------------|-----------|-------|
| `conversus run <config.yml> --provider anthropic\|claude-code\|mock`               | VERIFY      | VERIFY    | The single load-bearing CLI call path. If OSS ships `run` with the same signature + provider set, the adapter is 99% compatible. |
| `linter.output_contract` Python module importable inside the venv's python         | VERIFY      | VERIFY    | Orchestrator depends on the JSON schema (`genuine_disagreements_surviving`, `headline`, `summary`). If OSS splits or renames this, the adapter's verdict-derivation logic breaks. |
| Config schema: `mode / target / output / iterations / agents / arbiter`            | VERIFY      | VERIFY    | Arbiter's `grounding` + `docs` dual-field is particular; red-blue `role: red\|blue` hint is mode-specific. |
| Deliberation modes: `red-blue`, `cooperative`                                      | VERIFY      | VERIFY    | D014 + D017 precedents rely on both. Red-blue is canonical for `spec-pressure-test.yml`; cooperative for `normalize-fidelity.yml`. |
| `conversus login anthropic` OAuth subscription path                                | VERIFY      | VERIFY    | Bug 2 evidence suggests this is paid/premium-auth plumbing. OSS users may have only API-key path. |
| `conversus gate` native subcommand (shim bypasses it — see `conversus.sh:225`)     | Not used    | Not used  | Note: the adapter deliberately **does not** depend on a native `gate` subcommand. Parity concern moot. |
| pipx venv path `~/.local/pipx/venvs/conversus/bin/python`                          | VERIFY      | VERIFY    | If OSS ships under a different pipx package name (e.g., `conversus-oss`), the integration test + adapter venv-python extraction breaks. |
| Upstream PR #28 (claude-code provider success classification) — fixed in paid?     | VERIFY      | VERIFY    | Filed against `Build-Fractal/conversus` (paid). OSS branch point matters: if OSS is a cut from pre-#28, the claude-code provider is broken there too. |
| Upstream PR #29 (OAuth parallel-429 concurrency cap + retry) — fixed in paid?      | VERIFY      | VERIFY    | Same branch-point concern. |
| 26 prebuilt role presets cited in D007 (e.g., `role/red-team`, `domain/security`)  | VERIFY      | Likely paid | D007 cited these as a reason to drop M017. If they're paid-only, M018 and any future caller that references them by name needs an alternative — OR the orchestrator never uses them directly (we ship our own presets under `templates/conversus-presets/`) so this may be moot. |
| Anthropic provider cost tracking / token accounting in synthesis output            | VERIFY      | VERIFY    | M019 Tier 1 emitter records `conversus_gate_invocation` with `llm_calls` + `estimated_cost_usd` — currently hardcoded 0 in `specify.sh:533`. If OSS doesn't expose per-call cost, M019 Tier 2+3 plans that would read actuals need a degrade path. |
| MCP adapter interface (D016 posture for M023 design-layer renderers)               | VERIFY      | Likely paid | Not a current dependency but forward-reaching (M023). If OSS lacks MCP, M023 may need a paid-only escape. |

## 3. In-flight work that the migration crosses

| In-flight artifact                                                | Current state                                 | Migration implication                                                                                                                                     |
|-------------------------------------------------------------------|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Spec 025 (M020 knowledge-layer) — `Ready-for-discuss-gate-deferred` | Pass 3 gate deferred pending upstream PRs #28/#29 | If migration cuts over to OSS before #28/#29 ship in OSS, spec 025's gate re-run stays blocked on OSS side. If OSS has both fixes pre-cutover, gate can re-run on OSS. **Cross-link needed in new spec's Open Questions.** |
| Spec 026 (M014 three-pass shell impl) — Draft, milestone M014      | Depends on `conversus.sh gate` exit-code contract being stable | Migration MUST NOT change adapter's 0/1/2 exit-code contract, --strict flag, or TODO pre-flight. Spec 026 can proceed in parallel only if those invariants hold. |
| `commands/specify.md` D019 three-pass contract                     | Written but Passes 2+3 agent-executed for now | Migration-side work and spec-026 shell-impl share the adapter. If migration renames the binary (`conversus` → `conversus-oss`) without a symlink, spec 026's testing gets noisy. Sequencing decision required. |
| M020 draft context (`.orchestrator/milestones/M020/M020-CONTEXT.md`) | status: draft                                 | Unaffected directly. M020 uses knowledge layer primitives, not conversus directly. Migration is orthogonal. |
| M013/P04 conversus UAT PR gate (`scripts/integrations/github-conversus-gate.sh`) | Shipped | Consumes adapter via `gate --strict`. Must stay green through migration. |
| M014/P04 pressure-test preset + three-way prompt                    | Shipped                                        | Same invariants as spec 026. |

## 4. Proposed abstraction boundary (default + escape hatch)

Shape options to discuss:

1. **Env-var toggle** — `CONVERSUS_EDITION=oss|paid` resolved in `conversus.sh` resolver. Default `oss`. `paid` flips the binary-resolution order to prefer `~/Sites/conversus` over `~/Sites/conversus-oss`. Cheapest change; paid-only features invoked via preset that names them stay broken silently on OSS.
2. **Per-invocation `--edition` flag** on `conversus.sh gate`. Explicit per-call; no global default drift. Requires every caller to decide.
3. **Layered adapter** — keep `conversus.sh` as the OSS-default entry and add `scripts/dispatch/adapters/tool/conversus-paid.sh` that callers explicitly dispatch to for paid-only presets. Clearest blast-radius separation; most code churn.
4. **Symlink-at-install** — operator chooses `~/Sites/conversus → conversus-oss` at install time; adapter unchanged. Smallest adapter delta; fragile under dual-edition workflows.

Recommendation (surfaces as OQ in spec, operator decides at discuss-finalize): **layered adapter (#3)** for callers that *need* a paid feature with a clear diagnostic + **edition env var (#1)** as the default-resolution knob. Rejects #4 because dual-edition is a real use case (debugging a paid regression without uninstalling OSS).

## 5. Milestone-slotting proposal vs. D016

Current committed order (D016):

> **M014 (extended) → M020 → M024 → M019 Tier 2+3 → M018 → M023 → M009 (extended) → M010 (adjusted)**

The migration milestone (proposed **M026** — first free ID) needs slotting. Two options:

- **Option A**: Slot BEFORE spec 026's shell impl (i.e., before M014-ext's next phase). Rationale: the three-pass shell-impl (spec 026) bakes adapter invocation into the shell; if the migration changes the adapter later, spec 026's tests are rewritten twice. **Costs** a delay on the three-pass landing.
- **Option B**: Slot AFTER M014-ext but before M020 kickoff (so spec 025's gate re-run happens on whichever edition we've chosen). Rationale: spec 026 lands on the paid adapter (known-working today), then the migration re-homes. **Costs** adapter churn on tests written just weeks earlier.

Discuss-finalize decision. Spec proposes Option A with the note that it's the less-rework path if OSS parity is >= 90%; if parity gaps require staged work, promote to Option B.

## 6. What the operator should not do in this session

- Do not change `~/Sites/conversus` (paid) — read-only from orchestrator's POV.
- Do not change `~/Sites/conversus-oss` — same posture.
- Do not land the migration without finalizing the discuss-draft.
- Do not re-open spec 025 or spec 026 scope; note cross-cuts in the new spec's Open Questions.
