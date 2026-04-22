---
description: "Use when reconciling orchestrator state with GitHub Issues/Milestones/Projects v2 after init — reconcile pass only (no create). Closes sub-issues, updates Project v2 status via updateProjectV2ItemFieldValue, respects per-item retry boundaries, emits unit_close JSONL."
---

# orchestrator:github-sync

Reconcile orchestrator state with the GitHub projection layer created by `orchestrator:github init`. Sync is a reconcile pass — it diffs cached sidecar state against desired orchestrator state and pushes deltas. Unlike `init`, it never creates new Milestone/Project v2/Issues; it only closes sub-Issues and flips Project v2 status fields when phases complete.

## Prerequisites / State Check

- Sidecar must be populated (`STATUS: configured` per `orchestrator:github status`). Sync no-ops cleanly when sidecar is absent or pending.
- `gh auth status` must be green. Sync exits with rc=4 on auth-expired.
- Lifecycle lock must not be held by another orchestrator process. Sync acquires the lock at entry and releases on every exit path (FR-7).

## Core Workflow

1. **Invoke sync**: `bash scripts/integrations/github-sync.sh [--dry-run] [--i-am-operator] [--conversus-gate] [--timeout <sec>]`
2. **Sync modes**:
   - `manual` (default): operator runs `sync` when desired.
   - `on-transition`: the Claude Code `post-verify` hook invokes sync after every verified task. Requires `sync_mode: "on-transition"` in sidecar.
   - `cron`: operator-owned cron schedule (see `references/github-integration.md` Sync Modes for registration guidance).
3. **Dry-run contract**: `--dry-run` emits an upsert manifest with per-row reasons (`close`, `status-sync`, `skip-nochange`) + a footer `upserts=<N> skipped=<M> errors=<E>`. Manifest shape is byte-identical to `init --dry-run`.
4. **Lock acquisition (FR-7)**: sync acquires the lifecycle lock at entry; released on every exit path.
5. **Rate-limit + auth-expiry (FR-16)**: sync exits with rc=3 on rate-limit (emits `RATE-LIMIT: retry-after=<ISO>`), rc=4 on auth-expired (emits `AUTH-EXPIRED: run gh auth refresh`). No auto-retry inside the rate-limit window.
6. **Observability (FR-17)**: sync emits one `unit_close` JSONL record per Done-phase closure or sub-Issue close to `.orchestrator/execution-log.jsonl` in M019 Tier 1 shape with `source: "runtime"`.
7. **Conversus gate (opt-in)**: `--conversus-gate` wires a pre-close check through `scripts/integrations/github-conversus-gate.sh` for UAT-defect-closing sub-Issues. The gate invocation is emitted as a `conversus_gate_invocation` JSONL record.

## Output

Structured lines: `DRY-RUN:` header, per-row `UPSERT: <kind> <oid> <target> <reason>`, footer `upserts=<N> skipped=<M> errors=<E>`.

Live-mode side effects: GraphQL `updateProjectV2ItemFieldValue` mutations, `gh issue close` calls, per-item sidecar cache updates (`last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached`), JSONL records appended to `.orchestrator/execution-log.jsonl`.

## Idempotency

Sync is idempotent under a stable-state fixture: a second `--dry-run` against unchanged state emits a manifest with `upserts=0 errors=0` (all rows `skip-nochange`). The per-item cache `last_attempt_at` is the only field that moves under a live re-run with no state change.

## Error Handling

- `rc=0` — successful (including dry-run, auto-mode short-circuit with `STATUS: pending-operator-complete`).
- `rc=3` — rate-limit hit. Retry after the ISO timestamp in the `RATE-LIMIT:` diagnostic.
- `rc=4` — auth-expired. Run `gh auth refresh` and retry.
- `rc=6` — lock acquisition failed. Another sync is running.
- `rc=1` — other error.

## Referenced Scripts

- `scripts/integrations/github-sync.sh` — the implementation.
- `scripts/integrations/github-conversus-gate.sh` — invoked when `--conversus-gate` flag set + UAT-defect closing.
- `scripts/integrations/github-common.sh` — shared helpers (marker search, JSONL emitter, sidecar cache update).
- `scripts/dispatch/adapters/tool/conversus.sh` — upstream adapter (M011/P07; M013 is the invoking caller).
- `scripts/lifecycle/lock-manager.sh` — lifecycle lock acquisition.

## Referenced Templates

- `templates/github-integration-sidecar.json` — schema source.
