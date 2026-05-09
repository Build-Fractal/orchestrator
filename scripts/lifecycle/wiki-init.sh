#!/usr/bin/env bash
# scripts/lifecycle/wiki-init.sh — M032 P02 T01 FR-5 default scope + FR-12 toolchain probe.
#
# Per MEM012 the canonical command document is commands/wiki-init.md.
# Per MEM001 this script is bash 3.2 compatible — no associative arrays,
# no process substitution, no command substitution containing pipes.
# Single-script-file shape per AD-19.
#
# Default scope (no --with-giscus, no --deploy):
#   1. Read wiki/ entry from packaging/bundle/manifest.yml via read-project-assets.sh.
#   2. Probe python3 + pip3 on PATH; fail-closed with platform-aware diagnostic.
#   3. Parse git remote 'origin' for <owner>/<repo>; synthesize the four templated values.
#   4. Stage wiki/ to <PROJECT_DIR>/wiki/ via collision-check + install-asset-mode.sh.
#      Self-application detection: when REPO_ROOT == PROJECT_DIR (orchestrator dogfooding
#      itself), skip the staging step — the bundle source IS the target.
#   5. Sed-substitute the four {{...}} placeholders in <PROJECT_DIR>/wiki/mkdocs.yml.
#   6. Author <PROJECT_DIR>/wiki/glossary.md path-convention stub if absent (FR-15).
#   7. Optional --auto-pip runs pip3 install -r requirements.txt (#Q-2).
#
# Exit codes:
#   0 — success (or "no changes" idempotency).
#   2 — argument error (unknown flag, missing required arg).
#   3 — toolchain missing (python3 or pip3 not on PATH).
#   4 — git remote missing or unparseable.
#   5 — --deploy passed but not implemented (P03/T02 replaces this).
#   6 — bundle staging failure (read-project-assets.sh or install-asset-mode.sh failed).
#   7 — --with-giscus invoked without --with-wiki (no <PROJECT_DIR>/wiki/overrides/partials/comments.html).
#   8 — integration-giscus-config-failed (giscus-ids-from-gh.sh upstream failure or unparseable output).
#   9 — integration-giscus-config-check-failed (wiki-giscus-config-check.sh post-step failure).
#  10 — --deploy step 1 (gh api PATCH discussions=true) failed.
#  11 — --deploy step 2 (wiki-deploy.sh) failed.
#  12 — --deploy step 3 (MIT-007 Pages guard rejected incompatible source).
#  13 — --deploy step 4 (gh api PUT /pages) failed.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Staged-invocation fallback: when this copy of wiki-init.sh was staged into
# a consumer project (manifest.yml absent at REPO_ROOT — packaging/ is
# source-repo-only per packaging/bundle/manifest.yml's project_assets list),
# resolve the orchestrator source repo via env override or the
# install-meta.txt sidecar written by install-{claude-code,codex,cursor}.sh
# (key: source_root=<abs>). Discovered via the M037 P01 wiki-deploy dogfood:
# `bash scripts/lifecycle/wiki-init.sh --project-dir .` from a staged-into
# project hit `FAIL: manifest not found` at line ~173 because REPO_ROOT
# resolved to PROJECT_DIR. The existing self-application detection (handles
# REPO_ROOT == PROJECT_DIR for orchestrator dogfooding) sits below the
# manifest read and never gets reached. Gated on manifest absence so the
# orchestrator self-application path is untouched.
if [ ! -f "$REPO_ROOT/packaging/bundle/manifest.yml" ]; then
  if [ -n "${WIKI_INIT_SOURCE_ROOT:-}" ] && [ -f "$WIKI_INIT_SOURCE_ROOT/packaging/bundle/manifest.yml" ]; then
    REPO_ROOT="$WIKI_INIT_SOURCE_ROOT"
  elif [ -f "$REPO_ROOT/.orchestrator/install-meta.txt" ]; then
    _src=$(awk -F'=' '$1 == "source_root" { sub(/^source_root=/, "", $0); print; exit }' "$REPO_ROOT/.orchestrator/install-meta.txt" 2>/dev/null || true)
    if [ -n "$_src" ] && [ -f "$_src/packaging/bundle/manifest.yml" ]; then
      REPO_ROOT="$_src"
    fi
    unset _src
  fi
fi

PROJECT_DIR=""
SITE_NAME_OVERRIDE=""
SITE_DESCRIPTION_OVERRIDE=""
AUTO_PIP=0
WITH_GISCUS=0
WITH_DEPLOY=0
FORCE=0
FORCE_PAGES_RECONFIG=0
GISCUS_REPO_FLAG=""
GISCUS_CATEGORY_FLAG=""

# Argument parsing — single-pass loop, no getopts (bash 3.2 portability).
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --project-dir=*) PROJECT_DIR="${1#--project-dir=}"; shift ;;
    --site-name) SITE_NAME_OVERRIDE="$2"; shift 2 ;;
    --site-name=*) SITE_NAME_OVERRIDE="${1#--site-name=}"; shift ;;
    --site-description) SITE_DESCRIPTION_OVERRIDE="$2"; shift 2 ;;
    --site-description=*) SITE_DESCRIPTION_OVERRIDE="${1#--site-description=}"; shift ;;
    --auto-pip) AUTO_PIP=1; shift ;;
    --with-giscus) WITH_GISCUS=1; shift ;;
    --deploy) WITH_DEPLOY=1; shift ;;
    --force) FORCE=1; shift ;;
    --force-pages-reconfigure) FORCE_PAGES_RECONFIG=1; shift ;;
    --repo)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --repo requires an <owner>/<repo> argument" >&2
        exit 2
      fi
      GISCUS_REPO_FLAG="$1"; shift ;;
    --repo=*) GISCUS_REPO_FLAG="${1#--repo=}"; shift ;;
    --category)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --category requires a category-name argument" >&2
        exit 2
      fi
      GISCUS_CATEGORY_FLAG="$1"; shift ;;
    --category=*) GISCUS_CATEGORY_FLAG="${1#--category=}"; shift ;;
    --with-wiki) shift ;;  # M032/P04/T02 in-flight repair: --with-wiki is consumed
                           # by init-project.sh's FR-11 passthrough; wiki-init.sh
                           # itself IS the wiki-init step, so the flag is structurally
                           # redundant here but accepted for FR-11 passthrough symmetry.
                           # Surfaced in P03/T04 SC-5 dry-run; documented in
                           # P03-SUMMARY.md operator follow-ups.
    *) echo "FAIL: wiki-init: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: wiki-init: --project-dir is required" >&2
  exit 2
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# M032/P02/T02 test-only failure-injection escape hatch (Seam-B in T05).
# Env-var-only access keeps it out of the operator-facing surface per the
# M026/MEM030 <TOOL>_EDITION=<value> env-var convention pattern.
if [ -n "${M032_WIKI_INIT_FORCE_EXIT:-}" ]; then
  echo "FAIL: wiki-init: M032_WIKI_INIT_FORCE_EXIT=$M032_WIKI_INIT_FORCE_EXIT (test-only failure injection)" >&2
  exit "$M032_WIKI_INIT_FORCE_EXIT"
fi

# M032/P03/T02 audit-trail helper for the --deploy scope. Defined here so
# the --deploy workflow block at the script tail can invoke it on any
# failure path. The helper consults MUT_DISCUSSIONS / MUT_GH_PAGES_BRANCH /
# MUT_PAGES_CONFIGURED if set; otherwise emits an empty mutations array.
audit_failure() {
  _step="$1"
  _rc="$2"
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _muts=""
  if [ "${MUT_DISCUSSIONS:-0}" -eq 1 ]; then
    _muts='{"type":"discussions_enabled"}'
  fi
  if [ "${MUT_GH_PAGES_BRANCH:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "${MUT_PAGES_CONFIGURED:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"failure","error":"%s: rc=%s"}\n' \
    "$_ts" "${OWNER:-unknown}" "${REPO:-unknown}" "$_muts" "$_step" "$_rc" >> "${LOG_FILE:-/dev/null}"
}

# FR-12: probe python3 + pip3.
if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  if [ "$uname_s" = "Darwin" ]; then
    echo "FAIL: wiki-init: python3/pip3 missing — install via 'brew install python3'" >&2
  else
    echo "FAIL: wiki-init: python3/pip3 missing — install via 'apt install python3' (or your distro equivalent)" >&2
  fi
  exit 3
fi

# FR-5: parse git remote for the four templated values.
ORIGIN_URL=""
set +e
ORIGIN_URL="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)"
set -e
if [ -z "$ORIGIN_URL" ]; then
  echo "FAIL: wiki-init: no git remote at origin in $PROJECT_DIR; configure one with 'git remote add origin <url>' before running wiki-init" >&2
  exit 4
fi

# Parse <owner>/<repo> from either https or ssh remote shapes.
# Examples:
#   https://github.com/Build-Fractal/spec-kit-orchestrator(.git)
#   git@github.com:Build-Fractal/spec-kit-orchestrator(.git)
OWNER_REPO="$(printf '%s' "$ORIGIN_URL" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##')"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ "$OWNER" = "$OWNER_REPO" ]; then
  echo "FAIL: wiki-init: cannot parse <owner>/<repo> from origin URL '$ORIGIN_URL'" >&2
  exit 4
