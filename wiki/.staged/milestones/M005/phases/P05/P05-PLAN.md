---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M005"
goal: "Hook scripts can return structured verdicts (PASS/BLOCK/WARN/NEEDS_REVIEW) via a documented protocol; execution providers follow a documented shell convention (arguments, env vars, output path); run-doctor.sh validates provider scripts against the convention."
demo_sentence: "A developer sources scripts/lib/verdicts.sh and calls emit_verdict PASS 'all checks green'; hooks.sh captures VERDICT lines from hook stdout and blocks on BLOCK verdicts; references/provider-convention.md documents the provider shell interface; bash scripts/diagnostics/check-providers.sh scans scripts/providers/*.sh and validates each against the convention; run-doctor.sh includes Provider Conformance in its diagnostic output."
risk: "medium"
depends_on: ["P01", "P02"]
---

<!--
  P05 -- Gate Verdict Protocol and Provider Convention
  =====================================================

  Context: hooks.sh currently determines hook outcomes purely from exit
  codes (0 = pass, non-zero = block/warn depending on the block flag in
  hooks.yaml). This is insufficient for gate integration: Conversus
  deliberation gates need to communicate structured outcomes (PASS, BLOCK,
  WARN, NEEDS_REVIEW) with human-readable reasons. This phase introduces
  a verdict protocol layer on top of hooks.sh — hook scripts emit VERDICT
  lines to stdout, and hooks.sh parses them to map to block/warn/continue
  behavior.

  Separately, execution providers (the scripts that actually run dispatched
  tasks) have no documented interface contract. This phase defines that
  contract as a shell convention (AD-6) and adds a diagnostic check to
  validate provider scripts against it.

  Architectural decisions:
    AD-3  Gate verdict schema is provider-agnostic (PASS, BLOCK, WARN,
          NEEDS_REVIEW). The verdict protocol is a stdout convention, not
          a file format.
    AD-6  Provider abstraction is a shell convention, not a protocol.
          Providers are bash scripts that accept documented arguments,
          read documented env vars, and write output to a documented path.

  Cross-phase dependencies:
    - P01 delivered scripts/lib/hash.sh with compute_content_hash — providers
      may report content hashes in their output.
    - P02 delivered cost_source enum (estimated/reported/unknown) — providers
      report cost_source alongside cost in telemetry.
-->

## Must-Haves

### Truths

- verdicts.sh exists at `scripts/lib/verdicts.sh` with double-sourcing guard and exports `emit_verdict`, `parse_verdict`, and verdict constants (PASS, BLOCK, WARN, NEEDS_REVIEW).
  - Check: `bash scripts/verify/p05-verdicts-lib.sh`
- hooks.sh captures VERDICT lines from hook stdout and maps BLOCK to hook failure, WARN to HOOK_WARNING event, PASS/NEEDS_REVIEW to HOOK_COMPLETE with verdict metadata.
  - Check: `bash scripts/verify/p05-hooks-verdict-parsing.sh`
- Provider convention reference document exists at `references/provider-convention.md` and declares required arguments, env vars, output path, exit codes, and verdict integration.
  - Check: `bash scripts/verify/p05-provider-convention-doc.sh`
- Provider conformance check script exists at `scripts/diagnostics/check-providers.sh` and validates provider scripts against the convention (checks shebang, argument parsing, output path usage, emit_result call).
  - Check: `bash scripts/verify/p05-check-providers.sh`
- `scripts/diagnostics/run-doctor.sh` includes a `run_check` call for Provider Conformance that invokes `check-providers.sh`.
  - Check: `bash scripts/verify/p05-doctor-integration.sh`

### Artifacts

- scripts/lib/verdicts.sh (create, min 60 lines, contains "emit_verdict")
- scripts/lib/hooks.sh (modify, contains "VERDICT:")
- references/provider-convention.md (create, min 80 lines, contains "Provider Shell Convention")
- scripts/diagnostics/check-providers.sh (create, min 40 lines, contains "DOCTOR:PROVIDERS")
- scripts/diagnostics/run-doctor.sh (modify, contains "check-providers.sh")
- scripts/verify/p05-verdicts-lib.sh (create, min 10 lines)
- scripts/verify/p05-hooks-verdict-parsing.sh (create, min 10 lines)
- scripts/verify/p05-provider-convention-doc.sh (create, min 10 lines)
- scripts/verify/p05-check-providers.sh (create, min 10 lines)
- scripts/verify/p05-doctor-integration.sh (create, min 10 lines)

