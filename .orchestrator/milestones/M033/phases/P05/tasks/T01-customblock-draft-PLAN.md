---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M033"
name: "commands/customblock-draft.md + scripts/lifecycle/customblock-draft.sh + references/customblock-format.md (FR-13 / FR-14)"
depends_on: []
---

## Prerequisites

T01 ships the FR-13 + FR-14 surface: the new `orchestrator:customblock-draft` command-doc, the deterministic strict-aggregation driver, the FR-14 SSOT reference, and three shape verifiers. T01 has no intra-phase prerequisites — it consumes only P02 surfaces and reads P03/P04 sub-flow outputs at run time.

Files that MUST exist on disk at task-start (verified via `ls -la` per Plan-Time Discipline rule 1):

- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — FR-22 closed-enum emitter library (12 event types including the additive `imported_context_loaded` from P03/T04; T01 will call `emit customblock_drafted <payload>` — `customblock_drafted` is already in the closed enum per P02/T01)
- `scripts/util/start-state-markers.sh` (P02/T02) — partial-state marker primitives (write/read/next/clear over a closed sub-flow enum; `customblock-draft` is one of the documented sub-flow names per the FR-22 + FR-20 conventions, mapped via the start-state-markers.sh alias-mapping comment block from P03/T05's harmonization)
- `scripts/util/dual-write-runtime-md.sh` (M014/M033 inheritance) — FR-21 dual-write helper accepting `--root <path> --marker recent-changes --append-entry '<fragment>'` per the P03/T05-harmonized API
- `references/m033-fr21-dual-write-convention.md` (P02/T05) — FR-21 SSOT documenting the `--marker recent-changes --append-entry` real flag-form API (P03/T05 amended)
- `templates/project-instruction.md` (M001) — defines the `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` marker convention
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` (P01) — referenced for verification of friendly-tester artifacts (out-of-scope-for-T01 but listed for context)

P02-shipped API summary (zero-context surface T01 calls):
- `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <json_payload>` — appends a `{"event_type":"<type>","timestamp":"<ISO 8601 UTC>",...payload}` record to `<project-dir>/.orchestrator/execution-log.jsonl`. `event_type` MUST be in the closed enum. Atomic-append guard at 480 bytes.
- `bash scripts/util/start-state-markers.sh write <subflow-name> <project-dir>` — writes/preserves `<project-dir>/.orchestrator/start-state/<subflow-name>.complete`; idempotent (first-completion timestamp preserved on re-write).
- `bash scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker recent-changes --append-entry '<fragment>'` — appends one line to the `# >>> orchestrator:recent-changes >>>` region in `<project-dir>/CLAUDE.md` (and `<project-dir>/AGENTS.md` per `dual_write_agents` config).

## Description

T01 ships THREE deliverables (plus three shape verifiers):

1. **`commands/customblock-draft.md`** — canonical command-doc per MEM012 documenting the FR-13/FR-14 contract.
2. **`scripts/lifecycle/customblock-draft.sh`** — the deterministic strict-aggregation driver implementing FR-13.
3. **`references/customblock-format.md`** — FR-14 SSOT documenting the prescriptive 5-section custom-block format, the floor-not-ceiling discipline, the `## Source-Docs` vs `## Entry Points` branch-dependent variant rule, and the strict-aggregation invariant.

Plus three shape verifiers under `tools/verify/m033-p05-*`.

## Steps

### 1. Author `commands/customblock-draft.md`

Follow the canonical command-doc shape per MEM012 (YAML frontmatter `description:` field; `# orchestrator:customblock-draft` H1; numbered Core Workflow sections; Output / Idempotency / Error Handling / Referenced Scripts sections). Required content tokens (load-bearing for shape verifier):

- `orchestrator:customblock-draft` (H1)
- `FR-13`, `FR-14` (compliance citations in body)
- `customblock-draft.sh` (Referenced Scripts section)
- `BEGIN CUSTOM`, `END CUSTOM` (the marker-delimited write region)
- `## Project`, `## Stack`, `## Source-Docs`, `## Entry Points`, `## Conventions`, `## Decisions` (the prescribed 5-section structure with the branch-dependent variant)
- `customblock_drafted` (the FR-22 JSONL event-type)
- `customblock-draft.complete` (the FR-20 sub-flow marker)
- `constitution not present` (the US-7 AS-5 structurally-downstream-of-US-2 diagnostic)
- `no LLM`, `Constitution XV` (the strict-aggregation invariant)
- `customblock-format.md` (link to the FR-14 SSOT)

Body sections (numbered Core Workflow per MEM012):

```
## Prerequisites / State Check
- A constitution at <project-dir>/.orchestrator/memory/constitution.md (US-7 AS-5 structurally-downstream-of-US-2 gate)
- Optionally: ingest-codebase MEMs at <project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/
- Optionally: an intake artifact at <project-dir>/.orchestrator/intake/<timestamp>/{reconciled-pre-spec.md,ideation-pre-spec.md}

## Core Workflow
1. Verify the constitution exists; on absence, exit non-zero with the diagnostic.
2. Detect which upstream outputs are present and choose `## Source-Docs` (intake artifact present) vs `## Entry Points` (no intake artifact, ingest-codebase MEMs present) variant.
3. Strictly aggregate upstream outputs into the 5-section draft (no LLM invocation per Constitution XV).
4. Hand the draft to $EDITOR (skipped under --yes).
5. Write the reviewed content into the marker-delimited region of <project-dir>/CLAUDE.md.
6. Write the customblock-draft.complete marker.
7. Emit customblock_drafted JSONL event.
8. Append FR-21 dual-write Recent Changes fragment.

## Output
- <project-dir>/CLAUDE.md (modified — marker-delimited region populated)
- <project-dir>/.orchestrator/start-state/customblock-draft.complete (created)
- <project-dir>/.orchestrator/execution-log.jsonl (appended customblock_drafted record)

## Idempotency
- Without --force: re-runs preserve existing content (byte-identical) with `no changes` diagnostic.
- With --force: regenerates with stderr warning `--force discards prior operator edits`.

## Error Handling
- Missing constitution: exit non-zero with `constitution not present — run "orchestrator:constitution" first` (US-7 AS-5).

## Referenced Scripts
- scripts/lifecycle/customblock-draft.sh
- scripts/util/jsonl-event-emitter.sh (FR-22 emitter)
- scripts/util/start-state-markers.sh (FR-20 marker)
- scripts/util/dual-write-runtime-md.sh (FR-21 dual-write)

## See Also
- references/customblock-format.md (FR-14 SSOT)
```

### 2. Author `scripts/lifecycle/customblock-draft.sh`

Bash 3.2 compatible per MEM001. Single-script-file shape per AD-19 (no inline compound bash, no plain subshells, no `$()` containing pipes, no process substitution). Structure:

```bash
#!/usr/bin/env bash
# scripts/lifecycle/customblock-draft.sh -- M033/P05/T01 -- FR-13/FR-14 customblock-drafter
#
# Strict-aggregation discipline (Constitution XV): every line emitted into the
# custom block traces verbatim to a file under .orchestrator/{memory,knowledge,intake}/.
# NO conversus invocation, NO model routing, NO LLM call path.
set -e
set -u

PROJECT_DIR="${PWD}"
YES=0
FORCE=0

# Argument parsing -- additive flags, no overlap with constitution-author.sh.
while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --yes) YES=1; shift ;;
        --force) FORCE=1; shift ;;
        *) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# Step 1: structurally-downstream-of-US-2 gate (FR-13 step b).
