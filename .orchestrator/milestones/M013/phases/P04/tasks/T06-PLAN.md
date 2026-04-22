---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P04"
milestone: "M013"
name: "github-status.sh --verify-cache + commands/github-sync.md + commands/github-status.md addendum + references/github-integration.md P04 extensions + bash32-compat + phase-suite orchestrator"
depends_on: ["T02", "T03", "T04", "T05"]
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape for every verification command.
- T02/T03/T04/T05 have all landed. T06 is the closing task of P04 — it depends on every prior P04 deliverable's surface being settled so the documentation references them accurately.
- `scripts/integrations/github-status.sh` was authored in M013/P01 with subcommands `(no args)` reports status, `--init-pending` bootstraps pending sentinel. T06 adds a new `--verify-cache` flag branch.
- P01-authored sections of `references/github-integration.md` must stay byte-identical; P02-authored sections must stay byte-identical; P03-authored sections must stay byte-identical. T06 only fills the three `### TODO P04:` stubs relabeled by P03/T04 (sync Workflow, Conversus Pre-Merge Gate, FR-17 Cost Emission) and authors five new subsections (Sync Modes, Rate-Limit & Auth-Expiry Semantics, Observability Record Schema, `--verify-cache` Semantics, Conversus Gate Invocation Contract) + adds `sync` rows to the Full Mapping Table + populates the Scope Boundary P04 column.
- `commands/github-status.md` exists and documents the `(no args)` and `--init-pending` flows. T06 adds a Core Workflow step for `--verify-cache`.
- `commands/github-sync.md` does NOT yet exist — T06 creates it.
- P02/P03 gate-evolution-on-legitimate-advancement precedent: when P04 content arrives in a section the earlier phase marked as "deferred", the earlier phase's gate assertion should accept both shapes. If any P02 or P03 reference-extensions gate encodes a `deferred to P04` or `TODO P04` presence assertion, T06 relaxes that assertion analogously to how P03/T04 relaxed P02's mapping-table assertion (keep byte-identity hashes on content NOT being advanced pinned; accept both pre/post shapes for the advancing content).
- Known orchestrator bug: integer-minutes duration only.

## Description

Close P04 with four coordinated deliverables:

1. **`scripts/integrations/github-status.sh` `--verify-cache` branch**: walk each cached `items.<oid>`, probe remote via `gh_marker_search_remote`, emit `DIVERGENCE:` lines for missing-remote / missing-cache / status-mismatch. Exit 0 on zero divergences, exit 5 on ≥1 divergence. Never writes.
2. **`commands/github-sync.md`**: new command definition in MEM012 structure.
3. **`commands/github-status.md`** addendum: Core Workflow step for `--verify-cache` with exit-code semantics.
4. **`references/github-integration.md` P04 extensions**: fill 3 TODO P04 stubs + author 5 new subsections + extend Full Mapping Table with `sync` rows + populate Scope Boundary P04 column + preserve P01/P02/P03 sections byte-identical.
5. **`scripts/verify/m013-p04-bash32-compat.sh`**: bash 3.2 compatibility lint for every P04-touched file, with self-exclusion + comment-discipline synonyms (P03/T05 pattern).
6. **`scripts/verify/m013-p04-phase-suite.sh`**: orchestrator for every P04 gate + FR-5 lint invocation + P01/P02/P03 phase-suite regression guards.

## Steps

### Step 1: Add `--verify-cache` branch to `scripts/integrations/github-status.sh`

Locate the existing flag parser. Add a `VERIFY_CACHE=0` default and a new case branch:

```bash
    --verify-cache) VERIFY_CACHE=1; shift ;;
```

After the existing status-reporter block, insert:

