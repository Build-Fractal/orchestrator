---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M008"
name: "Create intensity-analyze.sh -- scope/risk/complexity analyzer"
depends_on: []
---

## Prerequisites

- `scripts/engine/` directory exists (contains checkpoint.sh, run.sh, test-resume.sh from prior milestones).
- No external dependencies beyond Bash 3.2 and standard Unix tools (grep, sed, awk, wc).

## Description

Create `scripts/engine/intensity-analyze.sh` that accepts a natural-language
task description and analyzes it for scope markers, risk signals, and complexity
indicators. The script uses pattern matching on the description text to classify
the task along three axes (scope, risk, complexity) and produces a recommended
intensity level.

### Analysis Model

**Scope classification** (how big is the task?):
- `trivial` -- single file, typo fix, small config change, one-liner, rename
- `moderate` -- multi-file feature, new component, refactor, API change
- `large` -- platform build, architecture change, multi-component system, migration

Scope detection uses keyword/phrase pattern matching:

| Scope | Trigger Patterns |
|-------|-----------------|
| trivial | "typo", "fix typo", "rename", "one-line", "single file", "config change", "update comment", "fix whitespace", "bump version", "small fix", "minor", "tweak" |
| large | "platform", "architecture", "migration", "multi-component", "redesign", "rewrite", "system", "infrastructure", "framework", "cross-cutting", "milestone", "epic" |
| moderate | default (neither trivial nor large patterns matched) |

**Risk classification** (how dangerous is the task?):
- `low` -- documentation, tests, comments, formatting
- `medium` -- new files, feature additions, non-critical refactors
- `high` -- auth/security changes, database migrations, dependency updates, CI/CD changes, payment/billing, API breaking changes

Risk detection uses path and keyword patterns:

| Risk | Trigger Patterns |
|------|-----------------|
| high | "auth", "security", "password", "token", "secret", "credential", "migration", "database", "schema", "payment", "billing", "breaking change", "API break", "deploy", "production", ".env", "Dockerfile", "docker-compose", paths containing "auth/", "security/", "middleware/" |
| low | "doc", "readme", "comment", "test", "spec", "typo", "whitespace", "format", "lint" |
| medium | default |

**Complexity classification** (how many moving parts?):
- `simple` -- single concern, isolated change
- `moderate` -- 2-3 concerns, some coordination
- `complex` -- 4+ concerns, cross-cutting, new abstractions

Complexity detection:

| Complexity | Trigger Patterns |
|------------|-----------------|
| complex | "cross-cutting", "abstraction", "interface", "adapter", "plugin", "extension point", "multi-", "distributed", "concurrent", "async", "parallel", 3+ distinct file path references |
| simple | scope=trivial AND risk=low |
| moderate | default |

**Recommended intensity** (decision logic):
- `Quick` -- scope=trivial AND risk!=high AND complexity=simple
- `Full` -- scope=large OR risk=high OR complexity=complex
- `Standard` -- everything else

**Risk signal collection**: The script collects individual risk signals (specific
matches) into a comma-separated list for transparency. Examples:
"auth_keyword_detected", "migration_keyword_detected",
"dependency_file_referenced", "security_path_detected".

### Interface

```
Usage: intensity-analyze.sh [--description "text"] [--file path]
  --description: task description as a string argument
  --file:        path to a file containing the task description
  If neither flag is given, reads from stdin.

Output (to stdout, key=value format):
  scope=trivial|moderate|large
  risk_level=low|medium|high
  complexity=simple|moderate|complex
  risk_signals=signal1,signal2,... (or "none")
  recommended_intensity=Quick|Standard|Full

Exit: 0 on success, 1 if no description provided
```

## Steps

### Step 1 -- Create `scripts/engine/intensity-analyze.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-analyze.sh — Scope/risk/complexity analyzer for adaptive intensity.
# Reads a natural-language task description and outputs an intensity recommendation
# with structured reasoning. Part of the M008 Adaptive Intensity Engine (FR-001, FR-005).
#
# Usage: intensity-analyze.sh [--description "text"] [--file path]
#   --description: task description as a string argument
#   --file:        path to a file containing the task description
#   If neither flag is given, reads from stdin.
#
# Output (stdout, key=value):
#   scope=trivial|moderate|large
#   risk_level=low|medium|high
#   complexity=simple|moderate|complex
#   risk_signals=signal1,signal2,...  (or "none")
#   recommended_intensity=Quick|Standard|Full
#
# Exit: 0 success, 1 if no description provided.
# Bash 3.2 compatible (NFR-200). No associative arrays.

set -euo pipefail

DESCRIPTION=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    --file)
      if [[ ! -f "$2" ]]; then
        echo "ERROR: file not found: $2" >&2
        exit 1
      fi
      DESCRIPTION="$(cat "$2")"; shift 2 ;;
    *)
      shift ;;
  esac
done

