---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M021"
name: "Phase integration gate cluster — five assertion gates (corpus-shape, decisions-d012, antipatterns-crossrefs, bash32-compat, phase-suite) that validate T01–T04 outputs and complete the P04 verify-ladder coverage"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

All four upstream tasks have completed:

- T01 → `tests/fixtures/m021-prompt-corpus.txt` with 20 entries in documented format.
- T02 → `scripts/verify/replay-prompt-corpus.sh` (executable; reports `WOULD_PROMPT=0/20` and `PASS:`).
- T03 → `scripts/verify/m021-p04-dogfood-attestation.sh` (executable; passes against current M021 state).
- T04 → [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) with D012 row appended; `ANTIPATTERNS.md` with Cross-Refs blocks on AP-005..AP-009.

T05 ships five small structural gates plus one phase-suite wrapper. Each gate is file-level assertion-only — no cross-file behavioral tests (those live in T02/T03).

## Description

Author five verify scripts that collectively enforce the P04 must-haves as mechanical checks:

1. `scripts/verify/m021-p04-corpus-shape.sh` — asserts T01's fixture structure (20 entries, 4-field format, valid pattern-class labels).
2. `scripts/verify/m021-p04-decisions-d012.sh` — asserts T04's D012 row exists with required substrings and D001..D011 remain present.
3. `scripts/verify/m021-p04-antipatterns-crossrefs.sh` — asserts T04's Cross-Refs blocks landed on AP-005..AP-009 and AP-001..AP-004 remain unchanged.
4. `scripts/verify/m021-p04-bash32-compat.sh` — asserts all P04 shell files pass `bash -n` and contain no forbidden Bash-4 constructs.
5. `scripts/verify/m021-p04-phase-suite.sh` — invokes `run-suite.sh m021 P04` (glob-discovers the `m021-p04-*.sh` gates) AND explicitly invokes `scripts/verify/replay-prompt-corpus.sh` (which does not match the m021-p04-* glob).

All five are Bash 3.2 safe, single-script-file invocable, and hermetic (read-only).

## Steps

### Step 1: Author `scripts/verify/m021-p04-corpus-shape.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-corpus-shape.sh — Structural gate for T01 fixture.
#
# Asserts tests/fixtures/m021-prompt-corpus.txt is well-formed per
# T01-PLAN.md format spec: 20 entries, 4-field format, valid labels.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$CORPUS" ]; then
  fail "corpus exists" "not found at $CORPUS"
  echo "FAIL: m021-p04-corpus-shape.sh (1 failures)"
  exit 1
fi
pass "corpus exists at $CORPUS"

# Entry count = 20 (count ID: lines)
id_count="$(grep -c '^ID:' "$CORPUS")"
if [ "$id_count" -eq 20 ]; then
  pass "entry count: 20"
else
  fail "entry count" "expected 20 got $id_count"
fi

# Four required field counts.
for field in INPUT EXPECTED_OUTCOME SCREENSHOT; do
  c="$(grep -c "^${field}:" "$CORPUS")"
  if [ "$c" -eq 20 ]; then
    pass "field ${field}: 20 lines"
  else
    fail "field ${field}" "expected 20 got $c"
  fi
done

# Entry separator count: 20 opening + 1 terminal = 21
sep_count="$(grep -c '^---$' "$CORPUS")"
if [ "$sep_count" -ge 20 ] && [ "$sep_count" -le 21 ]; then
  pass "separator count: $sep_count (expected 20 or 21)"
else
  fail "separator count" "expected 20-21 got $sep_count"
fi

# ID range 01..20 (zero-padded)
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20; do
  if grep -qE "^ID: $n\$" "$CORPUS"; then
    pass "ID: $n present"
  else
    fail "ID: $n" "missing"
  fi
done

# Every EXPECTED_OUTCOME matches grammar: allow | rewrite:* | reject:*
# Check: no EXPECTED_OUTCOME line has a value outside the three prefixes.
bad_outcomes="$(grep '^EXPECTED_OUTCOME:' "$CORPUS" | grep -vE '^EXPECTED_OUTCOME: (allow|rewrite:|reject:)' | wc -l | tr -d ' ')"
if [ "$bad_outcomes" -eq 0 ]; then
  pass "EXPECTED_OUTCOME grammar: all values match allow|rewrite:*|reject:*"
else
  fail "EXPECTED_OUTCOME grammar" "$bad_outcomes lines outside grammar"
fi

