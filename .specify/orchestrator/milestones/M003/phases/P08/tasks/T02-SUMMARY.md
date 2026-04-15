---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P08"
milestone: "M003"
provides:
  - "scripts/orchestrator/status.sh CLI wrapper; three-tier root resolution; MILESTONE/STATE/PHASE structured output contract; exit codes 0/1/2; AD-19 invoke-not-source integration with resolve-root.sh and derive-phase.sh"
requires:
  - "from:M008/P04 what:scripts/state/resolve-root.sh --absolute; from:M001 what:scripts/state/derive-phase.sh; from:M003/P08/T01 what:independent (T02 does not depend on T01)"
affects:
  - "M003/P08/T03 (verify script m003-p08-status-wrapper-contract.sh targets this file); M003/P08/T04 (integration test invokes status.sh against migrated fixture); roadmap demo sentence now literally executable"
key_files:
  - "scripts/orchestrator/status.sh"
key_decisions:
  - "AD-19"
patterns_established:
  - "three-tier root resolution precedence (flag > env > resolver fallback); state derivation from file presence (SUMMARY.md -> complete, PLAN.md -> executing, else pending) per MEM003; subprocess invocation of derive-phase.sh per milestone dir"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P08/tasks/T02-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-15T03:28:18Z"
---

Created scripts/orchestrator/status.sh — a thin Bash 3.2 CLI wrapper that resolves an orchestrator state root via three-tier precedence (--root flag > ORCHESTRATOR_ROOT env > scripts/state/resolve-root.sh --absolute fallback) and emits a structured milestone summary by walking milestones/ directories.

**Output contract**: per discovered milestone, emits one `MILESTONE: <ID>` line, one `STATE: <state>` line (derived by invoking scripts/state/derive-phase.sh as a subprocess), and zero or more `PHASE: <Pxx> <state>` lines where state is `complete` (if P##-SUMMARY.md exists), `executing` (if P##-PLAN.md exists), or `pending` otherwise.

**Exit codes**: 0 = at least one milestone found; 1 = no milestones/ dir or empty; 2 = resolver failed / root not a directory.

**AD-19 compliance**: invokes resolve-root.sh and derive-phase.sh via `bash <script>` subprocess calls, never sources them. Avoids `set -u` variable-shadow failures (P07 invoke-not-source pattern).

**MEM001 compliance**: no declare -A, no ${var,,}, no |&; uses $# argc checks instead of $2 unguarded; every output line is a single echo (no compound bash in output contract).

**Smoke tests (manual, matches T03 verify script contract)**: file exists (PASS), executable (PASS), 106 lines ≥ 40 (PASS), contains resolve-root (PASS), contains MILESTONE: (PASS), handles --root (PASS). Against .specify/orchestrator prints MILESTONE: M002…M008 with per-phase derived state; ORCHESTRATOR_ROOT env fallback works; --root pointing at a missing dir exits 2 with clear stderr.

**Known observation**: M001 has no milestones/M001 directory in this repo (it predates that layout convention), so it does not appear in the walk. This is expected — the wrapper reports what is on disk per MEM003 (state-on-disk-is-truth).
