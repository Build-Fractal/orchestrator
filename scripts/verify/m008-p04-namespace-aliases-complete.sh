#!/usr/bin/env bash
# m008-p04-namespace-aliases-complete.sh -- namespace-aliases.sh emits a mapping line per command file
set -u

SCRIPT="scripts/state/namespace-aliases.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

out="$(bash "$SCRIPT")"

# Every line must match the expected shape.
bad_line="$(echo "$out" | grep -v '^speckit\.orchestrator\.[a-z-]* -> orchestrator:[a-z-]*$' || true)"
if [[ -n "$bad_line" ]]; then
  echo "FAIL: malformed mapping line(s):"
  echo "$bad_line"
  exit 1
fi

# Count command files (excluding README/AGENTS) and compare with mapping count.
cmd_count="$(ls commands/*.md 2>/dev/null | grep -vE '/(README|AGENTS)\.md$' | wc -l | tr -d ' ')"
line_count="$(echo "$out" | grep -c '^speckit\.orchestrator\.' || true)"

if [[ "$cmd_count" != "$line_count" ]]; then
  echo "FAIL: command count $cmd_count != alias count $line_count"
  exit 1
fi

# Spot check: an expected command (auto) must appear
if ! echo "$out" | grep -q '^speckit\.orchestrator\.auto -> orchestrator:auto$'; then
  echo "FAIL: expected mapping for 'auto' not found"
  exit 1
fi

echo "PASS: namespace-aliases.sh covers every command file with canonical mapping lines"
exit 0
