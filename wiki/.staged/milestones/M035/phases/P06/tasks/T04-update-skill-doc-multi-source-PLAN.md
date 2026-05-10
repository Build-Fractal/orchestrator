---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M035"
name: "`commands/update.md` extended dispatch documentation — per-channel table + AD-5 paragraph + suppression-knob enumeration"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- **T01 closed** — `update_source` schema registered. T04 documents
  the schema enumeration verbatim.
- **T02 closed** — multi-source dispatch + AD-5 detection in
  `run-update.sh`. T04 documents the dispatch contract operator-facing.
- **T03 closed** — `update_run` JSONL emission + 5-condition
  suppression matrix. T04 documents the emission shape + suppression
  knobs operator-facing.
- **`commands/update.md`** exists with the `## Update sources` H2
  shipped via P03 T04 / P04 T04 (lists git/npm/homebrew/curl-pipe-bash
  channels in single-bullet form). T04 extends this section by
  REPLACING the bullets with a richer table + sub-sections covering
  AD-5 detection + suppression knobs + JSONL emission. The
  `## Rollback` section (P05 T02) is preserved verbatim — T04 does
  NOT touch it.
- **`scripts/lib/errors.sh`** exists. T04 verifier sources this.
- No `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`
  exists at plan-authoring time (Plan-Time Discipline Rule 6 confirmed
  absent).

## Description

T04 ships the operator-facing documentation for the multi-source
dispatch contract. The existing `## Update sources` H2 is the right
attach point but needs three additions:

1. **Per-channel dispatch table** — replace the four single-bullet
   listings with a table showing `update_source` value, dispatched
   command, pre-flight check, and channel-specific notes. The table
   shape mirrors the existing `## Failure Modes` table in
   `commands/update.md`.

2. **AD-5 detection paragraph** — when `update_source` is absent from
   `.orchestrator/config.yml`, the driver auto-detects per the
   ordering recorded in D014 (install-meta.txt → npm root -g check →
   brew --prefix check → git fallback) and persists detected non-git
   sources to config. Documented end-to-end with the persistence
   semantics so operators understand what hits their config file on
   first non-git invocation.

3. **JSONL emission + suppression-knob enumeration** — new H3 under
   `## Update sources` documenting the `update_run` event shape, the
   emission target (`.orchestrator/observability/<date>.jsonl`), and
   the 5-condition suppression matrix verbatim per D013.

Existing sections preserved unchanged:

- `## When to Use`
- `## What It Does`
- `## Invocation`
- `## Rollback` (P05 T02 — verbatim preserved)
- `## Output`
- `## Failure Modes`
- `## Read-Mostly Discipline`
- `## Cross-references`

The cross-references section gets one new entry pointing at
`references/installation.md § Channel-specific metadata files`
(MIT-2 exclusion list, also referenced by the byte-equivalence
test). All other cross-refs preserved.

## Steps

1. **Read `commands/update.md`** to confirm the current shape of
   `## Update sources` (P03 T04 + P04 T04 expansions). Snapshot at
   plan-authoring time:

   ```markdown
   ## Update sources

   - **`update_source: git`** — dispatches `install-claude-code.sh --force` ...
   - **`update_source: npm`** — dispatches `npm update -g @build-fractal/orchestrator` ...
   - **`update_source: homebrew`** — dispatches `brew upgrade orchestrator` ...
   - **`update_source: curl-pipe-bash`** — dispatches `curl -sSL ... install.sh | bash` ...
   ```

   T04 replaces this section's body (preserving the H2 heading) with
   the expanded shape below.

