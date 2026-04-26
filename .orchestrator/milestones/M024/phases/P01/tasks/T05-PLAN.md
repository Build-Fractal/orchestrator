---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M024"
name: "Author the two phase-level tests + the M014 manifest fixture"
depends_on: ["T04"]
---

## Prerequisites

- T04 complete: the proposal emitter exists and produces structurally complete proposals.
- An existing `tests/` directory with `test-knowledge-query.sh` as the canonical pass/fail style reference (MEM002 conventions: parallel arrays, `pass()`/`fail()` helpers, structured `PASS:`/`FAIL:` summary).

## Description

Three deliverables:

1. **`tests/fixtures/m014-interim-manifest-keys.txt`** — a captured fixture listing the M014 interim manifest's frontmatter key set. Per AD-4 direction `a` and DC-5: P01 captures the M014 manifest key set as a static fixture (not a live read) so the superset assertion can run without depending on M014/extended having shipped. P02 wires the live read direction. The fixture is the source of truth at P01 plan-phase time; if M014 evolves, the fixture is updated alongside.

2. **`tests/test-intake-proposal-shape.sh`** — exercises SC-7 (every proposal frontmatter contains all six named axes with non-null values). Invokes the emitter against three inputs (paragraph, idea, spec-path), greps for the seven structural-frontmatter keys + six axis section headings, and asserts no `{{...}}` placeholders remain.

3. **`tests/test-intake-manifest-superset.sh`** — exercises SC-8 / FR-15 / DC-5 (proposal frontmatter is a strict superset of the M014 manifest keys). Reads the fixture, invokes the emitter, parses proposal frontmatter keys, and asserts `every key in fixture is also in proposal` (and proposal has at least one key not in fixture — the strictness check).

Both tests follow `tests/test-knowledge-query.sh` style.

## Steps

1. **Create the fixture directory**: `mkdir -p tests/fixtures`.

2. **Write the fixture** at `tests/fixtures/m014-interim-manifest-keys.txt`. Per AD-3 + the captured M014 spec frontmatter shape (`templates/spec-template.md` + `commands/specify.md` Pass-1 scaffold + `scripts/specify/specify.sh`), the M014 interim manifest frontmatter pins these keys at plan-phase time:

```text
# tests/fixtures/m014-interim-manifest-keys.txt
# M014 interim manifest frontmatter key set, captured 2026-04-25 (M024/P01/T05).
# Source: templates/spec-template.md frontmatter + scripts/specify/specify.sh
# scaffold output. Updated alongside M014 evolution; P02 will wire the live
# read direction.
schema_version
type
feature_slug
created_at
status
milestone
```

These six keys form the M014 manifest's pinned frontmatter (the Pass-1 scaffold output). The proposal artifact's 22-key frontmatter is a strict superset: every one of these six keys appears in the proposal's frontmatter, plus 16 additional intake-specific keys (`intake_id`, `input_shape`, the six axes, the metadata flags, etc.).

Note: `feature_slug` and `milestone` are M014-specific keys not currently present in the T01 proposal template. To make the proposal a strict superset, the proposal frontmatter must include both. **This is a binding finding from T05 that loops back to T01**: the agent executing T05 must add `feature_slug: "{{feature_slug}}"` and `milestone: "{{milestone}}"` to the proposal template (T01's frontmatter list) and to the emitter (T04's substitution list, computing `feature_slug` from `intake_id` when in spec-path mode and from the `intake_id` slug otherwise; computing `milestone` from `null` when no milestone is bound, else from the active milestone). The T01 verify script must then be updated to include these two keys in `REQUIRED_KEYS`. This loop-back is the FR-15 strict-superset commitment in action — the alternative (lying to the assertion or weakening DC-5 to "subset") is rejected.

3. **Write the proposal-shape test** at `tests/test-intake-proposal-shape.sh`:

```bash
#!/usr/bin/env bash
# tests/test-intake-proposal-shape.sh — SC-7 frontmatter-completeness for M024/P01.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

pass_count=0
fail_count=0
fail_messages=""
pass() { pass_count=$((pass_count + 1)); }
fail() { fail_count=$((fail_count + 1)); fail_messages="$fail_messages
  - $1"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

REQUIRED_KEYS="schema_version type intake_id created_at input_shape input_hash shape_classification scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence feature_slug milestone"
REQUIRED_HEADINGS="Axis_1_Input_Shape Axis_2_Scope_Tier Axis_3_Decomposition Axis_4_Design_Gate Axis_5_Conversus_Gate Axis_6_Intensity"

check_one() {
  local label="$1"; local out="$2"; local path
  path=$(echo "$out" | sed -n 's/^proposal_path=//p')
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    fail "$label: emitter did not produce a file (out=$out)"
    return
  fi
  for k in $REQUIRED_KEYS; do
    if ! grep -q "^${k}:" "$path"; then
      fail "$label: missing frontmatter key '$k'"; return
    fi
  done
  for h in $REQUIRED_HEADINGS; do
    pretty=$(echo "$h" | sed 's/_/ /; s/_/ — /')
    if ! grep -qF "$pretty" "$path"; then
      fail "$label: missing axis heading '$pretty'"; return
    fi
  done
  if grep -q '{{[a-z_]*}}' "$path"; then
    fail "$label: unsubstituted placeholders remain in $path"; return
  fi
  pass
}

# Case A — paragraph.
out_a=$(bash "$EMIT" --input "We should add a last seen timestamp to the status command output and cache it briefly so repeated calls do not hammer the filesystem." --intake-root "$tmp/a")
check_one "paragraph" "$out_a"

# Case B — idea.
out_b=$(bash "$EMIT" --input "fix typo in status doc" --intake-root "$tmp/b")
check_one "idea" "$out_b"

# Case C — spec-path. Use this milestone's own spec.
out_c=$(bash "$EMIT" --spec-path "$ROOT/specs/028-universal-intake-routing/spec.md" --intake-root "$tmp/c")
check_one "spec-path" "$out_c"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count case(s):$fail_messages"
  echo "(passed: $pass_count)"
  exit 1
fi

echo "PASS: test-intake-proposal-shape.sh — paragraph, idea, spec-path ($pass_count cases)"
exit 0
```

4. **Write the manifest-superset test** at `tests/test-intake-manifest-superset.sh`:

```bash
#!/usr/bin/env bash
# tests/test-intake-manifest-superset.sh — SC-8 / FR-15 / DC-5 strict-superset
# assertion: proposal frontmatter contains every key from the M014 interim
# manifest fixture, plus at least one M024-specific key.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
FIXTURE="$ROOT/tests/fixtures/m014-interim-manifest-keys.txt"

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture missing: $FIXTURE"
  exit 1
fi
if [ ! -x "$EMIT" ]; then
  echo "FAIL: emitter missing: $EMIT"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

out=$(bash "$EMIT" --input "test input for manifest superset assertion" --intake-root "$tmp")
proposal_path=$(echo "$out" | sed -n 's/^proposal_path=//p')
if [ -z "$proposal_path" ] || [ ! -f "$proposal_path" ]; then
  echo "FAIL: emitter produced no file (out: $out)"
  exit 1
fi

# Extract the proposal's frontmatter key list.
prop_keys_file="$tmp/proposal-keys.txt"
awk 'BEGIN{in_fm=0} /^---$/{in_fm++; next} in_fm==1 && /^[a-z_]+:/ {sub(/:.*/, ""); print}' "$proposal_path" > "$prop_keys_file"

# Containment check.
missing=""
fixture_count=0
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  fixture_count=$((fixture_count + 1))
  if ! grep -qx "$line" "$prop_keys_file"; then
    missing="$missing $line"
  fi
done < "$FIXTURE"

if [ -n "$missing" ]; then
  echo "FAIL: proposal frontmatter missing M014 manifest keys —$missing"
  exit 1
fi

# Strictness check: proposal must have keys NOT in fixture.
prop_count=$(wc -l < "$prop_keys_file" | tr -d ' ')
if [ "$prop_count" -le "$fixture_count" ]; then
  echo "FAIL: superset is not strict (proposal=$prop_count keys, fixture=$fixture_count keys)"
  exit 1
fi

echo "PASS: test-intake-manifest-superset.sh — proposal contains all $fixture_count M014 manifest keys + $((prop_count - fixture_count)) M024-specific keys"
exit 0
```

5. **Make both tests executable**: `chmod +x tests/test-intake-proposal-shape.sh tests/test-intake-manifest-superset.sh`.

6. **Write the suite verify script** at `scripts/verify/m024-p01-suite.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-suite.sh — run both phase-level tests.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ok=1
if ! bash "$ROOT/tests/test-intake-proposal-shape.sh"; then
  ok=0
fi
if ! bash "$ROOT/tests/test-intake-manifest-superset.sh"; then
  ok=0
fi

if [ "$ok" -eq 0 ]; then
  echo "FAIL: M024/P01 phase suite reported a failure (see above)"
  exit 1
fi

echo "PASS: M024/P01 suite — proposal-shape + manifest-superset"
exit 0
```

