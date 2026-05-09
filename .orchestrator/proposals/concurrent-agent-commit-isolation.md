# Proposal: Concurrent-Agent Commit Isolation

**Captured**: 2026-05-08 from a downstream report (two CC sessions sharing one orchestrator-managed checkout)
**Shape**: Layered fix — three layers in increasing cost. Layer 1 is a paper-cut-class hotfix (~1 day); Layer 3 is its own milestone.
**Predecessors**: M021 (PreToolUse Bash shape-guard — Layer 1 must compose with `~/.claude/orchestrator-hooks/`), M025/P01 + M028/P02 (hook payload staging contract — `before-commit.sh` is a runtime-stable on-disk file the install adapter copies), M008 (`packaging/bundle/hooks/before-commit.json` enrolment), Constitution Principle V (Fresh Context Per Unit — extends to per-unit *git* isolation).
**Source**: 2026-05-08 downstream incident; verbatim repro preserved in § "Reproduction".
**Status**: **RFC capture only.** Post-launch demand-driven. Not a launch blocker. Layer 1 may ship sooner if a second incident arrives before M035 closes.

## TL;DR

Two Claude Code sessions running in the same checkout of an orchestrator-managed repo can collide on `git`'s shared index. The downstream report shows agent-A's `git checkout` yanking agent-B's staged-but-uncommitted work, after which agent-A's `git commit` bundles agent-B's 8 staged files into a commit message that describes only agent-A's work. Future code archaeology returns the wrong story.

This is git working as designed (the index is shared across all working-tree operations on a single checkout). The bug is that **the orchestrator does nothing to coordinate agents that are committing.** `.orchestrator/orchestrator.lock` already coordinates the autonomous loop; it is never consulted by `git commit`.

This proposal offers three layers in increasing cost:

1. **Cheap — orchestrator-aware pre-commit hook.** Refuses commits when a different session holds the lock. ~1 day.
2. **Medium — lock-aware `git add` wrapper.** Catches the staging race inside `auto`/`dispatch` flows. ~2–3 days.
3. **Right — per-session worktree.** Each spawned agent operates in its own `git worktree`. Eliminates the index entirely as a contention surface. Milestone-class.

Layers compose: 1 + 2 raise the floor for the common shared-checkout case; 3 raises the ceiling for true parallel multi-agent dispatch.

## Why post-launch (not pre-launch)

M035 ships **CC-only**, with an implicit **single-agent-per-checkout** assumption. The race only fires when a second agent shares the checkout — a deployment shape the launch queue does not cover. As multi-agent dispatch matures (M010 Managed Agents, M009 multi-runtime parity, future "two windows on one repo" workflows), this becomes more pressing. Pre-launch insertion would dilute M035's blast-radius focus without sharpening the first-impression for the deployment shape we *are* shipping.

Demand signal: one downstream report (this one). When a second consumer hits it, or when M010 / parallel dispatch enters the queue, Layer 1 lands first as a paper-cut and Layers 2/3 grow into a brief.

## Reproduction (verbatim from downstream report)

Two Claude Code sessions ran in the same checkout of an orchestrator-managed repo. Reconstructed from `git reflog`:

```
HEAD@{4}: checkout: moving from main to 0a25e17b   ← agent-A detaches HEAD
   ... agent-A starts working on M035 P05 T06, leaves files unstaged ...
HEAD@{3}: checkout: moving from 0a25e17b to feat/M036-business-doc-category
   ← agent-B (the reporter) creates a new branch from the detached HEAD
   ... agent-B makes 8 file edits, runs `git add <8 paths>` ...
HEAD@{2}: checkout: moving from feat/M036-business-doc-category to 0a25e17b
   ← agent-A resumes, runs `git checkout 0a25e17b` (yanking agent-B's branch)
HEAD@{1}: commit: M035 P05 T06: phase-suite aggregator
   ← agent-A runs `git commit`. The index still has agent-B's 8 staged files.
     They get bundled into agent-A's commit with agent-A's commit message.
HEAD@{0}: checkout: moving from f231d23b to main
```

