#!/usr/bin/env bash
# scripts/wiki/resolve-deploy-target.sh — resolve wiki.deploy_target for a
# project. Reads <root>/.orchestrator/config.yml. Returns:
#   github-pages      when the key/wiki-block/file is absent (FR-1 default)
#   github-pages      when explicitly set to github-pages
#   cloudflare-access when explicitly set to cloudflare-access
#   exit 2 + stderr   when the value is present but not a valid enum member
#                     (spec Edge Case: unknown value fails fast, never a
#                     silent fall-through to github-pages)
#
# Usage: resolve-deploy-target.sh <project-root>
# Bash 3.2 / POSIX-sh. No declare -A, no process substitution.
set -u

ROOT="${1:-.}"
CFG="$ROOT/.orchestrator/config.yml"
DEFAULT="github-pages"

val=""
if [ -f "$CFG" ]; then
  # Walk the top-level `wiki:` block for a 2-space-indented deploy_target: key.
  val="$(awk '
    BEGIN { in_wiki = 0 }
    /^wiki:[[:space:]]*$/      { in_wiki = 1; next }
    in_wiki && /^[^[:space:]]/ { exit }
    in_wiki && /^[[:space:]][[:space:]]deploy_target:/ {
      line = $0
      sub(/^[[:space:]]*deploy_target:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/"/, "", line)
      gsub(/[[:space:]]/, "", line)
      print line
      exit
    }
  ' "$CFG" 2>/dev/null || true)"
fi

case "$val" in
  "")
    printf '%s\n' "$DEFAULT"
    ;;
  github-pages|cloudflare-access)
    printf '%s\n' "$val"
    ;;
  *)
    printf 'resolve-deploy-target: unknown wiki.deploy_target value "%s" in %s (valid: github-pages, cloudflare-access)\n' "$val" "$CFG" >&2
    exit 2
    ;;
esac
exit 0
