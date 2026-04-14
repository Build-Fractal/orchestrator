#!/usr/bin/env bash
# Verifies intensity-gate.sh rejects unknown stages and intensities
# with non-zero exit and a stderr message.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Unknown stage
err="$(bash "$f" --stage bogus-stage --intensity Quick 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: unknown stage did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'unknown stage' || { echo "FAIL: unknown stage did not emit diagnostic on stderr"; exit 1; }

# Unknown intensity
err2="$(bash "$f" --stage verify --intensity Medium 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: unknown intensity did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'unknown intensity' || { echo "FAIL: unknown intensity did not emit diagnostic on stderr"; exit 1; }

# Missing --stage
err3="$(bash "$f" --intensity Quick 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing --stage did not exit non-zero"; exit 1; fi

echo "PASS: intensity-gate.sh rejects unknown/missing inputs with non-zero exit and stderr"