**Net result**: agent-B's M036/D006 work landed on `main` under a commit message describing only agent-A's M035/P05/T06 work. No mention of D006, M036, or business-doc in the commit. Future code archaeology returns the wrong story.

The race is not exotic. Two shapes are particularly common:

- **Shared checkout, one human, two terminal windows.** Operator runs `orchestrator:auto` in window A; opens window B to "just check something" and ends up making edits.
- **Shared checkout, one runtime, two CC sessions.** Background `auto` run + foreground human-driven session — the exact shape the M016 autonomous loop encourages.

## Why a fix is on the table at all

Two existing scaffolds already imply per-session isolation; the gap is that neither extends to git:

1. **`.orchestrator/orchestrator.lock`** (`references/file-formats.md` § "Lock File", `scripts/lifecycle/auto-loop.sh:165`) — JSON file with `pid`, `runtime`, `unitType`, `unitId`, `featureBranch`. Created at session start, deleted at session end. Already consumed by `commands/auto.md`, `commands/dispatch.md`, `commands/resume.md`, `scripts/lifecycle/auto-loop.sh`, `scripts/lifecycle/recovery-briefing.sh`, `scripts/diagnostics/render-status-json.sh`, `scripts/integrations/github-sync.sh`. **Not consumed by `git commit`.**
2. **Agent tool `isolation: "worktree"` mode** — orchestrator already uses this in some dispatch contexts. Layer 3 generalizes it to all `auto`/`dispatch` flows.
3. **Constitution Principle V — Fresh Context Per Unit** (`.orchestrator/memory/constitution.md:109`) — already mandates per-unit context isolation: *"Each unit of work (task, phase) MUST execute in a fresh context that receives ONLY what it needs."* Per-unit *git* isolation is a natural extension: a unit's working tree is part of "what it needs."

The lock-file scaffold is **load-bearing for Layer 1**: the pre-commit hook gets its "another session is active" signal from `.orchestrator/orchestrator.lock`. The Agent-tool worktree primitive is **load-bearing for Layer 3**.

## Existing hook architecture (composability constraints)

Any commit-time hook must fit the existing pattern, established by M008 / M025/P01 / M028/P02:

- **Bundle source**: `packaging/bundle/hooks/<name>.json` declares the hook event + the runtime-stable `bash` invocation.
- **Runtime-stable script**: `scripts/lifecycle/<name>.sh` is the source-of-truth file. The install adapter (`packaging/install/install-claude-code.sh`) stages a copy at `${HOME}/.claude/orchestrator-hooks/<name>.sh` so the post-install hooks dir does not 404 when the runtime spawns the command.
- **Existing stub**: `scripts/lifecycle/before-commit.sh` is a permissive no-op today (lines 12–18 explicitly note: *"Until a real verification-ladder pre-commit gate ships, this hook is a permissive no-op."*) — Layer 1 graduates this stub from no-op to lock-aware.
- **M021 PreToolUse Bash shape-guard** (`scripts/hooks/pre-bash-shape-guard.sh`): rejects compound shapes (AP-008 heredoc-with-expansion, AP-009 compound-chain-gt2, etc.) on Bash invocations through the dispatcher. Layer 1's hook script is invoked by *git*, not by the dispatcher, so it does not pass through the shape-guard — but its *internal* shape must still be AP-009 clean for consistency with `before-commit.sh`'s existing AD-19 single-script-file flat shape.

This means Layer 1 has zero net-new architecture: it slots into the empty `before-commit.sh` stub the install adapter already stages.

---

## Layer 1 — Orchestrator-aware pre-commit hook (cheap)

**Shape**: Graduate `scripts/lifecycle/before-commit.sh` from permissive no-op to lock-aware gate.

**What it catches**:

- **Simultaneous commit race**: agent-A is mid-flow with the lock held; agent-B (no lock, same checkout) tries `git commit`. Hook reads `.orchestrator/orchestrator.lock`, finds `pid` ≠ current process group's session, refuses with a clear stderr message naming the holding session, the unit it's working on, and how to coordinate.

