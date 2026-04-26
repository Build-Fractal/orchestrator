---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M024"
name: "Axis re-derive — pure decision emitter for dependent-axis recomputation"
depends_on: []
---

## Prerequisites

- P01 complete: `templates/intake-proposal.md` defines the six routing axes (`input_shape`, `scope_tier`, `decomposition`, `design_gate`, `conversus_gate`, `intensity`) and the load-bearing `recommended_command` field. `scripts/intake/proposal-emit.sh` exists and renders the template.
- P03 complete: `scripts/intake/paragraph-classify.sh` and `scripts/intake/approval-gate.sh` already validate the closed-enum axis names (`input_shape | scope_tier | decomposition | design_gate | conversus_gate | intensity`) — T01 reuses the same enum.

No upstream P06 task dependencies — T01 is the leaf decision emitter the rest of P06 builds on.

## Description

Author `scripts/intake/axis-rederive.sh` — a pure decision emitter (no file writes, no side effects beyond stdout/stderr) that, given a single primary-axis override and the path to the parent proposal (so `input_shape` is readable for rule-table dispatch), emits the recomputed dependent-axis values to stdout as `key=value` lines.

This is the small reusable engine that `revise.sh` (T02) will invoke once per operator-supplied override to build the `--axes-from <file>` payload it hands to the emitter.

### Rule table

The script implements exactly one rule table (re-encoded from paragraph-classify.sh and spec-shape-classify.sh — the rules are small enough that re-encoding is cheaper than refactoring three scripts to share a lib in P06; library extraction can ride a future cleanup phase if a third call site appears):

| Override                        | Re-derived dependent axes (stdout lines)                                            |
|---------------------------------|--------------------------------------------------------------------------------------|
| `--axis scope_tier --value A`   | `decomposition=single-task` + `recommended_command=orchestrator:dispatch`            |
| `--axis scope_tier --value B`   | `decomposition=single-phase` + `recommended_command=orchestrator:specify`            |
| `--axis scope_tier --value C`   | `decomposition=milestone-with-phases` + `recommended_command=orchestrator:specify`   |
| `--axis decomposition --value single-task` | `recommended_command=orchestrator:dispatch`                                |
| `--axis decomposition --value single-phase` | `recommended_command=orchestrator:specify`                                |
| `--axis decomposition --value milestone-with-phases` | `recommended_command=orchestrator:specify`                       |
| `--axis decomposition --value multi-milestone` | `recommended_command=orchestrator:roadmap` (escalation hint)            |
| `--axis design_gate --value walkthrough` | (no rederives — P07 owns the manual/skip branch)                              |
| `--axis design_gate --value none` | (no rederives)                                                                     |
| `--axis conversus_gate --value <any>` | (independent — emit no rederive lines)                                         |
| `--axis intensity --value <any>` | (independent — emit no rederive lines)                                            |
| `--axis input_shape --value <any>` | (revising input_shape is a structural change — emit no rederive lines and a stderr warning advising the operator to re-run from scratch) |

For overrides that re-derive nothing (independent axes), the script exits 0 with no stdout and an optional stderr note `note=axis is independent — no dependents`.

### Argument contract

- `--axis <name>` — primary override axis (closed enum: the six routing axes).
- `--value <value>` — primary override value. Validation per the same value enums paragraph-classify.sh / spec-shape-classify.sh emit:
  - `scope_tier`: `A | B | C`
  - `decomposition`: `single-task | single-phase | milestone-with-phases | multi-milestone`
  - `design_gate`: `none | walkthrough`
  - `conversus_gate`: `none | tdd-prone | scope-prone | api-prone` (open-set tolerated; pass through unchanged for independent axes)
  - `intensity`: `Quick | Standard | Full`
  - `input_shape`: `idea | paragraph | fragment | spec | empty | empty_qa`
- `--proposal <path>` — read-only access; only used to extract `input_shape` so the rule table can dispatch (e.g., a `scope_tier=C` override on a `spec`-shape proposal still re-derives `decomposition=milestone-with-phases` + `recommended_command=orchestrator:specify` per the spec rules; in P06 the rules happen to coincide for paragraph and spec shapes, but the proposal-aware shape lookup is forward-binding for P07 which may diverge them).

### Error handling

- Missing `--axis` or `--value`: exit 2 with usage.
- Missing `--proposal` or proposal file does not exist: exit 1 with `ERR: proposal not found at <path>`.
- Unknown axis name: exit 2 with `ERR: unknown axis '<name>' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity`.
- Invalid axis value (not in the enum for that axis): exit 2 with `ERR: invalid value '<v>' for axis '<a>' — supported: <enum>`.
- `input_shape` override: exit 0 with stderr warning `WARN: input_shape revision is structural; consider re-running orchestrator:evaluate from scratch instead`. Emit no rederive lines.

## Steps

