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
#   5 — --with-giscus or --deploy passed (P03 deliverable; P02 rejects).
#   6 — bundle staging failure (read-project-assets.sh or install-asset-mode.sh failed).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR=""
SITE_NAME_OVERRIDE=""
SITE_DESCRIPTION_OVERRIDE=""
AUTO_PIP=0
WITH_GISCUS=0
WITH_DEPLOY=0
FORCE=0

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

# P02 rejects --with-giscus and --deploy (P03 deliverables).
if [ "$WITH_GISCUS" = "1" ] || [ "$WITH_DEPLOY" = "1" ]; then
  echo "FAIL: wiki-init: --with-giscus and --deploy not yet implemented in P02; reserved for P03" >&2
  exit 5
fi

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
  # Compute target lines with the to-be-applied values.
  desired_site_name='site_name: "'"$SITE_NAME"'"'
  desired_site_description='site_description: "'"$SITE_DESCRIPTION"'"'
  desired_site_url='site_url: "'"$SITE_URL"'"'
  desired_repo_url='repo_url: "'"$REPO_URL"'"'

  # Detect whether all four lines already match desired values exactly (idempotent no-op).
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

  if [ "$match_count" -eq 4 ] && [ "$FORCE" != "1" ]; then
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

    tmp="$(mktemp -t wiki-init-mkdocs.XXXXXX)"
    sed \
      -e "s|^site_name:.*|site_name: \"${s_name}\"|" \
      -e "s|^site_description:.*|site_description: \"${s_desc}\"|" \
      -e "s|^site_url:.*|site_url: \"${s_url}\"|" \
      -e "s|^repo_url:.*|repo_url: \"${s_repo}\"|" \
      "$MKDOCS_TARGET" > "$tmp"
    mv "$tmp" "$MKDOCS_TARGET"
    echo "wiki-init: substituted site_name=${SITE_NAME} site_url=${SITE_URL} repo_url=${REPO_URL} in $MKDOCS_TARGET"
  fi
fi

# FR-15 path-convention stub: author wiki/glossary.md if absent.
GLOSSARY_TARGET="$PROJECT_DIR/wiki/glossary.md"
if [ ! -f "$GLOSSARY_TARGET" ]; then
  mkdir -p "$(dirname "$GLOSSARY_TARGET")"
  cat > "$GLOSSARY_TARGET" <<'GLOSSARYEOF'
# Glossary

Project glossary — alphabetized term entries with one-line definitions
and at most a two-line elaboration. M033's grilling protocol writes inline
into this file as terms resolve.

### Example Term

A one-line definition demonstrating the format invariant.

A two-line elaboration expanding on the definition, no longer than this paragraph.
GLOSSARYEOF
  echo "wiki-init: authored glossary stub at $GLOSSARY_TARGET"
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

echo "wiki-init: done (project=$PROJECT_DIR site_name=${SITE_NAME})"
exit 0
