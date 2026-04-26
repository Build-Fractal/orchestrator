#!/usr/bin/env bash
# scripts/intake/proposal-emit.sh
# M024/P01/T04 — Emit a 6-axis intake proposal at .orchestrator/intake/<id>/proposal.md.
#
# Inputs (one of):
#   --input <string>    Free-text input (idea / paragraph / fragment).
#   --spec-path <path>  Path to an existing feature spec.
#   (none)              Empty — caller is expected to invoke Q&A first; P01 emits empty-shape stub.
#
# Output:
#   proposal_path=<absolute path>   to stdout
#
# Exit 0 on success, 2 on usage error, 1 on internal error.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"
SHAPE_DETECT="$ROOT/scripts/intake/shape-detect.sh"
ID_ALLOCATE="$ROOT/scripts/intake/intake-id-allocate.sh"
INTENSITY="$ROOT/scripts/engine/intensity-recommend.sh"
INTAKE_ROOT="$ROOT/.orchestrator/intake"

INPUT=""
SPEC_PATH=""
QA_ANSWERS_FROM=""
AXES_FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)            INPUT="$2"; shift 2 ;;
    --spec-path)        SPEC_PATH="$2"; shift 2 ;;
    --intake-root)      INTAKE_ROOT="$2"; shift 2 ;;  # test-only override
    --qa-answers-from)  QA_ANSWERS_FROM="$2"; shift 2 ;;
    --axes-from)        AXES_FROM="$2"; shift 2 ;;
    -h|--help)
      echo "usage: proposal-emit.sh [--input <string>] [--spec-path <path>] [--qa-answers-from <file>] [--axes-from <file>]" >&2
      exit 2 ;;
    *)
      echo "proposal-emit.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

QA_ANSWERS_FROM="${QA_ANSWERS_FROM:-}"
AXES_FROM="${AXES_FROM:-}"

# (M024/P06/T02) --axes-from parsing — populate <axis>_override shell vars and
# build REVISE_AXES_KEYS for the rationale-loop skip branch below.
REVISE_AXES_KEYS=""
REVISE_AXES_DONE=0
if [ -n "$AXES_FROM" ]; then
  [ -f "$AXES_FROM" ] || { echo "proposal-emit.sh: axes-from file not found: $AXES_FROM" >&2; exit 1; }
  # Stash axes-from values in a revise_* namespace so they are applied AFTER
  # the paragraph + spec deep classifiers (which write to <axis>_override).
  # Operator revisions must win over deep-classifier output.
  while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      scope_tier)            scope_tier_revise="$val" ;;
      decomposition)         decomposition_revise="$val" ;;
      design_gate)           design_gate_revise="$val" ;;
      conversus_gate)        conversus_gate_revise="$val" ;;
      intensity)             intensity_revise="$val" ;;
      recommended_command)   recommended_command_revise="$val" ;;
      *)
        echo "proposal-emit.sh: unknown axes-from key '$key' — supported: scope_tier decomposition design_gate conversus_gate intensity recommended_command" >&2
        exit 2 ;;
    esac
    REVISE_AXES_KEYS="${REVISE_AXES_KEYS}${key}
"
  done < "$AXES_FROM"
  REVISE_AXES_DONE=1
fi

[ -f "$TEMPLATE" ]      || { echo "proposal-emit.sh: template missing: $TEMPLATE" >&2; exit 1; }
[ -x "$SHAPE_DETECT" ]  || { echo "proposal-emit.sh: shape-detect not executable" >&2; exit 1; }
[ -x "$ID_ALLOCATE" ]   || { echo "proposal-emit.sh: id-allocate not executable" >&2; exit 1; }

# (1) Shape.
shape_out=$(bash "$SHAPE_DETECT" --spec-path "${SPEC_PATH:-}" --input "${INPUT:-}")
input_shape=$(echo "$shape_out" | sed -n 's/^input_shape=//p')
shape_classification=$(echo "$shape_out" | sed -n 's/^shape_classification=//p')
[ -n "$input_shape" ] || { echo "proposal-emit.sh: shape-detect produced no input_shape" >&2; exit 1; }

