---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M029"
name: "orchestrator:context skill + SC-4 fixture/script + verifier (FR-4)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has completed: both design contracts (`references/status-headline-shape.md`, `references/status-json-schema.md`) exist on disk. T05 cross-references both in `commands/context.md`'s body.
- T02 has completed: `scripts/state/detect-invocation-context.sh` exists. T05's `commands/context.md` body invokes the resolver to display the runtime profile.
- `commands/` exists with sibling skills (`zoom-out.md` is the closest analog for a read-only debug skill — see `commands/zoom-out.md` for the pattern). Verify with `[ -f commands/zoom-out.md ]`.
- No file currently lives at `commands/context.md`; verify `[ ! -f commands/context.md ]`. Path-collision check passed at plan-authoring time.
- `scripts/state/resolve-root.sh`, `scripts/state/find-active-milestone.sh` exist and follow the existing 4-rule + bash-callable conventions.

## Description

T05 ships **`orchestrator:context`** — the FR-4 read-only single-screen runtime-profile printer. The skill displays:
- Resolved orchestrator root (via `scripts/state/resolve-root.sh`)
- Runtime (Claude Code / Codex CLI / Cursor — detected from env vars / packaging markers)
- Capability profile (subset of capabilities probed at `init`; surfaces `BACKEND`, `OS`, `BASH_VERSION`, etc.)
- Intensity defaults (Quick / Standard / Full thresholds — from `templates/orchestrator-config-default.yml` or local config overrides)
- Active milestone (via `scripts/state/find-active-milestone.sh`; renders `none` when no active milestone exists)
- Lock state (via lock-manager state file read; mirrors `commands/status.md`'s existing pattern)

The output MUST fit in a single screen ≤24 lines on 80×24 (SC-4). The skill is read-only — no I/O writes (CON-1 / FR-14 / SC-14 invariant).

`orchestrator:context` is intended as a quick "what runtime am I in?" debugging skill. It composes existing surfaces; no new scripts are produced for this skill in P01 (it's a pure command-document surface that drives existing scripts).

## Steps

1. **Author `commands/context.md`** (≥60 lines) following the canonical command-document shape per `commands/zoom-out.md` analog:

   - YAML frontmatter:
     ```yaml
     ---
     description: "Use when checking the orchestrator runtime profile — resolved root, runtime, capability profile, intensity defaults, active milestone, lock state. Read-only single-screen debug skill."
     ---
     ```
   - H1: `# orchestrator:context`
   - One paragraph intro explaining FR-4 / Principle XI single-resolve / read-only nature; names "Single-screen ≤24 lines on 80×24 (SC-4)" as the size constraint.
   - `## Output Format` — documents the six required fields with their labels and example values:
     ```
     resolved root: /Users/foo/Projects/myproject
     runtime: claude-code
     capability profile: BACKEND=claude-code OS=darwin BASH_VERSION=3.2.57 ...
     intensity defaults: quick.knowledge_token_budget=800 standard.dispatch_budget=64 full.dispatch_budget=128
     active milestone: M029 (planning, Tier C)
     lock state: free
     ```
     Each line is one labeled field; the labels are exact (`resolved root:`, `runtime:`, `capability profile:`, `intensity defaults:`, `active milestone:`, `lock state:`). When no active milestone exists, the active-milestone line renders as `active milestone: none`. When the lock-manager state file is absent or unparseable, `lock state: unknown` (not `error` — read-only contract permits graceful degradation).
   - `## Single-Screen Constraint` — documents the SC-4 ≤24-lines-on-80×24 invariant. Required prose: "The full output MUST fit in a single screen — no more than 24 lines on an 80-column terminal. Each labeled field is one line. Multi-value fields (capability profile, intensity defaults) wrap onto a single line via space-separated key=value pairs; if wrapping risks exceeding column width, the implementation truncates with `…` and emits a stderr `note: capability profile truncated; see scripts/state/...` advisory."
   - `## Resolution` — documents the fields' source scripts:
     - resolved root → `scripts/state/resolve-root.sh`
     - runtime → env-var probing (`${CLAUDECODE:-}`, `${CODEX_CLI:-}`, `${CURSOR_TRACE_ID:-}`, fallback to `unknown`); cross-references the resolver's `default_provider` field (which carries the same info via config)
     - capability profile → packaging marker probe (read `.orchestrator/capability-profile.json` or equivalent) + `OS`, `BASH_VERSION`
     - intensity defaults → `bash scripts/state/read-config.sh <root> intensity_defaults` or fallback to `templates/orchestrator-config-default.yml` keys
     - active milestone → `bash scripts/state/find-active-milestone.sh <root>` (returns `M### <state> <tier>` or empty)
     - lock state → mirrors `commands/status.md`'s `### Stale Lock File` lookup
   - `## AD-1 Single-Resolve` — documents that `orchestrator:context` reads `scripts/state/detect-invocation-context.sh`'s emitted env block at entry (Principle XI). The displayed `runtime` and `default_provider` lines come through the resolver, not from re-implemented detection.
   - `## Read-Only Discipline` — documents CON-1 / FR-14 invariant: no writes anywhere; the skill emits to stdout only. Cross-references SC-14 (the M029 milestone-grain read-only assertion that lands in P02 via the AD-9 sentinel-file mechanism); P01's precursor read-only verifier (`tools/verify/m029-p01-readonly-invariant.sh`, T06 deliverable) covers this skill.
   - `## Idempotency` — `orchestrator:context` is purely read-only and idempotent.
   - `## Error Handling` — graceful degradation for each field source: missing config → `unknown` placeholder; missing active milestone → `none`; missing lock-manager state → `unknown`. The skill MUST exit 0 even when every field is degraded; the operator sees a degraded-but-rendered profile rather than a crash.
   - `## Reference Files` — names:
     - `scripts/state/detect-invocation-context.sh` (resolver — AD-1 single-resolve)
     - `scripts/state/resolve-root.sh` (resolved-root field)
     - `scripts/state/find-active-milestone.sh` (active-milestone field)
     - `scripts/state/read-config.sh` (intensity-defaults field)
     - `references/status-headline-shape.md` (companion design contract — context skill shares the resolver-eval-at-entry pattern)
     - `references/status-json-schema.md` (companion design contract)

2. **Create the SC-4 minimal fixture** at `tests/m029-acceptance/fixtures/status-headline-executing.fixture/` — REUSE the SC-2 fixture from T03 if its shape is sufficient, OR create a minimal `tests/m029-acceptance/fixtures/context-minimal.fixture/` if a fixture milestone is needed. Note: the context skill needs only a resolvable orchestrator root; it does NOT need a full execution-log + roadmap. If reuse is feasible (the SC-2 fixture provides a populated `.orchestrator/` tree), use it; if not, create a minimal fixture with just `.orchestrator/config.yml` + `.orchestrator/milestones/M999/M999-ROADMAP.md`. The executor decides at implementation time which path is simpler.

3. **Author `tests/m029-acceptance/p01-sc4-context.sh`** (≥50 lines, executable). The script:

   - Sets `set -u` and traps cleanup.
   - Creates a working temp dir; copies the chosen fixture into it.
   - Writes a sentinel file at `<tmpdir>/orch-root/.orchestrator/.m029-p01-sc4-sentinel` with the current ISO-8601 timestamp before the run (precursor to the AD-9 SC-14 mechanism).
   - Runs `orchestrator:context` against the fixture. Captures stdout to `<tmpdir>/sc4.out`.
   - Asserts stdout has ≤24 non-empty lines (assertion: `wc -l <tmpdir>/sc4.out` returns ≤24).
   - Asserts each documented field label appears on its own line (greps for the literal labels: `resolved root:`, `runtime:`, `capability profile:`, `intensity defaults:`, `active milestone:`, `lock state:`).
   - Asserts the read-only invariant: no file under `<tmpdir>/orch-root/.orchestrator/` has mtime newer than the sentinel (excluding the sentinel itself). Implementation: `find <tmpdir>/orch-root/.orchestrator/ -newer <tmpdir>/orch-root/.orchestrator/.m029-p01-sc4-sentinel -not -path '*/.m029-p01-sc4-sentinel'` returns no output.
   - Asserts exit 0 from the `orchestrator:context` invocation.
   - Cleanup `rm -rf <tmpdir>`.
   - Tracks pass/fail; emits `PASS:` / `FAIL:` lines + final `SC-4: pass=N fail=M`. Exit 0 iff `fail=0`.

4. **Author `tools/verify/m029-p01-context-skill-shape.sh`** (≥30 lines, executable). The verifier:

   - Gates on `[ -f commands/context.md ]`.
   - Asserts the YAML frontmatter contains `description:` (greps for the canonical command-doc convention).
   - Asserts the H1 `# orchestrator:context` is present.
   - Asserts every required H2 section appears: `## Output Format`, `## Single-Screen Constraint`, `## Resolution`, `## AD-1 Single-Resolve`, `## Read-Only Discipline`, `## Idempotency`, `## Error Handling`, `## Reference Files`.
   - Asserts each documented field label appears: `resolved root:`, `runtime:`, `capability profile:`, `intensity defaults:`, `active milestone:`, `lock state:`.
   - Asserts FR-4 reference + `single-screen` literal token + `≤24` literal token.
   - Asserts the script names `scripts/state/detect-invocation-context.sh` (resolver) AND `scripts/state/resolve-root.sh` AND `scripts/state/find-active-milestone.sh` AND `references/status-headline-shape.md` AND `references/status-json-schema.md`.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-context-skill-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p01-sc4-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f tests/m029-acceptance/p01-sc4-context.sh ]`.
   - Asserts the SC-4 script is executable.
   - Asserts the SC-4 script's header references SC-4 AND FR-4.
   - Asserts the script invokes `orchestrator:context` (greps for the literal token).
   - Asserts the script greps for the six required field labels.
   - Asserts the script implements the sentinel-file read-only check (greps for `m029-p01-sc4-sentinel` AND `find` AND `-newer`).
   - Runs `bash tests/m029-acceptance/p01-sc4-context.sh` and asserts exit 0.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-sc4-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

6. **Run all verifiers + the SC-4 script** to confirm green.

## Must-Haves

This task addresses these P01 phase truths:
- `commands/context.md` exists in canonical shape, single-screen ≤24 lines on 80×24, documents the FR-4 field set.
- The SC-4 acceptance script exits 0 with the read-only invariant satisfied.

This task creates these P01 phase artifacts:
- `commands/context.md` — FR-4 single-screen invocation-context skill.
- `tests/m029-acceptance/p01-sc4-context.sh` — SC-4 acceptance script.
- `tools/verify/m029-p01-context-skill-shape.sh` — commands/context.md shape verifier.
- `tools/verify/m029-p01-sc4-shape.sh` — SC-4 wrapper verifier.

## Verification

```bash
bash tools/verify/m029-p01-context-skill-shape.sh
```

```bash
bash tools/verify/m029-p01-sc4-shape.sh
```

## Inputs

### From Previous Tasks

- `references/status-headline-shape.md` (from T01) — `commands/context.md` cross-references this in its Reference Files section so the round-trip link is auditable; `orchestrator:context` shares the resolver-eval-at-entry pattern with `orchestrator:status`.
- `references/status-json-schema.md` (from T01) — same cross-reference rationale.
- `scripts/state/detect-invocation-context.sh` (from T02) — `orchestrator:context` reads the resolver's emitted env block at command entry (AD-1 single-resolve); the `runtime` and `default_provider` fields displayed by the skill come through the resolver.
  - Key API: 3-line key=value env block on stdout; eval'able via `eval "$(bash scripts/state/detect-invocation-context.sh)"`.

### From Disk (Pre-existing)

- `commands/zoom-out.md` — closest analog for a read-only debug skill; mirror its document shape (frontmatter description; intro paragraph; `## Output Format`; `## Read-Only`; `## Reference Files`).
- `scripts/state/resolve-root.sh` — provides the `resolved root:` field.
- `scripts/state/find-active-milestone.sh` — provides the `active milestone:` field.
- `scripts/state/read-config.sh` — provides the `intensity defaults:` field.
- `templates/orchestrator-config-default.yml` — fallback source for intensity defaults if local config absent.
- The lock-manager state file lookup pattern from `commands/status.md`'s `### Stale Lock File` section — reused for the `lock state:` field.

## Constraints

- Single-screen ≤24 lines on 80×24 (SC-4) is the load-bearing UX constraint. The implementation MUST truncate or wrap multi-value fields rather than overflow the screen budget. When truncation occurs, a stderr advisory names the truncated field; stdout stays within budget.
- AD-1 single-resolve: the skill MUST read `scripts/state/detect-invocation-context.sh`'s output for runtime detection. It MUST NOT re-implement TTY / CI / runtime probing.
- Read-only (CON-1 / FR-14 / SC-14): the skill writes nothing. The SC-4 script's sentinel-file precursor check enforces this at acceptance time.
- Graceful degradation: every field has a documented fallback (`unknown` for unresolvable, `none` for active-milestone). Exit 0 even with degraded fields. The operator sees the degraded profile rather than a crash.
- The skill is a command-document surface only; it produces NO new scripts in P01. The body composes existing scripts (`resolve-root.sh`, `find-active-milestone.sh`, `read-config.sh`, the resolver) plus inline reads of the lock-manager state file.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T05 creates only `commands/context.md` + acceptance + verifier files. NO modification to M013/M019/M020/M027 surfaces.

## Expected Output

After T05 completes:
- `commands/context.md` exists in canonical command-document shape with all required sections.
- `tests/m029-acceptance/p01-sc4-context.sh` exists, is executable, exits 0 with `SC-4: pass=N fail=0`.
- Both verifiers (`m029-p01-context-skill-shape.sh`, `m029-p01-sc4-shape.sh`) exist, are executable, exit 0.
- A summary file at `.orchestrator/milestones/M029/phases/P01/tasks/T05-context-skill-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output: per-assertion `PASS:` lines, ending with `SUMMARY: m029-p01-context-skill-shape.sh pass=12 fail=0` (and similar for sc4). Expected SC-4 acceptance output: per-assertion `PASS:` lines covering the line count + every label + the sentinel-file read-only check, ending with `SC-4: pass=N fail=0`.

The skill's value proposition: a developer drops `orchestrator:context` into any orchestrator-managed project and immediately sees what runtime, what intensity profile, what active milestone — without scrubbing config files. Useful for "is this orchestrator state even valid?" debugging at session resume.
