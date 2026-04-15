#!/usr/bin/env bash
set -eu
test ! -e scripts/verify/m002-p07-extension-registration.sh || { echo "FAIL: m002-p07-extension-registration.sh still exists"; exit 1; }
test ! -e tests/fixtures/verify-pass/extension.yml || { echo "FAIL: tests/fixtures/verify-pass/extension.yml still exists"; exit 1; }
test ! -e tests/fixtures/verify-fail/extension.yml || { echo "FAIL: tests/fixtures/verify-fail/extension.yml still exists"; exit 1; }
echo "PASS: all extension-validation test artifacts are absent"
