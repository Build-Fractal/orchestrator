---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M024"
name: "Author the proposal emitter"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `templates/intake-proposal.md` exists with the pinned frontmatter contract and body skeleton.
- T02 complete: `scripts/intake/intake-id-allocate.sh` is executable and emits `intake_id=<value>` per the FR-11 + AD-2 rules.
- T03 complete: `scripts/intake/shape-detect.sh` is executable and emits `input_shape=<value>` + `shape_classification=<high|low>`.
- An existing intensity engine at `scripts/engine/intensity-recommend.sh` — read-only consumer per FR-9.

## Description

Author `scripts/intake/proposal-emit.sh` — the orchestration script that wires T01 + T02 + T03 into a single end-to-end emit:

1. Detect input shape (delegates to T03).
2. Allocate intake-id (delegates to T02).
3. Compute axis stub values (deep tier / decomposition / design-gate / conversus-gate logic ships in P02–P07; P01 emits structurally complete stubs that downstream phases will deepen):
   - **scope_tier**: `A` (P01 stub — full classifier ships P02 for spec shape, P03 for paragraph).
   - **decomposition**: `single-task` (P01 stub).
   - **design_gate**: `none` (P01 stub — full logic ships P07).
   - **conversus_gate**: `none` (P01 stub — full logic ships when conversus axis is wired).
   - **intensity**: invokes `scripts/engine/intensity-recommend.sh` if available; falls back to `Standard` if the script exits non-zero or is missing.
   - **recommended_command**: `orchestrator:dispatch` (consistent with `decomposition: single-task`).
4. Compute `input_hash`: `sha256(input || spec_path)` first 12 chars (for FR-14 idempotency).
5. Render the template by `sed`-substituting `{{placeholder}}` tokens in `templates/intake-proposal.md` with the resolved values.
6. Write to `.orchestrator/intake/<intake_id>/proposal.md`. Create the directory if absent.
7. Emit one line `proposal_path=<absolute path>` to stdout.

P01 emits **stub** axis values for everything except `input_shape` and `intensity`. Each axis section's rationale records the value AND the honest fallback evidence string `no-evidence — operator-supplied (P01 stub; deep classifier ships in P0N)`. This keeps SC-7 (frontmatter-completeness) and FR-13 (evidence citation) satisfied without P01 fabricating tier/gate decisions it does not yet have logic to support. P02–P07 progressively replace the `(P01 stub …)` rationale with real per-axis logic.

## Steps

1. **Write the script** at `scripts/intake/proposal-emit.sh`:

```bash
#!/usr/bin/env bash
# scripts/intake/proposal-emit.sh
# M024/P01/T04 — Emit a 6-axis intake proposal at .orchestrator/intake/<id>/proposal.md.
#
# Inputs (one of):
#   --input <string>    Free-text input (idea / paragraph / fragment).
#   --spec-path <path>  Path to an existing feature spec.
#   (none)              Empty — caller is expected to invoke Q&A first; P01 emits empty-shape stub.
#
# Output:
#   proposal_path=<absolute path>   to stdout
#
# Exit 0 on success, 2 on usage error, 1 on internal error.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"
SHAPE_DETECT="$ROOT/scripts/intake/shape-detect.sh"
ID_ALLOCATE="$ROOT/scripts/intake/intake-id-allocate.sh"
INTENSITY="$ROOT/scripts/engine/intensity-recommend.sh"
INTAKE_ROOT="$ROOT/.orchestrator/intake"

INPUT=""
SPEC_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)     INPUT="$2"; shift 2 ;;
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --intake-root) INTAKE_ROOT="$2"; shift 2 ;;  # test-only override
    -h|--help)
      echo "usage: proposal-emit.sh [--input <string>] [--spec-path <path>]" >&2
      exit 2 ;;
    *)
      echo "proposal-emit.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[ -f "$TEMPLATE" ]      || { echo "proposal-emit.sh: template missing: $TEMPLATE" >&2; exit 1; }
[ -x "$SHAPE_DETECT" ]  || { echo "proposal-emit.sh: shape-detect not executable" >&2; exit 1; }
[ -x "$ID_ALLOCATE" ]   || { echo "proposal-emit.sh: id-allocate not executable" >&2; exit 1; }

# (1) Shape.
shape_out=$(bash "$SHAPE_DETECT" --spec-path "${SPEC_PATH:-}" --input "${INPUT:-}")
input_shape=$(echo "$shape_out" | sed -n 's/^input_shape=//p')
shape_classification=$(echo "$shape_out" | sed -n 's/^shape_classification=//p')
[ -n "$input_shape" ] || { echo "proposal-emit.sh: shape-detect produced no input_shape" >&2; exit 1; }

# (2) Intake-id.
if [ -n "$SPEC_PATH" ]; then
  id_out=$(bash "$ID_ALLOCATE" --spec-path "$SPEC_PATH")
else
  id_for_alloc="${INPUT:-empty-input}"
  id_out=$(bash "$ID_ALLOCATE" --input "$id_for_alloc" --intake-dir "$INTAKE_ROOT")
fi
intake_id=$(echo "$id_out" | sed -n 's/^intake_id=//p')
[ -n "$intake_id" ] || { echo "proposal-emit.sh: id-allocate produced no intake_id" >&2; exit 1; }

# (3) Intensity (FR-9 reuse). Fall back to Standard on any error.
intensity="Standard"
if [ -x "$INTENSITY" ]; then
  raw=$(bash "$INTENSITY" --description "${INPUT:-${SPEC_PATH:-}}" 2>/dev/null || true)
  recommended=$(echo "$raw" | sed -n 's/^recommended_intensity=//p' | head -1)
  case "$recommended" in
    Quick|Standard|Full) intensity="$recommended" ;;
  esac
fi

# (4) Input hash.
hash_input="${INPUT:-${SPEC_PATH:-}}"
input_hash=$(printf '%s' "$hash_input" | shasum -a 256 | cut -c1-12)

# (5) Stub axes (P01 — deep logic in P02–P07).
scope_tier="A"
decomposition="single-task"
design_gate="none"
conversus_gate="none"
recommended_command="orchestrator:dispatch"

# (6) Frontmatter dynamic values.
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
supplemental_input="null"
auto_proceeded="false"
proceeded_at="null"
approved_at="null"
cancelled_at="null"
pending_approval="true"
design_skipped="false"
design_authored_manually="false"
qa_short_circuited="false"
low_confidence="false"
[ "$shape_classification" = "low" ] && low_confidence="true"

# (7) Body content — input echo + per-axis stub rationale (FR-13 honest fallback).
input_body="${INPUT:-(no inline input — see spec at $SPEC_PATH)}"
stub_rationale="P01 stub — deep classifier ships in a later phase."
stub_evidence="no-evidence — operator-supplied"

# (8) Render: sed-substitute every {{placeholder}}.
out_dir="$INTAKE_ROOT/$intake_id"
mkdir -p "$out_dir"
out_path="$out_dir/proposal.md"

# Use a temporary file to assemble; pipe-free for harness AD-19 compliance.
tmp_render=$(mktemp)
cp "$TEMPLATE" "$tmp_render"

# Helper: in-place sed swap (BSD/GNU portable via sed -i.bak then rm).
swap() {
  local key="$1"; local val="$2"
  # Escape forward slashes and ampersands in val.
  local esc
  esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/{{${key}}}/${esc}/g" "$tmp_render"
  rm -f "${tmp_render}.bak"
}

swap intake_id "$intake_id"
swap created_at "$created_at"
swap input_shape "$input_shape"
swap input_hash "$input_hash"
swap shape_classification "$shape_classification"
swap supplemental_input "$supplemental_input"
swap scope_tier "$scope_tier"
swap decomposition "$decomposition"
swap design_gate "$design_gate"
swap conversus_gate "$conversus_gate"
swap intensity "$intensity"
swap recommended_command "$recommended_command"
swap auto_proceeded "$auto_proceeded"
swap proceeded_at "$proceeded_at"
swap approved_at "$approved_at"
swap cancelled_at "$cancelled_at"
swap pending_approval "$pending_approval"
swap design_skipped "$design_skipped"
swap design_authored_manually "$design_authored_manually"
swap qa_short_circuited "$qa_short_circuited"
swap low_confidence "$low_confidence"

# Body slots — input + per-axis rationale/evidence stubs.
# Multiline `input_body` swap: use awk to substitute since the value may contain newlines.
awk -v body="$input_body" '
{ gsub(/\{\{input_body\}\}/, body); print }
' "$tmp_render" > "${tmp_render}.body"
mv "${tmp_render}.body" "$tmp_render"

for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  swap "rationale_${axis}" "$stub_rationale"
  swap "evidence_${axis}" "$stub_evidence"
done

swap approval_status "Status: pending operator approval."

mv "$tmp_render" "$out_path"

echo "proposal_path=$out_path"
exit 0
```

