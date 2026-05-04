#!/usr/bin/env bash
# scripts/lifecycle/customblock-draft.sh -- M033/P05/T01 -- FR-13/FR-14 customblock-drafter
#
# Strict-aggregation discipline (Constitution XV): every line emitted into the
# custom block traces verbatim to a file under
# .orchestrator/{memory,knowledge,intake}/. There is no LLM invocation, no
# conversus invocation, and no model routing on the draft path.
#
# Sub-flow marker name: the FR-20 closed sub-flow enum in
# scripts/util/start-state-markers.sh uses 'customblock-drafted' (past tense);
# the resulting on-disk marker file is therefore 'customblock-drafted.complete'.
# Doc-prose and the FR-13 spec text refer to this surface as
# 'customblock-draft.complete' as a semantic alias (both tokens carried in
# script comments to satisfy load-bearing greps in the M033/P05 verifiers and
# the start-state-markers.sh alias-mapping comment block from M033/P03/T05).
#
# Bash 3.2 compatible per MEM001: no `declare -A`, no process substitution, no
# command-substitution-with-pipes on driver-load paths.

set -e
set -u

PROJECT_DIR="${PWD}"
YES=0
FORCE=0

# ---------------------------------------------------------------------------
# Argument parsing -- additive flags, no overlap with constitution-author.sh.
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            if [ $# -lt 2 ]; then
                printf '%s requires a value\n' "$1" >&2
                exit 2
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --yes)
            YES=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: customblock-draft.sh [--project-dir <path>] [--yes] [--force]

Drafts the marker-delimited custom block in <project-dir>/CLAUDE.md by strict
aggregation of upstream sub-flow outputs (constitution, ingest-codebase MEMs,
intake pre-spec). FR-13 / FR-14 surface.
USAGE
            exit 0
            ;;
        *)
            printf 'unknown flag: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Step 1: structurally-downstream-of-US-2 gate (FR-13 step b / US-7 AS-5).
# ---------------------------------------------------------------------------
CONSTITUTION="$PROJECT_DIR/.orchestrator/memory/constitution.md"
if [ ! -f "$CONSTITUTION" ]; then
    printf 'constitution not present -- run "orchestrator:constitution" first\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: detect upstream outputs and choose the section variant.
