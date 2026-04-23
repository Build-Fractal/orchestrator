---
schema_version: "1.0"
type: feature-spec
feature_slug: "021-github-installer-coexistence"
created_at: "2026-04-23"
status: "Draft"
milestone: "M025"
remediates: "M013/P04/T04"
---

# Feature Specification: 021-github-installer-coexistence

**Feature Branch**: `021-github-installer-coexistence`
**Created**: 2026-04-23
**Status**: Draft
**Milestone**: M025
**Input**: User description: "Remediate the M013/P04 regression where scripts/dispatch/adapters/runtime/claude-code.sh --hook-config emits an invalid-schema blob that packaging/install/install-claude-code.sh then writes verbatim to ~/.claude/settings.json, overwriting any pre-existing user settings (e.g. GSD hooks). Three outcomes: (a) --hook-config emits valid Claude Code hooks shape mapping the six orchestrator lifecycle events to real CC events; (b) the installer merges into an existing settings.json instead of overwriting, preserving unrelated sibling hook configurations; (c) a coexistence test fixture proves a GSD-shaped settings.json survives an orchestrator install. Bash-3.2 / optional-jq constraints apply. FR-11 reversibility is preserved — uninstall returns the file to its pre-install shape byte-identically."

## Problem Statement

`packaging/install/install-claude-code.sh` overwrites `$HOME/.claude/settings.json` with the stdout of `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config`. Two independent bugs stack:

1. **Schema invalidity** — `claude-code.sh --hook-config` (lines 135–149) emits wrapper metadata (`runtime`, `hook_count`, `target_file`) around a `hooks: [{event, command}]` array whose `event` values are orchestrator lifecycle names (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`, `post_verify`) that Claude Code does not recognize. Real CC hook events are `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `Notification`, etc., with matcher-based dispatch. Even a clean install produces a no-op hook block.

2. **Unconditional overwrite** — `install-claude-code.sh:146` does `printf '%s\n' "$hook_json" > "$hook_target"`. `--force` is gated (line 142), but the gate only fires when the file already exists; first-time installs clobber without warning. There is no merge path, so any pre-existing `settings.json` owned by a sibling tool (GSD, developer-authored entries, MCP server configs) is destroyed.

Concrete user harm: when a developer runs the orchestrator installer in a repo that already hosts GSD hooks at `~/.claude/settings.json`, Claude Code fails to start on next launch because the overwritten file contains the orchestrator's non-CC schema. The restore path is manual (`cp settings.json.pre-m008-<date> settings.json`). This breaks the "install the orchestrator into an existing project" user journey that M015 cutover promised.

This spec remediates both bugs and adds a coexistence test fixture. Out of scope: redesigning the hook system, moving hooks to project-level `.claude/settings.json`, wiring hooks through a runtime-neutral adapter, or changing the six orchestrator lifecycle event names (those remain the internal vocabulary; this spec only changes how they're *projected* to Claude Code).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

US-1 (schema correctness) + US-2 (merge, not overwrite) + US-3 (coexistence fixture) form the load-bearing slice. Each is independently verifiable; together they close the "install orchestrator on top of a pre-existing `settings.json`" loop. US-4 (uninstall reversibility) builds on US-2.

### User Story 1 — Hook-config emits valid Claude Code schema (Priority: P1)

A developer runs `bash packaging/install/install-claude-code.sh` on a fresh `$HOME/.claude/` (no prior `settings.json`). After install, `claude` starts cleanly and `claude --help` succeeds. The written `~/.claude/settings.json` parses against Claude Code's `hooks` schema (real CC event names, matcher shape) and registers at least the `post_verify` hook against `Stop` or an equivalent terminal CC event.

**Why this priority**: Without valid schema, every other surface in this spec is pointless — even a perfect merge preserves an invalid block. This story is the bottom of the dependency stack.

**Independent Test**: `tests/m025-p01-hook-schema.sh` — runs the installer into an `HOME=$(mktemp -d)` fixture, parses the resulting `settings.json` with python's `json.tool`, asserts (a) no `runtime`/`hook_count`/`target_file` wrapper keys at root, (b) `hooks` object keyed by valid CC event names, (c) at least one `post_verify`-equivalent entry maps to a real CC event.

**Acceptance Scenarios**:

1. **Given** `HOME=$(mktemp -d)` with no prior `~/.claude/settings.json`, **When** `install-claude-code.sh` runs, **Then** `settings.json` exists, parses as JSON, and contains a top-level `hooks` object with real CC event names (`PreToolUse`|`PostToolUse`|`Stop`|`SessionStart`|`Notification`|`UserPromptSubmit`).
2. **Given** the installed `settings.json`, **When** checked against the schema published at `https://json.schemastore.org/claude-code-settings.json` (or a pinned local copy), **Then** validation passes.
3. **Given** the mapping from orchestrator lifecycle events to CC events, **When** inspected, **Then** each of the six orchestrator events (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`, `post_verify`) is either (a) mapped to a concrete CC event+matcher pair, or (b) explicitly documented as "deferred — no clean CC equivalent" with a tracking note. No orchestrator event is silently dropped.

### User Story 2 — Installer merges into existing settings.json (Priority: P1)

A developer with a pre-existing `~/.claude/settings.json` (containing GSD hooks, status line, or MCP server entries they authored themselves) runs the orchestrator installer. After install, all pre-existing entries survive byte-identically except where the orchestrator legitimately adds a new key. The merge is deterministic — running the installer twice produces the same file.

**Why this priority**: This is the direct user-harm fix. Without it, installing the orchestrator breaks sibling tools.

**Independent Test**: `tests/m025-p01-merge-preservation.sh` — seeds `$HOME/.claude/settings.json` with a known GSD-shaped payload, runs the installer, diffs the resulting file against the seed: the orchestrator's additions must be additive only; every pre-existing top-level key survives byte-identically; `hooks` arrays are concatenated (not replaced) with orchestrator entries appended after user entries.

**Acceptance Scenarios**:

1. **Given** a pre-existing `settings.json` with keys `{statusLine, hooks: {SessionStart: [...]}, permissions, $schema}`, **When** the installer runs, **Then** all four top-level keys are present with their original values unchanged, and `hooks` gains orchestrator entries without mutating the `SessionStart` array.
2. **Given** a pre-existing `settings.json` with a `hooks.Stop` array containing a user hook, **When** the installer adds its own `Stop` hook for `post_verify`, **Then** the resulting `hooks.Stop` array contains both entries, user entry first.
3. **Given** a second install invocation, **When** the installer re-runs, **Then** duplicate orchestrator entries are *not* appended (idempotency); the file is byte-identical to the first-install result.
4. **Given** `jq` is available, **When** the installer runs, **Then** the merge uses jq. **Given** `jq` is absent, **When** the installer runs, **Then** a bash-3.2-compatible awk/sed fallback produces the same result.

### User Story 3 — Coexistence test fixture (Priority: P1)

A CI gate demonstrates the full GSD ↔ orchestrator coexistence loop: pre-seed a GSD-shaped `settings.json`, run the orchestrator installer, assert both hook sets are honored by a dry-run CC launch check.

**Why this priority**: Locks in the fix against regression. Without this fixture, US-1 and US-2 can silently re-break at any future installer change.

**Independent Test**: `tests/m025-p01-coexistence.sh` — fixture-driven; lives next to existing `tests/fixtures/m013-p04/` patterns. Pre-seeds, installs, asserts, then uninstalls and asserts restoration (wires US-4).

**Acceptance Scenarios**:

1. **Given** `tests/fixtures/m025-p01/gsd-baseline/settings.json` (representative GSD content), **When** the gate runs, **Then** the post-install file contains both the GSD hooks and the orchestrator hooks with deterministic merge order.
2. **Given** the fixture file is authoritative, **When** its contents change, **Then** the gate fails with a clear diff showing what merge behavior regressed.

### User Story 4 — Uninstall reversibility preserves FR-11 (Priority: P2)

An operator removes the orchestrator's integration by running an uninstall path (either `install-claude-code.sh --uninstall` or a documented manual recipe). After uninstall, `~/.claude/settings.json` is byte-identical to its pre-install state — orchestrator-added keys are removed; unrelated user keys are untouched.

**Why this priority**: M013 FR-11 committed the GitHub integration to reversibility; the same posture must apply to settings.json modifications.

**Independent Test**: `tests/m025-p01-uninstall-reversibility.sh` — round-trip test: capture pre-install sha256, install, uninstall, capture post-uninstall sha256, assert equal. Requires a tagged-marker convention in the merged settings.json so the uninstaller knows what to remove.

**Acceptance Scenarios**:

1. **Given** a pre-install `settings.json` with sha256 `X`, **When** install then uninstall runs, **Then** the post-uninstall file has sha256 `X`.
2. **Given** the orchestrator's merged entries are tagged (e.g., `"_orchestrator_managed": true` on inserted objects, or a sidecar manifest at `~/.claude/settings.json.orchestrator-managed.json`), **When** the uninstaller reads the tags, **Then** it removes only tagged entries.

---

## Edge Cases

- **Malformed pre-existing settings.json** — installer encounters a `settings.json` that doesn't parse as JSON. Defined behavior: abort with a clear error, do not overwrite, exit code 4. Do not attempt repair.
- **jq version skew** — `jq` 1.4 vs 1.6 vs 1.7 produce subtly different output formatting. Defined behavior: jq path normalizes with `jq -S .` (sorted keys); fallback awk path produces semantically-equivalent but not byte-identical output, documented as acceptable.
- **Read-only $HOME/.claude/** — defined behavior: installer detects write failure on target, exits 1 with FAIL message, does not attempt to create a writable copy elsewhere.
- **Concurrent installer invocations** — two operators running the installer simultaneously could race the read-merge-write cycle. Defined behavior: P01 documents the race as a known limitation (Tier B scope); lock acquisition is deferred to a future hardening milestone.
- **Settings.json grows beyond reason across repeat installs** — idempotency check (AS3 of US-2) must prevent duplicate entry accretion. Gate with a hard assertion on file size growth across double-install.

---

## Functional Requirements

- **FR-1 (valid-cc-schema)**: `claude-code.sh --hook-config` emits JSON conforming to Claude Code's `hooks` schema — no wrapper metadata (`runtime`, `hook_count`, `target_file`) at root; `hooks` is an object keyed by CC event names; each entry uses CC's `matcher`+`hooks[].command` shape. Satisfies US-1.
- **FR-2 (event-mapping)**: Each of the six orchestrator lifecycle events maps to either (a) a concrete CC event+matcher pair, or (b) an explicit deferral with a `TODO(M###)` tracking note in the adapter source and `references/hooks.md`. Satisfies US-1 AS3.
- **FR-3 (merge-not-overwrite)**: `install-claude-code.sh` merges its emitted hook entries into any pre-existing `~/.claude/settings.json`, preserving all unrelated top-level keys and unrelated `hooks` event arrays byte-identically. Satisfies US-2.
- **FR-4 (jq-optional-fallback)**: Merge logic works with `jq` absent; a bash-3.2-compatible awk/sed fallback produces semantically-equivalent output. Satisfies US-2 AS4.
- **FR-5 (installer-idempotency)**: Running the installer twice produces a byte-identical `settings.json` on the second run (no duplicate orchestrator entries). Satisfies US-2 AS3.
- **FR-6 (coexistence-fixture)**: `tests/fixtures/m025-p01/gsd-baseline/settings.json` exists and is exercised by `tests/m025-p01-coexistence.sh`. Satisfies US-3.
- **FR-7 (managed-entry-tagging)**: Orchestrator-added entries in `settings.json` carry a machine-readable tag (inline property or sidecar manifest) enabling selective uninstall. Satisfies US-4 AS2.
- **FR-8 (uninstall-reversibility)**: A documented uninstall path (flag or manual recipe in `references/installation.md`) removes only tagged entries and leaves the file byte-identical to pre-install state. Satisfies US-4 AS1.
- **FR-9 (runtime-scope)**: Changes are scoped to the Claude Code runtime adapter + installer. Codex and Cursor adapters/installers are not modified. Parity with FR-12 Claude-Code-only v1 posture from M013.
- **FR-10 (recent-changes-dual-write)**: Any change that alters an operator-facing surface dual-writes to `CLAUDE.md` and `AGENTS.md` Recent Changes regions via `scripts/util/dual-write-runtime-md.sh` (already consumed by `orchestrator:specify`).

## Success Criteria

- **SC-1**: `bash tests/m025-p01-hook-schema.sh` exits 0. Asserts FR-1, FR-2.
- **SC-2**: `bash tests/m025-p01-merge-preservation.sh` exits 0. Asserts FR-3, FR-4, FR-5.
- **SC-3**: `bash tests/m025-p01-coexistence.sh` exits 0. Asserts FR-6; end-to-end proof.
- **SC-4**: `bash tests/m025-p01-uninstall-reversibility.sh` exits 0. Asserts FR-7, FR-8.
- **SC-5**: `bash tests/m025-p01-bash32-compat.sh` exits 0 on all new/modified scripts (follows M013/P04 bash-3.2 compat pattern).
- **SC-6**: `bash tests/m025-p01-phase-suite.sh` aggregates SC-1..SC-5 and passes.
- **SC-7**: `references/installation.md` contains uninstall recipe; `references/hooks.md` contains the six-event → CC-event mapping table. Manual check that both files reference FR-7 tagging convention.
- **SC-8**: `CHANGELOG.md` entry filed under a v0.9.1 heading naming the M013/P04/T04 regression and its fix.

## Non-Goals

- Not changing the orchestrator lifecycle event names — the internal vocabulary (`before_tasks`, etc.) stays; only the Claude Code projection changes. Rationale: avoiding a cross-cutting rename when the bug is isolated to one adapter.
- Not fixing the Codex or Cursor installers in the same phase — M025 is Claude-Code-scoped per FR-9, matching M013's FR-12 v1 posture. Rationale: Codex/Cursor don't write `$HOME/.claude/settings.json` anyway; their coexistence story is separate.
- Not introducing project-level `.claude/settings.json` support — that's a larger design change owned by a future milestone. Rationale: out of scope for a targeted regression fix.
- Not redesigning the six orchestrator lifecycle events — a clean CC-event mapping for every one is discovered by FR-2; gaps become documented deferrals, not in-scope redesign work.
- Not building a generic settings.json merger for arbitrary third-party tools — only the GSD shape is pre-seeded into the fixture; general-purpose preservation follows from "treat unknown keys as opaque" (FR-3).

## Constraints

- **CON-1 (bash-32-compat)**: All new scripts must pass `bash32-compat` gate. No associative arrays, no `mapfile`, no process-substitution in portable paths. Matches M013/P04 pattern.
- **CON-2 (jq-optional)**: `jq` is an optional dependency per CLAUDE.md Active Technologies. Every jq-consuming code path needs a non-jq fallback.
- **CON-3 (home-guard)**: All code that writes `$HOME/.claude/*` must guard against `$HOME` being empty or `/`. Pattern lifted verbatim from `claude-code.sh:76-79`.
- **CON-4 (dry-run-honesty)**: `--dry-run` must emit `would_write=<path>` + a canonical post-merge preview, not skip the merge computation entirely. A dry-run must be observationally equivalent to real-run except for the final `> file` write.
- **CON-5 (fr-12-runtime-scope)**: No edits to `packaging/install/install-codex.sh`, `packaging/install/install-cursor.sh`, or their adapter peers. Enforced by a negative-grep gate per the `FR-12-v1-negative-grep-guard` pattern.

### Knowledge-Layer Boundary (M025 vs. M013)

M025 writes pattern entries to `knowledge/patterns/` (merge-not-overwrite, jq-optional-fallback, tagged-managed-entries) and lesson entries to `knowledge/lessons/` (capturing how the regression happened — M013/P04/T04 did not exercise a pre-existing-settings-file path in its gates). M025 does NOT touch `knowledge/spec/**` (owned by M011/M012) and does NOT edit M013's consolidated knowledge retroactively; instead, a `knowledge/lessons/MEM0##.md` entry cross-references M013/P04/T04 as the originating regression.

## Assumptions

- Claude Code's published hook schema is stable and documented. (If absent, FR-1 uses the shape observed in working GSD `settings.json` files as the de-facto contract.)
- `$HOME/.claude/settings.json` is the canonical location; no migration to XDG-conformant paths is in flight.
- `scripts/util/dual-write-runtime-md.sh` works as documented for FR-10.
- M013 is closed and no further M013/P04 commits are expected; M025 can stage over a stable M013 tree.
- The GSD-shaped fixture `{statusLine, hooks.SessionStart, hooks.PostToolUse, permissions}` is a representative baseline; real-world user settings may include more keys, but opaque-preservation handles them generically.

## Constitution Check

- **Principle II (Evidence Before Claims)**: Every FR names a concrete script or artifact. SC-1..SC-8 are mechanical checks; no subjective verification. The regression itself was evidence-gathered (commits `d33b8a7`, filesystem state `settings.json.broken-orchestrator-20260422`).
- **Principle III (Design Before Code)**: The event-mapping decision (FR-2) surfaces as an open question (Q-1) explicitly deferred to `orchestrator:plan-phase` rather than discovered mid-implementation.
- **Principle IV (Plans Assume Zero Context)**: Phase plan will embed the full FR/SC table + the problematic code paths with file:line references so task dispatch needs no additional context.
- **Principle VII (Knowledge Compounds)**: Remediation is filed as a lesson entry cross-referencing M013/P04/T04 so the original milestone's consolidated knowledge gains a pointer to "here is where that phase's gate coverage was insufficient."
- **Principle XIV (No Speculative Complexity)**: Explicit non-goals rule out generic-merger, multi-runtime, and lifecycle-event-rename work.
- **Principle XV (Surgical Precision)**: FR-9 pins the blast radius to the Claude Code adapter + installer. Negative-grep gate (CON-5) enforces.

## Open Questions (defer to planning)

- **#Q-1 event-mapping-policy**: What is the concrete mapping from each of the six orchestrator lifecycle events to Claude Code's real events? Candidate: `post_verify` → `Stop`; `before_commit` → `PreToolUse` with matcher `Bash` + command-regex for `git commit`; `before_tasks`/`after_tasks` → likely deferred (no clean CC equivalent — tasks are an orchestrator concept). Planner decides per-event at `orchestrator:plan-phase M025 P01`.
- **#Q-2 tagging-shape**: Inline tag (`"_orchestrator_managed": true` on each inserted object) vs sidecar manifest (`~/.claude/settings.json.orchestrator-managed.json` listing inserted keys)? Tradeoff: inline is self-contained but adds non-standard keys to a schema-validated file; sidecar keeps the file clean but splits authority. Planner decides.
- **#Q-3 install-test-fixture-runtime**: Do we require Claude Code itself to be installed to run the fixture gate (invoke `claude` to observe it parses the file), or does `json.tool`-level validation suffice? Affects CI preconditions.

## Dependencies

- **M013/P04/T04** — the originating regression. This spec reads its commit `d33b8a7` to understand what was added; it does not modify M013 artifacts.
- **`scripts/util/dual-write-runtime-md.sh`** (M014/P01) — consumed for FR-10.
- **Claude Code hook schema** — authoritative source at `json.schemastore.org` or equivalent upstream reference.

## Downstream Consumers (informational, not binding)

- **M009 (runtime parity audit)** — will consume `RUNTIME-ASSUMPTIONS.md` entries this spec adds (hook-mapping assumptions per runtime).
- **M019 Tier 2+3 (observability)** — the `_orchestrator_managed` tagging convention (if chosen for #Q-2) becomes a precedent for tagging other orchestrator-added user-scope artifacts.
- **Future Codex/Cursor settings-merge parity milestone** — inherits the merge-not-overwrite pattern established here.
