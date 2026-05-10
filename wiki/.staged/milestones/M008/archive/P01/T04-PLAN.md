---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M008"
name: "Create intensity-metadata.md template + context-pressure.sh"
depends_on: []
---

## Prerequisites

- `templates/` directory exists with existing templates following the `{{placeholder}}`
  convention and YAML frontmatter with `schema_version` + `type` fields.
- `scripts/engine/` directory exists.

## Description

Two independent deliverables in one task:

1. **templates/intensity-metadata.md** -- the YAML frontmatter schema that flows
   through all pipeline stages. This template defines the data structure that
   every intensity-aware pipeline stage reads and writes. It is created once when
   the intensity engine produces a recommendation and then carried through
   discussion, planning, dispatch, verification, and knowledge generation stages.

2. **scripts/engine/context-pressure.sh** -- evaluates estimated token count
   against configurable thresholds and outputs a pressure level and recommended
   action. This prevents dispatching oversized payloads that degrade agent output
   quality. Thresholds are configurable and intensity-aware (Quick has tighter
   thresholds to stay fast).

### Intensity Metadata Schema

The template defines these fields in YAML frontmatter:

```yaml
schema_version: "1.0"
type: intensity-metadata
intensity: Quick|Standard|Full
scope: trivial|moderate|large
risk_level: low|medium|high
complexity: simple|moderate|complex
confidence: high|medium|low
reasoning: "<human-readable explanation>"
overridden_by: ""           # "developer" if manually overridden, else empty
original_intensity: ""      # original recommendation if overridden, else empty
capabilities_used:
  - "<capability name>"     # list of capabilities detected and used
evaluated_at: ""            # ISO 8601 timestamp of evaluation
```

### Context Pressure Evaluator

The script accepts a token estimate and an optional intensity level, then
applies threshold-based rules:

**Default thresholds** (configurable via environment variables):
- `PRESSURE_WARN_PCT=60` -- warn the developer
- `PRESSURE_DECOMPOSE_PCT=75` -- recommend decomposing the task
- `PRESSURE_REFUSE_PCT=85` -- refuse to dispatch

**Context window sizes** (configurable, defaults based on common models):
- `CONTEXT_WINDOW_TOKENS=200000` -- default context window size

**Intensity-aware adjustment**:
- Quick: thresholds are 10% tighter (warn at 50%, decompose at 65%, refuse at 75%)
- Standard: default thresholds
- Full: thresholds are 5% looser (warn at 65%, decompose at 80%, refuse at 90%)

### Interface

```
Usage: context-pressure.sh --tokens N [--intensity Quick|Standard|Full]
                            [--context-window N]
  --tokens:         estimated token count for the payload
  --intensity:      current intensity level (default: Standard)
  --context-window: context window size in tokens (default: 200000)

  Environment variable overrides:
    CONTEXT_WINDOW_TOKENS  — context window size
    PRESSURE_WARN_PCT      — warn threshold percentage
    PRESSURE_DECOMPOSE_PCT — decompose threshold percentage
    PRESSURE_REFUSE_PCT    — refuse threshold percentage

Output (stdout, key=value):
  pressure=low|medium|high|critical
  action=proceed|warn|decompose|refuse
  utilization_pct=<integer 0-100>
  threshold_warn=<integer>
  threshold_decompose=<integer>
  threshold_refuse=<integer>

Exit: 0 always (pressure evaluation never fails — returns pressure=low on bad input).
```

## Steps

### Step 1 -- Create `templates/intensity-metadata.md`

Create the template file:

```markdown
---
schema_version: "1.0"
type: intensity-metadata
intensity: "{{intensity}}"
scope: "{{scope}}"
risk_level: "{{risk_level}}"
complexity: "{{complexity}}"
confidence: "{{confidence}}"
reasoning: "{{reasoning}}"
overridden_by: "{{overridden_by}}"
original_intensity: "{{original_intensity}}"
capabilities_used:
  - "{{capability}}"
evaluated_at: "{{evaluated_at}}"
---

## Intensity Metadata

**Recommended intensity**: {{intensity}}
**Confidence**: {{confidence}}

### Analysis

- **Scope**: {{scope}} -- {{scope_explanation}}
- **Risk**: {{risk_level}} -- {{risk_explanation}}
- **Complexity**: {{complexity}} -- {{complexity_explanation}}

### Risk Signals

{{risk_signals_list}}

### Capabilities Used

{{capabilities_list}}

### Override History

{{override_history}}
```

