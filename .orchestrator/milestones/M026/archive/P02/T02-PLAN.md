---
schema_version: "1.0"
task: "T02"
phase: "P02"
milestone: "M026"
name: "JSONL edition field on conversus_gate_invocation records (FR-4 / AD-4)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `_resolve_edition` helper is available in `scripts/dispatch/adapters/tool/conversus.sh`, and `check` stdout contains `edition=<oss|paid|unknown>` plus `reason=<...>` lines.
- `scripts/integrations/github-common.sh::emit_conversus_gate_record` exists at lines 924-942 (as of post-M026/P01 state). It is a thin wrapper around `emit_tier1_record` for the `conversus_gate_invocation` record type.
- Inline JSONL emission exists at `scripts/specify/specify.sh` line 533 as a hand-rolled JSON string with fields: `type`, `ts`, `gate_id`, `spec_path`, `verdict`, `adapter_version`, `llm_calls`, `elapsed_ms`, `estimated_cost_usd`, `source`.

## Description

Add an `"edition"` field (value: `oss` | `paid` | `unknown`) to every `conversus_gate_invocation` JSONL record, populated from the adapter's resolver. The field is placed immediately adjacent to `adapter_version` per AD-4's provenance-cluster guidance.

Two emission sites:

1. **`scripts/integrations/github-common.sh::emit_conversus_gate_record`** (library wrapper, used by `github-sync.sh` and `github-conversus-gate.sh`). Extend the function signature to accept a 6th positional argument `edition`, propagate it into `emit_tier1_record` as a named field. Callers update to pass the adapter-resolver's edition output. If a caller does not pass the argument (backward compatibility), default to `unknown` and emit the record rather than fail.
2. **`scripts/specify/specify.sh:533`** (inline emission). Extend the REC_G JSON string literal to include `"edition":"${EDITION}"` adjacent to `"adapter_version":"m011-p07"`. Set `EDITION` from the adapter's `check` output immediately before the gate invocation.

JSONL is additive-tolerant per AD-4: existing readers (M019 Tier 1) ignore unknown fields, so adding `edition` is non-breaking.

## Steps

1. **Modify `scripts/integrations/github-common.sh`** (lines 922-942):
   - Extend `emit_conversus_gate_record` signature to accept a 6th positional argument: `local edition="${6:-unknown}"`.
   - Add `"edition=${edition}"` to the `emit_tier1_record` argument list, positioned **after** the `verdict=` field and before `rc=` so the serialized JSON places `edition` near `adapter_version` (note: `emit_tier1_record`'s field ordering is determined by argument order — verify by reading `emit_tier1_record`'s implementation earlier in the same file; if it preserves argument order in the output JSON, this achieves the AD-4 placement; if it sorts alphabetically, no placement control is possible but correctness is unaffected).
   - Update the inline `# emit_conversus_gate_record <issue-ref> <timeout-sec> <verdict> <rc> <duration-ms>` comment (line 924) to add `<edition>` as the 6th positional.
   - Update the Public-functions listing at the self-check footer (lines 947-957) only if the signature string is enumerated there — do not add new functions; the signature change is invisible to a caller-count summary.
2. **Find all callers** of `emit_conversus_gate_record` and update to pass `edition`:
   ```
   grep -rn "emit_conversus_gate_record" scripts/ tests/ 2>/dev/null
   ```
   Expected call sites: `scripts/integrations/github-sync.sh`, `scripts/integrations/github-conversus-gate.sh` (both are likely candidates per the header comment at line 927-928). At each call site, run `bash scripts/dispatch/adapters/tool/conversus.sh check` immediately before or reuse a cached capture, grep for `edition=` → extract value → pass as the 6th argument. Example pattern:
   ```sh
   _check_out="$(bash "${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh" check)"
   _edition="$(printf '%s\n' "$_check_out" | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
   : "${_edition:=unknown}"
   emit_conversus_gate_record "$ref" "$to" "$verdict" "$rc" "$dur" "$_edition"
   ```
