---
schema_version: "1.0"
type: context-draft
milestone: "M013"
status: finalized
created_at: "2026-04-21T16:40:02Z"
finalized_at: "2026-04-21T16:42:11Z"
---

## Architectural Decisions

**Settled pre-discuss by D014 (conversus red-blue arbitration) — binding, not re-opened here:**

- FR-12 post-verify hook handler registration is **Claude-Code-only for v1**. Codex CLI and Cursor fall back to `sync_mode: manual` at init with a clear diagnostic; non-Claude-Code runtime-adapter work is deferred to a future milestone.
- **Minimal Slice** is Phase 1's load-bearing scope: full US-3 + minimal US-1 scaffolding (sidecar config + UAT template install + index widening) + US-2 idempotency applied to UAT entries only.
- FR-9 index widening is **additive-emit only**. `chunk_id` is pinned to existing `SPEC-*` IDs from `knowledge/spec/**/SPEC-*.md` frontmatter — no new ID format authored here.
- **Knowledge-Layer Boundary (M013 vs. M020)**: M013 writes to the knowledge tree at exactly two points (FR-9 flat list emit + FR-10 `spec/defect` entries with `{chunk, phase, tests}` edges). Review-state lifecycle, dispatch-callable query surface, and entry clustering are M020 scope.
- **Sub-issue representation**: GitHub sub-issue REST link when available; else `parent:<phase-id>` / `child:<task-id>` labels with reciprocal Issue-body links. Checklist-items-only is explicitly rejected.
- **Conversus gate invocation site**: the single D007-named UAT PR gate (US-6), invoked via `scripts/dispatch/adapters/tool/conversus.sh` with `--strict` and a 30-second default timeout. No other gate sites in v1.

**Decided during this discussion:**

- **A1 (Phase decomposition sketch)** — three phases:
  - **P01 Minimal Slice** — sidecar config with `pending`-sentinel path, UAT Bug template install, FR-9 index widening (additive-emit), FR-10 ingestion path writing `spec/defect` entries with `{chunk, phase, tests}` edges, `orchestrator:github status` command.
  - **P02 Full US-1 projection** — `orchestrator:github init` creating Milestone + Project v2 + phase Issues + task sub-issues; lazy projection (Issues created on phase/task transition to Ready, not at init time); FR-4 marker idempotency; FR-14 re-init adoption via marker search; label-collision preflight.
  - **P03 Sync cycle + hooks + conversus gate** — `orchestrator:github sync` with FR-6 per-item cache, FR-7 lock acquisition, FR-8 exit reporting, FR-15 `--dry-run`, FR-16 rate-limit + auth-expiry detection, FR-17 M019 Tier 1 emission, FR-18 `status --verify-cache`; FR-12 Claude-Code post-verify hook descriptor under `packaging/bundle/hooks/post-verify.json` + one-line installer wiring; FR-13 conversus UAT PR gate invocation.

  Planning may split P03 if the FR-13 gate wiring proves heavier than anticipated, but the default is a single P03 so the full spec→issue→sync→gate loop is exercised end-to-end within this milestone.

- **A2 (Sync orchestration locus)** — new top-level **`scripts/integrations/`** namespace for `github-sync.sh` and any GitHub-specific helpers. Rationale: GitHub integration is not dispatch-adapter-shaped (it's not a backend Claude dispatches to; it's a side-effect projection of orchestrator state). Parallel to existing `scripts/state/`, `scripts/verify/`, `scripts/knowledge/` organization. The M011/P07 conversus adapter stays where it is (`scripts/dispatch/adapters/tool/`) because it is dispatch-shaped.

- **A3 (Command file shape)** — **one file per subcommand**: `commands/github-init.md`, `commands/github-sync.md`, `commands/github-status.md`. Follows existing single-command-per-file convention across the 13 current commands. A short `commands/github.md` index/overview may ship alongside if planning finds it useful for discoverability, but the authoritative definitions live in the per-subcommand files.

## Scope Boundaries

**In scope for M013:**

- The dogfood target is **`github.com/Build-Fractal/spec-kit-orchestrator` (this repo's own origin)**. The repo is confirmed clean of hand-maintained Issues, so the FR-14 re-init marker-search path will be verified on empty baselines rather than mixed-origin state.
- **FR-13 conversus UAT PR gate is wired AND dogfooded within M013** (SC-9 is **not** N/A for this cut). The adapter must be exercised end-to-end in at least one test at the UAT PR gate before M013 closes, so that M014's downstream consumption lands on a known-good adapter integration and any sharp edges surface here rather than leaking into M014 scope.
- **Multi-project readiness**: the sidecar-per-project pattern (FR-6 at `.orchestrator/integrations/github.json`) must work cleanly when a second orchestrator-using project is introduced in the near term. Planning should verify that no helper script hard-codes repo slugs, orchestrator-id namespaces, or label palettes in a way that prevents a second consuming project from running `orchestrator:github init` independently against its own remote.

**Out of scope for M013 (spec-level non-goals reaffirmed):**

- Bi-directional sync beyond the two named read-backs (UAT ingestion in M013; comment routing in M014).
- Comment classification, triage, or auto-apply (all M014).
- Webhooks, daemons, long-running sync processes.
- Cross-repo or org-wide rollups.
- Non-GitHub hosts.
- Migration from pre-existing hand-maintained Issues/Projects (not applicable given the clean-slate dogfood target).
- Additional conversus gate sites beyond US-6 (deferred per Constitution XIV).
- FR-12 handler registration on Codex CLI / Cursor runtimes (deferred per D014).

## Design Constraints

- **Bash 3.2 compatibility (Constitution IX)** and **`scripts/verify/anti-pattern-lint.sh` clean (Constitution XV + M016/M021 hardening)** for all shipped shell, hooks, and command payloads.
- **Zero Claude Code approval prompts in auto mode (SC-7)**, inheriting the M016/M021 zero-prompt baseline. The on-transition post-verify hook must not introduce new prompt triggers.
- **REST-first**: ≥90% of writes via `gh` subcommands. GraphQL limited to three named call shapes (`createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`) per FR-5; CI lints the call-shape set.
- **Marker idempotency** (FR-4): every orchestrator-generated Issue body carries `<!-- orchestrator-id: <id> -->`. Search-by-marker before create. A duplicate marker is a bug. Planning should reuse the M012 `shasum` byte-identity invariant-verification idiom where applicable.
- **Pending-sentinel is not graceful degradation** (FR-6): when init runs under auto-mode without live network/auth, the config is written with `pending` sentinels, no sync occurs, and non-init commands error with a clear "integration not configured: run `orchestrator:github init` to complete setup" diagnostic until the operator completes the config. Preserves M007 no-dual-code-path discipline.
- **Reversibility-by-delete** (FR-11, SC-5): deleting `.orchestrator/integrations/github.json` returns orchestrator commands to pre-integration behavior with zero `gh` subprocess spawns, zero config-missing warnings blocking execution, and zero dangling hooks that call `gh`. Verified by subprocess trace.
- **Per-item retry boundaries** (FR-7): one failed upsert does not abort remaining items. Rate-limit responses are the exception — they abort the GraphQL-dependent portion and are not re-attempted per-item within the same run.
- **SC-12 scope-cap magnitudes** — **recommended targets for planning to pin**:
  - New shell scripts outside `scripts/integrations/`: **≤5 files** (primarily hook descriptor consumers and any minimal wrappers; most new logic lives inside `scripts/integrations/`).
  - Hook-contract LOC (the new `packaging/bundle/hooks/post-verify.json` descriptor + its installer wiring in `packaging/install/install-claude-code.sh`): **≤40 LOC total**, consistent with the size of existing descriptors (`after-implement.json`, `after-tasks.json`, etc.).
  Planning may adjust either ceiling with a recorded rationale; these are the starting points.
- **SC-13 operator overhead ceiling** — **recommended target**: combined auth rotation + rate-limit diagnostics + cache reconciliation ≤ **2 hours/quarter/operator** during steady-state use. Exceeding this during M013 dogfooding is signal for M009 launch docs to recommend GitHub App over PAT as the default onboarding path.
- **Rate-limit preflight threshold** (FR-16): projected GraphQL volume > 50 mutations triggers a `gh api rate_limit` preflight. Keeping the threshold at 50 (the spec default) rather than lowering it — dogfood dataset sizes during M013 are expected to exceed 50 mutations on first-init for realistic milestones, so the preflight will be exercised naturally.
- **FR-17 observability emission shape**: `conversus_gate_invocation` record ships with the spec's `{gate_id, adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd}` baseline. No additional fields added at this stage — M019 owns schema evolution; M013 is a producer only.
- **Dogfood-target-specific constraint**: the `Build-Fractal/spec-kit-orchestrator` remote must have Projects v2, Issues, Milestones, and Discussions enabled (Discussions prerequisite inherited from M012). Verify before P02 planning.

## Open Questions

Spec Open Questions (deferred to planning) — confirmed carried over without addition:

1. **Project v2 status field values** — exact names and ordering (Planning / Ready / Executing / Verifying / Blocked / Done vs. some variant). Planning decision, small stakes.
2. **Post-verify hook install descriptor shape for Claude Code** — exact descriptor file location under `packaging/bundle/hooks/` and the shape of the one-line installer wiring in `packaging/install/install-claude-code.sh`.
3. **`--dry-run` manifest format** — plain text vs. JSON. Affects whether downstream tools can parse the manifest.
4. **UAT ingestion trigger** — manual command vs. cron pull (no webhooks per Constraints). Planning chooses the default.
5. **Custom-field mapping ergonomics** — field name vs. field ID vs. both in `github.json`. Affects first-run UX and whether a GraphQL preflight is needed at init to resolve IDs.
6. **Cross-milestone re-init** — does `init` re-run when a new milestone begins, or does `sync` auto-detect and create the new Milestone + Project v2 item set? Recommendation is the latter; planning confirms.
7. **PAT-vs-App default for M009 external-adopter onboarding** — informed by SC-13 per-operator overhead measured during M013 dogfooding. M013 supports all three auth modes (FR-2); M009 picks the recommended default.

No new open questions introduced in this discussion.