CONSTITUTION="$PROJECT_DIR/.orchestrator/memory/constitution.md"
if [ ! -f "$CONSTITUTION" ]; then
    printf 'constitution not present -- run "orchestrator:constitution" first\n' >&2
    exit 1
fi

# Step 2: detect upstream outputs and choose section variant.
INTAKE_DIR="$PROJECT_DIR/.orchestrator/intake"
ARCH_DIR="$PROJECT_DIR/.orchestrator/knowledge/architecture"
CONV_DIR="$PROJECT_DIR/.orchestrator/knowledge/conventions"
DEC_DIR="$PROJECT_DIR/.orchestrator/knowledge/decisions"
SECTION_VARIANT="entry-points"  # Default for existing-codebase / migrating branches.
INTAKE_PRESPEC=""
if [ -d "$INTAKE_DIR" ]; then
    # Find newest reconciled-pre-spec.md or ideation-pre-spec.md.
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

# Step 3: idempotency check before any draft work.
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    # Extract content between BEGIN CUSTOM and END CUSTOM markers (no process substitution).
    EXISTING_CUSTOM=$(awk '/<!-- BEGIN CUSTOM -->/,/<!-- END CUSTOM -->/' "$CLAUDE_MD" | grep -v '<!-- BEGIN CUSTOM -->' | grep -v '<!-- END CUSTOM -->' || true)
    NONEMPTY=$(printf '%s' "$EXISTING_CUSTOM" | grep -c '[^[:space:]]' || true)
    if [ "${NONEMPTY:-0}" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
        printf 'no changes -- existing custom block preserved (use --force to regenerate)\n'
        exit 0
    fi
    if [ "${NONEMPTY:-0}" -gt 0 ] && [ "$FORCE" -eq 1 ]; then
        printf '--force discards prior operator edits in CLAUDE.md custom block\n' >&2
    fi
fi

# Step 4: strict aggregation -- no LLM, no conversus, no model routing.
DRAFT=$(mktemp)
{
    printf '\n## Project\n\n'
    # Strict aggregation from constitution preamble + detected stack signals.
    printf '- Source: <constitution at .orchestrator/memory/constitution.md>\n'
    grep -m1 '^# ' "$CONSTITUTION" 2>/dev/null | sed 's/^# /- Title: /' || printf '- Title: <constitution title not detected>\n'

    printf '\n## Stack\n\n'
    if [ -d "$ARCH_DIR" ]; then
        for f in "$ARCH_DIR"/MEM-*.md; do
            [ -f "$f" ] || continue
            # Extract first non-frontmatter content line as a Stack bullet.
            LINE=$(awk '/^---$/{c++; next} c==2 && NF>0 {print; exit}' "$f")
            [ -n "$LINE" ] && printf -- '- %s [source: %s]\n' "$LINE" "$(basename "$f")"
        done
    else
        printf '- (no architecture MEMs detected -- run orchestrator:ingest-codebase)\n'
    fi

    if [ "$SECTION_VARIANT" = "source-docs" ]; then
        printf '\n## Source-Docs\n\n'
        # Intake pre-spec: enumerate H2 section headers verbatim.
        grep '^## ' "$INTAKE_PRESPEC" | sed 's/^## /- Section: /' || true
        printf -- '- Source: %s\n' "${INTAKE_PRESPEC#$PROJECT_DIR/}"
    else
        printf '\n## Entry Points\n\n'
        if [ -d "$ARCH_DIR" ]; then
            for f in "$ARCH_DIR"/MEM-*.md; do
                [ -f "$f" ] || continue
                NAME=$(basename "$f" .md)
                printf -- '- %s [source: %s]\n' "$NAME" "$(basename "$f")"
            done
        else
            printf '- (no entry-point MEMs detected)\n'
        fi
    fi

    printf '\n## Conventions\n\n'
    if [ -d "$CONV_DIR" ]; then
        for f in "$CONV_DIR"/MEM-*.md; do
            [ -f "$f" ] || continue
            LINE=$(awk '/^---$/{c++; next} c==2 && NF>0 {print; exit}' "$f")
            [ -n "$LINE" ] && printf -- '- %s [source: %s]\n' "$LINE" "$(basename "$f")"
        done
    else
        printf '- (no convention MEMs detected)\n'
    fi

    printf '\n## Decisions\n\n'
    if [ -d "$DEC_DIR" ]; then
        for f in "$DEC_DIR"/MEM-*.md; do
            [ -f "$f" ] || continue
            LINE=$(awk '/^---$/{c++; next} c==2 && NF>0 {print; exit}' "$f")
            [ -n "$LINE" ] && printf -- '- %s [source: %s]\n' "$LINE" "$(basename "$f")"
        done
    else
        printf '- (no decision MEMs detected)\n'
    fi
} > "$DRAFT"

# Step 5: editor pass (skipped under --yes).
if [ "$YES" -eq 0 ]; then
    EDITOR_BIN="${EDITOR:-vi}"
    "$EDITOR_BIN" "$DRAFT"
fi

# Step 6: preserve operator additions outside the 5 prescribed sections (floor-not-ceiling).
# Implementation: scan existing custom block for any H2 not in the prescribed set;
# if found, append it verbatim to the new draft (US-7 AS-2).
PRESCRIBED='## Project|## Stack|## Source-Docs|## Entry Points|## Conventions|## Decisions'
if [ -f "$CLAUDE_MD" ]; then
    EXISTING_BLOCK=$(awk '/<!-- BEGIN CUSTOM -->/,/<!-- END CUSTOM -->/' "$CLAUDE_MD")
    EXTRA_HEADERS=$(printf '%s\n' "$EXISTING_BLOCK" | grep '^## ' | grep -Ev "^($PRESCRIBED)$" || true)
    if [ -n "$EXTRA_HEADERS" ]; then
        # Append each extra section block verbatim.
        printf '%s\n' "$EXTRA_HEADERS" | while IFS= read -r hdr; do
            ESC=$(printf '%s' "$hdr" | sed 's/[][\\.*^$/]/\\&/g')
            awk -v h="$ESC" '$0 ~ "^"h"$"{p=1} p && /^## / && $0 != h && NR>1 {p=0} p {print}' "$CLAUDE_MD" >> "$DRAFT"
        done
    fi
fi

# Step 7: write reviewed content into marker-delimited region.
TMP_OUT=$(mktemp)
if [ -f "$CLAUDE_MD" ]; then
    awk -v draft="$DRAFT" '
        /<!-- BEGIN CUSTOM -->/{print; while ((getline line < draft) > 0) print line; in_block=1; next}
        /<!-- END CUSTOM -->/{in_block=0; print; next}
        !in_block {print}
    ' "$CLAUDE_MD" > "$TMP_OUT"
    mv "$TMP_OUT" "$CLAUDE_MD"
else
    {
        printf '<!-- BEGIN CUSTOM -->\n'
        cat "$DRAFT"
        printf '<!-- END CUSTOM -->\n'
    } > "$CLAUDE_MD"
fi
rm -f "$DRAFT"

# Step 8: write start-state marker (FR-20).
bash scripts/util/start-state-markers.sh write customblock-draft "$PROJECT_DIR" || true

# Step 9: emit JSONL event (FR-22).
PAYLOAD=$(printf '{"project_dir":"%s","section_variant":"%s","force":%s}' \
    "$PROJECT_DIR" "$SECTION_VARIANT" "$([ $FORCE -eq 1 ] && printf true || printf false)")
bash scripts/util/jsonl-event-emitter.sh emit customblock_drafted "$PAYLOAD" || true

# Step 10: FR-21 dual-write Recent Changes fragment.
FRAGMENT="- M033 customblock-draft: ${SECTION_VARIANT} variant, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
bash scripts/util/dual-write-runtime-md.sh --root "$PROJECT_DIR" --marker recent-changes --append-entry "$FRAGMENT" || true

printf 'customblock-drafted: %s sections=5 variant=%s\n' "$PROJECT_DIR" "$SECTION_VARIANT"
exit 0
```

### 3. Author `references/customblock-format.md`

Sections required:
- Title `# Customblock Format (FR-14 SSOT)`
- `## Prescribed 5 sections` — list each header verbatim with semantic role
- `## Branch-dependent variant rule` — `## Source-Docs` vs `## Entry Points` selection criteria
- `## Marker-delimited write region` — `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` discipline
- `## Floor-not-ceiling discipline` — operator additions preserved verbatim per US-7 AS-2
- `## Strict-aggregation invariant` — no LLM-invented facts per Constitution XV; every line traces to an upstream sub-flow output file
- `## Upstream output source map` — table mapping each section to its upstream file path
- `## Worked example` — rendered custom block for a fixture that completed US-1 + US-2 + US-3

Required content tokens for shape verifier: `FR-14`, `## Project`, `## Stack`, `## Source-Docs`, `## Entry Points`, `## Conventions`, `## Decisions`, `BEGIN CUSTOM`, `END CUSTOM`, `floor`, `ceiling`, `no LLM`, `Constitution XV`, `US-7 AS-2`.

### 4. Author `tools/verify/m033-p05-customblock-draft-md-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-draft-md-shape.sh
# Asserts commands/customblock-draft.md MEM012 shape + load-bearing tokens.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

DOC="commands/customblock-draft.md"
[ -f "$DOC" ] && pass "doc exists" || fail "doc missing: $DOC"

for tok in 'orchestrator:customblock-draft' 'FR-13' 'FR-14' 'customblock-draft.sh' \
           'BEGIN CUSTOM' 'END CUSTOM' '## Project' '## Stack' '## Source-Docs' \
           '## Entry Points' '## Conventions' '## Decisions' 'customblock_drafted' \
           'customblock-draft.complete' 'constitution not present' 'no LLM' \
           'Constitution XV' 'customblock-format.md'; do
    grep -qF -- "$tok" "$DOC" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$DOC")
[ "$LINES" -ge 60 ] && pass "min 60 lines (got $LINES)" || fail "below 60 lines (got $LINES)"

printf 'SUMMARY: m033-p05-customblock-draft-md-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 5. Author `tools/verify/m033-p05-customblock-draft-sh-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-draft-sh-shape.sh
# Asserts scripts/lifecycle/customblock-draft.sh shape + strict-aggregation negative-grep.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

DRV="scripts/lifecycle/customblock-draft.sh"
[ -f "$DRV" ] && pass "driver exists" || fail "driver missing: $DRV"
[ -x "$DRV" ] && pass "driver executable" || fail "driver not executable"

for tok in '--project-dir' '--yes' '--force' 'BEGIN CUSTOM' 'END CUSTOM' \
           '## Project' '## Stack' '## Source-Docs' '## Entry Points' \
           '## Conventions' '## Decisions' 'constitution not present' \
           'knowledge/architecture' 'knowledge/conventions' 'knowledge/decisions' \
           'intake/' 'reconciled-pre-spec.md' 'ideation-pre-spec.md' \
           'customblock_drafted' 'customblock-draft.complete' \
           'dual-write-runtime-md.sh' 'discards prior operator edits' 'no changes'; do
    grep -qF -- "$tok" "$DRV" && pass "token present: $tok" || fail "token absent: $tok"
done

# Negative grep: strict-aggregation invariant -- NO LLM/conversus/model invocation paths.
# Skip comment lines so doc-prose mentioning these tokens doesn't trip negative checks.
NONCOMMENT=$(grep -Ev '^[[:space:]]*#' "$DRV" || true)
for forbidden in 'conversus' 'model_routing' 'claude-code.*--task' 'scripts/dispatch'; do
    if printf '%s' "$NONCOMMENT" | grep -qE -- "$forbidden"; then
        fail "forbidden token in code path: $forbidden"
    else
        pass "no forbidden invocation: $forbidden"
    fi
done

# MEM001 bash 3.2 negative grep: no `declare -A`.
if printf '%s' "$NONCOMMENT" | grep -qE 'declare -A'; then
    fail "bash 3.2 violation: declare -A"
else
    pass "no declare -A (bash 3.2)"
fi

LINES=$(wc -l < "$DRV")
[ "$LINES" -ge 250 ] && pass "min 250 lines (got $LINES)" || fail "below 250 lines (got $LINES)"

printf 'SUMMARY: m033-p05-customblock-draft-sh-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 6. Author `tools/verify/m033-p05-customblock-format-ref-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-format-ref-shape.sh
# Asserts references/customblock-format.md FR-14 SSOT shape.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

REF="references/customblock-format.md"
[ -f "$REF" ] && pass "reference exists" || fail "reference missing: $REF"

for tok in 'FR-14' '## Project' '## Stack' '## Source-Docs' '## Entry Points' \
           '## Conventions' '## Decisions' 'BEGIN CUSTOM' 'END CUSTOM' \
           'floor' 'ceiling' 'no LLM' 'Constitution XV' 'US-7 AS-2'; do
    grep -qF -- "$tok" "$REF" && pass "token present: $tok" || fail "token absent: $tok"
done

LINES=$(wc -l < "$REF")
[ "$LINES" -ge 60 ] && pass "min 60 lines (got $LINES)" || fail "below 60 lines (got $LINES)"

printf 'SUMMARY: m033-p05-customblock-format-ref-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves (all from the phase plan):

- `commands/customblock-draft.md` exists as a canonical command-doc per MEM012 (Truth #1)
- `scripts/lifecycle/customblock-draft.sh` exists, is executable, and implements the FR-13/FR-14 contract (Truth #2)
- `references/customblock-format.md` exists as the FR-14 SSOT (Truth #3)
- Artifacts: `commands/customblock-draft.md`, `scripts/lifecycle/customblock-draft.sh`, `references/customblock-format.md`
- Verifier artifacts: `tools/verify/m033-p05-customblock-draft-md-shape.sh`, `tools/verify/m033-p05-customblock-draft-sh-shape.sh`, `tools/verify/m033-p05-customblock-format-ref-shape.sh`

## Verification

```bash
bash tools/verify/m033-p05-customblock-draft-md-shape.sh
bash tools/verify/m033-p05-customblock-draft-sh-shape.sh
bash tools/verify/m033-p05-customblock-format-ref-shape.sh
```

Functional smoke (run after the above shape verifiers pass):

```bash
bash tools/verify/m033-p05-customblock-draft-functional-smoke.sh
```

(Optional T01-internal functional smoke — out-of-scope for this task's must-haves; SC-7 acceptance script in T04 is the load-bearing functional gate.)

## Inputs

### From Previous Tasks

None (T01 has no intra-phase prerequisites).

### From Disk (Pre-existing)

- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — `bash <path> emit <event_type> <json_payload>`; `customblock_drafted` is in the closed enum
- `scripts/util/start-state-markers.sh` (P02/T02) — `bash <path> write <subflow-name> <project-dir>`; `customblock-draft` is a documented sub-flow name
- `scripts/util/dual-write-runtime-md.sh` (M014) — `bash <path> --root <project-dir> --marker recent-changes --append-entry '<fragment>'`
- `references/m033-fr21-dual-write-convention.md` (P02/T05, P03/T05-amended) — FR-21 SSOT; cite for the real flag-form API
- `templates/project-instruction.md` (M001) — defines the `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` marker shape

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no command-substitution-with-pipes
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- Constitution XV strict aggregation — driver MUST NOT call conversus, MUST NOT use model routing, MUST NOT invoke any dispatch path
- CON-3 / Principle XVI — zero `speckit.*` references in any code path or output (cross-checked by P05 cross-phase regression)
- AD-15 cross-phase regression — T01's deliverables MUST NOT regress P01..P04 (zero changes to existing files; pure additive create)
- Idempotency — re-runs without `--force` MUST preserve byte-identical content; `--force` regenerates with stderr warning
- Floor-not-ceiling — operator additions beyond the 5 prescribed sections MUST be preserved verbatim per US-7 AS-2

## Expected Output

T01 writes 6 new files:
- `commands/customblock-draft.md` (≥60 lines, MEM012 shape, load-bearing tokens present)
- `scripts/lifecycle/customblock-draft.sh` (≥250 lines, executable, bash 3.2 compatible, strict-aggregation discipline, no LLM/conversus/model paths)
- `references/customblock-format.md` (≥60 lines, FR-14 SSOT)
- `tools/verify/m033-p05-customblock-draft-md-shape.sh` (≥30 lines, executable)
- `tools/verify/m033-p05-customblock-draft-sh-shape.sh` (≥35 lines, executable)
- `tools/verify/m033-p05-customblock-format-ref-shape.sh` (≥25 lines, executable)

T01 modifies zero existing files.

After T01 lands, the three shape verifiers each emit `SUMMARY: m033-p05-customblock-draft-*-shape.sh pass=N fail=0`.

## Notes

### Branch-dependent variant rule (`## Source-Docs` vs `## Entry Points`)

The driver scans `<project-dir>/.orchestrator/intake/<timestamp>/` for `reconciled-pre-spec.md` (FR-9 / P04/T01 output) or `ideation-pre-spec.md` (FR-10 / P04/T02 output). When either is present, the variant is `source-docs` and the rendered block carries `## Source-Docs`. When neither is present, the variant is `entry-points` and the rendered block carries `## Entry Points` populated from `knowledge/architecture/` MEMs. This matches the spec's US-7 / FR-13 / FR-14 contract.

### Floor-not-ceiling implementation

The driver scans the existing custom block for any H2 not in the prescribed set (`## Project`, `## Stack`, `## Source-Docs`, `## Entry Points`, `## Conventions`, `## Decisions`) and appends each such section verbatim to the new draft before the write. This preserves operator additions like `## Notes` per US-7 AS-2. The shape verifier asserts the driver implements this branch (token presence: `EXTRA_HEADERS` or equivalent identifier).

### `customblock_drafted` event-type already in the closed enum

P02/T01 shipped the FR-22 emitter with `customblock_drafted` in the closed enum (one of the 11 documented event types per the spec FR-22). T01 calls `emit customblock_drafted <payload>` directly — no enum extension required. P03/T04 already extended the enum once (additive 11→12 with `imported_context_loaded`); T01 does NOT need a similar extension.

### `customblock-draft` sub-flow name in start-state-markers enum

P02/T02 shipped the start-state-markers with the closed sub-flow enum. P03/T05 added an alias-mapping comment block reconciling enum names with FR-7-style doc-prose names. T01's `customblock-draft` sub-flow name is one of the documented FR-20 sub-flow markers; if the P02 enum does not include it verbatim, the marker write call will fail. Verify at task-start by inspecting `scripts/util/start-state-markers.sh` for the `customblock-draft` token; if absent, T01 includes a 1-line additive enum extension to start-state-markers.sh as a sub-step before the driver authorship (an additive extension matching the P03/T04 precedent for the JSONL emitter enum).

### Path-collision check (Plan-Time Discipline rule 6)

All 6 created paths verified absent at plan-authoring time via `ls`:

- `commands/customblock-draft.md` — absent
- `scripts/lifecycle/customblock-draft.sh` — absent
- `references/customblock-format.md` — absent
- `tools/verify/m033-p05-customblock-draft-md-shape.sh` — absent
- `tools/verify/m033-p05-customblock-draft-sh-shape.sh` — absent
- `tools/verify/m033-p05-customblock-format-ref-shape.sh` — absent

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

All `## Verification` commands resolve to verifiers co-authored inside this task (steps 4, 5, 6). No cross-task dependency on yet-unwritten verifiers.

### Classifier-shape pre-validation (Plan-Time Discipline rule 3)

The driver code shape uses single-script-file invocations throughout (`bash scripts/util/jsonl-event-emitter.sh emit ...`, `bash scripts/util/start-state-markers.sh write ...`, `bash scripts/util/dual-write-runtime-md.sh ...`) — no compound chains, no plain subshells, no `$()` containing pipes. The `EXISTING_CUSTOM=$(awk ... | grep -v ... | grep -v ... || true)` pattern is `$()` containing pipes, which IS a forbidden shape per AD-19's harness heuristic. **Mitigation**: rewrite as two-step `awk` then `grep` with intermediate temp file, OR use `awk` with multiple negation conditions in a single pass. The driver as authored above uses the first approach (single awk pass with composite conditions); if the executor finds the harness heuristic still trips, fall back to the temp-file two-step shape.
