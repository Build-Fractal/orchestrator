---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M020"
name: "Jaccard helper (pairwise + validate stub)"
depends_on: ["T01"]
---

## Prerequisites

- T01: D024 + MEM031 establish the schema authority. T04 does not write to
  the schema, but the validation report it produces (in T05) cites MEM031
  as the convention authority.

T04 can run in parallel with T02/T03 — it is an independent file under
`scripts/knowledge/lib/`.

Pre-existing on disk:
- `scripts/knowledge/lib/index-utils.sh` (`get_project_root`).
- `scripts/knowledge/lib/detail-utils.sh` (`fm_field` for reading scalar
  frontmatter fields like `title`, `topic`).
- `knowledge/**/MEM*.md` tree (T04's pairwise function reads from this for
  testing; T05 invokes `validate` against the live tree).

## Description

Create `scripts/knowledge/lib/jaccard.sh` — pairwise Jaccard similarity
computation on the CON-5 feature vector (`title` + `topic` + `tags[]` +
first-paragraph words capped at 50 tokens). Two subcommands:

1. `pairwise_jaccard <file-a> <file-b>` → emits `similarity=<0.0-1.0>` to
   stdout. Used internally and by P05 (clustering integration).
2. `validate <knowledge-root>` → walks the tree, computes pairwise sims,
   produces a stub report at the canonical path. T05 fills in the report
   contents; T04 ships the walker scaffolding.

T04 ships the helper + a contract test for `pairwise_jaccard`. The
`validate` subcommand exists in skeleton form (writes a placeholder report
header + the iteration loop) — T05 enriches it with the threshold-
recommendation analysis and the demo-sentence demonstration.

## Steps

### Step 1: Create `scripts/knowledge/lib/jaccard.sh`

File path:
`/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/lib/jaccard.sh`

Required structure:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/jaccard.sh — pairwise Jaccard similarity helper
# for M020 knowledge clustering. Bash 3.2 safe.
#
# Subcommands:
#   pairwise_jaccard <file-a> <file-b>   # emits similarity=<0.0-1.0>
#   validate <knowledge-root>            # walks tree, writes report
#
# CON-5 feature vector:
#   frontmatter `title` + frontmatter `topic` + frontmatter `tags[]` keys
#   + first-paragraph content-words capped at 50 tokens
#
# Set-of-tokens semantics: case-folded, punctuation-stripped,
# duplicate-collapsed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/index-utils.sh"
. "$SCRIPT_DIR/detail-utils.sh"

# --- Extract feature vector tokens for an entry file ---
# Echoes one token per line on stdout; caller deduplicates.
_jaccard_extract_tokens() {
  local file="$1"
  # Title: from H1 line `# MEMNNN: <title>` (or frontmatter title:)
  local title
  title="$(fm_field "$file" "title" 2>/dev/null || true)"
  if [ -z "$title" ]; then
    title="$(grep -m1 '^# ' "$file" | sed 's/^# [A-Za-z0-9-]*:[[:space:]]*//' || true)"
  fi
  # Topic
  local topic
  topic="$(fm_field "$file" "topic" 2>/dev/null || true)"
  # Tags (space- or comma-separated; this implementation reads tags: line raw)
  local tags
  tags="$(fm_field "$file" "tags" 2>/dev/null || true)"

  # First-paragraph: lines after the second `---` until the first blank
  # line after the H1. Cap at 50 tokens.
  local body_start
  body_start="$(awk '/^---$/{n++; if (n==2) {print NR+1; exit}}' "$file")"
  local first_para
  first_para="$(awk -v s="${body_start:-1}" 'NR>=s {if (/^$/ && got) exit; if (/^# /) { got=1; next } if (got) print}' "$file")"

  # Concatenate all sources, normalize, emit one token per line, cap 50.
  printf "%s %s %s %s\n" "$title" "$topic" "$tags" "$first_para" \
    | tr 'A-Z' 'a-z' \
    | tr -c 'a-z0-9' '\n' \
    | grep -v '^$' \
    | head -50
}

