---
schema_version: "1.0"
type: context-draft
milestone: "M005"
status: draft
created_at: "2026-04-10T23:00:00Z"
finalized_at: null
---

## Architectural Decisions

### AD-1: Content hashing uses same sha256 prefix format as index-pipeline

Content hashes on knowledge entries and dispatch outputs use `sha256:{64-hex}` format (matching index-pipeline convention, Constitution Principle XI: Single Source of Truth). Never bare hex. Hash computed from body content only (excludes frontmatter).

### AD-2: Cost source is a closed enum, not a free string

Three cost source values: `estimated` (chars/4 heuristic), `reported` (from provider response), `unknown` (no data available). `null` cost in JSONL means unknown, `0` means actually free. This distinction is load-bearing for Conversus gate cost decisions.

### AD-3: Gate verdict schema is provider-agnostic

The verdict schema (`PASS`, `BLOCK`, `WARN`, `NEEDS_REVIEW`) is not Conversus-specific. Any hook at PRE_DISPATCH or POST_DISPATCH can return a verdict. Conversus will use the same protocol. This means non-Conversus gates (simple quality checks, budget gates) speak the same language.

### AD-4: Agent instruction schema is a template, not code

The instruction schema is a markdown template with required sections and optional sections. Enforcement is via conformance check (static grep for section headings), not runtime parsing. This keeps it Bash 3.2 compatible and avoids building a template engine.

### AD-5: Pure transforms are sourced libraries, not standalone scripts

Extracted pure transforms (payload section assembly, manifest building, compression logic) live in `scripts/lib/` as sourced functions, not in `scripts/dispatch/` as standalone scripts. They take stdin/arguments, return stdout. No file I/O inside the function — callers handle I/O.

### AD-6: Provider abstraction is a shell convention, not a protocol

Unlike Conversus (Python Protocol class) or index-pipeline (runtime-checkable Protocol), the orchestrator's provider abstraction is a documented shell convention: a provider script must accept specific arguments, set specific environment variables on exit, and write output to a specified path. Conformance is checked by the diagnostics doctor, not by a type system.

### AD-7: Autonomy permissions are introspection-generated, never `bypassPermissions`

The autonomy feature (P07) makes Tier C auto mode genuinely unattended by generating comprehensive `.claude/settings.json` allow-lists from project introspection rather than by removing safety checks. The orchestrator will never default to `bypassPermissions` — that mode removes protected path guards, which violates Principle II (Evidence Before Claims). Instead, the generator introspects `extension.yml`, `package.json`, `Makefile`, toolchain config files, and agent host directories to emit an allow-list broad enough that no "Do you want to proceed?" prompts interrupt orchestrator-initiated actions, while a declarative deny list in `templates/autonomy-defaults.yaml` gates genuinely dangerous operations (`rm -rf /`, `git push --force`, `curl | bash`, `npm publish`, etc). Safety comes from explicit enumeration, not from disabling checks.

### AD-8: Autonomy policy lives in templates, mechanics live in scripts

Following Principle X (Templating Over Inference) and Principle XI (Single Source of Truth): `templates/autonomy-defaults.yaml` declares WHAT (tier-to-mode mapping, deny list, introspection rules, compound-command / shell-builtin patterns); `scripts/lifecycle/generate-permissions.sh` implements HOW (reading project files, formatting JSON, emitting to stdout). The script has zero hardcoded policy. `extension.yml` remains the sole source of truth for the orchestrator's own script list — the generator reads it, never maintains a parallel list. Generator output is idempotent: identical project state → byte-identical stdout.

### AD-9: The generator is read-only; a separate writer handles agent-host translation

Per Principle VI (State On Disk Is Truth) and FR-10 (multi-agent-host abstraction): `generate-permissions.sh` is a pure function — it reads the project and emits a canonical JSON permissions object to stdout. It does not write files, create directories, or touch state. A separate `scripts/lifecycle/write-permissions.sh` translates the canonical format to whichever agent host is detected (`.claude/settings.json` for Claude Code; `.cursor/settings.json` and others pluggable). This two-step design allows previewing (`generate-permissions.sh | less`), piping to tests, and supporting future agent hosts without rewriting the generator.

## Scope Boundaries

### In Scope

- Content-hash fields on knowledge entry frontmatter + dispatch output metadata
- Hash-based change detection for knowledge rebuild and dispatch result recording
- Cost source enum (estimated/reported/unknown) in execution-log.jsonl schema
- Null vs zero cost distinction in telemetry recording and aggregation
- Pure transform extraction from build-context.sh and compress-payload.sh into lib/ functions
- Agent instruction schema template with required/optional sections
- Instruction schema conformance check in run-doctor.sh
- Gate verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW) for hook responses
- Provider abstraction convention (documented interface for execution providers)
- Provider conformance check in run-doctor.sh
- **Autonomy configuration schema** (`autonomy.mode`, `generate_on_init`, `deny_patterns`, `extra_allow` in `orchestrator-config.yml` with four-layer resolution)
- **Project-introspected permission generation** (`generate-permissions.sh` reading package.json / Makefile / toolchain markers / agent host dirs)
- **Tier-aware autonomy defaults** (A→minimal, B→standard, C→full) declared in `templates/autonomy-defaults.yaml`
- **Permission pre-flight enhancement in `commands/auto.md`** — regenerate when orchestrator-generated, merge when user-authored, validate completeness
- **Permission drift detection** via `scripts/diagnostics/check-permissions.sh`, wired into the P06 aggregated doctor report
- **Multi-agent-host abstraction** — canonical permissions format + pluggable host writer (Claude Code first, others extensible)
- Conformance test kit expansion (constitution v2.0 compliance checking, recipe validation, event emission verification, permission drift checking)

### Out of Scope

- Actual Conversus integration (M006+)
- Building a Conversus gate hook script (M006+)
- Multi-provider dispatch within a single phase (orchestrator dispatches one task at a time)
- Token-accurate counting (remains chars/4 heuristic; provider-reported tokens improve cost_source accuracy)
- Migrating all existing agent instructions to new schema (progressive, not big-bang)
- **Full Cursor / Copilot permission writers** — P07 ships the canonical format and the Claude Code writer; other hosts are pluggable stubs, not complete implementations (deferred until a user actually needs them)
- **A dedicated `speckit.orchestrator.permissions` command** (design question 4 from the feature prompt) — deferred. P07's generator + auto.md pre-flight + doctor drift check cover the main use cases; a standalone command can be added later if demand emerges.