2. **Author the replacement `## Update sources` body**:

   ```markdown
   ## Update sources

   `orchestrator:update` reads `update_source` from
   `.orchestrator/config.yml` and dispatches to the channel-appropriate
   command. The schema enumeration is `git|npm|homebrew|none`
   (per FR-13 and D012). Curl-pipe-bash users are auto-detected as
   `npm` because the curl-pipe-bash installer extracts the npm
   tarball — D007/D009 single-source-of-truth.

   ### Dispatch table

   | `update_source` | Dispatched command | Pre-flight check | Notes |
   |---|---|---|---|
   | `git` | `bash <source-repo>/packaging/install/install-claude-code.sh --force` | `<source-repo>` exists with `packaging/install/install-claude-code.sh` | Pre-M035 interim path; default for dogfooders. Resolves source via `--source-repo` / `$ORCHESTRATOR_SOURCE_REPO` / `~/Sites/orchestrator`. |
   | `npm` | `npm update -g @build-fractal/orchestrator` | `npm` on PATH AND `[ -d "$(npm root -g)/@build-fractal/orchestrator" ]` | Default for npm consumers. Dispatch is direct; no source-repo resolution required. |
   | `homebrew` | `brew upgrade orchestrator` | `brew` on PATH AND `[ -d "$(brew --prefix)/Cellar/orchestrator" ]` | Default for brew consumers via the `build-fractal/orchestrator` tap. |
   | `none` | `<no-op>` (operator opt-out) | none | Suppresses both `orchestrator:update` dispatch and the FR-4 drift-render in `orchestrator:status`. No JSONL emission. |

   ### AD-5 detection (when `update_source` is absent)

   When `update_source` is absent from `.orchestrator/config.yml` (the
   case for every pre-launch consumer), the driver auto-detects per
   D014's ordering:

   1. Read `.orchestrator/install-meta.txt` `runtime=` field. If the
      value contains the literal substring `npm` / `homebrew` /
      `brew` / `curl` / `git` (case-insensitive), use that. (`curl`
      resolves to `npm` per D012.)
   2. If `runtime=` doesn't disambiguate AND `npm` is on PATH AND
      `[ -d "$(npm root -g)/@build-fractal/orchestrator" ]`, resolve
      to `npm`.
   3. If still unresolved AND `brew` is on PATH AND
      `[ -d "$(brew --prefix)/Cellar/orchestrator" ]`, resolve to
      `homebrew`.
   4. Fallback: `git`.

   When detection lands on a non-`git` source, the resolved value is
   **persisted** to `.orchestrator/config.yml` as a top-level
   `update_source: <value>` line. Subsequent runs hit the persisted
   value and skip detection. Git-fallback resolutions are NOT
   persisted (default behavior; persisting would noise up every fresh
   consumer's config).

   ### `update_run` JSONL emission

   Each successful dispatch decision-point appends one `update_run`
   event to `.orchestrator/observability/<YYYY-MM-DD>.jsonl`:

   ```json
   {"event":"update_run","op":"update","source":"<channel>","target_version":"<version-or-unknown>","result":"success","timestamp":"2026-05-09T18:42:00Z"}
   ```

   `op=rollback` events come from `--rollback` (see `## Rollback`).
   `result=failure` events fire for post-validation dispatch failures
   (e.g. `npm update` exits non-zero); pre-validation failures (npm
   not on PATH, package not installed) emit nothing.

   ### Suppression knobs (5-condition matrix per D013)

   `update_run` emission honors [M027](../../../../../milestones/M027/index.md)'s 5-condition suppression matrix
   verbatim:

   1. **`--no-emit-jsonl` flag** on `run-update.sh` short-circuits
      emission. Opt-out only; does NOT abort dispatch.
   2. **`ORCHESTRATOR_AUTO=1` env var** short-circuits emission.
      Auto-loop runs are not metering events the operator cares to
      see.
   3. **`update_source: none`** short-circuits both dispatch and
      emission.
   4. **`compression.efficiency_footer.enabled: false`** does NOT
      apply (orthogonal surface — that knob gates efficiency-footer
      rendering, not JSONL stream writes).
   5. **Structural carve-out**: emission is bound to a successful
      dispatch decision-point. Pre-dispatch validation failures emit
      nothing.

   M035 introduces no new suppression knob beyond `--no-emit-jsonl`
   (FR-16: M035 inherits M025/M027 conventions).
   ```

3. **Add one new entry to `## Cross-references`** (preserving every
   existing entry):

   ```markdown
   - **`references/installation.md § Channel-specific metadata files`** — MIT-2 canonical exclusion list referenced by the cross-channel byte-equivalence test (CON-5).
   ```

