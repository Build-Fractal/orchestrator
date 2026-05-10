---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M035"
name: "`update_source` config schema — `read-config.sh` VALID_KEYS registration + D012 schema decision"
depends_on: []
---

## Prerequisites

- **`scripts/state/read-config.sh`** exists with `VALID_KEYS` defined as
  a single space-separated string at line 17. T01 reads this file and
  appends `update_source` to the canonical list. Confirmed present at
  plan-authoring time.
- **`.orchestrator/config.yml`** exists at the repo root. T01 does NOT
  modify the file directly — the schema is registered in `read-config.sh`
  so consumers (T02 dispatch, T03 emission) can read `update_source`
  via the existing read pipeline. Confirmed present.
- **[`.orchestrator/DECISIONS.md`](../../../../../decisions.md)** exists. T01 appends D012 in the
  prevailing row format (read the file at execution time to confirm
  whether to use the literal `### D012 — <decision>` heading-shape
  precedented by P03 D007/D008 / P04 D009/D010/D011, or the
  table-row shape — execute to read, mirror).
- **`scripts/lib/errors.sh`** exists and exports `emit_result()` for
  PASS/FAIL line emission. T01 verifier sources this for consistent
  output shape.
- No `tools/verify/m035-p06-config-schema-shape.sh` exists at
  plan-authoring time (Plan-Time Discipline Rule 6 — path-collision
  check confirmed absent).

## Description

T01 ships the schema registration that lets every downstream consumer
(`run-update.sh` in T02, JSONL emission in T03, doc in T04) read
`update_source` via the existing `read-config.sh` pipeline rather than
each ad-hoc-grepping `config.yml`. Schema enumeration is
`update_source: git|npm|homebrew|none` per spec FR-13 + #Q-5 resolution
recorded as D012 in the phase plan.

Two surfaces:

1. **Schema registration** — `update_source` joins the canonical
   `VALID_KEYS` list at `scripts/state/read-config.sh:17`. Position is
   end-of-list (after `display_thresholds.compression_savings_pct`),
   per the [M027](../../../../../milestones/M027/index.md) P02/P03 multi-key co-location pattern. The append is a
   single-line edit; it does not change the read-config.sh CLI shape.

2. **D012 decision row** — appended to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)
   recording the schema decision verbatim. The body cites FR-13 + #Q-5
   + AD-5 binding so future readers don't have to re-derive the
   reasoning.

The schema does NOT carry implicit defaults. When `update_source` is
absent from `config.yml`, `read-config.sh` returns the literal string
`null` (existing M027 P03/T01 null-sentinel pattern). T02's dispatch
treats `null` and empty as "use AD-5 detection." Invalid values (any
string outside `git|npm|homebrew|none`) surface a stderr advisory but
do not abort the read — T02 handles the unknown-source FAIL branch.

## Steps

1. **Read `scripts/state/read-config.sh`** to confirm the exact
   `VALID_KEYS` line shape (line 17). The current value (per
   plan-authoring snapshot) is:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled compression.efficiency_footer.enabled compression.regression_floor model_routing_regression.pass_rate_threshold model_routing_regression.min_class_sample display_thresholds.compression_savings_pct"
   ```

   Append ` update_source` (single space-prefix) to the END of this
   string before the closing quote. The new value:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled compression.efficiency_footer.enabled compression.regression_floor model_routing_regression.pass_rate_threshold model_routing_regression.min_class_sample display_thresholds.compression_savings_pct update_source"
   ```

   No other edits to `read-config.sh` (the value-validation enumeration
   for `update_source` is enforced by T02's dispatch, NOT by
   `read-config.sh` — read-config.sh is intentionally schema-agnostic
   on values; it only validates keys per its existing M027 contract).

2. **Append D012 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)**. Read the file at
   execution time to determine the prevailing row format (table-row
   shape as used by D001..D006 / [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }"), OR the literal
   `### D### — <title>` heading-shape used by P03 D007/D008 / P04
   D009/D010/D011). Mirror whichever shape the immediately preceding
   D-row uses for consistency. The decision body verbatim:

   ```
   D012 — update_source config schema (M035 P06)

   `.orchestrator/config.yml` accepts a top-level scalar key
   `update_source: git|npm|homebrew|none`. Default behavior when the
   key is absent: AD-5 detect-by-install-method-first (read
   install-meta.txt provenance + npm/brew/curl signals; first match
   wins; persist resolved source back to config). The literal value
   `none` is the operator opt-out: when set, both
   `orchestrator:update` dispatch and the FR-4 drift-render path
   suppress silently — no dispatch, no JSONL emission, no warning.

   Curl-pipe-bash users whose install resolved through `install.sh`
   are detected as `npm` (because curl-pipe-bash extracts the npm
   tarball — D007/D009 single-source-of-truth) and persist as `npm`
   for future runs. This narrows the schema enumeration to the
   spec-FR-13 literal three-channel contract without losing channel
   coverage.

   Bound by FR-13 + FR-16 + SC-13 + AD-5 + #Q-5.
   ```

   The actual row format depends on the prevailing convention; the
   substance above maps to whichever row template is in use.

