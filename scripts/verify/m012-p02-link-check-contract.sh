#!/usr/bin/env bash
# scripts/verify/m012-p02-link-check-contract.sh — M012/P02 gate 4.
#
# Verifies the wiki-link-check.sh script's contract using a synthetic fixture:
#   - script is executable
#   - on a fixture with one broken internal link and one external link:
#       - emits BROKEN: <page> -> sub/missing.html line
#       - emits OUT-OF-SCOPE: <page> -> example.com line
#       - emits BROKEN line for #nope anchor
#       - last summary line begins with "FAIL: <N> broken"
#       - exits with code 1
#
# Self-contained HTML fixture under /tmp/ — does not require mkdocs.
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"
script="$ROOT/scripts/diagnostics/wiki-link-check.sh"

if [ ! -x "$script" ]; then
  printf 'FAIL: %s not executable\n' "$script"
  exit 1
fi

fx="/tmp/m012-p02-linkfx.$$"
mkdir -p "$fx/sub"
trap 'rm -rf "$fx"' EXIT INT TERM

cat > "$fx/index.html" <<'EOF'
<html><body>
<a href="sub/target.html">ok internal</a>
<a href="sub/missing.html">broken internal</a>
<a href="https://example.com/">external</a>
<a href="#nope">broken anchor</a>
</body></html>
EOF

cat > "$fx/sub/target.html" <<'EOF'
<html><body><h1 id="hdr">hi</h1></body></html>
EOF

out=$(bash "$script" --site "$fx" 2>&1)
rc=$?

if ! echo "$out" | grep -q 'BROKEN:.*sub/missing.html'; then
  printf 'FAIL: missing BROKEN line for sub/missing.html\n%s\n' "$out"
  exit 1
fi

if ! echo "$out" | grep -q 'OUT-OF-SCOPE:.*example.com'; then
  printf 'FAIL: missing OUT-OF-SCOPE line for example.com\n%s\n' "$out"
  exit 1
fi

if ! echo "$out" | grep -q 'BROKEN:.*#nope'; then
  printf 'FAIL: missing BROKEN line for #nope anchor\n%s\n' "$out"
  exit 1
fi

if ! echo "$out" | grep -qE '^FAIL: [0-9]+ broken'; then
  printf 'FAIL: missing FAIL summary line\n%s\n' "$out"
  exit 1
fi

if [ "$rc" != "1" ]; then
  printf 'FAIL: expected exit 1 on broken fixture, got %s\n' "$rc"
  exit 1
fi

printf 'PASS: link-check contract verified against synthetic fixture\n'
exit 0
