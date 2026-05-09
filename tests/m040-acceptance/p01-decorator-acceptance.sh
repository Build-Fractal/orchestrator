#!/usr/bin/env bash
# tests/m040-acceptance/p01-decorator-acceptance.sh — M040 P01 acceptance.
#
# Exercises the wiki-readability decorator (scripts/wiki/wiki-decorate-build.py)
# against the synthetic project under tests/fixtures/wiki-readability/.
#
# Five assertions per the M040 spec:
#   1. --print-map emits AN/BG/OD codes from the spec table + DR-SYN-### codes
#      from DECISIONS.md (heading + bullet shapes).
#   2. Default invocation exits 0 and emits decorated copies into wiki/.staged/.
#   3. Decorated M001-CONTEXT contains live hyperlinks for codes (with hover
#      tooltips), bare paths, §-refs, and bare milestone names.
#   4. Stub include directives now point at .staged/ with rewrite-relative-
#      urls=false; missing-summary manifest is emitted to /tmp.
#   5. Re-running the decorator on unchanged source produces byte-identical
#      output (idempotency).
#
# Bash 3.2 + POSIX-sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECORATOR="$PROJECT_ROOT/scripts/wiki/wiki-decorate-build.py"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/wiki-readability"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

if [ ! -f "$DECORATOR" ]; then
  bad "decorator missing at $DECORATOR"
  printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -d "$FIXTURE_SRC" ]; then
  bad "fixture missing at $FIXTURE_SRC"
  printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  bad "python3 not on PATH"
  printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- stage a writable copy of the fixture ----------------------------------
TMPDIR_LOCAL="$(mktemp -d -t m040-p01-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

ROOT="$TMPDIR_LOCAL/project"
mkdir -p "$ROOT"
cp -R "$FIXTURE_SRC/." "$ROOT/" 2>/dev/null

# Copy the decorator into the staged tree so --root resolution lands it.
mkdir -p "$ROOT/scripts/wiki"
cp "$DECORATOR" "$ROOT/scripts/wiki/wiki-decorate-build.py"

# Use a fixture-local summary-todo target so the global /tmp/wiki-summary-todo.md
# is not clobbered by parallel test runs. The decorator hardcodes
# /tmp/wiki-summary-todo.md; we move it after each run for inspection.

# ---- assertion 1: --print-map emits expected codes -------------------------
PRINTMAP_LOG="$TMPDIR_LOCAL/printmap.log"
if ! python3 "$ROOT/scripts/wiki/wiki-decorate-build.py" --root "$ROOT" \
     --print-map >/dev/null 2>"$PRINTMAP_LOG"; then
  bad "decorator --print-map exited non-zero"
fi

# Spec-table prefixes (AN/BG/OD) must appear:
for code in AN-001 AN-002 BG-001 OD-001; do
  if grep -qE "^${code}\b" "$PRINTMAP_LOG"; then
    ok "Assertion 1: --print-map contains $code"
  else
    bad "Assertion 1: --print-map missing $code (log: $PRINTMAP_LOG)"
  fi
done
# DECISIONS.md heading + bullet shapes:
for code in DR-SYN-001 DR-SYN-002 DR-OPEN-SYN-001 DR-OPEN-SYN-002; do
  if grep -qE "^${code}\b" "$PRINTMAP_LOG"; then
    ok "Assertion 1: --print-map contains $code"
  else
    bad "Assertion 1: --print-map missing $code (log: $PRINTMAP_LOG)"
  fi
done

# ---- assertion 2: default invocation exits 0 + emits .staged/ --------------
RUN1_LOG="$TMPDIR_LOCAL/run1.log"
if python3 "$ROOT/scripts/wiki/wiki-decorate-build.py" --root "$ROOT" \
     >"$RUN1_LOG" 2>&1; then
  ok "Assertion 2: decorator run #1 exited 0"
else
  bad "Assertion 2: decorator run #1 exited non-zero (log: $RUN1_LOG)"
  cat "$RUN1_LOG" >&2
fi

STAGED_M001="$ROOT/wiki/.staged/milestones/M001/M001-CONTEXT.md"
STAGED_DEC="$ROOT/wiki/.staged/DECISIONS.md"
STAGED_PLAN="$ROOT/wiki/.staged/spec/synthetic-plan.md"
STAGED_P01="$ROOT/wiki/.staged/milestones/M001/phases/P01/P01-PLAN.md"

if [ -f "$STAGED_M001" ]; then
  ok "Assertion 2: staged M001-CONTEXT.md emitted"
else
  bad "Assertion 2: staged M001-CONTEXT.md missing at $STAGED_M001"
fi
if [ -f "$STAGED_DEC" ]; then
  ok "Assertion 2: staged DECISIONS.md emitted"
else
  bad "Assertion 2: staged DECISIONS.md missing at $STAGED_DEC"
fi
if [ -f "$STAGED_PLAN" ]; then
  ok "Assertion 2: staged synthetic-plan.md emitted"
else
  bad "Assertion 2: staged synthetic-plan.md missing at $STAGED_PLAN"
fi