3. **Author the verifier**
   `tools/verify/m035-p06-config-schema-shape.sh`. Single-script-file
   shape, AD-19, ~50 lines. Sources `scripts/lib/errors.sh` for
   `emit_result`. Asserts:

   1. `scripts/state/read-config.sh` is readable.
   2. `grep -qE 'update_source' scripts/state/read-config.sh` succeeds
      (the key is registered).
   3. The `VALID_KEYS` line includes `update_source` as a
      whitespace-separated token (regex needle:
      `(^|[[:space:]])update_source([[:space:]]|"$)`).
   4. [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) contains the literal token `D012`
      (case-sensitive grep -F).
   5. [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) contains the literal token
      `update_source` in proximity to D012 (within 30 lines of the
      D012 anchor — sed-extract block then grep).
   6. Stage a temp fixture under `/tmp/m035-p06-t01-config-fixture-$$/`
      (mktemp), write a minimal `.orchestrator/config.yml` containing
      `update_source: npm`, invoke
      `bash scripts/state/read-config.sh --root <fixture> update_source`
      (or whatever the canonical CLI shape is; read read-config.sh
      `--help` to confirm), and assert stdout contains `npm`.
   7. Same fixture but with `update_source: invalid_value`; assert
      `read-config.sh` returns the literal value (no client-side
      enumeration validation) and emits no error — the
      enumeration-enforcement is T02's job.
   8. Same fixture but with `update_source` absent from config.yml;
      assert `read-config.sh` returns either empty or `null`
      (preserving the null-sentinel pattern).

   Emit `BATTERY: pass=N fail=0` summary. Cleanup fixture on exit
   trap.

   The verifier MUST honor AD-19 single-script-file shape — no
   `$(... | ...)`, no plain subshells, no compound chains. Use
   intermediate variables and `if` blocks for compound logic.

## Must-Haves

- `scripts/state/read-config.sh` modified — `VALID_KEYS` includes
  `update_source` as a whitespace-separated token.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified — contains a `D012` row
  referencing M035/P06 + `update_source` + the four-value enumeration.
- `tools/verify/m035-p06-config-schema-shape.sh` exists, executable,
  ~50+ lines, contains `BATTERY:`, runs against staged fixtures,
  emits `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p06-config-schema-shape.sh
```

## Inputs

### From Previous Tasks

None — T01 is a leaf task within P06 with no upstream P06 dependencies.

### From Disk (Pre-existing)

- `scripts/state/read-config.sh` (line 17 holds `VALID_KEYS`) — T01
  appends `update_source` to the end of the space-separated list.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — T01 appends D012; row format mirrors
  the immediately preceding D-row (D004/D005/D006/D007/D008/D009/D010/
  D011 — read at execution time to confirm).
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`,
  `RESULT_OK`, `RESULT_FAIL`. Used by the verifier.
- `scripts/util/run-probe.sh` — staged-throwaway-probe wrapper. T01
  verifier does NOT use this directly (verifiers are repo-resident;
  AD-19 says invoke `bash <path>` directly).

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p06-*.sh`. No inline compound chains; no
  `$(... | ...)`; no plain subshells.
- **Bash 3.2 + POSIX-sh in the verifier** — CON-2/CON-7. Must run on
  macOS bash 3.2 unmodified.
- **FR-16 (no new suppression knob)** — T01 introduces no new
  suppression knob. The schema additions inherit the existing M025/
  M027 conventions for config-key behavior.
- **CON-7 / M027 alignment** — `update_source` joins the canonical
  `VALID_KEYS` list using the existing append discipline (single-line
  edit, end-of-list position) rather than introducing a new schema
  surface.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against `tools/verify/m035-p06-config-schema-shape.sh`;
  ABSENT. New file carries the `m035-p06-` slug per the
  milestone-prefix convention.

## Expected Output

Stdout from `bash tools/verify/m035-p06-config-schema-shape.sh`:

```
PASS: read-config.sh registers update_source in VALID_KEYS
PASS: VALID_KEYS line contains update_source as whitespace-separated token
PASS: DECISIONS.md contains D012 anchor
PASS: DECISIONS.md D012 row references update_source
PASS: read-config.sh returns 'npm' for fixture with update_source: npm
PASS: read-config.sh returns invalid_value verbatim (no client-side enum check)
PASS: read-config.sh returns null/empty for fixture with update_source absent
BATTERY: pass=7 fail=0
```
