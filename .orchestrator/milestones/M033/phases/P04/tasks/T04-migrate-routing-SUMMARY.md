---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M033"
provides:
  - "FR-11/FR-12 migrate-routing real implementation in scripts/lifecycle/start.sh (replaces P01 vacuous migrate_routing_stub via deprecated-alias forwarding); translate_from_to_source helper (gsd-v1->gsd1, gsd-v2->gsd2, spec-kit->speckit); US-6 AS-5 unsupported-tooling diagnostic; FR-12 migrate-then-ingest invocation gated on src/ presence; --dry-run gate that skips migrate.sh/ingest-codebase.sh while preserving load-bearing tokens; tools/verify/m033-p04-migrate-routing-shape.sh (30-check shape + functional translate verifier)"
requires:
  - "from:P01/T03 what:scripts/lifecycle/start.sh-migrate_routing_stub-slot+DETECTED_FROM-global; from:P01/T05 what:tests/m033-acceptance/p01-start-branch-routing.sh-SC-1-cross-phase-regression; from:P02/T01 what:scripts/util/jsonl-event-emitter.sh-migrate_routed-event-type; from:P02/T02 what:scripts/util/start-state-markers.sh-migrate-routed-marker; from:P03/T03+T04 what:scripts/lifecycle/ingest-codebase.sh-dup-prevention-sentinel; from:M015 what:scripts/migrate/migrate.sh---path/--source-flags"
affects:
  - "P04/T05"
key_files:
  - "scripts/lifecycle/start.sh,tools/verify/m033-p04-migrate-routing-shape.sh"
key_decisions:
  - "D-T04-01:--dry-run-gate-added-skip-migrate-sh-and-ingest-invocations-while-preserving-load-bearing-tokens-because-SC-1-fixture-4-runs-yes-dry-run-against-stub-gsd-fixture-and-actual-migrate-sh-call-would-fail;D-T04-02:keep-migrate_routing_stub-as-deprecated-alias-forwarding-to-migrate_routing-AND-emitting-legacy-would-execute-token-rather-than-deleting-it-preserves-SC-1-AD-15-backward-compat-without-modifying-SC-1-acceptance-script;D-T04-03:translate_from_to_source-uses-plain-case-and-echo-no-associative-arrays-MEM001-bash-3.2-compat;D-T04-04:no-FR-21-dual-write-fragment-for-migrate-routing-FR-21-closed-callsite-list-covers-FR-3/FR-7/FR-9/FR-10/FR-13-only-FR-11-is-glue-not-content-authoring-surface"
patterns_established:
  - "deprecated-alias-forwarding-pattern-with-load-bearing-token-emission-preserved-for-AD-15-cross-phase-regression-passthrough;dry-run-gate-pattern-skip-side-effects-but-emit-load-bearing-tokens-so-acceptance-tests-can-verify-routing-without-invoking-real-migrators;spec-shape-impl-shape-translation-helper-pattern-operator-facing-flag-decoupled-from-internal-flag-names-via-thin-case-helper;functional-translate-extraction-pattern-awk-extracts-helper-body-then-bash-c-loads-it-into-clean-subshell-for-positive+negative-functional-smoke-without-sourcing-main-script"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P04/tasks/T04-migrate-routing-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-05-04T14:39:59Z"
---

T04 replaced P01's vacuous migrate_routing_stub in scripts/lifecycle/start.sh with the FR-11/FR-12 real implementation. The driver now: (1) translates spec-shape gsd-v1/gsd-v2/spec-kit to migrate.sh's impl-shape gsd1/gsd2/speckit via the new translate_from_to_source helper; (2) emits the load-bearing tokens 'migrate-routed: from=<kind>' and 'proposed: orchestrator:migrate --from <kind> --project-dir <path>'; (3) under --yes (or operator one-keystroke 'Y') invokes 'bash scripts/migrate/migrate.sh --path <path> --source <kind>'; (4) emits the US-6 AS-5 diagnostic 'no orchestrator:migrate adapter for this tooling -- please file a request' to stderr when DETECTED_FROM is empty (migrating branch fired but no SSOT pattern matched, e.g. .aider/ directory); (5) on successful migrate, when src/ exists, invokes 'bash scripts/lifecycle/ingest-codebase.sh --project-dir <path>' once (FR-12, safe per T03's dup-prevention sentinel); (6) emits the migrate_routed JSONL event and writes the migrate-routed start-state marker. The migrate_routing_stub is preserved as a deprecated alias that emits the legacy 'would-execute: migrate-routing-stub' token AND forwards to migrate_routing (AD-15 backward compat: SC-1 fixture-4's hard-coded assertion against the legacy token continues to pass). A --dry-run gate added to migrate_routing skips the actual migrate.sh and ingest-codebase.sh invocations while preserving the load-bearing tokens, so SC-1 fixture-4 (runs --yes --dry-run against a stub .gsd/v1-roadmap.yml) doesn't trigger real migration against an invalid stub. Verification: tools/verify/m033-p04-migrate-routing-shape.sh pass=30 fail=0; tests/m033-acceptance/p01-start-branch-routing.sh pass=14 fail=0 (SC-1 cross-phase regression preserved without SC-1 modifications); tools/verify/m033-p01-phase-suite.sh pass=14 fail=0; scripts/diagnostics/check-plans.sh exit=0 (advisory). Functional smoke (off-tree, ephemeral): all three from-kinds (gsd-v1/gsd-v2/spec-kit) emit correct migrate-routed token; --dry-run gate fires; legacy stub token still emitted. SC-1 modifications: NONE — the deprecated-alias-forwarding pattern preserved the legacy token shape, so AD-15 cross-phase regression discipline is satisfied without touching the SC-1 acceptance script. P02 SUMMARY claims wiki-init/giscus event types but emitter ships them; P04/T04 does not extend the JSONL emitter further.
