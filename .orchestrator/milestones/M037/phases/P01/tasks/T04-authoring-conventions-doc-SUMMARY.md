---
schema_version: "1.0"
type: task-summary
task: "T04"
phase: "P01"
milestone: "M037"
---

# T04 — Authoring conventions doc + dispatch payload-guidance reference

## What changed

- **`references/authoring-conventions.md`** — new 278-line authoring reference
  covering (a) DR / BG / AN / MEM / Q-### code conventions with the new
  heading-shape and body-chip pattern (verbatim D003 before/after pair as the
  exemplar), the framework-owned `scripts/verify/decisions-shape-lint.sh`
  contract surface, and "When to use each prefix" guidance grounded in real
  repo usage (DR/MEM/Q) plus parallel-shape language for BG/AN; and (b)
  already-enabled mkdocs-material features authors should leverage —
  Mermaid diagrams via `pymdownx.superfences`, content reuse via
  `pymdownx.snippets`, admonition variants, inline status chips via
  `attr_list`, content tabs via `pymdownx.tabbed`, plus T05's incoming
  `pymdownx.details` (collapsible admonitions), `pymdownx.tasklist`
  (checkboxes), and `navigation.prune` polish-bundle additions.

- **`commands/dispatch.md`** — new `## Payload Guidance` section inserted
  before `## Gotchas`, referencing `references/authoring-conventions.md` as
  the authority for code-anchored artifact authoring (DR-CODE-NNN, MEM-NNN,
  BG-CODE-NNN, AN-CODE-NNN, Q-NNN) and naming the
  `scripts/verify/decisions-shape-lint.sh` contract surface. Future
  LLM-dispatched task agents emitting decision-log / knowledge / spec prose
  will inherit the conventions through the dispatch knowledge-inject.

- **`wiki/docs/stylesheets/code-chips.css`** (Surface E Option B) — new
  ~33-line plugin-free CSS file styling `.code-chip-row` (block container
  with bottom margin) and `.md-tag--decision`/`--background`/`--analysis`/
  `--knowledge`/`--question` (pill backgrounds, borders, padding,
  border-radius). Theme-aware via mkdocs-material CSS variables
  (`--md-default-fg-color*`, `--md-code-font-family`).

- **`wiki/mkdocs.yml`** — new `extra_css:` block (sentinel-bracketed
  `# >>> M037-P01-T04 extra_css ... # <<< M037-P01-T04 extra_css end`)
  pointing at `stylesheets/code-chips.css`. Inserted before the existing
  `# >>> M012-P03 extra (Giscus wiring — T01)` block so the two `extra*:`
  declarations sit side-by-side at the top of mkdocs.yml's tail-section.
  No plugin additions; CON-1 plugin discipline preserved.

- **`tools/verify/m037-p01-authoring-conventions-doc.sh`** — new Truth #8
  verifier (single-script-file per AD-19, bash 3.2 + POSIX sh per MEM001).
  Five checks: file exists, line count ≥ 100, all four required substrings
  present (`DR-CODE-NNN`, `navigation.prune`, `pymdownx.details`, `Mermaid`),
  `## Code Conventions` section header, `## Mkdocs-Material Features`
  section header. Emits `PASS: m037-p01-authoring-conventions-doc (5/5)` on
  full pass.

- **`tools/verify/m037-p01-dispatch-references-conventions.sh`** — new
  Truth #9 verifier (single-script-file, bash 3.2 + POSIX sh). Asserts
  `commands/dispatch.md` contains the literal string
  `references/authoring-conventions.md`. Emits
  `PASS: m037-p01-dispatch-references-conventions` on pass.

## Surface E decision (folded-in scope from T03)

**Option B chosen** — ship a small `wiki/docs/stylesheets/code-chips.css`
(~33 lines) defining `.code-chip-row` and `.md-tag--decision`/`--background`/
`--analysis`/`--knowledge`/`--question` pill styling, referenced via
`extra_css:` in `wiki/mkdocs.yml`.

