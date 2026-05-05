---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M032"
name: "wiki-init.sh default scope + commands/wiki-init.md + mkdocs.yml templating + FR-6 self-application loop + bundle wiki/ project_assets entry (FR-5, FR-6, FR-12, MIT-002)"
depends_on: []
---

## Prerequisites

- `packaging/bundle/manifest.yml` exists and carries the P01 `project_assets:` section with exactly four entries (`commands/`, `scripts/`, `references/`, `templates/`). Verified by `[ -f packaging/bundle/manifest.yml ]` and `grep -q '^project_assets:$' packaging/bundle/manifest.yml`.
- `scripts/lifecycle/read-project-assets.sh` exists, is executable, and emits `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` tuples on stdout. Verified by `[ -x scripts/lifecycle/read-project-assets.sh ]`. Behavioral contract: the reader emits one tab-separated tuple per `project_assets:` entry, exits 0 on success.
- `scripts/lifecycle/install-asset-mode.sh` exists, is executable, and dispatches on `mode=copy` and `mode=symlink`. Verified by `[ -x scripts/lifecycle/install-asset-mode.sh ]`. Behavioral contract: takes `<src> <dst> <mode> <project-dir>` args; `mode=copy` runs `cp -R "$src/." "$dst/"`; `mode=symlink` is POSIX-only with `M032_FORCE_WINDOWS=1` fail-closed.
- `scripts/lifecycle/install-collision-check.sh` exists, is executable, and implements FR-22's three oracle branches. Verified by `[ -x scripts/lifecycle/install-collision-check.sh ]`.
- `wiki/mkdocs.yml` exists at the orchestrator-repo root with the four hardcoded site-identity values verified at `wiki/mkdocs.yml:10-13` (`site_name: "spec-kit-orchestrator — dogfood wiki"`, `site_description:`, `site_url:`, `repo_url:`). Verified by `grep -q '^site_name:' wiki/mkdocs.yml`.
- `wiki/overrides/partials/comments.html` exists with the four `data-repo` / `data-repo-id` / `data-category` / `data-category-id` Giscus attributes. P02/T01 does NOT modify this file; FR-7 templating is P03's deliverable. Verified by `[ -f wiki/overrides/partials/comments.html ]`.
- `scripts/wiki/wiki-serve.sh` exists and is executable. Used in step 5 to verify the FR-6 self-application loop.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 (`.gitignore`, `.git-init-marker`, `README.md`). The fixture's git remote points at `https://github.com/fixture-owner/m032-fresh-project-fixture.git` per the marker contents.
- `tools/verify/` exists as the canonical home for project-owned slug-bearing verifiers per AD-19.
- `commands/` exists and contains pre-existing orchestrator command documents following the MEM012 structure (`init.md`, `dispatch.md`, etc.).
- T01 entry: this is the FIRST P02 task. None of `scripts/lifecycle/wiki-init.sh`, `commands/wiki-init.md`, or the `wiki/` entry in `packaging/bundle/manifest.yml` exists yet.

## Description

T01 ships the foundational P02 surface. It (a) authors `commands/wiki-init.md` per the MEM012 orchestrator command-file convention; (b) authors `scripts/lifecycle/wiki-init.sh` implementing the FR-5 default-scope invocation (no `--with-giscus`, no `--deploy`) — Python toolchain probe + git-remote parsing + sed-substitution against `wiki/mkdocs.yml` placeholders; (c) amends `wiki/mkdocs.yml` to replace the four hardcoded site-identity values with `{{...}}` placeholders; (d) closes the FR-6 self-application loop within this task by running `bash scripts/lifecycle/wiki-init.sh --project-dir .` against the orchestrator repo itself, resolving the placeholders to the orchestrator's identity, and verifying `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 (per AD-5 / MIT-002); (e) amends `packaging/bundle/manifest.yml` to add a `wiki/` entry under the existing P01 `project_assets:` block.

