---
schema_version: "1.0"
type: milestone-summary
id: "M025"
parent: "021-github-installer-coexistence"
milestone: "M025"
remediates: "M013/P04/T04"
provides:
  - "install-claude-code.sh merges into existing ~/.claude/settings.json via scripts/util/settings-merge.sh (python3 JSON engine, jq-optional, temp-file-then-rename, inline _orchestrator_managed tagging with cascade-cleanup on --uninstall); claude-code.sh runtime adapter --hook-config emits valid CC hooks schema (Stop + PreToolUse/Bash mapping, 4 TODO(M025+) deferrals); tests/fixtures/m025-p01/ pinned fixture tree; 10-gate P01 phase-suite (hook-schema + merge-preservation + coexistence + idempotency + uninstall-reversibility + runtime-scope-guard + bash32-compat + docs + knowledge-entries + recent-changes); references/installation.md Uninstall section + references/hooks.md Claude Code Event Mapping table; CHANGELOG.md [0.9.1] entry; knowledge/lessons/MEM026.md (M013/P04/T04 regression lesson) + knowledge/patterns/MEM027.md (merge-not-overwrite user-scope config pattern)"
requires:
  - "M013/P04/T04 commit d33b8a7 as read-only regression context; M014/P01 scripts/util/dual-write-runtime-md.sh; M012 scripts/knowledge/rebuild-index.sh + wiki include-markdown projection; M013/P04 FR-12-v1-negative-grep-guard pattern; M008/P05 runtime adapter --probe/--register/--hook-config interface; Constitution VII (Knowledge Compounds), XIV (No Speculative Complexity), XV (Surgical Precision); MEM001 Bash 3.2 compatibility; python3 as de-facto gate baseline (precedent: m013-p04-* gates)"
affects:
  - "M010 (Codex/Cursor parity post-launch — coexistence pattern inherits here if those runtimes gain user-scope config paths); M009 (launch-readiness audit — RUNTIME-ASSUMPTIONS.md gains 'orchestrator owns only its own hook entries under _orchestrator_managed tag' entry); M019 Tier 2+3 (no new emitters — Tier 1 shape preserved); future orchestrator users (safe to install on top of pre-existing ~/.claude/settings.json authored by GSD or other sibling tools — coexistence is now a first-class invariant); operator workflow (--uninstall path documented in references/installation.md)"
key_files:
  - "scripts/dispatch/adapters/runtime/claude-code.sh; packaging/install/install-claude-code.sh; scripts/util/settings-merge.sh; tests/fixtures/m025-p01/gsd-baseline/settings.json; tests/fixtures/m025-p01/expected-post-install.json; tests/fixtures/m025-p01/expected-post-uninstall.sha256; scripts/verify/m025-p01-phase-suite.sh (orchestrator); scripts/verify/m025-p01-{hook-schema,merge-preservation,coexistence,idempotency,uninstall-reversibility,runtime-scope-guard,bash32-compat,docs,knowledge-entries,recent-changes}.sh; references/installation.md; references/hooks.md; CHANGELOG.md; knowledge/lessons/MEM026.md; knowledge/patterns/MEM027.md"
key_decisions:
  - "Tier B (user-directed override; confirmed by metrics — 4 US / 11 AS / 10 FR / 1 SDD flow); single-phase milestone (P01). #Q-1 event-mapping policy locked at plan-phase: post_verify -> Stop; before_commit -> PreToolUse + Bash matcher; 4 deferred (before_tasks, after_tasks, before_implement, after_implement) with TODO(M025+) markers. #Q-2 tagging shape locked: inline _orchestrator_managed: true (not sidecar manifest) — self-contained uninstall; CC lenient about unknown keys. FR-9 runtime-scope: Claude Code only; codex + cursor installers + adapters byte-identical (pinned-sha + negative-grep gate). python3-for-awk-fallback deviation from CON-2 spec prose — documented in MEM027 as the pattern's canonical shape. FR-8 byte-identity nuance (canonicalization vs raw baseline): round-trip reversibility gate dual-asserts pinned-sha + structural-equivalence to preserve intent. New-file write path canonicalizes through the same serializer as the merge path so idempotency holds on first+second install."
