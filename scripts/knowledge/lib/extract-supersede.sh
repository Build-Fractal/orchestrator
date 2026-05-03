#!/usr/bin/env bash
# scripts/knowledge/lib/extract-supersede.sh -- M036 P06 T01.
#
# Pure-lib MEM004 helper for the supersede-chain authoring branch in
# scripts/knowledge/extract-reference.sh. No top-level execution.
# Functions take args, emit to stdout / exit code only.
#
# Bash 3.2 / POSIX-sh per CON-2.
#
# Functions:
#   supersede_find_chain_tip <chunk-dir> <category> <cite_id>
#     -> stdout: absolute path to the current chain-tip chunk file.
#        Walks REF-<cat>-<id>.md, REF-<cat>-<id>-v2.md, ...
#        Returns the highest-numbered file present.
#        If the bare-suffix file does not exist, exit 1.
#
#   supersede_next_version <chunk-dir> <category> <cite_id>
#     -> stdout: integer N+1 (the next free version slot).
#        Bare-suffix file counts as version 1.
#        If no chunk file exists yet, returns 1 (first-time extraction
#        path; caller should not be invoking this in that case).
#
#   supersede_amend_prior_chunk <prior-chunk-file> <new-chunk-id>
#     -> mutates the prior chunk frontmatter in-place to add
#        `superseded_by: <new-chunk-id>` after the existing
#        `content_hash:` line. Idempotent: if the prior chunk already
#        contains `superseded_by: <new-chunk-id>`, no-op.
set -eu

supersede_find_chain_tip() {
  local chunk_dir="$1"
  local category="$2"
  local cite_id="$3"
  local bare="$chunk_dir/REF-${category}-${cite_id}.md"
  if [ ! -f "$bare" ]; then
    return 1
  fi
  # Find highest -vN.md (N>=2). Bare-suffix is version 1.
  local highest=1
  local highest_file="$bare"
  local f n
  for f in "$chunk_dir"/REF-"${category}"-"${cite_id}"-v*.md; do
    [ -f "$f" ] || continue
    n=$(printf '%s\n' "$f" | sed -E "s|.*-v([0-9]+)\.md\$|\1|")
    case "$n" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$n" -gt "$highest" ]; then
      highest="$n"
      highest_file="$f"
    fi
  done
  printf '%s\n' "$highest_file"
}

supersede_next_version() {
  local chunk_dir="$1"
  local category="$2"
  local cite_id="$3"
  local bare="$chunk_dir/REF-${category}-${cite_id}.md"
  if [ ! -f "$bare" ]; then
    printf '1\n'
    return 0
  fi
  local highest=1
  local f n
  for f in "$chunk_dir"/REF-"${category}"-"${cite_id}"-v*.md; do
    [ -f "$f" ] || continue
    n=$(printf '%s\n' "$f" | sed -E "s|.*-v([0-9]+)\.md\$|\1|")
    case "$n" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$n" -gt "$highest" ]; then
      highest="$n"
    fi
  done
  printf '%s\n' "$((highest + 1))"
}

supersede_amend_prior_chunk() {
  local prior_file="$1"
  local new_chunk_id="$2"
  # Idempotency: if the line is already present, no-op.
  if grep -qF -e "superseded_by: \"${new_chunk_id}\"" "$prior_file"; then
    return 0
  fi
  # Insert after the existing content_hash: line. Use a tmpfile +
  # rename to keep Bash 3.2 / BSD-sed compatibility.
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/m036-p06-amend.XXXXXX")
  awk -v sb="superseded_by: \"${new_chunk_id}\"" '
    { print }
    /^content_hash:/ && !inserted { print sb; inserted=1 }
  ' "$prior_file" > "$tmp"
  mv "$tmp" "$prior_file"
}
