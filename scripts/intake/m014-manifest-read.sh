#!/usr/bin/env bash
# scripts/intake/m014-manifest-read.sh
# M024/P02/T02 — Live M014 interim-manifest reader (AD-4 direction `a`).
#
# Reads the six M014 interim-manifest keys from a feature spec frontmatter,
# emitting them as key=value lines in the canonical fixture order:
#   schema_version, type, feature_slug, created_at, status, milestone
#
# Inputs (exactly one of):
#   --spec-path <path>   Path to a spec.md file.
#   --specs-dir  <path>  Path to a specs/<NNN>-<slug>/ directory.
#
# Output (stdout, exactly six lines in this order):
#   schema_version=<value>
#   type=<value>
#   feature_slug=<value>
#   created_at=<value>
#   status=<value>
#   milestone=<value>
#
# Missing keys emit `<key>=null` (line count is always six — parseability invariant).
#
# Exit codes:
#   0 = success
#   1 = internal error (spec missing / unreadable / not a feature-spec)
#   2 = usage error
#   3 = M014 unshipped (templates/spec-template.md missing — see #DQ-2 stub branch)

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_GUARD="$ROOT/templates/spec-template.md"

usage() {
  echo "usage: m014-manifest-read.sh (--spec-path <p> | --specs-dir <d>)" >&2
  exit 2
}

SPEC_PATH=""
SPECS_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    --specs-dir) SPECS_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

# Exactly-one validation.
if [ -n "$SPEC_PATH" ] && [ -n "$SPECS_DIR" ]; then
  echo "m014-manifest-read.sh: --spec-path and --specs-dir are mutually exclusive" >&2
  exit 2
fi
if [ -z "$SPEC_PATH" ] && [ -z "$SPECS_DIR" ]; then
  usage
fi

# Invoke-time M014 shipping probe (#DQ-2 option `b`).
if [ ! -f "$TEMPLATE_GUARD" ]; then
  echo "m014-manifest-read.sh: M014 not yet shipped — templates/spec-template.md missing." >&2
  echo "This reader requires the M014 interim-manifest contract source (see AD-4 direction \`a\`)." >&2
  echo "Recover: ship M014, OR consume the fixture at tests/fixtures/m014-interim-manifest-keys.txt." >&2
  exit 3
fi

# Resolve spec path from --specs-dir if needed.
if [ -z "$SPEC_PATH" ]; then
  SPEC_PATH="$SPECS_DIR/spec.md"
fi

if [ ! -f "$SPEC_PATH" ]; then
  echo "m014-manifest-read.sh: spec not found: $SPEC_PATH" >&2
  exit 1
fi

# Validate frontmatter shape.
if ! head -30 "$SPEC_PATH" | grep -q '^type: feature-spec'; then
  echo "m014-manifest-read.sh: not a feature-spec frontmatter: $SPEC_PATH" >&2
  exit 1
fi

# Helper: extract one frontmatter value (between first `---` and second `---`).
# Strips surrounding double-quotes and leading/trailing whitespace.
# Emits empty string when key absent.
extract() {
  awk -v k="$1" '
    BEGIN { in_fm=0 }
    /^---$/ { in_fm++; next }
    in_fm==1 {
      if (match($0, "^" k ":[ \t]*")) {
        v = substr($0, RLENGTH+1)
        gsub(/^"/, "", v); gsub(/"$/, "", v)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' "$SPEC_PATH"
}

emit_line() {
  key="$1"
  val=$(extract "$key")
  if [ -z "$val" ]; then
    val="null"
  fi
  echo "$key=$val"
}

emit_line schema_version
emit_line type
emit_line feature_slug
emit_line created_at
emit_line status
emit_line milestone
exit 0