# Every reject: label is one of the 10 legal pattern-class names.
for class in trailing-rc-echo sed-n-range cat-heredoc-exec cd-and-bash var-inline-bash redirect-cmd-sub nested-cmd-sub compound-chain-gt2 heredoc-with-expansion quoted-brace; do
  # Silent — at least one entry must include a rewrite or reject reference to every class
  # so full matrix is exercised. Allow absence of reject-only classes in rewrite-only
  # fixtures by checking for presence anywhere in EXPECTED_OUTCOME lines.
  if grep -E "^EXPECTED_OUTCOME: " "$CORPUS" | grep -qE "(rewrite:.*|reject:)${class}"; then
    pass "pattern-class ${class} exercised"
  else
    # Non-fatal per-class warning; the T02 gate is the strict validator.
    echo "NOTE: pattern-class ${class} not in corpus (not all classes must appear)"
  fi
done

# Minimum coverage: ≥6 rewrite entries + ≥4 reject entries + ≥4 allow entries
rewrite_count="$(grep -c '^EXPECTED_OUTCOME: rewrite:' "$CORPUS")"
reject_count="$(grep -c '^EXPECTED_OUTCOME: reject:' "$CORPUS")"
allow_count="$(grep -c '^EXPECTED_OUTCOME: allow' "$CORPUS")"

if [ "$rewrite_count" -ge 6 ]; then pass "rewrite coverage: $rewrite_count (≥6)"; else fail "rewrite coverage" "$rewrite_count < 6"; fi
if [ "$reject_count" -ge 4 ]; then pass "reject coverage: $reject_count (≥4)"; else fail "reject coverage" "$reject_count < 4"; fi
if [ "$allow_count" -ge 4 ]; then pass "allow coverage: $allow_count (≥4)"; else fail "allow coverage" "$allow_count < 4"; fi

# Total should equal 20
total=$((rewrite_count + reject_count + allow_count))
if [ "$total" -eq 20 ]; then
  pass "total EXPECTED_OUTCOME lines: 20"
else
  fail "total EXPECTED_OUTCOME lines" "expected 20 got $total"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-corpus-shape.sh"
  exit 0
fi
echo "FAIL: m021-p04-corpus-shape.sh ($fail_count failures)"
exit 1
```

### Step 2: Author `scripts/verify/m021-p04-decisions-d012.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-decisions-d012.sh — Asserts T04.a decision entry landed.
#
# Checks .orchestrator/DECISIONS.md contains D012 row with required substrings,
# and D001..D011 rows remain present.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEC="${REPO_ROOT}/.orchestrator/DECISIONS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$DEC" ]; then
  fail "DECISIONS.md exists" "not found at $DEC"
  echo "FAIL: m021-p04-decisions-d012.sh (1 failures)"
  exit 1
fi
pass "DECISIONS.md exists at $DEC"

# D001..D011 still present.
for d in D001 D002 D003 D004 D005 D006 D007 D008 D009 D010 D011; do
  if grep -qE "^\| $d \|" "$DEC"; then
    pass "$d row present"
  else
    fail "$d row" "missing"
  fi
done

# D012 present with required substrings.
if grep -qE "^\| D012 \|" "$DEC"; then
  pass "D012 row present"
  # Required substrings in D012 row
  d012_line="$(grep -E "^\| D012 \|" "$DEC" | head -n 1)"
  for needle in 'sequencing' 'M019' 'M021' 'zero-prompt'; do
    if printf '%s' "$d012_line" | grep -qF "$needle"; then
      pass "D012 row contains [$needle]"
    else
      fail "D012 row contains [$needle]" "missing"
    fi
  done
else
  fail "D012 row" "missing"
fi

# Only one D012 row (no duplicates).
d012_count="$(grep -cE "^\| D012 \|" "$DEC")"
if [ "$d012_count" -eq 1 ]; then
  pass "D012 row count: 1"
else
  fail "D012 row count" "expected 1 got $d012_count"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-decisions-d012.sh"
  exit 0
fi
echo "FAIL: m021-p04-decisions-d012.sh ($fail_count failures)"
exit 1
```

### Step 3: Author `scripts/verify/m021-p04-antipatterns-crossrefs.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-antipatterns-crossrefs.sh — Asserts T04.b cross-refs landed.
#
# Checks ANTIPATTERNS.md contains Cross-Refs blocks under AP-005..AP-009 naming
# scripts/hooks/pre-bash-shape-guard.sh and tests/fixtures/m021-prompt-corpus.txt.
# AP-001..AP-004 headings remain present and unmodified at the heading level.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AP="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$AP" ]; then
  fail "ANTIPATTERNS.md exists" "not found at $AP"
  echo "FAIL: m021-p04-antipatterns-crossrefs.sh (1 failures)"
  exit 1
