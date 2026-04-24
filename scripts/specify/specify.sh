#!/usr/bin/env bash
# scripts/specify/specify.sh — FR-1 orchestrator:specify create-path.
#
# P01 scope: create-path skeleton scaffold (no LLM round-trip — see
# RUNTIME-ASSUMPTIONS.md FR-3). Full --amend semantics and split flow in later
# M014 phases.
#
# Bash 3.2 compatible. Passes scripts/verify/anti-pattern-lint.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# T07 testability: allow hermetic scratch projects to override state writes
# (observability log + scaffolded specs + dual-write targets) without
# relocating dependency lookups (templates/, scripts/, references/).
# PROJECT_ROOT stays at the real repo for deps; STATE_ROOT routes mutation.
STATE_ROOT="$PROJECT_ROOT"
if [ -n "${ORCHESTRATOR_PROJECT_ROOT:-}" ] && [ -d "${ORCHESTRATOR_PROJECT_ROOT}" ]; then
  STATE_ROOT="$(cd "${ORCHESTRATOR_PROJECT_ROOT}" && pwd)"
fi

DESCRIPTION=""
SLUG=""
MILESTONE=""
FORCE=0
YES=0
DRY_RUN=0
SUBCMD="specify"
AMEND_PATH=""
SPLIT_PATH=""

