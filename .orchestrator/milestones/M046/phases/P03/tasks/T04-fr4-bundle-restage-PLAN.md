---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M046"
name: "FR-4 orchestrator-do bundle-skill migration wiring"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T02 completed: `commands/do.md` is the deprecation-shim doc and
  `scripts/intake/do-entry.sh` is the forwarding shim.
- `packaging/bundle/manifest.yml` exists with a `skills:` list of 13 entries
  (no `orchestrator-do.md`).
- `packaging/bundle/build-bundle.sh` exists with `EXPECTED_SKILLS=13` and an
  `EXPECTED_SKILL_NAMES` list (13 names, no `orchestrator-do.md`).
- `packaging/skills/` is the source dir `build-bundle.sh` rebuilds `skills/` from.

## Description

Make FR-4 real and testable: `orchestrator:do` was never a shipped consumer skill
(verified at plan time — absent from the manifest, the `skills/` dir, and the
build-bundle expected set). US2-AS-2 assumes a "staged orchestrator-do skill" that
the `orchestrator:update` re-stage path re-installs. To honor that, add
`orchestrator-do.md` as a deprecation-shim skill to the bundle so the update
re-stage path re-installs it and a non-updated consumer gets the deprecation notice
rather than a missing-command error.

**Operator veto note (do not remove — surfaced for execution-time confirmation):**
Since no external consumer ever had `orchestrator:do`, an alternative reading is
that no external migration is owed and the shim serves only this repo's dogfood +
direct `do-entry.sh` scripted callers, in which case this task is a no-op and the
FR-4 verifier (T05) instead asserts only that the shim files bulk-stage via the
`commands/`+`scripts/` framework dirs. The plan takes the spec-literal path (ADD
the skill). If the operator vetoes at execution time, drop this task and adjust the
T05 `m046-p03-update-restage.sh` assertion accordingly.

## Steps

1. Create `packaging/skills/orchestrator-do.md` — a short deprecation-shim skill.
   Match the frontmatter shape of the sibling `packaging/skills/orchestrator-auto.md`
   (read it first for the exact `name:` / `description:` field convention). Body:
   a DEPRECATED banner, "use `orchestrator:auto <task>` instead", the D021 removal
   runway (retained through at least the next published minor; removal no earlier
   than one published release after this deprecation ships; notice names the target
   version), and a pointer that all behavior forwards to the unified entry. Must
   contain the token "deprecat".

2. Add `orchestrator-do.md` to `packaging/bundle/manifest.yml`'s `skills:` list.
   Insert it in sorted position (after `orchestrator-discuss.md`, before
   `orchestrator-dispatch.md` — alphabetical: `do` sorts before `dispatch`? No:
   `orchestrator-discuss` < `orchestrator-dispatch` < `orchestrator-do` is FALSE —
   `di` < `do`, so `orchestrator-do.md` sorts AFTER both `discuss` and `dispatch`,
   before `orchestrator-doctor.md`). Place it between `orchestrator-dispatch.md`
   and `orchestrator-doctor.md`.

3. In `packaging/bundle/build-bundle.sh`: bump `EXPECTED_SKILLS=13` → `14` and add
   `orchestrator-do.md` to `EXPECTED_SKILL_NAMES` in the same sorted position
   (between `orchestrator-dispatch.md` and `orchestrator-doctor.md`).

4. Regenerate the bundle so `packaging/bundle/skills/orchestrator-do.md` exists:
   `bash packaging/bundle/build-bundle.sh`
   Then confirm no drift:
   `bash packaging/bundle/build-bundle.sh --check`

## Must-Haves

- `packaging/skills/orchestrator-do.md` exists and contains "deprecat".
- `packaging/bundle/manifest.yml` skills list contains `orchestrator-do.md`.
- `packaging/bundle/build-bundle.sh` references `orchestrator-do.md` and
  `EXPECTED_SKILLS=14`.
- `packaging/bundle/build-bundle.sh --check` exits 0 (no drift).

## Verification

```bash
test -f packaging/skills/orchestrator-do.md
grep -qi "deprecat" packaging/skills/orchestrator-do.md
grep -q "orchestrator-do.md" packaging/bundle/manifest.yml
grep -q "orchestrator-do.md" packaging/bundle/build-bundle.sh
grep -q "EXPECTED_SKILLS=14" packaging/bundle/build-bundle.sh
bash packaging/bundle/build-bundle.sh --check
```

## Inputs

### From Previous Tasks

- `commands/do.md` (from T02) — the deprecation-shim doc whose content the bundle
  skill mirrors (banner + D021 runway + `--yes`/`--unattended` boundary).
- `scripts/intake/do-entry.sh` (from T02) — the forwarding shim the re-staged
  skill backs.

### From Disk (Pre-existing)

- `packaging/skills/orchestrator-auto.md` — the frontmatter/structure template for
  the new shim skill.
- `packaging/bundle/manifest.yml` — `skills:` list (13 entries).
- `packaging/bundle/build-bundle.sh` — `EXPECTED_SKILLS=13`,
  `EXPECTED_SKILL_NAMES` (13 names), and the `--check` drift gate that must stay
  green.

## Constraints

- Keep the manifest + build-bundle expected list + `skills/` dir mutually
  consistent — the `--check` gate fails on any drift among them.
- Do not alter any other skill entry.

## Expected Output

`orchestrator-do.md` present in `packaging/skills/`, the manifest skills list, the
`build-bundle.sh` expected set (count 14), and the regenerated
`packaging/bundle/skills/`; `build-bundle.sh --check` exits 0.
