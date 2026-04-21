---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M012"
goal: "Teach the dogfood wiki to resolve internal cross-links — every markdown link that targets an in-scope `.orchestrator/**.md` artifact (including KNOWLEDGE MEM entries referenced as `KNOWLEDGE.md#mem-NNNN` or as `knowledge/**/MEM*.md` file paths) navigates to the rendered route on build; a Bash-3.2 link-check diagnostic walks the built site and exits non-zero on any broken in-scope link while enumerating out-of-scope targets; the resolution policy is documented in `wiki/README.md`; and the D011 mechanical evaluation (1 of 3 criteria shipped → M020 promoted) is recorded at phase close."
demo_sentence: "From the repo root, a developer runs `bash scripts/wiki/wiki-serve.sh --probe` (or `mkdocs build --strict -f wiki/mkdocs.yml` where mkdocs is installed) and the build emits zero broken-link warnings for in-scope targets; `bash scripts/diagnostics/wiki-link-check.sh --site wiki/site` (or the auto-detected build dir) exits 0 with `PASS: 0 broken in-scope links` plus an `OUT-OF-SCOPE:` enumeration of external targets; `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 after running every gate; `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` records the 1-of-3 result with explicit M020-promotion note."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P02 verification logic lives inside
     scripts/verify/m012-p02-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/mkdocs.yml` enables link rewriting for include-markdown pulls (canonical-path-relative links inside an included `.orchestrator/**.md` body resolve against the rendered stub route, not against the canonical source path) — established by the include plugin's `rewrite_relative_urls: true` option carried over from P01, asserted explicitly here as the load-bearing invariant for cross-link resolution.
  - Check: `bash scripts/verify/m012-p02-link-rewrite-config.sh`

- The wiki resolves `knowledge/**/MEM*.md` file-path references by generating a thin include stub under `wiki/docs/knowledge/<category>/<MEM###>.md` for every file in `knowledge/patterns/`, `knowledge/conventions/`, `knowledge/lessons/` — following the P01 SSOT pattern (≤ 25-line stub, single `include-markdown` directive, no body copy, AD-3).
  - Check: `bash scripts/verify/m012-p02-mem-stubs.sh`

