---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M044"
---

# T02 — FR-4 scoped archive glob (preserve knowledge/archive/)

## Zero-context summary

Both `rebuild-index.sh:74` and `resolve-entries.sh:45` skip files via
`case "$file" in */archive/*) continue ;;` against the **absolute** path. A project
rooted under a path segment literally named `archive` (e.g.
`/Users/x/archive/proj/knowledge/...`) matches `*/archive/*` and skips EVERY file —
the index builds empty and the `:do` quick-inject is zero (B-4). The genuine intent
is to exclude only the `knowledge/archive/` cold-storage subtree (declared at
`rebuild-index.sh:6`, CON-4).

## Steps

1. `rebuild-index.sh:73-77` — compute the path relative to `$knowledge_dir`
   (`rel_knowledge="${file#$knowledge_dir/}"`) and match
   `case "$rel_knowledge" in archive/*|*/archive/*) continue ;; esac`. This matches
   `archive/foo.md` (top-level cold storage) and `cat/archive/foo.md` (nested) but
   NOT an `archive` segment ABOVE the project root.
2. `resolve-entries.sh:44-46` — same scoping against the path relative to
   `$root/knowledge/` (`rel_knowledge="${file#$root/knowledge/}"`;
   `case "$rel_knowledge" in archive/*|*/archive/*) continue ;; esac`).
3. Preserve the `rebuild-index.sh:6` docstring exclusion note (CON-4).

## Verifier

`tools/verify/m044-p03-t02-scoped-archive-glob.sh` — build a `mktemp -d` whose path
contains a segment named `archive` (e.g. `$TMP/archive-root/...`), seed
`knowledge/conventions/MEM900.md` (valid) + `knowledge/archive/MEM901.md` (genuine
cold storage) → run `rebuild-index.sh --root` → assert the index is non-empty,
MEM900 is indexed, and MEM901 (genuine `knowledge/archive/`) is excluded. Emits
`PASS:`/`FAIL:`.

## Done when

- `bash tools/verify/m044-p03-t02-scoped-archive-glob.sh` → `PASS:`
- An `archive`-rooted project indexes; `knowledge/archive/` stays excluded.
