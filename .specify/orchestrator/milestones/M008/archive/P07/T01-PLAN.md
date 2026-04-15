---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M008"
name: "detect-project.sh — language/framework/CI/tools detection"
depends_on: []
---

## Prerequisites

- None (independent leaf task). The script scans a project directory and emits key=value pairs. It does not depend on any other P07 task.
- Must follow MEM001 shell conventions: Bash 3.2, no associative arrays, structured key=value stdout, errors to stderr, exit 0 on success.
- Must follow the "capability profile output mode" pattern established by P01's `detect-capabilities.sh --profile` (key=value lines, flat namespace, one per line).

## Description

Create `scripts/lifecycle/detect-project.sh`. Given a project directory (via `--project-dir PATH`, defaulting to `$PWD`), the script scans the directory for language, framework, CI, and tool markers and emits a flat set of `key=value` lines to stdout. The output is consumed by `init-project.sh` (T03) and rendered into `templates/project-instruction.md` (T02) to populate the "Project Overview" section.

The script MUST NOT write any files, MUST NOT invoke network operations, and MUST exit 0 even when no markers are detected (output `unknown`/`none` values). Detection is best-effort and non-authoritative — absence of markers is a normal state.

## Steps

### 1. Script skeleton

Create `scripts/lifecycle/detect-project.sh`, mode 0755, with the following contract:

```
Usage:
  detect-project.sh [--project-dir PATH] [--verbose]

Output (stdout, key=value, one per line):
  language=<primary language or 'unknown'>
  languages_all=<comma-separated list of all detected languages or empty>
  framework=<primary framework or 'none'>
  frameworks_all=<comma-separated list or empty>
  ci_system=<primary CI system or 'none'>
  tools_detected=<comma-separated list of orchestration tools or empty>
  project_type=<generic|library|service|monorepo|cli|empty>
  has_git=<true|false>
  has_tests=<true|false>

Exit: 0 always (except 1 on malformed argument).
```

### 2. Arg parsing (Bash 3.2 `while-case`)

```bash
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
```

### 3. Language detection

Use a fixed lookup table (parallel arrays — Bash 3.2 safe). Emit `language=` with the first matched language, and `languages_all=` with all matches comma-joined.

| Marker file(s) | Language |
|---|---|
| `package.json` | node |
| `pyproject.toml`, `setup.py`, `requirements.txt` | python |
| `Cargo.toml` | rust |
| `go.mod` | go |
| `Gemfile` | ruby |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | java |
| `composer.json` | php |
| `*.csproj`, `*.sln` | dotnet |
| `Package.swift` | swift |
| `mix.exs` | elixir |

Implementation sketch:

```bash
langs=""
primary_lang="unknown"
check_lang() {
  # $1 = marker glob, $2 = language name
  if ls "$PROJECT_DIR"/$1 >/dev/null 2>&1; then
    if [ -z "$langs" ]; then
      langs="$2"
      primary_lang="$2"
    else
      case ",$langs," in *,$2,*) ;; *) langs="$langs,$2" ;; esac
    fi
  fi
}
check_lang "package.json" "node"
check_lang "pyproject.toml" "python"
check_lang "setup.py" "python"
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
  check_lang "dummy-always-missing" "dotnet"
  # (adjust: prefer direct call without the inner ls, to avoid double-add)
fi
```

Note: the helper uses `case ",$langs," in *,$2,*)` for dedup — this is a Bash 3.2-safe way to check membership in a comma-joined list.

### 4. Framework detection

Scan for framework markers. Emit `framework=` with the first match, `frameworks_all=` with all.

| Marker | Framework |
|---|---|
| `next.config.js`, `next.config.mjs`, `next.config.ts` | next |
| `nuxt.config.js`, `nuxt.config.ts` | nuxt |
| `vite.config.js`, `vite.config.ts` | vite |
| `remix.config.js` | remix |
| `svelte.config.js` | svelte |
| `angular.json` | angular |
| `django-admin` script or `manage.py` | django |
| `Rakefile` + `config/routes.rb` | rails |
| `astro.config.mjs` | astro |

Follow the same `check_framework` helper pattern from step 3.

### 5. CI system detection

```bash
ci_system="none"
[ -d "$PROJECT_DIR/.github/workflows" ] && ci_system="github-actions"
[ -f "$PROJECT_DIR/.gitlab-ci.yml" ] && ci_system="gitlab-ci"
[ -f "$PROJECT_DIR/.circleci/config.yml" ] && ci_system="circleci"
[ -f "$PROJECT_DIR/.travis.yml" ] && ci_system="travis-ci"
[ -f "$PROJECT_DIR/azure-pipelines.yml" ] && ci_system="azure-pipelines"
[ -f "$PROJECT_DIR/Jenkinsfile" ] && ci_system="jenkins"
```

Order matters — last match wins with this simple pattern; if more nuance is needed, switch to the comma-joined-dedup pattern from step 3. For P07, single-value `ci_system=` is sufficient.

### 6. Tools detection

```bash
tools=""
add_tool() {
  if [ -z "$tools" ]; then tools="$1"
  else case ",$tools," in *,$1,*) ;; *) tools="$tools,$1" ;; esac
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
```

