---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M024"
name: "Approval gate — verbs + frontmatter mutation"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/intake/paragraph-classify.sh` exists, and `scripts/intake/proposal-emit.sh` is wired so paragraph-shaped inputs produce non-stub `scope_tier` / `decomposition` / `recommended_command` axis values.
- P01 complete: `templates/intake-proposal.md` defines the frontmatter keys `approved_at`, `cancelled_at`, `pending_approval` (all initialized to `null` / `true` by the emitter).

## Description

Author `scripts/intake/approval-gate.sh` — the operator-facing gate that, given a proposal path and a verb (`approve | cancel | revise <axis>=<value>`), mutates the proposal frontmatter in-place and emits a stdout decision line for the caller (`commands/evaluate.md` or a downstream router) to act on.

### Verb contract

| Verb              | Frontmatter mutation                                                          | Stdout                                                               | Exit |
|-------------------|-------------------------------------------------------------------------------|----------------------------------------------------------------------|------|
| `approve`         | `approved_at: <ISO8601>`, `pending_approval: false`                           | `recommended_command_invoke=<value-of-recommended_command-frontmatter>` | 0    |
| `cancel`          | `cancelled_at: <ISO8601>`, `pending_approval: false`                          | (none)                                                               | 0    |
| `revise <a>=<v>`  | (no mutation in P03 — body lands in P05)                                      | `revision_pending=true axis=<a> value=<v>`                           | 0    |

Unknown verbs exit 2 with an actionable usage message naming the three supported verbs.

### Mutation strategy

Use the same `sed -i.bak` BSD/GNU-portable idiom that P01/T04 established for proposal-emit.sh. For each frontmatter key the verb mutates, the gate replaces the entire `^<key>: .*$` line with the new value. The script reads the existing `recommended_command` value with a `sed -n` extraction (no `$(... | ...)` shape) before mutating so the stdout invoke line carries the right value.

```bash
# Read recommended_command from frontmatter (single-script shape).
read_fm() {
  local key="$1" path="$2"
  sed -n "s/^${key}: \"\\(.*\\)\"\$/\\1/p" "$path" | head -1
}
```

### Error handling

- Missing `--proposal <path>` argument: exit 2 with usage.
- Proposal file does not exist: exit 1 with `ERR: proposal not found at <path>`.
- Proposal frontmatter does not contain `recommended_command:` (malformed): exit 1.
- `pending_approval: false` already (already-approved or already-cancelled): exit 1 with `ERR: proposal already finalized`. This is the idempotency guard — the gate cannot re-decide a finalized proposal.

## Steps

1. **Create the gate** at `scripts/intake/approval-gate.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/approval-gate.sh
# M024/P03/T02 — Operator approval gate for intake proposals (FR-4).
#
# Inputs:
#   --proposal <path>   The proposal.md to act on.
#   --verb <verb>       One of: approve | cancel | revise
#   --axis <name>       (revise only) Axis to override.
#   --value <value>     (revise only) New value.
#
# Outputs:
#   approve: stdout line "recommended_command_invoke=<value>"
#   cancel:  no stdout
#   revise:  stdout line "revision_pending=true axis=<a> value=<v>"
#
# Exit 0 on success, 1 on internal error, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <name> --value <value>]

Verbs:
  approve    set approved_at, set pending_approval=false, emit recommended_command_invoke
  cancel     set cancelled_at, set pending_approval=false
  revise     emit revision_pending (P03 surface; full re-emit lands in P05)
EOF
  exit 2
}

PROPOSAL=""
VERB=""
AXIS=""
VALUE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    --verb)     VERB="$2";     shift 2 ;;
    --axis)     AXIS="$2";     shift 2 ;;
    --value)    VALUE="$2";    shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -n "$VERB" ]     || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Read a frontmatter key value (single-script shape).
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}

# Bare-value form (boolean fields are written without quotes).
read_fm_bare() {
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}

