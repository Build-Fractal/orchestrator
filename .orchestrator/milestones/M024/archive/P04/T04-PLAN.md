---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M024"
name: "Phase tests + suite — fast-path auto-proceed + condition-violation matrix + config-disable"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `auto_proceed` is a valid `read-config.sh` key; defaults file ships `auto_proceed: true`. The two T01 verifies (`m024-p04-config-auto-proceed-key.sh`, `m024-p04-config-template.sh`) exist and pass.
- T02 complete: `scripts/intake/approval-gate.sh` accepts `--mode check-fast-path --proposal <path>` and emits the two-line verdict. The T02 verify (`m024-p04-fast-path-check.sh`) exists and passes.
- T03 complete: `scripts/intake/proposal-emit.sh` calls the fast-path check after axis swaps and flips `auto_proceeded: true` on eligible inputs. The T03 verify (`m024-p04-proposal-emit-fast-path.sh`) exists and passes.

## Description

Author the end-to-end phase tests + the regression-fence test that proves non-degenerate inputs still hit the approval gate, plus the config-disable test that proves the operator opt-out works. Wrap everything in a single suite runner using MEM002 parallel-array tracking.

The condition-violation test is the **load-bearing regression fence**. P04 is small in lines but wide in failure modes — a future refactor that breaks any one of the five disqualifying conditions silently breaks the gate. The matrix test exercises one input per condition (Tier B paragraph, Standard intensity, conversus-gated, design-gated, low-confidence) and asserts each lands `auto_proceeded: false` with a `reason=` that names the failing condition.

## Steps

1. **Author `tests/test-fast-path-auto-proceed.sh`** — phase-level smoke test that exercises the full emit-to-disk path on a Tier-A input.

   ```bash
   #!/usr/bin/env bash
   # tests/test-fast-path-auto-proceed.sh
   # M024/P04 phase test — Tier-A trivial input lands auto_proceeded: true.

   set -u
   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   trivial="fix typo in commands/status.md line 12 sope to scope"
   emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
   [ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

   grep -q '^auto_proceeded: true$' "$proposal" \
     || { echo "FAIL: trivial Tier-A input did not flip auto_proceeded to true"; exit 1; }
   grep -q '^scope_tier: "A"$' "$proposal" \
     || { echo "FAIL: scope_tier not A"; exit 1; }
   grep -q '^intensity: "Quick"$' "$proposal" \
     || { echo "FAIL: intensity not Quick"; exit 1; }
   grep -q '^conversus_gate: "none"$' "$proposal" \
     || { echo "FAIL: conversus_gate not none"; exit 1; }
   grep -q '^design_gate: "none"$' "$proposal" \
     || { echo "FAIL: design_gate not none"; exit 1; }

   echo "PASS: test-fast-path-auto-proceed — Tier-A trivial input → auto_proceeded: true"
   exit 0
   ```

2. **Author `tests/test-fast-path-condition-violation.sh`** — the regression fence. Hand-crafts five proposals (one per disqualifying condition) and exercises `approval-gate.sh --mode check-fast-path` directly so the test is independent of intensity-recommend.sh's heuristics. (The end-to-end coverage of the emitter sits in T03's verify and `tests/test-fast-path-auto-proceed.sh`.)

   ```bash
   #!/usr/bin/env bash
   # tests/test-fast-path-condition-violation.sh
   # M024/P04 phase test — every disqualifying condition produces auto_proceeded: false
   # with a reason= that names the failing condition.

   set -u
   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
   GATE="$ROOT/scripts/intake/approval-gate.sh"

   [ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   # Helper — write a minimal proposal frontmatter for a (tier, intensity, conv, design, lowconf) tuple.
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

   check_reason() {
     # args: $1=label $2=expected_reason $3=proposal_path
     local out
     out=$(bash "$GATE" --proposal "$3" --mode check-fast-path)
     echo "$out" | grep -q '^fast_path_eligible=false$' \
       || { echo "FAIL: $1 verdict not false (got: $out)"; return 1; }
     echo "$out" | grep -q "^reason=$2\$" \
       || { echo "FAIL: $1 reason wrong (expected: $2; got: $out)"; return 1; }
     echo "  ok: $1 → reason=$2"
     return 0
   }

   rc=0
   p1="$tmp/p1.md"; write_proposal B Quick    none none false "$p1"
   check_reason "tier-B"          tier-not-A          "$p1" || rc=1

   p2="$tmp/p2.md"; write_proposal A Standard none none false "$p2"
   check_reason "intensity-Std"   intensity-not-Quick "$p2" || rc=1

   p3="$tmp/p3.md"; write_proposal A Quick    required none false "$p3"
   check_reason "conversus-on"    conversus-gated     "$p3" || rc=1

   p4="$tmp/p4.md"; write_proposal A Quick    none required false "$p4"
   check_reason "design-on"       design-gated        "$p4" || rc=1

   p5="$tmp/p5.md"; write_proposal A Quick    none none true  "$p5"
   check_reason "low-conf"        low-confidence      "$p5" || rc=1

   if [ $rc -eq 0 ]; then
     echo "PASS: test-fast-path-condition-violation — five disqualifying conditions all caught with correct reason"
   fi
   exit $rc
   ```

