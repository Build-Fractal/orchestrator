#!/usr/bin/env bash
# Gate: verify .orchestrator/config.yml carries the new dual_write_agents key.
# (T05 extends this later with specify: section checks.)
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"

if [ ! -f "$CONFIG" ]; then
  echo "FAIL: .orchestrator/config.yml missing" >&2; exit 1
fi

grep -qE '^dual_write_agents:[[:space:]]*true' "$CONFIG" || {
  echo "FAIL: dual_write_agents: true not present at top level" >&2; exit 1;
}

# T05 will expand this gate to check specify: section. P01 skeleton check:
# Once T05 runs, this assertion becomes required.
if grep -q '^specify:' "$CONFIG"; then
  # T05 landed; run the expanded checks.
  grep -q 'complexity_thresholds:' "$CONFIG" || {
    echo "FAIL: specify.complexity_thresholds missing" >&2; exit 1;
  }
  grep -q 'scaffolder_description_min_words:' "$CONFIG" || {
    echo "FAIL: specify.scaffolder_description_min_words missing" >&2; exit 1;
  }
fi

echo "PASS: config keys verified"
exit 0