# ---- assertion 3: decorated M001-CONTEXT has codes/paths/§/milestone links --
if [ -f "$STAGED_M001" ]; then
  # Code with hover tooltip — pattern: [`AN-001`](URL "Title")
  if grep -qF '[`AN-001`](' "$STAGED_M001" && \
     grep -qF '"Decorate codes' "$STAGED_M001"; then
    ok "Assertion 3: AN-001 rendered as hyperlink with title attribute"
  else
    bad "Assertion 3: AN-001 hyperlink/tooltip missing in $STAGED_M001"
  fi
  # Bullet-shape DR-SYN code resolved (any link form).
  if grep -qF '[`DR-SYN-001`]' "$STAGED_M001"; then
    ok "Assertion 3: DR-SYN-001 rendered as hyperlink"
  else
    bad "Assertion 3: DR-SYN-001 hyperlink missing in $STAGED_M001"
  fi
  # Bare path .orchestrator/spec/synthetic-plan.md rewritten.
  if grep -qF '[`.orchestrator/spec/synthetic-plan.md`](' "$STAGED_M001"; then
    ok "Assertion 3: bare .orchestrator path rewritten as link"
  else
    bad "Assertion 3: bare .orchestrator path link missing in $STAGED_M001"
  fi
  # §2.1 resolved against the nearby spec link (literal § preserved).
  if grep -qE '\[\xc2\xa72\.1\]\(' "$STAGED_M001" || \
     grep -qF '[§2.1](' "$STAGED_M001"; then
    ok "Assertion 3: §2.1 reference resolved to anchor link"
  else
    bad "Assertion 3: §2.1 reference not resolved in $STAGED_M001"
  fi
  # Bare milestone name M002 decorated.
  if grep -qF '[M002](' "$STAGED_M001"; then
    ok "Assertion 3: bare milestone M002 decorated as link"
  else
    bad "Assertion 3: bare milestone M002 not linked in $STAGED_M001"
  fi
fi

# ---- assertion 4: stubs rewritten to .staged/ + summary manifest emitted ----
STUB_M001="$ROOT/wiki/docs/milestones/M001/M001-CONTEXT.md"
if [ -f "$STUB_M001" ]; then
  if grep -qE '\.staged/.*M001-CONTEXT\.md' "$STUB_M001"; then
    ok "Assertion 4: M001-CONTEXT stub rewritten to include from .staged/"
  else
    bad "Assertion 4: M001-CONTEXT stub include not rewritten"
    cat "$STUB_M001" >&2
  fi
  if grep -q 'rewrite-relative-urls=false' "$STUB_M001"; then
    ok "Assertion 4: M001-CONTEXT stub forces rewrite-relative-urls=false"
  else
    bad "Assertion 4: M001-CONTEXT stub missing rewrite-relative-urls=false"
  fi
fi

if [ -f "/tmp/wiki-summary-todo.md" ]; then
  if grep -q 'M001-CONTEXT.md' "/tmp/wiki-summary-todo.md"; then
    ok "Assertion 4: missing-summary manifest lists fixture stubs"
  else
    bad "Assertion 4: missing-summary manifest does not list fixture stubs"
  fi
else
  bad "Assertion 4: /tmp/wiki-summary-todo.md not emitted"
fi

# ---- assertion 5: idempotency — re-run produces byte-identical output ------
# Snapshot every staged file's sha after run #1.
SNAP1="$TMPDIR_LOCAL/snap1.txt"
SNAP2="$TMPDIR_LOCAL/snap2.txt"
if command -v shasum >/dev/null 2>&1; then
  HASHER="shasum"
else
  HASHER="sha1sum"
fi

if [ -d "$ROOT/wiki/.staged" ]; then
  find "$ROOT/wiki/.staged" -type f -name '*.md' | LC_ALL=C sort | \
    while IFS= read -r _f; do
      "$HASHER" "$_f" 2>/dev/null
    done | sed "s|$ROOT/||" > "$SNAP1"
fi

# Run #2 — must be a no-op given unchanged source.
RUN2_LOG="$TMPDIR_LOCAL/run2.log"
if python3 "$ROOT/scripts/wiki/wiki-decorate-build.py" --root "$ROOT" \
     >"$RUN2_LOG" 2>&1; then
  ok "Assertion 5: decorator run #2 exited 0"
else
  bad "Assertion 5: decorator run #2 exited non-zero (log: $RUN2_LOG)"
fi

if [ -d "$ROOT/wiki/.staged" ]; then
  find "$ROOT/wiki/.staged" -type f -name '*.md' | LC_ALL=C sort | \
    while IFS= read -r _f; do
      "$HASHER" "$_f" 2>/dev/null
    done | sed "s|$ROOT/||" > "$SNAP2"
fi

if [ -s "$SNAP1" ] && diff -q "$SNAP1" "$SNAP2" >/dev/null 2>&1; then
  ok "Assertion 5: re-run produces byte-identical staged output (idempotent)"
else
  bad "Assertion 5: staged output diverges across runs"
  diff -u "$SNAP1" "$SNAP2" >&2 || true
fi

printf 'SUMMARY: m040-acceptance pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m040-acceptance (decorator validated end-to-end)\n'
  exit 0
fi
exit 1
