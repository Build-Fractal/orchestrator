---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M012"
provides:
  - "wiki/mkdocs.yml include-markdown rewrite_relative_urls:true load-bearing setting; scripts/wiki/wiki-scan-sources.sh extended with knowledge/**/MEM*.md enumeration emitting knowledge:<category>|<repo-root-relative-path>|<title> records for patterns (11), conventions (9), lessons (5) in lexical order, appended strictly after .orchestrator/ records"
requires:
  - "from:M012/P01 what:wiki/ skeleton + include-plugin config + scanner emitting .orchestrator/**.md records; from:none what:knowledge/patterns,conventions,lessons/MEM*.md tree"
affects:
  - "M012/P02/T02 (stub generator will consume new knowledge:<category> records to emit wiki/docs/knowledge/<category>/MEM*.md include stubs + section indexes); M012/P02/T03 (nav generator will build Knowledge Entries subtree); M012/P02/T05 (link-rewrite-config + mem-stubs + mem-anchors verification gates)"
key_files:
  - "wiki/mkdocs.yml,scripts/wiki/wiki-scan-sources.sh"
key_decisions:
  - "AD-3 SSOT (scanner emits paths only; no content copy); Constitution XIV (no speculative flag added — emission unconditional when knowledge/ exists); Constitution XV (touched exactly two files)"
patterns_established:
  - "Additive scanner extension invariant: new emission block appended after existing blocks so downstream generators see stable order (top-level -> milestone -> archive -> knowledge:patterns -> knowledge:conventions -> knowledge:lessons); repo-root-relative <rel-path> convention for source trees outside .orchestrator/ (distinct from the .orchestrator-relative convention used for .orchestrator/**.md records); extract_title helper reuse avoids duplicate H1/pipe-sanitization logic across emission blocks"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P02/tasks/T01-PLAN.md,wiki/mkdocs.yml,scripts/wiki/wiki-scan-sources.sh"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-20T22:54:07Z"
---

T01 lands the two prerequisite invariants every subsequent P02 task rides on: include-plugin relative-URL rewriting declared load-bearing, and scanner knowledge/ enumeration.

## What was built

- **wiki/mkdocs.yml** — expanded the 'include-markdown' plugin from a bare list entry to an options block declaring 'rewrite_relative_urls: true' + 'heading_offset: 0'. The 'toc: permalink: true' markdown extension was already present from P01 (line 39-40) so no change needed there; grep-confirmed before move on.
- **scripts/wiki/wiki-scan-sources.sh** — appended a knowledge-tree emission block after the existing .orchestrator/archive scan and before the SUMMARY trailer. The block iterates a fixed category list ('patterns' 'conventions' 'lessons'), uses 'find -maxdepth 1 -type f -name MEM*.md | LC_ALL=C sort' to a /tmp list file (PID-suffixed, outside ROOT) to avoid the |-while subshell COUNT-loss, reads each path, extracts the title via the existing extract_title helper (H1 grep + pipe-sanitization + basename fallback), and prints 'knowledge:<cat>|<repo-root-relative-path>|<title>' records. The emission is unconditional when knowledge/ exists (no flag).

## Verification

- Scanner output: 983 total records (958 .orchestrator + 25 knowledge: 11 patterns + 9 conventions + 5 lessons). Knowledge records appear strictly after the last archive/milestone record. No empty third-field records (grep -E '^knowledge:[^|]+\|[^|]+\|$' returns 0).
- Byte-identical .orchestrator/ portion: head -n 958 of post-change output equals pre-change output exactly (diff -q confirms).
- mkdocs.yml: 'grep -F rewrite_relative_urls: true wiki/mkdocs.yml' emits one line; 'grep -A1 "- toc:" wiki/mkdocs.yml' shows the permalink:true sub-option.
- m012-p01-bash32-compat gate: PASS (0 violations across 14 scanned files — knowledge-block uses no declare -A, mapfile, process substitution, or &>).
- m012-p01-phase-suite.sh: 8/9 gates PASS — same as pre-T01 baseline. The one failing gate (m012-p01-nav-structure) was already failing before T01 ran because the nav block in wiki/mkdocs.yml was last regenerated before the M012/P01 task summaries (T01-T05) were written; the scanner now sees those summaries plus the new 25 knowledge records, none of which are in the nav block. T02 rebuilds the nav, which resolves this. T01 did not regress any previously-passing gate.

## Patterns established

- **Additive scanner extension discipline** — new emission blocks are appended, never interleaved. This preserves the lexical invariant existing downstream consumers rely on and guarantees byte-identical output for the pre-existing record portion.
- **Two-convention rel-path scheme** — .orchestrator/**.md records carry a rel-path relative to the .orchestrator/ root ('memory/constitution.md', 'milestones/M002/...'); knowledge/**/MEM*.md records carry a rel-path relative to the repo root ('[knowledge/patterns/MEM001.md](../../../../knowledge/patterns/MEM001.md)'). Downstream generators must switch on the category prefix to pick the correct join-base for the include-markdown directive.
- **extract_title helper reuse** — the existing helper handles H1 grep, pipe-to-slash sanitization (3-field schema preservation), and basename fallback uniformly; the new emission block reuses it rather than inlining a parallel pipeline.

## Deferred to T02 and beyond

- **Stub generator extension** (T02) — wiki-generate-stubs.sh must learn the knowledge:<cat> categories and emit wiki/docs/knowledge/<cat>/MEM*.md include stubs with canonical paths joined against the repo root (not .orchestrator/).
- **Nav generator extension** (T03) — wiki-generate-nav.sh must emit a 'Knowledge Entries' top-level subtree with per-category subgroups.
- **m012-p02-link-rewrite-config.sh gate** (T05) — will formally assert the rewrite_relative_urls:true and toc:permalink:true settings; manual grep-confirmation was done here for T01 acceptance.
- **Pre-existing nav-structure baseline failure** — caused by M012/P01 task summaries landing after the nav was last regenerated; T02 regeneration will close it out of scope for T01.
