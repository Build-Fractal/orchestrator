#!/usr/bin/env bash
# scripts/intake/lib/task-slug.sh -- M031 P02 T02 deterministic task-slug
# derivation per AD-10. Sourceable; exposes one function:
#
#   derive_task_slug <task-description>  -> echoes <base-slug>[-<sha1-4>]
#
# Base slug derivation (deterministic):
#   1. Lowercase the task description.
#   2. Replace whitespace runs with single hyphens.
#   3. Strip every character that is not [a-z0-9-].
#   4. Collapse consecutive hyphens; strip leading/trailing hyphens.
#   5. Truncate to 40 characters.
#
# Collision discipline (AD-10):
#   - If `.orchestrator/tier-a-plus/<base-slug>/research.md` does NOT exist
#     OR its first line matches the current task description's first line,
#     return the bare <base-slug>.
#   - Otherwise compute SHA-1 of the full task description (using
#     `shasum -a 1` or `openssl sha1` per host availability), take the
#     first 4 hex characters, and return `<base-slug>-<sha1-4>`.
#
# Empty-input fallback:
#   - When the input (or its base slug after stripping) is empty, the
#     function emits the deterministic literal `untitled` so callers
#     never receive a zero-length slug. Collision discipline above still
#     applies against `.orchestrator/tier-a-plus/untitled/research.md`.
#
# Bash 3.2 compatible. No declare -A, no process substitution, no $()
# pipes inside conditionals (per MEM001).

# _task_slug_sha1 <string>
#   Echoes lowercase hex SHA-1 of stdin/argument. Prefers `shasum -a 1`;
#   falls back to `openssl sha1`. Returns empty string if neither is on
#   PATH (caller treats empty as "no collision suffix possible" -- the
#   bare base slug is still emitted upstream of suffix logic).
_task_slug_sha1() {
    _tss_input="$1"
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$_tss_input" | shasum -a 1 | awk '{print $1}'
        return 0
    fi
    if command -v openssl >/dev/null 2>&1; then
        printf '%s' "$_tss_input" | openssl sha1 | awk '{print $NF}'
        return 0
    fi
    printf ''
}

# _task_slug_first_line <string>
#   Echoes the first line of the input (stops at newline). Used both for
#   the current task description's first line (collision comparison) and
#   for reading the upstream research.md's first line.
_task_slug_first_line() {
    printf '%s' "$1" | awk 'NR==1 {print; exit}'
}

# _task_slug_base <string>
#   Echoes the deterministic 40-char base slug per the documented rules.
#   Output may be empty when the input contains no [a-z0-9] characters;
#   the public derive_task_slug wrapper substitutes the `untitled`
#   fallback in that case.
_task_slug_base() {
    _tsb_input="$1"
    # Lowercase + whitespace-to-hyphen + strip non [a-z0-9-] + collapse
    # consecutive hyphens + strip leading/trailing hyphens. Done with a
    # single tr/sed pipeline for portability.
    _tsb_lower=$(printf '%s' "$_tsb_input" | tr '[:upper:]' '[:lower:]')
    _tsb_ws=$(printf '%s' "$_tsb_lower" | tr -s '[:space:]' '-')
    _tsb_stripped=$(printf '%s' "$_tsb_ws" | sed 's/[^a-z0-9-]//g')
    _tsb_collapsed=$(printf '%s' "$_tsb_stripped" | sed 's/--*/-/g')
    _tsb_trimmed=$(printf '%s' "$_tsb_collapsed" | sed 's/^-//' | sed 's/-$//')
    # Truncate to 40 characters via cut. Strip trailing hyphen if the
    # 40-char cut landed on one (keeps slugs human-readable).
    _tsb_truncated=$(printf '%s' "$_tsb_trimmed" | cut -c1-40 | sed 's/-$//')
    printf '%s' "$_tsb_truncated"
}

# derive_task_slug <task-description>
#   Public entry point. Echoes the AD-10 slug shape:
#     <base-slug>             (no collision)
#     <base-slug>-<sha1-4>    (collision against an unrelated prior task)
#     untitled                (empty input fallback)
#     untitled-<sha1-4>       (empty input collision)
#
#   The function is deterministic given the same task description AND the
#   same on-disk state under `.orchestrator/tier-a-plus/<base-slug>/`.
derive_task_slug() {
    _dts_input="$1"
    _dts_base=$(_task_slug_base "$_dts_input")
    if [ -z "$_dts_base" ]; then
        _dts_base="untitled"
    fi

    # Resolve the project root relative to this script. The collision
    # check is rooted at `<project-root>/.orchestrator/tier-a-plus/<base>/`.
    # This keeps the function callable from any cwd.
    _dts_self="${BASH_SOURCE[0]:-}"
    if [ -z "$_dts_self" ]; then
        _dts_self="$0"
    fi
    _dts_self_dir=$(cd "$(dirname "$_dts_self")" && pwd)
    _dts_root=$(cd "$_dts_self_dir/../../.." && pwd)
    _dts_research="$_dts_root/.orchestrator/tier-a-plus/$_dts_base/research.md"

    if [ ! -f "$_dts_research" ]; then
        printf '%s\n' "$_dts_base"
        return 0
    fi

    _dts_current_first=$(_task_slug_first_line "$_dts_input")
    _dts_existing_first=$(awk 'NR==1 {print; exit}' "$_dts_research")

    if [ "$_dts_current_first" = "$_dts_existing_first" ]; then
        printf '%s\n' "$_dts_base"
        return 0
    fi

    # Collision against an unrelated prior task description -> append the
    # SHA-1-4 suffix derived from the FULL task description (not just the
    # first line) so different bodies under the same first-line collide
    # to distinct slugs.
    _dts_hash=$(_task_slug_sha1 "$_dts_input")
    _dts_suffix=$(printf '%s' "$_dts_hash" | cut -c1-4)
    if [ -z "$_dts_suffix" ]; then
        # Neither shasum nor openssl on PATH; fall back to the bare base
        # slug rather than emit an empty suffix. Caller sees this as a
        # silent collision-resolution failure; the bare slug is still a
        # valid AD-10 shape.
        printf '%s\n' "$_dts_base"
        return 0
    fi
    printf '%s-%s\n' "$_dts_base" "$_dts_suffix"
}