### Step 2 -- Create `scripts/engine/context-pressure.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/context-pressure.sh — Context window pressure evaluator.
# Evaluates estimated token count against configurable thresholds to prevent
# dispatching oversized payloads that degrade agent output quality.
# Part of M008 Adaptive Intensity Engine (AD-04, DC-05, OQ-03).
#
# Usage: context-pressure.sh --tokens N [--intensity Quick|Standard|Full]
#                              [--context-window N]
#   --tokens:         estimated token count
#   --intensity:      current intensity level (default: Standard)
#   --context-window: context window size (default: $CONTEXT_WINDOW_TOKENS or 200000)
#
# Environment overrides:
#   CONTEXT_WINDOW_TOKENS   — context window size (default: 200000)
#   PRESSURE_WARN_PCT       — warn threshold % (default: 60)
#   PRESSURE_DECOMPOSE_PCT  — decompose threshold % (default: 75)
#   PRESSURE_REFUSE_PCT     — refuse threshold % (default: 85)
#
# Output (stdout, key=value):
#   pressure=low|medium|high|critical
#   action=proceed|warn|decompose|refuse
#   utilization_pct=<0-100>
#   threshold_warn=<token count>
#   threshold_decompose=<token count>
#   threshold_refuse=<token count>
#
# Exit: 0 always (pressure evaluation never fails).
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

# --- Defaults ---
TOKENS=0
INTENSITY="Standard"
CONTEXT_WINDOW="${CONTEXT_WINDOW_TOKENS:-200000}"
WARN_PCT="${PRESSURE_WARN_PCT:-60}"
DECOMPOSE_PCT="${PRESSURE_DECOMPOSE_PCT:-75}"
REFUSE_PCT="${PRESSURE_REFUSE_PCT:-85}"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tokens)
      TOKENS="$2"; shift 2 ;;
    --intensity)
      INTENSITY="$2"; shift 2 ;;
    --context-window)
      CONTEXT_WINDOW="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Validate numeric inputs ---
# Default to safe values if inputs are not numeric
case "$TOKENS" in
  ''|*[!0-9]*) TOKENS=0 ;;
esac
case "$CONTEXT_WINDOW" in
  ''|*[!0-9]*) CONTEXT_WINDOW=200000 ;;
esac
case "$WARN_PCT" in
  ''|*[!0-9]*) WARN_PCT=60 ;;
esac
case "$DECOMPOSE_PCT" in
  ''|*[!0-9]*) DECOMPOSE_PCT=75 ;;
esac
case "$REFUSE_PCT" in
  ''|*[!0-9]*) REFUSE_PCT=85 ;;
esac

# --- Intensity-aware threshold adjustment ---
case "$INTENSITY" in
  Quick)
    # 10% tighter thresholds for Quick (stay fast, small payloads)
    WARN_PCT=$((WARN_PCT - 10))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT - 10))
    REFUSE_PCT=$((REFUSE_PCT - 10))
    ;;
  Full)
    # 5% looser thresholds for Full (richer payloads acceptable)
    WARN_PCT=$((WARN_PCT + 5))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT + 5))
    REFUSE_PCT=$((REFUSE_PCT + 5))
    ;;
  Standard|*)
    # Default thresholds, no adjustment
    ;;
esac

# Clamp percentages to valid range
if [[ "$WARN_PCT" -lt 10 ]]; then WARN_PCT=10; fi
if [[ "$WARN_PCT" -gt 95 ]]; then WARN_PCT=95; fi
if [[ "$DECOMPOSE_PCT" -lt 20 ]]; then DECOMPOSE_PCT=20; fi
if [[ "$DECOMPOSE_PCT" -gt 95 ]]; then DECOMPOSE_PCT=95; fi
if [[ "$REFUSE_PCT" -lt 30 ]]; then REFUSE_PCT=30; fi
if [[ "$REFUSE_PCT" -gt 99 ]]; then REFUSE_PCT=99; fi

