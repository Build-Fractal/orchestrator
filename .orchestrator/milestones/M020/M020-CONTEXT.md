---
schema_version: "1.0"
type: context-draft
milestone: "M020"
status: draft
created_at: "2026-04-16T18:00:00Z"
finalized_at: null
---

## Architectural Decisions

### AD-1: Gate-scaffolding-first execution pattern (MEM011)

P01 authors six verify gates (`no-legacy-content.sh`, `no-legacy-resolver-docs.sh`,
`packaging-skills-match-commands.sh`, `principle-count-sync.sh`,
`test-suite-count-sync.sh`, `config-schema-matches-live.sh`) **before** landing
any fixes. The gates are expected to fail against HEAD — that expected-failure
state is the baseline. Subsequent phases land fixes and watch gates transition
FAIL → PASS. The transition is the measurable progress signal, consumable by
`scripts/verify/run-suite.sh`. This follows the MEM011 pattern blue-defender
cited as a load-bearing process pattern in the deliberation cross-review
(blue-defender/cross-reviews/red-auditor.md).

### AD-2: Ordered P02 → P03 to avoid crash-recovery UX break

The blind arbiter's Dispute 3 ruling (RISK-03 convergence at HIGH/CERTAIN)
identified a non-obvious ordering constraint: `commands/auto.md:68,296,518`
must have its `speckit.orchestrator.resume` reference replaced **before**
the `.claude/settings.json` `Skill(speckit.orchestrator.*)` allow entries
are deleted. Reverse order produces an intermediate window where the
printed recovery instructions fail to resolve. P02 ships the auto.md fix;
P03 deletes the allow-list.

### AD-3: Content-layer DECISIONS governance rule (D008)

The deliberation's systemic-observation pattern — mechanical defect +
rhetorical amplification — traces to an under-used DECISIONS.md
discipline. Architectural drifts get D-entries; content-layer drifts
currently do not. P03 appends D008 establishing the rule: any change
that leaves content-layer surfaces (commands, templates, reference docs,
top-level narrative docs) inconsistent with specs requires a
DECISIONS.md entry or a grep-gate that enforces the consistency. P01's
six gates discharge the gap backwards for the M015 cutover; D008
prevents recurrence.

### AD-4: Locked-down zero-prompt re-run in P04

The arbiter's Dispute 5 ruling reclassified RISK-05 (F3, M016 zero-prompt
scope) to MEDIUM and required a bounded summary edit plus an empirical
re-run on a locked-down settings posture. P04 executes the re-run on a
fresh clone with `.claude/settings.json` stripped to a minimal posture
(no `Skill(speckit.*)` entries, `.specify/*` entries removed or
explicitly retained with migration-rationale comments). Evidence lives
at `phases/P04/evidence/zero-prompts-locked.md`. If the re-run surfaces
new prompt sources, they feed a follow-up milestone — they do not
invalidate M016's original attested scope.

### AD-5: Six new gates ship individually, wired via `run-suite.sh`

Each of the six gates is independently runnable, exits with a
file:line diagnostic on failure, and is registered in
`scripts/verify/run-suite.sh` auto-discovery (follows the M016-P02
`<milestone>-<phase>-*.sh` naming where applicable; `principle-count-sync.sh`
and the matching gates are cross-cutting and live at
`scripts/verify/<name>.sh` without a phase suffix, but are still
discovered by the wrapper when invoked without a phase scope). This
matches the M016 pattern already established.

### AD-6: In-scope, rhetorical-overreach half bundled as narrow summary edit

The deliberation surfaced rhetorical overreach in `M016-SUMMARY.md:8`
(zero-prompt phrasing unqualified by the `orchestrator:auto` scope).
The arbiter's binding ruling requires a bounded edit, not an M016
invalidation. P04 performs the edit in-place and records the locked-down
re-run as the empirical bound. No M016 work is reopened; no M016
evidence is deleted or amended.

## Scope Boundaries

### In Scope

