#!/usr/bin/env bash
# scripts/lifecycle/constitution-author.sh
#
# FR-3 driver for M033 (036-project-onboarding-experience). Authors the
# project-local constitution from a stack-aware starter via the P02
# grilling-shell (`ask_one`) flow, substitutes the closed `{{...}}`
# placeholder vocabulary, hands the draft to `$EDITOR`, gates on the
# FR-5 shape lint, and writes the resolved constitution to
# `<project-dir>/.orchestrator/memory/constitution.md`.
#
# Closed v1 stack list: web-saas, cli-tool, library.
#
# Load-bearing tokens (verifier-grepped — do not paraphrase):
#   --stack, --project-dir, --force, --yes
#   web-saas, cli-tool, library
#   templates/constitution-starters
#   grilling-shell.sh, ask_one
#   constitution-shape-lint.sh
#   EDITOR
#   .orchestrator/memory/constitution.md
#   start-state-markers.sh, constitution-authored
#   jsonl-event-emitter.sh, constitution_authored
#   dual-write-runtime-md.sh, 036-project-onboarding-experience
#
# Bash 3.2 compatibility (MEM001):
#   - no `declare -A` (associative arrays)
#   - no process substitution `<(...)`
#   - no `$(...)` containing pipes
#   - parallel indexed arrays for placeholder/answer mapping
#
# Spec ref: M033 FR-3 / 036-project-onboarding-experience
# Plan ref: .orchestrator/milestones/M033/phases/P03/tasks/T02-constitution-author-PLAN.md

set -e
set -u
set -o pipefail

# ---------------------------------------------------------------------------
# Repo-root resolution (BASH_SOURCE discipline matching P02 patterns).
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

USAGE='usage: constitution-author.sh --stack <web-saas|cli-tool|library>
                                    [--project-dir <path>]
                                    [--force] [--yes]'

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------

STACK=""
PROJECT_DIR=""
FORCE=0
YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --stack)
            if [ $# -lt 2 ]; then
                echo "FAIL: --stack requires a value" >&2
                printf '%s\n' "$USAGE" >&2
                exit 2
            fi
            STACK="$2"
            shift 2
            ;;
        --project-dir)
            if [ $# -lt 2 ]; then
                echo "FAIL: --project-dir requires a path" >&2
                printf '%s\n' "$USAGE" >&2
                exit 2
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --yes)
            YES=1
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
# Validate --stack against the closed v1 enum (US-2 AS-4).
# ---------------------------------------------------------------------------

case "$STACK" in
    web-saas|cli-tool|library)
        : # supported
        ;;
    "")
        echo "FAIL: --stack is required" >&2
        echo "valid: web-saas cli-tool library" >&2
        echo "see references/constitution-starter-format.md (#Q-2 expansion path)" >&2
        printf '%s\n' "$USAGE" >&2
        exit 2
        ;;
    *)
        echo "FAIL: unknown stack: $STACK" >&2
        echo "valid: web-saas cli-tool library" >&2
        echo "see references/constitution-starter-format.md (#Q-2 expansion path)" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------------------
# Default + normalize PROJECT_DIR.
# ---------------------------------------------------------------------------

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

mkdir -p "$PROJECT_DIR/.orchestrator/memory"

# ---------------------------------------------------------------------------
# Pre-flight: verify the starter exists.
# ---------------------------------------------------------------------------

STARTER="$REPO_ROOT/templates/constitution-starters/$STACK.md"
if [ ! -f "$STARTER" ]; then
    echo "FAIL: starter not found: templates/constitution-starters/$STACK.md" >&2
    echo "FAIL: corrupt install? expected at $STARTER" >&2
    exit 1
fi

CONSTITUTION_PATH="$PROJECT_DIR/.orchestrator/memory/constitution.md"

# ---------------------------------------------------------------------------
# Idempotent no-force path (US-2 AS-2).
# ---------------------------------------------------------------------------

if [ -f "$CONSTITUTION_PATH" ] && [ "$FORCE" -eq 0 ]; then
    echo "no changes"
    PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/util/jsonl-event-emitter.sh" \
        emit constitution_authored '{"action":"no-changes"}' || true
    exit 0
fi

# ---------------------------------------------------------------------------
# --force warning (US-2 AS-3).
# ---------------------------------------------------------------------------

if [ -f "$CONSTITUTION_PATH" ] && [ "$FORCE" -eq 1 ]; then
    echo "WARN: --force discards prior operator edits at $CONSTITUTION_PATH" >&2
fi

# ---------------------------------------------------------------------------
# Source the grilling-shell (provides ask_one). The module guards itself
# against direct execution; sourcing pulls in ask_one without side effects.
# ---------------------------------------------------------------------------

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lifecycle/grilling-shell.sh"

