---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M013"
name: "scripts/verify/graphql-call-shape.sh FR-5 three-shape CI lint"
depends_on: []
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape constraint.
- `scripts/integrations/github-init.sh` (P02) contains exactly two GraphQL mutation shapes today:
  1. `mutation($title:String!){createProjectV2(input:{ownerId:"PLACEHOLDER",title:$title}){projectV2{id}}}` (line 451)
  2. `mutation($projectId:ID!,$contentId:ID!){addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){item{id}}}` (line 557)
- P04 will add the third whitelisted mutation: `updateProjectV2ItemFieldValue(...)` inside `scripts/integrations/github-sync.sh`. The lint must accept that shape as whitelisted so that when P04 lands, the lint continues passing without a P04-era edit.
- T02 (re-init adoption) introduces a GraphQL **query** (`projectsV2` discovery) — NOT a mutation. The lint must scan for mutation shapes only, not queries.
- The lint's scope is `scripts/integrations/github-*.sh` — it deliberately excludes the repo-wide GraphQL users (`scripts/diagnostics/wiki-giscus-remap.sh` contains an `updateDiscussion` mutation that is out of M013 scope).
- FR-5 spec text (spec.md line 152): "GraphQL usage is limited to **three distinct call shapes**: `createProjectV2` (once, during `init`), `addProjectV2ItemById` (per Issue attached to the Project v2), and `updateProjectV2ItemFieldValue` (per status transition). No other GraphQL shapes are added without a spec amendment; CI lints the call-shape set."
- Integer-minutes duration in T03-SUMMARY.md.

## Description

Author a CI lint at `scripts/verify/graphql-call-shape.sh` that:

1. Scans `scripts/integrations/github-*.sh` for `gh api graphql` invocations — both the single-line `--field query='mutation(...){<name>(...)}'` shape (P02's pattern) and the assigned-variable / heredoc shape anticipated for P04's sync mutations.
2. Extracts the top-level mutation name from each match via `awk` regex on `mutation\([^)]*\)\{([A-Za-z][A-Za-z0-9_]*)\(` — captures the identifier immediately after the outermost `{`.
3. Ignores GraphQL **queries** (`query(...){...}` form). Only mutations are whitelisted.
4. Emits one `SHAPE: <name>` line per match to stdout (for diagnostic visibility).
5. Deduplicates the captured set, asserts each member is in the whitelist `{createProjectV2, addProjectV2ItemById, updateProjectV2ItemFieldValue}`.
6. On any unexpected shape, emits `FAIL: graphql-call-shape.sh unexpected shape: <name>` to stderr and exits non-zero.
7. On zero shapes found in the scope (pre-P02 regression would look like this), emits `FAIL: graphql-call-shape.sh zero mutation shapes found — expected at least 2 after P02` to stderr and exits non-zero.

Also author `scripts/verify/m013-p03-graphql-call-shape-selftest.sh`: invokes the lint against the live repo (must exit 0 — exactly `createProjectV2` + `addProjectV2ItemById` are present post-P02) and against a temp-copy fixture with an injected fourth shape (must exit non-zero with the expected `unexpected shape:` diagnostic).

## Steps

### Step 1: Create `scripts/verify/graphql-call-shape.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/graphql-call-shape.sh — FR-5 GraphQL call-shape CI lint.
#
# Scans `scripts/integrations/github-*.sh` for GraphQL mutation invocations,
# extracts the top-level mutation name, and asserts membership in the
# three-shape whitelist: createProjectV2, addProjectV2ItemById,
# updateProjectV2ItemFieldValue.
#
# Output: one `SHAPE: <name>` line per match (stdout), then:
#   PASS: graphql-call-shape.sh <N> mutation shapes, all whitelisted
# on success (exit 0), or
#   FAIL: graphql-call-shape.sh unexpected shape: <name>
# on failure (exit 1 + stderr diagnostic).
#
# Scope: scripts/integrations/github-*.sh only. Unrelated GraphQL elsewhere
# in the repo (e.g., scripts/diagnostics/wiki-giscus-remap.sh) is out of
# scope for M013's FR-5 whitelist.
#
# Bash 3.2 compatible. No declare -A, no mapfile, no process substitution.
# Invoked by CI via scripts/verify/m013-p03-phase-suite.sh and directly by
# scripts/verify/m013-p03-graphql-call-shape-selftest.sh with a fixture override.

set -u

SCAN_ROOT="${1:-}"
if [ -z "$SCAN_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  SCAN_ROOT="${REPO_ROOT}/scripts/integrations"
fi

WHITELIST="createProjectV2 addProjectV2ItemById updateProjectV2ItemFieldValue"

# Collect matching files.
files=""
if [ -d "$SCAN_ROOT" ]; then
  files="$(find "$SCAN_ROOT" -maxdepth 1 -type f -name 'github-*.sh' 2>/dev/null || true)"
fi

# Extract mutation shapes. The regex captures the first identifier after
# `mutation(<args>){` — handling both single-line --field query= and
# multi-line heredoc shapes. Queries are skipped by anchoring on `mutation`.
shapes_raw=""
if [ -n "$files" ]; then
  shapes_raw="$(awk '
    /mutation\(/ {
      # Extract everything after the outermost mutation(...){ to end of line.
      s = $0
      # Find mutation( then ){ and capture the next identifier.
      idx = index(s, "mutation(")
      if (idx == 0) next
      rest = substr(s, idx)
      # Find ){ in rest.
      bc = index(rest, "){")
      if (bc == 0) next
      after = substr(rest, bc + 2)
      # Capture leading identifier.
      name = ""
      for (i = 1; i <= length(after); i++) {
        c = substr(after, i, 1)
        if (c ~ /[A-Za-z0-9_]/) {
          name = name c
        } else {
          break
        }
      }
      if (name != "") print name
    }
  ' $files 2>/dev/null || true)"
fi

# Emit per-match diagnostic lines.
if [ -n "$shapes_raw" ]; then
  printf '%s\n' "$shapes_raw" | while IFS= read -r sh; do
    [ -n "$sh" ] && echo "SHAPE: ${sh}"
  done
fi

# Deduplicate.
shapes_unique="$(printf '%s\n' "$shapes_raw" | sort -u | awk 'NF > 0')"

if [ -z "$shapes_unique" ]; then
  echo "FAIL: graphql-call-shape.sh zero mutation shapes found — expected at least 2 after P02" >&2
  exit 1
fi

# Assert each unique shape is in the whitelist.
fail_count=0
IFS='
'
for sh in $shapes_unique; do
  IFS=' '
  ok=0
  for w in $WHITELIST; do
    if [ "$sh" = "$w" ]; then
      ok=1
      break
    fi
  done
  if [ "$ok" -eq 0 ]; then
    echo "FAIL: graphql-call-shape.sh unexpected shape: ${sh}" >&2
    fail_count=$((fail_count + 1))
  fi
  IFS='
'
done
IFS=' '

count_total="$(printf '%s\n' "$shapes_unique" | awk 'NF > 0 { n++ } END { print n + 0 }')"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

echo "PASS: graphql-call-shape.sh ${count_total} mutation shapes, all whitelisted"
exit 0
```

### Step 2: Create the selftest gate `scripts/verify/m013-p03-graphql-call-shape-selftest.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-graphql-call-shape-selftest.sh — T03 gate.
#
# Asserts:
#   (1) graphql-call-shape.sh exits 0 against the live repo (exactly the
#       whitelisted shapes are present post-P02).
#   (2) graphql-call-shape.sh exits non-zero when a fixture contains an
#       injected fourth shape.
#   (3) the diagnostic line contains the offending shape name.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${REPO_ROOT}/scripts/verify/graphql-call-shape.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# (1) Live repo run.
if bash "$LINT" >/dev/null 2>&1; then
  pass "live repo: lint exits 0"
else
  fail "live repo: lint failed (post-P02 repo should have only whitelisted shapes)"
fi

# (1b) Live repo output must contain exactly the two post-P02 shapes at minimum.
live_out="$(bash "$LINT" 2>/dev/null || true)"
printf '%s\n' "$live_out" | grep -q 'SHAPE: createProjectV2' \
  && pass "createProjectV2 detected in live repo" \
  || fail "createProjectV2 not detected (regression in P02 init)"
printf '%s\n' "$live_out" | grep -q 'SHAPE: addProjectV2ItemById' \
  && pass "addProjectV2ItemById detected in live repo" \
  || fail "addProjectV2ItemById not detected (regression in P02 init)"

# (2) Fixture with injected fourth shape.
fx_dir="$(mktemp -d -t m013-p03-lint.XXXXXX)"
cat > "${fx_dir}/github-evilrogue.sh" <<'EOF'
#!/usr/bin/env bash
# Fixture: inject a non-whitelisted mutation to confirm the lint catches it.
gh api graphql --field query='mutation($id:ID!){deleteProjectV2(input:{projectId:$id}){clientMutationId}}' || true
EOF

# Also copy the real github-init.sh shapes so the lint finds the whitelist
# members alongside the intruder (more realistic failure shape).
cp "${REPO_ROOT}/scripts/integrations/github-init.sh" "${fx_dir}/" 2>/dev/null || true

fail_out="$(bash "$LINT" "$fx_dir" 2>&1 || true)"
rc=$?
if printf '%s\n' "$fail_out" | grep -q 'unexpected shape: deleteProjectV2'; then
  pass "fixture: deleteProjectV2 flagged as unexpected"
else
  fail "fixture: deleteProjectV2 NOT flagged (got: $fail_out)"
fi

# Final rc should be non-zero when running against the fixture.
if bash "$LINT" "$fx_dir" >/dev/null 2>&1; then
  fail "fixture: lint exited 0 despite injected fourth shape"
else
  pass "fixture: lint exited non-zero on injected fourth shape"
fi

rm -rf "$fx_dir"
echo "SUMMARY: m013-p03-graphql-call-shape-selftest.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-graphql-call-shape-selftest.sh"
  exit 0
fi
echo "FAIL: m013-p03-graphql-call-shape-selftest.sh" >&2
exit 1
```

### Step 3: `chmod +x scripts/verify/graphql-call-shape.sh`

The lint is invoked via `bash <path>` by the phase suite (per MEM013 AD-19 constraint), but chmoding executable supports direct invocation for CI wiring.

## Must-Haves

From P03-PLAN:

- `scripts/verify/graphql-call-shape.sh` exists, contains the string `createProjectV2`, scans `scripts/integrations/github-*.sh` by default, accepts a path argument for fixture use, extracts mutation names via awk, asserts whitelist membership.
- `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` passes (≥5 assertions):
  - live-repo run exits 0
  - `createProjectV2` detected
  - `addProjectV2ItemById` detected
  - fixture with injected shape flagged correctly
  - fixture run exits non-zero
- The lint emits `SHAPE: <name>` lines per match for CI operator visibility.

## Verification

```bash
bash scripts/verify/graphql-call-shape.sh
bash scripts/verify/m013-p03-graphql-call-shape-selftest.sh
```

First exits 0 (post-P02 repo is clean). Second exits 0 (selftest assertions pass). The selftest injects a fourth shape into a tempdir fixture and asserts the lint catches it.

## Inputs

### From Previous Tasks

None — T03 runs in parallel with T01/T02 and consumes only the pre-existing P02 GraphQL call sites.

### From Disk (Pre-existing)

- `scripts/integrations/github-init.sh` (from M013/P02/T02)
  - Contains exactly two whitelisted mutation call sites. Used as the scan target and (via copy) as a fixture ingredient in the selftest.
- `scripts/integrations/github-common.sh` (from M013/P02/T01 + P03/T01)
  - Contains zero mutation call sites. Used implicitly (scanned, produces zero `SHAPE:` lines).

## Constraints

- **Scope limited to `scripts/integrations/github-*.sh`**: the lint must NOT flag GraphQL in `scripts/diagnostics/wiki-giscus-remap.sh` (`updateDiscussion` is M012 wiki scope, out of M013 FR-5 scope). The `-maxdepth 1` + `-name 'github-*.sh'` combination scopes the scan.
- **FR-5 whitelist is exactly three**: `createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`. Any fourth triggers a FAIL. P04's `updateProjectV2ItemFieldValue` is pre-whitelisted so P04 passes on the day it lands.
- **Queries are unconstrained**: T02's `projectsV2` discovery query is NOT scanned (the awk regex anchors on `mutation(` and skips `query(`). Verify in the selftest by confirming the live repo lint exits 0 after T02 lands (the query must not be flagged).
- **AD-19 `Check:` shape**: gate commands are single-script-file invocations.
- **Bash 3.2**: no `declare -A`, no `mapfile`/`readarray`, no process substitution, no combined-redirect shorthand.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes.
- **Integer-minutes duration** in T03-SUMMARY.md.

## Expected Output

Live-repo lint:

```
SHAPE: createProjectV2
SHAPE: addProjectV2ItemById
PASS: graphql-call-shape.sh 2 mutation shapes, all whitelisted
```

Selftest gate:

```
PASS: live repo: lint exits 0
PASS: createProjectV2 detected in live repo
PASS: addProjectV2ItemById detected in live repo
PASS: fixture: deleteProjectV2 flagged as unexpected
PASS: fixture: lint exited non-zero on injected fourth shape
SUMMARY: m013-p03-graphql-call-shape-selftest.sh pass=5 fail=0
PASS: m013-p03-graphql-call-shape-selftest.sh
```

Estimated duration: 40 integer minutes.
