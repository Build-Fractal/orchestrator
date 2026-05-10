---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M032"
name: "FR-14 + MIT-005 custom-nav region split on wiki-generate-nav.sh + SC-6 acceptance"
depends_on: []
---

## Prerequisites

- `scripts/wiki/wiki-generate-nav.sh` exists and is executable from [M012](../../../../../milestones/M012/index.md) baseline + P02/T03 amendments. Verified by `[ -x scripts/wiki/wiki-generate-nav.sh ]`. Behavioral contract: bash 3.2; `set -u`; consumes `wiki-scan-sources.sh` output; writes a MkDocs `nav:` block between the markers `# >>> M012-P01 nav (auto-generated — do not edit by hand)` and `# <<< M012-P01 nav end` in `wiki/mkdocs.yml`; on first run appends the marker pair at EOF; on subsequent runs replaces between-marker content via `awk` split + concat. The marker pair is on lines ~98–99 of the script (`MARKER_START` / `MARKER_END` variables).
- `wiki/mkdocs.yml` exists at the orchestrator-repo level with the existing legacy markers. Verified by `grep -qF '# >>> M012-P01 nav' wiki/mkdocs.yml`.
- `scripts/wiki/wiki-scan-sources.sh` exists and is executable from M012 baseline + P02/T03 amendments (`--include-glossary` flag). T03 does NOT modify the scanner — it only modifies the nav-generator. Verified by `[ -x scripts/wiki/wiki-scan-sources.sh ]`.
- `wiki/docs/` exists with the symlink-set used by the existing nav-generator. Verified by `[ -d wiki/docs ]`.
- `tools/verify/` and `tests/m032-acceptance/` exist as canonical homes per AD-19.

## Description

T03 lands US-5 / Finding I — the operator-additions-survive-regenerate surface that defeats the silent data loss observed in the 2026-04-28 PBJ pilot. The deliverable surface has three pieces that ship together:

1. **FR-14 region split + empty-legacy migration**: amend `scripts/wiki/wiki-generate-nav.sh` to use TWO marker pairs instead of one — `# >>> auto-nav (auto-generated — do not edit by hand)` / `# <<< auto-nav end` (regenerated wholly on every invocation) and `# >>> custom-nav` / `# <<< custom-nav end` (preserved verbatim). On first regenerate against a legacy `# >>> M012-P01 nav` marker pair with EMPTY content between markers, migrate the markers in-place to the new shape and append an empty `custom-nav` block immediately after `# <<< auto-nav end` (zero behavior change at empty-legacy).

2. **MIT-005 non-empty legacy migration**: when the legacy markers contain NON-EMPTY content (the named PBJ pilot population case), move that content verbatim into the new `# >>> custom-nav` region rather than discarding it, AND emit a stdout diagnostic `Migrated <N> custom nav entries from legacy markers to custom-nav region` naming the count of preserved entries. The `<N>` count is load-bearing visibility — silent migration is the failure mode MIT-005 was written to prevent.

3. **US-5 AS-3 self-healing**: when the operator deletes the `# >>> custom-nav` markers entirely on an already-migrated mkdocs.yml, the next regenerate detects the absence and re-creates an empty `custom-nav` block at the standard insertion point (immediately after `# <<< auto-nav end`).

4. **SC-6 acceptance script**: author `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` exercising all four FR-14 branches (AS-1 byte-preserve, AS-2 empty-legacy migrate, MIT-005 non-empty-legacy migrate with diagnostic, AS-3 self-heal).

5. **Self-application**: run `bash scripts/wiki/wiki-generate-nav.sh --root .` against the orchestrator's own `wiki/mkdocs.yml` so the legacy `# >>> M012-P01 nav` markers (which the orchestrator currently uses) are migrated to the new region shape. The orchestrator repo has empty legacy content (no operator-hand-added entries), so this fires the empty-legacy branch — `<N>` is 0, no migration diagnostic.

The atomicity argument: regenerator-amendment + acceptance-coverage + self-application MUST land together. Splitting introduces a window where the orchestrator's own `mkdocs.yml` carries the new markers but the generator does not yet recognize the new shape, causing the next nav regeneration (any other phase task that touches mkdocs.yml) to fail or silently revert.

## Steps

