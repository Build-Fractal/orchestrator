---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M013"
name: "Re-init fixture tree + gh_marker_search_remote helper (github-common.sh additive extension)"
depends_on: []
---

## Prerequisites

- Bash 3.2 target — no `declare -A`, no `mapfile`/`readarray`, no `<(...)`/`>(...)`, no `&>`/`|&`, no `${var^^}`/`${var,,}` (MEM001, Constitution IX).
- AD-19 harness heuristic constraint applies to `Check:` lines in task/phase plans, NOT to the internals of scripts themselves. Internal control flow (if/for/while/case/$()) inside scripts is unrestricted.
- P02 has landed `scripts/integrations/github-common.sh` (638 lines, 12 public functions including `orchestrator_id_for`, `emit_marker`, `find_marker_in_body`, `shasum_marker_byte_identity`, `sidecar_path`, `sidecar_get_field`, `sidecar_set_top_field`, `sidecar_upsert_item`, `sidecar_item_exists`, `gh_auth_preflight`, `gh_subissue_rest_preflight`, `gh_label_collision_preflight`). P02 authored the `M013_GH_STUB_DIR` env-var stub-selector pattern for `gh_*_preflight` helpers — T01 follows the same pattern.
- P02 has landed `tests/fixtures/m013-p02/` fixture tree including `orchestrator-state/` seed layout and `gh-stub-responses/`. T01 authors a parallel tree at `tests/fixtures/m013-p03/re-init-adoption/` with different contents (sidecar-absent + marker-bearing remote).
- FR-4 marker format is exactly `<!-- orchestrator-id: M###-P##[-T##] -->` (three zero-padded digits for milestone, two for phase/task). The SSOT is `references/github-integration.md` P01 section "<!-- orchestrator-id: ... --> Marker Format".
- Known orchestrator bug: `scripts/lifecycle/phase-transition.sh` crashes on non-numeric `duration:` fields under `set -euo pipefail`. This task's summary MUST use integer-minutes duration.
- P02 byte-identity: existing `github-common.sh` function bodies stay untouched. T01's change is purely additive — one new public function appended, and the direct-execution usage-hint block at end of file gains the new name in its echo.

## Description

Author two artifacts:

1. **Re-init fixture tree** at `tests/fixtures/m013-p03/re-init-adoption/` mirroring P02's fixture shape. Key differences from P02 fixture: (a) there is NO `orchestrator-state/.orchestrator/integrations/github.json` (sidecar genuinely absent — not even a pending-sentinel), (b) `gh-stub-responses/` canned outputs simulate a remote GitHub state where each projected orchestrator-id already exists as a marker-bearing Issue (one Issue per phase id, one Issue per task id), and where a Project v2 already exists with all those Issues attached, (c) `expected-readopt-manifest.txt` is the pinned snapshot in which every resource row is `reason=adopt` and the footer is `upserts=0 skipped=N errors=0 adopted=N`.