fi

# Synthesize templated values.
# GitHub Pages canonical URL form lowercases the org; repo_url preserves case.
SITE_NAME="${SITE_NAME_OVERRIDE:-$REPO}"
SITE_DESCRIPTION="${SITE_DESCRIPTION_OVERRIDE:-}"
OWNER_LOWER="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
SITE_URL="https://${OWNER_LOWER}.github.io/${REPO}/"
REPO_URL="https://github.com/${OWNER}/${REPO}"

# ---- FR-21 (M037/P02/T03) — repo-visibility branch for site_url: ---------
# mkdocs-material's 404.html uses absolute asset paths derived from
# site_url:. Private repos (Pro/Team/Enterprise) serve at randomized
# <random>.pages.github.io/ subdomains without the /<repo>/ path prefix —
# absolute paths break, 404.html renders unstyled. Branch SITE_URL on
# repo visibility:
#   - private  -> empty site_url (mkdocs-material falls back to relative
#                paths in 404.html; confirmed mkdocs-material==9.5.49)
#   - public   -> existing https://<owner>.github.io/<repo>/ shape
# On gh unavailable / unauthenticated -> fall back to public (default
# behavior; operator manually flips site_url: "" if they hit the
# unstyled-404 symptom).
#
# Test escape hatch: GH_VISIBILITY_OVERRIDE=private|public bypasses gh
# for the verbatim test scaffold (tests/test-wiki-init-private-site-url.sh).
# Documented as test-only; do NOT promote to a CLI flag.
resolve_site_url_for_visibility() {
  # Inputs: $OWNER, $REPO, $SITE_URL (currently set to the public shape).
  # Output: mutates $SITE_URL in caller scope.
  if [ -n "${GH_VISIBILITY_OVERRIDE:-}" ]; then
    VISIBILITY="$GH_VISIBILITY_OVERRIDE"
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    VISIBILITY=$(gh api "repos/$OWNER/$REPO" --jq .visibility 2>/dev/null || echo "public")
    [ -n "$VISIBILITY" ] || VISIBILITY="public"
  else
    VISIBILITY="public"
    echo "wiki-init: gh unavailable / unauthenticated; assuming public visibility for site_url. If the repo is actually private and the 404 page renders unstyled, manually edit wiki/mkdocs.yml to set: site_url: \"\"" >&2
  fi
  if [ "$VISIBILITY" = "private" ]; then
    SITE_URL=""
    echo "wiki-init: FR-21 private repo detected; site_url set empty so 404.html uses relative asset paths"
  else
    echo "wiki-init: FR-21 public repo (or fallback); site_url=$SITE_URL preserved"
  fi
}

# FR-21 (M037/P02/T03) — branch SITE_URL on repo visibility
resolve_site_url_for_visibility

# FR-5 step (a): stage wiki tooling via P01 reader + mode handler.
# The bundle staging loop reuses the P01 read-project-assets / install-asset-mode helpers.
# Only the wiki-related project_assets entry is staged here (the four runtime dirs
# are P01's responsibility under install-{claude-code,codex,cursor}.sh).
TUPLES_FILE="$(mktemp -t wiki-init-tuples.XXXXXX)"
trap 'rm -f "$TUPLES_FILE"' EXIT

set +e
bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" >"$TUPLES_FILE"
read_rc=$?
set -e
if [ "$read_rc" -ne 0 ]; then
  echo "FAIL: wiki-init: read-project-assets.sh exited $read_rc" >&2
  exit 6
fi
if [ ! -s "$TUPLES_FILE" ]; then
  echo "FAIL: wiki-init: read-project-assets.sh emitted zero tuples; check $REPO_ROOT/packaging/bundle/manifest.yml for project_assets section" >&2
  exit 6
fi

# Build the project-assets target list (newline-separated) for collision-check arg 3.
TARGETS_LIST=""
while IFS= read -r tuple; do
  if [ -z "$tuple" ]; then
    continue
  fi
  tgt_field="$(printf '%s' "$tuple" | awk -F'\t' '{print $2}')"
  tgt_val="${tgt_field#target=}"
  if [ -z "$TARGETS_LIST" ]; then
    TARGETS_LIST="$tgt_val"
  else
    TARGETS_LIST="$TARGETS_LIST
$tgt_val"
  fi
done <"$TUPLES_FILE"

# Self-application detection: when REPO_ROOT == PROJECT_DIR, the bundle IS the target.
# In this dogfood path the staging step would either no-op (cp wiki/. wiki/) or trip
# the FR-22 collision-check operator-owned oracle (since wiki/ pre-exists in the
# orchestrator repo without an installed-files.txt entry). Skip the staging step
# entirely and proceed straight to sed-substitution on the in-place file.
SELF_APPLICATION=0
if [ "$REPO_ROOT" = "$PROJECT_DIR" ]; then
  SELF_APPLICATION=1
fi

# Idempotency / pre-staged short-circuit: skip bundle-staging when wiki/mkdocs.yml
# already exists at the target. Two cases hit this branch:
#   (a) Second `wiki-init` invocation (same identity values already match).
#   (b) `init --with-wiki` flow (FR-11): install-claude-code.sh / install-codex.sh /
#       install-cursor.sh have already staged wiki/ via the project_assets manifest
#       loop in their primary install step. By the time wiki-init runs as the
#       second sequential step under --with-wiki, wiki/ is on disk with bundle
#       defaults (placeholder mkdocs.yml). The collision-check would otherwise
#       trip on FR-22 operator-owned oracle (target exists, not in tracking
#       file, not gitignored). The substitute-templating step below handles
#       re-templating in both (a) and (b).
PRE_STAGE_NO_OP=0
PRE_STAGE_MKDOCS="$PROJECT_DIR/wiki/mkdocs.yml"
if [ -f "$PRE_STAGE_MKDOCS" ] && [ "$FORCE" != "1" ]; then
  PRE_STAGE_NO_OP=1
fi

# Iterate tuples — stage only entries whose source begins with 'wiki' under wiki-init's responsibility.
# (The four runtime-dir entries are staged by install-claude-code.sh / install-codex.sh / install-cursor.sh.)
if [ "$SELF_APPLICATION" -eq 0 ] && [ "$PRE_STAGE_NO_OP" -eq 0 ]; then
  while IFS= read -r tuple; do
    if [ -z "$tuple" ]; then
      continue
    fi
    src_field="$(printf '%s' "$tuple" | awk -F'\t' '{print $1}')"
    tgt_field="$(printf '%s' "$tuple" | awk -F'\t' '{print $2}')"
    mode_field="$(printf '%s' "$tuple" | awk -F'\t' '{print $3}')"
    src="${src_field#source=}"
    tgt="${tgt_field#target=}"
    mode="${mode_field#mode=}"
    case "$src" in
      wiki/|wiki) : ;;
      *) continue ;;
    esac
    src_abs="$REPO_ROOT/${src%/}"
    tgt_abs="$PROJECT_DIR/${tgt%/}"
    set +e
    bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" "$tgt_abs" "$PROJECT_DIR" "$TARGETS_LIST" >/dev/null
    coll_rc=$?
    set -e
    if [ "$coll_rc" -ne 0 ]; then
      echo "FAIL: wiki-init: collision-check rejected target $tgt_abs (rc=$coll_rc)" >&2
      exit 6
    fi
    set +e
    bash "$REPO_ROOT/scripts/lifecycle/install-asset-mode.sh" "$src_abs" "$tgt_abs" "$mode" "$PROJECT_DIR" >/dev/null
    mode_rc=$?
    set -e
    if [ "$mode_rc" -ne 0 ]; then
      echo "FAIL: wiki-init: install-asset-mode.sh rejected $src_abs -> $tgt_abs (rc=$mode_rc)" >&2
      exit 6
    fi
  done <"$TUPLES_FILE"