# Read from stdin if no --description or --file
if [[ -z "$DESCRIPTION" ]]; then
  if [[ -t 0 ]]; then
    echo "ERROR: no description provided. Use --description, --file, or pipe via stdin." >&2
    exit 1
  fi
  DESCRIPTION="$(cat)"
fi

if [[ -z "$DESCRIPTION" ]]; then
  echo "ERROR: empty description" >&2
  exit 1
fi

# Lowercase the description for case-insensitive matching
desc_lower="$(printf '%s' "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')"

# --- Scope classification ---
scope="moderate"

# Check trivial patterns
trivial_match=false
for pattern in "typo" "fix typo" "rename" "one-line" "one line" "single file" "config change" "update comment" "fix whitespace" "bump version" "small fix" "minor fix" "minor tweak" "tweak" "nit" "spelling"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    trivial_match=true
    break
  fi
done

# Check large patterns
large_match=false
for pattern in "platform" "architecture" "migration" "multi-component" "redesign" "rewrite" "system-wide" "infrastructure" "framework" "cross-cutting" "milestone" "epic" "overhaul" "rebuild" "greenfield" "from scratch"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    large_match=true
    break
  fi
done

if [[ "$trivial_match" = true ]] && [[ "$large_match" = false ]]; then
  scope="trivial"
elif [[ "$large_match" = true ]]; then
  scope="large"
fi

# --- Risk classification ---
risk_level="medium"
# Collect individual risk signals using parallel indexed arrays (bash 3.2 safe)
risk_signal_count=0

# High-risk keyword patterns
for pattern in "auth" "security" "password" "token" "secret" "credential" "migration" "database migration" "schema change" "payment" "billing" "breaking change" "api break" "deploy to prod" "production deploy" "\.env" "dockerfile" "docker-compose"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"${pattern}_detected\""
    risk_signal_count=$((risk_signal_count + 1))
  fi
done

# High-risk path patterns
for pattern in "auth/" "security/" "middleware/" "migrations/"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"path_${pattern%%/*}_detected\""
    risk_signal_count=$((risk_signal_count + 1))
  fi
done

# Dependency file references
for pattern in "package.json" "requirements.txt" "cargo.toml" "go.mod" "gemfile" "pom.xml" "build.gradle"; do
  if echo "$desc_lower" | grep -qiF "$pattern"; then
    eval "risk_signal_${risk_signal_count}=\"dependency_file_referenced\""
    risk_signal_count=$((risk_signal_count + 1))
    break
  fi
done

# Low-risk patterns (only if no high-risk signals found)
low_risk_match=false
if [[ "$risk_signal_count" -eq 0 ]]; then
  for pattern in "documentation" "readme" "comment" "test file" "add test" "spec file" "whitespace" "formatting" "lint fix"; do
    if echo "$desc_lower" | grep -qF "$pattern"; then
      low_risk_match=true
      break
    fi
  done
fi

if [[ "$risk_signal_count" -gt 0 ]]; then
  risk_level="high"
elif [[ "$low_risk_match" = true ]]; then
  risk_level="low"
fi

# Build risk_signals string
risk_signals="none"
if [[ "$risk_signal_count" -gt 0 ]]; then
  risk_signals=""
  i=0
  while [[ "$i" -lt "$risk_signal_count" ]]; do
    eval "sig=\"\$risk_signal_${i}\""
    if [[ -n "$risk_signals" ]]; then
      risk_signals="${risk_signals},${sig}"
    else
      risk_signals="$sig"
    fi
    i=$((i + 1))
  done
fi

# --- Complexity classification ---
complexity="moderate"

# Check complex patterns
complex_match=false
for pattern in "cross-cutting" "abstraction" "new interface" "adapter" "plugin" "extension point" "multi-service" "distributed" "concurrent" "async" "parallel" "event-driven"; do
  if echo "$desc_lower" | grep -qF "$pattern"; then
    complex_match=true
    break
  fi
done

if [[ "$complex_match" = true ]]; then
  complexity="complex"
elif [[ "$scope" = "trivial" ]] && [[ "$risk_level" = "low" ]]; then
  complexity="simple"
fi

# --- Recommended intensity ---
recommended_intensity="Standard"

if [[ "$scope" = "trivial" ]] && [[ "$risk_level" != "high" ]] && [[ "$complexity" = "simple" ]]; then
  recommended_intensity="Quick"
elif [[ "$scope" = "large" ]] || [[ "$risk_level" = "high" ]] || [[ "$complexity" = "complex" ]]; then
  recommended_intensity="Full"
fi

# --- Output ---
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "recommended_intensity=$recommended_intensity"
```

Make executable:

```bash
chmod +x scripts/engine/intensity-analyze.sh
```

### Step 2 -- Create verification scripts

Create three verification scripts.

**scripts/verify/m008-p01-analyze-output-format.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

output="$(echo "Add a new user authentication module with OAuth2 support" | bash "$f" 2>/dev/null)"

echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^recommended_intensity=" || { echo "FAIL: output missing recommended_intensity="; exit 1; }

# Verify scope is a valid value
scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
case "$scope_val" in
  trivial|moderate|large) ;;
  *) echo "FAIL: scope='$scope_val' is not trivial|moderate|large"; exit 1 ;;
esac

# Verify recommended_intensity is a valid value
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: recommended_intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

echo "PASS: intensity-analyze.sh outputs all required key=value fields with valid values"
```