2. **One additive public helper in `scripts/integrations/github-common.sh`**: `gh_marker_search_remote <repo-slug> <orchestrator-id>` — queries a remote repo for a marker-bearing Issue matching the given id, returns the Issue number on stdout (exit 0) on unique hit, empty stdout + exit 1 on zero matches, empty stdout + exit 2 on duplicate match. Fixture-driven via the `M013_GH_STUB_DIR` env var (P02's pattern): when set, the function reads canned `gh issue list` JSON from `${M013_GH_STUB_DIR}/issue-list-<oid>.json`; when unset, it invokes `gh issue list --state all --search "\"<!-- orchestrator-id: <oid> -->\"" --json number --jq '. | length'` and parses the count.

T02 consumes both the fixture and the helper. T01 does NOT modify `github-init.sh` or any other script.

## Steps

### Step 1: Create the fixture orchestrator-state seed

Create directory structure:

```
tests/fixtures/m013-p03/re-init-adoption/
├── orchestrator-state/
│   └── .orchestrator/
│       └── milestones/
│           └── M013/
│               ├── M013-ROADMAP.md
│               └── phases/
│                   └── P02/
│                       ├── P02-PLAN.md
│                       └── tasks/
│                           ├── T01-PLAN.md
│                           └── T02-PLAN.md
├── expected-readopt-manifest.txt
└── gh-stub-responses/
    ├── auth-status-green.txt
    ├── subissue-rest-available.json
    ├── labels-no-collision.json
    ├── issue-list-M013-P02.json
    ├── issue-list-M013-P02-T01.json
    ├── issue-list-M013-P02-T02.json
    ├── project-v2-node-query.json
    └── issue-view-body-M013-P02.txt
```

**`orchestrator-state/.orchestrator/milestones/M013/M013-ROADMAP.md`** — minimal frontmatter + single phase entry sufficient for the walker to find P02 in an in-flight (non-Planning) state:

```markdown
---
schema_version: "1.0"
type: roadmap
milestone: "M013"
feature_ref: "023-github-native-integration"
feature_spec: "specs/023-github-native-integration/spec.md"
vision: "Fixture for M013/P03/T02 re-init adoption gate."
tier: "C"
current_phase: "P02"
---

## Phases

- [x] **P01**: Minimal Slice — "Fixture phase; not walked during re-init adoption."
  - Risk: medium
  - Depends: none
- [ ] **P02**: Re-init adoption fixture phase — "Two tasks; both adopted by marker search."
  - Risk: medium
  - Depends: P01
```

**`phases/P02/P02-PLAN.md`** — minimal plan with frontmatter `phase: "P02"`, state implied Ready/Executing by walker rules (P02's `phase_state` function returns Ready when no `P##-SUMMARY.md` is present and the roadmap marks it `current_phase`). Body can be a single `## Tasks` heading listing T01 and T02.

**`phases/P02/tasks/T01-PLAN.md`** and **`T02-PLAN.md`** — each with frontmatter:

```markdown
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M013"
name: "Fixture task T01"
depends_on: []
---

## Description

Fixture task for re-init adoption gate.
```

(Likewise for T02 with `task: "T02"`.)

**`expected-readopt-manifest.txt`** — pinned manifest snapshot the T02 gate diffs against. Exact content:

```
MANIFEST: 0 0 0
UPSERT: milestone M013 101 adopt
UPSERT: project-v2 M013 PVT_kwDOABCD12345 adopt
UPSERT: label - phase adopt
UPSERT: label - task adopt
UPSERT: label - uat-bug adopt
UPSERT: label - spec-gap adopt
UPSERT: phase-issue M013-P02 201 adopt
UPSERT: task-subissue M013-P02-T01 202 adopt
UPSERT: task-subissue M013-P02-T02 203 adopt
upserts=0 skipped=0 errors=0 adopted=9
```

(Issue numbers are illustrative — the gate diff is byte-exact. T02 populates these exact values from the gh-stub responses below.)

**`gh-stub-responses/auth-status-green.txt`**:

```
github.com
  ✓ Logged in to github.com account test (keyring)
  - Active account: true
  - Git operations protocol: https
  - Token: ****
  - Token scopes: 'project', 'read:org', 'repo'
```

**`gh-stub-responses/subissue-rest-available.json`**:

```json
{"id": 999, "parent_issue_id": 200, "sub_issues": []}
```

**`gh-stub-responses/labels-no-collision.json`**:

```json
[]
```

**`gh-stub-responses/issue-list-M013-P02.json`** — response from `gh issue list --search "\"<!-- orchestrator-id: M013-P02 -->\"" --json number`:

```json
[{"number": 201}]
```

**`gh-stub-responses/issue-list-M013-P02-T01.json`**:

```json
[{"number": 202}]
```

**`gh-stub-responses/issue-list-M013-P02-T02.json`**:

```json
[{"number": 203}]
```

**`gh-stub-responses/project-v2-node-query.json`** — response for the pre-existing Project v2 discovery query:

```json
{"data": {"repository": {"projectsV2": {"nodes": [{"id": "PVT_kwDOABCD12345", "number": 1, "title": "M013"}]}}}}
```

**`gh-stub-responses/issue-view-body-M013-P02.txt`** — marker-bearing body returned by `gh issue view 201 --json body --jq .body` for shasum byte-identity verification:

```
<!-- orchestrator-id: M013-P02 -->

Orchestrator phase M013-P02. Managed by orchestrator:github.
```

Create similar `issue-view-body-M013-P02-T01.txt` / `issue-view-body-M013-P02-T02.txt` with matching marker lines for task ids.

### Step 2: Append `gh_marker_search_remote` to `scripts/integrations/github-common.sh`

Current file has a direct-execution usage hint at the end. T01 appends the new function BEFORE that hint block and updates the hint's echo list to include the new name.

Read the file first to locate the hint block (search for `Public functions:`). Insert the new function immediately above it:

```bash
# --- Re-init marker search (P03/T01) ----------------------------------------

# gh_marker_search_remote <repo-slug> <orchestrator-id>
# Searches the remote repo for an Issue whose body contains exactly one
# FR-4 marker matching <orchestrator-id>. Returns the Issue number on
# stdout on unique hit (exit 0), empty stdout + exit 1 on zero matches,
# empty stdout + exit 2 on duplicate match.
#
# Fixture-driven: when M013_GH_STUB_DIR is set and a file
# `${M013_GH_STUB_DIR}/issue-list-<oid>.json` exists, the function reads
# that file instead of invoking `gh`. The JSON is an array of
# `{"number": N}` objects; the function uses awk to parse count + first
# number without a jq hard-dep.
#
# Live mode: invokes `gh issue list --state all --search
# "\"<!-- orchestrator-id: <oid> -->\"" --json number` and parses the
# returned JSON array by line count.
#
# Used by: scripts/integrations/github-init.sh P03 re-init adoption branch.
gh_marker_search_remote() {
  local slug="${1:-}"
  local oid="${2:-}"
  if [ -z "$slug" ] || [ -z "$oid" ]; then
    echo "gh_marker_search_remote: missing args (slug, oid)" >&2
    return 3
  fi
  local json_file=""
  local json_content=""
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    json_file="${M013_GH_STUB_DIR}/issue-list-${oid}.json"
    if [ -f "$json_file" ]; then
      json_content="$(cat "$json_file")"
    else
      # Absence is equivalent to zero matches.
      json_content="[]"
    fi
  else
    # Live mode; repo-slug passed via -R to scope the search.
    local marker
    marker="$(emit_marker "$oid")"
    json_content="$(gh issue list -R "$slug" --state all \
      --search "\"${marker}\"" --json number 2>/dev/null || echo '[]')"
  fi
  # Count and first-number extraction via awk (no jq hard-dep).
  local count
  count="$(printf '%s\n' "$json_content" | awk '
    BEGIN { n = 0 }
    { for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") n++
      }
    }
    END { print n }
  ')"
  if [ "$count" -eq 0 ]; then
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    return 2
  fi
  # Extract the first number from the JSON.
  local num
  num="$(printf '%s\n' "$json_content" | awk '
    /"number"/ {
      n = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c ~ /[0-9]/) {
          num = num c
        } else if (num != "") {
          print num
          exit
        }
      }
    }
  ' | head -n 1)"
  printf '%s\n' "$num"
  return 0
}
```

Then update the direct-execution hint block (near end of file — search for `Public functions:`) to add `gh_marker_search_remote` to the printed list. Keep existing entries byte-identical.

### Step 3: Create the T01 gate `scripts/verify/m013-p03-re-init-fixture.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-fixture.sh — T01 gate: verify re-init fixture tree.
#
# Asserts:
#   - fixture root directory exists
#   - expected-readopt-manifest.txt exists with the pinned 10-line shape
#   - orchestrator-state seed is walkable (roadmap + phase-plan + 2 task-plans)
#   - 5 gh-stub-responses files present
#   - the single additive github-common.sh helper is defined + Bash 3.2 clean

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