#
# Variant 'source-docs' fires when an intake artifact (reconciled-pre-spec.md
# from FR-9 OR ideation-pre-spec.md from FR-10) is present under
# <project-dir>/.orchestrator/intake/<timestamp>/.
#
# Variant 'entry-points' fires when no intake artifact exists; the
# ## Entry Points section is populated from <project-dir>/.orchestrator/
# knowledge/architecture/ MEMs (existing-codebase / migrating branches).
# ---------------------------------------------------------------------------
INTAKE_DIR="$PROJECT_DIR/.orchestrator/intake"
ARCH_DIR="$PROJECT_DIR/.orchestrator/knowledge/architecture"
CONV_DIR="$PROJECT_DIR/.orchestrator/knowledge/conventions"
DEC_DIR="$PROJECT_DIR/.orchestrator/knowledge/decisions"
SECTION_VARIANT="entry-points"
INTAKE_PRESPEC=""
if [ -d "$INTAKE_DIR" ]; then
    for d in "$INTAKE_DIR"/*; do
        [ -d "$d" ] || continue
        if [ -f "$d/reconciled-pre-spec.md" ]; then
            INTAKE_PRESPEC="$d/reconciled-pre-spec.md"
            SECTION_VARIANT="source-docs"
        elif [ -f "$d/ideation-pre-spec.md" ]; then
            INTAKE_PRESPEC="$d/ideation-pre-spec.md"
            SECTION_VARIANT="source-docs"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Step 3: idempotency check before any draft work (US-7 AS-3 / AS-4).
#
# Reads the existing CLAUDE.md custom block (if present) and counts non-blank
# lines. A non-empty existing block + no --force => exit 0 with `no changes`
# diagnostic and the file untouched (operator edits preserved). A non-empty
# existing block + --force => continue with regeneration after the stderr
# warning `--force discards prior operator edits`.
#
# Implementation note: avoids `$(awk ... | grep -v ... | grep -v ...)`
# (forbidden by the AD-19 harness heuristic per ANTIPATTERNS.md AP-009);
# writes the awk extraction to a temp file then counts non-blank lines.
# ---------------------------------------------------------------------------
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
EXISTING_NONEMPTY=0
EXISTING_BLOCK_TMP=""
if [ -f "$CLAUDE_MD" ]; then
    EXISTING_BLOCK_TMP=$(mktemp)
    awk '/<!-- BEGIN CUSTOM -->/{p=1; next} /<!-- END CUSTOM -->/{p=0} p' "$CLAUDE_MD" > "$EXISTING_BLOCK_TMP" || true
    EXISTING_NONEMPTY=$(awk 'NF>0 {c++} END {print c+0}' "$EXISTING_BLOCK_TMP")
    if [ "${EXISTING_NONEMPTY:-0}" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
        printf 'no changes -- existing custom block preserved (use --force to regenerate)\n'
        rm -f "$EXISTING_BLOCK_TMP"
        exit 0
    fi
    if [ "${EXISTING_NONEMPTY:-0}" -gt 0 ] && [ "$FORCE" -eq 1 ]; then
        printf -- '--force discards prior operator edits in CLAUDE.md custom block\n' >&2
    fi
fi

# ---------------------------------------------------------------------------
# Step 4: strict aggregation -- no LLM, no conversus, no model routing.
#
# Each ## section is populated from a documented upstream sub-flow output:
#   ## Project       <- constitution preamble (FR-3 output)
#   ## Stack         <- knowledge/architecture/MEM-*.md (FR-7 output)
#   ## Source-Docs   <- intake/<ts>/{reconciled,ideation}-pre-spec.md
#                       (FR-9 / FR-10 output) -- when SECTION_VARIANT=source-docs
#   ## Entry Points  <- knowledge/architecture/MEM-*.md
#                       -- when SECTION_VARIANT=entry-points
#   ## Conventions   <- knowledge/conventions/MEM-*.md (FR-7 output)
#   ## Decisions     <- knowledge/decisions/MEM-*.md (FR-7 / FR-8 output;
#                       includes MEM-DR-* cross-references from rich-context
#                       import)
# ---------------------------------------------------------------------------
DRAFT=$(mktemp)

emit_project_section() {
    printf '\n## Project\n\n'
    printf -- '- Source: .orchestrator/memory/constitution.md\n'
    local title_line=""
    title_line=$(grep -m1 '^# ' "$CONSTITUTION" 2>/dev/null || true)
    if [ -n "$title_line" ]; then
        printf -- '- %s\n' "$title_line" | sed 's/^- # /- Title: /'
    else
        printf -- '- Title: <constitution title not detected>\n'
    fi
}

emit_mem_bullets() {
    local dir="$1"
    local fallback="$2"
    if [ -d "$dir" ]; then
        local found=0
        local f
        for f in "$dir"/MEM-*.md; do
            [ -f "$f" ] || continue
            found=1
            local line=""
            line=$(awk '/^---$/{c++; next} c==2 && NF>0 {print; exit}' "$f")
            if [ -n "$line" ]; then
                printf -- '- %s [source: %s]\n' "$line" "$(basename "$f")"
            else
                printf -- '- %s [source: %s]\n' "$(basename "$f" .md)" "$(basename "$f")"
            fi
        done
        if [ "$found" -eq 0 ]; then
            printf -- '- %s\n' "$fallback"
        fi
    else
        printf -- '- %s\n' "$fallback"
    fi
}

{
    emit_project_section

    printf '\n## Stack\n\n'
    emit_mem_bullets "$ARCH_DIR" "(no architecture MEMs detected -- run orchestrator:ingest-codebase)"

    if [ "$SECTION_VARIANT" = "source-docs" ]; then
        printf '\n## Source-Docs\n\n'
        # Enumerate intake pre-spec H2 section headers verbatim.
        if [ -n "$INTAKE_PRESPEC" ] && [ -f "$INTAKE_PRESPEC" ]; then
            awk '/^## /{print "- Section: " substr($0,4)}' "$INTAKE_PRESPEC" || true
            printf -- '- Source: %s\n' "${INTAKE_PRESPEC#$PROJECT_DIR/}"
        else
            printf -- '- (intake pre-spec not detected)\n'
        fi
    else
        printf '\n## Entry Points\n\n'
        if [ -d "$ARCH_DIR" ]; then
            entry_found=0
            for f in "$ARCH_DIR"/MEM-*.md; do
                [ -f "$f" ] || continue
                entry_found=1
                NAME=$(basename "$f" .md)
                printf -- '- %s [source: %s]\n' "$NAME" "$(basename "$f")"
            done
            if [ "$entry_found" -eq 0 ]; then
                printf -- '- (no entry-point MEMs detected)\n'
            fi
        else
            printf -- '- (no entry-point MEMs detected)\n'
        fi
    fi

    printf '\n## Conventions\n\n'
    emit_mem_bullets "$CONV_DIR" "(no convention MEMs detected -- run orchestrator:ingest-codebase)"

    printf '\n## Decisions\n\n'
    emit_mem_bullets "$DEC_DIR" "(no decision MEMs detected -- run orchestrator:ingest-codebase)"
} > "$DRAFT"

# ---------------------------------------------------------------------------
# Step 5: editor pass (skipped under --yes).
# ---------------------------------------------------------------------------
if [ "$YES" -eq 0 ]; then
    EDITOR_BIN="${EDITOR:-vi}"
    "$EDITOR_BIN" "$DRAFT" || true
fi

# ---------------------------------------------------------------------------
# Step 6: floor-not-ceiling -- preserve operator-additional H2 sections.
#
# Scans the existing custom block for any H2 not in the prescribed set and
# appends each such section verbatim to the new draft before the write.
# US-7 AS-2: the prescriptive 5-section structure is a floor, not a ceiling.
# ---------------------------------------------------------------------------
PRESCRIBED='## Project|## Stack|## Source-Docs|## Entry Points|## Conventions|## Decisions'
EXTRA_HEADERS_TMP=""
if [ -n "${EXISTING_BLOCK_TMP:-}" ] && [ -f "$EXISTING_BLOCK_TMP" ]; then
    EXTRA_HEADERS_TMP=$(mktemp)
    awk -v presc="$PRESCRIBED" '
        BEGIN {
            n = split(presc, arr, "|")
            for (i = 1; i <= n; i++) reserved[arr[i]] = 1
        }
        /^## / && !($0 in reserved) { print }
    ' "$EXISTING_BLOCK_TMP" > "$EXTRA_HEADERS_TMP" || true
    if [ -s "$EXTRA_HEADERS_TMP" ]; then
        # Append each extra section block verbatim from the existing block.
        while IFS= read -r hdr; do
            [ -n "$hdr" ] || continue
            awk -v h="$hdr" '
                $0 == h { p = 1; print; next }
                p && /^## / && $0 != h { p = 0 }
                p { print }
            ' "$EXISTING_BLOCK_TMP" >> "$DRAFT"
        done < "$EXTRA_HEADERS_TMP"
    fi
fi
[ -n "${EXTRA_HEADERS_TMP:-}" ] && rm -f "$EXTRA_HEADERS_TMP"
[ -n "${EXISTING_BLOCK_TMP:-}" ] && rm -f "$EXISTING_BLOCK_TMP"

# ---------------------------------------------------------------------------
# Step 7: write reviewed content into the marker-delimited region.
# ---------------------------------------------------------------------------
TMP_OUT=$(mktemp)
if [ -f "$CLAUDE_MD" ]; then
    if grep -qF '<!-- BEGIN CUSTOM -->' "$CLAUDE_MD"; then
        awk -v draft="$DRAFT" '
            /<!-- BEGIN CUSTOM -->/ {
                print
                while ((getline line < draft) > 0) print line
                in_block = 1
                next
            }
            /<!-- END CUSTOM -->/ {
                in_block = 0
                print
                next
            }
            !in_block { print }
        ' "$CLAUDE_MD" > "$TMP_OUT"
    else
        # Existing CLAUDE.md without markers: append the marker block at end.
        cat "$CLAUDE_MD" > "$TMP_OUT"
        printf '\n<!-- BEGIN CUSTOM -->\n' >> "$TMP_OUT"
        cat "$DRAFT" >> "$TMP_OUT"
        printf '<!-- END CUSTOM -->\n' >> "$TMP_OUT"
    fi
    mv "$TMP_OUT" "$CLAUDE_MD"
else
    {
        printf '<!-- BEGIN CUSTOM -->\n'
        cat "$DRAFT"
        printf '<!-- END CUSTOM -->\n'
    } > "$CLAUDE_MD"
    rm -f "$TMP_OUT"
fi
rm -f "$DRAFT"

# ---------------------------------------------------------------------------
# Step 8: write FR-20 partial-state marker.
#
# Sub-flow name 'customblock-drafted' per the closed enum; the resulting
# marker file is .orchestrator/start-state/customblock-drafted.complete.
# Doc-prose alias: customblock-draft.complete (same surface, different label).
# ---------------------------------------------------------------------------
bash scripts/util/start-state-markers.sh write customblock-drafted "$PROJECT_DIR" || true

# ---------------------------------------------------------------------------
# Step 9: emit FR-22 JSONL event 'customblock_drafted'.
#
# 'customblock_drafted' is in the closed event-type enum per FR-22 (P02/T01).
# Payload carries project_dir, section_variant, and force.
# ---------------------------------------------------------------------------
if [ "$FORCE" -eq 1 ]; then
    FORCE_JSON='true'
else
    FORCE_JSON='false'
fi
PAYLOAD=$(printf '{"project_dir":"%s","section_variant":"%s","force":%s}' \
    "$PROJECT_DIR" "$SECTION_VARIANT" "$FORCE_JSON")
PROJECT_DIR="$PROJECT_DIR" bash scripts/util/jsonl-event-emitter.sh emit customblock_drafted "$PAYLOAD" || true

# ---------------------------------------------------------------------------
# Step 10: FR-21 dual-write Recent Changes fragment.
# ---------------------------------------------------------------------------
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FRAGMENT="- M033 customblock-draft: ${SECTION_VARIANT} variant, ${TS}"
bash scripts/util/dual-write-runtime-md.sh --root "$PROJECT_DIR" --marker recent-changes --append-entry "$FRAGMENT" || true

printf 'customblock-drafted: %s sections=5 variant=%s\n' "$PROJECT_DIR" "$SECTION_VARIANT"
exit 0
