# Contributing to the orchestrator

Thanks for your interest. The orchestrator is a standalone, autonomous
multi-phase orchestration layer for Claude Code (with Codex/Cursor as
demand-driven fast-follows). This guide covers how to get a dev environment
going, the conventions that keep changes safe, and how the project develops
itself.

## Ways to contribute

- **Report a bug or request a feature** — open a [GitHub issue](https://github.com/Build-Fractal/orchestrator/issues) using one of the templates.
- **Ask a question / share usage** — GitHub Discussions (when enabled) or an issue.
- **Send a pull request** — see [Pull requests](#pull-requests) below. Small, focused PRs land fastest.

## Development setup

```bash
git clone https://github.com/Build-Fractal/orchestrator.git
cd orchestrator
```

Requirements: **Bash 3.2+** (the macOS system default — we target it deliberately), `git`, and optionally `jq` (some scripts use it when present, none require it). `node >= 14` only if you touch the npm packaging path.

The orchestrator dogfoods itself: it installs into its own repo. To exercise your changes against a project, run the installer with `--mode symlink` so the project points at your working tree:

```bash
bash packaging/install/install-claude-code.sh --project-dir /path/to/a/test/project --mode symlink
```

## Running tests

There is no single test runner; suites are standalone scripts you run directly.

- **Structural + behavioral suites** live under `tests/` (e.g. `bash tests/test-s01-structure.sh`, `tests/test-s04-core-commands.sh`).
- **Per-milestone acceptance batteries** live under `tools/verify/` (e.g. `bash tools/verify/m042-p01-acceptance-battery.sh`). Each prints `PASS:`/`FAIL:` lines and a `BATTERY: pass=N fail=M` summary, exiting non-zero on any failure.
- **Doctor** (`bash scripts/diagnostics/run-doctor.sh`) reports project health; checks emit `DOCTOR:<NAME> status=ok|warn|fail`.

Run the suites relevant to what you changed, plus `tests/test-s01-structure.sh` and `tests/test-s04-core-commands.sh` as a baseline. New behavior should ship with a fixture-backed test (prefer **byte-equality** fixtures over substring asserts).

## Code conventions

- **Bash 3.2 compatible.** No `declare -A` (associative arrays), no `mapfile`/`readarray`, no in-place case-modification (`${v,,}`/`${v^^}`), no process substitution. Helper scripts are POSIX-leaning where practical.
- **Graceful degradation / fail-open.** Optional dependencies (conversus, `gh`, `jq`) must degrade with a diagnostic, not hard-fail. State on disk is the source of truth.
- **State lives under `.orchestrator/`.** Don't hold runtime state in memory across steps.
- **Read the [Constitution](.orchestrator/memory/constitution.md)** — seven principles (Context Minimization, Evidence Before Claims, Design Before Code, Plans Assume Zero Context, Fresh Context Per Unit, State On Disk Is Truth, Knowledge Compounds) plus governance principles. They govern design decisions and review.
- **Forbidden command shapes are linted.** A PreToolUse hook (and `ANTIPATTERNS.md`) reject certain Bash shapes — notably long compound chains (`A && B && C`, AP-009). When you need to probe several things, use `scripts/util/run-probe.sh` rather than chaining. This keeps autonomous runs from tripping harness safety heuristics.

## Commit messages

- Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`. Scope with the milestone where relevant: `feat(M042): …`.
- **For multi-line messages, author a message file and use `git commit -F <file>`.** Do *not* use the inline-HEREDOC form `git commit -m "$(cat <<'EOF' … EOF)"` — the active Bash shape-guard rejects it (the inline `$(…)` wrapping a heredoc reads as a compound substitution). `-F` survives every path. Single-line messages can use `-m "…"`.
- End commit messages with a trailer crediting any AI assistance you used.

## Pull requests

1. Branch from `main`: `git checkout -b feat/<short-name>` (or `fix/`, `docs/`).
2. Keep the diff focused; restore any incidental churn (e.g. knowledge-graph `hit_count` bumps that test runs produce) so the PR is feature-only.
3. Run the relevant suites + `run-doctor.sh`; paste the `BATTERY:` lines in the PR description.
4. Update `CHANGELOG.md` under `## [Unreleased]` for user-visible changes.
5. Open the PR against `main` and link the issue it addresses.

CI (`.github/workflows/`) runs shape verifiers on every PR; the publish workflow only fires on `v*` tags (maintainers — see [Releasing](references/RELEASING.md)).

## How the project develops itself

The orchestrator builds itself with its own SDD workflow:

```
orchestrator:evaluate → discuss (Tier C) → roadmap → plan-phase
  → auto / dispatch → verify → consolidate
```

Milestones live under `.orchestrator/milestones/M###/` (evaluation, roadmap, phase plans, summaries, a `M###-VALIDATED` marker on close). Feature proposals are captured under `.orchestrator/proposals/` before they become milestones. Reading a recent closed milestone (e.g. `.orchestrator/milestones/M042/`) is the fastest way to learn the artifact shapes a contribution is expected to produce.

## Where things live

| Path | What |
|------|------|
| `commands/` | Command/skill instruction documents (the `orchestrator:*` surface) |
| `scripts/` | Helper scripts by concern: `state/`, `dispatch/`, `engine/`, `verify/`, `knowledge/`, `lifecycle/`, `diagnostics/`, `util/` |
| `templates/` | Output + config templates |
| `references/` | Architecture, file formats, state machine, installation, releasing, etc. |
| `docs/` | User guides (getting started, hooks, knowledge, recipes, migration) |
| `packaging/` | Installable bundle + per-runtime installers + npm/homebrew/curl publishing |
| `tests/`, `tools/verify/` | Test suites + per-milestone acceptance batteries |
| `.orchestrator/` | This repo's own orchestrator state (constitution, knowledge, decisions, milestones, proposals) |

## Code of conduct

Be respectful and constructive. We follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/);
report unacceptable behavior via a GitHub issue or to the maintainers.

## License

By contributing, you agree your contributions are licensed under the repository's [MIT License](LICENSE).