### Key Links

- scripts/lib/verdicts.sh -> scripts/lib/hooks.sh (hooks.sh sources verdicts.sh to parse VERDICT lines)
- scripts/lib/verdicts.sh -> references/provider-convention.md (convention documents verdict protocol)
- references/provider-convention.md -> scripts/diagnostics/check-providers.sh (convention defines what the check enforces)
- scripts/diagnostics/check-providers.sh -> scripts/diagnostics/run-doctor.sh (check wired into doctor)
- scripts/lib/hash.sh -> references/provider-convention.md (providers may report content hashes)
- scripts/lib/errors.sh -> scripts/lib/verdicts.sh (verdict protocol follows errors.sh patterns)

## Tasks

### T01: Create verdicts.sh verdict protocol library

Creates `scripts/lib/verdicts.sh` with the verdict protocol functions and
constants. Provides `emit_verdict` (emits a structured `VERDICT:` line to
stdout), `parse_verdict` (parses a `VERDICT:` line into components), and
the four verdict constants (ORCH_VERDICT_PASS, ORCH_VERDICT_BLOCK,
ORCH_VERDICT_WARN, ORCH_VERDICT_NEEDS_REVIEW). Follows the same patterns
as errors.sh (double-sourcing guard, constant export, validation function).
Also creates all five verification scripts for this phase under
`scripts/verify/p05-*.sh`.

Full plan: `tasks/T01-PLAN.md`

### T02: Update hooks.sh to parse VERDICT lines from hook stdout

Updates `scripts/lib/hooks.sh` to capture hook stdout (currently discarded
via `>/dev/null`), parse it for `VERDICT:` lines using `parse_verdict` from
verdicts.sh, and map verdicts to hook outcomes: BLOCK triggers hook failure,
WARN emits HOOK_WARNING, PASS/NEEDS_REVIEW emit HOOK_COMPLETE with verdict
metadata. When no VERDICT line is present, behavior is unchanged (exit code
determines outcome). Depends on T01 (verdicts.sh must exist).

Full plan: `tasks/T02-PLAN.md`

### T03: Create provider-convention.md reference document

Creates `references/provider-convention.md` documenting the execution
provider shell interface. Covers required arguments (`--task`, `--phase`,
`--output`), required env vars (`ORCH_RUN_ID`, `ORCH_STARTED_AT`,
`PROJECT_ROOT`), output format (result file at the `--output` path),
exit code semantics, verdict integration (providers may emit VERDICT lines),
cost reporting (`cost_source` field from P02), and content hash reporting
(optional `content_hash` via P01's hash.sh). This is a reference document
consumed by provider authors and by check-providers.sh.

Full plan: `tasks/T03-PLAN.md`

### T04: Create check-providers.sh and wire into run-doctor.sh

Creates `scripts/diagnostics/check-providers.sh` which validates provider
scripts (found under `scripts/providers/` or declared in extension.yml)
against the convention documented in `references/provider-convention.md`.
Checks for: bash shebang, argument parsing for `--task`/`--phase`/`--output`,
`emit_result` call, double-sourcing guard or `set -eu`. Emits structured
output `DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N`. Also
updates `scripts/diagnostics/run-doctor.sh` to include the provider
conformance check. Depends on T03 (convention doc defines what to check).

Full plan: `tasks/T04-PLAN.md`

## Task Dependencies

```
T01 (verdicts.sh + verify scripts)
  |
  +---> T02 (update hooks.sh to parse VERDICT lines)
  |
T03 (provider-convention.md)
  |
  +---> T04 (check-providers.sh + wire into run-doctor.sh)
```

T01 and T03 are independent of each other and can execute in parallel.
T02 depends on T01 (needs verdicts.sh).
T04 depends on T03 (needs convention doc to know what to enforce).
T02 and T04 are independent of each other.

## Files Likely Touched

- scripts/lib/verdicts.sh (create)
- scripts/lib/hooks.sh (modify)
- references/provider-convention.md (create)
- scripts/diagnostics/check-providers.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- scripts/verify/p05-verdicts-lib.sh (create)
- scripts/verify/p05-hooks-verdict-parsing.sh (create)
- scripts/verify/p05-provider-convention-doc.sh (create)
- scripts/verify/p05-check-providers.sh (create)
- scripts/verify/p05-doctor-integration.sh (create)
