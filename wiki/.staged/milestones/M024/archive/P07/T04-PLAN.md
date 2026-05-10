---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M024"
name: "Phase tests + suite + write-confinement + no-orphan check + evaluate.md update + D-row entry"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `scripts/intake/design-gate-classify.sh` exists; `scripts/verify/m024-p07-design-gate-classify.sh` passes.
- T02 complete: `scripts/intake/design-gate-degradation.sh` exists; `scripts/verify/m024-p07-degradation-script.sh`, `scripts/verify/m024-p07-pinned-message.sh`, `scripts/verify/m024-p07-m023-probe.sh` pass.
- T03 complete: `proposal-emit.sh` wires the classifier + recommended_command guard; `approval-gate.sh` accepts `manual`/`skip` verbs; `templates/intake-proposal.md` carries `pending_design_authored_manually`; `scripts/verify/m024-p07-skip-branch.sh`, `scripts/verify/m024-p07-manual-branch.sh`, `scripts/verify/m024-p07-approval-gate-design-verbs.sh` pass.

## Description

Six artifacts ship in T04:

1. **`tests/test-design-gate-degradation.sh`** — phase-level: paragraph with UI tokens → emit → assert FR-7 message via `grep -F` on stderr; assert `recommended_command` stays at the tier fallback (no `orchestrator:design` in pre-M023 frontmatter); assert verb table accepts `manual` and `skip`.
2. **`tests/test-design-gate-skip.sh`** — phase-level: full skip end-to-end. Emit → run `--verb skip` via approval-gate → assert `design_skipped: true`, `pending_approval: false`, `proceeded_at: <ISO8601>` in frontmatter.
3. **`tests/test-design-gate-manual.sh`** — phase-level: full manual end-to-end. Emit → first `--verb manual` invocation halts → author DESIGN.md at the named path → second `--verb manual` invocation flips `design_authored_manually: true`, `pending_approval: true`.
4. **`scripts/verify/m024-p07-no-orphan-design-cmd.sh`** — greps the codebase for active-code-path `orchestrator:design` references; asserts each is either inside an explicit M023-probe-pass branch or a doc-only forward reference clearly labeled.
5. **`scripts/verify/m024-p07-write-confinement.sh`** — asserts every P07 script writes only to `.orchestrator/intake/<id>/` and `/tmp`.
6. **`scripts/verify/m024-p07-evaluate-md.sh`** — asserts `commands/evaluate.md` Pre-M023 section reads "wired in P07" and the verb table includes `manual` and `skip` rows.

Plus three documentation/configuration updates:

7. **`commands/evaluate.md`** — flip the Pre-M023 design-gate degradation paragraph from "lands when P07 ships" to "wired in P07"; add `manual` and `skip` rows to the approval verb table; pin the FR-7 message verbatim. Update line 27 (the `revise` verb already says "wired in P06") for stylistic parity. Update line 33 (Pre-M023 paragraph) replacing "P03 does not exercise this branch (P07 wires the design-gate classifier); the message is pinned for grep-stability and lands when P07 ships." with a wired-in-P07 paragraph naming `scripts/intake/design-gate-degradation.sh`.

8. **[`.orchestrator/DECISIONS.md`](../../../../decisions.md)** — append a single D-row entry documenting the `pending_design_authored_manually` schema addition under MEM031 / D024 schema-authority handshake. The entry names [M020](../../../../milestones/M020/index.md) as the authority-holder, M024 as the consumer, the field semantics (transient flag, never carries semantic value beyond "operator is authoring DESIGN.md"), and the closed-enum default (`false` on emit; `true` only between manual-branch first-invoke and follow-up).

9. **`scripts/verify/m024-p07-suite.sh`** — MEM002 parallel-array tracker; structured `PASS:`/`FAIL:` summary; runs the three phase tests + every per-task verify (T01–T03 verifies plus T04 verifies, eleven total).

## Steps

### Step 1 — Author `tests/test-design-gate-degradation.sh`