# --- Pairwise Jaccard similarity over deduplicated token sets ---
pairwise_jaccard() {
  local file_a="$1"
  local file_b="$2"
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    echo "FAIL: pairwise_jaccard requires two existing files" >&2
    return 1
  fi
  local tmp_a tmp_b
  tmp_a="$(mktemp)"
  tmp_b="$(mktemp)"
  _jaccard_extract_tokens "$file_a" | sort -u > "$tmp_a"
  _jaccard_extract_tokens "$file_b" | sort -u > "$tmp_b"
  local intersection union
  intersection="$(comm -12 "$tmp_a" "$tmp_b" | wc -l | tr -d ' ')"
  union="$(cat "$tmp_a" "$tmp_b" | sort -u | wc -l | tr -d ' ')"
  rm -f "$tmp_a" "$tmp_b"
  if [ "$union" = "0" ]; then
    echo "similarity=0.0"
    return 0
  fi
  # Use awk for floating-point division (bash 3.2 has no float arithmetic)
  local sim
  sim="$(awk -v i="$intersection" -v u="$union" 'BEGIN{printf "%.4f\n", i/u}')"
  echo "similarity=$sim"
}

# --- Validate subcommand: stub report writer (T05 fills in the analysis) ---
_jaccard_validate() {
  local knowledge_root="$1"
  if [ -z "$knowledge_root" ] || [ ! -d "$knowledge_root" ]; then
    echo "FAIL: validate requires <knowledge-root> directory argument" >&2
    return 1
  fi
  local repo_root
  repo_root="$(get_project_root)"
  local report_dir="$repo_root/.orchestrator/milestones/M020/phases/P01"
  local report="$report_dir/jaccard-validation-report.md"
  mkdir -p "$report_dir"

  # T04 stub header — T05 enriches with full analysis + recommendation.
  {
    echo "# Jaccard Validation Report — M020/P01"
    echo ""
    echo "_Generated by \`scripts/knowledge/lib/jaccard.sh validate\`._"
    echo ""
    echo "## Configuration"
    echo ""
    echo "- threshold (default per A-5): 0.7"
    echo "- feature vector (CON-5): title + topic + tags[] + first-paragraph words capped at 50 tokens"
    echo "- knowledge-root scanned: \`$knowledge_root\`"
    echo ""
    echo "## Pairwise Similarities (above 0.5)"
    echo ""
  } > "$report"

  # Iterate every pair (i<j) under the knowledge root, MEM*.md only.
  local files=( "$knowledge_root"/*/MEM*.md )
  local i j
  local n=${#files[@]}
  for ((i=0; i<n-1; i++)); do
    for ((j=i+1; j<n; j++)); do
      [ ! -f "${files[i]}" ] && continue
      [ ! -f "${files[j]}" ] && continue
      local sim_line
      sim_line="$(pairwise_jaccard "${files[i]}" "${files[j]}")"
      local sim_val
      sim_val="${sim_line#similarity=}"
      # Use awk to gate the > 0.5 reporting condition (bash 3.2 floats)
      local keep
      keep="$(awk -v s="$sim_val" 'BEGIN{print (s>0.5)?"y":"n"}')"
      if [ "$keep" = "y" ]; then
        echo "- \`$(basename "${files[i]}")\` ↔ \`$(basename "${files[j]}")\` — similarity=$sim_val" >> "$report"
      fi
    done
  done

  echo "" >> "$report"
  echo "## Threshold Recommendation" >> "$report"
  echo "" >> "$report"
  echo "_Filled in by T05 based on observed cluster density._" >> "$report"

  echo "WROTE: $report"
}

# --- Subcommand dispatch ---
case "${1:-}" in
  pairwise_jaccard)
    shift; pairwise_jaccard "$@"
    ;;
  validate)
    shift; _jaccard_validate "$@"
    ;;
  "")
    echo "Usage: jaccard.sh {pairwise_jaccard <a> <b> | validate <knowledge-root>}" >&2
    exit 1
    ;;
  *)
    echo "FAIL: unknown subcommand: $1" >&2
    exit 1
    ;;
esac
```

`chmod +x` the file (it is callable both as a sourceable lib and as a CLI
via the dispatch block at the bottom).

### Step 2: Pairwise contract test

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-jaccard-pairwise-contract.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-jaccard-pairwise-contract.sh — exercise pairwise_jaccard
# semantics on synthetic fixtures. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/lib/jaccard.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: jaccard.sh missing or not executable at $SCRIPT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_fixture() {
  local id="$1"
  local title="$2"
  local body="$3"
  cat > "$tmpdir/${id}.md" <<EOF
---
id: ${id}
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
title: "${title}"
topic: "${title}"
tags: ${title}
---

# ${id}: ${title}

${body}
EOF
}

# Identical entries → similarity 1.0
write_fixture MEMA "alpha beta gamma" "shared body content here"
write_fixture MEMB "alpha beta gamma" "shared body content here"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEMA.md" "$tmpdir/MEMB.md")"
case "$sim_line" in
  similarity=1.0000) ;;
  *)
    echo "FAIL: identical entries produced '$sim_line', expected similarity=1.0000"
    exit 1
    ;;
esac

# Disjoint entries → similarity 0.0
write_fixture MEMC "foo bar" "completely different words"
write_fixture MEMD "qux quux" "nothing in common at all whatsoever"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEMC.md" "$tmpdir/MEMD.md")"
sim_val="${sim_line#similarity=}"
# Allow some incidental overlap from common stop-tokens; assert < 0.3
keep="$(awk -v s="$sim_val" 'BEGIN{print (s<0.3)?"y":"n"}')"
if [ "$keep" != "y" ]; then
  echo "FAIL: disjoint entries produced '$sim_line', expected < 0.3"
  exit 1
fi

# Partial overlap entries → similarity in (0, 1)
write_fixture MEME "shared overlap" "alpha beta gamma extra unique words here"
write_fixture MEMF "shared overlap" "alpha beta gamma different unique terms there"
sim_line="$(bash "$SCRIPT" pairwise_jaccard "$tmpdir/MEME.md" "$tmpdir/MEMF.md")"
sim_val="${sim_line#similarity=}"
keep="$(awk -v s="$sim_val" 'BEGIN{print (s>0.3 && s<1.0)?"y":"n"}')"
if [ "$keep" != "y" ]; then
  echo "FAIL: partial-overlap entries produced '$sim_line', expected (0.3, 1.0)"
  exit 1
fi

# Missing-file rejection
if bash "$SCRIPT" pairwise_jaccard "$tmpdir/MISSING.md" "$tmpdir/MEMA.md" 2>/dev/null; then
  echo "FAIL: pairwise_jaccard accepted nonexistent file"
  exit 1
fi

echo "PASS: pairwise_jaccard contract honored (4/4 cases)"
exit 0
```

`chmod +x` the script.

## Must-Haves

- `scripts/knowledge/lib/jaccard.sh` exists, is executable, and exposes both `pairwise_jaccard` and `validate` subcommands.
- Identical-entry pair returns `similarity=1.0000`; disjoint-entry pair returns < 0.3; partial-overlap returns in (0.3, 1.0).
- `validate` subcommand creates the report at [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) and writes the configuration header + the iteration loop output (T05 will enrich with threshold recommendation).
- `scripts/verify/m020-p01-jaccard-pairwise-contract.sh` exists, is executable, and exits 0.

## Verification

```bash
bash scripts/verify/m020-p01-jaccard-pairwise-contract.sh
```

Must print `PASS: pairwise_jaccard contract honored (4/4 cases)` and exit 0.

## Inputs

### From Previous Tasks

- [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) (T01) — informational; cited in the
  generated validation report header. T04 does not depend on schema fields
  for its own functionality (the feature vector reads `title`, `topic`,
  `tags`, body — all pre-existing fields, not the new `status:`).

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — `get_project_root`.
- `scripts/knowledge/lib/detail-utils.sh` — `fm_field` for scalar frontmatter reads.
- `knowledge/patterns/MEM*.md` and `knowledge/conventions/MEM*.md` — exist and have `# MEMNNN: <title>` H1 lines that the title-extraction fallback (`grep -m1 '^# '`) targets when frontmatter `title:` is absent.

## Constraints

- **AD-19**: every `Check:` invocation is single-script-file shape. Pipes inside the implementation are fine; pipes inside `Check:` lines are not.
- **MEM001**: bash 3.2 — `for ((i=0;i<n;i++))` is bash 3.2 safe; `awk` for float arithmetic (no `bc` dependency); no `declare -A`.
- **CON-5**: feature vector is exactly `title + topic + tags[] + first-paragraph words capped at 50 tokens`. Do not add full-body tokenization. The `head -50` cap is the contract.
- **CON-1**: read-only — `pairwise_jaccard` reads files only. `validate` writes only to the report directory under `.orchestrator/milestones/M020/phases/P01/`.
- **MEM003 / MEM008**: structured output (`similarity=...`, `WROTE:`); errors to stderr.

## Expected Output

After this task:

1. `scripts/knowledge/lib/jaccard.sh` exists and is executable.
2. `scripts/verify/m020-p01-jaccard-pairwise-contract.sh` exists, is executable, and exits 0.
3. `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a stub report at [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) (T05 will enrich the recommendation section).

**Done when**: pairwise contract test passes + the report file exists with the configuration header + iteration loop output.
