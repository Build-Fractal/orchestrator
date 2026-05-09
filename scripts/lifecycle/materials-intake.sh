#!/usr/bin/env bash
# scripts/lifecycle/materials-intake.sh
#
# FR-9 materials-intake driver for M033 (Project Onboarding Experience).
# Spec: specs/036-project-onboarding-experience/spec.md.
#
# Takes heterogeneous source materials in PBJ-shape (Product Brief,
# MVP Plan, Decision Register, Milestone Audit, optional Handoff JSON),
# labels each one against the closed labeling enum, runs deterministic
# CON-4 drift detection across the labeled set, reconciles via terminal-
# interactive UX (or file-based UX above M033_CONFLICT_FILE_THRESHOLD),
# and emits a byte-deterministic reconciled pre-spec consumed verbatim
# by orchestrator:specify --description.
#
# Architectural invariants:
#   - CON-4 deterministic-not-LLM: drift detection uses grep / awk / sed
#     regex only. No model invocation in the extraction path. The shape
#     verifier asserts no model-routing tokens appear in the driver.
#   - CON-5 sequential-never-batched: labeling and reconciliation loops
#     invoke ask_one once per item, awaiting the resolved answer before
#     proceeding to the next.
#   - Byte-deterministic reconciled pre-spec: same fixture + same
#     answers -> byte-identical body. Directory-name timestamp is the
#     only non-deterministic element; not embedded in the body.
#     M033_INTAKE_TIMESTAMP env override pins the directory for SC-4.
#
# Bash 3.2 compatibility (MEM001):
#   - parallel indexed arrays only (no associative arrays).
#   - no process substitution.
#   - no command-substitution with embedded pipes.
#
# Test-only escape valves (documented for SC-4 byte-determinism):
#   - M033_INTAKE_TIMESTAMP: pin the intake directory timestamp.
#   - M033_CONFLICT_FILE_THRESHOLD: integer threshold for terminal vs
#     file-based reconciliation. Default 5 per #Q-6.
#
# Spec refs: FR-9, CON-4, CON-5, FR-20, FR-21, FR-22, SC-4, US-4, #Q-6.

set -e
set -u
set -o pipefail

# ---------------------------------------------------------------------------
# Closed-enum SSOT blocks (fenced for grep parity)
# ---------------------------------------------------------------------------

# >>> material-extensions >>>
# .md
# .pdf
# .json
# .txt
# <<< material-extensions <<<

# >>> labeling-enum >>>
# primary
# supplementary
# decision-history
# out-of-scope
# <<< labeling-enum <<<

# >>> drift-categories >>>
# id-misalignment
# scheme-contradiction
# orphan-reference
# <<< drift-categories <<<

# >>> resolution-enum >>>
# accept-primary
# accept-supplementary
# manual-edit
# defer
# <<< resolution-enum <<<

MATERIAL_EXTS='md pdf json txt'
LABEL_ENUM='primary supplementary decision-history out-of-scope'
DRIFT_CATS='id-misalignment scheme-contradiction orphan-reference'

# ---------------------------------------------------------------------------
# Resolve script directory for sourcing grilling-shell.sh
# ---------------------------------------------------------------------------

SCRIPT_DIR=""
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Source the FR-17 grilling-shell module for ask_one. The module itself
# avoids top-level set -e -u -o pipefail so sourcing is safe.
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lifecycle/grilling-shell.sh"

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------

PROJECT_DIR=""
YES_FLAG=0
RESOLVE_PATH=""

usage() {
    echo "usage: materials-intake.sh --project-dir <path> [--yes] [--resolve <conflicts.md>]" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir)
            shift
            PROJECT_DIR="${1:-}"
            ;;
        --yes)
            YES_FLAG=1
            ;;
        --resolve)
            shift
            RESOLVE_PATH="${1:-}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown flag: $1" >&2
            usage
            exit 2
            ;;
    esac
    shift
done

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "project-dir does not exist: $PROJECT_DIR" >&2
    exit 2
fi

# Resolve to absolute path.
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
export PROJECT_DIR

