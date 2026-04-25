#!/usr/bin/env bash
# m020-p02-dispatch-query-wrapper.sh — assert dispatch-interface.sh --query
# delegates to query.sh with byte-equivalent stdout (OQ-4).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DISPATCH="$ROOT/scripts/dispatch/dispatch-interface.sh"
QUERY="$ROOT/scripts/knowledge/query.sh"

if [ ! -x "$DISPATCH" ]; then
  echo "FAIL: dispatch-interface.sh missing or not executable at $DISPATCH"
  exit 1
fi
if [ ! -x "$QUERY" ]; then
  echo "FAIL: query.sh missing or not executable at $QUERY"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM770.md" <<'EOF'
---
id: MEM770
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM770: passthrough fixture
EOF

cat >"$tmpdir/knowledge/patterns/MEM771.md" <<'EOF'
---
id: MEM771
topic: ""
tags: [auth]
last_verified: 2026-04-20
status: graduated
---

# MEM771: tag passthrough fixture
EOF

export PROJECT_ROOT="$tmpdir"

# 1. Direct query.sh invocation.
direct_ids="$(bash "$QUERY" --topic auth 2>/dev/null)"

# 2. Through the dispatch wrapper.
wrapped_ids="$(bash "$DISPATCH" --query --topic auth 2>/dev/null)"

if [ "$direct_ids" != "$wrapped_ids" ]; then
  echo "FAIL: ids stdout differs between direct and dispatch-wrapped invocation"
  echo "Direct:"
  echo "$direct_ids"
  echo "Wrapped:"
  echo "$wrapped_ids"
  exit 1
fi

# 3. Same with --format json.
direct_json="$(bash "$QUERY" --topic auth --format json 2>/dev/null)"
wrapped_json="$(bash "$DISPATCH" --query --topic auth --format json 2>/dev/null)"

if [ "$direct_json" != "$wrapped_json" ]; then
  echo "FAIL: json stdout differs between direct and dispatch-wrapped invocation"
  echo "Direct: $direct_json"
  echo "Wrapped: $wrapped_json"
  exit 1
fi

# 4. Exit code propagation: invalid --state should exit non-zero through both.
direct_rc=0
bash "$QUERY" --topic auth --state bogus >/dev/null 2>&1 || direct_rc=$?

wrapped_rc=0
bash "$DISPATCH" --query --topic auth --state bogus >/dev/null 2>&1 || wrapped_rc=$?

if [ "$direct_rc" -eq 0 ] || [ "$wrapped_rc" -eq 0 ]; then
  echo "FAIL: invalid --state should exit non-zero. direct=$direct_rc wrapped=$wrapped_rc"
  exit 1
fi
if [ "$direct_rc" != "$wrapped_rc" ]; then
  echo "FAIL: exit codes differ. direct=$direct_rc wrapped=$wrapped_rc"
  exit 1
fi

# 5. Wrapper does NOT alter knowledge/ tree.
post="$tmpdir/post-files.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$post"
if ! grep -q "MEM770" "$post"; then
  echo "FAIL: knowledge tree perturbed by dispatch wrapper"
  exit 1
fi

echo "PASS: dispatch-interface --query passthrough is byte-equivalent to direct query.sh"
exit 0
