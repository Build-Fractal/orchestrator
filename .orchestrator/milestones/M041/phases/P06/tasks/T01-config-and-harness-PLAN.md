---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M041"
name: "config-driven repo + threshold + corpus-validation harness"
depends_on: []
---

## Prerequisites

- `scripts/state/read-config.sh` exists with a fixed VALID_KEYS allow-list and per-block awk resolvers for dotted keys
- `scripts/diagnostics/search-issues.sh` + `file-issue.sh` exist (from P02) with hardcoded `repo="Build-Fractal/orchestrator"`
- `templates/orchestrator-config-default.yml` is the config-default SSOT

## Description

Make detective's target repo and match threshold config-driven, add a `meets_threshold` field to search results, and ship the #Q-1 corpus-validation harness.

## Steps

1. **read-config.sh**: add `detective.repo detective.match_threshold` to VALID_KEYS; add a `detective:`-block awk walker mirroring the `display_thresholds.*` resolver (project config → defaults template → `null`). Use `substr(line, index(line, ":")+1)` for the value so repo strings survive.
2. **orchestrator-config-default.yml**: add a `detective:` block — `repo: Build-Fractal/orchestrator`, `match_threshold: 3` — with a comment marking the threshold provisional/unvalidated (RISK-06 / #Q-1).
3. **search-issues.sh**: init `repo=""` + add `--threshold` (init `threshold=""`); after arg parse resolve `--flag > config > default` for both; pass `--argjson th` to the jq scorer and add `meets_threshold: ($score >= $th)`; in the no-jq fallback compute `meets` and emit `"meets_threshold":<bool>`.
4. **file-issue.sh**: init `repo=""`; after arg parse resolve `--repo > detective.repo config > default`.
5. **detective-validate-threshold.sh** (new): resolve repo+threshold; fetch corpus (GH_MOCK_DIR or `gh issue list --state all`); if `n < --min-corpus` (default 5) emit `insufficient corpus` + caution and exit 0; else compute pairwise keyword-overlap false-positive rate via jq and emit `verdict=PASS|WARN|ESCALATE` (<20 / 20-40 / >40). Requires jq; degrade cleanly if absent.
6. **detective.md**: document the `meets_threshold` decision in Workflow step 3, add the Match-threshold (#Q-1) subsection, update the repo-resolution gotcha, add the new scripts to Referenced Scripts.

## Must-Haves

- `detective.repo` / `detective.match_threshold` resolve via read-config.sh
- `search-issues.sh` emits `meets_threshold` driven by config/flag
- `file-issue.sh` resolves repo from config when `--repo` omitted
- harness computes a verdict above the floor and degrades to `insufficient corpus` below it

## Verification

```bash
bash tools/verify/m041-p06-phase-suite.sh
```

```bash
bash tools/verify/m041-p02-phase-suite.sh
```

## Inputs

### From Disk (Pre-existing)

- `scripts/state/read-config.sh` — VALID_KEYS + dotted-key awk resolver convention (display_thresholds.* is the template)
- `scripts/diagnostics/search-issues.sh` + `file-issue.sh` (from P02)
- `tests/fixtures/detective/gh-mock/issue-list-response.json` — 3-issue corpus for harness + meets_threshold tests

## Constraints

- Bash 3.2+ compatible (CON-3); awk resolver consistent with existing dotted-key blocks
- Match-threshold default stays provisional/unvalidated until the harness reports PASS against a real corpus (#Q-1 / RISK-06)
- Harness is advisory: exit 0 always

## Expected Output

- read-config.sh + config-default carry detective.* keys
- search-issues.sh emits meets_threshold; file-issue.sh + search-issues.sh honor detective.repo
- detective-validate-threshold.sh present; against the live (empty) tracker reports `insufficient corpus (n=0 floor=5)`
- P06 suite `pass=3 fail=0`; P02 suite still `pass=5 fail=0`
