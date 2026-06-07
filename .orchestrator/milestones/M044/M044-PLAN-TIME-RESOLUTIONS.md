---
schema_version: "1.0"
type: plan-time-resolutions
milestone: "M044"
created_at: "2026-06-07"
---

# M044 — Plan-Time Open-Question Resolutions

The spec (`specs/045-knowledge-activation-reliability/spec.md` § "Open Questions") defers
#Q-1…#Q-4 to plan-phase. This artifact records the **evidence-based dispositions** from a
dogfood-corpus scan + live-source audit run during roadmap, so each phase's `plan-phase`
consumes a resolved input rather than re-deriving. Each disposition names the phase that
formally owns it.

---

## #Q-1 (canonical-column-order) — RESOLVED: consumer-order wins; producer rewritten; forward-only

**Owner phase:** P02 (FR-1).

**Evidence (dogfood scan, 2026-06-07):**

| Store | Column order observed | Written by |
|---|---|---|
| `~/Sites/archive/.orchestrator/DECISIONS.md` (Source 2) | **consumer-order** `\| ID \| Decision \| Choice \| Scope \| When \| Rationale \|` — header line + data rows; `awk -F'\|'` `$5`=Scope(`arch`) / `$6`=When(`M001/P02`) ✓ | init-template seed (NOT `append-decision.sh`) |
| `./.orchestrator/DECISIONS.md` (this repo) | distinct hand-maintained 7-col variant `\| ID \| M/P \| category \| Decision \| Choice \| Rationale \| Revisable \|` (carries a `category` column neither canonical shape has) | hand-authored; not `append-decision.sh` output |
| `~/Sites/pbj-central-mono-repo/.orchestrator/DECISIONS.md` | custom `DR-###` namespaced section format, not the pipe-table at all | bespoke materials-intake artifact |
| `append-decision.sh:93` (the producer) | **producer-order** `\| ID \| When \| Scope \| Decision \| Choice \| Rationale \| Revisable \|` | `append-decision.sh` |

**Disposition:** The init-template header, the consumer comment's documented data-row
(`scope-filter.sh:343`), and the consumer `awk` indices (`:353-354`, `$5`/`$6`) **all already
agree on consumer-order**. Only `append-decision.sh:93` diverges. Per CON-6/AD-6 the oracle
asserts the observed awk indices (`$5`=scope / `$6`=when), which hold **only** under
consumer-order. Therefore:

- **Canonical written contract = consumer-order:** `| ID | Decision | Choice | Scope | When | Rationale | Revisable |`.
- **Loser rewritten = `append-decision.sh:93`** (producer flipped to emit consumer-order). The `scope-filter.sh:351` comment is corrected to describe the leading-empty-field reality (`$2`=ID … `$5`=Scope, `$6`=When); the awk at `:353-354` is already correct and stays.
- **Migration posture = forward-only.** Existing producer-order rows (if any were ever written by `append-decision.sh`) already never resolved (that *is* B-3), so they are already-broken data — not a regression a migration must preserve. New rows resolve correctly after the flip. An optional one-shot migration helper is **out of P0 scope** (note for P1). The init-seeded consumer-order stores (archive) already match the canonical contract and need no change.
- **Out of scope:** this repo's own 7-col `category`-bearing `DECISIONS.md` is hand-maintained, not `append-decision.sh` output; M044 does not touch it (flag only).

**Knowledge round-trip parallel (FR-2):** `append-knowledge.sh` ↔ `filter_knowledge` (`## K###`
shape) gets the same one-change-set reconciliation; `kf_filter_stream` is fixed to pass flat
`## K###` entries (no `---` frontmatter required).

---

## #Q-2 (stale-detection mechanism) — RESOLVED: mtime for P0; content-hash deferred to FR-10/P1

**Owner phase:** P01 (FR-5).

**Disposition:** P0 detects staleness via **mtime** — compare the index/db file mtime against
the newest `knowledge/**/*.md` mtime. Rationale: cheapest possible check (a `find -newer` /
`stat` comparison, no full corpus read), so the burning-path "rebuild-then-warn-if-still-bad"
(AD-3) adds no measurable mid-dispatch latency. Content-hash is the **eventual FR-10 contract**
and is explicitly P1/M040-track (spec Non-Goals: "freshness content-hash contract — P1"). P0
warns-on-stale; it does not auto-rebuild mid-dispatch (AD-3). The provenance header's
`index_age` field is derived from the mtime delta.

---

## #Q-3 (doctor reconciliation shape) — RESOLVED: reconcile (single surface); papercut absorbed, not superseded-by-deletion

**Owner phase:** P01 (FR-15).

**Evidence (live-source audit, 2026-06-07):**

- No `scripts/diagnostics/check-knowledge*.sh` (or any doctor knowledge-activation check) exists on disk. `grep -r 'DOCTOR:KNOWLEDGE|knowledge_gap|0-MEM'` over `scripts/` + `commands/doctor.md` returns only `scripts/verify/m020-*`/`m018-*` graph-query *verification tests* — none is a doctor surface. **No existing doctor test asserts an old/overlapping surface.**
- `papercut-doctor-knowledge-gap-surface.md` describes an **unshipped** `DOCTOR:KNOWLEDGE_GAP` check that surfaces *negative space* — per-section `tasks_dispatched > 0 AND mem_count == 0` density gaps. That is a **distinct 4th symptom** from M044's three *activation* symptoms (0-MEM-on-mature-project / vestigial-index / runtime-memory-divergence).

**Disposition:** **Reconcile.** M044/P01 builds the single consolidated knowledge-activation
doctor check (proposed file `scripts/diagnostics/check-knowledge-activation.sh`, emitting one
`DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail` line) covering its three activation symptoms.
Because the papercut's check does not yet exist, there is no second surface to delete; instead
the papercut is **annotated "reconciled into M044/FR-15"** with the binding rule that if/when the
negative-space density check ships it lands as an **additional symptom under the same
consolidated `DOCTOR:KNOWLEDGE_*` family**, never as a parallel doctor surface (CON-5 invariant
preserved forward). P01 plan-phase adds the one-line annotation to the papercut file.

---

## #Q-4 (provenance-header byte-contract version) — RESOLVED: pin a version field now

**Owner phase:** P01 (FR-5).

**Disposition:** **Pin `provenance_version: 1` in the header now.** Rationale: the provenance
header is a payload byte-contract consumed downstream (M034 decision-packet shape, M038
living-doc primitive, and the P1 `resolved-id` surface). A version field is one line of cheap
insurance that lets P1 add `resolved-id` / freshness fields without a breaking byte-contract
change. The P0 header shape is therefore:

```
knowledge_provenance:
  provenance_version: 1
  source: index | grep-fallback | degraded
  index_age: <seconds-or-"none">
  entries_considered: <N>
```

(Field ordering is fixed for byte-stability per CON-3; values are deterministic — no wall-clock
in the artifact body, `index_age` is a delta not a timestamp.)

---

## Summary

| # | Disposition | Owner phase |
|---|---|---|
| #Q-1 | Consumer-order is canonical; rewrite `append-decision.sh`; forward-only (no migration in P0) | P02 |
| #Q-2 | mtime for P0; content-hash deferred to FR-10/P1 | P01 |
| #Q-3 | Reconcile into one `DOCTOR:KNOWLEDGE_*` surface; annotate papercut "reconciled into M044/FR-15" | P01 |
| #Q-4 | Pin `provenance_version: 1` now | P01 |
