---
description: "Use when authoring a new feature spec. Runs a three-pass flow (scaffold → author → gate) intensity-scaled per D019: produces a spec ready for orchestrator:evaluate."
---

# orchestrator:specify

Author a new feature spec from a natural-language description via three sequential passes: **scaffold** (always), **author** (intensity-scaled content generation), and **gate** (intensity-scaled adversarial review). The scaffolded `specs/<NNN>-<slug>/spec.md` matches the Section Contract pinned by `templates/spec-template.md`; the `AGENTS.md` and `CLAUDE.md` Recent Changes region is dual-written via the FR-12 helper; an `unit_close` record is appended to `.orchestrator/execution-log.jsonl`.

This is the load-bearing command for the M014 dogfood loop: every future milestone's spec is expected to be produced by running this command rather than hand-copying an existing `specs/*/spec.md`.

**Status**: Three-pass contract defined here (D019, 2026-04-23). Pass 1 (scaffold) is implemented in `scripts/specify/specify.sh` today. Passes 2 and 3 as specified below land in the next M014 extended phase — until then, agents invoking this command must execute pass 2 and pass 3 manually against the scaffolded output by reading this doc.

## Prerequisites

- `.orchestrator/` exists (orchestrator state root). Run `orchestrator:init` first if absent.
- `templates/spec-template.md` is the Section Contract SSOT.
- `scripts/util/dual-write-runtime-md.sh` is installed (FR-12 helper).
- `scripts/verify/spec-shape-lint.sh` is installed (FR-4 verifier, invoked downstream by `orchestrator:discuss`).
- `scripts/engine/intensity-analyze.sh`, `scripts/engine/intensity-override.sh`, `scripts/engine/intensity-gate.sh` — intensity engine (existing, reused).
- `scripts/knowledge/spec-complexity-probe.sh` — post-authoring probe for gate-strictness escalation.
- `scripts/dispatch/adapters/tool/conversus.sh` — conversus gate adapter (pre-flight TODO guard per D019).

## Usage

The canonical invocation shape:

```
bash scripts/specify/specify.sh --description "<prose>" [--slug <slug>] [--milestone <M###>] [--intensity quick|standard|full] [--force] [--yes] [--dry-run]
```

Flags:

- `--description <prose>` — required on create-path. The operator's natural-language description; quoted in the scaffold's `Input:` frontmatter field.
- `--slug <slug>` — optional. Kebab-case short name for the spec directory. If omitted, derived deterministically from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation) and accepted silently in `--yes` mode.
- `--milestone <M###>` — optional. Binds the scaffold to a milestone ID in the frontmatter; otherwise `<TODO: bind to milestone>`.
- `--intensity quick|standard|full` — optional. Hard override of the intensity used for passes 2 and 3. Trumps project-default + smell-test escalation. Without this flag, intensity is resolved per the "Intensity Resolution" section below.
- `--force` — optional. Permits overwrite of an existing `specs/<NNN>-<slug>/` directory. Without this flag, slug collision exits non-zero.
- `--yes` — optional. Auto-accepts interactive prompts (slug derivation in particular). Implied under `orchestrator:auto`. At Full intensity, `--yes` auto-answers the clarify-loop with the agent's best-guess default; operators who want real clarify interaction must omit `--yes`.
- `--dry-run` — optional. Emits FR-19 JSONL manifest records to stdout describing what would be written; no disk writes performed.

Subcommand surfaces:

- `--amend <path>` — re-scaffolds per FR-14 three-case semantics: (a) all-placeholder sections re-fill via FR-3 LLM under CC (skip under Codex/Cursor); (b) partial-placeholder sections left byte-unchanged with a diagnostic; (c) fully-authored sections unchanged byte-identically. Re-probe fires on changed sections only (US-3 AS-7).
- `split <path>` — LLM-assisted splitter (Claude Code only in v1); proposes a 2-N sub-spec decomposition manifest at `.orchestrator/specify/decomposition/<source-id>/manifest.md`. Under Codex/Cursor, prints a CC-only diagnostic and exits 3.

## Three-Pass Flow

### Intensity × pass matrix