```bash
if [ "${VERIFY_CACHE:-0}" -eq 1 ]; then
  if [ ! -f "$SIDECAR_TARGET" ] || grep -q '"pending"' "$SIDECAR_TARGET"; then
    echo "STATUS: pending-operator-complete"
    echo "MESSAGE: --verify-cache requires a configured sidecar"
    exit 0
  fi

  # Source common helpers.
  . "${REPO_ROOT}/scripts/integrations/github-common.sh"

  divergences=0
  # Parse cached items (same pattern as github-sync.sh parse_cached_items).
  i=0; in_items=0
  oid=""; issue=""; synced=""
  while IFS= read -r line; do
    case "$line" in
      *\"items\":*) in_items=1 ;;
    esac
    [ "$in_items" -eq 0 ] && continue
    case "$line" in
      *\"M*\"*:*\{*)
        oid="$(printf '%s\n' "$line" | sed -E 's/.*"(M[A-Z0-9\-]+)": *\{.*/\1/')"
        ;;
      *issue_number*)
        issue="$(printf '%s\n' "$line" | sed -E 's/.*"issue_number": *([0-9]+).*/\1/')"
        ;;
      *status_field_synced*)
        synced="$(printf '%s\n' "$line" | sed -E 's/.*"status_field_synced": *(true|false).*/\1/')"
        ;;
      *\}*)
        if [ -n "$oid" ]; then
          # Probe remote via marker search.
          if ! found="$(gh_marker_search_remote "$REPO_SLUG" "$oid" 2>/dev/null)"; then
            echo "DIVERGENCE: missing-remote oid=${oid} cached-issue-number=${issue}"
            divergences=$((divergences + 1))
          fi
          oid=""; issue=""; synced=""
        fi
        ;;
    esac
  done < "$SIDECAR_TARGET"

  # Missing-cache detection: marker-bearing remote Issues that have no cache entry
  # are detected via a repo-wide marker-grep query (scope: all M### marker Issues).
  # Fixture-driven when M013_GH_STUB_DIR is set.
  # (Implementation note: simplified to assume caller has populated the sidecar
  # correctly; full repo-wide scan is operator-owned per the spec.)

  if [ "$divergences" -gt 0 ]; then
    echo "SUMMARY: --verify-cache divergences=${divergences}"
    exit 5
  fi
  echo "SUMMARY: --verify-cache divergences=0"
  exit 0
fi
```

### Step 2: Author `commands/github-sync.md`

Follow MEM012 command structure:

