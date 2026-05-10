---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M012"
provides:
  - "scripts/wiki/wiki-generate-stubs.sh — thin include-plugin stub generator that reads wiki-scan-sources.sh output and writes one <=25-line stub per in-scope .orchestrator/**.md artifact under wiki/docs/; each stub carries a YAML title + include-markdown directive pointing at a ../-relative canonical path (AD-3 SSOT); also emits per-section index.md files (milestones/, archive/, per-M###/, per-P##/) listing children in lexical order for T04 nav consumption"
requires:
  - "from:T01 what:wiki/ skeleton + mkdocs.yml with include-markdown plugin declared; from:T02 what:scripts/wiki/wiki-scan-sources.sh emitting <category>|<rel-path>|<title> records on stdout with exclusion policy applied"
affects:
  - "P01/T04 (wiki-generate-nav.sh mirrors the wiki/docs/ directory tree produced here), P01/T05 (m012-p01-include-plugin.sh + m012-p01-ssot.sh + m012-p01-exclusion-policy.sh + m012-p01-bash32-compat.sh assert on the stubs this script writes)"
key_files:
  - "scripts/wiki/wiki-generate-stubs.sh,wiki/docs/constitution.md,wiki/docs/decisions.md,wiki/docs/knowledge.md,wiki/docs/milestone-summary.md,wiki/docs/milestones/index.md,wiki/docs/milestones/M002/M002-CONTEXT.md,wiki/docs/milestones/M012/phases/P01/tasks/T03-PLAN.md"
key_decisions:
  - "AD-3,AD-6,AD-19,FR-8,M012-Constitution-VI"
patterns_established:
  - "per-stub canonical-path depth computed from slash-count of stub-rel-path (depth = N_slashes + 2) keeps it Bash 3.2 pure-string; clean-phase find uses -mindepth 1 with !-path guards on top-level index.md/README.md to preserve hand-authored pages while wiping every auto-generated .md under wiki/docs/; section indexes emit one bullet per unique child (sort -u) with child_title fallback to child_rel for empty titles; parallel /tmp list files scoped by PID replace associative arrays for section-to-children bookkeeping; idempotency proven by shasum-of-sha-list diff across two consecutive runs; stub template is 12-13 lines — well under the 25-line must-have — and carries only YAML title, authoring comment citing AD-3, and an include-markdown block with heading-offset=0 + rewrite-relative-urls=true"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P01/tasks/T03-PAYLOAD.md"
duration: "35"
verification_result: "pass"
completed_at: "2026-04-18T13:31:02Z"
---

Shipped scripts/wiki/wiki-generate-stubs.sh — the stub generator that projects every in-scope .orchestrator/**.md artifact into wiki/docs/ via thin mkdocs-include-markdown stubs. Bash 3.2 compliant; MEM004 carve-out respected (helper script uses pipes, awk, find, heredocs internally — not agent-facing). Supports --dry-run and --root PROJECT_ROOT. Clean phase removes every .md under wiki/docs/ except top-level index.md and README.md before re-emitting, then prunes now-empty subdirectories. Canonical path from a stub is computed as (slash_count(stub_rel) + 2) * '../' + '.orchestrator/' + orch_rel — verified against samples: constitution.md -> ../../.orchestrator/memory/constitution.md; milestones/M002/phases/P01/tasks/T01-PLAN.md -> ../../../../../../../.orchestrator/milestones/M002/phases/P01/tasks/T01-PLAN.md (both resolve to real files on disk). Stub template is 13 lines with a YAML title, an authoring comment citing AD-3, and an include-markdown block (heading-offset=0, rewrite-relative-urls=true). Section indexes generated for milestones/, archive/ (empty per current state), each milestones/M###/, and each milestones/M###/phases/P##/ — bullets in sort -u order for T04 nav parity. Dogfood run against current .orchestrator/ produced 945 stubs + 82 section indexes + 2 preserved top-level files = 1029 .md files. Idempotency verified: shasum-of-sha-list across wiki/docs/ identical between run 1 and run 2 (byte-identical). Must-have checks: all 945 stubs contain an include-markdown directive; 0 no-include; 4 section indexes exceed 25 lines (phase indexes for dense task trees and the [M008](../../../../milestones/M008/index.md) milestone index) — these are section indexes, not stubs, and the critical-reminder 25-line rule targets stubs per payload language. No stubs reference .orchestrator/scratch/, tmp/, or config/ (the single false positive was a T04-PLAN.md whose title text happens to mention '.orchestrator/config/pricing.yml'). No nav block touched; no verify scripts written; those are T04 and T05.