patterns_established:
  - "inline-managed-tag-on-user-scope-config (MEM027); python3-as-bash32-json-subprocess (env-var param passing + heredoc; jq-fallback convention generalized from m013-p04-* gates); canonicalize-at-write-for-idempotency (route new-file writes through the same serializer as merge-writes so run-1 output byte-equals run-2 output); cascade-cleanup-on-uninstall (leaves -> wrappers -> event keys -> hooks key); pinned-sha-plus-structural-baseline-dual-assert (round-trip reversibility gate pins canonical post-uninstall bytes AND asserts structural equivalence to pre-install baseline); runtime-scope-negative-grep-plus-pinned-sha (FR-9 enforcement combining pinned-sha on sibling-runtime files with negative-grep for milestone markers); comment-line-exclusion-in-forbidden-token-scanner (bash32-compat scanner strips ^[[:space:]]*# lines before grepping so header comments naming forbidden tokens do not trigger); regression-lesson-with-cross-milestone-pointer (MEM026 cross-references commit d33b8a7 and names the original P04 gate suite's missing coverage)"
drill_down_paths:
  - ".orchestrator/milestones/M025/phases/P01/P01-SUMMARY.md"
duration: "single-session"
verification_result: "pass"
completed_at: "2026-04-23"
observability_surfaces:
  - "no new JSONL emitters; CHANGELOG [0.9.1] entry + KNOWLEDGE-INDEX MEM026 (lesson) + MEM027 (pattern) + M012 wiki projections"
---

# M025 — GitHub installer coexistence remediation

M025 is a targeted one-phase remediation of the regression introduced in `M013/P04/T04` (commit `d33b8a7`), where `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` emitted a schema-invalid JSON blob and `packaging/install/install-claude-code.sh` wrote it verbatim over any pre-existing `~/.claude/settings.json` — clobbering GSD hooks or any sibling-tool configuration. M025 delivers three remediation surfaces and a knowledge-layer cross-reference so M013's consolidated summary gains a pointer to where its gate coverage was insufficient.

Tier B (user-directed override; confirmed by metrics). Single phase P01, 4 linear tasks, 1 SDD flow. Commits: `17a2592` (scaffold) → `4bea909` (T01) → `fe2a4d8` (T02) → `f2a9585` (T03) → `1824b28` (T04). Phase-suite: `pass=10 fail=0`.

## What was built