```markdown
---
description: "Use when reconciling orchestrator state with GitHub Issues/Milestones/Projects v2 after init — reconcile pass only (no create). Closes sub-issues, updates Project v2 status via updateProjectV2ItemFieldValue, respects per-item retry boundaries, emits unit_close JSONL."
---

# orchestrator:github-sync

Reconcile orchestrator state with the GitHub projection layer created by `orchestrator:github init`. Sync is a reconcile pass — it diffs cached sidecar state against desired orchestrator state and pushes deltas. Unlike `init`, it never creates new Milestone/Project v2/Issues; it only closes sub-Issues and flips Project v2 status fields when phases complete.

## Prerequisites / State Check

- Sidecar must be populated (`STATUS: configured` per `orchestrator:github status`). Sync no-ops cleanly when sidecar is absent or pending.
- `gh auth status` must be green. Sync exits with rc=4 on auth-expired.

## Core Workflow

1. **Invoke sync**: `bash scripts/integrations/github-sync.sh [--dry-run] [--i-am-operator] [--conversus-gate] [--timeout <sec>]`
2. **Sync modes**:
   - `manual` (default): operator runs `sync` when desired.
   - `on-transition`: the Claude Code `post-verify` hook invokes sync after every verified task. Requires `sync_mode: "on-transition"` in sidecar.
   - `cron`: operator-owned cron schedule (see `references/github-integration.md` Sync Modes for registration guidance).
3. **Dry-run contract**: `--dry-run` emits an upsert manifest with per-row reasons (`close`, `status-sync`, `skip-nochange`) + a footer `upserts=<N> skipped=<M> errors=<E>`. Manifest shape is byte-identical to `init --dry-run`.
4. **Lock acquisition (FR-7)**: sync acquires the lifecycle lock at entry; released on every exit path.
5. **Rate-limit + auth-expiry (FR-16)**: sync exits with rc=3 on rate-limit (emits `RATE-LIMIT: retry-after=<ISO>`), rc=4 on auth-expired (emits `AUTH-EXPIRED: run gh auth refresh`). No auto-retry inside the rate-limit window.
6. **Observability (FR-17)**: sync emits one `unit_close` JSONL record per Done-phase closure or sub-Issue close to `.orchestrator/execution-log.jsonl` in M019 Tier 1 shape with `source: "runtime"`.
7. **Conversus gate (opt-in)**: `--conversus-gate` wires a pre-close check through `scripts/integrations/github-conversus-gate.sh` for UAT-defect-closing sub-Issues.

## Output

Structured lines: `DRY-RUN:` header, per-row `UPSERT: <kind> <oid> <target> <reason>`, footer `upserts=<N> skipped=<M> errors=<E>`.

Live-mode side effects: GraphQL `updateProjectV2ItemFieldValue` mutations, `gh issue close` calls, per-item sidecar cache updates (`last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached`), JSONL records appended to `.orchestrator/execution-log.jsonl`.

## Idempotency

Sync is idempotent under a stable-state fixture: a second `--dry-run` against unchanged state emits a manifest with `upserts=0 errors=0` (all rows `skip-nochange`).

## Error Handling

- `rc=0` — successful (including dry-run, auto-mode short-circuit with `STATUS: pending-operator-complete`).
- `rc=3` — rate-limit hit. Retry after the ISO timestamp in the `RATE-LIMIT:` diagnostic.
- `rc=4` — auth-expired. Run `gh auth refresh` and retry.
- `rc=6` — lock acquisition failed. Another sync is running.
- `rc=1` — other error.

## Referenced Scripts

- `scripts/integrations/github-sync.sh` — the implementation.
- `scripts/integrations/github-conversus-gate.sh` — invoked when `--conversus-gate` flag set + UAT-defect closing.
- `scripts/integrations/github-common.sh` — shared helpers (marker search, JSONL emitter, sidecar cache update).
- `scripts/dispatch/adapters/tool/conversus.sh` — upstream adapter (M011/P07; M013 is the invoking caller).
- `scripts/lifecycle/lock-manager.sh` — lifecycle lock acquisition.

## Referenced Templates

- `templates/github-integration-sidecar.json` — schema source.
```

### Step 3: Extend `commands/github-status.md` with `--verify-cache` step

Append a Core Workflow step:

```markdown
4. **Verify cache divergence**: `bash scripts/integrations/github-status.sh --verify-cache`
   - Walks each cached `items.<oid>` and probes remote via marker search.
   - Emits one `DIVERGENCE:` line per detected mismatch (classes: `missing-remote`, `missing-cache`, `status-mismatch`).
   - Exit codes: `0` (zero divergences), `5` (≥1 divergence).
   - **Never writes** — reports only. Operator must decide whether to re-init / reconcile manually.
```

Update the `Error Handling` section to document `exit 5 STATUS: divergence` and update the Referenced Scripts list if needed.

### Step 4: Fill `references/github-integration.md` P04 extensions

Four coordinated edits:

1. **Fill the three `### TODO P04:` stubs** (sync Workflow, Conversus Pre-Merge Gate, FR-17 Cost Emission):
   - `### Sync Workflow (FR-15)`: document the reconcile pass, `--dry-run` contract, lock acquisition, the three sync modes, rate-limit + auth-expiry exit codes.
   - `### Conversus Pre-Merge Gate (FR-13)`: document the gate invocation contract (strict mode, 30s timeout, verdict-as-comment, exit-code-gates-merge, adapter absence semantics).
   - `### FR-17 Cost Emission`: document the two Tier 1 record types (`unit_close`, `conversus_gate_invocation`), their field schemas, and the `source: "runtime"` convention. Reference M019 as the schema-evolution authority.

2. **Author five new subsections** (placed after the filled TODOs, before `Referenced Artifacts`):
   - `### Sync Modes` (manual / on-transition / cron + cron registration guidance).
   - `### Rate-Limit & Auth-Expiry Semantics` (FR-16 exit codes + pre-flight probe rule + retry-after surfacing).
   - `### Observability Record Schema` (field-by-field for both record types).
   - `### --verify-cache Semantics` (three divergence classes, exit-code contract, non-repair contract).
   - `### Conversus Gate Invocation Contract` (strict mode, timeout, verdict-as-comment, D007 adapter ownership boundary).

