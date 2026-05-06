#!/usr/bin/env bash
# tests/m029-acceptance/timestamp-strip.sh
# M029 / #Q-G6 enumerated-pattern timestamp-strip filter for SC-5 golden
# render comparison.
#
# Reads stdin, writes stdout. Strips exactly the three #Q-G6 patterns:
#   - ISO-8601 UTC timestamps:  \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z   -> <TS>
#   - Recency phrasing:         \d+[smhd] ago                          -> <RECENCY>
#   - Epoch-second tokens:      \b1[6-9]\d{8}\b                        -> <EPOCH>
#
# Adding patterns silently risks under-stripping in CI; missing one
# causes byte-identity failures from natural drift. The set is locked
# at #Q-G6 resolution and MUST match exactly.
#
# Reproducible across runs. Bash 3.2 / MEM001 compatible. AD-19: this
# script is itself the implementation; the SC-5 acceptance script
# invokes it as a single-script-file `bash tests/m029-acceptance/timestamp-strip.sh`
# Check: line.
#
# The MEM004 carve-out applies: sed pipes inside this script body are
# permitted; the AD-19 straight-line constraint applies to Check: lines
# at the task-plan level, not to the body of transformation utilities.
#
# Spec references: M029 / #Q-G6 (enumerated timestamp-strip patterns).

set -u

sed -E \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TS>/g' \
    -e 's/[0-9]+[smhd] ago/<RECENCY>/g' \
    -e 's/(^|[^0-9])1[6-9][0-9]{8}([^0-9]|$)/\1<EPOCH>\2/g'
