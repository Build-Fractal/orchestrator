#!/usr/bin/env bash
# scripts/lifecycle/start.sh
#
# orchestrator:start driver — warm conversational front door for any
# new orchestrator-managed project (M033 / 036-project-onboarding-experience).
#
# Implements:
#   - FR-1: flag set (--project-dir, --yes, --branch, --stack, --dry-run).
#   - FR-2: deterministic ordered branch-detection rules.
#   - Idempotent invocation of scripts/lifecycle/init-project.sh.
#   - Inline disambiguation question (US-1 AS-5 + MIT-006 / RISK-006).
#   - Four vacuous sub-flow stubs (P01); P02–P05 replace these with real
#     sub-flow logic.
#   - FR-20 / CON-6 resume-on-partial-state read of marker files via
#     scripts/util/start-state-markers.sh, with --no-resume escape valve
#     (P02 additive extension; preserves all P01 behavior).
#
# SSOT cross-reference for branch-detection patterns:
#   references/branch-detection.md
# The pattern strings below byte-match the SSOT. The parity verifier
# tools/verify/m033-p01-branch-detection-ssot-parity.sh enforces the
# match via grep -F.
#
# Bash 3.2 compatible (MEM001): no associative arrays, no process
# substitution, no $(...) containing pipes. Structured output: PASS,
# FAIL, SUMMARY-prefixed lines to stdout; warnings to stderr.
#
# Usage:
#   bash scripts/lifecycle/start.sh [--project-dir PATH] [--yes] \
#       [--branch NAME] [--stack NAME] [--dry-run] [--no-resume]
#
# Branch enum (closed):
#   greenfield-empty | greenfield-with-materials | existing-codebase | migrating
#
# SSOT pattern reference (kept verbatim for grep -F parity):
#   prior_tooling_globs: .gsd/ .gsd2/ .specify/
#   pbj_md_glob: *BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md
#   source_extensions: .js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h
#   source_root_min_count: 10
#   git_min_commits: 1

set -e
set -u
set -o pipefail

# ---------------------------------------------------------------------------
# Defaults / globals
# ---------------------------------------------------------------------------

PROJECT_DIR="$PWD"
YES=0
BRANCH_OVERRIDE=""
STACK=""
DRY_RUN=0
NO_RESUME=0

# FR-15 / spec 035 FR-11 paired-launch flags (M033/P05/T02 additive).
# All default 0 (off) to preserve P01/P02/P04 behavior verbatim when
# the flags are not passed.
WITH_WIKI=0
WITH_GISCUS=0
DEPLOY=0

# FR-16 paired-launch flag (M033/P05/T03 additive). Default 0 (off) to
# preserve P01/P02/P04/T02 behavior verbatim when the flag is not passed.
WITH_GITHUB=0

# M029 / FR-10 / #Q-3 -- --auto-chain flag (default 0). When 1, the
# chain-driver walks evaluate -> discuss -> roadmap -> plan-phase one
# stage at a time, writing .orchestrator/start-state/<stage>.complete
# after each success. Failed stages leave the marker absent (#Q-3).
AUTO_CHAIN=0

DETECTED_FROM=""
MIT006_ELIGIBLE=0
INIT_INVOKED=0

# Side-channel tempfile: detect_branch runs in a $(...) subshell so it
# cannot directly mutate DETECTED_FROM / MIT006_ELIGIBLE in the parent.
# Instead it writes those values to this file, and load_detect_state
# in the parent re-reads them. Cleaned up on EXIT.
DETECT_STATE_FILE="${TMPDIR:-/tmp}/m033-start-detect-state-$$.kv"
trap 'rm -f "$DETECT_STATE_FILE"' EXIT

write_detect_state() {
    {
        printf 'DETECTED_FROM=%s\n' "$DETECTED_FROM"
        printf 'MIT006_ELIGIBLE=%s\n' "$MIT006_ELIGIBLE"
    } > "$DETECT_STATE_FILE"
}

load_detect_state() {
    if [ -f "$DETECT_STATE_FILE" ]; then
        local line key value
        while IFS= read -r line; do
            key="${line%%=*}"
            value="${line#*=}"
            case "$key" in
                DETECTED_FROM) DETECTED_FROM="$value" ;;
                MIT006_ELIGIBLE) MIT006_ELIGIBLE="$value" ;;
            esac
        done < "$DETECT_STATE_FILE"
    fi
}

USAGE='usage: start.sh [--project-dir PATH] [--yes] [--branch NAME] [--stack NAME] [--dry-run] [--no-resume] [--with-wiki] [--with-giscus] [--deploy] [--with-github] [--auto-chain] [--help|-h]'
BRANCH_ENUM='greenfield-empty | greenfield-with-materials | existing-codebase | migrating'

# ---------------------------------------------------------------------------
# Patch B (M033 friendly-tester UX): --help / -h support.
#
# Prints a one-paragraph header, the USAGE line, and a per-flag legend.
# Exits 0. Wired into the flag-parsing loop below as `--help|-h)` BEFORE
# the catch-all `*)` branch (which currently rejects unknown flags with
# exit 2). Pre-patch behavior was `unknown flag: --help` -> exit 2.
# ---------------------------------------------------------------------------

print_help() {
    cat <<'HELP'
start.sh -- orchestrator project onboarding entry point. Detects which of
four onboarding branches your project needs (empty / with-materials /
existing-codebase / migrating) and dispatches the appropriate sub-flow.
After detection, runs scripts/lifecycle/init-project.sh (idempotent) and
the matching sub-flow stub. SSOT for branch-detection patterns lives at
references/branch-detection.md.

usage: start.sh [--project-dir PATH] [--yes] [--branch NAME] [--stack NAME]
                [--dry-run] [--no-resume] [--with-wiki] [--with-giscus]
                [--deploy] [--with-github] [--auto-chain] [--help|-h]

flags:
  --project-dir PATH   target project directory (default: $PWD).
  --yes                non-interactive: accept disambiguation defaults and
                       skip the existing-codebase pre-flight prompt.
  --branch NAME        force a specific onboarding branch, bypassing
                       detection. NAME in: greenfield-empty,
                       greenfield-with-materials, existing-codebase,
                       migrating.
  --stack NAME         hint for stack-aware constitution starter (P03).
  --dry-run            preview-only: emits would-execute stubs and (for
                       existing-codebase) the pre-flight warning, then
                       exits without invoking init-project.sh.
  --no-resume          ignore start-state markers and force the full
                       baseline path (escape valve for FR-20 / CON-6).
  --with-wiki          after onboarding, invoke wiki-init.sh (FR-15).
  --with-giscus        passed through to wiki-init.sh.
  --deploy             passed through to wiki-init.sh.
  --with-github        after onboarding (and after --with-wiki when
                       paired), invoke github-init.sh (FR-16).
  --auto-chain         after onboarding, walk evaluate -> discuss ->
                       roadmap -> plan-phase one stage at a time
                       (M029 / FR-10).
  --help, -h           print this help and exit 0.
HELP
    return 0
}

