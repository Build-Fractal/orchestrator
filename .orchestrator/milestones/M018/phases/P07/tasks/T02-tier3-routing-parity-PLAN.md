---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M018"
name: "Tier 3 routing parity runner + deterministic LLM stub — T3 routes through dispatch-interface.sh under every runtime"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the corpus tree at `tests/compression-runtime-parity/fixtures/` (including `tier3-oversized-section/` which T01 stages but does not exercise) and the fixture-staging helper at `scripts/verify/_helpers/m018-p07-build-fixture.sh`.
- `scripts/dispatch/build-context.sh` `_bc_apply_tier3` (P06/T01) routes summarization through `scripts/dispatch/lib/tier3-llm-call.sh` which honors the four-flag contract `--prompt-file <p> --output <o> --max-tokens <N> --timeout <S>`. The shim's provider-resolution ladder is:
  1. **`$ORCH_TIER3_LLM_BIN` set + executable** — invokes that binary verbatim (operator-binary path).
  2. **`$ORCH_BACKEND=claude-code` + `claude` on PATH** — invokes `claude --print < $PROMPT_FILE > $CAPTURE_OUTPUT`.
  3. **Otherwise** — exits 1; caller's failure-passthrough emits `tier3_failed reason=llm-call-nonzero`.
- `_bc_apply_tier3` writes `savings_tokens=0 invocations=0` to `$TMPDIR_BUILD/_tier3_stats.txt` as its first action; success path overwrites with `savings_tokens=<delta> invocations=1`. Failure-passthrough leaves the zero-baseline.
- `scripts/dispatch/dispatch-interface.sh` is the dispatch entry point; the Tier 3 routing parity assertion is "the helper invokes `tier3-llm-call.sh` (and / or `dispatch-interface.sh` per the helper's wiring) under every runtime; the stub fires once per runtime; the captured output replaces the section in the payload".
- AP-009 / AD-19: no compound chains > 2; no inline `$(...)` containing pipes; no plain subshells; no process substitution.

## Description

T02 ships **one deterministic LLM stub** and **one Tier 3 routing parity runner** that proves T3 dispatches through `tier3-llm-call.sh` correctly under every simulated runtime, with byte-deterministic output thanks to the stub.

Specifically, T02 ships:

1. **`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`** — deterministic four-flag-honoring binary. Used as `ORCH_TIER3_LLM_BIN` so the operator-binary path (highest precedence) takes over and every runtime's T3 invocation is byte-deterministic.
2. **`tests/compression-runtime-parity/_stubs/README.md`** — stub documentation.
3. **`scripts/diagnostics/m018-runtime-parity-tier3.sh`** — Tier 3 routing parity driver. CLI:

   ```
   m018-runtime-parity-tier3.sh [--runtimes <csv>] [--fail-stub] [--fixture <name>]
   ```

   Defaults: `--runtimes claude-code,codex,cursor`, `--fixture tier3-oversized-section`. For each runtime: stages a hermetic root via the T01 helper; sets `ORCH_TIER3_LLM_BIN=<absolute-path-to-stub>`; sets `ORCH_BACKEND=<runtime>`; invokes `bash scripts/dispatch/build-context.sh` against the fixture; asserts (a) the stub fired exactly once (an invocation-counter file under the staged root), (b) the post-pipeline payload contains the stub's deterministic output envelope, (c) the `payload_breakdown` JSONL record carries `tier3_invocations=1` and `tier3_compression_savings_tokens > 0`. The `--fail-stub` flag flips `ORCH_TIER3_STUB_FAIL=1` so the stub exits 1; the runner asserts the failure-passthrough path emits `tier3_failed` to JSONL and the dispatch survives (exit 0).

T02 does NOT ship:

- The corpus / staging helper (T01).
- Verifiers beyond a `bash -n` self-check (T03 ships the canonical truth verifier).
- RUNTIME-ASSUMPTIONS.md or P07-SUMMARY (T03).

## Steps

### Step 1 — Author `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`

Single-script-file. Honors the four-flag contract from `scripts/dispatch/lib/tier3-llm-call.sh`. Behavior:

