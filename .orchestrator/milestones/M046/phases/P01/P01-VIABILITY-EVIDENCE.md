# P01-VIABILITY-EVIDENCE — M046 viability spikes

Decision-gate output for M046/P01 (CON-6 primitive-verification). This document is the
artifact the roadmap's P01 decision gate reads: it resolves **#Q-1 (hook-install
portability)** and **#Q-4 (M019 cost-read cadence)** with one grep-stable VERDICT line
each, and states the routing consequence for P04 (FR-7/FR-8 cost source) and P05 (FR-9
enforcement mechanism). A zero-context P04/P05 planner can consume the verdicts from this
file alone; the raw spike logs are cited by relative path for drill-down.

Evidence inputs (all produced by T01/T02 of this phase):

- .orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log (T01 direct-drive)
- .orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log (T01 install matrix)
- .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl (T02 cadence probe)
- .orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md (T02 analysis)

## #Q-1 hook-install portability

**Question (spec #Q-1):** Can the default-DENY PreToolUse hook (FR-9) be installed via the
M028 path on every supported CC install shape and survive the shape-guard?

**Method.** Two mechanical legs, both against the REAL hook stdin/exit-code contract under
literal `/bin/bash` 3.2.57, all inside isolated scratch HOMEs at
`/private/tmp/m046-p01-hook-spike/` (real `$HOME` never touched):

1. **Direct-drive** (`spike/hook/drive-hook-case.sh` driving
   `spike/hook/unattended-deny-probe.sh`): six cases through the PreToolUse stdin/exit-2
   contract — three deny vectors (out-of-scope write, out-of-scope Bash `git push`, MCP
   tool call), two allowlisted passes, and fail-closed on a missing policy file.
2. **Install matrix** (`spike/hook/run-install-matrix.sh`): stage + register the probe
   hook via the M028 consumer conventions (cp into `orchestrator-hooks/` + one managed
   settings-merge PreToolUse fragment, matcher `Write|Edit|Bash|mcp__.*`) on both install
   shapes — shape A (symlink/source-tree) and shape B (packaged bundle) — asserting
   coexistence with the existing `pre-bash-shape-guard.sh` entry, idempotent re-merge,
   and clean uninstall.

**Results — deny-drive leg** (quoted verbatim from
.orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log):

    case=oos-write expected=2 actual=2 result=PASS
    case=oos-bash-gitpush expected=2 actual=2 result=PASS
    case=oos-mcp expected=2 actual=2 result=PASS
    case=allowed-write expected=0 actual=0 result=PASS
    case=allowed-bash expected=0 actual=0 result=PASS
    case=policy-missing-failclosed expected=2 actual=2 result=PASS
    live-e2e=deferred-to-SC-5

6/6 PASS. The three deny vectors (including the MCP vector — the primary danger worktree
isolation cannot contain) exit 2 with a reason; allowlisted calls exit 0; a missing policy
file fails CLOSED (exit 2), not open.

**Results — install-matrix leg** (quoted from
.orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log):

    shape=A staged=1 merged=1 coexists=1 idempotent=1 uninstall_clean=1
    shape=B staged=1 merged=1 coexists=1 idempotent=1 uninstall_clean=1

Both shapes all-1s: hook staged, PreToolUse fragment merged managed-tagged, coexists with
the M021 shape-guard entry (8 leaf lines before and after — distinct dedup tuples, no
clobber), re-merge is a no-op, uninstall removes only the managed leaves.

**What is NOT covered here:** the optional live end-to-end leg (a real `claude -p` child
actually blocked by the installed hook) was deferred per dispatch instruction. That proof
is exactly SC-5 (write-and-tool-scope, NON-STUBBED, milestone-blocking) — it is already a
mandatory gate for M046 close, so the deferral leaves no unverified premise unguarded.

VERDICT: #Q-1 PARTIAL — both mechanical legs PASS (default-DENY semantics through the real hook contract, 6/6; M028-path install on both shapes, all-1s); the live-e2e leg is deferred to SC-5, which is already milestone-blocking and non-stubbed, so FR-9 proceeds as specced with no rerouting Decision row needed.

## #Q-4 cost-read cadence

**Question (spec #Q-4):** Does M019 Tier-1 JSONL emit at per-segment granularity in time
for pre-spawn lease reads, or is `--output-format json` `total_cost_usd` the sole cost
source? This is the SC-3 precondition (in-segment-kill must trigger on honestly
cost-derived data).

**Method.** T02 drove the REAL `scripts/lifecycle/auto-loop.sh` single-step driver through
5 steps (READY → PHASE_COMPLETE → READY → PHASE_COMPLETE → MILESTONE_VALIDATING) against a
throwaway 2-phase MFIX fixture in a scratch state root, with stubbed dispatch (summaries
written via the real `write-summary.sh` — the production unit_close emission path) and
zero LLM spend. A 0.2 s poller timestamp-watched the fixture `execution-log.jsonl` and
recorded every append with a wall-clock `"t"` into cadence.jsonl. The per-segment
authoritative-cost half was NOT re-measured: the P00 spike already proved `claude -p
--output-format json` returns a parent-readable `total_cost_usd` per segment
(0.244–0.249/worker), cited from `.orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md`.

**Ordering observations** (quoted from
.orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl):

    {"t":"1783956520.347","event":"jsonl_append","record_type":"unit_close","unit":"MFIX/P01/T01","cost_present":false}
    {"t":"1783956527.649","event":"jsonl_append","record_type":"unit_close","unit":"MFIX/P01","cost_present":false}
    {"t":"1783956539.415","event":"jsonl_append","record_type":"unit_close","unit":"MFIX/P02/T01","cost_present":false}
    {"t":"1783956546.754","event":"jsonl_append","record_type":"unit_close","unit":"MFIX/P02","cost_present":false}
    {"t":"1783956553.854","event":"loop_exit","code":0}
    {"t":"1783956553.994","event":"probe_summary","unit_close_total":4,"unit_close_before_exit":4,"verdict":"unit_grain_mid_segment"}

All 4 `unit_close` records (2 task-grain, 2 phase-grain) were readable from the JSONL
BEFORE `loop_exit` — the last one ~7 s before segment end, observe-lag 0.35–0.75 s
(bounded by the 0.2 s poll + 1 s record-timestamp truncation). Cost-bearing records
(`dispatch_usage` at dispatch time, the step-G result record immediately after each
unit_close) also land mid-segment. Probe verdict: **unit_grain_mid_segment**.

**Cost-field caveat (plainly stated, from CADENCE-FINDINGS.md):** the
`unit_close.estimated_cost_usd` KEY is always present (M019 Goodhart pairing) but its
VALUE was null on all 4 records — `write-summary.sh` any-null propagation nulls the sum
when any same-unit contributor is null (build-context's `dispatch_usage` carried null
under `pricing_warning: no-rate`), and this holds in production under any pricing
degradation. The step-G `--cost` value lands under the disjoint `cost_estimated` key,
which the unit_close aggregator does not read. So the JSONL supplies mid-segment
unit-grain **cadence**, but its cost values are advisory estimates that may be null —
never assume presence.

VERDICT: #Q-4 PASS — the M019 JSONL IS readable mid-segment at unit grain (4/4 unit_close before loop_exit, 0.35–0.75 s lag), satisfying the SC-3 precondition; the FR-7/FR-8 cost-source split is fixed as: FR-7 in-segment watchdog keeps the conservative reserve + duration probe as primary and reconciles per completed unit only on a non-null JSONL estimate, while FR-8 trues up the reserve-then-spend ledger at each segment boundary from the exiting child's `claude -p --output-format json` `total_cost_usd` (the sole authoritative actual, P00-proven) — JSONL supplies grain, JSON result supplies truth.

## Decision-gate routing

**P04 (budget envelope, FR-7/FR-8) may now assume:** the cost source is fixed. The
in-segment watchdog (FR-7) reads M019 JSONL at unit grain mid-segment — that read path is
proven — but treats JSONL cost values as nullable advisory estimates; its primary guard is
the conservative reserve + duration probe, with per-unit downward reconciliation only on
non-null `estimated_cost_usd` (or `cost_estimated`). Per-segment reconciliation (FR-8)
trues up from the exiting child's `total_cost_usd` JSON result BEFORE spawning segment
N+1; an unreconciled reserve counts as spent. No JSON-sole-source rerouting is needed —
the negative branch of the roadmap gate ("records only at loop exit") did not occur.

**P05 (default-DENY hook, FR-9) may now assume:** the FR-9 enforcement mechanism is
confirmed as specced — an M028-staged default-DENY PreToolUse hook. P05 consumes the
probe's policy-file + matcher shape (`Write|Edit|Bash|mcp__.*`) as its starting design and
inherits the proven install recipe: staged file + one managed settings-merge fragment,
zero installer changes, shape-guard coexistent, idempotent, cleanly uninstallable. The
only open leg — a live unattended child actually blocked — is discharged by SC-5, which
is milestone-blocking and non-stubbed; P05's deliverable must pass it before M046 close.

No Decision row is required: neither question resolved NEGATIVE, so neither the FR-9
mechanism reroute nor the JSON-sole-source fix (the two rerouting consequences named in
the M046-ROADMAP P01 decision-gate text) is triggered.
