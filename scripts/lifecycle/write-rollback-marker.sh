#!/usr/bin/env bash
# scripts/lifecycle/write-rollback-marker.sh
#
# M035 P05 T01 — Rollback-marker writer (FR-12 / D005 / #Q-G8 binding).
#
# Snapshots the prior install's .orchestrator/installed-files.txt manifest
# byte-for-byte to .orchestrator/.rollback/manifest-<prior-version>.txt and
# writes a five-field key=value sidecar at .orchestrator/.previous-version
# capturing prior version metadata. T02's --rollback driver replays the
# snapshot at restore time.
#
# Constitution / contracts:
#   - AD-19 single-script-file shape; no compound chains, no $(... | ...),
#     no plain subshells beyond single command substitutions for variable
#     capture.
#   - CON-2 bash 3.2 + POSIX-sh; runs unmodified on macOS bash 3.2.
#   - CON-7 (M025 reversibility-gate): reads installed-files.txt; never
#     modifies it. Purely additive (snapshot + marker).
#   - #Q-G8: prior_install_mode=symlink|mixed are RECORDED here but not
#     enforced — T02's --rollback driver consults this field to refuse.
#   - Idempotent: re-invocation overwrites the marker and the snapshot in
#     place (re-running at the same version is a no-op functionally).
#   - Greenfield (no prior installed-files.txt) is a no-op SKIP.
#
# Invocation:
#   bash scripts/lifecycle/write-rollback-marker.sh \
#     --project-dir <PATH> \
#     [--source-version <X.Y.Z>] \
#     [--source-commit-sha <SHA>] \
#     [--dry-run]
#
# Exit codes:
#   0 — success or skip-greenfield
#   1 — PROJECT_DIR validation failed; or installed-files.txt unreadable
#   2 — invalid arguments

set -u

PROJECT_DIR=""
SOURCE_VERSION=""
SOURCE_COMMIT_SHA=""
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="${2:-}"
      shift 2
      ;;
    --source-version)
      SOURCE_VERSION="${2:-}"
      shift 2
      ;;
    --source-commit-sha)
      SOURCE_COMMIT_SHA="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Step 1: PROJECT_DIR validation.
if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir is required" >&2
  exit 2
fi
if [ ! -d "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir does not exist: $PROJECT_DIR" >&2
  exit 1
fi

INSTALLED_FILES="$PROJECT_DIR/.orchestrator/installed-files.txt"
INSTALL_META="$PROJECT_DIR/.orchestrator/install-meta.txt"
MARKER_FILE="$PROJECT_DIR/.orchestrator/.previous-version"
ROLLBACK_DIR="$PROJECT_DIR/.orchestrator/.rollback"

# Step 2: Greenfield check.
if [ ! -f "$INSTALLED_FILES" ]; then
  echo "SKIP: greenfield install — no prior state to preserve"
  exit 0
fi

# Step 3: Read prior version from install-meta.txt `version=` line.
PRIOR_VERSION=""
if [ -f "$INSTALL_META" ]; then
  # `version=` line; tolerate leading/trailing whitespace; pick FIRST match.
  PRIOR_VERSION="$(grep -E '^version=' "$INSTALL_META" 2>/dev/null | head -1 | sed -E 's/^version=//')"
fi
if [ -z "$PRIOR_VERSION" ]; then
  PRIOR_VERSION="unknown"
fi

# Step 4: Read prior commit SHA from install-meta.txt `commit_sha=` line.
PRIOR_COMMIT_SHA=""
if [ -f "$INSTALL_META" ]; then
  PRIOR_COMMIT_SHA="$(grep -E '^commit_sha=' "$INSTALL_META" 2>/dev/null | head -1 | sed -E 's/^commit_sha=//')"
fi
# Empty is a valid recorded value (explicit empty per M035 P01 #Q-9 schema).

# Step 5: Read prior install mode by inspecting installed-files.txt.
# Counts: lines with mode:copy, lines with mode:symlink, total lines.
copy_count=0
symlink_count=0
total_lines=0
mode_marker_count=0
while IFS= read -r line; do
  total_lines=$((total_lines + 1))
  case "$line" in
    *"	mode:copy"*)
      copy_count=$((copy_count + 1))
      mode_marker_count=$((mode_marker_count + 1))
      ;;
    *"	mode:symlink"*)
      symlink_count=$((symlink_count + 1))
      mode_marker_count=$((mode_marker_count + 1))
      ;;
    "")
      total_lines=$((total_lines - 1))
      ;;
  esac
done < "$INSTALLED_FILES"

PRIOR_INSTALL_MODE=""
if [ "$mode_marker_count" -eq 0 ] && [ "$total_lines" -gt 0 ]; then
  # File present but malformed (no mode markers, e.g. pre-M035 P01 format).
  PRIOR_INSTALL_MODE="unknown"
elif [ "$copy_count" -gt 0 ] && [ "$symlink_count" -eq 0 ]; then
  PRIOR_INSTALL_MODE="copy"
elif [ "$symlink_count" -gt 0 ] && [ "$copy_count" -eq 0 ]; then
  PRIOR_INSTALL_MODE="symlink"
elif [ "$copy_count" -gt 0 ] && [ "$symlink_count" -gt 0 ]; then
  PRIOR_INSTALL_MODE="mixed"
else
  # Empty file with no entries — treat as unknown.
  PRIOR_INSTALL_MODE="unknown"
fi

# Step 6: Derive prior_manifest_path (relative to PROJECT_DIR for portability).
PRIOR_MANIFEST_REL=".orchestrator/.rollback/manifest-${PRIOR_VERSION}.txt"
PRIOR_MANIFEST_PATH="$PROJECT_DIR/$PRIOR_MANIFEST_REL"

# Dry-run branch: emit would_* lines and exit without writing.
if [ "$DRY_RUN" -eq 1 ]; then
  echo "would_write=$MARKER_FILE"
  echo "would_snapshot=$PRIOR_MANIFEST_PATH"
  # Echo the would-be marker contents so verifiers can assert field shape.
  echo "would_content_line=prior_version=$PRIOR_VERSION"
  echo "would_content_line=prior_commit_sha=$PRIOR_COMMIT_SHA"
  echo "would_content_line=prior_manifest_path=$PRIOR_MANIFEST_REL"
  echo "would_content_line=prior_install_mode=$PRIOR_INSTALL_MODE"
  echo "would_content_line=rolled_at="
  exit 0
fi

# Step 7: Snapshot installed-files.txt to .rollback/manifest-<prior-version>.txt.
mkdir -p "$ROLLBACK_DIR"
cp "$INSTALLED_FILES" "$PRIOR_MANIFEST_PATH"
cp_rc=$?
if [ "$cp_rc" -ne 0 ]; then
  echo "FAIL: snapshot copy failed (exit $cp_rc)" >&2
  exit 1
fi

# Step 8: Write the marker file at .orchestrator/.previous-version.
{
  printf 'prior_version=%s\n' "$PRIOR_VERSION"
  printf 'prior_commit_sha=%s\n' "$PRIOR_COMMIT_SHA"
  printf 'prior_manifest_path=%s\n' "$PRIOR_MANIFEST_REL"
  printf 'prior_install_mode=%s\n' "$PRIOR_INSTALL_MODE"
  printf 'rolled_at=\n'
} > "$MARKER_FILE"

# Step 9 + 10: Emit wrote= and snapshotted= lines.
echo "wrote=$MARKER_FILE"
echo "snapshotted=$PRIOR_MANIFEST_PATH"

# Step 11: Exit 0.
exit 0