1. Parse `--prompt-file <p> --output <o> --max-tokens <N> --timeout <S>` (case ladder; same shape as `tier3-llm-call.sh`).
2. If `$ORCH_TIER3_STUB_FAIL=1`, print a one-line stderr message and exit 1 (exercises FR-9 failure-passthrough).
3. Otherwise, write a deterministic envelope to `--output`:

   ```
   <!-- compressed:tier3 model=stub-deterministic input_tokens=<N> output_tokens=<M> -->
   stub-deterministic-summary-body
   ```

   where `<N>` is the byte size of `--prompt-file` and `<M>` is the literal `42` (deterministic across runtimes). Exit 0.
4. As a side effect, append a single line `<iso8601>\t<runtime>` to `${ORCH_TIER3_STUB_INVOCATIONS_LOG:-/dev/null}` so the parity runner can count invocations per runtime. (Use `${ORCH_BACKEND:-unknown}` to capture the runtime that invoked the stub.)

Pseudo-shape (Bash 3.2; AP-009-clean):

```bash
#!/usr/bin/env bash
# tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh
# M018/P07/T02 — Deterministic stub for Tier 3 LLM-call-shim contract.
set -u
PROMPT_FILE=""
OUTPUT=""
MAX_TOKENS=""
TIMEOUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --prompt-file)        PROMPT_FILE="$2"; shift 2 ;;
    --output)             OUTPUT="$2"; shift 2 ;;
    --max-tokens)         MAX_TOKENS="$2"; shift 2 ;;
    --timeout)            TIMEOUT="$2"; shift 2 ;;
    *)                    shift ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  printf 'tier3-stub-llm.sh: --output required\n' >&2
  exit 2
fi

if [ "${ORCH_TIER3_STUB_FAIL:-}" = "1" ]; then
  printf 'tier3-stub-llm.sh: ORCH_TIER3_STUB_FAIL=1 — failure-passthrough exercise\n' >&2
  exit 1
fi

# Compute prompt-file size (single-script-file shape; no $(... | ...))
INPUT_TOKENS=0
if [ -f "$PROMPT_FILE" ]; then
  INPUT_TOKENS=$(wc -c < "$PROMPT_FILE")
fi

# Deterministic envelope
{
  printf '<!-- compressed:tier3 model=stub-deterministic input_tokens=%s output_tokens=42 -->\n' "$INPUT_TOKENS"
  printf 'stub-deterministic-summary-body\n'
} > "$OUTPUT"

# Side-effect: invocation counter
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="${ORCH_TIER3_STUB_INVOCATIONS_LOG:-/dev/null}"
printf '%s\t%s\n' "$TS" "${ORCH_BACKEND:-unknown}" >> "$LOG"
exit 0
```

(Note the use of `wc -c < "$PROMPT_FILE"` inside `INPUT_TOKENS=$(...)` — this is `$(wc -c < file)` which is a single-command substitution with input redirection, NOT `$(... | ...)`. Per AP-009 the forbidden shape is command-substitution-containing-pipes; plain `$(cmd)` is allowed inside script bodies under the MEM004 carve-out. The forbidden shape applies at task-plan Check: line level — single-script-file shape.)

Marking script executable: `chmod +x tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`.

Min 15 lines; must contain the literal substring `--output`.

### Step 2 — Author `tests/compression-runtime-parity/_stubs/README.md`

Document:

1. **Purpose**: deterministic stub for `tier3-llm-call.sh`'s four-flag contract; used as `ORCH_TIER3_LLM_BIN` so T3 routing parity can be asserted byte-deterministically across runtimes.
2. **Contract**: takes `--prompt-file / --output / --max-tokens / --timeout`; writes a fixed envelope to `--output`; exits 0 on success.
3. **Failure mode**: `ORCH_TIER3_STUB_FAIL=1` flips to exit 1 (exercises FR-9 failure-passthrough).
4. **Invocation counter**: appends one line per fire to `$ORCH_TIER3_STUB_INVOCATIONS_LOG` for the parity runner.
5. **Why operator-binary path**: `tier3-llm-call.sh`'s provider-resolution ladder picks `$ORCH_TIER3_LLM_BIN` first (highest precedence); the stub takes precedence over any installed `claude` CLI so the runner is hermetic.

### Step 3 — Author `scripts/diagnostics/m018-runtime-parity-tier3.sh`

