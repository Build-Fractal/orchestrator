# P05 Parity Fixtures

Golden outputs captured from the pre-refactor dispatch scripts (before T02/T03
ran) and the harness that validates the post-refactor scripts against them.

## Files

- `golden-payload-M004-P04-T04.md` — output of pre-refactor
  `build-context.sh .specify/orchestrator M004 P04 T04`. T02 parity target.
- `golden-compressed-budget2000.md` — output of pre-refactor
  `compress-payload.sh --budget 2000` fed with the golden payload above.
  T03 parity target.
- `run-parity.sh` — end-to-end parity + event-emission harness. Run from
  repo root: `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`.
  Exits 0 iff every parity check passes. Known-pre-existing issues are
  reported as `XFAIL:` and do not count toward the failure tally.
- `README.md` — this file.

## Normalization Rules

Manifest table columns that legitimately vary between runs are stripped
before diff:

- `| <start>-<end> |` becomes `| LINES |` — line ranges shift as upstream
  payload sections grow or shrink.
- `~<N>` becomes `~TOKENS` — token estimates round to the nearest 100 and
  are not load-bearing for parity.
- `(<N> entries)` becomes `(N entries)` — knowledge entry counts fluctuate
  as the knowledge base is curated.

Everything else MUST match byte-for-byte. If a parity check fails, the
harness prints a unified diff of the first 60 lines of divergence to
stderr so the regression is immediately visible.

## Check Groups

`run-parity.sh` runs six check groups in order:

1. **build-context parity** — refactored `scripts/dispatch/build-context.sh`
   vs `golden-payload-M004-P04-T04.md` after normalization.
2. **compress-payload parity** — refactored `scripts/dispatch/compress-payload.sh`
   fed with the refactored build-context output at `--budget 2000`, vs
   `golden-compressed-budget2000.md` after normalization.
3. **select-model defaults** — `scripts/dispatch/select-model.sh` for all
   three tiers (heavy / standard / light) against the expected model +
   budget pairs from `templates/routing.yaml`.
4. **select-model --list-fallback** — all three tiers. Light tier must
   return the empty string (no fallbacks defined).
5. **select-model --next-fallback** — chain walk. Heavy tier only.
   opus -> sonnet, sonnet -> haiku, haiku -> exit non-zero (chain
   exhausted).
6. **Event + RESULT emission audit** — each refactored script must emit
   at least one `EVENT:` line and exactly one `RESULT:` line on stderr.

## Known Issues (P06 Scope — reported, not patched)

- **build-context.sh EVENT emission swallowed.** The recipe-resolved
  branch routes `emit_event` calls through `>/dev/null 2>&1 || true`, a
  pre-existing artifact of byte-for-byte parity with the pre-refactor
  script. The harness reports this as `XFAIL:` in check group 6 so the
  regression surface stays visible, but does not count it toward the
  failure tally. P06 will standardise emit_event routing across all
  dispatch scripts (all emissions to stderr, no /dev/null swallows).

## Regeneration

The golden fixtures are intentionally checked in. Only regenerate them if
the expected output intentionally changes (for example, the default
recipe is updated to add a new section). When regenerating, capture them
from a clean checkout of the pre-change commit, NOT from the post-change
tree — otherwise the harness loses its ability to detect regressions.

```
# Regeneration recipe (documentation only; do not run without review):
#   git checkout <pre-change-commit>
#   bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
#       > .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
#   bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
#     | bash scripts/dispatch/compress-payload.sh --budget 2000 \
#     > .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md
#   git checkout -
```

## Self-Cleaning Contract

The harness allocates every temp file inside a private
`mktemp -d -t run-parity-XXXXXX` directory and wipes that directory on
`trap EXIT INT TERM HUP`. No temp files, no state pollution, and the
real M004 execution log is never touched — the harness does not source
`run-context.sh` or call `emit_event`, only `emit_result` once on
completion.
