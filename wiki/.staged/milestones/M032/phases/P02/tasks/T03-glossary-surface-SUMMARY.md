---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M032"
provides:
  - "wiki/glossary.md path-convention with three populated US-6-format entries (Constitution, Knowledge Graph, Milestone); scripts/wiki/wiki-scan-sources.sh --include-glossary additive flag emitting top:glossary record as second top-level source after Constitution; scripts/wiki/wiki-generate-nav.sh HAS_GLOSSARY discovery flag + emit_leaf 1 'Glossary' 'glossary.md' between Constitution and Decisions; scripts/wiki/wiki-generate-stubs.sh top:glossary case-arm routing stub to wiki/docs/glossary.md via build_canonical_repo_rel; tools/verify/m032-p02-glossary-format-invariant.sh + tools/verify/m032-p02-glossary-scanner-and-nav.sh verifiers"
requires:
  - "from:M032/P02/T01 what:scripts/lifecycle/wiki-init.sh authoring consumer-side wiki/glossary.md stub via FR-15 path-convention; from:disk what:scripts/wiki/wiki-scan-sources.sh + scripts/wiki/wiki-generate-nav.sh + scripts/wiki/wiki-generate-stubs.sh + wiki/mkdocs.yml + wiki/docs/"
affects:
  - "M032/P02/T04+; M032/P03 (auto-vs-custom marker split per FR-14); M033 grilling-protocol (writes inline into wiki/glossary.md as terms resolve)"
key_files:
  - "wiki/glossary.md,scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-generate-stubs.sh,wiki/mkdocs.yml,wiki/docs/glossary.md,tools/verify/m032-p02-glossary-format-invariant.sh,tools/verify/m032-p02-glossary-scanner-and-nav.sh"
key_decisions:
  - "FR-15,FR-6,US-6,AD-19,MIT-002,CON-6"
patterns_established:
  - "top-level scanner record + nav-generator HAS_* flag + stub-generator case-arm trio for new top-level wiki sources; verifier-contract-over-verifier-skeleton (implement plan's contract wording when embedded verifier code conflicts); side-effect-free verifier via backup-and-trap-restore (EXIT/INT/TERM)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P02/tasks/T03-glossary-surface-PAYLOAD.md"
duration: "70m"
verification_result: "pass"
completed_at: "2026-05-04T19:39:07Z"
---

## What Shipped

T03 lands the [M033](../../../../../milestones/M033/index.md) grilling-protocol surface CON-6 mandates — the glossary
surface, in three parts:

1. **Path convention** — `wiki/glossary.md` at the orchestrator-repo root,
   populated with three alphabetized entries (Constitution, Knowledge Graph,
   Milestone) per the US-6 format invariant (`### TERM` heading, one-line
   definition, at-most-two-line elaboration). Pre-empts T01's `wiki-init.sh`
   self-application stub-author when the FR-6 self-application loop runs
   `wiki-init.sh --project-dir .` against the orchestrator.

2. **Scanner extension** — `scripts/wiki/wiki-scan-sources.sh` gains an
   additive `--include-glossary` flag (default-on per FR-15; opt out via
   `--no-include-glossary` or `--include-glossary=false`). When on, the
   scanner emits `top:glossary|wiki/glossary.md|<title>` as the second
   top-level source after Constitution. Pre-M032 invocations without the flag
   default to ON — additive default is "include glossary unless explicitly
   opted out."

3. **Nav generator extension** — `scripts/wiki/wiki-generate-nav.sh` learns
   the `top:glossary` category in both the discovery pass (HAS_GLOSSARY flag)
   and the emission pass. The Glossary leaf lands between Constitution and
   Decisions via `emit_leaf 1 "Glossary" "glossary.md"`. The
   `# >>> M012-P01 nav` marker shape is preserved verbatim — the auto/custom
   region split is P03's deliverable per FR-14.

The FR-6 self-application loop ran against the orchestrator: regenerated
`wiki/mkdocs.yml` carries `- Glossary: glossary.md` as the entry immediately
after `- Constitution: constitution.md` under the M012-P01 marker.

## Plan-Time Inaccuracy Resolved

