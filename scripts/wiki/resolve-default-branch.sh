#!/usr/bin/env bash
# scripts/wiki/resolve-default-branch.sh — M037 P01 T05 CON-4 helper.
#
# Resolves the default branch name for a project's `origin` remote by reading
# `git symbolic-ref refs/remotes/origin/HEAD` and stripping the
# `refs/remotes/origin/` prefix. On any failure (no remote, no HEAD ref,
# detached state, shallow clone) falls back to "main" and returns 0.
#
# Per CON-4 / AD-7: ALWAYS exits 0 with a usable branch name on stdout.
# Downstream consumers (wiki-init.sh edit_uri: substitution, P02 FR-13
# GitHub source-link rewrite) rely on a non-empty stdout token regardless of
# remote-state edge cases.
#
# Per MEM001: bash 3.2 + POSIX sh compatible — no associative arrays, no
# process substitution, no command substitution containing pipes.
# Per AD-19: single-script-file shape.
#
# Usage:
#   bash scripts/wiki/resolve-default-branch.sh [<project-dir>]
#
# Stderr diagnostic emitted only when WIKI_DEBUG=1.

set -u

PROJECT_DIR="${1:-$PWD}"
FALLBACK="main"

debug() {
  if [ "${WIKI_DEBUG:-0}" = "1" ]; then
    printf 'resolve-default-branch: %s\n' "$1" >&2
  fi
}

if [ ! -d "$PROJECT_DIR" ]; then
  debug "project dir '$PROJECT_DIR' does not exist; falling back to $FALLBACK"
  printf '%s\n' "$FALLBACK"
  exit 0
fi

# Probe `git symbolic-ref refs/remotes/origin/HEAD`. Suppress stderr; we only
# care about stdout success.
ref="$(git -C "$PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)"

if [ -z "$ref" ]; then
  debug "git symbolic-ref refs/remotes/origin/HEAD returned empty in '$PROJECT_DIR'; falling back to $FALLBACK"
  printf '%s\n' "$FALLBACK"
  exit 0
fi

# Strip the `refs/remotes/origin/` prefix to extract the bare branch name.
branch="${ref#refs/remotes/origin/}"

if [ -z "$branch" ] || [ "$branch" = "$ref" ]; then
  debug "could not strip refs/remotes/origin/ prefix from '$ref'; falling back to $FALLBACK"
  printf '%s\n' "$FALLBACK"
  exit 0
fi

printf '%s\n' "$branch"
exit 0
