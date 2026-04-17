#!/usr/bin/env bash
# scripts/knowledge/normalize-spec.sh
# Thin wrapper that normalizes a foreign-shaped markdown spec into the
# spec-kit section layout expected by commands/ingest.md. All agent I/O
# flows through scripts/dispatch/dispatch-interface.sh -- no hardcoded
# LLM HTTP calls (MEM018).
#
# Usage:
#   normalize-spec.sh --spec-path <source-path> --slug <slug>
#                     [--force] [--output-dir <dir>]
#
# Idempotency:
#   If <output-dir>/<slug>/spec.md already exists and its source_hash
#   marker matches the hash of the current source file, emits
#   SKIPPED: and exits 0 without dispatching.
#
# Stub mode:
#   If NORMALIZER_STUB=1 is set, skip the dispatch call and copy
#   tests/fixtures/normalized-stub.md to the output (still with
#   source_hash marker prepended). Required for T04 deterministic CI.
#
# Bash 3.2 compatible.

set -u

SPEC_PATH=""
SLUG=""
FORCE=0
OUTPUT_DIR="specs"

while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="${2:-}"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

if [ -z "$SPEC_PATH" ]; then
  echo "ERROR: --spec-path is required" >&2
  exit 1
fi
if [ -z "$SLUG" ]; then
  echo "ERROR: --slug is required" >&2
  exit 1
fi
if [ ! -f "$SPEC_PATH" ]; then
  echo "ERROR: source file not found: $SPEC_PATH" >&2
  exit 1
fi

# --- Compute SOURCE_HASH (sha256 -> md5 fallback) ---
SOURCE_HASH=""
if command -v shasum >/dev/null 2>&1; then
  SOURCE_HASH="$(shasum -a 256 "$SPEC_PATH" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  SOURCE_HASH="$(sha256sum "$SPEC_PATH" | awk '{print $1}')"
elif command -v md5 >/dev/null 2>&1; then
  SOURCE_HASH="$(md5 -q "$SPEC_PATH")"
elif command -v md5sum >/dev/null 2>&1; then
  SOURCE_HASH="$(md5sum "$SPEC_PATH" | awk '{print $1}')"
else
  echo "ERROR: no hashing utility (shasum/sha256sum/md5/md5sum) found" >&2
  exit 1
fi

OUTPUT_PATH="${OUTPUT_DIR}/${SLUG}/spec.md"
OUTPUT_DIR_FULL="${OUTPUT_DIR}/${SLUG}"

# --- Idempotency check ---
if [ "$FORCE" -eq 0 ] && [ -f "$OUTPUT_PATH" ]; then
  if grep -Fq -- "source_hash: \"${SOURCE_HASH}\"" "$OUTPUT_PATH"; then
    echo "SKIPPED: ${OUTPUT_PATH} (source unchanged)"
    exit 0
  fi
  if grep -Fq -- "source_hash: ${SOURCE_HASH}" "$OUTPUT_PATH"; then
    echo "SKIPPED: ${OUTPUT_PATH} (source unchanged)"
    exit 0
  fi
  if grep -Fq -- "<!-- source_hash: ${SOURCE_HASH} -->" "$OUTPUT_PATH"; then
    echo "SKIPPED: ${OUTPUT_PATH} (source unchanged)"
    exit 0
  fi
fi

# --- Prepare output directory ---
mkdir -p "$OUTPUT_DIR_FULL" 2>/dev/null || {
  echo "ERROR: failed to create output directory: $OUTPUT_DIR_FULL" >&2
  exit 1
}

TMP_OUT="${OUTPUT_DIR_FULL}/.spec.normalized.$$.tmp"

