---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M035"
name: "FR-4 drift line in M029 status headline + status-headline-shape.md addendum + phase-suite aggregator"
depends_on: ["T03"]
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring time):

- `scripts/state/check-orchestrator-drift.sh` (authored by T03;
  emits the structured `key=value` block consumed here)
- `commands/status.md` (M029/P01-shipped TUI render path; carries
  the headline+flat-sections wiring per `references/status-headline-shape.md`)
- `scripts/diagnostics/render-status-json.sh` (M029/P01-shipped
  JSON render path; carries the headline-fields-as-JSON-keys
  contract; `_M029_SCHEMA_VERSION="1.0"`)
- `references/status-headline-shape.md` (M029/P01 design contract;
  this task appends a documented addendum, does not redefine the
  three-line headline regex)
- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt`,
  `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (from T01)

Pre-existing decisions consumed:

- `references/status-headline-shape.md` § Embedded Footer (line 87-110):
  the embedded footer line is a documented optional 4th line.
  M035 P01's drift line is a 5th optional line; the regex for the
  three byte-stable headline lines is unchanged.
- AD-4 (M035 discuss): M035 contributes the drift datum, M029 renders.
  The change here is in M029's render code (which M035 owns the right
  to extend per AD-4); the M029 regex contract for lines 1-3 is
  preserved byte-for-byte — SC-2 of M029's spec stays green.
- FR-16 / `update_source: none`: rendering suppression policy.

## Description

Wire the T03 drift helper's stdout into both render paths
(`commands/status.md` TUI + `render-status-json.sh` JSON) so the
documented `STALE: orchestrator runtime is N commits behind upstream
— run \`orchestrator:update\`` line appears as a 5th optional headline
line when `commits_behind > 0`, and is suppressed cleanly when
`update_source=none`, when `commits_behind=0`, and when the drift
helper itself is unavailable.

This task also authors the M035 P01 phase-suite aggregator
(`tools/verify/m035-p01-phase-suite.sh`) per the AD-19 path-discipline
naming convention, and appends the § Drift Line (M035 P01) addendum
to `references/status-headline-shape.md` so the contract is on disk
for downstream scrapers.

## Steps

