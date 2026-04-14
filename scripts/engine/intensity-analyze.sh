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
