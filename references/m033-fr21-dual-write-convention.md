# FR-21 Dual-Write Recent Changes Convention (M033)

> **Status:** SSOT for M033 P03/P04/P05 calling commands.
> **Spec:** 036-project-onboarding-experience (FR-21).
> **Inheritance source:** 035 (M014 dual-write helper), closed milestone.
> **Owning task:** M033/P02/T05.

## Purpose

Every M033 calling command that materially mutates project state MUST
append a one-line fragment to the `# >>> orchestrator:recent-changes >>>`
region in `CLAUDE.md` and (subject to the `dual_write_agents` config flag)
`AGENTS.md`. This document is the SSOT P03/P04/P05 implementations
read against; the verifier `tools/verify/m033-p02-fr21-convention-shape.sh`
greps this file for the load-bearing tokens.

This convention is an **inheritance from M014/spec 035**, not a new
contract. M014 shipped the `scripts/util/dual-write-runtime-md.sh`
helper and the dual-region marker pair on both runtime instruction
files. M033 reuses that surface; we do not extend it.

## Inheritance from M014/spec 035

The dual-write helper `scripts/util/dual-write-runtime-md.sh` ships as
part of M014 (closed) and is invoked by every M033 calling command.
The convention is an inheritance, not a new contract. Spec 035 owns
the helper's contract, the dual-region marker pair, and the merge
semantics. M033's only responsibility is to **call into** the helper at
the FR-21 sites enumerated below.

If the helper's behavior changes, that change is owned by spec 035 and
its successors — not by M033. M033 carries no helper-internal
assumptions beyond the public CLI shape documented under "Call-site
shape" below.

## Call-site shape

The canonical invocation, used at every FR-21 site:

```bash
bash scripts/util/dual-write-runtime-md.sh \
    --root <project-dir> \
    --marker recent-changes \
    --append-entry "<one-line-fragment>"
```

The helper writes the fragment to the
`# >>> orchestrator:recent-changes >>>` region in `CLAUDE.md` and
(if `dual_write_agents` is not `false` in `.orchestrator/config.yml`)
also to `AGENTS.md`. Calling commands MUST NOT pre-format with
markdown bullets — the helper owns the bullet shape. The `--root`
flag targets the project-local runtime-md (NOT the orchestrator
repo's own file). The marker region name is `recent-changes`
(matches the `# >>> orchestrator:recent-changes >>>` block).

### Aliases / historical wording

Earlier drafts of this convention referenced a positional shorthand
`bash scripts/util/dual-write-runtime-md.sh append "<fragment>"`. That
shorthand is **not implemented** — the helper accepts only the flag
form documented above (verified at `scripts/util/dual-write-runtime-md.sh`
USAGE block). Calling commands MUST use the `--root` / `--marker` /
`--append-entry` flag form. The `append` keyword appears in this
document only as a verb in prose, not as a CLI subcommand.

The `dual_write_agents: false` config-respect note is load-bearing:
projects that ship without a Codex CLI / Cursor instruction file can
opt out of the AGENTS.md leg. The helper is the only surface that
reads that config flag; calling commands MUST NOT branch on it
themselves.

## Per-command fragment templates

Five M033 calling commands ship FR-21 dual-write call-sites, one each
under FR-3, FR-7, FR-9, FR-10, FR-13:

- `orchestrator:constitution` (FR-3) — `- M033/{stack}: constitution authored from {stack} starter`
- `orchestrator:ingest-codebase` (FR-7) — `- M033/ingest-codebase: seeded {N} MEMs from existing repo`
- `orchestrator:materials-intake` (FR-9) — `- M033/materials-intake: reconciled {N} conflicts; pre-spec at {path}`
- `orchestrator:ideation` (FR-10) — `- M033/ideation: 7-question ideation pre-spec at {path}`
- `orchestrator:customblock-draft` (FR-13) — `- M033/customblock-draft: populated 5-section custom block from upstream sub-flows`

The `{placeholder}` fields are filled by the calling command at
invocation time. The leading `M033/` prefix is required so M033
recent-changes lines are visually attributable in the future.

Lines remain a single line — the helper enforces no embedded newlines.

## Fenced SSOT block

The verifier reads this block by literal token. Do not edit without a
P02-PLAN.md amendment.

```
# >>> fr-21-dual-write-callsites >>>
# FR-3  constitution-authored : commands/constitution.md
# FR-7  ingest-codebase       : commands/ingest-codebase.md
# FR-9  materials-intake      : commands/materials-intake.md
# FR-10 ideation              : commands/ideation.md
# FR-13 customblock-drafted   : commands/customblock-draft.md
# <<< fr-21-dual-write-callsites <<<
```

Each row binds an FR ID to the command file that owns the call-site.
The verifier asserts all five FR IDs and all five command basenames
appear inside this fenced region.

## Cross-references

- `scripts/util/dual-write-runtime-md.sh` — M014 closed deliverable, the
  helper invoked at every FR-21 site. M033 does not modify it.
- `dual_write_agents` — `.orchestrator/config.yml` flag honored by the
  helper. Default is `true`. Setting to `false` skips the AGENTS.md
  leg without changing CLAUDE.md behavior.
- Spec 035 — dual-write parent specification (M014).
- Spec 036, FR-21 — the M033 site that pulls this convention forward.
- `commands/constitution.md`, `commands/ingest-codebase.md`,
  `commands/materials-intake.md`, `commands/ideation.md`,
  `commands/customblock-draft.md` — the five P03/P04/P05 calling
  commands that consume this SSOT.

## Non-goals

- Schema evolution: the recent-changes line shape is M014/spec 035
  territory. Bumping to a multi-line / structured format is outside
  M033 scope.
- Read-side parsing: M033 ships no recent-changes-line consumer. This
  is a write-side discipline document only.
