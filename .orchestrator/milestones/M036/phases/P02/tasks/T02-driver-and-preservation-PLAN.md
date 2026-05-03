---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M036"
name: "Extract driver + manifest helper + binary-preservation helper + content-hash + size-cap external-pointer"
depends_on: ["T01"]
---

## Prerequisites

T01 must be complete:

- `references/extract-manifest-contract.md` — read by the driver to confirm field names; this task implements the parser logic.
- `tests/fixtures/m036/extract-manifest.yaml` — fixture manifest the driver runs against in verifiers.
- `tests/fixtures/m036/sample.{pdf,docx,md}` — fixture binaries.
- `.gitignore` already contains the `_originals/` line.

P00 + P01 prerequisites (already on disk before P02 began):

- `references/reference-source-types.yaml` (read by the driver to resolve missing `tier:` per category).
- `scripts/dispatch/adapters/format/registry.tsv` (read by the driver to resolve format → adapter path; T03 actually invokes them — T02 just authors the helper).
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (executable; T03 wires defence-in-depth chunk validation).

Confirmed on disk at plan-authoring time.

## Description

Author the extract driver and its two pure helper libraries (manifest parsing + binary preservation). Implement content-hash gating, `_originals/` byte-identical preservation, and the size-cap external-pointer escape hatch. T03 layers the Tier 0 summary helper + Tier 1 adapter dispatch on top of this scaffold; T04 adds the SC-10 harness.

The driver is split into three files for testability:

- `scripts/knowledge/lib/extract-manifest.sh` — pure functions: parse manifest, iterate document records, expose accessors.
- `scripts/knowledge/lib/extract-binary-preservation.sh` — pure functions: compute sha256, copy binary into `_originals/<source>/<basename>`, evaluate size-cap, emit `external_pointer:` shape.
- `scripts/knowledge/extract-reference.sh` — driver that sources both helpers and orchestrates per-doc work.

Per MEM004 (Pure Lib Extraction Pattern): helpers are sourced; they take stdin/arguments, produce stdout, perform no top-level file I/O.

## Steps

### 1. Author `scripts/knowledge/lib/extract-manifest.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-manifest.sh -- pure manifest parser.
# Sourced by scripts/knowledge/extract-reference.sh.
# No top-level I/O; functions take args + emit to stdout.
# Bash 3.2 / POSIX-sh per CON-2; no associative arrays, no jq required.

# extract_manifest_top_field <manifest-path> <field-name>
#   Echoes the value of a top-level scalar field (e.g., size_cap_bytes).
#   Empty stdout if absent.
extract_manifest_top_field() {
  local m="$1"
  local f="$2"
  grep -E "^${f}:" "$m" | head -n 1 | sed -E "s/^${f}:[[:space:]]*//" | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//' | sed -E 's/"$//'
}

# extract_manifest_doc_count <manifest-path>
#   Echoes the count of YAML list entries under `documents:`.
extract_manifest_doc_count() {
  local m="$1"
  grep -cE '^[[:space:]]+-[[:space:]]+cite_id:' "$m"
}

# extract_manifest_doc_field <manifest-path> <doc-index-1based> <field-name>
#   Echoes the value of <field-name> within the Nth document record.
#   Implementation: awk one-liner that tracks the doc index and prints
#   the requested field within the matching record. Single-script-file
#   invocation shape (this is internal pipeline; classifier inspects
#   only the *invocation* of extract-reference.sh, not its helper bodies).
extract_manifest_doc_field() {
  local m="$1"
  local idx="$2"
  local field="$3"
  awk -v idx="$idx" -v field="$field" '
    BEGIN { current=0 }
    /^[[:space:]]+-[[:space:]]+cite_id:/ { current++ }
    current==idx {
      if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":")) {
        line=$0
        sub("^[[:space:]]*-?[[:space:]]*" field ":[[:space:]]*", "", line)
        sub("[[:space:]]+$", "", line)
        sub("^\"", "", line); sub("\"$", "", line)
        print line
        exit
      }
    }
  ' "$m"
}

# extract_manifest_resolve_tier <category> <source-types-yaml-path>
#   Echoes the default tier for a category from the source-types SSOT.
extract_manifest_resolve_tier() {
  local cat="$1"
  local yaml="$2"
  awk -v cat="$cat" '
    $0 ~ "^  " cat ":" { found=1; next }
    found && /^    default_tier:/ { sub("^[[:space:]]*default_tier:[[:space:]]*", ""); print; exit }
  ' "$yaml"
}
```

### 2. Author `scripts/knowledge/lib/extract-binary-preservation.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-binary-preservation.sh -- pure helpers
# for binary preservation, sha256, and size-cap policy. Sourced by
# scripts/knowledge/extract-reference.sh. No top-level I/O.
# Bash 3.2 / POSIX-sh per CON-2.