The atomicity argument for landing all five sub-deliverables in a single task: FR-6 self-application is non-optional within this task per MIT-002 — without it the orchestrator's own wiki breaks for the duration of M032 + M033 paired development. The bundle `wiki/` entry must land in the same task as `wiki-init.sh` because `wiki-init.sh` reads its bundle source paths via `read-project-assets.sh` against the new entry; splitting the bundle entry into a separate task introduces a no-op test window where `wiki-init.sh` exists but cannot stage any files.

The bundle vs orchestrator-local distinction: `wiki/mkdocs.yml` is BOTH the bundle-staged template (carrying placeholders verbatim — copied by `install-asset-mode.sh` at `mode: copy` to `<PROJECT_DIR>/wiki/mkdocs.yml`, then sed-substituted by `wiki-init.sh`) AND the orchestrator-repo-local resolved version (after the FR-6 self-application loop runs in step 5 below). The bundle copy lives at `wiki/mkdocs.yml` in the orchestrator repo (because the manifest's `wiki/` entry uses `source: wiki/`); the resolved version overwrites the same path after the self-application loop. This is acceptable because the orchestrator's identity values at the bundle-source path render correctly under `wiki-serve.sh` (the placeholders RESOLVE to the orchestrator's own identity when `--project-dir .` is passed). Future bundle pulls by external consumers re-run the sed-substitution against THEIR git remote.

## Steps

1. **Author `commands/wiki-init.md`** following the MEM012 orchestrator command-file convention. Required structure:

```markdown
---
description: "Use when initializing a wiki for a project — installs wiki tooling from the bundle, templates mkdocs.yml from the project's git remote, and probes Python toolchain. Default scope; --with-giscus and --deploy compose on top (P03 deliverables)."
---

# orchestrator:wiki-init

Initialize a working mkdocs Material wiki for any orchestrator-managed project.

## Prerequisites / State Check

- `packaging/bundle/manifest.yml` carries a `project_assets:` entry with `source: wiki/` (P01 + P02/T01 deliverable).
- The consumer project has a git remote at `origin` pointing at `https://github.com/<owner>/<repo>` (parsed for templated values).
- `python3` and `pip3` are on `PATH` (probed at invocation; missing toolchain fails closed with platform-aware diagnostic).

## Core Workflow

### Default scope (no extension flags)

1. Read wiki tooling from `project_assets:` entries via `scripts/lifecycle/read-project-assets.sh`.
2. Probe `python3` and `pip3` on `PATH`. Missing toolchain → fail closed with `brew install python3` (darwin) or `apt install python3` (linux).
3. Parse `git -C "$PROJECT_DIR" remote get-url origin` to derive `<owner>/<repo>`. Synthesize the four `{{...}}` values:
   - `site_name`: `<repo>` (default; overridable via `--site-name`).
   - `site_description`: empty string default; overridable via `--site-description`.
   - `site_url`: `https://<owner>.github.io/<repo>/`.
   - `repo_url`: `https://github.com/<owner>/<repo>`.
4. Stage `wiki/mkdocs.yml` to `<PROJECT_DIR>/wiki/mkdocs.yml` via the P01 mode handler.
5. Sed-substitute the four `{{...}}` placeholders in the staged `mkdocs.yml`.
6. Stage `wiki/overrides/partials/comments.html` to `<PROJECT_DIR>/wiki/overrides/partials/comments.html` UNCHANGED (Giscus partial templating is P03's `--with-giscus` deliverable).
7. Author `<PROJECT_DIR>/wiki/glossary.md` as a path-convention stub (FR-15 — T03 of P02 lands the orchestrator-repo-level canonical version; T01 ships only the consumer-side stub-author logic in `wiki-init.sh`).
8. Optional `--auto-pip` flag runs `pip install -r <PROJECT_DIR>/wiki/requirements.txt` per #Q-2; default behavior is print-and-exit.

### `--with-giscus`

P03 deliverable. P02 surface recognizes the flag and rejects with `not yet implemented in P02; reserved for P03`.

### `--with-wiki --deploy`

P03 deliverable. P02 surface recognizes the flag and rejects with `not yet implemented in P02; reserved for P03`.

## Output

- `<PROJECT_DIR>/wiki/mkdocs.yml` (staged + sed-substituted from git remote).
- `<PROJECT_DIR>/wiki/overrides/partials/comments.html` (staged unchanged).
- `<PROJECT_DIR>/wiki/glossary.md` (stub authored if absent; preserved if present per idempotency).
- `<PROJECT_DIR>/wiki/requirements.txt` (staged from bundle).

## Idempotency

A second invocation against an already-`wiki-init`'d project preserves operator edits to the templated files and exits 0 with `no changes` on stdout. The four `{{...}}` placeholder tokens are NOT re-substituted on re-run unless `--force` is passed (US-2 Acceptance Scenario 5).

## Error Handling

- Missing `python3` or `pip3` → exit non-zero with platform-aware diagnostic (`brew install python3` on darwin; `apt install python3` on linux); writes nothing.
- `git remote get-url origin` fails (no remote configured) → exit non-zero with `wiki-init: no git remote at origin; configure one with 'git remote add origin <url>' before running wiki-init`.
- `--with-giscus` or `--deploy` passed → exit non-zero with `not yet implemented in P02; reserved for P03`.

## Referenced Scripts

- `scripts/lifecycle/wiki-init.sh` — canonical implementation.
- `scripts/lifecycle/read-project-assets.sh` — bundle reader (P01).
- `scripts/lifecycle/install-asset-mode.sh` — per-mode handler (P01).
- `scripts/lifecycle/install-collision-check.sh` — FR-22 dual-oracle hierarchy (P01).
```

2. **Author `scripts/lifecycle/wiki-init.sh`** as the canonical implementation. The script's high-level structure (single-script-file shape per AD-19; bash 3.2 compatible per MEM001):

```bash
#!/usr/bin/env bash
# scripts/lifecycle/wiki-init.sh — FR-5 default scope + FR-12 toolchain probe.
# Per MEM012 the canonical command document is commands/wiki-init.md.
# Per MEM001 this script is bash 3.2 compatible — no associative arrays,
# no process substitution, no command substitution containing pipes.
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

[ -n "$PROJECT_DIR" ] || { echo "FAIL: wiki-init: --project-dir is required" >&2; exit 2; }
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

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
ORIGIN_URL="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)"
if [ -z "$ORIGIN_URL" ]; then
  echo "FAIL: wiki-init: no git remote at origin in $PROJECT_DIR; configure one with 'git remote add origin <url>' before running wiki-init" >&2
  exit 4
fi

# Parse <owner>/<repo> from either https or ssh remote shapes.
# Examples:
#   https://github.com/Build-Fractal/spec-kit-orchestrator(.git)
#   git@github.com:Build-Fractal/spec-kit-orchestrator(.git)
OWNER_REPO="$(echo "$ORIGIN_URL" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##')"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ "$OWNER" = "$OWNER_REPO" ]; then
  echo "FAIL: wiki-init: cannot parse <owner>/<repo> from origin URL '$ORIGIN_URL'" >&2
  exit 4
fi

# Synthesize templated values.
SITE_NAME="${SITE_NAME_OVERRIDE:-$REPO}"
SITE_DESCRIPTION="${SITE_DESCRIPTION_OVERRIDE:-}"
SITE_URL="https://${OWNER}.github.io/${REPO}/"
REPO_URL="https://github.com/${OWNER}/${REPO}"

# FR-5 step (a): stage wiki tooling via P01 reader + mode handler.
# The bundle staging loop reuses the P01 read-project-assets / install-asset-mode helpers.
# Only the wiki-related project_assets entry is staged here (the four runtime dirs
# are P01's responsibility under install-{claude-code,codex,cursor}.sh).
TUPLES="$(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" || true)"
if [ -z "$TUPLES" ]; then
  echo "FAIL: wiki-init: read-project-assets.sh emitted zero tuples; check $REPO_ROOT/packaging/bundle/manifest.yml for project_assets section" >&2
  exit 6
fi

# Iterate tuples — stage only entries whose source begins with 'wiki' under wiki-init's responsibility.
# (The four runtime-dir entries are staged by install-claude-code.sh / install-codex.sh / install-cursor.sh.)
echo "$TUPLES" | while IFS= read -r tuple; do
  src="$(echo "$tuple" | awk -F'\t' '{print $1}' | sed 's/^source=//')"
  tgt="$(echo "$tuple" | awk -F'\t' '{print $2}' | sed 's/^target=//')"
  mode="$(echo "$tuple" | awk -F'\t' '{print $3}' | sed 's/^mode=//')"
  case "$src" in
    wiki/|wiki) : ;;  # stage
    *) continue ;;    # skip non-wiki entries (handled by installers in P01)
  esac
  src_abs="$REPO_ROOT/$src"
  tgt_abs="$PROJECT_DIR/$tgt"
  bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" "$tgt_abs" "$PROJECT_DIR" "$tgt"
  bash "$REPO_ROOT/scripts/lifecycle/install-asset-mode.sh" "$src_abs" "$tgt_abs" "$mode" "$PROJECT_DIR"
