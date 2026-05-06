#!/usr/bin/env bash
# tools/verify/m029-p01-invocation-context-resolver-shape.sh -- M029 P01 / FR-1 / AD-1 shape verifier.
#
# Asserts scripts/state/detect-invocation-context.sh exists, is executable,
# names AD-1 in its header, declares all three required output fields with
# both renderer values and both exit_code_scheme values, exposes the
# test-injection flags, and produces a three-line env block on stdout in the
# fixed order under the canonical TTY+CI cases. This is the AD-1 single-
# resolve site -- downstream surfaces (T03/T04/T05/P02/P03) consume it, so
# any drift in the three-field shape breaks every M029 surface.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOLVER="$PROJECT_ROOT/scripts/state/detect-invocation-context.sh"

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

# 1. File exists.
if [ -f "$RESOLVER" ]; then
    ok "scripts/state/detect-invocation-context.sh exists"
else
    bad "scripts/state/detect-invocation-context.sh missing"
    printf 'SUMMARY: m029-p01-invocation-context-resolver-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable bit set.
if [ -x "$RESOLVER" ]; then
    ok "scripts/state/detect-invocation-context.sh executable"
else
    bad "scripts/state/detect-invocation-context.sh not executable"
fi

# 3. Header references AD-1.
if grep -F -q 'AD-1' "$RESOLVER"; then
    ok "header references AD-1"
else
    bad "header missing AD-1 reference"
fi

# 4. Three required output field names present.
for field in 'renderer=' 'exit_code_scheme=' 'default_provider='; do
    if grep -F -q -- "$field" "$RESOLVER"; then
        ok "field name present: $field"
    else
        bad "field name missing: $field"
    fi
done

# 5. All three renderer values appear in the script body.
for value in 'renderer=tui' 'renderer=plain' 'renderer=json'; do
    if grep -F -q -- "$value" "$RESOLVER"; then
        ok "renderer value present: $value"
    else
        bad "renderer value missing: $value"
    fi
done

# 6. Both exit_code_scheme values appear.
for value in 'exit_code_scheme=interactive' 'exit_code_scheme=governance'; do
    if grep -F -q -- "$value" "$RESOLVER"; then
        ok "exit_code_scheme value present: $value"
    else
        bad "exit_code_scheme value missing: $value"
    fi
done

# 7. Test-injection flags appear.
for flag in '--tty=' '--ci='; do
    if grep -F -q -- "$flag" "$RESOLVER"; then
        ok "test-injection flag present: $flag"
    else
        bad "test-injection flag missing: $flag"
    fi
done

# 8. Runtime: TTY=true CI=false -> three lines in fixed order matching canonical pattern.
TMPDIR_LOCAL="$(mktemp -d -t m029-shape-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

out_tty="$TMPDIR_LOCAL/tty.out"
bash "$RESOLVER" --tty=true --ci=false >"$out_tty" 2>&1

# Line count exactly 3.
line_count=$(wc -l <"$out_tty" | tr -d '[:space:]')
if [ "$line_count" = "3" ]; then
    ok "TTY=true CI=false output has exactly 3 lines"
else
    bad "TTY=true CI=false output line count: expected 3 got $line_count"
fi

# Fixed-order regex match (line 1 renderer, line 2 exit_code_scheme, line 3 default_provider).
if awk 'NR==1 && /^renderer=(tui|json|plain)$/ {ok1=1}
        NR==2 && /^exit_code_scheme=(interactive|governance)$/ {ok2=1}
        NR==3 && /^default_provider=.+$/ {ok3=1}
        END { exit !(ok1 && ok2 && ok3) }' "$out_tty"; then
    ok "TTY=true CI=false stdout matches fixed-order three-line shape"
else
    bad "TTY=true CI=false stdout failed fixed-order three-line shape"
fi

# Exact value: renderer=tui under TTY=true CI=false.
if grep -q '^renderer=tui$' "$out_tty"; then
    ok "TTY=true CI=false yields renderer=tui"
else
    bad "TTY=true CI=false expected renderer=tui"
fi

# 9. Runtime: TTY=false CI=true -> renderer=plain.
out_plain="$TMPDIR_LOCAL/plain.out"
bash "$RESOLVER" --tty=false --ci=true >"$out_plain" 2>&1
if grep -q '^renderer=plain$' "$out_plain"; then
    ok "TTY=false CI=true yields renderer=plain"
else
    bad "TTY=false CI=true expected renderer=plain"
fi

printf 'SUMMARY: m029-p01-invocation-context-resolver-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
