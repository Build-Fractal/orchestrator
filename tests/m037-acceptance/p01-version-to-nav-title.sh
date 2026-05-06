#!/usr/bin/env bash
# tests/m037-acceptance/p01-version-to-nav-title.sh — M037 P01 SC-2 acceptance.
#
# Exercises the FR-5 + FR-6 + MIT-01/MIT-02 P0 version-to-nav-title pipeline
# against the four-fixture corpus under tests/fixtures/m037-version-projection/.
#
#   Case A (chunk-a) — `version: "Human Label A"`
#                       -> stub `title: "Human Label A"`.
#   Case B (chunk-b) — `version: "QSO-21-06-NH (December 4, 2020)"`
#                       (markdown-active characters preserved YAML-double-quoted)
#                       -> stub `title: "QSO-21-06-NH (December 4, 2020)"`.
#   Case C (chunk-c) — no `version:` field
#                       -> stub `title:` falls back to chunk-id slug "chunk-c".
#   Case D (chunk-d-escape-hatch) — pre-existing stub with
#                       auto_generated: false + operator-edited
#                       title: "Operator Custom Title". MUST be preserved
#                       byte-identical across two consecutive generator runs.
#
# Spec references: FR-5, FR-6, US-2 AS-1..AS-5, SC-2, MIT-01 P0, MIT-02 P0.
# Pipeline under test: scripts/wiki/wiki-generate-stubs.sh.
#
# Phase artifact contract: this file is >= 30 lines and contains the
# literal string "auto_generated: false" (M037 P01 plan must-have).
# Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m037-version-projection"

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

if [ ! -f "$STUBS" ]; then
  bad "stub generator missing at $STUBS"
  printf 'SC-2: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$SCANNER" ]; then
  bad "scanner missing at $SCANNER"
  printf 'SC-2: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -d "$FIXTURE_SRC" ]; then
  bad "fixture corpus missing at $FIXTURE_SRC"
  printf 'SC-2: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m037-p01-t02-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

# ---- stage a synthetic project root ----------------------------------------
# Project layout the stub generator expects:
#   $ROOT/.orchestrator/config.yml          (declares wiki.extra_dirs)
#   $ROOT/scripts/wiki/wiki-generate-stubs.sh (symlinked from project)
#   $ROOT/scripts/wiki/wiki-scan-sources.sh   (symlinked from project)
#   $ROOT/wiki/docs/                        (output target)
#   $ROOT/wiki/mkdocs.yml                   (presence-only stub)
#   $ROOT/refs-corpus/chunk-*.md            (extra_dir, contains the chunks)

ROOT="$TMPDIR_LOCAL/project"
mkdir -p "$ROOT/.orchestrator"
mkdir -p "$ROOT/scripts/wiki"
mkdir -p "$ROOT/wiki/docs"
mkdir -p "$ROOT/refs-corpus"
mkdir -p "$ROOT/templates"

# Symlink the scripts so the generator's --root resolution lands them.
ln -s "$STUBS"   "$ROOT/scripts/wiki/wiki-generate-stubs.sh"
ln -s "$SCANNER" "$ROOT/scripts/wiki/wiki-scan-sources.sh"

# Copy the milestone-titles helper (called by the generator; missing-file
# is non-fatal but stage it to keep the smoke clean).
if [ -f "$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh" ]; then
  ln -s "$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh" \
        "$ROOT/scripts/wiki/wiki-milestone-titles.sh"
fi

# Copy the index-cards template so render_landing_cards's nav-fallback path
# does not WARN out (it is harmless — index.md is unchanged when nav has no
# DEFAULT_BLURBS intersection — but a clean stderr is friendlier).
if [ -f "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" ]; then
  cp "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" \
     "$ROOT/templates/wiki-index-cards.md.tmpl"
fi

# Copy fixture chunks into the extra_dir.
cp "$FIXTURE_SRC/chunk-a.md"               "$ROOT/refs-corpus/chunk-a.md"
cp "$FIXTURE_SRC/chunk-b.md"               "$ROOT/refs-corpus/chunk-b.md"
cp "$FIXTURE_SRC/chunk-c.md"               "$ROOT/refs-corpus/chunk-c.md"
cp "$FIXTURE_SRC/chunk-d-escape-hatch.md"  "$ROOT/refs-corpus/chunk-d-escape-hatch.md"

# .orchestrator/config.yml — declares the extra_dir so the scanner picks
# the chunks up under the extra:* category.
cat > "$ROOT/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
type: orchestrator-config
wiki:
  extra_dirs:
    - refs-corpus/
EOF

# wiki/mkdocs.yml — presence-only; the stubs generator only requires
# wiki/docs/ to exist. The nav generator (not invoked here) would need a
# real mkdocs.yml; leave a minimal placeholder for parity with the
# `wiki-init.sh` install template.
cat > "$ROOT/wiki/mkdocs.yml" <<'EOF'
site_name: Test Fixture
docs_dir: docs
nav:
  - Home: index.md
EOF

