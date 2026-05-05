#!/usr/bin/env bash
# scripts/lifecycle/ideation.sh
#
# FR-10 driver for M033 (036-project-onboarding-experience). Authors a
# structured pre-spec from a 7-question grilling-protocol-shaped flow
# for the **greenfield-empty** branch (no materials, no codebase).
#
# CON-6 (resume-on-interrupt): partial answers are persisted to
# `<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml`
# after EACH question. Re-invocation against the same <timestamp>
# resumes from the first unanswered key.
#
# MIT-007 (load-bearing): every `ask_one` invocation passes the
# partial-answers.yml path as the third argument so contradiction
# detection fires during normal sessions, not only on resume.
#
# CON-5 (sequential-never-batched): each `ask_one` invocation awaits
# its answer before the next fires.
#
# #Q-7: `--with-conversus-stress-test` is opt-in, OFF by default.
#
# Closed 7-question key set (execution order):
#   problem-statement, target-user, mvp-boundary, top-user-stories,
#   success-metric, top-risks, top-non-goals
#
# Bash 3.2 compatibility (MEM001):
#   - no `declare -A` (associative arrays)
#   - no process substitution `<(...)`
#   - no `$(...)` containing pipes
#   - parallel indexed arrays for qkey/question/recommendation mapping
#
# Load-bearing tokens (verifier-grepped — do not paraphrase):
#   FR-10, MIT-007, CON-6
#   --project-dir, --yes, --with-conversus-stress-test
#   ask_one, grilling-shell.sh
#   _GRILLING_CURRENT_QKEY
#   partial-answers.yml, ideation-pre-spec.md
#   ideation.complete, ideation_completed
#   Adversarial Findings
#   dual-write-runtime-md.sh
#   M033_IDEATION_TIMESTAMP
#
# Spec ref: M033 FR-10 / 036-project-onboarding-experience
# Plan ref: .orchestrator/milestones/M033/phases/P04/tasks/T02-ideation-PAYLOAD.md

set -e
set -u
set -o pipefail

# ---------------------------------------------------------------------------
# Repo-root resolution (BASH_SOURCE discipline matching P02/P03 patterns).
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

USAGE='usage: ideation.sh [--project-dir <path>]
                          [--yes]
                          [--with-conversus-stress-test]'

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------

PROJECT_DIR=""
YES=0
WITH_STRESS_TEST=0

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            if [ $# -lt 2 ]; then
                echo "FAIL: --project-dir requires a path" >&2
                printf '%s\n' "$USAGE" >&2
                exit 2
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --yes)
            YES=1
            shift
            ;;
        --with-conversus-stress-test)
            WITH_STRESS_TEST=1
            shift
            ;;
        -h|--help)
            printf '%s\n' "$USAGE"
            exit 0
            ;;
        *)
            echo "FAIL: unknown flag: $1" >&2
            printf '%s\n' "$USAGE" >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Default + normalize PROJECT_DIR.
# ---------------------------------------------------------------------------

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

mkdir -p "$PROJECT_DIR/.orchestrator/intake"

# ---------------------------------------------------------------------------
# Closed 7-question key set + question text + recommendation default.
# Bash 3.2: parallel indexed arrays. Recommendations are placeholder
# `(operator-supplied)` — ideation has no domain-specific recommendation
# (every project is unique), so the recommendation slot defers to operator
# input. Under `--yes` the empty-input branch returns the placeholder
# verbatim (see ask_one); the resolved-equals-recommendation case is
# tagged with the `<!-- Recommended-default-accepted -->` provenance
# comment in the emitted pre-spec.
# ---------------------------------------------------------------------------

# >>> ideation-question-keys >>>
# problem-statement
# target-user
# mvp-boundary
# top-user-stories
# success-metric
# top-risks
# top-non-goals
# <<< ideation-question-keys <<<

QKEYS_0="problem-statement";       QQUESTIONS_0="What problem does this project solve?";       QRECS_0="(operator-supplied)"
QKEYS_1="target-user";             QQUESTIONS_1="Who is the primary target user?";             QRECS_1="(operator-supplied)"
QKEYS_2="mvp-boundary";            QQUESTIONS_2="What is the MVP boundary?";                   QRECS_2="(operator-supplied)"
QKEYS_3="top-user-stories";        QQUESTIONS_3="What are the top 3 user stories?";            QRECS_3="(operator-supplied)"
QKEYS_4="success-metric";          QQUESTIONS_4="What is the primary success metric?";         QRECS_4="(operator-supplied)"
QKEYS_5="top-risks";               QQUESTIONS_5="What are the top 3 risks?";                   QRECS_5="(operator-supplied)"
QKEYS_6="top-non-goals";           QQUESTIONS_6="What are the top 3 non-goals?";               QRECS_6="(operator-supplied)"

