---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M024"
name: "Wire classifier + degradation into proposal-emit.sh and approval-gate.sh; add transient pending key"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `scripts/intake/design-gate-classify.sh` exists and is executable; emits `design_gate=<none|walkthrough>` + `design_gate_confidence=<low|high>` to stdout.
- T02 complete: `scripts/intake/design-gate-degradation.sh` exists and is executable; supports probe-only mode (`--probe-only`) and branch mode (`--branch manual|skip`); emits the FR-7 pinned message on probe-fail for walkthrough proposals.
- P03 complete: `scripts/intake/approval-gate.sh` already implements `approve | cancel | revise` verbs with idempotency guards and BSD/GNU-portable `sed -i.bak` frontmatter mutation.
- P06 complete: `scripts/intake/proposal-emit.sh` already implements the `--axes-from` flag, the `*_revise` namespace, the `REVISE_AXES_DONE` flag, and the PARA/SPEC/QA axes-done flag pattern. T03 mirrors that pattern with `DESIGN_AXES_DONE`.

## Description

Three artifacts modified, no new scripts authored:

1. **`scripts/intake/proposal-emit.sh`** — wire the design-gate classifier alongside the existing paragraph and spec deep classifiers; add a `DESIGN_AXES_DONE=1` flag mirroring `PARA_AXES_DONE` / `SPEC_AXES_DONE` / `QA_AXES_DONE` so the rationale loop skips the design slot when the classifier ran. Add the recommended_command guard: invoke `design-gate-degradation.sh --probe-only` after axes are resolved; when probe fails AND `design_gate=walkthrough`, force the recommended_command to the tier-derived fallback rather than `orchestrator:design`.

2. **`scripts/intake/approval-gate.sh`** — extend the verb table with `manual` and `skip`. Both verbs delegate to `scripts/intake/design-gate-degradation.sh --branch <verb>` and forward stdout. Pre-validation: proposal must carry `design_gate: "walkthrough"` AND M023 probe must fail; either condition violated → exit 2 with actionable error.

3. **`templates/intake-proposal.md`** — add the new transient frontmatter key `pending_design_authored_manually: false` (P07-introduced; D024 / MEM031 schema-authority handshake honored — the [M020](../../../../milestones/M020/index.md) D-row entry is appended in T04). The key is initially `false` on every fresh emit; the manual-branch first-invoke flips it to `true`; the manual-branch follow-up flips it back to `false`. Tracked transient state ONLY — never carries semantic value beyond "operator is in the middle of authoring DESIGN.md."

## Steps

### Step 1 — Add the transient template key

Edit `templates/intake-proposal.md` frontmatter block. Locate the existing line:

```
design_authored_manually: {{design_authored_manually}}
```

Insert immediately after it:

```
pending_design_authored_manually: {{pending_design_authored_manually}}
```

The manifest-superset assertion (`tests/test-intake-manifest-superset.sh`) reads its keys from `tests/fixtures/m014-interim-manifest-keys.txt`. Adding a P07-only key to the intake template that is not in the [M014](../../../../milestones/M014/index.md) manifest is fine — the contract is M024 ⊇ M014, not equality. The P01 frontmatter-completeness assertion (`tests/test-intake-proposal-shape.sh`) will need an updated allowed-keys list; that update lives in T04 alongside the schema D-row.

### Step 2 — Wire the classifier and probe into `proposal-emit.sh`

Locate the existing paragraph branch override block (around lines 183–196):

```bash
# Apply paragraph-classifier overrides (P03).
[ -n "${scope_tier_override:-}" ]          && scope_tier="$scope_tier_override"
[ -n "${decomposition_override:-}" ]       && decomposition="$decomposition_override"
[ -n "${recommended_command_override:-}" ] && recommended_command="$recommended_command_override"

# (M024/P06/T02) Apply axes-from revise overrides LAST so operator revisions
# beat deep-classifier output. The revise_* namespace is populated by the
# --axes-from parser at the top of this script.
[ -n "${scope_tier_revise:-}" ]          && scope_tier="$scope_tier_revise"
[ -n "${decomposition_revise:-}" ]       && decomposition="$decomposition_revise"
[ -n "${recommended_command_revise:-}" ] && recommended_command="$recommended_command_revise"
[ -n "${design_gate_revise:-}" ]         && design_gate="$design_gate_revise"
[ -n "${conversus_gate_revise:-}" ]      && conversus_gate="$conversus_gate_revise"
[ -n "${intensity_revise:-}" ]           && intensity="$intensity_revise"
```

