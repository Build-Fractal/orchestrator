---
schema_version: "1.0"
task: "T02"
phase: "P03"
milestone: "M026"
name: "Six doc-surface in-place rewrites — resolver order + escape-hatch shape (FR-12)"
depends_on: []
---

## Prerequisites

- Six doc surfaces exist on disk and contain `conversus`-related prose:
  - `commands/conversus-gate.md`
  - `commands/ingest.md`
  - `commands/specify.md`
  - `docs/ingesting-arbitrary-specs.md`
  - `references/github-integration.md`
  - `references/spec-management.md`
- Spec 027 §FR-12 specifies the contract: docs grep-match `conversus-oss` and `CONVERSUS_EDITION`, and the M011-era four-step resolver-order block at `commands/conversus-gate.md:24-28` is rewritten to the new edition-aware shape (per Addendum §D, single-venv reality: edition detection via `CONVERSUS_EDITION=oss|paid` env var primary, `python -m pip show conversus` metadata-probe fallback; `CONVERSUS_HOME` remains absolute override).
- AD-7 mandates **revise-in-place** posture — no append-at-end blocks.
- `references/architecture.md` already has the durable Conversus Operator Notes section (FR-14, shipped in P01) — out of scope for T02.

## Description

Update each of the six doc surfaces in place so:

1. The new resolver order (with OSS as user-local default and paid as escape hatch) is reflected wherever the doc currently describes the resolver.
2. Both `conversus-oss` and `CONVERSUS_EDITION` are grep-matchable in every surface (FR-12 mechanical contract).
3. The M011-era four-step resolver order in `commands/conversus-gate.md:24-28` is fully rewritten to the new edition-aware shape (six steps reflecting the P02 resolver: STUB → PATH → CONVERSUS_HOME → CONVERSUS_EDITION → user-local OSS → user-local paid; metadata-probe fallback noted).
4. The same four-step block in `docs/ingesting-arbitrary-specs.md:178-186` is also rewritten.
5. `commands/ingest.md`, `commands/specify.md`, `references/github-integration.md`, `references/spec-management.md` get a shorter mention (one paragraph each) explaining that the adapter resolves OSS by default and the operator can flip to paid via `CONVERSUS_EDITION=paid`. Reading paths chosen by where each doc already mentions the adapter.

T02 also creates the verifier `scripts/verify/m026-p03-doc-surface-coverage.sh` which mechanically asserts the FR-12 grep contract on all six surfaces.

## Steps

1. **Read each of the six doc surfaces** to understand the current shape and best insertion/rewrite points. The user has already done preliminary grep — see the line-numbered hits in the P03 plan-phase summary. Key insertion targets confirmed:
   - `commands/conversus-gate.md` lines 24-28: rewrite the four-step resolver block.
   - `docs/ingesting-arbitrary-specs.md` lines 178-186: rewrite the analogous four-step resolver block.
   - `commands/ingest.md`: add a short paragraph in the section that already references `conversus.sh check` (around line 124, the "Conversus binary missing (graceful degradation)" block) describing edition resolution.
   - `commands/specify.md`: add a short note in the "Gate adapter pre-flight (per D019)" block around line 125 noting `CONVERSUS_EDITION` as a related env var.
   - `references/github-integration.md`: add a short paragraph in the "Conversus Pre-Merge Gate" section around line 321 noting the OSS default + escape hatch.
   - `references/spec-management.md`: add a short note in the section that already references `conversus.sh` (around line 146 "[M014](../../../../milestones/M014/index.md) ships preset + prompts only") explaining the edition resolution.

