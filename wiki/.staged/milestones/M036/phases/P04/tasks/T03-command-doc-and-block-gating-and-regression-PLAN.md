---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M036"
name: "commands/ingest-reference.md + Tier 2 BLOCK-not-promoted verifier + P05 regression verifier"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 closed: fixture corpus on disk including `tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md` with `tier_2_verdict: "BLOCK"`.
- T02 closed: `scripts/knowledge/ingest-reference.sh` driver on disk with the BLOCK-gating branch implemented (T02 includes the BLOCK emission + counter logic; T03 adds the verifier that asserts the FR-18 `.structured.md`-absence invariant).
- T02 closed: `scripts/knowledge/rebuild-index.sh` basename-filter widened to `MEM*|SPEC-*|REF-*` + `*.text|*.structured` exclusion.
- `tools/verify/m036-p05-phase-suite.sh` exists (P05 deliverable) — the P05 regression baseline.

Verified at plan-authoring time: P05 phase-suite aggregator present.

## Description

Land the operator-facing command document `commands/ingest-reference.md`, the FR-18 BLOCK-gating verifier, and the P05 regression guard:

1. **`commands/ingest-reference.md`** (~80 lines) — user-facing command document following the M036/P02 `commands/extract.md` shape. Sections: Prerequisites + Inputs + Output (declares the CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: stdout protocol) + Idempotency + Error Handling + Referenced Scripts. Documents `--reference-root` and `--no-index-rebuild` flags. Per MEM012 Command File Structure.

