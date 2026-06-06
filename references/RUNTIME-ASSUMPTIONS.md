# Runtime Assumptions

This document records cross-runtime divergences and assumptions consumed
by the M009 launch-gate runtime-parity audit. Each block names a
milestone-scoped origin; each row inside a block names one divergence
with rationale and an M009 audit-row link.

The orchestrator targets three runtimes: `claude-code`, `codex`, and
`cursor`. Wherever runtime behavior diverges by design (because a
runtime exposes its own native model, CLI, or environment surface),
that divergence is captured here so M009 auditors can confirm each
case is intentional and verified.

## Compression (M018)

P07 (multi-runtime parity audit) exercised the M018 compression
pipeline under three simulated runtime environments — `claude-code`,
`codex`, `cursor` — against the fixture corpus at
`tests/compression-runtime-parity/`.

### Divergences

| ID | Surface | Divergence | Rationale | M009 Audit Row |
|----|---------|------------|-----------|-----------------|
| RA-M018-01 | Tier 3 model name + pricing | Each runtime's native model is invoked by `dispatch-interface.sh` for production T3 calls; pricing fields in `dispatch_usage.estimated_cost_usd` differ accordingly. | Per CON-3 / FR-13: T3 routes through `tier3-llm-call.sh` so each runtime calls its native model; the in-band marker schema is normalized but the model name + cost vary by runtime. | M009-RP-01 (compression-tier-3-pricing) |
| RA-M018-02 | `claude` CLI presence on PATH | `tier3-llm-call.sh`'s second-priority provider path requires the `claude` CLI on PATH when `ORCH_BACKEND=claude-code` and `ORCH_TIER3_LLM_BIN` is unset; absent that, the shim exits 1 and FR-9 failure-passthrough fires. | Operator-environment dependency outside the orchestrator's control; documented so M009 auditors can confirm the failure-passthrough path is operational under each runtime's expected install posture. | M009-RP-02 (claude-cli-path-presence) |

### Bash-only tier parity (filter + T1 + T2)

