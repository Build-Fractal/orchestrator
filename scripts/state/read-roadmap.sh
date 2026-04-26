#!/usr/bin/env bash
# scripts/state/read-roadmap.sh — Roadmap markdown parser
# Parses YAML frontmatter, phase checkboxes, risk, depends from roadmap files.
#
# Usage: read-roadmap.sh <roadmap-file> <query> [args...]
#   Queries:
#     frontmatter     — outputs YAML frontmatter as key=value lines (default if no query)
#     phases          — outputs one line per phase: P## status risk depends
#     status <P##>    — outputs "complete" or "incomplete" for a specific phase
#     phase <P##>     — outputs detail for one phase: id status risk depends demo
#     active-phase    — outputs the first incomplete phase ID (risk-ordered, dep-satisfied)
#     affects <P##>   — outputs CSV of phase IDs whose Depends: contains <P##>
#     tier            — outputs the tier value from frontmatter
#     count           — outputs the number of phases
#
# Exits 1 if file doesn't exist or is empty. Errors to stderr.

set -euo pipefail

# Parse arguments
ROADMAP_FILE=""
QUERY="frontmatter"
QUERY_ARG=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      QUERY="$2"; shift 2
      # If query takes an argument (phase, status, affects), grab next non-flag arg
      if [[ "$QUERY" = "phase" || "$QUERY" = "status" || "$QUERY" = "affects" ]]; then
        if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
          # Check if this is a phase ID or the roadmap file
          if [[ "$1" =~ ^P[0-9] ]]; then
            QUERY_ARG="$1"; shift
          fi
        fi
      fi
      ;;
    -*)
      echo "read-roadmap.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      POSITIONAL_ARGS+=("$1"); shift ;;
  esac
done

# Assign positional args: roadmap file, then optional query, then optional query arg
if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
  ROADMAP_FILE="${POSITIONAL_ARGS[0]}"