# Threshold (default 5 per #Q-6).
THRESHOLD="${M033_CONFLICT_FILE_THRESHOLD:-5}"
case "$THRESHOLD" in
    ''|*[!0-9]*)
        echo "M033_CONFLICT_FILE_THRESHOLD must be an integer: $THRESHOLD" >&2
        exit 2
        ;;
esac

# Resolve mode: --resolve <path-to-conflicts.md> reuses the parent
# intake directory from the original detection run rather than starting
# a new timestamped intake. Re-detection is intentionally skipped — the
# operator-supplied conflicts.md IS the authoritative input on this pass.
if [ -n "$RESOLVE_PATH" ]; then
    if [ ! -f "$RESOLVE_PATH" ]; then
        echo "--resolve target not found: $RESOLVE_PATH" >&2
        exit 2
    fi
    # Resolve to absolute then take its directory as the intake dir.
    RESOLVE_PATH=$(cd "$(dirname "$RESOLVE_PATH")" && pwd)/$(basename "$RESOLVE_PATH")
    INTAKE_DIR=$(dirname "$RESOLVE_PATH")
    INTAKE_TIMESTAMP=$(basename "$INTAKE_DIR")
else
    # Timestamp for the intake directory. M033_INTAKE_TIMESTAMP overrides
    # for SC-4 byte-determinism.
    INTAKE_TIMESTAMP="${M033_INTAKE_TIMESTAMP:-}"
    if [ -z "$INTAKE_TIMESTAMP" ]; then
        INTAKE_TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
    fi

    INTAKE_DIR="$PROJECT_DIR/.orchestrator/intake/$INTAKE_TIMESTAMP"
    mkdir -p "$INTAKE_DIR"
fi

ACCUMULATOR="$INTAKE_DIR/accumulator.txt"
LABELS_FILE="$INTAKE_DIR/labels.txt"
CONFLICTS_ACC="$INTAKE_DIR/conflicts-acc.txt"
RESOLUTIONS_FILE="$INTAKE_DIR/resolutions.txt"
PRESPEC_PATH="$INTAKE_DIR/reconciled-pre-spec.md"
CONFLICTS_MD="$INTAKE_DIR/conflicts.md"

if [ -z "$RESOLVE_PATH" ]; then
    : > "$ACCUMULATOR"
    : > "$LABELS_FILE"
    : > "$CONFLICTS_ACC"
    : > "$RESOLUTIONS_FILE"
fi

# ---------------------------------------------------------------------------
# Helper: parse_resolve_md
# ---------------------------------------------------------------------------
#
# Parses an operator-edited conflicts.md and emits resolutions.txt rows
# in the same `<i>|<resolution>|<original-conflict-line>` shape that
# reconcile_terminal produces. Walks `## Conflict N` blocks and extracts
# the matching `- Detail:` and `- Resolution:` lines. Unrecognized
# resolutions fall back to accept-primary with a stderr diagnostic.
# ---------------------------------------------------------------------------
parse_resolve_md() {
    local md_path="$1"
    local out_file="$2"
    : > "$out_file"
    local current_idx=""
    local current_detail=""
    local current_resolution=""
    local line
    local IFSO="$IFS"
    IFS=$'\n'
    while IFS= read -r line; do
        case "$line" in
            '## Conflict '*)
                # Flush prior block before starting a new one.
                if [ -n "$current_idx" ]; then
                    case "$current_resolution" in
                        accept-primary|accept-supplementary|manual-edit|defer)
                            ;;
                        *)
                            echo "unrecognized resolution '$current_resolution' for conflict ${current_idx} - falling back to accept-primary" >&2
                            current_resolution="accept-primary"
                            ;;
                    esac
                    echo "${current_idx}|${current_resolution}|${current_detail}" >> "$out_file"
                fi
                current_idx=$(echo "$line" | sed -E 's/^## Conflict[[:space:]]+([0-9]+).*/\1/')
                current_detail=""
                current_resolution=""
                ;;
            '- Detail: '*)
                current_detail=$(echo "$line" | sed -E 's/^- Detail:[[:space:]]*//')
                ;;
            '- Resolution: '*)
                current_resolution=$(echo "$line" | sed -E 's/^- Resolution:[[:space:]]*//')
                ;;
        esac
    done < "$md_path"
    IFS="$IFSO"
    # Flush trailing block.
    if [ -n "$current_idx" ]; then
        case "$current_resolution" in
            accept-primary|accept-supplementary|manual-edit|defer)
                ;;
            *)
                echo "unrecognized resolution '$current_resolution' for conflict ${current_idx} - falling back to accept-primary" >&2
                current_resolution="accept-primary"
                ;;
        esac
        echo "${current_idx}|${current_resolution}|${current_detail}" >> "$out_file"
    fi
}