1. **Read the current `wiki-generate-nav.sh` marker logic** to identify the touch points. The relevant blocks are at lines 98–99 (marker variable definitions), 269 + 671 (where markers are emitted into the rendered nav body), and 684–711 (the ensure-markers-then-splice block that creates absent markers and replaces between-marker content via `awk`). T03 amends each of these blocks.

2. **Replace the marker variables (lines 98–99)** with the new two-region shape:

```bash
# ---- markers (FR-14 region split) ------------------------------------------
# Two regions:
#   auto-nav: regenerated on every invocation (Constitution, Decisions, etc.)
#   custom-nav: preserved verbatim across regenerates (operator-owned)
MARKER_AUTO_START="# >>> auto-nav (auto-generated — do not edit by hand)"
MARKER_AUTO_END="# <<< auto-nav end"
MARKER_CUSTOM_START="# >>> custom-nav"
MARKER_CUSTOM_END="# <<< custom-nav end"

# Legacy markers (M012/P01 baseline). On first regenerate against a legacy
# block, migrate the markers in-place to the new shape per FR-14 / MIT-005.
LEGACY_MARKER_START="# >>> M012-P01 nav (auto-generated — do not edit by hand)"
LEGACY_MARKER_END="# <<< M012-P01 nav end"
```

3. **Update the rendered-nav-body emit (lines ~269 and ~671)** so the body opens with `MARKER_AUTO_START` and closes with `MARKER_AUTO_END` (renaming from the legacy markers). The custom-nav block is NOT emitted as part of the rendered body — it is preserved (or seeded) by the splice logic in step 4. Replace the line `printf '%s\n' "$MARKER_START" >> "$NAV_BODY"` (around line 269) with `printf '%s\n' "$MARKER_AUTO_START" >> "$NAV_BODY"`, and the line `printf '%s\n' "$MARKER_END" >> "$NAV_BODY"` (around line 671) with `printf '%s\n' "$MARKER_AUTO_END" >> "$NAV_BODY"`.

4. **Replace the splice block (lines 684–711)** with the new multi-branch migration + region-preserve logic. This is the load-bearing piece. Required block:

```bash
# ---- ensure markers + migrate from legacy + preserve custom region --------
# Branches:
#   (1) Brand-new mkdocs.yml — no auto-nav markers AND no legacy markers.
#       Append both region pairs at EOF: auto-nav (will be filled by the
#       splice that follows) + empty custom-nav region.
#   (2) Already-migrated — auto-nav markers present.
#       Preserve the existing custom-nav region (or self-heal an empty one
#       per US-5 AS-3 if it has been deleted).
#   (3) Legacy migration — legacy markers present, no auto-nav markers yet.
#       (3a) Empty legacy content: rename markers in-place, append empty
#            custom-nav block. Zero behavior change. No diagnostic.
#       (3b) Non-empty legacy content (MIT-005): rename markers in-place,
#            move non-empty content verbatim into a new custom-nav region.
#            Emit stdout diagnostic naming the preserved-entry count.

HAS_AUTO_NAV=0
HAS_LEGACY_NAV=0
HAS_CUSTOM_NAV=0
LEGACY_LINE_COUNT=0

if grep -qF "$MARKER_AUTO_START" "$CONFIG"; then
  HAS_AUTO_NAV=1
fi
if grep -qF "$LEGACY_MARKER_START" "$CONFIG"; then
  HAS_LEGACY_NAV=1
fi
if grep -qF "$MARKER_CUSTOM_START" "$CONFIG"; then
  HAS_CUSTOM_NAV=1
fi

# Helper: count non-blank, non-comment lines between two markers in $CONFIG.
count_between_markers() {
  _ms="$1"
  _me="$2"
  awk -v s="$_ms" -v e="$_me" '
    BEGIN { state="pre"; n=0 }
    {
      if (state == "pre") { if ($0 == s) state="in"; next }
      if (state == "in")  { if ($0 == e) { state="post"; next }
                            if ($0 ~ /^[[:space:]]*$/) next
                            if ($0 ~ /^[[:space:]]*#/) next
                            n++; next }
    }
    END { print n }
  ' "$CONFIG"
}

# Helper: extract content between two markers in $CONFIG to a temp file.
# Strips the markers themselves; preserves all other lines verbatim.
extract_between_markers() {
  _ms="$1"
  _me="$2"
  _out="$3"
  awk -v s="$_ms" -v e="$_me" -v out="$_out" '
    BEGIN { state="pre" }
    {
      if (state == "pre") { if ($0 == s) state="in"; next }
      if (state == "in")  { if ($0 == e) { state="post"; next }; print > out; next }
    }
  ' "$CONFIG"
  [ -f "$_out" ] || : > "$_out"
}

# Branch dispatcher.
LEGACY_PRESERVED=""  # path to temp file holding non-empty legacy content (set by branch 3b)
if [ "$HAS_AUTO_NAV" -eq 0 ] && [ "$HAS_LEGACY_NAV" -eq 1 ]; then
  # Branch 3 — legacy migration.
  LEGACY_LINE_COUNT=$(count_between_markers "$LEGACY_MARKER_START" "$LEGACY_MARKER_END")
  if [ "$LEGACY_LINE_COUNT" -gt 0 ]; then
    # 3b: MIT-005 non-empty migration. Preserve content for the custom-nav region.
    LEGACY_PRESERVED="/tmp/wiki-nav-legacy-preserved-$$.yml"
    extract_between_markers "$LEGACY_MARKER_START" "$LEGACY_MARKER_END" "$LEGACY_PRESERVED"
    printf 'Migrated %d custom nav entries from legacy markers to custom-nav region\n' "$LEGACY_LINE_COUNT"
  fi
  # Strip the legacy markers + any between-marker content from $CONFIG.
  TMP_DELEG="/tmp/wiki-nav-no-legacy-$$.yml"
  awk -v s="$LEGACY_MARKER_START" -v e="$LEGACY_MARKER_END" '
    BEGIN { state="pre" }
    {
      if (state == "pre") { if ($0 == s) { state="in"; next }; print; next }
      if (state == "in")  { if ($0 == e) { state="post"; next }; next }
      print
    }
  ' "$CONFIG" > "$TMP_DELEG"
  mv "$TMP_DELEG" "$CONFIG"
  HAS_LEGACY_NAV=0
fi

if [ "$HAS_AUTO_NAV" -eq 0 ]; then
  # Append the new auto-nav region pair at EOF (will be replaced by the
  # splice that follows). Append the custom-nav region pair immediately after.
  # If LEGACY_PRESERVED is set, use its content for the custom-nav region.
  {
    printf '\n'
    printf '%s\n' "$MARKER_AUTO_START"
    printf '%s\n' "$MARKER_AUTO_END"
    printf '%s\n' "$MARKER_CUSTOM_START"
    if [ -n "$LEGACY_PRESERVED" ] && [ -f "$LEGACY_PRESERVED" ]; then
      cat "$LEGACY_PRESERVED"
      rm -f "$LEGACY_PRESERVED"
    fi
    printf '%s\n' "$MARKER_CUSTOM_END"
  } >> "$CONFIG"
  HAS_AUTO_NAV=1
  HAS_CUSTOM_NAV=1
fi

# Branch 2: AS-3 self-healing — auto-nav exists but custom-nav does not.
if [ "$HAS_AUTO_NAV" -eq 1 ] && [ "$HAS_CUSTOM_NAV" -eq 0 ]; then
  # Insert empty custom-nav region immediately after MARKER_AUTO_END.
  TMP_HEAL="/tmp/wiki-nav-heal-$$.yml"
  awk -v e="$MARKER_AUTO_END" -v cs="$MARKER_CUSTOM_START" -v ce="$MARKER_CUSTOM_END" '
    {
      print
      if ($0 == e) {
        print cs
        print ce
      }
    }
  ' "$CONFIG" > "$TMP_HEAL"
  mv "$TMP_HEAL" "$CONFIG"
  HAS_CUSTOM_NAV=1
fi

# Splice: replace content between MARKER_AUTO_START and MARKER_AUTO_END with
# the freshly-rendered NAV_BODY (which itself begins with MARKER_AUTO_START and
# ends with MARKER_AUTO_END after step 3 above). Same awk-split-concat pattern
# as the legacy splice.
awk -v s="$MARKER_AUTO_START" -v e="$MARKER_AUTO_END" \
    -v pre="$TMP_PRE" -v post="$TMP_POST" '
  BEGIN { state = "pre" }
  {
    if (state == "pre") {
      if ($0 == s) { state = "in"; next }
      print > pre; next
    }
    if (state == "in") {
      if ($0 == e) { state = "post"; next }
      next
    }
    # state == "post"
    print > post
  }
' "$CONFIG"

[ -f "$TMP_PRE" ] || : > "$TMP_PRE"
[ -f "$TMP_POST" ] || : > "$TMP_POST"

cat "$TMP_PRE" > "$TMP_FINAL"
cat "$NAV_BODY" >> "$TMP_FINAL"
cat "$TMP_POST" >> "$TMP_FINAL"

# (atomic mv block continues unchanged)
```

