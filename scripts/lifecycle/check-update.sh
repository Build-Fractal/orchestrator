#!/usr/bin/env bash
# scripts/lifecycle/check-update.sh — Offline-safe version checker.
#
# Compares the installed orchestrator bundle version against a remote "latest"
# version and reports structured key=value lines. Ships the read-only half of
# the FR-019 self-update infrastructure; actual upgrade execution is reserved
# for M010.
#
# Usage:
#   scripts/lifecycle/check-update.sh [--project-dir PATH] [--timeout SECONDS] [--remote-url URL]
#
# Outputs (stdout, key=value lines):
#   installed_version=<version-string>
#   latest_version=<version-string or "unknown">
#   update_available=true|false|unknown
#   update_instructions=<single line>   # only when update_available=true
#
# Exit codes:
#   0  always, unless invoked with invalid arguments.
#   2  invalid arguments.
#
# Constraints (AD-19 / MEM001):
#   - Bash 3.2 compatible.
#   - No python, no jq — pure bash/grep/sed/curl|wget.
#   - Remote fetch writes to a tmpfile then `read`s the value — never
#     `$(curl ... | trim)` with an inner pipe.
#   - Default --remote-url uses the .invalid TLD so it cannot resolve
#     on the real internet (placeholder for M010 infrastructure).
#   - Offline-safe: exits 0 when network, curl/wget, or remote is absent.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_DEFAULT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROJECT_DIR="$REPO_ROOT_DEFAULT"
TIMEOUT="5"
REMOTE_URL="https://speckit.example.invalid/orchestrator/latest.txt"
FALLBACK_VERSION="0.3.0-dev"

usage() {
  cat <<'EOF'
Usage: check-update.sh [--project-dir PATH] [--timeout SECONDS] [--remote-url URL]

Emits key=value lines on stdout:
  installed_version=<version>
  latest_version=<version|unknown>
  update_available=true|false|unknown
  update_instructions=<hint>   # only when update_available=true

Exits 0 in all normal cases (including network failure). Exits 2 on bad args.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      if [ $# -lt 2 ]; then
        echo "check-update.sh: --project-dir requires a value" >&2
        exit 2
      fi
      PROJECT_DIR="$2"
      shift 2
      ;;
    --timeout)
      if [ $# -lt 2 ]; then
        echo "check-update.sh: --timeout requires a value" >&2
        exit 2
      fi
      TIMEOUT="$2"
      shift 2
      ;;
    --remote-url)
      if [ $# -lt 2 ]; then
        echo "check-update.sh: --remote-url requires a value" >&2
        exit 2
      fi
      REMOTE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "check-update.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ------------------------------------------------------------------
# Resolve installed version.
# Order:
#   1. $PROJECT_DIR/VERSION (if present and non-empty).
#   2. $PROJECT_DIR/packaging/bundle/manifest.yml `version:` line.
#   3. Fallback "0.3.0-dev".
# ------------------------------------------------------------------

installed_version=""

version_file="$PROJECT_DIR/VERSION"
if [ -f "$version_file" ]; then
  # read -r line < file — no $(cat), satisfies AD-19.
  read -r installed_version < "$version_file" || installed_version=""
  # Trim leading/trailing whitespace.
  installed_version="${installed_version#"${installed_version%%[! 	]*}"}"
  installed_version="${installed_version%"${installed_version##*[! 	]}"}"
fi

if [ -z "$installed_version" ]; then
  manifest_file="$PROJECT_DIR/packaging/bundle/manifest.yml"
  if [ -f "$manifest_file" ]; then
    manifest_tmp="$(mktemp)"
    grep '^version:' "$manifest_file" > "$manifest_tmp" 2>/dev/null || true
    if [ -s "$manifest_tmp" ]; then
      raw_line=""
      read -r raw_line < "$manifest_tmp" || raw_line=""
      # Strip "version:" prefix, surrounding whitespace, and quotes.
      stripped="${raw_line#version:}"
      stripped="${stripped#"${stripped%%[! 	]*}"}"
      stripped="${stripped%"${stripped##*[! 	]}"}"
      stripped="${stripped%\"}"
      stripped="${stripped#\"}"
      stripped="${stripped%\'}"
      stripped="${stripped#\'}"
      installed_version="$stripped"
    fi
    rm -f "$manifest_tmp"
  fi
fi

if [ -z "$installed_version" ]; then
  installed_version="$FALLBACK_VERSION"
fi

# ------------------------------------------------------------------
# Resolve latest version from REMOTE_URL.
# AD-19 shape: write remote output to a tmpfile, then `read` from it.
# Never `$(curl ... | trim)`.
# ------------------------------------------------------------------

latest_version="unknown"
remote_tmp="$(mktemp)"
remote_ok=0

if command -v curl >/dev/null 2>&1; then
  if curl -fsS --max-time "$TIMEOUT" "$REMOTE_URL" > "$remote_tmp" 2>/dev/null; then
    remote_ok=1
  fi
elif command -v wget >/dev/null 2>&1; then
  if wget -qO- --timeout="$TIMEOUT" "$REMOTE_URL" > "$remote_tmp" 2>/dev/null; then
    remote_ok=1
  fi
fi

if [ "$remote_ok" = "1" ] && [ -s "$remote_tmp" ]; then
  raw_remote=""
  read -r raw_remote < "$remote_tmp" || raw_remote=""
  raw_remote="${raw_remote#"${raw_remote%%[! 	]*}"}"
  raw_remote="${raw_remote%"${raw_remote##*[! 	]}"}"
  if [ -n "$raw_remote" ]; then
    latest_version="$raw_remote"
  fi
fi

rm -f "$remote_tmp"

# ------------------------------------------------------------------
# Emit structured output.
# ------------------------------------------------------------------

printf 'installed_version=%s\n' "$installed_version"
printf 'latest_version=%s\n' "$latest_version"

if [ "$latest_version" = "unknown" ]; then
  printf 'update_available=unknown\n'
  exit 0
fi

if [ "$latest_version" = "$installed_version" ]; then
  printf 'update_available=false\n'
  exit 0
fi

printf 'update_available=true\n'
printf 'update_instructions=run: bash packaging/install/install-claude-code.sh --force (or the codex/cursor variant)\n'
exit 0