done

# FR-6: sed-substitute the four placeholders in the staged mkdocs.yml.
MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"
if [ -f "$MKDOCS_TARGET" ]; then
  # Idempotency: detect if placeholders remain. If none remain AND --force is not set, emit "no changes" and exit 0.
  if ! grep -q '{{site_name}}\|{{site_description}}\|{{site_url}}\|{{repo_url}}' "$MKDOCS_TARGET" && [ "$FORCE" != "1" ]; then
    echo "wiki-init: no changes (mkdocs.yml already templated; pass --force to re-substitute)"
  else
    # Use a sed -i delimiter '|' to avoid escaping forward slashes in URLs.
    tmp="$(mktemp)"
    sed -e "s|{{site_name}}|${SITE_NAME}|g" \
        -e "s|{{site_description}}|${SITE_DESCRIPTION}|g" \
        -e "s|{{site_url}}|${SITE_URL}|g" \
        -e "s|{{repo_url}}|${REPO_URL}|g" \
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
    pip3 install -r "$REQ_FILE" || { echo "FAIL: wiki-init: pip3 install -r $REQ_FILE failed" >&2; exit 6; }
  else
    echo "wiki-init: Python deps not installed. Run 'pip3 install -r $REQ_FILE' or re-invoke with --auto-pip"
  fi