# ---------------------------------------------------------------------------
# Sub-flow stubs (P01 — deliberately vacuous; P02–P05 replace these)
# ---------------------------------------------------------------------------

ideation_stub() {
    printf 'would-execute: ideation-stub --project-dir %s\n' "$PROJECT_DIR"
    return 0
}

materials_intake_stub() {
    printf 'would-execute: materials-intake-stub --project-dir %s\n' "$PROJECT_DIR"
    return 0
}

ingest_codebase_stub() {
    printf 'would-execute: ingest-codebase-stub --project-dir %s\n' "$PROJECT_DIR"
    return 0
}

migrate_routing_stub() {
    # P01 stub kept as deprecated alias forwarding to the real
    # migrate_routing implementation (M033/P04/T04). Preserved so any
    # legacy callers (phase-suite verifiers, downstream stub-rewiring
    # paths) continue to function. The load-bearing
    # 'would-execute: migrate-routing-stub' token is preserved here
    # alongside the new 'migrate-routed: from=' token emitted by
    # migrate_routing — this allows the SC-1 P01 acceptance test to
    # remain green during the additive-extension transition (AD-15
    # cross-phase regression discipline).
    if [ -n "$DETECTED_FROM" ]; then
        printf 'would-execute: migrate-routing-stub --project-dir %s --from %s\n' "$PROJECT_DIR" "$DETECTED_FROM"
    else
        printf 'would-execute: migrate-routing-stub --project-dir %s\n' "$PROJECT_DIR"
    fi
    migrate_routing
    return 0
}

# ---------------------------------------------------------------------------
# FR-11 spec-shape -> impl-shape translation.
# The operator-facing flag is `--from gsd-v1|gsd-v2|spec-kit` per spec.
# The underlying scripts/migrate/migrate.sh accepts `--source gsd1|gsd2|speckit`.
# The translation layer is the orchestrator-spec layer; migrate.sh internals
# are M015-closed and not modified.
# ---------------------------------------------------------------------------
translate_from_to_source() {
    case "$1" in
        gsd-v1)   echo "gsd1" ;;
        gsd-v2)   echo "gsd2" ;;
        spec-kit) echo "speckit" ;;
        *)        echo "" ;;
    esac
}

# ---------------------------------------------------------------------------
# FR-11 / FR-12 migrate-routing real implementation (M033/P04/T04).
# Replaces P01's vacuous migrate_routing_stub.
#
# Behavior:
#   - When DETECTED_FROM is one of (gsd-v1, gsd-v2, spec-kit), print the
#     proposed orchestrator:migrate command line and (under YES=1 or
#     operator one-keystroke 'Y') invoke scripts/migrate/migrate.sh with
#     the translated --source flag.
#   - When DETECTED_FROM is empty (migrating branch fired but no SSOT
#     pattern matched -- e.g., .aider/), emit the US-6 AS-5 diagnostic
#     `no orchestrator:migrate adapter for this tooling -- please file a
#     request` to stderr and exit 0 (no silent fall-through to
#     greenfield-empty).
#   - After successful migration, when <project-dir>/src/ exists,
#     invoke scripts/lifecycle/ingest-codebase.sh once (FR-12). T03 ships
#     the dup-prevention sentinel handling that makes this safe.
#   - Emit migrate_routed JSONL event + write migrate-routed start-state
#     marker.
#   - Under --dry-run, skip the actual migrate.sh and ingest-codebase.sh
#     invocations but still emit the load-bearing tokens so cross-phase
#     acceptance (SC-1 fixture-4) can verify the dispatch routing without
#     actually running migration against a stub fixture.
# ---------------------------------------------------------------------------
migrate_routing() {
    # Unsupported tooling: DETECTED_FROM empty despite migrating branch.
    # Patch D (2026-05-09): preserve the legacy 'no orchestrator:migrate
    # adapter for this tooling -- please file a request' diagnostic on
    # stderr (load-bearing token grep'd by m033-p04-migrate-routing-
    # shape.sh + p05-migrate-routing.sh test 5). Append the actionable
    # footer on stdout via emit_migrate_dead_end_footer.
    if [ -z "${DETECTED_FROM:-}" ]; then
        printf 'no orchestrator:migrate adapter for this tooling -- please file a request\n' 1>&2
        emit_migrate_dead_end_footer "$PROJECT_DIR"
        return 0
    fi

    local from_kind="$DETECTED_FROM"
    local source_kind
    source_kind=$(translate_from_to_source "$from_kind")
    if [ -z "$source_kind" ]; then
        printf 'no orchestrator:migrate adapter for this tooling -- please file a request\n' 1>&2
        emit_migrate_dead_end_footer "$PROJECT_DIR"
        return 0
    fi

    # Print the proposed operator-facing command line + load-bearing tokens.
    # 'migrate-routed: from=<kind>' is the post-T04 token; the legacy
    # 'would-execute: migrate-routing-stub' token is emitted by the
    # deprecated alias migrate_routing_stub for AD-15 backward compat.
    printf 'migrate-routed: from=%s\n' "$from_kind"
    printf 'proposed: orchestrator:migrate --from %s --project-dir %s\n' \
        "$from_kind" "$PROJECT_DIR"

    # Under --dry-run, skip the actual migrate.sh invocation. The token
    # emission above is sufficient for SC-1's dispatch-routing assertion.
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf 'dry-run: skipping migrate.sh and ingest-codebase.sh invocations\n'
        return 0
    fi

    # One-keystroke accept under YES=1; otherwise read a single line.
    local accept=""
    if [ "${YES:-0}" = "1" ]; then
        accept="Y"
    else
        printf 'accept [Y/n]: '
        IFS= read -r accept || accept=""
    fi
    case "$accept" in
        ""|Y|y) ;;
        *)
            printf 'skipped -- re-invoke with --yes or accept the prompt\n'
            return 0
            ;;
    esac

    # Invoke migrate.sh with the translated --source.
    bash scripts/migrate/migrate.sh --path "$PROJECT_DIR" --source "$source_kind"

    # FR-12 migrate-then-ingest: when src/ exists, invoke ingest-codebase.
    # T03's dup-prevention sentinel handling makes the post-migrate
    # ingest invocation safe (skip-duplicate-from-migrate: diagnostic
    # fires for migrate-derived MEMs).
    if [ -d "$PROJECT_DIR/src" ]; then
        bash scripts/lifecycle/ingest-codebase.sh --project-dir "$PROJECT_DIR"
    fi

    # Emit migrate_routed JSONL event + write start-state marker.
    PROJECT_DIR="$PROJECT_DIR" bash scripts/util/jsonl-event-emitter.sh emit migrate_routed "{\"from\":\"$from_kind\"}"
    bash scripts/util/start-state-markers.sh write migrate-routed "$PROJECT_DIR"

    return 0
}

# ---------------------------------------------------------------------------
# Branch validation
# ---------------------------------------------------------------------------

