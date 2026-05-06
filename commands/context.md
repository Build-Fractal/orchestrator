---
description: "Use when checking the orchestrator runtime profile — resolved root, runtime, capability profile, intensity defaults, active milestone, lock state. Read-only single-screen debug skill."
---

# orchestrator:context

Render a single-screen snapshot of the runtime profile this orchestrator session is sitting on. This is the M029 / FR-4 surface — a quick "what runtime am I in, and is this state even valid?" debug skill that an operator drops into any orchestrator-managed project to grok the environment without scrubbing config files.

The skill is **read-only** (CON-1 / FR-14 / SC-14): no writes anywhere, no log emission, no state mutation. It composes existing surfaces — `scripts/state/resolve-root.sh`, `scripts/state/find-active-milestone.sh`, `scripts/state/read-config.sh`, the AD-1 invocation-context resolver, and the lock-manager state file lookup pattern from `commands/status.md`'s `### Stale Lock File` section. **No new scripts are introduced by this skill in P01.**

The full output MUST fit a **single screen ≤24 lines on 80×24 (SC-4)**. Each labeled field renders on exactly one line; multi-value fields wrap onto a single line via space-separated `key=value` pairs and truncate with `…` when wrapping risks exceeding the column budget (with a stderr advisory naming the truncated field).

## Output Format

The rendered output is a single block of six labeled lines, in fixed order. Labels are exact (literal strings, including the trailing colon and one space):

```
resolved root: /Users/foo/Projects/myproject
runtime: claude-code
capability profile: BACKEND=claude-code OS=darwin BASH_VERSION=3.2.57 GIT=2.45.0
intensity defaults: quick.knowledge_token_budget=800 standard.dispatch_budget=64 full.dispatch_budget=128
active milestone: M029 (planning, Tier C)
lock state: free
```

Every line carries one labeled field; the labels are exact: `resolved root:`, `runtime:`, `capability profile:`, `intensity defaults:`, `active milestone:`, `lock state:`. When no active milestone exists, the active-milestone line renders as `active milestone: none`. When the lock-manager state file is absent or unparseable, `lock state: unknown` (not `error` — the read-only contract permits graceful degradation, never a crash).

When the lock is held, `lock state:` mirrors `commands/status.md`'s headline form: `lock state: held by PID <pid> since <timestamp>`.

## Single-Screen Constraint

The full output MUST fit in a single screen — no more than **24 lines on an 80-column terminal**. Each labeled field is one line. Multi-value fields (capability profile, intensity defaults) wrap onto a single line via space-separated `key=value` pairs; if wrapping risks exceeding column width, the implementation truncates with `…` and emits a stderr `note: capability profile truncated; see scripts/state/...` advisory. The single-screen invariant is the load-bearing UX promise — it is what makes `orchestrator:context` cheaper than scrolling through `.orchestrator/config.yml` by hand.

SC-4 (the M029 acceptance battery) gates this invariant: `wc -l` against the rendered stdout MUST return ≤24.

## Resolution

Each field's source script:

- **resolved root** → `bash scripts/state/resolve-root.sh` (the standard 4-rule resolver: `ORCHESTRATOR_ROOT` env → config → `.orchestrator/` → default).
- **runtime** → env-var probing: `${CLAUDECODE:-}` → `claude-code`, `${CODEX_CLI:-}` → `codex-cli`, `${CURSOR_TRACE_ID:-}` → `cursor`, fallback to `unknown`. Cross-references the resolver's `default_provider` field (which carries the same info via config); when the resolver's `default_provider` disagrees with env-probing, the env-probe value wins (the env probe reflects the *current* runtime, the config reflects the *configured* default).
- **capability profile** → packaging marker probe: read `.orchestrator/capability-profile.json` if present; otherwise compose from `OS=$(uname -s | tr 'A-Z' 'a-z')`, `BASH_VERSION=${BASH_VERSION%%(*}`, plus best-effort `GIT=$(git --version 2>/dev/null | head -1)` etc. Truncate to fit the single-line budget.
- **intensity defaults** → `bash scripts/state/read-config.sh <key>` for the relevant intensity knobs; falls back to `templates/orchestrator-config-default.yml` keys when local config is absent.
- **active milestone** → `bash scripts/state/find-active-milestone.sh <root>` (returns `M### <state> <tier>` or `NONE`). The `NONE` exit-1 path renders as `active milestone: none`.
- **lock state** → mirrors `commands/status.md`'s `### Stale Lock File` lookup: read `<active-milestone-dir>/orchestrator.lock` if present; report `free` when absent, `held by PID <pid> since <timestamp>` when present and the PID is live, `unknown` when the file exists but is unparseable.

