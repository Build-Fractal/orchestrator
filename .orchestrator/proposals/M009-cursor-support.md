# M009 — Cursor Support (Multi-Runtime Parity Audit)

**Status:** proposal brief — **Tier-A SHIPPED 2026-06-06** on branch `m009-cursor-tier-a` (hand-built per §8 of the probe-findings recommendation, not yet a committed milestone). **Tier-B remains demand-driven** — promote via `orchestrator:specify` when a real Cursor user arrives. See the *Build status* addendum at the foot of this file.
**Authored:** 2026-06-06
**Supersedes/absorbs:** the M009 placeholder referenced across the roadmap; absorption candidate for `.orchestrator/proposals/M0xx-out-of-tree-runtime-footprint.md` (it already plans to touch Cursor cache/instruction conventions)
**Source research:** a 2026-06-06 capability audit of *current* (mid-2026) Cursor against the orchestrator's three load-bearing runtime needs (dispatch, hooks, interactive). Findings + source URLs are inlined in §3 and §9.

---

## 1. Problem

The orchestrator runs **Claude-Code-only** at launch. Cursor was slotted as an aspirational post-launch fast-follow (this milestone, M009). The blocker was never the deterministic engine — M018/P07 already proved the Bash-only tiers (compression filters + Tier 1/2 + Tier 3 routing) are **SHA-256 byte-identical** across `claude-code` / `codex` / `cursor` (`references/RUNTIME-ASSUMPTIONS.md`, `tests/compression-runtime-parity/`). The blocker was the *agent-facing* surface: dispatch, hooks, and interactive prompts.

**The decisive finding:** the orchestrator's Cursor integration is ~April-2026 vintage and is now **stale by roughly a year**. Current Cursor has independently closed all three gaps:

- `scripts/dispatch/adapters/runtime/cursor.sh` hardcodes `hooks_supported="false"` ("Cursor uses rule-based integration; no lifecycle hooks") and registers all 14 commands as `.cursor/rules/` files.
- `packaging/install/install-cursor.sh` reports `hooks_wired=0` (hook wiring is a no-op).
- There is **no** `scripts/dispatch/adapters/backend/cursor*.sh` at all — Cursor can *register* skills but **cannot dispatch a single task**.

Mid-2026 Cursor makes all of that false (see §3). So "Cursor support" is materially more achievable than the codebase implies — it's mostly *correcting stale assumptions + a contract-compatible backend adapter*, not greenfield research.

## 2. Goals / Non-Goals

**Goals**
- **G1** A real **fresh-context dispatch backend** for Cursor.
- **G2** Port the bash shape-guard to Cursor's `beforeShellExecution` hook (restore safety-veto parity).
- **G3** Surface the 14 commands natively (`.cursor/commands/` slash commands + rules for always-on instructions).
- **G4** Correct the stale `cursor.sh --hook-config` / `install-cursor.sh` assertions.
- **G5** Cost + byte-parity audit under `ORCH_BACKEND=cursor` (Tier B).

**Non-Goals**
- **Cloud Agents REST backend** — it's GitHub-repo / branch-PR-centric and pushes branches rather than returning local file edits to a worktree; it fights the file-state-on-disk model. Explicitly rejected as the dispatch backend.
- **Air-gapped Cursor dispatch** — `CURSOR_API_KEY` is required even for local runs; offline Cursor dispatch is out of scope (document as a hard divergence).
- **Changing the Claude Code path** — CC stays the reference implementation.

## 3. Capability findings (current Cursor, mid-2026)

| Orchestrator need | Verdict | Current Cursor mechanism |
|---|---|---|
| Fresh-context dispatch | ✅ supported | `cursor-agent` headless CLI: `agent -p --force --output-format json --model <m>`; runs against cwd, fresh context per call, JSON result on stdout — a near-1:1 analog of `local-codex.sh`'s `codex run`. Also a TS/Python SDK (`Agent.create({local:{cwd}})`) with nested subagents. |
| Pre-shell veto (shape-guard) | ✅ supported | **Cursor Hooks v1.7 (Oct 2025).** `beforeShellExecution` ≈ CC `PreToolUse(Bash)`: JSON-on-stdin, `allow|deny|ask`, exit-code-2 deny, `failClosed:true`. |
| After-agent-stops sync | 🟡 partial | `stop`/`sessionEnd` hooks (IDE Agent). **Not** available in headless/cloud agents — for the CLI backend, drive after-stop sync from the dispatch wrapper's existing read-back step (non-issue). |
| Before-commit | ✅ supported | No native Cursor commit hook in either runtime, but a standard **git `pre-commit` hook** is runtime-agnostic and works today; optional `git commit` pattern-match in `beforeShellExecution`. |
| Interactive AskUserQuestion | 🟡 partial | **MCP Elicitation** (Cursor-supported since v1.5): `elicitation/create` with JSON schema (enum→multiple-choice, string→free-form). Requires the orchestrator to expose an MCP server. **Crux:** unconfirmed whether headless `cursor-agent` honors elicitation or only the IDE/TUI does. |
| Native command surface | 🟡 partial→clean | `.cursor/commands/<name>.md` custom slash commands (since v1.6, project + `~/.cursor` global) — the true analog of CC slash skills. Today the adapter dumps everything into `.cursor/rules/` instead. |

**Key source URLs** (verify on promotion — all beta-flavored, "APIs may change before GA"):
- CLI headless/print mode: https://cursor.com/docs/cli/headless ; https://cursor.com/docs/cli/using ; https://cursor.com/docs/cli/overview
- SDK local runs: https://cursor.com/blog/typescript-sdk ; https://cursor.com/changelog/sdk-updates-jun-2026
- Hooks: https://cursor.com/docs/hooks (v1.7 intro: https://www.infoq.com/news/2025/10/cursor-hooks/)
- MCP elicitation: https://cursor.com/docs/mcp.md ; https://cursor.com/changelog/1-5
- Custom slash commands: https://cursor.com/changelog/1-6
- Rules MDC: https://cursor.com/docs/rules
- ⚠️ `cursor-agent -p` headless-hang bug report: https://forum.cursor.com/t/cursor-agent-p-print-headless-mode-hangs-indefinitely-and-never-returns/150246

## 4. The dispatch crux (decision)

**Decision:** primary backend = a subprocess CLI adapter `scripts/dispatch/adapters/backend/cursor-agent.sh`, modeled on `local-codex.sh`, invoking `cursor-agent -p --force --output-format json`. Fresh-context-per-call by default (continuity only on explicit `--resume`). It satisfies the existing backend contract with **zero edits** to `dispatch-interface.sh` / `backend-registry.sh` — both discover and route the new file purely by filename (FR-011 / SC-003).

**Rejected:** Cloud Agents REST API (wrong shape — see §2 Non-Goals).
**Deferred (Tier B):** the SDK local-run adapter (`Agent.create({local:{cwd}})`) — richer (nested-subagent fan-out, closest analog to CC's in-process Agent/Task tool) but introduces a Node/Python dependency that breaks the pure-bash adapter invariant. Gate behind a capability probe; keep the CLI path default.

**Conclusion:** dispatch is **NOT** sequential-fallback-only — true fresh-context dispatch exists for Cursor.

## 5. Functional Requirements

- **FR-1** `cursor-agent.sh` backend adapter: `--probe` (`command -v cursor-agent` + `CURSOR_API_KEY` set) + normal mode → emit a conforming `dispatch-result.md`. Wrap the invocation in a `timeout`/watchdog (mitigates the documented `-p` hang) and pin/verify a known-good `cursor-agent` version.
- **FR-2** Parse `--output-format json` stdout into the dispatch-result schema; capture a **golden fixture** under `tests/`. (Mirrors the still-unfinished `TODO(M008-P02)` parser in `local-codex.sh` — do **not** inherit an unverified invocation; live-probe first.)
- **FR-3** `cursor.sh --hook-config` emits a real `hooks.json` fragment wiring `beforeShellExecution` → a thin wrapper around `scripts/hooks/pre-bash-shape-guard.sh` with `failClosed:true`; `install-cursor.sh` writes `.cursor/hooks.json` and reports `hooks_wired>0`.
- **FR-4** Split registration in `cursor.sh --register`: invocable `commands/*.md` → `.cursor/commands/orchestrator-<cmd>.md`; constitution / always-on operating instructions → `.cursor/rules/` (+ `AGENTS.md`). Keep the existing `PROJECT_DIR`/HOME hermetic guards (`m008-p05-cursor-register-hermetic.sh`).
- **FR-5** Before-commit via a runtime-agnostic git `pre-commit` hook wired into the Cursor install path (no Cursor-specific code).
- **FR-6** *(Tier B)* Thin orchestrator **MCP server** exposing the review-gate via `elicitation/create`; define auto-mode policy for an unanswered/declined elicitation (parity with CC `defer`/`accept-with-audit`/`block`).
- **FR-7** *(Tier B)* `cursor:` column in `templates/model-routing.yml` + a real cost_rates row; confirm headless model availability + subscription-tier gating.
- **FR-8** *(Tier B)* M009 parity audit: assign real IDs to the `RA-M018-01/02` + placeholder `M009-RP-01/02` rows; run the `compression-runtime-parity` corpus with `ORCH_BACKEND=cursor` asserting SHA-256 byte-equality; verify Tier 3 routes through `tier3-llm-call.sh` under Cursor.
- **FR-9** New `RUNTIME-ASSUMPTIONS.md` divergence rows: `RA-M009-CURSOR-01` (`CURSOR_API_KEY` required → no air-gapped run), `-02` (headless cost/pricing TBD), `-03` (review gate = file-hand-off in headless).

## 6. Phasing

**Tier A — honest degraded support (~1–2 weeks, 1 engineer).** FR-1…FR-5 + FR-9 + a thin acceptance suite (probe test, stubbed `cursor-agent` emitting canned JSON to assert a conforming `dispatch-result.md`, backend-registry discovery assertion). Review gates degrade to the existing `QUESTIONS.md` file-hand-off (written explicitly, not silently no-op'd); cost degrades to `estimated_cost_usd:null` + `pricing_warning` (already a supported path). **Outcome: a Cursor user runs a full autonomous milestone end-to-end.** Dominated by the live-probe of the `cursor-agent` JSON schema + the `hooks.json` wiring; the adapter skeleton is a near-copy of `local-codex.sh`.

**Tier B — real parity (~4–6 weeks, the full M009).** FR-6…FR-8 + the optional SDK fan-out backend + IDE-vs-cloud hook reconciliation + validating that existing CC hook scripts run unmodified under Cursor's "load Claude Code hooks" compatibility path (aim: one shared hook impl with thin per-runtime adapters). Long poles: the MCP server + cost-model integration. The byte-parity audit mostly leverages existing P07 infrastructure.

## 7. Risks

1. **`cursor-agent -p` headless hang** (documented early-2026 bug) — a naive subprocess adapter would deadlock autonomous runs. Mitigate: timeout/watchdog + version-pin from day one (Tier A, FR-1).
2. **Elicitation-in-headless unknown** — the load-bearing crux for *native* review gates. If headless `cursor-agent` does not honor MCP elicitation, the native AskUserQuestion path collapses to file-hand-off and auto-mode gate semantics have no documented Cursor equivalent.
3. **Unenumerated `cursor-agent` JSON schema** + exit-code semantics (failure as non-zero exit vs error-in-JSON) — fragile-parser risk; requires a live probe before the adapter is trustworthy.
4. **`CURSOR_API_KEY` required even for local runs** — no air-gapped Cursor dispatch; per-task cost accounting against Cursor's billing is undocumented.
5. **Beta-surface churn** — CLI print mode, SDK, and Cloud API are all beta; build only against version-pinned surfaces + an M009-style parity smoke test.
6. **Stale-assumption blast radius** — anything downstream keying off `hooks_supported=false` or the rules-only shape must be re-audited when these flip, or it silently disagrees with the new backend.

## 8. Open Questions

- **Q1** Does headless `cursor-agent` honor MCP elicitation, or IDE/TUI only? *(gates FR-6)*
- **Q2** Exact `--output-format json` schema + does failure surface as non-zero exit or error-in-JSON? *(gates FR-2)*
- **Q3** Headless model availability (composer-2 / gpt-5.2) + subscription-tier gating? *(gates FR-7)*
- **Q4** Do the existing CC hook scripts run unmodified under Cursor's "load Claude Code hooks" path (single shared impl)?
- **Q5** Auto-mode semantics for an unanswered/declined elicitation (parity with `defer`/`accept-with-audit`/`block`)?

## 9. First step (before any code)

A **~30-minute live probe**: install Cursor + `cursor-agent`, run `cursor-agent -p --force --output-format json --model <m> "write hello to a file"` against a throwaway worktree, and capture:
1. the exact stdout JSON schema (final-result field, file-diff fields),
2. whether failure returns a non-zero exit code or only error-in-JSON,
3. whether `-p` hangs and what timeout is safe,
4. whether MCP elicitation renders in headless mode (the Tier-B crux, Q1).

This single probe de-risks every Tier-A unknown **and** the Tier-B crux before a line of `cursor-agent.sh` is written. Save the canned JSON as the first golden test fixture, then scaffold `cursor-agent.sh` as a copy of `local-codex.sh` with the validated invocation swapped in.

## 10. Stale assumptions to correct (audit trail)

These are encoded in the codebase today and are now false:
1. **"Cursor has no lifecycle-hook API"** — `cursor.sh --hook-config` (`hooks_supported="false"`) + `install-cursor.sh` (`hooks_wired=0`). False since Cursor Hooks v1.7 (Oct 2025).
2. **"Integration is rules-only / no skills equivalent"** — `cursor.sh --register` dumps all commands into `.cursor/rules/`. False since `.cursor/commands/` (v1.6).
3. **Implicit "Cursor cannot be a dispatch backend"** — no `backend/cursor*.sh` exists. False: `cursor-agent` CLI + SDK both provide programmatic fresh-context dispatch.
4. **"No native mid-run structured-question primitive"** — partially false: MCP Elicitation (v1.5) provides one (requires an MCP server; headless behavior unconfirmed).
5. **`RUNTIME-ASSUMPTIONS.md` scopes Cursor parity as only the compression byte-equality story** — predates the now-available dispatch/hooks/elicitation surfaces; needs new divergence rows.
6. **`local-codex.sh` `codex run --prompt-file` is still a `TODO(M008-P02)` placeholder** — reminder that the subprocess-backend invocation shape has never been runtime-validated; the Cursor adapter must live-probe, not inherit.

---

*Promotion path:* run `orchestrator:specify` on this brief to author the M009 spec, then `evaluate → roadmap → plan-phase`. Tier A is the minimal shippable slice; Tier B is the full parity milestone.

---

## Build status (addendum, updated 2026-06-06)

**Tier-A is COMPLETE** on branch `m009-cursor-tier-a` (9 commits ahead of main). Hand-built per the probe-findings §8 recommendation rather than via `orchestrator:specify`, because the brief was already a high-quality spec and the live probe validated the single biggest unknown (the invocation shape). Authoritative record: `.orchestrator/milestones/M009/M009-PROBE-FINDINGS-2026-06-06.md`.

Shipped + live-validated:
- **FR-1** `cursor-agent` dispatch backend (`scripts/dispatch/adapters/backend/cursor-agent.sh`) — validated invocation, pure-bash watchdog (no `timeout` on macOS), two-mode failure handling, auth-precondition probe, runtime-aware auto-default keyed off `CURSOR_AGENT=1`.
- **FR-2** JSON result parse + byte-exact golden success fixture.
- **FR-3** `beforeShellExecution` shape-guard port (`scripts/hooks/cursor-before-shell-shape-guard.sh`, reuses the shared classifier) + real `.cursor/hooks.json` wiring (`hooks_wired=1`), live-demoed block.
- **FR-4** native command surface — `.cursor/commands/orchestrator-*.md` + always-on `.cursor/rules/orchestrator.md`.
- **FR-5** before-commit gate wired as a git `pre-commit` (`scripts/lifecycle/install-git-pre-commit.sh`) — clobber-safe, non-git skip, `core.hooksPath`-aware, fails OPEN, `--dry-run`/`--uninstall`. Safe because `before-commit.sh` is an `exit 0` no-op today.
- **FR-9** RUNTIME-ASSUMPTIONS Cursor divergence rows (`RA-M009-CURSOR-01/02/03`).
- **Q1 RESOLVED** — headless cursor-agent honors MCP elicitation at the protocol level but auto-declines (no UI), mapping cleanly onto auto-mode gate policy. De-risks the FR-6 architecture.

Tests: `tests/test-cursor-agent-adapter.sh` 29/29, `tests/test-cursor-shape-guard-hook.sh` 24/24, `scripts/verify/m009-fr5-cursor-pre-commit-hermetic.sh` 15/15, `m008-p05`/`m008-p06` hermetic verifiers green.

Known gap (not a Tier-A blocker): a **real** §3 mode-2 runtime-error golden (exit 0 + `is_error:true`) could not be synthesized across 6 live trigger classes — cursor-agent absorbs controllable errors into mode 1 or success. Capture opportunistically during dogfooding or under Tier-B.

**Tier-B (FR-6 MCP review-gate server / FR-7 cost model + rate card / FR-8 byte-parity audit)** is the next slice and should go through `orchestrator:specify` as a committed milestone — gated on a real Cursor user arriving (the project's demand-driven post-launch posture). Q1 already de-risked the FR-6 architecture; §10 of the probe-findings lists the brief corrections to fold into that spec (default model `composer-2.5-fast`, `--trust` required, native `-w/--worktree`, no file-diff fields in JSON, two-mode failures, no `timeout` on macOS, auth precondition).

**Tier-B re-scoped 2026-06-06** — a real Cursor dogfooder who wants interactive review gates (with conversus open-sourcing imminently) is the demand signal. **FR-6 is not a Cursor silo — it is the Cursor *renderer* for M034's runtime-agnostic interactive review gate** (M034 Finding D anticipated this). FR-6 + FR-8 should fold into a consolidated M034 milestone; FR-7 stays the lone deferred Cursor item. Scoping: `.orchestrator/proposals/interactive-review-gates-consolidation.md`.