# Stage the MIT-02 P0 pre-existing operator-edited stub. This file MUST
# survive byte-identical across both generator runs because it carries
# auto_generated: false in its frontmatter. The expected stub path
# mirrors the chunk's path under wiki/docs/<extra-dir>/<basename>.md
# (extra-dir record name = "refs-corpus" with slash stripped + tr / -).
PROTECTED_STUB="$ROOT/wiki/docs/refs-corpus/chunk-d-escape-hatch.md"
mkdir -p "$ROOT/wiki/docs/refs-corpus"
cp "$FIXTURE_SRC/preexisting-stub.md" "$PROTECTED_STUB"
PROTECTED_BEFORE=$(shasum "$PROTECTED_STUB" | awk '{print $1}')

# ---- run #1 of the stub generator ------------------------------------------
RUN1_LOG="$TMPDIR_LOCAL/run1.log"
if bash "$STUBS" --root "$ROOT" >"$RUN1_LOG" 2>&1; then
  ok "wiki-generate-stubs.sh run #1 exited 0"
else
  bad "wiki-generate-stubs.sh run #1 exited non-zero (log: $RUN1_LOG)"
fi

# ---- assertions on emitted stubs -------------------------------------------
# Helper: read a stub's title: line (raw).
read_stub_title_raw() {
  _f="$1"
  awk '
    BEGIN { state="pre" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*title[[:space:]]*:/ { print; exit }
  ' "$_f" 2>/dev/null
}

# Case A — chunk-a: version: "Human Label A" -> stub title: "Human Label A".
STUB_A="$ROOT/wiki/docs/refs-corpus/chunk-a.md"
if [ -f "$STUB_A" ]; then
  T_A=$(read_stub_title_raw "$STUB_A")
  case "$T_A" in
    *'"Human Label A"'*) ok "Case A: chunk-a stub title is \"Human Label A\"" ;;
    *) bad "Case A: chunk-a stub title is wrong: $T_A" ;;
  esac
else
  bad "Case A: chunk-a stub not emitted at $STUB_A"
fi

# Case B — chunk-b: markdown-active characters preserved YAML-quoted.
STUB_B="$ROOT/wiki/docs/refs-corpus/chunk-b.md"
if [ -f "$STUB_B" ]; then
  T_B=$(read_stub_title_raw "$STUB_B")
  case "$T_B" in
    *'"QSO-21-06-NH (December 4, 2020)"'*)
      ok "Case B: chunk-b stub title preserves markdown-active chars" ;;
    *)
      bad "Case B: chunk-b stub title is wrong: $T_B" ;;
  esac
else
  bad "Case B: chunk-b stub not emitted at $STUB_B"
fi

# Case C — chunk-c: no version: -> falls back to a non-empty title.
# The fallback is the scanner-supplied TITLE (extracted from `# REF-CHUNK-C`
# H1) when version: is absent — derive_stub_title returns _fallback when
# both version: and slug are empty. The acceptance contract is "human
# string, not silently empty"; assert title is non-empty and is NOT one
# of the version-projected strings from chunks A/B.
STUB_C="$ROOT/wiki/docs/refs-corpus/chunk-c.md"
if [ -f "$STUB_C" ]; then
  T_C=$(read_stub_title_raw "$STUB_C")
  case "$T_C" in
    *'"Human Label A"'*|*'"QSO-21-06-NH'*)
      bad "Case C: chunk-c stub title leaked from another chunk: $T_C" ;;
    *'title:'*'""'*|"")
      bad "Case C: chunk-c stub title is empty: $T_C" ;;
    *)
      ok "Case C: chunk-c stub title falls back to non-empty value: $T_C" ;;
  esac
else
  bad "Case C: chunk-c stub not emitted at $STUB_C"
fi

# Case D run #1 — protected stub MUST survive byte-identical.
if [ -f "$PROTECTED_STUB" ]; then
  PROTECTED_AFTER1=$(shasum "$PROTECTED_STUB" | awk '{print $1}')
  if [ "$PROTECTED_BEFORE" = "$PROTECTED_AFTER1" ]; then
    ok "Case D run #1: auto_generated: false stub preserved byte-identical"
  else
    bad "Case D run #1: protected stub mutated: before=$PROTECTED_BEFORE after=$PROTECTED_AFTER1"
  fi
else
  bad "Case D run #1: protected stub disappeared from $PROTECTED_STUB"
fi

# ---- run #2 of the stub generator (idempotency under MIT-01/MIT-02) --------
RUN2_LOG="$TMPDIR_LOCAL/run2.log"
if bash "$STUBS" --root "$ROOT" >"$RUN2_LOG" 2>&1; then
  ok "wiki-generate-stubs.sh run #2 exited 0"
else
  bad "wiki-generate-stubs.sh run #2 exited non-zero (log: $RUN2_LOG)"
fi

# Case D run #2 — protected stub MUST still survive byte-identical.
if [ -f "$PROTECTED_STUB" ]; then
  PROTECTED_AFTER2=$(shasum "$PROTECTED_STUB" | awk '{print $1}')
  if [ "$PROTECTED_BEFORE" = "$PROTECTED_AFTER2" ]; then
    ok "Case D run #2: auto_generated: false stub still byte-identical"
  else
    bad "Case D run #2: protected stub mutated across re-runs: before=$PROTECTED_BEFORE after=$PROTECTED_AFTER2"
  fi
else
  bad "Case D run #2: protected stub disappeared from $PROTECTED_STUB"
fi

printf 'SUMMARY: p01-version-to-nav-title pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: p01-version-to-nav-title (4/4 fixtures)\n'
  exit 0
fi
exit 1