| Pass | Quick | Standard | Full |
|------|-------|----------|------|
| 1. Scaffold | ✓ | ✓ | ✓ |
| 2. Author | agent-only, no review | agent-only, warn on weak sections | agent + `speckit.clarify` loop (≤5 questions, user answers, agent revises) |
| 3. Gate | **skip** | **advisory** (findings logged to Open Questions, doesn't block) | **strict** (BLOCK halts; revise → re-run) |

The matrix is the contract. Any future edits to pass behavior that break this matrix require a new Decision row (not a command-doc amendment).

### Intensity resolution

At the start of the run, resolve effective intensity in this order (later sources override earlier):

1. **Project default** — read `intensity.default` from `.orchestrator/config.yml` (today: `standard`).
2. **Smell-test escalation** — pipe `--description` through `scripts/engine/intensity-analyze.sh --description <prose>` and read `recommended_intensity=`. Escalate the effective intensity if the analyzer recommends higher (Quick → Standard → Full); **never de-escalate**. Smell-test cannot reduce intensity below the project default.
3. **CLI override** — if `--intensity <level>` was provided, it wins. Trumps both above.

Emit the resolved intensity + reasoning as one `specify_intensity_resolution` JSONL record to `.orchestrator/execution-log.jsonl` with `{resolved, project_default, smell_test_recommendation, cli_override, reasoning, source: "runtime"}`.

### Pass 1 — Scaffold (all intensities)

Identical to the current shipped behavior. Creates the spec file with frontmatter + Section Contract placeholders (`<TODO: …>`) in every body section except `Input:` (populated from `--description`).

1. **Preflight**: confirm `.orchestrator/` exists; otherwise exit 2 with a pointer to `orchestrator:init`.
2. **Lock acquisition**: acquire `scripts/lifecycle/lock-manager.sh` around spec-number resolution to prevent TOCTOU (Edge Case: spec number race). Best-effort; missing lock manager does not fail the command.
3. **Number allocation**: scan `specs/NNN-*` directories; next number is `max(existing) + 1`.
4. **Slug derivation**: if `--slug` absent, derive from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation). Under `--yes`, accepted silently; otherwise print derived slug with one-keystroke accept/reject.
5. **Collision check**: if `specs/<NNN>-<slug>/` exists, exit 1 with a clear error unless `--force`.
6. **Scaffold write**: copy `templates/spec-template.md` into `specs/<NNN>-<slug>/spec.md` via temp-file-then-rename. Substitute frontmatter placeholders (`{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}`).
7. **Dual-write Recent Changes**: invoke `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content <fragment> --file CLAUDE.md --file AGENTS.md` with a one-line fragment `- <NNN>-<slug>: <first-80-chars-of-description>`.

### Pass 2 — Author (intensity-scaled)

Drafts the spec body from the Input field + available repo context. The agent reads:

- The Input field (frontmatter `Input:` verbatim).
- `.orchestrator/DECISIONS.md` — recent decisions whose `Scope` column references this spec's slug or milestone.
- `.orchestrator/memory/constitution.md` — for the Constitution Check section.
- `CLAUDE.md` + `AGENTS.md` Recent Changes — for context on neighboring active work.

The agent authors each section using only those sources; it **does not invent requirements not grounded in the Input field**. Sections produced:

- **Problem Statement** — 2-4 paragraphs, derived from the Input's framing.
- **Minimal Slice** — smallest coherent subset of user stories that closes the dogfood loop.
- **User Stories** (P1/P2/P3) — each with priority defense + independent-test description + acceptance scenarios.
- **Edge Cases** — off-happy-path scenarios with defined behavior.
- **Functional Requirements** — `FR-N (<short-name>)` entries citing the user story they satisfy.
- **Success Criteria** — mechanically verifiable (command + exit code + observable artifact).
- **Non-Goals** — explicit scope boundaries with rationale.
- **Constraints** — including the Knowledge-Layer Boundary subsection if knowledge/** schema is touched.
- **Constitution Check** — Principles II/III/XV/XIV (plus any others materially touched) with prose about how this spec honors each.
- **Assumptions** — pre-conditions held outside this milestone's scope.
- **Dependencies** — upstream milestones/tools.
- **Downstream Consumers** — informational.
- **Open Questions** — any places the agent had to guess + unresolved ambiguities.

Intensity behavior:

- **Quick**: agent-authors in one pass, no review prompts, no warnings. Output is final for this pass.
- **Standard**: agent-authors, then runs a self-review checklist (FR count sanity, at least one acceptance scenario per story, no empty sections). Emits `specify_author_warnings` JSONL record if checklist finds gaps; does not block.
- **Full**: agent-authors, then invokes `speckit.clarify` (skill) against the authored draft. Clarify surfaces up to 5 highest-value open questions (load-bearing ambiguities); operator answers; agent incorporates answers into the draft. If `--yes` is set, clarify's questions are auto-answered with the agent's best-guess defaults and those defaults are logged verbatim in the spec's Open Questions section so a human can revisit.

**Output of pass 2**: the spec file now contains authored prose in place of `<TODO:` placeholders. `scripts/verify/spec-shape-lint.sh` should pass (mandatory sections populated, Section Contract honored).

### Pass 3 — Gate (intensity-scaled)

Adversarially reviews the authored spec for ambiguity, internal contradiction, scope overreach, and insufficient evidence to pass Constitution II/III/XV gates.

**Pre-flight**: invoke `scripts/knowledge/spec-complexity-probe.sh specs/<NNN>-<slug>/spec.md`. Emits `probe=above-threshold reason=<criterion>` or `probe=below-threshold` on stdout. This runs against AUTHORED content (not placeholders); a well-authored spec that trips the probe is a genuine signal, not an artifact of TODOs.

Then the adapter runs per intensity:

- **Quick**: **skip pass 3 entirely**. Emit one `specify_gate_skipped` JSONL record with `{reason: "intensity=quick", probe_verdict}`. Spec proceeds to `Status: Ready-for-discuss` as-is.
- **Standard**: run `scripts/dispatch/adapters/tool/conversus.sh gate spec-pressure-test <spec-path> specs/<NNN>-<slug>/conversus/gate-result.md` **without** `--strict`. The adapter's TODO pre-flight refuses the call if authoring left placeholders (D019). On BLOCK verdict, findings are appended to the spec's Open Questions section with a deferred-to-discuss annotation; command exits 0 (advisory).
- **Full**: run the same adapter invocation **with** `--strict`. On BLOCK verdict, command exits 2 and prints the dispute list + "revise then re-run orchestrator:specify --amend" message. On PASS verdict, promote spec frontmatter `Status: Draft` → `Status: Ready-for-discuss`; add `Last Revised: <today>` line per M013/M014 precedent.

**Gate adapter pre-flight (per D019)**: the `conversus.sh gate` adapter refuses any artifact containing `<TODO:` markers above `CONVERSUS_GATE_TODO_THRESHOLD` (default 1). This guards against callers invoking the gate on unauthored scaffolds. Bypass via `CONVERSUS_GATE_SKIP_TODO_CHECK=1` is reserved for tests.

### Observability

At the end of the run:

- Append one `unit_close` record to `.orchestrator/execution-log.jsonl` with `{command, specs_scaffolded, dual_writes, author_pass_ran, clarify_invocations, conversus_invocations, adapter_verdicts, resolved_intensity, elapsed_ms, source: "runtime"}`.
- Print the absolute path to the written spec; exit 0 on PASS / skipped-gate, exit 2 on Full+BLOCK (advisory BLOCK at Standard still exits 0).

## Output

- `specs/<NNN>-<slug>/spec.md` — authored spec. At Quick: authored body, no gate artifact. At Standard: authored body, `conversus/gate-result.md` present, any BLOCK findings folded into Open Questions. At Full+PASS: authored body, gate-result.md present, status promoted to Ready-for-discuss, Last Revised line added.
- `CLAUDE.md` Recent Changes region updated (inside `# >>> orchestrator:recent-changes >>>` markers).
- `AGENTS.md` Recent Changes region updated (same markers; skipped if `dual_write_agents: false`).
- `.orchestrator/execution-log.jsonl` gains `specify_intensity_resolution`, optional `specify_author_warnings`, optional `specify_gate_skipped`, and one `unit_close` record.

## Idempotency

- Re-running with the same `--slug` fails with a clear error. `--force` permits overwrite.
- Re-running with `--amend` is idempotent on unchanged sections.
- Re-running pass 3 only (`--gate-only <spec-path>`, future surface): re-runs the gate against the current body without re-authoring. Useful after manual revision addresses a BLOCK verdict.

## Error Handling

- Missing `.orchestrator/`: exit 2, point to `orchestrator:init`.
- Slug collision: exit 1, mention `--force`.
- Template missing: exit 1, point to `templates/spec-template.md`.
- Dual-write helper missing: exit 1, point to `scripts/util/dual-write-runtime-md.sh`.
- Intensity-analyze script missing: warn, fall back to project-default intensity without smell-test escalation.
- Author pass produces empty sections (agent failure): exit 1, preserve scaffold placeholders, emit actionable diagnostic.
- Gate pre-flight rejects TODO-filled artifact: exit 1, message points at the author pass. Should only fire if pass 2 was skipped or failed silently; signals a broken flow.
- Full+BLOCK: exit 2, print dispute list, spec body preserved verbatim (no rollback).
- Execution-log append failure: warn on stderr but do not fail the command (observability is best-effort).

## Gotchas

- **Intensity resolution is one-shot at run start**. Pass 2 and pass 3 see the same resolved intensity; there's no mid-run escalation. If pass 2 surfaces something that should trip a stricter gate, that's a signal to re-run with `--intensity full`, not a signal to mid-run escalate.
- **Smell-test only escalates**. A Quick project default + smell-test recommending Standard → effective Standard. A Full project default + smell-test recommending Quick → effective Full. CLI override is the only way down.
- **`--yes` at Full silences clarify but does not skip it**. Clarify still runs; questions are auto-answered with agent defaults; the defaults are written back into Open Questions so the compromise is visible. Operators who want to truly skip clarify must downgrade with `--intensity standard`.
- **Gate skip at Quick is by design**. Quick is for low-risk specs (bugfix, tiny refactor, small docs change). Pay the authoring cost to get structure; skip the pressure-test that only earns its cost on architecturally load-bearing work.
- **TODO guard in gate adapter is universal**. Any caller of `conversus.sh gate` — not just `orchestrator:specify` — gets the same refusal. Callers that legitimately gate stubs (integration tests, preset authoring) set `CONVERSUS_GATE_SKIP_TODO_CHECK=1`.
- **Referring to scaffold-placeholders in authored prose is a footgun** (per D020). The pre-flight matches the literal `<TODO:` byte pattern; a section that refers to the token by name — e.g., an FR reading "refuses artifacts containing `<TODO:` markers" — will falsely trip refusal on its own body. Pass 2 authoring (human or agent) should use `scaffold-placeholder marker` or similar paraphrase rather than embedding the literal pattern inside backticked inline code.

## Referenced Scripts

- `scripts/specify/specify.sh` — this command's implementation (pass 1 today; passes 2+3 land in next M014 extended phase per D019).
- `templates/spec-template.md` — Section Contract SSOT.
- `templates/spec-scaffolder-prompt.md` — FR-3 author-pass LLM prompt.
- `scripts/util/dual-write-runtime-md.sh` — FR-12 marker-bounded dual-write helper.
- `scripts/verify/spec-shape-lint.sh` — FR-4 shape verifier.
- `scripts/engine/intensity-analyze.sh` — smell-test (recommendation from description).
- `scripts/engine/intensity-override.sh` — CLI override resolver.
- `scripts/engine/intensity-gate.sh` — per-stage intensity gate (used by downstream commands).
- `scripts/knowledge/spec-complexity-probe.sh` — post-authoring complexity probe.
- `scripts/dispatch/adapters/tool/conversus.sh` — gate adapter (pre-flight TODO guard per D019).
- `scripts/lifecycle/lock-manager.sh` — spec-number race mitigation.
- `scripts/dispatch/dispatch-interface.sh` — LLM round-trip dispatch surface for author pass + clarify.
