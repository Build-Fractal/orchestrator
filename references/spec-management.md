# Spec Management Reference

Authored by M014. Completed in P04 — documents the Section Contract SSOT pointer, the dual-write marker convention, the FR-19 `--dry-run` manifest record shape, the FR-5 complexity probe, the FR-6 conversus pressure-test flow, the FR-7 decomposition flow, and the FR-14 `--amend` three-case semantics.

## Section Contract

The `templates/spec-template.md` file is the canonical Section Contract SSOT. Every spec scaffolded by `orchestrator:specify` conforms to this shape; `scripts/verify/spec-shape-lint.sh` derives its required-section list from this template (not hardcoded).

Required top-level sections, in order:

1. YAML frontmatter block + `# Feature Specification: <title>` heading
2. `## Problem Statement`
3. `## User Scenarios & Testing *(mandatory)*`
   - `### Minimal Slice (Phase 1 Load-Bearing Scope)` subsection
   - `### User Story N — <title> (Priority: PN)` — at least one
4. `## Edge Cases`
5. `## Functional Requirements`
6. `## Success Criteria`
7. `## Non-Goals`
8. `## Constraints`
   - `### Knowledge-Layer Boundary (<milestone> vs. <owning-knowledge-milestone>)` subsection
9. `## Assumptions`
10. `## Constitution Check`
11. `## Open Questions (defer to planning)`
12. `## Dependencies`
13. `## Downstream Consumers (informational, not binding)`

**I/O contract**: the scaffolded output is a superset of the spec-kit `spec-template.md` vocabulary, so `scripts/knowledge/detect-spec-shape.sh` reports `shape=speckit` without renormalization. `scripts/knowledge/ingest-spec.sh` takes the fast path (no normalization required).

Placeholder convention: unpopulated content is bracketed `<TODO: ...>`. Authored content replaces placeholders as-is; `spec-shape-lint.sh` emits `todo_count=N` informationally (non-zero means skeleton, zero means authored).

## Dual-Write Marker Convention

The FR-12 runtime-instruction dual-write helper (`scripts/util/dual-write-runtime-md.sh`) writes content between marker lines of exactly this shape:

```
# >>> orchestrator:<region-name> >>>
<content lines>
# <<< orchestrator:<region-name> <<<
```

The region-name is passed via `--marker <region>`. The current write-sites (P01):

| Region | Written by | Shape |
|---|---|---|
| `recent-changes` | `orchestrator:specify` | one-line `- <slug>: <description-first-80-chars>` per scaffolded spec |

P02 extends this table with `orchestrator:init` and `orchestrator:consolidate` write-sites.

### Byte-preservation invariant (SC-6a)

Bytes outside the marker region are byte-identical pre- and post-write. `shasum -a 256` of the outside-markers byte stream is invariant across any number of writes. The test `tests/test-dual-write-outside-invariant.sh` enforces this contract.

### `dual_write_agents: false` gate