fi

echo "wiki-init: done (project=$PROJECT_DIR site_name=${SITE_NAME})"
exit 0
```

3. **Amend `wiki/mkdocs.yml`** by replacing the four hardcoded site-identity values at lines 10-13 with `{{...}}` placeholders. Exact replacements:

```diff
-site_name: "spec-kit-orchestrator — dogfood wiki"
-site_description: "Browseable projection of .orchestrator/ artifacts for the dogfood team."
-site_url: "https://build-fractal.github.io/spec-kit-orchestrator/"
-repo_url: "https://github.com/Build-Fractal/spec-kit-orchestrator"
+site_name: "{{site_name}}"
+site_description: "{{site_description}}"
+site_url: "{{site_url}}"
+repo_url: "{{repo_url}}"
```

This is the BUNDLE-STAGED state. The orchestrator-repo-local resolved state is restored in step 5 below by running `wiki-init.sh --project-dir .`.

4. **Amend `packaging/bundle/manifest.yml`** by adding a `wiki/` entry at the END of the existing P01 `project_assets:` block. The four pre-existing entries (`commands/`, `scripts/`, `references/`, `templates/`) MUST be byte-preserved. Exact append (after the last `mode: copy` line of the four pre-existing entries):

```yaml
  - source: wiki/
    target: wiki/
    mode: copy
