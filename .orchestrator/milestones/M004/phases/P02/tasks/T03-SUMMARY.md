---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M004"
provides:
  - "scripts/lib/run-context.sh — Bash 3.2 sourced library providing init_run_context (initializes and exports ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN, ORCH_RUN_MILESTONE, ORCH_RUN_PHASE), orch_now (returns frozen ORCH_STARTED_AT timestamp per Principle IX), orch_is_forced/orch_is_dry_run (flag detectors accepting 1|true|TRUE|yes|YES), _orch_run_nonce (internal random nonce from /dev/urandom with cksum fallback), and deterministic seeding via ORCH_RUN_SEED (same seed → same run_id and timestamp)"
requires:
  - "from:P02/T01 what:double-sourcing guard pattern and header style; from:P02/T02 what:ORCH_STARTED_AT export contract (events.sh reads this variable for deterministic timestamps)"
affects:
  - "P02/T04 (dispatch.sh will call init_run_context and emit SESSION_START event using orch_now), P03 (engine coordinator initializes run context at session start and passes ORCH_RUN_ID/ORCH_STARTED_AT into all dispatched tasks), P06 (all engine-managed scripts source run-context.sh to get frozen timestamps; no inline date calls allowed), FR-222/US9 AS1-4/Principle IX/NFR-200/NFR-203"
key_files:
  - "scripts/lib/run-context.sh"
key_decisions:
  - "Guard placed on lines 3-4 (after shebang + one-line comment) to pass head -5 check preemptively per T01 lesson; deterministic seeding uses cksum hash of ORCH_RUN_SEED then maps to 2026-01-01 anchor + (hash mod 1 year) offset so seeded runs get stable timestamps within a plausible future window; nonce generator prefers /dev/urandom with cksum+RANDOM fallback for portability on locked-down systems; orch_is_forced/orch_is_dry_run accept multiple truthy forms (1|true|TRUE|yes|YES) via case statement for CLI/env ergonomics; GNU date -u -d @epoch and BSD date -u -r epoch both tried with fallback to current time if neither works; init_run_context defaults ORCH_FORCE/ORCH_DRY_RUN to empty string (not 1) so sourcing alone does not accidentally enable either flag"
patterns_established:
  - "Deterministic reproducibility via ORCH_RUN_SEED → cksum-derived hash drives both run_id and started_at so the same seed replays to the same session identity; frozen-timestamp contract where all downstream scripts MUST use orch_now (reads ORCH_STARTED_AT) instead of calling date directly per Principle IX; GNU/BSD date portability pattern using -d and -r with fallback; flag-detector helpers accept multiple truthy spellings for CLI/env ergonomics; internal helpers prefixed _orch_run_ to avoid collision with other libraries"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P02/tasks/T03-PLAN.md"
duration: "4m"
verification_result: "pass"
completed_at: "2026-04-10T21:15:00Z"
---

Created scripts/lib/run-context.sh (90 lines) — the deterministic per-session run context library fulfilling FR-222, US9 AS1-4, Principle IX (Reproducibility), NFR-200 (Bash 3.2 compat), and NFR-203 (double-sourcing guard). Exports ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN, ORCH_RUN_MILESTONE, ORCH_RUN_PHASE via init_run_context. Deterministic mode: when ORCH_RUN_SEED is set, both run_id (run-seed-<cksum-hash>) and started_at (2026-01-01 anchor + hash mod 1 year) are derived from the seed so repeated runs are byte-identical — verified run-seed-3399945452:2026-10-24T05:17:32Z stable across two bash -c invocations. Non-deterministic mode: uses current UTC date + 8-char nonce from /dev/urandom (fallback to cksum of PID+RANDOM). orch_now reads ORCH_STARTED_AT for frozen timestamps so no downstream script needs inline date calls (Principle IX enforcement point). orch_is_forced/orch_is_dry_run accept 1|true|TRUE|yes|YES via case statement. Applied both T01/T02 lessons preemptively: (1) guard placed on lines 3-4 so head -5 detection passes on first run, (2) all behavioral verification checks used 'export VAR=val; . script' form to avoid the bash var-prefix scoping quirk. All 18 verification checks printed PASS on first run with zero deviations. File is 90 lines (>=70 required), Bash 3.2 compatible (no declare -A, readarray, mapfile, process substitution), and idempotent under double-sourcing.