Insert immediately AFTER this block (before the `# (6) Frontmatter dynamic values.` line):

```bash
# (5b) M024/P07/T03 — Design-gate deep classifier wired in alongside paragraph/spec branches.
# Skip when design_gate was already overridden by --axes-from (revise flow) or by the spec
# branch — REVISE wins highest precedence; the classifier only fills the P01 stub.
DESIGN_CLF="$ROOT/scripts/intake/design-gate-classify.sh"
design_gate_confidence="high"
if [ -z "${design_gate_revise:-}" ] && [ -x "$DESIGN_CLF" ]; then
  if [ -n "$INPUT" ]; then
    dg_out=$(bash "$DESIGN_CLF" --input "$INPUT" 2>/dev/null || echo "")
  elif [ -n "$SPEC_PATH" ]; then
    dg_out=$(bash "$DESIGN_CLF" --spec-path "$SPEC_PATH" 2>/dev/null || echo "")
  else
    dg_out=""
  fi
  dg_value=$(echo "$dg_out" | sed -n 's/^design_gate=//p' | head -1)
  dg_conf=$(echo "$dg_out" | sed -n 's/^design_gate_confidence=//p' | head -1)
  if [ -n "$dg_value" ]; then
    design_gate="$dg_value"
    DESIGN_AXES_DONE=1
  fi
  [ -n "$dg_conf" ] && design_gate_confidence="$dg_conf"
fi

# (5c) M024/P07/T03 — recommended_command guard against orphan orchestrator:design references.
# When design_gate=walkthrough AND M023 has NOT shipped, the slot stays at the tier-derived
# fallback rather than pointing at a non-existent orchestrator:design.
if [ "$design_gate" = "walkthrough" ]; then
  DEG="$ROOT/scripts/intake/design-gate-degradation.sh"
  if [ -x "$DEG" ]; then
    # Probe-only mode requires a proposal path argument; we don't have one yet (the proposal
    # has not been written). Inline the probe shape: env-override first, then disk probe.
    m023_shipped="false"
    case "${M023_SHIPPED_PROBE_OVERRIDE:-}" in
      live) m023_shipped="true" ;;
      stub|"") ;;
    esac
    if [ "$m023_shipped" = "false" ] && [ -z "${M023_SHIPPED_PROBE_OVERRIDE:-}" ]; then
      if [ -f "$ROOT/commands/design.md" ] && grep -qE '^Pass\.[0-9]+' "$ROOT/commands/design.md"; then
        m023_shipped="true"
      fi
    fi
    if [ "$m023_shipped" = "false" ]; then
      # Force tier-derived fallback. Do NOT let any upstream override pin orchestrator:design.
      case "$scope_tier" in
        A) recommended_command="orchestrator:dispatch" ;;
        B|C) recommended_command="orchestrator:specify" ;;
      esac
    fi
  fi
fi
```

Then locate the existing rationale-loop block (around lines 404+):

```bash
for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  # (M024/P06/T03) REVISE_AXES_DONE wins highest precedence — operator-driven
  # axes-from override places a placeholder; revise.sh post-processes to a
  # version-pointer rationale ("see proposal-v<N>.md") after the emitter returns.
  # This must run BEFORE the PARA/SPEC/QA gates so revised axes are not pinned
  # to deep-classifier rationale text from the same-input re-emit.
```

Inside that loop body, after the existing PARA/SPEC/QA skip-flag conditions, ADD a `DESIGN_AXES_DONE` check that skips the design_gate rationale slot when the classifier ran (the classifier sets the value but does not synthesize a rationale; the emitter writes a small canned rationale citing the classifier). Use the same shape as the existing skip flags. Specifically, ensure that when `axis = "design_gate"` AND `DESIGN_AXES_DONE=1`, the rationale slot is set to a canned string:

```
Operator input scanned for design-domain tokens (ui, render, design, layout, ...). Confidence: <high|low>.
```

with evidence:

```
scripts/intake/design-gate-classify.sh
```

Implementation form (insert in the rationale loop, BEFORE the existing P01-stub fallback):

```bash
  # M024/P07/T03 — design-gate deep-classifier rationale.
  if [ "$axis" = "design_gate" ] && [ "${DESIGN_AXES_DONE:-0}" = "1" ]; then
    swap "rationale_design_gate" "Operator input scanned for design-domain tokens (ui, render, design, layout, screen, view, panel, viewer, dashboard, interface, visual, theme); whole-word match. Confidence: $design_gate_confidence."
    swap "evidence_design_gate"  "scripts/intake/design-gate-classify.sh"
    continue
  fi
```

Initialize the new transient frontmatter slot just before the rendering block (alongside `design_skipped="false"` and `design_authored_manually="false"` at lines 233–234):

```bash
pending_design_authored_manually="false"
```

And add a corresponding `swap` line in the swap block (after `swap design_authored_manually "$design_authored_manually"` at line 338):

```bash
swap pending_design_authored_manually "$pending_design_authored_manually"
```

### Step 3 — Add `manual` and `skip` verbs to `approval-gate.sh`

Locate the existing verb dispatch (around the `case "$VERB" in` block — exact line numbers depend on P06/T03 edits, but the structure is the standard `approve|cancel|revise|...)` case). Add two new arms BEFORE the catch-all `*)` arm:

```bash
  manual|skip)
    # M024/P07/T03 — pre-M023 design-gate degradation verbs.
    # Validate proposal carries design_gate: "walkthrough".
    dg=$(sed -n 's/^design_gate: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
    if [ "$dg" != "walkthrough" ]; then
      echo "ERR: '$VERB' verb requires design_gate=walkthrough on a pre-M023 checkout (got: design_gate=$dg)" >&2
      exit 2
    fi
    # Delegate to the degradation script (it runs the M023 probe and emits the FR-7 pinned
    # message on stderr; we forward stdout/stderr verbatim).
    DEG="$ROOT/scripts/intake/design-gate-degradation.sh"
    if [ ! -x "$DEG" ]; then
      echo "ERR: $DEG not executable — required for manual/skip verbs" >&2
      exit 1
    fi
    bash "$DEG" --proposal "$PROPOSAL" --branch "$VERB"
    exit $?
    ;;
```

(The exact `ROOT` resolution and `PROPOSAL` variable names should match the existing approval-gate.sh idiom; the diff above is sketch shape.)

### Step 4 — Author the three new verify scripts

#### a. `scripts/verify/m024-p07-skip-branch.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-skip-branch.sh
# Asserts the skip branch flips design_skipped=true, pending_approval=false, proceeded_at set.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Sanity: classifier should have flipped design_gate to walkthrough.
grep -q '^design_gate: "walkthrough"' "$proposal" || { echo "FAIL: classifier did not flip design_gate to walkthrough"; exit 1; }

# Run skip branch under stub probe.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip >/dev/null 2>&1 \
  || { echo "FAIL: skip branch exited non-zero"; exit 1; }

# Assert frontmatter mutations.
grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: design_skipped not flipped to true"; exit 1; }
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped to false"; exit 1; }
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$proposal" || { echo "FAIL: proceeded_at not set to ISO8601"; exit 1; }

echo "PASS: skip-branch — design_skipped=true, pending_approval=false, proceeded_at set"
exit 0
```

#### b. `scripts/verify/m024-p07-manual-branch.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-manual-branch.sh
# Asserts the manual branch halts on first invoke, proceeds on follow-up after DESIGN.md exists.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# First invoke — halt expected.
out1=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out1" | grep -q '^branch=manual halt=true' || { echo "FAIL: first invoke should halt (got: $out1)"; exit 1; }
design_md=$(echo "$out1" | sed -n 's/^.*design_md_path=//p' | head -1)
[ -n "$design_md" ] || { echo "FAIL: first invoke did not emit design_md_path"; exit 1; }
grep -q '^pending_design_authored_manually: true' "$proposal" || { echo "FAIL: pending flag not set"; exit 1; }