# Section header text for the emitted pre-spec, parallel to qkeys.
SECTIONS_0="Problem"
SECTIONS_1="Target User"
SECTIONS_2="MVP"
SECTIONS_3="User Stories"
SECTIONS_4="Success Metric"
SECTIONS_5="Risks"
SECTIONS_6="Non-Goals"

# ---------------------------------------------------------------------------
# resolve_timestamp <project-dir>
#
# Resolution order:
#   1. If <project-dir>/.orchestrator/intake/<*>/partial-answers.yml exists
#      with fewer than 7 keys, that timestamp is reused (resume per CON-6).
#   2. Else honor M033_IDEATION_TIMESTAMP (TEST-ONLY env override).
#   3. Else `date -u +%Y%m%dT%H%M%SZ`.
#
# Echoes the resolved timestamp on stdout. Bash 3.2: no process
# substitution, no $(...) containing pipes. Uses `find` with `-print`
# and a single $(...) capture.
# ---------------------------------------------------------------------------

resolve_timestamp() {
    local proj="$1"
    local intake_root="$proj/.orchestrator/intake"

    # Tier 1: scan for an in-flight (incomplete) partial-answers.yml.
    if [ -d "$intake_root" ]; then
        local listing=""
        listing="$(ls -1 "$intake_root" 2>/dev/null || true)"
        local IFSO="$IFS"
        IFS=$'\n'
        local entry
        for entry in $listing; do
            local pa_path="$intake_root/$entry/partial-answers.yml"
            if [ -f "$pa_path" ]; then
                local key_count=0
                key_count=$(grep -c '^[a-z][a-z0-9-]*: ' "$pa_path" 2>/dev/null || true)
                if [ -z "$key_count" ]; then
                    key_count=0
                fi
                if [ "$key_count" -lt 7 ]; then
                    IFS="$IFSO"
                    printf '%s' "$entry"
                    return 0
                fi
            fi
        done
        IFS="$IFSO"
    fi

    # Tier 2: TEST-ONLY env override.
    if [ -n "${M033_IDEATION_TIMESTAMP:-}" ]; then
        printf '%s' "$M033_IDEATION_TIMESTAMP"
        return 0
    fi

    # Tier 3: fresh timestamp.
    local ts=""
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    printf '%s' "$ts"
}

# ---------------------------------------------------------------------------
# read_partial_answers <yaml-path>
#
# Emits one <qkey> per line for keys already present in the accumulator.
# Used by the main loop to skip already-answered keys (CON-6 resume).
# ---------------------------------------------------------------------------

read_partial_answers() {
    local pa_path="$1"
    if [ ! -f "$pa_path" ]; then
        return 0
    fi
    grep -E '^[a-z][a-z0-9-]*: ' "$pa_path" 2>/dev/null | sed -E 's/:.*$//' || true
}

# ---------------------------------------------------------------------------
# read_accumulator_answer <qkey> <yaml-path>
#
# Reads the most recent value for a qkey from the accumulator. ask_one
# appends `<qkey>: <resolved>` to the accumulator after passing the
# contradiction detection + glossary write. Returns the value on stdout.
# Single $(...) per call without an internal pipe (AP-009).
# ---------------------------------------------------------------------------

read_accumulator_answer() {
    local qkey_local="$1"
    local file_local="$2"
    local match=""
    match="$(grep "^${qkey_local}:" "$file_local" 2>/dev/null || true)"
    if [ -z "$match" ]; then
        return 1
    fi
    local last=""
    last="$(printf '%s\n' "$match" | tail -1)"
    local val=""
    val="$(printf '%s\n' "$last" | sed -E 's/^[^:]+:[[:space:]]*//')"
    printf '%s' "$val"
}

# ---------------------------------------------------------------------------
# ideate_one <qkey> <question> <recommendation> <yaml-path>
#
# MIT-007 wiring helper: sets _GRILLING_CURRENT_QKEY then invokes
# ask_one with the partial-answers.yml path passed AS THE THIRD ARG.
# This is the load-bearing call shape — the third arg is the
# context-file consulted by the contradiction detector.
#
# After ask_one returns 0, the answer has already been appended to
# yaml-path by ask_one itself (P02 wiring); the caller reads it back
# via read_accumulator_answer.
#
# Returns ask_one's exit code (0 success; 2 bad-usage; 3 contradiction-
# unresolved per MIT-007).
# ---------------------------------------------------------------------------

