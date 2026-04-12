#!/usr/bin/env bash
# Verifies templates/orchestrator-config-default.yml documents the four
# autonomy config keys: mode, generate_on_init, deny_patterns, extra_allow.
set -eu
f="templates/orchestrator-config-default.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "autonomy:" "$f" || { echo "FAIL: $f missing autonomy: block"; exit 1; }
grep -q "mode:" "$f" || { echo "FAIL: $f missing mode: key"; exit 1; }
grep -q "generate_on_init:" "$f" || { echo "FAIL: $f missing generate_on_init: key"; exit 1; }
grep -q "deny_patterns:" "$f" || { echo "FAIL: $f missing deny_patterns: key"; exit 1; }
grep -q "extra_allow:" "$f" || { echo "FAIL: $f missing extra_allow: key"; exit 1; }
echo "PASS: $f documents all four autonomy keys"
