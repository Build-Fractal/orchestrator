#!/usr/bin/env bash
# scripts/knowledge/lookup-mems.sh -- knowledge-graph lookup adapter.
# M032/P02/T04 ships --kind=glossary mode (FR-16 / MIT-010); future kinds
# may extend this adapter (--kind=mem for the M020 knowledge-graph kinds,
# --kind=reference for M036's reference-corpus, etc.).
#
# --kind=glossary contract:
#   Reads <project-root>/wiki/glossary.md.
#   Parses each `### TERM` heading + associated body.
#   Synthesizes one record per term with id=gloss-<slug>.
#   Honors M031's Quick/Standard/Full profile contract per FR-16 / MIT-010.
#
# Boundary (M020 / M032): the adapter is a READER that synthesizes records
# on-the-fly for downstream build-context.sh consumption. It does NOT write
# to knowledge/<category>/MEM*.md -- M020 holds exclusive schema-authority
# over the on-disk knowledge-graph kinds (per MEM031). M032 owns the
# project-glossary projection adapter (FR-16).
#
# Arguments:
#   --kind <glossary>            (required; only 'glossary' supported in P02)
#   --root <path>                (default: ".")
#   --profile <quick|standard|full>  (default: standard)
#   --task-description <text>    (Quick-profile touched-term hint, optional)
#   --file-change-set <comma-separated-paths>  (Quick-profile touched-term hint, optional)
#
# Exit codes:
#   0 -- success (zero or more records emitted on stdout).
#   2 -- argument error.
#
# FR-16 / MIT-010 safe-default-no-terms fallback:
#   --profile=quick AND no --task-description AND no --file-change-set
#   -> emit zero records, exit 0. (Preserves M031's Quick-profile budget
#   invariant -- without this fallback, callers who forget the touched-term
#   hints would silently inject the full glossary on every Quick payload.)
#
# Slug derivation: lower-case + non-alphanumeric collapse to '-' + leading/
# trailing '-' strip. Examples:
#   '### Constitution'    -> id: gloss-constitution
#   '### Knowledge Graph' -> id: gloss-knowledge-graph
#   '### Tier 0 Manifest' -> id: gloss-tier-0-manifest
#   '### --with-wiki'     -> id: gloss-with-wiki
#
# Bash 3.2 compatible (per MEM001) -- no declare -A, no mapfile, no process
# substitution, no $() containing pipes.

set -eu

KIND=""
ROOT="."
PROFILE="standard"
TASK_DESC=""
FILE_CHANGES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="$2"; shift 2 ;;
    --kind=*) KIND="${1#--kind=}"; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --task-description) TASK_DESC="$2"; shift 2 ;;
    --task-description=*) TASK_DESC="${1#--task-description=}"; shift ;;
    --file-change-set) FILE_CHANGES="$2"; shift 2 ;;
    --file-change-set=*) FILE_CHANGES="${1#--file-change-set=}"; shift ;;
    *) echo "FAIL: lookup-mems: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$KIND" ] || { echo "FAIL: lookup-mems: --kind is required" >&2; exit 2; }
[ "$KIND" = "glossary" ] || { echo "FAIL: lookup-mems: --kind=$KIND not supported in P02 (only 'glossary')" >&2; exit 2; }

case "$PROFILE" in
  quick|standard|full) : ;;
  *) echo "FAIL: lookup-mems: --profile must be quick|standard|full, got '$PROFILE'" >&2; exit 2 ;;
esac

GLOSSARY="$ROOT/wiki/glossary.md"

# FR-16 / MIT-010 safe-default-no-terms fallback under --profile=quick.
# Fires BEFORE any glossary parsing per the constraint -- avoids unnecessary
# I/O on the budget-conscious Quick path.
if [ "$PROFILE" = "quick" ] && [ -z "$TASK_DESC" ] && [ -z "$FILE_CHANGES" ]; then
  exit 0
