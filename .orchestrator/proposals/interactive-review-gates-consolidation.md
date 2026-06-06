# Scoping note: consolidate M034 (interactive review gates) + M009-FR6 (Cursor MCP renderer) + conversus producer

**Captured:** 2026-06-06
**Status:** scoping input for `orchestrator:specify` — NOT yet a committed milestone
**Trigger:** a real Cursor dogfooder who *will* use interactive review gates, with conversus open-sourcing imminently. This is the "second downstream consumer" demand signal M034's brief waited for (`M034-interactive-review-gates.md` §"Why post-launch", §Sequencing).
**Inputs:** `.orchestrator/proposals/M034-interactive-review-gates.md`, `.orchestrator/proposals/M009-cursor-support.md` (Tier-B FR-6), `.orchestrator/milestones/M009/M009-PROBE-FINDINGS-2026-06-06.md` (Q1 / Addendum (b)), conversus adapter `scripts/dispatch/adapters/tool/conversus.sh`.

---

## 1. The collision (and why it's actually one feature)

Three things looked like separate work; they're one architecture:

- **M034** owns the runtime-agnostic *interactive review gate*: a **decision-packet schema** (P01) + an **interactive walkthrough stage** (P02) that surfaces load-bearing decisions, captures operator responses to `REVIEW.md`, and populates `SIGNOFF.md`. Opt-in per phase via plan frontmatter; `auto`-mode policies `defer` / `accept-with-audit` / `block`.
- **M009 Tier-B FR-6** is "an orchestrator MCP review-gate server for Cursor." That is **not a separate feature** — it is the **Cursor *renderer/transport*** for M034's walkthrough, exactly as `AskUserQuestion` is the CC transport.
- **conversus** is a **producer**: it runs a deliberation over an artifact and emits a `PASS|BLOCK` verdict + rationale + surviving-disputes + a link to the full deliberation. That output is decision-packet *content*, surfaced by the gate. conversus does not render anything.

**M034 Finding D already wrote this down**: route the walkthrough through `dispatch-interface.sh` so each runtime adapter handles its own question primitive uniformly, and — verbatim — *"If M034 ships before M009, M034's runtime-assumption rows are the runtime-parity entries until M009 broadens the audit."* So the correct move is to **build M034 with the Cursor renderer (FR-6) as one of its runtime adapters from day one**, not to build FR-6 as an M009-Tier-B silo and re-reconcile later.

**Downside avoided:** building FR-6 standalone now means hand-rolling a packet shape, then re-shaping it when M034's schema lands — guaranteed rework + two interactive-review surfaces to keep in sync.

## 2. Layering (the contract that prevents drift)

```
                 ┌─────────────────────────────┐
   PRODUCER  →   │  decision-packet schema      │   (M034 P01 — the shared contract)
  conversus      │  DECISIONS.md, typed YAML,    │
  (optional)     │  named-constant thresholds,   │
                 │  severity: warn|block          │
                 └──────────────┬──────────────┘
                                │ consumed by
                 ┌──────────────▼──────────────┐
                 │  interactive_review stage     │   (M034 P02)
                 │  routed via dispatch-interface│
                 └──────┬─────────┬─────────┬────┘
        ┌───────────────┘         │         └────────────────┐
        ▼                          ▼                          ▼
  CC: AskUserQuestion    Cursor interactive:        headless / auto (CC or Cursor):
   (native tool)          MCP elicitation/create     QUESTIONS.md hand-off +
                          = M009 FR-6 renderer        auto-mode policy (defer/…)
```

**Single schema. Three renderers. One optional producer.** Everything keys off the decision-packet schema being defined *once* (M034 P01) with the GSD-derived discipline already in the M034 brief (typed YAML verdict, named scoring constants in one place, `severity: warn|block`).

## 3. What the Q1 probe already settled (de-risks FR-6)

From `M009-PROBE-FINDINGS-2026-06-06.md` Addendum (b):

- **Interactive Cursor (IDE/TUI):** declares `capabilities:{"elicitation":{"form":{}}}` → a real form renders → `action:accept` with content. **Native review gates work.** This is the only place the FR-6 MCP server is load-bearing.
- **Headless / autonomous Cursor:** elicitation deterministically returns `action:decline` instantly — no hang, no error. This maps onto M034's auto-mode policy (`decline`/`cancel` → apply declared `defer`/`accept-with-audit`/`block`). **No MCP server needed for headless** — the existing `QUESTIONS.md` hand-off + auto-policy fallback (M034 P02 Finding D) already covers it.

**Consequence for scope:** the FR-6 MCP server is only required to give *interactive* Cursor sessions native prompts. If the dogfooder runs autonomous milestones, the gate works on Tier-A-shipped infrastructure + M034 P02's fallback with **zero** MCP-server work. **Confirm the dogfooder's mode (interactive IDE vs headless `cursor-agent`) before committing to the MCP-server build** — it may be deferrable.

## 4. conversus-OSS dependency — pin this before scoping

The gate's value to this dogfooder is "run conversus, surface its verdict, let me adjudicate." That puts conversus on the critical path:

- **The producer already exists:** `scripts/dispatch/adapters/tool/conversus.sh gate [--strict] <preset> <artifact> <output>` → exit 0 (PASS) / 2 (BLOCK) / 1 (error). Output `gate-result.md` carries `verdict`, `disputes`, `rationale`, `source_hash`, and `conversus_output_dir` → `summary/final.md` (the full deliberation). `parse-verdict` extracts the verdict. This maps directly into decision-packet entries.
- **HAZARD — silent SKIP:** with the binary missing, non-strict `gate` emits `SKIPPED … bypassed` and **exits 0**. If the dogfooder lacks conversus, gates silently no-op and they'd think review ran when it didn't. The consolidated milestone MUST run conversus-backed gates **`--strict`** (or surface SKIPPED loudly in the packet), and the dogfooder onboarding MUST verify conversus is installed.
- **OSS install + auth:** resolver order includes `~/Sites/conversus-oss/bin/conversus` and PATH; install via `pipx install conversus-oss`. On OAuth (no `ANTHROPIC_API_KEY`) set **`CONVERSUS_PROVIDER=claude-code`** — the adapter auto-detects `~/.conversus/auth.json` and flips to `claude-code`, but confirm `conversus login anthropic` was run. (Matches the repo's established conversus-OSS posture.)
- **OSS cutover risk:** `.orchestrator/scratch/conversus-oss-migration-parity.md` flags that if OSS ships under a different pipx name and that upstream PR #28 (claude-code success classification) / #29 (OAuth parallel-429) aren't in the OSS branch point, the integration may break. Re-run the conversus adapter parity check against the actual OSS build before the dogfooder relies on it.

## 5. Recommended milestone scope (feed to `orchestrator:specify`)

Author **one milestone** ("interactive review gates"), phased:

| Phase | Scope | Notes |
|---|---|---|
| **P00** | Empirical baseline | M034 brief already prescribes replaying lakeledger M066/P01 as the fixture. ADD: a conversus-gate-result → decision-packet mapping fixture, and a Cursor-interactive elicitation transcript fixture. |
| **P01** | **Decision-packet schema** (shared contract) + writer | M034 P01 verbatim: `templates/decisions-packet.md` (versioned frontmatter), `scripts/knowledge/write-decisions.sh`, `severity: warn\|block`, named-constant thresholds. **+ conversus producer adapter**: map `gate-result.md` (verdict/disputes/rationale/`final.md` link) into packet entries. Ships standalone value (audit + `doctor`/`status` surfacing) even with no walkthrough. |
| **P02** | **Interactive walkthrough stage** routed via `dispatch-interface.sh` + REVIEW.md + SIGNOFF integration + `auto`-mode policies + boundary-translation packet type (M034 Finding E) | Renderers: CC `AskUserQuestion` + **headless fallback `QUESTIONS.md`** (covers autonomous CC *and* autonomous Cursor — Q1). This is the full M034 value and works for the dogfooder if they run headless. |
| **P03 (conditional)** | **Cursor MCP review-gate server (M009 FR-6)** — native elicitation renderer for *interactive* Cursor | Only if the dogfooder runs interactive IDE/TUI sessions (see §3). The orchestrator-owned stdio MCP server exposing review gates via `elicitation/create`, registered in `.cursor/mcp.json`. Architecture de-risked by Q1. |

**Deferred / cheap add-ons (not in this milestone unless asked):**
- **M009 FR-7 (Cursor cost model):** keep deferred. No USD in `cursor-agent` JSON → a hand-maintained rate card against a beta product. Keep the Tier-A `estimated_cost_usd:null` + `pricing_warning` degrade.
- **M009 FR-8 (byte-parity audit under `ORCH_BACKEND=cursor`):** low-risk, mostly mechanical; fold in as a verification task whenever convenient — does not need to gate this milestone.

## 6. Open questions for `orchestrator:specify`

1. **Dogfooder runtime mode?** Interactive Cursor IDE/TUI (→ P03 MCP server is load-bearing) vs headless `cursor-agent` (→ P03 deferrable; P02 fallback suffices). **Single biggest scope lever.**
2. **conversus as default producer or opt-in?** Recommend opt-in per gate (`producer: conversus` in plan frontmatter) — preserves M034's "load-bearing, opt-in" framing and avoids forcing a conversus dependency on every gate.
3. **`--strict` conversus by default in gated phases?** Recommend yes (or loud SKIPPED-in-packet) to kill the silent-skip hazard (§4).
4. **Milestone identity:** does this *become* M034 (absorbing M009-FR6/FR-8), or a new milestone that closes M034 + the M009-Tier-B FR-6/FR-8 line items? Recommend: author as M034 and explicitly mark M009 FR-6/FR-8 as satisfied-by-M034 in the M009 brief, leaving M009 FR-7 as the lone deferred Cursor item.
5. **All six M034 open questions** (its §"Open questions") still stand — packet placement, `auto_mode` default, REVIEW.md placement, etc. Resolve there.

## 7. One-line recommendation

Ship Tier-A now (PR #10) → put the dogfooder on it → author **M034 as the consolidated milestone** (schema → conversus producer → renderers, with the Cursor MCP server as a *conditional* P03 gated on whether they run interactive). Don't build FR-6 as an M009 silo; don't build FR-7's rate card.