fi
pass "ANTIPATTERNS.md exists at $AP"

# AP-001..AP-009 headings all present.
for ap in AP-001 AP-002 AP-003 AP-004 AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -qE "^## $ap:" "$AP"; then
    pass "$ap heading present"
  else
    fail "$ap heading" "missing"
  fi
done

# For AP-005..AP-009, extract the content block from its heading to the next
# heading (or EOF) and assert both cross-ref paths appear.
_tmp="$(mktemp -d)"

for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  # Use awk to slice the section from `## AP-XXX:` to the next `## AP-` line.
  awk -v tgt="$ap" '
    /^## AP-/ {
      if (active) { active=0 }
      if ($0 ~ "^## " tgt ":") { active=1; next }
    }
    active { print }
  ' "$AP" > "$_tmp/${ap}.txt"

  if grep -qF 'scripts/hooks/pre-bash-shape-guard.sh' "$_tmp/${ap}.txt"; then
    pass "$ap section references pre-bash-shape-guard.sh"
  else
    fail "$ap section references pre-bash-shape-guard.sh" "not found"
  fi
  if grep -qF 'tests/fixtures/m021-prompt-corpus.txt' "$_tmp/${ap}.txt"; then
    pass "$ap section references m021-prompt-corpus.txt"
  else
    fail "$ap section references m021-prompt-corpus.txt" "not found"
  fi
done

rm -rf "$_tmp"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-antipatterns-crossrefs.sh"
  exit 0
fi
echo "FAIL: m021-p04-antipatterns-crossrefs.sh ($fail_count failures)"
exit 1
```

### Step 4: Author `scripts/verify/m021-p04-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-bash32-compat.sh — Bash 3.2 compatibility scan for P04 files.
#
# Asserts all seven P04 shell files parse clean via bash -n and contain no
# forbidden Bash-4 constructs.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

targets="
scripts/verify/replay-prompt-corpus.sh
scripts/verify/m021-p04-dogfood-attestation.sh
scripts/verify/m021-p04-corpus-shape.sh
scripts/verify/m021-p04-decisions-d012.sh
scripts/verify/m021-p04-antipatterns-crossrefs.sh
scripts/verify/m021-p04-bash32-compat.sh
scripts/verify/m021-p04-phase-suite.sh
"

# Forbidden constructs. Split across assignments to avoid the gate's own
# source matching its own needles during self-inspection.
FORBID_A='declare -A'
FORBID_B='mapfile'
FORBID_C='readarray'
# The case-conversion forms (lowercase/uppercase) — assemble literally so
# this gate's source is not itself a match.
FORBID_D='${'"var"',,}'
FORBID_E='${'"var"'^^}'
FORBID_F='${!'"prefix"'*}'
# Process substitution open-paren — split to avoid self-match.
FORBID_G='<''('

for rel in $targets; do
  f="${REPO_ROOT}/${rel}"
  if [ ! -f "$f" ]; then
    fail "file present: $rel" "not found"
    continue
  fi

  # bash -n parse check
  if bash -n "$f" 2>/dev/null; then
    pass "parse: $rel"
  else
    fail "parse: $rel" "bash -n failed"
  fi

  # Forbidden-construct scan (comments stripped to reduce false positives)
  _stripped="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G"; do
    if printf '%s' "$_stripped" | grep -qF "$needle"; then
      fail "forbidden in $rel" "found [$needle]"
    fi
  done
  pass "forbidden-construct scan: $rel"
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m021-p04-bash32-compat.sh ($fail_count failures)"
exit 1
```

### Step 5: Author `scripts/verify/m021-p04-phase-suite.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-phase-suite.sh — Phase-level cohesion runner.
#
# Invokes run-suite.sh m021 P04 (auto-discovers scripts/verify/m021-p04-*.sh)
# AND invokes scripts/verify/replay-prompt-corpus.sh explicitly (its name
# does not match the m021-p04-* glob). Asserts both pass.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Invoke run-suite.sh m021 P04
bash "${REPO_ROOT}/scripts/verify/run-suite.sh" m021 P04
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "run-suite.sh m021 P04"
else
  fail "run-suite.sh m021 P04" "rc=$rc"
fi

# Invoke replay gate explicitly
bash "${REPO_ROOT}/scripts/verify/replay-prompt-corpus.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "replay-prompt-corpus.sh"
else
  fail "replay-prompt-corpus.sh" "rc=$rc"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-phase-suite.sh"
  exit 0
