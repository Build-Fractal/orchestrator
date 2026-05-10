---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M032"
provides:
  - "commands/wiki-init.md (orchestrator:wiki-init command document, MEM012 structure); scripts/lifecycle/wiki-init.sh (FR-5 default-scope canonical implementation, bash 3.2 + AD-19 single-script-file shape); wiki/mkdocs.yml four-field placeholder amendment (bundle template state) + FR-6 self-application loop closed against orchestrator repo (resolved orchestrator-identity values restored); packaging/bundle/manifest.yml additive wiki/ entry under project_assets:; tools/verify/m032-p02-wiki-init-command-shape.sh + tools/verify/m032-p02-wiki-init-default-scope.sh + tools/verify/m032-p02-mkdocs-templating-and-self-application.sh + tools/verify/lib/m032-p02-wiki-serve-probe.sh helper"
requires:
  - "from:M032/P01 what:packaging/bundle/manifest.yml project_assets schema, scripts/lifecycle/read-project-assets.sh, scripts/lifecycle/install-asset-mode.sh, scripts/lifecycle/install-collision-check.sh, tests/fixtures/m032-fresh-project-fixture/"
affects:
  - "P02/T02 (init --with-wiki passthrough consumes wiki-init.sh + manifest entry); P02/T03 (glossary canonical version follows wiki-init stub); P03 (--with-giscus + --deploy extension scopes amend wiki-init.sh argument-rejection branches)"
key_files:
  - "commands/wiki-init.md,scripts/lifecycle/wiki-init.sh,wiki/mkdocs.yml,packaging/bundle/manifest.yml,tools/verify/m032-p02-wiki-init-command-shape.sh,tools/verify/m032-p02-wiki-init-default-scope.sh,tools/verify/m032-p02-mkdocs-templating-and-self-application.sh,tools/verify/lib/m032-p02-wiki-serve-probe.sh,wiki/glossary.md"
key_decisions:
  - "FR-5,FR-6,FR-12,FR-15,FR-22,MIT-002,AD-5,AD-19,MEM012,MEM001,#Q-2"
patterns_established:
  - "self-application detection (REPO_ROOT == PROJECT_DIR) skips bundle staging in dogfooding loops; field-line rewrite is idempotent against BOTH placeholders AND already-resolved values where the bundle source IS the orchestrator-local resolved copy; pre-stage idempotency short-circuit avoids cp-overwrites-operator-edits failure mode; lowercase owner for site_url + preserved case for repo_url matches GitHub Pages canonical convention; verifier toolchain-probe via symlink-only PATH excluding python3/pip3 exercises FR-12 fail-closed without breaking other tool lookups; wiki-serve probe helper prefers wiki-serve.sh --probe (mkdocs build --strict) for port-free health check with start+curl+kill fallback per AD-19 envelope"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P02/tasks/T01-wiki-init-default-scope-PAYLOAD.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-05-04T18:34:15Z"
---

## What Shipped

T01 lands the foundational P02 surface: the `orchestrator:wiki-init` command
document (`commands/wiki-init.md`), its canonical implementation
(`scripts/lifecycle/wiki-init.sh`), the FR-6 placeholder amendment to
`wiki/mkdocs.yml`, the additive `wiki/` entry under
`packaging/bundle/manifest.yml`'s `project_assets:` block, the closed FR-6
self-application loop against the orchestrator's own dogfood wiki (per AD-5
/ MIT-002), and the three Truth-pair verifiers under `tools/verify/`.

The default-scope `wiki-init.sh` flow:

1. Reads `project_assets:` tuples from `packaging/bundle/manifest.yml` via
   the P01 `read-project-assets.sh` reader; filters to entries whose
   `source` begins with `wiki` (the four runtime-dir entries are P01
   installer responsibility).
2. Probes `python3` and `pip3` on `PATH` per FR-12 / #Q-2; fail-closed
   (exit 3) with platform-aware diagnostic (`brew install python3` on
   darwin; `apt install python3` on linux).
3. Parses `git -C "$PROJECT_DIR" remote get-url origin` to derive
   `<owner>/<repo>` from either `https://github.com/...` or
   `git@github.com:...` shapes.
4. Synthesizes the four templated values: `site_name=<repo>` (overridable
   via `--site-name`), `site_description=` (overridable), `site_url`
   uses lowercase owner per GitHub Pages canonical convention, `repo_url`
   preserves owner case.
5. Stages `wiki/` to `<PROJECT_DIR>/wiki/` via the P01 dual-oracle
   collision-check + per-mode handler.
6. Field-line sed-substitutes the four top-level YAML keys (`site_name`,
   `site_description`, `site_url`, `repo_url`) — idempotent against BOTH
   `{{...}}` placeholders AND already-resolved values.
7. Authors `<PROJECT_DIR>/wiki/glossary.md` path-convention stub if absent
   (FR-15 — T03 lands the orchestrator-repo-level canonical version).
8. Optional `--auto-pip` opt-in runs `pip3 install -r wiki/requirements.txt`
   per #Q-2; default behavior is print-and-exit.

## Self-Application Loop (FR-6 / MIT-002)

The orchestrator's own wiki is its own first consumer. The bundle source
for the new `wiki/` `project_assets:` entry is `wiki/` (relative to
orchestrator repo root) — same path as the orchestrator's local wiki. T01
runs `bash scripts/lifecycle/wiki-init.sh --project-dir . --site-name="..."
--site-description="..."` against the orchestrator repo to resolve the
four placeholders to orchestrator-identity values. Two seam fixes were
required to close the loop cleanly:

1. **Self-application detection** — when `REPO_ROOT == PROJECT_DIR`, the
   bundle IS the target. The staging step is skipped entirely (avoiding
   either a no-op `cp wiki/. wiki/` or an FR-22 collision-check rejection
   against the orchestrator's pre-existing operator-owned `wiki/`
   directory). Sed-substitution proceeds on the in-place file.

2. **Pre-stage idempotency short-circuit** — when the target
   `<project>/wiki/mkdocs.yml` already carries the desired `site_name` /
   `site_url` / `repo_url` for the current project, the bundle staging
   step (which would otherwise overwrite operator-edited files via the
   P01 `cp -R` mode handler) is also skipped. This is the "no changes"
   branch consumers see on second invocation per US-2 Acceptance
   Scenario 5.

The orchestrator's `bash scripts/wiki/wiki-serve.sh --probe` (which runs
`mkdocs build -f wiki/mkdocs.yml --strict`) returns exit 0 against the
resolved file — the FR-6 / MIT-002 self-application loop is closed and
the orchestrator's own dogfood wiki continues to render correctly for
the duration of M032 + [M033](../../../../../milestones/M033/index.md) paired development.

## Substitution Mechanism (Field-Line Rewrite)

The original task-plan sketch used placeholder-token substitution
(`s|{{site_name}}|...|g`). T01 chose a field-line rewrite instead
(`s|^site_name:.*|site_name: "..."|`) because the bundle source — which
on the orchestrator repo IS the same path as the local resolved file —
ends up carrying RESOLVED values after the self-application loop. A
placeholder-only mechanism would silently no-op against any consumer
that pulls the bundle (since they'd receive resolved orchestrator values
with no placeholders to substitute against). Field-line rewrite makes
the substitution idempotent against BOTH starting states. The "no
changes" emission threshold checks for byte-equal lines using
`grep -qxF` against the four desired field lines.

## Verifiers

Three Truth/Check pairs co-authored under `tools/verify/m032-p02-*` per
plan-time discipline rule 2. All three exit 0 against the T01-landed
surface:

- `m032-p02-wiki-init-command-shape.sh` — 15/15 PASS. MEM012 structure +
  FR-5 / FR-12 references + extension-flag declarations.
- `m032-p02-wiki-init-default-scope.sh` — 19/19 PASS. Exercises against
  the P01 fresh-project fixture: resolved values match git remote,
  glossary stub authored, no leakage into commands/scripts/references/
  templates (filter holds), FR-12 toolchain probe rejects exit 3 under
  synthesized PATH excluding python3/pip3, P03 flag rejection (--with-
  giscus, --deploy) exits 5, idempotency emits "no changes".
- `m032-p02-mkdocs-templating-and-self-application.sh` — 15/15 PASS.
  Resolved orchestrator-identity values + zero placeholders + manifest
  `wiki/` entry + P01 entries byte-preserved + wiki-serve probe.

The wiki-serve.sh start+probe+kill helper extracted to
`tools/verify/lib/m032-p02-wiki-serve-probe.sh` per AD-19 single-script-
file constraint. Helper prefers `wiki-serve.sh --probe` (mkdocs build
--strict) for a port-binding-free health check, with start+curl+kill
fallback.

## Key Design Decisions

- **Self-application detection** (REPO_ROOT == PROJECT_DIR) — sidesteps
  both the cp-self no-op and the FR-22 collision-check operator-owned
  oracle for the orchestrator-dogfooding-itself path.
- **Field-line rewrite > placeholder substitution** — supports consumers
  who pull a bundle whose source-of-truth file already carries resolved
  values (which IS the orchestrator's case, since `source: wiki/` points
  at the orchestrator's local wiki, not a separate template path).
- **Lowercase owner for site_url, preserved case for repo_url** —
  matches GitHub Pages canonical URL convention (lowercase) and GitHub
  repo URL convention (case-preserving).
- **Pre-stage idempotency short-circuit** — avoids the cp-overwrites-
  operator-edits failure mode that would otherwise prevent `wiki-init`
  from being safe to re-run against an operator-customized wiki.
- **Verifier toolchain-probe via synthesized PATH** — symlink-only PATH
  containing the standard utilities wiki-init.sh needs (bash, sh,
  dirname, mktemp, ..., git) but excluding python3/pip3, exercising the
  FR-12 fail-closed branch without breaking the script's other tool
  lookups.

## Affects Downstream

- **P02/T02 (init --with-wiki passthrough)** — adds `init` flag wired to
  `wiki-init.sh`. T01's command document + script + manifest entry are
  the consumed surface. The self-application loop closure means M033's
  paired development can rely on the orchestrator's own wiki rendering
  throughout.
- **P02/T03 (glossary canonical version)** — `wiki-init.sh`'s glossary
  stub is the consumer-side template; T03 lands the orchestrator-repo-
  level canonical glossary.md at the same path-convention.
- **P03** — `--with-giscus` + `--deploy` extension scopes. T01's
  argument-rejection branches (exit 5) provide the seam for P03 to
  amend.

## Verification Results

```
$ bash tools/verify/m032-p02-wiki-init-command-shape.sh
SUMMARY: m032-p02-wiki-init-command-shape.sh pass=15 fail=0

$ bash tools/verify/m032-p02-wiki-init-default-scope.sh
SUMMARY: m032-p02-wiki-init-default-scope.sh pass=19 fail=0

$ bash tools/verify/m032-p02-mkdocs-templating-and-self-application.sh
SUMMARY: m032-p02-mkdocs-templating-and-self-application.sh pass=15 fail=0
```

49/49 must-haves PASS, 0 FAIL.