# (1a) Empty + Q&A branch (M024/P05 — FR-5).
#
# Triggered when neither --input nor --spec-path is supplied AND
# --qa-answers-from is. The loop reads questions from the static
# template and answers from the line-mode file, captures a transcript,
# and propagates qa_short_circuited / low_confidence into the
# downstream rendering.
QA_LOOP="$ROOT/scripts/intake/qa-loop.sh"
qa_transcript=""
qa_short_circuited="false"
if [ -z "$INPUT" ] && [ -z "$SPEC_PATH" ] && [ -n "$QA_ANSWERS_FROM" ]; then
  [ -x "$QA_LOOP" ] || { echo "proposal-emit.sh: qa-loop.sh not executable" >&2; exit 1; }
  [ -f "$QA_ANSWERS_FROM" ] || { echo "proposal-emit.sh: qa answers file not found: $QA_ANSWERS_FROM" >&2; exit 1; }
  qa_tx_tmp=$(mktemp)
  qa_out=$(bash "$QA_LOOP" --answers-from "$QA_ANSWERS_FROM" --transcript-out "$qa_tx_tmp")
  qa_short_circuited=$(echo "$qa_out" | sed -n 's/^qa_short_circuited=//p' | head -1)
  [ -n "$qa_short_circuited" ] || qa_short_circuited="false"
  qa_transcript=$(cat "$qa_tx_tmp")
  rm -f "$qa_tx_tmp"

  # Override the shape-detect output: empty + qa-loop ran → empty_qa.
  input_shape="empty_qa"
  # Synthesize INPUT for downstream id-allocate + hash (deterministic from transcript).
  INPUT="$qa_transcript"
fi

# (2) Intake-id.
if [ -n "$SPEC_PATH" ]; then
  id_out=$(bash "$ID_ALLOCATE" --spec-path "$SPEC_PATH")
else
  id_for_alloc="${INPUT:-empty-input}"
  id_out=$(bash "$ID_ALLOCATE" --input "$id_for_alloc" --intake-dir "$INTAKE_ROOT")
fi
intake_id=$(echo "$id_out" | sed -n 's/^intake_id=//p')
[ -n "$intake_id" ] || { echo "proposal-emit.sh: id-allocate produced no intake_id" >&2; exit 1; }

# (3) Intensity (FR-9 reuse). Fall back to Standard on any error.
intensity="Standard"
if [ -x "$INTENSITY" ]; then
  raw=$(bash "$INTENSITY" --description "${INPUT:-${SPEC_PATH:-}}" 2>/dev/null || true)
  recommended=$(echo "$raw" | sed -n 's/^intensity=//p' | head -1)
  case "$recommended" in
    Quick|Standard|Full) intensity="$recommended" ;;
  esac
fi

# (3a) Paragraph deep classifier (P03 — replaces P01 stubs for paragraph shape).
PARA_CLASSIFY="$ROOT/scripts/intake/paragraph-classify.sh"
paragraph_rationale=""
paragraph_evidence=""
if [ "$input_shape" = "paragraph" ] && [ -x "$PARA_CLASSIFY" ]; then
  pc_out=$(bash "$PARA_CLASSIFY" --input "$INPUT" 2>/dev/null || true)
  pc_tier=$(echo "$pc_out" | sed -n 's/^scope_tier=//p')
  pc_decomp=$(echo "$pc_out" | sed -n 's/^decomposition=//p')
  pc_cmd=$(echo "$pc_out" | sed -n 's/^recommended_command=//p')
  pc_rat=$(echo "$pc_out" | sed -n 's/^rationale_paragraph=//p')
  case "$pc_tier" in A|B|C) scope_tier_override="$pc_tier" ;; esac
  case "$pc_decomp" in single-task|single-phase|milestone-with-phases|multi-milestone) decomposition_override="$pc_decomp" ;; esac
  case "$pc_cmd" in orchestrator:dispatch|orchestrator:specify) recommended_command_override="$pc_cmd" ;; esac
  if [ -n "$pc_rat" ]; then
    paragraph_rationale="$pc_rat"
    paragraph_evidence="word-count + structural-marker classification (see scripts/intake/paragraph-classify.sh)"
  fi
fi