3. **Modify `scripts/specify/specify.sh`** around lines 508-536 (the conversus-gate block that emits the REC_G JSONL record):
   - Immediately after the adapter invocation (before line 533) and before emitting the record, capture the adapter's edition:
     ```sh
     EDITION="$(bash "$_REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh" check 2>/dev/null | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
     : "${EDITION:=unknown}"
     ```
     If `_REPO_ROOT` is not in scope, use the existing path-resolution convention elsewhere in `specify.sh` (grep for `dispatch/adapters/tool/conversus.sh` in the file to find how it's referenced).
   - Update the REC_G JSON literal to:
     ```sh
     REC_G="{\"type\":\"conversus_gate_invocation\",\"ts\":\"${TS_G}\",\"gate_id\":\"spec-pressure-test\",\"spec_path\":\"${SPEC_PATH}\",\"verdict\":\"${V}\",\"adapter_version\":\"m011-p07\",\"edition\":\"${EDITION}\",\"llm_calls\":0,\"elapsed_ms\":${G_MS},\"estimated_cost_usd\":0.0,\"source\":\"runtime\"}"
     ```
     `edition` is inserted immediately after `adapter_version` per AD-4.
4. **Write `scripts/verify/m026-p02-jsonl-edition-field.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `scripts/integrations/github-common.sh` contains the updated `emit_conversus_gate_record` signature — grep for `local edition=` inside the function body.
   - The function body calls `emit_tier1_record` with an `edition=` positional argument — grep for `"edition=\${edition}"`.
   - `scripts/specify/specify.sh` contains `"edition":"${EDITION}"` in the REC_G literal (grep for the exact `\"edition\":\"` substring).
   - `scripts/specify/specify.sh` has an `EDITION=` capture line before the REC_G emit (grep `EDITION=.*conversus\.sh check`).
   - Fire a dry-run emission via stub-mode: invoke `emit_conversus_gate_record` in a subshell with `CONVERSUS_STUB=1`, redirect `execution-log.jsonl` to a temp file via `ORCHESTRATOR_ROOT`, grep the emitted line for `"edition"`. Exact mechanics are extracted into the helper script `scripts/verify/m026-p02-jsonl-edition-field.sh` — no compound bash at the Check site.

## Must-Haves

Addresses phase must-haves:
- "Truth: JSONL emission sites include `\"edition\"` field adjacent to `\"adapter_version\"`" (T02 owns)
- Artifact: `scripts/verify/m026-p02-jsonl-edition-field.sh`

## Verification

```
bash scripts/verify/m026-p02-jsonl-edition-field.sh
```

Must exit 0 and print `PASS: m026-p02-jsonl-edition-field.sh`.

Additionally, T01's adapter-invariant verifier must still pass (no regression introduced by the JSONL wiring):

```
bash scripts/verify/m026-p02-adapter-invariants.sh
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/tool/conversus.sh` (from T01)
  - Key API: `check` subcommand stdout now includes `edition=<oss|paid|unknown>` and `reason=<...>` lines in addition to `available=` and `conversus_path=`.
  - Key behavior: `_resolve_edition` is called automatically by `_resolve_binary` in all branches; callers need only parse `check` stdout for `edition=`.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` — target for the `emit_conversus_gate_record` signature extension. Key existing symbols: `emit_tier1_record` (used by the function), `ORCHESTRATOR_ROOT` (state-root resolution), `conversus_gate_invocation` (record type name).
- `scripts/specify/specify.sh` — target for inline REC_G extension. Surrounding context: the block at lines 508-536 is the conversus-gate `y-path` branch; the record is appended to `${STATE_ROOT}/.orchestrator/execution-log.jsonl`.

## Constraints

- **AD-4** (JSONL placement): `edition` immediately adjacent to `adapter_version`.
- **CON-1** (adapter invariants): unchanged — this task does not modify `conversus.sh`.
- **CON-2** (Bash 3.2): no `declare -A`, no process substitution, no command substitution containing pipes in the shell logic added to `github-common.sh` / `specify.sh`.
- **Backward compatibility**: `emit_conversus_gate_record` continues to emit a record when the 6th argument is omitted (falls back to `edition=unknown`). No caller-breakage.
- **Additive tolerance** (AD-4): the new `edition` field is additive in the JSONL record. Downstream consumers (M019 Tier 1 rollup at `scripts/engine/observability/emit-tier1.sh` or equivalent) are unaffected because JSONL schema is open-world.
- **Stderr discipline** (DC-5): the `bash conversus.sh check` invocation captures stdout only; stderr is dropped via `2>/dev/null` so adapter diagnostics don't contaminate the JSON literal.

## Expected Output

- `scripts/integrations/github-common.sh` — modified: `emit_conversus_gate_record` takes a 6th positional arg, default `unknown`, propagated to `emit_tier1_record`. Line count delta ≤ +10.
- `scripts/specify/specify.sh` — modified: `EDITION=` capture added before line 533 emit, REC_G literal extended with `"edition":"${EDITION}"` adjacent to `"adapter_version":"m011-p07"`. Line count delta ≤ +5.
- One or two additional call-site updates in `scripts/integrations/github-sync.sh` / `scripts/integrations/github-conversus-gate.sh` if they exist and call `emit_conversus_gate_record`.
- `scripts/verify/m026-p02-jsonl-edition-field.sh` — created (~40-60 lines).
- All exits 0 per Verification section.