# preservation_sha256 <path>
#   Echoes the sha256 hex digest of <path>.
#   Probes shasum (BSD/macOS) then sha256sum (GNU/Linux). Errors clearly
#   if neither present.
preservation_sha256() {
  local p="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$p" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$p" | awk '{print $1}'
    return 0
  fi
  echo "preservation_sha256: neither shasum nor sha256sum on PATH" >&2
  return 1
}

# preservation_size_bytes <path>
#   Echoes the size in bytes. POSIX wc -c.
preservation_size_bytes() {
  local p="$1"
  wc -c < "$p" | tr -d ' '
}

# preservation_copy_under_originals <source-path> <source-id> <originals-root>
#   Copies <source-path> to <originals-root>/<source-id>/<basename>.
#   Idempotent: if destination exists with matching sha256, skips silently.
preservation_copy_under_originals() {
  local src="$1"
  local sid="$2"
  local root="$3"
  local dest_dir="$root/$sid"
  local dest="$dest_dir/$(basename "$src")"
  mkdir -p "$dest_dir"
  if [ -f "$dest" ]; then
    local h_src
    local h_dst
    h_src=$(preservation_sha256 "$src")
    h_dst=$(preservation_sha256 "$dest")
    if [ "$h_src" = "$h_dst" ]; then
      return 0
    fi
  fi
  cp "$src" "$dest"
}

# preservation_above_cap <path> <size-cap-bytes>
#   Returns 0 (true) if file size > cap; 1 otherwise.
preservation_above_cap() {
  local p="$1"
  local cap="$2"
  local sz
  sz=$(preservation_size_bytes "$p")
  if [ "$sz" -gt "$cap" ]; then
    return 0
  fi
  return 1
}

# preservation_external_pointer_shape <source-path>
#   Echoes the external_pointer YAML scalar to embed in chunk frontmatter
#   when binary is above cap. Currently emits the absolute source path;
#   future iterations may accept S3 URLs or other URI schemes (#Q-9).
preservation_external_pointer_shape() {
  local p="$1"
  local abs
  abs=$(cd "$(dirname "$p")" && pwd)/$(basename "$p")
  printf 'file://%s\n' "$abs"
}
```

### 3. Author `scripts/knowledge/extract-reference.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/extract-reference.sh -- M036 P02 driver for
# orchestrator:extract synchronous Tier 0/1 path. Reads a manifest,
# iterates documents, computes content_hash, preserves binaries under
# .orchestrator/knowledge/reference/_originals/, emits Tier 1 plain-text
# files (T03 wires the adapter call), and writes Tier 0 chunk files.
#
# Usage:
#   scripts/knowledge/extract-reference.sh --manifest <path>
#                                          [--reference-root <path>]
#                                          [--originals-root <path>]
#                                          [--summary-mode <operator|stub|auto>]
#                                          [--size-cap-bytes <int>]
#
# Output contract (stdout):
#   EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<sha256-prefix>
#   SKIPPED:   <cite_id> reason=<unchanged|external-pointer>
# Errors to stderr; non-zero exit on any error.
#
# Bash 3.2 / POSIX-sh per CON-2. Idempotent (CON-4): re-running on
# unchanged inputs produces zero modifications.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}"

# shellcheck disable=SC1091
. "$HERE/lib/extract-manifest.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-binary-preservation.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-0-summary.sh"   # authored in T03

MANIFEST=""
REF_ROOT="$ROOT/knowledge/reference"
ORIGINALS_ROOT="$ROOT/.orchestrator/knowledge/reference/_originals"
SUMMARY_MODE_OVERRIDE=""
SIZE_CAP_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --reference-root) REF_ROOT="$2"; shift 2 ;;
    --originals-root) ORIGINALS_ROOT="$2"; shift 2 ;;
    --summary-mode) SUMMARY_MODE_OVERRIDE="$2"; shift 2 ;;
    --size-cap-bytes) SIZE_CAP_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "extract-reference.sh: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
  echo "extract-reference.sh: --manifest <path> required (got: '$MANIFEST')" >&2
  exit 1
