# >>> orchestrator:recent-changes >>>
- 027-conversus-oss-migration: Migrate orchestrator default Conversus integration from paid build to OSS build with paid-escape-hatch preserved (M026).
- M026/P02: conversus-OSS resolver flip — OSS primary, paid escape hatch via CONVERSUS_EDITION; JSONL edition field; dual-edition regression test with visible-skip annotations; gate-verdict-reliability bundle (verdict-text rationale, arbiter preference, OAuth auto-preflight closes OQ-16 false-PASS).
- M026/P01: conversus-OSS migration — parity matrix + DC-6 synthesis-crux spike verdict + ollama/pipx env probe
- installer-staging-fix: install-{claude-code,codex,cursor}.sh now stage scripts/templates/references/ into target project + manifest-backed --uninstall; references/installation.md rewritten with Upgrading/Uninstall sections.
- state-tier-fix: scripts/state/find-active-milestone.sh reads tier from EVALUATION.md first, falls back to ROADMAP.md — unblocks orchestrator:auto on evaluated-but-unroadmapped Tier C milestones.
- ingest-fr-slug-fix: scripts/knowledge/ingest-spec.sh accepts **FR-N (slug)** markers and aborts loudly on unmatched FR lines (was silent data loss on 36 chunks per bbt-companion dogfood).
- reinit-sentinel-fix: scripts/lifecycle/reinit-handler.sh preserves all # >>> orchestrator:NAME >>> sentinel blocks (not just project-identity), canonicalizes relative --project-dir, and keeps runtime_confidence sticky. Known limitation: template-regenerate model still loses free-form prose outside sentinel/CUSTOM blocks — redesign pending.
# <<< orchestrator:recent-changes <<<
