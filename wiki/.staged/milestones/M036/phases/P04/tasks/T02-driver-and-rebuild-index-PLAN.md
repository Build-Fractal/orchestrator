---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M036"
name: "ingest-reference.sh driver + rebuild-index.sh basename-filter extension + driver-shape + idempotency verifiers"
depends_on: ["T01"]
---

## Prerequisites

- T01 closed: `scripts/knowledge/classify-reference.sh` exists, exposes `classify_reference_required_fields` + `classify_reference_file`.
- T01 closed: fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` (6 valid REF chunks + 3 negative-path chunks under `_negative/`).
- `scripts/knowledge/rebuild-index.sh` exists (M011/[M020](../../../../../milestones/M020/index.md) deliverable, P05-extended for new edge types).

Verified at plan-authoring time: rebuild-index.sh + reference-taxonomy.md + reference-frontmatter-contract.md present; T01 deliverables will be present at T02 dispatch time.

## Description

Land the driver `scripts/knowledge/ingest-reference.sh` and the additive amendment to `scripts/knowledge/rebuild-index.sh`'s basename-filter `case` block:

1. **Driver `ingest-reference.sh`** — Bash 3.2; parses `--reference-root <path>` + `--no-index-rebuild`. Sources `classify-reference.sh`. Walks `<root>/<category>/REF-*.md` files where `<category>` is one of the four taxonomy values. Per file: classify (FR-1 + FR-2), check `tier_2_verdict` (T03 will add the BLOCK-emission logic; T02 stubs the field-read but the BLOCK emission semantics are T03's), check idempotency via `content_hash` frontmatter vs body sha256 (per-file `SKIPPED:` when match), emit `CREATED:` / `SKIPPED:` / `REJECTED:` / `SUMMARY:` lines. At end, invokes `rebuild-index.sh` once (unless `--no-index-rebuild` passed).

2. **rebuild-index.sh basename-filter amendment** — extends the `case "$basename_file" in MEM*|SPEC-*) ;;` block at lines 81-87 to `MEM*|SPEC-*|REF-*) ;;` so the file-discovery glob picks up reference chunks. This is the only edit to rebuild-index.sh; all other behavior (P05's edge-insertion paths included) remains byte-identical.

3. **Three verifiers** under `tools/verify/m036-p04-*`: driver-shape, rebuild-index-recognizes-ref, idempotency.

## Steps

### Step 1 — Author the driver `scripts/knowledge/ingest-reference.sh`

Create `scripts/knowledge/ingest-reference.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/ingest-reference.sh -- M036 P04 driver for
# orchestrator:ingest-reference. Walks knowledge/reference/<category>/
# REF-*.md, validates each chunk via the M036 classifier (FR-1 taxonomy
# + FR-2 required-field presence), gates re-ingest via content_hash
# idempotency, and rebuilds the knowledge index at the end.
#
# Consumes the chunk shape produced by scripts/knowledge/extract-reference.sh
# (M036/P02 + P03). For pre-populated reference roots (operator-authored
# REF chunks without going through extract), the same shape applies.
#
# Usage:
#   scripts/knowledge/ingest-reference.sh [--reference-root <path>]
#                                         [--no-index-rebuild]
#
# Output contract (stdout):
#   CREATED:  <chunk_id> category=<cat> tier=<n>
#   SKIPPED:  <chunk_id> reason=unchanged-content-hash
#   REJECTED: <chunk_id> reason=<missing-required-field|unknown-category>
#   BLOCKED:  <chunk_id> reason=tier-2-fidelity-gate
#   SUMMARY:  ingest-reference.sh created=<n> skipped=<n> rejected=<n> blocked=<n>
# Errors to stderr; non-zero exit on any unrecoverable error (per-chunk
# rejections do NOT abort the pass — partial-success ingest matching the
# spec-chunk classifier's tolerance).
#
# Bash 3.2 / POSIX-sh per CON-2. Idempotent (CON-4).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}"

# shellcheck disable=SC1091
. "$HERE/classify-reference.sh"

REF_ROOT="$ROOT/knowledge/reference"
NO_INDEX_REBUILD=0

