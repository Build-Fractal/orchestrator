# Proposal: Delegation Policy — Per-Tool Background-Safety Table

**Captured**: 2026-05-04 from the GSD-2 adoption scan (`gsd-2-adoption-scan-2026-05-04.md` item 14).
**Shape**: Single PR. No milestone needed.
**Bundling recommendation**: Bundle into the same PR window as `constitution-amendment-inclusion-criteria.md`. Both are constitution-adjacent governance work that operates on doctrine, not on user-facing surfaces. Shipping together keeps the standalone-amendment cycle small.
**Source**: GSD v2.79 commit `92509758` (`feat(delegation): codify per-tool background-safety policy`). Discovered during the 2026-05-04 GSD-2 adoption scan.

## Goal

Make the orchestrator's "what's safe to dispatch as a fresh-context subagent vs. what must run inline" contract **explicit, declared, and test-pinned** instead of implicit in script structure.

## Motivation

Constitution Principle V (Fresh Context Per Unit) says each unit-of-work runs in a fresh subagent context. The orchestrator already routes work through `scripts/dispatch/dispatch-interface.sh` and several adapters. But *which* commands and scripts are safe to dispatch — and under what constraints — is implicit knowledge:

- It lives in the script structure (some commands are `dispatch`-routed, others run inline)
- It lives in `commands/dispatch.md` prose (descriptive, not enforced)
- It lives in operator habit ("we never dispatch X because Y")

GSD v2.79 codified this as a typed table (`delegation-policy.ts` — GOOD / RISKY / NO verdicts with explicit constraint lists). The lesson translates directly: a declared, test-pinned table makes the safety contract auditable. Any future change requires explicit re-evaluation rather than slipping in via a one-line script edit.

## Why a single PR (not a milestone)

Doctrine work + a small data file + an enforcement hook in `dispatch-interface.sh`. Bundling with `constitution-amendment-inclusion-criteria` keeps the governance-PR pattern crisp and avoids two separate review cycles for what is one cohesive amendment to how the orchestrator declares its safety properties.

## Proposed changes

### Change 1 — Add `references/DELEGATION-POLICY.md`

A declarative document listing every dispatchable orchestrator command/script with one of three verdicts:

- **GOOD** — safe to run as a fresh-context subagent without operator gates
- **RISKY** — safe only with named constraints (e.g., "read-only mode", "no GitHub mutations", "explicit `--dry-run`")
- **NO** — must run in the orchestrator's main context; subagent dispatch forbidden

Each entry carries:
- Command/script name (canonical + aliases)
- Verdict (GOOD / RISKY / NO)
- For RISKY: explicit constraint list (free-form prose, but verifiable)
- Rationale (one sentence; why this verdict)

The default for unknown entries is **NO** (default-deny). A new dispatchable command without an explicit row in the table is forbidden from background dispatch.

### Change 2 — Add `scripts/dispatch/policy/delegation-policy.yml`

The data file consumed by `dispatch-interface.sh` at dispatch time. YAML or JSONL — same content as the markdown table but machine-readable. Wins:

- Two readers (markdown for humans, YAML for machines) cannot drift if the markdown is generated from the YAML, OR if a CI test asserts they agree
- `dispatch-interface.sh` reads the YAML and refuses to dispatch any command absent or marked NO
- A new tool `scripts/dispatch/policy/lint-delegation-policy.sh` asserts every dispatchable command-and-script has an entry

### Change 3 — Add tests pinning the GOOD set

A test under `tests/regression/delegation-policy-pins.sh` that:
- Lists every command with verdict GOOD
- Asserts no commands have *added* themselves to GOOD without an accompanying test update
- Catches the failure mode where someone flips a verdict from RISKY to GOOD without a re-evaluation

GSD's pattern: any future verdict change requires explicit edit to the pin-test, forcing the re-evaluation moment.

### Change 4 — `commands/dispatch.md` references the table

Single sentence near the top: "Background-safety verdicts for every dispatchable surface are declared in `references/DELEGATION-POLICY.md` and enforced by `scripts/dispatch/policy/delegation-policy.yml`. Default is NO; commands must opt in."

## Initial table (draft — refined during PR)

Initial verdict assignment is the load-bearing work of the PR. Strawman to argue against:

| Command/script | Verdict | Constraints / rationale |
|---|---|---|
| `orchestrator:dispatch` | GOOD | The dispatch primitive itself, fresh context by design |
| `orchestrator:plan-phase` | GOOD | Read-heavy planner; outputs a single artifact |
| `orchestrator:specify` | GOOD | Read + write of one spec file |
| `orchestrator:roadmap` | GOOD | Read + write of one roadmap file |
| `orchestrator:verify` | GOOD | Read-only inspection + report |
| `orchestrator:doctor` (`--fix=false`) | GOOD | Read-only diagnostic |
| `orchestrator:doctor` (`--fix=true`) | RISKY | Mutates state; require explicit `--scope` flag |
| `orchestrator:auto` | NO | Owns the milestone-level lock; NEVER nested |
| `orchestrator:resume` | NO | Owns lock recovery; NEVER nested |
| `orchestrator:start` ([M033](../milestones/M033/index.md)) | NO | Owns onboarding flow; cannot be subagent-invoked |
| `orchestrator:init` | NO | Bootstrap-only; idempotency contract precludes nesting |
| `orchestrator:consolidate` | RISKY | Archives milestone artifacts; require closed-milestone precondition |
| `orchestrator:github-init` | NO | External API mutations |
| `orchestrator:github-sync` | RISKY | Read-mostly; allow with `--dry-run` only |
| `orchestrator:ingest` | GOOD | Read + append to knowledge index |
| `orchestrator:ingest-codebase` (M033 P03) | GOOD | Deterministic structural scan |
| `orchestrator:ingest-reference` (M036a) | GOOD | Idempotent ingest |
| `orchestrator:extract` (M036a) | RISKY | Tier 2 invokes LLM; require explicit budget cap |
| `orchestrator:do` ([M031](../milestones/M031/index.md)) | NO | Universal entry — invokes other commands; nesting risk |

Per-script entries (`scripts/dispatch/`, `scripts/state/`, etc.) added during PR review.

## Effort estimate

1 day. Drafting the table is the load-bearing work; the YAML + enforcement script + lint test + pin test are mechanical.

## Sequencing

PR window is the same as `constitution-amendment-inclusion-criteria.md`. Both standalone, no milestone dependencies. Either ships first; the other rebases trivially.

## Cross-references

- Constitution Principle V (Fresh Context Per Unit) — this proposal makes the principle's enforcement surface explicit
- M033 dispatch surfaces — every M033 command gets a verdict during PR review
- M036a dispatch surfaces (`orchestrator:extract`, `orchestrator:ingest-reference`) — verdicts already drafted above
- GSD source: `delegation-policy.ts` in `gsd-build/gsd-2` HEAD (commit `92509758`, v2.79)

## Open questions

1. **YAML or JSONL for the data file?** YAML is more human-readable for a small static table; JSONL composes better with the existing [M019](../milestones/M019/index.md) emitter pattern. Recommendation: YAML, since this is configuration not event stream.
2. **Should constraint expressions be DSL or prose?** Prose is faster to ship and good enough for a default-deny gate. DSL deferred until a second amendment cycle.
3. **Does this amendment introduce a new constitution principle?** Probably not — it's an enforcement mechanism for existing Principle V. But a brief note in the constitution's *Governance* section pointing at the policy table would close the loop. Recommendation: add a one-line pointer in *Governance*, do NOT add a new principle.