```bash
#!/usr/bin/env bash
# tests/test-design-gate-degradation.sh
# M024/P07/T04 — End-to-end design-gate degradation: pinned message + no orphan command.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$DEG" ]  || { echo "FAIL: $DEG not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# UI-tagged paragraph -> classifier flips design_gate=walkthrough.
para="redesign the proposal viewer with split panes, a live diff layout, and a theme picker"
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^design_gate: "walkthrough"' "$proposal" || { echo "FAIL: classifier did not flip design_gate to walkthrough"; exit 1; }

# Recommended_command guard: must NOT be orchestrator:design pre-M023.
rec=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$proposal" | head -1)
[ "$rec" != "orchestrator:design" ] || { echo "FAIL: orphan orchestrator:design recommendation in pre-M023 proposal"; exit 1; }

# FR-7 pinned message lands on stderr during --branch skip.
PINNED='design walkthrough lands in M023; author DESIGN.md manually or skip'
stderr=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip 2>&1 >/dev/null)
echo "$stderr" | grep -qF "$PINNED" || { echo "FAIL: pinned message not on stderr"; exit 1; }

echo "PASS: design-gate-degradation — pinned message emits; no orphan orchestrator:design recommendation"
exit 0
```

### Step 2 — Author `tests/test-design-gate-skip.sh`

```bash
#!/usr/bin/env bash
# tests/test-design-gate-skip.sh
# M024/P07/T04 — Skip branch end-to-end: design_skipped=true, pending_approval=false.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# Approval-gate skip verb under stub probe.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb skip >/dev/null 2>&1 \
  || { echo "FAIL: skip verb exited non-zero"; exit 1; }

grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: design_skipped not flipped"; exit 1; }
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped"; exit 1; }
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$proposal" || { echo "FAIL: proceeded_at not set"; exit 1; }

echo "PASS: design-gate-skip — design_skipped=true, pending_approval=false, proceeded_at set"
exit 0
```

### Step 3 — Author `tests/test-design-gate-manual.sh`

```bash
#!/usr/bin/env bash
# tests/test-design-gate-manual.sh
# M024/P07/T04 — Manual branch end-to-end: halt-on-first-invoke; flip-on-follow-up.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# First invoke -> halt.
out1=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb manual 2>/dev/null)
echo "$out1" | grep -q '^branch=manual halt=true' || { echo "FAIL: first invoke did not halt (got: $out1)"; exit 1; }
design_md=$(echo "$out1" | sed -n 's/^.*design_md_path=//p' | head -1)
[ -n "$design_md" ] || { echo "FAIL: first invoke did not emit design_md_path"; exit 1; }

# Author DESIGN.md.
mkdir -p "$(dirname "$design_md")"
echo "# DESIGN.md (synthetic)" > "$design_md"

# Follow-up -> flip.
out2=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb manual 2>/dev/null)
echo "$out2" | grep -q '^branch=manual halt=false' || { echo "FAIL: follow-up did not flip (got: $out2)"; exit 1; }
grep -q '^design_authored_manually: true' "$proposal" || { echo "FAIL: design_authored_manually not flipped"; exit 1; }
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset"; exit 1; }

echo "PASS: design-gate-manual — halt+flip cycle works; pending_approval reset for re-approval"
exit 0
```

### Step 4 — Author `scripts/verify/m024-p07-no-orphan-design-cmd.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-no-orphan-design-cmd.sh
# Asserts no active-code-path orchestrator:design references appear without an M023 probe gate.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Greppable scope: scripts/intake/ + commands/evaluate.md (the active routing surface).
# Allowed sites:
#   - scripts/intake/design-gate-degradation.sh: probe-pass branch only.
#   - commands/evaluate.md: doc-only forward references explicitly labeled "post-M023".
#   - tests/, scripts/verify/m024-p07-* : test-only references (allowed; explicitly excluded below).
#
# Forbidden: any line in scripts/intake/proposal-emit.sh, scripts/intake/approval-gate.sh,
# or scripts/intake/route-*.sh that names orchestrator:design without an immediately-prior
# M023 probe-pass gate.

violation=0

# Scan proposal-emit.sh for orphan references.
if grep -nE 'orchestrator:design' "$ROOT/scripts/intake/proposal-emit.sh"; then
  echo "FAIL: orchestrator:design referenced in proposal-emit.sh — pre-M023 invariant violated"
  violation=1
fi

