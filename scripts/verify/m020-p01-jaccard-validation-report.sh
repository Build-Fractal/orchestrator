#!/usr/bin/env bash
# m020-p01-jaccard-validation-report.sh -- assert the demo-sentence report
# exists at the canonical path and contains the load-bearing analysis
# sections produced by `scripts/knowledge/lib/jaccard.sh validate`.
# Bash 3.2 safe. AD-19 single-script-invocation shape.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT="$ROOT/.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md"

if [ ! -f "$REPORT" ]; then
  echo "FAIL: validation report missing at $REPORT"
  exit 1
fi

# Load-bearing tokens that must appear in the enriched report.
# (Avoid greedy "PASS" / "threshold" matches by anchoring where possible.)
for token in "0.7" "CON-5" "feature vector" "Demo-sentence verification"; do
  if ! grep -q "$token" "$REPORT"; then
    echo "FAIL: report missing token: $token"
    exit 1
  fi
done

# Required H2 section headers (parser-stable anchors).
for section in \
  "## Pair-count distribution" \
  "## Threshold Recommendation" \
  "## Feature-Vector Sanity Check" \
  "## Demo-sentence verification"; do
  if ! grep -qF "$section" "$REPORT"; then
    echo "FAIL: report missing section: $section"
    exit 1
  fi
done

# A-5 threshold MUST be either confirmed or replaced (no "TBD" placeholder).
if grep -qi 'TBD\|<X>\|<N>' "$REPORT"; then
  echo "FAIL: report still contains placeholder strings (TBD / <X> / <N>)"
  exit 1
fi

# Recommendation line must name a numeric threshold value.
if ! grep -E '\*\*Recommendation\*\*.*0\.[0-9]+' "$REPORT" >/dev/null; then
  echo "FAIL: Threshold Recommendation is missing a numeric threshold value"
  exit 1
fi

# Demo sentence must end with PASS verdict.
if ! grep -qF "Demo sentence: **PASS**." "$REPORT"; then
  echo "FAIL: report missing 'Demo sentence: **PASS**.' verdict line"
  exit 1
fi

echo "PASS: jaccard validation report contract honored"
exit 0
