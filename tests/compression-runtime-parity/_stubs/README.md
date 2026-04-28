# Compression Runtime-Parity Stubs

Deterministic test stubs used by the M018/P07 multi-runtime parity
diagnostics under `scripts/diagnostics/m018-runtime-parity-tier3.sh`.

## `tier3-stub-llm.sh`

Deterministic stub for `scripts/dispatch/lib/tier3-llm-call.sh`'s
operator-binary contract.

### Purpose

Lets the Tier 3 routing-parity runner assert byte-deterministically
that `_bc_apply_tier3` routes its LLM call through `tier3-llm-call.sh`
under every simulated runtime (`ORCH_BACKEND` ∈ `claude-code|codex|cursor`)
without invoking a real LLM.

### Contract

The shim invokes the operator binary with this exact four-flag shape
(see `scripts/dispatch/lib/tier3-llm-call.sh` provider 1):

```
"$ORCH_TIER3_LLM_BIN" \
  --prompt-file <path> \
  --output      <path> \
  --max-tokens  <integer> \
  --timeout     <integer>
```

The stub honors all four flags, ignores `--max-tokens` and `--timeout`
(the deterministic body is fixed at "42 tokens"), reads `--prompt-file`
size to embed an `input_tokens=<bytes>` marker, and writes the
following envelope to `--output`:

```
<!-- compressed:tier3 model=stub-deterministic input_tokens=<N> output_tokens=42 -->
stub-deterministic-summary-body
```

`<N>` is the byte size of the rendered prompt file. The body is the
literal `stub-deterministic-summary-body`. Exit 0 on success.

### Failure mode (`ORCH_TIER3_STUB_FAIL=1`)

When `ORCH_TIER3_STUB_FAIL=1`, the stub prints a one-line stderr
message and exits 1. This exercises the FR-9 failure-passthrough path
in `_bc_apply_tier3`:

- `tier3-llm-call.sh` forwards the non-zero exit code.
- `_bc_apply_tier3` leaves `_tier3_stats.txt` at the
  `savings_tokens=0 invocations=0` zero-baseline.
- `_bc_emit_tier3_event` appends a `tier3_failed
  reason=llm-call-nonzero` JSONL record to the staged execution log.
- The dispatch proceeds with Tier 2's bytes unchanged (`build-context.sh`
  exits 0).

The parity runner asserts both the JSONL `tier3_failed` line and the
zero exit on `--fail-stub`.

### Invocation counter

Each fire (success **and** failure) appends exactly one line to
`$ORCH_TIER3_STUB_INVOCATIONS_LOG`:

```
<iso8601>\t<runtime>
```

`<runtime>` is `${ORCH_BACKEND:-unknown}`. Defaults to `/dev/null`
when the env var is unset, so manual invocations do not require a
log file. The parity runner truncates the log per-runtime then
counts lines after `build-context.sh` returns.

### Why operator-binary path

`tier3-llm-call.sh`'s provider-resolution ladder is:

1. `$ORCH_TIER3_LLM_BIN` set + executable — invoke verbatim.
2. `$ORCH_BACKEND=claude-code` + `claude` on PATH — invoke `claude --print`.
3. Otherwise — exit 1 (caller's failure-passthrough fires).

Setting `ORCH_TIER3_LLM_BIN=<absolute-path-to-this-stub>` takes the
**highest-precedence** branch under every runtime, so:

- The parity runner is hermetic — no installed `claude` CLI is ever
  invoked.
- The stub's deterministic envelope writes the same bytes for
  `ORCH_BACKEND=claude-code`, `ORCH_BACKEND=codex`, and
  `ORCH_BACKEND=cursor`.
- The runtime parameter cycles only the env-var value the helper
  observes — proving the routing surface itself is runtime-agnostic.

### Bash 3.2 / AP-009

Single-script-file shape. No `declare -A`, no process substitution,
no compound chains > 2, no `$(... | ...)`. `bash -n` clean.
