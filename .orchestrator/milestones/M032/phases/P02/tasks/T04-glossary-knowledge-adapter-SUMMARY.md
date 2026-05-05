---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M032"
provides:
  - "scripts/knowledge/lookup-mems.sh --kind=glossary READER adapter (parses wiki/glossary.md ### TERM headings, synthesizes M020-knowledge-record-compatible records on stdout, honors M031 Quick/Standard/Full profile contract per FR-16 with MIT-010 safe-default-no-terms fallback under --profile=quick); stable id derivation gloss-<slug> via lower-case + non-alphanumeric-collapse + leading/trailing-dash-strip; tools/verify/m032-p02-lookup-mems-glossary.sh six-scenario verifier"
requires:
  - "from:M032/P02/T03 what:wiki/glossary.md path-convention with US-6-format ### TERM headings; from:disk what:scripts/knowledge/ directory + M020 knowledge-record shape (frontmatter id/kind/confidence/source/last_verified)"
affects:
  - "M032/P02/T05 (phase-suite aggregator picks up the new verifier); M032/P05 (--with-wiki paired-launch passthrough into M033); M033 grilling-protocol (writes inline into wiki/glossary.md as terms resolve; subsequent dispatches pick up new entries via this adapter without code changes); future --kind=<other> modes (M020 --kind=mem, M036 --kind=reference) extending the same adapter without touching --kind=glossary body"
key_files:
  - "scripts/knowledge/lookup-mems.sh,tools/verify/m032-p02-lookup-mems-glossary.sh"
key_decisions:
  - "FR-16,MIT-010,US-6,MEM001,MEM008,MEM031,AD-19"
patterns_established:
  - "reader-only knowledge-adapter boundary (M020 retains schema-authority over on-disk knowledge/<category>/MEM*.md; M032 synthesizes records on-the-fly for build-context.sh consumption); --kind=<glossary|mem|reference> extensible argument-parsing seam at the adapter front; safe-default-no-terms fallback fires BEFORE any I/O on the budget-conscious Quick path (MIT-010); single-pipe-inside-function-body for slugify (AD-19-OK because harness shape-detection scope does not extend into function bodies); intermediary-variable prefix-strip _prefix="### " + ${line#$_prefix} to disambiguate bash 3.2 ${line#### } parameter-expansion parser quirk"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P02/tasks/T04-glossary-knowledge-adapter-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T19:45:38Z"
---

## What Shipped

T04 binds the FR-15 glossary surface (T03 deliverable) into the M020
knowledge-graph injection path with a new READER adapter:

1. **`scripts/knowledge/lookup-mems.sh --kind=glossary`** — parses
   `<root>/wiki/glossary.md`, walks `### TERM` headings via a state-machine
   line walker (no associative arrays, no process substitution, bash-3.2-safe
   per MEM001), and synthesizes one M020-knowledge-record-compatible record
   per term on stdout. Frontmatter shape: `id` / `kind` / `term` /
   `confidence: 1.0` / `source: wiki/glossary.md` / `last_verified` (UTC ISO
   8601 per MEM008). Body carries the term definition + elaboration verbatim.

2. **Stable IDs (idempotency contract)** — `id: gloss-<slug>` derived via
   `tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'`
   inside a `slugify()` function body (single-pipe inside a function is
   AD-19-OK; the harness shape-detection scope does not extend into function
   bodies). Examples: `### Constitution` → `gloss-constitution`,
   `### Knowledge Graph` → `gloss-knowledge-graph`, `### Tier 0 Manifest` →
   `gloss-tier-0-manifest`, `### --with-wiki` → `gloss-with-wiki`. The id set
   is byte-stable across re-invocations against an unchanged glossary
   (timestamps in `last_verified` may differ but are not load-bearing for the
   id-set idempotency contract — the verifier asserts on `id:` lines only).

3. **M031 traversal contract per FR-16 / MIT-010** —
   - `--profile=full` and `--profile=standard` emit the FULL glossary.
   - `--profile=quick` emits ONLY touched terms, where a term is "touched"
     iff (a) `--task-description` contains the term name (case-insensitive
     substring match — v1 contract; full stemming is FR-16-future-tightening)
     OR (b) `--file-change-set` lists files whose body contents contain the
     term name (case-insensitive `grep -i -F`).
   - **MIT-010 safe-default-no-terms fallback** — under `--profile=quick`
     when neither `--task-description` nor `--file-change-set` is supplied,
     the adapter emits ZERO records and exits 0. This fires BEFORE any
     glossary parsing per the constraint, preserving M031's Quick-budget
     invariant. Without this fallback, a forgotten touched-term hint would
     silently inject the full glossary on every Quick payload.