Single-script-file. Bash 3.2. AP-009-clean. Outline:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/m018-runtime-parity-tier3.sh
# M018/P07/T02 — Tier 3 routing parity driver.
#
# For each runtime in {claude-code, codex, cursor}: stage the hermetic
# tier3 fixture, set ORCH_TIER3_LLM_BIN to the deterministic stub, set
# ORCH_BACKEND=<runtime>, invoke build-context.sh, assert:
#   - stub fired once
#   - post-pipeline payload contains the stub's deterministic envelope
#   - payload_breakdown JSONL carries tier3_invocations=1
# With --fail-stub: assert failure-passthrough emits tier3_failed and
# dispatch exits 0.

set -u
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/verify/_helpers/m018-p07-build-fixture.sh"
STUB="$PROJECT_ROOT/tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh"
RUNTIMES="claude-code,codex,cursor"
FAIL_STUB=0
FIXTURE="tier3-oversized-section"

while [ $# -gt 0 ]; do
  case "$1" in
    --runtimes)   RUNTIMES="$2"; shift 2 ;;
    --fail-stub)  FAIL_STUB=1; shift ;;
    --fixture)    FIXTURE="$2"; shift 2 ;;
    *)            shift ;;
  esac
done
```

Per-runtime body:

1. Stage root: `STAGE="$(bash "$HELPER" "$runtime" "$FIXTURE")"` — writes path to stdout.
2. Set up env:
   - `export ORCHESTRATOR_ROOT="$STAGE"`
   - `export ORCH_BACKEND="$runtime"`
   - `export ORCH_TIER3_LLM_BIN="$STUB"`
   - `export ORCH_TIER3_STUB_INVOCATIONS_LOG="$STAGE/.orchestrator/_stub-invocations.log"`
   - `export ORCH_TIER3_STUB_FAIL="$FAIL_STUB"`
   - `: > "$ORCH_TIER3_STUB_INVOCATIONS_LOG"` (truncate)
3. Invoke `bash "$PROJECT_ROOT/scripts/dispatch/build-context.sh" --task-plan "$STAGE/input/payload-input.txt" --milestone M-FIXTURE > "$STAGE/output/payload.txt" 2>"$STAGE/output/build-context.stderr"` (or whatever the actual CLI surface accepts; T02 author reads `build-context.sh --help` once at integration time).
4. Capture exit code into a scalar `BC_RC=$?`.
5. Assert stub fired (success path) or failed (failure-passthrough path):
   - On `FAIL_STUB=0`: count lines in `$ORCH_TIER3_STUB_INVOCATIONS_LOG`. Must equal 1. Print `tier3-routing runtime=<runtime> stub_invocations=<N> result=fired`.
   - On `FAIL_STUB=1`: count must equal 1 (the stub fires and exits 1); the JSONL must contain a `tier3_failed` record with `reason=llm-call-nonzero` (grep for the literal); `BC_RC=0` (dispatch survives). Print `tier3-routing runtime=<runtime> stub_fail=1 passthrough=ok`.
6. On success path: assert the post-pipeline payload contains the literal `compressed:tier3 model=stub-deterministic` (the stub's deterministic marker). Single grep call with `-q`.
7. On success path: assert the JSONL `payload_breakdown` record carries `"tier3_invocations":1` and `"tier3_compression_savings_tokens":` with a positive integer. Single grep + awk-extract.
8. Append a `runtime_parity` JSONL record to `$STAGE/.orchestrator/milestones/M-FIXTURE/execution-log.jsonl`: `{"record_type":"runtime_parity","fixture":"<fixture>","runtime":"<runtime>","tier":"3","stub_fired":true,"timestamp":"<iso8601>"}`.

Per-runtime summary line:

```
tier3-routing runtime=<runtime> result=<routed|passthrough> stub_invocations=<N>
```

Final summary line: `tier3-routing-parity result=<all-routed|divergence>` and `regression_flag: <none|divergence>`.

Always exit 0 (FR-12 advisory pattern). The T03 verifier asserts on stdout shape.

### Step 4 — Run the Tier 3 routing runner end-to-end

```bash
bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor
```

Expected output:

```
tier3-routing runtime=claude-code result=routed stub_invocations=1
tier3-routing runtime=codex result=routed stub_invocations=1
tier3-routing runtime=cursor result=routed stub_invocations=1
tier3-routing-parity result=all-routed
regression_flag: none
```

Exit 0.

```bash
bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor --fail-stub
```

Expected output:

```
tier3-routing runtime=claude-code stub_fail=1 passthrough=ok
tier3-routing runtime=codex stub_fail=1 passthrough=ok
tier3-routing runtime=cursor stub_fail=1 passthrough=ok
tier3-routing-parity result=all-routed
regression_flag: none
```

Exit 0 (failure-passthrough is the documented contract; the dispatch survives).

### Step 5 — Bash-n self-check (T02 task-local Check)

```bash
bash -n scripts/diagnostics/m018-runtime-parity-tier3.sh
bash -n tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh
```

Both exit 0.

## Verification

T02's task-local extractable Check is the syntax-only self-check on the tier3 routing runner:

- Check: `bash -n scripts/diagnostics/m018-runtime-parity-tier3.sh`

(One Check per task. The canonical truth verifier — `m018-p07-tier3-routing.sh` — ships in T03 and exercises both this runner and the failure-passthrough path end-to-end.)

## Inputs

### From Previous Tasks

- `tests/compression-runtime-parity/fixtures/tier3-oversized-section/` (from T01) — the fixture this task exercises. Contains `config.yml` (with `tier3.enabled: true` + section_budget tuned to fire T3), `input/payload-input.txt` (with a ~25 KB Knowledge section that survives T1+T2), and `README.md`.
  - Key API: stage via `bash scripts/verify/_helpers/m018-p07-build-fixture.sh <runtime> tier3-oversized-section` → prints staged root path on stdout.
  - Key types: staged root contains `.orchestrator/config.yml`, `.orchestrator/milestones/M-FIXTURE/execution-log.jsonl` (empty initially), and `input/payload-input.txt`.
- `scripts/verify/_helpers/m018-p07-build-fixture.sh` (from T01) — fixture-staging helper. T02's runner invokes it with `<runtime> tier3-oversized-section` per per-runtime iteration.

### From Disk (Pre-existing)

- `scripts/dispatch/lib/tier3-llm-call.sh` — provider-resolution ladder. T02's stub takes the operator-binary path because `ORCH_TIER3_LLM_BIN` is set + executable. Read once at integration time to confirm the four-flag contract has not drifted.
- `scripts/dispatch/build-context.sh` `_bc_apply_tier3` — the helper the parity runner exercises. Routes through `tier3-llm-call.sh`; honors `ORCH_TIER3_LLM_BIN`.
- `scripts/dispatch/dispatch-interface.sh` — Tier 3 helper may also invoke this directly (per P06/T01 wiring); the parity runner does not assert on the exact routing path through dispatch-interface — it asserts the LLM call surfaces in the stub.

## Constraints

- **AD-19 / AP-009**: no compound chains > 2 at task-plan Check: line level. Inside script bodies, the MEM004 emitter-internal carve-out applies (single-pass awk, simple pipes for line-counting, plain `$(cmd)` substitutions where the inner command does not pipe).
- **CON-1 / Constitution Principle VI**: T02 modifies no production code. New files only under `scripts/diagnostics/` and `tests/compression-runtime-parity/_stubs/`. Pre-M018 sentinel byte-identity is preserved.
- **CON-5 (additive emitters)**: the new `runtime_parity` JSONL record_type is additive (already used by T01). Existing record schemas (payload_breakdown / dispatch_usage / unit_close / tier3_failed / tier3_skipped) unchanged.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand.
- **Hermetic stub**: `ORCH_TIER3_LLM_BIN` takes precedence over any installed `claude` CLI in `tier3-llm-call.sh`'s provider-resolution ladder. The stub is the only LLM-call surface exercised in the parity runner; no real LLM is invoked.
- **Always-exit-0 advisory pattern**: the runner always exits 0 even on divergence; FAIL surfaces via the `regression_flag:` line.
- **Failure-passthrough invariant**: `--fail-stub` exercises FR-9. The dispatch MUST survive (exit 0); the JSONL MUST contain `tier3_failed`. The verifier in T03 asserts both.

## Expected Output

After T02 lands:

- `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` exists, is executable, and `bash -n` clean.
- `tests/compression-runtime-parity/_stubs/README.md` exists.
- `scripts/diagnostics/m018-runtime-parity-tier3.sh` exists and `bash -n` clean.
- `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor` runs end-to-end, prints per-runtime routing lines, and exits 0 with `regression_flag: none` on a clean checkout.
- `bash scripts/diagnostics/m018-runtime-parity-tier3.sh --runtimes claude-code,codex,cursor --fail-stub` exercises the FR-9 failure-passthrough path and exits 0.
