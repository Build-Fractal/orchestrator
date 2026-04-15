#!/usr/bin/env bash
set -eu
test ! -e extension.yml || { echo "FAIL: extension.yml still exists"; exit 1; }
echo "PASS: extension.yml is absent"
