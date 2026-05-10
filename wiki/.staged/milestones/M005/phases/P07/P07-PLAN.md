---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M005"
goal: "Introspect project state and emit a canonical autonomy permissions object — making Tier C auto mode genuinely unattended without ever resorting to bypassPermissions."
demo_sentence: "A developer runs bash scripts/lifecycle/generate-permissions.sh on a Node.js project with a Makefile and the script emits a canonical JSON permissions object to stdout that includes every script from extension.yml, every package.json script key, every Makefile target, the comprehensive deny list, and a tier-appropriate defaultMode — running twice with unchanged project state produces byte-identical output, and bash scripts/diagnostics/check-permissions.sh reports DOCTOR:PERMISSIONS status=ok gaps=0 stale=0."
risk: "medium"
depends_on: []
---

<!--
  P07 — Autonomy Permission Generator
  ====================================

  Context: closes the gap between the M001 autonomy promise and the developer
  experience of babysitting every bash command in Tier C auto mode. The
  remediation path has two independent layers per AD-19:

    1. The permission layer (.claude/settings.json allow/deny patterns).
       P07 generates this from project introspection rather than hand-authoring.

    2. The harness safety heuristic layer (obfuscation-shaped command detection
       built into the host, invisible to the allow list). P07 cannot disable
       this. Instead, P07 updates task-plan authoring conventions so downstream
       verification commands are single-script-file invocations that the
       harness recognizes as benign.

  Cross-milestone dependencies (not listed in depends_on because they are
  outside M005):
    - [M004](../../../../milestones/M004/index.md) P02 delivered scripts/lib/errors.sh (emit_result) and
      scripts/lib/events.sh (emit_event). P07 scripts source both.
    - M004 P04 delivered scripts/lib/recipe-parser.sh (YAML reader). Per AD-14,
      P07 reuses this parser for templates/autonomy-defaults.yaml rather than
      writing a narrower one.

  Both are already committed on main (see recent git log: feat(M004/P02):
  rescue-commit shared libraries). No runtime check is required inside tasks.

  Architectural decisions that constrain this phase:
    AD-7  Introspection-generated permissions, never bypassPermissions
    AD-8  Policy lives in templates/, mechanics live in scripts/
    AD-9  Generator is read-only; separate writer handles host translation
    AD-10 No GSD runtime support beyond the [M003](../../../../milestones/M003/index.md) migration tool
    AD-11 Generator always runs with graceful per-source fallback
    AD-12 Drift severity is binary (ok / drift / missing)
    AD-13 Merge semantics for user-authored settings are additive only
    AD-14 YAML policy files reuse recipe-parser.sh from M004 P04
    AD-15 Permission tests use synthetic fixtures with snapshot assertions
    AD-16 Canonical permissions format v1 is Claude-Code-shaped + metadata
    AD-17 .local autonomy overrides use key-by-key deep merge (T01 verifies)
    AD-18 _generated_at is informational metadata, not a drift signal
    AD-19 Harness safety heuristics sit above the allow list
    AD-20 Baseline allow list includes system temp directories
    AD-21 Baseline allow list includes env-prefixed script invocations

  Full text: .specify/orchestrator/milestones/M005/M005-CONTEXT.md
-->

## Must-Haves

### Truths

- Generator reads autonomy-defaults.yaml via the shared YAML parser (no jq, no private parser).
  - Check: `grep -q "recipe-parser.sh" scripts/lifecycle/generate-permissions.sh`
- Generator emits the canonical permissions envelope with provenance markers.
  - Check: `grep -q "_generated_by" scripts/lifecycle/generate-permissions.sh`
- Generator output includes allow/deny under a permissions block (AD-16 shape).
  - Check: `grep -q "permissions" scripts/lifecycle/generate-permissions.sh`
- Generator does NOT emit `Skill(gsd:*)` or GSD-specific bash patterns (AD-10).
  - Check: `bash scripts/verify/p07-no-gsd.sh`
- Generator does NOT emit `bypassPermissions` as a default mode (AD-7).
  - Check: `bash scripts/verify/p07-no-bypass.sh`
- Generator is resilient: individual introspection sources can be missing without aborting (AD-11).
  - Check: `grep -q "per.source.fallback\|per_source_fallback\|continue.*missing\|if .*-f\|\[ -f" scripts/lifecycle/generate-permissions.sh`