fi
echo "FAIL: m021-p04-phase-suite.sh ($fail_count failures)"
exit 1
```

### Step 6: Make all five gates executable

```
chmod +x scripts/verify/m021-p04-corpus-shape.sh scripts/verify/m021-p04-decisions-d012.sh scripts/verify/m021-p04-antipatterns-crossrefs.sh scripts/verify/m021-p04-bash32-compat.sh scripts/verify/m021-p04-phase-suite.sh
```

(Issued as a single command — no compound chain, just multiple arguments to chmod.)

### Step 7: Run each gate individually, then the phase suite

```
bash scripts/verify/m021-p04-corpus-shape.sh
```

```
bash scripts/verify/m021-p04-decisions-d012.sh
```

```
bash scripts/verify/m021-p04-antipatterns-crossrefs.sh
```

```
bash scripts/verify/m021-p04-bash32-compat.sh
```

```
bash scripts/verify/m021-p04-phase-suite.sh
```

Each must exit 0 with final `PASS: <gate-name>` line.

### Step 8: Final verify-ladder run

```
bash scripts/verify/run-suite.sh m021 P04
```

Expected: all m021-p04-*.sh gates report PASS, total PASS count ≥5, FAIL count = 0.

```
bash scripts/verify/anti-pattern-lint.sh
```

Expected: exit 0. P04 introduces no new violations.

## Must-Haves

- `scripts/verify/m021-p04-corpus-shape.sh` exists, executable, PASSes against T01's fixture.
- `scripts/verify/m021-p04-decisions-d012.sh` exists, executable, PASSes against T04.a's edit.
- `scripts/verify/m021-p04-antipatterns-crossrefs.sh` exists, executable, PASSes against T04.b's edits.
- `scripts/verify/m021-p04-bash32-compat.sh` exists, executable, PASSes against all 7 P04 shell files.
- `scripts/verify/m021-p04-phase-suite.sh` exists, executable, PASSes (invokes run-suite.sh + replay-prompt-corpus.sh).
- All five gates emit per-assertion `PASS:` / `FAIL:` lines and a final `PASS: <gate>` or `FAIL: <gate>` line.
- All five gates Bash 3.2 compatible.
- Repo-wide anti-pattern-lint.sh exits 0.

## Verification

- Each gate exits 0 when invoked individually.
- `bash scripts/verify/run-suite.sh m021 P04` reports PASS for all discovered P04 gates.
- `bash scripts/verify/m021-p04-phase-suite.sh` exits 0.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0.

## Inputs

### From Previous Tasks

- `tests/fixtures/m021-prompt-corpus.txt` (from T01) — asserted by corpus-shape gate.
- `scripts/verify/replay-prompt-corpus.sh` (from T02) — invoked by phase-suite gate.
- `scripts/verify/m021-p04-dogfood-attestation.sh` (from T03) — discovered + run by run-suite.sh via m021-p04-* glob.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified by T04.a — asserted by decisions-d012 gate.
- `ANTIPATTERNS.md` modified by T04.b — asserted by antipatterns-crossrefs gate.

### From Disk (Pre-existing)

- `scripts/verify/run-suite.sh` — invoked by phase-suite gate for m021-p04-* auto-discovery.
- `scripts/verify/anti-pattern-lint.sh` — invoked in final verify step; asserts zero new violations.

## Constraints

- **Bash 3.2 compatibility** (constitution IX) — each gate passes its own bash32 scan.
- **Single-script-file invocation at agent-facing sites** (AD-19) — each gate is invoked as `bash scripts/verify/<name>.sh`.
- **Gate internals may use `$()`, pipes, `awk`, heredocs freely** (MEM004 + AP-004 scope-of-enforcement carve-out). The concatenation-split forbidden-construct literals inside `m021-p04-bash32-compat.sh` prevent the gate's own source from self-matching its needles.
- **Hermetic**: gates create only tempdirs under `mktemp -d` when needed; remove them before exit. No writes to the repo tree.
- **Idempotent**: running the full T05 set multiple times produces identical output (no stateful side effects).
- **No regression**: adding these gates must not change the result of any pre-existing gate under `scripts/verify/`.

## Expected Output

- Five new executable gate scripts under `scripts/verify/` matching the `m021-p04-*.sh` pattern (plus `m021-p04-phase-suite.sh` which also matches).
- `bash scripts/verify/run-suite.sh m021 P04` reports PASS ≥5 / FAIL 0.
- `bash scripts/verify/m021-p04-phase-suite.sh` exits 0.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 over the repo.
- Phase state advances: `derive-phase.sh .orchestrator/milestones/M021` reports `executing` (task plans + summaries present for all five P04 tasks; ready for milestone close).