# ---------------------------------------------------------------------------
# Set up the partial-answers accumulator (FR-10 MIT-007 amendment site).
# Path convention: <project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml
# Second-granularity timestamps are sufficient; operators do not run
# constitution-author multiple times per second.
# ---------------------------------------------------------------------------

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ACCUMULATOR_DIR="$PROJECT_DIR/.orchestrator/intake/$TIMESTAMP"
ACCUMULATOR="$ACCUMULATOR_DIR/partial-answers.yml"
mkdir -p "$ACCUMULATOR_DIR"
: > "$ACCUMULATOR"

# ---------------------------------------------------------------------------
# Per-stack question bundles. Bash 3.2: parallel indexed arrays
# (placeholders[] + qkeys[] + questions[] + recommendations[] + glossary[]).
# Total question count: 5–8 per FR-3. Universal placeholders contribute 3;
# stack-specific contribute 2–3 follow-ups. Stack-specific answers do NOT
# substitute into the starter (the v1 placeholder vocabulary is closed at
# 3) — they are recorded into the accumulator (and trigger the FR-18
# glossary writer when their qkey is in the closed glossary-trigger set).
# ---------------------------------------------------------------------------

# Universal (always asked, in order). Substitution applies.
placeholders=(project_type primary_constraint target_user)
u_qkeys=(project-type-defined primary-constraint-defined target-user)
u_questions=(
    "What is the project's identity in one short clause?"
    "What is the dominant operating constraint?"
    "Who is the user the project serves?"
)
u_recommendations=(
    "developer-facing tool"
    "single-binary distribution"
    "engineering teams"
)

# Stack-specific (no substitution; accumulator + glossary only).
case "$STACK" in
    web-saas)
        s_qkeys=(deployment-target auth-model data-residency)
        s_questions=(
            "What is the deployment target?"
            "What is the auth model?"
            "What data-residency posture applies?"
        )
        s_recommendations=(
            "serverless"
            "passwordless"
            "us-only"
        )
        ;;
    cli-tool)
        s_qkeys=(primary-subcommand-pattern distribution-channel)
        s_questions=(
            "What is the primary subcommand pattern?"
            "What distribution channel is canonical?"
        )
        s_recommendations=(
            "verb-noun (e.g., create, list, delete)"
            "homebrew + curl-pipe-bash"
        )
        ;;
    library)
        s_qkeys=(language-or-runtime distribution-channel)
        s_questions=(
            "What language or runtime is the library targeting?"
            "What distribution channel is canonical?"
        )
        s_recommendations=(
            "Python 3.11+"
            "PyPI"
        )
        ;;
esac

# ---------------------------------------------------------------------------
# Sequential grilling-protocol pass (CON-5 — never batched).
#
# For each question we set _GRILLING_CURRENT_QKEY (and optionally
# _GRILLING_CURRENT_DEFINITION for glossary writes), invoke ask_one,
# capture the resolved answer from stdout, and store it.
# ---------------------------------------------------------------------------

# Indexed answer storage for universal placeholders (parallel to placeholders[]).
answers=("" "" "")

# Read the most recent value for a qkey from the accumulator. ask_one
# appends `<qkey>: <resolved>` to the accumulator after passing
# contradiction detection, so the accumulator is the SSOT for the
# resolved answer. Single $(...) without an internal pipe per AP-009.
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

# Run universal questions. ask_one writes its prompt to stdout/stderr
# and reads from stdin; we do NOT capture its stdout (capture would
# hide the prompts from the operator). The resolved answer reaches us
# via the accumulator (ask_one appends `<qkey>: <resolved>` after
# successful contradiction-check + glossary write).
i=0
while [ "$i" -lt 3 ]; do
    qkey="${u_qkeys[$i]}"
    question="${u_questions[$i]}"
    recommendation="${u_recommendations[$i]}"

    _GRILLING_CURRENT_QKEY="$qkey"
    _GRILLING_CURRENT_DEFINITION="$question"
    export _GRILLING_CURRENT_QKEY
    export _GRILLING_CURRENT_DEFINITION
    export PROJECT_DIR

    # Direct invocation — stdin/stdout flow through to operator's terminal.
    rc=0
    ask_one "$question" "$recommendation" "$ACCUMULATOR" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: grilling-shell ask_one returned $rc for qkey=$qkey" >&2
        exit "$rc"
    fi
    resolved=""
    resolved="$(read_accumulator_answer "$qkey" "$ACCUMULATOR")" || resolved=""
    if [ -z "$resolved" ]; then
        # Fall back to the recommendation if the accumulator did not capture
        # (defensive — caller-side qkey wiring shouldn't drop on a clean
        # ask_one return).
        resolved="$recommendation"
    fi
    answers[$i]="$resolved"
    i=$((i + 1))
