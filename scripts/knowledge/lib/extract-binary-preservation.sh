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
  local base
  base=$(basename "$src")
  local dest="$dest_dir/$base"
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
  local dir
  local base
  dir=$(cd "$(dirname "$p")" && pwd)
  base=$(basename "$p")
  printf 'file://%s/%s\n' "$dir" "$base"
}