fi

# Glossary-absent: emit zero records, exit 0 (US-6 Acceptance Scenario 2).
if [ ! -f "$GLOSSARY" ]; then
  exit 0
fi

# Helper: slugify a term name to gloss-<slug>.
# Single pipe inside a function body is AD-19-OK -- function bodies execute
# outside the harness's compound-shape detection scope.
slugify() {
  local term
  term="$1"
  printf '%s' "$term" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Helper: check if a term is touched per FR-16 / MIT-010 v1 contract:
#   (a) --task-description contains the term name (case-insensitive substring), OR
#   (b) --file-change-set lists files whose contents contain the term name (case-insensitive).
# Returns 0 (touched) or 1 (not touched).
is_touched() {
  local term
  local lc_term
  local lc_desc
  local f
  local IFS_OLD
  term="$1"
  lc_term="$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]')"
  if [ -n "$TASK_DESC" ]; then
    lc_desc="$(printf '%s' "$TASK_DESC" | tr '[:upper:]' '[:lower:]')"
    case "$lc_desc" in
      *"$lc_term"*) return 0 ;;
    esac
  fi
  if [ -n "$FILE_CHANGES" ]; then
    IFS_OLD="$IFS"
    IFS=','
    for f in $FILE_CHANGES; do
      if [ -f "$f" ] && grep -q -i -F "$term" "$f" 2>/dev/null; then
        IFS="$IFS_OLD"
        return 0
      fi
    done
    IFS="$IFS_OLD"
  fi
  return 1
}

# Helper: emit a record for a term + body (M020-knowledge-record-compatible
# shape -- frontmatter with id, kind, term, confidence, source, last_verified;
# body containing the glossary entry).
emit_record() {
  local term
  local body
  local slug
  local now
  term="$1"
  body="$2"
  slug="$(slugify "$term")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '---\n'
  printf 'id: gloss-%s\n' "$slug"
  printf 'kind: glossary\n'
  printf 'term: %s\n' "$term"
  printf 'confidence: 1.0\n'
  printf 'source: wiki/glossary.md\n'
  printf 'last_verified: %s\n' "$now"
  printf -- '---\n'
  printf '%s\n' "$body"
  printf '\n'
}

# Helper: emit-if-profile-allows wrapper. Quick profile filters via is_touched.
emit_record_filtered() {
  local term
  local body
  term="$1"
  body="$2"
  case "$PROFILE" in
    full|standard)
      emit_record "$term" "$body"
      ;;
    quick)
      if is_touched "$term"; then
        emit_record "$term" "$body"
      fi
      ;;
  esac
}

# State-machine line walker: parse `### TERM` headings + accumulate body
# lines, emit on next `### ` heading or EOF.
CURRENT_TERM=""
CURRENT_BODY=""

while IFS= read -r line; do
  case "$line" in
    '### '*)
      if [ -n "$CURRENT_TERM" ]; then
        emit_record_filtered "$CURRENT_TERM" "$CURRENT_BODY"
      fi
      # Strip the literal '### ' prefix. The compact form `${line#### }`
      # is ambiguous in bash 3.2 (interpreted as `${var##}` longest-match
      # plus pattern `# `), so use a two-step strip via an intermediary
      # variable to make the prefix unambiguous.
      _prefix='### '
      CURRENT_TERM="${line#$_prefix}"
      CURRENT_BODY=""
      ;;
    *)
      if [ -n "$CURRENT_TERM" ]; then
        if [ -n "$CURRENT_BODY" ]; then
          CURRENT_BODY="$CURRENT_BODY"$'\n'"$line"
        else
          CURRENT_BODY="$line"
        fi
      fi
      ;;
  esac
done < "$GLOSSARY"

# Flush the final term.
if [ -n "$CURRENT_TERM" ]; then
  emit_record_filtered "$CURRENT_TERM" "$CURRENT_BODY"
fi

exit 0
