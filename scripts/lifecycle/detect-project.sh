#!/usr/bin/env bash
# scripts/lifecycle/detect-project.sh — Detect project language/framework/CI/tools via marker files
#
# Usage:
#   detect-project.sh [--project-dir PATH] [--verbose]
#
# Output (stdout, key=value, one per line):
#   language=<primary language or 'unknown'>
#   languages_all=<comma-separated list of all detected languages or empty>
#   framework=<primary framework or 'none'>
#   frameworks_all=<comma-separated list or empty>
#   ci_system=<primary CI system or 'none'>
#   tools_detected=<comma-separated list of orchestration tools or empty>
#   project_type=<generic|library|service|monorepo|cli|empty>
#   has_git=<true|false>
#   has_tests=<true|false>
#
# Exit: 0 always (except 1 on malformed argument or missing project dir).
#
# Contract:
#   - Bash 3.2 compatible (no associative arrays, no mapfile, no ${var,,}).
#   - No network calls. No writes to disk. Pure read-and-emit.
#   - File-presence-based detection only (no JSON/YAML parsing).
#   - Consumed by init-project.sh (T03) and rendered into templates/project-instruction.md (T02).

set -u

PROJECT_DIR="$PWD"
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

[ -d "$PROJECT_DIR" ] || { echo "ERROR: not a directory: $PROJECT_DIR" >&2; exit 1; }

# ---- Language detection -----------------------------------------------------

langs=""
primary_lang="unknown"

add_lang() {
  # $1 = language name
  if [ -z "$langs" ]; then
    langs="$1"
    primary_lang="$1"
  else
    case ",$langs," in
      *,$1,*) ;;
      *) langs="$langs,$1" ;;
    esac
  fi
}

check_lang() {
  # $1 = marker filename (exact), $2 = language name
  if [ -e "$PROJECT_DIR/$1" ]; then
    add_lang "$2"
  fi
}

check_lang "package.json" "node"
check_lang "pyproject.toml" "python"
check_lang "setup.py" "python"
check_lang "requirements.txt" "python"
check_lang "Cargo.toml" "rust"
check_lang "go.mod" "go"
check_lang "Gemfile" "ruby"
check_lang "pom.xml" "java"
check_lang "build.gradle" "java"
check_lang "build.gradle.kts" "java"
check_lang "composer.json" "php"
check_lang "Package.swift" "swift"
check_lang "mix.exs" "elixir"

# .NET markers use glob
if ls "$PROJECT_DIR"/*.csproj >/dev/null 2>&1 || ls "$PROJECT_DIR"/*.sln >/dev/null 2>&1; then
  add_lang "dotnet"
fi

# ---- Framework detection ----------------------------------------------------

frameworks=""
primary_framework="none"

add_framework() {
  if [ -z "$frameworks" ]; then
    frameworks="$1"
    primary_framework="$1"
  else
    case ",$frameworks," in
      *,$1,*) ;;
      *) frameworks="$frameworks,$1" ;;
    esac
  fi
}

# Next.js
if [ -e "$PROJECT_DIR/next.config.js" ] || [ -e "$PROJECT_DIR/next.config.mjs" ] || [ -e "$PROJECT_DIR/next.config.ts" ]; then
  add_framework "next"
fi
# Nuxt
if [ -e "$PROJECT_DIR/nuxt.config.js" ] || [ -e "$PROJECT_DIR/nuxt.config.ts" ]; then
  add_framework "nuxt"
fi
# Vite
if [ -e "$PROJECT_DIR/vite.config.js" ] || [ -e "$PROJECT_DIR/vite.config.ts" ]; then
  add_framework "vite"
fi
# Remix
[ -e "$PROJECT_DIR/remix.config.js" ] && add_framework "remix"
# Svelte
[ -e "$PROJECT_DIR/svelte.config.js" ] && add_framework "svelte"
# Angular
[ -e "$PROJECT_DIR/angular.json" ] && add_framework "angular"
# Django
[ -e "$PROJECT_DIR/manage.py" ] && add_framework "django"
# Rails (Rakefile + config/routes.rb)
if [ -e "$PROJECT_DIR/Rakefile" ] && [ -e "$PROJECT_DIR/config/routes.rb" ]; then
  add_framework "rails"
fi
# Astro
[ -e "$PROJECT_DIR/astro.config.mjs" ] && add_framework "astro"

# ---- CI system detection ----------------------------------------------------

ci_system="none"
[ -d "$PROJECT_DIR/.github/workflows" ] && ci_system="github-actions"
[ -f "$PROJECT_DIR/.gitlab-ci.yml" ] && ci_system="gitlab-ci"
[ -f "$PROJECT_DIR/.circleci/config.yml" ] && ci_system="circleci"
[ -f "$PROJECT_DIR/.travis.yml" ] && ci_system="travis-ci"
[ -f "$PROJECT_DIR/azure-pipelines.yml" ] && ci_system="azure-pipelines"
[ -f "$PROJECT_DIR/Jenkinsfile" ] && ci_system="jenkins"

# ---- Tools detection --------------------------------------------------------

tools=""
add_tool() {
  if [ -z "$tools" ]; then
    tools="$1"
  else
    case ",$tools," in
      *,$1,*) ;;
      *) tools="$tools,$1" ;;
    esac
  fi
}

[ -f "$PROJECT_DIR/docker-compose.yml" ] && add_tool "docker-compose"
[ -f "$PROJECT_DIR/docker-compose.yaml" ] && add_tool "docker-compose"
[ -f "$PROJECT_DIR/Dockerfile" ] && add_tool "docker"
[ -f "$PROJECT_DIR/Makefile" ] && add_tool "make"
[ -f "$PROJECT_DIR/Taskfile.yml" ] && add_tool "task"
[ -f "$PROJECT_DIR/justfile" ] && add_tool "just"
[ -f "$PROJECT_DIR/.pre-commit-config.yaml" ] && add_tool "pre-commit"
[ -f "$PROJECT_DIR/.tool-versions" ] && add_tool "asdf"
[ -f "$PROJECT_DIR/mise.toml" ] && add_tool "mise"

# ---- Project-type heuristic -------------------------------------------------

project_type="generic"

# Empty project?
if [ -z "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
  project_type="empty"
fi

# Monorepo signals
[ -f "$PROJECT_DIR/pnpm-workspace.yaml" ] && project_type="monorepo"
[ -f "$PROJECT_DIR/lerna.json" ] && project_type="monorepo"
if [ -d "$PROJECT_DIR/packages" ] && [ "$primary_lang" = "node" ]; then
  project_type="monorepo"
fi

# CLI signal — bin/<project-name>
if [ -f "$PROJECT_DIR/bin/$(basename "$PROJECT_DIR")" ]; then
  project_type="cli"
fi

# ---- Git + tests ------------------------------------------------------------

has_git="false"
[ -d "$PROJECT_DIR/.git" ] && has_git="true"

has_tests="false"
if [ -d "$PROJECT_DIR/tests" ] || [ -d "$PROJECT_DIR/test" ] || [ -d "$PROJECT_DIR/spec" ]; then
  has_tests="true"
fi

# ---- Emit -------------------------------------------------------------------

echo "language=$primary_lang"
echo "languages_all=$langs"
echo "framework=$primary_framework"
echo "frameworks_all=$frameworks"
echo "ci_system=$ci_system"
echo "tools_detected=$tools"
echo "project_type=$project_type"
echo "has_git=$has_git"
echo "has_tests=$has_tests"

if [ "$VERBOSE" = "1" ]; then
  echo "probed_dir=$PROJECT_DIR" >&2
fi

exit 0