elif [ "$SELF_APPLICATION" -eq 1 ]; then
  echo "wiki-init: self-application detected (REPO_ROOT == PROJECT_DIR); skipping bundle stage"
else
  echo "wiki-init: target wiki/ already templated for ${OWNER}/${REPO}; skipping bundle stage"
fi

# FR-6: sed-substitute the four site-identity values in the staged mkdocs.yml.
# The substitution is idempotent against BOTH (a) {{...}} placeholders left over
# from the bundle template AND (b) already-resolved values from a prior run /
# bundle pull (so consumers pulling a bundle that already carries
# orchestrator-identity values get correctly re-templated against THEIR git
# remote). Field-line rewrite operates on the four known top-level YAML keys
# (site_name, site_description, site_url, repo_url) — preserves all surrounding
# content. The "no changes" idempotency branch fires only when the four target
# values would be byte-identical to what's already on disk.
MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"
if [ -f "$MKDOCS_TARGET" ]; then
  # M037 P01 T05 (FR-9): resolve default branch via CON-4 helper for the
  # edit_uri: substitution. Helper always exits 0 with a usable name.
  DEFAULT_BRANCH="$(bash "$REPO_ROOT/scripts/wiki/resolve-default-branch.sh" "$PROJECT_DIR")"
  EDIT_URI="edit/${DEFAULT_BRANCH}/wiki/docs/"

  # US-4 AS-4 edge case: when repo_url: is unset / placeholder, skip the
  # edit_uri: injection (no broken affordance) and emit a diagnostic. Detect
  # by grepping for a `^repo_url:` line whose value is empty, "{{...}}" stub,
  # or just whitespace.
  EDIT_URI_SKIP=0
  repo_url_line="$(grep -E '^repo_url:' "$MKDOCS_TARGET" | head -n 1 || true)"
  if [ -z "$repo_url_line" ]; then
    EDIT_URI_SKIP=1
  else
    repo_url_value="${repo_url_line#repo_url:}"
    # Trim leading whitespace + surrounding quotes.
    repo_url_value="$(printf '%s' "$repo_url_value" | sed -e 's/^[[:space:]]*//' -e 's/^"//' -e 's/"$//')"
    case "$repo_url_value" in
      ""|"{{"*"}}") EDIT_URI_SKIP=1 ;;
    esac
  fi
  if [ "$EDIT_URI_SKIP" -eq 1 ]; then
    echo "wiki-init: repo_url: is unset/placeholder in $MKDOCS_TARGET; skipping edit_uri: injection (set repo_url: to enable the wiki Edit/View action affordances)" >&2
  fi

  # Compute target lines with the to-be-applied values.
  desired_site_name='site_name: "'"$SITE_NAME"'"'
  desired_site_description='site_description: "'"$SITE_DESCRIPTION"'"'
  desired_site_url='site_url: "'"$SITE_URL"'"'
  desired_repo_url='repo_url: "'"$REPO_URL"'"'
  desired_edit_uri='edit_uri: "'"$EDIT_URI"'"'

  # Detect whether all five lines already match desired values exactly (idempotent no-op).
  # When EDIT_URI_SKIP=1, the desired_edit_uri is not enforced — the threshold
  # falls back to 4 to preserve idempotency on operator-unconfigured remotes.
  match_count=0
  if grep -qxF "$desired_site_name" "$MKDOCS_TARGET"; then
    match_count=$((match_count + 1))
  fi
  if grep -qxF "$desired_site_description" "$MKDOCS_TARGET"; then
    match_count=$((match_count + 1))
  fi
  if grep -qxF "$desired_site_url" "$MKDOCS_TARGET"; then
    match_count=$((match_count + 1))
  fi
  if grep -qxF "$desired_repo_url" "$MKDOCS_TARGET"; then
    match_count=$((match_count + 1))
  fi
  if [ "$EDIT_URI_SKIP" -eq 0 ] && grep -qxF "$desired_edit_uri" "$MKDOCS_TARGET"; then
    match_count=$((match_count + 1))
  fi

  required_matches=5
  if [ "$EDIT_URI_SKIP" -eq 1 ]; then
    required_matches=4
  fi

  if [ "$match_count" -eq "$required_matches" ] && [ "$FORCE" != "1" ]; then
    echo "wiki-init: no changes (mkdocs.yml site-identity values already match)"
  else
    # Field-line rewrite: replace the entire `^<field>: ...` line with the desired
    # value. Use sed delimiter '|' since URLs contain forward slashes.
    # Escape backslashes, ampersands, and pipes in the replacement text since
    # those are sed-special. Bash 3.2 safe.
    escape_sed() {
      printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
    }
    s_name="$(escape_sed "$SITE_NAME")"
    s_desc="$(escape_sed "$SITE_DESCRIPTION")"
    s_url="$(escape_sed "$SITE_URL")"
    s_repo="$(escape_sed "$REPO_URL")"
    s_edit_uri="$(escape_sed "$EDIT_URI")"

    tmp="$(mktemp -t wiki-init-mkdocs.XXXXXX)"
    if [ "$EDIT_URI_SKIP" -eq 0 ]; then
      sed \
        -e "s|^site_name:.*|site_name: \"${s_name}\"|" \
        -e "s|^site_description:.*|site_description: \"${s_desc}\"|" \
        -e "s|^site_url:.*|site_url: \"${s_url}\"|" \
        -e "s|^repo_url:.*|repo_url: \"${s_repo}\"|" \
        -e "s|^edit_uri:.*|edit_uri: \"${s_edit_uri}\"|" \
        "$MKDOCS_TARGET" > "$tmp"
    else
      sed \
        -e "s|^site_name:.*|site_name: \"${s_name}\"|" \
        -e "s|^site_description:.*|site_description: \"${s_desc}\"|" \
        -e "s|^site_url:.*|site_url: \"${s_url}\"|" \
        -e "s|^repo_url:.*|repo_url: \"${s_repo}\"|" \
        "$MKDOCS_TARGET" > "$tmp"
    fi
    mv "$tmp" "$MKDOCS_TARGET"
    if [ "$EDIT_URI_SKIP" -eq 0 ]; then
      echo "wiki-init: substituted site_name=${SITE_NAME} site_url=${SITE_URL} repo_url=${REPO_URL} edit_uri=${EDIT_URI} in $MKDOCS_TARGET"
    else
      echo "wiki-init: substituted site_name=${SITE_NAME} site_url=${SITE_URL} repo_url=${REPO_URL} in $MKDOCS_TARGET (edit_uri skipped — repo_url unset/placeholder)"
    fi
  fi

  # M037 P01 T06 (FR-10/CON-3/MIT-03 P0) — yaml-merge against bundle mkdocs.yml.
  # After the sed-substitution rewrites the five sed-managed scalars
  # (site_name/site_description/site_url/repo_url/edit_uri), invoke the shared
  # yaml-merge primitive to preserve any operator-authored top-level keys
  # outside the framework's managed list (e.g., custom analytics: blocks),
  # AND to merge new framework-managed block content into the operator's
  # mkdocs.yml on subsequent refresh paths (e.g., new T05 polish-bundle
  # markdown_extensions added since the operator's last init).
  #
  # Managed-namespace divergence from T06 plan §149-160: the sed-substituted
  # scalars (site_name/site_description/site_url/repo_url/edit_uri) are NOT
  # listed here because those keys are project-derived by sed above; passing
  # them to yaml-merge would replace the consumer's just-substituted values
  # with the bundle's stale dogfood values. extra_css IS listed (T04 added the
  # framework-controlled code-chip CSS declaration; the plan table predated T04
  # — see T06-SUMMARY.md "extra_css addendum" for the namespace-classification
  # rationale).
  BUNDLE_MKDOCS="$REPO_ROOT/wiki/mkdocs.yml"
  YAML_MERGE="$REPO_ROOT/scripts/lib/yaml-merge.sh"
  MKDOCS_MANAGED="docs_dir,site_dir,theme,plugins,markdown_extensions,extra_css,nav"
  if [ -f "$BUNDLE_MKDOCS" ] && [ -f "$YAML_MERGE" ] && [ "$BUNDLE_MKDOCS" != "$MKDOCS_TARGET" ]; then
    # M040 follow-up (2026-05-09): capture the operator-authored content
    # between the `# >>> custom-nav` / `# <<< custom-nav end` markers
    # before yaml-merge overwrites the `nav:` namespace. The bundle's
    # mkdocs.yml carries an empty custom-nav region; without this
    # capture-restore wrapper, yaml-merge silently erases operator nav
    # entries on every refresh. Surfaced in PBJ-central 2026-05-09 (one
    # `- How to review this wiki: sme-review-guide.md` line dropped).
    # See specs/040-wiki-readability-decorator/spec.md FR-28.
    CUSTOM_NAV_CAPTURED="$(mktemp -t wiki-init-custom-nav.XXXXXX)"
    awk '
      BEGIN { state="pre" }
      {
        if (state == "pre") { if ($0 == "# >>> custom-nav") { state="in" }; next }
        if (state == "in")  { if ($0 == "# <<< custom-nav end") { state="post"; next }; print; next }
      }
    ' "$MKDOCS_TARGET" > "$CUSTOM_NAV_CAPTURED" 2>/dev/null || true

    set +e
    bash "$YAML_MERGE" merge --target "$MKDOCS_TARGET" --framework-default "$BUNDLE_MKDOCS" --managed-namespaces "$MKDOCS_MANAGED"
    merge_rc=$?
    set -e
    if [ "$merge_rc" -ne 0 ]; then
      echo "FAIL: wiki-init: yaml-merge against $MKDOCS_TARGET exited $merge_rc" >&2
      rm -f "$CUSTOM_NAV_CAPTURED"
      exit 6
    fi
    echo "wiki-init: yaml-merge applied to $MKDOCS_TARGET (managed=${MKDOCS_MANAGED})"

    # Restore captured custom-nav content. If capture is empty (no markers
    # in target, or markers present but body empty), the awk pass is a
    # structural no-op. Marker pair contract: edits between markers
    # preserved byte-for-byte; structurally identical to the
    # managed-gitignore emitter's preserve-outside-block convention,
    # inverted to preserve-inside-block.
    if [ -s "$CUSTOM_NAV_CAPTURED" ]; then
      tmp_restore="$(mktemp -t wiki-init-custom-nav-restore.XXXXXX)"
      awk -v src="$CUSTOM_NAV_CAPTURED" '
        BEGIN { state="pre" }
        {
          if (state == "pre") {
            print
            if ($0 == "# >>> custom-nav") {
              state="in"
              while ((getline line < src) > 0) print line
              close(src)
            }
            next
          }
          if (state == "in") {
            if ($0 == "# <<< custom-nav end") { print; state="post"; next }
            next
          }
          print
        }
      ' "$MKDOCS_TARGET" > "$tmp_restore"
      mv "$tmp_restore" "$MKDOCS_TARGET"
      echo "wiki-init: restored custom-nav region in $MKDOCS_TARGET (preserved $(wc -l < "$CUSTOM_NAV_CAPTURED" | tr -d ' ') lines)"
    fi
    rm -f "$CUSTOM_NAV_CAPTURED"
  fi
