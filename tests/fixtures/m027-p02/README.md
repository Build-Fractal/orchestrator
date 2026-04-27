# M027/P02 fixtures

Baseline fixtures for the M027/P02/T04 verifier suite.

## status-quiet-baseline.txt

Captures the verbatim post-`## Next Action` tail of `commands/status.md` (sections: Next Action, Concurrent Safety, Idempotency, Error Handling, Gotchas, Reference Files). The T04 `m027-p02-status-quiet-byte-identity.sh` verifier extracts the same range from the live `commands/status.md` (via `awk` from `## Next Action` through end-of-file) and `diff`s against this fixture.

This is the load-bearing post-M027 byte-identity baseline that gates CON-3 / SC-3: under `--quiet` (or `efficiency_footer: false`), no NEW content appears between the telemetry block and Next Action — the document tail starting at `## Next Action` must remain byte-identical to this fixture.

The fixture is updated only when intentional changes to those sections land via a follow-up commit; the verifier rejects accidental drift.