# (3b) Spec deep classifier (P02 — replaces P01 stubs for spec shape).
SPEC_CLASSIFY="$ROOT/scripts/intake/spec-shape-classify.sh"
spec_rationale=""
spec_evidence=""
if [ "$input_shape" = "spec" ] && [ -n "$SPEC_PATH" ] && [ -x "$SPEC_CLASSIFY" ]; then
  sc_out=$(bash "$SPEC_CLASSIFY" --spec-path "$SPEC_PATH" 2>/dev/null || true)
  sc_tier=$(echo "$sc_out" | sed -n 's/^scope_tier=//p')
  sc_decomp=$(echo "$sc_out" | sed -n 's/^decomposition=//p')
  sc_cmd=$(echo "$sc_out" | sed -n 's/^recommended_command=//p')
  sc_rat=$(echo "$sc_out" | sed -n 's/^rationale_spec=//p')
  sc_metrics=$(echo "$sc_out" | sed -n 's/^metrics_source=//p')
  case "$sc_tier" in A|B|C) scope_tier_override="$sc_tier" ;; esac
  case "$sc_decomp" in single-task|single-phase|milestone-with-phases|multi-milestone) decomposition_override="$sc_decomp" ;; esac
  case "$sc_cmd" in orchestrator:roadmap) recommended_command_override="$sc_cmd" ;; esac
  if [ -n "$sc_rat" ]; then
    spec_rationale="$sc_rat"
    spec_evidence="metrics_source=$sc_metrics (see scripts/intake/spec-shape-classify.sh)"
  fi
fi

# (4) Input hash.
hash_input="${INPUT:-${SPEC_PATH:-}}"
input_hash=$(printf '%s' "$hash_input" | shasum -a 256 | cut -c1-12)

# (5) Stub axes (P01 — deep logic in P02–P07).
scope_tier="A"
decomposition="single-task"
design_gate="none"
conversus_gate="none"
recommended_command="orchestrator:dispatch"

# Apply paragraph-classifier overrides (P03).
[ -n "${scope_tier_override:-}" ]          && scope_tier="$scope_tier_override"
[ -n "${decomposition_override:-}" ]       && decomposition="$decomposition_override"
[ -n "${recommended_command_override:-}" ] && recommended_command="$recommended_command_override"

# (M024/P06/T02) Apply axes-from revise overrides LAST so operator revisions
# beat deep-classifier output. The revise_* namespace is populated by the
# --axes-from parser at the top of this script.
[ -n "${scope_tier_revise:-}" ]          && scope_tier="$scope_tier_revise"
[ -n "${decomposition_revise:-}" ]       && decomposition="$decomposition_revise"
[ -n "${recommended_command_revise:-}" ] && recommended_command="$recommended_command_revise"
[ -n "${design_gate_revise:-}" ]         && design_gate="$design_gate_revise"
[ -n "${conversus_gate_revise:-}" ]      && conversus_gate="$conversus_gate_revise"
[ -n "${intensity_revise:-}" ]           && intensity="$intensity_revise"

# (5b) M024/P07/T03 — Design-gate deep classifier wired in alongside paragraph/spec branches.
# Skip when design_gate was already overridden by --axes-from (revise flow) or by the spec
# branch — REVISE wins highest precedence; the classifier only fills the P01 stub.
DESIGN_CLF="$ROOT/scripts/intake/design-gate-classify.sh"
design_gate_confidence="high"
if [ -z "${design_gate_revise:-}" ] && [ -x "$DESIGN_CLF" ]; then
  if [ -n "$INPUT" ]; then
    dg_out=$(bash "$DESIGN_CLF" --input "$INPUT" 2>/dev/null || echo "")
  elif [ -n "$SPEC_PATH" ]; then
    dg_out=$(bash "$DESIGN_CLF" --spec-path "$SPEC_PATH" 2>/dev/null || echo "")
  else
    dg_out=""
  fi
  dg_value=$(echo "$dg_out" | sed -n 's/^design_gate=//p' | head -1)
  dg_conf=$(echo "$dg_out" | sed -n 's/^design_gate_confidence=//p' | head -1)
  if [ -n "$dg_value" ]; then
    design_gate="$dg_value"
    DESIGN_AXES_DONE=1
  fi
  [ -n "$dg_conf" ] && design_gate_confidence="$dg_conf"
fi

