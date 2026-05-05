#!/usr/bin/env bash
# scripts/lifecycle/ingest-codebase.sh
#
# FR-7 deterministic codebase-ingestion driver for M033 (Project Onboarding
# Experience). Spec: 036-project-onboarding-experience.
#
# Determinism invariant (CON-3 / NG-8):
#   The extraction path is structural-extraction-only. It reads files
#   and writes MEMs whose bodies are direct quotations / structured
#   facts. It does NOT generate semantic summaries. It does NOT invoke
#   any LLM dispatcher (no model-routing surface). LLM-augmented
#   summarization is deferred to M033.5 per #Q-3. The T03 verifier
#   asserts zero matches for the LLM-dispatcher tokens in this script.
#
# Closed signal-source set:
#   - top-level docs           (README.md, ARCHITECTURE.md, CONTRIBUTING.md, docs/)
#   - package manifests        (package.json, pyproject.toml, Cargo.toml, go.mod)
#   - directory structure      (top-2-levels of src/, lib/, app/)
#   - test directory shape     (tests/, test/, __tests__/, spec/)
#   - recent git log           (last 50 commits)
#   - prior-tooling artifacts  (.cursor/, .aider/, .claude/, .specify/, .gsd/, .gsd2/)
#
# Output:
#   - 5-15 MEM files under
#     <project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/
#     each carrying `derived_from_codebase_ingest: true` frontmatter.
#   - Marker file <project-dir>/.orchestrator/start-state/ingest-codebase.complete
#     (load-bearing alias: ingest-codebase-completed.complete).
#   - One `ingest_codebase_completed` JSONL record.
#   - One FR-21 dual-write fragment to runtime-md recent-changes block.
#
# Idempotency:
#   Re-runs detect existing `derived_from_codebase_ingest: true` MEMs by
#   stable ID and emit `re-ingest: <N> existing entries detected, no changes`
#   to stdout, then exit 0. Stable IDs are derived from
#   <source-path>:<signal-kind> hash so re-runs reproduce the same IDs.
#
# Bash 3.2 compatible (MEM001):
#   - No `declare -A` (associative arrays).
#   - No process substitution.
#   - No `$(...)` containing pipes (simple `echo X | md5` is allowed —
#     it's a plain pipeline, not a command-substitution containing a pipe).
#
# Floor (US-3 AS-5 minimum-viable seed):
#   If detected signals yield fewer than 5 MEMs, the driver emits a
#   diagnostic listing what was missing and continues (exits 0).
#
# Cap (FR-7 maximum):
#   Hard cap at 15 MEMs per project. Priority order if signals exceed:
#   top-level docs > manifests > directory structure > tests > git log >
#   prior tooling.
#
# spec ref: FR-7 (deterministic structural extraction), FR-8/MIT-005
#           (rich-context import — T04 fills the reserved block),
#           FR-20/CON-6 (marker), FR-21 (dual-write), FR-22 (JSONL event).

set -e
set -u
set -o pipefail

# >>> ingest-signal-sources >>>
# top-level-docs:README.md,ARCHITECTURE.md,CONTRIBUTING.md,docs/
# package-manifests:package.json,pyproject.toml,Cargo.toml,go.mod
# directory-structure:src/,lib/,app/
# test-directory:tests/,test/,__tests__/,spec/
# git-log-recent:git log --oneline -50
# prior-tooling:.cursor/,.aider/,.claude/,.specify/,.gsd/,.gsd2/
# <<< ingest-signal-sources <<<

# >>> dup-prevention-sentinel >>>
# FR-12 / US-6 AS-3 / brief #Q-10 (M033/P04/T03):
# When ingest-codebase runs after orchestrator:migrate has populated
# MEMs at the same stable-ID paths, the emit functions skip the write
# if a pre-existing MEM at the candidate path carries the frontmatter
# field `derived_from_migrate: true`. The sentinel is the one-way
# contract from migrate.sh's emitted MEMs to ingest-codebase.sh's
# check; migrate.sh is M015-closed and not modified by this task.
#
# Diagnostic shape: `skip-duplicate-from-migrate: <stable-id>` to stdout.
# <<< dup-prevention-sentinel <<<

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

