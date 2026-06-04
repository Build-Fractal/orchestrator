# M043 Handoff Brief — Cloudflare Pages + Access wiki-deploy target

**Written**: 2026-06-04 (end of a specify→evaluate→discuss→roadmap session)
**For**: a fresh agent resuming M043 cold.
**Current state**: fully planned, roadmap-ready. Next step is `orchestrator:plan-phase` for **P00**. Nothing committed — all artifacts are working-tree changes.

---

## What M043 is (one paragraph)

Add **Cloudflare Pages + Cloudflare Access** as a first-class, plan-independent wiki-deploy target alongside today's GitHub-Pages-only path. It exists because of a **live downstream incident** (`pbj-central-mono-repo`, validated 2026-06-04): a *private* GitHub Pages site is Enterprise-Cloud-only, so on Free/Pro/Team the orchestrator wiki (which surfaces confidential `.orchestrator/` content) either silently goes **public** or, when an Enterprise trial lapses, **422s on every push while the build stays green** — freezing the live wiki for days. The fix: a `wiki.deploy_target: github-pages | cloudflare-access` switch + a Cloudflare deploy workflow + an idempotent provisioner + docs + a safety warning. Demand-driven, not speculative.

## Where it stands in the SDD pipeline

| Stage | Status | Artifact |
|---|---|---|
| specify | ✅ done (Standard, gate PASS) | `specs/043-wiki-cloudflare-access-deploy-target/spec.md` |
| evaluate | ✅ done — **Tier C** | `.orchestrator/milestones/M043/M043-EVALUATION.md` |
| discuss | ✅ done — **finalized** (AD-1..AD-4) | `.orchestrator/milestones/M043/M043-CONTEXT.md` |
| roadmap | ✅ done — **5 phases, validated** | `.orchestrator/milestones/M043/M043-ROADMAP.md` |
| plan-phase | ⬜ **next: P00** | — |
| dispatch/execute | ⬜ | — |

`derive-phase` returns `planning`; `read-roadmap.sh --query active-phase` returns **P00**.

## The roadmap (5 phases)

```
        ┌──→ P01 ──┐
P00 ────┤          ├──→ P03 ──→ P04
        └──→ P02 ──┘
```

- **P00** (high, no deps) — Cloudflare API characterization spike. Resolves the two open research questions (below) and seeds P02's fixtures.
- **P01** (high, deps P00) — Target switch + Cloudflare deploy workflow (US-1). Config schema (FR-1), `templates/wiki-cloudflare-deploy.yml.tmpl` with the FR-3a health check (FR-3/FR-3a), `wiki-init.sh`/`wiki-deploy.sh` branching (FR-2/FR-4/FR-5), the npx-wrangler/health-check-ordering lint (SC-2/SC-10).
- **P02** (high, deps P00) — Idempotent provisioner (US-2). `scripts/wiki/cloudflare-access-setup.sh` + recorded-API fixtures (FR-6..FR-9). **Runs concurrently with P01.**
- **P03** (medium, deps P01,P02) — Docs + fallback-only footgun warning (US-3). `references/installation.md` + `run-doctor.sh`/status warning (FR-10/FR-11/FR-12).
- **P04** (low, deps P01,P02,P03) — Live/friendly-tester validation (US-4). Human-recruitment protocol + signed evidence (FR-13).

**Minimal slice = US-1 + US-2 = P00 → P01 + P02.** Milestone may close at shippable scope (P00–P03) with P04 forward-pointed under a signed deferred-validation note (M033/M041 precedent).

## The decisions already made (AD-1..AD-4 — do not re-litigate)

Resolved with the operator during discuss; full text in `M043-CONTEXT.md`. The operator took the recommended option on all four:

- **AD-1 (#Q-5) — FR-3a health-check probe = reuse the existing Edit-scope token.** The CI pre-deploy health check authenticates with the `CLOUDFLARE_API_TOKEN` already in repo secrets (Access Apps-and-Policies *Edit*). **Fallback** if Edit can't read: unauthenticated `302 → cloudflareaccess.com` redirect probe with `Cache-Control: no-cache`/retry mitigation. (The "add a new Read scope" option was rejected.)
- **AD-2 (#Q-3) — Warning = fallback-only branch.** `status`/`doctor` fire on every (private repo + `github-pages`) config regardless of plan, with an "ignore if Enterprise Cloud" note. **No plan-detection logic.** This collapses SC-6 and the FR-10 fixture matrix to a single branch.
- **AD-3 (#Q-1) — Default stays `github-pages`**; init/wiki-init *recommend* cloudflare-access on private repos; the AD-2 warning is the backstop. (Auto-defaulting private repos to cloudflare-access was rejected — too much init friction.)
- **AD-4 (#Q-4) — Soft M041-first.** Prefer sequencing after the M041 `scripts/wiki/` carve-out so the new setup script auto-distributes via `orchestrator:update`; if M041 isn't ready, ship with the documented manual-`cp` bridge. Not a hard block.

## The two genuinely-open questions → these ARE P00's job

Both are external-Cloudflare-API research, not orchestrator-internal. They passed the corpus-exhaustion gate as `kept`. **P00 resolves them; P01/P02 consume the answers:**

- **#Q-5-sub (Edit-scope-grants-read)** → determines FR-3a probe shape (authenticated-with-existing-token per AD-1, vs. redirect fallback). Answer via Cloudflare API docs / a one-call spike.
- **#Q-6 (API error envelope)** → determines FR-9 diagnostic shape: are "Zero Trust not enabled" and "token missing scope" mechanically distinguishable (HTTP status/error code/body field)? If not, FR-9 emits a single **combined** diagnostic and SC-5 is revised. (Principle II: don't assert distinguishability without evidence.)

## ⚠️ Critical gotchas for the resumer

1. **P00 execution needs real Cloudflare credentials.** Planning P00 is doable now; *executing* it requires a Cloudflare account + scoped token from the operator. P00 is a real spike against external reality, not a code-only task. Confirm credential availability before dispatching P00 execution.
2. **`spec-metrics.sh` chunks bug (D020 #1).** `spec_chunks_present=true` is a FALSE positive here — M043's spec was never `orchestrator:ingest`-ed, so the chunks belong to another spec. Roadmap was built from the **raw spec** (correct). If you re-run any chunks-first path, ignore the chunk counts for M043 or ingest spec 043 first.
3. **Bash shape-guard (AP-009).** This repo's PreToolUse hook rejects compound `&&`/`;` chains >2 and inline-HEREDOC-with-expansion (AP-008). Run probes as single commands; for multi-line commit messages use `git commit -F <file>` (Write the file first), never the inline-HEREDOC `-m "$(cat <<EOF...)"` form.
4. **The `<TODO:` footgun (D020 #2).** When authoring spec/plan prose, don't embed the literal scaffold-placeholder byte pattern in backticked code — the conversus gate pre-flight grep will false-trip on it. Paraphrase as "scaffold-placeholder marker."
5. **CON-6 is the soul of this milestone.** The exposure window is closed at *two* sites — provisioning-time (P02 setup script ordering) AND every-CI-deploy (P01 FR-3a health check). Neither may be dropped. A reviewer who removes the health check believing provisioning-time enforcement suffices reopens the exact `pbj-central` exposure. This was the #1 finding from the specify conversus gate.

## Spec amendments already applied (specify conversus gate, 5 P0)

The advisory red/blue gate PASSed (0 surviving disputes) but flagged 5 P0 conditions, all applied to the spec: FR-3a (pre-deploy health check) + SC-10, CON-6 two-site rewrite, SC-6 conditional (now simplified by AD-2), FR-1 cross-ref fix + CON-7 domain-list caveat, #Q-5/#Q-6. See `specs/043-.../spec.md` `Last Revised` line + `specs/043-.../conversus/summary/final.md` for the full deliberation.

## Proposal + roadmap-placement context (outside the milestone dir)

- Brief: `.orchestrator/proposals/M043-wiki-cloudflare-access-deploy-target.md`
- Source evidence (the pbj-central incident write-up, incl. the working GitHub Actions workflow + exact API calls): `.orchestrator/proposals/M043-source-brief-pbj-central-2026-06-04.md`
- Slotted into `CLAUDE.md` Forward Roadmap (post-launch fast-follow queue, after M041) + `.orchestrator/proposals/README.md` table.

## Recommended next action

`orchestrator:plan-phase` P00. Author the spike's task breakdown + must-haves (the API probes for #Q-5-sub and #Q-6, the findings-note deliverable, and the fixture-payload capture for P02). Gate P00 execution on operator-provided Cloudflare credentials.
