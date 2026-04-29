#!/usr/bin/env bash
# scripts/verify/m028/p03-reject-lookup-coverage.sh
#
# M028/P03/T03 verifier: asserts the PreToolUse hook's reject_lookup function
# in scripts/hooks/pre-bash-shape-guard.sh maps:
#   - 5 new pattern classes (cmd-sub-in-pattern, quoted-arg-newline-hash,
#     multiline-quoted-script, unquoted-brace-glob, xargs-sh-c-compound-body)
#     to their wrapper-basename + AP-ID pairs (AP-010..AP-014), AND
#   - 4 existing M021 arms (nested-cmd-sub, compound-chain-gt2,
#     heredoc-with-expansion, quoted-brace) plus the catch-all default
#     emit unchanged byte-for-byte (CON-7 strict-superset).
#
# We invoke the function via a sub-bash that sources the hook with stdin
# closed. The hook's main body short-circuits at the empty-stdin check
# (line ~73: STDIN_JSON="$(cat)" then [ -z "$STDIN_JSON" ] && exit 0)
# without ever reaching the classification dispatch, so sourcing it is
# safe -- but for guarantee we use `bash -c` with a function-call epilogue
# instead of `source` so set -u + the classifier load path do not impact
# this verifier's own shell. The hook script defines reject_lookup as a
# top-level function before any side effect; calling it inside the sub-bash
# captures only the printf output.
#
# Single-script-file (AD-19). Bash 3.2 + POSIX-sh safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook not found at %s\n' "$HOOK" >&2
  exit 1
fi

fail_count=0

# call_lookup: invokes reject_lookup with $1 inside a sub-bash that sources
# the hook function body only. We extract the reject_lookup function via
# awk (start at "reject_lookup() {" line, end at the next bare "}" at
# column 1) and pipe it to a sub-bash with the lookup arg appended. This
# avoids running the hook's main dispatch logic, keeping the verifier
# scoped to the lookup table.
extract_reject_lookup() {
  awk '
    /^reject_lookup\(\) \{$/ { in_fn = 1; print; next }
    in_fn { print }
    in_fn && /^\}$/ { in_fn = 0 }
  ' "$HOOK"
}

call_lookup() {
  # $1 = pattern-class string. Echoes the wrapper-basename + AP-ID line.
  local class="$1"
  local body
  body=$(extract_reject_lookup)
  printf '%s\nreject_lookup %s\n' "$body" "$class" | bash
}

assert_arm() {
  # $1 = pattern-class; $2 = expected stdout (without trailing newline);
  # $3 = label suffix for PASS line.
  local class="$1"
  local expected="$2"
  local label="$3"
  local actual
  actual=$(call_lookup "$class")
  if [ "$actual" = "$expected" ]; then
    if [ -n "$label" ]; then
      printf 'PASS: reject_lookup %s %s\n' "$class" "$label"
    else
      printf 'PASS: reject_lookup %s -> %s\n' "$class" "$expected"
    fi
  else
    printf 'FAIL: reject_lookup %s -> %s (expected %s)\n' "$class" "$actual" "$expected" >&2
    fail_count=$((fail_count + 1))
  fi
}

# Five new arms (M028/P03/T03).
assert_arm 'cmd-sub-in-pattern'       'grep-files.sh AP-010' ''
assert_arm 'quoted-arg-newline-hash'  'read-range.sh AP-011' ''
assert_arm 'multiline-quoted-script'  'node-eval.sh AP-012'  ''
assert_arm 'unquoted-brace-glob'      'peek-files.sh AP-013' ''
assert_arm 'xargs-sh-c-compound-body' 'peek-files.sh AP-014' ''

# Four existing M021 arms preserved byte-for-byte (CON-7).
assert_arm 'nested-cmd-sub'         'run-probe.sh AP-009'  '(M021 baseline preserved)'
assert_arm 'compound-chain-gt2'     'run-probe.sh AP-009'  '(M021 baseline preserved)'
assert_arm 'heredoc-with-expansion' 'run-probe.sh AP-008'  '(M021 baseline preserved)'
assert_arm 'quoted-brace'           'read-range.sh AP-007' '(M021 baseline preserved)'

# Catch-all default (any unknown pattern class).
assert_arm 'some-unknown-class' 'run-probe.sh AP-009' '(catch-all preserved)'
# Re-label the catch-all PASS line for human readability.
# (assert_arm above already printed; the label arg covers it.)

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d assertion(s) failed in reject_lookup coverage\n' "$fail_count" >&2
  exit 1
fi

printf 'PASS: p03-reject-lookup-coverage.sh\n'
exit 0
