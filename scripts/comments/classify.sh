#!/usr/bin/env bash
# scripts/comments/classify.sh
# FR-9 v1 classifier — regex/heuristic per D023 (2026-04-24).
# Reads one inbox JSON file; emits class+confidence+reason on stdout.
#
# Output (stdout, single line):
#   class=<uat-bug|decision-append|spec-amendment|ambiguous> confidence=<0.0-1.0> reason=<short-id>
#
# Side channel (stderr): one INFO line naming the rule that fired.
#
# Behavior:
#   1. Reads one inbox JSON file produced by scripts/comments/fetch.sh
#      (shape: {url, body, source_surface, fetched_at, body_shasum, ...}).
#   2. Applies the regex/heuristic v1 ruleset (R1-R10) to the comment body.
#   3. Emits a single-line verdict on stdout. The auto-apply gate (T04)
#      consumes this verdict; classify.sh itself never auto-applies.
#   4. spec-amendment ALWAYS queues regardless of confidence (CON-5 / SC-5).
#   5. ambiguous routes to scripts/dispatch/adapters/tool/conversus.sh
#      (CON-4) — but the routing call itself lives in T04's pipeline, not
#      here. classify.sh is a pure verdict producer.
#
# D023 retune trigger (volume OR calibration):
#   - >=30 actioned comments observed, OR
#   - >=20% calibration divergence between regex/heuristic verdict and
#     conversus-triage / human-triage outcome.
#   See specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md
#   for the single source of truth on retune-trigger conditions.
#
# CON-6 / MEM001: Bash 3.2 — no declare -A, no mapfile, no ${var,,} (use tr),
# no process substitution, no &>. AD-19 single-script-file shape.

set -u

_inbox_file="${1:-}"
if [ -z "$_inbox_file" ] || [ ! -f "$_inbox_file" ]; then
  printf 'FAIL: classify.sh: inbox file required as $1 (got: %s)\n' "$_inbox_file" >&2
  exit 2
fi

# Extract body field via awk. The fetcher writes single-line JSON records;
# the body field is JSON-encoded with backslash-escaped quotes. We read up
# to the next unescaped quote that closes the body value. For multi-line
# bodies the \n stays literal and the regex rules below match across it
# because grep -E reads the whole line.
_body="$(awk '
  /"body"[[:space:]]*:/ {
    # Strip everything up to and including "body": "
    sub(/.*"body"[[:space:]]*:[[:space:]]*"/, "")
    # Strip from the closing unescaped " followed by ," or "}" to end
    sub(/",[[:space:]]*"[^"]*"[[:space:]]*:.*/, "")
    sub(/"[[:space:]]*}[[:space:]]*$/, "")
    print
    exit
  }
' "$_inbox_file")"

# Lowercase for case-insensitive matching (Bash 3.2 — use tr, not ${var,,}).
_body_lower="$(printf '%s' "$_body" | tr '[:upper:]' '[:lower:]')"

_class=""
_conf="0.0"
_reason="no-rule-fired"

# Rule R1: uat-bug — YAML frontmatter shape installed by M013 UAT Bug template.
if printf '%s' "$_body" | grep -qE '^[[:space:]]*kind:[[:space:]]*uat-bug'; then
  _class="uat-bug"; _conf="0.9"; _reason="yaml-frontmatter"
# Rule R2: uat-bug — acceptance-criterion-fails pattern.
elif printf '%s' "$_body_lower" | grep -qE '\bacceptance[[:space:]]+(criterion|scenario|criteria)\b.*\bfail'; then
  _class="uat-bug"; _conf="0.7"; _reason="acceptance-fails"
# Rule R3: uat-bug — bug-on-platform pattern.
elif printf '%s' "$_body_lower" | grep -qE '\b(bug|broken|failing|crashes?|errors?[[:space:]]+out)\b.*\bon\b'; then
  _class="uat-bug"; _conf="0.7"; _reason="bug-on-platform"
# Rule R4: decision-append — explicit /append-decision trigger.
elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*/append-decision\b'; then
  _class="decision-append"; _conf="0.95"; _reason="explicit-trigger"
# Rule R5: decision-append — "decision:" prefix.
elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*decision:[[:space:]]+'; then
  _class="decision-append"; _conf="0.85"; _reason="decision-prefix"
# Rule R6: decision-append — narrative match ("we decided/agreed/chose").
elif printf '%s' "$_body_lower" | grep -qE '\bwe[[:space:]]+(decided|agreed|chose)\b'; then
  _class="decision-append"; _conf="0.75"; _reason="narrative-decision"
# Rule R7: spec-amendment — FR-N + correction language.
elif printf '%s' "$_body_lower" | grep -qE '\bfr-[0-9]+[[:space:]]+(should|needs?[[:space:]]+to|must|also[[:space:]]+cover)\b'; then
  _class="spec-amendment"; _conf="0.85"; _reason="fr-amend"
# Rule R8: spec-amendment — AS/US/SC/CON cross-ref correction.
elif printf '%s' "$_body_lower" | grep -qE '\b(as|us|sc|con)-[0-9]+[[:space:]]+(is[[:space:]]+wrong|contradicts?|missing)\b'; then
  _class="spec-amendment"; _conf="0.85"; _reason="cross-ref-correction"
# Rule R9: spec-amendment — explicit amend prefix.
elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*(amend|propose[[:space:]]+amendment)\b'; then
  _class="spec-amendment"; _conf="0.95"; _reason="explicit-amend"
# Rule R10: ambiguous fallthrough — route to conversus per CON-4 (T04 pipeline).
else
  _class="ambiguous"; _conf="0.0"; _reason="no-rule-fired"
fi

printf 'class=%s confidence=%s reason=%s\n' "$_class" "$_conf" "$_reason"
printf 'INFO: classified %s as %s (rule=%s)\n' "$(basename "$_inbox_file")" "$_class" "$_reason" >&2
exit 0
