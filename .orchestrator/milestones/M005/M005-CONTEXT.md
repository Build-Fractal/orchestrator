---
schema_version: "1.0"
type: context-draft
milestone: "M005"
status: finalized
created_at: "2026-04-10T23:00:00Z"
finalized_at: "2026-04-10T23:45:00Z"
updated_at: "2026-04-10T23:55:00Z"
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

### AD-10: No GSD runtime support beyond the M003 migration tool

The orchestrator supports GSD only through the one-way M003 migration tool (which helps users move **from** GSD **to** orchestrator). The autonomy permission generator does NOT emit `Skill(gsd:*)` allow patterns, does NOT detect `.gsd/` directories as an introspection source, and does NOT include GSD-specific bash patterns. P07's generator output is GSD-free.

The MVP template at `templates/claude-settings.json`, the orchestrator's own `.claude/settings.json`, and the `commands/auto.md` documentation all previously included a blanket `Skill(gsd:*)` entry; these were cleaned up alongside the finalization of this decision so the repository is consistent with AD-10. The M003 migration tool references (`scripts/migrate/adapters/gsd1.sh`, `gsd2.sh`, `commands/migrate.md`, the `extension.yml` migration command description, and historical `.gsd/` mentions in research/handoff docs) are explicitly out of scope for this cleanup — they describe the one-way migration path, not runtime support.

### AD-11: Generator always runs with graceful per-source fallback

`generate-permissions.sh` always attempts introspection rather than checking for a "minimal environment" precondition. Each introspection source (package.json, Makefile, extension.yml, toolchain markers, agent host dirs) is independently wrapped — if a source is missing or unreadable, that source contributes nothing and the generator continues with the remaining sources. The static `templates/claude-settings.json` is the nuclear fallback only when bash itself cannot execute (which cannot happen in practice, since the orchestrator requires bash). There is no "minimal environment" mode.

### AD-12: Drift severity is binary (ok / drift / missing)

`scripts/diagnostics/check-permissions.sh` emits exactly one of three statuses:
- `ok` — zero missing allow patterns, zero stale allow patterns, and current deny list matches the `templates/autonomy-defaults.yaml` baseline exactly
- `drift` — at least one missing or stale pattern (indicates regeneration needed)
- `missing` — `.claude/settings.json` does not exist at all

No intermediate "warning" tier. Drift is binary — you're either current or you need to regenerate. This keeps the doctor signal unambiguous for the auto mode pre-flight step (FR-6) and avoids "minor drift" ambiguity that would force the developer to interpret gray-zone states.

### AD-13: Merge semantics for user-authored settings are additive only, never subtractive

When `.claude/settings.json` exists without the `_generated_by` marker (user-authored), the pre-flight merge is strictly additive:
- `permissions.allow`: union with orchestrator-generated patterns, deduplicate. Never removes user entries.
- `permissions.deny`: add missing baseline deny patterns from `autonomy-defaults.yaml` if absent, but never remove user entries. If the user intentionally removed a baseline deny, the merge respects that removal but the drift check reports it as a baseline-deny gap (informational, not blocking).
- `defaultMode`: leave user's value untouched. Never overwrite.
- `_generated_by` / `_generated_at` / `_autonomy_mode`: not added to user-authored files (preserves the user-authored status marker — adding the marker would convert it into an orchestrator-generated file on the next pre-flight, which would overwrite it).

User autonomy wins over orchestrator opinion. The orchestrator warns on drift but does not enforce.

### AD-14: YAML policy files reuse recipe-parser.sh from M004 P04

`templates/autonomy-defaults.yaml` conforms to the same YAML schema constraints as `templates/context-recipe.yaml` (max 2 levels of nesting, comma-separated inline arrays, parseable without jq — per M004 NFR-202). P07 reuses `scripts/lib/recipe-parser.sh` (produced by M004 P04, already committed) rather than writing a narrower parser. This maintains Single Source of Truth (Principle XI) for YAML parsing mechanics.

Consequence: P07 gains a dependency on M004 P04 in addition to M004 P02. P07 still has no M005-internal dependencies — it remains parallel to M005 P01-P04 — but it cannot start until M004 P02 AND M004 P04 are both committed.

### AD-15: Permission tests use synthetic fixtures with snapshot assertions

