---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M029"
provides:
  - "JSON renderer (FR-3) + commands/status.md --format=json wiring (FR-3 + AD-2 + AD-7) + SC-3 fixtures + acceptance + three shape verifiers"
requires:
  - "from:T01 what:references/status-json-schema.md; from:T02 what:scripts/state/detect-invocation-context.sh; from:T03 what:commands/status.md headline block"
affects:
  - "P01"
key_files:
  - "scripts/diagnostics/render-status-json.sh,commands/status.md,tests/m029-acceptance/p01-sc3-format-json.sh,tests/m029-acceptance/fixtures/status-json-executing.fixture,tests/m029-acceptance/fixtures/status-json-degraded.fixture,tools/verify/m029-p01-render-status-json-shape.sh,tools/verify/m029-p01-status-format-json-wiring.sh,tools/verify/m029-p01-sc3-shape.sh"
key_decisions:
  - "AD-2,AD-7,AD-1"
patterns_established:
  - "single ANSI-strip site (AD-2); _M029_SCHEMA_VERSION constant as renderer-side SSOT cross-checked against schema doc; jq -n --arg safe JSON construction; degraded-state envelope (state + parse_errors) on corrupt JSONL never crashes the renderer"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P01/tasks/T04-status-json-format-PAYLOAD.md"
duration: "2h"
verification_result: "pass"
completed_at: "2026-05-05T23:04:25Z"
---

T04 ships the FR-3 --format=json path. The renderer (scripts/diagnostics/render-status-json.sh) is the SINGLE AD-2 ANSI-strip site for the JSON output, declares _M029_SCHEMA_VERSION="1.0" as the AD-7 SSOT (cross-checked against references/status-json-schema.md), uses jq -n --arg for safe JSON construction, and emits a degraded-state envelope (state="degraded" + parse_errors[]) when execution-log.jsonl parses with errors -- never crashes on corrupt JSONL. commands/status.md gains a ## Format Flag section between ## Headline Block and ## State Derivation that documents the flag, the AD-2 unconditional-strip rule, and the degraded-state behavior. The SC-3 acceptance script (tests/m029-acceptance/p01-sc3-format-json.sh) drives the renderer against two fixture milestone trees (status-json-executing.fixture for the happy path and status-json-degraded.fixture with intentionally-corrupt JSONL lines), asserting parseable JSON, schema_version="1.0", every required top-level + section key via jq -e, the AD-2 invariant (no ANSI escapes under .sections), and the degraded-state envelope shape. Three shape verifiers (m029-p01-render-status-json-shape.sh, m029-p01-status-format-json-wiring.sh, m029-p01-sc3-shape.sh) cover the renderer, the commands/status.md wiring, and the SC-3 fixture/script contract. All three pass with fail=0; SC-3 acceptance script reports SC-3: pass=26 fail=0. T03's pre-existing m029-p01-status-headline-shape.sh and m029-p01-sc2-shape.sh continue to pass with no regression.
