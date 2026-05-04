---
description: "Use when initializing a wiki for a project — installs wiki tooling from the bundle, templates mkdocs.yml from the project's git remote, and probes Python toolchain. Default scope; --with-giscus and --deploy compose on top (P03 deliverables)."
---

# orchestrator:wiki-init

Initialize a working mkdocs Material wiki for any orchestrator-managed project. Default scope (no extension flags) stages the wiki tooling from `packaging/bundle/` via the P01 `project_assets:` entry, probes the Python toolchain (FR-12), parses the project's git `origin` remote, and sed-substitutes the four `{{...}}` site-identity placeholders in `wiki/mkdocs.yml` (FR-5 + FR-6).

The `--with-giscus` and `--deploy` extension scopes are P03 deliverables; this P02 surface ships only the default scope plus the `--auto-pip` opt-in (#Q-2).

## Prerequisites / State Check

- `packaging/bundle/manifest.yml` carries a `project_assets:` entry with `source: wiki/` (P01 + P02/T01 deliverable).
- The consumer project has a git remote at `origin` pointing at `https://github.com/<owner>/<repo>` (parsed for templated values).
- `python3` and `pip3` are on `PATH` (probed at invocation; missing toolchain fails closed with platform-aware diagnostic per FR-12).
- `wiki/` does not pre-exist as an operator-owned directory (FR-22 collision-check), unless this is a self-application loop where the orchestrator repo is its own consumer (`--project-dir .` against the orchestrator repo).

## Core Workflow

### Default scope (no extension flags)

1. Read wiki tooling from `project_assets:` entries via `scripts/lifecycle/read-project-assets.sh` (FR-5).
2. Probe `python3` and `pip3` on `PATH`. Missing toolchain → fail closed (exit 3) with `brew install python3` (darwin) or `apt install python3` (linux) per FR-12.
3. Parse `git -C "$PROJECT_DIR" remote get-url origin` to derive `<owner>/<repo>`. Synthesize the four `{{...}}` values:
   - `site_name`: `<repo>` (default; overridable via `--site-name`).
   - `site_description`: empty string default; overridable via `--site-description`.
   - `site_url`: `https://<owner>.github.io/<repo>/`.
   - `repo_url`: `https://github.com/<owner>/<repo>`.
4. Stage `wiki/` to `<PROJECT_DIR>/wiki/` via the P01 mode handler (`install-asset-mode.sh`) under FR-22 collision-check (`install-collision-check.sh`). Self-application detection: when the bundle root and the project directory resolve to the same path, the staging step is a no-op (the bundle IS the target).
5. Sed-substitute the four `{{...}}` placeholders in the staged `<PROJECT_DIR>/wiki/mkdocs.yml`.
6. Stage `wiki/overrides/partials/comments.html` UNCHANGED (Giscus partial templating is P03's `--with-giscus` deliverable).
7. Author `<PROJECT_DIR>/wiki/glossary.md` as a path-convention stub (FR-15 — T03 of P02 lands the orchestrator-repo-level canonical version; T01 ships only the consumer-side stub-author logic).
8. Optional `--auto-pip` flag runs `pip3 install -r <PROJECT_DIR>/wiki/requirements.txt` per #Q-2; default behavior is print-and-exit.

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

A second invocation against an already-`wiki-init`'d project preserves operator edits to the templated files and exits 0 with `no changes` on stdout. The four `{{...}}` placeholder tokens are NOT re-substituted on re-run unless `--force` is passed (US-2 Acceptance Scenario 5). The glossary stub is preserved if present.

## Error Handling

- Missing `python3` or `pip3` → exit 3 with platform-aware diagnostic (`brew install python3` on darwin; `apt install python3` on linux); writes nothing.
- `git remote get-url origin` fails (no remote configured) → exit 4 with `wiki-init: no git remote at origin in <project-dir>; configure one with 'git remote add origin <url>' before running wiki-init`.
- `--with-giscus` or `--deploy` passed → exit 5 with `not yet implemented in P02; reserved for P03`.
- Bundle staging failure (read-project-assets.sh or install-asset-mode.sh) → exit 6.
- Unknown argument → exit 2.

## Referenced Scripts

- `scripts/lifecycle/wiki-init.sh` — canonical implementation.
- `scripts/lifecycle/read-project-assets.sh` — bundle reader (P01).
- `scripts/lifecycle/install-asset-mode.sh` — per-mode handler (P01).
- `scripts/lifecycle/install-collision-check.sh` — FR-22 dual-oracle hierarchy (P01).
