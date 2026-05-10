---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01"
milestone: "M037"
name: "Shared YAML-merge primitive + install-template emission for config.yml + mkdocs.yml + acceptance battery aggregator scaffold"
depends_on: ["T01", "T05"]
---

## Prerequisites

- T01 has added `wiki:` → `landing_cards: []` to `templates/orchestrator-config-default.yml` (this task classifies the `wiki.landing_cards:` namespace as orchestrator-managed and exercises round-trip preservation against an operator-customized variant).
- T05 has added the polish-bundle keys to `wiki/mkdocs.yml` (this task exercises CON-3 preservation against a fixture that mixes those keys with operator-authored keys).
- `packaging/install/install-claude-code.sh` exists (verified at plan-authoring time, contains the `cfg_target` write block at lines 418-448).
- `packaging/install/install-codex.sh` and `packaging/install/install-cursor.sh` exist (verified at plan-authoring time via `ls packaging/install/`).

## Description

Lands the shared YAML-merge primitive at `scripts/lib/yaml-merge.sh` per #Q-4 resolution (single primitive, parameterized over file path + managed-namespace list, file-agnostic by design). Replaces the current "skip if exists / overwrite with --force" logic in the three installers' config-stage block with a `yaml-merge.sh merge` invocation. Applies the same primitive to the `mkdocs.yml` template-refresh path in `scripts/lifecycle/wiki-init.sh` per CON-3 / MIT-03 P0. Scaffolds `tests/m037-acceptance/run-acceptance-battery.sh` aggregator covering SC-1..SC-5 (P02 extends it for SC-6..SC-11; SC-12 closure gate fires only after P02 ships).

This task carries the **DISP-1 plan-time gate** per AD-6 / arbiter ruling: the plan body MUST contain a `## Managed-Key Namespace Cross-Reference` section listing every top-level key declared in `templates/orchestrator-config-default.yml` as orchestrator-managed, cross-referenced against any consumer-project config that planning can access. See that section below.

## Steps

1. **Author `scripts/lib/yaml-merge.sh`** (the shared primitive). Single-script-file shape per AD-19, bash 3.2 + POSIX sh per MEM001. The script:
   - Subcommand interface: `bash scripts/lib/yaml-merge.sh merge --target <file> --framework-default <file> --managed-namespaces <comma-separated-list> [--dry-run]`.
   - Reads the framework-default YAML file and the on-disk target YAML file (if it exists).
   - Behavior:
     - If target does not exist: copy framework-default to target byte-identical. Return 0.
     - If target exists: parse both as YAML (use a deterministic line-oriented parser — top-level keys are detected by `^[a-zA-Z_][a-zA-Z0-9_-]*:` pattern; this matches the existing convention in `templates/orchestrator-config-default.yml`).
     - For each top-level key in framework-default:
       - If key IS in `--managed-namespaces` list: replace target's block for that key with framework-default's block (orchestrator-managed; framework wins).
       - If key is NOT in managed-namespaces AND target already has the key: preserve target's block byte-identical (operator-authored; operator wins).
       - If key is NOT in managed-namespaces AND target does NOT have the key: append framework-default's block to target (new orchestrator-managed default; operator hasn't customized).
     - Operator-authored top-level keys present in target but absent from framework-default: preserve byte-identical at the original position.
   - **Fail-closed on YAML parse error** (FR-11): if the target file cannot be parsed (mismatched indentation, unbalanced quotes, etc.), abort with `FAIL: yaml-merge: target <path> failed YAML parse: <diagnostic>` to stderr and exit 4. Write nothing.
   - `--dry-run`: emit the merged content to stdout instead of writing to target. Exit 0.
   - Min 30 lines, contains the literal string `managed_namespaces` (per phase-plan artifact contract).

   **Implementation note**: do NOT use `yq` or external YAML parsers — bash 3.2 + POSIX sh + sed/awk only. The line-oriented parsing approach is feasible because both `orchestrator-config-default.yml` and `mkdocs.yml` use 2-space indentation with no exotic flow-style YAML.