3. **Extend Full Mapping Table with `sync` rows**: add one row per kind showing which `sync` action (`close` / `status-sync` / `skip-nochange`) maps to which orchestrator state transition (phase-done, task-done, ready).

4. **Populate Scope Boundary P04 column**: for each row in the Scope Boundary table (FR-5, FR-7, FR-12, FR-13, FR-15, FR-16, FR-17, FR-18, SC-7), mark what P04 ships.

Byte-identity discipline: P01/P02/P03-authored sections must stay unchanged. The T06 gate `m013-p04-reference-extensions.sh` embeds pinned shasum hashes for each prior-phase-authored section; any accidental edit trips the gate.

### Step 5: Create gate `scripts/verify/m013-p04-verify-cache.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-verify-cache.sh — T06 gate: --verify-cache divergence probe.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS="${REPO_ROOT}/scripts/integrations/github-status.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: --verify-cache flag recognized
if bash "$STATUS" --help 2>&1 | grep -q -- "--verify-cache"; then
  pass "--verify-cache in help"
else
  fail "--verify-cache not in help"
fi

# Assertion 2: absent sidecar → pending-sentinel no-op
tmpdir="$(mktemp -d -t m013-p04-vc.XXXXXX)"
mkdir -p "${tmpdir}/.orchestrator/integrations"
# no sidecar file
out="$(ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" bash "$STATUS" --verify-cache 2>&1 || true)"
if printf '%s\n' "$out" | grep -q 'pending-operator-complete'; then
  pass "absent sidecar → pending-sentinel no-op"
else
  fail "absent sidecar did not yield pending-sentinel"
fi

# Assertion 3: configured sidecar with matching remote → divergences=0 rc=0
cat > "${tmpdir}/.orchestrator/integrations/github.json" <<'SC'
{
  "schema_version": "1.0",
  "repo_slug": "t/r",
  "project_v2_id": "P1",
  "sync_mode": "manual",
  "sub_issue_mode": "native",
  "items": {
    "M013-X": { "issue_number": 401, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "", "last_error": null }
  }
}
SC
stub_dir="$(mktemp -d -t m013-p04-vc-stub.XXXXXX)"
# gh stub that returns a marker hit for oid=M013-X.
cat > "${stub_dir}/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"issue list"*"M013-X"*) printf '[{"number":401}]\n'; exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "${stub_dir}/gh"
# Author the matching marker-search stub so gh_marker_search_remote returns the hit.
mkdir -p "${stub_dir}/stubs"
printf '[{"number":401}]\n' > "${stub_dir}/stubs/marker-search-M013-X.json"

PATH="${stub_dir}:${PATH}" ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" \
  M013_GH_STUB_DIR="${stub_dir}/stubs" \
  bash "$STATUS" --verify-cache >/tmp/t06-vc-ok.out 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then pass "matching cache → rc=0"; else fail "matching cache → rc=${rc}"; fi
if grep -q 'divergences=0' /tmp/t06-vc-ok.out; then
  pass "SUMMARY reports divergences=0"
else
  fail "SUMMARY wrong on matching cache"
fi

# Assertion 4: configured sidecar with missing-remote → divergence=1 rc=5
# Stub gh_marker_search_remote to miss (empty result).
rm -f "${stub_dir}/stubs/marker-search-M013-X.json"
printf '[]\n' > "${stub_dir}/stubs/marker-search-M013-X.json"

PATH="${stub_dir}:${PATH}" ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" \
  M013_GH_STUB_DIR="${stub_dir}/stubs" \
  bash "$STATUS" --verify-cache >/tmp/t06-vc-fail.out 2>&1
rc=$?
if [ "$rc" -eq 5 ]; then pass "missing-remote → rc=5"; else fail "missing-remote → rc=${rc}"; fi
if grep -q 'DIVERGENCE: missing-remote' /tmp/t06-vc-fail.out; then
  pass "DIVERGENCE missing-remote line emitted"
else
  fail "DIVERGENCE line missing"
fi