# --- Calculate thresholds as token counts ---
threshold_warn=$((CONTEXT_WINDOW * WARN_PCT / 100))
threshold_decompose=$((CONTEXT_WINDOW * DECOMPOSE_PCT / 100))
threshold_refuse=$((CONTEXT_WINDOW * REFUSE_PCT / 100))

# --- Calculate utilization ---
if [[ "$CONTEXT_WINDOW" -gt 0 ]]; then
  utilization_pct=$((TOKENS * 100 / CONTEXT_WINDOW))
else
  utilization_pct=0
fi

# Clamp to 0-100
if [[ "$utilization_pct" -gt 100 ]]; then utilization_pct=100; fi
if [[ "$utilization_pct" -lt 0 ]]; then utilization_pct=0; fi

# --- Determine pressure level and action ---
pressure="low"
action="proceed"

if [[ "$TOKENS" -ge "$threshold_refuse" ]]; then
  pressure="critical"
  action="refuse"
elif [[ "$TOKENS" -ge "$threshold_decompose" ]]; then
  pressure="high"
  action="decompose"
elif [[ "$TOKENS" -ge "$threshold_warn" ]]; then
  pressure="medium"
  action="warn"
fi

# --- Output ---
echo "pressure=$pressure"
echo "action=$action"
echo "utilization_pct=$utilization_pct"
echo "threshold_warn=$threshold_warn"
echo "threshold_decompose=$threshold_decompose"
echo "threshold_refuse=$threshold_refuse"
```

Make executable:

```bash
chmod +x scripts/engine/context-pressure.sh
```

### Step 3 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-metadata-template.sh:**

```bash
#!/usr/bin/env bash
# Verifies templates/intensity-metadata.md exists with required YAML frontmatter fields.
set -eu

f="templates/intensity-metadata.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check schema_version and type in frontmatter
grep -q "schema_version:" "$f" || { echo "FAIL: $f missing schema_version"; exit 1; }
grep -q 'type: intensity-metadata' "$f" || { echo "FAIL: $f missing type: intensity-metadata"; exit 1; }

# Check all required fields exist in the template
for field in intensity scope risk_level complexity confidence reasoning overridden_by original_intensity capabilities_used evaluated_at; do
  grep -q "$field:" "$f" || { echo "FAIL: $f missing field: $field"; exit 1; }
done

# Check placeholder syntax
grep -q '{{intensity}}' "$f" || { echo "FAIL: $f missing {{intensity}} placeholder"; exit 1; }
grep -q '{{overridden_by}}' "$f" || { echo "FAIL: $f missing {{overridden_by}} placeholder"; exit 1; }

echo "PASS: templates/intensity-metadata.md exists with all required fields and placeholder syntax"
```

**scripts/verify/m008-p01-context-pressure.sh:**

```bash
#!/usr/bin/env bash
# Verifies context-pressure.sh evaluates token estimates and outputs pressure/action.
set -eu

f="scripts/engine/context-pressure.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Test 1: Low pressure (10k tokens in 200k window = 5%)
output="$(bash "$f" --tokens 10000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "low" ]]; then
  echo "FAIL: 10k/200k should be pressure=low, got $pressure"; exit 1
fi
if [[ "$action" != "proceed" ]]; then
  echo "FAIL: 10k/200k should be action=proceed, got $action"; exit 1
fi

# Test 2: High pressure (160k tokens in 200k window = 80%)
output="$(bash "$f" --tokens 160000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "high" ]]; then
  echo "FAIL: 160k/200k should be pressure=high, got $pressure"; exit 1
fi
if [[ "$action" != "decompose" ]]; then
  echo "FAIL: 160k/200k should be action=decompose, got $action"; exit 1
fi

# Test 3: Critical pressure (180k tokens in 200k window = 90%)
output="$(bash "$f" --tokens 180000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "critical" ]]; then
  echo "FAIL: 180k/200k should be pressure=critical, got $pressure"; exit 1
fi
if [[ "$action" != "refuse" ]]; then
  echo "FAIL: 180k/200k should be action=refuse, got $action"; exit 1
fi