### 7. Project-type heuristic

```bash
project_type="generic"
# Empty project?
if [ -z "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
  project_type="empty"
fi
# Monorepo?
[ -f "$PROJECT_DIR/pnpm-workspace.yaml" ] && project_type="monorepo"
[ -f "$PROJECT_DIR/lerna.json" ] && project_type="monorepo"
[ -d "$PROJECT_DIR/packages" ] && [ "$primary_lang" = "node" ] && project_type="monorepo"
# CLI?
[ -f "$PROJECT_DIR/bin/$(basename "$PROJECT_DIR")" ] && project_type="cli"
# Library vs service: leave as 'generic' unless we have a strong signal.
```

### 8. Git + tests

```bash
has_git="false"
[ -d "$PROJECT_DIR/.git" ] && has_git="true"
has_tests="false"
if [ -d "$PROJECT_DIR/tests" ] || [ -d "$PROJECT_DIR/test" ] || [ -d "$PROJECT_DIR/spec" ]; then
  has_tests="true"
fi
```

### 9. Emit

```bash
echo "language=$primary_lang"
echo "languages_all=$langs"
echo "framework=$primary_framework"
echo "frameworks_all=$frameworks"
echo "ci_system=$ci_system"
echo "tools_detected=$tools"
echo "project_type=$project_type"
echo "has_git=$has_git"
echo "has_tests=$has_tests"
```

When `--verbose`, additionally emit `probed_dir=$PROJECT_DIR` on stderr.

### 10. Verification scripts

Write two verification scripts under `scripts/verify/`:

**`scripts/verify/m008-p07-detect-project-contract.sh`** — empty-project contract check:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

out="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$FIXTURE")"
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: detect-project.sh exited $rc on empty project" >&2
  exit 1
fi

for key in language framework ci_system tools_detected project_type has_git has_tests; do
  if ! echo "$out" | grep -q "^$key="; then
    echo "FAIL: missing key '$key=' in output" >&2
    echo "$out" >&2
    exit 1
  fi
done

echo "PASS: detect-project.sh emits required keys on empty project"
```

**`scripts/verify/m008-p07-detect-project-matrix.sh`** — matrix across Node, Python, Rust, GitHub Actions:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/lifecycle/detect-project.sh"

assert_key_value() {
  # $1 = fixture path, $2 = expected key, $3 = expected value
  out="$(bash "$SCRIPT" --project-dir "$1")"
  line="$(echo "$out" | grep "^$2=")"
  if [ "$line" != "$2=$3" ]; then
    echo "FAIL: expected $2=$3, got: $line" >&2
    echo "$out" >&2
    exit 1
  fi
}

# Node fixture
F="$(mktemp -d)"; trap 'rm -rf "$F"' EXIT
echo '{}' > "$F/package.json"
assert_key_value "$F" "language" "node"

# Python fixture
F2="$(mktemp -d)"
echo '[project]' > "$F2/pyproject.toml"
assert_key_value "$F2" "language" "python"

# Rust fixture
F3="$(mktemp -d)"
echo '[package]' > "$F3/Cargo.toml"
assert_key_value "$F3" "language" "rust"

# GitHub Actions fixture
F4="$(mktemp -d)"
mkdir -p "$F4/.github/workflows"
touch "$F4/.github/workflows/ci.yml"
assert_key_value "$F4" "ci_system" "github-actions"

rm -rf "$F2" "$F3" "$F4"
echo "PASS: detect-project.sh matrix (node/python/rust/gh-actions)"
```

## Must-Haves

Addresses:

- `scripts/lifecycle/detect-project.sh` exists, is executable, and emits the required key=value contract.
- Contract check passes on an empty fixture (all required keys emitted with sensible defaults).
- Matrix check passes on Node / Python / Rust / GitHub Actions fixtures.
- Bash 3.2 compatible (checked globally by T05).

## Verification

```
bash scripts/verify/m008-p07-detect-project-contract.sh
bash scripts/verify/m008-p07-detect-project-matrix.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07
```

Each must emit a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- None (independent leaf task).

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` (P01) — reference implementation for capability profile output mode. Not invoked; used as a pattern reference.
  - Key pattern: key=value lines on stdout, one per line, flat namespace.
- None other.

## Constraints

- Bash 3.2 only — no `declare -A`, no `mapfile`, no `${var,,}`.
- No network calls.
- No writes to disk. Pure read-and-emit.
- Exit 0 even when nothing is detected (output `unknown`/`none`). Exit 1 only on malformed arguments.
- Script must work when invoked with `--project-dir PATH` where PATH is any readable directory (including empty dirs and dirs outside the current git repo).
- All detection MUST be file-presence-based, not content-parsed (no JSON/YAML parsing). This keeps the script fast and dependency-free.

## Expected Output

- `scripts/lifecycle/detect-project.sh` (60+ lines, contains `language=`, mode 0755)
- `scripts/verify/m008-p07-detect-project-contract.sh` (mode 0755)
- `scripts/verify/m008-p07-detect-project-matrix.sh` (mode 0755)
