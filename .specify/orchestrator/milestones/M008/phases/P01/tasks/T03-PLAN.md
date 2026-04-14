---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M008"
name: "Create intensity-recommend.sh -- recommendation engine combining analyze + capabilities"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-capabilities.sh` has `--profile` flag outputting cap_execution, cap_graph, cap_mcp, cap_ci, cap_subagent, cap_score.
- T02 complete: `scripts/engine/intensity-analyze.sh` exists and outputs scope, risk_level, complexity, risk_signals, recommended_intensity.

## Description

Create `scripts/engine/intensity-recommend.sh` that combines the output from
`intensity-analyze.sh` and `detect-capabilities.sh --profile` to produce a
final intensity recommendation with confidence level and human-readable
reasoning.

The recommendation engine is the integration point that resolves the final
intensity level the pipeline should operate at. It applies a decision matrix
that considers three inputs:

1. **Scope analysis** (from intensity-analyze.sh): scope, risk_level, complexity,
   risk_signals, recommended_intensity
2. **Capability profile** (from detect-capabilities.sh --profile): cap_execution,
   cap_graph, cap_mcp, cap_ci, cap_subagent, cap_score
3. **Decision matrix** (hardcoded): maps inputs to a final intensity + confidence

### Decision Matrix

The base intensity comes from `intensity-analyze.sh`. The recommendation engine
then adjusts confidence and may escalate (never downgrade) based on capabilities:

| Base Intensity | Capability Score | Confidence | Adjustment |
|----------------|-----------------|------------|------------|
| Quick          | any             | high       | No change -- Quick tasks don't benefit from richer environments |
| Standard       | 0-1             | high       | No change -- Standard is appropriate for lean environments |
| Standard       | 2-3             | high       | No change -- Standard already matched |
| Standard       | 4-5             | high       | No change -- richer environment but Standard still fits |
| Full           | 0-1             | medium     | Confidence reduced -- Full benefits from richer environment but can proceed |
| Full           | 2-3             | high       | Confidence high -- environment has enough for Full |
| Full           | 4-5             | high       | Confidence high -- rich environment |

Risk escalation rules (may override base):
- If risk_level=high AND base=Quick, escalate to Standard (risk overrides convenience).
- If risk_level=high AND complexity=complex, escalate to Full regardless of scope.
- If risk_signals contain "migration" or "security" or "auth", escalate to at least Standard.

Reasoning generation: The script produces a one-line reasoning string that
explains the recommendation. Format:
`"<Intensity> recommended: scope is <scope>, risk is <risk_level> [with signals: <signals>], complexity is <complexity>, environment has <cap_score>/5 capabilities."`

### Interface

```
Usage: intensity-recommend.sh [--analyze-output "key=value lines"] [--profile-output "key=value lines"]
  --analyze-output: output from intensity-analyze.sh (multi-line string)
  --profile-output: output from detect-capabilities.sh --profile (multi-line string)
  If flags not provided, runs both scripts internally.

Output (stdout, key=value):
  intensity=Quick|Standard|Full
  confidence=high|medium|low
  reasoning=<human readable explanation>
  scope=<passthrough from analyze>
  risk_level=<passthrough from analyze>
  complexity=<passthrough from analyze>
  risk_signals=<passthrough from analyze>
  cap_score=<passthrough from profile>

Exit: 0 on success, 1 on error.
```

## Steps

### Step 1 -- Create `scripts/engine/intensity-recommend.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-recommend.sh — Intensity recommendation engine.
# Combines scope analysis (intensity-analyze.sh) + capability profile
# (detect-capabilities.sh --profile) into a final intensity recommendation
# with confidence and reasoning. Part of M008 Adaptive Intensity Engine
# (FR-001, FR-005, FR-025).
#
# Usage: intensity-recommend.sh [--analyze-output "text"] [--profile-output "text"]
#                                [--description "text"]
#   --analyze-output: pre-computed output from intensity-analyze.sh
#   --profile-output: pre-computed output from detect-capabilities.sh --profile
#   --description:    task description (runs intensity-analyze.sh internally)
#   If no flags given, reads description from stdin and runs both scripts.
#
# Output (stdout, key=value):
#   intensity=Quick|Standard|Full
#   confidence=high|medium|low
#   reasoning=<explanation>
#   scope=<from analyze>
#   risk_level=<from analyze>
#   complexity=<from analyze>
#   risk_signals=<from analyze>
#   cap_score=<from profile>
#
# Exit: 0 success, 1 error.
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ANALYZE_OUTPUT=""
PROFILE_OUTPUT=""
DESCRIPTION=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --analyze-output)
      ANALYZE_OUTPUT="$2"; shift 2 ;;
    --profile-output)
      PROFILE_OUTPUT="$2"; shift 2 ;;
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# If no analyze output provided, run intensity-analyze.sh
if [[ -z "$ANALYZE_OUTPUT" ]]; then
  if [[ -z "$DESCRIPTION" ]]; then
    if [[ -t 0 ]]; then
      echo "ERROR: no description or analyze output provided." >&2
      exit 1
    fi
    DESCRIPTION="$(cat)"
  fi
  ANALYZE_OUTPUT="$(echo "$DESCRIPTION" | bash "$SCRIPT_DIR/intensity-analyze.sh" 2>/dev/null)"
