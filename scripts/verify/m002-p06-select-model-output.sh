#!/usr/bin/env bash
set -eu
f="scripts/dispatch/select-model.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# Check it accepts tier as argument
grep -q 'heavy\|standard\|light' "$f" || { echo "FAIL: does not handle complexity tiers"; exit 1; }
# Check built-in defaults
grep -q 'claude-opus' "$f" || { echo "FAIL: missing heavy tier default model"; exit 1; }
grep -q 'claude-sonnet' "$f" || { echo "FAIL: missing standard tier default model"; exit 1; }
grep -q 'claude-haiku' "$f" || { echo "FAIL: missing light tier default model"; exit 1; }
# Check context budget defaults
grep -q '200000\|150000\|80000' "$f" || { echo "FAIL: missing context budget defaults"; exit 1; }
# Check routing config support
grep -q 'routing.config\|ROUTING_CONFIG\|routing-config' "$f" || { echo "FAIL: does not accept routing config"; exit 1; }
echo "PASS: select-model.sh maps tier to model ID + context budget with defaults"
