# M027/P03 fixtures

Deterministic fixtures backing the M027/P03 verifier suite (anomaly detection
+ config drift). All fixtures use the `M999` milestone sentinel ID so live
helper invocations against them cannot pollute real `.orchestrator/milestones/`
data and the read-only invariant (FR-12 / CON-1) is trivially satisfied.

- `doctor-suppressed-baseline.txt` — verbatim post-`## Referenced Scripts`
  tail of `commands/doctor.md` (the document tail, since `## Referenced
  Scripts` is the last canonical section). Load-bearing baseline for the
  byte-identity verifier (`scripts/verify/m027-p03-doctor-byte-identity.sh`,
  shipped in T04). Intentional changes to the document tail must be
  reflected here via a follow-up commit, otherwise the verifier rejects the
  drift as accidental. Update protocol: re-run
  `awk '/^## Referenced Scripts/,EOF' commands/doctor.md > tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`
  in the same commit as the doctor.md edit.

- `anomaly-fixture.jsonl` — 9 hand-crafted `unit_close` records under
  milestone `M999`. T01–T08 are siblings (300s / $0.10 / pass_rate 1.0 /
  retry 0); T09 is an 8x cost (and 8x duration) outlier with
  `retry_count=3` and `verification_pass_rate=0.4`, exercising all three
  flagging conditions on the same row so T04's Goodhart-pairing verifier
  (`scripts/verify/m027-p03-anomaly-goodhart-pairing.sh`) can assert the
  flagged row contains BOTH cost AND quality tokens (FR-9 / CON-4). To run
  the helper against this fixture, the verifier sets up a `mktemp -d` tree,
  copies the fixture into
  `<tmp>/.orchestrator/milestones/M999/execution-log.jsonl`, and invokes
  `check-anomalies.sh --milestone M999` with the rollup engine pointed at
  the temp tree.
