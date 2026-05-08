---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M020"
name: "Jaccard validation report + demo-sentence verification"
depends_on: ["T03", "T04"]
---

## Prerequisites

- T03: `scripts/knowledge/graduate.sh` exists and exits 0 with `GRADUATED:`
  on a candidate fixture entry.
- T04: `scripts/knowledge/lib/jaccard.sh` exists with `pairwise_jaccard` +
  `validate` subcommands, and the `validate` subcommand writes a stub
  report header + iteration loop output.

This task is the demo-sentence verification — the sentence the phase is
defended on:

> Running `bash scripts/knowledge/graduate.sh --rationale 'test'
> <entry-id>` flips an entry's `status:` from `candidate` to `graduated`,
> and `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a
> validation report at
> `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`
> confirming the 0.7 threshold + CON-5 feature vector against the live
> knowledge tree.

T05 enriches the report with the threshold-recommendation analysis,
exercises the demo path against the live tree, and assembles the
incremental-migration verifier.

## Description

Three deliverables:

1. **Run the demo path** end-to-end: invoke `bash
   scripts/knowledge/lib/jaccard.sh validate
   /Users/brettkellgren/Sites/orchestrator/knowledge/` against
   the live tree and capture pairwise similarities.
2. **Enrich the report** at
   `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`
   with: observed pair-count distribution, threshold recommendation
   (confirm or adjust the A-5 default of 0.7), and a feature-vector
   sanity check (does CON-5 produce useful clusters or is the vector too
   narrow / too noisy?).
3. **Ship the demo-sentence + migration-incremental verification scripts**
   that the phase plan's must-haves cite.

## Steps

### Step 1: Run the demo against the live tree

```bash
bash /Users/brettkellgren/Sites/orchestrator/scripts/knowledge/lib/jaccard.sh \
  validate /Users/brettkellgren/Sites/orchestrator/knowledge/
```

Confirm stdout reports `WROTE: .../jaccard-validation-report.md` and the
file exists with the T04 stub header + the iteration-loop output (pairs
above 0.5 listed under "Pairwise Similarities").

### Step 2: Enrich the report

Open the report at
`/Users/brettkellgren/Sites/orchestrator/.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`
and append (or replace the placeholder section) with the following analysis
based on actual observed similarity distribution:

```markdown
## Pair-count distribution

| Bucket | Count |
|--------|-------|
| ≥ 0.9 (near-identical) | <N> |
| 0.7 – 0.9 (cluster candidates at default threshold) | <N> |
| 0.5 – 0.7 (sub-threshold but suspicious) | <N> |
| < 0.5 (distinct) | <N> |

Total pairs evaluated: <N> (= n*(n-1)/2 where n = entry count).

## Threshold Recommendation

**Recommendation**: <retain default 0.7 | lower to <X> | raise to <X>>

Rationale: <observed cluster density at 0.7 produces <K> clusters across
<N> entries — <healthy / too-coarse / too-fine>. Adjust to <new> if K is
out of band.>

## Feature-Vector Sanity Check (CON-5)

The CON-5 feature vector (`title` + `topic` + `tags[]` + first-paragraph
words capped at 50 tokens) was exercised against <N> entries.

- Average tokens per entry after dedup: <N>
- Pairs with `intersection=0` AND `union>0`: <N> (ideally low — high count
  means the vector is too sparse)
- Pairs that visibly cluster the same topic: <names>
- Pairs that visibly miss an obvious cluster: <names if any>

Verdict: <CON-5 vector is fit-for-purpose | recommend extending vector to
include <X> in M020/P05>.

## Demo-sentence verification

`bash scripts/knowledge/graduate.sh --rationale "test" <fixture-id>`
exercised against an isolated fixture flips `status:` from `candidate` to
`graduated`. Verified by `scripts/verify/m020-p01-graduate-single-entry.sh`
(4/4 cases PASS).

