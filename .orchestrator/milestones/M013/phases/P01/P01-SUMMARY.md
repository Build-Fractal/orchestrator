---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M013"
milestone: "M013"
provides:
  - "templates/github-integration-sidecar.json; scripts/integrations/sidecar-init-pending.sh; scripts/integrations/github-status.sh; scripts/integrations/uat-ingest.sh; commands/github-status.md; .github/ISSUE_TEMPLATE/uat-bug.yml; scripts/knowledge/rebuild-index.sh (additive Spec Chunks section); scripts/knowledge/lib/index-utils.sh (emit_spec_chunks_section helper); knowledge/spec/defect/README.md (SPEC-DEFECT-NNN schema); references/github-integration.md (P01 skeleton); 9 verify gates under scripts/verify/m013-p01-*.sh"
requires:
  - "M011 KNOWLEDGE-INDEX.md; M011 SPEC-* frontmatter in knowledge/spec/**/SPEC-*.md; scripts/verify/anti-pattern-lint.sh (M016/M021 invariant)"
affects:
  - "P02 (consumes sidecar template + github-common patterns); P03 (consumes fixture ingester shape + defect schema); M020 (Knowledge-Layer Boundary handoff — chunk ID authority)"
key_files:
  - "templates/github-integration-sidecar.json; scripts/integrations/sidecar-init-pending.sh; scripts/integrations/github-status.sh; scripts/integrations/uat-ingest.sh; commands/github-status.md; .github/ISSUE_TEMPLATE/uat-bug.yml; scripts/knowledge/rebuild-index.sh; scripts/knowledge/lib/index-utils.sh; knowledge/spec/defect/README.md; references/github-integration.md; scripts/verify/m013-p01-phase-suite.sh; scripts/verify/m013-p01-bash32-compat.sh"
key_decisions:
  - "D014 (conversus red-blue pressure test outcomes applied pre-discuss); FR-9 additive-only emit pass with chunk-IDs pinned to existing SPEC-* frontmatter (Knowledge-Layer Boundary with M020)"
patterns_established:
  - "pending-sentinel bootstrap with clobber-refusal exit 2; gate-script naming m013-p01-<artifact>.sh with final self-named PASS summary; bash-3.2 compat sweep via bash -n + bash-4-only pattern whitelist grep; fixture-driven ingester with --source dir mirroring post-Issue-Forms shape; .gitignored operator-owned live sidecar with in-repo template; comment-discipline — self-matching anti-pattern regex avoided via synonym paraphrase"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/P01-PLAN.md; .orchestrator/milestones/M013/phases/P01/tasks/T01-SUMMARY.md through T07-SUMMARY.md"
duration: "unreported"
verification_result: "pass"
completed_at: "2026-04-21T18:30:00Z"
observability_surfaces: "none"
---

M013/P01 (Minimal Slice) shipped the GitHub integration scaffold: sidecar schema template + pending-sentinel bootstrap helper (T01), tri-state `orchestrator:github status` command reading the sidecar (T02), UAT Bug Issue Form with required Spec Chunk ID field (T03), additive `## Spec Chunks` emit pass in `rebuild-index.sh` (T04), `knowledge/spec/defect/` schema + fixture-driven `uat-ingest.sh` with `chunk-lookup-failed` sentinel (T05), `references/github-integration.md` P01-scoped skeleton (T06), and a 9-gate dependency-ordered phase suite + bash-3.2 compat + anti-pattern-lint sweep across all 14 P01 .sh files (T07).

Demo criterion satisfied: opening a UAT Bug Issue referencing a valid `SPEC-*` chunk → `uat-ingest.sh` writes `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with `{chunk, phase, tests}` frontmatter edges and unknown chunk IDs flagged (never dropped); `orchestrator:github status` accurately reports absent / pending-operator-complete / configured sidecar states.

Knowledge-Layer Boundary honored throughout: chunk IDs pin to existing `SPEC-*` frontmatter; no new ID format introduced; `phase_id` sourced from frontmatter when present and emitted as empty string otherwise (M020 may extend).

Key patterns established: (1) pending-sentinel bootstrap helper with clobber-refusal exit 2 inheriting the M012/P04 DEPLOY-RECORD convention; (2) gate-script naming `scripts/verify/m013-p01-<artifact>.sh` with 10+ PASS lines + final self-named summary PASS; (3) `bash -n` parse + whitelisted bash-4-only pattern grep (`declare -A`, `mapfile`, `readarray`, `${,,}`/`${^^}`, `<(…)`, `>(…)`, `&>`, `|&`) as the bash-3.2 compat check surface; (4) fixture-driven P01 ingestion with `--source <dir>` that mirrors post-Issue-Forms shape so P03 wires live `gh` without ingester changes; (5) `.orchestrator/integrations/github.json` gitignored — operator-owned live sidecar, template-in-repo.

Verification: phase suite exit 0, 9/9 gates pass. Anti-pattern-lint clean across all 14 P01 .sh files.

Judgment calls surfaced during execution (for operator review): (a) sidecar is template + bootstrap helper only — not a committed live config; (b) `phase_id` column in KNOWLEDGE-INDEX Spec Chunks section is currently empty for all 20 existing SPEC-* files (no frontmatter has `phase_id:` yet — M020 may extend); (c) T02's `--init-pending` wraps T01's exit 2 behind `[ ! -f $SIDECAR ]` guard, making repeat bootstrap idempotent from caller perspective; (d) `scripts/lifecycle/phase-transition.sh` crashes on non-numeric duration values ("unreported") — worked around by writing this summary directly; orchestrator infrastructure bug flagged for operator follow-up.

Observability surfaces: none at P01 scope (P03 introduces `unit_close` + `conversus_gate_invocation` JSONL emitters in M019 Tier 1 shape).