**scripts/verify/m008-p01-analyze-trivial.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a trivial task as scope=trivial, intensity=Quick.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Fix typo in README.md" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "trivial" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as scope=$scope_val, expected trivial"; exit 1
fi
if [[ "$intensity_val" != "Quick" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as intensity=$intensity_val, expected Quick"; exit 1
fi

echo "PASS: trivial task correctly classified as scope=trivial, recommended_intensity=Quick"
```

**scripts/verify/m008-p01-analyze-moderate.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a multi-component feature as scope=moderate, intensity=Standard.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Add a new API endpoint for user profile updates with validation and error handling" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "moderate" ]]; then
  echo "FAIL: multi-component feature classified as scope=$scope_val, expected moderate"; exit 1
fi
if [[ "$intensity_val" != "Standard" ]]; then
  echo "FAIL: multi-component feature classified as intensity=$intensity_val, expected Standard"; exit 1
fi

echo "PASS: moderate task correctly classified as scope=moderate, recommended_intensity=Standard"
```

**scripts/verify/m008-p01-analyze-risk-escalation.sh:**

```bash
#!/usr/bin/env bash
# Verifies intensity-analyze.sh detects risk signals and escalates intensity.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# A small change to auth code should escalate to Full due to risk
output="$(echo "Update the auth middleware to fix a token validation bug" | bash "$f" 2>/dev/null)"

risk_val="$(echo "$output" | grep "^risk_level=" | cut -d= -f2)"
signals_val="$(echo "$output" | grep "^risk_signals=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$risk_val" != "high" ]]; then
  echo "FAIL: auth-related task has risk_level=$risk_val, expected high"; exit 1
fi
if [[ "$signals_val" = "none" ]]; then
  echo "FAIL: auth-related task has risk_signals=none, expected at least one signal"; exit 1
fi
if [[ "$intensity_val" != "Full" ]]; then
  echo "FAIL: high-risk task has intensity=$intensity_val, expected Full"; exit 1
fi

echo "PASS: auth-related task correctly escalated to risk_level=high, recommended_intensity=Full"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "intensity-analyze.sh accepts a task description and outputs scope,
  risk_level, complexity, risk_signals, and recommended_intensity",
  "intensity-analyze.sh classifies a trivial single-file fix as scope=trivial
  with recommended_intensity=Quick", "intensity-analyze.sh classifies a
  multi-component feature as scope=moderate with recommended_intensity=Standard",
  "intensity-analyze.sh detects risk signals and escalates intensity".
- **Artifacts**: `scripts/engine/intensity-analyze.sh`, three verification scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-analyze-output-format.sh
bash scripts/verify/m008-p01-analyze-trivial.sh
bash scripts/verify/m008-p01-analyze-moderate.sh
bash scripts/verify/m008-p01-analyze-risk-escalation.sh
```

All four should print PASS lines and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-analyze.sh` (create)
- `scripts/verify/m008-p01-analyze-output-format.sh` (create)
- `scripts/verify/m008-p01-analyze-trivial.sh` (create)
- `scripts/verify/m008-p01-analyze-moderate.sh` (create)
- `scripts/verify/m008-p01-analyze-risk-escalation.sh` (create)

## Inputs

### From Previous Tasks

None -- T02 is independent.

### From Disk (Pre-existing)

- `scripts/engine/` directory exists with checkpoint.sh, run.sh, test-resume.sh.
  The new script follows the same directory convention.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- Pattern matching must be case-insensitive (use `tr '[:upper:]' '[:lower:]'`).
- Risk signals stored using parallel indexed arrays (`risk_signal_0`, `risk_signal_1`, etc.)
  -- the Bash 3.2-safe pattern established in MEM001.
- Exit 0 on success, 1 only if no description is provided.
- All output to stdout as key=value pairs. Errors to stderr.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-analyze.sh` exists, is chmod +x, ~150+ lines.
2. `echo "Fix typo in README" | bash scripts/engine/intensity-analyze.sh` outputs
   `scope=trivial`, `risk_level=low`, `complexity=simple`, `risk_signals=none`,
   `recommended_intensity=Quick`.
3. `echo "Add new API endpoint with validation" | bash scripts/engine/intensity-analyze.sh`
   outputs `scope=moderate`, `recommended_intensity=Standard`.
4. `echo "Rewrite the auth middleware" | bash scripts/engine/intensity-analyze.sh`
   outputs `risk_level=high`, `recommended_intensity=Full`, and risk_signals
   includes at least one signal.
5. All four verification scripts print PASS and exit 0.
6. `git status` shows 5 new files.