1. **Create the script** at `scripts/intake/axis-rederive.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/axis-rederive.sh
# M024/P06/T01 — Pure decision emitter for dependent-axis recomputation (FR-12).
#
# Inputs:
#   --axis <name>      Primary override axis (closed enum).
#   --value <value>    Primary override value.
#   --proposal <path>  Parent proposal (read-only — used for input_shape lookup).
#
# Stdout (zero or more lines):
#   <dependent-axis>=<rederived-value>
#
# Stderr (advisory):
#   note=axis is independent — no dependents
#   WARN: input_shape revision is structural; consider re-running orchestrator:evaluate from scratch instead
#
# Exit 0 on success (including independent-axis no-op), 1 on internal error, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: axis-rederive.sh --axis <name> --value <value> --proposal <path>

Axes (closed enum):
  input_shape  scope_tier  decomposition  design_gate  conversus_gate  intensity

Emits dependent-axis recomputations as key=value stdout lines.
Independent axes (conversus_gate, intensity) emit no lines.
EOF
  exit 2
}

AXIS=""
VALUE=""
PROPOSAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --axis)     AXIS="$2";     shift 2 ;;
    --value)    VALUE="$2";    shift 2 ;;
    --proposal) PROPOSAL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$AXIS" ]     || usage
[ -n "$VALUE" ]    || usage
[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Read input_shape from the proposal frontmatter (single-pipeline shape).
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
SHAPE=$(read_fm input_shape)
[ -n "$SHAPE" ] || { echo "ERR: proposal missing input_shape frontmatter at $PROPOSAL" >&2; exit 1; }

# Axis enum check.
case "$AXIS" in
  input_shape|scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
  *) echo "ERR: unknown axis '$AXIS' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
esac

# Value enum check (per axis).
case "$AXIS" in
  scope_tier)
    case "$VALUE" in A|B|C) ;; *) echo "ERR: invalid value '$VALUE' for axis 'scope_tier' — supported: A B C" >&2; exit 2 ;; esac ;;
  decomposition)
    case "$VALUE" in single-task|single-phase|milestone-with-phases|multi-milestone) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'decomposition' — supported: single-task single-phase milestone-with-phases multi-milestone" >&2; exit 2 ;;
    esac ;;
  design_gate)
    case "$VALUE" in none|walkthrough) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'design_gate' — supported: none walkthrough" >&2; exit 2 ;;
    esac ;;
  intensity)
    case "$VALUE" in Quick|Standard|Full) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'intensity' — supported: Quick Standard Full" >&2; exit 2 ;;
    esac ;;
  input_shape)
    case "$VALUE" in idea|paragraph|fragment|spec|empty|empty_qa) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'input_shape' — supported: idea paragraph fragment spec empty empty_qa" >&2; exit 2 ;;
    esac ;;
  conversus_gate) ;;  # open-set passthrough
esac

# Rule dispatch.
case "$AXIS" in
  scope_tier)
    case "$VALUE" in
      A) echo "decomposition=single-task";          echo "recommended_command=orchestrator:dispatch" ;;
      B) echo "decomposition=single-phase";         echo "recommended_command=orchestrator:specify" ;;
      C) echo "decomposition=milestone-with-phases"; echo "recommended_command=orchestrator:specify" ;;
    esac
    exit 0 ;;
  decomposition)
    case "$VALUE" in
      single-task)            echo "recommended_command=orchestrator:dispatch" ;;
      single-phase)           echo "recommended_command=orchestrator:specify" ;;
      milestone-with-phases)  echo "recommended_command=orchestrator:specify" ;;
      multi-milestone)        echo "recommended_command=orchestrator:roadmap" ;;
    esac
    exit 0 ;;
  design_gate)
    # No rederives in P06; P07 owns the post-walkthrough manual/skip branch.
    exit 0 ;;
  conversus_gate|intensity)
    echo "note=axis is independent — no dependents" >&2
    exit 0 ;;
  input_shape)
    echo "WARN: input_shape revision is structural; consider re-running orchestrator:evaluate from scratch instead" >&2
    exit 0 ;;
esac
```

2. **Make it executable**: `chmod +x scripts/intake/axis-rederive.sh`.