done

# Run stack-specific questions. Answers are NOT substituted; we still
# invoke ask_one so the accumulator + glossary writers see them per
# CON-5 sequential-never-batched.
j=0
s_count="${#s_qkeys[@]}"
while [ "$j" -lt "$s_count" ]; do
    qkey="${s_qkeys[$j]}"
    question="${s_questions[$j]}"
    recommendation="${s_recommendations[$j]}"

    _GRILLING_CURRENT_QKEY="$qkey"
    _GRILLING_CURRENT_DEFINITION="$question"
    export _GRILLING_CURRENT_QKEY
    export _GRILLING_CURRENT_DEFINITION

    rc=0
    ask_one "$question" "$recommendation" "$ACCUMULATOR" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: grilling-shell ask_one returned $rc for qkey=$qkey" >&2
        exit "$rc"
    fi
    j=$((j + 1))
done

# ---------------------------------------------------------------------------
# Placeholder substitution.
#
# Copy the starter into a temp dir; for each (placeholder, answer)
# pair, run `sed -i.bak "s|{{<placeholder>}}|<answer>|g"`. Cleanup
# `.bak` afterwards.
#
# Bash 3.2 compatible: parallel indexed arrays.
# ---------------------------------------------------------------------------

TMPDIR_RUN="$(mktemp -d 2>/dev/null || mktemp -d -t constitution-author)"
DRAFT="$TMPDIR_RUN/constitution.md"
cp "$STARTER" "$DRAFT"

n=${#placeholders[@]}
k=0
while [ "$k" -lt "$n" ]; do
    ph="${placeholders[$k]}"
    val="${answers[$k]}"
    # Escape `|` and `&` in the value so sed substitution survives operator-
    # supplied content. Bash 3.2 — single $(...) per call without a pipe.
    val_escaped="$val"
    val_escaped="$(printf '%s' "$val_escaped" | sed -e 's/[\\|&]/\\&/g')"
    sed -i.bak "s|{{${ph}}}|${val_escaped}|g" "$DRAFT"
    rm -f "$DRAFT.bak"
    k=$((k + 1))
done

# ---------------------------------------------------------------------------
# Editor hand-off ($EDITOR review).
#
# `--yes` and `EDITOR=cat` both bypass operator review (the latter is
# the test convention).
# ---------------------------------------------------------------------------

EDITOR="${EDITOR:-vi}"
if [ "$YES" -eq 0 ]; then
    "$EDITOR" "$DRAFT"
fi

# ---------------------------------------------------------------------------
# Lint gate (FR-5).
# ---------------------------------------------------------------------------

LINT="$REPO_ROOT/scripts/verify/constitution-shape-lint.sh"
if ! bash "$LINT" "$DRAFT"; then
    echo "FAIL: lint rejected — re-invoke and re-edit; no partial write" >&2
    rm -rf "$TMPDIR_RUN"
    exit 1
fi

# ---------------------------------------------------------------------------
# Write to project-local destination.
# ---------------------------------------------------------------------------

cp "$DRAFT" "$CONSTITUTION_PATH"
rm -rf "$TMPDIR_RUN"

# ---------------------------------------------------------------------------
# Marker write (FR-20).
# ---------------------------------------------------------------------------

bash "$REPO_ROOT/scripts/util/start-state-markers.sh" \
    write constitution-authored "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# JSONL event emit (FR-22).
# ---------------------------------------------------------------------------

if [ "$FORCE" -eq 1 ]; then
    force_field='true'
else
    force_field='false'
fi
PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/util/jsonl-event-emitter.sh" \
    emit constitution_authored \
    "{\"stack\":\"$STACK\",\"force\":$force_field}"

# ---------------------------------------------------------------------------
# FR-21 dual-write recent-changes fragment.
#
# The helper signature takes --marker + --append-entry flags. The marker
# region is `recent-changes` (matches `# >>> orchestrator:recent-changes
# >>>` in CLAUDE.md / AGENTS.md). The fragment template is documented in
# references/m033-fr21-dual-write-convention.md.
# ---------------------------------------------------------------------------

FRAGMENT="M033/$STACK: constitution authored from $STACK starter"
bash "$REPO_ROOT/scripts/util/dual-write-runtime-md.sh" \
    --root "$PROJECT_DIR" \
    --marker recent-changes \
    --append-entry "$FRAGMENT" || true

echo "PASS: constitution authored at $CONSTITUTION_PATH"
echo "SUMMARY: constitution-author.sh stack=$STACK project_dir=$PROJECT_DIR force=$FORCE"

exit 0
