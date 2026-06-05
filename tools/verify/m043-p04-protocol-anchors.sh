#!/usr/bin/env bash
# m043-p04-protocol-anchors.sh — grep-asserts every required anchor in the
# P04 live-deploy protocol. Bash 3.2; offline; single-file.
# Required anchors (verbatim): cloudflareaccess.com, 302,
# cloudflare-access-setup.sh, wiki-init.sh, #Q-5, #Q-6, giscus, green CI.
set -e -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROTO="$ROOT/tests/m043-acceptance/live-deploy/protocol.md"

fail=0
pass=0
check() {
  if grep -q "$1" "$PROTO"; then
    pass=$((pass + 1))
  else
    echo "MISSING: $1"
    fail=1
  fi
}

if [ ! -f "$PROTO" ]; then
  echo "MISSING: protocol.md at $PROTO"
  echo "m043-p04-protocol-anchors pass=0 fail=1"
  exit 1
fi

check "cloudflareaccess.com"
check "302"
check "cloudflare-access-setup.sh"
check "wiki-init.sh"
check "#Q-5"
check "#Q-6"
check "giscus"
check "green CI"

echo "m043-p04-protocol-anchors pass=$pass fail=$fail"
exit $fail
