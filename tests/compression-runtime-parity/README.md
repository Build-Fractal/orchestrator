# Compression runtime-parity corpus (M018/P07)

Fixture corpus for the multi-runtime compression-parity diagnostics.
Proves that the bash-only compression tiers (knowledge-aware filter,
Tier 1 microcompact, Tier 2 snip) produce **byte-identical** compressed
payloads under every supported runtime (`claude-code`, `codex`,
`cursor`), and that Tier 3's auto-compact dispatches correctly through
`scripts/dispatch/dispatch-interface.sh` under each runtime via a
deterministic stub.

## Purpose

- **Byte-equality proof (T01).** The bash code path of `_bc_apply_filter`
  / `_bc_apply_tier1` / `_bc_apply_tier2` does not branch on
  `ORCH_BACKEND`. The runner exercises each fixture under all three
  simulated runtimes and asserts SHA-256 equality of the post-pipeline
  payload bytes.
- **Tier 3 routing proof (T02).** With `ORCH_TIER3_LLM_BIN` pointing at
  the deterministic stub at `_stubs/tier3-stub-llm.sh`, the Tier 3
  helper's LLM call is byte-deterministic across runtimes; the runner
  asserts that the stub fires once per fixture per runtime and that the
  captured output replaces the section in the payload.

## Corpus structure

```
tests/compression-runtime-parity/
  README.md                                    <- this file
  _stubs/                                      <- T02-managed
    tier3-stub-llm.sh                          <- T02 ships this
  fixtures/
    filter-mixed-status/                       <- T01: filter (US-2)
      config.yml
      knowledge/                               <- mixed status entries
      input/payload-input.txt
      README.md
    tier1-oversized-tool-result/               <- T01: Tier 1 (US-3)
      config.yml
      input/payload-input.txt
      README.md
    tier2-oversized-section/                   <- T01: Tier 2 (US-4)
      config.yml
      input/payload-input.txt
      README.md
    tier3-oversized-section/                   <- T02: Tier 3 (US-5)
      config.yml
      input/payload-input.txt
      README.md
```

Each fixture isolates one tier under test. Other tiers are disabled in
the fixture's `config.yml` so byte-equality across runtimes is provable
on the tier under test alone.

## How to add a fixture

1. Copy an existing fixture directory under `fixtures/` to a new slug.
2. Tune `config.yml` so the tier under test fires (and only that tier).
3. Rewrite `input/payload-input.txt` to exercise the contract.
4. Update the fixture's `README.md` naming what it exercises.
5. Re-run `bash scripts/diagnostics/m018-runtime-parity.sh` and confirm
   `parity fixture=<slug> result=match runtimes=3`.

The fixture-staging helper `scripts/verify/_helpers/m018-p07-build-fixture.sh`
auto-discovers any directory under `fixtures/` — no registry to update.

## Byte-identical contract

The parity runner asserts `sha256(post-pipeline payload bytes)` is
identical across all simulated runtimes per fixture. Any divergence is
either a bug to fix or a row to document in
`references/RUNTIME-ASSUMPTIONS.md` (T03).

## Stub usage (T02 forward reference)

`_stubs/tier3-stub-llm.sh` is a deterministic four-flag-honoring shim
the T02 runner exports as `ORCH_TIER3_LLM_BIN`. It writes a fixed string
to `--output` and exits 0 so Tier 3's behavior is byte-deterministic
across runtimes; T01 does not exercise it.