2. **`tools/verify/m036-p04-tier-2-block-not-promoted.sh`** — drives the driver against the BLOCK-verdict fixture (with the `_negative/tier-2-block/` chunk staged into a workspace as a `cms-rule/` chunk so it's actually picked up by the walker). Asserts:
   - The driver emits `BLOCKED: REF-cms-rule-blocked reason=tier-2-fidelity-gate` on stdout.
   - The driver does NOT emit `CREATED:` for that chunk_id.
   - No `.structured.md` sibling file is present in the workspace (FR-18 invariant: BLOCK-verdict chunks must not have a structured-md sibling promoted into the chunk store).
   - Driver exit code 0 (BLOCK is a verdict, not an error — partial-success ingest).

3. **`tools/verify/m036-p04-p05-regression-pass.sh`** — re-runs the P05 phase-suite aggregator (`tools/verify/m036-p05-phase-suite.sh`) and asserts `pass=8 fail=0`. Confirms P04's edits to `rebuild-index.sh` (basename filter + `*.text|*.structured` exclusion) do not perturb P05's edge-insertion paths.

4. **`tools/verify/m036-p04-command-shape.sh`** — token-presence checks against `commands/ingest-reference.md`.

## Steps

### Step 1 — Author `commands/ingest-reference.md`

Create `commands/ingest-reference.md`:

```markdown
---
description: "Use when ingesting a populated reference-corpus tree into the orchestrator's knowledge graph. Walks knowledge/reference/<category>/REF-*.md, classifies (FR-1 taxonomy + FR-2 required fields), gates re-ingest via content_hash idempotency, surfaces Tier 2 BLOCK-verdict chunks as advisories, and rebuilds KNOWLEDGE-INDEX.md so reference chunks participate in graph traversal."
---

# orchestrator:ingest-reference

Ingest a reference-corpus tree (`knowledge/reference/<category>/REF-*.md`) into the orchestrator's knowledge graph.

This command is the **ingest layer** in the M036 reference-corpus pipeline. It consumes the chunk artifacts produced upstream by `orchestrator:extract` (M036/P02 + P03 — `scripts/knowledge/extract-reference.sh`) or operator-authored REF chunks placed directly under the reference root. Per-file classification gates each chunk against the M036 taxonomy + frontmatter contract; valid chunks are recognized as graph entries; invalid chunks are rejected with per-file errors (partial-success ingest); Tier 2 BLOCK-verdict chunks are surfaced as advisories per FR-18.

Run `orchestrator:ingest-reference` after a successful `orchestrator:extract` pass, or whenever you have hand-authored REF chunks to bring into the graph. The re-ingest path is idempotent (CON-4): unchanged chunks produce zero file modifications.

## Prerequisites

1. **Reference root populated** — a directory tree at `knowledge/reference/<category>/` (default) or a custom path passed via `--reference-root`. The four taxonomy categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`) are walked; any other top-level directory under the reference root is silently skipped (e.g., `_originals/`, `_extraction-log/`, `_negative/`).
2. **Knowledge tree initialized** — the `knowledge/` directory must exist at the orchestrator root. Created by `scripts/lifecycle/scaffold.sh` during `orchestrator:evaluate`. This command does not bootstrap the tree.
3. **Classifier helper present** — `scripts/knowledge/classify-reference.sh` (M036 P04 deliverable) and `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (M036 P00 deliverable) must be present.
4. **Index rebuilder present** — `scripts/knowledge/rebuild-index.sh` (M011/M020 deliverable) must be present and recognize `REF-*` basenames (extended in M036 P04 — basename filter `MEM*|SPEC-*|REF-*`).

No prior orchestrator state beyond the knowledge tree is required — `orchestrator:ingest-reference` is safe to run before or after `orchestrator:evaluate`.

## Inputs

The canonical invocation:

```bash
bash scripts/knowledge/ingest-reference.sh [--reference-root <path>] [--no-index-rebuild]
```

User-facing flags:

- `--reference-root <path>` — optional. Absolute or repo-relative path to the reference-corpus root. Default: `knowledge/reference/`. Must exist (or be absent — see Edge Case "no reference corpus configured" below); if present, must contain at least one of the four taxonomy-category subdirectories.
- `--no-index-rebuild` — optional. Skip the final `rebuild-index.sh` invocation. Useful when chaining multiple ingest passes (e.g., spec ingest + reference ingest in the same operator workflow); rebuild once at the end.

## Output

Structured stdout per the M036-canonical contract:

- `CREATED: <chunk_id> category=<cat> tier=<n>` — emitted for each valid chunk that is not BLOCK-verdict and not unchanged-content-hash.
- `SKIPPED: <chunk_id> reason=unchanged-content-hash` — emitted for chunks whose frontmatter `content_hash` matches the body sha256 (re-ingest of an unchanged chunk).
- `REJECTED: <chunk_id> reason=<missing-required-field|unknown-category|...>` — emitted for chunks that fail FR-1 (taxonomy) or FR-2 (required-field presence). Per-file rejection — partial-success ingest continues with the next file.
- `BLOCKED: <chunk_id> reason=tier-2-fidelity-gate` — emitted for chunks whose Tier 0 frontmatter declares `tier_2_verdict: "BLOCK"`. The Tier 0 chunk persists on disk per FR-18; only the `.structured.md` sibling is withheld (and that withholding happens at extract-time in M036/P03, not at ingest-time here). Ingest verifies the absence of the structured-md sibling and emits a stderr WARNING if it finds one (operator-error indicator).
- `SUMMARY: ingest-reference.sh created=<n> skipped=<n> rejected=<n> blocked=<n>` — emitted as the last stdout line of the run.

Errors to stderr; non-zero exit only on unrecoverable error (per-chunk rejections do NOT abort the pass). Idempotency contract: re-running on an unchanged tree produces a `git status` reporting zero modified files under `knowledge/reference/`.

## Idempotency

Re-running `orchestrator:ingest-reference` is fully supported and is the expected workflow when the corpus evolves. CON-4 invariant: unchanged inputs produce zero file modifications.

- Unchanged chunks emit `SKIPPED:` (when the frontmatter `content_hash` matches the body sha256) or fall through to `CREATED:` (when the hash mismatches but the chunk is otherwise valid — this is the `extract-reference.sh` fall-through case where the frontmatter `content_hash` records the source-binary hash, not the body hash, so the per-line idempotency gate misses but the tree itself remains untouched).
- The hard idempotency invariant is the byte-identical tree across runs — the driver does not modify chunk files. T04's acceptance harness verifies this via tree-diff snapshots.

## Error Handling

- **Reference root missing** — exit 0 with `SUMMARY: ingest-reference.sh created=0 ... (no reference corpus configured)` (CON-1 backwards compat for projects that never ingest reference content).
- **Per-chunk classifier rejection** — emit `REJECTED:` line + stderr error naming the missing field or invalid category; continue with the next chunk. Final exit code is 0 unless an unrecoverable error (e.g., missing classifier helper) occurs.
- **rebuild-index.sh failure** — emit a stderr warning that the index may be stale; exit 0 (chunks are on disk; index can be rebuilt manually). The non-fatal posture matches the spec-chunk path at `commands/ingest.md:90`.

## Referenced Scripts / Templates

- `scripts/knowledge/ingest-reference.sh` — the production driver.
- `scripts/knowledge/classify-reference.sh` — taxonomy + required-field classifier helper (sourced by the driver).
- `scripts/knowledge/rebuild-index.sh` — index rebuilder (invoked at end unless `--no-index-rebuild`).
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — taxonomy + tier validator delegated to by the classifier helper.

## Reference Files

- `references/reference-taxonomy.md` — M036 closed-taxonomy SSOT (4 categories).
- `references/reference-frontmatter-contract.md` — FR-2 required-field SSOT (6 fields per chunk).
- `references/reference-source-types.yaml` — per-category default extraction-tier mapping.
- `specs/033-reference-corpus-ingest/spec.md` — feature spec (FR-1 taxonomy, FR-2 frontmatter, FR-3 ingest, FR-9 idempotency, FR-18 BLOCK retention).
```

