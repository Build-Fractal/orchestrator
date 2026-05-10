---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M024"
name: "Routes — specify (M024→M014) + dispatch (trivial)"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: paragraph classifier wired into the emitter; paragraph proposals carry `recommended_command=orchestrator:specify` (Tier B/C) or `recommended_command=orchestrator:dispatch` (Tier A).
- T02 complete: `scripts/intake/approval-gate.sh` exists and emits `recommended_command_invoke=<value>` to stdout on `approve`.
- M014/extended is shipped (probe at plan-phase time confirmed `scripts/specify/specify.sh` exists and `commands/specify.md` ships the three-pass contract). The route-to-specify script re-runs the probe at invoke time and degrades cleanly if the probe ever fails on a future regenerated checkout.

## Description

Author two single-purpose route scripts that consume the `recommended_command_invoke=<value>` line from `scripts/intake/approval-gate.sh` and produce the deterministic invocation contract the caller (`commands/evaluate.md`, T04) acts on.

### `scripts/intake/route-to-specify.sh` — M024 → [M014](../../../../milestones/M014/index.md) handshake (#DQ-2)

- Argument: `--proposal <path>`.
- Reads `recommended_command:` from the proposal frontmatter; aborts with exit 1 if the value is not `orchestrator:specify`.
- Re-runs the M014/extended shipping probe inline:

  ```bash
  test -f "$ROOT/scripts/specify/specify.sh"
  ```

  If the probe fails, emit the stub message `STUB: M014/extended not shipped — author commands/specify.md three-pass contract per D019 before invoking this route.` to stderr and exit 1 (per spec #DQ-2 option `b`).

- On probe success, emit one stdout line: `invoke=orchestrator:specify --input-from <proposal_path>`.
- The route writes nothing — it is a pure decision emitter.

### `scripts/intake/route-to-dispatch.sh` — trivial path

- Argument: `--proposal <path>`.
- Reads `recommended_command:` from the proposal frontmatter; aborts with exit 1 if the value is not `orchestrator:dispatch`.
- Reads `auto_proceeded:` from the proposal frontmatter (P01 emits `false` by default; the degenerate-fast-path branch in P06 will flip it to `true` for Tier A + Quick + no-conversus + no-design proposals).
- If `auto_proceeded=true`, mutate the proposal frontmatter to set `proceeded_at: <ISO8601>` (using the same `sed -i.bak` BSD/GNU-portable idiom T02 established) and additionally emit `auto_proceed=1` to stdout.
- Emit one stdout line: `invoke=orchestrator:dispatch --proposal <proposal_path>`.

## Steps

1. **Create the specify route** at `scripts/intake/route-to-specify.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/route-to-specify.sh
# M024/P03/T03 — Route an approved proposal to orchestrator:specify (M024 → M014 handshake).
#
# Input:
#   --proposal <path>   Approved proposal whose recommended_command=orchestrator:specify.
#
# Output (stdout):
#   invoke=orchestrator:specify --input-from <proposal_path>
#
# Exit 0 on success; 1 on probe failure or wrong recommended_command; 2 on usage error.

set -u

usage() {
  echo "usage: route-to-specify.sh --proposal <path>" >&2
  exit 2
}

PROPOSAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# M014/extended shipping probe (#DQ-2 option b — invoke-time fail-fast).
if [ ! -f "$ROOT/scripts/specify/specify.sh" ]; then
  echo "STUB: M014/extended not shipped — author commands/specify.md three-pass contract per D019 before invoking this route." >&2
  exit 1
fi
if ! grep -q 'Pass.1' "$ROOT/commands/specify.md" 2>/dev/null; then
  echo "STUB: M014/extended not shipped — commands/specify.md missing three-pass contract." >&2
  exit 1
fi

# Read recommended_command from frontmatter.
rec_cmd=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ "$rec_cmd" != "orchestrator:specify" ]; then
  echo "ERR: route-to-specify invoked on proposal with recommended_command='$rec_cmd' (expected orchestrator:specify)" >&2
  exit 1
fi

echo "invoke=orchestrator:specify --input-from $PROPOSAL"
exit 0
```

2. **Create the dispatch route** at `scripts/intake/route-to-dispatch.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/route-to-dispatch.sh
# M024/P03/T03 — Route an approved (or auto-proceeded) proposal to orchestrator:dispatch.
#
# Input:
#   --proposal <path>   Proposal whose recommended_command=orchestrator:dispatch.
#
# Output (stdout):
#   invoke=orchestrator:dispatch --proposal <proposal_path>
#   auto_proceed=1   (only when proposal frontmatter has auto_proceeded: true)
#
# Side effect (only when auto_proceeded=true):
#   Mutates proposal frontmatter to set proceeded_at: <ISO8601>.
#
# Exit 0 on success; 1 on wrong recommended_command; 2 on usage error.

set -u

usage() {
  echo "usage: route-to-dispatch.sh --proposal <path>" >&2
  exit 2
}

PROPOSAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

rec_cmd=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ "$rec_cmd" != "orchestrator:dispatch" ]; then
  echo "ERR: route-to-dispatch invoked on proposal with recommended_command='$rec_cmd' (expected orchestrator:dispatch)" >&2
  exit 1
fi

auto_proceeded=$(sed -n 's/^auto_proceeded: \(.*\)$/\1/p' "$PROPOSAL" | head -1)

if [ "$auto_proceeded" = "true" ]; then
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  esc=$(printf '%s' "proceeded_at: \"$ts\"" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^proceeded_at: .*\$/${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
  echo "auto_proceed=1"
fi

echo "invoke=orchestrator:dispatch --proposal $PROPOSAL"
exit 0
```

3. **Make both executable**:

```
chmod +x scripts/intake/route-to-specify.sh scripts/intake/route-to-dispatch.sh
```

(This is a single command file; no compound shape.)

4. **Write the specify-route verify script** at `scripts/verify/m024-p03-route-to-specify.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-route-to-specify.sh
# Verifies route-to-specify produces the M024→M014 invoke line on a Tier B/C proposal
# AND the M014-shipping probe gates correctly.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
ROUTE="$ROOT/scripts/intake/route-to-specify.sh"

[ -x "$EMIT" ]  || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$ROUTE" ] || { echo "FAIL: $ROUTE not executable"; exit 1; }

# Probe sanity — M014 must currently be shipped (otherwise this checkout cannot run P03 verifies).
[ -f "$ROOT/scripts/specify/specify.sh" ] || { echo "FAIL: M014 specify.sh missing — checkout broken"; exit 1; }
grep -q 'Pass.1' "$ROOT/commands/specify.md" || { echo "FAIL: commands/specify.md missing three-pass marker"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier B paragraph → recommended_command=orchestrator:specify.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || {
  echo "FAIL: emitter did not flag specify as recommended_command for the Tier B paragraph"
  exit 1
}

route_out=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out" | grep -q "^invoke=orchestrator:specify --input-from $proposal\$" || {
  echo "FAIL: route-to-specify did not emit the M024→M014 invoke line (got: $route_out)"
  exit 1
}

# Mismatch case: a Tier A proposal (recommended_command=orchestrator:dispatch) MUST be rejected.
emit_out2=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
grep -q '^recommended_command: "orchestrator:dispatch"' "$proposal2" || {
  echo "FAIL: Tier A proposal did not carry dispatch as recommended_command"
  exit 1
}
if bash "$ROUTE" --proposal "$proposal2" >/dev/null 2>&1; then
  echo "FAIL: route-to-specify accepted a dispatch-recommended proposal"
  exit 1
fi

echo "PASS: route-to-specify.sh — emits M024→M014 invoke line + rejects dispatch-recommended proposals"
exit 0
```

5. **Write the dispatch-route verify script** at `scripts/verify/m024-p03-route-to-dispatch.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-route-to-dispatch.sh
# Verifies route-to-dispatch on Tier A proposal AND the auto_proceed=true mutation path.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
ROUTE="$ROOT/scripts/intake/route-to-dispatch.sh"

[ -x "$EMIT" ]  || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$ROUTE" ] || { echo "FAIL: $ROUTE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A paragraph → recommended_command=orchestrator:dispatch, auto_proceeded=false (default).
emit_out=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^recommended_command: "orchestrator:dispatch"' "$proposal" || {
  echo "FAIL: emitter did not flag dispatch as recommended_command for the Tier A paragraph"
  exit 1
}

# Default path: auto_proceeded=false → no proceeded_at mutation, no auto_proceed=1 stdout.
route_out=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out" | grep -q "^invoke=orchestrator:dispatch --proposal $proposal\$" || {
  echo "FAIL: route-to-dispatch did not emit invoke line (got: $route_out)"
  exit 1
}
echo "$route_out" | grep -q '^auto_proceed=1' && {
  echo "FAIL: route-to-dispatch emitted auto_proceed=1 on auto_proceeded=false proposal"
  exit 1
}
grep -q '^proceeded_at: null' "$proposal" || { echo "FAIL: proceeded_at unexpectedly mutated"; exit 1; }

# Auto-proceed path: simulate P06's fast-path branch by flipping auto_proceeded to true on disk.
sed -i.bak 's/^auto_proceeded: false$/auto_proceeded: true/' "$proposal"
rm -f "${proposal}.bak"

route_out2=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out2" | grep -q '^auto_proceed=1$' || {
  echo "FAIL: route-to-dispatch did not emit auto_proceed=1 on auto_proceeded=true (got: $route_out2)"
  exit 1
}
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$proposal" || {
  echo "FAIL: proceeded_at not set on auto_proceeded=true path"
  exit 1
}

# Mismatch case: a specify-recommended proposal MUST be rejected.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data."
emit_out3=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake3")
proposal3=$(echo "$emit_out3" | sed -n 's/^proposal_path=//p')
grep -q '^recommended_command: "orchestrator:specify"' "$proposal3" || {
  echo "FAIL: Tier B proposal did not carry specify as recommended_command"
  exit 1
}
if bash "$ROUTE" --proposal "$proposal3" >/dev/null 2>&1; then
  echo "FAIL: route-to-dispatch accepted a specify-recommended proposal"
  exit 1
}

echo "PASS: route-to-dispatch.sh — invoke line + auto_proceed mutation + rejects specify-recommended proposals"
exit 0
```

## Must-Haves

- `scripts/intake/route-to-specify.sh` exists, is executable, and emits `invoke=orchestrator:specify --input-from <proposal_path>` to stdout on a specify-recommended proposal.
- The specify route re-runs the M014-shipping probe at invoke time and exits 1 with the `STUB:` stderr message when the probe fails (#DQ-2 option `b`).
- `scripts/intake/route-to-dispatch.sh` exists, is executable, and emits `invoke=orchestrator:dispatch --proposal <proposal_path>` to stdout on a dispatch-recommended proposal.
- The dispatch route, when `auto_proceeded=true` is set in the proposal frontmatter, mutates `proceeded_at: <ISO8601>` in-place and additionally emits `auto_proceed=1` to stdout.
- Both routes reject mis-matched proposals (specify route rejects dispatch-recommended; dispatch route rejects specify-recommended) with exit 1.
- All writes target only the named proposal file (SB-3 — verified by the phase-level write-confinement script in T04).
- AD-19 harness shape: every external invocation in verify scripts is single-script-file form.

## Verification

```
bash scripts/verify/m024-p03-route-to-specify.sh
bash scripts/verify/m024-p03-route-to-dispatch.sh
```

Expected output (each exit 0):

- `PASS: route-to-specify.sh — emits M024→M014 invoke line + rejects dispatch-recommended proposals`
- `PASS: route-to-dispatch.sh — invoke line + auto_proceed mutation + rejects specify-recommended proposals`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04, modified in M024/P03/T01) — invoked by verify scripts to generate fresh proposals. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → `proposal_path=<absolute path>`. Produces `recommended_command=orchestrator:specify` for Tier B/C paragraphs and `orchestrator:dispatch` for Tier A.
- `scripts/intake/paragraph-classify.sh` (from M024/P03/T01) — indirectly consumed via the emitter; provides the deterministic `recommended_command` value.
- `scripts/intake/approval-gate.sh` (from M024/P03/T02) — caller in the production path emits the `recommended_command_invoke=<value>` line that downstream evaluate.md (T04) feeds into one of these two routes.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; defines the frontmatter keys these routes read (`recommended_command`, `auto_proceeded`) and the dispatch route mutates (`proceeded_at`).

### From Disk (Pre-existing)

- `scripts/specify/specify.sh` (from M014/extended) — existence probed at invoke time. The M024→M014 handshake target. Read-only consumer per AD-4 direction `b`.
- `commands/specify.md` (from M014/extended) — existence + `Pass.1` marker probed. Read-only consumer.
- `sed -i.bak`, `grep`, `head`, `printf`, `date -u`, `mktemp` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. `sed -i.bak` (with `.bak` then `rm`) — never `sed -i ''`.
- The specify route writes nothing — pure stdout/stderr decision emitter.
- The dispatch route writes only to the proposal path passed via `--proposal`, and only when `auto_proceeded=true` (one mutation: `proceeded_at`).
- AD-19 single-script-file shape: every command in the verify scripts is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- The M014 probe is the load-bearing #DQ-2 gate. The probe re-runs at every invoke — never trust the plan-phase-time probe alone.

## Expected Output

`scripts/intake/route-to-specify.sh` and `scripts/intake/route-to-dispatch.sh` exist and are executable; both verify scripts (`m024-p03-route-to-specify.sh`, `m024-p03-route-to-dispatch.sh`) exit 0 with `PASS:` lines.