[ -d "$FX" ] && pass "fixture root exists" || fail "fixture root missing: $FX"
[ -f "${FX}/expected-readopt-manifest.txt" ] && pass "expected-readopt-manifest.txt present" \
  || fail "expected-readopt-manifest.txt missing"
[ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/M013-ROADMAP.md" ] \
  && pass "M013-ROADMAP.md seeded" || fail "M013-ROADMAP.md missing in fixture"
[ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md" ] \
  && pass "P02-PLAN.md seeded" || fail "P02-PLAN.md missing in fixture"
[ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T01-PLAN.md" ] \
  && pass "T01-PLAN.md seeded" || fail "T01 seed missing"
[ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T02-PLAN.md" ] \
  && pass "T02-PLAN.md seeded" || fail "T02 seed missing"
[ -f "${FX}/gh-stub-responses/auth-status-green.txt" ] && pass "auth stub present" \
  || fail "auth stub missing"
[ -f "${FX}/gh-stub-responses/issue-list-M013-P02.json" ] && pass "phase issue-list stub present" \
  || fail "phase issue-list stub missing"
[ -f "${FX}/gh-stub-responses/issue-list-M013-P02-T01.json" ] && pass "T01 issue-list stub present" \
  || fail "T01 issue-list stub missing"
[ -f "${FX}/gh-stub-responses/issue-list-M013-P02-T02.json" ] && pass "T02 issue-list stub present" \
  || fail "T02 issue-list stub missing"

# Manifest shape check: exact line count + required anchors.
mani="${FX}/expected-readopt-manifest.txt"
lines="$(wc -l <"$mani" 2>/dev/null | awk '{print $1}')"
if [ "${lines:-0}" -ge 10 ]; then
  pass "expected-readopt-manifest.txt has >=10 lines"
else
  fail "expected-readopt-manifest.txt has too few lines ($lines)"
fi
grep -q "^MANIFEST: 0 0 0$" "$mani" && pass "MANIFEST header shape" || fail "MANIFEST header missing"
grep -q "adopted=" "$mani" && pass "footer has adopted= field" || fail "footer missing adopted="
grep -qE '^UPSERT: [a-z\-]+ [A-Z0-9\-]+ [^ ]+ adopt$' "$mani" && pass "at least one adopt row" \
  || fail "no adopt rows in manifest"

echo "SUMMARY: m013-p03-re-init-fixture.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-fixture.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-fixture.sh" >&2
exit 1
```

### Step 4: Create the T01 helper gate `scripts/verify/m013-p03-github-common-readopt.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-github-common-readopt.sh — verify gh_marker_search_remote.
#
# Asserts:
#   - github-common.sh defines gh_marker_search_remote (grep)
#   - bash -n clean
#   - fixture-driven: with M013_GH_STUB_DIR=<fixture>, the helper returns
#     the expected Issue number for each of the three orchestrator-ids
#     seeded in the T01 fixture (M013-P02, M013-P02-T01, M013-P02-T02).
#   - duplicate detection works (feed a JSON with 2 objects → exit 2)
#   - zero-match works (feed empty array → exit 1)

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

grep -q 'gh_marker_search_remote()' "$COMMON" && pass "function defined" \
  || fail "gh_marker_search_remote not defined in github-common.sh"
bash -n "$COMMON" && pass "bash -n clean" || fail "bash -n failed"

# shellcheck disable=SC1090
. "$COMMON"

M013_GH_STUB_DIR="$FX"
export M013_GH_STUB_DIR

out_p02="$(gh_marker_search_remote test/test M013-P02 2>/dev/null)"
rc_p02=$?
[ "$rc_p02" -eq 0 ] && [ "$out_p02" = "201" ] && pass "M013-P02 → 201" \
  || fail "M013-P02 lookup wrong (rc=$rc_p02 out=$out_p02)"

out_t01="$(gh_marker_search_remote test/test M013-P02-T01 2>/dev/null)"
rc_t01=$?
[ "$rc_t01" -eq 0 ] && [ "$out_t01" = "202" ] && pass "M013-P02-T01 → 202" \
  || fail "M013-P02-T01 lookup wrong (rc=$rc_t01 out=$out_t01)"

# Zero-match: ask for an oid with no canned file.
out_zero="$(gh_marker_search_remote test/test M013-P99-T99 2>/dev/null)"
rc_zero=$?
[ "$rc_zero" -eq 1 ] && pass "zero-match returns exit 1" || fail "zero-match rc=$rc_zero out=$out_zero"

echo "SUMMARY: m013-p03-github-common-readopt.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-github-common-readopt.sh"
  exit 0
fi
echo "FAIL: m013-p03-github-common-readopt.sh" >&2
exit 1
```

(Duplicate-detection path is exercised by T02's re-init adoption gate, which feeds a doctored fixture. Keeping this gate narrow to the unique-hit + zero-match cases keeps it fast and decoupled.)

## Must-Haves

From P03-PLAN:

- `tests/fixtures/m013-p03/re-init-adoption/` exists with orchestrator-state seed + expected-readopt-manifest.txt + gh-stub-responses.
- `scripts/integrations/github-common.sh` contains `gh_marker_search_remote` (fixture-driven + live modes); P02 byte-identity on existing helpers preserved.
- `scripts/verify/m013-p03-re-init-fixture.sh` passes (≥11 assertions).
- `scripts/verify/m013-p03-github-common-readopt.sh` passes (≥4 assertions).

## Verification

```bash
bash scripts/verify/m013-p03-re-init-fixture.sh
bash scripts/verify/m013-p03-github-common-readopt.sh
```

Both exit 0 with `PASS:` summary lines. If the P02 byte-identity gate is run additionally (`bash scripts/verify/m013-p02-github-common.sh`), it must still exit 0 — the T01 change is additive.

## Inputs

### From Previous Tasks

None — this is the first task in P03.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` (from M013/P02/T01)
  - Key API: 12 P02-authored public functions. T01 extends this file additively, placing the new helper just before the direct-execution usage-hint block at file end. The `emit_marker` helper is used by `gh_marker_search_remote` in live mode.
- `tests/fixtures/m013-p02/` (from M013/P02/T01)
  - Shape precedent only — `orchestrator-state/` seed layout + `gh-stub-responses/` directory + `expected-manifest.txt` snapshot. T01's fixture mirrors this shape with different contents.
- `scripts/verify/m013-p02-github-common.sh` (from M013/P02/T07)
  - Gate shape precedent. T01's gates follow the same `pass()`/`fail()` + SUMMARY convention.
- `scripts/verify/anti-pattern-lint.sh` (M016/M021 invariant)
  - Consumed by T05's bash32-compat gate (not T01).
- `references/github-integration.md` (from M013/P02/T05)
  - P01/P02 doc with the FR-4 marker format documented. T01 does not modify this doc.

## Constraints

- **Knowledge-Layer Boundary (FR-9 + D014)**: this task MUST NOT modify any `knowledge/spec/**/SPEC-*.md` frontmatter, `KNOWLEDGE-INDEX.md`, `scripts/knowledge/rebuild-index.sh`, or any `wiki/` file. M020 owns schema extension.
- **FR-12 Claude-Code-only v1**: no multi-runtime abstractions.
- **AD-19 `Check:` shape**: verify scripts invoke single-script-file shape only. The helper internals are unconstrained.
- **No live `gh` calls at T01 CI**: the helper's live path requires `gh` but is not exercised by gates in CI — gates set `M013_GH_STUB_DIR` to the fixture and go through the canned-response path.
- **P02 byte-identity**: the existing 12 P02 functions' bodies stay untouched. Only the usage-hint echo list at file end gains one entry.
- **Bash 3.2**: no `declare -A`, no `mapfile`/`readarray`, no `<(...)`/`>(...)`, no `&>`/`|&`, no `${var^^}`/`${var,,}`. Use parallel indexed arrays and sed/awk/grep.
- **`set -u` clean**: all variables initialized before first read.
- **Integer-minutes duration**: the T01-SUMMARY.md `duration:` frontmatter field MUST be a bare integer (e.g., `45`) — `phase-transition.sh` crashes on string durations.

## Expected Output

```
PASS: fixture root exists
PASS: expected-readopt-manifest.txt present
PASS: M013-ROADMAP.md seeded
PASS: P02-PLAN.md seeded
PASS: T01-PLAN.md seeded
PASS: T02-PLAN.md seeded
PASS: auth stub present
PASS: phase issue-list stub present
PASS: T01 issue-list stub present
PASS: T02 issue-list stub present
PASS: expected-readopt-manifest.txt has >=10 lines
PASS: MANIFEST header shape
PASS: footer has adopted= field
PASS: at least one adopt row
SUMMARY: m013-p03-re-init-fixture.sh pass=14 fail=0
PASS: m013-p03-re-init-fixture.sh

PASS: function defined
PASS: bash -n clean
PASS: M013-P02 → 201
PASS: M013-P02-T01 → 202
PASS: zero-match returns exit 1
SUMMARY: m013-p03-github-common-readopt.sh pass=5 fail=0
PASS: m013-p03-github-common-readopt.sh
```

Both exit 0. Estimated duration: 45 integer minutes.