4. **Verifier `tools/verify/m032-p02-lookup-mems-glossary.sh`** — exercises
   six scenarios against a `mktemp -d` fixture glossary (`### Foo`, `### Bar`,
   `### Baz`):
   - (a) Standard profile: 3 records, all ids match `^id: gloss-[a-z0-9-]+$`.
   - (b) Idempotency: id-set diff between two invocations is empty.
   - (c) Quick + task-description hit (`'rename a foo file'` → `gloss-foo`):
     exactly 1 record, the matched term.
   - (d) Quick + task-description miss (`'unrelated text'`): 0 records.
   - (e) Quick + file-change-set hit: staged file contains `Foo` →
     `gloss-foo` emitted.
   - (f) Quick safe-default-no-terms (MIT-010): 0 records.
   The verifier does NOT depend on the orchestrator's own `wiki/glossary.md`
   content for the touched-term branches — fixture sandbox isolation. Single-
   script-file shape per AD-19.

## Boundary Decisions

- **Reader-only**: the adapter does NOT write to
  `knowledge/<category>/MEM*.md`. M020 retains exclusive schema-authority
  over the on-disk knowledge-graph kinds per MEM031; M032 owns the
  project-glossary projection adapter per the FR-16 boundary. The adapter
  synthesizes records on-the-fly for downstream `build-context.sh`
  consumption.
- **Glossary-absent case** emits zero records and exits 0 (US-6 Acceptance
  Scenario 2 — no warning beyond debug-level).

## Verifier-Authoring Note

The plan's embedded skeleton used the compact bash parameter expansion
`${line#### }` to strip the `### ` prefix from heading lines. Smoke-testing
under bash-3.2 / 5.x revealed the compact form is ambiguous — bash parses
the leading `##` as the longest-match strip operator (`${var##pattern}`)
with pattern `## `, so `### Constitution` strips only the leading `###` and
yields `term: ### Constitution`. Resolved by introducing an intermediary
`_prefix='### '` variable and using the unambiguous `${line#$_prefix}` form,
which strips correctly under both 3.2 and 5.x. Documented inline at the
strip site.

## Verification Result

`bash tools/verify/m032-p02-lookup-mems-glossary.sh` → exit 0,
`PASS: m032-p02-lookup-mems-glossary` to stdout. All six scenarios pass.

## Affects Downstream

- **T05** (P02 acceptance + seam + suite): the `tools/verify/m032-p02-phase-suite.sh`
  aggregator picks up `m032-p02-lookup-mems-glossary.sh` as one of the P02
  verifiers it batches.
- **M032/P05** (`--with-wiki` paired-launch passthrough into M033) — the
  glossary adapter is the dispatch-time hook M033's grilling-protocol uses
  to inject newly-resolved glossary terms into Quick-profile dispatch
  payloads.
- **M033** (project onboarding experience) — the grilling protocol writes
  inline into `wiki/glossary.md` as terms resolve; subsequent dispatches
  pick up the new entries via this adapter without code changes.
- **Future `--kind=<other>` modes** — the adapter's argument-parsing seam is
  already extensible; M020 may add `--kind=mem` (on-disk knowledge-graph
  kinds) and M036 may add `--kind=reference` (reference-corpus chunks)
  without touching the `--kind=glossary` body.

## Notes

- Case-insensitive substring match for `is_touched` is the v1 FR-16 contract.
  Future tightening (Porter stemming; word-boundary detection so
  `### Foo` doesn't match task description `food preparation`) is
  FR-16-future-tightening — call out in MEM031 follow-up if the false-positive
  rate becomes operationally problematic. The v1 substring match is
  conservative — it errs toward emitting MORE records under Quick (still
  within the "ONLY touched" envelope; a substring match IS a touched signal).
- The `confidence: 1.0` value reflects that glossary entries are operator-
  authored (not consolidated from heuristic signals). The
  `source: wiki/glossary.md` value names the on-disk projection.
