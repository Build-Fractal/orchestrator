# SKILL.md — Open Skill File Specification

Version: 1.0
Status: Draft (M008/P06)

## Purpose

A **skill file** is a thin, runtime-agnostic discovery surface for one
orchestrator command. It tells a host runtime (Claude Code, Codex, Cursor, or
any future tool that enumerates skills from disk) what the command is called,
what namespace it belongs to, when to use it, and where the canonical behavior
definition lives.

The format is deliberately **open**: it is a plain Markdown file with a small
YAML frontmatter block. No proprietary schema, no runtime-specific extensions.
A third party can produce compatible skill files for any tool without
coordinating with this project. Conversely, this project's skill files can be
consumed by any runtime that agrees to read the same frontmatter keys.

Skill files are **not** the source of truth. They point back to
`commands/<cmd>.md`, which remains the single canonical behavior document.
This keeps the skill bundle small, avoids duplication, and lets downstream
runtimes decide how much of the command document to materialize locally.

## Frontmatter Schema

Every skill file begins with a YAML frontmatter block delimited by `---`
lines. The following keys are defined for `schema_version: "1.0"`:

| Key                    | Type   | Required | Description                                                              |
| ---------------------- | ------ | -------- | ------------------------------------------------------------------------ |
| `schema_version`       | string | yes      | Literal `"1.0"` for this revision.                                       |
| `type`                 | string | yes      | Literal `"skill"`.                                                       |
| `name`                 | string | yes      | Human-readable label, e.g. `orchestrator:evaluate`.                      |
| `namespace`            | string | yes      | Fixed literal `orchestrator` for this project.                           |
| `description`          | string | yes      | One-sentence trigger hint shown to the agent when routing decisions happen. |
| `runtime_compatibility`| list   | yes      | Any non-empty subset of `claude-code`, `codex`, `cursor`.                |
| `command_file`         | string | yes      | Repo-relative path back to the canonical `commands/<cmd>.md` document.   |

Future schema revisions may add optional keys; consumers MUST ignore unknown
keys rather than erroring. Required keys above are stable for `1.0`.

The literal YAML keys that MUST appear in every skill file are therefore:
`schema_version:`, `type:`, `name:`, `namespace:`, `description:`,
`runtime_compatibility:`, and `command_file:`.

### Name and Namespace

The `namespace` key establishes a flat prefix that runtimes use to disambiguate
skills from multiple providers. For this project the value is always
`orchestrator`. The `name` key always takes the form `orchestrator:<cmd>` where
`<cmd>` matches the basename (without extension) of the `command_file`.

The `orchestrator:*` namespace mapping is documented further in
`scripts/state/namespace-aliases.sh`, which runtimes use at install time to
translate between the namespaced label and any legacy `speckit.orchestrator.*`
aliases that predate this format.

## Body Conventions

The body of a skill file is deliberately thin — typically 3 to 6 lines.
It MUST contain:

1. A level-1 Markdown heading matching the `name` field.
2. A short paragraph noting that canonical behavior lives in the referenced
   `command_file`, with a Markdown link pointing at it.
3. A one-line note that the skill file is a pure discovery surface for
   runtimes that enumerate skills from disk.

The body MUST NOT duplicate content from the command document. If a runtime
needs the full behavior specification, it follows the link. This single-source
convention lets `commands/<cmd>.md` evolve without forcing skill regeneration
for prose-only edits, while still flagging real contract drift via the
`generate-skills.sh --check` helper.

## Discovery Conventions

Runtimes enumerate skills from well-known directories. The canonical locations
this project's installers target are:

| Runtime        | Scope          | Location                                                     |
| -------------- | -------------- | ------------------------------------------------------------ |
| `claude-code`  | user-level     | `$HOME/.claude/commands/orchestrator-<cmd>.md`              |
| `codex`        | user-level     | `$HOME/.codex/skills/orchestrator-<cmd>.md`                 |
| `cursor`       | project-level  | `<project>/.cursor/rules/orchestrator-<cmd>.md`             |

File basenames always use the hyphen form `orchestrator-<cmd>.md` regardless
of the colon form used inside `name:`. The colon form is reserved for in-memory
labels; the hyphen form is reserved for filesystem paths (which cannot contain
colons on every platform).

## Versioning

Individual skill files do not carry a `version:` key. Instead, they inherit
the bundle version from `packaging/bundle/manifest.yml` via its top-level
`version:` field. Installers surface the bundle version to the runtime so a
skill can report which release it belongs to.

When `packaging/bundle/manifest.yml` is absent (for example, during
development before the bundle is assembled), downstream tools SHOULD treat
the effective version as the fallback literal `0.3.0-dev`.

## Regeneration

The file set under `packaging/skills/orchestrator-*.md` is produced
mechanically from `commands/*.md` by `scripts/packaging/generate-skills.sh`.
Running the generator with no arguments rewrites the skill files; running it
with `--check` re-generates into a temp directory and exits non-zero if the
output differs from the committed files. Drift detection is how we keep the
thin discovery surface honest against the canonical command documents.

## Rationale

Thin, frontmatter-only skill files minimize payload size for runtimes that
load all discovered skills eagerly, while the open schema means this project
does not have to ship a custom loader for every host. The single-source
convention (skills point at commands) also means bug fixes and behavior
refinements land in exactly one place and flow through regeneration to every
runtime surface automatically.