is_valid_branch() {
    case "$1" in
        greenfield-empty|greenfield-with-materials|existing-codebase|migrating)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            shift
            if [ $# -eq 0 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            PROJECT_DIR="$1"
            shift
            ;;
        --yes)
            YES=1
            shift
            ;;
        --branch)
            shift
            if [ $# -eq 0 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            BRANCH_OVERRIDE="$1"
            if ! is_valid_branch "$BRANCH_OVERRIDE"; then
                printf 'unknown --branch value: %s\n' "$BRANCH_OVERRIDE" 1>&2
                printf 'valid branches: %s\n' "$BRANCH_ENUM" 1>&2
                exit 2
            fi
            shift
            ;;
        --stack)
            shift
            if [ $# -eq 0 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            STACK="$1"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-resume)
            NO_RESUME=1
            shift
            ;;
        --with-wiki)
            WITH_WIKI=1
            shift
            ;;
        --with-giscus)
            WITH_GISCUS=1
            shift
            ;;
        --deploy)
            DEPLOY=1
            shift
            ;;
        --with-github)
            WITH_GITHUB=1
            shift
            ;;
        --auto-chain)
            AUTO_CHAIN=1
            shift
            ;;
        --help|-h)
            # Patch B: --help / -h prints the long-form help and exits 0.
            print_help
            exit 0
            ;;
        *)
            printf 'unknown flag: %s\n' "$1" 1>&2
            printf '%s\n' "$USAGE" 1>&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Init invocation (idempotent)
# ---------------------------------------------------------------------------

invoke_init() {
    local proj="$1"
    if [ -f "$proj/.orchestrator/config.yml" ]; then
        printf 'init already complete, proceeding to branch sub-flow\n'
        INIT_INVOKED=0
        return 0
    fi
    bash scripts/lifecycle/init-project.sh --project-dir "$proj"
    INIT_INVOKED=1
    return 0
}

# ---------------------------------------------------------------------------
# Branch detection (FR-2 deterministic ordered rules)
# ---------------------------------------------------------------------------
#
# Pattern strings below byte-match references/branch-detection.md. The
# parity verifier (tools/verify/m033-p01-branch-detection-ssot-parity.sh)
# enforces the match. Do NOT paraphrase these patterns — the parity
# verifier uses grep -F and will fail on any deviation.

detect_branch() {
    local proj="$1"

    # Rule 1: prior-tooling artifacts → migrating
    # SSOT: prior_tooling_globs: .gsd/ .gsd2/ .specify/
    if [ -d "$proj/.gsd" ] || [ -d "$proj/.gsd2" ] || [ -d "$proj/.specify" ]; then
        DETECTED_FROM=""
        if [ -f "$proj/.gsd/v1-roadmap.yml" ]; then
            DETECTED_FROM="gsd-v1"
        fi
        if [ -f "$proj/.gsd2/state.yml" ]; then
            DETECTED_FROM="gsd-v2"
        fi
        if [ -d "$proj/.specify/specs" ]; then
            DETECTED_FROM="spec-kit"
        fi
        write_detect_state
        echo "migrating"
        return 0
    fi

    # Rule 2: PBJ-shape .md files (≥3) AND no src/ → greenfield-with-materials
    # SSOT: pbj_md_glob: *BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md
    # SSOT: pbj_md_min_count: 3
    if [ ! -d "$proj/src" ]; then
        local pbj_count
        pbj_count=$(find "$proj" -maxdepth 1 -type f -name '*.md' \
            \( -iname '*BRIEF*' -o -iname '*PLAN*' -o -iname '*DECISIONS*' \
               -o -iname '*HANDOFF*' -o -iname '*AUDIT*' \) 2>/dev/null \
            | wc -l \
            | tr -d ' ')
        if [ "$pbj_count" -ge 3 ]; then
            echo "greenfield-with-materials"
            return 0
        fi
    fi

    # Rule 3: existing-codebase signals (any of: src/ dir, ≥10 source-ext
    # files at root, .git/ with ≥1 commit).
    # SSOT: source_extensions: .js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h
    # SSOT: source_root_min_count: 10
    # SSOT: git_min_commits: 1
    local has_src=0
    local has_many_sources=0
    local has_git_commits=0
    if [ -d "$proj/src" ]; then
        has_src=1
    fi
    local src_root_count
    src_root_count=$(find "$proj" -maxdepth 1 -type f \
        \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \
           -o -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.rb' \
           -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.cs' \
           -o -name '*.cpp' -o -name '*.c' -o -name '*.h' \) 2>/dev/null \
        | wc -l \
        | tr -d ' ')
    if [ "$src_root_count" -ge 10 ]; then
        has_many_sources=1
    fi
    if [ -d "$proj/.git" ]; then
        local commit_count
        commit_count=$(git -C "$proj" rev-list --count HEAD 2>/dev/null || echo 0)
        if [ "$commit_count" -ge 1 ]; then
            has_git_commits=1
        fi
    fi

    if [ "$has_src" -eq 1 ] || [ "$has_many_sources" -eq 1 ] || [ "$has_git_commits" -eq 1 ]; then
        # MIT-006 / RISK-006 disambiguation eligibility: rule 3 fired
        # solely because of .git/ ≥1 commit, with ≤9 source files at
        # root and no prior-tooling artifacts.
        MIT006_ELIGIBLE=0
        if [ "$has_git_commits" -eq 1 ] && [ "$has_src" -eq 0 ] && [ "$has_many_sources" -eq 0 ]; then
            if [ "$src_root_count" -le 9 ]; then
                MIT006_ELIGIBLE=1
            fi
        fi
        write_detect_state
        echo "existing-codebase"
        return 0
    fi

    # Rule 4: fallback → greenfield-empty
    write_detect_state
    echo "greenfield-empty"
    return 0
}

# ---------------------------------------------------------------------------
# Disambiguation question (US-1 AS-5 + MIT-006 / RISK-006)
# ---------------------------------------------------------------------------

prompt_case_a() {
    # Case A: rule 1 + rule 3 both match. Recommendation: migrating.
    local recommended="migrating"
    local alternative="existing-codebase"
    printf 'disambiguation: detected sibling-tool artifacts (.gsd/, .gsd2/, or .specify/) alongside source code.\n'
    printf 'recommended: %s (rule-1 wins by ordering — sibling-tool artifacts are the load-bearing signal).\n' "$recommended"
    printf 'override with %s if the sibling-tool artifacts are stale and you just want to onboard the codebase.\n' "$alternative"
    printf '[Y/y/enter] accept recommended, [n/N] override, anything else aborts: '
    local reply
    if ! IFS= read -r reply; then
        reply=""
    fi
    case "$reply" in
        ""|Y|y)
            echo "$recommended"
            return 0
            ;;
        N|n)
            echo "$alternative"
            return 0
            ;;
        *)
            printf 're-invoke with --branch <name>\n' 1>&2
            return 1
            ;;
    esac
}

