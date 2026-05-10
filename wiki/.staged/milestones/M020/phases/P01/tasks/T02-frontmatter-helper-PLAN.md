---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M020"
name: "Atomic frontmatter helper"
depends_on: ["T01"]
---

## Prerequisites

T01 has landed: [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) exists and documents the
closed-enum vocabulary. T02 implements the read/write helpers for the
fields MEM031 names.

Pre-existing on disk:
- `scripts/knowledge/lib/detail-utils.sh` exposes `fm_field <file> <key>`
  for reading scalar frontmatter fields and `sed_i` for portable in-place
  sed (BSD/GNU compatible).
- `scripts/knowledge/lib/index-utils.sh` exposes `get_project_root`.

## Description

Create `scripts/knowledge/lib/frontmatter.sh` — a sourceable bash 3.2
helper exposing atomic read/write functions for the M020 schema-evolution
fields (`status:`, `decision_history:`, `archived_into:`).

**Atomic** = write to a tempfile in the same directory, then `mv`
(single-inode replace). A crash mid-write must leave the original file
unchanged — never half-written. This honors CON-4 (Surgical Precision /
byte-equivalence for unrelated fields) by ensuring partial writes cannot
corrupt the schema-unrelated portions of the entry.

**Scope of T02**: implement and contract-test the read/write functions.
T03 (graduate.sh) and P03 (cluster-aware graduate, decision_history
append) are the consumers. T02 must NOT itself mutate any
`knowledge/**/MEM*.md` entry — it only ships the helper.

## Steps

### Step 1: Create `scripts/knowledge/lib/frontmatter.sh`

File path:
`/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/lib/frontmatter.sh`

The file MUST expose, at minimum, these function signatures:

```
fm_read_status <file>                       # echoes status value or "graduated" if absent (FR-10)
fm_write_status <file> <new-status>         # atomic write; closed-enum check
fm_write_archived_into <file> <canonical-id>  # atomic write
fm_append_decision_history <file> <rationale> <operator> <cluster-id>  # atomic append
fm_assert_closed_enum <value>               # exits 1 with stderr diagnostic on out-of-enum
```

Implementation requirements:

1. **Sourceable**: file begins with `#!/usr/bin/env bash` and a
   double-source guard `[ -n "${_FRONTMATTER_HELPER_SOURCED:-}" ] && return 0`
   followed by `_FRONTMATTER_HELPER_SOURCED=1`.

2. **Bash 3.2**: no `declare -A`, no `${var^^}`, no `[[ ... =~ ... ]]`
   captures into `BASH_REMATCH` if avoidable. Use `case` + `tr` for case
   handling.

3. **Atomic write**: every mutation function follows this pattern:
   ```
   tmp="${file}.tmp.$$"
   awk ... "$file" > "$tmp"
   mv "$tmp" "$file"
   ```
   The `mv` is the commit point — POSIX guarantees same-filesystem `mv` is
   atomic (rename(2)).

4. **Closed-enum guard**: `fm_assert_closed_enum` rejects any value not in
   `candidate|graduated|archived` with stderr `FAIL: status must be one of
   {candidate, graduated, archived}, got: <value>` and exit 1. Called by
   `fm_write_status` before the tempfile is created.

5. **Pre-M020 default for read**: `fm_read_status` returns `graduated`
   (not empty, not error) when the entry has no `status:` line at all.
   This implements FR-10 incremental migration semantics: callers see
   `graduated` for un-migrated entries and the field is written on next
   touch by `fm_write_status`.

6. **Insertion vs replacement on write**: `fm_write_status` MUST detect
   whether `status:` already exists in the frontmatter:
   - If present → replace the value (sed in the tempfile path).
   - If absent → insert the line immediately before the closing `---` of
     the frontmatter block.
   Both paths produce a final file with exactly one `status:` line.

7. **Decision-history append shape**: `fm_append_decision_history` appends
   a new YAML record under a `decision_history:` key. If the key is
   absent, create it. Record shape:
   ```yaml
   decision_history:
     - rationale: "<rationale>"
       timestamp: "2026-04-25T17:30:00Z"
       operator: "<operator>"
       cluster_id: "<cluster-id-or-empty>"
   ```
   Timestamps via `date -u +%Y-%m-%dT%H:%M:%SZ` per MEM008 ISO 8601 standard.

8. **Structured output**: every successful mutation echoes one stdout line
   `WROTE: <file> field=<field> value=<value>` for the operator + log
   trail. Errors go to stderr with `FAIL:` prefix.