2. **Rewrite `commands/conversus-gate.md` lines 24-28** from the [M011](../../../../milestones/M011/index.md) four-step:

   ```
   1. `CONVERSUS_STUB=1` — stub mode (test-only, uses canned fixtures).
   2. `command -v conversus` — PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit env var.
   4. `$HOME/Sites/conversus/bin/conversus` — user-local convention.
   ```

   to the M026/P03 six-step:

   ```
   1. `CONVERSUS_STUB=1` — stub mode (test-only, uses canned fixtures).
   2. `command -v conversus` — PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit absolute override.
   4. `$HOME/Sites/conversus-oss/bin/conversus` — user-local OSS default (M026/P02).
   5. `$HOME/Sites/conversus/bin/conversus` — user-local paid escape hatch.
   ```

   Add a follow-on paragraph (one-liner) describing edition resolution:

   ```
   Edition is reported on `check` stdout as `edition=<oss|paid|unknown>`. Operator declares the edition via `CONVERSUS_EDITION=oss|paid` (primary); fallback is `python -m pip show conversus` metadata probe against the resolved venv's `Home-page:` line. Stub mode is edition-agnostic (`edition=unknown reason=stub`). See `references/architecture.md` "Conversus Adapter — Operator Notes" for the operator runbook.
   ```

   Per FR-10/FR-11 also add a short paragraph (after the resolver section, before the "Subcommands" reference if present) describing the paid-only-preset refusal:

   ```
   **Paid-only-preset refusal (M026/P03)**: a preset whose YAML frontmatter declares `edition_required: paid` invoked on an OSS-resolved binary will be refused before any `conversus run` invocation. The diagnostic on stderr names the preset, the edition requirement, and `CONVERSUS_EDITION=paid` as the escape. Presets without `edition_required:` behave identically to today.
   ```

3. **Rewrite `docs/ingesting-arbitrary-specs.md` lines 178-186** analogously:

   Replace:

   ```
   Resolver order for the conversus binary:

   1. `CONVERSUS_STUB=1` — stub mode (testing).
   2. `command -v conversus` — on PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit env var.
   4. `$HOME/Sites/conversus/bin/conversus` — user-local convention.

   To install conversus locally, clone the repo to `~/Sites/conversus` (or any
   location pointed at by `CONVERSUS_HOME`). See the conversus project for its
   ```

   With:

   ```
   Resolver order for the conversus binary (M026/P02):

   1. `CONVERSUS_STUB=1` — stub mode (testing).
   2. `command -v conversus` — on PATH.
   3. `$CONVERSUS_HOME/bin/conversus` — explicit absolute override.
   4. `$HOME/Sites/conversus-oss/bin/conversus` — user-local OSS default.
   5. `$HOME/Sites/conversus/bin/conversus` — user-local paid escape hatch.

   Edition (`oss|paid|unknown`) is reported on `check` stdout. Operator declares the edition via `CONVERSUS_EDITION=oss|paid`; fallback is a `pip show conversus` metadata probe.

   To install the OSS conversus locally, clone the OSS repo to `~/Sites/conversus-oss`. To install the paid build, clone to `~/Sites/conversus` (or any location pointed at by `CONVERSUS_HOME`). See the conversus project for its
   ```

4. **Add a short paragraph to `commands/ingest.md`** in the "Conversus binary missing (graceful degradation)" block (around line 124). Insert as a new bullet immediately after the existing "Conversus binary missing" bullet:

   ```
   - **Edition resolution (M026)**: the adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default. Operators who need the paid build for a specific invocation set `CONVERSUS_EDITION=paid` in the environment; `CONVERSUS_HOME` remains the absolute override. Edition is reported on `check` stdout as `edition=<oss|paid|unknown>` and surfaces in every `conversus_gate_invocation` JSONL record. See `commands/conversus-gate.md` for the full resolver order.
   ```

5. **Add a short note to `commands/specify.md`** at the end of the "Gate adapter pre-flight (per D019)" block around line 125. Append after the existing TODO-pre-flight prose:

   ```
   The adapter resolves to the OSS conversus build by default (M026); set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. See `commands/conversus-gate.md` for the full resolver and edition-aware diagnostics.
   ```

6. **Add a short paragraph to `references/github-integration.md`** in the "Conversus Pre-Merge Gate" section. Insert as a new bullet at the end of the bullets that begin with "**Strict mode**" / "**30-second timeout**" / etc. (around line 329):

   ```
   - **Edition resolution** — the adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default; operators set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. The resolved edition is reported on every `conversus_gate_invocation` JSONL record. See `commands/conversus-gate.md` for the full resolver order.
   ```

7. **Add a short note to `references/spec-management.md`** at the end of the "M014 ships preset + prompts only" paragraph around line 146:

   ```
   The adapter resolves to the OSS conversus build by default (M026/P02); operators set `CONVERSUS_EDITION=paid` to flip. Edition is reported on the `conversus_gate_invocation` JSONL record emitted per gate run.
   ```