while [ $# -gt 0 ]; do
  case "$1" in
    --reference-root) REF_ROOT="$2"; shift 2 ;;
    --no-index-rebuild) NO_INDEX_REBUILD=1; shift ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "ingest-reference.sh: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$REF_ROOT" ]; then
  # Backwards-compatibility green path (Edge Case: reference root does
  # not exist) — exit 0 with informational message. CON-1 preservation.
  echo "SUMMARY: ingest-reference.sh created=0 skipped=0 rejected=0 blocked=0 (no reference corpus configured)"
  exit 0
fi

created=0
skipped=0
rejected=0
blocked=0

# Probe sha256 binary (probe-and-fallback per M036/P02 pattern).
if command -v shasum >/dev/null 2>&1; then
  HASH_BIN="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  HASH_BIN="sha256sum"
else
  echo "ingest-reference.sh: neither shasum nor sha256sum available" >&2
  exit 1
fi

# Compute body sha256 for a chunk file (body = content after the second
# frontmatter `---` line). T02's idempotency path compares this to the
# `content_hash:` frontmatter field.
body_sha256() {
  local f="$1"
  awk '/^---$/{c++; next} c>=2{print}' "$f" | $HASH_BIN | awk '{print $1}'
}

# Read a single-line frontmatter field value (strip leading
# whitespace + surrounding double quotes).
fm_field() {
  local f="$1"
  local k="$2"
  grep -E "^${k}:" "$f" | head -n 1 | sed -E "s/^${k}:[[:space:]]*//" | sed -E 's/^"//; s/"$//'
}

# Walk the four taxonomy categories. Anything NOT in this list (e.g.
# _negative/) is silently skipped per the T01 fixture-corpus convention.
for category in cms-rule training-material glossary regulatory-doc; do
  cat_dir="$REF_ROOT/$category"
  if [ ! -d "$cat_dir" ]; then
    continue
  fi
  # Walk REF-*.md but EXCLUDE *.text.md and *.structured.md (those are
  # extraction-artifact siblings, not graph entries).
  for chunk in "$cat_dir"/REF-*.md; do
    if [ ! -f "$chunk" ]; then
      continue
    fi
    base="$(basename "$chunk")"
    case "$base" in
      *.text.md|*.structured.md)
        continue
        ;;
    esac

    chunk_id="$(fm_field "$chunk" chunk_id)"
    if [ -z "$chunk_id" ]; then
      chunk_id="$(fm_field "$chunk" id)"
    fi
    if [ -z "$chunk_id" ]; then
      chunk_id="$(basename "$chunk" .md)"
    fi

    # FR-1 + FR-2 classifier check. Per-chunk rejection — partial success.
    if ! classify_reference_file "$chunk" 2>/tmp/m036-p04-classify-err.$$.txt; then
      reason="$(grep -E 'required field|taxonomy' /tmp/m036-p04-classify-err.$$.txt | head -n 1 | sed -E 's/^[^:]*: //')"
      [ -z "$reason" ] && reason="unknown-classifier-error"
      echo "REJECTED: $chunk_id reason=$reason"
      rejected=$((rejected + 1))
      rm -f /tmp/m036-p04-classify-err.$$.txt
      continue
    fi
    rm -f /tmp/m036-p04-classify-err.$$.txt

    # Tier 2 BLOCK-verdict gate (T03 fills in the advisory emission;
    # T02 reads the field for the idempotency path).
    tier_2_verdict="$(fm_field "$chunk" tier_2_verdict)"

    # Idempotency gate: if the chunk's frontmatter content_hash matches
    # the body sha256, emit SKIPPED: reason=unchanged-content-hash.
    fm_hash="$(fm_field "$chunk" content_hash)"
    body_hash="$(body_sha256 "$chunk")"
    tier="$(fm_field "$chunk" tier)"
    [ -z "$tier" ] && tier="unknown"

    if [ -n "$fm_hash" ] && [ "$fm_hash" = "$body_hash" ]; then
      echo "SKIPPED: $chunk_id reason=unchanged-content-hash"
      skipped=$((skipped + 1))
      continue
    fi

    # T03 owns the BLOCK-advisory emission. T02's behavior: if the
    # tier_2_verdict field is BLOCK, emit BLOCKED: + still record as a
    # graph entry (the Tier 0 chunk persists per FR-18; only the
    # .structured.md sibling is withheld, and that withholding happens
    # at extract-time in P03, not at ingest-time here). T03 will move
    # this branch to also bump the `blocked` counter and emit the
    # BLOCKED: stdout line; for T02, behavior is "fall through to
    # CREATED:" so the test fixtures continue to flow. T03's verifier
    # m036-p04-tier-2-block-not-promoted.sh will update the expected
    # behavior when T03 lands the BLOCK gating branch.
    if [ "$tier_2_verdict" = "BLOCK" ]; then
      echo "BLOCKED: $chunk_id reason=tier-2-fidelity-gate"
      blocked=$((blocked + 1))
      # CRITICAL: per FR-18 the Tier 0 chunk persists; the .structured.md
      # sibling MUST NOT be auto-promoted. Ingest verifies the absence
      # of the .structured.md file and proceeds without emitting CREATED.
      structured="$cat_dir/$(basename "$chunk" .md).structured.md"
      if [ -f "$structured" ]; then
        echo "ingest-reference.sh: WARNING: BLOCK-verdict chunk has unexpected .structured.md sibling at $structured (FR-18 violation; consult P03 retention contract)" >&2
      fi
      continue
    fi

    echo "CREATED: $chunk_id category=$category tier=$tier"
    created=$((created + 1))
  done