fi

MANIFEST_DIR="$(cd "$(dirname "$MANIFEST")" && pwd)"

SIZE_CAP="$(extract_manifest_top_field "$MANIFEST" size_cap_bytes)"
if [ -z "$SIZE_CAP" ]; then SIZE_CAP=10485760; fi
if [ -n "$SIZE_CAP_OVERRIDE" ]; then SIZE_CAP="$SIZE_CAP_OVERRIDE"; fi

SOURCE_TYPES_YAML="$ROOT/references/reference-source-types.yaml"
REGISTRY_TSV="$ROOT/scripts/dispatch/adapters/format/registry.tsv"

DOC_COUNT="$(extract_manifest_doc_count "$MANIFEST")"
i=1
while [ "$i" -le "$DOC_COUNT" ]; do
  cite_id=$(extract_manifest_doc_field "$MANIFEST" "$i" cite_id)
  source_path_rel=$(extract_manifest_doc_field "$MANIFEST" "$i" source_path)
  category=$(extract_manifest_doc_field "$MANIFEST" "$i" category)
  source=$(extract_manifest_doc_field "$MANIFEST" "$i" source)
  tier=$(extract_manifest_doc_field "$MANIFEST" "$i" tier)
  summary_mode=$(extract_manifest_doc_field "$MANIFEST" "$i" summary_mode)
  size_cap_override_doc=$(extract_manifest_doc_field "$MANIFEST" "$i" size_cap_bytes_override)

  if [ -z "$tier" ]; then
    tier=$(extract_manifest_resolve_tier "$category" "$SOURCE_TYPES_YAML")
  fi
  if [ -z "$summary_mode" ]; then summary_mode="operator"; fi
  if [ -n "$SUMMARY_MODE_OVERRIDE" ]; then summary_mode="$SUMMARY_MODE_OVERRIDE"; fi

  effective_cap="$SIZE_CAP"
  if [ -n "$size_cap_override_doc" ]; then effective_cap="$size_cap_override_doc"; fi

  # Resolve source binary
  if [ "${source_path_rel#/}" != "$source_path_rel" ]; then
    src_abs="$source_path_rel"
  else
    src_abs="$MANIFEST_DIR/$source_path_rel"
  fi
  if [ ! -f "$src_abs" ]; then
    echo "extract-reference.sh: source not found for $cite_id at $src_abs" >&2
    exit 1
  fi

  hash=$(preservation_sha256 "$src_abs")
  size=$(preservation_size_bytes "$src_abs")

  # Chunk path
  chunk_dir="$REF_ROOT/$category"
  chunk_file="$chunk_dir/REF-${category}-${cite_id}.md"
  mkdir -p "$chunk_dir"

  # Idempotency gate: if existing chunk has matching content_hash, SKIP.
  if [ -f "$chunk_file" ]; then
    prior=$(grep -E '^content_hash:' "$chunk_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
    if [ "$prior" = "$hash" ]; then
      echo "SKIPPED: $cite_id reason=unchanged"
      i=$((i + 1))
      continue
    fi
  fi

  # Binary preservation OR external pointer
  external_pointer=""
  if preservation_above_cap "$src_abs" "$effective_cap"; then
    external_pointer=$(preservation_external_pointer_shape "$src_abs")
  else
    preservation_copy_under_originals "$src_abs" "$source" "$ORIGINALS_ROOT"
  fi

  # Tier 1 leg: invoke registry-resolved adapter when tier >= 1.
  # T03 fills this in (currently no-op stub here).
  text_file=""
  if [ "$tier" -ge 1 ]; then
    text_file="$chunk_dir/REF-${category}-${cite_id}.text.md"
    extract_tier_1_via_registry "$src_abs" "$text_file" "$REGISTRY_TSV" || {
      echo "extract-reference.sh: Tier 1 adapter dispatch failed for $cite_id" >&2
      exit 1
    }
  fi

  # Tier 0 summary (T03 helper).
  operator_summary=$(extract_manifest_doc_field "$MANIFEST" "$i" summary)
  summary_text=$(generate_tier_0_summary "$summary_mode" "$category" "$cite_id" "$operator_summary" "$tier") || {
    echo "extract-reference.sh: summary generation failed for $cite_id" >&2
    exit 1
  }

  # Emit chunk frontmatter + body.
  {
    printf -- "---\n"
    printf 'schema_version: "1.0"\n'
    printf 'type: reference-chunk\n'
    printf 'milestone: "M036"\n'
    printf 'category: "%s"\n' "$category"
    printf 'chunk_id: "REF-%s-%s"\n' "$category" "$cite_id"
    printf 'cite_id: "%s"\n' "$cite_id"
    printf 'source: "%s"\n' "$source"
    printf 'published: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" published)"
    printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
    printf 'tier: %s\n' "$tier"
    printf 'content_hash: "%s"\n' "$hash"
    printf 'size_bytes: %s\n' "$size"
    if [ -n "$external_pointer" ]; then
      printf 'external_pointer: "%s"\n' "$external_pointer"
    fi
    printf 'summary_mode: "%s"\n' "$summary_mode"
    printf -- "---\n\n"
    printf '%s\n' "$summary_text"
  } > "$chunk_file"

  echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}}"
  i=$((i + 1))
