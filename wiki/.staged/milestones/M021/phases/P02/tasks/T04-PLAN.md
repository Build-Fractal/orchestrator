---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M021"
name: "Ship scripts/verify/m021-p02-linter-scope.sh + document marker convention in references/engine.md"
depends_on: ["T01", "T02"]
---

## Prerequisites

T01 has shipped the extended `scripts/verify/anti-pattern-lint.sh` with scope widening + `<!-- agent-facing -->` marker opt-in. T02 has appended AP-005..AP-009 to `ANTIPATTERNS.md`.

`references/engine.md` exists at the project root (245 lines) and already documents the engine's pipeline, usage, and lifecycle. A new subsection for the linter's marker convention fits naturally near the end or adjacent to any existing "enforcement" / "verification" discussion.

Scope model (from [`.orchestrator/milestones/M021/M021-CONTEXT.md`](../../../../../milestones/M021/M021-CONTEXT.md) OQ-3):
- Scanned by default: `commands/**/*.md`, `templates/**/*.md`, `scripts/dispatch/lib/**/*.sh`, `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`.
- Scanned only when opted in via `<!-- agent-facing -->`: `specs/**/*.md`, `references/**/*.md`, `docs/**/*.md`.

## Description

Create two deliverables:

1. **Gate script** `scripts/verify/m021-p02-linter-scope.sh` that asserts scope boundaries:
   - A seeded bad file under `specs/` (violation-triggering content, no marker) is NOT flagged when the linter sweeps its default roots.
   - The same file, when a `<!-- agent-facing -->` marker is added, IS flagged.
   - A seeded bad file under `references/` and `docs/` behave identically (opt-in via marker).
   - The existing real tree under `specs/`, `references/`, `docs/` — none of which should contain the marker — continues to produce zero new violations (no regression on human-facing docs).

2. **References doc update** — append a subsection to `references/engine.md` (or the nearest appropriate reference doc) titled "Agent-Facing Marker Convention" that documents:
   - What the marker is: `<!-- agent-facing -->` as a literal HTML-comment line.
   - Where it is needed: any markdown file under `specs/`, `references/`, or `docs/` that contains bash examples a subagent should treat as authoritative (vs. illustrative prose for human readers).
   - Where it is NOT needed: files under `commands/`, `templates/`, `scripts/dispatch/lib/`, `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` are in-scope by default.
   - Placement: anywhere before the first fenced code block in the file.
   - One example showing marker placement and the resulting linter behavior.

The scope-gate script uses the two scope-boundary fixtures seeded under `tests/fixtures/m021-p02/` (`scope-excluded-spec.md`, `scope-opted-in-spec.md`). These are authored by T04 — they were not in T03's ten-fixture list.

## Steps

### Step 1: Create tests/fixtures/m021-p02/scope-excluded-spec.md

Content (simulates a spec-style markdown file that happens to contain a violation-shape bash fence — but has NO agent-facing marker):

```markdown
# Scope fixture: specs-like file WITHOUT the agent-facing marker

This file represents a file under specs/, references/, or docs/ that does NOT
opt into linter scanning. The bash fence below trips a Class A detector if the
linter sees it, but the linter should never see it when sweeping default roots.

```bash
bash scripts/foo.sh --at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```
```

### Step 2: Create tests/fixtures/m021-p02/scope-opted-in-spec.md

Content (same file content as Step 1, PLUS the marker above the fence):

```markdown
# Scope fixture: specs-like file WITH the agent-facing marker

<!-- agent-facing -->

This file represents a file under specs/, references/, or docs/ that DOES opt
into linter scanning via the marker above. The bash fence below trips a Class A
detector and the linter should flag it when the file is scoped in.

```bash
bash scripts/foo.sh --at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```
```

### Step 3: Create scripts/verify/m021-p02-linter-scope.sh

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p02-linter-scope.sh — Gate for anti-pattern-lint.sh
# scope-boundary enforcement and <!-- agent-facing --> marker opt-in.
#
# Asserts:
#   - A specs-style fixture WITHOUT the marker is NOT flagged when present
#     inside a simulated specs/ root during the linter's default sweep.
#   - The same fixture WITH the marker IS flagged in the default sweep.
#   - The live repo's specs/, references/, docs/ trees — none of which should
#     carry the marker today — produce zero new violations under the current
#     linter (baseline preservation).
#   - references/engine.md documents the <!-- agent-facing --> convention.
#
# Exit: 0 on all assertions pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINTER="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
FIX_DIR="${REPO_ROOT}/tests/fixtures/m021-p02"
ENGINE_DOC="${REPO_ROOT}/references/engine.md"

fail_count=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