fi

# ---- FR-19 (M037/P02/T02) — GitHub Pages workflow scaffold ---------------
# Emit .github/workflows/pages.yml with the verbatim four-component shape
# from papercut-handoff-wiki-publishing-robustness-2026-05-07.md (PBJ-central
# commit e7a722e). CON-3: pre-existing operator-authored workflow → diagnostic
# + no clobber, no per-key merge. Whole-file managed.
emit_pages_workflow() {
  PAGES_WF_TARGET="$PROJECT_DIR/.github/workflows/pages.yml"
  if [ -f "$PAGES_WF_TARGET" ]; then
    echo "wiki-init: .github/workflows/pages.yml already present at $PAGES_WF_TARGET — preserving operator-authored workflow (CON-3); reference impl in $REPO_ROOT/.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md if reconciliation desired. Consider adding 'bash scripts/diagnostics/wiki-stubs-fresh.sh --root .' as a pre-build step (see papercut-wiki-stub-drift.md Layer 1)" >&2
    return 0
  fi
  mkdir -p "$(dirname "$PAGES_WF_TARGET")"
  cat > "$PAGES_WF_TARGET" <<'PAGES_WORKFLOW_EOF'
name: Deploy wiki to Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: wiki/requirements.txt
      - run: pip install -r wiki/requirements.txt
      - name: Check wiki stubs are fresh (no drift vs .orchestrator/)
        run: |
          if [ -x scripts/diagnostics/wiki-stubs-fresh.sh ]; then
            bash scripts/diagnostics/wiki-stubs-fresh.sh
          else
            echo "wiki-stubs-fresh: scripts/diagnostics/wiki-stubs-fresh.sh not present -- skipping (older orchestrator runtime)"
          fi
      - name: Materialize wiki/.staged/ via decorator (or verbatim fallback)
        # Stubs include from wiki/.staged/ (managed-gitignored); regenerate it
        # from .orchestrator/ source before mkdocs build, otherwise
        # include-markdown directives will fail on missing files.
        #
        # CI runtime posture (M040 spec amendment, Option B): the framework's
        # managed-gitignore excludes scripts/ — so consumer-project CI
        # checkouts (`actions/checkout@v4`) never have the decorator script.
        # This step gracefully degrades to a verbatim mirror of .orchestrator/
        # into wiki/.staged/ so mkdocs build can resolve the rewritten include
        # directives. CI deploys therefore ship stub-baked admonitions but
        # NOT body-text hyperlink decoration (codes/§-refs/paths/milestone
        # names render as plain text). Local previews retain full decoration.
        # Upgrade path: post-M035, switch to install-at-CI-time once the
        # framework's install endpoint is published.
        run: |
          if [ -f scripts/wiki/wiki-decorate-build.py ]; then
            python3 scripts/wiki/wiki-decorate-build.py --force
          else
            echo "wiki-decorate-build: scripts/wiki/wiki-decorate-build.py not present in CI checkout -- mirroring .orchestrator/ verbatim into wiki/.staged/ (admonitions-only fallback per M040 Option B)"
            mkdir -p wiki/.staged
            for d in memory spec decisions knowledge milestones proposals; do
              if [ -d ".orchestrator/$d" ]; then
                cp -R ".orchestrator/$d" "wiki/.staged/"
              fi
            done
            for f in DECISIONS.md KNOWLEDGE.md milestone-summary.md spikes-registry.md; do
              if [ -f ".orchestrator/$f" ]; then
                cp ".orchestrator/$f" "wiki/.staged/"
              fi
            done
          fi
      - run: mkdocs build -f wiki/mkdocs.yml
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: wiki/site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
PAGES_WORKFLOW_EOF
  echo "wiki-init: emitted $PAGES_WF_TARGET (build_type=workflow scaffold per FR-19)"
}

# ---- FR-19 (M037/P02/T02) — flip Pages config to build_type=workflow -----
# After the workflow file is emitted, set the repo's Pages build_type to
# workflow so the deploy-pages action can publish. Idempotent — flipping
# an already-workflow repo is a no-op upstream. Manual-fallback diagnostic
# surfaces the verbatim command on `gh` unavailable / unauthenticated.
flip_pages_build_type() {
  [ -n "${OWNER:-}" ] || return 0
  [ -n "${REPO:-}" ] || return 0
  if ! command -v gh >/dev/null 2>&1; then
    echo "wiki-init: gh CLI not on PATH; skipping FR-19 build_type flip. Run manually after install:" >&2
    echo "    gh api -X PUT \"repos/$OWNER/$REPO/pages\" -f build_type=workflow" >&2
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "wiki-init: gh not authenticated; skipping FR-19 build_type flip. Run manually after gh auth login:" >&2
    echo "    gh api -X PUT \"repos/$OWNER/$REPO/pages\" -f build_type=workflow" >&2
    return 0
  fi
  if gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow >/dev/null 2>&1; then
    echo "wiki-init: FR-19 build_type=workflow set on repos/$OWNER/$REPO/pages"
  else
    _flip_rc=$?
    echo "wiki-init: gh api -X PUT repos/$OWNER/$REPO/pages -f build_type=workflow exited $_flip_rc; run manually if needed" >&2
  fi
}

