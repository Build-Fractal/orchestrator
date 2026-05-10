---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M035/P00"
milestone: "M035"
provides:
  - "managed .gitignore block emitter (FR-6/SC-6) for installer-owned sidecars; idempotent in-place block replacement; defensive duplicate-block collapse"
requires:
  - "from:M035/P00/T01 what:bash-3.2-safe installers with exit-status-propagating shapes"
affects:
  - "M035/P00 SC-6 (managed .gitignore block); future P02-P06 publishing pipelines (every install path now annotates the project .gitignore)"
key_files:
  - "scripts/lifecycle/emit-managed-gitignore.sh,packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m035-p00-managed-gitignore.sh"
key_decisions:
  - "opener/closer marker shape '# >>> orchestrator-managed: gitignore >>>' / '# <<< ... <<<' (mirrors CLAUDE.md orchestrator:recent-changes pattern); single-pass awk rewrite with state machine (in_block / seen_block / last_emitted_blank); separator policy = single blank line iff last emitted line was non-blank; helper-direct behaviour-layer fixtures + grep-based wiring layer (CI-portable across runtimes whose probes may fail)"
patterns_established:
  - "marker-delimited block primitive: opener + closer + body content; single helper script invoked identically from all 3 installers (mirrors install-meta.txt sidecar pattern); awk getline file pulls block body from temp file (avoids embedding multi-line strings in awk source); behaviour-layer testing via direct helper invocation when full installer run requires unavailable runtimes"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P00/tasks/T02-managed-gitignore-block-PLAN.md,scripts/lifecycle/emit-managed-gitignore.sh,tools/verify/m035-p00-managed-gitignore.sh"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-08T05:23:58Z"
---

Authored scripts/lifecycle/emit-managed-gitignore.sh — a bash-3.2 helper that idempotently emits a marker-delimited orchestrator-managed block in <PROJECT_DIR>/.gitignore covering installer-owned sidecars (currently .orchestrator/install-meta.txt). Single-pass awk rewrite implements: (1) absent target -> create with canonical block, (2) no block found -> append separated by a single blank line iff last line non-blank, (3) block found -> replace lines opener..closer in place (verbatim preservation outside), (4) defensive multi-block collapse -> keep first opener position, suppress duplicate ranges. --dry-run prints would_write=<file>; --block-content takes an optional body file. Wired identically into all 3 installers (install-claude-code.sh / install-codex.sh / install-cursor.sh) immediately after the install-meta.txt sidecar write, gated to skip on --uninstall and --repair (those paths short-circuit before this stage). Authored tools/verify/m035-p00-managed-gitignore.sh — 25 checks across two layers: wiring layer (grep-verifies each installer invokes the helper with --project-dir, surfaces non-zero rc, and positions the call after the install-path install-meta.txt write to prove it is not inside the uninstall/repair short-circuits) + behaviour layer (5 fixtures: A dry-run via install-claude-code.sh; B/C/D real-run via direct helper invocation covering create / preserve-user-content / idempotency; E defensive duplicate-block collapse). Verifier returns 25/25 PASS under bash 3.2.57. Confirmed T01 verifier (m035-p00-bash32-collision.sh) still 17/17 PASS and the T01 regression fixture (m035-collision-exit-status.sh) still 3/3 installers surface non-zero on producer failure. Concerns: (1) The behaviour fixtures B/C/D run against the helper directly rather than the full installer because install-codex.sh / install-cursor.sh probe-gate exit 3 in this dev env (cursor not available) — the wiring layer proves each installer invokes the same helper, so behaviour-layer parity follows. install-claude-code.sh dry-run runs end-to-end and emits the would_write line through the helper. (2) The canonical block currently lists only .orchestrator/install-meta.txt; future tasks (e.g. installed-files.txt, runtime payload, .orchestrator/cache/) can extend the body via --block-content without changing the marker contract. (3) The helper rewrites .gitignore atomically (mktemp + mv) but does not preserve the previous file's mode/owner explicitly — uses cp/mv defaults, which match the rest of the installer's filesystem operations.
