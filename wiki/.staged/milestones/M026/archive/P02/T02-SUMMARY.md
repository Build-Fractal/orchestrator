---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M026/P02"
milestone: "M026"
provides:
  - "JSONL conversus_gate_invocation records carry edition field adjacent to adapter_version at both emission sites (github-common emit_conversus_gate_record + specify.sh REC_G); backward-compatible default edition=unknown when caller omits the 6th positional"
requires:
  - "T01 adapter check output line edition=<oss|paid|unknown>; emit_tier1_record argument-order preservation"
affects:
  - "scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh"
key_files:
  - "scripts/integrations/github-common.sh,scripts/integrations/github-conversus-gate.sh,scripts/specify/specify.sh,scripts/verify/m026-p02-jsonl-edition-field.sh"
key_decisions:
  - "Emit adapter_version+edition as adjacent pair in github-common emitter (AD-4 adjacency invariant testable symmetrically with specify.sh); default edition=unknown on omitted 6th positional preserves caller backward compat; capture edition via adapter check stdout (not env var) so the two-tier resolver from T01 is the single source of truth"
patterns_established:
  - "Adjacent-pair AD-4 placement via argument ordering in emit_tier1_record; backward-compat optional positional with defaulted unknown sentinel; verify script drives live emitter through staged sub-scripts to avoid process substitution / compound bash"
drill_down_paths:
  - "scripts/integrations/github-common.sh:930-949,scripts/integrations/github-conversus-gate.sh:146-155,scripts/specify/specify.sh:531-540,scripts/verify/m026-p02-jsonl-edition-field.sh"
duration: "18"
verification_result: "pass"
completed_at: "2026-04-24T18:37:36Z"
---

Wired FR-4 edition field into both conversus_gate_invocation JSONL emission sites. github-common.sh::emit_conversus_gate_record now accepts a 6th positional edition (default unknown) and emits adapter_version=m013-p04 immediately followed by edition=<value> through emit_tier1_record (argument-order preserved per emitter contract). Updated sole caller github-conversus-gate.sh to resolve edition from the adapter's check stdout before invoking. specify.sh captures EDITION=$(bash $ADAPTER check 2>/dev/null | grep ^edition= | sed ...) with :=unknown fallback, and REC_G literal now places "edition":"${EDITION}" immediately after "adapter_version":"m011-p07" (AD-4 adjacency). New scripts/verify/m026-p02-jsonl-edition-field.sh (30 assertions, all pass) checks: static source-shape greps on both files, AD-4 adjacency by line-number delta in github-common and by ordered-substring in specify.sh REC_G, live emit through emit_conversus_gate_record validating edition-oss/paid/unknown value range and backward-compat default, preservation of all pre-existing field keys (no silent renames). Regression guards still pass: m026-p02-edition-detection-contract.sh (18/18), m026-p02-adapter-invariants.sh (29/29), test-conversus-adapter-shim.sh, m013-p04-observability.sh (shape-tolerant, unaffected by the new fields).
