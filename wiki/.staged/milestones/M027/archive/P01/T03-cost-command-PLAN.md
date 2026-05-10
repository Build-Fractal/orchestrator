---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M027"
name: "commands/cost.md user-facing command + +/-20% accuracy disclaimer per D027"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped `scripts/engine/cost-estimate.sh` (sourceable + CLI). CLI accepts `--description "<text>"` and `--format text|json`. Text mode emits a 3-row table with header, recommended-tier marker, and accuracy trailer per D027.
- T02 has modified `scripts/engine/intensity-recommend.sh` to accept `--format text|json` and to append per-tier cost annotations.
- M027/P00 has shipped `scripts/diagnostics/metrics-rollup.sh` (sourceable + CLI). CLI accepts `--granularity task|phase|milestone|project`, `--milestone Mxxx`, `--phase Pxx`, `--task <id>`, `--source estimate|runtime|aggregate|all`, `--log <path>`, `--help`. Live invocation against `.orchestrator/milestones/M019/execution-log.jsonl` exits 0 and emits one paired cost+quality milestone row.
- Project commands convention (MEM012): every `commands/*.md` follows the structure: YAML frontmatter (`description` field), Title, Prerequisites / State Check, Core Workflow (numbered sections), Output, Idempotency, Error Handling, Referenced Scripts.
- M015/[M025](../../../../milestones/M025/index.md) packaging: the runtime adapters under `scripts/dispatch/adapters/runtime/{claude-code,codex,cursor}.sh` auto-register every `commands/*.md` (excluding `README.md`) as a runtime skill / command on `--register`. No code changes to the adapters or to `packaging/bundle/manifest.yml` are required to add a new command — only the `commands/cost.md` file. (Optional: add a thin discovery-surface skill file under `packaging/bundle/skills/orchestrator-cost.md` for runtimes that enumerate skills from the bundle directory; T03 ships this for parity with the existing 12 skills, even though the adapter auto-register path does not require it.)

## Description

Create `commands/cost.md` — the canonical user-facing definition for `orchestrator:cost`. The command exposes two surfaces:

1. **Retrospective** (no flags or with scope flags): a thin wrapper over `scripts/diagnostics/metrics-rollup.sh`. Defaults: active milestone if one is detectable, else project-granularity rollup. Accepts `--milestone`, `--phase`, `--task`, `--granularity`, `--source`, `--since` flags that pass through to the rollup engine.

2. **Predictive** (`--estimate "<description>"`): delegates to `scripts/engine/cost-estimate.sh --description "<description>"`. Output is a 3-row Quick / Standard / Full paired cost+quality table with the recommended tier marked, plus the accuracy trailer.

The command document also embeds the verbatim D027 accuracy disclaimer under a dedicated `## Accuracy` section — load-bearing for SC-18 and for downstream parser tooling that surfaces command help.

Additionally, ship a thin discovery-surface skill stub at `packaging/bundle/skills/orchestrator-cost.md` mirroring the shape of the existing 12 skills (e.g., `orchestrator-status.md`). The bundle manifest at `packaging/bundle/manifest.yml` is updated to include the new skill in the `skills:` list — this keeps bundle introspection consistent with the runtime-adapter auto-registration path.

## Steps

1. **Create `commands/cost.md`** with the following structure (follows MEM012):

   ```markdown
   ---
   description: "Use when surfacing orchestrator cost data — retrospective rollups over the [M019](../../../../milestones/M019/index.md) Tier 1 JSONL stream, or predictive per-tier (Quick / Standard / Full) cost+quality estimates before dispatch. Read-only; bash-only; zero LLM tokens."
   ---

   # orchestrator:cost

   <one-paragraph summary>

   ## Prerequisites / State Check

   - `.orchestrator/` exists at the project root (run `orchestrator:init` first).
   - For retrospective surface: `scripts/diagnostics/metrics-rollup.sh` is executable.
   - For predictive surface: `scripts/engine/cost-estimate.sh` is executable; `scripts/lib/pricing.sh` is sourceable.

   ## Core Workflow

   ### 1. Resolve mode (retrospective vs predictive)

   <text>

   ### 2. Retrospective: rollup over M019 Tier 1 JSONL

   <text + delegation to metrics-rollup.sh>

   ### 3. Predictive: per-tier estimate before dispatch

   <text + delegation to cost-estimate.sh>

   ## Output

   <text describing both surfaces>

   ## Accuracy

   Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).

   ## Idempotency

   <text — both surfaces are read-only; running twice produces identical stdout modulo timing>

   ## Error Handling

   <text — missing .orchestrator/, missing pricing.yml, mutually exclusive flags>

   ## Referenced Scripts

   - `scripts/diagnostics/metrics-rollup.sh` — retrospective rollup engine (P00)
   - `scripts/engine/cost-estimate.sh` — predictive per-tier estimator (P01/T01)
   - `scripts/engine/intensity-recommend.sh` — recommendation engine consumed by predictive surface (P01/T02)
   - `scripts/lib/pricing.sh` — pricing + token-estimate helpers (M019)
   ```