fi
if [[ ${#POSITIONAL_ARGS[@]} -ge 2 ]]; then
  QUERY="${POSITIONAL_ARGS[1]}"
fi
if [[ ${#POSITIONAL_ARGS[@]} -ge 3 ]]; then
  QUERY_ARG="${POSITIONAL_ARGS[2]}"
fi

if [[ -z "$ROADMAP_FILE" ]]; then
  echo "read-roadmap.sh: missing roadmap file argument" >&2
  echo "Usage: read-roadmap.sh <roadmap-file> [query] [args...]" >&2
  exit 1
fi

# Validate file exists and is non-empty
if [[ ! -f "$ROADMAP_FILE" ]]; then
  echo "read-roadmap.sh: roadmap file not found: $ROADMAP_FILE" >&2
  exit 1
fi

if [[ ! -s "$ROADMAP_FILE" ]]; then
  echo "read-roadmap.sh: roadmap file is empty: $ROADMAP_FILE" >&2
  exit 1
fi

# Extract YAML frontmatter (between --- markers)
extract_frontmatter() {
  sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$ROADMAP_FILE"
}

# Get a frontmatter value by key
get_frontmatter_value() {
  local key="$1"
  local line
  line=$(extract_frontmatter | grep "^${key}:" | head -1) || true
  if [[ -z "$line" ]]; then
    return
  fi
  # Extract value, strip quotes and whitespace
  echo "$line" | sed "s/^${key}:[[:space:]]*//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# Parse all phases into structured data
# Outputs: P## complete|incomplete high|medium|low none|P##,P##
parse_phases() {
  local in_phase=false
  local phase_id=""
  local phase_status=""
  local phase_risk="low"
  local phase_depends="none"
  local phase_demo=""

  while IFS= read -r line; do
    # Match phase checkbox lines: - [x] **P##**: ... or - [ ] **P##**: ...
    # Decimal IDs like P09.1 are a valid roadmap-author convention for
    # post-roadmap additions ("between P09 and P10"); the regex accepts them
    # so the state machine doesn't silently skip a phase it can't see.
    if echo "$line" | grep -qE '^\- \[(x| )\] \*\*P[0-9]+(\.[0-9]+)?\*\*'; then
      # Output previous phase if we had one
      if [[ "$in_phase" = "true" ]]; then
        echo "$phase_id $phase_status $phase_risk $phase_depends"
      fi

      in_phase=true
      phase_risk="low"
      phase_depends="none"

      # Extract phase ID. Greedy match on `P[0-9]+(\.[0-9]+)?` so a P09.1
      # header doesn't get truncated to `P09` (which would silently merge two
      # distinct phases under one ID and let the milestone close with the
      # decimal phase still incomplete).
      phase_id=$(echo "$line" | grep -oE 'P[0-9]+(\.[0-9]+)?' | head -1)

      # Extract status
      if echo "$line" | grep -q '^\- \[x\]'; then
        phase_status="complete"
      else
        phase_status="incomplete"
      fi

      # Extract demo sentence (after — or - dash)
      phase_demo=$(echo "$line" | sed 's/.*— "//' | sed 's/"$//' || true)

    # Match indented Risk/Depends lines under a phase
    elif [[ "$in_phase" = "true" ]]; then
      # Risk line — strip parenthetical commentary so multi-word risk values
      # don't pollute downstream IFS=' ' splits in the active-phase loop.
      if echo "$line" | grep -qiE '^[[:space:]]+-?[[:space:]]*Risk:'; then
        # Risk: <level> [— commentary]. Take only the first token so trailing
        # prose (em-dash, semicolons, periods) cannot leak into pdepends via
        # the space-separated parse_phases output. Documented values are
        # high|medium|low.
        phase_risk=$(echo "$line" \
          | sed 's/.*Risk:[[:space:]]*//' \
          | sed 's/([^)]*)//g' \
          | awk '{print $1}' \
          | tr '[:upper:]' '[:lower:]')
      fi

      # Depends line
      if echo "$line" | grep -qiE '^[[:space:]]+-?[[:space:]]*Depends:'; then
        local deps
        # Strip leading "Depends:", then any parenthesized commentary, then
        # truncate at the first sentence boundary, then normalize whitespace
        # and commas. This lets roadmap authors write
        #   Depends: none (operates on M004 P05)
        #   Depends: P01, P02 (hash utility)
        #   Depends: none within M005 (parallel track). Cross-milestone: ...
        # without the parser capturing commentary as dependency tokens.
        deps=$(echo "$line" \
          | sed 's/.*Depends:[[:space:]]*//' \
          | sed 's/([^)]*)//g' \
          | sed 's/\.[[:space:]].*//' \
          | sed 's/^[[:space:]]*//' \
          | sed 's/[[:space:]]*$//' \
          | sed 's/[[:space:]]*,[[:space:]]*/,/g')
        # "none <qualifier>" forms (e.g. "none within M005") mean no deps.
        if echo "$deps" | grep -qiE '^none([[:space:]]|$)'; then
          deps="none"
        fi
        if [[ "$deps" != "none" && -n "$deps" ]]; then
          phase_depends="$deps"
        fi
      fi

      # Stale line
      if echo "$line" | grep -qiE '^[[:space:]]+-?[[:space:]]*Stale:'; then
        local stale_val
        stale_val=$(echo "$line" | sed 's/.*Stale:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//')
        if [[ "$stale_val" = "true" ]]; then
          phase_status="stale"
        fi
      fi

      # Blank line or next section header — end of phase details
      if echo "$line" | grep -qE '^$' && ! echo "$line" | grep -qE '^[[:space:]]'; then
        : # blank lines within phase block are OK
      fi
    fi
  done < "$ROADMAP_FILE"

  # Output last phase
  if [[ "$in_phase" = "true" ]]; then
    echo "$phase_id $phase_status $phase_risk $phase_depends"
  fi
}

# Execute query
case "$QUERY" in
  frontmatter)
    extract_frontmatter | while IFS= read -r line; do
      key=$(echo "$line" | cut -d: -f1)
      value=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
      echo "${key}=${value}"
    done
    ;;

  phases)
    parse_phases
    ;;

  status)
    if [[ -z "$QUERY_ARG" ]]; then
      echo "read-roadmap.sh: 'status' query requires a phase ID argument" >&2
      exit 1
    fi
    result=$(parse_phases | grep "^${QUERY_ARG} " | awk '{print $2}')
    if [[ -z "$result" ]]; then
      echo "read-roadmap.sh: phase '$QUERY_ARG' not found" >&2
      exit 1
    fi
    echo "$result"
    ;;

  phase)
    if [[ -z "$QUERY_ARG" ]]; then
      echo "read-roadmap.sh: 'phase' query requires a phase ID argument" >&2
      exit 1
    fi
    result=$(parse_phases | grep "^${QUERY_ARG} ")
    if [[ -z "$result" ]]; then
      echo "read-roadmap.sh: phase '$QUERY_ARG' not found" >&2
      exit 1
    fi
    echo "$result"
    ;;

  active-phase)
    # Find the first incomplete phase whose dependencies are all complete
    # Among tied phases with satisfied deps, pick highest risk first
    phases_data=$(parse_phases)

    # Risk priority: high=3, medium=2, low=1
    risk_priority() {
      case "$1" in
        high) echo 3 ;;
        medium) echo 2 ;;
        low) echo 1 ;;
        *) echo 0 ;;
      esac
    }

    best_phase=""
    best_risk_score=0

    while IFS=' ' read -r pid pstatus prisk pdepends; do
      # Skip complete and stale phases
      if [[ "$pstatus" != "incomplete" ]]; then
        continue
      fi

      # Check if all dependencies are satisfied
      deps_satisfied=true
      if [[ "$pdepends" != "none" ]]; then
        # Split comma-separated deps
        # IFS=',' is local to read -ra (bash built-in) — safe, does not leak
        IFS=',' read -ra dep_list <<< "$pdepends"
        for dep in "${dep_list[@]}"; do
          dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
          if [[ -z "$dep" ]]; then
            continue
          fi
          # Unparseable token = parser bug or malformed roadmap. A phase with
          # a non-P## dependency must refuse to schedule rather than silently
          # declaring itself ready (this was the load-bearing miss that let a
          # parens-in-Risk parse mishap mark P02 ready while P01 was incomplete).
          if [[ ! "$dep" =~ ^P[0-9] ]]; then
            echo "read-roadmap.sh: phase $pid has unparseable dependency token '$dep' (full Depends: '$pdepends')" >&2
            deps_satisfied=false
            break
          fi
          # `|| true` is load-bearing: under `set -e + pipefail`, a no-match
          # grep would otherwise abort the whole script silently.
          dep_status=$(echo "$phases_data" | grep "^${dep} " | awk '{print $2}' 2>/dev/null || true)
          if [[ "$dep_status" != "complete" ]]; then
            deps_satisfied=false
            break
          fi
        done
      fi

      if [[ "$deps_satisfied" = "true" ]]; then
        score=$(risk_priority "$prisk")
        if [[ $score -gt $best_risk_score ]]; then
          best_phase="$pid"
          best_risk_score=$score
        elif [[ $score -eq $best_risk_score && -z "$best_phase" ]]; then
          best_phase="$pid"
        fi
      fi
    done <<< "$phases_data"

    if [[ -n "$best_phase" ]]; then
      echo "$best_phase"
    else
      echo "none"
    fi
    ;;

  affects)
    if [[ -z "$QUERY_ARG" ]]; then
      echo "read-roadmap.sh: 'affects' query requires a phase ID argument" >&2
      exit 1
    fi
    # Find phases whose Depends list contains the target phase. Output CSV in
    # roadmap-declaration order. Empty result → "none".
    result=$(parse_phases | awk -v target="$QUERY_ARG" '
      {
        n = split($4, deps, ",")
        for (i = 1; i <= n; i++) {
          if (deps[i] == target) { print $1; next }
        }
      }
    ' | paste -sd, -)
    echo "${result:-none}"
    ;;

  tier)
    value=$(get_frontmatter_value "tier")
    if [[ -n "$value" ]]; then
      echo "$value"
    else
      echo "null"
    fi
    ;;

  count)
    count=$(parse_phases | wc -l | tr -d ' ')
    echo "$count"
    ;;

  *)
    echo "read-roadmap.sh: unknown query '$QUERY'" >&2
    echo "Valid queries: frontmatter, phases, status, phase, active-phase, affects, tier, count" >&2
    exit 1
    ;;
esac
