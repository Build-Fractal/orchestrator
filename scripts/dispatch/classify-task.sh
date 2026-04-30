#!/usr/bin/env bash
# scripts/dispatch/classify-task.sh -- M030 task-character classifier (FR-1, FR-2).
#
# Reads a PLAN.md and emits two stdout lines:
#   character=<mechanical|standard|novel>
#   confidence=<high|medium|low>
#
# Pure bash + grep/sed/awk. NO LLM call. NO network. NO jq dependency
# on the hot path. Bash 3.2 compatible. Runs in well under 100ms.
#
# Usage: classify-task.sh <plan-path>
#
# AD-19 single-script-file invocation. CON-1 (no-LLM-on-hot-path).
# CON-3 (symbolic closure -- classifier emits character only;
# tier resolution lives in templates/model-routing.yml).
#
# FR-2 input set (inputs e/f stubbed in v1; see ## Notes for the
# SC-10 agreement-validated rationale):
#   (a) ## Steps block presence + structure   -- IMPLEMENTED
#   (b) file-touch breadth in plan            -- IMPLEMENTED
#   (c) ## Verification specificity           -- IMPLEMENTED
#   (d) frontmatter type: field               -- IMPLEMENTED
#   (e) phase position                        -- STUBBED (no-op)
#   (f) recent-retry anomaly JSONL signal     -- STUBBED (no-op)

set -uo pipefail

PLAN_PATH="${1:-}"
if [ -z "$PLAN_PATH" ]; then
  echo "usage: classify-task.sh <plan-path>" >&2
  exit 1
fi
if [ ! -f "$PLAN_PATH" ]; then
  echo "classify-task.sh: plan not found: $PLAN_PATH" >&2
  exit 1
fi

character=""
confidence=""

