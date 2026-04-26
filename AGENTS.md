# >>> orchestrator:recent-changes >>>
- bbt-companion-dogfood-fixes: FU-7 registers `orchestrator-agent` into `~/.claude/agents/` via the claude-code adapter (guardrail prompt — payload authoritative, forbids framework conventions, forbids output-shape rewrites); FU-8 stages `commands/` into project root through all three installers so dispatched agents can read rubrics like `commands/plan-phase.md`; FU-9 captures `check-settings-state.sh` regen/write/merge failure detail to `.orchestrator/diagnostics/settings-regen-<ISO8601>.log` with stderr breadcrumb (was silently dropped). FU-10 (skip lock under CC) deferred behind FU-4 fix in bbt-companion register.
- M014/P03: comment→workflow classifier (regex/heuristic v1 per D023) + spec-amendment human-gated apply path; consumes M012 wiki + M013 GitHub comment surfaces; conversus-triage on ambiguous; FR-19 dry-run + FR-16 observability; phase suite 14 gates green.
- M026/P03: conversus-OSS migration close — preset edition_required:paid refusal on OSS, six-surface doc updates, knowledge graduation (MEM029 pattern + MEM030 convention), DECISIONS D022, CHANGELOG entry. Closes M026.
- 027-conversus-oss-migration: Migrate orchestrator default Conversus integration from paid build to OSS build with paid-escape-hatch preserved (M026).
- M026/P02: conversus-OSS resolver flip — OSS primary, paid escape hatch via CONVERSUS_EDITION; JSONL edition field; dual-edition regression test with visible-skip annotations; gate-verdict-reliability bundle (verdict-text rationale, arbiter preference, OAuth auto-preflight closes OQ-16 false-PASS). See `.orchestrator/milestones/M026/phases/P02/P02-SUMMARY.md`.
- M026/P01: conversus-OSS migration — parity matrix + DC-6 synthesis-crux spike verdict + ollama/pipx env probe
- installer-staging-fix: install-{claude-code,codex,cursor}.sh now stage scripts/templates/references/ into target project + manifest-backed --uninstall; references/installation.md rewritten with Upgrading/Uninstall sections.
- state-tier-fix: scripts/state/find-active-milestone.sh reads tier from EVALUATION.md first, falls back to ROADMAP.md — unblocks orchestrator:auto on evaluated-but-unroadmapped Tier C milestones.
- ingest-fr-slug-fix: scripts/knowledge/ingest-spec.sh accepts **FR-N (slug)** markers and aborts loudly on unmatched FR lines (was silent data loss on 36 chunks per bbt-companion dogfood).
- reinit-sentinel-fix: scripts/lifecycle/reinit-handler.sh preserves all # >>> orchestrator:NAME >>> sentinel blocks (not just project-identity), canonicalizes relative --project-dir, and keeps runtime_confidence sticky. Known limitation: template-regenerate model still loses free-form prose outside sentinel/CUSTOM blocks — redesign pending.
- M026: milestone consolidated (87% reduction, 3 phases archived)
- M014: milestone consolidated (87% reduction, 4 phases archived)
- M024: milestone consolidated (84% reduction, 7 phases archived)
# <<< orchestrator:recent-changes <<<