2. **Flesh out the Core Workflow sections** with concrete, agent-facing instructions:

   - Section 1 (Resolve mode): if invocation includes `--estimate <description>`, predictive mode; else retrospective.
   - Section 2 (Retrospective): pseudocode-level — resolve the active milestone via `bash scripts/state/derive-phase.sh` or fall back to project-granularity; build the `metrics-rollup.sh` argument list from any passed `--milestone`/`--phase`/`--task`/`--granularity`/`--source`/`--since` flags; invoke; print stdout to user. Emit a one-line command header `# orchestrator:cost — retrospective rollup` ABOVE the rollup engine output. The header is the only divergence from `metrics-rollup.sh` direct output, satisfying SC-4.
   - Section 3 (Predictive): pseudocode-level — invoke `bash scripts/engine/cost-estimate.sh --description "$DESCRIPTION"`; print stdout to user. The output already includes the per-tier table + accuracy trailer; no command header is added (the table itself is self-identifying, and adding a header would push the output below the 100ms latency budget more than necessary). The agent SHOULD remind the operator of the override semantics in a one-line trailer if interactive: "press a number 1-3 to switch tiers, or accept the recommended tier with Enter" — but this trailer is informational only and does NOT participate in dispatch flow (dispatch-time interactive surface is P02 work).

3. **Embed the D027 disclaimer verbatim** in the `## Accuracy` section (step 1 has the literal copy). Verifier `m027-p01-cost-command-shape.sh` greps for the verbatim string.

4. **Document Error Handling**:
   - No `.orchestrator/` at project root → exit 2 with the existing diagnostic shape (`run orchestrator:init first`).
   - Mutually exclusive flags (e.g., `--task` + `--granularity milestone`) → exit 2 with usage error.
   - `--estimate` with no following description → exit 2 with usage error.
   - Missing `pricing.yml` → predictive surface emits `(unavailable)` cost cells per FR-24; never aborts (CON-5 carry-forward).

5. **Document Idempotency**: both surfaces are read-only; `git diff --quiet` is exit 0 after invocation; running twice produces identical stdout modulo timing.

6. **Create `packaging/bundle/skills/orchestrator-cost.md`** as a thin discovery-surface skill mirroring `orchestrator-status.md`:

   ```
   ---
   schema_version: "1.0"
   type: skill
   name: "orchestrator:cost"
   namespace: "orchestrator"
   description: "Use when surfacing orchestrator cost data — retrospective rollups over the M019 Tier 1 JSONL stream, or predictive per-tier (Quick / Standard / Full) cost+quality estimates before dispatch. Read-only; bash-only; zero LLM tokens."
   runtime_compatibility: ["claude-code", "codex", "cursor"]
   command_file: "commands/cost.md"
   ---

   # orchestrator:cost

   Canonical behavior is defined in [`commands/cost.md`](../../../commands/cost.md).
   This skill file is a thin discovery surface for runtimes that enumerate skills
   from disk. When the runtime invokes `orchestrator:cost`, it delegates to the
   command document above.
   ```

7. **Update `packaging/bundle/manifest.yml`** — add `- orchestrator-cost.md` to the `skills:` list (alphabetically, between `orchestrator-consolidate.md` and `orchestrator-discuss.md`). Bump `version` if the existing convention is to bump per-feature; preserve existing version if convention is to bump only at consolidate. Inspect `git log packaging/bundle/manifest.yml` to determine the convention (likely: leave version unchanged at task scope).

8. **bash 3.2 / pure-markdown discipline.** This task ships markdown only; no shell code in `commands/cost.md` beyond example invocation lines. The CON-7 verifier does not apply to markdown but the verifier suite still greps for forbidden tokens to catch accidental inline-script anti-patterns.

## Must-Haves

- File `commands/cost.md` exists, ≥ 80 lines, contains the literal string `orchestrator:cost`.
- File `commands/cost.md` contains the verbatim D027 disclaimer: `Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).`
- File `commands/cost.md` contains references to all four scripts: `scripts/diagnostics/metrics-rollup.sh`, `scripts/engine/cost-estimate.sh`, `scripts/engine/intensity-recommend.sh`, `scripts/lib/pricing.sh`.
- File `commands/cost.md` documents both surfaces (retrospective AND predictive) and a `## Accuracy` heading.
- File `packaging/bundle/skills/orchestrator-cost.md` exists with `name: "orchestrator:cost"` and `command_file: "commands/cost.md"`.
- File `packaging/bundle/manifest.yml` lists `orchestrator-cost.md` in the `skills:` array.

