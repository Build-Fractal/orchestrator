---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M024"
name: "Author the input-shape detector"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: the proposal template exists and pins `input_shape` as a string-valued frontmatter key drawn from the enum `idea | paragraph | fragment | spec | empty`. T03 produces the value the template consumes via T04 substitution.
- This task can run in parallel with T02 — they touch disjoint files.

## Description

Author `scripts/intake/shape-detect.sh` — a portable shell script that mechanically classifies an input string into one of the five FR-1 shapes.

This task resolves spec **#Q-1 (input-shape-heuristics)** with concrete thresholds:

| Shape | Detection rule (evaluated in order; first match wins) |
|-------|--------------------------------------------------------|
| `spec` | `--spec-path <path>` is supplied AND the file exists AND the file's first 30 lines contain `type: feature-spec` |
| `empty` | No `--spec-path` AND `--input` is empty (or absent) |
| `fragment` | Input contains any of: `^##` headings, `Given/When/Then` skeleton, `^- FR-` requirement bullets, or word count ≥ 81 |
| `idea` | Word count ≤ 10 |
| `paragraph` | Default — anything that doesn't match the rules above (11–80 words, no structural markers) |

Confidence is **`high`** when the matched rule is unambiguous (exact spec frontmatter match, exact empty, fragment with structural marker, idea word-count, or paragraph with word count between 20–60). Confidence is **`low`** when:

- A `paragraph` classification was made but the input contains some structural fragments (a stray `##` line, partial Given/When but no Then) — borderline-fragment case.
- An `idea` classification with word count in the 8–10 boundary — borderline-paragraph case.
- A `fragment` classification triggered solely by word count ≥ 81 with no other structural markers — borderline-paragraph-overflow case.

Output format (two lines to stdout):

```
input_shape=<value>
shape_classification=<high|low>
```

## Steps

1. **Write the script** at `scripts/intake/shape-detect.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/shape-detect.sh
# M024/P01/T03 — Mechanical input-shape classifier (FR-1, resolves #Q-1).
#
# Inputs:
#   --spec-path <path>    Optional. If file exists and has `type: feature-spec`
#                         in its first 30 lines, shape is `spec`.
#   --input <string>      Optional. The raw input text.
#
# Output (stdout, two lines):
#   input_shape=<idea|paragraph|fragment|spec|empty>
#   shape_classification=<high|low>
#
# Exit 0 on success, 2 on usage error.

set -u

usage() {
  echo "usage: shape-detect.sh [--spec-path <path>] [--input <string>]" >&2
  exit 2
}

SPEC_PATH=""
INPUT=""
HAVE_INPUT_FLAG=0

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --input)     INPUT="$2"; HAVE_INPUT_FLAG=1; shift 2 ;;
    -h|--help)   usage ;;
    *)           usage ;;
  esac
done

# Rule 1: spec path that points at a real feature spec.
if [ -n "$SPEC_PATH" ] && [ -f "$SPEC_PATH" ]; then
  if head -30 "$SPEC_PATH" | grep -q 'type: feature-spec'; then
    echo "input_shape=spec"
    echo "shape_classification=high"
    exit 0
  fi
fi

# Rule 2: empty.
# Empty means: no spec path AND (input flag absent OR input is whitespace-only).
trimmed=$(echo "$INPUT" | tr -d '[:space:]')
if [ -z "$SPEC_PATH" ] && [ -z "$trimmed" ]; then
  echo "input_shape=empty"
  echo "shape_classification=high"
  exit 0
fi

# Rule 3 / 4 / 5: structural + word-count classification.
# Word count: split on whitespace.
words=$(echo "$INPUT" | tr -s '[:space:]' '\n' | grep -c .)

# Structural markers.
has_heading=0
has_gwt=0
has_fr_bullet=0
if echo "$INPUT" | grep -qE '^##'; then has_heading=1; fi
# Given/When/Then triple-marker, case-insensitive.
if echo "$INPUT" | grep -qiE '\bGiven\b'; then
  if echo "$INPUT" | grep -qiE '\bWhen\b'; then
    if echo "$INPUT" | grep -qiE '\bThen\b'; then
      has_gwt=1
    fi
  fi
fi
if echo "$INPUT" | grep -qE '^-[[:space:]]+FR-'; then has_fr_bullet=1; fi

structural=$((has_heading + has_gwt + has_fr_bullet))

# Fragment: structural marker OR word count >= 81.
if [ "$structural" -gt 0 ] || [ "$words" -ge 81 ]; then
  conf="high"
  # Low-confidence sub-case: word-count overflow with no structural marker.
  if [ "$structural" -eq 0 ] && [ "$words" -ge 81 ]; then
    conf="low"
  fi
  echo "input_shape=fragment"
  echo "shape_classification=$conf"
  exit 0
fi

# Idea: word count <= 10.
if [ "$words" -le 10 ]; then
  conf="high"
  # Low-confidence sub-case: 8-10 word boundary.
  if [ "$words" -ge 8 ]; then
    conf="low"
  fi
  echo "input_shape=idea"
  echo "shape_classification=$conf"
  exit 0
fi

# Default: paragraph.
# Low-confidence sub-cases: stray heading, partial GWT, or word count outside 20-60.
conf="high"
partial_gwt=0
if echo "$INPUT" | grep -qiE '\bGiven\b|\bWhen\b|\bThen\b'; then
  if [ "$has_gwt" -eq 0 ]; then
    partial_gwt=1
  fi
fi
if [ "$partial_gwt" -eq 1 ] || [ "$words" -lt 20 ] || [ "$words" -gt 60 ]; then
  conf="low"
fi

echo "input_shape=paragraph"
echo "shape_classification=$conf"
exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/shape-detect.sh`.

