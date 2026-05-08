#!/usr/bin/env bash
# tests/test-wiki-stubs-fresh-extra-dirs.sh
#
# PBJ-2026-05-08 regression — wiki-stubs-fresh.sh false-FAILed against a
# project with non-empty `wiki.extra_dirs` because the diagnostic propagated
# the operator's `--root .` literal into the regenerator, while the operator
# had previously regenerated wiki/docs via the flag-less form (which resolves
# ROOT to an absolute path via `cd $SCRIPT_DIR/../.. && pwd`). The two ROOT
# forms produce drift in two places baked into per-stub output:
#
#   1. `Source metadata: <path>` auto-generated comments embed `$ROOT`
#      verbatim. `--root .` → `./knowledge/...`; absolute → `/abs/.../knowledge/...`.
#   2. `project_external_pointer` pattern-matches `case "$_ptr" in
#      "file://$ROOT/"*)` to project file:// pointers to `<repo_url>/blob/main/`.
#      With `$ROOT="."` the pattern is `file://./...`, which never matches the
#      real `file:///abs/...` pointer, so the GitHub source-link callout
#      silently disappears.
#
# Both differences are deterministic per ROOT-form and hidden from the
# operator. Bug surfaced in PBJ-central immediately after the
# `db22270a` paper-cut bundle landed (`wiki-stubs-fresh.sh` Item 2a's new
# strict-build chain became unreachable because the staleness gate
# false-FAILed first). Fix: canonicalize ROOT to absolute when --root is
# explicitly passed (wiki-generate-stubs.sh, wiki-generate-nav.sh,
# wiki-scan-sources.sh) plus belt-and-suspenders canonicalization in
# wiki-stubs-fresh.sh itself.
#
# This test asserts: with non-empty `wiki.extra_dirs`, two consecutive
# `wiki-stubs-fresh.sh --restore` invocations — one with `--root <abs>`,
# one with `--root .` from inside the fixture — both PASS, and a control
# diff between the two ROOT-forms' regen output is byte-identical.
#
# Bash 3.2 compatible. Throwaway fixture under /tmp; trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

FIXTURE="/tmp/wiki-stubs-fresh-extra-dirs-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/knowledge/reference/cms-rule"
mkdir -p "$FIXTURE/scripts"

# Symlink the project's scripts/ tree so the regenerators resolve their
# sibling scanners via $ROOT/scripts/wiki/ — same pattern the M032
# acceptance fixtures use (p0X-pbj-b1-extra-dir-index.sh et al.).
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"
ln -s "$PROJECT_ROOT/scripts/diagnostics" "$FIXTURE/scripts/diagnostics"

# Two reference chunks: one with a Tier-1 sibling and a `file://` pointer
# (exercises write_stub_extra_with_sibling + project_external_pointer);
# one body-only (exercises the metadata-only fallback). The
# external_pointer with `file://<FIXTURE>/...` is the trigger geometry —
# `project_external_pointer` requires `$ROOT` to absolute-prefix-match
# the pointer to project it; the bug shows up when $ROOT becomes a
# relative literal.
cat > "$FIXTURE/knowledge/reference/cms-rule/REF-cms-rule-foo.md" <<EOF
---
chunk_id: REF-cms-rule-foo
version: "Foo Rule v1.0"
external_pointer: file://${FIXTURE}/knowledge/reference/cms-rule/REF-cms-rule-foo.pdf
published: "2026-04-01"
---
|
EOF
cat > "$FIXTURE/knowledge/reference/cms-rule/REF-cms-rule-foo.text.md" <<'EOF'
# Foo Rule v1.0

Real body text extracted from the source PDF.
EOF
cat > "$FIXTURE/knowledge/reference/cms-rule/REF-cms-rule-bar.md" <<'EOF'
---
chunk_id: REF-cms-rule-bar
version: "Bar Rule v2.0"
published: "2026-03-01"
---

# Bar Rule v2.0

Operator-authored body content (non-empty).
EOF

cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - knowledge/reference/cms-rule/
  extra_dir_labels:
    knowledge-reference-cms-rule: "Reference — CMS rules"
YAML

# Minimal mkdocs.yml so read_repo_url() returns a non-empty string and the
# project_external_pointer file:// projection arm fires.
cat > "$FIXTURE/wiki/mkdocs.yml" <<'YAML'
site_name: Fixture
repo_url: https://github.com/example/fixture
nav:
  - Home: index.md
YAML
cat > "$FIXTURE/wiki/docs/index.md" <<'EOF'
# Fixture Home
EOF

pass=0
fail=0

assert() {
  local label="$1"; shift
  if "$@"; then
    pass=$((pass + 1))
    printf 'PASS: %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$label" >&2
  fi
}

