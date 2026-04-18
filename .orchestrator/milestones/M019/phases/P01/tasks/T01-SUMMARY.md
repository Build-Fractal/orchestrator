---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M019"
provides:
  - "scripts/lib/pricing.sh sourceable library with pricing_file_path, pricing_last_updated, pricing_stale_days, pricing_is_stale, pricing_resolve_alias, pricing_lookup_rates, pricing_estimate_cost_usd, pricing_warning_reason, chars_to_tokens_quartile; scripts/verify/m019-schema.sh JSONL validator enforcing record_type/source/granularity enums, unit_close cost+quality pairing, pre-M019 additivity"
requires:
  - "from:M019/P00/T04 what:.orchestrator/config/pricing.yml"
affects:
  - "P01/T02,P01/T03,P01/T04,P01/T05"
key_files:
  - "scripts/lib/pricing.sh,scripts/verify/m019-schema.sh"
key_decisions:
  - "AD-1 char-quartile token estimate;AD-2 pricing file + ORCH_PRICING_FILE override;AD-4 three record_type enum + source enum + granularity enum"
patterns_established:
  - "Module-scoped _PRICING_WARNING_REASON channel set by pricing_estimate_cost_usd and read by pricing_warning_reason (never aborts caller, always exit 0); never-abort degradation returns empty string on missing/stale/no-rate; awk variable naming avoids in_ identifier collision with awk in keyword on BSD awk; JSONL validator uses pure grep/sed shape-check with no jq dep and additivity for pre-M019 records"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P01/tasks/T01-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-18T03:09:00Z"
---

T01 ships the two foundation units for the Tier 1 M019 emitter. scripts/lib/pricing.sh resolves model rates from .orchestrator/config/pricing.yml, honors ORCH_PRICING_FILE, reports staleness age in days, and computes estimated_cost_usd with 8-decimal precision. On missing file, stale over 90 days, or unknown-model paths it returns empty string and sets _PRICING_WARNING_REASON to missing or stale:Nd or no-rate:MODEL (exposed via pricing_warning_reason); it never aborts the caller. chars_to_tokens_quartile implements AD-1 int chars/4. scripts/verify/m019-schema.sh is a pure-bash JSONL validator that enforces record_type enum payload_breakdown/dispatch_usage/unit_close, source enum estimate/runtime (SC-4), granularity enum task/phase/milestone on unit_close, and mandatory cost+quality pairing (estimated_cost_usd, pricing_version, verification_pass_rate, deviation_count, retry_count) on every unit_close record (C2 Goodhart guard). Pre-M019 records with no record_type field still validate (SC-10 additivity). Both files are bash 3.2 compatible, tested under /bin/bash 3.2.57 on macOS. Smoke-tested: pricing_estimate_cost_usd 1000 500 claude-opus-4-7 returns 0.05250000; opus-latest alias resolves identically; missing-file path returns empty + pricing_warning_reason=missing; bogus-model returns empty + pricing_warning_reason=no-rate:bogus-model. Schema validator accepts good 4-record fixture (PASS exit 0), rejects 5-violation fixture with per-line FAIL diagnostics, and accepts pre-M019 legacy records. One tricky awk pitfall: BSD awk treats identifiers starting with in_ ambiguously due to the in keyword; renamed captures to ival/oval to fix a silent zero in the input_per_million_usd field. No agent-facing content added, anti-pattern linter not retightened per constraint.
