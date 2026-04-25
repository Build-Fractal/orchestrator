---
schema_version: "1.0"
task: "T05"
phase: "P03"
milestone: "M026"
name: "Phase verification suite + Recent Changes dual-write (CON-6, OQ-10)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 has shipped: `scripts/verify/m026-p03-edition-required-diagnostic.sh` exists and exits 0.
- T02 has shipped: `scripts/verify/m026-p03-doc-surface-coverage.sh` exists and exits 0.
- T03 has shipped: `scripts/verify/m026-p03-mem-graduation.sh` exists and exits 0.
- T04 has shipped: `scripts/verify/m026-p03-decision-row.sh` exists and exits 0.
- Existing M011/P07 cross-milestone invariant gates (DC-2): `scripts/verify/m011-p07-conversus-adapter-shape.sh`, `scripts/verify/m011-p07-gate-pass-block.sh`, `scripts/verify/m011-p07-bash32-compat.sh`.
- `scripts/util/dual-write-runtime-md.sh` exists with `--append-entry` mode (M026 batch 3 fix `fd2cf64`).
- CLAUDE.md and AGENTS.md both have an existing `# >>> orchestrator:recent-changes >>>` ... `# <<< orchestrator:recent-changes <<<` region with the M026/P02 entry as the current first line.

## Description

Two artifacts:

1. **Phase verification suite** `scripts/verify/m026-p03-phase-suite.sh` — chains all four P03 task verifiers + the three M011/P07 cross-milestone invariant gates and emits a single `SUMMARY: m026-p03-phase-suite.sh pass=N fail=M` trailer. Mirror the P02 suite shape (`scripts/verify/m026-p02-phase-suite.sh`).

2. **Recent Changes dual-write** to CLAUDE.md + AGENTS.md via `scripts/util/dual-write-runtime-md.sh --append-entry`. The `--append-entry` mode is reverse-chronological prepend (M026 batch 3 fix `fd2cf64`): the new entry becomes the new first line of the marker region, preserving every existing line below. This is the critical OQ-10 dual-write parity invariant — both files MUST receive the same entry, in the same place, atomically.

T05 also creates the verifier `scripts/verify/m026-p03-recent-changes.sh` which asserts the dual-write landed correctly.

## Steps

1. **Read the existing P02 phase suite for shape**:

   ```sh
   cat scripts/verify/m026-p02-phase-suite.sh
   ```

   Note: IFS-newline GATES list, single-script-file gate invocation pattern, `SUMMARY: pass=N fail=M` trailer, exit 0 if `fail=0` else exit 1.

2. **Create `scripts/verify/m026-p03-phase-suite.sh`** mirroring the P02 suite shape (single-script-file, AD-19, Bash 3.2):

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-phase-suite.sh
   # M026/P03 phase verification suite — chains all P03 verifiers + M011/P07
   # cross-milestone invariant gates per DC-2.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"

   pass=0; fail=0
   IFS='
   '
   GATES="scripts/verify/m026-p03-edition-required-diagnostic.sh
   scripts/verify/m026-p03-doc-surface-coverage.sh
   scripts/verify/m026-p03-mem-graduation.sh
   scripts/verify/m026-p03-decision-row.sh
   scripts/verify/m026-p03-recent-changes.sh
   scripts/verify/m011-p07-conversus-adapter-shape.sh
   scripts/verify/m011-p07-gate-pass-block.sh
   scripts/verify/m011-p07-bash32-compat.sh"

   for gate in $GATES; do
     if [ ! -f "$gate" ]; then
       echo "FAIL: missing gate script: $gate"
       fail=$((fail+1))
       continue
     fi
     if bash "$gate" >/dev/null 2>&1; then
       pass=$((pass+1))
       echo "PASS: $(basename "$gate")"
     else
       fail=$((fail+1))
       echo "FAIL: $(basename "$gate")"
     fi
   done

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Notes:
   - GATES list uses literal newline IFS (no arrays — Bash 3.2 portable).
   - Each gate runs as a single `bash <script>` invocation.
   - Output discipline: PASS/FAIL line per gate + SUMMARY trailer + exit code.
   - Note that `m026-p03-recent-changes.sh` is included even though T05 creates it — the phase suite runs at phase-close after T05's dual-write has happened, so by then the verifier exists and the dual-write has landed.

