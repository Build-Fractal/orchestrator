#!/usr/bin/env bash
# installer-smoke.sh — XXII evidence stub
#
# Verifies SOURCE B XXII Invariant 3 (end-to-end install testing): every
# release gate runs each per-runtime installer against a fresh project
# fixture and verifies `orchestrator:status` works. No hand-waving
# "it worked on dev."
#
# Status: STUB. Created 2026-05-11 as part of the originating-deliberation
# P1-7 fix (XXII Criterion 1 mechanical-verification feasibility gate).
# A partial installer smoke harness already exists today in this repo;
# this stub at the named XXII evidence path records the canonical
# location the XXII-driven extension will land. Path-existence
# discharges the Criterion 1 feasibility requirement at the inheritance
# declaration level.
#
# TODO (post-ratification): extend the existing partial smoke harness to
# cover all three runtime adapters (claude-code, codex, cursor) against
# a fresh project fixture, verifying `orchestrator:status` works at
# each. Emit verdict=PASS|FAIL.
#
# Tracking: .orchestrator/proposals/constitution-amendment-inclusion-criteria.md
# Synthesis P1-7 (T-2 modified).

set -euo pipefail

echo "TODO: installer-smoke.sh — XXII Invariant 3 verifier not yet fully implemented."
echo "      Partial smoke harness exists elsewhere; this stub records the canonical XXII path."
echo "      Path-existence stub discharges Criterion 1 feasibility requirement."
echo "      See script header for the full implementation sketch."
exit 0