3. **Write the verify script** at `scripts/verify/m024-p06-axis-rederive.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-axis-rederive.sh
# Verifies the axis-rederive rule table.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
RD="$ROOT/scripts/intake/axis-rederive.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$RD" ]   || { echo "FAIL: $RD not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a fresh paragraph proposal.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# scope_tier=C → decomposition=milestone-with-phases + recommended_command=orchestrator:specify
out=$(bash "$RD" --axis scope_tier --value C --proposal "$proposal")
echo "$out" | grep -qx "decomposition=milestone-with-phases" || { echo "FAIL: scope_tier=C did not emit milestone-with-phases (got: $out)"; exit 1; }
echo "$out" | grep -qx "recommended_command=orchestrator:specify" || { echo "FAIL: scope_tier=C did not emit orchestrator:specify (got: $out)"; exit 1; }

# scope_tier=A → decomposition=single-task + recommended_command=orchestrator:dispatch
out=$(bash "$RD" --axis scope_tier --value A --proposal "$proposal")
echo "$out" | grep -qx "decomposition=single-task" || { echo "FAIL: scope_tier=A did not emit single-task (got: $out)"; exit 1; }
echo "$out" | grep -qx "recommended_command=orchestrator:dispatch" || { echo "FAIL: scope_tier=A did not emit orchestrator:dispatch (got: $out)"; exit 1; }

# decomposition=multi-milestone → recommended_command=orchestrator:roadmap
out=$(bash "$RD" --axis decomposition --value multi-milestone --proposal "$proposal")
echo "$out" | grep -qx "recommended_command=orchestrator:roadmap" || { echo "FAIL: multi-milestone did not emit orchestrator:roadmap (got: $out)"; exit 1; }

# Independent axis (conversus_gate) emits no rederive lines.
out=$(bash "$RD" --axis conversus_gate --value tdd-prone --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: conversus_gate emitted unexpected stdout: $out"; exit 1; }

# Independent axis (intensity) emits no rederive lines.
out=$(bash "$RD" --axis intensity --value Full --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: intensity emitted unexpected stdout: $out"; exit 1; }

# design_gate=walkthrough emits no rederive lines (P07 owns the branch).
out=$(bash "$RD" --axis design_gate --value walkthrough --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: design_gate=walkthrough emitted unexpected stdout: $out"; exit 1; }

# Unknown axis exits 2.
if bash "$RD" --axis frobnicate --value X --proposal "$proposal" >/dev/null 2>&1; then
  echo "FAIL: unknown axis should exit non-zero"
  exit 1
fi

# Invalid value exits 2.
if bash "$RD" --axis scope_tier --value Z --proposal "$proposal" >/dev/null 2>&1; then
  echo "FAIL: invalid scope_tier value should exit non-zero"
  exit 1
fi

# Missing --proposal exits 2.
if bash "$RD" --axis scope_tier --value A >/dev/null 2>&1; then
  echo "FAIL: missing --proposal should exit non-zero"
  exit 1
fi

echo "PASS: axis-rederive — rule table covers scope_tier+decomposition; independent axes emit no lines; usage validation works"
exit 0
```

4. **Make verify script executable**: `chmod +x scripts/verify/m024-p06-axis-rederive.sh`.

## Must-Haves

- `scripts/intake/axis-rederive.sh` exists and is executable.
- The script is a pure decision emitter — no file writes anywhere, including no temp-file creation. (The verify script's `mktemp -d` is verify-only test scratch.)
- The `scope_tier` rule table emits exactly the dependent-axis lines named above for each of `A | B | C`.
- The `decomposition` rule table emits exactly the `recommended_command` line named above for each of the four values.
- Independent axes (`conversus_gate`, `intensity`) emit no stdout lines.
- The script reads `input_shape` from the supplied `--proposal` path so future P07 / Mxxx revisions can dispatch on shape.
- Closed-enum validation rejects unknown axes (exit 2) and invalid values (exit 2) with actionable error messages naming the supported set.
- AD-19 single-script-file shape: every external invocation in the verify script is top-level; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Bash 3.2 portable; no `declare -A`; no process substitution.

## Verification

```
bash scripts/verify/m024-p06-axis-rederive.sh
```

Expected output (exit 0):
- `PASS: axis-rederive — rule table covers scope_tier+decomposition; independent axes emit no lines; usage validation works`

## Inputs

### From Previous Tasks

(none — T01 is the leaf task)

### From Disk (Pre-existing)

- `scripts/intake/proposal-emit.sh` — used by the verify script only, to generate a fresh paragraph proposal whose frontmatter the rederive script reads. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → stdout `proposal_path=<absolute path>`. The emitter writes a 25-key-frontmatter proposal at `<intake-root>/<id>/proposal.md` per P01.
- `scripts/intake/paragraph-classify.sh` (referenced as the source of the rule table — re-encoded, not sourced). Key contract: paragraph-shape inputs map `≤30 words → scope_tier=A → decomposition=single-task → recommended_command=orchestrator:dispatch`; `31–80 words → scope_tier=B → decomposition=single-phase → orchestrator:specify`; etc. T01 re-encodes this mapping from the operator-override side.
- `scripts/intake/spec-shape-classify.sh` (same — re-encoded). Spec-shape inputs follow the same scope_tier → decomposition + recommended_command mapping.
- `templates/intake-proposal.md` — read-only consumer; defines the `input_shape` frontmatter key the script reads.
- POSIX utilities: `sed`, `head`, `mktemp`, `chmod`, `cat`, `echo`.

## Constraints

- POSIX sh + bash 3.2 portable.
- Pure decision emitter — no file writes. Specifically forbidden: any `>` redirect, `cp`, `mv`, `mkdir`, `touch`, or `sed -i`.
- AD-19 single-script-file shape in every verify script — no `$(... | ...)` containing pipes, no plain subshells, no process substitution.
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- No new schema fields — the script reads existing P01 frontmatter and emits values for existing P01 axes only (D024 / MEM031 schema authority handshake honored: P06 introduces no new keys).

## Expected Output

`scripts/intake/axis-rederive.sh` exists, is executable, and `bash scripts/verify/m024-p06-axis-rederive.sh` exits 0 with the `PASS:` line.