1. **Update `commands/status.md`** to consume the drift helper. The
   exact wiring is documented as a render step in the LLM-instruction
   skill body (the file is markdown, not bash). The new step appears
   AFTER the embedded efficiency-footer step, BEFORE the existing flat
   sections begin. Pseudocode-shape addition (in the actual file,
   render the change as a documented step + bash snippet, mirroring
   how the headline + footer steps are documented today):

   ```markdown
   > **Drift line (M035 P01 / FR-4 / SC-4).** After the embedded footer
   > line, invoke `bash scripts/state/check-orchestrator-drift.sh
   > --consumer "$PROJECT_DIR" 2>/dev/null`. Parse the structured stdout:
   >
   >   commits_behind=<value>
   >   update_source=<git|npm|homebrew|none>
   >   versions_behind=<value>
   >
   > Suppression matrix (FR-4, FR-16):
   > - `update_source=none` → emit nothing.
   > - `commits_behind=0` AND `versions_behind=0` → emit nothing.
   > - drift helper exits non-zero or output unparseable → emit nothing
   >   (degrade gracefully per Edge Case line 181).
   >
   > Otherwise emit exactly one line, byte-stable:
   >
   >   `STALE: orchestrator runtime is N commits behind upstream — run \`orchestrator:update\``
   >
   > where N is `commits_behind` when numeric, or the literal `unknown`
   > when the SHA-absent fallback fired (the rendered line says
   > `unknown commits behind` in that case; the user-visible advisory
   > line in stderr from the helper has already explained the cause).
   ```

   The actual edit appends this block to `commands/status.md` between
   the existing footer-block and the flat-sections-invariant block.

2. **Update `scripts/diagnostics/render-status-json.sh`** to add a
   new top-level field `drift` to the JSON envelope. Schema:

   ```json
   {
     "schema_version": "1.0",
     "milestone_id": "...",
     "...": "...",
     "drift": {
       "commits_behind": "<integer-or-string-unknown>",
       "update_source": "git|npm|homebrew|none",
       "upstream_path": "<absolute-path-or-empty>",
       "versions_behind": "<integer>",
       "rendered_line": "<exact-string-rendered-by-tui-or-empty>"
     }
   }
   ```

   Implementation: invoke the helper, parse the four fields with
   `sed -n 's/^commits_behind=\(.*\)$/\1/p'` etc., build the `drift`
   object via the existing jq-based assembly path. When the helper
   is unavailable or `update_source=none`, emit
   `"drift": {"update_source": "none", "commits_behind": 0, "versions_behind": 0, "rendered_line": ""}`.

   **Schema-version policy**: the addition of the `drift` field is
   an additive schema change. Per AD-7 stability policy at
   `references/status-json-schema.md`, additive top-level fields do
   NOT bump `_M029_SCHEMA_VERSION`. The M029 cross-check verifier
   that asserts `schema_version == "1.0"` byte-for-byte stays green.
   Document this decision inline in `render-status-json.sh` next
   to the drift-emission code so future readers know the addition
   was intentional.

3. **Append § Drift Line (M035 P01) to `references/status-headline-shape.md`**.
   New section after § CON-5 Suppression Matrix. Body:

   ```markdown
   ## Drift Line (M035 P01)

   The drift line is an optional FIFTH line that appears after the
   three byte-stable headline lines and the embedded efficiency-footer
   line. It is governed by the `update_source` config value and the
   `commits_behind` / `versions_behind` data emitted by
   `scripts/state/check-orchestrator-drift.sh` (M035 P01 / FR-3).

   ### Render Conditions

   The drift line renders if-and-only-if ALL of:
     - `update_source != none` (FR-16 suppression honor)
     - `commits_behind > 0` OR `versions_behind > 0`
     - the drift helper exited 0 with parseable stdout

   ### Line Shape

   When rendered, the line is byte-stable:

       STALE: orchestrator runtime is <N> commits behind upstream — run `orchestrator:update`

   where:
     - `<N>` is the integer `commits_behind` value when numeric.
     - `<N>` is the literal token `unknown` when the SHA-absent
       fallback fired (#Q-G5 / SC-3b path); the user-visible advisory
       in the helper's stderr has already explained the cause.

   The em-dash separator is U+2014 (`—`). The backticks around
   `orchestrator:update` are literal backticks. Renderers MUST NOT
   substitute hyphens for the em-dash.

   ### JSON-side Field

   Under `--format=json`, the drift datum appears as the top-level
   `drift` object:

   ```json
   "drift": {
     "commits_behind": "<integer-or-string-unknown>",
     "update_source": "git|npm|homebrew|none",
     "upstream_path": "<absolute-path-or-empty>",
     "versions_behind": "<integer>",
     "rendered_line": "<exact-string-rendered-by-tui-or-empty>"
   }
   ```

   The `rendered_line` field is empty when suppression conditions fire.

   ### M029 Contract Preservation

   The three byte-stable headline lines (`line1`, `line2`, `line3`) and
   their POSIX-extended regexes in § Regex above are UNCHANGED. The
   drift line is additive: existing M029 SC-2 scrapers continue to
   pass byte-for-byte. The M035 SC-4 scraper greps for the
   `^STALE: orchestrator runtime is .*$` pattern below the embedded
   footer line.

   ### Drift Line Regex

       drift-line: ^STALE: orchestrator runtime is ([0-9]+|unknown) commits behind upstream — run `orchestrator:update`$
   ```

4. **Author `tools/verify/m035-p01-drift-line-in-status.sh`** (SC-4
   primary path). Stage a fixture project + fixture upstream-repo
   (mirror of T03's verifier setup), copy the SHA-bearing
   `install-meta.txt`, write `config.yml` pointing at the upstream,
   then assert:

   - `bash commands/status.md`-equivalent invocation (or
     `scripts/diagnostics/render-status-json.sh` for the JSON path)
     emits stdout containing exactly one line matching the
     documented drift-line regex.
   - Both TUI and JSON paths are exercised — TUI via the rendered
     stdout, JSON via `jq -e '.drift.rendered_line | test("STALE")'`.

   Single-script-file shape per AD-19.

5. **Author `tools/verify/m035-p01-drift-line-suppressed.sh`**
   (SC-4 suppression paths). Three sub-cases:

   a. Toggle `update_source: none` in fixture config; assert
      no `STALE:` line in either render output.
   b. Stage a fixture whose `install-meta.txt` SHA matches the
      fixture upstream's HEAD (`commits_behind=0`); assert no
      `STALE:` line.
   c. Stage a fixture whose `.orchestrator/install-meta.txt` is
      missing entirely (drift helper degrades gracefully); assert
      no `STALE:` line.

   For each sub-case, also assert that the THREE byte-stable
   headline lines are present (the M029 contract is preserved).

   Single-script-file shape per AD-19.

6. **Author `tools/verify/m035-p01-phase-suite.sh`** (the AD-19-prefixed
   phase aggregator; mirrors `tools/verify/m035-p00-phase-suite.sh` from
   M035 P00). Aggregates all P01 task-grain verifiers:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p01-phase-suite.sh — M035 P01 phase aggregator.
   # Filename embeds the m035-p01- milestone+phase prefix per AD-19
   # path discipline (the unprefixed p01-phase-suite.sh shape silently
   # clobbered prior milestones' aggregators in the M030/M031/M036
   # observed regression series, 2026-05-01).
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   suite=(
     m035-p01-mode-flag
     m035-p01-symlink-source-target
     m035-p01-mode-aware-uninstall
     m035-p01-drift-detection
     m035-p01-drift-detection-sha-absent
     m035-p01-drift-line-in-status
     m035-p01-drift-line-suppressed
   )
   pass=0; fail=0
   for v in "${suite[@]}"; do
     if bash "$REPO_ROOT/tools/verify/${v}.sh" >/dev/null 2>&1; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $v" >&2
     fi
   done
   echo "BATTERY: pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   The naming convention (milestone+phase prefix) is mandatory per
   AD-19 / commands/plan-phase.md "Naming convention" rule —
   `tools/verify/p01-phase-suite.sh` would silently clobber every
   prior milestone's P01 aggregator.

## Must-Haves

- Drift line renders against SC-3 fixture (TUI + JSON)
  - Check: `bash tools/verify/m035-p01-drift-line-in-status.sh`
- Drift line suppressed under `update_source=none` / no-drift / unavailable
  - Check: `bash tools/verify/m035-p01-drift-line-suppressed.sh`

## Verification

```bash
bash tools/verify/m035-p01-drift-line-in-status.sh
bash tools/verify/m035-p01-drift-line-suppressed.sh
bash tools/verify/m035-p01-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/state/check-orchestrator-drift.sh` (from T03)
  - Key API: `bash scripts/state/check-orchestrator-drift.sh --consumer <path>`; emits a four-line key=value block on stdout (`commits_behind=`, `update_source=`, `upstream_path=`, `versions_behind=`); exit 0 always.
  - Stderr: optional one-line advisory under SHA-absent fallback.
- T03's verifier upstream-fixture pattern (referenced for SC-4 verifier scaffolding).

### From Disk (Pre-existing)

- `commands/status.md` — render path; T04 appends one block (the drift-line render step) between the embedded-footer block and the flat-sections-invariant block.
- `scripts/diagnostics/render-status-json.sh` — JSON renderer; T04 adds the `drift` top-level field. The schema_version constant `_M029_SCHEMA_VERSION` stays at `"1.0"` (additive change per AD-7 policy).
- `references/status-headline-shape.md` — M029 contract; T04 appends § Drift Line (M035 P01) below the existing § CON-5 Suppression Matrix.
- `references/status-json-schema.md` — JSON schema doc (M029); T04 also appends the `drift` field documentation here so the cross-check verifier (which asserts the two files agree) stays green.

## Constraints

- **M029 SC-2 preservation**: the three byte-stable headline lines
  and their regex contract at `references/status-headline-shape.md`
  § Regex are UNCHANGED. M029 acceptance battery stays green.
- **AD-7 schema-version policy**: additive `drift` field does NOT
  bump `_M029_SCHEMA_VERSION`. The M029 cross-check verifier that
  asserts `schema_version == "1.0"` byte-for-byte stays green.
- **FR-15 (read-only)**: T04 reads from `check-orchestrator-drift.sh`
  and renders. No state writes.
- **FR-16 (suppression)**: rendered-line suppression honors
  `update_source: none` + `commits_behind=0` + helper-unavailable.
- **AD-19 path discipline**: phase-suite aggregator filename
  embeds the `m035-p01-` milestone+phase prefix.

## Notes

- Expected verifier outputs:
  - `PASS: m035-p01-drift-line-in-status`
  - `PASS: m035-p01-drift-line-suppressed`
  - `BATTERY: pass=7 fail=0` from the phase-suite aggregator.
- **Plan-phase verifier-availability cross-check (rule 2)**: every
  verifier referenced in T04's `## Verification` section is authored
  in this task (steps 4-6).
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  proposed `Check:` command is a single-script-file invocation. The
  internal verifier bodies use `case`, `[ ... ] && [ ... ]` two-token
  pairs (below the AP-009 compound-chain-gt2 threshold), and `jq -e`
  invocations — all below the shape-guard threshold.
- **Plan-phase real-DB rule (rule 5)**: not applicable — no SQL
  surface in P01.
- **CON-3 / shape-guard interaction in verifier bodies**: any time
  the verifier needs to chain `cmd1 && cmd2 && cmd3` it should
  refactor to a `case` block or sequential statements separated by
  newlines, not a 3+ inline `&&` chain. This is the same discipline
  the M035 P00 verifiers follow.

## Expected Output

After T04 completes:

- `commands/status.md` carries the drift-line render step between
  the embedded footer step and the flat-sections-invariant block.
- `scripts/diagnostics/render-status-json.sh` emits the `drift`
  top-level field; `_M029_SCHEMA_VERSION="1.0"` unchanged.
- `references/status-headline-shape.md` carries § Drift Line (M035 P01).
- `references/status-json-schema.md` documents the `drift` field.
- Three new verifiers exist (`m035-p01-drift-line-in-status.sh`,
  `m035-p01-drift-line-suppressed.sh`, `m035-p01-phase-suite.sh`)
  and PASS against the new state.
- Phase-suite aggregator emits `BATTERY: pass=7 fail=0` covering
  every P01 task-grain verifier.