# ---------------------------------------------------------------------------
# Helper: enumerate_materials
# ---------------------------------------------------------------------------
#
# Iterates project-root files matching the closed extension SSOT. For
# .pdf, probes textutil (darwin) or pdftotext (linux) and surfaces a
# missing-binary diagnostic + skip if absent (NOT silent skip per the
# Edge Case). Excludes the README.md oracle from the PBJ fixture so the
# fixture itself is intake-safe.
# ---------------------------------------------------------------------------
enumerate_materials() {
    local root="$1"
    local out_file="$2"
    local ext
    local f
    : > "$out_file"
    for ext in $MATERIAL_EXTS; do
        for f in "$root"/*."$ext"; do
            if [ ! -f "$f" ]; then
                continue
            fi
            local base
            base=$(basename "$f")
            # Skip README oracles — they are ground-truth, not materials.
            case "$base" in
                README.md|readme.md|README*.md)
                    continue
                    ;;
            esac
            if [ "$ext" = "pdf" ]; then
                if ! command -v textutil >/dev/null 2>&1; then
                    if ! command -v pdftotext >/dev/null 2>&1; then
                        echo "missing-binary: pdf converter not found for $base" >&2
                        continue
                    fi
                fi
            fi
            echo "$f" >> "$out_file"
        done
    done
}

# ---------------------------------------------------------------------------
# Helper: recommend_label
# ---------------------------------------------------------------------------
#
# Filename-heuristic recommendation per the FR-9 contract.
# ---------------------------------------------------------------------------
recommend_label() {
    local path="$1"
    local base
    base=$(basename "$path")
    local upper
    upper=$(echo "$base" | tr '[:lower:]' '[:upper:]')
    case "$upper" in
        *BRIEF*) echo "primary" ;;
        *PLAN*) echo "primary" ;;
        *DECISIONS*) echo "decision-history" ;;
        *AUDIT*) echo "decision-history" ;;
        *HANDOFF*) echo "supplementary" ;;
        *) echo "supplementary" ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: label_material
# ---------------------------------------------------------------------------
#
# Under --yes auto-accepts the recommendation. Otherwise invokes
# ask_one once per material (CON-5). _GRILLING_CURRENT_QKEY is set to ""
# so the labeling loop does NOT trigger contradiction-detection or
# glossary writes — labels are independent of schema-key collisions.
# ---------------------------------------------------------------------------
label_material() {
    local path="$1"
    local yes_flag="$2"
    local rec
    rec=$(recommend_label "$path")
    if [ "$yes_flag" -eq 1 ]; then
        echo "$rec"
        return 0
    fi
    _GRILLING_CURRENT_QKEY=""
    _GRILLING_CURRENT_DEFINITION=""
    local base
    base=$(basename "$path")
    local out
    out=$(ask_one "Label for $base:" "$rec")
    local label
    label=$(echo "$out" | sed -n 's/^answer: //p' | tail -1)
    if [ -z "$label" ]; then
        label="$rec"
    fi
    # Validate against closed enum.
    case "$label" in
        primary|supplementary|decision-history|out-of-scope)
            echo "$label"
            ;;
        *)
            echo "unrecognized label '$label' - falling back to recommendation '$rec'" >&2
            echo "$rec"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: extract_token_refs
# ---------------------------------------------------------------------------
#
# Extracts <TOKEN>-<NUMBER> references via grep -oE. Bash 3.2 safe.
# ---------------------------------------------------------------------------
extract_token_refs() {
    local f="$1"
    grep -oE '[A-Z][A-Z]+-[0-9]+' "$f" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Helper: detect_id_misalignment
# ---------------------------------------------------------------------------
#
# For each token-prefix family (e.g. DR-, US-, FR-, M-), compares the
# maximum-referenced number across documents. When two documents
# reference the same prefix family with non-overlapping ranges (or one
# references a number the other does not define), emits an
# id-misalignment entry. The PBJ fixture exercises:
#   1. PRODUCT-BRIEF refs US-3 but MVP-PLAN defines only US-1 / US-2.
#   4. DECISIONS defines DR-003 but no upstream cites it.
# ---------------------------------------------------------------------------
detect_id_misalignment() {
    local materials_list="$1"
    local out_file="$2"
    local refs_tmp
    refs_tmp="$INTAKE_DIR/refs-by-file.txt"
    : > "$refs_tmp"
    local f
    while IFS= read -r f; do
        if [ -z "$f" ]; then
            continue
        fi
        local base
        base=$(basename "$f")
        local refs
        refs=$(extract_token_refs "$f")
        local r
        for r in $refs; do
            echo "$base:$r" >> "$refs_tmp"
        done
    done < "$materials_list"

    # Build sorted unique list of (file, token).
    local sorted_tmp
    sorted_tmp="$INTAKE_DIR/refs-sorted.txt"
    sort -u "$refs_tmp" > "$sorted_tmp"

    # For each prefix family, collect the set of (file, number) pairs.
    # Emit id-misalignment when one file references a number that no
    # OTHER file in the set references (asymmetric reference).
    local prefix_list
    prefix_list=$(awk -F: '{ ref=$2; sub(/-[0-9]+$/, "", ref); print ref }' "$sorted_tmp" | sort -u)
    local prefix
    for prefix in $prefix_list; do
        local pairs
        pairs=$(grep ":${prefix}-" "$sorted_tmp" || true)
        if [ -z "$pairs" ]; then
            continue
        fi
        # For each (file, ref), check if any other file mentions the same ref
        # OR defines it. Asymmetry = misalignment.
        local pair
        local IFSO="$IFS"
        IFS=$'\n'
        for pair in $pairs; do
            local file_part
            file_part=$(echo "$pair" | cut -d: -f1)
            local ref_part
            ref_part=$(echo "$pair" | cut -d: -f2)
            # Count files mentioning this ref.
            local hit_count
            hit_count=$(grep -c ":${ref_part}\$" "$sorted_tmp" || true)
            if [ -z "$hit_count" ]; then
                hit_count=0
            fi
            if [ "$hit_count" = "1" ]; then
                echo "id-misalignment:${file_part}:${ref_part} referenced only in ${file_part}" >> "$out_file"
            fi
        done
        IFS="$IFSO"
    done
}

# ---------------------------------------------------------------------------
# Helper: detect_scheme_contradiction
# ---------------------------------------------------------------------------
#
# Extracts same-key declarations across primary + supplementary
# materials and emits a scheme-contradiction entry when the same key
# has different values across documents. Keys probed: target_user,
# mvp_boundary, success_metric, MVP timeline, deployment target.
# ---------------------------------------------------------------------------
detect_scheme_contradiction() {
    local materials_list="$1"
    local out_file="$2"
    local labels_file="$3"
    local key_patterns='target_user|mvp_boundary|success_metric|MVP timeline|deployment target|deployment_target'
    local kv_tmp
    kv_tmp="$INTAKE_DIR/kv-tmp.txt"
    : > "$kv_tmp"
    local f
    while IFS= read -r f; do
        if [ -z "$f" ]; then
            continue
        fi
        local base
        base=$(basename "$f")
        # Extract `key: value` lines for the probed keys (case-insensitive).
        local kv_lines
        kv_lines=$(grep -iE "^[^#]*(${key_patterns})[[:space:]]*:" "$f" 2>/dev/null || true)
        if [ -z "$kv_lines" ]; then
            continue
        fi
        local IFSO="$IFS"
        IFS=$'\n'
        local line
        for line in $kv_lines; do
            # Normalize: strip leading bullets / whitespace; lowercase the key.
            local stripped
            stripped=$(echo "$line" | sed -E 's/^[[:space:]]*[-*]?[[:space:]]*//')
            local key
            key=$(echo "$stripped" | sed -E 's/^([^:]+):.*/\1/' | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/_/g')
            local val
            val=$(echo "$stripped" | sed -E 's/^[^:]+:[[:space:]]*//' | sed -E 's/[[:space:]]+$//')
            if [ -n "$key" ] && [ -n "$val" ]; then
                echo "${key}|${base}|${val}" >> "$kv_tmp"
            fi
        done
        IFS="$IFSO"
    done < "$materials_list"

    if [ ! -s "$kv_tmp" ]; then
        return 0
    fi

    # For each key, compare values across documents. Differing values = contradiction.
    local key_list
    key_list=$(awk -F'|' '{ print $1 }' "$kv_tmp" | sort -u)
    local key
    for key in $key_list; do
        local rows
        rows=$(grep "^${key}|" "$kv_tmp" || true)
        local val_list
        val_list=$(echo "$rows" | awk -F'|' '{ print $3 }' | sort -u)
        local val_count
        val_count=$(echo "$val_list" | grep -c .)
        if [ "$val_count" -gt 1 ]; then
            local files
            files=$(echo "$rows" | awk -F'|' '{ print $2 }' | sort -u | tr '\n' ',' | sed 's/,$//')
            echo "scheme-contradiction:${files}:${key} differs across documents" >> "$out_file"
        fi
    done
}

# ---------------------------------------------------------------------------
# Helper: detect_orphan_reference
# ---------------------------------------------------------------------------
#
# Collects every <TOKEN>-<NUMBER> reference, then collects every defining
# occurrence (lines matching `^### TOKEN-NUMBER` or `^TOKEN-NUMBER:`).
# Emits orphan-reference for any reference without a defining occurrence
# anywhere in the set. Exercises PBJ fixture's M-3 orphan.
# ---------------------------------------------------------------------------
detect_orphan_reference() {
    local materials_list="$1"
    local out_file="$2"
    local refs_all
    refs_all="$INTAKE_DIR/refs-all.txt"
    local defs_all
    defs_all="$INTAKE_DIR/defs-all.txt"
    : > "$refs_all"
    : > "$defs_all"
    local f
    while IFS= read -r f; do
        if [ -z "$f" ]; then
            continue
        fi
        local base
        base=$(basename "$f")
        # Refs.
        local refs
        refs=$(extract_token_refs "$f")
        local r
        for r in $refs; do
            echo "$r|$base" >> "$refs_all"
        done
        # Defs: ### TOKEN-NUMBER OR TOKEN-NUMBER: at line-start.
        local defs1
        defs1=$(grep -oE '^### [A-Z][A-Z]+-[0-9]+' "$f" 2>/dev/null || true)
        local d
        for d in $defs1; do
            local clean
            clean=$(echo "$d" | sed -E 's/^### //')
            echo "$clean" >> "$defs_all"
        done
        local defs2
        defs2=$(grep -oE '^[A-Z][A-Z]+-[0-9]+:' "$f" 2>/dev/null || true)
        for d in $defs2; do
            local clean2
            clean2=$(echo "$d" | sed -E 's/:$//')
            echo "$clean2" >> "$defs_all"
        done
    done < "$materials_list"

    # For each ref, check if it appears in defs_all. If not, emit orphan.
    local sorted_refs
    sorted_refs=$(sort -u "$refs_all")
    local IFSO="$IFS"
    IFS=$'\n'
    local row
    for row in $sorted_refs; do
        if [ -z "$row" ]; then
            continue
        fi
        local ref_token
        ref_token=$(echo "$row" | cut -d'|' -f1)
        local ref_file
        ref_file=$(echo "$row" | cut -d'|' -f2)
        if ! grep -qxF "$ref_token" "$defs_all"; then
            echo "orphan-reference:${ref_file}:${ref_token} referenced but never defined" >> "$out_file"
        fi
    done
    IFS="$IFSO"
}

# ---------------------------------------------------------------------------
# Helper: detect_drift
# ---------------------------------------------------------------------------
#
# Three deterministic detectors run sequentially. Output goes to the
# conflicts accumulator file as `<category>:<details>` lines.
# ---------------------------------------------------------------------------
detect_drift() {
    local materials_list="$1"
    local labels_file="$2"
    local out_file="$3"
    : > "$out_file"
    detect_id_misalignment "$materials_list" "$out_file"
    detect_scheme_contradiction "$materials_list" "$out_file" "$labels_file"
    detect_orphan_reference "$materials_list" "$out_file"
    # De-duplicate.
    if [ -s "$out_file" ]; then
        local dedup_tmp
        dedup_tmp="$INTAKE_DIR/conflicts-dedup.txt"
        sort -u "$out_file" > "$dedup_tmp"
        mv "$dedup_tmp" "$out_file"
    fi
}

# ---------------------------------------------------------------------------
# Helper: surface_conflicts
# ---------------------------------------------------------------------------
surface_conflicts() {
    local acc_file="$1"
    local count="$2"
    local i=1
    local line
    local IFSO="$IFS"
    IFS=$'\n'
    while IFS= read -r line; do
        echo "${i}. ${line}"
        i=$((i + 1))
    done < "$acc_file"
    IFS="$IFSO"
}

# ---------------------------------------------------------------------------
# Helper: reconcile_terminal
# ---------------------------------------------------------------------------
#
# For each conflict invokes ask_one with default accept-primary.
# Closed resolution enum: accept-primary | accept-supplementary |
# manual-edit | defer.
# ---------------------------------------------------------------------------
reconcile_terminal() {
    local acc_file="$1"
    local out_file="$2"
    local yes_flag="$3"
    : > "$out_file"
    local i=1
    local line
    local IFSO="$IFS"
    IFS=$'\n'
    while IFS= read -r line; do
        local cat
        cat=$(echo "$line" | cut -d: -f1)
        local resolution=""
        if [ "$yes_flag" -eq 1 ]; then
            resolution="accept-primary"
        else
            _GRILLING_CURRENT_QKEY=""
            _GRILLING_CURRENT_DEFINITION=""
            local out
            out=$(ask_one "Resolve conflict ${i} (${cat}):" "accept-primary")
            resolution=$(echo "$out" | sed -n 's/^answer: //p' | tail -1)
            if [ -z "$resolution" ]; then
                resolution="accept-primary"
            fi
        fi
        case "$resolution" in
            accept-primary|accept-supplementary|manual-edit|defer)
                ;;
            *)
                echo "unrecognized resolution '$resolution' - falling back to accept-primary" >&2
                resolution="accept-primary"
                ;;
        esac
        echo "${i}|${resolution}|${line}" >> "$out_file"
        i=$((i + 1))
    done < "$acc_file"
    IFS="$IFSO"
}