When `.orchestrator/config.yml` has `dual_write_agents: false` at the top level, the helper writes only `CLAUDE.md` and skips `AGENTS.md` with a `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr. Operators on pure-Claude-Code projects opt out cleanly; default is `true`.

## `--dry-run` Manifest Shape (FR-19)

Every M014 command's `--dry-run` flag emits structured JSONL records to stdout, one record per proposed action. Record shape:

```json
{
  "command": "<command-name>",
  "action_type": "<action-type>",
  "target_path": "<absolute-or-repo-relative-path>",
  "source_ref": "<template-or-fragment-path>",
  "description": "<human-readable-one-line-summary>"
}
```

Defined `action_type` values (M014-local; additional values permitted in later phases; removal requires a D-row):

| action_type | Emitter | Target |
|---|---|---|
| `scaffold-spec` | `orchestrator:specify` | `specs/<NNN>-<slug>/spec.md` |
| `dual-write-region` | `scripts/util/dual-write-runtime-md.sh`, `orchestrator:specify` | `CLAUDE.md`, `AGENTS.md` |
| `classify-comment` (P03) | `orchestrator:comments` | in-memory classification result |
| `apply-amendment` (P03) | `orchestrator:comments` | `specs/<NNN>-<slug>/spec.md` |
| `append-decision` (P03) | `orchestrator:comments` | `.orchestrator/DECISIONS.md` |
| `invoke-conversus-gate` (P04) | `orchestrator:specify` (y path) | `specs/<NNN>-<slug>/conversus/summary/final.md` |
| `propose-decomposition` (P04) | `orchestrator:specify split` | `.orchestrator/specify/decomposition/<source-id>/manifest.md` |
| `amend-section` (P04) | `orchestrator:specify --amend` | `specs/<NNN>-<slug>/spec.md` |

M013's `--dry-run` format is not retrofitted by M014 (see spec §FR-19).

## Failure Semantics

Inherited from M016/M021 zero-prompt discipline and M013/FR-13 strict-mode precedent:

- Missing prerequisites (`.orchestrator/` absent, templates missing): exit 2 with diagnostic pointing to the install path (`orchestrator:init`) or the missing artifact.
- Slug collision without `--force`: exit 1, mention the `--force` override.
- Dual-write failure mid-run: `unit_close` records `dual_writes` count < 2 so operators can detect partial writes in the execution log.
- Execution-log append failure: **warn on stderr but do not fail the command** — observability is best-effort, not load-bearing on scaffold success.

## Complexity Probe (FR-5)

`scripts/knowledge/spec-complexity-probe.sh <spec-path>` evaluates a draft spec against five dimensions and emits a single-line verdict plus four structured fields. Thresholds live in `.orchestrator/config.yml` under `specify.complexity_thresholds:`. The probe was pinned in M014/P04 per the corpus-calibration memo at `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md`.

### Dimensions

- **`fr_count`** — number of `^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+` matches. Above-threshold at ≥ `fr_count` (default 15).
- **`user_story_count`** — number of `^### User (Story|Scenario)` matches. Above-threshold at ≥ `user_story_count` (default 5).
- **`raw_token_count`** — `wc -w` of the spec file. Above-threshold at ≥ `raw_token_count` (default 8000).
- **`todo_density`** — `<TODO>` count / (`<TODO>` count + section count). Above-threshold at ≥ `todo_density` (default 0.5).
- **`contradiction_signals`** — LLM-derived contradiction count (CC only; Codex/Cursor emit 0). Above-threshold at ≥ `contradiction_signal_count` (default 1).

### Hardening-spec exception

When `specify.hardening_spec_exception: true` (default) and `fr_count == 0`, the probe returns `below-threshold` unconditionally. Rationale: M016 and M021 hardening milestones have zero FR-list but legitimate user-story counts; the exception prevents false-positive above-threshold firings on small hardening specs. Documented in the calibration memo.

### Runtime split (CON-2)

Heuristic dimensions (`fr_count`, `user_story_count`, `raw_token_count`, `todo_density`) are runtime-agnostic. `contradiction_signals` is CC-only; Codex/Cursor runtimes emit `contradiction_signals=0`. See `RUNTIME-ASSUMPTIONS.md` FR-5 for the full runtime-parity obligation.

### Observability

Every probe invocation appends one `spec_complexity_probe` JSONL record to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape: `{type, ts, spec_path, verdict, reason, fr_count, user_story_count, todo_count, contradiction_signals, llm_calls, elapsed_ms, source}`.

## Conversus Pressure-Test (US-3, FR-6)

When the FR-5 probe fires `above-threshold`, `orchestrator:specify` prints a single-line prompt `conversus pressure-test recommended (<reason>). [y/n/d]` and reads one character from the controlling terminal.

### Prompt resolution