usage() {
  cat <<'EOF'
Usage: specify.sh --description "<prose>" [--slug <slug>] [--milestone <M###>]
                  [--force] [--yes] [--dry-run]
       specify.sh --amend <path> [--yes] [--dry-run]
       specify.sh split <path>

See commands/specify.md for full semantics.
EOF
}

# Parse first positional subcommand.
if [ $# -ge 1 ] && [ "$1" = "split" ]; then
  SUBCMD="split"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --description)
      if [ $# -lt 2 ]; then echo "--description requires a value" >&2; exit 1; fi
      DESCRIPTION="$2"; shift 2 ;;
    --slug)
      if [ $# -lt 2 ]; then echo "--slug requires a value" >&2; exit 1; fi
      SLUG="$2"; shift 2 ;;
    --milestone)
      if [ $# -lt 2 ]; then echo "--milestone requires a value" >&2; exit 1; fi
      MILESTONE="$2"; shift 2 ;;
    --amend)
      if [ $# -lt 2 ]; then echo "--amend requires a path" >&2; exit 1; fi
      SUBCMD="amend"; AMEND_PATH="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --yes) YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      # Positional argument for split subcommand.
      if [ "$SUBCMD" = "split" ] && [ -z "${SPLIT_PATH:-}" ]; then
        SPLIT_PATH="$1"; shift
      else
        echo "specify.sh: unknown argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

# --- Subcommand: split (FR-7 full) ---
if [ "$SUBCMD" = "split" ]; then
  if [ -z "${SPLIT_PATH:-}" ]; then
    echo "split: usage: specify.sh split <spec-path>" >&2
    exit 1
  fi
  if [ ! -f "$SPLIT_PATH" ]; then
    echo "split: spec path not found: $SPLIT_PATH" >&2
    exit 1
  fi

  # Derive source-id from spec directory basename.
  SPLIT_DIR="$(cd "$(dirname "$SPLIT_PATH")" && pwd)"
  SOURCE_ID="$(basename "$SPLIT_DIR")"
  MANIFEST_DIR="${STATE_ROOT}/.orchestrator/specify/decomposition/${SOURCE_ID}"
  MANIFEST_PATH="${MANIFEST_DIR}/manifest.md"

  # Runtime gate: CC only in v1.
  RUNTIME_SIG=""
  if [ "${CLAUDE_CODE_RUNTIME:-0}" = "1" ]; then
    RUNTIME_SIG="claude-code"
  elif [ -x "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" ]; then
    RUNTIME_SIG="$(bash "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" --runtime 2>/dev/null || echo "")"
  fi

  SPLITTER_PROMPT="${PROJECT_ROOT}/templates/spec-splitter-prompt.md"
  DISPATCH_IF="${PROJECT_ROOT}/scripts/dispatch/dispatch-interface.sh"

  if [ "$RUNTIME_SIG" != "claude-code" ]; then
    echo "split: LLM-assisted splitter is Claude Code only in v1 (see RUNTIME-ASSUMPTIONS.md FR-7); fall back to manual spec decomposition" >&2
    exit 3
  fi
  if [ ! -f "$SPLITTER_PROMPT" ]; then
    echo "split: splitter prompt missing: $SPLITTER_PROMPT" >&2
    exit 1
  fi
  if [ ! -x "$DISPATCH_IF" ]; then
    echo "split: dispatch-interface.sh missing or not executable: $DISPATCH_IF" >&2
    exit 1
  fi

  # Dispatch LLM.
  SPLIT_OUT="$(bash "$DISPATCH_IF" --prompt-file "$SPLITTER_PROMPT" --input-file "$SPLIT_PATH" --mode oneshot 2>/dev/null || true)"
  if [ -z "$SPLIT_OUT" ]; then
    echo "split: LLM dispatch produced empty response; bailing" >&2
    exit 1
  fi

  # Basic shape check: manifest must contain "type: decomposition-manifest" and at least two "- slug:" entries.
  ENTRY_COUNT="$(printf '%s\n' "$SPLIT_OUT" | grep -cE '^  - slug:')"
  if [ "$ENTRY_COUNT" -lt 2 ]; then
    echo "split: malformed LLM response (expected >=2 entries, got ${ENTRY_COUNT})" >&2
    exit 1
  fi
  if [ "$ENTRY_COUNT" -gt 4 ]; then
    echo "split: malformed LLM response (expected <=4 entries, got ${ENTRY_COUNT})" >&2
    exit 1
  fi
  if ! printf '%s\n' "$SPLIT_OUT" | grep -qF 'type: decomposition-manifest'; then
    echo "split: malformed LLM response (missing type: decomposition-manifest)" >&2
    exit 1
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    # Emit one FR-19 record per proposed sub-spec.
    SLUGS="$(printf '%s\n' "$SPLIT_OUT" | grep -E '^  - slug:' | sed -E 's/^  - slug: *//; s/ *$//')"
    for s in $SLUGS; do
      printf '{"command":"orchestrator:specify","action_type":"propose-decomposition","target_path":"%s","source_ref":"%s","description":"would scaffold sub-spec %s from %s"}\n' \
        "$MANIFEST_PATH" "$SPLIT_PATH" "$s" "$SOURCE_ID"
    done
    exit 0
  fi

  mkdir -p "$MANIFEST_DIR"
  TMP_M="$(mktemp)"
  printf '%s\n' "$SPLIT_OUT" > "$TMP_M"
  mv "$TMP_M" "$MANIFEST_PATH"

  # Observability: emit unit_close-style record with specs_decomposed field.
  LOG_FILE="${STATE_ROOT}/.orchestrator/execution-log.jsonl"
  TS_S="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  REC_S="{\"type\":\"unit_close\",\"ts\":\"${TS_S}\",\"command\":\"orchestrator:specify-split\",\"source_id\":\"${SOURCE_ID}\",\"sub_specs_proposed\":${ENTRY_COUNT},\"manifest_path\":\"${MANIFEST_PATH}\",\"source\":\"runtime\"}"
  printf '%s\n' "$REC_S" >> "$LOG_FILE" 2>/dev/null || true

  echo "$MANIFEST_PATH"
  exit 0
fi

# --- Preflight: .orchestrator/ exists ---
if [ ! -d "${STATE_ROOT}/.orchestrator" ]; then
  echo "specify.sh: .orchestrator/ not found — run orchestrator:init first" >&2
  exit 2
fi

# --- Templates available ---
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
if [ ! -f "$TEMPLATE" ]; then
  echo "specify.sh: templates/spec-template.md missing" >&2
  exit 1
fi
DUAL_WRITE="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
if [ ! -x "$DUAL_WRITE" ]; then
  echo "specify.sh: scripts/util/dual-write-runtime-md.sh missing or not executable" >&2
  exit 1
fi

# --- Subcommand: amend (FR-14 full three-case semantics) ---
if [ "$SUBCMD" = "amend" ]; then
  if [ ! -f "$AMEND_PATH" ]; then
    echo "specify.sh: --amend target not found: $AMEND_PATH" >&2; exit 1
  fi

  # Snapshot pre-amend shasum for case (b)/(c) byte-preservation invariant (SC-14).
  PRE_SHA="$(shasum -a 256 "$AMEND_PATH" | awk '{print $1}')"

  # Classify each top-level ^## section into case (a), (b), or (c).
  # Extract sections as blocks between adjacent ^## headings.
  AMEND_REPORT="$(mktemp)"
  SECTION_DIR="$(mktemp -d)"
  awk '
    /^## / {
      if (sec != "") {
        fname = sprintf("%s/sec-%03d.md", dir, idx)
        print header > fname
        printf "%s", sec > fname
        close(fname)
        idx++
      }
      header = $0 "\n"
      sec = ""
      next
    }
    { sec = sec $0 "\n" }
    END {
      if (sec != "" || header != "") {
        fname = sprintf("%s/sec-%03d.md", dir, idx)
        print header > fname
        printf "%s", sec > fname
        close(fname)
      }
    }
  ' dir="$SECTION_DIR" "$AMEND_PATH"

  # For each section file, classify and log.
  CHANGED_SECTIONS=""
  for sf in "$SECTION_DIR"/sec-*.md; do
    [ -f "$sf" ] || continue
    SNAME="$(head -n 1 "$sf" | sed -E 's/^## *//')"
    # grep -c always prints a count (0 on no match) and returns 1 on no match;
    # guard with a truthy tail so a zero-count does not abort under pipefail and
    # does not leak a second "0" token from `|| echo 0`.
    TODO_COUNT="$({ grep -cE '<TODO' "$sf" 2>/dev/null || true; } | head -n 1)"
    if [ -z "$TODO_COUNT" ]; then TODO_COUNT=0; fi
    TODO_LINES="$TODO_COUNT"
    # Authored line count = non-blank, non-header, non-TODO-bearing lines in the
    # section file. The awk section-split adds a blank line between header and
    # body, so blank-line exclusion is load-bearing for case (a) detection.
    AUTHORED_LINES="$(tail -n +2 "$sf" | grep -vE '^[[:space:]]*$' | grep -vcE '<TODO' 2>/dev/null || true)"
    AUTHORED_LINES="$(printf '%s\n' "$AUTHORED_LINES" | head -n 1)"
    if [ -z "$AUTHORED_LINES" ]; then AUTHORED_LINES=0; fi
    if [ "$AUTHORED_LINES" -lt 0 ]; then AUTHORED_LINES=0; fi

    CASE=""
    if [ "$TODO_COUNT" -gt 0 ] && [ "$AUTHORED_LINES" -eq 0 ]; then
      CASE="a"  # all-placeholder
    elif [ "$TODO_COUNT" -gt 0 ] && [ "$AUTHORED_LINES" -gt 0 ]; then
      CASE="b"  # partial-placeholder
    else
      CASE="c"  # fully-authored
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
      printf '{"command":"orchestrator:specify","action_type":"amend-section","target_path":"%s","source_ref":"%s","description":"section %s case %s (todo_lines=%d, authored_lines=%d)"}\n' \
        "$AMEND_PATH" "$SNAME" "$SNAME" "$CASE" "$TODO_LINES" "$AUTHORED_LINES"
    fi

    case "$CASE" in
      a)
        # CC: re-run FR-3 LLM-fill. Non-CC: leave unchanged (CON-2 fallback).
        # P04 T06 note: FR-3 LLM-fill wiring is still deferred to a later phase
        # per RUNTIME-ASSUMPTIONS.md FR-3; case (a) here is a no-op that logs the
        # would-be LLM fill as a diagnostic. The byte-preservation invariant is
        # trivially satisfied (nothing changes).
        echo "amend: section '${SNAME}' case (a) all-placeholder — FR-3 LLM-fill deferred (see RUNTIME-ASSUMPTIONS.md FR-3); no-op" >&2
        CHANGED_SECTIONS="${CHANGED_SECTIONS}${SNAME}\n"
        ;;
      b)
        echo "amend: section '${SNAME}' case (b) partial — both <TODO> and authored prose present; operator must resolve manually" >&2
        ;;
      c)
        # Byte-identical pass: leave alone.
        :
        ;;
    esac
  done

  # Post-amend shasum for SC-14 invariant verification.
  POST_SHA="$(shasum -a 256 "$AMEND_PATH" | awk '{print $1}')"
  if [ "$PRE_SHA" != "$POST_SHA" ]; then
    echo "amend: WARN: file shasum changed (pre=${PRE_SHA} post=${POST_SHA}) — SC-14 invariant may be at risk" >&2
  fi

  # Observability: unit_close-style record with specs_amended field.
  LOG_FILE="${STATE_ROOT}/.orchestrator/execution-log.jsonl"
  TS_A="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  REC_A="{\"type\":\"unit_close\",\"ts\":\"${TS_A}\",\"command\":\"orchestrator:specify-amend\",\"target\":\"${AMEND_PATH}\",\"specs_amended\":1,\"pre_shasum\":\"${PRE_SHA}\",\"post_shasum\":\"${POST_SHA}\",\"source\":\"runtime\"}"
  printf '%s\n' "$REC_A" >> "$LOG_FILE" 2>/dev/null || true

  # Re-probe changed sections (AS-7: preserve prior deliberation — probe only fires
  # if CHANGED_SECTIONS non-empty). Under non-CC this is a heuristic-only pass.
  if [ -n "$CHANGED_SECTIONS" ]; then
    PROBE_A="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
    if [ -x "$PROBE_A" ]; then
      bash "$PROBE_A" "$AMEND_PATH" >/dev/null 2>&1 || true
    fi
  fi

  rm -rf "$SECTION_DIR"
  rm -f "$AMEND_REPORT"
  echo "$AMEND_PATH"
  exit 0
fi

# --- Create path: --description required ---
if [ -z "$DESCRIPTION" ]; then
  echo "specify.sh: --description required on create path" >&2
  usage >&2
  exit 1
fi

# --- Slug derivation ---
if [ -z "$SLUG" ]; then
  # Take first 5 words, lowercase, kebab-case, truncate to 40 chars.
  SLUG="$(echo "$DESCRIPTION" | awk '{ for (i=1;i<=5 && i<=NF;i++) printf "%s%s", (i>1?"-":""), $i }' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-\n' '-' | sed -e 's/--*/-/g' -e 's/-$//')"
  if [ ${#SLUG} -gt 40 ]; then SLUG="$(printf '%s' "$SLUG" | cut -c1-40)"; fi
  if [ "$YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "derived slug: $SLUG (pass --yes to accept silently in auto mode)" >&2
  fi
fi

# --- Slug collision scan + next spec number ---
mkdir -p "${STATE_ROOT}/specs"
HIGHEST=0
SLUG_COLLISION=""
for d in "${STATE_ROOT}/specs"/*/ ; do
  [ -d "$d" ] || continue
  bn="$(basename "$d")"
  prefix="$(echo "$bn" | awk -F- '{print $1}')"
  if [ "$prefix" != "" ] && echo "$prefix" | grep -qE '^[0-9]+$'; then
    if [ "$prefix" -gt "$HIGHEST" ]; then HIGHEST="$prefix"; fi
  fi
  # Slug match: directory suffix after NNN- equals SLUG.
  suffix="${bn#*-}"
  if [ "$suffix" = "$SLUG" ]; then
    SLUG_COLLISION="$d"
  fi
done
NEXT=$((10#$HIGHEST + 1))
NEXT_STR="$(printf '%03d' "$NEXT")"
SPEC_DIR="${STATE_ROOT}/specs/${NEXT_STR}-${SLUG}"
SPEC_PATH="${SPEC_DIR}/spec.md"

# --- Collision check ---
if [ -n "$SLUG_COLLISION" ] && [ "$FORCE" -eq 0 ]; then
  echo "specify.sh: slug '${SLUG}' already exists at ${SLUG_COLLISION} (pass --force to overwrite, or pick a different --slug)" >&2
  exit 1
fi
if [ -d "$SPEC_DIR" ] && [ "$FORCE" -eq 0 ]; then
  echo "specify.sh: $SPEC_DIR already exists (pass --force to overwrite)" >&2
  exit 1
fi

CREATED_AT="$(date -u +%Y-%m-%d)"
MS="${MILESTONE:-<TODO: bind to milestone>}"
FEATURE_TITLE="${NEXT_STR}-${SLUG}"

# --- Dry-run manifest emission ---
if [ "$DRY_RUN" -eq 1 ]; then
  WORD_COUNT="$(echo "$DESCRIPTION" | wc -w | tr -d ' ')"
  printf '{"command":"orchestrator:specify","action_type":"scaffold-spec","target_path":"%s","source_ref":"templates/spec-template.md","description":"scaffold %s from %s-word description"}\n' \
    "$SPEC_PATH" "${NEXT_STR}-${SLUG}" "$WORD_COUNT"
  printf '{"command":"orchestrator:specify","action_type":"dual-write-region","target_path":"%s/CLAUDE.md","source_ref":"recent-changes","description":"append %s entry"}\n' \
    "$PROJECT_ROOT" "${NEXT_STR}-${SLUG}"
  printf '{"command":"orchestrator:specify","action_type":"dual-write-region","target_path":"%s/AGENTS.md","source_ref":"recent-changes","description":"append %s entry"}\n' \
    "$PROJECT_ROOT" "${NEXT_STR}-${SLUG}"

  # --- Dry-run probe + conversus-gate manifest (T04) ---
  # Stage a temp scaffolded spec so the probe has real material to inspect,
  # then surface an invoke-conversus-gate manifest record when above-threshold.
  PROBE_DR="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
  TEMPLATE_DR="${PROJECT_ROOT}/templates/spec-template.md"
  if [ -x "$PROBE_DR" ] && [ -f "$TEMPLATE_DR" ]; then
    TMP_DR_DIR="$(mktemp -d)"
    TMP_DR_SPEC="${TMP_DR_DIR}/spec.md"
    esc_dr() { printf '%s' "$1" | sed -e 's/[|/&]/\\&/g'; }
    FS_DR="$(esc_dr "${NEXT_STR}-${SLUG}")"
    CA_DR="$(esc_dr "$CREATED_AT")"
    MS_DR="$(esc_dr "$MS")"
    FT_DR="$(esc_dr "$FEATURE_TITLE")"
    DS_DR="$(esc_dr "$DESCRIPTION")"
    sed \
      -e "s|{{feature_slug}}|${FS_DR}|g" \
      -e "s|{{created_at}}|${CA_DR}|g" \
      -e "s|{{milestone}}|${MS_DR}|g" \
      -e "s|{{feature_title}}|${FT_DR}|g" \
      -e "s|{{description}}|${DS_DR}|g" \
      "$TEMPLATE_DR" > "$TMP_DR_SPEC"
    PROBE_DR_OUT="$(bash "$PROBE_DR" "$TMP_DR_SPEC" 2>/dev/null || true)"
    case "$PROBE_DR_OUT" in
      probe=above-threshold*)
        PROBE_DR_REASON="$(printf '%s\n' "$PROBE_DR_OUT" | sed -E 's/^probe=above-threshold reason=//' | head -n 1)"
        printf '{"command":"orchestrator:specify","action_type":"invoke-conversus-gate","target_path":"%s/conversus/summary/final.md","source_ref":"spec-pressure-test","description":"would invoke conversus adapter on above-threshold probe (reason=%s)"}\n' \
          "$SPEC_DIR" "$PROBE_DR_REASON"
        ;;
    esac
    rm -rf "$TMP_DR_DIR"
  fi

  exit 0
fi

# --- Acquire lock ---
LOCK_MGR="${PROJECT_ROOT}/scripts/lifecycle/lock-manager.sh"
LOCK_ACQUIRED=0
if [ -x "$LOCK_MGR" ]; then
  # Best-effort lock acquisition. Non-fatal if unavailable (single-user projects).
  bash "$LOCK_MGR" acquire specify 2>/dev/null && LOCK_ACQUIRED=1 || true
fi

mkdir -p "$SPEC_DIR"

# --- Scaffold write: temp-file-then-rename ---
TMP_SPEC="$(mktemp)"
# Escape substitution strings for sed. We use a low-risk sed since placeholders
# are simple {{name}} tokens and substitution values are controlled.
esc() {
  # Escape | / & and newlines for sed.
  printf '%s' "$1" | sed -e 's/[|/&]/\\&/g'
}

FS="$(esc "${NEXT_STR}-${SLUG}")"
CA="$(esc "$CREATED_AT")"
MS_ESC="$(esc "$MS")"
FT="$(esc "$FEATURE_TITLE")"
DS_ESC="$(esc "$DESCRIPTION")"

sed \
  -e "s|{{feature_slug}}|${FS}|g" \
  -e "s|{{created_at}}|${CA}|g" \
  -e "s|{{milestone}}|${MS_ESC}|g" \
  -e "s|{{feature_title}}|${FT}|g" \
  -e "s|{{description}}|${DS_ESC}|g" \
  "$TEMPLATE" > "$TMP_SPEC"

mv "$TMP_SPEC" "$SPEC_PATH"

# --- Dual-write Recent Changes ---
FRAG="$(mktemp)"
DESC_SHORT="$(printf '%s' "$DESCRIPTION" | cut -c1-80)"
echo "- ${NEXT_STR}-${SLUG}: ${DESC_SHORT}" > "$FRAG"

DUAL_WRITES=0
if bash "$DUAL_WRITE" --marker recent-changes --content "$FRAG" --root "$STATE_ROOT" --file CLAUDE.md --file AGENTS.md >/dev/null 2>&1; then
  DUAL_WRITES=2
else
  # Fallback: try CLAUDE.md only (e.g., if dual_write_agents=false gated AGENTS.md).
  if bash "$DUAL_WRITE" --marker recent-changes --content "$FRAG" --root "$STATE_ROOT" --file CLAUDE.md >/dev/null 2>&1; then
    DUAL_WRITES=1
  fi
fi
rm -f "$FRAG"

# --- Complexity probe (full, T02+) ---
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
PROBE_STDOUT=""
PROBE_VERDICT="below-threshold"
PROBE_REASON=""
if [ -x "$PROBE" ]; then
  PROBE_STDOUT="$(bash "$PROBE" "$SPEC_PATH" 2>/dev/null || true)"
  case "$PROBE_STDOUT" in
    probe=above-threshold*)
      PROBE_VERDICT="above-threshold"
      # Extract reason=<criterion> (strip any trailing whitespace).
      PROBE_REASON="$(printf '%s\n' "$PROBE_STDOUT" | sed -E 's/^probe=above-threshold reason=//' | head -n 1)"
      ;;
    *)
      PROBE_VERDICT="below-threshold"
      ;;
  esac
fi

# --- Three-way prompt (US-3 y/n/d) ---
CONVERSUS_INVOCATIONS=0
ADAPTER_VERDICTS=""
PROMPT_ANSWER="n"  # Default under --yes per SC-7.

if [ "$PROBE_VERDICT" = "above-threshold" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    # FR-19 dry-run manifest record for the gate invocation.
    printf '{"command":"orchestrator:specify","action_type":"invoke-conversus-gate","target_path":"%s/conversus/summary/final.md","source_ref":"spec-pressure-test","description":"would invoke conversus adapter on above-threshold probe (reason=%s)"}\n' \
      "$SPEC_DIR" "$PROBE_REASON"
    PROMPT_ANSWER="skip-dry-run"
  elif [ "$YES" -eq 1 ]; then
    # Auto-mode default is silent n (no prompt to stdin).
    PROMPT_ANSWER="n"
  elif [ -t 0 ] && [ -t 2 ]; then
    # Interactive with TTY on stdin+stderr.
    printf 'conversus pressure-test recommended (%s). [y/n/d] ' "$PROBE_REASON" >&2
    # Read one character; default n on EOF or empty.
    IFS= read -r -n 1 PROMPT_ANSWER 2>/dev/null || PROMPT_ANSWER="n"
    echo >&2
    case "$PROMPT_ANSWER" in
      y|Y) PROMPT_ANSWER="y" ;;
      d|D) PROMPT_ANSWER="d" ;;
      *)   PROMPT_ANSWER="n" ;;
    esac
  else
    # No TTY + no --yes: act as --yes (default n).
    PROMPT_ANSWER="n"
  fi

  # --- y path: invoke conversus adapter with --strict ---
  if [ "$PROMPT_ANSWER" = "y" ]; then
    ADAPTER="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
    GATE_OUT_DIR="${SPEC_DIR}/conversus/summary"
    GATE_OUT="${GATE_OUT_DIR}/final.md"
    mkdir -p "$GATE_OUT_DIR"
    G_START="$(date +%s)"
    bash "$ADAPTER" gate --strict spec-pressure-test "$SPEC_PATH" "$GATE_OUT" >/tmp/.specify-p04-conversus-$$.out 2>&1
    G_RC=$?
    G_END="$(date +%s)"
    G_MS=$(( (G_END - G_START) * 1000 ))
    CONVERSUS_INVOCATIONS=1
    case "$G_RC" in
      0)
        # PASS or SKIPPED.
        if grep -qE '^SKIPPED:' /tmp/.specify-p04-conversus-$$.out 2>/dev/null; then
          V="SKIPPED"
          echo "warn: conversus adapter reported SKIPPED on y path — proceeding without gate verdict" >&2
        else
          V="PASS"
        fi
        ;;
      2) V="BLOCK"
         echo "conversus gate verdict: BLOCK — draft retained; see ${GATE_OUT}" >&2
         ;;
      1) V="ERROR"
         echo "conversus gate error (rc=1) — see ${GATE_OUT} and stderr" >&2
         ;;
      *) V="UNKNOWN-${G_RC}" ;;
    esac
    ADAPTER_VERDICTS="$V"
    # Emit conversus_gate_invocation JSONL record per FR-16.
    # M026/P02/T02 (FR-4, AD-4): resolve edition from adapter and place
    # "edition" immediately adjacent to "adapter_version". Stderr dropped
    # per DC-5 so adapter diagnostics don't contaminate the JSON literal.
    EDITION="$(bash "$ADAPTER" check 2>/dev/null | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
    : "${EDITION:=unknown}"
    TS_G="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    REC_G="{\"type\":\"conversus_gate_invocation\",\"ts\":\"${TS_G}\",\"gate_id\":\"spec-pressure-test\",\"spec_path\":\"${SPEC_PATH}\",\"verdict\":\"${V}\",\"adapter_version\":\"m011-p07\",\"edition\":\"${EDITION}\",\"llm_calls\":0,\"elapsed_ms\":${G_MS},\"estimated_cost_usd\":0.0,\"source\":\"runtime\"}"
    LOG_FILE="${STATE_ROOT}/.orchestrator/execution-log.jsonl"
    printf '%s\n' "$REC_G" >> "$LOG_FILE" 2>/dev/null || true
    rm -f /tmp/.specify-p04-conversus-$$.out

    # Hard error path: ERROR (rc=1) halts before unit_close. PASS/SKIPPED/BLOCK proceed.
    if [ "$V" = "ERROR" ]; then
      exit 1
    fi

  # --- d path: invoke splitter subcommand ---
  elif [ "$PROMPT_ANSWER" = "d" ]; then
    # Delegate to this same script's split subcommand against the just-scaffolded path.
    bash "$0" split "$SPEC_PATH"
    # On split success, the split body prints the manifest path; we propagate exit.
    SPLIT_RC=$?
    if [ "$SPLIT_RC" -ne 0 ]; then
      exit "$SPLIT_RC"
    fi
  fi
fi

# --- Observability emission (best-effort) ---
LOG="${STATE_ROOT}/.orchestrator/execution-log.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ELAPSED=0  # Skeleton: elapsed time measurement omitted in P01 stub; P04 can add.
REC="{\"type\":\"unit_close\",\"ts\":\"${TS}\",\"command\":\"orchestrator:specify\",\"specs_scaffolded\":1,\"dual_writes\":${DUAL_WRITES},\"conversus_invocations\":${CONVERSUS_INVOCATIONS},\"adapter_verdicts\":\"${ADAPTER_VERDICTS}\",\"elapsed_ms\":${ELAPSED},\"source\":\"runtime\"}"
printf '%s\n' "$REC" >> "$LOG" 2>/dev/null || true

# --- Release lock ---
if [ "$LOCK_ACQUIRED" -eq 1 ]; then
  bash "$LOCK_MGR" release specify >/dev/null 2>&1 || true
fi

echo "$SPEC_PATH"
exit 0