Permission generator tests use synthetic minimal project directories under `tests/fixtures/permissions/{nodejs,rust,python,go,polyglot}/` — each fixture contains just enough files to trigger specific introspection sources (e.g., `nodejs/` has a `package.json` with 3 script keys and nothing else). Tests assert against expected-output JSON snapshots in `tests/fixtures/permissions/expected/`. The generator is NOT tested against the orchestrator repo itself (too variable — the repo changes, tests should be stable).

### AD-16: Canonical permissions format v1 is Claude-Code-shaped + metadata

The canonical permissions format emitted by `generate-permissions.sh` is:

```json
{
  "_generated_by": "speckit-orchestrator",
  "_generated_at": "<ISO-8601>",
  "_autonomy_mode": "<minimal|standard|full>",
  "permissions": {
    "defaultMode": "<default|acceptEdits>",
    "allow": ["..."],
    "deny": ["..."]
  }
}
```

This is Claude Code's native shape plus the provenance markers. Writing to Claude Code is effectively a pass-through. Writing to other hosts requires per-host translators.

A richer schema with capability categories (reads/writes/network/shell) that translators map to host-specific primitives is explicitly deferred as YAGNI until a second host actually needs it. First host ships, second host motivates the abstraction.

### AD-17: .local autonomy overrides use key-by-key deep merge (pending P07 verification)

`orchestrator-config.local.yml` overrides of the `autonomy` block merge key-by-key into the project-level `autonomy` block (e.g., setting only `extra_allow` in `.local` leaves `mode`, `generate_on_init`, and `deny_patterns` at their project-level values). This should match the existing four-layer config resolution behavior for other config sections. **P07 planning must verify this matches current semantics before implementation** — if current config resolution uses replace-instead-of-merge for other sections, this AD gets revised to match whatever the existing behavior is. Consistency with existing semantics is more important than the specific choice.

### AD-18: `_generated_at` is informational metadata, not a drift signal

The `_generated_at` ISO-8601 timestamp in generated permission files is metadata only. The drift detector compares content between current and regenerated output; it does NOT treat a stale timestamp as a drift signal on its own. A project with zero changes can have a months-old `_generated_at` and still report `ok`. This avoids false-positive regeneration noise for stable projects.

### AD-19: Harness safety heuristics sit above the allow list — task plan verification uses script-file shape

Claude Code's bash permission system has two independent layers:

1. **The permission layer** — `.claude/settings.json` `defaultMode` plus allow/deny pattern matching. This is what P07's generator targets.
2. **The safety heuristic layer** — built-in checks in the harness that detect obfuscation-shaped commands and force a user prompt *regardless* of the allow list. This layer cannot be disabled from `settings.json`, is invisible to the orchestrator, and fires on command shape rather than command content. It exists precisely because pattern-matching allow lists can be defeated by obfuscation, so the harness has a second gate that does not trust patterns alone.

**Observed trigger classes** (enumerated from M004/P02/T01 and M004/P05 task verification; the list is expected to grow as the harness evolves, so treat it as indicative, not exhaustive):

- `brace expansion containing quote characters` — e.g. `grep -q 'done\[[:space:]]*\\\''`
- `simple_expansion` — complex `$variable` expansion inside compound blocks
- `expansion obfuscation` — any `bash -c '...'` with embedded quoted regex or character classes
- `Contains subshell` — a plain `( ... )` group, **even without `&&`/`||`**; e.g. `( . lib.sh && fn arg )` or `( ! grep … ) && echo`
- `'.' evaluates arguments as shell code` — the `.` / `source` builtin with arguments, especially in a subshell
- `Contains process_substitution` — `<(...)` or `>(...)` used anywhere in the command
- `zsh ~[ dynamic directory syntax` (false positive) — fires on `cmd <file` input redirection nested inside `$(...)`, e.g. `lines=$(wc -l < path/to/file)`
- `shell operators require approval for safety` — any `&&`/`||` outside a trivial two-token pair
- Command substitution `$(...)` **containing pipes** — e.g. `rc=$(bash … | grep -c '^RESULT:')`
- Compound `;`-separated statements chaining more than two commands — e.g. `cmd1; rc=$?; echo; cat file`
- Inline `for`/`while`/`if` blocks embedded in a single command — e.g. `for fn in a b c; do grep -q "$fn" file && echo PASS; done`
- Heredocs (`<<EOF` / `<<'YAML'`) feeding commands with further pipes/redirects
- `Unhandled node type: string` — a separate parser failure (not a heuristic), triggered by nested heredocs in git commit commands; same remedy applies