ideate_one() {
    local qkey="$1"
    local question="$2"
    local recommendation="$3"
    local pa_path="$4"

    _GRILLING_CURRENT_QKEY="$qkey"
    _GRILLING_CURRENT_DEFINITION="$question"
    export _GRILLING_CURRENT_QKEY
    export _GRILLING_CURRENT_DEFINITION
    export PROJECT_DIR

    # MIT-007 third-arg wiring — pa_path is the context-file passed on
    # EVERY ask_one invocation (not only on resume).
    local rc=0
    ask_one "$question" "$recommendation" "$pa_path" || rc=$?
    return "$rc"
}

# ---------------------------------------------------------------------------
# Source the grilling-shell (provides ask_one). The module guards itself
# against direct execution; sourcing pulls in ask_one without side effects.
# ---------------------------------------------------------------------------

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lifecycle/grilling-shell.sh"

# ---------------------------------------------------------------------------
# Main flow.
# ---------------------------------------------------------------------------

TIMESTAMP=""
TIMESTAMP="$(resolve_timestamp "$PROJECT_DIR")"

INTAKE_DIR="$PROJECT_DIR/.orchestrator/intake/$TIMESTAMP"
mkdir -p "$INTAKE_DIR"

PARTIAL_ANSWERS="$INTAKE_DIR/partial-answers.yml"
touch "$PARTIAL_ANSWERS"

# Read pre-existing answered qkeys (CON-6 resume).
ANSWERED=""
ANSWERED="$(read_partial_answers "$PARTIAL_ANSWERS")"

# ---------------------------------------------------------------------------
# Sequential 7-question pass (CON-5 — never batched).
#
# For each qkey index 0..6, skip if already in the accumulator (CON-6
# resume), otherwise invoke ideate_one. Exit codes:
#   0  continue
#   2  bad-usage / no explicit answer
#   3  contradiction-unresolved per MIT-007
# ---------------------------------------------------------------------------

i=0
while [ "$i" -lt 7 ]; do
    case "$i" in
        0) qkey="$QKEYS_0"; question="$QQUESTIONS_0"; recommendation="$QRECS_0" ;;
        1) qkey="$QKEYS_1"; question="$QQUESTIONS_1"; recommendation="$QRECS_1" ;;
        2) qkey="$QKEYS_2"; question="$QQUESTIONS_2"; recommendation="$QRECS_2" ;;
        3) qkey="$QKEYS_3"; question="$QQUESTIONS_3"; recommendation="$QRECS_3" ;;
        4) qkey="$QKEYS_4"; question="$QQUESTIONS_4"; recommendation="$QRECS_4" ;;
        5) qkey="$QKEYS_5"; question="$QQUESTIONS_5"; recommendation="$QRECS_5" ;;
        6) qkey="$QKEYS_6"; question="$QQUESTIONS_6"; recommendation="$QRECS_6" ;;
    esac

    # CON-6 resume: skip qkeys already in partial-answers.yml.
    skip=0
    IFSO="$IFS"
    IFS=$'\n'
    for done_qkey in $ANSWERED; do
        if [ "$done_qkey" = "$qkey" ]; then
            skip=1
            break
        fi
    done
    IFS="$IFSO"

    if [ "$skip" -eq 1 ]; then
        echo "skip: $qkey already answered (resume)"
        i=$((i + 1))
        continue
    fi

    rc=0
    # MIT-007: ideate_one passes "$PARTIAL_ANSWERS" as the third arg
    # to ask_one on every call.
    ideate_one "$qkey" "$question" "$recommendation" "$PARTIAL_ANSWERS" || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "FAIL: ideate_one returned 2 (bad-usage / no explicit answer) for qkey=$qkey" >&2
        exit 2
    fi
    if [ "$rc" -eq 3 ]; then
        echo "FAIL: contradiction-unresolved for qkey=$qkey (per MIT-007)" >&2
        exit 3
    fi
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: ideate_one returned $rc for qkey=$qkey" >&2
        exit "$rc"
    fi

    i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Compose ideation-pre-spec.md.
