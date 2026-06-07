---
schema_version: "1.0"
type: audit-artifact
milestone: "M044"
phase: "P03"
requirement: "FR-3 (bounded audit) / SC-3"
created_at: "2026-06-07"
---

# M044/P03 — Bounded Unguarded-Command Audit (`rebuild-index.sh` + directly-sourced libs)

**Scope (bounded per FR-3 / Principle XIV):** `scripts/knowledge/rebuild-index.sh`
and the two libraries it sources directly — `scripts/knowledge/lib/index-utils.sh`
and `scripts/knowledge/lib/graph-db.sh`. The whole codebase is NOT swept. Every
command that can fail under `set -euo pipefail` is listed and marked **guarded**,
**fixed**, or **justify-and-track**.

All three files run (or are sourced into) `set -euo pipefail`. The failure mode of
concern: a command that returns non-zero on *normal data* (e.g. a `grep` miss),
which `pipefail` propagates and `set -e` turns into a whole-script abort.

## rebuild-index.sh

| Site | Command | Risk under set -e/pipefail | Disposition |
|---|---|---|---|
| `fm_field()` (~:40) | `sed … \| grep "^field:" \| head \| sed …` | grep-miss on an absent optional field → exit 1 | **guarded** — ends in `\|\| true` (pre-existing) |
| description grep (~:117) | `grep "^# ${id}:" … \| head \| sed` | grep-miss on a heading-less entry → exit 1 → **whole-rebuild abort (B-1)** | **FIXED (FR-3)** — captured into `heading_line` guarded with `\|\| true`; empty ⇒ skip-and-warn + `continue` |
| id extraction (~:93/:98) | `fm_field …` (already guarded) | — | guarded (inherits `fm_field` `\|\| true`) |
| `id`-empty case | new explicit guard | n/a | **FIXED (FR-3)** — `[ -z "$id" ]` ⇒ skip-and-warn + `continue` |
| scope_tags / edges parsing (:132–220) | `printf … \| sed \| tr`, `db_insert_*` inside `if [ -n … ]` guards | sed/tr/printf do not fail on this data; each block is `[ -n … ]`-gated | safe — no reproduced failure |
| `entries="$(echo … \| sort)"` (:242) | `sort` | `sort` does not fail on valid input | safe |
| `write_full_index` / `emit_spec_chunks_section` / `mv "$tmp_db"` (:246–254) | file writes + atomic `mv` | a real **DB/file write failure** SHOULD abort | **intentional abort** — this is the named catastrophic case (exit non-zero is correct) |

## index-utils.sh

| Site | Command | Risk | Disposition |
|---|---|---|---|
| `index_remove_entry` / `index_update_entry` (:96/:115) | `grep -v … > tmp` | grep-`-v` returns 1 only if *every* line is removed (all-match) | **guarded** — both end in `\|\| true` (pre-existing) |
| `index_has_entry` / `index_get_entry` (:132/:147) | `grep -q` / `grep` | grep-miss returns 1 | safe — these are leaf functions whose **return code is the contract** (caller branches on it); they are not in the rebuild path's abort surface |
| `next_entry_id` (:177/:197) | `grep -oE … \| sed` inside a `while`/`for` with `[ -n … ]` guards | grep-miss → empty `num`, guarded by `[ -n "$num" ]` | safe |
| `emit_spec_chunks_section` archive glob (:264) | `case "$f" in */archive/*)` against the **absolute** path | same B-4 false-match as `rebuild-index.sh:74` — an `archive`-rooted project would drop all spec chunks | **FIXED (FR-4)** — scoped to the `knowledge/`-relative path (third B-4 site, surfaced by this audit) |
| `emit_spec_chunks_section` field greps (:273/:278) | `sed -n … \| { grep \|\| true; } \| …` | grep-miss | **guarded** — `{ grep \|\| true; }` (pre-existing) |

## graph-db.sh

| Site | Command | Risk | Disposition |
|---|---|---|---|
| `db_query` (:44) | `sqlite3 … <<EOF \|\| rc=$?` | sqlite3 failure | **guarded** — captured into `rc`, surfaced as `DB_ERROR:` to stderr, returned to caller; a genuine DB write failure correctly propagates as the catastrophic case |
| `db_insert_*` numeric sanitizers (:134/:135) | `printf … \| grep -oE … \|\| printf '0.0'` | grep-miss | **guarded** — `\|\| printf` fallback (pre-existing) |
| `db_init` (:59) | `sqlite3 … <<'EOF_SCHEMA'` | schema-create failure | **intentional abort** — catastrophic DB failure should stop the rebuild |

## Summary

- **2 reproduced silent-failure bugs FIXED**: `rebuild-index.sh:117` description grep
  (B-1, the proven root incident) and `index-utils.sh:264` `emit_spec_chunks_section`
  archive glob (B-4, third site).
- **All other at-risk commands** are either already `|| true`-guarded, gated behind
  `[ -n … ]` existence checks, contract-return leaf functions, or the **intentional
  catastrophic-abort** surface (missing `knowledge/`, DB/file write failure) where a
  non-zero exit is the correct fail-loud behavior.
- No unbounded codebase sweep was performed (Principle XIV). The audit is closed at
  the rebuild script + its two directly-sourced libraries.

INDEXED/SKIPPED contract: `rebuild-index.sh` now emits a final
`INDEXED: N / SKIPPED: M [ids]` summary and exits 0 on per-entry skips; non-zero is
reserved for the catastrophic cases above.
