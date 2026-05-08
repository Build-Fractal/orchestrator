---
schema_version: "1.0"
type: task-summary
task: "T03"
phase: "P01"
milestone: "M037"
---

# T03 — DR-### heading-shape pivot for `.orchestrator/DECISIONS.md` + framework-owned shape-lint verifier

## Pre-restructure inbound permalink survey

Pre-restructure grep across `*.md` files in the repo for `#d[0-9]+` inbound
references found **9 total matches**, distributed as follows:

| Source location | Count | Shape | Notes |
|---|---|---|---|
| `.orchestrator/milestones/M037/phases/P01/tasks/T03-decisions-shape-pivot-PLAN.md` | 3 | `#d001` (illustrative) | M037 internal; excluded by acceptance test scope per task plan. |
| `specs/022-spec-wiki/spec.md` line 83 | 1 | `#d009` (live cross-reference) | **Real inbound link**; rewritten to `#dr-code-009` in this commit. |
| `specs/038-wiki-team-feedback-ready/conversus/red-advocate/review.md` | 3 | `#d004`, `#d004`, `#d009` (illustrative discussion) | M037-spec deliberation; `#d004`/`#d009` resolve to live D004/D009 entries after the migration. |
| `specs/038-wiki-team-feedback-ready/conversus/blue-advocate/cross-reviews/red-advocate.md` | 1 | `#d004` (illustrative) | M037-spec deliberation. |
| `specs/038-wiki-team-feedback-ready/conversus/blue-advocate/revision.md` | 1 | `#d004` (illustrative) | M037-spec deliberation. |

Uppercase `#D[0-9]+` matches: **0**.
Already-correct `#dr-code-[0-9]+` matches outside DECISIONS.md: **5**, all inside
`.orchestrator/milestones/M037/phases/P01/tasks/`.

**Surface B threshold check**: 9 < 50 — no blast-radius surface; rewrite proceeds
as planned.

## What changed

- **`.orchestrator/DECISIONS.md`** — restructured from a 7-column markdown table
  (28 `| Dnnn |` rows) to 28 `### Title { #dr-code-NNN }` heading entries. Each
  entry carries a body chip (`<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-NNN</span>`
  marked with `{: .code-chip-row }` via `attr_list`), a metadata bullet block
  (When / Scope / Choice / Revisable), the verbatim Rationale paragraph, and a
  trailing `---` rule. The Choice and Rationale columns are preserved
  byte-for-byte from the source table (the rationale prose carries the load).
- **`specs/022-spec-wiki/spec.md`** — single inbound permalink rewrite,
  `#d009` → `#dr-code-009` (line 83, US-2 Independent Test example).
- **`scripts/verify/decisions-shape-lint.sh`** — new framework-owned shape-lint
  verifier (single-script-file per AD-19, bash 3.2 + POSIX sh per MEM001, 105
  lines). Asserts the heading-shape regex, refuses any surviving legacy table
  row, enforces anchor uniqueness. Default target `.orchestrator/DECISIONS.md`,
  accepts an override path argument.
- **`tools/verify/m037-p01-decisions-shape.sh`** — new phase-suite-callable
  wrapper invoking the framework verifier against this repo's DECISIONS.md.
- **`tests/m037-acceptance/p01-dr-heading-shape.sh`** — new SC-3 acceptance
  test. Invokes the shape-lint verifier (must exit 0); then walks every inbound
  `#d[0-9]+` and `#dr-code-[0-9]+` reference in the repo (excluding
  `.orchestrator/milestones/M037/` and DECISIONS.md itself), normalises legacy
  shape to `dr-code-NNN`, and asserts the cited anchor exists in DECISIONS.md.

## Verification

```
$ bash scripts/verify/decisions-shape-lint.sh .orchestrator/DECISIONS.md
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (28 entries, all anchors unique)
$ echo $?
0

$ bash tests/m037-acceptance/p01-dr-heading-shape.sh
PASS: decisions-shape-lint /Users/brettkellgren/Sites/orchestrator/.orchestrator/DECISIONS.md (28 entries, all anchors unique)
PASS: p01-dr-heading-shape (28 entries, 8 inbound permalinks resolved)
$ echo $?
0
```

Both gates green. The 8-inbound-resolved count comprises: 1 live cross-reference
in `specs/022-spec-wiki/spec.md` (post-rewrite) + 7 illustrative references
inside `specs/038-wiki-team-feedback-ready/conversus/**` discussion documents.
All resolve to existing D004/D009 anchors after migration.