2. **Modify `packaging/install/install-claude-code.sh`** at lines 438-448. Replace:

   ```bash
   if [ "$DRY_RUN" = "1" ]; then
     echo "would_write=$cfg_target"
     config_written=1
   elif [ -e "$cfg_target" ] && [ "$FORCE" = "0" ]; then
     echo "SKIP: $cfg_target exists (use --force to overwrite)"
   else
     mkdir -p "$state_root"
     cp "$cfg_src" "$cfg_target"
     echo "wrote=$cfg_target"
     config_written=1
   fi
   ```

   With:

   ```bash
   YAML_MERGE="$BUNDLE/../scripts/lib/yaml-merge.sh"
   # Resolve via repo root if bundle staging hasn't placed it yet.
   if [ ! -f "$YAML_MERGE" ]; then
     YAML_MERGE="$(cd "$(dirname "$0")/../.." && pwd)/scripts/lib/yaml-merge.sh"
   fi
   MANAGED_NAMESPACES="default_tier,verification_commands,context_verbosity,git_isolation,dispatch_budget,duration_budget,budget_enforcement,auto_proceed,autonomy,compression,quick_knowledge_token_budget,entry_routing_confidence_floor,tier_a_plus_prompt_summary_lines,display_thresholds,wiki"
   if [ "$DRY_RUN" = "1" ]; then
     bash "$YAML_MERGE" merge --target "$cfg_target" --framework-default "$cfg_src" --managed-namespaces "$MANAGED_NAMESPACES" --dry-run
     echo "would_write=$cfg_target"
     config_written=1
   else
     mkdir -p "$state_root"
     bash "$YAML_MERGE" merge --target "$cfg_target" --framework-default "$cfg_src" --managed-namespaces "$MANAGED_NAMESPACES"
     merge_rc=$?
     if [ "$merge_rc" -ne 0 ]; then
       echo "FAIL: yaml-merge.sh exited $merge_rc against $cfg_target" >&2
       exit 1
     fi
     echo "wrote=$cfg_target"
     config_written=1
   fi
   ```

   The `MANAGED_NAMESPACES` list is the cross-reference artifact from the DISP-1 plan-time gate (see below) — every top-level key in `templates/orchestrator-config-default.yml` is listed.

3. **Apply identical changes to `packaging/install/install-codex.sh` and `packaging/install/install-cursor.sh`** for parity. Find the equivalent `cfg_target` write block in each (the three installers share the same [M032](../../../../../milestones/M032/index.md) configuration block shape per the M032 dogfood findings) and apply the same replacement.

4. **Apply yaml-merge.sh to `mkdocs.yml` template-refresh path in `scripts/lifecycle/wiki-init.sh`**. The current sed-based field-line rewrite at lines 279-326 (modified by T05 to add `edit_uri:`) handles four-then-five known top-level fields. CON-3 / MIT-03 P0 requires that operator-authored top-level keys outside those known fields survive byte-identical too.

   Modification: AFTER the sed-substitution block (where the four-then-five known fields are written), invoke yaml-merge.sh against the staged `mkdocs.yml` with a managed-namespace list of `site_name,site_description,site_url,repo_url,edit_uri,docs_dir,site_dir,theme,plugins,markdown_extensions,extra,nav` and the bundle's `wiki/mkdocs.yml` as the framework default. The merge primitive then ensures any operator-authored top-level keys outside that list (e.g., a custom `analytics:` block) survive byte-identical.

   On the orchestrator's self-application path (REPO_ROOT == PROJECT_DIR), this is a no-op (target == bundle == byte-identical). On consumer-project refresh paths, the merge primitive does the load-bearing preservation work.

5. **Author `tests/m037-acceptance/run-acceptance-battery.sh` aggregator scaffold** (SC-12 scaffold, P01 portion). The script:
   - Iterates `tests/m037-acceptance/p01-*.sh` (SC-1..SC-5).
   - For each, invokes the test, captures exit code.
   - Prints a `BATTERY: pass=N skip=M fail=K` summary line at end.
   - Exits 0 only if `fail=0`.
   - Min 20 lines, contains the literal string `BATTERY: pass=` (per phase-plan artifact contract).
   - **P02 extension**: P02 ships will append `p02-*.sh` invocations + the SC-10 strict-build smoke + the SC-11 PBJ-update evidence; that is OUT OF SCOPE for this task.