The task plan's Notes section claimed `wiki-generate-stubs.sh` was
"path-agnostic and picks up new sources automatically." In practice the stub
generator's `map_record_to_stub_rel()` function carries a hardcoded mapping
table for `top:*` records — unknown categories fall through a `*)` arm that
emits the raw orch-rel path, which would route the glossary stub to
`wiki/docs/wiki/glossary.md` (wrong) and resolve canonical via
`build_canonical` against `.orchestrator/wiki/glossary.md` (file doesn't
exist). I added an explicit `top:glossary` case-arm above the fallback that
routes the stub to `wiki/docs/glossary.md` and resolves canonical via
`build_canonical_repo_rel` (the same helper introduced in M012/P02/T02 for
the `knowledge:*` category whose canonical lives at the repo root). Without
this fix the dogfood wiki at `:8000` would 404 on `/Glossary/`, breaking
FR-6 / MIT-002 dogfood-coherence for the duration of M032 + M033 paired
development.

## Verifiers

Two T03 verifiers under `tools/verify/`, both single-script-file shape per
AD-19, both Bash 3.2 compatible:

- `m032-p02-glossary-format-invariant.sh` — asserts (a) `wiki/glossary.md`
  exists, (b) >=3 `### TERM` headings, (c) terms alphabetized at file scope
  via `LC_ALL=C sort` + `diff -q`, (d) each heading has non-empty body within
  2 lines below (handles canonical "heading + blank line + body" markdown
  style).
- `m032-p02-glossary-scanner-and-nav.sh` — asserts (a) `--include-glossary`
  emits `wiki/glossary.md`, (b) `--no-include-glossary` does not, (c) after
  `wiki-generate-nav.sh --root .`, the entry immediately following the
  Constitution top-level leaf under the M012-P01 marker is the Glossary leaf,
  AND Glossary is followed by some other top-level entry (sandwich-between
  contract). Side-effect-free: backs up `wiki/mkdocs.yml` before the
  regeneration probe and restores from backup on every exit path
  (EXIT/INT/TERM trap).

Note on the task plan's verifier skeleton: it used `count==2` to find the
second top-level nav entry under the marker, which would actually catch
Constitution (the order is Home, Constitution, Glossary, ...). I implemented
the verifier per the task plan's *contract* wording — "after Constitution,
before everything else" — rather than the literal skeleton, by locating the
Constitution entry's position in the entry list and asserting the immediately
following entry is Glossary.

## Verification Results

- `bash tools/verify/m032-p02-glossary-format-invariant.sh` →
  `PASS: m032-p02-glossary-format-invariant`
- `bash tools/verify/m032-p02-glossary-scanner-and-nav.sh` →
  `PASS: m032-p02-glossary-scanner-and-nav`

## Patterns Established

- **Top-level scanner record + nav-generator HAS_* flag + stub-generator
  case-arm trio** — adding a new top-level wiki source requires touching all
  three scripts in lockstep. The `top:glossary` route here mirrors the
  existing `top:constitution` / `top:decisions` / `top:knowledge` /
  `top:milestone-summary` routes, plus the canonical-via-`build_canonical_repo_rel`
  pattern from M012/P02/T02's `knowledge:*` work for sources that live at the
  repo root rather than under `.orchestrator/`.
- **Verifier contract over verifier skeleton** — when a task plan's
  embedded verifier code conflicts with the contract wording, implement the
  contract. The skeleton is a hint, not a spec; the plan's prose constraints
  are the spec.
- **Side-effect-free verifier via backup-and-trap-restore** — a verifier
  that has to mutate disk state to probe an integration's effect (here, the
  nav regen) backs up the touched file before mutation and restores from
  backup on every exit path (EXIT, INT, TERM trap). Clean signal even when
  CTRL-C'd mid-run.

## Affects Downstream

- **P02/T04..T06** (or whichever subsequent P02 tasks consume the scanner
  surface) inherit the `top:glossary` category emission as a stable signal.
- **P03** consumes the glossary path-convention when authoring the Giscus
  comments-partial fill-ins (and inherits the auto/custom marker-region
  split work, which T03 explicitly did NOT do).
- **M033 grilling-protocol** writes inline into `wiki/glossary.md` as terms
  resolve in greenfield-with-materials and existing-codebase branches. The
  US-6 format invariant is now live and verifier-gated.