7. **Honor the loop-back from step 2**: the agent executing T05 must edit T01's deliverables to add `feature_slug` and `milestone` keys. Concretely:
   - Edit `templates/intake-proposal.md` frontmatter to add `feature_slug: "{{feature_slug}}"` (after `type: intake-proposal`) and `milestone: "{{milestone}}"` (after `intake_id`).
   - Edit `scripts/intake/proposal-emit.sh` to compute and substitute these two values:
     - `feature_slug`: when `--spec-path` was supplied, derive from `basename "$(dirname "$SPEC_PATH")"`; otherwise, use the intake-id slug (strip the `<NNN>-` counter prefix).
     - `milestone`: read from `.orchestrator/milestone-summary.md` if present (`grep '^**Active milestone**:' | head -1` shape) — otherwise emit `null`.
   - Edit `scripts/verify/m024-p01-template-frontmatter.sh` `REQUIRED_KEYS` to include `feature_slug` and `milestone`.

## Must-Haves

- `tests/fixtures/m014-interim-manifest-keys.txt` exists and lists the M014 manifest key set (one key per line, comments allowed with `#` prefix).
- `tests/test-intake-proposal-shape.sh` exits 0 with `PASS:` line when run after T04.
- `tests/test-intake-manifest-superset.sh` exits 0 with `PASS:` line when run after T04.
- Both tests follow MEM002 conventions (parallel pass/fail counters, structured summary).
- The T01 template + T04 emitter loop-back additions (`feature_slug`, `milestone`) are landed; `scripts/verify/m024-p01-template-frontmatter.sh` updated to require both.
- `scripts/verify/m024-p01-suite.sh` exits 0 with `PASS:` line.

## Verification

```
bash scripts/verify/m024-p01-suite.sh
```

Expected output (final exit 0): three `PASS:` lines covering `test-intake-proposal-shape.sh` (paragraph, idea, spec-path — 3 cases), `test-intake-manifest-superset.sh` (proposal contains all 6 M014 manifest keys + N M024-specific keys), and `M024/P01 suite — proposal-shape + manifest-superset`.

## Inputs

### From Previous Tasks

- `scripts/intake/proposal-emit.sh` (from T04) — invoked via `bash <path> {--input <s>|--spec-path <p>} --intake-root <dir>`. Key API: emits one stdout line `proposal_path=<absolute path>`; writes a complete proposal.md to that path; exits 0 on success.
- `templates/intake-proposal.md` (from T01) — read by the emitter; modified by step 7 to add `feature_slug` + `milestone`.
- `scripts/intake/intake-id-allocate.sh` (from T02) and `scripts/intake/shape-detect.sh` (from T03) — invoked transitively via the emitter; not called directly by tests.
- `scripts/verify/m024-p01-template-frontmatter.sh` (from T01) — modified by step 7 to require `feature_slug` + `milestone`.

### From Disk (Pre-existing)

- `specs/028-universal-intake-routing/spec.md` — used by the proposal-shape test as the spec-path case fixture.
- `tests/test-knowledge-query.sh` — read-only style reference (MEM002 pass/fail conventions).
- `.orchestrator/milestone-summary.md` (optional) — read by the emitter loop-back to populate `milestone`.

## Constraints

- POSIX sh + bash 3.2 portable.
- Tests confine writes to `mktemp -d` directories; no fixed `/tmp` paths or repo-root pollution.
- No conversus invocations, no knowledge writes (SB-3).
- No `<TODO:` markers (DC-3).
- The fixture file is the canary for FR-15 drift: if M014's manifest gains or loses a key, the fixture is updated and the superset test must continue to pass. Drift in either direction breaks the handshake (cross-cutting D017 manifest-superset assertion).
- The "strict" check (proposal has keys not in fixture) is what makes this a *strict* superset assertion per DC-5. A bare "≥" check is insufficient.
- Test naming follows the existing `tests/test-*.sh` convention.
- No live M014 invocation in P01 (P02 wires that direction). The fixture is the source of truth at P01.
- AD-19: every helper invocation is single-script-file shape; no inline compound bash.

## Expected Output

- `tests/fixtures/m014-interim-manifest-keys.txt` exists with ≥6 key lines.
- `tests/test-intake-proposal-shape.sh` and `tests/test-intake-manifest-superset.sh` both exist, are executable, and exit 0 with `PASS:` lines.
- T01/T04 deliverables updated per step 7; the T01 verify still passes.
- `scripts/verify/m024-p01-suite.sh` exits 0.