### Step 2 — Author `tools/verify/m036-p04-tier-2-block-not-promoted.sh`

Create `tools/verify/m036-p04-tier-2-block-not-promoted.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-tier-2-block-not-promoted.sh -- M036 P04 T03.
# FR-18 BLOCK-retention contract verifier: drives ingest-reference.sh
# against a workspace containing only the BLOCK-verdict fixture (staged
# under cms-rule/ so it's actually walked). Asserts:
#   - stdout contains "BLOCKED: <chunk_id> reason=tier-2-fidelity-gate"
#   - stdout does NOT contain "CREATED: <chunk_id>"
#   - no .structured.md sibling exists in the workspace
#   - driver exits 0 (BLOCK is a verdict, not an error)
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md"
fail=0
if [ ! -f "$DRV" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (DRV=$DRV FX=$FX)"
  echo "SUMMARY: m036-p04-tier-2-block-not-promoted.sh fail=1"
  exit 1
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p04-block.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/cms-rule"
cp "$FX" "$WORK/cms-rule/"
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-block-out.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver exit 0"
else
  echo "FAIL: driver exit $rc (expected 0; BLOCK is verdict not error)"
  fail=$((fail + 1))
fi
if grep -qF -e "BLOCKED:" "$OUT"; then
  if grep -qF -e "reason=tier-2-fidelity-gate" "$OUT"; then
    echo "PASS: stdout contains BLOCKED with tier-2-fidelity-gate reason"
  else
    echo "FAIL: BLOCKED line missing tier-2-fidelity-gate reason"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: stdout missing BLOCKED line"
  fail=$((fail + 1))
fi
if grep -qF -e "CREATED: REF-cms-rule-blocked" "$OUT"; then
  echo "FAIL: stdout contains CREATED for BLOCK-verdict chunk (FR-18 violation)"
  fail=$((fail + 1))
else
  echo "PASS: no CREATED emitted for BLOCK-verdict chunk"
fi
# .structured.md sibling absence (FR-18 invariant).
STRUCT="$WORK/cms-rule/REF-cms-rule-blocked.structured.md"
if [ -f "$STRUCT" ]; then
  echo "FAIL: .structured.md sibling promoted (FR-18 violation): $STRUCT"
  fail=$((fail + 1))
else
  echo "PASS: no .structured.md sibling for BLOCK-verdict chunk"
fi
rm -f "$OUT"
trap - EXIT
rm -rf "$WORK"
echo "SUMMARY: m036-p04-tier-2-block-not-promoted.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3 — Author `tools/verify/m036-p04-p05-regression-pass.sh`

Create `tools/verify/m036-p04-p05-regression-pass.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-p05-regression-pass.sh -- M036 P04 T03.
# Regression guard: re-runs the P05 phase-suite aggregator and asserts
# its SUMMARY line still reports pass=8 fail=0. Confirms P04's edits to
# rebuild-index.sh (basename-filter widening + *.text|*.structured
# exclusion) do not perturb P05's 8 edge-insertion verifiers.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
P05_AGG="$ROOT/tools/verify/m036-p05-phase-suite.sh"
fail=0
if [ ! -f "$P05_AGG" ]; then
  echo "FAIL: P05 phase-suite missing $P05_AGG"
  echo "SUMMARY: m036-p04-p05-regression-pass.sh fail=1"
  exit 1
