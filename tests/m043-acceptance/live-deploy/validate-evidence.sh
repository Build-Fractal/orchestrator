#!/usr/bin/env bash
# tests/m043-acceptance/live-deploy/validate-evidence.sh
#
# M043 SC-9 mechanical gate. Reads a filled live-deploy evidence note and
# exits 0 iff EITHER:
#   (a) completed live pass:
#         redirect_verified: yes  AND  ci_green: yes  AND  giscus_working: yes
#   (b) signed deferred-validation acknowledgment:
#         deferred_validation: yes  AND  signed_by: <non-empty>
#
# A missing note prints the literal "live-deploy validation not run --
# milestone close blocked" and exits 1 (fail-closed; mirrors M033
# validate-report.sh / spec FR-13 SC-9).
#
# Bash 3.2 compatible. Frontmatter parsed with awk -- no jq, no python.
# References: M043 spec FR-13 / US-4 / SC-9. MEM001 (bash 3.2).
set -e -u -o pipefail

NOTE="${1:-}"

if [ -z "$NOTE" ]; then
  echo "usage: validate-evidence.sh <evidence-note.md>" >&2
  exit 2
fi

if [ ! -f "$NOTE" ]; then
  echo "live-deploy validation not run -- milestone close blocked" >&2
  echo "  expected evidence note at: $NOTE" >&2
  exit 1
fi

# Read one frontmatter scalar (between the first two `---` lines), strip
# surrounding quotes/space, lower-case nothing (caller compares literals).
fm_val() {
  awk -v key="$1" '
    BEGIN { n=0 }
    /^---[[:space:]]*$/ { n++; if (n==2) exit; next }
    n==1 {
      pat = "^" key ":[[:space:]]*"
      if ($0 ~ pat) {
        sub(pat, "", $0)
        sub(/[[:space:]]*#.*$/, "", $0)   # drop trailing inline comment
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        gsub(/^"|"$/, "", $0)
        print
        exit
      }
    }
  ' "$NOTE"
}

redirect=$(fm_val redirect_verified)
ci=$(fm_val ci_green)
giscus=$(fm_val giscus_working)
deferred=$(fm_val deferred_validation)
signed=$(fm_val signed_by)

# Path (b): signed deferred-validation note.
if [ "$deferred" = "yes" ] && [ -n "$signed" ]; then
  echo "PASS: deferred-validation note signed_by=$signed (SC-9 forward-pointed)"
  exit 0
fi

# Path (a): completed live pass.
if [ "$redirect" = "yes" ] && [ "$ci" = "yes" ] && [ "$giscus" = "yes" ]; then
  echo "PASS: live deploy verified (redirect+ci+giscus all yes)"
  exit 0
fi

echo "FAIL: evidence note satisfies neither SC-9 path" >&2
echo "  completed-pass requires: redirect_verified=yes ci_green=yes giscus_working=yes" >&2
echo "    got: redirect_verified=$redirect ci_green=$ci giscus_working=$giscus" >&2
echo "  deferred path requires: deferred_validation=yes signed_by=<non-empty>" >&2
echo "    got: deferred_validation=$deferred signed_by=$signed" >&2
exit 1