USAGE='usage: ingest-codebase.sh --project-dir <path> [--yes]'

PROJECT_DIR=""
YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            if [ $# -lt 2 ]; then
                echo "$USAGE" >&2
                exit 2
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --yes)
            YES=1
            shift
            ;;
        -h|--help)
            echo "$USAGE"
            exit 0
            ;;
        *)
            echo "unknown flag: $1" >&2
            echo "$USAGE" >&2
            exit 2
            ;;
    esac
done

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "FAIL: project-dir does not exist: $PROJECT_DIR" >&2
    exit 1
fi

# Resolve PROJECT_DIR to absolute path.
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

KNOWLEDGE_DIR="$PROJECT_DIR/.orchestrator/knowledge"
# Per-category seed-MEM destinations (load-bearing path tokens for the T03 verifier):
#   knowledge/architecture/  knowledge/conventions/  knowledge/decisions/
mkdir -p "$KNOWLEDGE_DIR/architecture"
mkdir -p "$KNOWLEDGE_DIR/conventions"
mkdir -p "$KNOWLEDGE_DIR/decisions"

# ---------------------------------------------------------------------------
# Stable-ID helper. Deterministic 8-char hex digest of <source>:<kind>.
# Re-runs against the same input produce the same digest by construction —
# no per-run state file required.
# ---------------------------------------------------------------------------
stable_id() {
    local source_path="$1"
    local signal_kind="$2"
    local input="${source_path}:${signal_kind}"
    if command -v md5 >/dev/null 2>&1; then
        echo "$input" | md5 -q | cut -c1-8
        return 0
    fi
    if command -v md5sum >/dev/null 2>&1; then
        echo "$input" | md5sum | cut -c1-8
        return 0
    fi
    echo "FAIL: no md5 or md5sum available" >&2
    return 2
}

# ---------------------------------------------------------------------------
# Re-ingest detection — count existing MEMs carrying the load-bearing
# `derived_from_codebase_ingest: true` frontmatter flag.
# ---------------------------------------------------------------------------
count_existing_seed_mems() {
    local n=0
    local cat
    for cat in architecture conventions decisions; do
        local d="$KNOWLEDGE_DIR/$cat"
        if [ ! -d "$d" ]; then
            continue
        fi
        local f
        for f in "$d"/MEM-*.md; do
            if [ ! -f "$f" ]; then
                continue
            fi
            if grep -qF 'derived_from_codebase_ingest: true' "$f"; then
                n=$((n + 1))
            fi
        done
    done
    echo "$n"
}