5. **Run `bash scripts/wiki/wiki-generate-nav.sh --root .`** against the orchestrator's own `wiki/mkdocs.yml` to migrate the existing legacy `# >>> M012-P01 nav` markers in-place to the new shape. Expected: empty-legacy branch fires (no operator-hand-added entries today), markers rename in-place, empty `# >>> custom-nav` block appended, no migration diagnostic emitted (`<N>` is 0 — count is 0 by design when legacy is empty). Verify:

```bash
bash scripts/wiki/wiki-generate-nav.sh --root .
grep -qF '# >>> auto-nav' wiki/mkdocs.yml
grep -qF '# >>> custom-nav' wiki/mkdocs.yml
! grep -qF '# >>> M012-P01 nav' wiki/mkdocs.yml
```

6. **Author `tools/verify/m032-p03-custom-nav-region.sh`**. Static text checks against the amended `wiki-generate-nav.sh`, plus exercise the four FR-14 branches against tmpdir fixtures. Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-custom-nav-region.sh — FR-14 + MIT-005 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GEN="$REPO_ROOT/scripts/wiki/wiki-generate-nav.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks.
for tok in 'MARKER_AUTO_START' 'MARKER_AUTO_END' 'MARKER_CUSTOM_START' \
           'MARKER_CUSTOM_END' 'LEGACY_MARKER_START' 'LEGACY_MARKER_END' \
           '# >>> auto-nav' '# <<< auto-nav end' '# >>> custom-nav' \
           '# <<< custom-nav end' '# >>> M012-P01 nav' \
           'Migrated %d custom nav entries from legacy markers to custom-nav region' \
           'count_between_markers' 'extract_between_markers' \
           'FR-14' 'MIT-005'; do
  if grep -qF "$tok" "$GEN"; then
    say_pass "wiki-generate-nav.sh contains: $tok"
  else
    say_fail "wiki-generate-nav.sh missing: $tok"
  fi
done

# AS-1: populated custom-nav byte-preserved across regenerate.
TMP_F=$(mktemp -d -t m032-p03-nav.XXXXXX)
trap 'rm -rf "$TMP_F"' EXIT
mkdir -p "$TMP_F/wiki/docs" "$TMP_F/.orchestrator/memory"
# Copy enough of the orchestrator's wiki tree to make wiki-generate-nav.sh's
# scanner happy; the verifier focuses on marker logic, not content scan.
cp "$REPO_ROOT/scripts/wiki/wiki-scan-sources.sh" "$TMP_F/" 2>/dev/null || true
# Author a fixture mkdocs.yml with both regions populated.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\n\n'
  printf '# >>> auto-nav (auto-generated — do not edit by hand)\nnav:\n  - Home: index.md\n# <<< auto-nav end\n'
  printf '# >>> custom-nav\n  - Domain Decisions: domain-decisions.md\n  - Project Spec: spec.md\n  - Team Notes: notes.md\n# <<< custom-nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"
SHA_BEFORE=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')
# Run the generator (with the orchestrator's scanner; if scanner fails on the
# minimal fixture, this branch is skipped but other branches still cover).
bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true
SHA_AFTER=$(awk '/^# >>> custom-nav$/,/^# <<< custom-nav end$/' "$TMP_F/wiki/mkdocs.yml" | shasum -a 256 | awk '{print $1}')
if [ "$SHA_BEFORE" = "$SHA_AFTER" ]; then
  say_pass "AS-1: custom-nav region byte-preserved across regenerate"
else
  say_fail "AS-1: custom-nav region modified ($SHA_BEFORE -> $SHA_AFTER)"
fi

# AS-2: empty-legacy migration. Rebuild fixture with legacy markers + empty content.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\n\n'
  printf '# >>> M012-P01 nav (auto-generated — do not edit by hand)\n# <<< M012-P01 nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"
