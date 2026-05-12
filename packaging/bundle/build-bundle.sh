#!/usr/bin/env bash
# build-bundle.sh — assemble packaging/bundle/ from source skills + hooks + config.
#
# Modes:
#   (default)  Rebuild skills/ from packaging/skills/, substitute version into
#              manifest.yml, emit one wrote=<path> line per written file.
#   --check    Verify bundle contents match expected set (13 skills, 5 hooks,
#              1 config, 1 README, 1 manifest). Exit non-zero on drift.
#
# Bash 3.2 compatible. No python, no jq.

set -euo pipefail

# Resolve repo root: script lives at packaging/bundle/build-bundle.sh
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
BUNDLE_DIR="$SCRIPT_DIR"
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)

SKILLS_SRC="$REPO_ROOT/packaging/skills"
BUNDLE_SKILLS="$BUNDLE_DIR/skills"
BUNDLE_HOOKS="$BUNDLE_DIR/hooks"
BUNDLE_CONFIG="$BUNDLE_DIR/config"
MANIFEST="$BUNDLE_DIR/manifest.yml"
README="$BUNDLE_DIR/README.md"
CONFIG_FILE="$BUNDLE_CONFIG/orchestrator.default.yml"

EXPECTED_SKILLS=13
EXPECTED_HOOKS=5

# Expected skill filenames (sorted, as they appear in manifest.yml).
EXPECTED_SKILL_NAMES="orchestrator-auto.md
orchestrator-consolidate.md
orchestrator-cost.md
orchestrator-discuss.md
orchestrator-dispatch.md
orchestrator-doctor.md
orchestrator-evaluate.md
orchestrator-migrate.md
orchestrator-plan-phase.md
orchestrator-resume.md
orchestrator-roadmap.md
orchestrator-status.md
orchestrator-verify.md"

EXPECTED_HOOK_EVENTS="before-tasks
after-tasks
before-implement
after-implement
before-commit"