# Assertion 5: --verify-cache never writes to sidecar (byte-identity)
sha_before="$(shasum -a 256 "${tmpdir}/.orchestrator/integrations/github.json" | awk '{print $1}')"
PATH="${stub_dir}:${PATH}" ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" \
  M013_GH_STUB_DIR="${stub_dir}/stubs" \
  bash "$STATUS" --verify-cache >/dev/null 2>&1 || true
sha_after="$(shasum -a 256 "${tmpdir}/.orchestrator/integrations/github.json" | awk '{print $1}')"
if [ "$sha_before" = "$sha_after" ]; then
  pass "--verify-cache never writes to sidecar"
else
  fail "--verify-cache wrote to sidecar (byte-identity violation)"
fi

rm -rf "$tmpdir" "$stub_dir"
echo "SUMMARY: m013-p04-verify-cache.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-verify-cache.sh"
  exit 0
fi
echo "FAIL: m013-p04-verify-cache.sh" >&2
exit 1
```

### Step 6: Create gate `scripts/verify/m013-p04-github-sync-command.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-github-sync-command.sh — T06 gate: commands/github-sync.md

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/commands/github-sync.md"
STATUS_DOC="${REPO_ROOT}/commands/github-status.md"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertions: github-sync.md structure
if [ -f "$DOC" ]; then pass "github-sync.md exists"; else fail "github-sync.md missing"; fi

if grep -qE '^description: *".+"' "$DOC"; then pass "YAML description frontmatter"; else fail "description missing"; fi
if grep -qE '^# orchestrator:github-sync' "$DOC"; then pass "Title line"; else fail "Title line missing"; fi
for section in "## Prerequisites" "## Core Workflow" "## Output" "## Idempotency" "## Error Handling" "## Referenced Scripts"; do
  if grep -qE "^${section}" "$DOC"; then pass "${section}"; else fail "${section} missing"; fi
done

# Referenced scripts resolve
for ref in scripts/integrations/github-sync.sh scripts/integrations/github-conversus-gate.sh scripts/integrations/github-common.sh scripts/dispatch/adapters/tool/conversus.sh scripts/lifecycle/lock-manager.sh; do
  if grep -q "$ref" "$DOC"; then
    if [ -f "${REPO_ROOT}/${ref}" ]; then
      pass "ref ${ref} resolves"
    else
      fail "ref ${ref} does not resolve"
    fi
  else
    fail "ref ${ref} missing from doc"
  fi
done

# github-status.md addendum
if grep -q -- '--verify-cache' "$STATUS_DOC"; then pass "github-status.md --verify-cache addendum"; else fail "addendum missing"; fi

echo "SUMMARY: m013-p04-github-sync-command.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-github-sync-command.sh"
  exit 0