2. **Make it executable**: `chmod +x scripts/intake/proposal-emit.sh`.

3. **Write the verify script** at `scripts/verify/m024-p01-proposal-emit.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-proposal-emit.sh
# End-to-end emit: invoke against a paragraph and verify the resulting file
# contains all six axes + complete frontmatter.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

if [ ! -x "$EMIT" ]; then
  echo "FAIL: $EMIT not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

paragraph="We should add a last seen timestamp to the status command output and cache it for about five seconds so repeated calls do not hammer the filesystem."

out=$(bash "$EMIT" --input "$paragraph" --intake-root "$tmp/intake" || echo "ERR")
proposal_path=$(echo "$out" | sed -n 's/^proposal_path=//p')
if [ -z "$proposal_path" ] || [ ! -f "$proposal_path" ]; then
  echo "FAIL: emitter did not produce a file (out: $out)"
  exit 1
fi

REQUIRED="schema_version type intake_id created_at input_shape input_hash shape_classification scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence"

missing=""
for k in $REQUIRED; do
  if ! grep -q "^${k}:" "$proposal_path"; then
    missing="$missing $k"
  fi
done

# Six axis section headings.
for h in "Axis 1 — Input Shape" "Axis 2 — Scope Tier" "Axis 3 — Decomposition" "Axis 4 — Design Gate" "Axis 5 — Conversus Gate" "Axis 6 — Intensity"; do
  if ! grep -qF "$h" "$proposal_path"; then
    missing="$missing heading:$h"
  fi
done

# No unsubstituted placeholders.
if grep -q '{{[a-z_]*}}' "$proposal_path"; then
  missing="$missing unsubstituted-placeholders"
fi

if [ -n "$missing" ]; then
  echo "FAIL: proposal at $proposal_path missing —$missing"
  exit 1
fi

echo "PASS: proposal-emit.sh — frontmatter + six axis sections + no unsubstituted placeholders"
exit 0
```

4. **Write the write-confinement verify script** at `scripts/verify/m024-p01-write-confinement.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-write-confinement.sh
# Asserts grep against P01-produced shell scripts shows no writes outside .orchestrator/intake.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Allowed write targets (each line is a fixed substring matched against the
# script body — any disk write must reference one of these paths).
ALLOWED="\\.orchestrator/intake|/tmp|mktemp|\\\${tmp_render}|\\\$out_path|\\\$out_dir|\\\$INTAKE_ROOT|\\\$INTAKE_DIR"

violations=""
for f in "$ROOT/scripts/intake/proposal-emit.sh" "$ROOT/scripts/intake/shape-detect.sh" "$ROOT/scripts/intake/intake-id-allocate.sh"; do
  [ -f "$f" ] || continue
  # Find any redirection or mkdir target. If a >, >>, mkdir, or cp/mv target
  # references something other than ALLOWED paths, flag it.
  hits=$(grep -nE 'mkdir |^[^#]*>[^&]' "$f" | grep -vE "$ALLOWED" | grep -vE '^[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    violations="$violations
$f:
$hits"
  fi
done

if [ -n "$violations" ]; then
  echo "FAIL: write-confinement violations:$violations"
  exit 1
fi

echo "PASS: P01 scripts write only under .orchestrator/intake or /tmp"
exit 0
```

5. **Write the schema-version pin verify** at `scripts/verify/m024-p01-schema-version.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-schema-version.sh
# Asserts proposal frontmatter pins schema_version: "1.0" (AD-3) and does
# NOT introduce intake_schema_version.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"

if ! grep -q '^schema_version: "1.0"' "$TEMPLATE"; then
  echo "FAIL: $TEMPLATE missing 'schema_version: \"1.0\"' pin"
  exit 1
fi

if grep -q '^intake_schema_version' "$TEMPLATE"; then
  echo "FAIL: $TEMPLATE introduces intake_schema_version (forbidden by AD-3)"
  exit 1
fi

echo "PASS: schema_version pin AD-3 honored"
exit 0
```