`bash scripts/knowledge/lib/jaccard.sh validate knowledge/` exercised
against the live tree wrote this report. Verified by
`scripts/verify/m020-p01-jaccard-validation-report.sh` (asserts the report
exists at the canonical path AND contains threshold + feature-vector
sections).

Demo sentence: PASS.
```

Fill in the `<N>` values, the `<X>` recommendation, and the named pairs
based on the actual computed output.

If the observed cluster density at threshold 0.7 produces **0 clusters**
(everything below threshold) OR **a single clump containing >50% of
entries** (everything above threshold), the report MUST recommend an
adjusted threshold and explain the rationale. The "may adjust 0.7 default"
clause in the M020-ROADMAP P01 entry exists exactly for this case.

### Step 3: Ship the validation-report verifier

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-jaccard-validation-report.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-jaccard-validation-report.sh — assert the demo-sentence report
# exists at the canonical path and contains the load-bearing analysis
# sections. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT="$ROOT/.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md"

if [ ! -f "$REPORT" ]; then
  echo "FAIL: validation report missing at $REPORT"
  exit 1
fi

# Load-bearing tokens that must appear in the enriched report
for token in "threshold" "0.7" "CON-5" "feature vector" "Demo-sentence verification" "PASS"; do
  if ! grep -q "$token" "$REPORT"; then
    echo "FAIL: report missing token: $token"
    exit 1
  fi
done

# Threshold-recommendation section header must exist
if ! grep -q "^## Threshold Recommendation" "$REPORT"; then
  echo "FAIL: report missing 'Threshold Recommendation' section"
  exit 1
fi

# Feature-vector sanity-check section must exist
if ! grep -q "^## Feature-Vector Sanity Check" "$REPORT"; then
  echo "FAIL: report missing 'Feature-Vector Sanity Check' section"
  exit 1
fi

# Pair-count distribution table must exist
if ! grep -q "^## Pair-count distribution" "$REPORT"; then
  echo "FAIL: report missing 'Pair-count distribution' section"
  exit 1
fi

echo "PASS: jaccard validation report contract honored"
exit 0
```

`chmod +x` the script.

### Step 4: Ship the migration-incremental verifier

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-migration-incremental.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-migration-incremental.sh — assert P01 did NOT bulk-migrate the
# live knowledge tree. FR-10 + NG-3: pre-M020 entries gain `status:` only
# on next touch. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Count MEM*.md entries that already have a status: line.
# Expectation: at most a small number (only entries explicitly touched
# during P01 execution by graduate.sh against live entries — ideally 0
# since P01 testing uses tempdir fixtures).
total="$(find "$ROOT/knowledge" -type f -name 'MEM*.md' -not -path '*/archive/*' | wc -l | tr -d ' ')"
with_status="$(grep -l '^status:' "$ROOT"/knowledge/*/MEM*.md 2>/dev/null | wc -l | tr -d ' ')"

# Threshold: bulk migration would have written status: to ALL entries.
# Allow up to 5% of entries to legitimately bear status: (entries written
# by P01 testing or future P03 cluster operations against live entries).
# If more than 5% bear status: this phase, P01 has overstepped FR-10.
limit="$(awk -v t="$total" 'BEGIN{ printf "%d\n", (t*5)/100 + 1 }')"

if [ "$with_status" -gt "$limit" ]; then
  echo "FAIL: $with_status of $total live entries bear status: (limit $limit). P01 overstepped FR-10 (incremental on-touch migration only)."
  exit 1
fi

