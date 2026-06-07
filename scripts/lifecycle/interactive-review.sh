#!/usr/bin/env bash
# scripts/lifecycle/interactive-review.sh — M034 P02 (FR-5 interactive_review stage spine).
#
# The `interactive_review` lifecycle stage, invoked for phases that declare
# `review_gates: [...]` in their plan frontmatter: the first-class review stage
# that sits between artifact authoring and SIGNOFF.md population. Consumes a
# *-DECISIONS.md packet (P01), walks its active (non-superseded) decisions in
# packet order, records one REVIEW.md block per operator response (append-only
# audit trail, FR-7), and populates the sibling SIGNOFF.md from the terminal
# review block.
#
# FR-5 contract: the stage ALWAYS writes REVIEW.md + SIGNOFF.md on the
# non-interactive paths; it NEVER silently skips (CON-5/SC-5). A gate reached
# with its packet absent fails CLOSED (exit 3) rather than passing.
#
# Case A split (CON-7 renderer routing — selection routes ONLY through
# dispatch-interface.sh --probe-renderer; this script NEVER calls
# AskUserQuestion / elicitation directly from bash):
#   - interactive-cc / interactive-cursor: the orchestrating AGENT drives the
#     walkthrough and writes REVIEW.md directly (this script emits a render
#     descriptor — T06).
#   - test-responses / headless / auto: THIS script writes REVIEW.md +
#     SIGNOFF.md deterministically.
#
# CON-1: bash 3.2 / POSIX-sh single file — no declare -A, no ${var,,}, no
# process substitution. Pipes / awk / $() / jq permitted in the body.
# RISK-1: field bodies (rationale, override_value) are written via quoted
# printf '%s' — never eval, never unquoted re-expansion.
#
# jq is REQUIRED (same posture as write-decisions.sh).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=scripts/knowledge/lib/decisions-constants.sh
. "$SCRIPT_DIR/../knowledge/lib/decisions-constants.sh"

READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
DISPATCH_IFACE="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

# --- jq-required guard. -----------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: interactive-review.sh requires jq (structured fixture parse). Install jq and retry." >&2
  exit 1
fi

# --- Arg parse (--field=value, mirroring write-decisions.sh). ----------------
MILESTONE=""
PHASE=""
GATE_ID=""
PACKET=""
POLICY="$DECISIONS_POLICY_DEFAULT"
TEST_RESPONSES=""
RESUME_FILE=""
REVIEW_OUT=""
SIGNOFF_OUT=""

for arg in "$@"; do
  case "$arg" in
    --milestone=*)      MILESTONE="${arg#*=}" ;;
    --phase=*)          PHASE="${arg#*=}" ;;
    --gate-id=*)        GATE_ID="${arg#*=}" ;;
    --packet=*)         PACKET="${arg#*=}" ;;
    --policy=*)         POLICY="${arg#*=}" ;;
    --test-responses=*) TEST_RESPONSES="${arg#*=}" ;;
    --resume=*)         RESUME_FILE="${arg#*=}" ;;
    --review-out=*)     REVIEW_OUT="${arg#*=}" ;;
    --signoff-out=*)    SIGNOFF_OUT="${arg#*=}" ;;
    *)
      echo "ERROR: interactive-review: unrecognized argument '$arg'. Use --milestone= / --phase= / --gate-id= / --packet= / --policy= / --test-responses= / --resume= / --review-out= / --signoff-out=." >&2
      exit 1
      ;;
  esac
done

# --- Derive REVIEW_OUT / SIGNOFF_OUT defaults from the packet path. ----------
if [ -z "$REVIEW_OUT" ]; then
  REVIEW_OUT="${PACKET%-DECISIONS.md}-REVIEW.md"
fi
if [ -z "$SIGNOFF_OUT" ]; then
  SIGNOFF_OUT="${PACKET%-DECISIONS.md}-SIGNOFF.md"
fi

# --- Packet-absent guard (Edge Case "gate reached, packet absent"). ----------
# When NOT resuming and the packet is missing, fail CLOSED (exit 3). Do NOT
# silently pass the gate.
if [ -z "$RESUME_FILE" ] && [ ! -f "$PACKET" ]; then
  echo "ERROR: interactive-review: packet not found: $PACKET (gate $GATE_ID fails closed)" >&2
  exit 3
fi

