---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M024"
name: "--mode check-fast-path on scripts/intake/approval-gate.sh"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `auto_proceed` is a valid `read-config.sh` key and the defaults file ships `auto_proceed: true`. (T02 does not directly depend on the config — that wiring lands in T03 — but the suite ordering keeps T01 first so T03's verifies can chain.)
- P03 complete: `scripts/intake/approval-gate.sh` exists at HEAD with the `approve | cancel | revise` verbs, the `read_fm` / `read_fm_bare` helpers, and the `set -u` discipline.
- P01 complete: the proposal frontmatter ships `scope_tier`, `intensity`, `conversus_gate`, `design_gate`, and `low_confidence` keys (all populated by the emitter every run, per the 25-key SC-7 contract).

## Description

Extend `scripts/intake/approval-gate.sh` with a fifth invocation mode (alongside the existing three verbs): `--mode check-fast-path --proposal <path>`. The mode reads the named proposal's frontmatter, evaluates the four fast-path conditions plus the `low_confidence` guard, and emits exactly two stdout key=value lines. The check is **read-only** — no frontmatter mutation, no I/O outside the proposal read.

### Mode contract

| Argument                       | Required | Notes                                                               |
|--------------------------------|----------|---------------------------------------------------------------------|
| `--mode check-fast-path`       | yes      | Selects the new mode. (Verb form `--verb` is reserved for P03 verbs; `--mode` keeps the surfaces orthogonal.) |
| `--proposal <path>`            | yes      | Read-only path to the proposal under test.                          |

### Stdout shape

Exactly two lines, in fixed order (the order is the verifiable contract — MEM029 stdout-discipline pattern):

```
fast_path_eligible=true|false
reason=<token>
```

`<token>` is one of (closed enum):

- `all-conditions-met` — emitted when `fast_path_eligible=true`.
- `tier-not-A` — `scope_tier != "A"`.
- `intensity-not-Quick` — `intensity != "Quick"`.
- `conversus-gated` — `conversus_gate != "none"`.
- `design-gated` — `design_gate != "none"`.
- `low-confidence` — `low_confidence == "true"` (forward-wires the P05 Q&A short-circuit guard so a single-answer proposal never auto-proceeds).

Conditions are evaluated **in the order above**; the first failing condition wins the reason slot. (`all-conditions-met` is the only non-failing reason.)

### Exit codes

| Exit | Meaning                                                                                |
|------|----------------------------------------------------------------------------------------|
| 0    | Verdict emitted (eligible OR ineligible — both are healthy outcomes; the verdict is the value, not the exit code). |
| 1    | I/O error (proposal not found, frontmatter unreadable).                                |
| 2    | Usage error (missing `--mode`, missing `--proposal`, unknown mode).                    |

### Why a `--mode` flag (not a fourth `--verb`)

The existing `approve | cancel | revise` verbs all *mutate* frontmatter and are surfaces operators interact with. `check-fast-path` is a read-only programmatic surface called by `proposal-emit.sh` (T03). Using `--mode` keeps the operator-facing verb namespace clean and signals to callers that this surface is non-mutating. The argparse loop adds a single `--mode` case alongside the existing `--verb` case.

## Steps

1. **Edit `scripts/intake/approval-gate.sh`** — add `MODE=""` to the variable-init block at the top (next to `VERB=""`):

   ```bash
   PROPOSAL=""
   VERB=""
   MODE=""        # NEW — for --mode check-fast-path
   AXIS=""
   VALUE=""
   ```

2. Add a `--mode` case to the argparse `while` loop, immediately after the existing `--verb` case:

   ```bash
   while [ $# -gt 0 ]; do
     case "$1" in
       --proposal) PROPOSAL="$2"; shift 2 ;;
       --verb)     VERB="$2";     shift 2 ;;
       --mode)     MODE="$2";     shift 2 ;;
       --axis)     AXIS="$2";     shift 2 ;;
       --value)    VALUE="$2";    shift 2 ;;
       -h|--help)  usage ;;
       *)          usage ;;
     esac
   done
   ```

3. Update the usage block to document the new mode:

   ```bash
   usage() {
     cat >&2 <<'EOF'
   usage: approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <name> --value <value>]
          approval-gate.sh --proposal <path> --mode check-fast-path

   Verbs (mutate frontmatter):
     approve    set approved_at, set pending_approval=false, emit recommended_command_invoke
     cancel     set cancelled_at, set pending_approval=false
     revise     emit revision_pending (P03 surface; full re-emit lands in P05)

   Modes (read-only):
     check-fast-path   emit fast_path_eligible + reason for the four-condition gate
   EOF
     exit 2
   }
   ```

4. Adjust the `[ -n "$VERB" ] || usage` guard so either `VERB` or `MODE` satisfies it:

   ```bash
   [ -n "$PROPOSAL" ] || usage
   [ -n "$VERB" ] || [ -n "$MODE" ] || usage
   [ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }
   ```

5. **Branch on mode before the verb dispatcher.** Insert the new mode handler after the existing `read_fm` / `read_fm_bare` / `swap_line` / `now_iso` definitions but **before** the `case "$VERB"` block. The mode handler short-circuits — when `--mode check-fast-path` is supplied, the verb path is never entered.

   The check-fast-path mode does **not** require `recommended_command` (the proposal may not yet have one finalized when the emitter calls the check mid-render). It does **not** check `pending_approval` (the check is read-only and runs at emit time before the gate has been hit). Override the existing `REC_CMD` / `PA` reads by gating them on `[ -z "$MODE" ]`:

   ```bash
   if [ -z "$MODE" ]; then
     REC_CMD=$(read_fm recommended_command)
     [ -n "$REC_CMD" ] || { echo "ERR: proposal missing recommended_command frontmatter at $PROPOSAL" >&2; exit 1; }

     PA=$(read_fm_bare pending_approval)
     if [ "$PA" = "false" ]; then
       echo "ERR: proposal already finalized (pending_approval=false) at $PROPOSAL" >&2
       exit 1
     fi
   fi
   ```

6. Add the `check-fast-path` mode handler immediately after that block:

   ```bash
   if [ "$MODE" = "check-fast-path" ]; then
     scope_tier=$(read_fm scope_tier)
     intensity=$(read_fm intensity)
     conversus_gate=$(read_fm conversus_gate)
     design_gate=$(read_fm design_gate)
     low_confidence=$(read_fm_bare low_confidence)

     # Evaluate conditions in fixed order — the first failing condition wins the reason slot.
     if [ "$scope_tier" != "A" ]; then
       echo "fast_path_eligible=false"
       echo "reason=tier-not-A"
       exit 0
     fi
     if [ "$intensity" != "Quick" ]; then
       echo "fast_path_eligible=false"
       echo "reason=intensity-not-Quick"
       exit 0
     fi
     if [ "$conversus_gate" != "none" ]; then
       echo "fast_path_eligible=false"
       echo "reason=conversus-gated"
       exit 0
     fi
     if [ "$design_gate" != "none" ]; then
       echo "fast_path_eligible=false"
       echo "reason=design-gated"
       exit 0
     fi
     if [ "$low_confidence" = "true" ]; then
       echo "fast_path_eligible=false"
       echo "reason=low-confidence"
       exit 0
     fi

     echo "fast_path_eligible=true"
     echo "reason=all-conditions-met"
     exit 0
   fi

   # Unknown mode (anything other than check-fast-path).
   if [ -n "$MODE" ]; then
     echo "ERR: unknown mode '$MODE' — supported: check-fast-path" >&2
     exit 2
   fi
   ```

7. **Make the script executable** (already executable from P03 — no-op if so): `chmod +x scripts/intake/approval-gate.sh`.

8. **Author the verify** at `scripts/verify/m024-p04-fast-path-check.sh`:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-fast-path-check.sh
   # Verifies the --mode check-fast-path read-only verdict on hand-crafted proposals.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   GATE="$ROOT/scripts/intake/approval-gate.sh"

   [ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   # Helper: write a minimal proposal frontmatter for a given (tier, intensity, conv, design, lowconf) tuple.
   write_proposal() {
     # args: $1=tier $2=intensity $3=conversus_gate $4=design_gate $5=low_confidence  $6=out_path
     cat > "$6" <<EOF
   ---
   schema_version: "1.0"
   type: intake-proposal
   intake_id: "test"
   scope_tier: "$1"
   intensity: "$2"
   conversus_gate: "$3"
   design_gate: "$4"
   low_confidence: $5
   ---
   EOF
   }

   # Eligible proposal — all four conditions met, low_confidence=false.
   p1="$tmp/p1.md"
   write_proposal A Quick none none false "$p1"
   out=$(bash "$GATE" --proposal "$p1" --mode check-fast-path)
   echo "$out" | grep -q '^fast_path_eligible=true$'   || { echo "FAIL: eligible proposal verdict not true (got: $out)"; exit 1; }
   echo "$out" | grep -q '^reason=all-conditions-met$' || { echo "FAIL: eligible reason wrong (got: $out)"; exit 1; }

   # Tier B → tier-not-A.
   p2="$tmp/p2.md"
   write_proposal B Quick none none false "$p2"
   out=$(bash "$GATE" --proposal "$p2" --mode check-fast-path)
   echo "$out" | grep -q '^fast_path_eligible=false$' || { echo "FAIL: tier-B verdict not false (got: $out)"; exit 1; }
   echo "$out" | grep -q '^reason=tier-not-A$'        || { echo "FAIL: tier-B reason wrong (got: $out)"; exit 1; }

   # Tier A but Standard intensity → intensity-not-Quick.
   p3="$tmp/p3.md"
   write_proposal A Standard none none false "$p3"
   out=$(bash "$GATE" --proposal "$p3" --mode check-fast-path)
   echo "$out" | grep -q '^reason=intensity-not-Quick$' || { echo "FAIL: standard-intensity reason wrong (got: $out)"; exit 1; }

   # Conversus-gated → conversus-gated.
   p4="$tmp/p4.md"
   write_proposal A Quick required none false "$p4"
   out=$(bash "$GATE" --proposal "$p4" --mode check-fast-path)
   echo "$out" | grep -q '^reason=conversus-gated$' || { echo "FAIL: conversus reason wrong (got: $out)"; exit 1; }

   # Design-gated → design-gated.
   p5="$tmp/p5.md"
   write_proposal A Quick none required false "$p5"
   out=$(bash "$GATE" --proposal "$p5" --mode check-fast-path)
   echo "$out" | grep -q '^reason=design-gated$' || { echo "FAIL: design reason wrong (got: $out)"; exit 1; }

   # Low-confidence guard → low-confidence.
   p6="$tmp/p6.md"
   write_proposal A Quick none none true "$p6"
   out=$(bash "$GATE" --proposal "$p6" --mode check-fast-path)
   echo "$out" | grep -q '^reason=low-confidence$' || { echo "FAIL: low-confidence reason wrong (got: $out)"; exit 1; }

   # Read-only check: no .bak file, no frontmatter mutation. Compare frontmatter pre/post.
   pre=$(shasum -a 256 "$p1" | cut -c1-16)
   bash "$GATE" --proposal "$p1" --mode check-fast-path >/dev/null
   post=$(shasum -a 256 "$p1" | cut -c1-16)
   [ "$pre" = "$post" ] || { echo "FAIL: check-fast-path mutated proposal (pre=$pre post=$post)"; exit 1; }
   [ ! -f "${p1}.bak" ] || { echo "FAIL: check-fast-path left a .bak file"; exit 1; }

   # Unknown mode → exit 2.
   if bash "$GATE" --proposal "$p1" --mode frobnicate >/dev/null 2>&1; then
     echo "FAIL: unknown mode should exit non-zero"
     exit 1
   fi

   # Verb path still works (regression — approve verb on a fresh hand-crafted proposal needs recommended_command + pending_approval).
   p7="$tmp/p7.md"
   cat > "$p7" <<EOF
   ---
   schema_version: "1.0"
   type: intake-proposal
   intake_id: "test"
   recommended_command: "orchestrator:dispatch"
   pending_approval: true
   approved_at: null
   cancelled_at: null
   ---
   EOF
   ap_out=$(bash "$GATE" --proposal "$p7" --verb approve)
   echo "$ap_out" | grep -q '^recommended_command_invoke=orchestrator:dispatch$' \
     || { echo "FAIL: approve verb regression (got: $ap_out)"; exit 1; }

   echo "PASS: approval-gate.sh --mode check-fast-path — six branches + read-only invariant + verb regression"
   exit 0
   ```

9. **Make the verify executable**: `chmod +x scripts/verify/m024-p04-fast-path-check.sh`.

## Must-Haves

- `scripts/intake/approval-gate.sh` accepts `--mode check-fast-path --proposal <path>` and emits exactly two stdout lines (`fast_path_eligible=true|false` and `reason=<token>`).
- The six closed-enum reasons (`all-conditions-met`, `tier-not-A`, `intensity-not-Quick`, `conversus-gated`, `design-gated`, `low-confidence`) are emitted in the documented condition order — the first failing condition wins.
- The mode is **read-only**: no frontmatter mutation, no `.bak` file, file content shasum equal pre/post.
- Exit 0 in both eligible and ineligible cases. Exit 1 on missing proposal. Exit 2 on missing `--mode` or unknown mode value.
- The existing `approve | cancel | revise` verbs continue to work unchanged (regression coverage in the verify).
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)`.

## Verification

```
bash scripts/verify/m024-p04-fast-path-check.sh
```

Exits 0 with `PASS: approval-gate.sh --mode check-fast-path — six branches + read-only invariant + verb regression`.

## Inputs

### From Previous Tasks

- `scripts/intake/approval-gate.sh` (from M024/P03/T02) — the script being extended. Key API: `--proposal <path> --verb <approve|cancel|revise>` mutates frontmatter and emits a stdout decision line. Helpers `read_fm` (quoted-string read) and `read_fm_bare` (bare-value read) are pre-existing and reused in the new mode handler. The `swap_line` helper is **not** invoked in the new mode (the mode is read-only).
- T01's `auto_proceed` config key is **not** consumed by T02 (T03 wires the config check into the emitter); T02's mode is purely a verdict on the four axis values + the `low_confidence` guard.

### From Disk (Pre-existing)

- `templates/intake-proposal.md` (from M024/P01/T01) — the frontmatter schema being read. Keys consumed by check-fast-path: `scope_tier`, `intensity`, `conversus_gate`, `design_gate`, `low_confidence`. All five are populated by every emit (P01 SC-7 contract).
- `sed -n`, `grep`, `cat`, `mktemp`, `shasum`, `cut` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- Read-only invariant — `--mode check-fast-path` MUST NOT mutate the proposal file or leave any sibling `.bak` file. Verified by shasum equality and `.bak` non-existence.
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)`.
- Closed-enum discipline: the six `reason=` tokens are the **only** values emitted. Adding a seventh requires a follow-up Decision row (mirrors MEM031 closed-enum convention).
- Stdout-discipline (MEM029): the two-line shape is the contract — `fast_path_eligible=` first, `reason=` second, fixed order. Warnings go to stderr (none expected in normal operation).
- The mode is orthogonal to the verb path — invoking `--mode check-fast-path` MUST NOT exercise the `recommended_command` / `pending_approval` reads that the verb path requires.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

## Expected Output

`scripts/intake/approval-gate.sh` is modified to accept `--mode check-fast-path`; `scripts/verify/m024-p04-fast-path-check.sh` exists, is executable, and exits 0 with a `PASS:` line.