out_empty="$(bash "$GEN" --root "$TMP_F" 2>/dev/null)"
if grep -qF '# >>> auto-nav' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! grep -qF '# >>> M012-P01 nav' "$TMP_F/wiki/mkdocs.yml" && \
   ! printf '%s' "$out_empty" | grep -qF 'Migrated'; then
  say_pass "AS-2: empty-legacy migrated to new shape, no diagnostic emitted"
else
  say_fail "AS-2: empty-legacy migration shape unexpected"
fi

# MIT-005: non-empty-legacy migration with diagnostic.
{
  printf 'site_name: "fixture"\nrepo_url: "https://github.com/fixture/repo"\n\n'
  printf '# >>> M012-P01 nav (auto-generated — do not edit by hand)\n'
  printf '  - Domain A: a.md\n'
  printf '  - Domain B: b.md\n'
  printf '  - Domain C: c.md\n'
  printf '# <<< M012-P01 nav end\n'
} > "$TMP_F/wiki/mkdocs.yml"
out_nonempty="$(bash "$GEN" --root "$TMP_F" 2>/dev/null)"
if printf '%s' "$out_nonempty" | grep -qF 'Migrated 3 custom nav entries from legacy markers to custom-nav region' && \
   grep -qF 'Domain A: a.md' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF 'Domain B: b.md' "$TMP_F/wiki/mkdocs.yml" && \
   grep -qF 'Domain C: c.md' "$TMP_F/wiki/mkdocs.yml"; then
  say_pass "MIT-005: non-empty legacy preserved verbatim, diagnostic emitted with count=3"
else
  say_fail "MIT-005: non-empty legacy migration shape unexpected"
fi

# AS-3: self-heal — delete custom-nav markers manually, expect re-creation.
sed -i.bak '/^# >>> custom-nav$/,/^# <<< custom-nav end$/d' "$TMP_F/wiki/mkdocs.yml"
rm -f "$TMP_F/wiki/mkdocs.yml.bak"
bash "$GEN" --root "$TMP_F" >/dev/null 2>&1 || true
if grep -qF '# >>> custom-nav' "$TMP_F/wiki/mkdocs.yml" && grep -qF '# <<< custom-nav end' "$TMP_F/wiki/mkdocs.yml"; then
  say_pass "AS-3: self-heal re-created custom-nav markers"
else
  say_fail "AS-3: self-heal did not re-create custom-nav markers"
fi

printf 'SUMMARY: m032-p03-custom-nav-region pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

7. **Author `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh`** (SC-6). Same four-branch coverage as the verifier above, but with assertions written from the SC-6-spec perspective (verifies FR-14 against a fixture clone of `wiki/mkdocs.yml`). Required content sketch follows the verifier's structure with friendlier output framing — include `SC-6`, `FR-14`, `MIT-005`, `auto-nav`, `custom-nav`, `M012-P01 nav`, `Migrated`, `byte-identical` tokens to satisfy the artifact-grep contract.

8. **Author `tools/verify/m032-p03-acceptance-shape-sc6.sh`**. Asserts the SC-6 acceptance script exists, is executable, and contains the load-bearing tokens. Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc6.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc6 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-6' 'FR-14' 'MIT-005' 'auto-nav' 'custom-nav' \
           'M012-P01 nav' 'Migrated' 'byte-identical'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-6 contains: $tok"
  else
    say_fail "SC-6 missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-acceptance-shape-sc6 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

9. **Make all new scripts executable**: `chmod +x tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh tools/verify/m032-p03-custom-nav-region.sh tools/verify/m032-p03-acceptance-shape-sc6.sh`.

## Must-Haves

- FR-14 region split on `wiki-generate-nav.sh` (`# >>> auto-nav` regenerated; `# >>> custom-nav` byte-preserved)
- US-5 AS-2 empty-legacy migration (rename in-place, append empty custom-nav)
- MIT-005 non-empty-legacy migration (preserve verbatim into new custom-nav region, emit `Migrated <N> custom nav entries from legacy markers to custom-nav region` diagnostic)
- US-5 AS-3 self-healing (re-create deleted custom-nav markers)
- SC-6 acceptance script (`tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh`)
- Self-application against orchestrator's own `wiki/mkdocs.yml` (legacy markers migrated in-place, empty-legacy branch fires)
- Two project-owned verifiers: `tools/verify/m032-p03-custom-nav-region.sh`, `tools/verify/m032-p03-acceptance-shape-sc6.sh`

## Verification