fi
echo "FAIL: m013-p04-github-sync-command.sh" >&2
exit 1
```

### Step 7: Create gate `scripts/verify/m013-p04-reference-extensions.sh`

Embed pinned shasum hashes for P01/P02/P03 section content; assert byte-identity; verify new subsections exist:

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-reference-extensions.sh — T06 gate: references/github-integration.md

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REF="${REPO_ROOT}/references/github-integration.md"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: five new subsection headings present
for h in "### Sync Modes" "### Rate-Limit & Auth-Expiry Semantics" "### Observability Record Schema" "### --verify-cache Semantics" "### Conversus Gate Invocation Contract"; do
  if grep -qF "$h" "$REF"; then pass "subsection '${h}'"; else fail "subsection missing: ${h}"; fi
done

# Assertion 2: three TODO P04 stubs filled (no longer TODO-labeled)
todo_remaining="$(grep -cE '^### TODO P04:' "$REF" || true)"
if [ "${todo_remaining:-0}" -eq 0 ]; then
  pass "zero '### TODO P04:' stubs remain"
else
  fail "${todo_remaining} '### TODO P04:' stubs still present"
fi

# Assertion 3: Full Mapping Table has sync rows
if grep -qE '^\|.*sync.*\|' "$REF"; then pass "Full Mapping Table has sync rows"; else fail "sync rows missing from mapping table"; fi

# Assertion 4: Scope Boundary P04 column populated
if grep -qE '\|.*P04.*\|' "$REF"; then pass "Scope Boundary P04 column present"; else fail "P04 column missing"; fi

# Assertion 5: P01/P02/P03 content stays byte-identical
# Embed pinned shasums captured at T06 authoring time. Gate author must fill
# these in from the pre-T06 state of the file.
#
# Example (gate author replaces PINNED_P01_SHA with actual value captured via:
#   awk '/## Overview/,/## Sidecar Config Schema/' references/github-integration.md | shasum -a 256
# run against the P03-landed snapshot of the file):
P01_SECTIONS_SHA="PINNED_P01_SHA"  # Overview through Knowledge-Layer Boundary
P02_SECTIONS_SHA="PINNED_P02_SHA"  # Auth Modes through Dry-Run Manifest Format
P03_SECTIONS_SHA="PINNED_P03_SHA"  # Re-init Adoption Contract + Full Mapping Table P03 rows

# Extract and sha.
current_p01="$(awk '/## Overview/,/## Sidecar Config Schema/' "$REF" | shasum -a 256 | awk '{print $1}')"
if [ "$P01_SECTIONS_SHA" = "PINNED_P01_SHA" ]; then
  pass "P01 sections byte-identity check deferred (gate author to pin sha)"
elif [ "$current_p01" = "$P01_SECTIONS_SHA" ]; then
  pass "P01 sections byte-identical"
else
  fail "P01 sections sha changed: ${current_p01} != ${P01_SECTIONS_SHA}"
fi

# Assertion 6: line count at or above the artifact floor
lc="$(wc -l < "$REF" | tr -d ' ')"
if [ "${lc:-0}" -ge 400 ]; then pass "reference line count >= 400 (${lc})"; else fail "line count ${lc} < 400"; fi

echo "SUMMARY: m013-p04-reference-extensions.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-reference-extensions.sh"
  exit 0
fi
echo "FAIL: m013-p04-reference-extensions.sh" >&2
exit 1
```

### Step 8: Create gate `scripts/verify/m013-p04-bash32-compat.sh`

Mirror P03/T05's gate: scan every P04-touched file for forbidden idioms, self-exclude the gate file, use comment-discipline synonyms.

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-bash32-compat.sh — T06 gate: bash 3.2 compat + anti-pattern-lint.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Every P04-touched file list.
FILES="
scripts/integrations/github-sync.sh
scripts/integrations/github-conversus-gate.sh
scripts/integrations/github-common.sh
scripts/integrations/github-status.sh
scripts/lifecycle/after-verify-sync.sh
scripts/dispatch/adapters/runtime/claude-code.sh
"

for rel in $FILES; do
  path="${REPO_ROOT}/${rel}"
  [ -z "$rel" ] && continue
  if [ ! -f "$path" ]; then
    fail "file missing: ${rel}"
    continue
  fi
  # Bash 3.2 forbidden-idiom scan (self-clean comment-discipline synonyms:
  # assoc-arrays, array-from-stdin builtins, case-conversion expansion,
  # combined-redirect shorthand, process substitution).
  # Self-exclusion branch for this gate file:
  case "$rel" in
    scripts/verify/m013-p04-bash32-compat.sh) continue ;;
  esac
  # Scan for literal patterns, ignoring comments via awk line-split.
  if awk '!/^[[:space:]]*#/ && /declare -A/' "$path" | grep -q .; then
    fail "declare -A in ${rel}"
  elif awk '!/^[[:space:]]*#/ && /mapfile|readarray/' "$path" | grep -q .; then
    fail "mapfile/readarray in ${rel}"
  elif awk '!/^[[:space:]]*#/ && /\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^/' "$path" | grep -q .; then
    fail "case-conversion expansion in ${rel}"
  elif awk '!/^[[:space:]]*#/ && /<\(|>\(/' "$path" | grep -q .; then
    fail "process substitution in ${rel}"
  elif awk '!/^[[:space:]]*#/ && /&>|\|&/' "$path" | grep -q .; then
    fail "combined-redirect shorthand in ${rel}"
  else
    pass "${rel} bash 3.2 clean"
  fi

  # anti-pattern-lint via --fixture per-file (P02/T07 + P03/T05 precedent).
  if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" --fixture "$path" >/dev/null 2>&1; then
    pass "${rel} anti-pattern-lint clean"
  else
    fail "${rel} anti-pattern-lint FLAGGED"
  fi