# FR-19 (M037/P02/T02) — workflow-based Pages publishing scaffold.
# Wired here AFTER mkdocs.yml is finalized and BEFORE the --deploy block.
# The workflow file emit honors CON-3 (no-clobber on pre-existing path);
# the build_type flip is gated on gh availability/auth and surfaces a
# manual-fallback diagnostic on either skip path.
emit_pages_workflow
flip_pages_build_type

# FR-15 path-convention stub: author wiki/glossary.md if absent.
#
# M037 P03 (P1.4): when the project carries a real glossary at
# .orchestrator/knowledge/glossary.md, write wiki/glossary.md as a thin
# include-markdown wrapper sourcing from that authoritative copy. The
# wiki/docs/glossary.md stub (written by wiki-generate-stubs.sh top:glossary
# routing) then resolves through the nested include chain, surfacing real
# glossary content instead of the empty "Example Term" placeholder.
#
# Idempotency: prior wiki-init runs may have authored the empty FR-15 stub
# at wiki/glossary.md before .orchestrator/knowledge/glossary.md existed.
# Detect that exact stub shape (≤20 lines + verbatim "### Example Term"
# sentinel) and replace it in place — operator-edited glossaries are
# preserved unchanged.
GLOSSARY_TARGET="$PROJECT_DIR/wiki/glossary.md"
GLOSSARY_PROJECT_SRC="$PROJECT_DIR/.orchestrator/knowledge/glossary.md"
glossary_is_empty_stub() {
  _g="$1"
  [ -f "$_g" ] || return 1
  _lines=$(wc -l < "$_g" | tr -d ' ')
  if [ "$_lines" -le 20 ] && grep -q '^### Example Term' "$_g" 2>/dev/null; then
    return 0
  fi
  return 1
}
write_glossary_include_wrapper() {
  cat > "$GLOSSARY_TARGET" <<'GLOSSARYEOF'
# Glossary

<!-- Auto-generated by wiki-init.sh — sourced from .orchestrator/knowledge/glossary.md.
     Edit the source-of-truth file, not this wrapper. -->

{%
  include-markdown "../.orchestrator/knowledge/glossary.md"
  rewrite-relative-urls=false
%}
GLOSSARYEOF
}
write_glossary_empty_stub() {
  cat > "$GLOSSARY_TARGET" <<'GLOSSARYEOF'
# Glossary

Project glossary — alphabetized term entries with one-line definitions
and at most a two-line elaboration. M033's grilling protocol writes inline
into this file as terms resolve.

### Example Term

A one-line definition demonstrating the format invariant.

A two-line elaboration expanding on the definition, no longer than this paragraph.
GLOSSARYEOF
}
mkdir -p "$(dirname "$GLOSSARY_TARGET")"
if [ ! -f "$GLOSSARY_TARGET" ]; then
  if [ -f "$GLOSSARY_PROJECT_SRC" ]; then
    write_glossary_include_wrapper
    echo "wiki-init: authored glossary include-wrapper at $GLOSSARY_TARGET (source: .orchestrator/knowledge/glossary.md)"
  else
    write_glossary_empty_stub
    echo "wiki-init: authored glossary stub at $GLOSSARY_TARGET"
  fi
elif [ -f "$GLOSSARY_PROJECT_SRC" ] && glossary_is_empty_stub "$GLOSSARY_TARGET"; then
  # Project glossary appeared after a prior wiki-init wrote the empty
  # stub. Replace the stub with the include wrapper in place — covers
  # the common upgrade path where M037 P03 lands after M033 onboarding
  # has already populated .orchestrator/knowledge/glossary.md.
  write_glossary_include_wrapper
  echo "wiki-init: replaced empty glossary stub at $GLOSSARY_TARGET with include-wrapper (source: .orchestrator/knowledge/glossary.md)"
fi

# PBJ-2026-05-08: Spikes registry template. Seeded into the consumer project's
# .orchestrator/spikes-registry.md on first wiki-init when absent. Operators
# author the registry; the wiki-generate-stubs.sh top:spikes routing projects
# it onto wiki/docs/spikes/index.md and wiki-generate-nav.sh emits a Spikes
# top-level nav leaf. Idempotent — never overwrites an existing file. Skipped
# in self-application mode (the orchestrator source repo doesn't dogfood a
# spikes registry against itself).
SPIKES_TARGET="$PROJECT_DIR/.orchestrator/spikes-registry.md"
if [ "$SELF_APPLICATION" -eq 0 ] && [ ! -f "$SPIKES_TARGET" ]; then
  mkdir -p "$(dirname "$SPIKES_TARGET")"
  cat > "$SPIKES_TARGET" <<'SPIKESEOF'
# Spikes Registry

Discovery / unblocking spikes for this project. A spike is a time-boxed
investigation whose deliverable is **clarity** (a decision, a verified
constraint, a discarded option) rather than shipped product code. Once a
spike's exit criteria are met, file the resulting decisions/learnings into
`.orchestrator/DECISIONS.md` or the relevant milestone artifact and mark the
spike `closed`.

This file is operator-authored. The orchestrator's wiki tooling projects it
onto `wiki/docs/spikes/index.md` so SMEs can review the registry alongside
the rest of the project's knowledge graph.

## Status legend

| Status | Meaning |
|--------|---------|
| `active` | Spike is currently being worked. |
| `queued` | Spike is named and scoped but not yet staffed. |
| `named-not-staffed` | Spike is acknowledged in planning but no owner yet. |
| `closed` | Exit criteria met; learnings filed. |
| `blocked` | Spike paused on an external dependency (note the dependency). |

## Registry

| ID | Name | Status | Owner | Parent | Scope / exit criteria | Related DRs / gates | Notes |
|----|------|--------|-------|--------|-----------------------|---------------------|-------|
| `SPIKE-EXAMPLE-001` | Example: replace this row | `closed` | TBD | — | One-line statement of what closing the spike looks like (decision, verified constraint, discarded option). | DR-EXAMPLE-001 | Free-form notes — multi-path spikes can spell out each path here, or break out subsections below the table. |

<!-- Optional per-spike subsections for spikes whose Notes need more than one
     row. Pattern:

## SPIKE-XYZ-NNN — Name

**Status**: active · **Owner**: TBD · **Parent**: M### · **Opened**: YYYY-MM-DD

**Scope** — one paragraph.

**Path A** — first investigation track.

**Path B** — second investigation track (if any).

**Exit criteria** — bulleted list of what closing looks like. -->
SPIKESEOF
  echo "wiki-init: seeded spikes registry template at $SPIKES_TARGET (operator-authored — edit to populate)"
fi