- **Valid Claude Code hooks schema** — `claude-code.sh --hook-config` emits a real CC `hooks` object with only mapped events (`Stop` for `post_verify`, `PreToolUse` + matcher `Bash` for `before_commit`). Four orchestrator lifecycle events without CC equivalents (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`) are explicit deferrals with `TODO(M025+)` markers. Every inserted hook leaf carries `_orchestrator_managed: true`.
- **Merge-not-overwrite installer** — `install-claude-code.sh` calls `scripts/util/settings-merge.sh merge` instead of overwriting. The merge helper (333 lines, python3 JSON engine, jq-optional) deep-merges per-event arrays while preserving every non-orchestrator top-level key structurally-identically. Malformed pre-existing JSON → exit 4 (no write). Temp-file-then-rename throughout. `--force` bypasses the idempotency guard.
- **Reversible uninstall** — `install-claude-code.sh --uninstall` short-circuits probe/register/config-stage and dispatches to `settings-merge.sh uninstall`, which strips only entries tagged `_orchestrator_managed: true` and cascades the cleanup (empty wrappers → drop; empty event arrays → drop keys; empty `hooks` → drop). Round-trip pinned via `tests/fixtures/m025-p01/expected-post-uninstall.sha256`.
- **Coexistence fixture** — `tests/fixtures/m025-p01/gsd-baseline/settings.json` is a representative GSD-shaped seed. `expected-post-install.json` is captured from a real merge run (not hand-authored — canonicalization defeats manual capture). 10-gate phase-suite proves coexistence + idempotency + reversibility + FR-9 runtime-scope (pinned-sha on `install-codex.sh`, `install-cursor.sh`, `codex.sh`, `cursor.sh`).
- **Knowledge-layer regression entry** — `knowledge/lessons/MEM026.md` cross-references commit `d33b8a7` and documents why M013/P04's gate suite missed the regression (no pre-existing-settings path exercised). `knowledge/patterns/MEM027.md` codifies the merge-not-overwrite pattern with the inline-tag + jq-optional + cascade-cleanup shape.

## Phase shape

- **P01 — Installer coexistence: hook-config schema + merge-not-overwrite + reversibility** (4 tasks). T01 schema fix + event mapping → T02 merge-not-overwrite installer + `--uninstall` flag → T03 fixture tree + 7 new gates + phase-suite orchestrator → T04 docs + knowledge entries + dual-write. Linear chain. Phase-suite closes `pass=10 fail=0`.

## Key decisions

- **Numbering** — M025 rather than M013.1 or M013/P05. Orchestrator has no decimal-milestone precedent; reopening a closed milestone (M013 sealed via `461osf` / `M013-VALIDATED` sentinel) would break the sealed-milestone invariant. M025 is the next free integer past the M009/M010/M018/M020/M023/M024 committed forward-roadmap set.
- **Tier B** — User-directed override confirmed by metrics (4 US / 11 AS / 10 FR / 1 SDD flow / bounded scope / no cross-phase coordination). Auto mode deemed overkill; Tier B manual per-phase dispatch kept the human in the loop on `#Q-1` and `#Q-2`.
- **#Q-1 event-mapping policy** (locked at plan-phase) — `post_verify` → `Stop`; `before_commit` → `PreToolUse` + matcher `Bash`; four orchestrator events deferred with `TODO(M025+)` markers. Candidate revisit if Claude Code gains task-start / task-end / implement-start / implement-end events.
- **#Q-2 tagging shape** (locked at plan-phase) — inline `_orchestrator_managed: true` on each orchestrator-inserted hook leaf. No sidecar manifest. Rationale: self-contained uninstall; CC lenient about unknown keys; sidecar drift the larger pragmatic risk.
- **python3-for-awk-fallback** (CON-2 deviation) — documented in MEM027 as the pattern's canonical shape. Awk-based JSON deep-merge for bash 3.2 would dwarf the rest of T02; python3 is already a de-facto baseline in `scripts/verify/m013-p04-*.sh` gates.
- **FR-8 byte-identity nuance** — round-trip reversibility gate dual-asserts pinned-sha on canonical post-uninstall bytes AND structural equivalence to pre-install baseline. Canonicalization via `python3 json.dumps(indent=2, sort_keys=True)` makes pre-vs-post byte-identity impossible without normalizing the input too; gate preserves FR-8 intent ("uninstalling restores the file") under that constraint.
- **FR-9 runtime-scope** — Claude Code only. `install-codex.sh`, `install-cursor.sh`, `scripts/dispatch/adapters/runtime/codex.sh`, `scripts/dispatch/adapters/runtime/cursor.sh` byte-identical per pinned-sha + negative-grep for `M025`/`_orchestrator_managed`/`settings-merge` tokens. Pattern lifted from M013/P04 FR-12-v1-negative-grep-guard.

## Patterns established

See `patterns_established` in frontmatter. The two new MEM entries (MEM026 lesson + MEM027 pattern) will compound into future user-scope-config-write phases: M010 Codex/Cursor parity (if those runtimes gain user-scope paths), M019 Tier 2+3 observability (if tier-2 JSONL ever writes under `$HOME`), any future runtime-agnostic hook registration work.

## Observability surfaces

No new JSONL emitters. M019 Tier 1 shape unchanged. Surfaces added: `CHANGELOG.md [0.9.1]` entry, `KNOWLEDGE-INDEX.md` MEM026 + MEM027 rows, `wiki/docs/knowledge/` projections.

## Closeout

Phase-suite green (`pass=10 fail=0`). Four feat commits + one scaffolding commit. Forward roadmap advances to M014 (spec management extended).
