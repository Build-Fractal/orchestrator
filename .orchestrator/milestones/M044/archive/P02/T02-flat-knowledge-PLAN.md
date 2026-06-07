---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M044"
---

# T02 — FR-2 flat `## K###` knowledge passes the filter

## Zero-context summary

The compression filter `kf_filter_stream` (`scripts/lib/knowledge-filter.sh`)
splits entries **only** on `---` frontmatter fences. A flat `## K###` knowledge
entry (no frontmatter — the `KNOWLEDGE.md` / `filter_knowledge` shape) is therefore
glued onto whatever frontmatter entry precedes it; if that frontmatter entry is
dropped (`status: superseded|experimental`), the flat entry is **silently dropped
with it** (verified live: a flat entry after a superseded MEM is swallowed — B-5).
Separately, the two wrapper empty-detections (`_bc_apply_knowledge_filter` in
`build-context.sh:874-881`, `_sh_apply_knowledge_filter` in
`section-handlers.sh:396-405`) decide "empty after filter" by counting `^---$`
fences — so a **flat-only** filtered stream (which has no `---`) is falsely
reported empty and replaced by the `(no qualifying knowledge entries)` sentinel,
even when valid flat entries are present.

## Steps

1. `scripts/lib/knowledge-filter.sh::kf_filter_stream` awk body — add flat-entry
   boundary detection: a `## ` heading at top level (`in_fm == 0`) flushes the
   current buffer (`decide(...)`) and starts a new entry, **except** the first
   `## ` heading immediately after a closing `---` fence, which is the current
   frontmatter entry's own heading and must stay bound to it (so superseded-entry
   drop still drops the heading+body). Track per-entry flags: `fm_seen` (this
   entry opened with frontmatter) and `heading_seen` (this entry already consumed
   its `## ` heading). Reset both on every new entry. Flat entries carry no
   `status:`, so `decide()` keeps them (status_val stays "").
2. `scripts/dispatch/build-context.sh::_bc_apply_knowledge_filter` — change the
   empty-detection from `grep -cE '^---$'` to also count flat headings
   (`grep -cE '^---$|^## '`); rename the local to reflect it counts entry markers,
   not just frontmatter fences. Keep the `(no qualifying knowledge entries)`
   sentinel only for a genuinely empty post-filter stream.
3. `scripts/dispatch/lib/section-handlers.sh::_sh_apply_knowledge_filter` — same
   empty-detection fix (the parallel consumer must not diverge).
4. Confirm `append-knowledge.sh` (`- **[scope]** [date] text`) ↔ `filter_knowledge`
   (`## K###`) agree — `filter_knowledge` parses `^## [A-Z][A-Za-z0-9]+:` headings;
   `append-knowledge.sh` appends a `- **[scope]**` bullet under a section. These
   are two shapes for two stores (flat consolidated `## K###` vs. the append
   bullet). Verify `filter_knowledge` resolves the `## K###` consolidated shape
   (the inject path); do NOT rewrite unless a true producer/consumer mismatch on
   the `## K###` path is reproduced.

## Verifier

`tools/verify/m044-p02-t02-flat-knowledge.sh` — lib-level fixture tests:
(a) mixed stream (superseded frontmatter entry + trailing flat `## K###`) →
the flat entry survives `kf_filter_stream`, only the superseded entry is dropped;
(b) pure-flat stream → passes through unchanged with `dropped_count=0`;
(c) the wrapper empty-detection greps (`^---$|^## `) are present in both
build-context.sh and section-handlers.sh. Emits `PASS:`/`FAIL:`.

## Done when

- `bash tools/verify/m044-p02-t02-flat-knowledge.sh` → `PASS:`
- A flat `## K###` entry survives a mixed-stream filter and a flat-only inject is
  never replaced by `(no qualifying knowledge entries)`.