fi

# If no profile output provided, run detect-capabilities.sh --profile
if [[ -z "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
fi

# --- Parse analyze output ---
# Extract values using grep + cut (no associative arrays)
scope="$(echo "$ANALYZE_OUTPUT" | grep "^scope=" | head -1 | cut -d= -f2)"
risk_level="$(echo "$ANALYZE_OUTPUT" | grep "^risk_level=" | head -1 | cut -d= -f2)"
complexity="$(echo "$ANALYZE_OUTPUT" | grep "^complexity=" | head -1 | cut -d= -f2)"
risk_signals="$(echo "$ANALYZE_OUTPUT" | grep "^risk_signals=" | head -1 | cut -d= -f2-)"
base_intensity="$(echo "$ANALYZE_OUTPUT" | grep "^recommended_intensity=" | head -1 | cut -d= -f2)"

# --- Parse capability profile ---
cap_score="$(echo "$PROFILE_OUTPUT" | grep "^cap_score=" | head -1 | cut -d= -f2)"
cap_score="${cap_score:-0}"

# --- Apply decision matrix ---
intensity="$base_intensity"
confidence="high"

# Risk escalation: risk overrides convenience
if [[ "$risk_level" = "high" ]] && [[ "$intensity" = "Quick" ]]; then
  intensity="Standard"
fi

# Risk + complexity double-escalation
if [[ "$risk_level" = "high" ]] && [[ "$complexity" = "complex" ]]; then
  intensity="Full"
fi

# Specific risk signal escalation (migration, security, auth -> at least Standard)
if [[ "$risk_signals" != "none" ]]; then
  for escalation_signal in "migration" "security" "auth"; do
    if echo "$risk_signals" | grep -qF "$escalation_signal"; then
      if [[ "$intensity" = "Quick" ]]; then
        intensity="Standard"
      fi
      break
    fi
  done
fi

# Confidence adjustment based on capability score
if [[ "$intensity" = "Full" ]] && [[ "$cap_score" -le 1 ]]; then
  confidence="medium"
fi

# --- Build reasoning ---
signal_clause=""
if [[ "$risk_signals" != "none" ]]; then
  signal_clause=" with signals: $risk_signals"
fi

reasoning="${intensity} recommended: scope is ${scope}, risk is ${risk_level}${signal_clause}, complexity is ${complexity}, environment has ${cap_score}/5 capabilities."

# --- Output ---
echo "intensity=$intensity"
echo "confidence=$confidence"
echo "reasoning=$reasoning"
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "cap_score=$cap_score"
```

Make executable:

```bash
chmod +x scripts/engine/intensity-recommend.sh
```

### Step 2 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-recommend-output-format.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-recommend.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Provide pre-computed inputs so we don't depend on other scripts' runtime behavior
analyze="scope=moderate
risk_level=medium
complexity=moderate
risk_signals=none
recommended_intensity=Standard"

profile="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output="$(bash "$f" --analyze-output "$analyze" --profile-output "$profile" 2>/dev/null)"

echo "$output" | grep -q "^intensity=" || { echo "FAIL: output missing intensity="; exit 1; }
echo "$output" | grep -q "^confidence=" || { echo "FAIL: output missing confidence="; exit 1; }
echo "$output" | grep -q "^reasoning=" || { echo "FAIL: output missing reasoning="; exit 1; }
echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: output missing cap_score="; exit 1; }

# Verify intensity is a valid value
intensity_val="$(echo "$output" | grep "^intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

# Verify confidence is a valid value
conf_val="$(echo "$output" | grep "^confidence=" | cut -d= -f2)"
case "$conf_val" in
  high|medium|low) ;;
  *) echo "FAIL: confidence='$conf_val' is not high|medium|low"; exit 1 ;;
esac

echo "PASS: intensity-recommend.sh outputs all required key=value fields with valid values"
```

**scripts/verify/m008-p01-recommend-capabilities.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-recommend.sh factors capabilities into its recommendation.
# Full intensity with low cap_score should have reduced confidence.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Full intensity + lean environment -> confidence should be medium
analyze_full="scope=large
risk_level=high
complexity=complex
risk_signals=migration_detected
recommended_intensity=Full"

profile_lean="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output_lean="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_lean" 2>/dev/null)"
conf_lean="$(echo "$output_lean" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_lean" != "medium" ]]; then
  echo "FAIL: Full intensity with cap_score=0 should have confidence=medium, got $conf_lean"; exit 1