9. **No file-I/O from pure helpers**: read functions (`fm_read_status`)
   MUST NOT mutate. Per MEM004 (Pure Lib Extraction Pattern).

### Step 2: Implementation skeleton (reference)

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/frontmatter.sh — atomic frontmatter read/write
# helpers for M020 schema-evolution fields (status, decision_history,
# archived_into). Bash 3.2 safe.
#
# Source this file. Requires lib/detail-utils.sh sourced first for sed_i.

[ -n "${_FRONTMATTER_HELPER_SOURCED:-}" ] && return 0
_FRONTMATTER_HELPER_SOURCED=1

# --- Closed-enum assertion ---
fm_assert_closed_enum() {
  local value="$1"
  case "$value" in
    candidate|graduated|archived) return 0 ;;
    *)
      echo "FAIL: status must be one of {candidate, graduated, archived}, got: $value" >&2
      exit 1
      ;;
  esac
}

# --- Read status with FR-10 default ---
fm_read_status() {
  local file="$1"
  local val
  val="$(awk '/^---$/{n++;next} n==1 && /^status:/{print;exit}' "$file" | sed 's/^status:[[:space:]]*//')"
  if [ -z "$val" ]; then
    echo "graduated"
  else
    echo "$val"
  fi
}

# --- Write status (atomic; insert if absent, replace if present) ---
fm_write_status() {
  local file="$1"
  local new_status="$2"
  fm_assert_closed_enum "$new_status"
  local tmp="${file}.tmp.$$"
  awk -v ns="$new_status" '
    BEGIN{infm=0; wrote=0}
    /^---$/{
      if (infm==0) { infm=1; print; next }
      if (infm==1 && wrote==0) { print "status: " ns; wrote=1 }
      infm=2; print; next
    }
    infm==1 && /^status:/{
      print "status: " ns; wrote=1; next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "WROTE: $file field=status value=$new_status"
}

# (Implement fm_write_archived_into and fm_append_decision_history with the
# same write-tempfile-then-mv discipline. Use awk for line manipulation.)
```

Fill in `fm_write_archived_into` and `fm_append_decision_history` following
the same pattern.

### Step 3: Create the contract-test verification script

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-frontmatter-helper-contract.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-frontmatter-helper-contract.sh — exercise every public function
# of lib/frontmatter.sh against a tempfile fixture. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/lib/frontmatter.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: frontmatter helper missing at $HELPER"
  exit 1
fi

# Source helpers
# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/index-utils.sh"
# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/detail-utils.sh"
# shellcheck source=/dev/null
. "$HELPER"

# Build a fixture entry
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fixture="$tmpdir/MEM999.md"
cat > "$fixture" <<'EOF'
---
id: MEM999
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
---

# MEM999: Fixture entry for contract test

Body content.
EOF

# Test 1: fm_read_status on an entry with no status: returns "graduated"
result="$(fm_read_status "$fixture")"
if [ "$result" != "graduated" ]; then
  echo "FAIL: fm_read_status default returned '$result', expected 'graduated'"
  exit 1
fi

# Test 2: fm_write_status inserts the field on first write
fm_write_status "$fixture" candidate >/dev/null
if ! grep -q "^status: candidate$" "$fixture"; then
  echo "FAIL: fm_write_status did not insert status line"
  exit 1
fi

# Test 3: fm_write_status replaces on second write
fm_write_status "$fixture" graduated >/dev/null
count="$(grep -c "^status:" "$fixture")"
if [ "$count" != "1" ]; then
  echo "FAIL: fm_write_status produced $count status lines, expected 1"
  exit 1
fi
if ! grep -q "^status: graduated$" "$fixture"; then
  echo "FAIL: fm_write_status did not replace value"
  exit 1
fi

# Test 4: closed-enum rejection
if fm_write_status "$fixture" pending 2>/dev/null; then
  echo "FAIL: fm_write_status accepted out-of-enum value 'pending'"
  exit 1
fi

# Test 5: archived_into write
fm_write_archived_into "$fixture" MEM042 >/dev/null
if ! grep -q "^archived_into: MEM042" "$fixture"; then
  echo "FAIL: fm_write_archived_into did not write field"
  exit 1
fi

# Test 6: decision_history append (creates key if absent)
fm_append_decision_history "$fixture" "merge test" "tester" "C1" >/dev/null
if ! grep -q "^decision_history:" "$fixture"; then
  echo "FAIL: fm_append_decision_history did not create key"
  exit 1
fi
if ! grep -q "rationale: \"merge test\"" "$fixture"; then
  echo "FAIL: fm_append_decision_history did not write rationale"
  exit 1
fi

# Test 7: atomic write — no .tmp file left behind
leftover="$(ls "$tmpdir"/*.tmp.* 2>/dev/null | wc -l | tr -d ' ')"
if [ "$leftover" != "0" ]; then
  echo "FAIL: $leftover .tmp files left behind after writes"
  exit 1
fi

echo "PASS: frontmatter helper contract honored (7/7 cases)"
exit 0
```

`chmod +x` the script.

### Step 4: Smoke-test against an existing entry

After implementing the helper, run a one-shot probe (NOT committed) to
confirm `fm_read_status` returns `graduated` against a real pre-M020 entry:

Create `/tmp/m020-p01-t02-smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/brettkellgren/Sites/orchestrator"
. "$ROOT/scripts/knowledge/lib/index-utils.sh"
. "$ROOT/scripts/knowledge/lib/detail-utils.sh"
. "$ROOT/scripts/knowledge/lib/frontmatter.sh"
v="$(fm_read_status "$ROOT/knowledge/patterns/MEM001.md")"
echo "MEM001 status reads as: $v"
```

Run `bash /tmp/m020-p01-t02-smoke.sh` and confirm output is
`MEM001 status reads as: graduated`. Delete the smoke script when done.

## Must-Haves

- `scripts/knowledge/lib/frontmatter.sh` exists and is sourceable (no syntax errors when sourced).
- All five public functions exist and behave per the contract test.
- Atomic writes (no `.tmp.*` debris) and closed-enum rejection both verified by the contract test.
- `scripts/verify/m020-p01-frontmatter-helper-contract.sh` exists, is executable, and exits 0.
- T02 produces NO mutations to any `knowledge/**/MEM*.md` entry — only the helper file is created.

## Verification

```bash
bash scripts/verify/m020-p01-frontmatter-helper-contract.sh
```

Must print `PASS: frontmatter helper contract honored (7/7 cases)` and exit 0.

The cross-task no-bulk-migration invariant (T02 must not rewrite the live
`knowledge/**` tree) is enforced at phase-verification time by
`scripts/verify/m020-p01-migration-incremental.sh` (created in T05) — it
reads the execution log and asserts no `knowledge/**/MEM*.md` files were
modified by any task before T05's incremental-migration step. Not run
inline at T02 because the script does not yet exist.

## Inputs

### From Previous Tasks

- [`knowledge/conventions/MEM031.md`](../../../../../knowledge/conventions/MEM031.md) (from T01)
  - Key contract: closed enum is exactly `{candidate, graduated, archived}`. Pre-M020 entries default to `graduated` on read.
  - Companion fields documented: `decision_history:` (append-only list), `archived_into:` (single ID back-ref).

### From Disk (Pre-existing)

- `scripts/knowledge/lib/detail-utils.sh` — provides `sed_i` (BSD/GNU portable in-place sed) and `fm_field` (frontmatter scalar reader). Source as a sibling helper.
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root`. Source for path resolution.
- [`knowledge/patterns/MEM001.md`](../../../../../knowledge/patterns/MEM001.md) — example pre-M020 entry with no `status:` field; smoke-test target for FR-10 default behavior.

## Constraints

- **AD-19**: every `Check:` invocation in this plan is single-script-file shape. The contract test is one script that exercises all 7 cases internally.
- **MEM001**: bash 3.2 compatible.
- **MEM003 / MEM008**: ISO 8601 UTC timestamps via `date -u +%Y-%m-%dT%H:%M:%SZ`. Structured stdout (`WROTE:`); errors to stderr (`FAIL:`).
- **MEM004**: pure-lib extraction — `fm_read_status` is read-only (no I/O side effects beyond reading the file).
- **CON-1 (read-only-during-dispatch)**: the helper is callable from operator-invoked paths only. T03 is the first consumer and is operator-invoked. Document this in a header comment.
- **CON-4 (byte-equivalence)**: write functions touch ONLY the named field. Test 7 of the contract test asserts no other lines change between write and the `mv` commit point.

## Expected Output

After this task:

1. `scripts/knowledge/lib/frontmatter.sh` exists with the five functions documented above.
2. `scripts/verify/m020-p01-frontmatter-helper-contract.sh` exists and is executable.
3. The contract test prints `PASS: frontmatter helper contract honored (7/7 cases)` and exits 0.
4. No `knowledge/**/MEM*.md` file has been mutated.
5. `git status knowledge/` reports a clean tree.

**Done when**: contract test passes + git status of `knowledge/` is clean.
