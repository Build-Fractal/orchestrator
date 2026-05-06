---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M029"
provides:
  - "AD-1 single-resolve invocation-context resolver (scripts/state/detect-invocation-context.sh) emitting renderer/exit_code_scheme/default_provider env block consumed by every M029 surface; SC-1 acceptance script + two shape verifiers gating downstream drift"
requires:
  - "from:T01 what:references/status-headline-shape.md and references/status-json-schema.md design contracts cross-referenced in resolver header"
affects:
  - "P01"
key_files:
  - "scripts/state/detect-invocation-context.sh,tests/m029-acceptance/p01-sc1-resolver.sh,tools/verify/m029-p01-invocation-context-resolver-shape.sh,tools/verify/m029-p01-sc1-shape.sh"
key_decisions:
  - "AD-1 single-resolve invocation context (renderer/exit_code_scheme/default_provider env block as SSOT for every M029 surface),Principle XI (no surface re-derives TTY/CI/runtime detection),CON-1/FR-14 read-only resolver"
patterns_established:
  - "three-helper resolver shape (_resolve_renderer / _resolve_exit_code_scheme / _resolve_default_provider) emitting fixed-order key=value env block; test-injection flags (--tty/--ci) decouple resolution from real TTY state for SC-1 fixturing; shape verifier asserts field names + values + fixed-order stdout regex so downstream consumers cannot drift silently"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-PAYLOAD.md"
duration: "1h"
verification_result: "pass"
completed_at: "2026-05-05T22:46:20Z"
---

T02 ships the AD-1 single-resolve invocation-context resolver plus the SC-1 acceptance script and two shape verifiers. The resolver is the load-bearing site every M029 surface (status headline, --format=json, where, context, live-tail, preflight) consumes at command entry; downstream tasks T03/T04/T05 and P02/P03 surfaces MUST NOT re-derive TTY / CI / runtime detection.

Artifacts:
- scripts/state/detect-invocation-context.sh (executable, bash 3.2 compatible) -- the AD-1 resolver. Re-source guard, --tty=<true|false>/--ci=<true|false>/--format=<tui|json|plain>/--help|-h flag parser, three resolution helpers (_resolve_renderer, _resolve_exit_code_scheme, _resolve_default_provider), unknown-flag handler exits 2 with stderr diagnostic, --help exits 0. Emits exactly three stdout lines in fixed order: renderer=<tui|json|plain>, exit_code_scheme=<interactive|governance>, default_provider=<value>. Read-only -- no writes anywhere. default_provider is resolved by direct YAML grep against .orchestrator/config.yml (default_provider is not a registered key in scripts/state/read-config.sh so direct read avoids the unknown-key reject path); falls back to claude-code when absent / null per the canonical default in templates/orchestrator-config-default.yml.
- tests/m029-acceptance/p01-sc1-resolver.sh (executable) -- SC-1 acceptance script. Exercises five cases: case1 TTY=true CI=false -> tui+interactive; case2 TTY=false CI=true -> plain; case3 TTY=false CI=false --format=json -> json+governance; case4 TTY=true CI=true -> plain (CI forces plain even on TTY); case5 unknown flag -> non-zero exit + 'unknown flag' on stderr. mktemp tmpdir + EXIT trap. Final SC-1: pass=N fail=M summary line. Exits 0 iff fail=0.
- tools/verify/m029-p01-invocation-context-resolver-shape.sh (executable) -- shape verifier. Asserts file exists + executable, header references AD-1, all three field names + all three renderer values + both exit_code_scheme values + both test-injection flags present in script body, runtime three-line fixed-order regex match under TTY=true CI=false, runtime renderer=plain under TTY=false CI=true. Final SUMMARY line. 17 PASS lines, fail=0.
- tools/verify/m029-p01-sc1-shape.sh (executable) -- SC-1 wrapper verifier. Asserts SC-1 script exists + executable, header references SC-1 + FR-1, invokes scripts/state/detect-invocation-context.sh, SC-1 script exits 0, final SC-1 summary line present with fail=0. 7 PASS lines, fail=0.

Verification (all three Must-Have commands ran green):
- bash tools/verify/m029-p01-invocation-context-resolver-shape.sh -> SUMMARY: m029-p01-invocation-context-resolver-shape.sh pass=17 fail=0 (exit 0)
- bash tests/m029-acceptance/p01-sc1-resolver.sh -> SC-1: pass=8 fail=0 (exit 0)
- bash tools/verify/m029-p01-sc1-shape.sh -> SUMMARY: m029-p01-sc1-shape.sh pass=7 fail=0 (exit 0)

AD-1 single-resolve discipline upheld: every downstream M029 surface reads this script's three-line env block and never re-derives invocation context. Drift in the three-field output shape would break every downstream surface; the resolver shape verifier mechanically asserts field names, renderer values, exit_code_scheme values, and the fixed-order three-line stdout pattern so drift cannot land silently.

Constraints upheld: read-only (CON-1 / FR-14), bash 3.2 compatible (no associative arrays, no case-folding, no process substitution, no herestrings), AD-19 single-script-file shape for verifier Truth Check invocations, no new schema additions to M013 sidecar / M019 JSONL / M020 KNOWLEDGE.md / M027 surfaces (CON-7 / AD-8 boundary). The --format=json flag on the resolver emulates the downstream-command flag; production status/where/context callers probe --format=json themselves and forward it -- the resolver does not auto-detect from the parent's $@.

Plan-rule note (acceptance-script asserts more cases than the plan's nominal 5): the SC-1 plan listed five test cases. The implementation asserts both renderer and exit_code_scheme separately on three of those cases (8 total assertions), which strengthens the SC-1 coverage without removing any case. The pass=8 fail=0 still satisfies the "exits 0 iff fail=0" contract; downstream consumers (T06 phase suite) read the SC-1 prefix line, not the assertion count.

Downstream consumption (locked at AD-1):
- T03 reads renderer to decide whether to ANSI-strip the embedded efficiency-footer line.
- T04 reads renderer=json to know the JSON renderer is the active surface.
- T05 reads default_provider for the runtime-profile screen.
- T06 chains the resolver shape verifier + the SC-1 wrapper verifier in the m029-p01-phase-suite.sh chain (gates 3 + 4 after the T01 design-contract gates).
