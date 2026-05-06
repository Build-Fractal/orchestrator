---
description: "Use when a developer wants to see the full work hierarchy at a glance — feature → milestone → phases → tasks → current dispatch — with per-row cost columns and progress bars. Renders read-only from on-disk state."
---

# orchestrator:where

Read-only tree renderer for the work hierarchy. Composes existing M013 / M018 / M019 / M027 surfaces into a glanceable view; never mutates state; never invokes GitHub APIs.

This is the M029 / FR-5 surface — the operator's "where am I in this feature, and what is in flight right now?" skill. When the active feature spans multiple milestones (per AD-6 cross-milestone data model), `where` renders the full feature view and marks the active milestone within it; collapsed inactive milestones expand under `--expand-all`.

The skill is **read-only** (CON-1 / FR-14): no writes anywhere, no log emission, no state mutation. Production rendering is performed by `scripts/diagnostics/render-position.sh` (the renderer engine); this skill instructs the agent to invoke the engine and pass its output through unchanged. This mirrors `commands/context.md` (the P01 precedent for LLM-instruction skills).

## Prerequisites / State Check

- The active milestone resolves via `scripts/state/find-active-milestone.sh` (returns `NONE` when no milestone is active; the renderer prints a one-line `no active milestone` notice and exits 0).
- Invocation context is single-resolved via `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve discipline; Principle XI). The renderer reads its three-line env block; this skill MUST NOT re-implement TTY / CI / runtime detection.
- The cross-milestone data model contract at `references/cross-milestone-feature-shape.md` is on disk (AD-6 SSOT for the feature-spec frontmatter schema, the reverse-lookup advisory, and the inactive-render shape).

## Core Workflow

1. Resolve invocation context once at command entry by reading
   `scripts/state/detect-invocation-context.sh`'s emitted env block.
2. Invoke `scripts/diagnostics/render-position.sh` with the operator's
   flags forwarded unchanged.
3. Print the renderer's stdout verbatim. ANSI color is the resolver's
   call: `renderer=tui` keeps color; `renderer=plain|json` strips it.
4. On non-zero exit, surface the renderer's stderr unchanged. The renderer
   exits 0 in degraded states (no active milestone, missing roadmap, etc.);
   non-zero exits are usage / unknown-flag errors only.

## Glyph Legend

The canonical glyph alphabet (pinned by `references/cross-milestone-feature-shape.md`). Every glyph in `where`'s output comes from this set; no other glyphs may appear.

- `✓` — phase or task complete (P##-SUMMARY.md or T##-*-SUMMARY.md exists).
- `▶` — phase or task currently executing (PLAN exists, SUMMARY does not, last verify did not fail).
- `◇` — phase or task pending (no plan yet on disk).
- `✗` — phase or task failed (last verify_result record was `fail`).
- `▽` — savings marker for `--live` mode (FR-8). The canonical compact form is `▽ saved Nk` (#Q-G8 resolution); any verbose suffix that appends provenance after the magnitude is reserved for a future `--verbose` mode and MUST NOT appear in v1 output. See `references/cross-milestone-feature-shape.md` for the verbatim contract.

The at-rest renderer (`render-position.sh`) NEVER emits `▽` itself — that glyph is reserved for the live-tail mode that lands in P03.

## Flags

All flags are forwarded to `scripts/diagnostics/render-position.sh` unchanged.

- `--milestone <M###>` — render only the named milestone (active-only view; default behavior is the FULL feature view per FR-13).
- `--expand-all` — expand every milestone's full phase tree (default: inactive milestones are collapsed). Resolves #Q-5.
- `--feature <slug>` — override the active feature; used by SC-5 fixtures to point at a known feature.
- `--no-cost` — operator-side per-row cost column suppression. FR-6's pre-M019 detection is automatic and silent (CON-3).
- `--root <path>` — override the `.orchestrator/` root for fixturing; required by SC-5 / SC-6 / SC-14 fixtures.
- `-h`, `--help` — print usage to stdout, exit 0.

## Output

A tree on stdout. Each milestone in the cross-milestone feature view renders as either a single collapsed line (default for inactive milestones) or a full phase tree (active milestone, plus any milestone under `--expand-all`). The collapsed form follows the AD-6 #Q-5 shape:

```
<glyph> M### <name>  ▓░ X% (k/n phases)
```

Per-row cost cells are populated by `scripts/diagnostics/metrics-rollup.sh --granularity task` ONLY when the milestone's `execution-log.jsonl` carries M019 Tier 1 `dispatch_usage` records. When absent, the cost column is OMITTED entirely — no blank column, no stderr warning (FR-6 / CON-3 silent suppression).

Reads-only; never writes to `.orchestrator/`. ANSI color is auto-stripped when piped or under CI per the AD-1 resolver (`renderer=plain` or `renderer=json`).

