# Knowledge

## K001: Bash 3.2 Compatibility [project]

All scripts must be compatible with bash 3.2. No associative arrays (declare -A), no mapfile/readarray. Use indexed arrays and POSIX constructs.

## K002: State Machine Priority Order [milestone:M001]

The 9 orchestrator states are checked in priority order (pre-planning through complete). First matching rule wins. This is critical for derive-phase.sh correctness.

## K003: Phase P03 Specific Pattern [phase:M001/P03]

Phase P03 uses a specialized validation approach that doesn't apply to other phases. The validation scripts in P03 check for cross-milestone references.