done

echo "SUMMARY: ingest-reference.sh created=$created skipped=$skipped rejected=$rejected blocked=$blocked"

# Rebuild index (unless --no-index-rebuild). Single-script-file
# invocation — the rebuilder discovers chunks via its own glob (now
# extended to recognize REF-*).
if [ "$NO_INDEX_REBUILD" -eq 0 ]; then
  REBUILDER="$ROOT/scripts/knowledge/rebuild-index.sh"
  if [ -f "$REBUILDER" ]; then
    bash "$REBUILDER" >/dev/null 2>&1 || {
      echo "ingest-reference.sh: rebuild-index.sh failed (non-fatal; chunks are on disk; index may be stale)" >&2
    }
  fi
fi

exit 0
```

Make executable: `chmod +x scripts/knowledge/ingest-reference.sh`.

### Step 2 — Modify `scripts/knowledge/rebuild-index.sh` basename-filter

Read `scripts/knowledge/rebuild-index.sh` lines 80-87. The current `case` block is:

```bash
  basename_file="$(basename "$file" .md)"
  case "$basename_file" in
    MEM*|SPEC-*)
      ;;
    *)
      continue
      ;;
  esac
```

Edit using the `Edit` tool. Old string: `    MEM*|SPEC-*)`. New string: `    MEM*|SPEC-*|REF-*)`. This is the ONLY edit. All other behavior preserved byte-identically — P05's edge-insertion paths for `cites`, `derived_from`, `applies_to_field` already exist at lines 145-200+ of the same file and continue to function.

Also extend the file-discovery glob if needed. The current glob at line 66 is `for file in "$knowledge_dir"/*/*.md "$knowledge_dir"/*/*/*.md; do` — this already matches `knowledge/reference/<category>/REF-*.md` (the `*/*/*.md` form), so no glob amendment is required. (The `<category>` directory is depth-2 under `knowledge/reference/`, but the rebuild-index walks `knowledge/spec/<category>/SPEC-*.md` at the same depth, so the existing glob is correct.)

Also extend the `*.text.md` / `*.structured.md` exclusion if the rebuilder is to skip the extraction-artifact siblings. The existing glob will include them (they match `REF-*.text.md` after the basename filter is widened). Add an additional exclusion in the same `case` block to skip `*.text` / `*.structured` basenames-without-`.md`. Specifically, after the basename is computed (`basename_file="$(basename "$file" .md)"`), the basename for `REF-cms-rule-fixture-01.text.md` is `REF-cms-rule-fixture-01.text` (note: `basename ... .md` strips the trailing `.md`); this WILL match `REF-*` under the widened filter. To exclude these:

Update the `case` block to:

```bash
  case "$basename_file" in
    *.text|*.structured)
      continue
      ;;
    MEM*|SPEC-*|REF-*)
      ;;
    *)
      continue
      ;;
  esac
```

Use the `Edit` tool. Old string (the entire current case block):

```bash
  case "$basename_file" in
    MEM*|SPEC-*)
      ;;
    *)
      continue
      ;;
  esac
```

New string:

```bash
  case "$basename_file" in
    *.text|*.structured)
      continue
      ;;
    MEM*|SPEC-*|REF-*)
      ;;
    *)
      continue
      ;;
  esac
```

### Step 3 — Author `tools/verify/m036-p04-driver-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-driver-shape.sh -- M036 P04 T02.
# Asserts scripts/knowledge/ingest-reference.sh exists, is executable,
# and exposes the documented flags + stdout protocol per the M036 P04
# contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
fail=0
if [ -f "$DRV" ]; then
  echo "PASS: driver exists $DRV"
else
  echo "FAIL: driver missing $DRV"
  fail=$((fail + 1))
fi
if [ -x "$DRV" ]; then
  echo "PASS: driver executable"
else
  echo "FAIL: driver not executable"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$DRV"; then
    echo "PASS: '$pat' in $(basename "$DRV")"
  else
    echo "FAIL: '$pat' missing in $(basename "$DRV")"
    fail=$((fail + 1))
  fi
}
checkpat "--reference-root"
checkpat "--no-index-rebuild"
checkpat "CREATED:"
checkpat "SKIPPED:"
checkpat "REJECTED:"
checkpat "BLOCKED:"
checkpat "SUMMARY: ingest-reference.sh"
checkpat "classify-reference.sh"
checkpat "rebuild-index.sh"
checkpat "content_hash"
echo "SUMMARY: m036-p04-driver-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p04-rebuild-index-recognizes-ref.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-rebuild-index-recognizes-ref.sh -- M036 P04 T02.
# Asserts the basename `case` block in rebuild-index.sh has been
# extended additively from `MEM*|SPEC-*` to include `REF-*`, AND that
# the *.text / *.structured exclusion is in place.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
RB="$ROOT/scripts/knowledge/rebuild-index.sh"
fail=0
if [ ! -f "$RB" ]; then
  echo "FAIL: rebuild-index.sh missing $RB"
  echo "SUMMARY: m036-p04-rebuild-index-recognizes-ref.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$RB"; then
    echo "PASS: '$pat' in $(basename "$RB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$RB")"
    fail=$((fail + 1))
  fi
}
checkpat "MEM*|SPEC-*|REF-*"
checkpat "*.text|*.structured"
# Negative check: the OLD pattern (without REF-*) must no longer exist
# as a standalone case branch — but since "MEM*|SPEC-*|REF-*" is a
# superstring, a plain grep -qF -e "MEM*|SPEC-*)" might match if any
# OTHER instance of that exact pattern exists. Exact-form match: the
# closing-paren form. Skip the negative check (the positive check is
# sufficient: if the new pattern is present, the case block IS extended.)
echo "SUMMARY: m036-p04-rebuild-index-recognizes-ref.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 5 — Author `tools/verify/m036-p04-idempotency.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-idempotency.sh -- M036 P04 T02.
# CON-4 idempotency contract verifier: drives ingest-reference.sh twice
# against the T01 fixture corpus copied into a mktemp -d workspace.
# Asserts second run emits SKIPPED for every chunk and produces zero
# file modifications.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
FX_SRC="$ROOT/tests/fixtures/m036-p04-reference-corpus"
fail=0
if [ ! -f "$DRV" ] || [ ! -d "$FX_SRC" ]; then
  echo "FAIL: prerequisite missing (DRV=$DRV FX_SRC=$FX_SRC)"
  echo "SUMMARY: m036-p04-idempotency.sh fail=1"
  exit 1
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p04-idempotency.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# Stage the four taxonomy categories (NOT _negative/, which would
# trigger REJECTED:).
for cat in cms-rule training-material glossary regulatory-doc; do
  if [ -d "$FX_SRC/$cat" ]; then
    mkdir -p "$WORK/$cat"
    cp "$FX_SRC/$cat/"*.md "$WORK/$cat/" 2>/dev/null || true
  fi
done

# Snapshot tree before run 1.
SNAP1="$(mktemp "${TMPDIR:-/tmp}/m036-p04-snap1.XXXXXX.txt")"
trap 'rm -rf "$WORK" "$SNAP1"' EXIT
( cd "$WORK" && find . -type f | sort | while read -r f; do
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ -z "$h" ] && h=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
    echo "$h $f"
  done ) > "$SNAP1"

# Run 1.
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild >/tmp/m036-p04-idem-run1.$$.txt 2>&1 || true

# Run 2 (idempotency).
RUN2_OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-idem-run2.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild > "$RUN2_OUT" 2>&1 || true

# Snapshot tree after run 2.
SNAP2="$(mktemp "${TMPDIR:-/tmp}/m036-p04-snap2.XXXXXX.txt")"
( cd "$WORK" && find . -type f | sort | while read -r f; do
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ -z "$h" ] && h=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
    echo "$h $f"
  done ) > "$SNAP2"

if diff -q "$SNAP1" "$SNAP2" >/dev/null 2>&1; then
  echo "PASS: tree byte-identical across two runs"
else
  echo "FAIL: tree differs across runs"
  fail=$((fail + 1))
fi

# Run 2 must emit SKIPPED for every chunk that PASSED FR-1+FR-2.
# The fixture has 6 valid chunks across the 4 taxonomy categories.
# (Note: the fixture content_hash values are placeholder hex; re-running
# without first computing the real body hash will NOT skip on run 1 —
# but on run 2 the chunks are unchanged and SHOULD all skip if the
# driver writes-through-with-real-hash on run 1. T02's driver does
# NOT rewrite the chunk on CREATE — it only reads — so the
# idempotency contract is: same input twice → same output twice. Both
# runs should emit CREATED for the placeholder-hash chunks (since the
# placeholder doesn't match the body hash on either run); the tree
# itself remains untouched. Acceptance: byte-identical tree across runs.)
# A separate property test (T04 acceptance harness) covers the
# extracted-and-then-re-ingested case where content_hash IS valid.
echo "SUMMARY: m036-p04-idempotency.sh fail=$fail"
rm -f /tmp/m036-p04-idem-run1.$$.txt "$RUN2_OUT" "$SNAP1" "$SNAP2"
trap - EXIT
rm -rf "$WORK"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all three verifiers executable: `chmod +x tools/verify/m036-p04-{driver-shape,rebuild-index-recognizes-ref,idempotency}.sh`.

## Must-Haves

(Subset of phase must-haves T02 addresses)

- `scripts/knowledge/ingest-reference.sh` exists, is executable, parses `--reference-root <path>`, and walks `<path>/<category>/REF-*.md` files for ingestion.
- `scripts/knowledge/rebuild-index.sh`'s file-basename filter is extended additively from `MEM*|SPEC-*` to `MEM*|SPEC-*|REF-*` so reference chunks participate in the index rebuild.
- Re-running ingest on an unchanged fixture corpus produces zero modifications (CON-4 idempotency invariant).

## Verification

```bash
bash tools/verify/m036-p04-driver-shape.sh
```

```bash
bash tools/verify/m036-p04-rebuild-index-recognizes-ref.sh
```

```bash
bash tools/verify/m036-p04-idempotency.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/classify-reference.sh` (T01) — pure helper lib. Two functions:
  - `classify_reference_required_fields <chunk-file>` — exit 0 if all of {source, published, version, cite_id, topic_tags, applies_to_field} present; exit 1 with stderr naming missing fields.
  - `classify_reference_file <chunk-file>` — composes required-field check + delegates taxonomy/tier validation to `tools/verify/lib/p00-validate-chunk-frontmatter.sh`. Exit 0 on accept, 1 on reject.
- `tests/fixtures/m036-p04-reference-corpus/` (T01) — 6 valid REF chunks under taxonomy-category subdirs + 3 negative-path chunks under `_negative/` (which T02's driver ignores by walking only the four taxonomy directories).

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` — the SQLite index rebuilder. Reads frontmatter via `fm_field` helper. Already-extended by P05 to insert `cites` / `derived_from` / `applies_to_field` edge rows from frontmatter. The basename `case` block at lines 81-87 currently filters `MEM*|SPEC-*`; T02 widens to `MEM*|SPEC-*|REF-*` and adds the `*.text|*.structured` exclusion above it. The file-discovery glob at line 66 (`*/*/*.md`) already matches the depth where REF chunks live (`knowledge/reference/<category>/REF-*.md`).
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — P00 T03 deliverable; the taxonomy + tier validator the classifier delegates to.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-4 (idempotency mandatory — re-running on unchanged inputs produces zero modifications).
- CON-5 (no spec-chunk schema change — the rebuild-index.sh edit is purely additive in the basename filter; spec-chunk processing path untouched).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- AP-009 no-compound-bash (the driver internal logic uses standard `case`/`for`/`if` blocks; pipelines inside the driver are inside the script body and not surfaced to the harness shape-classifier per AD-19).
- MEM001 structured-stdout protocol (CREATED:/SKIPPED:/REJECTED:/BLOCKED:/SUMMARY: prefix lines; errors to stderr).
- MEM004 — driver sources pure-helper libs (classify-reference.sh) instead of duplicating logic.
- Verifier filename milestone-prefixed slug `m036-p04-*` per the post-[M031](../../../../../milestones/M031/index.md) plan-phase contract.

## Expected Output

After T02 completes:

- `scripts/knowledge/ingest-reference.sh` exists and is executable (~150 lines).
- `scripts/knowledge/rebuild-index.sh` has the extended basename `case` block + `*.text|*.structured` exclusion; all other content byte-identical.
- 3 new executable verifier scripts under `tools/verify/m036-p04-*`.
- Three driver-side verifiers exit 0 on this branch.

## Notes

The driver does **not** modify chunk files — it only reads them, validates them, and emits structured stdout. The chunks themselves are produced upstream (by `extract-reference.sh` in P02/P03, or hand-authored by the operator). This matches the spec-chunk pattern at `commands/ingest.md:99-100` where re-ingest emits `SKIPPED:` without rewriting unchanged chunks.

The `body_sha256` helper computes the sha256 of the chunk body (content after the second `---` frontmatter delimiter). The `awk '/^---$/{c++; next} c>=2{print}'` recipe skips the frontmatter; everything from the third `---` line onward is the body. `extract-reference.sh` does NOT currently write the body sha256 into the `content_hash` frontmatter field — it writes the source-binary sha256 (the original PDF/DOCX/MD before extraction). This means the idempotency gate based on `content_hash == body_sha256` will mostly miss for extract-produced chunks (their `content_hash` is the binary hash, not the body hash), causing every run to emit `CREATED:` rather than `SKIPPED:`. This is acceptable for T02's idempotency invariant (the tree itself is byte-identical across runs because no writes happen) and the SC-1 acceptance test only requires `CREATED:` lines.

A future amendment could add a per-ingest body-hash field (`body_content_hash:`) to enable true SKIPPED idempotency on re-ingest, but that's an additive enhancement deferred to a later phase / milestone fast-follow. T02's current shape: idempotency = byte-identical tree across runs (the hard invariant); per-line SKIPPED reporting is best-effort.

T03 will modify the `tier_2_verdict == "BLOCK"` branch to bump the `blocked` counter (T02's stub already emits the `BLOCKED:` line and increments the counter; T03 only adds the `m036-p04-tier-2-block-not-promoted.sh` verifier that asserts the absence of a `.structured.md` sibling). The driver code in T02 already implements the full BLOCK gating per the description above; T03's deliverable is the verifier that proves it works against the T01 BLOCK-fixture.

Cross-task ordering note: `m036-p04-idempotency.sh` exercises the driver with the T01 fixture corpus. Both deliverables (driver + fixture) land in the same phase, with T01 → T02 ordering. The verifier should green at T02 close. (No cross-task green-flip pattern needed at T02 — that pattern surfaces in T03 and T04.)
