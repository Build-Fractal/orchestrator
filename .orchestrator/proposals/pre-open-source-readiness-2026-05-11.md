# Pre-open-source readiness audit — 2026-05-11

**Authored**: 2026-05-11, immediately after the v2.3.0 constitution amendment ship (SHAs `859bfd8c` + `cf4e90ba` + `54c5e935`) and the M035 launch-event close (2026-05-09). Branch `main`, working tree clean at audit start, fully pushed to origin (`Build-Fractal/orchestrator`).

**Scope**: surface every gap that would meet a first-time public visitor at the orchestrator repo. Audit-only with safe-fix sweep; operator-decision items (stub triage, inheritance URL repair, README prose, LICENSE) are flagged but not chosen.

**Out of scope**: M033 friendly-tester pass (deadline 2026-05-19, human recruitment); implementing the three `scripts/verify/*.sh` stubs (separate workstream); pushing or amending commits.

---

## Top-line status

**Ready-with-decisions-needed.** Two blockers and three judgment-calls stand between today's state and a clean public flip:

| # | Item | Status | Blocker for public flip? |
|---|---|---|---|
| 1 | M033 friendly-tester pass | Pending (out of scope) | No — separate deadline 2026-05-19 |
| 2 | Three `scripts/verify/*.sh` PENDING stubs | NEEDS-OPERATOR-DECISION | No (constitution doesn't revert) — but the enforcement claim degrades the instant the first `v*` tag publishes if no extension is recorded |
| 3 | Stale-version sweep | FIX-APPLIED (1 safe fix) + PASS (the rest) | No |
| 4 | Inheritance URL reachability | NEEDS-OPERATOR-DECISION | **Yes** — both URLs are private GitHub repos; public visitors hit 404s |
| 5a | README + LICENSE — README | NEEDS-OPERATOR-DECISION (prose rewrites) | Judgment call — README L91 stale claim fix-applied; install-section ordering and stub-disclosure are prose decisions |
| 5b | README + LICENSE — LICENSE | PASS | No — LICENSE present at repo root |

**Verdict**: do not flip the repo public until Item 4 is resolved (the constitution's Tier 1 inheritance chain is otherwise unverifiable from a public visitor's vantage). Item 2 is operator's choice — neither path blocks the flip but the choice influences which constitutional claim degrades and when. Items 3, 5b are already cleared. Item 5a depends on operator taste for the install section and stub disclosure.

---

## Item 2 — Three `scripts/verify/*.sh` PENDING stubs

**Background.** Three verifier stubs (`version-source-of-truth.sh`, `manifest-coverage.sh`, `installer-smoke.sh`) are PENDING per CONFORMANCE.md § "Tier 2 XXII — PENDING/ACTIVE verifier-stub cap" (L95–128). Each is present at its canonical path but emits a TODO line and `exit 0` regardless of state. The cap's promotion deadline is **"first `v*` tag publication"** (CONFORMANCE.md L101) — i.e., the first tag-push that triggers `.github/workflows/release.yml` and produces a publicly downloadable artifact.

If the first `v*` tag publishes without **any** of the three stubs implemented **and** no extension recorded in the cap section, each unsatisfied stub auto-demotes from PENDING to ADVISORY (CONFORMANCE.md L103). The constitution itself does not revert on demotion — only the named enforcement claim for the demoted stub degrades to "advisory-only" (CONFORMANCE.md L124–128).

Going open-source on its own does not trigger this; the trigger is the first `v*` tag publication that lands the M035 packaging artifacts on npm + Homebrew + the curl-pipe-bash channel. In practice, "flip the repo public" and "publish the first `v*` tag" often happen close together, so this is worth resolving now.

### Three resolution paths

**Option A — Implement the three stubs.** Real work; produces deterministic `verdict=PASS|FAIL` lines + paired green/red-path fixtures + CI wiring for each. Promotes all three to ACTIVE before the first `v*` tag publishes. Per the cap's promotion criteria (L107–113), this is the only path that strengthens the enforcement claims. Estimated effort: ~1–2 days end-to-end, dominated by `installer-smoke.sh` red-path fixture authoring against a deliberately-broken bundle manifest.

**Option B — Record an extension in CONFORMANCE.md.** The cap's extension protocol (L103) is literally one dated bullet appended to the cap section, naming a new deadline-milestone-identifier and the operator-authorized rationale. Extensions do not renew automatically — the new deadline fires deterministically as worded. Smallest possible lift; preserves all three enforcement claims through the new deadline. Example shape:

```
- 2026-05-11 operator-authorized extension: deadline moves from "first
  `v*` tag publication" to "first `v*` tag publication AFTER the
  M033 friendly-tester pass closes". Rationale: pre-launch verifier
  implementation deferred so the friendly-tester surface remains
  representative of the as-shipped install paths; the three stubs
  will land before the second `v*` tag.
```

The exact deadline shape is operator's call. The extension protocol does NOT require a deliberation — it's a one-bullet append.

**Option C — Accept the auto-demotion.** Do nothing. When the first `v*` tag publishes without the stubs implemented, all three demote to ADVISORY per the cap's mechanical rule. CONFORMANCE.md's "Failure-consequence rollup" (L124–128) becomes the live state:
- Tier 2 XXII Invariant 2 enforcement claim → ADVISORY (`manifest-coverage.sh`)
- Principle XI installer-channel version SST enforcement claim → ADVISORY (`version-source-of-truth.sh`)
- Constitution Quality Gates § Install gates mechanical-gate property → ADVISORY (`installer-smoke.sh`)
- Constitution body and CONFORMANCE.md inheritance row do **not** revert; only the named enforcement claims degrade.
- Re-promotion requires fresh three-deliberation constitution-amendment ratification (CONFORMANCE.md L105) — much costlier than implementing the stubs cleanly the first time.

### Recommendation

**Option B (record extension).** Smallest blast radius; preserves all three enforcement claims through the new deadline; produces a single dated audit-record bullet that future readers can find without re-deriving the deadline state. The deadline-renewal cost is bounded — extensions don't renew automatically, so a second extension would itself be an operator-recorded decision.

Option A is the durable answer (and the constitution would prefer it) but the effort isn't bounded to a single safe-fix sweep, and the first `v*` tag could publish before stub implementations land. Option C is reversible only through a full constitution-amendment ratification — the most expensive recovery path of the three.

Operator decides. This audit makes no choice.

---

## Item 3 — Stale-version sweep

**Sweep scope.** Grepped for `v2\.2\.[01]`, `Invariant 1`, `Invariant 2`, `Invariant 3`, `three invariants`, and `M035` across `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `AGENTS.md`, `CONFORMANCE.md`, `.orchestrator/memory/constitution.md`, `.orchestrator/milestones/M035/M035-SUMMARY.md`, `.orchestrator/milestone-summary.md`, `docs/`, `references/`.

**Result**: one genuinely stale claim. All other v2.2.x references are HISTORICAL ("at v2.2.1 the opening declaration was further PATCHed…", "ratified alongside the v2.2.0 bump") and remain factually accurate when read as records of when something became true. The constitution Sync Impact Report at v2.3.0 (constitution.md L1–80) is fully current.

| # | File:line | Current text | Proposed fix | Applied? |
|---|---|---|---|---|
| 3.1 | `README.md:91` | `> **Coming with M035 (launch):** one-liner install via npm, Homebrew, or \`curl \| bash\`. Tracking in [\`CHANGELOG.md\`](./CHANGELOG.md).` | Remove the blockquote entirely OR rewrite as "Available since v2.3.0 (M035, 2026-05-09)" with the three install commands. **Mechanical-fix variant taken**: remove the line (the install section's "Today (clone path)" framing is itself stale prose — addressed in Item 5a, not here, since that's a prose rewrite). | Yes — line removed |
| 3.2 | `references/operator-vs-developer-config.md:13` | `Ratified: 2026-05-11 (...this doc...lands alongside the constitution v2.2.0 bump).` | No fix. Historical statement — accurate as written. The doc was ratified alongside the v2.2.0 bump; later v2.2.1/v2.3.0 bumps did not amend the doc's ratification provenance. | No (not stale) |
| 3.3 | `references/dead-infra-linter-conventions.md:95` | `The constitutional boundary is made self-derivable at constitution v2.2.1 in Principle VIII's opening declaration` | No fix. Historical statement — Principle VIII's opening declaration was PATCHed at v2.2.1 (Item 4 of the substantive-followups ledger); v2.3.0 did not amend VIII. The "self-derivable at v2.2.1" claim remains true. | No (not stale) |
| 3.4 | `references/dead-infra-linter-conventions.md:101` | `.orchestrator/memory/constitution.md § VIII (file-system scope boundary, self-derivable at v2.2.1).` | No fix. Same reason as 3.3. | No (not stale) |
| 3.5 | `.orchestrator/memory/constitution.md:42` | `At v2.2.1 the opening declaration was further PATCHed so the scope boundary is constitutionally self-derivable from VIII's plain text` | No fix. Sync Impact Report records the v2.2.0→v2.2.1→v2.3.0 amendment chain; v2.2.1 mention is part of the documented history. | No (not stale) |
| 3.6 | `CHANGELOG.md` | (no `v2\.2\.[01]` references found) | n/a | n/a |
| 3.7 | `AGENTS.md` | 3 lines total: `orchestrator:recent-changes` marker only | Flagged as a judgment call — publishing a 3-line stub looks strange. Not a stale-version issue. Surface to operator under Item 5a. | No (judgment call) |
| 3.8 | `docs/` | (no `v2\.2\.[01]` references found) | n/a | n/a |

**Net effect of safe fixes**: one line removed from `README.md`.

---

## Item 4 — Inheritance reachability

**The two URLs the prompt names and what `gh repo view` reports about them:**

| URL | `gh repo view` visibility | Referenced from | Reachable to public visitor? |
|---|---|---|---|
| `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/CONSTITUTION.md` | **PRIVATE** | `CONFORMANCE.md:7` (Tier 1 source); plus `CONFORMANCE.md:11, 40, 206, 208, 210` cite the same repo for build-fractal namespace governance + conversus suite-admission pathway | **NO** — 404 |
| `https://github.com/Build-Fractal/conversus-oss` | **PRIVATE** | `README.md:28` + `README.md:189` (sister project promo); `CHANGELOG.md:126` + `docs/ingesting-arbitrary-specs.md:184,193` + `references/spec-management.md:148` + `references/github-integration.md:330` reference the path `~/Sites/conversus-oss` (local filesystem, not URL) | **NO** — 404 |

**Implication**. A public visitor to the orchestrator repo cannot:
- Follow CONFORMANCE.md's Tier 1 inheritance to its declared source (`SOURCE B`, the build-fractal constitution). The entire Tier 2 XXII + XII inheritance audit becomes unverifiable from the public-facing artifact tree.
- Click through to the conversus-OSS sister project. The README's "sister project" framing becomes a broken promise.

**Three resolution paths.**

**Option 4A — Host an in-repo snapshot.** Copy the relevant `build-fractal/CONSTITUTION.md` content (pinned to a specific upstream commit SHA) into `references/build-fractal-constitution-snapshot.md` (or similar), update CONFORMANCE.md's cross-references to point at the snapshot, add a one-line provenance note ("snapshot of `clariti-care/payer-index-mono@<sha>:build-fractal/CONSTITUTION.md`, will re-sync when upstream goes public"). Reverses cleanly when the upstream repos go public — replace snapshot with original URL. Estimated effort: 1–2 hours.

**Option 4B — Wait until upstream goes public.** If `clariti-care/payer-index-mono` and `Build-Fractal/conversus-oss` are scheduled for public flips before orchestrator's, defer orchestrator's flip until both upstream repos are public. Zero work in this repo; high coordination cost across the three repos.

**Option 4C — Hybrid: snapshot Tier 1 source, defer conversus-OSS link.** Do Option 4A for the load-bearing `CONFORMANCE.md` reference (the inheritance chain is the constitutional dependency); convert the README's `conversus-oss` link to plain text ("sister project; repo URL coming soon") until that repo flips. Lowest blast radius; ships orchestrator public without dragging two other repos along.

### Recommendation

**Option 4C (hybrid).** The CONFORMANCE.md inheritance chain is the load-bearing dependency — without it, the Tier 2 XXII + XII ratification audit is unverifiable from public artifacts. The conversus-OSS README mention is promotional, not load-bearing; deferring the URL until that repo goes public is a clean degradation.

Operator decides. This audit makes no choice.

**Additional reachability note (raised, not in the prompt)**: `README.md:80` instructs users to `git clone git@github.com:Build-Fractal/orchestrator.git`. That URL's reachability depends on whether `Build-Fractal/orchestrator` itself is public when orchestrator flips. The audit cannot verify that condition from inside this repo. Flag for operator confirmation.

---

## Item 5 — README + LICENSE audit

### 5a — README

The README is fundamentally well-structured for a public-facing repo: a clear value proposition, "When this isn't a fit" honesty, a Pick-your-path routing table, a Five-command cheat sheet, and a Documentation index. **Concrete gaps below; none are blockers, all are judgment calls for the operator.**

**Gap 5a.1 — Install section frames clone as primary post-launch.** Lines 79–91 read:

> **Today (clone path):**
> ```bash
> git clone git@github.com:Build-Fractal/orchestrator.git
> cd orchestrator
> bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
> ```
> ...
> > **Coming with M035 (launch):** one-liner install via npm, Homebrew, or `curl | bash`. Tracking in [`CHANGELOG.md`](./CHANGELOG.md).

But M035 closed 2026-05-09 and `M035-SUMMARY.md:30` confirms `npm install -g @build-fractal/orchestrator`, `brew install orchestrator`, and `curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash` all ship as load-bearing 3-way byte-equivalent channels. The "Today (clone path)" → "Coming" framing is inverted relative to the as-shipped reality.

**Proposed before/after** (operator-decides; not applied):

Before:
```
**Today (clone path):**

\`\`\`bash
git clone git@github.com:Build-Fractal/orchestrator.git
cd orchestrator
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
\`\`\`

> Other runtimes: `install-codex.sh` and `install-cursor.sh` exist with the same flag shape.

**Requirements:** Bash 3.2+ (macOS default), git, jq (optional — JSON parsing fallback exists).

The installer registers `orchestrator:*` skills with your runtime and stages the runtime tree (`scripts/`, `templates/`, `references/`) into your project. Idempotent — re-run any time to update.

> **Coming with M035 (launch):** one-liner install via npm, Homebrew, or `curl | bash`. Tracking in [`CHANGELOG.md`](./CHANGELOG.md).
```

After (illustrative shape):
```
**Install via npm** (recommended):

\`\`\`bash
npm install -g @build-fractal/orchestrator
\`\`\`

**Or via Homebrew:**

\`\`\`bash
brew install build-fractal/orchestrator/orchestrator
\`\`\`

**Or curl-pipe-bash** (for environments without npm or brew):

\`\`\`bash
curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
\`\`\`

**Or from source** (for dogfooding velocity — symlink mode keeps consumers in sync with `git pull`):

\`\`\`bash
git clone git@github.com:Build-Fractal/orchestrator.git
cd orchestrator
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project --mode=symlink
\`\`\`

> Other runtimes: `install-codex.sh` and `install-cursor.sh` exist with the same flag shape.

**Requirements:** Bash 3.2+ (macOS default), git, jq (optional — JSON parsing fallback exists). Integrity verification via sigstore keyless + SHA-256 fallback — see [`references/installation.md`](references/installation.md) § Verifying integrity.
```

**Gap 5a.2 — No disclosure of three PENDING verifier stubs.** README L36 advertises *"Verification is mechanical, not vibes — every task and phase passes a 4-tier ladder"* and L161 reinforces *"Mechanical verification — A 4-tier ladder runs after every task and phase: file checks → configured commands → behavioral review → optional human gates."* Both claims are true for **per-task** and **per-phase** verification surfaces. They are silent on the **release-time** verification surface, where three named verifier stubs (`version-source-of-truth.sh`, `manifest-coverage.sh`, `installer-smoke.sh`) are currently PENDING and emit `exit 0` regardless of state. A public visitor reading the README does not know this; CONFORMANCE.md L116–122 documents it but a visitor must drill down to find it. Per the prompt, this should be set on a first-time reader.

**Proposed before/after** (operator-decides; not applied) — append a single line to the Status section (L248–250):

Before:
```
## Status

In production use against this repo's own development. 30+ closed milestones spanning spec management, GitHub integration, knowledge layer, autonomous hardening, adaptive model routing, reference-corpus ingest, wiki distribution, and onboarding experience. Full milestone history in [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md). Engineering changelog in [`CHANGELOG.md`](./CHANGELOG.md).
```

After (illustrative — last sentence is the addition):
```
## Status

In production use against this repo's own development. 30+ closed milestones spanning spec management, GitHub integration, knowledge layer, autonomous hardening, adaptive model routing, reference-corpus ingest, wiki distribution, and onboarding experience. Full milestone history in [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md). Engineering changelog in [`CHANGELOG.md`](./CHANGELOG.md).

**Known maturity gaps** (transparent for public consumers): three release-time verifier scripts under `scripts/verify/` are currently PENDING — they exist at their canonical paths but emit `exit 0` regardless of state. The per-task and per-phase 4-tier verification ladder is fully wired. See [`CONFORMANCE.md`](./CONFORMANCE.md) § "Tier 2 XXII — PENDING/ACTIVE verifier-stub cap" for the maturity tier contract.
```

The exact wording is operator's. This audit flags the gap with a proposed shape.

**Gap 5a.3 — AGENTS.md is a 3-line stub.** The file at repo root carries only an `orchestrator:recent-changes` block. It will look strange to a Codex/Cursor visitor who expects AGENTS.md to mirror CLAUDE.md's content shape. Either populate it (mirror the relevant CLAUDE.md sections) or omit it from the public tree via `.gitignore` until populated. Out of scope for safe-fix sweep; flag for operator.

### 5b — LICENSE

**LICENSE present at repo root** (1069 bytes). Content: standard MIT License, Copyright "Clariti Care" 2026.

`CONFORMANCE.md:42` declares orchestrator a *"single-edition product per the Status & Provenance section above"*, consistent with the MIT framing. The license badge (`README.md:3`) and the L252 `## License — MIT` line both align.

**No issue.** Item 5b clears.

**One micro-flag for operator awareness** (not a fix): Copyright holder is "Clariti Care" — this is the corporate identity. If a Build-Fractal entity is the eventual upstream maintainer for the open-source surface, operator may want to confirm the copyright string before public flip. Not a blocker.

---

## Out of scope (explicitly enumerated for the operator's record)

- **M033 friendly-tester pass** against the four init branches. Deadline 2026-05-19 (pushed from 2026-05-12 per operator authorization on 2026-05-11). Protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`. Requires human recruitment, not autonomous execution.
- **Implementation of any `scripts/verify/*.sh` stub** (Option A under Item 2). Estimated 1–2 days; out of scope for this audit's safe-fix sweep.
- **README prose rewrites** (gaps 5a.1, 5a.2, 5a.3). All flagged with before/after shape; operator decides.
- **LICENSE copyright-string revision** (micro-flag under 5b). Operator decides.
- **Inheritance-URL repair** (Item 4). All three options costed; operator decides.

---

## Suggested commit shape

**Commit 1 — Pre-open-source readiness audit report.** This file. Single new file at `.orchestrator/proposals/pre-open-source-readiness-2026-05-11.md`. Standalone audit-record commit.

**Commit 2 — Safe-fix sweep.** Single line removal: `README.md:91` blockquote ("Coming with M035 (launch): one-liner install via npm, Homebrew, or `curl | bash`. Tracking in [CHANGELOG.md].") The line is factually stale; removing it without rewriting the surrounding install section is a clean mechanical fix that doesn't pre-judge the operator's prose decision for gap 5a.1.

**Commit 3 (optional, operator-decided) — LICENSE inline drop.** Not applied. The LICENSE file already exists; no action needed unless operator wants to revise the copyright string before flip.

All commits authored via `git commit -F <message-file>` per AP-008 shape-guard (inline-HEREDOC rejected).

---

## Audit-record provenance

- Constitution snapshot at audit time: v2.3.0, last amended 2026-05-11 (SHAs `859bfd8c` + `cf4e90ba` + `54c5e935`).
- CONFORMANCE.md snapshot at audit time: § "Tier 2 XXII — PENDING/ACTIVE verifier-stub cap" comprehensive (L95–128); all three stubs at status=PENDING.
- M035 closure snapshot: 2026-05-09; `validate-milestone.sh M035` reports 185/185 PASS per CLAUDE.md "Project Status" rollup.
- `gh repo view` results that establish Item 4: `clariti-care/payer-index-mono` visibility=PRIVATE; `Build-Fractal/conversus-oss` visibility=PRIVATE (queried 2026-05-11 during this audit).
- Audit author: Claude (Opus 4.7), invoked from `/Users/brettkellgren/Sites/orchestrator` on 2026-05-11.