3. **Author the Recent Changes entry text**. Single line, ≤200 chars, follows the existing region's reverse-chronological convention. Suggested text:

   ```
   - M026/P03: conversus-OSS migration close — preset edition_required:paid refusal on OSS, six-surface doc updates, knowledge graduation (MEM029 pattern + MEM030 convention), DECISIONS D022, CHANGELOG entry. Closes M026.
   ```

4. **Invoke the dual-write helper** with `--append-entry`:

   ```sh
   bash scripts/util/dual-write-runtime-md.sh \
     --marker recent-changes \
     --append-entry "- M026/P03: conversus-OSS migration close — preset edition_required:paid refusal on OSS, six-surface doc updates, knowledge graduation (MEM029 pattern + MEM030 convention), DECISIONS D022, CHANGELOG entry. Closes M026." \
     --file CLAUDE.md \
     --file AGENTS.md
   ```

   `--append-entry` mode prepends the entry as the new first line of the region body and preserves every existing line below it (reverse-chronological). No need to reconstruct the rest of the block.

   Confirm with:

   ```sh
   sed -n '/# >>> orchestrator:recent-changes >>>/,/# <<< orchestrator:recent-changes <<</p' CLAUDE.md | head -10
   sed -n '/# >>> orchestrator:recent-changes >>>/,/# <<< orchestrator:recent-changes <<</p' AGENTS.md | head -10
   ```

   Both should show the new M026/P03 line as the first body line, with the M026/P02 line immediately below it.

5. **Create `scripts/verify/m026-p03-recent-changes.sh`** (single-script-file, AD-19, Bash 3.2):

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-recent-changes.sh
   # Verifies M026/P03/T05: Recent Changes dual-written to CLAUDE.md + AGENTS.md
   # with the M026/P03 entry present and the M026/P02 entry preserved (OQ-10 parity).
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   for f in CLAUDE.md AGENTS.md; do
     full="${REPO_ROOT}/${f}"
     if [ ! -f "$full" ]; then _fail "${f}: missing"; continue; fi
     if grep -qE 'M026/P03.*conversus-OSS migration close' "$full"; then _pass "${f}: contains M026/P03 entry"; else _fail "${f}: missing M026/P03 entry"; fi
     if grep -qE 'M026/P02' "$full"; then _pass "${f}: M026/P02 entry preserved"; else _fail "${f}: M026/P02 entry was lost (overwrite regression)"; fi
     if grep -q '^# >>> orchestrator:recent-changes >>>' "$full"; then _pass "${f}: marker region intact"; else _fail "${f}: missing marker region"; fi
   done

   # Order check: M026/P03 must appear BEFORE M026/P02 in CLAUDE.md (reverse-chronological).
   ord_p03=$(grep -nE 'M026/P03.*conversus-OSS migration close' "${REPO_ROOT}/CLAUDE.md" | head -1 | awk -F: '{print $1}')
   ord_p02=$(grep -nE 'M026/P02:' "${REPO_ROOT}/CLAUDE.md" | head -1 | awk -F: '{print $1}')
   if [ -n "$ord_p03" ] && [ -n "$ord_p02" ] && [ "$ord_p03" -lt "$ord_p02" ]; then
     _pass "CLAUDE.md: M026/P03 precedes M026/P02 (reverse-chronological)"
   else
     _fail "CLAUDE.md: M026/P03 does not precede M026/P02 (p03=${ord_p03}, p02=${ord_p02})"
   fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

6. **Run the recent-changes verifier in isolation first** to confirm the dual-write landed correctly:

   ```sh
   bash scripts/verify/m026-p03-recent-changes.sh
   ```

   Expected: `SUMMARY: ... pass=7 fail=0` (3 checks per file × 2 files + 1 ordering check).