prompt_case_b() {
    # Case B (MIT-006 / RISK-006): rule 3 fired solely on .git/, ≤9
    # source files. Recommendation: greenfield-empty.
    local recommended="greenfield-empty"
    local alternative="existing-codebase"
    printf 'disambiguation: git history present but only a thin signal — no src/, ≤9 source files at root, no prior-tooling artifacts.\n'
    printf 'this is the MIT-006 / RISK-006 case: a fresh git init with a README commit may otherwise be misclassified as existing-codebase.\n'
    printf 'recommended: greenfield-empty (per MIT-006 mitigation).\n'
    printf 'override with %s if you have code in a non-standard location.\n' "$alternative"
    printf '[Y/y/enter] accept recommended, [n/N] override, anything else aborts: '
    local reply
    if ! IFS= read -r reply; then
        reply=""
    fi
    case "$reply" in
        ""|Y|y)
            echo "$recommended"
            return 0
            ;;
        N|n)
            echo "$alternative"
            return 0
            ;;
        *)
            printf 're-invoke with --branch <name>\n' 1>&2
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Detection-with-disambiguation pipeline
# ---------------------------------------------------------------------------

resolve_branch() {
    local proj="$1"
    local detected
    detected=$(detect_branch "$proj")
    load_detect_state

    # Case A ambiguity: rule 1 + rule 3 both match. detect_branch
    # returns "migrating" by ordering, but we re-probe to know if rule 3
    # would also have matched.
    local rule3_would_match=0
    if [ "$detected" = "migrating" ]; then
        if [ -d "$proj/src" ]; then
            rule3_would_match=1
        fi
    fi

    if [ "$detected" = "migrating" ] && [ "$rule3_would_match" -eq 1 ]; then
        if [ "$YES" -eq 1 ]; then
            # --yes: rule-1 wins by ordering.
            echo "$detected"
            return 0
        fi
        local resolved
        if ! resolved=$(prompt_case_a); then
            return 1
        fi
        echo "$resolved"
        return 0
    fi

    # Case B ambiguity: MIT-006 / RISK-006 — rule 3 fired solely on
    # .git/ ≥1 commit. Under --yes, the detected existing-codebase
    # stands; operator must override with --branch greenfield-empty.
    if [ "$detected" = "existing-codebase" ] && [ "$MIT006_ELIGIBLE" -eq 1 ]; then
        if [ "$YES" -eq 1 ]; then
            echo "$detected"
            return 0
        fi
        local resolved
        if ! resolved=$(prompt_case_b); then
            return 1
        fi
        echo "$resolved"
        return 0
    fi

    echo "$detected"
    return 0
}

# ---------------------------------------------------------------------------
# Stub dispatch
# ---------------------------------------------------------------------------

dispatch_stub() {
    local branch_name="$1"
    case "$branch_name" in
        greenfield-empty)
            ideation_stub
            ;;
        greenfield-with-materials)
            materials_intake_stub
            ;;
        existing-codebase)
            ingest_codebase_stub
            ;;
        migrating)
            migrate_routing_stub
            ;;
        *)
            printf 'internal error: unknown branch name: %s\n' "$branch_name" 1>&2
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# FR-20 / CON-6 resume-on-partial-state helpers
# ---------------------------------------------------------------------------
#
# The resume-detection block reads sub-flow start-state markers via
# scripts/util/start-state-markers.sh. If THIS branch's sub-flow marker
# is already present, start.sh emits the load-bearing diagnostic
# `start-state: resuming from <next sub-flow>` and skips the sub-flow
# dispatch (P03/P04/P05 will eventually replace this exit-0 with
# real next-sub-flow dispatch). The --no-resume flag forces the full
# P01 baseline path (escape valve).
#
# The block is purely additive — when no markers are present (the P01
# baseline), control falls through to the existing dispatch_stub path.
#
# spec ref: FR-20 (marker convention), CON-6 (resume on partial state),
#           SC-12 (resume diagnostic acceptance criterion).

branch_to_subflow() {
    case "$1" in
        greenfield-empty)         echo "ideation" ;;
        greenfield-with-materials) echo "materials-intake" ;;
        existing-codebase)        echo "ingest-codebase" ;;
        migrating)                echo "migrate-routed" ;;
        *)                        echo "" ;;
    esac
}

# ---------------------------------------------------------------------------
# FR-15 wiki-init paired-launch passthrough (M033/P05/T02 additive).
#
# Spec ref: FR-15 / spec 035 FR-11 / CON-1 / MIT-001.
#
# Two-mode test contract (MIT-001):
#   Stub mode (M033_FR15_STUB=1):
#     Emits 'STUB: wiki-init invoked --project-dir=<path> [--with-giscus] [--deploy]'
#     Returns M033_FR15_STUB_EXIT_CODE (default 0). Does NOT invoke wiki-init.sh.
#   Real mode (M033_FR15_STUB unset/0):
#     If scripts/lifecycle/wiki-init.sh exists (M032/P02 closed), invokes it.
#     Otherwise, emits 'wiki-init.sh not found ...' diagnostic and returns rc=1
#     (genuine failure, NOT skip — SC-14 skip=0 invariant).
#
# Sequential-atomicity model (FR-15 / spec 035 CON-3):
#   On non-zero exit, surfaces failure as a wiki-init failure (NOT a start
#   failure); preserves all US-1..US-7 sub-flow markers (no rollback);
#   propagates the underlying exit code verbatim.
# ---------------------------------------------------------------------------