## Verification

```bash
bash scripts/verify/m027-p01-t03-shape-precheck.sh
```

This precheck verifier (T03-scoped, ships with T03) asserts T03's six must-haves: `commands/cost.md` exists ≥80 lines and references `orchestrator:cost`, the verbatim D027 disclaimer is present, the `## Accuracy` heading is present, all four script paths (`metrics-rollup.sh`, `cost-estimate.sh`, `intensity-recommend.sh`, `pricing.sh`) are referenced, the skill stub at `packaging/bundle/skills/orchestrator-cost.md` carries the right frontmatter, and `packaging/bundle/manifest.yml` registers the skill.

T04 ships the canonical phase-level verifier `m027-p01-cost-command-shape.sh` (which subsumes this precheck). The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` runs at the phase boundary, not at T03 task verification (per the M027/P00 parser-shape lesson — task-level Verification must reference only what the task itself produces).

## Inputs

### From Previous Tasks

- T01: `scripts/engine/cost-estimate.sh` — invoked from the `## Core Workflow ### 3.` section as `bash scripts/engine/cost-estimate.sh --description "<text>"`. Output: 3-row table with header + recommended-tier marker + accuracy trailer.
- T02: modified `scripts/engine/intensity-recommend.sh` — referenced (not invoked) from `commands/cost.md`'s "Referenced Scripts" section as the recommendation engine consumed transitively by the predictive surface.

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (P00) — invoked from the `## Core Workflow ### 2.` section. Accepts `--granularity task|phase|milestone|project`, `--milestone`, `--phase`, `--task`, `--source`, `--log`. Live invocation against `.orchestrator/milestones/M019/execution-log.jsonl` emits one paired cost+quality row.
- `scripts/state/derive-phase.sh` — invoked to detect the active milestone for default-scope resolution. Outputs a single state word + the active milestone path on stderr (existing convention).
- `commands/status.md`, `commands/doctor.md`, `commands/init.md` — reference shapes for the canonical commands convention (MEM012). Read these to mirror structure.
- `packaging/bundle/skills/orchestrator-status.md` — reference shape for the discovery-surface skill stub.
- `packaging/bundle/manifest.yml` — modify in place to add `orchestrator-cost.md` to the `skills:` list.
- `scripts/dispatch/adapters/runtime/claude-code.sh`, `codex.sh`, `cursor.sh` — auto-register every `commands/*.md` on `--register`. No code change required.

## Constraints

- **MEM012 (command structure)**: Follow the canonical sections — frontmatter `description`, Title, Prerequisites / State Check, Core Workflow (numbered sections), Output, Idempotency, Error Handling, Referenced Scripts. The `## Accuracy` section is M027-specific addition between `Output` and `Idempotency`.
- **D027 (disclaimer copy)**: Verbatim string under `## Accuracy`. T04's `m027-p01-cost-command-shape.sh` greps for it.
- **D026 (JSON shape)**: Documented in `commands/cost.md` only at high level (the predictive surface delegates to T01's CLI which owns the JSON contract); not load-bearing in this task.
- **CON-1 / FR-12 (read-only)**: `commands/cost.md` documents that both surfaces are read-only; T04's read-only verifier asserts.
- **CON-7 (bash 3.2)**: `commands/cost.md` is markdown; no inline shell anti-patterns. The skill stub is YAML frontmatter + 4 lines of markdown body.
- **AD-19 (single-script-file Check shape)**: This task does NOT define any `Check:` commands; phase-level Truths use single-script-file shape (verifiers ship in T04).
- **Runtime-adapter contract** (M015/M025): The adapters auto-register every `commands/*.md` on `--register`. After this task, running the adapter `--register --dry-run` lists `commands/cost.md` among the would-write entries. T04's `m027-p01-runtime-adapter-registration.sh` verifier asserts.

## Expected Output

After this task:

1. `commands/cost.md` exists, ≥ 80 lines, follows MEM012, contains the verbatim D027 disclaimer.
2. `packaging/bundle/skills/orchestrator-cost.md` exists with the canonical skill stub shape.
3. `packaging/bundle/manifest.yml` lists `orchestrator-cost.md` in the `skills:` array.
4. Running `bash scripts/dispatch/adapters/runtime/claude-code.sh --register --dry-run` from this repo emits a `would_write=...orchestrator-cost.md` line.
5. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