echo "PASS: migration is incremental — $with_status of $total entries bear status: (within $limit limit)"
exit 0
```

`chmod +x` the script.

### Step 5: End-to-end demo verification

Run the full demo path in sequence (each as its own AD-19-compliant
single-script invocation):

```bash
bash scripts/verify/m020-p01-graduate-single-entry.sh
bash scripts/verify/m020-p01-jaccard-validation-report.sh
```

Both must print `PASS:` and exit 0. Together they constitute the
demo-sentence verification: the first asserts the graduate flip, the
second asserts the validation report exists at the canonical path with
the load-bearing analysis sections.

## Must-Haves

- `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` exists, has `## Pair-count distribution`, `## Threshold Recommendation`, `## Feature-Vector Sanity Check`, and `## Demo-sentence verification` sections, and includes a literal `0.7` threshold reference + `CON-5` feature-vector citation.
- The threshold recommendation either confirms `0.7` or proposes an alternative with rationale.
- `scripts/verify/m020-p01-jaccard-validation-report.sh` exists, is executable, and exits 0.
- `scripts/verify/m020-p01-migration-incremental.sh` exists, is executable, and exits 0 — confirming P01 did NOT bulk-migrate the live tree.
- Demo sentence verifies: `m020-p01-graduate-single-entry.sh` PASS + `m020-p01-jaccard-validation-report.sh` PASS.

## Verification

```bash
bash scripts/verify/m020-p01-jaccard-validation-report.sh
bash scripts/verify/m020-p01-migration-incremental.sh
bash scripts/verify/m020-p01-graduate-single-entry.sh
```

All three must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/graduate.sh` (T03) — invoked by the graduate-half of
  the demo sentence. Key API: `graduate.sh --rationale <text> <entry-id>`
  → exit 0 + `GRADUATED:` line on flip.
- `scripts/knowledge/lib/jaccard.sh` (T04) — invoked by the validate-half
  of the demo sentence. Key API: `jaccard.sh validate <knowledge-root>` →
  writes report at the canonical path; `pairwise_jaccard <a> <b>` →
  emits `similarity=<0.0-1.0>`.
- `scripts/verify/m020-p01-graduate-single-entry.sh` (T03) — already
  exists; T05 only invokes it as part of demo verification.

### From Disk (Pre-existing)

- `knowledge/**/MEM*.md` — the live tree. `validate` walks this for the
  pairwise similarity computation. T05 must not mutate any file under this
  path (read-only walk).

## Constraints

- **AD-19**: every `Check:` and verification command is a single-script-file
  invocation.
- **MEM001 / MEM003**: bash 3.2; structured output; idempotent.
- **CON-1 (read-only-during-dispatch)**: T05's report-writing path writes
  ONLY to `.orchestrator/milestones/M020/phases/P01/`. Never mutates
  `knowledge/**`.
- **FR-10 (incremental migration)**: T05's migration-incremental verifier
  enforces the contract that P01 did not perform a bulk migration. The
  live tree must remain largely free of `status:` fields at the close of
  P01 (only entries P01 testing explicitly touched should bear it; the
  5% allowance is a generous upper bound).
- **A-5 (jaccard threshold default)**: report MAY recommend adjusting 0.7
  but MUST recommend a value (no "TBD" allowed). The recommendation is
  consumed by P05 when wiring threshold defaults into the `consolidate
  --cluster` invocation.
- **Demo sentence is load-bearing**: the report must exist at exactly
  `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`
  (the validator script's canonical path). Any other path fails the
  must-have.

## Expected Output

After this task:

1. `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` exists, ~80–150 lines, with all four enriched sections.
2. `scripts/verify/m020-p01-jaccard-validation-report.sh` exists, is executable, exits 0.
3. `scripts/verify/m020-p01-migration-incremental.sh` exists, is executable, exits 0.
4. The full demo path (`graduate.sh` flip + `jaccard.sh validate`) runs end-to-end against the live tree without mutating any `knowledge/**/MEM*.md` entry beyond what was explicitly graduated.
5. `git status knowledge/` is clean (or has only the one or two entries deliberately graduated by phase testing — within the 5% bound).

**Done when**: all three verification scripts in the Verification section above pass + the report file is fully enriched (no `<N>` / `<X>` placeholder strings remain).
