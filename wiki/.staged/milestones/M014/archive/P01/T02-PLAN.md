---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M014"
name: "scripts/verify/spec-shape-lint.sh FR-4 verifier (template-derived required-section list)"
depends_on: ["T01"]
---

## Prerequisites

Upstream T01 must be green: `templates/spec-template.md` exists as the Section Contract SSOT.

Pre-existing disk state:

- `scripts/verify/` exists with many existing verifier scripts.
- `scripts/verify/anti-pattern-lint.sh` is the Bash 3.2 + shape-lint compliance verifier.
- `specs/024-spec-management-extended/spec.md` is a fully-authored spec (zero `<TODO>` placeholders) and can serve as a positive-test fixture target.

## Description

Ship `scripts/verify/spec-shape-lint.sh` — the FR-4 verifier that reads any target spec markdown file and asserts it conforms to the FR-2 Section Contract. The required-section list is **derived at runtime from `templates/spec-template.md`** (not hardcoded) — when the template changes, the linter automatically tracks.

The linter is consumed by:

- `orchestrator:discuss` as a preflight (in a later M014 phase — P01 ships the linter so the surface exists; `orchestrator:discuss` does not yet invoke it in P01).
- T06's FR-18 fixture test to assert scaffolded specs pass shape lint.
- Future CI / operator tooling.

## Steps

### Step 1: Create `scripts/verify/spec-shape-lint.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# scripts/verify/spec-shape-lint.sh — FR-4 spec shape verifier.
# Derives required-section list from templates/spec-template.md (SSOT)
# and asserts the target spec conforms.
#
# Usage: spec-shape-lint.sh <spec-path> [--template <path>] [--help]
#
# Emits to stdout:
#   checks=<N> passed=<M> failed=<K>
#   todo_count=<N>   (informational; not a fail condition)
# Emits to stderr: one line per failed check.
# Exit 0 when failed=0; exit 1 otherwise.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
SPEC_PATH=""

usage() {
  cat <<'EOF'
Usage: spec-shape-lint.sh <spec-path> [--template <path>]

Verifies the target markdown spec conforms to the FR-2 Section Contract
derived from templates/spec-template.md.

Arguments:
  <spec-path>           Path to the spec markdown file to lint.
  --template <path>     Override the default templates/spec-template.md SSOT.
  --help                Print this message.

Exit codes:
  0    All structural checks passed (todo_count may be non-zero).
  1    At least one required section is missing, out of order, or a
       required frontmatter field is absent.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --template)
      if [ $# -lt 2 ]; then echo "--template requires a path" >&2; exit 1; fi
      TEMPLATE="$2"; shift 2
      ;;
    -*)
      echo "spec-shape-lint.sh: unknown flag: $1" >&2; exit 1
      ;;
    *)
      if [ -z "$SPEC_PATH" ]; then SPEC_PATH="$1"; shift
      else echo "spec-shape-lint.sh: unexpected positional: $1" >&2; exit 1
      fi
      ;;
  esac
done

if [ -z "$SPEC_PATH" ]; then
  echo "spec-shape-lint.sh: missing <spec-path>" >&2; usage >&2; exit 1
fi
if [ ! -f "$SPEC_PATH" ]; then
  echo "spec-shape-lint.sh: spec file not found: $SPEC_PATH" >&2; exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "spec-shape-lint.sh: template not found: $TEMPLATE" >&2; exit 1
fi

CHECKS=0
PASSED=0
FAILED=0
FAIL_LINES=""

record_pass() {
  CHECKS=$((CHECKS + 1)); PASSED=$((PASSED + 1))
}
record_fail() {
  CHECKS=$((CHECKS + 1)); FAILED=$((FAILED + 1))
  FAIL_LINES="${FAIL_LINES}$1\n"
}

# --- Derive required headings from template (lines starting with '#') ---
TEMPLATE_HEADINGS="$(mktemp)"
grep -E '^#+[[:space:]]' "$TEMPLATE" > "$TEMPLATE_HEADINGS"

SPEC_HEADINGS="$(mktemp)"
grep -E '^#+[[:space:]]' "$SPEC_PATH" > "$SPEC_HEADINGS"