# M037 P03 round-4 — framework-managed wiki/overrides/ refresh.
#
# Round-3.5 introduced wiki/overrides/main.html (P3.1 breadcrumb shim) and
# updated wiki/overrides/partials/comments.html (P3.2 file-feedback aside +
# M032 dual-template surface). Neither install path stages wiki/overrides/
# content into existing projects:
#   - install-claude-code.sh trips the operator-owned oracle on wiki/ when
#     a project already has a wiki/ tree.
#   - wiki-init.sh's PRE_STAGE_NO_OP short-circuits when wiki/mkdocs.yml
#     exists, skipping the bundle stage.
# This step mirrors framework-managed *.html files from the bundle into
# <PROJECT_DIR>/wiki/overrides/ on every wiki-init invocation, with
# operator-edit-detection: write <f>.bundle.new + WARN rather than clobber
# when the project file diverges in ways we don't recognize.
#
# Special case: wiki/overrides/partials/comments.html. When --with-giscus
# was previously run, the project copy has the four {{giscus_*}} placeholders
# substituted with concrete IDs but the dual-template Jinja form intact.
# Detect that "substituted-managed" shape (no {{giscus_repo}} placeholder AND
# {{ config.extra.giscus.repo }} present) and re-stage from bundle, then
# re-substitute against the GISCUS_* values persisted to <PROJECT_DIR>/.env
# by --with-giscus (papercut-wiki-deploy-env-loader managed marker block).
# Makes refresh idempotent on substituted-managed projects so dogfood loops
# pick up new bundle features without a manual --with-giscus rerun.
BUNDLE_OVERRIDES_DIR="$REPO_ROOT/wiki/overrides"
PROJECT_OVERRIDES_DIR="$PROJECT_DIR/wiki/overrides"
if [ -d "$BUNDLE_OVERRIDES_DIR" ] && [ "$REPO_ROOT" != "$PROJECT_DIR" ]; then
  # Load any persisted GISCUS_* values from <PROJECT_DIR>/.env so we can
  # re-substitute comments.html transparently when refreshing a project
  # that previously ran --with-giscus.
  GISCUS_REPO_ENV=""
  GISCUS_REPO_ID_ENV=""
  GISCUS_CATEGORY_ENV=""
  GISCUS_CATEGORY_ID_ENV=""
  if [ -f "$PROJECT_DIR/.env" ]; then
    GISCUS_REPO_ENV=$(awk -F'"' '/^export GISCUS_REPO=/ { print $2; exit }' "$PROJECT_DIR/.env" 2>/dev/null || true)
    GISCUS_REPO_ID_ENV=$(awk -F'"' '/^export GISCUS_REPO_ID=/ { print $2; exit }' "$PROJECT_DIR/.env" 2>/dev/null || true)
    GISCUS_CATEGORY_ENV=$(awk -F'"' '/^export GISCUS_CATEGORY=/ { print $2; exit }' "$PROJECT_DIR/.env" 2>/dev/null || true)
    GISCUS_CATEGORY_ID_ENV=$(awk -F'"' '/^export GISCUS_CATEGORY_ID=/ { print $2; exit }' "$PROJECT_DIR/.env" 2>/dev/null || true)
  fi

  override_sed_escape() {
    printf '%s' "$1" | sed -e 's|[\\&|]|\\&|g'
  }

  apply_giscus_substitution() {
    # Args: $1=target file. Mutates target in place.
    [ -n "$GISCUS_REPO_ENV" ] || return 1
    [ -n "$GISCUS_REPO_ID_ENV" ] || return 1
    [ -n "$GISCUS_CATEGORY_ENV" ] || return 1
    [ -n "$GISCUS_CATEGORY_ID_ENV" ] || return 1
    _gr=$(override_sed_escape "$GISCUS_REPO_ENV")
    _gri=$(override_sed_escape "$GISCUS_REPO_ID_ENV")
    _gc=$(override_sed_escape "$GISCUS_CATEGORY_ENV")
    _gci=$(override_sed_escape "$GISCUS_CATEGORY_ID_ENV")
    _tmp=$(mktemp -t comments.html.refresh.XXXXXX)
    sed \
      -e "s|{{giscus_repo}}|$_gr|g" \
      -e "s|{{giscus_repo_id}}|$_gri|g" \
      -e "s|{{giscus_category}}|$_gc|g" \
      -e "s|{{giscus_category_id}}|$_gci|g" \
      "$1" > "$_tmp"
    mv "$_tmp" "$1"
    return 0
  }

  # Walk all .html files under bundle wiki/overrides/. The find pipe runs the
  # while loop in a subshell — that's fine; we only emit diagnostics and write
  # files, no state needs to escape.
  find "$BUNDLE_OVERRIDES_DIR" -type f -name '*.html' | while IFS= read -r _bundle_file; do
    _rel="${_bundle_file#$BUNDLE_OVERRIDES_DIR/}"
    _proj_file="$PROJECT_OVERRIDES_DIR/$_rel"
    mkdir -p "$(dirname "$_proj_file")"

    if [ ! -f "$_proj_file" ]; then
      cp "$_bundle_file" "$_proj_file"
      echo "wiki-init: staged framework override $_proj_file"
      continue
    fi

    if cmp -s "$_bundle_file" "$_proj_file"; then
      continue
    fi

    # Files differ. Detect the substituted-managed comments.html shape:
    # placeholder {{giscus_repo}} absent AND Jinja {{ config.extra.giscus.repo }}
    # present. That shape can only have been produced by a prior --with-giscus
    # run; safe to re-stage + re-substitute.
    _is_subbed_comments=0
    case "$_rel" in
      partials/comments.html)
        if ! grep -q '{{giscus_repo}}' "$_proj_file" 2>/dev/null \
           && grep -q '{{ config.extra.giscus.repo }}' "$_proj_file" 2>/dev/null; then
          _is_subbed_comments=1
        fi
        ;;
    esac

    if [ "$_is_subbed_comments" -eq 1 ]; then
      cp "$_bundle_file" "$_proj_file"
      if apply_giscus_substitution "$_proj_file"; then
        echo "wiki-init: refreshed $_proj_file from bundle and re-substituted GISCUS_* from $PROJECT_DIR/.env"
      else
        echo "wiki-init: refreshed $_proj_file from bundle (no GISCUS_* in .env to re-substitute; rerun with --with-giscus if needed)"
      fi
      continue
    fi

    # Operator-edited or unrecognized divergence — write .bundle.new + warn.
    cp "$_bundle_file" "$_proj_file.bundle.new"
    echo "WARN: wiki-init: $_proj_file diverges from bundle; wrote $_proj_file.bundle.new for review (delete the project file and re-run wiki-init to take the bundle copy)" >&2
  done
fi

# FR-12 #Q-2: --auto-pip opt-in runs pip install; default is print-and-exit.
REQ_FILE="$PROJECT_DIR/wiki/requirements.txt"
if [ -f "$REQ_FILE" ]; then
  if [ "$AUTO_PIP" = "1" ]; then
    set +e
    pip3 install -r "$REQ_FILE"
    pip_rc=$?
    set -e
    if [ "$pip_rc" -ne 0 ]; then
      echo "FAIL: wiki-init: pip3 install -r $REQ_FILE failed (rc=$pip_rc)" >&2
      exit 6
    fi
  else
    echo "wiki-init: Python deps not installed. Run 'pip3 install -r $REQ_FILE' or re-invoke with --auto-pip"
  fi
fi

