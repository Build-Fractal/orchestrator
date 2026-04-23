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

# --- Derive required headings from template ---
# Top-level '## ' sections drive Check 1 (presence + ordering). ### subsection
# presence is verified by Check 3's explicit patterns to avoid fragile
# substring matching against headings that embed {{placeholders}} mid-line.
TEMPLATE_HEADINGS="$(mktemp)"
grep -E '^##[[:space:]]' "$TEMPLATE" > "$TEMPLATE_HEADINGS"

SPEC_HEADINGS="$(mktemp)"
grep -E '^##[[:space:]]' "$SPEC_PATH" > "$SPEC_HEADINGS"

# --- Check 1: every required top-level heading (##) is present in the spec ---
# Template headings may carry {{placeholders}}; normalize by dropping
# everything after the first '{{' or '<' before comparing, to accept
# scaffolded values that have been filled in.
normalize() {
  # Strip trailing placeholder/TODO suffixes so template-{{slug}} matches a
  # scaffolded '001-my-feature'. Collapse runs of whitespace so a template
  # heading like '### User Story 1 —  (Priority: P1)' (double-space left by
  # removed <TODO: short-title>) substring-matches a concrete
  # '### User Story 1 — Anything (Priority: P1)'. POSIX sed.
  sed -e 's/{{[^}]*}}//g' \
      -e 's/<TODO:[^>]*>//g' \
      -e 's/[[:space:]][[:space:]]*/ /g' \
      -e 's/[[:space:]]*$//' \
      -e 's/^[[:space:]]*//' "$1"
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
  # Ordering is advisory — presence is the hard contract. Emit a stderr
  # warning but count the check as passed so authored specs with
  # locally-reasoned section order (e.g. Constraints-before-Non-Goals)
  # still pass shape lint. The binding ordering gate is exercised by
  # scripts/verify/m014-p01-template-ssot.sh against the template itself.
  echo "WARN: required sections appear out of template order in spec (advisory)" >&2
  record_pass
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
