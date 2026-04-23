---
description: "Use when authoring a new feature spec. Scaffolds specs/<NNN>-<slug>/spec.md conforming to the FR-2 Section Contract and dual-writes a Recent Changes entry to CLAUDE.md + AGENTS.md."
---

# orchestrator:specify

Scaffold a new feature spec from a natural-language description. The scaffolded `specs/<NNN>-<slug>/spec.md` matches the Section Contract pinned by `templates/spec-template.md`; the `AGENTS.md` and `CLAUDE.md` Recent Changes region is dual-written via the FR-12 helper; an `unit_close` record is appended to `.orchestrator/execution-log.jsonl`.

This is the load-bearing command for the M014 dogfood loop: every future milestone's spec is expected to be produced by running this command rather than hand-copying an existing `specs/*/spec.md`.

## Prerequisites

- `.orchestrator/` exists (orchestrator state root). Run `orchestrator:init` first if absent.
- `templates/spec-template.md` is the Section Contract SSOT.
- `scripts/util/dual-write-runtime-md.sh` is installed (FR-12 helper).
- `scripts/verify/spec-shape-lint.sh` is installed (FR-4 verifier, invoked downstream by `orchestrator:discuss`).

## Usage

The canonical invocation shape:

```
bash scripts/specify/specify.sh --description "<prose>" [--slug <slug>] [--milestone <M###>] [--force] [--yes] [--dry-run]
```

Flags:

- `--description <prose>` — required on create-path. The operator's natural-language description; quoted in the scaffold's `Input:` frontmatter field.
- `--slug <slug>` — optional. Kebab-case short name for the spec directory. If omitted, derived deterministically from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation) and accepted silently in `--yes` mode.
- `--milestone <M###>` — optional. Binds the scaffold to a milestone ID in the frontmatter; otherwise `<TODO: bind to milestone>`.
- `--force` — optional. Permits overwrite of an existing `specs/<NNN>-<slug>/` directory. Without this flag, slug collision exits non-zero.
- `--yes` — optional. Auto-accepts interactive prompts (slug derivation in particular). Implied under `orchestrator:auto`.
- `--dry-run` — optional. Emits FR-19 JSONL manifest records to stdout describing what would be written; no disk writes performed.

Subcommand surfaces:

- `--amend <path>` — re-scaffolds per FR-14 three-case semantics: (a) all-placeholder sections re-fill via FR-3 LLM under CC (skip under Codex/Cursor); (b) partial-placeholder sections left byte-unchanged with a diagnostic; (c) fully-authored sections unchanged byte-identically. Re-probe fires on changed sections only (US-3 AS-7).
- `split <path>` — LLM-assisted splitter (Claude Code only in v1); proposes a 2-N sub-spec decomposition manifest at `.orchestrator/specify/decomposition/<source-id>/manifest.md`. Under Codex/Cursor, prints a CC-only diagnostic and exits 3.

## Workflow

1. **Preflight**: confirm `.orchestrator/` exists; otherwise exit 2 with a pointer to `orchestrator:init`.
2. **Lock acquisition**: acquire `scripts/lifecycle/lock-manager.sh` around spec-number resolution to prevent TOCTOU (Edge Case: spec number race). Best-effort; missing lock manager does not fail the command.
3. **Number allocation**: scan `specs/NNN-*` directories; next number is `max(existing) + 1`.
4. **Slug derivation**: if `--slug` absent, derive from `--description` (first 5 words, lowercased, kebab-cased, 40-char truncation). Under `--yes`, accepted silently; otherwise print derived slug with one-keystroke accept/reject.
5. **Collision check**: if `specs/<NNN>-<slug>/` exists, exit 1 with a clear error unless `--force`.
6. **Scaffold write**: copy `templates/spec-template.md` into `specs/<NNN>-<slug>/spec.md` via temp-file-then-rename. Substitute frontmatter placeholders (`{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}`). Skeleton-only in P01 — no LLM round-trip (see `RUNTIME-ASSUMPTIONS.md` FR-3).
7. **Dual-write Recent Changes**: invoke `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content <fragment> --file CLAUDE.md --file AGENTS.md` with a one-line fragment `- <NNN>-<slug>: <first-80-chars-of-description>`.
8. **Complexity probe** (FR-5): invoke `scripts/knowledge/spec-complexity-probe.sh specs/<NNN>-<slug>/spec.md`; capture `probe=above-threshold reason=<criterion>` or `probe=below-threshold` on stdout. Emits one `spec_complexity_probe` JSONL record.

9. **Three-way prompt** (US-3 y/n/d, fires only on `above-threshold`): print `conversus pressure-test recommended (<reason>). [y/n/d]` to stderr and read one character from the controlling terminal. Under `--yes`, silently default to `n`. Under `--dry-run`, emit a FR-19 `invoke-conversus-gate` manifest record and skip. On `y`: invoke `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test specs/<NNN>-<slug>/spec.md specs/<NNN>-<slug>/conversus/summary/final.md`; handle exit codes per M013/FR-13 (0 PASS -> proceed; 0 SKIPPED -> warn + proceed; 2 BLOCK -> record + surface; 1 ERROR -> halt exit 1); emit one `conversus_gate_invocation` JSONL record. On `d`: invoke `specify.sh split <path>` (see Subcommands). On `n`: proceed silently.

10. **Observability emission**: append one `unit_close` record to `.orchestrator/execution-log.jsonl` with `{command, specs_scaffolded, dual_writes, conversus_invocations, adapter_verdicts, elapsed_ms, source: "runtime"}`.
11. **Lock release** + **stdout**: print the absolute path to the written spec; exit 0.

## Output

- `specs/<NNN>-<slug>/spec.md` — scaffolded spec, skeleton with `<TODO: ...>` placeholders in every section.
- `CLAUDE.md` Recent Changes region updated (inside `# >>> orchestrator:recent-changes >>>` markers).
- `AGENTS.md` Recent Changes region updated (same markers; skipped if `dual_write_agents: false`).
- `.orchestrator/execution-log.jsonl` gains one `unit_close` record.

## Idempotency

Re-running with the same `--slug` fails with a clear error. `--force` permits overwrite. Re-running with `--amend` is idempotent on unchanged sections.

## Error Handling

- Missing `.orchestrator/`: exit 2, point to `orchestrator:init`.
- Slug collision: exit 1, mention `--force`.
- Template missing: exit 1, point to `templates/spec-template.md`.
- Dual-write helper missing: exit 1, point to `scripts/util/dual-write-runtime-md.sh`.
- Execution-log append failure: warn on stderr but do not fail the command (observability is best-effort, not load-bearing on scaffold success).

## Referenced Scripts

- `scripts/specify/specify.sh` — this command's implementation.
- `templates/spec-template.md` — Section Contract SSOT.
- `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM prompt (invocation deferred per RUNTIME-ASSUMPTIONS.md FR-3).
- `scripts/util/dual-write-runtime-md.sh` — FR-12 marker-bounded dual-write helper.
- `scripts/verify/spec-shape-lint.sh` — FR-4 shape verifier (consumed by `orchestrator:discuss` preflight downstream).
- `scripts/knowledge/spec-complexity-probe.sh` — FR-5 probe stub (full probe in P04).
- `scripts/lifecycle/lock-manager.sh` — spec-number race mitigation.
- `scripts/dispatch/dispatch-interface.sh` — CC LLM round-trip dispatch surface (not invoked in P01).