8. **Create `scripts/verify/m026-p03-doc-surface-coverage.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). The verifier must:

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-doc-surface-coverage.sh
   # Verifies M026/P03/T02: six doc surfaces grep-match conversus-oss + CONVERSUS_EDITION (FR-12).
   # Verifies the M011-era four-step resolver block in commands/conversus-gate.md is rewritten.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   SURFACES="commands/conversus-gate.md commands/ingest.md commands/specify.md docs/ingesting-arbitrary-specs.md references/github-integration.md references/spec-management.md"

   for surface in $SURFACES; do
     full="${REPO_ROOT}/${surface}"
     if [ ! -f "$full" ]; then _fail "${surface}: file missing"; continue; fi
     if grep -q 'conversus-oss' "$full"; then _pass "${surface}: contains 'conversus-oss'"; else _fail "${surface}: missing 'conversus-oss'"; fi
     if grep -q 'CONVERSUS_EDITION' "$full"; then _pass "${surface}: contains 'CONVERSUS_EDITION'"; else _fail "${surface}: missing 'CONVERSUS_EDITION'"; fi
   done

   # The M011-era 4-step resolver block in commands/conversus-gate.md ended at "user-local convention".
   # Confirm the rewrite by asserting the new "user-local OSS default" or "user-local paid escape hatch"
   # phrasing is present.
   gate_doc="${REPO_ROOT}/commands/conversus-gate.md"
   if grep -qE 'user-local OSS default|user-local paid escape hatch' "$gate_doc"; then
     _pass "commands/conversus-gate.md: M011-era resolver block rewritten"
   else
     _fail "commands/conversus-gate.md: original 'user-local convention' resolver block not rewritten"
   fi

   # Same check for docs/ingesting-arbitrary-specs.md.
   ingest_doc="${REPO_ROOT}/docs/ingesting-arbitrary-specs.md"
   if grep -qE 'user-local OSS default|user-local paid escape hatch' "$ingest_doc"; then
     _pass "docs/ingesting-arbitrary-specs.md: resolver block rewritten"
   else
     _fail "docs/ingesting-arbitrary-specs.md: resolver block not rewritten"
   fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

9. **Run the verifier** to confirm green:

   ```sh
   bash scripts/verify/m026-p03-doc-surface-coverage.sh
   ```

   Expected:

   ```
   ----
   SUMMARY: m026-p03-doc-surface-coverage.sh pass=14 fail=0
   PASS: m026-p03-doc-surface-coverage.sh
   ```

   (12 grep checks + 2 rewrite-shape checks = 14 PASS lines.)

## Must-Haves

Addresses phase must-haves:
- "Truth: all six FR-12 doc surfaces grep-match conversus-oss + CONVERSUS_EDITION; the M011-era four-step resolver block in commands/conversus-gate.md is rewritten"
- Artifacts: `scripts/verify/m026-p03-doc-surface-coverage.sh`, six modified docs

## Verification

```
bash scripts/verify/m026-p03-doc-surface-coverage.sh
```

Must exit 0 with a `PASS:` final line.

## Inputs

### From Previous Tasks

None — T02 is independent within P03.

### From Disk (Pre-existing)

The six FR-12 doc surfaces. AD-7 mandates revise-in-place — do NOT append a wholesale block at end of file; integrate edits into the prose at the reading paths each doc already uses.

## Constraints

- **AD-7** (revise-in-place): edits land inline at the relevant reading paths, not as appended blocks.
- **CON-1** (no caller code change): no scripts modified beyond verifier creation.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that would trigger the harness heuristic.
- **Idempotent**: re-running the verifier after a no-op `touch` of any surface still passes (greps are idempotent).
- **Bash 3.2 compatible**: verifier uses `for` over a space-separated string, not `mapfile` or arrays-with-IFS.

## Expected Output

- Six doc files modified in-place (line-count deltas: ~5-15 lines each).
- `scripts/verify/m026-p03-doc-surface-coverage.sh` — created (~50-70 lines).
- `bash scripts/verify/m026-p03-doc-surface-coverage.sh` exits 0, prints `SUMMARY: ... pass=14 fail=0` and `PASS:` final line.
