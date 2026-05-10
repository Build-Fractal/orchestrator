---
schema_version: "1.0"
type: task-summary
task: "T06"
phase: "P01"
milestone: "M037"
---

# T06 — Shared YAML-merge primitive + install-template emission for config.yml + mkdocs.yml + acceptance battery aggregator scaffold

## What changed

- **NEW `scripts/lib/yaml-merge.sh`** — 398-line shared YAML-merge primitive
  per AD-19 single-script-file shape, bash 3.2 + POSIX sh per MEM001, sed/awk
  only (NO yq, NO python, CON-1 dependency discipline). Subcommand interface
  `merge --target <file> --framework-default <file> --managed-namespaces
  <comma-list> [--dry-run]`. Contains literal `managed_namespaces` (4×).
  Behaviour:
  - Target absent → byte-identical copy from framework default, exit 0.
  - Per-top-level-key classification:
    - **Managed AND target has key** → sub-key-aware merge
      (`merge_managed_block`): framework's block-header line and any sub-key
      missing from target are emitted; target's sub-key sub-blocks survive
      byte-identical for sub-keys present in BOTH (operator wins on
      sub-key value); target-only sub-keys appended at end. This satisfies
      the verifier requirement that operator-authored content under a
      managed namespace (`wiki.landing_cards:`) survive byte-identical
      while framework can still introduce new managed sub-keys (e.g., a
      future `wiki.nav_buckets:`).
    - **Managed AND target absent key** → framework's block emitted
      (new orchestrator-managed default).
    - **Not-managed AND target has key** → target's block byte-identical
      (operator wins).
    - **Not-managed AND target absent key** → framework's block emitted
      (new framework default the operator hasn't customized).
    - **Operator-only top-level key (in target, not in framework)** →
      preserved byte-identical, anchored to the last framework-known key
      that preceded it in target's order (preserves relative position).
    - Header (lines preceding first top-level key): prefer target's,
      else framework's.
  - **FR-11 fail-closed**: pre-scan for malformed-YAML signals (odd unescaped
    double-quote count on a content line; duplicate top-level keys). On
    parse failure: write diagnostic `YAML_PARSE_ERROR: ...` to stderr,
    return exit 4, write nothing. Test coverage: a target with `foo:
    "unclosed-string` is preserved byte-identical (md5-hash unchanged) while
    yaml-merge.sh exits 4.
  - `--dry-run`: emit merged content to stdout, no write, exit 0.
  - Atomic write: merged content composed in tempfile, then `mv` to target.

- **MODIFY `packaging/install/install-claude-code.sh`** (lines 438-448 →
  21-line yaml-merge invocation block). Replaces the pre-T06 "skip if exists
  / overwrite with --force" cfg_target write that clobbered operator
  customizations. Managed-namespaces list is the full 15-key cross-reference
  artifact from the DISP-1 plan-time gate (`default_tier`,
  `verification_commands`, `context_verbosity`, `git_isolation`,
  `dispatch_budget`, `duration_budget`, `budget_enforcement`, `auto_proceed`,
  `autonomy`, `compression`, `quick_knowledge_token_budget`,
  `entry_routing_confidence_floor`, `tier_a_plus_prompt_summary_lines`,
  `display_thresholds`, `wiki`).

- **MODIFY `packaging/install/install-codex.sh`** (lines 247-257) — identical
  yaml-merge invocation block. The three installers' cfg_target write blocks
  share shape per [M032](../../../../../milestones/M032/index.md) dogfood findings, so the same replacement bash fits
  cleanly.

- **MODIFY `packaging/install/install-cursor.sh`** (lines 256-266) — identical
  yaml-merge invocation block.

- **MODIFY `scripts/lifecycle/wiki-init.sh`** (after line 378's sed-block
  closing `fi`) — invokes yaml-merge against the staged `wiki/mkdocs.yml`
  using `$REPO_ROOT/wiki/mkdocs.yml` as framework default. Self-application
  guard: skips merge when `BUNDLE_MKDOCS == MKDOCS_TARGET` (orchestrator
  dogfooding path; would be a no-op anyway). On consumer-project refresh
  paths, the merge does load-bearing CON-3 preservation work for any
  operator-authored top-level keys outside the framework's managed list
  (e.g., custom `analytics:` blocks).

  **Managed-namespace divergence from T06 plan §149-160**: the mkdocs-managed
  list applied here is `docs_dir,site_dir,theme,plugins,markdown_extensions,
  extra_css,nav` — the sed-substituted scalars (`site_name` /
  `site_description` / `site_url` / `repo_url` / `edit_uri`) are
  **intentionally excluded** because those keys are project-derived by the
  preceding sed block; passing them through yaml-merge as managed keys
  would replace the consumer's just-substituted values with the bundle's
  stale dogfood values. Documented inline at the invocation site. The plan
  table predated T04; `extra_css` IS included as managed (T04 added the
  framework-controlled code-chip CSS declaration; see `extra_css addendum`
  below).

## extra_css addendum (executor-time decision per T06 PROMPT)

The T06 plan's mkdocs.yml managed-namespace cross-reference table
(plan lines 151-160) was authored before T04 landed and does not include
`extra_css`. T04 (commit `2031a9af`) added a top-level `extra_css:` block at
`wiki/mkdocs.yml` lines 70-73 (sentinel-bracketed
`# >>> M037-P01-T04 extra_css ... # <<< M037-P01-T04 extra_css end`)
declaring `stylesheets/code-chips.css` for Surface E code-chip pill styling
on the DECISIONS body. The CSS file ships with the orchestrator bundle; the
declaration is framework-controlled and parallels `plugins:` /
`markdown_extensions:` (other framework-managed CSS/JS-shaped surfaces).

**Decision**: classify `extra_css` as **orchestrator-managed**. Added to the
`MKDOCS_MANAGED` namespace list in `scripts/lifecycle/wiki-init.sh`. Not a
plan deviation — fills a gap that opened when T04 landed after the plan was
authored. Sub-key merge semantics under managed apply: operator-authored
extra `- stylesheets/operator-overrides.css` entries (if any) would survive
via the "target-only sub-keys appended at end" path, while the
framework-supplied `- stylesheets/code-chips.css` always renders.

## DISP-1 PBJ-central cross-reference (deferred)

PBJ-central's `.orchestrator/config.yml` is **not accessible at executor**
in this dispatch (the executor only has the orchestrator repo at
`/Users/brettkellgren/Sites/orchestrator`). Per the T06 plan
§143-147 fallback ("If PBJ-central is not accessible at dispatch time, the
executor proceeds with the table above as the authoritative
classification"), the cross-reference is deferred. The plan's 15-key
cross-reference table is the authoritative classification and ships
unchanged to the installer's `MANAGED_NAMESPACES` list.

Operator follow-up: when PBJ-central next runs `orchestrator:update` (or the
[M035](../../../../../milestones/M035/index.md) `orchestrator:update` first-class command lands), validate that no
PBJ-central top-level config keys are silently re-classified by the merge
primitive. The fail-closed design (operator-only keys are preserved
byte-identical at the original relative position) makes silent
re-classification structurally impossible; this is documentation discipline.

## packaging/bundle/config/orchestrator.default.yml situation

`packaging/bundle/config/orchestrator.default.yml` is a **separate
hand-authored stub file** (12 lines) — NOT a copy or symlink of the canonical
175-line `templates/orchestrator-config-default.yml`. Verified via
`diff packaging/bundle/config/orchestrator.default.yml
templates/orchestrator-config-default.yml` (1,175c1,12 — fully divergent).

This is a pre-existing condition; T06 does NOT modify it. Implication for
T01's `wiki:` block: T01 (commit `deef3e96`) added the `wiki:
landing_cards: []` schema to `templates/orchestrator-config-default.yml`
only — `packaging/bundle/config/orchestrator.default.yml` does NOT carry the
`wiki:` schema.

The installers reference `cfg_src="$BUNDLE/config/orchestrator.default.yml"`
(install-claude-code.sh:429, install-codex.sh:238, install-cursor.sh:247),
so on a fresh consumer install the bundle stub is what gets staged. **This
means T01's `wiki.landing_cards:` schema is NOT delivered to consumer
projects today** — the bundle stub lacks the namespace, so the merge
primitive cannot introduce it on round-trip either.

Surfacing this as a discrete observation for operator triage: M035 packaging
work needs to either (a) make `packaging/bundle/config/orchestrator.default.yml`
a symlink/copy of `templates/orchestrator-config-default.yml`, or (b) add a
build step that materializes the bundle stub from the canonical template.
T06 stays in scope (yaml-merge plumbing); the bundle-stub divergence is
M035's domain.

## NEW `tests/fixtures/m037-config-merge/` corpus

Three fixture artifacts:

- `.orchestrator/config.yml` — operator-authored config exercising the three
  CON-3 preservation surfaces (customized `default_tier`, populated
  `wiki.landing_cards:` 3-entry block, operator-only
  `pbj_team_dashboard_url:`).
- `framework-defaults/orchestrator-config-default.yml` — minimal framework
  default with the `_orchestrator_managed` comment marker required by the
  SC-5 acceptance test artifact contract.
- `wiki/mkdocs.yml` — operator-authored mkdocs.yml carrying a custom
  top-level `analytics:` block (CON-3 surface for the `wiki-init.sh`
  template-refresh path; available for P02 extension if a parallel
  `wiki-init.sh` round-trip acceptance test gets added).
- `README.md` — fixture layout and intent.

## NEW `tools/verify/m037-p01-config-clobber-fix.sh` (Truth #6)

Five checks: yaml-merge.sh existence + `managed_namespaces` literal; three
installers invoke `yaml-merge.sh` (regex match); round-trip merge against the
fixture preserves `pbj_team_dashboard_url:` byte-identical AND operator
`wiki.landing_cards:` content byte-identical AND merges orchestrator-managed
defaults underneath (operator's content survives, not framework's empty
list). Emits `PASS: m037-p01-config-clobber-fix (5/5)` on full pass.

## NEW `tools/verify/m037-p01-malformed-yaml-fail-closed.sh` (Truth #7)

Three checks: stages malformed YAML (unclosed quote on key line), invokes
yaml-merge.sh, asserts non-zero exit + parseable diagnostic
(`YAML_PARSE_ERROR` or `failed YAML parse`) + target file md5-hash
byte-identical to malformed input (no silent overwrite). Emits
`PASS: m037-p01-malformed-yaml-fail-closed` on full pass.

## NEW `tests/m037-acceptance/p01-config-clobber-fix.sh` (SC-5 acceptance)

173 lines, contains literal `_orchestrator_managed` (4×) per phase-plan
artifact contract. Four US-5 scenarios:

- **(a) Operator-authored keys survive simulated `orchestrator:update`** —
  yaml-merge round-trip preserves operator-only `pbj_team_dashboard_url:`
  AND operator content under managed `wiki.landing_cards:`. Note:
  flat-shape managed keys (`verification_commands:`,`default_tier:`) are
  intentionally framework-wins per plan §33; operator overrides via
  `.orchestrator/config.local.yml` (AD-17 four-layer resolution, out of
  scope for the yaml-merge primitive).
- **(b) Absent target produces fresh emit** — empty `wiki.landing_cards:`
  placeholder ships when target is absent.
- **(c) Managed key with new sub-key applies new schema** — extended
  framework adds `wiki.nav_buckets:` alongside `wiki.landing_cards:`;
  merge brings the new sub-key in while operator's `landing_cards:` content
  survives. Validates the future-evolution path in the plan §145
  (e.g., a future `wiki.nav_buckets:` from P02).
- **(d) Malformed YAML fails closed** — non-zero exit + target byte-identical
  to malformed input.

Emits `PASS: p01-config-clobber-fix (4/4 scenarios)` on full pass.

## NEW `tests/m037-acceptance/run-acceptance-battery.sh` (SC-12 scaffold)

60 lines, contains `BATTERY: pass=` literal (3×) per phase-plan artifact
contract. Iterates `tests/m037-acceptance/p01-*.sh`, captures exit codes,
prints `BATTERY: pass=N skip=M fail=K` summary. Exits 0 only when fail=0.
P02 extension (out of scope here): append parallel iteration over
`p02-*.sh` plus the SC-10 strict-build smoke and SC-11 PBJ-update evidence.

After T01..T06 land, current battery output:

```
BATTERY: pass=5 skip=0 fail=0
```

(The five P01 acceptance tests: `p01-card-grid-homepage.sh`,
`p01-config-clobber-fix.sh`, `p01-dr-heading-shape.sh`,
`p01-mkdocs-polish-bundle.sh`, `p01-version-to-nav-title.sh`.)

## Verifier output

```
$ bash scripts/lib/yaml-merge.sh --help
yaml-merge.sh — shared YAML-merge primitive (M037 FR-10/FR-11).
Usage: bash scripts/lib/yaml-merge.sh merge \
  --target <file> --framework-default <file> \
  --managed-namespaces <comma-list> [--dry-run]
...

$ bash tools/verify/m037-p01-config-clobber-fix.sh
CHECK PASS: scripts/lib/yaml-merge.sh exists with managed_namespaces literal
CHECK PASS: install-claude-code.sh invokes yaml-merge.sh
CHECK PASS: install-codex.sh invokes yaml-merge.sh
CHECK PASS: install-cursor.sh invokes yaml-merge.sh
CHECK PASS: round-trip merge preserves operator content (3/3 sub-checks)
SUMMARY: m037-p01-config-clobber-fix pass=5 fail=0
PASS: m037-p01-config-clobber-fix (5/5)

$ bash tools/verify/m037-p01-malformed-yaml-fail-closed.sh
CHECK PASS: yaml-merge.sh exited non-zero (4) on malformed target (fail-closed)
CHECK PASS: stderr/log contains parseable diagnostic (YAML_PARSE_ERROR or failed YAML parse)
CHECK PASS: target file byte-identical to malformed input (no silent overwrite)
SUMMARY: m037-p01-malformed-yaml-fail-closed pass=3 fail=0
PASS: m037-p01-malformed-yaml-fail-closed

$ bash tests/m037-acceptance/p01-config-clobber-fix.sh
PASS: scenario (a) operator keys survive simulated update
PASS: scenario (b) absent target produces fresh emit with empty landing_cards
PASS: scenario (c) managed schema change merges new sub-key while preserving operator content
PASS: scenario (d) malformed YAML fails closed (rc=4, target byte-identical)
SUMMARY: p01-config-clobber-fix scenarios pass=4 fail=0
PASS: p01-config-clobber-fix (4/4 scenarios)

$ bash tests/m037-acceptance/run-acceptance-battery.sh
... (5 P01 tests run, all pass) ...
BATTERY: pass=5 skip=0 fail=0
```

## Regression checks

All pre-existing P01 verifiers and acceptance tests still PASS post-T06:

```
$ bash tools/verify/m037-p01-card-grid.sh
PASS: m037-p01-card-grid (4/4)

$ bash tools/verify/m037-p01-version-to-title.sh
PASS: m037-p01-version-to-title (5/5)

$ bash tools/verify/m037-p01-auto-generated-escape-hatch.sh
PASS: m037-p01-auto-generated-escape-hatch (4/4)

$ bash tools/verify/m037-p01-decisions-shape.sh
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (28 entries, all anchors unique)

$ bash scripts/verify/decisions-shape-lint.sh
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (28 entries, all anchors unique)

$ bash tools/verify/m037-p01-authoring-conventions-doc.sh
PASS: m037-p01-authoring-conventions-doc (5/5)

$ bash tools/verify/m037-p01-dispatch-references-conventions.sh
PASS: m037-p01-dispatch-references-conventions

$ bash tools/verify/m037-p01-mkdocs-polish-bundle.sh
PASS: m037-p01-mkdocs-polish-bundle (9/9)

$ bash tests/m037-acceptance/p01-mkdocs-polish-bundle.sh
PASS: p01-mkdocs-polish-bundle (13/13)
```

## Must-haves (from T06 plan)

- [x] Truth #6 (install-template refresh preserves operator-authored
      top-level keys).
- [x] Truth #7 (install-template fails closed on malformed YAML).
- [x] Phase artifact: `scripts/lib/yaml-merge.sh` (398 lines ≥ 30,
      contains `managed_namespaces` 4×).
- [x] Phase artifact: `tests/m037-acceptance/run-acceptance-battery.sh`
      (60 lines ≥ 20, contains `BATTERY: pass=` 3×).
- [x] Phase artifact: `tests/m037-acceptance/p01-config-clobber-fix.sh`
      (173 lines ≥ 30, contains `_orchestrator_managed` 4×).
- [x] Phase Key Link: `scripts/lib/yaml-merge.sh` →
      `packaging/install/install-claude-code.sh` (yaml-merge.sh referenced
      from installer's cfg_target write block).
- [x] SC-5 acceptance test passes (4/4 scenarios).
- [x] DISP-1 plan-time managed-key namespace cross-reference is on disk
      in the T06 plan.

## Notes

- `wiki/mkdocs.yml` is **untouched** by T06 — T05's polish-bundle additions
  (commit `a4ea4cd6`) and T04's `extra_css:` block (commit `2031a9af`) at
  lines 70-73 remain byte-identical. Confirmed via `git diff --stat
  wiki/mkdocs.yml` (empty). T06's wiki-init.sh modification operates on
  CONSUMER-project mkdocs.yml refresh paths, not on the orchestrator's own
  dogfood file.
- The line-oriented YAML parser handled both `templates/orchestrator-config-default.yml`
  (175 lines, multiple block-shaped keys with deep nested structure including
  `compression.tier3.intensity_floor:` etc.) and `wiki/mkdocs.yml` (with
  `!ENV [VAR_NAME, default]` directives in the `extra:` block) without
  edge-case escalation. Self-merge against both produces byte-identical
  output (confirmed via diff).
- The duplicate-top-level-key guard (`seen[new_key] == 1` in awk) catches
  the structural malformation case; the unbalanced-quote pre-scan catches
  the canonical "unclosed string" malformation. Both are simple line-based
  heuristics, not full YAML-1.2 parsing — this is the deliberate
  bash-3.2-friendly tradeoff per CON-1's spirit (zero new deps).
- After T06 lands, P01 is **complete**. Phase-suite verification gate (per
  T06 PROMPT closing instructions): all nine P01 verifiers + the acceptance
  battery aggregator run green. Phase-close work follows.