6. **Author `tests/fixtures/m037-config-merge/` corpus**. A fixture project tree containing:
   - A populated `.orchestrator/config.yml` with operator-authored values (e.g., a populated `wiki.landing_cards:` block declaring three cards, a custom `verification_commands:` list, plus an arbitrary operator-authored top-level key like `pbj_team_dashboard_url: "https://example.com/dashboard"` to exercise the "key not in framework default" path).
   - A populated `wiki/mkdocs.yml` with operator-authored extras (e.g., a custom `analytics:` block at the top level).

7. **Author `tools/verify/m037-p01-config-clobber-fix.sh`** (Truth #6 verifier). Asserts:
   - `scripts/lib/yaml-merge.sh` exists and contains `managed_namespaces` literal.
   - `packaging/install/install-claude-code.sh` invokes `yaml-merge.sh` (regex `yaml-merge\.sh` present).
   - `packaging/install/install-codex.sh` invokes `yaml-merge.sh`.
   - `packaging/install/install-cursor.sh` invokes `yaml-merge.sh`.
   - Round-trip test against the fixture: stage the fixture, run the merge primitive against the fixture's config.yml with the framework default, assert the operator-authored `pbj_team_dashboard_url:` survives byte-identical, the operator-authored three-entry `wiki.landing_cards:` block survives byte-identical, and orchestrator-managed defaults are merged underneath.
   - The fixture `_orchestrator_managed` marker (a comment in the fixture's framework default explaining the namespace classification) is preserved per phase-plan artifact contract: `tests/m037-acceptance/p01-config-clobber-fix.sh (min 30, contains "_orchestrator_managed")`.

8. **Author `tools/verify/m037-p01-malformed-yaml-fail-closed.sh`** (Truth #7 verifier). Stages a fixture target with deliberately-malformed YAML (e.g., unbalanced quotes), invokes yaml-merge.sh against it, asserts the script exits non-zero with a parseable diagnostic, AND asserts the target file on disk is byte-identical to the malformed input (no silent overwrite).

9. **Author `tests/m037-acceptance/p01-config-clobber-fix.sh`** (acceptance test, SC-5). Exercises the four US-5 acceptance scenarios against the fixture: operator-authored keys survive across simulated `orchestrator:update`; absent-config produces fresh emit with empty `wiki.landing_cards:` placeholder; orchestrator-managed key with changed schema applies the new schema while preserving operator-authored keys; malformed YAML fails closed.

## Managed-Key Namespace Cross-Reference

(DISP-1 plan-time gate per AD-6 / arbiter ruling. This section is the named planning artifact.)

The following top-level keys in `templates/orchestrator-config-default.yml` are classified as **orchestrator-managed** (the framework controls their default values; operator customizations to keys/values WITHIN these namespaces are still preserved by the merge primitive — the namespace classification controls which top-level keys merge in defaults from the framework, not which sub-keys win on conflict). All keys present in the framework default at plan-authoring time:

| Top-level key                          | Source line | Classification        | PBJ-central collision? |
|----------------------------------------|-------------|-----------------------|------------------------|
| `default_tier`                         | line 5      | orchestrator-managed  | unknown — operator confirm at dispatch |
| `verification_commands`                | line 6      | orchestrator-managed  | unknown — operator confirm |
| `context_verbosity`                    | line 7      | orchestrator-managed  | unknown — operator confirm |
| `git_isolation`                        | line 8      | orchestrator-managed  | unknown — operator confirm |
| `dispatch_budget`                      | line 9      | orchestrator-managed  | unknown — operator confirm |
| `duration_budget`                      | line 10     | orchestrator-managed  | unknown — operator confirm |
| `budget_enforcement`                   | line 11     | orchestrator-managed  | unknown — operator confirm |
| `auto_proceed`                         | line 33     | orchestrator-managed  | unknown — operator confirm |
| `autonomy`                             | line 50     | orchestrator-managed  | unknown — operator confirm |
| `compression`                          | line 61     | orchestrator-managed  | unknown — operator confirm |
| `quick_knowledge_token_budget`         | line 144    | orchestrator-managed  | unknown — operator confirm |
| `entry_routing_confidence_floor`       | line 145    | orchestrator-managed  | unknown — operator confirm |
| `tier_a_plus_prompt_summary_lines`     | line 146    | orchestrator-managed  | unknown — operator confirm |
| `display_thresholds`                   | line 156    | orchestrator-managed  | unknown — operator confirm |
| `wiki` (added by T01)                  | new in M037 | orchestrator-managed  | **likely collision** — PBJ-central spec says operator authors `wiki:` block; T01 declares the namespace orchestrator-managed but operator-authored sub-key values survive via merge primitive |

**Operator confirmation requested at dispatch time**: if PBJ-central's `.orchestrator/config.yml` is accessible to the executor, cross-reference each of these top-level keys against the live consumer config and confirm:
1. Any key in PBJ-central's config NOT in the table above MUST be flagged as a CON-3 conflict (operator-authored key being silently classified). Surface to operator before applying the merge.
2. The `wiki:` namespace classification specifically: PBJ-central authors `wiki.landing_cards:` (operator content); the framework supplies the `wiki:` namespace itself (with empty list default). Round-trip merge MUST preserve the operator's `wiki.landing_cards:` content byte-identical while adding any new orchestrator-managed sub-keys (e.g., a future `wiki.nav_buckets:` from P02).

If PBJ-central is not accessible at dispatch time, the executor proceeds with the table above as the authoritative classification and notes in `T06-SUMMARY.md` that the cross-reference was deferred.

The mkdocs.yml managed-namespace list is separately:

| Top-level key in `wiki/mkdocs.yml`     | Classification        | Note |
|----------------------------------------|-----------------------|------|
| `site_name`, `site_description`, `site_url`, `repo_url`, `edit_uri` | orchestrator-managed | Substituted by `wiki-init.sh` field-line rewrite from project git remote |
| `docs_dir`, `site_dir`                 | orchestrator-managed  | Bundle-fixed paths |
| `theme`                                | orchestrator-managed  | Polish bundle (T05) controls theme.features and theme.name |
| `plugins`                              | orchestrator-managed  | T01 + T05 control; P02 extends with FR-15 |
| `markdown_extensions`                  | orchestrator-managed  | T01 + T05 control |
| `extra`                                | mixed                 | `extra.giscus.*` is operator-supplied via `--with-giscus`; the `extra:` top-level block is operator-authoritative outside the giscus subkeys |
| `nav`                                  | orchestrator-managed  | Auto-generated by `wiki-generate-nav.sh` |
| anything else                          | operator-authored     | Preserved byte-identical by merge primitive |

## Must-Haves

- Truth #6 (install-template refresh preserves operator-authored top-level keys).
- Truth #7 (install-template fails closed on malformed YAML).
- Phase artifacts: `scripts/lib/yaml-merge.sh` (min 30, contains "managed_namespaces"), `tests/m037-acceptance/run-acceptance-battery.sh` (min 20, contains "BATTERY: pass="), `tests/m037-acceptance/p01-config-clobber-fix.sh` (min 30, contains "_orchestrator_managed").
- Phase Key Link: `scripts/lib/yaml-merge.sh` → `packaging/install/install-claude-code.sh`.
- SC-5 acceptance test passes.
- DISP-1 plan-time managed-key namespace cross-reference (the `## Managed-Key Namespace Cross-Reference` section above) is on disk in this plan.

## Verification

```bash
bash tools/verify/m037-p01-config-clobber-fix.sh
bash tools/verify/m037-p01-malformed-yaml-fail-closed.sh
bash tests/m037-acceptance/p01-config-clobber-fix.sh
bash tests/m037-acceptance/run-acceptance-battery.sh
```

## Notes

- Expected output of `tools/verify/m037-p01-config-clobber-fix.sh`: `PASS: m037-p01-config-clobber-fix (5/5)`.
- Expected output of `tools/verify/m037-p01-malformed-yaml-fail-closed.sh`: `PASS: m037-p01-malformed-yaml-fail-closed`.
- Expected output of `tests/m037-acceptance/p01-config-clobber-fix.sh`: `PASS: p01-config-clobber-fix (4/4 scenarios)`.
- Expected output of `tests/m037-acceptance/run-acceptance-battery.sh` after T01..T06 land: `BATTERY: pass=5 skip=0 fail=0` (SC-1..SC-5 covered in P01; SC-6..SC-12 ride P02 + milestone close).
- The line-oriented YAML parser in `yaml-merge.sh` is the simplest implementation that fits bash 3.2 + POSIX sh constraints; if at execution time it cannot handle an edge case (e.g., quoted keys with colons inside), the executor escalates to the operator before reaching for `yq` (which would violate CON-1's spirit of zero-new-deps).

## Inputs

### From Previous Tasks

- `templates/orchestrator-config-default.yml` (from T01)
  - Key API: top-level keys enumerated in the Managed-Key Namespace Cross-Reference table above. T01 added the `wiki:` namespace with `landing_cards: []` empty list default.
  - Key types: YAML 1.2 line-oriented top-level blocks with 2-space indentation. No flow-style. No anchors/aliases.
- `wiki/mkdocs.yml` (from T05)
  - Key API: polish bundle additions are now part of the framework-managed surface — `theme.features` includes navigation.tabs/sticky/prune/content.action.edit/view; `markdown_extensions` includes pymdownx.details + pymdownx.tasklist with custom_checkbox; `toc.toc_depth: 2`; top-level `edit_uri:` derived from `repo_url:`.
  - Key types: YAML 1.2 line-oriented top-level blocks plus the `nav:` auto-generated section.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — modified at lines 418-448 (the cfg_target write block).
- `packaging/install/install-codex.sh` — equivalent block modified for parity.
- `packaging/install/install-cursor.sh` — equivalent block modified for parity.
- `scripts/lifecycle/wiki-init.sh` — modified at lines 279-326 (T05 added `edit_uri:` to the field-line rewrite; T06 wraps the whole block with a yaml-merge invocation for operator-authored-key preservation).
- `packaging/bundle/config/orchestrator.default.yml` — read-only; this is the bundle-staged copy of `templates/orchestrator-config-default.yml`. Verify the path resolution in `install-claude-code.sh` line 429 (`cfg_src="$BUNDLE/config/orchestrator.default.yml"`) is consistent with where T01's `wiki:` block lands. If the bundle staging copies `templates/orchestrator-config-default.yml` at install time, no separate edit needed; if it's a sibling file, T01 must update both (executor confirms at execution time).

## Constraints

- **CON-3 — Operator-authored keys survive every template-emit path**: HARD CONTRACT. The yaml-merge primitive is the load-bearing implementation. Any deviation that loses operator content is a P0 bug.
- **MIT-03 P0 — CON-3 back-reference in FR-9 (mkdocs.yml)**: HARD CONTRACT. Step 4's wiki-init.sh modification is the implementation; the SC-5 fixture exercises it.
- **DISP-1 — Plan-time managed-key namespace cross-reference**: SATISFIED by the section above. Operator approval at dispatch time finalizes the `wiki:` namespace classification (likely the only contestable entry).
- **FR-11 — Fail-closed on malformed YAML**: HARD CONTRACT. Truth #7 verifier exercises this.
- **MEM001 — bash 3.2 + POSIX sh** in `yaml-merge.sh` and the modifications to install scripts and `wiki-init.sh`.
- **AD-19 — Verifier shape**: all verifiers under `tools/verify/m037-p01-*.sh` are project-owned, milestone-prefixed, single-script-file shape.
- **No external YAML parser dependency**: `yaml-merge.sh` uses sed/awk only — does not reach for `yq`, `python -m yaml`, or other external parsers (CON-1's spirit).

## Expected Output

- `scripts/lib/yaml-merge.sh` exists, ≥ 30 lines, contains `managed_namespaces`, supports `merge` subcommand with `--target` / `--framework-default` / `--managed-namespaces` / `--dry-run` flags, fails closed on malformed YAML.
- `packaging/install/install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh` all invoke `yaml-merge.sh` in their config-stage block.
- `scripts/lifecycle/wiki-init.sh` invokes `yaml-merge.sh` against the staged `mkdocs.yml` after the field-line rewrite.
- `tests/m037-acceptance/run-acceptance-battery.sh` exists, ≥ 20 lines, prints a `BATTERY: pass=N skip=M fail=K` summary, exits 0 only when fail=0.
- `tests/fixtures/m037-config-merge/` corpus exists.
- `tools/verify/m037-p01-config-clobber-fix.sh` exits 0.
- `tools/verify/m037-p01-malformed-yaml-fail-closed.sh` exits 0.
- `tests/m037-acceptance/p01-config-clobber-fix.sh` exits 0 (all four US-5 acceptance scenarios pass).
- `tests/m037-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=5 skip=0 fail=0` after T01..T06 all land.
