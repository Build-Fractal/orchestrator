---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M005"
goal: "Core payload transforms (section assembly, manifest building, compression steps) extracted into sourced lib/ functions that take stdin and return stdout with no file I/O — independently testable via pipe chains."
demo_sentence: "A developer sources scripts/lib/payload-transforms.sh and pipes a multi-section payload through drop_by_priority, summarize_section, and drop_lowest_confidence on the command line; sources scripts/lib/manifest-builder.sh and calls build_manifest_header, compute_section_tokens, format_manifest_row to construct a manifest table from stdin; build-context.sh and compress-payload.sh produce identical output but delegate all transform logic to these lib functions."
risk: "medium"
depends_on: []
---

<!--
  P03 -- Pure Transform Extraction
  =================================

  Context: build-context.sh and compress-payload.sh contain inline transform
  logic (token estimation, manifest assembly, section splitting, compression
  steps) that is tightly coupled to file I/O and impossible to unit-test in
  isolation. This phase extracts that logic into pure sourced functions in
  scripts/lib/ following AD-5: functions take stdin/arguments, return stdout,
  with no file I/O inside the function body.

  Architectural decision:
    AD-5  Extracted pure transforms live in scripts/lib/ as sourced functions,
          not in scripts/dispatch/ as standalone scripts. They take
          stdin/arguments, return stdout. No file I/O inside the function —
          callers handle I/O.

  Cross-milestone dependencies:
    - M004 P05 delivered the refactored dispatch scripts (build-context.sh,
      compress-payload.sh, section-handlers.sh).
    - M004 P04 delivered scripts/lib/recipe-parser.sh.
    Both are committed on main.
-->

## Must-Haves

### Truths

- payload-transforms.sh exists with double-sourcing guard and exports assemble_section, drop_by_priority, summarize_section, drop_lowest_confidence.
  - Check: `bash scripts/verify/p03-payload-transforms-lib.sh`
- manifest-builder.sh exists with double-sourcing guard and exports build_manifest_header, compute_section_tokens, format_manifest_row.
  - Check: `bash scripts/verify/p03-manifest-builder-lib.sh`
- All pure functions take stdin or arguments and return stdout with no file I/O (no cat/read from files, no write/redirect to files inside function bodies).
  - Check: `bash scripts/verify/p03-no-file-io.sh`
- build-context.sh sources manifest-builder.sh and delegates manifest table construction to lib functions.
  - Check: `bash scripts/verify/p03-build-context-delegates.sh`
- compress-payload.sh sources payload-transforms.sh and delegates compression steps to lib functions.
  - Check: `bash scripts/verify/p03-compress-delegates.sh`
- Token estimation function (estimate_tokens) is defined in exactly one lib file and sourced by both dispatch scripts (no duplication).
  - Check: `bash scripts/verify/p03-no-duplicate-estimate.sh`

### Artifacts

- scripts/lib/payload-transforms.sh (create, min 80 lines, contains "assemble_section")
- scripts/lib/manifest-builder.sh (create, min 60 lines, contains "build_manifest_header")
- scripts/dispatch/build-context.sh (modify, contains "manifest-builder.sh")
- scripts/dispatch/compress-payload.sh (modify, contains "payload-transforms.sh")
- scripts/verify/p03-payload-transforms-lib.sh (create, min 10 lines)
- scripts/verify/p03-manifest-builder-lib.sh (create, min 10 lines)
- scripts/verify/p03-no-file-io.sh (create, min 10 lines)
- scripts/verify/p03-build-context-delegates.sh (create, min 10 lines)
- scripts/verify/p03-compress-delegates.sh (create, min 10 lines)
- scripts/verify/p03-no-duplicate-estimate.sh (create, min 10 lines)

### Key Links

- scripts/lib/payload-transforms.sh -> scripts/dispatch/compress-payload.sh
- scripts/lib/manifest-builder.sh -> scripts/dispatch/build-context.sh
- scripts/lib/payload-transforms.sh -> scripts/dispatch/build-context.sh (estimate_tokens shared)
- scripts/lib/manifest-builder.sh -> scripts/dispatch/compress-payload.sh (manifest rebuild)
- scripts/lib/errors.sh -> scripts/lib/payload-transforms.sh (guard pattern reference)
- scripts/lib/errors.sh -> scripts/lib/manifest-builder.sh (guard pattern reference)

## Tasks

### T01: Create payload-transforms.sh and verification scripts

Creates `scripts/lib/payload-transforms.sh` with pure transform functions
extracted from `compress-payload.sh`: `estimate_tokens`, `raw_token_count`,
`assemble_section`, `drop_by_priority`, `summarize_section`, and
`drop_lowest_confidence`. All functions take stdin/arguments and return stdout.
Also creates all six verification scripts for this phase under
`scripts/verify/p03-*.sh`. Zero upstream dependencies.

Full plan: `tasks/T01-PLAN.md`

### T02: Create manifest-builder.sh

Creates `scripts/lib/manifest-builder.sh` with pure manifest construction
functions extracted from `build-context.sh` and `compress-payload.sh`:
`build_manifest_header`, `compute_section_tokens`, `format_manifest_row`,
and `assemble_manifest_table`. All functions take arguments and return stdout.
Depends on T01 (shares `estimate_tokens` from payload-transforms.sh).

Full plan: `tasks/T02-PLAN.md`

### T03: Refactor build-context.sh to delegate to lib functions

Refactors `scripts/dispatch/build-context.sh` to source
`scripts/lib/manifest-builder.sh` and `scripts/lib/payload-transforms.sh`,
replacing the inline `estimate_tokens` function and
`_bc_assemble_manifest_and_emit` logic with calls to the new lib functions.
Depends on T01 and T02 (both libs must exist).

Full plan: `tasks/T03-PLAN.md`

### T04: Refactor compress-payload.sh to delegate to lib functions

Refactors `scripts/dispatch/compress-payload.sh` to source
`scripts/lib/payload-transforms.sh` and `scripts/lib/manifest-builder.sh`,
replacing the inline `estimate_tokens`, `raw_token_count`, compression step
functions, and manifest rebuild logic with calls to the new lib functions.
Depends on T01 and T02 (both libs must exist).

Full plan: `tasks/T04-PLAN.md`

## Task Dependencies

```
T01 (payload-transforms.sh + verify scripts)
  |
  +---> T02 (manifest-builder.sh, sources payload-transforms.sh for estimate_tokens)
  |       |
  |       +---> T03 (refactor build-context.sh)
  |       |
  |       +---> T04 (refactor compress-payload.sh)
  |
  +---> T03 (also depends directly on T01)
  |
  +---> T04 (also depends directly on T01)
```

T01 is the critical-path gate -- T02 consumes estimate_tokens from it.
T03 and T04 depend on both T01 and T02 but are independent of each other
and can execute in parallel.

## Files Likely Touched

- scripts/lib/payload-transforms.sh (create)
- scripts/lib/manifest-builder.sh (create)
- scripts/dispatch/build-context.sh (modify)
- scripts/dispatch/compress-payload.sh (modify)
- scripts/verify/p03-payload-transforms-lib.sh (create)
- scripts/verify/p03-manifest-builder-lib.sh (create)
- scripts/verify/p03-no-file-io.sh (create)
- scripts/verify/p03-build-context-delegates.sh (create)
- scripts/verify/p03-compress-delegates.sh (create)
- scripts/verify/p03-no-duplicate-estimate.sh (create)
