#!/usr/bin/env bash
# scripts/state/check-orchestrator-drift.sh — M035 P01 FR-3.
#
# Reads consumer's .orchestrator/install-meta.txt and the
# update_source / upstream-path config from .orchestrator/config.yml,
# emits a key=value block on stdout: update_source, upstream_path,
# commits_behind, versions_behind. Exit 0 always (consumers branch
# on the data, not the exit code) — FR-15 read-only-on-render.
#
# SHA-absent fallback (#Q-G5): when install-meta.txt lacks
# commit_sha=, emit commits_behind=unknown + versions_behind=
# semver-delta + one-time stderr advisory.
#
# Usage:
#   check-orchestrator-drift.sh --consumer <path>
#   check-orchestrator-drift.sh                       # defaults to $PWD
#
# Bash 3.2 compatible. No process substitution, no associative arrays,
# no `<<<` herestrings, no jq dependency.

set -u

CONSUMER="$PWD"
while [ $# -gt 0 ]; do
  case "$1" in
    --consumer)        shift; CONSUMER="$1"; shift ;;
    --consumer=*)      CONSUMER="${1#--consumer=}"; shift ;;
    -h|--help)         sed -n '2,18p' "$0"; exit 0 ;;
    *)                 echo "FAIL: unknown argument '$1'" >&2; exit 0 ;;  # FR-15: still 0
  esac
done

# --- Defaults ---
update_source="git"
upstream_path="$HOME/Sites/spec-kit-orchestrator"
commits_behind=0
versions_behind=0

# --- Read install-meta.txt ---
meta="$CONSUMER/.orchestrator/install-meta.txt"
commit_sha=""
version=""
if [ -f "$meta" ]; then
  commit_sha="$(awk -F= '/^commit_sha=/{print $2}' "$meta")"
  version="$(awk -F= '/^version=/{print $2}'   "$meta")"
fi

# --- Read .orchestrator/config.yml (best-effort, no jq) ---
cfg="$CONSUMER/.orchestrator/config.yml"
if [ -f "$cfg" ]; then
  # Extract update_source: <value>  (single-line YAML scalar).
  us_val="$(awk '/^update_source:/{sub(/^update_source:[[:space:]]*/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit}' "$cfg")"
  [ -n "$us_val" ] && update_source="$us_val"
  up_val="$(awk '/^update_upstream_path:/{sub(/^update_upstream_path:[[:space:]]*/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit}' "$cfg")"
  [ -n "$up_val" ] && upstream_path="$up_val"
fi

# --- update_source=none short-circuit ---
if [ "$update_source" = "none" ]; then
  printf 'commits_behind=0\nupdate_source=none\nupstream_path=\nversions_behind=0\n'
  exit 0
fi

# --- update_source=git: compute drift ---
if [ "$update_source" = "git" ]; then
  if [ -z "$commit_sha" ]; then
    # SHA-absent fallback (#Q-G5)
    echo "commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install)." >&2
    commits_behind="unknown"
  else
    if [ -d "$upstream_path/.git" ]; then
      # Resolve upstream HEAD; count commits between local_sha and upstream HEAD.
      upstream_head="$(cd "$upstream_path" && git rev-parse HEAD 2>/dev/null)"
      if [ -n "$upstream_head" ] && [ -n "$commit_sha" ]; then
        # `git rev-list --count A..B` = commits in B not in A. Run inside upstream repo.
        commits_behind="$(cd "$upstream_path" && git rev-list --count "$commit_sha..$upstream_head" 2>/dev/null)"
        [ -z "$commits_behind" ] && commits_behind=0
      fi
    fi
  fi

  # Compute versions_behind from CHANGELOG semver delta (works regardless of SHA).
  if [ -n "$version" ] && [ -f "$upstream_path/CHANGELOG.md" ]; then
    upstream_version="$(awk '/^## \[[0-9]/{print; exit}' "$upstream_path/CHANGELOG.md" | sed -E 's/^## \[([^]]+)\].*/\1/')"
    if [ -n "$upstream_version" ] && [ "$upstream_version" != "$version" ]; then
      versions_behind="$(awk -v a="$version" -v b="$upstream_version" '
        BEGIN {
          split(a, A, ".");
          split(b, B, ".");
          if (A[1] != B[1] || A[2] != B[2]) { print 1; exit }
          d = B[3] - A[3];
          if (d < 0) d = 0;
          print d;
        }')"
      [ -z "$versions_behind" ] && versions_behind=0
    fi
  fi
fi

# --- Emit the structured block (sorted, no blanks) ---
printf 'commits_behind=%s\nupdate_source=%s\nupstream_path=%s\nversions_behind=%s\n' \
  "$commits_behind" "$update_source" "$upstream_path" "$versions_behind"
exit 0
