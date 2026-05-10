---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M012"
provides:
  - "scripts/wiki/wiki-generate-stubs.sh extended to consume knowledge:<category> scanner records — routes each to wiki/docs/knowledge/<sub>/<MEM###>.md with canonical include rooted at repo (knowledge/<sub>/<MEM>.md) via build_canonical_repo_rel helper, plus emits 4 section indexes (knowledge/index.md + patterns/conventions/lessons per-category indexes) carrying the 'Auto-generated section index' comment probe; scripts/wiki/wiki-generate-nav.sh extended to emit a Knowledge Entries subtree between the consolidated Knowledge: leaf and the Milestone Summary: leaf, grouped by category in lexical order with per-category Overview leaves; scripts/verify/m012-p01-include-plugin.sh extended additively to accept repo-rooted knowledge/** canonical targets alongside the pre-existing .orchestrator/** allowance"
requires:
  - "from:M012/P02/T01 what:wiki-scan-sources.sh emitting knowledge:<category>|<repo-root-rel>|<title> records + wiki/mkdocs.yml rewrite_relative_urls:true + toc:permalink:true; from:M012/P01 what:P01 stub/nav generator skeleton + P01 9-gate verification suite"
affects:
  - "M012/P02/T03 (wiki/README.md link-resolution policy authoring reads the generated Knowledge Entries subtree shape + MEM stub canonical-path convention); M012/P02/T04 (diagnostics wiki-link-check.sh built-site walker will see the 25 MEM stubs + 4 knowledge indexes as additional in-scope pages); M012/P02/T05 (m012-p02-mem-stubs.sh mechanical gate will assert on the exact stub count + nav-leaf count this task produces; m012-p02-mem-anchors.sh gate will run its anchor-probe against these stubs)"
key_files:
  - "scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/verify/m012-p01-include-plugin.sh,wiki/docs/knowledge/index.md,wiki/docs/knowledge/patterns/index.md,wiki/docs/knowledge/conventions/index.md,wiki/docs/knowledge/lessons/index.md,wiki/docs/knowledge/patterns/MEM001.md..MEM011.md,wiki/docs/knowledge/conventions/MEM012.md..MEM020.md,wiki/docs/knowledge/lessons/MEM021.md..MEM025.md,wiki/mkdocs.yml"
key_decisions:
  - "AD-3 SSOT (every MEM stub is a ≤25-line include shell — no canonical body copied); AD-6 nav completeness (every knowledge:* scanner record maps to exactly one nav leaf); AD-19 single-script-file Check shape (all verification lives inside the P01 gate scripts); Constitution XIV (no speculative flags — Knowledge Entries subtree emitted unconditionally when scanner sees records); Constitution XV (surgical precision — T02 touched exactly the two generator scripts, one P01 gate additively, and created the wiki/docs/knowledge/ subtree)"
patterns_established:
  - "Per-category /tmp list files as fixed-slot associative-array replacement (bash 3.2 safe) — three hard-coded filenames (KN_PATTERNS_LIST, KN_CONVENTIONS_LIST, KN_LESSONS_LIST) scoped by PID; Two-root canonical scheme picked by category-prefix branch (build_canonical for .orchestrator/-rooted records, build_canonical_repo_rel for repo-rooted knowledge/ records); Additive P01 gate extension when a downstream task legitimately expands the set of valid canonical roots (rather than duplicating the gate under P02); Scanner-presence-gated subtree emission (Knowledge Entries subtree disappears cleanly when scanner sees zero knowledge:* records, mirroring P01's conditional Archive bucket)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P02/tasks/T02-PLAN.md,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/verify/m012-p01-include-plugin.sh"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-20T23:39:27Z"
---

T02 extends the two P01 generators (stubs + nav) to consume the `knowledge:<category>` scanner records that T01 added, projecting every `knowledge/**/MEM*.md` canonical file into the wiki as a thin include stub plus a `Knowledge Entries` nav subtree. A minor additive patch to the P01 `include-plugin` gate lets it accept both `.orchestrator/**` and `knowledge/**` as valid canonical roots so all nine P01 gates stay green.

## What was built

- **scripts/wiki/wiki-generate-stubs.sh** — added a `knowledge:patterns|knowledge:conventions|knowledge:lessons` branch at the top of the main record loop that (a) routes the stub to `wiki/docs/knowledge/<sub>/<MEM>.md`, (b) uses the pre-existing (T-attempt-1) `build_canonical_repo_rel` helper to emit a canonical include path whose root is the repo (not `.orchestrator/`), and (c) records `<mem_id>|<title>` to a per-category `/tmp` list for the section-index emitter. Appended a knowledge-section-index block after the existing milestone/archive index emission that writes four indexes — `wiki/docs/knowledge/index.md` (top-level, three category links) plus per-category `patterns/index.md`, `conventions/index.md`, `lessons/index.md` (bullet list of every MEM stub in lexical order). All four carry the `Auto-generated section index` probe comment so the P01 SSOT gate classifies them as indexes (not artifact stubs).
- **scripts/wiki/wiki-generate-nav.sh** — added a `Knowledge Entries` subtree emitted between the existing `Knowledge: knowledge.md` leaf and the `Milestone Summary:` leaf. The subtree opens with an `Overview` leaf pointing at [`knowledge/index.md`](../../../../knowledge/index.md), then three category groups (Patterns / Conventions / Lessons), each group led by its `Overview` pointing at the per-category index, followed by one `MEM###: knowledge/<sub>/MEM###.md` leaf per entry in lexical order. The subtree is emitted only when the scanner observed at least one `knowledge:*` record.
- **scripts/verify/m012-p01-include-plugin.sh** — one additive case arm: canonical targets are now accepted under either `$ROOT/.orchestrator/*` (the P01 root) OR `$ROOT/knowledge/*` (the T02 MEM source root). FAIL message updated to reflect both valid roots.