# ---------------------------------------------------------------------------
# Helper: reconcile_file_based
# ---------------------------------------------------------------------------
#
# Writes a markdown checklist to conflicts.md; exits 0 with the
# re-invoke diagnostic. Above-threshold UX path per #Q-6.
# ---------------------------------------------------------------------------
reconcile_file_based() {
    local acc_file="$1"
    local md_path="$2"
    local count="$3"
    {
        echo "# Conflicts ($count detected)"
        echo ""
        echo "Edit each block to declare a resolution from the closed enum:"
        echo "accept-primary | accept-supplementary | manual-edit | defer"
        echo ""
        local i=1
        local line
        local IFSO="$IFS"
        IFS=$'\n'
        while IFS= read -r line; do
            echo "## Conflict $i"
            echo ""
            echo "- Detail: $line"
            echo "- Resolution: <fill>"
            echo ""
            i=$((i + 1))
        done < "$acc_file"
        IFS="$IFSO"
    } > "$md_path"
    echo "edit then re-invoke with --resolve $md_path"
}

# ---------------------------------------------------------------------------
# Helper: emit_reconciled_prespec
# ---------------------------------------------------------------------------
#
# Composes the byte-deterministic reconciled pre-spec body.
#   - H1 title.
#   - Sections per labeled material, primary first then supplementary
#     then decision-history. out-of-scope materials excluded.
#   - Provenance comments per resolved conflict.
# Body MUST NOT embed timestamps or random tokens.
# ---------------------------------------------------------------------------
emit_reconciled_prespec() {
    local labels_file="$1"
    local resolutions_file="$2"
    local out_path="$3"
    {
        echo "# Reconciled Pre-Spec"
        echo ""
        echo "Generated by orchestrator:materials-intake (FR-9)."
        echo ""
        # Sections per category, in canonical order.
        local cat
        for cat in primary supplementary decision-history; do
            local rows
            rows=$(grep "|${cat}\$" "$labels_file" || true)
            if [ -z "$rows" ]; then
                continue
            fi
            echo "## ${cat}"
            echo ""
            local IFSO="$IFS"
            IFS=$'\n'
            local row
            for row in $rows; do
                local path
                path=$(echo "$row" | cut -d'|' -f1)
                local base
                base=$(basename "$path")
                echo "### ${base}"
                echo ""
                # Embed the file body verbatim under its section heading.
                # Re-emit content; preserves byte-identity for identical inputs.
                cat "$path"
                echo ""
            done
            IFS="$IFSO"
        done
        # Provenance comments.
        if [ -s "$resolutions_file" ]; then
            echo "## Reconciliation Log"
            echo ""
            local rline
            local IFS_R="$IFS"
            IFS=$'\n'
            while IFS= read -r rline; do
                local rid
                rid=$(echo "$rline" | cut -d'|' -f1)
                local rres
                rres=$(echo "$rline" | cut -d'|' -f2)
                echo "<!-- Reconciled: conflict-${rid} -> ${rres} -->"
            done < "$resolutions_file"
            IFS="$IFS_R"
        fi
    } > "$out_path"
}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------