- Under `--yes` or non-TTY stdin: defaults to `n` silently (preserves SC-7 zero-prompt baseline).
- On `y`: invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> specs/<NNN>-<slug>/conversus/summary/final.md`.
- On `d`: invokes `scripts/specify/specify.sh split <spec>` (see Decomposition Flow).
- On `n`: proceeds silently; no side effects.

### Preset

`templates/conversus-presets/spec-pressure-test.yml` (FR-6) — red-blue adversarial deliberation: blue argues shippable, red argues fatal flaw, arbiter grounds verdicts in `.orchestrator/memory/constitution.md` (Principle II Evidence Before Claims, Principle III Design Before Code, Principle XV Surgical Precision). Verdict: PASS|BLOCK.

### Adapter exit-code handling (M013/FR-13 precedent)

- `0` + `SKIPPED:` on stdout → adapter binary missing in non-strict mode (not applicable under `--strict`).
- `0` otherwise → PASS; proceed.
- `2` → BLOCK; record verdict, surface diagnostic, exit 0 with the scaffold intact.
- `1` → ERROR (including `--strict` with missing adapter binary); surface diagnostic, exit 1.

Every `y` invocation appends one `conversus_gate_invocation` JSONL record to `.orchestrator/execution-log.jsonl` per FR-16 + M013/FR-17 shape.

### No adapter modification (D007 + CON-4)

M014 ships preset + prompts only. `scripts/dispatch/adapters/tool/conversus.sh` is unchanged. Under `--strict`, adapter absence fails loudly.

The adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default (M026/P02); operators set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. Edition is reported on the `conversus_gate_invocation` JSONL record emitted per gate run. See `commands/conversus-gate.md` for the full resolver order and edition-aware diagnostics.

## Decomposition Flow (FR-7)

`orchestrator:specify split <path>` proposes a 2–N-way decomposition of a large draft. CC only in v1 per CON-2.

### Runtime gate

- Under Claude Code runtime (`CLAUDE_CODE_RUNTIME=1` or `scripts/lifecycle/detect-capabilities.sh --runtime` = `claude-code`): invokes `scripts/dispatch/dispatch-interface.sh --prompt-file templates/spec-splitter-prompt.md --input-file <spec> --mode oneshot`.
- Under Codex/Cursor: exits 3 with diagnostic pointing to manual decomposition.

### Manifest shape

The splitter emits a YAML manifest with `type: decomposition-manifest` and an entries list of 2–4 proposed sub-specs. Each entry has `slug`, `slice` (one-line description of owned subset), `inherited_user_stories` (array of `US-N` identifiers from source), and `rationale` (one-line coherence argument).

Cap at 4 sub-specs is prompt-enforced and script-verified; larger decompositions indicate the source isn't ready to split yet.

### Interim path (FR-7 + D016)

The manifest lands at `.orchestrator/specify/decomposition/<source-id>/manifest.md` in v1. When M024 (Universal Intake & Routing) ships, the manifest path migrates to `.orchestrator/intake/<id>/decomposition.md`. The manifest schema is write-forward-compatible; only the file location changes.

## `--amend` Three-Case Semantics (FR-14)

`orchestrator:specify --amend <path>` re-scaffolds an existing spec without overwriting authored content. Per top-level `^## ` section, the amend engine classifies and routes:

### Case (a) — all-placeholder

Section contains `<TODO>` markers and zero authored prose bytes. Under CC: re-run FR-3 LLM-fill (deferred in P04; tracked in RUNTIME-ASSUMPTIONS.md FR-3). Under Codex/Cursor: leave unchanged.

### Case (b) — partial-placeholder

Section contains both `<TODO>` markers and authored prose. Leave both bytes unchanged; log a one-line diagnostic naming the section. Operator resolves manually — this is the Constitution III + XIV guard on spec mutation (the amend engine does not pick between placeholder and authored content).

### Case (c) — fully-authored

Zero `<TODO>` markers. Leave unchanged byte-identically.

### Changed-section computation (US-3 AS-7)

A section is "changed" if either: `<TODO>` count changed, or `shasum -a 256` of authored (non-placeholder) prose bytes changed. FR-5 re-probe fires on changed sections only — prior deliberation state is preserved per CON-5 + CON-8. This closes the loop on M013's D014 pattern: post-deliberation edits are preserved, not re-deliberated.

### SC-14 byte-preservation invariant