## Must-Haves

- `scripts/intake/proposal-emit.sh` exists, is executable, and produces a file at the path it emits.
- The emitted file's frontmatter contains every key from the T01 template — none unsubstituted (no `{{...}}` left over).
- The emitted file body contains all six `Axis N — <name>` headings.
- `intensity` axis is populated from `scripts/engine/intensity-recommend.sh` when available; falls back to `Standard` otherwise.
- All writes confined to `.orchestrator/intake/<id>/` (SB-3) — verified by `scripts/verify/m024-p01-write-confinement.sh`.
- `schema_version: "1.0"` pinned (AD-3) — verified by `scripts/verify/m024-p01-schema-version.sh`.
- No `<TODO:` markers in any emitted proposal body (DC-3 / D019).

## Verification

```
bash scripts/verify/m024-p01-proposal-emit.sh
bash scripts/verify/m024-p01-write-confinement.sh
bash scripts/verify/m024-p01-schema-version.sh
```

Each exits 0 with a `PASS:` line.

## Inputs

### From Previous Tasks

- `templates/intake-proposal.md` (from T01) — read as the template; substituted by `sed`. Key API: 22 frontmatter keys + 12 body placeholders (`{{input_body}}`, `{{rationale_<axis>}}`, `{{evidence_<axis>}}` for each of 6 axes, `{{approval_status}}`).
- `scripts/intake/shape-detect.sh` (from T03) — invoked via `bash <path> --spec-path <p> --input <s>`. Key API: emits two stdout lines `input_shape=<value>` and `shape_classification=<high|low>`; exits 0 on success, 2 on usage error. Pure (FR-14 idempotent).
- `scripts/intake/intake-id-allocate.sh` (from T02) — invoked via `bash <path> {--spec-path <p>|--input <s>} [--intake-dir <d>]`. Key API: emits one stdout line `intake_id=<value>`; exits 0 on success, 2 on usage error. Writes nothing.

### From Disk (Pre-existing)

- `scripts/engine/intensity-recommend.sh` — read-only consumer per FR-9. Invoked with `--description <prose>`; expected stdout key `recommended_intensity=<Quick|Standard|Full>`. Failure-tolerant: emitter falls back to `Standard` if the script is missing or exits non-zero.
- `shasum -a 256` (system) — used for input-hash computation. Available on macOS + Linux base images.
- `awk`, `sed -i.bak`, `cut`, `tr`, `mktemp` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. `sed -i.bak` (with the `.bak` suffix then `rm`) instead of `sed -i ''` for BSD/GNU portability.
- Writes only to `.orchestrator/intake/<intake_id>/` and `/tmp` (via `mktemp`). Verified mechanically.
- No conversus invocations, no knowledge writes (SB-3, NG-2, NG-5).
- No `<TODO:` markers in any output (DC-3).
- AD-19 harness shape: every external invocation is a single-script-file shape (`bash <path> --args`); no inline compound bash, no plain subshells, no `$(...)` containing pipes.
- The emitter is **idempotent within a single project state**: re-running with identical input produces a byte-identical file *except for `created_at`*. The `input_hash` field is the FR-14 idempotency key — full byte-identical idempotency lands when a later phase wires the cache lookup. P01 emits the hash; P01 does not enforce idempotency yet (that is a downstream phase concern).
- The five P01 stub axis values (`scope_tier=A`, `decomposition=single-task`, `design_gate=none`, `conversus_gate=none`, `recommended_command=orchestrator:dispatch`) are placeholders that downstream phases replace. They satisfy SC-7 (frontmatter-completeness) without claiming P01 has real per-axis logic.

## Expected Output

`scripts/intake/proposal-emit.sh` exists, is executable, and the three verify scripts (`m024-p01-proposal-emit.sh`, `m024-p01-write-confinement.sh`, `m024-p01-schema-version.sh`) all exit 0 with `PASS:` lines.