# --- Check 1: every required top-level heading (##) is present in the spec ---
# Template headings may carry {{placeholders}}; normalize by dropping
# everything after the first '{{' or '<' before comparing, to accept
# scaffolded values that have been filled in.
normalize() {
  # Strip trailing placeholder/TODO suffixes so template-{{slug}} matches a
  # scaffolded '001-my-feature'. POSIX sed.
  sed -e 's/{{[^}]*}}//g' -e 's/<TODO:[^>]*>//g' -e 's/[[:space:]]*$//' "$1"
}

TEMPLATE_NORM="$(mktemp)"
SPEC_NORM="$(mktemp)"
normalize "$TEMPLATE_HEADINGS" > "$TEMPLATE_NORM"
normalize "$SPEC_HEADINGS" > "$SPEC_NORM"

# Step through template headings; for each, find its position in spec.
PREV_POS=0
OUT_OF_ORDER=0
MISSING=""
while IFS= read -r heading_line; do
  if [ -z "$heading_line" ]; then continue; fi
  # Search for this heading in spec headings; awk emits line number of first match.
  POS="$(awk -v target="$heading_line" 'index($0, target){ print NR; exit }' "$SPEC_NORM")"
  if [ -z "$POS" ]; then
    MISSING="${MISSING}${heading_line}\n"
  else
    if [ "$POS" -lt "$PREV_POS" ]; then
      OUT_OF_ORDER=1
    fi
    PREV_POS="$POS"
  fi
done < "$TEMPLATE_NORM"

if [ -z "$MISSING" ]; then
  record_pass
else
  record_fail "missing required sections:\n${MISSING}"
fi

if [ "$OUT_OF_ORDER" -eq 0 ]; then
  record_pass
else
  record_fail "required sections appear out of order in spec"
fi

# --- Check 2: required frontmatter fields ---
check_frontmatter_field() {
  local field="$1"
  if head -20 "$SPEC_PATH" | grep -q -E "^(\*\*${field}\*\*|${field}):"; then
    record_pass
  else
    record_fail "frontmatter missing required field: ${field}"
  fi
}

check_frontmatter_field "Feature Branch"
check_frontmatter_field "Created"
check_frontmatter_field "Status"
check_frontmatter_field "Milestone"
check_frontmatter_field "Input"

# --- Check 3: required subsections present ---
check_subsection() {
  local pattern="$1"
  local label="$2"
  if grep -q -E "$pattern" "$SPEC_PATH"; then
    record_pass
  else
    record_fail "missing required subsection: ${label}"
  fi
}

check_subsection '^### Minimal Slice' "Minimal Slice"
check_subsection '^### Knowledge-Layer Boundary' "Knowledge-Layer Boundary"
check_subsection '^### User Story [0-9]+' "User Story N"

# --- Informational: TODO count ---
TODO_COUNT="$(grep -cE '<TODO:' "$SPEC_PATH" || true)"

rm -f "$TEMPLATE_HEADINGS" "$SPEC_HEADINGS" "$TEMPLATE_NORM" "$SPEC_NORM"

echo "checks=${CHECKS} passed=${PASSED} failed=${FAILED}"
echo "todo_count=${TODO_COUNT}"

if [ "$FAILED" -gt 0 ]; then
  printf "%b" "$FAIL_LINES" >&2
  exit 1
fi
exit 0
```

Make executable: `chmod +x scripts/verify/spec-shape-lint.sh`.

### Step 2: Create the gate verifier `scripts/verify/m014-p01-spec-shape-lint.sh`

Exercises three cases: scaffolded-shape template itself should pass (all required sections present); a missing-section fixture should fail; an authored fully-populated spec should pass.

```bash
#!/usr/bin/env bash
# scripts/verify/m014-p01-spec-shape-lint.sh — gate for T02.
# Verifies spec-shape-lint.sh behavior on three fixture cases.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/spec-shape-lint.sh"
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"

if [ ! -x "$LINT" ]; then
  echo "FAIL: scripts/verify/spec-shape-lint.sh missing or not executable" >&2
  exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: templates/spec-template.md missing (T01 not shipped)" >&2
  exit 1
fi