**Consequence:** inline compound verification blocks — even when every component would individually match an allow pattern — trip one or more of these heuristics and interrupt unattended Tier C execution. This was observed repeatedly during M004/P02/T01 and across every task of M004/P05. P07's allow-list generator cannot eliminate this class of prompt; the remedy is upstream, in how task plan `Check:` commands and inline verification blocks are authored.

**Remedy (P07 scope — preventive):**
- `commands/plan-phase.md` Truths guidance explicitly forbids inline compound `Check:` commands and directs authors to use single-script invocations (e.g., `bash scripts/verify/P##-T##-verify.sh`) for any multi-step verification. Guidance enumerates every trigger class above so downstream planners can recognize the full shape family, not just `&&`-chained `bash -c`.
- `templates/phase-plan.md` and `templates/task-plan.md` examples exclusively show the script-file shape — no `&&`-chained `bash -c` blocks, no heredoc-embedded quoted regex, no `( . lib.sh && fn )` subshells, no `rc=$(bash … | grep -c …)` patterns, no `<(process_sub)`.
- `commands/auto.md` Permission Pre-Flight gains a "Known Limitations: Harness Safety Heuristics" subsection naming this residual prompt class, documenting the remedy (script-file verification shape), enumerating the observed trigger classes, and explicitly acknowledging that P07's generator does not and cannot eliminate it from the allow list.
- Bundled helper `scripts/verify/task-verify.sh <phase-dir> <task-id>` (optional, P07 may produce it) encapsulates the common "run a command, grep its output, emit PASS/FAIL" idiom as a single-script invocation that task plans can call uniformly — eliminating the temptation to inline compound pipelines.

