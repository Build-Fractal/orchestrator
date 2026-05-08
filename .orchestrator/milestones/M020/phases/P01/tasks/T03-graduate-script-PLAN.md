---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M020"
name: "Minimum-viable graduate.sh"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01: D024 + MEM031 establish the schema vocabulary.
- T02: `scripts/knowledge/lib/frontmatter.sh` exists with `fm_read_status`,
  `fm_write_status`, `fm_assert_closed_enum` and the contract test passes.

Pre-existing on disk:
- `scripts/knowledge/lib/detail-utils.sh` (`fm_field`, `sed_i`,
  `find_detail_file`).
- `scripts/knowledge/lib/index-utils.sh` (`get_project_root`).
- The fixture entries created by T05 (under `tests/fixtures/m020-p01/`) are
  NOT a prerequisite for T03 itself — T03 ships the graduate script and a
  contract test that creates its own ephemeral fixture.

## Description

Create `scripts/knowledge/graduate.sh` — the minimum-viable
candidate→graduated flip per A-1. Scope is deliberately narrow:

- **In scope**: `--rationale <text>` flag (required), one positional
  entry-ID argument, single-entry flip from `candidate` → `graduated` via
  T02's `fm_write_status`.
- **Out of scope** (defer to P03): `--cluster <id>`, `--reject`,
  decision-history append, archive-sibling back-references, conflict
  detection.

The script's role in P01 is to prove the schema-write path end-to-end and
to be the demo-sentence consumer (T05 invokes it).

## Steps

### Step 1: Create `scripts/knowledge/graduate.sh`

File path:
`/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/graduate.sh`

Required behavior:

1. **Argument parsing**: accept `--rationale <text>` (required) and one
   positional entry-ID. Reject extra positional args. Print usage and exit
   1 on missing `--rationale` or missing ID.

2. **Entry resolution**: use `find_detail_file <entry-id>` from
   `lib/detail-utils.sh` to locate the entry file. If not found, exit 1
   with stderr `FAIL: entry <id> not found in knowledge/`.

3. **Pre-flip status read**: call `fm_read_status <file>`.
   - If status is `graduated` → exit 0 with stdout
     `NO-OP: <id> already graduated` (idempotent per MEM001).
   - If status is `archived` → exit 1 with stderr
     `FAIL: <id> is archived; cannot graduate without --reanimate (not implemented in P01)`.
   - If status is `candidate` (or absent → defaults to `graduated` so
     this branch fires only on explicit `candidate`) → proceed.

4. **Flip**: call `fm_write_status <file> graduated`.

5. **Rationale logging**: P01 graduate.sh does NOT yet append to
   `decision_history:` (that's P03's responsibility). Instead, emit the
   rationale to stdout as a structured line:
   `RATIONALE: <id> "<rationale-text>"`.

6. **Success line**: emit `GRADUATED: <id> from=candidate to=graduated`.

7. **Exit codes**: 0 on success or NO-OP, 1 on any failure.

8. **Bash 3.2 + AD-19 + MEM001 conventions** throughout.

### Step 2: Reference implementation

