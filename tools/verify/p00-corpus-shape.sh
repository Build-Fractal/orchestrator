#!/usr/bin/env bash
# tools/verify/p00-corpus-shape.sh — M030/P00/T01 corpus-shape verifier.
#
# Six structural checks against the classifier ground-truth fixture file:
#   1. File exists.
#   2. Required frontmatter keys present (6 keys).
#   3. `entries:` list-key body line present.
#   4. `  - plan_path:` entry count >= 30.
#   5. Every entry's immediately-following lines carry the four required
#      keys (`character`, `confidence`, `rationale`).
#   6. Vocabulary check: every `character` is one of
#      `mechanical|standard|novel|TBD`; every `confidence` is one of
#      `high|medium|low|TBD`; every `rationale` value is non-empty
#      (TBD allowed at T01-close, tightened by T02/T03 verifiers).
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

# ---------- Check 1: file exists ----------

if [ -f "$FIXTURE" ]; then
  note_pass
else
  note_fail "labels.yml missing at $FIXTURE"
  printf '%s' "$fail_reasons"
  printf 'SUMMARY: p00-corpus-shape.sh pass=%s fail=%s\n' "$pass" "$fail"
  exit 1
fi

# ---------- Check 2: required frontmatter keys ----------

missing_keys=""
for key in 'schema_version' 'type: classifier-fixture-corpus' 'milestone: "M030"' 'phase: "P00"' 'created_at' 'labeler_constraint'; do
  if ! grep -q "^${key}" "$FIXTURE"; then
    missing_keys="${missing_keys}${key} | "
  fi
done

if [ -z "$missing_keys" ]; then
  note_pass
else
  note_fail "frontmatter missing keys: ${missing_keys}"
fi

# ---------- Check 3: `entries:` list-key body line ----------

if grep -q '^entries:' "$FIXTURE"; then
  note_pass
else
  note_fail "entries: list-key line not found"
fi

# ---------- Check 4: entry count >= 30 ----------

entry_count=$(grep -c '^  - plan_path:' "$FIXTURE")

if [ "$entry_count" -ge 30 ]; then
  note_pass
else
  note_fail "entry count $entry_count below floor of 30"
fi

# ---------- Check 5: every entry has the 4 required keys in shape ----------
# AWK pass: walk file; on every `  - plan_path:` line, the next 3
# lines MUST start with `    character:`, `    confidence:`, `    rationale:`
# in that order. Anything else is a shape violation.

awk_violations=$(awk '
  BEGIN { state = 0; viols = 0; entry_no = 0 }
  /^  - plan_path:/ {
    entry_no = entry_no + 1
    state = 1
    next
  }
  state == 1 {
    if ($0 !~ /^    character:/) {
      printf "entry %d: expected character, got: %s\n", entry_no, $0
      viols = viols + 1
      state = 0
      next
    }
    state = 2
    next
  }
  state == 2 {
    if ($0 !~ /^    confidence:/) {
      printf "entry %d: expected confidence, got: %s\n", entry_no, $0
      viols = viols + 1
      state = 0
      next
    }
    state = 3
    next
  }
  state == 3 {
    if ($0 !~ /^    rationale:/) {
      printf "entry %d: expected rationale, got: %s\n", entry_no, $0
      viols = viols + 1
      state = 0
      next
    }
    state = 0
    next
  }
  END {
    if (viols == 0) {
      print "OK"
    }
  }
' "$FIXTURE")

if [ "$awk_violations" = "OK" ]; then
  note_pass
else
  note_fail "entry-shape violations:
${awk_violations}"
fi

# ---------- Check 6: vocabulary checks ----------
# character: mechanical|standard|novel|TBD
# confidence: high|medium|low|TBD
# rationale: non-empty (TBD allowed)

vocab_violations=$(awk '
  BEGIN { v = 0 }
  /^    character:/ {
    val = $2
    gsub(/[",]/, "", val)
    if (val != "mechanical" && val != "standard" && val != "novel" && val != "TBD") {
      printf "bad character: %s\n", $0
      v = v + 1
    }
    next
  }
  /^    confidence:/ {
    val = $2
    gsub(/[",]/, "", val)
    if (val != "high" && val != "medium" && val != "low" && val != "TBD") {
      printf "bad confidence: %s\n", $0
      v = v + 1
    }
    next
  }
  /^    rationale:/ {
    # Empty rationale = `    rationale:` with no value after the colon.
    line = $0
    sub(/^    rationale:[[:space:]]*/, "", line)
    if (line == "") {
      printf "empty rationale at: %s\n", $0
      v = v + 1
    }
    next
  }
  END {
    if (v == 0) {
      print "OK"
    }
  }
' "$FIXTURE")

if [ "$vocab_violations" = "OK" ]; then
  note_pass
else
  note_fail "vocabulary violations:
${vocab_violations}"
fi

# ---------- Final summary ----------

if [ -n "$fail_reasons" ]; then
  printf '%s' "$fail_reasons"
fi
printf 'SUMMARY: p00-corpus-shape.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