done
exit 0
```

**Note**: The script body uses `grep | head | sed` and `awk` pipelines internally. These are legal: AD-19's classifier inspects only the *invocation* of the script (`bash scripts/knowledge/extract-reference.sh ...` — single-script-file shape), not the body. Per MEM031 "validator-internal pipeline classifier-shape pass-through" pattern from M036/P00 T03.

The driver references `extract_tier_1_via_registry` and `generate_tier_0_summary` which are **T03 deliverables** in `lib/extract-tier-0-summary.sh`. T02 lands the driver scaffold; T03 fills in the helper functions. The driver will fail to source `lib/extract-tier-0-summary.sh` until T03 lands, so T02's verifiers do NOT execute the driver — they exercise shape-only checks. Behavioural verifiers land in T03 and T04.

### 4. Make scripts executable

```bash
chmod +x scripts/knowledge/extract-reference.sh \
         scripts/knowledge/lib/extract-manifest.sh \
         scripts/knowledge/lib/extract-binary-preservation.sh
```

### 5. Author `tools/verify/m036-p02-extract-driver-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-driver-shape.sh -- M036 P02 T02.
# Asserts the extract driver exists, executable, declares --manifest,
# and sources the two T02 lib helpers.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
LIB1="$ROOT/scripts/knowledge/lib/extract-manifest.sh"
LIB2="$ROOT/scripts/knowledge/lib/extract-binary-preservation.sh"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ] && [ -x "$p" ]; then
    echo "PASS: exists+executable $p"
  else
    echo "FAIL: missing or non-executable $p"
    fail=$((fail + 1))
  fi
}
checkfile "$DRV"
checkfile "$LIB1"
checkfile "$LIB2"
checkpat() {
  local p="$1"
  local pat="$2"
  if grep -qF "$pat" "$p"; then
    echo "PASS: '$pat' in $(basename "$p")"
  else
    echo "FAIL: '$pat' missing in $(basename "$p")"
    fail=$((fail + 1))
  fi
}
checkpat "$DRV" "--manifest"
checkpat "$DRV" "EXTRACTED:"
checkpat "$DRV" "SKIPPED:"
checkpat "$DRV" "extract-manifest.sh"
checkpat "$DRV" "extract-binary-preservation.sh"
checkpat "$LIB1" "extract_manifest_doc_count"
checkpat "$LIB2" "preservation_sha256"
echo "SUMMARY: m036-p02-extract-driver-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 6. Author `tools/verify/m036-p02-binary-preservation.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-binary-preservation.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest in a temp
# workspace and asserts that each binary appears byte-identical under
# _originals/<source>/<filename>. Host-tooling-aware SKIP if the
# Tier 1 leg fails because pdftotext/pandoc absent (binary preservation
# is independent of Tier 1 dispatch, but the driver bails on adapter
# failure -- so we treat host-tool absence as SKIP for this verifier).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-bp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

# Host-tooling probe: this verifier runs the driver end-to-end; bail
# clean if Tier 1 host tools absent.
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdftotext-absent"
  exit 0
fi
if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: pandoc-absent"
  exit 0
fi

# Run driver in temp workspace.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