4. **Author the verifier**
   `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`.
   Single-script-file shape, AD-19, ~50 lines. Sources
   `scripts/lib/errors.sh`. Asserts:

   1. `commands/update.md` is readable.
   2. The file contains the `## Update sources` H2 heading.
   3. The file contains the `### Dispatch table` H3 (new in T04).
   4. The file contains the `### AD-5 detection` H3 (new in T04).
   5. The file contains the `### update_run JSONL emission` H3
      (new in T04). NOTE: the H3 will render as `### \`update_run\` JSONL emission` due to the inline backtick — verifier uses `grep -F` to match the literal.
   6. The file contains the `### Suppression knobs` H3 (new in T04).
   7. The file contains the literal token `update_source: git|npm|homebrew|none`.
   8. The file contains the literal token `D012`, `D013`, AND `D014`
      cross-references.
   9. The file contains the literal token `npm root -g` AND
      `brew --prefix`.
   10. The file contains the literal token `--no-emit-jsonl`.
   11. The file contains the literal token `ORCHESTRATOR_AUTO`.
   12. The `## Rollback` section is preserved verbatim — verifier
       greps for the literal advisory string `rollback not available
       for symlink-mode installs` from P05 T02.
   13. The cross-references section contains the new entry pointing
       at `references/installation.md § Channel-specific metadata files`
       — use `grep -qF` for the literal substring.

   Emit `BATTERY: pass=N fail=0` summary.

   The verifier MUST honor AD-19 — no inline compound chains. Use
   `grep -qF -- '<pattern>'` form for any pattern starting with `--`
   (BSD-grep portability per the P04 T04 finding).

## Must-Haves

- `commands/update.md` modified — `## Update sources` H2 body
  replaced with: dispatch table + AD-5 detection H3 +
  `update_run` JSONL emission H3 + suppression knobs H3.
- `commands/update.md` modified — `## Cross-references` extended with
  one new entry pointing at the MIT-2 exclusion list.
- `commands/update.md` UNCHANGED — `## Rollback` section verbatim
  preserved (P05 T02 contract); `## When to Use`, `## What It Does`,
  `## Invocation`, `## Output`, `## Failure Modes`, `## Read-Mostly
  Discipline` all preserved.
- `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`
  exists, executable, ~50+ lines, contains `BATTERY:`, emits
  `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/state/read-config.sh` (from T01) — schema registration is
  now operator-discoverable; T04 documents the schema enumeration
  verbatim.
- `scripts/lifecycle/run-update.sh` (from T02 + T03) — multi-source
  dispatch + AD-5 detection + JSONL emission. T04 documents the
  contract end-to-end so operators don't have to read the script to
  understand the surface.

### From Disk (Pre-existing)

- `commands/update.md` — current shape after P05 T02 (`## Rollback`
  section) + P03/P04 T04 (`## Update sources` H2 four-bullet form).
  T04 replaces only the H2 body; everything else preserved.
- `references/installation.md` — `## Channel-specific metadata files`
  section shipped via P02 T03. Cross-referenced from the new
  `## Update sources § Suppression knobs` and `## Cross-references`.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p06-*.sh`. No inline compound chains.
- **BSD-grep flag pattern portability** — `grep -qF -- '--no-emit-jsonl'`
  is the portable shape (pattern starts with `--`). Mirror P04 T04's
  precedent.
- **Section preservation discipline** — T04 modifies only the
  `## Update sources` H2 body and one new entry in
  `## Cross-references`. Every other section is verbatim-preserved.
  Verifier asserts the `## Rollback` symlink-mode advisory remains
  byte-identical to its P05 T02 shape.
- **Self-sufficient operator copy** — every recipe in the new
  documentation is runnable end-to-end without other-doc indirection
  (per the P05 T04 self-contained-operator-recipe pattern). The
  dispatch table shows the literal command per channel; the AD-5
  detection paragraph enumerates the four steps; the JSONL emission
  H3 shows the literal event template.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against
  `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`;
  ABSENT.

## Expected Output

Stdout from `bash tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh`:

```
PASS: commands/update.md contains ## Update sources heading
PASS: commands/update.md contains ### Dispatch table heading
PASS: commands/update.md contains ### AD-5 detection heading
PASS: commands/update.md contains ### update_run JSONL emission heading
PASS: commands/update.md contains ### Suppression knobs heading
PASS: commands/update.md contains schema enumeration `git|npm|homebrew|none`
PASS: commands/update.md cross-references D012, D013, AND D014
PASS: commands/update.md references npm root -g AND brew --prefix
PASS: commands/update.md references --no-emit-jsonl
PASS: commands/update.md references ORCHESTRATOR_AUTO
PASS: ## Rollback section preserves the symlink-mode advisory verbatim
PASS: ## Cross-references contains MIT-2 exclusion-list entry
BATTERY: pass=12 fail=0
```
