---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P07"
milestone: "M018"
provides:
  - "Three P07-private truth verifiers under scripts/verify/m018-p07-*.sh: m018-p07-zero-llm-parity.sh (16 assertions; drives the T01 zero-LLM runner end-to-end and asserts on per-(fixture,runtime) sha256 lines + per-fixture parity-match summary + final regression_flag: none, with documented-divergence carve-out accepting divergence iff a RA-M018-NN row exists in references/RUNTIME-ASSUMPTIONS.md), m018-p07-tier3-routing.sh (14 assertions; drives the T02 T3 runner under both success and --fail-stub modes asserting per-runtime tier3-routing routed stub_invocations=1 lines, tier3-routing-parity result=all-routed summary, and FR-9 failure-passthrough passthrough=ok lines), m018-p07-runtime-assumptions-and-dual-write.sh (11 assertions; mirrors the m018-p06-dual-write-recent.sh shape with M018/P06 -> M018/P07 substitution and adds RUNTIME-ASSUMPTIONS.md presence + # Compression (M018) header + RA-M018-NN row assertions). references/RUNTIME-ASSUMPTIONS.md (registry document for the M009 launch-gate runtime-parity audit; # Compression (M018) block names two inherent-by-design divergences RA-M018-01 Tier 3 model+pricing per runtime and RA-M018-02 claude CLI PATH presence with rationale + M009 audit-row link placeholders; bash-only tier parity sub-block records P07 close-state regression_flag: none, no divergence observed). P07-SUMMARY.md (written atomically via bash scripts/lifecycle/phase-transition.sh --write so roadmap+disk transition together — load-bearing convention from P05/T04 retrospective). CLAUDE.md / AGENTS.md orchestrator:recent-changes dual-write naming M018/P07 + runtime-parity via scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry."
requires:
  - "P07/T01 fixture corpus + zero-LLM parity runner + fixture-staging helper; P07/T02 tier3-stub-llm.sh deterministic stub + m018-runtime-parity-tier3.sh routing runner; scripts/util/dual-write-runtime-md.sh canonical dual-write helper; scripts/lifecycle/phase-transition.sh --write atomic transition helper; scripts/verify/m018-p06-dual-write-recent.sh canonical dual-write verifier shape; references/ directory exists"
affects:
  - "M018 milestone close — P07 is the last phase per the roadmap dependency graph; downstream M009 runtime-parity audit reads references/RUNTIME-ASSUMPTIONS.md (Compression M018 block) at launch-gate time to confirm each cross-runtime divergence has a rationale and an audit-row link"
key_files:
  - "scripts/verify/m018-p07-zero-llm-parity.sh;scripts/verify/m018-p07-tier3-routing.sh;scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh;references/RUNTIME-ASSUMPTIONS.md;.orchestrator/milestones/M018/phases/P07/_summary-body.txt;.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md;CLAUDE.md;AGENTS.md"
key_decisions:
  - "phase-transition.sh --write (NOT write-summary.sh phase) is the canonical closing-task convention — P05/T04 hit a SYNC:MISMATCH using the latter and P06/T04 confirmed the lifecycle helper is the right surface; T03 follows the P06/T04 pattern verbatim with a body-file at .orchestrator/milestones/M018/phases/P07/_summary-body.txt; documented-divergence carve-out: the P07 verifiers accept regression_flag: divergence iff a documenting RA-M018-NN row exists in references/RUNTIME-ASSUMPTIONS.md so divergences are documented (not suppressed) and the verifier asserts the documentation discipline; references/RUNTIME-ASSUMPTIONS.md M009 audit-row column carries placeholder IDs (M009-RP-01, M009-RP-02) — M009 will assign real audit-row IDs at audit time; the verifier asserts header + at least one RA-M018-NN row, not specific row IDs; AP-009 / single-script-file Check shape preserved on every verifier — runner stdout captured to a temp file via single redirect, then grep-asserted (no inline pipes, no compound chains > 2); M018/P06 -> M018/P07 substitution on the dual-write verifier shape + addition of RUNTIME-ASSUMPTIONS.md assertions makes Truth #3 a clean superset of the P06 dual-write check"
patterns_established:
  - "Closing-task verifier-and-summary shape carries forward from P03/P04/P05/P06: pass and fail helpers per MEM002, hermetic ORCHESTRATOR_ROOT staging via runners (verifiers themselves do not touch canonical state), single-script-file Check shape per AD-19/AP-009, body-file pattern (_summary-body.txt) keeps multiline narrative out of CLI args per AD-19, dual-write via scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry; phase-transition.sh --write is the canonical roadmap+disk atomic transition for closing tasks; documented-divergence carve-out pattern — verifiers accept observed divergence iff the registry document carries a corresponding row, asserting documentation discipline rather than suppressing observations; runtime-assumptions registry pattern — references/RUNTIME-ASSUMPTIONS.md is the single consumption surface for the M009 launch-gate runtime-parity audit, with milestone-scoped # <Surface> (M0NN) blocks each carrying RA-M0NN-NN rows with rationale + M009 audit-row link"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P07/tasks/T03-verifiers-and-summary-PLAN.md;.orchestrator/milestones/M018/phases/P07/tasks/T03-verifiers-and-summary-PAYLOAD.md"
duration: "~30m"
verification_result: "pass"
completed_at: "2026-04-28T16:30:00Z"
---

T03 closes P07 by shipping the verification + summary infrastructure
that exercises every prior task's surface and atomically transitions
the roadmap with the disk state.

## What landed

- **Three truth verifiers** under `scripts/verify/m018-p07-*.sh`:
  - `m018-p07-zero-llm-parity.sh` (16 assertions; drives T01's runner)
  - `m018-p07-tier3-routing.sh` (14 assertions; drives T02's runner
    under both success and `--fail-stub` modes)
  - `m018-p07-runtime-assumptions-and-dual-write.sh` (11 assertions;
    RUNTIME-ASSUMPTIONS.md + dual-write check)
- **`references/RUNTIME-ASSUMPTIONS.md`** — registry document with a
  `# Compression (M018)` block carrying two RA-M018-NN divergence rows
  (Tier 3 model+pricing per runtime; `claude` CLI PATH presence) plus
  a bash-only tier parity sub-block recording the P07 close-state
  result (`regression_flag: none`).
- **[`.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md`](../../../../../milestones/M018/phases/P07/P07-SUMMARY.md)** —
  written atomically via `phase-transition.sh --write` so roadmap +
  disk transition together (avoids the P05/T04 SYNC:MISMATCH
  regression).
- **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write** —
  via `scripts/util/dual-write-runtime-md.sh --marker recent-changes
  --append-entry "..."`. Both files name `M018/P07` and
  `runtime-parity`.

## Verification

All three verifiers exit 0 with PASS lines per assertion (41 total
assertions across the three). The task-local Check
(`bash -n scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh`)
exits 0.

## Notes

- `references/RUNTIME-ASSUMPTIONS.md` did not exist prior to P07; T03
  created it. The M009 audit-row column carries placeholder IDs
  (`M009-RP-01`, `M009-RP-02`); M009 will assign real audit-row IDs
  at audit time.
- The documented-divergence carve-out pattern lets the P07 verifiers
  accept `regression_flag: divergence` iff a corresponding RA-M018-NN
  row exists in the registry — divergences are documented, not
  suppressed.