- **P01 gates**: `scripts/verify/no-legacy-content.sh`, `no-legacy-resolver-docs.sh`, `packaging-skills-match-commands.sh`, `principle-count-sync.sh`, `test-suite-count-sync.sh`, `config-schema-matches-live.sh`. Plus a shared banned-token fixture file at `scripts/verify/fixtures/legacy-tokens.txt`.
- **P02 runtime fixes**: `packaging/skills/orchestrator-init.md` (new), `packaging/bundle/manifest.yml` (add init entry), `commands/auto.md` (lines 68, 296, 518 — replace `speckit.orchestrator.resume` with the current `orchestrator:resume` identifier).
- **P03 content sweep**: `templates/autonomy-defaults.yaml:90-91` (remove `Skill(speckit.orchestrator.*)` entries), `templates/claude-settings.json` (remove same), `templates/instruction-schema.md` and `templates/claude-code-appendix.md` if they carry similar tokens, `.claude/settings.json:55-56` (delete speckit allow-list entries), `commands/migrate.md:47,83` (rewrite 5-rule → 4-rule resolver description), `.orchestrator/DECISIONS.md` (append D007 retiring FR-013 hash-preservation; append D008 content-layer governance rule).
- **P04 summary reconciliation**: `CLAUDE.md:37,48-54` (update principle count 7 → 15 and enumerate all XV), test-count doc sweep (4 docs referenced in red-auditor/review.md D1), `M016-SUMMARY.md:8` (qualify zero-prompt phrasing), locked-down zero-prompt re-run with evidence at `phases/P04/evidence/`.

### Out of Scope

- **Broadening `anti-pattern-lint.sh` scope beyond fenced code blocks** — arbiter ruled NEW-3 a scope correction, not a standalone risk. Track separately.
- **Broadening the hermetic-only glob beyond `m008-p07-*`** — arbiter ruled NEW-4 a scope correction.
- **New Managed Agents backend work** — M010 scope.
- **Conversus hook integration** — lands in M011/P07 per D005.
- **Rewriting the constitution** — the enumeration update in CLAUDE.md points at the existing constitution file; the constitution itself is not modified.
- **M016 evidence invalidation or amendment** — the original attestation is valid within its measured scope; only the summary phrasing narrows.

## Design Constraints

- **Bash 3.2 compatibility**: all new verify scripts must honor constitution principle VIII. No `declare -A`, `mapfile`, `${var,,}`. Same constraint as M016.
- **Gates must self-exclude their fixtures**: `no-legacy-content.sh` scans templates and commands for banned tokens; its own banned-token fixture file must be excluded from the scan (use `# lint-ignore` marker or an explicit exclude-path list).
- **Ordering — AD-2 is load-bearing**: P02 must fully land (`auto.md` fix published to the repo) before P03 deletes the `settings.json` allow-list. CI on P03's PR must show P02's gates already passing.
- **Minimal M015 re-entry**: M020 does not reopen M015. Legacy migration-adapter paths (`.specify/*` Bash entries, `Skill(speckit.specify.*)` if any) are retained where `M015-SUMMARY.md:32` justifies them. Gates are calibrated to allow those entries with an explicit-rationale comment.
- **No new milestones spawned from P04 re-run failures**: if the locked-down re-run surfaces new prompt sources, they are recorded as evidence and filed as a fresh spec (e.g., `021-*`). They do not retroactively invalidate M016.
- **Pre-M009 deadline**: arbiter's verdict lists four P0 mitigations as launch-blocking. M020 closes those four.

## Open Questions

- **Q1** — Does the `orchestrator:init` skill file ship as a minimal wrapper delegating to `scripts/lifecycle/init-project.sh`, or does it contain the full first-run orchestration logic inline? **Resolution during planning** — mirror the shape of the twelve existing `packaging/skills/orchestrator-*.md` files; whichever pattern those use is the pattern here.
- **Q2** — The `packaging/bundle/manifest.yml:4` version is `0.3.0-dev` while the project is v0.9.0 (RISK-11 in the synthesis). Is the version-bump in scope? **Recommended resolution**: out of scope for M020; file as a separate cleanup. This milestone is focused on content-layer sweep; bundle-version governance is a separate concern.
- **Q3** — When `CLAUDE.md` enumerates all 15 principles, is a one-sentence gloss per principle sufficient, or must the enumeration include full definitions? **Recommended resolution**: one-sentence gloss per principle in the CLAUDE.md body; full definitions already live in `.orchestrator/memory/constitution.md` and the orientation doc should reference that file rather than duplicate it.
- **Q4** — Do we retain `.claude/settings.json` `Bash(bash .specify/*)` entries with a migration-rationale comment, or delete them entirely now that the migration path is explicitly documented as external? **Recommended resolution**: retain with comment citing `M015-SUMMARY.md:32`. Deletion would remove a load-bearing entry for external users mid-migration; the cost of the retained lines is a one-line-comment audit trail.