`shasum` of pre-amend file bytes equals post-amend file bytes when all sections classify as (b) or (c). Verified by `tests/fixtures/m014-p04/amend-seed-spec.md` + `scripts/verify/m014-p04-amend-three-case.sh` at milestone close.

## Comment Classification & Workflow Routing

*Added by M014/P03 (2026-04-24). See `.orchestrator/DECISIONS.md` D023 for
the regex/heuristic v1 baseline pin and retune trigger.*

### Pipeline (orchestrator:comments classify)

1. `scripts/comments/fetch.sh` enumerates unactioned Giscus + GitHub Issue/PR
   comments, caches each to `.orchestrator/comments/inbox/<comment-id>.json`,
   skips entries already in `.orchestrator/comments/actioned.jsonl`.
2. `scripts/comments/classify.sh <inbox-file>` emits per-comment verdict
   `class=<class> confidence=<score> reason=<rule-id>` for one of four FR-9
   classes: `uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`.
3. `scripts/comments/comments.sh` master pipeline routes per class:
   - `uat-bug` >= threshold → M013/FR-10 UAT ingestion path (auto-apply).
   - `decision-append` >= threshold → templated block appended to `DECISIONS.md`.
   - `spec-amendment` (any confidence) → review-queue (NEVER auto-applies).
   - `ambiguous` → `scripts/dispatch/adapters/tool/conversus.sh gate
     classify-comment` (--strict); on PASS-with-reclassification, route to
     new class; on BLOCK / low-confidence / adapter unavailable, route to
     human triage bucket.

### Regex/heuristic v1 ruleset (D023)

See `scripts/comments/classify.sh` rules R1-R10 inline. Confidence values
are coarse (0.7–0.95 in 0.05–0.10 steps) pinned on intuition + four-class
precedent, NOT on measured precision/recall. Retune trigger documented below.

### Auto-apply thresholds

`.orchestrator/config.yml` `comments.auto_apply_threshold:` — per-class:

| Class | Default | Behavior at/above threshold |
|---|---|---|
| `uat-bug` | 0.8 | Route through M013/FR-10 UAT ingestion. |
| `decision-append` | 0.8 | Append templated block to `DECISIONS.md`. |
| `spec-amendment` | 1.0 | NEVER auto-applies (CON-5/SC-5 invariant). |
| `ambiguous` | 1.0 | Always conversus-triage. |

Operators tune by editing `.orchestrator/config.yml`. SC-4 measures precision
on dogfood data; SC-5 forbids auto-apply regardless of `spec-amendment` threshold.

### Spec-amendment human-gate (CON-5/SC-5/Constitution III + XIV)

The `apply <queue-id>` subcommand is the SINGLE path for spec mutation from
comments. No script under `scripts/comments/` auto-applies a spec-amendment
regardless of confidence score. `scripts/verify/m014-p03-spec-amendment-human-gate.sh`
asserts this invariant mechanically.

### D023 retune trigger

The regex/heuristic v1 baseline is provisional. Open a follow-up D-row to
re-pin FR-9 shape when EITHER condition holds:

1. `actioned.jsonl` shows >=30 fetched comments across the four classes.
2. Classifier confidence calibration on observed comments diverges from
   regex/heuristic predictions in >=20% of samples (sample = comment whose
   conversus-triage verdict OR human-triage outcome disagrees with the
   regex/heuristic verdict).

Either trigger justifies escalating to one of the alternative shapes from
spec OQ #C-1 (embedding-distance, LLM-call-per-comment, two-pass hybrid).

### FR-19 dry-run manifest shape (comments)

`comments classify --dry-run` emits JSONL action records to stdout:

```
{"command":"comments classify","action_type":"<action>","target_path":"<path>","source_ref":"<url>","description":"<text>"}
```

`action_type` values: `cache-comment`, `classify-comment`, `auto-apply-uat-bug`,
`auto-apply-decision-append`, `queue-spec-amendment`, `route-ambiguous-to-conversus`,
`apply-amendment`, `reject-queue-item`.