# ---- Setup: produce a baseline wiki/docs via flag-less invocation ----------
# This is what the operator does (no --root). Resolves ROOT to absolute
# via `cd $SCRIPT_DIR/../.. && pwd`. NOTE: $SCRIPT_DIR resolves to the
# symlink target (PROJECT_ROOT/scripts/wiki) so the script would normally
# pick PROJECT_ROOT, not FIXTURE. To exercise the operator's exact path
# we invoke from a copy that resolves through the fixture, OR we pass
# --root <abs> which is the canonical form the operator would also get.
# We use --root <abs> as the baseline; the bug's repro is --root . second.
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" >/dev/null 2>&1 || {
  printf 'FAIL: setup — stubs gen --root <abs> returned non-zero\n' >&2
  exit 1
}
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh" --root "$FIXTURE" >/dev/null 2>&1 || {
  printf 'FAIL: setup — nav gen --root <abs> returned non-zero\n' >&2
  exit 1
}

# Snapshot for the ROOT-form-equivalence assertion below.
SNAP_ABS="/tmp/wiki-stubs-fresh-extra-dirs-snap-$$"
cp -R "$FIXTURE/wiki/docs" "$SNAP_ABS"
trap 'rm -rf "$FIXTURE" "$SNAP_ABS" "${SNAP_ABS}.rel"' EXIT INT TERM

# ---- Test 1: wiki-stubs-fresh.sh --root <abs> --restore --------------------
# Control case: caller passes an absolute --root (matching what produced
# the operator's wiki/docs). Should always PASS.
bash "$FIXTURE/scripts/diagnostics/wiki-stubs-fresh.sh" \
  --root "$FIXTURE" --restore \
  >/dev/null 2>"${SNAP_ABS}.err1"
rc1=$?
assert "wiki-stubs-fresh --root <abs> exits 0" [ "$rc1" -eq 0 ]

# ---- Test 2: wiki-stubs-fresh.sh --root . --restore (regression) ----------
# THIS is the failure mode the fix repairs. Pre-fix this exited 1 with
# STALE: lines for every extra:* stub. Post-fix the diagnostic
# canonicalizes ROOT_DIR to absolute before invoking the regenerators,
# AND the regenerators canonicalize their own --root, so both layers are
# safe.
cd "$FIXTURE"
bash "$FIXTURE/scripts/diagnostics/wiki-stubs-fresh.sh" \
  --root . --restore \
  >/dev/null 2>"${SNAP_ABS}.err2"
rc2=$?
cd "$PROJECT_ROOT"
assert "wiki-stubs-fresh --root . (relative) exits 0" [ "$rc2" -eq 0 ]

# ---- Test 3: regen with --root . produces same output as --root <abs> -----
# The deepest invariant: ROOT-form independence. If a future change
# regresses the canonicalization (e.g., removes it from one of the
# scripts), Test 2 might still pass coincidentally, but this test will
# catch it because it compares the actual regen output across ROOT forms.
cd "$FIXTURE"
bash "$FIXTURE/scripts/wiki/wiki-generate-stubs.sh" --root . >/dev/null 2>&1 || {
  printf 'FAIL: stubs gen --root . returned non-zero\n' >&2
  fail=$((fail + 1))
}
cd "$PROJECT_ROOT"
cp -R "$FIXTURE/wiki/docs" "${SNAP_ABS}.rel"

if diff -rq "$SNAP_ABS" "${SNAP_ABS}.rel" >/dev/null 2>&1; then
  pass=$((pass + 1))
  printf 'PASS: regen output is byte-identical across --root <abs> and --root .\n'
else
  fail=$((fail + 1))
  printf 'FAIL: regen output differs across --root <abs> vs --root . (canonicalization regressed)\n' >&2
  diff -rq "$SNAP_ABS" "${SNAP_ABS}.rel" 2>&1 | head -10 >&2
fi

# ---- Test 4: stub content does not leak relative ROOT ---------------------
# Spot-check one extra:* stub for the absolute-path Source metadata
# comment. A literal `./knowledge/...` would indicate ROOT was not
# canonicalized at write time.
STUB="$FIXTURE/wiki/docs/knowledge-reference-cms-rule/REF-cms-rule-foo.md"
if [ -f "$STUB" ] && grep -q "Source metadata: ${FIXTURE}/" "$STUB"; then
  pass=$((pass + 1))
  printf 'PASS: extra:* stub bakes absolute Source metadata path\n'
else
  fail=$((fail + 1))
  printf 'FAIL: extra:* stub does not contain absolute Source metadata (canonicalization missing)\n' >&2
  if [ -f "$STUB" ]; then
    grep -E '^[[:space:]]*Source metadata:' "$STUB" | head -2 >&2
  fi
fi

printf 'SUMMARY: wiki-stubs-fresh-extra-dirs pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