# Scan approval-gate.sh.
if grep -nE 'orchestrator:design' "$ROOT/scripts/intake/approval-gate.sh"; then
  echo "FAIL: orchestrator:design referenced in approval-gate.sh — pre-M023 invariant violated"
  violation=1
fi

# Scan route-to-*.sh.
for route in "$ROOT/scripts/intake/route-to-specify.sh" "$ROOT/scripts/intake/route-to-dispatch.sh"; do
  if [ -f "$route" ] && grep -nE 'orchestrator:design' "$route"; then
    echo "FAIL: orchestrator:design referenced in $(basename "$route") — pre-M023 invariant violated"
    violation=1
  fi
done

# Scan degradation script — references must be guarded by M023 probe-pass.
# Heuristic: every orchestrator:design occurrence must appear within 5 lines of an
# m023_shipped check. We accept the script-level convention if the only mention is
# inside a probe-pass branch (greppable as "m023_shipped=true" or "= \"true\"" pattern).
deg="$ROOT/scripts/intake/design-gate-degradation.sh"
if [ -f "$deg" ]; then
  if grep -nE 'orchestrator:design' "$deg"; then
    # Allowed only if every match is preceded (within 5 lines) by m023_shipped="true" or
    # m023_shipped" = "true" or equivalent. Use awk to validate.
    if ! awk '
      /m023_shipped[[:space:]]*=[[:space:]]*"?true"?/ { gate=NR }
      /orchestrator:design/ { if (NR - gate > 5 || gate == 0) { print "ORPHAN at line " NR; orphan=1 } }
      END { exit orphan ? 1 : 0 }
    ' "$deg"; then
      echo "FAIL: orchestrator:design in degradation script not gated by m023_shipped=true"
      violation=1
    fi
  fi
fi

# Scan evaluate.md — references must be in a clearly labeled "post-M023" doc context.
ev="$ROOT/commands/evaluate.md"
if grep -nE 'orchestrator:design' "$ev"; then
  # Allowed if every line is part of a "post-M023" / "when M023 ships" / "M023 has shipped" prose context.
  # We take the conservative line: only allow it if the file ALSO contains the post-M023 marker phrase
  # within 10 lines of every match.
  if ! awk '
    /post-M023|when M023 ships|M023 has shipped/ { gate=NR }
    /orchestrator:design/ { if (NR - gate > 10 || gate == 0) { if (NR - 10 > 0) { print "ORPHAN at line " NR; orphan=1 } } }
    END { exit orphan ? 1 : 0 }
  ' "$ev"; then
    echo "FAIL: orchestrator:design in evaluate.md not in a post-M023 doc context"
    violation=1
  fi
fi

if [ "$violation" -eq 0 ]; then
  echo "PASS: no-orphan-design-cmd — every orchestrator:design reference is M023-probe-gated or doc-labeled"
  exit 0
fi
exit 1
```

### Step 5 — Author `scripts/verify/m024-p07-write-confinement.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-write-confinement.sh
# Asserts P07 scripts write only to .orchestrator/intake/<id>/ or /tmp.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

violation=0

# Pure decision emitters must not redirect to any path.
for pure in "$ROOT/scripts/intake/design-gate-classify.sh"; do
  if grep -nE '^[^#]*[[:space:]]>[[:space:]]+[^&]' "$pure" \
     | grep -vE '>&[12]' | grep -vE '>/dev/null'; then
    echo "FAIL: $pure has unexpected file redirect — pure decision emitter must not write"
    violation=1
  fi
done

# Degradation script writes only to the --proposal path supplied by caller (sed -i.bak idiom).
deg="$ROOT/scripts/intake/design-gate-degradation.sh"
if grep -nE '^[^#]*sed -i\.bak' "$deg" | grep -v 'PROPOSAL'; then
  echo "FAIL: $deg has a sed -i.bak that does not target \$PROPOSAL — write-confinement violated"
  violation=1
fi

# proposal-emit.sh modifications must keep writes inside out_dir / out_path / tmp_render.
emit="$ROOT/scripts/intake/proposal-emit.sh"
if grep -nE '^[^#]*sed -i\.bak' "$emit" | grep -vE 'tmp_render|PROPOSAL|"\$proposal"|out_path'; then
  echo "FAIL: $emit has a sed -i.bak that escapes the tmp/intake confinement"
  violation=1
fi