- Writer embeds the `_generated_by` provenance marker when producing settings.json (AD-16).
  - Check: `grep -q "_generated_by" scripts/lifecycle/write-permissions.sh`
- Writer respects user-authored files: merge is additive only, never removes user entries (AD-13).
  - Check: `bash scripts/verify/p07-merge-additive.sh`
- Drift detector emits a structured DOCTOR:PERMISSIONS line with status, gaps, and stale counts.
  - Check: `grep -q "DOCTOR:PERMISSIONS" scripts/diagnostics/check-permissions.sh`
- Drift detector status set is the closed enum `ok|drift|missing` (AD-12).
  - Check: `grep -qE "status=(ok|drift|missing)" scripts/diagnostics/check-permissions.sh`
- Autonomy defaults file declares the tier→mode mapping (Tier A=minimal, B=standard, C=full).
  - Check: `bash scripts/verify/p07-tier-modes.sh`
- Autonomy defaults baseline allow list includes system-temp-directory patterns (AD-20).
  - Check: `grep -q "/tmp/" templates/autonomy-defaults.yaml`
- Autonomy defaults baseline allow list includes macOS `/var/folders/` patterns (AD-20).
  - Check: `grep -q "/var/folders" templates/autonomy-defaults.yaml`
- Autonomy defaults baseline allow list includes `ORCH_*=* bash scripts/*` (AD-21).
  - Check: `grep -qE 'ORCH_\*=\* bash scripts' templates/autonomy-defaults.yaml`
- extension.yml registers `scripts/lifecycle/generate-permissions.sh` under provides.scripts.
  - Check: `grep -q "lifecycle/generate-permissions.sh" extension.yml`
- extension.yml registers `scripts/lifecycle/write-permissions.sh` under provides.scripts.
  - Check: `grep -q "lifecycle/write-permissions.sh" extension.yml`
- extension.yml registers `scripts/diagnostics/check-permissions.sh` under provides.scripts.
  - Check: `grep -q "diagnostics/check-permissions.sh" extension.yml`
- extension.yml config_schema declares an `autonomy` block (FR-1 four-layer resolution).
  - Check: `grep -q "autonomy:" extension.yml`
- orchestrator-config-default.yml surfaces the autonomy configuration keys.
  - Check: `grep -q "autonomy:" templates/orchestrator-config-default.yml`
- orchestrator-config-default.yml documents the four autonomy keys: mode, generate_on_init, deny_patterns, extra_allow.
  - Check: `bash scripts/verify/p07-config-keys.sh`
- commands/auto.md Permission Pre-Flight references the generator (FR-6).
  - Check: `grep -q "generate-permissions" commands/auto.md`
- commands/auto.md Permission Pre-Flight references the drift detector.
  - Check: `grep -q "check-permissions" commands/auto.md`
- commands/auto.md documents the harness-safety-heuristic limitation (AD-19).
  - Check: `grep -q "Known Limitations" commands/auto.md`
- commands/auto.md Known Limitations section names AD-19 explicitly.
  - Check: `grep -q "AD-19" commands/auto.md`
- commands/evaluate.md triggers permission generation on init (FR-7).
  - Check: `grep -q "generate_on_init" commands/evaluate.md`
- commands/plan-phase.md Truths guidance cross-references AD-19.
  - Check: `grep -q "AD-19" commands/plan-phase.md`
- commands/plan-phase.md enumerates the harness-heuristic trigger classes and points at the script-file shape remedy.
  - Check: `grep -q "script.file shape\|script-file shape" commands/plan-phase.md`
- templates/phase-plan.md example Truth `Check:` uses a single-invocation script-file shape (no inline compound bash).
  - Check: `grep -q "bash scripts/" templates/phase-plan.md`
- templates/task-plan.md verification example calls out AD-19 as the source of the shape constraint.
  - Check: `grep -q "AD-19" templates/task-plan.md`
- references/installation.md documents the three autonomy modes.
  - Check: `grep -qE "minimal.*standard.*full|full.*standard.*minimal" references/installation.md`

### Artifacts