## Idempotency

`where` is purely read-only and idempotent. Running it twice against an unchanged disk produces byte-identical stdout (modulo M027 metrics that may have updated under live dispatch). It never holds locks. It never modifies log files. Running it during an active dispatch is safe.

## Error Handling

The skill MUST exit 0 even when state is degraded; the operator sees a degraded-but-rendered tree rather than a crash:

- No active milestone → `no active milestone` one-line notice; exit 0.
- Spec frontmatter missing both `milestone:` and `milestones:` → `feature <slug> declares no milestone; nothing to render`; exit 0.
- Spec declares both `milestone:` AND `milestones:` (schema violation) → `WARN:` on stderr identifying the ambiguity; render proceeds preferring the plural form (Principle XV: surgical precision; loud surface, no crash).
- Reverse-lookup mismatch → `WARN: feature <slug> spec frontmatter declares <set>; reverse-lookup discovered <set>; using spec` on stderr; render proceeds from the spec's declaration (Principle XI — spec is authoritative).
- Missing `M###-ROADMAP.md` → milestone label falls back to the bare `M###` ID.
- Missing `metrics-rollup.sh` cost data → cost column suppressed silently (FR-6 / CON-3).

Stderr `WARN:` lines are advisory and never block render. Non-zero exit is reserved for usage errors (`exit 2` on unknown flag).

## Constraints

- **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`. The only allowed write site is `${TMPDIR:-/tmp}/m029-rp.$$/` for transient resolver / oracle capture (per `run-probe.sh` scope rule 4 — `/tmp/` is the staged probe domain). The renderer `trap`s on EXIT to remove that directory. SC-14's milestone-grain readonly-invariant gate enforces this.
- **No GitHub API (CON-4 / FR-11)**: the renderer MUST NOT invoke `gh` or any GitHub HTTP API; the M013 sidecar (the `github.json` file under the `integrations` subtree of `.orchestrator/`) is NOT read in v1. SC-13's anti-coupling guard greps the renderer + this skill doc for the M013 sidecar path token and returns no matches. The M013 sidecar remains readable by `orchestrator:github-status` and `orchestrator:github-sync` — those skills are unchanged.
- **AD-1 single-resolve (Principle XI)**: this skill MUST NOT re-derive TTY / CI / runtime detection. The renderer reads `scripts/state/detect-invocation-context.sh`'s env block exclusively.
- **AD-6 cross-milestone data model**: feature-spec frontmatter declares either `milestone: M###` (singular legacy) OR `milestones: [M###, ...]` (plural AD-6). Exactly-one-of. See `references/cross-milestone-feature-shape.md`.
- **Glyph alphabet (#Q-G8)**: the savings glyph `▽` has canonical compact form `▽ saved Nk` only; any verbose suffix appending provenance after the magnitude MUST NOT appear anywhere in this skill or its renderer. The at-rest renderer (`render-position.sh`) NEVER emits `▽`; that glyph is P03 `--live` mode-only. See `references/cross-milestone-feature-shape.md` for the verbatim contract.

## Referenced Scripts

- `scripts/diagnostics/render-position.sh` — the renderer engine. This skill invokes it with the operator's flags forwarded unchanged.
- `scripts/state/detect-invocation-context.sh` — AD-1 single-resolve invocation-context resolver.
- `scripts/state/find-active-milestone.sh` — active-milestone resolver.
- `scripts/state/read-roadmap.sh` — roadmap parser (used by the renderer for milestone-name + phase-list extraction).
- `scripts/diagnostics/summarize-milestone.sh` — collapsed inactive-milestone summary helper (AD-4 SC-8 oracle).
- `scripts/diagnostics/metrics-rollup.sh` — per-row cost column source (M027, read-only consumer).

## Reference Files

- `references/cross-milestone-feature-shape.md` — AD-6 cross-milestone schema contract; this skill's output shape (collapsed / expanded inactive lines, glyph alphabet, reverse-lookup advisory) is pinned there.
- `references/status-headline-shape.md` — sibling P01 design contract; `where`'s tree reuses the headline's field vocabulary in the milestone progress-bar tail.
- `references/status-json-schema.md` — sibling P01 design contract.
- `commands/status.md` — sibling P01 skill that the operator hits at session resume; `commands/where.md` is the tree-view counterpart.
- `commands/context.md` — sibling P01 skill; LLM-instruction-doc precedent (the agent reads the skill, invokes the script, prints the output).
- `.orchestrator/milestones/M029/M029-CONTEXT.md` — AD-1 / AD-6 / AD-9 authorities.
- `specs/037-roadmap-visibility-cli-ux/spec.md` — the M029 spec carries FR-5 / FR-6 / FR-11 / FR-13 / FR-14 / CON-1 / CON-3 / CON-4 / SC-13 / SC-14.
