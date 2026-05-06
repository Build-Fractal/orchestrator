#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b7-extra-text-md-sibling.sh
#
# PBJ-dogfood B7 regression — wiki tooling must handle the M036
# reference-corpus pattern of paired metadata `.md` (frontmatter +
# literal `|` body placeholder) with `<basename>.text.md` Tier-1
# sibling. Two surfaces:
#
#   1. wiki-scan-sources.sh: when both `<basename>.md` and
#      `<basename>.text.md` coexist in an extra_dirs subtree, only emit
#      the canonical record (suppress the `.text.md` duplicate). Without
#      this, the wiki nav grows duplicate sibling entries.
#
#   2. wiki-generate-stubs.sh extra:* arm: when the canonical body is
#      empty AND a `.text.md` sibling exists → emit a stub that includes
#      the sibling's content with the frontmatter rendered as a
#      "Source metadata" admonition. When body is empty AND no sibling
#      exists → emit a metadata-only stub with an external_pointer:
#      callout when present (Tier 0 graceful degradation). When body is
#      non-empty → preserve current default-include behavior.
#
# Bash 3.2 compatible. Single-script-file shape per AD-19. Throwaway
# fixture protocol — all state under /tmp, trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b7-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/refs"
mkdir -p "$FIXTURE/scripts"
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

# REF-paired: metadata `.md` body-empty + `.text.md` sibling with content.
cat > "$FIXTURE/refs/REF-paired.md" <<'EOF'
---
chunk_id: REF-paired
title: "Paired Reference"
source_type: pdf
external_pointer: docs/source.pdf
---
|
EOF
cat > "$FIXTURE/refs/REF-paired.text.md" <<'EOF'
# Paired Reference

This is the Tier-1 extracted body. Contains the real content.
EOF

# REF-orphan: metadata `.md` body-empty + NO `.text.md` sibling (Tier 0).
cat > "$FIXTURE/refs/REF-orphan.md" <<'EOF'
---
chunk_id: REF-orphan
title: "Orphan Reference"
source_type: docx
external_pointer: docs/orphan.docx
---
|
EOF

# REF-authored: operator-authored body alongside frontmatter (non-empty).
cat > "$FIXTURE/refs/REF-authored.md" <<'EOF'
---
chunk_id: REF-authored
title: "Authored Reference"
---

# Authored Reference

This chunk has real content authored alongside the frontmatter.
EOF

cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - refs/
YAML

pass=0
fail=0

# ---- 1. Scanner-side: assert sibling-suppression -------------------------
SCAN_OUT="/tmp/m032-pbj-b7-scan-$$.txt"
bash "$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$FIXTURE" \
  > "$SCAN_OUT" 2>/dev/null || {
  printf 'FAIL: B7 scanner returned non-zero against fixture\n' >&2
  cat "$SCAN_OUT" >&2
  exit 1
}

if grep -q '|refs/REF-paired\.md|' "$SCAN_OUT"; then
  pass=$((pass + 1))
  printf 'PASS: B7 scanner emits canonical refs/REF-paired.md record\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B7 scanner missing canonical refs/REF-paired.md record\n' >&2
  cat "$SCAN_OUT" >&2
fi

if grep -q '|refs/REF-paired\.text\.md|' "$SCAN_OUT"; then
  fail=$((fail + 1))
  printf 'FAIL: B7 scanner emitted .text.md sibling (regression — duplicate nav entry)\n' >&2
else
  pass=$((pass + 1))
  printf 'PASS: B7 scanner suppressed refs/REF-paired.text.md sibling record\n'
fi

if grep -q '|refs/REF-orphan\.md|' "$SCAN_OUT"; then
  pass=$((pass + 1))
  printf 'PASS: B7 scanner emits orphan-no-sibling record\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B7 scanner missing orphan record\n' >&2
fi

if grep -q '|refs/REF-authored\.md|' "$SCAN_OUT"; then
  pass=$((pass + 1))
  printf 'PASS: B7 scanner emits authored-body record\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B7 scanner missing authored-body record\n' >&2
fi

rm -f "$SCAN_OUT"

# ---- 2. Stub-generator-side: assert per-record emission shape ------------
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || {
  printf 'FAIL: B7 stubs generator returned non-zero against fixture\n' >&2
  exit 1
}

# REF-paired stub: should include the .text.md sibling AND have a metadata table.
PAIRED_STUB="$FIXTURE/wiki/docs/refs/REF-paired.md"
if [ -f "$PAIRED_STUB" ]; then
  if grep -q 'REF-paired\.text\.md' "$PAIRED_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 paired stub includes .text.md sibling\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 paired stub does NOT include .text.md sibling\n' >&2
    sed -n '1,30p' "$PAIRED_STUB" >&2
  fi
  if grep -q 'Source metadata' "$PAIRED_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 paired stub renders frontmatter as Source metadata admonition\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 paired stub missing Source metadata admonition\n' >&2
  fi
  if grep -q '| chunk_id | REF-paired |' "$PAIRED_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 paired stub metadata table includes chunk_id row\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 paired stub metadata table missing chunk_id row\n' >&2
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: B7 paired stub not generated\n' >&2
fi

# REF-orphan stub: should have metadata table + external_pointer callout,
# no include-markdown directive (no body to include).
ORPHAN_STUB="$FIXTURE/wiki/docs/refs/REF-orphan.md"
if [ -f "$ORPHAN_STUB" ]; then
  if grep -q 'Source metadata' "$ORPHAN_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 orphan stub renders metadata admonition\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 orphan stub missing metadata admonition\n' >&2
  fi
  if grep -q 'docs/orphan\.docx' "$ORPHAN_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 orphan stub surfaces external_pointer\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 orphan stub missing external_pointer callout\n' >&2
    sed -n '1,30p' "$ORPHAN_STUB" >&2
  fi
  if grep -q 'include-markdown' "$ORPHAN_STUB"; then
    fail=$((fail + 1))
    printf 'FAIL: B7 orphan stub emitted include-markdown directive (no body to include)\n' >&2
  else
    pass=$((pass + 1))
    printf 'PASS: B7 orphan stub omits include-markdown directive\n'
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: B7 orphan stub not generated\n' >&2
fi

# REF-authored stub: should preserve current default-include behavior.
AUTHORED_STUB="$FIXTURE/wiki/docs/refs/REF-authored.md"
if [ -f "$AUTHORED_STUB" ]; then
  if grep -q 'include-markdown' "$AUTHORED_STUB"; then
    pass=$((pass + 1))
    printf 'PASS: B7 authored stub preserves default include-markdown\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B7 authored stub missing include-markdown directive\n' >&2
  fi
  if grep -q 'Source metadata' "$AUTHORED_STUB"; then
    fail=$((fail + 1))
    printf 'FAIL: B7 authored stub emitted Source metadata admonition (over-trigger)\n' >&2
  else
    pass=$((pass + 1))
    printf 'PASS: B7 authored stub does not over-trigger metadata admonition\n'
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: B7 authored stub not generated\n' >&2
fi

# Per-stub redundant .text.md stub must NOT have been generated.
if [ -f "$FIXTURE/wiki/docs/refs/REF-paired.text.md" ]; then
  fail=$((fail + 1))
  printf 'FAIL: B7 .text.md duplicate stub emitted (regression)\n' >&2
else
  pass=$((pass + 1))
  printf 'PASS: B7 .text.md duplicate stub suppressed\n'
fi

printf 'SUMMARY: pbj-b7-extra-text-md-sibling pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
