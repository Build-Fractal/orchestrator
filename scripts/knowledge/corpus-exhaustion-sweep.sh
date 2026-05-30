#!/usr/bin/env bash
# scripts/knowledge/corpus-exhaustion-sweep.sh — M042/P01 deterministic corpus-exhaustion sweep
#
# Given a set of candidate questions and a store manifest, this script sweeps
# every reachable knowledge store for each question (cheap, deterministic
# case-insensitive grep), records what it found, and writes a corpus-exhaustion
# artifact: per question — search terms, stores searched, hit citations, and a
# verdict. It computes a top-level PASS|BLOCK verdict and writes it into the
# artifact frontmatter. The wrapping adapter (corpus-gate.sh) owns the
# enabled/disabled + SKIPPED policy and maps the verdict to an exit code.
#
# This is the P01 deterministic floor — NO LLM. A grep hit is a *candidate*
# answer, not a proven one: the gate forces "read before ask" by marking
# hit-bearing questions HITS (pending) until the agent dispositions them. The
# P03 judge upgrades HITS into semantic ANSWERED/PARTIAL/MENTIONS verdicts.
#
# Verdict per question:
#   CLEAN                    zero hits, all required stores searched — safe to ask
#   HITS                     >=1 hit, not yet dispositioned — BLOCKS (read first)
#   DROPPED                  >=1 hit, dispositioned @disposition=dropped — answered, removed from packet
#   KEPT                     >=1 hit, dispositioned @disposition=kept — genuinely open, stays in packet
#   IRREDUCIBLE-WITH-CAVEAT  zero hits but a required store was unreachable — surfaced with caveat
#
# Top-level verdict: BLOCK iff any question is HITS (pending). Else PASS.
#
# Disposition annotations live on the question line (so re-sweeps are
# reproducible — the questions file is the input-of-record):
#   [Q1] Does the spec require frobnication?  @disposition=dropped reason: answered in DR-012
#   [Q2] What is the SME sign-off deadline?   @disposition=kept reason: not in corpus
#
# CON-1: Bash 3.2 compatible (no associative arrays, no mapfile, no in-place
#        case-modification parameter expansion, no process substitution).
#        CON-7: no date/$RANDOM — timestamps are
#        caller-supplied via --generated-at so fixtures are byte-stable.
#
# Usage:
#   corpus-exhaustion-sweep.sh --questions <file> --checkpoint <name> \
#     [--manifest <file>] [--out <path>] [--repo-root <path>] \
#     [--generated-at <iso8601>] [--max-hits <n>] [--max-terms <n>] [--strict]
#
# Exit codes (mechanism layer — policy/verdict→exit mapping lives in the adapter):
#   0  artifact written successfully (verdict is inside the artifact)
#   1  usage / input error (missing questions file; missing manifest in --strict)

set -u

# --- argument parsing -------------------------------------------------------

QUESTIONS_FILE=""
SINGLE_QUESTION=""
CHECKPOINT="unspecified"
MANIFEST=""
OUT=""
REPO_ROOT=""
GENERATED_AT="unset"
MAX_HITS=5
MAX_TERMS=12
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --questions)     QUESTIONS_FILE="$2"; shift 2 ;;
    --question)      SINGLE_QUESTION="$2"; shift 2 ;;
    --checkpoint)    CHECKPOINT="$2"; shift 2 ;;
    --manifest)      MANIFEST="$2"; shift 2 ;;
    --out)           OUT="$2"; shift 2 ;;
    --repo-root)     REPO_ROOT="$2"; shift 2 ;;
    --generated-at)  GENERATED_AT="$2"; shift 2 ;;
    --max-hits)      MAX_HITS="$2"; shift 2 ;;
    --max-terms)     MAX_TERMS="$2"; shift 2 ;;
    --strict)        STRICT=1; shift ;;
    -h|--help)
      grep -E '^# ' "$0" | sed -E 's/^# ?//'
      exit 0
      ;;
    *)
      echo "corpus-exhaustion-sweep.sh: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

_fail() { echo "FAIL: $*" >&2; }

# --- repo root resolution ---------------------------------------------------

_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$REPO_ROOT" ]; then
  # scripts/knowledge/ -> repo root is two levels up.
  REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
