#!/usr/bin/env bash
# scripts/diagnostics/giscus-ids-from-gh.sh — fetch Giscus IDs for a (private-
# or public-) GitHub repo via the GraphQL API and print ready-to-paste export
# lines for the four GISCUS_* env vars used by wiki-deploy.sh.
#
# Why this exists: the giscus.app setup tool refuses to surface IDs for
# private repositories (its validator requires the repo be public). The
# underlying giscus GitHub App + client.js *do* work on private repos for
# authenticated team members; only the ID-lookup flow needs a private-repo
# path. This helper replaces that flow.
#
# Usage:
#   bash scripts/diagnostics/giscus-ids-from-gh.sh \
#     --repo <org>/<repo> --category "Wiki Comments"
#
# Flags:
#   --repo <org>/<repo>      GitHub repo slug (required).
#   --category <name>        Discussions category name (required).
#   --help                   Print this usage and exit 0.
#
# Output: four `export NAME="value"` lines on stdout, ready to paste into
# the shell that will run wiki-deploy.sh.
#
# Exit codes:
#   0 — all four IDs resolved and printed.
#   1 — network/auth failure, unresolvable repo, or unknown category.
#   2 — usage error.
#
# Prerequisites: `gh` on PATH, authenticated with a token that has `repo`
# scope (required to read private-repo GraphQL).
#
# Bash 3.2 compliant.

set -u

usage() {
  cat <<'USAGE'
Usage: bash scripts/diagnostics/giscus-ids-from-gh.sh --repo <org>/<repo> --category <name>

Queries the GitHub GraphQL API for the four IDs Giscus needs and prints
ready-to-paste export lines:

  export GISCUS_REPO="..."
  export GISCUS_REPO_ID="..."
  export GISCUS_CATEGORY="..."
  export GISCUS_CATEGORY_ID="..."

Flags:
  --repo <org>/<repo>      GitHub repo slug (required).
  --category <name>        Discussions category name (required).
  --help                   Print this usage and exit 0.

Prerequisites: `gh` on PATH, authenticated with `repo` scope. Run
`gh auth status` to verify.

See wiki/README.md "First-deploy checklist" for the full setup flow.
USAGE
}

REPO=""
CATEGORY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      if [ $# -lt 2 ]; then
        printf 'ERROR: --repo requires an argument\n' >&2
        exit 2
      fi
      REPO="$2"
      shift 2
      ;;
    --category)
      if [ $# -lt 2 ]; then
        printf 'ERROR: --category requires an argument\n' >&2
        exit 2
      fi
      CATEGORY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown flag: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$REPO" ] || [ -z "$CATEGORY" ]; then
  printf 'ERROR: --repo and --category are both required\n' >&2
  usage >&2
  exit 2
fi

case "$REPO" in
  */*) : ;;
  *)
    printf 'ERROR: --repo must be of the form <org>/<repo> (got: %s)\n' "$REPO" >&2
    exit 2
    ;;
esac

OWNER=${REPO%%/*}
NAME=${REPO##*/}

if ! command -v gh >/dev/null 2>&1; then
  printf 'ERROR: gh is not on PATH. Install from https://cli.github.com/.\n' >&2
  exit 1
fi

QUERY='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){id hasDiscussionsEnabled discussionCategories(first:50){nodes{id name}}}}'

RESP=$(gh api graphql -f query="$QUERY" -f owner="$OWNER" -f name="$NAME" 2>/dev/null) || {
  printf 'ERROR: gh api graphql call failed. Check `gh auth status` and the repo slug.\n' >&2
  exit 1
}

REPO_ID=$(printf '%s' "$RESP" | sed -n 's/.*"repository":{"id":"\([^"]*\)".*/\1/p')
if [ -z "$REPO_ID" ]; then
  printf 'ERROR: repository %s not found or not readable with current gh token.\n' "$REPO" >&2
  exit 1
fi

DISCUSSIONS_ENABLED=$(printf '%s' "$RESP" | sed -n 's/.*"hasDiscussionsEnabled":\([a-z]*\).*/\1/p')
if [ "$DISCUSSIONS_ENABLED" != "true" ]; then
  printf 'ERROR: Discussions is not enabled on %s. Enable in Settings -> General -> Features.\n' "$REPO" >&2
  exit 1
fi

CAT_ID=$(printf '%s' "$RESP" \
  | tr '{' '\n' \
  | grep -F "\"name\":\"$CATEGORY\"" \
  | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' \
  | head -n 1)

if [ -z "$CAT_ID" ]; then
  printf 'ERROR: category "%s" not found on %s. Available categories:\n' "$CATEGORY" "$REPO" >&2
  printf '%s' "$RESP" \
    | tr '{' '\n' \
    | sed -n 's/.*"name":"\([^"]*\)".*/  - \1/p' \
    | sort -u >&2
  exit 1
fi

printf 'export GISCUS_REPO="%s"\n' "$REPO"
printf 'export GISCUS_REPO_ID="%s"\n' "$REPO_ID"
printf 'export GISCUS_CATEGORY="%s"\n' "$CATEGORY"
printf 'export GISCUS_CATEGORY_ID="%s"\n' "$CAT_ID"

exit 0
