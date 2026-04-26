---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M024"
name: "commands/evaluate.md rewrite + two phase tests + suite"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: paragraph classifier wired into the emitter; paragraph proposals carry deep axes.
- T02 complete: `scripts/intake/approval-gate.sh` exists with `approve | cancel | revise` verbs.
- T03 complete: `scripts/intake/route-to-specify.sh` and `scripts/intake/route-to-dispatch.sh` exist and emit deterministic invoke lines.
- The legacy spec-on-disk path in `commands/evaluate.md` (lines 23–35 currently) must remain byte-compatible per FR-6 — T04 adds a new "Input Shapes" section above the existing `Spec Discovery` block; it does not edit the existing scope-analysis / tier-classification prose.

## Description

Three deliverables:

1. **Edit `commands/evaluate.md`** to add a new top-level section **`## Input Shapes`** that documents all five input shapes (idea / paragraph / fragment / spec / empty), names the recommended downstream command per shape, and back-references the P01 + P03 scripts. Inserted **between** the `# orchestrator:evaluate` title block and the existing `## Prerequisites` block (no edits to the prerequisites or scope-analysis prose — FR-6 byte-compat invariant on the legacy path).

2. **Author two phase-level tests**: `tests/test-paragraph-intake.sh` (paragraph end-to-end: emit → assert non-stub axes → approve via gate → route to specify) and `tests/test-approval-gate.sh` (gate verb matrix: approve, cancel, revise, idempotency-guard, unknown-verb).

3. **Author the P03 suite + write-confinement + evaluate-md verify scripts** that wire everything together for `scripts/verify/check-must-haves.sh`-style consumption.

### `commands/evaluate.md` — new "Input Shapes" section

Insert this block immediately after the title and before the existing `## Prerequisites` heading. The legacy spec-on-disk path (current `## Spec Discovery` etc.) is unchanged — it remains the canonical pre-M024 entry-point per FR-6. The new section's first paragraph back-references the legacy path so readers landing on the new section understand the byte-compat guarantee.

```markdown
## Input Shapes

`orchestrator:evaluate` accepts any of five input shapes, detected mechanically by `scripts/intake/shape-detect.sh` (M024/P01) before tier classification runs. Every invocation emits a single reviewable proposal at `.orchestrator/intake/<id>/proposal.md` covering all six routing axes; the recommended downstream command and approval-gate behavior depend on the input shape and the resulting tier.

**Legacy spec-on-disk callers**: see `## Spec Discovery` below — the spec-on-disk path is unchanged and produces byte-compatible today-shape evaluation output per FR-6. The new proposal artifact is additionally emitted alongside it.

| Input shape | Detection rule (see `shape-detect.sh`)                                                | Recommended downstream                              | Approval gate                          |
|-------------|---------------------------------------------------------------------------------------|-----------------------------------------------------|----------------------------------------|
| `spec`      | `--spec-path <p>` points at a `type: feature-spec` file                               | `orchestrator:roadmap` (legacy path) + proposal.md  | Operator-approve unless degenerate     |
| `paragraph` | Word-count 11–80 with no fragment markers (default catch-all)                         | Tier A → `orchestrator:dispatch`; Tier B/C → `orchestrator:specify` (see `paragraph-classify.sh`) | Operator-approve (revise / cancel possible) |
| `fragment`  | Structural marker (`##` heading, Given/When/Then triple, FR-bullet) OR word-count ≥81 | `orchestrator:specify` (P05+ wires deep classifier) | Operator-approve                       |
| `idea`      | Word-count ≤10                                                                        | Tier A → `orchestrator:dispatch` (P05+ wires deep classifier) | Operator-approve unless degenerate     |
| `empty`     | No `--input` and no `--spec-path`                                                     | Bounded Q&A loop (P05+ wires Q&A); then proposal as if paragraph | Operator-approve                       |

For every non-degenerate shape, the operator is prompted via `scripts/intake/approval-gate.sh` with three verbs:

- `approve` — invoke the recommended downstream command (`scripts/intake/route-to-specify.sh` or `scripts/intake/route-to-dispatch.sh`).
- `cancel` — record `cancelled_at` to the proposal and halt.
- `revise <axis>=<value>` — override an axis and re-emit (full revision body lands in P05; P03 records revision intent only).

The degenerate fast-path (Tier A + Quick + no-conversus + no-design) auto-proceeds to `orchestrator:dispatch` without an approval prompt — wired in P06.

### Pre-M023 design-gate degradation

When the design-gate axis recommends a walkthrough on a checkout where M023 has not shipped, the router emits the exact string `"design walkthrough lands in M023; author DESIGN.md manually or skip"` and offers `manual` / `skip` branches per FR-7. P03 does not exercise this branch (P07 wires the design-gate classifier); the message is pinned for grep-stability and lands when P07 ships.
```

### `tests/test-paragraph-intake.sh`

End-to-end paragraph dogfood: emit a paragraph proposal, assert the three deep axes, run the approval gate, route to specify.

```bash
#!/usr/bin/env bash
# tests/test-paragraph-intake.sh
# M024/P03 phase test — paragraph end-to-end (emit → deep axes → approve → route).
# Conventions: parallel arrays for pass/fail tracking (MEM002).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"
ROUTE_S="$ROOT/scripts/intake/route-to-specify.sh"
ROUTE_D="$ROOT/scripts/intake/route-to-dispatch.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ----- Tier A paragraph (≤30 words) → dispatch.
emit_a=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/a")
prop_a=$(echo "$emit_a" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_a" ] && grep -q '^scope_tier: "A"' "$prop_a" && grep -q '^recommended_command: "orchestrator:dispatch"' "$prop_a"; then
  pass "tier A paragraph → dispatch"
else
  fail "tier A paragraph → dispatch" "proposal at $prop_a missing tier=A or dispatch"
fi

# Approve the Tier A proposal; gate emits invoke=orchestrator:dispatch.
ag_out=$(bash "$GATE" --proposal "$prop_a" --verb approve)
if echo "$ag_out" | grep -q '^recommended_command_invoke=orchestrator:dispatch$'; then
  pass "gate approve → dispatch invoke"
else
  fail "gate approve → dispatch invoke" "got: $ag_out"
fi

# Route to dispatch.
rd_out=$(bash "$ROUTE_D" --proposal "$prop_a")
if echo "$rd_out" | grep -q "^invoke=orchestrator:dispatch --proposal $prop_a\$"; then
  pass "route-to-dispatch invoke line"
else
  fail "route-to-dispatch invoke line" "got: $rd_out"
fi

# ----- Tier B paragraph (31–80 words) → specify.
para_b="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_b=$(bash "$EMIT" --input "$para_b" --intake-root "$tmp/b")
prop_b=$(echo "$emit_b" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_b" ] && grep -q '^scope_tier: "B"' "$prop_b" && grep -q '^recommended_command: "orchestrator:specify"' "$prop_b"; then
  pass "tier B paragraph → specify"
else
  fail "tier B paragraph → specify" "proposal at $prop_b missing tier=B or specify"
fi

# Approve + route to specify.
ag_out_b=$(bash "$GATE" --proposal "$prop_b" --verb approve)
if echo "$ag_out_b" | grep -q '^recommended_command_invoke=orchestrator:specify$'; then
  pass "gate approve → specify invoke"
else
  fail "gate approve → specify invoke" "got: $ag_out_b"
fi
rs_out=$(bash "$ROUTE_S" --proposal "$prop_b")
if echo "$rs_out" | grep -q "^invoke=orchestrator:specify --input-from $prop_b\$"; then
  pass "route-to-specify invoke line"
else
  fail "route-to-specify invoke line" "got: $rs_out"
fi

# ----- Tier C paragraph (milestone marker) → specify + milestone-with-phases.
emit_c=$(bash "$EMIT" --input "Plan a new milestone with multiple phases that overhauls the status command surface." --intake-root "$tmp/c")
prop_c=$(echo "$emit_c" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_c" ] && grep -q '^scope_tier: "C"' "$prop_c" && grep -q '^decomposition: "milestone-with-phases"' "$prop_c"; then
  pass "tier C paragraph → milestone-with-phases"
else
  fail "tier C paragraph → milestone-with-phases" "proposal at $prop_c missing tier=C or correct decomposition"
fi

# Print summary.
n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-paragraph-intake.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### `tests/test-approval-gate.sh`

Gate verb matrix.

```bash
#!/usr/bin/env bash
# tests/test-approval-gate.sh
# M024/P03 phase test — approval gate verb matrix.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""; NAMES_5=""
i=0
pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

new_proposal() {
  local dir="$1"; local input="$2"
  local out path
  out=$(bash "$EMIT" --input "$input" --intake-root "$dir")
  path=$(echo "$out" | sed -n 's/^proposal_path=//p')
  echo "$path"
}

# Approve.
p1=$(new_proposal "$tmp/d1" "Add a status caching layer for five seconds.")
ao=$(bash "$GATE" --proposal "$p1" --verb approve)
if echo "$ao" | grep -q '^recommended_command_invoke=' && grep -q '^pending_approval: false' "$p1" && grep -qE '^approved_at: "[0-9]{4}-' "$p1"; then
  pass "approve: invoke + frontmatter mutation"
else
  fail "approve: invoke + frontmatter mutation" "stdout=$ao"
fi

# Approve again on finalized proposal — must exit non-zero.
if bash "$GATE" --proposal "$p1" --verb approve >/dev/null 2>&1; then
  fail "approve idempotency guard" "second approve unexpectedly succeeded"
else
  pass "approve idempotency guard"
fi

# Cancel.
p2=$(new_proposal "$tmp/d2" "Add a status caching layer for five seconds.")
co=$(bash "$GATE" --proposal "$p2" --verb cancel)
if [ -z "$co" ] && grep -qE '^cancelled_at: "[0-9]{4}-' "$p2" && grep -q '^pending_approval: false' "$p2"; then
  pass "cancel: silent + frontmatter mutation"
else
  fail "cancel: silent + frontmatter mutation" "stdout=$co"
fi

# Revise (P03 pass-through).
p3=$(new_proposal "$tmp/d3" "Add a status caching layer for five seconds.")
ro=$(bash "$GATE" --proposal "$p3" --verb revise --axis scope_tier --value C)
if echo "$ro" | grep -q '^revision_pending=true axis=scope_tier value=C$' && grep -q '^pending_approval: true' "$p3"; then
  pass "revise: emits revision_pending + leaves frontmatter untouched"
else
  fail "revise: emits revision_pending + leaves frontmatter untouched" "stdout=$ro"
fi

# Unsupported axis.
if bash "$GATE" --proposal "$p3" --verb revise --axis frobnicate --value X >/dev/null 2>&1; then
  fail "unsupported axis rejection" "exited 0"
else
  pass "unsupported axis rejection"
fi

# Unknown verb.
if bash "$GATE" --proposal "$p3" --verb yolo >/dev/null 2>&1; then
  fail "unknown verb rejection" "exited 0"
else
  pass "unknown verb rejection"
fi

n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-approval-gate.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

### `scripts/verify/m024-p03-evaluate-md.sh`

Asserts the new "Input Shapes" section exists and covers all five shapes.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-evaluate-md.sh
# Verifies commands/evaluate.md ships the "Input Shapes" section per P03.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/commands/evaluate.md"

[ -f "$DOC" ] || { echo "FAIL: $DOC missing"; exit 1; }

grep -q '^## Input Shapes' "$DOC" || { echo "FAIL: $DOC missing '## Input Shapes' section"; exit 1; }

# All five shapes named in the section.
for shape in spec paragraph fragment idea empty; do
  if ! grep -q "\`$shape\`" "$DOC"; then
    echo "FAIL: $DOC does not name shape '$shape' in backticks"
    exit 1
  fi
done

# Back-references to P01 + P03 scripts.
for script in shape-detect.sh paragraph-classify.sh approval-gate.sh route-to-specify.sh route-to-dispatch.sh; do
  if ! grep -q "$script" "$DOC"; then
    echo "FAIL: $DOC does not back-reference $script"
    exit 1
  fi
done

# Legacy spec discovery section preserved (FR-6 byte-compat marker).
grep -q '^## Spec Discovery' "$DOC" || grep -q '^### 2. Spec Discovery' "$DOC" || {
  echo "FAIL: $DOC removed legacy Spec Discovery section (FR-6 violation)"
  exit 1
}

echo "PASS: evaluate.md — Input Shapes section + all five shapes + back-references + legacy preserved"
exit 0
```

### `scripts/verify/m024-p03-write-confinement.sh`

Asserts P03 scripts only write to `.orchestrator/intake/` or `/tmp`.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-write-confinement.sh
# Asserts P03-introduced scripts write only under .orchestrator/intake or /tmp (SB-3).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ALLOWED="\\.orchestrator/intake|/tmp|mktemp|\\\${PROPOSAL}|\\\$PROPOSAL|\\\$out_path|\\\$out_dir|\\\$INTAKE_ROOT|\\\$INTAKE_DIR|\\\$proposal"

violations=""
for f in \
  "$ROOT/scripts/intake/paragraph-classify.sh" \
  "$ROOT/scripts/intake/approval-gate.sh" \
  "$ROOT/scripts/intake/route-to-specify.sh" \
  "$ROOT/scripts/intake/route-to-dispatch.sh"; do
  [ -f "$f" ] || continue
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

echo "PASS: P03 scripts write only under .orchestrator/intake or /tmp"
exit 0
```

### `scripts/verify/m024-p03-suite.sh`

Bundles the two phase tests + every per-task verify.

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p03-suite.sh
# P03 suite — paragraph + approval-gate + routes + evaluate.md + write-confinement.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

run() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    "$@"
    return 1
  fi
}

rc=0
run "test-paragraph-intake.sh"          bash "$ROOT/tests/test-paragraph-intake.sh"          || rc=1
run "test-approval-gate.sh"             bash "$ROOT/tests/test-approval-gate.sh"             || rc=1
run "m024-p03-paragraph-classify"       bash "$ROOT/scripts/verify/m024-p03-paragraph-classify.sh"       || rc=1
run "m024-p03-approval-gate"            bash "$ROOT/scripts/verify/m024-p03-approval-gate.sh"            || rc=1
run "m024-p03-approval-gate-verbs"      bash "$ROOT/scripts/verify/m024-p03-approval-gate-verbs.sh"      || rc=1
run "m024-p03-route-to-specify"         bash "$ROOT/scripts/verify/m024-p03-route-to-specify.sh"         || rc=1
run "m024-p03-route-to-dispatch"        bash "$ROOT/scripts/verify/m024-p03-route-to-dispatch.sh"        || rc=1
run "m024-p03-evaluate-md"              bash "$ROOT/scripts/verify/m024-p03-evaluate-md.sh"              || rc=1
run "m024-p03-write-confinement"        bash "$ROOT/scripts/verify/m024-p03-write-confinement.sh"        || rc=1

if [ $rc -eq 0 ]; then
  echo "PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md"
fi
exit $rc
```

## Steps

1. **Edit `commands/evaluate.md`** — insert the "Input Shapes" section (block above) immediately after the `# orchestrator:evaluate` title block and before the existing `## Prerequisites` block. Do not edit any existing text in `## Prerequisites`, `## Scope Analysis`, `## Tier Classification`, or any later section — FR-6 byte-compat invariant.

2. **Create `tests/test-paragraph-intake.sh`** with the content above; `chmod +x tests/test-paragraph-intake.sh`.

3. **Create `tests/test-approval-gate.sh`** with the content above; `chmod +x tests/test-approval-gate.sh`.

4. **Create `scripts/verify/m024-p03-evaluate-md.sh`** with the content above; `chmod +x scripts/verify/m024-p03-evaluate-md.sh`.

5. **Create `scripts/verify/m024-p03-write-confinement.sh`** with the content above; `chmod +x scripts/verify/m024-p03-write-confinement.sh`.

6. **Create `scripts/verify/m024-p03-suite.sh`** with the content above; `chmod +x scripts/verify/m024-p03-suite.sh`.

## Must-Haves

- `commands/evaluate.md` ships the new `## Input Shapes` section naming all five shapes in backticks and back-referencing the P01 + P03 scripts (`shape-detect.sh`, `paragraph-classify.sh`, `approval-gate.sh`, `route-to-specify.sh`, `route-to-dispatch.sh`).
- The legacy `Spec Discovery` section is preserved verbatim (FR-6 byte-compat invariant).
- `tests/test-paragraph-intake.sh` exercises Tier A / B / C paragraph end-to-end (emit → axes → approve → route) and exits 0.
- `tests/test-approval-gate.sh` exercises the verb matrix (approve, cancel, revise, idempotency-guard, unsupported axis, unknown verb) and exits 0.
- `scripts/verify/m024-p03-suite.sh` runs every P03 phase test + per-task verify and emits `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md` when all pass.
- `scripts/verify/m024-p03-write-confinement.sh` confirms no P03 script writes outside `.orchestrator/intake/` or `/tmp`.
- AD-19 harness shape: every external invocation in tests + verify scripts is single-script-file form.

## Verification

```
bash scripts/verify/m024-p03-suite.sh
```

Expected output (exit 0): `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md`

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04 + M024/P03/T01) — invoked by both phase tests. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → `proposal_path=<absolute path>`.
- `scripts/intake/paragraph-classify.sh` (from M024/P03/T01) — exercised indirectly via the emitter.
- `scripts/intake/approval-gate.sh` (from M024/P03/T02) — exercised by `test-approval-gate.sh` and indirectly by `test-paragraph-intake.sh`. Key API: `bash approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <a> --value <v>]` → emits `recommended_command_invoke=<value>` (approve), no stdout (cancel), or `revision_pending=true axis=<a> value=<v>` (revise).
- `scripts/intake/route-to-specify.sh` (from M024/P03/T03) — invoked by `test-paragraph-intake.sh` on Tier B path. Emits `invoke=orchestrator:specify --input-from <path>`.
- `scripts/intake/route-to-dispatch.sh` (from M024/P03/T03) — invoked by `test-paragraph-intake.sh` on Tier A path. Emits `invoke=orchestrator:dispatch --proposal <path>`.

### From Disk (Pre-existing)

- `commands/evaluate.md` (from before M024) — modified by this task; the "Input Shapes" section is inserted before the existing `## Prerequisites` block.
- `commands/specify.md` (from M014/extended) — read-only consumer; back-referenced by the route-to-specify path.
- `scripts/intake/shape-detect.sh` (from M024/P01/T03) — read-only consumer; back-referenced by the new "Input Shapes" section.
- `templates/intake-proposal.md` (from M024/P01/T01) — read-only consumer; defines the frontmatter keys the tests grep for.
- `grep`, `sed -n`, `mktemp`, `date -u` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable. MEM002 test conventions: parallel indexed arrays for pass/fail tracking, structured `PASS:`/`FAIL:` lines, summary count at end.
- The `commands/evaluate.md` edit MUST NOT modify any existing prose under `## Prerequisites`, `## Scope Analysis`, `## Tier Classification`, or later sections — FR-6 byte-compat invariant. Insert the new section above `## Prerequisites` only.
- AD-19 single-script-file shape: every command in the tests + verify scripts is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Verification block authoring convention (per P01 lesson): the fenced block under `## Verification` contains ONLY runnable commands. Expected output goes in inline backticks below the fenced block, NOT in a second fenced block.
- The suite script propagates per-test failure but always runs the full test list (it does not bail on the first failure) so the operator sees the full pass/fail surface.
- No conversus invocations, no knowledge writes (NG-2, NG-5).

## Expected Output

`commands/evaluate.md` ships the "Input Shapes" section (legacy preserved); `tests/test-paragraph-intake.sh`, `tests/test-approval-gate.sh`, `scripts/verify/m024-p03-evaluate-md.sh`, `scripts/verify/m024-p03-write-confinement.sh`, and `scripts/verify/m024-p03-suite.sh` all exist and are executable; the suite script exits 0 with `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md`.