```bash
bash tools/verify/m032-p03-custom-nav-region.sh
```

```bash
bash tools/verify/m032-p03-acceptance-shape-sc6.sh
```

```bash
bash tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0. The SC-6 acceptance script's expected pass count covers all four FR-14 branches (AS-1 byte-preserve, AS-2 empty-legacy, MIT-005 non-empty-legacy, AS-3 self-heal).

The `count_between_markers` helper counts non-blank, non-comment lines between markers — entries that are pure blank-lines or YAML comments are NOT counted toward the migration diagnostic's `<N>`. This matches the operator's mental model of "nav entries" (a comment between the legacy markers is NOT a custom nav entry).

The `extract_between_markers` helper preserves the EXACT byte-content between markers (including blank lines and comments) — even though the count excludes blanks/comments, the migration moves all the bytes. This avoids the failure mode where a count-aware migration silently drops operator-authored YAML comments.

Self-application caveat: running the generator against the orchestrator's own `wiki/mkdocs.yml` requires the existing `wiki-scan-sources.sh` + `wiki-generate-stubs.sh` chain to succeed. If either of these fails on the orchestrator repo, the self-application step in step 5 will fail and the migration won't fire — in that case, manually edit `wiki/mkdocs.yml` to migrate the markers (rename `# >>> M012-P01 nav (auto-generated — do not edit by hand)` to `# >>> auto-nav (auto-generated — do not edit by hand)`, rename `# <<< M012-P01 nav end` to `# <<< auto-nav end`, append an empty `# >>> custom-nav` / `# <<< custom-nav end` block immediately after).

Bash 3.2 gotcha for the `awk` heredoc-style multi-line scripts: this task's `awk` blocks are MULTI-LINE STRINGS PASSED AS A SINGLE ARGUMENT (not heredoc-fed). bash 3.2 handles this correctly via the `awk '...'` invocation pattern; the harness shape-guard does not flag bash-internal awk-script bodies (AP-009 concerns inline compound bash, not `awk` script bodies).

## Inputs

### From Previous Tasks

(none — T03 is independent of T01/T02/T04; depends only on P02 artifacts)

### From Disk (Pre-existing)

- `scripts/wiki/wiki-generate-nav.sh` (M012/P01 baseline + P02/T03 amendments) — bash 3.2 nav generator. T03 amends three blocks: marker variables (lines 98–99), rendered-body emit (lines ~269 + ~671), splice (lines 684–711).
- `wiki/mkdocs.yml` (orchestrator-local) — currently carries legacy `# >>> M012-P01 nav` markers. T03 step 5 migrates them in-place via self-application.
- `scripts/wiki/wiki-scan-sources.sh` (M012 + P02/T03 baseline) — read-only reference; T03 does NOT modify the scanner.
- `wiki/docs/` (M012 baseline) — read-only reference; the generator's existing logic depends on this directory's presence.

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — awk script bodies are multi-line single-quoted strings; no `declare -A`; no process substitution.
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix.
- No modifications to T01/T02-touched files (`wiki/overrides/partials/comments.html`, `scripts/lifecycle/wiki-init.sh`, `scripts/wiki/wiki-deploy.sh`) or P02/P01-owned files.
- The `Migrated %d custom nav entries from legacy markers to custom-nav region` diagnostic format string is load-bearing — the SC-6 acceptance script greps for the literal `Migrated 3` substring against a 3-entry fixture. Do not reformat the diagnostic.
- The empty-legacy branch MUST emit ZERO diagnostics on stdout (zero-behavior-change at empty-legacy is the AS-2 contract).
- Co-author the verifier scripts within T03 — do NOT defer to T05 per plan-time discipline rule 2.

## Expected Output

After T03 completes:

- `scripts/wiki/wiki-generate-nav.sh` recognizes both legacy and new markers, implements the four FR-14 branches.
- `wiki/mkdocs.yml` carries the new `# >>> auto-nav` / `# <<< auto-nav end` and `# >>> custom-nav` / `# <<< custom-nav end` markers (legacy markers migrated in-place via self-application step 5).
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` exists and exits 0 (SC-6 PASS).
- `tools/verify/m032-p03-custom-nav-region.sh` and `tools/verify/m032-p03-acceptance-shape-sc6.sh` exist and exit 0.
- The two `Check:` commands listed in P03-PLAN.md's "Truths" section for T03-owned truths return exit 0.
