---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M011"
provides:
  - "End-to-end P05 demo-scenario verification (3 stories, 8 requirements, 5 acceptances, 2 constraints, 1 non-goal, US-003->US-001 edge); Bash 3.2 compat scan over three new/modified P05 scripts; command-reference-preservation regression guard for evaluate.md + roadmap.md"
requires:
  - "T01 spec-metrics.sh, T02 spec-story-graph.sh + intensity-gate.sh roadmap stage, rebuild-index.sh edge persistence, P04 regression suite stability"
affects:
  - "P05 verification closes with 11 m011-p05-*.sh PASS; M011 ready to progress to P06 end-to-end validation"
key_files:
  - "scripts/verify/m011-p05-demo-scenario.sh, scripts/verify/m011-p05-bash32-compat.sh, scripts/verify/m011-p05-commands-preserve-references.sh"
key_decisions:
  - "AD-T03-1 heading-bearing fixture entries required for rebuild-index.sh under pipefail; AD-T03-2 rebuild failure must be loud (no || true) so a bad fixture fails fast; AD-T03-3 comment-strip before forbidden-token grep (consistent with P04 compat scan)"
patterns_established:
  - "Verify-script fixtures must write full spec-chunk frontmatter AND a heading to survive rebuild-index.sh description-extraction under set -euo pipefail; verify suites wrapped in /tmp runner scripts to honor AP-004 no-compound-chain rule in executor Bash calls"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P05/tasks/T03-SUMMARY.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-17T04:10:54Z"
---

T03 delivered the P05 verification layer with three new scripts under scripts/verify/m011-p05-*.sh and no production code changes.

m011-p05-demo-scenario.sh builds the full P05 demo fixture — 3 stories (SPEC-US-003 relates_to SPEC-US-001), 8 requirements, 5 acceptances, 2 constraints, 1 non-goal — under $(mktemp -d) with an EXIT trap. The fixture writes the complete ingest-spec.sh-shaped frontmatter (id/scope_tags/category/confidence/created_at/last_verified/hit_count/source_unit/source_type/supersedes/superseded_by/relates_to/content_hash) plus a leading `# <id>: ...` heading. The heading is load-bearing: rebuild-index.sh runs under set -euo pipefail and its description-extraction pipeline (grep ^# | head -1 | sed) returns non-zero when no heading matches, aborting the whole rebuild silently. A minimal frontmatter (which the payload's initial sketch used) caused rebuild to die before edge insertion, producing SPEC-US-003| with no deps. Once heading-bearing entries land, rebuild persists 19 entries + 1 edge into knowledge.db, spec-metrics.sh reports the seven documented counts, and spec-story-graph.sh emits the SPEC-US-003|SPEC-US-001 edge.

m011-p05-bash32-compat.sh scans scripts/state/spec-metrics.sh, scripts/knowledge/spec-story-graph.sh, and scripts/engine/intensity-gate.sh for bash -n syntax plus forbidden constructs (declare -A, mapfile, readarray, process substitution <(...)/>(...)), using the same comment-stripping pattern as the P04 scan so descriptive comments don't false-positive.

m011-p05-commands-preserve-references.sh guards the pre-existing Reference File bullets in commands/evaluate.md (templates/evaluation.md, scripts/state/read-config.sh, scripts/lifecycle/scaffold.sh, references/tier-definitions.md, references/installation.md) and commands/roadmap.md (templates/roadmap.md, scripts/state/derive-phase.sh, scripts/state/read-config.sh, scripts/lifecycle/scaffold.sh, references/tier-definitions.md, scripts/verify/check-boundary-map.sh, references/state-machine.md). This catches accidental deletion during any future edit to either command doc.

All 11 P05 verify scripts PASS (3 from T01, 5 from T02, 3 from T03). P04 regression suite (m011-p04-demo-scenario.sh, m011-p04-bash32-compat.sh) still PASS — T02's intensity-gate.sh edit did not regress P04's scope-filter / build-context / section-handlers assertions.

Pattern reinforced: verify-script fixtures that invoke rebuild-index.sh must emit the heading line, not just frontmatter — rebuild's strict pipefail-plus-grep description extractor turns missing headings into silent script abort rather than empty description.
