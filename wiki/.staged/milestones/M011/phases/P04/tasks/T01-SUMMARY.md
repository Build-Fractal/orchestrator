---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M011"
provides:
  - "scope-filter.sh --spec-scope-tags mode (filter_spec_scope_tags function), six m011-p04 verify scripts"
requires:
  - "scripts/dispatch/scope-filter.sh (P01), scripts/knowledge/traverse-graph.sh, scripts/knowledge/lib/graph-db.sh, scripts/knowledge/rebuild-index.sh, knowledge/spec/<cat>/<SPEC-XX-NNN>.md entries (P02/P03)"
affects:
  - "build-context.sh (T02 will consume --spec-scope-tags output), dispatch payload Spec Context section (T02)"
key_files:
  - "scripts/dispatch/scope-filter.sh, scripts/verify/m011-p04-bash32-compat.sh, scripts/verify/m011-p04-spec-scope-tag-resolve.sh, scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh, scripts/verify/m011-p04-requirement-pulls-neighbors.sh, scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh, scripts/verify/m011-p04-spec-scope-skips-superseded.sh"
key_decisions:
  - "Dispatch check placed at bottom of scope-filter.sh so filter_spec_scope_tags is defined before call; positional-arg validation skipped via if-guard on SPEC_SCOPE_TAGS. Fallback scans knowledge/spec/<cat>/<id>.md at project-root layout (not .orchestrator/knowledge). Respects PROJECT_ROOT env var in fallback path for sandbox testability."
patterns_established:
  - "ID-emission mode distinct from knowledge-filter mode; lazy-source graph-db.sh guarded by _GRAPH_DB_SOURCED; mktemp + sort -u dedup for merging initial IDs with 1-hop neighbors; verify scripts seed .orchestrator/ marker in sandbox so get_project_root() respects PROJECT_ROOT during rebuild"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P04/tasks/T01-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-17T01:22:21Z"
---

T01 extended scripts/dispatch/scope-filter.sh with a new --spec-scope-tags
mode that resolves spec/<cat>/<SPEC-XX-NNN> tags to SPEC- entry IDs and
emits one ID per line, followed by their 1-hop relates_to graph neighbors
(via traverse-graph.sh). The mode is self-sufficient: the positional
<file-path> <scope-context> validation is skipped when --spec-scope-tags
is present, so callers do not need to supply dummy values. Superseded
tips (non-empty superseded_by) are skipped with a WARN: on stderr, and
spec/non-goal entries are excluded by default per AD-7 (P01), honoring
the existing --include-non-goals flag.

The filter_spec_scope_tags function lazy-sources scripts/knowledge/lib/
graph-db.sh (guarded by _GRAPH_DB_SOURCED) and uses a SQL lookup against
knowledge.db when present, falling back to direct frontmatter reads of
knowledge/spec/<cat>/<id>.md when the DB is absent. Neighbor collection
shells out to traverse-graph.sh --id <id> --hops 1 --max-entries 10. The
emitter writes initial IDs in input order first, then sorted-unique
neighbors not already in the initial set, using mktemp files for
concurrent safety.

Six verify scripts were created under scripts/verify/m011-p04-*.sh:
bash32-compat (T01 variant — scans only scope-filter.sh per the T03
expansion plan), spec-scope-tag-resolve, spec-scope-tag-graph-neighbors,
requirement-pulls-neighbors (3 requirements + 2 acceptances + 1
constraint with selective relates_to wiring), spec-scope-excludes-non-
goals, and spec-scope-skips-superseded. Every script builds a mktemp
sandbox, writes valid frontmatter fixtures, invokes rebuild-index.sh
under PROJECT_ROOT, then asserts scope-filter.sh stdout/stderr with
grep. All six print PASS: and exit 0.

Key Bash 3.2 discipline: no declare -A, no mapfile, no readarray, no
process substitution. Temp files + while-read-from-real-file loops
throughout. The dispatch check was placed at the bottom of scope-
filter.sh (alongside the --graph dispatch) rather than immediately
after arg parsing so that the function is defined before it is called;
skipping positional-arg validation is achieved by wrapping the
existing validation block in if [[ -z "$SPEC_SCOPE_TAGS" ]]. This
preserves the plan intent (mode bypasses positional validation) while
respecting bash's function-definition ordering.
