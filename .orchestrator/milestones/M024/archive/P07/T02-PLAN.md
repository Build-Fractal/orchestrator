---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M024"
name: "Design-gate degradation — invoke-time M023 probe + FR-7 pinned message + manual/skip branches"
depends_on: []
---

## Prerequisites

- P01 complete: `templates/intake-proposal.md` defines `design_gate`, `design_skipped`, `design_authored_manually` frontmatter keys; `scripts/intake/proposal-emit.sh` exists and renders the template.
- P03 complete: `scripts/intake/route-to-specify.sh` establishes the invoke-time probe pattern — re-run probe at every invocation, never trust plan-phase-time check (#DQ-2 option `b`). T02 mirrors this pattern for the M023 probe. Also establishes the in-place frontmatter mutation idiom via `sed -i.bak` (BSD/GNU portable).
- P06 complete: `scripts/intake/revise.sh` already preserves a revised `design_gate=walkthrough` value through re-emit; T02 does not need to coordinate with revise.sh.

T02 is independent of T01 — both produce pure leaf scripts. T03 will wire both into proposal-emit.sh and approval-gate.sh.

## Description

Author `scripts/intake/design-gate-degradation.sh` — invoke-time M023-shipping probe, FR-7 byte-pinned message emission, and manual/skip branch handlers. The script has two orthogonal modes:

- **Probe-only mode** (no `--branch`, optionally `--probe-only`): runs the M023 probe and emits to stdout. Used by `proposal-emit.sh` (T03) at emit time to decide the `recommended_command` slot — when M023 has shipped, the slot points at `orchestrator:design`; when it has not, the slot stays at the tier-derived fallback. Pure stdout emitter; no proposal mutation.

- **Branch mode** (`--branch manual|skip`): runs the probe; on probe-pass, exits 2 with `ERR: M023 has shipped — manual/skip branches are pre-M023-only`. On probe-fail for a `design_gate=walkthrough` proposal, emits the FR-7 pinned message to stderr AND dispatches the named branch handler (frontmatter mutation + stdout summary). On probe-fail for a non-walkthrough proposal, exits 2 with `ERR: 'manual'/'skip' verb requires design_gate=walkthrough on a pre-M023 checkout`.

### M023-shipping probe

Probe order (highest precedence first):

1. `M023_SHIPPED_PROBE_OVERRIDE=stub` → probe returns `m023_shipped=false reason=env-override`. Test-only escape so a future post-M023 checkout can still exercise the pre-M023 branches under regression tests. Closed enum: `stub | live | <unset>`.
2. `M023_SHIPPED_PROBE_OVERRIDE=live` → probe returns `m023_shipped=true reason=env-override`. Test-only affirmative — tests can mock M023 having shipped on a current checkout to exercise the post-M023 path.
3. Real-disk probe — checks `commands/design.md` exists AND its content contains a `Pass.<N>` marker (mirrors P03/T03's M014 probe pattern: `grep -E '^Pass\.[0-9]+' commands/design.md`). On both checks pass → `m023_shipped=true reason=disk-probe`. On either fail → `m023_shipped=false reason=disk-probe-failed`.

The probe is read-only and side-effect-free. No subprocess calls beyond `test -f` and `grep -E`.

### FR-7 byte-pinned message

The exact string emitted to stderr (and recorded into the proposal body when applicable):

```
design walkthrough lands in M023; author DESIGN.md manually or skip
```

No leading/trailing whitespace. No surrounding markdown. No variant punctuation. Pinned across the three sites (this script, `commands/evaluate.md`, `scripts/verify/m024-p07-pinned-message.sh`). SC-5 verifies via `grep -F`.

### Skip branch handler

On `--branch skip`:

1. Validate the proposal carries `design_gate: "walkthrough"` (else exit 2 with the validation error).
2. Validate the M023 probe currently fails (else exit 2 — skip is pre-M023-only).
3. Mutate frontmatter via `sed -i.bak`:
   - `design_skipped: true` (was `false`)
   - `pending_approval: false` (was `true` or already `false`)
   - `proceeded_at: "<ISO8601>"` (was `null`)
4. Emit stdout: `branch=skip design_skipped=true proposal=<path>`. Exit 0.

### Manual branch handler

On `--branch manual`, two sub-cases distinguished by frontmatter state:

**First invocation** (`pending_design_authored_manually: false` AND `design_authored_manually: false`):

1. Validate as above.
2. Compute the expected DESIGN.md path: `<spec-dir>/DESIGN.md` where `<spec-dir>` is `specs/<feature_slug>/` if `feature_slug` is non-null AND that directory exists; otherwise `<intake-dir>/DESIGN.md` (the proposal's own directory).
3. Mutate frontmatter:
   - `pending_design_authored_manually: true` (the new P07-introduced transient flag — added in T03's template edit).
4. Emit stdout: `branch=manual halt=true design_authored_manually=false design_md_path=<absolute-expected-path>`. Exit 0. The script does NOT block waiting for the operator; it returns immediately so the operator can author DESIGN.md and re-invoke.

**Follow-up invocation** (`pending_design_authored_manually: true`):

1. Check whether `<design_md_path>` (from the first-invocation stdout, re-derived the same way) now exists.
2. If absent → exit 0 with stdout `branch=manual halt=true design_authored_manually=false design_md_path=<path>` (idempotent — operator can re-invoke as many times as they want; the halt persists until the file exists).
3. If present → mutate frontmatter:
   - `design_authored_manually: true`
   - `pending_design_authored_manually: false`
   - `pending_approval: true` (operator must still approve before downstream runs — manual-branch does NOT auto-proceed)
4. Emit stdout: `branch=manual halt=false design_authored_manually=true design_md_path=<path>`. Exit 0.

## Steps

1. **Create the degradation script** at `scripts/intake/design-gate-degradation.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/design-gate-degradation.sh
# M024/P07/T02 — Invoke-time M023 probe + FR-7 pinned message + manual/skip branches.
#
# Modes:
#   Probe-only (no --branch):  emit m023_shipped=<bool> + recommended_command=<v> to stdout.
#   Branch mode (--branch manual|skip): emit FR-7 pinned message to stderr on probe-fail
#     for a walkthrough proposal; mutate proposal frontmatter; emit branch summary to stdout.
#
# Exit 0 on success, 1 on internal error (e.g. proposal frontmatter unreadable),
#        2 on usage error or validation failure.

set -u

# FR-7 byte-pinned message — DO NOT EDIT without updating the three pinned sites
# (this script, commands/evaluate.md, scripts/verify/m024-p07-pinned-message.sh).
FR7_MSG='design walkthrough lands in M023; author DESIGN.md manually or skip'

usage() {
  cat >&2 <<'EOF'
usage: design-gate-degradation.sh --proposal <path> [--branch manual|skip]

Probe-only mode (no --branch): emits m023_shipped=<true|false> + recommended_command=<v>.
Branch mode: requires --proposal carrying design_gate: "walkthrough" AND M023 probe failing.

  --branch skip    Records design_skipped=true; proceeds.
  --branch manual  Halts on first invocation; flips design_authored_manually=true on
                   follow-up invocation if DESIGN.md was authored at the expected path.

Env: M023_SHIPPED_PROBE_OVERRIDE=stub|live (test-only escape)
EOF
  exit 2
}

PROPOSAL=""
BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal)    PROPOSAL="$2"; shift 2 ;;
    --branch)      BRANCH="$2";   shift 2 ;;
    --probe-only)  BRANCH="";     shift ;;
    -h|--help)     usage ;;
    *)             usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Validate --branch enum.
if [ -n "$BRANCH" ]; then
  case "$BRANCH" in manual|skip) ;; *) echo "ERR: --branch must be manual|skip (got: $BRANCH)" >&2; exit 2 ;; esac
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# --- M023 probe ---
m023_probe() {
  local override="${M023_SHIPPED_PROBE_OVERRIDE:-}"
  case "$override" in
    stub) echo "m023_shipped=false"; echo "reason=env-override"; return ;;
    live) echo "m023_shipped=true";  echo "reason=env-override"; return ;;
    "")   ;;
    *)    echo "WARN: M023_SHIPPED_PROBE_OVERRIDE='$override' not in {stub,live}; falling through to disk probe" >&2 ;;
  esac
  if [ -f "$ROOT/commands/design.md" ] && grep -qE '^Pass\.[0-9]+' "$ROOT/commands/design.md"; then
    echo "m023_shipped=true"; echo "reason=disk-probe"
  else
    echo "m023_shipped=false"; echo "reason=disk-probe-failed"
  fi
}

# --- proposal frontmatter helpers ---
read_fm() {
  # read_fm <key>; emits the value (un-quoted scalars only).
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
read_fm_bool() {
  # bool keys are unquoted (true/false/null) per template.
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}
mutate_fm() {
  # mutate_fm <key> <value-with-or-without-quotes>; uses sed -i.bak then rm.
  local key="$1"; local val="$2"
  local esc
  esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^${key}: .*/${key}: ${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
}

# --- expected DESIGN.md path ---
expected_design_md_path() {
  local feature_slug
  feature_slug=$(read_fm feature_slug)
  if [ -n "$feature_slug" ] && [ "$feature_slug" != "null" ] && [ -d "$ROOT/specs/$feature_slug" ]; then
    echo "$ROOT/specs/$feature_slug/DESIGN.md"
  else
    echo "$(dirname "$PROPOSAL")/DESIGN.md"
  fi
}

# --- run probe ---
probe_out=$(m023_probe)
m023_shipped=$(echo "$probe_out" | sed -n 's/^m023_shipped=//p' | head -1)

# --- probe-only mode ---
if [ -z "$BRANCH" ]; then
  # Decide recommended_command for design-gated proposals.
  design_gate=$(read_fm design_gate)
  scope_tier=$(read_fm scope_tier)
  rec_cmd="orchestrator:dispatch"
  case "$scope_tier" in
    A) rec_cmd="orchestrator:dispatch" ;;
    B|C) rec_cmd="orchestrator:specify" ;;
  esac
  if [ "$design_gate" = "walkthrough" ] && [ "$m023_shipped" = "true" ]; then
    rec_cmd="orchestrator:design"
  fi
  echo "$probe_out"
  echo "recommended_command=$rec_cmd"
  exit 0
fi

# --- branch mode validation ---
design_gate=$(read_fm design_gate)
if [ "$design_gate" != "walkthrough" ]; then
  echo "ERR: '$BRANCH' verb requires design_gate=walkthrough on a pre-M023 checkout (got: design_gate=$design_gate)" >&2
  exit 2
fi
if [ "$m023_shipped" = "true" ]; then
  echo "ERR: M023 has shipped — manual/skip branches are pre-M023-only; use 'approve' to invoke orchestrator:design" >&2
  exit 2
fi

# --- emit pinned message to stderr ---
echo "$FR7_MSG" >&2

# --- branch dispatch ---
case "$BRANCH" in
  skip)
    mutate_fm design_skipped "true"
    mutate_fm pending_approval "false"
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    mutate_fm proceeded_at "\"$now\""
    echo "branch=skip design_skipped=true proposal=$PROPOSAL"
    exit 0
    ;;
  manual)
    pending=$(read_fm_bool pending_design_authored_manually)
    authored=$(read_fm_bool design_authored_manually)
    design_md=$(expected_design_md_path)
    # First invocation OR follow-up where DESIGN.md still missing.
    if [ "$authored" = "true" ]; then
      # Already finalized — idempotent no-op.
      echo "branch=manual halt=false design_authored_manually=true design_md_path=$design_md"
      exit 0
    fi
    if [ -f "$design_md" ]; then
      mutate_fm design_authored_manually "true"
      mutate_fm pending_design_authored_manually "false"
      mutate_fm pending_approval "true"
      echo "branch=manual halt=false design_authored_manually=true design_md_path=$design_md"
      exit 0
    fi
    if [ "$pending" != "true" ]; then
      mutate_fm pending_design_authored_manually "true"
    fi
    echo "branch=manual halt=true design_authored_manually=false design_md_path=$design_md"
    exit 0
    ;;
esac
```

2. **Make it executable**: `chmod +x scripts/intake/design-gate-degradation.sh`.

3. **Write the verify scripts**:

   a. `scripts/verify/m024-p07-degradation-script.sh` — exercises probe-only mode + branch mode validation errors.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-degradation-script.sh
# Verifies the degradation script's mode dispatch and validation.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/intake/design-gate-degradation.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Emit a baseline paragraph proposal (design_gate=none stub at P01 emit time).
out=$(bash "$EMIT" --input "fix typo in commands/status.md" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Force design_gate=walkthrough for branch tests.
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"
rm -f "$proposal.bak"
# Add the transient pending flag (P07 schema addition; T03 wires this into the template).
grep -q '^pending_design_authored_manually:' "$proposal" || echo 'pending_design_authored_manually: false' >> "$proposal"

# Probe-only mode emits m023_shipped + recommended_command.
po_out=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$po_out" | grep -qx "m023_shipped=false" || { echo "FAIL: probe-only m023_shipped=false (got: $po_out)"; exit 1; }
echo "$po_out" | grep -qE "^recommended_command=" || { echo "FAIL: probe-only recommended_command line (got: $po_out)"; exit 1; }

# Branch=skip on a non-walkthrough proposal exits 2.
sed -i.bak 's/^design_gate: ".*"$/design_gate: "none"/' "$proposal"
rm -f "$proposal.bak"
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --branch skip >/dev/null 2>&1; then
  echo "FAIL: skip on non-walkthrough should exit 2"
  exit 1
fi

# Restore walkthrough; branch=skip on probe=live exits 2 (M023 shipped).
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"
rm -f "$proposal.bak"
if M023_SHIPPED_PROBE_OVERRIDE=live bash "$SCRIPT" --proposal "$proposal" --branch skip >/dev/null 2>&1; then
  echo "FAIL: skip on probe=live should exit 2"
  exit 1
fi

# Unknown --branch value exits 2.
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --branch frobnicate >/dev/null 2>&1; then
  echo "FAIL: unknown --branch should exit 2"
  exit 1
fi

# Missing --proposal exits 2.
if bash "$SCRIPT" --branch skip >/dev/null 2>&1; then
  echo "FAIL: missing --proposal should exit 2"
  exit 1
fi

echo "PASS: degradation-script — probe-only + branch validation errors covered"
exit 0
```

   b. `scripts/verify/m024-p07-pinned-message.sh` — asserts the FR-7 byte-pinned string.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-pinned-message.sh
# Asserts the FR-7 pinned message is byte-stable across the three pinned sites.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# The literal pinned string. DO NOT edit without updating all three pinned sites.
PINNED='design walkthrough lands in M023; author DESIGN.md manually or skip'

# Site 1: scripts/intake/design-gate-degradation.sh
grep -qF "$PINNED" "$ROOT/scripts/intake/design-gate-degradation.sh" \
  || { echo "FAIL: pinned message missing from scripts/intake/design-gate-degradation.sh"; exit 1; }

# Site 2: commands/evaluate.md
grep -qF "$PINNED" "$ROOT/commands/evaluate.md" \
  || { echo "FAIL: pinned message missing from commands/evaluate.md"; exit 1; }

# Site 3: this verify script (self-reference) — implicit; if the script ran the line above
# matched, the constant is intact.

# End-to-end emission: force walkthrough proposal, run --branch skip, assert stderr carries it.
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes and theme support" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"; rm -f "$proposal.bak"
grep -q '^pending_design_authored_manually:' "$proposal" || echo 'pending_design_authored_manually: false' >> "$proposal"

stderr_capture=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip 2>&1 >/dev/null)
echo "$stderr_capture" | grep -qF "$PINNED" \
  || { echo "FAIL: pinned message not on stderr during --branch skip (got: $stderr_capture)"; exit 1; }

echo "PASS: pinned-message — FR-7 string byte-stable across degradation script + evaluate.md + emitted to stderr"
exit 0
```

   c. `scripts/verify/m024-p07-m023-probe.sh` — exercises the probe override matrix.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-m023-probe.sh
# Exercises the M023_SHIPPED_PROBE_OVERRIDE matrix.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/intake/design-gate-degradation.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "fix typo" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# stub override -> m023_shipped=false reason=env-override
out=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=false" || { echo "FAIL: stub override (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=env-override" || { echo "FAIL: stub reason (got: $out)"; exit 1; }

# live override -> m023_shipped=true reason=env-override
out=$(M023_SHIPPED_PROBE_OVERRIDE=live bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=true" || { echo "FAIL: live override (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=env-override" || { echo "FAIL: live reason (got: $out)"; exit 1; }

# Unset override -> disk probe. On this checkout (no commands/design.md) -> false+disk-probe-failed.
unset M023_SHIPPED_PROBE_OVERRIDE
out=$(bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=false" || { echo "FAIL: disk probe (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=disk-probe-failed" || { echo "FAIL: disk reason (got: $out)"; exit 1; }

# Synthesize a commands/design.md in tmp ROOT and re-run with disk probe.
# (We cannot mutate the real ROOT; instead we build a synthetic root tree.)
synth="$tmp/synth"
mkdir -p "$synth/commands" "$synth/scripts/intake"
cp "$SCRIPT" "$synth/scripts/intake/"
chmod +x "$synth/scripts/intake/design-gate-degradation.sh"
echo 'Pass.1' > "$synth/commands/design.md"
# The script computes ROOT relative to its own location; copy a stub proposal too.
cp "$proposal" "$synth/scripts/intake/proposal-stub.md"
out=$(bash "$synth/scripts/intake/design-gate-degradation.sh" --proposal "$synth/scripts/intake/proposal-stub.md" --probe-only)
echo "$out" | grep -qx "m023_shipped=true" || { echo "FAIL: synth disk probe (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=disk-probe" || { echo "FAIL: synth disk reason (got: $out)"; exit 1; }

echo "PASS: m023-probe — env-override matrix + disk probe (negative + positive synthesized)"
exit 0
```

4. **Make verify scripts executable**: `chmod +x scripts/verify/m024-p07-degradation-script.sh scripts/verify/m024-p07-pinned-message.sh scripts/verify/m024-p07-m023-probe.sh`.

## Must-Haves

- `scripts/intake/design-gate-degradation.sh` exists and is executable.
- The FR-7 pinned message string `design walkthrough lands in M023; author DESIGN.md manually or skip` appears verbatim in the script source.
- `M023_SHIPPED_PROBE_OVERRIDE=stub` forces probe-fail; `M023_SHIPPED_PROBE_OVERRIDE=live` forces probe-pass; absent → disk probe (`commands/design.md` exists AND contains `^Pass\.[0-9]+`).
- Probe-only mode emits exactly two lines: `m023_shipped=<bool>` + `reason=<env-override|disk-probe|disk-probe-failed>` plus one line for `recommended_command=<v>`.
- Branch mode requires `design_gate=walkthrough` AND probe-fail; either condition violated → exit 2 with actionable error.
- Branch mode emits the FR-7 pinned message to stderr exactly once before dispatching to skip/manual.
- Skip handler mutates frontmatter: `design_skipped=true`, `pending_approval=false`, `proceeded_at=<ISO8601>`. Stdout: `branch=skip design_skipped=true proposal=<path>`.
- Manual handler first-invoke: mutates `pending_design_authored_manually=true`. Stdout: `branch=manual halt=true design_authored_manually=false design_md_path=<path>`.
- Manual handler follow-up (DESIGN.md exists at expected path): mutates `design_authored_manually=true`, `pending_design_authored_manually=false`, `pending_approval=true`. Stdout: `branch=manual halt=false ...`.
- Manual handler follow-up where DESIGN.md still missing: idempotent — same first-invoke stdout, no further mutation.
- All frontmatter mutations use the `sed -i.bak` BSD/GNU portable idiom; SB-3 write-confinement honored (writes only to the proposal path passed via `--proposal`).
- AD-19 single-script-file shape: every external invocation in the verify scripts is top-level; no inline compound bash, no plain subshells, no `$(...|...)` containing pipes.
- Bash 3.2 portable; no `declare -A`; no process substitution.

## Verification

```
bash scripts/verify/m024-p07-degradation-script.sh
bash scripts/verify/m024-p07-pinned-message.sh
bash scripts/verify/m024-p07-m023-probe.sh
```

Expected output (each exits 0): a single `PASS:` line per script.

## Inputs

### From Previous Tasks

(none — T02 is independent of T01)

### From Disk (Pre-existing)

- `scripts/intake/proposal-emit.sh` — used by the verify scripts to generate baseline proposals. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → stdout `proposal_path=<absolute path>`. Emits a P01-template proposal with `design_gate="none"` (stub).
- `scripts/intake/route-to-specify.sh` — referenced as the source-of-shape for the invoke-time probe pattern (#DQ-2 option `b`). T02 mirrors the probe re-run discipline (never trust plan-phase-time check).
- `scripts/intake/approval-gate.sh` — the BSD/GNU-portable `sed -i.bak` frontmatter-mutation idiom is established here; T02 reuses it for `design_skipped`/`design_authored_manually`/`pending_approval`/`pending_design_authored_manually`/`proceeded_at` mutations.
- `templates/intake-proposal.md` — read-only consumer; defines the `design_gate`/`design_skipped`/`design_authored_manually` keys. The new `pending_design_authored_manually` key is added by T03's template edit.
- POSIX utilities: `sed -i.bak`, `grep -E -q -F`, `head`, `cut`, `tr`, `mktemp`, `trap`, `chmod`, `cat`, `printf`, `date -u +%Y-%m-%dT%H:%M:%SZ`.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure invoke-time probe — no caching of probe results across invocations (#DQ-2 option `b`); every call re-runs the probe.
- Frontmatter writes confined to the named `--proposal <path>` (SB-3); no writes outside the named proposal.
- AD-19 single-script-file shape in every verify script — no `$(... | ...)` containing pipes, no plain subshells, no process substitution.
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- The FR-7 message must appear verbatim (byte-exact) in the script source — `grep -F` is the contracted matching shape.

## Expected Output

`scripts/intake/design-gate-degradation.sh` exists, is executable, and the three verify scripts each exit 0 with a `PASS:` line.
