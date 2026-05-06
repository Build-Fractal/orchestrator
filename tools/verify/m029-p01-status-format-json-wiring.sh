#!/usr/bin/env bash
# tools/verify/m029-p01-status-format-json-wiring.sh
#
# M029/P01/T04 shape verifier for the commands/status.md `--format=json`
# wiring. Asserts the new `## Format Flag` section is present, names the
# load-bearing spec entries (FR-3 / AD-2 / AD-7), references the JSON
# renderer + JSON schema, and the Reference Files section lists both.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STATUS_MD="$PROJECT_ROOT/commands/status.md"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Gate.
if [ ! -f "$STATUS_MD" ]; then
    bad "commands/status.md missing"
    printf 'SUMMARY: m029-p01-status-format-json-wiring.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "commands/status.md exists"

# `## Format Flag` section.
if grep -qE '^## Format Flag' "$STATUS_MD"; then
    ok "## Format Flag section present"
else
    bad "## Format Flag section missing"
fi

# `--format=json` literal.
if grep -q -- '--format=json' "$STATUS_MD"; then
    ok "literal --format=json present"
else
    bad "literal --format=json missing"
fi

# FR-3, AD-2, AD-7 references.
for tag in FR-3 AD-2 AD-7 ; do
    if grep -q "$tag" "$STATUS_MD"; then
        ok "spec reference present: $tag"
    else
        bad "spec reference missing: $tag"
    fi
done

# Renderer reference.
if grep -q 'scripts/diagnostics/render-status-json.sh' "$STATUS_MD"; then
    ok "scripts/diagnostics/render-status-json.sh referenced"
else
    bad "scripts/diagnostics/render-status-json.sh NOT referenced"
fi

# Schema reference.
if grep -q 'references/status-json-schema.md' "$STATUS_MD"; then
    ok "references/status-json-schema.md referenced"
else
    bad "references/status-json-schema.md NOT referenced"
fi

# Reference Files section: both names present.
REF_BLOCK=$(awk '/^## Reference Files/{flag=1; next} /^## /{flag=0} flag' "$STATUS_MD")
if printf '%s' "$REF_BLOCK" | grep -q 'references/status-json-schema.md'; then
    ok "Reference Files section names references/status-json-schema.md"
else
    bad "Reference Files section missing references/status-json-schema.md"
fi
if printf '%s' "$REF_BLOCK" | grep -q 'scripts/diagnostics/render-status-json.sh'; then
    ok "Reference Files section names scripts/diagnostics/render-status-json.sh"
else
    bad "Reference Files section missing scripts/diagnostics/render-status-json.sh"
fi

printf 'SUMMARY: m029-p01-status-format-json-wiring.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