# (5c) M024/P07/T03 — recommended_command guard against orphan post-M023-design references.
# When design_gate=walkthrough AND M023 has NOT shipped, the slot stays at the tier-derived
# fallback rather than pointing at the post-M023 design command which does not yet exist.
if [ "$design_gate" = "walkthrough" ]; then
  DEG="$ROOT/scripts/intake/design-gate-degradation.sh"
  if [ -x "$DEG" ]; then
    m023_shipped="false"
    case "${M023_SHIPPED_PROBE_OVERRIDE:-}" in
      live) m023_shipped="true" ;;
      stub|"") ;;
    esac
    if [ "$m023_shipped" = "false" ] && [ -z "${M023_SHIPPED_PROBE_OVERRIDE:-}" ]; then
      if [ -f "$ROOT/commands/design.md" ] && grep -qE '^Pass\.[0-9]+' "$ROOT/commands/design.md"; then
        m023_shipped="true"
      fi
    fi
    if [ "$m023_shipped" = "false" ]; then
      case "$scope_tier" in
        A) recommended_command="orchestrator:dispatch" ;;
        B|C) recommended_command="orchestrator:specify" ;;
      esac
    fi
  fi
fi

# (6) Frontmatter dynamic values.
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# feature_slug: spec-path mode → basename of dir containing spec; otherwise
# strip the `<NNN>-` counter prefix from the intake-id slug
# (e.g. `001-add-a-cache` → `add-a-cache`).
if [ -n "$SPEC_PATH" ]; then
  feature_slug=$(basename "$(dirname "$SPEC_PATH")")
else
  intake_slug="${intake_id##*/}"
  feature_slug=$(echo "$intake_slug" | sed -E 's/^[0-9]+-//')
fi
[ -n "$feature_slug" ] || feature_slug="null"

# milestone: read from .orchestrator/milestone-summary.md if present (look
# for an active-milestone marker line); otherwise emit `null`.
milestone="null"
SUMMARY_FILE="$ROOT/.orchestrator/milestone-summary.md"
if [ -f "$SUMMARY_FILE" ]; then
  active_line=$(grep -E '^\*\*(Out-of-band )?[Aa]ctive milestone\*\*:' "$SUMMARY_FILE" | head -1)
  if [ -n "$active_line" ]; then
    parsed=$(echo "$active_line" | sed -nE 's/.*\*\*(M[0-9]+)[^*]*\*\*.*/\1/p' | head -1)
    if [ -n "$parsed" ]; then
      milestone="$parsed"
    fi
  fi
fi

status="pending"
supplemental_input="null"
auto_proceeded="false"
proceeded_at="null"
approved_at="null"
cancelled_at="null"
pending_approval="true"
design_skipped="false"
design_authored_manually="false"
pending_design_authored_manually="false"
# qa_short_circuited is set above by the (1a) empty-qa branch when applicable;
# otherwise default to "false" for all other input modes.
qa_short_circuited="${qa_short_circuited:-false}"
low_confidence="false"
[ "$shape_classification" = "low" ] && low_confidence="true"
# Q&A short-circuit forces low_confidence so the P04 fast-path guard fires.
[ "$qa_short_circuited" = "true" ] && low_confidence="true"

# (7) Body content — input echo + per-axis stub rationale (FR-13 honest fallback).
# Empty-qa branch: INPUT was synthesized from the transcript for slug/hash
# purposes, but the Original Input echo points readers at ## Q&A instead of
# duplicating the transcript here.
if [ "$input_shape" = "empty_qa" ]; then
  input_body="(no inline input — operator answered the bounded Q&A loop; see ## Q&A section below)"
else
  input_body="${INPUT:-(no inline input — see spec at $SPEC_PATH)}"
fi
stub_rationale="P01 stub — deep classifier ships in a later phase."
stub_evidence="no-evidence — operator-supplied"

# (8) Render: sed-substitute every {{placeholder}}.
out_dir="$INTAKE_ROOT/$intake_id"
mkdir -p "$out_dir"
out_path="$out_dir/proposal.md"

# Use a temporary file to assemble; pipe-free for harness AD-19 compliance.
tmp_render=$(mktemp)
cp "$TEMPLATE" "$tmp_render"

# Helper: in-place sed swap (BSD/GNU portable via sed -i.bak then rm).
swap() {
  local key="$1"; local val="$2"
  # Escape forward slashes and ampersands in val.
  local esc
  esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/{{${key}}}/${esc}/g" "$tmp_render"
  rm -f "${tmp_render}.bak"
}

