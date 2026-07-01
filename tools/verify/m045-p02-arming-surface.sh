#!/usr/bin/env sh
# m045-p02-arming-surface.sh
# Checks commands/auto.md documents the --self-continue arming surface.
set -eu
F="commands/auto.md"
grep -q -- "--self-continue" "$F" || { echo "FAIL: --self-continue not documented"; exit 1; }
grep -q "self-continue-branch.sh" "$F" || { echo "FAIL: branch script not referenced"; exit 1; }
grep -qi "default: OFF\|default OFF\|defaults OFF\|default: off" "$F" || { echo "FAIL: default-off opt-in not stated"; exit 1; }
echo "PASS: arming surface documented"
