---
schema_version: "1.0"
type: empirical-baseline-corpus
milestone: "M031"
phase: "P00"
created_at: "2026-05-01"
stratification_constraint: "AD-15"
---

# M031 Empirical Baseline Corpus

Stratification per AD-15 (CONTEXT.md):
- 5 historical-JSONL-derived tasks: 2 high-cost, 2 medium-cost, 1 low-cost
- 5 synthetic edge-case tasks: empty / 1-file / 5-file / 10-file / doc-only
- 10 spread across ≥3 categories (bugfix / doc / feature)
- Total: 20 entries

Each entry's `task_id` corresponds to `task-NN.txt` under this directory.
`pre-m031-stub.sh` reads each fixture and emits one JSONL record to
`pre-m031-baseline.jsonl` (frozen at P00 close per AD-14 single-window).

Cost-class derivation: historical entries draw their `cost_class` from
the `duration_s` field on `unit_close` records in
`.orchestrator/milestones/M*/execution-log.jsonl` (the on-disk
`total_tokens` / `re_dispatch_count` fields named in the AD-15 plan
guidance are absent from the live records, so `duration_s` is the
nearest observed cost proxy — high ≥ 5000s, medium 2500–4500s,
low ≤ 60s). Synthetic entries carry `cost_class: n/a` because the
edge-case dimension is fan-out / category, not observed cost.

Section references in this manifest's prose use scaffold-placeholder
markers (per CON-7 / D020 token hygiene) rather than embedding the
literal open-bracket-TODO byte pattern.

## Entries

| task_id   | category | cost_class | provenance                                 | rationale |
|-----------|----------|------------|--------------------------------------------|-----------|
| task-01   | bugfix   | high       | M028/P03/T05 (historical)                  | duration_s=7200 (autonomous-hardening v3 phase task); top-of-distribution observed cost; representative high-cost rediscovery shape |
| task-02   | feature  | high       | M027/P02/T04 (historical)                  | duration_s=5100 (cost+quality observability surfaces); multi-subsystem touch; representative high-cost feature work |
| task-03   | feature  | medium     | M020/P04/T02 (historical)                  | duration_s=3300 (knowledge-layer maturation phase task); medium-band observed cost; multi-file touch |
| task-04   | feature  | medium     | M013/P04/T05 (historical)                  | duration_s=3000 (GitHub native integration phase task); medium-band cost; doc + script changes |
| task-05   | bugfix   | low        | M026/P01/T03 (historical)                  | duration_s=8 (conversus-OSS migration follow-up); bottom-of-distribution observed cost; small-touch correction |
| task-06   | feature  | n/a        | synthetic (empty)                          | Edge: no touched files; degenerate plan |
| task-07   | bugfix   | n/a        | synthetic (1-file)                         | Edge: smallest non-degenerate |
| task-08   | feature  | n/a        | synthetic (5-file)                         | Edge: medium fan-out |
| task-09   | feature  | n/a        | synthetic (10-file)                        | Edge: largest fan-out |
| task-10   | doc      | n/a        | synthetic (doc-only)                       | Edge: markdown-only diff |
| task-11   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
| task-12   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
| task-13   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
| task-14   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
| task-15   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
| task-16   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
| task-17   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |
| task-18   | bugfix   | n/a        | synthetic (bugfix)                         | Category-coverage filler |
| task-19   | doc      | n/a        | synthetic (doc)                            | Category-coverage filler |
| task-20   | feature  | n/a        | synthetic (feature)                        | Category-coverage filler |

## Consuming SCs

- SC-2 (M031 amended per AD-13): aggregate cost is reported across this
  20-task corpus in T03's harness output.
