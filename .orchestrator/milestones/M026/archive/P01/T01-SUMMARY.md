---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M026"
provides:
  - "authoritative conversus OSS/paid parity matrix (16 rows, fixed-vocabulary verdicts); three T01-scoped verifiers"
requires:
  - "conversus-oss + conversus source trees readable; scratch seed matrix; smoke-test commentary"
affects:
  - "P02 adapter-consumption design uses the matrix as authoritative drift ledger; OQ-2 narrow-vs-full scope call gated on this artifact"
key_files:
  - ".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md,.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md,scripts/verify/m026-p01-parity-matrix-shape.sh,scripts/verify/m026-p01-parity-matrix-coverage.sh,scripts/verify/m026-p01-upstream-readonly.sh"
key_decisions:
  - "OQ-2 narrow-scope TRIGGERED (drifted+absent=5>3); 4 smoke-identified drifts re-classified as verified-identical between OSS and paid (drift is orchestrator-preset vs both trees, not OSS vs paid)"
patterns_established:
  - "parity-matrix fixed-vocabulary verdict pattern (verified-identical/drifted/absent/moot) as OSS-migration driver"
drill_down_paths:
  - ".orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-23T21:47:48Z"
---

T01 delivered the M026 authoritative parity matrix by fs-inspecting both `~/Sites/conversus-oss` (HEAD 8ee7cc3, Apache-2.0 extraction) and `~/Sites/conversus` (HEAD 0eb70ca, paid) read-only. Sixteen data rows landed covering the 12 scratch-matrix surfaces plus the 4 smoke-confirmed drift rows from oss-early-review.md. Final tally: 11 verified-identical, 3 verified-drifted, 2 verified-absent, 0 verified-moot.

Key topology finding worth flagging to P02: OSS is NOT a subset of paid. OSS branched at 1bfd62c and received new features (registry / quality_floor / wheel packaging / spec 006 inter-round arbitration / G1/G2/G11/G12 fixes) while paid received upstream PR #28 (claude-code tool-use-only success classification, commit 722d222) and PR #29 (anthropic parallel-429 retry + concurrency=1, commits defe207 + 0cec838). They are siblings with divergent history. The two verified-absent rows are exactly PR #28 and PR #29 — the real adapter-consumption risk for the migration. The three verified-drifted rows (config-schema additive fields, role preset count 25 vs 26, mcp_server internal refactor) are all additive-or-adapter-irrelevant.

Bigger surprise worth surfacing: the four smoke-confirmed drift rows (YAML frontmatter rejection, agents[].role requirement under red-blue, prompt vs system_prompt field, output object-vs-string) are ALL verified-identical between OSS and paid conversus trees. Both trees use `yaml.safe_load`, both enforce `red-blue` role requirement at the same config.py location, both demand `agents[].prompt:` (paid config.py:42, OSS config.py:45 — both use `prompt: str`), both accept `output: Path` as string path. The drift surfaced in oss-early-review is orchestrator-preset (`templates/conversus-presets/spec-pressure-test.yml` leads with frontmatter, uses `system_prompt:`, has structured `output:` object) versus BOTH conversus trees. This is a significant re-framing: P02 synth-layer translation work applies regardless of which edition is the default, and is not blocked by the migration. It also means OQ-2's narrow-scope trigger (5 drift/absent > 3) fires primarily on the absent PR #28 / PR #29 rows, not on the smoke-identified drifts.

OQ-2 call: NARROW-SCOPE TRIGGERED. P02 should concentrate on (a) a PR #29 mitigation path (serialize agent dispatch on OSS+anthropic, or document `--provider ollama/mock` as supported, or `CONVERSUS_EDITION=oss` diagnostic fallback), (b) a PR #28 shield for `CONVERSUS_PROVIDER=claude-code` on OSS, and (c) deferring internal-refactor and preset-count concerns to demand-driven follow-up.