```bash
#!/usr/bin/env bash
# scripts/knowledge/graduate.sh — Minimum-viable candidate→graduated flip
# (P01 scope per A-1). Cluster + decision_history + archive sibling
# semantics land in P03.
#
# Usage: graduate.sh --rationale <text> <entry-id>
#
# Bash 3.2 compatible. AD-19 shape compliant.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
. "$SCRIPT_DIR/lib/detail-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"

usage() {
  cat >&2 <<'EOF'
Usage: graduate.sh --rationale <text> <entry-id>

Flips a single knowledge entry's status: from candidate to graduated.
P01 scope only — cluster + decision_history land in P03.
EOF
  exit 1
}

rationale=""
entry_id=""

while [ $# -gt 0 ]; do
  case "$1" in
    --rationale)
      [ $# -lt 2 ] && usage
      rationale="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    --*)
      echo "FAIL: unknown flag: $1" >&2
      usage
      ;;
    *)
      if [ -n "$entry_id" ]; then
        echo "FAIL: only one entry-id positional argument accepted in P01 (got '$entry_id' and '$1')" >&2
        usage
      fi
      entry_id="$1"
      shift
      ;;
  esac
done

[ -z "$rationale" ] && { echo "FAIL: --rationale <text> is required" >&2; usage; }
[ -z "$entry_id" ] && { echo "FAIL: entry-id positional argument is required" >&2; usage; }

file="$(find_detail_file "$entry_id" 2>/dev/null || true)"
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "FAIL: entry $entry_id not found in knowledge/" >&2
  exit 1
fi

current="$(fm_read_status "$file")"
case "$current" in
  graduated)
    echo "NO-OP: $entry_id already graduated"
    exit 0
    ;;
  archived)
    echo "FAIL: $entry_id is archived; cannot graduate without --reanimate (not implemented in P01)" >&2
    exit 1
    ;;
  candidate)
    fm_write_status "$file" graduated >/dev/null
    echo "RATIONALE: $entry_id \"$rationale\""
    echo "GRADUATED: $entry_id from=candidate to=graduated"
    exit 0
    ;;
  *)
    echo "FAIL: $entry_id has unrecognized status '$current'" >&2
    exit 1
    ;;
esac
```

`chmod +x scripts/knowledge/graduate.sh`.

### Step 3: Create the verification script

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-graduate-single-entry.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-graduate-single-entry.sh — exercise graduate.sh against an
# isolated fixture. Bash 3.2 safe. AD-19 shape compliant.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: graduate.sh missing or not executable at $SCRIPT"
  exit 1
fi

# Build an isolated knowledge fixture under a tempdir whose internal
# layout mirrors the repo (knowledge/patterns/ etc.) so find_detail_file
# resolves against it via ORCHESTRATOR_ROOT.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
fixture="$tmpdir/knowledge/patterns/MEM900.md"
cat > "$fixture" <<'EOF'
---
id: MEM900
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
status: candidate
---

# MEM900: Fixture entry

Body.
EOF

# Point project-root resolution at the fixture
export ORCHESTRATOR_ROOT="$tmpdir"

# Case 1: candidate → graduated
out="$(bash "$SCRIPT" --rationale "test flip" MEM900)"
case "$out" in
  *"GRADUATED: MEM900 from=candidate to=graduated"*) ;;
  *)
    echo "FAIL: graduate output missing GRADUATED line. Got: $out"
    exit 1
    ;;
esac

if ! grep -q "^status: graduated$" "$fixture"; then
  echo "FAIL: status line not flipped to graduated in fixture"
  exit 1
fi

# Case 2: idempotency — re-running is a NO-OP
out2="$(bash "$SCRIPT" --rationale "again" MEM900)"
case "$out2" in
  *"NO-OP: MEM900 already graduated"*) ;;
  *)
    echo "FAIL: second invocation did not produce NO-OP. Got: $out2"
    exit 1
    ;;
esac

# Case 3: missing --rationale rejected
if bash "$SCRIPT" MEM900 2>/dev/null; then
  echo "FAIL: graduate.sh accepted invocation without --rationale"
  exit 1
fi

# Case 4: missing entry rejected
if bash "$SCRIPT" --rationale "x" MEM999 2>/dev/null; then
  echo "FAIL: graduate.sh accepted nonexistent entry"
  exit 1
fi