```

5. **Close the FR-6 self-application loop within this task per AD-5 / MIT-002**. Run, in order, from the orchestrator repo root:

```bash
bash scripts/lifecycle/wiki-init.sh --project-dir .
```

This invocation:
- Probes python3/pip3 (orchestrator dev box has them per A-2 implication).
- Parses the orchestrator's own git remote (`https://github.com/Build-Fractal/spec-kit-orchestrator`) → `OWNER=Build-Fractal`, `REPO=spec-kit-orchestrator`.
- Synthesizes the four values (`site_name=spec-kit-orchestrator`, `site_url=https://build-fractal.github.io/spec-kit-orchestrator/`, `repo_url=https://github.com/Build-Fractal/spec-kit-orchestrator`, `site_description=`).
- Sed-substitutes the four placeholders in `wiki/mkdocs.yml` (resolving them back to working values).
- After this step the orchestrator-repo-local `wiki/mkdocs.yml` carries RESOLVED values and `bash scripts/wiki/wiki-serve.sh` continues to function.

Note: the bundle-staged copy at `wiki/` (which IS this same path because the manifest's `wiki/` entry uses `source: wiki/`) ends up resolved to orchestrator-identity values. This is acceptable because external consumers re-run sed-substitution against THEIR git remote when they invoke `wiki-init.sh --project-dir <consumer>` — the substitution is idempotent against placeholders AND against already-resolved values, because `--site-name=<consumer-repo>` etc. would re-substitute via the `--force` flag. Verifier `m032-p02-mkdocs-templating-and-self-application.sh` asserts BOTH (a) the orchestrator-repo-local `wiki/mkdocs.yml` carries resolved orchestrator values AND (b) `bash scripts/wiki/wiki-serve.sh --check-only` (or equivalent — `wiki-serve.sh` must return HTTP 200 in a startup probe) succeeds.

Important: the `wiki-init.sh` invocation against `--project-dir .` will route through `read-project-assets.sh` which iterates ALL five tuples (the four runtime dirs + the new wiki entry); the script's filter at step 2 above (`case "$src" in wiki/|wiki) ... esac`) ensures only the wiki entry is staged. The four runtime-dir tuples are skipped (they belong to the three installers' staging loops in P01).

6. **Author the three T01 verifiers** under `tools/verify/`:

   **`m032-p02-wiki-init-command-shape.sh`** — asserts `commands/wiki-init.md` exists, has YAML frontmatter with a `description:` field, has the seven required sections from MEM012 (`Title`, `Prerequisites`, `Core Workflow`, `Output`, `Idempotency`, `Error Handling`, `Referenced Scripts`), references `scripts/lifecycle/wiki-init.sh` as the canonical implementation, and mentions FR-5 + FR-12 by name. Single-script-file shape per AD-19. Example skeleton:

```bash
#!/usr/bin/env bash
set -eu
DOC="commands/wiki-init.md"
[ -f "$DOC" ] || { echo "FAIL: $DOC missing"; exit 1; }
grep -q '^description:' "$DOC" || { echo "FAIL: $DOC missing description: in frontmatter"; exit 1; }
grep -q '^# orchestrator:wiki-init' "$DOC" || { echo "FAIL: $DOC missing title heading"; exit 1; }
grep -q '^## Prerequisites' "$DOC" || { echo "FAIL: $DOC missing Prerequisites section"; exit 1; }
grep -q '^## Core Workflow' "$DOC" || { echo "FAIL: $DOC missing Core Workflow section"; exit 1; }
grep -q '^## Output' "$DOC" || { echo "FAIL: $DOC missing Output section"; exit 1; }
grep -q '^## Idempotency' "$DOC" || { echo "FAIL: $DOC missing Idempotency section"; exit 1; }
grep -q '^## Error Handling' "$DOC" || { echo "FAIL: $DOC missing Error Handling section"; exit 1; }
grep -q '^## Referenced Scripts' "$DOC" || { echo "FAIL: $DOC missing Referenced Scripts section"; exit 1; }
grep -q 'scripts/lifecycle/wiki-init.sh' "$DOC" || { echo "FAIL: $DOC missing reference to scripts/lifecycle/wiki-init.sh"; exit 1; }
grep -q 'FR-5' "$DOC" || { echo "FAIL: $DOC missing FR-5 reference"; exit 1; }
grep -q 'FR-12' "$DOC" || { echo "FAIL: $DOC missing FR-12 reference"; exit 1; }
echo "PASS: m032-p02-wiki-init-command-shape"
```

   **`m032-p02-wiki-init-default-scope.sh`** — exercises `wiki-init.sh` against the P01 fresh-project fixture: stages a temp copy of the fixture via `mktemp -d` + `cp -R`, initializes a fake git remote pointing at `https://github.com/fixture-owner/m032-fresh-project-fixture.git`, runs `bash scripts/lifecycle/wiki-init.sh --project-dir <tmp>`, asserts `<tmp>/wiki/mkdocs.yml` exists and contains `site_name: m032-fresh-project-fixture` and `repo_url: https://github.com/fixture-owner/m032-fresh-project-fixture` and does NOT contain any `{{site_name}}` placeholder. Also asserts the FR-12 toolchain probe by exporting `PATH=/dev/null` (no python3) and asserting exit code 3 + diagnostic substring.

   **`m032-p02-mkdocs-templating-and-self-application.sh`** — asserts (a) `wiki/mkdocs.yml` after the FR-6 self-application loop in step 5 contains `site_name: "spec-kit-orchestrator` (resolved orchestrator value), (b) does NOT contain literal `{{site_name}}` (placeholder cleared by self-application), (c) the bundle source path (which is the same orchestrator-repo path under `source: wiki/`) is consistent, (d) `bash scripts/wiki/wiki-serve.sh` can start and respond HTTP 200 at `:8000` (use `(wiki-serve.sh & SERVE_PID=$!; sleep 3; curl -fsS http://localhost:8000 -o /dev/null; rc=$?; kill $SERVE_PID; exit $rc)` BUT extracted to a script-file shape per AD-19 — author a tiny helper `tools/verify/lib/m032-p02-wiki-serve-probe.sh` that does the start+probe+kill within a single script body, and have the parent verifier invoke it via `bash tools/verify/lib/m032-p02-wiki-serve-probe.sh`).

7. **Run all three verifiers locally** to confirm exit 0 from each.

## Must-Haves

- `commands/wiki-init.md` exists per the MEM012 structure with FR-5 / FR-12 references and `Referenced Scripts` pointing at `scripts/lifecycle/wiki-init.sh`.
- `scripts/lifecycle/wiki-init.sh` exists, is executable, implements the full default-scope flow, the FR-12 toolchain probe with platform-aware diagnostics, the git-remote-derived `<owner>/<repo>` parsing, the four-placeholder sed-substitution, the `--auto-pip` / `--site-name` / `--site-description` / `--force` / `--with-giscus` (P03-reject) / `--deploy` (P03-reject) flag handling, and idempotent re-run.
- `wiki/mkdocs.yml` carries the four `{{...}}` placeholders at lines 10-13 in the bundle-source state, AND has been resolved back to orchestrator-identity values via the FR-6 self-application loop run inside this task per AD-5 / MIT-002.
- `packaging/bundle/manifest.yml` has the additive `wiki/` entry under `project_assets:`; the four pre-existing P01 entries are byte-preserved.
- The orchestrator's own `bash scripts/wiki/wiki-serve.sh` returns HTTP 200 at `:8000` after the self-application loop completes (closes the FR-6 / MIT-002 self-application loop).
- All three T01 verifiers under `tools/verify/m032-p02-{wiki-init-command-shape,wiki-init-default-scope,mkdocs-templating-and-self-application}.sh` exist, are executable, and exit 0 against the T01-landed surface.