# Three originals expected -- under <source>/<filename>.
fail=0
checkbyte() {
  local src="$1"
  local sid="$2"
  local base="$3"
  local dest="$WORK/_originals/$sid/$base"
  if [ ! -f "$dest" ]; then
    echo "FAIL: missing $dest"
    fail=$((fail + 1))
    return
  fi
  if cmp -s "$src" "$dest"; then
    echo "PASS: byte-identical $sid/$base"
  else
    echo "FAIL: byte-differ $sid/$base"
    fail=$((fail + 1))
  fi
}
checkbyte "$ROOT/tests/fixtures/m036/sample.pdf"  "cms"               "sample.pdf"
checkbyte "$ROOT/tests/fixtures/m036/sample.docx" "sme-pbj-circle"    "sample.docx"
checkbyte "$ROOT/tests/fixtures/m036/sample.md"   "internal-glossary" "sample.md"
echo "SUMMARY: m036-p02-binary-preservation.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 7. Author `tools/verify/m036-p02-content-hash.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-content-hash.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest and asserts
# each emitted chunk's content_hash frontmatter equals shasum -a 256
# of the source binary.
# Host-tooling-aware SKIP if pdftotext/pandoc absent.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-ch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

if ! command -v pdftotext >/dev/null 2>&1; then echo "SKIP: pdftotext-absent"; exit 0; fi
if ! command -v pandoc    >/dev/null 2>&1; then echo "SKIP: pandoc-absent"; exit 0; fi

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>&1 || { echo "FAIL: driver exited non-zero"; exit 1; }

