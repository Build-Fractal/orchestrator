# M037 P01 T06 — config merge fixture

Fixture project tree exercising the shared yaml-merge primitive
(`scripts/lib/yaml-merge.sh`) under SC-5 / Truth #6 / Truth #7.

## Layout

- `.orchestrator/config.yml` — operator-authored config with three CON-3
  preservation surfaces:
  1. Customized `default_tier: full` (operator chose non-framework value).
  2. Populated 3-entry `wiki.landing_cards:` block (operator authored
     content under a managed namespace).
  3. Operator-only top-level key `pbj_team_dashboard_url:` (key absent
     from framework default — must round-trip byte-identical).
- `wiki/mkdocs.yml` — operator-authored mkdocs.yml carrying a custom
  top-level `analytics:` block (CON-3 preservation surface for the
  `wiki-init.sh` template-refresh path; operator-only block, never in
  framework default).
- `framework-defaults/orchestrator-config-default.yml` — minimal framework
  default exercising the three CON-3 surfaces above plus the
  `_orchestrator_managed` comment marker required by the SC-5 acceptance
  test artifact contract.

The fixture is read-only at rest. T06 verifiers and the SC-5 acceptance
test stage copies under `mktemp -d` before mutating, so the on-disk
fixture stays byte-identical across runs.