swap feature_slug "$feature_slug"
swap intake_id "$intake_id"
swap milestone "$milestone"
swap status "$status"
swap created_at "$created_at"
swap input_shape "$input_shape"
swap input_hash "$input_hash"
swap shape_classification "$shape_classification"
swap supplemental_input "$supplemental_input"
swap scope_tier "$scope_tier"
swap decomposition "$decomposition"
swap design_gate "$design_gate"
swap conversus_gate "$conversus_gate"
swap intensity "$intensity"
swap recommended_command "$recommended_command"

# (8a) Fast-path check (M024/P04 — FR-3 four-condition gate).
#
# The check requires the five axis frontmatter lines to be already swapped
# in. The block sits between the `swap intensity` and the `swap auto_proceeded`
# calls so the verdict reflects real values, not template placeholders.
# (Note: low_confidence is also a condition; it is set above and swapped
# below — but check-fast-path reads it from the rendered proposal, so the
# swap order below must keep low_confidence ahead of the gate. We achieve
# this by reading low_confidence from the local var via the rendered file:
# the gate sees the swapped intensity/scope_tier/conversus_gate/design_gate;
# low_confidence still holds its `{{placeholder}}` literal at this point,
# so we must swap it first.)
swap low_confidence "$low_confidence"

GATE="$ROOT/scripts/intake/approval-gate.sh"
READ_CONFIG="$ROOT/scripts/state/read-config.sh"
DEFAULTS_FILE="$ROOT/templates/orchestrator-config-default.yml"
PROJECT_FILE="$ROOT/orchestrator-config.yml"
LOCAL_FILE="$ROOT/orchestrator-config.local.yml"

# Resolve config — treat null as the default (true) per FR-3.
ap_config="true"
if [ -x "$READ_CONFIG" ]; then
  ap_resolved=$(bash "$READ_CONFIG" auto_proceed --defaults "$DEFAULTS_FILE" --project "$PROJECT_FILE" --local "$LOCAL_FILE" 2>/dev/null || echo "null")
  case "$ap_resolved" in
    false) ap_config="false" ;;
    true|null|"") ap_config="true" ;;
    *) ap_config="true" ;;
  esac
fi

# Interim render: $tmp_render now has the five axis lines swapped in
# (scope_tier, conversus_gate, design_gate, intensity, low_confidence).
if [ "$ap_config" = "true" ] && [ -x "$GATE" ]; then
  fp_out=$(bash "$GATE" --proposal "$tmp_render" --mode check-fast-path 2>/dev/null || true)
  fp_eligible=$(echo "$fp_out" | sed -n 's/^fast_path_eligible=//p' | head -1)
  if [ "$fp_eligible" = "true" ]; then
    auto_proceeded="true"
    FAST_PATH_AXES_DONE=1
  fi
fi

swap auto_proceeded "$auto_proceeded"
swap proceeded_at "$proceeded_at"
swap approved_at "$approved_at"
swap cancelled_at "$cancelled_at"
swap pending_approval "$pending_approval"
swap design_skipped "$design_skipped"
swap design_authored_manually "$design_authored_manually"
swap pending_design_authored_manually "$pending_design_authored_manually"
swap qa_short_circuited "$qa_short_circuited"
# (low_confidence was swapped above the fast-path block at (8a))

# Body slots — input + per-axis rationale/evidence stubs.
# Multiline `input_body` swap: stage body in a tmp_render-adjacent file so
# newlines pass through portably (BSD awk rejects literal newlines in -v
# assignments). The .body-source file sits beside $tmp_render under the
# system tempdir mktemp picked.
printf '%s' "$input_body" > "${tmp_render}.body-src"
awk -v body_file="${tmp_render}.body-src" '
BEGIN {
  body = ""
  sep = ""
  while ((getline line < body_file) == 1) {
    body = body sep line
    sep = "\n"
  }
  close(body_file)
}
{ gsub(/\{\{input_body\}\}/, body); print }
' "$tmp_render" > "${tmp_render}.body"
mv "${tmp_render}.body" "$tmp_render"
rm -f "${tmp_render}.body-src"