P07's parity runner asserts SHA-256 byte-equality of post-pipeline
payload bytes across `ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}
for every fixture in the corpus. As of P07 close, **no divergence was
observed** — the bash-only tiers ignore `ORCH_BACKEND` (consistent with
their bash-only nature). The parity runner emits
`regression_flag: none` against the live `tests/compression-runtime-parity/`
corpus on a clean checkout.

Any future divergence should land here as a new RA-M018-NN row with
the fixture name, divergent runtime, and rationale; the P07 verifier
accepts `regression_flag: divergence` only when the corresponding
RA-M018-NN row exists (the "documented divergence" carve-out).

### Tier 3 routing parity

P07's Tier 3 routing-parity runner
(`scripts/diagnostics/m018-runtime-parity-tier3.sh`) confirms T3
routes through `scripts/dispatch/lib/tier3-llm-call.sh` under every
runtime via the deterministic stub at
`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`. The
`--fail-stub` mode confirms FR-9 failure-passthrough (Tier 2 bytes
pass through unchanged on stub-fail) is preserved across runtimes.

### M009 launch-gate handoff

The `M009 Audit Row` column above is consumed by M009's runtime-parity
audit. P07 uses placeholder IDs (`M009-RP-01`, `M009-RP-02`); M009
will assign real audit-row IDs at audit time. The verifier asserts the
column header exists and at least one RA-M018-NN row is present, not
specific row IDs.

## Cursor dispatch, hooks & interactive (M009)

The Cursor runtime gained first-class dispatch (`cursor-agent` headless
CLI), lifecycle hooks (Cursor Hooks v1.7+), and MCP elicitation since the
codebase's original ~April-2026 Cursor assumptions were written. The
Tier-A slice (M009 FR-1…FR-4) ships against the `cursor-agent` CLI,
validated live 2026-06-06 (see
`.orchestrator/milestones/M009/M009-PROBE-FINDINGS-2026-06-06.md`). The
divergences below are intentional and apply only under `ORCH_BACKEND=cursor`
(or auto-selected when running under the Cursor runtime, `CURSOR_AGENT=1`).

### Divergences

| ID | Surface | Divergence | Rationale | M009 Audit Row |
|----|---------|------------|-----------|-----------------|
| RA-M009-CURSOR-01 | Auth required for local dispatch | `cursor-agent` requires authentication (`cursor-agent login` OR `CURSOR_API_KEY`) even for local headless runs. There is no air-gapped Cursor dispatch; the `cursor-agent.sh` adapter `--probe` reports unavailable when unauthenticated, and normal mode emits a `status:"failure"` dispatch-result. | `CURSOR_API_KEY`/login is a hard precondition of the Cursor CLI, outside the orchestrator's control. Unlike `claude-code`'s in-process Agent tool or a fully-local Codex run, Cursor always round-trips to its backend. Documented so auditors confirm the unauthenticated-failure path is graceful, not a hang. | M009-RP-CURSOR-01 (auth-required-no-airgap) |
| RA-M009-CURSOR-02 | Per-task cost / pricing | `cursor-agent --output-format json` reports token `usage` (input/output/cacheRead/cacheWrite) but NO USD cost; per-model Cursor pricing + subscription-tier gating are undocumented. The dispatch-result surfaces token usage; `dispatch-interface.sh` cost rollup applies a rate card or degrades to `estimated_cost_usd:null` + `pricing_warning`. | Cursor bills against the account, not per-call in the JSON. A `cursor:` rate-card row + tier-gating confirmation is deferred to Tier-B FR-7. Documented so cost surfaces under Cursor are known-degraded, not silently wrong. | M009-RP-CURSOR-02 (headless-cost-pricing-tbd) |
| RA-M009-CURSOR-03 | Interactive review gate in headless | Native MCP elicitation (`elicitation/create`) is supported by Cursor (capability `{"elicitation":{"form":{}}}`), but headless `cursor-agent -p` auto-returns `{"action":"decline"}` — there is no interactive surface. Review gates render natively in interactive Cursor; in headless/autonomous runs they resolve to `decline`, which maps onto the orchestrator's auto-mode gate policy (`defer`/`accept-with-audit`/`block`). | Verified live 2026-06-06 (M009 Q1 / findings Addendum (b)): decline is instant, deterministic, no hang. The Tier-B orchestrator MCP review-gate server (FR-6) consumes this; until then, autonomous review gates degrade to file-hand-off / auto-mode policy. | M009-RP-CURSOR-03 (headless-elicitation-declines) |

### M009 audit handoff

These rows use placeholder audit IDs (`M009-RP-CURSOR-01..03`); the
Tier-B parity audit (FR-8) assigns real IDs and runs the
`compression-runtime-parity` corpus under `ORCH_BACKEND=cursor` to assert
SHA-256 byte-equality + Tier-3 routing parity, alongside the M018 rows
above.

## Shape-Guard Carve-Outs (M021 / M028)

The active PreToolUse Bash shape-guard
(`scripts/hooks/pre-bash-shape-guard.sh`, classifier at
`scripts/verify/lib/shape-classifier.sh`) inspects command shape
**line-by-line** against the AP-### antipattern table. Two carve-outs
are load-bearing for plan and verifier authoring; both are easy to
forget when authoring helpers, so they're documented here.

### AD-19 helper-function carve-out — function bodies are not classifier-scanned

Bash function bodies declared inside a script under audit are out of
scope for the AP-### classifier. The classifier matches command-shape
on the body of the *invocation* line; the multi-step compounds inside
a function body are not re-scanned at definition time. This means a
multi-step compound like:

```bash
compute_sha() {
  shasum -a 256 "$1" > "$2.raw"
  awk '{print $1}' "$2.raw" > "$2"
}
```

…can be hoisted into a top-of-script function and called once per
invocation site without triggering AP-009 (`compound-chain-gt2`) or
AP-010 (`heredoc-with-expansion`) at the call site. Verifier authors
can use this to keep complex setup compact while staying classifier-clean.

This carve-out was implicit in M028/P02/T03-T05 verifier authoring;
documented retroactively after M028/P02/T05 codified it as a
comment-block convention. Without this note, every future verifier
author rediscovers it from scratch — or gives up and reaches for
`scripts/util/run-probe.sh` (which is the wrong tool for project-tree
verifier paths; see `commands/plan-phase.md` Plan-Time Discipline rule
4 for the run-probe.sh scope contract).

### Inline-shape-check carve-out — `if [ -f X ] && grep ...` is allowed

A two-stage compound (one `&&` or one `;`) inside an `if`-test condition
is below the `compound-chain-gt2` threshold. The shape:

```bash
if [ -f "$path" ] && grep -q "$pattern" "$path"; then
  ...
fi
```

…is classifier-clean and is the canonical shape for the stub-tolerant
inline shape-checks that `commands/plan-phase.md` Plan-Time Discipline
rule 2 names as the alternative when a verifier script doesn't yet
exist at plan-authoring time.

### Cross-references

- `commands/plan-phase.md` — Plan-Time Discipline (rules 3 + 4 reference
  this section).
- `scripts/verify/lib/shape-classifier.sh::classify_command` — call
  this directly at plan-authoring time when the verdict is load-bearing.
- `references/ANTIPATTERNS.md` — AP-### table (the rule set this
  carve-out lives outside of).

## M018 Tier-1 inline_threshold_tokens (P00 precondition)

The M018 compression layer's tier-1 microcompact threshold is sourced from the
active orchestrator config: `compression.tier1.inline_threshold_tokens`. The
default value pinned in `templates/orchestrator-config-default.yml:87` is
`1500` tokens (P00 plan time, 2026-05-01).

Consuming SC: SC-3 (M031, amended per AD-17) — the test fixture under
`tests/m031-acceptance/test-compression-applies-to-quick.sh` MUST construct a
Quick-profile payload exceeding this threshold so tier-1 records reliably emit.
The constructed payload's body-tokens minimum is `inline_threshold_tokens + 1`;
the canonical fixture rounds to `1700` for cushion.

Resolution path at runtime: `compression.tier1.inline_threshold_tokens` in the
project's active `.orchestrator/config.yml` (or the bundled
`templates/orchestrator-config-default.yml` if the project hasn't customized).
M009 (multi-runtime parity, deferred post-launch) is the milestone that
verifies non-CC runtimes resolve the same value.