# --- Stub-mode short-circuit ---
if [ "${NORMALIZER_STUB:-0}" = "1" ]; then
  STUB_FIXTURE="tests/fixtures/normalized-stub.md"
  if [ ! -f "$STUB_FIXTURE" ]; then
    echo "ERROR: NORMALIZER_STUB=1 but fixture not found: $STUB_FIXTURE" >&2
    exit 1
  fi
  {
    printf '<!-- source_hash: %s -->\n' "$SOURCE_HASH"
    cat "$STUB_FIXTURE"
  } > "$TMP_OUT" || {
    echo "ERROR: failed to write temp output: $TMP_OUT" >&2
    exit 1
  }
  mv "$TMP_OUT" "$OUTPUT_PATH" || {
    echo "ERROR: failed to rename temp output to $OUTPUT_PATH" >&2
    exit 1
  }
  echo "NORMALIZED: ${OUTPUT_PATH} (source_hash=${SOURCE_HASH})"
  exit 0
fi

# --- Build prompt by substituting placeholders into the template ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/templates/spec-normalizer-prompt.md"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: normalizer prompt template not found: $TEMPLATE" >&2
  exit 1
fi

PROMPT_TMP="${OUTPUT_DIR_FULL}/.spec.normalizer-prompt.$$.tmp"
# Read source contents
SOURCE_CONTENTS="$(cat "$SPEC_PATH")"
# Use awk to substitute placeholders safely (avoid sed metacharacter pitfalls)
awk -v slug="$SLUG" -v src="$SOURCE_CONTENTS" '
  {
    line = $0
    gsub(/\{\{slug\}\}/, slug, line)
    gsub(/\{\{source_markdown\}\}/, src, line)
    print line
  }
' "$TEMPLATE" > "$PROMPT_TMP" || {
  echo "ERROR: failed to render prompt" >&2
  rm -f "$PROMPT_TMP"
  exit 1
}

# --- Dispatch through scripts/dispatch/dispatch-interface.sh ---
DISPATCH="${REPO_ROOT}/scripts/dispatch/dispatch-interface.sh"
if [ ! -x "$DISPATCH" ] && [ ! -f "$DISPATCH" ]; then
  echo "ERROR: dispatch-interface.sh not found: $DISPATCH" >&2
  rm -f "$PROMPT_TMP"
  exit 1
fi

# The dispatch-interface.sh router expects --task-plan and --payload
# file paths. We use the rendered prompt as both the task-plan body
# (the instruction the agent executes) and the payload context.
DISPATCH_RESULT_TMP="${OUTPUT_DIR_FULL}/.spec.dispatch-result.$$.tmp"
dispatch_rc=0
bash "$DISPATCH" \
  --task-plan "$PROMPT_TMP" \
  --payload "$PROMPT_TMP" \
  > "$DISPATCH_RESULT_TMP" 2>/dev/null || dispatch_rc=$?

if [ "$dispatch_rc" -ne 0 ]; then
  echo "ERROR: dispatch-interface.sh failed (exit=$dispatch_rc)" >&2
  rm -f "$PROMPT_TMP" "$DISPATCH_RESULT_TMP"
  exit 1
fi

# The adapter emits a dispatch-result.md document. For now we pass
# through its body as the normalized markdown. Prepend the source_hash
# marker and atomically rename.
{
  printf '<!-- source_hash: %s -->\n' "$SOURCE_HASH"
  cat "$DISPATCH_RESULT_TMP"
} > "$TMP_OUT" || {
  echo "ERROR: failed to write normalized output" >&2
  rm -f "$PROMPT_TMP" "$DISPATCH_RESULT_TMP" "$TMP_OUT"
  exit 1
}

rm -f "$PROMPT_TMP" "$DISPATCH_RESULT_TMP"

mv "$TMP_OUT" "$OUTPUT_PATH" || {
  echo "ERROR: failed to rename temp output to $OUTPUT_PATH" >&2
  rm -f "$TMP_OUT"
  exit 1
}

echo "NORMALIZED: ${OUTPUT_PATH} (source_hash=${SOURCE_HASH})"
exit 0
