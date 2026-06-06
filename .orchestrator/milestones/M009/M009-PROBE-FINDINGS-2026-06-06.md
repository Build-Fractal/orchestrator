# M009 — `cursor-agent` Live Probe Findings

**Date:** 2026-06-06
**Probe operator:** orchestrator dogfood session (CC)
**Brief:** `.orchestrator/proposals/M009-cursor-support.md` §9 (first step before any code)
**Status:** ✅ probe SUCCEEDED — Tier-A unknowns de-risked; **Q1 (Tier-B elicitation crux) RESOLVED live** (see Addendum (b))
**Environment:** macOS (darwin 24.6.0), `cursor-agent 2026.06.04-5fd875e`, logged in as `bkellgren@gmail.com` (browser login, no `CURSOR_API_KEY`)

---

## 0. TL;DR

The brief's central thesis is **confirmed live**: current `cursor-agent` provides true fresh-context headless dispatch with a clean machine-readable JSON result, runs against an arbitrary workspace dir, completes a write-a-file task in ~16s with **no hang**, and exits 0. The adapter is a viable near-copy of `local-codex.sh` with a *validated* invocation — unlike the codex placeholder, we now have the real shape. Two adapter-shaping surprises vs. the brief: (a) failures split into **two** modes (preflight → non-zero exit + stderr; runtime → expected `is_error` in JSON), and (b) the result JSON carries **no file-diff fields** — file changes must be read back from disk (matches the brief's read-back assumption). Q1 (does *headless* honor MCP elicitation) remains the open Tier-B crux and needs its own MCP-server probe.

---

## 1. Validated invocation (the golden shape)

```
cursor-agent -p --force --trust --output-format json \
  --model <model> --workspace <cwd> "<prompt>"
```

Flag notes (from `cursor-agent --help`, verified live — corrects/extends the brief):

| Flag | Role | Note |
|---|---|---|
| `-p` / `--print` | headless/non-interactive; "access to all tools incl. write & shell" | the dispatch entry point |
| `--output-format json` | one-shot JSON result on stdout | also `text` (default) and `stream-json` (deltas) |
| `-f` / `--force` (alias `--yolo`) | allow commands unless explicitly denied | needed for autonomous write/shell |
| `--trust` | trust workspace without prompting; **"only works with --print/headless mode"** | required to avoid a trust prompt deadlock in headless |
| `--model <m>` | model selection | examples in help are `gpt-5, sonnet-4, sonnet-4-thinking`; **default = `composer-2.5-fast`** |
| `--workspace <path>` | working dir | cleaner than relying on cwd; used a plain non-git `/tmp` dir successfully |
| `-w` / `--worktree [name]` | **built-in git worktree isolation** at `~/.cursor/worktrees/<repo>/<name>` | NOT in the brief — Cursor has native worktree isolation; may simplify the orchestrator's worktree-per-task model |
| `--sandbox enabled\|disabled` | sandbox override | — |
| `--resume [chatId]` / `--continue` | session continuity | default is fresh-context-per-call (matches brief decision) |

The codex adapter passes the payload via `codex run --prompt-file "$PAYLOAD"`. `cursor-agent` takes the **prompt as a positional argument** (no `--prompt-file` flag observed). **Open detail (minor):** whether it reads the prompt from stdin — adapter will likely use `"$(cat "$PAYLOAD")"` as the positional arg, or pipe via stdin (test during adapter build).

---

## 2. Q2 — stdout JSON schema (SUCCESS path)