# --- Field extractor: print the `- **<field>**: ` value within the `## <id>`
# block. Bash-3.2-safe awk; used to surface decision context. ----------------
_packet_field() {
  awk -v want="$2" -v field="$3" '
    /^## / { inblk = 0 }
    /^- \*\*id\*\*: / { v=$0; sub(/^- \*\*id\*\*: /,"",v); inblk=(v==want)?1:0; next }
    inblk && $0 ~ ("^- \\*\\*" field "\\*\\*: ") {
      line=$0; sub("^- \\*\\*" field "\\*\\*: ","",line); print line; exit
    }
  ' "$1"
}

# --- ISO timestamp. ----------------------------------------------------------
# ORCH_REVIEW_FIXED_TS (test-only, M034 P03 / FR-15): when set, emit the literal
# value so two otherwise-identical runs are byte-equal for the byte-parity audit.
# Unset (production): real UTC timestamp as before.
_iso_now() {
  if [ -n "${ORCH_REVIEW_FIXED_TS:-}" ]; then
    printf '%s' "$ORCH_REVIEW_FIXED_TS"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# --- REVIEW.md helpers. ------------------------------------------------------

# Print the count of `^## ` blocks currently in the REVIEW file (0 if absent).
_review_block_count() {
  rf="$1"
  [ -f "$rf" ] || { printf '0\n'; return 0; }
  c=$(grep -c '^## ' "$rf" 2>/dev/null || true)
  [ -n "$c" ] || c=0
  printf '%s\n' "$c"
}

# Write the REVIEW.md header (frontmatter + heading) iff the file is absent.
# Append-only afterward; never rewrite the header.
_ensure_review_header() {
  rf="$1"
  [ -f "$rf" ] && return 0
  rdir=$(dirname "$rf")
  mkdir -p "$rdir"
  pbase=$(basename "$PACKET")
  {
    printf -- '---\n'
    printf 'schema_version: "%s"\n' "$DECISIONS_SCHEMA_VERSION"
    printf 'type: review-log\n'
    printf 'milestone: "%s"\n' "$MILESTONE"
    printf 'phase: "%s"\n' "$PHASE"
    printf 'gate_id: "%s"\n' "$GATE_ID"
    printf 'packet: "%s"\n' "$pbase"
    printf -- '---\n'
    printf '\n'
    printf '# Review Log — %s\n' "$GATE_ID"
  } > "$rf"
}

# Append (>>) one review block. Field bodies via quoted printf '%s' (RISK-1).
#   _append_review_block <review_file> <index> <id> <action> <rationale> <override_value> [gate_kind]
# The optional 7th arg `gate_kind`: when it equals `confirm-the-bridge` (a
# boundary_translation entry, M034 T05 / FR-13), emit a `- **gate_kind**:`
# line so the audit trail distinguishes a bridge-confirmation from an ordinary
# decision; when the action is `na` on such an entry, also emit
# `- **acknowledged_not_applicable**: true` (the FR-13 "operator can mark N/A"
# edge case — recorded in REVIEW.md, still counts reviewed via `reviewed: <id>`).
_append_review_block() {
  rf="$1"; idx="$2"; rid="$3"; raction="$4"; rrationale="$5"; rvalue="$6"
  rgate_kind="${7:-}"
  riso=$(_iso_now)
  {
    printf '\n'
    printf '## %s — review block %s\n' "$rid" "$idx"
    printf -- '- **id**: %s\n' "$rid"
    printf -- '- **action**: %s\n' "$raction"
    printf -- '- **reviewed_at**: %s\n' "$riso"
    if [ -n "$rrationale" ]; then
      printf -- '- **rationale**: %s\n' "$rrationale"
    fi
    if [ "$raction" = "override" ] && [ -n "$rvalue" ]; then
      printf -- '- **override_value**: %s\n' "$rvalue"
    fi
    if [ "$rgate_kind" = "confirm-the-bridge" ]; then
      printf -- '- **gate_kind**: confirm-the-bridge\n'
    fi
    if [ "$raction" = "na" ]; then
      printf -- '- **acknowledged_not_applicable**: true\n'
    fi
    printf 'reviewed: %s\n' "$rid"
  } >> "$rf"
}

# --- SIGNOFF helper. ---------------------------------------------------------
#   _populate_signoff <signoff_file> <terminal_block_count> <approved_by>
# Overwrites the SIGNOFF file with approved_by flipped from null.
_populate_signoff() {
  sf="$1"; sterm="$2"; sapprover="$3"
  sdir=$(dirname "$sf")
  mkdir -p "$sdir"
  rbase=$(basename "$REVIEW_OUT")
  siso=$(_iso_now)
  {
    printf -- '---\n'
    printf 'schema_version: "%s"\n' "$DECISIONS_SCHEMA_VERSION"
    printf 'type: signoff\n'
    printf 'milestone: "%s"\n' "$MILESTONE"
    printf 'phase: "%s"\n' "$PHASE"
    printf 'gate_id: "%s"\n' "$GATE_ID"
    printf 'approved_by: "%s"\n' "$sapprover"
    printf 'review_md: "%s"\n' "$rbase"
    printf 'terminal_review_block: %s\n' "$sterm"
    printf 'signed_at: "%s"\n' "$siso"
    printf -- '---\n'
    printf '\n'
    printf '# Sign-off — %s\n' "$GATE_ID"
    printf '\n'
    printf 'Populated from REVIEW.md terminal entry (block %s).\n' "$sterm"
  } > "$sf"
}

# --- _emit_event: append a JSONL line to the milestone execution-log. --------
# $1 = full JSON object string (already formed by the caller). Append-only.
# Honors ORCH_EVENT_LOG override (verifier hermeticity) so the real milestone
# log is never touched in tests. Never fails the run on a log-write error.
_emit_event() {
  ev_log="$REPO_ROOT/.orchestrator/milestones/$MILESTONE/execution-log.jsonl"
  if [ -n "${ORCH_EVENT_LOG:-}" ]; then ev_log="$ORCH_EVENT_LOG"; fi
  mkdir -p "$(dirname "$ev_log")" 2>/dev/null || return 0
  printf '%s\n' "$1" >> "$ev_log" 2>/dev/null || true
}

# --- _run_test_responses (this task's deliverable, SC-3 / PC-3). -------------
# Fully deterministic: no prompt, no network. One REVIEW.md block per active id
# in packet order. Ids absent from the fixture default to accept.
_run_test_responses() {
  if [ ! -f "$TEST_RESPONSES" ]; then
    echo "ERROR: interactive-review: --test-responses fixture not found: $TEST_RESPONSES" >&2
    exit 1
  fi

  FIXTURE_JSON="$(cat "$TEST_RESPONSES")"
  if ! printf '%s' "$FIXTURE_JSON" | jq -e 'type=="array"' >/dev/null 2>&1; then
    echo "ERROR: interactive-review: --test-responses fixture is not a JSON array: $TEST_RESPONSES" >&2
    exit 1
  fi

  _ensure_review_header "$REVIEW_OUT"
  base=$(_review_block_count "$REVIEW_OUT")

  ids="$(bash "$READER" active-ids "$PACKET")"

  n=$base
  for id in $ids; do
    [ -n "$id" ] || continue
    entry="$(printf '%s' "$FIXTURE_JSON" | jq -c --arg id "$id" '.[] | select(.id==$id)' | head -n 1)"
    if [ -z "$entry" ]; then
      action="accept"
      rationale=""
      value=""
    else
      action="$(printf '%s' "$entry" | jq -r '.action // "accept"')"
      value="$(printf '%s' "$entry" | jq -r '.value // ""')"
      rationale="$(printf '%s' "$entry" | jq -r '.rationale // ""')"
    fi

    if [ "$(decisions_is_valid_action "$action")" != "ok" ]; then
      echo "ERROR: interactive-review: invalid action '$action' for decision '$id' (allowed: $DECISIONS_ACTION_VALUES)." >&2
      exit 1
    fi

    # gate_kind: a boundary_translation entry surfaces as confirm-the-bridge
    # (FR-13 / T05). Ordinary decisions pass an empty gate_kind.
    gate_kind=""
    if [ "$(_packet_field "$PACKET" "$id" type)" = "boundary_translation" ]; then
      gate_kind="confirm-the-bridge"
    fi

    n=$((n + 1))
    _append_review_block "$REVIEW_OUT" "$n" "$id" "$action" "$rationale" "$value" "$gate_kind"
  done

  _populate_signoff "$SIGNOFF_OUT" "$n" "${ORCH_REVIEWER:-operator}"

  reviewed_count=$((n - base))
  echo "INTERACTIVE-REVIEW: reviewed $reviewed_count decisions -> $REVIEW_OUT"
  exit 0
}

# --- Stub functions (filled by later tasks — keep the marker comments). ------

# >>> T03 fills this: headless auto-mode policy paths (FR-8/FR-9). <<<
# Headless / auto-mode entry: no human, no blocking read. Branches on the
# declared $POLICY (FR-8) and never deadlocks — every branch ends in an
# explicit `exit` (watchdog-never-fires guarantee). CON-5/SC-5: the
# *-DECISIONS.md is already on disk and is NEVER touched here; only
# operator-touch (REVIEW/SIGNOFF/CONTINUE) is gated.
_run_headless_policy() {
  if [ "$(decisions_is_valid_policy "$POLICY")" != "ok" ]; then
    echo "ERROR: interactive-review: invalid policy '$POLICY' (allowed: $DECISIONS_POLICY_VALUES)." >&2
    exit 1
  fi

  case "$POLICY" in
    defer)
      idx=$(_review_block_count "$REVIEW_OUT")
      pkt_dir=$(dirname "$PACKET")

      # FR-9 QUESTIONS.md hand-off: a markdown checklist a human answers
      # out-of-band (mirrors the M033 P04 conflict hand-off shape). Written
      # first, then the continue-file + JSONL + clean exit.
      QUESTIONS_FILE="$pkt_dir/${GATE_ID}-QUESTIONS.md"
      {
        printf -- '# Review Questions — %s\n' "$GATE_ID"
        printf '\n'
        printf 'Headless `defer` policy: this gate awaits human completion.\n'
        printf 'Answer each active decision below, then run `orchestrator:resume`.\n'
        printf '\n'
        for qid in $(bash "$READER" active-ids "$PACKET"); do
          [ -n "$qid" ] || continue
          q_summary=$(_packet_field "$PACKET" "$qid" "summary")
          q_impact=$(_packet_field "$PACKET" "$qid" "concrete_impact")
          printf -- '- [ ] **%s** — %s\n' "$qid" "$q_summary"
          printf -- '  - impact: %s\n' "$q_impact"
        done
      } > "$QUESTIONS_FILE"

      # Continue-file (PC-5 schema) — atomic tmpfile + mv (CON-1).
      CONTINUE_FILE="$pkt_dir/${GATE_ID}-CONTINUE.md"
      ciso=$(_iso_now)
      tmp_continue="${CONTINUE_FILE}.tmp.$$"
      {
        printf -- '---\n'
        printf 'schema_version: "%s"\n' "$DECISIONS_SCHEMA_VERSION"
        printf 'type: pending-review-continue\n'
        printf 'milestone_id: "%s"\n' "$MILESTONE"
        printf 'phase_id: "%s"\n' "$PHASE"
        printf 'gate_id: "%s"\n' "$GATE_ID"
        printf 'last_review_md_block_index: %s\n' "$idx"
        printf 'declared_policy: "defer"\n'
        printf 'created_at: "%s"\n' "$ciso"
        printf 'packet_path: "%s"\n' "$PACKET"
        printf 'review_md_path: "%s"\n' "$REVIEW_OUT"
        printf 'status: "pending-review"\n'
        printf -- '---\n'
        printf '\n'
        printf 'Gate %s deferred for later human review via `orchestrator:resume`.\n' "$GATE_ID"
      } > "$tmp_continue"
      mv -f "$tmp_continue" "$CONTINUE_FILE"

      _emit_event "$(printf '{"record_type":"pending_review","milestone":"%s","phase":"%s","gate_id":"%s","last_review_md_block_index":%s,"declared_policy":"defer","timestamp":"%s"}' "$MILESTONE" "$PHASE" "$GATE_ID" "$idx" "$ciso")"

      echo "INTERACTIVE-REVIEW: deferred gate $GATE_ID -> $CONTINUE_FILE"
      exit 0
      ;;

    accept-with-audit)
      _ensure_review_header "$REVIEW_OUT"
      base=$(_review_block_count "$REVIEW_OUT")
      n=$base
      for id in $(bash "$READER" active-ids "$PACKET"); do
        [ -n "$id" ] || continue
        n=$((n + 1))
        _append_review_block "$REVIEW_OUT" "$n" "$id" "accept" \
          "auto-accepted (accept-with-audit policy)" ""
        aiso=$(_iso_now)
        _emit_event "$(printf '{"record_type":"auto_accepted","milestone":"%s","phase":"%s","gate_id":"%s","decision_id":"%s","timestamp":"%s"}' "$MILESTONE" "$PHASE" "$GATE_ID" "$id" "$aiso")"
      done
      _populate_signoff "$SIGNOFF_OUT" "$n" "auto-accept"
      accepted=$((n - base))
      echo "INTERACTIVE-REVIEW: accept-with-audit gate $GATE_ID ($accepted decisions)"
      exit 0
      ;;

    refuse-entry)
      riso=$(_iso_now)
      _emit_event "$(printf '{"record_type":"refused_entry","milestone":"%s","phase":"%s","gate_id":"%s","timestamp":"%s"}' "$MILESTONE" "$PHASE" "$GATE_ID" "$riso")"
      echo "INTERACTIVE-REVIEW: refuse-entry gate $GATE_ID — phase entry refused (declared policy)" >&2
      exit 30
      ;;
  esac
}