# --- Assertion 1: fixture WITHOUT marker, fed via --fixture, is in-scope by
#     design (--fixture forces scan). Sanity check: the content would trip
#     Class A if scanned.
out="$(bash "$LINTER" --fixture "$FIX_DIR/scope-excluded-spec.md" 2>&1 || true)"
if printf '%s' "$out" | grep -q '\[AP-004\]'; then
  pass "fixture content is Class A when scanned via --fixture"
else
  fail "fixture content failed to trip Class A via --fixture"
fi

# --- Assertion 2: scope-excluded fixture is NOT picked up by the default
#     sweep because tests/fixtures/ is not in the default scan roots AND
#     there is no marker. Run the default sweep and confirm the fixture
#     path does not appear in the violation report.
out="$(bash "$LINTER" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'scope-excluded-spec.md'; then
  fail "default sweep unexpectedly picked up scope-excluded-spec.md"
else
  pass "default sweep correctly skips tests/fixtures/ (unmarked)"
fi

# --- Assertion 3: marker-gated discovery works on synthetic specs/ tree.
#     Create a tempdir with specs/, references/, docs/ subdirs; copy the
#     marked fixture into each; run the linter in the tempdir via a
#     PROJECT_ROOT override and confirm each is flagged.
_tmp="$(mktemp -d)"
mkdir -p "$_tmp/specs" "$_tmp/references" "$_tmp/docs"
mkdir -p "$_tmp/commands" "$_tmp/templates" "$_tmp/scripts/dispatch/lib" "$_tmp/.orchestrator/milestones"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/specs/opted-in.md"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/references/opted-in.md"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/docs/opted-in.md"

# Copy the linter into the tempdir so its $PROJECT_ROOT resolution lands
# on the tempdir. (Linter derives PROJECT_ROOT from its own location:
# $(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd).)
mkdir -p "$_tmp/scripts/verify"
cp "$LINTER" "$_tmp/scripts/verify/anti-pattern-lint.sh"
out="$(bash "$_tmp/scripts/verify/anti-pattern-lint.sh" 2>&1 || true)"

if printf '%s' "$out" | grep -q 'specs/opted-in.md'; then
  pass "marker opts specs/ file into default sweep"
else
  fail "marker failed to opt specs/ file into default sweep"
fi

if printf '%s' "$out" | grep -q 'references/opted-in.md'; then
  pass "marker opts references/ file into default sweep"
else
  fail "marker failed to opt references/ file into default sweep"
fi

if printf '%s' "$out" | grep -q 'docs/opted-in.md'; then
  pass "marker opts docs/ file into default sweep"
else
  fail "marker failed to opt docs/ file into default sweep"
fi

# --- Assertion 4: unmarked specs-style file in the synthetic tree is NOT
#     flagged. Replace the marked fixture with the excluded (unmarked)
#     variant and rerun.
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/specs/opted-in.md"
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/references/opted-in.md"
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/docs/opted-in.md"
out="$(bash "$_tmp/scripts/verify/anti-pattern-lint.sh" 2>&1 || true)"

if printf '%s' "$out" | grep -qE 'specs/opted-in.md|references/opted-in.md|docs/opted-in.md'; then
  fail "unmarked files unexpectedly appeared in sweep output"
else
  pass "unmarked files correctly excluded from default sweep"
fi

rm -rf "$_tmp"

# --- Assertion 5: live repo tree produces zero linter violations. This
#     guards against a T01 scope-widening change that accidentally adds
#     real-world violations to commands/, templates/, dispatch/lib/, or
#     task-PAYLOAD files.
out="$(bash "$LINTER" 2>&1 || true)"
if printf '%s' "$out" | grep -q '^LINT PASS'; then
  pass "live repo sweep reports LINT PASS"
else
  fail "live repo sweep produced violations: $out"
fi

# --- Assertion 6: references/engine.md documents the marker convention.
if grep -q 'agent-facing' "$ENGINE_DOC"; then
  pass "references/engine.md mentions 'agent-facing'"
else
  fail "references/engine.md does not document the agent-facing marker"
fi

if grep -qF '<!-- agent-facing -->' "$ENGINE_DOC"; then
  pass "references/engine.md contains literal marker example"
else
  fail "references/engine.md missing literal <!-- agent-facing --> example"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p02-linter-scope.sh"
  exit 0
fi
echo "FAIL: m021-p02-linter-scope.sh ($fail_count failures)"
exit 1
```

### Step 4: Append marker-convention subsection to references/engine.md

Add a new top-level subsection to `references/engine.md` (append at end or insert before the final "See also" block, whichever exists). Content:

```markdown
---

## Agent-Facing Marker Convention

The anti-pattern linter (`scripts/verify/anti-pattern-lint.sh`) enforces shape
rules against markdown files a subagent may read as authoritative. By default
it scans:

- `commands/**/*.md`
- `templates/**/*.md`
- `scripts/dispatch/lib/**/*.sh`
- `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`

Files under `specs/`, `references/`, and `docs/` are **excluded by default** —
they often contain illustrative bash for human readers that would trip the
shape heuristics without cause.

To opt a specific file under `specs/`, `references/`, or `docs/` into linter
scanning, place the literal HTML comment marker anywhere before the first
fenced code block:

```
<!-- agent-facing -->
```

Once the marker is present, the linter sweeps that file on every run. Without
the marker, the linter skips it even if other files in the same directory are
opted in.

### When to add the marker

Add the marker to a specs/references/docs file when:

- The file contains a canonical bash recipe that a subagent is expected to
  copy verbatim into a Bash tool call (e.g., a migration guide with exact
  commands).
- The file is referenced from a dispatch payload or task plan as
  "follow the steps in `docs/<file>.md`".

Leave the marker off when the file is human-facing documentation, conceptual
prose, or contains bash only to illustrate what *not* to do.

### Example

```markdown
# My Runbook

<!-- agent-facing -->

Run these steps in order:

```bash
bash scripts/verify/run-suite.sh m999 P01
```
```

With the marker, the fenced bash above is subject to the same Class A +
Class B detectors that guard `commands/` and `templates/`. Without it, the
same file is invisible to the linter.

See `ANTIPATTERNS.md#AP-004` (Class A) and `AP-005` through `AP-009` (Class B)
for the full pattern catalog and remediation wrappers.
```

### Step 5: Run the gate

`bash scripts/verify/m021-p02-linter-scope.sh` must exit 0 with final line `PASS: m021-p02-linter-scope.sh`.

## Must-Haves

- `tests/fixtures/m021-p02/scope-excluded-spec.md` and `scope-opted-in-spec.md` exist; both contain the same Class A-triggering bash fence; they differ only in the presence of the `<!-- agent-facing -->` marker.
- `scripts/verify/m021-p02-linter-scope.sh` exists, is runnable as `bash <path>`, and asserts all six scope behaviors listed in Step 3.
- `references/engine.md` contains a subsection documenting the `<!-- agent-facing -->` marker convention with placement guidance and a literal-marker example.
- The live repo's `specs/`, `references/`, and `docs/` trees produce zero new linter violations (no regression on human-facing docs).

## Verification

- `bash scripts/verify/m021-p02-linter-scope.sh` exits 0 with final line `PASS: m021-p02-linter-scope.sh`.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 on the live repo (no regressions from the scope widening + marker changes).

## Inputs

### From Previous Tasks

- `scripts/verify/anti-pattern-lint.sh` (from T01)
  - Key API: `bash anti-pattern-lint.sh [--fixture <path>]`
  - Key behavior: default sweep discovers files under the four default roots plus marker-opted files under `specs/`, `references/`, `docs/`.
- `ANTIPATTERNS.md` (from T02) — referenced by link text in the engine.md subsection (`AP-004`, `AP-005..AP-009` anchors).

### From Disk (Pre-existing)

- `references/engine.md` — existing 245-line reference doc; target for the marker-convention subsection.
- `tests/fixtures/m021-p02/` — fixture directory created in T03; T04 adds two more files.

## Constraints

- Bash 3.2 compatible (constitution IX).
- Gate script's tempdir mechanism must not leave artifacts on failure — use `trap 'rm -rf "$_tmp"' EXIT` if needed.
- Do not modify any existing `references/engine.md` content — append only (consistent with append-only discipline for reference docs of finalized mechanics).
- The `references/engine.md` subsection itself does NOT need an `<!-- agent-facing -->` marker — `references/` files are excluded by default, and the subsection only describes the marker, does not demonstrate a real one the linter must scan. (If the example bash fence is a concern, the entire "Example" subsection can be fenced inside a four-backtick outer block so the linter's fence-tracking does not descend into it.)
- No speculative behavior (constitution XIV). The marker convention is exactly as specified: a single HTML-comment line, anywhere before the first code block, no attributes, no precedence rules.

## Expected Output

- `tests/fixtures/m021-p02/scope-excluded-spec.md` and `tests/fixtures/m021-p02/scope-opted-in-spec.md` exist.
- `scripts/verify/m021-p02-linter-scope.sh` exists.
- `references/engine.md` contains a new subsection with the string `agent-facing` and a literal `<!-- agent-facing -->` marker example.
- `bash scripts/verify/m021-p02-linter-scope.sh` exits 0 with final line `PASS: m021-p02-linter-scope.sh`.
- `bash scripts/verify/run-suite.sh m021 P02` (the overall phase verification) reports PASS for both `m021-p02-linter-v2.sh` and `m021-p02-linter-scope.sh`.