**Rationale**:
- Plugin-free — no entanglement with T05's in-flight plugin-list additions
  (T05 ships `pymdownx.details` + `pymdownx.tasklist` in `markdown_extensions:`,
  not `plugins:`, but the principle of avoiding cross-task plugin coordination
  applies).
- CON-1 plugin discipline preserved (no Material `tags:` plugin, no
  auto-generated `tags.md` index page).
- Stays inside T04's surface — T06 (yaml-merge-and-install-emission) only
  needs to learn about the new CSS file (one extra entry in the
  install-template payload), not a new plugin in mkdocs.yml.
- Theme-aware via mkdocs-material CSS variables; respects light/dark mode
  without per-mode overrides.
- Reversible — if a future milestone adopts Material `tags:` plugin, the
  `code-chips.css` can be removed and the chip classes (`md-tag md-tag-icon
  md-tag--decision`) pick up Material's built-in pill styling automatically.

**T06 coordination note**: T06's install-template payload needs to ship
`wiki/docs/stylesheets/code-chips.css` alongside the other wiki bundle
files, and the install-template `mkdocs.yml` emit path needs to carry the
`extra_css: ['stylesheets/code-chips.css']` declaration (or merge it into
existing template-side `extra_css:` if any). The sentinel-bracketed shape
in this repo's `wiki/mkdocs.yml` mirrors the `# >>> M012-P03 extra` /
`# <<< M012-P03 extra end` convention used elsewhere — T06 can follow the
same pattern in install-template emission.

## Verifier output

```
$ bash tools/verify/m037-p01-authoring-conventions-doc.sh
CHECK PASS: references/authoring-conventions.md exists
CHECK PASS: line count 278 >= 100
CHECK PASS: all four required substrings present (DR-CODE-NNN, navigation.prune, pymdownx.details, Mermaid)
CHECK PASS: contains '## Code Conventions' section header
CHECK PASS: contains '## Mkdocs-Material Features' section header
SUMMARY: m037-p01-authoring-conventions-doc pass=5 fail=0
PASS: m037-p01-authoring-conventions-doc (5/5)

$ bash tools/verify/m037-p01-dispatch-references-conventions.sh
PASS: m037-p01-dispatch-references-conventions
```

T03's framework-owned shape-lint also re-run as a regression check —
unchanged from T03 close (28 entries, all anchors unique):

```
$ bash scripts/verify/decisions-shape-lint.sh
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (28 entries, all anchors unique)
```

## Must-haves (from T04 plan)

- [x] Truth #8 — `references/authoring-conventions.md` covers DR/BG/AN/MEM/Q
      codes + already-enabled features.
- [x] Truth #9 — `commands/dispatch.md` references the new convention doc.
- [x] Phase artifact: `references/authoring-conventions.md` (278 lines ≥ 100,
      contains "DR-CODE-NNN", "navigation.prune", "pymdownx.details", "Mermaid").
- [x] Phase Key Links: `commands/dispatch.md` →
      `references/authoring-conventions.md`; `references/authoring-conventions.md`
      → `.orchestrator/DECISIONS.md`.

## Notes

- The `pymdownx.details` and `pymdownx.tasklist` references in the doc are
  correctly forward-shaped for T05's polish bundle. Until T05 ships, the
  `???` collapsible-admonition syntax falls back to plain text in the
  rendered wiki; the doc's prose explicitly notes this fallback so authors
  reading the doc before T05 lands aren't confused.
- The "When to use each prefix" subsection grounds DR / MEM / Q in real
  repo usage (citing `DECISIONS.md` D003, `MEM001`, `MEM029`, and the `#Q-N`
  convention seen in proposals). BG-CODE-NNN and AN-CODE-NNN are
  parallel-shape forward-looking — the plan's prefix scheme names them but
  the repo has no entries yet. Doc describes their intended use without
  inventing fake examples.
- T05 remains parallel-eligible (no overlap with this task's surface).
- T06 (yaml-merge-and-install-emission) is unblocked by this task close.
  T06 must coordinate: ship `code-chips.css` in install-template payload +
  emit `extra_css:` declaration in install-template `mkdocs.yml`.