# Resolve mode: short-circuit re-detection. Reuse the parent intake dir's
# labels.txt + conflicts-acc.txt from the original run, parse resolutions
# from the operator-edited conflicts.md, then emit the pre-spec + markers.
if [ -n "$RESOLVE_PATH" ]; then
    if [ ! -s "$LABELS_FILE" ]; then
        echo "--resolve: prior labels.txt missing or empty under $INTAKE_DIR" >&2
        exit 2
    fi
    parse_resolve_md "$RESOLVE_PATH" "$RESOLUTIONS_FILE"

    CONFLICT_COUNT=0
    if [ -s "$RESOLUTIONS_FILE" ]; then
        CONFLICT_COUNT=$(grep -c . "$RESOLUTIONS_FILE" || true)
    fi
    LABELED_COUNT=$(grep -c . "$LABELS_FILE" || true)

    emit_reconciled_prespec "$LABELS_FILE" "$RESOLUTIONS_FILE" "$PRESPEC_PATH"

    bash "$REPO_ROOT/scripts/util/start-state-markers.sh" write materials-intake "$PROJECT_DIR"
    PAYLOAD="{\"materials_count\":${LABELED_COUNT},\"conflicts_resolved\":${CONFLICT_COUNT}}"
    PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/util/jsonl-event-emitter.sh" emit materials_intake_completed "$PAYLOAD"
    DUAL_WRITE_HELPER="$REPO_ROOT/scripts/util/dual-write-runtime-md.sh"
    if [ -x "$DUAL_WRITE_HELPER" ]; then
        FRAGMENT="materials-intake: reconciled ${LABELED_COUNT} materials with ${CONFLICT_COUNT} conflicts resolved"
        bash "$DUAL_WRITE_HELPER" --root "$PROJECT_DIR" --marker recent-changes --append-entry "$FRAGMENT" || true
    fi

    echo "PASS: materials-intake completed"
    echo "SUMMARY: materials-intake.sh materials=${LABELED_COUNT} conflicts=${CONFLICT_COUNT} prespec=${PRESPEC_PATH}"
    exit 0
