---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P00"
milestone: "M019"
name: "Populate .orchestrator/config/pricing.yml with Anthropic Opus 4.7 / Sonnet 4.6 / Haiku 4.5 input/output rates per million tokens plus last_updated timestamp and ORCH_PRICING_FILE contract documentation. In-repo default per AD-2."
depends_on: ["T01"]
---

## Prerequisites

T01 has completed (nominal serial ordering). T04 does not consume T01 outputs.

Repository pre-existing state:

- `.orchestrator/` directory exists.
- `.orchestrator/config/` directory does NOT exist yet — T04 creates it.
- AD-2 (M019-CONTEXT.md): "Pricing config lives at `.orchestrator/config/pricing.yml`. Keeps state-tree concerns colocated. `ORCH_PRICING_FILE` env var overrides the path. P00 ships a one-shot populate seeded with current Anthropic public pricing."
- Q2 (M019-CONTEXT.md): "Lean toward [structuring entries to accept arbitrary model names with a `provider` field] — costs ~3 lines now, migration later costs more." T04 adopts the Q2 recommendation.

Public Anthropic pricing reference (as of 2026-04-17):

- **Claude Opus 4.7**: input $15.00 / million tokens, output $75.00 / million tokens.
- **Claude Sonnet 4.6**: input $3.00 / million tokens, output $15.00 / million tokens.
- **Claude Haiku 4.5**: input $0.80 / million tokens, output $4.00 / million tokens.

(These are placeholder values representative of the Claude 4 family pricing convention. The operator is expected to review and update the file before P01 ships — that's the AD-2 "hand-maintained, refresh cadence acceptable" contract.)

## Description

Create the `.orchestrator/config/pricing.yml` file with a schema that supports the P01 emitter and forward-compatible provider multi-tenancy (Q2 resolution).

Schema shape:

```yaml
# .orchestrator/config/pricing.yml
# Resolver contract: scripts/lib/pricing.sh (P01) reads this file by default.
# ORCH_PRICING_FILE env var overrides the path.
# Stale threshold: 90 days since last_updated -> emitter writes
# estimated_cost_usd: null with pricing_warning (C4, SC-5).

schema_version: "1.0"
last_updated: "2026-04-17"

# One model block per rate entry. Provider field reserved for Tier 3
# multi-backend support (Codex / Cursor / OpenAI). Anthropic-only in P00.
# Rates are USD per million tokens (input + output distinct per Anthropic
# public pricing page as of last_updated).

models:
  claude-opus-4-7:
    provider: anthropic
    input_per_million_usd: 15.00
    output_per_million_usd: 75.00
  claude-sonnet-4-6:
    provider: anthropic
    input_per_million_usd: 3.00
    output_per_million_usd: 15.00
  claude-haiku-4-5:
    provider: anthropic
    input_per_million_usd: 0.80
    output_per_million_usd: 4.00

# Aliases — map orchestrator-internal model handles to concrete model keys.
# Intensity gate's model selection writes the canonical handle; the
# resolver prefers aliases[<handle>] then models[<handle>].
aliases:
  opus-latest: claude-opus-4-7
  sonnet-latest: claude-sonnet-4-6
  haiku-latest: claude-haiku-4-5
```

No resolver helper is in scope for T04 — `scripts/lib/pricing.sh` ships in P01 per the roadmap's Produces set for P01.

## Steps

### Step 1: Create directory

```bash
mkdir -p .orchestrator/config
```

### Step 2: Write `.orchestrator/config/pricing.yml`

Use the `Write` tool to create the file with the exact content from the Description section above. Key keys that must appear (for Gate 6 of the payload-shape verify):

- Literal line `last_updated:` with an ISO 8601 date value.
- Literal strings `opus`, `sonnet`, `haiku` each appear at least once (matched against model keys).
- Literal strings `input` and `output` appear as part of `input_per_million_usd` / `output_per_million_usd` field names.
- Literal string `ORCH_PRICING_FILE` appears in a comment documenting the env override.
- Minimum 30 lines (enforced by P00-PLAN.md artifacts check).

### Step 3: Add pricing.yml to any .gitignore exclusions that may hide `.orchestrator/config/`

**Action 3.** Inspect `.gitignore` / `.orchestrator/.gitignore` if present. If `.orchestrator/config/` is excluded, add an explicit `!.orchestrator/config/pricing.yml` exception line so the file is committed.

Typical `.orchestrator/.gitignore` patterns exclude `tmp/`, `orchestrator.lock`, `execution-log.jsonl` — `config/` should not be excluded, but verify.

If no gitignore changes are needed, skip Step 3.

## Must-Haves

- `.orchestrator/config/pricing.yml` exists.
- File contains `schema_version: "1.0"`.
- File contains `last_updated:` with an ISO 8601 date value.
- File contains entries for `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5` (or equivalent handles matching the tokens `opus`, `sonnet`, `haiku`).
- Each model entry has `input_per_million_usd` and `output_per_million_usd` numeric fields.
- File contains a comment naming `ORCH_PRICING_FILE` env override.
- File ≥ 30 lines.

## Verification

Run:

```
bash scripts/verify/m019-p00-payload-shape.sh
```

Expected Gate 6 passes:

```
PASS: pricing.yml exists
PASS: pricing.yml contains last_updated:
PASS: pricing.yml contains opus
PASS: pricing.yml contains sonnet
PASS: pricing.yml contains haiku
PASS: pricing.yml contains input
PASS: pricing.yml contains output
```

Gates 3 (L3) and 5 (L5) should already be passing post-T02.

## Inputs

### From Previous Tasks

- `scripts/verify/m019-p00-payload-shape.sh` (from T01) — Gate 6 consumes pricing.yml existence and keys.

### From Disk (Pre-existing)

- AD-2 in [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — locates the file at `.orchestrator/config/pricing.yml`.
- Q2 resolution in [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — provider-field schema.
- Anthropic public pricing page (operator-verified).

## Constraints

- **Pure YAML**, parseable by grep/sed/awk (MEM001). No nested scalars with colons-in-values without quoting.
- **In-repo default** per AD-2. File is checked in — not user-local.
- **ORCH_PRICING_FILE env override** documented in a top-of-file comment, even though the resolver is not implemented in P00.
- **No resolver code in P00 scope.** `scripts/lib/pricing.sh` is P01 territory; T04 only ships the config file.
- **Schema reserves provider field** (Q2) so Tier 3 backend adapters can add Codex/Cursor/OpenAI models without a breaking migration.
- **Surgical scope** (Constitution XV). No extra commentary, no runtime code, no migration tools.

## Expected Output

After T04:

- `.orchestrator/config/` directory exists.
- `.orchestrator/config/pricing.yml` exists, is ≥ 30 lines, contains the documented schema.
- `bash scripts/verify/m019-p00-payload-shape.sh` Gate 6 passes; final line may still be `FAIL:` if other gates are not yet passing (L1/L2/L4 pass after T01; L3/L5 pass after T02; if both preceding tasks are complete, the full gate passes).
- File is committed alongside the other P00 changes.