echo "PASS: graduate.sh single-entry flip honors contract (4/4 cases)"
exit 0
```

`chmod +x` the script.

**NOTE on `ORCHESTRATOR_ROOT`**: the fixture above sets
`ORCHESTRATOR_ROOT` so that `get_project_root` (from
`lib/index-utils.sh`) resolves to the tempdir. Confirm
`lib/index-utils.sh` honors that env var (4-rule resolver per
`scripts/state/resolve-root.sh`); if it does not, replace the env-var
strategy with a direct path-passing argument or by `cd`-ing to the tempdir
before invoking the script. Either approach satisfies AD-19 as long as
the `Check:` invocation itself stays a single script-file call.

### Step 4: Side-effect-scope verification script

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-graduate-side-effect-scope.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-graduate-side-effect-scope.sh — assert graduate.sh single-entry
# path mutates ONLY the target entry file. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Two fixture entries; only MEM901 should change.
for id in MEM901 MEM902; do
  cat > "$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
status: candidate
---

# ${id}: Fixture
EOF
done

# Snapshot MEM902 hash
hash_before="$(md5 -q "$tmpdir/knowledge/patterns/MEM902.md" 2>/dev/null || md5sum "$tmpdir/knowledge/patterns/MEM902.md" | awk '{print $1}')"

export ORCHESTRATOR_ROOT="$tmpdir"
bash "$SCRIPT" --rationale "scope test" MEM901 >/dev/null

hash_after="$(md5 -q "$tmpdir/knowledge/patterns/MEM902.md" 2>/dev/null || md5sum "$tmpdir/knowledge/patterns/MEM902.md" | awk '{print $1}')"

if [ "$hash_before" != "$hash_after" ]; then
  echo "FAIL: graduate.sh mutated MEM902 (untouched sibling)"
  exit 1
fi

echo "PASS: graduate.sh side-effect scope bounded to target entry"
exit 0
```

`chmod +x` the script.

## Must-Haves

- `scripts/knowledge/graduate.sh` exists, is executable, and accepts `--rationale <text> <entry-id>`.
- Idempotent: re-invoking on a `graduated` entry is a NO-OP (exit 0).
- Bounded side effects: only the target entry file is mutated.
- Closed-enum + missing-input + missing-entry error cases all reject with `FAIL:` to stderr and exit 1.
- `scripts/verify/m020-p01-graduate-single-entry.sh` and `scripts/verify/m020-p01-graduate-side-effect-scope.sh` exist, are executable, and exit 0.

## Verification

```bash
bash scripts/verify/m020-p01-graduate-single-entry.sh
bash scripts/verify/m020-p01-graduate-side-effect-scope.sh
```

Both must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `knowledge/conventions/MEM031.md` (T01) — closed enum drives the `case` statement on read status.
- `scripts/knowledge/lib/frontmatter.sh` (T02) — graduate.sh sources this file. Key API:
  - `fm_read_status <file>` → echoes one of `candidate|graduated|archived` (defaults to `graduated` for absent field per FR-10).
  - `fm_write_status <file> <new-status>` → atomic write; rejects out-of-enum values with stderr `FAIL:` and exit 1.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/detail-utils.sh` — provides `find_detail_file <id>` (returns the path to the entry's `.md` file or non-zero on miss).
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root` (honors `ORCHESTRATOR_ROOT` env var per the 4-rule resolver).

## Constraints

- **AD-19**: `Check:` and verification commands are single-script-file invocations. The fixture-and-assert dance is internal to the verification script, not the `Check:` line.
- **MEM001**: bash 3.2; structured `GRADUATED:` / `NO-OP:` / `RATIONALE:` / `FAIL:` prefixes; idempotent.
- **CON-1 (read-only-during-dispatch)**: graduate.sh is operator-invoked. Document this in the script header comment so a future scan can grep for `operator-invoked`.
- **CON-4 (Surgical Precision)**: P01 scope is single-entry only. Do NOT add `--cluster`, `--reject`, decision-history append, archive sibling logic — those land in P03 per the M020 roadmap. Adding them here is a scope violation.
- **FR-7 (decision-history)**: explicitly NOT implemented in T03. The `RATIONALE:` stdout line is a P01 stub that P03 will replace with the frontmatter append. Document this in a script header comment.
- **FR-9 (schema authority)**: graduate.sh writes only the `status:` field via the T02 helper. No new fields, no field renames.

## Expected Output

After this task:

1. `scripts/knowledge/graduate.sh` exists and is executable.
2. `scripts/verify/m020-p01-graduate-single-entry.sh` exists, is executable, and exits 0 with `PASS: graduate.sh single-entry flip honors contract (4/4 cases)`.
3. `scripts/verify/m020-p01-graduate-side-effect-scope.sh` exists, is executable, and exits 0 with `PASS: graduate.sh side-effect scope bounded to target entry`.
4. No `knowledge/**/MEM*.md` file in the live tree has been mutated.

**Done when**: both verification scripts pass + `git status knowledge/` is clean.