fi

MATERIALS_LIST="$INTAKE_DIR/materials.txt"
enumerate_materials "$PROJECT_DIR" "$MATERIALS_LIST"

if [ ! -s "$MATERIALS_LIST" ]; then
    echo "no materials detected - falling back to greenfield-empty ideation flow"
    exit 0
fi

# Labeling loop: write `<path>|<label>` per material.
LABELED_COUNT=0
OUT_OF_SCOPE_COUNT=0
TOTAL_COUNT=0
# FD-0 isolation: the materials list is read on FD 3 so the loop body
# (which calls label_material -> ask_one) inherits the operator's
# stdin on FD 0. Without this, ask_one's `read` would consume the
# materials list instead of operator input. Bash 3.2 safe.
while IFS= read -r M <&3; do
    if [ -z "$M" ]; then
        continue
    fi
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    LBL=$(label_material "$M" "$YES_FLAG")
    echo "${M}|${LBL}" >> "$LABELS_FILE"
    LABELED_COUNT=$((LABELED_COUNT + 1))
    if [ "$LBL" = "out-of-scope" ]; then
        OUT_OF_SCOPE_COUNT=$((OUT_OF_SCOPE_COUNT + 1))
    fi
done 3< "$MATERIALS_LIST"

# US-4 AS-5 fallback: ALL materials labeled out-of-scope -> exit 0.
if [ "$TOTAL_COUNT" -gt 0 ] && [ "$OUT_OF_SCOPE_COUNT" -eq "$TOTAL_COUNT" ]; then
    echo "no primary spec materials labeled - skipping reconciliation, falling back to greenfield-empty ideation flow"
    exit 0