# Paragraph branch overrides P01 stubs for tier / decomposition / recommended_command.
# (M024/P06/T03) When REVISE_AXES_DONE=1 and an axis is operator-revised, do NOT
# let the paragraph branch overwrite the slot — the REVISE branch below must place
# the placeholder string that revise.sh post-processes into a version-pointer.
if [ -n "${paragraph_rationale:-}" ]; then
  if ! { [ "${REVISE_AXES_DONE:-0}" = "1" ] && echo "${REVISE_AXES_KEYS:-}" | grep -qx "scope_tier"; }; then
    swap rationale_scope_tier "$paragraph_rationale"
    swap evidence_scope_tier  "$paragraph_evidence"
  fi
  if ! { [ "${REVISE_AXES_DONE:-0}" = "1" ] && echo "${REVISE_AXES_KEYS:-}" | grep -qx "decomposition"; }; then
    swap rationale_decomposition "$paragraph_rationale"
    swap evidence_decomposition  "$paragraph_evidence"
  fi
  # input_shape rationale stays at the P01 stub (shape itself was already deeply detected).
  PARA_AXES_DONE=1
fi

# Spec branch overrides P01 stubs for input_shape rationale slot (P02/T03).
# (scope_tier / decomposition rationales are wired by re-using paragraph_rationale-style
#  swap below; the input_shape slot is the spec-specific rationale.)
if [ -n "${spec_rationale:-}" ]; then
  swap rationale_input_shape "$spec_rationale"
  swap evidence_input_shape  "$spec_evidence"
  swap rationale_scope_tier "$spec_rationale"
  swap evidence_scope_tier  "$spec_evidence"
  swap rationale_decomposition "$spec_rationale"
  swap evidence_decomposition  "$spec_evidence"
  SPEC_AXES_DONE=1
fi

# M024/P05 — empty-qa branch overrides P01 stubs for input_shape and decomposition rationale slots.
if [ "$input_shape" = "empty_qa" ]; then
  swap rationale_input_shape "Operator-supplied via bounded Q&A loop (5 turns max, enough short-circuit). Transcript embedded under ## Q&A."
  swap evidence_input_shape  "scripts/intake/qa-loop.sh transcript at this proposal's ## Q&A section"
  swap rationale_scope_tier "Derived from Q2 (scope) answer in the embedded Q&A transcript."
  swap evidence_scope_tier  "Operator answer to Q2 in ## Q&A"
  swap rationale_decomposition "Derived from Q2 (scope) answer in the embedded Q&A transcript."
  swap evidence_decomposition  "Operator answer to Q2 in ## Q&A"
  QA_AXES_DONE=1
fi

for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  # (M024/P06/T03) REVISE_AXES_DONE wins highest precedence — operator-driven
  # axes-from override places a placeholder; revise.sh post-processes to a
  # version-pointer rationale ("see proposal-v<N>.md") after the emitter returns.
  # This must run BEFORE the PARA/SPEC/QA gates so revised axes are not pinned
  # to deep-classifier rationale text from the same-input re-emit.
  if [ "${REVISE_AXES_DONE:-0}" = "1" ]; then
    if echo "$REVISE_AXES_KEYS" | grep -qx "$axis"; then
      swap "rationale_${axis}" "Operator revision via revise.sh — see prior version for original rationale."
      swap "evidence_${axis}" "see proposal-v<N>.md (revise.sh post-processes this slot)"
      continue
    fi
  fi
  if [ "${PARA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  if [ "${SPEC_AXES_DONE:-0}" = "1" ] && [ "$axis" = "input_shape" -o "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  if [ "${QA_AXES_DONE:-0}" = "1" ] && [ "$axis" = "input_shape" -o "$axis" = "scope_tier" -o "$axis" = "decomposition" ]; then
    continue
  fi
  # M024/P07/T03 — design-gate deep-classifier rationale.
  if [ "$axis" = "design_gate" ] && [ "${DESIGN_AXES_DONE:-0}" = "1" ]; then
    swap "rationale_design_gate" "Operator input scanned for design-domain tokens (ui, render, design, layout, screen, view, panel, viewer, dashboard, interface, visual, theme); whole-word match. Confidence: $design_gate_confidence."
    swap "evidence_design_gate"  "scripts/intake/design-gate-classify.sh"
    continue
  fi
  swap "rationale_${axis}" "$stub_rationale"
  swap "evidence_${axis}" "$stub_evidence"
done

swap approval_status "Status: pending operator approval."

mv "$tmp_render" "$out_path"

# Append the Q&A transcript (M024/P05 — FR-5).
if [ -n "$qa_transcript" ]; then
  {
    echo ""
    echo "## Q&A"
    echo ""
    echo "$qa_transcript"
  } >> "$out_path"
fi

echo "proposal_path=$out_path"
exit 0