if [ "$violation" -eq 0 ]; then
  echo "PASS: write-confinement — P07 scripts confine writes to intake dir + tmp"
  exit 0
fi
exit 1
```

### Step 6 — Author `scripts/verify/m024-p07-evaluate-md.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-evaluate-md.sh
# Asserts commands/evaluate.md's pre-M023 section names "wired in P07".

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EV="$ROOT/commands/evaluate.md"

[ -f "$EV" ] || { echo "FAIL: $EV not found"; exit 1; }

grep -qF 'wired in P07' "$EV" || { echo "FAIL: 'wired in P07' marker missing from evaluate.md"; exit 1; }
grep -qF 'design walkthrough lands in M023; author DESIGN.md manually or skip' "$EV" \
  || { echo "FAIL: FR-7 pinned message missing from evaluate.md"; exit 1; }
grep -qE '^\| `manual`' "$EV" || grep -qE '`manual`.*halts|halts.*`manual`' "$EV" \
  || { echo "FAIL: manual verb row missing from evaluate.md verb table"; exit 1; }
grep -qE '^\| `skip`' "$EV" || grep -qE '`skip`.*proceeds|proceeds.*`skip`' "$EV" \
  || { echo "FAIL: skip verb row missing from evaluate.md verb table"; exit 1; }
grep -qF 'scripts/intake/design-gate-degradation.sh' "$EV" \
  || { echo "FAIL: degradation script reference missing from evaluate.md"; exit 1; }

echo "PASS: evaluate-md — wired in P07 marker + FR-7 pinned message + manual/skip rows + script reference"
exit 0
```

### Step 7 — Update `commands/evaluate.md`

Locate the existing `### Pre-M023 design-gate degradation` section (lines 31–33). Replace its content with:

```markdown
### Pre-M023 design-gate degradation

Wired in P07. When the design-gate axis classifier (`scripts/intake/design-gate-classify.sh`) emits `design_gate=walkthrough` and the invoke-time M023-shipping probe at `scripts/intake/design-gate-degradation.sh` returns `m023_shipped=false`, the router emits the exact byte-pinned string `design walkthrough lands in M023; author DESIGN.md manually or skip` to stderr (FR-7 byte-stable for `grep -F`) and offers two operator branches via the approval-gate verb table:

| Verb     | Behavior                                                                                              |
|----------|-------------------------------------------------------------------------------------------------------|
| `manual` | Halts the workflow with a pointer to the expected `DESIGN.md` path. Operator authors `DESIGN.md`, then re-runs `evaluate`; on follow-up the proposal flips `design_authored_manually: true` and resets `pending_approval: true` so the operator must still approve before downstream runs. |
| `skip`   | Records `design_skipped: true` and proceeds without a design step.                                    |

The `recommended_command` slot in pre-M023 proposals stays at the tier-derived fallback (`orchestrator:dispatch` for Tier A, `orchestrator:specify` for Tier B/C) — `orchestrator:design` is never named in pre-M023 active code paths (verified by `scripts/verify/m024-p07-no-orphan-design-cmd.sh`).

Post-M023 (when `commands/design.md` ships with a `Pass.<N>` marker), the probe flips and the recommended_command points at `orchestrator:design`; the `manual` and `skip` verbs become operator-opt-out branches rather than M023-not-yet-shipped fallbacks.
```

### Step 8 — Append D-row to [`.orchestrator/DECISIONS.md`](../../../../decisions.md)