- scripts/lifecycle/generate-permissions.sh (min 200 lines, contains "_generated_by")
- scripts/lifecycle/write-permissions.sh (min 90 lines, contains "_generated_by")
- scripts/diagnostics/check-permissions.sh (min 90 lines, contains "DOCTOR:PERMISSIONS")
- templates/autonomy-defaults.yaml (min 60 lines, contains "tier_defaults")
- templates/orchestrator-config-default.yml (min 18 lines, contains "autonomy:")
- extension.yml (min 215 lines, contains "generate-permissions.sh")
- commands/auto.md (min 460 lines, contains "generate-permissions")
- commands/evaluate.md (min 170 lines, contains "generate_on_init")
- commands/plan-phase.md (min 175 lines, contains "AD-19")
- templates/phase-plan.md (min 55 lines, contains "bash scripts/")
- templates/task-plan.md (min 45 lines, contains "AD-19")
- references/installation.md (min 165 lines, contains "autonomy")
- scripts/verify/p07-no-gsd.sh (min 10 lines, contains "Skill(gsd")
- scripts/verify/p07-no-bypass.sh (min 10 lines, contains "bypassPermissions")
- scripts/verify/p07-merge-additive.sh (min 15 lines, contains "additive")
- scripts/verify/p07-tier-modes.sh (min 15 lines, contains "minimal")
- scripts/verify/p07-config-keys.sh (min 10 lines, contains "generate_on_init")

### Key Links

- commands/auto.md → scripts/lifecycle/generate-permissions.sh
- commands/auto.md → scripts/lifecycle/write-permissions.sh
- commands/auto.md → scripts/diagnostics/check-permissions.sh
- scripts/lifecycle/generate-permissions.sh → templates/autonomy-defaults.yaml
- scripts/lifecycle/generate-permissions.sh → scripts/lib/recipe-parser.sh
- scripts/lifecycle/generate-permissions.sh → scripts/lib/errors.sh
- scripts/lifecycle/write-permissions.sh → scripts/lifecycle/generate-permissions.sh
- scripts/diagnostics/check-permissions.sh → scripts/lifecycle/generate-permissions.sh
- commands/evaluate.md → scripts/lifecycle/generate-permissions.sh
- commands/plan-phase.md → templates/phase-plan.md

## Tasks

### T01: Autonomy defaults + config schema (declarative policy)

Creates `templates/autonomy-defaults.yaml` as the single source of truth for tier→mode mapping, baseline deny list, baseline allow list (including AD-20 temp-dir and AD-21 env-prefix patterns), and introspection rules. Adds the `autonomy:` block to `templates/orchestrator-config-default.yml` with four keys (mode, generate_on_init, deny_patterns, extra_allow). Adds the `autonomy` config_schema block to `extension.yml` and registers the three new scripts (generate-permissions.sh, write-permissions.sh, check-permissions.sh) under `provides.scripts`. This task is pure data + manifest changes — no runtime behavior yet. Zero upstream dependencies.

Full plan: `tasks/T01-PLAN.md`

### T02: Project introspector — generate-permissions.sh

Implements `scripts/lifecycle/generate-permissions.sh` as a pure read-only function from project state → canonical JSON permissions on stdout. Sources `scripts/lib/errors.sh` (emit_result), `scripts/lib/events.sh` (emit_event), `scripts/lib/recipe-parser.sh` (read autonomy-defaults.yaml per AD-14), and `scripts/dispatch/detect-capabilities.sh` (agent host markers). Introspects: extension.yml provides.scripts, package.json script keys, Makefile targets, toolchain config markers (tsconfig/Cargo.toml/go.mod/pyproject.toml/Gemfile), agent host directories (.claude/, .cursor/, .github/copilot/ — NOT .gsd/ per AD-10). Graceful per-source fallback (AD-11). Emits the AD-16 canonical envelope to stdout with `_generated_by: speckit-orchestrator`, `_generated_at: <ISO-8601>`, `_autonomy_mode: <tier-default>`, and `permissions.{defaultMode,allow,deny}`. Bash 3.2. Deterministic: same project state → byte-identical stdout. Idempotent. Depends on T01 (autonomy-defaults.yaml).

Full plan: `tasks/T02-PLAN.md`

### T03: Agent-host writer + drift detector

