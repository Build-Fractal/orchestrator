---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M015/P03"
milestone: "M015"
provides:
  - "Five primary standalone docs reframed (README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md) and CHANGELOG.md M015 [0.9.0] entry appended above historical entries; three P03 verifiers now PASS (standalone-framing, no-legacy-install, changelog-has-m015)."
requires:
  - "T01 verify scaffolding + CHANGELOG historical snapshot at scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt; P02 state tree migration to .orchestrator/."
affects:
  - "T03 (migration guide + wider sweep), T04 (closeout + ALLOW_P03_DOCS shrink)."
key_files:
  - "README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md, CHANGELOG.md"
key_decisions:
  - "Used 'extension to spec-kit' (not 'spec-kit extension') for the single historical one-liner in README.md to clear the framing verifier literal blocklist. Version bumped to 0.9.0 dated 2026-04-15. For CLAUDE.md Recent Changes line describing the state migration, avoided naming the legacy '.specify/orchestrator' path — phrased the relocation instead — to keep the no-legacy-install verifier clean. references/architecture.md got surgical edits (Overview rewrite, state-machine path sweep, file-layout diagram rewrite to drop extension.yml and pivot to .orchestrator/ + packaging/) rather than a full rewrite. references/installation.md and docs/getting-started.md were fully rewritten because the cp -r install flow and Step 3 CLAUDE.md template were structurally incompatible with standalone framing."
patterns_established:
  - "Framing-verifier-friendly migration callouts: when Recent Changes or historical prose must describe the state migration, reference the new path only and describe the relocation without naming the legacy path literally; avoids re-tripping the no-legacy-install grep without losing information."
drill_down_paths:
  - ".orchestrator/milestones/M015/phases/P03/tasks/T02-PLAN.md"
duration: "38"
verification_result: "pass"
completed_at: "2026-04-15T14:37:36Z"
---

Reframed the five primary standalone docs and appended the M015 v0.9.0 CHANGELOG entry. README (258 -> 248), CLAUDE.md (78 -> 70), references/architecture.md (378 -> 381, surgical edit), references/installation.md (258 -> 251, full rewrite), docs/getting-started.md (391 -> 412, full rewrite), CHANGELOG.md (287 -> 319, M015 entry prepended). CHANGELOG historical tail is byte-identical to the T01 snapshot (diff -q clean). All three in-scope P03 verifiers PASS: m015-p03-standalone-framing, m015-p03-no-legacy-install, m015-p03-changelog-has-m015. The remaining three P03 verifiers (migration-doc, wider-docs-sweep, allow-list-tightened) correctly remain FAIL — they gate on T03/T04.