## AD-1 Single-Resolve

`orchestrator:context` reads `scripts/state/detect-invocation-context.sh`'s emitted env block at command entry (Principle XI — Single Source of Truth). The displayed `runtime` and `default_provider` lines come through the resolver, not from re-implemented detection:

```bash
eval "$(bash scripts/state/detect-invocation-context.sh)"
# now $renderer, $exit_code_scheme, $default_provider are set.
```

The resolver is the AD-1 single-resolve site for invocation context across every M029 surface (`status` headline, `--format=json`, `where`, `context`, live-tail, preflight). This skill MUST NOT re-implement TTY / CI / runtime probing — even when the env-var probe (`${CLAUDECODE:-}` etc.) drives the displayed `runtime` field, the underlying resolver's `default_provider` is the authoritative cross-check.

## Read-Only Discipline

CON-1 / FR-14 invariant: the skill writes nothing. It emits only to stdout (the rendered six-line block) and stderr (truncation advisories). No file I/O writes. No log emissions. No state mutation. No config writes. The skill MUST be safe to run concurrently with auto mode or dispatched tasks in another terminal, and safe to run against a corrupted or partially-built `.orchestrator/` tree without making things worse.

Cross-references SC-14 (the M029 milestone-grain read-only assertion that lands in P02 via the AD-9 sentinel-file mechanism); P01's precursor read-only verifier (`tools/verify/m029-p01-readonly-invariant.sh`, T06 deliverable) covers this skill against the SC-4 fixture.

## Idempotency

`orchestrator:context` is purely read-only and idempotent. Running it twice produces byte-identical stdout (modulo the live-PID lock-state field, which reflects current process state). It never holds locks. It never modifies log files. Running it during an active dispatch is safe.

## Error Handling

Graceful degradation for each field source. The skill MUST exit 0 even when every field is degraded; the operator sees a degraded-but-rendered profile rather than a crash:

- Missing `.orchestrator/config.yml` → `intensity defaults: <fallback to templates/orchestrator-config-default.yml>`.
- Missing capability marker → `capability profile: <synthesized from OS + BASH_VERSION>`.
- `find-active-milestone.sh` returns NONE / exit 1 → `active milestone: none`.
- Missing lock-manager state file → `lock state: unknown` (not `error`).
- Resolver returns the empty string for `default_provider` → `runtime: unknown`.

Stderr advisories are permitted (and expected when truncation occurs). The skill never crashes; it never returns non-zero from a degraded field.

## Reference Files

- `scripts/state/detect-invocation-context.sh` — AD-1 invocation-context resolver (single-resolve).
- `scripts/state/resolve-root.sh` — provides the `resolved root:` field.
- `scripts/state/find-active-milestone.sh` — provides the `active milestone:` field.
- `scripts/state/read-config.sh` — provides the `intensity defaults:` field.
- `templates/orchestrator-config-default.yml` — fallback source for intensity defaults when local config is absent.
- `references/status-headline-shape.md` — companion FR-2 design contract; `orchestrator:context` shares the resolver-eval-at-entry pattern with `orchestrator:status`.
- `references/status-json-schema.md` — companion FR-3 design contract.
- `commands/status.md` — `### Stale Lock File` lookup pattern reused for the `lock state:` field.
- `commands/zoom-out.md` — analog read-only debug skill (closest documentation shape).