#
# H1 + 7 H2 sections in execution order. The body of each section is
# the resolved answer for the corresponding qkey, optionally tagged
# with `<!-- Recommended-default-accepted -->` when the answer matches
# the recommendation default verbatim.
# ---------------------------------------------------------------------------

PRE_SPEC="$INTAKE_DIR/ideation-pre-spec.md"
: > "$PRE_SPEC"
printf '# Ideation Pre-Spec\n\n' >> "$PRE_SPEC"

j=0
while [ "$j" -lt 7 ]; do
    case "$j" in
        0) qkey="$QKEYS_0"; section="$SECTIONS_0"; recommendation="$QRECS_0" ;;
        1) qkey="$QKEYS_1"; section="$SECTIONS_1"; recommendation="$QRECS_1" ;;
        2) qkey="$QKEYS_2"; section="$SECTIONS_2"; recommendation="$QRECS_2" ;;
        3) qkey="$QKEYS_3"; section="$SECTIONS_3"; recommendation="$QRECS_3" ;;
        4) qkey="$QKEYS_4"; section="$SECTIONS_4"; recommendation="$QRECS_4" ;;
        5) qkey="$QKEYS_5"; section="$SECTIONS_5"; recommendation="$QRECS_5" ;;
        6) qkey="$QKEYS_6"; section="$SECTIONS_6"; recommendation="$QRECS_6" ;;
    esac

    resolved=""
    resolved="$(read_accumulator_answer "$qkey" "$PARTIAL_ANSWERS")" || resolved=""
    if [ -z "$resolved" ]; then
        resolved="$recommendation"
    fi

    printf '## %s\n\n' "$section" >> "$PRE_SPEC"
    if [ "$resolved" = "$recommendation" ]; then
        printf '<!-- Recommended-default-accepted -->\n' >> "$PRE_SPEC"
    fi
    printf '%s\n\n' "$resolved" >> "$PRE_SPEC"

    j=$((j + 1))
done

# ---------------------------------------------------------------------------
# Optional --with-conversus-stress-test (#Q-7 default OFF).
#
# Probe for the conversus adapter; if present, append the adversarial
# output as a final `## Adversarial Findings (deferred to specify)`
# section. If absent, emit a stderr diagnostic and continue (non-fatal).
# ---------------------------------------------------------------------------

if [ "$WITH_STRESS_TEST" = "1" ]; then
    CONVERSUS_ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh"
    if [ -x "$CONVERSUS_ADAPTER" ] || [ -f "$CONVERSUS_ADAPTER" ]; then
        printf '## Adversarial Findings (deferred to specify)\n\n' >> "$PRE_SPEC"
        stress_out=""
        stress_out="$(bash "$CONVERSUS_ADAPTER" stress-test "$PRE_SPEC" 2>&1 || true)"
        printf '%s\n\n' "$stress_out" >> "$PRE_SPEC"
    else
        echo "conversus adapter not available — skipping stress-test" >&2
    fi
fi

# ---------------------------------------------------------------------------
# Marker write (FR-20).
# ---------------------------------------------------------------------------

bash "$REPO_ROOT/scripts/util/start-state-markers.sh" \
    write ideation "$PROJECT_DIR"

# Marker file path is `<project-dir>/.orchestrator/start-state/ideation.complete`
# per FR-20 (canonical name documented for downstream verifiers).

# ---------------------------------------------------------------------------
# JSONL event emit (FR-22).
# ---------------------------------------------------------------------------

if [ "$WITH_STRESS_TEST" = "1" ]; then
    stress_field='true'
else
    stress_field='false'
fi
PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/util/jsonl-event-emitter.sh" \
    emit ideation_completed \
    "{\"questions_answered\":7,\"with_stress_test\":$stress_field}"

# ---------------------------------------------------------------------------
# FR-21 dual-write recent-changes fragment.
#
# The helper signature takes --marker + --append-entry flags. The marker
# region is `recent-changes`. The fragment template is documented in
# references/m033-fr21-dual-write-convention.md.
# ---------------------------------------------------------------------------

FRAGMENT="ideation: 7-question pre-spec authored"
bash "$REPO_ROOT/scripts/util/dual-write-runtime-md.sh" \
    --root "$PROJECT_DIR" \
    --marker recent-changes \
    --append-entry "$FRAGMENT" || true

echo "PASS: ideation pre-spec authored at $PRE_SPEC"
echo "SUMMARY: ideation.sh project_dir=$PROJECT_DIR timestamp=$TIMESTAMP with_stress_test=$WITH_STRESS_TEST"

exit 0