# M035 P02 T05 — Bundle-hygiene pre-publish filter (#Q-9 absorption).
# Two rules (per .orchestrator/proposals/m035-bundle-hygiene-pre-
# publish-filter.md):
#   1. Pattern exclusion: files matching basename glob
#      m[0-9]*-p[0-9]*-* under scripts/verify/, tools/verify/, or
#      templates/conversus-presets/ are excluded from the staged bundle.
#   2. Magic-comment opt-out: any file whose first 10 lines carry
#      `# bundle: dogfood-only` (or `bundle: dogfood-only` in YAML/MD
#      frontmatter) is excluded.
#
# Verified by tools/verify/m035-p02-bundle-hygiene-filter.sh and
# tools/verify/m035-p02-npm-pack-contents.sh.
should_exclude_from_bundle() {
    local file="$1"
    local rel="${file#$REPO_ROOT/}"
    local base
    base="$(basename "$file")"

    # Rule 1: pattern exclusion under specific directories.
    case "$rel" in
        scripts/verify/m[0-9]*-p[0-9]*-*|\
        tools/verify/m[0-9]*-p[0-9]*-*|\
        templates/conversus-presets/m[0-9]*-p[0-9]*-*)
            return 0
            ;;
    esac

    # Fallback: basename match plus parent-dir scope.
    case "$base" in
        m[0-9]*-p[0-9]*-*)
            case "$rel" in
                scripts/verify/*|tools/verify/*|templates/conversus-presets/*)
                    return 0
                    ;;
            esac
            ;;
    esac

    # Rule 2: magic-comment opt-out (header line or YAML frontmatter).
    if [ -f "$file" ]; then
        if head -10 "$file" 2>/dev/null \
             | grep -qE '^[[:space:]]*#?[[:space:]]*bundle:[[:space:]]*dogfood-only' ; then
            return 0
        fi
    fi

    return 1
}

# Post-copy hygiene pass: prunes dogfood-only artifacts from a staged
# bundle dir. Invoked at the end of cmd_build for any populated
# subtrees that may carry milestone-internal verifiers.
apply_bundle_hygiene_filter() {
    local stage_dir="$1"
    [ -d "$stage_dir" ] || return 0

    # Pattern exclusion under three subdirs.
    local subdir
    for subdir in scripts/verify tools/verify templates/conversus-presets; do
        [ -d "$stage_dir/$subdir" ] || continue
        find "$stage_dir/$subdir" -type f -name 'm[0-9]*-p[0-9]*-*' \
            -exec rm -f {} +
    done

    # Magic-comment exclusion: scan bundle-relevant subtrees.
    local search_dirs=""
    for subdir in scripts templates references commands; do
        [ -d "$stage_dir/$subdir" ] && search_dirs="$search_dirs $stage_dir/$subdir"
    done
    [ -n "$search_dirs" ] || return 0

    find $search_dirs -type f \
            \( -name '*.sh' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) \
            2>/dev/null \
        | while IFS= read -r f; do
            if head -10 "$f" 2>/dev/null \
                 | grep -qE '^[[:space:]]*#?[[:space:]]*bundle:[[:space:]]*dogfood-only'; then
                rm -f "$f"
                [ "${VERBOSE:-0}" = "1" ] && echo "excluded=$f" >&2
            fi
        done
}

resolve_version() {
    if [ -f "$REPO_ROOT/VERSION" ]; then
        # Strip whitespace from VERSION file.
        sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$REPO_ROOT/VERSION" | head -n1
    else
        printf '0.3.0-dev\n'
    fi
}

cmd_build() {
    local version
    version=$(resolve_version)

    mkdir -p "$BUNDLE_SKILLS" "$BUNDLE_HOOKS" "$BUNDLE_CONFIG"

    # Copy skills (not symlink) so the bundle tars cleanly.
    local src
    for src in "$SKILLS_SRC"/orchestrator-*.md; do
        if [ -f "$src" ]; then
            local base
            base=$(basename "$src")
            cp "$src" "$BUNDLE_SKILLS/$base"
            printf 'wrote=%s\n' "$BUNDLE_SKILLS/$base"
        fi
    done

    # Substitute version into manifest (version: "..." line).
    # sed in-place with BSD/GNU portability via temp file.
    if [ -f "$MANIFEST" ]; then
        local tmp
        tmp="$MANIFEST.tmp.$$"
        sed -e 's|^version: .*|version: "'"$version"'"|' "$MANIFEST" > "$tmp"
        mv "$tmp" "$MANIFEST"
        printf 'wrote=%s\n' "$MANIFEST"
    fi

    # Hooks, config, README are authored files — report them as written
    # once they exist on disk (build-bundle is idempotent for these).
    local h
    for h in before-tasks after-tasks before-implement after-implement before-commit; do
        if [ -f "$BUNDLE_HOOKS/$h.json" ]; then
            printf 'wrote=%s\n' "$BUNDLE_HOOKS/$h.json"
        fi
    done

    if [ -f "$CONFIG_FILE" ]; then
        printf 'wrote=%s\n' "$CONFIG_FILE"
    fi

    if [ -f "$README" ]; then
        printf 'wrote=%s\n' "$README"
    fi

    # M035 P02 T05 — apply bundle-hygiene pre-publish filter.
    apply_bundle_hygiene_filter "$BUNDLE_DIR"

    printf 'BUILD: version=%s skills=%d hooks=%d\n' "$version" "$EXPECTED_SKILLS" "$EXPECTED_HOOKS"
}

cmd_check() {
    local errors=0

    # Manifest.
    if [ ! -f "$MANIFEST" ]; then
        printf 'FAIL: missing manifest: %s\n' "$MANIFEST" >&2
        errors=$((errors + 1))
    fi

    # README.
    if [ ! -f "$README" ]; then
        printf 'FAIL: missing README: %s\n' "$README" >&2
        errors=$((errors + 1))
    fi

    # Config.
    if [ ! -f "$CONFIG_FILE" ]; then
        printf 'FAIL: missing config: %s\n' "$CONFIG_FILE" >&2
        errors=$((errors + 1))
    fi

    # Skills count + names.
    local skill_count=0
    local missing_skill=""
    local name
    for name in $EXPECTED_SKILL_NAMES; do
        if [ -f "$BUNDLE_SKILLS/$name" ]; then
            skill_count=$((skill_count + 1))
        else
            missing_skill="$missing_skill $name"
        fi
    done
    if [ "$skill_count" -ne "$EXPECTED_SKILLS" ]; then
        printf 'FAIL: expected %d skills in %s, got %d (missing:%s)\n' \
            "$EXPECTED_SKILLS" "$BUNDLE_SKILLS" "$skill_count" "$missing_skill" >&2
        errors=$((errors + 1))
    fi

    # Hooks count + names.
    local hook_count=0
    local missing_hook=""
    local ev
    for ev in $EXPECTED_HOOK_EVENTS; do
        if [ -f "$BUNDLE_HOOKS/$ev.json" ]; then
            hook_count=$((hook_count + 1))
        else
            missing_hook="$missing_hook $ev.json"
        fi
    done
    if [ "$hook_count" -ne "$EXPECTED_HOOKS" ]; then
        printf 'FAIL: expected %d hooks in %s, got %d (missing:%s)\n' \
            "$EXPECTED_HOOKS" "$BUNDLE_HOOKS" "$hook_count" "$missing_hook" >&2
        errors=$((errors + 1))
    fi

    if [ "$errors" -ne 0 ]; then
        printf 'FAIL: bundle check failed with %d error(s)\n' "$errors" >&2
        exit 1
    fi

    local version=""
    if [ -f "$MANIFEST" ]; then
        version=$(grep -E '^version: ' "$MANIFEST" | head -n1 | sed -e 's/^version: //' -e 's/^"//' -e 's/"$//')
    fi
    printf 'PASS: bundle check — version=%s, %d skills, %d hooks\n' \
        "$version" "$skill_count" "$hook_count"
}

main() {
    local mode="build"
    if [ "$#" -gt 0 ]; then
        case "$1" in
            --check)
                mode="check"
                ;;
            --help|-h)
                sed -n '2,12p' "$0"
                exit 0
                ;;
            *)
                printf 'error: unknown argument: %s\n' "$1" >&2
                exit 2
                ;;
        esac
    fi

    case "$mode" in
        build) cmd_build ;;
        check) cmd_check ;;
    esac
}

main "$@"