7. **Run the full phase suite**:

   ```sh
   bash scripts/verify/m026-p03-phase-suite.sh
   ```

   Expected:

   ```
   PASS: m026-p03-edition-required-diagnostic.sh
   PASS: m026-p03-doc-surface-coverage.sh
   PASS: m026-p03-mem-graduation.sh
   PASS: m026-p03-decision-row.sh
   PASS: m026-p03-recent-changes.sh
   PASS: m011-p07-conversus-adapter-shape.sh
   PASS: m011-p07-gate-pass-block.sh
   PASS: m011-p07-bash32-compat.sh
   ----
   SUMMARY: m026-p03-phase-suite.sh pass=8 fail=0
   ```

## Must-Haves

Addresses phase must-haves:
- "Truth: CLAUDE.md and AGENTS.md recent-changes regions both contain a fresh M026/P03 entry, M026/P02 entry preserved (OQ-10 parity)"
- "Truth: Phase verification suite chains every P03 verifier with M011/P07 invariant gates and emits SUMMARY: m026-p03-phase-suite.sh pass=N fail=0"
- Artifacts: `scripts/verify/m026-p03-phase-suite.sh`, `scripts/verify/m026-p03-recent-changes.sh`, CLAUDE.md and AGENTS.md (modified — RC region only)

## Verification

```
bash scripts/verify/m026-p03-recent-changes.sh
bash scripts/verify/m026-p03-phase-suite.sh
```

Both must exit 0 with `SUMMARY: ... pass=N fail=0` trailers.

## Inputs

### From Previous Tasks

- T01 verifier: `scripts/verify/m026-p03-edition-required-diagnostic.sh`
- T02 verifier: `scripts/verify/m026-p03-doc-surface-coverage.sh`
- T03 verifier: `scripts/verify/m026-p03-mem-graduation.sh`
- T04 verifier: `scripts/verify/m026-p03-decision-row.sh`

The suite invokes each verifier as a single `bash <path>` call and aggregates the pass/fail count. T05 does NOT modify any of the upstream verifiers.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — append-entry mode shipped in commit `fd2cf64` (M026 batch 3 fix).
- `scripts/verify/m011-p07-{conversus-adapter-shape,gate-pass-block,bash32-compat}.sh` — invariant gates, used as regression guards.
- `scripts/verify/m026-p02-phase-suite.sh` — shape exemplar for the P03 suite.

## Constraints

- **CON-6** (dual-write): both CLAUDE.md and AGENTS.md MUST receive the same entry. The verifier asserts this with parallel checks per file. If `dual_write_agents: false` is set in `.orchestrator/config.yml`, the helper skips AGENTS.md with a `SKIPPED:` line on stderr — current config has it true, so both files receive the entry.
- **OQ-10** (dual-write parity): the entry text is identical in both files; the marker region is preserved.
- **AD-19** (single-script-file Check shape): both verifiers and the phase suite use no compound bash.
- **Append-entry mode (not --content)**: `--append-entry` prepends to the existing region body, preserving the M026/P02 line below the new M026/P03 line. Using `--content` would require reconstructing the whole region — not used here.
- **Bash 3.2 compatibility**: GATES list uses IFS=newline + `for` over a string, not arrays. Compatible with the P02 suite shape.

## Expected Output

- `scripts/verify/m026-p03-phase-suite.sh` — created (~50-70 lines).
- `scripts/verify/m026-p03-recent-changes.sh` — created (~50-65 lines).
- CLAUDE.md and AGENTS.md — modified: one new line prepended to the recent-changes marker region in each file.
- `bash scripts/verify/m026-p03-recent-changes.sh` exits 0 with `SUMMARY: ... pass=7 fail=0`.
- `bash scripts/verify/m026-p03-phase-suite.sh` exits 0 with `SUMMARY: ... pass=8 fail=0`.