wiki_init_passthrough() {
    local project_dir="$1"
    local with_giscus_flag=""
    local deploy_flag=""
    if [ "$WITH_GISCUS" -eq 1 ]; then
        with_giscus_flag="--with-giscus"
    fi
    if [ "$DEPLOY" -eq 1 ]; then
        deploy_flag="--deploy"
    fi

    local rc=0
    local stub_mode="false"
    if [ "${M033_FR15_STUB:-0}" -eq 1 ]; then
        stub_mode="true"
        printf 'STUB: wiki-init invoked --project-dir=%s %s %s\n' \
            "$project_dir" "$with_giscus_flag" "$deploy_flag"
        rc="${M033_FR15_STUB_EXIT_CODE:-0}"
    elif [ -f "scripts/lifecycle/wiki-init.sh" ]; then
        # Real-mode: M032/P02 has shipped wiki-init.sh.
        rc=0
        bash scripts/lifecycle/wiki-init.sh \
            --project-dir "$project_dir" $with_giscus_flag $deploy_flag || rc=$?
    else
        # M032/P02 not closed AND no stub mode -- genuine failure (not skip).
        printf 'wiki-init.sh not found -- M032/P02 must close before --with-wiki real-mode can fire\n' 1>&2
        rc=1
    fi

    # FR-22 JSONL emit with downstream exit code threading.
    local with_giscus_bool="false"
    local deploy_bool="false"
    if [ "$WITH_GISCUS" -eq 1 ]; then
        with_giscus_bool="true"
    fi
    if [ "$DEPLOY" -eq 1 ]; then
        deploy_bool="true"
    fi
    local payload
    payload=$(printf '{"project_dir":"%s","exit_code":%d,"stub_mode":%s,"with_giscus":%s,"deploy":%s}' \
        "$project_dir" "$rc" "$stub_mode" "$with_giscus_bool" "$deploy_bool")
    # PROJECT_DIR threading: the emitter writes to <PROJECT_DIR>/.orchestrator/
    # execution-log.jsonl. Without the explicit prefix, the emitter falls
    # back to $PWD (the dispatcher cwd, NOT the staged project dir). Same
    # pattern as migrate_routing's emit at line ~239. Surgically minimal
    # fix landed in M033/P05/T04 so SC-9 acceptance can read the per-project
    # JSONL surface.
    PROJECT_DIR="$project_dir" bash scripts/util/jsonl-event-emitter.sh emit wiki_init_invoked "$payload" || true

    # Sequential-atomicity model: surface failure as wiki-init failure;
    # preserve sub-flow markers; propagate exit code verbatim.
    if [ "$rc" -ne 0 ]; then
        printf 'wiki-init failed; re-run "orchestrator:wiki-init" independently to complete; all other onboarding outputs preserved\n'
        return "$rc"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# FR-16 github-init paired-launch passthrough (M033/P05/T03 additive).
#
# Spec ref: FR-16 / paired-launch ordering rule / CON-1 / MIT-001.
#
# Two-mode test contract (MIT-001) -- mirrors FR-15 wiki passthrough:
#   Stub mode (M033_GHINIT_STUB=1):
#     Emits 'STUB: github-init invoked --project-dir=<path>'
#     Returns M033_GHINIT_STUB_EXIT_CODE (default 0). Does NOT invoke
#     github-init.sh.
#   Real mode (M033_GHINIT_STUB unset/0):
#     If scripts/lifecycle/github-init.sh exists (M013 closed), invokes it.
#     Otherwise, emits 'github-init.sh not found ...' diagnostic and
#     returns rc=1 (genuine failure, NOT skip -- SC-14 skip=0 invariant).
#
# Sequential-atomicity model (FR-16 paired-launch contract):
#   On non-zero exit, surfaces failure as a github-init failure (NOT a
#   start failure); preserves all US-1..US-7 sub-flow markers AND wiki-init
#   marker (no rollback); propagates the underlying exit code verbatim.
#
# Ordering rule: github-init MUST fire AFTER wiki-init when both flags
# are present. Enforced by code ordering -- T03's gate is inserted
# IMMEDIATELY AFTER T02's wiki gate in main().
# ---------------------------------------------------------------------------

github_init_passthrough() {
    # FR-16 paired-launch contract -- mirrors FR-15's failure-propagation
    # discipline. Must fire AFTER wiki-init (when --with-wiki --with-github
    # are combined) per the post-wiki-init ordering rule.
    local project_dir="$1"

    local rc=0
    local stub_mode="false"
    if [ "${M033_GHINIT_STUB:-0}" -eq 1 ]; then
        stub_mode="true"
        printf 'STUB: github-init invoked --project-dir=%s\n' "$project_dir"
        rc="${M033_GHINIT_STUB_EXIT_CODE:-0}"
    elif [ -f "scripts/lifecycle/github-init.sh" ]; then
        # Real-mode: M013 has shipped github-init.sh.
        rc=0
        bash scripts/lifecycle/github-init.sh --project-dir "$project_dir" || rc=$?
    else
        # M013 absent AND no stub mode -- genuine failure (not skip).
        printf 'github-init.sh not found -- M013 must be installed before --with-github real-mode can fire\n' 1>&2
        rc=1
    fi

    # FR-22 JSONL emit with downstream exit code threading.
    local payload
    payload=$(printf '{"project_dir":"%s","exit_code":%d,"stub_mode":%s}' \
        "$project_dir" "$rc" "$stub_mode")
    # PROJECT_DIR threading: same pattern as wiki_init_passthrough's emit
    # (and migrate_routing's emit at line ~239). Without the explicit
    # prefix, the emitter falls back to $PWD which is the dispatcher cwd
    # rather than the staged project dir. Surgically minimal fix landed
    # in M033/P05/T04 so SC-10 acceptance can read the per-project JSONL.
    PROJECT_DIR="$project_dir" bash scripts/util/jsonl-event-emitter.sh emit github_init_invoked "$payload" || true

    # Sequential-atomicity model: surface failure as github-init failure;
    # preserve sub-flow markers (and wiki-init marker if present);
    # propagate exit code verbatim.
    if [ "$rc" -ne 0 ]; then
        printf 'github-init failed; re-run "orchestrator:github-init" independently to complete; all other onboarding outputs preserved\n'
        return "$rc"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Patch A (M033 friendly-tester UX): warm welcome footer.
#
# Emits a per-branch human-readable footer AFTER the existing machine
# tokens (SUMMARY:, branch:, would-execute:, migrate-routed:, proposed:,
# start-state:, branch-override:). Strictly ADDITIVE -- preserves all
# load-bearing tokens grep'd by the M033 verifier suite. Always written
# to stdout. Box-drawing uses U+2500 horizontal-line; no emoji.
#
# The footer answers the three friendly-tester questions every operator
# asks at this point:
#   1. WHAT to type next (concrete `/orchestrator-*` skill name).
#   2. WHY this branch fired (one-sentence "we detected ... so we'll ...").
#   3. HOW to course-correct (force a different branch).
# ---------------------------------------------------------------------------

# Count PBJ-shape .md files for the greenfield-with-materials footer.
# Mirrors detect_branch's rule-2 find invocation byte-for-byte (same
# patterns, same maxdepth) so the count we report is exactly what
# detection saw.
count_pbj_md_files() {
    local proj="$1"
    find "$proj" -maxdepth 1 -type f -name '*.md' \
        \( -iname '*BRIEF*' -o -iname '*PLAN*' -o -iname '*DECISIONS*' \
           -o -iname '*HANDOFF*' -o -iname '*AUDIT*' \) 2>/dev/null \
        | wc -l \
        | tr -d ' '
}

# Compose the existing-codebase "we detected ..." sentence by listing
# only the signals that actually fired. Mirrors detect_branch's rule-3
# probe shape; called from emit_welcome_footer when the branch is
# existing-codebase.
existing_codebase_signal_sentence() {
    local proj="$1"
    local has_src=0 has_many=0 has_git=0
    local src_count=0 commit_count=0
    if [ -d "$proj/src" ]; then has_src=1; fi
    src_count=$(find "$proj" -maxdepth 1 -type f \
        \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \
           -o -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.rb' \
           -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.cs' \
           -o -name '*.cpp' -o -name '*.c' -o -name '*.h' \) 2>/dev/null \
        | wc -l \
        | tr -d ' ')
    if [ "$src_count" -ge 10 ]; then has_many=1; fi
    if [ -d "$proj/.git" ]; then
        commit_count=$(git -C "$proj" rev-list --count HEAD 2>/dev/null || echo 0)
        if [ "$commit_count" -ge 1 ]; then has_git=1; fi
    fi
    local parts=""
    if [ "$has_src" -eq 1 ]; then
        parts="src/ directory present"
    fi
    if [ "$has_many" -eq 1 ]; then
        if [ -n "$parts" ]; then parts="$parts; "; fi
        parts="${parts}${src_count} source files at root (>=10)"
    fi
    if [ "$has_git" -eq 1 ]; then
        if [ -n "$parts" ]; then parts="$parts; "; fi
        parts="${parts}.git/ with ${commit_count} commit(s)"
    fi
    if [ -z "$parts" ]; then
        parts="existing-codebase signal (forced via --branch override)"
    fi
    # No trailing newline -- caller embeds in a printf format string and
    # adds its own '\n'.
    printf 'an existing codebase (%s)' "$parts"
}

emit_welcome_footer() {
    local branch_name="$1"
    local proj="$2"

    local sep='---------------------------------------------------------------------'
    # Use box-drawing horizontal line (U+2500).
    sep='─────────────────────────────────────────────────────'

    case "$branch_name" in
        greenfield-empty)
            printf '%s\n' "$sep"
            printf ' [OK] Setup complete\n'
            printf '\n'
            printf '   We detected: an empty project (no code, no docs)\n'
            printf "   So we'll: walk you through ideating what to build\n"
            printf '\n'
            printf ' NEXT STEP -- in your Claude Code session, type:\n'
            printf '   /orchestrator-evaluate\n'
            printf '\n'
            printf ' Need a different path? Force a branch:\n'
            printf '   start.sh --branch greenfield-with-materials | existing-codebase | migrating\n'
            printf '%s\n' "$sep"
            ;;
        greenfield-with-materials)
            local pbj_n
            pbj_n=$(count_pbj_md_files "$proj")
            printf '%s\n' "$sep"
            printf ' [OK] Setup complete\n'
            printf '\n'
            printf '   We detected: a project with %s markdown brief documents (no source code)\n' "$pbj_n"
            printf "   So we'll: ingest your materials and walk you through scoping a roadmap\n"
            printf '\n'
            printf ' NEXT STEP -- in your Claude Code session, type:\n'
            printf '   /orchestrator-materials-intake\n'
            printf '\n'
            printf ' Need a different path? Force a branch:\n'
            printf '   start.sh --branch greenfield-empty | existing-codebase | migrating\n'
            printf '%s\n' "$sep"
            ;;
        existing-codebase)
            local sig_sentence
            sig_sentence=$(existing_codebase_signal_sentence "$proj")
            printf '%s\n' "$sep"
            printf ' [OK] Setup complete\n'
            printf '\n'
            printf '   We detected: %s\n' "$sig_sentence"
            printf "   So we'll: scan your codebase to seed an orchestrator knowledge graph (5-15 architecture/conventions/decisions chunks)\n"
            printf '\n'
            printf ' NEXT STEP -- in your Claude Code session, type:\n'
            printf '   /orchestrator-ingest-codebase\n'
            printf '\n'
            printf ' Need a different path? Force a branch:\n'
            printf '   start.sh --branch greenfield-empty | greenfield-with-materials | migrating\n'
            printf '%s\n' "$sep"
            ;;
        migrating)
            if [ -n "${DETECTED_FROM:-}" ]; then
                printf '%s\n' "$sep"
                printf ' [OK] Setup complete\n'
                printf '\n'
                printf '   We detected: a project from %s\n' "$DETECTED_FROM"
                printf "   So we'll: migrate your existing tooling state into orchestrator format\n"
                printf '\n'
                printf ' NEXT STEP -- in your Claude Code session, type:\n'
                printf '   /orchestrator-migrate\n'
                printf '\n'
                printf ' Need a different path? Force a branch:\n'
                printf '   start.sh --branch greenfield-empty | greenfield-with-materials | existing-codebase\n'
                printf '%s\n' "$sep"
            fi
            # The DETECTED_FROM-empty case is handled by the dead-end
            # footer in emit_migrate_dead_end_footer (Patch D), invoked
            # from migrate_routing on the unsupported-tooling branch.
            ;;
        *)
            : # Unknown branch: silent (the dispatch_stub already errors).
            ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# Patch C (M033 friendly-tester UX): existing-codebase pre-flight.
