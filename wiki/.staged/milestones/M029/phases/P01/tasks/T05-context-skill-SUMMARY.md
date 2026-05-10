---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P01"
milestone: "M029"
provides:
  - "orchestrator:context FR-4 single-screen runtime-profile skill (commands/context.md) + SC-4 fixture/script + 2 verifiers"
requires:
  - "from:T01 what:references/status-headline-shape.md+references/status-json-schema.md from:T02 what:scripts/state/detect-invocation-context.sh"
affects:
  - "P02 (SC-14 read-only invariant assertion folds in the SC-4 sentinel-file precursor)"
key_files:
  - "commands/context.md,tests/m029-acceptance/p01-sc4-context.sh,tests/m029-acceptance/fixtures/context-minimal.fixture/,tools/verify/m029-p01-context-skill-shape.sh,tools/verify/m029-p01-sc4-shape.sh"
key_decisions:
  - "AD-1 single-resolve at command entry; SC-2 embedded-reference-renderer pattern reused; sentinel-file precursor for SC-14; new minimal fixture (not SC-2 reuse) for .orchestrator/-rooted read-only check"
patterns_established:
  - "LLM-instruction-doc skills get an embedded reference renderer in their acceptance script; sentinel-file find -newer is the precursor for the AD-9 SC-14 mechanism"
drill_down_paths:
  - "commands/context.md,tests/m029-acceptance/p01-sc4-context.sh"
duration: "2h"
verification_result: "pass"
completed_at: "2026-05-05T23:15:03Z"
---

# T05 — orchestrator:context skill + SC-4 fixture/script + verifiers (FR-4)

## What shipped

Four artifacts realize the FR-4 single-screen runtime-profile skill on the
M029/P01 plane:

1. `commands/context.md` — the canonical command-document for
   orchestrator:context. Frontmatter description, H1, and all eight
   required H2 sections (## Output Format, ## Single-Screen Constraint,
   ## Resolution, ## AD-1 Single-Resolve, ## Read-Only Discipline,
   ## Idempotency, ## Error Handling, ## Reference Files). Documents
   the six labeled fields (resolved root:, runtime:, capability profile:,
   intensity defaults:, active milestone:, lock state:) and the SC-4
   single-screen constraint (24 lines on 80x24). Cross-references the
   AD-1 resolver, both companion design contracts, and the composed
   scripts (resolve-root.sh, find-active-milestone.sh, read-config.sh).

2. tests/m029-acceptance/fixtures/context-minimal.fixture/ — minimal
   fixture (.orchestrator/config.yml + .orchestrator/milestones/M999/
   M999-ROADMAP.md) exercising the skill against a known-state
   orchestrator root. Created instead of reusing the SC-2 fixture
   because the SC-2 fixture's tree shape is <root>/milestones/...
   (omitting the .orchestrator/ parent), while SC-4's sentinel-file
   precursor mechanism asserts read-only-ness under .orchestrator/
   specifically.

3. tests/m029-acceptance/p01-sc4-context.sh — the SC-4 acceptance script.
   Mirrors the SC-2 pattern (embedded reference renderer encoding the
   contract documented in commands/context.md; the renderer is
   test-internal and MUST NOT be sourced by production code). Asserts
   single-screen line budget, all six field labels present, exit 0
   under degraded fields, and the read-only invariant via the
   sentinel-file precursor (.m029-p01-sc4-sentinel + find -newer empty).
   Final form: SC-4: pass=9 fail=0.

4. tools/verify/m029-p01-context-skill-shape.sh — verifies the
   command-document's shape: file presence, frontmatter description,
   H1, the eight H2 sections, the six field labels, the FR-4 +
   single-screen + 24 literal tokens, and the five composed-script and
   companion-contract references. 25 assertions, all PASS.

5. tools/verify/m029-p01-sc4-shape.sh — verifies the SC-4 acceptance
   script's shape: file presence, executability, FR-4 + SC-4 header
   tokens, the six field-label assertions, the m029-p01-sc4-sentinel +
   find + -newer sentinel-mechanism tokens, and ends by running the
   SC-4 script itself end-to-end. 15 assertions, all PASS.

## Key design decisions

- AD-1 single-resolve discipline. The skill MUST read the resolver's
  emitted env block at command entry. The skill displays runtime from
  env-var probing and cross-checks default_provider from the resolver;
  the two agree on configured systems and disagree only when the env
  probe reflects a current runtime that differs from the configured
  default.

- Read-only via sentinel-file precursor. The SC-4 script stamps a
  sentinel before invoking the renderer and asserts find -newer
  returns nothing afterward. This is the precursor mechanism to the
  AD-9 SC-14 milestone-grain read-only assertion that lands in P02.
  Sleep 1s after sentinel-stamp to avoid same-second-mtime false
  negatives.

- Embedded reference renderer pattern (SC-2 precedent). Because
  commands/context.md is an LLM-instruction document (not a directly
  executable program), the SC-4 script embeds a reference renderer
  (m029_render_context) that mirrors the documented contract. A
  comment block at the top of the SC-4 script names it as
  test-internal and forbids production sourcing.

- Fixture choice. Created a new minimal fixture rather than reusing
  the SC-2 status-headline-executing.fixture/ because (a) SC-4's
  sentinel-file mechanism requires <root>/.orchestrator/ shape, while
  SC-2's fixture is a flat <root>/milestones/... shape; (b) the
  context-minimal.fixture/ is genuinely minimal -- just config.yml
  plus M999 roadmap -- and won't drift if SC-2's fixture grows.

## Verification

- bash tools/verify/m029-p01-context-skill-shape.sh -> pass=25 fail=0
- bash tools/verify/m029-p01-sc4-shape.sh -> pass=15 fail=0 (and the
  embedded SC-4 script invocation: SC-4: pass=9 fail=0)

## Constraints honored

- Single-screen budget (SC-4): rendered output is 6 non-empty lines.
- AD-1 single-resolve: skill reads detect-invocation-context.sh env
  block at entry; SC-4 reference renderer does the same.
- Read-only (CON-1 / FR-14 / SC-14 precursor): zero writes during
  invocation; sentinel-file find -newer proves it.
- Graceful degradation: every field has a documented fallback; the
  SC-4 reference renderer exercises the degraded paths (no
  CLAUDECODE set in test env) and still exits 0.
- No new production scripts. T05 created only the command document
  plus acceptance fixture/script plus two verifiers. No modification
  to M013/M019/M020/[M027](../../../../../milestones/M027/index.md) surfaces.