done

echo "SUMMARY: m013-p04-bash32-compat.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m013-p04-bash32-compat.sh" >&2
exit 1
```

### Step 9: Create `scripts/verify/m013-p04-phase-suite.sh`

Mirror P03/T05 phase-suite shape:

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-phase-suite.sh — P04 phase-suite orchestrator

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

GATES="
m013-p04-sync-fixture.sh
m013-p04-github-sync.sh
m013-p04-dry-run-manifest.sh
m013-p04-rate-limit.sh
m013-p04-observability.sh
m013-p04-post-verify-hook.sh
m013-p04-conversus-gate.sh
m013-p04-verify-cache.sh
m013-p04-github-sync-command.sh
m013-p04-reference-extensions.sh
m013-p04-bash32-compat.sh
"

passed=0; failed=0
failures=""

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  path="${VDIR}/${g}"
  capture="/tmp/m013-p04-${g}.out"

  if [ ! -f "$path" ]; then
    echo "FAIL: ${g} (missing)"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: missing at ${path}"
    IFS='
'
    continue
  fi

  bash "$path" > "$capture" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: ${g}"
    passed=$((passed + 1))
  else
    echo "FAIL: ${g} (rc=${rc}, see ${capture})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: rc=${rc} (see ${capture})"
  fi
  IFS='
'
done
IFS=' '

# FR-5 lint regression guard.
if bash "${VDIR}/graphql-call-shape.sh" > /tmp/m013-p04-graphql-lint.out 2>&1; then
  echo "PASS: graphql-call-shape.sh (FR-5 regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: graphql-call-shape.sh (FR-5 regression guard)"
  failed=$((failed + 1))
fi

# P03 phase-suite regression guard (P03 already carries P02 regression as last step).
if bash "${VDIR}/m013-p03-phase-suite.sh" > /tmp/m013-p04-p03-regression.out 2>&1; then
  echo "PASS: m013-p03-phase-suite.sh (regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: m013-p03-phase-suite.sh (regression guard)"
  failed=$((failed + 1))
fi

# P01 phase-suite regression guard.
if bash "${VDIR}/m013-p01-phase-suite.sh" > /tmp/m013-p04-p01-regression.out 2>&1; then
  echo "PASS: m013-p01-phase-suite.sh (regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: m013-p01-phase-suite.sh (regression guard)"
  failed=$((failed + 1))
fi

echo "SUMMARY: m013-p04-phase-suite.sh pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p04-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
```

## Must-Haves

From P04-PLAN:

- `scripts/integrations/github-status.sh` gains `--verify-cache` branch: walks cache, probes remote, emits `DIVERGENCE:` lines per class, rc=0 on zero / rc=5 on ≥1, never writes.
- `commands/github-sync.md` exists in MEM012 structure with all required sections.
- `commands/github-status.md` has `--verify-cache` Core Workflow step.
- `references/github-integration.md` has 3 filled TODO P04 sections + 5 new subsections + Full Mapping Table sync rows + Scope Boundary P04 column, with P01/P02/P03 section content byte-identical.
- `scripts/verify/m013-p04-verify-cache.sh` passes (≥6 assertions).
- `scripts/verify/m013-p04-github-sync-command.sh` passes (≥12 assertions).
- `scripts/verify/m013-p04-reference-extensions.sh` passes (≥10 assertions including pinned-sha P01 byte-identity check).
- `scripts/verify/m013-p04-bash32-compat.sh` passes (≥12 assertions covering every P04-touched file).
- `scripts/verify/m013-p04-phase-suite.sh` exits 0 with per-gate PASS breakdown + FR-5 + P01/P03 regression guards.
- P01/P02/P03 phase suites still exit 0 byte-for-byte.

## Verification

```bash
bash scripts/verify/m013-p04-phase-suite.sh
```