# ---- Rule 1: explicit character override in frontmatter ----
fm_char=$(awk '
  /^---$/ { c++; next }
  c == 1 && /^character:[[:space:]]/ {
    val = $2
    gsub(/[",]/, "", val)
    print val
    exit
  }
' "$PLAN_PATH")

case "$fm_char" in
  mechanical|standard|novel)
    character="$fm_char"
    confidence="high"
    ;;
esac

# ---- Pre-extract structural signals (only if no frontmatter override) ----

# Extract Description/Goal section text (for novel-language detection scoped
# to the deliverable-framing prose, not the verifier-bash blocks or notes).
desc_text=$(awk '
  /^## (Description|Goal|Demo)/ { in_d = 1; next }
  in_d && /^## /                { in_d = 0 }
  in_d                           { print }
' "$PLAN_PATH")

# Extract Steps + Description text (the "deliverable" sections).
deliverable_text=$(awk '
  /^## (Steps|Description|Goal|Demo|Expected Output)/ { in_s = 1; next }
  in_s && /^## /                                       { in_s = 0 }
  in_s                                                  { print }
' "$PLAN_PATH")

# Distinct file paths mentioned in deliverable sections (Steps + Description +
# Goal + Demo + Expected Output). Captures path-shaped backtick tokens with
# a code-ish extension.
file_count=$(printf '%s\n' "$deliverable_text" \
  | grep -E -o '`[A-Za-z0-9_./\-]+\.(sh|md|yml|yaml|py|ts|tsx|js|json)`' \
  | sort -u | wc -l | tr -d ' ')

# Number of steps in the Steps block (counts top-level numbered list items
# AND `### Step N:`-style h3 step headers).
step_count=$(awk '
  /^## Steps/                                 { in_s = 1; next }
  in_s && /^## /                              { in_s = 0 }
  in_s && /^[[:space:]]*[0-9]+\.[[:space:]]/  { n++ }
  in_s && /^### Step[[:space:]]+[0-9]+/       { n++ }
  END { print n + 0 }
' "$PLAN_PATH")

# has_steps: presence of a `## Steps` block, regardless of step_count > 0.
# Some plans declare ## Steps but use prose-paragraph form (no enumeration).
has_steps=0
if grep -q -E '^## Steps[[:space:]]*$' "$PLAN_PATH"; then has_steps=1; fi

has_verif=0
if grep -q -E '^## Verification' "$PLAN_PATH"; then has_verif=1; fi

# Verification block contains at least one "bash <path>.sh" invocation.
verif_text=$(awk '
  /^## Verification/ { in_v = 1; next }
  in_v && /^## /     { in_v = 0 }
  in_v                { print }
' "$PLAN_PATH")
has_verif_bash=0
if printf '%s\n' "$verif_text" | grep -q -E '(^|[[:space:]])bash[[:space:]]+([A-Za-z0-9_./-]+\.sh|-c[[:space:]])'; then
  has_verif_bash=1
fi
# Count distinct verifier-bash invocations -- proxy for "thoroughly mechanical".
verif_bash_count=$(printf '%s\n' "$verif_text" \
  | grep -E -c '(^|[[:space:]])bash[[:space:]]+([A-Za-z0-9_./-]+\.sh|-c[[:space:]])' | tr -d ' ')

# Plan body length in lines.
body_lines=$(wc -l < "$PLAN_PATH" | tr -d ' ')

# ---- Novel-language detection ----
# Two-tier lexicon. The high-precision tier (strong novel markers) requires
# a single hit; the low-precision tier (weaker design-shaped markers) requires
# at least two distinct hits to fire (reduces false positives from "matrix"
# appearing in mechanical contexts like "suppression matrix").
#
# Restricted to the Description/Goal sections so verifier-block bash bodies
# don't false-trigger on words like "research" appearing in quoted content.

novel_high=0
novel_low=0

if printf '%s\n' "$desc_text" | grep -q -E -i '\b(explore|design alternatives|evaluate alternatives|investigate options|design-artifact|design judgment|exploratory|research artifact|tuned-by-eye|reframe|recompose|narrate|fs-inspect|fs-inspection|investigation-shaped|byte-for-byte|composition)\b'; then
  novel_high=1
fi

# Low-precision markers (require >=2 distinct hits to fire).
# "verdict" intentionally excluded -- it appears as a generic technical term
# in many standard plans; including it false-fires novel.
nl_hits=$(printf '%s\n' "$desc_text" \
  | grep -E -i -o '\b(judgment|narrative|mental model|design choice|spike|prototype|parity matrix|exploratory)\b' \
  | sort -u | wc -l | tr -d ' ')
if [ "$nl_hits" -ge 2 ]; then
  novel_low=1
fi

novel_signal=0
if [ "$novel_high" -eq 1 ] || [ "$novel_low" -eq 1 ]; then
  novel_signal=1
fi

# ---- Classification ----

if [ -z "$character" ]; then
  # Rule 2: novel signals present.
  if [ "$novel_signal" -eq 1 ]; then
    character="novel"
    if [ "$novel_high" -eq 1 ]; then
      confidence="high"
    else
      confidence="medium"
    fi
  fi
fi

if [ -z "$character" ]; then
  # Rule 3: mechanical signals (empirically calibrated against the M030/P00
  # ground-truth corpus -- file_count + body_lines are the dominant signals).
  #
  # Rule 3a: narrow-scope mechanical (file_count <= 5) with a Steps block
  # AND body short enough to be mostly transcription (body_lines <= 400).
  # Catches 16 of 20 mechanical-labeled plans; the body cap rules out long
  # standard plans (M002/P01/T01 body=444, M013/P04/T03 body=536) that have
  # narrow file scope but heavy multi-subsystem narrative.
  if [ "$has_steps" -eq 1 ] && [ "$file_count" -le 5 ] && [ "$body_lines" -le 400 ]; then
    character="mechanical"
    if [ "$has_verif_bash" -eq 1 ]; then
      confidence="high"
    else
      confidence="medium"
    fi
  fi
fi

if [ -z "$character" ]; then
  # Rule 3b: medium-scope mechanical -- file_count 6-13 with Steps + bash
  # verifier AND a body short enough that the plan is mostly transcription
  # rather than narrative (body_lines <= 320). Catches M024/P02/T02 (7
  # files, 271 body), M027/P02/T03 (10 files, 273 body), M020/P01/T01 (13
  # files, 318 body). Avoids false positives on standards which trend
  # longer-bodied or higher-file-count.
  if [ "$has_steps" -eq 1 ] && [ "$has_verif_bash" -eq 1 ] && [ "$file_count" -ge 6 ] && [ "$file_count" -le 13 ] && [ "$body_lines" -le 320 ]; then
    character="mechanical"
    confidence="medium"
  fi
fi

if [ -z "$character" ]; then
  # Rule 3c: mechanical bulk-enumeration (M015/P01/T01 hard-delete pattern).
  # Many files but the deliverable IS the enumeration; verifiers gate the
  # bulk operation; ## Description is short relative to the file list.
  if [ "$has_steps" -eq 1 ] && [ "$has_verif_bash" -eq 1 ] && [ "$file_count" -ge 20 ] && [ "$body_lines" -le 200 ]; then
    character="mechanical"
    confidence="medium"
  fi
fi

if [ -z "$character" ]; then
  # Rule 4: standard fallback.
  character="standard"
  if [ "$has_steps" -eq 1 ] && [ "$has_verif" -eq 1 ]; then
    confidence="high"
  elif [ "$has_steps" -eq 1 ] || [ "$has_verif" -eq 1 ]; then
    confidence="medium"
  else
    confidence="low"
  fi
fi

printf 'character=%s\n' "$character"
printf 'confidence=%s\n' "$confidence"
exit 0