## Verification

- `bash scripts/wiki/wiki-generate-stubs.sh --root $ROOT` — exit 0, `SUMMARY: wrote 985 stubs, 87 section indexes, removed 1072 stale files`, no stderr warnings beyond informational `STUB:`/`INDEX:` lines.
- `bash scripts/wiki/wiki-generate-nav.sh --root $ROOT` — exit 0, `SUMMARY: wrote nav block (1163 lines) with 13 milestone(s) and 0 archive(s)`.
- `bash scripts/verify/m012-p01-phase-suite.sh` — 9/9 gates PASS (wiki-self-contained, requirements-pinned, include-plugin, ssot, exclusion-policy, nav-structure, serve-smoke, index-placeholder, bash32-compat).
- MEM stub count: `find wiki/docs/knowledge -name 'MEM*.md' -not -name 'index.md'` = 25; `find knowledge -name 'MEM*.md' -type f` = 25. Counts match (11 patterns + 9 conventions + 5 lessons).
- MEM stub shape: every stub is 12 lines (well under the 25-line cap), contains exactly one `include-markdown` directive, no canonical body.
- Section indexes: all four ([`knowledge/index.md`](../../../../knowledge/index.md), [`knowledge/patterns/index.md`](../../../../knowledge/patterns/index.md), [`knowledge/conventions/index.md`](../../../../knowledge/conventions/index.md), [`knowledge/lessons/index.md`](../../../../knowledge/lessons/index.md)) exist and carry the `Auto-generated section index` probe comment.
- Nav placement: `Knowledge Entries:` appears at line 59 of `wiki/mkdocs.yml`, immediately after `- Knowledge: knowledge.md` (line 58) and before `- Milestone Summary: milestone-summary.md` (line 92). Every MEM stub path appears exactly once.
- Idempotency: running both generators twice produced byte-identical `wiki/docs/` tree hash (sha of sha-list stable across runs) and byte-identical `wiki/mkdocs.yml` (stable sha1).
- Bash 3.2 compat gate: PASS (0 violations across 14 scanned wiki/verify files).

## Patterns established

- **Per-category /tmp lists as associative-array replacement** — three fixed-name files (`KN_PATTERNS_LIST`, `KN_CONVENTIONS_LIST`, `KN_LESSONS_LIST`) replace a would-be `declare -A` map. The category list is fixed at three entries so an open-ended dictionary would be overkill; hard-coded filenames keep it Bash 3.2 safe and make the trap cleanup explicit.
- **Two-root canonical scheme** — `build_canonical` (`.orchestrator/`-rooted) and `build_canonical_repo_rel` (repo-rooted) are picked by the category-prefix branch in the main loop. Future source trees outside `.orchestrator/` add one `case` arm + one helper call, nothing else. This keeps the include-plugin gate's root allow-list as the single source of truth for "valid canonical roots".
- **Additive P01 gate extension** — when a P02 task changes the set of valid canonical roots, the right move is an additive arm in the relevant P01 gate (`include-plugin.sh` here), not a duplicate P02 gate. Keeps the "9/9 P01 gates still PASS" invariant meaningful rather than hollowed-out.
- **Scanner-record-driven emission discipline** — the nav subtree is gated on the presence of at least one `knowledge:*` record in the scanner output; if the `knowledge/` tree is ever empty the subtree disappears cleanly with no stray markers or empty groups. Same posture as P01's conditional `Archive` bucket.

## Deferred to T03+

- **wiki/README.md "Link resolution" section + "Running the link checker" subsection** (T04 per the plan).
- **scripts/diagnostics/wiki-link-check.sh** built-site link walker (later task authors the diagnostic that crawls the rendered `site/`).
- **scripts/verify/m012-p02-*.sh gate suite** (T05 authors the mechanical P02 gates — link-rewrite-config, mem-stubs, mem-anchors, link-check-contract, link-check-help, readme-policy, link-check-smoke, bash32-compat, d011-evaluation, phase-suite).
- **MEM-anchor probe artifact** (optional step 7 in plan) — `mkdocs` was not invoked locally in this execution; T04 will document the anchor-resolution policy conservatively (file-path MEM links are canonical; `KNOWLEDGE.md#mem-NNNN` anchors work only when the consolidated file carries a matching heading).
- **[.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md](../../../../milestones/M012/phases/P02/D011-EVALUATION.md)** — T05 records the D011 mechanical-evaluation outcome.