- SC-3 (M031 amended per AD-17): the Quick-profile compression-tier
  fixture references the M018 tier-1 `inline_threshold_tokens` value;
  see `references/RUNTIME-ASSUMPTIONS.md` ("M018 Tier-1
  inline_threshold_tokens" section) for the resolution path.
- SC-11 / SC-13 / SC-14 / SC-15 / SC-16 — see `specs/034-right-sized-entry/spec.md`.

## Stratification rationale

AD-15 mandates a three-stratum corpus so the empirical baseline cannot be
gamed by drawing only from one cost regime or one task shape. Each stratum
answers a distinct question about pre-M031 behavior:

- **≥5 historical-derived (task-01..task-05)** — these are the only entries
  whose `cost_class` is grounded in observed production behavior. They
  anchor the baseline to the live distribution: two high-cost
  representatives (task-01, task-02) dominate the upper tail; two
  medium-cost representatives (task-03, task-04) fix the body of the
  distribution; one low-cost representative (task-05) anchors the lower
  tail. Without this stratum the baseline would be synthetic-only and
  could not legitimately claim to represent rediscovery cost.
- **≥5 synthetic edge cases (task-06..task-10)** — these probe shape
  dimensions that the historical sample does not cover by construction
  (empty plan, single-file plan, doc-only plan, fan-out boundaries at 5
  and 10 files). They are deliberately marked `cost_class: n/a` because
  their value is dimensional coverage, not cost realism.
- **≥10 category-spread fillers (task-11..task-20)** — these guarantee
  the AD-15 "≥3 categories" floor (bugfix / doc / feature) holds even
  if the historical and synthetic strata cluster on a single category.
  They are the corpus's category-coverage insurance policy.

Cost-class proxy substitution: AD-15's plan-time guidance named
`total_tokens` and `re_dispatch_count` as the intended cost signal. Both
fields are absent from the on-disk `unit_close` JSONL records produced
by `scripts/dispatch/run-unit.sh`, so the manifest substitutes
`duration_s` (the nearest observed cost proxy that IS recorded). The
substitution is documented openly here rather than silently re-mapped,
so future operators can audit the proxy choice. Bands: high ≥ 5000s,
medium 2500–4500s, low ≤ 60s. The bands were chosen by inspection of
the live distribution across M020/M026/M027/M028 phase tasks, not by
theoretical thresholds — they describe what the on-disk corpus
actually looks like.

## Provenance audit trail

Each historical entry's provenance triple resolves to a real
`unit_close` record on disk:

- task-01 → `M028/P03/T05` → `.orchestrator/milestones/M028/execution-log.jsonl` (autonomous-hardening v3 phase task; duration_s=7200)
- task-02 → `M027/P02/T04` → `.orchestrator/milestones/M027/execution-log.jsonl` (cost+quality observability; duration_s=5100)
- task-03 → `M020/P04/T02` → `.orchestrator/milestones/M020/execution-log.jsonl` (knowledge-layer maturation; duration_s=3300)
- task-04 → `M013/P04/T05` → `.orchestrator/milestones/M013/execution-log.jsonl` (GitHub native integration; duration_s=3000)
- task-05 → `M026/P01/T03` → `.orchestrator/milestones/M026/execution-log.jsonl` (conversus-OSS migration follow-up; duration_s=8)

Synthetic entries (task-06..task-20) carry `provenance: synthetic (...)`
and have no JSONL origin by construction — their provenance is the
fixture file `task-NN.txt` co-located in this directory. The pre-M031
stub treats both provenance kinds identically; only the manifest
distinguishes them for audit purposes.

## Reproduction

To re-derive this manifest if the corpus needs refreshing:

1. Re-scan `.orchestrator/milestones/M*/execution-log.jsonl` for
   `unit_close` records with non-null `duration_s` and bucket by the
   bands declared above (high ≥ 5000s / medium 2500–4500s / low ≤ 60s).
2. Pick 2 high / 2 medium / 1 low representatives, preferring tasks
   whose phase plans touch multiple subsystems (so the rediscovery
   cost signal is non-trivial).
3. Author 5 synthetic edge-case fixtures (empty / 1-file / 5-file /
   10-file / doc-only) as `task-NN.txt` files; each is a free-text
   task description, not an executable artifact.
4. Author 10 category-spread fillers (bugfix / doc / feature) so the
   AD-15 ≥3-category floor holds regardless of how the historical and
   synthetic strata distribute.
5. Update the entries table above, preserving the `task_id` ordering
   (task-01..task-05 historical, task-06..task-10 synthetic edge,
   task-11..task-20 category fillers). Re-run
   `bash tools/verify/p00-corpus-manifest-shape.sh` and the AD-14
   single-window discipline check (`verify-baseline-ordering.sh`) to
   confirm the refreshed corpus still passes shape gates and was
   committed before any P01 surface changes.