# Test 4: Verify all output fields present
echo "$output" | grep -q "^pressure=" || { echo "FAIL: missing pressure="; exit 1; }
echo "$output" | grep -q "^action=" || { echo "FAIL: missing action="; exit 1; }
echo "$output" | grep -q "^utilization_pct=" || { echo "FAIL: missing utilization_pct="; exit 1; }
echo "$output" | grep -q "^threshold_warn=" || { echo "FAIL: missing threshold_warn="; exit 1; }
echo "$output" | grep -q "^threshold_decompose=" || { echo "FAIL: missing threshold_decompose="; exit 1; }
echo "$output" | grep -q "^threshold_refuse=" || { echo "FAIL: missing threshold_refuse="; exit 1; }

# Test 5: Quick intensity tightens thresholds (10% tighter)
# At Standard, 130k/200k = 65% is medium (above 60% warn). At Quick, warn is 50%, so 65% > 50% -> medium.
# But let's test: 110k/200k = 55%. Standard: below 60% warn = low. Quick: above 50% warn = medium.
output="$(bash "$f" --tokens 110000 --context-window 200000 --intensity Quick 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
if [[ "$pressure" != "medium" ]]; then
  echo "FAIL: Quick intensity at 55% should be pressure=medium (warn at 50%), got $pressure"; exit 1
fi

echo "PASS: context-pressure.sh correctly evaluates pressure levels, actions, and intensity-aware thresholds"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "templates/intensity-metadata.md exists with YAML frontmatter schema
  containing intensity, scope, risk_level, complexity, confidence, reasoning,
  overridden_by, original_intensity, and capabilities_used fields" and
  "context-pressure.sh evaluates token estimates against configurable thresholds
  and outputs pressure level and recommended action".
- **Artifacts**: `templates/intensity-metadata.md`, `scripts/engine/context-pressure.sh`,
  two verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-metadata-template.sh
bash scripts/verify/m008-p01-context-pressure.sh
```

Both should print PASS lines and exit 0.

Additional manual tests:

```bash
# Low pressure
bash scripts/engine/context-pressure.sh --tokens 5000
# Expected: pressure=low, action=proceed

# Medium pressure at Quick intensity
bash scripts/engine/context-pressure.sh --tokens 110000 --intensity Quick
# Expected: pressure=medium, action=warn (Quick threshold is 50%, 110k/200k = 55%)

# Critical pressure
bash scripts/engine/context-pressure.sh --tokens 180000
# Expected: pressure=critical, action=refuse
```

### Files Touched By This Task

- `templates/intensity-metadata.md` (create)
- `scripts/engine/context-pressure.sh` (create)
- `scripts/verify/m008-p01-metadata-template.sh` (create)
- `scripts/verify/m008-p01-context-pressure.sh` (create)

## Inputs

### From Previous Tasks

None -- T04 is independent.

### From Disk (Pre-existing)

- `templates/` directory -- existing templates use `{{placeholder}}` syntax
  with YAML frontmatter containing `schema_version` and `type` fields.
  The new template follows the same convention.

- `scripts/engine/` directory -- the new script lives here alongside
  checkpoint.sh, run.sh.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- context-pressure.sh exits 0 always (pressure evaluation never fails).
- Template uses `{{placeholder}}` syntax consistent with all other templates.
- Template YAML frontmatter must include `schema_version: "1.0"` and
  `type: intensity-metadata`.
- Thresholds configurable via environment variables for testing and customization.
- Integer arithmetic only (no floating point in Bash) -- use percentage-based
  calculations with `$((token * 100 / window))`.

## Expected Output

After completing this task:

1. `templates/intensity-metadata.md` exists with ~30+ lines, YAML frontmatter
   containing all 10 specified fields, and `{{placeholder}}` syntax in the body.
2. `scripts/engine/context-pressure.sh` exists, is chmod +x, ~100+ lines.
3. `bash scripts/engine/context-pressure.sh --tokens 5000` outputs
   `pressure=low`, `action=proceed`.
4. `bash scripts/engine/context-pressure.sh --tokens 160000` outputs
   `pressure=high`, `action=decompose`.
5. `bash scripts/engine/context-pressure.sh --tokens 180000` outputs
   `pressure=critical`, `action=refuse`.
6. Quick intensity tightens thresholds by 10%; Full intensity loosens by 5%.
7. Both verification scripts print PASS and exit 0.
8. `git status` shows 4 new files.