# Case 1: lint against the template itself.
# Template has {{placeholder}} for Feature Branch etc. inside the frontmatter block,
# and every required heading is present. Expected: lint exits 0 (structural PASS)
# with todo_count > 0.
OUTPUT="$(bash "$LINT" "$TEMPLATE" 2>/dev/null || true)"
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: lint against template exited non-zero (expected 0); output: $OUTPUT" >&2
  exit 1
fi
echo "$OUTPUT" | grep -qE '^checks=' || { echo "FAIL: missing checks= line" >&2; exit 1; }
echo "$OUTPUT" | grep -qE '^todo_count=[1-9]' || { echo "FAIL: template should have non-zero todo_count" >&2; exit 1; }

# Case 2: lint against a spec with a missing required section — expect exit 1.
BAD_FIXTURE="$(mktemp)"
cat > "$BAD_FIXTURE" <<'EOF'
# Feature Specification: Bad

**Feature Branch**: `bad`
**Created**: 2026-04-22
**Status**: Draft
**Milestone**: M999
**Input**: test

## Problem Statement

Missing other required sections.
EOF
bash "$LINT" "$BAD_FIXTURE" >/dev/null 2>&1
RC=$?
rm -f "$BAD_FIXTURE"
if [ $RC -eq 0 ]; then
  echo "FAIL: lint against incomplete fixture exited 0 (expected 1)" >&2
  exit 1
fi

# Case 3: lint against specs/024-spec-management-extended/spec.md (fully authored).
AUTHORED="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ -f "$AUTHORED" ]; then
  bash "$LINT" "$AUTHORED" >/dev/null 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "FAIL: lint against specs/024-spec-management-extended/spec.md exited non-zero" >&2
    exit 1
  fi
fi

echo "PASS: scripts/verify/spec-shape-lint.sh behaves on all three fixture cases"
exit 0
```

Make executable: `chmod +x scripts/verify/m014-p01-spec-shape-lint.sh`.

## Must-Haves

- `scripts/verify/spec-shape-lint.sh` exists, is executable, and implements the FR-4 contract (derives required sections from template; exits 0 on conforming specs, 1 otherwise)
- The linter supports `--help` and `--template <path>`
- The linter emits `checks=N passed=M failed=K` and `todo_count=N` on stdout
- Failed checks print one line per failure on stderr
- The linter passes against `templates/spec-template.md` (structural PASS; `todo_count > 0`)
- The linter passes against `specs/024-spec-management-extended/spec.md` (authored spec — `failed=0`)
- The linter fails against a contrived missing-sections fixture (exit 1)
- `scripts/verify/m014-p01-spec-shape-lint.sh` exists, is executable, exits 0
- Both scripts are Bash 3.2 compatible and pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-spec-shape-lint.sh
```

Expected: stdout `PASS: scripts/verify/spec-shape-lint.sh behaves on all three fixture cases`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/spec-shape-lint.sh
```

Expected: exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p01-spec-shape-lint.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- `templates/spec-template.md` (from T01)
  - Key API: file shape — every required heading is on a line starting with `#+ `; every section body contains `<TODO: ...>`.
  - Key types: markdown file with YAML frontmatter block and standard heading hierarchy.

### From Disk (Pre-existing)

- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier (invoked post-authoring).
- `specs/024-spec-management-extended/spec.md` — authored reference spec, used as Case 3 positive-test fixture.

## Constraints

- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution `<(...)`, no `&>`, no `$(cmd | pipe)` in Check scripts.
- Required-section list derives from the template at runtime; no hardcoded section names (template-SSOT discipline per Principle X Templating Over Inference).
- Linter output format is stable: `checks=N passed=M failed=K` and `todo_count=N` lines; downstream consumers parse these.
- Linter exits with well-defined codes: 0 = conforming, 1 = any structural failure.

## Expected Output

Two shell scripts committed:

1. `scripts/verify/spec-shape-lint.sh` — FR-4 verifier (~150 lines, executable)
2. `scripts/verify/m014-p01-spec-shape-lint.sh` — gate verifier (~60 lines, executable)

Running `bash scripts/verify/m014-p01-spec-shape-lint.sh` exits 0 with `PASS: ...`.