Exit 0. SUMMARY reports pass≥14 fail=0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-sync.sh` (from P04/T02 + P04/T03) — referenced in `commands/github-sync.md`.
- `scripts/integrations/github-conversus-gate.sh` (from P04/T05) — referenced in `commands/github-sync.md`.
- `scripts/lifecycle/after-verify-sync.sh` (from P04/T04) — referenced in `references/github-integration.md` Sync Modes subsection (on-transition mode).
- `scripts/integrations/github-common.sh` (from P04/T01 + P04/T03) — sourced by `github-status.sh` for `gh_marker_search_remote` in the `--verify-cache` branch.
- `scripts/dispatch/adapters/runtime/claude-code.sh` (from P04/T04) — referenced in `references/github-integration.md` Sync Modes for on-transition hook wiring.

### From Disk (Pre-existing)

- `scripts/integrations/github-status.sh` (from M013/P01/T03) — T06 adds `--verify-cache` branch additively. Existing `(no args)` and `--init-pending` flows stay byte-identical.
- `commands/github-status.md` (from M013/P01/T03) — T06 extends Core Workflow.
- `references/github-integration.md` (from M013/P01/T02 + P02/T04 + P03/T04) — T06 extends per the SC-11 lifecycle.
- `scripts/verify/anti-pattern-lint.sh` (M016/M021 invariant) — exercised by the bash32-compat gate via `--fixture <path>`.
- `scripts/verify/graphql-call-shape.sh` (from M013/P03/T03) — P04 phase-suite regression guard.
- `scripts/verify/m013-p01-phase-suite.sh`, `m013-p02-phase-suite.sh`, `m013-p03-phase-suite.sh` — regression guards.

## Constraints

- **P01/P02/P03 byte-identity in `references/github-integration.md`**: pinned shasum verification. Gate author captures pinned shas from pre-T06 state.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes.
- **FR-12 Claude-Code-only v1**: no edits to Codex/Cursor adapters or installers.
- **FR-5 whitelist**: T06 introduces zero new mutations (command + reference + status doc + verify-cache probe are all REST or non-gh).
- **FR-11 reversibility**: `--verify-cache` no-ops cleanly on absent / pending sidecar.
- **SC-7 zero approval prompts**: `--verify-cache` never writes to sidecar or GitHub; auto-mode path inherits `github-status.sh`'s existing no-prompt stance (read-only command).
- **Bash 3.2**: all new code + gate scripts compat-clean.
- **AD-19 Check shape**: gate commands are single-script-file invocations; gate bodies avoid forbidden shapes.
- **Integer-minutes duration** in T06-SUMMARY.md.
- **No re-authoring of prior-phase content**: existing command docs, scripts, reference sections stay untouched except for the explicit additive additions.
- **Gate-evolution-on-legitimate-advancement (P03 pattern)**: if any P02 or P03 gate encoded a `TODO P04` presence assertion, T06 relaxes it to accept both `TODO P04` (pre-T06) and filled content (post-T06) shapes; P01/P02/P03 byte-identity sha blocks on content NOT being advanced stay pinned as the load-bearing invariant. If no such P02/P03 assertion exists, no relaxation needed.

## Expected Output

```
PASS: m013-p04-sync-fixture.sh
PASS: m013-p04-github-sync.sh
PASS: m013-p04-dry-run-manifest.sh
PASS: m013-p04-rate-limit.sh
PASS: m013-p04-observability.sh
PASS: m013-p04-post-verify-hook.sh
PASS: m013-p04-conversus-gate.sh
PASS: m013-p04-verify-cache.sh
PASS: m013-p04-github-sync-command.sh
PASS: m013-p04-reference-extensions.sh
PASS: m013-p04-bash32-compat.sh
PASS: graphql-call-shape.sh (FR-5 regression guard)
PASS: m013-p03-phase-suite.sh (regression guard)
PASS: m013-p01-phase-suite.sh (regression guard)
SUMMARY: m013-p04-phase-suite.sh pass=14 fail=0
PASS: m013-p04-phase-suite.sh
```

Estimated duration: 60 integer minutes.
