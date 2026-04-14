#!/usr/bin/env bash
# Verify references/architecture.md includes subsystem relationship map.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "M001" "$f" || { echo "FAIL: missing M001 subsystem"; exit 1; }
grep -q "M002" "$f" || { echo "FAIL: missing M002 subsystem"; exit 1; }
grep -q "M003" "$f" || { echo "FAIL: missing M003 subsystem"; exit 1; }
grep -q "M004" "$f" || { echo "FAIL: missing M004 subsystem"; exit 1; }
grep -q "M005" "$f" || { echo "FAIL: missing M005 subsystem"; exit 1; }
echo "PASS: architecture.md subsystem map"