## Verification

```bash
bash tools/verify/m032-p02-wiki-init-command-shape.sh
bash tools/verify/m032-p02-wiki-init-default-scope.sh
bash tools/verify/m032-p02-mkdocs-templating-and-self-application.sh
```

## Inputs

### From Previous Tasks

None within P02. Cross-phase inputs from P01 below.

### From Disk (Pre-existing)

- `packaging/bundle/manifest.yml` — pre-M032 manifest schema + the P01 `project_assets:` section with four entries. Key API: top-level YAML keys (`schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility`, `project_assets`); each `project_assets:` entry has `source:`, `target:`, `mode:` keys. T01 amends the file by appending one new entry (`source: wiki/`, `target: wiki/`, `mode: copy`).
- `scripts/lifecycle/read-project-assets.sh` — P01 reader. Key API: `bash read-project-assets.sh <bundle-dir>` emits one line per `project_assets:` entry as `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` on stdout; exits 0 on success.
- `scripts/lifecycle/install-asset-mode.sh` — P01 per-mode handler. Key API: `bash install-asset-mode.sh <src-abs> <dst-abs> <mode> <project-dir-abs>`; `mode=copy` runs `cp -R "$src/." "$dst/"`; `mode=symlink` is POSIX-only with `M032_FORCE_WINDOWS=1` fail-closed.
- `scripts/lifecycle/install-collision-check.sh` — P01 dual-oracle hierarchy. Key API: `bash install-collision-check.sh <target-abs> <project-dir-abs> <project-assets-target-list>`; exits 0 on no-collision, exits 4 on operator-owned collision with `staged-dirs-collision:` diagnostic.
- `wiki/mkdocs.yml` — orchestrator-repo dogfood wiki config. Lines 10-13 carry the four hardcoded site-identity values that T01 replaces with placeholders.
- `wiki/overrides/partials/comments.html` — orchestrator-repo Giscus partial. T01 does NOT modify; FR-7 templating is P03's deliverable.
- `scripts/wiki/wiki-serve.sh` — pre-existing local-serve helper. Used in step 5 to verify FR-6 self-application loop closure.

## Constraints

