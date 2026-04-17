---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M011"
provides:
  - "scripts/knowledge/spec-story-graph.sh (directional story-to-story depends_on emitter delegating to traverse-graph.sh), intensity-gate.sh roadmap stage (Quick=single-pass / Standard=basic-decomp,rationale / Full=basic-decomp,rationale,collaborative-loop), commands/roadmap.md chunks-first + intensity-aware wiring with five new Reference Files bullets"
requires:
  - "T01 spec-metrics.sh (referenced by doc), P02 spec/story chunk shape with relates_to/superseded_by frontmatter, P04 scope-filter.sh --category spec/story --graph + --spec-scope-tags modes, M007 scripts/knowledge/traverse-graph.sh 1-hop neighbor API"
affects:
  - "T03 demo-scenario + doc-regression (consumes new Reference Files; scans T02 scripts for Bash 3.2 compat), orchestrator:roadmap runtime behavior at all three intensities, downstream phase graph depends_on derivation"
key_files:
  - "scripts/knowledge/spec-story-graph.sh, scripts/engine/intensity-gate.sh, commands/roadmap.md, scripts/verify/m011-p05-spec-story-graph-emits-deps.sh, scripts/verify/m011-p05-spec-story-graph-delegates.sh, scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh, scripts/verify/m011-p05-roadmap-doc-references-chunks.sh, scripts/verify/m011-p05-roadmap-doc-references-intensity.sh"
key_decisions:
  - "Delegate edge lookup to traverse-graph.sh rather than SQL in spec-story-graph.sh (constitution evidence: traverse-graph is the canonical graph access path); directional edge filter layered on top of bidirectional traverse output by re-reading the source story's relates_to frontmatter; re-export PROJECT_ROOT from orch_root for the delegated traverse subprocess so knowledge.db resolves independent of caller cwd; new roadmap stage follows the existing stage case idiom in intensity-gate.sh (execute/skip CSV pair, added to unknown-stage allowlist); roadmap.md edits are five targeted insertions with zero deletions so the T03 reference-preservation regression stays satisfied"
patterns_established:
  - "Bidirectional-graph + directional-frontmatter filter composition (use traverse-graph for connectivity, re-read frontmatter for direction); orch_root → PROJECT_ROOT shim pattern for helpers that delegate to knowledge.db-backed scripts; intensity-gate stage registration via minimal case-row insertion matching existing stage idiom; chunks-first-with-raw-spec-fallback doc wiring pattern sibling to T01's evaluate.md edits"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P05/tasks/T02-SUMMARY.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-17T03:49:43Z"
---

T02 adds the roadmap side of M011/P05. Three artifacts land together:

(1) scripts/knowledge/spec-story-graph.sh emits one `<SPEC-US-ID>|<comma-sep deps>` line per non-superseded story. Edge traversal is delegated to scripts/knowledge/traverse-graph.sh (--hops 1) rather than reimplemented in SQL — the helper re-exports PROJECT_ROOT derived from the passed orch_root so traverse-graph finds the matching knowledge.db. Because traverse-graph is bidirectional on relates_to, the helper layers a directional filter: it re-reads the current story's `relates_to:` inline-array frontmatter and keeps only neighbors that are explicitly declared outbound from this story. Both the tip and its neighbors must be non-superseded; superseded neighbor IDs are dropped so a chain `US-001 (old) → US-001-v2 (tip) ← US-003` reports US-003 depends on US-001-v2, not on US-001.

(2) scripts/engine/intensity-gate.sh gains a new `roadmap` stage row keyed to the existing Quick/Standard/Full idiom: Quick=single-pass (skip=basic-decomp,rationale,collaborative-loop), Standard=basic-decomp,rationale (skip=collaborative-loop), Full=basic-decomp,rationale,collaborative-loop (skip=single-pass). The unknown-stage error string is extended with `roadmap` so the allowlist stays in sync.

(3) commands/roadmap.md is extended with five targeted insertions (no deletions): a new Prerequisites step 6 invoking `intensity-gate.sh --stage roadmap`; a rewritten Spec Analysis step 1 documenting the chunks-first path (enumerate via scope-filter.sh --category spec/story --graph, read story-to-story edges via spec-story-graph.sh, pull related acceptance/constraint chunks per story) with the raw-spec fallback preserved as legacy behavior; a new "Intensity-Aware Interaction" subsection prepended under Roadmap Generation that delegates Full-intensity to speckit.orchestrator.discuss; a new bullet under Phase Decomposition describing chunk→phase mapping and depends_on derivation; and five new Reference Files bullets (scope-filter.sh, spec-story-graph.sh, traverse-graph.sh, intensity-gate.sh, spec-metrics.sh) inserted between scaffold.sh and tier-definitions.md so existing bullets remain intact.

Verification: five T02 verify scripts pass (spec-story-graph-emits-deps, spec-story-graph-delegates, intensity-gate-roadmap-stage, roadmap-doc-references-chunks, roadmap-doc-references-intensity). All 10 P04 verify scripts and all 3 P05/T01 verify scripts continue to pass — no regressions. Bash 3.2 compatibility preserved (no declare -A, mapfile, readarray, or process substitution).
