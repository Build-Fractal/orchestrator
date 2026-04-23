#!/usr/bin/env bash
# Gate alias: delegates to m014-p04-calibration-thresholds.sh.
# T01 shipped calibration-thresholds.sh; P04-PLAN.md + T07 phase-suite reference
# the complexity-thresholds-pinned.sh name. Thin forwarder to avoid renaming
# T01 artifacts (summary + memo) and preserve verbatim-plan naming in T07.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/m014-p04-calibration-thresholds.sh" "$@"
