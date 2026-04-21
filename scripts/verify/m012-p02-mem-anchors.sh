#!/usr/bin/env bash
# scripts/verify/m012-p02-mem-anchors.sh — M012/P02 gate 3.
#
# When mkdocs is available, builds the wiki site to a throwaway directory
# and checks that the rendered output has at least one heading anchor
# matching id="mem-..." form (proves anchor-resolution chain is functional).
# Accepts either the consolidated KNOWLEDGE page OR a per-entry MEM stub.
#
# When mkdocs is absent, emits SKIP: and exits 0 (Tier 1 acceptable).
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"

if ! command -v mkdocs >/dev/null 2>&1; then
  printf 'SKIP: mkdocs not installed — anchor check deferred to Tier 4 UAT\n'
  exit 0
fi

probe_dir="/tmp/m012-p02-anchors.$$"
mkdir -p "$probe_dir"
trap 'rm -rf "$probe_dir"' EXIT INT TERM

build_log="/tmp/m012-p02-anchors-build.$$"
(cd "$ROOT/wiki" && mkdocs build --site-dir "$probe_dir" --quiet) > "$build_log" 2>&1
build_rc=$?

if [ "$build_rc" != "0" ]; then
  printf 'FAIL: mkdocs build failed (rc=%s)\n' "$build_rc"
  sed 's/^/  /' "$build_log"
  rm -f "$build_log"
  exit 1
fi
rm -f "$build_log"

# Look for consolidated KNOWLEDGE page first.
knowledge_html=$(find "$probe_dir" -type f -name 'index.html' -path '*knowledge*' 2>/dev/null | head -n 1)

if [ -n "$knowledge_html" ]; then
  if grep -qiE 'id="mem[-_]?[0-9]+"' "$knowledge_html"; then
    printf 'PASS: KNOWLEDGE renders with at least one MEM heading anchor\n'
    exit 0
  fi
fi

# Fall back to per-entry MEM stub rendering.
mem_stub_html=$(find "$probe_dir" -type f -name 'index.html' -path '*knowledge/patterns/MEM*' 2>/dev/null | head -n 1)

if [ -n "$mem_stub_html" ]; then
  if grep -qiE 'id="mem[-_]?[0-9]+"' "$mem_stub_html"; then
    printf 'PASS: MEM stub renders with heading anchor (per-entry path)\n'
    exit 0
  fi
fi

printf 'FAIL: no MEM heading anchor found in rendered output (%s)\n' "$probe_dir"
exit 1