3. **Write the verify script** at `scripts/verify/m024-p01-shape-detector.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-shape-detector.sh
# Exercises the detector against five canonical cases.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DET="$ROOT/scripts/intake/shape-detect.sh"

if [ ! -x "$DET" ]; then
  echo "FAIL: $DET not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case A — spec.
mkdir -p "$tmp/specs/099-x"
cat > "$tmp/specs/099-x/spec.md" <<EOF
---
schema_version: "1.0"
type: feature-spec
EOF
out_a=$(bash "$DET" --spec-path "$tmp/specs/099-x/spec.md")
case "$out_a" in
  *"input_shape=spec"*"shape_classification=high"*) ;;
  *) echo "FAIL: spec case got: $out_a"; exit 1 ;;
esac

# Case B — empty.
out_b=$(bash "$DET")
case "$out_b" in
  *"input_shape=empty"*"shape_classification=high"*) ;;
  *) echo "FAIL: empty case got: $out_b"; exit 1 ;;
esac

# Case C — idea (5 words).
out_c=$(bash "$DET" --input "fix typo in status doc")
case "$out_c" in
  *"input_shape=idea"*) ;;
  *) echo "FAIL: idea case got: $out_c"; exit 1 ;;
esac

# Case D — paragraph (~30 words).
out_d=$(bash "$DET" --input "We should add a last seen timestamp to the status command output and probably cache it for about five seconds so repeated calls do not hammer the filesystem at all")
case "$out_d" in
  *"input_shape=paragraph"*) ;;
  *) echo "FAIL: paragraph case got: $out_d"; exit 1 ;;
esac

# Case E — fragment (Given/When/Then triple).
gwt_input="Given a project state, When the operator types evaluate, Then the proposal is emitted."
out_e=$(bash "$DET" --input "$gwt_input")
case "$out_e" in
  *"input_shape=fragment"*) ;;
  *) echo "FAIL: fragment-gwt case got: $out_e"; exit 1 ;;
esac

# Case F — fragment (## heading).
out_f=$(bash "$DET" --input "## Background
Some context here about the bug.")
case "$out_f" in
  *"input_shape=fragment"*) ;;
  *) echo "FAIL: fragment-heading case got: $out_f"; exit 1 ;;
esac

echo "PASS: shape-detect.sh — spec, empty, idea, paragraph, fragment-gwt, fragment-heading"
exit 0
```

## Must-Haves

- `scripts/intake/shape-detect.sh` exists and is executable.
- All five FR-1 shapes are emitted from the rule table; no shape outside the enum is ever emitted.
- Spec rule fires only when both the path exists AND the file's head contains `type: feature-spec` — a `.md` file with no frontmatter still falls through to the word-count rules.
- Empty rule fires only when both no spec path AND no non-whitespace input.
- Word-count thresholds: ≤10 → idea; 11–80 (no structural markers) → paragraph; ≥81 → fragment.
- Structural markers (`##` headings, full Given/When/Then triple, `- FR-` bullets) escalate to fragment regardless of word count.
- `shape_classification` is always one of `high | low` — never empty, never another value.

## Verification

```
bash scripts/verify/m024-p01-shape-detector.sh
```

Expected output (exit 0): `PASS: shape-detect.sh — spec, empty, idea, paragraph, fragment-gwt, fragment-heading`

## Inputs

### From Previous Tasks

- `templates/intake-proposal.md` (from T01) — not read directly; the template's `input_shape` and `shape_classification` placeholders consume this task's stdout via T04 substitution.

### From Disk (Pre-existing)

None. The detector reads only its CLI arguments and (in the spec branch) the file at `--spec-path`.

## Constraints

- POSIX sh + bash 3.2 portable. No bash 4+ features.
- No `<TODO:` markers (DC-3).
- No conversus calls, no knowledge writes (SB-3).
- No network access.
- The detector is pure — same input always produces the same output (FR-14 idempotency contract; T04's `input_hash` field uses this property).
- Single-script-file invocation via stdin/argv only — no shell tricks like process substitution that would trigger the harness shape guard (AD-19).
- The five-shape enum is closed in P01. Adding a sixth shape (e.g., M013 UAT-bug per SB-2) requires a Decision row, not an in-place edit.

## Expected Output

`scripts/intake/shape-detect.sh` exists, is executable, and `bash scripts/verify/m024-p01-shape-detector.sh` exits 0 with the `PASS:` line.