# Follow-up before DESIGN.md exists — still halt (idempotent).
out2=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out2" | grep -q '^branch=manual halt=true' || { echo "FAIL: idempotent follow-up should still halt (got: $out2)"; exit 1; }

# Author the DESIGN.md and re-invoke.
mkdir -p "$(dirname "$design_md")"
echo "# DESIGN.md (synthetic)" > "$design_md"
out3=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out3" | grep -q '^branch=manual halt=false' || { echo "FAIL: post-DESIGN.md follow-up should not halt (got: $out3)"; exit 1; }
grep -q '^design_authored_manually: true' "$proposal" || { echo "FAIL: design_authored_manually not flipped"; exit 1; }
grep -q '^pending_design_authored_manually: false' "$proposal" || { echo "FAIL: pending flag not flipped back"; exit 1; }
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset to true"; exit 1; }

echo "PASS: manual-branch — halt+idempotent first invoke; flip on follow-up after DESIGN.md authored"
exit 0
```

#### c. `scripts/verify/m024-p07-approval-gate-design-verbs.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-approval-gate-design-verbs.sh
# Asserts approval-gate's manual/skip verbs are wired and validated.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')

# Verb=skip on walkthrough proposal under stub probe -> exits 0, mutates design_skipped.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb skip >/dev/null 2>&1 \
  || { echo "FAIL: skip verb on walkthrough proposal exited non-zero"; exit 1; }
grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: skip verb did not mutate design_skipped"; exit 1; }

# Re-emit a fresh proposal with non-walkthrough design_gate.
tmp2="$(mktemp -d)"
out=$(bash "$EMIT" --input "fix typo in commands/status.md" --intake-root "$tmp2/intake")
proposal2=$(echo "$out" | sed -n 's/^proposal_path=//p')
grep -q '^design_gate: "none"' "$proposal2" || { echo "FAIL: non-UI input did not yield design_gate=none"; exit 1; }

# Verb=skip on non-walkthrough proposal -> exit 2.
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal2" --verb skip >/dev/null 2>&1; then
  echo "FAIL: skip verb on non-walkthrough proposal should exit 2"
  exit 1
fi

# Verb=manual on walkthrough proposal under live probe -> exit 2 (M023 shipped).
tmp3="$(mktemp -d)"
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp3/intake")
proposal3=$(echo "$out" | sed -n 's/^proposal_path=//p')
if M023_SHIPPED_PROBE_OVERRIDE=live bash "$GATE" --proposal "$proposal3" --verb manual >/dev/null 2>&1; then
  echo "FAIL: manual verb under live probe should exit 2"
  exit 1
fi

