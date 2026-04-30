#!/usr/bin/env bash
# tools/verify/p01-routing-table-shape.sh — M030/P01/T03 routing-table
# shape verifier (CON-3 closure).
#
# Eight checks against templates/model-routing.yml:
#   1. File exists.
#   2. Frontmatter has schema_version, type: model-routing-table,
#      milestone: "M030".
#   3. Three top-level sections present: routing:, resolution:, cost_rates:.
#   4. Every symbolic-tier name referenced under routing: (right-hand
#      side of claude-code:/codex-cli:/cursor: lines, excluding the
#      literal "inherit") has a matching key under resolution:.
#   5. Every symbolic-tier name keyed under cost_rates: has a matching
#      key under resolution:.
#   6. Character keys under routing: are exactly the closed enum
#      {mechanical, standard, novel}.
#   7. Symbolic-tier keys under resolution: and cost_rates: are subsets
#      of the closed enum {fast, balanced, smart}; resolution: covers
#      the full enum.
#   8. Every cost_rates: tier entry has both input_per_mtok: and
#      output_per_mtok: numeric values.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No jq, no $().
# YAML walked by line-prefix matching against the indented file shape.
# Override target via $1.

set -u

TARGET="${1:-templates/model-routing.yml}"

pass=0
fail=0
fail_reasons=""

note_pass() {
  pass=$((pass + 1))
}

note_fail() {
  fail=$((fail + 1))
  fail_reasons="${fail_reasons}FAIL: $1
"
}

# ---------- Check 1: file exists ----------

if [ -f "$TARGET" ]; then
  note_pass
else
  note_fail "model-routing.yml missing at $TARGET"
  printf '%s' "$fail_reasons"
  printf 'SUMMARY: p01-routing-table-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi

# ---------- Check 2: frontmatter keys ----------

missing_keys=""
for key in 'schema_version' 'type: model-routing-table' 'milestone: "M030"'; do
  if ! grep -q "^${key}" "$TARGET"; then
    missing_keys="${missing_keys}${key} | "
  fi
done

if [ -z "$missing_keys" ]; then
  note_pass
else
  note_fail "frontmatter missing keys: ${missing_keys}"
fi

# ---------- Check 3: three top-level sections ----------

missing_sections=""
for section in 'routing:' 'resolution:' 'cost_rates:'; do
  if ! grep -q "^${section}" "$TARGET"; then
    missing_sections="${missing_sections}${section} | "
  fi
done

if [ -z "$missing_sections" ]; then
  note_pass
else
  note_fail "top-level sections missing: ${missing_sections}"
fi

# ---------- Section-bounded extraction via awk ----------
# Emit lines of a section to a temp file. Section ends at next
# top-level key (a line matching ^[a-z_]+:$) or EOF.

extract_section() {
  awk -v sec="$1" '
    BEGIN { in_sec = 0 }
    /^[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ {
      if ($0 == sec ":") { in_sec = 1; next }
      else if (in_sec == 1) { in_sec = 0 }
    }
    { if (in_sec == 1) print }
  ' "$TARGET"
}

ROUTING_BODY="$(extract_section routing)"
RESOLUTION_BODY="$(extract_section resolution)"
COST_RATES_BODY="$(extract_section cost_rates)"

# ---------- Check 4: routing -> resolution closure ----------
# Tier names referenced in routing: are the right-hand side tokens of
# `claude-code: <tier>`, `codex-cli: <tier>`, `cursor: <tier>` lines,
# excluding "inherit".

referenced_tiers="$(printf '%s\n' "$ROUTING_BODY" \
  | awk '/^[[:space:]]+(claude-code|codex-cli|cursor):[[:space:]]+/ { print $2 }' \
  | grep -v '^inherit$' \
  | sort -u)"

# Resolved-tier keys: lines matching `^  <name>:` directly under
# `resolution:` — exactly two leading spaces, then a name, then colon.

defined_tiers="$(printf '%s\n' "$RESOLUTION_BODY" \
  | awk '/^[[:space:]][[:space:]][a-z][a-z_]*:[[:space:]]*$/ { gsub(":", "", $1); print $1 }' \
  | sort -u)"

routing_closure_missing=""
for tier in $referenced_tiers; do
  if ! printf '%s\n' "$defined_tiers" | grep -qx "$tier"; then
    routing_closure_missing="${routing_closure_missing}${tier} | "
  fi
done

ref_count="$(printf '%s\n' "$referenced_tiers" | grep -c .)"
def_count="$(printf '%s\n' "$defined_tiers" | grep -c .)"

if [ -z "$routing_closure_missing" ]; then
  note_pass
  printf 'OK: routing -> resolution closure holds (%s tiers referenced, %s defined)\n' "$ref_count" "$def_count"
else
  note_fail "routing references tiers not defined in resolution: ${routing_closure_missing}"
fi

# ---------- Check 5: cost_rates -> resolution closure ----------

cost_tier_keys="$(printf '%s\n' "$COST_RATES_BODY" \
  | awk '/^[[:space:]][[:space:]][a-z][a-z_]*:[[:space:]]*$/ { gsub(":", "", $1); print $1 }' \
  | sort -u)"

cost_closure_missing=""
for tier in $cost_tier_keys; do
  if ! printf '%s\n' "$defined_tiers" | grep -qx "$tier"; then
    cost_closure_missing="${cost_closure_missing}${tier} | "
  fi
done

if [ -z "$cost_closure_missing" ]; then
  note_pass
  printf 'OK: cost_rates -> resolution closure holds\n'
else
  note_fail "cost_rates references tiers not defined in resolution: ${cost_closure_missing}"
fi

# ---------- Check 6: character closed enum under routing: ----------

char_keys="$(printf '%s\n' "$ROUTING_BODY" \
  | awk '/^[[:space:]][[:space:]][a-z][a-z_]*:[[:space:]]*$/ { gsub(":", "", $1); print $1 }' \
  | sort -u)"

unexpected_chars=""
for key in $char_keys; do
  case "$key" in
    mechanical|standard|novel) ;;
    *) unexpected_chars="${unexpected_chars}${key} | " ;;
  esac