**What it doesn't catch**:

- The exact reproduction above. **Critically**: in the report, agent-A *was* the lock holder and *was* the committer. The hook would have let agent-A commit. The bug is that agent-A's commit picked up agent-B's staged files — Layer 1 only stops agent-B from *also* committing.
- Operators running `git commit` in a third terminal outside any orchestrator session.
- Sessions that didn't acquire a lock (any non-`auto`/`dispatch` orchestrator entry point, or hand-rolled scripts).
- Stale-lock false-positives — already handled by `references/file-formats.md` § "Staleness Check" + `scripts/lifecycle/auto-loop.sh` lock-manager; Layer 1 reuses the same staleness logic.

**Implementation cost**: ~1 day, ~2–3 files touched.

| File | Change |
|---|---|
| `scripts/lifecycle/before-commit.sh` | Replace permissive `exit 0` with: read `.orchestrator/orchestrator.lock`, parse `pid`, compare against current `$$` (and parents). On mismatch + non-stale: emit clear stderr message, `exit 1`. On match / stale / absent: `exit 0`. |
| `scripts/util/lock-status.sh` *(new)* | Extract the existing inline lock-read+staleness-check logic from `scripts/lifecycle/auto-loop.sh` into a reusable helper so Layer 1 + auto-loop share one parser. Bash 3.2, AP-009 clean, AD-19 single-file. |
| `tests/m??-acceptance/before-commit-lock-collision.sh` *(new)* | Acceptance test: spin up a fixture lock file with `pid` ≠ self, run `before-commit.sh`, assert exit 1 + stderr contains the holding session id. Mirror shape: `tests/m032-acceptance/run-acceptance-battery.sh`. |

**Failure mode if bypassed**: operator runs `git commit --no-verify`, or runs `git commit` outside a checkout where `core.hooksPath` points at the orchestrator-staged `before-commit.sh`. In both cases the layer is silently absent and the race fires unchanged. **The pre-commit hook is a soft gate, not a guarantee** — same posture as the existing M021 shape-guard (operator can always escape).

**Compatibility with existing hook architecture**:

- ✅ M008 enrolment: `packaging/bundle/hooks/before-commit.json` already references this script.
- ✅ M025/P01 + M028/P02 staging: install adapter already copies the script to `${HOME}/.claude/orchestrator-hooks/before-commit.sh`.
- ✅ M021 Bash shape-guard: hook is invoked by git, not by the dispatcher; internal shape stays AD-19 / AP-009 clean.
- ⚠️ Composition with the future M034 verification-ladder pre-commit gate: `before-commit.sh:12–14` reserves the script for that purpose. Layer 1 must keep the design open — recommend a small dispatch table at the top of `before-commit.sh` (`run lock-check; run-if-present verification-gate`) so M034 slots in alongside, not on top of, the lock check.

**Stderr message shape** (proposed):

```
orchestrator: pre-commit refused — another session holds the orchestrator lock.

  Holding session:  pid=12345 unit=M035/P05/T06 started=2026-05-08T14:22:01Z
  This session:     pid=67890

The git index is shared across all working-tree operations on this
checkout. Committing now risks bundling the other session's staged
files into your commit (see .orchestrator/proposals/concurrent-agent-
commit-isolation.md).

To proceed:
  1. Wait for the other session to complete (most common).
  2. If the other session is wedged: bash scripts/state/break-lock.sh
  3. To bypass this hook (DANGEROUS): git commit --no-verify
```

---

## Layer 2 — Lock-aware `git add` wrapper (medium)

**Shape**: Wrap orchestrator-managed `git add` invocations in a helper that takes the lock first, releases on completion. Called from inside `orchestrator:auto` and `orchestrator:dispatch` flows.

**What it catches**:

- **Staging race inside orchestrator-managed flows**: prevents agent-B's `git add` from running while agent-A holds the lock. Combined with Layer 1, this means the only way a foreign-session race can corrupt the index is if the foreign session bypasses both layers (e.g. operator running `git add` directly in a third terminal, or a non-orchestrator script).
- **Detect-and-warn on dirty index at lock-acquire time**: when the orchestrator acquires its lock, it can scan `git status --porcelain` and refuse to start (or prompt) if the index already has unstaged or staged files belonging to a different unit. This is the cheapest mitigation for the exact reproduction above (agent-A would have noticed agent-B's 8 staged files at lock-acquire time, before running `git checkout`).

**What it doesn't catch**:

- Users running `git add` directly outside orchestrator (foreign-session writes to the index). Layer 2 is a discipline layer for *orchestrator-managed* git ops, not a global git interceptor.
- Two orchestrator sessions racing on lock acquisition itself — already handled by the existing lock-manager (`scripts/lifecycle/auto-loop.sh:68`) atomic-create semantics.

**Implementation cost**: ~2–3 days, ~5–8 files touched.

| File | Change |
|---|---|
| `scripts/util/git-staged-add.sh` *(new)* | Wrapper: `lock-acquire (or-fail) → git add "$@" → lock-release`. Idempotent if lock already held by self. AP-009 clean. |
| `scripts/util/git-status-check.sh` *(new)* | At lock-acquire time, run `git status --porcelain`, classify the dirty set (matching-unit / mismatched-unit / unattributable), emit JSONL event, refuse-or-warn based on config. |
| `scripts/lifecycle/auto-loop.sh` | Call `git-status-check.sh` at lock-acquire (currently no-op). |
| `commands/auto.md` + `commands/dispatch.md` | Document that orchestrator-managed `git add` flows route through `git-staged-add.sh`. Operator-facing `git add` stays untouched. |
| `templates/orchestrator-config-default.yml` | Add `concurrent_agent_isolation: { dirty_index_policy: warn|refuse|allow }` config knob with default `warn` (preserves backward compat). |
| `scripts/hooks/pre-bash-shape-guard.sh` *(optional)* | Detect `git add ` in dispatched Bash payloads and route through the wrapper. **Defer** — too aggressive for first cut; revisit if direct-`git-add` adoption stays high. |
| `tests/m??-acceptance/git-staged-add-lock-collision.sh` *(new)* | Two-fixture race test: session-A holds lock, session-B calls `git-staged-add.sh`, assert refusal + stderr message. |

**Failure mode if bypassed**: operator runs `git add` directly (not through the wrapper). Wrapper is an in-orchestrator discipline layer, not a gate on raw `git`. Layer 1 still catches the *commit* in this case if agent-B then tries to commit while agent-A's lock is held — but it does *not* catch agent-A's commit picking up agent-B's already-staged-via-raw-`git add` files. **Layer 1 + Layer 2 together raise the floor; they do not eliminate the index-as-shared-resource problem.**

**Compatibility with existing hook architecture**:

- ✅ Reuses Layer 1's `scripts/util/lock-status.sh`.
- ✅ Reuses existing lock-manager atomic-create semantics from M021/M028.
- ⚠️ Touching `commands/auto.md` + `commands/dispatch.md` is the load-bearing shape — both are downstream of M016/M021/M028 hardening and any change goes through the M021 PreToolUse shape-guard for any Bash payloads they emit. Recommend `git-staged-add.sh` invocation be a single bare command (no compound chains) to stay AP-009 clean.

---

## Layer 3 — Per-session worktree (right)

**Shape**: Each spawned orchestrator agent operates in its own `git worktree`. Agents run truly in parallel without index contention; `git checkout` in one does not affect the other. Builds on the existing Agent-tool `isolation: "worktree"` primitive — generalizes it from "some dispatch contexts" to "all `auto`/`dispatch` flows that touch the working tree."

**What it catches**:

- **The exact reproduction above**: agent-A's checkout *cannot* yank agent-B's branch because agent-B's branch lives in a different worktree with a different `HEAD`. Agent-A's commit *cannot* pick up agent-B's staged files because each worktree has its own index.
- **All foreign-session commit/staging races**, including operator-driven ones in additional terminal windows — provided the operator launches their session into a worktree (which the orchestrator can do automatically at session start).
- **Parallel multi-agent dispatch** beyond two-agent races. The only path that scales to N concurrent agents.

**What it doesn't catch**:

- Worktree teardown races (orphan worktrees from crashed sessions). Mitigated by the existing crash-recovery flow (`commands/resume.md`) growing a worktree-cleanup branch.
- Disk usage: N worktrees = N working trees. Trivial for code, can be material for large generated artifacts. Mitigate via shared `.orchestrator/` parent (state stays canonical, working tree stays per-session).
- Shared `.orchestrator/` state contention (lock file, knowledge index, JSONL emitters). These are *not* index-races and stay coordinated by the existing lock-manager — Layer 3 isolates the *working tree*, not orchestrator state.

**Implementation cost**: **milestone-class**. Estimated 4–6 phases, ~30–50 files touched.

Phases (sketch — full brief authored when arc enters queue):

| Phase | Scope |
|---|---|
| P01 | Worktree-aware session bootstrap: `scripts/state/session-start.sh` creates `.orchestrator/worktrees/<session-id>/` (or honors `WORKTREE_ROOT` env). Lock file gains a `worktree_path` field. |
| P02 | Dispatch plumbing: `commands/dispatch.md` payload constructor injects `worktree_path` into agent context; agent tool spawns with cwd inside the worktree. |
| P03 | `auto`-loop integration: `scripts/lifecycle/auto-loop.sh` per-iteration cwd is the worktree, not the canonical checkout. Verify-stage assembles results back to canonical checkout via merge / rebase / cherry-pick policy. |
| P04 | Cleanup + crash recovery: `commands/resume.md` detects orphan worktrees, `scripts/state/break-lock.sh` cleans them, `git worktree prune` integration. |
| P05 | Operator-facing entry: `orchestrator:start --worktree` opt-in flag; `commands/init.md` guidance for shared-checkout teams. |
| P06 | Compatibility audit: M009 multi-runtime parity check (Codex CLI / Cursor worktree behavior), M021 Bash shape-guard interaction, performance regression suite. |

**Failure mode if bypassed**: operator declines the worktree flag and runs everything in the canonical checkout. Layer 3 reduces to Layer 1 + Layer 2 in that path. **Worktree adoption is opt-in by design** — forcing every solo-developer single-checkout user into a worktree is unjustified ceremony.

**Compatibility with existing hook architecture**:

- ✅ Builds on Agent-tool `isolation: "worktree"` (already in use).
- ✅ Composes with Constitution Principle V — extends "fresh context per unit" to "fresh working tree per unit."
- ⚠️ M021 shape-guard: per-worktree dispatched payloads must still pass shape-guard checks. No new shapes introduced, but cwd-aware payload assembly needs a regression sweep.
- ⚠️ M032 wiki-init / M037 wiki-build: wiki tooling assumes canonical-checkout paths. Layer 3 must treat wiki ops as canonical-checkout ops, not worktree ops, or grow the wiki tooling to handle worktree-relative paths.
- ⚠️ M013 GitHub integration: branch reconciliation logic reads HEAD-of-checkout; per-worktree HEADs need a "primary worktree owns GitHub state" convention.

**This is its own milestone.** Recommend slot **after M010** in the post-launch fast-follow queue: M010 brings Managed Agents (a hosted dispatch backend that already isolates by container, not worktree); the right time to invest in local-runtime worktree isolation is when local parallel dispatch becomes the bottleneck.

---

## Sequencing recommendation

| When | What |
|---|---|
| **Now (RFC capture)** | This document. No code. |
| **First duplicate report, or M035 closure window** | **Layer 1 ships as a paper-cut hotfix.** ~1 day of work; graduates the existing `before-commit.sh` stub; zero net-new architecture; lands on the post-launch fast-follow queue under the existing hook-architecture conventions. |
| **Second duplicate report, or first observed Layer-1 false-positive (lock-stale or lock-bypass)** | **Layer 2 ships** as a small follow-up milestone or absorbed into the next observability/hardening milestone (M028's successor). |
| **M010 + first parallel-dispatch friction signal** | **Layer 3 enters the queue as its own milestone.** Brief authored at queue-entry time, building on this proposal's § "Layer 3" sketch. |

## Strict scope (when arc enters queue)

This is the **commit-isolation layer for orchestrator-managed shared-checkout deployments**. It is **not**:

- A general-purpose git-hook framework (M034 owns the verification-ladder gate; this layer composes alongside).
- A multi-runtime parity scope (M009 owns runtime parity; Layer 3 may surface parity gaps but does not own resolving them).
- A replacement for the existing lock-manager (`scripts/lifecycle/auto-loop.sh:68` + `references/file-formats.md` § "Lock File") — *consumes* it, doesn't replace it.
- A foreign-process gate (operator running `git commit --no-verify` is always permitted; we are raising the floor, not building a fortress).

## Open questions (RFC-phase)

1. **Lock-file `pid` semantics under CC sub-agent dispatch**: when a parent CC session dispatches a sub-agent, do they share `pid`? If yes, Layer 1's "current process's session-id" check needs to compare a session-id (some other field), not `pid`. Investigation: re-read `references/file-formats.md` § "Lock File" + `scripts/lifecycle/auto-loop.sh` lock-write path and confirm the discriminator. If `pid` is insufficient, add a `session_id` field at lock-create time.
2. **`core.hooksPath` install policy**: does `orchestrator:init` set `core.hooksPath` to point at `${HOME}/.claude/orchestrator-hooks/`, or does it write into `.git/hooks/<repo>/`? Layer 1 needs the install adapter to land the hook on a path git actually reads. Confirm at `packaging/install/install-claude-code.sh`.
3. **Bypass discoverability**: should Layer 1 warn (then proceed) on first occurrence and refuse on second, to onboard operators gradually? Or refuse-by-default with `--no-verify` as the documented escape hatch? Recommend refuse-by-default — the failure mode (corrupted commit history) is loud and silent-corruption-prone, so noisy upfront beats quiet downstream.
4. **Layer 2 dirty-index policy default** — `warn` vs `refuse` vs `allow`. Recommend `warn` for v1 (preserves backward compat); revisit after first incident report tells us whether warn-fatigue is real.

## References

- Reproduction: § "Reproduction" above (verbatim from 2026-05-08 downstream report).
- Existing lock contract: `references/file-formats.md` § "Lock File" (line 433).
- Existing lock consumers: `commands/auto.md`, `commands/dispatch.md`, `commands/resume.md`, `scripts/lifecycle/auto-loop.sh:165`, `scripts/lifecycle/recovery-briefing.sh`, `scripts/diagnostics/render-status-json.sh`, `scripts/integrations/github-sync.sh`.
- Existing pre-commit stub: `scripts/lifecycle/before-commit.sh` (permissive no-op, M008-enrolled).
- Bundle hook enrolment: `packaging/bundle/hooks/before-commit.json`.
- Hook payload staging: `scripts/verify/m028/p02-hooks-payload-staged.sh`, `scripts/util/settings-merge.sh:48,430`.
- M021 shape-guard: `scripts/hooks/pre-bash-shape-guard.sh` + `references/ANTIPATTERNS.md` AP-008/AP-009.
- Constitution Principle V: `.orchestrator/memory/constitution.md:109`.
- Future verification-ladder gate: M034 brief at `.orchestrator/proposals/M034-interactive-review-gates.md` (Layer 1 must compose with M034's eventual `before-commit.sh` co-tenant).
- Proposal-shape precedents: `.orchestrator/proposals/M034-interactive-review-gates.md`, `.orchestrator/proposals/M038-living-documents.md`.
