#!/usr/bin/env bash
# m043-p00-fixture-seeds-present.sh — assert the P02 fixture seeds captured by
# P00/T01 are present and the Access-app create payload carries BOTH the apex
# and a wildcard self_hosted_domain (the SC-3 apex+wildcard seed). Tier 1.
set -u

DIR=".orchestrator/milestones/M043/phases/P00/fixture-seeds"
fail=0

check() {
  if [ "$2" -eq 0 ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    fail=1
  fi
}

for f in \
  pages-project-create-request.json \
  access-app-create-request.json \
  access-policy-create-request.json \
  zero-trust-not-enabled-response.json \
  missing-scope-response.json \
  README.md
do
  test -s "$DIR/$f"
  check "seed present and non-empty: $f" $?
done

APP="$DIR/access-app-create-request.json"
if [ -f "$APP" ]; then
  grep -q "self_hosted_domains" "$APP"
  check "access-app seed declares self_hosted_domains" $?

  grep -q "\.pages\.dev" "$APP"
  check "access-app seed contains an apex *.pages.dev domain" $?

  grep -q "\*\." "$APP"
  check "access-app seed contains a wildcard (\\*.) domain" $?
else
  check "access-app seed contains apex+wildcard domains" 1
fi

if [ "$fail" -eq 0 ]; then
  echo "SUMMARY: m043-p00-fixture-seeds-present.sh pass=ALL fail=0"
  exit 0
fi
echo "SUMMARY: m043-p00-fixture-seeds-present.sh pass=SOME fail=1"
exit 1