#
# The friendly-tester walkthrough (2026-05-09) found that pointing
# start.sh at a real repo silently writes 8+ items at the project root
# (commands/, scripts/, references/, templates/, wiki/, .gitignore,
# CLAUDE.md, AGENTS.md, .orchestrator/). A stranger loses confidence.
#
# This pre-flight runs BEFORE invoke_init in the existing-codebase case:
#   1. Lists what install-claude-code.sh's project_assets stage will
#      create (cross-checked against packaging/bundle/manifest.yml on
#      2026-05-09: commands/ scripts/ references/ templates/ wiki/).
#      Plus .orchestrator/, CLAUDE.md, AGENTS.md, .gitignore.
#   2. Checks each item against the project root for collisions.
#   3. On collision -> exit 2 (refuse). Operator resolves manually or
#      passes --branch <other> to bypass.
#   4. No collision + TTY + no --yes -> prompt for confirmation.
#   5. --yes -> skip prompt, but still print the warning + would-create
#      list (transparency contract).
#   6. --dry-run -> print + emit "DRY-RUN: no changes made" + exit 0
#      BEFORE invoke_init runs.
#
# Out-of-tree footprint refactor (the deeper fix that would move
# commands/ scripts/ references/ templates/ wiki/ under .orchestrator/)
# is filed as a separate post-launch proposal.
# ---------------------------------------------------------------------------

# Items the install-claude-code.sh project_assets stage creates at the
# project root. Two-column "name  description" rows for the warning
# block. Source: packaging/bundle/manifest.yml project_assets list +
# .orchestrator/, CLAUDE.md, AGENTS.md, .gitignore (added by the
# installer's hook + state-root + instruction-file phases).
existing_codebase_would_create_items() {
    cat <<'EOF'
.orchestrator/    state directory
CLAUDE.md         instruction file for Claude Code
AGENTS.md         instruction file for Codex CLI
.gitignore        orchestrator state ignores
commands/         skill definitions
references/       architectural docs
scripts/          helper scripts
templates/        output templates
wiki/             wiki tooling
EOF
}

# Print the existing-codebase pre-flight warning block. Detects
# collisions; populates COLLISIONS_DETECTED (global) for the caller to
# act on. Uses awk to split the "name  description" rows into the
# bullet shape.
emit_existing_codebase_preflight() {
    local proj="$1"
    local sep='─────────────────────────────────────────────────────'

    # Compute collisions first so the COLLISIONS DETECTED block can be
    # included in the same warning frame.
    PREFLIGHT_COLLISIONS=""
    local item
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        item="${line%% *}"
        if [ -e "$proj/$item" ]; then
            if [ -z "$PREFLIGHT_COLLISIONS" ]; then
                PREFLIGHT_COLLISIONS="$item"
            else
                PREFLIGHT_COLLISIONS="$PREFLIGHT_COLLISIONS
$item"
            fi
        fi
    done <<EOF
$(existing_codebase_would_create_items)
EOF

    printf '%s\n' "$sep"
    printf ' [WARN] About to install orchestrator into an existing codebase\n'
    printf '\n'
    printf '    Target: %s\n' "$proj"
    printf "    We'll create these items at the project root:\n"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        item="${line%% *}"
        # Description = the rest after the first run of spaces.
        local desc="${line#* }"
        # Trim leading spaces from desc.
        while [ "${desc#" "}" != "$desc" ]; do desc="${desc#" "}"; done
        printf '      - %-18s(%s)\n' "$item" "$desc"
    done <<EOF
$(existing_codebase_would_create_items)
EOF

    if [ -n "$PREFLIGHT_COLLISIONS" ]; then
        printf '\n'
        printf '  COLLISIONS DETECTED:\n'
        local cline
        while IFS= read -r cline; do
            [ -z "$cline" ] && continue
            printf '    - %s     (will be modified or refused -- review first)\n' "$cline"
        done <<EOF
$PREFLIGHT_COLLISIONS
EOF
    fi
    printf '\n'
    printf '  Tip: re-run with --dry-run to preview without writing.\n'
    printf '%s\n' "$sep"
    return 0
}