fi
if [ ! -d "$REPO_ROOT" ]; then
  _fail "repo root not a directory: $REPO_ROOT"
  exit 1
fi

# --- manifest resolution ----------------------------------------------------
# Precedence: --manifest > bundled default at templates/corpus-store-manifest.yml
# (the adapter resolves the config-configured path before calling us). A missing
# manifest is a usage error in --strict mode; otherwise we synthesize an empty
# sweep that PASSes (graceful degradation — the adapter normally intercepts the
# disabled/absent case and emits SKIPPED before reaching here).
if [ -z "$MANIFEST" ]; then
  MANIFEST="$REPO_ROOT/templates/corpus-store-manifest.yml"
fi
if [ ! -f "$MANIFEST" ]; then
  if [ "$STRICT" = "1" ]; then
    _fail "store manifest not found: $MANIFEST (strict mode)"
    exit 1
  fi
  echo "SKIPPED: store manifest not found ($MANIFEST) — sweep produced no gate" >&2
fi

# --- collect questions ------------------------------------------------------
# Questions arrive as newline records in a temp list. Bash 3.2: no arrays for
# the cross-function set; we re-read the questions file in the main loop.
if [ -n "$SINGLE_QUESTION" ]; then
  _Q_TMP="$(mktemp -t corpus-q.XXXXXX)"
  printf '%s\n' "$SINGLE_QUESTION" > "$_Q_TMP"
  QUESTIONS_FILE="$_Q_TMP"
  trap 'rm -f "$_Q_TMP"' EXIT
fi
if [ -z "$QUESTIONS_FILE" ] || [ ! -f "$QUESTIONS_FILE" ]; then
  _fail "questions file not found (pass --questions <file> or --question <text>)"
  exit 1
fi