**Remedy (P06 scope — detective):**
- `scripts/diagnostics/check-plans.sh` (new diagnostic, registered via run-doctor.sh) scans existing task plan `Check:` commands AND task plan inline verification blocks (recognized by ```` ```bash ```` fences) and flags any of the trigger shapes above. Specifically: `bash -c '` with embedded quoted character classes or escape sequences; `&&`/`||` chained compound bash invocations beyond a trivial two-token pair; heredocs containing bash expansion; **plain `(…)` subshells containing `.`/`source` or pipes**; **command substitution `$(…)` containing pipes**; **process substitution `<(…)` / `>(…)`**; **`cmd <file` input redirection nested inside `$(…)`**; **compound `;`-separated statements with more than two commands**; **inline `for`/`while`/`if` blocks**. Emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`. **Advisory, not blocking** — the developer can proceed, but the doctor surfaces the likelihood of prompt interruption during auto mode so it can be fixed before a long unattended run.

Safety and unattendedness come from writing commands the harness recognizes as benign, not from trying to defeat the harness.

### AD-20: Baseline allow list includes system temp directories

Orchestrator scripts read from and write to platform temp directories for dry-run output capture, parity fixtures, recipe-expansion tests, and compression golden-file generation (observed in M004/P02–P05 verification). `templates/autonomy-defaults.yaml` baseline allow list therefore includes (Principle X: Templating Over Inference):

- `Bash(* > /tmp/*)`, `Bash(* >> /tmp/*)`, `Bash(cat /tmp/*)`, `Bash(cat > /tmp/*)`, `Bash(rm -f /tmp/*)`, `Bash(rm -rf /tmp/*)`, `Bash(ls /tmp/*)`, `Bash(find /tmp/*)`
- macOS equivalents: `Bash(* > /var/folders/*)`, `Bash(ls /var/folders/*)`, `Bash(find /var/folders/*)`, plus `Read(//var/folders/**)`
- `Read(//tmp/**)` and `Read(//private/tmp/**)` (macOS resolves `/tmp` → `/private/tmp`)

The deny list continues to forbid temp-path patterns that are actually dangerous — none exist today because `/tmp` is by convention ephemeral. Should a deny pattern emerge (e.g., a named socket or device-like path under `/tmp`), it lives in `autonomy-defaults.yaml` `deny` and `generate-permissions.sh` emits it unchanged.

This is narrower than it sounds: these patterns are only baseline *defaults*. Projects that do not touch temp can override via `.local` to remove them; projects on non-Unix hosts (hypothetical) override via the agent host translator.

### AD-21: Baseline allow list includes env-prefixed script invocations

Orchestrator scripts are routinely invoked with test/config environment variables on the same command line — `ORCH_RUN_SEED=p03-dry ORCH_DRY_RUN=1 bash scripts/engine/run.sh …`, `ORCH_RUN_SEED=test-seed bash scripts/dispatch/build-context.sh …`, etc. This is explicit, deterministic, and directly observable; hiding it behind a wrapper script would harm debugging, so the baseline allow list accepts it.

`templates/autonomy-defaults.yaml` baseline includes:

- `Bash(ORCH_*=* bash scripts/*)`
- `Bash(ORCH_*=* ORCH_*=* bash scripts/*)` (two-variable form — most common orchestrator pattern)
- `Bash(ORCH_*=* bash .specify/*)`
- `Bash(ORCH_*=* ORCH_*=* bash .specify/*)`

Note: Claude Code's pattern matcher treats the env-assignment prefix as part of the command pattern, so prefix-match against `ORCH_*=*` is load-bearing. The baseline intentionally scopes these patterns to `ORCH_*` rather than `*=*` — unconstrained env-prefix matching would weaken the allow list.

`generate-permissions.sh` extends this with project-specific env-prefix patterns discovered from introspection (e.g., `NODE_ENV=* npm run *` when a `package.json` script uses NODE_ENV; `CI=* …` when a CI config references env prefixes), but the `ORCH_*` patterns above are invariant orchestrator baseline and always emitted regardless of project state.

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
- **Task plan verification command shape guidance** — `commands/plan-phase.md`, `templates/phase-plan.md`, and `templates/task-plan.md` updated to forbid inline compound `bash -c '...' && bash -c '...'` `Check:` commands and require single-script-file shape; guidance enumerates the full observed trigger list from AD-19 (plain subshells, source-in-subshell, command-substitution-with-pipes, process substitution, input-redirect false positives, compound `;`, inline `for`/`while`); `commands/auto.md` Permission Pre-Flight documents the residual harness-heuristic prompt class (per AD-19)
- **Advisory task plan lint** via `scripts/diagnostics/check-plans.sh`, flagging the full AD-19 trigger set (not just `bash -c`+`&&`), wired into the P06 aggregated doctor report
- **System-temp-directory baseline** in `templates/autonomy-defaults.yaml` — `/tmp/**` and macOS `/var/folders/**` read/write allow patterns plus `Read(//tmp/**)`, `Read(//private/tmp/**)`, `Read(//var/folders/**)` (per AD-20)
- **Env-prefixed script-invocation baseline** in `templates/autonomy-defaults.yaml` — `ORCH_*=* bash scripts/*`, two-variable form, and `.specify/*` equivalents (per AD-21)
- Conformance test kit expansion (constitution v2.0 compliance checking, recipe validation, event emission verification, permission drift checking, task plan shape checking)

### Out of Scope

- Actual Conversus integration (M006+)
- Building a Conversus gate hook script (M006+)
- Multi-provider dispatch within a single phase (orchestrator dispatches one task at a time)
- Token-accurate counting (remains chars/4 heuristic; provider-reported tokens improve cost_source accuracy)
- Migrating all existing agent instructions to new schema (progressive, not big-bang)
- **Full Cursor / Copilot permission writers** — P07 ships the canonical format and the Claude Code writer; other hosts are pluggable stubs, not complete implementations (deferred until a user actually needs them)
- **A dedicated `speckit.orchestrator.permissions` command** (design question 4 from the feature prompt) — deferred. P07's generator + auto.md pre-flight + doctor drift check cover the main use cases; a standalone command can be added later if demand emerges.
- **GSD runtime support** — the orchestrator supports GSD only through the existing M003 migration tool (GSD → orchestrator, one-way). P07's generator does not detect GSD, does not emit `Skill(gsd:*)` or GSD-specific bash patterns. The MVP template, `.claude/settings.json`, and `commands/auto.md` have been cleaned up to match this boundary. (Per AD-10.)
- **Richer canonical permissions schema with capability categories** (reads/writes/network/shell) — YAGNI. The canonical format v1 is Claude-Code-shaped + metadata markers. A capability-category abstraction is deferred until a second agent host with genuinely different primitives motivates it. (Per AD-16.)
- **"Minimal environment" detection mode** — the generator always runs with graceful per-source fallback. There is no separate code path that skips introspection based on environment detection. (Per AD-11.)
