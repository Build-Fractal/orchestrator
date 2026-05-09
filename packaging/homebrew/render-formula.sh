#!/usr/bin/env bash
# packaging/homebrew/render-formula.sh -- render orchestrator.rb
# from orchestrator.rb.tmpl by substituting __VERSION__ / __URL__ /
# __SHA256__ tokens.
#
# Usage:
#   bash packaging/homebrew/render-formula.sh \
#     --version <X.Y.Z> \
#     --url <https://...tgz> \
#     --sha256 <64-hex-char-digest>
#
# Output (stdout): the rendered formula. No in-place writes;
# callers redirect to the desired path (e.g. tap-clone/Formula/
# orchestrator.rb).
#
# Bash 3.2 compatible. No declare -A, no <(...), no
# command-substitution-with-pipes.

set -u

VERSION=""
URL=""
SHA256=""

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --url)
      URL="${2:-}"
      shift 2
      ;;
    --sha256)
      SHA256="${2:-}"
      shift 2
      ;;
    *)
      echo "FAIL: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "FAIL: --version required" >&2
  exit 1
fi
if [ -z "$URL" ]; then
  echo "FAIL: --url required" >&2
  exit 1
fi
if [ -z "$SHA256" ]; then
  echo "FAIL: --sha256 required" >&2
  exit 1
fi

# Validate sha256 shape: exactly 64 hex chars, lowercase.
if ! printf '%s' "$SHA256" | grep -qE '^[0-9a-f]{64}$'; then
  echo "FAIL: --sha256 must be 64 lowercase hex chars (got: $SHA256)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPL="$SCRIPT_DIR/orchestrator.rb.tmpl"

if [ ! -f "$TMPL" ]; then
  echo "FAIL: template not found: $TMPL" >&2
  exit 1
fi

# Substitute tokens. Use sed with | as delimiter because the URL
# contains forward slashes. Escape | in URL defensively (URLs
# almost never contain | but the sed delimiter must not appear in
# the replacement).
url_escaped="$(printf '%s' "$URL" | sed -E 's/[|]/\\|/g')"

sed \
  -e "s|__VERSION__|$VERSION|g" \
  -e "s|__URL__|$url_escaped|g" \
  -e "s|__SHA256__|$SHA256|g" \
  "$TMPL"