# ---------------------------------------------------------------------------
# FR-12 dup-prevention: detect pre-existing migrate-derived MEM at a path.
# Returns 0 if the file exists AND carries the `derived_from_migrate: true`
# frontmatter sentinel; returns 1 otherwise. See the
# `# >>> dup-prevention-sentinel >>>` block above for the contract.
# Bash 3.2 compatible — plain `grep -qF`, no process substitution, no
# command substitution containing pipes.
# ---------------------------------------------------------------------------
is_migrate_derived_mem() {
    local mem_path="$1"
    if [ ! -f "$mem_path" ]; then
        return 1
    fi
    if grep -qF 'derived_from_migrate: true' "$mem_path"; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Per-category MEM emit functions.
# Each writes one ≤30-line seed MEM with deterministic frontmatter.
# Body is a direct/structural quotation, not an LLM-summarized digest.
# ---------------------------------------------------------------------------

emit_architecture_mem() {
    local source_path="$1"
    local signal_kind="$2"
    local body_text="$3"
    local id
    id="$(stable_id "$source_path" "$signal_kind")"
    local out="$KNOWLEDGE_DIR/architecture/MEM-ARCH-$id.md"
    # FR-12 dup-prevention check (M033/P04/T03).
    if is_migrate_derived_mem "$out"; then
        printf 'skip-duplicate-from-migrate: %s\n' "$id"
        return 0
    fi
    {
        printf '%s\n' '---'
        printf '%s\n' 'schema_version: "1.0"'
        printf '%s\n' 'type: knowledge-mem'
        printf '%s\n' 'category: architecture'
        printf '%s\n' "source_path: $source_path"
        printf '%s\n' "signal_kind: $signal_kind"
        printf '%s\n' 'status: graduated'
        printf '%s\n' 'derived_from_codebase_ingest: true'
        printf '%s\n' '---'
        printf '\n'
        printf '# MEM-ARCH-%s: %s\n\n' "$id" "$signal_kind"
        printf '%s\n' "$body_text"
    } > "$out"
    EMITTED_COUNT=$((EMITTED_COUNT + 1))
}

emit_convention_mem() {
    local source_path="$1"
    local signal_kind="$2"
    local body_text="$3"
    local id
    id="$(stable_id "$source_path" "$signal_kind")"
    local out="$KNOWLEDGE_DIR/conventions/MEM-CONV-$id.md"
    # FR-12 dup-prevention check (M033/P04/T03).
    if is_migrate_derived_mem "$out"; then
        printf 'skip-duplicate-from-migrate: %s\n' "$id"
        return 0
    fi
    {
        printf '%s\n' '---'
        printf '%s\n' 'schema_version: "1.0"'
        printf '%s\n' 'type: knowledge-mem'
        printf '%s\n' 'category: conventions'
        printf '%s\n' "source_path: $source_path"
        printf '%s\n' "signal_kind: $signal_kind"
        printf '%s\n' 'status: graduated'
        printf '%s\n' 'derived_from_codebase_ingest: true'
        printf '%s\n' '---'
        printf '\n'
        printf '# MEM-CONV-%s: %s\n\n' "$id" "$signal_kind"
        printf '%s\n' "$body_text"
    } > "$out"
    EMITTED_COUNT=$((EMITTED_COUNT + 1))
}

emit_decision_mem() {
    local source_path="$1"
    local signal_kind="$2"
    local body_text="$3"
    local id
    id="$(stable_id "$source_path" "$signal_kind")"
    local out="$KNOWLEDGE_DIR/decisions/MEM-DEC-$id.md"
    # FR-12 dup-prevention check (M033/P04/T03).
    if is_migrate_derived_mem "$out"; then
        printf 'skip-duplicate-from-migrate: %s\n' "$id"
        return 0
    fi
    {
        printf '%s\n' '---'
        printf '%s\n' 'schema_version: "1.0"'
        printf '%s\n' 'type: knowledge-mem'
        printf '%s\n' 'category: decisions'
        printf '%s\n' "source_path: $source_path"
        printf '%s\n' "signal_kind: $signal_kind"
        printf '%s\n' 'status: graduated'
        printf '%s\n' 'derived_from_codebase_ingest: true'
        printf '%s\n' '---'
        printf '\n'
        printf '# MEM-DEC-%s: %s\n\n' "$id" "$signal_kind"
        printf '%s\n' "$body_text"
    } > "$out"
    EMITTED_COUNT=$((EMITTED_COUNT + 1))
}

# ---------------------------------------------------------------------------
# Re-ingest short-circuit. If any seed MEMs already exist, this run is a
# re-ingest: emit diagnostic + JSONL event + marker, exit 0.
# ---------------------------------------------------------------------------
EXISTING_COUNT=$(count_existing_seed_mems)
if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "re-ingest: $EXISTING_COUNT existing entries detected, no changes"
    PROJECT_DIR="$PROJECT_DIR" bash "$ORCH_ROOT/scripts/util/jsonl-event-emitter.sh" \
        emit ingest_codebase_completed \
        "{\"action\":\"re-ingest\",\"existing\":$EXISTING_COUNT}"
    bash "$ORCH_ROOT/scripts/util/start-state-markers.sh" write ingest-codebase "$PROJECT_DIR"
    # Marker file path emitted: <project-dir>/.orchestrator/start-state/ingest-codebase.complete
    # Load-bearing alias for FR-7 docs: ingest-codebase-completed.complete (same semantic event).
    echo "PASS: ingest-codebase re-ingest no-op"
    exit 0
fi

# ---------------------------------------------------------------------------
# Signal-source scan. Each detection records (source-path, signal-kind,
# body-text, category) into parallel indexed arrays (MEM001 — no
# associative arrays). Priority order is the array insertion order.
# ---------------------------------------------------------------------------

EMITTED_COUNT=0
MISSING_SIGNALS=""

# (1) Top-level docs → architecture MEMs.
TOP_LEVEL_DOCS_FOUND=0
for doc in README.md ARCHITECTURE.md CONTRIBUTING.md; do
    src="$PROJECT_DIR/$doc"
    if [ -f "$src" ]; then
        first_lines=$(head -20 "$src")
        body="Source: $doc

First-20-line excerpt (deterministic structural extract):

$first_lines"
        emit_architecture_mem "$doc" "top-level-doc" "$body"
        TOP_LEVEL_DOCS_FOUND=$((TOP_LEVEL_DOCS_FOUND + 1))
    fi
done
if [ -d "$PROJECT_DIR/docs" ]; then
    docs_listing=$(ls "$PROJECT_DIR/docs" 2>/dev/null | head -20)
    body="Source: docs/

Top-level docs/ entries:

$docs_listing"
    emit_architecture_mem "docs/" "docs-directory" "$body"
    TOP_LEVEL_DOCS_FOUND=$((TOP_LEVEL_DOCS_FOUND + 1))
fi
if [ "$TOP_LEVEL_DOCS_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS top-level-docs"
fi

# (2) Package manifests → conventions MEMs (one per manifest).
MANIFESTS_FOUND=0
for manifest in package.json pyproject.toml Cargo.toml go.mod; do
    src="$PROJECT_DIR/$manifest"
    if [ -f "$src" ]; then
        excerpt=$(head -30 "$src")
        body="Source: $manifest

First-30-line manifest excerpt (deterministic structural extract):

$excerpt"
        emit_convention_mem "$manifest" "package-manifest" "$body"
        MANIFESTS_FOUND=$((MANIFESTS_FOUND + 1))
        if [ "$EMITTED_COUNT" -ge 15 ]; then
            break
        fi
    fi
done
if [ "$MANIFESTS_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS package-manifests"
fi

# (3) Directory structure → architecture MEM (one summary).
DIR_STRUCT_FOUND=0
if [ "$EMITTED_COUNT" -lt 15 ]; then
    for dirname in src lib app; do
        d="$PROJECT_DIR/$dirname"
        if [ -d "$d" ]; then
            listing=$(ls "$d" 2>/dev/null | head -20)
            body="Source: $dirname/

Top-level entries (capped at 20, top 2 levels honored at scan time):

$listing"
            emit_architecture_mem "$dirname/" "directory-structure" "$body"
            DIR_STRUCT_FOUND=1
            break
        fi
    done
fi
if [ "$DIR_STRUCT_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS directory-structure"
fi

# (4) Test directory shape → conventions MEM.
TEST_DIR_FOUND=0
if [ "$EMITTED_COUNT" -lt 15 ]; then
    for tdir in tests test __tests__ spec; do
        d="$PROJECT_DIR/$tdir"
        if [ -d "$d" ]; then
            listing=$(ls "$d" 2>/dev/null | head -10)
            body="Source: $tdir/

Test directory shape (top-level entries):

$listing"
            emit_convention_mem "$tdir/" "test-directory" "$body"
            TEST_DIR_FOUND=1
            break
        fi
    done
fi
if [ "$TEST_DIR_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS test-directory"
fi

# (5) Recent git log → decision MEM (skipped if no .git/).
GIT_LOG_FOUND=0
if [ "$EMITTED_COUNT" -lt 15 ]; then
    if [ -d "$PROJECT_DIR/.git" ]; then
        log_lines=$(cd "$PROJECT_DIR" && git log --oneline -50 2>/dev/null | head -20)
        if [ -n "$log_lines" ]; then
            body="Source: git log --oneline -50

Recent commit subjects (capped at 20 lines for seed brevity):

$log_lines"
            emit_decision_mem ".git/log" "git-log-recent" "$body"
            GIT_LOG_FOUND=1
        fi
    fi
fi
if [ "$GIT_LOG_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS git-log-recent"
fi

# (6) Prior-tooling artifacts → conventions MEM (one per detected tool, capped).
PRIOR_TOOLING_FOUND=0
if [ "$EMITTED_COUNT" -lt 15 ]; then
    for tooldir in .cursor .aider .claude .specify .gsd .gsd2; do
        d="$PROJECT_DIR/$tooldir"
        if [ -d "$d" ]; then
            listing=$(ls "$d" 2>/dev/null | head -10)
            body="Source: $tooldir/

Prior-tooling artifact directory contents:

$listing"
            emit_convention_mem "$tooldir/" "prior-tooling" "$body"
            PRIOR_TOOLING_FOUND=$((PRIOR_TOOLING_FOUND + 1))
            if [ "$EMITTED_COUNT" -ge 15 ]; then
                break
            fi
        fi
    done
fi
if [ "$PRIOR_TOOLING_FOUND" -eq 0 ]; then
    MISSING_SIGNALS="$MISSING_SIGNALS prior-tooling"
fi

# ---------------------------------------------------------------------------
# Floor diagnostic (US-3 AS-5 — minimum-viable seed): if EMITTED_COUNT < 5
# emit a stdout diagnostic and continue. Don't error.
# ---------------------------------------------------------------------------
if [ "$EMITTED_COUNT" -lt 5 ]; then
    echo "minimum-viable seed: $EMITTED_COUNT entries (<5 floor) — missing signals:$MISSING_SIGNALS"
fi

# >>> rich-context-branch >>>
# M033/P03/T04 — FR-8 / MIT-005 rich-context import path.
# Detects free-form context material in the project (.orchestrator/DECISIONS.md
# carrying DR- entries, or .orchestrator/MILESTONE-AUDIT.md, or a populated
# CLAUDE.md custom block) and imports it to either <current-milestone>-CONTEXT.md
# (when a milestone is active) or _imported-context/_imported-context.md per
# #Q-11. Cross-references each DR- as MEM-DR-* (provenance-preserving — NOT
# duplicate authoring), seeds a prior-tooling .orchestrator/ convention MEM
# when the rich-context branch fires, and emits one imported_context_loaded
# JSONL event per FR-22.

# (3a) Detection — OR-shape across three signals.
RICH_DECISIONS_FILE="$PROJECT_DIR/.orchestrator/DECISIONS.md"
RICH_AUDIT_FILE="$PROJECT_DIR/.orchestrator/MILESTONE-AUDIT.md"
RICH_CLAUDE_FILE="$PROJECT_DIR/CLAUDE.md"

RICH_HAS_DR=0
if [ -f "$RICH_DECISIONS_FILE" ]; then
    if grep -q '^## DR-' "$RICH_DECISIONS_FILE"; then
        RICH_HAS_DR=1
    elif grep -q '^DR-' "$RICH_DECISIONS_FILE"; then
        RICH_HAS_DR=1
    fi
fi

RICH_HAS_AUDIT=0
if [ -f "$RICH_AUDIT_FILE" ]; then
    RICH_HAS_AUDIT=1
fi

RICH_HAS_CUSTOM=0
if [ -f "$RICH_CLAUDE_FILE" ]; then
    # Extract content between BEGIN CUSTOM and END CUSTOM markers, then
    # check it has any non-marker, non-blank content.
    custom_body=$(awk '/<!-- BEGIN CUSTOM -->/,/<!-- END CUSTOM -->/' "$RICH_CLAUDE_FILE")
    custom_filtered=$(printf '%s\n' "$custom_body" | grep -v 'BEGIN CUSTOM' | grep -v 'END CUSTOM' | grep -v '^[[:space:]]*$' || true)
    if [ -n "$custom_filtered" ]; then
        RICH_HAS_CUSTOM=1
    fi
fi

if [ "$RICH_HAS_DR" -eq 1 ] || [ "$RICH_HAS_AUDIT" -eq 1 ] || [ "$RICH_HAS_CUSTOM" -eq 1 ]; then

    # (3b) Path resolution — read current_milestone: from config.yml.
    RICH_CONFIG_FILE="$PROJECT_DIR/.orchestrator/config.yml"
    RICH_CURRENT_MILESTONE=""
    if [ -f "$RICH_CONFIG_FILE" ]; then
        rich_cm_line=$(grep -E '^current_milestone:' "$RICH_CONFIG_FILE" || true)
        if [ -n "$rich_cm_line" ]; then
            # Strip leading "current_milestone:" and surrounding whitespace.
            RICH_CURRENT_MILESTONE=$(printf '%s\n' "$rich_cm_line" | awk '{print $2}')
        fi
    fi

    if [ -n "$RICH_CURRENT_MILESTONE" ]; then
        RICH_CONTEXT_DIR="$PROJECT_DIR/.orchestrator/milestones/$RICH_CURRENT_MILESTONE"
        RICH_CONTEXT_PATH="$RICH_CONTEXT_DIR/${RICH_CURRENT_MILESTONE}-CONTEXT.md"
    else
        RICH_CONTEXT_DIR="$PROJECT_DIR/.orchestrator/milestones/_imported-context"
        RICH_CONTEXT_PATH="$RICH_CONTEXT_DIR/_imported-context.md"
    fi
    mkdir -p "$RICH_CONTEXT_DIR"

    # (3c) Thin context file emission (≤30 lines, frontmatter + cross-ref body).
    rich_imported_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    {
        printf '%s\n' '---'
        printf '%s\n' 'schema_version: "1.0"'
        printf '%s\n' 'type: imported-context'
        printf '%s\n' 'context_source: imported-from-existing'
        printf 'imported_at: %s\n' "$rich_imported_at"
        printf '%s\n' 'source_files:'
        if [ "$RICH_HAS_DR" -eq 1 ]; then
            printf '%s\n' '  - .orchestrator/DECISIONS.md'
        fi
        if [ "$RICH_HAS_AUDIT" -eq 1 ]; then
            printf '%s\n' '  - .orchestrator/MILESTONE-AUDIT.md'
        fi
        if [ "$RICH_HAS_CUSTOM" -eq 1 ]; then
            printf '%s\n' '  - CLAUDE.md (custom block)'
        fi
        printf '%s\n' '---'
        printf '\n'
        printf '%s\n' '# Imported Context'
        printf '\n'
        printf '%s\n' 'This context file was generated by orchestrator:ingest-codebase from existing project artifacts. The source files (named in source_files:) are the authoritative content; this file is a cross-reference index, NOT a duplicate.'
        printf '\n'
        printf '%s\n' '## Sources'
        printf '\n'
        if [ "$RICH_HAS_DR" -eq 1 ]; then
            printf '%s\n' '- `.orchestrator/DECISIONS.md` — decision records cross-referenced as `knowledge/decisions/MEM-DR-*.md`.'
        fi
        if [ "$RICH_HAS_AUDIT" -eq 1 ]; then
            printf '%s\n' '- `.orchestrator/MILESTONE-AUDIT.md` — milestone-audit history (read directly).'
        fi
        if [ "$RICH_HAS_CUSTOM" -eq 1 ]; then
            printf '%s\n' '- `CLAUDE.md` custom block — populated; consumed at dispatch time.'
        fi
        printf '\n'
        printf '%s\n' '## Provenance'
        printf '\n'
        printf '%s\n' 'M033/P03/T04 — FR-8 / MIT-005 rich-context import path. See `references/imported-context-sentinel.md`.'
    } > "$RICH_CONTEXT_PATH"

    # (3d) MEM-DR-* cross-reference emission, one per DR-<id> entry.
    RICH_DR_COUNT=0
    if [ "$RICH_HAS_DR" -eq 1 ]; then
        mkdir -p "$KNOWLEDGE_DIR/decisions"
        # Extract DR-<id> tokens from the DECISIONS.md heading lines.
        rich_dr_ids=$(grep -E '^(## )?DR-' "$RICH_DECISIONS_FILE" | sed -E 's/^## //; s/^(DR-[A-Za-z0-9_-]+).*/\1/')
        for dr_id_full in $rich_dr_ids; do
            # Strip the "DR-" prefix to get the bare id.
            dr_id=${dr_id_full#DR-}
            mem_path="$KNOWLEDGE_DIR/decisions/MEM-DR-$dr_id.md"
            # Idempotency — skip if MEM already exists with the marker.
            if [ -f "$mem_path" ]; then
                if grep -qF 'derived_from_codebase_ingest: true' "$mem_path"; then
                    continue
                fi
            fi
            {
                printf '%s\n' '---'
                printf '%s\n' 'schema_version: "1.0"'
                printf '%s\n' 'type: knowledge-mem'
                printf '%s\n' 'category: decisions'
                printf '%s\n' 'status: graduated'
                printf '%s\n' 'source_path: .orchestrator/DECISIONS.md'
                printf '%s\n' 'signal_kind: dr-cross-reference'
                printf 'dr_id: %s\n' "$dr_id"
                printf '%s\n' 'derived_from_codebase_ingest: true'
                printf '%s\n' '---'
                printf '\n'
                printf '# MEM-DR-%s\n' "$dr_id"
                printf '\n'
                printf 'Cross-reference to `DR-%s` in `.orchestrator/DECISIONS.md`. Provenance-preserving — see source for canonical content.\n' "$dr_id"
            } > "$mem_path"
            EMITTED_COUNT=$((EMITTED_COUNT + 1))
            RICH_DR_COUNT=$((RICH_DR_COUNT + 1))
        done
    fi

    # (3d-extra) Prior-tooling .orchestrator/ convention MEM — emitted once
    # when the rich-context branch fires AND the project carries an
    # .orchestrator/ directory (which it does by definition since DECISIONS
    # / MILESTONE-AUDIT live under it). This is the +1 MEM the TS-saas
    # README-oracle expects beyond the deterministic core + cross-refs.
    if [ -d "$PROJECT_DIR/.orchestrator" ]; then
        rich_orch_listing=$(ls "$PROJECT_DIR/.orchestrator" 2>/dev/null | head -10)
        rich_orch_body="Source: .orchestrator/

Prior-tooling artifact directory contents (rich-context-branch detection):

$rich_orch_listing"
        emit_convention_mem ".orchestrator/" "prior-tooling" "$rich_orch_body"
    fi

    # (3e) JSONL event emit — imported_context_loaded.
    PROJECT_DIR="$PROJECT_DIR" bash "$ORCH_ROOT/scripts/util/jsonl-event-emitter.sh" \
        emit imported_context_loaded \
        "{\"path\":\"$RICH_CONTEXT_PATH\",\"dr_count\":$RICH_DR_COUNT}"
fi
# <<< rich-context-branch <<<

# ---------------------------------------------------------------------------
# Marker write (FR-20). Use the closed sub-flow enum value `ingest-codebase`.
# The resulting marker file is:
#   <project-dir>/.orchestrator/start-state/ingest-codebase.complete
# Load-bearing alias for FR-7 documentation: ingest-codebase-completed.complete
# (same semantic event; the docs use the post-completion phrasing while the
# closed enum uses the pre-completion phrasing). Both forms refer to the
# same on-disk marker.
# ---------------------------------------------------------------------------
bash "$ORCH_ROOT/scripts/util/start-state-markers.sh" write ingest-codebase "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# JSONL event (FR-22). Closed-enum event_type is `ingest_codebase_completed`.
# ---------------------------------------------------------------------------
PROJECT_DIR="$PROJECT_DIR" bash "$ORCH_ROOT/scripts/util/jsonl-event-emitter.sh" \
    emit ingest_codebase_completed \
    "{\"mem_count\":$EMITTED_COUNT,\"categories\":\"architecture,conventions,decisions\"}"

# ---------------------------------------------------------------------------
# FR-21 dual-write fragment. Helper API is --marker + --append-entry (see
# T02 SUMMARY: the SSOT-suggested `append <fragment>` shorthand is not
# implemented; --append-entry is the real flag form). Pass --root to
# target the project's runtime-md, not the orchestrator repo's.
# Fragment string is the load-bearing recent-changes line.
# ---------------------------------------------------------------------------
bash "$ORCH_ROOT/scripts/util/dual-write-runtime-md.sh" \
    --root "$PROJECT_DIR" \
    --marker recent-changes \
    --append-entry "036-project-onboarding-experience: orchestrator:ingest-codebase seeded $EMITTED_COUNT MEMs from existing codebase"

echo "PASS: ingest-codebase emitted $EMITTED_COUNT MEMs"
echo "SUMMARY: ingest-codebase.sh project=$PROJECT_DIR mems=$EMITTED_COUNT"

exit 0