# --- manifest parsing -------------------------------------------------------
# Parse the `stores:` list from the YAML manifest into newline records of the
# form "<label>|<glob>|<required>". Bash 3.2 / awk-only (no yq).
_parse_manifest() {
  [ -f "$MANIFEST" ] || return 0
  awk '
    BEGIN { in_stores = 0; label=""; glob=""; req="false" }
    /^stores:[[:space:]]*$/ { in_stores = 1; next }
    in_stores && /^[a-zA-Z]/ { in_stores = 0 }   # left the block (next top-level key)
    in_stores {
      line = $0
      if (line ~ /^[[:space:]]*-[[:space:]]*label:/) {
        # flush previous entry
        if (label != "") { print label "|" glob "|" req }
        label = line; sub(/^[[:space:]]*-[[:space:]]*label:[[:space:]]*/, "", label)
        gsub(/"/, "", label); sub(/[[:space:]]*$/, "", label)
        glob=""; req="false"
        next
      }
      if (line ~ /^[[:space:]]+glob:/) {
        glob = line; sub(/^[[:space:]]+glob:[[:space:]]*/, "", glob)
        gsub(/"/, "", glob); sub(/[[:space:]]*$/, "", glob); next
      }
      if (line ~ /^[[:space:]]+required:/) {
        req = line; sub(/^[[:space:]]+required:[[:space:]]*/, "", req)
        gsub(/"/, "", req); sub(/[[:space:]]*$/, "", req); next
      }
    }
    END { if (label != "") print label "|" glob "|" req }
  ' "$MANIFEST"
}

# Resolve a store glob (repo-root-relative) to a newline list of existing,
# readable paths (files or directories — grep -r recurses into dirs). Uses
# nullglob so non-matching globs vanish rather than passing through literally.
_resolve_glob() {
  _rg_glob="$1"
  ( cd "$REPO_ROOT" 2>/dev/null || exit 0
    shopt -s nullglob 2>/dev/null || true
    # shellcheck disable=SC2086 # intentional glob expansion
    for _p in $_rg_glob; do
      if [ -e "$_p" ]; then
        printf '%s\n' "$_p"
      fi
    done
  )
}

# --- term extraction (deterministic, FR-2) ----------------------------------
# Strips the [id] prefix and any trailing @disposition= annotation, then pulls:
#   structured IDs  (§N.N, FR-N, SC-N, US-N, AS-N, DR-N, generic AAA-N)
#   ISO dates       (YYYY-MM-DD)
#   quoted phrases  ("..." kept as a single fixed-string term)
#   significant tokens (alnum runs length >= 4, minus a stopword list)
# Emits a newline list of unique terms (order-stable). Caps at MAX_TERMS,
# recording the cap on stderr-free path (caller notes it in the artifact).
_STOPWORDS=" the and for with does what when which that this from have has are was were will would should could into your you our the not but how why who whom whose can may might must shall about above after again against all any because been before being below between both during each few more most other over same some such than then there these those through under until very does done "

_extract_terms() {
  _et_line="$1"
  # strip leading [id]
  _et_clean="$(printf '%s\n' "$_et_line" | sed -E 's/^[[:space:]]*\[[^]]*\][[:space:]]*//')"
  # strip trailing disposition annotation
  _et_clean="$(printf '%s\n' "$_et_clean" | sed -E 's/@disposition=[a-zA-Z]+.*$//')"

  {
    # structured IDs + dates
    printf '%s\n' "$_et_clean" | grep -oE '§[0-9][0-9.]*|[A-Z]{1,6}-[0-9]+|[0-9]{4}-[0-9]{2}-[0-9]{2}' 2>/dev/null || true
    # quoted phrases (double quotes)
    printf '%s\n' "$_et_clean" | grep -oE '"[^"]+"' 2>/dev/null | sed -E 's/^"//; s/"$//' || true
    # significant lowercase tokens
    printf '%s\n' "$_et_clean" \
      | tr 'A-Z' 'a-z' \
      | tr -cs 'a-z0-9' '\n' \
      | while IFS= read -r _tok; do
          [ -n "$_tok" ] || continue
          # length >= 4
          if [ "${#_tok}" -lt 4 ]; then continue; fi
          # stopword filter
          case "$_STOPWORDS" in
            *" $_tok "*) continue ;;
          esac
          printf '%s\n' "$_tok"
        done
  } | awk 'NF && !seen[$0]++' | head -n "$MAX_TERMS"
}

# --- artifact emission ------------------------------------------------------

# Build the body in a temp file, count verdicts, then prepend frontmatter so
# the top-level verdict reflects the whole sweep.
_BODY_TMP="$(mktemp -t corpus-body.XXXXXX)"
_OLD_TRAP_TMP="${_Q_TMP:-}"
trap 'rm -f "$_BODY_TMP" ${_OLD_TRAP_TMP:+"$_OLD_TRAP_TMP"}' EXIT

# Counters
n_total=0
n_clean=0
n_hits=0
n_dropped=0
n_kept=0
n_caveat=0

# Track unreachable required stores (newline list, dedup at render time).
_UNREACHABLE_TMP="$(mktemp -t corpus-unreach.XXXXXX)"
: > "$_UNREACHABLE_TMP"

# Pre-resolve the store list once (label|glob|required), then per question
# re-grep. The unreachable-required set is global to the sweep.
_STORES="$(_parse_manifest)"

# Determine unreachable required stores up front (independent of question).
if [ -n "$_STORES" ]; then
  _sv_old_ifs="$IFS"
  IFS='
'
  for _st in $_STORES; do
    [ -n "$_st" ] || continue
    _st_label="${_st%%|*}"
    _st_rest="${_st#*|}"
    _st_glob="${_st_rest%%|*}"
    _st_req="${_st_rest##*|}"
    _resolved="$(_resolve_glob "$_st_glob")"
    if [ -z "$_resolved" ] && [ "$_st_req" = "true" ]; then
      printf '%s\n' "$_st_label" >> "$_UNREACHABLE_TMP"
    fi
  done
  IFS="$_sv_old_ifs"
fi
_HAS_CAVEAT=0
if [ -s "$_UNREACHABLE_TMP" ]; then
  _HAS_CAVEAT=1
fi

# Search a single term across all resolved stores; append "label:path:line"
# citations to the given output file. Honors MAX_HITS per store (cap noted).
_search_term_into() {
  _stt_term="$1"
  _stt_out="$2"
  [ -n "$_STORES" ] || return 0
  _stt_old_ifs="$IFS"
  IFS='
'
  for _st in $_STORES; do
    [ -n "$_st" ] || continue
    _st_label="${_st%%|*}"
    _st_rest="${_st#*|}"
    _st_glob="${_st_rest%%|*}"
    _resolved="$(_resolve_glob "$_st_glob")"
    [ -n "$_resolved" ] || continue
    # Build a path argv (newline-split) and grep fixed-string, case-insensitive,
    # with filename+line. -r recurses dirs; -I skips binary.
    _r_old_ifs="$IFS"
    IFS='
'
    # shellcheck disable=SC2086
    set --
    for _rp in $_resolved; do
      [ -n "$_rp" ] || continue
      set -- "$@" "$REPO_ROOT/$_rp"
    done
    IFS="$_r_old_ifs"
    [ $# -gt 0 ] || continue
    _hits="$(grep -rIinF -- "$_stt_term" "$@" 2>/dev/null | head -n "$MAX_HITS")"
    if [ -n "$_hits" ]; then
      _count="$(printf '%s\n' "$_hits" | grep -c . 2>/dev/null | head -n1)"
      _count="${_count// /}"
      printf '%s\n' "$_hits" | while IFS= read -r _hline; do
        [ -n "$_hline" ] || continue
        # strip REPO_ROOT prefix for readable citations
        _rel="${_hline#$REPO_ROOT/}"
        printf '  - %s :: %s\n' "$_st_label" "$_rel" >> "$_stt_out"
      done
      if [ "$_count" -ge "$MAX_HITS" ]; then
        printf '  - %s :: (capped at %s hits — more may exist)\n' "$_st_label" "$MAX_HITS" >> "$_stt_out"
      fi
    fi
  done
  IFS="$_stt_old_ifs"
}

# --- main loop --------------------------------------------------------------

# Read questions: each non-blank, non-comment (#) line is one question.
while IFS= read -r _line || [ -n "$_line" ]; do
  # skip blank + comment lines
  case "$_line" in
    ""|"#"*) continue ;;
  esac
  n_total=$((n_total + 1))

  # extract id (optional [id] prefix)
  _qid="$(printf '%s\n' "$_line" | sed -nE 's/^[[:space:]]*\[([^]]*)\].*/\1/p')"
  if [ -z "$_qid" ]; then
    _qid="Q${n_total}"
  fi

  # disposition annotation
  _disp="pending"
  case "$_line" in
    *"@disposition=dropped"*) _disp="dropped" ;;
    *"@disposition=kept"*)    _disp="kept" ;;
  esac
  _reason="$(printf '%s\n' "$_line" | sed -nE 's/.*reason:[[:space:]]*(.*)$/\1/p')"

  # display question text (strip annotation, keep [id])
  _qtext="$(printf '%s\n' "$_line" | sed -E 's/@disposition=[a-zA-Z]+([[:space:]]+reason:.*)?$//; s/[[:space:]]*$//')"

  # terms
  _terms="$(_extract_terms "$_line")"
  _term_count="$(printf '%s\n' "$_terms" | grep -c . 2>/dev/null | head -n1)"
  _term_count="${_term_count// /}"

  # hits
  _hits_tmp="$(mktemp -t corpus-hits.XXXXXX)"
  : > "$_hits_tmp"
  if [ -n "$_terms" ]; then
    printf '%s\n' "$_terms" | while IFS= read -r _term; do
      [ -n "$_term" ] || continue
      _search_term_into "$_term" "$_hits_tmp"
    done
  fi
  # dedup citations
  _hit_lines="$(sort -u "$_hits_tmp" 2>/dev/null | grep . 2>/dev/null || true)"
  rm -f "$_hits_tmp"
  _has_hits=0
  if [ -n "$_hit_lines" ]; then
    _has_hits=1
  fi

  # verdict
  if [ "$_has_hits" = "1" ]; then
    case "$_disp" in
      dropped) _verdict="DROPPED"; n_dropped=$((n_dropped + 1)) ;;
      kept)    _verdict="KEPT";    n_kept=$((n_kept + 1)) ;;
      *)       _verdict="HITS";    n_hits=$((n_hits + 1)) ;;
    esac
  else
    if [ "$_HAS_CAVEAT" = "1" ]; then
      _verdict="IRREDUCIBLE-WITH-CAVEAT"; n_caveat=$((n_caveat + 1))
    else
      _verdict="CLEAN"; n_clean=$((n_clean + 1))
    fi
  fi

  # render question block into body
  {
    printf '### %s — %s\n\n' "$_qid" "$_verdict"
    printf -- '- **question**: %s\n' "$_qtext"
    printf -- '- **disposition**: %s' "$_disp"
    if [ -n "$_reason" ]; then printf ' (%s)' "$_reason"; fi
    printf '\n'
    printf -- '- **terms** (%s): %s\n' "$_term_count" "$(printf '%s' "$_terms" | tr '\n' ',' | sed -E 's/,$//; s/,/, /g')"
    if [ "$_has_hits" = "1" ]; then
      printf -- '- **hits**:\n'
      printf '%s\n' "$_hit_lines"
    else
      printf -- '- **hits**: (none)\n'
    fi
    printf '\n'
  } >> "$_BODY_TMP"