# FR-8 --with-giscus scope: substitute the four {{giscus_*}} placeholder tokens
# in <PROJECT_DIR>/wiki/overrides/partials/comments.html against IDs fetched
# from giscus-ids-from-gh.sh (or M032_GISCUS_IDS_FROM_GH_STUB stub mode).
if [ "$WITH_GISCUS" = "1" ]; then
  if [ -z "$GISCUS_REPO_FLAG" ] || [ -z "$GISCUS_CATEGORY_FLAG" ]; then
    echo "FAIL: wiki-init: --with-giscus requires both --repo <owner>/<repo> and --category <name>" >&2
    exit 2
  fi
  PARTIAL="$PROJECT_DIR/wiki/overrides/partials/comments.html"
  if [ ! -f "$PARTIAL" ]; then
    echo "FAIL: wiki-init: --with-giscus requires --with-wiki to have been run first; missing $PARTIAL" >&2
    exit 7
  fi

  # Test-only stub mode envelope per the M026/MEM030 <TOOL>_<NAME> env-var convention.
  IDS_OUT=""
  ids_rc=0
  case "${M032_GISCUS_IDS_FROM_GH_STUB:-}" in
    1)
      # Deterministic fixture IDs — do not reach the network.
      IDS_OUT=$(printf 'export GISCUS_REPO="%s"\nexport GISCUS_REPO_ID="R_kgDOFixture"\nexport GISCUS_CATEGORY="%s"\nexport GISCUS_CATEGORY_ID="DIC_kwDOFixture"\n' "$GISCUS_REPO_FLAG" "$GISCUS_CATEGORY_FLAG")
      ids_rc=0
      ;;
    fail)
      echo "FAIL: wiki-init: integration-giscus-config-failed: M032_GISCUS_IDS_FROM_GH_STUB=fail (forced failure injection)" >&2
      exit 8
      ;;
    *)
      # Live path — invoke the real helper.
      set +e
      IDS_OUT="$(bash "$REPO_ROOT/scripts/diagnostics/giscus-ids-from-gh.sh" --repo "$GISCUS_REPO_FLAG" --category "$GISCUS_CATEGORY_FLAG" 2>&1)"
      ids_rc=$?
      set -e
      if [ "$ids_rc" -ne 0 ]; then
        echo "FAIL: wiki-init: integration-giscus-config-failed: giscus-ids-from-gh.sh exited $ids_rc — $IDS_OUT" >&2
        exit 8
      fi
      ;;
  esac

  # Parse the four export lines into shell variables.
  GISCUS_REPO_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO="\(.*\)"$/\1/p')
  GISCUS_REPO_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO_ID="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY_ID="\(.*\)"$/\1/p')
  if [ -z "$GISCUS_REPO_VAL" ] || [ -z "$GISCUS_REPO_ID_VAL" ] || [ -z "$GISCUS_CATEGORY_VAL" ] || [ -z "$GISCUS_CATEGORY_ID_VAL" ]; then
    echo "FAIL: wiki-init: integration-giscus-config-failed: could not parse all four GISCUS_* exports from helper output" >&2
    exit 8
  fi

  # Sed-substitute the four {{giscus_*}} placeholders. Use | as the sed
  # delimiter (none of the values contain |); escape \, &, and | in values
  # for sed-replacement-safety. Bash 3.2 sed-in-place: BSD sed requires
  # `-i ''`, GNU sed accepts `-i`. Use a temp-file rename pattern to avoid
  # the difference.
  TMP_PARTIAL="$(mktemp -t comments.html.XXXXXX)"
  trap 'rm -f "$TMP_PARTIAL" "$TUPLES_FILE"' EXIT
  sed_escape() { printf '%s' "$1" | sed -e 's|[\\&|]|\\&|g'; }
  GR_E=$(sed_escape "$GISCUS_REPO_VAL")
  GRI_E=$(sed_escape "$GISCUS_REPO_ID_VAL")
  GC_E=$(sed_escape "$GISCUS_CATEGORY_VAL")
  GCI_E=$(sed_escape "$GISCUS_CATEGORY_ID_VAL")
  sed \
    -e "s|{{giscus_repo}}|$GR_E|g" \
    -e "s|{{giscus_repo_id}}|$GRI_E|g" \
    -e "s|{{giscus_category}}|$GC_E|g" \
    -e "s|{{giscus_category_id}}|$GCI_E|g" \
    "$PARTIAL" > "$TMP_PARTIAL"
  cp "$TMP_PARTIAL" "$PARTIAL"
  rm -f "$TMP_PARTIAL"
  trap 'rm -f "$TUPLES_FILE"' EXIT

  # FR-8 post-step verifier — wiki-giscus-config-check.sh asserts the four
  # GISCUS_* env vars are non-empty. Export them from the values we just
  # substituted so the verifier sees a populated environment.
  set +e
  GISCUS_REPO="$GISCUS_REPO_VAL" \
  GISCUS_REPO_ID="$GISCUS_REPO_ID_VAL" \
  GISCUS_CATEGORY="$GISCUS_CATEGORY_VAL" \
  GISCUS_CATEGORY_ID="$GISCUS_CATEGORY_ID_VAL" \
    bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --quiet
  check_rc=$?
  set -e
  if [ "$check_rc" -ne 0 ]; then
    echo "FAIL: wiki-init: integration-giscus-config-check-failed: wiki-giscus-config-check.sh exited $check_rc against $PROJECT_DIR" >&2
    exit 9
  fi

  # Layer 2 of the operator-secrets-and-adaptive-init pre-launch slice
  # (.orchestrator/proposals/papercut-wiki-deploy-env-loader.md): persist
  # the four GISCUS_* values to <PROJECT_DIR>/.env under a managed marker
  # block so wiki-deploy.sh's Layer 1 .env loader can find them on
  # subsequent invocations. Idempotent — re-runs replace the existing
  # marker block in place.
  ENV_FILE="$PROJECT_DIR/.env"
  ENV_TMP="$(mktemp -t orchestrator-env.XXXXXX)"
  ENV_MARK_START="# >>> orchestrator-managed: giscus >>>"
  ENV_MARK_END="# <<< orchestrator-managed: giscus <<<"
  if [ -f "$ENV_FILE" ]; then
    awk -v s="$ENV_MARK_START" -v e="$ENV_MARK_END" '
      BEGIN { skip = 0 }
      $0 == s { skip = 1; next }
      $0 == e { skip = 0; next }
      skip == 0 { print }
    ' "$ENV_FILE" > "$ENV_TMP"
  else
    : > "$ENV_TMP"
  fi
  {
    printf '%s\n' "$ENV_MARK_START"
    printf 'export GISCUS_REPO="%s"\n' "$GISCUS_REPO_VAL"
    printf 'export GISCUS_REPO_ID="%s"\n' "$GISCUS_REPO_ID_VAL"
    printf 'export GISCUS_CATEGORY="%s"\n' "$GISCUS_CATEGORY_VAL"
    printf 'export GISCUS_CATEGORY_ID="%s"\n' "$GISCUS_CATEGORY_ID_VAL"
    printf '%s\n' "$ENV_MARK_END"
  } >> "$ENV_TMP"
  mv "$ENV_TMP" "$ENV_FILE"
  chmod 600 "$ENV_FILE" 2>/dev/null || true

  # .gitignore hygiene: warn-don't-block if <PROJECT_DIR>/.gitignore
  # does not list .env. The orchestrator's own root .gitignore already
  # ignores .env; consumer projects that don't yet would commit
  # secrets if not warned. Stay non-blocking — this is paper-cut
  # scope, not a constitutional gate.
  GITIGNORE_FILE="$PROJECT_DIR/.gitignore"
  ENV_GITIGNORED=0
  if [ -f "$GITIGNORE_FILE" ]; then
    if grep -qE '^\.env([[:space:]]|$|/|\*)' "$GITIGNORE_FILE"; then
      ENV_GITIGNORED=1
    fi
  fi
  if [ "$ENV_GITIGNORED" -eq 0 ]; then
    echo "WARN: wiki-init: $ENV_FILE contains operator secrets but is not gitignored — add '.env' to $GITIGNORE_FILE before committing" >&2
  fi

  echo "wiki-init: --with-giscus done — substituted four giscus IDs in $PARTIAL; persisted to $ENV_FILE under managed marker block"
fi

# M037 P03 (P1.3) — regenerate stubs + nav as a final step BEFORE --deploy.
#
# The bundled wiki/mkdocs.yml ships with upstream's literal nav block (which
# references the orchestrator's own M030+/proposals/* tree). Without this
# step, a staged-into-project install would render the orchestrator's nav
# instead of the project's. wiki-generate-stubs.sh writes wiki/docs/<...>.md
# from .orchestrator/ artifacts; wiki-generate-nav.sh then rebuilds the
# nav: block in wiki/mkdocs.yml between its auto-nav markers, projecting
# `version:` frontmatter to human nav titles. Both are idempotent.
#
# Both scripts must resolve relative to PROJECT_DIR (where the project's
# .orchestrator/ + wiki/ live), not REPO_ROOT (the bundle source). They are
# installed into PROJECT_DIR/scripts/wiki/ by the bundle stage.
WIKI_REGEN_STUBS="$PROJECT_DIR/scripts/wiki/wiki-generate-stubs.sh"
WIKI_REGEN_NAV="$PROJECT_DIR/scripts/wiki/wiki-generate-nav.sh"
# Self-application: when REPO_ROOT == PROJECT_DIR (orchestrator dogfooding
# itself), the staging step short-circuits and the scripts are NOT staged
# under PROJECT_DIR/scripts/wiki/. Resolve from REPO_ROOT in that case.
if [ ! -f "$WIKI_REGEN_STUBS" ]; then
  WIKI_REGEN_STUBS="$REPO_ROOT/scripts/wiki/wiki-generate-stubs.sh"
fi
if [ ! -f "$WIKI_REGEN_NAV" ]; then
  WIKI_REGEN_NAV="$REPO_ROOT/scripts/wiki/wiki-generate-nav.sh"
fi
if [ -f "$WIKI_REGEN_STUBS" ]; then
  set +e
  bash "$WIKI_REGEN_STUBS" --root "$PROJECT_DIR"
  _stubs_rc=$?
  set -e
  if [ "$_stubs_rc" -ne 0 ]; then
    echo "WARN: wiki-init: wiki-generate-stubs.sh exited $_stubs_rc — nav regen may use stale stubs" >&2
  fi
