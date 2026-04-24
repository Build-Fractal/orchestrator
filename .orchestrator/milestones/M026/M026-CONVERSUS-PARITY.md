---
schema_version: "1.0"
type: parity-matrix
milestone: "M026"
phase: "P01"
created_at: "2026-04-23"
status: final
---

# Conversus OSS vs Paid Parity Matrix (M026-authoritative)

**Reading posture**: every row's `Verified:` cell is populated by fs-inspection
on 2026-04-23 against `~/Sites/conversus-oss` and `~/Sites/conversus` as they
exist on the operator's machine today. Verdict vocabulary:
`verified-identical` (same shape both editions, adapter consumption is safe),
`verified-drifted` (different shape, adapter or callers must adapt — covered
in P02 scope or deferred), `verified-absent` (OSS-side surface does not exist;
escape hatch required), `verified-moot` (surface not consumed by the adapter;
parity concern is moot).

## Inspection ground-truth

- OSS tree HEAD: `8ee7cc3 feat(registry): spec 064.1 — runtime registration of discovered capabilities (#4)` (Apache-2.0 extraction, diverged from paid after `1bfd62c`).
- Paid tree HEAD: `0eb70ca test(integration): flip xfails after spec 064.1 lands (#25)` (has upstream PRs #28 / #29 merged).
- Both trees inspected read-only per CON-5. Pre-existing untracked state (`?? .claude/`, `?? .conversus/` on OSS; ` M uv.lock` on paid) is pre-T01 operator state, not a T01 write.
- Topology note: OSS is NOT a subset of paid. OSS branched at `1bfd62c` and received new features (registry, quality_floor, wheel packaging, spec 006 inter-round arbitration, G1/G2/G11/G12 fixes) while paid received PR #28 (claude-code provider) and PR #29 (anthropic parallel-429 cap + retry). They are siblings with divergent history.

## Consumption Surface

| Surface | OSS | Paid | Verified | Notes |
|---|---|---|---|---|
| `conversus run <config.yml> --provider <p>` CLI | `engine/__main__.py` + `engine/run.py` provide `run` subcommand with `--provider` flag | identical — `engine/run.py` byte-identical (diff empty) | verified-identical | load-bearing CLI path; both trees same |
| Exit-code contract (0 PASS, 1 error, 2 BLOCK via adapter) | adapter derives via `engine/run.py` return + `linter.output_contract` parse; conversus CLI itself returns 0/1 on success/failure | identical | verified-identical | adapter-layer contract (0/1/2) is stable across editions |
| `linter.output_contract` Python module importable | `linter/output_contract.py` present (434 lines) | present (434 lines) — `diff` empty | verified-identical | JSON schema (`quality_indicators.genuine_disagreements_surviving`, `headline`, `summary`) byte-identical; adapter `conversus.sh:298` consumption is safe on OSS |
| Config schema: `mode / target / output / iterations / agents / arbiter` | OSS `engine/config.py` adds arbiter `timing: final\|inter-round` + `influence: binding\|recommended\|advisory` (spec 006) + registry-based `VALID_PROVIDERS` (accepts 11+ providers, G12 fix) | paid `engine/config.py` has `VALID_PROVIDERS = ("anthropic", "openai")` hardcoded; no timing/influence fields | verified-drifted | OSS is a strict superset on config schema — additive new fields are forward-compatible; adapter-synth emits only fields both accept; `trigger: disputes_remain` unchanged; diff is OSS-ahead not OSS-behind |
| Deliberation modes `red-blue` / `cooperative` / `winner-take-all` / `prisoners-dilemma` | full enum supported via `engine/config.py:613` → `VALID_MODES` + `engine/phases.py` | same full enum; `red-blue` role enforcement at `engine/config.py:708` identical on both sides | verified-identical | red-blue role requirement (`role: blue\|red` mandatory) is identical OSS and paid |
| `conversus login anthropic` OAuth subscription path | `engine/auth.py` with `_login_anthropic` at line 257, `login()` at line 359, OAuth PKCE flow | byte-identical at line level (same line numbers 257/359/391/669) | verified-identical | OAuth subscription support ships in OSS (contrary to scratch-matrix assumption); OSS users on subscription auth are first-class |
| pipx venv path `~/.local/pipx/venvs/conversus/bin/python` | single venv named `conversus` at `~/.local/pipx/venvs/conversus/` regardless of source tree | same — only one `conversus` venv per machine, whichever was `pipx install`-ed last wins | verified-identical | adapter venv-python extraction via launcher shebang (`head -n 1 $_bin_path`) remains correct; operator currently has OSS installed per oss-early-review.md |
| Upstream PR #28 (claude-code provider success classification — tool-use-only treated as success) | NOT in OSS log (`git log --all --grep=claude.code` empty on OSS) | merged in paid: `722d222 fix(claude-code): treat tool-use-only responses as success` | verified-absent | OSS cut predates PR #28; `CONVERSUS_PROVIDER=claude-code` invocations on OSS will misclassify tool-use-only completions as failure. Adapter's default `CONVERSUS_PROVIDER=anthropic` shields most callers, but any caller that sets claude-code hits this |
| Upstream PR #29 (anthropic parallel-429 retry + concurrency cap) | NOT in OSS log | merged in paid as two commits: `defe207 fix(anthropic): retry 429s with Retry-After + jittered backoff (max 3)` + `0cec838 fix(anthropic): gate OAuth subscription auth to concurrency=1` | verified-absent | load-bearing for adapter callers using OAuth subscription + red-blue (2+ parallel agents); oss-early-review.md confirmed reproduction on first contact 2026-04-23. M026 narrow-scope trigger |
| 26 prebuilt role presets cited in D007 | 25 presets total; `presets/role/` has 4 (balanced-arbiter, blue-team, devils-advocate, red-team) | 26 presets total; `presets/role/` has 5 (adds `status-quo-guardian.yml`) | verified-drifted | orchestrator ships its own presets under `templates/conversus-presets/`, does not name upstream presets by path; drift is informational not adapter-consumption-breaking |
| Token / cost accounting (`engine/cost.py`) | `estimate_cost_usd` with per-model pricing, range estimate | `diff` empty — byte-identical | verified-identical | M019 Tier 2+3 plans that read cost estimates work on either edition |
| MCP adapter interface (`mcp_server.py`) | result types refactored into `engine/results.py` (single source of truth per constitution XI); `mcp_server.py` re-exports `CostEstimate / ValidateResult / RunResult / DecideResult` at module scope | paid `mcp_server.py` defines result types inline (no `engine/results.py`); `from __future__ import annotations` present in paid, removed in OSS (FastMCP compatibility) | verified-drifted | public `from mcp_server import <Type>` surface unchanged; drift is internal refactor. M023 design-layer callers (forward-reaching, D016) see same API |
| Top-level YAML contract — frontmatter rejection | `yaml.safe_load` → `ComposerError: expected a single document in the stream` when preset has `---\n...\n---\n<body>` frontmatter | same parser, same behavior | verified-identical | confirmed 2026-04-23 via oss-early-review.md; BOTH trees reject frontmatter-plus-body shape. Drift is orchestrator-preset (`templates/conversus-presets/spec-pressure-test.yml` leads with frontmatter) ↔ BOTH conversus trees. P02 synth-layer work applies regardless of edition |
| `agents[].role` required under `mode: red-blue` on OSS | `engine/config.py:708` enforces `red-blue mode requires at least one agent with role: red\|blue` | byte-identical enforcement at `engine/config.py:655` (same rule, different line number only) | verified-identical | confirmed 2026-04-23 via oss-early-review.md; BOTH trees enforce. Orchestrator-preset drift: `spec-pressure-test.yml` uses `agents[].name` heuristic without explicit `role:` field. P02 synth-layer must inject role |
| `agents[].prompt:` (OSS) vs `agents[].system_prompt:` (paid) — field rename | OSS `engine/config.py` uses `prompt: str` at line 45 (AgentConfig), validates raw `prompt:` at line 298/427/437 | paid `engine/config.py` ALSO uses `prompt: str` at line 42; both trees read `agents[].prompt:` | verified-identical | confirmed 2026-04-23 via oss-early-review.md; the drift surfaced in smoke is orchestrator-preset (`templates/conversus-presets/spec-pressure-test.yml:13,32` uses `system_prompt:`) ↔ BOTH conversus trees (which demand `prompt:`). Not an OSS-vs-paid drift. P02 synth-layer rename applies to either edition |
| Top-level `output:` — object-vs-string semantic | OSS `engine/config.py:102` — `output: Path`; `conversus.example.yml:17` — `output: example-output/` (string) | paid `engine/config.py:82` — `output: Path`; `conversus.example.yml:26` — `output: specs/001-.../conversus/` (string) | verified-identical | confirmed 2026-04-23 via oss-early-review.md; BOTH trees accept path-string only. The drift is orchestrator-preset's `output: { template:, required_fields: }` structured-object shape ↔ BOTH conversus trees. P02 synth-layer work applies regardless of edition |

## Summary

- Rows marked `verified-identical`: 11
- Rows marked `verified-drifted`: 3
- Rows marked `verified-absent`: 2
- Rows marked `verified-moot`: 0
- **Total**: 16

## OQ-2 Decision Input

Per M026-CONTEXT.md OQ-2: if `verified-drifted` + `verified-absent` together
exceed 3 rows (across the orchestrator consumption surface, not counting
`verified-moot`), M026's P02 scope narrows per the narrow-scope rule.

**Count**: `verified-drifted` (3) + `verified-absent` (2) = **5 rows**.

**Call**: **NARROW-SCOPE TRIGGERED** (5 > 3).

**Interpretation for P02**:

The narrow-scope rule fires primarily on the two `verified-absent` rows —
PR #28 (claude-code provider) and PR #29 (anthropic parallel-429). Both are
load-bearing for callers that exercise OSS against subscription-auth
Anthropic with multi-agent red-blue configs (the canonical
`spec-pressure-test.yml` preset). The three `verified-drifted` rows
(config schema additive fields, role preset count, mcp_server internal
refactor) are additive-only / adapter-irrelevant and do NOT by themselves
require adapter work.

The P02 narrow scope should concentrate on:

1. A **PR #29 mitigation path** for OSS — either serialize agent dispatch on
   OSS when provider=anthropic (adapter-side retry/concurrency shim), OR
   document `--provider ollama` / `--provider mock` as the supported OSS
   test path, OR gate OSS invocation behind a `CONVERSUS_EDITION=oss`
   diagnostic that falls back to paid when anthropic is the target.
2. A **PR #28 shield** for `CONVERSUS_PROVIDER=claude-code` callers — either
   force-skip claude-code on OSS, or document the false-failure mode.
3. Deferring the `mcp_server.py` refactor and role-preset-count concerns to
   demand-driven follow-up (no current consumer).

The four smoke-confirmed drift rows (YAML frontmatter, `role:` requirement,
`prompt:` field, `output:` string) are all **orchestrator-preset ↔
conversus-tree** drifts that apply IDENTICALLY to OSS and paid. They are
P02 synth-layer work regardless of which edition is the default. This is
a significant finding: the orchestrator's `conversus-synth.py` must
already be performing (or must start performing) these translations, and
that work is independent of the migration default.

## Addendum: 2026-04-23 post-verification install reality

After P01 verification, the operator ran `pipx install conversus` against
the OSS tree (editable-install via `~/Sites/conversus-oss`). This surfaced
three facts the initial matrix missed and that reshape P02 planning:

1. **Both editions publish to PyPI under the same package name `conversus`**
   and install to the same venv path `~/.local/pipx/venvs/conversus/`.
   Installing OSS replaces paid (and vice versa) — you cannot hold both
   editions in pipx's default namespace simultaneously. **Path-based
   edition detection is infeasible.** Verdict: `verified-drifted`
   (upgraded from the original `pipx venv path` row, which assumed
   separate `conversus-oss/` and `conversus/` venv directories).
2. **OSS ships a second console-script entry point `conversus-lint`**
   (installed at `~/.local/pipx/venvs/conversus/bin/conversus-lint`)
   alongside the `python -m linter.output_contract` module invocation
   the adapter currently uses. Paid's entry-point inventory is not
   confirmed post-uninstall but the orchestrator adapter does not use
   `conversus-lint` today. Verdict: `verified-moot` for current adapter;
   noted as a P02 opportunity (the adapter could switch from `python -m`
   to `conversus-lint` for cleaner invocation on OSS).
3. **Editable-install source path is `~/Sites/conversus-oss`.** The
   installed package imports source directly from that working tree, so
   any changes in the tree propagate to the installed binary without
   reinstall. This tightens the operator-discipline CON-5 read-only
   posture: a write under `~/Sites/conversus-oss` is simultaneously a
   write to the operator's installed conversus. Verdict: `verified-moot`
   for parity (both editions behave the same way under editable installs)
   but `verified-operational-constraint` for P02 test planning.

### P02 edition-detection strategy (updated from OQ-5)

Since path collision rules out directory-based detection, P02 must pick one:

- **(a) pip-show metadata probe.** Run `python -m pip show conversus` in
  the pipx venv and parse `Home-page:`. OSS = `github.com/Build-Fractal/conversus-oss`;
  paid = different (to be confirmed when paid reinstall happens).
  Adds one subprocess per adapter invocation unless cached.
- **(b) `CONVERSUS_EDITION=oss|paid` env-var override.** Operator declares
  which edition is active; adapter trusts the declaration. Lowest overhead,
  highest operator discipline. Matches the dual-edition escape-hatch
  posture captured in `project_m026_oss_posture`.
- **(c) `conversus-lint` presence sniff.** If the binary exists in the
  venv, treat as OSS. Works today but assumes paid never adds that
  entry point — brittle as a long-term differentiator.

Recommendation for P02: **(b) primary + (a) fallback.** Env-var makes the
common case zero-cost; metadata probe catches the accident-prone case
where the operator forgot to set the var.

### OSS venv inventory (authoritative as of 2026-04-23T22:50 PT)

- OSS installed: `/Users/brettkellgren/.local/pipx/venvs/conversus/` —
  package `conversus 0.3.0`, editable at `/Users/brettkellgren/Sites/conversus-oss`,
  binaries `conversus` + `conversus-lint`, License Apache-2.0,
  Home-page `https://github.com/Build-Fractal/conversus-oss`.
- Paid: **uninstalled** (displaced by OSS install). Re-install requires
  a separate pipx namespace or displacing OSS back.

## Drill-down pointers

- Seed scratch matrix: `.orchestrator/scratch/conversus-oss-migration-parity.md`
- Smoke-test commentary: `specs/027-conversus-oss-migration/conversus/oss-early-review.md`
- Adapter consumption surface: `scripts/dispatch/adapters/tool/conversus.sh` (`_resolve_binary` 52-82, `_parse_verdict` 84-108, `python -m linter.output_contract` line 298)
- Adapter synth helper: `scripts/dispatch/adapters/tool/conversus-synth.py`
- Integration-test pipx venv assumption: `tests/test-conversus-adapter-shim.sh:119-124`