# ---------------------------------------------------------------------------
# Patch D (M033 friendly-tester UX): actionable migrate dead-end.
#
# The legacy line `no orchestrator:migrate adapter for this tooling --
# please file a request` (still emitted by migrate_routing on stderr to
# preserve the load-bearing token grep'd by m033-p04-migrate-routing-
# shape.sh + p05-migrate-routing.sh) tells operators "file a request"
# with no path forward. Append a multi-line actionable footer on stdout
# explaining the supported sources and the two course-correction paths.
# ---------------------------------------------------------------------------

emit_migrate_dead_end_footer() {
    local proj="$1"
    local sep='─────────────────────────────────────────────────────'
    printf '%s\n' "$sep"
    printf ' [FAIL] No migration adapter for this tooling\n'
    printf '\n'
    printf '   We detected: a project with prior tooling (.gsd / .gsd2 / .specify marker)\n'
    printf "   But: the layout doesn't match a known migration adapter.\n"
    printf '\n'
    printf '   Supported sources: gsd-v1, gsd-v2, spec-kit\n'
    printf '   Your project: marker present but no recognizable internal layout\n'
    printf '\n'
    printf ' OPTIONS:\n'
    printf '   1. Force a different branch:\n'
    printf '        start.sh --project-dir %s --branch existing-codebase\n' "$proj"
    printf '   2. Request adapter support:\n'
    printf "        File an issue describing your project's tooling layout.\n"
    # TODO: post-launch -- replace with GitHub Issues URL once M035 P06
    # closure publishes the public repo.
    printf '        (No public issue tracker yet -- for now, attach project tree + email.)\n'
    printf '%s\n' "$sep"
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    # ---------------------------------------------------------------------
    # Patch C (M033 friendly-tester UX): existing-codebase pre-flight.
    # Runs BEFORE invoke_init so the operator sees what's about to be
    # written into a real codebase (and can refuse / dry-run / accept).
    #
    # We need the would-be branch to gate this. When --branch is given,
    # use it directly. Otherwise peek-detect via detect_branch (peek-only
    # -- the "real" detection later in main() runs again to populate
    # DETECTED_FROM via load_detect_state and emit the final 'branch:'
    # line). The peek is idempotent and side-effect-free apart from
    # writing DETECT_STATE_FILE (which the real detection overwrites).
    # ---------------------------------------------------------------------
    PREFLIGHT_BRANCH=""
    PREFLIGHT_MIT006=0
    if [ -n "$BRANCH_OVERRIDE" ]; then
        PREFLIGHT_BRANCH="$BRANCH_OVERRIDE"
    else
        # Skip peek if config.yml already present -- the pre-flight is
        # for first-install only. On a re-invoke against an
        # already-initialized project, init prints 'init already
        # complete' and we go straight through.
        if [ ! -f "$PROJECT_DIR/.orchestrator/config.yml" ]; then
            PREFLIGHT_BRANCH=$(detect_branch "$PROJECT_DIR" 2>/dev/null || echo "")
            load_detect_state
            PREFLIGHT_MIT006="$MIT006_ELIGIBLE"
        fi
    fi

    # MIT-006 / RISK-006 carve-out: when rule-3 fired solely on .git/
    # with <=9 source files (the thin-signal case), suppress the
    # pre-flight. Without this, the dry-run pre-flight would exit
    # before the MIT-006 disambiguation prompt could fire and the
    # operator would never see the recommendation to flip to
    # greenfield-empty. The disambiguation question (prompt_case_b
    # in resolve_branch) is the load-bearing UX for this case.
    if [ "$PREFLIGHT_BRANCH" = "existing-codebase" ] \
       && [ "$PREFLIGHT_MIT006" = "1" ] \
       && [ "$YES" -ne 1 ] \
       && [ -z "$BRANCH_OVERRIDE" ]; then
        PREFLIGHT_BRANCH=""
    fi

    if [ "$PREFLIGHT_BRANCH" = "existing-codebase" ] \
       && [ ! -f "$PROJECT_DIR/.orchestrator/config.yml" ]; then
        emit_existing_codebase_preflight "$PROJECT_DIR"
        if [ -n "$PREFLIGHT_COLLISIONS" ]; then
            printf 'orchestrator install would collide with existing project files; resolve manually or use --branch to force a different branch\n' 1>&2
            exit 2
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            printf 'DRY-RUN: no changes made\n'
            exit 0
        fi
        if [ "$YES" -ne 1 ] && [ -t 0 ]; then
            printf 'Proceed? [y/N] '
            local _reply
            if ! IFS= read -r _reply; then _reply=""; fi
            case "$_reply" in
                y|Y|yes|YES) ;;
                *)
                    printf 'aborted -- re-invoke with --yes or accept the prompt\n' 1>&2
                    exit 1
                    ;;
            esac
        fi
    fi

    invoke_init "$PROJECT_DIR"

    # FR-20: post-init, write the init-invoked marker for symmetry with
    # downstream sub-flow markers. Idempotent — the primitive preserves
    # the first-completion timestamp, so re-invoking start.sh after init
    # has previously completed is a no-op for this marker.
    if [ -f "$PROJECT_DIR/.orchestrator/config.yml" ]; then
        bash scripts/util/start-state-markers.sh write init-invoked "$PROJECT_DIR" || true
    fi

    local final_branch=""

    if [ -n "$BRANCH_OVERRIDE" ]; then
        # Override path: skip detection. Compute what detection would
        # have produced for the diagnostic.
        local detected_for_diag
        detected_for_diag=$(detect_branch "$PROJECT_DIR")
        load_detect_state
        if [ "$detected_for_diag" != "$BRANCH_OVERRIDE" ]; then
            printf 'branch-override: detected=%s overridden=%s\n' "$detected_for_diag" "$BRANCH_OVERRIDE" 1>&2
        fi
        final_branch="$BRANCH_OVERRIDE"
    else
        if ! final_branch=$(resolve_branch "$PROJECT_DIR"); then
            exit 1
        fi
        load_detect_state
    fi

    printf 'branch: %s\n' "$final_branch"

    # FR-20 / CON-6 resume-on-partial-state: if THIS branch's sub-flow
    # marker is already present, emit the load-bearing diagnostic and
    # skip the sub-flow dispatch. The --no-resume flag forces full
    # baseline behavior.
    if [ "$NO_RESUME" -eq 0 ]; then
        local completed_subflows
        completed_subflows=$(bash scripts/util/start-state-markers.sh read "$PROJECT_DIR")
        local this_subflow
        this_subflow=$(branch_to_subflow "$final_branch")
        if [ -n "$this_subflow" ]; then
            if echo "$completed_subflows" | grep -qx "$this_subflow"; then
                local next_subflow
                next_subflow=$(bash scripts/util/start-state-markers.sh next "$PROJECT_DIR")
                printf 'start-state: resuming from %s\n' "$next_subflow"
                exit 0
            fi
        fi
    fi

    dispatch_stub "$final_branch"

    # Patch A (M033 friendly-tester UX): per-branch warm welcome footer.
    # Strictly additive -- emitted AFTER all machine tokens (SUMMARY:,
    # branch:, would-execute:, migrate-routed:, proposed:). For the
    # migrating-with-empty-DETECTED_FROM (unsupported tooling) case,
    # the dead-end footer is emitted by migrate_routing instead and
    # this welcome footer is suppressed (see emit_welcome_footer's
    # migrating branch).
    emit_welcome_footer "$final_branch" "$PROJECT_DIR"

    # FR-15 wiki-init paired-launch passthrough (post-onboarding gate).
    # Fires after the branch sub-flow has completed (US-1..US-7 markers
    # already written). On non-zero, propagates exit code verbatim per
    # the sequential-atomicity model. T03 will append a similar
    # --with-github gate AFTER this one so the natural code ordering
    # enforces github-init not firing before wiki-init succeeds.
    if [ "$WITH_WIKI" -eq 1 ]; then
        WIKI_RC=0
        wiki_init_passthrough "$PROJECT_DIR" || WIKI_RC=$?
        if [ "$WIKI_RC" -ne 0 ]; then
            exit "$WIKI_RC"
        fi
    fi

    # FR-16 github-init paired-launch passthrough (post-wiki-init gate).
    # Fires after the wiki gate has completed (or was never invoked).
    # Code ordering enforces the FR-16 ordering rule: when both flags are
    # passed and wiki succeeds, the wiki gate returns 0 and falls through
    # to this block; when wiki fails, the wiki gate exits with WIKI_RC and
    # this block is unreachable. On non-zero, propagates exit code verbatim
    # per the sequential-atomicity model (preserves wiki-init marker).
    if [ "$WITH_GITHUB" -eq 1 ]; then
        GH_RC=0
        github_init_passthrough "$PROJECT_DIR" || GH_RC=$?
        if [ "$GH_RC" -ne 0 ]; then
            exit "$GH_RC"
        fi
    fi

    # M029 / FR-10 / #Q-3 -- --auto-chain entry-chain walker.
    # Walks evaluate -> discuss -> roadmap -> plan-phase one stage at a time,
    # writing .orchestrator/start-state/<stage>.complete after each success.
    # The four canonical marker filenames are:
    #   - .orchestrator/start-state/evaluate.complete
    #   - .orchestrator/start-state/discuss.complete
    #   - .orchestrator/start-state/roadmap.complete
    #   - .orchestrator/start-state/plan-phase.complete
    # Failed stages leave the marker absent (#Q-3); re-runs re-execute.
    # AD-3 priority order between stages: --yes > auto_proceed:true >
    # non-TTY refusal (M029_AUTOCHAIN_NEEDS_CONFIRMATION) > TTY prompt.
    # See commands/auto.md AD-3 section for the canonical four-tier policy.
    # Fires AFTER --with-wiki / --with-github passthrough gates so wiki /
    # github initialization (when requested) lands before the chain walks.
    if [ "${AUTO_CHAIN:-0}" -eq 1 ]; then
        START_STATE_DIR="$PROJECT_DIR/.orchestrator/start-state"
        mkdir -p "$START_STATE_DIR"

        # Resolve auto_proceed from config (4-layer per
        # scripts/state/read-config.sh). Empty / failure -> empty string.
        AUTO_PROCEED_VAL=""
        if [ -r scripts/state/read-config.sh ]; then
            AUTO_PROCEED_VAL=$(bash scripts/state/read-config.sh auto_proceed 2>/dev/null || true)
        fi

        for STAGE in evaluate discuss roadmap plan-phase; do
            MARKER="$START_STATE_DIR/${STAGE}.complete"
            if [ -f "$MARKER" ]; then
                printf 'SKIP: %s (marker present)\n' "$STAGE"
                continue
            fi

            # AD-3 between-stage gate.
            PROCEED=0
            if [ "${YES:-0}" -eq 1 ]; then
                PROCEED=1
            elif [ "$AUTO_PROCEED_VAL" = "true" ]; then
                PROCEED=1
            elif [ -t 0 ]; then
                # TTY -- prompt for confirmation between each stage.
                printf 'Proceed with %s? [y/N] ' "$STAGE"
                read -r REPLY
                case "$REPLY" in
                    y|Y|yes|YES) PROCEED=1 ;;
                    *) PROCEED=0 ;;
                esac
            else
                printf 'M029_AUTOCHAIN_NEEDS_CONFIRMATION\n' 1>&2
                exit 2
            fi

            if [ "$PROCEED" -ne 1 ]; then
                printf 'START_AUTO_CHAIN_ABORTED stage=%s\n' "$STAGE" 1>&2
                exit 1
            fi

            # Invoke the stage's skill. For SC-10 fixture mode, the
            # AUTO_CHAIN_STAGE_STUB env var allows fixtures to inject a
            # no-op stub script that just writes the marker (used by the
            # SC-10 acceptance script only). In real-mode invocation
            # (no env var set), the chain-driver assumes the orchestrator
            # harness (Claude Code, Codex CLI, Cursor) invokes each stage's
            # skill (orchestrator:<stage>) between successive
            # start.sh --auto-chain calls; this script's role is to gate,
            # prompt, mark, and resume.
            STAGE_RC=0
            if [ -n "${AUTO_CHAIN_STAGE_STUB:-}" ]; then
                bash "$AUTO_CHAIN_STAGE_STUB" "$STAGE" || STAGE_RC=$?
            fi

            if [ "$STAGE_RC" -ne 0 ]; then
                # #Q-3 -- failed stages leave the .complete marker absent.
                # No alternate failure-marker is written; re-runs re-execute.
                printf 'START_AUTO_CHAIN_STAGE_FAILED stage=%s\n' "$STAGE" 1>&2
                exit 1
            fi

            # Write the .complete marker (#Q-3 -- only on success).
            NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            printf '%s %s\n' "$NOW" "$STAGE" > "$MARKER"
            printf 'OK: %s -> %s\n' "$STAGE" "$MARKER"
        done

        printf 'START_AUTO_CHAIN_COMPLETE\n'
    fi

    exit 0
}

main "$@"