Implements `scripts/lifecycle/write-permissions.sh` (canonical JSON on stdin or `--input <file>` → writes `.claude/settings.json` for Claude Code, detects host via `detect-capabilities.sh`) with AD-13 additive merge semantics when the target file is user-authored (lacks `_generated_by` marker) and overwrite-with-preservation semantics when orchestrator-generated. Implements `scripts/diagnostics/check-permissions.sh` which runs `generate-permissions.sh`, diffs the result against the current `.claude/settings.json`, and emits `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N` per AD-12. Depends on T02 (reads the canonical format and re-invokes the generator).

Full plan: `tasks/T03-PLAN.md`

### T04: Command wiring — auto.md pre-flight, evaluate.md init, auto.md known-limitations

Rewrites `commands/auto.md` Permission Pre-Flight subsection per FR-6: the new flow reads `autonomy.generate_on_init` config, detects whether `.claude/settings.json` exists and whether it is orchestrator-generated (via `_generated_by` marker), calls `generate-permissions.sh | write-permissions.sh` for generation, calls `check-permissions.sh` to report drift, and warns (not blocks) on user-authored drift per AD-13. Adds a new "Known Limitations: Harness Safety Heuristics" subsection per AD-19 that names the residual prompt class, points at the script-file verification shape as the remedy, and cross-references AD-19 in M005-CONTEXT.md. Updates `commands/evaluate.md` to trigger permission generation during initial scaffold when `autonomy.generate_on_init` is true and tier default applies (FR-7). Depends on T02 and T03 (scripts must exist to be called).

Full plan: `tasks/T04-PLAN.md`

### T05: Harness-heuristic shape guidance + installation docs

Updates `commands/plan-phase.md` Truths `Check:` guidance per AD-19 to explicitly forbid: inline compound bash blocks; `bash -c '...' && bash -c '...'` chains; plain `(…)` subshells sourcing libraries or containing pipes; command substitution `$(…)` containing pipes; process substitution `<(…)` / `>(…)`; `cmd <file` input redirection inside `$(…)`; compound `;`-separated statements with more than two commands; inline `for`/`while`/`if` blocks. Directs authors to single-script-file invocations (e.g., `bash scripts/verify/P##-T##-verify.sh`) with a short rationale paragraph explaining *why* (the harness safety heuristic layer). Updates `templates/phase-plan.md` Truths example to show the script-file shape exclusively — no `&&`-chained `bash -c` blocks anywhere. Updates `templates/task-plan.md` Verification example to use the script-file shape with a comment naming AD-19 as the source of the constraint. Updates `references/installation.md` to document the three autonomy modes, the four autonomy config keys, how drift detection works, and the harness-heuristic limitation (cross-references AD-19). This task is pure documentation/template — no script changes — and is independent of T02/T03/T04 (it can dispatch in parallel with them). Depends only on T01's config shape being settled so the docs stay consistent.

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (autonomy defaults + config schema)
  │
  ├─→ T02 (generator)
  │     │
  │     └─→ T03 (writer + drift detector)
  │           │
  │           └─→ T04 (command wiring: auto pre-flight + evaluate init + known limitations)
  │
  └─→ T05 (harness-heuristic guidance + installation docs)   [independent of T02-T04]
```

T01 is the critical-path gate — everything else waits on the autonomy defaults schema.
T02 → T03 → T04 is a strict chain (each consumes the previous task's output).
T05 runs in parallel with T02-T04 — it only needs T01's config key names to stay consistent with the docs.

## Files Likely Touched

- scripts/lifecycle/generate-permissions.sh (create)
- scripts/lifecycle/write-permissions.sh (create)
- scripts/diagnostics/check-permissions.sh (create)
- templates/autonomy-defaults.yaml (create)
- templates/orchestrator-config-default.yml (modify)
- extension.yml (modify)
- commands/auto.md (modify)
- commands/evaluate.md (modify)
- commands/plan-phase.md (modify)
- templates/phase-plan.md (modify)
- templates/task-plan.md (modify)
- references/installation.md (modify)
- scripts/verify/p07-no-gsd.sh (create)
- scripts/verify/p07-no-bypass.sh (create)
- scripts/verify/p07-merge-additive.sh (create)
- scripts/verify/p07-tier-modes.sh (create)
- scripts/verify/p07-config-keys.sh (create)
- scripts/dispatch/detect-capabilities.sh (modify — add agent host marker detection)