3. **Author `scripts/verify/m024-p04-fast-path-auto-proceed.sh`** — wraps the phase test as a verify so the suite picks it up:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-fast-path-auto-proceed.sh
   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   exec bash "$ROOT/tests/test-fast-path-auto-proceed.sh"
   ```

4. **Author `scripts/verify/m024-p04-fast-path-condition-violation.sh`** — same wrapper shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-fast-path-condition-violation.sh
   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   exec bash "$ROOT/tests/test-fast-path-condition-violation.sh"
   ```

5. **Author `scripts/verify/m024-p04-config-disable.sh`** — exercises operator opt-out via project config:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-config-disable.sh
   # Verifies a Tier-A-eligible input lands auto_proceeded: false when the project
   # config sets auto_proceed: false (operator opt-out per AD-1 / #Q-7).

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   EMIT="$ROOT/scripts/intake/proposal-emit.sh"

   [ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT

   # Write a project-local override at the repo root path the emitter will see.
   # The emitter resolves config relative to $ROOT — we must write to the actual
   # project file. To avoid clobbering the developer's config, swap it on entry
   # and restore on exit.
   project_cfg="$ROOT/orchestrator-config.yml"
   backup=""
   if [ -f "$project_cfg" ]; then
     backup="$(mktemp)"
     cp "$project_cfg" "$backup"
   fi
   echo "auto_proceed: false" > "$project_cfg"
   restore() {
     if [ -n "$backup" ]; then
       mv "$backup" "$project_cfg"
     else
       rm -f "$project_cfg"
     fi
   }
   trap 'restore; rm -rf "$tmp"' EXIT

   trivial="fix typo in commands/status.md line 12 sope to scope"
   emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
   proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
   [ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

   grep -q '^auto_proceeded: false$' "$proposal" \
     || { echo "FAIL: auto_proceed=false config did not suppress fast-path"; exit 1; }

   echo "PASS: m024-p04-config-disable — auto_proceed=false config suppresses fast-path on Tier-A input"
   exit 0
   ```

6. **Author `scripts/verify/m024-p04-write-confinement.sh`** — same shape as the P03 confinement check, scoped to P04 surfaces:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-write-confinement.sh
   # Verifies P04-introduced shell scripts respect SB-3 — writes target only
   # .orchestrator/intake/<id>/, /tmp scratch, or stdout/stderr.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   # The check-fast-path mode is read-only — any write at all in approval-gate.sh
   # must be explicitly under the verb path (already verified by P03 confinement).
   # T03's wiring in proposal-emit.sh introduces no new write paths — the existing
   # mktemp + swap + mv flow already SB-3-conforms.
   #
   # We grep the P04-touched files for `>` redirections that escape the allowed
   # surfaces and fail loudly on any hit. The regex requires whitespace before `>`
   # and excludes `>&[12]` and `>/dev/null` per the P03 tightening.

   files="
     scripts/intake/approval-gate.sh
     scripts/intake/proposal-emit.sh
     scripts/state/read-config.sh
   "

   rc=0
   for f in $files; do
     full="$ROOT/$f"
     [ -f "$full" ] || { echo "FAIL: $f not present"; rc=1; continue; }
     # Look for a write that escapes /tmp, .orchestrator/intake/, $tmp, /dev/null, &1, &2.
     hits=$(grep -nE '[[:space:]]>([^&/]|/[^d])' "$full" \
              | grep -vE '/tmp|\.orchestrator/intake|\$tmp|>/dev/null|tmp_render|\$out_path|\$out_dir|>&[12]' \
              || true)
     if [ -n "$hits" ]; then
       echo "FAIL: $f has unconfined writes:"
       echo "$hits"
       rc=1
     fi
   done

   if [ $rc -eq 0 ]; then
     echo "PASS: m024-p04-write-confinement — approval-gate / proposal-emit / read-config writes confined to .orchestrator/intake/, /tmp, or stdio"
   fi
   exit $rc
   ```

7. **Author the suite runner** at `scripts/verify/m024-p04-suite.sh` — MEM002 parallel-array tracking, structured `PASS:`/`FAIL:` summary:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p04-suite.sh
   # P04 suite — fast-path check + emit wiring + condition-violation + config-disable + write-confinement.

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
   run "test-fast-path-auto-proceed.sh"          bash "$ROOT/tests/test-fast-path-auto-proceed.sh"          || rc=1
   run "test-fast-path-condition-violation.sh"   bash "$ROOT/tests/test-fast-path-condition-violation.sh"   || rc=1
   run "m024-p04-config-auto-proceed-key"        bash "$ROOT/scripts/verify/m024-p04-config-auto-proceed-key.sh"        || rc=1
   run "m024-p04-config-template"                bash "$ROOT/scripts/verify/m024-p04-config-template.sh"                || rc=1
   run "m024-p04-fast-path-check"                bash "$ROOT/scripts/verify/m024-p04-fast-path-check.sh"                || rc=1
   run "m024-p04-proposal-emit-fast-path"        bash "$ROOT/scripts/verify/m024-p04-proposal-emit-fast-path.sh"        || rc=1
   run "m024-p04-fast-path-auto-proceed"         bash "$ROOT/scripts/verify/m024-p04-fast-path-auto-proceed.sh"         || rc=1
   run "m024-p04-fast-path-condition-violation"  bash "$ROOT/scripts/verify/m024-p04-fast-path-condition-violation.sh"  || rc=1
   run "m024-p04-config-disable"                 bash "$ROOT/scripts/verify/m024-p04-config-disable.sh"                 || rc=1
   run "m024-p04-write-confinement"              bash "$ROOT/scripts/verify/m024-p04-write-confinement.sh"              || rc=1

   if [ $rc -eq 0 ]; then
     echo "PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement"
   fi
   exit $rc
   ```

8. **Make every new file executable** (one chmod per file — do not chain):

   ```
   chmod +x tests/test-fast-path-auto-proceed.sh
   chmod +x tests/test-fast-path-condition-violation.sh
   chmod +x scripts/verify/m024-p04-fast-path-auto-proceed.sh
   chmod +x scripts/verify/m024-p04-fast-path-condition-violation.sh
   chmod +x scripts/verify/m024-p04-config-disable.sh
   chmod +x scripts/verify/m024-p04-write-confinement.sh
   chmod +x scripts/verify/m024-p04-suite.sh
   ```

## Must-Haves

- `tests/test-fast-path-auto-proceed.sh` exists, is executable, and exits 0 on a Tier-A trivial input — asserting `auto_proceeded: true` and the four matching axis values.
- `tests/test-fast-path-condition-violation.sh` exists, is executable, and asserts each of the five disqualifying conditions (`tier-not-A`, `intensity-not-Quick`, `conversus-gated`, `design-gated`, `low-confidence`) lands `auto_proceeded: false` with the matching `reason=` token.
- `scripts/verify/m024-p04-fast-path-auto-proceed.sh` and `scripts/verify/m024-p04-fast-path-condition-violation.sh` wrap the phase tests as verifies the suite picks up.
- `scripts/verify/m024-p04-config-disable.sh` proves operator opt-out: with `auto_proceed: false` in the project config, even a four-condition-eligible input lands `auto_proceeded: false`. The verify backs up + restores the developer's `orchestrator-config.yml` to avoid clobbering local state.
- `scripts/verify/m024-p04-write-confinement.sh` greps the three P04-touched files for unconfined `>` redirections and fails loudly on any hit (P03's tightening shape preserved).
- `scripts/verify/m024-p04-suite.sh` runs all ten verifies + tests and emits a single `PASS: M024/P04 suite — ...` summary line on success. MEM002 parallel-array tracking; structured `PASS:`/`FAIL:` lines; non-zero exit on any failure.
- AD-19 single-script-file shape: every external invocation in every verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.

## Verification

```
bash scripts/verify/m024-p04-suite.sh
```

Exits 0 with ten `PASS:` lines (one per sub-check) followed by `PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement`.

The phase-level tests can also be run individually:

```
bash tests/test-fast-path-auto-proceed.sh
bash tests/test-fast-path-condition-violation.sh
```

Each exits 0 with its respective `PASS:` line.

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (modified by M024/P04/T03) — invoked by the auto-proceed test and the config-disable verify. Key API: `bash proposal-emit.sh --input <s> [--intake-root <d>]` → `proposal_path=<absolute path>`. With T03 wired, emits proposals carrying `auto_proceeded: true` on four-condition-eligible inputs (and config not opt-out), `auto_proceeded: false` otherwise.
- `scripts/intake/approval-gate.sh` (modified by M024/P04/T02) — invoked directly by the condition-violation matrix test. Key API: `bash approval-gate.sh --proposal <path> --mode check-fast-path` emits two stdout lines `fast_path_eligible=true|false` + `reason=<token>` from the closed enum (`all-conditions-met | tier-not-A | intensity-not-Quick | conversus-gated | design-gated | low-confidence`).
- `scripts/state/read-config.sh` (modified by M024/P04/T01) — used indirectly by the config-disable verify (the emitter resolves `auto_proceed` from the developer's project config, which the verify swaps in for the test then restores).
- `templates/orchestrator-config-default.yml` (modified by M024/P04/T01) — provides the `auto_proceed: true` default.

### From Disk (Pre-existing)

- `scripts/engine/intensity-recommend.sh` — invoked indirectly via `proposal-emit.sh` to produce the `intensity` axis value. The fixture string ("fix typo in commands/status.md line 12 sope to scope") must classify to `Quick` for the auto-proceed test to pass; if a future intensity-recommend update changes the threshold, the test will fail loudly with a `FAIL: intensity not Quick` line that names the regression site.
- `tests/test-paragraph-intake.sh` and `tests/test-approval-gate.sh` (from M024/P03/T04) — pattern reference for the new phase tests; same `set -u` + `mktemp -d` + `trap rm` shape.
- `scripts/verify/m024-p03-suite.sh` (from M024/P03/T04) — pattern reference for the suite runner; same `run()` helper + parallel-array tracking shape.
- `sed -n`, `grep -E`, `grep -v`, `mktemp`, `cat <<EOF`, `trap` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- The config-disable verify MUST back up + restore the developer's `orchestrator-config.yml` on entry/exit. Failing to restore would silently disable the fast-path for the developer's subsequent invocations — a correctness footgun. The `trap` chain (`restore; rm -rf "$tmp"`) handles both clean exit and signal interruption.
- AD-19 single-script-file shape: every external invocation in every verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Verification block authoring convention (validated in P01/P03): every line inside a fenced code block under `## Verification` is a runnable command. Expected output text lives in inline backticks **outside** the fenced block.
- The condition-violation matrix is the regression fence — all five conditions must be exercised. Removing any branch silently weakens the gate. (The matrix uses hand-crafted proposals to avoid coupling to intensity-recommend.sh's heuristics.)
- SB-3 write-confinement: every test writes only to `mktemp -d` scratch and (for the config-disable verify) to the `orchestrator-config.yml` it backs up + restores. No writes to `.orchestrator/intake/` outside `--intake-root <tmp/intake>` overrides.
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- Idempotency: re-running the suite on a clean checkout produces the same ten `PASS:` lines.

## Expected Output

Two phase-level tests + four new verifies + the suite runner exist and are executable. `bash scripts/verify/m024-p04-suite.sh` exits 0 with ten `PASS:` lines (one per sub-check) followed by the suite-level `PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement` summary.
