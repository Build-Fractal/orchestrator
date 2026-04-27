# tests/fixtures/m027-p01

Deterministic input/output fixtures for M027/P01 verifier suite.

## Files

- `intensity-recommend-baseline-text.txt` — the canonical pre-T02
  byte-stable 8-key=value output of `intensity-recommend.sh` when given
  a fixed `--analyze-output` and `--profile-output` (no fork to
  `intensity-analyze.sh` or `detect-capabilities.sh`). The
  `m027-p01-intensity-text-back-compat.sh` verifier diffs the first 8
  lines of live output (with `--no-cost-annotation`) against this
  fixture to gate Truth #8 (FR-7 / SC-3 byte-stability).

  Inputs that produce this baseline:
  - `--analyze-output`: `scope=moderate / risk_level=medium /
    complexity=moderate / risk_signals=none /
    recommended_intensity=Standard`
  - `--profile-output`: `cap_score=1`
  - `--description`: `test`

  If T02 changes the output shape of those 8 lines, this fixture must
  be regenerated and the change explicitly justified — the byte-stable
  contract is the entire point of the verifier.
