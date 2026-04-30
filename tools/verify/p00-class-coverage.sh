#!/usr/bin/env bash
# tools/verify/p00-class-coverage.sh — M030/P00/T02 class-coverage verifier.
#
# Five strict-vocabulary + coverage checks against the classifier
# ground-truth fixture file:
#
#   1. Vocabulary (character): every `character:` value MUST be exactly
#      one of `mechanical|standard|novel`. TBD is rejected.
#   2. Vocabulary (confidence): every `confidence:` value MUST be exactly
#      one of `high|medium|low`. TBD is rejected.
#   3. Per-class floor: each of mechanical|standard|novel has >=5 entries.
#   4. Total floor: total entry count >=30.
#   5. No-TBD rationale: every rationale: line is non-empty and not the
#      literal `TBD`.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Override fixture path via $1.

set -u

FIXTURE="${1:-tests/fixtures/m030-classifier-corpus/labels.yml}"

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

# ---------- Pre-flight: file exists ----------

if [ ! -f "$FIXTURE" ]; then
  printf 'FAIL: labels.yml missing at %s\n' "$FIXTURE"
  printf 'SUMMARY: p00-class-coverage.sh pass=0 fail=1\n'
  exit 1
fi

# ---------- Check 1: strict character vocabulary ----------
# Every `    character:` line MUST have one of mechanical|standard|novel.

bad_char=$(awk '
  BEGIN { v = 0 }
  /^    character:/ {
    val = $2
    gsub(/[",]/, "", val)
    if (val != "mechanical" && val != "standard" && val != "novel") {
      printf "bad character: %s\n", $0
      v = v + 1
    }
    next
  }
  END {
    if (v == 0) { print "OK" }
  }
' "$FIXTURE")

if [ "$bad_char" = "OK" ]; then
  note_pass
else
  note_fail "character vocabulary violations:
${bad_char}"
fi

# ---------- Check 2: strict confidence vocabulary ----------
# Every `    confidence:` line MUST have one of high|medium|low.

bad_conf=$(awk '
  BEGIN { v = 0 }
  /^    confidence:/ {
    val = $2
    gsub(/[",]/, "", val)
    if (val != "high" && val != "medium" && val != "low") {
      printf "bad confidence: %s\n", $0
      v = v + 1
    }
    next
  }
  END {
    if (v == 0) { print "OK" }
  }
' "$FIXTURE")

if [ "$bad_conf" = "OK" ]; then
  note_pass
else
  note_fail "confidence vocabulary violations:
${bad_conf}"
fi

# ---------- Check 3: per-class floor (>=5 each) ----------
# Three independent grep -c invocations — no $() containing pipes.

mechanical_count=$(grep -c '^    character: mechanical$' "$FIXTURE" || true)
standard_count=$(grep -c '^    character: standard$' "$FIXTURE" || true)
novel_count=$(grep -c '^    character: novel$' "$FIXTURE" || true)

floor=5
floor_violations=""

if [ "$mechanical_count" -lt "$floor" ]; then
  floor_violations="${floor_violations}class=mechanical count=${mechanical_count} below floor=${floor}
"
fi
if [ "$standard_count" -lt "$floor" ]; then
  floor_violations="${floor_violations}class=standard count=${standard_count} below floor=${floor}
"
fi
if [ "$novel_count" -lt "$floor" ]; then
  floor_violations="${floor_violations}class=novel count=${novel_count} below floor=${floor}
"
fi

if [ -z "$floor_violations" ]; then
  note_pass
else
  note_fail "per-class floor violations:
${floor_violations}"
fi

# ---------- Check 4: total entry count >= 30 ----------

entry_count=$(grep -c '^  - plan_path:' "$FIXTURE" || true)

if [ "$entry_count" -ge 30 ]; then
  note_pass
else
  note_fail "total entry count ${entry_count} below floor of 30"
fi

# ---------- Check 5: no `TBD` rationale survives ----------
# Both bare-`TBD` and quoted-"TBD" forms are rejected.

tbd_rationale_count=$(grep -c '^    rationale: TBD$' "$FIXTURE" || true)
tbd_rationale_quoted=$(grep -c '^    rationale: "TBD"$' "$FIXTURE" || true)
tbd_total=$((tbd_rationale_count + tbd_rationale_quoted))

if [ "$tbd_total" -eq 0 ]; then
  note_pass
else
  note_fail "TBD rationale survivors: count=${tbd_total} (bare=${tbd_rationale_count} quoted=${tbd_rationale_quoted})"
fi

# ---------- Final summary ----------

if [ -n "$fail_reasons" ]; then
  printf '%s' "$fail_reasons"
fi
printf 'SUMMARY: p00-class-coverage.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