Golden fixture: `probe-fixtures/cursor-agent-success.json` (single-line, exactly as emitted).

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "duration_ms": 8148,
  "duration_api_ms": 8148,
  "result": "Creating `hello.txt` ...\nCreated `hello.txt` ...",
  "session_id": "40712072-...",
  "request_id": "9f875ae8-...",
  "usage": {
    "inputTokens": 15922,
    "outputTokens": 193,
    "cacheReadTokens": 39564,
    "cacheWriteTokens": 0
  }
}
```

**Field map for the dispatch-result parser (FR-2):**
- **final-result field** = `result` — a *natural-language prose summary*, NOT structured. The agent's terminal answer.
- **success signal** = `subtype:"success"` + `is_error:false`. (The presence of these booleans strongly implies an error variant: `is_error:true` / `subtype != "success"` on runtime failure — see §3.)
- **file-diff fields** = **NONE.** The JSON does not enumerate created/modified files or diffs. **→ The orchestrator's existing read-back / verification-layer-inspects-the-workspace approach is mandatory** (same posture as `local-codex.sh` §"Artifacts" comment). This validates the brief's "after-stop sync from the dispatch wrapper's existing read-back step (non-issue)."
- **cost inputs** = `usage{inputTokens, outputTokens, cacheReadTokens, cacheWriteTokens}`. Token counts present; **no USD cost** in the JSON → FR-7 cost integration must apply a rate card (or degrade to `estimated_cost_usd:null` + `pricing_warning`, the already-supported Tier-A path). `duration_ms` / `duration_api_ms` also available.
- **correlation** = `session_id` + `request_id` (useful for `--resume` and for cost/audit linkage).

---

## 3. Q2 — failure semantics (TWO distinct modes)

Fixture: `probe-fixtures/cursor-agent-fail-badmodel.txt`. Forced via an invalid `--model`:

- **Exit code: 1 (non-zero).**
- **stdout: empty** — *no JSON emitted at all*, despite `--output-format json`.
- **stderr: plaintext** error (`Cannot use this model: ... Available models: ...`).

So **preflight / argument-validation failures are NOT error-in-JSON** — they are classic Unix `exit≠0 + stderr`. Meanwhile the success JSON's `is_error:false` / `subtype:"success"` booleans imply a **second** failure mode: a *runtime* error (model fails mid-task, tool error, etc.) likely surfaces as `is_error:true` / `subtype != "success"` **inside** the JSON on a possibly-zero exit.

**Adapter rule (FR-1/FR-2):**
1. Branch on **process exit code first.** Non-zero → failure dispatch-result; error payload = stderr.
2. On exit 0, **parse JSON and also check `is_error` / `subtype`.** `is_error:true` → failure dispatch-result even though the process exited 0.
3. Only treat as success when exit 0 **and** `is_error:false`.

(Not yet captured: a real *runtime* failure's exact exit code + JSON shape. Recommend capturing one during adapter build — e.g. a deliberately impossible task or a revoked-permission scenario — to pin mode #2's golden fixture.)

---

## 4. Risk 1 — `-p` headless hang

**Not observed.** The "write hello.txt" task completed in **16s wall / 8.1s API**, exit 0, watchdog never fired. The documented early-2026 `cursor-agent -p` hang bug did not reproduce on `2026.06.04`.

**Still mitigate anyway** (the bug is version-specific and beta surfaces churn): the probe used a **pure-bash watchdog** (background the process, poll `kill -0`, `TERM` then `KILL` on timeout) because **macOS has no `timeout`/`gtimeout`**. The adapter must ship this watchdog rather than assume a `timeout` binary. Recommended default: **150s** watchdog was generous; a real task budget should be configurable. Version-pin / `cursor-agent --version`-assert from day one (FR-1).

Reusable watchdog implementation: `/tmp/cursor-probe.sh` (this session's probe).

---

## 5. Q1 — MCP elicitation in headless (Tier-B crux — ✅ RESOLVED, see Addendum (b))

> **Update:** Q1 was resolved live later the same day by standing up a minimal
> MCP server. **Headless cursor-agent supports elicitation but auto-declines
> it** (no UI), with no hang. See **Addendum (b)** for the full result and the
> FR-6 design consequence. The text below was the pre-resolution analysis.

**Not resolved by the initial probe** — and could not be without standing up an MCP server, which is a Tier-B-sized task, not part of the 30-min Tier-A probe.

What was captured (MCP wiring surface, via `cursor-agent mcp --help`):
- MCP servers configured in `.cursor/mcp.json` or `~/.cursor/mcp.json`.
- Subcommands: `mcp login|list|list-tools|enable|disable`.
- A headless run can auto-approve MCP *server loading* via `--approve-mcps`.

**Important distinction:** `--approve-mcps` approves *loading a server*; it says nothing about whether a runtime `elicitation/create` *request-for-input* can render when there is **no interactive surface** (`-p` has no TTY prompt UI). Strong a-priori expectation: headless `-p` **cannot** render an interactive elicitation, so it will either auto-decline, error, or hang — which would collapse native AskUserQuestion review gates to the **file-hand-off** path (matches the brief's Tier-A degradation and risk 2). But this MUST be tested, not assumed.

**Recommended dedicated Q1 probe (Tier-B, ~1–2 hr):** write a minimal MCP server exposing one tool that calls `elicitation/create` with an enum schema; register it in `.cursor/mcp.json`; run `cursor-agent -p --force --approve-mcps` with a prompt that triggers the tool; observe (a) does it render / block / auto-decline / hang, (b) exit code + JSON shape on each. This single probe gates FR-6 and answers Q5 (auto-mode semantics for unanswered elicitation).

---

## 6. Q3 — model availability / tier gating (ANSWERED)

`cursor-agent models` returned a large roster on this account (full list in session log). Highlights:
- **Default:** `composer-2.5-fast` (Cursor's own model — cheapest/fastest; used `composer-2.5` for the probe).
- `auto` (Cursor picks).
- Anthropic: `claude-opus-4-8-*` (low/medium/high/xhigh/max ± thinking ± fast, 1M ctx), `claude-4.6-opus-*`, `claude-4.6-sonnet-*`, `claude-4.5-sonnet`, `claude-4-sonnet`, etc.
- OpenAI: `gpt-5.5-*`, `gpt-5.4-*` (+ `mini`/`nano`), `gpt-5.3-codex-*`, `gpt-5.2-*`, `gpt-5.1-*`, `gpt-5-mini`.
- Others: `gemini-3.1-pro`, `gemini-3.5-flash`, `gemini-3-flash`, `grok-4.3`, `grok-build-0.1`, `kimi-k2.5`.

The brief's guessed `composer-2` / `gpt-5.2` names are stale/partial: it's **`composer-2.5`** and the GPT family is much broader. **No tier-gating error hit** on this account for `composer-2.5` headless dispatch (so this account's plan permits headless agent use). Per-model billing in USD is still undocumented in the JSON (only token `usage`); FR-7 needs a rate card. **`models` / `--list-models` is the programmatic enumeration source** the adapter/routing can call to validate a requested model before dispatch (avoids the §3 mode-1 failure).

---

## 7. Contract mapping → `cursor-agent.sh` (next step if hand-building Tier A)

The existing backend contract (from `local-codex.sh`):
- `--probe` → emit `available=true|false`, `backend=cursor-agent`, `reason=...`. Probe = `command -v cursor-agent` **AND** auth present (`cursor-agent status` shows logged-in **OR** `CURSOR_API_KEY` set). *Note: auth is a real precondition Cursor adds over codex — bake it into the probe.*
- normal mode `--task-plan <p> --payload <p> --intensity-metadata <p>` → emit `dispatch-result.md` (YAML frontmatter `schema_version/type/status/backend/task_id/phase_id/milestone_id/dispatched_at/completed_at/duration_s` + markdown body). `backend: "cursor-agent"`.
- Discovered + routed purely by filename → **zero edits to `dispatch-interface.sh` / `backend-registry.sh`** (brief FR-011/SC-003). Verify with a backend-registry discovery assertion.

Adapter-specific additions vs. the codex template:
1. **Watchdog** around the subprocess (§4) — non-negotiable, and no `timeout` binary on macOS.
2. **Two-mode failure handling** (§3) — exit-code branch + JSON `is_error` branch.
3. **Auth precondition** in `--probe` and a clean failure dispatch-result when unauthenticated.
4. **`--workspace`** set to the task's worktree; rely on the verification layer for file read-back (no diff in JSON).
5. **`usage`→cost**: pass token counts through; degrade to `estimated_cost_usd:null` + `pricing_warning` until FR-7 rate card lands.

---

## 8. Recommendation on path forward

**Hand-build the Tier-A slice** rather than immediately running `orchestrator:specify`. Rationale: the brief is already a high-quality spec, the invocation is now *validated* (the single biggest unknown), the adapter is a contained near-copy of `local-codex.sh`, and Tier A delivers a concrete dogfoodable outcome ("a Cursor user runs a full autonomous milestone end-to-end"). Promote to a formal milestone via `orchestrator:specify` when ready to commit to **Tier B** (MCP elicitation server + cost model + byte-parity audit), where the scope genuinely warrants spec→roadmap→plan rigor and where Q1 must be resolved first.

**Immediate next actions (in order):**
1. ✅ **DONE** — Q1 MCP-elicitation probe (§5 / Addendum (b)): native gates viable; headless auto-declines into auto-mode policy.
2. ✅ **DONE** — hand-built `scripts/dispatch/adapters/backend/cursor-agent.sh` (§1 + §7) with the §4 watchdog and §3 two-mode failure handling, plus runtime-aware auto-default (Addendum (a)). Validated end-to-end live.
3. ✅ **DONE (stubbed)** — thin acceptance suite `tests/test-cursor-agent-adapter.sh` (29/29). Still pending: a **real** runtime-failure golden fixture (§3 mode 2) from a live cursor-agent error (currently only stubbed).
4. ✅ **DONE** — stale-assertion corrections (brief §10): FR-3 (`--hook-config` real hooks.json + `install-cursor.sh` `hooks_wired=1` + the shape-guard wrapper + `CURSOR_AGENT` probe) in Addendum (c); FR-4 (`--register` splits commands → `.cursor/commands/` + always-on rule → `.cursor/rules/`) in Addendum (d). m008-p05/p06 verifiers updated; tests green.
5. **TODO (Tier-B, via `orchestrator:specify`)** — the orchestrator MCP review-gate server (FR-6) now that Q1 confirms the architecture; cost model (FR-7); byte-parity audit (FR-8).

---

## 9. Probe artifacts (this session)

- `probe-fixtures/cursor-agent-success.json` — golden SUCCESS result (byte-exact).
- `probe-fixtures/cursor-agent-fail-badmodel.txt` — preflight-failure capture (exit 1 + stderr).
- `/tmp/cursor-probe.sh` — success probe + reusable pure-bash watchdog.
- `/tmp/cursor-probe-fail.sh` — failure-semantics probe.
- Raw success stdout: `/tmp/cursor-probe-stdout.json`.

## 10. Brief corrections / new facts (feed into `orchestrator:specify` on promotion)

- Default model is **`composer-2.5-fast`**; full roster is far broader than the brief's `composer-2`/`gpt-5.2` guess (§6).
- **`--trust` is required** in headless to avoid a workspace-trust prompt deadlock (not in the brief).
- `cursor-agent` has **native `-w/--worktree` isolation** — may simplify the orchestrator's worktree model (new finding).
- Result JSON has **no file-diff fields** — read-back mandatory (confirms brief assumption, now evidenced).
- Failures are **two-mode** (exit-code vs in-JSON) — the brief's Q2 ("non-zero exit OR error-in-JSON") is answered as **both, depending on failure class** (§3).
- The `-p` hang did **not** reproduce on `2026.06.04`, but **no `timeout` binary on macOS** → adapter must carry its own watchdog (§4).
- Auth is a genuine precondition (login OR `CURSOR_API_KEY`) — fold into `--probe` (§7).

---

## Addendum 2026-06-06 — runtime env signals + auto-default

A follow-up probe (`cursor-agent ... "env | sort > env-dump.txt"`) captured the
environment `cursor-agent` exports to every shell it spawns:

```
CURSOR_AGENT=1
CURSOR_INVOKED_AS=cursor-agent
NODE_COMPILE_CACHE=/Users/.../Library/Caches/cursor-compile-cache
```

(An `AI_AGENT=claude-code_...` value also appeared — but that was *leaked from
the parent Claude Code shell that launched the probe*, NOT a Cursor signal.
Don't key off `AI_AGENT`.)

**`CURSOR_AGENT=1` is the canonical, reliable runtime signal.** It is present
whenever the orchestrator runs *under* `cursor-agent`, which is exactly the
condition under which the cursor backend should auto-select as default.

**Adapter consequence (shipped):** the `--probe` "enabled" decision is now:
`ORCHESTRATOR_CURSOR_ENABLE=1` (force on) / `=0` (force off) / unset →
auto-enable iff `_cursor_runtime_active` (`CURSOR_AGENT=1` |
`CURSOR_INVOKED_AS=cursor-agent` | `CURSOR_TRACE_ID` | `CURSOR_SESSION_ID` |
`CURSOR_USER`). A bare `.cursor/` dir is deliberately NOT a signal (a CC user
can have one). Net: a real Cursor session gets the backend with zero env
fiddling; a CC machine never auto-selects it. The default-hijack guard (risk 6)
holds because none of these signals are set on a CC machine.

**New stale assumption found:** `scripts/dispatch/adapters/runtime/cursor.sh`
`--probe` checks `CURSOR_TRACE_ID` / `CURSOR_SESSION_ID` / `CURSOR_USER` (IDE
signals) but **not** `CURSOR_AGENT` — so it likely does **not** detect the
headless `cursor-agent` runtime at all. Fold a `CURSOR_AGENT=1` signal into
that adapter's probe when the FR-4 registration/runtime-correction work lands
(brief §10). Tracked here so the two probes stay consistent.

---

## Addendum (b) 2026-06-06 — Q1 RESOLVED: MCP elicitation in headless mode

Built a minimal stdio MCP server (`probe-harness/mcp-elicit-server.py`),
registered it via `.cursor/mcp.json`, and drove a headless
`cursor-agent -p --force --trust --approve-mcps` run told to call an
`ask_user` tool that issues `elicitation/create`. Golden capture:
`probe-fixtures/mcp-elicitation-headless.log`.

**Results (definitive):**
1. **Headless cursor-agent SUPPORTS elicitation.** Its `initialize` request
   declared `clientInfo:{"name":"Cursor","version":"1.0.0"}` and
   `capabilities:{"elicitation":{"form":{}}}`. Negotiated protocolVersion
   `2025-11-25`. The full MCP handshake (initialize → initialized → tools/list
   → tools/call → server→client elicitation/create → response) completed.
2. **In headless/`-p` mode the elicitation auto-DECLINES.** The client answered
   `elicitation/create` **instantly** with `{"action":"decline"}` — there is no
   interactive surface to render a form. **No hang, no error, no deadlock**
   (this retires the hang half of risk 2). Agent exited 0 in 8s and faithfully
   reported the decline.

**Design consequence — native review gates ARE viable (FR-6 path):**
- **Interactive Cursor (IDE/TUI):** the `{"elicitation":{"form":{}}}` capability
  means a real form renders → `action:accept` with content. Native
  AskUserQuestion works for human-in-the-loop sessions.
- **Headless / autonomous Cursor:** elicitation deterministically returns
  `action:decline`. This maps cleanly onto the orchestrator's existing
  **auto-mode gate policy** (Q5): treat `action` ∈ {`decline`,`cancel`} as
  "no human response available → apply the plan-declared `defer` /
  `accept-with-audit` / `block` policy." No special hang-handling, no mandatory
  file-hand-off fallback — though file-hand-off remains a valid belt-and-braces
  default for Tier A before the MCP server exists.

**Q1 verdict:** headless honors elicitation at the protocol level but cannot
render it (auto-declines). So FR-6's orchestrator MCP server is the right
shape: expose review gates via `elicitation/create`; interactive sessions get
native prompts, autonomous sessions get a clean deterministic decline that the
auto-mode policy consumes. **Q5 is answered by the same finding.**

**Scope note:** FR-6 (the orchestrator's own MCP review-gate server) is
Tier-B / milestone-sized and should go through `orchestrator:specify`. This
probe de-risks the architecture; it does not itself ship the server.

**MCP elicitation `action` values** (MCP spec, confirmed in the capability):
`accept` (with `content`), `decline` (explicit no), `cancel` (dismissed).
Headless → `decline`.

---

## Addendum (c) 2026-06-06 — FR-3 SHIPPED: beforeShellExecution shape-guard

Verified live that headless `cursor-agent` honors `.cursor/hooks.json`
`beforeShellExecution`, then shipped the safety-veto port.

**Hook input contract** (golden: `probe-fixtures/cursor-hook-input.json`):
top-level `{"command":"<shell cmd>","hook_event_name":"beforeShellExecution",
"cwd":...,"model":...,"sandbox":...,"cursor_version":...,"workspace_roots":[...],
"user_email":...,"transcript_path":...}`. **Differs from Claude Code** (CC nests
the command at `tool_input.command`).

**Hook output contract:** emit `{"permission":"allow"|"deny"|"ask"}` (optional
`agentMessage`/`userMessage`). Live findings:
- A `deny` BLOCKS the command (the chain never ran — file MISSING).
- **To surface the hook's message to the agent, exit 2** (JSON-only + exit 0
  blocks but shows Cursor's generic "blocked by a hook" text). With exit 2,
  Cursor relays the hook stdout — so the agent sees the full
  `REJECT: <class> — use scripts/util/<wrapper> …` diagnostic and can
  self-correct. (Verbatim parity with `pre-bash-shape-guard.sh`, which also
  exits 2 + writes the REJECT line.)

**Shipped:**
- `scripts/hooks/cursor-before-shell-shape-guard.sh` — reads Cursor's stdin,
  reuses the SAME `scripts/verify/lib/shape-classifier.sh`, translates
  `allow`/`reject:`/`rewrite:` to Cursor's permission contract. `rewrite:`
  classes become deny-with-suggested-form (Cursor can't rewrite in place).
- `cursor.sh --hook-config` now emits a real `hooks.json` (was
  `hooks_supported="false"`); `--probe` now detects `CURSOR_AGENT` /
  `CURSOR_INVOKED_AS` (closing the headless-runtime gap from Addendum (a)).
- `install-cursor.sh` writes `<project>/.cursor/hooks.json` (idempotent,
  non-clobbering of operator hooks) and reports `hooks_wired=1`.
- m008-p06 verifier flipped `hooks_wired=0` → `=1` + hooks.json assertions.
- Hermetic suite `tests/test-cursor-shape-guard-hook.sh` (18/18).

**Live end-to-end demo:** with the wrapper wired via `.cursor/hooks.json`, a
headless `cursor-agent` told to run `mkdir -p a && touch a/x && echo done >
chain-ran.txt` was **blocked** by the real shape-classifier (compound-chain-gt2);
`chain-ran.txt` never created; the agent received the `run-probe.sh` remedy.

**`failClosed` decision (deliberate divergence from the brief):** the emitted
hooks.json sets `failClosed:false` and the wrapper fails OPEN on infra errors
(missing classifier → allow). Rationale: the shape-guard is a shape-CORRECTOR,
not a security boundary; CC's guard fails open by design (M028 Finding A), and
a failClosed guard would deny ALL shell commands if the hook script broke,
bricking autonomous runs. Recorded here as an explicit, reasoned departure from
the brief's `failClosed:true` suggestion.

---

## Addendum (d) 2026-06-06 — FR-4 SHIPPED: native command surface

Corrected the "integration is rules-only / no skills equivalent" stale
assumption (false since Cursor `.cursor/commands/` v1.6).

`cursor.sh --register` now splits to the Cursor-native surfaces:
- **Invocable commands** → `.cursor/commands/orchestrator-<cmd>.md` (one per
  `commands/*.md`, README excluded). These are the true analog of Claude Code
  slash skills — invoked on demand as `/orchestrator-<cmd>`, not always-loaded.
- **Always-on operating instructions** → `.cursor/rules/orchestrator.md`, an
  `alwaysApply: true` rule that declares the project orchestrator-managed,
  notes the beforeShellExecution shape-guard, and lists the command index.

This replaces the pre-FR-4 behavior that dumped every command's full body into
`.cursor/rules/` (always loaded — context-heavy and not how Cursor models
invocable commands). Emit shape: `registered=true count=<N>` + `rules=1`
(count = command files; the two-line emit preserves install-cursor.sh's
`count=` parse).

Verifiers updated: m008-p05 (register hermetic) now asserts the commands dir +
always-on rule + the preserved HOME-hermetic guard; m008-p06 (install hermetic)
asserts `.cursor/commands/` + the rule. Hermetic suite
`tests/test-cursor-shape-guard-hook.sh` extended to 24/24.

**Not done (deliberate Tier-A scope):** an `AGENTS.md` at project root (the
brief's "+ AGENTS.md"). Writing/merging a project-root AGENTS.md risks
clobbering operator content and needs a merge strategy — deferred. The
`.cursor/rules/orchestrator.md` always-on rule covers the always-loaded
operating-instructions need for now.

---

## §10 stale-assumption status (updated 2026-06-06)

1. "Cursor has no lifecycle-hook API" — ✅ CORRECTED (FR-3, Addendum (c)).
2. "Integration is rules-only / no skills equivalent" — ✅ CORRECTED (FR-4, Addendum (d)).
3. "Cursor cannot be a dispatch backend" — ✅ CORRECTED (cursor-agent.sh adapter).
4. "No native mid-run structured-question primitive" — ✅ CLARIFIED (Q1 / Addendum (b)): MCP elicitation exists; headless auto-declines.
5. RUNTIME-ASSUMPTIONS scopes Cursor parity as compression-only — ✅ CORRECTED (FR-9): added the `## Cursor dispatch, hooks & interactive (M009)` section with rows `RA-M009-CURSOR-01` (auth required / no air-gap), `-02` (headless cost/pricing TBD), `-03` (headless elicitation declines) to `references/RUNTIME-ASSUMPTIONS.md`.
6. `local-codex.sh` invocation is an unvalidated placeholder — unchanged (out of M009 scope; noted for M008/M010).

---

## Tier-A status + remaining work (handoff, 2026-06-06)

**Shipped + live-validated this session** (branch `m009-cursor-tier-a`, 6 commits):
FR-1 (dispatch adapter), FR-2 (JSON parse + golden fixture), FR-3 (shape-guard
on `beforeShellExecution`, live-demoed block), FR-4 (commands/ + always-on
rule), FR-9 (RUNTIME-ASSUMPTIONS rows). Plus runtime-aware auto-default and the
Q1 elicitation resolution. Tests: `test-cursor-agent-adapter.sh` 29/29,
`test-cursor-shape-guard-hook.sh` 24/24; m008-p05/p06 verifiers updated + green.

**Remaining Tier-A (NOT done — start fresh):**
- **FR-5 — before-commit git hook.** Wire `scripts/lifecycle/before-commit.sh`
  as a git `pre-commit` in the Cursor install path. **Deliberately deferred to
  a fresh context**: this is the riskiest remaining item — a careless wiring
  blocks *every commit* in the consumer repo. Needs: (a) reading
  `before-commit.sh`'s exit semantics (does it hard-fail outside an active
  milestone? it must NOT block ordinary commits), (b) a clobber-guard for an
  existing `.git/hooks/pre-commit`, (c) non-git-repo + `--dry-run` + uninstall
  handling, (d) a hermetic verifier. It is NOT de-risked by any live probe.
- **Real runtime-failure golden fixture (§3 mode 2).** Capture a live
  cursor-agent runtime error (exit 0 + `is_error:true`) — currently only
  stubbed in the acceptance suite.

**Tier-B (via `orchestrator:specify`):** FR-6 orchestrator MCP review-gate
server (architecture de-risked by Q1), FR-7 cost model + `cursor:` rate card,
FR-8 byte-parity audit under `ORCH_BACKEND=cursor`.

**Context-rot note:** the session that produced this was long; FR-5 was stopped
*before* implementation specifically to avoid a context-fatigued mistake in
commit-blocking machinery. Treat the above as the authoritative next-step list.
