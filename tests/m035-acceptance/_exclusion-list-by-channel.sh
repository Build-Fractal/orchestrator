#!/usr/bin/env bash
# tests/m035-acceptance/_exclusion-list-by-channel.sh
# Extract per-channel exclusion paths from references/installation.md
# § Channel-specific metadata files. Bash 3.2.
#
# Inputs (env):
#   INSTALLATION_MD=<path-to-references/installation.md>
#   CHANNEL=<npm|homebrew|curl-pipe-bash>
# Output (stdout): newline-separated paths whose `Channel(s)` column
#   matches `all` or the requested channel.

set -u

if [ -z "${INSTALLATION_MD:-}" ]; then
  echo "FAIL: INSTALLATION_MD env var empty" >&2
  exit 1
fi
if [ -z "${CHANNEL:-}" ]; then
  echo "FAIL: CHANNEL env var empty" >&2
  exit 1
fi
if [ ! -f "$INSTALLATION_MD" ]; then
  echo "FAIL: $INSTALLATION_MD missing" >&2
  exit 1
fi

# Awk:
#   - flag=1 once we hit the section header
#   - flag=0 on the next ## heading
#   - inside the block, parse pipe-table rows where column 1 is a
#     backticked path and column 2 is `all` / `npm` / `homebrew` /
#     a comma-separated subset.
awk -v ch="$CHANNEL" '
  /^## Channel-specific metadata files/ { flag=1; next }
  flag && /^## / { flag=0 }
  flag && /^\| `/ {
    # row layout: | `<path>` | <channel-list> | <why> |
    # split on pipe; field 2 is the path-column with backticks,
    # field 3 is the channel column.
    n = split($0, f, /[|]/)
    if (n < 4) next
    path = f[2]
    chans = f[3]
    gsub(/^[ \t]+|[ \t]+$/, "", path)
    gsub(/^[ \t]+|[ \t]+$/, "", chans)
    gsub(/`/, "", path)
    # match channel: "all" matches every channel; otherwise
    # comma-separated list of channel names.
    matched = 0
    if (chans == "all") {
      matched = 1
    } else {
      m = split(chans, c, /[, ]+/)
      for (i = 1; i <= m; i++) {
        if (c[i] == ch) { matched = 1; break }
      }
    }
    if (matched) print path
  }
' "$INSTALLATION_MD"