- T01 MUST NOT touch any of the P01 deliverables (`packaging/install/install-{claude-code,codex,cursor}.sh`, `scripts/lifecycle/{read-project-assets,install-asset-mode,install-collision-check}.sh`); the P01 surface is consumed via direct invocation, not amended.
- T01 MUST NOT modify `wiki/overrides/partials/comments.html` (P03's `--with-giscus` deliverable).
- T01 MUST NOT split the existing `# >>> M012-P01 nav` markers in `wiki/mkdocs.yml` into auto-nav / custom-nav regions (P03's deliverable).
- The FR-6 self-application loop MUST run within this task per AD-5 / MIT-002 — failure to close the loop within T01 leaves the orchestrator's own wiki broken. The verifier `m032-p02-mkdocs-templating-and-self-application.sh` enforces this with the live `wiki-serve.sh` HTTP probe.
- All three T01 verifiers MUST use single-script-file shape per AD-19 — no inline compound bash, no plain subshells with sourcing, no command substitution containing pipes, no process substitution. The `wiki-serve.sh` HTTP probe is extracted to a separate helper script `tools/verify/lib/m032-p02-wiki-serve-probe.sh` to keep the parent verifier's invocations within the AD-19 envelope.
- The `wiki-init.sh` script MUST be bash 3.2 compatible per MEM001 — no `declare -A`, no `mapfile`, no process substitution, no `$()` containing pipes that exceed AD-19's one-pipe budget within compound contexts. Use parallel indexed arrays or line-by-line `while IFS= read -r` loops for any aggregate handling.
- `commands/wiki-init.md` MUST follow the MEM012 structure exactly — frontmatter with `description:`, the seven section headers in order, and a `Referenced Scripts` section pointing at `scripts/lifecycle/wiki-init.sh`.
- The bundle vs orchestrator-local distinction described in the Description section MUST be preserved: a bundle pull by an external consumer running `wiki-init.sh --project-dir <consumer>` MUST re-substitute against the consumer's git remote (idempotency against either placeholders or already-resolved values via `--force`).

## Expected Output

After T01 completes:

- `commands/wiki-init.md` is a new file at the orchestrator-repo root following MEM012 structure with FR-5 + FR-12 references.
- `scripts/lifecycle/wiki-init.sh` is a new executable file at the orchestrator-repo root implementing the full default-scope flow.
- `wiki/mkdocs.yml` carries the four `{{...}}` placeholders in the bundle-source state AND has been re-substituted to orchestrator-identity values via the FR-6 self-application loop. After the loop the file at this path looks identical to the pre-M032 state for `site_name` / `site_description` / `site_url` / `repo_url` (resolved values), with the placeholders only briefly observable during the substitution window (which is the correct behavior — the orchestrator's wiki must continue to render under `wiki-serve.sh`).
- `packaging/bundle/manifest.yml` has one additional `project_assets:` entry (`source: wiki/`, `target: wiki/`, `mode: copy`) appended after the four pre-existing P01 entries.
- The orchestrator's own `bash scripts/wiki/wiki-serve.sh` returns HTTP 200 at `:8000`.
- All three T01 verifiers exit 0.

## Notes

- Expected `wiki-init.sh` exit codes: 0 (success or no-changes idempotency), 2 (argument error), 3 (toolchain missing), 4 (git remote missing/unparseable), 5 (P03 flag passed in P02), 6 (bundle staging failure).
- The `wiki-init.sh` filter at step 2 above (`case "$src" in wiki/|wiki) ... esac`) is the seam that lets `wiki-init.sh` co-exist with the three installers' staging loops without double-staging the four runtime dirs. The filter is verified indirectly via `m032-p02-wiki-init-default-scope.sh` (which asserts `<fixture>/commands/`, `<fixture>/scripts/`, etc. are NOT created by `wiki-init.sh` against a fresh fixture).
- The bundle-source `wiki/mkdocs.yml` carries placeholders only in the brief window between step 3 and step 5. After step 5 it carries resolved orchestrator values. External consumers re-stage from the bundle (which by the time they pull is a git-tracked copy with resolved values) AND re-substitute against THEIR git remote — the substitution is idempotent against resolved values via `--force`.
- The single-script-file constraint per AD-19 forbids the inline `(wiki-serve.sh & ... ; kill $SERVE_PID)` shape directly under `## Verification`; the verifier `m032-p02-mkdocs-templating-and-self-application.sh` invokes a helper `tools/verify/lib/m032-p02-wiki-serve-probe.sh` that performs the start+probe+kill within a single script body. The helper script is co-authored alongside the verifier in this task.
- Plan-time discipline rule 2 (verifier-availability cross-check) is honored: all three verifiers cited in `## Verification` are co-authored within this task in step 6.
- Plan-time discipline rule 6 (path-collision check): `commands/wiki-init.md`, `scripts/lifecycle/wiki-init.sh`, `tools/verify/m032-p02-wiki-init-command-shape.sh`, `tools/verify/m032-p02-wiki-init-default-scope.sh`, `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh`, and `tools/verify/lib/m032-p02-wiki-serve-probe.sh` do NOT exist on disk at plan-authoring time (verified). `wiki/mkdocs.yml` and `packaging/bundle/manifest.yml` are explicitly modified, not created.