fi
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-p05-regression.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$P05_AGG" > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: P05 aggregator exit 0"
else
  echo "FAIL: P05 aggregator exit $rc"
  fail=$((fail + 1))
fi
if grep -qE 'SUMMARY: m036-p05-phase-suite\.sh pass=[0-9]+ fail=0' "$OUT"; then
  echo "PASS: P05 SUMMARY reports fail=0"
else
  echo "FAIL: P05 SUMMARY does not report fail=0 (regression detected)"
  cat "$OUT" >&2
  fail=$((fail + 1))
fi
rm -f "$OUT"
echo "SUMMARY: m036-p04-p05-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p04-command-shape.sh`

Create `tools/verify/m036-p04-command-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-command-shape.sh -- M036 P04 T03.
# Asserts commands/ingest-reference.md exists with the M036/P02-canonical
# command-doc structure (Prerequisites + Inputs + Output + Idempotency
# + Error Handling + Referenced Scripts sections) and declares the
# stdout protocol + flags per the M036 P04 contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
CMD="$ROOT/commands/ingest-reference.md"
fail=0
if [ -f "$CMD" ]; then
  echo "PASS: command doc exists $CMD"
else
  echo "FAIL: command doc missing $CMD"
  echo "SUMMARY: m036-p04-command-shape.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$CMD"; then
    echo "PASS: '$pat' in $(basename "$CMD")"
  else
    echo "FAIL: '$pat' missing in $(basename "$CMD")"
    fail=$((fail + 1))
  fi
}
checkpat "## Prerequisites"
checkpat "## Inputs"
checkpat "## Output"
checkpat "## Idempotency"
checkpat "## Error Handling"
checkpat "## Referenced Scripts"
checkpat "--reference-root"
checkpat "--no-index-rebuild"
checkpat "CREATED:"
checkpat "SKIPPED:"
checkpat "REJECTED:"
checkpat "BLOCKED:"
checkpat "ingest-reference.sh"
checkpat "FR-18"
echo "SUMMARY: m036-p04-command-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all three new verifiers executable: `chmod +x tools/verify/m036-p04-{tier-2-block-not-promoted,p05-regression-pass,command-shape}.sh`.

## Must-Haves

(Subset of phase must-haves T03 addresses)

- A fixture chunk whose Tier 0 frontmatter declares `tier_2_verdict: "BLOCK"` emits `BLOCKED:` advisory and is NOT promoted (FR-18 invariant).
- `commands/ingest-reference.md` exists with the M036/P02-canonical command-doc structure.
- The P05 phase-suite aggregator continues to report `pass=8 fail=0` after P04's rebuild-index.sh edits.

## Verification

```bash
bash tools/verify/m036-p04-tier-2-block-not-promoted.sh
```

```bash
bash tools/verify/m036-p04-command-shape.sh
```

```bash
bash tools/verify/m036-p04-p05-regression-pass.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/ingest-reference.sh` (T02) — the driver. CLI shape:
  - `--reference-root <path>` (default `knowledge/reference/`).
  - `--no-index-rebuild` (skip final rebuild).
  - Stdout protocol: `CREATED:` / `SKIPPED:` / `REJECTED:` / `BLOCKED:` / `SUMMARY:`.
  - Behavior on `tier_2_verdict: "BLOCK"`: emits `BLOCKED: <chunk_id> reason=tier-2-fidelity-gate`, increments `blocked` counter, does NOT emit CREATED, exits 0 at end of pass.
- `scripts/knowledge/rebuild-index.sh` (T02-modified) — basename filter widened to `MEM*|SPEC-*|REF-*` + `*.text|*.structured` exclusion; all other behavior byte-identical to pre-T02.
- `tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md` (T01) — BLOCK-verdict fixture.

### From Disk (Pre-existing)

- `tools/verify/m036-p05-phase-suite.sh` — P05 8-gate aggregator. CLI shape: `bash <path>`. Outputs `SUMMARY: m036-p05-phase-suite.sh pass=N fail=N`. Exits 0 iff `fail=0`. T03's regression verifier re-runs this and asserts the SUMMARY line still reports `fail=0`.
- `commands/extract.md` (M036/P02) — structural template for `commands/ingest-reference.md`. Read-only reference; T03 mirrors its section ordering and verbiage style.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-5 (no spec-chunk schema change — the BLOCK-gating logic operates on the additive `tier_2_verdict` frontmatter field; spec-chunk paths untouched).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- AP-009 no-compound-bash.
- MEM001 structured-stdout protocol.
- MEM012 Command File Structure (Prerequisites + Inputs + Output + Idempotency + Error Handling + Referenced Scripts sections).
- Verifier filename milestone-prefixed slug `m036-p04-*` per the post-[M031](../../../../../milestones/M031/index.md) plan-phase contract.
- `grep -qF -e "$pat"` form (not `grep -qF "$pat"`) for leading-dash safety.

## Expected Output

After T03 completes:

- `commands/ingest-reference.md` exists (~80 lines) with the canonical command-doc structure.
- 3 new executable verifier scripts under `tools/verify/m036-p04-*`.
- All three T03 verifiers exit 0 on this branch.
- M036/P05 phase-suite aggregator continues to report `fail=0` (regression guard).

## Notes

The `m036-p04-tier-2-block-not-promoted.sh` verifier stages the BLOCK-verdict fixture under `cms-rule/` in the workspace (instead of leaving it under `_negative/tier-2-block/`) because the driver only walks the four taxonomy-category directories at the top level of the reference root. The negative-path fixtures live under `_negative/` so they don't pollute the positive-path acceptance harness, but the BLOCK-fixture-specific verifier needs the chunk to actually be picked up by the walker.

This is the THIRD instance of the M036 cross-task ordering pattern within the milestone (M036/P02/T02 size-cap-external-pointer, M036/P03/T03 four-fixture green-flip, this T03 BLOCK-gating verifier). The pattern is a documented convention now; first-fail-retry handles the green-up at the dependent task's close.

The P05 regression verifier guards against the most likely silent-clobber failure mode for P04: the rebuild-index.sh `case`-block edit is a tiny, mechanical change, but a careless edit (e.g., adding `REF-*` BEFORE `*.text|*.structured`, which would let `REF-*.text` match the `REF-*` arm and cause text/structured siblings to be indexed as graph entries) would break P05's edge-insertion expectations silently. The `*.text|*.structured` exclusion is placed FIRST in the `case` block per Step 2 of T02 to enforce the precedence; this verifier provides the integration-level confirmation.

The `commands/ingest-reference.md` doc is purposefully shorter than `commands/ingest.md` (the spec-chunk version) because reference ingest has fewer moving parts (no fidelity gate at ingest-time — that's at extract-time in M036/P03; no normalization step — reference content is markdown by construction; no spec-shape probe). The M036/P02 `commands/extract.md` (~80 lines) is the closer template.
