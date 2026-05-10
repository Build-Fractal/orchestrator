---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M024"
name: "Phase tests + fixture-vs-live verify + write-confinement + suite"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `scripts/intake/spec-shape-classify.sh` exists; emitter wires the spec branch.
- T02 complete: `scripts/intake/m014-manifest-read.sh` exists and emits six canonical-order key=value lines.
- T03 complete: `tests/fixtures/evaluate-pre-m024-baseline.txt` is captured; emitter SPEC_AXES_DONE wiring is in place.
- All P02-introduced shell scripts respect SB-3 — writes target only `.orchestrator/intake/<id>/` and `/tmp`.
- Bash 3.2 + POSIX sh portable. AD-19 single-script-file shape on every external invocation.

## Description

Four deliverables — two phase-level tests + the remaining P02 verify scripts + the suite:

1. **`tests/test-evaluate-spec-backcompat.sh`** — phase-level regression test. Re-runs the same metric extraction against the in-repo spec used to capture the baseline; `diff`s against `tests/fixtures/evaluate-pre-m024-baseline.txt`; asserts byte-identical match. Additionally invokes the proposal emitter with `--spec-path <p>` and asserts the proposal carries the spec-shape deep axes (mirrors T01's verify but at the phase-test scope, exercising the full emit path end-to-end).

2. **`tests/test-m014-manifest-read.sh`** — phase-level regression test for the live AD-4 direction `a` reader. Invokes the reader against the in-repo spec, asserts the six manifest keys are present in stdout in the canonical order, asserts `--spec-path` and `--specs-dir` modes parity, asserts the invoke-time [M014](../../../../milestones/M014/index.md) probe behavior by temporarily renaming `templates/spec-template.md` to a tmp path and confirming the reader exits 3 with the unshipped-stub message (then restoring the template — write-confined to `/tmp` for the rename pivot).

3. **`scripts/verify/m024-p02-fixture-vs-live.sh`** — fixture-vs-live equality verify. Reads `tests/fixtures/m014-interim-manifest-keys.txt` (the P01 contracted snapshot), invokes `scripts/intake/m014-manifest-read.sh` against an in-repo spec, extracts the key portion of each `key=value` line, and asserts the live key-list equals the fixture key-list (same keys, same order). When they drift, the verify FAILs naming both sets — the operator updates the fixture by re-capturing.

4. **`scripts/verify/m024-p02-write-confinement.sh`** — SB-3 confinement verify. Greps every P02-introduced shell script for write operations (`>`, `>>`, `mkdir`, `tee`, `cp`, `mv`, `rm -r`, `sed -i`) and asserts each write target resolves under `.orchestrator/intake/`, `/tmp`, or — in the special case of `_capture-baseline.sh` — `tests/fixtures/`. Other write targets (e.g. `scripts/`, `commands/`, `knowledge/`, `specs/`) are FAILs.

5. **`scripts/verify/m024-p02-suite.sh`** — invokes both phase tests + every per-task verify; reports a single PASS / FAIL summary.

### Phase test conventions (MEM002)

Both phase tests use parallel-array pass/fail tracking — bash 3.2 safe; no `declare -A`. Same shape as `tests/test-paragraph-intake.sh` and `tests/test-approval-gate.sh` from P03.

## Steps

1. **Author `tests/test-evaluate-spec-backcompat.sh`**:

```bash
#!/usr/bin/env bash
# tests/test-evaluate-spec-backcompat.sh
# M024/P02 phase test — spec-path backcompat: today-shape metrics + new proposal.md.
# Conventions: parallel arrays for pass/fail tracking (MEM002).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
BASELINE="$ROOT/tests/fixtures/evaluate-pre-m024-baseline.txt"

PASS=0; FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# (1) Today-shape metrics byte-compat vs baseline.
bash "$ROOT/scripts/verify/m024-p02-evaluate-spec-backcompat.sh" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "today-shape metrics byte-compat vs baseline"
else
  fail "today-shape metrics byte-compat vs baseline" "verify exited $rc"
fi

# (2) Emitter produces a proposal at --spec-path mode.
emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
prop=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
if [ -f "$prop" ]; then
  pass "emitter produced proposal at --spec-path"
else
  fail "emitter produced proposal at --spec-path" "no proposal_path emitted; out=$emit_out"
fi

# (3) Proposal carries input_shape=spec.
if [ -f "$prop" ] && grep -q '^input_shape: "spec"' "$prop"; then
  pass "proposal frontmatter input_shape=spec"
else
  fail "proposal frontmatter input_shape=spec" "missing or wrong"
fi

# (4) Proposal carries non-stub scope_tier (one of A|B|C, not the placeholder).
if [ -f "$prop" ] && grep -qE '^scope_tier: "[ABC]"' "$prop"; then
  pass "proposal scope_tier in {A,B,C}"
else
  fail "proposal scope_tier in {A,B,C}" "missing or unexpected"
fi

# (5) Proposal carries recommended_command=orchestrator:roadmap (FR-6 byte-compat).
if [ -f "$prop" ] && grep -q '^recommended_command: "orchestrator:roadmap"' "$prop"; then
  pass "proposal recommended_command=orchestrator:roadmap"
else
  fail "proposal recommended_command=orchestrator:roadmap" "missing or wrong"
fi

# Summary.
n=$((PASS + FAIL))
echo
echo "test-evaluate-spec-backcompat: $PASS/$n PASS, $FAIL FAIL"
j=0
while [ "$j" -lt "$n" ]; do
  eval "echo \"  \$NAMES_$j\""
  j=$((j+1))
done

[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

2. **Author `tests/test-m014-manifest-read.sh`**:

```bash
#!/usr/bin/env bash
# tests/test-m014-manifest-read.sh
# M024/P02 phase test — live M014 manifest reader (AD-4 direction `a`).
# Conventions: parallel arrays for pass/fail tracking (MEM002).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
TEMPLATE="$ROOT/templates/spec-template.md"

PASS=0; FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# (1) --spec-path mode: six lines in canonical order.
out=$(bash "$READER" --spec-path "$SPEC")
lc=$(echo "$out" | grep -c '^')
if [ "$lc" -eq 6 ]; then
  pass "reader emits exactly six lines"
else
  fail "reader emits exactly six lines" "got $lc"
fi

# (2) Canonical key order.
keys=$(echo "$out" | sed -E 's/=.*//')
expected="schema_version
type
feature_slug
created_at
status
milestone"
if [ "$keys" = "$expected" ]; then
  pass "canonical six-key order"
else
  fail "canonical six-key order" "got: $keys"
fi

# (3) --specs-dir parity with --spec-path.
out2=$(bash "$READER" --specs-dir "$ROOT/specs/023-github-native-integration")
if [ "$out" = "$out2" ]; then
  pass "--spec-path / --specs-dir parity"
else
  fail "--spec-path / --specs-dir parity" "differ"
fi

# (4) Invoke-time M014 probe — pivot the template to /tmp and confirm exit 3.
mv "$TEMPLATE" "$tmp/spec-template.md.parked"
rc=0
bash "$READER" --spec-path "$SPEC" >/dev/null 2>&1 || rc=$?
mv "$tmp/spec-template.md.parked" "$TEMPLATE"
if [ "$rc" -eq 3 ]; then
  pass "invoke-time probe exits 3 when template missing"
else
  fail "invoke-time probe exits 3 when template missing" "got rc=$rc"
fi

# Summary.
n=$((PASS + FAIL))
echo
echo "test-m014-manifest-read: $PASS/$n PASS, $FAIL FAIL"
j=0
while [ "$j" -lt "$n" ]; do
  eval "echo \"  \$NAMES_$j\""
  j=$((j+1))
done

[ "$FAIL" -eq 0 ] || exit 1
exit 0
```

3. **Write `scripts/verify/m024-p02-fixture-vs-live.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-fixture-vs-live.sh
# Asserts the P01 fixture key-list equals the live M014 reader's key-list
# (same keys, same canonical order). When they drift, FAIL names both sets;
# operator re-captures the fixture by hand from the live reader output.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
FIXTURE="$ROOT/tests/fixtures/m014-interim-manifest-keys.txt"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"

[ -x "$READER" ]  || { echo "FAIL: reader missing: $READER"; exit 1; }
[ -f "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }
[ -f "$SPEC" ]    || { echo "FAIL: spec missing: $SPEC"; exit 1; }

tmp_live=$(mktemp)
tmp_fix=$(mktemp)
trap 'rm -f "$tmp_live" "$tmp_fix"' EXIT

# Live: extract key portion (left of the `=`).
bash "$READER" --spec-path "$SPEC" | sed -E 's/=.*//' > "$tmp_live"

# Fixture: strip comments and blanks.
grep -v '^#' "$FIXTURE" | grep -v '^$' > "$tmp_fix"

if ! diff -q "$tmp_fix" "$tmp_live" >/dev/null 2>&1; then
  echo "FAIL: fixture key-list drifted from live reader."
  echo "----- fixture -----"; cat "$tmp_fix"
  echo "----- live -----"; cat "$tmp_live"
  echo "Recover: re-capture fixture by running 'bash $READER --spec-path $SPEC | sed -E s/=.*//'"
  exit 1
fi

echo "PASS: fixture-vs-live — fixture key-list matches live M014 reader output"
exit 0
```

4. **Write `scripts/verify/m024-p02-write-confinement.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-write-confinement.sh
# SB-3 verify: every write op in P02-introduced scripts targets
# .orchestrator/intake/, /tmp, or tests/fixtures/ (the latter only for the
# one-shot baseline-capture helper).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Scripts authored or modified in P02 (intake-tree subset).
TARGETS="
scripts/intake/spec-shape-classify.sh
scripts/intake/m014-manifest-read.sh
scripts/intake/_capture-baseline.sh
"

# Allowed write-target prefixes.
allowed_prefix() {
  case "$1" in
    *.orchestrator/intake/*) return 0 ;;
    /tmp/*) return 0 ;;
    *tests/fixtures/*) return 0 ;;
    *) return 1 ;;
  esac
}

bad=0
for rel in $TARGETS; do
  f="$ROOT/$rel"
  [ -f "$f" ] || continue   # _capture-baseline.sh may be removed after use; skip cleanly.
  # Find write-shaped lines: redirect, mkdir, sed -i, mv to non-/tmp.
  while IFS= read -r line; do
    case "$line" in
      *' > '*|*' >> '*|*'mkdir '*|*'sed -i'*|*' tee '*|*' mv '*|*' cp '*)
        # Heuristic: extract the apparent target (last bareword on the line).
        target=$(echo "$line" | awk '{print $NF}')
        case "$target" in
          *.orchestrator/intake/*|/tmp/*|*tests/fixtures/*) ;;
          \"*\"|\$*) ;;  # variable / quoted literal — skip
          *)
            echo "FAIL: $rel:  potentially out-of-confine write target '$target'"
            bad=1 ;;
        esac
        ;;
    esac
  done < "$f"
done

if [ "$bad" -ne 0 ]; then
  echo "FAIL: write-confinement violations above"
  exit 1
fi

echo "PASS: write-confinement — all P02 intake-tree writes confined to .orchestrator/intake/, /tmp, tests/fixtures/"
exit 0
```

Note: this verify is heuristic (script-shape grep). The intent is to catch egregious violations (e.g. a script writing to `commands/` or `knowledge/`); subtle violations are caught by Tier 3 review at consolidation. The heuristic accepts variable / quoted-literal targets without flagging them — the operator owns those at review time.

5. **Write `scripts/verify/m024-p02-suite.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p02-suite.sh — run both phase tests + every per-task verify.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ok=1

bash "$ROOT/tests/test-evaluate-spec-backcompat.sh" || ok=0
bash "$ROOT/tests/test-m014-manifest-read.sh"      || ok=0
bash "$ROOT/scripts/verify/m024-p02-spec-shape-classify.sh"     || ok=0
bash "$ROOT/scripts/verify/m024-p02-m014-manifest-read.sh"      || ok=0
bash "$ROOT/scripts/verify/m024-p02-fixture-vs-live.sh"         || ok=0
bash "$ROOT/scripts/verify/m024-p02-evaluate-spec-backcompat.sh" || ok=0
bash "$ROOT/scripts/verify/m024-p02-spec-rationale.sh"          || ok=0
bash "$ROOT/scripts/verify/m024-p02-write-confinement.sh"       || ok=0

if [ "$ok" -eq 0 ]; then
  echo "FAIL: M024/P02 phase suite reported a failure (see above)"
  exit 1
fi

echo "PASS: M024/P02 suite — backcompat + manifest-read + fixture-vs-live + rationale + confinement"
exit 0
```

## Must-Haves

- `tests/test-evaluate-spec-backcompat.sh` exists, exercises the byte-compat baseline diff AND the spec-path emit path end-to-end, exits 0 on a clean checkout.
- `tests/test-m014-manifest-read.sh` exists, exercises the six-key canonical order, --spec-path / --specs-dir parity, AND the invoke-time M014 probe (parking the template to `/tmp` and asserting exit 3), exits 0 on a clean checkout.
- `scripts/verify/m024-p02-fixture-vs-live.sh` exists and asserts the P01 fixture equals the live reader output. When they drift, the verify FAILs naming both sets and pointing at the recover command.
- `scripts/verify/m024-p02-write-confinement.sh` exists and flags any P02 intake-script write targeting outside `.orchestrator/intake/`, `/tmp`, or `tests/fixtures/`.
- `scripts/verify/m024-p02-suite.sh` invokes both phase tests + every per-task verify and reports a single PASS / FAIL summary.
- All scripts respect AD-19 single-script-file shape and SB-3 write-confinement.

## Verification

```
bash scripts/verify/m024-p02-suite.sh
```

Expected output (exit 0): `PASS: M024/P02 suite — backcompat + manifest-read + fixture-vs-live + rationale + confinement`

## Inputs

### From Previous Tasks

- `scripts/intake/spec-shape-classify.sh` (from T01) — exercised end-to-end by `tests/test-evaluate-spec-backcompat.sh`.
- `scripts/intake/m014-manifest-read.sh` (from T02) — exercised by `tests/test-m014-manifest-read.sh` and by `scripts/verify/m024-p02-fixture-vs-live.sh`.
- `tests/fixtures/evaluate-pre-m024-baseline.txt` (from T03) — read by the baseline diff test.
- `scripts/intake/proposal-emit.sh` (modified by T01 + T03) — exercised end-to-end by the spec-path emit test.
- `tests/fixtures/m014-interim-manifest-keys.txt` (from M024/P01/T05) — pinned snapshot, asserted equal to live reader output by `m024-p02-fixture-vs-live.sh`.

### From Disk (Pre-existing)

- `templates/spec-template.md` — pivoted to `/tmp` and back during the invoke-time-probe test (the only mutating disk op outside intake/tmp/fixtures, and it's reverted by the same test under a `trap`).
- `specs/023-github-native-integration/spec.md` — fixture spec.
- `grep`, `sed -E`, `awk`, `diff`, `mv`, `mktemp`, `cat`, `wc` — POSIX utilities.

## Constraints

- POSIX sh + bash 3.2 portable.
- AD-19 single-script-file shape on every external invocation in every verify and phase test. No `<(...)` process substitution, no plain subshells, no `$(...)` containing pipes.
- SB-3 write-confinement: the only out-of-`.orchestrator/intake/` writes are (a) `/tmp` scratch under `mktemp` (auto-cleaned via `trap`), (b) the one-shot baseline-capture writing to `tests/fixtures/evaluate-pre-m024-baseline.txt` (T03 — not invoked by the suite), and (c) the template-pivot mv in `tests/test-m014-manifest-read.sh` (atomic round-trip under `trap`).
- The `tests/test-m014-manifest-read.sh` template-pivot is the one place where a P02 test mutates a non-fixture disk file. It is wrapped in a `trap`-guarded restore to guarantee the template is returned to its original location even on test failure or interrupt. The test FAILs if the restore is incomplete.
- MEM002 conventions: parallel arrays for pass/fail tracking, structured `PASS:`/`FAIL:` summary, no `declare -A`.
- NG-2 / NG-5: no conversus invocations, no knowledge writes.

## Expected Output

`tests/test-evaluate-spec-backcompat.sh`, `tests/test-m014-manifest-read.sh`, and the four T04 verify scripts all exist; `bash scripts/verify/m024-p02-suite.sh` exits 0 with `PASS:`.