done

missing_chars=""
for required in mechanical standard novel; do
  if ! printf '%s\n' "$char_keys" | grep -qx "$required"; then
    missing_chars="${missing_chars}${required} | "
  fi
done

if [ -z "$unexpected_chars" ] && [ -z "$missing_chars" ]; then
  note_pass
else
  note_fail "routing: character keys not exact closed enum {mechanical, standard, novel}; unexpected=[${unexpected_chars}] missing=[${missing_chars}]"
fi

# ---------- Check 7: symbolic-tier closed enum ----------

unexpected_resolution_tiers=""
for tier in $defined_tiers; do
  case "$tier" in
    fast|balanced|smart) ;;
    *) unexpected_resolution_tiers="${unexpected_resolution_tiers}${tier} | " ;;
  esac
done

missing_resolution_tiers=""
for required in fast balanced smart; do
  if ! printf '%s\n' "$defined_tiers" | grep -qx "$required"; then
    missing_resolution_tiers="${missing_resolution_tiers}${required} | "
  fi
done

unexpected_cost_tiers=""
for tier in $cost_tier_keys; do
  case "$tier" in
    fast|balanced|smart) ;;
    *) unexpected_cost_tiers="${unexpected_cost_tiers}${tier} | " ;;
  esac
done

if [ -z "$unexpected_resolution_tiers" ] && [ -z "$missing_resolution_tiers" ] && [ -z "$unexpected_cost_tiers" ]; then
  note_pass
else
  note_fail "symbolic-tier vocabulary breach: resolution unexpected=[${unexpected_resolution_tiers}] resolution missing=[${missing_resolution_tiers}] cost_rates unexpected=[${unexpected_cost_tiers}]"
fi

# ---------- Check 8: cost_rates entries have input_per_mtok + output_per_mtok ----------
# For each tier present under cost_rates, both keys must appear in the
# few lines following the tier header. We walk by reading each tier
# block from cost_rates body.

cost_shape_missing=""
for tier in $cost_tier_keys; do
  block="$(printf '%s\n' "$COST_RATES_BODY" \
    | awk -v t="$tier" '
        BEGIN { in_blk = 0 }
        $0 ~ "^[[:space:]][[:space:]]" t ":[[:space:]]*$" { in_blk = 1; next }
        /^[[:space:]][[:space:]][a-z][a-z_]*:[[:space:]]*$/ { if (in_blk == 1) in_blk = 0 }
        { if (in_blk == 1) print }
      ')"

  has_input=0
  has_output=0
  if printf '%s\n' "$block" | grep -qE '^[[:space:]]+input_per_mtok:[[:space:]]+[0-9]+(\.[0-9]+)?[[:space:]]*$'; then
    has_input=1
  fi
  if printf '%s\n' "$block" | grep -qE '^[[:space:]]+output_per_mtok:[[:space:]]+[0-9]+(\.[0-9]+)?[[:space:]]*$'; then
    has_output=1
  fi

  if [ "$has_input" -eq 0 ] || [ "$has_output" -eq 0 ]; then
    cost_shape_missing="${cost_shape_missing}${tier}(input=${has_input},output=${has_output}) | "
  fi
done

if [ -z "$cost_shape_missing" ]; then
  note_pass
else
  note_fail "cost_rates tier(s) missing required numeric keys: ${cost_shape_missing}"
fi

# ---------- Summary ----------

if [ "$fail" -eq 0 ]; then
  printf 'SUMMARY: p01-routing-table-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 0
else
  printf '%s' "$fail_reasons"
  printf 'SUMMARY: p01-routing-table-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi
