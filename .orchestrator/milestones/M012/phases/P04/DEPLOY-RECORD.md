---
schema_version: "1.0"
type: deploy-record
milestone: "M012"
phase: "P04"
deployed_url: "pending"
commit_sha: "pending"
deployed_at: "2026-04-21T03:49:37Z"
deployer: "pending"
gate_giscus_config_result: "skip"
gate_mkdocs_build_result: "skip"
gate_link_check_result: "skip"
gate_giscus_smoke_result: "skip"
---

# M012/P04 First-deploy record

## Deploy summary

This record was written on the fixture-sentinel path. The autonomous
dispatch context that produced it has no network access, no
`GISCUS_*` environment variables, and no `gh-pages` push rights, so
`scripts/wiki/wiki-deploy.sh` was not executed. The file carries the
`pending` sentinel in `deployed_url`, `commit_sha`, and `deployer`,
and each `gate_*_result` is `skip` because the wrapper's four gates
(giscus-config, mkdocs-build, link-check, giscus-smoke) did not run
in this context.

Per T04-PLAN.md, the T05 gate (`m012-p04-deploy-record.sh`) accepts
the `pending` sentinels in Tier 1. A human operator completes the
record on the live path during M012 consolidation — see the
"Pending-value path" section below.

## Wrapper output (abbreviated)

```
GATE: giscus-config SKIP (fixture path — not run)
BUILD: skip (fixture path — not run)
GATE: link-check SKIP (fixture path — not run)
GATE: giscus-smoke SKIP (fixture path — not run)
DEPLOY: pending (fixture path — not run)
OK: fixture-sentinel record written (no deploy attempted)
```

The wrapper this record refers to lives at
`scripts/wiki/wiki-deploy.sh` (T03). When a human operator runs it
on the live path, they capture the wrapper's actual last lines and
replace the abbreviated block above with the real output.

## Notes

- First deploy: creates the `gh-pages` branch and triggers an
  initial GitHub Pages build. Subsequent deploys reuse the branch
  and force-push the new built output.
- GitHub Pages can take up to a minute to serve a freshly pushed
  `gh-pages` update. If the deployed URL returns 404 immediately
  after the wrapper exits 0, wait 60s and reload.
- If `gh-pages` is a protected branch, `mkdocs gh-deploy --force`
  requires an administrator override. This is not the default;
  the wrapper assumes direct force-push is allowed.
- The fixture-sentinel path does not mutate remote state. Writing
  this record is safe; a later live run by a human operator is the
  only action that pushes to `gh-pages`.

## Pending-value path

`deployed_url`, `commit_sha`, and `deployer` in the frontmatter read
`pending`, which indicates this record was written without network
access at plan-execution time.

Before the M012 milestone closes, a human operator must:

1. Complete the `wiki/README.md` first-deploy checklist (steps 1–5:
   Pages source configured, Discussions enabled, Giscus category
   created, the four `GISCUS_*` env vars exported, `gh-pages` push
   rights confirmed).
2. Run `bash scripts/wiki/wiki-deploy.sh` from the repo root.
3. Capture the wrapper's terminator line (`OK: deployed to <url>`),
   the latest commit SHA on `main` (`git rev-parse HEAD`), and the
   ISO-8601 UTC timestamp (`date -u +%Y-%m-%dT%H:%M:%SZ`).
4. Replace `pending` sentinels in the frontmatter with the real
   values, update each `gate_*_result` to `pass` / `fail` per the
   wrapper's per-gate output, update `deployer` with the operator's
   GitHub handle, and replace the abbreviated Wrapper-output block
   with the actual last six lines of the wrapper run.
5. Verify SC-5 by posting a test comment on any wiki page through
   the Giscus thread, triggering a redeploy via a trivial wiki edit
   + rerunning the wrapper, and confirming the test comment persists
   across the redeploy. Record the SC-5 observation in
   `P04-SUMMARY.md` during consolidation.
