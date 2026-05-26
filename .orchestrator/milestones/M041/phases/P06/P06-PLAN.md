---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M041"
goal: "Drain the two M041 deferred follow-ups: config-driven repo + match-threshold (detective.repo / detective.match_threshold) and the #Q-1 corpus-validation harness"
demo_sentence: "detective.repo and detective.match_threshold in config drive search/file behavior; search-issues.sh --threshold marks results via meets_threshold; detective-validate-threshold.sh reports the empirical false-positive rate or 'insufficient corpus' when the tracker is empty."
risk: "low"
depends_on: ["P05"]
---

## Must-Haves

### Truths

- `read-config.sh detective.repo` resolves to the defaults-template value and `file-issue.sh` honors it when `--repo` is omitted
  - Check: `bash tools/verify/m041-p06-config-repo.sh`
- `read-config.sh detective.match_threshold` resolves and `search-issues.sh` emits a `meets_threshold` boolean driven by it (overridable with `--threshold`)
  - Check: `bash tools/verify/m041-p06-match-threshold.sh`
- `detective-validate-threshold.sh` computes a false-positive verdict when the corpus clears the floor and reports `insufficient corpus` when it does not
  - Check: `bash tools/verify/m041-p06-validate-harness.sh`

### Artifacts

- `scripts/diagnostics/detective-validate-threshold.sh` (min 40 lines, contains "false_positive_rate")
- `scripts/state/read-config.sh` (modify — detective.* keys)
- `templates/orchestrator-config-default.yml` (modify — detective: block)

### Key Links

- `scripts/diagnostics/search-issues.sh` → `scripts/state/read-config.sh` (repo + threshold resolution)
- `scripts/diagnostics/detective-validate-threshold.sh` → `scripts/state/read-config.sh` (repo + threshold resolution)

## Tasks

### T01: config-driven repo + threshold + corpus-validation harness

Single cohesive task — read-config.sh extension, config-default block, repo+threshold resolution in search-issues.sh + file-issue.sh, meets_threshold field, the validation harness, detective.md docs, and verifiers.

## Task Dependencies

T01 (single task)

## Files Likely Touched

- `scripts/state/read-config.sh` (modify)
- `templates/orchestrator-config-default.yml` (modify)
- `scripts/diagnostics/search-issues.sh` (modify)
- `scripts/diagnostics/file-issue.sh` (modify)
- `scripts/diagnostics/detective-validate-threshold.sh` (create)
- `commands/detective.md` (modify)
- `tools/verify/m041-p06-config-repo.sh` (create)
- `tools/verify/m041-p06-match-threshold.sh` (create)
- `tools/verify/m041-p06-validate-harness.sh` (create)
- `tools/verify/m041-p06-phase-suite.sh` (create)

## Design Notes

`read-config.sh` gates keys against a fixed allow-list and resolves dotted keys via per-block awk walkers (the `display_thresholds.*` / `model_routing_regression.*` pattern). `detective.repo` + `detective.match_threshold` follow that exact convention: project `.orchestrator/config.yml` wins, then `templates/orchestrator-config-default.yml`, then `null` so callers apply their built-in fallback.

Repo + threshold resolution in both scripts is `--flag > config > default` via an empty-string sentinel (init to `""`, resolve after arg parse).

The match threshold default (3) is **provisional and unvalidated** per conversus RISK-06 / spec #Q-1 — orchestrator-domain vocabulary overlaps heavily, so the real false-positive rate must be measured against the actual corpus. The harness does that measurement; against today's empty `Build-Fractal/orchestrator` tracker it reports `insufficient corpus (n=0 floor=5)`, so the threshold stays provisional and the spec's `--yes` automation caution remains in force. The harness is ready to emit an empirical PASS/WARN/ESCALATE verdict once the tracker accumulates ≥ 5 issues.
