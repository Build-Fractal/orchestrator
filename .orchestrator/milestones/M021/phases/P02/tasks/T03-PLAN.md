---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M021"
name: "Ship scripts/verify/m021-p02-linter-v2.sh + fixture seeds under tests/fixtures/m021-p02/"
depends_on: ["T01", "T02"]
---

## Prerequisites

T01 has shipped the extended `scripts/verify/anti-pattern-lint.sh` with all five Class B detectors + scope widening + marker opt-in + preserved Class A behavior.

T02 has appended AP-005..AP-009 to `ANTIPATTERNS.md`. Each new entry names a P01 wrapper (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, or `scripts/util/run-probe.sh`) and cites M011/P05–P07.

The `tests/fixtures/` directory exists at the project root and holds per-scenario fixture sub-directories (see `tests/fixtures/auto-budget/`, `tests/fixtures/knowledge-knowledge/`, etc.). The convention is one sub-directory per milestone/phase/scenario.

`scripts/verify/run-suite.sh` discovers gate scripts via filename pattern `m<milestone>-p<phase>-*.sh` (lowercase) — the new gate must match `m021-p02-*.sh` to be auto-discovered.

## Description

Create two deliverables:

1. **Fixture seeds** under `tests/fixtures/m021-p02/` — ten markdown files, each containing a minimal bash fence that trips exactly one detector (or zero detectors for the `clean.md` fixture, or suppressed detectors for `suppressed.md`). Fixtures live outside the linter's default scan roots so they do not pollute the main-project sweep.

2. **Gate script** `scripts/verify/m021-p02-linter-v2.sh` that invokes `scripts/verify/anti-pattern-lint.sh --fixture <path>` for each seed and asserts the expected classification:
   - Three Class A fixtures must produce violations tagged `[AP-004]`.
   - Five Class B fixtures must produce violations tagged `[AP-005]` through `[AP-009]` respectively.
   - The `suppressed.md` fixture must produce zero violations (M016 suppression semantics preserved).
   - The `clean.md` fixture must produce zero violations.
   - `ANTIPATTERNS.md` must contain all five new AP anchors and each must name at least one `scripts/util/*.sh` wrapper path.

The gate emits `PASS:` / `FAIL:` lines per assertion and a final `PASS: m021-p02-linter-v2.sh` line on success (M016 gate convention).

## Steps

### Step 1: Create tests/fixtures/m021-p02/class-a-cmd-sub.md

```markdown
# Class A fixture: command substitution

Minimal bash fence containing $(...) — expected to trip AP-004.

```bash
bash scripts/foo.sh --completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```
```

### Step 2: Create tests/fixtures/m021-p02/class-a-backtick.md

```markdown
# Class A fixture: backtick command substitution

```bash
result=`date -u +%Y-%m-%dT%H:%M:%SZ`
```
```

### Step 3: Create tests/fixtures/m021-p02/class-a-brace.md

```markdown
# Class A fixture: brace expansion

```bash
bash scripts/foo.sh {alpha,beta}
```
```

### Step 4: Create tests/fixtures/m021-p02/class-b-simple-expansion.md

```markdown
# Class B fixture: simple-expansion

```bash
bash scripts/verify/run-suite.sh m021 P02; echo "RC=$?"
```
```

### Step 5: Create tests/fixtures/m021-p02/class-b-redirect-cmd-sub.md

```markdown
# Class B fixture: redirect-cmd-sub

```bash
bash scripts/foo.sh > "$(mktemp)" 2>&1
```
```

### Step 6: Create tests/fixtures/m021-p02/class-b-quoted-brace.md

```markdown
# Class B fixture: quoted-brace

```bash
awk "BEGIN{print 42}" /dev/null
```
```

### Step 7: Create tests/fixtures/m021-p02/class-b-heredoc-expansion.md

```markdown
# Class B fixture: heredoc-expansion

```bash
cat > /tmp/probe.sh <<EOF
echo $HOME
EOF
```
```

### Step 8: Create tests/fixtures/m021-p02/class-b-task-plan-compound-PAYLOAD.md

The filename suffix `-PAYLOAD.md` alone is NOT enough — the task-plan-compound detector requires the path to match `*/tasks/*-PAYLOAD.md`. Since the fixture is fed via `--fixture <path>`, and the linter derives `is_task_payload` from `real_file` matching `*/tasks/*-PAYLOAD.md`, the gate script invokes this fixture with a `--fixture` path that includes a synthetic `/tasks/` segment. Simplest mechanism: the gate creates a temporary symlink or copy into a tempdir that contains `tasks/` as a literal component, then passes that path.

Fixture content:

```markdown
# Class B fixture: task-plan-compound (only fires on */tasks/*-PAYLOAD.md scope)

```bash
for f in specs/*.md ; do bash scripts/foo.sh "$f" ; done
```
```

### Step 9: Create tests/fixtures/m021-p02/suppressed.md

```markdown
# Suppression fixture: forbidden region must not flag

```bash
# FORBIDDEN: the following lines demonstrate a forbidden pattern
bash foo.sh --at=$(date)
result=`echo x`
bash {a,b}.sh
```
```

### Step 10: Create tests/fixtures/m021-p02/clean.md

```markdown
# Clean fixture: no violations expected

```bash
bash scripts/verify/run-suite.sh m021 P02
```
```

### Step 11: Create scripts/verify/m021-p02-linter-v2.sh

Author the gate. It drives the linter against each fixture and asserts expected tags. Bash 3.2 safe. The gate itself is a script — it may use compound bash internally.

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p02-linter-v2.sh — Gate for anti-pattern-lint.sh v2 coverage.
#
# Asserts:
#   - Class A detectors (AP-004) still fire on the three class-a-*.md fixtures.
#   - Class B detectors (AP-005..AP-009) fire on each corresponding class-b-*.md fixture.
#   - suppressed.md yields zero violations.
#   - clean.md yields zero violations.
#   - ANTIPATTERNS.md contains AP-005..AP-009 each naming a scripts/util/*.sh path.
#
# Exit: 0 on all assertions pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINTER="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
FIX_DIR="${REPO_ROOT}/tests/fixtures/m021-p02"
AP="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0

assert_contains() {
  # $1 = label, $2 = haystack text, $3 = needle
  if printf '%s' "$2" | grep -qF "$3"; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (missing substring: $3)"
    fail_count=$((fail_count + 1))
  fi
}

assert_empty() {
  # $1 = label, $2 = rc from linter, $3 = output
  if [ "$2" = "0" ] && ! printf '%s' "$3" | grep -q 'LINT FAIL'; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (exit=$2, output=$3)"
    fail_count=$((fail_count + 1))
  fi
}

run_lint() {
  # $1 = fixture path; prints linter stdout; returns linter exit code
  bash "$LINTER" --fixture "$1" 2>&1
}

# --- Class A fixtures ---
out="$(run_lint "$FIX_DIR/class-a-cmd-sub.md" || true)"
assert_contains "Class A: command substitution flagged [AP-004]" "$out" "[AP-004]"

out="$(run_lint "$FIX_DIR/class-a-backtick.md" || true)"
assert_contains "Class A: backtick flagged [AP-004]" "$out" "[AP-004]"

out="$(run_lint "$FIX_DIR/class-a-brace.md" || true)"
assert_contains "Class A: brace expansion flagged [AP-004]" "$out" "[AP-004]"

# --- Class B fixtures ---
out="$(run_lint "$FIX_DIR/class-b-simple-expansion.md" || true)"
assert_contains "Class B: simple-expansion flagged [AP-005]" "$out" "[AP-005]"
assert_contains "Class B: simple-expansion hint names with-env.sh" "$out" "scripts/util/with-env.sh"

out="$(run_lint "$FIX_DIR/class-b-redirect-cmd-sub.md" || true)"
assert_contains "Class B: redirect-cmd-sub flagged [AP-006]" "$out" "[AP-006]"

out="$(run_lint "$FIX_DIR/class-b-quoted-brace.md" || true)"
assert_contains "Class B: quoted-brace flagged [AP-007]" "$out" "[AP-007]"

out="$(run_lint "$FIX_DIR/class-b-heredoc-expansion.md" || true)"
assert_contains "Class B: heredoc-expansion flagged [AP-008]" "$out" "[AP-008]"
assert_contains "Class B: heredoc-expansion hint names run-probe.sh" "$out" "scripts/util/run-probe.sh"

# --- task-plan-compound requires */tasks/*-PAYLOAD.md path shape ---
# Stage the fixture under a tempdir with a tasks/ segment.
_tmpdir="$(mktemp -d)"
mkdir -p "$_tmpdir/tasks"
cp "$FIX_DIR/class-b-task-plan-compound-PAYLOAD.md" "$_tmpdir/tasks/T99-PAYLOAD.md"
out="$(run_lint "$_tmpdir/tasks/T99-PAYLOAD.md" || true)"
assert_contains "Class B: task-plan-compound flagged [AP-009]" "$out" "[AP-009]"
rm -rf "$_tmpdir"

# --- Suppression + clean fixtures: zero violations ---
out="$(bash "$LINTER" --fixture "$FIX_DIR/suppressed.md" 2>&1)"
rc=$?
assert_empty "Suppressed region yields zero violations" "$rc" "$out"

out="$(bash "$LINTER" --fixture "$FIX_DIR/clean.md" 2>&1)"
rc=$?
assert_empty "Clean fixture yields zero violations" "$rc" "$out"

# --- ANTIPATTERNS.md contains AP-005..AP-009 each naming a P01 wrapper ---
for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -q "^## ${ap}:" "$AP"; then
    echo "PASS: ANTIPATTERNS.md contains ${ap} heading"
  else
    echo "FAIL: ANTIPATTERNS.md missing ${ap} heading"
    fail_count=$((fail_count + 1))
  fi
done

# Each AP-00X section should name at least one scripts/util/*.sh path.
# Extract AP-005..AP-009 body blocks and grep each for scripts/util/.
awk '
  /^## AP-005:/ {section="AP-005"; capture=1; next}
  /^## AP-006:/ {section="AP-006"; capture=1; next}
  /^## AP-007:/ {section="AP-007"; capture=1; next}
  /^## AP-008:/ {section="AP-008"; capture=1; next}
  /^## AP-009:/ {section="AP-009"; capture=1; next}
  /^## / {capture=0; section=""}
  capture && /scripts\/util\// {print section}
' "$AP" | sort -u > "$_tmpdir.ap-wrappers.txt" 2>/dev/null || true

for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -q "^${ap}$" "$_tmpdir.ap-wrappers.txt" 2>/dev/null; then
    echo "PASS: ${ap} names a scripts/util/ wrapper"
  else
    echo "FAIL: ${ap} does not name any scripts/util/ wrapper"
    fail_count=$((fail_count + 1))
  fi
done
rm -f "$_tmpdir.ap-wrappers.txt"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p02-linter-v2.sh"
  exit 0
fi
echo "FAIL: m021-p02-linter-v2.sh ($fail_count failures)"
exit 1
```

### Step 12: Run the gate

`bash scripts/verify/m021-p02-linter-v2.sh` must exit 0 with final line `PASS: m021-p02-linter-v2.sh`.

## Must-Haves

- Ten fixture files exist under `tests/fixtures/m021-p02/`: three Class A seeds, five Class B seeds, one suppressed seed, one clean seed.
- `scripts/verify/m021-p02-linter-v2.sh` exists, is executable as `bash <path>`, and drives the linter against each fixture.
- Gate asserts Class A tags (`[AP-004]`) on three Class A fixtures.
- Gate asserts Class B tags (`[AP-005]`..`[AP-009]`) on five Class B fixtures.
- Gate asserts the `suppressed.md` and `clean.md` fixtures produce zero violations.
- Gate asserts `ANTIPATTERNS.md` contains headings for AP-005..AP-009 and each section names a `scripts/util/*.sh` path.
- Fixtures live outside the linter's default scan roots — the main-project sweep `bash scripts/verify/anti-pattern-lint.sh` continues to return zero violations.

## Verification

- `bash scripts/verify/m021-p02-linter-v2.sh` exits 0 with final line `PASS: m021-p02-linter-v2.sh`.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 against the live repo (fixtures do not leak into the default sweep because `tests/fixtures/` is not in the scan roots).

## Inputs

### From Previous Tasks

- `scripts/verify/anti-pattern-lint.sh` (from T01)
  - Key API: `bash anti-pattern-lint.sh [--fixture <path>]`
  - Key behavior: emits lines tagged `[AP-004]` for Class A violations, `[AP-005]` through `[AP-009]` for Class B; exit 0 clean, 1 dirty.
- `ANTIPATTERNS.md` (from T02)
  - Key structure: headings `## AP-005:` through `## AP-009:`; each section body names a `scripts/util/*.sh` path.

### From Disk (Pre-existing)

- `tests/fixtures/` — existing fixture parent directory.
- `scripts/verify/run-suite.sh` — discovers `m021-p02-*.sh` by filename pattern.
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — referenced by name in fixture content and in gate assertions (path strings, not executed).

## Constraints

- Fixtures MUST NOT trigger the main-project linter sweep. `tests/fixtures/` is not in the default scan roots (`commands/`, `templates/`, `scripts/dispatch/lib/`, `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`), so fixtures are invisible unless explicitly fed via `--fixture`.
- Gate script is Bash 3.2 compatible (constitution IX).
- Gate script uses single-script-file shape at its invocation point — the gate itself is the script. Its internals may use pipes and `$(...)` freely (MEM004, AP-004 scope-of-enforcement note).
- No speculative fixtures (constitution XIV). Exactly ten files, one per intended assertion.

## Expected Output

- `tests/fixtures/m021-p02/` contains ten markdown files.
- `scripts/verify/m021-p02-linter-v2.sh` exists and is runnable.
- `bash scripts/verify/m021-p02-linter-v2.sh` exits 0 with `PASS: m021-p02-linter-v2.sh` on the final line.
