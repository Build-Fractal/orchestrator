#!/usr/bin/env bash
# scripts/migrate/lib/detect-source.sh — Source Format Detection
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand)
#
# Auto-detects the source project format from directory contents.
# Provides two functions:
#   - detect_source_type <project_path>  — echoes gsd2/gsd1/speckit/unknown
#   - resolve_source_path <path> <type>  — normalizes path for the adapter
#
# Detection priority (when multiple indicators coexist):
#   gsd2 > gsd1 > speckit > unknown
#
# Source this file in other scripts:
#   source "$(dirname "$0")/lib/detect-source.sh"
# =============================================================================

# -----------------------------------------------------------------------------
# detect_source_type <project_path>
#   Inspect a project directory and echo the detected source format.
#   Priority: gsd2 > gsd1 > speckit > unknown
# -----------------------------------------------------------------------------
detect_source_type() {
    local project_path="${1:-.}"

    # Normalize: strip trailing slash
    project_path="${project_path%/}"

    # --- GSD2 detection ---
    # Check for .gsd/ subdirectory containing key files
    if [ -f "${project_path}/.gsd/gsd.db" ] || [ -f "${project_path}/.gsd/memories-snapshot.json" ]; then
        echo "gsd2"
        return 0
    fi

    # Check if the path IS the .gsd directory itself
    if [ -f "${project_path}/gsd.db" ] || [ -f "${project_path}/memories-snapshot.json" ]; then
        # Verify this looks like a .gsd dir (not some random dir with these names)
        case "$project_path" in
            */.gsd)
                echo "gsd2"
                return 0
                ;;
            *)
                # Even if not named .gsd, if it has gsd.db it is gsd2
                if [ -f "${project_path}/gsd.db" ]; then
                    echo "gsd2"
                    return 0
                fi
                if [ -f "${project_path}/memories-snapshot.json" ]; then
                    echo "gsd2"
                    return 0
                fi
                ;;
        esac
    fi

    # --- GSD1 detection ---
    if [ -d "${project_path}/.planning" ]; then
        echo "gsd1"
        return 0
    fi

    # --- spec-kit detection ---
    if [ -d "${project_path}/.specify" ] || [ -d "${project_path}/specs" ]; then
        echo "speckit"
        return 0
    fi

    # --- Unknown ---
    echo "unknown"
    return 0
}

# -----------------------------------------------------------------------------
# resolve_source_path <path> <source_type>
#   Normalize the given path for the adapter based on source type.
#   For gsd2: if path is a project root, the adapter expects the project root
#             (adapter resolves .gsd/ internally via _resolve_gsd_dir).
#   For other types: returns the path as-is (adapters handle their own resolution).
#   Echoes the resolved path to stdout.
# -----------------------------------------------------------------------------
resolve_source_path() {
    local path="${1:-.}"
    local source_type="${2:-unknown}"

    # Normalize: strip trailing slash (unless it is just "/")
    case "$path" in
        /)  ;;
        *)  path="${path%/}" ;;
    esac

    case "$source_type" in
        gsd2)
            # The gsd2 adapter handles .gsd/ resolution internally.
            # If the user passed the .gsd dir directly, go up one level
            # so the adapter's _resolve_gsd_dir sees the project root.
            case "$path" in
                */.gsd)
                    # Already a .gsd path — adapter can use this directly
                    echo "$path"
                    ;;
                *)
                    echo "$path"
                    ;;
            esac
            ;;
        gsd1)
            echo "$path"
            ;;
        speckit)
            echo "$path"
            ;;
        *)
            echo "$path"
            ;;
    esac
    return 0
}