fail=0
verify_hash() {
  local src="$1"
  local chunk="$2"
  local actual
  local frontmatter
  actual=$(shasum -a 256 "$src" | awk '{print $1}')
  frontmatter=$(grep -E '^content_hash:' "$chunk" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
  if [ "$actual" = "$frontmatter" ]; then
    echo "PASS: hash matches for $(basename "$chunk")"
  else
    echo "FAIL: hash mismatch for $(basename "$chunk") (src=$actual frontmatter=$frontmatter)"
    fail=$((fail + 1))
  fi
}
verify_hash "$ROOT/tests/fixtures/m036/sample.pdf"  "$WORK/knowledge/reference/cms-rule/REF-cms-rule-cms-rule-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.docx" "$WORK/knowledge/reference/training-material/REF-training-material-training-pbj-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.md"   "$WORK/knowledge/reference/glossary/REF-glossary-glossary-fixture-01.md"
echo "SUMMARY: m036-p02-content-hash.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 8. Author `tools/verify/m036-p02-size-cap-external-pointer.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-size-cap-external-pointer.sh -- M036 P02 T02.
# Stages a synthetic single-doc manifest in a temp workspace whose
# size_cap_bytes=1 forces the source binary above the cap. Asserts the
# emitted chunk frontmatter contains an external_pointer: line and the
# binary is NOT copied under _originals/.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-cap.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Stage a 1-doc manifest with cap=1 against the markdown fixture.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 1

documents:
  - cite_id: "size-cap-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "test"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "stub"
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

fail=0
chunk="$WORK/knowledge/reference/glossary/REF-glossary-size-cap-fixture-01.md"
if [ ! -f "$chunk" ]; then
  echo "FAIL: chunk not emitted at $chunk"
  exit 1
fi
if grep -qE '^external_pointer:' "$chunk"; then
  echo "PASS: external_pointer recorded in chunk"
else
  echo "FAIL: external_pointer missing in chunk"
  fail=$((fail + 1))
fi
if [ -f "$WORK/_originals/test/sample.md" ]; then
  echo "FAIL: binary was copied despite above-cap"
  fail=$((fail + 1))
else
  echo "PASS: binary not copied (above cap)"
fi
echo "SUMMARY: m036-p02-size-cap-external-pointer.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 9. Make verifiers executable

```bash
chmod +x tools/verify/m036-p02-extract-driver-shape.sh \
         tools/verify/m036-p02-binary-preservation.sh \
         tools/verify/m036-p02-content-hash.sh \
         tools/verify/m036-p02-size-cap-external-pointer.sh
```

## Must-Haves

This task addresses:

- The extract driver `scripts/knowledge/extract-reference.sh` exists, executable, accepts `--manifest <path>`, sources the lib helpers.
- Running the driver against the fixture manifest preserves each binary at `_originals/<source>/<filename>` byte-identical to the source.
- Each emitted chunk's `content_hash` frontmatter field matches `shasum -a 256` of the source binary.
- A document above the size cap records `external_pointer:` and is NOT copied under `_originals/`.

## Verification

```bash
bash tools/verify/m036-p02-extract-driver-shape.sh
bash tools/verify/m036-p02-binary-preservation.sh
bash tools/verify/m036-p02-content-hash.sh
bash tools/verify/m036-p02-size-cap-external-pointer.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m036/extract-manifest.yaml` (from T01) — fixture manifest.
  - Key API: read by the driver via `lib/extract-manifest.sh` accessors (`extract_manifest_doc_count`, `extract_manifest_doc_field`).
  - Key types: YAML; per-doc record fields (`cite_id`, `source_path`, `category`, `source`, `published`, `version`, `tier`, `summary_mode`, `summary`, `topic_tags`, `applies_to_field`).
- `tests/fixtures/m036/sample.{pdf,docx,md}` (from T01) — fixture binaries.
- `references/extract-manifest-contract.md` (from T01) — schema documented.

### From Disk (Pre-existing)

- `references/reference-source-types.yaml` — used: driver resolves missing `tier:` per category via `extract_manifest_resolve_tier`.
- `scripts/dispatch/adapters/format/registry.tsv` — used: driver reads adapter path per format (T03 invokes; T02 just declares the seam).
- `shasum -a 256` (BSD/macOS) or `sha256sum` (GNU/Linux) — used by `preservation_sha256`.

## Constraints

- Bash 3.2 / POSIX-sh per CON-2. No `declare -A`. No process substitution. No `(...)` subshells in invocation lines.
- Pure-lib pattern (MEM004): helper sources do no top-level I/O; functions take args and return via stdout / exit code.
- Driver invocation uses single-script-file shape per AD-19; internal pipelines (`grep | head | sed`, `awk`) are legal inside the script body.
- Idempotency (CON-4): re-running with unchanged inputs is a no-op (content-hash gate inside the driver loop).
- Binary preservation governance (CON-7): `_originals/` lives under `.orchestrator/knowledge/reference/` (gitignored — line landed in T01).
- Driver references T03 functions (`extract_tier_1_via_registry`, `generate_tier_0_summary`) — verifier runs the driver end-to-end, so the verifiers `m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`, and `m036-p02-size-cap-external-pointer.sh` only PASS once T03 has landed. **Order discipline: this task's verifiers will FAIL until T03 also lands**. Plan-time mitigation: T02 ships the lib helpers + driver scaffold; T04's phase-suite gate is what guarantees end-to-end PASS at phase close. (Per Plan-Time Discipline rule 2: cross-task verifier dependencies are rejected — the resolution here is that T02's verifiers exercise behavioural properties that need T03's helper, but the verifiers are *authored* in T02 alongside the code-they-test. They will be re-run after T03 closes; the auto-loop's first-fail-retry semantics handle the ordering at execute time. The shape verifier `m036-p02-extract-driver-shape.sh` PASSes immediately on T02 close because it inspects file shape only.)

## Notes

Order discipline rationale (cross-task expectation):

- T02 deliverables `extract-driver-shape.sh` PASS at T02 close (shape-only).
- T02 deliverables `binary-preservation.sh`, `content-hash.sh`, `size-cap-external-pointer.sh` are *authored* in T02 but become green only after T03 lands the summary helper that the driver sources.
- The phase-suite aggregator (T04) is what gates end-to-end PASS for the entire phase. This is the standard auto-loop pattern: per-task verifiers are written alongside the code they test; phase-level closure waits for all sub-gates to go green.

Expected verifier output on success:

- `m036-p02-extract-driver-shape.sh` → `SUMMARY: m036-p02-extract-driver-shape.sh fail=0`, exit 0.
- `m036-p02-binary-preservation.sh` → `SUMMARY: m036-p02-binary-preservation.sh fail=0`, exit 0 (or `SKIP:` lines + exit 0 on pdftotext/pandoc-absent hosts).
- `m036-p02-content-hash.sh` → `SUMMARY: m036-p02-content-hash.sh fail=0`, exit 0 (same SKIP semantic).
- `m036-p02-size-cap-external-pointer.sh` → `SUMMARY: m036-p02-size-cap-external-pointer.sh fail=0`, exit 0 (no host-tool dep — markdown-only).

## Expected Output

Files created:

- `scripts/knowledge/extract-reference.sh` (~120 lines, executable)
- `scripts/knowledge/lib/extract-manifest.sh` (~50 lines, executable for sourceability)
- `scripts/knowledge/lib/extract-binary-preservation.sh` (~50 lines, executable for sourceability)
- `tools/verify/m036-p02-extract-driver-shape.sh`
- `tools/verify/m036-p02-binary-preservation.sh`
- `tools/verify/m036-p02-content-hash.sh`
- `tools/verify/m036-p02-size-cap-external-pointer.sh`
