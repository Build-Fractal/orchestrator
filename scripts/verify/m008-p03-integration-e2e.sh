#!/usr/bin/env bash
# End-to-end integration test for the P03 intensity-aware pipeline.
# Exercises intensity-gate.sh, intensity-override.sh, and
# intensity-knowledge.sh against fixture metadata files.
set -u

gate="scripts/engine/intensity-gate.sh"
override="scripts/engine/intensity-override.sh"
know="scripts/knowledge/intensity-knowledge.sh"

for f in "$gate" "$override" "$know"; do
  test -x "$f" || { echo "FAIL: $f missing or not executable"; exit 1; }
done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

make_meta() {
  local path="$1"
  local level="$2"
  cat > "$path" <<EOF
---
schema_version: "1.0"
type: intensity-metadata
intensity: "$level"
scope: "moderate"
risk_level: "medium"
complexity: "moderate"
confidence: "high"
reasoning: "fixture"
overridden_by: ""
original_intensity: ""
capabilities_used:
  - "none"
evaluated_at: "2026-04-14T15:00:00Z"
---

## Fixture
EOF
}

# --- 1. Gate: all 7 stages x 3 levels produce distinct output ---

stages="discuss research plan-phase dispatch verify knowledge auto"

for s in $stages; do
  q="$(bash "$gate" --stage "$s" --intensity Quick 2>/dev/null)"
  std="$(bash "$gate" --stage "$s" --intensity Standard 2>/dev/null)"
  full="$(bash "$gate" --stage "$s" --intensity Full 2>/dev/null)"

  if [[ -z "$q" ]] || [[ -z "$std" ]] || [[ -z "$full" ]]; then
    echo "FAIL: stage=$s emitted empty output at some level"
    exit 1
  fi
  if [[ "$q" = "$std" ]]; then
    echo "FAIL: stage=$s produced identical output at Quick and Standard"
    exit 1
  fi
  if [[ "$std" = "$full" ]]; then
    echo "FAIL: stage=$s produced identical output at Standard and Full"
    exit 1
  fi
done

# --- 2. Gate via --intensity-metadata produces identical output to --intensity ---

make_meta "$tmp/quick.md" "Quick"
make_meta "$tmp/full.md" "Full"

direct="$(bash "$gate" --stage verify --intensity Quick 2>/dev/null)"
via_meta="$(bash "$gate" --stage verify --intensity-metadata "$tmp/quick.md" 2>/dev/null)"
if [[ "$direct" != "$via_meta" ]]; then
  echo "FAIL: --intensity-metadata does not agree with --intensity for verify Quick"
  exit 1
fi

# --- 3. Override: Quick -> Full rewrites metadata ---

meta_ov="$tmp/override-target.md"
make_meta "$meta_ov" "Quick"

bash "$override" --metadata-file "$meta_ov" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: override Quick -> Full exited non-zero"; exit 1; }

grep -q '^intensity: "Full"' "$meta_ov" || { echo "FAIL: override did not rewrite intensity to Full"; exit 1; }
grep -q '^original_intensity: "Quick"' "$meta_ov" || { echo "FAIL: override did not preserve Quick as original_intensity"; exit 1; }
grep -q '^overridden_by: "developer"' "$meta_ov" || { echo "FAIL: override did not set overridden_by=developer"; exit 1; }

# After override, the gate reading that file should now return Full substeps
post="$(bash "$gate" --stage verify --intensity-metadata "$meta_ov" 2>/dev/null)"
echo "$post" | grep -q 'tier1,tier2,tier3,tier4' \
  || { echo "FAIL: gate on overridden file did not reflect Full intensity"; exit 1; }

# --- 4. Knowledge: dry-run at each level matches expected subset ---

make_meta "$tmp/k-quick.md" "Quick"
make_meta "$tmp/k-std.md" "Standard"
make_meta "$tmp/k-full.md" "Full"

q_log="$(bash "$know" --intensity-metadata "$tmp/k-quick.md" --dry-run 2>/dev/null)"
s_log="$(bash "$know" --intensity-metadata "$tmp/k-std.md" --dry-run 2>/dev/null)"
f_log="$(bash "$know" --intensity-metadata "$tmp/k-full.md" --dry-run 2>/dev/null)"

# Quick: one step (write-summary only)
q_count="$(echo "$q_log" | grep -c '^WOULD_RUN:')"
if [[ "$q_count" != "1" ]]; then echo "FAIL: Quick knowledge log expected 1 step, got $q_count"; exit 1; fi
echo "$q_log" | grep -q 'write-summary.sh' || { echo "FAIL: Quick missing write-summary.sh"; exit 1; }

# Standard: two steps
s_count="$(echo "$s_log" | grep -c '^WOULD_RUN:')"
if [[ "$s_count" != "2" ]]; then echo "FAIL: Standard knowledge log expected 2 steps, got $s_count"; exit 1; fi
echo "$s_log" | grep -q 'append-decision.sh' || { echo "FAIL: Standard missing append-decision.sh"; exit 1; }

# Full: four steps
f_count="$(echo "$f_log" | grep -c '^WOULD_RUN:')"
if [[ "$f_count" != "4" ]]; then echo "FAIL: Full knowledge log expected 4 steps, got $f_count"; exit 1; fi
echo "$f_log" | grep -q 'rebuild-index.sh' || { echo "FAIL: Full missing rebuild-index.sh"; exit 1; }

# --- 5. End-to-end sanity: override then knowledge dispatch expands set ---

make_meta "$tmp/e2e.md" "Quick"
pre_log="$(bash "$know" --intensity-metadata "$tmp/e2e.md" --dry-run 2>/dev/null)"
pre_count="$(echo "$pre_log" | grep -c '^WOULD_RUN:')"
if [[ "$pre_count" != "1" ]]; then echo "FAIL: pre-override Quick should plan 1 step, got $pre_count"; exit 1; fi

bash "$override" --metadata-file "$tmp/e2e.md" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: mid-workflow override exited non-zero"; exit 1; }

post_log="$(bash "$know" --intensity-metadata "$tmp/e2e.md" --dry-run 2>/dev/null)"
post_count="$(echo "$post_log" | grep -c '^WOULD_RUN:')"
if [[ "$post_count" != "4" ]]; then echo "FAIL: post-override Full should plan 4 steps, got $post_count"; exit 1; fi

echo "PASS: P03 end-to-end integration — gate, override, knowledge all honor intensity"