# --- Continue-file frontmatter reader (PC-5). --------------------------------
# Print the value of frontmatter key $2 in continue-file $1. Handles both the
# quoted form (`key: "value"`) and the bare form (`key: 0`). grep+sed only
# (CON-1 — no yaml lib). Strips surrounding double-quotes if present.
_continue_field() {
  cf="$1"; key="$2"
  line=$(grep -E "^${key}:[[:space:]]*" "$cf" 2>/dev/null | head -n 1)
  [ -n "$line" ] || { printf ''; return 0; }
  v=$(printf '%s' "$line" | sed -E "s/^${key}:[[:space:]]*//")
  # Strip a single pair of surrounding double-quotes if present.
  v=$(printf '%s' "$v" | sed -E 's/^"(.*)"$/\1/')
  printf '%s' "$v"
}

# >>> T04 fills this: --resume re-entry at last_review_md_block_index (PC-5). <<<
# Consume a `<gate_id>-CONTINUE.md` continue-file (PC-5 schema) and re-enter the
# review walkthrough at the recorded last_review_md_block_index WITHOUT
# re-writing the already-recorded REVIEW.md blocks (append-only across the
# defer->resume boundary). Completes the remaining (pending) decisions, populates
# SIGNOFF.md, emits a `review_resumed` JSONL event, and removes the consumed
# continue-file. The "operator answers, then crash before SIGNOFF" edge case:
# partial answers on disk survive; resume continues from them.
_run_resume() {
  if [ ! -f "$RESUME_FILE" ]; then
    echo "ERROR: interactive-review: --resume continue-file not found: $RESUME_FILE" >&2
    exit 1
  fi

  # Parse the continue-file frontmatter; overwrite the run vars (so --resume
  # needs no other flags). REVIEW_OUT comes from review_md_path; SIGNOFF_OUT is
  # derived from the packet path as in T02.
  MILESTONE="$(_continue_field "$RESUME_FILE" "milestone_id")"
  PHASE="$(_continue_field "$RESUME_FILE" "phase_id")"
  GATE_ID="$(_continue_field "$RESUME_FILE" "gate_id")"
  resume_idx="$(_continue_field "$RESUME_FILE" "last_review_md_block_index")"
  PACKET="$(_continue_field "$RESUME_FILE" "packet_path")"
  REVIEW_OUT="$(_continue_field "$RESUME_FILE" "review_md_path")"
  [ -n "$resume_idx" ] || resume_idx=0
  [ -n "$REVIEW_OUT" ] || REVIEW_OUT="${PACKET%-DECISIONS.md}-REVIEW.md"
  SIGNOFF_OUT="${PACKET%-DECISIONS.md}-SIGNOFF.md"

  # Validate the packet still exists (else fail closed, exit 3 — same posture as
  # the non-resume packet-absent guard).
  if [ ! -f "$PACKET" ]; then
    echo "ERROR: interactive-review: packet not found on resume: $PACKET (gate $GATE_ID fails closed)" >&2
    exit 3
  fi

  _ensure_review_header "$REVIEW_OUT"

  # Re-entry: an active id is PENDING iff it is NOT already marked reviewed in
  # REVIEW_OUT. Iterate active ids in packet order; SKIP already-reviewed ones so
  # re-entry never double-writes a block. `current` continues the block index
  # from the blocks already on disk.
  current=$(_review_block_count "$REVIEW_OUT")

  # Pre-load the fixture (if the deterministic verifier resume path is taken).
  HAVE_FIXTURE=0
  if [ -n "$TEST_RESPONSES" ]; then
    if [ ! -f "$TEST_RESPONSES" ]; then
      echo "ERROR: interactive-review: --test-responses fixture not found: $TEST_RESPONSES" >&2
      exit 1
    fi
    FIXTURE_JSON="$(cat "$TEST_RESPONSES")"
    if ! printf '%s' "$FIXTURE_JSON" | jq -e 'type=="array"' >/dev/null 2>&1; then
      echo "ERROR: interactive-review: --test-responses fixture is not a JSON array: $TEST_RESPONSES" >&2
      exit 1
    fi
    HAVE_FIXTURE=1
  fi

  ids="$(bash "$READER" active-ids "$PACKET")"
  n=$current
  for id in $ids; do
    [ -n "$id" ] || continue
    # Skip ids already recorded in REVIEW_OUT (no double-write).
    if grep -E "^reviewed: ${id}[[:space:]]*\$" "$REVIEW_OUT" >/dev/null 2>&1; then
      continue
    fi

    if [ "$HAVE_FIXTURE" = "1" ]; then
      entry="$(printf '%s' "$FIXTURE_JSON" | jq -c --arg id "$id" '.[] | select(.id==$id)' | head -n 1)"
      if [ -z "$entry" ]; then
        action="accept"; rationale=""; value=""
      else
        action="$(printf '%s' "$entry" | jq -r '.action // "accept"')"
        value="$(printf '%s' "$entry" | jq -r '.value // ""')"
        rationale="$(printf '%s' "$entry" | jq -r '.rationale // ""')"
      fi
    else
      # No deterministic fixture under --resume: a headless re-defer would
      # deadlock the round-trip. Fail explicitly rather than silently looping.
      echo "ERROR: interactive-review: --resume without --test-responses requires an interactive renderer (agent walkthrough). Headless resume is unsupported." >&2
      exit 1
    fi

    if [ "$(decisions_is_valid_action "$action")" != "ok" ]; then
      echo "ERROR: interactive-review: invalid action '$action' for decision '$id' (allowed: $DECISIONS_ACTION_VALUES)." >&2
      exit 1
    fi

    n=$((n + 1))
    _append_review_block "$REVIEW_OUT" "$n" "$id" "$action" "$rationale" "$value"
  done

  _populate_signoff "$SIGNOFF_OUT" "$n" "${ORCH_REVIEWER:-operator}"

  riso=$(_iso_now)
  _emit_event "$(printf '{"record_type":"review_resumed","milestone":"%s","phase":"%s","gate_id":"%s","resumed_from_block":%s,"timestamp":"%s"}' "$MILESTONE" "$PHASE" "$GATE_ID" "$resume_idx" "$riso")"

  rm -f "$RESUME_FILE"

  echo "INTERACTIVE-REVIEW: resumed gate $GATE_ID from block $resume_idx -> SIGNOFF"
  exit 0
}