- KNOWLEDGE anchor links of the form `KNOWLEDGE.md#mem-NNNN` (or `#MEM-NNNN`, case-insensitive per MkDocs' slug normalization) resolve to the rendered `.orchestrator/KNOWLEDGE.md` stub's heading anchor for that MEM entry — verified by scraping the rendered KNOWLEDGE HTML page for a heading with a matching anchor id (D011 criterion (a); AD-1).
  - Check: `bash scripts/verify/m012-p02-mem-anchors.sh`

- `scripts/diagnostics/wiki-link-check.sh` exists, is Bash 3.2 compatible, walks a built site directory (`wiki/site/` by default; `--site <dir>` override), extracts every internal `<a href="…">` link from every generated HTML file, classifies each link as in-scope (resolves to another rendered page or same-page anchor in the built site) vs out-of-scope (external URL, mailto, or path outside the rendered tree), emits `BROKEN: <source-page> -> <href>` for every broken in-scope link, `OUT-OF-SCOPE: <source-page> -> <href>` for every external target, `PASS:` or `FAIL:` summary on the last line, and exits 0 iff zero in-scope links are broken (FR-6, SC-6).
  - Check: `bash scripts/verify/m012-p02-link-check-contract.sh`

- `scripts/diagnostics/wiki-link-check.sh --help` prints a usage block naming the `--site`, `--root`, and `--strict` options plus the in-scope/out-of-scope classification rule, so operators can invoke it without reading the source.
  - Check: `bash scripts/verify/m012-p02-link-check-help.sh`

- `wiki/README.md` documents the link-resolution policy: what counts as in-scope (`.orchestrator/**.md`, `knowledge/**/MEM*.md`, same-page anchors), what counts as out-of-scope (source files like `scripts/**`, `tests/**`, `commands/**`, `templates/**`, `references/**`, `docs/**`, plus absolute URLs), how out-of-scope targets are handled (resolved to a GitHub source URL pattern OR flagged and enumerated in build output), how to invoke the checker locally, and how to wire it as a pre-deploy hook for P04 (FR-6, US4 AS-3).
  - Check: `bash scripts/verify/m012-p02-readme-policy.sh`

- An end-to-end link-resolution smoke works against a real build: when `mkdocs` is available, `wiki-serve.sh --probe` produces a throwaway `site/` directory and the link-checker, run against that directory, exits 0. When `mkdocs` is not installed, both gates emit `SKIP:` and exit 0 (Tier 1 acceptable; Tier 4 UAT covers the live build). No silent success — every SKIP is logged.
  - Check: `bash scripts/verify/m012-p02-link-check-smoke.sh`

- Every `.sh` file touched or created by P02 is Bash 3.2 compatible — no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(…)`/`>(…)` process substitution, no `&>` merge redirect (Constitution VIII, SC-11, MEM001). The scan target includes `scripts/diagnostics/wiki-link-check.sh` and every `scripts/verify/m012-p02-*.sh`.
  - Check: `bash scripts/verify/m012-p02-bash32-compat.sh`

- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` records the mechanical D011 outcome: a structured YAML-frontmatter + body note enumerating the three D011 criteria, marking (a) cross-refs ✓, (b) review-state ✗, (c) query surface ✗, and stating the "1 of 3 → M020 promoted" conclusion with pointers to `.orchestrator/DECISIONS.md` D011 and `.orchestrator/milestones/M012/M012-CONTEXT.md` AD-1. Emitted as a first-class artifact this phase is accountable for; not a summary-only side note (cross-cutting-concern bullet in M012-ROADMAP.md).
  - Check: `bash scripts/verify/m012-p02-d011-evaluation.sh`

- `bash scripts/verify/m012-p02-phase-suite.sh` orchestrates every P02 gate (the nine gates above) and exits 0 only when every gate exits 0; prints one `GATE: <name> PASS|FAIL` line per gate to stdout and a `SUMMARY: <passed>/<total> gates passed` line to stderr.
  - Check: `bash scripts/verify/m012-p02-phase-suite.sh`

### Artifacts

- `wiki/mkdocs.yml` (min 50 lines, contains "rewrite_relative_urls") — P01-authored base, P02 asserts explicit link-rewriting settings in include-plugin block and (if added) `markdown_extensions` adjustments. File line floor only nudges up from P01's min; semantic guard is the `rewrite_relative_urls: true` presence.
- `wiki/docs/knowledge/patterns/MEM001.md` (min 8 lines, contains "include-markdown") — representative MEM stub produced by the generator. The generator writes one stub per `knowledge/**/MEM*.md`; this specific stub is the canary used by Artifacts assertions.
- `wiki/docs/knowledge/patterns/MEM002.md` (min 8 lines, contains "include-markdown") — second canary stub (asserts the generator iterated past the first entry).
- `wiki/docs/knowledge/patterns/index.md` (min 4 lines, contains "Auto-generated section index") — per-category section index emitted by the extended stub generator.
- `wiki/docs/knowledge/conventions/index.md` (min 4 lines, contains "Auto-generated section index") — per-category section index.
- `wiki/docs/knowledge/lessons/index.md` (min 4 lines, contains "Auto-generated section index") — per-category section index.
- `wiki/docs/knowledge/index.md` (min 4 lines, contains "Auto-generated section index") — top-level `knowledge/` section index emitted by the extended stub generator.
- `scripts/wiki/wiki-scan-sources.sh` (min 60 lines, contains "knowledge/") — extended from P01 to additionally enumerate `knowledge/**/MEM*.md` records with a `knowledge:<category>` category prefix.
- `scripts/wiki/wiki-generate-stubs.sh` (min 100 lines, contains "knowledge/") — extended to consume `knowledge:<category>` scanner records and write `wiki/docs/knowledge/<category>/<MEM###>.md` stubs plus section indexes.
- `scripts/wiki/wiki-generate-nav.sh` (min 70 lines, contains "Knowledge Entries") — extended to emit a per-milestone-group-adjacent `Knowledge Entries` nav subtree grouping MEM stubs by category.
- `scripts/diagnostics/wiki-link-check.sh` (min 180 lines, contains "BROKEN:") — the in-repo link-check diagnostic; walks built-site HTML, classifies links, emits structured output.
- `wiki/README.md` (min 80 lines, contains "Link resolution") — extended operator guide: install/preview section retained from P01, plus a dedicated "Link resolution" section with in-scope vs out-of-scope rules and a "Running the link checker" subsection.
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` (min 30 lines, contains "M020 promoted") — structured D011 mechanical-evaluation record.
- `scripts/verify/m012-p02-link-rewrite-config.sh` (min 20 lines, contains "rewrite_relative_urls")
- `scripts/verify/m012-p02-mem-stubs.sh` (min 40 lines, contains "knowledge/")
- `scripts/verify/m012-p02-mem-anchors.sh` (min 40 lines, contains "mem-")
- `scripts/verify/m012-p02-link-check-contract.sh` (min 50 lines, contains "BROKEN:")
- `scripts/verify/m012-p02-link-check-help.sh` (min 20 lines, contains "--help")
- `scripts/verify/m012-p02-readme-policy.sh` (min 30 lines, contains "Link resolution")
- `scripts/verify/m012-p02-link-check-smoke.sh` (min 40 lines, contains "mkdocs")
- `scripts/verify/m012-p02-bash32-compat.sh` (min 40 lines, contains "declare -A")
- `scripts/verify/m012-p02-d011-evaluation.sh` (min 30 lines, contains "M020 promoted")
- `scripts/verify/m012-p02-phase-suite.sh` (min 40 lines, contains "m012-p02")

### Key Links

- `scripts/diagnostics/wiki-link-check.sh` → `wiki/site` (the default site directory the checker walks; the string must appear as a default value / doc reference)
- `scripts/wiki/wiki-generate-stubs.sh` → `knowledge/` (extended stub generator consumes knowledge entries)
- `scripts/wiki/wiki-generate-nav.sh` → `scripts/wiki/wiki-scan-sources.sh` (nav generator consumes the same extended scanner output)
- `wiki/mkdocs.yml` → `rewrite_relative_urls` (include-plugin block carries the option that makes link rewriting load-bearing)
- `wiki/README.md` → `wiki-link-check.sh` (operator guide references the checker by name)
- `wiki/README.md` → `Link resolution` (documented policy section)
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` → `DECISIONS.md` (evaluation cites the upstream decision)
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` → `M012-CONTEXT.md` (evaluation cites AD-1)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-link-rewrite-config.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-mem-stubs.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-mem-anchors.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-link-check-contract.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-link-check-help.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-readme-policy.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-link-check-smoke.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-bash32-compat.sh` (orchestrated gate)
- `scripts/verify/m012-p02-phase-suite.sh` → `scripts/verify/m012-p02-d011-evaluation.sh` (orchestrated gate)

## Tasks

### T01: Link-rewriting config + wiki-scan extension for `knowledge/` source tree

See `.orchestrator/milestones/M012/phases/P02/tasks/T01-PLAN.md`.

### T02: MEM stub generation + nav integration + anchor resolution verification

See `.orchestrator/milestones/M012/phases/P02/tasks/T02-PLAN.md`.

### T03: `scripts/diagnostics/wiki-link-check.sh` — built-site link walker

See `.orchestrator/milestones/M012/phases/P02/tasks/T03-PLAN.md`.

### T04: `wiki/README.md` link-resolution policy + `mkdocs build --strict` alignment

See `.orchestrator/milestones/M012/phases/P02/tasks/T04-PLAN.md`.

### T05: P02 verification suite + D011-EVALUATION.md + phase-suite orchestrator

See `.orchestrator/milestones/M012/phases/P02/tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05
```

Strict linear chain. T01 extends the scanner (the upstream source of truth for what the generators iterate over) and flips on the link-rewriting config — every downstream output depends on the scanner's extended record set. T02 teaches the stub generator and nav generator to emit `knowledge/**/MEM*.md` stubs + a Knowledge Entries nav subtree and verifies MEM anchors resolve; without T01 the scanner would not surface the records. T03 ships the in-repo link-check diagnostic; it needs the full stub+nav set (from T01+T02) as its in-scope target space. T04 writes the operator-facing policy doc and the `mkdocs build --strict` alignment note; this requires the checker's contract (T03) to be stable. T05 wires the verification suite (which assertions on T01–T04 outputs) plus the D011-EVALUATION.md record.

## Files Likely Touched

- `wiki/mkdocs.yml` (modify — assert `rewrite_relative_urls: true` on include-plugin; add `Knowledge Entries` nav subtree via T02's extended nav generator)
- `wiki/README.md` (modify — add "Link resolution" section + "Running the link checker" subsection)
- `scripts/wiki/wiki-scan-sources.sh` (modify — add `knowledge/**/MEM*.md` enumeration with `knowledge:<category>` record category)
- `scripts/wiki/wiki-generate-stubs.sh` (modify — consume `knowledge:<category>` records; emit `wiki/docs/knowledge/<category>/<MEM###>.md` stubs + section indexes)
- `scripts/wiki/wiki-generate-nav.sh` (modify — emit `Knowledge Entries` subtree with per-category subgroups)
- `wiki/docs/knowledge/` (create — directory tree of generated stubs and section indexes; not hand-edited)
- `wiki/docs/knowledge/index.md` (create — top-level section index)
- `wiki/docs/knowledge/patterns/index.md` (create — per-category section index)
- `wiki/docs/knowledge/conventions/index.md` (create — per-category section index)
- `wiki/docs/knowledge/lessons/index.md` (create — per-category section index)
- `wiki/docs/knowledge/patterns/MEM*.md` (create — thin include stubs, one per `knowledge/patterns/MEM*.md`)
- `wiki/docs/knowledge/conventions/MEM*.md` (create — thin include stubs, one per `knowledge/conventions/MEM*.md`)
- `wiki/docs/knowledge/lessons/MEM*.md` (create — thin include stubs, one per `knowledge/lessons/MEM*.md`)
- `scripts/diagnostics/wiki-link-check.sh` (create — Bash 3.2 built-site link walker)
- `scripts/verify/m012-p02-link-rewrite-config.sh` (create)
- `scripts/verify/m012-p02-mem-stubs.sh` (create)
- `scripts/verify/m012-p02-mem-anchors.sh` (create)
- `scripts/verify/m012-p02-link-check-contract.sh` (create)
- `scripts/verify/m012-p02-link-check-help.sh` (create)
- `scripts/verify/m012-p02-readme-policy.sh` (create)
- `scripts/verify/m012-p02-link-check-smoke.sh` (create)
- `scripts/verify/m012-p02-bash32-compat.sh` (create)
- `scripts/verify/m012-p02-d011-evaluation.sh` (create)
- `scripts/verify/m012-p02-phase-suite.sh` (create)
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` (create — D011 mechanical-evaluation record)
