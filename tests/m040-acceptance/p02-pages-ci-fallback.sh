#!/usr/bin/env bash
# tests/m040-acceptance/p02-pages-ci-fallback.sh — M040 P02 acceptance.
#
# Validates the CI-runtime posture amendment (Option B / verbatim-mirror
# fallback) against the synthetic wiki-readability fixture. Simulates a
# consumer-project CI checkout where `actions/checkout@v4` produces only
# project-tracked files (no framework-managed `scripts/` tree, no
# `wiki/.staged/` output) and asserts the workflow's `else` branch
# materializes `wiki/.staged/` so include directives in rewritten stubs
# resolve against real files.
#
# Five assertions:
#   1. After local decorator run, stubs are rewritten to include from
#      `../.staged/<rel>` (sanity check on Phase 1 prereq).
#   2. After simulating CI checkout (rm -rf scripts/ wiki/.staged/), the
#      workflow's `else` branch runs without errors.
#   3. Verbatim mirror produced wiki/.staged/<rel> for every rewritten
#      stub include target.
#   4. `pages.yml` emitted by `wiki-init.sh::emit_pages_workflow()`
#      contains the verbatim-mirror fallback (regression guard against
#      the bare `echo skip` shape this amendment replaces).
#   5. Idempotency: re-running the fallback against an already-mirrored
#      tree is a no-op (cp -R copies are tolerated; no exit error).
#
# Bash 3.2 + POSIX-sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECORATOR="$PROJECT_ROOT/scripts/wiki/wiki-decorate-build.py"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/wiki-readability"
WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"

pass=0
fail=0

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

if [ ! -f "$DECORATOR" ]; then
  bad "decorator missing at $DECORATOR"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -d "$FIXTURE_SRC" ]; then
  bad "fixture missing at $FIXTURE_SRC"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$WIKI_INIT" ]; then
  bad "wiki-init.sh missing at $WIKI_INIT"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  bad "python3 not on PATH"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- stage a writable copy of the fixture ----------------------------------
TMPDIR_LOCAL="$(mktemp -d -t m040-p02-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

ROOT="$TMPDIR_LOCAL/project"
mkdir -p "$ROOT"
cp -R "$FIXTURE_SRC/." "$ROOT/" 2>/dev/null

# Place the decorator + wiki-init under the staged tree so --root resolves.
mkdir -p "$ROOT/scripts/wiki" "$ROOT/scripts/lifecycle"
cp "$DECORATOR" "$ROOT/scripts/wiki/wiki-decorate-build.py"
cp "$WIKI_INIT" "$ROOT/scripts/lifecycle/wiki-init.sh"

# ---- prereq: run the decorator locally (rewrites stubs + creates .staged/) -
RUN_LOG="$TMPDIR_LOCAL/decorate.log"
if ! python3 "$ROOT/scripts/wiki/wiki-decorate-build.py" --root "$ROOT" \
     >"$RUN_LOG" 2>&1; then
  bad "Prereq: decorator run exited non-zero (log: $RUN_LOG)"
  cat "$RUN_LOG" >&2
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- assertion 1: stubs rewritten to .staged/ -------------------------------
STUB_M001="$ROOT/wiki/docs/milestones/M001/M001-CONTEXT.md"
STUB_DEC="$ROOT/wiki/docs/decisions.md"
if [ -f "$STUB_M001" ] && grep -qE '\.staged/.*M001-CONTEXT\.md' "$STUB_M001"; then
  ok "Assertion 1: stub rewritten to include from .staged/ (M001-CONTEXT)"
else
  bad "Assertion 1: stub include not rewritten — fallback test cannot proceed"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- simulate CI checkout: drop framework-gitignored trees ------------------
# `actions/checkout@v4` clones the consumer repo; the framework-managed
# `scripts/` tree is in the managed-gitignore block so it never appears in
# the checkout. `wiki/.staged/` is also gitignored. This is the canonical
# bug reproduction.
rm -rf "$ROOT/scripts" "$ROOT/wiki/.staged"

if [ -d "$ROOT/scripts" ] || [ -d "$ROOT/wiki/.staged" ]; then
  bad "CI-checkout sim: failed to remove scripts/ or wiki/.staged/"
  printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---- assertion 2: run the workflow `else` branch directly -------------------