fi

# Full intensity + rich environment -> confidence should be high
profile_rich="cap_execution=ci
cap_graph=true
cap_mcp=true
cap_ci=true
cap_subagent=true
cap_score=5"

output_rich="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_rich" 2>/dev/null)"
conf_rich="$(echo "$output_rich" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_rich" != "high" ]]; then
  echo "FAIL: Full intensity with cap_score=5 should have confidence=high, got $conf_rich"; exit 1
fi

echo "PASS: intensity-recommend.sh factors capabilities into confidence (lean=medium, rich=high)"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "intensity-recommend.sh combines analyze output + capability profile
  and produces intensity, confidence, and reasoning as key=value pairs" and
  "intensity-recommend.sh factors detected capabilities into its recommendation".
- **Artifacts**: `scripts/engine/intensity-recommend.sh`, two verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-recommend-output-format.sh
bash scripts/verify/m008-p01-recommend-capabilities.sh
```

Both should print PASS lines and exit 0.

Additionally, test the full pipeline manually:

```bash
# Run analyze + recommend together via --description
bash scripts/engine/intensity-recommend.sh --description "Fix a typo in the README"
# Expected: intensity=Quick, confidence=high

bash scripts/engine/intensity-recommend.sh --description "Rewrite the authentication system with OAuth2 migration"
# Expected: intensity=Full, confidence=medium (in lean environment)
```

### Files Touched By This Task

- `scripts/engine/intensity-recommend.sh` (create)
- `scripts/verify/m008-p01-recommend-output-format.sh` (create)
- `scripts/verify/m008-p01-recommend-capabilities.sh` (create)

## Inputs

### From Previous Tasks

- **T01**: `scripts/dispatch/detect-capabilities.sh` with `--profile` flag.
  The profile output format is:
  ```
  cap_execution=local|ci
  cap_graph=true|false
  cap_mcp=true|false
  cap_ci=true|false
  cap_subagent=true|false
  cap_score=0..5
  ```

- **T02**: `scripts/engine/intensity-analyze.sh`. The analyze output format is:
  ```
  scope=trivial|moderate|large
  risk_level=low|medium|high
  complexity=simple|moderate|complex
  risk_signals=signal1,signal2,...  (or "none")
  recommended_intensity=Quick|Standard|Full
  ```

### From Disk (Pre-existing)

- `scripts/engine/` directory -- the new script lives here alongside
  checkpoint.sh, run.sh, and intensity-analyze.sh (from T02).

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- The recommendation engine may escalate intensity (Quick -> Standard -> Full)
  but NEVER downgrades. Risk overrides convenience.
- The `--analyze-output` and `--profile-output` flags accept pre-computed output
  to avoid redundant script execution (important for testing and when the caller
  has already gathered the data).
- Exit 0 on success, 1 only on error (no description, missing scripts).

## Expected Output

After completing this task:

1. `scripts/engine/intensity-recommend.sh` exists, is chmod +x, ~120+ lines.
2. Providing a Standard analyze output with cap_score=0 produces intensity=Standard,
   confidence=high (lean environment doesn't reduce confidence for Standard).
3. Providing a Full analyze output with cap_score=0 produces intensity=Full,
   confidence=medium (Full in lean environment gets reduced confidence).
4. Providing a Full analyze output with cap_score=5 produces intensity=Full,
   confidence=high.
5. Risk escalation works: analyze output with risk_level=high and base Quick
   gets escalated to at least Standard.
6. Both verification scripts print PASS and exit 0.
7. `git status` shows 3 new files.