done < "$QUESTIONS_FILE"

# --- top-level verdict ------------------------------------------------------
# BLOCK iff any question is HITS (>=1 hit, not dispositioned). Else PASS.
if [ "$n_hits" -gt 0 ]; then
  TOP_VERDICT="BLOCK"
else
  TOP_VERDICT="PASS"
fi

# surviving packet = total - dropped (questions that still reach the human)
n_surviving=$((n_total - n_dropped))

# unreachable-required store list, comma-joined
_unreach_join="$(sort -u "$_UNREACHABLE_TMP" 2>/dev/null | grep . 2>/dev/null | tr '\n' ',' | sed -E 's/,$//; s/,/, /g')"
rm -f "$_UNREACHABLE_TMP"

# --- write the artifact -----------------------------------------------------
_emit_artifact() {
  printf -- '---\n'
  printf 'schema_version: "1.0"\n'
  printf 'type: corpus-exhaustion\n'
  printf 'verdict: "%s"\n' "$TOP_VERDICT"
  printf 'checkpoint: "%s"\n' "$CHECKPOINT"
  printf 'generated_at: "%s"\n' "$GENERATED_AT"
  printf 'manifest: "%s"\n' "$MANIFEST"
  printf 'questions_total: %s\n' "$n_total"
  printf 'questions_surviving: %s\n' "$n_surviving"
  printf 'clean: %s\n' "$n_clean"
  printf 'hits_pending: %s\n' "$n_hits"
  printf 'dropped: %s\n' "$n_dropped"
  printf 'kept: %s\n' "$n_kept"
  printf 'caveat: %s\n' "$n_caveat"
  if [ -n "$_unreach_join" ]; then
    printf 'unreachable_required_stores: "%s"\n' "$_unreach_join"
  fi
  printf -- '---\n\n'
  printf '# Corpus-Exhaustion Artifact — %s\n\n' "$CHECKPOINT"
  printf '**Verdict:** %s' "$TOP_VERDICT"
  if [ "$TOP_VERDICT" = "BLOCK" ]; then
    printf ' — %s question(s) have un-dispositioned corpus hits. Read the cited locations, then annotate each with `@disposition=dropped` (answered) or `@disposition=kept` (genuinely open) and re-run.\n\n' "$n_hits"
  else
    printf ' — every question is clean or dispositioned; %s question(s) survive to the human.\n\n' "$n_surviving"
  fi
  if [ -n "$_unreach_join" ]; then
    printf '> **Caveat:** required store(s) could not be searched: %s. CLEAN verdicts were downgraded to IRREDUCIBLE-WITH-CAVEAT. (CON-3: no store is silently skipped.)\n\n' "$_unreach_join"
  fi
  printf '## Per-question evidence\n\n'
  cat "$_BODY_TMP"
}

if [ -n "$OUT" ]; then
  _out_dir="$(dirname "$OUT")"
  mkdir -p "$_out_dir"
  _emit_artifact > "$OUT"
  echo "artifact=$OUT"
  echo "verdict=$TOP_VERDICT"
else
  _emit_artifact
fi

exit 0