REC_CMD=$(read_fm recommended_command)
[ -n "$REC_CMD" ] || { echo "ERR: proposal missing recommended_command frontmatter at $PROPOSAL" >&2; exit 1; }

PA=$(read_fm_bare pending_approval)
if [ "$PA" = "false" ]; then
  echo "ERR: proposal already finalized (pending_approval=false) at $PROPOSAL" >&2
  exit 1
fi

# In-place line-replace helper, BSD/GNU portable.
swap_line() {
  local key="$1" newline="$2"
  local esc
  esc=$(printf '%s' "$newline" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^${key}: .*\$/${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

case "$VERB" in
  approve)
    ts=$(now_iso)
    swap_line approved_at "approved_at: \"$ts\""
    swap_line pending_approval "pending_approval: false"
    echo "recommended_command_invoke=$REC_CMD"
    exit 0
    ;;
  cancel)
    ts=$(now_iso)
    swap_line cancelled_at "cancelled_at: \"$ts\""
    swap_line pending_approval "pending_approval: false"
    exit 0
    ;;
  revise)
    [ -n "$AXIS" ]  || { echo "ERR: --axis required for revise" >&2; exit 2; }
    [ -n "$VALUE" ] || { echo "ERR: --value required for revise" >&2; exit 2; }
    case "$AXIS" in
      input_shape|scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
      *) echo "ERR: unsupported axis '$AXIS' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
    esac
    echo "revision_pending=true axis=$AXIS value=$VALUE"
    exit 0
    ;;
  *)
    usage
    ;;
esac
```

2. **Make it executable**: `chmod +x scripts/intake/approval-gate.sh`.

3. **Write the verify script** at `scripts/verify/m024-p03-approval-gate.sh` (covers `approve` + the frontmatter mutation):

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-approval-gate.sh
# Verifies the approve verb mutates frontmatter and emits the invoke line.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a fresh proposal (paragraph input — Tier B, recommended specify).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Pre-state: pending_approval=true, approved_at=null.
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pre-state pending_approval not true"; exit 1; }
grep -q '^approved_at: null' "$proposal"      || { echo "FAIL: pre-state approved_at not null"; exit 1; }

# Approve.
approve_out=$(bash "$GATE" --proposal "$proposal" --verb approve)

# Stdout: recommended_command_invoke=<value>.
echo "$approve_out" | grep -q '^recommended_command_invoke=orchestrator:' || {
  echo "FAIL: approve did not emit recommended_command_invoke (got: $approve_out)"
  exit 1
}

# Frontmatter mutation: pending_approval false, approved_at ISO8601.
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped to false"; exit 1; }
grep -qE '^approved_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$proposal" || {
  echo "FAIL: approved_at not set to ISO8601"
  exit 1
}

# Idempotency guard: re-running approve on already-finalized proposal MUST exit 1.
if bash "$GATE" --proposal "$proposal" --verb approve >/dev/null 2>&1; then
  echo "FAIL: approve on already-finalized proposal should exit non-zero"
  exit 1
fi

echo "PASS: approval-gate.sh — approve mutates frontmatter + emits invoke + idempotency guard"
exit 0
```

4. **Write the verbs verify script** at `scripts/verify/m024-p03-approval-gate-verbs.sh` (covers `cancel` and `revise`):

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-approval-gate-verbs.sh
# Verifies cancel + revise verbs.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Cancel case.
emit_out=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

cancel_out=$(bash "$GATE" --proposal "$proposal" --verb cancel)
[ -z "$cancel_out" ] || { echo "FAIL: cancel emitted unexpected stdout: $cancel_out"; exit 1; }
grep -qE '^cancelled_at: "[0-9]{4}-' "$proposal" || { echo "FAIL: cancelled_at not set"; exit 1; }
grep -q '^pending_approval: false' "$proposal"   || { echo "FAIL: pending_approval not flipped"; exit 1; }

