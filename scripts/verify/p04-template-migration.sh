#!/usr/bin/env bash
# Verifies that at least 2 templates have conforming section headings.
# Checks dispatch-prompt.md and task-plan.md for required section heading
# aliases as defined by the instruction schema.
# Expected to FAIL until T03 migrates templates.
set -eu

conforming=0

# --- Check dispatch-prompt.md ---
f="templates/dispatch-prompt.md"
if [ -f "$f" ]; then
  has_context=false
  has_task=false
  has_constraints=false
  has_verification=false
  has_output=false

  # Context group aliases
  grep -qE '^## (Context|Prerequisites|State Context|State Derivation|Context Gathering)$' "$f" && has_context=true
  # Task group aliases
  grep -qE '^## (Task|Scope|Phase Planning|What It Checks|Usage|Context Construction|Dispatch Strategy)$' "$f" && has_task=true
  # Constraints group aliases
  grep -qE '^## (Constraints|Error Handling|Gotchas|Idempotency|Concurrent Safety|Budget Gates)$' "$f" && has_constraints=true
  # Verification group aliases
  grep -qE '^## (Verification|Post-Dispatch|Validation|Must-Haves|Tier 1)$' "$f" && has_verification=true
  # Output Format group aliases
  grep -qE '^## (Output Format|Expected Output|Output|Referenced Templates|Payload Size Guidance)$' "$f" && has_output=true

  if $has_context && $has_task && $has_constraints && $has_verification && $has_output; then
    conforming=$((conforming + 1))
  else
    echo "INFO: $f missing some required section groups"
  fi
else
  echo "INFO: $f not found"
fi

# --- Check task-plan.md ---
f="templates/task-plan.md"
if [ -f "$f" ]; then
  has_context=false
  has_task=false
  has_constraints=false
  has_verification=false
  has_output=false

  grep -qE '^## (Context|Prerequisites|State Context|State Derivation|Context Gathering)$' "$f" && has_context=true
  grep -qE '^## (Task|Scope|Phase Planning|What It Checks|Usage|Context Construction|Dispatch Strategy|Description|Steps)$' "$f" && has_task=true
  grep -qE '^## (Constraints|Error Handling|Gotchas|Idempotency|Concurrent Safety|Budget Gates)$' "$f" && has_constraints=true
  grep -qE '^## (Verification|Post-Dispatch|Validation|Must-Haves|Tier 1)$' "$f" && has_verification=true
  grep -qE '^## (Output Format|Expected Output|Output|Referenced Templates|Payload Size Guidance|Inputs)$' "$f" && has_output=true

  if $has_context && $has_task && $has_constraints && $has_verification && $has_output; then
    conforming=$((conforming + 1))
  else
    echo "INFO: $f missing some required section groups"
  fi
else
  echo "INFO: $f not found"
fi

if [ "$conforming" -lt 2 ]; then
  echo "FAIL: only $conforming templates have conforming section headings (expected at least 2, will pass after T03)"
  exit 1
fi

echo "PASS: $conforming templates have conforming section headings"
