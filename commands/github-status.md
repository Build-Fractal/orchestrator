---
description: "Use when reporting GitHub integration sidecar state — absent, pending-operator-complete, or configured. Read-only; makes no GitHub API calls."
---

# orchestrator:github-status

Report the current state of the M013 GitHub integration sidecar config at `.orchestrator/integrations/github.json`. This command is read-only — it never writes to GitHub and never writes to orchestrator state (except optionally when `--init-pending` is passed, which delegates to the pending-sentinel bootstrap helper from T01).

## Prerequisites / State Check

No orchestrator state requirements. Runs in any orchestrator state. The sidecar file itself is operator-owned and gitignored; this command never modifies it outside the explicit `--init-pending` path.

## Core Workflow

1. **Invoke the status script**: `bash scripts/integrations/github-status.sh [--init-pending]`
2. **Interpret the STATUS line** (always the first line of stdout):
   - `STATUS: absent` — sidecar file does not exist. Integration is off. Run `bash scripts/integrations/github-status.sh --init-pending` to bootstrap a pending-sentinel config, or run `orchestrator:github init` (P02) to configure fully.
   - `STATUS: pending-operator-complete` — sidecar exists but at least one top-level field carries the literal value `"pending"`. The `PENDING_FIELDS:` line names them. The operator must complete these fields (typically by running `orchestrator:github init` on first live session).
   - `STATUS: configured` — sidecar is populated. The `REPO_SLUG:`, `SYNC_MODE:`, `LAST_SYNC:`, and `CACHE_ITEMS:` lines report current state.
3. **Report to developer**: print the script's stdout verbatim, then a short plain-English gloss.
4. **Verify cache divergence**: `bash scripts/integrations/github-status.sh --verify-cache`
   - Walks each cached `items.<oid>` and probes remote via marker search (`gh_marker_search_remote`).
   - Emits one `DIVERGENCE:` line per detected mismatch (classes: `missing-remote`, `missing-cache`, `status-mismatch`).
   - Exit codes: `0` (zero divergences, `SUMMARY: --verify-cache divergences=0`), `5` (≥1 divergence, `SUMMARY: --verify-cache divergences=<N>`).
   - **Never writes** — reports only. Operator must decide whether to re-init / reconcile manually.
   - On absent or pending sidecar, no-ops with `STATUS: pending-operator-complete` + exit 0 (FR-11 reversibility; FR-18 `--verify-cache` semantics).

## Output

Verbatim script output followed by a one-line summary. Example configured output:

```
STATUS: configured
REPO_SLUG: Build-Fractal/spec-kit-orchestrator
SYNC_MODE: manual
SUB_ISSUE_MODE: native
LAST_SYNC: 2026-04-25T14:22:10Z
CACHE_ITEMS: 17

GitHub integration is configured; 17 cached items; last sync ~2h ago; manual sync mode; sub-issue representation: native.
```

Example absent output:

```
STATUS: absent

GitHub integration sidecar not present. Run with --init-pending to scaffold, or run orchestrator:github init to configure.
```

## Idempotency

Fully idempotent: running multiple times without arguments produces identical output. With `--init-pending`, the second invocation finds the sidecar already present and leaves it unchanged (the underlying `sidecar-init-pending.sh` helper refuses to clobber, exit 2 — but `github-status.sh` swallows that and re-reports the current status).

## Error Handling

- `exit 0 STATUS: absent|pending-operator-complete|configured` — successful report (this is a reader, not a gate — pending/absent are not errors).
- `exit 0 SUMMARY: --verify-cache divergences=0` — `--verify-cache` ran against a configured sidecar and found no divergences.
- `exit 1 STATUS: schema-mismatch` — the sidecar file exists but is missing required top-level fields per FR-6. The `MISSING_FIELDS:` line (stderr) names them. Operator must delete and re-init.
- `exit 2` — invalid CLI flag. Check the `--help` output.
- `exit 5 SUMMARY: --verify-cache divergences=<N>` — `--verify-cache` detected one or more divergences. One `DIVERGENCE:` line per class is emitted on stdout. Read-only — operator decides remediation.

## Referenced Scripts

- `scripts/integrations/github-status.sh` — the implementation (read-only reporter).
- `scripts/integrations/sidecar-init-pending.sh` — invoked on `--init-pending` (from T01).

## Referenced Templates

- `templates/github-integration-sidecar.json` — schema source, M013/P01/T01 deliverable.