# Revise case (separate fresh proposal so pending_approval is true).
emit_out2=$(bash "$EMIT" --input "Add a verbose flag to the status command." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
[ -f "$proposal2" ] || { echo "FAIL: second emit did not produce a proposal"; exit 1; }

revise_out=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C)
echo "$revise_out" | grep -q '^revision_pending=true axis=scope_tier value=C$' || {
  echo "FAIL: revise did not emit revision_pending line (got: $revise_out)"
  exit 1
}

# Revise must NOT mutate frontmatter in P03.
grep -q '^pending_approval: true' "$proposal2" || { echo "FAIL: revise mutated pending_approval (P03 must not)"; exit 1; }

# Unsupported axis exits 2.
if bash "$GATE" --proposal "$proposal2" --verb revise --axis frobnicate --value X >/dev/null 2>&1; then
  echo "FAIL: revise on unsupported axis should exit non-zero"
  exit 1
fi

# Unknown verb exits 2.
if bash "$GATE" --proposal "$proposal2" --verb yolo >/dev/null 2>&1; then
  echo "FAIL: unknown verb should exit non-zero"
  exit 1
fi

echo "PASS: approval-gate.sh — cancel mutates frontmatter, revise pass-through, unsupported verbs/axes rejected"
exit 0
```

## Must-Haves

- `scripts/intake/approval-gate.sh` exists, is executable, and supports the three verbs `approve`, `cancel`, `revise`.
- `approve` sets `approved_at: <ISO8601>` and `pending_approval: false` in the proposal frontmatter and emits `recommended_command_invoke=<value>` to stdout.
- `cancel` sets `cancelled_at: <ISO8601>` and `pending_approval: false`; emits no stdout.
- `revise <axis>=<value>` emits `revision_pending=true axis=<a> value=<v>` and does NOT mutate frontmatter (full revision body lands in P05).
- Already-finalized proposals (`pending_approval: false`) cannot be re-decided — the gate exits non-zero.
- Unknown verbs and unsupported revision axes exit 2 with actionable error messages.
- All writes target only the named proposal file (SB-3 — verified by the phase-level write-confinement script in T04).
- AD-19 harness shape: every external invocation in verify scripts is single-script-file form.

## Verification

```
bash scripts/verify/m024-p03-approval-gate.sh
bash scripts/verify/m024-p03-approval-gate-verbs.sh
```

Expected output (each exit 0):

- `PASS: approval-gate.sh — approve mutates frontmatter + emits invoke + idempotency guard`
- `PASS: approval-gate.sh — cancel mutates frontmatter, revise pass-through, unsupported verbs/axes rejected`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04, modified by M024/P03/T01) — invoked by verify scripts to generate fresh proposals. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → `proposal_path=<absolute path>`. The emitter initializes `pending_approval: true`, `approved_at: null`, `cancelled_at: null` in every fresh proposal.
- `scripts/intake/paragraph-classify.sh` (from M024/P03/T01) — indirectly consumed via the emitter; produces the non-stub `recommended_command` value the gate's `approve` verb echoes.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; defines the frontmatter keys the gate mutates (`approved_at`, `cancelled_at`, `pending_approval`).

### From Disk (Pre-existing)

- `sed -i.bak`, `grep`, `head`, `printf`, `date -u`, `mktemp` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. `sed -i.bak` (with `.bak` suffix then `rm`) — never `sed -i ''`.
- Writes only to the proposal path passed via `--proposal` (SB-3).
- AD-19 single-script-file shape: every command in the verify scripts is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`. The `read_fm` helper in the gate uses single-pipe `sed -n | head -1` which is safe (single-pipeline, not nested in `$()` with further pipes).
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- Idempotency guard is mandatory: re-running `approve` (or any verb) on an already-finalized proposal exits non-zero — the gate is one-shot per proposal.
- ISO 8601 UTC timestamps via `date -u +%Y-%m-%dT%H:%M:%SZ` (MEM008 standard).

## Expected Output

`scripts/intake/approval-gate.sh` exists, is executable, and the two verify scripts (`m024-p03-approval-gate.sh`, `m024-p03-approval-gate-verbs.sh`) both exit 0 with `PASS:` lines.