Locate the most-recent D-row in [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (likely D024 from M020/P01 or higher if M020/P02+ landed). Append a new D-row immediately after the latest one. The text:

```markdown
## D025 — `pending_design_authored_manually` transient frontmatter key (M024/P07)

**Date**: <today's ISO date>

**Context**: M024/P07 wires the FR-7 graceful-degradation path for the design-gate axis on a pre-M023 checkout. The `manual` branch halts on first invocation (operator must author `DESIGN.md`) and proceeds on follow-up. Tracking the in-between state requires a transient frontmatter flag that is `false` on emit, `true` between manual-branch first-invoke and follow-up, and `false` again after the operator authors `DESIGN.md` and re-runs.

**Decision**: Add `pending_design_authored_manually` to the intake-proposal frontmatter as a closed-enum `true | false` flag. Initialized to `false` on every fresh emit (`proposal-emit.sh`). Mutated only by `scripts/intake/design-gate-degradation.sh --branch manual`. Never carries semantic value beyond "operator is mid-authoring `DESIGN.md`."

**Authority**: M020 holds schema authority over knowledge entries (MEM031); the intake proposal frontmatter is M024-owned but uses the same closed-enum discipline. This D-row is the M024 schema-evolution record for the intake proposal and does NOT require an M020 D-row update (intake-proposal frontmatter is not a knowledge entry).

**Reversibility**: When M023 ships, the manual/skip branches become operator-opt-out fallbacks rather than pre-M023-only branches. The `pending_design_authored_manually` field stays — it is neutral with respect to M023 status (it tracks the manual-author cycle regardless of why the operator picked the `manual` verb).
```

(The actual `<today's ISO date>` is filled in by the executing dispatch.)

### Step 9 — Author `scripts/verify/m024-p07-suite.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p07-suite.sh
# M024/P07 phase suite — runs every per-task verify + every phase test.
# MEM002 parallel-array tracker.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Parallel arrays (bash 3.2 portable — no associative arrays).
i=0
add() { eval "name_$i=\"\$1\""; eval "cmd_$i=\"\$2\""; i=$((i + 1)); }

add "test-design-gate-degradation"        "bash $ROOT/tests/test-design-gate-degradation.sh"
add "test-design-gate-skip"               "bash $ROOT/tests/test-design-gate-skip.sh"
add "test-design-gate-manual"             "bash $ROOT/tests/test-design-gate-manual.sh"
add "m024-p07-design-gate-classify"       "bash $ROOT/scripts/verify/m024-p07-design-gate-classify.sh"
add "m024-p07-degradation-script"         "bash $ROOT/scripts/verify/m024-p07-degradation-script.sh"
add "m024-p07-pinned-message"             "bash $ROOT/scripts/verify/m024-p07-pinned-message.sh"
add "m024-p07-m023-probe"                 "bash $ROOT/scripts/verify/m024-p07-m023-probe.sh"
add "m024-p07-skip-branch"                "bash $ROOT/scripts/verify/m024-p07-skip-branch.sh"
add "m024-p07-manual-branch"              "bash $ROOT/scripts/verify/m024-p07-manual-branch.sh"
add "m024-p07-no-orphan-design-cmd"       "bash $ROOT/scripts/verify/m024-p07-no-orphan-design-cmd.sh"
add "m024-p07-approval-gate-design-verbs" "bash $ROOT/scripts/verify/m024-p07-approval-gate-design-verbs.sh"
add "m024-p07-write-confinement"          "bash $ROOT/scripts/verify/m024-p07-write-confinement.sh"
add "m024-p07-evaluate-md"                "bash $ROOT/scripts/verify/m024-p07-evaluate-md.sh"

n=$i
fail_count=0
j=0
while [ "$j" -lt "$n" ]; do
  eval "n_var=\$name_$j"
  eval "c_var=\$cmd_$j"
  if eval "$c_var" >/dev/null 2>&1; then
    echo "PASS: $n_var"
  else
    echo "FAIL: $n_var"
    fail_count=$((fail_count + 1))
  fi
  j=$((j + 1))
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: M024/P07 suite — design-gate degradation + skip/manual branches + no-orphan + write-confinement"
  exit 0
fi
echo "SUMMARY: $fail_count of $n P07 verifies failed"
exit 1
```

### Step 10 — Make all new scripts executable

```
chmod +x tests/test-design-gate-degradation.sh tests/test-design-gate-skip.sh tests/test-design-gate-manual.sh scripts/verify/m024-p07-no-orphan-design-cmd.sh scripts/verify/m024-p07-write-confinement.sh scripts/verify/m024-p07-evaluate-md.sh scripts/verify/m024-p07-suite.sh
```

## Must-Haves

- `tests/test-design-gate-degradation.sh` exists, exercises the FR-7 pinned message via `grep -F` on stderr, and asserts `recommended_command` is NOT `orchestrator:design` in pre-M023 proposals.
- `tests/test-design-gate-skip.sh` exists and asserts `design_skipped=true`, `pending_approval=false`, `proceeded_at` ISO8601 after a skip-verb invocation.
- `tests/test-design-gate-manual.sh` exists and asserts the halt-then-flip cycle (first invoke halts; author DESIGN.md; second invoke flips `design_authored_manually=true`).
- `scripts/verify/m024-p07-no-orphan-design-cmd.sh` exists and asserts no active-code-path `orchestrator:design` reference appears without an M023 probe gate.
- `scripts/verify/m024-p07-write-confinement.sh` exists and asserts P07 scripts confine writes to the intake dir + `/tmp`.
- `scripts/verify/m024-p07-evaluate-md.sh` exists and asserts `commands/evaluate.md` carries the "wired in P07" marker, the FR-7 pinned message verbatim, the manual/skip verb rows, and the degradation script reference.
- `commands/evaluate.md` Pre-M023 section names "wired in P07", embeds the FR-7 pinned message verbatim, includes manual/skip rows in the verb table, and references `scripts/intake/design-gate-degradation.sh`.
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) carries a new D-row documenting the `pending_design_authored_manually` schema addition.
- `scripts/verify/m024-p07-suite.sh` exists, uses MEM002 parallel-array tracking, and runs all 13 P07 verifies (3 phase tests + 10 per-claim verifies).
- Running `bash scripts/verify/m024-p07-suite.sh` exits 0 with a structured `PASS:` summary line.
- All P03/P06 phase suites remain green (no regressions introduced by the proposal-emit.sh and approval-gate.sh edits).
- AD-19 single-script-file shape preserved across all new scripts.
- Bash 3.2 portable.

## Verification

```
bash scripts/verify/m024-p07-suite.sh
bash scripts/verify/m024-p03-suite.sh
bash scripts/verify/m024-p06-suite.sh
```

Expected output: each suite prints a final `PASS: M024/P0X suite ...` line and exits 0. Per-test PASS lines precede the suite line.

## Inputs

### From Previous Tasks

- **T01** (`scripts/intake/design-gate-classify.sh`): consumed indirectly via `proposal-emit.sh` (T03 wiring) — the test suite exercises the classifier through the emitter on UI-tagged paragraphs.
- **T02** (`scripts/intake/design-gate-degradation.sh`): consumed by all three phase tests via `approval-gate.sh --verb manual|skip` (T03 wiring) and directly via `--branch manual|skip`. API: probe-only mode emits `m023_shipped=<bool>`; branch mode mutates frontmatter and emits the FR-7 pinned message to stderr.
- **T03** (`scripts/intake/proposal-emit.sh`, `scripts/intake/approval-gate.sh`, `templates/intake-proposal.md`): consumed by every phase test via the emit + approval-gate flow. Key API: `bash proposal-emit.sh --input <s> --intake-root <d>` emits a proposal whose `design_gate` reflects the classifier verdict; `bash approval-gate.sh --proposal <p> --verb <manual|skip>` validates and delegates to the degradation script.

### From Disk (Pre-existing)

- `scripts/verify/m024-p03-suite.sh`, `scripts/verify/m024-p06-suite.sh` — referenced as the "no regressions" canaries.
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — appended to (not modified in place).
- `commands/evaluate.md` — section replaced (lines 31–33).
- POSIX utilities: `grep -F -E -q -n -w`, `sed -i.bak`, `awk`, `head`, `mktemp`, `trap`, `chmod`, `cat`, `printf`.

## Constraints

- POSIX sh + bash 3.2 portable.
- AD-19 single-script-file shape across every new verify and test script.
- The P03 and P06 phase suites must remain green after T04 lands — no regressions in the existing behaviors.
- The D-row text must not introduce a new convention beyond what MEM031 / D024 already authorize; the entry is purely a record of the M024-local schema addition.
- The verb-table additions in `commands/evaluate.md` must follow the existing `revise` / `approve` / `cancel` row formatting so the doc stays internally consistent.
- The suite runner uses MEM002 parallel-array tracking exclusively (no `declare -A`, no associative arrays).

## Expected Output

All thirteen P07 verifies pass; the P07 suite exits 0; P03 and P06 suites remain green; `commands/evaluate.md` Pre-M023 section is updated to "wired in P07"; [`.orchestrator/DECISIONS.md`](../../../../decisions.md) carries the new D-row.