fi

# Drift detection.
detect_drift "$MATERIALS_LIST" "$LABELS_FILE" "$CONFLICTS_ACC"

CONFLICT_COUNT=0
if [ -s "$CONFLICTS_ACC" ]; then
    CONFLICT_COUNT=$(grep -c . "$CONFLICTS_ACC" || true)
fi

# Reconciliation: terminal vs file-based per threshold.
if [ "$CONFLICT_COUNT" -gt "$THRESHOLD" ]; then
    reconcile_file_based "$CONFLICTS_ACC" "$CONFLICTS_MD" "$CONFLICT_COUNT"
    exit 0
fi

if [ "$CONFLICT_COUNT" -gt 0 ]; then
    surface_conflicts "$CONFLICTS_ACC" "$CONFLICT_COUNT"
    reconcile_terminal "$CONFLICTS_ACC" "$RESOLUTIONS_FILE" "$YES_FLAG"
fi

# Reconciled pre-spec emission (byte-deterministic body).
emit_reconciled_prespec "$LABELS_FILE" "$RESOLUTIONS_FILE" "$PRESPEC_PATH"

# FR-20 marker (lands on disk as materials-intake.complete under
# <project-dir>/.orchestrator/start-state/), FR-22 JSONL emit,
# FR-21 dual-write fragment.
bash "$REPO_ROOT/scripts/util/start-state-markers.sh" write materials-intake "$PROJECT_DIR"

PAYLOAD="{\"materials_count\":${LABELED_COUNT},\"conflicts_resolved\":${CONFLICT_COUNT}}"
PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/util/jsonl-event-emitter.sh" emit materials_intake_completed "$PAYLOAD"

DUAL_WRITE_HELPER="$REPO_ROOT/scripts/util/dual-write-runtime-md.sh"
if [ -x "$DUAL_WRITE_HELPER" ]; then
    FRAGMENT="materials-intake: reconciled ${LABELED_COUNT} materials with ${CONFLICT_COUNT} conflicts resolved"
    bash "$DUAL_WRITE_HELPER" --root "$PROJECT_DIR" --marker recent-changes --append-entry "$FRAGMENT" || true
fi

echo "PASS: materials-intake completed"
echo "SUMMARY: materials-intake.sh materials=${LABELED_COUNT} conflicts=${CONFLICT_COUNT} prespec=${PRESPEC_PATH}"
exit 0