## Surfaces / decisions

- **Surface A — actual inbound shape distribution**: 9 total `#d[0-9]+` matches,
  exclusively lowercase auto-derived shape; 0 uppercase `#D[0-9]+`; 0 mixed
  forms. Distribution above. No surface-A escalation.
- **Surface B — blast radius (>50 inbound refs)**: not triggered (9 < 50).
- **Surface C — `attr_list` collision check**: `wiki/mkdocs.yml` line 40
  enables `attr_list`, line 43 enables `md_in_html`. No `extra_css` declaration
  in `mkdocs.yml`; no project-owned stylesheet files at
  `wiki/docs/stylesheets/` or `wiki/docs/extra/`. No collision risk.
- **Surface D — un-mappable rows**: zero. All 28 rows had non-empty Decision
  cells; titles derived via 16 hand-written overrides (in `/tmp/build_decisions.py`
  TITLE_OVERRIDES) for rows whose Decision cell was either question-shaped
  (D026/D027) or too long for a scannable heading (D007/D008/D009/D010/D015/
  D016/D019/D020/D021/D022/D023/D024/D025/D028); the remaining 12 used the
  Decision cell verbatim with `**emphasis**` and `\`backticks\`` stripped to
  keep the heading scannable.
- **Surface E — `code-chip-row` CSS class**: this class is **not defined**
  anywhere in the repo today (no `wiki/docs/stylesheets/`, no `extra_css`
  declaration in `mkdocs.yml`, no installer-staged CSS payload). The body chip
  uses Material's built-in `md-tag md-tag-icon md-tag--decision` class set
  which is **only styled when the Material `tags:` plugin is enabled** —
  `mkdocs.yml` enables `search` only (line 33). The chip therefore renders as
  plain inline text (with class attributes preserved in HTML, but no Material
  tag-pill styling) until either (a) `tags:` plugin is added to
  `mkdocs.yml`, or (b) a small `wiki/docs/stylesheets/code-chips.css` file
  defines `.code-chip-row` + `.md-tag--decision`. **This is acceptable for
  T03**: the markup is structurally correct, the permalink anchors are
  load-bearing (and verified by the lint), and the chip styling is decorative.
  Captured here as a follow-up for T04 (authoring conventions doc) which is the
  natural home for either the plugin enablement or the small CSS file
  decision. **No silent drop**: if the operator wants the pill rendering live
  before T04 lands, the cheapest path is adding `tags` to the `plugins:`
  list and `tags_extra_files: false` to disable the auto-tag-page generation.

- **28-rows-actual vs ~150-rows-brief scope delta**: the M037 brief (proposal
  `.orchestrator/proposals/M037-wiki-team-feedback-ready.md`) and the M037-ROADMAP
  prose forecast "~150 row entries". The actual file at task-execution time
  contained 28 rows (D001–D028). The T03 plan already captured this delta in
  its Description block (~150 → 28). No downstream-task scope adjustment
  needed; the verifier and acceptance-test contracts are scope-agnostic.

## Notes for downstream

- **T04 (authoring conventions doc)** should reference the framework-owned
  verifier at `scripts/verify/decisions-shape-lint.sh` as the contract surface
  for the heading-shape rule. The verifier now ships in the install bundle by
  living under `scripts/verify/`. If T04 wants to recommend a `.code-chip-row`
  rendering (the Surface-E follow-up above), the cheapest paths are:
    1. enable Material's `tags` plugin in `mkdocs.yml` so
       `md-tag*` classes pick up Material's pill styling, OR
    2. add a 6-line `wiki/docs/stylesheets/code-chips.css` and reference it via
       `extra_css:` — keeps the chip plugin-free and CON-1-compliant.
- **T05 (`mkdocs.yml` template additions)** does NOT need to know about
  DECISIONS.md heading shape — the wiki render of decisions.md is governed by
  whatever T05 lands in `mkdocs.yml` `nav:` and `toc:` config; the `attr_list`
  block-level anchor declarations are already enabled.
- **Future verifier consumers**: the heading-shape regex
  `^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$` reserves four sibling code
  prefixes (`bg-`, `an-`, `mem-`, `q-`) for adjacent registers; if the
  authoring-conventions doc or future milestones promote any of those into
  permalink-stable surfaces, the lint will accept them without modification.