# Mirror of the verbatim-mirror snippet emitted by
# scripts/lifecycle/wiki-init.sh::emit_pages_workflow(). Kept in sync with
# the workflow template; assertion 4 below regression-guards that linkage.
FALLBACK_LOG="$TMPDIR_LOCAL/fallback.log"
(
  cd "$ROOT" || exit 1
  if [ -f scripts/wiki/wiki-decorate-build.py ]; then
    # Should not happen in this CI sim; the file was just rm'd above.
    echo "fallback-test: decorator unexpectedly present, aborting" >&2
    exit 1
  else
    mkdir -p wiki/.staged
    for d in memory spec decisions knowledge milestones proposals; do
      if [ -d ".orchestrator/$d" ]; then
        cp -R ".orchestrator/$d" "wiki/.staged/"
      fi
    done
    for f in DECISIONS.md KNOWLEDGE.md milestone-summary.md spikes-registry.md; do
      if [ -f ".orchestrator/$f" ]; then
        cp ".orchestrator/$f" "wiki/.staged/"
      fi
    done
  fi
) >"$FALLBACK_LOG" 2>&1
fallback_rc=$?

if [ "$fallback_rc" -eq 0 ]; then
  ok "Assertion 2: verbatim-mirror fallback exited 0 in CI-shaped checkout"
else
  bad "Assertion 2: fallback exited $fallback_rc (log: $FALLBACK_LOG)"
  cat "$FALLBACK_LOG" >&2
fi

# ---- assertion 3: every rewritten stub include resolves --------------------
# Extract the path arg from each rewritten stub include directive and assert
# the target file exists under the project root. Stubs include with paths
# relative to the stub's own dir (e.g. ../.staged/<rel> from wiki/docs/);
# we resolve relative to the docs root for the verification because mkdocs's
# include-markdown resolves the same way.
DOCS_ROOT="$ROOT/wiki/docs"
MISSING=0
CHECKED=0
while IFS= read -r stub; do
  inc_target=$(grep -oE '\.\./\.staged/[^"[:space:]]+' "$stub" 2>/dev/null \
               | head -1)
  [ -z "$inc_target" ] && continue
  CHECKED=$((CHECKED + 1))
  rel_from_docs="${inc_target#../}"
  resolved="$ROOT/wiki/$rel_from_docs"
  if [ ! -f "$resolved" ]; then
    MISSING=$((MISSING + 1))
    echo "  missing: $stub -> $resolved" >&2
  fi
done <<EOF
$(find "$DOCS_ROOT" -type f -name '*.md' | LC_ALL=C sort)
EOF

if [ "$CHECKED" -eq 0 ]; then
  bad "Assertion 3: no rewritten-stub includes found to verify"
elif [ "$MISSING" -eq 0 ]; then
  ok "Assertion 3: all $CHECKED rewritten-stub include targets resolved against verbatim-mirrored .staged/"
else
  bad "Assertion 3: $MISSING/$CHECKED stub includes resolved to missing files"
fi

# ---- assertion 4: regression guard on workflow template ---------------------
# The fallback shell snippet in the test must stay in sync with what
# wiki-init.sh emits. Grep for the canonical fallback-marker phrase so a
# future edit that drops it (e.g. reverts to bare `echo skip`) breaks
# loudly here.
if grep -q 'mirroring .orchestrator/ verbatim into wiki/.staged/' "$WIKI_INIT" \
   && grep -q 'admonitions-only fallback per M040 Option B' "$WIKI_INIT"; then
  ok "Assertion 4: wiki-init.sh emit_pages_workflow contains Option B fallback"
else
  bad "Assertion 4: wiki-init.sh missing Option B fallback marker (grep on canonical phrase)"
fi

# ---- assertion 5: idempotency — re-run is a no-op ---------------------------
RERUN_LOG="$TMPDIR_LOCAL/rerun.log"
(
  cd "$ROOT" || exit 1
  mkdir -p wiki/.staged
  for d in memory spec decisions knowledge milestones proposals; do
    if [ -d ".orchestrator/$d" ]; then
      cp -R ".orchestrator/$d" "wiki/.staged/"
    fi
  done
  for f in DECISIONS.md KNOWLEDGE.md milestone-summary.md spikes-registry.md; do
    if [ -f ".orchestrator/$f" ]; then
      cp ".orchestrator/$f" "wiki/.staged/"
    fi
  done
) >"$RERUN_LOG" 2>&1
rerun_rc=$?

if [ "$rerun_rc" -eq 0 ]; then
  ok "Assertion 5: re-running fallback is idempotent (exit 0)"
else
  bad "Assertion 5: re-run exited $rerun_rc (log: $RERUN_LOG)"
fi

printf 'SUMMARY: m040-p02 pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m040-p02-pages-ci-fallback (Option B verbatim-mirror validated)\n'
  exit 0
fi
exit 1
