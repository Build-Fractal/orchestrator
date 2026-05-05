# m033 PBJ Materials Fixture

This fixture is a synthetic-PBJ-shape document set used by the M033
acceptance battery. It carries an intentionally-curated set of
inconsistencies so that downstream verifiers have a stable, oracle-
audited target to compare against.

## Purpose

This fixture is the deterministic input for FR-23 / SC-4 / P04's
materials-intake drift detector. The four PBJ-shape documents
(PRODUCT-BRIEF.md, MVP-PLAN.md, DECISIONS.md, MILESTONE-AUDIT.md)
contain exactly five inconsistencies, designed so that P04's
detector can run against the fixture and have its output compared
line-by-line against the ground-truth oracle in this README.

Frontloading the fixture in P01 (rather than P04) is mandated by
FR-23: the fixture must exist before P04's `p04-materials-intake.sh`
can run, and authoring the inconsistencies in P01 means P02-P04
implementations have a stable target to develop against.

The fixture is materials-only (no `src/`, no `.git/`) so that when it
is copied into a probe target, FR-2's rule-2 detection
(`greenfield-with-materials`) fires cleanly under P01's SC-1 branch-
detection acceptance.

## Inconsistencies (Ground-Truth Oracle)

The fixture contains exactly five inconsistencies. Each is named
below by category (from the closed CON-4 enum
`id-misalignment | scheme-contradiction | orphan-reference`),
affected document pair, and a one-to-two-sentence description.

1. **id-misalignment** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF references `US-3` in its scope statement, but MVP-PLAN defines only `US-1` and `US-2`.
2. **scheme-contradiction** — `DECISIONS.md ↔ MVP-PLAN.md`. DECISIONS records `DR-002: Deploy via Vercel`; MVP-PLAN names `Cloudflare Workers` as deployment target.
3. **orphan-reference** — `MILESTONE-AUDIT.md`. Mentions milestone `M-3 (Authentication)` which no other document defines or scopes.
4. **id-misalignment** — `PRODUCT-BRIEF.md ↔ DECISIONS.md`. DECISIONS defines `DR-003` but no upstream document cites it.
5. **scheme-contradiction** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF says `MVP timeline: 4 weeks`; MVP-PLAN says `MVP timeline: 6 weeks`.

The 5 entries cover all three CON-4 categories with at least one
instance each, plus 2 additional instances chosen to stress the
deterministic detector across both id-misalignment (US- and DR-
identifiers) and scheme-contradiction (numeric and named-target)
shapes.

## Determinism Guarantee

This fixture honours FR-23's clause: same fixture + same operator
answers produces same detection output across platforms and operator
identities. The fixture content is text-only, with no timestamps, no
machine-name embeddings, no `$(date)` expansions, no platform-
specific paths, and no random tokens. Re-creating the fixture from
scratch on a different machine MUST produce byte-identical content.

This guarantee is what makes the README oracle a reliable comparison
target — P04's verifier can assume that any drift between the
fixture and the oracle is a real bug, not a platform-induced false
positive.

## Consumers

This fixture is consumed by the following M033 acceptance points:

- **P01 SC-1** — exercises FR-2's rule-2 (`greenfield-with-materials`)
  branch detection. The fixture is copied into a probe target and
  `start.sh` must classify the target as `greenfield-with-materials`
  on the strength of the four PBJ-shape `.md` files at the project
  root with no `src/` directory.
- **P04 SC-4** — exercises the materials-intake drift detector. The
  detector reads the fixture, surfaces inconsistencies, and SC-4
  asserts that the output names exactly the five inconsistencies
  enumerated in this README's ground-truth oracle.

Any change to the fixture's inconsistency count (4 or 6 instead of
5) silently breaks SC-4. Any addition of `src/` or `.git/` to the
fixture silently breaks SC-1 by re-routing FR-2 detection to rule-3.
