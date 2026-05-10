---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M011"
provides:
  - "spec-metrics.sh helper counting non-superseded spec chunks by category, commands/evaluate.md chunks-first wiring with raw-spec fallback, metrics_source evaluation field, three m011-p05 verify scripts (counts, skips-superseded, evaluate-doc-references)"
requires:
  - "P02 spec-chunk shape (category/superseded_by frontmatter), P04 superseded-tip filtering convention, existing commands/evaluate.md structure"
affects:
  - "T02 roadmap command (parallel sibling, consumes same chunk tree), T03 demo-scenario + doc-regression (verifies preserved Reference Files, consumes spec-metrics output)"
key_files:
  - "scripts/state/spec-metrics.sh, commands/evaluate.md, scripts/verify/m011-p05-spec-metrics-counts.sh, scripts/verify/m011-p05-spec-metrics-skips-superseded.sh, scripts/verify/m011-p05-evaluate-doc-references-metrics.sh"
key_decisions:
  - "awk-on-files rather than SQL via knowledge.db so spec-metrics works before any rebuild-index run; two-step knowledge-root resolver (orch_root sibling first, then SCRIPT_DIR-derived project root); for f in dir/*.md plus [ -e ] || continue handles empty dirs without nullglob; metrics_source is a new evaluation-output field, not a tier-rule change"
patterns_established:
  - "spec-chunk counter as a single-purpose state helper emitting key=value lines on stdout; chunks-first with raw-spec graceful fallback pattern for commands that previously re-parsed specs on every run; targeted three-edit documentation update preserving all existing Reference File bullets"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P05/tasks/T01-PAYLOAD.md, .orchestrator/milestones/M011/phases/P05/tasks/T01-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T03:30:40Z"
---

T01 adds scripts/state/spec-metrics.sh and wires commands/evaluate.md
to prefer ingested spec chunks over raw-spec regex when counting
structural elements for tier classification. spec-metrics.sh emits
seven key=value lines to stdout: spec_chunks_present,
story_count, requirement_count, acceptance_count, constraint_count,
nfr_count, non_goal_count. Counts are non-superseded tips only — a
chunk whose frontmatter superseded_by field is non-empty is skipped
so a spec revised from 5 to 7 requirements reports
requirement_count=7 (not 12). The helper resolves the knowledge root
via a two-step precedence: first <orch_root>/../knowledge/spec
(repo layout with .orchestrator/ sibling to knowledge/), then
<project-root>/knowledge/spec via SCRIPT_DIR parent. When no tree
exists it emits spec_chunks_present=false with zero counts and
exits 0 (verified via bash scripts/state/spec-metrics.sh /tmp).

commands/evaluate.md gains three targeted insertions, no deletions:
(1) the "Count structural elements" step now documents a chunks-first
path that calls spec-metrics.sh and a raw-spec fallback, with a
metrics_source output field (spec_chunks vs raw_spec); (2) the
evaluation-output field list gains a metrics_source bullet after the
existing complexity-factors bullet; (3) the Reference Files block
gains scripts/state/spec-metrics.sh between read-config.sh and
scaffold.sh so the script bullets stay grouped. Tier A/B/C
classification rules are unchanged — this is a metric-source switch,
not a tier-rule change. All pre-existing Reference File bullets
(templates/evaluation.md, scripts/state/read-config.sh,
scripts/lifecycle/scaffold.sh, references/tier-definitions.md,
references/installation.md) remain present.

Three verify scripts under scripts/verify/m011-p05-*.sh certify the
contract: spec-metrics-counts (8-chunk fixture across 6 categories
asserts all 7 output keys), spec-metrics-skips-superseded (v1→v2
chain plus two independent tips asserts requirement_count=3), and
evaluate-doc-references-metrics (greps evaluate.md for the new
references, path, headings, and metrics_source field). All three
print PASS and exit 0.

Implementation is Bash 3.2 safe — plain awk on each file for
frontmatter parsing, no declare -A / mapfile / readarray / <(...),
no jq or python3 dependency. The for f in "$dir"/*.md plus
[ -e "$f" ] || continue pattern handles empty category directories
without nullglob. The script uses $(...) internally to capture
function output (count_category prints to stdout), which is
permitted inside the helper script — the AP-004 restriction applies
only to Bash tool calls the executor makes directly.

No changes to commands/roadmap.md (T02 territory), no changes to
scope-filter.sh / rebuild-index.sh / graph-db.sh, no Bash 3.2 compat
scan script (T03 territory), no end-to-end demo scenario (T03
territory).
