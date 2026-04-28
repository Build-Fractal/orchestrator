# M018/P03 Tool-Result Fixture

This fixture exercises the Tier 1 microcompact paging path in
`scripts/dispatch/build-context.sh:_bc_apply_tier1`.

## Files

- `dispatch-payload-fixture.md` — a hand-crafted dispatch payload that
  contains:
  - A short `<tool-result command="ls -la /tmp/small.txt">` block whose
    body is well under the 1500-token threshold (passes through verbatim).
  - A large `<tool-result command="cat /tmp/big.log">` block whose body
    is ~15.6 KB (~3900 tokens) — comfortably over the 1500-token
    threshold (gets paged).
  - Surrounding manifest + Task Plan markdown so the file resembles a
    real assembled payload.

## Verifier consumers

- `scripts/verify/m018-p03-tier1-paging.sh` — asserts the big block is
  paged out and the small block is left alone; cache file written under
  `<dest>/cache/tool-results/<sha256>`.
- `scripts/verify/m018-p03-cache-reuse.sh` — replays the same fixture
  twice; asserts the cache file's mtime is preserved on the second pass.
- `scripts/verify/m018-p03-emitter-additivity.sh` — drives the captured
  payload through the live `_bc_apply_tier1` shim and inspects the stats
  file plus the additive `tier1_savings_tokens` / `tier1_invocations`
  fields on the emitter's printf in `build-context.sh`.
- `scripts/verify/m018-p03-preservation-self-check.sh` — replays the
  fixture with a stubbed `pres_check_section` that always returns 1 to
  exercise the failure-path passthrough + violation-emit code.

## Cross-references

- The fixture-staging helper `scripts/verify/_helpers/m018-p03-build-fixture.sh`
  copies this payload into a hermetic tmp orchestrator root so the
  verifiers can drive `_bc_apply_tier1` against a controlled state.
- The big-block body uses a constant repeating marker
  (`repeating-content-marker M018-P03-T03-BIG`) so cache hits are
  trivially reproducible across two runs.