rm -rf "$tmp2" "$tmp3"
echo "PASS: approval-gate-design-verbs — skip+manual wired; validation rejects non-walkthrough + post-M023"
exit 0
```

5. **Make verify scripts executable**: `chmod +x scripts/verify/m024-p07-skip-branch.sh scripts/verify/m024-p07-manual-branch.sh scripts/verify/m024-p07-approval-gate-design-verbs.sh`.

## Must-Haves

- `scripts/intake/proposal-emit.sh` invokes `scripts/intake/design-gate-classify.sh` in both `--input` and `--spec-path` modes, after PARA/SPEC overrides but before the rendering block.
- `DESIGN_AXES_DONE=1` is set when the classifier successfully emits a verdict; the rationale loop honors it (skips the P01 stub for the design_gate slot).
- The recommended_command guard runs after axis resolution: when `design_gate=walkthrough` AND M023 probe fails, the slot is forced to the tier-derived fallback (`orchestrator:dispatch` for Tier A, `orchestrator:specify` for Tier B/C) — never `orchestrator:design`.
- `templates/intake-proposal.md` carries the new `pending_design_authored_manually: {{pending_design_authored_manually}}` line in the frontmatter block.
- `proposal-emit.sh` initializes `pending_design_authored_manually="false"` and includes a corresponding `swap` line.
- `scripts/intake/approval-gate.sh` accepts `manual` and `skip` verbs; both validate `design_gate=walkthrough` (exit 2 otherwise); both delegate to `design-gate-degradation.sh --branch <verb>`.
- A non-walkthrough proposal subjected to `--verb skip` or `--verb manual` exits 2 with the actionable error.
- A walkthrough proposal under a live M023 probe (`M023_SHIPPED_PROBE_OVERRIDE=live`) subjected to `--verb manual` or `--verb skip` exits 2 (manual/skip are pre-M023-only — operator should use `approve` to invoke `orchestrator:design` post-M023).
- All P07-introduced edits respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal mutations) and `/tmp` (test scratch).
- AD-19 single-script-file shape preserved across the verify scripts.
- Bash 3.2 portable.

## Verification

```
bash scripts/verify/m024-p07-skip-branch.sh
bash scripts/verify/m024-p07-manual-branch.sh
bash scripts/verify/m024-p07-approval-gate-design-verbs.sh
bash scripts/verify/m024-p07-design-gate-classify.sh
bash scripts/verify/m024-p07-degradation-script.sh
bash scripts/verify/m024-p07-pinned-message.sh
bash scripts/verify/m024-p07-m023-probe.sh
```

Expected output (each exits 0): a single `PASS:` line per script.

## Inputs

### From Previous Tasks

- **T01** (`scripts/intake/design-gate-classify.sh`): pure decision emitter consumed by proposal-emit.sh's classifier wiring. API: `bash design-gate-classify.sh (--input <text>|--spec-path <path>)` → stdout `design_gate=<none|walkthrough>` + `design_gate_confidence=<low|high>`. Exit 0 on success, 1 on missing spec, 2 on usage.
- **T02** (`scripts/intake/design-gate-degradation.sh`): probe + branch dispatcher consumed by approval-gate.sh's manual/skip verbs and by proposal-emit.sh's recommended_command guard. API:
  - Probe-only mode: `bash design-gate-degradation.sh --proposal <path> --probe-only` → stdout `m023_shipped=<bool>` + `reason=<env-override|disk-probe|disk-probe-failed>` + `recommended_command=<v>`.
  - Branch mode: `bash design-gate-degradation.sh --proposal <path> --branch <manual|skip>` → emits FR-7 pinned message to stderr, mutates frontmatter, emits `branch=<v>` summary to stdout. Exit 0 on success, 2 on validation failure (non-walkthrough or post-M023).
  - Env: `M023_SHIPPED_PROBE_OVERRIDE=stub|live` (test-only escape).

### From Disk (Pre-existing)

- `scripts/intake/proposal-emit.sh` — modified in this task. Existing structure: `--input`/`--spec-path`/`--axes-from` argument parsing → axis stub init → P03/P05/P06 deep-classifier overrides → frontmatter mutation block → template render via `swap` helper → rationale loop. T03 inserts the design-gate classifier wiring at the post-override / pre-render boundary.
- `scripts/intake/approval-gate.sh` — modified in this task. Existing verb dispatch handles `approve | cancel | revise`; T03 adds `manual | skip` arms before the catch-all.
- `templates/intake-proposal.md` — modified in this task. Existing frontmatter block has 25 keys; T03 adds 1 (`pending_design_authored_manually`).
- POSIX utilities: `sed -i.bak`, `grep`, `head`, `awk`, `mktemp`, `trap`, `chmod`, `cat`.

## Constraints

- POSIX sh + bash 3.2 portable.
- No new scripts authored in this task — three modifications + three verify scripts.
- AD-19 single-script-file shape across the verify scripts.
- The recommended_command guard must NOT introduce a new dispatch pattern — it reuses the existing tier→command mapping established in P01.
- The `manual`/`skip` verbs must NOT bypass the existing approval-gate idempotency guard — a proposal already finalized via `approve` or `cancel` must reject `manual`/`skip` cleanly.
- Frontmatter writes confined to the named `--proposal <path>` (SB-3).
- The new `pending_design_authored_manually` template key is initialized to `"false"` on every fresh emit; the manual-branch handler is the only mutator.

## Expected Output

`scripts/intake/proposal-emit.sh`, `scripts/intake/approval-gate.sh`, and `templates/intake-proposal.md` are modified to wire the design-gate classifier + degradation; three verify scripts pass.