# --- _emit_interactive_descriptor (FR-6, Case A). ----------------------------
# The interactive-cc / interactive-cursor path: emit a render-descriptor on
# stdout (a coordination boundary mirroring local-agent.sh) and exit 0. This
# script NEVER calls AskUserQuestion / elicitation from bash (CON-7 / AD-3) —
# the orchestrating AGENT issues the question primitive in-process (Case A) and
# writes REVIEW.md directly per references/interactive-review-renderer.md.
#   $1 = renderer name (interactive-cc | interactive-cursor).
_emit_interactive_descriptor() {
  _renderer_name="$1"
  cat <<EOF
---
schema_version: "1.0"
type: "interactive-review-descriptor"
renderer: "${_renderer_name}"
gate_id: "${GATE_ID}"
packet: "${PACKET}"
review_out: "${REVIEW_OUT}"
signoff_out: "${SIGNOFF_OUT}"
---

# Interactive Review — orchestrating-agent action required

Render the decision packet at ${PACKET} interactively per
references/interactive-review-renderer.md: surface each active decision via
the runtime question primitive (AskUserQuestion for interactive-cc; Cursor MCP
elicitation for interactive-cursor, P03), append one REVIEW.md block per
response to ${REVIEW_OUT}, and populate ${SIGNOFF_OUT} from the terminal entry.

Renderer: ${_renderer_name} (Case A — agent issues the question primitive in-process)
Reference: references/interactive-review-renderer.md
EOF
  exit 0
}

# --- Dispatch skeleton. ------------------------------------------------------
if [ -n "${RESUME_FILE:-}" ]; then
  _run_resume
elif [ -n "${TEST_RESPONSES:-}" ]; then
  _run_test_responses
else
  _renderer="$(bash "$DISPATCH_IFACE" --probe-renderer 2>/dev/null | grep -E '^renderer=' | head -n 1 | cut -d= -f2)"
  case "$_renderer" in
    interactive-cc|interactive-cursor) _emit_interactive_descriptor "$_renderer" ;;
    *) _run_headless_policy ;;
  esac
fi
