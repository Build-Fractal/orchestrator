#!/usr/bin/env bash
# Verify references/constitution-walkthrough.md covers all 13 principles.
set -eu
f="references/constitution-walkthrough.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check all 13 principle names are present
for principle in \
  "Context Minimization" \
  "Evidence Before Claims" \
  "Design Before Code" \
  "Plans Assume Zero Context" \
  "Fresh Context Per Unit" \
  "State On Disk" \
  "Knowledge Compounds" \
  "No Dead Infrastructure" \
  "Reproducibility" \
  "Templating Over Inference" \
  "Single Source of Truth" \
  "Hook Isolation" \
  "Agent Instruction Schema"; do
  grep -qi "$principle" "$f" || { echo "FAIL: missing principle '$principle'"; exit 1; }
done

# Check for at least 13 ## Principle headings
heading_count=$(grep -c "^###* Principle" "$f" 2>/dev/null || true)
test "$heading_count" -ge 13 || { echo "FAIL: fewer than 13 Principle headings (found $heading_count)"; exit 1; }

# Check for subsection structure
grep -q "### What It Means" "$f" || { echo "FAIL: missing '### What It Means' subsections"; exit 1; }
grep -q "### Codebase Examples" "$f" || { echo "FAIL: missing '### Codebase Examples' subsections"; exit 1; }
grep -q "### Common Violations" "$f" || { echo "FAIL: missing '### Common Violations' subsections"; exit 1; }
grep -qi "### How to Check" "$f" || { echo "FAIL: missing '### How to Check' subsections"; exit 1; }

# Check for Quick Reference Table
grep -qi "Quick Reference" "$f" || { echo "FAIL: missing Quick Reference Table"; exit 1; }
grep -q "|.*|.*|" "$f" || { echo "FAIL: missing markdown table in Quick Reference section"; exit 1; }

echo "PASS: constitution-walkthrough.md covers all 13 principles with required structure"