fi
if [ -f "$WIKI_REGEN_NAV" ]; then
  set +e
  bash "$WIKI_REGEN_NAV" --root "$PROJECT_DIR"
  _nav_rc=$?
  set -e
  if [ "$_nav_rc" -ne 0 ]; then
    echo "WARN: wiki-init: wiki-generate-nav.sh exited $_nav_rc — wiki/mkdocs.yml nav: block may carry bundle defaults" >&2
  else
    echo "wiki-init: regenerated wiki/docs/ stubs + wiki/mkdocs.yml nav: block from project artifacts"
  fi
fi

# FR-9 + MIT-007 + MIT-008 --deploy scope: four-step ordered sequence with
# read-before-write Pages guard and structured JSONL audit-trail. Composes
# with the default scope OR with --with-giscus (does NOT depend on
# --with-giscus having run).
if [ "$WITH_DEPLOY" = "1" ]; then
  # JSONL log path: <PROJECT_DIR>/.orchestrator/execution-log.jsonl
  # (initialized via mkdir -p .orchestrator/ if absent).
  LOG_DIR="$PROJECT_DIR/.orchestrator"
  LOG_FILE="$LOG_DIR/execution-log.jsonl"
  mkdir -p "$LOG_DIR"

  # Track which mutations actually fire so the audit-trail mutations array
  # reflects the truth on disk. Bash 3.2 — use parallel scalar flags, not
  # arrays of objects.
  MUT_DISCUSSIONS=0
  MUT_GH_PAGES_BRANCH=0
  MUT_PAGES_CONFIGURED=0

  iso_ts() {
    date -u +%Y-%m-%dT%H:%M:%SZ
  }

  # Step 1: enable Discussions via PATCH /repos/<owner>/<repo>.
  step1_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      step1_rc=0
      MUT_DISCUSSIONS=1
      ;;
    *)
      set +e
      gh api --method PATCH "/repos/$OWNER/$REPO" -f has_discussions=true >/dev/null 2>&1
      step1_rc=$?
      set -e
      if [ "$step1_rc" -eq 0 ]; then
        MUT_DISCUSSIONS=1
      fi
      ;;
  esac
  if [ "$step1_rc" -ne 0 ]; then
    audit_failure "discussions_enable" "$step1_rc"
    echo "FAIL: wiki-init: --deploy step 1: gh api PATCH /repos/$OWNER/$REPO has_discussions=true exited $step1_rc" >&2
    exit 10
  fi

  # M035/P00/T04 — closes M032 SC-5 fixture-completeness gap.
  # If $PROJECT_DIR is missing scripts/wiki/wiki-deploy.sh, stage it from
  # $REPO_ROOT (M032 SC-5 deferred-validation fallback). Existing-file
  # behaviour unchanged: copy only when target is absent.
  if [ ! -f "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" ]; then
    if [ -f "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" ]; then
      mkdir -p "$PROJECT_DIR/scripts/wiki"
      cp "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"
      echo "wiki-init: staged \$PROJECT_DIR/scripts/wiki/wiki-deploy.sh from \$REPO_ROOT (M032 SC-5 deferred-validation fallback)" >&2
    else
      echo "FAIL: wiki-init: --deploy step 2 cannot stage wiki-deploy.sh — neither \$PROJECT_DIR/scripts/wiki/wiki-deploy.sh nor \$REPO_ROOT/scripts/wiki/wiki-deploy.sh exist" >&2
      exit 11
    fi
  fi

  # Step 2: invoke wiki-deploy.sh (it runs the FR-10 cwd-gate + the four
  # P02-baseline gates + mkdocs gh-deploy --force).
  step2_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — skip the deploy invocation entirely (no mkdocs install
      # required for hermetic verifier coverage).
      step2_rc=0
      MUT_GH_PAGES_BRANCH=1
      ;;
    *)
      set +e
      bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"
      step2_rc=$?
      set -e
      if [ "$step2_rc" -eq 0 ]; then
        MUT_GH_PAGES_BRANCH=1
      fi
      ;;
  esac
  if [ "$step2_rc" -ne 0 ]; then
    audit_failure "wiki_deploy" "$step2_rc"
    echo "FAIL: wiki-init: --deploy step 2: wiki-deploy.sh exited $step2_rc" >&2
    exit 11
  fi

  # Step 3: MIT-007 read-before-write Pages guard.
  # gh api GET /repos/<owner>/<repo>/pages — inspect .source.branch and .source.path.
  PAGES_RESP=""
  pages_get_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — read fixture state from $M032_DEPLOY_GH_API_STUB_DIR/pages-get.json
      # (or default to "404 / no Pages configured" if file absent).
      if [ -n "${M032_DEPLOY_GH_API_STUB_DIR:-}" ] && [ -f "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json" ]; then
        PAGES_RESP="$(cat "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json")"
        pages_get_rc=0
      else
        PAGES_RESP=""
        pages_get_rc=1  # simulates 404 Not Found
      fi
      ;;
    *)
      set +e
      PAGES_RESP="$(gh api "/repos/$OWNER/$REPO/pages" 2>/dev/null)"
      pages_get_rc=$?
      set -e
      ;;
  esac

  PAGES_PUT_NEEDED=1
  if [ "$pages_get_rc" -eq 0 ] && [ -n "$PAGES_RESP" ]; then
    # Pages exist — inspect source.
    EXISTING_BRANCH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"branch":"\([^"]*\)".*/\1/p')
    EXISTING_PATH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"path":"\([^"]*\)".*/\1/p')
    if [ "$EXISTING_BRANCH" = "gh-pages" ] && [ "$EXISTING_PATH" = "/" ]; then
      # No-op: already configured for our target source.
      PAGES_PUT_NEEDED=0
      echo "wiki-init: --deploy step 3: pages-already-configured (gh-pages root) — skipping PUT"
    else
      # Incompatible source.
      if [ "$FORCE_PAGES_RECONFIG" -eq 1 ]; then
        echo "wiki-init: --deploy step 3: WARNING — overwriting existing Pages source ($EXISTING_BRANCH $EXISTING_PATH) per --force-pages-reconfigure" >&2
      else
        audit_failure "pages_guard" "$pages_get_rc"
        echo "FAIL: wiki-init: Repository has an existing Pages deployment from a different source ($EXISTING_BRANCH $EXISTING_PATH). This source will be overwritten. Pass --force-pages-reconfigure to proceed, or reconfigure Pages manually before running --deploy." >&2
        exit 12
      fi
    fi
  fi

  # Step 4: PUT /repos/<owner>/<repo>/pages (only if PAGES_PUT_NEEDED).
  if [ "$PAGES_PUT_NEEDED" -eq 1 ]; then
    step4_rc=0
    case "${M032_DEPLOY_GH_API_STUB:-}" in
      1)
        step4_rc=0
        MUT_PAGES_CONFIGURED=1
        ;;
      *)
        set +e
        gh api --method PUT "/repos/$OWNER/$REPO/pages" -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null 2>&1
        step4_rc=$?
        set -e
        if [ "$step4_rc" -eq 0 ]; then
          MUT_PAGES_CONFIGURED=1
        fi
        ;;
    esac
    if [ "$step4_rc" -ne 0 ]; then
      audit_failure "pages_put" "$step4_rc"
      echo "FAIL: wiki-init: --deploy step 4: gh api PUT /repos/$OWNER/$REPO/pages exited $step4_rc" >&2
      exit 13
    fi
  fi

  # Step 5: MIT-008 audit-trail append BEFORE live URL print.
  # NDJSON shape — one line, newline-terminated. mutations array reflects
  # actual fired steps via parallel scalar flags (bash 3.2 — no declare -A).
  TS="$(iso_ts)"
  MUTATIONS=""
  if [ "$MUT_DISCUSSIONS" -eq 1 ]; then
    MUTATIONS='{"type":"discussions_enabled"}'
  fi
  if [ "$MUT_GH_PAGES_BRANCH" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "$MUT_PAGES_CONFIGURED" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"success"}\n' \
    "$TS" "$OWNER" "$REPO" "$MUTATIONS" >> "$LOG_FILE"

  # Step 6: print live URL.
  OWNER_LOWER_DEPLOY="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
  printf 'https://%s.github.io/%s/\n' "$OWNER_LOWER_DEPLOY" "$REPO"
fi

echo "wiki-init: done (project=$PROJECT_DIR site_name=${SITE_NAME})"
exit 0
